#ifndef NOCTTY_NATIVE_GTK_H
#define NOCTTY_NATIVE_GTK_H

#include <gtk/gtk.h>

GtkWidget *noctty_pane_info_strip_new(gboolean enabled);
void noctty_pane_info_strip_set_enabled(GtkWidget *strip, gboolean enabled);
gboolean noctty_pane_info_strip_update(GtkWidget *strip, const char *text,
                                       const char *tooltip);
const char *noctty_pane_info_strip_text(GtkWidget *strip);
const char *noctty_pane_info_strip_tooltip(GtkWidget *strip);
guint noctty_pane_info_strip_revision(GtkWidget *strip);
void noctty_configure_action_button(GtkWidget *button, const char *tooltip);
void noctty_prepare_action_button_tree(GtkWidget *widget);
void noctty_show_all_with_action_affordances(GtkWidget *widget);
gboolean noctty_grid_sync_split_visibility(
    GtkWidget *content, GtkWidget *const *panes, guint pane_count);
void noctty_apply_pane_divider_style(GtkWidget *widget, int width_px);

GtkWidget *noctty_paned_new(int orientation, int divider_px);
void noctty_paned_pack1(
    GtkWidget *paned, GtkWidget *child, gboolean resize, gboolean shrink);
void noctty_paned_pack2(
    GtkWidget *paned, GtkWidget *child, gboolean resize, gboolean shrink);
void noctty_paned_set_position(GtkWidget *paned, int position);
void noctty_container_add(GtkWidget *container, GtkWidget *child);
void noctty_container_remove(GtkWidget *container, GtkWidget *child);
void noctty_container_set_border_width(GtkWidget *container, unsigned width);
void noctty_box_pack_start(
    GtkWidget *box, GtkWidget *child,
    gboolean expand, gboolean fill, unsigned padding);
void noctty_box_pack_end(
    GtkWidget *box, GtkWidget *child,
    gboolean expand, gboolean fill, unsigned padding);
void noctty_box_reorder_child(
    GtkWidget *box, GtkWidget *child, int position);
gboolean noctty_apply_even_pane_positions(GtkWidget *widget);
void noctty_apply_pane_gap_style(GtkWidget *widget, guint32 rgb,
                                 gboolean opaque);
void noctty_install_compact_tab_styles(GtkWidget *notebook);

typedef struct {
    GtkWidget *page;
    const char *text;
    gpointer callback_data;
} NocttyCompactTabOptions;

typedef struct {
    GCallback button_press;
    GCallback button_release;
    GCallback drag_begin;
    GCallback drag_end;
    GCallback close_clicked;
} NocttyCompactTabCallbacks;

typedef struct {
    GtkWidget *tab;
    GtkWidget *label;
    GtkWidget *close_button;
} NocttyCompactTabContents;

/*
 * Returned roots keep GTK floating ownership until inserted into a container.
 * Descendant handles are borrowed. Callback data remains C-owned and must
 * outlive the corresponding widget tree.
 */
gboolean noctty_compact_tab_new(
    const NocttyCompactTabOptions *options,
    const NocttyCompactTabCallbacks *callbacks,
    NocttyCompactTabContents *contents_out);
GtkWidget *noctty_new_tab_button_new(
    int extent_px, gpointer callback_data, GCallback clicked);

typedef struct {
    GCallback settings_clicked;
    GCallback close_clicked;
} NocttyWindowToolbarCallbacks;

typedef struct {
    GtkWidget *controls;
    GtkWidget *settings;
    GtkWidget *close_button;
} NocttyWindowToolbarContents;

gboolean noctty_window_toolbar_new(
    int extent_px, gpointer callback_data,
    const NocttyWindowToolbarCallbacks *callbacks,
    NocttyWindowToolbarContents *contents_out);
void noctty_window_toolbar_set_close_visible(
    GtkWidget *close_button, gboolean visible);
GdkWindow *noctty_action_button_event_window(GtkWidget *widget);
gboolean noctty_action_button_enter(GtkWidget *widget);
gboolean noctty_action_button_leave(GtkWidget *widget);
GtkWidget *noctty_tab_label_from_widget(GtkWidget *tab_widget);
GtkWidget *noctty_tab_close_button_from_widget(GtkWidget *tab_widget);
gboolean noctty_tab_color_uses_dark_text(guint32 rgb);
void noctty_apply_tab_color_style(GtkWidget *tab_widget, guint32 rgb,
                                  gboolean is_active);
