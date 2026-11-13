#ifndef DINTTY_NATIVE_GTK_H
#define DINTTY_NATIVE_GTK_H

#include <gtk/gtk.h>
enum DinttyGtkWidgetType {
    DINTTY_GTK_WIDGET = 0,
    DINTTY_GTK_WINDOW = 1,
    DINTTY_GTK_CONTAINER = 2,
    DINTTY_GTK_BOX = 3,
    DINTTY_GTK_PANED = 4,
    DINTTY_GTK_BUTTON = 5,
    DINTTY_GTK_MENU = 6,
    DINTTY_GTK_ENTRY = 7,
    DINTTY_GTK_EVENT_BOX = 8,
    DINTTY_GTK_IMAGE = 9,
    DINTTY_GTK_NOTEBOOK = 10,
    DINTTY_GTK_DIALOG = 11,
    DINTTY_GTK_COMBO_BOX = 12,
    DINTTY_GTK_COMBO_BOX_TEXT = 13,
    DINTTY_GTK_SPIN_BUTTON = 14,
    DINTTY_GTK_TOGGLE_BUTTON = 15,
    DINTTY_GTK_CHECK_BUTTON = 16,
    DINTTY_GTK_SCROLLED_WINDOW = 17,
    DINTTY_GTK_LABEL = 18,
    DINTTY_GTK_BIN = 19,
    DINTTY_GTK_MENU_ITEM = 20,
    DINTTY_GTK_RADIO_MENU_ITEM = 21,
};

GtkWidget *dintty_pane_info_strip_new(gboolean enabled);
void dintty_pane_info_strip_set_enabled(GtkWidget *strip, gboolean enabled);
gboolean dintty_pane_info_strip_update(GtkWidget *strip, const char *text,
                                       const char *tooltip);
const char *dintty_pane_info_strip_text(GtkWidget *strip);
const char *dintty_pane_info_strip_tooltip(GtkWidget *strip);
guint dintty_pane_info_strip_revision(GtkWidget *strip);
void dintty_configure_action_button(GtkWidget *button, const char *tooltip);
void dintty_prepare_action_button_tree(GtkWidget *widget);
void dintty_show_all_with_action_affordances(GtkWidget *widget);
gboolean dintty_grid_sync_split_visibility(
    GtkWidget *content, GtkWidget *const *panes, guint pane_count);
void dintty_apply_pane_divider_style(GtkWidget *widget, int width_px);

GtkWidget *dintty_paned_new(int orientation, int divider_px);
void dintty_paned_pack1(
    GtkWidget *paned, GtkWidget *child, gboolean resize, gboolean shrink);
void dintty_paned_pack2(
    GtkWidget *paned, GtkWidget *child, gboolean resize, gboolean shrink);
void dintty_paned_set_position(GtkWidget *paned, int position);
void dintty_container_add(GtkWidget *container, GtkWidget *child);
void dintty_container_remove(GtkWidget *container, GtkWidget *child);
void dintty_container_set_border_width(GtkWidget *container, unsigned width);
void dintty_box_pack_start(
    GtkWidget *box, GtkWidget *child,
    gboolean expand, gboolean fill, unsigned padding);
void dintty_box_pack_end(
    GtkWidget *box, GtkWidget *child,
    gboolean expand, gboolean fill, unsigned padding);
void dintty_box_reorder_child(
    GtkWidget *box, GtkWidget *child, int position);
gboolean dintty_apply_even_pane_positions(GtkWidget *widget);
void dintty_apply_pane_gap_style(GtkWidget *widget, guint32 rgb,
                                 gboolean opaque);
void dintty_install_compact_tab_styles(GtkWidget *notebook);

typedef struct {
    GtkWidget *page;
    const char *text;
    gpointer callback_data;
} DinttyCompactTabOptions;

typedef struct {
    GCallback button_press;
    GCallback button_release;
    GCallback drag_begin;
    GCallback drag_end;
    GCallback close_clicked;
} DinttyCompactTabCallbacks;

typedef struct {
    GtkWidget *tab;
    GtkWidget *label;
    GtkWidget *close_button;
} DinttyCompactTabContents;

/*
 * Returned roots keep GTK floating ownership until inserted into a container.
 * Descendant handles are borrowed. Callback data remains C-owned and must
 * outlive the corresponding widget tree.
 */
gboolean dintty_compact_tab_new(
    const DinttyCompactTabOptions *options,
    const DinttyCompactTabCallbacks *callbacks,
    DinttyCompactTabContents *contents_out);
GtkWidget *dintty_new_tab_button_new(
    int extent_px, gpointer callback_data, GCallback clicked);

typedef struct {
    GCallback settings_clicked;
    GCallback close_clicked;
} DinttyWindowToolbarCallbacks;

typedef struct {
    GtkWidget *controls;
    GtkWidget *settings;
    GtkWidget *close_button;
} DinttyWindowToolbarContents;

gboolean dintty_window_toolbar_new(
    int extent_px, gpointer callback_data,
    const DinttyWindowToolbarCallbacks *callbacks,
    DinttyWindowToolbarContents *contents_out);
