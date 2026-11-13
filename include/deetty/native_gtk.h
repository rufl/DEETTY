#ifndef DEETTY_NATIVE_GTK_H
#define DEETTY_NATIVE_GTK_H

#include <gtk/gtk.h>
enum DeettyGtkWidgetType {
    DEETTY_GTK_WIDGET = 0,
    DEETTY_GTK_WINDOW = 1,
    DEETTY_GTK_CONTAINER = 2,
    DEETTY_GTK_BOX = 3,
    DEETTY_GTK_PANED = 4,
    DEETTY_GTK_BUTTON = 5,
    DEETTY_GTK_MENU = 6,
    DEETTY_GTK_ENTRY = 7,
    DEETTY_GTK_EVENT_BOX = 8,
    DEETTY_GTK_IMAGE = 9,
    DEETTY_GTK_NOTEBOOK = 10,
    DEETTY_GTK_DIALOG = 11,
    DEETTY_GTK_COMBO_BOX = 12,
    DEETTY_GTK_COMBO_BOX_TEXT = 13,
    DEETTY_GTK_SPIN_BUTTON = 14,
    DEETTY_GTK_TOGGLE_BUTTON = 15,
    DEETTY_GTK_CHECK_BUTTON = 16,
    DEETTY_GTK_SCROLLED_WINDOW = 17,
    DEETTY_GTK_LABEL = 18,
    DEETTY_GTK_BIN = 19,
    DEETTY_GTK_MENU_ITEM = 20,
    DEETTY_GTK_RADIO_MENU_ITEM = 21,
};

GtkWidget *deetty_pane_info_strip_new(gboolean enabled);
void deetty_pane_info_strip_set_enabled(GtkWidget *strip, gboolean enabled);
gboolean deetty_pane_info_strip_update(GtkWidget *strip, const char *text,
                                       const char *tooltip);
const char *deetty_pane_info_strip_text(GtkWidget *strip);
const char *deetty_pane_info_strip_tooltip(GtkWidget *strip);
guint deetty_pane_info_strip_revision(GtkWidget *strip);
void deetty_configure_action_button(GtkWidget *button, const char *tooltip);
void deetty_prepare_action_button_tree(GtkWidget *widget);
void deetty_show_all_with_action_affordances(GtkWidget *widget);
gboolean deetty_grid_sync_split_visibility(
    GtkWidget *content, GtkWidget *const *panes, guint pane_count);
void deetty_apply_pane_divider_style(GtkWidget *widget, int width_px);

GtkWidget *deetty_paned_new(int orientation, int divider_px);
void deetty_paned_pack1(
    GtkWidget *paned, GtkWidget *child, gboolean resize, gboolean shrink);
void deetty_paned_pack2(
    GtkWidget *paned, GtkWidget *child, gboolean resize, gboolean shrink);
void deetty_paned_set_position(GtkWidget *paned, int position);
void deetty_container_add(GtkWidget *container, GtkWidget *child);
void deetty_container_remove(GtkWidget *container, GtkWidget *child);
void deetty_container_set_border_width(GtkWidget *container, unsigned width);
void deetty_box_pack_start(
    GtkWidget *box, GtkWidget *child,
    gboolean expand, gboolean fill, unsigned padding);
void deetty_box_pack_end(
    GtkWidget *box, GtkWidget *child,
    gboolean expand, gboolean fill, unsigned padding);
void deetty_box_reorder_child(
    GtkWidget *box, GtkWidget *child, int position);
gboolean deetty_apply_even_pane_positions(GtkWidget *widget);
void deetty_apply_pane_gap_style(GtkWidget *widget, guint32 rgb,
                                 gboolean opaque);
void deetty_install_compact_tab_styles(GtkWidget *notebook);

typedef struct {
    GtkWidget *page;
    const char *text;
    gpointer callback_data;
} DeettyCompactTabOptions;

typedef struct {
    GCallback button_press;
    GCallback button_release;
    GCallback drag_begin;
    GCallback drag_end;
    GCallback close_clicked;
} DeettyCompactTabCallbacks;

typedef struct {
    GtkWidget *tab;
    GtkWidget *label;
    GtkWidget *close_button;
} DeettyCompactTabContents;

/*
 * Returned roots keep GTK floating ownership until inserted into a container.
 * Descendant handles are borrowed. Callback data remains C-owned and must
 * outlive the corresponding widget tree.
 */
gboolean deetty_compact_tab_new(
    const DeettyCompactTabOptions *options,
    const DeettyCompactTabCallbacks *callbacks,
    DeettyCompactTabContents *contents_out);
