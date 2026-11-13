/* Test-only sharing dialog scope and recovery assertions. */
static gboolean inspect_sharing_scope_smoke(gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    GtkWidget *dialog = root->sharing_dialog;
    GtkWidget *share_pane = dialog != NULL
        ? g_object_get_data(G_OBJECT(dialog), "deetty-sharing-share-pane")
        : NULL;
    GtkWidget *share_tab = dialog != NULL
        ? g_object_get_data(G_OBJECT(dialog), "deetty-sharing-share-tab")
        : NULL;
    GtkWidget *share_session = dialog != NULL
        ? g_object_get_data(G_OBJECT(dialog), "deetty-sharing-share-session")
        : NULL;
    GtkWidget *tabs = dialog != NULL
        ? g_object_get_data(G_OBJECT(dialog), "deetty-sharing-tabs")
        : NULL;
    GtkWidget *streams = dialog != NULL
        ? g_object_get_data(G_OBJECT(dialog), "deetty-sharing-streams")
        : NULL;
    GtkWidget *preview = dialog != NULL
        ? g_object_get_data(G_OBJECT(dialog), "deetty-sharing-preview")
        : NULL;
    GtkWidget *peers = dialog != NULL
        ? g_object_get_data(G_OBJECT(dialog), "deetty-sharing-peers")
        : NULL;
    GtkWidget *alias = dialog != NULL
        ? g_object_get_data(G_OBJECT(dialog), "deetty-sharing-alias")
        : NULL;
    GtkWidget *endpoint = dialog != NULL
        ? g_object_get_data(G_OBJECT(dialog), "deetty-sharing-endpoint")
        : NULL;
    GtkWidget *status = dialog != NULL
        ? g_object_get_data(G_OBJECT(dialog), "deetty-sharing-status")
        : NULL;
    GtkWidget *stop = dialog != NULL
        ? g_object_get_data(G_OBJECT(dialog), "deetty-sharing-stop")
        : NULL;
    GtkWidget *stop_receive = dialog != NULL
        ? g_object_get_data(G_OBJECT(dialog), "deetty-sharing-stop-receive")
        : NULL;
    GtkWidget *retry_save = dialog != NULL
        ? g_object_get_data(G_OBJECT(dialog), "deetty-sharing-retry-save")
        : NULL;
    AtkObject *tabs_accessible = tabs != NULL
        ? gtk_widget_get_accessible(tabs) : NULL;
    AtkObject *streams_accessible = streams != NULL
        ? gtk_widget_get_accessible(streams) : NULL;
    AtkObject *preview_accessible = preview != NULL
        ? gtk_widget_get_accessible(preview) : NULL;
    AtkObject *status_accessible = status != NULL
        ? gtk_widget_get_accessible(status) : NULL;
    int preview_request_width = 0;
    int preview_request_height = 0;
    if (preview != NULL)
        gtk_widget_get_size_request(
            preview, &preview_request_width, &preview_request_height);
    gboolean form_accessible =
        peers != NULL && alias != NULL && endpoint != NULL && status != NULL &&
        widget_has_accessible_name(peers, "Paired device") &&
        widget_has_accessible_name(alias, "Remote alias") &&
        widget_has_accessible_name(endpoint, "Other device address") &&
        widget_has_accessible_name(status, "Session sharing status");
    gboolean status_accessible_ok =
        status_accessible != NULL &&
        atk_object_get_role(status_accessible) == ATK_ROLE_STATUSBAR;
    gboolean sharing_visual_polish =
        dialog != NULL &&
        gtk_style_context_has_class(
            gtk_widget_get_style_context(dialog),
            "deetty-sharing-dialog") &&
        share_pane != NULL &&
        gtk_style_context_has_class(
            gtk_widget_get_style_context(share_pane),
            "deetty-sharing-action") &&
        preview != NULL &&
        gtk_style_context_has_class(
            gtk_widget_get_style_context(preview),
            "deetty-sharing-preview") &&
        status != NULL &&
        gtk_style_context_has_class(
            gtk_widget_get_style_context(status),
            "deetty-sharing-status");
    gboolean sharing_action_tones =
        share_pane != NULL &&
        gtk_style_context_has_class(
            gtk_widget_get_style_context(share_pane),
            "deetty-sharing-action-primary") &&
        retry_save != NULL &&
        gtk_style_context_has_class(
            gtk_widget_get_style_context(retry_save),
            "deetty-sharing-action-primary") &&
        stop != NULL &&
        gtk_style_context_has_class(
            gtk_widget_get_style_context(stop),
            "deetty-sharing-action-danger") &&
        stop_receive != NULL &&
        gtk_style_context_has_class(
            gtk_widget_get_style_context(stop_receive),
            "deetty-sharing-action-danger");

    gboolean preview_request_bounded =
        preview_request_width > 0 && preview_request_width <= 480 &&
        preview_request_height > 0 && preview_request_height <= 260;
    gboolean recovery_policy =
        (deetty_grid_sharing_status_actions(205) &
         DEETTY_GRID_SHARING_CLEAR_HOST) != 0 &&
        (deetty_grid_sharing_status_actions(206) &
         DEETTY_GRID_SHARING_CLEAR_HOST) != 0 &&
        (deetty_grid_sharing_status_actions(305) &
         DEETTY_GRID_SHARING_CLEAR_VIEWER) != 0 &&
        (deetty_grid_sharing_status_actions(306) &
         DEETTY_GRID_SHARING_CLEAR_VIEWER) != 0 &&
        (deetty_grid_sharing_status_actions(104) &
         DEETTY_GRID_SHARING_ALLOW_PAIRING) != 0 &&
        (deetty_grid_sharing_status_actions(105) &
         DEETTY_GRID_SHARING_ALLOW_PAIRING) != 0 &&
        (deetty_grid_sharing_status_actions(201) &
         DEETTY_GRID_SHARING_ALLOW_PAIRING) == 0 &&
        (deetty_grid_sharing_status_actions(106) &
         DEETTY_GRID_SHARING_ALLOW_SESSION) != 0 &&
        (deetty_grid_sharing_status_actions(107) &
         DEETTY_GRID_SHARING_ALLOW_SESSION) != 0 &&
        (deetty_grid_sharing_status_actions(205) &
         DEETTY_GRID_SHARING_ALLOW_SESSION) == 0 &&
        stop != NULL && stop_receive != NULL && retry_save != NULL &&
        gtk_widget_get_sensitive(stop_receive) &&
        !gtk_widget_get_sensitive(share_pane) &&
        !gtk_widget_get_sensitive(share_tab) &&
        !gtk_widget_get_sensitive(share_session) &&
        GPOINTER_TO_INT(g_object_get_data(
            G_OBJECT(retry_save), "deetty-sharing-action")) == 18 &&
        sharing_selected_peer_index(GTK_COMBO_BOX(peers)) >= 0;
    int pane_click_ok = 0;
    if (preview != NULL && streams != NULL) {
        uint32_t x = 0;
        uint32_t y = 0;
        uint32_t width = 0;
        uint32_t height = 0;
        int selected = 0;
        int host_active = 0;
        if (deetty_grid_share_view_pane_layout(
                root->event_data, 1, &x, &y, &width, &height,
                &selected, &host_active) > 0) {
            GdkEventButton click = {0};
            click.button = GDK_BUTTON_PRIMARY;
            click.x = (double)gtk_widget_get_allocated_width(preview) *
                      ((double)x + (double)width / 2.0) / 1000000.0;
            click.y = (double)gtk_widget_get_allocated_height(preview) *
                      ((double)y + (double)height / 2.0) / 1000000.0;
            int clicked = on_sharing_preview_button(preview, &click, root);
            if (deetty_grid_share_view_pane_layout(
                    root->event_data, 1, &x, &y, &width, &height,
                    &selected, &host_active) > 0) {
                pane_click_ok =
                    clicked && selected &&
                    g_strcmp0(gtk_combo_box_get_active_id(
                                  GTK_COMBO_BOX(streams)),
                              "1") == 0;
            }
        }
    }
    root->sharing_scope_smoke_ok =
        dialog != NULL && gtk_widget_get_mapped(dialog) &&
        share_pane != NULL && share_tab != NULL && share_session != NULL &&
        GPOINTER_TO_INT(g_object_get_data(
            G_OBJECT(share_pane), "deetty-sharing-action")) == 15 &&
        GPOINTER_TO_INT(g_object_get_data(
            G_OBJECT(share_tab), "deetty-sharing-action")) == 5 &&
        GPOINTER_TO_INT(g_object_get_data(
            G_OBJECT(share_session), "deetty-sharing-action")) == 16 &&
        tabs_accessible != NULL &&
        g_strcmp0(atk_object_get_name(tabs_accessible), "Shared tab") == 0 &&
        streams_accessible != NULL &&
        g_strcmp0(atk_object_get_name(streams_accessible), "Shared pane") == 0 &&
        preview_accessible != NULL &&
        g_strcmp0(atk_object_get_name(preview_accessible),
                  "Remote terminal workspace") == 0 &&
        form_accessible && status_accessible_ok && preview_request_bounded &&
        sharing_visual_polish &&
        sharing_action_tones &&
        (root->sharing_layout_pane_mask & UINT64_C(3)) == UINT64_C(3) &&
        root->sharing_layout_selected_seen &&
        root->sharing_layout_host_active_seen &&
        pane_click_ok && recovery_policy;
    g_print("native_grid_sharing_scope_smoke dialog=%s pane=%s tab=%s "
            "session=%s selectors=%s preview=%s form_accessible=%s "
            "status_accessible=%s preview_bounded=%s layout=%s focus=%s "
            "click=%s recovery=%s tones=%s passed=%s\n",
            dialog != NULL && gtk_widget_get_mapped(dialog) ? "true" : "false",
            share_pane != NULL ? "true" : "false",
            share_tab != NULL ? "true" : "false",
            share_session != NULL ? "true" : "false",
            tabs_accessible != NULL && streams_accessible != NULL
                ? "true" : "false",
            preview_accessible != NULL ? "true" : "false",
            form_accessible ? "true" : "false",
            status_accessible_ok ? "true" : "false",
            preview_request_bounded ? "true" : "false",
            (root->sharing_layout_pane_mask & UINT64_C(3)) == UINT64_C(3)
                ? "true" : "false",
            root->sharing_layout_selected_seen &&
                    root->sharing_layout_host_active_seen
                ? "true" : "false",
            pane_click_ok ? "true" : "false",
            recovery_policy ? "true" : "false",
            sharing_action_tones ? "true" : "false",
            root->sharing_scope_smoke_ok ? "true" : "false");
    if (dialog != NULL) gtk_widget_destroy(dialog);
    return finish_title_smoke(root);
}

