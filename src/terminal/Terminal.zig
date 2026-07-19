const std = @import("std");
const Config = @import("../config/Config.zig");
const Theme = @import("../theme/Theme.zig");

pub const PaneId = u64;

pub const TerminalStatus = enum {
    idle,
    running,
    pending_interaction,
    done,
    @"error",
    long_running,
};

pub const ExitEvent = struct {
    code: u8,
    at_ms: u64,
};

pub const StatusEvent = union(enum) {
    process_started: u64,
    output_received: u64,
    waiting_for_input: u64,
    exited: ExitEvent,
    tick: u64,
    reset_idle,
};

pub const TerminalProfile = struct {
    theme_name: []const u8 = "noctty-dark",
    font_family: []const u8 = "JetBrains Mono",
    font_size_pt: f32 = 12.0,
    ligatures: bool = true,

    pub fn validate(self: TerminalProfile, font_config: Config.FontConfig) !void {
        if (std.mem.trim(u8, self.theme_name, " \t\r\n").len == 0) return error.InvalidThemeName;
        if (std.mem.trim(u8, self.font_family, " \t\r\n").len == 0) return error.InvalidFontFamily;
        if (self.font_size_pt < font_config.min_size_pt or self.font_size_pt > font_config.max_size_pt) return error.InvalidFontSize;
    }
};

pub const ProfilePreset = enum {
    global_default,
    compact,
    readable,
    high_contrast,
    mono_no_ligatures,

    pub fn profile(self: ProfilePreset, config: Config.Config) TerminalProfile {
        return switch (self) {
            .global_default => .{
                .theme_name = config.default_theme,
                .font_family = config.font.family,
                .font_size_pt = config.font.size_pt,
                .ligatures = config.font.ligatures,
            },
            .compact => .{
                .theme_name = config.default_theme,
                .font_family = config.font.family,
                .font_size_pt = config.font.clampSize(9.0),
                .ligatures = config.font.ligatures,
            },
            .readable => .{
                .theme_name = config.default_theme,
                .font_family = config.font.family,
                .font_size_pt = config.font.clampSize(14.0),
                .ligatures = config.font.ligatures,
            },
            .high_contrast => .{
                .theme_name = "noctty-high-contrast",
                .font_family = config.font.family,
                .font_size_pt = config.font.clampSize(12.0),
                .ligatures = config.font.ligatures,
            },
            .mono_no_ligatures => .{
                .theme_name = config.default_theme,
                .font_family = config.font.family,
                .font_size_pt = config.font.size_pt,
                .ligatures = false,
            },
        };
    }
};

pub const StatusStyle = struct {
    indicator: Config.StatusIndicator,
    color: Theme.Color,
};

