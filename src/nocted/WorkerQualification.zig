const std = @import("std");
const builtin = @import("builtin");
const core = @import("nocted_core");
const c = @import("gtk.zig");
const worker = @import("FilesystemWorker.zig");

const fixture_files: usize = 193;
const AccountedAllocator = std.heap.DebugAllocator(.{
    .enable_memory_limit = true,
});

const State = struct {
    io: std.Io,
    completed: usize = 0,
    scan_complete: bool = false,
    old_search_complete: bool = false,
    new_search_complete: bool = false,
    save_complete: bool = false,
    old_batches: usize = 0,
    old_results: usize = 0,
    new_batches: usize = 0,
    new_results: usize = 0,
    new_first_entry: ?usize = null,
    batch_size_bounded: bool = true,
    cancel_started: ?std.Io.Timestamp = null,
    cancel_retired_ns: u64 = 0,

    fn onComplete(job: *worker.Job) void {
        const self: *State = @ptrCast(@alignCast(job.owner));
        switch (job.kind()) {
            .project_scan => self.scan_complete = true,
            .project_search => if (job.generation == 1) {
                self.old_search_complete = true;
                if (self.cancel_started) |started| {
                    const elapsed = started.durationTo(
                        std.Io.Clock.awake.now(self.io),
                    ).nanoseconds;
                    self.cancel_retired_ns = @intCast(@max(elapsed, 0));
                }
            } else {
                self.new_search_complete = true;
            },
            .document_save => self.save_complete = true,
            else => {},
        }
        self.completed += 1;
    }

    fn onBatch(job: *worker.Job, results: []const core.project_search.Result) void {
        const self: *State = @ptrCast(@alignCast(job.owner));
        if (results.len == 0 or results.len > worker.Job.search_batch_size)
            self.batch_size_bounded = false;
        if (job.generation == 1) {
            self.old_batches += 1;
            self.old_results += results.len;
            if (!job.isCancelled()) {
                self.cancel_started = std.Io.Clock.awake.now(self.io);
                job.cancelled.store(true, .release);
            }
            return;
        }
        self.new_batches += 1;
        self.new_results += results.len;
        if (self.new_first_entry == null)
            self.new_first_entry = results[0].entry_index;
    }
};

const Outcome = struct {
    scan_entries: usize,
    search_results: usize,
    old_batch_peak: u8,
    new_batch_peak: u8,
    new_batches: usize,
    cancel_retired_ns: u64,
    checkpoint_active_bytes: usize,
};

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 2) return error.InvalidArguments;

    var debug_allocator: AccountedAllocator = .init;
    const outcome = runQualification(
        &debug_allocator,
        init.io,
        args[1],
    ) catch |err| {
        _ = debug_allocator.deinit();
        return err;
    };
    const residual_bytes = debug_allocator.total_requested_bytes;
    const leak_check = debug_allocator.deinit();
    if (residual_bytes != 0 or leak_check != .ok)
        return error.AllocatorAccountingFailed;

    var output_buffer: [4096]u8 = undefined;
    var output_writer: std.Io.File.Writer = .init(
        .stdout(),
        init.io,
        &output_buffer,
    );
    const stdout = &output_writer.interface;
    defer stdout.flush() catch {};
    try stdout.print(
        "nocted_worker_qualification mode={s} fixture_files={d} " ++
            "scan_entries={d} search_results={d} old_batch_peak={d} " ++
            "new_batch_peak={d} new_batches={d} cancel_retired_ns={d} " ++
            "shared_admission_policy=true generation_supersession=true " ++
            "shared_queue_cap=64 lane_queue_cap=32 " ++
            "cancelled_lane_excluded=true kind_cancel=true pending_lookup=true " ++
            "lazy_pool_creation=true transactional_enqueue=true " ++
            "append_failure_safe=true push_failure_rollback=true " ++
            "ordered_retirement=true " ++
            "glib_thread_pools=true worker_lanes=2 project_scan=true " ++
            "search_streaming=true snapshot_first=true " ++
            "cooperative_cancellation=true search_batch_size=24 " ++
            "search_batch_cap=2 backpressure_exercised=true " ++
            "foreground_save_under_backpressure=true worker_drained=true " ++
            "allocator_leak_free=true allocator_residual_bytes={d} " ++
            "checkpoint_active_bytes={d}\n",
        .{
            @tagName(builtin.mode),
            fixture_files,
            outcome.scan_entries,
            outcome.search_results,
            outcome.old_batch_peak,
            outcome.new_batch_peak,
            outcome.new_batches,
            outcome.cancel_retired_ns,
            residual_bytes,
            outcome.checkpoint_active_bytes,
        },
    );
}

