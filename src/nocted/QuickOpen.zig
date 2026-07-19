const std = @import("std");
const ProjectIndex = @import("ProjectIndex.zig");

pub const max_query_bytes: usize = 256;
pub const max_results: usize = 100;

pub const Match = struct {
    entry_index: usize,
    score: i32,
};

pub const Results = struct {
    matches: []Match = &.{},
    total_matches: usize = 0,
    truncated: bool = false,

    pub fn deinit(self: *Results, allocator: std.mem.Allocator) void {
        if (self.matches.len != 0) allocator.free(self.matches);
        self.* = .{};
    }
};

pub fn filterAlloc(
    allocator: std.mem.Allocator,
    index: ProjectIndex.Index,
    query: []const u8,
) !Results {
    if (query.len > max_query_bytes) return error.QuickOpenQueryTooLong;
    if (!std.unicode.utf8ValidateSlice(query) or
        std.mem.indexOfAny(u8, query, "\x00\r\n") != null)
        return error.InvalidQuickOpenQuery;

    var heap: [max_results]Match = undefined;
    var heap_length: usize = 0;
    var total_matches: usize = 0;
    for (index.entries, 0..) |entry, entry_index| {
        if (entry.kind != .file) continue;
        const score = scorePath(index, entry, query) orelse continue;
        total_matches += 1;
        const candidate = Match{ .entry_index = entry_index, .score = score };
        if (heap_length < heap.len) {
            heap[heap_length] = candidate;
            siftWorstUp(index, heap[0 .. heap_length + 1], heap_length);
            heap_length += 1;
        } else if (isBetter(index, candidate, heap[0])) {
            heap[0] = candidate;
            siftWorstDown(index, &heap, heap_length, 0);
        }
    }

    const matches = try allocator.alloc(Match, heap_length);
    @memcpy(matches, heap[0..heap_length]);
    std.sort.heap(Match, matches, index, sortBetter);
    return .{
        .matches = matches,
        .total_matches = total_matches,
        .truncated = total_matches > max_results,
    };
}

const ScoreState = struct {
    best: i32 = std.math.minInt(i32),
    ending: i32 = std.math.minInt(i32),
};

fn scorePath(index: ProjectIndex.Index, entry: ProjectIndex.Entry, query: []const u8) ?i32 {
    const path = index.path(entry);
    if (query.len == 0) return -@as(i32, @intCast(@min(path.len, std.math.maxInt(i32))));
    const case_sensitive = containsUpper(query);
    if (!subsequenceEligible(path, query, case_sensitive)) return null;

    var previous = [_]ScoreState{.{}} ** (max_query_bytes + 1);
    var current = [_]ScoreState{.{}} ** (max_query_bytes + 1);
    previous[0].best = 0;
    for (path, 0..) |path_byte, path_index| {
        current[0] = previous[0];
        for (1..query.len + 1) |query_index| {
            current[query_index] = .{ .best = previous[query_index].best };
            if (!equalByte(path_byte, query[query_index - 1], case_sensitive)) continue;
            const boundary_bonus: i32 = if (isBoundary(entry, path, path_index)) 18 else 0;
            const basename_bonus: i32 = if (path_index == entry.basename_offset) 28 else 0;
            var ending: i32 = std.math.minInt(i32);
            if (query_index == 1) {
                ending = 12 + boundary_bonus + basename_bonus - @as(i32, @intCast(path_index));
            } else if (previous[query_index - 1].best != std.math.minInt(i32)) {
                ending = previous[query_index - 1].best + 12 + boundary_bonus + basename_bonus;
            }
            if (query_index > 1 and previous[query_index - 1].ending != std.math.minInt(i32))
                ending = @max(ending, previous[query_index - 1].ending + 26 + basename_bonus);
            current[query_index].ending = ending;
            current[query_index].best = @max(current[query_index].best, ending);
        }
        std.mem.swap([max_query_bytes + 1]ScoreState, &previous, &current);
    }
    var score = previous[query.len].best;
    if (score == std.math.minInt(i32)) return null;
    const basename = index.basename(entry);
    if (startsWithFold(basename, query, case_sensitive)) score += 48;
    if (extensionMatches(path, query, case_sensitive)) score += 24;
    score -= @intCast(@min(path.len, 4096) / 4);
    return score;
}

fn subsequenceEligible(path: []const u8, query: []const u8, case_sensitive: bool) bool {
    var cursor: usize = 0;
    for (query) |needle| {
        while (cursor < path.len and !equalByte(path[cursor], needle, case_sensitive))
            cursor += 1;
        if (cursor == path.len) return false;
        cursor += 1;
    }
    return true;
}

fn isBoundary(entry: ProjectIndex.Entry, path: []const u8, position: usize) bool {
    if (position < 64) return entry.boundary_mask & (@as(u64, 1) << @intCast(position)) != 0;
    if (position == 0) return true;
    const previous = path[position - 1];
    const current = path[position];
    return previous == '/' or previous == '_' or previous == '-' or previous == '.' or
        (previous >= 'a' and previous <= 'z' and current >= 'A' and current <= 'Z');
}

