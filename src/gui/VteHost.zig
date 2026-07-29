const std = @import("std");

pub const Event = enum(c_int) {
    started = 1,
    output = 2,
    exited = 3,
    input_sent = 4,
    resized = 5,
    input_marker = 6,
    shown = 7,
    hidden = 8,
    focused = 9,
    global_shortcut = 10,
    shortcut_registered = 11,
    shortcut_unregistered = 12,
    placement = 13,
    shortcut_conflict = 14,
    shortcut_failed = 15,
    shortcut_captured = 16,
    shortcut_recorder_shown = 17,
    preset_changed = 18,
    maintenance_tick = 19,
};

pub const Callback = *const fn (?*anyopaque, u64, Event, c_int, u64) callconv(.c) void;

const gboolean = c_int;
const guint = c_uint;
const GType = usize;
const GCallback = ?*const fn () callconv(.c) void;
const GtkWidget = opaque {};
const GtkWindow = opaque {};
const GtkContainer = opaque {};
const GtkBox = opaque {};
const GtkPaned = opaque {};
const GtkNotebook = opaque {};
const GtkLabel = opaque {};
const GtkComboBoxText = opaque {};
const VteTerminal = opaque {};
const GdkDisplay = opaque {};
const GdkMonitor = opaque {};
const GdkWindow = opaque {};
const GdkDevice = opaque {};
const GTypeInstance = opaque {};
const GDBusConnection = opaque {};
const GVariant = opaque {};
const GVariantType = opaque {};
const GCancellable = opaque {};

const GError = extern struct {
    domain: c_uint,
    code: c_int,
    message: [*:0]u8,
};

const GdkRectangle = extern struct {
    x: c_int,
    y: c_int,
    width: c_int,
    height: c_int,
};

const GdkEventKey = extern struct {
    event_type: c_int,
    window: ?*GdkWindow,
    send_event: i8,
    time: u32,
    state: c_uint,
    keyval: c_uint,
    length: c_int,
    string: ?[*:0]u8,
    hardware_keycode: u16,
    group: u8,
    is_modifier: c_uint,
};

const GdkEventButton = extern struct {
    event_type: c_int,
    window: ?*GdkWindow,
    send_event: i8,
    time: u32,
    x: f64,
    y: f64,
    axes: ?[*]f64,
    state: c_uint,
    button: c_uint,
    device: ?*GdkDevice,
    x_root: f64,
    y_root: f64,
};

const GVariantBuilder = extern struct {
    storage: [16]usize,
};

const GTK_WINDOW_TOPLEVEL: c_int = 0;
const GTK_ORIENTATION_HORIZONTAL: c_int = 0;
const GTK_ORIENTATION_VERTICAL: c_int = 1;
const GTK_POS_TOP: c_int = 2;
const GTK_WIN_POS_CENTER: c_int = 1;
const GTK_DIALOG_MODAL: c_int = 1;
const GTK_DIALOG_DESTROY_WITH_PARENT: c_int = 2;
const GDK_GRAVITY_NORTH: c_int = 2;
const G_BUS_TYPE_SESSION: c_int = 2;
const G_FILE_TEST_EXISTS: c_int = 1 << 4;
const G_SPAWN_SEARCH_PATH: c_int = 1 << 2;
const VTE_PTY_DEFAULT: c_int = 0;
const VTE_FORMAT_TEXT: c_int = 1;
const G_SOURCE_REMOVE: gboolean = 0;
const G_SOURCE_CONTINUE: gboolean = 1;

const GDK_SHIFT_MASK: c_uint = 1 << 0;
const GDK_CONTROL_MASK: c_uint = 1 << 2;
const GDK_MOD1_MASK: c_uint = 1 << 3;
const GDK_SUPER_MASK: c_uint = 1 << 26;
const GDK_KEY_Escape: c_uint = 0xff1b;
const GDK_KEY_Tab: c_uint = 0xff09;
const GDK_KEY_BackSpace: c_uint = 0xff08;
const GDK_KEY_Return: c_uint = 0xff0d;
const GDK_KEY_KP_Enter: c_uint = 0xff8d;
const GDK_KEY_Insert: c_uint = 0xff63;
const GDK_KEY_Delete: c_uint = 0xffff;
const GDK_KEY_Home: c_uint = 0xff50;
const GDK_KEY_End: c_uint = 0xff57;
const GDK_KEY_Left: c_uint = 0xff51;
const GDK_KEY_Up: c_uint = 0xff52;
const GDK_KEY_Right: c_uint = 0xff53;
const GDK_KEY_Down: c_uint = 0xff54;
const GDK_KEY_Page_Up: c_uint = 0xff55;
const GDK_KEY_Page_Down: c_uint = 0xff56;
const GDK_KEY_F1: c_uint = 0xffbe;
const GDK_KEY_F10: c_uint = 0xffc7;
const GDK_KEY_F11: c_uint = 0xffc8;
const GDK_KEY_F12: c_uint = 0xffc9;

