const std = @import("std");

pub const max_parameters = 16;
pub const max_subparameters = 8;
pub const max_intermediates = 2;
pub const max_string_bytes = 4096;
const empty_parameter = Parameter{};

pub const Parameter = struct {
    values: [max_subparameters]u16 = [_]u16{0} ** max_subparameters,
    present: [max_subparameters]bool = [_]bool{false} ** max_subparameters,
    count: usize = 1,

    pub fn valueOr(self: *const Parameter, index: usize, default: u16) u16 {
        if (index >= self.count or !self.present[index]) return default;
        return self.values[index];
    }

    pub fn isPresent(self: *const Parameter, index: usize) bool {
        return index < self.count and self.present[index];
    }

    fn appendDigit(self: *Parameter, digit: u8) void {
        const index = self.count - 1;
        self.present[index] = true;
        self.values[index] = @min(
            @as(u32, self.values[index]) * 10 + digit,
            std.math.maxInt(u16),
        );
    }

    fn nextSubparameter(self: *Parameter) bool {
        if (self.count >= max_subparameters) return false;
        self.values[self.count] = 0;
        self.present[self.count] = false;
        self.count += 1;
        return true;
    }
};

pub const Csi = struct {
    private_marker: u8 = 0,
    intermediates: [max_intermediates]u8 = [_]u8{0} ** max_intermediates,
    intermediate_count: usize = 0,
    parameters: [max_parameters]Parameter = [_]Parameter{.{}} ** max_parameters,
    parameter_count: usize = 1,
    final: u8 = 0,

    pub fn parameter(self: *const Csi, index: usize) *const Parameter {
        return if (index < self.parameter_count) &self.parameters[index] else &empty_parameter;
    }

    pub fn valueOr(self: *const Csi, index: usize, default: u16) u16 {
        return self.parameter(index).valueOr(0, default);
    }

    pub fn hasIntermediate(self: Csi, value: u8) bool {
        return self.intermediate_count == 1 and self.intermediates[0] == value;
    }
};

pub const Escape = struct {
    intermediates: [max_intermediates]u8 = [_]u8{0} ** max_intermediates,
    intermediate_count: usize = 0,
    final: u8,
};

pub const StringKind = enum {
    osc,
    dcs,
    sos_pm_apc,
};

pub const StringEvent = struct {
    kind: StringKind,
    length: usize,
    overflow: bool,
};

pub const Event = union(enum) {
    none,
    print: u8,
    execute: u8,
    escape: Escape,
    csi: *const Csi,
    string: StringEvent,
};

pub const State = enum {
    ground,
    escape,
    escape_intermediate,
    csi_entry,
    csi_parameter,
    csi_intermediate,
    csi_ignore,
    dcs_entry,
    dcs_parameter,
    dcs_intermediate,
    dcs_passthrough,
    dcs_ignore,
    osc_string,
    sos_pm_apc_string,
    string_escape,
};

const ByteClass = enum {
    c0,
    escape,
    digit,
    semicolon,
    colon,
    private,
    intermediate,
    final,
    delete,
    high,
};

const byte_classes = blk: {
    var table = [_]ByteClass{.high} ** 256;
    for (0x00..0x20) |byte| table[byte] = .c0;
    table[0x1b] = .escape;
    table[0x7f] = .delete;
    for ('0'..'9' + 1) |byte| table[byte] = .digit;
    table[';'] = .semicolon;
    table[':'] = .colon;
    for (0x3c..0x40) |byte| table[byte] = .private;
    for (0x20..0x30) |byte| table[byte] = .intermediate;
    for (0x40..0x7f) |byte| table[byte] = .final;
    break :blk table;
};

