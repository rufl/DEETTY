const std = @import("std");

const GtkWidget = opaque {};
const GtkEventBox = opaque {};
const GtkLabel = opaque {};
const GtkButton = opaque {};
const GtkBin = opaque {};
const GtkContainer = opaque {};
const GtkNotebook = opaque {};
const GtkCssProvider = opaque {};
const GtkStyleProvider = opaque {};
const GtkStyleContext = opaque {};
const GtkBox = opaque {};
const GtkGrid = opaque {};
const GtkFrame = opaque {};
const GtkScrolledWindow = opaque {};
const GtkAdjustment = opaque {};
const GtkImage = opaque {};
const GtkListBox = opaque {};
const GtkListBoxRow = opaque {};
const GtkStack = opaque {};
const GtkDialog = opaque {};
const GObject = opaque {};
const AtkObject = opaque {};
const GdkWindow = opaque {};
const GdkDisplay = opaque {};
const GdkCursor = opaque {};
const GdkScreen = opaque {};
const GType = usize;
const GTypeInstance = extern struct { g_class: ?*anyopaque };
const GError = extern struct {
    domain: c_uint,
    code: c_int,
    message: [*:0]u8,
};
const GList = extern struct {
    data: ?*anyopaque,
    next: ?*GList,
    prev: ?*GList,
};
const GCallback = *const fn () callconv(.c) void;
const GDestroyNotify = *const fn (?*anyopaque) callconv(.c) void;

const FALSE: c_int = 0;
const TRUE: c_int = 1;
const PANGO_ELLIPSIZE_MIDDLE: c_int = 2;
const GTK_STYLE_PROVIDER_PRIORITY_APPLICATION: c_uint = 600;
const GDK_ENTER_NOTIFY_MASK: c_int = 1 << 12;
const GDK_LEAVE_NOTIFY_MASK: c_int = 1 << 13;
const GDK_ARROW: c_int = 2;
const GTK_ORIENTATION_HORIZONTAL: c_int = 0;
const GTK_ORIENTATION_VERTICAL: c_int = 1;
const GTK_ALIGN_FILL: c_int = 0;
const GTK_ALIGN_START: c_int = 1;
const GTK_ALIGN_CENTER: c_int = 3;
const GTK_POLICY_AUTOMATIC: c_int = 1;
const GTK_POLICY_NEVER: c_int = 2;
const GTK_SHADOW_NONE: c_int = 0;
const GTK_ICON_SIZE_LARGE_TOOLBAR: c_int = 3;

