const std = @import("std");
const LaunchProfile = @import("../terminal/LaunchProfile.zig");
const WorkspaceActivation = @import("../workspace/Activation.zig");

pub const WindowMode = enum {
    dropdown,
    windowed,
    zen_fullscreen,
};

pub const TabPosition = enum {
    top,
    bottom,
    left,
    right,
};

pub const StatusIndicator = enum {
    background,
    border,
};

pub const Shortcut = struct {
    key: Key = .f10,
    ctrl: bool = false,
    shift: bool = false,
    alt: bool = false,
    super: bool = false,

    pub const Key = enum {
        a,
        b,
        c,
        d,
        e,
        f,
        g,
        h,
        i,
        j,
        k,
        l,
        m,
        n,
        o,
        p,
        q,
        r,
        s,
        t,
        u,
        v,
        w,
        x,
        y,
        z,
        digit0,
        digit1,
        digit2,
        digit3,
        digit4,
        digit5,
        digit6,
        digit7,
        digit8,
        digit9,
        grave,
        escape,
        space,
        enter,
        tab,
        backspace,
        insert,
        delete,
        home,
        end,
        page_up,
        page_down,
        arrow_left,
        arrow_right,
        arrow_up,
        arrow_down,
        f1,
        f2,
        f3,
        f4,
        f5,
        f6,
        f7,
        f8,
        f9,
        f10,
        f11,
        f12,

        pub fn label(self: Key) []const u8 {
            return switch (self) {
                .a => "A",
                .b => "B",
                .c => "C",
                .d => "D",
                .e => "E",
                .f => "F",
                .g => "G",
                .h => "H",
                .i => "I",
                .j => "J",
                .k => "K",
                .l => "L",
                .m => "M",
                .n => "N",
                .o => "O",
                .p => "P",
                .q => "Q",
                .r => "R",
                .s => "S",
                .t => "T",
                .u => "U",
                .v => "V",
                .w => "W",
                .x => "X",
                .y => "Y",
                .z => "Z",
                .digit0 => "0",
                .digit1 => "1",
                .digit2 => "2",
                .digit3 => "3",
                .digit4 => "4",
                .digit5 => "5",
                .digit6 => "6",
                .digit7 => "7",
                .digit8 => "8",
                .digit9 => "9",
                .grave => "`",
                .escape => "Esc",
                .space => "Space",
                .enter => "Enter",
                .tab => "Tab",
                .backspace => "Backspace",
                .insert => "Insert",
                .delete => "Delete",
                .home => "Home",
                .end => "End",
                .page_up => "PageUp",
                .page_down => "PageDown",
                .arrow_left => "Left",
                .arrow_right => "Right",
                .arrow_up => "Up",
                .arrow_down => "Down",
                .f1 => "F1",
                .f2 => "F2",
                .f3 => "F3",
                .f4 => "F4",
                .f5 => "F5",
                .f6 => "F6",
                .f7 => "F7",
                .f8 => "F8",
                .f9 => "F9",
                .f10 => "F10",
                .f11 => "F11",
                .f12 => "F12",
            };
        }

        pub fn isFunctionKey(self: Key) bool {
            return switch (self) {
                .f1, .f2, .f3, .f4, .f5, .f6, .f7, .f8, .f9, .f10, .f11, .f12 => true,
                else => false,
            };
        }
    };

    pub fn displayName(self: Shortcut) []const u8 {
        if (self.ctrl or self.shift or self.alt or self.super) return "custom-shortcut";
        return self.key.label();
    }

    pub fn fromKeyEvent(event: KeyEvent) !Shortcut {
        const shortcut = Shortcut{
            .key = event.key,
            .ctrl = event.ctrl,
            .shift = event.shift,
            .alt = event.alt,
            .super = event.super,
        };
        try shortcut.validateGlobal();
        return shortcut;
    }

    pub fn validateGlobal(self: Shortcut) !void {
        if (!self.key.isFunctionKey() and !self.ctrl and !self.alt and !self.super) {
            return error.GlobalShortcutNeedsModifier;
        }
    }

    pub fn formatDisplay(self: Shortcut, writer: anytype) !void {
        var wrote_modifier = false;
        if (self.ctrl) {
            try writer.writeAll("Ctrl");
            wrote_modifier = true;
        }
        if (self.shift) {
            if (wrote_modifier) try writer.writeAll("+");
            try writer.writeAll("Shift");
            wrote_modifier = true;
        }
        if (self.alt) {
            if (wrote_modifier) try writer.writeAll("+");
            try writer.writeAll("Alt");
            wrote_modifier = true;
        }
        if (self.super) {
            if (wrote_modifier) try writer.writeAll("+");
            try writer.writeAll("Meta");
            wrote_modifier = true;
        }
        if (wrote_modifier) try writer.writeAll("+");
        try writer.writeAll(self.key.label());
    }
};

