//! Bounded Windows launch profiles; every mutation commits the complete envelope first.
const std = @import("std");
const Launch = @import("noctty_share").launch_profile;

pub const max_state_bytes: usize = 65_536;
pub const builtin_count: usize = 2;
const builtin_names = [_][]const u8{ "PowerShell", "Command Prompt" };
const magic = "NWLP";
const version: u8 = 1;
const fields = .{ "shell", "command", "working_directory", "environment", "ssh_target" };

pub fn validateProfile(profile: *const Launch.Profile) !void {
    try profile.validateFor(.windows);
    if (profile.kind != .shell and profile.kind != .command) return error.UnsupportedWindowsLaunchKind;
    if (profile.shell.len == 0) return error.InvalidLaunchShell;
    if (profile.ssh_target.len != 0) return error.InvalidSshTarget;
    if ((profile.command.len == 0) != (profile.kind == .shell)) return error.InvalidLaunchCommand;
}

pub const Library = struct {
    custom: Launch.LibraryFor(.windows) = .{},
    selected: usize = 0,

    pub fn init(legacy: c_int) Library {
        return .{ .selected = if (legacy == 1) 1 else 0 };
    }

    pub fn count(self: *const Library) usize {
        return builtin_count + self.custom.count;
    }

    pub fn name(self: *const Library, index: usize) ?[]const u8 {
        if (index < builtin_count) return builtin_names[index];
        return (self.get(index) orelse return null).name.slice();
    }

    pub fn get(self: *const Library, index: usize) ?*const Launch.NamedProfile {
        if (index < builtin_count or index >= self.count()) return null;
        return &self.custom.entries[index - builtin_count];
    }

    pub fn validate(self: *const Library) !void {
        try self.custom.validate();
        if (self.selected >= self.count()) return error.InvalidLaunchProfileSelection;
        const expected = if (self.selected < builtin_count) Launch.no_selection else self.selected - builtin_count;
        if (self.custom.selected_index != expected) return error.InvalidLaunchProfileSelection;
        for (self.custom.entries[0..self.custom.count]) |*entry| {
            try validateProfile(&entry.profile);
            for (builtin_names) |builtin_name| {
                if (std.ascii.eqlIgnoreCase(entry.name.slice(), builtin_name)) return error.DuplicateLaunchProfileName;
            }
        }
    }

    /// Null creates; an existing global index edits/renames. Names never imply replacement.
    pub fn save(self: *Library, index: ?usize, name_value: []const u8, profile: Launch.Profile, sink: anytype) !usize {
        try validateProfile(&profile);
        var candidate = self.*;
        const slot = if (index) |global| blk: {
            if (self.get(global) == null) return error.LaunchProfileNotFound;
            break :blk global - builtin_count;
        } else blk: {
            if (candidate.custom.count == Launch.max_named_profiles) return error.TooManyLaunchProfiles;
            const new_slot: usize = candidate.custom.count;
            candidate.custom.count += 1;
            break :blk new_slot;
        };
        try candidate.custom.entries[slot].name.set(name_value);
        candidate.custom.entries[slot].profile = profile;
        candidate.custom.selected_index = @intCast(slot);
        candidate.selected = slot + builtin_count;
        try self.commit(&candidate, sink);
        return candidate.selected;
    }

    pub fn select(self: *Library, index: usize, sink: anytype) !void {
        if (index >= self.count()) return error.LaunchProfileNotFound;
        var candidate = self.*;
        candidate.selected = index;
        candidate.custom.selected_index = if (index < builtin_count) Launch.no_selection else @intCast(index - builtin_count);
        try self.commit(&candidate, sink);
    }

    pub fn remove(self: *Library, index: usize, sink: anytype) !void {
        if (self.get(index) == null) return error.LaunchProfileNotFound;
        var candidate = self.*;
        try candidate.custom.remove(index - builtin_count);
        if (candidate.selected == index) {
            candidate.selected = 0;
        } else if (candidate.selected > index) {
            candidate.selected -= 1;
        }
        try self.commit(&candidate, sink);
    }

    fn commit(self: *Library, candidate: *const Library, sink: anytype) !void {
        var bytes: [max_state_bytes]u8 = undefined;
        const length = try candidate.encodeState(&bytes);
        try sink.save(bytes[0..length]);
        self.* = candidate.*;
    }

    pub fn encodeState(self: *const Library, output: []u8) !usize {
        try self.validate();
        var writer = Writer{ .bytes = output[0..@min(output.len, max_state_bytes)] };
        try writer.put(magic);
        try writer.byte(version);
        try writer.byte(@intCast(self.selected));
        try writer.byte(self.custom.count);
        for (self.custom.entries[0..self.custom.count]) |*entry| {
            try writer.text(entry.name.slice());
            try writer.byte(@intFromEnum(entry.profile.kind));
            var number: [4]u8 = undefined;
            std.mem.writeInt(u32, &number, entry.profile.scrollback_lines, .little);
            try writer.put(&number);
            inline for (fields) |field| try writer.text(@field(entry.profile, field).slice());
        }
        return writer.position;
    }
};

