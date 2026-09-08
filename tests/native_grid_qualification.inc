/* Test-only renderer, presentation, and stability qualification.
 * Included by native_grid_host.c with NOCTTY_ENABLE_SMOKE. */
enum {
    NOCTTY_RENDERER_QUALIFICATION_FRAMES = 128,
    NOCTTY_RENDERER_QUALIFICATION_COLUMNS = 160,
    NOCTTY_RENDERER_QUALIFICATION_ROWS = 50,
};

typedef struct {
    int scenario;
    int columns;
    int rows;
} NocttyRendererFixture;

typedef struct {
    uint64_t p50_cpu_ns;
    uint64_t p95_cpu_ns;
    uint64_t p99_cpu_ns;
    uint64_t pixel_hash;
    guint pixel_diff;
    guint first_frame_owned_allocations;
    guint warm_frame_owned_allocations;
    size_t peak_owned_scratch_bytes;
    guint row_buffer_allocations;
    guint glyph_scratch_allocations;
    guint glyph_cache_builds;
} NocttyRendererQualificationResult;

enum {
    NOCTTY_PIPELINE_QUALIFICATION_SAMPLES = 64,
};

static uint64_t renderer_fixture_cell_value(
    const NocttyRendererFixture *fixture, int column, int row) {
    uint32_t codepoint = ' ';
    uint32_t style = 0xffffff00u;
    if (fixture->scenario == 0) return (uint64_t)codepoint |
        ((uint64_t)style << 32);

    codepoint = (uint32_t)('!' +
        ((row * fixture->columns + column) % 94));
    uint32_t foreground = (uint32_t)((row + column) % 16);
    uint32_t background = row % 9 == 0
        ? (uint32_t)((row / 9 + column / 20) % 8) : 0xfffu;
    uint32_t flags = 0;
    if ((column + row) % 29 == 0) flags |= 1;
    if ((column * 3 + row) % 41 == 0) flags |= 4;
    if (fixture->scenario == 2) {
        if ((column + row * 5) % 37 == 0) {
            codepoint = 'x';
            flags |= 64;
        }
        if ((column + row) % 17 == 0) flags |= 8;
        if ((column * 7 + row) % 31 == 0) flags |= 16;
        if ((column + row * 11) % 43 == 0) flags |= 32;
        if ((column + row * 13) % 47 == 0) flags |= 2;
    }
    style = flags | (foreground << 8) | (background << 20);
    return (uint64_t)codepoint | ((uint64_t)style << 32);
}

static uint64_t renderer_fixture_cell(void *userdata, int column, int row) {
    NocttyRendererFixture *fixture = userdata;
    if (fixture == NULL || column < 0 || row < 0 ||
        column >= fixture->columns || row >= fixture->rows)
        return (uint64_t)' ' | ((uint64_t)0xffffff00u << 32);
    return renderer_fixture_cell_value(fixture, column, row);
}

static int renderer_fixture_row(void *userdata, int row, uint64_t *output,
                                size_t capacity) {
    NocttyRendererFixture *fixture = userdata;
    if (fixture == NULL || output == NULL || row < 0 ||
        row >= fixture->rows || capacity < (size_t)fixture->columns)
        return 0;
    for (int column = 0; column < fixture->columns; column++)
        output[column] = renderer_fixture_cell_value(fixture, column, row);
    return fixture->columns;
}

static uint32_t renderer_fixture_cursor(void *userdata) {
    NocttyRendererFixture *fixture = userdata;
    if (fixture == NULL || fixture->scenario == 0) return 0xffffffffu;
    return 12u | (7u << 16);
}

static uint32_t renderer_fixture_color(void *userdata, uint32_t color_id) {
    (void)userdata;
    static const uint32_t palette[] = {
        0x1d2021, 0xcc241d, 0x98971a, 0xd79921,
        0x458588, 0xb16286, 0x689d6a, 0xa89984,
        0x928374, 0xfb4934, 0xb8bb26, 0xfabd2f,
        0x83a598, 0xd3869b, 0x8ec07c, 0xebdbb2,
    };
    if (color_id == 0xfffu) return UINT32_MAX;
    return palette[color_id % G_N_ELEMENTS(palette)];
}

static int renderer_fixture_cell_text(void *userdata, int column, int row,
                                      char *output, size_t capacity) {
    NocttyRendererFixture *fixture = userdata;
    static const char grapheme[] = "\xe7\x95\x8c";
    if (fixture == NULL || fixture->scenario != 2 || output == NULL ||
        capacity < sizeof(grapheme) - 1 ||
        (column + row * 5) % 37 != 0)
        return 0;
    memcpy(output, grapheme, sizeof(grapheme) - 1);
    return (int)(sizeof(grapheme) - 1);
}

static uint64_t renderer_process_cpu_ns(void) {
    clock_t ticks = clock();
    if (ticks == (clock_t)-1) return 0;
    return (uint64_t)ticks * 1000000000ull / (uint64_t)CLOCKS_PER_SEC;
}

static uint64_t renderer_monotonic_ns(void) {
    return (uint64_t)g_get_monotonic_time() * 1000ull;
}

static int compare_renderer_sample(const void *left, const void *right) {
    uint64_t a = *(const uint64_t *)left;
    uint64_t b = *(const uint64_t *)right;
    return a < b ? -1 : a > b ? 1 : 0;
}

static uint64_t renderer_percentile(const uint64_t *samples, size_t count,
                                    size_t percent) {
    if (count == 0) return 0;
    size_t rank = (count * percent + 99) / 100;
    return samples[MAX(rank, 1) - 1];
}

static void record_presentation_draw_smoke(NocttyGridContext *context) {
    NocttyGridContext *root = root_grid_context(context);
    if (root->workspace_smoke != 36 || !root->presentation_pending ||
        root->presentation_samples_completed >=
            root->presentation_samples_started ||
        root->presentation_output_serial <
            root->presentation_expected_output_serial)
        return;
    guint index = root->presentation_samples_completed;
    if (root->presentation_key_to_draw_ns[index] != 0) return;
    gint64 elapsed_us = g_get_monotonic_time() -
        root->presentation_key_start_us[index];
    if (elapsed_us > 0)
        root->presentation_key_to_draw_ns[index] =
            (uint64_t)elapsed_us * 1000ull;
}

static void collect_presentation_feedback_smoke(
    NocttyGridContext *context, GdkFrameClock *clock) {
    for (guint index = 0;
         index < context->presentation_samples_completed; index++) {
        if (!context->presentation_frame_recorded[index] ||
            context->presentation_key_to_present_ns[index] != 0)
            continue;
        GdkFrameTimings *timings = gdk_frame_clock_get_timings(
            clock, context->presentation_frame_counter[index]);
        if (timings == NULL || !gdk_frame_timings_get_complete(timings))
            continue;
        gint64 presentation_us =
            gdk_frame_timings_get_presentation_time(timings);
        if (presentation_us <= context->presentation_key_start_us[index])
            continue;
        context->presentation_key_to_present_ns[index] =
            (uint64_t)(presentation_us -
                       context->presentation_key_start_us[index]) * 1000ull;
        context->presentation_feedback_count++;
    }
}

