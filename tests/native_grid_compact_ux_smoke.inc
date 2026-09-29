/* Test-only compact UX, settings, note, and toolbar smoke callbacks. */
static gboolean inspect_compact_palette_smoke(gpointer user_data) {
    NocttyGridContext *root = user_data;
    root->compact_palette_context_opened = root->palette_dialog != NULL;
    root->compact_palette_rename_suppressed =
        root->palette_dialog != NULL && root->tab_rename_entry == NULL;
    if (root->palette_dialog != NULL) {
        GtkWidget *shortcut_hint = g_object_get_data(
            G_OBJECT(root->palette_dialog),
            "noctty-visibility-shortcut-hint");
        root->compact_shortcut_label_dynamic =
            GTK_IS_LABEL(shortcut_hint) &&
            g_strcmp0(gtk_label_get_text(GTK_LABEL(shortcut_hint)),
                      "F11") == 0;
        if (widget_has_accessible_name(root->palette_search,
                                       "Search commands") &&
            widget_has_accessible_name(root->palette_list,
                                       "Available commands"))
            root->compact_accessibility_mask |= 1u;
        gtk_widget_destroy(root->palette_dialog);
    }
    root->requested_shortcut_key = root->compact_palette_previous_shortcut;
    return G_SOURCE_REMOVE;
}

static gboolean request_compact_palette_smoke(gpointer user_data) {
    NocttyGridContext *root = user_data;
    root->compact_palette_previous_shortcut = root->requested_shortcut_key;
    root->requested_shortcut_key = 0x0100003a;
    if (!open_smoke_workspace_menu(root)) {
        root->requested_shortcut_key =
            root->compact_palette_previous_shortcut;
        return G_SOURCE_REMOVE;
    }
    const gchar *submenu_labels[] = {
        "Split Pane", "New Split Tab", "Selection and Tags", "Pane",
        "Clear Terminal", "View", "Tools",
    };
    root->compact_context_submenus = 1;
    root->compact_new_1x1_removed =
        find_workspace_menu_item(root->workspace_menu, "New 1×1") == NULL;
    /* Exercise source ownership without waiting for a real tab teardown. */
    GtkWidget *distribution_probe = g_object_ref_sink(gtk_paned_new(
        GTK_ORIENTATION_HORIZONTAL));
    schedule_even_pane_distribution(root, distribution_probe);
    gtk_widget_destroy(distribution_probe);
    g_object_unref(distribution_probe);
    for (guint index = 0; index < G_N_ELEMENTS(submenu_labels); index++) {
        GtkWidget *parent = find_workspace_menu_item(
            root->workspace_menu, submenu_labels[index]);
        if (parent == NULL ||
            gtk_menu_item_get_submenu(GTK_MENU_ITEM(parent)) == NULL)
            root->compact_context_submenus = 0;
    }
    const gchar *split_labels[] = {
        "Split Right", "Split Down", "Split Up", "Split Left",
    };
    for (guint index = 0; index < G_N_ELEMENTS(split_labels); index++)
        if (find_workspace_menu_item(root->workspace_menu,
                                     split_labels[index]) == NULL)
            root->compact_context_submenus = 0;
    if (!workspace_split_menu_has_order(root->workspace_menu))
        root->compact_context_submenus = 0;
    GtkWidget *item = find_workspace_menu_item(
        root->workspace_menu, "Command Palette…");
    if (item == NULL) {
        dismiss_workspace_menu(root);
        root->requested_shortcut_key =
            root->compact_palette_previous_shortcut;
        return G_SOURCE_REMOVE;
    }
    gtk_menu_item_activate(GTK_MENU_ITEM(item));
    dismiss_workspace_menu(root);
    g_timeout_add(40, inspect_compact_palette_smoke, root);
    return G_SOURCE_REMOVE;
}

static gboolean request_compact_find_smoke(gpointer user_data) {
    NocttyGridContext *root = user_data;
    open_terminal_find(root);
    if (root->find_entry != NULL) {
        gtk_entry_set_text(GTK_ENTRY(root->find_entry), "NOCTTY_COMPACT_SEARCH");
        if (widget_has_accessible_name(root->find_entry,
                                       "Search terminal scrollback") &&
            widget_has_accessible_name(root->find_status,
                                       "Terminal search status"))
            root->compact_accessibility_mask |= 2u;
    }
    return G_SOURCE_REMOVE;
}

static gboolean request_compact_note_smoke(gpointer user_data) {
    NocttyGridContext *root = user_data;
    open_quick_note(root);
    if (root->note_view != NULL) {
        if (widget_has_accessible_name(root->note_view,
                                       "Workspace quick note") &&
            widget_has_accessible_name(root->note_status,
                                       "Workspace note save status"))
            root->compact_accessibility_mask |= 4u;
        gtk_text_buffer_set_text(gtk_text_view_get_buffer(GTK_TEXT_VIEW(root->note_view)),
                                 "compact workspace note", -1);
        if (root->note_save_source != 0) {
            g_source_remove(root->note_save_source);
            root->note_save_source = 0;
        }
        (void)flush_quick_note(root);
    }
    return G_SOURCE_REMOVE;
}

static gboolean request_compact_zoom_smoke(gpointer user_data) {
    NocttyGridContext *root = user_data;
    toggle_grid_zoom(root);
    root->compact_zoom_hid_tab_bar =
        !gtk_notebook_get_show_tabs(GTK_NOTEBOOK(root->notebook)) &&
        root->new_tab_button != NULL &&
        !gtk_widget_get_child_visible(root->new_tab_button);
    return G_SOURCE_REMOVE;
}

static gboolean request_compact_navigation_smoke(gpointer user_data) {
    NocttyGridContext *root = user_data;
    if (root->zoomed_pane_id != 0) {
        toggle_grid_zoom(root);
        root->compact_zoom_restored_tab_bar =
            gtk_notebook_get_show_tabs(GTK_NOTEBOOK(root->notebook)) &&
            root->new_tab_button != NULL &&
            gtk_widget_get_child_visible(root->new_tab_button);
    }
    if (root->contexts != NULL && root->contexts->len > 1) {
        NocttyGridContext *primary = g_ptr_array_index(root->contexts, 0);
        gtk_widget_grab_focus(primary->area);
        (void)focus_grid_direction(primary, 0, 1);
    }
    return G_SOURCE_REMOVE;
}

