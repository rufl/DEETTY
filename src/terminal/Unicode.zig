const std = @import("std");
const data = @import("UnicodeData.zig");

pub const unicode_version = data.unicode_version;
pub const GraphemeBreakProperty = data.GraphemeBreakProperty;
pub const IndicConjunctBreak = data.IndicConjunctBreak;

const Properties = struct {
    grapheme: GraphemeBreakProperty,
    indic: IndicConjunctBreak,
    extended_pictographic: bool,
};

const EmojiState = enum { none, pictographic, zwj_after_pictographic };
const IndicState = enum { none, consonant, linker_after_consonant };

/// Allocation-free streaming implementation of Unicode 17 UAX #29 extended
/// grapheme boundaries. `push` returns true when the scalar starts a cluster.
pub const Stream = struct {
    initialized: bool = false,
    previous: GraphemeBreakProperty = .other,
    regional_indicator_run: usize = 0,
    emoji: EmojiState = .none,
    indic: IndicState = .none,

    pub fn reset(self: *Stream) void {
        self.* = .{};
    }

    pub fn startAscii(self: *Stream) void {
        self.* = .{
            .initialized = true,
            .previous = .other,
        };
    }

    pub fn push(self: *Stream, codepoint: u21) bool {
        const current = properties(codepoint);
        if (!self.initialized) {
            self.start(current);
            return true;
        }
        const boundary = self.hasBoundary(current);
        if (boundary) self.start(current) else self.advance(current);
        return boundary;
    }

    fn start(self: *Stream, current: Properties) void {
        self.initialized = true;
        self.previous = current.grapheme;
        self.regional_indicator_run =
            if (current.grapheme == .regional_indicator) 1 else 0;
        self.emoji = nextEmoji(.none, current);
        self.indic = nextIndic(.none, current.indic);
    }

    fn hasBoundary(self: Stream, current: Properties) bool {
        const previous = self.previous;
        if (previous == .cr and current.grapheme == .lf) return false; // GB3
        if (isControl(previous) or isControl(current.grapheme)) return true; // GB4/5
        if (previous == .l and oneOf(current.grapheme, &.{ .l, .v, .lv, .lvt })) return false; // GB6
        if (oneOf(previous, &.{ .lv, .v }) and oneOf(current.grapheme, &.{ .v, .t })) return false; // GB7
        if (oneOf(previous, &.{ .lvt, .t }) and current.grapheme == .t) return false; // GB8
        if (oneOf(current.grapheme, &.{ .extend, .zwj, .spacing_mark })) return false; // GB9/9a
        if (previous == .prepend) return false; // GB9b
        if (current.indic == .consonant and self.indic == .linker_after_consonant) return false; // GB9c
        if (current.extended_pictographic and self.emoji == .zwj_after_pictographic) return false; // GB11
        if (previous == .regional_indicator and
            current.grapheme == .regional_indicator and
            self.regional_indicator_run % 2 == 1) return false; // GB12/13
        return true; // GB999
    }

    fn advance(self: *Stream, current: Properties) void {
        if (current.grapheme == .regional_indicator)
            self.regional_indicator_run += 1
        else
            self.regional_indicator_run = 0;
        self.emoji = nextEmoji(self.emoji, current);
        self.indic = nextIndic(self.indic, current.indic);
        self.previous = current.grapheme;
    }
};

pub fn scalarWidth(codepoint: u21) u2 {
    const grapheme = graphemeProperty(codepoint);
    if (isControl(grapheme) or oneOf(grapheme, &.{ .extend, .zwj, .prepend }))
        return 0;
    if (contains(codepoint, &data.wide_ranges) or
        contains(codepoint, &data.emoji_presentation_ranges)) return 2;
    return 1;
}

pub fn isExtendedPictographic(codepoint: u21) bool {
    return contains(codepoint, &data.extended_pictographic_ranges);
}

pub fn graphemeProperty(codepoint: u21) GraphemeBreakProperty {
    var low: usize = 0;
    var high: usize = data.grapheme_break_ranges.len;
    while (low < high) {
        const middle = low + (high - low) / 2;
        const range = data.grapheme_break_ranges[middle];
        if (codepoint < range.first)
            high = middle
        else if (codepoint > range.last)
            low = middle + 1
        else
            return range.value;
    }
    return .other;
}

