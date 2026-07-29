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

#define configure_action_button noctty_configure_action_button
#define prepare_action_button_tree noctty_prepare_action_button_tree
#define show_all_with_action_affordances noctty_show_all_with_action_affordances
#define install_compact_tab_styles noctty_install_compact_tab_styles
#define tab_label_from_widget noctty_tab_label_from_widget
#define tab_close_button_from_widget noctty_tab_close_button_from_widget
#define tab_color_uses_dark_text noctty_tab_color_uses_dark_text
#define apply_tab_color_style noctty_apply_tab_color_style

#endif
