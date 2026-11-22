const std = @import("std");

pub fn quoteCommandArguments(args: anytype, output: *[max_command_bytes]u8) ![]const u8 {
    if (args.len == 0) return error.InvalidExecuteArguments;
    var length: usize = 0;
    for (args, 0..) |arg, index| {
        if (index == 0 and arg.len == 0) return error.InvalidExecuteArguments;
        if (index != 0) try appendCommandBytes(output, &length, " ");
        try appendCommandBytes(output, &length, "'");
        for (arg) |byte| {
            if (byte < 0x20 or byte == 0x7f) return error.InvalidExecuteArgument;
            if (byte == '\'') {
                try appendCommandBytes(output, &length, "'\\''");
            } else {
                try appendCommandByte(output, &length, byte);
            }
        }
        try appendCommandBytes(output, &length, "'");
    }
    return output[0..length];
}

fn appendCommandBytes(
    output: *[max_command_bytes]u8,
    length: *usize,
    bytes: []const u8,
) !void {
    if (bytes.len > max_command_bytes - length.*) return error.ExecuteArgumentsTooLong;
    @memcpy(output[length.* .. length.* + bytes.len], bytes);
    length.* += bytes.len;
}

fn appendCommandByte(
    output: *[max_command_bytes]u8,
    length: *usize,
    byte: u8,
) !void {
    if (length.* == max_command_bytes) return error.ExecuteArgumentsTooLong;
    output[length.*] = byte;
    length.* += 1;
}
const builtin = @import("builtin");

pub const PathStyle = enum { posix, windows };
pub const native_path_style: PathStyle = if (builtin.os.tag == .windows) .windows else .posix;

pub const max_shell_bytes: usize = 256;
pub const max_command_bytes: usize = 1024;
pub const max_working_directory_bytes: usize = 4096;
pub const max_environment_bytes: usize = 2048;
pub const max_ssh_target_bytes: usize = 256;
pub const max_environment_entries: usize = 16;
pub const default_scrollback_lines: u32 = 10_000;
pub const max_scrollback_lines: u32 = 100_000;
pub const max_name_bytes: usize = 64;
pub const max_named_profiles: usize = 8;
pub const no_selection: u8 = std.math.maxInt(u8);

pub const Kind = enum(u8) {
    shell = 0,
    command = 1,
    ssh = 2,
    tmux = 3,
    zellij = 4,
};

pub fn BoundedText(comptime capacity: usize) type {
    return struct {
        const Self = @This();

        bytes: [capacity]u8 = @splat(0),
        len: u16 = 0,

        pub fn set(self: *Self, value: []const u8) !void {
            if (value.len > capacity or value.len > std.math.maxInt(u16)) return error.LaunchProfileFieldTooLong;
            @memcpy(self.bytes[0..value.len], value);
            if (value.len < capacity) @memset(self.bytes[value.len..], 0);
            self.len = @intCast(value.len);
        }

        pub fn validateLength(self: *const Self) !void {
            if (self.len > capacity) return error.LaunchProfileFieldTooLong;
        }

        pub fn slice(self: *const Self) []const u8 {
            return self.bytes[0..self.len];
        }
    };
}