static gboolean request_presentation_sample_smoke(gpointer user_data) {
    NocttyGridContext *context = root_grid_context(user_data);
    if (context->presentation_failed || context->presentation_pending ||
        context->presentation_samples_started >=
            NOCTTY_PRESENTATION_QUALIFICATION_SAMPLES)
        return G_SOURCE_REMOVE;
    GdkWindow *window = gtk_widget_get_window(context->area);
    if (!gtk_widget_get_mapped(context->area) || window == NULL) {
        context->presentation_failed = 1;
        return G_SOURCE_REMOVE;
    }

    guint index = context->presentation_samples_started;
    gchar text[2] = {
        (gchar)('a' + (index % 26)),
        '\0',
    };
    GdkEventKey event = {0};
    event.type = GDK_KEY_PRESS;
    event.window = g_object_ref(window);
    event.send_event = TRUE;
    event.time = GDK_CURRENT_TIME;
    event.state = 0;
    event.keyval = gdk_unicode_to_keyval((gunichar)text[0]);
    event.length = 1;
    event.string = text;
    event.hardware_keycode = 0;
    event.group = 0;
    event.is_modifier = 0;
    context->presentation_armed = 1;
    gboolean handled = on_key_press(context->area, &event, context);
    g_object_unref(event.window);
    if (!handled || context->presentation_armed) {
        context->presentation_armed = 0;
        context->presentation_failed = 1;
        if (context->write(context->userdata, "\x04", 1) == 1)
            schedule_grid_write_flush(context);
    }
    return G_SOURCE_REMOVE;
}

static gboolean finish_presentation_qualification_smoke(gpointer user_data) {
    NocttyGridContext *context = root_grid_context(user_data);
    GdkFrameClock *clock = gtk_widget_get_frame_clock(context->area);
    if (clock != NULL) collect_presentation_feedback_smoke(context, clock);
    if (context->presentation_finish_attempts++ < 12 &&
        context->presentation_feedback_count <
            context->presentation_samples_completed) {
        gtk_widget_queue_draw(context->area);
        if (clock != NULL)
            gdk_frame_clock_request_phase(clock, GDK_FRAME_CLOCK_PHASE_PAINT);
        return G_SOURCE_CONTINUE;
    }
    context->presentation_finished = 1;
    if (context->write(context->userdata, "\n\x04", 2) == 2)
        schedule_grid_write_flush(context);
    else
        context->presentation_failed = 1;
    return G_SOURCE_REMOVE;
}

static void on_presentation_after_paint_smoke(GdkFrameClock *clock,
                                               gpointer user_data) {
    NocttyGridContext *context = root_grid_context(user_data);
    collect_presentation_feedback_smoke(context, clock);
    if (!context->presentation_pending ||
        context->presentation_samples_completed >=
            context->presentation_samples_started)
        return;
    guint index = context->presentation_samples_completed;
    if (context->presentation_key_to_draw_ns[index] == 0) return;

    gint64 now_us = g_get_monotonic_time();
    gint64 elapsed_us = now_us - context->presentation_key_start_us[index];
    if (elapsed_us <= 0) {
        context->presentation_failed = 1;
        return;
    }
    context->presentation_key_to_frame_ns[index] =
        (uint64_t)elapsed_us * 1000ull;
    GdkFrameTimings *timings =
        gdk_frame_clock_get_current_timings(clock);
    gint64 frame_us = gdk_frame_clock_get_frame_time(clock);
    if (timings != NULL) {
        frame_us = gdk_frame_timings_get_frame_time(timings);
        context->presentation_frame_counter[index] =
            gdk_frame_timings_get_frame_counter(timings);
        context->presentation_frame_recorded[index] = 1;
        gint64 predicted_us =
            gdk_frame_timings_get_predicted_presentation_time(timings);
        if (predicted_us > context->presentation_key_start_us[index])
            context->presentation_key_to_predicted_ns[index] =
                (uint64_t)(predicted_us -
                           context->presentation_key_start_us[index]) *
                1000ull;
    }
    if (context->presentation_previous_frame_us > 0 &&
        frame_us > context->presentation_previous_frame_us) {
        gint64 interval_us = frame_us -
            context->presentation_previous_frame_us;
        guint interval_index = context->presentation_interval_count++;
        context->presentation_frame_interval_ns[interval_index] =
            (uint64_t)interval_us * 1000ull;
        gint64 refresh_us = timings != NULL
            ? gdk_frame_timings_get_refresh_interval(timings) : 0;
        if (refresh_us > 0 && interval_us > refresh_us * 3 / 2)
            context->presentation_missed_deadlines++;
    }
    context->presentation_previous_frame_us = frame_us;
    context->presentation_samples_completed++;
    context->presentation_pending = 0;
    collect_presentation_feedback_smoke(context, clock);
    if (context->presentation_samples_completed <
        NOCTTY_PRESENTATION_QUALIFICATION_SAMPLES)
        g_timeout_add(2, request_presentation_sample_smoke, context);
    else
        g_timeout_add(20, finish_presentation_qualification_smoke, context);
}

static gboolean start_presentation_qualification_smoke(gpointer user_data) {
    NocttyGridContext *context = root_grid_context(user_data);
    GdkFrameClock *clock = gtk_widget_get_frame_clock(context->area);
    context->presentation_mapped =
        gtk_widget_get_mapped(context->area) && clock != NULL;
    if (!context->presentation_mapped) {
        context->presentation_failed = 1;
        if (context->write(context->userdata, "\x04", 1) == 1)
            schedule_grid_write_flush(context);
        return G_SOURCE_REMOVE;
    }
    context->presentation_after_paint_handler = g_signal_connect(
        clock, "after-paint",
        G_CALLBACK(on_presentation_after_paint_smoke), context);
    return request_presentation_sample_smoke(context);
}