fn properties(codepoint: u21) Properties {
    return .{
        .grapheme = graphemeProperty(codepoint),
        .indic = indicProperty(codepoint),
        .extended_pictographic = isExtendedPictographic(codepoint),
    };
}

fn indicProperty(codepoint: u21) IndicConjunctBreak {
    var low: usize = 0;
    var high: usize = data.indic_conjunct_ranges.len;
    while (low < high) {
        const middle = low + (high - low) / 2;
        const range = data.indic_conjunct_ranges[middle];
        if (codepoint < range.first)
            high = middle
        else if (codepoint > range.last)
            low = middle + 1
        else
            return range.value;
    }
    return .none;
}

fn contains(codepoint: u21, ranges: anytype) bool {
    var low: usize = 0;
    var high: usize = ranges.len;
    while (low < high) {
        const middle = low + (high - low) / 2;
        const range = ranges[middle];
        if (codepoint < range.first)
            high = middle
        else if (codepoint > range.last)
            low = middle + 1
        else
            return true;
    }
    return false;
}

fn nextEmoji(previous: EmojiState, current: Properties) EmojiState {
    if (current.extended_pictographic) return .pictographic;
    if (current.grapheme == .extend and previous == .pictographic) return .pictographic;
    if (current.grapheme == .zwj and previous == .pictographic) return .zwj_after_pictographic;
    return .none;
}

fn nextIndic(previous: IndicState, current: IndicConjunctBreak) IndicState {
    return switch (current) {
        .none => .none,
        .consonant => .consonant,
        .extend => switch (previous) {
            .consonant, .linker_after_consonant => previous,
            .none => .none,
        },
        .linker => switch (previous) {
            .consonant, .linker_after_consonant => .linker_after_consonant,
            .none => .none,
        },
    };
}

fn isControl(property: GraphemeBreakProperty) bool {
    return oneOf(property, &.{ .control, .cr, .lf });
}

fn oneOf(value: GraphemeBreakProperty, values: []const GraphemeBreakProperty) bool {
    for (values) |candidate| if (value == candidate) return true;
    return false;
}

test "Unicode 17 width policy covers combining wide and emoji scalars" {
    try std.testing.expectEqual(@as(u2, 1), scalarWidth('A'));
    try std.testing.expectEqual(@as(u2, 0), scalarWidth(0x0301));
    try std.testing.expectEqual(@as(u2, 2), scalarWidth(0x754c));
    try std.testing.expectEqual(@as(u2, 2), scalarWidth(0x1f680));
    try std.testing.expectEqual(@as(u2, 0), scalarWidth(0x200d));
}

test "Unicode 17 complete extended grapheme conformance corpus" {
    const corpus = @embedFile("fixtures/GraphemeBreakTest-17.0.0.txt");
    try std.testing.expectEqual(@as(usize, 766), try validateGraphemeBreakCorpus(corpus));
}

/// Validates the official GraphemeBreakTest text format without allocation.
/// Kept public so qualification runners can exercise the same production
/// streaming implementation without duplicating the conformance parser.
pub fn validateGraphemeBreakCorpus(corpus: []const u8) !usize {
    var lines = std.mem.splitScalar(u8, corpus, '\n');
    var case_count: usize = 0;
    while (lines.next()) |raw_line| {
        const comment = std.mem.indexOfScalar(u8, raw_line, '#') orelse raw_line.len;
        const line = std.mem.trim(u8, raw_line[0..comment], " \t\r");
        if (line.len == 0) continue;
        try validateConformanceLine(line);
        case_count += 1;
    }
    return case_count;
}

fn validateConformanceLine(line: []const u8) !void {
    var stream = Stream{};
    var tokens = std.mem.tokenizeAny(u8, line, " \t");
    var expected_boundary = true;
    var scalar_count: usize = 0;
    while (tokens.next()) |token| {
        if (std.mem.eql(u8, token, "\xc3\xb7")) {
            expected_boundary = true;
            continue;
        }
        if (std.mem.eql(u8, token, "\xc3\x97")) {
            expected_boundary = false;
            continue;
        }
        const parsed = try std.fmt.parseUnsigned(u21, token, 16);
        if (expected_boundary != stream.push(parsed))
            return error.GraphemeBoundaryMismatch;
        scalar_count += 1;
    }
    if (scalar_count == 0) return error.EmptyGraphemeCase;
}
