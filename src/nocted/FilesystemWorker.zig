const std = @import("std");
const core = @import("nocted_core");
const c = @import("gtk.zig");

pub const Kind = enum {
    project_scan,
    project_search,
    document_load,
    document_save,
    resolve_save_path,
};

pub const Lane = enum { foreground, scan };

pub fn lane(kind_value: Kind) Lane {
    return switch (kind_value) {
        .project_scan, .project_search => .scan,
        .document_load, .document_save, .resolve_save_path => .foreground,
    };
}

pub const AdmissionStatus = enum {
    accepted,
    queue_full,
    lane_full,
};

pub const Admission = struct {
    status: AdmissionStatus,
    lane: Lane,
    cancelled_jobs: usize,
    active_lane_jobs: usize,
};

/// Applies the exact application admission policy without taking ownership.
/// Older live generations of the same job kind are cancelled before the shared
/// and per-lane caps are evaluated, matching App.submitWorkerJob semantics.
pub fn admit(pending: []const *Job, job: *Job) Admission {
    var cancelled_jobs: usize = 0;
    if (job.generation != 0) {
        for (pending) |candidate| {
            if (candidate.kind() == job.kind() and
                candidate.generation < job.generation and
                !candidate.isCancelled())
            {
                candidate.cancelled.store(true, .release);
                cancelled_jobs += 1;
            }
        }
    }

    const job_lane = lane(job.kind());
    if (pending.len >= Job.max_pending) return .{
        .status = .queue_full,
        .lane = job_lane,
        .cancelled_jobs = cancelled_jobs,
        .active_lane_jobs = 0,
    };

    var active_lane_jobs: usize = 0;
    for (pending) |candidate| {
        if (lane(candidate.kind()) == job_lane and !candidate.isCancelled())
            active_lane_jobs += 1;
    }
    return .{
        .status = if (active_lane_jobs >= Job.max_pending / 2)
            .lane_full
        else
            .accepted,
        .lane = job_lane,
        .cancelled_jobs = cancelled_jobs,
        .active_lane_jobs = active_lane_jobs,
    };
}

pub fn cancelKind(pending: []const *Job, kind_value: Kind) usize {
    var cancelled_jobs: usize = 0;
    for (pending) |job| {
        if (job.kind() == kind_value and !job.isCancelled()) {
            job.cancelled.store(true, .release);
            cancelled_jobs += 1;
        }
    }
    return cancelled_jobs;
}

pub fn hasKind(pending: []const *Job, kind_value: Kind) bool {
    for (pending) |job| {
        if (job.kind() == kind_value) return true;
    }
    return false;
}

/// Owns the two lazy GLib worker pools while keeping all GTK state in App.
pub const Pools = struct {
    foreground: ?*c.GThreadPool = null,
    scan: ?*c.GThreadPool = null,

    pub fn ensure(self: *Pools, lane_value: Lane) !*c.GThreadPool {
        const existing = switch (lane_value) {
            .foreground => self.foreground,
            .scan => self.scan,
        };
        if (existing) |pool| return pool;

        var error_ptr: ?*c.GError = null;
        const pool = c.g_thread_pool_new(run, null, 1, 1, &error_ptr);
        if (error_ptr) |err| c.g_error_free(err);
        const created = pool orelse return error.WorkerCreationFailed;
        switch (lane_value) {
            .foreground => self.foreground = created,
            .scan => self.scan = created,
        }
        return created;
    }

    pub fn shutdown(self: *Pools) void {
        if (self.foreground) |pool| {
            c.g_thread_pool_free(pool, 0, 1);
            self.foreground = null;
        }
        if (self.scan) |pool| {
            c.g_thread_pool_free(pool, 0, 1);
            self.scan = null;
        }
    }
};

pub fn push(pool: *c.GThreadPool, job: *Job) !void {
    var error_ptr: ?*c.GError = null;
    if (c.g_thread_pool_push(pool, job, &error_ptr) == 0) {
        if (error_ptr) |err| c.g_error_free(err);
        return error.WorkerQueueFailed;
    }
    if (error_ptr) |err| c.g_error_free(err);
}

/// Commits one already-admitted job. A failed queue push removes exactly the
/// just-appended pointer and leaves all earlier attached jobs in order.
pub fn commitWith(
    pending: anytype,
    job: *Job,
    pool: anytype,
    comptime push_job: anytype,
) !usize {
    try pending.append(job);
    errdefer {
        const removed = pending.pop() orelse unreachable;
        std.debug.assert(removed == job);
    }
    try push_job(pool, job);
    return pending.items.len;
}