static void print_presentation_qualification_smoke(
    NocttyGridContext *context, gboolean passed) {
    uint64_t draw[NOCTTY_PRESENTATION_QUALIFICATION_SAMPLES];
    uint64_t frame[NOCTTY_PRESENTATION_QUALIFICATION_SAMPLES];
    uint64_t predicted[NOCTTY_PRESENTATION_QUALIFICATION_SAMPLES];
    uint64_t presented[NOCTTY_PRESENTATION_QUALIFICATION_SAMPLES];
    uint64_t intervals[NOCTTY_PRESENTATION_QUALIFICATION_SAMPLES - 1];
    memcpy(draw, context->presentation_key_to_draw_ns, sizeof(draw));
    memcpy(frame, context->presentation_key_to_frame_ns, sizeof(frame));
    memcpy(intervals, context->presentation_frame_interval_ns,
           sizeof(intervals));
    guint predicted_count = 0;
    guint presented_count = 0;
    for (guint index = 0;
         index < context->presentation_samples_completed; index++) {
        if (context->presentation_key_to_predicted_ns[index] != 0)
            predicted[predicted_count++] =
                context->presentation_key_to_predicted_ns[index];
        if (context->presentation_key_to_present_ns[index] != 0)
            presented[presented_count++] =
                context->presentation_key_to_present_ns[index];
    }
    qsort(draw, context->presentation_samples_completed, sizeof(draw[0]),
          compare_renderer_sample);
    qsort(frame, context->presentation_samples_completed, sizeof(frame[0]),
          compare_renderer_sample);
    qsort(predicted, predicted_count, sizeof(predicted[0]),
          compare_renderer_sample);
    qsort(presented, presented_count, sizeof(presented[0]),
          compare_renderer_sample);
    qsort(intervals, context->presentation_interval_count,
          sizeof(intervals[0]), compare_renderer_sample);
    const char *backend = g_getenv("GDK_BACKEND");
    if (backend == NULL || backend[0] == '\0') backend = "default";
    g_print(
        "native_grid_presentation_qualification backend=%s samples=%u "
        "key_to_draw_p50_ns=%llu key_to_draw_p95_ns=%llu "
        "key_to_draw_p99_ns=%llu key_to_frame_p50_ns=%llu "
        "key_to_frame_p95_ns=%llu key_to_frame_p99_ns=%llu "
        "frame_interval_p50_ns=%llu frame_interval_p95_ns=%llu "
        "frame_interval_p99_ns=%llu predicted_samples=%u "
        "key_to_predicted_p50_ns=%llu key_to_predicted_p95_ns=%llu "
        "key_to_predicted_p99_ns=%llu presentation_feedback_samples=%u "
        "key_to_present_p50_ns=%llu key_to_present_p95_ns=%llu "
        "key_to_present_p99_ns=%llu missed_deadlines=%u mapped_surface=%s "
        "frame_clock=%s synthetic_gtk_keys=true gdk_event_queue=false "
        "hid=false passed=%s\n",
        backend, context->presentation_samples_completed,
        (unsigned long long)renderer_percentile(draw,
            context->presentation_samples_completed, 50),
        (unsigned long long)renderer_percentile(draw,
            context->presentation_samples_completed, 95),
        (unsigned long long)renderer_percentile(draw,
            context->presentation_samples_completed, 99),
        (unsigned long long)renderer_percentile(frame,
            context->presentation_samples_completed, 50),
        (unsigned long long)renderer_percentile(frame,
            context->presentation_samples_completed, 95),
        (unsigned long long)renderer_percentile(frame,
            context->presentation_samples_completed, 99),
        (unsigned long long)renderer_percentile(intervals,
            context->presentation_interval_count, 50),
        (unsigned long long)renderer_percentile(intervals,
            context->presentation_interval_count, 95),
        (unsigned long long)renderer_percentile(intervals,
            context->presentation_interval_count, 99),
        predicted_count,
        (unsigned long long)(predicted_count > 0
            ? renderer_percentile(predicted, predicted_count, 50) : 0),
        (unsigned long long)(predicted_count > 0
            ? renderer_percentile(predicted, predicted_count, 95) : 0),
        (unsigned long long)(predicted_count > 0
            ? renderer_percentile(predicted, predicted_count, 99) : 0),
        presented_count,
        (unsigned long long)(presented_count > 0
            ? renderer_percentile(presented, presented_count, 50) : 0),
        (unsigned long long)(presented_count > 0
            ? renderer_percentile(presented, presented_count, 95) : 0),
        (unsigned long long)(presented_count > 0
            ? renderer_percentile(presented, presented_count, 99) : 0),
        context->presentation_missed_deadlines,
        context->presentation_mapped ? "true" : "false",
        context->presentation_after_paint_handler != 0 ? "true" : "false",
        passed ? "true" : "false");
}

static gboolean finish_full_stack_qualification_smoke(gpointer user_data) {
    NocttyGridContext *context = root_grid_context(user_data);
    context->full_stack_phase = 0;
    context->full_stack_finished = 1;
    g_print("native_grid_full_stack_phase phase=complete pid=%ld\n",
            (long)getpid());
    fflush(stdout);
    if (context->write(context->userdata, "\n\x04", 2) == 2)
        schedule_grid_write_flush(context);
    else
        context->full_stack_failed = 1;
    return G_SOURCE_REMOVE;
}

static gboolean announce_full_stack_fullscreen_smoke(gpointer user_data) {
    NocttyGridContext *context = root_grid_context(user_data);
    GdkWindow *window = gtk_widget_get_window(context->window);
    GdkWindowState state = window != NULL
        ? gdk_window_get_state(window) : 0;
    context->full_stack_fullscreen =
        (state & GDK_WINDOW_STATE_FULLSCREEN) != 0;
    if (!context->full_stack_fullscreen) {
        context->full_stack_failed = 1;
        return finish_full_stack_qualification_smoke(context);
    }
    g_print("native_grid_full_stack_phase phase=fullscreen_ready pid=%ld\n",
            (long)getpid());
    fflush(stdout);
    g_timeout_add(2500, finish_full_stack_qualification_smoke, context);
    return G_SOURCE_REMOVE;
}

static gboolean request_full_stack_fullscreen_smoke(gpointer user_data) {
    NocttyGridContext *context = root_grid_context(user_data);
    static const char clear[] = "\x1b[2J\x1b[H";
    context->full_stack_phase = 2;
    gtk_window_fullscreen(GTK_WINDOW(context->window));
    if (!context->layer_shell_active)
        gtk_window_present(GTK_WINDOW(context->window));
    if (context->write(context->userdata, clear, sizeof(clear) - 1) !=
        (int)(sizeof(clear) - 1)) {
        context->full_stack_failed = 1;
        return finish_full_stack_qualification_smoke(context);
    }
    for (int row = 0; row < 36; row++) {
        char line[160];
        int length = g_snprintf(
            line, sizeof(line),
            "\x1b[38;2;%d;%d;%dmNOCTTY mapped fullscreen row %02d"
            "  PTY · VT · GTK · Cairo · Plasma\x1b[0m\n",
            96 + row * 3, 120 + row * 2, 220 - row * 2, row + 1);
        if (length <= 0 || context->write(
                context->userdata, line, (size_t)length) != length) {
            context->full_stack_failed = 1;
            return finish_full_stack_qualification_smoke(context);
        }
    }
    schedule_grid_write_flush(context);
    gtk_widget_queue_draw(context->area);
    g_timeout_add(700, announce_full_stack_fullscreen_smoke, context);
    return G_SOURCE_REMOVE;
}

