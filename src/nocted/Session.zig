const std = @import("std");

pub const max_recent_projects: usize = 8;
pub const max_open_files: usize = 32;
pub const max_path_bytes: usize = 4096;
pub const max_state_bytes: usize = 64 * 1024;

pub const State = struct {
    recent_projects: std.array_list.Managed([]u8),
    project: ?[]u8 = null,
    open_files: std.array_list.Managed([]u8),
    active_file: ?[]u8 = null,

    pub fn init(allocator: std.mem.Allocator) State {
        return .{
            .recent_projects = std.array_list.Managed([]u8).init(allocator),
            .open_files = std.array_list.Managed([]u8).init(allocator),
        };
    }

    pub fn deinit(self: *State, allocator: std.mem.Allocator) void {
        clearList(allocator, &self.recent_projects);
        clearList(allocator, &self.open_files);
        if (self.project) |value| allocator.free(value);
        if (self.active_file) |value| allocator.free(value);
        self.recent_projects.deinit();
        self.open_files.deinit();
        self.* = undefined;
    }

    pub fn rememberProject(
        self: *State,
        allocator: std.mem.Allocator,
        project: []const u8,
    ) !void {
        try validatePath(project);
        var existing_index: ?usize = null;
        for (self.recent_projects.items, 0..) |existing, index| {
            if (std.mem.eql(u8, existing, project)) existing_index = index;
        }
        if (existing_index) |index| allocator.free(self.recent_projects.orderedRemove(index));
        try self.recent_projects.insert(0, try allocator.dupe(u8, project));
        while (self.recent_projects.items.len > max_recent_projects)
            allocator.free(self.recent_projects.pop().?);
    }

    pub fn clearRecentProjects(
        self: *State,
        allocator: std.mem.Allocator,
    ) void {
        clearList(allocator, &self.recent_projects);
    }

    pub fn setSession(
        self: *State,
        allocator: std.mem.Allocator,
        project: ?[]const u8,
        open_files: []const []const u8,
        active_file: ?[]const u8,
    ) !void {
        if (open_files.len > max_open_files) return error.TooManyOpenFiles;
        if (project) |value| try validatePath(value);
        if (active_file) |value| try validatePath(value);
        for (open_files, 0..) |value, index| {
            try validatePath(value);
            for (open_files[0..index]) |previous|
                if (std.mem.eql(u8, value, previous)) return error.DuplicateOpenFile;
        }
        if (active_file) |active| {
            var found = false;
            for (open_files) |value| found = found or std.mem.eql(u8, active, value);
            if (!found) return error.ActiveFileNotOpen;
        }

        const new_project = if (project) |value| try allocator.dupe(u8, value) else null;
        errdefer if (new_project) |value| allocator.free(value);
        const new_active = if (active_file) |value| try allocator.dupe(u8, value) else null;
        errdefer if (new_active) |value| allocator.free(value);
        var new_files = std.array_list.Managed([]u8).init(allocator);
        errdefer {
            clearList(allocator, &new_files);
            new_files.deinit();
        }
        for (open_files) |value| try new_files.append(try allocator.dupe(u8, value));

        if (self.project) |value| allocator.free(value);
        if (self.active_file) |value| allocator.free(value);
        clearList(allocator, &self.open_files);
        self.open_files.deinit();
        self.project = new_project;
        self.active_file = new_active;
        self.open_files = new_files;
    }
};

pub fn loadAlloc(
    allocator: std.mem.Allocator,
    io: std.Io,
    path: []const u8,
) !State {
    const bytes = std.Io.Dir.cwd().readFileAlloc(
        io,
        path,
        allocator,
        .limited(max_state_bytes + 1),
    ) catch |err| switch (err) {
        error.FileNotFound, error.StreamTooLong => return State.init(allocator),
        else => return err,
    };
    defer allocator.free(bytes);
    return parseAlloc(allocator, bytes) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => State.init(allocator),
    };
}

