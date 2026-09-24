const std = @import("std");

const GtkWidget = opaque {};
const GtkEventBox = opaque {};
const GtkLabel = opaque {};
const GtkButton = opaque {};
const GtkBin = opaque {};
const GtkContainer = opaque {};
const GtkNotebook = opaque {};
const GtkWindow = opaque {};

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
const GtkFileChooser = opaque {};
const GtkEntry = opaque {};
const GtkTextView = opaque {};
const GtkTextBuffer = opaque {};
const GtkComboBox = opaque {};
const GtkComboBoxText = opaque {};
const GtkSpinButton = opaque {};
const GtkClipboard = opaque {};
const GtkIMContext = opaque {};

const GtkToggleButton = opaque {};
const GtkRange = opaque {};
const GtkScale = opaque {};
const GtkFlowBox = opaque {};
const GtkMenuItem = opaque {};
const GtkMenuShell = opaque {};
const GtkPaned = opaque {};
const GtkOrientable = opaque {};
const GObject = opaque {};
const AtkObject = opaque {};
const GdkWindow = opaque {};
const GdkDisplay = opaque {};
const GdkFrameClock = opaque {};
const GdkCursor = opaque {};
const GdkScreen = opaque {};
const GtkAllocation = extern struct {
    x: c_int,
    y: c_int,
    width: c_int,
    height: c_int,
};
const GdkRectangle = extern struct {
    x: c_int,
    y: c_int,
    width: c_int,
    height: c_int,
};
const GdkGeometry = extern struct {
    min_width: c_int,
    min_height: c_int,
    max_width: c_int,
    max_height: c_int,
    base_width: c_int,
    base_height: c_int,
    width_inc: c_int,
    height_inc: c_int,
    min_aspect: f64,
    max_aspect: f64,
    win_gravity: c_int,
};
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
const GSList = opaque {};
const GtkClipboardTextReceivedCallback = *const fn (
    ?*GtkClipboard,
    ?[*:0]const u8,
    ?*anyopaque,
) callconv(.c) void;
const GCallback = *const fn () callconv(.c) void;
const GtkTickCallback = *const fn (
    *GtkWidget,
    *anyopaque,
    ?*anyopaque,
) callconv(.c) c_int;
const GDestroyNotify = *const fn (?*anyopaque) callconv(.c) void;

const FALSE: c_int = 0;
const TRUE: c_int = 1;
const GTK_FILE_CHOOSER_ACTION_SAVE: c_int = 1;
const GTK_FILE_CHOOSER_ACTION_OPEN: c_int = 0;
const GTK_RESPONSE_CANCEL: c_int = -6;
const GTK_RESPONSE_ACCEPT: c_int = -3;
const GTK_DIALOG_MODAL: c_int = 1;
const GTK_DIALOG_DESTROY_WITH_PARENT: c_int = 2;
const GTK_MESSAGE_ERROR: c_int = 3;
const GTK_BUTTONS_CLOSE: c_int = 2;
const PANGO_ELLIPSIZE_MIDDLE: c_int = 2;
const GTK_STYLE_PROVIDER_PRIORITY_APPLICATION: c_uint = 600;
const GDK_ENTER_NOTIFY_MASK: c_int = 1 << 12;
const GDK_LEAVE_NOTIFY_MASK: c_int = 1 << 13;
const GDK_BUTTON_RELEASE_MASK: c_int = 1 << 9;
const GDK_ARROW: c_int = 2;
const GTK_ORIENTATION_HORIZONTAL: c_int = 0;
const GTK_ORIENTATION_VERTICAL: c_int = 1;
const GTK_ALIGN_FILL: c_int = 0;
const GTK_ALIGN_START: c_int = 1;
const GTK_ALIGN_END: c_int = 2;
const GTK_ALIGN_CENTER: c_int = 3;
const GTK_POLICY_AUTOMATIC: c_int = 1;
const GTK_POLICY_NEVER: c_int = 2;
const GTK_SHADOW_NONE: c_int = 0;
const GTK_ICON_SIZE_LARGE_TOOLBAR: c_int = 3;
const GTK_ICON_SIZE_MENU: c_int = 1;
const GTK_RELIEF_NONE: c_int = 2;
const GTK_SELECTION_BROWSE: c_int = 2;
const GTK_STACK_TRANSITION_TYPE_CROSSFADE: c_int = 1;
const GTK_SELECTION_SINGLE: c_int = 1;
const GTK_WRAP_WORD_CHAR: c_int = 3;
const GTK_SHADOW_IN: c_int = 1;
const GTK_SELECTION_NONE: c_int = 0;
const GTK_POS_RIGHT: c_int = 1;
const ATK_ROLE_STATUSBAR: c_int = 53;
const GDK_KEY_PRESS_MASK: c_int = 1 << 10;
const GDK_BUTTON_PRESS_MASK: c_int = 1 << 8;
const GDK_SCROLL_MASK: c_int = 1 << 21;
const GDK_SMOOTH_SCROLL_MASK: c_int = 1 << 23;
const GDK_POINTER_MOTION_MASK: c_int = 1 << 2;

extern fn gtk_event_box_new() ?*GtkWidget;
extern fn gtk_event_box_set_visible_window(*GtkEventBox, c_int) void;
extern fn gtk_event_box_set_above_child(*GtkEventBox, c_int) void;
extern fn gtk_menu_new() ?*GtkWidget;
extern fn gtk_menu_item_new_with_label([*:0]const u8) ?*GtkWidget;
extern fn gtk_radio_menu_item_new_with_label(
    ?*GSList,
    [*:0]const u8,
) ?*GtkWidget;
extern fn gtk_radio_menu_item_get_group(*GtkWidget) ?*GSList;
extern fn gtk_check_menu_item_set_active(*GtkWidget, c_int) void;
extern fn gtk_menu_item_set_submenu(*GtkMenuItem, *GtkWidget) void;
extern fn gtk_menu_shell_append(*GtkMenuShell, *GtkWidget) void;
extern fn gtk_menu_popdown(*GtkWidget) void;
extern fn gtk_menu_item_get_label(*GtkMenuItem) ?[*:0]const u8;
extern fn gtk_menu_item_get_submenu(*GtkMenuItem) ?*GtkWidget;
extern fn gtk_menu_item_activate(*GtkMenuItem) void;
extern fn gtk_menu_shell_select_item(*GtkMenuShell, *GtkWidget) void;
extern fn gtk_menu_shell_activate_item(*GtkMenuShell, *GtkWidget, c_int) c_int;
extern fn gtk_menu_get_attach_widget(*GtkWidget) ?*GtkWidget;
extern fn gtk_menu_popup_at_widget(
    *GtkWidget,
    *GtkWidget,
    c_int,
    c_int,
    ?*anyopaque,
) void;
extern fn gtk_menu_popup_at_rect(
    *GtkWidget,
    *GdkWindow,
    *const GdkRectangle,
    c_int,
    c_int,
    ?*anyopaque,
) void;
extern fn gtk_separator_menu_item_new() ?*GtkWidget;
extern fn gtk_label_new(?[*:0]const u8) ?*GtkWidget;
extern fn gtk_label_set_xalign(*GtkLabel, f32) void;
extern fn gtk_label_set_single_line_mode(*GtkLabel, c_int) void;
extern fn gtk_label_set_ellipsize(*GtkLabel, c_int) void;
extern fn gtk_label_set_max_width_chars(*GtkLabel, c_int) void;
extern fn gtk_label_set_text(*GtkLabel, [*:0]const u8) void;
extern fn gtk_label_get_text(*GtkLabel) ?[*:0]const u8;
extern fn gtk_message_dialog_new(
    *GtkWidget,
    c_int,
    c_int,
    c_int,
    [*:0]const u8,
    ...,
) ?*GtkWidget;
extern fn gtk_message_dialog_format_secondary_text(
    *GtkWidget,
    [*:0]const u8,
    ...,
) void;
extern fn gtk_dialog_add_buttons(*GtkWidget, [*:0]const u8, c_int, ...) void;
extern fn gtk_dialog_set_default_response(*GtkWidget, c_int) void;
extern fn gtk_label_set_markup(*GtkLabel, [*:0]const u8) void;
extern fn gtk_label_set_line_wrap(*GtkLabel, c_int) void;
extern fn gtk_label_set_mnemonic_widget(*GtkLabel, *GtkWidget) void;
extern fn gtk_info_bar_new_with_buttons([*:0]const u8, c_int, ...) ?*GtkWidget;
extern fn gtk_info_bar_set_message_type(*GtkWidget, c_int) void;
extern fn gtk_info_bar_get_content_area(*GtkWidget) *GtkWidget;
extern fn gtk_dialog_get_content_area(*GtkDialog) *GtkWidget;
extern fn gtk_dialog_run(*GtkDialog) c_int;
extern fn gtk_dialog_response(*GtkDialog, c_int) void;
extern fn gtk_search_entry_new() ?*GtkWidget;
extern fn gtk_entry_set_placeholder_text(*GtkEntry, [*:0]const u8) void;
extern fn gtk_entry_set_max_length(*GtkEntry, c_int) void;
extern fn gtk_entry_set_visibility(*GtkEntry, c_int) void;
extern fn gtk_button_new_with_label([*:0]const u8) ?*GtkWidget;
extern fn gtk_button_new_from_icon_name([*:0]const u8, c_int) ?*GtkWidget;
extern fn gtk_button_set_relief(*GtkButton, c_int) void;
extern fn gtk_button_set_label(*GtkButton, [*:0]const u8) void;
extern fn gtk_button_clicked(*GtkButton) void;
extern fn gtk_check_button_new_with_label([*:0]const u8) ?*GtkWidget;
extern fn gtk_toggle_button_get_active(*GtkToggleButton) c_int;
extern fn gtk_toggle_button_set_active(*GtkToggleButton, c_int) void;
extern fn gtk_entry_new() ?*GtkWidget;
extern fn gtk_entry_set_text(*GtkEntry, [*:0]const u8) void;
extern fn gtk_entry_get_text(*GtkEntry) ?[*:0]const u8;
extern fn gtk_entry_set_icon_from_icon_name(
    *GtkEntry, c_int, ?[*:0]const u8) void;
extern fn gtk_entry_set_icon_tooltip_text(
    *GtkEntry, c_int, ?[*:0]const u8) void;
extern fn gtk_entry_set_has_frame(*GtkEntry, c_int) void;
extern fn gtk_entry_set_alignment(*GtkEntry, f32) void;
extern fn gtk_entry_set_width_chars(*GtkEntry, c_int) void;
extern fn gtk_entry_set_max_width_chars(*GtkEntry, c_int) void;
extern fn gtk_spin_button_new_with_range(f64, f64, f64) ?*GtkWidget;
extern fn gtk_spin_button_set_value(*GtkSpinButton, f64) void;
extern fn gtk_spin_button_get_value_as_int(*GtkSpinButton) c_int;
extern fn gtk_scale_new_with_range(c_int, f64, f64, f64) ?*GtkWidget;
extern fn gtk_range_set_value(*GtkRange, f64) void;
extern fn gtk_range_get_value(*GtkRange) f64;
extern fn gtk_scale_set_draw_value(*GtkScale, c_int) void;
extern fn gtk_scale_set_value_pos(*GtkScale, c_int) void;
extern fn gtk_drawing_area_new() ?*GtkWidget;
extern fn gtk_flow_box_new() ?*GtkWidget;
extern fn gtk_flow_box_set_selection_mode(*GtkFlowBox, c_int) void;
extern fn gtk_flow_box_set_min_children_per_line(*GtkFlowBox, c_uint) void;
extern fn gtk_flow_box_set_max_children_per_line(*GtkFlowBox, c_uint) void;
extern fn gtk_flow_box_set_row_spacing(*GtkFlowBox, c_uint) void;
extern fn gtk_flow_box_set_column_spacing(*GtkFlowBox, c_uint) void;
extern fn gtk_flow_box_set_homogeneous(*GtkFlowBox, c_int) void;
extern fn gtk_combo_box_text_new() ?*GtkWidget;
extern fn gtk_combo_box_text_new_with_entry() ?*GtkWidget;
extern fn gtk_color_button_new() ?*GtkWidget;
extern fn gtk_color_chooser_set_use_alpha(*GtkWidget, c_int) void;
extern fn gtk_combo_box_text_append_text(*GtkComboBoxText, [*:0]const u8) void;
extern fn gtk_combo_box_text_append(
    *GtkComboBoxText,
    ?[*:0]const u8,
    [*:0]const u8,
) void;
extern fn gtk_combo_box_set_active(*GtkComboBox, c_int) void;
extern fn gtk_combo_box_set_active_id(
    *GtkComboBox, [*:0]const u8) c_int;
extern fn gtk_combo_box_get_active(*GtkComboBox) c_int;
extern fn gtk_combo_box_get_active_id(
    *GtkComboBox) ?[*:0]const u8;
extern fn gtk_combo_box_text_get_active_text(
    *GtkComboBoxText) ?[*:0]u8;
extern fn gtk_dialog_new_with_buttons(
    [*:0]const u8,
    *GtkWidget,
    c_int,
    ?[*:0]const u8,
    ...,
) ?*GtkWidget;
extern fn gtk_window_new(window_type: c_int) ?*GtkWidget;
extern fn gtk_notebook_new() ?*GtkWidget;
extern fn gtk_notebook_set_scrollable(*GtkNotebook, c_int) void;
extern fn gtk_notebook_set_action_widget(*GtkNotebook, *GtkWidget, c_int) void;
extern fn gtk_notebook_append_page(
    *GtkNotebook,
    *GtkWidget,
    *GtkWidget,
) c_int;
extern fn gtk_notebook_set_tab_reorderable(*GtkNotebook, *GtkWidget, c_int) void;
extern fn gtk_notebook_set_tab_detachable(*GtkNotebook, *GtkWidget, c_int) void;
extern fn gtk_notebook_set_tab_pos(*GtkNotebook, c_int) void;
extern fn gtk_notebook_set_show_tabs(*GtkNotebook, c_int) void;
extern fn gtk_notebook_set_show_border(*GtkNotebook, c_int) void;
extern fn gtk_orientable_set_orientation(*GtkOrientable, c_int) void;
extern fn gtk_notebook_set_current_page(*GtkNotebook, c_int) void;
extern fn gtk_notebook_get_n_pages(*GtkNotebook) c_int;
extern fn gtk_notebook_get_current_page(*GtkNotebook) c_int;
extern fn gtk_notebook_get_nth_page(*GtkNotebook, c_int) ?*GtkWidget;
extern fn gtk_notebook_get_tab_label(
    *GtkNotebook, *GtkWidget) ?*GtkWidget;
extern fn gtk_notebook_get_show_tabs(*GtkNotebook) c_int;
extern fn gtk_notebook_get_action_widget(
    *GtkNotebook, c_int) ?*GtkWidget;
extern fn gtk_notebook_get_tab_pos(*GtkNotebook) c_int;
extern fn gtk_notebook_page_num(*GtkNotebook, *GtkWidget) c_int;
extern fn gtk_notebook_reorder_child(
    *GtkNotebook, *GtkWidget, c_int) void;
extern fn gtk_notebook_remove_page(*GtkNotebook, c_int) void;




extern fn gtk_clipboard_get(?*anyopaque) ?*GtkClipboard;
extern fn gtk_clipboard_request_text(
    *GtkClipboard,
    GtkClipboardTextReceivedCallback,
    ?*anyopaque,
) void;
extern fn gtk_clipboard_set_text(
    *GtkClipboard, [*:0]const u8, c_int) void;
extern fn gtk_im_context_focus_in(*GtkIMContext) void;
extern fn gtk_im_context_focus_out(*GtkIMContext) void;
extern fn gtk_im_context_filter_keypress(
    *GtkIMContext, ?*anyopaque) c_int;
extern fn gtk_editable_select_region(*GtkWidget, c_int, c_int) void;
extern fn gtk_im_multicontext_new() ?*GtkIMContext;
extern fn gtk_window_set_icon_name(*GtkWindow, [*:0]const u8) void;
extern fn gtk_window_set_default_size(*GtkWindow, c_int, c_int) void;
extern fn gtk_window_set_decorated(*GtkWindow, c_int) void;
extern fn gtk_window_set_resizable(*GtkWindow, c_int) void;
extern fn gtk_window_set_keep_above(*GtkWindow, c_int) void;
extern fn gtk_window_set_modal(*GtkWindow, c_int) void;
extern fn gtk_window_set_position(*GtkWindow, c_int) void;
extern fn gtk_window_set_type_hint(*GtkWindow, c_int) void;
extern fn gtk_window_set_destroy_with_parent(*GtkWindow, c_int) void;
extern fn gtk_window_set_geometry_hints(
    *GtkWindow, ?*GtkWindow, *const GdkGeometry, c_int) void;
extern fn gtk_window_set_title(*GtkWindow, [*:0]const u8) void;
extern fn gtk_window_get_title(*GtkWindow) ?[*:0]const u8;
extern fn gtk_window_get_focus(*GtkWindow) ?*GtkWidget;
extern fn gtk_window_get_size(*GtkWindow, *c_int, *c_int) void;
extern fn gtk_window_get_position(*GtkWindow, *c_int, *c_int) void;
extern fn gtk_window_is_active(*GtkWindow) c_int;
extern fn gtk_window_get_decorated(*GtkWindow) c_int;
extern fn gtk_window_get_resizable(*GtkWindow) c_int;
extern fn gtk_window_get_transient_for(*GtkWindow) ?*GtkWindow;
extern fn gtk_window_get_icon_name(*GtkWindow) ?[*:0]const u8;
extern fn gtk_window_present(*GtkWindow) void;
extern fn gtk_window_begin_resize_drag(
    *GtkWindow,
    c_int,
    c_int,
    c_int,
    c_int,
    c_uint,
) void;
extern fn gtk_window_fullscreen(*GtkWindow) void;
extern fn gtk_window_unfullscreen(*GtkWindow) void;
extern fn gtk_window_set_startup_id(*GtkWindow, [*:0]const u8) void;
extern fn gtk_window_set_focus(*GtkWindow, *GtkWidget) void;
extern fn gtk_window_set_transient_for(*GtkWindow, ?*GtkWindow) void;
extern fn gtk_window_resize(*GtkWindow, c_int, c_int) void;
extern fn gtk_window_move(*GtkWindow, c_int, c_int) void;




extern fn gtk_file_chooser_dialog_new([*:0]const u8, *GtkWidget, c_int, [*:0]const u8, ...) ?*GtkWidget;
extern fn gtk_file_chooser_set_current_name(*GtkWidget, [*:0]const u8) void;
extern fn gtk_file_chooser_set_extra_widget(*GtkWidget, *GtkWidget) void;
extern fn gtk_file_chooser_set_do_overwrite_confirmation(*GtkWidget, c_int) void;
extern fn gtk_file_chooser_get_filename(
    *GtkFileChooser) ?[*:0]u8;
extern fn gtk_list_box_get_row_at_index(
    *GtkListBox, c_int) ?*GtkListBoxRow;
extern fn gtk_list_box_select_row(
    *GtkListBox, ?*GtkListBoxRow) void;
extern fn gtk_list_box_new() ?*GtkWidget;
extern fn gtk_list_box_set_selection_mode(*GtkListBox, c_int) void;
extern fn gtk_list_box_set_activate_on_single_click(*GtkListBox, c_int) void;
extern fn gtk_text_view_new() ?*GtkWidget;
extern fn gtk_text_view_set_editable(*GtkTextView, c_int) void;
extern fn gtk_text_view_set_cursor_visible(*GtkTextView, c_int) void;
extern fn gtk_text_view_set_monospace(*GtkTextView, c_int) void;
extern fn gtk_text_view_set_wrap_mode(*GtkTextView, c_int) void;
extern fn gtk_text_view_get_buffer(*GtkTextView) *GtkTextBuffer;
extern fn gtk_text_buffer_set_text(*GtkTextBuffer, [*:0]const u8, c_int) void;
extern fn gtk_button_get_label(*GtkButton) ?[*:0]const u8;
extern fn gtk_bin_get_child(*GtkBin) ?*GtkWidget;
extern fn gtk_container_add(*GtkContainer, *GtkWidget) void;
extern fn gtk_container_remove(*GtkContainer, *GtkWidget) void;
extern fn gtk_container_set_border_width(*GtkContainer, c_uint) void;
extern fn gtk_container_get_children(*GtkContainer) ?*GList;
extern fn gtk_widget_set_name(*GtkWidget, [*:0]const u8) void;
extern fn gtk_widget_set_size_request(*GtkWidget, c_int, c_int) void;
extern fn gtk_widget_set_hexpand(*GtkWidget, c_int) void;
extern fn gtk_widget_set_vexpand(*GtkWidget, c_int) void;
extern fn gtk_widget_set_can_focus(*GtkWidget, c_int) void;
extern fn gtk_widget_set_focus_on_click(*GtkWidget, c_int) void;
extern fn gtk_widget_set_sensitive(*GtkWidget, c_int) void;
extern fn gtk_widget_set_no_show_all(*GtkWidget, c_int) void;
extern fn gtk_widget_set_opacity(*GtkWidget, f64) void;
extern fn gtk_widget_set_margin_start(*GtkWidget, c_int) void;
extern fn gtk_widget_set_margin_end(*GtkWidget, c_int) void;
extern fn gtk_widget_set_margin_top(*GtkWidget, c_int) void;
extern fn gtk_widget_set_margin_bottom(*GtkWidget, c_int) void;
extern fn gtk_widget_grab_focus(*GtkWidget) c_int;
extern fn gtk_widget_show(*GtkWidget) void;
extern fn gtk_widget_hide(*GtkWidget) void;
extern fn gtk_widget_queue_draw(*GtkWidget) void;
extern fn gtk_widget_queue_draw_area(
    *GtkWidget, c_int, c_int, c_int, c_int) void;
extern fn gtk_widget_queue_resize(*GtkWidget) void;
extern fn gtk_widget_get_scale_factor(*GtkWidget) c_int;
extern fn gtk_widget_set_visible(*GtkWidget, c_int) void;
extern fn gtk_widget_set_halign(*GtkWidget, c_int) void;
extern fn gtk_widget_set_valign(*GtkWidget, c_int) void;
extern fn gtk_widget_set_tooltip_text(*GtkWidget, ?[*:0]const u8) void;
extern fn gtk_widget_get_tooltip_text(*GtkWidget) ?[*:0]u8;
extern fn gtk_widget_style_get(*GtkWidget, [*:0]const u8, ...) void;
extern fn gtk_widget_has_focus(*GtkWidget) c_int;
extern fn gtk_widget_get_frame_clock(*GtkWidget) ?*GdkFrameClock;
extern fn gtk_widget_get_display(*GtkWidget) ?*GdkDisplay;
extern fn gtk_widget_get_ancestor(*GtkWidget, GType) ?*GtkWidget;
extern fn gtk_widget_get_size_request(
    *GtkWidget, ?*c_int, ?*c_int) void;