GtkWidget *noctty_settings_grid_new(void);
void noctty_settings_grid_attach_control(GtkWidget *grid, const char *text,
                                         GtkWidget *control, int row);
GtkWidget *noctty_settings_group_new(const char *title, GtkWidget *child);
GtkWidget *noctty_settings_page_new(const char *title,
                                    const char *description,
                                    GtkWidget **body_out);
GtkWidget *noctty_settings_category_row_new(const char *icon_name,
                                            const char *label_text,
                                            const char *page_name);
void noctty_settings_category_selected(GtkListBox *list, GtkListBoxRow *row,
                                       gpointer user_data);
void noctty_settings_response(GtkDialog *dialog, gint response,
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
} NocttyWorkspaceMenuCallbacks;

typedef struct {
    gpointer context;
    gpointer root;
    GtkWidget *profile_menu;
    const char *broadcast_label;
    gboolean selection_active;
    gboolean pane_close_sensitive;
} NocttyWorkspaceMenuOptions;

GtkWidget *noctty_workspace_menu_new(
    const NocttyWorkspaceMenuOptions *options,
    const NocttyWorkspaceMenuCallbacks *callbacks);

typedef struct {
    GtkWidget *menu;
    GtkWidget *open;
    GtkWidget *copy;
} NocttyHyperlinkMenuContents;

gboolean noctty_hyperlink_menu_new(
    NocttyHyperlinkMenuContents *contents_out);
GtkWidget *noctty_profile_preset_menu_new(
    const char *const *labels, guint label_count, int active,
    GCallback toggled, gpointer context);
GtkWidget *noctty_tab_color_menu_new(
    const char *const *labels, guint label_count, int active,
    GtkWidget *page, GCallback preset_toggled, GCallback adjust_activate,
    gpointer context, const char *lighter_label, const char *darker_label);
GtkWidget *noctty_tab_context_menu_new(
    GtkWidget *page, GtkWidget *tab_color_menu, gboolean close_sensitive,
    GCallback close_activate, gpointer context);

typedef struct {
    GtkWidget *entry;
    GtkWidget *status;
} NocttyFindContents;

typedef struct {
    GtkWidget *view;
    GtkWidget *status;
} NocttyQuickNoteContents;

typedef struct {
    int id;
    const char *label;
    const char *hint;
} NocttyPaletteAction;

typedef struct {
    GtkWidget *search;
    GtkWidget *list;
} NocttyPaletteContents;

gboolean noctty_terminal_find_contents_new(
    GtkWidget *dialog, int dialog_width, gboolean vertical,
    NocttyFindContents *contents_out);
gboolean noctty_quick_note_contents_new(
    GtkWidget *dialog, int dialog_width, int dialog_height,
    NocttyQuickNoteContents *contents_out);
gboolean noctty_shortcuts_contents_new(
    GtkWidget *dialog, const char *shortcuts, int dialog_width,
    int dialog_height);
gboolean noctty_command_palette_contents_new(
    GtkWidget *dialog, int dialog_width, int dialog_height,
    gboolean vertical_rows, const NocttyPaletteAction *actions,
    guint action_count, const char *visibility_hint,
    NocttyPaletteContents *contents_out);

typedef struct {
    GtkWidget *save;
    GtkWidget *open;
    GtkWidget *recent_combo;
    GtkWidget *recent_open;
    GtkWidget *editor;
    GtkWidget *summary;
    GtkWidget *summary_scroll;
} NocttyProjectContents;

gboolean noctty_project_contents_new(
    GtkWidget *dialog, const char *summary_text,
    NocttyProjectContents *contents_out);

gboolean noctty_restore_workspace_contents_new(
    GtkWidget *dialog, GtkWidget **combo_out);
GtkWidget *noctty_workspace_file_chooser_new(
    GtkWidget *parent, gboolean save);

GtkWidget *noctty_save_file_chooser_new(
    GtkWidget *parent, const char *title, const char *accept_label,
    const char *default_name);