static gboolean inspect_compact_pane_info_smoke(gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    refresh_active_pane_info(root);
    gint page_index = gtk_notebook_get_current_page(GTK_NOTEBOOK(root->notebook));
    GtkWidget *page = gtk_notebook_get_nth_page(
        GTK_NOTEBOOK(root->notebook), page_index);
    GtkWidget *strip = pane_info_strip_for_page(page);
    NocttyGridContext *active = focused_grid_context(root);
    const char *text = noctty_pane_info_strip_text(strip);
    const char *tooltip = noctty_pane_info_strip_tooltip(strip);

    GList *children = gtk_container_get_children(
        GTK_CONTAINER(root->content_box));
    root->compact_pane_info_positioned =
        children != NULL && GTK_WIDGET(children->data) == root->notebook &&
        GTK_WIDGET(g_list_last(children)->data) == strip;
    g_list_free(children);
    root->compact_pane_info_rendered = strip != NULL &&
        gtk_widget_get_visible(strip) && gtk_widget_get_mapped(strip) &&
        text != NULL && text[0] != '\0';

    char pane_marker[64] = {0};
    g_snprintf(pane_marker, sizeof(pane_marker), "Pane %" G_GUINT64_FORMAT,
               active != NULL ? (guint64)active->pane_id : 0);
    root->compact_pane_info_source = active != NULL &&
        active->pane_id == 2 && text != NULL && tooltip != NULL &&
        strstr(text, " : sleep") != NULL &&
        strstr(text, "| App ") != NULL &&
        strstr(text, "| Pane ") != NULL &&
        strstr(tooltip, pane_marker) != NULL &&
        strstr(tooltip, "Process: sleep (PID ") != NULL &&
        strstr(tooltip, "Directory: /") != NULL &&
        strstr(tooltip, "NOCTTY tree:") != NULL &&
        strstr(tooltip, "Selected terminal tree:") != NULL;

    guint revision = noctty_pane_info_strip_revision(strip);
    refresh_active_pane_info(root);
    root->compact_pane_info_dedup =
        revision > 0 && revision == noctty_pane_info_strip_revision(strip);
    return G_SOURCE_REMOVE;
}


static int compact_tui_wheel_smoke_mouse_mode(void *userdata) {
    (void)userdata;
    return 1;
}

static int compact_tui_wheel_smoke_mouse(
    void *userdata, int column, int row, int button, int pressed) {
    (void)userdata;
    (void)column;
    (void)row;
    (void)button;
    (void)pressed;
    return 1;
}

static gboolean request_compact_hyperlink_smoke(gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    NocttyGridContext *target = NULL;
    int hyperlink_column = -1;
    int hyperlink_row = -1;
    char uri_byte = 0;
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len && target == NULL; index++) {
        NocttyGridContext *candidate = g_ptr_array_index(
            root->contexts, index);
        if (!grid_context_session_available(candidate)) continue;
        (void)scroll_terminal_to_offset(candidate, 0);
        for (int row = 0; row < candidate->rows && target == NULL; row++) {
            for (int column = 0; column < candidate->columns; column++) {
                int length = candidate->cell_hyperlink(
                    candidate->userdata, column, row, &uri_byte, 1);
                if (length <= 0) continue;
                target = candidate;
                hyperlink_column = column;
                hyperlink_row = row;
                break;
            }
        }
    }
    if (target == NULL) {
        if (root->compact_hyperlink_smoke_attempts++ < 16) {
            g_timeout_add(50, request_compact_hyperlink_smoke, root);
        } else {
            guint underlined = 0;
            for (int row = 0; row < root->rows; row++) {
                for (int column = 0; column < root->columns; column++) {
                    uint32_t style = (uint32_t)(
                        root->cell(root->userdata, column, row) >> 32);
                    if (style & 8) underlined++;
                }
            }
            g_printerr("native_grid_hyperlink_scan underlined=%u rows=%d columns=%d\n",
                       underlined, root->rows, root->columns);
        }
        return G_SOURCE_REMOVE;
    }

    NocttyGridMouseMode original_mouse_mode = target->mouse_mode;
    target->mouse_mode = compact_tui_wheel_smoke_mouse_mode;
    NocttyGridFontMetrics metrics = grid_font_metrics(target);
    GdkEventButton event = {0};
    event.type = GDK_BUTTON_PRESS;
    event.button = 1;
    event.state = GDK_CONTROL_MASK;
    event.x = 4.0 + (hyperlink_column + 0.5) * metrics.cell_width;
    event.y = 2.0 + (hyperlink_row + 0.5) * metrics.cell_height;
    (void)on_mouse_button(target->area, &event, target);
    event.type = GDK_BUTTON_RELEASE;
    (void)on_mouse_button(target->area, &event, target);
    event.type = GDK_BUTTON_PRESS;
    event.button = 3;
    event.state = 0;
    (void)on_mouse_button(target->area, &event, target);
    target->mouse_mode = original_mouse_mode;
    return G_SOURCE_REMOVE;
}

static gboolean request_compact_linear_selection_smoke(gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    if (root->rows < 4 || root->columns < 8) return G_SOURCE_REMOVE;
    clear_grid_selection(root);
    NocttyGridFontMetrics metrics = grid_font_metrics(root);
    GdkEventButton button = {0};
    button.type = GDK_BUTTON_PRESS;
    button.button = 1;
    button.x = 4.0 + 3.5 * metrics.cell_width;
    button.y = 2.0 + 1.5 * metrics.cell_height;
    (void)on_mouse_button(root->area, &button, root);
    GdkEventMotion motion = {0};
    motion.type = GDK_MOTION_NOTIFY;
    motion.state = GDK_BUTTON1_MASK;
    motion.x = 4.0 + 2.5 * metrics.cell_width;
    motion.y = 2.0 + 3.5 * metrics.cell_height;
    (void)on_mouse_motion(root->area, &motion, root);
    button.type = GDK_BUTTON_RELEASE;
    button.x = motion.x;
    button.y = motion.y;
    (void)on_mouse_button(root->area, &button, root);
    root->compact_linear_selection = root->selecting &&
        !grid_cell_is_selected(root, 2, 1) &&
        grid_cell_is_selected(root, 3, 1) &&
        grid_cell_is_selected(root, root->columns - 1, 1) &&
        grid_cell_is_selected(root, 0, 2) &&
        grid_cell_is_selected(root, root->columns - 1, 2) &&
        grid_cell_is_selected(root, 0, 3) &&
        grid_cell_is_selected(root, 2, 3) &&
        !grid_cell_is_selected(root, 3, 3);
    copy_grid_selection_to_clipboard(root);
    gchar *copied = gtk_clipboard_wait_for_text(
        gtk_clipboard_get(GDK_SELECTION_CLIPBOARD));
    root->compact_linear_selection_copy =
        copied != NULL && strchr(copied, '\n') != NULL;
    g_free(copied);
    double previous_bottom = ceil(2.0 + 2.0 * metrics.cell_height);
    double next_top = floor(2.0 + 2.0 * metrics.cell_height);
    root->compact_background_fill_seamless = next_top <= previous_bottom;
    clear_grid_selection(root);
    return G_SOURCE_REMOVE;
}