extern fn gtk_widget_has_grab(*GtkWidget) c_int;
extern fn gtk_grab_get_current() ?*GtkWidget;
extern fn gtk_grab_add(*GtkWidget) void;
extern fn gtk_grab_remove(*GtkWidget) void;
extern fn gtk_widget_is_ancestor(*GtkWidget, *GtkWidget) c_int;
extern fn gtk_widget_get_parent(*GtkWidget) ?*GtkWidget;
extern fn gtk_widget_get_visible(*GtkWidget) c_int;
extern fn gtk_widget_get_mapped(*GtkWidget) c_int;
extern fn gtk_widget_in_destruction(*GtkWidget) c_int;
extern fn gtk_widget_get_allocation(*GtkWidget, *GtkAllocation) void;
extern fn gtk_widget_get_toplevel(*GtkWidget) ?*GtkWidget;
extern fn gtk_paned_get_position(*GtkPaned) c_int;
extern fn gtk_paned_get_child1(*GtkPaned) ?*GtkWidget;
extern fn gtk_paned_get_child2(*GtkPaned) ?*GtkWidget;
extern fn gtk_paned_set_position(*GtkPaned, c_int) void;
extern fn gtk_paned_pack1(*GtkPaned, *GtkWidget, c_int, c_int) void;
extern fn gtk_paned_pack2(*GtkPaned, *GtkWidget, c_int, c_int) void;
extern fn gtk_orientable_get_orientation(*GtkOrientable) c_int;
extern fn gtk_widget_get_window(*GtkWidget) ?*GdkWindow;
extern fn gtk_widget_translate_coordinates(
    *GtkWidget,
    *GtkWidget,
    c_int,
    c_int,
    *c_int,
    *c_int,
) c_int;
extern fn gtk_widget_get_app_paintable(*GtkWidget) c_int;
extern fn gtk_widget_get_screen(*GtkWidget) ?*GdkScreen;
extern fn gtk_widget_add_events(*GtkWidget, c_int) void;
extern fn gtk_widget_add_tick_callback(
    *GtkWidget,
    GtkTickCallback,
    ?*anyopaque,
    ?GDestroyNotify,
) c_uint;
extern fn gtk_drag_finish(
    ?*anyopaque,
    c_int,
    c_int,
    c_uint,
) void;
extern fn gtk_events_pending() c_int;
extern fn gtk_main_iteration_do(c_int) void;
extern fn gtk_main_level() c_uint;
extern fn gtk_main_quit() void;
extern fn gtk_show_uri_on_window(
    *GtkWindow,
    [*:0]const u8,
    c_uint,
    ?*?*GError,
) c_int;
extern fn gtk_drag_source_set(
    *GtkWidget,
    c_uint,
    ?*anyopaque,
    c_int,
    c_uint,
) void;
extern fn gtk_drag_dest_set(
    *GtkWidget,
    c_uint,
    ?*anyopaque,
    c_int,
    c_uint,
) void;
extern fn gtk_widget_set_app_paintable(*GtkWidget, c_int) void;
extern fn gtk_widget_set_visual(*GtkWidget, ?*anyopaque) void;
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
extern fn gtk_paned_new(c_int) ?*GtkWidget;
extern fn gtk_paned_get_type() GType;
extern fn gtk_box_new(c_int, c_int) ?*GtkWidget;
extern fn gtk_box_pack_start(*GtkBox, *GtkWidget, c_int, c_int, c_uint) void;
extern fn gtk_box_pack_end(*GtkBox, *GtkWidget, c_int, c_int, c_uint) void;
extern fn gtk_box_reorder_child(*GtkBox, *GtkWidget, c_int) void;
extern fn gtk_box_set_spacing(*GtkBox, c_int) void;
extern fn gtk_separator_new(c_int) ?*GtkWidget;
extern fn gtk_revealer_new() ?*GtkWidget;
extern fn gtk_revealer_set_reveal_child(*GtkWidget, c_int) void;
extern fn gtk_revealer_set_transition_duration(*GtkWidget, c_uint) void;
extern fn gtk_revealer_set_transition_type(*GtkWidget, c_int) void;
extern fn gtk_window_list_toplevels() ?*GList;
extern fn gtk_grid_new() ?*GtkWidget;
extern fn gtk_grid_set_row_spacing(*GtkGrid, c_uint) void;
extern fn gtk_grid_set_column_spacing(*GtkGrid, c_uint) void;
extern fn gtk_grid_set_column_homogeneous(*GtkGrid, c_int) void;
extern fn gtk_grid_attach(*GtkGrid, *GtkWidget, c_int, c_int, c_int, c_int) void;
extern fn gtk_overlay_new() ?*GtkWidget;
extern fn gtk_overlay_add_overlay(*GtkWidget, *GtkWidget) void;
extern fn gtk_frame_new(?[*:0]const u8) ?*GtkWidget;
extern fn gtk_frame_set_label_widget(*GtkFrame, *GtkWidget) void;
extern fn gtk_scrolled_window_new(?*anyopaque, ?*anyopaque) ?*GtkWidget;
extern fn gtk_scrolled_window_set_policy(*GtkScrolledWindow, c_int, c_int) void;
extern fn gtk_scrolled_window_set_shadow_type(*GtkScrolledWindow, c_int) void;
extern fn gtk_list_box_row_new() ?*GtkWidget;
extern fn gtk_image_new_from_icon_name([*:0]const u8, c_int) ?*GtkWidget;
extern fn gtk_image_set_pixel_size(*GtkImage, c_int) void;
extern fn gtk_stack_new() ?*GtkWidget;
extern fn gtk_stack_set_transition_type(*GtkStack, c_int) void;
extern fn gtk_stack_set_transition_duration(*GtkStack, c_uint) void;
extern fn gtk_stack_add_named(*GtkStack, *GtkWidget, [*:0]const u8) void;
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
extern fn gtk_style_context_remove_class(
    *GtkStyleContext, [*:0]const u8) void;
extern fn gtk_style_context_has_class(
    *GtkStyleContext, [*:0]const u8) c_int;
extern fn atk_object_set_name(*AtkObject, [*:0]const u8) void;
extern fn atk_object_set_description(*AtkObject, [*:0]const u8) void;
extern fn atk_object_get_description(*AtkObject) ?[*:0]const u8;
extern fn atk_object_get_role(*AtkObject) c_int;
extern fn atk_object_set_role(*AtkObject, c_int) void;
extern fn atk_object_get_name(*AtkObject) ?[*:0]const u8;
extern fn g_type_check_instance_is_a(*GTypeInstance, GType) c_int;
extern fn g_signal_connect_data(?*anyopaque, [*:0]const u8, GCallback, ?*anyopaque, ?*anyopaque, c_uint) c_ulong;
extern fn g_object_unref(?*anyopaque) void;
extern fn g_object_set_data(*GObject, [*:0]const u8, ?*anyopaque) void;
extern fn g_object_set_data_full(*GObject, [*:0]const u8, ?*anyopaque, GDestroyNotify) void;
extern fn g_object_get_data(*GObject, [*:0]const u8) ?*anyopaque;
extern fn g_strdup([*:0]const u8) ?*anyopaque;
extern fn g_strdup_printf([*:0]const u8, ...) ?[*:0]u8;
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
    "window.noctty-terminal-window, " ++
    "window.noctty-terminal-window > overlay, " ++
    "window.noctty-terminal-window box, " ++
    "window.noctty-terminal-window grid, " ++
    "window.noctty-terminal-window revealer, " ++
    "window.noctty-terminal-window paned, " ++
    "window.noctty-terminal-window notebook, " ++
    "window.noctty-terminal-window notebook > stack { " ++
    "background-color: transparent; background-image: none; box-shadow: none; }" ++
    "notebook.noctty-tab-notebook, notebook.noctty-tab-notebook > stack { background-color: transparent; background-image: none; }" ++
    "notebook.noctty-tab-notebook > header { margin: 0; padding: 0 5px; border-width: 0; box-shadow: none; min-width: 0; min-height: 0; background: @theme_bg_color; }" ++
    "notebook.noctty-tab-notebook > header > tabs { margin: 0; padding: 0; border-width: 0; box-shadow: none; min-width: 0; min-height: 0; }" ++
    "notebook.noctty-tab-notebook > header > tabs > tab { margin: 0 4px 0 0; padding: 0; border-width: 0; border-radius: 7px 7px 0 0; box-shadow: none; min-width: 0; min-height: 0; font-size: 0.9em; background: alpha(@theme_fg_color, 0.06); color: alpha(@theme_fg_color, 0.72); }" ++
    "notebook.noctty-tab-notebook > header > tabs > tab:checked { background: @theme_base_color; color: @theme_text_color; box-shadow: inset 0 2px @theme_selected_bg_color; }" ++
    "notebook.noctty-tab-notebook > header > tabs > tab:hover { background: alpha(@theme_fg_color, 0.12); color: @theme_fg_color; }" ++
    "list.sidebar > row.noctty-settings-category { margin: 2px 4px; padding: 0; min-height: 48px; border-radius: 8px; }" ++
    "list.sidebar > row.noctty-settings-category:selected { background: alpha(@theme_selected_bg_color, 0.18); color: @theme_text_color; }" ++
    "list.sidebar > row.noctty-settings-category:focus { outline: 2px solid @theme_selected_bg_color; outline-offset: -2px; }" ++
    ".noctty-tab-content, .noctty-tab-label { margin: 0; padding: 0; border-radius: 9px 9px 0 0; }" ++
    "button.noctty-tab-close, button.noctty-tab-action { margin: 0; padding: 0; border-width: 0; border-radius: 7px; box-shadow: none; min-width: 28px; min-height: 24px; color: alpha(@theme_fg_color, 0.72); background: transparent; }" ++
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

const pane_count_max: u32 = 16;
const split_count_max: usize = 15;
const split_walk_max: usize = 31;

fn branchHasVisiblePane(
    branch: *GtkWidget,
    panes: []const ?*GtkWidget,
) bool {
    for (panes) |pane_optional| {
        const pane = pane_optional orelse continue;
        if (gtk_widget_get_visible(pane) == 0) continue;
        if (pane == branch or gtk_widget_is_ancestor(pane, branch) != 0)
            return true;
    }
    return false;
}

pub export fn noctty_grid_sync_split_visibility(
    content_optional: ?*GtkWidget,
    panes_optional: ?[*]const ?*GtkWidget,
    pane_count: u32,
) callconv(.c) c_int {
    const content = content_optional orelse return FALSE;
    const pane_pointer = panes_optional orelse return FALSE;
    if (pane_count == 0 or pane_count > pane_count_max) return FALSE;
    const panes = pane_pointer[0..pane_count];

    var pending: [split_walk_max]?*GtkWidget = [_]?*GtkWidget{null} ** split_walk_max;
    var splits: [split_count_max]?*GtkWidget = [_]?*GtkWidget{null} ** split_count_max;
    var pending_count: usize = 1;
    var split_count: usize = 0;
    pending[0] = content;
    while (pending_count > 0) {
        pending_count -= 1;
        const branch = pending[pending_count] orelse continue;
        if (!isA(branch, gtk_paned_get_type)) continue;
        if (split_count == splits.len) return FALSE;
        splits[split_count] = branch;
        split_count += 1;
        const paned: *GtkPaned = @ptrCast(branch);
        for ([_]?*GtkWidget{
            gtk_paned_get_child1(paned),
            gtk_paned_get_child2(paned),
        }) |child_optional| {
            const child = child_optional orelse continue;
            if (pending_count == pending.len) return FALSE;
            pending[pending_count] = child;
            pending_count += 1;
        }
    }

    var index = split_count;
    while (index > 0) {
        index -= 1;
        const branch = splits[index] orelse continue;
        const paned: *GtkPaned = @ptrCast(branch);
        for ([_]?*GtkWidget{
            gtk_paned_get_child1(paned),
            gtk_paned_get_child2(paned),
        }) |child_optional| {
            const child = child_optional orelse continue;
            gtk_widget_set_visible(
                child,
                @intFromBool(branchHasVisiblePane(child, panes)),
            );
        }
    }
    return TRUE;
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

fn widgetCssProvider(
    widget: *GtkWidget,
    key: [*:0]const u8,
) ?*GtkCssProvider {
    if (g_object_get_data(object(widget), key)) |value| return @ptrCast(value);
    const provider = gtk_css_provider_new() orelse return null;
    g_object_set_data_full(object(widget), key, provider, g_object_unref);
    gtk_style_context_add_provider(
        gtk_widget_get_style_context(widget),
        @ptrCast(provider),
        GTK_STYLE_PROVIDER_PRIORITY_APPLICATION,
    );
    return provider;
}

fn applyPaneDividerStyle(widget: *GtkWidget, width_px: c_int) void {
    if (isA(widget, gtk_paned_get_type)) {
        const provider = widgetCssProvider(widget, "noctty-divider-provider") orelse return;
        var css_buffer: [96]u8 = undefined;
        const width = std.math.clamp(width_px, 1, 64);
        const css = std.fmt.bufPrintZ(
            &css_buffer,
            "paned > separator {{ min-width: {d}px; min-height: {d}px; }}",
            .{ width, width },
        ) catch return;
        _ = gtk_css_provider_load_from_data(provider, css, -1, null);
    }
    if (!isA(widget, gtk_container_get_type)) return;
    const children = gtk_container_get_children(@ptrCast(widget));
    defer g_list_free(children);
    var item = children;
    while (item) |child| : (item = child.next) {
        const current: *GtkWidget = @ptrCast(child.data orelse continue);
        applyPaneDividerStyle(current, width_px);
    }
}

pub export fn noctty_apply_pane_divider_style(
    widget: ?*GtkWidget,
    width_px: c_int,
) void {
    applyPaneDividerStyle(widget orelse return, width_px);
}

pub export fn noctty_paned_new(
    orientation: c_int,
    divider_px: c_int,
) ?*GtkWidget {
    const paned = gtk_paned_new(orientation) orelse return null;
    if (divider_px > 0) applyPaneDividerStyle(paned, divider_px);
    return paned;
}
pub export fn noctty_paned_pack1(
    paned_optional: ?*GtkWidget,
    child_optional: ?*GtkWidget,
    resize: c_int,
    shrink: c_int,
) void {
    const paned = paned_optional orelse return;
    const child = child_optional orelse return;
    gtk_paned_pack1(@ptrCast(paned), child, resize, shrink);
}

pub export fn noctty_paned_pack2(
    paned_optional: ?*GtkWidget,
    child_optional: ?*GtkWidget,
    resize: c_int,
    shrink: c_int,
) void {
    const paned = paned_optional orelse return;
    const child = child_optional orelse return;
    gtk_paned_pack2(@ptrCast(paned), child, resize, shrink);
}

pub export fn noctty_paned_set_position(
    paned_optional: ?*GtkWidget,
    position: c_int,
) void {
    const paned = paned_optional orelse return;
    gtk_paned_set_position(@ptrCast(paned), position);
}
pub export fn noctty_container_add(
    container_optional: ?*GtkWidget,
    child_optional: ?*GtkWidget,
) void {
    const container = container_optional orelse return;
    const child = child_optional orelse return;
    gtk_container_add(@ptrCast(container), child);
}

pub export fn noctty_container_remove(
    container_optional: ?*GtkWidget,
    child_optional: ?*GtkWidget,
) void {
    const container = container_optional orelse return;
    const child = child_optional orelse return;
    gtk_container_remove(@ptrCast(container), child);
}

pub export fn noctty_container_set_border_width(
    container_optional: ?*GtkWidget,
    width: c_uint,
) void {
    const container = container_optional orelse return;
    gtk_container_set_border_width(@ptrCast(container), width);
}

pub export fn noctty_box_pack_start(
    box_optional: ?*GtkWidget,
    child_optional: ?*GtkWidget,
    expand: c_int,
    fill: c_int,
    padding: c_uint,
) void {
    const box = box_optional orelse return;
    const child = child_optional orelse return;
    gtk_box_pack_start(@ptrCast(box), child, expand, fill, padding);
}

pub export fn noctty_box_pack_end(
    box_optional: ?*GtkWidget,
    child_optional: ?*GtkWidget,
    expand: c_int,
    fill: c_int,
    padding: c_uint,
) void {
    const box = box_optional orelse return;
    const child = child_optional orelse return;
    gtk_box_pack_end(@ptrCast(box), child, expand, fill, padding);
}

pub export fn noctty_box_reorder_child(
    box_optional: ?*GtkWidget,
    child_optional: ?*GtkWidget,
    position: c_int,
) void {
    const box = box_optional orelse return;
    const child = child_optional orelse return;
    gtk_box_reorder_child(@ptrCast(box), child, position);
}

fn paneWidgetCount(widget_optional: ?*GtkWidget) u32 {
    const widget = widget_optional orelse return 0;
    if (!isA(widget, gtk_paned_get_type)) return 1;
    const paned: *GtkPaned = @ptrCast(widget);
    return paneWidgetCount(gtk_paned_get_child1(paned)) +
        paneWidgetCount(gtk_paned_get_child2(paned));
}

fn applyEvenPanePositions(widget_optional: ?*GtkWidget) bool {
    const widget = widget_optional orelse return false;
    if (!isA(widget, gtk_paned_get_type)) return true;
    const paned: *GtkPaned = @ptrCast(widget);
    const first = gtk_paned_get_child1(paned);
    const second = gtk_paned_get_child2(paned);
    const first_count = paneWidgetCount(first);
    const second_count = paneWidgetCount(second);
    const total = first_count + second_count;
    if (total == 0) return false;

    var allocation: GtkAllocation = undefined;
    gtk_widget_get_allocation(widget, &allocation);
    var handle_size: c_int = 0;
    gtk_widget_style_get(
        widget,
        "handle-size",
        &handle_size,
        @as(?*anyopaque, null),
    );
    const orientation = gtk_orientable_get_orientation(@ptrCast(widget));
    const extent = if (orientation == GTK_ORIENTATION_VERTICAL)
        allocation.height
    else
        allocation.width;
    const available: i64 = @max(1, @as(i64, extent) - @max(0, handle_size));
    const position: c_int = @intCast(
        @divTrunc(
            available * @as(i64, first_count) + @divTrunc(total, 2),
            total,
        ),
    );
    const ratio_permille: usize = @intCast(
        @divTrunc(first_count * 1000 + @divTrunc(total, 2), total),
    );
    g_object_set_data(
        object(widget),
        "noctty-preset-ratio",
        @ptrFromInt(ratio_permille),
    );
    gtk_paned_set_position(paned, position);
    if (first != null) _ = applyEvenPanePositions(first);
    if (second != null) _ = applyEvenPanePositions(second);
    return true;
}

pub export fn noctty_apply_even_pane_positions(widget: ?*GtkWidget) c_int {
    return @intFromBool(applyEvenPanePositions(widget));
}

fn setPaneGapStyle(widget: *GtkWidget, rgb: u32, is_opaque: bool) void {
    const provider = widgetCssProvider(widget, "noctty-pane-gap-provider") orelse return;
    gtk_style_context_add_class(
        gtk_widget_get_style_context(widget),
        "noctty-pane-gap-surface",
    );
    var css_buffer: [160]u8 = undefined;
    const css = if (is_opaque)
        std.fmt.bufPrintZ(
            &css_buffer,
            ".noctty-pane-gap-surface {{ background-color: rgb({d},{d},{d}); }}",
            .{ (rgb >> 16) & 0xff, (rgb >> 8) & 0xff, rgb & 0xff },
        ) catch return
    else
        std.fmt.bufPrintZ(
            &css_buffer,
            ".noctty-pane-gap-surface {{ background-color: rgba(0,0,0,0); }}",
            .{},
        ) catch return;
    _ = gtk_css_provider_load_from_data(provider, css, -1, null);
}

fn applyPaneGapStyle(widget: *GtkWidget, rgb: u32, is_opaque: bool, root: bool) void {
    if (root or isA(widget, gtk_paned_get_type))
        setPaneGapStyle(widget, rgb, is_opaque);
    if (!isA(widget, gtk_container_get_type)) return;
    const children = gtk_container_get_children(@ptrCast(widget));
    defer g_list_free(children);
    var item = children;
    while (item) |child| : (item = child.next) {
        const current: *GtkWidget = @ptrCast(child.data orelse continue);
        applyPaneGapStyle(current, rgb, is_opaque, false);
    }
}

pub export fn noctty_apply_pane_gap_style(
    widget: ?*GtkWidget,
    rgb: u32,
    is_opaque: c_int,
) void {
    applyPaneGapStyle(widget orelse return, rgb, is_opaque != 0, true);
}

pub export fn noctty_install_compact_tab_styles(target: ?*GtkWidget) void {
    const widget = target orelse return;
    const provider = compactTabProvider() orelse return;
    const screen = gtk_widget_get_screen(widget) orelse gdk_screen_get_default();
    if (screen) |value| gtk_style_context_add_provider_for_screen(value, @ptrCast(provider), GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);
    g_object_set_data(object(widget), "noctty-style-provider-installed", @ptrFromInt(1));
    if (isA(widget, gtk_notebook_get_type))
        gtk_style_context_add_class(gtk_widget_get_style_context(widget), "noctty-tab-notebook");
}

const CompactTabOptions = extern struct {
    page: ?*GtkWidget,
    text: ?[*:0]const u8,
    callback_data: ?*anyopaque,
};

const CompactTabCallbacks = extern struct {
    button_press: ?GCallback,
    button_release: ?GCallback,
    drag_begin: ?GCallback,
    drag_end: ?GCallback,
    close_clicked: ?GCallback,
};

const CompactTabContents = extern struct {
    tab: ?*GtkWidget,
    label: ?*GtkWidget,
    close_button: ?*GtkWidget,
};

/// The returned tab keeps its GTK floating reference until C inserts it into a
/// container. Descendant handles are borrowed and callback data remains C-owned.
pub export fn noctty_compact_tab_new(
    options_raw: ?*const CompactTabOptions,
    callbacks_raw: ?*const CompactTabCallbacks,
    contents_out: ?*CompactTabContents,
) c_int {
    const output = contents_out orelse return FALSE;
    output.* = std.mem.zeroes(CompactTabContents);
    const options = options_raw orelse return FALSE;
    const callbacks = callbacks_raw orelse return FALSE;
    const page = options.page orelse return FALSE;
    const text = options.text orelse return FALSE;

    const tab = gtk_event_box_new() orelse return FALSE;
    const content = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 1) orelse {
        g_object_unref(tab);
        return FALSE;
    };
    const label = gtk_label_new(text) orelse {
        g_object_unref(content);
        g_object_unref(tab);
        return FALSE;
    };
    const close = gtk_button_new_from_icon_name(
        "window-close-symbolic",
        GTK_ICON_SIZE_MENU,
    ) orelse {
        g_object_unref(label);
        g_object_unref(content);
        g_object_unref(tab);
        return FALSE;
    };

    gtk_event_box_set_visible_window(@ptrCast(tab), FALSE);
    gtk_event_box_set_above_child(@ptrCast(tab), FALSE);
    gtk_widget_add_events(tab, GDK_BUTTON_PRESS_MASK | GDK_BUTTON_RELEASE_MASK);
    gtk_button_set_relief(@ptrCast(close), GTK_RELIEF_NONE);
    gtk_widget_set_focus_on_click(close, FALSE);
    gtk_widget_set_size_request(close, 28, 24);
    noctty_configure_action_button(close, "Close Tab");
    setAccessibleName(close, "Close Tab");
    gtk_style_context_add_class(gtk_widget_get_style_context(content), "noctty-tab-content");
    gtk_style_context_add_class(gtk_widget_get_style_context(label), "noctty-tab-label");
    gtk_style_context_add_class(gtk_widget_get_style_context(close), "noctty-tab-close");
    gtk_style_context_add_class(gtk_widget_get_style_context(close), "flat");
    gtk_box_pack_start(@ptrCast(content), label, TRUE, TRUE, 0);
    gtk_box_pack_start(@ptrCast(content), close, FALSE, FALSE, 0);
    gtk_container_add(@ptrCast(tab), content);
    g_object_set_data(object(tab), "noctty-tab-page", page);
    g_object_set_data(object(close), "noctty-tab-page", page);
    g_object_set_data(object(tab), tab_label_key, label);
    g_object_set_data(object(tab), tab_close_key, close);
    connectSignal(tab, "button-press-event", callbacks.button_press, options.callback_data);
    connectSignal(tab, "button-release-event", callbacks.button_release, options.callback_data);
    connectSignal(tab, "drag-begin", callbacks.drag_begin, options.callback_data);
    connectSignal(tab, "drag-end", callbacks.drag_end, options.callback_data);
    connectSignal(close, "clicked", callbacks.close_clicked, options.callback_data);
    output.* = .{ .tab = tab, .label = label, .close_button = close };
    return TRUE;
}

/// The returned button keeps its GTK floating reference until C inserts it into
/// the notebook. Callback data remains C-owned for the button's lifetime.
pub export fn noctty_new_tab_button_new(
    extent_px: c_int,
    callback_data: ?*anyopaque,
    clicked: ?GCallback,
) ?*GtkWidget {
    const button = gtk_button_new_from_icon_name(
        "list-add-symbolic",
        GTK_ICON_SIZE_MENU,
    ) orelse return null;
    gtk_button_set_relief(@ptrCast(button), GTK_RELIEF_NONE);
    gtk_widget_set_can_focus(button, TRUE);
    gtk_widget_set_size_request(button, extent_px, extent_px);
    noctty_configure_action_button(button, "New Tab (Ctrl+Shift+T)");
    setAccessibleName(button, "New Tab, Ctrl+Shift+T");
    gtk_style_context_add_class(gtk_widget_get_style_context(button), "noctty-tab-action");
    gtk_style_context_add_class(gtk_widget_get_style_context(button), "flat");
    connectSignal(button, "clicked", clicked, callback_data);
    return button;
}