extern fn gtk_event_box_new() ?*GtkWidget;
extern fn gtk_event_box_set_visible_window(*GtkEventBox, c_int) void;
extern fn gtk_label_new(?[*:0]const u8) ?*GtkWidget;
extern fn gtk_label_set_xalign(*GtkLabel, f32) void;
extern fn gtk_label_set_single_line_mode(*GtkLabel, c_int) void;
extern fn gtk_label_set_ellipsize(*GtkLabel, c_int) void;
extern fn gtk_label_set_max_width_chars(*GtkLabel, c_int) void;
extern fn gtk_label_set_text(*GtkLabel, [*:0]const u8) void;
extern fn gtk_label_set_markup(*GtkLabel, [*:0]const u8) void;
extern fn gtk_label_set_line_wrap(*GtkLabel, c_int) void;
extern fn gtk_label_set_mnemonic_widget(*GtkLabel, *GtkWidget) void;
extern fn gtk_button_get_label(*GtkButton) ?[*:0]const u8;
extern fn gtk_bin_get_child(*GtkBin) ?*GtkWidget;
extern fn gtk_container_add(*GtkContainer, *GtkWidget) void;
extern fn gtk_container_get_children(*GtkContainer) ?*GList;
extern fn gtk_widget_set_name(*GtkWidget, [*:0]const u8) void;
extern fn gtk_widget_set_size_request(*GtkWidget, c_int, c_int) void;
extern fn gtk_widget_set_hexpand(*GtkWidget, c_int) void;
extern fn gtk_widget_set_can_focus(*GtkWidget, c_int) void;
extern fn gtk_widget_set_no_show_all(*GtkWidget, c_int) void;
extern fn gtk_widget_set_visible(*GtkWidget, c_int) void;
extern fn gtk_widget_set_halign(*GtkWidget, c_int) void;
extern fn gtk_widget_set_valign(*GtkWidget, c_int) void;
extern fn gtk_widget_set_tooltip_text(*GtkWidget, ?[*:0]const u8) void;
extern fn gtk_widget_get_tooltip_text(*GtkWidget) ?[*:0]u8;
extern fn gtk_widget_get_parent(*GtkWidget) ?*GtkWidget;
extern fn gtk_widget_get_window(*GtkWidget) ?*GdkWindow;
extern fn gtk_widget_get_screen(*GtkWidget) ?*GdkScreen;
extern fn gtk_widget_add_events(*GtkWidget, c_int) void;
extern fn gtk_widget_show_all(*GtkWidget) void;
extern fn gtk_widget_destroy(*GtkWidget) void;
extern fn gtk_widget_get_style_context(*GtkWidget) *GtkStyleContext;
extern fn gtk_widget_get_accessible(*GtkWidget) *AtkObject;
extern fn gtk_button_get_type() GType;
extern fn gtk_bin_get_type() GType;
extern fn gtk_box_get_type() GType;
extern fn gtk_container_get_type() GType;
extern fn gtk_label_get_type() GType;
extern fn gtk_notebook_get_type() GType;
extern fn gtk_box_new(c_int, c_int) ?*GtkWidget;
extern fn gtk_box_pack_start(*GtkBox, *GtkWidget, c_int, c_int, c_uint) void;
extern fn gtk_grid_new() ?*GtkWidget;
extern fn gtk_grid_set_row_spacing(*GtkGrid, c_uint) void;
extern fn gtk_grid_set_column_spacing(*GtkGrid, c_uint) void;
extern fn gtk_grid_set_column_homogeneous(*GtkGrid, c_int) void;
extern fn gtk_grid_attach(*GtkGrid, *GtkWidget, c_int, c_int, c_int, c_int) void;
extern fn gtk_frame_new(?[*:0]const u8) ?*GtkWidget;
extern fn gtk_frame_set_label_widget(*GtkFrame, *GtkWidget) void;
extern fn gtk_container_set_border_width(*GtkContainer, c_uint) void;
extern fn gtk_scrolled_window_new(?*anyopaque, ?*anyopaque) ?*GtkWidget;
extern fn gtk_scrolled_window_set_policy(*GtkScrolledWindow, c_int, c_int) void;
extern fn gtk_scrolled_window_set_shadow_type(*GtkScrolledWindow, c_int) void;
extern fn gtk_list_box_row_new() ?*GtkWidget;
extern fn gtk_image_new_from_icon_name([*:0]const u8, c_int) ?*GtkWidget;
extern fn gtk_image_set_pixel_size(*GtkImage, c_int) void;
extern fn gtk_stack_set_visible_child_name(*GtkStack, [*:0]const u8) void;
extern fn gtk_stack_get_visible_child(*GtkStack) ?*GtkWidget;
extern fn gtk_scrolled_window_get_vadjustment(
    *GtkScrolledWindow,
) ?*GtkAdjustment;
extern fn gtk_adjustment_set_value(*GtkAdjustment, f64) void;
extern fn gtk_css_provider_new() ?*GtkCssProvider;
extern fn gtk_css_provider_load_from_data(*GtkCssProvider, [*:0]const u8, isize, ?*?*GError) c_int;
extern fn gtk_style_context_add_provider(*GtkStyleContext, *GtkStyleProvider, c_uint) void;
extern fn gtk_style_context_remove_provider(*GtkStyleContext, *GtkStyleProvider) void;
extern fn gtk_style_context_add_provider_for_screen(*GdkScreen, *GtkStyleProvider, c_uint) void;
extern fn gtk_style_context_add_class(*GtkStyleContext, [*:0]const u8) void;
extern fn atk_object_set_name(*AtkObject, [*:0]const u8) void;
extern fn atk_object_get_name(*AtkObject) ?[*:0]const u8;
extern fn g_type_check_instance_is_a(*GTypeInstance, GType) c_int;
extern fn g_signal_connect_data(?*anyopaque, [*:0]const u8, GCallback, ?*anyopaque, ?*anyopaque, c_uint) c_ulong;
extern fn g_object_unref(?*anyopaque) void;
extern fn g_object_set_data(*GObject, [*:0]const u8, ?*anyopaque) void;
extern fn g_object_set_data_full(*GObject, [*:0]const u8, ?*anyopaque, GDestroyNotify) void;
extern fn g_object_get_data(*GObject, [*:0]const u8) ?*anyopaque;
extern fn g_strdup([*:0]const u8) ?*anyopaque;
extern fn g_markup_printf_escaped([*:0]const u8, ...) ?[*:0]u8;
extern fn g_free(?*anyopaque) void;
extern fn g_error_free(*GError) void;
extern fn g_strcmp0(?[*:0]const u8, ?[*:0]const u8) c_int;
extern fn g_list_free(?*GList) void;
extern fn gdk_window_get_display(*GdkWindow) *GdkDisplay;
extern fn gdk_window_set_cursor(*GdkWindow, ?*GdkCursor) void;
extern fn gdk_cursor_new_from_name(*GdkDisplay, [*:0]const u8) ?*GdkCursor;
extern fn gdk_cursor_new_for_display(*GdkDisplay, c_int) ?*GdkCursor;
extern fn gdk_screen_get_default() ?*GdkScreen;

