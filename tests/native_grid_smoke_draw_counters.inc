/* Test-only draw counters for mapped qualification builds. */
    DeettyGridContext *root = root_grid_context(context);
    if (root->workspace_smoke == 37) {
        if (root->full_stack_phase == 1)
            root->full_stack_idle_draws++;
        else if (root->full_stack_phase == 2)
            root->full_stack_fullscreen_draws++;
    } else if (root->workspace_smoke == 40) {
        if (root->stability_phase == 1)
            root->stability_visible_draws++;
        else if (root->stability_phase == 2)
            root->stability_hidden_draws++;
    }
    record_presentation_draw_smoke(context);