pub fn enqueue(
    pools: *Pools,
    pending: *std.array_list.Managed(*Job),
    job: *Job,
    lane_value: Lane,
) !usize {
    const pool = try pools.ensure(lane_value);
    return commitWith(pending, job, pool, push);
}

pub fn detach(pending: *std.array_list.Managed(*Job), job: *Job) bool {
    for (pending.items, 0..) |candidate, index| {
        if (candidate != job) continue;
        _ = pending.orderedRemove(index);
        return true;
    }
    return false;
}

pub const Job = struct {
    pub const max_pending: usize = 64;
    pub const search_batch_size: usize = 24;
    pub const max_search_batches: usize = 2;
    pub const Completion = *const fn (*Job) void;
    pub const BatchCompletion = *const fn (*Job, []const core.project_search.Result) void;

    owner: *anyopaque,
    allocator: std.mem.Allocator,
    io: std.Io,
    generation: u64,
    cancelled: std.atomic.Value(bool) = .init(false),
    synchronous: bool = false,
    main_done: bool = false,
    failure: ?anyerror = null,
    completion: Completion,
    batch_completion: ?BatchCompletion = null,
    outstanding_batches: std.atomic.Value(u8) = .init(0),
    batch_peak: u8 = 0,
    payload: Payload,

    pub const Payload = union(Kind) {
        project_scan: struct {
            root: ?[]u8,
            index: core.project_index.Index = .{},
            changes: []core.project_index.FilesystemChange = &.{},
            delta_stats: core.project_index.DeltaStats = .{},
        },
        project_search: struct {
            root: []u8,
            query: []u8,
            index: core.project_index.Index,
            snapshots: []core.project_search.BufferSnapshot = &.{},
            search: core.project_search.Search = .{},
        },
        document_load: struct {
            requested_path: []u8,
            reveal_line: ?u32,
            loaded: ?core.document.LoadedFile = null,
        },
        document_save: struct {
            path: []u8,
            contents: []u8,
        },
        resolve_save_path: struct {
            requested_path: []u8,
            resolved: ?[:0]u8 = null,
        },
    };

    pub fn init(
        owner: *anyopaque,
        allocator: std.mem.Allocator,
        io: std.Io,
        generation: u64,
        synchronous: bool,
        payload: Payload,
        completion: Completion,
    ) Job {
        return .{
            .owner = owner,
            .allocator = allocator,
            .io = io,
            .generation = generation,
            .synchronous = synchronous,
            .completion = completion,
            .payload = payload,
        };
    }

    pub fn kind(self: *const Job) Kind {
        return std.meta.activeTag(self.payload);
    }

    pub fn isCancelled(self: *const Job) bool {
        return self.cancelled.load(.acquire);
    }

    pub fn deinit(self: *Job) void {
        switch (self.payload) {
            .project_scan => |*payload| {
                if (payload.root) |root| self.allocator.free(root);
                payload.index.deinit(self.allocator);
                for (payload.changes) |change| {
                    self.allocator.free(change.path);
                    if (change.other_path) |other| self.allocator.free(other);
                }
                if (payload.changes.len != 0) self.allocator.free(payload.changes);
            },
            .project_search => |*payload| {
                payload.search.deinit(self.allocator);
                payload.index.deinit(self.allocator);
                for (payload.snapshots) |snapshot|
                    self.allocator.free(snapshot.contents);
                if (payload.snapshots.len != 0)
                    self.allocator.free(payload.snapshots);
                self.allocator.free(payload.root);
                self.allocator.free(payload.query);
            },
            .document_load => |*payload| {
                if (payload.loaded) |*loaded| loaded.deinit(self.allocator);
                self.allocator.free(payload.requested_path);
            },
            .document_save => |payload| {
                self.allocator.free(payload.path);
                self.allocator.free(payload.contents);
            },
            .resolve_save_path => |*payload| {
                self.allocator.free(payload.requested_path);
                if (payload.resolved) |resolved| self.allocator.free(resolved);
            },
        }
        self.* = undefined;
    }
};

pub fn run(data: ?*anyopaque, _: ?*anyopaque) callconv(.c) void {
    const job: *Job = @ptrCast(@alignCast(data orelse return));
    execute(job) catch |err| {
        job.failure = err;
    };
    _ = c.g_idle_add(onComplete, job);
}