const WindowToolbarCallbacks = extern struct {
    settings_clicked: ?GCallback,
    close_clicked: ?GCallback,
};

const WindowToolbarContents = extern struct {
    controls: ?*GtkWidget,
    settings: ?*GtkWidget,
    close_button: ?*GtkWidget,
};

/// The returned controls box keeps its GTK floating reference until C inserts
/// it into the notebook. Descendants are borrowed; callback data remains C-owned.
pub export fn noctty_window_toolbar_new(
    extent_px: c_int,
    callback_data: ?*anyopaque,
    callbacks_raw: ?*const WindowToolbarCallbacks,
    contents_out: ?*WindowToolbarContents,
) c_int {
    const output = contents_out orelse return FALSE;
    output.* = std.mem.zeroes(WindowToolbarContents);
    const callbacks = callbacks_raw orelse return FALSE;
    const controls = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0) orelse return FALSE;
    const settings = gtk_button_new_from_icon_name(
        "preferences-system-symbolic",
        GTK_ICON_SIZE_MENU,
    ) orelse {
        g_object_unref(controls);
        return FALSE;
    };
    const close = gtk_button_new_from_icon_name(
        "window-close-symbolic",
        GTK_ICON_SIZE_MENU,
    ) orelse {
        g_object_unref(settings);
        g_object_unref(controls);
        return FALSE;
    };

    for (
        [_]*GtkWidget{ settings, close },
        [_][*:0]const u8{ "Settings", "Close NOCTTY" },
    ) |button, text| {
        gtk_button_set_relief(@ptrCast(button), GTK_RELIEF_NONE);
        gtk_widget_set_focus_on_click(button, FALSE);
        gtk_widget_set_size_request(button, extent_px, extent_px);
        noctty_configure_action_button(button, text);
        setAccessibleName(button, text);
        gtk_style_context_add_class(gtk_widget_get_style_context(button), "flat");
        gtk_style_context_add_class(gtk_widget_get_style_context(button), "noctty-tab-action");
        gtk_box_pack_start(@ptrCast(controls), button, FALSE, FALSE, 0);
    }
    gtk_style_context_add_class(gtk_widget_get_style_context(controls), "noctty-window-controls");
    connectSignal(settings, "clicked", callbacks.settings_clicked, callback_data);
    connectSignal(close, "clicked", callbacks.close_clicked, callback_data);
    output.* = .{
        .controls = controls,
        .settings = settings,
        .close_button = close,
    };
    return TRUE;
}

pub export fn noctty_window_toolbar_set_close_visible(
    close_button: ?*GtkWidget,
    visible: c_int,
) void {
    const close = close_button orelse return;
    gtk_widget_set_no_show_all(close, @intFromBool(visible == 0));
    gtk_widget_set_visible(close, visible);
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
    gtk_grid_set_column_spacing(@ptrCast(grid), 12);
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
    gtk_label_set_line_wrap(@ptrCast(label), TRUE);
    gtk_label_set_max_width_chars(@ptrCast(label), 14);
    gtk_label_set_mnemonic_widget(@ptrCast(label), control_widget);
    gtk_widget_set_halign(label, GTK_ALIGN_START);
    gtk_widget_set_valign(label, GTK_ALIGN_CENTER);
    gtk_widget_set_size_request(label, 112, -1);
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
    gtk_container_set_border_width(@ptrCast(child_widget), 12);
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
        GTK_POLICY_NEVER,
        GTK_POLICY_AUTOMATIC,
    );
    gtk_scrolled_window_set_shadow_type(@ptrCast(scrolled), GTK_SHADOW_NONE);
    gtk_widget_set_hexpand(scrolled, TRUE);
    const body = gtk_box_new(GTK_ORIENTATION_VERTICAL, 20) orelse return null;
    gtk_container_set_border_width(@ptrCast(body), 20);
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

const WorkspaceMenuCallbacks = extern struct {
    workspace: ?GCallback,
    terminal: ?GCallback,
    compact: ?GCallback,
    tag_selected: ?GCallback,
    tag_remove: ?GCallback,
    smart_filter: ?GCallback,
    broadcast: ?GCallback,
    theme: ?GCallback,
    command_palette: ?GCallback,
    sharing: ?GCallback,
    project: ?GCallback,
    pane_close: ?GCallback,
    settings: ?GCallback,
    selection_done: ?GCallback,
    destroy: ?GCallback,
};

const WorkspaceMenuOptions = extern struct {
    context: ?*anyopaque,
    root: ?*anyopaque,
    profile_menu: ?*GtkWidget,
    broadcast_label: ?[*:0]const u8,
    selection_active: c_int,
    pane_close_sensitive: c_int,
};

const MenuAction = struct {
    label: [*:0]const u8,
    action: c_int,
};

fn connectSignal(
    widget: *GtkWidget,
    signal: [*:0]const u8,
    callback: ?GCallback,
    data: ?*anyopaque,
) void {
    const handler = callback orelse return;
    _ = g_signal_connect_data(widget, signal, handler, data, null, 0);
}
pub export fn noctty_grid_signal_connect(
    instance: ?*anyopaque,
    signal: [*:0]const u8,
    callback_optional: ?GCallback,
    data: ?*anyopaque,
) c_ulong {
    const target = instance orelse return 0;
    const callback = callback_optional orelse return 0;
    return g_signal_connect_data(target, signal, callback, data, null, 0);
}
pub export fn noctty_grid_signal_connect_swapped(
    instance: ?*anyopaque,
    signal: [*:0]const u8,
    callback_optional: ?GCallback,
    data: ?*anyopaque,
) c_ulong {
    const target = instance orelse return 0;
    const callback = callback_optional orelse return 0;
    return g_signal_connect_data(target, signal, callback, data, null, 1);
}

pub export fn noctty_grid_signal_connect_object(
    instance: ?*anyopaque,
    signal: [*:0]const u8,
    callback_optional: ?GCallback,
    object_optional: ?*anyopaque,
    flags: c_uint,
) c_ulong {
    const target = instance orelse return 0;
    const callback = callback_optional orelse return 0;
    const object_target = object_optional orelse return 0;
    return g_signal_connect_data(
        target,
        signal,
        callback,
        object_target,
        null,
        flags | 2,
    );
}

fn appendSeparator(menu: *GtkWidget) void {
    const separator = gtk_separator_menu_item_new() orelse return;
    gtk_menu_shell_append(@ptrCast(menu), separator);
}

fn appendSubmenu(menu: *GtkWidget, label: [*:0]const u8) ?*GtkWidget {
    const item = gtk_menu_item_new_with_label(label) orelse return null;
    const submenu = gtk_menu_new() orelse return null;
    gtk_menu_item_set_submenu(@ptrCast(item), submenu);
    gtk_menu_shell_append(@ptrCast(menu), item);
    return submenu;
}

fn appendAction(options: struct {
    menu: *GtkWidget,
    label: [*:0]const u8,
    key: [*:0]const u8,
    action: c_int,
    sensitive: bool = true,
    callback: ?GCallback,
    data: ?*anyopaque,
}) void {
    const item = gtk_menu_item_new_with_label(options.label) orelse return;
    g_object_set_data(
        object(item),
        options.key,
        if (options.action == 0) null else @ptrFromInt(@as(usize, @intCast(options.action))),
    );
    gtk_widget_set_sensitive(item, @intFromBool(options.sensitive));
    connectSignal(item, "activate", options.callback, options.data);
    gtk_menu_shell_append(@ptrCast(options.menu), item);
}

fn appendActions(options: struct {
    menu: *GtkWidget,
    actions: []const MenuAction,
    key: [*:0]const u8,
    callback: ?GCallback,
    data: ?*anyopaque,
}) void {
    for (options.actions) |action| {
        appendAction(.{
            .menu = options.menu,
            .label = action.label,
            .key = options.key,
            .action = action.action,
            .callback = options.callback,
            .data = options.data,
        });
    }
}

fn appendCallback(
    menu: *GtkWidget,
    label: [*:0]const u8,
    callback: ?GCallback,
    data: ?*anyopaque,
) void {
    appendAction(.{
        .menu = menu,
        .label = label,
        .key = "noctty-callback-action",
        .action = 0,
        .callback = callback,
        .data = data,
    });
}

/// GTK owns the returned menu and all descendants. Callback data remains C-owned
/// because menu activation never outlives the surrounding native-grid context.
pub export fn noctty_workspace_menu_new(
    options_raw: ?*const WorkspaceMenuOptions,
    callbacks_raw: ?*const WorkspaceMenuCallbacks,
) ?*GtkWidget {
    const options = options_raw orelse return null;
    const callbacks = callbacks_raw orelse return null;
    const context = options.context orelse return null;
    const root = options.root orelse return null;
    const menu = gtk_menu_new() orelse return null;

    appendAction(.{
        .menu = menu,
        .label = "Copy",
        .key = "noctty-terminal-action",
        .action = 1,
        .sensitive = options.selection_active != 0,
        .callback = callbacks.terminal,
        .data = context,
    });
    appendAction(.{
        .menu = menu,
        .label = "Paste",
        .key = "noctty-terminal-action",
        .action = 2,
        .callback = callbacks.terminal,
        .data = context,
    });
    appendSeparator(menu);
    appendAction(.{
        .menu = menu,
        .label = "New Tab",
        .key = "noctty-workspace-event",
        .action = 20,
        .callback = callbacks.workspace,
        .data = context,
    });

    if (appendSubmenu(menu, "Split Pane")) |submenu| {
        appendActions(.{
            .menu = submenu,
            .actions = &.{
                .{ .label = "Split Right", .action = 27 },
                .{ .label = "Split Down", .action = 21 },
                .{ .label = "Split Up", .action = 28 },
                .{ .label = "Split Left", .action = 22 },
            },
            .key = "noctty-workspace-event",
            .callback = callbacks.workspace,
            .data = context,
        });
    }
    if (appendSubmenu(menu, "New Split Tab")) |submenu| {
        appendActions(.{
            .menu = submenu,
            .actions = &.{
                .{ .label = "New 2×2", .action = 51 },
                .{ .label = "New 4×2", .action = 61 },
                .{ .label = "New 3×3", .action = 52 },
                .{ .label = "New 4×4", .action = 60 },
            },
            .key = "noctty-workspace-event",
            .callback = callbacks.workspace,
            .data = context,
        });
    }

    if (appendSubmenu(menu, "Selection and Tags")) |submenu| {
        appendAction(.{
            .menu = submenu,
            .label = "Select All",
            .key = "noctty-terminal-action",
            .action = 3,
            .callback = callbacks.terminal,
            .data = context,
        });
        appendAction(.{
            .menu = submenu,
            .label = "Clear Selection",
            .key = "noctty-terminal-action",
            .action = 4,
            .sensitive = options.selection_active != 0,
            .callback = callbacks.terminal,
            .data = context,
        });
        appendActions(.{
            .menu = submenu,
            .actions = &.{
                .{ .label = "Add Pane to Selection", .action = 53 },
                .{ .label = "Toggle Pane Selection", .action = 54 },
            },
            .key = "noctty-workspace-event",
            .callback = callbacks.workspace,
            .data = context,
        });
        appendCallback(submenu, "Tag Selected Panes…", callbacks.tag_selected, context);
        appendCallback(submenu, "Remove Tag from Selected Panes…", callbacks.tag_remove, context);
        appendCallback(submenu, "Smart Tab Filter…", callbacks.smart_filter, context);
    }

    if (appendSubmenu(menu, "Pane")) |submenu| {
        appendAction(.{
            .menu = submenu,
            .label = "Zoom / Restore Pane",
            .key = "noctty-compact-action",
            .action = 4,
            .callback = callbacks.compact,
            .data = context,
        });
        if (options.profile_menu) |profile_menu| {
            if (gtk_menu_item_new_with_label("Profile")) |profile| {
                gtk_menu_item_set_submenu(@ptrCast(profile), profile_menu);
                gtk_menu_shell_append(@ptrCast(submenu), profile);
            }
        }
        appendCallback(
            submenu,
            options.broadcast_label orelse "Broadcast Input",
            callbacks.broadcast,
            context,
        );
        appendAction(.{
            .menu = submenu,
            .label = "Move Pane to Other Tab",
            .key = "noctty-workspace-event",
            .action = 56,
            .callback = callbacks.workspace,
            .data = context,
        });
    }
    g_object_set_data(object(menu), "noctty-profile-context", context);

    if (appendSubmenu(menu, "Clear Terminal")) |submenu| {
        appendActions(.{
            .menu = submenu,
            .actions = &.{
                .{ .label = "Clear Screen", .action = 5 },
                .{ .label = "Clear Scrollback", .action = 6 },
                .{ .label = "Clear Scrollback and Reset", .action = 7 },
            },
            .key = "noctty-terminal-action",
            .callback = callbacks.terminal,
            .data = context,
        });
    }
    if (appendSubmenu(menu, "View")) |submenu| {
        appendActions(.{
            .menu = submenu,
            .actions = &.{
                .{ .label = "Find in Scrollback…", .action = 5 },
                .{ .label = "Quick Note…", .action = 6 },
                .{ .label = "Save Scrollback…", .action = 12 },
            },
            .key = "noctty-compact-action",
            .callback = callbacks.compact,
            .data = context,
        });
        appendCallback(submenu, "Theme Library…", callbacks.theme, context);
    }
    if (appendSubmenu(menu, "Tools")) |submenu| {
        appendCallback(submenu, "Command Palette…", callbacks.command_palette, context);
        appendCallback(submenu, "Session Sharing…", callbacks.sharing, context);
        appendActions(.{
            .menu = submenu,
            .actions = &.{
                .{ .label = "Keyboard Shortcuts…", .action = 13 },
                .{ .label = "Open NoctEd Here", .action = 18 },
            },
            .key = "noctty-compact-action",
            .callback = callbacks.compact,
            .data = context,
        });
        appendCallback(submenu, "Project / NoctEd…", callbacks.project, context);
    }

    appendSeparator(menu);
    appendAction(.{
        .menu = menu,
        .label = "Close Terminal",
        .key = "noctty-callback-action",
        .action = 0,
        .sensitive = options.pane_close_sensitive != 0,
        .callback = callbacks.pane_close,
        .data = context,
    });
    appendCallback(menu, "Settings…", callbacks.settings, context);
    connectSignal(menu, "selection-done", callbacks.selection_done, null);
    connectSignal(menu, "destroy", callbacks.destroy, root);
    return menu;
}

const HyperlinkMenuContents = extern struct {
    menu: ?*GtkWidget,
    open: ?*GtkWidget,
    copy: ?*GtkWidget,
};

fn menuIntegerData(value: c_int) ?*anyopaque {
    return @ptrFromInt(@as(usize, @bitCast(@as(isize, value))));
}

pub export fn noctty_hyperlink_menu_new(
    contents_out: ?*HyperlinkMenuContents,
) c_int {
    const output = contents_out orelse return FALSE;
    const menu = gtk_menu_new() orelse return FALSE;
    const open = gtk_menu_item_new_with_label("Open Link in Browser") orelse {
        g_object_unref(menu);
        return FALSE;
    };
    const copy = gtk_menu_item_new_with_label("Copy Link") orelse {
        g_object_unref(open);
        g_object_unref(menu);
        return FALSE;
    };
    setAccessibleName(open, "Open link in default browser");
    setAccessibleName(copy, "Copy hyperlink address");
    gtk_menu_shell_append(@ptrCast(menu), open);
    gtk_menu_shell_append(@ptrCast(menu), copy);
    output.* = .{ .menu = menu, .open = open, .copy = copy };
    return TRUE;
}

pub export fn noctty_profile_preset_menu_new(
    labels: ?[*]const [*:0]const u8,
    label_count: c_uint,
    active: c_int,
    toggled: ?GCallback,
    context: ?*anyopaque,
) ?*GtkWidget {
    const values = labels orelse return null;
    if (label_count == 0) return null;
    const menu = gtk_menu_new() orelse return null;
    var group: ?*GSList = null;
    for (0..label_count) |index| {
        const item = gtk_radio_menu_item_new_with_label(group, values[index]) orelse {
            g_object_unref(menu);
            return null;
        };
        group = gtk_radio_menu_item_get_group(item);
        g_object_set_data(object(item), "noctty-profile-preset", menuIntegerData(@intCast(index)));
        gtk_check_menu_item_set_active(item, @intFromBool(@as(c_int, @intCast(index)) == active));
        connectSignal(item, "toggled", toggled, context);
        gtk_menu_shell_append(@ptrCast(menu), item);
    }
    return menu;
}

pub export fn noctty_tab_color_menu_new(
    labels: ?[*]const [*:0]const u8,
    label_count: c_uint,
    active: c_int,
    page: ?*GtkWidget,
    preset_toggled: ?GCallback,
    adjust_activate: ?GCallback,
    context: ?*anyopaque,
    lighter_label: [*:0]const u8,
    darker_label: [*:0]const u8,
) ?*GtkWidget {
    const values = labels orelse return null;
    const target_page = page orelse return null;
    if (label_count == 0) return null;
    const menu = gtk_menu_new() orelse return null;
    var group: ?*GSList = null;
    for (0..label_count) |index| {
        const preset: c_int = @as(c_int, @intCast(index)) - 1;
        const item = gtk_radio_menu_item_new_with_label(group, values[index]) orelse {
            g_object_unref(menu);
            return null;
        };
        group = gtk_radio_menu_item_get_group(item);
        g_object_set_data(object(item), "noctty-tab-page", target_page);
        g_object_set_data(object(item), "noctty-tab-color-preset", menuIntegerData(preset));
        gtk_check_menu_item_set_active(item, @intFromBool(preset == active));
        connectSignal(item, "toggled", preset_toggled, context);
        gtk_menu_shell_append(@ptrCast(menu), item);
        if (preset == -1) appendSeparator(menu);
    }
    appendSeparator(menu);
    const lighter = gtk_menu_item_new_with_label(lighter_label) orelse {
        g_object_unref(menu);
        return null;
    };
    const darker = gtk_menu_item_new_with_label(darker_label) orelse {
        g_object_unref(lighter);
        g_object_unref(menu);
        return null;
    };
    for ([_]struct { item: *GtkWidget, delta: c_int }{
        .{ .item = lighter, .delta = 1 },
        .{ .item = darker, .delta = -1 },
    }) |adjustment| {
        g_object_set_data(object(adjustment.item), "noctty-tab-page", target_page);
        g_object_set_data(object(adjustment.item), "noctty-tab-color-delta", menuIntegerData(adjustment.delta));
        connectSignal(adjustment.item, "activate", adjust_activate, context);
        gtk_menu_shell_append(@ptrCast(menu), adjustment.item);
    }
    return menu;
}

pub export fn noctty_tab_context_menu_new(
    page: ?*GtkWidget,
    tab_color_menu: ?*GtkWidget,
    close_sensitive: c_int,
    close_activate: ?GCallback,
    context: ?*anyopaque,
) ?*GtkWidget {
    const target_page = page orelse return null;
    const color_menu = tab_color_menu orelse return null;
    const menu = gtk_menu_new() orelse return null;
    const color = gtk_menu_item_new_with_label("Tab Color") orelse {
        g_object_unref(menu);
        return null;
    };
    const close = gtk_menu_item_new_with_label("Close Tab") orelse {
        g_object_unref(color);
        g_object_unref(menu);
        return null;
    };
    gtk_menu_item_set_submenu(@ptrCast(color), color_menu);
    gtk_menu_shell_append(@ptrCast(menu), color);
    appendSeparator(menu);
    g_object_set_data(object(close), "noctty-tab-page", target_page);
    gtk_widget_set_sensitive(close, close_sensitive);
    connectSignal(close, "activate", close_activate, context);
    gtk_menu_shell_append(@ptrCast(menu), close);
    return menu;
}

const FindContents = extern struct {
    entry: ?*GtkWidget,
    status: ?*GtkWidget,
};

const QuickNoteContents = extern struct {
    view: ?*GtkWidget,
    status: ?*GtkWidget,
};

const PaletteAction = extern struct {
    id: c_int,
    label: ?[*:0]const u8,
    hint: ?[*:0]const u8,
};

const PaletteContents = extern struct {
    search: ?*GtkWidget,
    list: ?*GtkWidget,
};

const ProjectContents = extern struct {
    save: ?*GtkWidget,
    open: ?*GtkWidget,
    recent_combo: ?*GtkWidget,
    recent_open: ?*GtkWidget,
    editor: ?*GtkWidget,
    summary: ?*GtkWidget,
    summary_scroll: ?*GtkWidget,
};

fn setAccessibleName(widget: *GtkWidget, name: [*:0]const u8) void {
    atk_object_set_name(gtk_widget_get_accessible(widget), name);
}

pub export fn noctty_theme_combo_new() ?*GtkWidget {
    return gtk_combo_box_text_new();
}

pub export fn noctty_color_button_new(
    accessible_name: ?[*:0]const u8,
) ?*GtkWidget {
    const button = gtk_color_button_new() orelse return null;
    gtk_color_chooser_set_use_alpha(button, FALSE);
    if (accessible_name) |name| setAccessibleName(button, name);
    return button;
}

pub export fn noctty_tag_combo_new() ?*GtkWidget {
    const combo = gtk_combo_box_text_new_with_entry() orelse return null;
    const entry = gtk_bin_get_child(@ptrCast(combo)) orelse return null;
    gtk_entry_set_placeholder_text(
        @ptrCast(entry),
        "e.g. backend, tests, review",
    );
    setAccessibleName(entry, "Workspace tag");
    return combo;
}

pub export fn noctty_tag_hint_new() ?*GtkWidget {
    const hint = gtk_label_new("Choose an existing tag or type a new one") orelse return null;
    gtk_widget_set_halign(hint, GTK_ALIGN_START);
    gtk_widget_set_opacity(hint, 0.72);
    return hint;
}

pub export fn noctty_shortcut_recorder_label_new(
    plasma: c_int,
) ?*GtkWidget {
    const label = gtk_label_new(
        if (plasma != 0)
            "Press the Plasma shortcut to register. Esc cancels."
        else
            "Press a shortcut. NOCTTY will update the Noctalia compositor binding plan. Esc cancels.",
    ) orelse return null;
    gtk_label_set_line_wrap(@ptrCast(label), TRUE);
    gtk_widget_set_margin_start(label, 16);
    gtk_widget_set_margin_end(label, 16);
    gtk_widget_set_margin_top(label, 14);
    gtk_widget_set_margin_bottom(label, 14);
    return label;
}

pub export fn noctty_settings_notifications_box_new(
    notifications: ?*GtkWidget,
) ?*GtkWidget {
    const child = notifications orelse return null;
    const box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 8) orelse return null;
    gtk_box_pack_start(@ptrCast(box), child, FALSE, FALSE, 0);
    return box;
}

const GridShellContents = extern struct {
    revealer: ?*GtkWidget,
    content_box: ?*GtkWidget,
};

pub export fn noctty_grid_shell_contents_new(
    contents_out: *GridShellContents,
) c_int {
    const revealer = gtk_revealer_new() orelse return FALSE;
    const content_box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0) orelse return FALSE;
    contents_out.* = .{
        .revealer = revealer,
        .content_box = content_box,
    };
    return TRUE;
}

const WindowResizeLayout = extern struct {
    column: c_int,
    row: c_int,
    width: c_int,
    height: c_int,
};

