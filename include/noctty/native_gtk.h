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
