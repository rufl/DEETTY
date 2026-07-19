const std = @import("std");

pub const BackendKind = enum {
    plasma_wayland,
    noctalia_wayland,
    wayland,
    x11,
    portable_test,
};

pub const DesktopShell = enum {
    plasma,
    noctalia,
    other,
};

pub const WaylandCompositor = enum {
    none,
    niri,
    hyprland,
    sway,
    scroll,
    labwc,
    mango,
    other,

    pub fn isNoctaliaSupported(self: WaylandCompositor) bool {
        return switch (self) {
            .niri, .hyprland, .sway, .scroll, .labwc, .mango => true,
            .none, .other => false,
        };
    }
};

pub const Capabilities = struct {
    wayland: bool,
    x11: bool,
    hidpi: bool,
    global_shortcuts: bool,
    app_shortcut_registration: bool,
    external_activation: bool,
    desktop_notifications: bool,
    layer_shell: bool,
    drag_and_drop: bool,
};

pub const WindowChrome = struct {
    main_titlebar_px: u16 = 0,
    terminal_titlebar_px: u16 = 0,
    client_side_decorations: bool = false,
};

pub const Descriptor = struct {
    kind: BackendKind,
    shell: DesktopShell,
    compositor: WaylandCompositor = .none,
    capabilities: Capabilities,
    chrome: WindowChrome = .{},

    pub fn preferredForLinux() Descriptor {
        return .{
            .kind = .plasma_wayland,
            .shell = .plasma,
            .compositor = .other,
            .capabilities = .{
                .wayland = true,
                .x11 = true,
                .hidpi = true,
                .global_shortcuts = true,
                .app_shortcut_registration = true,
                .external_activation = true,
                .desktop_notifications = true,
                .layer_shell = true,
                .drag_and_drop = true,
            },
        };
    }

    pub fn noctaliaFor(compositor: WaylandCompositor) Descriptor {
        return .{
            .kind = .noctalia_wayland,
            .shell = .noctalia,
            .compositor = compositor,
            .capabilities = .{
                .wayland = true,
                .x11 = false,
                .hidpi = true,
                .global_shortcuts = true,
                .app_shortcut_registration = false,
                .external_activation = true,
                .desktop_notifications = true,
                .layer_shell = true,
                .drag_and_drop = true,
            },
        };
    }

    pub fn genericWayland(compositor: WaylandCompositor) Descriptor {
        var descriptor = noctaliaFor(compositor);
        descriptor.kind = .wayland;
        descriptor.shell = .other;
        descriptor.capabilities.global_shortcuts = false;
        return descriptor;
    }
};

test "preferred backend is plasma-compatible and titlebar-free" {
    const backend = Descriptor.preferredForLinux();
    try std.testing.expectEqual(BackendKind.plasma_wayland, backend.kind);
    try std.testing.expect(backend.capabilities.wayland);
    try std.testing.expect(backend.capabilities.x11);
    try std.testing.expect(backend.capabilities.desktop_notifications);
    try std.testing.expect(backend.capabilities.app_shortcut_registration);
    try std.testing.expectEqual(@as(u16, 0), backend.chrome.main_titlebar_px);
    try std.testing.expectEqual(@as(u16, 0), backend.chrome.terminal_titlebar_px);
}

test "Noctalia backend covers every supported compositor without KDE coupling" {
    inline for (.{
        WaylandCompositor.niri,
        WaylandCompositor.hyprland,
        WaylandCompositor.sway,
        WaylandCompositor.scroll,
        WaylandCompositor.labwc,
        WaylandCompositor.mango,
    }) |compositor| {
        const backend = Descriptor.noctaliaFor(compositor);
        try std.testing.expectEqual(BackendKind.noctalia_wayland, backend.kind);
        try std.testing.expectEqual(DesktopShell.noctalia, backend.shell);
        try std.testing.expect(backend.capabilities.layer_shell);
        try std.testing.expect(backend.capabilities.external_activation);
        try std.testing.expect(backend.capabilities.desktop_notifications);
        try std.testing.expect(!backend.capabilities.app_shortcut_registration);
    }
}