extern fn gtk_init_check(argc: ?*c_int, argv: ?*anyopaque) gboolean;
extern fn gtk_main() void;
extern fn gtk_main_quit() void;
extern fn gtk_window_new(window_type: c_int) ?*GtkWidget;
extern fn gtk_window_set_title(window: *GtkWindow, title: [*:0]const u8) void;
extern fn gtk_window_set_default_size(window: *GtkWindow, width: c_int, height: c_int) void;
extern fn gtk_window_move(window: *GtkWindow, x: c_int, y: c_int) void;
extern fn gtk_window_set_gravity(window: *GtkWindow, gravity: c_int) void;
extern fn gtk_window_fullscreen(window: *GtkWindow) void;
extern fn gtk_window_set_position(window: *GtkWindow, position: c_int) void;
extern fn gtk_window_set_decorated(window: *GtkWindow, setting: gboolean) void;
extern fn gtk_window_set_keep_above(window: *GtkWindow, setting: gboolean) void;
extern fn gtk_window_resize(window: *GtkWindow, width: c_int, height: c_int) void;
extern fn gtk_window_present(window: *GtkWindow) void;
extern fn gtk_window_get_position(window: *GtkWindow, x: *c_int, y: *c_int) void;
extern fn gtk_window_get_size(window: *GtkWindow, width: *c_int, height: *c_int) void;
extern fn gtk_widget_show_all(widget: *GtkWidget) void;
extern fn gtk_widget_hide(widget: *GtkWidget) void;
extern fn gtk_widget_destroy(widget: *GtkWidget) void;
extern fn gtk_widget_grab_focus(widget: *GtkWidget) void;
extern fn gtk_widget_get_visible(widget: *GtkWidget) gboolean;
extern fn gtk_container_add(container: *GtkContainer, widget: *GtkWidget) void;
extern fn gtk_container_set_border_width(container: *GtkContainer, border_width: c_uint) void;
extern fn gtk_box_new(orientation: c_int, spacing: c_int) ?*GtkWidget;
extern fn gtk_box_pack_start(box: *GtkBox, child: *GtkWidget, expand: gboolean, fill: gboolean, padding: c_uint) void;
extern fn gtk_paned_new(orientation: c_int) ?*GtkWidget;
extern fn gtk_paned_pack1(paned: *GtkPaned, child: *GtkWidget, resize: gboolean, shrink: gboolean) void;
extern fn gtk_paned_pack2(paned: *GtkPaned, child: *GtkWidget, resize: gboolean, shrink: gboolean) void;
extern fn gtk_notebook_new() ?*GtkWidget;
extern fn gtk_notebook_set_tab_pos(notebook: *GtkNotebook, position: c_int) void;
extern fn gtk_notebook_append_page(notebook: *GtkNotebook, child: *GtkWidget, tab_label: *GtkWidget) c_int;
extern fn gtk_notebook_set_tab_reorderable(notebook: *GtkNotebook, child: *GtkWidget, reorderable: gboolean) void;
extern fn gtk_label_new(text: ?[*:0]const u8) ?*GtkWidget;
extern fn gtk_label_set_text(label: *GtkLabel, text: [*:0]const u8) void;
extern fn gtk_label_set_xalign(label: *GtkLabel, xalign: f32) void;
extern fn gtk_combo_box_text_new() ?*GtkWidget;
extern fn gtk_combo_box_text_append_text(combo: *GtkComboBoxText, text: [*:0]const u8) void;
extern fn gtk_combo_box_text_get_active_text(combo: *GtkComboBoxText) ?[*:0]u8;
extern fn gtk_combo_box_set_active(combo: ?*anyopaque, index: c_int) void;
extern fn gtk_combo_box_get_active(combo: ?*anyopaque) c_int;
extern fn gtk_dialog_new_with_buttons(title: [*:0]const u8, parent: *GtkWindow, flags: c_int, first_button_text: ?[*:0]const u8, ...) ?*GtkWidget;
extern fn gtk_dialog_get_content_area(dialog: ?*anyopaque) ?*GtkWidget;

extern fn gdk_display_get_default() ?*GdkDisplay;
extern fn gdk_display_get_primary_monitor(display: *GdkDisplay) ?*GdkMonitor;
extern fn gdk_display_get_monitor(display: *GdkDisplay, monitor_num: c_int) ?*GdkMonitor;
extern fn gdk_monitor_get_workarea(monitor: *GdkMonitor, workarea: *GdkRectangle) void;
extern fn gdk_x11_display_get_type() GType;
extern fn gdk_wayland_display_get_type() GType;
extern fn g_type_check_instance_is_a(instance: *GTypeInstance, iface_type: GType) gboolean;

extern fn g_signal_connect_data(instance: ?*anyopaque, detailed_signal: [*:0]const u8, handler: GCallback, data: ?*anyopaque, destroy_data: ?*anyopaque, flags: c_uint) c_ulong;
extern fn g_timeout_add(interval: c_uint, function: *const fn (?*anyopaque) callconv(.c) gboolean, data: ?*anyopaque) c_uint;
extern fn g_source_remove(tag: c_uint) gboolean;
extern fn g_get_monotonic_time() i64;
extern fn g_getenv(variable: [*:0]const u8) ?[*:0]const u8;
extern fn g_setenv(variable: [*:0]const u8, value: [*:0]const u8, overwrite: gboolean) gboolean;
extern fn g_file_test(filename: [*:0]const u8, test_flags: c_int) gboolean;
extern fn g_free(memory: ?*anyopaque) void;
extern fn g_error_free(error_value: *GError) void;
extern fn g_object_unref(object: ?*anyopaque) void;

extern fn g_bus_get_sync(bus_type: c_int, cancellable: ?*GCancellable, error_value: *?*GError) ?*GDBusConnection;
extern fn g_dbus_connection_call_sync(connection: *GDBusConnection, bus_name: [*:0]const u8, object_path: [*:0]const u8, interface_name: [*:0]const u8, method_name: [*:0]const u8, parameters: ?*GVariant, reply_type: ?*const GVariantType, flags: c_int, timeout_msec: c_int, cancellable: ?*GCancellable, error_value: ?*?*GError) ?*GVariant;
extern fn g_dbus_connection_signal_subscribe(connection: *GDBusConnection, sender: ?[*:0]const u8, interface_name: ?[*:0]const u8, member: ?[*:0]const u8, object_path: ?[*:0]const u8, arg0: ?[*:0]const u8, flags: c_int, callback: *const fn (*GDBusConnection, ?[*:0]const u8, [*:0]const u8, [*:0]const u8, [*:0]const u8, *GVariant, ?*anyopaque) callconv(.c) void, user_data: ?*anyopaque, user_data_free_func: ?*anyopaque) c_uint;
extern fn g_dbus_connection_signal_unsubscribe(connection: *GDBusConnection, subscription_id: c_uint) void;
extern fn g_variant_new(format: [*:0]const u8, ...) *GVariant;
extern fn g_variant_unref(value: *GVariant) void;
extern fn g_variant_get(value: *GVariant, format: [*:0]const u8, ...) void;
extern fn g_variant_builder_init(builder: *GVariantBuilder, type_value: *const GVariantType) void;
extern fn g_variant_builder_add(builder: *GVariantBuilder, format: [*:0]const u8, ...) void;
extern fn g_variant_get_fixed_array(value: *GVariant, n_elements: *usize, element_size: usize) ?*const anyopaque;

