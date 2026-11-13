const std = @import("std");
const builtin = @import("builtin");
const Vt = @import("Vt.zig");
const VtParser = @import("VtParser.zig");
const Unicode = @import("Unicode.zig");

const protocol_fixture = @embedFile("fixtures/agent-compat-vt-corpus.tsv");
const grapheme_fixture = @embedFile("fixtures/GraphemeBreakTest-17.0.0.txt");
const protocol_case_count: usize = 23;
const schedule_count: usize = 6;
const malformed_case_count: usize = 128;
const malformed_case_bytes: usize = 4096;
const unicode_mutation_count: usize = 256;
const AccountedAllocator = std.heap.DebugAllocator(.{
    .enable_memory_limit = true,
});

const ExpectedProtocol = struct {
    name: []const u8,
    input: []const u8,
    reply: []const u8,
    cursor_column: usize,
    cursor_row: usize,
    bracketed_paste: bool,
    synchronized_output: bool,
    blocked_osc52: u64,
    title: []const u8,
};

pub fn main(init: std.process.Init) !void {
    var debug_allocator: AccountedAllocator = .init;
    const grapheme_cases = runQualification(&debug_allocator) catch |err| {
        _ = debug_allocator.deinit();
        return err;
    };
    const residual_bytes = debug_allocator.total_requested_bytes;
    const leak_check = debug_allocator.deinit();
    if (residual_bytes != 0 or leak_check != .ok)
        return error.AllocatorAccountingFailed;

    var stdout_buffer: [2048]u8 = undefined;
    var stdout_file_writer: std.Io.File.Writer = .init(.stdout(), init.io, &stdout_buffer);
    const stdout = &stdout_file_writer.interface;
    defer stdout.flush() catch {};
    try stdout.print(
        "terminal_compatibility mode={s} protocol_cases={d} schedules={d} " ++
            "protocol_runs={d} malformed_cases={d} malformed_bytes={d} " ++
            "unicode_mutations={d} grapheme_cases={d} unicode_version={s} " ++
            "state_diff=true replies=true modes=true sgr=true osc8=true " ++
            "osc52_blocked=true c1=true parser_bounds=true allocator_leak_free=true " ++
            "allocator_residual_bytes={d} assertions=true\n",
        .{
            @tagName(builtin.mode),
            protocol_case_count,
            schedule_count,
            protocol_case_count * schedule_count,
            malformed_case_count,
            malformed_case_count * malformed_case_bytes,
            unicode_mutation_count,
            grapheme_cases,
            Unicode.unicode_version,
            residual_bytes,
        },
    );
}

fn runQualification(accounting: *AccountedAllocator) !usize {
    const allocator = accounting.allocator();
    const baseline = accounting.total_requested_bytes;
    try runProtocolCorpus(allocator, accounting, baseline);
    try runFeatureAssertions(allocator);
    if (accounting.total_requested_bytes != baseline)
        return error.FeatureAllocatorResidual;
    try runMalformedDifferential(allocator, accounting, baseline);
    try runUnicodeDifferential(allocator, accounting, baseline);
    const grapheme_cases = try Unicode.validateGraphemeBreakCorpus(grapheme_fixture);
    if (grapheme_cases != 766) return error.GraphemeCaseCountMismatch;
    if (accounting.total_requested_bytes != baseline)
        return error.QualificationAllocatorResidual;
    return grapheme_cases;
}

fn runProtocolCorpus(
    allocator: std.mem.Allocator,
    accounting: *AccountedAllocator,
    baseline: usize,
) !void {
    var lines = std.mem.splitScalar(u8, protocol_fixture, '\n');
    var case_index: usize = 0;
    while (lines.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, " \r");
        if (line.len == 0 or line[0] == '#') continue;
        {
            var input_buffer: [1024]u8 = undefined;
            var reply_buffer: [1024]u8 = undefined;
            const expected = try parseProtocolCase(line, &input_buffer, &reply_buffer);
            var direct = try Vt.Grid.init(allocator, 80, 24);
            defer direct.deinit();
            try direct.feed(expected.input);
            try validateExpectedProtocol(&direct, expected);

            for (1..schedule_count) |schedule| {
                var candidate = try Vt.Grid.init(allocator, 80, 24);
                defer candidate.deinit();
                try feedScheduled(&candidate, expected.input, schedule, case_index + 1);
                try validateExpectedProtocol(&candidate, expected);
                try compareGridState(&direct, &candidate);
            }
            case_index += 1;
        }
        if (accounting.total_requested_bytes != baseline)
            return error.ProtocolAllocatorResidual;
    }
    if (case_index != protocol_case_count) return error.ProtocolCaseCountMismatch;
}