const label_key = "noctty-pane-info-label";
const text_key = "noctty-pane-info-text";
const tooltip_key = "noctty-pane-info-tooltip";
const revision_key = "noctty-pane-info-revision";
const tab_label_key = "noctty-tab-label-widget";
const tab_close_key = "noctty-tab-close-widget";
const compact_tab_css =
    "notebook.noctty-tab-notebook > header { margin: 0; padding: 0 5px; border-width: 0; box-shadow: none; min-width: 0; min-height: 0; background: @theme_bg_color; }" ++
    "notebook.noctty-tab-notebook > header > tabs { margin: 0; padding: 0; border-width: 0; box-shadow: none; min-width: 0; min-height: 0; }" ++
    "notebook.noctty-tab-notebook > header > tabs > tab { margin: 0 4px 0 0; padding: 0 8px; border-width: 0; border-radius: 9px 9px 0 0; box-shadow: none; min-width: 0; min-height: 0; background: alpha(@theme_fg_color, 0.06); color: alpha(@theme_fg_color, 0.72); }" ++
    "notebook.noctty-tab-notebook > header > tabs > tab:checked { background: @theme_base_color; color: @theme_text_color; box-shadow: inset 0 2px @theme_selected_bg_color; }" ++
    "notebook.noctty-tab-notebook > header > tabs > tab:hover { background: alpha(@theme_fg_color, 0.12); color: @theme_fg_color; }" ++
    "list.sidebar > row.noctty-settings-category { margin: 2px 4px; padding: 0; min-height: 48px; border-radius: 8px; }" ++
    "list.sidebar > row.noctty-settings-category:selected { background: alpha(@theme_selected_bg_color, 0.18); color: @theme_text_color; }" ++
    "list.sidebar > row.noctty-settings-category:focus { outline: 2px solid @theme_selected_bg_color; outline-offset: -2px; }" ++
    ".noctty-tab-content, .noctty-tab-label { margin: 0; padding: 0; border-radius: 9px 9px 0 0; }" ++
    "button.noctty-tab-close, button.noctty-tab-action { margin: 0; padding: 0; border-width: 0; border-radius: 8px; box-shadow: none; min-width: 28px; min-height: 22px; color: alpha(@theme_fg_color, 0.72); background: transparent; }" ++
    "button.noctty-tab-close:hover, button.noctty-tab-action:hover { color: @theme_fg_color; background: alpha(@theme_fg_color, 0.10); }" ++
    "button.noctty-tab-close:active, button.noctty-tab-action:active { background: alpha(@theme_selected_bg_color, 0.24); }" ++
    "button.noctty-tab-close:focus, button.noctty-tab-action:focus { outline: 2px solid @theme_selected_bg_color; outline-offset: -2px; }" ++
    "entry.noctty-tab-rename { margin: 0; padding: 0 2px; min-height: 18px; }" ++
    ".noctty-grid-area, .noctty-grid-area:focus { outline-style: none; outline-width: 0; border-width: 0; border-color: transparent; box-shadow: none; }";

var compact_tab_provider: ?*GtkCssProvider = null;

fn object(widget: *GtkWidget) *GObject {
    return @ptrCast(widget);
}

fn isA(widget: *GtkWidget, get_type: *const fn () callconv(.c) GType) bool {
    return g_type_check_instance_is_a(@ptrCast(@alignCast(widget)), get_type()) != 0;
}

fn compactTabProvider() ?*GtkCssProvider {
    if (compact_tab_provider) |provider| return provider;
    const provider = gtk_css_provider_new() orelse return null;
    var error_value: ?*GError = null;
    _ = gtk_css_provider_load_from_data(provider, compact_tab_css, -1, &error_value);
    if (error_value) |err| {
        defer g_error_free(err);
        defer g_object_unref(provider);
        std.debug.print("native_grid_compact_tab_css_failed message={s}\n", .{std.mem.span(err.message)});
        return null;
    }
    compact_tab_provider = provider;
    return provider;
}