gboolean noctty_history_password_contents_new(
    GtkWidget *dialog, GtkWidget **entry_out);
gboolean noctty_agent_resume_contents_new(
    GtkWidget *dialog, GtkWidget **provider_out,
    GtkWidget **session_out, GtkWidget **label_out);

GtkWidget *noctty_error_dialog_new(
    GtkWidget *parent, const char *title, const char *detail);

GtkWidget *noctty_dialog_new(
    GtkWidget *parent, const char *title, int flags,
    const char *cancel_label, int cancel_response,
    const char *accept_label, int accept_response);

GtkWidget *noctty_message_dialog_new(
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
} NocttySettingsCoreOptions;

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
} NocttySettingsCoreContents;

gboolean noctty_settings_core_contents_new(
    const NocttySettingsCoreOptions *options,
    NocttySettingsCoreContents *contents_out);

typedef struct {
    GtkWidget *categories;
    GtkWidget *stack;
} NocttySettingsShellContents;

gboolean noctty_settings_shell_new(
    GtkWidget *dialog, gboolean compact,
    GtkWidget *window_page, GtkWidget *behavior_page,
    GtkWidget *appearance_page, NocttySettingsShellContents *contents_out);

GtkWidget *noctty_theme_combo_new(void);
GtkWidget *noctty_color_button_new(const char *accessible_name);

GtkWidget *noctty_grid_page_new(int panel_padding, GtkWidget *pane_info_strip);
GtkWidget *noctty_grid_window_new(void);
GtkWidget *noctty_grid_notebook_new(void);
GtkIMContext *noctty_grid_input_context_new(void);
void noctty_grid_window_configure(
    GtkWidget *window, int default_width, int default_height,
    gboolean decorated, gboolean keep_above);
void noctty_grid_window_apply_mode(
    GtkWidget *window, gboolean decorated, gboolean keep_above);
void noctty_grid_window_set_title(
    GtkWidget *window, const char *title);
void noctty_grid_window_present(GtkWidget *window);
void noctty_grid_window_set_fullscreen(
    GtkWidget *window, gboolean fullscreen);
void noctty_grid_window_set_startup_id(
    GtkWidget *window, const char *startup_id);
void noctty_grid_focus_widget(
    GtkWidget *window, GtkWidget *target);
void noctty_grid_widget_set_margins(
    GtkWidget *widget, int start, int top, int end, int bottom);
void noctty_grid_widget_queue_draw(GtkWidget *widget);
void noctty_grid_widget_queue_draw_area(
    GtkWidget *widget, int x, int y, int width, int height);
void noctty_grid_widget_queue_resize(GtkWidget *widget);
void noctty_grid_widget_show(GtkWidget *widget);
void noctty_grid_widget_hide(GtkWidget *widget);
void noctty_grid_widget_set_visible(GtkWidget *widget, gboolean visible);
void noctty_grid_widget_set_can_focus(GtkWidget *widget, gboolean can_focus);
void noctty_grid_widget_set_sensitive(GtkWidget *widget, gboolean sensitive);
void noctty_grid_widget_set_size_request(
    GtkWidget *widget, int width, int height);
void noctty_grid_widget_set_tooltip_text(
    GtkWidget *widget, const char *tooltip);
void noctty_grid_window_set_decorated(GtkWidget *window, gboolean decorated);
void noctty_grid_window_set_keep_above(GtkWidget *window, gboolean keep_above);
void noctty_grid_window_set_resizable(GtkWidget *window, gboolean resizable);
void noctty_grid_window_set_default_size(
    GtkWidget *window, int width, int height);
void noctty_grid_window_set_modal(GtkWidget *window, gboolean modal);
void noctty_grid_window_set_position(GtkWidget *window, int position);
void noctty_grid_window_set_type_hint(GtkWidget *window, int type_hint);
void noctty_grid_window_set_destroy_with_parent(
    GtkWidget *window, gboolean destroy_with_parent);
void noctty_grid_widget_add_events(GtkWidget *widget, int events);
void noctty_grid_window_set_transient_for(
    GtkWidget *window, GtkWidget *parent);
void noctty_grid_window_resize(
    GtkWidget *window, int width, int height);
void noctty_grid_window_move(
    GtkWidget *window, int x, int y);