pub const Profile = struct {
    kind: Kind = .shell,
    shell: BoundedText(max_shell_bytes) = .{},
    command: BoundedText(max_command_bytes) = .{},
    working_directory: BoundedText(max_working_directory_bytes) = .{},
    environment: BoundedText(max_environment_bytes) = .{},
    ssh_target: BoundedText(max_ssh_target_bytes) = .{},
    scrollback_lines: u32 = default_scrollback_lines,

    pub fn normalizeScrollback(self: *Profile) void {
        if (self.scrollback_lines == 0)
            self.scrollback_lines = default_scrollback_lines;
    }

    pub fn effectiveScrollbackLines(self: *const Profile) u32 {
        return if (self.scrollback_lines == 0)
            default_scrollback_lines
        else
            self.scrollback_lines;
    }

    pub fn validate(self: *const Profile) !void {
        return self.validateFor(native_path_style);
    }

    pub fn validateFor(self: *const Profile, comptime style: PathStyle) !void {
        inline for (.{ "shell", "command", "working_directory", "environment", "ssh_target" }) |field| {
            try @field(self, field).validateLength();
            if (style == .windows and !std.unicode.utf8ValidateSlice(@field(self, field).slice()))
                return error.InvalidLaunchProfileUtf8;
        }
        try validateOptionalAbsolutePath(style, self.shell.slice(), error.InvalidLaunchShell);
        try validateSingleLine(self.command.slice(), error.InvalidLaunchCommand);
        try validateOptionalAbsolutePath(style, self.working_directory.slice(), error.InvalidLaunchWorkingDirectory);
        try validateEnvironmentFor(style, self.environment.slice());
        if (self.scrollback_lines == 0 or
            self.scrollback_lines > max_scrollback_lines)
            return error.InvalidLaunchScrollbackLines;

        switch (self.kind) {
            .shell => try validateSshTarget(self.ssh_target.slice()),
            .command => {
                try validateSshTarget(self.ssh_target.slice());
                if (self.command.slice().len == 0) return error.InvalidLaunchCommand;
            },
            .ssh => {
                try validateSshTarget(self.ssh_target.slice());
                if (self.ssh_target.slice().len == 0) return error.InvalidSshTarget;
            },
            .tmux, .zellij => try validateSessionName(self.ssh_target.slice()),
        }
    }

    pub fn shellPath(self: *const Profile, fallback_shell: []const u8) []const u8 {
        return if (self.shell.slice().len == 0)
            safeFallbackShell(fallback_shell)
        else
            self.shell.slice();
    }

    pub fn workingDirectory(self: *const Profile, pane_cwd: []const u8) []const u8 {
        return if (self.working_directory.slice().len == 0) pane_cwd else self.working_directory.slice();
    }

    pub fn forInitialLaunch(
        self: Profile,
        explicit_working_directory: ?[]const u8,
    ) Profile {
        var profile = self;
        if (explicit_working_directory != null) profile.working_directory = .{};
        return profile;
    }

    pub fn argument(self: *const Profile) []const u8 {
        return switch (self.kind) {
            .shell => "",
            .command => self.command.slice(),
            .ssh, .tmux, .zellij => self.ssh_target.slice(),
        };
    }

    pub fn environmentEntryCount(self: *const Profile) usize {
        if (self.environment.slice().len == 0) return 0;
        var count: usize = 0;
        var iterator = std.mem.splitScalar(u8, self.environment.slice(), ';');
        while (iterator.next()) |_| count += 1;
        return count;
    }

    pub fn eql(self: *const Profile, other: *const Profile) bool {
        return self.kind == other.kind and
            std.mem.eql(u8, self.shell.slice(), other.shell.slice()) and
            std.mem.eql(u8, self.command.slice(), other.command.slice()) and
            std.mem.eql(u8, self.working_directory.slice(), other.working_directory.slice()) and
            std.mem.eql(u8, self.environment.slice(), other.environment.slice()) and
            std.mem.eql(u8, self.ssh_target.slice(), other.ssh_target.slice()) and
            self.scrollback_lines == other.scrollback_lines;
    }
};

pub fn safeFallbackShell(shell: []const u8) []const u8 {
    return if (std.fs.path.isAbsolute(shell)) shell else "/bin/sh";
}

pub const NamedProfile = struct {
    name: BoundedText(max_name_bytes) = .{},
    profile: Profile = .{},

    pub fn validate(self: *const NamedProfile) !void {
        return self.validateFor(native_path_style);
    }

    pub fn validateFor(self: *const NamedProfile, comptime style: PathStyle) !void {
        try self.name.validateLength();
        try validateName(self.name.slice());
        try self.profile.validateFor(style);
    }
};

pub const Library = LibraryFor(native_path_style);