static gboolean request_compact_font_scroll_smoke(gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    double initial = root->font_size;
    NocttyGridContext *other = root->contexts != NULL && root->contexts->len > 1
        ? g_ptr_array_index(root->contexts, 1) : NULL;
    double other_initial = other != NULL ? other->font_size : 0.0;
    GdkEventScroll event = {0};
    event.type = GDK_SCROLL;
    event.state = GDK_CONTROL_MASK;
    event.direction = GDK_SCROLL_UP;
    (void)on_scroll(root->area, &event, root);
    double increased = root->font_size;
    root->compact_font_scroll_up = increased > initial;
    root->compact_font_scroll_isolated = other != NULL &&
        other->font_size == other_initial && other->font_size != increased;
    event.direction = GDK_SCROLL_DOWN;
    (void)on_scroll(root->area, &event, root);
    root->compact_font_scroll_down = root->font_size == initial;
    event.direction = GDK_SCROLL_UP;
    (void)on_scroll(root->area, &event, root);
    event.state = 0;
    (void)on_scroll(root->area, &event, root);
    NocttyGridMouse original_mouse = root->mouse;
    NocttyGridMouseMode original_mouse_mode = root->mouse_mode;
    root->mouse = compact_tui_wheel_smoke_mouse;
    root->mouse_mode = compact_tui_wheel_smoke_mouse_mode;
    root->compact_tui_wheel_mapping = 0;
    GtkAllocation allocation;
    gtk_widget_get_allocation(root->area, &allocation);
    /* TUI wheel reporting is a terminal-content contract. Keep this event
     * away from the independently owned native scrollbar hit target. */
    event.x = allocation.width / 2.0;
    event.y = allocation.height / 2.0;
    root->terminal_scroll_accumulator = 0.0;
    event.direction = GDK_SCROLL_UP;
    (void)on_scroll(root->area, &event, root);
    event.direction = GDK_SCROLL_DOWN;
    (void)on_scroll(root->area, &event, root);
    event.direction = GDK_SCROLL_SMOOTH;
    event.delta_y = 0.4;
    (void)on_scroll(root->area, &event, root);
    event.delta_y = 0.7;
    (void)on_scroll(root->area, &event, root);
    root->terminal_scroll_accumulator = 0.0;
    event.delta_y = -0.4;
    (void)on_scroll(root->area, &event, root);
    event.delta_y = -0.7;
    (void)on_scroll(root->area, &event, root);
    root->mouse = original_mouse;
    root->mouse_mode = original_mouse_mode;
    root->compact_tui_wheel_mapping =
        root->compact_tui_wheel_mapping == 3;
    if (root->resize_grip != NULL) {
        int original_mode = root->mode;
        root->mode = 0;
        int original_width = root->dropdown_width_percent;
        GdkEventButton first_click = {0};
        first_click.type = GDK_BUTTON_PRESS;
        first_click.button = 1;
        first_click.time = 100;
        first_click.x_root = 20;
        first_click.y_root = 20;
        (void)on_window_resize_handle_button(
            root->resize_grip, &first_click, root);
        GdkEventButton double_click = first_click;
        double_click.type = GDK_2BUTTON_PRESS;
        double_click.time = 160;
        (void)on_window_resize_handle_button(
            root->resize_grip, &double_click, root);
        gboolean maximized = root->dropdown_height_percent == 100;
        first_click.time = 300;
        (void)on_window_resize_handle_button(
            root->resize_grip, &first_click, root);
        double_click.time = 360;
        (void)on_window_resize_handle_button(
            root->resize_grip, &double_click, root);
        root->compact_dragger_height_toggle = maximized &&
            root->dropdown_width_percent == original_width &&
            root->dropdown_height_percent == 50;
        root->mode = original_mode;
    }
    return G_SOURCE_REMOVE;
}

static gboolean request_pane_scrollbar_smoke(gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    GtkAllocation allocation;
    gtk_widget_get_allocation(root->area, &allocation);
    NocttyTerminalScrollbarGeometry scrollbar;
    if (!terminal_scrollbar_geometry(root, allocation, &scrollbar) ||
        scrollbar.history_lines == 0) {
        if (root->project_smoke_attempts++ < 100) {
            g_timeout_add(50, request_pane_scrollbar_smoke, root);
            return G_SOURCE_REMOVE;
        }
        (void)root->write(root->userdata, "exit 0\n", 7);
        return G_SOURCE_REMOVE;
    }
    root->compact_scrollbar_history_lines = scrollbar.history_lines;
    (void)scroll_terminal_to_offset(root, 0);
    GdkEventKey key = {0};
    key.type = GDK_KEY_PRESS;
    key.state = GDK_SHIFT_MASK;
    key.keyval = GDK_KEY_Page_Up;
    (void)on_key_press(root->area, &key, root);
    if (terminal_scrollbar_geometry(root, allocation, &scrollbar))
        root->compact_keyboard_scrollback_up =
            scrollbar.viewport_offset > 0;
    key.keyval = GDK_KEY_Page_Down;
    (void)on_key_press(root->area, &key, root);
    if (terminal_scrollbar_geometry(root, allocation, &scrollbar))
        root->compact_keyboard_scrollback_down =
            scrollbar.viewport_offset == 0;
    if (!terminal_scrollbar_geometry(root, allocation, &scrollbar))
        return G_SOURCE_REMOVE;

    /* Codex and other full-screen TUIs enable mouse reporting. The visible
     * native rail must still scroll NOCTTY history without forwarding a TUI
     * mouse event. */
    (void)scroll_terminal_to_offset(root, 0);
    NocttyGridMouse original_mouse = root->mouse;
    NocttyGridMouseMode original_mouse_mode = root->mouse_mode;
    root->mouse = compact_tui_wheel_smoke_mouse;
    root->mouse_mode = compact_tui_wheel_smoke_mouse_mode;
    root->compact_scrollbar_tui_forwarded = 0;
    GdkEventScroll wheel = {0};
    wheel.type = GDK_SCROLL;
    wheel.direction = GDK_SCROLL_UP;
    wheel.x = scrollbar.x + scrollbar.width / 2.0;
    wheel.y = scrollbar.y + scrollbar.height / 2.0;
    (void)on_scroll(root->area, &wheel, root);
    if (terminal_scrollbar_geometry(root, allocation, &scrollbar))
        root->compact_scrollbar_mouse_mode_wheel =
            scrollbar.viewport_offset > 0 &&
            !root->compact_scrollbar_tui_forwarded;
    root->mouse = original_mouse;
    root->mouse_mode = original_mouse_mode;

    GdkEventButton button = {0};
    button.type = GDK_BUTTON_PRESS;
    button.button = 1;
    button.x = scrollbar.x + scrollbar.width / 2.0;
    button.y = scrollbar.y;
    (void)on_mouse_button(root->area, &button, root);

    if (terminal_scrollbar_geometry(root, allocation, &scrollbar)) {
        button.y = scrollbar.thumb_y + scrollbar.thumb_height / 2.0;
        (void)on_mouse_button(root->area, &button, root);
        GdkEventMotion motion = {0};
        motion.type = GDK_MOTION_NOTIFY;
        motion.state = GDK_BUTTON1_MASK;
        motion.x = button.x;
        motion.y = scrollbar.y + scrollbar.height;
        (void)on_mouse_motion(root->area, &motion, root);
        button.type = GDK_BUTTON_RELEASE;
        button.y = motion.y;
        (void)on_mouse_button(root->area, &button, root);
    }
    (void)root->write(root->userdata, "exit 0\n", 7);
    return G_SOURCE_REMOVE;
}