void noctty_grid_widget_set_no_show_all(
    GtkWidget *widget, gboolean no_show_all);
void noctty_grid_widget_destroy(GtkWidget *widget);
gulong noctty_grid_signal_connect(
    gpointer instance,
    const char *signal,
    GCallback callback,
    gpointer data);
gulong noctty_grid_signal_connect_swapped(
    gpointer instance,
    const char *signal,
    GCallback callback,
    gpointer data);
gulong noctty_grid_signal_connect_object(
    gpointer instance,
    const char *signal,
    GCallback callback,
    gpointer object,
    unsigned int flags);
void noctty_grid_drag_source_set(
    GtkWidget *widget,
    unsigned int start_button_mask,
    gpointer targets,
    int target_count,
    unsigned int actions);
void noctty_grid_drag_dest_set(
    GtkWidget *widget,
    unsigned int dest_defaults,
    gpointer targets,
    int target_count,
    unsigned int actions);
void noctty_grid_widget_show_all(GtkWidget *widget);
void noctty_grid_widget_set_app_paintable(
    GtkWidget *widget, gboolean app_paintable);
void noctty_grid_widget_set_visual(GtkWidget *widget, gpointer visual);
GtkWidget *noctty_grid_window_get_focus(gpointer window);
void noctty_grid_window_get_size(
    gpointer window, int *width, int *height);
void noctty_grid_window_get_position(
    gpointer window, int *x, int *y);
gboolean noctty_grid_window_is_active(gpointer window);
gboolean noctty_grid_window_get_decorated(gpointer window);
gboolean noctty_grid_window_get_resizable(gpointer window);
GtkWindow *noctty_grid_window_get_transient_for(gpointer window);
const char *noctty_grid_window_get_icon_name(gpointer window);
GdkScreen *noctty_grid_widget_get_screen(gpointer widget);
gboolean noctty_grid_widget_get_app_paintable(gpointer widget);
GtkWidget *noctty_grid_dialog_get_content_area(gpointer dialog);
int noctty_grid_dialog_run(gpointer dialog);
void noctty_grid_dialog_response(gpointer dialog, int response);
void noctty_grid_dialog_set_default_response(
    gpointer dialog, int response);
unsigned int noctty_grid_main_level(void);
void noctty_grid_main_quit(void);
gboolean noctty_grid_show_uri_on_window(
    gpointer window, const char *uri, unsigned int time,
    GError **error);
GtkWidget *noctty_grid_widget_get_parent(GtkWidget *widget);
gboolean noctty_grid_widget_get_visible(GtkWidget *widget);
gboolean noctty_grid_widget_get_mapped(GtkWidget *widget);
gboolean noctty_grid_widget_in_destruction(GtkWidget *widget);
void noctty_grid_widget_get_allocation(
    GtkWidget *widget, GtkAllocation *allocation);
GtkWidget *noctty_grid_paned_get_child1(gpointer paned);
GtkWidget *noctty_grid_paned_get_child2(gpointer paned);
int noctty_grid_paned_get_position(gpointer paned);
int noctty_grid_orientable_get_orientation(gpointer orientable);
GtkWidget *noctty_grid_bin_get_child(gpointer bin);
GList *noctty_grid_container_get_children(gpointer container);
GtkWidget *noctty_grid_widget_get_toplevel(gpointer widget);
const char *noctty_grid_label_get_text(gpointer label);
char *noctty_grid_widget_get_tooltip_text(gpointer widget);
const char *noctty_grid_entry_get_text(gpointer entry);
int noctty_grid_spin_button_get_value_as_int(gpointer spin);
gboolean noctty_grid_toggle_button_get_active(gpointer toggle);
int noctty_grid_combo_box_get_active(gpointer combo);
double noctty_grid_range_get_value(gpointer range);
int noctty_grid_widget_get_scale_factor(gpointer widget);
void noctty_grid_label_set_text(gpointer label, const char *text);
void noctty_grid_label_set_markup(gpointer label, const char *markup);
void noctty_grid_entry_set_text(gpointer entry, const char *text);
void noctty_grid_button_set_label(gpointer button, const char *label);
void noctty_grid_button_clicked(gpointer button);
void noctty_grid_combo_box_set_active(gpointer combo, int index);
gboolean noctty_grid_combo_box_set_active_id(
    gpointer combo, const char *id);
