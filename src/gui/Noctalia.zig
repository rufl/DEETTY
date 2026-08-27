const std = @import("std");
const Backend = @import("Backend.zig");
const Config = @import("../config/Config.zig");

pub const ShellVersion = enum { unknown, v4, v5 };

pub const Environment = struct {
    wayland_display: ?[]const u8 = null,
    current_desktop: ?[]const u8 = null,
    session_desktop: ?[]const u8 = null,
    compositor_override: ?[]const u8 = null,
    shell_override: ?[]const u8 = null,
    noctalia_version: ?[]const u8 = null,
    niri_socket: ?[]const u8 = null,
    hyprland_instance_signature: ?[]const u8 = null,
    sway_socket: ?[]const u8 = null,
    labwc_pid: ?[]const u8 = null,
    mango_socket: ?[]const u8 = null,
};

pub const Detection = struct {
    active: bool,
    version: ShellVersion,
    compositor: Backend.WaylandCompositor,

    pub fn supported(self: Detection) bool {
        return self.active and self.compositor.isNoctaliaSupported();
    }
};

pub fn detect(env: Environment) Detection {
    const compositor = detectCompositor(env);
    const explicitly_noctalia = containsIgnoreCase(env.shell_override, "noctalia") or
        containsIgnoreCase(env.current_desktop, "noctalia") or
        containsIgnoreCase(env.session_desktop, "noctalia");
    return .{
        .active = env.wayland_display != null and
            (explicitly_noctalia or compositor.isNoctaliaSupported()),
        .version = detectVersion(env),
        .compositor = compositor,
    };
}

pub fn detectCompositor(env: Environment) Backend.WaylandCompositor {
    if (env.compositor_override) |value| {
        if (parseCompositor(value)) |compositor| return compositor;
    }
    if (env.niri_socket != null) return .niri;
    if (env.hyprland_instance_signature != null) return .hyprland;
    if (containsIgnoreCase(env.current_desktop, "scroll") or
        containsIgnoreCase(env.session_desktop, "scroll")) return .scroll;
    if (env.sway_socket != null) return .sway;
    if (env.labwc_pid != null or containsIgnoreCase(env.current_desktop, "labwc") or
        containsIgnoreCase(env.session_desktop, "labwc")) return .labwc;
    if (env.mango_socket != null or containsIgnoreCase(env.current_desktop, "mango") or
        containsIgnoreCase(env.session_desktop, "mango")) return .mango;
    if (containsIgnoreCase(env.current_desktop, "niri") or
        containsIgnoreCase(env.session_desktop, "niri")) return .niri;
    if (containsIgnoreCase(env.current_desktop, "hyprland") or
        containsIgnoreCase(env.session_desktop, "hyprland")) return .hyprland;
    if (containsIgnoreCase(env.current_desktop, "sway") or
        containsIgnoreCase(env.session_desktop, "sway")) return .sway;
    return .other;
}

pub fn parseCompositor(value: []const u8) ?Backend.WaylandCompositor {
    if (std.ascii.eqlIgnoreCase(value, "niri")) return .niri;
    if (std.ascii.eqlIgnoreCase(value, "hyprland")) return .hyprland;
    if (std.ascii.eqlIgnoreCase(value, "sway")) return .sway;
    if (std.ascii.eqlIgnoreCase(value, "scroll")) return .scroll;
    if (std.ascii.eqlIgnoreCase(value, "labwc")) return .labwc;
    if (std.ascii.eqlIgnoreCase(value, "mango") or
        std.ascii.eqlIgnoreCase(value, "mangowc") or
        std.ascii.eqlIgnoreCase(value, "mangowm")) return .mango;
    return null;
}

pub fn writeBinding(writer: anytype, compositor: Backend.WaylandCompositor, shortcut: Config.Shortcut) !void {
    try shortcut.validateGlobal();
    switch (compositor) {
        .niri => {
            try writeHotkey(writer, shortcut, .standard);
            try writer.writeAll(" { spawn \"noctty\" \"--toggle\"; }");
        },
        .hyprland => {
            try writer.writeAll("hl.bind(\"");
            try writeHotkey(writer, shortcut, .standard);
            try writer.writeAll("\", hl.dsp.exec_cmd(\"noctty --toggle\"))");
        },
        .sway, .scroll => {
            try writer.writeAll("bindsym ");
            try writeHotkey(writer, shortcut, .standard);
            try writer.writeAll(" exec noctty --toggle");
        },
        .labwc => {
            try writer.writeAll("<keybind key=\"");
            try writeHotkey(writer, shortcut, .labwc);
            try writer.writeAll("\"><action name=\"Execute\"><command>noctty --toggle</command></action></keybind>");
        },
        .mango => {
            try writer.writeAll("bind=");
            try writeMangoModifiers(writer, shortcut);
            try writer.writeAll(",");
            try writer.writeAll(xkbKeyName(shortcut.key));
            try writer.writeAll(",spawn,noctty --toggle");
        },
        .none, .other => return error.UnsupportedNoctaliaCompositor,
    }
}