fn parseProtocolCase(
    line: []const u8,
    input_buffer: []u8,
    reply_buffer: []u8,
) !ExpectedProtocol {
    var fields = std.mem.splitScalar(u8, line, '\t');
    const name = fields.next() orelse return error.InvalidProtocolFixture;
    const input = try decodeHex(
        fields.next() orelse return error.InvalidProtocolFixture,
        input_buffer,
    );
    const reply = try decodeHex(
        fields.next() orelse return error.InvalidProtocolFixture,
        reply_buffer,
    );
    const cursor_column = try std.fmt.parseInt(
        usize,
        fields.next() orelse return error.InvalidProtocolFixture,
        10,
    );
    const cursor_row = try std.fmt.parseInt(
        usize,
        fields.next() orelse return error.InvalidProtocolFixture,
        10,
    );
    const bracketed = parseFlag(fields.next() orelse return error.InvalidProtocolFixture);
    const synchronized = parseFlag(fields.next() orelse return error.InvalidProtocolFixture);
    const blocked_osc52 = try std.fmt.parseInt(
        u64,
        fields.next() orelse return error.InvalidProtocolFixture,
        10,
    );
    const encoded_title = fields.next() orelse return error.InvalidProtocolFixture;
    if (fields.next() != null) return error.InvalidProtocolFixture;
    return .{
        .name = name,
        .input = input,
        .reply = reply,
        .cursor_column = cursor_column,
        .cursor_row = cursor_row,
        .bracketed_paste = bracketed,
        .synchronized_output = synchronized,
        .blocked_osc52 = blocked_osc52,
        .title = if (std.mem.eql(u8, encoded_title, "-")) "" else encoded_title,
    };
}

fn parseFlag(value: []const u8) bool {
    return std.mem.eql(u8, value, "1");
}

fn validateExpectedProtocol(grid: *const Vt.Grid, expected: ExpectedProtocol) !void {
    if (!std.mem.eql(u8, expected.reply, grid.pendingReplies())) {
        std.debug.print("protocol reply mismatch: {s}\n", .{expected.name});
        return error.ProtocolReplyMismatch;
    }
    if (grid.cursor_column != expected.cursor_column or
        grid.cursor_row != expected.cursor_row or
        grid.bracketed_paste != expected.bracketed_paste or
        grid.synchronized_output != expected.synchronized_output or
        grid.blocked_osc52 != expected.blocked_osc52 or
        !std.mem.eql(u8, expected.title, grid.titleSlice()))
    {
        std.debug.print("protocol state mismatch: {s}\n", .{expected.name});
        return error.ProtocolStateMismatch;
    }
}