fn actionButtonWindow(widget: *GtkWidget) ?*GdkWindow {
    var candidate: ?*GtkWidget = widget;
    while (candidate) |current| : (candidate = gtk_widget_get_parent(current))
        if (gtk_widget_get_window(current)) |window| return window;
    return null;
}

fn onActionButtonEnter(widget: *GtkWidget, _: ?*anyopaque, _: ?*anyopaque) callconv(.c) c_int {
    const window = actionButtonWindow(widget) orelse return FALSE;
    const display = gdk_window_get_display(window);
    const cursor = gdk_cursor_new_from_name(display, "default") orelse
        gdk_cursor_new_for_display(display, GDK_ARROW) orelse return FALSE;
    defer g_object_unref(cursor);
    gdk_window_set_cursor(window, cursor);
    g_object_set_data(object(widget), "noctty-action-pointer-active", @ptrFromInt(1));
    g_object_set_data(object(widget), "noctty-action-pointer-name", @ptrCast(@constCast("default")));
    return FALSE;
}

fn onActionButtonLeave(widget: *GtkWidget, _: ?*anyopaque, _: ?*anyopaque) callconv(.c) c_int {
    if (actionButtonWindow(widget)) |window| gdk_window_set_cursor(window, null);
    g_object_set_data(object(widget), "noctty-action-pointer-active", null);
    return FALSE;
}

pub export fn noctty_action_button_event_window(widget: ?*GtkWidget) ?*GdkWindow {
    return actionButtonWindow(widget orelse return null);
}

pub export fn noctty_action_button_enter(widget: ?*GtkWidget) c_int {
    return onActionButtonEnter(widget orelse return FALSE, null, null);
}

pub export fn noctty_action_button_leave(widget: ?*GtkWidget) c_int {
    return onActionButtonLeave(widget orelse return FALSE, null, null);
}

fn setFallbackTooltip(button: *GtkWidget) void {
    if (gtk_widget_get_tooltip_text(button)) |tooltip| {
        defer g_free(tooltip);
        if (tooltip[0] != 0) return;
    }
    var source = gtk_button_get_label(@ptrCast(button));
    if (source == null or source.?[0] == 0) source = atk_object_get_name(gtk_widget_get_accessible(button));
    const text = source orelse return;
    if (text[0] == 0) return;

    const source_len = std.mem.len(text);
    const buffer = std.heap.c_allocator.allocSentinel(u8, source_len, 0) catch return;
    defer std.heap.c_allocator.free(buffer);
    var written: usize = 0;
    var index: usize = 0;
    while (index < source_len) : (index += 1) {
        if (text[index] != '_') {
            buffer[written] = text[index];
            written += 1;
        } else if (index + 1 < source_len and text[index + 1] == '_') {
            buffer[written] = '_';
            written += 1;
            index += 1;
        }
    }
    const trimmed = std.mem.trim(u8, buffer[0..written], " \t\r\n\x0b\x0c");
    if (trimmed.len == 0) return;
    buffer[@intFromPtr(trimmed.ptr) - @intFromPtr(buffer.ptr) + trimmed.len] = 0;
    gtk_widget_set_tooltip_text(button, @ptrCast(trimmed.ptr));
}

pub export fn noctty_configure_action_button(button: ?*GtkWidget, tooltip: ?[*:0]const u8) void {
    const widget = button orelse return;
    if (!isA(widget, gtk_button_get_type)) return;
    if (tooltip) |text| {
        if (text[0] != 0) gtk_widget_set_tooltip_text(widget, text) else setFallbackTooltip(widget);
    } else setFallbackTooltip(widget);
    if (g_object_get_data(object(widget), "noctty-action-affordance") != null) return;
    gtk_widget_add_events(widget, GDK_ENTER_NOTIFY_MASK | GDK_LEAVE_NOTIFY_MASK);
    _ = g_signal_connect_data(widget, "enter-notify-event", @ptrCast(&onActionButtonEnter), null, null, 0);
    _ = g_signal_connect_data(widget, "leave-notify-event", @ptrCast(&onActionButtonLeave), null, null, 0);
    g_object_set_data(object(widget), "noctty-action-affordance", @ptrFromInt(1));
}

pub export fn noctty_prepare_action_button_tree(widget: ?*GtkWidget) void {
    const current = widget orelse return;
    if (isA(current, gtk_button_get_type)) noctty_configure_action_button(current, null);
    if (!isA(current, gtk_container_get_type)) return;
    const children = gtk_container_get_children(@ptrCast(current));
    defer g_list_free(children);
    var item = children;
    while (item) |child| : (item = child.next)
        noctty_prepare_action_button_tree(if (child.data) |data| @ptrCast(data) else null);
}