pub fn writeBindingForVersion(writer: anytype, compositor: Backend.WaylandCompositor, shortcut: Config.Shortcut, version: ShellVersion) !void {
    if (compositor != .hyprland or version != .v4)
        return writeBinding(writer, compositor, shortcut);
    try shortcut.validateGlobal();
    try writer.writeAll("bind = ");
    try writeHyprlandConfModifiers(writer, shortcut);
    try writer.writeAll(", ");
    try writer.writeAll(xkbKeyName(shortcut.key));
    try writer.writeAll(", exec, noctty --toggle");
}

pub fn writeAutostart(writer: anytype, compositor: Backend.WaylandCompositor) !void {
    switch (compositor) {
        .niri => try writer.writeAll("spawn-at-startup \"noctty\" \"--hidden\""),
        .hyprland => try writer.writeAll("hl.on(\"hyprland.start\", function() hl.exec_cmd(\"noctty --hidden\") end)"),
        .sway, .scroll => try writer.writeAll("exec noctty --hidden"),
        .labwc => try writer.writeAll("noctty --hidden"),
        .mango => try writer.writeAll("exec-once=noctty --hidden"),
        .none, .other => return error.UnsupportedNoctaliaCompositor,
    }
}

pub fn writeAutostartForVersion(writer: anytype, compositor: Backend.WaylandCompositor, version: ShellVersion) !void {
    if (compositor == .hyprland and version == .v4) {
        try writer.writeAll("exec-once = noctty --hidden");
        return;
    }
    try writeAutostart(writer, compositor);
}

pub fn writePlan(writer: anytype, detection: Detection, shortcut: Config.Shortcut) !void {
    try writer.print("noctalia active={} supported={} version={s} compositor={s}\n", .{
        detection.active,
        detection.supported(),
        @tagName(detection.version),
        @tagName(detection.compositor),
    });
    try writer.writeAll("activation=dbus command=noctty --toggle service=com.noctty.NOCTTY\n");
    try writer.writeAll("surface=toplevel app_id=com.noctty.NOCTTY title_prefix=NOCTTY_Dropdown notifications=org.freedesktop.Notifications\n");
    if (!detection.compositor.isNoctaliaSupported()) {
        try writer.writeAll("binding=unavailable\nautostart=unavailable\n");
        return;
    }
    try writer.writeAll("binding=");
    try writeBindingForVersion(writer, detection.compositor, shortcut, detection.version);
    try writer.writeAll("\nautostart=");
    try writeAutostartForVersion(writer, detection.compositor, detection.version);
    try writer.writeAll("\n");
}

const HotkeyStyle = enum { standard, labwc };

fn writeHotkey(writer: anytype, shortcut: Config.Shortcut, style: HotkeyStyle) !void {
    if (style == .labwc) {
        if (shortcut.ctrl) try writer.writeAll("C-");
        if (shortcut.shift) try writer.writeAll("S-");
        if (shortcut.alt) try writer.writeAll("A-");
        if (shortcut.super) try writer.writeAll("W-");
    } else {
        var needs_separator = false;
        if (shortcut.ctrl) {
            try writer.writeAll("Ctrl");
            needs_separator = true;
        }
        if (shortcut.shift) {
            if (needs_separator) try writer.writeAll("+");
            try writer.writeAll("Shift");
            needs_separator = true;
        }
        if (shortcut.alt) {
            if (needs_separator) try writer.writeAll("+");
            try writer.writeAll("Alt");
            needs_separator = true;
        }
        if (shortcut.super) {
            if (needs_separator) try writer.writeAll("+");
            try writer.writeAll("Super");
            needs_separator = true;
        }
        if (needs_separator) try writer.writeAll("+");
    }
    try writer.writeAll(xkbKeyName(shortcut.key));
}

fn writeMangoModifiers(writer: anytype, shortcut: Config.Shortcut) !void {
    var wrote = false;
    if (shortcut.ctrl) {
        try writer.writeAll("CTRL");
        wrote = true;
    }
    if (shortcut.shift) {
        if (wrote) try writer.writeAll("+");
        try writer.writeAll("SHIFT");
        wrote = true;
    }
    if (shortcut.alt) {
        if (wrote) try writer.writeAll("+");
        try writer.writeAll("ALT");
        wrote = true;
    }
    if (shortcut.super) {
        if (wrote) try writer.writeAll("+");
        try writer.writeAll("SUPER");
        wrote = true;
    }
    if (!wrote) try writer.writeAll("NONE");
}

fn writeHyprlandConfModifiers(writer: anytype, shortcut: Config.Shortcut) !void {
    var wrote = false;
    if (shortcut.ctrl) {
        try writer.writeAll("CTRL");
        wrote = true;
    }
    if (shortcut.shift) {
        if (wrote) try writer.writeAll(" SHIFT");
        if (!wrote) try writer.writeAll("SHIFT");
        wrote = true;
    }
    if (shortcut.alt) {
        if (wrote) try writer.writeAll(" ALT");
        if (!wrote) try writer.writeAll("ALT");
        wrote = true;
    }
    if (shortcut.super) {
        if (wrote) try writer.writeAll(" SUPER");
        if (!wrote) try writer.writeAll("SUPER");
    }
}