extern fn vte_terminal_new() ?*GtkWidget;
extern fn vte_terminal_get_text_format(terminal: *VteTerminal, format: c_int) ?[*:0]u8;
extern fn vte_terminal_feed_child(terminal: *VteTerminal, text: [*]const u8, length: isize) void;
extern fn vte_terminal_get_column_count(terminal: *VteTerminal) c_long;
extern fn vte_terminal_set_scrollback_lines(terminal: *VteTerminal, lines: c_long) void;
extern fn vte_terminal_set_mouse_autohide(terminal: *VteTerminal, setting: gboolean) void;
extern fn vte_terminal_spawn_async(terminal: *VteTerminal, pty_flags: c_int, working_directory: ?[*:0]const u8, argv: [*:null]const ?[*:0]u8, envv: ?[*:null]const ?[*:0]u8, spawn_flags: c_int, child_setup: ?*anyopaque, child_setup_data: ?*anyopaque, child_setup_data_destroy: ?*anyopaque, timeout: c_int, cancellable: ?*GCancellable, callback: *const fn (*VteTerminal, c_int, ?*GError, ?*anyopaque) callconv(.c) void, user_data: ?*anyopaque) void;

const Placement = enum(c_int) {
    none = 0,
    x11_top = 1,
    wayland_layer = 2,
    wayland_constrained = 3,
    windowed = 4,
    fullscreen = 5,
};

const Context = struct {
    window: *GtkWidget,
    terminal_widget: *GtkWidget,
    secondary_terminal_widget: ?*GtkWidget = null,
    pane_id: u64,
    callback: Callback,
    callback_data: ?*anyopaque,
    smoke: c_int,
    mode: c_int,
    initial_width: c_int = 0,
    initial_height: c_int = 0,
    session_bus: ?*GDBusConnection = null,
    shortcut_subscription: c_uint = 0,
    global_shortcut_registered: bool = false,
    global_shortcut_action_registered: bool = false,
    requested_shortcut_key: c_int,
    placement: Placement = .none,
    layer_shell_library: ?std.DynLib = null,
    expected_x: c_int = 0,
    expected_y: c_int = 0,
    expected_width: c_int = 0,
    expected_height: c_int = 0,
    smoke_marker_path: [128]u8 = [_]u8{0} ** 128,
    shortcut_dialog: ?*GtkWidget = null,
    shortcut_feedback: ?*GtkWidget = null,
    tabs: ?*GtkWidget = null,
    tab_index: c_uint = 0,
    secondary_pane_id: u64 = 0,
    secondary_bound: bool = false,
    maintenance_timer: c_uint = 0,
    smoke_resize_source: c_uint = 0,
    smoke_marker_source: c_uint = 0,
    smoke_hide_source: c_uint = 0,
    smoke_shortcut_source: c_uint = 0,
    smoke_recorder_source: c_uint = 0,
    smoke_recorder_capture_source: c_uint = 0,
};

const SecondaryContext = struct {
    terminal_widget: *GtkWidget,
    pane_id: u64,
    callback: Callback,
    callback_data: ?*anyopaque,
    spawned: bool = false,
};

fn asWindow(widget: *GtkWidget) *GtkWindow {
    return @ptrCast(widget);
}

fn asContainer(widget: *GtkWidget) *GtkContainer {
    return @ptrCast(widget);
}

fn asBox(widget: *GtkWidget) *GtkBox {
    return @ptrCast(widget);
}

fn asPaned(widget: *GtkWidget) *GtkPaned {
    return @ptrCast(widget);
}

fn asNotebook(widget: *GtkWidget) *GtkNotebook {
    return @ptrCast(widget);
}

fn asLabel(widget: *GtkWidget) *GtkLabel {
    return @ptrCast(widget);
}

fn asCombo(widget: *GtkWidget) *GtkComboBoxText {
    return @ptrCast(widget);
}

fn asTerminal(widget: *GtkWidget) *VteTerminal {
    return @ptrCast(widget);
}

fn context(raw: ?*anyopaque) *Context {
    return @ptrCast(@alignCast(raw.?));
}

fn secondaryContext(raw: ?*anyopaque) *SecondaryContext {
    return @ptrCast(@alignCast(raw.?));
}

fn connect(instance: ?*anyopaque, signal: [*:0]const u8, handler: anytype, data: ?*anyopaque) void {
    _ = g_signal_connect_data(instance, signal, @ptrCast(handler), data, null, 0);
}

fn nowMs() u64 {
    return @intCast(@divTrunc(g_get_monotonic_time(), 1000));
}

fn variantType(text: [*:0]const u8) *const GVariantType {
    return @ptrCast(text);
}

fn displayIs(display: *GdkDisplay, display_type: GType) bool {
    return g_type_check_instance_is_a(@ptrCast(display), display_type) != 0;
}

fn emit(ctx: *Context, event: Event, value: c_int) void {
    ctx.callback(ctx.callback_data, ctx.pane_id, event, value, nowMs());
}

fn markerSeen(terminal: *VteTerminal) bool {
    const raw = vte_terminal_get_text_format(terminal, VTE_FORMAT_TEXT) orelse return false;
    defer g_free(raw);
    return std.mem.indexOf(u8, std.mem.span(raw), "NOCTTY_NATIVE_INPUT_OK") != null;
}

fn onSecondarySpawned(_: *VteTerminal, _: c_int, error_value: ?*GError, raw: ?*anyopaque) callconv(.c) void {
    const secondary = secondaryContext(raw);
    if (error_value) |err| {
        g_error_free(err);
        return;
    }
    secondary.spawned = true;
    secondary.callback(secondary.callback_data, secondary.pane_id, .started, 0, nowMs());
}

fn onSecondaryContentsChanged(_: *VteTerminal, raw: ?*anyopaque) callconv(.c) void {
    const secondary = secondaryContext(raw);
    secondary.callback(secondary.callback_data, secondary.pane_id, .output, 0, nowMs());
}

fn onSecondarySizeAllocate(_: *GtkWidget, _: *GdkRectangle, raw: ?*anyopaque) callconv(.c) void {
    const secondary = secondaryContext(raw);
    secondary.callback(secondary.callback_data, secondary.pane_id, .resized, 0, nowMs());
}

fn onSecondaryChildExited(_: *VteTerminal, status: c_int, raw: ?*anyopaque) callconv(.c) void {
    const secondary = secondaryContext(raw);
    secondary.callback(secondary.callback_data, secondary.pane_id, .exited, status, nowMs());
}

fn removeSource(source: *c_uint) void {
    if (source.* == 0) return;
    _ = g_source_remove(source.*);
    source.* = 0;
}

