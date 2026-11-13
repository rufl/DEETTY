const std = @import("std");
const Workspace = @import("Workspace.zig");

const Io = std.Io;
const Dir = std.Io.Dir;

pub const WorkspaceFileRole = enum {
    manual,
    autosave,
    recovery,
};

pub const RecoveryPolicy = struct {
    enabled: bool = true,
    autosave_interval_seconds: u16 = 1,
    max_recovery_snapshots: u8 = 3,
    keep_recovery_after_clean_exit: bool = false,

    pub fn validate(self: RecoveryPolicy) !void {
        if (self.enabled and self.autosave_interval_seconds == 0) return error.InvalidRecoveryPolicy;
        if (self.max_recovery_snapshots == 0) return error.InvalidRecoveryPolicy;
    }
};

pub const RecoveryState = struct {
    policy: RecoveryPolicy = .{},
    dirty: bool = false,
    generation: u64 = 0,
    saved_generation: u64 = 0,
    last_path: ?[]u8 = null,
    recovery_path: ?[]u8 = null,

    pub fn deinit(self: *RecoveryState, allocator: std.mem.Allocator) void {
        if (self.last_path) |path| allocator.free(path);
        if (self.recovery_path) |path| allocator.free(path);
        self.* = .{};
    }

    pub fn markDirty(self: *RecoveryState) void {
        self.generation += 1;
        self.dirty = true;
    }

    pub fn markSaved(self: *RecoveryState, allocator: std.mem.Allocator, path: []const u8, role: WorkspaceFileRole) !void {
        const owned_path = try allocator.dupe(u8, path);
        errdefer allocator.free(owned_path);
        switch (role) {
            .manual => {
                if (!self.policy.keep_recovery_after_clean_exit) self.clearRecoveryPath(allocator);
            },
            .autosave, .recovery => try self.setRecoveryPath(allocator, path),
        }
        if (self.last_path) |old| allocator.free(old);
        self.last_path = owned_path;
        self.saved_generation = self.generation;
        self.dirty = false;
    }

    pub fn markLoaded(self: *RecoveryState, allocator: std.mem.Allocator, path: []const u8, role: WorkspaceFileRole) !void {
        try self.setLastPath(allocator, path);
        self.saved_generation = self.generation;
        self.dirty = false;
        if (role == .recovery and self.policy.keep_recovery_after_clean_exit) {
            try self.setRecoveryPath(allocator, path);
        } else if (role == .manual) {
            self.clearRecoveryPath(allocator);
        }
    }

    pub fn clearRecoveryPath(self: *RecoveryState, allocator: std.mem.Allocator) void {
        if (self.recovery_path) |path| allocator.free(path);
        self.recovery_path = null;
    }

    pub fn shouldAutosave(self: RecoveryState, elapsed_seconds: u64) bool {
        return self.policy.enabled and
            self.dirty and
            elapsed_seconds >= self.policy.autosave_interval_seconds and
            self.generation != self.saved_generation;
    }

    pub fn hasPendingRecovery(self: RecoveryState) bool {
        return self.recovery_path != null;
    }

    fn setLastPath(self: *RecoveryState, allocator: std.mem.Allocator, path: []const u8) !void {
        const owned = try allocator.dupe(u8, path);
        errdefer allocator.free(owned);
        if (self.last_path) |old| allocator.free(old);
        self.last_path = owned;
    }

    fn setRecoveryPath(self: *RecoveryState, allocator: std.mem.Allocator, path: []const u8) !void {
        const owned = try allocator.dupe(u8, path);
        errdefer allocator.free(owned);
        if (self.recovery_path) |old| allocator.free(old);
        self.recovery_path = owned;
    }
};

pub const WorkspaceFileReceipt = struct {
    path: []u8,
    role: WorkspaceFileRole,
    bytes: usize,
    recovery_pending: bool,

    pub fn deinit(self: WorkspaceFileReceipt, allocator: std.mem.Allocator) void {
        allocator.free(self.path);
    }
};