GtkWidget *deetty_new_tab_button_new(
    int extent_px, gpointer callback_data, GCallback clicked);

typedef struct {
    GCallback settings_clicked;
    GCallback close_clicked;
} DeettyWindowToolbarCallbacks;

typedef struct {
    GtkWidget *controls;
    GtkWidget *settings;
    GtkWidget *close_button;
} DeettyWindowToolbarContents;

gboolean deetty_window_toolbar_new(
    int extent_px, gpointer callback_data,
    const DeettyWindowToolbarCallbacks *callbacks,
    DeettyWindowToolbarContents *contents_out);
void deetty_window_toolbar_set_close_visible(
    GtkWidget *close_button, gboolean visible);
GdkWindow *deetty_action_button_event_window(GtkWidget *widget);
gboolean deetty_action_button_enter(GtkWidget *widget);
gboolean deetty_action_button_leave(GtkWidget *widget);
GtkWidget *deetty_tab_label_from_widget(GtkWidget *tab_widget);
GtkWidget *deetty_tab_close_button_from_widget(GtkWidget *tab_widget);
gboolean deetty_tab_color_uses_dark_text(guint32 rgb);
void deetty_apply_tab_color_style(GtkWidget *tab_widget, guint32 rgb,
                                  gboolean is_active);
GtkWidget *deetty_settings_grid_new(void);
void deetty_settings_grid_attach_control(GtkWidget *grid, const char *text,
                                         GtkWidget *control, int row);
GtkWidget *deetty_settings_group_new(const char *title, GtkWidget *child);
GtkWidget *deetty_settings_page_new(const char *title,
                                    const char *description,
                                    GtkWidget **body_out);
GtkWidget *deetty_settings_category_row_new(const char *icon_name,
                                            const char *label_text,
                                            const char *page_name);
void deetty_settings_category_selected(GtkListBox *list, GtkListBoxRow *row,
                                       gpointer user_data);
void deetty_settings_response(GtkDialog *dialog, gint response,
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
} DeettyWorkspaceMenuCallbacks;

typedef struct {
    gpointer context;
    gpointer root;
    GtkWidget *profile_menu;
    const char *broadcast_label;
    gboolean selection_active;
    gboolean pane_close_sensitive;
} DeettyWorkspaceMenuOptions;

GtkWidget *deetty_workspace_menu_new(
    const DeettyWorkspaceMenuOptions *options,
    const DeettyWorkspaceMenuCallbacks *callbacks);

typedef struct {
    GtkWidget *menu;
    GtkWidget *open;
    GtkWidget *copy;
} DeettyHyperlinkMenuContents;

gboolean deetty_hyperlink_menu_new(
    DeettyHyperlinkMenuContents *contents_out);
GtkWidget *deetty_profile_preset_menu_new(
    const char *const *labels, guint label_count, int active,
    GCallback toggled, gpointer context);
GtkWidget *deetty_tab_color_menu_new(
    const char *const *labels, guint label_count, int active,
    GtkWidget *page, GCallback preset_toggled, GCallback adjust_activate,
    gpointer context, const char *lighter_label, const char *darker_label);
GtkWidget *deetty_tab_context_menu_new(
    GtkWidget *page, GtkWidget *tab_color_menu, gboolean close_sensitive,
    GCallback close_activate, gpointer context);

typedef struct {
    GtkWidget *entry;
    GtkWidget *status;
} DeettyFindContents;

typedef struct {
    GtkWidget *view;
    GtkWidget *status;
} DeettyQuickNoteContents;

typedef struct {
    int id;
    const char *label;
    const char *hint;
} DeettyPaletteAction;

typedef struct {
    GtkWidget *search;
    GtkWidget *list;
} DeettyPaletteContents;

gboolean deetty_terminal_find_contents_new(
    GtkWidget *dialog, int dialog_width, gboolean vertical,
    DeettyFindContents *contents_out);
gboolean deetty_quick_note_contents_new(
    GtkWidget *dialog, int dialog_width, int dialog_height,
    DeettyQuickNoteContents *contents_out);
gboolean deetty_shortcuts_contents_new(
    GtkWidget *dialog, const char *shortcuts, int dialog_width,
    int dialog_height);
gboolean deetty_command_palette_contents_new(
    GtkWidget *dialog, int dialog_width, int dialog_height,
    gboolean vertical_rows, const DeettyPaletteAction *actions,
    guint action_count, const char *visibility_hint,
    DeettyPaletteContents *contents_out);