fn clearSmokeSources(ctx: *Context) void {
    removeSource(&ctx.smoke_resize_source);
    removeSource(&ctx.smoke_marker_source);
    removeSource(&ctx.smoke_hide_source);
    removeSource(&ctx.smoke_shortcut_source);
    removeSource(&ctx.smoke_recorder_source);
    removeSource(&ctx.smoke_recorder_capture_source);
}

fn onMaintenanceTimer(raw: ?*anyopaque) callconv(.c) gboolean {
    emit(context(raw), .maintenance_tick, 0);
    return G_SOURCE_CONTINUE;
}

fn configureDropdownPlacement(ctx: *Context) void {
    const display = gdk_display_get_default() orelse return;
    var monitor = gdk_display_get_primary_monitor(display);
    if (monitor == null) monitor = gdk_display_get_monitor(display, 0);
    var geometry = GdkRectangle{ .x = 0, .y = 0, .width = 1000, .height = 640 };
    if (monitor) |value| gdk_monitor_get_workarea(value, &geometry);
    const height = @max(1, @divTrunc(geometry.height * 45, 100));

    if (displayIs(display, gdk_x11_display_get_type())) {
        gtk_window_set_default_size(asWindow(ctx.window), geometry.width, height);
        gtk_window_move(asWindow(ctx.window), geometry.x, geometry.y);
        ctx.placement = .x11_top;
        ctx.expected_x = geometry.x;
        ctx.expected_y = geometry.y;
        ctx.expected_width = geometry.width;
        ctx.expected_height = height;
    } else if (displayIs(display, gdk_wayland_display_get_type())) {
        const IsSupported = *const fn () callconv(.c) gboolean;
        const InitForWindow = *const fn (*GtkWindow) callconv(.c) void;
        const SetAnchor = *const fn (*GtkWindow, c_int, gboolean) callconv(.c) void;
        const SetLayer = *const fn (*GtkWindow, c_int) callconv(.c) void;
        const SetKeyboardMode = *const fn (*GtkWindow, c_int) callconv(.c) void;
        var library = std.DynLib.open("libgtk-layer-shell.so.0") catch null;
        if (library) |*lib| {
            ctx.layer_shell_library = lib.*;
            const is_supported = lib.lookup(IsSupported, "gtk_layer_is_supported");
            const init_for_window = lib.lookup(InitForWindow, "gtk_layer_init_for_window");
            const set_anchor = lib.lookup(SetAnchor, "gtk_layer_set_anchor");
            const set_layer = lib.lookup(SetLayer, "gtk_layer_set_layer");
            const set_keyboard = lib.lookup(SetKeyboardMode, "gtk_layer_set_keyboard_mode");
            if (is_supported != null and init_for_window != null and set_anchor != null and set_layer != null and set_keyboard != null and is_supported.?() != 0) {
                init_for_window.?(asWindow(ctx.window));
                set_anchor.?(asWindow(ctx.window), 0, 1);
                set_anchor.?(asWindow(ctx.window), 1, 1);
                set_anchor.?(asWindow(ctx.window), 2, 1);
                set_layer.?(asWindow(ctx.window), 2);
                set_keyboard.?(asWindow(ctx.window), 2);
                gtk_window_set_default_size(asWindow(ctx.window), 0, height);
                ctx.placement = .wayland_layer;
            }
        }
        if (ctx.placement == .none) {
            gtk_window_set_default_size(asWindow(ctx.window), geometry.width, height);
            gtk_window_set_gravity(asWindow(ctx.window), GDK_GRAVITY_NORTH);
            ctx.placement = .wayland_constrained;
        }
    }
    if (ctx.placement != .x11_top) emit(ctx, .placement, @intFromEnum(ctx.placement));
}

fn configureWindowMode(ctx: *Context) void {
    const display = gdk_display_get_default() orelse return;
    var monitor = gdk_display_get_primary_monitor(display);
    if (monitor == null) monitor = gdk_display_get_monitor(display, 0);
    var geometry = GdkRectangle{ .x = 0, .y = 0, .width = 1000, .height = 640 };
    if (monitor) |value| gdk_monitor_get_workarea(value, &geometry);
    if (ctx.mode == 2) {
        gtk_window_fullscreen(asWindow(ctx.window));
        ctx.placement = .fullscreen;
    } else {
        gtk_window_set_default_size(asWindow(ctx.window), @max(1, @divTrunc(geometry.width * 80, 100)), @max(1, @divTrunc(geometry.height * 75, 100)));
        gtk_window_set_position(asWindow(ctx.window), GTK_WIN_POS_CENTER);
        ctx.placement = .windowed;
    }
    emit(ctx, .placement, @intFromEnum(ctx.placement));
}

fn onChildExited(terminal: *VteTerminal, status: c_int, raw: ?*anyopaque) callconv(.c) void {
    const ctx = context(raw);
    if (ctx.smoke != 0) {
        if (markerSeen(terminal)) emit(ctx, .input_marker, 0);
        const marker: [*:0]const u8 = @ptrCast(&ctx.smoke_marker_path);
        if (g_file_test(marker, G_FILE_TEST_EXISTS) != 0) {
            emit(ctx, .input_marker, 0);
            _ = std.c.unlink(marker);
        }
    }
    const wait_status: u32 = @bitCast(status);
    const exit_code: c_int = if (std.c.W.IFEXITED(wait_status)) std.c.W.EXITSTATUS(wait_status) else 255;
    emit(ctx, .exited, exit_code);
    gtk_widget_destroy(ctx.window);
}

fn onContentsChanged(terminal: *VteTerminal, raw: ?*anyopaque) callconv(.c) void {
    const ctx = context(raw);
    emit(ctx, .output, 0);
    if (ctx.smoke != 0 and markerSeen(terminal)) emit(ctx, .input_marker, 0);
}

fn onSpawned(terminal: *VteTerminal, _: c_int, error_value: ?*GError, raw: ?*anyopaque) callconv(.c) void {
    const ctx = context(raw);
    if (error_value) |err| {
        std.debug.print("NOCTTY could not start the shell: {s}\n", .{std.mem.span(err.message)});
        emit(ctx, .exited, 255);
        g_error_free(err);
        gtk_widget_destroy(ctx.window);
        return;
    }
    emit(ctx, .started, 0);
    if (ctx.smoke != 0) {
        const command =
            "printf 'NOCTTY_NATIVE_INPUT_OK pane=$NOCTTY_SMOKE_PANE\\n'; " ++
            ": > \"$NOCTTY_SMOKE_MARKER\"; " ++
            "sleep \"$NOCTTY_SMOKE_DELAY\"; exit 0\n";
        vte_terminal_feed_child(terminal, command, -1);
        emit(ctx, .input_sent, 0);
    }
}

