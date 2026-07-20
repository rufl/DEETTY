const std = @import("std");
const ConfigMod = @import("Config.zig");
const LaunchProfile = @import("../terminal/LaunchProfile.zig");
const WorkspaceActivation = @import("../workspace/Activation.zig");

const Io = std.Io;
const Dir = std.Io.Dir;

const config_magic = "NOCTTYCFG";
const config_version: u8 = 10;
const default_launch_profile_tail_bytes: usize = 1 + (5 * 8) + 4;
const default_launch_library_tail_bytes: usize = 2;
const default_recent_workspace_tail_bytes: usize = 1;
const default_font_rendering_tail_bytes: usize = 2;

pub const ConfigFileRole = enum {
    settings,
    backup,
};

pub const ConfigFileReceipt = struct {
    path: []u8,
    role: ConfigFileRole,
    bytes: usize,

    pub fn deinit(self: ConfigFileReceipt, allocator: std.mem.Allocator) void {
        allocator.free(self.path);
    }
};

pub const LoadedConfig = struct {
    config: ConfigMod.Config,
    owned_font_family: []u8,
    owned_default_theme: []u8,
    owned_syntax_theme: []u8,

    pub fn deinit(self: *LoadedConfig, allocator: std.mem.Allocator) void {
        allocator.free(self.owned_font_family);
        allocator.free(self.owned_default_theme);
        allocator.free(self.owned_syntax_theme);
        self.* = undefined;
    }
};

pub const LoadedConfigFile = struct {
    loaded: LoadedConfig,
    receipt: ConfigFileReceipt,

    pub fn deinit(self: *LoadedConfigFile, allocator: std.mem.Allocator) void {
        self.loaded.deinit(allocator);
        self.receipt.deinit(allocator);
        self.* = undefined;
    }
};

pub const max_config_file_bytes: usize = 1024 * 1024;

pub fn defaultConfigPathAlloc(allocator: std.mem.Allocator, home_dir: []const u8) ![]u8 {
    if (home_dir.len == 0) return error.InvalidConfigPath;
    return std.fs.path.join(allocator, &.{
        home_dir,
        ".config",
        "noctty",
        "settings.nocttycfg",
    });
}

pub fn exportConfigAlloc(allocator: std.mem.Allocator, config: ConfigMod.Config) ![]u8 {
    try config.validate();
    var writer = ConfigWriter.init(allocator);
    errdefer writer.deinit();

    try writer.bytes.appendSlice(config_magic);
    try writer.writeU8(config_version);
    try writer.writeWindowMode(config.default_mode);
    try writer.writeShortcut(config.dropdown.shortcut);
    try writer.writeU8(config.dropdown.width_percent);
    try writer.writeU8(config.dropdown.height_percent);
    try writer.writeU16(config.dropdown.animation_ms);
    try writer.writeBool(config.dropdown.hide_on_focus_loss);
    try writer.writeTabPosition(config.tabs.position);
    try writer.writeU16(config.tabs.compact_height_px);
    try writer.writeBool(config.tabs.show_status_counts);
    try writer.writeBool(config.tabs.tooltip_details);
    try writer.writeBool(config.tabs.focus_follows_pointer);
    try writer.writeU16(config.panels.padding_px);
    try writer.writeU16(config.panels.spacing_px);
    try writer.writeU16(config.panels.divider_px);
    try writer.writeU16(config.panels.border_px);
    try writer.writeU16(config.panels.terminal_titlebar_px);
    try writer.writeU16(config.panels.main_titlebar_px);
    try writer.writeString(config.font.family);
    try writer.writeScaledFloat(config.font.size_pt);
    try writer.writeScaledFloat(config.font.min_size_pt);
    try writer.writeScaledFloat(config.font.max_size_pt);
    try writer.writeBool(config.font.ligatures);
    try writer.writeBool(config.font.hidpi);
    try writer.writeStatusIndicator(config.status.indicator);
    try writer.writeU16(config.status.long_running_minutes);
    try writer.writeBool(config.status.desktop_notifications);
    try writer.writeBool(config.clipboard.bracketed_paste);
    try writer.writeBool(config.clipboard.repair_multiline_shell_commands);
    try writer.writeBool(config.clipboard.strip_unsafe_controls);
    try writer.writeString(config.default_theme);
    try writer.writeString(config.syntax_theme);
    try writer.writeBool(config.tabs.show_pane_info);
    try writer.writeU32(config.terminal.scrollback_lines);
    try writeLaunchProfile(&writer, config.terminal.launch_profile);
    try writer.writeU8(config.terminal.launch_profiles.count);
    try writer.writeU8(config.terminal.launch_profiles.selected_index);
    for (config.terminal.launch_profiles.entries[0..config.terminal.launch_profiles.count]) |*entry| {
        try writer.writeString(entry.name.slice());
        try writeLaunchProfile(&writer, entry.profile);
    }
    try writer.writeU8(config.recent_workspaces.count);
    for (config.recent_workspaces.entries[0..config.recent_workspaces.count]) |*entry|
        try writer.writeString(entry.slice());
    try writer.writeU8(@intFromEnum(config.font.antialias));
    try writer.writeU8(@intFromEnum(config.font.hinting));

    return writer.bytes.toOwnedSlice();
}