fn runQualification(
    accounting: *AccountedAllocator,
    io: std.Io,
    root_path: []const u8,
) !Outcome {
    const allocator = accounting.allocator();
    try qualifyAdmissionPolicy(allocator, io);
    try qualifyQueueTransaction(allocator, io);
    var root = try std.Io.Dir.openDirAbsolute(io, root_path, .{ .iterate = true });
    defer root.close(io);
    try createFixture(root, io);

    var state = State{ .io = io };
    var pools: worker.Pools = .{};
    defer pools.shutdown();
    var pending = std.array_list.Managed(*worker.Job).init(allocator);
    defer pending.deinit();
    if (pools.scan != null or pools.foreground != null)
        return error.WorkerPoolsNotLazy;

    const scan_job = try allocator.create(worker.Job);
    scan_job.* = worker.Job.init(
        &state,
        allocator,
        io,
        1,
        false,
        .{ .project_scan = .{
            .root = try allocator.dupe(u8, root_path),
        } },
        State.onComplete,
    );
    if (try worker.enqueue(&pools, &pending, scan_job, .scan) != 1 or
        pools.scan == null or pools.foreground != null)
        return error.ScanPoolCreationMismatch;
    try drainUntil(&state, io, 1);
    if (!state.scan_complete or scan_job.failure != null)
        return error.ProjectScanFailed;
    const scan_entries = scan_job.payload.project_scan.index.entries.len;
    if (scan_entries < fixture_files) return error.ProjectScanIncomplete;
    const focus_entry = scan_job.payload.project_scan.index.findPath("focus.zig") orelse
        return error.FocusEntryMissing;

    const old_job = try createSearchJob(
        allocator,
        io,
        &state,
        root_path,
        scan_job.payload.project_scan.index,
        focus_entry,
        1,
    );
    const new_job = try createSearchJob(
        allocator,
        io,
        &state,
        root_path,
        scan_job.payload.project_scan.index,
        focus_entry,
        2,
    );
    if (try worker.enqueue(&pools, &pending, old_job, .scan) != 2 or
        try worker.enqueue(&pools, &pending, new_job, .scan) != 3)
        return error.ScanEnqueueMismatch;
    try waitForBackpressure(old_job, io);

    const save_path = try std.fs.path.join(
        allocator,
        &.{ root_path, "foreground-save.txt" },
    );
    const save_contents = "foreground lane stayed independent\n";
    const save_job = try allocator.create(worker.Job);
    save_job.* = worker.Job.init(
        &state,
        allocator,
        io,
        0,
        false,
        .{ .document_save = .{
            .path = save_path,
            .contents = try allocator.dupe(u8, save_contents),
        } },
        State.onComplete,
    );
    if (try worker.enqueue(&pools, &pending, save_job, .foreground) != 4 or
        pools.foreground == null or pools.scan == null)
        return error.ForegroundPoolCreationMismatch;
    try waitForSavedFile(root, allocator, io, save_contents);
    if (state.completed != 1 or old_job.outstanding_batches.load(.acquire) != 2)
        return error.ForegroundLaneNotIndependent;

    try drainUntil(&state, io, 4);
    while (c.g_main_context_iteration(null, 0) != 0) {}

    if (!state.old_search_complete or !state.new_search_complete or
        !state.save_complete or old_job.failure != null or
        new_job.failure != null or save_job.failure != null)
        return error.WorkerCompletionFailed;
    if (!old_job.isCancelled() or state.old_batches != 1 or
        state.old_results == 0 or state.cancel_retired_ns == 0)
        return error.CancellationFailed;
    if (!state.batch_size_bounded or old_job.batch_peak != 2 or
        new_job.batch_peak == 0 or new_job.batch_peak > worker.Job.max_search_batches)
        return error.SearchBackpressureFailed;
    if (state.new_first_entry != focus_entry)
        return error.SnapshotWasNotFirst;
    const completed_search = &new_job.payload.project_search.search;
    if (state.new_results != completed_search.results.len or
        completed_search.results.len != fixture_files or state.new_batches < 2)
        return error.SearchResultMismatch;

    const search_results = completed_search.results.len;
    const old_batch_peak = old_job.batch_peak;
    const new_batch_peak = new_job.batch_peak;
    const new_batches = state.new_batches;
    const cancel_retired_ns = state.cancel_retired_ns;
    const checkpoint_active_bytes = accounting.total_requested_bytes;
    if (checkpoint_active_bytes == 0)
        return error.AllocatorCheckpointMissing;

    if (!worker.detach(&pending, old_job) or
        !worker.detach(&pending, new_job) or
        !worker.detach(&pending, save_job) or
        !worker.detach(&pending, scan_job) or
        worker.detach(&pending, scan_job) or pending.items.len != 0)
        return error.WorkerRetirementMismatch;

    old_job.deinit();
    allocator.destroy(old_job);
    new_job.deinit();
    allocator.destroy(new_job);
    save_job.deinit();
    allocator.destroy(save_job);
    scan_job.deinit();
    allocator.destroy(scan_job);
    pools.shutdown();
    if (pools.foreground != null or pools.scan != null)
        return error.WorkerPoolShutdownMismatch;

    return .{
        .scan_entries = scan_entries,
        .search_results = search_results,
        .old_batch_peak = old_batch_peak,
        .new_batch_peak = new_batch_peak,
        .new_batches = new_batches,
        .cancel_retired_ns = cancel_retired_ns,
        .checkpoint_active_bytes = checkpoint_active_bytes,
    };
}