static gboolean start_full_stack_qualification_smoke(gpointer user_data) {
    NocttyGridContext *context = root_grid_context(user_data);
    GdkFrameClock *clock = gtk_widget_get_frame_clock(context->area);
    context->full_stack_mapped =
        gtk_widget_get_mapped(context->area) && clock != NULL;
    if (!context->full_stack_mapped) {
        context->full_stack_failed = 1;
        return finish_full_stack_qualification_smoke(context);
    }
    gtk_window_set_title(GTK_WINDOW(context->window),
                         "NOCTTY full-stack qualification");
    if (!context->layer_shell_active)
        gtk_window_present(GTK_WINDOW(context->window));
    context->full_stack_phase = 1;
    g_print("native_grid_full_stack_phase phase=idle_ready pid=%ld\n",
            (long)getpid());
    fflush(stdout);
    g_timeout_add(2500, request_full_stack_fullscreen_smoke, context);
    return G_SOURCE_REMOVE;
}

static gboolean request_stability_hidden_smoke(gpointer user_data);

static guint stability_env_uint(const char *name, guint fallback,
                                guint maximum) {
    const char *value = g_getenv(name);
    if (value == NULL || value[0] == '\0') return fallback;
    char *end = NULL;
    guint64 parsed = g_ascii_strtoull(value, &end, 10);
    if (end == value || end == NULL || end[0] != '\0' || parsed == 0 ||
        parsed > maximum)
        return 0;
    return (guint)parsed;
}

static gboolean timeout_stability_qualification_smoke(gpointer user_data) {
    NocttyGridContext *context = root_grid_context(user_data);
    if (!context->exited) {
        context->stability_failed = 1;
        if (gtk_main_level() > 0) gtk_main_quit();
    }
    return G_SOURCE_REMOVE;
}

static gboolean finish_stability_qualification_smoke(gpointer user_data) {
    NocttyGridContext *context = root_grid_context(user_data);
    context->stability_phase = 0;
    context->stability_finished = 1;
    context->stability_finished_us = g_get_monotonic_time();
    g_print("native_grid_stability_phase phase=complete cycle=%u pid=%ld\n",
            context->stability_cycles_completed, (long)getpid());
    fflush(stdout);
    if (context->write(context->userdata, "\n\x04", 2) == 2)
        schedule_grid_write_flush(context);
    else
        context->stability_failed = 1;
    g_timeout_add(5000, timeout_stability_qualification_smoke, context);
    return G_SOURCE_REMOVE;
}

static gboolean announce_stability_visible_smoke(gpointer user_data) {
    NocttyGridContext *context = root_grid_context(user_data);
    GdkFrameClock *clock = gtk_widget_get_frame_clock(context->area);
    if (!context->window_presented || !gtk_widget_get_mapped(context->area) ||
        clock == NULL) {
        context->stability_failed = 1;
        return finish_stability_qualification_smoke(context);
    }
    context->stability_mapped_visible = 1;
    context->stability_cycles_completed++;
    context->stability_phase = 1;
    g_print("native_grid_stability_phase phase=visible_ready cycle=%u pid=%ld\n",
            context->stability_cycles_completed, (long)getpid());
    fflush(stdout);
    if (context->stability_cycles_completed >=
        context->stability_cycles_target) {
        g_timeout_add(5000, finish_stability_qualification_smoke, context);
    } else {
        g_timeout_add_seconds(context->stability_phase_seconds,
                              request_stability_hidden_smoke, context);
    }
    return G_SOURCE_REMOVE;
}

static gboolean request_stability_visible_smoke(gpointer user_data) {
    NocttyGridContext *context = root_grid_context(user_data);
    context->stability_phase = 0;
    if (context->window_presented) {
        context->stability_failed = 1;
        return finish_stability_qualification_smoke(context);
    }
    toggle_grid_window(context);
    g_timeout_add(350, announce_stability_visible_smoke, context);
    return G_SOURCE_REMOVE;
}

static gboolean announce_stability_hidden_smoke(gpointer user_data) {
    NocttyGridContext *context = root_grid_context(user_data);
    if (context->window_presented || gtk_widget_get_mapped(context->area)) {
        context->stability_failed = 1;
        return finish_stability_qualification_smoke(context);
    }
    context->stability_unmapped_hidden = 1;
    context->stability_phase = 2;
    g_print("native_grid_stability_phase phase=hidden_ready cycle=%u pid=%ld\n",
            context->stability_cycles_completed + 1, (long)getpid());
    fflush(stdout);
    g_timeout_add_seconds(context->stability_phase_seconds,
                          request_stability_visible_smoke, context);
    return G_SOURCE_REMOVE;
}

static gboolean request_stability_hidden_smoke(gpointer user_data) {
    NocttyGridContext *context = root_grid_context(user_data);
    context->stability_phase = 0;
    if (!context->window_presented) {
        context->stability_failed = 1;
        return finish_stability_qualification_smoke(context);
    }
    toggle_grid_window(context);
    guint delay_ms = (guint)MAX(context->dropdown_animation_ms, 0) + 150;
    g_timeout_add(delay_ms, announce_stability_hidden_smoke, context);
    return G_SOURCE_REMOVE;
}

static gboolean start_stability_qualification_smoke(gpointer user_data) {
    NocttyGridContext *context = root_grid_context(user_data);
    const char *ready_path = g_getenv("NOCTTY_STABILITY_READY_PATH");
    if (ready_path != NULL && ready_path[0] != '\0' &&
        !g_file_test(ready_path, G_FILE_TEST_EXISTS)) {
        context->stability_ready_attempts++;
        if (context->stability_ready_attempts < 1800)
            return G_SOURCE_CONTINUE;
        context->stability_failed = 1;
        return finish_stability_qualification_smoke(context);
    }
    context->stability_cycles_target = stability_env_uint(
        "NOCTTY_STABILITY_CYCLES", 2, 96);
    context->stability_phase_seconds = stability_env_uint(
        "NOCTTY_STABILITY_PHASE_SECONDS", 2, 3600);
    GdkFrameClock *clock = gtk_widget_get_frame_clock(context->area);
    if (context->stability_cycles_target == 0 ||
        context->stability_phase_seconds == 0 ||
        !context->window_presented || !gtk_widget_get_mapped(context->area) ||
        clock == NULL) {
        context->stability_failed = 1;
        return finish_stability_qualification_smoke(context);
    }
    gtk_window_set_title(GTK_WINDOW(context->window),
                         "NOCTTY stability qualification");
    if (!context->layer_shell_active)
        gtk_window_present(GTK_WINDOW(context->window));
    context->stability_mapped_visible = 1;
    context->stability_started_us = g_get_monotonic_time();
    context->stability_phase = 1;
    g_print("native_grid_stability_phase phase=visible_ready cycle=0 pid=%ld\n",
            (long)getpid());
    fflush(stdout);
    g_timeout_add_seconds(context->stability_phase_seconds,
                          request_stability_hidden_smoke, context);
    return G_SOURCE_REMOVE;
}