typedef struct {
    GtkWidget *save;
    GtkWidget *open;
    GtkWidget *recent_combo;
    GtkWidget *recent_open;
    GtkWidget *editor;
    GtkWidget *summary;
    GtkWidget *summary_scroll;
} DeettyProjectContents;

gboolean deetty_project_contents_new(
    GtkWidget *dialog, const char *summary_text,
    DeettyProjectContents *contents_out);

gboolean deetty_restore_workspace_contents_new(
    GtkWidget *dialog, GtkWidget **combo_out);
GtkWidget *deetty_workspace_file_chooser_new(
    GtkWidget *parent, gboolean save);

GtkWidget *deetty_save_file_chooser_new(
    GtkWidget *parent, const char *title, const char *accept_label,
    const char *default_name);

gboolean deetty_history_password_contents_new(
    GtkWidget *dialog, GtkWidget **entry_out);
gboolean deetty_agent_resume_contents_new(
    GtkWidget *dialog, GtkWidget **provider_out,
    GtkWidget **session_out, GtkWidget **label_out);

GtkWidget *deetty_error_dialog_new(
    GtkWidget *parent, const char *title, const char *detail);

GtkWidget *deetty_dialog_new(
    GtkWidget *parent, const char *title, int flags,
    const char *cancel_label, int cancel_response,
    const char *accept_label, int accept_response);

GtkWidget *deetty_message_dialog_new(
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
} DeettySettingsCoreOptions;

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
} DeettySettingsCoreContents;

gboolean deetty_settings_core_contents_new(
    const DeettySettingsCoreOptions *options,
    DeettySettingsCoreContents *contents_out);

typedef struct {
    GtkWidget *categories;
    GtkWidget *stack;
} DeettySettingsShellContents;

gboolean deetty_settings_shell_new(
    GtkWidget *dialog, gboolean compact,
    GtkWidget *window_page, GtkWidget *behavior_page,
    GtkWidget *appearance_page, DeettySettingsShellContents *contents_out);

GtkWidget *deetty_theme_combo_new(void);
GtkWidget *deetty_color_button_new(const char *accessible_name);

GtkWidget *deetty_grid_page_new(int panel_padding, GtkWidget *pane_info_strip);
GtkWidget *deetty_grid_window_new(void);
GtkWidget *deetty_grid_notebook_new(void);
GtkIMContext *deetty_grid_input_context_new(void);
void deetty_grid_widget_class_set_accessible_type(
    gpointer widget_class, GType accessible_type);
void deetty_grid_window_configure(
    GtkWidget *window, int default_width, int default_height,
    gboolean decorated, gboolean keep_above);
void deetty_grid_window_apply_mode(
    GtkWidget *window, gboolean decorated, gboolean keep_above);
void deetty_grid_window_set_title(
    GtkWidget *window, const char *title);
void deetty_grid_window_present(GtkWidget *window);
void deetty_grid_window_set_fullscreen(
    GtkWidget *window, gboolean fullscreen);
void deetty_grid_window_set_startup_id(
    GtkWidget *window, const char *startup_id);
void deetty_grid_focus_widget(
    GtkWidget *window, GtkWidget *target);
void deetty_grid_widget_set_margins(
    GtkWidget *widget, int start, int top, int end, int bottom);
void deetty_grid_widget_queue_draw(GtkWidget *widget);
void deetty_grid_widget_queue_draw_area(
    GtkWidget *widget, int x, int y, int width, int height);
void deetty_grid_widget_queue_resize(GtkWidget *widget);
void deetty_grid_widget_show(GtkWidget *widget);
void deetty_grid_widget_hide(GtkWidget *widget);
void deetty_grid_widget_set_visible(GtkWidget *widget, gboolean visible);
void deetty_grid_widget_set_can_focus(GtkWidget *widget, gboolean can_focus);
void deetty_grid_widget_set_sensitive(GtkWidget *widget, gboolean sensitive);
void deetty_grid_widget_set_size_request(
    GtkWidget *widget, int width, int height);
void deetty_grid_widget_set_tooltip_text(
    GtkWidget *widget, const char *tooltip);
void deetty_grid_window_set_decorated(GtkWidget *window, gboolean decorated);
void deetty_grid_window_set_keep_above(GtkWidget *window, gboolean keep_above);
void deetty_grid_window_set_resizable(GtkWidget *window, gboolean resizable);
void deetty_grid_window_set_default_size(
    GtkWidget *window, int width, int height);
void deetty_grid_window_set_modal(GtkWidget *window, gboolean modal);
void deetty_grid_window_set_position(GtkWidget *window, int position);
void deetty_grid_window_set_type_hint(GtkWidget *window, int type_hint);
void deetty_grid_window_set_destroy_with_parent(
    GtkWidget *window, gboolean destroy_with_parent);