fn onSizeAllocate(_: *GtkWidget, allocation: *GdkRectangle, raw: ?*anyopaque) callconv(.c) void {
    const ctx = context(raw);
    if (ctx.smoke == 0) return;
    if (ctx.initial_width == 0 or ctx.initial_height == 0) {
        ctx.initial_width = allocation.width;
        ctx.initial_height = allocation.height;
        return;
    }
    if (allocation.width != ctx.initial_width or allocation.height != ctx.initial_height)
        emit(ctx, .resized, @intCast(vte_terminal_get_column_count(asTerminal(ctx.terminal_widget))));
}

fn requestSmokeResize(raw: ?*anyopaque) callconv(.c) gboolean {
    const ctx = context(raw);
    ctx.smoke_resize_source = 0;
    gtk_window_resize(asWindow(ctx.window), 1200, 720);
    return G_SOURCE_REMOVE;
}

fn toggleDropdown(ctx: *Context) void {
    if (gtk_widget_get_visible(ctx.window) != 0) {
        gtk_widget_hide(ctx.window);
    } else {
        gtk_widget_show_all(ctx.window);
        gtk_window_present(asWindow(ctx.window));
        gtk_widget_grab_focus(ctx.terminal_widget);
    }
}

pub fn qtKeyFromGdk(keyval: c_uint, state: c_uint) c_int {
    var key: u32 = if (keyval >= GDK_KEY_F1 and keyval <= GDK_KEY_F12)
        0x01000030 + (keyval - GDK_KEY_F1)
    else if (keyval >= 'a' and keyval <= 'z')
        'A' + (keyval - 'a')
    else if (keyval >= 'A' and keyval <= 'Z')
        keyval
    else if (keyval >= '0' and keyval <= '9')
        '0' + (keyval - '0')
    else switch (keyval) {
        '`' => '`',
        GDK_KEY_Escape => 0x01000000,
        GDK_KEY_Tab => 0x01000001,
        GDK_KEY_BackSpace => 0x01000003,
        GDK_KEY_Return, GDK_KEY_KP_Enter => 0x01000005,
        ' ' => 0x20,
        GDK_KEY_Insert => 0x01000006,
        GDK_KEY_Delete => 0x01000007,
        GDK_KEY_Home => 0x01000010,
        GDK_KEY_End => 0x01000011,
        GDK_KEY_Left => 0x01000012,
        GDK_KEY_Up => 0x01000013,
        GDK_KEY_Right => 0x01000014,
        GDK_KEY_Down => 0x01000015,
        GDK_KEY_Page_Up => 0x01000016,
        GDK_KEY_Page_Down => 0x01000017,
        else => return 0,
    };
    if (state & GDK_SHIFT_MASK != 0) key |= 0x02000000;
    if (state & GDK_CONTROL_MASK != 0) key |= 0x04000000;
    if (state & GDK_MOD1_MASK != 0) key |= 0x08000000;
    if (state & GDK_SUPER_MASK != 0) key |= 0x10000000;
    return @intCast(key);
}

pub fn controlCall(action: c_int, visible_out: *c_int) c_int {
    const method: [*:0]const u8 = switch (action) {
        1 => "Toggle",
        2 => "Show",
        3 => "Hide",
        else => "GetState",
    };
    var error_value: ?*GError = null;
    const bus = g_bus_get_sync(G_BUS_TYPE_SESSION, null, &error_value) orelse {
        if (error_value) |err| g_error_free(err);
        return 0;
    };
    defer g_object_unref(bus);
    const reply = g_dbus_connection_call_sync(bus, "com.noctty.NOCTTY", "/com/noctty/NOCTTY", "com.noctty.NOCTTY.Control", method, null, variantType("(b)"), 0, 2000, null, &error_value) orelse {
        if (error_value) |err| g_error_free(err);
        return 0;
    };
    defer g_variant_unref(reply);
    var visible: gboolean = 0;
    g_variant_get(reply, "(b)", &visible);
    visible_out.* = @intFromBool(visible != 0);
    return 1;
}

fn onKeyPress(_: *GtkWidget, event: *GdkEventKey, raw: ?*anyopaque) callconv(.c) gboolean {
    const ctx = context(raw);
    if (qtKeyFromGdk(event.keyval, event.state) != ctx.requested_shortcut_key) return 0;
    toggleDropdown(ctx);
    return 1;
}

fn shortcutFailed(ctx: *Context, error_value: *?*GError) c_int {
    if (error_value.*) |err| {
        std.debug.print("NOCTTY could not register Plasma F10 shortcut: {s}\n", .{std.mem.span(err.message)});
        g_error_free(err);
        error_value.* = null;
    }
    emit(ctx, .shortcut_failed, 0);
    return 0;
}

fn onGlobalShortcut(_: *GDBusConnection, _: ?[*:0]const u8, _: [*:0]const u8, _: [*:0]const u8, _: [*:0]const u8, _: *GVariant, raw: ?*anyopaque) callconv(.c) void {
    const ctx = context(raw);
    toggleDropdown(ctx);
    emit(ctx, .global_shortcut, 0);
}