pub const KeyEvent = struct {
    key: Shortcut.Key,
    ctrl: bool = false,
    shift: bool = false,
    alt: bool = false,
    super: bool = false,
};

pub const FontAntialias = enum { system, grayscale, subpixel };
pub const FontHinting = enum { none, slight, full };

pub const FontConfig = struct {
    family: []const u8 = "Monospace",
    size_pt: f32 = 13.0,
    min_size_pt: f32 = 7.0,
    max_size_pt: f32 = 28.0,
    ligatures: bool = true,
    hidpi: bool = true,
    antialias: FontAntialias = .subpixel,
    hinting: FontHinting = .slight,

    pub fn clampSize(self: FontConfig, requested: f32) f32 {
        return @min(self.max_size_pt, @max(self.min_size_pt, requested));
    }

    pub fn validate(self: FontConfig) !void {
        if (std.mem.trim(u8, self.family, " \t\r\n").len == 0) return error.InvalidFontFamily;
        if (self.min_size_pt <= 0 or self.max_size_pt < self.min_size_pt) return error.InvalidFontRange;
        if (self.size_pt < self.min_size_pt or self.size_pt > self.max_size_pt) return error.InvalidFontSize;
    }
};

pub const DropdownConfig = struct {
    shortcut: Shortcut = .{},
    width_percent: u8 = 96,
    height_percent: u8 = 55,
    width_px: u16 = 0,
    height_px: u16 = 0,
    animation_ms: u16 = 120,
    hide_on_focus_loss: bool = true,
};

pub const TabConfig = struct {
    position: TabPosition = .bottom,
    compact_height_px: u16 = 18,
    show_status_counts: bool = true,
    tooltip_details: bool = true,
    focus_follows_pointer: bool = false,
    show_pane_info: bool = true,

    pub fn validate(self: TabConfig) !void {
        if (self.compact_height_px < 12 or self.compact_height_px > 64) return error.InvalidTabHeight;
    }
};

pub const PanelMetrics = struct {
    padding_px: u16 = 6,
    spacing_px: u16 = 4,
    divider_px: u16 = 1,
    border_px: u16 = 1,
    terminal_titlebar_px: u16 = 0,
    main_titlebar_px: u16 = 0,

    pub fn validate(self: PanelMetrics) !void {
        if (self.padding_px > 64 or self.spacing_px > 64) return error.InvalidPanelSpacing;
        if (self.divider_px > 8 or self.border_px > 8) return error.InvalidPanelBorder;
        if (self.terminal_titlebar_px != 0 or self.main_titlebar_px != 0) return error.ThickTitlebarForbidden;
    }
};

pub const StatusConfig = struct {
    indicator: StatusIndicator = .background,
    long_running_minutes: u16 = 20,
    desktop_notifications: bool = true,

    pub fn validate(self: StatusConfig) !void {
        if (self.long_running_minutes > 24 * 60) return error.InvalidLongRunningThreshold;
    }
};

pub const ClipboardConfig = struct {
    bracketed_paste: bool = true,
    repair_multiline_shell_commands: bool = true,
    strip_unsafe_controls: bool = true,
};