void dintty_window_toolbar_set_close_visible(
    GtkWidget *close_button, gboolean visible);
GdkWindow *dintty_action_button_event_window(GtkWidget *widget);
gboolean dintty_action_button_enter(GtkWidget *widget);
gboolean dintty_action_button_leave(GtkWidget *widget);
GtkWidget *dintty_tab_label_from_widget(GtkWidget *tab_widget);
GtkWidget *dintty_tab_close_button_from_widget(GtkWidget *tab_widget);
gboolean dintty_tab_color_uses_dark_text(guint32 rgb);
void dintty_apply_tab_color_style(GtkWidget *tab_widget, guint32 rgb,
                                  gboolean is_active);
GtkWidget *dintty_settings_grid_new(void);
void dintty_settings_grid_attach_control(GtkWidget *grid, const char *text,
                                         GtkWidget *control, int row);
GtkWidget *dintty_settings_group_new(const char *title, GtkWidget *child);
GtkWidget *dintty_settings_page_new(const char *title,
                                    const char *description,
                                    GtkWidget **body_out);
GtkWidget *dintty_settings_category_row_new(const char *icon_name,
                                            const char *label_text,
                                            const char *page_name);
void dintty_settings_category_selected(GtkListBox *list, GtkListBoxRow *row,
                                       gpointer user_data);
void dintty_settings_response(GtkDialog *dialog, gint response,
                              gpointer user_data);

typedef struct {
    GCallback workspace;
    GCallback terminal;
    GCallback compact;
    GCallback tag_selected;
    GCallback tag_remove;
    GCallback smart_filter;
    GCallback broadcast;
    GCallback theme;
    GCallback command_palette;
    GCallback sharing;
    GCallback project;
    GCallback pane_close;
    GCallback settings;
    GCallback selection_done;
    GCallback destroy;
} DinttyWorkspaceMenuCallbacks;

typedef struct {
    gpointer context;
    gpointer root;
    GtkWidget *profile_menu;
    const char *broadcast_label;
    gboolean selection_active;
    gboolean pane_close_sensitive;
} DinttyWorkspaceMenuOptions;

GtkWidget *dintty_workspace_menu_new(
    const DinttyWorkspaceMenuOptions *options,
    const DinttyWorkspaceMenuCallbacks *callbacks);

typedef struct {
    GtkWidget *menu;
    GtkWidget *open;
    GtkWidget *copy;
} DinttyHyperlinkMenuContents;

gboolean dintty_hyperlink_menu_new(
    DinttyHyperlinkMenuContents *contents_out);
GtkWidget *dintty_profile_preset_menu_new(
    const char *const *labels, guint label_count, int active,
    GCallback toggled, gpointer context);
GtkWidget *dintty_tab_color_menu_new(
    const char *const *labels, guint label_count, int active,
    GtkWidget *page, GCallback preset_toggled, GCallback adjust_activate,
    gpointer context, const char *lighter_label, const char *darker_label);
GtkWidget *dintty_tab_context_menu_new(
    GtkWidget *page, GtkWidget *tab_color_menu, gboolean close_sensitive,
    GCallback close_activate, gpointer context);

typedef struct {
    GtkWidget *entry;
    GtkWidget *status;
} DinttyFindContents;

typedef struct {
    GtkWidget *view;
    GtkWidget *status;
} DinttyQuickNoteContents;

typedef struct {
    int id;
    const char *label;
    const char *hint;
} DinttyPaletteAction;

typedef struct {
    GtkWidget *search;
    GtkWidget *list;
} DinttyPaletteContents;

gboolean dintty_terminal_find_contents_new(
    GtkWidget *dialog, int dialog_width, gboolean vertical,
    DinttyFindContents *contents_out);
gboolean dintty_quick_note_contents_new(
    GtkWidget *dialog, int dialog_width, int dialog_height,
    DinttyQuickNoteContents *contents_out);
gboolean dintty_shortcuts_contents_new(
    GtkWidget *dialog, const char *shortcuts, int dialog_width,
    int dialog_height);
gboolean dintty_command_palette_contents_new(
    GtkWidget *dialog, int dialog_width, int dialog_height,
    gboolean vertical_rows, const DinttyPaletteAction *actions,
    guint action_count, const char *visibility_hint,
    DinttyPaletteContents *contents_out);

typedef struct {
    GtkWidget *save;
    GtkWidget *open;
    GtkWidget *recent_combo;
    GtkWidget *recent_open;
    GtkWidget *editor;
    GtkWidget *summary;
    GtkWidget *summary_scroll;
} DinttyProjectContents;

gboolean dintty_project_contents_new(
    GtkWidget *dialog, const char *summary_text,
    DinttyProjectContents *contents_out);

gboolean dintty_restore_workspace_contents_new(
    GtkWidget *dialog, GtkWidget **combo_out);
GtkWidget *dintty_workspace_file_chooser_new(
    GtkWidget *parent, gboolean save);