pub fn importConfigAlloc(allocator: std.mem.Allocator, bytes: []const u8) !LoadedConfig {
    var reader = ConfigReader{
        .allocator = allocator,
        .bytes = bytes,
    };
    try reader.expectMagic();
    const version = try reader.readU8();
    if (version == 0 or version > config_version) return error.UnsupportedConfigSnapshot;

    var config = ConfigMod.Config.defaults();
    config.default_mode = try reader.readWindowMode();
    config.dropdown.shortcut = try reader.readShortcut();
    config.dropdown.width_percent = try reader.readU8();
    config.dropdown.height_percent = try reader.readU8();
    config.dropdown.animation_ms = try reader.readU16();
    config.dropdown.hide_on_focus_loss = try reader.readBool();
    config.tabs.position = try reader.readTabPosition();
    config.tabs.compact_height_px = try reader.readU16();
    config.tabs.show_status_counts = try reader.readBool();
    config.tabs.tooltip_details = try reader.readBool();
    config.tabs.focus_follows_pointer = if (version >= 2) try reader.readBool() else false;
    config.panels.padding_px = try reader.readU16();
    config.panels.spacing_px = try reader.readU16();
    config.panels.divider_px = try reader.readU16();
    config.panels.border_px = try reader.readU16();
    config.panels.terminal_titlebar_px = try reader.readU16();
    config.panels.main_titlebar_px = try reader.readU16();

    const font_family = try reader.readStringAlloc();
    errdefer allocator.free(font_family);
    config.font.family = font_family;
    config.font.size_pt = try reader.readScaledFloat();
    config.font.min_size_pt = try reader.readScaledFloat();
    config.font.max_size_pt = try reader.readScaledFloat();
    config.font.ligatures = try reader.readBool();
    config.font.hidpi = try reader.readBool();
    config.status.indicator = try reader.readStatusIndicator();
    config.status.long_running_minutes = try reader.readU16();
    config.status.desktop_notifications = try reader.readBool();
    config.clipboard.bracketed_paste = try reader.readBool();
    config.clipboard.repair_multiline_shell_commands = try reader.readBool();
    config.clipboard.strip_unsafe_controls = try reader.readBool();

    const default_theme = try reader.readStringAlloc();
    errdefer allocator.free(default_theme);
    config.default_theme = default_theme;

    const syntax_theme = if (version >= 3 or !reader.finished())
        try reader.readStringAlloc()
    else
        try allocator.dupe(u8, "noctty-syntax-default");
    errdefer allocator.free(syntax_theme);
    config.syntax_theme = syntax_theme;

    config.tabs.show_pane_info = if (version >= 4)
        try reader.readBool()
    else
        true;
    config.terminal.scrollback_lines = if (version >= 5)
        try reader.readU32()
    else
        ConfigMod.Config.defaults().terminal.scrollback_lines;
    if (version >= 6) {
        try readLaunchProfile(&reader, &config.terminal.launch_profile, version);
    }
    if (version >= 7) {
        config.terminal.launch_profiles.count = try reader.readU8();
        if (config.terminal.launch_profiles.count > LaunchProfile.max_named_profiles)
            return error.InvalidConfigSnapshot;
        config.terminal.launch_profiles.selected_index = try reader.readU8();
        for (config.terminal.launch_profiles.entries[0..config.terminal.launch_profiles.count]) |*entry| {
            try entry.name.set(try reader.readStringSlice());
            try readLaunchProfile(&reader, &entry.profile, version);
        }
    }
    if (version >= 8) {
        config.recent_workspaces.count = try reader.readU8();
        if (config.recent_workspaces.count > WorkspaceActivation.max_recent_workspaces)
            return error.InvalidConfigSnapshot;
        for (config.recent_workspaces.entries[0..config.recent_workspaces.count]) |*entry|
            try entry.set(try reader.readStringSlice());
    }
    if (version >= 10) {
        config.font.antialias = switch (try reader.readU8()) {
            0 => .system,
            1 => .grayscale,
            2 => .subpixel,
            else => return error.InvalidConfigSnapshot,
        };
        config.font.hinting = switch (try reader.readU8()) {
            0 => .none,
            1 => .slight,
            2 => .full,
            else => return error.InvalidConfigSnapshot,
        };
    }

    if (!reader.finished()) return error.InvalidConfigSnapshot;
    try config.validate();

    return .{
        .config = config,
        .owned_font_family = font_family,
        .owned_default_theme = default_theme,
        .owned_syntax_theme = syntax_theme,
    };
}

