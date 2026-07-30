const std = @import("std");

pub const gboolean = c_int;
pub const guint = c_uint;
pub const GType = usize;
pub const GCallback = ?*const fn () callconv(.c) void;

pub const GtkWidget = opaque {};
pub const GtkWindow = opaque {};
pub const GtkContainer = opaque {};
pub const GtkBox = opaque {};
pub const GtkPaned = opaque {};
pub const GtkNotebook = opaque {};
pub const GtkLabel = opaque {};
pub const GtkButton = opaque {};
pub const GtkEntry = opaque {};
pub const GtkScrolledWindow = opaque {};
pub const GtkTreeView = opaque {};
pub const GtkTreeViewColumn = opaque {};
pub const GtkTreeModel = opaque {};
pub const GtkTreeStore = opaque {};
pub const GtkTreePath = opaque {};
pub const GtkTreeSelection = opaque {};
pub const GtkTextBuffer = opaque {};
pub const GtkTextMark = opaque {};
pub const GtkTextTag = opaque {};
pub const GtkCheckMenuItem = opaque {};
pub const GtkClipboard = opaque {};
pub const GtkCssProvider = opaque {};
pub const GtkStyleProvider = opaque {};
pub const GtkStyleContext = opaque {};
pub const GtkSourceBuffer = opaque {};
pub const GtkSourceView = opaque {};
pub const GtkSourceMap = opaque {};
pub const GtkSourceLanguage = opaque {};
pub const GtkSourceLanguageManager = opaque {};
pub const GtkSourceStyleScheme = opaque {};
pub const GtkSourceStyleSchemeManager = opaque {};
pub const GtkSourceSearchSettings = opaque {};
pub const GtkSourceSearchContext = opaque {};
pub const AtkObject = opaque {};
pub const GdkScreen = opaque {};
pub const GdkDisplay = opaque {};
pub const GdkWindow = opaque {};
pub const GdkPixbuf = opaque {};
pub const GdkEvent = opaque {};
pub const GError = opaque {};
pub const GThreadPool = opaque {};
pub const GFile = opaque {};
pub const GFileMonitor = opaque {};
pub const GCancellable = opaque {};

pub const GtkTreeIter = extern struct {
    stamp: c_int,
    user_data: ?*anyopaque,
    user_data2: ?*anyopaque,
    user_data3: ?*anyopaque,
};

pub const GtkTextIter = extern struct {
    dummy1: ?*anyopaque,
    dummy2: ?*anyopaque,
    dummy3: c_int,
    dummy4: c_int,
    dummy5: c_int,
    dummy6: c_int,
    dummy7: c_int,
    dummy8: c_int,
    dummy9: ?*anyopaque,
    dummy10: ?*anyopaque,
    dummy11: c_int,
    dummy12: c_int,
    dummy13: c_int,
    dummy14: ?*anyopaque,
};

const GValueData = extern union {
    v_int: c_int,
    v_uint: c_uint,
    v_long: c_long,
    v_ulong: c_ulong,
    v_int64: i64,
    v_uint64: u64,
    v_float: f32,
    v_double: f64,
    v_pointer: ?*anyopaque,
};

pub const GValue = extern struct {
    g_type: GType,
    data: [2]GValueData,
};

pub const GdkEventKey = extern struct {
    type: c_int,
    window: ?*GdkWindow,
    send_event: i8,
    time: u32,
    state: c_uint,
    keyval: c_uint,
    length: c_int,
    string: ?[*:0]u8,
    hardware_keycode: u16,
    group: u8,
};

pub const GdkEventScroll = extern struct {
    type: c_int,
    window: ?*GdkWindow,
    send_event: i8,
    time: u32,
    x: f64,
    y: f64,
    state: c_uint,
    direction: c_int,
    device: ?*anyopaque,
    x_root: f64,
    y_root: f64,
    delta_x: f64,
    delta_y: f64,
    is_stop: c_uint,
};

