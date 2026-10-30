//! Toolkit-neutral terminal keys. Platform adapters own key codes and text input.

const std = @import("std");

pub const Key = enum {
    up,
    down,
    right,
    left,
    home,
    end,
    insert,
    delete,
    page_up,
    page_down,
    f1,
    f2,
    f3,
    f4,
    f5,
    f6,
    f7,
    f8,
    f9,
    f10,
    f11,
    f12,
    enter,
    backspace,
    tab,
    backtab,
    escape,
};

pub const Options = struct {
    application_cursor: bool = false,
    /// Existing xterm modifier parameter: 1 is unmodified. Applies only to
    /// navigation, editing, and function keys, not literal control bytes.
    modifier: c_int = 1,
};

/// Writes a complete sequence without a NUL terminator and returns its length.
/// Returns zero without changing output when capacity or options are invalid.
/// Application cursor mode changes only unmodified arrows, never Home/End.
/// No allocation; modified sequences retain the sharing encoder's 16-byte bound.
pub fn encode(key: Key, options: Options, output: []u8) usize {
    if (options.modifier < 1) return 0;
    const application_cursor = options.application_cursor and options.modifier == 1;
    const sequence: []const u8 = switch (key) {
        .up => if (application_cursor) "\x1bOA" else "\x1b[A",
        .down => if (application_cursor) "\x1bOB" else "\x1b[B",
        .right => if (application_cursor) "\x1bOC" else "\x1b[C",
        .left => if (application_cursor) "\x1bOD" else "\x1b[D",
        .home => "\x1b[H",
        .end => "\x1b[F",
        .insert => "\x1b[2~",
        .delete => "\x1b[3~",
        .page_up => "\x1b[5~",
        .page_down => "\x1b[6~",
        .f1 => "\x1bOP",
        .f2 => "\x1bOQ",
        .f3 => "\x1bOR",
        .f4 => "\x1bOS",
        .f5 => "\x1b[15~",
        .f6 => "\x1b[17~",
        .f7 => "\x1b[18~",
        .f8 => "\x1b[19~",
        .f9 => "\x1b[20~",
        .f10 => "\x1b[21~",
        .f11 => "\x1b[23~",
        .f12 => "\x1b[24~",
        .enter => "\r",
        .backspace => "\x7f",
        .tab => "\t",
        .backtab => "\x1b[Z",
        .escape => "\x1b",
    };
    if (options.modifier == 1) {
        if (output.len < sequence.len) return 0;
        @memcpy(output[0..sequence.len], sequence);
        return sequence.len;
    }
    switch (key) {
        .enter, .backspace, .tab, .backtab, .escape => return 0,
        else => {},
    }
    const final = sequence[sequence.len - 1];
    const parameter = if (final == '~') sequence[2 .. sequence.len - 1] else "1";
    var buffer: [16]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);
    writer.print("\x1b[{s};{d}{c}", .{ parameter, options.modifier, final }) catch return 0;
    const modified = writer.buffered();
    if (output.len < modified.len) return 0;
    @memcpy(output[0..modified.len], modified);
    return modified.len;
}

test "application cursor mode changes only unmodified arrows" {
    var output: [16]u8 = undefined;
    const cases = [_]struct { key: Key, normal: []const u8, application: []const u8, modified: []const u8 }{
        .{ .key = .up, .normal = "\x1b[A", .application = "\x1bOA", .modified = "\x1b[1;2A" },
        .{ .key = .down, .normal = "\x1b[B", .application = "\x1bOB", .modified = "\x1b[1;2B" },
        .{ .key = .right, .normal = "\x1b[C", .application = "\x1bOC", .modified = "\x1b[1;2C" },
        .{ .key = .left, .normal = "\x1b[D", .application = "\x1bOD", .modified = "\x1b[1;2D" },
        .{ .key = .home, .normal = "\x1b[H", .application = "\x1b[H", .modified = "\x1b[1;2H" },
        .{ .key = .end, .normal = "\x1b[F", .application = "\x1b[F", .modified = "\x1b[1;2F" },
        .{ .key = .f1, .normal = "\x1bOP", .application = "\x1bOP", .modified = "\x1b[1;2P" },
        .{ .key = .f12, .normal = "\x1b[24~", .application = "\x1b[24~", .modified = "\x1b[24;2~" },
    };
    for (cases) |case| {
        try std.testing.expectEqualStrings(case.normal, output[0..encode(case.key, .{}, &output)]);
        try std.testing.expectEqualStrings(case.application, output[0..encode(case.key, .{ .application_cursor = true }, &output)]);
        try std.testing.expectEqualStrings(case.modified, output[0..encode(case.key, .{ .application_cursor = true, .modifier = 2 }, &output)]);
    }
}

test "bounded encoding is atomic at every key boundary" {
    const untouched: [17]u8 = @splat(0xa5);
    for (std.meta.tags(Key)) |key| {
        for ([_]c_int{ 1, 2 }) |modifier| {
            var expected: [16]u8 = undefined;
            const options: Options = .{ .application_cursor = true, .modifier = modifier };
            const length = encode(key, options, &expected);
            if (length == 0) continue;
            for (0..length + 1) |capacity| {
                var output: [17]u8 = @splat(0xa5);
                const count = encode(key, options, output[0..capacity]);
                if (capacity < length) {
                    try std.testing.expectEqual(@as(usize, 0), count);
                    try std.testing.expectEqualSlices(u8, &untouched, &output);
                } else {
                    try std.testing.expectEqualStrings(expected[0..length], output[0..count]);
                    try std.testing.expectEqual(@as(u8, 0xa5), output[length]);
                }
            }
        }
    }
}

test "invalid modifiers and insufficient capacity leave output untouched" {
    var output: [32]u8 = @splat(0xa5);
    const untouched: [32]u8 = @splat(0xa5);
    try std.testing.expectEqual(@as(usize, 0), encode(.up, .{ .modifier = 0 }, &output));
    try std.testing.expectEqual(@as(usize, 0), encode(.up, .{ .modifier = -1 }, &output));
    try std.testing.expectEqual(@as(usize, 0), encode(.tab, .{ .modifier = 2 }, &output));
    try std.testing.expectEqual(@as(usize, 0), encode(.f12, .{ .modifier = std.math.maxInt(c_int) }, output[0..15]));
    try std.testing.expectEqualSlices(u8, &untouched, &output);
    const length = encode(.f12, .{ .modifier = std.math.maxInt(c_int) }, output[0..16]);
    try std.testing.expectEqualStrings("\x1b[24;2147483647~", output[0..length]);
    try std.testing.expectEqual(@as(u8, 0xa5), output[16]);
}
