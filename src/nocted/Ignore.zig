const std = @import("std");

pub const max_rules: usize = 8192;
pub const max_rule_bytes: usize = 256;
pub const max_pattern_bytes: usize = 1024 * 1024;
pub const max_ignore_file_bytes: usize = 256 * 1024;
pub const max_ignore_files: usize = 4096;

const Rule = struct {
    base_offset: u32,
    base_length: u16,
    pattern_offset: u32,
    pattern_length: u16,
    negated: bool,
    directory_only: bool,
    basename_only: bool,
};

pub const Matcher = struct {
    allocator: std.mem.Allocator,
    arena: std.array_list.Managed(u8),
    rules: std.array_list.Managed(Rule),
    loaded_files: usize = 0,
    truncated: bool = false,

    pub fn init(allocator: std.mem.Allocator) Matcher {
        return .{
            .allocator = allocator,
            .arena = std.array_list.Managed(u8).init(allocator),
            .rules = std.array_list.Managed(Rule).init(allocator),
        };
    }

    pub fn deinit(self: *Matcher) void {
        self.rules.deinit();
        self.arena.deinit();
        self.* = undefined;
    }

    pub fn loadDirectory(
        self: *Matcher,
        directory: std.Io.Dir,
        io: std.Io,
        base: []const u8,
    ) !void {
        try self.loadFile(directory, io, base, ".gitignore");
        try self.loadFile(directory, io, base, ".ignore");
    }

    pub fn addContents(
        self: *Matcher,
        base: []const u8,
        contents: []const u8,
    ) !void {
        var lines = std.mem.splitScalar(u8, contents, '\n');
        while (lines.next()) |raw_line| {
            var line = std.mem.trimEnd(u8, raw_line, " \t\r");
            if (line.len == 0) continue;
            if (line[0] == '#' and !std.mem.startsWith(u8, line, "\\#")) continue;

            var negated = false;
            if (line[0] == '!' and !std.mem.startsWith(u8, line, "\\!")) {
                negated = true;
                line = line[1..];
            } else if (std.mem.startsWith(u8, line, "\\#") or
                std.mem.startsWith(u8, line, "\\!"))
            {
                line = line[1..];
            }
            if (line.len == 0) continue;

            var directory_only = false;
            if (line[line.len - 1] == '/' and
                (line.len == 1 or line[line.len - 2] != '\\'))
            {
                directory_only = true;
                line = line[0 .. line.len - 1];
            }
            const anchored = line.len > 0 and line[0] == '/';
            if (anchored) line = line[1..];
            if (line.len == 0) continue;
            if (line.len > max_rule_bytes or base.len > std.math.maxInt(u16)) {
                self.truncated = true;
                continue;
            }
            if (self.rules.items.len >= max_rules or
                self.arena.items.len + base.len + line.len > max_pattern_bytes)
            {
                self.truncated = true;
                return;
            }

            const base_offset = self.arena.items.len;
            try self.arena.appendSlice(base);
            const pattern_offset = self.arena.items.len;
            try self.arena.appendSlice(line);
            try self.rules.append(.{
                .base_offset = @intCast(base_offset),
                .base_length = @intCast(base.len),
                .pattern_offset = @intCast(pattern_offset),
                .pattern_length = @intCast(line.len),
                .negated = negated,
                .directory_only = directory_only,
                .basename_only = !anchored and
                    std.mem.indexOfScalar(u8, line, '/') == null,
            });
        }
    }

    pub fn isIgnored(
        self: *const Matcher,
        path: []const u8,
        is_directory: bool,
    ) bool {
        var ignored = false;
        for (self.rules.items) |rule| {
            const base = self.slice(rule.base_offset, rule.base_length);
            const relative = relativeToBase(path, base) orelse continue;
            const pattern = self.slice(rule.pattern_offset, rule.pattern_length);
            if (!ruleMatches(pattern, relative, rule.basename_only, rule.directory_only, is_directory))
                continue;
            ignored = !rule.negated;
        }
        return ignored;
    }

    fn loadFile(
        self: *Matcher,
        directory: std.Io.Dir,
        io: std.Io,
        base: []const u8,
        name: []const u8,
    ) !void {
        if (self.loaded_files >= max_ignore_files) {
            self.truncated = true;
            return;
        }
        var path_buffer: [std.fs.max_path_bytes]u8 = undefined;
        const path = if (base.len == 0)
            std.fmt.bufPrint(&path_buffer, "{s}", .{name}) catch {
                self.truncated = true;
                return;
            }
        else
            std.fmt.bufPrint(&path_buffer, "{s}/{s}", .{ base, name }) catch {
                self.truncated = true;
                return;
            };
        const contents = directory.readFileAlloc(
            io,
            path,
            self.allocator,
            .limited(max_ignore_file_bytes + 1),
        ) catch |err| switch (err) {
            error.FileNotFound => return,
            error.OutOfMemory => return err,
            else => {
                self.truncated = true;
                return;
            },
        };
        defer self.allocator.free(contents);
        self.loaded_files += 1;
        if (contents.len > max_ignore_file_bytes) {
            self.truncated = true;
            return;
        }
        try self.addContents(base, contents);
    }

    fn slice(self: *const Matcher, offset: u32, length: u16) []const u8 {
        const start: usize = offset;
        return self.arena.items[start .. start + length];
    }
};