pub fn LibraryFor(comptime style: PathStyle) type {
    return struct {
        const Self = @This();
        entries: [max_named_profiles]NamedProfile = @splat(.{}),
        count: u8 = 0,
        selected_index: u8 = no_selection,

        pub fn validate(self: *const Self) !void {
            if (self.count > max_named_profiles) return error.TooManyLaunchProfiles;
            if (self.selected_index != no_selection and self.selected_index >= self.count)
                return error.InvalidLaunchProfileSelection;

            for (self.entries[0..self.count], 0..) |*entry, index| {
                try entry.validateFor(style);
                for (self.entries[0..index]) |*prior| {
                    if (std.ascii.eqlIgnoreCase(prior.name.slice(), entry.name.slice()))
                        return error.DuplicateLaunchProfileName;
                }
            }
        }

        pub fn selected(self: *const Self) ?*const NamedProfile {
            if (self.selected_index == no_selection) return null;
            return &self.entries[self.selected_index];
        }

        pub fn find(self: *const Self, name: []const u8) ?usize {
            for (self.entries[0..self.count], 0..) |*entry, index| {
                if (std.ascii.eqlIgnoreCase(entry.name.slice(), name)) return index;
            }
            return null;
        }

        pub fn saveAndSelect(self: *Self, name: []const u8, profile: Profile) !usize {
            try validateName(name);
            try profile.validateFor(style);

            var next = self.*;
            const index = next.find(name) orelse add: {
                if (next.count == max_named_profiles) return error.TooManyLaunchProfiles;
                const new_index: usize = next.count;
                next.count += 1;
                break :add new_index;
            };
            try next.entries[index].name.set(name);
            next.entries[index].profile = profile;
            next.selected_index = @intCast(index);
            try next.validate();
            self.* = next;
            return index;
        }

        pub fn select(self: *Self, index: usize) !Profile {
            if (index >= self.count) return error.LaunchProfileNotFound;
            self.selected_index = @intCast(index);
            return self.entries[index].profile;
        }

        pub fn clearSelection(self: *Self) void {
            self.selected_index = no_selection;
        }

        pub fn remove(self: *Self, index: usize) !void {
            if (index >= self.count) return error.LaunchProfileNotFound;
            var next = self.*;
            const old_count: usize = next.count;
            var cursor = index;
            while (cursor + 1 < old_count) : (cursor += 1) {
                next.entries[cursor] = next.entries[cursor + 1];
            }
            next.entries[old_count - 1] = .{};
            next.count -= 1;
            if (next.selected_index == index) {
                next.selected_index = no_selection;
            } else if (next.selected_index != no_selection and next.selected_index > index) {
                next.selected_index -= 1;
            }
            try next.validate();
            self.* = next;
        }
    };
}

fn validateName(value: []const u8) !void {
    if (value.len == 0 or value.len > max_name_bytes) return error.InvalidLaunchProfileName;
    if (!std.unicode.utf8ValidateSlice(value)) return error.InvalidLaunchProfileName;
    if (!std.mem.eql(u8, value, std.mem.trim(u8, value, " \t\r\n")))
        return error.InvalidLaunchProfileName;
    try validateSingleLine(value, error.InvalidLaunchProfileName);
}

fn validateOptionalAbsolutePath(comptime style: PathStyle, value: []const u8, invalid: anyerror) !void {
    if (value.len == 0) return;
    try validateSingleLine(value, invalid);
    if (style == .posix) {
        if (!std.fs.path.isAbsolutePosix(value)) return invalid;
    } else {
        if (!std.fs.path.isAbsoluteWindows(value)) return invalid;
        // Root-relative and drive-relative paths depend on process state. Device
        // namespaces are not executable/cwd paths in the profile contract.
        if (value.len >= 3 and std.ascii.isAlphabetic(value[0]) and value[1] == ':' and
            (value[2] == '\\' or value[2] == '/')) return;
        if (value.len < 5 or !isWindowsSeparator(value[0]) or !isWindowsSeparator(value[1])) return invalid;
        var parts = std.mem.tokenizeAny(u8, value[2..], "\\/");
        const server = parts.next() orelse return invalid;
        const share = parts.next() orelse return invalid;
        if (std.mem.eql(u8, server, ".") or std.mem.eql(u8, server, "?") or
            std.mem.eql(u8, share, ".") or std.mem.eql(u8, share, "..")) return invalid;
    }
}