pub const LoadedWorkspaceFile = struct {
    snapshot: Workspace.ProjectSnapshot,
    receipt: WorkspaceFileReceipt,

    pub fn deinit(self: *LoadedWorkspaceFile, allocator: std.mem.Allocator) void {
        self.snapshot.deinit(allocator);
        self.receipt.deinit(allocator);
        self.* = undefined;
    }
};

pub const RecoveryCleanupCandidate = struct {
    path: []const u8,
    role: WorkspaceFileRole,
    saved_generation: u64,
    saved_at_ms: u64,
};

pub const RecoveryCleanupEntry = struct {
    path: []u8 = &.{},
    role: WorkspaceFileRole = .recovery,
    saved_generation: u64 = 0,
    saved_at_ms: u64 = 0,

    pub fn deinit(self: *RecoveryCleanupEntry, allocator: std.mem.Allocator) void {
        allocator.free(self.path);
        self.* = .{};
    }
};

pub const RecoveryCleanupPlan = struct {
    retained_count: usize = 0,
    delete_entries: []RecoveryCleanupEntry = &.{},

    pub fn deinit(self: *RecoveryCleanupPlan, allocator: std.mem.Allocator) void {
        for (self.delete_entries) |*entry| entry.deinit(allocator);
        allocator.free(self.delete_entries);
        self.* = .{};
    }
};

pub const RecoveryCleanupReceipt = struct {
    retained_count: usize = 0,
    deleted_count: usize = 0,
    missing_count: usize = 0,
};

pub const max_workspace_file_bytes: usize = 64 * 1024 * 1024;

pub fn retainRejectedSnapshotFile(
    allocator: std.mem.Allocator,
    io: Io,
    dir: Dir,
    path: []const u8,
) ![]u8 {
    if (path.len == 0) return error.InvalidWorkspacePath;
    const rejected_path = try std.fmt.allocPrint(allocator, "{s}.rejected", .{path});
    errdefer allocator.free(rejected_path);
    try dir.rename(path, dir, rejected_path, io);
    return rejected_path;
}

pub fn defaultWorkspacePathAlloc(
    allocator: std.mem.Allocator,
    home_dir: []const u8,
    project_name: []const u8,
    role: WorkspaceFileRole,
) ![]u8 {
    if (home_dir.len == 0) return error.InvalidWorkspacePath;

    const slug = try sanitizeProjectNameAlloc(allocator, project_name);
    defer allocator.free(slug);
    const file_name = try std.fmt.allocPrint(allocator, "{s}.dinttyws", .{slug});
    defer allocator.free(file_name);

    return switch (role) {
        .manual => std.fs.path.join(allocator, &.{
            home_dir,
            ".local",
            "share",
            "dintty",
            "workspaces",
            file_name,
        }),
        .autosave => std.fs.path.join(allocator, &.{
            home_dir,
            ".local",
            "state",
            "dintty",
            "autosave",
            file_name,
        }),
        .recovery => std.fs.path.join(allocator, &.{
            home_dir,
            ".local",
            "state",
            "dintty",
            "recovery",
            file_name,
        }),
    };
}

pub fn saveSnapshotFile(
    allocator: std.mem.Allocator,
    io: Io,
    dir: Dir,
    path: []const u8,
    snapshot: Workspace.ProjectSnapshot,
    role: WorkspaceFileRole,
    recovery_pending: bool,
) !WorkspaceFileReceipt {
    if (path.len == 0) return error.InvalidWorkspacePath;

    const bytes = try Workspace.exportSnapshotAlloc(allocator, snapshot);
    defer allocator.free(bytes);

    var atomic = try dir.createFileAtomic(io, path, .{
        .make_path = true,
        .replace = true,
    });
    defer atomic.deinit(io);
    try atomic.file.writeStreamingAll(io, bytes);
    try atomic.replace(io);

    return .{
        .path = try allocator.dupe(u8, path),
        .role = role,
        .bytes = bytes.len,
        .recovery_pending = recovery_pending,
    };
}

