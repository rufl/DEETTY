const std = @import("std");

pub const ghostty_app_t = ?*anyopaque;
pub const ghostty_config_t = ?*anyopaque;
pub const ghostty_surface_t = ?*anyopaque;

pub const Platform = enum(c_int) {
    invalid = 0,
    macos = 1,
    ios = 2,
};

pub const SurfaceContext = enum(c_int) {
    window = 0,
    tab = 1,
    split = 2,
};

pub const RuntimeConfig = extern struct {
    userdata: ?*anyopaque = null,
    supports_selection_clipboard: bool = true,
    wakeup_cb: ?*const fn (?*anyopaque) callconv(.c) void = null,
    action_cb: ?*const fn (ghostty_app_t, Target, Action) callconv(.c) bool = null,
    read_clipboard_cb: ?*const fn (?*anyopaque, c_int, ?*anyopaque) callconv(.c) bool = null,
    confirm_read_clipboard_cb: ?*const fn (?*anyopaque, [*:0]const u8, ?*anyopaque, c_int) callconv(.c) void = null,
    write_clipboard_cb: ?*const fn (?*anyopaque, c_int, ?*const anyopaque, usize, bool) callconv(.c) void = null,
    close_surface_cb: ?*const fn (?*anyopaque, bool) callconv(.c) void = null,
};

pub const Target = extern struct {
    tag: c_int = 0,
    surface: ghostty_surface_t = null,
};

pub const Action = extern struct {
    tag: c_int = 0,
    payload: [128]u8 = @splat(0),
};

pub const SurfaceConfig = extern struct {
    platform_tag: Platform = .invalid,
    platform: PlatformUnion = .{ .ptr = null },
    userdata: ?*anyopaque = null,
    scale_factor: f64 = 1.0,
    font_size: f32 = 11.0,
    working_directory: ?[*:0]const u8 = null,
    command: ?[*:0]const u8 = null,
    env_vars: ?*anyopaque = null,
    env_var_count: usize = 0,
    initial_input: ?[*:0]const u8 = null,
    wait_after_command: bool = false,
    context: SurfaceContext = .window,
};

pub const PlatformUnion = extern union {
    ptr: ?*anyopaque,
};

pub const InputAction = enum(c_int) {
    release = 0,
    press = 1,
    repeat = 2,
};

pub const InputMods = enum(c_int) {
    none = 0,
    shift = 1,
    ctrl = 2,
    alt = 4,
    super = 8,
    caps = 16,
    num = 32,
};

pub const InputKey = extern struct {
    action: InputAction = .press,
    mods: c_int = 0,
    consumed_mods: c_int = 0,
    keycode: u32 = 0,
    text: ?[*:0]const u8 = null,
    unshifted_codepoint: u32 = 0,
    composing: bool = false,
};

pub const MouseState = enum(c_int) {
    release = 0,
    press = 1,
};

pub const MouseButton = enum(c_int) {
    unknown = 0,
    left = 1,
    right = 2,
    middle = 3,
    four = 4,
    five = 5,
};

pub const SurfaceSize = extern struct {
    columns: u16,
    rows: u16,
    width_px: u32,
    height_px: u32,
    cell_width_px: u32,
    cell_height_px: u32,
};

pub const Info = extern struct {
    build_mode: c_int,
    version: ?[*]const u8,
    version_len: usize,
};

pub const SymbolNames = struct {
    pub const init = "ghostty_init";
    pub const info = "ghostty_info";
    pub const config_new = "ghostty_config_new";
    pub const config_free = "ghostty_config_free";
    pub const config_finalize = "ghostty_config_finalize";
    pub const app_new = "ghostty_app_new";
    pub const app_free = "ghostty_app_free";
    pub const app_tick = "ghostty_app_tick";
    pub const app_set_focus = "ghostty_app_set_focus";
    pub const surface_config_new = "ghostty_surface_config_new";
    pub const surface_new = "ghostty_surface_new";
    pub const surface_free = "ghostty_surface_free";
    pub const surface_refresh = "ghostty_surface_refresh";
    pub const surface_draw = "ghostty_surface_draw";
    pub const surface_set_focus = "ghostty_surface_set_focus";
    pub const surface_set_occlusion = "ghostty_surface_set_occlusion";
    pub const surface_set_size = "ghostty_surface_set_size";
    pub const surface_size = "ghostty_surface_size";
    pub const surface_key = "ghostty_surface_key";
    pub const surface_text = "ghostty_surface_text";
    pub const surface_preedit = "ghostty_surface_preedit";
    pub const surface_mouse_button = "ghostty_surface_mouse_button";
    pub const surface_mouse_pos = "ghostty_surface_mouse_pos";
    pub const surface_mouse_scroll = "ghostty_surface_mouse_scroll";
    pub const surface_process_exited = "ghostty_surface_process_exited";
};

