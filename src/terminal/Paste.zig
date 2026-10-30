const std = @import("std");

pub const PastePolicy = enum {
    literal,
    shell_one_line,
};

pub const PrepareOptions = struct {
    policy: PastePolicy = .literal,
    bracketed_paste: bool = true,
    repair_multiline_shell_commands: bool = true,
    strip_unsafe_controls: bool = true,
};

pub const PreparedPaste = struct {
    bytes: []u8,
    applied_policy: PastePolicy,
    bracketed: bool,
    literal_required: bool,
    unsafe_controls_stripped: usize,

    pub fn deinit(self: PreparedPaste, allocator: std.mem.Allocator) void {
        allocator.free(self.bytes);
    }
};

const bracketed_paste_start = "\x1b[200~";
const bracketed_paste_end = "\x1b[201~";

pub fn preparePasteAlloc(allocator: std.mem.Allocator, input: []const u8, options: PrepareOptions) !PreparedPaste {
    if (options.policy == .literal) {
        return prepareLiteralPasteAlloc(allocator, input, options);
    }

    const normalized = try removeBracketedPasteMarkersAlloc(allocator, input);
    defer allocator.free(normalized);

    const sanitized: SanitizedBytes = if (options.strip_unsafe_controls)
        try stripUnsafeControlsDetailedAlloc(allocator, normalized)
    else
        .{ .bytes = try allocator.dupe(u8, normalized), .stripped = 0 };
    errdefer allocator.free(sanitized.bytes);

    const literal_required = requiresLiteralPaste(sanitized.bytes);
    var body = sanitized.bytes;
    var applied_policy = PastePolicy.literal;

    if (options.policy == .shell_one_line and options.repair_multiline_shell_commands and !literal_required) {
        const repaired = try shellOneLineAlloc(allocator, body);
        allocator.free(body);
        body = repaired;
        applied_policy = .shell_one_line;
    }
    errdefer allocator.free(body);

    const bytes = if (options.bracketed_paste)
        try wrapBracketedPasteAlloc(allocator, body)
    else
        try allocator.dupe(u8, body);
    allocator.free(body);

    return .{
        .bytes = bytes,
        .applied_policy = applied_policy,
        .bracketed = options.bracketed_paste,
        .literal_required = literal_required,
        .unsafe_controls_stripped = sanitized.stripped,
    };
}

fn prepareLiteralPasteAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: PrepareOptions,
) !PreparedPaste {
    const scan = scanLiteralPaste(input, null, options.strip_unsafe_controls);
    const wrapper_bytes = if (options.bracketed_paste)
        bracketed_paste_start.len + bracketed_paste_end.len
    else
        0;
    const bytes = try allocator.alloc(
        u8,
        try std.math.add(usize, scan.length, wrapper_bytes),
    );
    errdefer allocator.free(bytes);
    var body_start: usize = 0;
    if (options.bracketed_paste) {
        @memcpy(bytes[0..bracketed_paste_start.len], bracketed_paste_start);
        body_start = bracketed_paste_start.len;
    }
    const body = bytes[body_start .. body_start + scan.length];
    const written = scanLiteralPaste(input, body, options.strip_unsafe_controls);
    std.debug.assert(written.length == body.len and
        written.stripped == scan.stripped);
    if (options.bracketed_paste) {
        @memcpy(bytes[body_start + body.len ..], bracketed_paste_end);
    }
    return .{
        .bytes = bytes,
        .applied_policy = .literal,
        .bracketed = options.bracketed_paste,
        .literal_required = requiresLiteralPaste(body),
        .unsafe_controls_stripped = scan.stripped,
    };
}

const LiteralPasteScan = struct {
    length: usize,
    stripped: usize,
};