GtkWidget *dintty_save_file_chooser_new(
    GtkWidget *parent, const char *title, const char *accept_label,
    const char *default_name);

gboolean dintty_history_password_contents_new(
    GtkWidget *dialog, GtkWidget **entry_out);
gboolean dintty_agent_resume_contents_new(
    GtkWidget *dialog, GtkWidget **provider_out,
    GtkWidget **session_out, GtkWidget **label_out);

GtkWidget *dintty_error_dialog_new(
    GtkWidget *parent, const char *title, const char *detail);

GtkWidget *dintty_dialog_new(
    GtkWidget *parent, const char *title, int flags,
    const char *cancel_label, int cancel_response,
    const char *accept_label, int accept_response);

GtkWidget *dintty_message_dialog_new(
    GtkWidget *parent, int message_type, const char *primary,
    const char *detail, const char *cancel_label,
    const char *accept_label);

typedef struct {
    GtkWidget *shortcut;
    int mode;
    int dropdown_width;
    int dropdown_height;
    int animation_ms;
    gboolean hide_focus;
    gboolean focus_pointer;
    gboolean notifications;
    int preset;
    int scrollback;
    int scroll_lines;
    gboolean smooth_scroll;
    gboolean compact;
} DinttySettingsCoreOptions;

typedef struct {
    GtkWidget *window_page;
    GtkWidget *behavior_page;
    GtkWidget *behavior_body;
    GtkWidget *mode;
    GtkWidget *dropdown_width;
    GtkWidget *dropdown_height;
    GtkWidget *animation;
    GtkWidget *hide_focus;
    GtkWidget *focus_pointer;
    GtkWidget *notifications;
    GtkWidget *preset;
    GtkWidget *scrollback;
    GtkWidget *scroll_lines;
    GtkWidget *smooth_scroll;
} DinttySettingsCoreContents;

gboolean dintty_settings_core_contents_new(
    const DinttySettingsCoreOptions *options,
    DinttySettingsCoreContents *contents_out);

typedef struct {
    GtkWidget *categories;
    GtkWidget *stack;
} DinttySettingsShellContents;

gboolean dintty_settings_shell_new(
    GtkWidget *dialog, gboolean compact,
    GtkWidget *window_page, GtkWidget *behavior_page,
    GtkWidget *appearance_page, DinttySettingsShellContents *contents_out);

GtkWidget *dintty_theme_combo_new(void);
GtkWidget *dintty_color_button_new(const char *accessible_name);

GtkWidget *dintty_grid_page_new(int panel_padding, GtkWidget *pane_info_strip);
GtkWidget *dintty_grid_window_new(void);
GtkWidget *dintty_grid_notebook_new(void);
GtkIMContext *dintty_grid_input_context_new(void);
void dintty_grid_widget_class_set_accessible_type(
    gpointer widget_class, GType accessible_type);
void dintty_grid_window_configure(
    GtkWidget *window, int default_width, int default_height,
    gboolean decorated, gboolean keep_above);
void dintty_grid_window_apply_mode(
    GtkWidget *window, gboolean decorated, gboolean keep_above);
void dintty_grid_window_set_title(
    GtkWidget *window, const char *title);
void dintty_grid_window_present(GtkWidget *window);
void dintty_grid_window_set_fullscreen(
    GtkWidget *window, gboolean fullscreen);
void dintty_grid_window_set_startup_id(
    GtkWidget *window, const char *startup_id);
void dintty_grid_focus_widget(
    GtkWidget *window, GtkWidget *target);
void dintty_grid_widget_set_margins(
    GtkWidget *widget, int start, int top, int end, int bottom);
void dintty_grid_widget_queue_draw(GtkWidget *widget);
void dintty_grid_widget_queue_draw_area(
    GtkWidget *widget, int x, int y, int width, int height);
void dintty_grid_widget_queue_resize(GtkWidget *widget);
void dintty_grid_widget_show(GtkWidget *widget);
void dintty_grid_widget_hide(GtkWidget *widget);
void dintty_grid_widget_set_visible(GtkWidget *widget, gboolean visible);
void dintty_grid_widget_set_can_focus(GtkWidget *widget, gboolean can_focus);
void dintty_grid_widget_set_sensitive(GtkWidget *widget, gboolean sensitive);
void dintty_grid_widget_set_size_request(
    GtkWidget *widget, int width, int height);
void dintty_grid_widget_set_tooltip_text(
    GtkWidget *widget, const char *tooltip);
void dintty_grid_window_set_decorated(GtkWidget *window, gboolean decorated);
void dintty_grid_window_set_keep_above(GtkWidget *window, gboolean keep_above);
void dintty_grid_window_set_resizable(GtkWidget *window, gboolean resizable);
void dintty_grid_window_set_default_size(
    GtkWidget *window, int width, int height);
void dintty_grid_window_set_modal(GtkWidget *window, gboolean modal);
void dintty_grid_window_set_position(GtkWidget *window, int position);
void dintty_grid_window_set_type_hint(GtkWidget *window, int type_hint);
void dintty_grid_window_set_destroy_with_parent(
    GtkWidget *window, gboolean destroy_with_parent);