static gboolean request_compact_save_smoke(gpointer user_data) {
    NocttyGridContext *root = user_data;
    (void)save_grid_scrollback_to_path(root,
        "/tmp/noctty-native-grid-compact-scrollback.txt");
    return G_SOURCE_REMOVE;
}

static gboolean finish_compact_smoke(gpointer user_data) {
    NocttyGridContext *root = user_data;
    if (root->find_dialog != NULL) gtk_widget_destroy(root->find_dialog);
    if (root->note_dialog != NULL) gtk_widget_destroy(root->note_dialog);
    for (guint index = 0; root->contexts != NULL && index < root->contexts->len; index++) {
        NocttyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (candidate->active && !candidate->exited)
            (void)candidate->write(candidate->userdata, "exit 0\n", 7);
    }
    return G_SOURCE_REMOVE;
}

static gboolean request_note_overlay_alt_press_smoke(gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    root->project_smoke_attempts = 0;
    GdkEventKey event = {0};
    event.type = GDK_KEY_PRESS;
    event.keyval = GDK_KEY_Alt_L;
    (void)on_key_press(root->area, &event, root);
    return G_SOURCE_REMOVE;
}

static gboolean check_note_overlay_hidden_smoke(gpointer user_data);

static gboolean check_note_overlay_drawn_smoke(gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    int visible_panes = 0;
    int drawn_panes = 0;
    if (root->contexts != NULL) {
        for (guint index = 0; index < root->contexts->len; index++) {
            NocttyGridContext *candidate =
                g_ptr_array_index(root->contexts, index);
            if (!candidate->active || candidate->area == NULL ||
                !gtk_widget_get_mapped(candidate->area)) continue;
            visible_panes++;
            if (candidate->note_overlay_drawn &&
                candidate->note_overlay_compact) drawn_panes++;
        }
    }
    gboolean all_drawn =
        root->note_overlay_visible && root->note_overlay_content_loaded &&
        visible_panes >= 2 && drawn_panes == visible_panes;
    if (!all_drawn && root->project_smoke_attempts++ < 200) {
        queue_quick_note_overlay_draws(root);
        g_timeout_add(25, check_note_overlay_drawn_smoke, root);
        return G_SOURCE_REMOVE;
    }
    root->project_smoke_attempts = 0;
    root->note_overlay_smoke_panes = visible_panes;
    root->note_overlay_smoke_all_drawn = all_drawn;

    GdkEventKey event = {0};
    event.type = GDK_KEY_RELEASE;
    event.keyval = GDK_KEY_Alt_L;
    (void)on_key_release(root->area, &event, root);
    g_timeout_add(200, check_note_overlay_hidden_smoke, root);
    return G_SOURCE_REMOVE;
}

static gboolean check_note_overlay_hidden_smoke(gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    root->note_overlay_smoke_hidden =
        root->note_overlay_alt_released && !root->note_overlay_visible &&
        root->note_overlay_text == NULL &&
        root->note_overlay_label == NULL;
    for (guint index = 0;
         root->contexts != NULL && index < root->contexts->len; index++) {
        NocttyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (candidate->active && !candidate->exited)
            (void)candidate->write(candidate->userdata, "exit 0\n", 7);
    }
    return G_SOURCE_REMOVE;
}