pub const Parser = struct {
    state: State = .ground,
    csi: Csi = .{},
    dcs_header: Csi = .{},
    escape_intermediates: [max_intermediates]u8 = [_]u8{0} ** max_intermediates,
    escape_intermediate_count: usize = 0,
    string_kind: StringKind = .osc,
    string_bytes: [max_string_bytes]u8 = undefined,
    string_length: usize = 0,
    string_overflow: bool = false,
    string_escape_return: State = .ground,

    pub fn isGround(self: Parser) bool {
        return self.state == .ground;
    }

    pub fn stringSlice(self: *const Parser) []const u8 {
        return self.string_bytes[0..self.string_length];
    }

    pub fn dcsHeader(self: Parser) Csi {
        return self.dcs_header;
    }

    pub fn reset(self: *Parser) void {
        self.state = .ground;
        self.resetCsi();
        self.escape_intermediate_count = 0;
        self.string_length = 0;
        self.string_overflow = false;
    }

    pub fn feed(self: *Parser, byte: u8) Event {
        if (byte == 0x18 or byte == 0x1a) {
            self.reset();
            return .none;
        }
        if (byte == 0x9c and self.inString()) return self.finishString();
        return switch (self.state) {
            .ground => self.feedGround(byte),
            .escape => self.feedEscape(byte),
            .escape_intermediate => self.feedEscapeIntermediate(byte),
            .csi_entry, .csi_parameter => self.feedCsi(byte, false),
            .csi_intermediate => self.feedCsiIntermediate(byte, false),
            .csi_ignore => self.feedIgnore(byte),
            .dcs_entry, .dcs_parameter => self.feedCsi(byte, true),
            .dcs_intermediate => self.feedCsiIntermediate(byte, true),
            .dcs_passthrough => self.feedStringByte(byte),
            .dcs_ignore => self.feedDcsIgnore(byte),
            .osc_string, .sos_pm_apc_string => self.feedStringByte(byte),
            .string_escape => self.feedStringEscape(byte),
        };
    }

    fn feedGround(self: *Parser, byte: u8) Event {
        if (byte == 0x1b) {
            self.startEscape();
            return .none;
        }
        if (byte == 0x90) return self.startDcs();
        if (byte == 0x98 or byte == 0x9e or byte == 0x9f)
            return self.startString(.sos_pm_apc);
        if (byte == 0x9b) return self.startCsi(false);
        if (byte == 0x9d) return self.startString(.osc);
        if (byte <= 0x1f or (byte >= 0x80 and byte <= 0x9f))
            return .{ .execute = byte };
        if (byte == 0x7f) return .none;
        return .{ .print = byte };
    }

    fn feedEscape(self: *Parser, byte: u8) Event {
        if (byte == 0x1b) {
            self.startEscape();
            return .none;
        }
        if (byte <= 0x1f) return .{ .execute = byte };
        if (byte == '[') return self.startCsi(false);
        if (byte == ']') return self.startString(.osc);
        if (byte == 'P') return self.startDcs();
        if (byte == 'X' or byte == '^' or byte == '_')
            return self.startString(.sos_pm_apc);
        return switch (byte) {
            0x20...0x2f => blk: {
                self.escape_intermediates[0] = byte;
                self.escape_intermediate_count = 1;
                self.state = .escape_intermediate;
                break :blk .none;
            },
            0x30...0x7e => self.finishEscape(byte),
            else => blk: {
                self.state = .ground;
                break :blk .none;
            },
        };
    }

    fn feedEscapeIntermediate(self: *Parser, byte: u8) Event {
        if (byte == 0x1b) {
            self.startEscape();
            return .none;
        }
        if (byte <= 0x1f) return .{ .execute = byte };
        if (byte >= 0x20 and byte <= 0x2f) {
            if (self.escape_intermediate_count >= max_intermediates) {
                self.state = .ground;
            } else {
                self.escape_intermediates[self.escape_intermediate_count] = byte;
                self.escape_intermediate_count += 1;
            }
            return .none;
        }
        if (byte >= 0x30 and byte <= 0x7e) return self.finishEscape(byte);
        self.state = .ground;
        return .none;
    }

    fn feedCsi(self: *Parser, byte: u8, dcs: bool) Event {
        if (byte == 0x1b) {
            self.startEscape();
            return .none;
        }
        if (byte <= 0x1f) return .{ .execute = byte };
        switch (byte_classes[byte]) {
            .digit => {
                self.currentParameter().appendDigit(byte - '0');
                self.state = if (dcs) .dcs_parameter else .csi_parameter;
            },
            .semicolon => {
                if (!self.nextParameter())
                    self.state = if (dcs) .dcs_ignore else .csi_ignore
                else
                    self.state = if (dcs) .dcs_parameter else .csi_parameter;
            },
            .colon => {
                if (!self.currentParameter().nextSubparameter())
                    self.state = if (dcs) .dcs_ignore else .csi_ignore
                else
                    self.state = if (dcs) .dcs_parameter else .csi_parameter;
            },
            .private => {
                if (self.state == .csi_entry or self.state == .dcs_entry) {
                    if (self.csi.private_marker == 0)
                        self.csi.private_marker = byte
                    else
                        self.state = if (dcs) .dcs_ignore else .csi_ignore;
                } else {
                    self.state = if (dcs) .dcs_ignore else .csi_ignore;
                }
            },
            .intermediate => {
                self.csi.intermediates[0] = byte;
                self.csi.intermediate_count = 1;
                self.state = if (dcs) .dcs_intermediate else .csi_intermediate;
            },
            .final => return self.finishCsi(byte, dcs),
            .delete => {},
            else => self.state = if (dcs) .dcs_ignore else .csi_ignore,
        }
        return .none;
    }

    fn feedCsiIntermediate(self: *Parser, byte: u8, dcs: bool) Event {
        if (byte == 0x1b) {
            self.startEscape();
            return .none;
        }
        if (byte <= 0x1f) return .{ .execute = byte };
        if (byte >= 0x20 and byte <= 0x2f) {
            if (self.csi.intermediate_count >= max_intermediates)
                self.state = if (dcs) .dcs_ignore else .csi_ignore
            else {
                self.csi.intermediates[self.csi.intermediate_count] = byte;
                self.csi.intermediate_count += 1;
            }
            return .none;
        }
        if (byte >= 0x40 and byte <= 0x7e) return self.finishCsi(byte, dcs);
        self.state = if (dcs) .dcs_ignore else .csi_ignore;
        return .none;
    }

    fn feedIgnore(self: *Parser, byte: u8) Event {
        if (byte == 0x1b) self.startEscape() else if (byte >= 0x40 and byte <= 0x7e)
            self.state = .ground;
        return .none;
    }

    fn feedDcsIgnore(self: *Parser, byte: u8) Event {
        if (byte == 0x1b) {
            self.string_kind = .dcs;
            self.string_escape_return = .dcs_ignore;
            self.state = .string_escape;
        }
        return .none;
    }

    fn feedStringByte(self: *Parser, byte: u8) Event {
        if (self.state == .osc_string and byte == 0x07)
            return self.finishString();
        if (byte == 0x1b) {
            self.string_escape_return = self.state;
            self.state = .string_escape;
            return .none;
        }
        self.appendStringByte(byte);
        return .none;
    }

    fn feedStringEscape(self: *Parser, byte: u8) Event {
        if (byte == '\\') return self.finishString();
        if (byte == 0x1b) return .none;
        if (self.string_escape_return != .dcs_ignore) {
            self.appendStringByte(0x1b);
            self.appendStringByte(byte);
        }
        self.state = self.string_escape_return;
        return .none;
    }

    fn startEscape(self: *Parser) void {
        self.state = .escape;
        self.escape_intermediate_count = 0;
    }

    fn startCsi(self: *Parser, dcs: bool) Event {
        self.resetCsi();
        self.state = if (dcs) .dcs_entry else .csi_entry;
        return .none;
    }

    fn startDcs(self: *Parser) Event {
        return self.startCsi(true);
    }

    fn startString(self: *Parser, kind: StringKind) Event {
        self.string_kind = kind;
        self.string_length = 0;
        self.string_overflow = false;
        self.state = switch (kind) {
            .osc => .osc_string,
            .dcs => .dcs_passthrough,
            .sos_pm_apc => .sos_pm_apc_string,
        };
        return .none;
    }

    fn finishEscape(self: *Parser, final: u8) Event {
        const event = Escape{
            .intermediates = self.escape_intermediates,
            .intermediate_count = self.escape_intermediate_count,
            .final = final,
        };
        self.state = .ground;
        self.escape_intermediate_count = 0;
        return .{ .escape = event };
    }

    fn finishCsi(self: *Parser, final: u8, dcs: bool) Event {
        self.csi.final = final;
        if (dcs) {
            self.dcs_header = self.csi;
            return self.startString(.dcs);
        }
        self.state = .ground;
        return .{ .csi = &self.csi };
    }

    fn finishString(self: *Parser) Event {
        const event = StringEvent{
            .kind = self.string_kind,
            .length = self.string_length,
            .overflow = self.string_overflow,
        };
        self.state = .ground;
        return .{ .string = event };
    }

    fn currentParameter(self: *Parser) *Parameter {
        return &self.csi.parameters[self.csi.parameter_count - 1];
    }

    fn nextParameter(self: *Parser) bool {
        if (self.csi.parameter_count >= max_parameters) return false;
        self.csi.parameters[self.csi.parameter_count] = .{};
        self.csi.parameter_count += 1;
        return true;
    }

    fn resetCsi(self: *Parser) void {
        self.csi.private_marker = 0;
        self.csi.intermediate_count = 0;
        self.csi.parameter_count = 1;
        self.csi.parameters[0].values[0] = 0;
        self.csi.parameters[0].present[0] = false;
        self.csi.parameters[0].count = 1;
        self.csi.final = 0;
    }

    fn appendStringByte(self: *Parser, byte: u8) void {
        if (self.string_length == self.string_bytes.len) {
            self.string_overflow = true;
            return;
        }
        self.string_bytes[self.string_length] = byte;
        self.string_length += 1;
    }

    fn inString(self: Parser) bool {
        return switch (self.state) {
            .dcs_passthrough,
            .dcs_ignore,
            .osc_string,
            .sos_pm_apc_string,
            .string_escape,
            => true,
            else => false,
        };
    }
};