fn isWindowsSeparator(byte: u8) bool {
    return byte == '\\' or byte == '/';
}

fn validateSingleLine(value: []const u8, invalid: anyerror) !void {
    for (value) |byte| {
        if (byte < 0x20 or byte == 0x7f) return invalid;
    }
}

pub fn validateEnvironment(value: []const u8) !void {
    return validateEnvironmentFor(native_path_style, value);
}

pub fn validateEnvironmentFor(comptime style: PathStyle, value: []const u8) !void {
    if (style == .windows and !std.unicode.utf8ValidateSlice(value)) return error.InvalidLaunchEnvironment;
    if (value.len == 0) return;

    var keys: [max_environment_entries][]const u8 = undefined;
    var count: usize = 0;
    var iterator = std.mem.splitScalar(u8, value, ';');
    while (iterator.next()) |entry| {
        if (entry.len == 0 or count == max_environment_entries) return error.InvalidLaunchEnvironment;
        const equals = std.mem.indexOfScalar(u8, entry, '=') orelse return error.InvalidLaunchEnvironment;
        const key = entry[0..equals];
        const entry_value = entry[equals + 1 ..];
        if (key.len == 0 or !isEnvironmentKeyStart(key[0])) return error.InvalidLaunchEnvironment;
        for (key[1..]) |byte| {
            if (!isEnvironmentKeyContinue(byte)) return error.InvalidLaunchEnvironment;
        }
        try validateSingleLine(entry_value, error.InvalidLaunchEnvironment);
        if (std.mem.indexOfScalar(u8, entry_value, ';') != null) return error.InvalidLaunchEnvironment;
        for (keys[0..count]) |prior| {
            if (if (style == .windows) std.ascii.eqlIgnoreCase(prior, key) else std.mem.eql(u8, prior, key))
                return error.DuplicateLaunchEnvironmentKey;
        }
        keys[count] = key;
        count += 1;
    }
}

fn isEnvironmentKeyStart(byte: u8) bool {
    return std.ascii.isAlphabetic(byte) or byte == '_';
}

fn isEnvironmentKeyContinue(byte: u8) bool {
    return isEnvironmentKeyStart(byte) or std.ascii.isDigit(byte);
}

fn validateSshTarget(value: []const u8) !void {
    if (value.len == 0) return;
    if (value[0] == '-') return error.InvalidSshTarget;
    for (value) |byte| {
        if (!(std.ascii.isAlphanumeric(byte) or switch (byte) {
            '.', '_', '-', '@', ':', '[', ']' => true,
            else => false,
        })) return error.InvalidSshTarget;
    }
}

fn validateSessionName(value: []const u8) !void {
    if (value.len == 0 or value.len > max_name_bytes or value[0] == '-')
        return error.InvalidSessionName;
    for (value) |byte| {
        if (!(std.ascii.isAlphanumeric(byte) or switch (byte) {
            '.', '_', '-' => true,
            else => false,
        })) return error.InvalidSessionName;
    }
}

test "launch profiles validate shell command cwd environment and ssh modes" {
    var profile = Profile{};
    try profile.validateFor(.posix);
    if (native_path_style == .posix) {
        try std.testing.expectEqualStrings("/bin/fish", profile.shellPath("/bin/fish"));
        try std.testing.expectEqualStrings("/bin/sh", profile.shellPath("fish"));
    }
    try std.testing.expectEqualStrings("/workspace", profile.workingDirectory("/workspace"));

    profile.kind = .command;
    try std.testing.expectError(error.InvalidLaunchCommand, profile.validateFor(.posix));
    try profile.shell.set("/bin/sh");
    try profile.command.set("printf ready");
    try profile.working_directory.set("/tmp");
    try profile.environment.set("DEETTY_PROFILE=ready;TERM_PROGRAM=DEETTY");
    profile.scrollback_lines = 4096;
    try profile.validateFor(.posix);
    try std.testing.expectEqual(@as(usize, 2), profile.environmentEntryCount());
    try std.testing.expectEqualStrings("printf ready", profile.argument());

    profile.kind = .ssh;
    try profile.ssh_target.set("alice@example.com");
    try profile.validateFor(.posix);
    try std.testing.expectEqualStrings("alice@example.com", profile.argument());

    profile.kind = .tmux;
    try profile.ssh_target.set("deetty-work");
    try profile.validateFor(.posix);
    try std.testing.expectEqualStrings("deetty-work", profile.argument());

    profile.kind = .zellij;
    try profile.validateFor(.posix);
    try std.testing.expectEqualStrings("deetty-work", profile.argument());
}

