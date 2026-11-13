const std = @import("std");

pub const extension = ".npr";
pub const max_path_bytes: usize = 4096;
pub const max_state_bytes: usize = max_path_bytes + 32;

pub const State = struct {
    root: []u8,

    pub fn deinit(self: *State, allocator: std.mem.Allocator) void {
        allocator.free(self.root);
        self.* = undefined;
    }
};

pub fn loadAlloc(
    allocator: std.mem.Allocator,
    io: std.Io,
    path: []const u8,
) !State {
    const bytes = try std.Io.Dir.cwd().readFileAlloc(
        io,
        path,
        allocator,
        .limited(max_state_bytes + 1),
    );
    defer allocator.free(bytes);
    return parseAlloc(allocator, bytes);
}

pub fn save(io: std.Io, path: []const u8, root: []const u8) !void {
    try validateRoot(root);
    var output: std.Io.Writer.Allocating = .init(std.heap.page_allocator);
    defer output.deinit();
    try output.writer.print("version=1\nroot={s}\n", .{root});
    std.debug.assert(output.writer.buffered().len <= max_state_bytes);

    var atomic = try std.Io.Dir.cwd().createFileAtomic(io, path, .{
        .permissions = @fromBackingInt(@intCast(0o600)),
        .make_path = true,
        .replace = true,
    });
    defer atomic.deinit(io);
    try atomic.file.writeStreamingAll(io, output.writer.buffered());
    try atomic.replace(io);
}

fn parseAlloc(allocator: std.mem.Allocator, bytes: []const u8) !State {
    if (bytes.len > max_state_bytes) return error.ProjectStateTooLarge;
    var version_seen = false;
    var root: ?[]u8 = null;
    errdefer if (root) |value| allocator.free(value);

    var lines = std.mem.splitScalar(u8, bytes, '\n');
    while (lines.next()) |raw| {
        const line = std.mem.trim(u8, raw, "\r");
        if (line.len == 0) continue;
        const separator = std.mem.indexOfScalar(u8, line, '=') orelse
            return error.InvalidProjectState;
        const key = line[0..separator];
        const value = line[separator + 1 ..];
        if (std.mem.eql(u8, key, "version")) {
            if (version_seen or !std.mem.eql(u8, value, "1"))
                return error.UnsupportedProjectVersion;
            version_seen = true;
        } else if (std.mem.eql(u8, key, "root")) {
            if (root != null) return error.DuplicateProjectField;
            try validateRoot(value);
            root = try allocator.dupe(u8, value);
        } else {
            return error.InvalidProjectState;
        }
    }
    if (!version_seen or root == null) return error.InvalidProjectState;
    return .{ .root = root.? };
}

fn validateRoot(root: []const u8) !void {
    if (root.len == 0 or root.len > max_path_bytes or
        !std.fs.path.isAbsolute(root) or
        !std.unicode.utf8ValidateSlice(root) or
        std.mem.indexOfAny(u8, root, "\x00\r\n") != null)
        return error.InvalidProjectRoot;
}

test "project files atomically retain one absolute root" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(io, .{ .sub_path = "project.npr", .data = "" });
    const path = try tmp.dir.realPathFileAlloc(io, "project.npr", allocator);
    defer allocator.free(path);

    try save(io, path, "/work/dintty");
    var project = try loadAlloc(allocator, io, path);
    defer project.deinit(allocator);
    try std.testing.expectEqualStrings("/work/dintty", project.root);

    const stat = try std.Io.Dir.cwd().statFile(io, path, .{});
    try std.testing.expectEqual(@as(std.posix.mode_t, 0), stat.permissions.toMode() & 0o077);
}

test "project files reject malformed and unsafe roots" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(io, .{ .sub_path = "project.npr", .data = "" });
    const path = try tmp.dir.realPathFileAlloc(io, "project.npr", allocator);
    defer allocator.free(path);

    const malformed = [_][]const u8{
        "",
        "version=1\nunknown=/work\n",
    };
    for (malformed) |contents| {
        try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = path, .data = contents });
        try std.testing.expectError(error.InvalidProjectState, loadAlloc(allocator, io, path));
    }
    try std.Io.Dir.cwd().writeFile(io, .{
        .sub_path = path,
        .data = "version=1\nroot=relative\n",
    });
    try std.testing.expectError(error.InvalidProjectRoot, loadAlloc(allocator, io, path));
    try std.Io.Dir.cwd().writeFile(io, .{
        .sub_path = path,
        .data = "version=2\nroot=/work\n",
    });
    try std.testing.expectError(error.UnsupportedProjectVersion, loadAlloc(allocator, io, path));
}