fn writeLaunchProfile(writer: *ConfigWriter, profile: LaunchProfile.Profile) !void {
    try writer.writeU8(@intFromEnum(profile.kind));
    try writer.writeString(profile.shell.slice());
    try writer.writeString(profile.command.slice());
    try writer.writeString(profile.working_directory.slice());
    try writer.writeString(profile.environment.slice());
    try writer.writeString(profile.ssh_target.slice());
    try writer.writeU32(profile.scrollback_lines);
}

fn readLaunchProfile(reader: *ConfigReader, profile: *LaunchProfile.Profile, version: u8) !void {
    profile.kind = switch (try reader.readU8()) {
        0 => .shell,
        1 => .command,
        2 => .ssh,
        3 => if (version >= 9) .tmux else return error.InvalidConfigSnapshot,
        4 => if (version >= 9) .zellij else return error.InvalidConfigSnapshot,
        else => return error.InvalidConfigSnapshot,
    };
    try profile.shell.set(try reader.readStringSlice());
    try profile.command.set(try reader.readStringSlice());
    try profile.working_directory.set(try reader.readStringSlice());
    try profile.environment.set(try reader.readStringSlice());
    try profile.ssh_target.set(try reader.readStringSlice());
    profile.scrollback_lines = try reader.readU32();
}

pub fn saveConfigFile(
    allocator: std.mem.Allocator,
    io: Io,
    dir: Dir,
    path: []const u8,
    config: ConfigMod.Config,
    role: ConfigFileRole,
) !ConfigFileReceipt {
    if (path.len == 0) return error.InvalidConfigPath;

    const bytes = try exportConfigAlloc(allocator, config);
    defer allocator.free(bytes);

    var atomic = try dir.createFileAtomic(io, path, .{
        .make_path = true,
        .replace = true,
    });
    defer atomic.deinit(io);
    try atomic.file.writeStreamingAll(io, bytes);
    try atomic.replace(io);

    return .{
        .path = try allocator.dupe(u8, path),
        .role = role,
        .bytes = bytes.len,
    };
}

pub fn loadConfigFile(
    allocator: std.mem.Allocator,
    io: Io,
    dir: Dir,
    path: []const u8,
    role: ConfigFileRole,
) !LoadedConfigFile {
    if (path.len == 0) return error.InvalidConfigPath;

    const bytes = try dir.readFileAlloc(io, path, allocator, .limited(max_config_file_bytes));
    defer allocator.free(bytes);

    var loaded = try importConfigAlloc(allocator, bytes);
    errdefer loaded.deinit(allocator);
    return .{
        .loaded = loaded,
        .receipt = .{
            .path = try allocator.dupe(u8, path),
            .role = role,
            .bytes = bytes.len,
        },
    };
}