fn runFeatureAssertions(allocator: std.mem.Allocator) !void {
    {
        var grid = try Vt.Grid.init(allocator, 32, 4);
        defer grid.deinit();
        try grid.feed("\x1b]8;id=docs;https://example.com/dintty\x1b\\link" ++
            "\x1b]8;;\x1b\\ plain");
        var uri: [128]u8 = undefined;
        const uri_length = grid.cellHyperlink(0, 0, &uri);
        if (!std.mem.eql(u8, "https://example.com/dintty", uri[0..uri_length]) or
            grid.cell(0, 0).hyperlink_id == 0 or
            grid.cell(5, 0).hyperlink_id != 0)
            return error.Osc8AssertionFailed;
    }
    {
        var grid = try Vt.Grid.init(allocator, 32, 4);
        defer grid.deinit();
        try grid.feed("\x1b[1;2;3;4;9;38;2;10;20;30;48;5;17mX");
        const cell = grid.cell(0, 0);
        if (!cell.flags.bold or !cell.flags.dim or !cell.flags.italic or
            !cell.flags.underline or !cell.flags.strikethrough or
            grid.colorRgb(cell.foreground) != 0x0a141e or
            cell.background != 17)
            return error.SgrAssertionFailed;
    }
    {
        var grid = try Vt.Grid.init(allocator, 16, 2);
        defer grid.deinit();
        var payload: [VtParser.max_string_bytes + 128]u8 = undefined;
        @memset(&payload, 'x');
        try grid.feed("\x1b]2;");
        try grid.feed(&payload);
        try grid.feed("\x07");
        if (grid.parser_string_overflows != 1 or
            grid.parser.state != .ground or
            grid.titleSlice().len != 0)
            return error.ParserBoundAssertionFailed;
    }
}

fn runMalformedDifferential(
    allocator: std.mem.Allocator,
    accounting: *AccountedAllocator,
    baseline: usize,
) !void {
    for (0..malformed_case_count) |seed| {
        var bytes: [malformed_case_bytes]u8 = undefined;
        var random_state: u64 = 0x9e3779b97f4a7c15 ^ @as(u64, seed + 1);
        for (&bytes, 0..) |*byte, index| {
            byte.* = nextRandomByte(&random_state);
            if (index % 113 == 0) byte.* = 0x1b;
            if (index % 113 == 1) byte.* = '[';
            if (index % 127 == 2) byte.* = ']';
            if (index % 181 == 3) byte.* = 0x9b;
            if (index % 197 == 4) byte.* = 0x9d;
            if (index % 211 == 5) byte.* = 0x9c;
        }
        {
            var direct = try Vt.Grid.initWithHistoryLimit(allocator, 32, 8, 64);
            defer direct.deinit();
            try feedWithResizes(&direct, &bytes, 0, seed);
            try assertBounds(&direct);
            for (1..schedule_count) |schedule| {
                var candidate = try Vt.Grid.initWithHistoryLimit(allocator, 32, 8, 64);
                defer candidate.deinit();
                try feedWithResizes(&candidate, &bytes, schedule, seed);
                try assertBounds(&candidate);
                try compareGridState(&direct, &candidate);
            }
        }
        if (accounting.total_requested_bytes != baseline)
            return error.MalformedAllocatorResidual;
    }
}

fn runUnicodeDifferential(
    allocator: std.mem.Allocator,
    accounting: *AccountedAllocator,
    baseline: usize,
) !void {
    const fragments = [_][]const u8{
        "ASCII",
        "e\xcc\x81",
        "\xe7\x95\x8c",
        "\xf0\x9f\x9a\x80",
        "\xf0\x9f\x91\xa9\xe2\x80\x8d\xf0\x9f\x92\xbb",
        "\xf0\x9f\x87\xb5\xf0\x9f\x87\xb9",
        "\xe0\x80\x80",
        "\xed\xa0\x80",
        "\xf4\x90\x80\x80",
        "\x80\xbf\xc0\xc1\xf5",
        "\x1b[38:2::10:20:30m",
        "\x9b0m",
        "\x1b]2;unicode\x1b\\",
        "\r\n\t\x07",
    };
    for (0..unicode_mutation_count) |seed| {
        var bytes: [512]u8 = undefined;
        var length: usize = 0;
        var random_state: u64 = 0xd1b54a32d192ed03 ^ @as(u64, seed + 1);
        for (0..48) |_| {
            const fragment = fragments[nextRandomByte(&random_state) % fragments.len];
            if (length + fragment.len > bytes.len) break;
            @memcpy(bytes[length .. length + fragment.len], fragment);
            length += fragment.len;
        }
        {
            var direct = try Vt.Grid.initWithHistoryLimit(allocator, 24, 6, 32);
            defer direct.deinit();
            try direct.feed(bytes[0..length]);
            try assertBounds(&direct);
            for (1..schedule_count) |schedule| {
                var candidate = try Vt.Grid.initWithHistoryLimit(allocator, 24, 6, 32);
                defer candidate.deinit();
                try feedScheduled(&candidate, bytes[0..length], schedule, seed);
                try assertBounds(&candidate);
                try compareGridState(&direct, &candidate);
            }
        }
        if (accounting.total_requested_bytes != baseline)
            return error.UnicodeAllocatorResidual;
    }
}

