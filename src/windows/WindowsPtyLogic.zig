//! Platform-neutral bounded ring logic used by the Win32 ConPTY reader.

const std = @import("std");

pub const OutputRing = struct {
    storage: []u8,
    start: usize = 0,
    length: usize = 0,

    pub fn init(storage: []u8) OutputRing {
        std.debug.assert(storage.len > 0);
        return .{ .storage = storage };
    }

    pub fn write(self: *OutputRing, input: []const u8) usize {
        const available = self.storage.len - self.length;
        const count = @min(input.len, available);
        const write_at = (self.start + self.length) % self.storage.len;
        const first = @min(count, self.storage.len - write_at);
        @memcpy(self.storage[write_at..][0..first], input[0..first]);
        if (count > first) {
            @memcpy(self.storage[0 .. count - first], input[first..count]);
        }
        self.length += count;
        return count;
    }

    pub fn read(self: *OutputRing, output: []u8) usize {
        const count = @min(self.length, output.len);
        const first = @min(count, self.storage.len - self.start);
        @memcpy(output[0..first], self.storage[self.start..][0..first]);
        if (count > first) {
            @memcpy(output[first..count], self.storage[0 .. count - first]);
        }
        self.start = (self.start + count) % self.storage.len;
        self.length -= count;
        return count;
    }
};

test "output ring preserves wrapped byte order" {
    var storage: [8]u8 = undefined;
    var ring = OutputRing.init(&storage);
    try std.testing.expectEqual(@as(usize, 6), ring.write("abcdef"));
    var first: [4]u8 = undefined;
    try std.testing.expectEqual(@as(usize, 4), ring.read(&first));
    try std.testing.expectEqualSlices(u8, "abcd", &first);
    try std.testing.expectEqual(@as(usize, 6), ring.write("ghijkl"));
    var output: [8]u8 = undefined;
    try std.testing.expectEqual(@as(usize, 8), ring.read(&output));
    try std.testing.expectEqualSlices(u8, "efghijkl", &output);
}

test "output ring rejects bytes beyond fixed capacity" {
    var storage: [4]u8 = undefined;
    var ring = OutputRing.init(&storage);
    try std.testing.expectEqual(@as(usize, 4), ring.write("abcdef"));
    try std.testing.expectEqual(@as(usize, 0), ring.write("z"));
    var output: [6]u8 = undefined;
    try std.testing.expectEqual(@as(usize, 4), ring.read(&output));
    try std.testing.expectEqualSlices(u8, "abcd", output[0..4]);
}