fn createFixture(root: std.Io.Dir, io: std.Io) !void {
    for (0..8) |directory_index| {
        var directory_buffer: [32]u8 = undefined;
        const directory = try std.fmt.bufPrint(
            &directory_buffer,
            "module_{d:0>2}",
            .{directory_index},
        );
        try root.createDirPath(io, directory);
    }
    for (0..fixture_files - 1) |file_index| {
        var path_buffer: [96]u8 = undefined;
        const path = try std.fmt.bufPrint(
            &path_buffer,
            "module_{d:0>2}/fixture_{d:0>3}.zig",
            .{ file_index % 8, file_index },
        );
        try root.writeFile(io, .{
            .sub_path = path,
            .data = "const worker_needle = true;\n",
        });
    }
    try root.writeFile(io, .{
        .sub_path = "focus.zig",
        .data = "const stale_disk_contents = true;\n",
    });
}

fn qualifyAdmissionPolicy(allocator: std.mem.Allocator, io: std.Io) !void {
    var state = State{ .io = io };

    var older = admissionJob(allocator, io, &state, .project_search, 1);
    var current = admissionJob(allocator, io, &state, .project_search, 2);
    var other_kind = admissionJob(allocator, io, &state, .project_scan, 1);
    var replacement = admissionJob(allocator, io, &state, .project_search, 3);
    const generations = [_]*worker.Job{ &older, &current, &other_kind };
    const supersession = worker.admit(&generations, &replacement);
    if (supersession.status != .accepted or supersession.lane != .scan or
        supersession.cancelled_jobs != 2 or supersession.active_lane_jobs != 1 or
        !older.isCancelled() or !current.isCancelled() or other_kind.isCancelled())
        return error.GenerationSupersessionMismatch;

    var zero_generation = admissionJob(
        allocator,
        io,
        &state,
        .project_search,
        0,
    );
    const zero_result = worker.admit(&generations, &zero_generation);
    if (zero_result.status != .accepted or zero_result.cancelled_jobs != 0)
        return error.ZeroGenerationAdmissionMismatch;

    var jobs: [worker.Job.max_pending]worker.Job = undefined;
    var pointers: [worker.Job.max_pending]*worker.Job = undefined;
    for (0..worker.Job.max_pending / 2) |index| {
        jobs[index] = admissionJob(
            allocator,
            io,
            &state,
            .project_scan,
            0,
        );
        pointers[index] = &jobs[index];
    }
    for (worker.Job.max_pending / 2..worker.Job.max_pending) |index| {
        jobs[index] = admissionJob(
            allocator,
            io,
            &state,
            .document_load,
            0,
        );
        pointers[index] = &jobs[index];
    }

    var scan_candidate = admissionJob(
        allocator,
        io,
        &state,
        .project_search,
        0,
    );
    const scan_full = worker.admit(
        pointers[0 .. worker.Job.max_pending / 2],
        &scan_candidate,
    );
    if (scan_full.status != .lane_full or scan_full.lane != .scan or
        scan_full.active_lane_jobs != worker.Job.max_pending / 2)
        return error.ScanLaneCapMismatch;

    jobs[0].cancelled.store(true, .release);
    const cancelled_excluded = worker.admit(
        pointers[0 .. worker.Job.max_pending / 2],
        &scan_candidate,
    );
    if (cancelled_excluded.status != .accepted or
        cancelled_excluded.active_lane_jobs != worker.Job.max_pending / 2 - 1)
        return error.CancelledLaneAccountingMismatch;

    var foreground_candidate = admissionJob(
        allocator,
        io,
        &state,
        .document_save,
        0,
    );
    const foreground_full = worker.admit(
        pointers[worker.Job.max_pending / 2 ..],
        &foreground_candidate,
    );
    if (foreground_full.status != .lane_full or
        foreground_full.lane != .foreground or
        foreground_full.active_lane_jobs != worker.Job.max_pending / 2)
        return error.ForegroundLaneCapMismatch;

    const independent_lane = worker.admit(
        pointers[worker.Job.max_pending / 2 ..],
        &scan_candidate,
    );
    if (independent_lane.status != .accepted or
        independent_lane.active_lane_jobs != 0)
        return error.LaneIndependenceMismatch;

    const shared_full = worker.admit(&pointers, &scan_candidate);
    if (shared_full.status != .queue_full or
        shared_full.active_lane_jobs != 0 or
        worker.Job.max_pending != 64)
        return error.SharedQueueCapMismatch;

    var cancel_a = admissionJob(allocator, io, &state, .document_load, 0);
    var cancel_b = admissionJob(allocator, io, &state, .document_load, 0);
    var keep = admissionJob(allocator, io, &state, .document_save, 0);
    cancel_b.cancelled.store(true, .release);
    const cancel_pending = [_]*worker.Job{ &cancel_a, &cancel_b, &keep };
    if (worker.cancelKind(&cancel_pending, .document_load) != 1 or
        !cancel_a.isCancelled() or !cancel_b.isCancelled() or keep.isCancelled() or
        !worker.hasKind(&cancel_pending, .document_load) or
        worker.hasKind(&cancel_pending, .project_scan))
        return error.KindCancellationMismatch;
}