fn registerGlobalShortcut(ctx: *Context) c_int {
    var error_value: ?*GError = null;
    const action_id = [_:null]?[*:0]const u8{ "noctty", "toggle-window", "NOCTTY", "Show/hide NOCTTY" };
    const requested_key: i32 = ctx.requested_shortcut_key;
    ctx.session_bus = g_bus_get_sync(G_BUS_TYPE_SESSION, null, &error_value);
    const bus = ctx.session_bus orelse return shortcutFailed(ctx, &error_value);

    var reply = g_dbus_connection_call_sync(bus, "org.kde.kglobalaccel", "/kglobalaccel", "org.kde.KGlobalAccel", "doRegister", g_variant_new("(^as)", &action_id), null, 0, -1, null, &error_value) orelse return shortcutFailed(ctx, &error_value);
    g_variant_unref(reply);
    ctx.global_shortcut_action_registered = true;

    reply = g_dbus_connection_call_sync(bus, "org.kde.kglobalaccel", "/kglobalaccel", "org.kde.KGlobalAccel", "isGlobalShortcutAvailable", g_variant_new("(is)", requested_key, "noctty"), variantType("(b)"), 0, -1, null, &error_value) orelse return shortcutFailed(ctx, &error_value);
    var available: gboolean = 0;
    g_variant_get(reply, "(b)", &available);
    g_variant_unref(reply);
    if (available == 0) {
        emit(ctx, .shortcut_conflict, requested_key);
        return 0;
    }

    var keys: GVariantBuilder = undefined;
    g_variant_builder_init(&keys, variantType("ai"));
    g_variant_builder_add(&keys, "i", requested_key);
    reply = g_dbus_connection_call_sync(bus, "org.kde.kglobalaccel", "/kglobalaccel", "org.kde.KGlobalAccel", "setShortcut", g_variant_new("(^asaiu)", &action_id, &keys, @as(c_uint, 2)), variantType("(ai)"), 0, -1, null, &error_value) orelse return shortcutFailed(ctx, &error_value);
    var accepted_keys: ?*GVariant = null;
    g_variant_get(reply, "(@ai)", &accepted_keys);
    var accepted_count: usize = 0;
    const accepted_raw = if (accepted_keys) |value| g_variant_get_fixed_array(value, &accepted_count, @sizeOf(i32)) else null;
    const accepted: ?[*]const i32 = if (accepted_raw) |value| @ptrCast(@alignCast(value)) else null;
    const accepted_requested = accepted_count == 1 and accepted != null and accepted.?[0] == requested_key;
    if (accepted_keys) |value| g_variant_unref(value);
    g_variant_unref(reply);
    if (!accepted_requested) {
        emit(ctx, .shortcut_conflict, requested_key);
        return 0;
    }

    ctx.shortcut_subscription = g_dbus_connection_signal_subscribe(bus, "org.kde.kglobalaccel", "org.kde.kglobalaccel.Component", "globalShortcutPressed", "/component/noctty", null, 0, onGlobalShortcut, ctx, null);
    ctx.global_shortcut_registered = true;
    emit(ctx, .shortcut_registered, 0);
    return 1;
}

fn unregisterGlobalShortcut(ctx: *Context) void {
    const bus = ctx.session_bus orelse return;
    if (ctx.shortcut_subscription != 0)
        g_dbus_connection_signal_unsubscribe(bus, ctx.shortcut_subscription);
    if (ctx.global_shortcut_action_registered) {
        const reply = g_dbus_connection_call_sync(bus, "org.kde.kglobalaccel", "/kglobalaccel", "org.kde.KGlobalAccel", "unregister", g_variant_new("(ss)", "noctty", "toggle-window"), variantType("(b)"), 0, -1, null, null);
        if (reply) |value| g_variant_unref(value);
        emit(ctx, .shortcut_unregistered, 0);
    }
    g_object_unref(bus);
    ctx.session_bus = null;
    ctx.shortcut_subscription = 0;
    ctx.global_shortcut_registered = false;
    ctx.global_shortcut_action_registered = false;
}

fn onShortcutCapture(_: *GtkWidget, event: *GdkEventKey, raw: ?*anyopaque) callconv(.c) gboolean {
    const ctx = context(raw);
    if (event.keyval == GDK_KEY_Escape) {
        if (ctx.shortcut_dialog) |dialog| gtk_widget_destroy(dialog);
        ctx.shortcut_dialog = null;
        ctx.shortcut_feedback = null;
        return 1;
    }
    const key = qtKeyFromGdk(event.keyval, event.state);
    if (key == 0) {
        if (ctx.shortcut_feedback) |feedback| gtk_label_set_text(asLabel(feedback), "Use a letter, digit, navigation key, or F1-F12. Esc cancels.");
        return 1;
    }
    unregisterGlobalShortcut(ctx);
    ctx.requested_shortcut_key = key;
    emit(ctx, .shortcut_captured, key);
    if (registerGlobalShortcut(ctx) != 0) {
        if (ctx.shortcut_dialog) |dialog| gtk_widget_destroy(dialog);
        ctx.shortcut_dialog = null;
        ctx.shortcut_feedback = null;
    } else if (ctx.shortcut_feedback) |feedback| {
        gtk_label_set_text(asLabel(feedback), "Shortcut unavailable. Press another key or Esc.");
    }
    return 1;
}

fn onShortcutDialogDestroy(_: *GtkWidget, raw: ?*anyopaque) callconv(.c) void {
    const ctx = context(raw);
    ctx.shortcut_dialog = null;
    ctx.shortcut_feedback = null;
}

fn onPresetChanged(combo: *GtkComboBoxText, raw: ?*anyopaque) callconv(.c) void {
    const ctx = context(raw);
    const name = gtk_combo_box_text_get_active_text(combo) orelse return;
    defer g_free(name);
    var message_buffer: [256]u8 = undefined;
    const message = std.fmt.bufPrintZ(&message_buffer, "Preset selected: {s}\nApply through settings to persist.", .{std.mem.span(name)}) catch return;
    if (ctx.shortcut_feedback) |feedback| gtk_label_set_text(asLabel(feedback), message.ptr);
    emit(ctx, .preset_changed, gtk_combo_box_get_active(combo));
}

fn openShortcutRecorder(ctx: *Context) void {
    if (ctx.shortcut_dialog) |dialog| {
        gtk_window_present(asWindow(dialog));
        return;
    }
    const dialog = gtk_dialog_new_with_buttons("NOCTTY Dropdown Shortcut", asWindow(ctx.window), GTK_DIALOG_MODAL | GTK_DIALOG_DESTROY_WITH_PARENT, null) orelse return;
    const content = gtk_dialog_get_content_area(dialog) orelse return;
    const label = gtk_label_new("Press a letter, digit, navigation/editing key, or F1-F12.\nModifiers are supported.\nEsc cancels without changing the shortcut.") orelse return;
    const settings = gtk_label_new("Current settings\nShortcut: F10\nMode: Dropdown\nFont: JetBrains Mono 12 pt\nProfile: Global default\nPresets: Global default, Focus, Review, Logs, Custom\nTabs: Top\nStatus indicator: Border") orelse return;
    const box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 12) orelse return;
    const preset_combo = gtk_combo_box_text_new() orelse return;
    for ([_][*:0]const u8{ "Global default", "Focus", "Review", "Logs", "Custom" }) |name|
        gtk_combo_box_text_append_text(asCombo(preset_combo), name);
    gtk_combo_box_set_active(preset_combo, 0);
    gtk_container_set_border_width(asContainer(content), 16);
    gtk_label_set_xalign(asLabel(settings), 0);
    gtk_label_set_xalign(asLabel(label), 0);
    gtk_box_pack_start(asBox(box), settings, 0, 0, 0);
    gtk_box_pack_start(asBox(box), preset_combo, 0, 0, 0);
    gtk_box_pack_start(asBox(box), label, 0, 0, 0);
    gtk_container_add(asContainer(content), box);
    ctx.shortcut_dialog = dialog;
    ctx.shortcut_feedback = label;
    connect(preset_combo, "changed", &onPresetChanged, ctx);
    connect(dialog, "key-press-event", &onShortcutCapture, ctx);
    connect(dialog, "destroy", &onShortcutDialogDestroy, ctx);
    gtk_widget_show_all(dialog);
    emit(ctx, .shortcut_recorder_shown, 0);
}