fn scanLiteralPaste(
    input: []const u8,
    output: ?[]u8,
    strip_unsafe_controls: bool,
) LiteralPasteScan {
    var used: usize = 0;
    var stripped: usize = 0;
    var index: usize = 0;
    while (index < input.len) {
        if (std.mem.startsWith(u8, input[index..], bracketed_paste_start)) {
            index += bracketed_paste_start.len;
            continue;
        }
        if (std.mem.startsWith(u8, input[index..], bracketed_paste_end)) {
            index += bracketed_paste_end.len;
            continue;
        }
        const byte = input[index];
        index += 1;
        if (strip_unsafe_controls) switch (byte) {
            '\t', '\n', '\r' => {},
            0x00...0x08, 0x0b, 0x0c, 0x0e...0x1f, 0x7f => {
                stripped += 1;
                continue;
            },
            else => {},
        };
        if (output) |buffer| buffer[used] = byte;
        used += 1;
    }
    return .{ .length = used, .stripped = stripped };
}

pub fn sanitizeAlloc(allocator: std.mem.Allocator, input: []const u8, policy: PastePolicy) ![]u8 {
    const clean = try stripUnsafeControlsAlloc(allocator, input);
    errdefer allocator.free(clean);

    return switch (policy) {
        .literal => clean,
        .shell_one_line => blk: {
            const one = try shellOneLineAlloc(allocator, clean);
            allocator.free(clean);
            break :blk one;
        },
    };
}

pub fn requiresLiteralPaste(input: []const u8) bool {
    return std.mem.indexOf(u8, input, "<<") != null;
}

pub fn stripUnsafeControlsAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    const detailed = try stripUnsafeControlsDetailedAlloc(allocator, input);
    return detailed.bytes;
}

const SanitizedBytes = struct {
    bytes: []u8,
    stripped: usize,
};

pub fn stripUnsafeControlsDetailedAlloc(allocator: std.mem.Allocator, input: []const u8) !SanitizedBytes {
    var out = std.array_list.Managed(u8).init(allocator);
    errdefer out.deinit();
    try out.ensureTotalCapacity(input.len);

    var stripped: usize = 0;
    var i: usize = 0;
    while (i < input.len) : (i += 1) {
        const c = input[i];
        switch (c) {
            '\t', '\n', '\r' => try out.append(c),
            0x00...0x08, 0x0b, 0x0c, 0x0e...0x1f, 0x7f => stripped += 1,
            else => try out.append(c),
        }
    }
    return .{
        .bytes = try out.toOwnedSlice(),
        .stripped = stripped,
    };
}

pub fn shellOneLineAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    if (requiresLiteralPaste(input)) {
        return error.HereDocNeedsLiteralPaste;
    }

    var out = std.array_list.Managed(u8).init(allocator);
    errdefer out.deinit();
    try out.ensureTotalCapacity(input.len);

    var it = std.mem.splitAny(u8, input, "\r\n");
    var wrote = false;
    var continued = false;
    while (it.next()) |raw_line| {
        var line = std.mem.trim(u8, raw_line, " \t");
        if (line.len == 0) continue;

        var next_continued = false;
        if (line[line.len - 1] == '\\') {
            line = std.mem.trimEnd(u8, line[0 .. line.len - 1], " \t");
            next_continued = true;
        }

        if (wrote) {
            if (continued) {
                try out.append(' ');
            } else {
                try out.appendSlice("; ");
            }
        }
        try out.appendSlice(line);
        wrote = true;
        continued = next_continued;
    }

    return out.toOwnedSlice();
}

pub fn removeBracketedPasteMarkersAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var out = std.array_list.Managed(u8).init(allocator);
    errdefer out.deinit();
    try out.ensureTotalCapacity(input.len);

    var i: usize = 0;
    while (i < input.len) {
        if (std.mem.startsWith(u8, input[i..], bracketed_paste_start)) {
            i += bracketed_paste_start.len;
            continue;
        }
        if (std.mem.startsWith(u8, input[i..], bracketed_paste_end)) {
            i += bracketed_paste_end.len;
            continue;
        }
        try out.append(input[i]);
        i += 1;
    }
    return out.toOwnedSlice();
}

