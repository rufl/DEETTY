#include "pane_info_strip.h"

#define NOCTTY_PANE_INFO_LABEL "noctty-pane-info-label"
#define NOCTTY_PANE_INFO_TEXT "noctty-pane-info-text"
#define NOCTTY_PANE_INFO_TOOLTIP "noctty-pane-info-tooltip"
#define NOCTTY_PANE_INFO_REVISION "noctty-pane-info-revision"

static void add_strip_style(GtkWidget *strip, GtkWidget *label) {
    static const char css[] =
        "#noctty-pane-info {"
        " background-color: alpha(@theme_fg_color, 0.035);"
        " border-bottom: 1px solid alpha(@theme_fg_color, 0.09);"
        "}"
        "#noctty-pane-info label {"
        " color: alpha(@theme_fg_color, 0.72);"
        " font-size: 10px;"
        " padding: 1px 6px;"
        "}";
    GtkCssProvider *provider = gtk_css_provider_new();
    gtk_css_provider_load_from_data(provider, css, -1, NULL);
    gtk_style_context_add_provider(
        gtk_widget_get_style_context(strip),
        GTK_STYLE_PROVIDER(provider),
        GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);
    gtk_style_context_add_provider(
        gtk_widget_get_style_context(label),
        GTK_STYLE_PROVIDER(provider),
        GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);
    g_object_unref(provider);
}

GtkWidget *noctty_pane_info_strip_new(gboolean enabled) {
    GtkWidget *strip = gtk_event_box_new();
    gtk_widget_set_name(strip, "noctty-pane-info");
    gtk_widget_set_size_request(strip, -1, 18);
    gtk_event_box_set_visible_window(GTK_EVENT_BOX(strip), TRUE);
    GtkWidget *label = gtk_label_new("");
    gtk_label_set_xalign(GTK_LABEL(label), 0.0f);
    gtk_label_set_single_line_mode(GTK_LABEL(label), TRUE);
    gtk_label_set_ellipsize(GTK_LABEL(label), PANGO_ELLIPSIZE_MIDDLE);
    gtk_label_set_max_width_chars(GTK_LABEL(label), 96);
    gtk_widget_set_hexpand(label, TRUE);
    gtk_container_add(GTK_CONTAINER(strip), label);
    add_strip_style(strip, label);
    g_object_set_data(G_OBJECT(strip), NOCTTY_PANE_INFO_LABEL, label);
    atk_object_set_name(gtk_widget_get_accessible(strip),
                        "Active terminal pane information");
    noctty_pane_info_strip_set_enabled(strip, enabled);
    return strip;
}

void noctty_pane_info_strip_set_enabled(GtkWidget *strip, gboolean enabled) {
    if (!GTK_IS_WIDGET(strip)) return;
    gtk_widget_set_no_show_all(strip, !enabled);
    gtk_widget_set_visible(strip, enabled);
}

gboolean noctty_pane_info_strip_update(GtkWidget *strip, const char *text,
                                       const char *tooltip) {
    if (!GTK_IS_WIDGET(strip) || text == NULL || tooltip == NULL) return FALSE;
    const char *previous_text = g_object_get_data(
        G_OBJECT(strip), NOCTTY_PANE_INFO_TEXT);
    const char *previous_tooltip = g_object_get_data(
        G_OBJECT(strip), NOCTTY_PANE_INFO_TOOLTIP);
    if (g_strcmp0(previous_text, text) == 0 &&
        g_strcmp0(previous_tooltip, tooltip) == 0)
        return FALSE;

    GtkWidget *label = g_object_get_data(
        G_OBJECT(strip), NOCTTY_PANE_INFO_LABEL);
    if (GTK_IS_LABEL(label)) gtk_label_set_text(GTK_LABEL(label), text);
    gtk_widget_set_tooltip_text(strip, tooltip);
    g_object_set_data_full(G_OBJECT(strip), NOCTTY_PANE_INFO_TEXT,
                           g_strdup(text), g_free);
    g_object_set_data_full(G_OBJECT(strip), NOCTTY_PANE_INFO_TOOLTIP,
                           g_strdup(tooltip), g_free);
    guint revision = noctty_pane_info_strip_revision(strip) + 1;
    g_object_set_data(G_OBJECT(strip), NOCTTY_PANE_INFO_REVISION,
                      GUINT_TO_POINTER(revision));
    return TRUE;
}

const char *noctty_pane_info_strip_text(GtkWidget *strip) {
    if (!GTK_IS_WIDGET(strip)) return NULL;
    return g_object_get_data(G_OBJECT(strip), NOCTTY_PANE_INFO_TEXT);
}

const char *noctty_pane_info_strip_tooltip(GtkWidget *strip) {
    if (!GTK_IS_WIDGET(strip)) return NULL;
    return g_object_get_data(G_OBJECT(strip), NOCTTY_PANE_INFO_TOOLTIP);
}

guint noctty_pane_info_strip_revision(GtkWidget *strip) {
    if (!GTK_IS_WIDGET(strip)) return 0;
    return GPOINTER_TO_UINT(g_object_get_data(
        G_OBJECT(strip), NOCTTY_PANE_INFO_REVISION));
}
