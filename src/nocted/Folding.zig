const std = @import("std");

pub const max_regions: usize = 4096;
pub const max_nesting: usize = 256;

pub const Region = struct {
    anchor_line: u32,
    first_hidden_line: u32,
    end_line_exclusive: u32,

    pub fn hiddenLineCount(self: Region) u32 {
        return self.end_line_exclusive - self.first_hidden_line;
    }
};

pub const Analysis = struct {
    regions: std.array_list.Managed(Region),
    truncated: bool,

    pub fn deinit(self: *Analysis) void {
        self.regions.deinit();
        self.* = undefined;
    }

    pub fn regionAtLine(self: *const Analysis, line: u32) ?Region {
        for (self.regions.items) |region| {
            if (region.anchor_line == line) return region;
        }
        return null;
    }
};

const Line = struct {
    number: u32,
    indent: usize,
};

const OpenRegion = struct {
    region_index: usize,
    base_indent: usize,
};

pub fn analyzeAlloc(
    allocator: std.mem.Allocator,
    text: []const u8,
    tab_width: usize,
) !Analysis {
    if (tab_width == 0) return error.InvalidTabWidth;
    var analysis = Analysis{
        .regions = std.array_list.Managed(Region).init(allocator),
        .truncated = false,
    };
    errdefer analysis.deinit();

    var open_regions: [max_nesting]OpenRegion = undefined;
    var open_count: usize = 0;
    var previous: ?Line = null;
    var line_number: u32 = 0;
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |line_text| : (line_number += 1) {
        const indent = indentation(line_text, tab_width) orelse continue;

        while (open_count > 0 and indent <= open_regions[open_count - 1].base_indent) {
            open_count -= 1;
            const open = open_regions[open_count];
            analysis.regions.items[open.region_index].end_line_exclusive =
                previous.?.number + 1;
        }

        if (previous) |last| {
            if (indent > last.indent) {
                if (analysis.regions.items.len >= max_regions or open_count >= max_nesting) {
                    analysis.truncated = true;
                } else {
                    try analysis.regions.append(.{
                        .anchor_line = last.number,
                        .first_hidden_line = last.number + 1,
                        .end_line_exclusive = 0,
                    });
                    open_regions[open_count] = .{
                        .region_index = analysis.regions.items.len - 1,
                        .base_indent = last.indent,
                    };
                    open_count += 1;
                }
            }
        }
        previous = .{ .number = line_number, .indent = indent };
    }

    if (previous) |last| {
        while (open_count > 0) {
            open_count -= 1;
            const open = open_regions[open_count];
            analysis.regions.items[open.region_index].end_line_exclusive =
                last.number + 1;
        }
    }
    return analysis;
}

fn indentation(line: []const u8, tab_width: usize) ?usize {
    var columns: usize = 0;
    for (line) |byte| switch (byte) {
        ' ' => columns += 1,
        '\t' => columns = ((columns / tab_width) + 1) * tab_width,
        '\r' => {},
        else => return columns,
    };
    return null;
}

test "indentation analysis finds nested and sibling regions" {
    const source =
        \\fn outer() void {
        \\    if (ready) {
        \\        run();
        \\    }
        \\}
        \\fn sibling() void {
        \\    finish();
        \\}
    ;
    var analysis = try analyzeAlloc(std.testing.allocator, source, 4);
    defer analysis.deinit();

    try std.testing.expect(!analysis.truncated);
    try std.testing.expectEqual(@as(usize, 3), analysis.regions.items.len);
    try std.testing.expectEqual(Region{
        .anchor_line = 0,
        .first_hidden_line = 1,
        .end_line_exclusive = 4,
    }, analysis.regions.items[0]);
    try std.testing.expectEqual(Region{
        .anchor_line = 1,
        .first_hidden_line = 2,
        .end_line_exclusive = 3,
    }, analysis.regions.items[1]);
    try std.testing.expectEqual(Region{
        .anchor_line = 5,
        .first_hidden_line = 6,
        .end_line_exclusive = 7,
    }, analysis.regions.items[2]);
    try std.testing.expectEqual(@as(u32, 3), analysis.regions.items[0].hiddenLineCount());
}

test "analysis includes leading blank lines and trims trailing blanks" {
    const source = "root\n\n\tchild\n\t\nnext\n";
    var analysis = try analyzeAlloc(std.testing.allocator, source, 4);
    defer analysis.deinit();

    const region = analysis.regionAtLine(0).?;
    try std.testing.expectEqual(@as(u32, 1), region.first_hidden_line);
    try std.testing.expectEqual(@as(u32, 3), region.end_line_exclusive);
    try std.testing.expectEqual(@as(u32, 2), region.hiddenLineCount());
}

test "flat and blank text has no fold regions" {
    var flat = try analyzeAlloc(std.testing.allocator, "one\ntwo\nthree\n", 4);
    defer flat.deinit();
    try std.testing.expectEqual(@as(usize, 0), flat.regions.items.len);

    var blank = try analyzeAlloc(std.testing.allocator, "\n\t\n", 4);
    defer blank.deinit();
    try std.testing.expectEqual(@as(usize, 0), blank.regions.items.len);
    try std.testing.expectError(
        error.InvalidTabWidth,
        analyzeAlloc(std.testing.allocator, "a\n b", 0),
    );
}
