//! Generates DINTTY's pinned Unicode terminal lookup tables.

const std = @import("std");

const file_bytes_max: usize = 16 * 1024 * 1024;
const range_count_max: usize = 200_000;

const Range = struct {
    first: u21,
    last: u21,
};

const PropertyRange = struct {
    first: u21,
    last: u21,
    value: []const u8,
};

const Lock = struct {
    unicode_version: []const u8,
    generated_output: Output,
    files: []const File,

    const Output = struct {
        name: []const u8,
        sha256: []const u8,
    };

    const File = struct {
        name: []const u8,
        sha256: []const u8,
    };
};

const Arguments = struct {
    lock_path: []const u8,
    input_directory: []const u8,
    output_path: []const u8,
};

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const options = try parseArguments(args);
    try generate(init.gpa, init.io, options);
}

fn parseArguments(args: []const []const u8) !Arguments {
    var lock_path: ?[]const u8 = null;
    var input_directory: ?[]const u8 = null;
    var output_path: ?[]const u8 = null;
    var index: usize = 1;
    while (index < args.len) : (index += 2) {
        if (index + 1 >= args.len) return error.InvalidArguments;
        if (std.mem.eql(u8, args[index], "--lock")) {
            lock_path = args[index + 1];
        } else if (std.mem.eql(u8, args[index], "--input-dir")) {
            input_directory = args[index + 1];
        } else if (std.mem.eql(u8, args[index], "--output")) {
            output_path = args[index + 1];
        } else {
            return error.InvalidArguments;
        }
    }
    return .{
        .lock_path = lock_path orelse return error.MissingLockPath,
        .input_directory = input_directory orelse return error.MissingInputDirectory,
        .output_path = output_path orelse return error.MissingOutputPath,
    };
}

fn generate(gpa: std.mem.Allocator, io: std.Io, options: Arguments) !void {
    const lock_bytes = try readFileAlloc(gpa, io, options.lock_path);
    defer gpa.free(lock_bytes);
    var parsed_lock = try std.json.parseFromSlice(Lock, gpa, lock_bytes, .{
        .ignore_unknown_fields = true,
    });
    defer parsed_lock.deinit();
    const lock = parsed_lock.value;
    if (!std.mem.eql(u8, lock.unicode_version, "17.0.0"))
        return error.UnsupportedUnicodeVersion;
    if (!std.mem.eql(u8, lock.generated_output.name, "src/terminal/UnicodeData.zig"))
        return error.UnexpectedGeneratedOutput;

    var grapheme = std.array_list.Managed(PropertyRange).init(gpa);
    defer grapheme.deinit();
    var indic = std.array_list.Managed(PropertyRange).init(gpa);
    defer indic.deinit();
    var extended = std.array_list.Managed(Range).init(gpa);
    defer extended.deinit();
    var emoji_presentation = std.array_list.Managed(Range).init(gpa);
    defer emoji_presentation.deinit();
    var wide = std.array_list.Managed(Range).init(gpa);
    defer wide.deinit();

    for (lock.files) |file| {
        const path = try std.fs.path.join(gpa, &.{ options.input_directory, file.name });
        defer gpa.free(path);
        const contents = try readFileAlloc(gpa, io, path);
        defer gpa.free(contents);
        try verifyHash(contents, file.sha256);
        if (std.mem.eql(u8, file.name, "GraphemeBreakTest.txt")) continue;
        if (std.mem.eql(u8, file.name, "GraphemeBreakProperty.txt")) {
            try collectGrapheme(&grapheme, contents);
        } else if (std.mem.eql(u8, file.name, "DerivedCoreProperties.txt")) {
            try collectIndic(&indic, contents);
        } else if (std.mem.eql(u8, file.name, "emoji-data.txt")) {
            try collectEmoji(&extended, &emoji_presentation, contents);
        } else if (std.mem.eql(u8, file.name, "EastAsianWidth.txt")) {
            try collectWide(&wide, contents);
        }
    }

    var output: std.Io.Writer.Allocating = .init(gpa);
    defer output.deinit();
    try render(
        &output.writer,
        &grapheme,
        &indic,
        &extended,
        &emoji_presentation,
        &wide,
    );
    const rendered = output.writer.buffered();
    try verifyHash(rendered, lock.generated_output.sha256);
    var atomic = try std.Io.Dir.cwd().createFileAtomic(io, options.output_path, .{
        .make_path = true,
        .replace = true,
    });
    defer atomic.deinit(io);
    try atomic.file.writeStreamingAll(io, rendered);
    try atomic.replace(io);
}