pub const GTK_WINDOW_TOPLEVEL: c_int = 0;
pub const GTK_ORIENTATION_HORIZONTAL: c_int = 0;
pub const GTK_ORIENTATION_VERTICAL: c_int = 1;
pub const GTK_POLICY_AUTOMATIC: c_int = 1;
pub const GTK_DIALOG_MODAL: c_int = 1;
pub const GTK_DIALOG_DESTROY_WITH_PARENT: c_int = 2;
pub const GTK_MESSAGE_INFO: c_int = 0;
pub const GTK_MESSAGE_WARNING: c_int = 1;
pub const GTK_MESSAGE_QUESTION: c_int = 2;
pub const GTK_BUTTONS_NONE: c_int = 0;
pub const GTK_BUTTONS_CLOSE: c_int = 2;
pub const GTK_RESPONSE_REJECT: c_int = -2;
pub const GTK_RESPONSE_ACCEPT: c_int = -3;
pub const GTK_RESPONSE_CANCEL: c_int = -6;
pub const GTK_FILE_CHOOSER_ACTION_OPEN: c_int = 0;
pub const GTK_FILE_CHOOSER_ACTION_SAVE: c_int = 1;
pub const GTK_FILE_CHOOSER_ACTION_SELECT_FOLDER: c_int = 2;
pub const GTK_ICON_SIZE_MENU: c_int = 1;
pub const GTK_RELIEF_NONE: c_int = 2;
pub const GTK_WRAP_NONE: c_int = 0;
pub const GTK_SOURCE_SMART_HOME_END_BEFORE: c_int = 1;
pub const GTK_STYLE_PROVIDER_PRIORITY_APPLICATION: c_uint = 600;
pub const PANGO_ELLIPSIZE_END: c_int = 3;
pub const G_SOURCE_REMOVE: gboolean = 0;
pub const G_SOURCE_CONTINUE: gboolean = 1;
pub const G_FILE_MONITOR_NONE: c_int = 0;
pub const G_FILE_MONITOR_EVENT_CHANGED: c_int = 0;
pub const G_FILE_MONITOR_EVENT_CHANGES_DONE_HINT: c_int = 1;
pub const G_FILE_MONITOR_EVENT_DELETED: c_int = 2;
pub const G_FILE_MONITOR_EVENT_CREATED: c_int = 3;
pub const G_FILE_MONITOR_EVENT_ATTRIBUTE_CHANGED: c_int = 4;
pub const G_FILE_MONITOR_EVENT_MOVED: c_int = 7;
pub const G_FILE_MONITOR_EVENT_RENAMED: c_int = 8;
pub const G_FILE_MONITOR_EVENT_MOVED_IN: c_int = 9;
pub const G_FILE_MONITOR_EVENT_MOVED_OUT: c_int = 10;
pub const G_TYPE_BOOLEAN: GType = 5 << 2;
pub const G_TYPE_UINT64: GType = 11 << 2;
pub const G_TYPE_STRING: GType = 16 << 2;
pub const GDK_SHIFT_MASK: c_uint = 1 << 0;
pub const GDK_CONTROL_MASK: c_uint = 1 << 2;
pub const GDK_MOD1_MASK: c_uint = 1 << 3;
pub const GDK_SCROLL_MASK: c_int = 1 << 21;
pub const GDK_SMOOTH_SCROLL_MASK: c_int = 1 << 23;
pub const GDK_SCROLL_UP: c_int = 0;
pub const GDK_SCROLL_DOWN: c_int = 1;
pub const GDK_SCROLL_SMOOTH: c_int = 4;
pub const GDK_KEY_Escape: c_uint = 0xff1b;
pub const GDK_KEY_BackSpace: c_uint = 0xff08;
pub const GDK_KEY_Delete: c_uint = 0xffff;
pub const GDK_KEY_Down: c_uint = 0xff54;
pub const GDK_KEY_F3: c_uint = 0xffc0;
pub const GDK_KEY_Page_Up: c_uint = 0xff55;
pub const GDK_KEY_Page_Down: c_uint = 0xff56;
pub const GDK_KEY_bracketleft: c_uint = '[';
pub const GDK_KEY_bracketright: c_uint = ']';
pub const GDK_KEY_braceleft: c_uint = '{';
pub const GDK_KEY_braceright: c_uint = '}';
pub const GDK_KEY_b: c_uint = 'b';
pub const GDK_KEY_f: c_uint = 'f';
pub const GDK_KEY_l: c_uint = 'l';
pub const GDK_KEY_n: c_uint = 'n';
pub const GDK_KEY_o: c_uint = 'o';
pub const GDK_KEY_p: c_uint = 'p';
pub const GDK_KEY_s: c_uint = 's';
pub const GDK_KEY_w: c_uint = 'w';