pub export fn noctty_window_resize_layout_new(
    content: ?*GtkWidget,
    handles: [*]const ?*GtkWidget,
    layouts: [*]const WindowResizeLayout,
    handle_count: c_uint,
    resize_grip_out: *?*GtkWidget,
) ?*GtkWidget {
    const child = content orelse return null;
    const grid = gtk_grid_new() orelse return null;
    gtk_widget_set_hexpand(grid, TRUE);
    gtk_widget_set_vexpand(grid, TRUE);
    gtk_widget_set_hexpand(child, TRUE);
    gtk_widget_set_vexpand(child, TRUE);
    const count: usize = @intCast(handle_count);
    var index: usize = 0;
    while (index < count) : (index += 1) {
        const handle = handles[index] orelse continue;
        if (index == 6) continue;
        const layout = layouts[index];
        gtk_grid_attach(
            @ptrCast(grid),
            handle,
            layout.column,
            layout.row,
            1,
            1,
        );
    }
    const grip = handles[6] orelse return null;
    gtk_grid_attach(@ptrCast(grid), child, 1, 1, 1, 1);
    const overlay = gtk_overlay_new() orelse return null;
    gtk_container_add(@ptrCast(overlay), grid);
    gtk_widget_set_halign(grip, GTK_ALIGN_FILL);
    gtk_widget_set_valign(grip, GTK_ALIGN_END);
    gtk_overlay_add_overlay(overlay, grip);
    resize_grip_out.* = grip;
    return overlay;
}

pub export fn noctty_resize_handle_new(
    index: c_int,
    width: c_int,
    height: c_int,
    cursor_name: ?[*:0]const u8,
) ?*GtkWidget {
    const handle = gtk_event_box_new() orelse return null;
    gtk_event_box_set_visible_window(@ptrCast(handle), FALSE);
    gtk_event_box_set_above_child(@ptrCast(handle), TRUE);
    gtk_widget_set_size_request(handle, width, height);
    gtk_widget_set_hexpand(handle, if (width < 0) TRUE else FALSE);
    gtk_widget_set_vexpand(handle, if (height < 0) TRUE else FALSE);
    gtk_widget_set_tooltip_text(
        handle,
        if (index == 6)
            "Drag to resize; double-click to maximize / minimize height"
        else
            "Drag to resize NOCTTY",
    );
    gtk_widget_set_no_show_all(handle, TRUE);
    gtk_widget_add_events(
        handle,
        GDK_BUTTON_PRESS_MASK |
            GDK_BUTTON_RELEASE_MASK |
            GDK_POINTER_MOTION_MASK,
    );
    g_object_set_data(
        object(handle),
        "noctty-resize-index",
        @ptrFromInt(@as(usize, @intCast(index + 1))),
    );
    if (cursor_name) |name| {
        g_object_set_data(
            object(handle),
            "noctty-resize-cursor-name",
            @ptrCast(@constCast(name)),
        );
    }
    return handle;
}

const SmartFilterEmptyContents = extern struct {
    box: ?*GtkWidget,
    label: ?*GtkWidget,
    clear_button: ?*GtkWidget,
};

pub export fn noctty_grid_window_new() ?*GtkWidget {
    return gtk_window_new(0);
}

pub export fn noctty_grid_notebook_new() ?*GtkWidget {
    const notebook = gtk_notebook_new() orelse return null;
    gtk_notebook_set_scrollable(@ptrCast(notebook), TRUE);
    noctty_install_compact_tab_styles(notebook);
    return notebook;
}

pub export fn noctty_grid_input_context_new() ?*GtkIMContext {
    return gtk_im_multicontext_new();
}
pub export fn noctty_grid_window_configure(
    window_optional: ?*GtkWidget,
    default_width: c_int,
    default_height: c_int,
    decorated: c_int,
    keep_above: c_int,
) void {
    const window = window_optional orelse return;
    gtk_style_context_add_class(
        gtk_widget_get_style_context(window),
        "noctty-terminal-window",
    );
    noctty_install_compact_tab_styles(window);
    gtk_window_set_icon_name(@ptrCast(window), "com.noctty.NOCTTY");
    gtk_window_set_default_size(
        @ptrCast(window),
        @max(1, default_width),
        @max(1, default_height),
    );
    gtk_window_set_decorated(@ptrCast(window), decorated);
    gtk_window_set_resizable(@ptrCast(window), TRUE);
    gtk_window_set_keep_above(@ptrCast(window), keep_above);
}
pub export fn noctty_grid_window_apply_mode(
    window_optional: ?*GtkWidget,
    decorated: c_int,
    keep_above: c_int,
) void {
    const window = window_optional orelse return;
    gtk_window_set_decorated(@ptrCast(window), decorated);
    gtk_window_set_resizable(@ptrCast(window), TRUE);
    gtk_window_set_keep_above(@ptrCast(window), keep_above);
}
pub export fn noctty_grid_window_set_decorated(
    window_optional: ?*GtkWidget,
    decorated: c_int,
) void {
    const window = window_optional orelse return;
    gtk_window_set_decorated(@ptrCast(window), decorated);
}

pub export fn noctty_grid_window_set_keep_above(
    window_optional: ?*GtkWidget,
    keep_above: c_int,
) void {
    const window = window_optional orelse return;
    gtk_window_set_keep_above(@ptrCast(window), keep_above);
}

pub export fn noctty_grid_window_set_resizable(
    window_optional: ?*GtkWidget,
    resizable: c_int,
) void {
    const window = window_optional orelse return;
    gtk_window_set_resizable(@ptrCast(window), resizable);
}
pub export fn noctty_grid_window_set_default_size(
    window_optional: ?*GtkWidget,
    width: c_int,
    height: c_int,
) void {
    const window = window_optional orelse return;
    gtk_window_set_default_size(@ptrCast(window), width, height);
}

pub export fn noctty_grid_window_set_modal(
    window_optional: ?*GtkWidget,
    modal: c_int,
) void {
    const window = window_optional orelse return;
    gtk_window_set_modal(@ptrCast(window), modal);
}

pub export fn noctty_grid_window_set_position(
    window_optional: ?*GtkWidget,
    position: c_int,
) void {
    const window = window_optional orelse return;
    gtk_window_set_position(@ptrCast(window), position);
}

pub export fn noctty_grid_window_set_type_hint(
    window_optional: ?*GtkWidget,
    type_hint: c_int,
) void {
    const window = window_optional orelse return;
    gtk_window_set_type_hint(@ptrCast(window), type_hint);
}

pub export fn noctty_grid_window_set_destroy_with_parent(
    window_optional: ?*GtkWidget,
    destroy_with_parent: c_int,
) void {
    const window = window_optional orelse return;
    gtk_window_set_destroy_with_parent(@ptrCast(window), destroy_with_parent);
}
pub export fn noctty_grid_window_set_geometry_hints(
    window_optional: ?*GtkWidget,
    min_width: c_int,
    min_height: c_int,
    max_width: c_int,
    max_height: c_int,
    hints: c_int,
) void {
    const window = window_optional orelse return;
    const geometry = GdkGeometry{
        .min_width = min_width,
        .min_height = min_height,
        .max_width = max_width,
        .max_height = max_height,
        .base_width = 0,
        .base_height = 0,
        .width_inc = 0,
        .height_inc = 0,
        .min_aspect = 0,
        .max_aspect = 0,
        .win_gravity = 0,
    };
    gtk_window_set_geometry_hints(
        @ptrCast(window),
        null,
        &geometry,
        hints,
    );
}
pub export fn noctty_grid_window_set_transient_for(
    window_optional: ?*GtkWidget,
    parent_optional: ?*GtkWidget,
) void {
    const window = window_optional orelse return;
    const parent = parent_optional orelse return;
    gtk_window_set_transient_for(
        @ptrCast(window),
        @ptrCast(parent),
    );
}
pub export fn noctty_grid_widget_destroy(
    widget_optional: ?*GtkWidget,
) void {
    const widget = widget_optional orelse return;
    gtk_widget_destroy(widget);
}

pub export fn noctty_grid_window_resize(
    window_optional: ?*GtkWidget,
    width: c_int,
    height: c_int,
) void {
    const window = window_optional orelse return;
    gtk_window_resize(@ptrCast(window), width, height);
}
pub export fn noctty_grid_window_begin_resize_drag(
    window_optional: ?*anyopaque,
    edge: c_int,
    button: c_int,
    root_x: c_int,
    root_y: c_int,
    time: c_uint,
) void {
    const window = window_optional orelse return;
    gtk_window_begin_resize_drag(
        @ptrCast(window),
        edge,
        button,
        root_x,
        root_y,
        time,
    );
}

pub export fn noctty_grid_window_move(
    window_optional: ?*GtkWidget,
    x: c_int,
    y: c_int,
) void {
    const window = window_optional orelse return;
    gtk_window_move(@ptrCast(window), x, y);
}

pub export fn noctty_grid_window_set_title(
    window_optional: ?*GtkWidget,
    title: ?[*:0]const u8,
) void {
    const window = window_optional orelse return;
    const next_title = title orelse return;
    if (g_strcmp0(gtk_window_get_title(@ptrCast(window)), next_title) != 0) {
        gtk_window_set_title(@ptrCast(window), next_title);
    }
}
pub export fn noctty_grid_window_get_focus(
    window_optional: ?*anyopaque,
) ?*GtkWidget {
    const window = window_optional orelse return null;
    return gtk_window_get_focus(@ptrCast(window));
}

pub export fn noctty_grid_window_get_size(
    window_optional: ?*anyopaque,
    width: ?*c_int,
    height: ?*c_int,
) void {
    const window = window_optional orelse return;
    const width_out = width orelse return;
    const height_out = height orelse return;
    gtk_window_get_size(@ptrCast(window), width_out, height_out);
}

pub export fn noctty_grid_window_get_position(
    window_optional: ?*anyopaque,
    x: ?*c_int,
    y: ?*c_int,
) void {
    const window = window_optional orelse return;
    const x_out = x orelse return;
    const y_out = y orelse return;
    gtk_window_get_position(@ptrCast(window), x_out, y_out);
}

pub export fn noctty_grid_window_is_active(
    window_optional: ?*anyopaque,
) c_int {
    const window = window_optional orelse return FALSE;
    return gtk_window_is_active(@ptrCast(window));
}

pub export fn noctty_grid_window_get_decorated(
    window_optional: ?*anyopaque,
) c_int {
    const window = window_optional orelse return FALSE;
    return gtk_window_get_decorated(@ptrCast(window));
}

pub export fn noctty_grid_window_get_resizable(
    window_optional: ?*anyopaque,
) c_int {
    const window = window_optional orelse return FALSE;
    return gtk_window_get_resizable(@ptrCast(window));
}
pub export fn noctty_grid_window_get_transient_for(
    window_optional: ?*anyopaque,
) ?*GtkWindow {
    const window = window_optional orelse return null;
    return @ptrCast(gtk_window_get_transient_for(@ptrCast(window)));
}

pub export fn noctty_grid_window_get_icon_name(
    window_optional: ?*anyopaque,
) ?[*:0]const u8 {
    const window = window_optional orelse return null;
    return gtk_window_get_icon_name(@ptrCast(window));
}

pub export fn noctty_grid_widget_get_screen(
    widget_optional: ?*anyopaque,
) ?*GdkScreen {
    const widget = widget_optional orelse return null;
    return gtk_widget_get_screen(@ptrCast(widget));
}

pub export fn noctty_grid_widget_get_app_paintable(
    widget_optional: ?*anyopaque,
) c_int {
    const widget = widget_optional orelse return FALSE;
    return gtk_widget_get_app_paintable(@ptrCast(widget));
}

pub export fn noctty_grid_dialog_get_content_area(
    dialog_optional: ?*anyopaque,
) ?*GtkWidget {
    const dialog = dialog_optional orelse return null;
    return gtk_dialog_get_content_area(@ptrCast(dialog));
}

pub export fn noctty_grid_dialog_run(
    dialog_optional: ?*anyopaque,
) c_int {
    const dialog = dialog_optional orelse return -1;
    return gtk_dialog_run(@ptrCast(dialog));
}

pub export fn noctty_grid_dialog_response(
    dialog_optional: ?*anyopaque,
    response: c_int,
) void {
    const dialog = dialog_optional orelse return;
    gtk_dialog_response(@ptrCast(dialog), response);
}

pub export fn noctty_grid_dialog_set_default_response(
    dialog_optional: ?*anyopaque,
    response: c_int,
) void {
    const dialog = dialog_optional orelse return;
    gtk_dialog_set_default_response(@ptrCast(dialog), response);
}

pub export fn noctty_grid_main_level() c_uint {
    return gtk_main_level();
}

pub export fn noctty_grid_main_quit() void {
    gtk_main_quit();
}

pub export fn noctty_grid_show_uri_on_window(
    window_optional: ?*anyopaque,
    uri: [*:0]const u8,
    time: c_uint,
    error_out: ?*?*GError,
) c_int {
    const window = window_optional orelse return FALSE;
    return gtk_show_uri_on_window(@ptrCast(window), uri, time, error_out);
}
pub export fn noctty_grid_window_present(
    window_optional: ?*GtkWidget,
) void {
    const window = window_optional orelse return;
    gtk_window_present(@ptrCast(window));
}

pub export fn noctty_grid_window_set_fullscreen(
    window_optional: ?*GtkWidget,
    fullscreen: c_int,
) void {
    const window = window_optional orelse return;
    if (fullscreen != 0) {
        gtk_window_fullscreen(@ptrCast(window));
    } else {
        gtk_window_unfullscreen(@ptrCast(window));
    }
}

pub export fn noctty_grid_window_set_startup_id(
    window_optional: ?*GtkWidget,
    startup_id: ?[*:0]const u8,
) void {
    const window = window_optional orelse return;
    const id = startup_id orelse return;
    gtk_window_set_startup_id(@ptrCast(window), id);
}
pub export fn noctty_grid_focus_widget(
    window_optional: ?*GtkWidget,
    target_optional: ?*GtkWidget,
) void {
    const target = target_optional orelse return;
    if (window_optional) |window| {
        gtk_window_set_focus(@ptrCast(window), target);
    }
    _ = gtk_widget_grab_focus(target);
}

pub export fn noctty_grid_widget_set_margins(
    widget_optional: ?*GtkWidget,
    start: c_int,
    top: c_int,
    end: c_int,
    bottom: c_int,
) void {
    const widget = widget_optional orelse return;
    gtk_widget_set_margin_start(widget, start);
    gtk_widget_set_margin_top(widget, top);
    gtk_widget_set_margin_end(widget, end);
    gtk_widget_set_margin_bottom(widget, bottom);
}
pub export fn noctty_grid_widget_show(
    widget_optional: ?*GtkWidget,
) void {
    const widget = widget_optional orelse return;
    gtk_widget_show(widget);
}
pub export fn noctty_grid_widget_show_all(
    widget_optional: ?*GtkWidget,
) void {
    const widget = widget_optional orelse return;
    gtk_widget_show_all(widget);
}
pub export fn noctty_grid_widget_get_parent(
    widget_optional: ?*GtkWidget,
) ?*GtkWidget {
    const widget = widget_optional orelse return null;
    return gtk_widget_get_parent(widget);
}

pub export fn noctty_grid_widget_get_visible(
    widget_optional: ?*GtkWidget,
) c_int {
    const widget = widget_optional orelse return FALSE;
    return gtk_widget_get_visible(widget);
}

pub export fn noctty_grid_widget_get_mapped(
    widget_optional: ?*GtkWidget,
) c_int {
    const widget = widget_optional orelse return FALSE;
    return gtk_widget_get_mapped(widget);
}

pub export fn noctty_grid_widget_in_destruction(
    widget_optional: ?*GtkWidget,
) c_int {
    const widget = widget_optional orelse return FALSE;
    return gtk_widget_in_destruction(widget);
}

pub export fn noctty_grid_widget_get_allocation(
    widget_optional: ?*GtkWidget,
    allocation: ?*GtkAllocation,
) void {
    const widget = widget_optional orelse return;
    const allocation_out = allocation orelse return;
    gtk_widget_get_allocation(widget, allocation_out);
}
pub export fn noctty_grid_widget_translate_coordinates(
    source_optional: ?*GtkWidget,
    dest_optional: ?*GtkWidget,
    src_x: c_int,
    src_y: c_int,
    dest_x: ?*c_int,
    dest_y: ?*c_int,
) c_int {
    const source = source_optional orelse return FALSE;
    const dest = dest_optional orelse return FALSE;
    const dest_x_out = dest_x orelse return FALSE;
    const dest_y_out = dest_y orelse return FALSE;
    return gtk_widget_translate_coordinates(
        source,
        dest,
        src_x,
        src_y,
        dest_x_out,
        dest_y_out,
    );
}

pub export fn noctty_grid_widget_get_window(
    widget_optional: ?*GtkWidget,
) ?*GdkWindow {
    const widget = widget_optional orelse return null;
    return gtk_widget_get_window(widget);
}

pub export fn noctty_grid_paned_get_child1(
    paned_optional: ?*anyopaque,
) ?*GtkWidget {
    const paned = paned_optional orelse return null;
    return gtk_paned_get_child1(@ptrCast(paned));
}

pub export fn noctty_grid_paned_get_child2(
    paned_optional: ?*anyopaque,
) ?*GtkWidget {
    const paned = paned_optional orelse return null;
    return gtk_paned_get_child2(@ptrCast(paned));
}

pub export fn noctty_grid_paned_get_position(
    paned_optional: ?*anyopaque,
) c_int {
    const paned = paned_optional orelse return 0;
    return gtk_paned_get_position(@ptrCast(paned));
}

pub export fn noctty_grid_orientable_get_orientation(
    orientable_optional: ?*anyopaque,
) c_int {
    const orientable = orientable_optional orelse return 0;
    return gtk_orientable_get_orientation(@ptrCast(orientable));
}

pub export fn noctty_grid_bin_get_child(
    bin_optional: ?*anyopaque,
) ?*GtkWidget {
    const bin = bin_optional orelse return null;
    return gtk_bin_get_child(@ptrCast(bin));
}

pub export fn noctty_grid_container_get_children(
    container_optional: ?*anyopaque,
) ?*GList {
    const container = container_optional orelse return null;
    return gtk_container_get_children(@ptrCast(container));
}

pub export fn noctty_grid_widget_get_toplevel(
    widget_optional: ?*anyopaque,
) ?*GtkWidget {
    const widget = widget_optional orelse return null;
    return gtk_widget_get_toplevel(@ptrCast(widget));
}
pub export fn noctty_grid_label_get_text(
    label_optional: ?*anyopaque,
) ?[*:0]const u8 {
    const label = label_optional orelse return null;
    return gtk_label_get_text(@ptrCast(label));
}

pub export fn noctty_grid_widget_get_tooltip_text(
    widget_optional: ?*anyopaque,
) ?[*:0]u8 {
    const widget = widget_optional orelse return null;
    return gtk_widget_get_tooltip_text(@ptrCast(widget));
}

pub export fn noctty_grid_entry_get_text(
    entry_optional: ?*anyopaque,
) ?[*:0]const u8 {
    const entry = entry_optional orelse return null;
    return gtk_entry_get_text(@ptrCast(entry));
}

pub export fn noctty_grid_spin_button_get_value_as_int(
    spin_optional: ?*anyopaque,
) c_int {
    const spin = spin_optional orelse return 0;
    return gtk_spin_button_get_value_as_int(@ptrCast(spin));
}

pub export fn noctty_grid_toggle_button_get_active(
    toggle_optional: ?*anyopaque,
) c_int {
    const toggle = toggle_optional orelse return FALSE;
    return gtk_toggle_button_get_active(@ptrCast(toggle));
}

pub export fn noctty_grid_combo_box_get_active(
    combo_optional: ?*anyopaque,
) c_int {
    const combo = combo_optional orelse return -1;
    return gtk_combo_box_get_active(@ptrCast(combo));
}

pub export fn noctty_grid_range_get_value(
    range_optional: ?*anyopaque,
) f64 {
    const range = range_optional orelse return 0;
    return gtk_range_get_value(@ptrCast(range));
}

pub export fn noctty_grid_widget_get_scale_factor(
    widget_optional: ?*anyopaque,
) c_int {
    const widget = widget_optional orelse return 1;
    return gtk_widget_get_scale_factor(@ptrCast(widget));
}
pub export fn noctty_grid_combo_box_get_active_id(
    combo_optional: ?*anyopaque,
) ?[*:0]const u8 {
    const combo = combo_optional orelse return null;
    return gtk_combo_box_get_active_id(@ptrCast(combo));
}

pub export fn noctty_grid_combo_box_text_get_active_text(
    combo_optional: ?*anyopaque,
) ?[*:0]u8 {
    const combo = combo_optional orelse return null;
    return gtk_combo_box_text_get_active_text(@ptrCast(combo));
}

pub export fn noctty_grid_file_chooser_get_filename(
    chooser_optional: ?*anyopaque,
) ?[*:0]u8 {
    const chooser = chooser_optional orelse return null;
    return gtk_file_chooser_get_filename(@ptrCast(chooser));
}

pub export fn noctty_grid_list_box_get_row_at_index(
    list_optional: ?*anyopaque,
    index: c_int,
) ?*GtkListBoxRow {
    const list = list_optional orelse return null;
    return gtk_list_box_get_row_at_index(@ptrCast(list), index);
}

pub export fn noctty_grid_list_box_select_row(
    list_optional: ?*anyopaque,
    row_optional: ?*GtkListBoxRow,
) void {
    const list = list_optional orelse return;
    gtk_list_box_select_row(@ptrCast(list), row_optional);
}

pub export fn noctty_grid_event_box_set_above_child(
    event_box_optional: ?*anyopaque,
    above_child: c_int,
) void {
    const event_box = event_box_optional orelse return;
    gtk_event_box_set_above_child(@ptrCast(event_box), above_child);
}

pub export fn noctty_grid_entry_set_icon_from_icon_name(
    entry_optional: ?*anyopaque,
    icon_pos: c_int,
    icon_name: ?[*:0]const u8,
) void {
    const entry = entry_optional orelse return;
    gtk_entry_set_icon_from_icon_name(@ptrCast(entry), icon_pos, icon_name);
}

pub export fn noctty_grid_entry_set_icon_tooltip_text(
    entry_optional: ?*anyopaque,
    icon_pos: c_int,
    tooltip: ?[*:0]const u8,
) void {
    const entry = entry_optional orelse return;
    gtk_entry_set_icon_tooltip_text(@ptrCast(entry), icon_pos, tooltip);
}
pub export fn noctty_grid_label_set_text(
    label_optional: ?*anyopaque,
    text: [*:0]const u8,
) void {
    const label = label_optional orelse return;
    gtk_label_set_text(@ptrCast(label), text);
}

pub export fn noctty_grid_label_set_markup(
    label_optional: ?*anyopaque,
    markup: [*:0]const u8,
) void {
    const label = label_optional orelse return;
    gtk_label_set_markup(@ptrCast(label), markup);
}

pub export fn noctty_grid_entry_set_text(
    entry_optional: ?*anyopaque,
    text: [*:0]const u8,
) void {
    const entry = entry_optional orelse return;
    gtk_entry_set_text(@ptrCast(entry), text);
}

pub export fn noctty_grid_button_set_label(
    button_optional: ?*anyopaque,
    label: [*:0]const u8,
) void {
    const button = button_optional orelse return;
    gtk_button_set_label(@ptrCast(button), label);
}

pub export fn noctty_grid_button_clicked(
    button_optional: ?*anyopaque,
) void {
    const button = button_optional orelse return;
    gtk_button_clicked(@ptrCast(button));
}

pub export fn noctty_grid_combo_box_set_active(
    combo_optional: ?*anyopaque,
    index: c_int,
) void {
    const combo = combo_optional orelse return;
    gtk_combo_box_set_active(@ptrCast(combo), index);
}

pub export fn noctty_grid_combo_box_set_active_id(
    combo_optional: ?*anyopaque,
    id: [*:0]const u8,
) c_int {
    const combo = combo_optional orelse return FALSE;
    return gtk_combo_box_set_active_id(@ptrCast(combo), id);
}

pub export fn noctty_grid_spin_button_set_value(
    spin_optional: ?*anyopaque,
    value: f64,
) void {
    const spin = spin_optional orelse return;
    gtk_spin_button_set_value(@ptrCast(spin), value);
}

pub export fn noctty_grid_toggle_button_set_active(
    toggle_optional: ?*anyopaque,
    active: c_int,
) void {
    const toggle = toggle_optional orelse return;
    gtk_toggle_button_set_active(@ptrCast(toggle), active);
}