static gboolean poll_installed_continuity_detach_smoke(gpointer user_data) {
    NocttyGridContext *context = root_grid_context(user_data);
    const char *path = g_getenv("NOCTTY_CONTINUITY_DETACH_PATH");
    const char *kind = g_getenv("NOCTTY_CONTINUITY_KIND");
    context->installed_continuity_detach_attempts++;
    if (path != NULL && g_file_test(path, G_FILE_TEST_EXISTS)) {
        const char *sequence = NULL;
        if (g_strcmp0(kind, "tmux") == 0) sequence = "\x02" "d";
        else if (g_strcmp0(kind, "zellij") == 0) sequence = "\x0f" "d";
        if (sequence == NULL || deliver_grid_input(context, sequence, 2) != 2) {
            context->installed_continuity_failed = 1;
            if (gtk_main_level() > 0) gtk_main_quit();
        } else {
            context->installed_continuity_detached = 1;
        }
        return G_SOURCE_REMOVE;
    }
    if (context->installed_continuity_detach_attempts >= 600) {
        context->installed_continuity_failed = 1;
        if (gtk_main_level() > 0) gtk_main_quit();
        return G_SOURCE_REMOVE;
    }
    return G_SOURCE_CONTINUE;
}

static void print_full_stack_qualification_smoke(
    NocttyGridContext *context, gboolean passed) {
    const char *backend = g_getenv("GDK_BACKEND");
    if (backend == NULL || backend[0] == '\0') backend = "default";
    g_print(
        "native_grid_full_stack_qualification backend=%s "
        "idle_draws=%u idle_output_frames=%u idle_ticks=%u "
        "idle_cursor_blinks=%u idle_maintenance=%u "
        "fullscreen_draws=%u fullscreen_output_frames=%u "
        "fullscreen_ticks=%u fullscreen_cursor_blinks=%u "
        "fullscreen_maintenance=%u mapped_surface=%s fullscreen=%s "
        "production_pty=true production_vt=true production_gtk=true "
        "production_cairo=true external_memory=true "
        "external_compositor_pixels=true hid=false passed=%s\n",
        backend,
        context->full_stack_idle_draws,
        context->full_stack_idle_output_frames,
        context->full_stack_idle_ticks,
        context->full_stack_idle_cursor_blinks,
        context->full_stack_idle_maintenance,
        context->full_stack_fullscreen_draws,
        context->full_stack_fullscreen_output_frames,
        context->full_stack_fullscreen_ticks,
        context->full_stack_fullscreen_cursor_blinks,
        context->full_stack_fullscreen_maintenance,
        context->full_stack_mapped ? "true" : "false",
        context->full_stack_fullscreen ? "true" : "false",
        passed ? "true" : "false");
}

static void print_stability_qualification_smoke(
    NocttyGridContext *context, gboolean passed) {
    const char *backend = g_getenv("GDK_BACKEND");
    if (backend == NULL || backend[0] == '\0') backend = "default";
    guint64 duration_seconds = 0;
    if (context->stability_finished_us > context->stability_started_us)
        duration_seconds = (guint64)(context->stability_finished_us -
            context->stability_started_us) / G_USEC_PER_SEC;
    g_print(
        "native_grid_stability_qualification backend=%s cycles=%u "
        "phase_seconds=%u duration_seconds=%llu visible_draws=%u "
        "hidden_draws=%u visible_presents=%u hidden_presents=%u "
        "visible_ticks=%u hidden_ticks=%u visible_cursor_blinks=%u "
        "hidden_cursor_blinks=%u visible_maintenance=%u "
        "hidden_maintenance=%u mapped_visible=%s unmapped_hidden=%s "
        "production_pty=true production_vt=true production_gtk=true "
        "production_cairo=true workload_output=true hid=false passed=%s\n",
        backend,
        context->stability_cycles_completed,
        context->stability_phase_seconds,
        (unsigned long long)duration_seconds,
        context->stability_visible_draws,
        context->stability_hidden_draws,
        context->stability_visible_presents,
        context->stability_hidden_presents,
        context->stability_visible_ticks,
        context->stability_hidden_ticks,
        context->stability_visible_cursor_blinks,
        context->stability_hidden_cursor_blinks,
        context->stability_visible_maintenance,
        context->stability_hidden_maintenance,
        context->stability_mapped_visible ? "true" : "false",
        context->stability_unmapped_hidden ? "true" : "false",
        passed ? "true" : "false");
}

static GtkAllocation renderer_allocation_for_context(
    const NocttyGridContext *context) {
    NocttyGridFontMetrics metrics = grid_font_metrics(context);
    GtkAllocation allocation = {
        .x = 0,
        .y = 0,
        .width = (int)ceil(8.0 + context->columns * metrics.cell_width),
        .height = (int)ceil(4.0 + context->rows * metrics.cell_height),
    };
    return allocation;
}

static void renderer_init_context(NocttyGridContext *context,
                                  NocttyRendererFixture *fixture) {
    memset(context, 0, sizeof(*context));
    context->userdata = fixture;
    context->cell = renderer_fixture_cell;
    context->row = renderer_fixture_row;
    context->color_rgb = renderer_fixture_color;
    context->cell_text = renderer_fixture_cell_text;
    context->cursor = renderer_fixture_cursor;
    context->active = 1;
    context->cursor_visible = fixture->scenario != 0;
    context->columns = fixture->columns;
    context->rows = fixture->rows;
    context->font_size = 14.0;
    context->requested_font_size = 14.0;
    context->font_family = (gchar *)"monospace";
    if (fixture->scenario == 2) {
        context->selecting = 1;
        context->selection_start_column = 3;
        context->selection_end_column = 28;
        context->selection_start_row = 4;
        context->selection_end_row = 9;
    }
}

static guint renderer_owned_allocation_count(
    const NocttyGridContext *context) {
    return context->row_buffer_allocations +
        context->glyph_scratch_allocations + context->glyph_cache_builds;
}

static size_t renderer_owned_scratch_bytes(
    const NocttyGridContext *context) {
    return context->row_cell_capacity * sizeof(*context->row_cells) +
        context->glyph_scratch_capacity * sizeof(*context->glyph_scratch);
}

static uint64_t renderer_surface_hash(cairo_surface_t *surface,
                                      GtkAllocation allocation) {
    cairo_surface_flush(surface);
    const unsigned char *data = cairo_image_surface_get_data(surface);
    int stride = cairo_image_surface_get_stride(surface);
    uint64_t hash = 14695981039346656037ull;
    for (int row = 0; row < allocation.height; row++) {
        const unsigned char *pixels = data + row * stride;
        for (int byte = 0; byte < allocation.width * 4; byte++)
            hash = (hash ^ pixels[byte]) * 1099511628211ull;
    }
    return hash;
}