pub const Pane = struct {
    allocator: std.mem.Allocator,
    id: PaneId,
    title: []u8,
    cwd: []u8,
    worktree_root: ?[]u8 = null,
    profile: TerminalProfile = .{},
    owned_profile_theme_name: ?[]u8 = null,
    owned_profile_font_family: ?[]u8 = null,
    status: TerminalStatus = .idle,
    process_started_at_ms: ?u64 = null,
    last_activity_at_ms: ?u64 = null,
    pending_since_ms: ?u64 = null,
    exit_code: ?u8 = null,
    selected: bool = false,
    tags: std.array_list.Managed([]u8),

    pub fn init(allocator: std.mem.Allocator, id: PaneId, title: []const u8, cwd: []const u8) !Pane {
        return .{
            .allocator = allocator,
            .id = id,
            .title = try allocator.dupe(u8, title),
            .cwd = try allocator.dupe(u8, cwd),
            .tags = std.array_list.Managed([]u8).init(allocator),
        };
    }

    pub fn cloneForSplit(self: Pane, id: PaneId, title: []const u8) !Pane {
        var pane = try Pane.init(self.allocator, id, title, self.cwd);
        errdefer pane.deinit();
        if (self.worktree_root) |root| try pane.setWorktreeRoot(root);
        _ = try pane.setProfile(self.profile);
        pane.status = .idle;
        for (self.tags.items) |tag| {
            try pane.addTag(tag);
        }
        return pane;
    }

    pub fn setCwd(self: *Pane, cwd: []const u8) !void {
        if (!std.fs.path.isAbsolute(cwd)) return error.InvalidPaneWorkingDirectory;
        const owned = try self.allocator.dupe(u8, cwd);
        self.allocator.free(self.cwd);
        self.cwd = owned;
    }

    pub fn addTag(self: *Pane, tag: []const u8) !void {
        const trimmed = std.mem.trim(u8, tag, " \t\r\n");
        if (trimmed.len == 0 or self.hasTag(trimmed)) return;
        try self.tags.append(try self.allocator.dupe(u8, trimmed));
    }

    pub fn hasTag(self: Pane, tag: []const u8) bool {
        for (self.tags.items) |candidate| {
            if (std.mem.eql(u8, candidate, tag)) return true;
        }
        return false;
    }

    pub fn removeTag(self: *Pane, tag: []const u8) bool {
        for (self.tags.items, 0..) |candidate, index| {
            if (std.mem.eql(u8, candidate, tag)) {
                self.allocator.free(candidate);
                _ = self.tags.orderedRemove(index);
                return true;
            }
        }
        return false;
    }

    pub fn setWorktreeRoot(self: *Pane, root_raw: ?[]const u8) !void {
        if (self.worktree_root) |old| {
            self.allocator.free(old);
            self.worktree_root = null;
        }
        const root = root_raw orelse return;
        const trimmed = std.mem.trim(u8, root, " \t\r\n");
        if (trimmed.len == 0) return;
        self.worktree_root = try self.allocator.dupe(u8, trimmed);
    }

    pub fn applyProfilePreset(self: *Pane, preset: ProfilePreset, config: Config.Config) !TerminalProfile {
        const profile = preset.profile(config);
        try profile.validate(config.font);
        return self.setProfile(profile);
    }

    pub fn setProfile(self: *Pane, profile: TerminalProfile) !TerminalProfile {
        const theme_name = try self.allocator.dupe(u8, profile.theme_name);
        errdefer self.allocator.free(theme_name);
        const font_family = try self.allocator.dupe(u8, profile.font_family);
        errdefer self.allocator.free(font_family);

        if (self.owned_profile_theme_name) |old| self.allocator.free(old);
        if (self.owned_profile_font_family) |old| self.allocator.free(old);
        self.owned_profile_theme_name = theme_name;
        self.owned_profile_font_family = font_family;
        self.profile = .{
            .theme_name = theme_name,
            .font_family = font_family,
            .font_size_pt = profile.font_size_pt,
            .ligatures = profile.ligatures,
        };
        return self.profile;
    }

    pub fn applyStatusEvent(self: *Pane, event: StatusEvent, long_running_minutes: u16) TerminalStatus {
        const threshold_ms = minutesToMs(long_running_minutes);
        switch (event) {
            .process_started => |at_ms| {
                self.process_started_at_ms = at_ms;
                self.last_activity_at_ms = at_ms;
                self.pending_since_ms = null;
                self.exit_code = null;
                self.status = .running;
            },
            .output_received => |at_ms| {
                if (self.process_started_at_ms == null) self.process_started_at_ms = at_ms;
                self.last_activity_at_ms = at_ms;
                self.pending_since_ms = null;
                self.exit_code = null;
                self.status = runningStatus(self.process_started_at_ms, at_ms, threshold_ms);
            },
            .waiting_for_input => |at_ms| {
                if (self.process_started_at_ms == null) self.process_started_at_ms = at_ms;
                self.last_activity_at_ms = at_ms;
                self.pending_since_ms = at_ms;
                self.exit_code = null;
                self.status = .pending_interaction;
            },
            .exited => |exit| {
                self.last_activity_at_ms = exit.at_ms;
                self.pending_since_ms = null;
                self.exit_code = exit.code;
                self.status = if (exit.code == 0) .done else .@"error";
            },
            .tick => |at_ms| {
                if (self.status == .running or self.status == .long_running) {
                    self.status = runningStatus(self.process_started_at_ms, at_ms, threshold_ms);
                }
            },
            .reset_idle => {
                self.process_started_at_ms = null;
                self.last_activity_at_ms = null;
                self.pending_since_ms = null;
                self.exit_code = null;
                self.status = .idle;
            },
        }
        return self.status;
    }

    pub fn deinit(self: *Pane) void {
        for (self.tags.items) |tag| self.allocator.free(tag);
        self.tags.deinit();
        if (self.worktree_root) |root| self.allocator.free(root);
        if (self.owned_profile_theme_name) |theme_name| self.allocator.free(theme_name);
        if (self.owned_profile_font_family) |font_family| self.allocator.free(font_family);
        self.allocator.free(self.title);
        self.allocator.free(self.cwd);
    }
};