pub fn loadSnapshotFile(
    allocator: std.mem.Allocator,
    io: Io,
    dir: Dir,
    path: []const u8,
    role: WorkspaceFileRole,
) !LoadedWorkspaceFile {
    if (path.len == 0) return error.InvalidWorkspacePath;

    const bytes = try dir.readFileAlloc(io, path, allocator, .limited(max_workspace_file_bytes));
    defer allocator.free(bytes);

    var snapshot = try Workspace.importSnapshotAlloc(allocator, bytes);
    errdefer snapshot.deinit(allocator);
    return .{
        .snapshot = snapshot,
        .receipt = .{
            .path = try allocator.dupe(u8, path),
            .role = role,
            .bytes = bytes.len,
            .recovery_pending = role == .recovery,
        },
    };
}

pub fn planRecoveryCleanupAlloc(
    allocator: std.mem.Allocator,
    policy: RecoveryPolicy,
    candidates: []const RecoveryCleanupCandidate,
) !RecoveryCleanupPlan {
    try policy.validate();

    var retained = std.array_list.Managed(RecoveryCleanupCandidate).init(allocator);
    defer retained.deinit();
    for (candidates) |candidate| {
        if (candidate.path.len == 0) return error.InvalidWorkspacePath;
        if (candidate.role == .manual) continue;
        try retained.append(candidate);
    }

    std.mem.sort(RecoveryCleanupCandidate, retained.items, {}, newerRecoveryFirst);

    const keep_count = @min(retained.items.len, policy.max_recovery_snapshots);
    const delete_count = retained.items.len - keep_count;
    var delete_entries = try allocator.alloc(RecoveryCleanupEntry, delete_count);
    errdefer allocator.free(delete_entries);
    for (delete_entries) |*entry| entry.* = .{};
    errdefer {
        for (delete_entries) |*entry| entry.deinit(allocator);
    }

    for (retained.items[keep_count..], 0..) |candidate, idx| {
        delete_entries[idx] = try cloneCleanupEntry(allocator, candidate);
    }

    return .{
        .retained_count = keep_count,
        .delete_entries = delete_entries,
    };
}

pub fn applyRecoveryCleanup(io: Io, dir: Dir, plan: RecoveryCleanupPlan) !RecoveryCleanupReceipt {
    var receipt = RecoveryCleanupReceipt{
        .retained_count = plan.retained_count,
    };
    for (plan.delete_entries) |entry| {
        dir.deleteFile(io, entry.path) catch |err| switch (err) {
            error.FileNotFound => {
                receipt.missing_count += 1;
                continue;
            },
            else => |e| return e,
        };
        receipt.deleted_count += 1;
    }
    return receipt;
}

fn newerRecoveryFirst(_: void, lhs: RecoveryCleanupCandidate, rhs: RecoveryCleanupCandidate) bool {
    if (lhs.saved_at_ms != rhs.saved_at_ms) return lhs.saved_at_ms > rhs.saved_at_ms;
    if (lhs.saved_generation != rhs.saved_generation) return lhs.saved_generation > rhs.saved_generation;
    return std.mem.lessThan(u8, lhs.path, rhs.path);
}

fn cloneCleanupEntry(allocator: std.mem.Allocator, candidate: RecoveryCleanupCandidate) !RecoveryCleanupEntry {
    return .{
        .path = try allocator.dupe(u8, candidate.path),
        .role = candidate.role,
        .saved_generation = candidate.saved_generation,
        .saved_at_ms = candidate.saved_at_ms,
    };
}

fn sanitizeProjectNameAlloc(allocator: std.mem.Allocator, project_name: []const u8) ![]u8 {
    var out = std.array_list.Managed(u8).init(allocator);
    errdefer out.deinit();

    for (std.mem.trim(u8, project_name, " \t\r\n")) |char| {
        try out.append(if (isSafeFileChar(char)) char else '-');
    }

    if (out.items.len == 0) try out.appendSlice("workspace");
    return out.toOwnedSlice();
}

fn isSafeFileChar(char: u8) bool {
    return switch (char) {
        'a'...'z', 'A'...'Z', '0'...'9', '.', '_', '-' => true,
        else => false,
    };
}