pub const TerminalConfig = struct {
    pub const max_scrollback_lines: u32 = 100_000;

    scrollback_lines: u32 = 1000,
    launch_profile: LaunchProfile.Profile = .{},
    launch_profiles: LaunchProfile.Library = .{},

    pub fn validate(self: TerminalConfig) !void {
        if (self.scrollback_lines > max_scrollback_lines) return error.InvalidScrollbackLines;
        try self.launch_profile.validate();
        try self.launch_profiles.validate();
        if (self.launch_profiles.selected()) |selected| {
            if (!self.launch_profile.eql(&selected.profile))
                return error.LaunchProfileSelectionMismatch;
        }
    }

    pub fn setLaunchProfile(self: *TerminalConfig, profile: LaunchProfile.Profile) !void {
        try profile.validate();
        var next = self.*;
        next.launch_profile = profile;
        next.launch_profiles.clearSelection();
        try next.validate();
        self.* = next;
    }

    pub fn saveAndSelectLaunchProfile(
        self: *TerminalConfig,
        name: []const u8,
        profile: LaunchProfile.Profile,
    ) !usize {
        var next = self.*;
        const index = try next.launch_profiles.saveAndSelect(name, profile);
        next.launch_profile = profile;
        try next.validate();
        self.* = next;
        return index;
    }

    pub fn selectLaunchProfile(self: *TerminalConfig, index: usize) !void {
        var next = self.*;
        next.launch_profile = try next.launch_profiles.select(index);
        try next.validate();
        self.* = next;
    }

    pub fn removeLaunchProfile(self: *TerminalConfig, index: usize) !void {
        var next = self.*;
        try next.launch_profiles.remove(index);
        try next.validate();
        self.* = next;
    }
};

pub const Config = struct {
    default_mode: WindowMode = .dropdown,
    dropdown: DropdownConfig = .{},
    tabs: TabConfig = .{},
    panels: PanelMetrics = .{},
    font: FontConfig = .{},
    status: StatusConfig = .{},
    clipboard: ClipboardConfig = .{},
    terminal: TerminalConfig = .{},
    recent_workspaces: WorkspaceActivation.RecentWorkspaces = .{},
    default_theme: []const u8 = "noctty-dark",
    syntax_theme: []const u8 = "noctty-syntax-default",

    pub fn defaults() Config {
        return .{};
    }

    pub fn validate(self: Config) !void {
        if (self.dropdown.width_percent == 0 or self.dropdown.width_percent > 100) {
            return error.InvalidDropdownWidth;
        }
        if (self.dropdown.height_percent == 0 or self.dropdown.height_percent > 100) {
            return error.InvalidDropdownHeight;
        }
        try self.tabs.validate();
        try self.panels.validate();
        try self.font.validate();
        try self.status.validate();
        try self.terminal.validate();
        try self.recent_workspaces.validate();
        if (std.mem.trim(u8, self.default_theme, " \t\r\n").len == 0) return error.InvalidThemeName;
        if (std.mem.trim(u8, self.syntax_theme, " \t\r\n").len == 0) return error.InvalidSyntaxThemeName;
        try self.dropdown.shortcut.validateGlobal();
    }
};

test "defaults match product constraints" {
    const cfg = Config.defaults();
    try cfg.validate();
    try std.testing.expectEqual(WindowMode.dropdown, cfg.default_mode);
    try std.testing.expectEqual(Shortcut.Key.f10, cfg.dropdown.shortcut.key);
    try std.testing.expectEqualStrings("Monospace", cfg.font.family);
    try std.testing.expectEqual(@as(f32, 13.0), cfg.font.size_pt);
    try std.testing.expectEqual(@as(u8, 96), cfg.dropdown.width_percent);
    try std.testing.expectEqual(@as(u8, 55), cfg.dropdown.height_percent);
    try std.testing.expectEqual(@as(u16, 120), cfg.dropdown.animation_ms);
    try std.testing.expectEqual(TabPosition.bottom, cfg.tabs.position);
    try std.testing.expectEqual(@as(u16, 18), cfg.tabs.compact_height_px);
    try std.testing.expectEqual(StatusIndicator.background, cfg.status.indicator);
    try std.testing.expect(cfg.font.ligatures);
    try std.testing.expectEqual(FontAntialias.subpixel, cfg.font.antialias);
    try std.testing.expectEqual(FontHinting.slight, cfg.font.hinting);
    try std.testing.expectEqual(@as(u32, 1000), cfg.terminal.scrollback_lines);
    try std.testing.expectEqual(LaunchProfile.Kind.shell, cfg.terminal.launch_profile.kind);
    try std.testing.expectEqual(@as(u8, 0), cfg.terminal.launch_profiles.count);
    try std.testing.expectEqual(@as(u8, 0), cfg.recent_workspaces.count);
    try std.testing.expectEqual(@as(u16, 0), cfg.panels.main_titlebar_px);
    try std.testing.expectEqual(@as(u16, 0), cfg.panels.terminal_titlebar_px);
}