void dintty_grid_widget_add_events(GtkWidget *widget, int events);
void dintty_grid_window_set_transient_for(
    GtkWidget *window, GtkWidget *parent);
void dintty_grid_window_resize(
    GtkWidget *window, int width, int height);
void dintty_grid_window_move(
    GtkWidget *window, int x, int y);
void dintty_grid_widget_set_no_show_all(
    GtkWidget *widget, gboolean no_show_all);
void dintty_grid_widget_destroy(GtkWidget *widget);
gulong dintty_grid_signal_connect(
    gpointer instance,
    const char *signal,
    GCallback callback,
    gpointer data);
gulong dintty_grid_signal_connect_swapped(
    gpointer instance,
    const char *signal,
    GCallback callback,
    gpointer data);
gulong dintty_grid_signal_connect_object(
    gpointer instance,
    const char *signal,
    GCallback callback,
    gpointer object,
    unsigned int flags);
void dintty_grid_drag_source_set(
    GtkWidget *widget,
    unsigned int start_button_mask,
    gpointer targets,
    int target_count,
    unsigned int actions);
void dintty_grid_drag_dest_set(
    GtkWidget *widget,
    unsigned int dest_defaults,
    gpointer targets,
    int target_count,
    unsigned int actions);
void dintty_grid_widget_show_all(GtkWidget *widget);
gpointer dintty_grid_object_get_data(gpointer object, const char *key);
void dintty_grid_object_set_data(
    gpointer object, const char *key, gpointer value);
void dintty_grid_object_set_data_full(
    gpointer object, const char *key, gpointer value,
    GDestroyNotify destroy);
gpointer dintty_grid_object_ref(gpointer object);
void dintty_grid_object_unref(gpointer object);
gpointer dintty_grid_object_clear(gpointer object);
guint dintty_grid_source_idle_add(GSourceFunc function, gpointer data);
guint dintty_grid_source_timeout_add(
    guint interval, GSourceFunc function, gpointer data);
guint dintty_grid_source_timeout_add_seconds(
    guint interval, GSourceFunc function, gpointer data);
gboolean dintty_grid_source_remove(guint source_id);
gboolean dintty_grid_main_context_iteration(gboolean may_block);
void dintty_grid_memory_free(gpointer value);
gpointer dintty_grid_memory_clear(gpointer value);
void dintty_grid_error_clear(GError **error);
void dintty_grid_variant_unref(GVariant *value);
GVariant *dintty_grid_variant_clear(GVariant *value);
GVariant *dintty_grid_variant_ref(GVariant *value);
void dintty_grid_widget_set_app_paintable(
    GtkWidget *widget, gboolean app_paintable);
void dintty_grid_widget_set_visual(GtkWidget *widget, gpointer visual);
GtkWidget *dintty_grid_window_get_focus(gpointer window);
void dintty_grid_window_get_size(
    gpointer window, int *width, int *height);
void dintty_grid_window_get_position(
    gpointer window, int *x, int *y);
gboolean dintty_grid_window_is_active(gpointer window);
gboolean dintty_grid_window_get_decorated(gpointer window);
gboolean dintty_grid_widget_is_type(gpointer widget, int type);
gboolean dintty_grid_window_get_resizable(gpointer window);
GtkWindow *dintty_grid_window_get_transient_for(gpointer window);
int dintty_grid_window_get_window_type(gpointer window);
const char *dintty_grid_window_get_icon_name(gpointer window);
GdkScreen *dintty_grid_widget_get_screen(gpointer widget);
gboolean dintty_grid_widget_get_app_paintable(gpointer widget);
GtkWidget *dintty_grid_dialog_get_content_area(gpointer dialog);
GtkWidget *dintty_grid_dialog_get_widget_for_response(
    gpointer dialog, int response);
int dintty_grid_dialog_run(gpointer dialog);
void dintty_grid_dialog_response(gpointer dialog, int response);
void dintty_grid_dialog_set_default_response(
    gpointer dialog, int response);
unsigned int dintty_grid_main_level(void);
void dintty_grid_gtk_main(void);
gboolean dintty_grid_gtk_init_check(void);
void dintty_grid_main_quit(void);
gboolean dintty_grid_show_uri_on_window(
    gpointer window, const char *uri, unsigned int time,
    GError **error);
GtkWidget *dintty_grid_widget_get_parent(GtkWidget *widget);
gboolean dintty_grid_widget_get_visible(GtkWidget *widget);
gboolean dintty_grid_widget_get_mapped(GtkWidget *widget);
gboolean dintty_grid_widget_in_destruction(GtkWidget *widget);
void dintty_grid_widget_get_allocation(
    GtkWidget *widget, GtkAllocation *allocation);