static guint renderer_surface_pixel_diff(cairo_surface_t *left,
                                         cairo_surface_t *right,
                                         GtkAllocation allocation) {
    cairo_surface_flush(left);
    cairo_surface_flush(right);
    const unsigned char *left_data = cairo_image_surface_get_data(left);
    const unsigned char *right_data = cairo_image_surface_get_data(right);
    int left_stride = cairo_image_surface_get_stride(left);
    int right_stride = cairo_image_surface_get_stride(right);
    guint changed = 0;
    for (int row = 0; row < allocation.height; row++) {
        const uint32_t *left_pixels = (const uint32_t *)(
            left_data + row * left_stride);
        const uint32_t *right_pixels = (const uint32_t *)(
            right_data + row * right_stride);
        for (int column = 0; column < allocation.width; column++)
            if (left_pixels[column] != right_pixels[column]) changed++;
    }
    return changed;
}

static int renderer_qualify_scenario(
    int scenario, const char *artifact_directory, const char *artifact_name,
    NocttyRendererQualificationResult *result) {
    NocttyRendererFixture fixture = {
        .scenario = scenario,
        .columns = NOCTTY_RENDERER_QUALIFICATION_COLUMNS,
        .rows = NOCTTY_RENDERER_QUALIFICATION_ROWS,
    };
    NocttyGridContext context;
    renderer_init_context(&context, &fixture);
    GtkAllocation allocation = renderer_allocation_for_context(&context);
    cairo_surface_t *surface = cairo_image_surface_create(
        CAIRO_FORMAT_ARGB32, allocation.width, allocation.height);
    cairo_surface_t *comparison = cairo_image_surface_create(
        CAIRO_FORMAT_ARGB32, allocation.width, allocation.height);
    if (cairo_surface_status(surface) != CAIRO_STATUS_SUCCESS ||
        cairo_surface_status(comparison) != CAIRO_STATUS_SUCCESS) {
        cairo_surface_destroy(surface);
        cairo_surface_destroy(comparison);
        return -1;
    }
    cairo_t *cr = cairo_create(surface);
    cairo_t *comparison_cr = cairo_create(comparison);
    if (cairo_status(cr) != CAIRO_STATUS_SUCCESS ||
        cairo_status(comparison_cr) != CAIRO_STATUS_SUCCESS) {
        cairo_destroy(cr);
        cairo_destroy(comparison_cr);
        cairo_surface_destroy(surface);
        cairo_surface_destroy(comparison);
        return -1;
    }

    (void)draw_grid_contents(&context, cr, allocation);
    result->first_frame_owned_allocations =
        renderer_owned_allocation_count(&context);
    result->peak_owned_scratch_bytes = renderer_owned_scratch_bytes(&context);
    guint allocations_before_warm = renderer_owned_allocation_count(&context);
    uint64_t samples[NOCTTY_RENDERER_QUALIFICATION_FRAMES];
    for (size_t frame = 0;
         frame < NOCTTY_RENDERER_QUALIFICATION_FRAMES; frame++) {
        uint64_t started = renderer_process_cpu_ns();
        (void)draw_grid_contents(&context, cr, allocation);
        uint64_t finished = renderer_process_cpu_ns();
        if (started == 0 || finished <= started) {
            cairo_destroy(cr);
            cairo_destroy(comparison_cr);
            cairo_surface_destroy(surface);
            cairo_surface_destroy(comparison);
            destroy_grid_glyph_cache(&context);
            g_clear_pointer(&context.row_cells, g_free);
            return -1;
        }
        samples[frame] = finished - started;
        result->peak_owned_scratch_bytes = MAX(
            result->peak_owned_scratch_bytes,
            renderer_owned_scratch_bytes(&context));
    }
    result->warm_frame_owned_allocations =
        renderer_owned_allocation_count(&context) - allocations_before_warm;
    qsort(samples, NOCTTY_RENDERER_QUALIFICATION_FRAMES,
          sizeof(samples[0]), compare_renderer_sample);
    result->p50_cpu_ns = renderer_percentile(
        samples, NOCTTY_RENDERER_QUALIFICATION_FRAMES, 50);
    result->p95_cpu_ns = renderer_percentile(
        samples, NOCTTY_RENDERER_QUALIFICATION_FRAMES, 95);
    result->p99_cpu_ns = renderer_percentile(
        samples, NOCTTY_RENDERER_QUALIFICATION_FRAMES, 99);
    result->pixel_hash = renderer_surface_hash(surface, allocation);

    (void)draw_grid_contents(&context, comparison_cr, allocation);
    result->pixel_diff = renderer_surface_pixel_diff(
        surface, comparison, allocation);
    result->row_buffer_allocations = context.row_buffer_allocations;
    result->glyph_scratch_allocations = context.glyph_scratch_allocations;
    result->glyph_cache_builds = context.glyph_cache_builds;

    char artifact_path[4096];
    int path_length = g_snprintf(
        artifact_path, sizeof(artifact_path), "%s/%s.png",
        artifact_directory, artifact_name);
    cairo_status_t artifact_status = path_length > 0 &&
            (size_t)path_length < sizeof(artifact_path)
        ? cairo_surface_write_to_png(surface, artifact_path)
        : CAIRO_STATUS_WRITE_ERROR;

    cairo_destroy(cr);
    cairo_destroy(comparison_cr);
    cairo_surface_destroy(surface);
    cairo_surface_destroy(comparison);
    destroy_grid_glyph_cache(&context);
    g_clear_pointer(&context.row_cells, g_free);
    return artifact_status == CAIRO_STATUS_SUCCESS &&
        result->pixel_diff == 0 &&
        result->warm_frame_owned_allocations == 0 ? 0 : -1;
}