fn readFileAlloc(gpa: std.mem.Allocator, io: std.Io, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(io, path, gpa, .limited(file_bytes_max));
}

fn verifyHash(bytes: []const u8, expected_hex: []const u8) !void {
    if (expected_hex.len != std.crypto.hash.sha2.Sha256.digest_length * 2)
        return error.InvalidSha256;
    var digest: [std.crypto.hash.sha2.Sha256.digest_length]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    var rendered: [digest.len * 2]u8 = undefined;
    _ = std.fmt.bufPrint(&rendered, "{x}", .{digest}) catch unreachable;
    if (!std.mem.eql(u8, &rendered, expected_hex)) return error.HashMismatch;
}

fn parseRange(text: []const u8) !Range {
    const separator = std.mem.indexOf(u8, text, "..");
    const first_text = if (separator) |offset| text[0..offset] else text;
    const last_text = if (separator) |offset| text[offset + 2 ..] else text;
    const first = try std.fmt.parseInt(u21, std.mem.trim(u8, first_text, " \t"), 16);
    const last = try std.fmt.parseInt(u21, std.mem.trim(u8, last_text, " \t"), 16);
    if (first > last) return error.InvalidRange;
    return .{ .first = first, .last = last };
}

fn RecordIterator() type {
    return struct {
        lines: std.mem.SplitIterator(u8, .scalar),

        const Record = struct {
            bounds: Range,
            fields: []const u8,
        };

        fn init(contents: []const u8) @This() {
            return .{ .lines = std.mem.splitScalar(u8, contents, '\n') };
        }

        fn next(self: *@This()) !?Record {
            while (self.lines.next()) |raw| {
                const comment = std.mem.indexOfScalar(u8, raw, '#') orelse raw.len;
                const line = std.mem.trim(u8, raw[0..comment], " \t\r");
                if (line.len == 0) continue;
                const separator = std.mem.indexOfScalar(u8, line, ';') orelse
                    return error.InvalidUnicodeRecord;
                return .{
                    .bounds = try parseRange(line[0..separator]),
                    .fields = std.mem.trim(u8, line[separator + 1 ..], " \t"),
                };
            }
            return null;
        }
    };
}

fn appendProperty(
    output: *std.array_list.Managed(PropertyRange),
    bounds: Range,
    value: []const u8,
) !void {
    if (output.items.len >= range_count_max) return error.TooManyUnicodeRanges;
    try output.append(.{ .first = bounds.first, .last = bounds.last, .value = value });
}

fn appendRange(output: *std.array_list.Managed(Range), bounds: Range) !void {
    if (output.items.len >= range_count_max) return error.TooManyUnicodeRanges;
    try output.append(bounds);
}

fn graphemeName(value: []const u8) ![]const u8 {
    const names = [_]struct { source: []const u8, target: []const u8 }{
        .{ .source = "CR", .target = "cr" },
        .{ .source = "LF", .target = "lf" },
        .{ .source = "Control", .target = "control" },
        .{ .source = "Extend", .target = "extend" },
        .{ .source = "ZWJ", .target = "zwj" },
        .{ .source = "Regional_Indicator", .target = "regional_indicator" },
        .{ .source = "Prepend", .target = "prepend" },
        .{ .source = "SpacingMark", .target = "spacing_mark" },
        .{ .source = "L", .target = "l" },
        .{ .source = "V", .target = "v" },
        .{ .source = "T", .target = "t" },
        .{ .source = "LV", .target = "lv" },
        .{ .source = "LVT", .target = "lvt" },
    };
    for (names) |name| {
        if (std.mem.eql(u8, value, name.source)) return name.target;
    }
    return error.UnsupportedGraphemeProperty;
}