pub export fn noctty_grid_range_set_value(
    range_optional: ?*anyopaque,
    value: f64,
) void {
    const range = range_optional orelse return;
    gtk_range_set_value(@ptrCast(range), value);
}
pub export fn noctty_grid_clipboard_get(
    selection_optional: ?*anyopaque,
) ?*GtkClipboard {
    return gtk_clipboard_get(selection_optional);
}

pub export fn noctty_grid_clipboard_request_text(
    clipboard_optional: ?*anyopaque,
    callback_optional: ?GtkClipboardTextReceivedCallback,
    data: ?*anyopaque,
) void {
    const clipboard = clipboard_optional orelse return;
    const callback = callback_optional orelse return;
    gtk_clipboard_request_text(@ptrCast(clipboard), callback, data);
}

pub export fn noctty_grid_clipboard_set_text(
    clipboard_optional: ?*anyopaque,
    text: [*:0]const u8,
    length: c_int,
) void {
    const clipboard = clipboard_optional orelse return;
    gtk_clipboard_set_text(@ptrCast(clipboard), text, length);
}

pub export fn noctty_grid_im_context_focus_in(
    context_optional: ?*anyopaque,
) void {
    const context = context_optional orelse return;
    gtk_im_context_focus_in(@ptrCast(context));
}

pub export fn noctty_grid_im_context_focus_out(
    context_optional: ?*anyopaque,
) void {
    const context = context_optional orelse return;
    gtk_im_context_focus_out(@ptrCast(context));
}

pub export fn noctty_grid_im_context_filter_keypress(
    context_optional: ?*anyopaque,
    event_optional: ?*anyopaque,
) c_int {
    const context = context_optional orelse return FALSE;
    return gtk_im_context_filter_keypress(
        @ptrCast(context),
        event_optional,
    );
}

pub export fn noctty_grid_editable_select_region(
    editable_optional: ?*anyopaque,
    start_pos: c_int,
    end_pos: c_int,
) void {
    const editable = editable_optional orelse return;
    gtk_editable_select_region(@ptrCast(editable), start_pos, end_pos);
}
pub export fn noctty_grid_widget_get_accessible(
    widget_optional: ?*anyopaque,
) ?*AtkObject {
    const widget = widget_optional orelse return null;
    return gtk_widget_get_accessible(@ptrCast(widget));
}

pub export fn noctty_grid_widget_get_style_context(
    widget_optional: ?*anyopaque,
) ?*GtkStyleContext {
    const widget = widget_optional orelse return null;
    return gtk_widget_get_style_context(@ptrCast(widget));
}

pub export fn noctty_grid_style_context_add_class(
    style_optional: ?*anyopaque,
    class_name: [*:0]const u8,
) void {
    const style = style_optional orelse return;
    gtk_style_context_add_class(@ptrCast(style), class_name);
}

pub export fn noctty_grid_style_context_remove_class(
    style_optional: ?*anyopaque,
    class_name: [*:0]const u8,
) void {
    const style = style_optional orelse return;
    gtk_style_context_remove_class(@ptrCast(style), class_name);
}

pub export fn noctty_grid_style_context_has_class(
    style_optional: ?*anyopaque,
    class_name: [*:0]const u8,
) c_int {
    const style = style_optional orelse return FALSE;
    return gtk_style_context_has_class(@ptrCast(style), class_name);
}

pub export fn noctty_grid_atk_object_set_name(
    accessible_optional: ?*anyopaque,
    name: [*:0]const u8,
) void {
    const accessible = accessible_optional orelse return;
    atk_object_set_name(@ptrCast(accessible), name);
}

pub export fn noctty_grid_atk_object_set_description(
    accessible_optional: ?*anyopaque,
    description: [*:0]const u8,
) void {
    const accessible = accessible_optional orelse return;
    atk_object_set_description(@ptrCast(accessible), description);
}

pub export fn noctty_grid_atk_object_set_role(
    accessible_optional: ?*anyopaque,
    role: c_int,
) void {
    const accessible = accessible_optional orelse return;
    atk_object_set_role(@ptrCast(accessible), role);
}

pub export fn noctty_grid_atk_object_get_name(
    accessible_optional: ?*anyopaque,
) ?[*:0]const u8 {
    const accessible = accessible_optional orelse return null;
    return atk_object_get_name(@ptrCast(accessible));
}

pub export fn noctty_grid_atk_object_get_description(
    accessible_optional: ?*anyopaque,
) ?[*:0]const u8 {
    const accessible = accessible_optional orelse return null;
    return atk_object_get_description(@ptrCast(accessible));
}

pub export fn noctty_grid_atk_object_get_role(
    accessible_optional: ?*anyopaque,
) c_int {
    const accessible = accessible_optional orelse return 0;
    return atk_object_get_role(@ptrCast(accessible));
}
pub export fn noctty_grid_widget_has_focus(
    widget_optional: ?*GtkWidget,
) c_int {
    const widget = widget_optional orelse return FALSE;
    return gtk_widget_has_focus(widget);
}

pub export fn noctty_grid_widget_get_display(
    widget_optional: ?*GtkWidget,
) ?*GdkDisplay {
    const widget = widget_optional orelse return null;
    return gtk_widget_get_display(widget);
}

pub export fn noctty_grid_widget_get_ancestor(
    widget_optional: ?*GtkWidget,
    widget_type: GType,
) ?*GtkWidget {
    const widget = widget_optional orelse return null;
    return gtk_widget_get_ancestor(widget, widget_type);
}

pub export fn noctty_grid_widget_get_frame_clock(
    widget_optional: ?*GtkWidget,
) ?*GdkFrameClock {
    const widget = widget_optional orelse return null;
    return gtk_widget_get_frame_clock(widget);
}

pub export fn noctty_grid_grab_get_current() ?*GtkWidget {
    return gtk_grab_get_current();
}

pub export fn noctty_grid_grab_add(widget_optional: ?*GtkWidget) void {
    const widget = widget_optional orelse return;
    gtk_grab_add(widget);
}

pub export fn noctty_grid_grab_remove(widget_optional: ?*GtkWidget) void {
    const widget = widget_optional orelse return;
    gtk_grab_remove(widget);
}

pub export fn noctty_grid_widget_has_grab(
    widget_optional: ?*GtkWidget,
) c_int {
    const widget = widget_optional orelse return FALSE;
    return gtk_widget_has_grab(widget);
}

pub export fn noctty_grid_widget_get_size_request(
    widget_optional: ?*GtkWidget,
    width: ?*c_int,
    height: ?*c_int,
) void {
    const widget = widget_optional orelse return;
    gtk_widget_get_size_request(widget, width, height);
}

pub export fn noctty_grid_window_list_toplevels() ?*GList {
    return gtk_window_list_toplevels();
}

pub export fn noctty_grid_check_menu_item_set_active(
    item_optional: ?*GtkWidget,
    active: c_int,
) void {
    const item = item_optional orelse return;
    gtk_check_menu_item_set_active(item, active);
}

pub export fn noctty_grid_revealer_set_reveal_child(
    revealer_optional: ?*GtkWidget,
    reveal: c_int,
) void {
    const revealer = revealer_optional orelse return;
    gtk_revealer_set_reveal_child(revealer, reveal);
}

pub export fn noctty_grid_revealer_set_transition_duration(
    revealer_optional: ?*GtkWidget,
    duration: c_uint,
) void {
    const revealer = revealer_optional orelse return;
    gtk_revealer_set_transition_duration(revealer, duration);
}

pub export fn noctty_grid_revealer_set_transition_type(
    revealer_optional: ?*GtkWidget,
    transition_type: c_int,
) void {
    const revealer = revealer_optional orelse return;
    gtk_revealer_set_transition_type(revealer, transition_type);
}
pub export fn noctty_grid_widget_add_tick_callback(
    widget_optional: ?*GtkWidget,
    callback_optional: ?GCallback,
    data: ?*anyopaque,
    destroy_notify: ?GDestroyNotify,
) c_uint {
    const widget = widget_optional orelse return 0;
    const callback = callback_optional orelse return 0;
    return gtk_widget_add_tick_callback(
        widget,
        @ptrCast(callback),
        data,
        destroy_notify,
    );
}

pub export fn noctty_grid_drag_finish(
    drag: ?*anyopaque,
    delete_data: c_int,
    success: c_int,
    time: c_uint,
) void {
    gtk_drag_finish(drag, delete_data, success, time);
}

pub export fn noctty_grid_events_pending() c_int {
    return gtk_events_pending();
}

pub export fn noctty_grid_main_iteration_do(blocking: c_int) void {
    gtk_main_iteration_do(blocking);
}

pub export fn noctty_grid_widget_set_app_paintable(
    widget_optional: ?*GtkWidget,
    app_paintable: c_int,
) void {
    const widget = widget_optional orelse return;
    gtk_widget_set_app_paintable(widget, app_paintable);
}

pub export fn noctty_grid_widget_set_visual(
    widget_optional: ?*GtkWidget,
    visual: ?*anyopaque,
) void {
    const widget = widget_optional orelse return;
    gtk_widget_set_visual(widget, visual);
}

pub export fn noctty_grid_widget_hide(
    widget_optional: ?*GtkWidget,
) void {
    const widget = widget_optional orelse return;
    gtk_widget_hide(widget);
}

pub export fn noctty_grid_widget_set_visible(
    widget_optional: ?*GtkWidget,
    visible: c_int,
) void {
    const widget = widget_optional orelse return;
    gtk_widget_set_visible(widget, visible);
}

pub export fn noctty_grid_widget_set_can_focus(
    widget_optional: ?*GtkWidget,
    can_focus: c_int,
) void {
    const widget = widget_optional orelse return;
    gtk_widget_set_can_focus(widget, can_focus);
}
pub export fn noctty_grid_widget_set_sensitive(
    widget_optional: ?*GtkWidget,
    sensitive: c_int,
) void {
    const widget = widget_optional orelse return;
    gtk_widget_set_sensitive(widget, sensitive);
}
pub export fn noctty_grid_widget_set_no_show_all(
    widget_optional: ?*GtkWidget,
    no_show_all: c_int,
) void {
    const widget = widget_optional orelse return;
    gtk_widget_set_no_show_all(widget, no_show_all);
}
pub export fn noctty_grid_widget_add_events(
    widget_optional: ?*GtkWidget,
    events: c_int,
) void {
    const widget = widget_optional orelse return;
    gtk_widget_add_events(widget, events);
}
pub export fn noctty_grid_drag_source_set(
    widget_optional: ?*GtkWidget,
    start_button_mask: c_uint,
    targets: ?*anyopaque,
    target_count: c_int,
    actions: c_uint,
) void {
    const widget = widget_optional orelse return;
    gtk_drag_source_set(
        widget,
        start_button_mask,
        targets,
        target_count,
        actions,
    );
}

pub export fn noctty_grid_drag_dest_set(
    widget_optional: ?*GtkWidget,
    dest_defaults: c_uint,
    targets: ?*anyopaque,
    target_count: c_int,
    actions: c_uint,
) void {
    const widget = widget_optional orelse return;
    gtk_drag_dest_set(
        widget,
        dest_defaults,
        targets,
        target_count,
        actions,
    );
}
pub export fn noctty_grid_widget_set_size_request(
    widget_optional: ?*GtkWidget,
    width: c_int,
    height: c_int,
) void {
    const widget = widget_optional orelse return;
    gtk_widget_set_size_request(widget, width, height);
}

pub export fn noctty_grid_widget_set_tooltip_text(
    widget_optional: ?*GtkWidget,
    tooltip: ?[*:0]const u8,
) void {
    const widget = widget_optional orelse return;
    gtk_widget_set_tooltip_text(widget, tooltip);
}

pub export fn noctty_grid_widget_queue_draw(
    widget_optional: ?*GtkWidget,
) void {
    const widget = widget_optional orelse return;
    gtk_widget_queue_draw(widget);
}

pub export fn noctty_grid_widget_queue_draw_area(
    widget_optional: ?*GtkWidget,
    x: c_int,
    y: c_int,
    width: c_int,
    height: c_int,
) void {
    const widget = widget_optional orelse return;
    gtk_widget_queue_draw_area(widget, x, y, width, height);
}

pub export fn noctty_grid_widget_queue_resize(
    widget_optional: ?*GtkWidget,
) void {
    const widget = widget_optional orelse return;
    gtk_widget_queue_resize(widget);
}




const GridWindowCallbacks = extern struct {
    delete_event: ?GCallback,
    destroy: ?GCallback,
    focus_out_event: ?GCallback,
    map: ?GCallback,
    configure_event: ?GCallback,
    button_release_event: ?GCallback,
};

pub export fn noctty_grid_window_connect_signals(
    window_optional: ?*GtkWidget,
    context: ?*anyopaque,
    callbacks_raw: ?*const GridWindowCallbacks,
) c_int {
    const window = window_optional orelse return FALSE;
    const callbacks = callbacks_raw orelse return FALSE;
    connectSignal(window, "delete-event", callbacks.delete_event, context);
    connectSignal(window, "destroy", callbacks.destroy, null);
    connectSignal(window, "focus-out-event", callbacks.focus_out_event, context);
    connectSignal(window, "map", callbacks.map, context);
    connectSignal(window, "configure-event", callbacks.configure_event, context);
    connectSignal(window, "button-release-event", callbacks.button_release_event, context);
    return TRUE;
}

const GridNotebookCallbacks = extern struct {
    switch_page: ?GCallback,
    drag_begin: ?GCallback,
    drag_end: ?GCallback,
    page_reordered: ?GCallback,
};

pub export fn noctty_grid_notebook_configure(
    notebook_optional: ?*GtkWidget,
    new_tab_button_optional: ?*GtkWidget,
    toolbar_optional: ?*GtkWidget,
    context: ?*anyopaque,
    callbacks_raw: ?*const GridNotebookCallbacks,
) c_int {
    const notebook = notebook_optional orelse return FALSE;
    const new_tab_button = new_tab_button_optional orelse return FALSE;
    const toolbar = toolbar_optional orelse return FALSE;
    const callbacks = callbacks_raw orelse return FALSE;
    connectSignal(notebook, "switch-page", callbacks.switch_page, context);
    connectSignal(notebook, "drag-begin", callbacks.drag_begin, context);
    connectSignal(notebook, "drag-end", callbacks.drag_end, context);
    connectSignal(notebook, "page-reordered", callbacks.page_reordered, context);
    gtk_notebook_set_action_widget(@ptrCast(notebook), new_tab_button, 0);
    gtk_widget_show_all(new_tab_button);
    gtk_notebook_set_action_widget(@ptrCast(notebook), toolbar, 1);
    gtk_widget_show_all(toolbar);
    return TRUE;
}
pub export fn noctty_grid_notebook_append_page(
    notebook_optional: ?*GtkWidget,
    page_optional: ?*GtkWidget,
    tab_widget_optional: ?*GtkWidget,
) c_int {
    const notebook = notebook_optional orelse return -1;
    const page = page_optional orelse return -1;
    const tab_widget = tab_widget_optional orelse return -1;
    const page_index = gtk_notebook_append_page(
        @ptrCast(notebook),
        page,
        tab_widget,
    );

    if (page_index < 0) return -1;
    gtk_notebook_set_tab_reorderable(@ptrCast(notebook), page, TRUE);
    gtk_notebook_set_tab_detachable(@ptrCast(notebook), page, FALSE);
    return page_index;
}
pub export fn noctty_grid_notebook_apply_policy(
    notebook_optional: ?*GtkWidget,
    toolbar_optional: ?*GtkWidget,
    tab_position: c_int,
    show_tabs: c_int,
) void {
    const notebook = notebook_optional orelse return;
    const gtk_position: c_int = switch (tab_position) {
        0 => 2,
        1 => 3,
        2 => 0,
        3 => 1,
        else => return,
    };
    gtk_notebook_set_tab_pos(@ptrCast(notebook), gtk_position);
    gtk_notebook_set_show_tabs(@ptrCast(notebook), show_tabs);
    gtk_notebook_set_show_border(@ptrCast(notebook), FALSE);
    if (toolbar_optional) |toolbar| {
        gtk_orientable_set_orientation(
            @ptrCast(toolbar),
            if (tab_position < 2) GTK_ORIENTATION_HORIZONTAL else GTK_ORIENTATION_VERTICAL,
        );
    }
}
pub export fn noctty_grid_notebook_select_page(
    notebook_optional: ?*GtkWidget,
    page_index: c_int,
) void {
    const notebook = notebook_optional orelse return;
    if (page_index < 0) return;
    gtk_notebook_set_current_page(@ptrCast(notebook), page_index);
}
pub export fn noctty_grid_notebook_get_n_pages(
    notebook_optional: ?*anyopaque,
) c_int {
    const notebook = notebook_optional orelse return 0;
    return gtk_notebook_get_n_pages(@ptrCast(notebook));
}

pub export fn noctty_grid_notebook_get_current_page(
    notebook_optional: ?*anyopaque,
) c_int {
    const notebook = notebook_optional orelse return -1;
    return gtk_notebook_get_current_page(@ptrCast(notebook));
}

pub export fn noctty_grid_notebook_get_nth_page(
    notebook_optional: ?*anyopaque,
    page_index: c_int,
) ?*GtkWidget {
    const notebook = notebook_optional orelse return null;
    return gtk_notebook_get_nth_page(@ptrCast(notebook), page_index);
}

pub export fn noctty_grid_notebook_get_tab_label(
    notebook_optional: ?*anyopaque,
    page_optional: ?*anyopaque,
) ?*GtkWidget {
    const notebook = notebook_optional orelse return null;
    const page = page_optional orelse return null;
    return gtk_notebook_get_tab_label(@ptrCast(notebook), @ptrCast(page));
}

pub export fn noctty_grid_notebook_get_show_tabs(
    notebook_optional: ?*anyopaque,
) c_int {
    const notebook = notebook_optional orelse return FALSE;
    return gtk_notebook_get_show_tabs(@ptrCast(notebook));
}

pub export fn noctty_grid_notebook_get_action_widget(
    notebook_optional: ?*anyopaque,
    pack_type: c_int,
) ?*GtkWidget {
    const notebook = notebook_optional orelse return null;
    return gtk_notebook_get_action_widget(@ptrCast(notebook), pack_type);
}

pub export fn noctty_grid_notebook_get_tab_pos(
    notebook_optional: ?*anyopaque,
) c_int {
    const notebook = notebook_optional orelse return 0;
    return gtk_notebook_get_tab_pos(@ptrCast(notebook));
}

pub export fn noctty_grid_notebook_page_num(
    notebook_optional: ?*anyopaque,
    page_optional: ?*anyopaque,
) c_int {
    const notebook = notebook_optional orelse return -1;
    const page = page_optional orelse return -1;
    return gtk_notebook_page_num(@ptrCast(notebook), @ptrCast(page));
}

pub export fn noctty_grid_notebook_reorder_child(
    notebook_optional: ?*anyopaque,
    page_optional: ?*anyopaque,
    page_index: c_int,
) void {
    const notebook = notebook_optional orelse return;
    const page = page_optional orelse return;
    gtk_notebook_reorder_child(@ptrCast(notebook), @ptrCast(page), page_index);
}

pub export fn noctty_grid_notebook_remove_page(
    notebook_optional: ?*anyopaque,
    page_index: c_int,
) void {
    const notebook = notebook_optional orelse return;
    gtk_notebook_remove_page(@ptrCast(notebook), page_index);
}
pub export fn noctty_grid_menu_popdown(menu_optional: ?*anyopaque) void {
    const menu = menu_optional orelse return;
    gtk_menu_popdown(@ptrCast(menu));
}

pub export fn noctty_grid_menu_item_get_label(
    item_optional: ?*anyopaque,
) ?[*:0]const u8 {
    const item = item_optional orelse return null;
    return gtk_menu_item_get_label(@ptrCast(item));
}

pub export fn noctty_grid_menu_item_get_submenu(
    item_optional: ?*anyopaque,
) ?*GtkWidget {
    const item = item_optional orelse return null;
    return gtk_menu_item_get_submenu(@ptrCast(item));
}

pub export fn noctty_grid_menu_item_activate(item_optional: ?*anyopaque) void {
    const item = item_optional orelse return;
    gtk_menu_item_activate(@ptrCast(item));
}

pub export fn noctty_grid_menu_shell_select_item(
    shell_optional: ?*anyopaque,
    item_optional: ?*anyopaque,
) void {
    const shell = shell_optional orelse return;
    const item = item_optional orelse return;
    gtk_menu_shell_select_item(@ptrCast(shell), @ptrCast(item));
}

pub export fn noctty_grid_menu_shell_activate_item(
    shell_optional: ?*anyopaque,
    item_optional: ?*anyopaque,
    force: c_int,
) c_int {
    const shell = shell_optional orelse return FALSE;
    const item = item_optional orelse return FALSE;
    return gtk_menu_shell_activate_item(@ptrCast(shell), @ptrCast(item), force);
}

pub export fn noctty_grid_menu_get_attach_widget(
    menu_optional: ?*anyopaque,
) ?*GtkWidget {
    const menu = menu_optional orelse return null;
    return gtk_menu_get_attach_widget(@ptrCast(menu));
}

pub export fn noctty_grid_menu_popup_at_widget(
    menu_optional: ?*anyopaque,
    anchor_optional: ?*GtkWidget,
    widget_gravity: c_int,
    menu_gravity: c_int,
    event: ?*anyopaque,
) void {
    const menu = menu_optional orelse return;
    const anchor = anchor_optional orelse return;
    gtk_menu_popup_at_widget(
        @ptrCast(menu),
        anchor,
        widget_gravity,
        menu_gravity,
        event,
    );
}

pub export fn noctty_grid_menu_popup_at_rect(
    menu_optional: ?*anyopaque,
    window_optional: ?*GdkWindow,
    rect: ?*const GdkRectangle,
    rect_gravity: c_int,
    menu_gravity: c_int,
    event: ?*anyopaque,
) void {
    const menu = menu_optional orelse return;
    const window = window_optional orelse return;
    const rectangle = rect orelse return;
    gtk_menu_popup_at_rect(
        @ptrCast(menu),
        window,
        rectangle,
        rect_gravity,
        menu_gravity,
        event,
    );
}





pub export fn noctty_grid_page_new(
    panel_padding: c_int,
    pane_info_strip: ?*GtkWidget,
) ?*GtkWidget {
    const page = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0) orelse return null;
    gtk_container_set_border_width(
        @ptrCast(page),
        if (panel_padding > 0) @intCast(panel_padding) else 0,
    );
    g_object_set_data(
        object(page),
        "noctty-pane-info-strip",
        @ptrCast(pane_info_strip),
    );
    return page;
}

pub export fn noctty_smart_filter_empty_contents_new(
    message: ?[*:0]const u8,
    contents_out: *SmartFilterEmptyContents,
) c_int {
    const text = message orelse return FALSE;
    const box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 8) orelse return FALSE;
    gtk_widget_set_margin_top(box, 16);
    gtk_widget_set_margin_bottom(box, 16);
    gtk_widget_set_halign(box, GTK_ALIGN_CENTER);
    const label = gtk_label_new(text) orelse return FALSE;
    gtk_widget_set_tooltip_text(
        label,
        "The current Smart Tab tag matches no visible panes",
    );
    gtk_widget_set_opacity(label, 0.72);
    gtk_box_pack_start(@ptrCast(box), label, FALSE, FALSE, 0);
    const clear_button = gtk_button_new_with_label("Clear filter") orelse return FALSE;
    noctty_configure_action_button(
        clear_button,
        "Clear the Smart Tab filter and show all panes",
    );
    gtk_box_pack_start(@ptrCast(box), clear_button, FALSE, FALSE, 0);
    contents_out.* = .{
        .box = box,
        .label = label,
        .clear_button = clear_button,
    };
    return TRUE;
}