test "explicit initial working directory overrides a configured profile cwd" {
    var configured = Profile{};
    try configured.working_directory.set("/profile-directory");

    const explicit = configured.forInitialLaunch("/open-here");
    try std.testing.expectEqualStrings(
        "/open-here",
        explicit.workingDirectory("/open-here"),
    );

    const inherited = configured.forInitialLaunch(null);
    try std.testing.expectEqualStrings(
        "/profile-directory",
        inherited.workingDirectory("/fallback"),
    );
}

test "launch profiles reject unsafe or ambiguous fields" {
    var profile = Profile{};
    try profile.shell.set("bin/sh");
    try std.testing.expectError(error.InvalidLaunchShell, profile.validate());

    profile = .{};
    try profile.working_directory.set("relative/path");
    try std.testing.expectError(error.InvalidLaunchWorkingDirectory, profile.validate());

    profile = .{};
    try profile.environment.set("GOOD=one;GOOD=two");
    try std.testing.expectError(error.DuplicateLaunchEnvironmentKey, profile.validate());

    profile = .{ .kind = .ssh };
    try profile.ssh_target.set("-oProxyCommand=bad");
    try std.testing.expectError(error.InvalidSshTarget, profile.validate());

    profile = .{ .kind = .tmux };
    try std.testing.expectError(error.InvalidSessionName, profile.validate());
    try profile.ssh_target.set("-unsafe");
    try std.testing.expectError(error.InvalidSessionName, profile.validate());
    try profile.ssh_target.set("unsafe/name");
    try std.testing.expectError(error.InvalidSessionName, profile.validate());

    profile = .{ .kind = .zellij };
    try profile.ssh_target.set("name with spaces");
    try std.testing.expectError(error.InvalidSessionName, profile.validate());
}

test "named launch profile library saves selects replaces and removes atomically" {
    var library = LibraryFor(.posix){};
    try library.validate();
    try std.testing.expect(library.selected() == null);

    var build = Profile{ .kind = .command };
    try build.command.set("zig build test");
    const build_index = try library.saveAndSelect("Local build", build);
    try std.testing.expectEqual(@as(usize, 0), build_index);
    try std.testing.expectEqual(@as(u8, 1), library.count);
    try std.testing.expect(library.selected().?.profile.eql(&build));

    var shell = Profile{};
    try shell.shell.set("/bin/sh");
    _ = try library.saveAndSelect("Safe shell", shell);
    try std.testing.expectEqual(@as(u8, 2), library.count);
    try std.testing.expectEqualStrings("Safe shell", library.selected().?.name.slice());

    const selected = try library.select(build_index);
    try std.testing.expect(selected.eql(&build));
    try std.testing.expectEqual(@as(u8, 0), library.selected_index);

    try build.command.set("zig build verify");
    try std.testing.expectEqual(build_index, try library.saveAndSelect("local BUILD", build));
    try std.testing.expectEqual(@as(u8, 2), library.count);
    try std.testing.expectEqualStrings("zig build verify", library.selected().?.profile.command.slice());

    try library.remove(1);
    try std.testing.expectEqual(@as(u8, 1), library.count);
    try std.testing.expectEqual(@as(u8, 0), library.selected_index);
    try std.testing.expectError(error.LaunchProfileNotFound, library.select(1));
}