test "default workspace paths use native data and state locations" {
    const allocator = std.testing.allocator;

    const manual = try defaultWorkspacePathAlloc(allocator, "/home/alice", "DINTTY repo", .manual);
    defer allocator.free(manual);
    try std.testing.expectEqualStrings("/home/alice/.local/share/dintty/workspaces/DINTTY-repo.dinttyws", manual);

    const autosave = try defaultWorkspacePathAlloc(allocator, "/home/alice", "DINTTY repo", .autosave);
    defer allocator.free(autosave);
    try std.testing.expectEqualStrings("/home/alice/.local/state/dintty/autosave/DINTTY-repo.dinttyws", autosave);

    const recovery = try defaultWorkspacePathAlloc(allocator, "/home/alice", "   ", .recovery);
    defer allocator.free(recovery);
    try std.testing.expectEqualStrings("/home/alice/.local/state/dintty/recovery/workspace.dinttyws", recovery);
}

test "recovery state tracks dirty autosave and clean manual saves" {
    const allocator = std.testing.allocator;
    var state = RecoveryState{};
    defer state.deinit(allocator);

    try state.policy.validate();
    try std.testing.expect(!state.shouldAutosave(1));

    state.markDirty();
    try std.testing.expect(!state.shouldAutosave(0));
    try std.testing.expect(state.shouldAutosave(1));

    try state.markSaved(allocator, "autosave/project.dinttyws", .autosave);
    try std.testing.expect(!state.dirty);
    try std.testing.expectEqualStrings("autosave/project.dinttyws", state.recovery_path.?);
    try std.testing.expect(state.hasPendingRecovery());

    state.markDirty();
    try std.testing.expect(state.hasPendingRecovery());
    try state.markSaved(allocator, "manual/project.dinttyws", .manual);
    try std.testing.expect(state.recovery_path == null);
}

fn exerciseRecoverySaveAllocationFailures(allocator: std.mem.Allocator) !void {
    var state = RecoveryState{};
    defer state.deinit(allocator);
    state.markDirty();
    try state.markSaved(allocator, "previous.dinttyws", .autosave);
    state.markDirty();
    const generation = state.generation;
    const saved_generation = state.saved_generation;
    state.markSaved(allocator, "next.dinttyws", .autosave) catch |err| {
        try std.testing.expect(state.dirty);
        try std.testing.expectEqual(generation, state.generation);
        try std.testing.expectEqual(saved_generation, state.saved_generation);
        try std.testing.expectEqualStrings("previous.dinttyws", state.last_path.?);
        try std.testing.expectEqualStrings("previous.dinttyws", state.recovery_path.?);
        return err;
    };
    try std.testing.expect(!state.dirty);
    try std.testing.expectEqual(generation, state.saved_generation);
    try std.testing.expectEqualStrings("next.dinttyws", state.last_path.?);
    try std.testing.expectEqualStrings("next.dinttyws", state.recovery_path.?);
}

test "recovery save allocation failures preserve dirty state and previous paths" {
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        exerciseRecoverySaveAllocationFailures,
        .{},
    );
}

test "damaged workspace snapshots can be retained before safe replacement" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var damaged = try tmp.dir.createFileAtomic(io, "autosave/default.dinttyws", .{
        .make_path = true,
        .replace = true,
    });
    defer damaged.deinit(io);
    try damaged.file.writeStreamingAll(io, "damaged workspace");
    try damaged.replace(io);

    const rejected_path = try retainRejectedSnapshotFile(
        allocator,
        io,
        tmp.dir,
        "autosave/default.dinttyws",
    );
    defer allocator.free(rejected_path);
    try std.testing.expectEqualStrings(
        "autosave/default.dinttyws.rejected",
        rejected_path,
    );
    const rejected = try tmp.dir.readFileAlloc(
        io,
        rejected_path,
        allocator,
        .limited(64),
    );
    defer allocator.free(rejected);
    try std.testing.expectEqualStrings("damaged workspace", rejected);
}