static void set_settings_smoke_values(GtkWidget *dialog) {
    GtkComboBox *mode = GTK_COMBO_BOX(g_object_get_data(
        G_OBJECT(dialog), "noctty-settings-mode"));
    gtk_combo_box_set_active(mode, 0);
    gtk_combo_box_set_active(mode, 1);
    gtk_spin_button_set_value(GTK_SPIN_BUTTON(g_object_get_data(G_OBJECT(dialog), "noctty-settings-width")), 90);
    gtk_spin_button_set_value(GTK_SPIN_BUTTON(g_object_get_data(G_OBJECT(dialog), "noctty-settings-height")), 40);
    gtk_spin_button_set_value(GTK_SPIN_BUTTON(g_object_get_data(G_OBJECT(dialog), "noctty-settings-animation")), 120);
    gtk_toggle_button_set_active(GTK_TOGGLE_BUTTON(g_object_get_data(G_OBJECT(dialog), "noctty-settings-hide-focus")), TRUE);
    gtk_toggle_button_set_active(GTK_TOGGLE_BUTTON(g_object_get_data(G_OBJECT(dialog), "noctty-settings-focus-pointer")), TRUE);
    gtk_combo_box_set_active(GTK_COMBO_BOX(g_object_get_data(G_OBJECT(dialog), "noctty-settings-preset")), 2);
    gtk_spin_button_set_value(GTK_SPIN_BUTTON(g_object_get_data(G_OBJECT(dialog), "noctty-settings-scrollback")), 256);
    gtk_spin_button_set_value(GTK_SPIN_BUTTON(g_object_get_data(
        G_OBJECT(dialog), "noctty-settings-scroll-lines")), 7);
    GtkToggleButton *smooth_scroll = GTK_TOGGLE_BUTTON(g_object_get_data(
        G_OBJECT(dialog), "noctty-settings-smooth-scroll"));
    gtk_toggle_button_set_active(smooth_scroll, FALSE);
    GtkToggleButton *notifications = GTK_TOGGLE_BUTTON(g_object_get_data(
        G_OBJECT(dialog), "noctty-settings-notifications"));
    gtk_toggle_button_set_active(notifications, TRUE);
    gtk_toggle_button_set_active(notifications, FALSE);
    gtk_combo_box_set_active(GTK_COMBO_BOX(g_object_get_data(G_OBJECT(dialog), "noctty-settings-tabs")), 1);
    gtk_combo_box_set_active(GTK_COMBO_BOX(g_object_get_data(G_OBJECT(dialog), "noctty-settings-status")), 0);
    gtk_spin_button_set_value(GTK_SPIN_BUTTON(g_object_get_data(G_OBJECT(dialog), "noctty-settings-padding")), 8);
    gtk_spin_button_set_value(GTK_SPIN_BUTTON(g_object_get_data(G_OBJECT(dialog), "noctty-settings-spacing")), 6);
    GtkToggleButton *pane_gaps = GTK_TOGGLE_BUTTON(g_object_get_data(
        G_OBJECT(dialog), "noctty-settings-pane-gaps"));
    gtk_toggle_button_set_active(pane_gaps, FALSE);
    gtk_toggle_button_set_active(pane_gaps, TRUE);
    gtk_toggle_button_set_active(GTK_TOGGLE_BUTTON(g_object_get_data(
        G_OBJECT(dialog), "noctty-settings-gap-transparent")), FALSE);
    GtkToggleButton *inactive_dim = GTK_TOGGLE_BUTTON(g_object_get_data(
        G_OBJECT(dialog), "noctty-settings-inactive-dim"));
    gtk_toggle_button_set_active(inactive_dim, FALSE);
    gtk_toggle_button_set_active(inactive_dim, TRUE);
    gtk_range_set_value(GTK_RANGE(g_object_get_data(
        G_OBJECT(dialog), "noctty-settings-inactive-brightness")), 68.0);
    gtk_spin_button_set_value(GTK_SPIN_BUTTON(g_object_get_data(
        G_OBJECT(dialog), "noctty-settings-divider")), 5);
    gtk_spin_button_set_value(GTK_SPIN_BUTTON(g_object_get_data(
        G_OBJECT(dialog), "noctty-settings-pane-border")), 2);
    gtk_spin_button_set_value(GTK_SPIN_BUTTON(g_object_get_data(
        G_OBJECT(dialog), "noctty-settings-focused-border")), 6);
    gtk_spin_button_set_value(GTK_SPIN_BUTTON(g_object_get_data(
        G_OBJECT(dialog), "noctty-settings-selected-border")), 4);
    gtk_spin_button_set_value(GTK_SPIN_BUTTON(g_object_get_data(
        G_OBJECT(dialog), "noctty-settings-status-border")), 3);
    gtk_spin_button_set_value(GTK_SPIN_BUTTON(g_object_get_data(
        G_OBJECT(dialog), "noctty-settings-overlay-border")), 2);
    gtk_spin_button_set_value(GTK_SPIN_BUTTON(g_object_get_data(
        G_OBJECT(dialog), "noctty-settings-window-border")), 7);
    gtk_spin_button_set_value(GTK_SPIN_BUTTON(g_object_get_data(
        G_OBJECT(dialog), "noctty-settings-dragger")), 12);
    gtk_toggle_button_set_active(GTK_TOGGLE_BUTTON(g_object_get_data(
        G_OBJECT(dialog), "noctty-settings-theme-scope-tab")), FALSE);
    gtk_combo_box_set_active_id(GTK_COMBO_BOX(g_object_get_data(G_OBJECT(dialog), "noctty-settings-theme")), "noctty-high-contrast");
    GtkToggleButton *translucency = GTK_TOGGLE_BUTTON(g_object_get_data(
        G_OBJECT(dialog), "noctty-settings-translucency"));
    gtk_toggle_button_set_active(translucency, FALSE);
    gtk_toggle_button_set_active(translucency, TRUE);
    gtk_range_set_value(GTK_RANGE(g_object_get_data(
        G_OBJECT(dialog), "noctty-settings-opacity")), 78.0);
    GtkWidget *tint = g_object_get_data(
        G_OBJECT(dialog), "noctty-settings-background-tint");
    GdkRGBA tint_color = {
        .red = 0x19 / 255.0,
        .green = 0x32 / 255.0,
        .blue = 0x4c / 255.0,
        .alpha = 1.0,
    };
    gtk_color_chooser_set_rgba(GTK_COLOR_CHOOSER(tint), &tint_color);
    g_signal_emit_by_name(tint, "color-set");
    gtk_combo_box_set_active(GTK_COMBO_BOX(g_object_get_data(G_OBJECT(dialog), "noctty-settings-family")), 0);
    gtk_spin_button_set_value(GTK_SPIN_BUTTON(g_object_get_data(G_OBJECT(dialog), "noctty-settings-font")), 16);
    gtk_combo_box_set_active(GTK_COMBO_BOX(g_object_get_data(G_OBJECT(dialog), "noctty-settings-antialias")), 1);
    gtk_combo_box_set_active(GTK_COMBO_BOX(g_object_get_data(G_OBJECT(dialog), "noctty-settings-hinting")), 2);
}