const ConfigWriter = struct {
    bytes: std.array_list.Managed(u8),

    fn init(allocator: std.mem.Allocator) ConfigWriter {
        return .{ .bytes = std.array_list.Managed(u8).init(allocator) };
    }

    fn deinit(self: *ConfigWriter) void {
        self.bytes.deinit();
    }

    fn writeWindowMode(self: *ConfigWriter, mode: ConfigMod.WindowMode) !void {
        try self.writeU8(switch (mode) {
            .dropdown => 0,
            .windowed => 1,
            .zen_fullscreen => 2,
        });
    }

    fn writeTabPosition(self: *ConfigWriter, position: ConfigMod.TabPosition) !void {
        try self.writeU8(switch (position) {
            .top => 0,
            .bottom => 1,
            .left => 2,
            .right => 3,
        });
    }

    fn writeStatusIndicator(self: *ConfigWriter, indicator: ConfigMod.StatusIndicator) !void {
        try self.writeU8(switch (indicator) {
            .background => 0,
            .border => 1,
        });
    }

    fn writeShortcut(self: *ConfigWriter, shortcut: ConfigMod.Shortcut) !void {
        try self.writeU8(@intFromEnum(shortcut.key));
        try self.writeBool(shortcut.ctrl);
        try self.writeBool(shortcut.shift);
        try self.writeBool(shortcut.alt);
        try self.writeBool(shortcut.super);
    }

    fn writeString(self: *ConfigWriter, value: []const u8) !void {
        try self.writeU64(value.len);
        try self.bytes.appendSlice(value);
    }

    fn writeScaledFloat(self: *ConfigWriter, value: f32) !void {
        try self.writeU32(@intFromFloat(value * 1000.0));
    }

    fn writeBool(self: *ConfigWriter, value: bool) !void {
        try self.writeU8(if (value) 1 else 0);
    }

    fn writeU8(self: *ConfigWriter, value: u8) !void {
        try self.bytes.append(value);
    }

    fn writeU16(self: *ConfigWriter, value: u16) !void {
        try self.writeIntLittle(value, 2);
    }

    fn writeU32(self: *ConfigWriter, value: u32) !void {
        try self.writeIntLittle(value, 4);
    }

    fn writeU64(self: *ConfigWriter, value: anytype) !void {
        try self.writeIntLittle(@as(u64, @intCast(value)), 8);
    }

    fn writeIntLittle(self: *ConfigWriter, value: u64, comptime byte_count: usize) !void {
        var idx: usize = 0;
        while (idx < byte_count) : (idx += 1) {
            const shift: u6 = @intCast(idx * 8);
            try self.bytes.append(@intCast((value >> shift) & 0xff));
        }
    }
};

const ConfigReader = struct {
    allocator: std.mem.Allocator,
    bytes: []const u8,
    offset: usize = 0,

    fn expectMagic(self: *ConfigReader) !void {
        if (self.bytes.len < config_magic.len) return error.InvalidConfigSnapshot;
        if (!std.mem.eql(u8, self.bytes[0..config_magic.len], config_magic)) return error.InvalidConfigSnapshot;
        self.offset = config_magic.len;
    }

    fn finished(self: ConfigReader) bool {
        return self.offset == self.bytes.len;
    }

    fn readWindowMode(self: *ConfigReader) !ConfigMod.WindowMode {
        return switch (try self.readU8()) {
            0 => .dropdown,
            1 => .windowed,
            2 => .zen_fullscreen,
            else => error.InvalidConfigSnapshot,
        };
    }

    fn readTabPosition(self: *ConfigReader) !ConfigMod.TabPosition {
        return switch (try self.readU8()) {
            0 => .top,
            1 => .bottom,
            2 => .left,
            3 => .right,
            else => error.InvalidConfigSnapshot,
        };
    }

    fn readStatusIndicator(self: *ConfigReader) !ConfigMod.StatusIndicator {
        return switch (try self.readU8()) {
            0 => .background,
            1 => .border,
            else => error.InvalidConfigSnapshot,
        };
    }

    fn readShortcut(self: *ConfigReader) !ConfigMod.Shortcut {
        return .{
            .key = try self.readShortcutKey(),
            .ctrl = try self.readBool(),
            .shift = try self.readBool(),
            .alt = try self.readBool(),
            .super = try self.readBool(),
        };
    }

    fn readShortcutKey(self: *ConfigReader) !ConfigMod.Shortcut.Key {
        const raw = try self.readU8();
        inline for (std.meta.fields(ConfigMod.Shortcut.Key)) |field| {
            if (field.value == raw) return @enumFromInt(raw);
        }
        return error.InvalidConfigSnapshot;
    }

    fn readStringAlloc(self: *ConfigReader) ![]u8 {
        return self.allocator.dupe(u8, try self.readStringSlice());
    }

    fn readStringSlice(self: *ConfigReader) ![]const u8 {
        const len = try self.readU64AsUsize();
        if (self.offset + len > self.bytes.len) return error.InvalidConfigSnapshot;
        const slice = self.bytes[self.offset .. self.offset + len];
        self.offset += len;
        return slice;
    }

    fn readScaledFloat(self: *ConfigReader) !f32 {
        return @as(f32, @floatFromInt(try self.readU32())) / 1000.0;
    }

    fn readBool(self: *ConfigReader) !bool {
        return switch (try self.readU8()) {
            0 => false,
            1 => true,
            else => error.InvalidConfigSnapshot,
        };
    }

    fn readU8(self: *ConfigReader) !u8 {
        if (self.offset >= self.bytes.len) return error.InvalidConfigSnapshot;
        const value = self.bytes[self.offset];
        self.offset += 1;
        return value;
    }

    fn readU16(self: *ConfigReader) !u16 {
        return @intCast(try self.readIntLittle(2));
    }

    fn readU32(self: *ConfigReader) !u32 {
        return @intCast(try self.readIntLittle(4));
    }

    fn readU64AsUsize(self: *ConfigReader) !usize {
        const value = try self.readIntLittle(8);
        if (value > std.math.maxInt(usize)) return error.InvalidConfigSnapshot;
        return @intCast(value);
    }

    fn readIntLittle(self: *ConfigReader, comptime byte_count: usize) !u64 {
        if (self.offset + byte_count > self.bytes.len) return error.InvalidConfigSnapshot;
        var value: u64 = 0;
        var idx: usize = 0;
        while (idx < byte_count) : (idx += 1) {
            const shift: u6 = @intCast(idx * 8);
            value |= @as(u64, self.bytes[self.offset + idx]) << shift;
        }
        self.offset += byte_count;
        return value;
    }
};

