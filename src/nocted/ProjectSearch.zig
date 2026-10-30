const std = @import("std");
const project_index = @import("ProjectIndex.zig");

pub const max_query_bytes: usize = 256;
pub const max_files: usize = 1024;
pub const max_file_bytes: usize = 1024 * 1024;
pub const max_total_bytes: usize = 32 * 1024 * 1024;
pub const max_results: usize = 1000;
pub const max_preview_bytes: usize = 240;
pub const read_buffer_bytes: usize = 64 * 1024;
pub const max_ranges_per_line: usize = 8;

pub const MatchRange = struct {
    column: u32,
    length: u16,
};

pub const BufferSnapshot = struct {
    entry_index: usize,
    contents: []const u8,
};

pub const Limits = struct {
    files: usize = max_files,
    file_bytes: usize = max_file_bytes,
    total_bytes: usize = max_total_bytes,
    results: usize = max_results,

    fn validate(self: Limits) !void {
        if (self.files == 0 or self.file_bytes == 0 or
            self.total_bytes == 0 or self.results == 0)
            return error.InvalidSearchLimits;
    }
};

pub const Result = struct {
    entry_index: usize,
    relative_path: []const u8,
    line: u32,
    column: u32,
    preview: []u8,
    ranges: [max_ranges_per_line]MatchRange = undefined,
    range_count: u8 = 0,
};

pub const Search = struct {
    results: []Result = &.{},
    owned_index: project_index.Index = .{},
    files_scanned: usize = 0,
    bytes_scanned: usize = 0,
    truncated: bool = false,

    pub fn deinit(self: *Search, allocator: std.mem.Allocator) void {
        for (self.results) |result| {
            allocator.free(result.preview);
        }
        if (self.results.len != 0) allocator.free(self.results);
        self.owned_index.deinit(allocator);
        self.* = .{};
    }
};

pub const SearchProgress = enum {
    pending,
    complete,
};