fn feedWithResizes(
    grid: *Vt.Grid,
    bytes: []const u8,
    schedule: usize,
    seed: usize,
) !void {
    const first = bytes.len / 3;
    const second = bytes.len * 2 / 3;
    try feedScheduled(grid, bytes[0..first], schedule, seed + 1);
    try grid.resize(8 + seed % 41, 2 + seed % 11);
    try feedScheduled(grid, bytes[first..second], schedule, seed + 2);
    try grid.resize(12 + seed % 37, 3 + seed % 9);
    try feedScheduled(grid, bytes[second..], schedule, seed + 3);
}

fn feedScheduled(grid: *Vt.Grid, bytes: []const u8, schedule: usize, seed: usize) !void {
    if (schedule == 0) return grid.feed(bytes);
    if (schedule == 1) {
        for (bytes) |byte| try grid.feedByte(byte);
        return;
    }
    var offset: usize = 0;
    while (offset < bytes.len) {
        const count = @min(
            bytes.len - offset,
            1 + (offset * 17 + seed * 13 + schedule * 19) % (schedule * 11),
        );
        try grid.feed(bytes[offset .. offset + count]);
        offset += count;
    }
}

fn assertBounds(grid: *const Vt.Grid) !void {
    if (grid.pendingReplies().len > grid.reply_buffer.len or
        grid.history.items.len > grid.history_limit or
        grid.parser.string_length > VtParser.max_string_bytes or
        grid.utf8_expected > 3 or
        grid.titleSlice().len > 512)
        return error.BoundExceeded;
}