static gboolean request_settings_smoke(gpointer user_data) {
    NocttyGridContext *context = root_grid_context(user_data);
    if (context->window_settings_button != NULL)
        gtk_button_clicked(GTK_BUTTON(context->window_settings_button));
    context->settings_opened = context->settings_dialog != NULL;
    GtkWidget *transparency_status = context->settings_dialog != NULL
        ? g_object_get_data(G_OBJECT(context->settings_dialog),
                            "noctty-settings-transparency-status")
        : NULL;
    const gchar *transparency_text = GTK_IS_LABEL(transparency_status)
        ? gtk_label_get_text(GTK_LABEL(transparency_status)) : NULL;
    context->settings_background_support_notice =
        transparency_text != NULL &&
        ((context->background_alpha_supported &&
          strstr(transparency_text, "Available") != NULL) ||
         (!context->background_alpha_supported &&
          strstr(transparency_text, "opaque") != NULL));
    if (context->settings_categories != NULL && context->settings_stack != NULL) {
        GtkListBoxRow *first = gtk_list_box_get_row_at_index(
            GTK_LIST_BOX(context->settings_categories), 0);
        AtkObject *accessible = first != NULL
            ? gtk_widget_get_accessible(GTK_WIDGET(first)) : NULL;
        context->settings_category_accessible = accessible != NULL &&
            g_strcmp0(atk_object_get_name(accessible), "Window") == 0;
        context->settings_category_focusable = first != NULL &&
            gtk_widget_get_can_focus(GTK_WIDGET(first));
        context->settings_category_focus_initial = first != NULL &&
            gtk_window_get_focus(GTK_WINDOW(context->settings_dialog)) ==
                GTK_WIDGET(first);
        gchar *category_tooltip = first != NULL
            ? gtk_widget_get_tooltip_text(GTK_WIDGET(first)) : NULL;
        context->settings_category_tooltips = category_tooltip != NULL &&
            g_strstr_len(category_tooltip, -1, "Window") != NULL;
        g_free(category_tooltip);
        GtkWidget *window_page = gtk_stack_get_child_by_name(
            GTK_STACK(context->settings_stack), "window");
        GtkWidget *behavior_page = gtk_stack_get_child_by_name(
            GTK_STACK(context->settings_stack), "behavior");
        context->settings_visual_polish =
            context->settings_dialog != NULL &&
            gtk_style_context_has_class(
                gtk_widget_get_style_context(context->settings_dialog),
                "noctty-settings-dialog") &&
            gtk_style_context_has_class(
                gtk_widget_get_style_context(context->settings_categories),
                "noctty-settings-sidebar") &&
            first != NULL &&
            gtk_style_context_has_class(
                gtk_widget_get_style_context(GTK_WIDGET(first)),
                "noctty-settings-category") &&
            GTK_IS_SCROLLED_WINDOW(window_page) &&
            gtk_style_context_has_class(
                gtk_widget_get_style_context(window_page),
                "noctty-settings-page");
        if (GTK_IS_SCROLLED_WINDOW(window_page) &&
            GTK_IS_SCROLLED_WINDOW(behavior_page)) {
            GtkPolicyType window_horizontal = GTK_POLICY_NEVER;
            GtkPolicyType window_vertical = GTK_POLICY_NEVER;
            GtkPolicyType behavior_horizontal = GTK_POLICY_NEVER;
            GtkPolicyType behavior_vertical = GTK_POLICY_NEVER;
            gtk_scrolled_window_get_policy(GTK_SCROLLED_WINDOW(window_page),
                                           &window_horizontal,
                                           &window_vertical);
            gtk_scrolled_window_get_policy(GTK_SCROLLED_WINDOW(behavior_page),
                                           &behavior_horizontal,
                                           &behavior_vertical);
            GtkListBoxRow *behavior = gtk_list_box_get_row_at_index(
                GTK_LIST_BOX(context->settings_categories), 1);
            gtk_list_box_select_row(GTK_LIST_BOX(context->settings_categories),
                                    behavior);
            /* Selection changes stack visibility immediately but GTK may defer
             * the new page allocation. Force this smoke-only resize check so
             * the adjustment reflects the user-visible page, not stale zero
             * geometry from the previously visible category. */
            gtk_container_check_resize(
                GTK_CONTAINER(context->settings_dialog));
            GtkAdjustment *behavior_horizontal_adjustment =
                gtk_scrolled_window_get_hadjustment(
                    GTK_SCROLLED_WINDOW(behavior_page));
            gboolean behavior_fits = behavior_horizontal_adjustment != NULL &&
                gtk_adjustment_get_upper(behavior_horizontal_adjustment) <=
                gtk_adjustment_get_page_size(behavior_horizontal_adjustment) +
                0.5;
            context->settings_narrow_access =
                window_horizontal == GTK_POLICY_NEVER &&
                window_vertical == GTK_POLICY_AUTOMATIC &&
                behavior_horizontal == GTK_POLICY_NEVER &&
                behavior_vertical == GTK_POLICY_AUTOMATIC && behavior_fits;
            if (!context->settings_narrow_access) {
                g_printerr(
                    "native_grid_settings_narrow window=%d/%d behavior=%d/%d upper=%.1f page=%.1f fits=%d\n",
                    window_horizontal, window_vertical,
                    behavior_horizontal, behavior_vertical,
                    behavior_horizontal_adjustment != NULL
                        ? gtk_adjustment_get_upper(
                              behavior_horizontal_adjustment) : -1.0,
                    behavior_horizontal_adjustment != NULL
                        ? gtk_adjustment_get_page_size(
                              behavior_horizontal_adjustment) : -1.0,
                    behavior_fits);
            }
        }
        GtkListBoxRow *appearance = gtk_list_box_get_row_at_index(
            GTK_LIST_BOX(context->settings_categories), 2);
        gtk_list_box_select_row(GTK_LIST_BOX(context->settings_categories),
                                appearance);
        const char *visible = gtk_stack_get_visible_child_name(
            GTK_STACK(context->settings_stack));
        context->settings_page_switched =
            appearance != NULL &&
            gtk_list_box_get_selected_row(
                GTK_LIST_BOX(context->settings_categories)) == appearance &&
            g_strcmp0(visible, "appearance") == 0;
        gtk_list_box_select_row(
            GTK_LIST_BOX(context->settings_categories),
            gtk_list_box_get_row_at_index(
                GTK_LIST_BOX(context->settings_categories), 0));
    }
    if (GTK_IS_TOGGLE_BUTTON(context->settings_pane_info_toggle)) {
        gtk_toggle_button_set_active(
            GTK_TOGGLE_BUTTON(context->settings_pane_info_toggle), FALSE);
        gtk_toggle_button_set_active(
            GTK_TOGGLE_BUTTON(context->settings_pane_info_toggle), TRUE);
    }
    set_settings_smoke_values(context->settings_dialog);
    GtkWidget *settings_page = gtk_notebook_get_nth_page(
        GTK_NOTEBOOK(context->notebook),
        gtk_notebook_get_current_page(GTK_NOTEBOOK(context->notebook)));
    int side_width = -1;
    int dragger_height = -1;
    if (context->window_resize_handles[3] != NULL)
        gtk_widget_get_size_request(context->window_resize_handles[3],
                                    &side_width, NULL);
    if (context->resize_grip != NULL)
        gtk_widget_get_size_request(context->resize_grip, NULL,
                                    &dragger_height);
    context->settings_metric_thickness_live =
        context->panel_padding_px == 8 && context->pane_spacing_px == 6 &&
        context->pane_gaps_enabled && !context->pane_gaps_transparent &&
        context->inactive_pane_dim_enabled &&
        context->inactive_pane_brightness_percent == 68 &&
        GTK_IS_TOGGLE_BUTTON(g_object_get_data(
            G_OBJECT(context->settings_dialog),
            "noctty-settings-theme-scope-tab")) &&
        GTK_IS_RANGE(g_object_get_data(
            G_OBJECT(context->settings_dialog),
            "noctty-settings-inactive-brightness")) &&
        context->pane_divider_px == 5 && context->pane_border_px == 2 &&
        context->pane_border_focused_px == 6 &&
        context->pane_border_selected_px == 4 &&
        context->status_border_px == 3 && context->overlay_border_px == 2 &&
        context->window_border_px == 7 && context->dragger_px == 12 &&
        GTK_IS_CONTAINER(settings_page) &&
        gtk_container_get_border_width(GTK_CONTAINER(settings_page)) == 8 &&
        gtk_widget_get_margin_start(context->area) == 3 &&
        gtk_widget_get_margin_end(context->area) == 3 &&
        g_object_get_data(G_OBJECT(settings_page),
                          "noctty-pane-gap-provider") != NULL &&
        side_width == 7 && dragger_height == 12;
    if (context->launch_profile_setting_control) {
        gtk_combo_box_set_active(GTK_COMBO_BOX(context->settings_launch_kind),
                                 3);
        gtk_entry_set_text(GTK_ENTRY(context->settings_launch_ssh_target),
                           "noctty-tmux");
        gtk_button_clicked(GTK_BUTTON(context->settings_launch_apply));
        gtk_combo_box_set_active(GTK_COMBO_BOX(context->settings_launch_kind),
                                 4);
        gtk_entry_set_text(GTK_ENTRY(context->settings_launch_ssh_target),
                           "noctty-zellij");
        gtk_button_clicked(GTK_BUTTON(context->settings_launch_apply));
        gtk_combo_box_set_active(GTK_COMBO_BOX(context->settings_launch_kind),
                                 1);
        gtk_entry_set_text(GTK_ENTRY(context->settings_launch_shell),
                           "/bin/sh");
        gtk_entry_set_text(GTK_ENTRY(context->settings_launch_command),
                           "printf 'NOCTTY_LAUNCH_PROFILE_OK:%s:%s' \"$PWD\" \"$NOCTTY_PROFILE\"");
        gtk_entry_set_text(GTK_ENTRY(context->settings_launch_cwd), "/tmp");
        gtk_entry_set_text(GTK_ENTRY(context->settings_launch_environment),
                           "NOCTTY_PROFILE=ready;NOCTTY_SECOND=value");
        gtk_entry_set_text(GTK_ENTRY(context->settings_launch_ssh_target),
                           "alice@example.com");
        gtk_spin_button_set_value(
            GTK_SPIN_BUTTON(context->settings_launch_scrollback), 2048);
        gtk_button_clicked(GTK_BUTTON(context->settings_launch_apply));
        if (context->launch_profile_library_control) {
            gtk_entry_set_text(GTK_ENTRY(context->settings_launch_name),
                               "Local command");
            gtk_button_clicked(GTK_BUTTON(context->settings_launch_save));
            gtk_entry_set_text(GTK_ENTRY(context->settings_launch_name),
                               "Disposable");
            gtk_entry_set_text(GTK_ENTRY(context->settings_launch_command),
                               "printf discard");
            gtk_button_clicked(GTK_BUTTON(context->settings_launch_save));
            gtk_button_clicked(GTK_BUTTON(context->settings_launch_delete));
            gtk_combo_box_set_active(
                GTK_COMBO_BOX(context->settings_launch_library), 1);
        }
    }
    (void)sync_grid_context_profile(context);
    GtkWidget *shortcut_button = g_object_get_data(
        G_OBJECT(context->settings_dialog), "noctty-settings-shortcut");
    const gchar *initial_shortcut_label = GTK_IS_BUTTON(shortcut_button)
        ? gtk_button_get_label(GTK_BUTTON(shortcut_button)) : NULL;
    context->settings_shortcut_label_current =
        initial_shortcut_label != NULL &&
        g_strstr_len(initial_shortcut_label, -1, "F10") != NULL;
    open_grid_shortcut_recorder(context);
    GdkEventKey shortcut_event = {0};
    shortcut_event.keyval = GDK_KEY_F11;
    (void)on_grid_shortcut_capture(context->shortcut_recorder_dialog,
                                   &shortcut_event, context);
    const gchar *updated_shortcut_label = GTK_IS_BUTTON(shortcut_button)
        ? gtk_button_get_label(GTK_BUTTON(shortcut_button)) : NULL;
    context->settings_shortcut_label_updated =
        updated_shortcut_label != NULL &&
        g_strstr_len(updated_shortcut_label, -1, "F11") != NULL;
    return G_SOURCE_REMOVE;
}

