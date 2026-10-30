const std = @import("std");

pub const max_selections: usize = 256;
pub const max_selected_bytes: usize = 4096;

pub const Range = struct {
    start: u32,
    end: u32,

    pub fn isEmpty(self: Range) bool {
        return self.start == self.end;
    }
};

pub const Matches = struct {
    ranges: []Range,
    truncated: bool,

    pub fn deinit(self: *Matches, allocator: std.mem.Allocator) void {
        allocator.free(self.ranges);
        self.* = undefined;
    }
};

pub fn findAllAlloc(
    allocator: std.mem.Allocator,
    text: []const u8,
    selected: []const u8,
) !Matches {
    if (selected.len == 0) return error.EmptySelection;
    if (selected.len > max_selected_bytes) return error.SelectionTooLarge;
    if (!std.unicode.utf8ValidateSlice(text) or
        !std.unicode.utf8ValidateSlice(selected))
        return error.InvalidUtf8;

    var ranges = std.array_list.Managed(Range).init(allocator);
    errdefer ranges.deinit();
    var byte_index: usize = 0;
    var character_offset: u32 = 0;
    const selected_characters: u32 = @intCast(try std.unicode.utf8CountCodepoints(selected));
    var truncated = false;
    while (byte_index < text.len) {
        const matches = std.mem.startsWith(u8, text[byte_index..], selected) and
            (byte_index + selected.len == text.len or
                !isContinuation(text[byte_index + selected.len]));
        if (matches) {
            if (ranges.items.len >= max_selections) {
                truncated = true;
                break;
            }
            try ranges.append(.{
                .start = character_offset,
                .end = character_offset + selected_characters,
            });
            byte_index += selected.len;
            character_offset += selected_characters;
            continue;
        }
        const width = try std.unicode.utf8ByteSequenceLength(text[byte_index]);
        byte_index += width;
        character_offset += 1;
    }
    return .{ .ranges = try ranges.toOwnedSlice(), .truncated = truncated };
}

pub fn normalize(ranges: []Range) usize {
    std.mem.sort(Range, ranges, {}, lessThan);
    var output: usize = 0;
    for (ranges) |raw| {
        const current = if (raw.start <= raw.end)
            raw
        else
            Range{ .start = raw.end, .end = raw.start };
        if (output == 0) {
            ranges[0] = current;
            output = 1;
            continue;
        }
        const previous = &ranges[output - 1];
        if (current.start <= previous.end and
            !(current.isEmpty() and previous.isEmpty() and current.start == previous.end))
        {
            previous.end = @max(previous.end, current.end);
            continue;
        }
        if (current.isEmpty() and previous.isEmpty() and current.start == previous.start)
            continue;
        ranges[output] = current;
        output += 1;
    }
    return output;
}

pub fn replaceAlloc(
    allocator: std.mem.Allocator,
    text: []const u8,
    input_ranges: []const Range,
    replacement: []const u8,
) ![]u8 {
    if (!std.unicode.utf8ValidateSlice(text) or
        !std.unicode.utf8ValidateSlice(replacement))
        return error.InvalidUtf8;
    if (input_ranges.len == 0) return allocator.dupe(u8, text);
    if (input_ranges.len > max_selections) return error.TooManySelections;

    const character_count: u32 = @intCast(try std.unicode.utf8CountCodepoints(text));
    const ranges = try allocator.dupe(Range, input_ranges);
    defer allocator.free(ranges);
    const count = normalize(ranges);
    for (ranges[0..count]) |range| {
        if (range.end > character_count) return error.SelectionOutOfBounds;
    }

    var output: std.Io.Writer.Allocating = .init(allocator);
    defer output.deinit();
    var previous_character: u32 = 0;
    var previous_byte: usize = 0;
    for (ranges[0..count]) |range| {
        const start_byte = try byteOffset(text, previous_byte, previous_character, range.start);
        const end_byte = try byteOffset(text, start_byte, range.start, range.end);
        try output.writer.writeAll(text[previous_byte..start_byte]);
        try output.writer.writeAll(replacement);
        previous_byte = end_byte;
        previous_character = range.end;
    }
    try output.writer.writeAll(text[previous_byte..]);
    return output.toOwnedSlice();
}

fn lessThan(_: void, left: Range, right: Range) bool {
    const left_start = @min(left.start, left.end);
    const right_start = @min(right.start, right.end);
    if (left_start != right_start) return left_start < right_start;
    return @max(left.start, left.end) < @max(right.start, right.end);
}

fn byteOffset(
    text: []const u8,
    start_byte: usize,
    start_character: u32,
    target_character: u32,
) !usize {
    if (target_character < start_character) return error.InvalidSelectionOrder;
    var byte_index = start_byte;
    var character = start_character;
    while (character < target_character) : (character += 1) {
        if (byte_index >= text.len) return error.SelectionOutOfBounds;
        byte_index += try std.unicode.utf8ByteSequenceLength(text[byte_index]);
    }
    return byte_index;
}

fn isContinuation(byte: u8) bool {
    return byte & 0xc0 == 0x80;
}

test "finds bounded Unicode occurrences as character ranges" {
    var matches = try findAllAlloc(std.testing.allocator, "alpha α beta α", "α");
    defer matches.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 2), matches.ranges.len);
    try std.testing.expectEqual(Range{ .start = 6, .end = 7 }, matches.ranges[0]);
    try std.testing.expectEqual(Range{ .start = 13, .end = 14 }, matches.ranges[1]);
    try std.testing.expect(!matches.truncated);
}

test "normalizes overlap reversed and duplicate empty selections" {
    var ranges = [_]Range{
        .{ .start = 8, .end = 4 },
        .{ .start = 2, .end = 5 },
        .{ .start = 9, .end = 9 },
        .{ .start = 9, .end = 9 },
        .{ .start = 12, .end = 12 },
    };
    const count = normalize(&ranges);
    try std.testing.expectEqual(@as(usize, 3), count);
    try std.testing.expectEqual(Range{ .start = 2, .end = 8 }, ranges[0]);
    try std.testing.expectEqual(Range{ .start = 9, .end = 9 }, ranges[1]);
    try std.testing.expectEqual(Range{ .start = 12, .end = 12 }, ranges[2]);
}

test "replaces normalized Unicode selections in one logical transaction" {
    const output = try replaceAlloc(
        std.testing.allocator,
        "one α two α three",
        &.{
            .{ .start = 11, .end = 10 },
            .{ .start = 4, .end = 5 },
        },
        "omega",
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("one omega two omega three", output);
}

test "caps selections and rejects invalid input" {
    try std.testing.expectError(
        error.EmptySelection,
        findAllAlloc(std.testing.allocator, "text", ""),
    );
    try std.testing.expectError(
        error.InvalidUtf8,
        findAllAlloc(std.testing.allocator, "\xff", "x"),
    );
    var text: [max_selections + 8]u8 = undefined;
    @memset(&text, 'x');
    var matches = try findAllAlloc(std.testing.allocator, &text, "x");
    defer matches.deinit(std.testing.allocator);
    try std.testing.expectEqual(max_selections, matches.ranges.len);
    try std.testing.expect(matches.truncated);
}
