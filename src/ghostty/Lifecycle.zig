const std = @import("std");
const Compat = @import("compat");
const Api = @import("Api.zig");

pub const SurfaceOptions = struct {
    working_directory: []const u8 = ".",
    command: ?[]const u8 = null,
    initial_input: ?[]const u8 = null,
    font_size: f32 = 11.0,
    scale_factor: f64 = 1.0,
    width_px: u32 = 1280,
    height_px: u32 = 720,
    context: Api.SurfaceContext = .window,
};

pub const KeyInput = struct {
    action: Api.InputAction = .press,
    mods: c_int = 0,
    keycode: u32 = 0,
    text: ?[]const u8 = null,
    unshifted_codepoint: u32 = 0,
    composing: bool = false,
};

pub const MouseInput = union(enum) {
    button: Button,
    position: Position,
    scroll: Scroll,

    pub const Button = struct {
        state: Api.MouseState,
        button: Api.MouseButton,
        mods: c_int = 0,
    };

    pub const Position = struct {
        x: f64,
        y: f64,
        mods: c_int = 0,
    };

    pub const Scroll = struct {
        x: f64,
        y: f64,
        mods: c_int = 0,
    };
};

pub const Session = struct {
    allocator: std.mem.Allocator,
    symbols: Api.Symbols,
    config: Api.ghostty_config_t = null,
    app: Api.ghostty_app_t = null,
    surface: Api.ghostty_surface_t = null,
    runtime_config: Api.RuntimeConfig = .{},
    cwd_z: ?[:0]u8 = null,
    command_z: ?[:0]u8 = null,
    initial_input_z: ?[:0]u8 = null,
    key_text_z: ?[:0]u8 = null,

    pub fn create(allocator: std.mem.Allocator, symbols: Api.Symbols, options: SurfaceOptions) !Session {
        if (!symbols.lifecycleComplete()) return error.GhosttySymbolsIncomplete;

        var session = Session{
            .allocator = allocator,
            .symbols = symbols,
            .runtime_config = .{},
        };
        errdefer session.deinit();

        session.cwd_z = try Compat.dupeZ(allocator, options.working_directory);
        if (options.command) |command| session.command_z = try Compat.dupeZ(allocator, command);
        if (options.initial_input) |initial_input| session.initial_input_z = try Compat.dupeZ(allocator, initial_input);

        session.config = symbols.config_new.?() orelse return error.GhosttyConfigCreateFailed;
        if (symbols.config_finalize) |finalize| finalize(session.config);

        session.app = symbols.app_new.?(&session.runtime_config, session.config) orelse return error.GhosttyAppCreateFailed;

        var surface_config = symbols.surface_config_new.?();
        surface_config.platform_tag = .invalid;
        surface_config.working_directory = session.cwd_z.?.ptr;
        surface_config.command = if (session.command_z) |command| command.ptr else null;
        surface_config.initial_input = if (session.initial_input_z) |input| input.ptr else null;
        surface_config.font_size = options.font_size;
        surface_config.scale_factor = options.scale_factor;
        surface_config.context = options.context;

        session.surface = symbols.surface_new.?(session.app, &surface_config) orelse return error.GhosttySurfaceCreateFailed;
        symbols.surface_set_size.?(session.surface, options.width_px, options.height_px);
        return session;
    }

    pub fn deinit(self: *Session) void {
        if (self.surface) |surface| {
            if (self.symbols.surface_free) |surface_free| surface_free(surface);
            self.surface = null;
        }
        if (self.app) |app| {
            if (self.symbols.app_free) |app_free| app_free(app);
            self.app = null;
        }
        if (self.config) |config| {
            if (self.symbols.config_free) |config_free| config_free(config);
            self.config = null;
        }
        if (self.key_text_z) |text| {
            self.allocator.free(text);
            self.key_text_z = null;
        }
        if (self.initial_input_z) |input| {
            self.allocator.free(input);
            self.initial_input_z = null;
        }
        if (self.command_z) |command| {
            self.allocator.free(command);
            self.command_z = null;
        }
        if (self.cwd_z) |cwd| {
            self.allocator.free(cwd);
            self.cwd_z = null;
        }
    }

    pub fn tick(self: *Session) void {
        self.symbols.app_tick.?(self.app);
    }

    pub fn refresh(self: *Session) void {
        if (self.symbols.surface_refresh) |surface_refresh| {
            surface_refresh(self.surface);
        }
    }

    pub fn draw(self: *Session) void {
        self.symbols.surface_draw.?(self.surface);
    }

    pub fn resize(self: *Session, width_px: u32, height_px: u32) void {
        self.symbols.surface_set_size.?(self.surface, width_px, height_px);
    }

    pub fn setFocus(self: *Session, focused: bool) void {
        if (self.symbols.app_set_focus) |app_set_focus| app_set_focus(self.app, focused);
        if (self.symbols.surface_set_focus) |surface_set_focus| surface_set_focus(self.surface, focused);
    }

    pub fn setOcclusion(self: *Session, occluded: bool) void {
        if (self.symbols.surface_set_occlusion) |surface_set_occlusion| {
            surface_set_occlusion(self.surface, occluded);
        }
    }

    pub fn sendText(self: *Session, text: []const u8) void {
        if (text.len == 0) return;
        self.symbols.surface_text.?(self.surface, text.ptr, text.len);
    }

    pub fn sendPreedit(self: *Session, text: []const u8) void {
        const surface_preedit = self.symbols.surface_preedit orelse return;
        surface_preedit(self.surface, text.ptr, text.len);
    }

    pub fn sendKey(self: *Session, input: KeyInput) !bool {
        const surface_key = self.symbols.surface_key orelse return error.GhosttyKeyInputUnavailable;
        if (self.key_text_z) |text| {
            self.allocator.free(text);
            self.key_text_z = null;
        }
        if (input.text) |text| self.key_text_z = try Compat.dupeZ(self.allocator, text);
        return surface_key(self.surface, .{
            .action = input.action,
            .mods = input.mods,
            .consumed_mods = 0,
            .keycode = input.keycode,
            .text = if (self.key_text_z) |text| text.ptr else null,
            .unshifted_codepoint = input.unshifted_codepoint,
            .composing = input.composing,
        });
    }

    pub fn sendMouse(self: *Session, input: MouseInput) !bool {
        switch (input) {
            .button => |button| {
                const surface_mouse_button = self.symbols.surface_mouse_button orelse return error.GhosttyMouseInputUnavailable;
                return surface_mouse_button(self.surface, button.state, button.button, button.mods);
            },
            .position => |position| {
                const surface_mouse_pos = self.symbols.surface_mouse_pos orelse return error.GhosttyMouseInputUnavailable;
                surface_mouse_pos(self.surface, position.x, position.y, position.mods);
                return true;
            },
            .scroll => |scroll| {
                const surface_mouse_scroll = self.symbols.surface_mouse_scroll orelse return error.GhosttyMouseInputUnavailable;
                surface_mouse_scroll(self.surface, scroll.x, scroll.y, scroll.mods);
                return true;
            },
        }
    }

    pub fn processExited(self: *Session) ?bool {
        const surface_process_exited = self.symbols.surface_process_exited orelse return null;
        return surface_process_exited(self.surface);
    }
};