pub const Cursor = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    root_dir: std.Io.Dir,
    query: []u8,
    query_codepoints: u16,
    index: project_index.Index,
    snapshots: []const BufferSnapshot,
    limits: Limits,
    results: std.array_list.Managed(Result),
    next_entry: usize = 0,
    next_snapshot: usize = 0,
    files_scanned: usize = 0,
    bytes_scanned: usize = 0,
    truncated: bool,
    finished: bool = false,
    read_buffer: [read_buffer_bytes]u8 = undefined,
    query_prefix: [max_query_bytes]u16 = @splat(0),

    pub fn init(
        allocator: std.mem.Allocator,
        io: std.Io,
        root: []const u8,
        index: project_index.Index,
        query: []const u8,
        limits: Limits,
    ) !Cursor {
        return initWithSnapshots(allocator, io, root, index, query, limits, &.{});
    }

    pub fn initWithSnapshots(
        allocator: std.mem.Allocator,
        io: std.Io,
        root: []const u8,
        index: project_index.Index,
        query: []const u8,
        limits: Limits,
        snapshots: []const BufferSnapshot,
    ) !Cursor {
        try validateQuery(query, limits);
        for (snapshots) |snapshot| {
            if (snapshot.entry_index >= index.entries.len or
                index.entries[snapshot.entry_index].kind != .file)
                return error.InvalidSearchSnapshot;
        }
        const root_dir = try std.Io.Dir.openDirAbsolute(io, root, .{});
        errdefer root_dir.close(io);
        const owned_query = try allocator.dupe(u8, query);
        errdefer allocator.free(owned_query);
        var cursor = Cursor{
            .allocator = allocator,
            .io = io,
            .root_dir = root_dir,
            .query = owned_query,
            .query_codepoints = @intCast(try std.unicode.utf8CountCodepoints(query)),
            .index = index.retain(),
            .snapshots = snapshots,
            .limits = limits,
            .results = std.array_list.Managed(Result).init(allocator),
            .truncated = index.truncated,
        };
        cursor.buildQueryPrefix();
        return cursor;
    }

    pub fn deinit(self: *Cursor) void {
        for (self.results.items) |result| {
            self.allocator.free(result.preview);
        }
        self.results.deinit();
        self.index.deinit(self.allocator);
        self.root_dir.close(self.io);
        self.allocator.free(self.query);
        self.* = undefined;
    }

    pub fn step(self: *Cursor, max_entries: usize) !SearchProgress {
        if (self.finished) return .complete;
        if (max_entries == 0) return error.InvalidSearchBudget;

        var visited: usize = 0;
        while (visited < max_entries and self.next_snapshot < self.snapshots.len) : (visited += 1) {
            const snapshot = self.snapshots[self.next_snapshot];
            self.next_snapshot += 1;
            if (self.files_scanned >= self.limits.files) {
                self.truncated = true;
                self.finished = true;
                return .complete;
            }
            try self.scanSnapshot(snapshot);
            if (self.finished) return .complete;
        }
        while (visited < max_entries and self.next_entry < self.index.entries.len) : (visited += 1) {
            const entry_index = self.next_entry;
            const entry = self.index.entries[entry_index];
            self.next_entry += 1;
            if (entry.kind != .file or self.hasSnapshot(entry_index)) continue;
            if (self.files_scanned >= self.limits.files) {
                self.truncated = true;
                self.finished = true;
                return .complete;
            }
            try self.scanFile(entry_index, entry);
            if (self.finished) return .complete;
        }
        if (self.next_snapshot >= self.snapshots.len and
            self.next_entry >= self.index.entries.len)
        {
            self.finished = true;
            return .complete;
        }
        return .pending;
    }

    pub fn takeSearch(self: *Cursor) !Search {
        if (!self.finished) return error.SearchIncomplete;
        const owned_results = try self.results.toOwnedSlice();
        const owned_index = self.index;
        self.index = .{};
        return .{
            .results = owned_results,
            .owned_index = owned_index,
            .files_scanned = self.files_scanned,
            .bytes_scanned = self.bytes_scanned,
            .truncated = self.truncated,
        };
    }

    fn scanFile(
        self: *Cursor,
        entry_index: usize,
        entry: project_index.Entry,
    ) !void {
        const relative_path = self.index.path(entry);
        const stat = self.root_dir.statFile(self.io, relative_path, .{}) catch return;
        if (stat.kind != .file) return;
        const size = std.math.cast(usize, stat.size) orelse {
            self.truncated = true;
            return;
        };
        if (size > self.limits.file_bytes) {
            self.truncated = true;
            return;
        }
        if (size > self.limits.total_bytes -| self.bytes_scanned) {
            self.truncated = true;
            self.finished = true;
            return;
        }
        const file = self.root_dir.openFile(self.io, relative_path, .{}) catch return;
        defer file.close(self.io);
        self.files_scanned += 1;
        const result_start = self.results.items.len;
        var line = LineState{};
        var utf8 = Utf8State{};
        var file_bytes: usize = 0;
        var invalid_text = false;

        read_loop: while (true) {
            const n = file.readStreaming(
                self.io,
                &.{self.read_buffer[0..]},
            ) catch |err| switch (err) {
                error.EndOfStream => break,
                else => return,
            };
            if (n == 0) continue;
            if (n > self.limits.file_bytes -| file_bytes or
                n > self.limits.total_bytes -| self.bytes_scanned)
            {
                self.truncated = true;
                self.finished = true;
                break;
            }
            file_bytes += n;
            self.bytes_scanned += n;

            for (self.read_buffer[0..n]) |byte| {
                if (byte == 0 or !utf8.accept(byte)) {
                    invalid_text = true;
                    break :read_loop;
                }
                if (byte == '\n') {
                    try self.finishLine(entry_index, relative_path, &line);
                    if (self.finished) break :read_loop;
                    line.next();
                    continue;
                }
                line.observe(byte, utf8.started_codepoint);
                self.matchByte(&line, byte);
            }
        }

        if (!invalid_text and !self.finished) {
            if (!utf8.complete()) {
                invalid_text = true;
            } else {
                try self.finishLine(entry_index, relative_path, &line);
            }
        }
        if (invalid_text) {
            self.discardResultsFrom(result_start);
        }
    }

    fn scanSnapshot(self: *Cursor, snapshot: BufferSnapshot) !void {
        const contents = snapshot.contents;
        if (contents.len > self.limits.file_bytes) {
            self.truncated = true;
            return;
        }
        if (contents.len > self.limits.total_bytes -| self.bytes_scanned) {
            self.truncated = true;
            self.finished = true;
            return;
        }
        self.files_scanned += 1;
        const result_start = self.results.items.len;
        var line = LineState{};
        var utf8 = Utf8State{};
        var invalid_text = false;
        var offset: usize = 0;
        while (offset < contents.len) {
            const end = @min(offset + read_buffer_bytes, contents.len);
            self.bytes_scanned += end - offset;
            for (contents[offset..end]) |byte| {
                if (byte == 0 or !utf8.accept(byte)) {
                    invalid_text = true;
                    break;
                }
                if (byte == '\n') {
                    try self.finishLine(
                        snapshot.entry_index,
                        self.index.pathAt(snapshot.entry_index),
                        &line,
                    );
                    if (self.finished) break;
                    line.next();
                    continue;
                }
                line.observe(byte, utf8.started_codepoint);
                self.matchByte(&line, byte);
            }
            if (invalid_text or self.finished) break;
            offset = end;
        }
        if (!invalid_text and !self.finished) {
            if (!utf8.complete()) {
                invalid_text = true;
            } else {
                try self.finishLine(
                    snapshot.entry_index,
                    self.index.pathAt(snapshot.entry_index),
                    &line,
                );
            }
        }
        if (invalid_text) self.discardResultsFrom(result_start);
    }

    fn hasSnapshot(self: *const Cursor, entry_index: usize) bool {
        for (self.snapshots) |snapshot| {
            if (snapshot.entry_index == entry_index) return true;
        }
        return false;
    }

    fn buildQueryPrefix(self: *Cursor) void {
        var matched: usize = 0;
        var index: usize = 1;
        while (index < self.query.len) : (index += 1) {
            while (matched > 0 and self.query[index] != self.query[matched]) {
                matched = self.query_prefix[matched - 1];
            }
            if (self.query[index] == self.query[matched]) matched += 1;
            self.query_prefix[index] = @intCast(matched);
        }
    }

    fn matchByte(self: *const Cursor, line: *LineState, byte: u8) void {
        var matched: usize = line.query_matched;
        while (matched > 0 and byte != self.query[matched]) {
            matched = self.query_prefix[matched - 1];
        }
        if (byte == self.query[matched]) matched += 1;
        if (matched == self.query.len) {
            const column = line.codepoints - self.query_codepoints + 1;
            if (line.range_count < max_ranges_per_line) {
                line.ranges[line.range_count] = .{
                    .column = column,
                    .length = self.query_codepoints,
                };
                line.range_count += 1;
            }
            if (line.first_column == 0) line.first_column = column;
            matched = self.query_prefix[matched - 1];
        }
        line.query_matched = @intCast(matched);
    }

    fn finishLine(
        self: *Cursor,
        entry_index: usize,
        relative_path: []const u8,
        line: *const LineState,
    ) !void {
        if (line.first_column == 0) return;
        if (self.results.items.len >= self.limits.results) {
            self.truncated = true;
            self.finished = true;
            return;
        }
        var preview = std.mem.trimEnd(
            u8,
            line.preview[0..line.preview_length],
            " \t\r",
        );
        preview = utf8Prefix(preview, max_preview_bytes);
        if (preview.len == 0) preview = self.query;
        var result = Result{
            .entry_index = entry_index,
            .relative_path = relative_path,
            .line = line.number,
            .column = line.first_column,
            .preview = try self.allocator.dupe(u8, preview),
            .range_count = line.range_count,
        };
        @memcpy(result.ranges[0..line.range_count], line.ranges[0..line.range_count]);
        errdefer self.allocator.free(result.preview);
        try self.results.append(result);
    }

    fn discardResultsFrom(self: *Cursor, first: usize) void {
        for (self.results.items[first..]) |result| {
            self.allocator.free(result.preview);
        }
        self.results.shrinkRetainingCapacity(first);
    }
};

