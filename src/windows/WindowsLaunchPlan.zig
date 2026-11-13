//! Bounded, allocation-free Windows command and environment construction.
const std = @import("std");
const builtin = @import("builtin");
const Launch = @import("deetty_share").launch_profile;
const Profiles = @import("WindowsLaunchProfiles.zig");

pub const command_capacity = 2048;
pub const path_capacity = 4097;
pub const environment_capacity = 32768;
pub const max_environment_entries = 4096;

pub const Plan = struct {
    application: [path_capacity]u16 = undefined,
    application_len: usize = 0,
    command: [command_capacity]u16 = undefined,
    command_len: usize = 0,
    directory: [path_capacity]u16 = undefined,
    directory_len: usize = 0,
    environment: [environment_capacity]u16 = undefined,
    environment_len: usize = 0,

    pub fn custom(self: *Plan, profile: *const Launch.Profile) !void {
        try Profiles.validateProfile(profile);
        var executable: [257]u16 = undefined;
        var arguments: [1025]u16 = undefined;
        const exe_len = try utf16(&executable, profile.shell.slice());
        const args_len = try utf16(&arguments, profile.command.slice());
        try self.setCommand(executable[0..exe_len], arguments[0..args_len]);
        self.directory_len = try utf16(&self.directory, profile.working_directory.slice());
    }

    /// argv0 is always quoted; arguments are already Windows command-line text.
    pub fn setCommand(self: *Plan, executable: []const u16, arguments: []const u16) !void {
        if (executable.len == 0 or executable.len >= self.application.len or
            std.mem.indexOfScalar(u16, executable, '"') != null or
            std.mem.indexOfScalar(u16, executable, 0) != null or
            std.mem.indexOfScalar(u16, arguments, 0) != null)
            return error.InvalidWindowsCommand;
        // An executable cannot end in a directory separator. Rejecting this also
        // avoids the trailing-backslash ambiguity in quoted argv0 parsers.
        if (executable[executable.len - 1] == '\\' or executable[executable.len - 1] == '/')
            return error.InvalidWindowsCommand;
        const length = executable.len + 2 + (if (arguments.len == 0) @as(usize, 0) else arguments.len + 1);
        if (length >= self.command.len) return error.WindowsCommandTooLong;
        @memcpy(self.application[0..executable.len], executable);
        self.application[executable.len] = 0;
        self.application_len = executable.len;
        self.command[0] = '"';
        @memcpy(self.command[1..][0..executable.len], executable);
        self.command[1 + executable.len] = '"';
        if (arguments.len != 0) {
            self.command[2 + executable.len] = ' ';
            @memcpy(self.command[3 + executable.len ..][0..arguments.len], arguments);
        }
        self.command[length] = 0;
        self.command_len = length;
    }

    /// Operator commands accept one quoted or unquoted executable token. No
    /// shell expansion or interpretation is introduced; the remaining text is raw.
    pub fn operator(self: *Plan, value: []const u16) !void {
        if (value.len == 0 or value.len >= command_capacity) return error.InvalidWindowsCommand;
        const quoted = value[0] == '"';
        const start: usize = if (quoted) 1 else 0;
        var end = start;
        while (end < value.len and (if (quoted) value[end] != '"' else value[end] != ' ' and value[end] != '\t')) : (end += 1) {}
        if (quoted and end == value.len) return error.InvalidWindowsCommand;
        var args = end + @as(usize, if (quoted) 1 else 0);
        if (args < value.len and value[args] != ' ' and value[args] != '\t') return error.InvalidWindowsCommand;
        while (args < value.len and (value[args] == ' ' or value[args] == '\t')) : (args += 1) {}
        try self.setCommand(value[start..end], value[args..]);
    }

    pub fn setEnvironment(self: *Plan, inherited: []const u16, overrides: []const u8) !void {
        self.environment_len = try mergeEnvironment(&self.environment, inherited, overrides);
    }
};

pub fn utf16(output: []u16, value: []const u8) !usize {
    if (!std.unicode.utf8ValidateSlice(value) or std.mem.indexOfScalar(u8, value, 0) != null)
        return error.InvalidWindowsText;
    const required = try std.unicode.calcUtf16LeLen(value);
    if (required >= output.len) return error.WindowsTextTooLong;
    const length = try std.unicode.utf8ToUtf16Le(output[0..required], value);
    output[length] = 0;
    return length;
}