void noctty_grid_spin_button_set_value(gpointer spin, double value);
void noctty_grid_toggle_button_set_active(
    gpointer toggle, gboolean active);
void noctty_grid_range_set_value(gpointer range, double value);
const char *noctty_grid_combo_box_get_active_id(gpointer combo);
char *noctty_grid_combo_box_text_get_active_text(gpointer combo);
char *noctty_grid_file_chooser_get_filename(gpointer chooser);
GtkListBoxRow *noctty_grid_list_box_get_row_at_index(
    gpointer list, int index);
void noctty_grid_list_box_select_row(
    gpointer list, GtkListBoxRow *row);
void noctty_grid_event_box_set_above_child(
    gpointer event_box, gboolean above_child);
void noctty_grid_entry_set_icon_from_icon_name(
    gpointer entry, int icon_pos, const char *icon_name);
void noctty_grid_entry_set_icon_tooltip_text(
    gpointer entry, int icon_pos, const char *tooltip);
gpointer noctty_grid_text_view_get_buffer(gpointer view);
void noctty_grid_text_buffer_get_bounds(
    gpointer buffer, gpointer start, gpointer end);
char *noctty_grid_text_buffer_get_text(
    gpointer buffer, gpointer start, gpointer end,
    gboolean include_hidden);
void noctty_grid_text_buffer_set_text(
    gpointer buffer, const char *text, int length);
gpointer noctty_grid_combo_box_get_model(gpointer combo);
int noctty_grid_tree_model_iter_n_children(
    gpointer model, gpointer parent);
GtkWidget *noctty_grid_button_get_image(gpointer button);
void noctty_grid_image_get_icon_name(
    gpointer image, const char **icon_name, GtkIconSize *icon_size);
gpointer noctty_grid_clipboard_get(gpointer selection);
void noctty_grid_clipboard_request_text(
    gpointer clipboard,
    void (*callback)(GtkClipboard *, const gchar *, gpointer),
    gpointer data);
void noctty_grid_clipboard_set_text(
    gpointer clipboard, const char *text, int length);
void noctty_grid_im_context_focus_in(gpointer context);
void noctty_grid_im_context_focus_out(gpointer context);
gboolean noctty_grid_im_context_filter_keypress(
    gpointer context, gpointer event);
void noctty_grid_editable_select_region(
    gpointer editable, int start_pos, int end_pos);
gpointer noctty_grid_widget_get_accessible(gpointer widget);
gpointer noctty_grid_widget_get_style_context(gpointer widget);
void noctty_grid_style_context_add_class(
    gpointer style_context, const char *class_name);
void noctty_grid_style_context_remove_class(
    gpointer style_context, const char *class_name);
gboolean noctty_grid_style_context_has_class(
    gpointer style_context, const char *class_name);
void noctty_grid_atk_object_set_name(
    gpointer accessible, const char *name);
void noctty_grid_atk_object_set_description(
    gpointer accessible, const char *description);
void noctty_grid_atk_object_set_role(
    gpointer accessible, AtkRole role);
const char *noctty_grid_atk_object_get_name(gpointer accessible);
const char *noctty_grid_atk_object_get_description(
    gpointer accessible);
AtkRole noctty_grid_atk_object_get_role(gpointer accessible);
gboolean noctty_grid_widget_translate_coordinates(
    GtkWidget *source,
    GtkWidget *dest,
    int src_x,
    int src_y,
    int *dest_x,
    int *dest_y);
GdkWindow *noctty_grid_widget_get_window(GtkWidget *widget);
unsigned int noctty_grid_widget_add_tick_callback(
    GtkWidget *widget,
    GCallback callback,
    gpointer data,
    GDestroyNotify destroy_notify);
void noctty_grid_drag_finish(
    gpointer drag, gboolean delete_data, gboolean success, unsigned int time);
void noctty_grid_window_begin_resize_drag(
    gpointer window,
    int edge,
    int button,
    int root_x,
    int root_y,
    unsigned int time);
gboolean noctty_grid_events_pending(void);
int noctty_grid_notebook_get_n_pages(gpointer notebook);
int noctty_grid_notebook_get_current_page(gpointer notebook);
GtkWidget *noctty_grid_notebook_get_nth_page(
    gpointer notebook, int page_index);