const QueueProbe = struct {
    called: bool = false,

    fn succeed(self: *QueueProbe, _: *worker.Job) !void {
        self.called = true;
    }

    fn fail(self: *QueueProbe, _: *worker.Job) !void {
        self.called = true;
        return error.QualificationPushFailed;
    }
};

fn qualifyQueueTransaction(allocator: std.mem.Allocator, io: std.Io) !void {
    var state = State{ .io = io };
    var existing = admissionJob(allocator, io, &state, .document_load, 0);
    var candidate = admissionJob(allocator, io, &state, .document_save, 0);

    var empty_storage: [0]u8 = .{};
    var fixed = std.heap.FixedBufferAllocator.init(&empty_storage);
    var no_capacity = std.array_list.Managed(*worker.Job).init(fixed.allocator());
    defer no_capacity.deinit();
    var append_probe: QueueProbe = .{};
    var append_failed = false;
    _ = worker.commitWith(
        &no_capacity,
        &candidate,
        &append_probe,
        QueueProbe.succeed,
    ) catch |err| {
        if (err != error.OutOfMemory) return err;
        append_failed = true;
    };
    if (!append_failed or append_probe.called or no_capacity.items.len != 0)
        return error.AppendFailureMutation;

    var pending = std.array_list.Managed(*worker.Job).init(allocator);
    defer pending.deinit();
    try pending.append(&existing);
    var failure_probe: QueueProbe = .{};
    var push_failed = false;
    _ = worker.commitWith(
        &pending,
        &candidate,
        &failure_probe,
        QueueProbe.fail,
    ) catch |err| {
        if (err != error.QualificationPushFailed) return err;
        push_failed = true;
    };
    if (!push_failed or !failure_probe.called or pending.items.len != 1 or
        pending.items[0] != &existing)
        return error.PushFailureRollbackMismatch;

    var success_probe: QueueProbe = .{};
    if (try worker.commitWith(
        &pending,
        &candidate,
        &success_probe,
        QueueProbe.succeed,
    ) != 2 or !success_probe.called or pending.items[0] != &existing or
        pending.items[1] != &candidate)
        return error.QueueCommitMismatch;
    if (!worker.detach(&pending, &candidate) or
        worker.detach(&pending, &candidate) or pending.items.len != 1 or
        pending.items[0] != &existing)
        return error.OrderedRetirementMismatch;
}