pub export fn noctty_tab_rename_entry_new(
    title: ?[*:0]const u8,
    width_chars: c_int,
    height: c_int,
) ?*GtkWidget {
    const text = title orelse return null;
    const entry = gtk_entry_new() orelse return null;
    gtk_entry_set_text(@ptrCast(entry), text);
    gtk_entry_set_has_frame(@ptrCast(entry), FALSE);
    gtk_entry_set_alignment(@ptrCast(entry), 0.5);
    gtk_entry_set_max_length(@ptrCast(entry), 128);
    gtk_entry_set_width_chars(@ptrCast(entry), width_chars);
    gtk_entry_set_max_width_chars(@ptrCast(entry), 24);
    gtk_widget_set_size_request(entry, -1, if (height > 12) height else 12);
    gtk_style_context_add_class(gtk_widget_get_style_context(entry), "flat");
    gtk_style_context_add_class(
        gtk_widget_get_style_context(entry),
        "noctty-tab-rename",
    );
    gtk_widget_set_tooltip_text(
        entry,
        "Enter to save · Esc or click elsewhere to cancel",
    );
    return entry;
}

pub export fn noctty_recovery_notice_new(
    message: ?[*:0]const u8,
    apply_response: c_int,
    close_response: c_int,
) ?*GtkWidget {
    const text = message orelse return null;
    const bar = gtk_info_bar_new_with_buttons(
        "Open Settings",
        apply_response,
        "Dismiss",
        close_response,
        @as(?[*:0]const u8, null),
    ) orelse return null;
    gtk_info_bar_set_message_type(bar, 1);
    gtk_widget_set_name(bar, "noctty-recovery-notice");
    const label = gtk_label_new(text) orelse return null;
    gtk_label_set_xalign(@ptrCast(label), 0.0);
    gtk_label_set_line_wrap(@ptrCast(label), TRUE);
    gtk_label_set_max_width_chars(@ptrCast(label), 96);
    setAccessibleName(label, "NOCTTY startup recovery notice");
    gtk_box_pack_start(
        @ptrCast(gtk_info_bar_get_content_area(bar)),
        label,
        TRUE,
        TRUE,
        0,
    );
    return bar;
}

pub export fn noctty_terminal_find_contents_new(
    dialog: ?*GtkWidget,
    dialog_width: c_int,
    vertical: c_int,
    contents_out: ?*FindContents,
) c_int {
    const target = dialog orelse return FALSE;
    const output = contents_out orelse return FALSE;
    output.* = .{ .entry = null, .status = null };

    const box = gtk_box_new(
        if (vertical != 0) GTK_ORIENTATION_VERTICAL else GTK_ORIENTATION_HORIZONTAL,
        10,
    ) orelse return FALSE;
    const entry = gtk_search_entry_new() orelse return FALSE;
    const status = gtk_label_new("Type to search scrollback") orelse return FALSE;
    gtk_entry_set_placeholder_text(@ptrCast(entry), "Find in terminal…");
    setAccessibleName(entry, "Search terminal scrollback");
    setAccessibleName(status, "Terminal search status");
    gtk_label_set_xalign(@ptrCast(status), 0.0);
    gtk_label_set_line_wrap(@ptrCast(status), TRUE);
    gtk_widget_set_size_request(entry, @min(330, @max(1, dialog_width - 16)), -1);
    gtk_container_set_border_width(@ptrCast(box), 8);
    gtk_box_pack_start(@ptrCast(box), entry, TRUE, TRUE, 0);
    gtk_box_pack_start(@ptrCast(box), status, FALSE, FALSE, 0);
    gtk_container_add(@ptrCast(gtk_dialog_get_content_area(@ptrCast(target))), box);
    output.* = .{ .entry = entry, .status = status };
    return TRUE;
}

pub export fn noctty_quick_note_contents_new(
    dialog: ?*GtkWidget,
    dialog_width: c_int,
    dialog_height: c_int,
    contents_out: ?*QuickNoteContents,
) c_int {
    const target = dialog orelse return FALSE;
    const output = contents_out orelse return FALSE;
    output.* = .{ .view = null, .status = null };

    const box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 6) orelse return FALSE;
    const status = gtk_label_new("Workspace note · saved automatically") orelse return FALSE;
    const scroll = gtk_scrolled_window_new(null, null) orelse return FALSE;
    const view = gtk_text_view_new() orelse return FALSE;
    gtk_text_view_set_monospace(@ptrCast(view), TRUE);
    gtk_text_view_set_wrap_mode(@ptrCast(view), GTK_WRAP_WORD_CHAR);
    setAccessibleName(view, "Workspace quick note");
    setAccessibleName(status, "Workspace note save status");
    gtk_widget_set_size_request(
        scroll,
        @max(1, dialog_width - 16),
        @max(1, dialog_height - 96),
    );
    gtk_container_add(@ptrCast(scroll), view);
    gtk_container_set_border_width(@ptrCast(box), 8);
    gtk_box_pack_start(@ptrCast(box), status, FALSE, FALSE, 0);
    gtk_box_pack_start(@ptrCast(box), scroll, TRUE, TRUE, 0);
    gtk_container_add(@ptrCast(gtk_dialog_get_content_area(@ptrCast(target))), box);
    output.* = .{ .view = view, .status = status };
    return TRUE;
}

pub export fn noctty_shortcuts_contents_new(
    dialog: ?*GtkWidget,
    shortcuts: ?[*:0]const u8,
    dialog_width: c_int,
    dialog_height: c_int,
) c_int {
    const target = dialog orelse return FALSE;
    const text = shortcuts orelse return FALSE;
    const scroll = gtk_scrolled_window_new(null, null) orelse return FALSE;
    const label = gtk_label_new(text) orelse return FALSE;
    gtk_label_set_xalign(@ptrCast(label), 0.0);
    gtk_widget_set_margin_start(label, 16);
    gtk_widget_set_margin_end(label, 16);
    gtk_widget_set_margin_top(label, 12);
    gtk_widget_set_margin_bottom(label, 12);
    setAccessibleName(label, "NOCTTY keyboard shortcuts");
    gtk_scrolled_window_set_policy(
        @ptrCast(scroll),
        GTK_POLICY_AUTOMATIC,
        GTK_POLICY_AUTOMATIC,
    );
    gtk_widget_set_size_request(
        scroll,
        @max(1, dialog_width - 16),
        @max(1, dialog_height - 72),
    );
    gtk_container_add(@ptrCast(scroll), label);
    gtk_container_add(@ptrCast(gtk_dialog_get_content_area(@ptrCast(target))), scroll);
    return TRUE;
}

pub export fn noctty_command_palette_contents_new(
    dialog: ?*GtkWidget,
    dialog_width: c_int,
    dialog_height: c_int,
    vertical_rows: c_int,
    actions_raw: ?[*]const PaletteAction,
    action_count: c_uint,
    visibility_hint: ?[*:0]const u8,
    contents_out: ?*PaletteContents,
) c_int {
    const target = dialog orelse return FALSE;
    const actions = actions_raw orelse return FALSE;
    const output = contents_out orelse return FALSE;
    output.* = .{ .search = null, .list = null };
    if (action_count == 0 or action_count > 128) return FALSE;

    const box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 5) orelse return FALSE;
    const search = gtk_search_entry_new() orelse return FALSE;
    const list = gtk_list_box_new() orelse return FALSE;
    const scroll = gtk_scrolled_window_new(null, null) orelse return FALSE;
    gtk_entry_set_placeholder_text(@ptrCast(search), "Type a command…");
    setAccessibleName(search, "Search commands");
    setAccessibleName(list, "Available commands");
    gtk_list_box_set_selection_mode(@ptrCast(list), GTK_SELECTION_SINGLE);
    gtk_list_box_set_activate_on_single_click(@ptrCast(list), TRUE);
    gtk_widget_set_size_request(
        scroll,
        @max(1, dialog_width - 16),
        @max(1, dialog_height - 96),
    );
    gtk_container_add(@ptrCast(scroll), list);
    gtk_container_set_border_width(@ptrCast(box), 8);
    gtk_box_pack_start(@ptrCast(box), search, FALSE, FALSE, 0);
    gtk_box_pack_start(@ptrCast(box), scroll, TRUE, TRUE, 0);
    gtk_container_add(@ptrCast(gtk_dialog_get_content_area(@ptrCast(target))), box);

    const vertical = vertical_rows != 0;
    for (actions[0..@intCast(action_count)]) |action| {
        const label_text = action.label orelse continue;
        const hint_text = action.hint orelse continue;
        const row = gtk_list_box_row_new() orelse continue;
        const line = gtk_box_new(
            if (vertical) GTK_ORIENTATION_VERTICAL else GTK_ORIENTATION_HORIZONTAL,
            if (vertical) 2 else 10,
        ) orelse continue;
        const label = gtk_label_new(label_text) orelse continue;
        const dynamic_hint = if (action.id == 14) visibility_hint else null;
        const hint = gtk_label_new(dynamic_hint orelse hint_text) orelse continue;
        gtk_label_set_xalign(@ptrCast(label), 0.0);
        gtk_label_set_xalign(@ptrCast(hint), if (vertical) 0.0 else 1.0);
        gtk_widget_set_opacity(hint, 0.62);
        gtk_container_set_border_width(@ptrCast(line), 5);
        gtk_box_pack_start(@ptrCast(line), label, TRUE, TRUE, 0);
        gtk_box_pack_end(@ptrCast(line), hint, FALSE, FALSE, 0);
        gtk_container_add(@ptrCast(row), line);

        const search_text = g_strdup_printf("%s %s", label_text, hint_text) orelse continue;
        g_object_set_data_full(object(row), "noctty-palette-search", search_text, g_free);
        g_object_set_data(
            object(row),
            "noctty-palette-action",
            @ptrFromInt(@as(usize, @intCast(action.id))),
        );
        if (action.id == 14) {
            g_object_set_data(object(target), "noctty-visibility-shortcut-hint", hint);
        }
        gtk_container_add(@ptrCast(list), row);
    }
    output.* = .{ .search = search, .list = list };
    return TRUE;
}

pub export fn noctty_project_contents_new(
    dialog: ?*GtkWidget,
    summary_text: ?[*:0]const u8,
    contents_out: ?*ProjectContents,
) c_int {
    const target = dialog orelse return FALSE;
    const text = summary_text orelse return FALSE;
    const output = contents_out orelse return FALSE;
    output.* = .{
        .save = null,
        .open = null,
        .recent_combo = null,
        .recent_open = null,
        .editor = null,
        .summary = null,
        .summary_scroll = null,
    };

    const box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 10) orelse return FALSE;
    const save = gtk_button_new_with_label("Save Workspace…") orelse return FALSE;
    const open = gtk_button_new_with_label("Open Workspace…") orelse return FALSE;
    const recent_row = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8) orelse return FALSE;
    const recent_combo = gtk_combo_box_text_new() orelse return FALSE;
    const recent_open = gtk_button_new_with_label("Open Recent") orelse return FALSE;
    const editor = gtk_button_new_with_label("Open NoctEd Here…") orelse return FALSE;
    noctty_configure_action_button(save, "Save the current NOCTTY workspace");
    noctty_configure_action_button(open, "Open a saved NOCTTY workspace");
    noctty_configure_action_button(
        recent_open,
        "Open the selected workspace in a separate native NOCTTY window",
    );
    noctty_configure_action_button(editor, "Open project files in standalone NoctEd");

    const summary = gtk_text_view_new() orelse return FALSE;
    const summary_scroll = gtk_scrolled_window_new(null, null) orelse return FALSE;
    gtk_text_view_set_editable(@ptrCast(summary), FALSE);
    gtk_text_view_set_cursor_visible(@ptrCast(summary), FALSE);
    gtk_text_view_set_monospace(@ptrCast(summary), TRUE);
    gtk_text_view_set_wrap_mode(@ptrCast(summary), 0);
    gtk_text_buffer_set_text(gtk_text_view_get_buffer(@ptrCast(summary)), text, -1);
    gtk_scrolled_window_set_policy(
        @ptrCast(summary_scroll),
        GTK_POLICY_AUTOMATIC,
        GTK_POLICY_AUTOMATIC,
    );
    gtk_scrolled_window_set_shadow_type(@ptrCast(summary_scroll), GTK_SHADOW_IN);
    gtk_widget_set_size_request(summary_scroll, -1, 260);
    gtk_widget_set_hexpand(summary_scroll, TRUE);
    gtk_widget_set_vexpand(summary_scroll, TRUE);
    gtk_container_add(@ptrCast(summary_scroll), summary);
    setAccessibleName(summary, "Workspace summary");
    setAccessibleName(recent_combo, "Recent workspaces");

    gtk_box_pack_start(@ptrCast(recent_row), recent_combo, TRUE, TRUE, 0);
    gtk_box_pack_start(@ptrCast(recent_row), recent_open, FALSE, FALSE, 0);
    gtk_container_set_border_width(@ptrCast(box), 14);
    const intro = gtk_label_new(
        "Native workspace snapshots, project files, and NoctEd",
    ) orelse return FALSE;
    gtk_label_set_xalign(@ptrCast(intro), 0.0);
    gtk_label_set_line_wrap(@ptrCast(intro), TRUE);
    gtk_box_pack_start(@ptrCast(box), intro, FALSE, FALSE, 0);
    gtk_box_pack_start(@ptrCast(box), summary_scroll, TRUE, TRUE, 0);
    gtk_box_pack_start(@ptrCast(box), save, FALSE, FALSE, 0);
    gtk_box_pack_start(@ptrCast(box), open, FALSE, FALSE, 0);
    const recent_label = gtk_label_new("Recent Workspaces") orelse return FALSE;
    gtk_box_pack_start(@ptrCast(box), recent_label, FALSE, FALSE, 0);
    gtk_box_pack_start(@ptrCast(box), recent_row, FALSE, FALSE, 0);
    gtk_box_pack_start(@ptrCast(box), editor, FALSE, FALSE, 0);
    gtk_container_add(@ptrCast(gtk_dialog_get_content_area(@ptrCast(target))), box);
    output.* = .{
        .save = save,
        .open = open,
        .recent_combo = recent_combo,
        .recent_open = recent_open,
        .editor = editor,
        .summary = summary,
        .summary_scroll = summary_scroll,
    };
    return TRUE;
}

pub export fn noctty_restore_workspace_contents_new(
    dialog: ?*GtkWidget,
    combo_out: ?**GtkWidget,
) c_int {
    const target = dialog orelse return FALSE;
    const output = combo_out orelse return FALSE;
    const box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 8) orelse return FALSE;
    const label = gtk_label_new(
        "Choose what should survive restore. Agent resume uses only registered references.",
    ) orelse return FALSE;
    const combo = gtk_combo_box_text_new() orelse return FALSE;
    gtk_label_set_xalign(@ptrCast(label), 0.0);
    for ([_][*:0]const u8{
        "Restart shells (layout and directories)",
        "Attach persistent tmux/Zellij sessions",
        "Resume registered agents",
    }) |text| gtk_combo_box_text_append_text(@ptrCast(combo), text);
    gtk_combo_box_set_active(@ptrCast(combo), 0);
    setAccessibleName(combo, "Workspace restore mode");
    gtk_container_set_border_width(@ptrCast(box), 12);
    gtk_box_pack_start(@ptrCast(box), label, FALSE, FALSE, 0);
    gtk_box_pack_start(@ptrCast(box), combo, FALSE, FALSE, 0);
    gtk_container_add(@ptrCast(gtk_dialog_get_content_area(@ptrCast(target))), box);
    output.* = combo;
    return TRUE;
}

pub export fn noctty_workspace_file_chooser_new(
    parent: ?*GtkWidget,
    save: c_int,
) ?*GtkWidget {
    const target = parent orelse return null;
    const chooser = gtk_file_chooser_dialog_new(
        if (save != 0) "Save NOCTTY Workspace" else "Open NOCTTY Workspace",
        target,
        if (save != 0) GTK_FILE_CHOOSER_ACTION_SAVE else GTK_FILE_CHOOSER_ACTION_OPEN,
        "Cancel",
        GTK_RESPONSE_CANCEL,
        if (save != 0) "Save" else "Open",
        GTK_RESPONSE_ACCEPT,
        @as(?[*:0]const u8, null),
    ) orelse return null;
    if (save != 0) gtk_file_chooser_set_current_name(chooser, "workspace.nocttyws");
    return chooser;
}

fn saveFileChooser(
    parent: *GtkWidget,
    title: [*:0]const u8,
    accept_label: [*:0]const u8,
    default_name: [*:0]const u8,
) ?*GtkWidget {
    const chooser = gtk_file_chooser_dialog_new(
        title,
        parent,
        GTK_FILE_CHOOSER_ACTION_SAVE,
        "Cancel",
        GTK_RESPONSE_CANCEL,
        accept_label,
        GTK_RESPONSE_ACCEPT,
        @as(?[*:0]const u8, null),
    ) orelse return null;
    gtk_file_chooser_set_current_name(chooser, default_name);
    gtk_file_chooser_set_do_overwrite_confirmation(chooser, TRUE);
    return chooser;
}

pub export fn noctty_save_file_chooser_new(
    parent: ?*GtkWidget,
    title: [*:0]const u8,
    accept_label: [*:0]const u8,
    default_name: [*:0]const u8,
) ?*GtkWidget {
    return saveFileChooser(parent orelse return null, title, accept_label, default_name);
}

pub export fn noctty_history_password_contents_new(
    dialog: ?*GtkWidget,
    entry_out: ?**GtkWidget,
) c_int {
    const target = dialog orelse return FALSE;
    const output = entry_out orelse return FALSE;
    const box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 8) orelse return FALSE;
    const label = gtk_label_new(
        "Use at least 8 characters. The password is not stored by NOCTTY.",
    ) orelse return FALSE;
    const entry = gtk_entry_new() orelse return FALSE;
    gtk_label_set_xalign(@ptrCast(label), 0.0);
    gtk_entry_set_visibility(@ptrCast(entry), FALSE);
    gtk_entry_set_max_length(@ptrCast(entry), 4096);
    setAccessibleName(entry, "Screen history password");
    gtk_container_set_border_width(@ptrCast(box), 12);
    gtk_box_pack_start(@ptrCast(box), label, FALSE, FALSE, 0);
    gtk_box_pack_start(@ptrCast(box), entry, FALSE, FALSE, 0);
    gtk_container_add(@ptrCast(gtk_dialog_get_content_area(@ptrCast(target))), box);
    output.* = entry;
    return TRUE;
}

pub export fn noctty_agent_resume_contents_new(
    dialog: ?*GtkWidget,
    provider_out: ?**GtkWidget,
    session_out: ?**GtkWidget,
    label_out: ?**GtkWidget,
) c_int {
    const target = dialog orelse return FALSE;
    const provider_output = provider_out orelse return FALSE;
    const session_output = session_out orelse return FALSE;
    const label_output = label_out orelse return FALSE;
    const box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 8) orelse return FALSE;
    const provider = gtk_combo_box_text_new() orelse return FALSE;
    const session = gtk_entry_new() orelse return FALSE;
    const label = gtk_entry_new() orelse return FALSE;
    for ([_][*:0]const u8{ "Claude Code", "Codex" }) |text|
        gtk_combo_box_text_append_text(@ptrCast(provider), text);
    gtk_combo_box_set_active(@ptrCast(provider), 0);
    gtk_entry_set_placeholder_text(@ptrCast(session), "Opaque session ID");
    gtk_entry_set_placeholder_text(@ptrCast(label), "Optional label");
    gtk_entry_set_max_length(@ptrCast(session), 256);
    gtk_entry_set_max_length(@ptrCast(label), 64);
    setAccessibleName(provider, "Agent provider");
    setAccessibleName(session, "Agent session reference");
    setAccessibleName(label, "Agent display label");
    for ([_]*GtkWidget{
        gtk_label_new("Provider") orelse return FALSE,
        provider,
        gtk_label_new("Session reference") orelse return FALSE,
        session,
        gtk_label_new("Display label") orelse return FALSE,
        label,
    }) |widget| gtk_box_pack_start(@ptrCast(box), widget, FALSE, FALSE, 0);
    gtk_container_set_border_width(@ptrCast(box), 12);
    gtk_container_add(@ptrCast(gtk_dialog_get_content_area(@ptrCast(target))), box);
    provider_output.* = provider;
    session_output.* = session;
    label_output.* = label;
    return TRUE;
}

pub export fn noctty_dialog_new(
    parent: ?*GtkWidget,
    title: [*:0]const u8,
    flags: c_int,
    cancel_label: ?[*:0]const u8,
    cancel_response: c_int,
    accept_label: ?[*:0]const u8,
    accept_response: c_int,
) ?*GtkWidget {
    const target = parent orelse return null;
    const dialog = if (cancel_label != null and accept_label != null)
        gtk_dialog_new_with_buttons(title, target, flags, cancel_label.?, cancel_response, accept_label.?, accept_response, @as(?[*:0]const u8, null))
    else if (cancel_label != null)
        gtk_dialog_new_with_buttons(title, target, flags, cancel_label.?, cancel_response, @as(?[*:0]const u8, null))
    else if (accept_label != null)
        gtk_dialog_new_with_buttons(title, target, flags, accept_label.?, accept_response, @as(?[*:0]const u8, null))
    else
        gtk_dialog_new_with_buttons(title, target, flags, @as(?[*:0]const u8, null));
    return dialog;
}

pub export fn noctty_error_dialog_new(
    parent: ?*GtkWidget,
    title: [*:0]const u8,
    detail: ?[*:0]const u8,
) ?*GtkWidget {
    const target = parent orelse return null;
    const dialog = gtk_message_dialog_new(
        target,
        GTK_DIALOG_MODAL | GTK_DIALOG_DESTROY_WITH_PARENT,
        GTK_MESSAGE_ERROR,
        GTK_BUTTONS_CLOSE,
        "%s",
        title,
    ) orelse return null;
    if (detail) |text| {
        gtk_message_dialog_format_secondary_text(dialog, "%s", text);
    }
    return dialog;
}

pub export fn noctty_message_dialog_new(
    parent: ?*GtkWidget,
    message_type: c_int,
    primary: [*:0]const u8,
    detail: ?[*:0]const u8,
    cancel_label: [*:0]const u8,
    accept_label: [*:0]const u8,
) ?*GtkWidget {
    const target = parent orelse return null;
    const dialog = gtk_message_dialog_new(
        target,
        GTK_DIALOG_MODAL | GTK_DIALOG_DESTROY_WITH_PARENT,
        message_type,
        0,
        "%s",
        primary,
    ) orelse return null;
    if (detail) |text| {
        gtk_message_dialog_format_secondary_text(dialog, "%s", text);
    }
    gtk_dialog_add_buttons(
        dialog,
        cancel_label,
        GTK_RESPONSE_CANCEL,
        accept_label,
        GTK_RESPONSE_ACCEPT,
        @as(?[*:0]const u8, null),
    );
    gtk_dialog_set_default_response(dialog, GTK_RESPONSE_CANCEL);
    return dialog;
}

const SettingsCoreOptions = extern struct {
    shortcut: ?*GtkWidget,
    mode: c_int,
    dropdown_width: c_int,
    dropdown_height: c_int,
    animation_ms: c_int,
    hide_focus: c_int,
    focus_pointer: c_int,
    notifications: c_int,
    preset: c_int,
    scrollback: c_int,
    scroll_lines: c_int,
    smooth_scroll: c_int,
    compact: c_int,
};

const SettingsCoreContents = extern struct {
    window_page: ?*GtkWidget,
    behavior_page: ?*GtkWidget,
    behavior_body: ?*GtkWidget,
    mode: ?*GtkWidget,
    dropdown_width: ?*GtkWidget,
    dropdown_height: ?*GtkWidget,
    animation: ?*GtkWidget,
    hide_focus: ?*GtkWidget,
    focus_pointer: ?*GtkWidget,
    notifications: ?*GtkWidget,
    preset: ?*GtkWidget,
    scrollback: ?*GtkWidget,
    scroll_lines: ?*GtkWidget,
    smooth_scroll: ?*GtkWidget,
};

const SettingsShellContents = extern struct {
    categories: ?*GtkWidget,
    stack: ?*GtkWidget,
};