test "config snapshots export and import owned gui settings" {
    const allocator = std.testing.allocator;
    var config = ConfigMod.Config.defaults();
    config.default_mode = .windowed;
    config.dropdown.shortcut = .{ .key = .t, .ctrl = true, .alt = true };
    config.dropdown.width_percent = 90;
    config.tabs.position = .bottom;
    config.tabs.tooltip_details = false;
    config.tabs.focus_follows_pointer = true;
    config.tabs.show_pane_info = false;
    config.terminal.scrollback_lines = 4096;
    var launch_profile = LaunchProfile.Profile{ .kind = .command };
    try launch_profile.shell.set("/bin/sh");
    try launch_profile.command.set("printf ready");
    try launch_profile.working_directory.set("/tmp");
    try launch_profile.environment.set("NOCTTY_PROFILE=ready;LANG=C.UTF-8");
    launch_profile.scrollback_lines = 8192;
    _ = try config.terminal.saveAndSelectLaunchProfile("Local build", launch_profile);
    try config.recent_workspaces.record("/tmp/Release Ops.nocttyws");
    try config.recent_workspaces.record("/home/alice/project.nocttyws");
    config.panels.padding_px = 8;
    config.font.family = "Commit Mono";
    config.font.size_pt = 13.5;
    config.font.antialias = .grayscale;
    config.font.hinting = .full;
    config.status.indicator = .background;
    config.status.long_running_minutes = 45;
    config.clipboard.bracketed_paste = false;
    config.default_theme = "workspace-night";

    const bytes = try exportConfigAlloc(allocator, config);
    defer allocator.free(bytes);
    try std.testing.expect(bytes.len > config_magic.len);

    var loaded = try importConfigAlloc(allocator, bytes);
    defer loaded.deinit(allocator);
    try std.testing.expectEqual(ConfigMod.WindowMode.windowed, loaded.config.default_mode);
    try std.testing.expectEqual(ConfigMod.Shortcut.Key.t, loaded.config.dropdown.shortcut.key);
    try std.testing.expect(loaded.config.dropdown.shortcut.ctrl);
    try std.testing.expect(loaded.config.dropdown.shortcut.alt);
    try std.testing.expectEqual(ConfigMod.TabPosition.bottom, loaded.config.tabs.position);
    try std.testing.expect(!loaded.config.tabs.tooltip_details);
    try std.testing.expect(loaded.config.tabs.focus_follows_pointer);
    try std.testing.expect(!loaded.config.tabs.show_pane_info);
    try std.testing.expectEqual(@as(u32, 4096), loaded.config.terminal.scrollback_lines);
    try std.testing.expectEqual(LaunchProfile.Kind.command, loaded.config.terminal.launch_profile.kind);
    try std.testing.expectEqualStrings("/bin/sh", loaded.config.terminal.launch_profile.shell.slice());
    try std.testing.expectEqualStrings("printf ready", loaded.config.terminal.launch_profile.command.slice());
    try std.testing.expectEqualStrings("/tmp", loaded.config.terminal.launch_profile.working_directory.slice());
    try std.testing.expectEqualStrings("NOCTTY_PROFILE=ready;LANG=C.UTF-8", loaded.config.terminal.launch_profile.environment.slice());
    try std.testing.expectEqual(@as(u32, 8192), loaded.config.terminal.launch_profile.scrollback_lines);
    try std.testing.expectEqual(@as(u8, 1), loaded.config.terminal.launch_profiles.count);
    try std.testing.expectEqual(@as(u8, 0), loaded.config.terminal.launch_profiles.selected_index);
    try std.testing.expectEqualStrings("Local build", loaded.config.terminal.launch_profiles.entries[0].name.slice());
    try std.testing.expect(loaded.config.terminal.launch_profiles.entries[0].profile.eql(&loaded.config.terminal.launch_profile));
    try std.testing.expectEqual(@as(u8, 2), loaded.config.recent_workspaces.count);
    try std.testing.expectEqualStrings("/home/alice/project.nocttyws", loaded.config.recent_workspaces.at(0).?);
    try std.testing.expectEqualStrings("/tmp/Release Ops.nocttyws", loaded.config.recent_workspaces.at(1).?);
    try std.testing.expectEqual(@as(u16, 8), loaded.config.panels.padding_px);
    try std.testing.expectEqualStrings("Commit Mono", loaded.config.font.family);
    try std.testing.expectEqual(@as(f32, 13.5), loaded.config.font.size_pt);
    try std.testing.expectEqual(ConfigMod.FontAntialias.grayscale, loaded.config.font.antialias);
    try std.testing.expectEqual(ConfigMod.FontHinting.full, loaded.config.font.hinting);
    try std.testing.expectEqual(ConfigMod.StatusIndicator.background, loaded.config.status.indicator);
    try std.testing.expectEqual(@as(u16, 45), loaded.config.status.long_running_minutes);
    try std.testing.expect(!loaded.config.clipboard.bracketed_paste);
    try std.testing.expectEqualStrings("workspace-night", loaded.config.default_theme);
}