pub fn save(io: std.Io, path: []const u8, state: *const State) !void {
    var output: std.Io.Writer.Allocating = .init(std.heap.page_allocator);
    defer output.deinit();
    try output.writer.writeAll("version=1\n");
    if (state.project) |value| try output.writer.print("project={s}\n", .{value});
    if (state.active_file) |value| try output.writer.print("active={s}\n", .{value});
    for (state.recent_projects.items) |value|
        try output.writer.print("recent={s}\n", .{value});
    for (state.open_files.items) |value|
        try output.writer.print("open={s}\n", .{value});
    if (output.writer.buffered().len > max_state_bytes) return error.SessionStateTooLarge;
    var atomic = try std.Io.Dir.cwd().createFileAtomic(io, path, .{
        .make_path = true,
        .replace = true,
    });
    defer atomic.deinit(io);
    try atomic.file.writeStreamingAll(io, output.writer.buffered());
    try atomic.replace(io);
}

fn parseAlloc(allocator: std.mem.Allocator, bytes: []const u8) !State {
    if (bytes.len > max_state_bytes) return error.SessionStateTooLarge;
    var state = State.init(allocator);
    errdefer state.deinit(allocator);
    var version_ok = false;
    var lines = std.mem.splitScalar(u8, bytes, '\n');
    while (lines.next()) |raw| {
        const line = std.mem.trim(u8, raw, "\r");
        if (line.len == 0) continue;
        const separator = std.mem.indexOfScalar(u8, line, '=') orelse
            return error.InvalidSessionState;
        const key = line[0..separator];
        const value = line[separator + 1 ..];
        if (std.mem.eql(u8, key, "version")) {
            if (!std.mem.eql(u8, value, "1")) return error.UnsupportedSessionVersion;
            version_ok = true;
        } else if (std.mem.eql(u8, key, "project")) {
            try setOptional(allocator, &state.project, value);
        } else if (std.mem.eql(u8, key, "active")) {
            try setOptional(allocator, &state.active_file, value);
        } else if (std.mem.eql(u8, key, "recent")) {
            if (state.recent_projects.items.len >= max_recent_projects)
                return error.TooManyRecentProjects;
            try validatePath(value);
            if (contains(state.recent_projects.items, value))
                return error.DuplicateRecentProject;
            try state.recent_projects.append(try allocator.dupe(u8, value));
        } else if (std.mem.eql(u8, key, "open")) {
            if (state.open_files.items.len >= max_open_files)
                return error.TooManyOpenFiles;
            try validatePath(value);
            if (contains(state.open_files.items, value))
                return error.DuplicateOpenFile;
            try state.open_files.append(try allocator.dupe(u8, value));
        } else {
            return error.InvalidSessionState;
        }
    }
    if (!version_ok) return error.InvalidSessionState;
    if (state.active_file) |active|
        if (!contains(state.open_files.items, active)) return error.ActiveFileNotOpen;
    return state;
}

fn contains(values: []const []u8, needle: []const u8) bool {
    for (values) |value| if (std.mem.eql(u8, value, needle)) return true;
    return false;
}

fn validatePath(path: []const u8) !void {
    if (path.len == 0 or path.len > max_path_bytes or
        !std.unicode.utf8ValidateSlice(path) or
        std.mem.indexOfAny(u8, path, "\x00\r\n") != null)
        return error.InvalidSessionPath;
}

fn setOptional(
    allocator: std.mem.Allocator,
    target: *?[]u8,
    value: []const u8,
) !void {
    if (target.* != null) return error.DuplicateSessionField;
    try validatePath(value);
    target.* = try allocator.dupe(u8, value);
}

fn clearList(
    allocator: std.mem.Allocator,
    list: *std.array_list.Managed([]u8),
) void {
    for (list.items) |value| allocator.free(value);
    list.clearRetainingCapacity();
}

test "recent projects are unique most-recent-first and bounded" {
    var state = State.init(std.testing.allocator);
    defer state.deinit(std.testing.allocator);
    for (0..max_recent_projects + 3) |index| {
        var buffer: [64]u8 = undefined;
        const path = try std.fmt.bufPrint(&buffer, "/tmp/project-{d}", .{index});
        try state.rememberProject(std.testing.allocator, path);
    }
    try std.testing.expectEqual(max_recent_projects, state.recent_projects.items.len);
    try std.testing.expectEqualStrings("/tmp/project-10", state.recent_projects.items[0]);
    try state.rememberProject(std.testing.allocator, "/tmp/project-7");
    try std.testing.expectEqualStrings("/tmp/project-7", state.recent_projects.items[0]);
    try std.testing.expectEqual(max_recent_projects, state.recent_projects.items.len);
}