test "workspace snapshots save and load through atomic storage" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var ws = try Workspace.Workspace.init(allocator, "/repo/main");
    defer ws.deinit();
    _ = try ws.splitActivePane(.down);
    try ws.findPane(2).?.addTag("worker");
    _ = try ws.updateProjectPanels(.{
        .git_status = &.{.{ .path = "src/main.zig", .state = .modified }},
        .files = &.{.{ .path = "src/main.zig", .kind = .file, .dirty = true }},
    });

    var snapshot = try ws.captureSnapshot();
    defer snapshot.deinit(allocator);
    const saved = try saveSnapshotFile(allocator, io, tmp.dir, "nested/project.dinttyws", snapshot, .manual, false);
    defer saved.deinit(allocator);
    try std.testing.expect(saved.bytes > 16);

    var loaded = try loadSnapshotFile(allocator, io, tmp.dir, "nested/project.dinttyws", .manual);
    defer loaded.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 1), loaded.snapshot.tabs.len);
    try std.testing.expectEqual(@as(usize, 2), loaded.snapshot.tabs[0].panes.len);
    try std.testing.expectEqualStrings("worker", loaded.snapshot.tabs[0].panes[1].tags[0]);
    try std.testing.expectEqual(Workspace.GitFileState.modified, loaded.snapshot.project_panels.git_status[0].state);
}

test "recovery cleanup plan retains newest autosaves and ignores manual files" {
    const allocator = std.testing.allocator;

    var plan = try planRecoveryCleanupAlloc(allocator, .{ .max_recovery_snapshots = 2 }, &.{
        .{ .path = "manual/project.dinttyws", .role = .manual, .saved_generation = 9, .saved_at_ms = 9000 },
        .{ .path = "recovery/old.dinttyws", .role = .recovery, .saved_generation = 1, .saved_at_ms = 1000 },
        .{ .path = "autosave/newer.dinttyws", .role = .autosave, .saved_generation = 3, .saved_at_ms = 3000 },
        .{ .path = "recovery/newest.dinttyws", .role = .recovery, .saved_generation = 4, .saved_at_ms = 4000 },
        .{ .path = "autosave/middle.dinttyws", .role = .autosave, .saved_generation = 2, .saved_at_ms = 2000 },
    });
    defer plan.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 2), plan.retained_count);
    try std.testing.expectEqual(@as(usize, 2), plan.delete_entries.len);
    try std.testing.expectEqualStrings("autosave/middle.dinttyws", plan.delete_entries[0].path);
    try std.testing.expectEqualStrings("recovery/old.dinttyws", plan.delete_entries[1].path);
}

test "recovery cleanup applies planned file deletion" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.writeFile(io, .{ .sub_path = "newest.dinttyws", .data = "keep" });
    try tmp.dir.writeFile(io, .{ .sub_path = "middle.dinttyws", .data = "delete" });
    try tmp.dir.writeFile(io, .{ .sub_path = "old.dinttyws", .data = "delete" });

    var plan = try planRecoveryCleanupAlloc(allocator, .{ .max_recovery_snapshots = 1 }, &.{
        .{ .path = "old.dinttyws", .role = .recovery, .saved_generation = 1, .saved_at_ms = 1000 },
        .{ .path = "middle.dinttyws", .role = .autosave, .saved_generation = 2, .saved_at_ms = 2000 },
        .{ .path = "newest.dinttyws", .role = .recovery, .saved_generation = 3, .saved_at_ms = 3000 },
        .{ .path = "already-missing.dinttyws", .role = .recovery, .saved_generation = 0, .saved_at_ms = 0 },
    });
    defer plan.deinit(allocator);

    const receipt = try applyRecoveryCleanup(io, tmp.dir, plan);
    try std.testing.expectEqual(@as(usize, 1), receipt.retained_count);
    try std.testing.expectEqual(@as(usize, 2), receipt.deleted_count);
    try std.testing.expectEqual(@as(usize, 1), receipt.missing_count);

    const kept = try tmp.dir.readFileAlloc(io, "newest.dinttyws", allocator, .limited(16));
    defer allocator.free(kept);
    try std.testing.expectEqualStrings("keep", kept);
    try std.testing.expectError(error.FileNotFound, tmp.dir.readFileAlloc(io, "middle.dinttyws", allocator, .limited(16)));
    try std.testing.expectError(error.FileNotFound, tmp.dir.readFileAlloc(io, "old.dinttyws", allocator, .limited(16)));
}