test "version one config snapshots load with pointer focus disabled" {
    const allocator = std.testing.allocator;
    var config = ConfigMod.Config.defaults();
    config.dropdown.width_percent = 87;
    config.tabs.position = .bottom;
    const current = try exportConfigAlloc(allocator, config);
    defer allocator.free(current);

    const focus_field_offset = config_magic.len + 1 + 1 + 5 + 1 + 1 + 2 + 1 + 1 + 2 + 1 + 1;
    const legacy = try allocator.alloc(u8, current.len - 6 - default_launch_profile_tail_bytes - default_launch_library_tail_bytes - default_recent_workspace_tail_bytes - default_font_rendering_tail_bytes);
    defer allocator.free(legacy);
    @memcpy(legacy[0..focus_field_offset], current[0..focus_field_offset]);
    @memcpy(legacy[focus_field_offset..], current[focus_field_offset + 1 .. current.len - 5 - default_launch_profile_tail_bytes - default_launch_library_tail_bytes - default_recent_workspace_tail_bytes - default_font_rendering_tail_bytes]);
    legacy[config_magic.len] = 1;

    var loaded = try importConfigAlloc(allocator, legacy);
    defer loaded.deinit(allocator);
    try std.testing.expectEqual(@as(u8, 87), loaded.config.dropdown.width_percent);
    try std.testing.expectEqual(ConfigMod.TabPosition.bottom, loaded.config.tabs.position);
    try std.testing.expect(!loaded.config.tabs.focus_follows_pointer);
    try std.testing.expect(loaded.config.tabs.show_pane_info);
    try std.testing.expectEqual(@as(u32, 1000), loaded.config.terminal.scrollback_lines);
}

test "version three config snapshots enable pane information by default" {
    const allocator = std.testing.allocator;
    const current = try exportConfigAlloc(allocator, ConfigMod.Config.defaults());
    defer allocator.free(current);
    const legacy = try allocator.dupe(u8, current[0 .. current.len - 5 - default_launch_profile_tail_bytes - default_launch_library_tail_bytes - default_recent_workspace_tail_bytes - default_font_rendering_tail_bytes]);
    defer allocator.free(legacy);
    legacy[config_magic.len] = 3;

    var loaded = try importConfigAlloc(allocator, legacy);
    defer loaded.deinit(allocator);
    try std.testing.expect(loaded.config.tabs.show_pane_info);
    try std.testing.expectEqual(@as(u32, 1000), loaded.config.terminal.scrollback_lines);
}

