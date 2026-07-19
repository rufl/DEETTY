#include <gtk/gtk.h>
#include <glib/gstdio.h>
#include <gdk/gdkwayland.h>
#include <gdk/gdkx.h>
#include <dlfcn.h>
#include <stdint.h>
#include <string.h>
#include <sys/wait.h>
#include <vte/vte.h>
#include <unistd.h>

typedef void (*NocttyHostEventCallback)(void *userdata, uint64_t pane_id,
                                        int event, int exit_code,
                                        uint64_t at_ms);
static uint64_t now_ms(void);

typedef struct {
    GtkWidget *window;
    GtkWidget *terminal_widget;
    GtkWidget *secondary_terminal_widget;
    uint64_t pane_id;
    NocttyHostEventCallback callback;
    void *callback_data;
    int smoke;
    int mode;
    int initial_width;
    int initial_height;
    GDBusConnection *session_bus;
    guint shortcut_subscription;
    int global_shortcut_registered;
    int global_shortcut_action_registered;
    int requested_shortcut_key;
    int placement;
    void *layer_shell_library;
    int expected_x;
    int expected_y;
    int expected_width;
    int expected_height;
    char smoke_marker_path[128];
    GtkWidget *shortcut_dialog;
    GtkWidget *shortcut_feedback;
    GtkWidget *tabs;
    guint tab_index;
    guint64 secondary_pane_id;
    gboolean secondary_bound;
    guint maintenance_timer;
    guint smoke_resize_source;
    guint smoke_marker_source;
    guint smoke_hide_source;
    guint smoke_shortcut_source;
    guint smoke_recorder_source;
    guint smoke_recorder_capture_source;
} NocttyHostContext;

typedef struct {
    GtkWidget *terminal_widget;
    guint64 pane_id;
    NocttyHostEventCallback callback;
    gpointer callback_data;
    gboolean spawned;
} NocttySecondaryContext;

static void on_secondary_spawned(VteTerminal *terminal, GPid pid, GError *error,
                                 gpointer user_data) {
    NocttySecondaryContext *secondary = user_data;
    (void)terminal;
    (void)pid;
    if (error != NULL) {
        g_error_free(error);
        return;
    }
    secondary->spawned = TRUE;
    secondary->callback(secondary->callback_data, secondary->pane_id, 1, 0, now_ms());
}

static void on_secondary_contents_changed(VteTerminal *terminal, gpointer user_data) {
    NocttySecondaryContext *secondary = user_data;
    (void)terminal;
    secondary->callback(secondary->callback_data, secondary->pane_id, 2, 0, now_ms());
}

static void on_secondary_size_allocate(GtkWidget *widget, GdkRectangle *allocation,
                                       gpointer user_data) {
    NocttySecondaryContext *secondary = user_data;
    (void)widget;
    (void)allocation;
    secondary->callback(secondary->callback_data, secondary->pane_id, 5, 0, now_ms());
}

static void on_secondary_child_exited(VteTerminal *terminal, gint status,
                                      gpointer user_data) {
    NocttySecondaryContext *secondary = user_data;
    (void)terminal;
    secondary->callback(secondary->callback_data, secondary->pane_id, 3, status, now_ms());
}

static int register_global_shortcut(NocttyHostContext *context);
static void unregister_global_shortcut(NocttyHostContext *context);
static void on_preset_changed(GtkComboBoxText *combo, gpointer user_data);

static void remove_host_source(guint *source) {
    if (*source == 0) return;
    g_source_remove(*source);
    *source = 0;
}

static void clear_smoke_sources(NocttyHostContext *context) {
    remove_host_source(&context->smoke_resize_source);
    remove_host_source(&context->smoke_marker_source);
    remove_host_source(&context->smoke_hide_source);
    remove_host_source(&context->smoke_shortcut_source);
    remove_host_source(&context->smoke_recorder_source);
    remove_host_source(&context->smoke_recorder_capture_source);
}

static gboolean on_maintenance_timer(gpointer user_data) {
    NocttyHostContext *context = user_data;
    context->callback(context->callback_data, context->pane_id, 19, 0, now_ms());
    return G_SOURCE_CONTINUE;
}

enum {
    NOCTTY_PLACEMENT_X11_TOP = 1,
    NOCTTY_PLACEMENT_WAYLAND_LAYER = 2,
    NOCTTY_PLACEMENT_WAYLAND_CONSTRAINED = 3,
    NOCTTY_PLACEMENT_WINDOWED = 4,
    NOCTTY_PLACEMENT_FULLSCREEN = 5,
};

static uint64_t now_ms(void) {
    return (uint64_t)(g_get_monotonic_time() / 1000);
}

