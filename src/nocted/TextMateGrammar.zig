const std = @import("std");

pub const max_source_bytes: usize = 1024 * 1024;
pub const max_patterns: usize = 512;
pub const max_pattern_bytes: usize = 4096;
pub const max_file_types: usize = 32;
pub const max_include_depth: usize = 16;

const RuleKind = enum { match, range };

const Rule = struct {
    kind: RuleKind,
    first: []const u8,
    second: []const u8 = "",
    style: []const u8,
};

pub const Conversion = struct {
    language_id: []u8,
    display_name: []u8,
    xml: []u8,
    pattern_count: usize,
    skipped_patterns: usize,
    file_type_count: usize,

    pub fn deinit(self: *Conversion, allocator: std.mem.Allocator) void {
        allocator.free(self.language_id);
        allocator.free(self.display_name);
        allocator.free(self.xml);
        self.* = undefined;
    }
};

const Stats = struct {
    skipped: usize = 0,
};

pub fn convertAlloc(
    allocator: std.mem.Allocator,
    source: []const u8,
) !Conversion {
    if (source.len == 0) return error.EmptyTextMateGrammar;
    if (source.len > max_source_bytes) return error.TextMateGrammarTooLarge;
    if (std.mem.indexOfScalar(u8, source, 0) != null)
        return error.InvalidTextMateGrammar;

    var parsed = std.json.parseFromSlice(std.json.Value, allocator, source, .{}) catch {
        return error.InvalidTextMateGrammar;
    };
    defer parsed.deinit();
    if (parsed.value != .object) return error.InvalidTextMateGrammar;
    const root = &parsed.value.object;

    const name = try requiredString(root, "name", 128);
    const scope_name = optionalString(root, "scopeName", 192) catch
        return error.InvalidTextMateGrammar;
    const id_source = scope_name orelse name;
    const language_id = try languageIdAlloc(allocator, id_source);
    errdefer allocator.free(language_id);
    const display_name = try allocator.dupe(u8, name);
    errdefer allocator.free(display_name);

    const file_types_value = root.get("fileTypes") orelse
        return error.TextMateGrammarMissingFileTypes;
    if (file_types_value != .array or file_types_value.array.items.len == 0)
        return error.TextMateGrammarMissingFileTypes;
    if (file_types_value.array.items.len > max_file_types)
        return error.TooManyTextMateFileTypes;
    for (file_types_value.array.items) |value| {
        if (value != .string or !validFileType(value.string))
            return error.InvalidTextMateFileType;
    }

    const patterns_value = root.get("patterns") orelse
        return error.TextMateGrammarMissingPatterns;
    if (patterns_value != .array) return error.TextMateGrammarMissingPatterns;
    const repository = if (root.getPtr("repository")) |value|
        if (value.* == .object) &value.object else null
    else
        null;

    var rules = std.array_list.Managed(Rule).init(allocator);
    defer rules.deinit();
    var stats = Stats{};
    var include_stack: [max_include_depth][]const u8 = undefined;
    try collectPatternArray(
        patterns_value.array.items,
        repository,
        &rules,
        &stats,
        &include_stack,
        0,
    );
    if (rules.items.len == 0) return error.TextMateGrammarHasNoSupportedPatterns;

    var output: std.Io.Writer.Allocating = .init(allocator);
    defer output.deinit();
    const writer = &output.writer;
    try writer.writeAll("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<language id=\"");
    try writeXml(writer, language_id, true);
    try writer.writeAll("\" name=\"");
    try writeXml(writer, display_name, true);
    try writer.writeAll("\" version=\"2.0\" _section=\"Source\">\n  <metadata>\n    <property name=\"globs\">");
    for (file_types_value.array.items, 0..) |value, index| {
        if (index != 0) try writer.writeAll(";");
        const file_type = value.string;
        if (std.mem.startsWith(u8, file_type, "*.")) {
            try writeXml(writer, file_type, false);
        } else {
            try writer.writeAll("*.");
            try writeXml(writer, std.mem.trimStart(u8, file_type, "."), false);
        }
    }
    try writer.writeAll(
        "</property>\n  </metadata>\n  <styles>\n" ++
            "    <style id=\"comment\" name=\"Comment\" map-to=\"def:comment\"/>\n" ++
            "    <style id=\"string\" name=\"String\" map-to=\"def:string\"/>\n" ++
            "    <style id=\"number\" name=\"Number\" map-to=\"def:number\"/>\n" ++
            "    <style id=\"keyword\" name=\"Keyword\" map-to=\"def:keyword\"/>\n" ++
            "    <style id=\"type\" name=\"Data Type\" map-to=\"def:type\"/>\n" ++
            "    <style id=\"function\" name=\"Function\" map-to=\"def:function\"/>\n" ++
            "    <style id=\"variable\" name=\"Variable\" map-to=\"def:identifier\"/>\n" ++
            "    <style id=\"special\" name=\"Special\" map-to=\"def:special-char\"/>\n" ++
            "    <style id=\"error\" name=\"Error\" map-to=\"def:error\"/>\n" ++
            "  </styles>\n  <definitions>\n",
    );
    for (rules.items, 0..) |rule, index| {
        try writer.print("    <context id=\"rule-{d}\" style-ref=\"{s}\">\n", .{ index, rule.style });
        switch (rule.kind) {
            .match => {
                try writer.writeAll("      <match>");
                try writeXml(writer, rule.first, false);
                try writer.writeAll("</match>\n");
            },
            .range => {
                try writer.writeAll("      <start>");
                try writeXml(writer, rule.first, false);
                try writer.writeAll("</start><end>");
                try writeXml(writer, rule.second, false);
                try writer.writeAll("</end>\n");
            },
        }
        try writer.writeAll("    </context>\n");
    }
    try writer.writeAll("    <context id=\"");
    try writeXml(writer, language_id, true);
    try writer.writeAll("\">\n      <include>\n");
    for (rules.items, 0..) |_, index|
        try writer.print("        <context ref=\"rule-{d}\"/>\n", .{index});
    try writer.writeAll("      </include>\n    </context>\n  </definitions>\n</language>\n");

    return .{
        .language_id = language_id,
        .display_name = display_name,
        .xml = try output.toOwnedSlice(),
        .pattern_count = rules.items.len,
        .skipped_patterns = stats.skipped,
        .file_type_count = file_types_value.array.items.len,
    };
}