GtkWidget *dintty_grid_paned_get_child1(gpointer paned);
GtkWidget *dintty_grid_paned_get_child2(gpointer paned);
int dintty_grid_paned_get_position(gpointer paned);
int dintty_grid_orientable_get_orientation(gpointer orientable);
GtkWidget *dintty_grid_bin_get_child(gpointer bin);
GList *dintty_grid_container_get_children(gpointer container);
void dintty_grid_container_forall(
    gpointer container, gpointer callback, gpointer data);
GtkWidget *dintty_grid_widget_get_toplevel(gpointer widget);
const char *dintty_grid_window_get_title(gpointer window);
GtkWidget *dintty_grid_window_get_default_widget(gpointer window);
const char *dintty_grid_label_get_text(gpointer label);
const char *dintty_grid_label_get_label(gpointer label);
char *dintty_grid_widget_get_tooltip_text(gpointer widget);
const char *dintty_grid_entry_get_text(gpointer entry);
int dintty_grid_spin_button_get_value_as_int(gpointer spin);
double dintty_grid_spin_button_get_value(gpointer spin);
gboolean dintty_grid_toggle_button_get_active(gpointer toggle);
int dintty_grid_combo_box_get_active(gpointer combo);
double dintty_grid_range_get_value(gpointer range);
int dintty_grid_widget_get_scale_factor(gpointer widget);
gboolean dintty_grid_widget_get_sensitive(gpointer widget);
void dintty_grid_label_set_text(gpointer label, const char *text);
void dintty_grid_label_set_markup(gpointer label, const char *markup);
void dintty_grid_entry_set_text(gpointer entry, const char *text);
void dintty_grid_button_set_label(gpointer button, const char *label);
GtkWidget *dintty_grid_button_new_with_label(const char *label);
const char *dintty_grid_button_get_label(gpointer button);
void dintty_grid_button_clicked(gpointer button);
void dintty_grid_combo_box_set_active(gpointer combo, int index);
gboolean dintty_grid_combo_box_set_active_id(
    gpointer combo, const char *id);
void dintty_grid_spin_button_set_value(gpointer spin, double value);
void dintty_grid_toggle_button_set_active(
    gpointer toggle, gboolean active);
void dintty_grid_range_set_value(gpointer range, double value);
const char *dintty_grid_combo_box_get_active_id(gpointer combo);
char *dintty_grid_combo_box_text_get_active_text(gpointer combo);
void dintty_grid_combo_box_text_remove_all(gpointer combo);
void dintty_grid_combo_box_text_append(
    gpointer combo, const char *id, const char *text);
void dintty_grid_combo_box_text_append_text(
    gpointer combo, const char *text);
void dintty_grid_color_chooser_set_rgb(
    gpointer widget, double red, double green, double blue);
gboolean dintty_grid_color_chooser_get_rgb(
    gpointer widget, double *red, double *green, double *blue);
int dintty_grid_widget_get_allocated_width(gpointer widget);
int dintty_grid_widget_get_allocated_height(gpointer widget);
gboolean dintty_grid_check_menu_item_get_active(gpointer item);
char *dintty_grid_file_chooser_get_filename(gpointer chooser);
GtkListBoxRow *dintty_grid_list_box_get_row_at_index(
    gpointer list, int index);
GtkListBoxRow *dintty_grid_list_box_get_selected_row(gpointer list);
void dintty_grid_list_box_select_row(
    gpointer list, GtkListBoxRow *row);
void dintty_grid_event_box_set_above_child(
    gpointer event_box, gboolean above_child);
void dintty_grid_entry_set_icon_from_icon_name(
    gpointer entry, int icon_pos, const char *icon_name);
void dintty_grid_entry_set_icon_tooltip_text(
    gpointer entry, int icon_pos, const char *tooltip);
gpointer dintty_grid_text_view_get_buffer(gpointer view);
void dintty_grid_text_buffer_get_bounds(
    gpointer buffer, gpointer start, gpointer end);
char *dintty_grid_text_buffer_get_text(
    gpointer buffer, gpointer start, gpointer end,
    gboolean include_hidden);
void dintty_grid_text_buffer_set_text(
    gpointer buffer, const char *text, int length);
gpointer dintty_grid_combo_box_get_model(gpointer combo);
int dintty_grid_tree_model_iter_n_children(
    gpointer model, gpointer parent);
GtkWidget *dintty_grid_button_get_image(gpointer button);
void dintty_grid_image_get_icon_name(
    gpointer image, const char **icon_name, GtkIconSize *icon_size);
void dintty_grid_text_view_set_editable(gpointer view, gboolean editable);
void dintty_grid_render_background(
    gpointer style, gpointer surface, double width, double height);
gboolean dintty_grid_event_get_scroll_deltas(
    gpointer event, double *delta_x, double *delta_y);
gpointer dintty_grid_button_event_new(
    gpointer window, unsigned int time, double x, double y,
    unsigned int state, unsigned int button, double x_root, double y_root);
void dintty_grid_event_set_device(gpointer event, gpointer device);
void dintty_grid_event_free(gpointer event);
void dintty_grid_gdk_window_get_origin(
    gpointer window, int *x, int *y);