fn name(entry: []const u16) ![]const u16 {
    if (entry.len == 0) return error.InvalidWindowsEnvironment;
    const start: usize = if (entry[0] == '=') 1 else 0;
    const equals = std.mem.indexOfScalarPos(u16, entry, start, '=') orelse return error.InvalidWindowsEnvironment;
    if (equals == start) return error.InvalidWindowsEnvironment;
    return entry[0..equals];
}

fn upcase(value: u16) u16 {
    return if (builtin.os.tag == .windows)
        std.os.windows.ntdll.RtlUpcaseUnicodeChar(value)
    else
        std.os.windows.nls.upcaseW(value);
}

fn compareNames(a: []const u16, b: []const u16) std.math.Order {
    for (a[0..@min(a.len, b.len)], b[0..@min(a.len, b.len)]) |left, right| {
        const order = std.math.order(upcase(left), upcase(right));
        if (order != .eq) return order;
    }
    return std.math.order(a.len, b.len);
}

fn put(entries: [][]const u16, count: *usize, entry: []const u16) !void {
    const key = try name(entry);
    for (entries[0..count.*]) |*prior| {
        if (compareNames(try name(prior.*), key) == .eq) {
            prior.* = entry;
            return;
        }
    }
    if (count.* == entries.len) return error.WindowsEnvironmentTooLarge;
    entries[count.*] = entry;
    count.* += 1;
}

fn lessThan(_: void, a: []const u16, b: []const u16) bool {
    return compareNames(name(a) catch unreachable, name(b) catch unreachable) == .lt;
}

/// Inherited block -> terminal defaults -> explicit overrides. References are
/// sorted before a single copy into output. Hidden =C: drive entries survive.
pub fn mergeEnvironment(output: []u16, inherited: []const u16, overrides: []const u8) !usize {
    if (inherited.len < 2 or inherited.len > environment_capacity or
        inherited[inherited.len - 1] != 0 or inherited[inherited.len - 2] != 0)
        return error.InvalidWindowsEnvironment;
    var entries: [max_environment_entries][]const u16 = undefined;
    var count: usize = 0;
    var cursor: usize = 0;
    while (cursor + 1 < inherited.len and inherited[cursor] != 0) {
        const end = std.mem.indexOfScalarPos(u16, inherited, cursor, 0) orelse return error.InvalidWindowsEnvironment;
        try put(&entries, &count, inherited[cursor..end]);
        cursor = end + 1;
    }
    if (cursor != inherited.len - 1 and !(cursor == 0 and inherited.len == 2)) return error.InvalidWindowsEnvironment;
    try put(&entries, &count, std.unicode.utf8ToUtf16LeStringLiteral("TERM=xterm-256color"));
    try put(&entries, &count, std.unicode.utf8ToUtf16LeStringLiteral("COLORTERM=truecolor"));
    if (overrides.len > 2048) return error.WindowsEnvironmentTooLarge;
    var wide: [2049]u16 = undefined;
    const length = try utf16(&wide, overrides);
    var override_keys: [16][]const u16 = undefined;
    var override_count: usize = 0;
    var iterator = std.mem.splitScalar(u16, wide[0..length], ';');
    if (length != 0) while (iterator.next()) |entry| {
        if (override_count == override_keys.len) return error.WindowsEnvironmentTooLarge;
        const key = try name(entry);
        for (key, 0..) |unit, index| {
            if (unit > 127 or !(std.ascii.isAlphabetic(@intCast(unit)) or unit == '_' or (index != 0 and std.ascii.isDigit(@intCast(unit)))))
                return error.InvalidWindowsEnvironment;
        }
        for (entry) |unit| if (unit < 0x20 or unit == 0x7f) return error.InvalidWindowsEnvironment;
        for (override_keys[0..override_count]) |prior| {
            if (compareNames(prior, key) == .eq) return error.DuplicateWindowsEnvironmentKey;
        }
        override_keys[override_count] = key;
        override_count += 1;
        try put(&entries, &count, entry);
    };
    std.mem.sort([]const u16, entries[0..count], {}, lessThan);
    var used: usize = 0;
    for (entries[0..count]) |entry| {
        if (entry.len + 2 > output.len - used) return error.WindowsEnvironmentTooLarge;
        @memcpy(output[used..][0..entry.len], entry);
        used += entry.len;
        output[used] = 0;
        used += 1;
    }
    if (used >= output.len or used >= environment_capacity) return error.WindowsEnvironmentTooLarge;
    output[used] = 0;
    return used + 1;
}