static void configure_dropdown_placement(NocttyHostContext *context) {
    GdkDisplay *display = gdk_display_get_default();
    GdkMonitor *monitor = gdk_display_get_primary_monitor(display);
    if (monitor == NULL) monitor = gdk_display_get_monitor(display, 0);
    GdkRectangle geometry = {0, 0, 1000, 640};
    if (monitor != NULL) gdk_monitor_get_workarea(monitor, &geometry);
    int height = MAX(1, geometry.height * 45 / 100);

    if (GDK_IS_X11_DISPLAY(display)) {
        gtk_window_set_default_size(GTK_WINDOW(context->window), geometry.width,
                                    height);
        gtk_window_move(GTK_WINDOW(context->window), geometry.x, geometry.y);
        context->placement = NOCTTY_PLACEMENT_X11_TOP;
        context->expected_x = geometry.x;
        context->expected_y = geometry.y;
        context->expected_width = geometry.width;
        context->expected_height = height;
    } else if (GDK_IS_WAYLAND_DISPLAY(display)) {
        typedef gboolean (*IsSupported)(void);
        typedef void (*InitForWindow)(GtkWindow *);
        typedef void (*SetAnchor)(GtkWindow *, int, gboolean);
        typedef void (*SetLayer)(GtkWindow *, int);
        typedef void (*SetKeyboardMode)(GtkWindow *, int);
        context->layer_shell_library = dlopen("libgtk-layer-shell.so.0", RTLD_NOW);
        if (context->layer_shell_library == NULL)
            context->layer_shell_library = dlopen(
                "vendor/gtk-layer-shell/usr/lib/"
                "libgtk-layer-shell.so.0.10.1",
                RTLD_NOW);
        if (context->layer_shell_library != NULL) {
            IsSupported is_supported = dlsym(context->layer_shell_library,
                                              "gtk_layer_is_supported");
            InitForWindow init_for_window = dlsym(
                context->layer_shell_library, "gtk_layer_init_for_window");
            SetAnchor set_anchor = dlsym(context->layer_shell_library,
                                         "gtk_layer_set_anchor");
            SetLayer set_layer = dlsym(context->layer_shell_library,
                                       "gtk_layer_set_layer");
            SetKeyboardMode set_keyboard = dlsym(
                context->layer_shell_library, "gtk_layer_set_keyboard_mode");
            if (is_supported != NULL && init_for_window != NULL &&
                set_anchor != NULL && set_layer != NULL &&
                set_keyboard != NULL && is_supported()) {
                init_for_window(GTK_WINDOW(context->window));
                set_anchor(GTK_WINDOW(context->window), 0, TRUE);
                set_anchor(GTK_WINDOW(context->window), 1, TRUE);
                set_anchor(GTK_WINDOW(context->window), 2, TRUE);
                set_layer(GTK_WINDOW(context->window), 2);
                set_keyboard(GTK_WINDOW(context->window), 2);
                gtk_window_set_default_size(GTK_WINDOW(context->window), 0,
                                            height);
                context->placement = NOCTTY_PLACEMENT_WAYLAND_LAYER;
            }
        }
        if (context->placement == 0) {
            gtk_window_set_default_size(GTK_WINDOW(context->window),
                                        geometry.width, height);
            gtk_window_set_gravity(GTK_WINDOW(context->window),
                                   GDK_GRAVITY_NORTH);
            context->placement = NOCTTY_PLACEMENT_WAYLAND_CONSTRAINED;
        }
    }
    if (context->placement != NOCTTY_PLACEMENT_X11_TOP)
        context->callback(context->callback_data, context->pane_id, 13,
                          context->placement, now_ms());
}

static void configure_window_mode(NocttyHostContext *context) {
    GdkDisplay *display = gdk_display_get_default();
    GdkMonitor *monitor = gdk_display_get_primary_monitor(display);
    if (monitor == NULL) monitor = gdk_display_get_monitor(display, 0);
    GdkRectangle geometry = {0, 0, 1000, 640};
    if (monitor != NULL) gdk_monitor_get_workarea(monitor, &geometry);

    if (context->mode == 2) {
        gtk_window_fullscreen(GTK_WINDOW(context->window));
        context->placement = NOCTTY_PLACEMENT_FULLSCREEN;
    } else {
        gtk_window_set_default_size(GTK_WINDOW(context->window),
                                    MAX(1, geometry.width * 80 / 100),
                                    MAX(1, geometry.height * 75 / 100));
        gtk_window_set_position(GTK_WINDOW(context->window), GTK_WIN_POS_CENTER);
        context->placement = NOCTTY_PLACEMENT_WINDOWED;
    }
    context->callback(context->callback_data, context->pane_id, 13,
                      context->placement, now_ms());
}