void deetty_grid_widget_add_events(GtkWidget *widget, int events);
void deetty_grid_window_set_transient_for(
    GtkWidget *window, GtkWidget *parent);
void deetty_grid_window_resize(
    GtkWidget *window, int width, int height);
void deetty_grid_window_move(
    GtkWidget *window, int x, int y);
void deetty_grid_widget_set_no_show_all(
    GtkWidget *widget, gboolean no_show_all);
void deetty_grid_widget_destroy(GtkWidget *widget);
gulong deetty_grid_signal_connect(
    gpointer instance,
    const char *signal,
    GCallback callback,
    gpointer data);
gulong deetty_grid_signal_connect_swapped(
    gpointer instance,
    const char *signal,
    GCallback callback,
    gpointer data);
gulong deetty_grid_signal_connect_object(
    gpointer instance,
    const char *signal,
    GCallback callback,
    gpointer object,
    unsigned int flags);
void deetty_grid_drag_source_set(
    GtkWidget *widget,
    unsigned int start_button_mask,
    gpointer targets,
    int target_count,
    unsigned int actions);
void deetty_grid_drag_dest_set(
    GtkWidget *widget,
    unsigned int dest_defaults,
    gpointer targets,
    int target_count,
    unsigned int actions);
void deetty_grid_widget_show_all(GtkWidget *widget);
gpointer deetty_grid_object_get_data(gpointer object, const char *key);
void deetty_grid_object_set_data(
    gpointer object, const char *key, gpointer value);
void deetty_grid_object_set_data_full(
    gpointer object, const char *key, gpointer value,
    GDestroyNotify destroy);
gpointer deetty_grid_object_ref(gpointer object);
void deetty_grid_object_unref(gpointer object);
gpointer deetty_grid_object_clear(gpointer object);
guint deetty_grid_source_idle_add(GSourceFunc function, gpointer data);
guint deetty_grid_source_timeout_add(
    guint interval, GSourceFunc function, gpointer data);
guint deetty_grid_source_timeout_add_seconds(
    guint interval, GSourceFunc function, gpointer data);
gboolean deetty_grid_source_remove(guint source_id);
gboolean deetty_grid_main_context_iteration(gboolean may_block);
void deetty_grid_memory_free(gpointer value);
gpointer deetty_grid_memory_clear(gpointer value);
void deetty_grid_error_clear(GError **error);
void deetty_grid_variant_unref(GVariant *value);
GVariant *deetty_grid_variant_clear(GVariant *value);
GVariant *deetty_grid_variant_ref(GVariant *value);
void deetty_grid_widget_set_app_paintable(
    GtkWidget *widget, gboolean app_paintable);
void deetty_grid_widget_set_visual(GtkWidget *widget, gpointer visual);
GtkWidget *deetty_grid_window_get_focus(gpointer window);
void deetty_grid_window_get_size(
    gpointer window, int *width, int *height);
void deetty_grid_window_get_position(
    gpointer window, int *x, int *y);
gboolean deetty_grid_window_is_active(gpointer window);
gboolean deetty_grid_window_get_decorated(gpointer window);
gboolean deetty_grid_widget_is_type(gpointer widget, int type);
gboolean deetty_grid_window_get_resizable(gpointer window);
GtkWindow *deetty_grid_window_get_transient_for(gpointer window);
int deetty_grid_window_get_window_type(gpointer window);
const char *deetty_grid_window_get_icon_name(gpointer window);
GdkScreen *deetty_grid_widget_get_screen(gpointer widget);
gboolean deetty_grid_widget_get_app_paintable(gpointer widget);
GtkWidget *deetty_grid_dialog_get_content_area(gpointer dialog);
GtkWidget *deetty_grid_dialog_get_widget_for_response(
    gpointer dialog, int response);
int deetty_grid_dialog_run(gpointer dialog);
void deetty_grid_dialog_response(gpointer dialog, int response);
void deetty_grid_dialog_set_default_response(
    gpointer dialog, int response);
unsigned int deetty_grid_main_level(void);
void deetty_grid_gtk_main(void);
gboolean deetty_grid_gtk_init_check(void);
void deetty_grid_main_quit(void);
gboolean deetty_grid_show_uri_on_window(
    gpointer window, const char *uri, unsigned int time,
    GError **error);
