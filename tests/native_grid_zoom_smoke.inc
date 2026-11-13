/* Test-only recursive pane zoom geometry assertions. */

static guint recursive_zoom_branch_state(
    DeettyGridContext *target, guint *hidden_siblings) {
    GtkWidget *child = target->area;
    GtkWidget *parent = gtk_widget_get_parent(child);
    guint ancestors = 0;
    *hidden_siblings = 0;
    while (parent != NULL && parent != target->page) {
        if (GTK_IS_PANED(parent)) {
            GtkWidget *first = gtk_paned_get_child1(GTK_PANED(parent));
            GtkWidget *second = gtk_paned_get_child2(GTK_PANED(parent));
            GtkWidget *sibling = child == first ? second :
                child == second ? first : NULL;
            ancestors++;
            if (sibling != NULL && !gtk_widget_get_visible(sibling))
                (*hidden_siblings)++;
        }
        child = parent;
        parent = gtk_widget_get_parent(parent);
    }
    return ancestors;
}

static gboolean verify_recursive_zoom_restored(gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    guint active = 0;
    guint visible = 0;
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        DeettyGridContext *candidate = g_ptr_array_index(
            root->contexts, index);
        if (!candidate->active || candidate->exited ||
            candidate->page == NULL)
            continue;
        active++;
        if (gtk_widget_get_visible(candidate->area) &&
            gtk_widget_get_mapped(candidate->area))
            visible++;
    }
    root->recursive_zoom_restored = active == 4 && visible == active;
    return G_SOURCE_REMOVE;
}

static gboolean verify_recursive_zoom_full_page(gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    DeettyGridContext *target = grid_context_for_pane(
        root, root->zoomed_pane_id);
    if (target == NULL || target->page == NULL) return G_SOURCE_REMOVE;
    GtkWidget *content = grid_page_content_root(target, target->page);
    if (content == NULL) return G_SOURCE_REMOVE;

    GtkAllocation pane_allocation;
    GtkAllocation content_allocation;
    gtk_widget_get_allocation(target->area, &pane_allocation);
    gtk_widget_get_allocation(content, &content_allocation);
    guint hidden_siblings = 0;
    guint ancestors = recursive_zoom_branch_state(
        target, &hidden_siblings);
    root->recursive_zoom_full_page = ancestors >= 2 &&
        hidden_siblings == ancestors &&
        pane_allocation.width * 4 >= content_allocation.width * 3 &&
        pane_allocation.height * 4 >= content_allocation.height * 3;

    toggle_grid_zoom(target);
    g_timeout_add(100, verify_recursive_zoom_restored, root);
    return G_SOURCE_REMOVE;
}

static gboolean request_recursive_zoom_smoke(gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    if (root->contexts == NULL || root->contexts->len != 4)
        return G_SOURCE_REMOVE;
    DeettyGridContext *target = g_ptr_array_index(
        root->contexts, root->contexts->len - 1);
    toggle_grid_zoom(target);
    g_timeout_add(100, verify_recursive_zoom_full_page, root);
    return G_SOURCE_REMOVE;
}