fn collectPatternArray(
    values: []const std.json.Value,
    repository: ?*const std.json.ObjectMap,
    rules: *std.array_list.Managed(Rule),
    stats: *Stats,
    include_stack: *[max_include_depth][]const u8,
    depth: usize,
) anyerror!void {
    if (depth >= max_include_depth) return error.TextMateGrammarTooDeep;
    for (values) |*value| try collectPattern(
        value,
        repository,
        rules,
        stats,
        include_stack,
        depth,
    );
}

fn collectPattern(
    value: *const std.json.Value,
    repository: ?*const std.json.ObjectMap,
    rules: *std.array_list.Managed(Rule),
    stats: *Stats,
    include_stack: *[max_include_depth][]const u8,
    depth: usize,
) anyerror!void {
    if (value.* != .object) {
        stats.skipped += 1;
        return;
    }
    const object = &value.object;
    const scope = if (object.get("name")) |name_value|
        if (name_value == .string and name_value.string.len <= 256)
            name_value.string
        else
            ""
    else
        "";
    if (object.get("match")) |match_value| {
        if (match_value != .string) return error.InvalidTextMatePattern;
        try appendRule(rules, .{
            .kind = .match,
            .first = match_value.string,
            .style = styleForScope(scope),
        });
        return;
    }
    if (object.get("begin")) |begin_value| {
        const end_value = object.get("end") orelse return error.InvalidTextMatePattern;
        if (begin_value != .string or end_value != .string)
            return error.InvalidTextMatePattern;
        try appendRule(rules, .{
            .kind = .range,
            .first = begin_value.string,
            .second = end_value.string,
            .style = styleForScope(scope),
        });
        return;
    }
    if (object.get("include")) |include_value| {
        if (include_value != .string or
            !std.mem.startsWith(u8, include_value.string, "#") or
            include_value.string.len == 1)
        {
            stats.skipped += 1;
            return;
        }
        const key = include_value.string[1..];
        const repo = repository orelse return error.TextMateRepositoryEntryMissing;
        for (include_stack[0..depth]) |active| {
            if (std.mem.eql(u8, active, key)) return error.CyclicTextMateInclude;
        }
        const included = repo.getPtr(key) orelse return error.TextMateRepositoryEntryMissing;
        if (depth >= max_include_depth) return error.TextMateGrammarTooDeep;
        include_stack[depth] = key;
        try collectPattern(included, repository, rules, stats, include_stack, depth + 1);
        return;
    }
    if (object.get("patterns")) |nested| {
        if (nested != .array) return error.InvalidTextMatePattern;
        try collectPatternArray(
            nested.array.items,
            repository,
            rules,
            stats,
            include_stack,
            depth + 1,
        );
        return;
    }
    stats.skipped += 1;
}