pub const InitFn = *const fn (usize, [*]?[*:0]u8) callconv(.c) c_int;
pub const InfoFn = *const fn () callconv(.c) Info;
pub const ConfigNewFn = *const fn () callconv(.c) ghostty_config_t;
pub const ConfigFreeFn = *const fn (ghostty_config_t) callconv(.c) void;
pub const ConfigFinalizeFn = *const fn (ghostty_config_t) callconv(.c) void;
pub const AppNewFn = *const fn (*const RuntimeConfig, ghostty_config_t) callconv(.c) ghostty_app_t;
pub const AppFreeFn = *const fn (ghostty_app_t) callconv(.c) void;
pub const AppTickFn = *const fn (ghostty_app_t) callconv(.c) void;
pub const AppSetFocusFn = *const fn (ghostty_app_t, bool) callconv(.c) void;
pub const SurfaceConfigNewFn = *const fn () callconv(.c) SurfaceConfig;
pub const SurfaceNewFn = *const fn (ghostty_app_t, *const SurfaceConfig) callconv(.c) ghostty_surface_t;
pub const SurfaceFreeFn = *const fn (ghostty_surface_t) callconv(.c) void;
pub const SurfaceRefreshFn = *const fn (ghostty_surface_t) callconv(.c) void;
pub const SurfaceDrawFn = *const fn (ghostty_surface_t) callconv(.c) void;
pub const SurfaceSetFocusFn = *const fn (ghostty_surface_t, bool) callconv(.c) void;
pub const SurfaceSetOcclusionFn = *const fn (ghostty_surface_t, bool) callconv(.c) void;
pub const SurfaceSetSizeFn = *const fn (ghostty_surface_t, u32, u32) callconv(.c) void;
pub const SurfaceSizeFn = *const fn (ghostty_surface_t) callconv(.c) SurfaceSize;
pub const SurfaceKeyFn = *const fn (ghostty_surface_t, InputKey) callconv(.c) bool;
pub const SurfaceTextFn = *const fn (ghostty_surface_t, [*]const u8, usize) callconv(.c) void;
pub const SurfacePreeditFn = *const fn (ghostty_surface_t, [*]const u8, usize) callconv(.c) void;
pub const SurfaceMouseButtonFn = *const fn (ghostty_surface_t, MouseState, MouseButton, c_int) callconv(.c) bool;
pub const SurfaceMousePosFn = *const fn (ghostty_surface_t, f64, f64, c_int) callconv(.c) void;
pub const SurfaceMouseScrollFn = *const fn (ghostty_surface_t, f64, f64, c_int) callconv(.c) void;
pub const SurfaceProcessExitedFn = *const fn (ghostty_surface_t) callconv(.c) bool;

pub const Symbols = struct {
    init: ?InitFn = null,
    info: ?InfoFn = null,
    config_new: ?ConfigNewFn = null,
    config_free: ?ConfigFreeFn = null,
    config_finalize: ?ConfigFinalizeFn = null,
    app_new: ?AppNewFn = null,
    app_free: ?AppFreeFn = null,
    app_tick: ?AppTickFn = null,
    app_set_focus: ?AppSetFocusFn = null,
    surface_config_new: ?SurfaceConfigNewFn = null,
    surface_new: ?SurfaceNewFn = null,
    surface_free: ?SurfaceFreeFn = null,
    surface_refresh: ?SurfaceRefreshFn = null,
    surface_draw: ?SurfaceDrawFn = null,
    surface_set_focus: ?SurfaceSetFocusFn = null,
    surface_set_occlusion: ?SurfaceSetOcclusionFn = null,
    surface_set_size: ?SurfaceSetSizeFn = null,
    surface_size: ?SurfaceSizeFn = null,
    surface_key: ?SurfaceKeyFn = null,
    surface_text: ?SurfaceTextFn = null,
    surface_preedit: ?SurfacePreeditFn = null,
    surface_mouse_button: ?SurfaceMouseButtonFn = null,
    surface_mouse_pos: ?SurfaceMousePosFn = null,
    surface_mouse_scroll: ?SurfaceMouseScrollFn = null,
    surface_process_exited: ?SurfaceProcessExitedFn = null,

    pub fn complete(self: Symbols) bool {
        return self.init != null and
            self.info != null and
            self.config_new != null and
            self.config_free != null and
            self.config_finalize != null and
            self.app_new != null and
            self.app_free != null and
            self.app_tick != null and
            self.app_set_focus != null and
            self.surface_config_new != null and
            self.surface_new != null and
            self.surface_free != null and
            self.surface_refresh != null and
            self.surface_draw != null and
            self.surface_set_focus != null and
            self.surface_set_occlusion != null and
            self.surface_set_size != null and
            self.surface_size != null and
            self.surface_key != null and
            self.surface_text != null;
    }

    pub fn lifecycleComplete(self: Symbols) bool {
        return self.config_new != null and
            self.config_free != null and
            self.app_new != null and
            self.app_free != null and
            self.app_tick != null and
            self.surface_config_new != null and
            self.surface_new != null and
            self.surface_free != null and
            self.surface_draw != null and
            self.surface_set_size != null and
            self.surface_text != null;
    }
};