gpointer dintty_grid_gdk_monitor_at_window(
    gpointer display, gpointer window);
gpointer dintty_grid_gdk_primary_monitor(gpointer display);
gboolean dintty_grid_gdk_pointer_position(
    gpointer display, int *x, int *y);
gpointer dintty_grid_gdk_monitor_at_point(
    gpointer display, int x, int y);
int dintty_grid_gdk_monitor_count(gpointer display);
gpointer dintty_grid_gdk_monitor_at_index(
    gpointer display, int index);
void dintty_grid_gdk_monitor_get_geometry(
    gpointer monitor, GdkRectangle *geometry);
void dintty_grid_gdk_monitor_get_workarea(
    gpointer monitor, GdkRectangle *workarea);
int dintty_grid_gdk_monitor_get_scale_factor(gpointer monitor);
void dintty_grid_gdk_window_set_fullscreen_mode(
    gpointer window, int mode);
void dintty_grid_gdk_window_fullscreen_on_monitor(
    gpointer window, int monitor_index);
void dintty_grid_gdk_window_fullscreen(gpointer window);
gboolean dintty_grid_gdk_set_cursor(
    gpointer window, gpointer display,
    const char *name, int fallback_cursor);
void dintty_grid_gdk_request_paint(gpointer clock, int phase);
unsigned int dintty_grid_gdk_keyval_to_unicode(unsigned int keyval);
gpointer dintty_grid_gdk_screen_get_rgba_visual(gpointer screen);
gboolean dintty_grid_gdk_screen_is_composited(gpointer screen);
gboolean dintty_grid_gdk_display_is_wayland(gpointer display);
gboolean dintty_grid_gdk_default_display_is_wayland(void);
void dintty_grid_event_set_pointer_device(
    gpointer event, gpointer display);
gpointer dintty_grid_clipboard_get(gpointer selection);
void dintty_grid_clipboard_request_text(
    gpointer clipboard,
    void (*callback)(GtkClipboard *, const gchar *, gpointer),
    gpointer data);
void dintty_grid_clipboard_set_text(
    gpointer clipboard, const char *text, int length);
void dintty_grid_im_context_focus_in(gpointer context);
void dintty_grid_im_context_set_client_window(
    gpointer context, gpointer window);
void dintty_grid_selection_data_set_text(
    gpointer selection, const char *text, int length);
char *dintty_grid_selection_data_get_text(gpointer selection);
void dintty_grid_im_context_focus_out(gpointer context);
gboolean dintty_grid_im_context_filter_keypress(
    gpointer context, gpointer event);
void dintty_grid_editable_select_region(
    gpointer editable, int start_pos, int end_pos);
gpointer dintty_grid_widget_get_accessible(gpointer widget);
gpointer dintty_grid_widget_get_style_context(gpointer widget);
void dintty_grid_style_context_add_class(
    gpointer style_context, const char *class_name);
void dintty_grid_style_context_remove_class(
    gpointer style_context, const char *class_name);
gboolean dintty_grid_style_context_has_class(
    gpointer style_context, const char *class_name);
void dintty_grid_atk_object_set_name(
    gpointer accessible, const char *name);
void dintty_grid_atk_object_set_description(
    gpointer accessible, const char *description);
void dintty_grid_atk_object_set_role(
    gpointer accessible, AtkRole role);
const char *dintty_grid_atk_object_get_name(gpointer accessible);
const char *dintty_grid_atk_object_get_description(
    gpointer accessible);
AtkRole dintty_grid_atk_object_get_role(gpointer accessible);
gboolean dintty_grid_widget_translate_coordinates(
    GtkWidget *source,
    GtkWidget *dest,
    int src_x,
    int src_y,
    int *dest_x,
    int *dest_y);
GdkWindow *dintty_grid_widget_get_window(GtkWidget *widget);
unsigned int dintty_grid_widget_add_tick_callback(
    GtkWidget *widget,
    GCallback callback,
    gpointer data,
    GDestroyNotify destroy_notify);
void dintty_grid_drag_finish(
    gpointer drag, gboolean delete_data, gboolean success, unsigned int time);
void dintty_grid_window_begin_resize_drag(
    gpointer window,
    int edge,
    int button,
    int root_x,
    int root_y,
    unsigned int time);
gboolean dintty_grid_events_pending(void);
int dintty_grid_notebook_get_n_pages(gpointer notebook);
int dintty_grid_notebook_get_current_page(gpointer notebook);
GtkWidget *dintty_grid_notebook_get_nth_page(
    gpointer notebook, int page_index);
GtkWidget *dintty_grid_notebook_get_tab_label(
    gpointer notebook, gpointer page);
gboolean dintty_grid_notebook_get_show_tabs(gpointer notebook);
GtkWidget *dintty_grid_notebook_get_action_widget(
    gpointer notebook, int pack_type);
int dintty_grid_notebook_get_tab_pos(gpointer notebook);
int dintty_grid_notebook_page_num(gpointer notebook, gpointer page);
void dintty_grid_notebook_reorder_child(
    gpointer notebook, gpointer page, int page_index);