fn appendRule(rules: *std.array_list.Managed(Rule), rule: Rule) !void {
    if (rules.items.len >= max_patterns) return error.TooManyTextMatePatterns;
    if (rule.first.len == 0 or rule.first.len > max_pattern_bytes or
        (rule.kind == .range and
            (rule.second.len == 0 or rule.second.len > max_pattern_bytes)))
        return error.InvalidTextMatePattern;
    if (std.mem.indexOfAny(u8, rule.first, "\x00\r\n") != null or
        std.mem.indexOfAny(u8, rule.second, "\x00\r\n") != null)
        return error.InvalidTextMatePattern;
    try rules.append(rule);
}

fn requiredString(
    object: *const std.json.ObjectMap,
    key: []const u8,
    max_len: usize,
) ![]const u8 {
    return (try optionalString(object, key, max_len)) orelse
        return error.InvalidTextMateGrammar;
}

fn optionalString(
    object: *const std.json.ObjectMap,
    key: []const u8,
    max_len: usize,
) !?[]const u8 {
    const value = object.get(key) orelse return null;
    if (value != .string or value.string.len == 0 or value.string.len > max_len or
        std.mem.indexOfAny(u8, value.string, "\x00\r\n") != null)
        return error.InvalidTextMateGrammar;
    return value.string;
}

fn languageIdAlloc(allocator: std.mem.Allocator, raw: []const u8) ![]u8 {
    const candidate = if (std.mem.lastIndexOfScalar(u8, raw, '.')) |dot|
        raw[dot + 1 ..]
    else
        raw;
    var result = try allocator.alloc(u8, @min(candidate.len, 64));
    errdefer allocator.free(result);
    var length: usize = 0;
    var previous_dash = false;
    for (candidate) |byte| {
        if (length >= result.len) break;
        const normalized: u8 = if (std.ascii.isAlphanumeric(byte))
            std.ascii.toLower(byte)
        else
            '-';
        if (normalized == '-' and (length == 0 or previous_dash)) continue;
        result[length] = normalized;
        length += 1;
        previous_dash = normalized == '-';
    }
    while (length > 0 and result[length - 1] == '-') length -= 1;
    if (length == 0) return error.InvalidTextMateLanguageId;
    return allocator.realloc(result, length);
}

fn validFileType(value: []const u8) bool {
    if (value.len == 0 or value.len > 64) return false;
    const trimmed = std.mem.trimStart(u8, value, ".");
    if (trimmed.len == 0) return false;
    return std.mem.indexOfAny(u8, value, "\x00\r\n/\\;") == null and
        (std.mem.startsWith(u8, value, "*.") or
            std.mem.indexOfAny(u8, value, "*?[]{}") == null);
}

fn styleForScope(scope: []const u8) []const u8 {
    if (std.mem.indexOf(u8, scope, "invalid") != null) return "error";
    if (std.mem.indexOf(u8, scope, "comment") != null) return "comment";
    if (std.mem.indexOf(u8, scope, "string") != null) return "string";
    if (std.mem.indexOf(u8, scope, "numeric") != null or
        std.mem.indexOf(u8, scope, "number") != null) return "number";
    if (std.mem.indexOf(u8, scope, "keyword") != null or
        std.mem.indexOf(u8, scope, "storage") != null) return "keyword";
    if (std.mem.indexOf(u8, scope, "type") != null or
        std.mem.indexOf(u8, scope, "class") != null) return "type";
    if (std.mem.indexOf(u8, scope, "function") != null or
        std.mem.indexOf(u8, scope, "method") != null) return "function";
    if (std.mem.indexOf(u8, scope, "variable") != null or
        std.mem.indexOf(u8, scope, "parameter") != null) return "variable";
    return "special";
}

fn writeXml(writer: *std.Io.Writer, value: []const u8, attribute: bool) !void {
    for (value) |byte| switch (byte) {
        '&' => try writer.writeAll("&amp;"),
        '<' => try writer.writeAll("&lt;"),
        '>' => try writer.writeAll("&gt;"),
        '"' => if (attribute) try writer.writeAll("&quot;") else try writer.writeByte(byte),
        '\'' => if (attribute) try writer.writeAll("&apos;") else try writer.writeByte(byte),
        else => try writer.writeByte(byte),
    };
}

test "converts bounded TextMate JSON with repository includes" {
    const source =
        \\{
        \\  "name": "Task Notes",
        \\  "scopeName": "source.task-note",
        \\  "fileTypes": ["note", ".task"],
        \\  "patterns": [
        \\    {"match": "\\\\b(TODO|DONE)\\\\b", "name": "keyword.control.task"},
        \\    {"begin": "#", "end": "$", "name": "comment.line.number-sign"},
        \\    {"include": "#numbers"}
        \\  ],
        \\  "repository": {
        \\    "numbers": {"patterns": [
        \\      {"match": "\\\\b[0-9]+\\\\b", "name": "constant.numeric"}
        \\    ]}
        \\  }
        \\}
    ;
    var converted = try convertAlloc(std.testing.allocator, source);
    defer converted.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("task-note", converted.language_id);
    try std.testing.expectEqualStrings("Task Notes", converted.display_name);
    try std.testing.expectEqual(@as(usize, 3), converted.pattern_count);
    try std.testing.expectEqual(@as(usize, 2), converted.file_type_count);
    try std.testing.expectEqual(@as(usize, 0), converted.skipped_patterns);
    try std.testing.expect(std.mem.indexOf(u8, converted.xml, "*.note;*.task") != null);
    try std.testing.expect(std.mem.indexOf(u8, converted.xml, "style-ref=\"keyword\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, converted.xml, "style-ref=\"comment\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, converted.xml, "style-ref=\"number\"") != null);
}