const LineState = struct {
    number: u32 = 1,
    codepoints: u32 = 0,
    query_matched: u16 = 0,
    first_column: u32 = 0,
    ranges: [max_ranges_per_line]MatchRange = undefined,
    range_count: u8 = 0,
    preview: [max_preview_bytes]u8 = undefined,
    preview_length: u16 = 0,
    leading_whitespace: bool = true,

    fn observe(self: *LineState, byte: u8, started_codepoint: bool) void {
        if (started_codepoint) self.codepoints +|= 1;
        if (self.leading_whitespace and (byte == ' ' or byte == '\t' or byte == '\r'))
            return;
        self.leading_whitespace = false;
        if (self.preview_length < self.preview.len) {
            self.preview[self.preview_length] = byte;
            self.preview_length += 1;
        }
    }

    fn next(self: *LineState) void {
        const next_number = self.number +| 1;
        self.* = .{ .number = next_number };
    }
};

const Utf8State = struct {
    bytes: [4]u8 = undefined,
    length: u3 = 0,
    expected: u3 = 0,
    started_codepoint: bool = false,

    fn accept(self: *Utf8State, byte: u8) bool {
        self.started_codepoint = false;
        if (self.expected == 0) {
            const expected = std.unicode.utf8ByteSequenceLength(byte) catch return false;
            self.started_codepoint = true;
            if (expected == 1) return true;
            self.bytes[0] = byte;
            self.length = 1;
            self.expected = expected;
            return true;
        }
        if (byte & 0b1100_0000 != 0b1000_0000) return false;
        self.bytes[self.length] = byte;
        self.length += 1;
        if (self.length != self.expected) return true;
        _ = std.unicode.utf8Decode(self.bytes[0..self.expected]) catch return false;
        self.length = 0;
        self.expected = 0;
        return true;
    }

    fn complete(self: *const Utf8State) bool {
        return self.expected == 0;
    }
};