static int renderer_resize_scratch_qualification(
    guint *growth_allocations, guint *shrink_allocations,
    size_t *peak_owned_scratch_bytes) {
    NocttyRendererFixture fixture = {
        .scenario = 1,
        .columns = 80,
        .rows = 24,
    };
    NocttyGridContext context;
    renderer_init_context(&context, &fixture);
    GtkAllocation allocation = renderer_allocation_for_context(&context);
    cairo_surface_t *surface = cairo_image_surface_create(
        CAIRO_FORMAT_ARGB32, allocation.width, allocation.height);
    cairo_t *cr = cairo_create(surface);
    if (cairo_surface_status(surface) != CAIRO_STATUS_SUCCESS ||
        cairo_status(cr) != CAIRO_STATUS_SUCCESS) {
        cairo_destroy(cr);
        cairo_surface_destroy(surface);
        return -1;
    }
    (void)draw_grid_contents(&context, cr, allocation);
    *peak_owned_scratch_bytes = renderer_owned_scratch_bytes(&context);
    guint before_growth = context.row_buffer_allocations +
        context.glyph_scratch_allocations;
    cairo_destroy(cr);
    cairo_surface_destroy(surface);

    fixture.columns = 160;
    fixture.rows = 50;
    context.columns = fixture.columns;
    context.rows = fixture.rows;
    allocation = renderer_allocation_for_context(&context);
    surface = cairo_image_surface_create(
        CAIRO_FORMAT_ARGB32, allocation.width, allocation.height);
    cr = cairo_create(surface);
    (void)draw_grid_contents(&context, cr, allocation);
    *growth_allocations = context.row_buffer_allocations +
        context.glyph_scratch_allocations - before_growth;
    *peak_owned_scratch_bytes = MAX(
        *peak_owned_scratch_bytes, renderer_owned_scratch_bytes(&context));
    guint before_shrink = context.row_buffer_allocations +
        context.glyph_scratch_allocations;
    cairo_destroy(cr);
    cairo_surface_destroy(surface);

    fixture.columns = 80;
    fixture.rows = 24;
    context.columns = fixture.columns;
    context.rows = fixture.rows;
    allocation = renderer_allocation_for_context(&context);
    surface = cairo_image_surface_create(
        CAIRO_FORMAT_ARGB32, allocation.width, allocation.height);
    cr = cairo_create(surface);
    (void)draw_grid_contents(&context, cr, allocation);
    *shrink_allocations = context.row_buffer_allocations +
        context.glyph_scratch_allocations - before_shrink;
    cairo_destroy(cr);
    cairo_surface_destroy(surface);
    destroy_grid_glyph_cache(&context);
    g_clear_pointer(&context.row_cells, g_free);
    return *growth_allocations > 0 && *shrink_allocations == 0 ? 0 : -1;
}

int noctty_native_grid_renderer_qualification(
    const char *artifact_directory, const char *mode) {
    if (artifact_directory == NULL || artifact_directory[0] == '\0' ||
        mode == NULL || mode[0] == '\0')
        return -1;
    NocttyRendererQualificationResult idle = {0};
    NocttyRendererQualificationResult full = {0};
    NocttyRendererQualificationResult rich = {0};
    guint resize_growth_allocations = 0;
    guint resize_shrink_allocations = 0;
    size_t resize_peak_scratch_bytes = 0;
    if (renderer_qualify_scenario(
            0, artifact_directory, "idle", &idle) != 0 ||
        renderer_qualify_scenario(
            1, artifact_directory, "fullscreen", &full) != 0 ||
        renderer_qualify_scenario(
            2, artifact_directory, "rich-style", &rich) != 0 ||
        renderer_resize_scratch_qualification(
            &resize_growth_allocations, &resize_shrink_allocations,
            &resize_peak_scratch_bytes) != 0)
        return -1;

    guint pixel_diff = idle.pixel_diff + full.pixel_diff + rich.pixel_diff;
    guint warm_allocations = idle.warm_frame_owned_allocations +
        full.warm_frame_owned_allocations + rich.warm_frame_owned_allocations;
    size_t peak_scratch_bytes = MAX(
        resize_peak_scratch_bytes,
        MAX(idle.peak_owned_scratch_bytes,
            MAX(full.peak_owned_scratch_bytes,
                rich.peak_owned_scratch_bytes)));
    g_print(
        "native_grid_renderer_qualification mode=%s frames=384 "
        "frames_per_scenario=128 scenarios=3 columns=160 rows=50 "
        "idle_p50_cpu_ns=%llu idle_p95_cpu_ns=%llu idle_p99_cpu_ns=%llu "
        "fullscreen_p50_cpu_ns=%llu fullscreen_p95_cpu_ns=%llu "
        "fullscreen_p99_cpu_ns=%llu rich_p50_cpu_ns=%llu "
        "rich_p95_cpu_ns=%llu rich_p99_cpu_ns=%llu "
        "idle_hash=%llu fullscreen_hash=%llu rich_hash=%llu pixel_diff=%u "
        "first_frame_owned_allocations=%u warm_frame_owned_allocations=%u "
        "resize_growth_allocations=%u resize_shrink_allocations=%u "
        "peak_owned_scratch_bytes=%zu row_buffer_allocations=%u "
        "glyph_scratch_allocations=%u glyph_cache_builds=%u "
        "artifacts=3 assertions=true\n",
        mode,
        (unsigned long long)idle.p50_cpu_ns,
        (unsigned long long)idle.p95_cpu_ns,
        (unsigned long long)idle.p99_cpu_ns,
        (unsigned long long)full.p50_cpu_ns,
        (unsigned long long)full.p95_cpu_ns,
        (unsigned long long)full.p99_cpu_ns,
        (unsigned long long)rich.p50_cpu_ns,
        (unsigned long long)rich.p95_cpu_ns,
        (unsigned long long)rich.p99_cpu_ns,
        (unsigned long long)idle.pixel_hash,
        (unsigned long long)full.pixel_hash,
        (unsigned long long)rich.pixel_hash,
        pixel_diff,
        idle.first_frame_owned_allocations +
            full.first_frame_owned_allocations +
            rich.first_frame_owned_allocations,
        warm_allocations,
        resize_growth_allocations,
        resize_shrink_allocations,
        peak_scratch_bytes,
        idle.row_buffer_allocations + full.row_buffer_allocations +
            rich.row_buffer_allocations,
        idle.glyph_scratch_allocations + full.glyph_scratch_allocations +
            rich.glyph_scratch_allocations,
        idle.glyph_cache_builds + full.glyph_cache_builds +
            rich.glyph_cache_builds);
    return pixel_diff == 0 && warm_allocations == 0 &&
        resize_growth_allocations > 0 && resize_shrink_allocations == 0
        ? 0 : -1;
}