pub export fn noctty_settings_shell_new(
    dialog: ?*GtkWidget,
    compact: c_int,
    window_page: ?*GtkWidget,
    behavior_page: ?*GtkWidget,
    appearance_page: ?*GtkWidget,
    contents_out: *SettingsShellContents,
) c_int {
    const target = dialog orelse return FALSE;
    const window = window_page orelse return FALSE;
    const behavior = behavior_page orelse return FALSE;
    const appearance = appearance_page orelse return FALSE;
    const layout = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0) orelse return FALSE;
    gtk_widget_set_hexpand(layout, TRUE);
    gtk_widget_set_vexpand(layout, TRUE);

    const categories = gtk_list_box_new() orelse return FALSE;
    gtk_list_box_set_selection_mode(@ptrCast(categories), GTK_SELECTION_BROWSE);
    gtk_widget_set_size_request(
        categories,
        if (compact != 0) 136 else 184,
        -1,
    );
    gtk_widget_set_hexpand(categories, FALSE);
    gtk_widget_set_vexpand(categories, TRUE);
    gtk_style_context_add_class(
        gtk_widget_get_style_context(categories),
        "sidebar",
    );
    gtk_container_set_border_width(@ptrCast(categories), 4);
    const category_rows = [_][3][*:0]const u8{
        .{ "preferences-system-windows", "Window", "window" },
        .{ "preferences-system-windows-actions", "Behavior", "behavior" },
        .{ "preferences-desktop-theme", "Appearance", "appearance" },
    };
    for (category_rows) |row_data| {
        const row = noctty_settings_category_row_new(
            row_data[0],
            row_data[1],
            row_data[2],
        ) orelse return FALSE;
        gtk_container_add(@ptrCast(categories), row);
    }

    const stack = gtk_stack_new() orelse return FALSE;
    gtk_stack_set_transition_type(
        @ptrCast(stack),
        GTK_STACK_TRANSITION_TYPE_CROSSFADE,
    );
    gtk_stack_set_transition_duration(@ptrCast(stack), 120);
    gtk_widget_set_hexpand(stack, TRUE);
    gtk_widget_set_vexpand(stack, TRUE);
    gtk_stack_add_named(@ptrCast(stack), window, "window");
    gtk_stack_add_named(@ptrCast(stack), behavior, "behavior");
    gtk_stack_add_named(@ptrCast(stack), appearance, "appearance");

    const separator = gtk_separator_new(GTK_ORIENTATION_VERTICAL) orelse return FALSE;
    const content = gtk_dialog_get_content_area(@ptrCast(target));
    gtk_box_set_spacing(@ptrCast(content), 0);
    gtk_container_set_border_width(@ptrCast(content), 0);
    gtk_container_add(@ptrCast(content), layout);
    gtk_box_pack_start(@ptrCast(layout), categories, FALSE, TRUE, 0);
    gtk_box_pack_start(@ptrCast(layout), separator, FALSE, TRUE, 0);
    gtk_box_pack_start(@ptrCast(layout), stack, TRUE, TRUE, 0);
    contents_out.* = .{
        .categories = categories,
        .stack = stack,
    };
    return TRUE;
}

fn comboText(labels: []const [*:0]const u8, active: c_int) ?*GtkWidget {
    const combo = gtk_combo_box_text_new() orelse return null;
    for (labels) |label| gtk_combo_box_text_append_text(@ptrCast(combo), label);
    gtk_combo_box_set_active(@ptrCast(combo), active);
    return combo;
}

fn spinButton(minimum: f64, maximum: f64, step: f64, value: f64) ?*GtkWidget {
    const spin = gtk_spin_button_new_with_range(minimum, maximum, step) orelse return null;
    gtk_spin_button_set_value(@ptrCast(spin), value);
    return spin;
}

fn packSettingsGroup(body: *GtkWidget, title: [*:0]const u8, child: *GtkWidget) bool {
    const group = noctty_settings_group_new(title, child) orelse return false;
    gtk_box_pack_start(@ptrCast(body), group, FALSE, FALSE, 0);
    return true;
}

pub export fn noctty_settings_core_contents_new(
    options_raw: ?*const SettingsCoreOptions,
    contents_out: ?*SettingsCoreContents,
) c_int {
    const options = options_raw orelse return FALSE;
    const shortcut = options.shortcut orelse return FALSE;
    const output = contents_out orelse return FALSE;
    output.* = std.mem.zeroes(SettingsCoreContents);

    const mode = comboText(&.{ "Dropdown", "Windowed", "Zen fullscreen" }, options.mode) orelse
        return FALSE;
    var window_page_body: *GtkWidget = undefined;
    const window_page = noctty_settings_page_new(
        "Window",
        "Choose how NOCTTY opens and size the drop-down terminal in real time.",
        &window_page_body,
    ) orelse return FALSE;
    if (options.compact != 0) gtk_container_set_border_width(@ptrCast(window_page_body), 12);
    const window_grid = noctty_settings_grid_new() orelse return FALSE;
    noctty_settings_grid_attach_control(window_grid, "Presentation mode", mode, 0);
    noctty_settings_grid_attach_control(window_grid, "Open / retract shortcut", shortcut, 1);
    if (!packSettingsGroup(window_page_body, "Window", window_grid)) return FALSE;

    const dropdown_width = spinButton(1, 100, 1, @floatFromInt(options.dropdown_width)) orelse
        return FALSE;
    const dropdown_height = spinButton(1, 100, 1, @floatFromInt(options.dropdown_height)) orelse
        return FALSE;
    const animation = spinButton(0, 2000, 10, @floatFromInt(options.animation_ms)) orelse
        return FALSE;
    const dropdown_grid = noctty_settings_grid_new() orelse return FALSE;
    noctty_settings_grid_attach_control(dropdown_grid, "Width (%)", dropdown_width, 0);
    noctty_settings_grid_attach_control(dropdown_grid, "Height (%)", dropdown_height, 1);
    noctty_settings_grid_attach_control(dropdown_grid, "Reveal animation (ms)", animation, 2);
    if (!packSettingsGroup(window_page_body, "Drop-down geometry", dropdown_grid)) return FALSE;

    const hide_focus = gtk_check_button_new_with_label("Hide dropdown when focus leaves") orelse
        return FALSE;
    const focus_pointer = gtk_check_button_new_with_label("Focus pane on pointer hover") orelse
        return FALSE;
    const notifications = gtk_check_button_new_with_label("Desktop notifications") orelse
        return FALSE;
    gtk_toggle_button_set_active(@ptrCast(hide_focus), options.hide_focus);
    gtk_toggle_button_set_active(@ptrCast(focus_pointer), options.focus_pointer);
    gtk_toggle_button_set_active(@ptrCast(notifications), options.notifications);
    const preset = comboText(
        &.{ "Global default", "Compact", "Readable", "High contrast", "Mono no ligatures" },
        options.preset,
    ) orelse return FALSE;
    var body: *GtkWidget = undefined;
    const behavior_page = noctty_settings_page_new(
        "Behavior",
        "Control focus, session defaults, and unobtrusive desktop feedback.",
        &body,
    ) orelse return FALSE;
    if (options.compact != 0) gtk_container_set_border_width(@ptrCast(body), 12);
    const focus_box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 8) orelse return FALSE;
    gtk_box_pack_start(@ptrCast(focus_box), hide_focus, FALSE, FALSE, 0);
    gtk_box_pack_start(@ptrCast(focus_box), focus_pointer, FALSE, FALSE, 0);
    if (!packSettingsGroup(body, "Focus", focus_box)) return FALSE;

    const scrollback = spinButton(100, 100000, 100, @floatFromInt(options.scrollback)) orelse
        return FALSE;
    const scroll_lines = spinButton(1, 20, 1, @floatFromInt(options.scroll_lines)) orelse
        return FALSE;
    const smooth_scroll = gtk_check_button_new_with_label("Enable") orelse return FALSE;
    gtk_widget_set_tooltip_text(
        smooth_scroll,
        "Use smooth touchpad and high-resolution wheel scrolling.",
    );
    gtk_toggle_button_set_active(@ptrCast(smooth_scroll), options.smooth_scroll);
    const session_grid = noctty_settings_grid_new() orelse return FALSE;
    noctty_settings_grid_attach_control(session_grid, "Active pane profile", preset, 0);
    noctty_settings_grid_attach_control(session_grid, "Scrollback lines", scrollback, 1);
    noctty_settings_grid_attach_control(session_grid, "Lines per wheel step", scroll_lines, 2);
    noctty_settings_grid_attach_control(session_grid, "Smooth scrolling", smooth_scroll, 3);
    if (!packSettingsGroup(body, "Sessions", session_grid)) return FALSE;

    output.* = .{
        .window_page = window_page,
        .behavior_page = behavior_page,
        .behavior_body = body,
        .mode = mode,
        .dropdown_width = dropdown_width,
        .dropdown_height = dropdown_height,
        .animation = animation,
        .hide_focus = hide_focus,
        .focus_pointer = focus_pointer,
        .notifications = notifications,
        .preset = preset,
        .scrollback = scrollback,
        .scroll_lines = scroll_lines,
        .smooth_scroll = smooth_scroll,
    };
    return TRUE;
}

const SettingsAppearanceOptions = extern struct {
    theme: ?*GtkWidget,
    background_tint: ?*GtkWidget,
    color_buttons: ?[*]const ?*GtkWidget,
    color_count: c_uint,
    tab_position: c_int,
    panel_padding: c_int,
    pane_spacing: c_int,
    pane_gaps_enabled: c_int,
    pane_gaps_transparent: c_int,
    inactive_pane_dim_enabled: c_int,
    inactive_pane_brightness_percent: c_int,
    pane_divider: c_int,
    pane_border: c_int,
    focused_border: c_int,
    selected_border: c_int,
    status_border: c_int,
    overlay_border: c_int,
    window_border: c_int,
    dragger: c_int,
    show_pane_info: c_int,
    family: c_int,
    font_min: f64,
    font_max: f64,
    font_size: f64,
    antialias: c_int,
    hinting: c_int,
    translucency: c_int,
    alpha_supported: c_int,
    opacity_percent: f64,
    compact: c_int,
};

const SettingsAppearanceContents = extern struct {
    page: ?*GtkWidget,
    tabs: ?*GtkWidget,
    status: ?*GtkWidget,
    padding: ?*GtkWidget,
    spacing: ?*GtkWidget,
    pane_gaps_enabled: ?*GtkWidget,
    pane_gaps_transparent: ?*GtkWidget,
    inactive_pane_dim_enabled: ?*GtkWidget,
    inactive_pane_brightness: ?*GtkWidget,
    theme_scope_tab: ?*GtkWidget,
    divider: ?*GtkWidget,
    pane_border: ?*GtkWidget,
    focused_border: ?*GtkWidget,
    selected_border: ?*GtkWidget,
    status_border: ?*GtkWidget,
    overlay_border: ?*GtkWidget,
    window_border: ?*GtkWidget,
    dragger: ?*GtkWidget,
    pane_info: ?*GtkWidget,
    theme_library: ?*GtkWidget,
    family: ?*GtkWidget,
    font: ?*GtkWidget,
    antialias: ?*GtkWidget,
    hinting: ?*GtkWidget,
    translucency: ?*GtkWidget,
    opacity: ?*GtkWidget,
    transparency_status: ?*GtkWidget,
};

fn panelMetricSpin(event_code: c_int, minimum: f64, maximum: f64, value: c_int) ?*GtkWidget {
    const spin = spinButton(minimum, maximum, 1, @floatFromInt(value)) orelse return null;
    g_object_set_data(
        object(spin),
        "noctty-panel-metric-event",
        @ptrFromInt(@as(usize, @intCast(event_code))),
    );
    return spin;
}

fn attachControls(grid: *GtkWidget, controls: []const struct { [*:0]const u8, *GtkWidget }) void {
    for (controls, 0..) |control, row| {
        noctty_settings_grid_attach_control(grid, control[0], control[1], @intCast(row));
    }
}

pub export fn noctty_settings_appearance_contents_new(
    options_raw: ?*const SettingsAppearanceOptions,
    contents_out: ?*SettingsAppearanceContents,
) c_int {
    const options = options_raw orelse return FALSE;
    const theme = options.theme orelse return FALSE;
    const tint = options.background_tint orelse return FALSE;
    const colors = options.color_buttons orelse return FALSE;
    const output = contents_out orelse return FALSE;
    output.* = std.mem.zeroes(SettingsAppearanceContents);
    if (options.color_count != 17) return FALSE;

    const tabs = comboText(&.{ "Top", "Bottom", "Left", "Right" }, options.tab_position) orelse return FALSE;
    const status = comboText(&.{ "Background", "Border" }, 1) orelse return FALSE;
    const padding = panelMetricSpin(46, 0, 64, options.panel_padding) orelse return FALSE;
    const spacing = panelMetricSpin(47, 0, 64, options.pane_spacing) orelse return FALSE;
    const pane_gaps_enabled = gtk_check_button_new_with_label(
        "Show pixel gaps between panes",
    ) orelse return FALSE;
    gtk_toggle_button_set_active(
        @ptrCast(pane_gaps_enabled),
        options.pane_gaps_enabled,
    );
    g_object_set_data(
        object(pane_gaps_enabled),
        "noctty-panel-metric-event",
        @ptrFromInt(127),
    );
    const pane_gaps_transparent = gtk_check_button_new_with_label(
        "Keep pane gaps transparent",
    ) orelse return FALSE;
    gtk_toggle_button_set_active(
        @ptrCast(pane_gaps_transparent),
        options.pane_gaps_transparent,
    );
    gtk_widget_set_sensitive(
        pane_gaps_transparent,
        options.pane_gaps_enabled,
    );
    g_object_set_data(
        object(pane_gaps_transparent),
        "noctty-panel-metric-event",
        @ptrFromInt(128),
    );
    const inactive_pane_dim_enabled = gtk_check_button_new_with_label(
        "Dim inactive panes",
    ) orelse return FALSE;
    gtk_toggle_button_set_active(
        @ptrCast(inactive_pane_dim_enabled),
        options.inactive_pane_dim_enabled,
    );
    g_object_set_data(
        object(inactive_pane_dim_enabled),
        "noctty-panel-metric-event",
        @ptrFromInt(129),
    );
    const inactive_pane_brightness = gtk_scale_new_with_range(
        GTK_ORIENTATION_HORIZONTAL,
        20,
        100,
        1,
    ) orelse return FALSE;
    gtk_range_set_value(
        @ptrCast(inactive_pane_brightness),
        @floatFromInt(options.inactive_pane_brightness_percent),
    );
    gtk_scale_set_draw_value(@ptrCast(inactive_pane_brightness), TRUE);
    gtk_scale_set_value_pos(@ptrCast(inactive_pane_brightness), GTK_POS_RIGHT);
    gtk_widget_set_sensitive(
        inactive_pane_brightness,
        options.inactive_pane_dim_enabled,
    );
    setAccessibleName(inactive_pane_brightness, "Inactive pane brightness percent");
    gtk_widget_set_sensitive(spacing, options.pane_gaps_enabled);
    g_object_set_data(object(pane_gaps_enabled), "noctty-gap-width", spacing);
    g_object_set_data(
        object(pane_gaps_enabled),
        "noctty-gap-transparent",
        pane_gaps_transparent,
    );
    g_object_set_data(
        object(inactive_pane_dim_enabled),
        "noctty-inactive-brightness",
        inactive_pane_brightness,
    );
    const divider = panelMetricSpin(119, 1, 16, options.pane_divider) orelse return FALSE;
    const pane_border = panelMetricSpin(120, 0, 12, options.pane_border) orelse return FALSE;
    const focused_border = panelMetricSpin(121, 1, 12, options.focused_border) orelse return FALSE;
    const selected_border = panelMetricSpin(122, 1, 12, options.selected_border) orelse return FALSE;
    const status_border = panelMetricSpin(123, 1, 12, options.status_border) orelse return FALSE;
    const overlay_border = panelMetricSpin(124, 1, 12, options.overlay_border) orelse return FALSE;
    const window_border = panelMetricSpin(125, 1, 16, options.window_border) orelse return FALSE;
    const dragger = panelMetricSpin(126, 1, 32, options.dragger) orelse return FALSE;
    const pane_info = gtk_check_button_new_with_label("Show bottom pane and resource bar") orelse return FALSE;
    gtk_toggle_button_set_active(@ptrCast(pane_info), options.show_pane_info);
    const theme_scope_tab = gtk_check_button_new_with_label(
        "Apply theme to the current tab only",
    ) orelse return FALSE;
    gtk_toggle_button_set_active(@ptrCast(theme_scope_tab), TRUE);
    const theme_library = gtk_button_new_with_label("Browse installed themes…") orelse return FALSE;
    noctty_configure_action_button(theme_library, "Open Theme Library and choose an installed Noctalia scheme");
    const family = comboText(&.{ "Monospace", "JetBrains Mono" }, options.family) orelse return FALSE;
    const font = spinButton(options.font_min, options.font_max, 1, options.font_size) orelse return FALSE;
    const antialias = comboText(&.{ "System default", "Grayscale", "Subpixel (smoothest)" }, options.antialias) orelse return FALSE;
    const hinting = comboText(&.{ "None", "Slight", "Full" }, options.hinting) orelse return FALSE;

    var body: *GtkWidget = undefined;
    const page = noctty_settings_page_new(
        "Appearance",
        "Keep terminal text readable while tuning the small amount of client chrome.",
        &body,
    ) orelse return FALSE;
    if (options.compact != 0) gtk_container_set_border_width(@ptrCast(body), 12);
    const terminal_grid = noctty_settings_grid_new() orelse return FALSE;
    attachControls(terminal_grid, &.{
        .{ "Theme", theme },                 .{ "Theme scope", theme_scope_tab },
        .{ "Theme library", theme_library }, .{ "Font family", family },
        .{ "Font size", font },              .{ "Font smoothing", antialias },
        .{ "Font hinting", hinting },
    });
    if (!packSettingsGroup(body, "Terminal", terminal_grid)) return FALSE;
    const chrome_grid = noctty_settings_grid_new() orelse return FALSE;
    attachControls(chrome_grid, &.{
        .{ "Tab position", tabs },     .{ "Status indicator", status },
        .{ "Panel padding", padding }, .{ "Pane information", pane_info },
    });
    if (!packSettingsGroup(body, "Client chrome", chrome_grid)) return FALSE;
    const pane_grid = noctty_settings_grid_new() orelse return FALSE;
    attachControls(pane_grid, &.{
        .{ "Pane gaps", pane_gaps_enabled },
        .{ "Gap width", spacing },
        .{ "Gap surface", pane_gaps_transparent },
        .{ "Inactive panes", inactive_pane_dim_enabled },
        .{ "Inactive brightness", inactive_pane_brightness },
    });
    if (!packSettingsGroup(body, "Pane focus and spacing", pane_grid)) return FALSE;
    const thickness_grid = noctty_settings_grid_new() orelse return FALSE;
    attachControls(thickness_grid, &.{
        .{ "Focused pane border", focused_border },
        .{ "Selected pane border", selected_border },
        .{ "Unselected pane border", pane_border },
        .{ "Status outline", status_border },
        .{ "Overlay outline", overlay_border },
        .{ "Split dragger", divider },
        .{ "Window resize border", window_border },
        .{ "Bottom dragger", dragger },
    });
    if (!packSettingsGroup(body, "Border and drag thickness", thickness_grid)) return FALSE;

    const translucency = gtk_check_button_new_with_label("Show the desktop through terminal backgrounds") orelse return FALSE;
    gtk_toggle_button_set_active(@ptrCast(translucency), options.translucency);
    const opacity = gtk_scale_new_with_range(GTK_ORIENTATION_HORIZONTAL, 10, 100, 1) orelse return FALSE;
    gtk_range_set_value(@ptrCast(opacity), options.opacity_percent);
    gtk_scale_set_draw_value(@ptrCast(opacity), TRUE);
    gtk_scale_set_value_pos(@ptrCast(opacity), GTK_POS_RIGHT);
    gtk_widget_set_sensitive(opacity, @intFromBool(options.translucency != 0 and options.alpha_supported != 0));
    setAccessibleName(opacity, "Terminal background opacity percent");
    const transparency_status = gtk_label_new(if (options.alpha_supported != 0)
        "Available through the current compositor"
    else
        "Unavailable; NOCTTY is using an opaque background") orelse return FALSE;
    gtk_label_set_xalign(@ptrCast(transparency_status), 0.0);
    gtk_label_set_line_wrap(@ptrCast(transparency_status), TRUE);
    g_object_set_data(object(translucency), "noctty-background-opacity", opacity);
    const background_grid = noctty_settings_grid_new() orelse return FALSE;
    attachControls(background_grid, &.{
        .{ "Translucency", translucency }, .{ "Opacity", opacity },
        .{ "Tint", tint },                 .{ "Compositor support", transparency_status },
    });
    if (!packSettingsGroup(body, "Background", background_grid)) return FALSE;

    const color_labels = [_][*:0]const u8{
        "Focused pane border", "Selected pane border", "Unselected pane border",
        "Scrollbar track",     "Scrollbar thumb",      "Scrollbar hover / drag",
        "Overlay background",  "Overlay border",       "Overlay text",
        "Text selection",      "Search match",         "Info status",
        "Success status",      "Warning status",       "Error status",
        "Terminal caret",      "Pane gap",
    };
    const color_grid = noctty_settings_grid_new() orelse return FALSE;
    for (color_labels, 0..) |label, index| {
        const button = colors[index] orelse return FALSE;
        noctty_settings_grid_attach_control(color_grid, label, button, @intCast(index));
    }
    if (!packSettingsGroup(body, "Workspace colors", color_grid)) return FALSE;
    output.* = .{
        .page = page,
        .tabs = tabs,
        .status = status,
        .padding = padding,
        .spacing = spacing,
        .pane_gaps_enabled = pane_gaps_enabled,
        .pane_gaps_transparent = pane_gaps_transparent,
        .inactive_pane_dim_enabled = inactive_pane_dim_enabled,
        .inactive_pane_brightness = inactive_pane_brightness,
        .theme_scope_tab = theme_scope_tab,
        .divider = divider,
        .pane_border = pane_border,
        .focused_border = focused_border,
        .selected_border = selected_border,
        .status_border = status_border,
        .overlay_border = overlay_border,
        .window_border = window_border,
        .dragger = dragger,
        .pane_info = pane_info,
        .theme_library = theme_library,
        .family = family,
        .font = font,
        .antialias = antialias,
        .hinting = hinting,
        .translucency = translucency,
        .opacity = opacity,
        .transparency_status = transparency_status,
    };
    return TRUE;
}

const LaunchProfileOptions = extern struct {
    shell: ?[*:0]const u8,
    command: ?[*:0]const u8,
    cwd: ?[*:0]const u8,
    environment: ?[*:0]const u8,
    ssh_target: ?[*:0]const u8,
    kind: c_int,
    scrollback: c_int,
};

const LaunchProfileContents = extern struct {
    library: ?*GtkWidget,
    name: ?*GtkWidget,
    kind: ?*GtkWidget,
    shell: ?*GtkWidget,
    command: ?*GtkWidget,
    cwd: ?*GtkWidget,
    environment: ?*GtkWidget,
    ssh_target: ?*GtkWidget,
    scrollback: ?*GtkWidget,
    apply: ?*GtkWidget,
    save: ?*GtkWidget,
    delete: ?*GtkWidget,
    status: ?*GtkWidget,
};

fn textEntry(text: [*:0]const u8, placeholder: [*:0]const u8) ?*GtkWidget {
    const entry = gtk_entry_new() orelse return null;
    gtk_entry_set_text(@ptrCast(entry), text);
    gtk_entry_set_placeholder_text(@ptrCast(entry), placeholder);
    return entry;
}