static gboolean reveal_sharing_preview_smoke(gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    GtkWidget *dialog = root->sharing_dialog;
    if (!GTK_IS_DIALOG(dialog))
        return finish_title_smoke(root);
    GtkWidget *scroll = g_object_get_data(
        G_OBJECT(dialog), "deetty-sharing-scroll");
    GtkWidget *preview = g_object_get_data(
        G_OBJECT(dialog), "deetty-sharing-preview");
    if (GTK_IS_SCROLLED_WINDOW(scroll)) {
        GtkAdjustment *adjustment =
            gtk_scrolled_window_get_vadjustment(
                GTK_SCROLLED_WINDOW(scroll));
        gtk_adjustment_set_value(
            adjustment,
            MAX(gtk_adjustment_get_lower(adjustment),
                gtk_adjustment_get_upper(adjustment) -
                    gtk_adjustment_get_page_size(adjustment)));
    }
    if (GTK_IS_WIDGET(preview)) gtk_widget_queue_draw(preview);
    g_timeout_add(200, inspect_sharing_scope_smoke, root);
    return G_SOURCE_REMOVE;
}

static gboolean request_sharing_scope_smoke(gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    show_session_sharing_dialog(root);
    g_timeout_add(150, reveal_sharing_preview_smoke, root);
    return G_SOURCE_REMOVE;
}