pub fn wrapBracketedPasteAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var out = std.array_list.Managed(u8).init(allocator);
    errdefer out.deinit();
    try out.ensureTotalCapacity(try std.math.add(
        usize,
        input.len,
        bracketed_paste_start.len + bracketed_paste_end.len,
    ));
    try out.appendSlice(bracketed_paste_start);
    try out.appendSlice(input);
    try out.appendSlice(bracketed_paste_end);
    return out.toOwnedSlice();
}

test "shell paste repair joins multiline commands" {
    const allocator = std.testing.allocator;
    const fixed = try shellOneLineAlloc(allocator,
        \\git status
        \\git diff --check
    );
    defer allocator.free(fixed);
    try std.testing.expectEqualStrings("git status; git diff --check", fixed);
}

test "shell paste repair handles backslash continuations" {
    const allocator = std.testing.allocator;
    const fixed = try shellOneLineAlloc(allocator,
        \\zig build \
        \\  -Doptimize=ReleaseFast
    );
    defer allocator.free(fixed);
    try std.testing.expectEqualStrings("zig build -Doptimize=ReleaseFast", fixed);
}

test "shell paste repair refuses heredocs" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(error.HereDocNeedsLiteralPaste, shellOneLineAlloc(allocator,
        \\cat <<EOF
        \\hello
        \\EOF
    ));
}

test "paste preparation wraps shell repairs in bracketed paste" {
    const allocator = std.testing.allocator;
    const prepared = try preparePasteAlloc(allocator,
        \\git status
        \\git diff --check
    , .{ .policy = .shell_one_line });
    defer prepared.deinit(allocator);

    try std.testing.expect(prepared.bracketed);
    try std.testing.expectEqual(PastePolicy.shell_one_line, prepared.applied_policy);
    try std.testing.expectEqualStrings("\x1b[200~git status; git diff --check\x1b[201~", prepared.bytes);
}

test "paste preparation keeps heredocs literal and bracketed" {
    const allocator = std.testing.allocator;
    const prepared = try preparePasteAlloc(allocator,
        \\cat <<EOF
        \\hello
        \\EOF
    , .{ .policy = .shell_one_line });
    defer prepared.deinit(allocator);

    try std.testing.expect(prepared.literal_required);
    try std.testing.expectEqual(PastePolicy.literal, prepared.applied_policy);
    try std.testing.expectEqualStrings(
        "\x1b[200~cat <<EOF\nhello\nEOF\x1b[201~",
        prepared.bytes,
    );
}

test "paste preparation strips unsafe controls without corrupting bracket markers" {
    const allocator = std.testing.allocator;
    const prepared = try preparePasteAlloc(
        allocator,
        "\x1b[200~printf 'ok'\x07\n\x1b[201~",
        .{ .policy = .literal },
    );
    defer prepared.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 1), prepared.unsafe_controls_stripped);
    try std.testing.expectEqualStrings("\x1b[200~printf 'ok'\n\x1b[201~", prepared.bytes);
}

test "paste preparation can produce unbracketed literal payloads" {
    const allocator = std.testing.allocator;
    const prepared = try preparePasteAlloc(allocator, "echo ok", .{
        .policy = .literal,
        .bracketed_paste = false,
    });
    defer prepared.deinit(allocator);

    try std.testing.expect(!prepared.bracketed);
    try std.testing.expectEqualStrings("echo ok", prepared.bytes);
}

test "literal paste preparation uses one owned buffer" {
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{
        .fail_index = 1,
    });
    const allocator = failing.allocator();
    const prepared = try preparePasteAlloc(
        allocator,
        "\x1b[200~echo ok\x07\x1b[201~",
        .{ .policy = .literal },
    );
    defer prepared.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 1), failing.alloc_index);
    try std.testing.expectEqual(@as(usize, 1), prepared.unsafe_controls_stripped);
    try std.testing.expectEqualStrings("\x1b[200~echo ok\x1b[201~", prepared.bytes);
}