static void on_child_exited(VteTerminal *terminal, gint status, gpointer user_data) {
    NocttyHostContext *context = user_data;
    if (context->smoke) {
        char *text = vte_terminal_get_text_format(terminal, VTE_FORMAT_TEXT);
        if (text != NULL && strstr(text, "NOCTTY_NATIVE_INPUT_OK") != NULL)
            context->callback(context->callback_data, context->pane_id, 6, 0,
                              now_ms());
        g_free(text);
        if (g_file_test(context->smoke_marker_path, G_FILE_TEST_EXISTS)) {
            context->callback(context->callback_data, context->pane_id, 6, 0,
                              now_ms());
            g_unlink(context->smoke_marker_path);
        }
    }
    int exit_code = WIFEXITED(status) ? WEXITSTATUS(status) : 255;
    context->callback(context->callback_data, context->pane_id, 3, exit_code,
                      now_ms());
    gtk_widget_destroy(context->window);
}

static void on_contents_changed(VteTerminal *terminal, gpointer user_data) {
    NocttyHostContext *context = user_data;
    context->callback(context->callback_data, context->pane_id, 2, 0, now_ms());
    if (context->smoke) {
        char *text = vte_terminal_get_text_format(terminal, VTE_FORMAT_TEXT);
        if (text != NULL && strstr(text, "NOCTTY_NATIVE_INPUT_OK") != NULL)
            context->callback(context->callback_data, context->pane_id, 6, 0,
                              now_ms());
        g_free(text);
    }
}

static void on_spawned(VteTerminal *terminal, GPid pid, GError *error, gpointer user_data) {
    (void)terminal;
    (void)pid;
    NocttyHostContext *context = user_data;
    if (error != NULL) {
        g_printerr("NOCTTY could not start the shell: %s\n", error->message);
        context->callback(context->callback_data, context->pane_id, 3, 255,
                          now_ms());
        g_error_free(error);
        gtk_widget_destroy(context->window);
        return;
    }
    context->callback(context->callback_data, context->pane_id, 1, 0, now_ms());
    if (context->smoke) {
        const char command[] =
            "printf 'NOCTTY_NATIVE_INPUT_OK pane=$NOCTTY_SMOKE_PANE\\n'; "
            ": > \"$NOCTTY_SMOKE_MARKER\"; "
            "sleep \"$NOCTTY_SMOKE_DELAY\"; exit 0\n";
        vte_terminal_feed_child(terminal, command, -1);
        context->callback(context->callback_data, context->pane_id, 4, 0,
                          now_ms());
    }
}

static void on_size_allocate(GtkWidget *widget, GtkAllocation *allocation,
                             gpointer user_data) {
    (void)widget;
    NocttyHostContext *context = user_data;
    if (!context->smoke) return;
    if (context->initial_width == 0 || context->initial_height == 0) {
        context->initial_width = allocation->width;
        context->initial_height = allocation->height;
        return;
    }
    if (allocation->width != context->initial_width ||
        allocation->height != context->initial_height) {
        context->callback(context->callback_data, context->pane_id, 5,
                          (int)vte_terminal_get_column_count(
                              VTE_TERMINAL(context->terminal_widget)),
                          now_ms());
    }
}

static gboolean request_smoke_resize(gpointer user_data) {
    NocttyHostContext *context = user_data;
    context->smoke_resize_source = 0;
    gtk_window_resize(GTK_WINDOW(context->window), 1200, 720);
    return G_SOURCE_REMOVE;
}

static void toggle_dropdown(NocttyHostContext *context) {
    if (gtk_widget_get_visible(context->window)) {
        gtk_widget_hide(context->window);
    } else {
        gtk_widget_show_all(context->window);
        gtk_window_present(GTK_WINDOW(context->window));
        gtk_widget_grab_focus(context->terminal_widget);
    }
}

static int qt_key_from_gdk(GdkEventKey *event);

static gboolean on_key_press(GtkWidget *widget, GdkEventKey *event,
                             gpointer user_data) {
    (void)widget;
    NocttyHostContext *context = user_data;
    if (qt_key_from_gdk(event) != context->requested_shortcut_key) return FALSE;
    toggle_dropdown(context);
    return TRUE;
}