test "named launch profile library rejects invalid names duplicates and overflow" {
    var library = Library{};
    try std.testing.expectError(error.InvalidLaunchProfileName, library.saveAndSelect(" bad ", .{}));
    try std.testing.expectError(error.InvalidLaunchProfileName, library.saveAndSelect("bad\xff", .{}));

    _ = try library.saveAndSelect("Build", .{});
    library.entries[1] = library.entries[0];
    try library.entries[1].name.set("build");
    library.count = 2;
    try std.testing.expectError(error.DuplicateLaunchProfileName, library.validate());

    library = .{};
    for (0..max_named_profiles) |index| {
        var name: [16]u8 = undefined;
        const value = try std.fmt.bufPrint(&name, "Profile {d}", .{index + 1});
        _ = try library.saveAndSelect(value, .{});
    }
    try std.testing.expectError(error.TooManyLaunchProfiles, library.saveAndSelect("Overflow", .{}));
}

test "launch profiles: Windows and POSIX paths and environment names remain distinct" {
    var profile: Profile = .{};
    for ([_][]const u8{ "C:\\tools\\shell.exe", "d:/tools/shell.exe", "\\\\server\\share\\shell.exe" }) |path| {
        try profile.shell.set(path);
        try profile.validateFor(.windows);
        try std.testing.expectError(error.InvalidLaunchShell, profile.validateFor(.posix));
    }
    for ([_][]const u8{ "C:shell.exe", "\\shell.exe", "/shell.exe", "\\\\server", "\\\\?\\C:\\shell.exe", "\\\\.\\pipe\\shell" }) |path| {
        try profile.shell.set(path);
        try std.testing.expectError(error.InvalidLaunchShell, profile.validateFor(.windows));
    }
    try profile.shell.set("/bin/sh");
    try profile.validateFor(.posix);
    try profile.shell.set("");
    try profile.environment.set("Path=one;PATH=two");
    try profile.validateFor(.posix);
    try std.testing.expectError(error.DuplicateLaunchEnvironmentKey, profile.validateFor(.windows));
    try profile.environment.set("NAME=\xff");
    try profile.validateFor(.posix);
    try std.testing.expectError(error.InvalidLaunchProfileUtf8, profile.validateFor(.windows));
}

test "launch profiles: bounded decoded lengths are checked before slicing" {
    inline for (.{ "shell", "command", "working_directory", "environment", "ssh_target" }) |field| {
        var profile: Profile = .{};
        @field(profile, field).len = @intCast(@field(profile, field).bytes.len + 1);
        try std.testing.expectError(error.LaunchProfileFieldTooLong, profile.validateFor(.posix));
        try std.testing.expectError(error.LaunchProfileFieldTooLong, profile.validateFor(.windows));
    }
    var named: NamedProfile = .{};
    named.name.len = max_name_bytes + 1;
    try std.testing.expectError(error.LaunchProfileFieldTooLong, named.validateFor(.windows));
    var profile: Profile = .{ .kind = .command };
    @memset(&profile.command.bytes, 'a');
    profile.command.len = max_command_bytes;
    try profile.validateFor(.windows);
}
test "terminal execute argv are safely quoted and bounded" {
    const argv = [_][]const u8{ "/usr/bin/echo", "space here", "a'b", "", "$(touch /tmp/no)" };
    var output: [max_command_bytes]u8 = undefined;
    try std.testing.expectEqualStrings(
        "'/usr/bin/echo' 'space here' 'a'\\''b' '' '$(touch /tmp/no)'",
        try quoteCommandArguments(&argv, &output),
    );

    const no_program = [_][]const u8{""};
    try std.testing.expectError(error.InvalidExecuteArguments, quoteCommandArguments(&no_program, &output));
    const controls = [_][]const u8{ "/bin/echo", "line\nbreak" };
    try std.testing.expectError(error.InvalidExecuteArgument, quoteCommandArguments(&controls, &output));
    var long_argument: [max_command_bytes]u8 = @splat('x');
    const long_argv = [_][]const u8{ "/bin/echo", long_argument[0..] };
    try std.testing.expectError(error.ExecuteArgumentsTooLong, quoteCommandArguments(&long_argv, &output));
}
