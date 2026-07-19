const std = @import("std");
const builtin = @import("builtin");
const core = @import("nocted_core");

const AccountedAllocator = std.heap.DebugAllocator(.{
    .enable_memory_limit = true,
});

const Outcome = struct {
    entries: usize,
    scan_ns: u64,
    delta_ns: u64,
    index_bytes: usize,
    two_snapshot_bytes: usize,
    delta_events: usize,
    delta_added: usize,
    delta_removed: usize,
    peak_active_bytes: usize,
};

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 3) return error.InvalidArguments;
    const scale = try std.fmt.parseInt(usize, args[2], 10);
    if (scale < 32 or scale > core.project_index.max_entries)
        return error.InvalidScale;

    var debug_allocator: AccountedAllocator = .init;
    const outcome = runQualification(
        &debug_allocator,
        init.io,
        args[1],
        scale,
    ) catch |err| {
        _ = debug_allocator.deinit();
        return err;
    };
    const residual_bytes = debug_allocator.total_requested_bytes;
    const leak_check = debug_allocator.deinit();
    if (residual_bytes != 0 or leak_check != .ok)
        return error.AllocatorAccountingFailed;

    var buffer: [4096]u8 = undefined;
    var file_writer: std.Io.File.Writer = .init(.stdout(), init.io, &buffer);
    const stdout = &file_writer.interface;
    defer stdout.flush() catch {};
    try stdout.print(
        "nocted_project_index_qualification mode={s} scale={d} entries={d} " ++
            "scan_ns={d} delta_ns={d} index_bytes={d} two_snapshot_bytes={d} " ++
            "delta_events={d} delta_added={d} delta_removed={d} " ++
            "directory_rename=true replacement_conflict=true ignore_fallback=true " ++
            "overflow_fallback=true snapshot_teardown=true allocator_leak_free=true " ++
            "allocator_residual_bytes={d} peak_active_bytes={d}\n",
        .{
            @tagName(builtin.mode),
            scale,
            outcome.entries,
            outcome.scan_ns,
            outcome.delta_ns,
            outcome.index_bytes,
            outcome.two_snapshot_bytes,
            outcome.delta_events,
            outcome.delta_added,
            outcome.delta_removed,
            residual_bytes,
            outcome.peak_active_bytes,
        },
    );
}