GtkWidget *deetty_grid_widget_get_parent(GtkWidget *widget);
gboolean deetty_grid_widget_get_visible(GtkWidget *widget);
gboolean deetty_grid_widget_get_mapped(GtkWidget *widget);
gboolean deetty_grid_widget_in_destruction(GtkWidget *widget);
void deetty_grid_widget_get_allocation(
    GtkWidget *widget, GtkAllocation *allocation);
GtkWidget *deetty_grid_paned_get_child1(gpointer paned);
GtkWidget *deetty_grid_paned_get_child2(gpointer paned);
int deetty_grid_paned_get_position(gpointer paned);
int deetty_grid_orientable_get_orientation(gpointer orientable);
GtkWidget *deetty_grid_bin_get_child(gpointer bin);
GList *deetty_grid_container_get_children(gpointer container);
void deetty_grid_container_forall(
    gpointer container, gpointer callback, gpointer data);
GtkWidget *deetty_grid_widget_get_toplevel(gpointer widget);
const char *deetty_grid_window_get_title(gpointer window);
GtkWidget *deetty_grid_window_get_default_widget(gpointer window);
const char *deetty_grid_label_get_text(gpointer label);
const char *deetty_grid_label_get_label(gpointer label);
char *deetty_grid_widget_get_tooltip_text(gpointer widget);
const char *deetty_grid_entry_get_text(gpointer entry);
int deetty_grid_spin_button_get_value_as_int(gpointer spin);
double deetty_grid_spin_button_get_value(gpointer spin);
gboolean deetty_grid_toggle_button_get_active(gpointer toggle);
int deetty_grid_combo_box_get_active(gpointer combo);
double deetty_grid_range_get_value(gpointer range);
int deetty_grid_widget_get_scale_factor(gpointer widget);
gboolean deetty_grid_widget_get_sensitive(gpointer widget);
void deetty_grid_label_set_text(gpointer label, const char *text);
void deetty_grid_label_set_markup(gpointer label, const char *markup);
void deetty_grid_entry_set_text(gpointer entry, const char *text);
void deetty_grid_button_set_label(gpointer button, const char *label);
GtkWidget *deetty_grid_button_new_with_label(const char *label);
const char *deetty_grid_button_get_label(gpointer button);
void deetty_grid_button_clicked(gpointer button);
void deetty_grid_combo_box_set_active(gpointer combo, int index);
gboolean deetty_grid_combo_box_set_active_id(
    gpointer combo, const char *id);
void deetty_grid_spin_button_set_value(gpointer spin, double value);
void deetty_grid_toggle_button_set_active(
    gpointer toggle, gboolean active);
void deetty_grid_range_set_value(gpointer range, double value);
const char *deetty_grid_combo_box_get_active_id(gpointer combo);
char *deetty_grid_combo_box_text_get_active_text(gpointer combo);
void deetty_grid_combo_box_text_remove_all(gpointer combo);
void deetty_grid_combo_box_text_append(
    gpointer combo, const char *id, const char *text);
void deetty_grid_combo_box_text_append_text(
    gpointer combo, const char *text);
void deetty_grid_color_chooser_set_rgb(
    gpointer widget, double red, double green, double blue);
gboolean deetty_grid_color_chooser_get_rgb(
    gpointer widget, double *red, double *green, double *blue);
int deetty_grid_widget_get_allocated_width(gpointer widget);
int deetty_grid_widget_get_allocated_height(gpointer widget);
gboolean deetty_grid_check_menu_item_get_active(gpointer item);
char *deetty_grid_file_chooser_get_filename(gpointer chooser);
GtkListBoxRow *deetty_grid_list_box_get_row_at_index(
    gpointer list, int index);
GtkListBoxRow *deetty_grid_list_box_get_selected_row(gpointer list);
void deetty_grid_list_box_select_row(
    gpointer list, GtkListBoxRow *row);
void deetty_grid_event_box_set_above_child(
    gpointer event_box, gboolean above_child);
void deetty_grid_entry_set_icon_from_icon_name(
    gpointer entry, int icon_pos, const char *icon_name);
void deetty_grid_entry_set_icon_tooltip_text(
    gpointer entry, int icon_pos, const char *tooltip);
gpointer deetty_grid_text_view_get_buffer(gpointer view);
void deetty_grid_text_buffer_get_bounds(
    gpointer buffer, gpointer start, gpointer end);
char *deetty_grid_text_buffer_get_text(
    gpointer buffer, gpointer start, gpointer end,
    gboolean include_hidden);
void deetty_grid_text_buffer_set_text(
    gpointer buffer, const char *text, int length);
gpointer deetty_grid_combo_box_get_model(gpointer combo);
int deetty_grid_tree_model_iter_n_children(
    gpointer model, gpointer parent);