static int qt_key_from_gdk(GdkEventKey *event) {
    int key = 0;
    if (event->keyval >= GDK_KEY_F1 && event->keyval <= GDK_KEY_F12)
        key = 0x01000030 + (event->keyval - GDK_KEY_F1);
    else if (event->keyval >= GDK_KEY_a && event->keyval <= GDK_KEY_z)
        key = 'A' + (event->keyval - GDK_KEY_a);
    else if (event->keyval >= GDK_KEY_0 && event->keyval <= GDK_KEY_9)
        key = '0' + (event->keyval - GDK_KEY_0);
    else if (event->keyval == GDK_KEY_Insert) key = 0x01000006;
    else if (event->keyval == GDK_KEY_Delete) key = 0x01000007;
    else if (event->keyval == GDK_KEY_Home) key = 0x01000010;
    else if (event->keyval == GDK_KEY_End) key = 0x01000011;
    else if (event->keyval == GDK_KEY_Left) key = 0x01000012;
    else if (event->keyval == GDK_KEY_Up) key = 0x01000013;
    else if (event->keyval == GDK_KEY_Right) key = 0x01000014;
    else if (event->keyval == GDK_KEY_Down) key = 0x01000015;
    else if (event->keyval == GDK_KEY_Page_Up) key = 0x01000016;
    else if (event->keyval == GDK_KEY_Page_Down) key = 0x01000017;
    else
        return 0;
    if (event->state & GDK_SHIFT_MASK) key |= 0x02000000;
    if (event->state & GDK_CONTROL_MASK) key |= 0x04000000;
    if (event->state & GDK_MOD1_MASK) key |= 0x08000000;
    if (event->state & GDK_SUPER_MASK) key |= 0x10000000;
    return key;
}

static gboolean on_shortcut_capture(GtkWidget *widget, GdkEventKey *event,
                                    gpointer user_data) {
    (void)widget;
    NocttyHostContext *context = user_data;
    if (event->keyval == GDK_KEY_Escape) {
        gtk_widget_destroy(context->shortcut_dialog);
        context->shortcut_dialog = NULL;
        context->shortcut_feedback = NULL;
        return TRUE;
    }
    int key = qt_key_from_gdk(event);
    if (key == 0) {
        gtk_label_set_text(GTK_LABEL(context->shortcut_feedback),
                           "Use a letter, digit, navigation key, or F1-F12. Esc cancels.");
        return TRUE;
    }
    unregister_global_shortcut(context);
    context->requested_shortcut_key = key;
    context->callback(context->callback_data, context->pane_id, 16, key,
                      now_ms());
    if (register_global_shortcut(context)) {
        gtk_widget_destroy(context->shortcut_dialog);
        context->shortcut_dialog = NULL;
        context->shortcut_feedback = NULL;
    } else {
        gtk_label_set_text(GTK_LABEL(context->shortcut_feedback),
                           "Shortcut unavailable. Press another key or Esc.");
    }
    return TRUE;
}

static void on_shortcut_dialog_destroy(GtkWidget *widget, gpointer user_data) {
    (void)widget;
    NocttyHostContext *context = user_data;
    context->shortcut_dialog = NULL;
    context->shortcut_feedback = NULL;
}

static void open_shortcut_recorder(NocttyHostContext *context) {
    if (context->shortcut_dialog != NULL) {
        gtk_window_present(GTK_WINDOW(context->shortcut_dialog));
        return;
    }
    GtkWidget *dialog = gtk_dialog_new_with_buttons(
        "NOCTTY Dropdown Shortcut", GTK_WINDOW(context->window),
        GTK_DIALOG_MODAL | GTK_DIALOG_DESTROY_WITH_PARENT, NULL, NULL);
    GtkWidget *content = gtk_dialog_get_content_area(GTK_DIALOG(dialog));
    GtkWidget *label = gtk_label_new(
        "Press a letter, digit, navigation/editing key, or F1-F12.\n"
        "Modifiers are supported.\n"
        "Esc cancels without changing the shortcut.");
    GtkWidget *settings = gtk_label_new(
        "Current settings\n"
        "Shortcut: F10\n"
        "Mode: Dropdown\n"
        "Font: JetBrains Mono 12 pt\n"
        "Profile: Global default\n"
        "Presets: Global default, Focus, Review, Logs, Custom\n"
        "Tabs: Top\n"
        "Status indicator: Border");
    GtkWidget *box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 12);
    GtkWidget *preset_combo = gtk_combo_box_text_new();
    gtk_combo_box_text_append_text(GTK_COMBO_BOX_TEXT(preset_combo), "Global default");
    gtk_combo_box_text_append_text(GTK_COMBO_BOX_TEXT(preset_combo), "Focus");
    gtk_combo_box_text_append_text(GTK_COMBO_BOX_TEXT(preset_combo), "Review");
    gtk_combo_box_text_append_text(GTK_COMBO_BOX_TEXT(preset_combo), "Logs");
    gtk_combo_box_text_append_text(GTK_COMBO_BOX_TEXT(preset_combo), "Custom");
    gtk_combo_box_set_active(GTK_COMBO_BOX(preset_combo), 0);
    gtk_container_set_border_width(GTK_CONTAINER(content), 16);
    gtk_label_set_xalign(GTK_LABEL(settings), 0.0f);
    gtk_label_set_xalign(GTK_LABEL(label), 0.0f);
    gtk_box_pack_start(GTK_BOX(box), settings, FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(box), preset_combo, FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(box), label, FALSE, FALSE, 0);
    gtk_container_add(GTK_CONTAINER(content), box);
    context->shortcut_dialog = dialog;
    context->shortcut_feedback = label;
    g_signal_connect(preset_combo, "changed", G_CALLBACK(on_preset_changed), context);
    g_signal_connect(dialog, "key-press-event", G_CALLBACK(on_shortcut_capture),
                     context);
    g_signal_connect(dialog, "destroy",
                     G_CALLBACK(on_shortcut_dialog_destroy), context);
    gtk_widget_show_all(dialog);
    context->callback(context->callback_data, context->pane_id, 17, 0, now_ms());
}