GtkWidget *noctty_grid_notebook_get_tab_label(
    gpointer notebook, gpointer page);
gboolean noctty_grid_notebook_get_show_tabs(gpointer notebook);
GtkWidget *noctty_grid_notebook_get_action_widget(
    gpointer notebook, int pack_type);
int noctty_grid_notebook_get_tab_pos(gpointer notebook);
int noctty_grid_notebook_page_num(gpointer notebook, gpointer page);
void noctty_grid_notebook_reorder_child(
    gpointer notebook, gpointer page, int page_index);
void noctty_grid_notebook_remove_page(gpointer notebook, int page_index);
void noctty_grid_menu_popdown(gpointer menu);
const char *noctty_grid_menu_item_get_label(gpointer item);
GtkWidget *noctty_grid_menu_item_get_submenu(gpointer item);
void noctty_grid_menu_item_activate(gpointer item);
void noctty_grid_menu_shell_select_item(
    gpointer menu_shell, gpointer item);
gboolean noctty_grid_menu_shell_activate_item(
    gpointer menu_shell, gpointer item, gboolean force);
GtkWidget *noctty_grid_menu_get_attach_widget(gpointer menu);
void noctty_grid_menu_popup_at_widget(
    gpointer menu,
    GtkWidget *anchor,
    int widget_gravity,
    int menu_gravity,
    gpointer event);
void noctty_grid_menu_popup_at_rect(
    gpointer menu,
    GdkWindow *rect_window,
    const GdkRectangle *rect,
    int rect_gravity,
    int menu_gravity,
    gpointer event);
gboolean noctty_grid_widget_has_focus(gpointer widget);
GdkFrameClock *noctty_grid_widget_get_frame_clock(gpointer widget);
GdkDisplay *noctty_grid_widget_get_display(gpointer widget);
GtkWidget *noctty_grid_widget_get_ancestor(
    gpointer widget, GType widget_type);
GtkWidget *noctty_grid_grab_get_current(void);
void noctty_grid_grab_add(gpointer widget);
void noctty_grid_grab_remove(gpointer widget);
gboolean noctty_grid_widget_has_grab(gpointer widget);
void noctty_grid_widget_get_size_request(
    gpointer widget, int *width, int *height);
GList *noctty_grid_window_list_toplevels(void);
void noctty_grid_check_menu_item_set_active(
    gpointer item, gboolean active);
void noctty_grid_revealer_set_reveal_child(
    gpointer revealer, gboolean reveal);
void noctty_grid_revealer_set_transition_duration(
    gpointer revealer, unsigned int duration);
void noctty_grid_revealer_set_transition_type(
    gpointer revealer, int transition_type);
void noctty_grid_main_iteration_do(gboolean blocking);
void noctty_grid_window_set_geometry_hints(
    GtkWidget *window, int min_width, int min_height,
    int max_width, int max_height, int hints);




typedef struct {
    GCallback delete_event;
    GCallback destroy;
    GCallback focus_out_event;
    GCallback map;
    GCallback configure_event;
    GCallback button_release_event;
} NocttyGridWindowCallbacks;

gboolean noctty_grid_window_connect_signals(
    GtkWidget *window, gpointer context,
    const NocttyGridWindowCallbacks *callbacks);

typedef struct {
    GCallback switch_page;
    GCallback drag_begin;
    GCallback drag_end;
    GCallback page_reordered;
} NocttyGridNotebookCallbacks;

gboolean noctty_grid_notebook_configure(
    GtkWidget *notebook, GtkWidget *new_tab_button,
    GtkWidget *toolbar_controls, gpointer context,
    const NocttyGridNotebookCallbacks *callbacks);
int noctty_grid_notebook_append_page(
    GtkWidget *notebook, GtkWidget *page, GtkWidget *tab_widget);
void noctty_grid_notebook_apply_policy(
    GtkWidget *notebook, GtkWidget *toolbar_controls,
    int tab_position, gboolean show_tabs);
void noctty_grid_notebook_select_page(
    GtkWidget *notebook, int page_index);







typedef struct {
    int column;
    int row;
    int width;
    int height;
} NocttyWindowResizeLayout;

