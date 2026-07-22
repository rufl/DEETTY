const std = @import("std");

pub const Action = enum { check, build, test_project, run };

pub const Plan = struct {
    name: []const u8,
    argv: []const []const u8,
};

pub fn detect(io: std.Io, root: []const u8, action: Action) ?Plan {
    if (has(io, root, "build.zig")) return plan("Zig", action, &.{ "zig", "build", "check" }, &.{ "zig", "build" }, &.{ "zig", "build", "test" }, &.{ "zig", "build", "run" });
    if (has(io, root, "Makefile") or has(io, root, "makefile"))
        return plan("Make", action, &.{ "make", "check" }, &.{"make"}, &.{ "make", "test" }, &.{ "make", "run" });
    return null;
}

fn plan(name: []const u8, action: Action, check: []const []const u8, build: []const []const u8, test_argv: []const []const u8, run: []const []const u8) Plan {
    return .{ .name = name, .argv = switch (action) {
        .check => check,
        .build => build,
        .test_project => test_argv,
        .run => run,
    } };
}

fn has(io: std.Io, root: []const u8, name: []const u8) bool {
    const path = std.fs.path.join(std.heap.page_allocator, &.{ root, name }) catch return false;
    defer std.heap.page_allocator.free(path);
    _ = std.Io.Dir.cwd().statFile(io, path, .{}) catch return false;
    return true;
}

pub const Result = struct {
    output: []u8,
    success: bool,
};

pub fn runAlloc(allocator: std.mem.Allocator, io: std.Io, root: []const u8, plan_value: Plan) !Result {
    const result = try std.process.run(allocator, io, .{
        .argv = plan_value.argv,
        .cwd = .{ .path = root },
        .stdout_limit = .limited(1024 * 1024),
        .stderr_limit = .limited(1024 * 1024),
        .timeout = .{ .duration = .{ .raw = .fromSeconds(120), .clock = .awake } },
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);
    var output: std.Io.Writer.Allocating = .init(allocator);
    errdefer output.deinit();
    try output.writer.writeAll(result.stdout);
    try output.writer.writeAll(result.stderr);
    return .{
        .output = try output.toOwnedSlice(),
        .success = switch (result.term) {
            .exited => |code| code == 0,
            else => false,
        },
    };
}

test "detects Zig project actions" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "build.zig", .data = "" });
    var root_buffer: [std.fs.max_path_bytes]u8 = undefined;
    const root_length = try tmp.dir.realPath(std.testing.io, &root_buffer);
    const root = root_buffer[0..root_length];
    const detected = detect(std.testing.io, root, .test_project).?;
    try std.testing.expectEqualStrings("Zig", detected.name);
    try std.testing.expectEqualStrings("test", detected.argv[2]);
}