GtkWidget *deetty_grid_button_get_image(gpointer button);
void deetty_grid_image_get_icon_name(
    gpointer image, const char **icon_name, GtkIconSize *icon_size);
void deetty_grid_text_view_set_editable(gpointer view, gboolean editable);
void deetty_grid_render_background(
    gpointer style, gpointer surface, double width, double height);
gboolean deetty_grid_event_get_scroll_deltas(
    gpointer event, double *delta_x, double *delta_y);
gpointer deetty_grid_button_event_new(
    gpointer window, unsigned int time, double x, double y,
    unsigned int state, unsigned int button, double x_root, double y_root);
void deetty_grid_event_set_device(gpointer event, gpointer device);
void deetty_grid_event_free(gpointer event);
void deetty_grid_gdk_window_get_origin(
    gpointer window, int *x, int *y);
gpointer deetty_grid_gdk_monitor_at_window(
    gpointer display, gpointer window);
gpointer deetty_grid_gdk_primary_monitor(gpointer display);
gboolean deetty_grid_gdk_pointer_position(
    gpointer display, int *x, int *y);
gpointer deetty_grid_gdk_monitor_at_point(
    gpointer display, int x, int y);
int deetty_grid_gdk_monitor_count(gpointer display);
gpointer deetty_grid_gdk_monitor_at_index(
    gpointer display, int index);
void deetty_grid_gdk_monitor_get_geometry(
    gpointer monitor, GdkRectangle *geometry);
void deetty_grid_gdk_monitor_get_workarea(
    gpointer monitor, GdkRectangle *workarea);
int deetty_grid_gdk_monitor_get_scale_factor(gpointer monitor);
void deetty_grid_gdk_window_set_fullscreen_mode(
    gpointer window, int mode);
void deetty_grid_gdk_window_fullscreen_on_monitor(
    gpointer window, int monitor_index);
void deetty_grid_gdk_window_fullscreen(gpointer window);
gboolean deetty_grid_gdk_set_cursor(
    gpointer window, gpointer display,
    const char *name, int fallback_cursor);
void deetty_grid_gdk_request_paint(gpointer clock, int phase);
unsigned int deetty_grid_gdk_keyval_to_unicode(unsigned int keyval);
gpointer deetty_grid_gdk_screen_get_rgba_visual(gpointer screen);
gboolean deetty_grid_gdk_screen_is_composited(gpointer screen);
gboolean deetty_grid_gdk_display_is_wayland(gpointer display);
gboolean deetty_grid_gdk_default_display_is_wayland(void);
void deetty_grid_event_set_pointer_device(
    gpointer event, gpointer display);
gpointer deetty_grid_clipboard_get(gpointer selection);
void deetty_grid_clipboard_request_text(
    gpointer clipboard,
    void (*callback)(GtkClipboard *, const gchar *, gpointer),
    gpointer data);
void deetty_grid_clipboard_set_text(
    gpointer clipboard, const char *text, int length);
void deetty_grid_im_context_focus_in(gpointer context);
void deetty_grid_im_context_set_client_window(
    gpointer context, gpointer window);
void deetty_grid_selection_data_set_text(
    gpointer selection, const char *text, int length);
char *deetty_grid_selection_data_get_text(gpointer selection);
void deetty_grid_im_context_focus_out(gpointer context);
gboolean deetty_grid_im_context_filter_keypress(
    gpointer context, gpointer event);
void deetty_grid_editable_select_region(
    gpointer editable, int start_pos, int end_pos);
gpointer deetty_grid_widget_get_accessible(gpointer widget);
gpointer deetty_grid_widget_get_style_context(gpointer widget);
void deetty_grid_style_context_add_class(
    gpointer style_context, const char *class_name);
void deetty_grid_style_context_remove_class(
    gpointer style_context, const char *class_name);
gboolean deetty_grid_style_context_has_class(
    gpointer style_context, const char *class_name);
void deetty_grid_atk_object_set_name(
    gpointer accessible, const char *name);
void deetty_grid_atk_object_set_description(
    gpointer accessible, const char *description);
void deetty_grid_atk_object_set_role(
    gpointer accessible, AtkRole role);
const char *deetty_grid_atk_object_get_name(gpointer accessible);
const char *deetty_grid_atk_object_get_description(
    gpointer accessible);
AtkRole deetty_grid_atk_object_get_role(gpointer accessible);
gboolean deetty_grid_widget_translate_coordinates(
    GtkWidget *source,
    GtkWidget *dest,
    int src_x,
    int src_y,
    int *dest_x,
    int *dest_y);