static gboolean request_smoke_recorder(gpointer user_data) {
    NocttyHostContext *context = user_data;
    context->smoke_recorder_source = 0;
    open_shortcut_recorder(context);
    return G_SOURCE_REMOVE;
}

static gboolean request_smoke_recorder_capture(gpointer user_data) {
    NocttyHostContext *context = user_data;
    context->smoke_recorder_capture_source = 0;
    if (context->shortcut_dialog == NULL) return G_SOURCE_REMOVE;
    GdkEventKey event = {0};
    event.keyval = GDK_KEY_F11;
    on_shortcut_capture(context->shortcut_dialog, &event, context);
    return G_SOURCE_REMOVE;
}

static gboolean on_terminal_button(GtkWidget *widget, GdkEventButton *event,
                                   gpointer user_data) {
    (void)widget;
    if (event->button != 3) return FALSE;
    open_shortcut_recorder(user_data);
    return TRUE;
}

static void on_preset_changed(GtkComboBoxText *combo, gpointer user_data) {
    NocttyHostContext *context = user_data;
    gchar *name = gtk_combo_box_text_get_active_text(combo);
    if (name == NULL) return;
    char message[256];
    g_snprintf(message, sizeof(message),
               "Preset selected: %s\nApply through settings to persist.",
               name);
    gtk_label_set_text(GTK_LABEL(context->shortcut_feedback), message);
    context->callback(context->callback_data, context->pane_id, 18,
                      gtk_combo_box_get_active(GTK_COMBO_BOX(combo)), now_ms());
    g_free(name);
}

static guint append_terminal_tab(NocttyHostContext *context, GtkWidget *terminal_widget, const gchar *title) {
    guint index = gtk_notebook_append_page(GTK_NOTEBOOK(context->tabs), terminal_widget, gtk_label_new(title));
    gtk_notebook_set_tab_reorderable(GTK_NOTEBOOK(context->tabs), terminal_widget, TRUE);
    context->tab_index = index;
    return index;
}

static void on_window_map(GtkWidget *widget, gpointer user_data) {
    (void)widget;
    NocttyHostContext *context = user_data;
    if (context->placement == NOCTTY_PLACEMENT_X11_TOP) {
        int x = 0, y = 0, width = 0, height = 0;
        gtk_window_get_position(GTK_WINDOW(context->window), &x, &y);
        gtk_window_get_size(GTK_WINDOW(context->window), &width, &height);
        if (x == context->expected_x && y == context->expected_y &&
            width == context->expected_width &&
            height == context->expected_height)
            context->callback(context->callback_data, context->pane_id, 13,
                              context->placement, now_ms());
    }
    context->callback(context->callback_data, context->pane_id, 7, 0, now_ms());
}

static void on_window_unmap(GtkWidget *widget, gpointer user_data) {
    (void)widget;
    NocttyHostContext *context = user_data;
    context->callback(context->callback_data, context->pane_id, 8, 0, now_ms());
}

static gboolean on_terminal_focus(GtkWidget *widget, GdkEventFocus *event,
                                  gpointer user_data) {
    (void)widget;
    (void)event;
    NocttyHostContext *context = user_data;
    context->callback(context->callback_data, context->pane_id, 9, 0, now_ms());
    return FALSE;
}

static gboolean request_smoke_hide(gpointer user_data) {
    NocttyHostContext *context = user_data;
    context->smoke_hide_source = 0;
    if (gtk_widget_get_visible(context->window)) gtk_widget_hide(context->window);
    return G_SOURCE_REMOVE;
}