test "rejects malformed oversized and unsafe TextMate grammars" {
    try std.testing.expectError(
        error.InvalidTextMateGrammar,
        convertAlloc(std.testing.allocator, "{broken"),
    );
    const oversized = try std.testing.allocator.alloc(u8, max_source_bytes + 1);
    defer std.testing.allocator.free(oversized);
    @memset(oversized, 'x');
    try std.testing.expectError(
        error.TextMateGrammarTooLarge,
        convertAlloc(std.testing.allocator, oversized),
    );
    const unsafe =
        \\{"name":"Bad","scopeName":"source.bad","fileTypes":["../bad"],"patterns":[{"match":"x"}]}
    ;
    try std.testing.expectError(
        error.InvalidTextMateFileType,
        convertAlloc(std.testing.allocator, unsafe),
    );
}

test "duplicate scope names map to one deterministic precedence key" {
    const first =
        \\{"name":"One","scopeName":"source.shared","fileTypes":["one"],"patterns":[{"match":"one","name":"keyword"}]}
    ;
    const second =
        \\{"name":"Two","scopeName":"source.shared","fileTypes":["two"],"patterns":[{"match":"two","name":"string"}]}
    ;
    var first_conversion = try convertAlloc(std.testing.allocator, first);
    defer first_conversion.deinit(std.testing.allocator);
    var second_conversion = try convertAlloc(std.testing.allocator, second);
    defer second_conversion.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings(
        first_conversion.language_id,
        second_conversion.language_id,
    );
    try std.testing.expect(!std.mem.eql(
        u8,
        first_conversion.xml,
        second_conversion.xml,
    ));
}

test "rejects cyclic repository includes" {
    const source =
        \\{"name":"Cycle","scopeName":"source.cycle","fileTypes":["cycle"],"patterns":[{"include":"#a"}],"repository":{"a":{"include":"#a"}}}
    ;
    try std.testing.expectError(
        error.CyclicTextMateInclude,
        convertAlloc(std.testing.allocator, source),
    );
}

test "deterministic TextMate mutation corpus rejects safely or stays bounded" {
    const source =
        \\{"name":"Mutation","scopeName":"source.mutation","fileTypes":["mut"],"patterns":[{"match":"\\\\b(TODO|DONE)\\\\b","name":"keyword.control"},{"begin":"#","end":"$","name":"comment.line"}]}
    ;
    const mutation_bytes = [_]u8{ 0, 0xff, '{', '}', '[', ']', '"', '\\', '\n', 'x' };
    var random_state: u64 = 0x7465_7874_6d61_7465;
    var accepted: usize = 0;
    var rejected: usize = 0;
    for (0..256) |case_index| {
        const candidate = try std.testing.allocator.dupe(u8, source);
        defer std.testing.allocator.free(candidate);
        if (case_index % 8 != 0) {
            if (case_index % 8 == 1) {
                candidate[0] = 0;
            } else {
                const mutation_count = 1 + case_index % 4;
                for (0..mutation_count) |_| {
                    random_state ^= random_state << 13;
                    random_state ^= random_state >> 7;
                    random_state ^= random_state << 17;
                    const position: usize = @intCast(random_state % candidate.len);
                    const replacement: usize = @intCast(
                        (random_state >> 16) % mutation_bytes.len,
                    );
                    candidate[position] = mutation_bytes[replacement];
                }
            }
        }
        if (convertAlloc(std.testing.allocator, candidate)) |conversion_value| {
            var conversion = conversion_value;
            defer conversion.deinit(std.testing.allocator);
            try std.testing.expect(conversion.pattern_count > 0);
            try std.testing.expect(conversion.pattern_count <= max_patterns);
            try std.testing.expect(conversion.file_type_count <= max_file_types);
            try std.testing.expect(std.unicode.utf8ValidateSlice(conversion.xml));
            accepted += 1;
        } else |err| {
            if (err == error.OutOfMemory) return err;
            rejected += 1;
        }
    }
    try std.testing.expect(accepted >= 32);
    try std.testing.expect(rejected >= 32);
}
