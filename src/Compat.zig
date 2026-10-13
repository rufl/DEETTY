const std = @import("std");

pub fn dupeZ(allocator: std.mem.Allocator, bytes: []const u8) ![:0]u8 {
    const result = try allocator.allocSentinel(u8, bytes.len, 0);
    @memcpy(result, bytes);
    return result;
}

pub fn bufPrintZ(
    buffer: []u8,
    comptime format: []const u8,
    args: anytype,
) ![:0]u8 {
    if (buffer.len == 0) return error.NoSpaceLeft;
    const written = try std.fmt.bufPrint(buffer[0 .. buffer.len - 1], format, args);
    buffer[written.len] = 0;
    return buffer[0..written.len :0];
}