const Writer = struct {
    bytes: []u8,
    position: usize = 0,
    fn put(self: *Writer, bytes: []const u8) !void {
        if (bytes.len > self.bytes.len - self.position) return error.WindowsLaunchStateTooLarge;
        @memcpy(self.bytes[self.position..][0..bytes.len], bytes);
        self.position += bytes.len;
    }
    fn byte(self: *Writer, value: u8) !void {
        try self.put(&.{value});
    }
    fn text(self: *Writer, value: []const u8) !void {
        var length: [2]u8 = undefined;
        std.mem.writeInt(u16, &length, @intCast(value.len), .little);
        try self.put(&length);
        try self.put(value);
    }
};

const Reader = struct {
    bytes: []const u8,
    position: usize = 0,
    fn take(self: *Reader, length: usize) ![]const u8 {
        if (length > self.bytes.len - self.position) return error.InvalidWindowsLaunchState;
        const value = self.bytes[self.position..][0..length];
        self.position += length;
        return value;
    }
    fn byte(self: *Reader) !u8 {
        return (try self.take(1))[0];
    }
    fn text(self: *Reader, target: anytype) !void {
        const length = std.mem.readInt(u16, (try self.take(2))[0..2], .little);
        if (length > target.bytes.len) return error.LaunchProfileFieldTooLong;
        try target.set(try self.take(length));
    }
};

pub fn decodeState(bytes: []const u8) !Library {
    if (bytes.len > max_state_bytes) return error.WindowsLaunchStateTooLarge;
    var reader = Reader{ .bytes = bytes };
    if (!std.mem.eql(u8, try reader.take(magic.len), magic)) return error.InvalidWindowsLaunchState;
    if (try reader.byte() != version) return error.UnsupportedWindowsLaunchState;
    var library = Library.init(0);
    library.selected = try reader.byte();
    library.custom.count = try reader.byte();
    if (library.custom.count > Launch.max_named_profiles) return error.TooManyLaunchProfiles;
    library.custom.selected_index = if (library.selected < builtin_count) Launch.no_selection else @intCast(library.selected - builtin_count);
    for (library.custom.entries[0..library.custom.count]) |*entry| {
        try reader.text(&entry.name);
        entry.profile.kind = std.enums.fromInt(Launch.Kind, try reader.byte()) orelse return error.UnsupportedWindowsLaunchKind;
        entry.profile.scrollback_lines = std.mem.readInt(u32, (try reader.take(4))[0..4], .little);
        inline for (fields) |field| try reader.text(&@field(entry.profile, field));
    }
    if (reader.position != bytes.len) return error.InvalidWindowsLaunchState;
    try library.validate();
    return library;
}

const MemorySink = struct {
    bytes: [max_state_bytes]u8 = undefined,
    length: usize = 0,
    fail: bool = false,
    fn save(self: *MemorySink, bytes: []const u8) !void {
        if (self.fail) return error.DiskFull;
        @memcpy(self.bytes[0..bytes.len], bytes);
        self.length = bytes.len;
    }
};

fn testProfile() !Launch.Profile {
    var profile: Launch.Profile = .{ .kind = .command, .scrollback_lines = 321 };
    try profile.shell.set("C:\\Program Files\\Example\\tool.exe");
    try profile.command.set("--title \"日本語\"");
    try profile.working_directory.set("\\\\server\\share\\workspace");
    try profile.environment.set("TERM=profile;EMPTY=;Path=C:\\tools");
    return profile;
}

test "Windows launch profiles: durable CRUD selection and failed-write rollback" {
    var library = Library.init(1);
    var sink: MemorySink = .{};
    const profile = try testProfile();
    _ = try library.save(null, "First", profile, &sink);
    _ = try library.save(null, "Second", profile, &sink);
    var saved: [max_state_bytes]u8 = undefined;
    const length = sink.length;
    @memcpy(saved[0..length], sink.bytes[0..length]);
    sink.fail = true;
    try std.testing.expectError(error.DiskFull, library.save(3, "Renamed", profile, &sink));
    try std.testing.expectError(error.DiskFull, library.save(null, "Third", profile, &sink));
    try std.testing.expectError(error.DiskFull, library.select(0, &sink));
    try std.testing.expectError(error.DiskFull, library.remove(3, &sink));
    try std.testing.expectEqualStrings("Second", library.name(library.selected).?);
    try std.testing.expectEqual(@as(usize, 4), library.count());
    try std.testing.expectEqualSlices(u8, saved[0..length], sink.bytes[0..sink.length]);
    sink.fail = false;
    try std.testing.expectError(error.DuplicateLaunchProfileName, library.save(3, "FIRST", profile, &sink));
    try std.testing.expectError(error.DuplicateLaunchProfileName, library.save(null, "first", profile, &sink));
    try std.testing.expectError(error.DuplicateLaunchProfileName, library.save(3, "PowerShell", profile, &sink));
    try std.testing.expectError(error.LaunchProfileNotFound, library.remove(0, &sink));
    try std.testing.expectError(error.LaunchProfileNotFound, library.save(1, "Builtin", profile, &sink));
    _ = try library.save(3, "Renamed", profile, &sink);
    try library.remove(2, &sink);
    var loaded = try decodeState(sink.bytes[0..sink.length]);
    try std.testing.expectEqual(@as(usize, 2), loaded.selected);
    try std.testing.expectEqualStrings("Renamed", loaded.name(2).?);
    try std.testing.expect(loaded.get(2).?.profile.eql(&profile));
    try loaded.remove(2, &sink);
    loaded = try decodeState(sink.bytes[0..sink.length]);
    try std.testing.expectEqual(@as(usize, 0), loaded.selected);
    try std.testing.expectEqual(@as(usize, 2), loaded.count());
    try loaded.select(1, &sink);
    loaded = try decodeState(sink.bytes[0..sink.length]);
    try std.testing.expectEqual(@as(usize, 1), loaded.selected);
}