pub export fn noctty_show_all_with_action_affordances(widget: ?*GtkWidget) void {
    const current = widget orelse return;
    noctty_prepare_action_button_tree(current);
    gtk_widget_show_all(current);
}

pub export fn noctty_install_compact_tab_styles(notebook: ?*GtkWidget) void {
    const widget = notebook orelse return;
    if (!isA(widget, gtk_notebook_get_type)) return;
    const provider = compactTabProvider() orelse return;
    const screen = gtk_widget_get_screen(widget) orelse gdk_screen_get_default();
    if (screen) |value| gtk_style_context_add_provider_for_screen(value, @ptrCast(provider), GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);
    gtk_style_context_add_class(gtk_widget_get_style_context(widget), "noctty-tab-notebook");
}

fn tabChildOfType(tab_widget: *GtkWidget, get_type: *const fn () callconv(.c) GType) ?*GtkWidget {
    if (!isA(tab_widget, gtk_bin_get_type)) return null;
    const content = gtk_bin_get_child(@ptrCast(tab_widget)) orelse return null;
    if (isA(content, get_type)) return content;
    if (!isA(content, gtk_box_get_type)) return null;
    const children = gtk_container_get_children(@ptrCast(content));
    defer g_list_free(children);
    var item = children;
    while (item) |child| : (item = child.next) {
        const widget: *GtkWidget = @ptrCast(child.data orelse continue);
        if (isA(widget, get_type)) return widget;
    }
    return null;
}

pub export fn noctty_tab_label_from_widget(tab_widget: ?*GtkWidget) ?*GtkWidget {
    const tab = tab_widget orelse return null;
    if (g_object_get_data(object(tab), tab_label_key)) |value| return @ptrCast(value);
    const label = tabChildOfType(tab, gtk_label_get_type) orelse return null;
    g_object_set_data(object(tab), tab_label_key, label);
    return label;
}

pub export fn noctty_tab_close_button_from_widget(tab_widget: ?*GtkWidget) ?*GtkWidget {
    const tab = tab_widget orelse return null;
    if (g_object_get_data(object(tab), tab_close_key)) |value| return @ptrCast(value);
    const close = tabChildOfType(tab, gtk_button_get_type) orelse return null;
    g_object_set_data(object(tab), tab_close_key, close);
    return close;
}

pub export fn noctty_tab_color_uses_dark_text(rgb: u32) c_int {
    const red: u64 = (rgb >> 16) & 0xff;
    const green: u64 = (rgb >> 8) & 0xff;
    const blue: u64 = rgb & 0xff;
    return @intFromBool(red * red * 2126 + green * green * 7152 + blue * blue * 722 >= 116394750);
}

fn removeTabColorProvider(tab_widget: *GtkWidget, widgets: [3]?*GtkWidget) void {
    const raw_provider = g_object_get_data(object(tab_widget), "noctty-tab-color-provider") orelse return;
    const provider: *GtkStyleProvider = @ptrCast(raw_provider);
    for (widgets) |widget|
        if (widget) |value| gtk_style_context_remove_provider(gtk_widget_get_style_context(value), provider);
    g_object_set_data(object(tab_widget), "noctty-tab-color-provider", null);
}