pub fn searchAlloc(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: []const u8,
    query: []const u8,
) !Search {
    return searchAllocWithLimits(allocator, io, root, query, .{});
}

pub fn searchAllocWithLimits(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: []const u8,
    query: []const u8,
    limits: Limits,
) !Search {
    var index = try project_index.scanAlloc(allocator, io, root);
    errdefer index.deinit(allocator);
    var cursor = try Cursor.init(
        allocator,
        io,
        root,
        index,
        query,
        limits,
    );
    defer cursor.deinit();
    while (try cursor.step(128) == .pending) {}
    const search = try cursor.takeSearch();
    index.deinit(allocator);
    index = .{};
    return search;
}

fn validateQuery(query: []const u8, limits: Limits) !void {
    try limits.validate();
    if (query.len == 0) return error.EmptySearchQuery;
    if (query.len > max_query_bytes) return error.SearchQueryTooLong;
    if (!std.unicode.utf8ValidateSlice(query) or
        std.mem.indexOfAny(u8, query, "\x00\r\n") != null)
        return error.InvalidSearchQuery;
}

fn utf8Prefix(value: []const u8, limit: usize) []const u8 {
    if (value.len <= limit) return value;
    var end = limit;
    while (end > 0 and !std.unicode.utf8ValidateSlice(value[0..end])) : (end -= 1) {}
    return value[0..end];
}

test "project search finds bounded path line column and previews" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.createDirPath(io, "src/nested");
    try tmp.dir.createDirPath(io, ".zig-cache/o");
    try tmp.dir.writeFile(io, .{
        .sub_path = "src/main.zig",
        .data = "const first = true;\n  const needle = 1;  \nconst café = \"needle\";\n",
    });
    try tmp.dir.writeFile(io, .{
        .sub_path = "src/nested/other.zig",
        .data = "fn second() void {\n    const needle = 2;\n}\n",
    });
    try tmp.dir.writeFile(io, .{
        .sub_path = ".zig-cache/o/generated.zig",
        .data = "const needle = 3;\n",
    });
    try tmp.dir.writeFile(io, .{
        .sub_path = "binary",
        .data = &.{ 'n', 'e', 'e', 'd', 'l', 'e', 0, 0xff },
    });
    var root_buffer: [std.fs.max_path_bytes]u8 = undefined;
    const root_length = try tmp.dir.realPath(io, &root_buffer);

    var search = try searchAlloc(
        allocator,
        io,
        root_buffer[0..root_length],
        "needle",
    );
    defer search.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 3), search.results.len);
    try std.testing.expectEqualStrings("src/main.zig", search.results[0].relative_path);
    try std.testing.expectEqual(@as(u32, 2), search.results[0].line);
    try std.testing.expectEqual(@as(u32, 9), search.results[0].column);
    try std.testing.expectEqualStrings("const needle = 1;", search.results[0].preview);
    try std.testing.expectEqual(@as(u32, 15), search.results[1].column);
    try std.testing.expectEqualStrings("src/nested/other.zig", search.results[2].relative_path);
    try std.testing.expect(!search.truncated);
}

test "project search reports result and file limits" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(io, .{ .sub_path = "a.txt", .data = "hit\nhit\n" });
    try tmp.dir.writeFile(io, .{ .sub_path = "b.txt", .data = "hit\n" });
    var root_buffer: [std.fs.max_path_bytes]u8 = undefined;
    const root_length = try tmp.dir.realPath(io, &root_buffer);

    var search = try searchAllocWithLimits(
        allocator,
        io,
        root_buffer[0..root_length],
        "hit",
        .{ .files = 1, .file_bytes = 32, .total_bytes = 32, .results = 1 },
    );
    defer search.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 1), search.results.len);
    try std.testing.expect(search.truncated);
}