static gboolean request_smoke_show(gpointer user_data) {
    NocttyHostContext *context = user_data;
    if (!gtk_widget_get_visible(context->window)) toggle_dropdown(context);
    return G_SOURCE_REMOVE;
}

static void on_global_shortcut(GDBusConnection *connection,
                               const gchar *sender_name,
                               const gchar *object_path,
                               const gchar *interface_name,
                               const gchar *signal_name,
                               GVariant *parameters,
                               gpointer user_data) {
    (void)connection;
    (void)sender_name;
    (void)object_path;
    (void)interface_name;
    (void)signal_name;
    (void)parameters;
    NocttyHostContext *context = user_data;
    toggle_dropdown(context);
    context->callback(context->callback_data, context->pane_id, 10, 0, now_ms());
}

static int register_global_shortcut(NocttyHostContext *context) {
    GError *error = NULL;
    const gchar *action_id[] = {
        "noctty", "toggle-window", "NOCTTY", "Show/hide NOCTTY", NULL};
    const gint32 requested_key = context->requested_shortcut_key;

    context->session_bus = g_bus_get_sync(G_BUS_TYPE_SESSION, NULL, &error);
    if (context->session_bus == NULL) goto failed;

    GVariant *reply = g_dbus_connection_call_sync(
        context->session_bus, "org.kde.kglobalaccel", "/kglobalaccel",
        "org.kde.KGlobalAccel", "doRegister",
        g_variant_new("(^as)", action_id), NULL, G_DBUS_CALL_FLAGS_NONE, -1,
        NULL, &error);
    if (reply == NULL) goto failed;
    g_variant_unref(reply);
    context->global_shortcut_action_registered = 1;

    reply = g_dbus_connection_call_sync(
        context->session_bus, "org.kde.kglobalaccel", "/kglobalaccel",
        "org.kde.KGlobalAccel", "isGlobalShortcutAvailable",
        g_variant_new("(is)", requested_key, "noctty"),
        G_VARIANT_TYPE("(b)"), G_DBUS_CALL_FLAGS_NONE, -1, NULL, &error);
    if (reply == NULL) goto failed;
    gboolean available = FALSE;
    g_variant_get(reply, "(b)", &available);
    g_variant_unref(reply);
    if (!available) {
        context->callback(context->callback_data, context->pane_id, 14,
                          requested_key, now_ms());
        return 0;
    }

    GVariantBuilder keys;
    g_variant_builder_init(&keys, G_VARIANT_TYPE("ai"));
    g_variant_builder_add(&keys, "i", requested_key);
    reply = g_dbus_connection_call_sync(
        context->session_bus, "org.kde.kglobalaccel", "/kglobalaccel",
        "org.kde.KGlobalAccel", "setShortcut",
        g_variant_new("(^asaiu)", action_id, &keys, 2u),
        G_VARIANT_TYPE("(ai)"), G_DBUS_CALL_FLAGS_NONE, -1, NULL, &error);
    if (reply == NULL) goto failed;
    GVariant *accepted_keys = NULL;
    g_variant_get(reply, "(@ai)", &accepted_keys);
    gsize accepted_count = 0;
    const gint32 *accepted = g_variant_get_fixed_array(
        accepted_keys, &accepted_count, sizeof(gint32));
    gboolean accepted_requested = accepted_count == 1 &&
                                  accepted != NULL &&
                                  accepted[0] == requested_key;
    g_variant_unref(accepted_keys);
    g_variant_unref(reply);
    if (!accepted_requested) {
        context->callback(context->callback_data, context->pane_id, 14,
                          requested_key, now_ms());
        return 0;
    }

    context->shortcut_subscription = g_dbus_connection_signal_subscribe(
        context->session_bus, "org.kde.kglobalaccel",
        "org.kde.kglobalaccel.Component", "globalShortcutPressed",
        "/component/noctty", NULL, G_DBUS_SIGNAL_FLAGS_NONE,
        on_global_shortcut, context, NULL);
    context->global_shortcut_registered = 1;
    context->callback(context->callback_data, context->pane_id, 11, 0, now_ms());
    return 1;

failed:
    if (error != NULL) {
        g_printerr("NOCTTY could not register Plasma F10 shortcut: %s\n",
                   error->message);
        g_error_free(error);
    }
    context->callback(context->callback_data, context->pane_id, 15, 0,
                      now_ms());
    return 0;
}