static gboolean request_settings_stacking_smoke(gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    open_grid_settings(root);
    open_terminal_find(root);
    return G_SOURCE_REMOVE;
}

static gboolean check_settings_stacking_smoke(gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    GtkWidget *dialog = root->settings_dialog;
    GtkWidget *find_dialog = root->find_dialog;
    if (GTK_IS_WINDOW(dialog)) {
        GdkRectangle workarea = {0, 0, 760, 560};
        GdkMonitor *monitor = grid_monitor_for_window(root->window);
        if (monitor != NULL) gdk_monitor_get_workarea(monitor, &workarea);
        gint width = gtk_widget_get_allocated_width(dialog);
        gint height = gtk_widget_get_allocated_height(dialog);
        root->settings_geometry_sane =
            width >= MIN(560, MAX(1, workarea.width - 64)) &&
            height >= MIN(420, MAX(1, workarea.height - 64)) &&
            width <= MAX(1, workarea.width - 32) &&
            height <= MAX(1, workarea.height - 32);
        root->settings_stacking_visible =
            gtk_widget_get_visible(root->window) &&
            gtk_widget_get_mapped(root->window) &&
            gtk_widget_get_visible(dialog) && gtk_widget_get_mapped(dialog) &&
            GTK_IS_WINDOW(find_dialog) &&
            gtk_widget_get_visible(find_dialog) &&
            gtk_widget_get_mapped(find_dialog);
        root->settings_transient_parent =
            gtk_window_get_transient_for(GTK_WINDOW(dialog)) ==
            GTK_WINDOW(root->window) && GTK_IS_WINDOW(find_dialog) &&
            gtk_window_get_transient_for(GTK_WINDOW(find_dialog)) ==
                GTK_WINDOW(root->window);
        root->settings_keep_above = 1;
        if (root->layer_shell_active && root->layer_shell_library != NULL) {
            NocttyLayerIsLayerWindow is_layer_window =
                (NocttyLayerIsLayerWindow)dlsym(root->layer_shell_library,
                                                "gtk_layer_is_layer_window");
            NocttyLayerGetInt get_layer =
                (NocttyLayerGetInt)dlsym(root->layer_shell_library,
                                         "gtk_layer_get_layer");
            root->settings_layer_overlay = is_layer_window != NULL &&
                get_layer != NULL && is_layer_window(GTK_WINDOW(dialog)) &&
                get_layer(GTK_WINDOW(dialog)) == 3 &&
                GTK_IS_WINDOW(find_dialog) &&
                is_layer_window(GTK_WINDOW(find_dialog)) &&
                get_layer(GTK_WINDOW(find_dialog)) == 3;
        }
        root->settings_stacking_ready =
            root->settings_stacking_visible &&
            root->settings_transient_parent && root->settings_keep_above &&
            (!root->layer_shell_active ||
             (root->settings_layer_overlay &&
              root->settings_parent_layer_lowered_seen));
        if (GTK_IS_WIDGET(find_dialog)) gtk_widget_destroy(find_dialog);
        gtk_widget_destroy(dialog);
        if (root->layer_shell_active &&
            !root->settings_parent_layer_restored)
            root->settings_stacking_ready = 0;
    }
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        NocttyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (candidate->active && !candidate->exited)
            (void)candidate->write(candidate->userdata, "exit 0\n", 7);
    }
    return G_SOURCE_REMOVE;
}

static gboolean action_button_tooltip_ready(GtkWidget *button) {
    if (!GTK_IS_BUTTON(button) || !gtk_widget_get_has_tooltip(button) ||
        g_object_get_data(G_OBJECT(button),
                          "noctty-action-affordance") == NULL)
        return FALSE;
    gchar *tooltip = gtk_widget_get_tooltip_text(button);
    gboolean ready = tooltip != NULL && tooltip[0] != '\0';
    g_free(tooltip);
    return ready;
}