fn execute(job: *Job) !void {
    if (job.isCancelled()) return;
    switch (job.payload) {
        .project_scan => |*payload| {
            const root = payload.root orelse return error.ProjectRootUnavailable;
            if (payload.changes.len != 0) {
                var delta = try core.project_index.applyFilesystemChangesAlloc(
                    job.allocator,
                    job.io,
                    root,
                    payload.index,
                    payload.changes,
                );
                payload.index.deinit(job.allocator);
                payload.index = delta.index;
                delta.index = .{};
                payload.delta_stats = delta.stats;
                return;
            }
            var scanner = try core.project_index.Scanner.init(
                job.allocator,
                job.io,
                root,
            );
            defer scanner.deinit();
            while (try scanner.step(128) == .pending) {
                if (job.isCancelled()) return;
            }
            if (job.isCancelled()) return;
            payload.index = try scanner.takeIndex();
        },
        .project_search => |*payload| {
            var cursor = try core.project_search.Cursor.initWithSnapshots(
                job.allocator,
                job.io,
                payload.root,
                payload.index,
                payload.query,
                .{},
                payload.snapshots,
            );
            defer cursor.deinit();
            var published: usize = 0;
            var last_publish = std.Io.Clock.now(.awake, job.io);
            while (true) {
                const progress = try cursor.step(1);
                if (job.isCancelled()) return;
                const now = std.Io.Clock.now(.awake, job.io);
                const elapsed = last_publish.durationTo(now).nanoseconds;
                const pending = cursor.results.items.len - published;
                const timed_flush = pending != 0 and elapsed >=
                    25 * std.time.ns_per_ms;
                if (pending >= Job.search_batch_size or timed_flush or
                    progress == .complete)
                {
                    published = try publishSearchResults(
                        job,
                        cursor.results.items,
                        published,
                        timed_flush or progress == .complete,
                    );
                    last_publish = now;
                }
                if (progress == .complete) break;
            }
            if (job.isCancelled()) return;
            payload.search = try cursor.takeSearch();
        },
        .document_load => |*payload| {
            payload.loaded = try core.document.loadFileAlloc(
                job.allocator,
                job.io,
                payload.requested_path,
            );
        },
        .document_save => |payload| {
            try core.document.saveFileAtomic(
                job.io,
                payload.path,
                payload.contents,
            );
        },
        .resolve_save_path => |*payload| {
            payload.resolved = try core.document.resolveSavePathAlloc(
                job.allocator,
                job.io,
                payload.requested_path,
            );
        },
    }
}

fn onComplete(data: ?*anyopaque) callconv(.c) c.gboolean {
    const job: *Job = @ptrCast(@alignCast(data orelse return c.G_SOURCE_REMOVE));
    if (job.outstanding_batches.load(.acquire) != 0) return c.G_SOURCE_CONTINUE;
    job.completion(job);
    return c.G_SOURCE_REMOVE;
}

const SearchBatch = struct {
    job: *Job,
    count: u8,
    results: [Job.search_batch_size]core.project_search.Result = undefined,
};

fn publishSearchResults(
    job: *Job,
    results: []const core.project_search.Result,
    first: usize,
    flush_partial: bool,
) !usize {
    var published = first;
    while (published < results.len) {
        const remaining = results.len - published;
        if (remaining < Job.search_batch_size and !flush_partial) break;
        while (job.outstanding_batches.load(.acquire) >= Job.max_search_batches) {
            if (job.isCancelled()) return published;
            job.io.sleep(.fromMilliseconds(1), .awake) catch {};
        }
        if (job.isCancelled()) return published;
        const count = @min(remaining, Job.search_batch_size);
        const batch = try job.allocator.create(SearchBatch);
        batch.* = .{ .job = job, .count = @intCast(count) };
        @memcpy(batch.results[0..count], results[published .. published + count]);
        const outstanding = job.outstanding_batches.fetchAdd(1, .acq_rel) + 1;
        job.batch_peak = @max(job.batch_peak, outstanding);
        if (c.g_idle_add(onSearchBatch, batch) == 0) {
            _ = job.outstanding_batches.fetchSub(1, .acq_rel);
            job.allocator.destroy(batch);
            return error.SearchBatchQueueFailed;
        }
        published += count;
    }
    return published;
}

fn onSearchBatch(data: ?*anyopaque) callconv(.c) c.gboolean {
    const batch: *SearchBatch = @ptrCast(@alignCast(data orelse return c.G_SOURCE_REMOVE));
    const job = batch.job;
    if (!job.isCancelled()) {
        if (job.batch_completion) |completion|
            completion(job, batch.results[0..batch.count]);
    }
    _ = job.outstanding_batches.fetchSub(1, .acq_rel);
    job.allocator.destroy(batch);
    return c.G_SOURCE_REMOVE;
}