test "Windows launch profiles: exact library capacity and malformed envelope boundaries" {
    var library = Library.init(0);
    var sink: MemorySink = .{};
    const profile = try testProfile();
    for (0..Launch.max_named_profiles) |index| {
        var name: [64]u8 = undefined;
        @memset(&name, 'a' + @as(u8, @intCast(index)));
        _ = try library.save(null, &name, profile, &sink);
    }
    try std.testing.expectError(error.TooManyLaunchProfiles, library.save(null, "Overflow", profile, &sink));
    const loaded = try decodeState(sink.bytes[0..sink.length]);
    try std.testing.expectEqual(@as(usize, 10), loaded.count());
    try std.testing.expectEqual(@as(usize, 9), loaded.selected);
    for (0..sink.length) |length| {
        if (decodeState(sink.bytes[0..length])) |_| return error.AcceptedTruncation else |_| {}
    }
    sink.bytes[sink.length] = 0;
    try std.testing.expectError(error.InvalidWindowsLaunchState, decodeState(sink.bytes[0 .. sink.length + 1]));
    sink.bytes[7] = 0xff;
    sink.bytes[8] = 0xff;
    try std.testing.expectError(error.LaunchProfileFieldTooLong, decodeState(sink.bytes[0..sink.length]));
    sink.length = try library.encodeState(&sink.bytes);
    sink.bytes[9] = 0xff;
    try std.testing.expectError(error.InvalidLaunchProfileName, decodeState(sink.bytes[0..sink.length]));
    sink.length = try library.encodeState(&sink.bytes);
    // First executable starts after header, name prefix/value, kind, history and text prefix.
    sink.bytes[7 + 2 + 64 + 1 + 4 + 2] = 0xff;
    try std.testing.expectError(error.InvalidLaunchProfileUtf8, decodeState(sink.bytes[0..sink.length]));
    sink.length = try library.encodeState(&sink.bytes);
    sink.bytes[5] = 99;
    try std.testing.expectError(error.InvalidLaunchProfileSelection, decodeState(sink.bytes[0..sink.length]));
    sink.length = try library.encodeState(&sink.bytes);
    sink.bytes[6] = 9;
    try std.testing.expectError(error.TooManyLaunchProfiles, decodeState(sink.bytes[0..sink.length]));
}

test "Windows launch profiles: unsupported modes and oversized decoded fields fail before slicing" {
    var profile = try testProfile();
    profile.shell.len = Launch.max_shell_bytes + 1;
    try std.testing.expectError(error.LaunchProfileFieldTooLong, validateProfile(&profile));
    profile = try testProfile();
    profile.kind = .ssh;
    try profile.ssh_target.set("user@example.com");
    try std.testing.expectError(error.UnsupportedWindowsLaunchKind, validateProfile(&profile));
    profile = try testProfile();
    profile.kind = .shell;
    try std.testing.expectError(error.InvalidLaunchCommand, validateProfile(&profile));
    profile = try testProfile();
    try profile.shell.set("");
    try std.testing.expectError(error.InvalidLaunchShell, validateProfile(&profile));
}

test "Windows launch profiles: maximum field sizes roundtrip without truncation" {
    var profile: Launch.Profile = .{ .kind = .command, .scrollback_lines = Launch.max_scrollback_lines };
    inline for (.{ "shell", "command", "working_directory", "environment" }) |field| {
        const text = &@field(profile, field);
        @memset(&text.bytes, 'a');
        text.len = @intCast(text.bytes.len);
    }
    @memcpy(profile.shell.bytes[0..3], "C:\\");
    @memcpy(profile.working_directory.bytes[0..3], "D:\\");
    @memcpy(profile.environment.bytes[0..2], "A=");
    var library = Library.init(0);
    var sink: MemorySink = .{};
    var name: [Launch.max_name_bytes]u8 = undefined;
    @memset(&name, 'n');
    _ = try library.save(null, &name, profile, &sink);
    const loaded = try decodeState(sink.bytes[0..sink.length]);
    try std.testing.expect(loaded.get(2).?.profile.eql(&profile));
    try std.testing.expectEqualSlices(u8, &name, loaded.get(2).?.name.slice());
    profile.scrollback_lines += 1;
    try std.testing.expectError(error.InvalidLaunchScrollbackLines, library.save(2, &name, profile, &sink));
}