test "project search validates the query and limits" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var root_buffer: [std.fs.max_path_bytes]u8 = undefined;
    const root_length = try tmp.dir.realPath(io, &root_buffer);
    const root = root_buffer[0..root_length];
    try std.testing.expectError(
        error.EmptySearchQuery,
        searchAlloc(allocator, io, root, ""),
    );
    var long_query: [max_query_bytes + 1]u8 = undefined;
    @memset(&long_query, 'x');
    try std.testing.expectError(
        error.SearchQueryTooLong,
        searchAlloc(allocator, io, root, &long_query),
    );
    try std.testing.expectError(
        error.InvalidSearchLimits,
        searchAllocWithLimits(allocator, io, root, "x", .{ .files = 0 }),
    );
}

test "project search cursor yields between indexed entries" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(io, .{ .sub_path = "a.txt", .data = "hit\n" });
    try tmp.dir.writeFile(io, .{ .sub_path = "b.txt", .data = "hit\n" });
    var root_buffer: [std.fs.max_path_bytes]u8 = undefined;
    const root_length = try tmp.dir.realPath(io, &root_buffer);
    const root = root_buffer[0..root_length];
    var index = try project_index.scanAlloc(allocator, io, root);
    defer index.deinit(allocator);

    var cursor = try Cursor.init(
        allocator,
        io,
        root,
        index,
        "hit",
        .{},
    );
    defer cursor.deinit();
    try std.testing.expectEqual(SearchProgress.pending, try cursor.step(1));
    try std.testing.expect(cursor.files_scanned <= 1);
    while (try cursor.step(1) == .pending) {}
    var search = try cursor.takeSearch();
    defer search.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 2), search.results.len);
}

test "project search streams matches across read chunk boundaries" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const prefix_length = read_buffer_bytes - 3;
    const contents = try allocator.alloc(u8, prefix_length + "needle\n".len);
    defer allocator.free(contents);
    @memset(contents[0..prefix_length], 'a');
    @memcpy(contents[prefix_length..], "needle\n");
    try tmp.dir.writeFile(io, .{ .sub_path = "large.txt", .data = contents });
    var root_buffer: [std.fs.max_path_bytes]u8 = undefined;
    const root_length = try tmp.dir.realPath(io, &root_buffer);

    var search = try searchAlloc(
        allocator,
        io,
        root_buffer[0..root_length],
        "needle",
    );
    defer search.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 1), search.results.len);
    try std.testing.expectEqual(@as(u32, prefix_length + 1), search.results[0].column);
    try std.testing.expectEqual(@as(u8, 1), search.results[0].range_count);
    try std.testing.expectEqual(search.results[0].column, search.results[0].ranges[0].column);
}

test "project search rejects a file when invalid text follows a match" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(io, .{
        .sub_path = "binary.txt",
        .data = "needle\nvalid prefix\n\xf0\x80\x80\x80",
    });
    var root_buffer: [std.fs.max_path_bytes]u8 = undefined;
    const root_length = try tmp.dir.realPath(io, &root_buffer);

    var search = try searchAlloc(
        allocator,
        io,
        root_buffer[0..root_length],
        "needle",
    );
    defer search.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 0), search.results.len);
    try std.testing.expectEqual(@as(usize, 1), search.files_scanned);
}

test "project search scans modified snapshots first and skips stale disk bytes" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(io, .{
        .sub_path = "a.txt",
        .data = "stale needle\n",
    });
    try tmp.dir.writeFile(io, .{
        .sub_path = "b.txt",
        .data = "disk needle\n",
    });
    var root_buffer: [std.fs.max_path_bytes]u8 = undefined;
    const root_length = try tmp.dir.realPath(io, &root_buffer);
    const root = root_buffer[0..root_length];
    var index = try project_index.scanAlloc(allocator, io, root);
    defer index.deinit(allocator);
    const a_index = index.findPath("a.txt") orelse return error.ExpectedIndexedPath;
    const snapshots = [_]BufferSnapshot{.{
        .entry_index = a_index,
        .contents = "modified without the term\n",
    }};
    var cursor = try Cursor.initWithSnapshots(
        allocator,
        io,
        root,
        index,
        "needle",
        .{},
        &snapshots,
    );
    defer cursor.deinit();
    while (try cursor.step(1) == .pending) {}
    var search = try cursor.takeSearch();
    defer search.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 1), search.results.len);
    try std.testing.expectEqualStrings("b.txt", search.results[0].relative_path);
    try std.testing.expectEqual(@as(usize, 2), search.files_scanned);
}