fn requestSmokeRecorder(raw: ?*anyopaque) callconv(.c) gboolean {
    const ctx = context(raw);
    ctx.smoke_recorder_source = 0;
    openShortcutRecorder(ctx);
    return G_SOURCE_REMOVE;
}

fn requestSmokeRecorderCapture(raw: ?*anyopaque) callconv(.c) gboolean {
    const ctx = context(raw);
    ctx.smoke_recorder_capture_source = 0;
    const dialog = ctx.shortcut_dialog orelse return G_SOURCE_REMOVE;
    var event = std.mem.zeroes(GdkEventKey);
    event.keyval = GDK_KEY_F11;
    _ = onShortcutCapture(dialog, &event, ctx);
    return G_SOURCE_REMOVE;
}

fn onTerminalButton(_: *GtkWidget, event: *GdkEventButton, raw: ?*anyopaque) callconv(.c) gboolean {
    if (event.button != 3) return 0;
    openShortcutRecorder(context(raw));
    return 1;
}

fn appendTerminalTab(ctx: *Context, terminal_widget: *GtkWidget, title: [*:0]const u8) c_uint {
    const label = gtk_label_new(title) orelse return 0;
    const index = gtk_notebook_append_page(asNotebook(ctx.tabs.?), terminal_widget, label);
    gtk_notebook_set_tab_reorderable(asNotebook(ctx.tabs.?), terminal_widget, 1);
    ctx.tab_index = @intCast(index);
    return @intCast(index);
}

fn onWindowMap(_: *GtkWidget, raw: ?*anyopaque) callconv(.c) void {
    const ctx = context(raw);
    if (ctx.placement == .x11_top) {
        var x: c_int = 0;
        var y: c_int = 0;
        var width: c_int = 0;
        var height: c_int = 0;
        gtk_window_get_position(asWindow(ctx.window), &x, &y);
        gtk_window_get_size(asWindow(ctx.window), &width, &height);
        if (x == ctx.expected_x and y == ctx.expected_y and width == ctx.expected_width and height == ctx.expected_height)
            emit(ctx, .placement, @intFromEnum(ctx.placement));
    }
    emit(ctx, .shown, 0);
}

fn onWindowUnmap(_: *GtkWidget, raw: ?*anyopaque) callconv(.c) void {
    emit(context(raw), .hidden, 0);
}

fn onTerminalFocus(_: *GtkWidget, _: ?*anyopaque, raw: ?*anyopaque) callconv(.c) gboolean {
    emit(context(raw), .focused, 0);
    return 0;
}

fn requestSmokeHide(raw: ?*anyopaque) callconv(.c) gboolean {
    const ctx = context(raw);
    ctx.smoke_hide_source = 0;
    if (gtk_widget_get_visible(ctx.window) != 0) gtk_widget_hide(ctx.window);
    return G_SOURCE_REMOVE;
}

fn requestSmokeShow(raw: ?*anyopaque) callconv(.c) gboolean {
    const ctx = context(raw);
    if (gtk_widget_get_visible(ctx.window) == 0) toggleDropdown(ctx);
    return G_SOURCE_REMOVE;
}

fn requestSmokeGlobalShortcut(raw: ?*anyopaque) callconv(.c) gboolean {
    const ctx = context(raw);
    ctx.smoke_shortcut_source = 0;
    const bus = ctx.session_bus orelse return G_SOURCE_REMOVE;
    if (!ctx.global_shortcut_registered) return G_SOURCE_REMOVE;
    const reply = g_dbus_connection_call_sync(bus, "org.kde.kglobalaccel", "/component/noctty", "org.kde.kglobalaccel.Component", "invokeShortcut", g_variant_new("(s)", "toggle-window"), null, 0, -1, null, null);
    if (reply) |value| g_variant_unref(value);
    return G_SOURCE_REMOVE;
}

fn requestSmokeMarkerCheck(raw: ?*anyopaque) callconv(.c) gboolean {
    const ctx = context(raw);
    ctx.smoke_marker_source = 0;
    if (markerSeen(asTerminal(ctx.terminal_widget))) emit(ctx, .input_marker, 0);
    return G_SOURCE_REMOVE;
}

fn onWindowDestroy(_: *GtkWidget, _: ?*anyopaque) callconv(.c) void {
    gtk_main_quit();
}