pub export fn noctty_apply_tab_color_style(tab_widget: ?*GtkWidget, rgb: u32, is_active: c_int) void {
    const tab = tab_widget orelse return;
    if (!isA(tab, gtk_bin_get_type)) return;
    const cached_rgb: u32 = if (g_object_get_data(object(tab), "noctty-tab-color-rgb")) |value| @intCast(@intFromPtr(value)) else 0;
    const cached_active = g_object_get_data(object(tab), "noctty-tab-color-active") != null;
    const active = is_active != 0;
    if (cached_rgb == rgb and (rgb == 0 or cached_active == active)) return;

    const content = gtk_bin_get_child(@ptrCast(tab));
    const label = noctty_tab_label_from_widget(tab);
    const close = noctty_tab_close_button_from_widget(tab);
    removeTabColorProvider(tab, .{ content, label, close });
    g_object_set_data(object(tab), "noctty-tab-color-rgb", if (rgb == 0) null else @ptrFromInt(rgb));
    g_object_set_data(object(tab), "noctty-tab-color-active", if (active) @ptrFromInt(1) else null);
    if (rgb == 0 or content == null) return;

    const foreground = if (noctty_tab_color_uses_dark_text(rgb) != 0) "#11151b" else "#ffffff";
    var css_buffer: [768]u8 = undefined;
    const css = std.fmt.bufPrintZ(
        &css_buffer,
        ".noctty-tab-content {{ background-color: #{x:0>6}; color: {s}; border-radius: 9px 9px 0 0; box-shadow: inset 0 {s} 0 rgba(255,255,255,{s}); }}" ++
            ".noctty-tab-label {{ color: {s}; }}" ++
            "button.noctty-tab-close {{ color: {s}; background: transparent; border-radius: 8px; }}",
        .{ rgb & 0xffffff, foreground, if (active) "-2px" else "-1px", if (active) "0.42" else "0.20", foreground, foreground },
    ) catch return;
    const provider = gtk_css_provider_new() orelse return;
    var error_value: ?*GError = null;
    _ = gtk_css_provider_load_from_data(provider, css, -1, &error_value);
    if (error_value) |err| {
        defer g_error_free(err);
        defer g_object_unref(provider);
        std.debug.print("native_grid_tab_color_css_failed message={s}\n", .{std.mem.span(err.message)});
        return;
    }
    for ([3]?*GtkWidget{ content, label, close }) |widget|
        if (widget) |value| gtk_style_context_add_provider(gtk_widget_get_style_context(value), @ptrCast(provider), GTK_STYLE_PROVIDER_PRIORITY_APPLICATION + 2);
    g_object_set_data_full(object(tab), "noctty-tab-color-provider", provider, g_object_unref);
}

fn settingsHeadingNew(
    title: ?[*:0]const u8,
    description: ?[*:0]const u8,
) ?*GtkWidget {
    const title_text = title orelse return null;
    const detail_text = description orelse return null;
    const box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 4) orelse return null;
    const heading = gtk_label_new(null) orelse return null;
    const markup = g_markup_printf_escaped(
        "<span size=\"x-large\" weight=\"bold\">%s</span>",
        title_text,
    ) orelse return null;
    defer g_free(markup);
    gtk_label_set_markup(@ptrCast(heading), markup);
    gtk_label_set_xalign(@ptrCast(heading), 0.0);

    const detail = gtk_label_new(detail_text) orelse return null;
    gtk_label_set_xalign(@ptrCast(detail), 0.0);
    gtk_label_set_line_wrap(@ptrCast(detail), TRUE);
    gtk_label_set_max_width_chars(@ptrCast(detail), 58);
    gtk_style_context_add_class(gtk_widget_get_style_context(detail), "dim-label");
    gtk_box_pack_start(@ptrCast(box), heading, FALSE, FALSE, 0);
    gtk_box_pack_start(@ptrCast(box), detail, FALSE, FALSE, 0);
    return box;
}

pub export fn noctty_settings_grid_new() ?*GtkWidget {
    const grid = gtk_grid_new() orelse return null;
    gtk_grid_set_row_spacing(@ptrCast(grid), 12);
    gtk_grid_set_column_spacing(@ptrCast(grid), 24);
    gtk_grid_set_column_homogeneous(@ptrCast(grid), FALSE);
    gtk_widget_set_hexpand(grid, TRUE);
    gtk_widget_set_halign(grid, GTK_ALIGN_FILL);
    return grid;
}

pub export fn noctty_settings_grid_attach_control(
    grid: ?*GtkWidget,
    text: ?[*:0]const u8,
    control: ?*GtkWidget,
    row: c_int,
) void {
    const grid_widget = grid orelse return;
    const control_widget = control orelse return;
    const label = gtk_label_new(text orelse return) orelse return;
    gtk_label_set_xalign(@ptrCast(label), 0.0);
    gtk_label_set_mnemonic_widget(@ptrCast(label), control_widget);
    gtk_widget_set_halign(label, GTK_ALIGN_START);
    gtk_widget_set_valign(label, GTK_ALIGN_CENTER);
    gtk_widget_set_size_request(label, 176, -1);
    gtk_widget_set_hexpand(control_widget, TRUE);
    gtk_widget_set_halign(control_widget, GTK_ALIGN_FILL);
    gtk_grid_attach(@ptrCast(grid_widget), label, 0, row, 1, 1);
    gtk_grid_attach(@ptrCast(grid_widget), control_widget, 1, row, 1, 1);
}