static void unregister_global_shortcut(NocttyHostContext *context) {
    if (context->session_bus == NULL) return;
    if (context->shortcut_subscription != 0)
        g_dbus_connection_signal_unsubscribe(context->session_bus,
                                             context->shortcut_subscription);
    if (context->global_shortcut_action_registered) {
        GVariant *reply = g_dbus_connection_call_sync(
            context->session_bus, "org.kde.kglobalaccel", "/kglobalaccel",
            "org.kde.KGlobalAccel", "unregister",
            g_variant_new("(ss)", "noctty", "toggle-window"),
            G_VARIANT_TYPE("(b)"), G_DBUS_CALL_FLAGS_NONE, -1, NULL, NULL);
        if (reply != NULL) g_variant_unref(reply);
        context->callback(context->callback_data, context->pane_id, 12, 0,
                          now_ms());
    }
    g_object_unref(context->session_bus);
    context->session_bus = NULL;
    context->shortcut_subscription = 0;
    context->global_shortcut_registered = 0;
    context->global_shortcut_action_registered = 0;
}

static gboolean request_smoke_global_shortcut(gpointer user_data) {
    NocttyHostContext *context = user_data;
    context->smoke_shortcut_source = 0;
    if (!context->global_shortcut_registered) return G_SOURCE_REMOVE;
    GVariant *reply = g_dbus_connection_call_sync(
        context->session_bus, "org.kde.kglobalaccel", "/component/noctty",
        "org.kde.kglobalaccel.Component", "invokeShortcut",
        g_variant_new("(s)", "toggle-window"), NULL, G_DBUS_CALL_FLAGS_NONE,
        -1, NULL, NULL);
    if (reply != NULL) g_variant_unref(reply);
    return G_SOURCE_REMOVE;
}

static gboolean request_smoke_marker_check(gpointer user_data) {
    NocttyHostContext *context = user_data;
    context->smoke_marker_source = 0;
    char *text = vte_terminal_get_text_format(
        VTE_TERMINAL(context->terminal_widget), VTE_FORMAT_TEXT);
    if (text != NULL && strstr(text, "NOCTTY_NATIVE_INPUT_OK") != NULL)
        context->callback(context->callback_data, context->pane_id, 6, 0,
                          now_ms());
    g_free(text);
    return G_SOURCE_REMOVE;
}

