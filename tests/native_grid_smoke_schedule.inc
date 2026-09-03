/* Test-only native-grid smoke scheduling matrix. */
    if (workspace_smoke < 0 &&
        g_getenv("NOCTTY_ACTIVATION_CHILD_RECEIPT") != NULL)
        g_timeout_add(250, write_activation_child_receipt_smoke, &context);
    if (workspace_smoke == 1) {
        g_timeout_add(250, emit_workspace_smoke_tab, &context);
        g_timeout_add(450, emit_workspace_smoke_split, &context);
        g_timeout_add(650, emit_workspace_smoke_split_left, &context);
        g_timeout_add(850, emit_workspace_smoke_broadcast, &context);
        g_timeout_add(1050, emit_workspace_smoke_select, &context);
        g_timeout_add(1150, emit_workspace_smoke_tag_filter, &context);
        g_timeout_add(1250, emit_workspace_smoke_focus, &context);
        g_timeout_add(1450, emit_workspace_smoke_move,
                      context.peer != NULL ? context.peer : &context);
        g_timeout_add(1650, finish_workspace_smoke, &context);
    } else if (workspace_smoke == 2) {
        g_timeout_add(250, emit_workspace_smoke_split, &context);
    } else if (workspace_smoke == 3) {
        g_timeout_add(250, request_new_tab_button_smoke, &context);
        g_timeout_add(450, inspect_compact_tab_geometry_smoke, &context);
        g_timeout_add(600, request_tab_close_smoke, &context);
    } else if (workspace_smoke == 4) {
        g_timeout_add(250, request_clipboard_smoke, &context);
    } else if (workspace_smoke == 6) {
        g_timeout_add(300, inspect_window_toolbar_smoke, &context);
        g_timeout_add(700, request_settings_smoke, &context);
        g_timeout_add(1600, request_window_close_button_smoke, &context);
    } else if (workspace_smoke == 7) {
        g_timeout_add(250, request_theme_smoke, &context);
    } else if (workspace_smoke == 8) {
        g_timeout_add(250, request_project_smoke, &context);
        g_timeout_add(20000, finish_title_smoke, &context);
    } else if (workspace_smoke == 11) {
        g_timeout_add(250, emit_workspace_smoke_split, &context);
        g_timeout_add(500, emit_workspace_smoke_split, &context);
        g_timeout_add(750, emit_workspace_smoke_split_left, &context);
        g_timeout_add(900, request_recursive_zoom_smoke, &context);
    } else if (workspace_smoke == 12) {
        g_timeout_add(250, emit_workspace_smoke_split, &context);
        g_timeout_add(350, drive_focus_click_smoke, &context);
    } else if (workspace_smoke == 13) {
        g_timeout_add(250, emit_workspace_smoke_balanced_split, &context);
        g_timeout_add(500, emit_workspace_smoke_balanced_split, &context);
        g_timeout_add(750, emit_workspace_smoke_balanced_split, &context);
        g_timeout_add(1000, emit_workspace_smoke_balanced_split, &context);
        g_timeout_add(1250, emit_workspace_smoke_balanced_split, &context);
        g_timeout_add(1500, emit_workspace_smoke_balanced_split, &context);
        g_timeout_add(1750, emit_workspace_smoke_balanced_split, &context);
    } else if (workspace_smoke == 14) {
        g_timeout_add(250, emit_workspace_smoke_tab, &context);
        g_timeout_add(500, emit_workspace_smoke_move_last_pane, &context);
    } else if (workspace_smoke == 15) {
        g_timeout_add(150, request_compact_hyperlink_smoke, &context);
        g_timeout_add(250, emit_workspace_smoke_split, &context);
        g_timeout_add(500, request_compact_palette_smoke, &context);
        g_timeout_add(700, request_compact_find_smoke, &context);
        g_timeout_add(900, request_compact_note_smoke, &context);
        g_timeout_add(1100, request_compact_zoom_smoke, &context);
        g_timeout_add(1300, request_compact_navigation_smoke, &context);
        g_timeout_add(1400, inspect_compact_pane_info_smoke, &context);
        g_timeout_add(1500, request_compact_font_scroll_smoke, &context);
        g_timeout_add(1625, request_compact_linear_selection_smoke, &context);
        g_timeout_add(1700, request_compact_save_smoke, &context);
        g_timeout_add(1800, request_pane_scrollbar_smoke, &context);
        g_timeout_add(2500, finish_compact_smoke, &context);
    } else if (workspace_smoke == 17) {
        g_timeout_add(250, emit_workspace_smoke_tab, &context);
        g_timeout_add(500, request_tab_rename_smoke, &context);
    } else if (workspace_smoke == 18) {
        g_timeout_add(300, check_resize_overlay_initially_hidden, &context);
        g_timeout_add(400, emit_workspace_smoke_split, &context);
        g_timeout_add(700, move_resize_overlay_divider, &context);
        g_timeout_add(850, move_resize_overlay_divider, &context);
        g_timeout_add(1000, check_resize_overlay_visible, &context);
        g_timeout_add(1700, check_resize_overlay_hidden_and_finish, &context);
    } else if (workspace_smoke == 19) {
        g_timeout_add(250, request_window_resize_smoke, &context);
    } else if (workspace_smoke == 20) {
        g_timeout_add(180, emit_pane_close_primary_split_right, &context);
        g_timeout_add(330, emit_pane_close_secondary_split_right, &context);
        g_timeout_add(500, inspect_and_resize_pane_close_layout, &context);
        g_timeout_add(680, disturb_pane_close_layout, &context);
        g_timeout_add(850, request_pane_close_smoke, &context);
    } else if (workspace_smoke == 21 || workspace_smoke == 43) {
        g_timeout_add(300, start_layout_preset_smoke, &context);
    } else if (workspace_smoke == 22) {
        g_timeout_add(300, emit_workspace_smoke_tab, &context);
        g_timeout_add(550, emit_workspace_smoke_split, &context);
        g_timeout_add(800, start_tab_navigation_interactions, &context);
    } else if (workspace_smoke == 23) {
        g_timeout_add(300, check_title_fallback_smoke, &context);
        g_timeout_add(700, emit_title_overflow_smoke, &context);
        g_timeout_add(1200, check_title_overflow_smoke, &context);
        g_timeout_add(1700, check_title_rename_smoke, &context);
        g_timeout_add(2300, finish_title_smoke, &context);
    } else if (workspace_smoke == 24) {
        g_timeout_add(300, trigger_dirty_smoke, &context);
        g_timeout_add(650, emit_attention_smoke, &context);
        g_timeout_add(1000, check_dirty_smoke, &context);
        g_timeout_add(1200, check_attention_smoke, &context);
        g_timeout_add(1450, save_dirty_smoke, &context);
        g_timeout_add(1750, check_dirty_clear_smoke, &context);
        g_timeout_add(2100, acknowledge_attention_smoke, &context);
        g_timeout_add(2400, finish_title_smoke, &context);
    } else if (workspace_smoke == 25) {
        g_timeout_add(300, emit_workspace_smoke_tab, &context);
        g_timeout_add(600, emit_workspace_smoke_tab, &context);
        g_timeout_add(900, announce_reorder_drag_smoke, &context);
        g_timeout_add(6500, check_reorder_smoke, &context);
        g_timeout_add(6800, persist_reorder_smoke, &context);
        g_timeout_add(7500, finish_title_smoke, &context);
    } else if (workspace_smoke == 26) {
        g_timeout_add(500, palette_rename_smoke, &context);
        g_timeout_add(2200, finish_title_smoke, &context);
    } else if (workspace_smoke == 27) {
        g_timeout_add(300, request_tab_color_smoke, &context);
    } else if (workspace_smoke == 28) {
        g_timeout_add(300, request_settings_stacking_smoke, &context);
        g_timeout_add(700, check_settings_stacking_smoke, &context);
    } else if (workspace_smoke == 29) {
        g_timeout_add(300, emit_workspace_smoke_split, &context);
        g_timeout_add(650, request_note_overlay_alt_press_smoke, &context);
        g_timeout_add(950, check_note_overlay_drawn_smoke, &context);
    } else if (workspace_smoke == 31) {
        g_timeout_add(350, request_terminal_interrupt_chord_smoke, &context);
        g_timeout_add(700, request_terminal_close_chord_smoke, &context);
        g_timeout_add(950, request_terminal_final_pane_guard_smoke, &context);
        g_timeout_add(1200, finish_terminal_chord_smoke, &context);
    } else if (workspace_smoke == 33) {
        g_timeout_add(350, request_profile_preset_smoke, &context);
    } else if (workspace_smoke == 35) {
        g_timeout_add(300, request_recent_workspace_child_smoke, &context);
        g_timeout_add(6000, finish_title_smoke, &context);
    } else if (workspace_smoke == 36) {
        g_timeout_add(350, start_presentation_qualification_smoke, &context);
    } else if (workspace_smoke == 37) {
        g_timeout_add(350, start_full_stack_qualification_smoke, &context);
    } else if (workspace_smoke == 39) {
        g_timeout_add(100, poll_installed_continuity_detach_smoke, &context);
    } else if (workspace_smoke == 40) {
        g_timeout_add(350, start_stability_qualification_smoke, &context);
    } else if (workspace_smoke == 41) {
        g_timeout_add(300, request_sharing_scope_smoke, &context);
    } else if (workspace_smoke == 42) {
        g_timeout_add(500, request_pane_scrollbar_smoke, &context);
    }