test "version four config snapshots use the bounded scrollback default" {
    const allocator = std.testing.allocator;
    const current = try exportConfigAlloc(allocator, ConfigMod.Config.defaults());
    defer allocator.free(current);
    const legacy = try allocator.dupe(u8, current[0 .. current.len - 4 - default_launch_profile_tail_bytes - default_launch_library_tail_bytes - default_recent_workspace_tail_bytes - default_font_rendering_tail_bytes]);
    defer allocator.free(legacy);
    legacy[config_magic.len] = 4;

    var loaded = try importConfigAlloc(allocator, legacy);
    defer loaded.deinit(allocator);
    try std.testing.expectEqual(@as(u32, 1000), loaded.config.terminal.scrollback_lines);
}

test "version five config snapshots use the default launch profile" {
    const allocator = std.testing.allocator;
    const current = try exportConfigAlloc(allocator, ConfigMod.Config.defaults());
    defer allocator.free(current);
    const legacy = try allocator.dupe(u8, current[0 .. current.len - default_launch_profile_tail_bytes - default_launch_library_tail_bytes - default_recent_workspace_tail_bytes - default_font_rendering_tail_bytes]);
    defer allocator.free(legacy);
    legacy[config_magic.len] = 5;

    var loaded = try importConfigAlloc(allocator, legacy);
    defer loaded.deinit(allocator);
    try std.testing.expectEqual(LaunchProfile.Kind.shell, loaded.config.terminal.launch_profile.kind);
    try std.testing.expectEqualStrings("", loaded.config.terminal.launch_profile.shell.slice());
    try std.testing.expectEqual(@as(u32, 1000), loaded.config.terminal.launch_profile.scrollback_lines);
    try std.testing.expectEqual(@as(u8, 0), loaded.config.terminal.launch_profiles.count);
}

test "version six config snapshots retain the active profile with an empty library" {
    const allocator = std.testing.allocator;
    var config = ConfigMod.Config.defaults();
    var profile = LaunchProfile.Profile{ .kind = .command };
    try profile.command.set("printf legacy-six");
    try config.terminal.setLaunchProfile(profile);
    const current = try exportConfigAlloc(allocator, config);
    defer allocator.free(current);
    const legacy = try allocator.dupe(u8, current[0 .. current.len - default_launch_library_tail_bytes - default_recent_workspace_tail_bytes - default_font_rendering_tail_bytes]);
    defer allocator.free(legacy);
    legacy[config_magic.len] = 6;

    var loaded = try importConfigAlloc(allocator, legacy);
    defer loaded.deinit(allocator);
    try std.testing.expectEqual(LaunchProfile.Kind.command, loaded.config.terminal.launch_profile.kind);
    try std.testing.expectEqualStrings("printf legacy-six", loaded.config.terminal.launch_profile.command.slice());
    try std.testing.expectEqual(@as(u8, 0), loaded.config.terminal.launch_profiles.count);
    try std.testing.expectEqual(LaunchProfile.no_selection, loaded.config.terminal.launch_profiles.selected_index);
}

test "version seven config snapshots retain named profiles with no recent workspaces" {
    const allocator = std.testing.allocator;
    var config = ConfigMod.Config.defaults();
    var profile = LaunchProfile.Profile{ .kind = .command };
    try profile.command.set("printf legacy-seven");
    _ = try config.terminal.saveAndSelectLaunchProfile("Legacy build", profile);
    const current = try exportConfigAlloc(allocator, config);
    defer allocator.free(current);
    const legacy = try allocator.dupe(u8, current[0 .. current.len - default_recent_workspace_tail_bytes - default_font_rendering_tail_bytes]);
    defer allocator.free(legacy);
    legacy[config_magic.len] = 7;

    var loaded = try importConfigAlloc(allocator, legacy);
    defer loaded.deinit(allocator);
    try std.testing.expectEqual(@as(u8, 1), loaded.config.terminal.launch_profiles.count);
    try std.testing.expectEqualStrings("Legacy build", loaded.config.terminal.launch_profiles.entries[0].name.slice());
    try std.testing.expectEqual(@as(u8, 0), loaded.config.recent_workspaces.count);
}