pub export fn noctty_settings_group_new(
    title: ?[*:0]const u8,
    child: ?*GtkWidget,
) ?*GtkWidget {
    const child_widget = child orelse return null;
    const frame = gtk_frame_new(null) orelse return null;
    const label = gtk_label_new(null) orelse return null;
    const markup = g_markup_printf_escaped("<b>%s</b>", title orelse return null) orelse
        return null;
    defer g_free(markup);
    gtk_label_set_markup(@ptrCast(label), markup);
    gtk_frame_set_label_widget(@ptrCast(frame), label);
    gtk_container_set_border_width(@ptrCast(child_widget), 16);
    gtk_widget_set_hexpand(child_widget, TRUE);
    gtk_widget_set_halign(child_widget, GTK_ALIGN_FILL);
    gtk_container_add(@ptrCast(frame), child_widget);
    gtk_widget_set_hexpand(frame, TRUE);
    gtk_widget_set_halign(frame, GTK_ALIGN_FILL);
    return frame;
}

pub export fn noctty_settings_page_new(
    title: ?[*:0]const u8,
    description: ?[*:0]const u8,
    body_out: ?**GtkWidget,
) ?*GtkWidget {
    const output = body_out orelse return null;
    const scrolled = gtk_scrolled_window_new(null, null) orelse return null;
    gtk_scrolled_window_set_policy(
        @ptrCast(scrolled),
        GTK_POLICY_AUTOMATIC,
        GTK_POLICY_AUTOMATIC,
    );
    gtk_scrolled_window_set_shadow_type(@ptrCast(scrolled), GTK_SHADOW_NONE);
    gtk_widget_set_hexpand(scrolled, TRUE);
    const body = gtk_box_new(GTK_ORIENTATION_VERTICAL, 20) orelse return null;
    gtk_container_set_border_width(@ptrCast(body), 28);
    gtk_widget_set_hexpand(body, TRUE);
    gtk_widget_set_halign(body, GTK_ALIGN_FILL);
    const heading = settingsHeadingNew(title, description) orelse return null;
    gtk_box_pack_start(@ptrCast(body), heading, FALSE, FALSE, 0);
    gtk_container_add(@ptrCast(scrolled), body);
    output.* = body;
    return scrolled;
}

pub export fn noctty_settings_category_row_new(
    icon_name: ?[*:0]const u8,
    label_text: ?[*:0]const u8,
    page_name: ?[*:0]const u8,
) ?*GtkWidget {
    const label_value = label_text orelse return null;
    const row = gtk_list_box_row_new() orelse return null;
    gtk_widget_set_name(row, "noctty-settings-category");
    gtk_widget_set_can_focus(row, TRUE);
    gtk_widget_set_size_request(row, -1, 52);
    var tooltip_buffer: [96]u8 = undefined;
    const tooltip = std.fmt.bufPrintZ(
        &tooltip_buffer,
        "Open {s} settings",
        .{std.mem.span(label_value)},
    ) catch "Open settings category";
    gtk_widget_set_tooltip_text(row, tooltip.ptr);
    gtk_style_context_add_class(gtk_widget_get_style_context(row), "noctty-settings-category");
    const accessible = gtk_widget_get_accessible(row);
    atk_object_set_name(accessible, label_value);
    const box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 14) orelse return null;
    const icon = gtk_image_new_from_icon_name(
        icon_name orelse return null,
        GTK_ICON_SIZE_LARGE_TOOLBAR,
    ) orelse return null;
    const label = gtk_label_new(label_value) orelse return null;
    gtk_image_set_pixel_size(@ptrCast(icon), 24);
    gtk_label_set_xalign(@ptrCast(label), 0.0);
    gtk_widget_set_hexpand(label, TRUE);
    gtk_container_set_border_width(@ptrCast(box), 14);
    gtk_box_pack_start(@ptrCast(box), icon, FALSE, FALSE, 0);
    gtk_box_pack_start(@ptrCast(box), label, TRUE, TRUE, 0);
    gtk_container_add(@ptrCast(row), box);
    g_object_set_data_full(
        object(row),
        "noctty-settings-page",
        g_strdup(page_name orelse return null),
        g_free,
    );
    return row;
}

pub export fn noctty_settings_category_selected(
    _: ?*GtkListBox,
    row: ?*GtkListBoxRow,
    user_data: ?*anyopaque,
) void {
    const selected = row orelse return;
    const stack: *GtkStack = @ptrCast(user_data orelse return);
    const raw_name = g_object_get_data(
        @ptrCast(selected),
        "noctty-settings-page",
    ) orelse return;
    gtk_stack_set_visible_child_name(stack, @ptrCast(raw_name));
    const visible = gtk_stack_get_visible_child(stack) orelse return;
    const adjustment = gtk_scrolled_window_get_vadjustment(
        @ptrCast(visible),
    ) orelse return;
    gtk_adjustment_set_value(adjustment, 0.0);
}
pub export fn noctty_settings_response(
    dialog: ?*GtkDialog,
    _: c_int,
    _: ?*anyopaque,
) void {
    gtk_widget_destroy(@ptrCast(dialog orelse return));
}