test "Windows launch plan: quoted Unicode executable preserves raw arguments" {
    var plan: Plan = .{};
    const exe = std.unicode.utf8ToUtf16LeStringLiteral("C:\\Program Files\\工具\\shell.exe");
    const args = std.unicode.utf8ToUtf16LeStringLiteral("--path \"C:\\資料\\\" & echo untouched");
    try plan.setCommand(exe, args);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("\"C:\\Program Files\\工具\\shell.exe\" --path \"C:\\資料\\\" & echo untouched"), plan.command[0..plan.command_len]);
    try std.testing.expectEqualSlices(u16, exe, plan.application[0..plan.application_len]);
    const cwd = "\\\\server\\share\\資料 with spaces\\";
    plan.directory_len = try utf16(&plan.directory, cwd);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral(cwd), plan.directory[0..plan.directory_len]);
    try std.testing.expectError(error.InvalidWindowsCommand, plan.setCommand(std.unicode.utf8ToUtf16LeStringLiteral("C:\\bad\"name.exe"), &.{}));
    try std.testing.expectError(error.InvalidWindowsCommand, plan.setCommand(std.unicode.utf8ToUtf16LeStringLiteral("C:\\directory\\"), &.{}));
    const oversized: [command_capacity]u16 = @splat('x');
    try std.testing.expectError(error.WindowsCommandTooLong, plan.setCommand(exe, &oversized));
    try std.testing.expectError(error.InvalidWindowsText, utf16(&plan.directory, "\xff"));
}

test "Windows launch plan: operator parsing preserves arguments without shell adaptation" {
    var plan: Plan = .{};
    try plan.operator(std.unicode.utf8ToUtf16LeStringLiteral("\"C:\\Program Files\\tool.exe\" /raw \"a\\\\b\""));
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("\"C:\\Program Files\\tool.exe\" /raw \"a\\\\b\""), plan.command[0..plan.command_len]);
    try std.testing.expectError(error.InvalidWindowsCommand, plan.operator(std.unicode.utf8ToUtf16LeStringLiteral("\"missing.exe")));
}

test "Windows launch plan: environment precedence hidden entries Unicode casefold and ordering" {
    var output: [environment_capacity]u16 = undefined;
    const inherited = std.unicode.utf8ToUtf16LeStringLiteral("z=last\x00=C:=C:\\資料\x00Path=old\x00TERM=old\x00ä=first\x00Ä=second\x00\x00");
    const length = try mergeEnvironment(&output, inherited, "PATH=new;term=custom;EMPTY=");
    const expected = std.unicode.utf8ToUtf16LeStringLiteral("=C:=C:\\資料\x00COLORTERM=truecolor\x00EMPTY=\x00PATH=new\x00term=custom\x00z=last\x00Ä=second\x00\x00");
    try std.testing.expectEqualSlices(u16, expected, output[0..length]);
    try std.testing.expectError(error.DuplicateWindowsEnvironmentKey, mergeEnvironment(&output, inherited, "Path=a;PATH=b"));
    try std.testing.expectError(error.InvalidWindowsEnvironment, mergeEnvironment(&output, inherited, "=C:=bad"));
    try std.testing.expectError(error.InvalidWindowsEnvironment, mergeEnvironment(&output, &.{ 0, 0, 0 }, ""));
    var small: [4]u16 = undefined;
    try std.testing.expectError(error.WindowsEnvironmentTooLarge, mergeEnvironment(&small, &.{ 0, 0 }, ""));
    try std.testing.expectError(error.WindowsEnvironmentTooLarge, mergeEnvironment(&output, &.{ 0, 0 }, "A=1;B=1;C=1;D=1;E=1;F=1;G=1;H=1;I=1;J=1;K=1;L=1;M=1;N=1;O=1;P=1;Q=1"));
}

test "Windows launch plan: custom profile validates before bounded field slices" {
    var profile: Launch.Profile = .{};
    try profile.shell.set("C:\\Program Files\\工具\\shell.exe");
    try profile.command.set("--literal \"資料\\\\\" & untouched");
    try profile.working_directory.set("\\\\server\\share\\資料 with spaces\\");
    profile.kind = .command;
    var plan: Plan = .{};
    try plan.custom(&profile);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("\"C:\\Program Files\\工具\\shell.exe\" --literal \"資料\\\\\" & untouched"), plan.command[0..plan.command_len]);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("\\\\server\\share\\資料 with spaces\\"), plan.directory[0..plan.directory_len]);
    profile.kind = .ssh;
    try std.testing.expectError(error.InvalidSshTarget, plan.custom(&profile));
    profile.kind = .command;
    profile.command.len = Launch.max_command_bytes + 1;
    try std.testing.expectError(error.LaunchProfileFieldTooLong, plan.custom(&profile));
}