pub fn statusColor(status: TerminalStatus) Theme.Color {
    return switch (status) {
        .idle => Theme.Color.rgb(0x58, 0x5b, 0x70),
        .running => Theme.Color.rgb(0xf9, 0xe2, 0xaf),
        .pending_interaction => Theme.Color.rgb(0xfa, 0xb3, 0x87),
        .done => Theme.Color.rgb(0xa6, 0xe3, 0xa1),
        .@"error" => Theme.Color.rgb(0xba, 0x1a, 0x1a),
        .long_running => Theme.Color.rgb(0xf3, 0xcd, 0x63),
    };
}

pub fn statusLabel(status: TerminalStatus) []const u8 {
    return switch (status) {
        .idle => "Idle",
        .running => "Running",
        .pending_interaction => "Pending input",
        .done => "Done",
        .@"error" => "Error",
        .long_running => "Long running",
    };
}

pub fn statusShortLabel(status: TerminalStatus) []const u8 {
    return switch (status) {
        .idle => "idle",
        .running => "run",
        .pending_interaction => "wait",
        .done => "done",
        .@"error" => "err",
        .long_running => "long",
    };
}

pub fn styleForStatus(status: TerminalStatus, indicator: Config.StatusIndicator) StatusStyle {
    return .{
        .indicator = indicator,
        .color = statusColor(status),
    };
}

pub fn isAttentionStatus(status: TerminalStatus) bool {
    return switch (status) {
        .pending_interaction, .@"error", .long_running => true,
        .idle, .running, .done => false,
    };
}

fn minutesToMs(minutes: u16) u64 {
    return @as(u64, minutes) * 60 * 1000;
}

fn runningStatus(started_at_ms: ?u64, at_ms: u64, threshold_ms: u64) TerminalStatus {
    if (started_at_ms) |started| {
        if (threshold_ms > 0 and at_ms >= started and at_ms - started >= threshold_ms) {
            return .long_running;
        }
    }
    return .running;
}

test "status colors separate agent states" {
    const done = statusColor(.done);
    const err = statusColor(.@"error");
    const pending = statusColor(.pending_interaction);
    try std.testing.expect(!std.meta.eql(done, err));
    try std.testing.expect(!std.meta.eql(pending, err));
    try std.testing.expect(isAttentionStatus(.pending_interaction));
    try std.testing.expect(!isAttentionStatus(.idle));
    try std.testing.expectEqualStrings("Pending input", statusLabel(.pending_interaction));
    try std.testing.expectEqualStrings("err", statusShortLabel(.@"error"));
}

test "profile presets derive validated per-terminal settings from config" {
    var cfg = Config.Config.defaults();
    cfg.font.family = "JetBrains Mono";
    cfg.font.size_pt = 12.0;
    cfg.default_theme = "workspace-dark";

    const compact = ProfilePreset.compact.profile(cfg);
    try compact.validate(cfg.font);
    try std.testing.expectEqualStrings("workspace-dark", compact.theme_name);
    try std.testing.expectEqualStrings("JetBrains Mono", compact.font_family);
    try std.testing.expectEqual(@as(f32, 9.0), compact.font_size_pt);

    const high_contrast = ProfilePreset.high_contrast.profile(cfg);
    try high_contrast.validate(cfg.font);
    try std.testing.expectEqualStrings("noctty-high-contrast", high_contrast.theme_name);

    const no_ligatures = ProfilePreset.mono_no_ligatures.profile(cfg);
    try std.testing.expect(!no_ligatures.ligatures);
}

