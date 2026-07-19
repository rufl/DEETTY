#ifndef NOCTTY_PANE_INFO_STRIP_H
#define NOCTTY_PANE_INFO_STRIP_H

#include <gtk/gtk.h>

GtkWidget *noctty_pane_info_strip_new(gboolean enabled);
void noctty_pane_info_strip_set_enabled(GtkWidget *strip, gboolean enabled);
gboolean noctty_pane_info_strip_update(GtkWidget *strip, const char *text,
                                       const char *tooltip);
const char *noctty_pane_info_strip_text(GtkWidget *strip);
const char *noctty_pane_info_strip_tooltip(GtkWidget *strip);
guint noctty_pane_info_strip_revision(GtkWidget *strip);

#endif