GdkWindow *deetty_grid_widget_get_window(GtkWidget *widget);
unsigned int deetty_grid_widget_add_tick_callback(
    GtkWidget *widget,
    GCallback callback,
    gpointer data,
    GDestroyNotify destroy_notify);
void deetty_grid_drag_finish(
    gpointer drag, gboolean delete_data, gboolean success, unsigned int time);
void deetty_grid_window_begin_resize_drag(
    gpointer window,
    int edge,
    int button,
    int root_x,
    int root_y,
    unsigned int time);
gboolean deetty_grid_events_pending(void);
int deetty_grid_notebook_get_n_pages(gpointer notebook);
int deetty_grid_notebook_get_current_page(gpointer notebook);
GtkWidget *deetty_grid_notebook_get_nth_page(
    gpointer notebook, int page_index);
GtkWidget *deetty_grid_notebook_get_tab_label(
    gpointer notebook, gpointer page);
gboolean deetty_grid_notebook_get_show_tabs(gpointer notebook);
GtkWidget *deetty_grid_notebook_get_action_widget(
    gpointer notebook, int pack_type);
int deetty_grid_notebook_get_tab_pos(gpointer notebook);
int deetty_grid_notebook_page_num(gpointer notebook, gpointer page);
void deetty_grid_notebook_reorder_child(
    gpointer notebook, gpointer page, int page_index);
void deetty_grid_notebook_remove_page(gpointer notebook, int page_index);
void deetty_grid_menu_popdown(gpointer menu);
const char *deetty_grid_menu_item_get_label(gpointer item);
GtkWidget *deetty_grid_menu_item_get_submenu(gpointer item);
void deetty_grid_menu_item_activate(gpointer item);
void deetty_grid_menu_shell_select_item(
    gpointer menu_shell, gpointer item);
gboolean deetty_grid_menu_shell_activate_item(
    gpointer menu_shell, gpointer item, gboolean force);
GtkWidget *deetty_grid_menu_get_attach_widget(gpointer menu);
void deetty_grid_menu_popup_at_widget(
    gpointer menu,
    GtkWidget *anchor,
    int widget_gravity,
    int menu_gravity,
    gpointer event);
void deetty_grid_menu_popup_at_rect(
    gpointer menu,
    GdkWindow *rect_window,
    const GdkRectangle *rect,
    int rect_gravity,
    int menu_gravity,
    gpointer event);
gboolean deetty_grid_widget_has_focus(gpointer widget);
GdkFrameClock *deetty_grid_widget_get_frame_clock(gpointer widget);
GdkDisplay *deetty_grid_widget_get_display(gpointer widget);
GtkWidget *deetty_grid_widget_get_ancestor(
    gpointer widget, GType widget_type);
GtkWidget *deetty_grid_grab_get_current(void);
void deetty_grid_grab_add(gpointer widget);
void deetty_grid_grab_remove(gpointer widget);
gboolean deetty_grid_widget_has_grab(gpointer widget);
void deetty_grid_widget_get_size_request(
    gpointer widget, int *width, int *height);
GList *deetty_grid_window_list_toplevels(void);
void deetty_grid_check_menu_item_set_active(
    gpointer item, gboolean active);
void deetty_grid_revealer_set_reveal_child(
    gpointer revealer, gboolean reveal);
void deetty_grid_revealer_set_transition_duration(
    gpointer revealer, unsigned int duration);
void deetty_grid_revealer_set_transition_type(
    gpointer revealer, int transition_type);
void deetty_grid_main_iteration_do(gboolean blocking);
void deetty_grid_widget_remove_tick_callback(
    GtkWidget *widget, unsigned int source);
void deetty_grid_window_set_default_icon_name(const char *name);
void deetty_grid_window_set_geometry_hints(
    GtkWidget *window, int min_width, int min_height,
    int max_width, int max_height, int hints);




typedef struct {
    GCallback delete_event;
    GCallback destroy;
    GCallback focus_out_event;
    GCallback map;
    GCallback configure_event;
    GCallback button_release_event;
} DeettyGridWindowCallbacks;

gboolean deetty_grid_window_connect_signals(
    GtkWidget *window, gpointer context,
    const DeettyGridWindowCallbacks *callbacks);

typedef struct {
    GCallback switch_page;
    GCallback drag_begin;
    GCallback drag_end;
    GCallback page_reordered;
} DeettyGridNotebookCallbacks;

gboolean deetty_grid_notebook_configure(
    GtkWidget *notebook, GtkWidget *new_tab_button,
    GtkWidget *toolbar_controls, gpointer context,
    const DeettyGridNotebookCallbacks *callbacks);