pub export fn noctty_launch_profile_contents_new(
    parent_body: ?*GtkWidget,
    options_raw: ?*const LaunchProfileOptions,
    contents_out: ?*LaunchProfileContents,
) c_int {
    const body = parent_body orelse return FALSE;
    const options = options_raw orelse return FALSE;
    const output = contents_out orelse return FALSE;
    output.* = std.mem.zeroes(LaunchProfileContents);

    const library = gtk_combo_box_text_new() orelse return FALSE;
    gtk_combo_box_text_append_text(@ptrCast(library), "Custom current");
    gtk_combo_box_set_active(@ptrCast(library), 0);
    const name = gtk_entry_new() orelse return FALSE;
    gtk_entry_set_max_length(@ptrCast(name), 64);
    gtk_entry_set_placeholder_text(@ptrCast(name), "Name this launch profile");
    const kind = gtk_combo_box_text_new() orelse return FALSE;
    for ([_][*:0]const u8{
        "Shell",
        "Command",
        "SSH",
        "Persistent tmux",
        "Persistent Zellij",
    }) |label| gtk_combo_box_text_append_text(@ptrCast(kind), label);
    gtk_combo_box_set_active(@ptrCast(kind), @max(0, @min(4, options.kind)));

    const shell = textEntry(
        options.shell orelse "",
        "Use $SHELL when blank",
    ) orelse return FALSE;
    const command = textEntry(
        options.command orelse "",
        "One command line for new sessions",
    ) orelse return FALSE;
    const cwd = textEntry(
        options.cwd orelse "",
        "Inherit pane directory when blank",
    ) orelse return FALSE;
    const environment = textEntry(
        options.environment orelse "",
        "NAME=value;SECOND=value",
    ) orelse return FALSE;
    const ssh_target = textEntry(
        options.ssh_target orelse "",
        "user@example.com or session-name",
    ) orelse return FALSE;
    const scrollback = gtk_spin_button_new_with_range(100, 100000, 100) orelse return FALSE;
    gtk_spin_button_set_value(@ptrCast(scrollback), @floatFromInt(options.scrollback));

    const apply = gtk_button_new_with_label("Apply to new sessions") orelse return FALSE;
    noctty_configure_action_button(
        apply,
        "Validate and save this profile; running sessions are unchanged.",
    );
    const save = gtk_button_new_with_label("Save named profile") orelse return FALSE;
    noctty_configure_action_button(
        save,
        "Add or replace a named profile and select it for new sessions.",
    );
    const delete = gtk_button_new_with_label("Delete selected profile") orelse return FALSE;
    noctty_configure_action_button(
        delete,
        "Remove the selected name; the current launch values stay active.",
    );
    gtk_widget_set_sensitive(delete, FALSE);
    const status = gtk_label_new("") orelse return FALSE;
    gtk_label_set_xalign(@ptrCast(status), 0.0);
    gtk_label_set_line_wrap(@ptrCast(status), TRUE);
    gtk_widget_set_no_show_all(status, TRUE);
    gtk_widget_set_visible(status, FALSE);
    setAccessibleName(status, "Launch profile save status");

    const grid = noctty_settings_grid_new() orelse return FALSE;
    const controls = [_]struct { [*:0]const u8, *GtkWidget }{
        .{ "Saved profile", library },
        .{ "Profile name", name },
        .{ "Launch type", kind },
        .{ "Shell", shell },
        .{ "Command", command },
        .{ "Working directory", cwd },
        .{ "Environment overrides", environment },
        .{ "SSH / session target", ssh_target },
        .{ "New-session scrollback", scrollback },
    };
    for (controls, 0..) |control, row| {
        noctty_settings_grid_attach_control(grid, control[0], control[1], @intCast(row));
    }
    const buttons = gtk_box_new(GTK_ORIENTATION_VERTICAL, 6) orelse return FALSE;
    gtk_widget_set_halign(buttons, GTK_ALIGN_FILL);
    gtk_box_pack_start(@ptrCast(buttons), apply, FALSE, FALSE, 0);
    gtk_box_pack_start(@ptrCast(buttons), save, FALSE, FALSE, 0);
    gtk_box_pack_start(@ptrCast(buttons), delete, FALSE, FALSE, 0);
    gtk_grid_attach(@ptrCast(grid), buttons, 1, 9, 1, 1);
    gtk_grid_attach(@ptrCast(grid), status, 1, 10, 1, 1);
    const group = noctty_settings_group_new("Launch profiles", grid) orelse return FALSE;
    gtk_box_pack_start(@ptrCast(body), group, FALSE, FALSE, 0);

    output.* = .{
        .library = library,
        .name = name,
        .kind = kind,
        .shell = shell,
        .command = command,
        .cwd = cwd,
        .environment = environment,
        .ssh_target = ssh_target,
        .scrollback = scrollback,
        .apply = apply,
        .save = save,
        .delete = delete,
        .status = status,
    };
    return TRUE;
}

pub export fn noctty_theme_import_dialog_new(
    parent: ?*GtkWidget,
    variant_out: ?**GtkWidget,
) ?*GtkWidget {
    const target = parent orelse return null;
    const output = variant_out orelse return null;
    const chooser = gtk_file_chooser_dialog_new(
        "Import Terminal Theme",
        target,
        GTK_FILE_CHOOSER_ACTION_OPEN,
        "Cancel",
        GTK_RESPONSE_CANCEL,
        "Import",
        GTK_RESPONSE_ACCEPT,
        @as(?[*:0]const u8, null),
    ) orelse return null;
    const variant = comboText(
        &.{
            "Noctalia: auto / active colors",
            "Noctalia: dark variant",
            "Noctalia: light variant",
        },
        0,
    ) orelse {
        gtk_widget_destroy(chooser);
        return null;
    };
    gtk_widget_set_tooltip_text(
        variant,
        "Used for Noctalia colors.json and colorscheme JSON files",
    );
    setAccessibleName(variant, "Noctalia import variant");
    gtk_file_chooser_set_extra_widget(chooser, variant);
    output.* = variant;
    return chooser;
}

const ThemeLibraryContents = extern struct {
    variant: ?*GtkWidget,
    scope_tab: ?*GtkWidget,
    apply: ?*GtkWidget,
    status: ?*GtkWidget,
    import_current: ?*GtkWidget,
    import_file: ?*GtkWidget,
};

pub export fn noctty_theme_library_contents_new(
    dialog: ?*GtkWidget,
    themes: ?*GtkWidget,
    scheme: ?*GtkWidget,
    scheme_count: c_uint,
    contents_out: ?*ThemeLibraryContents,
) c_int {
    const target = dialog orelse return FALSE;
    const theme_combo = themes orelse return FALSE;
    const scheme_combo = scheme orelse return FALSE;
    const output = contents_out orelse return FALSE;
    output.* = std.mem.zeroes(ThemeLibraryContents);
    const box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 10) orelse return FALSE;
    const preview = gtk_label_new(
        "Preview: foreground · background · cursor · ANSI palette",
    ) orelse return FALSE;
    const scope_tab = gtk_check_button_new_with_label(
        "Apply theme to the current tab only",
    ) orelse return FALSE;
    gtk_toggle_button_set_active(@ptrCast(scope_tab), FALSE);
    g_object_set_data(object(theme_combo), "noctty-theme-scope-tab", scope_tab);
    const scheme_label = gtk_label_new("Installed Noctalia scheme") orelse return FALSE;
    gtk_label_set_xalign(@ptrCast(scheme_label), 0.0);
    const variant = comboText(&.{ "Dark", "Light" }, 0) orelse return FALSE;
    const apply = gtk_button_new_with_label("Use selected Noctalia theme") orelse return FALSE;
    noctty_configure_action_button(
        apply,
        "Import and select the chosen installed Noctalia colorscheme",
    );
    const status = gtk_label_new(if (scheme_count > 0)
        "Choose a scheme and Dark or Light variant."
    else
        "No Noctalia colorschemes were found.") orelse return FALSE;
    gtk_label_set_xalign(@ptrCast(status), 0.0);
    gtk_label_set_line_wrap(@ptrCast(status), TRUE);
    setAccessibleName(scheme_combo, "Installed Noctalia scheme");
    setAccessibleName(variant, "Noctalia theme variant");
    setAccessibleName(status, "Noctalia theme status");
    const available: c_int = @intFromBool(scheme_count > 0);
    gtk_widget_set_sensitive(scheme_combo, available);
    gtk_widget_set_sensitive(variant, available);
    gtk_widget_set_sensitive(apply, available);
    const import_current = gtk_button_new_with_label("Use current Noctalia colors") orelse return FALSE;
    noctty_configure_action_button(
        import_current,
        "Import ~/.config/noctalia/colors.json as terminal and workspace colors",
    );
    const import_file = gtk_button_new_with_label(
        "Import Ghostty / Xresources / Alacritty / Noctalia theme…",
    ) orelse return FALSE;
    noctty_configure_action_button(
        import_file,
        "Import terminal and workspace colors, including Noctalia JSON schemes",
    );
    gtk_container_set_border_width(@ptrCast(box), 14);
    for ([_]*GtkWidget{
        preview,
        theme_combo,
        scope_tab,
        scheme_label,
        scheme_combo,
        variant,
        apply,
        status,
        import_current,
        import_file,
    }) |widget| gtk_box_pack_start(@ptrCast(box), widget, FALSE, FALSE, 0);
    gtk_container_add(@ptrCast(gtk_dialog_get_content_area(@ptrCast(target))), box);
    setSharingData(target, "noctty-system-noctalia-scheme", scheme_combo);
    setSharingData(target, "noctty-system-noctalia-apply", apply);
    setSharingData(target, "noctty-theme-selector", theme_combo);
    setSharingData(target, "noctty-theme-status", status);
    output.* = .{
        .variant = variant,
        .scope_tab = scope_tab,
        .apply = apply,
        .status = status,
        .import_current = import_current,
        .import_file = import_file,
    };
    return TRUE;
}

const NoctaliaSchemeRecord = struct {
    label: []const u8,
    path: []const u8,
};

pub export fn noctty_theme_library_append_noctalia_records(
    scheme: ?*GtkWidget,
    records: ?[*]const u8,
    length: usize,
) c_uint {
    const combo = scheme orelse return 0;
    const bytes = records orelse return 0;
    var parsed: [128]NoctaliaSchemeRecord = undefined;
    var count: usize = 0;
    var cursor = bytes[0..length];
    while (cursor.len > 0 and count < parsed.len) {
        const line_length = std.mem.indexOfScalar(u8, cursor, '\n') orelse cursor.len;
        const line = cursor[0..line_length];
        if (std.mem.indexOfScalar(u8, line, '\t')) |tab| {
            if (tab > 0 and tab + 1 < line.len) {
                parsed[count] = .{
                    .label = line[0..tab],
                    .path = line[tab + 1 ..],
                };
                count += 1;
            }
        }
        cursor = if (line_length < cursor.len)
            cursor[line_length + 1 ..]
        else
            cursor[cursor.len..];
    }
    std.mem.sort(NoctaliaSchemeRecord, parsed[0..count], {}, struct {
        fn lessThan(_: void, left: NoctaliaSchemeRecord, right: NoctaliaSchemeRecord) bool {
            return std.mem.lessThan(u8, left.label, right.label);
        }
    }.lessThan);
    var appended: usize = 0;
    for (parsed[0..count]) |record| {
        var label_buffer: [std.fs.max_path_bytes + 1]u8 = undefined;
        var path_buffer: [std.fs.max_path_bytes + 1]u8 = undefined;
        if (record.label.len > std.fs.max_path_bytes or
            record.path.len > std.fs.max_path_bytes)
            continue;
        @memcpy(label_buffer[0..record.label.len], record.label);
        @memcpy(path_buffer[0..record.path.len], record.path);
        label_buffer[record.label.len] = 0;
        path_buffer[record.path.len] = 0;
        gtk_combo_box_text_append(
            @ptrCast(combo),
            @ptrCast(&path_buffer),
            @ptrCast(&label_buffer),
        );
        appended += 1;
    }
    if (appended > 0) gtk_combo_box_set_active(@ptrCast(combo), 0);
    return @intCast(appended);
}

const SharingCallbacks = extern struct {
    action: ?GCallback,
    tab_changed: ?GCallback,
    stream_changed: ?GCallback,
    preview_draw: ?GCallback,
    preview_button: ?GCallback,
    preview_key: ?GCallback,
    preview_scroll: ?GCallback,
};

const SharingAction = struct {
    label: [*:0]const u8,
    action: c_int,
};

fn sharingActionButton(
    action: SharingAction,
    context: *anyopaque,
    callback: ?GCallback,
) ?*GtkWidget {
    const button = gtk_button_new_with_label(action.label) orelse return null;
    g_object_set_data(
        object(button),
        "noctty-sharing-action",
        @ptrFromInt(@as(usize, @intCast(action.action))),
    );
    connectSignal(button, "clicked", callback, context);
    return button;
}

fn sharingFieldLabel(text: [*:0]const u8, control: *GtkWidget) ?*GtkWidget {
    const label = gtk_label_new(text) orelse return null;
    gtk_label_set_xalign(@ptrCast(label), 0.0);
    gtk_label_set_mnemonic_widget(@ptrCast(label), control);
    return label;
}

fn sharingActionGroup(
    title: [*:0]const u8,
    buttons: []const *GtkWidget,
) ?*GtkWidget {
    const frame = gtk_frame_new(title) orelse return null;
    const flow = gtk_flow_box_new() orelse return null;
    gtk_flow_box_set_selection_mode(@ptrCast(flow), GTK_SELECTION_NONE);
    gtk_flow_box_set_min_children_per_line(@ptrCast(flow), 1);
    gtk_flow_box_set_max_children_per_line(@ptrCast(flow), 4);
    gtk_flow_box_set_row_spacing(@ptrCast(flow), 8);
    gtk_flow_box_set_column_spacing(@ptrCast(flow), 8);
    gtk_flow_box_set_homogeneous(@ptrCast(flow), TRUE);
    gtk_container_set_border_width(@ptrCast(flow), 8);
    gtk_widget_set_hexpand(flow, TRUE);
    for (buttons) |button| gtk_container_add(@ptrCast(flow), button);
    gtk_container_add(@ptrCast(frame), flow);
    gtk_widget_set_hexpand(frame, TRUE);
    return frame;
}

fn setSharingData(dialog: *GtkWidget, key: [*:0]const u8, widget: *GtkWidget) void {
    g_object_set_data(object(dialog), key, widget);
}

/// Builds the sharing control surface while C retains network and dialog
/// lifecycle ownership. Every action remains explicit and callback-driven.
pub export fn noctty_sharing_contents_new(
    dialog: ?*GtkWidget,
    width: c_int,
    height: c_int,
    context: ?*anyopaque,
    callbacks_raw: ?*const SharingCallbacks,
) c_int {
    const target = dialog orelse return FALSE;
    const callback_data = context orelse return FALSE;
    const callbacks = callbacks_raw orelse return FALSE;

    const scroll = gtk_scrolled_window_new(null, null) orelse return FALSE;
    gtk_scrolled_window_set_policy(
        @ptrCast(scroll),
        GTK_POLICY_AUTOMATIC,
        GTK_POLICY_AUTOMATIC,
    );
    gtk_scrolled_window_set_shadow_type(@ptrCast(scroll), GTK_SHADOW_NONE);
    gtk_widget_set_hexpand(scroll, TRUE);
    gtk_widget_set_vexpand(scroll, TRUE);
    const grid = gtk_grid_new() orelse return FALSE;
    gtk_grid_set_row_spacing(@ptrCast(grid), 10);
    gtk_grid_set_column_spacing(@ptrCast(grid), 10);
    gtk_container_set_border_width(@ptrCast(grid), 16);
    gtk_container_add(@ptrCast(scroll), grid);
    gtk_container_add(@ptrCast(gtk_dialog_get_content_area(@ptrCast(target))), scroll);

    const peers = gtk_combo_box_text_new() orelse return FALSE;
    const alias = gtk_entry_new() orelse return FALSE;
    const endpoint = gtk_entry_new() orelse return FALSE;
    const port = gtk_spin_button_new_with_range(1, 65535, 1) orelse return FALSE;
    gtk_entry_set_text(@ptrCast(alias), "Remote NOCTTY");
    gtk_entry_set_text(@ptrCast(endpoint), "127.0.0.1");
    gtk_entry_set_placeholder_text(@ptrCast(endpoint), "hostname, tailnet IP, or VPN DNS name");
    gtk_spin_button_set_value(@ptrCast(port), 49331);
    setAccessibleName(peers, "Paired device");
    setAccessibleName(alias, "Remote alias");
    setAccessibleName(endpoint, "Other device address");
    setAccessibleName(port, "Pairing port");

    const actions = [_]SharingAction{
        .{ .label = "Listen for pairing", .action = 1 },
        .{ .label = "Connect to pairing listener", .action = 2 },
        .{ .label = "Confirm matching code", .action = 3 },
        .{ .label = "Cancel pairing", .action = 4 },
        .{ .label = "Discover on LAN", .action = 13 },
        .{ .label = "Share current pane", .action = 15 },
        .{ .label = "Share current tab", .action = 5 },
        .{ .label = "Share entire session", .action = 16 },
        .{ .label = "Stop sharing", .action = 6 },
        .{ .label = "Grant control", .action = 7 },
        .{ .label = "Revoke control", .action = 8 },
        .{ .label = "Revoke paired device", .action = 9 },
        .{ .label = "Receive from selected device", .action = 10 },
        .{ .label = "Stop receiving", .action = 11 },
        .{ .label = "Request control", .action = 12 },
        .{ .label = "Reconnect securely", .action = 17 },
        .{ .label = "Retry saving devices", .action = 18 },
    };
    var buttons: [actions.len]*GtkWidget = undefined;
    for (actions, 0..) |action, index| {
        buttons[index] = sharingActionButton(action, callback_data, callbacks.action) orelse
            return FALSE;
    }

    const tabs = gtk_combo_box_text_new() orelse return FALSE;
    const streams = gtk_combo_box_text_new() orelse return FALSE;
    gtk_widget_set_hexpand(tabs, TRUE);
    gtk_widget_set_hexpand(streams, TRUE);
    connectSignal(tabs, "changed", callbacks.tab_changed, callback_data);
    connectSignal(streams, "changed", callbacks.stream_changed, callback_data);
    setAccessibleName(tabs, "Shared tab");
    setAccessibleName(streams, "Shared pane");

    const preview = gtk_drawing_area_new() orelse return FALSE;
    gtk_widget_set_size_request(
        preview,
        @max(1, @min(480, width - 64)),
        @max(1, @min(260, @divTrunc(height, 3))),
    );
    gtk_widget_set_hexpand(preview, TRUE);
    gtk_widget_set_vexpand(preview, TRUE);
    gtk_widget_set_can_focus(preview, TRUE);
    const preview_accessible = gtk_widget_get_accessible(preview);
    atk_object_set_name(preview_accessible, "Remote terminal workspace");
    atk_object_set_description(
        preview_accessible,
        "Shows the selected remote tab with its live split panes. Click a " ++
            "pane to select it; focus here to send input after the host grants " ++
            "temporary control for that pane.",
    );
    gtk_widget_add_events(
        preview,
        GDK_KEY_PRESS_MASK | GDK_BUTTON_PRESS_MASK | GDK_SCROLL_MASK |
            GDK_SMOOTH_SCROLL_MASK,
    );
    connectSignal(preview, "draw", callbacks.preview_draw, callback_data);
    connectSignal(preview, "button-press-event", callbacks.preview_button, callback_data);
    connectSignal(preview, "key-press-event", callbacks.preview_key, callback_data);
    connectSignal(preview, "scroll-event", callbacks.preview_scroll, callback_data);

    const idle_text = "Idle. Pair a device or share with a paired device.";
    const status = gtk_label_new(idle_text) orelse return FALSE;
    gtk_label_set_xalign(@ptrCast(status), 0.0);
    gtk_label_set_line_wrap(@ptrCast(status), TRUE);
    const status_accessible = gtk_widget_get_accessible(status);
    atk_object_set_name(status_accessible, "Session sharing status");
    atk_object_set_role(status_accessible, ATK_ROLE_STATUSBAR);
    atk_object_set_description(status_accessible, idle_text);
    const security = gtk_label_new(
        "Enter the other device's reachable address before pairing; the " ++
            "listener does not infer a routed return address. View-only is the " ++
            "default. Pairing uses a six-digit code derived from the encrypted " ++
            "handshake. Control is temporary and never survives a reconnect.",
    ) orelse return FALSE;
    gtk_label_set_xalign(@ptrCast(security), 0.0);
    gtk_label_set_line_wrap(@ptrCast(security), TRUE);

    const pairing_group = sharingActionGroup("Pairing", buttons[0..5]) orelse return FALSE;
    const sharing_group = sharingActionGroup("Sharing scope", buttons[5..9]) orelse return FALSE;
    const control_group = sharingActionGroup(
        "Remote control and devices",
        buttons[9..17],
    ) orelse return FALSE;
    const peer_label = sharingFieldLabel("Paired device", peers) orelse return FALSE;
    const alias_label = sharingFieldLabel("Remote alias", alias) orelse return FALSE;
    const endpoint_label = sharingFieldLabel("Other device address", endpoint) orelse return FALSE;
    const tabs_label = sharingFieldLabel("Shared tab", tabs) orelse return FALSE;
    const streams_label = sharingFieldLabel("Shared pane", streams) orelse return FALSE;
    gtk_grid_attach(@ptrCast(grid), peer_label, 0, 0, 1, 1);
    gtk_grid_attach(@ptrCast(grid), peers, 1, 0, 3, 1);
    gtk_grid_attach(@ptrCast(grid), alias_label, 0, 1, 1, 1);
    gtk_grid_attach(@ptrCast(grid), alias, 1, 1, 3, 1);
    gtk_grid_attach(@ptrCast(grid), endpoint_label, 0, 2, 1, 1);
    gtk_grid_attach(@ptrCast(grid), endpoint, 1, 2, 2, 1);
    gtk_grid_attach(@ptrCast(grid), port, 3, 2, 1, 1);
    gtk_grid_attach(@ptrCast(grid), pairing_group, 0, 3, 4, 1);
    gtk_grid_attach(@ptrCast(grid), sharing_group, 0, 4, 4, 1);
    gtk_grid_attach(@ptrCast(grid), control_group, 0, 5, 4, 1);
    gtk_grid_attach(@ptrCast(grid), tabs_label, 0, 6, 1, 1);
    gtk_grid_attach(@ptrCast(grid), tabs, 1, 6, 3, 1);
    gtk_grid_attach(@ptrCast(grid), streams_label, 0, 7, 1, 1);
    gtk_grid_attach(@ptrCast(grid), streams, 1, 7, 3, 1);
    gtk_grid_attach(@ptrCast(grid), preview, 0, 8, 4, 1);
    gtk_grid_attach(@ptrCast(grid), status, 0, 9, 4, 1);
    gtk_grid_attach(@ptrCast(grid), security, 0, 10, 4, 1);

    const keys = [_][*:0]const u8{
        "noctty-sharing-pair-listen",
        "noctty-sharing-pair-connect",
        "noctty-sharing-confirm",
        "noctty-sharing-cancel-pairing",
        "noctty-sharing-discover",
        "noctty-sharing-share-pane",
        "noctty-sharing-share-tab",
        "noctty-sharing-share-session",
        "noctty-sharing-stop",
        "noctty-sharing-grant",
        "noctty-sharing-revoke",
        "noctty-sharing-revoke-device",
        "noctty-sharing-receive",
        "noctty-sharing-stop-receive",
        "noctty-sharing-request-control",
        "noctty-sharing-reconnect",
        "noctty-sharing-retry-save",
    };
    for (keys, buttons) |key, button| setSharingData(target, key, button);
    setSharingData(target, "noctty-sharing-peers", peers);
    setSharingData(target, "noctty-sharing-alias", alias);
    setSharingData(target, "noctty-sharing-endpoint", endpoint);
    setSharingData(target, "noctty-sharing-tabs", tabs);
    setSharingData(target, "noctty-sharing-streams", streams);
    setSharingData(target, "noctty-sharing-port", port);
    setSharingData(target, "noctty-sharing-status", status);
    setSharingData(target, "noctty-sharing-preview", preview);
    setSharingData(target, "noctty-sharing-scroll", scroll);
    g_object_set_data(object(target), "noctty-sharing-stream-count", @ptrFromInt(~@as(usize, 0)));
    return TRUE;
}

fn addStyle(strip: *GtkWidget, label: *GtkWidget) void {
    const provider = gtk_css_provider_new() orelse return;
    _ = gtk_css_provider_load_from_data(provider, "#noctty-pane-info {" ++
        " background-color: #11151d;" ++
        " border-top: 1px solid #2b3444;" ++
        "}" ++
        "#noctty-pane-info label {" ++
        " color: #c4cbd6;" ++
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