pub extern fn gtk_init_check(argc: ?*c_int, argv: ?*anyopaque) gboolean;
pub extern fn gtk_main() void;
pub extern fn gtk_main_quit() void;
pub extern fn gtk_window_new(window_type: c_int) ?*GtkWidget;
pub extern fn gtk_window_set_title(window: *GtkWindow, title: [*:0]const u8) void;
pub extern fn gtk_window_set_default_size(window: *GtkWindow, width: c_int, height: c_int) void;
pub extern fn gtk_window_set_icon_name(window: *GtkWindow, name: [*:0]const u8) void;
pub extern fn gtk_window_set_transient_for(window: *GtkWindow, parent: *GtkWindow) void;
pub extern fn gtk_widget_set_name(widget: *GtkWidget, name: [*:0]const u8) void;
pub extern fn gtk_widget_add_events(widget: *GtkWidget, events: c_int) void;
pub extern fn gtk_widget_get_style_context(widget: *GtkWidget) *GtkStyleContext;
pub extern fn gtk_widget_set_size_request(widget: *GtkWidget, width: c_int, height: c_int) void;
pub extern fn gtk_widget_set_hexpand(widget: *GtkWidget, expand: gboolean) void;
pub extern fn gtk_widget_set_tooltip_text(widget: *GtkWidget, text: [*:0]const u8) void;
pub extern fn gtk_widget_set_visible(widget: *GtkWidget, visible: gboolean) void;
pub extern fn gtk_widget_get_visible(widget: *GtkWidget) gboolean;
pub extern fn gtk_widget_show(widget: *GtkWidget) void;
pub extern fn gtk_widget_show_all(widget: *GtkWidget) void;
pub extern fn gtk_widget_hide(widget: *GtkWidget) void;
pub extern fn gtk_widget_destroy(widget: *GtkWidget) void;
pub extern fn gtk_widget_grab_focus(widget: *GtkWidget) void;
pub extern fn gtk_widget_queue_draw(widget: *GtkWidget) void;
pub extern fn gtk_widget_get_window(widget: *GtkWidget) ?*GdkWindow;
pub extern fn gtk_widget_get_accessible(widget: *GtkWidget) *AtkObject;
pub extern fn gtk_container_add(container: *GtkContainer, widget: *GtkWidget) void;
pub extern fn gtk_box_new(orientation: c_int, spacing: c_int) ?*GtkWidget;
pub extern fn gtk_box_pack_start(box: *GtkBox, child: *GtkWidget, expand: gboolean, fill: gboolean, padding: c_uint) void;
pub extern fn gtk_box_pack_end(box: *GtkBox, child: *GtkWidget, expand: gboolean, fill: gboolean, padding: c_uint) void;
pub extern fn gtk_paned_new(orientation: c_int) ?*GtkWidget;
pub extern fn gtk_paned_pack1(paned: *GtkPaned, child: *GtkWidget, resize: gboolean, shrink: gboolean) void;
pub extern fn gtk_paned_pack2(paned: *GtkPaned, child: *GtkWidget, resize: gboolean, shrink: gboolean) void;
pub extern fn gtk_paned_set_position(paned: *GtkPaned, position: c_int) void;
pub extern fn gtk_notebook_new() ?*GtkWidget;
pub extern fn gtk_notebook_set_scrollable(notebook: *GtkNotebook, scrollable: gboolean) void;
pub extern fn gtk_notebook_set_show_border(notebook: *GtkNotebook, show_border: gboolean) void;
pub extern fn gtk_notebook_append_page(notebook: *GtkNotebook, child: *GtkWidget, tab_label: *GtkWidget) c_int;
pub extern fn gtk_notebook_set_tab_reorderable(notebook: *GtkNotebook, child: *GtkWidget, reorderable: gboolean) void;
pub extern fn gtk_notebook_set_current_page(notebook: *GtkNotebook, page_num: c_int) void;
pub extern fn gtk_notebook_get_current_page(notebook: *GtkNotebook) c_int;
pub extern fn gtk_notebook_get_n_pages(notebook: *GtkNotebook) c_int;
pub extern fn gtk_notebook_get_nth_page(notebook: *GtkNotebook, page_num: c_int) ?*GtkWidget;
pub extern fn gtk_notebook_page_num(notebook: *GtkNotebook, child: *GtkWidget) c_int;
pub extern fn gtk_notebook_remove_page(notebook: *GtkNotebook, page_num: c_int) void;
pub extern fn gtk_menu_bar_new() ?*GtkWidget;
pub extern fn gtk_menu_new() ?*GtkWidget;
pub extern fn gtk_menu_item_new_with_label(label: [*:0]const u8) ?*GtkWidget;
pub extern fn gtk_menu_item_set_label(menu_item: *anyopaque, label: [*:0]const u8) void;
pub extern fn gtk_check_menu_item_new_with_label(label: [*:0]const u8) ?*GtkWidget;
pub extern fn gtk_check_menu_item_set_active(check_menu_item: *GtkCheckMenuItem, is_active: gboolean) void;
pub extern fn gtk_check_menu_item_get_active(check_menu_item: *GtkCheckMenuItem) gboolean;
pub extern fn gtk_menu_item_set_submenu(menu_item: *anyopaque, submenu: *GtkWidget) void;
pub extern fn gtk_menu_shell_append(menu_shell: *anyopaque, child: *GtkWidget) void;
pub extern fn gtk_separator_menu_item_new() ?*GtkWidget;
pub extern fn gtk_label_new(text: ?[*:0]const u8) ?*GtkWidget;
pub extern fn gtk_label_set_text(label: *GtkLabel, text: [*:0]const u8) void;
pub extern fn gtk_label_get_text(label: *GtkLabel) [*:0]const u8;
pub extern fn gtk_label_set_xalign(label: *GtkLabel, xalign: f32) void;
pub extern fn gtk_label_set_ellipsize(label: *GtkLabel, mode: c_int) void;
pub extern fn gtk_button_new_from_icon_name(icon_name: [*:0]const u8, size: c_int) ?*GtkWidget;
pub extern fn gtk_button_set_relief(button: *anyopaque, relief: c_int) void;
pub extern fn gtk_scrolled_window_new(hadjustment: ?*anyopaque, vadjustment: ?*anyopaque) ?*GtkWidget;
pub extern fn gtk_scrolled_window_set_policy(scrolled_window: *GtkScrolledWindow, hscrollbar_policy: c_int, vscrollbar_policy: c_int) void;
pub extern fn gtk_search_entry_new() ?*GtkWidget;
pub extern fn gtk_entry_new() ?*GtkWidget;
pub extern fn gtk_entry_get_text(entry: *anyopaque) [*:0]const u8;
pub extern fn gtk_entry_set_text(entry: *anyopaque, text: [*:0]const u8) void;
pub extern fn gtk_entry_set_placeholder_text(entry: *anyopaque, text: [*:0]const u8) void;
pub extern fn gtk_combo_box_text_new() ?*GtkWidget;
pub extern fn gtk_combo_box_text_append_text(combo_box: *anyopaque, text: [*:0]const u8) void;
pub extern fn gtk_combo_box_set_active(combo_box: *anyopaque, index: c_int) void;
pub extern fn gtk_combo_box_get_active(combo_box: *anyopaque) c_int;
pub extern fn gtk_tree_store_newv(n_columns: c_int, types: [*]GType) ?*GtkTreeStore;
pub extern fn gtk_tree_store_clear(tree_store: *GtkTreeStore) void;
pub extern fn gtk_tree_store_append(tree_store: *GtkTreeStore, iter: *GtkTreeIter, parent: ?*GtkTreeIter) void;
pub extern fn gtk_tree_store_remove(tree_store: *GtkTreeStore, iter: *GtkTreeIter) gboolean;
pub extern fn gtk_tree_store_set(tree_store: *GtkTreeStore, iter: *GtkTreeIter, ...) void;
pub extern fn gtk_tree_view_new_with_model(model: *GtkTreeModel) ?*GtkWidget;
pub extern fn gtk_tree_view_set_model(tree_view: *GtkTreeView, model: ?*GtkTreeModel) void;
pub extern fn gtk_tree_view_set_headers_visible(tree_view: *GtkTreeView, headers_visible: gboolean) void;
pub extern fn gtk_tree_view_set_enable_search(tree_view: *GtkTreeView, enable_search: gboolean) void;
pub extern fn gtk_tree_view_set_search_column(tree_view: *GtkTreeView, column: c_int) void;
pub extern fn gtk_tree_view_get_model(tree_view: *GtkTreeView) ?*GtkTreeModel;
pub extern fn gtk_tree_view_get_selection(tree_view: *GtkTreeView) *GtkTreeSelection;
pub extern fn gtk_tree_view_append_column(tree_view: *GtkTreeView, column: *GtkTreeViewColumn) c_int;
pub extern fn gtk_tree_view_expand_row(tree_view: *GtkTreeView, path: *GtkTreePath, open_all: gboolean) gboolean;
pub extern fn gtk_tree_view_collapse_row(tree_view: *GtkTreeView, path: *GtkTreePath) gboolean;
pub extern fn gtk_tree_view_row_expanded(tree_view: *GtkTreeView, path: *GtkTreePath) gboolean;
pub extern fn gtk_tree_model_iter_children(tree_model: *GtkTreeModel, iter: *GtkTreeIter, parent: ?*GtkTreeIter) gboolean;
pub extern fn gtk_tree_model_get_iter_first(tree_model: *GtkTreeModel, iter: *GtkTreeIter) gboolean;
pub extern fn gtk_tree_model_iter_next(tree_model: *GtkTreeModel, iter: *GtkTreeIter) gboolean;
pub extern fn gtk_tree_view_column_new() ?*GtkTreeViewColumn;
pub extern fn gtk_tree_view_column_pack_start(tree_column: *GtkTreeViewColumn, cell: *anyopaque, expand: gboolean) void;
pub extern fn gtk_tree_view_column_add_attribute(tree_column: *GtkTreeViewColumn, cell_renderer: *anyopaque, attribute: [*:0]const u8, column: c_int) void;
pub extern fn gtk_cell_renderer_pixbuf_new() ?*anyopaque;
pub extern fn gtk_cell_renderer_text_new() ?*anyopaque;
pub extern fn gtk_tree_path_new_first() ?*GtkTreePath;
pub extern fn gtk_tree_path_new_from_string(path: [*:0]const u8) ?*GtkTreePath;
pub extern fn gtk_tree_path_free(path: *GtkTreePath) void;
pub extern fn gtk_tree_model_get_iter(tree_model: *GtkTreeModel, iter: *GtkTreeIter, path: *GtkTreePath) gboolean;
pub extern fn gtk_tree_model_get_value(tree_model: *GtkTreeModel, iter: *GtkTreeIter, column: c_int, value: *GValue) void;
pub extern fn gtk_tree_selection_get_selected(selection: *GtkTreeSelection, model: ?**GtkTreeModel, iter: *GtkTreeIter) gboolean;
pub extern fn gtk_tree_selection_select_path(selection: *GtkTreeSelection, path: *GtkTreePath) void;
pub extern fn gtk_css_provider_new() ?*GtkCssProvider;
pub extern fn gtk_css_provider_load_from_data(css_provider: *GtkCssProvider, data: [*]const u8, length: isize, error_ptr: *?*GError) gboolean;
pub extern fn gtk_style_context_add_provider(style_context: *GtkStyleContext, provider: *GtkStyleProvider, priority: c_uint) void;
pub extern fn gtk_style_context_add_provider_for_screen(screen: *GdkScreen, provider: *GtkStyleProvider, priority: c_uint) void;
pub extern fn gdk_screen_get_default() ?*GdkScreen;
pub extern fn gdk_display_get_default() ?*GdkDisplay;
pub extern fn gdk_window_get_width(window: *GdkWindow) c_int;
pub extern fn gdk_window_get_height(window: *GdkWindow) c_int;
pub extern fn gdk_pixbuf_get_from_window(window: *GdkWindow, src_x: c_int, src_y: c_int, width: c_int, height: c_int) ?*GdkPixbuf;
pub extern fn gdk_pixbuf_save(pixbuf: *GdkPixbuf, filename: [*:0]const u8, image_type: [*:0]const u8, error_ptr: *?*GError, ...) gboolean;
pub extern fn gdk_keyval_to_lower(keyval: c_uint) c_uint;
pub extern fn gtk_accelerator_get_default_mod_mask() c_uint;
pub extern fn gtk_clipboard_get_default(display: ?*GdkDisplay) ?*GtkClipboard;
pub extern fn gtk_text_buffer_set_text(buffer: *GtkTextBuffer, text: [*]const u8, len: c_int) void;
pub extern fn gtk_text_buffer_set_modified(buffer: *GtkTextBuffer, setting: gboolean) void;
pub extern fn gtk_text_buffer_get_modified(buffer: *GtkTextBuffer) gboolean;
pub extern fn gtk_text_buffer_get_bounds(buffer: *GtkTextBuffer, start: *GtkTextIter, end: *GtkTextIter) void;
pub extern fn gtk_text_buffer_get_start_iter(buffer: *GtkTextBuffer, iter: *GtkTextIter) void;
pub extern fn gtk_text_buffer_get_end_iter(buffer: *GtkTextBuffer, iter: *GtkTextIter) void;
pub extern fn gtk_text_buffer_get_line_count(buffer: *GtkTextBuffer) c_int;
pub extern fn gtk_text_buffer_get_iter_at_line(buffer: *GtkTextBuffer, iter: *GtkTextIter, line_number: c_int) void;
pub extern fn gtk_text_buffer_get_iter_at_line_index(buffer: *GtkTextBuffer, iter: *GtkTextIter, line_number: c_int, byte_index: c_int) void;
pub extern fn gtk_text_buffer_get_iter_at_offset(buffer: *GtkTextBuffer, iter: *GtkTextIter, char_offset: c_int) void;
pub extern fn gtk_text_buffer_get_insert(buffer: *GtkTextBuffer) *GtkTextMark;
pub extern fn gtk_text_buffer_get_iter_at_mark(buffer: *GtkTextBuffer, iter: *GtkTextIter, mark: *GtkTextMark) void;
pub extern fn gtk_text_buffer_create_mark(buffer: *GtkTextBuffer, mark_name: ?[*:0]const u8, where: *const GtkTextIter, left_gravity: gboolean) ?*GtkTextMark;
pub extern fn gtk_text_buffer_delete_mark(buffer: *GtkTextBuffer, mark: *GtkTextMark) void;
pub extern fn gtk_text_buffer_create_tag(buffer: *GtkTextBuffer, tag_name: ?[*:0]const u8, first_property_name: ?[*:0]const u8, ...) ?*GtkTextTag;
pub extern fn gtk_text_buffer_apply_tag(buffer: *GtkTextBuffer, tag: *GtkTextTag, start: *const GtkTextIter, end: *const GtkTextIter) void;
pub extern fn gtk_text_buffer_remove_tag(buffer: *GtkTextBuffer, tag: *GtkTextTag, start: *const GtkTextIter, end: *const GtkTextIter) void;
pub extern fn gtk_text_buffer_get_text(buffer: *GtkTextBuffer, start: *const GtkTextIter, end: *const GtkTextIter, include_hidden_chars: gboolean) ?[*:0]u8;
pub extern fn gtk_text_buffer_get_selection_bounds(buffer: *GtkTextBuffer, start: *GtkTextIter, end: *GtkTextIter) gboolean;
pub extern fn gtk_text_buffer_begin_user_action(buffer: *GtkTextBuffer) void;
pub extern fn gtk_text_buffer_end_user_action(buffer: *GtkTextBuffer) void;
pub extern fn gtk_text_buffer_insert(buffer: *GtkTextBuffer, iter: *GtkTextIter, text: [*]const u8, len: c_int) void;
pub extern fn gtk_text_buffer_delete(buffer: *GtkTextBuffer, start: *GtkTextIter, end: *GtkTextIter) void;
pub extern fn gtk_text_buffer_select_range(buffer: *GtkTextBuffer, ins: *const GtkTextIter, bound: *const GtkTextIter) void;
pub extern fn gtk_text_buffer_cut_clipboard(buffer: *GtkTextBuffer, clipboard: ?*GtkClipboard, default_editable: gboolean) void;
pub extern fn gtk_text_buffer_copy_clipboard(buffer: *GtkTextBuffer, clipboard: ?*GtkClipboard) void;
pub extern fn gtk_text_buffer_paste_clipboard(buffer: *GtkTextBuffer, clipboard: ?*GtkClipboard, override_location: ?*GtkTextIter, default_editable: gboolean) void;
pub extern fn gtk_text_iter_get_line(iter: *const GtkTextIter) c_int;
pub extern fn gtk_text_iter_get_line_offset(iter: *const GtkTextIter) c_int;
pub extern fn gtk_text_iter_get_offset(iter: *const GtkTextIter) c_int;
pub extern fn gtk_text_iter_has_tag(iter: *const GtkTextIter, tag: *GtkTextTag) gboolean;
pub extern fn gtk_text_iter_backward_char(iter: *GtkTextIter) gboolean;
pub extern fn gtk_text_view_set_monospace(text_view: *anyopaque, monospace: gboolean) void;
pub extern fn gtk_text_view_set_wrap_mode(text_view: *anyopaque, wrap_mode: c_int) void;
pub extern fn gtk_text_view_set_editable(text_view: *anyopaque, setting: gboolean) void;
pub extern fn gtk_text_view_scroll_to_iter(text_view: *anyopaque, iter: *GtkTextIter, within_margin: f64, use_align: gboolean, xalign: f64, yalign: f64) gboolean;
pub extern fn gtk_source_language_manager_new() ?*GtkSourceLanguageManager;
pub extern fn gtk_source_language_manager_get_search_path(language_manager: *GtkSourceLanguageManager) ?[*:null]?[*:0]const u8;
pub extern fn gtk_source_language_manager_set_search_path(language_manager: *GtkSourceLanguageManager, dirs: [*:null]?[*:0]const u8) void;
pub extern fn gtk_source_language_manager_get_language_ids(language_manager: *GtkSourceLanguageManager) ?[*:null]?[*:0]const u8;
pub extern fn gtk_source_language_manager_guess_language(language_manager: *GtkSourceLanguageManager, filename: [*:0]const u8, content_type: ?[*:0]const u8) ?*GtkSourceLanguage;
pub extern fn gtk_source_language_get_id(language: *GtkSourceLanguage) [*:0]const u8;
pub extern fn gtk_source_language_get_name(language: *GtkSourceLanguage) [*:0]const u8;
pub extern fn gtk_source_style_scheme_manager_new() ?*GtkSourceStyleSchemeManager;
pub extern fn gtk_source_style_scheme_manager_prepend_search_path(manager: *GtkSourceStyleSchemeManager, path: [*:0]const u8) void;
pub extern fn gtk_source_style_scheme_manager_get_scheme(manager: *GtkSourceStyleSchemeManager, scheme_id: [*:0]const u8) ?*GtkSourceStyleScheme;
pub extern fn gtk_source_buffer_new(table: ?*anyopaque) ?*GtkSourceBuffer;
pub extern fn gtk_source_buffer_new_with_language(language: *GtkSourceLanguage) ?*GtkSourceBuffer;
pub extern fn gtk_source_buffer_set_highlight_syntax(buffer: *GtkSourceBuffer, highlight: gboolean) void;
pub extern fn gtk_source_buffer_set_highlight_matching_brackets(buffer: *GtkSourceBuffer, highlight: gboolean) void;
pub extern fn gtk_source_buffer_set_max_undo_levels(buffer: *GtkSourceBuffer, max_undo_levels: c_int) void;
pub extern fn gtk_source_buffer_set_implicit_trailing_newline(buffer: *GtkSourceBuffer, implicit_trailing_newline: gboolean) void;
pub extern fn gtk_source_buffer_set_style_scheme(buffer: *GtkSourceBuffer, scheme: *GtkSourceStyleScheme) void;
pub extern fn gtk_source_buffer_begin_not_undoable_action(buffer: *GtkSourceBuffer) void;
pub extern fn gtk_source_buffer_end_not_undoable_action(buffer: *GtkSourceBuffer) void;
pub extern fn gtk_source_buffer_can_undo(buffer: *GtkSourceBuffer) gboolean;
pub extern fn gtk_source_buffer_can_redo(buffer: *GtkSourceBuffer) gboolean;
pub extern fn gtk_source_buffer_undo(buffer: *GtkSourceBuffer) void;
pub extern fn gtk_source_buffer_redo(buffer: *GtkSourceBuffer) void;
pub extern fn gtk_source_buffer_get_language(buffer: *GtkSourceBuffer) ?*GtkSourceLanguage;
pub extern fn gtk_source_buffer_set_language(buffer: *GtkSourceBuffer, language: ?*GtkSourceLanguage) void;
pub extern fn gtk_source_view_new_with_buffer(buffer: *GtkSourceBuffer) ?*GtkWidget;
pub extern fn gtk_source_view_set_show_line_numbers(view: *GtkSourceView, show: gboolean) void;
pub extern fn gtk_source_view_get_show_line_numbers(view: *GtkSourceView) gboolean;
pub extern fn gtk_source_view_set_highlight_current_line(view: *GtkSourceView, highlight: gboolean) void;
pub extern fn gtk_source_view_set_auto_indent(view: *GtkSourceView, enable: gboolean) void;
pub extern fn gtk_source_view_set_indent_on_tab(view: *GtkSourceView, enable: gboolean) void;
pub extern fn gtk_source_view_set_smart_backspace(view: *GtkSourceView, smart_backspace: gboolean) void;
pub extern fn gtk_source_view_set_smart_home_end(view: *GtkSourceView, smart_home_end: c_int) void;
pub extern fn gtk_source_view_set_tab_width(view: *GtkSourceView, width: c_uint) void;
pub extern fn gtk_source_view_set_insert_spaces_instead_of_tabs(view: *GtkSourceView, enable: gboolean) void;
pub extern fn gtk_source_map_new() ?*GtkWidget;
pub extern fn gtk_source_map_set_view(map: *GtkSourceMap, view: *GtkSourceView) void;
pub extern fn gtk_source_map_get_view(map: *GtkSourceMap) ?*GtkSourceView;
pub extern fn gtk_source_search_settings_new() ?*GtkSourceSearchSettings;
pub extern fn gtk_source_search_settings_set_search_text(settings: *GtkSourceSearchSettings, text: [*:0]const u8) void;
pub extern fn gtk_source_search_settings_set_wrap_around(settings: *GtkSourceSearchSettings, wrap_around: gboolean) void;
pub extern fn gtk_source_search_context_new(buffer: *GtkSourceBuffer, settings: *GtkSourceSearchSettings) ?*GtkSourceSearchContext;
pub extern fn gtk_source_search_context_set_highlight(search: *GtkSourceSearchContext, highlight: gboolean) void;
pub extern fn gtk_source_search_context_get_occurrences_count(search: *GtkSourceSearchContext) c_int;
pub extern fn gtk_source_search_context_forward(search: *GtkSourceSearchContext, iter: *const GtkTextIter, match_start: *GtkTextIter, match_end: *GtkTextIter, has_wrapped_around: ?*gboolean) gboolean;
pub extern fn gtk_source_search_context_backward(search: *GtkSourceSearchContext, iter: *const GtkTextIter, match_start: *GtkTextIter, match_end: *GtkTextIter, has_wrapped_around: ?*gboolean) gboolean;
pub extern fn gtk_file_chooser_dialog_new(title: [*:0]const u8, parent: *GtkWindow, action: c_int, first_button_text: [*:0]const u8, ...) ?*GtkWidget;
pub extern fn gtk_file_chooser_set_local_only(chooser: *anyopaque, local_only: gboolean) void;
pub extern fn gtk_file_chooser_set_current_folder(chooser: *anyopaque, filename: [*:0]const u8) gboolean;
pub extern fn gtk_file_chooser_set_current_name(chooser: *anyopaque, name: [*:0]const u8) void;
pub extern fn gtk_file_chooser_set_do_overwrite_confirmation(chooser: *anyopaque, do_overwrite_confirmation: gboolean) void;
pub extern fn gtk_file_chooser_get_filename(chooser: *anyopaque) ?[*:0]u8;
pub extern fn gtk_message_dialog_new(parent: *GtkWindow, flags: c_int, message_type: c_int, buttons: c_int, message_format: [*:0]const u8, ...) ?*GtkWidget;
pub extern fn gtk_dialog_get_content_area(dialog: *anyopaque) ?*GtkWidget;
pub extern fn gtk_dialog_add_button(dialog: *anyopaque, button_text: [*:0]const u8, response_id: c_int) ?*GtkWidget;
pub extern fn gtk_dialog_set_default_response(dialog: *anyopaque, response_id: c_int) void;
pub extern fn gtk_dialog_run(dialog: *anyopaque) c_int;
pub extern fn gtk_dialog_response(dialog: *anyopaque, response_id: c_int) void;
pub extern fn gtk_about_dialog_new() ?*GtkWidget;
pub extern fn gtk_about_dialog_set_program_name(about: *anyopaque, name: [*:0]const u8) void;
pub extern fn gtk_about_dialog_set_version(about: *anyopaque, version: [*:0]const u8) void;
pub extern fn gtk_about_dialog_set_comments(about: *anyopaque, comments: [*:0]const u8) void;
pub extern fn g_signal_connect_data(instance: ?*anyopaque, detailed_signal: [*:0]const u8, c_handler: GCallback, data: ?*anyopaque, destroy_data: ?*anyopaque, connect_flags: c_uint) c_ulong;
pub extern fn g_timeout_add(interval: c_uint, function: *const fn (?*anyopaque) callconv(.c) gboolean, data: ?*anyopaque) c_uint;
pub extern fn g_idle_add(function: *const fn (?*anyopaque) callconv(.c) gboolean, data: ?*anyopaque) c_uint;
pub extern fn g_main_context_iteration(context: ?*anyopaque, may_block: gboolean) gboolean;
pub extern fn g_source_remove(tag: c_uint) gboolean;
pub extern fn g_thread_pool_new(
    function: *const fn (?*anyopaque, ?*anyopaque) callconv(.c) void,
    user_data: ?*anyopaque,
    max_threads: c_int,
    exclusive: gboolean,
    error_ptr: *?*GError,
) ?*GThreadPool;
pub extern fn g_thread_pool_push(
    pool: *GThreadPool,
    data: ?*anyopaque,
    error_ptr: *?*GError,
) gboolean;
pub extern fn g_thread_pool_free(
    pool: *GThreadPool,
    immediate: gboolean,
    wait: gboolean,
) void;
pub extern fn g_file_new_for_path(path: [*:0]const u8) ?*GFile;
pub extern fn g_file_get_path(file: *GFile) ?[*:0]u8;
pub extern fn g_file_monitor_directory(
    file: *GFile,
    flags: c_int,
    cancellable: ?*GCancellable,
    error_ptr: *?*GError,
) ?*GFileMonitor;
pub extern fn g_file_monitor_cancel(monitor: *GFileMonitor) gboolean;
pub extern fn g_file_monitor_set_rate_limit(monitor: *GFileMonitor, limit_msecs: c_int) void;
pub extern fn g_object_set_data(object: ?*anyopaque, key: [*:0]const u8, data: ?*anyopaque) void;
pub extern fn g_object_get_data(object: ?*anyopaque, key: [*:0]const u8) ?*anyopaque;
pub extern fn g_object_unref(object: ?*anyopaque) void;
pub extern fn g_free(memory: ?*anyopaque) void;
pub extern fn g_error_free(error_ptr: *GError) void;
pub extern fn atk_object_set_name(accessible: *AtkObject, name: [*:0]const u8) void;
pub extern fn g_value_unset(value: *GValue) void;
pub extern fn g_value_get_string(value: *const GValue) ?[*:0]const u8;
pub extern fn g_value_get_boolean(value: *const GValue) gboolean;
pub extern fn g_value_get_uint64(value: *const GValue) u64;
pub extern fn g_print(format: [*:0]const u8, ...) void;

comptime {
    std.debug.assert(@sizeOf(GtkTreeIter) == @sizeOf(c_int) + 3 * @sizeOf(?*anyopaque) + 4);
}
