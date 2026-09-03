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
void noctty_install_compact_tab_styles(GtkWidget *notebook);
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