test "version nine config snapshots retain continuity profiles" {
    const allocator = std.testing.allocator;
    var config = ConfigMod.Config.defaults();
    var tmux = LaunchProfile.Profile{ .kind = .tmux };
    try tmux.ssh_target.set("noctty-work");
    try tmux.working_directory.set("/tmp");
    _ = try config.terminal.saveAndSelectLaunchProfile("Persistent tmux", tmux);
    var zellij = LaunchProfile.Profile{ .kind = .zellij };
    try zellij.ssh_target.set("noctty-pair");
    _ = try config.terminal.saveAndSelectLaunchProfile("Persistent Zellij", zellij);

    const current = try exportConfigAlloc(allocator, config);
    defer allocator.free(current);
    const bytes = try allocator.dupe(u8, current[0 .. current.len - default_font_rendering_tail_bytes]);
    defer allocator.free(bytes);
    bytes[config_magic.len] = 9;

    var loaded = try importConfigAlloc(allocator, bytes);
    defer loaded.deinit(allocator);
    try std.testing.expectEqual(LaunchProfile.Kind.zellij, loaded.config.terminal.launch_profile.kind);
    try std.testing.expectEqualStrings("noctty-pair", loaded.config.terminal.launch_profile.argument());
    try std.testing.expectEqual(@as(u8, 2), loaded.config.terminal.launch_profiles.count);
    try std.testing.expectEqual(LaunchProfile.Kind.tmux, loaded.config.terminal.launch_profiles.entries[0].profile.kind);
    try std.testing.expectEqualStrings("noctty-work", loaded.config.terminal.launch_profiles.entries[0].profile.argument());

    const mislabeled_legacy = try allocator.dupe(u8, bytes);
    defer allocator.free(mislabeled_legacy);
    mislabeled_legacy[config_magic.len] = 8;
    try std.testing.expectError(
        error.InvalidConfigSnapshot,
        importConfigAlloc(allocator, mislabeled_legacy),
    );
}

test "version eight config snapshots retain recent workspaces" {
    const allocator = std.testing.allocator;
    var config = ConfigMod.Config.defaults();
    try config.recent_workspaces.record("/tmp/legacy-eight.nocttyws");
    const current = try exportConfigAlloc(allocator, config);
    defer allocator.free(current);
    const legacy = try allocator.dupe(u8, current[0 .. current.len - default_font_rendering_tail_bytes]);
    defer allocator.free(legacy);
    legacy[config_magic.len] = 8;

    var loaded = try importConfigAlloc(allocator, legacy);
    defer loaded.deinit(allocator);
    try std.testing.expectEqual(@as(u8, 1), loaded.config.recent_workspaces.count);
    try std.testing.expectEqualStrings(
        "/tmp/legacy-eight.nocttyws",
        loaded.config.recent_workspaces.at(0).?,
    );
}

test "config snapshots reject invalid bytes" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(error.InvalidConfigSnapshot, importConfigAlloc(allocator, "not-noctty-config"));

    const config = ConfigMod.Config.defaults();
    const bytes = try exportConfigAlloc(allocator, config);
    defer allocator.free(bytes);
    const bad = try allocator.dupe(u8, bytes);
    defer allocator.free(bad);
    bad[config_magic.len] = 99;
    try std.testing.expectError(error.UnsupportedConfigSnapshot, importConfigAlloc(allocator, bad));
}

test "default config path uses native config location" {
    const allocator = std.testing.allocator;
    const path = try defaultConfigPathAlloc(allocator, "/home/alice");
    defer allocator.free(path);
    try std.testing.expectEqualStrings("/home/alice/.config/noctty/settings.nocttycfg", path);
}

test "config snapshots save and load through atomic storage" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var config = ConfigMod.Config.defaults();
    config.font.family = "Commit Mono";
    config.default_theme = "workspace-night";
    config.tabs.position = .bottom;

    const saved = try saveConfigFile(allocator, io, tmp.dir, "settings/noctty.nocttycfg", config, .settings);
    defer saved.deinit(allocator);
    try std.testing.expect(saved.bytes > config_magic.len);

    var loaded = try loadConfigFile(allocator, io, tmp.dir, "settings/noctty.nocttycfg", .settings);
    defer loaded.deinit(allocator);
    try std.testing.expectEqual(ConfigFileRole.settings, loaded.receipt.role);
    try std.testing.expectEqualStrings("Commit Mono", loaded.loaded.config.font.family);
    try std.testing.expectEqualStrings("workspace-night", loaded.loaded.config.default_theme);
    try std.testing.expectEqual(ConfigMod.TabPosition.bottom, loaded.loaded.config.tabs.position);
}