GtkWidget *noctty_window_resize_layout_new(
    GtkWidget *content, GtkWidget *const *handles,
    const NocttyWindowResizeLayout *layouts, guint handle_count,
    GtkWidget **resize_grip_out);

GtkWidget *noctty_resize_handle_new(
    int index, int width, int height, const char *cursor_name);

typedef struct {
    GtkWidget *box;
    GtkWidget *label;
    GtkWidget *clear_button;
} NocttySmartFilterEmptyContents;

gboolean noctty_smart_filter_empty_contents_new(
    const char *message, NocttySmartFilterEmptyContents *contents_out);


GtkWidget *noctty_tab_rename_entry_new(
    const char *title, int width_chars, int height);

GtkWidget *noctty_recovery_notice_new(
    const char *message, int apply_response, int close_response);

GtkWidget *noctty_tag_combo_new(void);
GtkWidget *noctty_tag_hint_new(void);
GtkWidget *noctty_shortcut_recorder_label_new(gboolean plasma);
GtkWidget *noctty_settings_notifications_box_new(GtkWidget *notifications);

typedef struct {
    GtkWidget *revealer;
    GtkWidget *content_box;
} NocttyGridShellContents;

gboolean noctty_grid_shell_contents_new(
    NocttyGridShellContents *contents_out);
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
    gboolean translucency;
    gboolean alpha_supported;
    double opacity_percent;
    gboolean compact;
} NocttySettingsAppearanceOptions;

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
    GtkWidget *translucency;
    GtkWidget *opacity;
    GtkWidget *transparency_status;
} NocttySettingsAppearanceContents;

gboolean noctty_settings_appearance_contents_new(
    const NocttySettingsAppearanceOptions *options,
    NocttySettingsAppearanceContents *contents_out);

typedef struct {
    const char *shell;
    const char *command;
    const char *cwd;
    const char *environment;
    const char *ssh_target;
    int kind;
    int scrollback;
} NocttyLaunchProfileOptions;

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
} NocttyLaunchProfileContents;

gboolean noctty_launch_profile_contents_new(
    GtkWidget *parent_body, const NocttyLaunchProfileOptions *options,
    NocttyLaunchProfileContents *contents_out);

typedef struct {
    GtkWidget *variant;
    GtkWidget *scope_tab;
    GtkWidget *apply;
    GtkWidget *status;
    GtkWidget *import_current;
    GtkWidget *import_file;
} NocttyThemeLibraryContents;

gboolean noctty_theme_library_contents_new(
    GtkWidget *dialog, GtkWidget *themes, GtkWidget *scheme,
    guint scheme_count, NocttyThemeLibraryContents *contents_out);

guint noctty_theme_library_append_noctalia_records(
    GtkWidget *scheme, const char *records, gsize length);

GtkWidget *noctty_theme_import_dialog_new(
    GtkWidget *parent, GtkWidget **variant_out);

typedef struct {
    GCallback action;
    GCallback tab_changed;
    GCallback stream_changed;
    GCallback preview_draw;
    GCallback preview_button;
    GCallback preview_key;
    GCallback preview_scroll;
} NocttySharingCallbacks;

gboolean noctty_sharing_contents_new(
    GtkWidget *dialog, int width, int height, gpointer context,
    const NocttySharingCallbacks *callbacks);

#define configure_action_button noctty_configure_action_button
#define prepare_action_button_tree noctty_prepare_action_button_tree
#define show_all_with_action_affordances noctty_show_all_with_action_affordances
#define install_compact_tab_styles noctty_install_compact_tab_styles
#define tab_label_from_widget noctty_tab_label_from_widget
#define tab_close_button_from_widget noctty_tab_close_button_from_widget
#define tab_color_uses_dark_text noctty_tab_color_uses_dark_text
#define apply_tab_color_style noctty_apply_tab_color_style
#define settings_grid_new noctty_settings_grid_new
#define settings_grid_attach_control noctty_settings_grid_attach_control
#define settings_group_new noctty_settings_group_new
#define settings_page_new noctty_settings_page_new
#define settings_category_row_new noctty_settings_category_row_new
#define on_settings_category_selected noctty_settings_category_selected
#define on_settings_response noctty_settings_response

#endif