fn admissionJob(
    allocator: std.mem.Allocator,
    io: std.Io,
    state: *State,
    kind_value: worker.Kind,
    generation: u64,
) worker.Job {
    const payload: worker.Job.Payload = switch (kind_value) {
        .project_scan => .{ .project_scan = .{ .root = null } },
        .project_search => .{ .project_search = .{
            .root = &.{},
            .query = &.{},
            .index = .{},
        } },
        .document_load => .{ .document_load = .{
            .requested_path = &.{},
            .reveal_line = null,
        } },
        .document_save => .{ .document_save = .{
            .path = &.{},
            .contents = &.{},
        } },
        .resolve_save_path => .{ .resolve_save_path = .{
            .requested_path = &.{},
        } },
    };
    return worker.Job.init(
        state,
        allocator,
        io,
        generation,
        false,
        payload,
        State.onComplete,
    );
}

fn createSearchJob(
    allocator: std.mem.Allocator,
    io: std.Io,
    state: *State,
    root_path: []const u8,
    index: core.project_index.Index,
    focus_entry: usize,
    generation: u64,
) !*worker.Job {
    const snapshots = try allocator.alloc(core.project_search.BufferSnapshot, 1);
    snapshots[0] = .{
        .entry_index = focus_entry,
        .contents = try allocator.dupe(
            u8,
            "const worker_needle = \"snapshot first\";\n",
        ),
    };
    const job = try allocator.create(worker.Job);
    job.* = worker.Job.init(
        state,
        allocator,
        io,
        generation,
        false,
        .{ .project_search = .{
            .root = try allocator.dupe(u8, root_path),
            .query = try allocator.dupe(u8, "worker_needle"),
            .index = index.retain(),
            .snapshots = snapshots,
        } },
        State.onComplete,
    );
    job.batch_completion = State.onBatch;
    return job;
}

fn waitForBackpressure(job: *worker.Job, io: std.Io) !void {
    const started = std.Io.Clock.awake.now(io);
    while (job.outstanding_batches.load(.acquire) < worker.Job.max_search_batches) {
        if (started.durationTo(std.Io.Clock.awake.now(io)).nanoseconds >=
            5 * std.time.ns_per_s)
            return error.BackpressureTimeout;
        io.sleep(.fromMilliseconds(1), .awake) catch {};
    }
}

fn waitForSavedFile(
    root: std.Io.Dir,
    allocator: std.mem.Allocator,
    io: std.Io,
    expected: []const u8,
) !void {
    const started = std.Io.Clock.awake.now(io);
    while (true) {
        const stat = root.statFile(io, "foreground-save.txt", .{}) catch null;
        if (stat != null) break;
        if (started.durationTo(std.Io.Clock.awake.now(io)).nanoseconds >=
            5 * std.time.ns_per_s)
            return error.ForegroundSaveTimeout;
        io.sleep(.fromMilliseconds(1), .awake) catch {};
    }
    const contents = try root.readFileAlloc(
        io,
        "foreground-save.txt",
        allocator,
        .limited(128),
    );
    defer allocator.free(contents);
    if (!std.mem.eql(u8, contents, expected))
        return error.ForegroundSaveMismatch;
}

fn drainUntil(state: *State, io: std.Io, expected: usize) !void {
    const started = std.Io.Clock.awake.now(io);
    while (state.completed < expected) {
        while (c.g_main_context_iteration(null, 0) != 0) {}
        if (started.durationTo(std.Io.Clock.awake.now(io)).nanoseconds >=
            10 * std.time.ns_per_s)
            return error.WorkerDrainTimeout;
        io.sleep(.fromMilliseconds(1), .awake) catch {};
    }
}