fn firstField(fields: []const u8) []const u8 {
    const separator = std.mem.indexOfScalar(u8, fields, ';') orelse fields.len;
    return std.mem.trim(u8, fields[0..separator], " \t");
}

fn secondField(fields: []const u8) ![]const u8 {
    const separator = std.mem.indexOfScalar(u8, fields, ';') orelse
        return error.MissingUnicodeField;
    return std.mem.trim(u8, fields[separator + 1 ..], " \t");
}

fn collectGrapheme(output: *std.array_list.Managed(PropertyRange), contents: []const u8) !void {
    var records = RecordIterator().init(contents);
    while (try records.next()) |record| {
        try appendProperty(output, record.bounds, try graphemeName(firstField(record.fields)));
    }
}

fn collectIndic(output: *std.array_list.Managed(PropertyRange), contents: []const u8) !void {
    var records = RecordIterator().init(contents);
    while (try records.next()) |record| {
        if (!std.mem.eql(u8, firstField(record.fields), "InCB")) continue;
        const source = try secondField(record.fields);
        const value = if (std.mem.eql(u8, source, "Linker"))
            "linker"
        else if (std.mem.eql(u8, source, "Consonant"))
            "consonant"
        else if (std.mem.eql(u8, source, "Extend"))
            "extend"
        else
            return error.UnsupportedIndicProperty;
        try appendProperty(output, record.bounds, value);
    }
}

fn collectEmoji(
    extended: *std.array_list.Managed(Range),
    presentation: *std.array_list.Managed(Range),
    contents: []const u8,
) !void {
    var records = RecordIterator().init(contents);
    while (try records.next()) |record| {
        const property = firstField(record.fields);
        if (std.mem.eql(u8, property, "Extended_Pictographic")) {
            try appendRange(extended, record.bounds);
        } else if (std.mem.eql(u8, property, "Emoji_Presentation")) {
            try appendRange(presentation, record.bounds);
        }
    }
}

fn collectWide(output: *std.array_list.Managed(Range), contents: []const u8) !void {
    var records = RecordIterator().init(contents);
    while (try records.next()) |record| {
        const property = firstField(record.fields);
        if (std.mem.eql(u8, property, "W") or std.mem.eql(u8, property, "F"))
            try appendRange(output, record.bounds);
    }
}

fn rangeLessThan(_: void, left: Range, right: Range) bool {
    return left.first < right.first or left.first == right.first and left.last < right.last;
}

fn propertyLessThan(_: void, left: PropertyRange, right: PropertyRange) bool {
    return left.first < right.first or left.first == right.first and left.last < right.last;
}

fn mergeRanges(ranges: *std.array_list.Managed(Range)) void {
    std.mem.sort(Range, ranges.items, {}, rangeLessThan);
    var output_count: usize = 0;
    for (ranges.items) |item| {
        if (output_count != 0 and item.first <= @as(u22, ranges.items[output_count - 1].last) + 1) {
            ranges.items[output_count - 1].last = @max(ranges.items[output_count - 1].last, item.last);
        } else {
            ranges.items[output_count] = item;
            output_count += 1;
        }
    }
    ranges.shrinkRetainingCapacity(output_count);
}

fn emitProperties(
    writer: *std.Io.Writer,
    name: []const u8,
    type_name: []const u8,
    ranges: *std.array_list.Managed(PropertyRange),
) !void {
    std.mem.sort(PropertyRange, ranges.items, {}, propertyLessThan);
    try writer.print("pub const {s} = [_]{s}{{\n", .{ name, type_name });
    for (ranges.items) |item| {
        try writer.print(
            "    .{{ .first = 0x{X}, .last = 0x{X}, .value = .{s} }},\n",
            .{ item.first, item.last, item.value },
        );
    }
    try writer.writeAll("};\n\n");
}