fn relativeToBase(path: []const u8, base: []const u8) ?[]const u8 {
    if (base.len == 0) return path;
    if (path.len <= base.len or !std.mem.eql(u8, path[0..base.len], base) or
        path[base.len] != '/')
        return null;
    return path[base.len + 1 ..];
}

fn ruleMatches(
    pattern: []const u8,
    relative: []const u8,
    basename_only: bool,
    directory_only: bool,
    is_directory: bool,
) bool {
    if (!basename_only) {
        if (globMatch(pattern, relative) and (!directory_only or is_directory)) return true;
        if (!directory_only) return false;
        var end = relative.len;
        while (std.mem.lastIndexOfScalar(u8, relative[0..end], '/')) |slash| {
            if (globMatch(pattern, relative[0..slash])) return true;
            end = slash;
        }
        return false;
    }

    var components = std.mem.splitScalar(u8, relative, '/');
    var component_index: usize = 0;
    const slash_count = std.mem.count(u8, relative, "/");
    while (components.next()) |component| : (component_index += 1) {
        if (!globMatch(pattern, component)) continue;
        const component_is_directory = component_index < slash_count or is_directory;
        if (!directory_only or component_is_directory) return true;
    }
    return false;
}

const Token = struct {
    kind: enum { literal, any, class, star },
    next: usize,
    literal: u8 = 0,
    class_end: usize = 0,
    cross_slash: bool = false,
};

fn tokenAt(pattern: []const u8, index: usize) Token {
    const byte = pattern[index];
    if (byte == '\\' and index + 1 < pattern.len)
        return .{ .kind = .literal, .next = index + 2, .literal = pattern[index + 1] };
    if (byte == '?') return .{ .kind = .any, .next = index + 1 };
    if (byte == '*') {
        var next = index + 1;
        while (next < pattern.len and pattern[next] == '*') next += 1;
        return .{
            .kind = .star,
            .next = next,
            .cross_slash = next - index >= 2,
        };
    }
    if (byte == '[') {
        var end = index + 1;
        if (end < pattern.len and (pattern[end] == '!' or pattern[end] == '^')) end += 1;
        if (end < pattern.len and pattern[end] == ']') end += 1;
        while (end < pattern.len and pattern[end] != ']') end += 1;
        if (end < pattern.len)
            return .{ .kind = .class, .next = end + 1, .class_end = end };
    }
    return .{ .kind = .literal, .next = index + 1, .literal = byte };
}

