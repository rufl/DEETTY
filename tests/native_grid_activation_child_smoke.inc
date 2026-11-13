/* Test-only activation child receipt helper. */
static gboolean write_activation_child_receipt_smoke(gpointer user_data) {
    DinttyGridContext *root = root_grid_context(user_data);
    const gchar *receipt_path = g_getenv("DINTTY_ACTIVATION_CHILD_RECEIPT");
    if (receipt_path == NULL || receipt_path[0] != '/') {
        finish_title_smoke(root);
        return G_SOURCE_REMOVE;
    }
    gboolean mapped = root->window != NULL && root->area != NULL &&
        root->window_presented && gtk_widget_get_mapped(root->window) &&
        gtk_widget_get_mapped(root->area);
    gboolean rendered = mapped && root->saw_draw;
    gint tab_count = root->notebook != NULL
        ? gtk_notebook_get_n_pages(GTK_NOTEBOOK(root->notebook)) : 0;
    if ((!rendered || tab_count != 2) &&
        root->activation_child_receipt_attempts++ < 200) {
        g_timeout_add(25, write_activation_child_receipt_smoke, root);
        return G_SOURCE_REMOVE;
    }
    if (rendered && tab_count == 2) {
        const gchar *source = g_getenv("DINTTY_ACTIVATION_SOURCE");
        const gchar *backend = g_getenv("GDK_BACKEND");
        gchar *receipt = g_strdup_printf(
            "native_grid_activation_child source=%s backend=%s mapped=true rendered=true tabs=2 controlled_exit=true\n",
            source != NULL ? source : "unknown",
            backend != NULL ? backend : "unknown");
        GError *error = NULL;
        if (!g_file_set_contents(receipt_path, receipt, -1, &error)) {
            g_printerr("native_grid_activation_receipt_failed path=%s detail=%s\n",
                       receipt_path,
                       error != NULL ? error->message : "unknown");
        }
        g_clear_error(&error);
        g_free(receipt);
    } else {
        g_printerr(
            "native_grid_activation_child_failed mapped=%d rendered=%d tabs=%d\n",
            mapped, rendered, tab_count);
    }
    finish_title_smoke(root);
    return G_SOURCE_REMOVE;
}

static gboolean request_recent_workspace_child_smoke(gpointer user_data) {
    DinttyGridContext *root = root_grid_context(user_data);
    gboolean surface_ready = root->window != NULL && root->area != NULL &&
        root->window_presented && gtk_widget_get_mapped(root->window) &&
        gtk_widget_get_mapped(root->area);
    if (!surface_ready && root->project_smoke_attempts++ < 200) {
        g_timeout_add(25, request_recent_workspace_child_smoke, root);
        return G_SOURCE_REMOVE;
    }
    root->project_smoke_attempts = 0;
    if (!surface_ready) {
        finish_title_smoke(root);
        return G_SOURCE_REMOVE;
    }
    open_project_tools(root);
    gboolean project_mapped = root->project_dialog != NULL &&
        gtk_widget_get_mapped(root->project_dialog);
    gboolean recent_ready = project_mapped &&
        GTK_IS_COMBO_BOX_TEXT(root->recent_workspace_combo) &&
        GTK_IS_BUTTON(root->recent_workspace_open) &&
        gtk_widget_get_sensitive(root->recent_workspace_open) &&
        root->recent_workspace_control &&
        root->project_summary_scrollable &&
        root->project_summary_accessible;
    root->recent_workspace_parent_rendered = project_mapped && recent_ready;
    if (recent_ready) {
        gtk_button_clicked(GTK_BUTTON(root->recent_workspace_open));
        root->recent_workspace_child_clicked = 1;
    }
    g_timeout_add(800, finish_title_smoke, root);
    return G_SOURCE_REMOVE;
}