void dintty_grid_notebook_remove_page(gpointer notebook, int page_index);
void dintty_grid_menu_popdown(gpointer menu);
const char *dintty_grid_menu_item_get_label(gpointer item);
GtkWidget *dintty_grid_menu_item_get_submenu(gpointer item);
void dintty_grid_menu_item_activate(gpointer item);
void dintty_grid_menu_shell_select_item(
    gpointer menu_shell, gpointer item);
gboolean dintty_grid_menu_shell_activate_item(
    gpointer menu_shell, gpointer item, gboolean force);
GtkWidget *dintty_grid_menu_get_attach_widget(gpointer menu);
void dintty_grid_menu_popup_at_widget(
    gpointer menu,
    GtkWidget *anchor,
    int widget_gravity,
    int menu_gravity,
    gpointer event);
void dintty_grid_menu_popup_at_rect(
    gpointer menu,
    GdkWindow *rect_window,
    const GdkRectangle *rect,
    int rect_gravity,
    int menu_gravity,
    gpointer event);
gboolean dintty_grid_widget_has_focus(gpointer widget);
GdkFrameClock *dintty_grid_widget_get_frame_clock(gpointer widget);
GdkDisplay *dintty_grid_widget_get_display(gpointer widget);
GtkWidget *dintty_grid_widget_get_ancestor(
    gpointer widget, GType widget_type);
GtkWidget *dintty_grid_grab_get_current(void);
void dintty_grid_grab_add(gpointer widget);
void dintty_grid_grab_remove(gpointer widget);
gboolean dintty_grid_widget_has_grab(gpointer widget);
void dintty_grid_widget_get_size_request(
    gpointer widget, int *width, int *height);
GList *dintty_grid_window_list_toplevels(void);
void dintty_grid_check_menu_item_set_active(
    gpointer item, gboolean active);
void dintty_grid_revealer_set_reveal_child(
    gpointer revealer, gboolean reveal);
void dintty_grid_revealer_set_transition_duration(
    gpointer revealer, unsigned int duration);
void dintty_grid_revealer_set_transition_type(
    gpointer revealer, int transition_type);
void dintty_grid_main_iteration_do(gboolean blocking);
void dintty_grid_widget_remove_tick_callback(
    GtkWidget *widget, unsigned int source);
void dintty_grid_window_set_default_icon_name(const char *name);
void dintty_grid_window_set_geometry_hints(
    GtkWidget *window, int min_width, int min_height,
    int max_width, int max_height, int hints);




typedef struct {
    GCallback delete_event;
    GCallback destroy;
    GCallback focus_out_event;
    GCallback map;
    GCallback configure_event;
    GCallback button_release_event;
} DinttyGridWindowCallbacks;

gboolean dintty_grid_window_connect_signals(
    GtkWidget *window, gpointer context,
    const DinttyGridWindowCallbacks *callbacks);

typedef struct {
    GCallback switch_page;
    GCallback drag_begin;
    GCallback drag_end;
    GCallback page_reordered;
} DinttyGridNotebookCallbacks;

gboolean dintty_grid_notebook_configure(
    GtkWidget *notebook, GtkWidget *new_tab_button,
    GtkWidget *toolbar_controls, gpointer context,
    const DinttyGridNotebookCallbacks *callbacks);
int dintty_grid_notebook_append_page(
    GtkWidget *notebook, GtkWidget *page, GtkWidget *tab_widget);
void dintty_grid_notebook_apply_policy(
    GtkWidget *notebook, GtkWidget *toolbar_controls,
    int tab_position, gboolean show_tabs);
void dintty_grid_notebook_select_page(
    GtkWidget *notebook, int page_index);







typedef struct {
    int column;
    int row;
    int width;
    int height;
} DinttyWindowResizeLayout;

GtkWidget *dintty_window_resize_layout_new(
    GtkWidget *content, GtkWidget *const *handles,
    const DinttyWindowResizeLayout *layouts, guint handle_count,
    GtkWidget **resize_grip_out);

GtkWidget *dintty_resize_handle_new(
    int index, int width, int height, const char *cursor_name);

typedef struct {
    GtkWidget *box;
    GtkWidget *label;
    GtkWidget *clear_button;
} DinttySmartFilterEmptyContents;

gboolean dintty_smart_filter_empty_contents_new(
    const char *message, DinttySmartFilterEmptyContents *contents_out);


GtkWidget *dintty_tab_rename_entry_new(
    const char *title, int width_chars, int height);

GtkWidget *dintty_recovery_notice_new(
    const char *message, int apply_response, int close_response);

GtkWidget *dintty_tag_combo_new(void);
GtkWidget *dintty_tag_hint_new(void);
GtkWidget *dintty_shortcut_recorder_label_new(gboolean plasma);
GtkWidget *dintty_settings_notifications_box_new(GtkWidget *notifications);

typedef struct {
    GtkWidget *revealer;
    GtkWidget *content_box;
} DinttyGridShellContents;