pub fn run(pane_id: u64, shortcut_key: c_int, callback: Callback, callback_data: ?*anyopaque, mode: c_int, smoke: c_int) c_int {
    if (gtk_init_check(null, null) == 0) {
        std.debug.print("NOCTTY could not connect to a Wayland or X11 display.\n", .{});
        return 2;
    }
    const window = gtk_window_new(GTK_WINDOW_TOPLEVEL) orelse return 2;
    const terminal_widget = vte_terminal_new() orelse return 2;
    const terminal = asTerminal(terminal_widget);
    var ctx = Context{
        .window = window,
        .terminal_widget = terminal_widget,
        .pane_id = pane_id,
        .callback = callback,
        .callback_data = callback_data,
        .mode = mode,
        .smoke = smoke,
        .requested_shortcut_key = shortcut_key,
    };

    const shell_raw = g_getenv("SHELL");
    const shell: [*:0]const u8 = if (shell_raw == null or shell_raw.?[0] == 0) "/bin/sh" else shell_raw.?;
    var shell_argv = [_:null]?[*:0]u8{@constCast(shell)};
    var smoke_argv = [_:null]?[*:0]u8{@constCast(@as([*:0]const u8, "/bin/sh"))};
    var pane_buffer: [32]u8 = undefined;
    if (smoke != 0) {
        const pane_text = std.fmt.bufPrintZ(&pane_buffer, "{d}", .{pane_id}) catch return 2;
        _ = g_setenv("NOCTTY_SMOKE_PANE", pane_text.ptr, 1);
        const marker = std.fmt.bufPrintZ(&ctx.smoke_marker_path, "/tmp/noctty-native-input-{d}-{d}", .{ std.c.getpid(), pane_id }) catch return 2;
        _ = std.c.unlink(marker.ptr);
        _ = g_setenv("NOCTTY_SMOKE_MARKER", marker.ptr, 1);
        _ = g_setenv("NOCTTY_SMOKE_DELAY", if (smoke == 3) "5" else if (smoke == 4) "12" else "1.5", 1);
    }

    gtk_window_set_title(asWindow(window), "NOCTTY");
    gtk_window_set_default_size(asWindow(window), 1000, 640);
    gtk_window_set_decorated(asWindow(window), 0);
    gtk_window_set_keep_above(asWindow(window), @intFromBool(mode == 0));
    if (mode == 0) configureDropdownPlacement(&ctx) else configureWindowMode(&ctx);

    const tabs = gtk_notebook_new() orelse return 2;
    gtk_notebook_set_tab_pos(asNotebook(tabs), GTK_POS_TOP);
    ctx.tabs = tabs;
    const split = gtk_paned_new(GTK_ORIENTATION_HORIZONTAL) orelse return 2;
    const secondary_terminal_widget = vte_terminal_new() orelse return 2;
    var secondary = SecondaryContext{
        .terminal_widget = secondary_terminal_widget,
        .pane_id = pane_id + 1,
        .callback = callback,
        .callback_data = callback_data,
    };
    ctx.secondary_terminal_widget = secondary_terminal_widget;
    gtk_paned_pack1(asPaned(split), terminal_widget, 1, 0);
    gtk_paned_pack2(asPaned(split), secondary_terminal_widget, 1, 0);
    _ = appendTerminalTab(&ctx, split, "Terminal 1");
    gtk_container_add(asContainer(window), tabs);

    connect(window, "destroy", &onWindowDestroy, null);
    connect(window, "key-press-event", &onKeyPress, &ctx);
    connect(window, "map", &onWindowMap, &ctx);
    connect(window, "unmap", &onWindowUnmap, &ctx);
    connect(terminal_widget, "focus-in-event", &onTerminalFocus, &ctx);
    connect(terminal_widget, "button-press-event", &onTerminalButton, &ctx);
    connect(terminal, "child-exited", &onChildExited, &ctx);
    connect(terminal, "contents-changed", &onContentsChanged, &ctx);
    connect(terminal_widget, "size-allocate", &onSizeAllocate, &ctx);
    connect(secondary_terminal_widget, "size-allocate", &onSizeAllocate, &ctx);
    connect(secondary_terminal_widget, "size-allocate", &onSecondarySizeAllocate, &secondary);
    connect(asTerminal(secondary_terminal_widget), "contents-changed", &onSecondaryContentsChanged, &secondary);
    connect(asTerminal(secondary_terminal_widget), "child-exited", &onSecondaryChildExited, &secondary);

    vte_terminal_set_scrollback_lines(terminal, 10_000);
    vte_terminal_set_mouse_autohide(terminal, 1);
    _ = registerGlobalShortcut(&ctx);
    vte_terminal_spawn_async(terminal, VTE_PTY_DEFAULT, null, if (smoke != 0) &smoke_argv else &shell_argv, null, G_SPAWN_SEARCH_PATH, null, null, null, -1, null, onSpawned, &ctx);
    vte_terminal_spawn_async(asTerminal(secondary_terminal_widget), VTE_PTY_DEFAULT, null, if (smoke != 0) &smoke_argv else &shell_argv, null, G_SPAWN_SEARCH_PATH, null, null, null, -1, null, onSecondarySpawned, &secondary);

    gtk_widget_show_all(window);
    gtk_widget_grab_focus(terminal_widget);
    if (mode == 0 and smoke == 0 and ctx.global_shortcut_registered) gtk_widget_hide(window);
    ctx.maintenance_timer = g_timeout_add(if (smoke != 0) 100 else 1000, onMaintenanceTimer, &ctx);
    if (smoke != 0) {
        ctx.smoke_resize_source = g_timeout_add(50, requestSmokeResize, &ctx);
        ctx.smoke_marker_source = g_timeout_add(200, requestSmokeMarkerCheck, &ctx);
        if (smoke == 1) {
            ctx.smoke_hide_source = g_timeout_add(500, requestSmokeHide, &ctx);
            ctx.smoke_shortcut_source = g_timeout_add(800, requestSmokeGlobalShortcut, &ctx);
        }
        if (smoke == 3) {
            ctx.smoke_recorder_source = g_timeout_add(300, requestSmokeRecorder, &ctx);
            ctx.smoke_recorder_capture_source = g_timeout_add(600, requestSmokeRecorderCapture, &ctx);
        }
        if (smoke == 4) ctx.smoke_recorder_source = g_timeout_add(300, requestSmokeRecorder, &ctx);
    }
    gtk_main();
    removeSource(&ctx.maintenance_timer);
    clearSmokeSources(&ctx);
    unregisterGlobalShortcut(&ctx);
    if (ctx.layer_shell_library) |*library| library.close();
    return 0;
}

test "GDK shortcut conversion preserves Qt-compatible key and modifier bits" {
    try std.testing.expectEqual(@as(c_int, 0x01000039), qtKeyFromGdk(GDK_KEY_F10, 0));
    try std.testing.expectEqual(@as(c_int, 0x15000010), qtKeyFromGdk(GDK_KEY_Home, GDK_CONTROL_MASK | GDK_SUPER_MASK));
    try std.testing.expectEqual(@as(c_int, 0x06000041), qtKeyFromGdk('A', GDK_SHIFT_MASK | GDK_CONTROL_MASK));
    try std.testing.expectEqual(@as(c_int, 0x01000005), qtKeyFromGdk(GDK_KEY_KP_Enter, 0));
    try std.testing.expectEqual(@as(c_int, 0x01000000), qtKeyFromGdk(GDK_KEY_Escape, 0));
}