int noctty_native_host_run(int argc, char **argv, uint64_t pane_id,
                           int shortcut_key,
                           NocttyHostEventCallback callback,
                           void *callback_data, int mode, int smoke) {
    (void)argc;
    (void)argv;
    if (!gtk_init_check(NULL, NULL)) {
        g_printerr("NOCTTY could not connect to a Wayland or X11 display.\n");
        return 2;
    }

    GtkWidget *window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    GtkWidget *terminal_widget = vte_terminal_new();
    VteTerminal *terminal = VTE_TERMINAL(terminal_widget);
    NocttyHostContext context = {
        .window = window,
        .terminal_widget = terminal_widget,
        .pane_id = pane_id,
        .callback = callback,
        .callback_data = callback_data,
        .mode = mode,
        .smoke = smoke,
        .requested_shortcut_key = shortcut_key,
        .secondary_pane_id = 0,
        .secondary_bound = FALSE,
    };
    const char *shell = g_getenv("SHELL");
    if (shell == NULL || shell[0] == '\0') shell = "/bin/sh";
    char *shell_argv[] = {(char *)shell, NULL};
    char *smoke_argv[] = {"/bin/sh", NULL};
    char pane_text[32];
    if (smoke != 0) {
        g_snprintf(pane_text, sizeof(pane_text), "%llu",
                   (unsigned long long)pane_id);
        g_setenv("NOCTTY_SMOKE_PANE", pane_text, TRUE);
        g_snprintf(context.smoke_marker_path, sizeof(context.smoke_marker_path),
                   "/tmp/noctty-native-input-%d-%llu", (int)getpid(),
                   (unsigned long long)pane_id);
        g_unlink(context.smoke_marker_path);
        g_setenv("NOCTTY_SMOKE_MARKER", context.smoke_marker_path, TRUE);
        g_setenv("NOCTTY_SMOKE_DELAY", smoke == 3 ? "5" : smoke == 4 ? "12" : "1.5", TRUE);
    }

    gtk_window_set_title(GTK_WINDOW(window), "NOCTTY");
    gtk_window_set_default_size(GTK_WINDOW(window), 1000, 640);
    gtk_window_set_decorated(GTK_WINDOW(window), FALSE);
    gtk_window_set_keep_above(GTK_WINDOW(window), mode == 0);
    if (mode == 0) configure_dropdown_placement(&context);
    else configure_window_mode(&context);
    GtkWidget *tabs = gtk_notebook_new();
    gtk_notebook_set_tab_pos(GTK_NOTEBOOK(tabs), GTK_POS_TOP);
    context.tabs = tabs;
    GtkWidget *split = gtk_paned_new(GTK_ORIENTATION_HORIZONTAL);
    GtkWidget *secondary_terminal_widget = vte_terminal_new();
    NocttySecondaryContext secondary = {
        .terminal_widget = secondary_terminal_widget,
        .pane_id = pane_id + 1,
        .callback = callback,
        .callback_data = callback_data,
        .spawned = FALSE,
    };
    context.secondary_terminal_widget = secondary_terminal_widget;
    gtk_paned_pack1(GTK_PANED(split), terminal_widget, TRUE, FALSE);
    gtk_paned_pack2(GTK_PANED(split), secondary_terminal_widget, TRUE, FALSE);
    append_terminal_tab(&context, split, "Terminal 1");
    gtk_container_add(GTK_CONTAINER(window), tabs);

    g_signal_connect(window, "destroy", G_CALLBACK(gtk_main_quit), NULL);
    g_signal_connect(window, "key-press-event", G_CALLBACK(on_key_press), &context);
    g_signal_connect(window, "map", G_CALLBACK(on_window_map), &context);
    g_signal_connect(window, "unmap", G_CALLBACK(on_window_unmap), &context);
    g_signal_connect(terminal_widget, "focus-in-event", G_CALLBACK(on_terminal_focus), &context);
    g_signal_connect(terminal_widget, "button-press-event", G_CALLBACK(on_terminal_button), &context);
    g_signal_connect(terminal, "child-exited", G_CALLBACK(on_child_exited), &context);
    g_signal_connect(terminal, "contents-changed", G_CALLBACK(on_contents_changed), &context);
    g_signal_connect(terminal_widget, "size-allocate", G_CALLBACK(on_size_allocate), &context);
    g_signal_connect(secondary_terminal_widget, "size-allocate", G_CALLBACK(on_size_allocate), &context);
    g_signal_connect(secondary_terminal_widget, "size-allocate", G_CALLBACK(on_secondary_size_allocate), &secondary);
    g_signal_connect(VTE_TERMINAL(secondary_terminal_widget), "contents-changed", G_CALLBACK(on_secondary_contents_changed), &secondary);
    g_signal_connect(VTE_TERMINAL(secondary_terminal_widget), "child-exited", G_CALLBACK(on_secondary_child_exited), &secondary);

    vte_terminal_set_scrollback_lines(terminal, 10000);
    vte_terminal_set_mouse_autohide(terminal, TRUE);
    register_global_shortcut(&context);
    vte_terminal_spawn_async(
        terminal,
        VTE_PTY_DEFAULT,
        NULL,
        smoke ? smoke_argv : shell_argv,
        NULL,
        G_SPAWN_SEARCH_PATH,
        NULL,
        NULL,
        NULL,
        -1,
        NULL,
        on_spawned,
        &context);
    vte_terminal_spawn_async(
        VTE_TERMINAL(secondary_terminal_widget),
        VTE_PTY_DEFAULT,
        NULL,
        smoke ? smoke_argv : shell_argv,
        NULL,
        G_SPAWN_SEARCH_PATH,
        NULL,
        NULL,
        NULL,
        -1,
        NULL,
        on_secondary_spawned,
        &secondary);

    gtk_widget_show_all(window);
    gtk_widget_grab_focus(terminal_widget);
    if (mode == 0 && smoke == 0 && context.global_shortcut_registered) gtk_widget_hide(window);
    context.maintenance_timer = g_timeout_add(smoke != 0 ? 100 : 1000,
                                              on_maintenance_timer, &context);
    if (smoke != 0) {
        context.smoke_resize_source =
            g_timeout_add(50, request_smoke_resize, &context);
        context.smoke_marker_source =
            g_timeout_add(200, request_smoke_marker_check, &context);
        if (smoke == 1) {
            context.smoke_hide_source =
                g_timeout_add(500, request_smoke_hide, &context);
            context.smoke_shortcut_source =
                g_timeout_add(800, request_smoke_global_shortcut, &context);
        }
        if (smoke == 3) {
            context.smoke_recorder_source =
                g_timeout_add(300, request_smoke_recorder, &context);
            context.smoke_recorder_capture_source =
                g_timeout_add(600, request_smoke_recorder_capture, &context);
        }
        if (smoke == 4)
            context.smoke_recorder_source =
                g_timeout_add(300, request_smoke_recorder, &context);
    }
    gtk_main();
    if (context.maintenance_timer != 0) g_source_remove(context.maintenance_timer);
    clear_smoke_sources(&context);
    unregister_global_shortcut(&context);
    if (context.layer_shell_library != NULL)
        dlclose(context.layer_shell_library);
    return 0;
}