test "session lifecycle routes through ghostty symbols" {
    const allocator = std.testing.allocator;
    fake = .{};

    var session = try Session.create(allocator, fakeSymbols(), .{
        .working_directory = "/tmp/deetty",
        .command = "/bin/bash",
        .initial_input = "echo ready",
        .width_px = 900,
        .height_px = 540,
    });
    defer session.deinit();

    session.tick();
    session.refresh();
    session.draw();
    session.resize(1200, 700);
    session.setFocus(true);
    session.setOcclusion(false);
    session.sendText("hello");
    try std.testing.expect(try session.sendKey(.{ .keycode = 42, .text = "x" }));
    try std.testing.expect(try session.sendMouse(.{ .button = .{ .state = .press, .button = .left } }));
    try std.testing.expect(try session.sendMouse(.{ .position = .{ .x = 10, .y = 20 } }));
    try std.testing.expect(try session.sendMouse(.{ .scroll = .{ .x = 0, .y = -1 } }));
    try std.testing.expectEqual(false, session.processExited().?);

    try std.testing.expectEqual(@as(usize, 1), fake.config_new);
    try std.testing.expectEqual(@as(usize, 1), fake.app_new);
    try std.testing.expectEqual(@as(usize, 1), fake.surface_new);
    try std.testing.expectEqual(@as(usize, 2), fake.set_size);
    try std.testing.expectEqual(@as(usize, 1), fake.text);
    try std.testing.expectEqual(@as(usize, 1), fake.key);
    try std.testing.expectEqual(@as(usize, 1), fake.mouse_button);
    try std.testing.expectEqual(@as(usize, 1), fake.mouse_pos);
    try std.testing.expectEqual(@as(usize, 1), fake.mouse_scroll);
}

test "session refuses incomplete symbol table" {
    try std.testing.expectError(error.GhosttySymbolsIncomplete, Session.create(std.testing.allocator, .{}, .{}));
}

const Fake = struct {
    config_new: usize = 0,
    app_new: usize = 0,
    surface_new: usize = 0,
    config_finalize: usize = 0,
    config_free: usize = 0,
    app_free: usize = 0,
    surface_free: usize = 0,
    tick: usize = 0,
    refresh: usize = 0,
    draw: usize = 0,
    set_size: usize = 0,
    focus: usize = 0,
    occlusion: usize = 0,
    text: usize = 0,
    key: usize = 0,
    mouse_button: usize = 0,
    mouse_pos: usize = 0,
    mouse_scroll: usize = 0,
};

var fake: Fake = .{};
var config_storage: u8 = 0;
var app_storage: u8 = 0;
var surface_storage: u8 = 0;