fn compareGridState(expected: *const Vt.Grid, actual: *const Vt.Grid) !void {
    if (expected.columns != actual.columns or expected.rows != actual.rows or
        expected.cursor_column != actual.cursor_column or
        expected.cursor_row != actual.cursor_row or
        expected.saved_cursor_column != actual.saved_cursor_column or
        expected.saved_cursor_row != actual.saved_cursor_row or
        expected.saved_wrap_pending != actual.saved_wrap_pending or
        expected.saved_origin_mode != actual.saved_origin_mode or
        expected.alternate_saved_cursor_column != actual.alternate_saved_cursor_column or
        expected.alternate_saved_cursor_row != actual.alternate_saved_cursor_row or
        expected.alternate_saved_wrap_pending != actual.alternate_saved_wrap_pending or
        expected.alternate_saved_margin_top != actual.alternate_saved_margin_top or
        expected.alternate_saved_margin_bottom != actual.alternate_saved_margin_bottom or
        expected.alternate_saved_origin_mode != actual.alternate_saved_origin_mode or
        expected.saved_charset_g0_dec_special != actual.saved_charset_g0_dec_special or
        expected.saved_charset_g1_dec_special != actual.saved_charset_g1_dec_special or
        expected.saved_charset_use_g1 != actual.saved_charset_use_g1 or
        expected.screen_origin != actual.screen_origin or
        expected.cursor_visible != actual.cursor_visible or
        expected.bracketed_paste != actual.bracketed_paste or
        expected.application_cursor_keys != actual.application_cursor_keys or
        expected.insert_mode != actual.insert_mode or
        expected.auto_wrap != actual.auto_wrap or
        expected.wrap_pending != actual.wrap_pending or
        expected.origin_mode != actual.origin_mode or
        expected.charset_g0_dec_special != actual.charset_g0_dec_special or
        expected.charset_g1_dec_special != actual.charset_g1_dec_special or
        expected.charset_use_g1 != actual.charset_use_g1 or
        expected.last_printed_codepoint != actual.last_printed_codepoint or
        expected.mouse_tracking != actual.mouse_tracking or
        expected.mouse_encoding != actual.mouse_encoding or
        expected.focus_reporting != actual.focus_reporting or
        expected.synchronized_output != actual.synchronized_output or
        expected.blocked_osc52 != actual.blocked_osc52 or
        expected.parser_string_overflows != actual.parser_string_overflows or
        expected.reply_overflows != actual.reply_overflows or
        expected.bell_serial != actual.bell_serial or
        expected.history.items.len != actual.history.items.len or
        expected.history_start != actual.history_start or
        expected.viewport_offset != actual.viewport_offset or
        expected.margin_top != actual.margin_top or
        expected.margin_bottom != actual.margin_bottom or
        expected.active_hyperlink != actual.active_hyperlink or
        expected.hyperlink_overflows != actual.hyperlink_overflows or
        expected.utf8_codepoint != actual.utf8_codepoint or
        expected.utf8_minimum != actual.utf8_minimum or
        expected.utf8_expected != actual.utf8_expected or
        expected.parser.state != actual.parser.state or
        expected.parser.string_length != actual.parser.string_length or
        expected.parser.string_overflow != actual.parser.string_overflow or
        (expected.alternate_cells != null) != (actual.alternate_cells != null))
        return error.StateScalarMismatch;

    if (!std.mem.eql(u8, expected.titleSlice(), actual.titleSlice()) or
        !std.mem.eql(u8, expected.pendingReplies(), actual.pendingReplies()) or
        !std.mem.eql(u8, expected.parser.stringSlice(), actual.parser.stringSlice()) or
        !std.mem.eql(bool, expected.tab_stops, actual.tab_stops) or
        !std.mem.eql(u32, expected.true_colors.items, actual.true_colors.items))
        return error.StateSliceMismatch;

    var expected_row: [128]u64 = undefined;
    var actual_row: [128]u64 = undefined;
    var expected_text: [128]u8 = undefined;
    var actual_text: [128]u8 = undefined;
    var expected_uri: [128]u8 = undefined;
    var actual_uri: [128]u8 = undefined;
    for (0..expected.rows) |row| {
        const expected_count = expected.packedRow(row, &expected_row);
        const actual_count = actual.packedRow(row, &actual_row);
        if (expected_count != actual_count or
            !std.mem.eql(u64, expected_row[0..expected_count], actual_row[0..actual_count]))
            return error.StateRowMismatch;
        for (0..expected.columns) |column| {
            const expected_text_length = expected.cellText(column, row, &expected_text);
            const actual_text_length = actual.cellText(column, row, &actual_text);
            if (expected_text_length != actual_text_length or
                !std.mem.eql(
                    u8,
                    expected_text[0..expected_text_length],
                    actual_text[0..actual_text_length],
                ))
                return error.StateCellTextMismatch;
            const expected_uri_length = expected.cellHyperlink(column, row, &expected_uri);
            const actual_uri_length = actual.cellHyperlink(column, row, &actual_uri);
            if (expected_uri_length != actual_uri_length or
                !std.mem.eql(
                    u8,
                    expected_uri[0..expected_uri_length],
                    actual_uri[0..actual_uri_length],
                ))
                return error.StateHyperlinkMismatch;
        }
    }
}

fn nextRandomByte(state: *u64) u8 {
    state.* ^= state.* << 13;
    state.* ^= state.* >> 7;
    state.* ^= state.* << 17;
    return @truncate(state.*);
}

fn decodeHex(encoded: []const u8, output: []u8) ![]const u8 {
    if (std.mem.eql(u8, encoded, "-")) return output[0..0];
    if (encoded.len % 2 != 0 or encoded.len / 2 > output.len)
        return error.InvalidProtocolHex;
    for (0..encoded.len / 2) |index| {
        output[index] = (try hexNibble(encoded[index * 2])) << 4 |
            try hexNibble(encoded[index * 2 + 1]);
    }
    return output[0 .. encoded.len / 2];
}

fn hexNibble(value: u8) !u8 {
    return switch (value) {
        '0'...'9' => value - '0',
        'a'...'f' => value - 'a' + 10,
        'A'...'F' => value - 'A' + 10,
        else => error.InvalidProtocolHex,
    };
}