test "pane applies profile presets without changing status state" {
    const allocator = std.testing.allocator;
    var pane = try Pane.init(allocator, 1, "agent", "/tmp");
    defer pane.deinit();
    pane.status = .running;

    const profile = try pane.applyProfilePreset(.readable, Config.Config.defaults());
    try std.testing.expectEqual(@as(f32, 14.0), profile.font_size_pt);
    try std.testing.expectEqual(TerminalStatus.running, pane.status);
}

test "split panes own copied profile strings" {
    const allocator = std.testing.allocator;
    var pane = try Pane.init(allocator, 1, "source", "/tmp");
    defer pane.deinit();

    try pane.setWorktreeRoot(" /tmp/worktree ");
    _ = try pane.applyProfilePreset(.high_contrast, Config.Config.defaults());
    var split = try pane.cloneForSplit(2, "split");
    defer split.deinit();

    try std.testing.expectEqualStrings("/tmp/worktree", split.worktree_root.?);
    try std.testing.expectEqualStrings("noctty-high-contrast", split.profile.theme_name);
    try std.testing.expect(split.profile.theme_name.ptr != pane.profile.theme_name.ptr);
    try std.testing.expect(split.profile.font_family.ptr != pane.profile.font_family.ptr);
}

test "status events detect running pending completion and long running states" {
    const allocator = std.testing.allocator;
    var pane = try Pane.init(allocator, 1, "agent", "/tmp");
    defer pane.deinit();

    try std.testing.expectEqual(TerminalStatus.running, pane.applyStatusEvent(.{ .process_started = 0 }, 20));
    try std.testing.expectEqual(TerminalStatus.pending_interaction, pane.applyStatusEvent(.{ .waiting_for_input = 1000 }, 20));
    try std.testing.expectEqual(TerminalStatus.running, pane.applyStatusEvent(.{ .output_received = 2000 }, 20));
    try std.testing.expectEqual(TerminalStatus.long_running, pane.applyStatusEvent(.{ .tick = 20 * 60 * 1000 }, 20));
    try std.testing.expectEqual(TerminalStatus.@"error", pane.applyStatusEvent(.{ .exited = .{ .code = 2, .at_ms = 20 * 60 * 1000 + 1 } }, 20));
    try std.testing.expectEqual(@as(?u8, 2), pane.exit_code);
    try std.testing.expectEqual(TerminalStatus.idle, pane.applyStatusEvent(.reset_idle, 20));
    try std.testing.expectEqual(@as(?u8, null), pane.exit_code);
}

test "successful exit maps to done without long-running promotion" {
    const allocator = std.testing.allocator;
    var pane = try Pane.init(allocator, 1, "build", "/tmp");
    defer pane.deinit();

    _ = pane.applyStatusEvent(.{ .process_started = 50 }, 1);
    try std.testing.expectEqual(TerminalStatus.done, pane.applyStatusEvent(.{ .exited = .{ .code = 0, .at_ms = 55 } }, 1));
    try std.testing.expectEqual(@as(?u8, 0), pane.exit_code);
}

test "output can establish start time when process start event was missed" {
    const allocator = std.testing.allocator;
    var pane = try Pane.init(allocator, 1, "stream", "/tmp");
    defer pane.deinit();

    try std.testing.expectEqual(TerminalStatus.running, pane.applyStatusEvent(.{ .output_received = 100 }, 1));
    try std.testing.expectEqual(@as(?u64, 100), pane.process_started_at_ms);
    try std.testing.expectEqual(TerminalStatus.long_running, pane.applyStatusEvent(.{ .tick = 60 * 1000 + 100 }, 1));
}