fn epsilonClosure(pattern: []const u8, states: *[max_rule_bytes + 1]bool) void {
    var index: usize = 0;
    while (index < pattern.len) : (index += 1) {
        if (!states[index]) continue;
        const token = tokenAt(pattern, index);
        if (token.kind != .star) continue;
        states[token.next] = true;
        if (token.cross_slash and token.next < pattern.len and pattern[token.next] == '/')
            states[token.next + 1] = true;
    }
}

fn globMatch(pattern: []const u8, value: []const u8) bool {
    if (pattern.len > max_rule_bytes) return false;
    var current = [_]bool{false} ** (max_rule_bytes + 1);
    var next = [_]bool{false} ** (max_rule_bytes + 1);
    current[0] = true;
    epsilonClosure(pattern, &current);
    for (value) |byte| {
        @memset(&next, false);
        var index: usize = 0;
        while (index < pattern.len) : (index += 1) {
            if (!current[index]) continue;
            const token = tokenAt(pattern, index);
            switch (token.kind) {
                .literal => if (byte == token.literal) {
                    next[token.next] = true;
                },
                .any => if (byte != '/') {
                    next[token.next] = true;
                },
                .class => if (byte != '/' and classMatches(
                    pattern[index + 1 .. token.class_end],
                    byte,
                )) {
                    next[token.next] = true;
                },
                .star => if (token.cross_slash or byte != '/') {
                    next[index] = true;
                },
            }
        }
        current = next;
        epsilonClosure(pattern, &current);
    }
    epsilonClosure(pattern, &current);
    return current[pattern.len];
}

fn classMatches(class: []const u8, byte: u8) bool {
    if (class.len == 0) return false;
    var index: usize = 0;
    const negated = class[0] == '!' or class[0] == '^';
    if (negated) index += 1;
    var matched = false;
    while (index < class.len) {
        const first = class[index];
        if (index + 2 < class.len and class[index + 1] == '-') {
            matched = matched or (byte >= first and byte <= class[index + 2]);
            index += 3;
        } else {
            matched = matched or byte == first;
            index += 1;
        }
    }
    return if (negated) !matched else matched;
}

test "directory scoped ignore rules support negation globstar and directory rules" {
    var matcher = Matcher.init(std.testing.allocator);
    defer matcher.deinit();
    try matcher.addContents("", "zig-out/\n*.tmp\n!important.tmp\nsrc/**/generated?.zig\n");
    try matcher.addContents("src", "local.log\n!keep.tmp\n");

    try std.testing.expect(matcher.isIgnored("zig-out", true));
    try std.testing.expect(matcher.isIgnored("zig-out/file", false));
    try std.testing.expect(matcher.isIgnored("notes.tmp", false));
    try std.testing.expect(!matcher.isIgnored("important.tmp", false));
    try std.testing.expect(matcher.isIgnored("src/a/b/generated1.zig", false));
    try std.testing.expect(matcher.isIgnored("src/a/local.log", false));
    try std.testing.expect(!matcher.isIgnored("other/local.log", false));
    try std.testing.expect(!matcher.isIgnored("src/keep.tmp", false));
}

test "ignore matcher handles character classes and escaped prefixes" {
    var matcher = Matcher.init(std.testing.allocator);
    defer matcher.deinit();
    try matcher.addContents("", "file[0-9].log\n\\#literal\n\\!literal\n");
    try std.testing.expect(matcher.isIgnored("file4.log", false));
    try std.testing.expect(!matcher.isIgnored("filex.log", false));
    try std.testing.expect(matcher.isIgnored("#literal", false));
    try std.testing.expect(matcher.isIgnored("!literal", false));
}

test "leading slash anchors a rule to its ignore directory" {
    var matcher = Matcher.init(std.testing.allocator);
    defer matcher.deinit();
    try matcher.addContents("", "/build\n");
    try matcher.addContents("src", "/generated.zig\n");
    try std.testing.expect(matcher.isIgnored("build", true));
    try std.testing.expect(!matcher.isIgnored("nested/build", true));
    try std.testing.expect(matcher.isIgnored("src/generated.zig", false));
    try std.testing.expect(!matcher.isIgnored("src/nested/generated.zig", false));
}
