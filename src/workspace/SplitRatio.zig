//! Allocation-free proportional split arithmetic shared by native frontends.
const std = @import("std");

/// Nearest integral position; ties round toward the second child's origin.
pub fn position(extent: u32, ratio: u16) u32 {
    return @intCast((@as(u64, extent) * @min(ratio, 1000) + 500) / 1000);
}

/// Clamp before multiplication so even extreme signed pointer positions are safe.
pub fn fromPosition(offset: i64, extent: u32) u16 {
    if (extent == 0 or offset <= 0) return 0;
    if (offset >= extent) return 1000;
    return @intCast((@as(u64, @intCast(offset)) * 1000 + extent / 2) / extent);
}

test "split ratios: nearest rounding, exact remainders and extreme extents" {
    try std.testing.expectEqual(@as(u32, 2), position(3, 500));
    try std.testing.expectEqual(@as(u32, 0), position(0, 1000));
    try std.testing.expectEqual(std.math.maxInt(u32), position(std.math.maxInt(u32), std.math.maxInt(u16)));
    try std.testing.expectEqual(@as(u32, 2_147_483_648), position(std.math.maxInt(u32), 500));
    for ([_]u32{ 1, 3, 17, 1_000_000, std.math.maxInt(u32) }) |extent| {
        var previous: u32 = 0;
        for (0..1001) |ratio| {
            const first = position(extent, @intCast(ratio));
            try std.testing.expect(first >= previous and first <= extent);
            try std.testing.expectEqual(extent, first + (extent - first));
            previous = first;
        }
    }
}

test "split ratios: inverse clamps signed extremes and rounds nearest" {
    try std.testing.expectEqual(@as(u16, 0), fromPosition(std.math.minInt(i64), 1));
    try std.testing.expectEqual(@as(u16, 1000), fromPosition(std.math.maxInt(i64), std.math.maxInt(u32)));
    try std.testing.expectEqual(@as(u16, 0), fromPosition(42, 0));
    try std.testing.expectEqual(@as(u16, 167), fromPosition(1, 6));
    try std.testing.expectEqual(@as(u16, 1), fromPosition(1, 2000));
    for (0..1001) |ratio| {
        try std.testing.expectEqual(@as(u16, @intCast(ratio)), fromPosition(position(std.math.maxInt(u32), @intCast(ratio)), std.math.maxInt(u32)));
    }
}