fn xkbKeyName(key: Config.Shortcut.Key) []const u8 {
    return switch (key) {
        .escape => "Escape",
        .enter => "Return",
        .page_up => "Page_Up",
        .page_down => "Page_Down",
        .arrow_left => "Left",
        .arrow_right => "Right",
        .arrow_up => "Up",
        .arrow_down => "Down",
        else => key.label(),
    };
}

fn detectVersion(env: Environment) ShellVersion {
    if (env.noctalia_version) |value| {
        if (value.len > 0 and value[0] == '4') return .v4;
        if (value.len > 0 and value[0] == '5') return .v5;
        if (containsIgnoreCase(value, "v4")) return .v4;
        if (containsIgnoreCase(value, "v5")) return .v5;
    }
    return .unknown;
}

fn containsIgnoreCase(value: ?[]const u8, needle: []const u8) bool {
    const haystack = value orelse return false;
    if (needle.len > haystack.len) return false;
    var index: usize = 0;
    while (index + needle.len <= haystack.len) : (index += 1) {
        if (std.ascii.eqlIgnoreCase(haystack[index .. index + needle.len], needle)) return true;
    }
    return false;
}

test "detects every compositor family supported by Noctalia" {
    try std.testing.expectEqual(Backend.WaylandCompositor.niri, detect(.{
        .wayland_display = "wayland-1",
        .niri_socket = "/run/user/1000/niri.sock",
    }).compositor);
    try std.testing.expectEqual(Backend.WaylandCompositor.hyprland, detect(.{
        .wayland_display = "wayland-1",
        .hyprland_instance_signature = "instance",
    }).compositor);
    try std.testing.expectEqual(Backend.WaylandCompositor.scroll, detect(.{
        .wayland_display = "wayland-1",
        .current_desktop = "scroll",
        .sway_socket = "/run/user/1000/scroll.sock",
    }).compositor);
    try std.testing.expectEqual(Backend.WaylandCompositor.labwc, detect(.{
        .wayland_display = "wayland-1",
        .current_desktop = "labwc",
    }).compositor);
    try std.testing.expectEqual(Backend.WaylandCompositor.mango, detect(.{
        .wayland_display = "wayland-1",
        .current_desktop = "MangoWC",
    }).compositor);
}

test "renders compositor-owned F10 bindings and hidden autostart" {
    const expected = .{
        .{ Backend.WaylandCompositor.niri, "F10 { spawn \"noctty\" \"--toggle\"; }", "spawn-at-startup \"noctty\" \"--hidden\"" },
        .{ Backend.WaylandCompositor.hyprland, "hl.bind(\"F10\", hl.dsp.exec_cmd(\"noctty --toggle\"))", "hl.on(\"hyprland.start\", function() hl.exec_cmd(\"noctty --hidden\") end)" },
        .{ Backend.WaylandCompositor.sway, "bindsym F10 exec noctty --toggle", "exec noctty --hidden" },
        .{ Backend.WaylandCompositor.scroll, "bindsym F10 exec noctty --toggle", "exec noctty --hidden" },
        .{ Backend.WaylandCompositor.labwc, "<keybind key=\"F10\"><action name=\"Execute\"><command>noctty --toggle</command></action></keybind>", "noctty --hidden" },
        .{ Backend.WaylandCompositor.mango, "bind=NONE,F10,spawn,noctty --toggle", "exec-once=noctty --hidden" },
    };
    inline for (expected) |row| {
        var binding_buf: [256]u8 = undefined;
        var binding_writer = std.Io.Writer.fixed(&binding_buf);
        try writeBinding(&binding_writer, row[0], .{});
        try std.testing.expectEqualStrings(row[1], binding_writer.buffered());

        var autostart_buf: [256]u8 = undefined;
        var autostart_writer = std.Io.Writer.fixed(&autostart_buf);
        try writeAutostart(&autostart_writer, row[0]);
        try std.testing.expectEqualStrings(row[2], autostart_writer.buffered());
    }
}

test "binding format follows a recorded modifier chord" {
    var buf: [256]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);
    try writeBinding(&writer, .mango, .{ .key = .home, .ctrl = true, .shift = true });
    try std.testing.expectEqualStrings("bind=CTRL+SHIFT,Home,spawn,noctty --toggle", writer.buffered());
}

test "Noctalia v4 plan keeps Hyprland conf syntax" {
    var buf: [256]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);
    try writeBindingForVersion(&writer, .hyprland, .{}, .v4);
    try std.testing.expectEqualStrings("bind = , F10, exec, noctty --toggle", writer.buffered());

    var autostart_buf: [128]u8 = undefined;
    var autostart_writer = std.Io.Writer.fixed(&autostart_buf);
    try writeAutostartForVersion(&autostart_writer, .hyprland, .v4);
    try std.testing.expectEqualStrings("exec-once = noctty --hidden", autostart_writer.buffered());
}
