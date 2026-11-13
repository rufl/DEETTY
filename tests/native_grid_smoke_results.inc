/* Test-only presentation, stability, and continuity result checks. */
    int presentation_ok = workspace_smoke != 36 ||
        (context.presentation_mapped && !context.presentation_failed &&
         context.presentation_finished &&
         context.presentation_samples_started ==
             DINTTY_PRESENTATION_QUALIFICATION_SAMPLES &&
         context.presentation_samples_completed ==
             DINTTY_PRESENTATION_QUALIFICATION_SAMPLES &&
         context.presentation_interval_count ==
             DINTTY_PRESENTATION_QUALIFICATION_SAMPLES - 1);
    int full_stack_ok = workspace_smoke != 37 ||
        (context.full_stack_mapped && context.full_stack_fullscreen &&
         !context.full_stack_failed && context.full_stack_finished &&
         context.full_stack_idle_draws > 0 &&
         context.full_stack_idle_draws <= 16 &&
         context.full_stack_idle_ticks == 0 &&
         context.full_stack_idle_cursor_blinks > 0 &&
         context.full_stack_idle_cursor_blinks <= 8 &&
         context.full_stack_idle_maintenance > 0 &&
         context.full_stack_idle_maintenance <= 4 &&
         context.full_stack_fullscreen_draws > 0 &&
         context.full_stack_fullscreen_output_frames > 0 &&
         context.full_stack_fullscreen_ticks == 0 &&
         context.full_stack_fullscreen_cursor_blinks > 0 &&
         context.full_stack_fullscreen_cursor_blinks <= 8 &&
         context.full_stack_fullscreen_maintenance > 0 &&
         context.full_stack_fullscreen_maintenance <= 4);
    guint64 stability_duration_seconds = 0;
    if (context.stability_finished_us > context.stability_started_us)
        stability_duration_seconds = (guint64)(context.stability_finished_us -
            context.stability_started_us) / G_USEC_PER_SEC;
    guint64 stability_expected_seconds =
        (guint64)context.stability_cycles_target *
        (guint64)context.stability_phase_seconds * 2;
    int stability_ok = workspace_smoke != 40 ||
        (context.stability_mapped_visible &&
         context.stability_unmapped_hidden &&
         !context.stability_failed && context.stability_finished &&
         context.stability_cycles_completed ==
             context.stability_cycles_target &&
         stability_duration_seconds >= stability_expected_seconds &&
         context.stability_visible_draws > 0 &&
         context.stability_hidden_draws == 0 &&
         context.stability_visible_presents > 0 &&
         context.stability_hidden_presents > 0 &&
         context.stability_visible_ticks == 0 &&
         context.stability_hidden_ticks == 0 &&
         context.stability_visible_cursor_blinks > 0 &&
         context.stability_hidden_cursor_blinks > 0 &&
         context.stability_visible_maintenance > 0 &&
         context.stability_hidden_maintenance > 0);
    int installed_continuity_ok = workspace_smoke != 39 ||
        (context.installed_continuity_detached &&
         !context.installed_continuity_failed);