fn emitRanges(
    writer: *std.Io.Writer,
    name: []const u8,
    ranges: *std.array_list.Managed(Range),
    final: bool,
) !void {
    mergeRanges(ranges);
    try writer.print("pub const {s} = [_]Range{{\n", .{name});
    for (ranges.items) |item| {
        try writer.print(
            "    .{{ .first = 0x{X}, .last = 0x{X} }},\n",
            .{ item.first, item.last },
        );
    }
    try writer.writeAll(if (final) "};\n" else "};\n\n");
}

fn render(
    writer: *std.Io.Writer,
    grapheme: *std.array_list.Managed(PropertyRange),
    indic: *std.array_list.Managed(PropertyRange),
    extended: *std.array_list.Managed(Range),
    emoji_presentation: *std.array_list.Managed(Range),
    wide: *std.array_list.Managed(Range),
) !void {
    try writer.writeAll(
        \\//! Generated from pinned Unicode 17.0.0 data. Do not edit.
        \\//! Regenerate with tools/generate_terminal_unicode.zig.
        \\
        \\pub const unicode_version = "17.0.0";
        \\
        \\pub const GraphemeBreakProperty = enum(u8) {
        \\    other, cr, lf, control, extend, zwj, regional_indicator,
        \\    prepend, spacing_mark, l, v, t, lv, lvt,
        \\};
        \\
        \\pub const IndicConjunctBreak = enum(u8) { none, linker, consonant, extend };
        \\
        \\pub const Range = struct { first: u21, last: u21 };
        \\pub const PropertyRange = struct {
        \\    first: u21,
        \\    last: u21,
        \\    value: GraphemeBreakProperty,
        \\};
        \\pub const IndicRange = struct {
        \\    first: u21,
        \\    last: u21,
        \\    value: IndicConjunctBreak,
        \\};
        \\
    );
    try emitProperties(writer, "grapheme_break_ranges", "PropertyRange", grapheme);
    try emitProperties(writer, "indic_conjunct_ranges", "IndicRange", indic);
    try emitRanges(writer, "extended_pictographic_ranges", extended, false);
    try emitRanges(writer, "emoji_presentation_ranges", emoji_presentation, false);
    try emitRanges(writer, "wide_ranges", wide, true);
}

test "range parsing and merging preserve sorted inclusive bounds" {
    try std.testing.expectEqual(Range{ .first = 0x41, .last = 0x43 }, try parseRange("0041..0043"));
    try std.testing.expectEqual(Range{ .first = 0x20, .last = 0x20 }, try parseRange("0020"));
    var ranges = std.array_list.Managed(Range).init(std.testing.allocator);
    defer ranges.deinit();
    try ranges.appendSlice(&.{
        .{ .first = 8, .last = 9 },
        .{ .first = 1, .last = 3 },
        .{ .first = 4, .last = 6 },
    });
    mergeRanges(&ranges);
    try std.testing.expectEqualSlices(Range, &.{
        .{ .first = 1, .last = 6 },
        .{ .first = 8, .last = 9 },
    }, ranges.items);
}

test "SHA-256 verification accepts exact lowercase lock digests" {
    try verifyHash(
        "abc",
        "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
    );
    try std.testing.expectError(
        error.HashMismatch,
        verifyHash(
            "abd",
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
        ),
    );
}

test "record parsing strips comments and maps pinned properties" {
    var grapheme = std.array_list.Managed(PropertyRange).init(std.testing.allocator);
    defer grapheme.deinit();
    try collectGrapheme(&grapheme,
        \\000D ; CR # carriage return
        \\0300..0301 ; Extend
        \\
    );
    try std.testing.expectEqual(@as(usize, 2), grapheme.items.len);
    try std.testing.expectEqualStrings("cr", grapheme.items[0].value);
    try std.testing.expectEqualStrings("extend", grapheme.items[1].value);
}