int deetty_grid_notebook_append_page(
    GtkWidget *notebook, GtkWidget *page, GtkWidget *tab_widget);
void deetty_grid_notebook_apply_policy(
    GtkWidget *notebook, GtkWidget *toolbar_controls,
    int tab_position, gboolean show_tabs);
void deetty_grid_notebook_select_page(
    GtkWidget *notebook, int page_index);







typedef struct {
    int column;
    int row;
    int width;
    int height;
} DeettyWindowResizeLayout;

GtkWidget *deetty_window_resize_layout_new(
    GtkWidget *content, GtkWidget *const *handles,
    const DeettyWindowResizeLayout *layouts, guint handle_count,
    GtkWidget **resize_grip_out);

GtkWidget *deetty_resize_handle_new(
    int index, int width, int height, const char *cursor_name);

typedef struct {
    GtkWidget *box;
    GtkWidget *label;
    GtkWidget *clear_button;
} DeettySmartFilterEmptyContents;

gboolean deetty_smart_filter_empty_contents_new(
    const char *message, DeettySmartFilterEmptyContents *contents_out);


GtkWidget *deetty_tab_rename_entry_new(
    const char *title, int width_chars, int height);

GtkWidget *deetty_recovery_notice_new(
    const char *message, int apply_response, int close_response);

GtkWidget *deetty_tag_combo_new(void);
GtkWidget *deetty_tag_hint_new(void);
GtkWidget *deetty_shortcut_recorder_label_new(gboolean plasma);
GtkWidget *deetty_settings_notifications_box_new(GtkWidget *notifications);

typedef struct {
    GtkWidget *revealer;
    GtkWidget *content_box;
} DeettyGridShellContents;

gboolean deetty_grid_shell_contents_new(
    DeettyGridShellContents *contents_out);
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
} DeettySettingsAppearanceOptions;

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
} DeettySettingsAppearanceContents;

gboolean deetty_settings_appearance_contents_new(
    const DeettySettingsAppearanceOptions *options,
    DeettySettingsAppearanceContents *contents_out);

typedef struct {
    const char *shell;
    const char *command;
    const char *cwd;
    const char *environment;
    const char *ssh_target;
    int kind;
    int scrollback;
} DeettyLaunchProfileOptions;

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
} DeettyLaunchProfileContents;

gboolean deetty_launch_profile_contents_new(
    GtkWidget *parent_body, const DeettyLaunchProfileOptions *options,
    DeettyLaunchProfileContents *contents_out);

typedef struct {
    GtkWidget *variant;
    GtkWidget *scope_tab;
    GtkWidget *apply;
    GtkWidget *status;
    GtkWidget *import_current;
    GtkWidget *import_file;
} DeettyThemeLibraryContents;

gboolean deetty_theme_library_contents_new(
    GtkWidget *dialog, GtkWidget *themes, GtkWidget *scheme,
    guint scheme_count, DeettyThemeLibraryContents *contents_out);

guint deetty_theme_library_append_noctalia_records(
    GtkWidget *scheme, const char *records, gsize length);

GtkWidget *deetty_theme_import_dialog_new(
    GtkWidget *parent, GtkWidget **variant_out);

typedef struct {
    GCallback action;
    GCallback tab_changed;
    GCallback stream_changed;
    GCallback preview_draw;
    GCallback preview_button;
    GCallback preview_key;
    GCallback preview_scroll;
} DeettySharingCallbacks;

gboolean deetty_sharing_contents_new(
    GtkWidget *dialog, int width, int height, gpointer context,
    const DeettySharingCallbacks *callbacks);

#define configure_action_button deetty_configure_action_button
#define prepare_action_button_tree deetty_prepare_action_button_tree
#define show_all_with_action_affordances deetty_show_all_with_action_affordances
#define install_compact_tab_styles deetty_install_compact_tab_styles
#define tab_label_from_widget deetty_tab_label_from_widget
#define tab_close_button_from_widget deetty_tab_close_button_from_widget
#define tab_color_uses_dark_text deetty_tab_color_uses_dark_text
#define apply_tab_color_style deetty_apply_tab_color_style
#define settings_grid_new deetty_settings_grid_new
#define settings_grid_attach_control deetty_settings_grid_attach_control
#define settings_group_new deetty_settings_group_new
#define settings_page_new deetty_settings_page_new
#define settings_category_row_new deetty_settings_category_row_new
#define on_settings_category_selected deetty_settings_category_selected
#define on_settings_response deetty_settings_response

#endif