test "VT parser retains explicit missing and colon subparameters" {
    var parser = Parser{};
    var event: Event = .none;
    for ("\x1b[1;;38:2::10:20:30m") |byte| {
        const next = parser.feed(byte);
        if (next != .none) event = next;
    }
    const csi = event.csi.*;
    try std.testing.expectEqual(@as(u8, 'm'), csi.final);
    try std.testing.expectEqual(@as(usize, 3), csi.parameter_count);
    try std.testing.expectEqual(@as(u16, 1), csi.valueOr(0, 0));
    try std.testing.expect(!csi.parameter(1).isPresent(0));
    try std.testing.expectEqual(@as(u16, 38), csi.parameter(2).valueOr(0, 0));
    try std.testing.expectEqual(@as(u16, 2), csi.parameter(2).valueOr(1, 0));
    try std.testing.expect(!csi.parameter(2).isPresent(2));
    try std.testing.expectEqual(@as(u16, 30), csi.parameter(2).valueOr(5, 0));
}

test "VT parser bounds parameters and recovers after ignored CSI" {
    var parser = Parser{};
    _ = parser.feed(0x1b);
    _ = parser.feed('[');
    for (0..max_parameters + 4) |_| {
        _ = parser.feed('1');
        _ = parser.feed(';');
    }
    try std.testing.expectEqual(State.csi_ignore, parser.state);
    _ = parser.feed('m');
    try std.testing.expect(parser.isGround());
    try std.testing.expectEqual(Event{ .print = 'x' }, parser.feed('x'));
}