fn extensionMatches(path: []const u8, query: []const u8, case_sensitive: bool) bool {
    const path_extension = std.fs.path.extension(path);
    const query_extension = std.fs.path.extension(query);
    return query_extension.len > 1 and path_extension.len == query_extension.len and
        startsWithFold(path_extension, query_extension, case_sensitive);
}

fn startsWithFold(haystack: []const u8, needle: []const u8, case_sensitive: bool) bool {
    if (needle.len > haystack.len) return false;
    for (haystack[0..needle.len], needle) |lhs, rhs|
        if (!equalByte(lhs, rhs, case_sensitive)) return false;
    return true;
}

fn containsUpper(value: []const u8) bool {
    for (value) |byte| if (byte >= 'A' and byte <= 'Z') return true;
    return false;
}

fn equalByte(lhs: u8, rhs: u8, case_sensitive: bool) bool {
    return if (case_sensitive) lhs == rhs else asciiLower(lhs) == asciiLower(rhs);
}

fn asciiLower(value: u8) u8 {
    return if (value >= 'A' and value <= 'Z') value + ('a' - 'A') else value;
}

fn isBetter(index: ProjectIndex.Index, lhs: Match, rhs: Match) bool {
    if (lhs.score != rhs.score) return lhs.score > rhs.score;
    return std.mem.lessThan(u8, index.pathAt(lhs.entry_index), index.pathAt(rhs.entry_index));
}

fn isWorse(index: ProjectIndex.Index, lhs: Match, rhs: Match) bool {
    return isBetter(index, rhs, lhs);
}

fn sortBetter(index: ProjectIndex.Index, lhs: Match, rhs: Match) bool {
    return isBetter(index, lhs, rhs);
}

fn siftWorstUp(index: ProjectIndex.Index, heap: []Match, start: usize) void {
    var child = start;
    while (child > 0) {
        const parent = (child - 1) / 2;
        if (!isWorse(index, heap[child], heap[parent])) break;
        std.mem.swap(Match, &heap[child], &heap[parent]);
        child = parent;
    }
}

fn siftWorstDown(index: ProjectIndex.Index, heap: []Match, length: usize, start: usize) void {
    var parent = start;
    while (true) {
        const left = parent * 2 + 1;
        if (left >= length) return;
        const right = left + 1;
        var worst = left;
        if (right < length and isWorse(index, heap[right], heap[left])) worst = right;
        if (!isWorse(index, heap[worst], heap[parent])) return;
        std.mem.swap(Match, &heap[parent], &heap[worst]);
        parent = worst;
    }
}

test "quick open uses smart-case path-aware deterministic top K" {
    const allocator = std.testing.allocator;
    const inputs = [_]ProjectIndex.InputEntry{
        .{ .path = "src", .kind = .directory },
        .{ .path = "src/menu.zig", .kind = .file },
        .{ .path = "src/main.zig", .kind = .file },
        .{ .path = "docs/main-notes.md", .kind = .file },
        .{ .path = "src/MainWindow.zig", .kind = .file },
    };
    var index = try ProjectIndex.fromEntriesAlloc(allocator, &inputs, false);
    defer index.deinit(allocator);

    var results = try filterAlloc(allocator, index, "mainz");
    defer results.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 2), results.matches.len);
    try std.testing.expectEqualStrings("src/main.zig", index.pathAt(results.matches[0].entry_index));

    var smart_case = try filterAlloc(allocator, index, "MW");
    defer smart_case.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 1), smart_case.matches.len);
    try std.testing.expectEqualStrings("src/MainWindow.zig", index.pathAt(smart_case.matches[0].entry_index));
}

test "quick open caps retained winners and rejects unsafe queries" {
    const allocator = std.testing.allocator;
    var paths: [max_results + 37][32]u8 = undefined;
    var inputs: [max_results + 37]ProjectIndex.InputEntry = undefined;
    for (&paths, &inputs, 0..) |*path, *input, index| {
        const value = try std.fmt.bufPrint(path, "src/file-{d}.zig", .{index});
        input.* = .{ .path = value, .kind = .file };
    }
    var project = try ProjectIndex.fromEntriesAlloc(allocator, &inputs, false);
    defer project.deinit(allocator);
    var results = try filterAlloc(allocator, project, "");
    defer results.deinit(allocator);
    try std.testing.expectEqual(max_results, results.matches.len);
    try std.testing.expectEqual(max_results + 37, results.total_matches);
    try std.testing.expect(results.truncated);

    var long_query: [max_query_bytes + 1]u8 = undefined;
    @memset(&long_query, 'x');
    try std.testing.expectError(error.QuickOpenQueryTooLong, filterAlloc(allocator, project, &long_query));
    try std.testing.expectError(error.InvalidQuickOpenQuery, filterAlloc(allocator, project, "bad\nquery"));
    try std.testing.expectError(error.InvalidQuickOpenQuery, filterAlloc(allocator, project, "bad\x00query"));
}
