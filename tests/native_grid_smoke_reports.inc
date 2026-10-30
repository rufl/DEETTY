/* Test-only qualification report dispatch. */
    if (workspace_smoke == 36)
        print_presentation_qualification_smoke(&context, presentation_ok);
    if (workspace_smoke == 37)
        print_full_stack_qualification_smoke(&context, full_stack_ok);
    if (workspace_smoke == 40)
        print_stability_qualification_smoke(&context, stability_ok);