test "VT parser bounds strings and terminates OSC and DCS" {
    var parser = Parser{};
    _ = parser.feed(0x1b);
    _ = parser.feed(']');
    for (0..max_string_bytes + 17) |_| _ = parser.feed('x');
    const osc = parser.feed(0x07).string;
    try std.testing.expectEqual(StringKind.osc, osc.kind);
    try std.testing.expectEqual(max_string_bytes, osc.length);
    try std.testing.expect(osc.overflow);

    _ = parser.feed(0x1b);
    _ = parser.feed('P');
    _ = parser.feed('+');
    _ = parser.feed('q');
    _ = parser.feed('A');
    _ = parser.feed(0x1b);
    const dcs = parser.feed('\\').string;
    try std.testing.expectEqual(StringKind.dcs, dcs.kind);
    try std.testing.expectEqualStrings("A", parser.stringSlice());
    try std.testing.expect(parser.dcsHeader().hasIntermediate('+'));
    try std.testing.expectEqual(@as(u8, 'q'), parser.dcsHeader().final);
}

test "VT parser executes controls inside CSI and cancels safely" {
    var parser = Parser{};
    _ = parser.feed(0x1b);
    _ = parser.feed('[');
    try std.testing.expectEqual(Event{ .execute = 0x07 }, parser.feed(0x07));
    _ = parser.feed('1');
    _ = parser.feed(0x18);
    try std.testing.expect(parser.isGround());
}