fn fakeSymbols() Api.Symbols {
    return .{
        .config_new = fakeConfigNew,
        .config_free = fakeConfigFree,
        .config_finalize = fakeConfigFinalize,
        .app_new = fakeAppNew,
        .app_free = fakeAppFree,
        .app_tick = fakeAppTick,
        .app_set_focus = fakeAppSetFocus,
        .surface_config_new = fakeSurfaceConfigNew,
        .surface_new = fakeSurfaceNew,
        .surface_free = fakeSurfaceFree,
        .surface_refresh = fakeSurfaceRefresh,
        .surface_draw = fakeSurfaceDraw,
        .surface_set_focus = fakeSurfaceSetFocus,
        .surface_set_occlusion = fakeSurfaceSetOcclusion,
        .surface_set_size = fakeSurfaceSetSize,
        .surface_size = fakeSurfaceSize,
        .surface_key = fakeSurfaceKey,
        .surface_text = fakeSurfaceText,
        .surface_preedit = fakeSurfaceText,
        .surface_mouse_button = fakeSurfaceMouseButton,
        .surface_mouse_pos = fakeSurfaceMousePos,
        .surface_mouse_scroll = fakeSurfaceMouseScroll,
        .surface_process_exited = fakeSurfaceProcessExited,
    };
}

fn fakeConfigNew() callconv(.c) Api.ghostty_config_t {
    fake.config_new += 1;
    return @ptrCast(&config_storage);
}

fn fakeConfigFree(_: Api.ghostty_config_t) callconv(.c) void {
    fake.config_free += 1;
}

fn fakeConfigFinalize(_: Api.ghostty_config_t) callconv(.c) void {
    fake.config_finalize += 1;
}

fn fakeAppNew(_: *const Api.RuntimeConfig, _: Api.ghostty_config_t) callconv(.c) Api.ghostty_app_t {
    fake.app_new += 1;
    return @ptrCast(&app_storage);
}

fn fakeAppFree(_: Api.ghostty_app_t) callconv(.c) void {
    fake.app_free += 1;
}

fn fakeAppTick(_: Api.ghostty_app_t) callconv(.c) void {
    fake.tick += 1;
}

fn fakeAppSetFocus(_: Api.ghostty_app_t, _: bool) callconv(.c) void {
    fake.focus += 1;
}

fn fakeSurfaceConfigNew() callconv(.c) Api.SurfaceConfig {
    return .{};
}

fn fakeSurfaceNew(_: Api.ghostty_app_t, config: *const Api.SurfaceConfig) callconv(.c) Api.ghostty_surface_t {
    fake.surface_new += 1;
    std.debug.assert(config.platform_tag == .invalid);
    return @ptrCast(&surface_storage);
}

fn fakeSurfaceFree(_: Api.ghostty_surface_t) callconv(.c) void {
    fake.surface_free += 1;
}

fn fakeSurfaceRefresh(_: Api.ghostty_surface_t) callconv(.c) void {
    fake.refresh += 1;
}

fn fakeSurfaceDraw(_: Api.ghostty_surface_t) callconv(.c) void {
    fake.draw += 1;
}

fn fakeSurfaceSetFocus(_: Api.ghostty_surface_t, _: bool) callconv(.c) void {
    fake.focus += 1;
}

fn fakeSurfaceSetOcclusion(_: Api.ghostty_surface_t, _: bool) callconv(.c) void {
    fake.occlusion += 1;
}

fn fakeSurfaceSetSize(_: Api.ghostty_surface_t, _: u32, _: u32) callconv(.c) void {
    fake.set_size += 1;
}

fn fakeSurfaceSize(_: Api.ghostty_surface_t) callconv(.c) Api.SurfaceSize {
    return .{
        .columns = 90,
        .rows = 30,
        .width_px = 900,
        .height_px = 540,
        .cell_width_px = 10,
        .cell_height_px = 18,
    };
}

fn fakeSurfaceText(_: Api.ghostty_surface_t, _: [*]const u8, _: usize) callconv(.c) void {
    fake.text += 1;
}

fn fakeSurfaceKey(_: Api.ghostty_surface_t, input: Api.InputKey) callconv(.c) bool {
    fake.key += 1;
    return input.keycode == 42;
}

fn fakeSurfaceMouseButton(_: Api.ghostty_surface_t, _: Api.MouseState, _: Api.MouseButton, _: c_int) callconv(.c) bool {
    fake.mouse_button += 1;
    return true;
}

fn fakeSurfaceMousePos(_: Api.ghostty_surface_t, _: f64, _: f64, _: c_int) callconv(.c) void {
    fake.mouse_pos += 1;
}

fn fakeSurfaceMouseScroll(_: Api.ghostty_surface_t, _: f64, _: f64, _: c_int) callconv(.c) void {
    fake.mouse_scroll += 1;
}

fn fakeSurfaceProcessExited(_: Api.ghostty_surface_t) callconv(.c) bool {
    return false;
}