test "validation rejects invalid gui settings" {
    var cfg = Config.defaults();
    cfg.font.family = "  ";
    try std.testing.expectError(error.InvalidFontFamily, cfg.validate());

    cfg = Config.defaults();
    cfg.font.size_pt = 99;
    try std.testing.expectError(error.InvalidFontSize, cfg.validate());

    cfg = Config.defaults();
    cfg.tabs.compact_height_px = 8;
    try std.testing.expectError(error.InvalidTabHeight, cfg.validate());

    cfg = Config.defaults();
    cfg.panels.main_titlebar_px = 1;
    try std.testing.expectError(error.ThickTitlebarForbidden, cfg.validate());

    cfg = Config.defaults();
    cfg.default_theme = "";
    try std.testing.expectError(error.InvalidThemeName, cfg.validate());

    cfg = Config.defaults();
    cfg.terminal.scrollback_lines = TerminalConfig.max_scrollback_lines + 1;
    try std.testing.expectError(error.InvalidScrollbackLines, cfg.validate());

    cfg = Config.defaults();
    cfg.terminal.launch_profile.kind = .command;
    try std.testing.expectError(error.InvalidLaunchCommand, cfg.validate());
}

test "terminal config manages named launch profiles without partial state" {
    var terminal = TerminalConfig{};
    var build = LaunchProfile.Profile{ .kind = .command };
    try build.command.set("printf build");
    try std.testing.expectEqual(@as(usize, 0), try terminal.saveAndSelectLaunchProfile("Build", build));
    try std.testing.expect(terminal.launch_profile.eql(&build));
    try std.testing.expectEqual(@as(u8, 0), terminal.launch_profiles.selected_index);

    var shell = LaunchProfile.Profile{};
    try shell.shell.set("/bin/sh");
    try terminal.setLaunchProfile(shell);
    try std.testing.expect(terminal.launch_profile.eql(&shell));
    try std.testing.expectEqual(LaunchProfile.no_selection, terminal.launch_profiles.selected_index);

    try terminal.selectLaunchProfile(0);
    try std.testing.expect(terminal.launch_profile.eql(&build));
    try terminal.removeLaunchProfile(0);
    try std.testing.expectEqual(@as(u8, 0), terminal.launch_profiles.count);
    try std.testing.expectEqual(LaunchProfile.no_selection, terminal.launch_profiles.selected_index);
    try std.testing.expect(terminal.launch_profile.eql(&build));
}

test "shortcut recorder accepts function keys and modified letters" {
    const f10 = try Shortcut.fromKeyEvent(.{ .key = .f10 });
    try std.testing.expectEqual(Shortcut.Key.f10, f10.key);

    const ctrl_alt_t = try Shortcut.fromKeyEvent(.{ .key = .t, .ctrl = true, .alt = true });
    var buf: [32]u8 = undefined;
    var stream = std.Io.Writer.fixed(&buf);
    try ctrl_alt_t.formatDisplay(&stream);
    try std.testing.expectEqualStrings("Ctrl+Alt+T", stream.buffered());
}

test "global shortcut rejects bare typing keys" {
    try std.testing.expectError(error.GlobalShortcutNeedsModifier, Shortcut.fromKeyEvent(.{ .key = .t }));
}