pub const Runtime = struct {
    lib: ?std.DynLib = null,
    symbols: Symbols = .{},

    pub fn open(path: ?[]const u8) !Runtime {
        var runtime = Runtime{};
        const lib_path = path orelse "libghostty.so";
        runtime.lib = try std.DynLib.open(lib_path);
        errdefer if (runtime.lib) |*lib| lib.close();

        if (runtime.lib) |*lib| {
            runtime.symbols = .{
                .init = lib.lookup(InitFn, SymbolNames.init),
                .info = lib.lookup(InfoFn, SymbolNames.info),
                .config_new = lib.lookup(ConfigNewFn, SymbolNames.config_new),
                .config_free = lib.lookup(ConfigFreeFn, SymbolNames.config_free),
                .config_finalize = lib.lookup(ConfigFinalizeFn, SymbolNames.config_finalize),
                .app_new = lib.lookup(AppNewFn, SymbolNames.app_new),
                .app_free = lib.lookup(AppFreeFn, SymbolNames.app_free),
                .app_tick = lib.lookup(AppTickFn, SymbolNames.app_tick),
                .app_set_focus = lib.lookup(AppSetFocusFn, SymbolNames.app_set_focus),
                .surface_config_new = lib.lookup(SurfaceConfigNewFn, SymbolNames.surface_config_new),
                .surface_new = lib.lookup(SurfaceNewFn, SymbolNames.surface_new),
                .surface_free = lib.lookup(SurfaceFreeFn, SymbolNames.surface_free),
                .surface_refresh = lib.lookup(SurfaceRefreshFn, SymbolNames.surface_refresh),
                .surface_draw = lib.lookup(SurfaceDrawFn, SymbolNames.surface_draw),
                .surface_set_focus = lib.lookup(SurfaceSetFocusFn, SymbolNames.surface_set_focus),
                .surface_set_occlusion = lib.lookup(SurfaceSetOcclusionFn, SymbolNames.surface_set_occlusion),
                .surface_set_size = lib.lookup(SurfaceSetSizeFn, SymbolNames.surface_set_size),
                .surface_size = lib.lookup(SurfaceSizeFn, SymbolNames.surface_size),
                .surface_key = lib.lookup(SurfaceKeyFn, SymbolNames.surface_key),
                .surface_text = lib.lookup(SurfaceTextFn, SymbolNames.surface_text),
                .surface_preedit = lib.lookup(SurfacePreeditFn, SymbolNames.surface_preedit),
                .surface_mouse_button = lib.lookup(SurfaceMouseButtonFn, SymbolNames.surface_mouse_button),
                .surface_mouse_pos = lib.lookup(SurfaceMousePosFn, SymbolNames.surface_mouse_pos),
                .surface_mouse_scroll = lib.lookup(SurfaceMouseScrollFn, SymbolNames.surface_mouse_scroll),
                .surface_process_exited = lib.lookup(SurfaceProcessExitedFn, SymbolNames.surface_process_exited),
            };
        }

        return runtime;
    }

    pub fn deinit(self: *Runtime) void {
        if (self.lib) |*lib| lib.close();
        self.lib = null;
        self.symbols = .{};
    }
};

pub const Probe = struct {
    available: bool,
    lifecycle_complete: bool = false,
    complete: bool = false,
    platform_surface_supported: bool = false,
    safe_gui_abi: bool = false,
    error_name: ?[]const u8 = null,
};

pub fn probe(path: ?[]const u8) Probe {
    var runtime = Runtime.open(path) catch |err| {
        return .{
            .available = false,
            .error_name = @errorName(err),
        };
    };
    defer runtime.deinit();

    const symbols_complete = runtime.symbols.complete();
    // The current public C ABI exposes only invalid/macos/ios platform tags.
    // Until a supported Linux platform-surface contract exists, symbol presence
    // alone must never promote a library to a safe NOCTTY GUI backend.
    const platform_surface_supported = false;
    return .{
        .available = true,
        .lifecycle_complete = runtime.symbols.lifecycleComplete(),
        .complete = symbols_complete and platform_surface_supported,
        .platform_surface_supported = platform_surface_supported,
        .safe_gui_abi = symbols_complete and platform_surface_supported,
    };
}

test "symbol names track published libghostty entry points" {
    try std.testing.expectEqualStrings("ghostty_init", SymbolNames.init);
    try std.testing.expectEqualStrings("ghostty_app_new", SymbolNames.app_new);
    try std.testing.expectEqualStrings("ghostty_surface_new", SymbolNames.surface_new);
    try std.testing.expectEqualStrings("ghostty_surface_draw", SymbolNames.surface_draw);
    try std.testing.expectEqualStrings("ghostty_surface_key", SymbolNames.surface_key);
    try std.testing.expectEqualStrings("ghostty_surface_text", SymbolNames.surface_text);
    try std.testing.expectEqual(@as(c_int, 0), @backingInt(Platform.invalid));
    try std.testing.expectEqual(@as(c_int, 1), @backingInt(Platform.macos));
    try std.testing.expectEqual(@as(c_int, 2), @backingInt(Platform.ios));
}

test "probe reports unavailable library without failing" {
    const result = probe("/definitely/not/libghostty.so");
    try std.testing.expect(!result.available);
    try std.testing.expect(result.error_name != null);
}