fn addStyle(strip: *GtkWidget, label: *GtkWidget) void {
    const provider = gtk_css_provider_new() orelse return;
    _ = gtk_css_provider_load_from_data(provider, "#noctty-pane-info {" ++
        " background-color: alpha(@theme_fg_color, 0.035);" ++
        " border-top: 1px solid alpha(@theme_fg_color, 0.09);" ++
        "}" ++
        "#noctty-pane-info label {" ++
        " color: alpha(@theme_fg_color, 0.72);" ++
        " font-size: 0.9em;" ++
        " padding: 1px 6px;" ++
        "}", -1, null);
    gtk_style_context_add_provider(gtk_widget_get_style_context(strip), @ptrCast(provider), GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);
    gtk_style_context_add_provider(gtk_widget_get_style_context(label), @ptrCast(provider), GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);
    g_object_unref(provider);
}

pub export fn noctty_pane_info_strip_new(enabled: c_int) ?*GtkWidget {
    const strip = gtk_event_box_new() orelse return null;
    const label = gtk_label_new("") orelse {
        g_object_unref(strip);
        return null;
    };
    gtk_widget_set_name(strip, "noctty-pane-info");
    gtk_widget_set_size_request(strip, -1, 18);
    gtk_event_box_set_visible_window(@ptrCast(strip), TRUE);
    gtk_label_set_xalign(@ptrCast(label), 0.0);
    gtk_label_set_single_line_mode(@ptrCast(label), TRUE);
    gtk_label_set_ellipsize(@ptrCast(label), PANGO_ELLIPSIZE_MIDDLE);
    gtk_label_set_max_width_chars(@ptrCast(label), 96);
    gtk_widget_set_hexpand(label, TRUE);
    gtk_container_add(@ptrCast(strip), label);
    addStyle(strip, label);
    g_object_set_data(object(strip), label_key, label);
    atk_object_set_name(gtk_widget_get_accessible(strip), "Active terminal pane information");
    noctty_pane_info_strip_set_enabled(strip, enabled);
    return strip;
}

pub export fn noctty_pane_info_strip_set_enabled(strip: ?*GtkWidget, enabled: c_int) void {
    const widget = strip orelse return;
    gtk_widget_set_no_show_all(widget, if (enabled == 0) TRUE else FALSE);
    gtk_widget_set_visible(widget, enabled);
}

pub export fn noctty_pane_info_strip_update(strip: ?*GtkWidget, text: ?[*:0]const u8, tooltip: ?[*:0]const u8) c_int {
    const widget = strip orelse return FALSE;
    const next_text = text orelse return FALSE;
    const next_tooltip = tooltip orelse return FALSE;
    const previous_text: ?[*:0]const u8 = if (g_object_get_data(object(widget), text_key)) |value| @ptrCast(value) else null;
    const previous_tooltip: ?[*:0]const u8 = if (g_object_get_data(object(widget), tooltip_key)) |value| @ptrCast(value) else null;
    if (g_strcmp0(previous_text, next_text) == 0 and g_strcmp0(previous_tooltip, next_tooltip) == 0) return FALSE;

    if (g_object_get_data(object(widget), label_key)) |label| gtk_label_set_text(@ptrCast(label), next_text);
    gtk_widget_set_tooltip_text(widget, next_tooltip);
    g_object_set_data_full(object(widget), text_key, g_strdup(next_text), g_free);
    g_object_set_data_full(object(widget), tooltip_key, g_strdup(next_tooltip), g_free);
    const revision = noctty_pane_info_strip_revision(widget) +% 1;
    g_object_set_data(object(widget), revision_key, if (revision == 0) null else @ptrFromInt(revision));
    return TRUE;
}

pub export fn noctty_pane_info_strip_text(strip: ?*GtkWidget) ?[*:0]const u8 {
    const widget = strip orelse return null;
    const value = g_object_get_data(object(widget), text_key) orelse return null;
    return @ptrCast(value);
}

pub export fn noctty_pane_info_strip_tooltip(strip: ?*GtkWidget) ?[*:0]const u8 {
    const widget = strip orelse return null;
    const value = g_object_get_data(object(widget), tooltip_key) orelse return null;
    return @ptrCast(value);
}

pub export fn noctty_pane_info_strip_revision(strip: ?*GtkWidget) c_uint {
    const widget = strip orelse return 0;
    const value = g_object_get_data(object(widget), revision_key) orelse return 0;
    return @intCast(@intFromPtr(value));
}