fn runQualification(
    accounting: *AccountedAllocator,
    io: std.Io,
    root_path: []const u8,
    scale: usize,
) !Outcome {
    const allocator = accounting.allocator();
    var root = try std.Io.Dir.openDirAbsolute(io, root_path, .{ .iterate = true });
    defer root.close(io);
    const directory_count = @max(@as(usize, 2), scale / 1000);
    const file_count = scale - directory_count;
    for (0..directory_count) |directory_index| {
        var directory_buffer: [64]u8 = undefined;
        const directory_path = try std.fmt.bufPrint(
            &directory_buffer,
            "module_{d:0>3}",
            .{directory_index},
        );
        try root.createDirPath(io, directory_path);
    }
    for (0..file_count) |file_index| {
        var path_buffer: [128]u8 = undefined;
        const path = try std.fmt.bufPrint(
            &path_buffer,
            "module_{d:0>3}/file_{d:0>6}.zig",
            .{ file_index % directory_count, file_index },
        );
        try root.writeFile(io, .{ .sub_path = path, .data = "const fixture = true;\n" });
    }

    var started = std.Io.Clock.awake.now(io);
    var baseline = try core.project_index.scanAlloc(allocator, io, root_path);
    defer baseline.deinit(allocator);
    const scan_ns = elapsedNanoseconds(started, io);
    if (baseline.entries.len != scale or baseline.truncated)
        return error.ScaleScanMismatch;
    var retained = baseline.retain();
    defer retained.deinit(allocator);

    const delete_a = "module_000/file_000000.zig";
    const delete_b = std.fmt.allocPrint(
        allocator,
        "module_{d:0>3}/file_{d:0>6}.zig",
        .{ 3 % directory_count, 3 },
    ) catch return error.OutOfMemory;
    defer allocator.free(delete_b);
    const conflict_source = std.fmt.allocPrint(
        allocator,
        "module_{d:0>3}/file_{d:0>6}.zig",
        .{ 1 % directory_count, 1 },
    ) catch return error.OutOfMemory;
    defer allocator.free(conflict_source);
    const conflict_target = std.fmt.allocPrint(
        allocator,
        "module_{d:0>3}/file_{d:0>6}.zig",
        .{ 2 % directory_count, 2 },
    ) catch return error.OutOfMemory;
    defer allocator.free(conflict_target);

    try root.deleteFile(io, delete_a);
    try root.deleteFile(io, delete_b);
    try root.rename(conflict_source, root, conflict_target, io);
    try root.rename("module_001", root, "renamed_module", io);
    try root.createDirPath(io, "delta_added/nested");
    try root.writeFile(io, .{
        .sub_path = "delta_added/nested/new.zig",
        .data = "const delta = true;\n",
    });

    const changes = [_]core.project_index.FilesystemChange{
        .{ .kind = .deleted, .path = delete_a },
        .{ .kind = .deleted, .path = delete_b },
        .{ .kind = .renamed, .path = conflict_source, .other_path = conflict_target },
        .{ .kind = .renamed, .path = "module_001", .other_path = "renamed_module" },
        .{ .kind = .created, .path = "delta_added" },
    };
    started = std.Io.Clock.awake.now(io);
    var delta = try core.project_index.applyFilesystemChangesAlloc(
        allocator,
        io,
        root_path,
        baseline,
        &changes,
    );
    defer delta.index.deinit(allocator);
    const delta_ns = elapsedNanoseconds(started, io);
    if (delta.index.entries.len != scale or delta.index.truncated or
        delta.index.findPath(delete_a) != null or
        delta.index.findPath(delete_b) != null or
        delta.index.findPath(conflict_source) != null or
        delta.index.findPath(conflict_target) == null or
        delta.index.findPath("module_001") != null or
        delta.index.findPath("renamed_module") == null or
        delta.index.findPath("delta_added/nested/new.zig") == null)
        return error.DeltaQualificationMismatch;

    const ignore_change = [_]core.project_index.FilesystemChange{
        .{ .kind = .created, .path = ".ignore" },
    };
    if (core.project_index.applyFilesystemChangesAlloc(
        allocator,
        io,
        root_path,
        delta.index,
        &ignore_change,
    )) |unexpected| {
        var value = unexpected;
        value.index.deinit(allocator);
        return error.IgnoreFallbackMissing;
    } else |err| if (err != error.ProjectDeltaRequiresRescan) return err;

    const overflow = try allocator.alloc(
        core.project_index.FilesystemChange,
        core.project_index.max_filesystem_changes + 1,
    );
    defer allocator.free(overflow);
    for (overflow) |*change| change.* = .{ .kind = .deleted, .path = "missing" };
    if (core.project_index.applyFilesystemChangesAlloc(
        allocator,
        io,
        root_path,
        delta.index,
        overflow,
    )) |unexpected| {
        var value = unexpected;
        value.index.deinit(allocator);
        return error.OverflowFallbackMissing;
    } else |err| if (err != error.ProjectDeltaRequiresRescan) return err;

    return .{
        .entries = delta.index.entries.len,
        .scan_ns = scan_ns,
        .delta_ns = delta_ns,
        .index_bytes = delta.index.memoryBytes(),
        .two_snapshot_bytes = baseline.memoryBytes() + delta.index.memoryBytes(),
        .delta_events = delta.stats.events,
        .delta_added = delta.stats.added_entries,
        .delta_removed = delta.stats.removed_entries,
        .peak_active_bytes = accounting.total_requested_bytes,
    };
}

fn elapsedNanoseconds(started: std.Io.Timestamp, io: std.Io) u64 {
    const elapsed = started.durationTo(std.Io.Clock.awake.now(io)).nanoseconds;
    return @intCast(@max(elapsed, 0));
}