gboolean dintty_grid_shell_contents_new(
    DinttyGridShellContents *contents_out);
typedef struct {
    GtkWidget *theme;
    GtkWidget *background_tint;
    GtkWidget *const *color_buttons;
    guint color_count;
    int tab_position;
    int panel_padding;
    int pane_spacing;
    gboolean pane_gaps_enabled;
    gboolean pane_gaps_transparent;
    gboolean inactive_pane_dim_enabled;
    int inactive_pane_brightness_percent;
    int pane_divider;
    int pane_border;
    int focused_border;
    int selected_border;
    int status_border;
    int overlay_border;
    int window_border;
    int dragger;
    gboolean show_pane_info;
    int family;
    double font_min;
    double font_max;
    double font_size;
    int antialias;
    int hinting;
    int renderer_backend;
    gboolean translucency;
    gboolean alpha_supported;
    double opacity_percent;
    gboolean compact;
} DinttySettingsAppearanceOptions;

typedef struct {
    GtkWidget *page;
    GtkWidget *tabs;
    GtkWidget *status;
    GtkWidget *padding;
    GtkWidget *spacing;
    GtkWidget *pane_gaps_enabled;
    GtkWidget *pane_gaps_transparent;
    GtkWidget *inactive_pane_dim_enabled;
    GtkWidget *inactive_pane_brightness;
    GtkWidget *theme_scope_tab;
    GtkWidget *divider;
    GtkWidget *pane_border;
    GtkWidget *focused_border;
    GtkWidget *selected_border;
    GtkWidget *status_border;
    GtkWidget *overlay_border;
    GtkWidget *window_border;
    GtkWidget *dragger;
    GtkWidget *pane_info;
    GtkWidget *theme_library;
    GtkWidget *family;
    GtkWidget *font;
    GtkWidget *antialias;
    GtkWidget *hinting;
    GtkWidget *renderer;
    GtkWidget *translucency;
    GtkWidget *opacity;
    GtkWidget *transparency_status;
} DinttySettingsAppearanceContents;

gboolean dintty_settings_appearance_contents_new(
    const DinttySettingsAppearanceOptions *options,
    DinttySettingsAppearanceContents *contents_out);

typedef struct {
    const char *shell;
    const char *command;
    const char *cwd;
    const char *environment;
    const char *ssh_target;
    int kind;
    int scrollback;
} DinttyLaunchProfileOptions;

typedef struct {
    GtkWidget *library;
    GtkWidget *name;
    GtkWidget *kind;
    GtkWidget *shell;
    GtkWidget *command;
    GtkWidget *cwd;
    GtkWidget *environment;
    GtkWidget *ssh_target;
    GtkWidget *scrollback;
    GtkWidget *apply;
    GtkWidget *save;
    GtkWidget *delete_button;
    GtkWidget *status;
} DinttyLaunchProfileContents;

gboolean dintty_launch_profile_contents_new(
    GtkWidget *parent_body, const DinttyLaunchProfileOptions *options,
    DinttyLaunchProfileContents *contents_out);

typedef struct {
    GtkWidget *variant;
    GtkWidget *scope_tab;
    GtkWidget *apply;
    GtkWidget *status;
    GtkWidget *import_current;
    GtkWidget *import_file;
} DinttyThemeLibraryContents;

gboolean dintty_theme_library_contents_new(
    GtkWidget *dialog, GtkWidget *themes, GtkWidget *scheme,
    guint scheme_count, DinttyThemeLibraryContents *contents_out);

guint dintty_theme_library_append_noctalia_records(
    GtkWidget *scheme, const char *records, gsize length);

GtkWidget *dintty_theme_import_dialog_new(
    GtkWidget *parent, GtkWidget **variant_out);

typedef struct {
    GCallback action;
    GCallback tab_changed;
    GCallback stream_changed;
    GCallback preview_draw;
    GCallback preview_button;
    GCallback preview_key;
    GCallback preview_scroll;
} DinttySharingCallbacks;

gboolean dintty_sharing_contents_new(
    GtkWidget *dialog, int width, int height, gpointer context,
    const DinttySharingCallbacks *callbacks);

#define configure_action_button dintty_configure_action_button
#define prepare_action_button_tree dintty_prepare_action_button_tree
#define show_all_with_action_affordances dintty_show_all_with_action_affordances
#define install_compact_tab_styles dintty_install_compact_tab_styles
#define tab_label_from_widget dintty_tab_label_from_widget
#define tab_close_button_from_widget dintty_tab_close_button_from_widget
#define tab_color_uses_dark_text dintty_tab_color_uses_dark_text
#define apply_tab_color_style dintty_apply_tab_color_style
#define settings_grid_new dintty_settings_grid_new
#define settings_grid_attach_control dintty_settings_grid_attach_control
#define settings_group_new dintty_settings_group_new
#define settings_page_new dintty_settings_page_new
#define settings_category_row_new dintty_settings_category_row_new
#define on_settings_category_selected dintty_settings_category_selected
#define on_settings_response dintty_settings_response

#endif