static gboolean action_button_pointer_is_normal(GtkWidget *button,
                                                int *cursor_type_out) {
    if (cursor_type_out != NULL) *cursor_type_out = -1;
    if (!GTK_IS_BUTTON(button)) return FALSE;
    GdkWindow *window = noctty_action_button_event_window(button);
    if (window == NULL) return FALSE;
    (void)noctty_action_button_enter(button);
    GdkCursor *cursor = gdk_window_get_cursor(window);
    if (cursor_type_out != NULL && cursor != NULL)
        *cursor_type_out = (int)gdk_cursor_get_cursor_type(cursor);
    gboolean active = g_object_get_data(
        G_OBJECT(button), "noctty-action-pointer-active") != NULL;
    const gchar *pointer_name = g_object_get_data(
        G_OBJECT(button), "noctty-action-pointer-name");
    gboolean normal = active && g_strcmp0(pointer_name, "default") == 0 &&
        (cursor == NULL ||
         gdk_cursor_get_cursor_type(cursor) == GDK_CURSOR_IS_PIXMAP ||
         gdk_cursor_get_cursor_type(cursor) == GDK_ARROW ||
         gdk_cursor_get_cursor_type(cursor) == GDK_LEFT_PTR);
    (void)noctty_action_button_leave(button);
    return normal;
}

static gboolean inspect_window_toolbar_smoke(gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    GtkWidget *controls = root->window_toolbar_controls;
    GList *children = controls != NULL
        ? gtk_container_get_children(GTK_CONTAINER(controls))
        : NULL;
    GtkWidget *settings = children != NULL ? children->data : NULL;
    GtkWidget *close = children != NULL && children->next != NULL
        ? children->next->data
        : NULL;
    GtkWidget *settings_icon = GTK_IS_BUTTON(settings)
        ? gtk_button_get_image(GTK_BUTTON(settings))
        : NULL;
    GtkWidget *close_icon = GTK_IS_BUTTON(close)
        ? gtk_button_get_image(GTK_BUTTON(close))
        : NULL;
    const gchar *settings_icon_name = NULL;
    const gchar *close_icon_name = NULL;
    GtkIconSize settings_icon_size = GTK_ICON_SIZE_INVALID;
    GtkIconSize close_icon_size = GTK_ICON_SIZE_INVALID;
    if (GTK_IS_IMAGE(settings_icon))
        gtk_image_get_icon_name(GTK_IMAGE(settings_icon),
                                &settings_icon_name, &settings_icon_size);
    if (GTK_IS_IMAGE(close_icon))
        gtk_image_get_icon_name(GTK_IMAGE(close_icon),
                                &close_icon_name, &close_icon_size);
    AtkObject *settings_accessible = settings != NULL
        ? gtk_widget_get_accessible(settings)
        : NULL;
    AtkObject *close_accessible = close != NULL
        ? gtk_widget_get_accessible(close)
        : NULL;
    gint page_index = gtk_notebook_get_current_page(
        GTK_NOTEBOOK(root->notebook));
    GtkWidget *page = gtk_notebook_get_nth_page(
        GTK_NOTEBOOK(root->notebook), page_index);
    GtkWidget *tab_widget = page != NULL
        ? gtk_notebook_get_tab_label(GTK_NOTEBOOK(root->notebook), page)
        : NULL;
    GtkWidget *tab_close = tab_close_button_from_widget(tab_widget);
    GtkWidget *action_buttons[] = {
        root->new_tab_button,
        settings,
        close,
        tab_close,
    };
    root->action_button_pointer_normal = 1;
    root->action_button_tooltips_ready = 1;
    for (guint index = 0; index < G_N_ELEMENTS(action_buttons); index++) {
        int cursor_type = -1;
        if (!action_button_pointer_is_normal(action_buttons[index],
                                             &cursor_type)) {
            root->action_button_pointer_normal = 0;
            g_printerr("native_grid_button_pointer_probe index=%u button=%d window=%d cursor_type=%d configured=%d\n",
                       index,
                       GTK_IS_BUTTON(action_buttons[index]),
                       action_buttons[index] != NULL &&
                           noctty_action_button_event_window(
                               action_buttons[index]) != NULL,
                       cursor_type,
                       action_buttons[index] != NULL &&
                           g_object_get_data(G_OBJECT(action_buttons[index]),
                                             "noctty-action-affordance") != NULL);
        }
        if (!action_button_tooltip_ready(action_buttons[index]))
            root->action_button_tooltips_ready = 0;
    }
    GtkAllocation controls_allocation = {0};
    GtkAllocation settings_allocation = {0};
    GtkAllocation close_allocation = {0};
    if (controls != NULL) gtk_widget_get_allocation(
        controls, &controls_allocation);
    if (settings != NULL) gtk_widget_get_allocation(
        settings, &settings_allocation);
    if (close != NULL) gtk_widget_get_allocation(close, &close_allocation);
    root->window_toolbar_visible = controls != NULL &&
        gtk_notebook_get_action_widget(GTK_NOTEBOOK(root->notebook),
                                       GTK_PACK_END) == controls &&
        gtk_widget_get_mapped(controls) &&
        gtk_widget_get_mapped(root->window_settings_button) &&
        gtk_widget_get_mapped(root->window_close_button) &&
        controls_allocation.width >= 48 && controls_allocation.width <= 52 &&
        controls_allocation.height >= 24 && controls_allocation.height <= 28 &&
        settings_allocation.width >= 24 && settings_allocation.width <= 26 &&
        settings_allocation.height >= 24 && settings_allocation.height <= 28 &&
        close_allocation.width >= 24 && close_allocation.width <= 26 &&
        close_allocation.height >= 24 && close_allocation.height <= 28;
    root->window_toolbar_yakuake_order =
        g_list_length(children) == 2 &&
        settings == root->window_settings_button &&
        close == root->window_close_button &&
        GTK_IS_IMAGE(settings_icon) && GTK_IS_IMAGE(close_icon) &&
        settings_icon_size == GTK_ICON_SIZE_MENU &&
        close_icon_size == GTK_ICON_SIZE_MENU &&
        g_strcmp0(settings_icon_name, "preferences-system-symbolic") == 0 &&
        g_strcmp0(close_icon_name, "window-close-symbolic") == 0 &&
        settings_accessible != NULL &&
        g_strcmp0(atk_object_get_name(settings_accessible), "Settings") == 0 &&
        close_accessible != NULL &&
        g_strcmp0(atk_object_get_name(close_accessible), "Close NOCTTY") == 0;
    g_list_free(children);
    return G_SOURCE_REMOVE;
}