test "session state round trips atomically" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(io, .{ .sub_path = "session.conf", .data = "" });
    const path = try tmp.dir.realPathFileAlloc(io, "session.conf", allocator);
    defer allocator.free(path);

    var expected = State.init(allocator);
    defer expected.deinit(allocator);
    try expected.rememberProject(allocator, "/work/two");
    try expected.rememberProject(allocator, "/work/one");
    try expected.setSession(
        allocator,
        "/work/one",
        &.{ "/work/one/a.zig", "/work/one/b.zig" },
        "/work/one/b.zig",
    );
    try save(io, path, &expected);

    var actual = try loadAlloc(allocator, io, path);
    defer actual.deinit(allocator);
    try std.testing.expectEqualStrings("/work/one", actual.project.?);
    try std.testing.expectEqual(@as(usize, 2), actual.open_files.items.len);
    try std.testing.expectEqualStrings("/work/one/b.zig", actual.active_file.?);
    try std.testing.expectEqualStrings("/work/one", actual.recent_projects.items[0]);
}

test "corrupt session falls back to empty state" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(io, .{
        .sub_path = "session.conf",
        .data = "version=99\nopen=/tmp/a\n",
    });
    const path = try tmp.dir.realPathFileAlloc(io, "session.conf", allocator);
    defer allocator.free(path);
    var state = try loadAlloc(allocator, io, path);
    defer state.deinit(allocator);
    try std.testing.expect(state.project == null);
    try std.testing.expectEqual(@as(usize, 0), state.open_files.items.len);
}

test "semantic session corruption falls back to empty state" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(io, .{
        .sub_path = "session.conf",
        .data = "version=1\nactive=/tmp/missing\nopen=/tmp/a\nopen=/tmp/a\n",
    });
    const path = try tmp.dir.realPathFileAlloc(io, "session.conf", allocator);
    defer allocator.free(path);
    var state = try loadAlloc(allocator, io, path);
    defer state.deinit(allocator);
    try std.testing.expect(state.active_file == null);
    try std.testing.expectEqual(@as(usize, 0), state.open_files.items.len);
}

test "malformed and oversized session corpus falls back to empty state" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(io, .{ .sub_path = "session.conf", .data = "" });
    const path = try tmp.dir.realPathFileAlloc(io, "session.conf", allocator);
    defer allocator.free(path);

    const malformed = [_][]const u8{
        "version=1\nproject=/tmp/a\nproject=/tmp/b\n",
        "version=1\nopen=/tmp/a\nopen=/tmp/a\n",
        "version=1\nactive=/tmp/missing\n",
        "version=1\nunknown=/tmp/a\n",
        "version=1\nopen=bad\x00path\n",
        "version=1\nopen=\xff\n",
    };
    for (malformed) |contents| {
        try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = path, .data = contents });
        var state = try loadAlloc(allocator, io, path);
        defer state.deinit(allocator);
        try std.testing.expect(state.project == null);
        try std.testing.expect(state.active_file == null);
        try std.testing.expectEqual(@as(usize, 0), state.recent_projects.items.len);
        try std.testing.expectEqual(@as(usize, 0), state.open_files.items.len);
    }

    const oversized = try allocator.alloc(u8, max_state_bytes + 1);
    defer allocator.free(oversized);
    @memset(oversized, 'x');
    try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = path, .data = oversized });
    var state = try loadAlloc(allocator, io, path);
    defer state.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 0), state.open_files.items.len);
}

test "interrupted session replacement preserves the previous state" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(io, .{ .sub_path = "session.conf", .data = "" });
    const path = try tmp.dir.realPathFileAlloc(io, "session.conf", allocator);
    defer allocator.free(path);

    var expected = State.init(allocator);
    defer expected.deinit(allocator);
    try expected.setSession(allocator, "/work", &.{"/work/a.zig"}, "/work/a.zig");
    try save(io, path, &expected);
    {
        var interrupted = try std.Io.Dir.cwd().createFileAtomic(io, path, .{
            .make_path = true,
            .replace = true,
        });
        defer interrupted.deinit(io);
        try interrupted.file.writeStreamingAll(io, "version=1\nopen=/broken\n");
    }

    var actual = try loadAlloc(allocator, io, path);
    defer actual.deinit(allocator);
    try std.testing.expectEqualStrings("/work", actual.project.?);
    try std.testing.expectEqualStrings("/work/a.zig", actual.active_file.?);
    try std.testing.expectEqual(@as(usize, 1), actual.open_files.items.len);
}