int noctty_native_grid_pipeline_qualification(
    const NocttyGridCallbacks *callbacks, int columns, int rows,
    NocttyGridPipelineAdvance advance, void *advance_data,
    const char *artifact_path, const char *mode) {
    if (callbacks == NULL ||
        callbacks->abi_version != NOCTTY_NATIVE_GRID_ABI_VERSION ||
        callbacks->struct_size < sizeof(*callbacks) ||
        callbacks->cell == NULL || callbacks->row == NULL ||
        callbacks->color_rgb == NULL || callbacks->cell_text == NULL ||
        callbacks->cursor == NULL || advance == NULL ||
        columns <= 0 || rows <= 0 || artifact_path == NULL ||
        artifact_path[0] == '\0' || mode == NULL || mode[0] == '\0')
        return -1;

    NocttyGridContext context = {0};
    context.root = &context;
    context.userdata = callbacks->userdata;
    context.cell = callbacks->cell;
    context.row = callbacks->row;
    context.color_rgb = callbacks->color_rgb;
    context.ui_color_rgb = callbacks->ui_color_rgb;
    context.cell_text = callbacks->cell_text;
    context.cell_hyperlink = callbacks->cell_hyperlink;
    context.cursor = callbacks->cursor;
    context.active = 1;
    context.cursor_visible = callbacks->cursor(callbacks->userdata) != UINT32_MAX;
    context.columns = columns;
    context.rows = rows;
    context.font_size = 14.0;
    context.requested_font_size = 14.0;
    context.font_family = (gchar *)"monospace";

    GtkAllocation allocation = renderer_allocation_for_context(&context);
    cairo_surface_t *surface = cairo_image_surface_create(
        CAIRO_FORMAT_ARGB32, allocation.width, allocation.height);
    cairo_t *cr = cairo_create(surface);
    if (cairo_surface_status(surface) != CAIRO_STATUS_SUCCESS ||
        cairo_status(cr) != CAIRO_STATUS_SUCCESS) {
        cairo_destroy(cr);
        cairo_surface_destroy(surface);
        return -1;
    }

    uint64_t input_samples[NOCTTY_PIPELINE_QUALIFICATION_SAMPLES];
    uint64_t read_samples[NOCTTY_PIPELINE_QUALIFICATION_SAMPLES];
    uint64_t draw_samples[NOCTTY_PIPELINE_QUALIFICATION_SAMPLES];
    size_t output_bytes = 0;
    guint first_frame_owned_allocations = 0;
    guint warm_frame_owned_allocations = 0;
    for (size_t sample = 0;
         sample < NOCTTY_PIPELINE_QUALIFICATION_SAMPLES; sample++) {
        uint64_t input_to_grid_ns = 0;
        uint64_t read_to_grid_ns = 0;
        size_t sample_output_bytes = 0;
        if (advance(advance_data, sample, &input_to_grid_ns,
                    &read_to_grid_ns, &sample_output_bytes) != 0 ||
            input_to_grid_ns == 0 || read_to_grid_ns == 0)
            goto pipeline_failure;
        output_bytes += sample_output_bytes;

        guint allocations_before = renderer_owned_allocation_count(&context);
        uint64_t draw_cpu_started = renderer_process_cpu_ns();
        uint64_t draw_started = renderer_monotonic_ns();
        (void)draw_grid_contents(&context, cr, allocation);
        uint64_t draw_finished = renderer_monotonic_ns();
        uint64_t draw_cpu_finished = renderer_process_cpu_ns();
        if (draw_finished <= draw_started ||
            draw_cpu_finished <= draw_cpu_started)
            goto pipeline_failure;
        guint frame_allocations =
            renderer_owned_allocation_count(&context) - allocations_before;
        if (sample == 0)
            first_frame_owned_allocations = frame_allocations;
        else
            warm_frame_owned_allocations += frame_allocations;
        uint64_t draw_wall_ns = draw_finished - draw_started;
        input_samples[sample] = input_to_grid_ns + draw_wall_ns;
        read_samples[sample] = read_to_grid_ns + draw_wall_ns;
        draw_samples[sample] = draw_cpu_finished - draw_cpu_started;
    }

    qsort(input_samples, NOCTTY_PIPELINE_QUALIFICATION_SAMPLES,
          sizeof(input_samples[0]), compare_renderer_sample);
    qsort(read_samples, NOCTTY_PIPELINE_QUALIFICATION_SAMPLES,
          sizeof(read_samples[0]), compare_renderer_sample);
    qsort(draw_samples, NOCTTY_PIPELINE_QUALIFICATION_SAMPLES,
          sizeof(draw_samples[0]), compare_renderer_sample);
    uint64_t pixel_hash = renderer_surface_hash(surface, allocation);
    cairo_status_t artifact_status =
        cairo_surface_write_to_png(surface, artifact_path);
    size_t peak_owned_scratch_bytes = renderer_owned_scratch_bytes(&context);
    g_print(
        "native_grid_pipeline_qualification mode=%s samples=64 "
        "columns=%d rows=%d output_bytes=%zu "
        "input_write_to_draw_p50_ns=%llu input_write_to_draw_p95_ns=%llu "
        "input_write_to_draw_p99_ns=%llu "
        "pty_read_to_draw_p50_ns=%llu pty_read_to_draw_p95_ns=%llu "
        "pty_read_to_draw_p99_ns=%llu "
        "draw_p50_cpu_ns=%llu draw_p95_cpu_ns=%llu draw_p99_cpu_ns=%llu "
        "pixel_hash=%llu first_frame_owned_allocations=%u "
        "warm_frame_owned_allocations=%u peak_owned_scratch_bytes=%zu "
        "production_pty=true production_vt=true production_cairo=true "
        "display_independent=true compositor_presented=false artifact=true "
        "assertions=true\n",
        mode, columns, rows, output_bytes,
        (unsigned long long)renderer_percentile(
            input_samples, NOCTTY_PIPELINE_QUALIFICATION_SAMPLES, 50),
        (unsigned long long)renderer_percentile(
            input_samples, NOCTTY_PIPELINE_QUALIFICATION_SAMPLES, 95),
        (unsigned long long)renderer_percentile(
            input_samples, NOCTTY_PIPELINE_QUALIFICATION_SAMPLES, 99),
        (unsigned long long)renderer_percentile(
            read_samples, NOCTTY_PIPELINE_QUALIFICATION_SAMPLES, 50),
        (unsigned long long)renderer_percentile(
            read_samples, NOCTTY_PIPELINE_QUALIFICATION_SAMPLES, 95),
        (unsigned long long)renderer_percentile(
            read_samples, NOCTTY_PIPELINE_QUALIFICATION_SAMPLES, 99),
        (unsigned long long)renderer_percentile(
            draw_samples, NOCTTY_PIPELINE_QUALIFICATION_SAMPLES, 50),
        (unsigned long long)renderer_percentile(
            draw_samples, NOCTTY_PIPELINE_QUALIFICATION_SAMPLES, 95),
        (unsigned long long)renderer_percentile(
            draw_samples, NOCTTY_PIPELINE_QUALIFICATION_SAMPLES, 99),
        (unsigned long long)pixel_hash, first_frame_owned_allocations,
        warm_frame_owned_allocations, peak_owned_scratch_bytes);
    cairo_destroy(cr);
    cairo_surface_destroy(surface);
    destroy_grid_glyph_cache(&context);
    g_clear_pointer(&context.row_cells, g_free);
    return artifact_status == CAIRO_STATUS_SUCCESS && pixel_hash != 0 &&
        first_frame_owned_allocations > 0 && warm_frame_owned_allocations == 0
        ? 0 : -1;

pipeline_failure:
    cairo_destroy(cr);
    cairo_surface_destroy(surface);
    destroy_grid_glyph_cache(&context);
    g_clear_pointer(&context.row_cells, g_free);
    return -1;
}
