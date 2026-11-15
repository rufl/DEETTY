/*
 * Native Linux GTK/Cairo host for the production terminal grid.
 *
 * Zig owns terminal, workspace, configuration, and persistence state. This
 * file owns GTK object lifetimes, Pango glyph caches, GLib main-loop sources,
 * and the C side of native_grid_abi.h. Zig owns extracted Cairo primitives and
 * model policy. Keep decisions behind those ABIs so GTK
 * object lifetimes and terminal-session lifetimes remain independently
 * testable. DEETTY_ENABLE_SMOKE adds qualification orchestration; it must not
 * alter production behavior.
 */
#include <epoxy/gl.h>
#include <gtk/gtk-a11y.h>
#include <gdk/gdkwayland.h>
#include <glib-unix.h>
#include <glib/gstdio.h>
#include <pango/pangocairo.h>
#include <dlfcn.h>
#include <unistd.h>
#include <stdint.h>
#include <stddef.h>
#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <math.h>
#include <malloc.h>
#include <stdlib.h>
#include <time.h>
#include <sys/stat.h>

#include "../../include/deetty/native_gtk.h"
#include "../../include/deetty/native_grid_abi.h"
#include "../../include/deetty/native_grid_logic.h"
#include "../../include/deetty/native_grid_render.h"
#define DEETTY_GRID_HOST_EVENT(kind) \
    deetty_grid_host_event_code(DEETTY_GRID_HOST_EVENT_##kind)

#ifndef DEETTY_ENABLE_SMOKE
#define DEETTY_ENABLE_SMOKE 0
#endif
#if DEETTY_ENABLE_SMOKE
#include "../../tests/native_grid_smoke_constants.inc"
#endif


typedef enum {
    DEETTY_FOCUS_SMOKE_PRIMARY_ACTION = 0,
    DEETTY_FOCUS_SMOKE_PRIMARY_CHECK = 1,
    DEETTY_FOCUS_SMOKE_SECONDARY_ACTION = 2,
    DEETTY_FOCUS_SMOKE_SECONDARY_CHECK = 3,
    DEETTY_FOCUS_SMOKE_ZOOM = 4,
    DEETTY_FOCUS_SMOKE_RELEASE = 5,
} DeettyFocusSmokeStage;
extern void *deetty_grid_create_session(void *, uint64_t, int, int, int, uint64_t *);
extern int deetty_grid_tab_position(void *);
extern int deetty_grid_tab_title(void *, uint64_t, char *, size_t);
extern uint32_t deetty_grid_tab_color(void *, uint64_t, int *, int *);
extern int deetty_grid_set_tab_color(void *, uint64_t, int);
extern int deetty_grid_adjust_tab_color(void *, uint64_t, int);
extern int deetty_grid_rename_tab(void *, uint64_t, const char *, size_t);
extern int deetty_grid_reorder_tab(void *, uint64_t, int);
extern int deetty_grid_tab_index_for_pane(void *, uint64_t);
extern int deetty_grid_close_tab(void *, uint64_t);
extern int deetty_grid_close_pane(void *, uint64_t, uint64_t *, int *);
extern int deetty_grid_close_session(void *, void *);
extern int deetty_grid_close_transport(void *);
extern int deetty_grid_has_foreground_process(void *);
extern int deetty_grid_process_name(void *, uint8_t *, size_t);
extern int deetty_grid_apply_preset(void *, uint64_t, int, uint64_t *, size_t);
extern int deetty_grid_current_directory(void *, void *, uint64_t, char *, size_t);
extern int deetty_grid_pane_info(void *, void *, uint64_t, char *, size_t,
                                 char *, size_t);
extern int deetty_grid_compact_setting(void *, int);
extern int deetty_grid_theme_count(void *);
extern int deetty_grid_theme_name(void *, int, char *, size_t);
extern int deetty_grid_active_theme_name(void *, char *, size_t);
extern int deetty_grid_pane_theme_name(void *, uint64_t, char *, size_t);
extern int deetty_grid_set_tab_theme(void *, uint64_t, const char *, size_t);
extern uint32_t deetty_grid_pane_terminal_color_rgb(void *, uint64_t, uint32_t);
extern uint32_t deetty_grid_pane_background_rgb(void *, uint64_t);
extern uint32_t deetty_grid_pane_cursor_rgb(void *, uint64_t);
extern uint32_t deetty_grid_pane_gap_rgb(void *, uint64_t);
extern int deetty_grid_launch_profile(void *, int, char *, size_t);
extern int deetty_grid_launch_profile_library(void *, int, int, char *, size_t);
extern int deetty_grid_find(void *, const char *, size_t, int, size_t,
                            int *, int *, int *, int *);
extern int deetty_grid_scrollback(void *, char *, size_t);
extern int deetty_grid_scroll_state(void *, uint64_t *, uint64_t *, uint32_t *);
extern uint64_t deetty_grid_bell_serial(void *);
extern uint64_t deetty_grid_notification_serial(void *);
extern int deetty_grid_notification_action(void *);
extern int deetty_grid_notification_title(void *, char *, size_t);
extern int deetty_grid_notification_body(void *, char *, size_t);
extern int deetty_grid_set_agent_resume(void *, uint64_t, int, const char *, size_t, const char *, size_t);
extern int deetty_grid_clear_agent_resume(void *, uint64_t);
extern int deetty_grid_save_encrypted_history(void *, void *, const char *, size_t, const char *, size_t);
extern int deetty_grid_pty_fd(void *);
extern int deetty_grid_compact_idle_history(void *);
extern int deetty_grid_control(void *, const char *, size_t);
extern int deetty_grid_write_pending(void *);
extern int deetty_grid_flush_write(void *);
extern int deetty_grid_workspace_dirty(void *);
extern int deetty_grid_pane_selected(void *, uint64_t);
extern int deetty_grid_pane_profile(void *, uint64_t, char *, size_t,
                                    int *, int *, int *);
extern int deetty_grid_pane_tags(void *, uint64_t, char *, size_t);
extern int deetty_grid_known_tags(void *, char *, size_t);
extern int deetty_grid_pane_matches_smart_filter(void *, uint64_t);
extern int deetty_grid_tag_selected_panes(void *, const char *, size_t);
extern int deetty_grid_remove_tag_from_selected_panes(void *, const char *, size_t);
extern int deetty_grid_set_smart_filter(void *, const char *, size_t);
extern int deetty_grid_broadcast_enabled(void *);
extern int deetty_grid_hot_session_loaded(void *);
extern int deetty_grid_recent_workspace(void *, int, char *, size_t);
extern int deetty_grid_restore_tab_count(void *);
extern int deetty_grid_restore_active_tab(void *);
extern int deetty_grid_restore_tab_index_for_pane(void *, uint64_t);
extern int deetty_grid_restore_tab_info(void *, int, int *, uint64_t *, int *, int *);
extern int deetty_grid_restore_pane_id(void *, int, int, uint64_t *);
extern int deetty_grid_restore_layout_node(void *, int, int, int *, uint64_t *, int *, int *, int *, int *);
extern int deetty_grid_set_layout_ratio(void *, int, int, int);
extern int deetty_grid_flush_hot_session(void *);
extern int deetty_grid_smart_filter_tag(void *, char *, size_t);
extern int deetty_grid_share_peer(void *, int, char *, size_t, char *, size_t,
                                  uint16_t *, int *);
extern int deetty_grid_share_discovered(void *, char *, size_t, char *, size_t,
                                        uint16_t *);
extern int deetty_grid_share_action(void *, int, int, const char *, size_t,
                                    const char *, size_t, uint16_t);
extern int deetty_grid_share_status(void *, uint32_t *, uint16_t *);
extern int deetty_grid_share_view_dimensions(void *, uint16_t *, uint16_t *);
extern uint64_t deetty_grid_share_view_cell(void *, int, int);
extern int deetty_grid_share_view_cell_text(void *, int, int, uint8_t *, size_t);
extern uint32_t deetty_grid_share_view_color(void *, uint32_t);
extern uint32_t deetty_grid_share_view_cursor(void *);
extern int deetty_grid_share_view_cursor_mode(void *);
extern int deetty_grid_share_view_bracketed_paste(void *);
extern int deetty_grid_share_view_title(void *, uint8_t *, size_t);
extern int deetty_grid_share_view_tab(void *, int, uint8_t *, size_t,
                                      uint64_t *, int *, int *);
extern int deetty_grid_share_view_select_tab(void *, int);
extern int deetty_grid_share_view_stream(void *, int, uint8_t *, size_t,
                                         uint64_t *, uint64_t *, int *);
extern uint64_t deetty_grid_share_view_revision(void *);
extern int deetty_grid_share_view_select(void *, int);
extern int deetty_grid_share_view_scroll(void *, int);
extern int deetty_grid_share_view_input(void *, const uint8_t *, size_t);
extern int deetty_grid_share_view_pane_layout(
    void *, int, uint32_t *, uint32_t *, uint32_t *, uint32_t *, int *, int *);
extern int deetty_grid_share_view_pane_dimensions(void *, int, uint16_t *,
                                                   uint16_t *);
extern uint64_t deetty_grid_share_view_pane_cell(void *, int, int, int);
extern int deetty_grid_share_view_pane_cell_text(
    void *, int, int, int, uint8_t *, size_t);
extern uint32_t deetty_grid_share_view_pane_color(void *, int, uint32_t);
extern uint32_t deetty_grid_share_view_pane_cursor(void *, int);
extern int deetty_qt_shortcut_from_gdk(guint keyval, guint state);

typedef struct DeettyGridContextTag {
    GtkWidget *window;
    GtkWidget *area;
    GtkWidget *page;
    GtkWidget *notebook;
    GtkWidget *revealer;
    GtkWidget *content_box;
    GtkWidget *pane_info_strip;
    GtkWidget *resize_grip;
    GtkWidget *window_layout;
    GtkWidget *window_resize_handles[8];
    GtkWidget *paned;
    GtkWidget *tab_label;
    GtkWidget *new_tab_button;
    GtkWidget *window_toolbar_controls;
    GtkWidget *window_settings_button;
    GtkWidget *window_close_button;
    GtkWidget *smart_filter_button;
    GtkWidget *smart_filter_empty_box;
    GtkWidget *smart_filter_empty_label;
    GtkWidget *smart_filter_empty_clear_button;
    GtkWidget *tab_rename_entry;
    GtkWidget *tab_rename_page;
    GtkWidget *tab_rename_event_box;
    GtkWidget *settings_dialog;
    GtkWidget *theme_dialog;
    GtkWidget *settings_categories;
    GtkWidget *settings_stack;
    GtkWidget *settings_pane_info_toggle;
    GtkWidget *settings_launch_library;
    GtkWidget *settings_launch_name;
    GtkWidget *settings_launch_kind;
    GtkWidget *settings_launch_shell;
    GtkWidget *settings_launch_command;
    GtkWidget *settings_launch_cwd;
    GtkWidget *settings_launch_environment;
    GtkWidget *settings_launch_ssh_target;
    GtkWidget *settings_launch_scrollback;
    GtkWidget *settings_launch_apply;
    GtkWidget *settings_launch_save;
    GtkWidget *settings_launch_delete;
    GtkWidget *settings_launch_status;
    GtkWidget *sharing_dialog;
    guint sharing_status_source;
    uint64_t sharing_stream_revision;
    gint64 sharing_feedback_until_us;
    int sharing_last_status;
    int sharing_scope_smoke_ok;
    int sharing_dialog_scrollable;
    int sharing_dialog_stacking;
    int sharing_dialog_grouped_actions;
    uint64_t sharing_layout_pane_mask;
    int sharing_layout_selected_seen;
    int sharing_layout_host_active_seen;
    GtkWidget *shortcut_recorder_dialog;
    GtkWidget *shortcut_recorder_feedback;
    GtkWidget *palette_dialog;
    GtkWidget *palette_search;
    GtkWidget *palette_list;
    GtkWidget *find_dialog;
    GtkWidget *find_entry;
    GtkWidget *find_status;
    GtkWidget *note_dialog;
    GtkWidget *note_view;
    GtkWidget *note_status;
    gchar *note_overlay_text;
    gchar *note_overlay_label;
    PangoFontDescription *note_overlay_font;
    gchar *status_feedback_text;
    guint status_feedback_source;
    int status_feedback_drawn;
    GtkWidget *shortcuts_dialog;
    GtkIMContext *im_context;
    GtkWidget *project_dialog;
    GtkWidget *recent_workspace_combo;
    GtkWidget *recent_workspace_open;
    GtkWidget *workspace_menu;
    gchar *display_title;
    gchar *smart_filter_tag;
    GPtrArray *contexts;
    struct DeettyGridContextTag *root;
    void *userdata;
    DeettyGridPump pump;
    DeettyGridWrite write;
    DeettyGridFrame frame;
    DeettyGridDirtyRows dirty_rows;
    DeettyGridDirtySpans dirty_spans;
    DeettyGridPresentationReady presentation_ready;
    DeettyGridColorRgb color_rgb;
    DeettyGridUiColorRgb ui_color_rgb;
    DeettyGridCellText cell_text;
    DeettyGridCellHyperlink cell_hyperlink;
    DeettyGridPollExit poll_exit;
    DeettyGridResize resize;
    DeettyGridMouse mouse;
    DeettyGridPaste paste;
    DeettyGridCopy copy;
    DeettyGridScroll scroll;
    DeettyGridCursor cursor;
    DeettyGridTitle title;
    DeettyGridCursorMode cursor_mode;
    DeettyGridMouseMode mouse_mode;
    DeettyGridFocus focus;
    DeettyGridEvent event;
    DeettyGridTextAction text_action;
    DeettyGridCreateSession create_session;
    void *event_data;
    void *text_action_data;
    uint64_t pane_id;
    int selecting;
    int selection_dragging;
    int selection_start_column;
    int selection_start_row;
    int selection_end_column;
    int selection_end_row;
    int scrollbar_dragging;
    int scrollbar_hovered;
    double scrollbar_drag_offset;
    int selection_border_drawn;
    int tag_filter_applied;
    int tag_filter_match;
    int tag_filter_untagged_hidden;
    int tag_filter_cleared;
    int tag_filter_indicator_visible;
    int tag_filter_focus_restored;
    int tag_filter_empty_state_visible;
    int tag_filter_empty_clear;
    int tag_filter_empty_context;
    int tag_filter_empty_escape;
    int tag_suggestions_visible;
    int selection_indicator_visible;
    int preserve_double_click_selection;
    int suppress_primary_release;
    int cursor_visible;
    int focused;
    int columns;
    int rows;
    int saw_draw;
    int exited;
    int exit_code;
    int dogfood_omp_seen;
    int dogfood_omp_input_seen;
    int dogfood_omp_paste_seen;
    int dogfood_omp_focus_seen;
    int dogfood_omp_resize_seen;
    int dogfood_omp_normal_exit_seen;
    uint64_t dogfood_omp_output_bytes;
    int dogfood_omp_feed_failed;
    guint dogfood_omp_max_concurrent;
    guint dogfood_omp_hidden_count;
    int dogfood_omp_streaming_seen;
    int dogfood_omp_hide_seen;
    int dogfood_omp_hot_restore_seen;
    int dogfood_omp_workspace_emitted;
    int dogfood_omp_hide_show_seen;
    int mode;
    GDBusConnection *shortcut_bus;
    guint shortcut_subscription;
    int shortcut_action_registered;
    int shortcut_registered;
    int shortcut_invoked;
    int shortcut_hidden_before_registration;
    guint window_map_count;
    int shortcut_transport;
    int requested_shortcut_key;
    int shortcut_recorder_prior_key;
    int shortcut_recorder_restore_on_destroy;
    int shortcut_recorder_shown;
    int shortcut_recorder_settings_hidden;
    int shortcut_recorder_settings_handoff;
    int shortcut_recorder_settings_restored;
    int shortcut_recorded;
    guint shortcut_generation;
    GCancellable *dbus_cancellable;
    guint dbus_pending_operations;
    GDBusConnection *control_bus;
    GDBusNodeInfo *control_node;
    guint control_object_id;
    int control_registered;
    int control_name_conflict;
    int control_conflict_forwarded;
    int claim_control;
    int show_on_control_conflict;
    guint32 recovery_notice_flags;
    GtkWidget *recovery_notice;
    gchar *xdg_activation_token;
    int xdg_activation_token_received;
    int xdg_activation_token_applied;
    int control_status_seen;
    int control_status_count;
    int control_show_seen;
    int control_hide_seen;
    int control_toggle_seen;
    GDBusConnection *tray_bus;
    GDBusNodeInfo *tray_node;
    GDBusNodeInfo *tray_menu_node;
    GVariant *tray_icon_pixmaps;
    guint tray_object_id;
    guint tray_menu_object_id;
    guint tray_watcher_subscription;
    guint tray_menu_revision;
    int tray_registered;
    int tray_menu_registered;
    int tray_watcher_registered;
    int tray_icon_available;
    int tray_activation_count;
    int tray_secondary_seen;
    int tray_context_seen;
    int tray_menu_layout_seen;
    int tray_close_seen;
    int tray_close_session_stopped;
    DeettyGridCloseCoordinator application_close;
    guint application_close_deferred_source;
    guint application_close_preflight_source;
    void *layer_shell_library;
    int layer_shell_active;
    int layer_shell_allowed;
    int layer_shell_keyboard_mode;
    GdkMonitor *layer_shell_monitor;
    int window_presented;
    guint window_mode_recreate_source;
    guint resolution_adapt_source;
    int monitor_workarea_x;
    int monitor_workarea_y;
    int monitor_workarea_width;
    int monitor_workarea_height;
    int monitor_geometry_x;
    int monitor_geometry_y;
    int monitor_geometry_width;
    int monitor_geometry_height;
    int monitor_scale_factor;
    int window_mode_surface_recreated;
    int workspace_smoke;
    int workspace_visual_attempts;
    int dropdown_minimum_geometry;
    int primary;
    int active;
    int retiring;
    int clipboard_pasted;
    int clipboard_copy_valid;
    int broadcast_confirmation_explicit;
    int broadcast_confirmation_cancel_default;
    int broadcast_disable_immediate;
    int broadcast_disable_feedback;
    int broadcast_state_label;
    int enable_notifications;
    int notification_delivered;
    int status_kind;
    int settings_opened;
    int settings_category_count;
    int settings_category_accessible;
    int settings_category_focusable;
    int settings_category_focus_initial;
    int settings_category_tooltips;
    int settings_visual_polish;
    int settings_background_support_notice;
    int settings_metric_thickness_live;
    int settings_narrow_access;
    int settings_page_switched;
    int settings_shortcut_label_current;
    int settings_shortcut_label_updated;
    int settings_reopened_after_mode_change;
    int settings_stacking_visible;
    int settings_transient_parent;
    int settings_keep_above;
    int settings_layer_overlay;
    int settings_parent_layer_lowered;
    int settings_parent_layer_lowered_seen;
    int settings_parent_layer_restored;
    int settings_stacking_ready;
    guint overlay_dialog_count;
    int settings_geometry_sane;
    int application_icon_ready;
    int theme_imported;
    int theme_visual_polish;
    int theme_import_dialog_built;
    int system_noctalia_theme_listed;
    int system_noctalia_theme_applied;
    int project_smoke_done;
    int project_visual_polish;
    int project_smoke_attempts;
    int project_summary_scrollable;
    int project_summary_accessible;
    int context_menu_opened;
    int context_menu_survived;
    int editor_here_opened;
    int nocted_launch_attempted;
    int nocted_launch_succeeded;
    int nocted_process_separate;
    int nocted_directory_resolved;
    int recent_workspace_control;
    int recent_workspace_parent_rendered;
    int recent_workspace_child_launched;
    int recent_workspace_child_clicked;
    int activation_child_receipt_attempts;
    DeettyFocusSmokeStage focus_click_smoke_stage;
    int focus_click_smoke_attempts;
    int focus_click_primary;
    int focus_click_secondary;
    int focus_click_controlled_exit;
    int focus_double_click_word_selection;
    int focus_double_click_zoom_clean;
    int focus_double_click_restore_clean;
    int focus_drag_selection_preserved;
    int recursive_zoom_full_page;
    int recursive_zoom_restored;
    int tab_position;
    int pane_move_applied;
    int attention;
    uint64_t last_bell_serial;
    uint64_t last_notification_serial;
    int pending_notification_action;
    gint64 last_desktop_notification_us;
    uint64_t zoomed_pane_id;
    uint64_t active_pane_id_for_render;
    size_t find_ordinal;
    int dropdown_width_percent;
    int dropdown_height_percent;
    int dropdown_width_px;
    int dropdown_height_px;
    int dropdown_animation_ms;
    int hide_on_focus_loss;
    int focus_follows_pointer;
    int background_translucency;
    int background_opacity_percent;
    int background_alpha_supported;
    int translucent_surface_ready;
    int panel_padding_px;
    int pane_spacing_px;
    int pane_gaps_enabled;
    int pane_gaps_transparent;
    int inactive_pane_dim_enabled;
    int inactive_pane_brightness_percent;
    int pane_divider_px;
    int pane_border_px;
    int pane_border_focused_px;
    int pane_border_selected_px;
    int status_border_px;
    int overlay_border_px;
    int window_border_px;
    int dragger_px;
    int show_pane_info;
    int compact_tab_height;
    int compact_palette_shown;
    int compact_palette_context_opened;
    int compact_context_submenus;
    int compact_new_1x1_removed;
    int compact_even_distribution_cancelled;
    int compact_palette_rename_suppressed;
    int compact_palette_previous_shortcut;
    int compact_find_shown;
    int compact_note_shown;
    guint compact_accessibility_mask;
    int compact_utility_visual_polish;
    int compact_shortcut_label_dynamic;
    int compact_light_tab_title_inherits;
    int note_overlay_visible;
    int note_overlay_content_loaded;
    int note_overlay_alt_pressed;
    int note_overlay_alt_released;
    int note_overlay_drawn;
    int note_overlay_compact;
    int note_overlay_smoke_panes;
    int note_overlay_smoke_all_drawn;
    int note_overlay_smoke_hidden;
    int hot_session_restored;
    int hot_session_tab_count;
    int hot_session_pane_count;
    int hot_session_layout_ready;
    int hot_session_active_ready;
    int hot_session_smart_filter_ready;
    int layout_restore_applying;
    int compact_zoom_toggled;
    int compact_directional_focus;
    int compact_scrollback_saved;
    int compact_attention_seen;
    int compact_font_scroll_up;
    int compact_font_scroll_down;
    int compact_font_scroll_isolated;
    int compact_font_key_up;
    int compact_font_key_down;
    int compact_font_smooth;
    int compact_plain_scroll_preserved;
    int compact_tui_wheel_mapping;
    int compact_terminal_caret_drawn;
    int compact_dragger_height_toggle;
    int compact_scrollbar_drawn;
    int compact_scrollbar_track_scrolled;
    int compact_scrollbar_thumb_dragged;
    int compact_scrollbar_mouse_mode_wheel;
    int compact_scrollbar_tui_forwarded;
    int compact_hyperlink_open_attempted;
    int compact_hyperlink_context_menu;
    int compact_hyperlink_context_open;
    int compact_hyperlink_mouse_mode_override;
    int compact_hyperlink_underline_positioned;
    int compact_hyperlink_smoke_attempts;
    int compact_linear_selection;
    int compact_linear_selection_copy;
    int compact_background_fill_seamless;
    uint64_t compact_scrollbar_history_lines;
    int compact_keyboard_scrollback_up;
    int compact_keyboard_scrollback_down;
    int compact_terminal_accessible_text;
    int compact_zoom_hid_tab_bar;
    int compact_zoom_restored_tab_bar;
    int compact_pane_info_rendered;
    int compact_pane_info_positioned;
    int compact_pane_info_source;
    int compact_pane_info_dedup;
    int pane_info_setting_control;
    int pane_info_setting_toggled;
    int launch_profile_setting_control;
    int launch_profile_setting_applied;
    int launch_profile_feedback;
    int launch_profile_library_control;
    int launch_profile_library_saved;
    int launch_profile_library_selected;
    int launch_profile_library_removed;
    int tab_rename_inline_shown;
    int tab_rename_inline_embedded;
    int tab_rename_double_click_seen;
    int tab_rename_outside_cancelled;
    int tab_rename_applied;
    int tab_rename_focus_restored;
    int tab_context_menu_opened;
    int tab_context_menu_survived;
    int tab_close_smoke_attempts;
    int tab_close_targeted_background;
    int tab_close_applied;
    int tab_close_session_stopped;
    int tab_close_remaining_focused;
    int late_callback_guarded;
    GtkWidget *tab_reorder_pressed_active_page;
    GtkWidget *tab_reorder_drag_active_page;
    int tab_reorder_dragging;
    int tab_reorder_syncing;
    int tab_reorder_drag_begin_seen;
    int tab_reorder_drag_end_seen;
    int tab_reorder_pointer_press_seen;
    int tab_reorder_pointer_release_seen;
    int tab_reorder_count;
    int tab_reorder_ready_attempts;
    int tab_active_styled;
    int tab_close_button_visible;
    int compact_tab_geometry;
    int compact_tab_strip_extent;
    int compact_tab_widget_extent;
    int compact_tab_max_width;
    int compact_tab_close_extent;
    int compact_tab_action_extent;
    int tab_color_menu_opened;
    int tab_color_preset_applied;
    int tab_color_rendered;
    int tab_color_shortcut_lighten;
    int tab_color_shortcut_darken;
    int tab_color_contrast_ready;
    uint32_t tab_color_initial_rgb;
    uint32_t tab_color_lightened_rgb;
    uint32_t tab_color_restored_rgb;
    int profile_menu_opened;
    int profile_menu_survived;
    int profile_menu_current;
    int profile_menu_active;
    int profile_menu_selected;
    int profile_exact_target;
    int profile_readable;
    int profile_isolated;
    int profile_high_contrast;
    int profile_rendered;
    int profile_mono_no_ligatures;
    int profile_smoke_stage;
    int profile_smoke_attempts;
    double profile_neighbor_font_size;
    int profile_neighbor_high_contrast;
    int profile_neighbor_ligatures;
    int profile_neighbor_preset;
    int new_tab_button_visible;
    int new_tab_button_at_start;
    int new_tab_button_icon;
    int new_tab_button_accessible;
    int new_tab_button_clicked;
    int new_tab_button_visible_after_close;
    int new_tab_button_reopened_after_close;
    int new_tab_button_fresh_context;
    int new_tab_button_cleanup;
    int window_toolbar_visible;
    int window_toolbar_yakuake_order;
    int action_button_pointer_normal;
    int action_button_tooltips_ready;
    int window_settings_button_activated;
    int window_close_button_activated;
    int window_close_session_stopped;
    int pane_cycle_next;
    int alt_scroll_cycle_next;
    int alt_scroll_cycle_previous;
    int alt_scroll_current_tab;
    int alt_scroll_hidden_skipped;
    int ctrl_alt_scroll_cycle_next;
    int ctrl_alt_scroll_cycle_previous;
    int ctrl_alt_scroll_wraparound;
    int pane_cycle_feedback_visible;
    int pane_cycle_feedback_index;
    int pane_cycle_feedback_count;
    int pane_cycle_feedback_drawn;
    uint64_t alt_scroll_start_pane_id;
    GtkWidget *alt_scroll_start_page;
    int tab_cycle_feedback_visible;
    int tab_cycle_feedback_index;
    int tab_cycle_feedback_count;
    int tab_cycle_feedback_drawn;
    GtkWidget *ctrl_alt_scroll_start_page;
    int tab_cycle_next;
    int tab_cycle_previous;
    int tab_cycle_smart_filter;
    int tab_shortcut_close;
    int tab_shortcut_reopen;
    int pane_close_menu_opened;
    int pane_close_menu_survived;
    int pane_close_menu_popped_down;
    int pane_close_targeted_primary;
    int pane_close_applied;
    int pane_close_session_stopped;
    int pane_close_rendered_collapsed;
    int pane_close_remaining_focused;
    int pane_close_last_terminal_protected;
    int pane_split_evenly_distributed;
    int pane_split_two_by_two;
    int pane_split_resize_equal;
    int pane_close_evenly_distributed;
    int pane_close_user_resize_preserved;
    GtkWidget *pane_close_resize_split;
    gint pane_close_resize_position;
    int pane_close_smoke_attempts;
    int terminal_close_prompt_count;
    int terminal_close_prompt_accepted;
    int terminal_close_prompt_busy_count;
    int ctrl_c_local_interrupt;
    int ctrl_d_close_attempted;
    int ctrl_d_close_succeeded;
    int terminal_chord_interrupt_focused;
    int terminal_chord_enter_forwarded;
    int terminal_chord_close_exact;
    int terminal_chord_close_rendered;
    int terminal_chord_close_session_stopped;
    int terminal_chord_remaining_focused;
    int terminal_chord_final_protected;
    uint64_t terminal_chord_closed_pane_id;
    int layout_preset_1x1_applied;
    int layout_preset_2x2_applied;
    int layout_preset_4x2_applied;
    int layout_preset_3x3_applied;
    int layout_preset_4x4_applied;
    int layout_preset_created_count;
    int layout_preset_closed_count;
    int layout_preset_menu_survived;
    int layout_preset_2x2_rendered;
    int layout_preset_4x2_rendered;
    int layout_preset_3x3_rendered;
    int layout_preset_4x4_rendered;
    int layout_preset_1x1_rendered;
    int layout_preset_prompt_count;
    int layout_preset_prompt_cancelled;
    int layout_preset_prompt_accepted;
    int layout_preset_moved_count;
    int layout_preset_remaining_focused;
    int layout_preset_smoke_stage;
    int layout_preset_smoke_attempts;
    int layout_preset_churn_rounds;
    int layout_preset_finalizing;
    int session_creation_focus_deferred;
    int resize_overlay_armed;
    int resize_overlay_visible;
    int resize_overlay_columns;
    int resize_overlay_rows;
    int resize_overlay_zoom_percent;
    int resize_overlay_floor_reached;
    int resize_overlay_initial_suppressed;
    int resize_overlay_show_count;
    int resize_overlay_update_count;
    int resize_overlay_drawn;
    int resize_overlay_hidden;
    int resize_overlay_smoke_initial_hidden;
    int resize_overlay_smoke_visible;
    int resize_overlay_smoke_realtime;
    int resize_overlay_smoke_hidden;
    int resize_overlay_smoke_moves;
    int window_resize_handle_count;
    int window_resize_handle_mask;
    int window_resize_affordance_ready;
    int window_native_decorated;
    int window_native_resizable;
    int window_resize_geometry_changed;
    int window_resize_initial_width;
    int window_resize_initial_height;
    int window_resize_drag_active;
    int window_resize_drag_handle;
    double window_resize_drag_start_x;
    double window_resize_drag_start_y;
    int window_resize_drag_start_width;
    int window_resize_drag_start_height;
    int window_resize_drag_start_width_percent;
    int window_resize_drag_start_height_percent;
    guint32 dragger_last_press_time;
    guint dragger_double_click_source;
    int dragger_click_pending;
    int dragger_height_toggled;
    double font_size;
    double requested_font_size;
    double font_min_size;
    double font_max_size;
    double font_scroll_accumulator;
    double terminal_scroll_accumulator;
    int terminal_scroll_lines;
    int terminal_smooth_scroll;
    double pane_cycle_scroll_accumulator;
    double tab_cycle_scroll_accumulator;
    gchar *font_family;
    int font_antialias;
    int font_hinting;
    int renderer_backend;
    int renderer_backend_requested;
    cairo_surface_t *gpu_surface;
    int gpu_surface_width;
    int gpu_surface_height;
    int gpu_surface_scale;
    GLuint gpu_texture;
    GLuint gpu_program;
    GLuint gpu_vao;
    GLuint gpu_vbo;
    GLint gpu_sampler;
    guint gpu_fallback_source;
    int gpu_fallback_pending;
    int gpu_context_reported;
    guint gpu_render_frames;
    guint gpu_texture_uploads;
    int gpu_receipt_reported;
    guint gpu_fallbacks;
    int ligatures;
    int profile_preset;
    int high_contrast;
    int terminal_metadata_initialized;
    gint64 last_exit_poll_us;
    guint tick_source;
    guint pty_source;
    guint write_flush_source;
    guint output_present_source;
    int output_present_is_tick;
    guint synchronized_output_source;
    int synchronized_output_pending;
    int auto_fit_propagating;
    guint resize_commit_source;
    int pending_resize_columns;
    int pending_resize_rows;
    int pending_resize_width;
    int pending_resize_height;
    uint64_t *frame_cells;
    size_t frame_cell_capacity;
    uint8_t *dirty_row_buffer;
    size_t dirty_row_capacity;
    DeettyGridDirtySpan *dirty_span_buffer;
    size_t dirty_span_capacity;
    cairo_glyph_t *glyph_scratch;
    size_t glyph_scratch_capacity;
    cairo_scaled_font_t *ascii_scaled_fonts[4];
    unsigned long ascii_glyph_indices[4][95];
    uint8_t ascii_glyph_cache_valid[4];
    PangoFontDescription *terminal_font_descriptions[4];
    uint32_t last_cursor_position;
    int damage_initialized;
    int terminal_dirty_rows_used;
    int terminal_dirty_spans_used;
    guint damage_rows_queued;
    guint damage_cells_queued;
    guint damage_spans_queued;
    guint frame_batches_drawn;
    guint glyph_batches_drawn;
    guint glyph_cells_batched;
    guint glyph_cache_hits;
    guint glyph_fallback_conversions;
    guint frame_buffer_allocations;
    guint glyph_scratch_allocations;
    guint glyph_cache_builds;
    guint grapheme_cells_drawn;
    guint rich_style_cells_drawn;
    guint frame_presentations;
    guint timeout_presentations;
#if DEETTY_ENABLE_SMOKE
#include "../../tests/native_grid_smoke_fields.inc"
#endif
    guint synchronized_output_deferrals;
    guint synchronized_output_releases;
    guint synchronized_output_deadman_releases;
    guint resize_requests;
    guint resize_commits;
    guint unmapped_resize_suppressed;
    int pty_fd;
    int pty_output_dirty;
    gint64 last_output_us;
    int idle_history_compacted;
    int pty_event_source_started;
    int descriptor_tick_coalesced;
    int descriptor_maintenance_fallback_seen;
    guint source_cleanup_count;
    guint cursor_blink_source;
    guint maintenance_source;
    guint note_save_source;
    int note_load_failed;
    guint hide_source;
    guint focus_hide_source;
    guint resize_overlay_arm_source;
    guint resize_overlay_hide_source;
    guint focus_deferred_source;
    guint layout_save_source;
    guint pane_cycle_feedback_source;
    guint tab_cycle_feedback_source;
    guint clipboard_requests;
    int heap_allocated;
    struct DeettyGridContextTag *peer;
} DeettyGridContext;

static DeettyGridContext *root_grid_context(DeettyGridContext *context);
static gboolean on_gpu_render(GtkGLArea *area, GdkGLContext *gl_context,
                              gpointer user_data);
static gboolean fallback_grid_renderer_idle(gpointer user_data);
static void destroy_gpu_resources(DeettyGridContext *context);
static void connect_grid_area(DeettyGridContext *context);
static gchar *current_tab_title_alloc(DeettyGridContext *context);
static void update_compact_tab(DeettyGridContext *context);
static void open_grid_settings(DeettyGridContext *context);
static void open_theme_library(DeettyGridContext *context);
static void queue_theme_redraw(DeettyGridContext *context);
static void on_open_theme_library_clicked(GtkButton *button,
                                          gpointer user_data);
static void open_grid_shortcut_recorder(DeettyGridContext *context);
static gboolean open_grid_shortcut_recorder_live_smoke(gpointer user_data);
static void emit_grid_tray_tooltip(DeettyGridContext *context);
static void emit_grid_tray_menu_layout(DeettyGridContext *context);
static void set_widget_accessible_name(GtkWidget *widget, const char *name);
static void set_status_label_feedback(GtkWidget *label, const char *message,
                                      gboolean is_error);
static gboolean request_grid_application_close(
    DeettyGridContext *context, DeettyApplicationCloseOrigin origin);
static gboolean confirm_grid_application_close(DeettyGridContext *context);
static void begin_grid_modal(DeettyGridContext *context);
static void end_grid_modal(DeettyGridContext *context);
static gint run_grid_modal_dialog(DeettyGridContext *context,
                                  GtkDialog *dialog);
static gboolean configure_overlay_window_stacking(
    DeettyGridContext *context, GtkWidget *dialog,
    const char *namespace_name);
static void present_configured_window(GtkWidget *window) {
    if (!deetty_grid_widget_is_type(window, DEETTY_GTK_WINDOW) ||
        deetty_grid_object_get_data(window, "deetty-overlay-window") != NULL)
        return;
    deetty_grid_window_present(window);
}

static void update_window_resize_handles(DeettyGridContext *context);
static gboolean on_window_resize_handle_button(
    GtkWidget *widget, GdkEventButton *event, gpointer user_data);
static gboolean on_window_resize_handle_motion(
    GtkWidget *widget, GdkEventMotion *event, gpointer user_data);
static gboolean on_window_resize_handle_release(
    GtkWidget *widget, GdkEventButton *event, gpointer user_data);
static gboolean apply_pane_font_size(
    DeettyGridContext *context, double requested, gboolean notify);
static void queue_grid_cursor_cell(DeettyGridContext *context,
                                   uint32_t packed_cursor);
static void apply_panel_layout_metrics(DeettyGridContext *root);
static void resize_grid_to_allocation(DeettyGridContext *context,
                                      GtkAllocation *allocation);
static void emit_dogfood_event(DeettyGridContext *context,
                               const char *event_name,
                               uint64_t pane_id,
                               int value,
                               const char *detail);
static guint dogfood_active_omp_count(DeettyGridContext *context);
static void show_resize_overlay(DeettyGridContext *context,
                                int columns, int rows);
static void show_status_feedback(DeettyGridContext *context,
                                 const char *message);
static void schedule_grid_hot_session_flush(DeettyGridContext *context);
static void bind_preset_max_positions(DeettyGridContext *root,
                                      GtkWidget *widget);
static void schedule_even_pane_distribution(DeettyGridContext *context,
                                            GtkWidget *layout);
static gboolean on_scroll(GtkWidget *widget, GdkEventScroll *event,
                          gpointer user_data);
static gboolean on_key_press(GtkWidget *widget, GdkEventKey *event,
                             gpointer user_data);
static gboolean on_key_release(GtkWidget *widget, GdkEventKey *event,
                               gpointer user_data);
static void toggle_grid_window(DeettyGridContext *context);
static void set_grid_layer_keyboard_active(DeettyGridContext *context,
                                           gboolean active);
static gboolean adapt_window_to_resolution(gpointer user_data);
static void schedule_resolution_adapt(DeettyGridContext *context);
static void apply_fullscreen_dimensions(DeettyGridContext *context);
static gboolean normalize_dropdown_pixel_dimensions(
    DeettyGridContext *context, gboolean notify);
static void on_broadcast_menu_activate(GtkWidget *item, gpointer user_data);
#if DEETTY_ENABLE_SMOKE
static void record_presentation_draw_smoke(DeettyGridContext *context);
#endif
static gboolean show_quick_note_overlays(DeettyGridContext *context);
static void hide_quick_note_overlays(DeettyGridContext *context);
static gboolean adjust_active_tab_color(DeettyGridContext *context,
                                        int delta);
static gboolean on_tab_rename_key(GtkWidget *widget, GdkEventKey *event,
                                  gpointer user_data);
static gboolean on_mouse_button(GtkWidget *widget, GdkEventButton *event,
                                gpointer user_data);
static DeettyGridContext *focused_grid_context(DeettyGridContext *fallback);
static void activate_grid_context(DeettyGridContext *context);
static int deliver_grid_input(DeettyGridContext *source, const char *bytes,
                              size_t length);
static int deliver_grid_paste(DeettyGridContext *source, const char *bytes,
                              size_t length);
static void schedule_grid_write_flush(DeettyGridContext *context);
static void finish_tab_rename(DeettyGridContext *context,
                              gboolean restore_terminal_focus);
static void apply_preset_paned_positions(GtkWidget *widget,
                                         gint width, gint height);
static gboolean bind_grid_layout_for_page(DeettyGridContext *context);
static gboolean sync_grid_context_profile(DeettyGridContext *context);
static void restore_zoomed_page(DeettyGridContext *root);
static void destroy_retired_grid_context(DeettyGridContext *root,
                                         DeettyGridContext *context);
static void dismiss_workspace_menu(DeettyGridContext *context);
static void dismiss_grid_popup_windows(DeettyGridContext *context);
static void refresh_active_pane_info(DeettyGridContext *context);
static gboolean open_smoke_workspace_menu(DeettyGridContext *context);
static GtkWidget *grid_page_content_root(DeettyGridContext *context,
                                         GtkWidget *page);

static gboolean grid_context_session_available(
    const DeettyGridContext *context) {
    return context != NULL && context->active && !context->retiring &&
        context->userdata != NULL;
}

static gboolean grid_context_is_registered(
    const DeettyGridContext *root, const DeettyGridContext *candidate) {
    if (root == NULL || candidate == NULL || root->contexts == NULL)
        return FALSE;
    for (guint index = 0; index < root->contexts->len; index++) {
        if (g_ptr_array_index(root->contexts, index) == candidate)
            return TRUE;
    }
    return FALSE;
}

static DeettyGridFontMetrics grid_font_metrics(
    const DeettyGridContext *context) {
    DeettyGridFontMetrics metrics;
    deetty_grid_font_metrics(
        context != NULL ? context->font_size : 0, &metrics);
    return metrics;
}

typedef struct {
    GtkWidgetAccessible parent;
    gchar *text;
} DeettyTerminalAccessible;

typedef struct {
    GtkWidgetAccessibleClass parent_class;
} DeettyTerminalAccessibleClass;

static void deetty_terminal_accessible_text_iface_init(
    AtkTextIface *interface);

G_DEFINE_TYPE_WITH_CODE(
    DeettyTerminalAccessible, deetty_terminal_accessible,
    GTK_TYPE_WIDGET_ACCESSIBLE,
    G_IMPLEMENT_INTERFACE(
        ATK_TYPE_TEXT, deetty_terminal_accessible_text_iface_init))

static const gchar *deetty_terminal_accessible_contents(AtkText *text) {
    DeettyTerminalAccessible *accessible =
        (DeettyTerminalAccessible *)text;
    return accessible->text != NULL ? accessible->text : "";
}

static gchar *deetty_terminal_accessible_get_text(
    AtkText *text, gint start_offset, gint end_offset) {
    const gchar *contents = deetty_terminal_accessible_contents(text);
    gint count = (gint)g_utf8_strlen(contents, -1);
    DeettyGridAccessibleOffsetPlan offsets = {0};
    deetty_grid_accessible_offset_plan(
        count, start_offset, end_offset, &offsets);
    const gchar *start_pointer =
        g_utf8_offset_to_pointer(contents, offsets.start);
    const gchar *end_pointer =
        g_utf8_offset_to_pointer(contents, offsets.end);
    return g_strndup(start_pointer, (gsize)(end_pointer - start_pointer));
}

static gunichar deetty_terminal_accessible_get_character(
    AtkText *text, gint offset) {
    const gchar *contents = deetty_terminal_accessible_contents(text);
    gint count = (gint)g_utf8_strlen(contents, -1);
    DeettyGridAccessibleOffsetPlan offsets = {0};
    deetty_grid_accessible_offset_plan(count, offset, -1, &offsets);
    if (offsets.valid == 0) return 0;
    return g_utf8_get_char(
        g_utf8_offset_to_pointer(contents, offsets.start));
}

static gint deetty_terminal_accessible_get_character_count(AtkText *text) {
    return (gint)g_utf8_strlen(
        deetty_terminal_accessible_contents(text), -1);
}

static gint deetty_terminal_accessible_get_caret_offset(AtkText *text) {
    return deetty_terminal_accessible_get_character_count(text);
}

static gchar *deetty_terminal_accessible_get_string_at_offset(
    AtkText *text, gint offset, AtkTextGranularity granularity,
    gint *start_offset, gint *end_offset) {
    const gchar *contents = deetty_terminal_accessible_contents(text);
    int granularity_kind =
        deetty_grid_accessible_granularity((int)granularity);
    DeettyGridAccessibleRangePlan range = {0};
    deetty_grid_accessible_range_plan(
        (const uint8_t *)contents, strlen(contents),
        offset, granularity_kind, &range);
    if (range.valid == 0) {
        if (start_offset != NULL) *start_offset = 0;
        if (end_offset != NULL) *end_offset = 0;
        return g_strdup("");
    }

    const gchar *start = g_utf8_offset_to_pointer(contents, range.start);
    const gchar *end = g_utf8_offset_to_pointer(contents, range.end);
    if (start_offset != NULL) *start_offset = range.start;
    if (end_offset != NULL) *end_offset = range.end;
    return g_strndup(start, (gsize)(end - start));
}

static void deetty_terminal_accessible_finalize(GObject *object) {
    DeettyTerminalAccessible *accessible =
        (DeettyTerminalAccessible *)object;
    accessible->text = deetty_grid_memory_clear(accessible->text);
    G_OBJECT_CLASS(deetty_terminal_accessible_parent_class)->finalize(object);
}

static void deetty_terminal_accessible_initialize(
    AtkObject *object, gpointer data) {
    ATK_OBJECT_CLASS(deetty_terminal_accessible_parent_class)
        ->initialize(object, data);
    deetty_grid_atk_object_set_role(object, ATK_ROLE_TERMINAL);
}

static void deetty_terminal_accessible_class_init(
    DeettyTerminalAccessibleClass *class) {
    GObjectClass *object_class = G_OBJECT_CLASS(class);
    AtkObjectClass *atk_class = ATK_OBJECT_CLASS(class);
    object_class->finalize = deetty_terminal_accessible_finalize;
    atk_class->initialize = deetty_terminal_accessible_initialize;
}

static void deetty_terminal_accessible_init(
    DeettyTerminalAccessible *accessible) {
    accessible->text = g_strdup("");
}

static void deetty_terminal_accessible_text_iface_init(
    AtkTextIface *interface) {
    interface->get_text = deetty_terminal_accessible_get_text;
    interface->get_character_at_offset =
        deetty_terminal_accessible_get_character;
    interface->get_character_count =
        deetty_terminal_accessible_get_character_count;
    interface->get_caret_offset =
        deetty_terminal_accessible_get_caret_offset;
    interface->get_string_at_offset =
        deetty_terminal_accessible_get_string_at_offset;
}

typedef struct {
    GtkDrawingArea parent;
} DeettyTerminalArea;

typedef struct {
    GtkDrawingAreaClass parent_class;
} DeettyTerminalAreaClass;

G_DEFINE_TYPE(
    DeettyTerminalArea, deetty_terminal_area, GTK_TYPE_DRAWING_AREA)

typedef struct {
    GtkGLArea parent;
} DeettyTerminalGLArea;

typedef struct {
    GtkGLAreaClass parent_class;
} DeettyTerminalGLAreaClass;

G_DEFINE_TYPE(
    DeettyTerminalGLArea, deetty_terminal_gl_area, GTK_TYPE_GL_AREA)

static void deetty_terminal_area_class_init(
    DeettyTerminalAreaClass *class) {
    deetty_grid_widget_class_set_accessible_type(
        class, deetty_terminal_accessible_get_type());
}

static void deetty_terminal_area_init(DeettyTerminalArea *area) {
    (void)area;
}

static void deetty_terminal_gl_area_class_init(
    DeettyTerminalGLAreaClass *class) {
    deetty_grid_widget_class_set_accessible_type(
        class, deetty_terminal_accessible_get_type());
}

static void deetty_terminal_gl_area_init(DeettyTerminalGLArea *area) {
    (void)area;
}

static GtkWidget *deetty_terminal_area_new(int renderer_backend) {
    if (renderer_backend != 0) {
        GtkWidget *area = GTK_WIDGET(
            g_object_new(deetty_terminal_gl_area_get_type(), NULL));
        gtk_gl_area_set_has_alpha(GTK_GL_AREA(area), TRUE);
        gtk_gl_area_set_auto_render(GTK_GL_AREA(area), TRUE);
        gtk_gl_area_set_required_version(GTK_GL_AREA(area), 3, 2);
        return area;
    }
    GtkWidget *area = GTK_WIDGET(
        g_object_new(deetty_terminal_area_get_type(), NULL));
    deetty_grid_widget_set_app_paintable(area, TRUE);
    return area;
}

static void refresh_terminal_accessible_text(DeettyGridContext *context) {
    if (context == NULL || context->area == NULL ||
        context->cell_text == NULL ||
        !grid_context_session_available(context))
        return;
    AtkObject *object = deetty_grid_widget_get_accessible(context->area);
    if (!ATK_IS_TEXT(object) ||
        !G_TYPE_CHECK_INSTANCE_TYPE(
            object, deetty_terminal_accessible_get_type()))
        return;

    DeettyGridAccessibleTextPlan text_plan = {0};
    deetty_grid_accessible_text_capacity(
        context->columns, context->rows, &text_plan);
    GString *next = g_string_sized_new((gsize)text_plan.initial_capacity);
    for (int row = 0; row < context->rows; row++) {
        gsize row_start = next->len;
        for (int column = 0; column < context->columns; column++) {
            char cell[64] = {0};
            int length = context->cell_text(
                context->userdata, column, row, cell, sizeof(cell));
            int accepted_length = deetty_grid_accessible_cell_length(
                length, (int)sizeof(cell));
            if (accepted_length > 0)
                g_string_append_len(next, cell, accepted_length);
        }
        gsize row_length = next->len - row_start;
        gsize trimmed_length = deetty_grid_accessible_trim_row_length(
            (const uint8_t *)next->str + row_start, row_length);
        if (trimmed_length < row_length)
            g_string_truncate(next, row_start + trimmed_length);
        if (row + 1 < context->rows) g_string_append_c(next, '\n');
    }
    gsize trimmed_length = deetty_grid_accessible_trim_newline_length(
        (const uint8_t *)next->str, next->len);
    if (trimmed_length < next->len)
        g_string_truncate(next, trimmed_length);

    DeettyTerminalAccessible *accessible =
        (DeettyTerminalAccessible *)object;
    if (g_strcmp0(accessible->text, next->str) != 0) {
        gint old_count = accessible->text != NULL
            ? (gint)g_utf8_strlen(accessible->text, -1) : 0;
        gint new_count = (gint)g_utf8_strlen(next->str, -1);
        if (old_count > 0)
            g_signal_emit_by_name(
                accessible, "text-changed::delete", 0, old_count);
        deetty_grid_memory_free(accessible->text);
        accessible->text = g_string_free(next, FALSE);
        if (new_count > 0)
            g_signal_emit_by_name(
                accessible, "text-changed::insert", 0, new_count);
    } else {
        g_string_free(next, TRUE);
    }
#if DEETTY_ENABLE_SMOKE
    if (deetty_terminal_accessible_get_character_count(
            ATK_TEXT(accessible)) > 0)
        root_grid_context(context)->compact_terminal_accessible_text = 1;
#endif
}

static gboolean terminal_scrollbar_geometry(
    DeettyGridContext *context, GtkAllocation allocation,
    DeettyTerminalScrollbarGeometry *geometry) {
    DeettyGridNativeHostPolicy policy = {0};
    deetty_grid_native_host_policy(&policy);
    if (!grid_context_session_available(context) || context->scroll == NULL ||
        geometry == NULL ||
        allocation.width <= policy.terminal_scrollbar_width_px ||
        allocation.height <= 4)
        return FALSE;
    uint64_t history_lines = 0;
    uint64_t viewport_offset = 0;
    uint32_t visible_rows = 0;
    if (deetty_grid_scroll_state(
            context->userdata, &history_lines, &viewport_offset,
            &visible_rows) != 0)
        return FALSE;
    return deetty_grid_scrollbar_geometry(
        allocation.width, allocation.height,
        policy.terminal_scrollbar_width_px,
        policy.terminal_scrollbar_min_thumb_px, history_lines,
        viewport_offset, visible_rows, geometry) != 0;
}

static gboolean scroll_terminal_by_lines(
    DeettyGridContext *context, int lines) {
    if (lines == 0) return TRUE;
    int result = context->scroll(context->userdata, lines);
    if (result != 0) {
        show_status_feedback(
            context,
            deetty_grid_status_feedback_message(
                DEETTY_GRID_FEEDBACK_SCROLL_HISTORY));
        return FALSE;
    }
    return TRUE;
}

static gboolean scroll_terminal_to_offset(
    DeettyGridContext *context, uint64_t target_offset) {
    GtkAllocation allocation;
    deetty_grid_widget_get_allocation(context->area, &allocation);
    DeettyTerminalScrollbarGeometry geometry;
    if (!terminal_scrollbar_geometry(context, allocation, &geometry))
        return FALSE;

    int lines = deetty_grid_scroll_target_delta(
        geometry.history_lines, geometry.viewport_offset, target_offset);
    if (lines == 0) return FALSE;
    if (!scroll_terminal_by_lines(context, lines)) return FALSE;
    deetty_grid_widget_queue_draw(context->area);
    return TRUE;
}
static gboolean scroll_terminal_from_keyboard(
    DeettyGridContext *context, guint keyval) {
    GtkAllocation allocation;
    deetty_grid_widget_get_allocation(context->area, &allocation);
    DeettyTerminalScrollbarGeometry geometry;
    if (!terminal_scrollbar_geometry(context, allocation, &geometry))
        return TRUE;

    int action = deetty_grid_keyboard_scroll_action(keyval);
    uint64_t target = deetty_grid_keyboard_scroll_target(
        geometry.history_lines, geometry.viewport_offset,
        geometry.visible_rows, action);
    (void)scroll_terminal_to_offset(context, target);
    return TRUE;
}

static int grid_cell_is_selected(const DeettyGridContext *context,
                                      int column, int row) {
    return deetty_grid_cell_selected(
        context->selecting, context->selection_start_column,
        context->selection_start_row, context->selection_end_column,
        context->selection_end_row, column, row) != 0;
}

static void draw_terminal_text_pango(DeettyGridContext *context, cairo_t *cr,
                                     const char *text, int length,
                                     double x, double baseline,
                                     uint32_t style) {
    if (text == NULL || length <= 0) return;
    DeettyGridFontMetrics metrics = grid_font_metrics(context);
    const DeettyGridTerminalFont font = {
        .descriptions = context->terminal_font_descriptions,
        .family = context->font_family,
        .size_px = metrics.font_px,
    };
    (void)deetty_grid_render_terminal_text(
        cr, &font, text, length, x, baseline, style);
}

static void draw_codepoint(DeettyGridContext *context, cairo_t *cr,
                           uint32_t codepoint, double x, double y,
                           uint32_t style) {
    char text[4] = {0};
    int length = deetty_grid_codepoint_utf8(
        codepoint, (uint8_t *)text, sizeof(text));
    if (length > 0)
        draw_terminal_text_pango(context, cr, text, length, x, y, style);
}

static void draw_grid_cell_text(DeettyGridContext *context, cairo_t *cr,
                                int column, int row, double x, double y,
                                uint32_t style) {
    char text[129];
    int length = context->cell_text(context->userdata, column, row,
                                    text, sizeof(text) - 1);
    if (length <= 0) return;
    length = MIN(length, (int)sizeof(text) - 1);
    text[length] = '\0';
    draw_terminal_text_pango(context, cr, text, length, x, y, style);
    root_grid_context(context)->grapheme_cells_drawn++;
}

static void clear_ascii_glyph_cache(DeettyGridContext *context) {
    for (int face = 0; face < 4; face++) {
        g_clear_pointer(&context->terminal_font_descriptions[face],
                        pango_font_description_free);
        if (context->ascii_scaled_fonts[face] != NULL)
            cairo_scaled_font_destroy(context->ascii_scaled_fonts[face]);
        context->ascii_scaled_fonts[face] = NULL;
        context->ascii_glyph_cache_valid[face] = 0;
    }
}

static void destroy_grid_glyph_cache(DeettyGridContext *context) {
    clear_ascii_glyph_cache(context);
    context->glyph_scratch = deetty_grid_memory_clear(context->glyph_scratch);
    context->glyph_scratch_capacity = 0;
}

static void draw_codepoint_bridge(
    void *userdata, cairo_t *cr, uint32_t codepoint,
    double x, double y, uint32_t style) {
    draw_codepoint(userdata, cr, codepoint, x, y, style);
}

static uint32_t ui_color_rgb(DeettyGridContext *context, uint32_t color,
                             uint32_t fallback) {
    uint32_t rgb = context->ui_color_rgb != NULL
        ? context->ui_color_rgb(context->event_data, color) : UINT32_MAX;
    return rgb == UINT32_MAX ? fallback : rgb;
}

static void format_ui_color(DeettyGridContext *context, uint32_t color,
                            uint32_t fallback, char output[8]) {
    uint32_t rgb = ui_color_rgb(context, color, fallback);
    if (deetty_grid_theme_color_text(
            deetty_grid_theme_color_channel(rgb, 0),
            deetty_grid_theme_color_channel(rgb, 1),
            deetty_grid_theme_color_channel(rgb, 2),
            (unsigned char *)output, 8) == 0)
        output[0] = '\0';
}

static void draw_resize_overlay(DeettyGridContext *context, cairo_t *cr,
                                GtkAllocation allocation) {
    if (!context->resize_overlay_visible) return;
    const DeettyGridResizeOverlay options = {
        .palette = { context->event_data, context->ui_color_rgb },
        .font_family = context->font_family,
        .allocation_width = allocation.width,
        .allocation_height = allocation.height,
        .columns = context->resize_overlay_columns,
        .rows = context->resize_overlay_rows,
        .floor_reached = context->resize_overlay_floor_reached,
        .zoom_percent = context->resize_overlay_zoom_percent,
        .border_width = context->overlay_border_px,
        .high_contrast = context->high_contrast,
    };
    if (deetty_grid_render_resize_overlay(cr, &options))
        context->resize_overlay_drawn = 1;
}

static void draw_quick_note_overlay(DeettyGridContext *context, cairo_t *cr,
                                    GtkAllocation allocation) {
    DeettyGridContext *root = root_grid_context(context);
    if (!root->note_overlay_visible || root->note_overlay_label == NULL)
        return;
    const DeettyGridTextOverlay options = {
        .palette = { context->event_data, context->ui_color_rgb },
        .text = root->note_overlay_label,
        .font_cache = &root->note_overlay_font,
        .allocation_width = allocation.width,
        .allocation_height = allocation.height,
        .border_width = context->overlay_border_px,
        .high_contrast = context->high_contrast,
    };
    int compact = 0;
    if (deetty_grid_render_quick_note(cr, &options, &compact)) {
        context->note_overlay_drawn = 1;
        context->note_overlay_compact = compact;
    }
}

static gboolean clear_status_feedback(gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    root->status_feedback_source = 0;
    root->status_feedback_text = deetty_grid_memory_clear(root->status_feedback_text);
    DeettyGridContext *focused = focused_grid_context(root);
    if (focused != NULL && focused->area != NULL)
        deetty_grid_widget_queue_draw(focused->area);
    return G_SOURCE_REMOVE;
}

static void show_status_feedback(DeettyGridContext *context,
                                 const char *message) {
    DeettyGridContext *root = root_grid_context(context);
    DeettyGridLifecycleTimingPlan timing = {0};
    deetty_grid_lifecycle_timing_plan(&timing);
    root->status_feedback_text = deetty_grid_memory_clear(root->status_feedback_text);
    if (root->status_feedback_source != 0) {
        deetty_grid_source_remove(root->status_feedback_source);
        root->status_feedback_source = 0;
    }
    root->status_feedback_text = g_strdup(message);
    root->status_feedback_source = deetty_grid_source_timeout_add(
        (guint)timing.status_feedback_ms, clear_status_feedback, root);
    if (context->area != NULL) deetty_grid_widget_queue_draw(context->area);
}

static void draw_status_feedback(DeettyGridContext *context, cairo_t *cr,
                                 GtkAllocation allocation) {
    DeettyGridContext *root = root_grid_context(context);
    if (root->status_feedback_text == NULL ||
        focused_grid_context(root) != context)
        return;
    const DeettyGridTextOverlay options = {
        .palette = { context->event_data, context->ui_color_rgb },
        .text = root->status_feedback_text,
        .font_cache = NULL,
        .allocation_width = allocation.width,
        .allocation_height = allocation.height,
        .border_width = context->overlay_border_px,
        .high_contrast = context->high_contrast,
    };
    if (deetty_grid_render_status_feedback(cr, &options))
        root->status_feedback_drawn = 1;
}

static void draw_cycle_feedback(DeettyGridContext *context, cairo_t *cr,
                                GtkAllocation allocation, const char *label,
                                double red, double green, double blue) {
    const uint32_t accent =
        ((uint32_t)(red * 255.0) << 16) |
        ((uint32_t)(green * 255.0) << 8) |
        (uint32_t)(blue * 255.0);
    const DeettyGridCycleOverlay options = {
        .palette = { context->event_data, context->ui_color_rgb },
        .label = label,
        .allocation_width = allocation.width,
        .allocation_height = allocation.height,
        .pane_border_width = context->pane_border_focused_px,
        .overlay_border_width = context->overlay_border_px,
        .accent_rgb = accent,
    };
    (void)deetty_grid_render_cycle_overlay(cr, &options);
}

static void draw_pane_cycle_feedback(DeettyGridContext *context, cairo_t *cr,
                                     GtkAllocation allocation) {
    if (!context->pane_cycle_feedback_visible ||
        context->pane_cycle_feedback_count <= 0) return;

    char label[64];
    if (deetty_grid_cycle_feedback_text(
            0, context->pane_cycle_feedback_index,
            context->pane_cycle_feedback_count,
            (unsigned char *)label, sizeof(label)) <= 0)
        return;
    draw_cycle_feedback(context, cr, allocation, label, 0.28, 0.68, 1.0);

    root_grid_context(context)->pane_cycle_feedback_drawn = 1;
}

static void draw_tab_cycle_feedback(DeettyGridContext *context, cairo_t *cr,
                                    GtkAllocation allocation) {
    if (!context->tab_cycle_feedback_visible ||
        context->tab_cycle_feedback_count <= 0) return;

    char label[64];
    if (deetty_grid_cycle_feedback_text(
            1, context->tab_cycle_feedback_index,
            context->tab_cycle_feedback_count,
            (unsigned char *)label, sizeof(label)) <= 0)
        return;
    draw_cycle_feedback(context, cr, allocation, label, 0.74, 0.48, 1.0);

    root_grid_context(context)->tab_cycle_feedback_drawn = 1;
}

static void draw_terminal_scrollbar(
    DeettyGridContext *context, cairo_t *cr, GtkAllocation allocation) {
    DeettyTerminalScrollbarGeometry geometry;
    if (!terminal_scrollbar_geometry(context, allocation, &geometry)) return;
    const DeettyGridRenderScrollbar options = {
        .palette = { context->event_data, context->ui_color_rgb },
        .allocation_height = allocation.height,
        .x = geometry.x,
        .width = geometry.width,
        .thumb_y = geometry.thumb_y,
        .thumb_height = geometry.thumb_height,
        .dragging = context->scrollbar_dragging,
        .hovered = context->scrollbar_hovered,
    };
    if (deetty_grid_render_scrollbar(cr, &options))
        root_grid_context(context)->compact_scrollbar_drawn = 1;
}

static uint32_t scale_pane_brightness(DeettyGridContext *context,
                                      uint32_t rgb) {
    DeettyGridContext *root = root_grid_context(context);
    gboolean active = deetty_grid_pane_is_active(
        root->active_pane_id_for_render, context->pane_id, context->focused);
    return deetty_grid_scale_brightness(
        rgb, context->inactive_pane_dim_enabled, active,
        context->inactive_pane_brightness_percent);
}

static uint32_t resolve_pane_terminal_color(void *userdata,
                                            uint32_t color_id) {
    DeettyGridContext *context = userdata;
    uint32_t rgb = context->event_data != NULL
        ? deetty_grid_pane_terminal_color_rgb(
              context->event_data, context->pane_id, color_id)
        : UINT32_MAX;
    if (rgb == UINT32_MAX && context->color_rgb != NULL)
        rgb = context->color_rgb(context->userdata, color_id);
    return rgb == UINT32_MAX ? rgb : scale_pane_brightness(context, rgb);
}

static int grid_cell_selected_bridge(void *userdata, int column, int row) {
    const DeettyGridContext *context = userdata;
    return deetty_grid_cell_selected(
        context->selecting, context->selection_start_column,
        context->selection_start_row, context->selection_end_column,
        context->selection_end_row, column, row) != 0;
}

static void draw_grid_cell_text_bridge(
    void *userdata, cairo_t *cr, int column, int row,
    double x, double y, uint32_t style) {
    draw_grid_cell_text(userdata, cr, column, row, x, y, style);
}

static gboolean draw_grid_contents(DeettyGridContext *context, cairo_t *cr,
                                   GtkAllocation allocation) {
    double background_alpha = deetty_grid_background_alpha(
        context->background_translucency,
        context->background_alpha_supported,
        context->background_opacity_percent);
    cairo_save(cr);
    cairo_set_operator(cr, CAIRO_OPERATOR_SOURCE);
    uint32_t background_rgb = 0;
    if (context->event_data != NULL) {
        background_rgb = deetty_grid_pane_background_rgb(
            context->event_data, context->pane_id);
    } else {
        DeettyGridNativeHostPolicy policy = {0};
        deetty_grid_native_host_policy(&policy);
        background_rgb = ui_color_rgb(
            context, (uint32_t)policy.ui_color_workspace_background,
            policy.default_workspace_background_rgb);
    }
    background_rgb = scale_pane_brightness(context, background_rgb);
    cairo_set_source_rgba(
        cr,
        ((background_rgb >> 16) & 0xffu) / 255.0,
        ((background_rgb >> 8) & 0xffu) / 255.0,
        (background_rgb & 0xffu) / 255.0,
        background_alpha);
    cairo_paint(cr);
    cairo_restore(cr);
    if (!grid_context_session_available(context)) return FALSE;

    context->saw_draw = 1;
    DeettyGridContext *root = root_grid_context(context);
    gboolean pane_selected = context->event_data != NULL &&
        deetty_grid_pane_selected(context->event_data, context->pane_id) != 0;
    DeettyGridFontMetrics metrics = grid_font_metrics(context);
    double cell_width = metrics.cell_width;
    double cell_height = metrics.cell_height;
    uint32_t cursor = context->cursor(context->userdata);
    DeettyGridCursorPosition cursor_position = {0};
    deetty_grid_cursor_position(cursor, &cursor_position);
    int cursor_column = cursor_position.column;
    int cursor_row = cursor_position.row;
    DeettyTerminalScrollbarGeometry cursor_scrollbar;
    gboolean cursor_at_live_bottom =
        !terminal_scrollbar_geometry(context, allocation, &cursor_scrollbar) ||
        cursor_scrollbar.viewport_offset == 0;
    DeettyGridRenderChrome chrome;
    deetty_grid_render_chrome(
        context->status_kind, context->focused, pane_selected,
        context->pane_border_px, context->pane_border_focused_px,
        context->pane_border_selected_px, context->cursor_visible,
        cursor_at_live_bottom, cursor_column, cursor_row,
        context->columns, context->rows, cell_width, cell_height, &chrome);
    if (pane_selected && context->contexts != NULL &&
        context->contexts->len > 0)
        root->selection_border_drawn = 1;

    uint32_t cursor_rgb = 0;
    if (context->event_data != NULL) {
        cursor_rgb = deetty_grid_pane_cursor_rgb(
            context->event_data, context->pane_id);
    } else {
        DeettyGridNativeHostPolicy policy = {0};
        deetty_grid_native_host_policy(&policy);
        cursor_rgb = policy.default_terminal_cursor_rgb;
    }
    const DeettyGridCells options = {
        .ui_palette = { context->event_data, context->ui_color_rgb },
        .terminal_palette = { context, resolve_pane_terminal_color },
        .glyph_cache = {
            .scratch = &context->glyph_scratch,
            .capacity = &context->glyph_scratch_capacity,
            .scaled_fonts = context->ascii_scaled_fonts,
            .indices = context->ascii_glyph_indices,
            .valid = context->ascii_glyph_cache_valid,
            .scratch_allocations = &context->glyph_scratch_allocations,
            .cache_builds = &context->glyph_cache_builds,
            .cache_hits = &context->glyph_cache_hits,
            .fallback_conversions = &context->glyph_fallback_conversions,
        },
        .frame_cells = &context->frame_cells,
        .frame_capacity = &context->frame_cell_capacity,
        .frame_allocations = &context->frame_buffer_allocations,
        .frame_batches = &root->frame_batches_drawn,
        .glyph_batches = &root->glyph_batches_drawn,
        .glyph_cells = &root->glyph_cells_batched,
        .rich_style_cells = &root->rich_style_cells_drawn,
        .source_context = context->userdata,
        .frame = context->frame,
        .selection_context = context,
        .selected = grid_cell_selected_bridge,
        .draw_context = context,
        .draw_codepoint = draw_codepoint_bridge,
        .draw_cell_text = draw_grid_cell_text_bridge,
        .font_family = context->font_family,
        .font_px = metrics.font_px,
        .antialias = root->font_antialias,
        .hinting = root->font_hinting,
        .allocation_width = allocation.width,
        .allocation_height = allocation.height,
        .columns = context->columns,
        .rows = context->rows,
        .cell_width = cell_width,
        .cell_height = cell_height,
        .status_border_width = context->status_border_px,
        .cursor_rgb = scale_pane_brightness(context, cursor_rgb),
        .chrome = chrome,
    };
    int render_result = deetty_grid_render_cells(cr, &options);
    if (root->workspace_smoke == 15) {
        if ((render_result & 2) != 0)
            root->compact_hyperlink_underline_positioned = 1;
        if ((render_result & 4) != 0)
            root->compact_terminal_caret_drawn = 1;
    }

    draw_terminal_scrollbar(context, cr, allocation);
    draw_resize_overlay(context, cr, allocation);
    draw_quick_note_overlay(context, cr, allocation);
    draw_status_feedback(context, cr, allocation);
    draw_pane_cycle_feedback(context, cr, allocation);
    draw_tab_cycle_feedback(context, cr, allocation);
    if (context->workspace_smoke == 33 && context->profile_preset == 3 &&
        context->high_contrast)
        root->profile_rendered = 1;
    return FALSE;
}

static gboolean on_draw(GtkWidget *widget, cairo_t *cr, gpointer user_data) {
    DeettyGridContext *context = user_data;
    GtkAllocation allocation;
    deetty_grid_widget_get_allocation(widget, &allocation);
    gboolean result = draw_grid_contents(context, cr, allocation);
    refresh_terminal_accessible_text(context);
#if DEETTY_ENABLE_SMOKE
#include "../../tests/native_grid_smoke_draw_counters.inc"
#endif
    return result;
}
static gboolean request_gpu_fallback(DeettyGridContext *context) {
    if (context == NULL || context->gpu_fallback_pending) return FALSE;
    context->gpu_fallback_pending = 1;
    DeettyGridContext *root = root_grid_context(context);
    root->gpu_fallbacks++;
    if (g_getenv("DEETTY_BENCH_RENDERER") != NULL)
        g_printerr(
            "native_grid_renderer_fallback renderer_requested=%s gpu_fallbacks=%u\n",
            root->renderer_backend_requested != 0 ? "opengl" : "cairo",
            root->gpu_fallbacks);
    context->gpu_fallback_source =
        g_idle_add(fallback_grid_renderer_idle, context);
    return TRUE;
}

static void destroy_gpu_resources(DeettyGridContext *context) {
    if (context == NULL) return;
    if (context->gpu_fallback_source != 0) {
        g_source_remove(context->gpu_fallback_source);
        context->gpu_fallback_source = 0;
        context->gpu_fallback_pending = 0;
    }
    if (context->area != NULL &&
        GTK_IS_GL_AREA(context->area) &&
        gtk_widget_get_realized(context->area)) {
        gtk_gl_area_make_current(GTK_GL_AREA(context->area));
        if (context->gpu_vbo != 0) {
            glDeleteBuffers(1, &context->gpu_vbo);
            context->gpu_vbo = 0;
        }
        if (context->gpu_vao != 0) {
            glDeleteVertexArrays(1, &context->gpu_vao);
            context->gpu_vao = 0;
        }
        if (context->gpu_texture != 0) {
            glDeleteTextures(1, &context->gpu_texture);
            context->gpu_texture = 0;
        }
        if (context->gpu_program != 0) {
            glDeleteProgram(context->gpu_program);
            context->gpu_program = 0;
        }
    } else {
        context->gpu_vbo = 0;
        context->gpu_vao = 0;
        context->gpu_texture = 0;
        context->gpu_program = 0;
    }
    if (context->gpu_surface != NULL) {
        cairo_surface_destroy(context->gpu_surface);
        context->gpu_surface = NULL;
    }
    context->gpu_surface_width = 0;
    context->gpu_surface_height = 0;
    context->gpu_surface_scale = 0;
    context->gpu_sampler = -1;
}

static gboolean compile_gpu_shader(
    GLenum type, const char *source, GLuint *shader_out) {
    GLuint shader = glCreateShader(type);
    if (shader == 0) return FALSE;
    const GLchar *sources[] = { source };
    glShaderSource(shader, 1, sources, NULL);
    glCompileShader(shader);
    GLint compiled = GL_FALSE;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &compiled);
    if (compiled == GL_FALSE) {
        char log[1024] = {0};
        GLsizei length = 0;
        glGetShaderInfoLog(
            shader, (GLsizei)(sizeof(log) - 1), &length, log);
        log[length < (GLsizei)(sizeof(log) - 1) ? length :
            (GLsizei)(sizeof(log) - 1)] = '\0';
        g_printerr("native_grid_gpu_shader_failed %s\n", log);
        glDeleteShader(shader);
        return FALSE;
    }
    *shader_out = shader;
    return TRUE;
}

static gboolean initialize_gpu_resources(
    DeettyGridContext *context, GtkGLArea *area) {
    gtk_gl_area_make_current(area);
    GError *error = gtk_gl_area_get_error(area);
    if (error != NULL) {
        g_printerr("native_grid_gpu_context_failed %s\n", error->message);
        return FALSE;
    }
    const GLubyte *version = glGetString(GL_VERSION);
    if (version == NULL) return FALSE;
    if (!context->gpu_context_reported) {
        const GLubyte *vendor = glGetString(GL_VENDOR);
        const GLubyte *renderer = glGetString(GL_RENDERER);
        g_print(
            "native_grid_gpu_context vendor=%s renderer=%s version=%s\n",
            vendor != NULL ? (const char *)vendor : "unknown",
            renderer != NULL ? (const char *)renderer : "unknown",
            (const char *)version);
        fflush(stdout);
        context->gpu_context_reported = 1;
    }
    if (context->gpu_program != 0) return TRUE;

    static const char vertex_source[] =
        "#version 150\n"
        "in vec2 a_position;\n"
        "in vec2 a_texcoord;\n"
        "out vec2 v_texcoord;\n"
        "void main() {\n"
        "  gl_Position = vec4(a_position, 0.0, 1.0);\n"
        "  v_texcoord = a_texcoord;\n"
        "}\n";
    static const char fragment_source[] =
        "#version 150\n"
        "uniform sampler2D u_texture;\n"
        "in vec2 v_texcoord;\n"
        "out vec4 out_color;\n"
        "void main() { out_color = texture(u_texture, v_texcoord); }\n";
    GLuint vertex_shader = 0;
    GLuint fragment_shader = 0;
    if (!compile_gpu_shader(
            GL_VERTEX_SHADER, vertex_source, &vertex_shader) ||
        !compile_gpu_shader(
            GL_FRAGMENT_SHADER, fragment_source, &fragment_shader)) {
        if (vertex_shader != 0) glDeleteShader(vertex_shader);
        if (fragment_shader != 0) glDeleteShader(fragment_shader);
        return FALSE;
    }
    context->gpu_program = glCreateProgram();
    if (context->gpu_program == 0) {
        glDeleteShader(vertex_shader);
        glDeleteShader(fragment_shader);
        return FALSE;
    }
    glAttachShader(context->gpu_program, vertex_shader);
    glAttachShader(context->gpu_program, fragment_shader);
    glBindAttribLocation(context->gpu_program, 0, "a_position");
    glBindAttribLocation(context->gpu_program, 1, "a_texcoord");
    glLinkProgram(context->gpu_program);
    glDeleteShader(vertex_shader);
    glDeleteShader(fragment_shader);
    GLint linked = GL_FALSE;
    glGetProgramiv(context->gpu_program, GL_LINK_STATUS, &linked);
    if (linked == GL_FALSE) {
        char log[1024] = {0};
        GLsizei length = 0;
        glGetProgramInfoLog(
            context->gpu_program, (GLsizei)(sizeof(log) - 1), &length, log);
        log[length < (GLsizei)(sizeof(log) - 1) ? length :
            (GLsizei)(sizeof(log) - 1)] = '\0';
        g_printerr("native_grid_gpu_program_failed %s\n", log);
        glDeleteProgram(context->gpu_program);
        context->gpu_program = 0;
        return FALSE;
    }
    context->gpu_sampler =
        glGetUniformLocation(context->gpu_program, "u_texture");
    if (context->gpu_sampler < 0) return FALSE;

    static const GLfloat vertices[] = {
        -1.0f, -1.0f, 0.0f, 1.0f,
         1.0f, -1.0f, 1.0f, 1.0f,
        -1.0f,  1.0f, 0.0f, 0.0f,
         1.0f,  1.0f, 1.0f, 0.0f,
    };
    glGenVertexArrays(1, &context->gpu_vao);
    glGenBuffers(1, &context->gpu_vbo);
    glBindVertexArray(context->gpu_vao);
    glBindBuffer(GL_ARRAY_BUFFER, context->gpu_vbo);
    glBufferData(
        GL_ARRAY_BUFFER, (GLsizeiptr)sizeof(vertices), vertices,
        GL_STATIC_DRAW);
    glVertexAttribPointer(
        0, 2, GL_FLOAT, GL_FALSE, (GLsizei)(4 * sizeof(GLfloat)),
        (const void *)0);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(
        1, 2, GL_FLOAT, GL_FALSE, (GLsizei)(4 * sizeof(GLfloat)),
        (const void *)(2 * sizeof(GLfloat)));
    glEnableVertexAttribArray(1);
    glBindVertexArray(0);
    glBindBuffer(GL_ARRAY_BUFFER, 0);

    glGenTextures(1, &context->gpu_texture);
    glBindTexture(GL_TEXTURE_2D, context->gpu_texture);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glBindTexture(GL_TEXTURE_2D, 0);
    if (glGetError() != GL_NO_ERROR) {
        destroy_gpu_resources(context);
        return FALSE;
    }
    return TRUE;
}

static gboolean ensure_gpu_surface(
    DeettyGridContext *context, int width, int height, int scale) {
    if (width <= 0 || height <= 0 || scale <= 0) return FALSE;
    if (context->gpu_surface != NULL &&
        context->gpu_surface_width == width &&
        context->gpu_surface_height == height &&
        context->gpu_surface_scale == scale)
        return TRUE;
    if (context->gpu_surface != NULL) {
        cairo_surface_destroy(context->gpu_surface);
        context->gpu_surface = NULL;
    }
    context->gpu_surface = cairo_image_surface_create(
        CAIRO_FORMAT_ARGB32, width, height);
    if (cairo_surface_status(context->gpu_surface) != CAIRO_STATUS_SUCCESS) {
        cairo_surface_destroy(context->gpu_surface);
        context->gpu_surface = NULL;
        return FALSE;
    }
    cairo_surface_set_device_scale(
        context->gpu_surface, (double)scale, (double)scale);
    context->gpu_surface_width = width;
    context->gpu_surface_height = height;
    context->gpu_surface_scale = scale;
    return TRUE;
}

static gboolean on_gpu_render(
    GtkGLArea *area, GdkGLContext *gl_context, gpointer user_data) {
    (void)gl_context;
    DeettyGridContext *context = user_data;
    if (context == NULL || context->renderer_backend == 0) return TRUE;
    if (gtk_gl_area_get_error(area) != NULL ||
        !initialize_gpu_resources(context, area)) {
        request_gpu_fallback(context);
        return TRUE;
    }
    GtkAllocation allocation;
    deetty_grid_widget_get_allocation(GTK_WIDGET(area), &allocation);
    int scale = gtk_widget_get_scale_factor(GTK_WIDGET(area));
    int width = allocation.width * scale;
    int height = allocation.height * scale;
    if (!ensure_gpu_surface(context, width, height, scale)) {
        request_gpu_fallback(context);
        return TRUE;
    }
    cairo_t *cr = cairo_create(context->gpu_surface);
    if (cairo_status(cr) != CAIRO_STATUS_SUCCESS) {
        cairo_destroy(cr);
        request_gpu_fallback(context);
        return TRUE;
    }
    (void)draw_grid_contents(context, cr, allocation);
    cairo_destroy(cr);
    if (cairo_surface_status(context->gpu_surface) != CAIRO_STATUS_SUCCESS) {
        request_gpu_fallback(context);
        return TRUE;
    }
    refresh_terminal_accessible_text(context);
    cairo_surface_flush(context->gpu_surface);
    gtk_gl_area_make_current(area);
    glViewport(0, 0, width, height);
    glDisable(GL_SCISSOR_TEST);
    glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    glEnable(GL_BLEND);
    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    glUseProgram(context->gpu_program);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, context->gpu_texture);
    glPixelStorei(GL_UNPACK_ALIGNMENT, 4);
    glTexImage2D(
        GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_BGRA,
        GL_UNSIGNED_BYTE, cairo_image_surface_get_data(context->gpu_surface));
    glUniform1i(context->gpu_sampler, 0);
    glBindVertexArray(context->gpu_vao);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    glBindVertexArray(0);
    glBindTexture(GL_TEXTURE_2D, 0);
    GLenum error = glGetError();
    if (error != GL_NO_ERROR) {
        request_gpu_fallback(context);
        return TRUE;
    }
    DeettyGridContext *root = root_grid_context(context);
    root->gpu_render_frames++;
    root->gpu_texture_uploads++;
    if (root->gpu_render_frames == 1 && !root->gpu_receipt_reported) {
        g_print(
            "native_grid_renderer_receipt renderer_requested=%s renderer_effective=%s gpu_render_frames=%u gpu_texture_uploads=%u gpu_fallbacks=%u\n",
            root->renderer_backend_requested != 0 ? "opengl" : "cairo",
            root->renderer_backend != 0 ? "opengl" : "cairo",
            root->gpu_render_frames, root->gpu_texture_uploads,
            root->gpu_fallbacks);
        fflush(stdout);
        root->gpu_receipt_reported = 1;
    }
    return TRUE;
}

static gboolean fallback_grid_renderer_idle(gpointer user_data) {
    DeettyGridContext *context = user_data;
    if (context == NULL) return G_SOURCE_REMOVE;
    context->gpu_fallback_source = 0;
    context->gpu_fallback_pending = 0;
    if (context->renderer_backend == 0 || context->area == NULL)
        return G_SOURCE_REMOVE;
    GtkWidget *old_area = context->area;
    GtkWidget *parent = gtk_widget_get_parent(old_area);
    GtkWidget *new_area = deetty_terminal_area_new(0);
    if (parent == NULL || new_area == NULL) {
        if (new_area != NULL) gtk_widget_destroy(new_area);
        context->renderer_backend = 0;
        destroy_gpu_resources(context);
        return G_SOURCE_REMOVE;
    }
    int margin_start = gtk_widget_get_margin_start(old_area);
    int margin_end = gtk_widget_get_margin_end(old_area);
    int margin_top = gtk_widget_get_margin_top(old_area);
    int margin_bottom = gtk_widget_get_margin_bottom(old_area);
    gtk_widget_set_margin_start(new_area, margin_start);
    gtk_widget_set_margin_end(new_area, margin_end);
    gtk_widget_set_margin_top(new_area, margin_top);
    gtk_widget_set_margin_bottom(new_area, margin_bottom);
    gboolean expand = TRUE;
    gboolean fill = TRUE;
    guint padding = 0;
    GtkPackType pack = GTK_PACK_START;
    gboolean parent_is_box = GTK_IS_BOX(parent);
    if (parent_is_box)
        gtk_box_query_child_packing(
            GTK_BOX(parent), old_area, &expand, &fill, &padding, &pack);
    GtkWidget *paned = NULL;
    gboolean paned_first = FALSE;
    if (GTK_IS_PANED(parent)) {
        if (gtk_paned_get_child1(GTK_PANED(parent)) == old_area) {
            paned = parent;
            paned_first = TRUE;
        } else if (gtk_paned_get_child2(GTK_PANED(parent)) == old_area) {
            paned = parent;
        }
    }
    destroy_gpu_resources(context);
    context->renderer_backend = 0;
    gtk_container_remove(GTK_CONTAINER(parent), old_area);
    if (parent_is_box) {
        if (pack == GTK_PACK_END)
            gtk_box_pack_end(
                GTK_BOX(parent), new_area, expand, fill, padding);
        else
            gtk_box_pack_start(
                GTK_BOX(parent), new_area, expand, fill, padding);
        gtk_box_set_child_packing(
            GTK_BOX(parent), new_area, expand, fill, padding, pack);
    } else if (paned != NULL) {
        if (paned_first) gtk_paned_add1(GTK_PANED(paned), new_area);
        else gtk_paned_add2(GTK_PANED(paned), new_area);
    } else {
        gtk_container_add(GTK_CONTAINER(parent), new_area);
    }
    context->area = new_area;
    connect_grid_area(context);
    gtk_widget_show_all(new_area);
    g_warning("DEETTY OpenGL presentation unavailable; using Cairo renderer");
    return G_SOURCE_REMOVE;
}

#if DEETTY_ENABLE_SMOKE
#include "../../tests/native_grid_qualification.inc"
#endif

static void on_clipboard_text(GtkClipboard *clipboard, const gchar *text, gpointer user_data) {
    DeettyGridContext *context = user_data;
    (void)clipboard;
    if (context->clipboard_requests > 0) context->clipboard_requests--;
    if (!grid_context_session_available(context)) {
        if (context->heap_allocated && context->clipboard_requests == 0 &&
            context->page == NULL)
            destroy_retired_grid_context(root_grid_context(context), context);
        return;
    }
    if (text != NULL) {
        int delivered = deliver_grid_paste(context, text, strlen(text));
        if (delivered > 0) {
            context->clipboard_pasted = 1;
            if (context->workspace_smoke == 4) (void)deliver_grid_input(context, "\r", 1);
        } else {
            show_status_feedback(
                context,
                deetty_grid_status_feedback_message(
                    DEETTY_GRID_FEEDBACK_PASTE));
        }
    }
}

static void request_grid_clipboard_text(DeettyGridContext *context) {
    if (!grid_context_session_available(context)) return;
    context->clipboard_requests++;
    deetty_grid_clipboard_request_text(deetty_grid_clipboard_get(GDK_SELECTION_CLIPBOARD),
                               on_clipboard_text, context);
}
static void copy_grid_selection_to_clipboard(DeettyGridContext *context) {
    if (!grid_context_session_available(context) || context->copy == NULL)
        return;
    DeettyGridNativeHostPolicy policy = {0};
    deetty_grid_native_host_policy(&policy);
    gsize capacity = 16u * 1024u;
    gchar *text = NULL;
    int copied_length = -1;
    while ((int64_t)capacity <= policy.selection_copy_max_bytes) {
        gchar *resized = g_try_realloc(text, capacity);
        if (resized == NULL) break;
        text = resized;
        copied_length = context->copy(
            context->userdata, text, capacity - 1,
            context->selecting ? context->selection_start_column : -1,
            context->selecting ? context->selection_start_row : -1,
            context->selecting ? context->selection_end_column : -1,
            context->selecting ? context->selection_end_row : -1);
        if (copied_length >= 0 && (gsize)copied_length < capacity) break;
        if ((int64_t)capacity == policy.selection_copy_max_bytes) break;
        capacity = deetty_grid_selection_copy_capacity_next(capacity);
    }
    if (copied_length > 0 && (gsize)copied_length < capacity) {
        text[copied_length] = '\0';
        deetty_grid_clipboard_set_text(
            deetty_grid_clipboard_get(GDK_SELECTION_CLIPBOARD), text, copied_length);
    } else if (copied_length < 0 ||
               (int64_t)(gsize)copied_length >= policy.selection_copy_max_bytes) {
        show_status_feedback(
            context,
            deetty_grid_status_feedback_message(DEETTY_GRID_FEEDBACK_COPY));
    }
    deetty_grid_memory_free(text);
}

static void apply_terminal_control(DeettyGridContext *context,
                                   const char *bytes, size_t length) {
    if (!grid_context_session_available(context)) return;
    if (deetty_grid_control(context->userdata, bytes, length) != (int)length) {
        show_status_feedback(
            context,
            deetty_grid_status_feedback_message(
                DEETTY_GRID_FEEDBACK_TERMINAL_STATE));
        return;
    }
    deetty_grid_widget_queue_draw(context->area);
}

static void clear_grid_screen(DeettyGridContext *context) {
    if (context->write == NULL ||
        context->write(context->userdata, "\x0c", 1) != 1) {
        show_status_feedback(
            context,
            deetty_grid_status_feedback_message(DEETTY_GRID_FEEDBACK_CTRL_L));
        return;
    }
    schedule_grid_write_flush(context);
}

static void clear_grid_scrollback(DeettyGridContext *context) {
    apply_terminal_control(context, "\x1b[3J", 4);
}

static void reset_grid_terminal(DeettyGridContext *context) {
    apply_terminal_control(context,
                           "\x1b[3J\x1b[2J\x1b[H\x1b" "c", 13);
}
static gboolean verify_clipboard_copy_smoke(gpointer user_data) {
    DeettyGridContext *context = user_data;
    if (!grid_context_session_available(context) || context->copy == NULL)
        return G_SOURCE_REMOVE;
    char text[16384];
    int copied_length = context->copy(
        context->userdata, text, sizeof(text) - 1, -1, -1, -1, -1);
    if (copied_length <= 1 || (size_t)copied_length >= sizeof(text))
        return G_SOURCE_REMOVE;
    text[copied_length] = '\0';
    context->clipboard_copy_valid =
        strstr(text, "DEETTY_COPY_") != NULL &&
        strstr(text, "_END") != NULL &&
        memchr(text, '\0', (size_t)copied_length - 1) == NULL;
    return G_SOURCE_REMOVE;
}

static gboolean read_clipboard_smoke(gpointer user_data) {
    DeettyGridContext *context = user_data;
    request_grid_clipboard_text(context);
    deetty_grid_source_timeout_add(400, verify_clipboard_copy_smoke, context);
    return G_SOURCE_REMOVE;
}
static gboolean request_clipboard_smoke(gpointer user_data) {
    DeettyGridContext *context = user_data;
    GtkClipboard *clipboard = deetty_grid_clipboard_get(GDK_SELECTION_CLIPBOARD);
    const gchar *command =
        "printf 'DEETTY_CLIPBOARD_OK DEETTY_COPY_\xF0\x9F\x98\x80_END'; "
        "sleep 1; exit 0\n";
    deetty_grid_clipboard_set_text(clipboard, command, -1);
    deetty_grid_source_timeout_add(200, read_clipboard_smoke, context);
    return G_SOURCE_REMOVE;
}

static void emit_grid_workspace_event(DeettyGridContext *context, int event_code);
static gboolean close_grid_tab(DeettyGridContext *context, GtkWidget *page);
static DeettyGridContext *root_grid_context(DeettyGridContext *context);
static DeettyGridContext *grid_context_for_page(DeettyGridContext *context,
                                                GtkWidget *page);
static void apply_smart_filter(DeettyGridContext *context);
static int populate_tag_suggestions(DeettyGridContext *context,
                                    GtkComboBoxText *combo);

static void sync_grid_page_branch_visibility(
    DeettyGridContext *root, GtkWidget *page) {
    GtkWidget *panes[16] = {0};
    guint pane_count = 0;
    DeettyGridContext *representative = NULL;
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len && pane_count < G_N_ELEMENTS(panes);
         index++) {
        DeettyGridContext *candidate = g_ptr_array_index(
            root->contexts, index);
        if (!candidate->active || candidate->exited ||
            candidate->page != page || candidate->area == NULL)
            continue;
        if (representative == NULL) representative = candidate;
        panes[pane_count++] = candidate->area;
    }
    GtkWidget *content = representative != NULL
        ? grid_page_content_root(representative, page) : NULL;
    if (content != NULL)
        (void)deetty_grid_sync_split_visibility(
            content, panes, pane_count);
}

static gboolean clear_smart_filter(DeettyGridContext *context) {
    DeettyGridContext *root = root_grid_context(context);
    if (root->event_data == NULL || deetty_grid_set_smart_filter(root->event_data, "", 0) != 0)
        return FALSE;
    root->smart_filter_tag = deetty_grid_memory_clear(root->smart_filter_tag);
    apply_smart_filter(root);
    if (root->area != NULL) deetty_grid_focus_widget(NULL, root->area);
    return TRUE;
}

static void on_smart_filter_empty_clear_clicked(GtkButton *button, gpointer user_data) {
    (void)button;
    (void)clear_smart_filter(user_data);
}

static void apply_smart_filter(DeettyGridContext *context) {
    DeettyGridContext *root = root_grid_context(context);
    GtkWidget *page = root->notebook != NULL
        ? deetty_grid_notebook_get_nth_page(GTK_NOTEBOOK(root->notebook),
                                    deetty_grid_notebook_get_current_page(GTK_NOTEBOOK(root->notebook)))
        : NULL;
    DeettyGridContext *first_visible = NULL;
    gboolean focused_visible = FALSE;
    const int filter_active = root->smart_filter_tag != NULL;
    for (guint index = 0; root->contexts != NULL && index < root->contexts->len; index++) {
        DeettyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (!candidate->active || candidate->page != page || candidate->area == NULL) continue;
        const int matches = filter_active == 0 ? 1 :
            root->event_data != NULL &&
            deetty_grid_pane_matches_smart_filter(root->event_data, candidate->pane_id) != 0;
        DeettyGridSmartFilterVisibilityPlan visibility_plan = {0};
        deetty_grid_smart_filter_visibility_plan(
            filter_active, matches, candidate->focused,
            first_visible != NULL, &visibility_plan);
        gboolean visible = visibility_plan.visible != 0;
        deetty_grid_widget_set_visible(candidate->area, visible);
        if (visibility_plan.first_visible != 0) first_visible = candidate;
        if (visibility_plan.focused_visible != 0) focused_visible = TRUE;
    }
    if (page != NULL) sync_grid_page_branch_visibility(root, page);
    DeettyGridSmartFilterSummaryPlan summary_plan = {0};
    deetty_grid_smart_filter_summary_plan(
        filter_active, page != NULL, first_visible != NULL,
        focused_visible, &summary_plan);
    if (summary_plan.focus_first != 0 && first_visible != NULL)
        deetty_grid_focus_widget(NULL, first_visible->area);
    if (root->smart_filter_empty_box != NULL &&
        deetty_grid_widget_get_parent(root->smart_filter_empty_box) != page) {
        deetty_grid_widget_destroy(root->smart_filter_empty_box);
        root->smart_filter_empty_box = NULL;
        root->smart_filter_empty_label = NULL;
        root->smart_filter_empty_clear_button = NULL;
    }
    char filter_empty_text[256];
    char filter_label[256];
    char filter_tooltip[128];
    DeettyGridSmartFilterTextPlan filter_text_plan = {0};
    if (deetty_grid_smart_filter_text(
            filter_active,
            (const unsigned char *)root->smart_filter_tag,
            root->smart_filter_tag != NULL
                ? strlen(root->smart_filter_tag) : 0,
            (unsigned char *)filter_empty_text, sizeof(filter_empty_text),
            (unsigned char *)filter_label, sizeof(filter_label),
            (unsigned char *)filter_tooltip, sizeof(filter_tooltip),
            &filter_text_plan) == 0)
        return;
    if (summary_plan.show_empty != 0) {
        if (root->smart_filter_empty_box == NULL) {
            DeettySmartFilterEmptyContents empty_contents = {0};
            if (!deetty_smart_filter_empty_contents_new(
                    filter_empty_text, &empty_contents))
                return;
            root->smart_filter_empty_box = empty_contents.box;
            root->smart_filter_empty_label = empty_contents.label;
            root->smart_filter_empty_clear_button =
                empty_contents.clear_button;
            deetty_grid_signal_connect(root->smart_filter_empty_clear_button, "clicked",
                             G_CALLBACK(on_smart_filter_empty_clear_clicked), root);
            deetty_box_pack_start(
                page, root->smart_filter_empty_box, FALSE, FALSE, 0);
        }
        show_all_with_action_affordances(root->smart_filter_empty_box);
    } else if (root->smart_filter_empty_box != NULL) {
        deetty_grid_widget_destroy(root->smart_filter_empty_box);
        root->smart_filter_empty_box = NULL;
        root->smart_filter_empty_label = NULL;
        root->smart_filter_empty_clear_button = NULL;
    }
    if (root->smart_filter_button != NULL) {
        deetty_grid_button_set_label(
            GTK_BUTTON(root->smart_filter_button), filter_label);
        configure_action_button(
            root->smart_filter_button, filter_tooltip);
    }
    for (guint index = 0; root->contexts != NULL && index < root->contexts->len; index++) {
        DeettyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (candidate->active && candidate->page != NULL)
            update_compact_tab(candidate);
    }
}

static void focus_notebook_page(DeettyGridContext *context, GtkWidget *page) {
    DeettyGridContext *root = root_grid_context(context);
    DeettyGridContext *target = grid_context_for_page(root, page);
    if (target == NULL) return;
    if (target->event != NULL)
        target->event(target->event_data, target->pane_id, DEETTY_GRID_HOST_EVENT(PANE_FOCUS), 0,
                      (uint64_t)(g_get_monotonic_time() / 1000));
    if (target->area != NULL) {
        deetty_grid_focus_widget(root->window, target->area);
    }
}

static gboolean cycle_grid_tab(DeettyGridContext *context, int direction) {
    DeettyGridContext *root = root_grid_context(context);
    gint count = deetty_grid_notebook_get_n_pages(GTK_NOTEBOOK(root->notebook));
    if (count < 2) return FALSE;
    gint current = deetty_grid_notebook_get_current_page(GTK_NOTEBOOK(root->notebook));
    gint next = deetty_grid_cycle_target(count, current, TRUE, direction);
    if (next < 0) return FALSE;
    GtkWidget *page = deetty_grid_notebook_get_nth_page(GTK_NOTEBOOK(root->notebook), next);
    if (page == NULL) return FALSE;
    deetty_grid_notebook_select_page(root->notebook, next);
    focus_notebook_page(root, page);
    if (direction > 0) root->tab_cycle_next = 1;
    else root->tab_cycle_previous = 1;
    return TRUE;
}

static gboolean clear_pane_cycle_feedback(gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    root->pane_cycle_feedback_source = 0;
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        DeettyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (!candidate->pane_cycle_feedback_visible) continue;
        candidate->pane_cycle_feedback_visible = 0;
        if (candidate->area != NULL) deetty_grid_widget_queue_draw(candidate->area);
    }
    return G_SOURCE_REMOVE;
}

static void show_pane_cycle_feedback(DeettyGridContext *context,
                                     guint visible_index,
                                     guint visible_count) {
    DeettyGridContext *root = root_grid_context(context);
    DeettyGridLifecycleTimingPlan timing = {0};
    deetty_grid_lifecycle_timing_plan(&timing);
    if (root->pane_cycle_feedback_source != 0) {
        deetty_grid_source_remove(root->pane_cycle_feedback_source);
        root->pane_cycle_feedback_source = 0;
    }
    if (root->tab_cycle_feedback_source != 0) {
        deetty_grid_source_remove(root->tab_cycle_feedback_source);
        root->tab_cycle_feedback_source = 0;
    }
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        DeettyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (candidate->tab_cycle_feedback_visible) {
            candidate->tab_cycle_feedback_visible = 0;
            if (candidate->area != NULL) deetty_grid_widget_queue_draw(candidate->area);
        }
        if (candidate != context && candidate->pane_cycle_feedback_visible) {
            candidate->pane_cycle_feedback_visible = 0;
            if (candidate->area != NULL) deetty_grid_widget_queue_draw(candidate->area);
        }
    }
    context->pane_cycle_feedback_visible = 1;
    context->pane_cycle_feedback_index = (int)visible_index + 1;
    context->pane_cycle_feedback_count = (int)visible_count;
    if (context->area != NULL) deetty_grid_widget_queue_draw(context->area);
    root->pane_cycle_feedback_source = deetty_grid_source_timeout_add(
        (guint)timing.pane_cycle_feedback_ms, clear_pane_cycle_feedback, root);
}

static gboolean clear_tab_cycle_feedback(gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    root->tab_cycle_feedback_source = 0;
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        DeettyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (!candidate->tab_cycle_feedback_visible) continue;
        candidate->tab_cycle_feedback_visible = 0;
            if (candidate->area != NULL) deetty_grid_widget_queue_draw(candidate->area);
    }
    return G_SOURCE_REMOVE;
}

static void show_tab_cycle_feedback(DeettyGridContext *context,
                                    guint tab_index,
                                    guint tab_count) {
    DeettyGridContext *root = root_grid_context(context);
    DeettyGridLifecycleTimingPlan timing = {0};
    deetty_grid_lifecycle_timing_plan(&timing);
    if (root->pane_cycle_feedback_source != 0) {
        deetty_grid_source_remove(root->pane_cycle_feedback_source);
        root->pane_cycle_feedback_source = 0;
    }
    if (root->tab_cycle_feedback_source != 0) {
        deetty_grid_source_remove(root->tab_cycle_feedback_source);
        root->tab_cycle_feedback_source = 0;
    }
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        DeettyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (candidate->pane_cycle_feedback_visible ||
            (candidate != context && candidate->tab_cycle_feedback_visible)) {
            candidate->pane_cycle_feedback_visible = 0;
            candidate->tab_cycle_feedback_visible = 0;
            if (candidate->area != NULL) deetty_grid_widget_queue_draw(candidate->area);
        }
    }
    context->tab_cycle_feedback_visible = 1;
    context->tab_cycle_feedback_index = (int)tab_index + 1;
    context->tab_cycle_feedback_count = (int)tab_count;
    if (context->area != NULL) deetty_grid_widget_queue_draw(context->area);
    root->tab_cycle_feedback_source = deetty_grid_source_timeout_add(
        (guint)timing.tab_cycle_feedback_ms, clear_tab_cycle_feedback, root);
}

static void show_active_tab_cycle_feedback(DeettyGridContext *context) {
    DeettyGridContext *root = root_grid_context(context);
    gint count = deetty_grid_notebook_get_n_pages(GTK_NOTEBOOK(root->notebook));
    gint index = deetty_grid_notebook_get_current_page(GTK_NOTEBOOK(root->notebook));
    if (count <= 0 || index < 0) return;
    GtkWidget *page = deetty_grid_notebook_get_nth_page(GTK_NOTEBOOK(root->notebook),
                                                index);
    DeettyGridContext *target = focused_grid_context(root);
    if (target == NULL || target->page != page)
        target = grid_context_for_page(root, page);
    if (target != NULL)
        show_tab_cycle_feedback(target, (guint)index, (guint)count);
}

static gboolean cycle_grid_pane(DeettyGridContext *context, int direction) {
    DeettyGridContext *root = root_grid_context(context);
    gint page_index = deetty_grid_notebook_get_current_page(GTK_NOTEBOOK(root->notebook));
    GtkWidget *page = deetty_grid_notebook_get_nth_page(GTK_NOTEBOOK(root->notebook),
                                                page_index);
    DeettyGridContext *current = focused_grid_context(context);
    guint count = 0;
    guint current_index = 0;
    gboolean current_found = FALSE;
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        DeettyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (!candidate->active || candidate->exited || candidate->page != page ||
            candidate->area == NULL || !deetty_grid_widget_get_visible(candidate->area))
            continue;
        if (candidate == current) {
            current_index = count;
            current_found = TRUE;
        }
        count++;
    }
    if (count == 0) return TRUE;

    if (count > G_MAXINT) return TRUE;
    gint target_index = deetty_grid_cycle_target(
        (gint)count, (gint)current_index, current_found, direction);
    if (target_index < 0) return TRUE;

    DeettyGridContext *target = NULL;
    guint visible_index = 0;
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        DeettyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (!candidate->active || candidate->exited || candidate->page != page ||
            candidate->area == NULL || !deetty_grid_widget_get_visible(candidate->area))
            continue;
        if ((gint)visible_index == target_index) {
            target = candidate;
            break;
        }
        visible_index++;
    }
    if (target == NULL) return TRUE;
    if (target != current) {
        deetty_grid_focus_widget(root->window, target->area);
        if (root->workspace_smoke == 22)
            activate_grid_context(target);
        if (direction > 0) root->pane_cycle_next = 1;
    }
    show_pane_cycle_feedback(target, (guint)target_index, count);
    return TRUE;
}
static DeettyGridContext *grid_context_for_pane(DeettyGridContext *context,
                                                uint64_t pane_id);
static gboolean move_grid_context(DeettyGridContext *source,
                                  DeettyGridContext *target);

static gboolean emit_workspace_smoke_tab(gpointer user_data) {
    DeettyGridContext *context = user_data;
    emit_grid_workspace_event(context, DEETTY_GRID_HOST_EVENT(WORKSPACE_NEW_TAB));
    return G_SOURCE_REMOVE;
}

static const char *title_overflow_smoke_text = "A deliberately long shell title for native overflow verification";
static const char *dirty_smoke_title = "Dirty native tab";
static void open_command_palette(DeettyGridContext *context);
static void on_palette_search_activate(GtkEntry *entry, gpointer user_data);

static gboolean check_title_fallback_smoke(gpointer user_data) {
    DeettyGridContext *context = focused_grid_context(user_data);
    DeettyGridContext *root = root_grid_context(context);
    gchar *title = current_tab_title_alloc(context);
    const gchar *label = context->tab_label != NULL
        ? deetty_grid_label_get_text(GTK_LABEL(context->tab_label)) : "";
    if (g_strcmp0(title, ".") == 0 || g_strcmp0(title, "tmp") == 0 || g_strcmp0(title, "Tab 1") == 0)
        if (root->event != NULL) root->event(root->event_data, root->pane_id, DEETTY_GRID_HOST_EVENT(TITLE_FALLBACK), 1, (uint64_t)(g_get_monotonic_time() / 1000));
    (void)label;
    deetty_grid_memory_free(title);
    return G_SOURCE_REMOVE;
}

static gboolean emit_title_overflow_smoke(gpointer user_data) {
    DeettyGridContext *context = focused_grid_context(user_data);
    const char *command = "printf '\\033]2;A deliberately long shell title for native overflow verification\\007'\n";
    (void)context->write(context->userdata, command, strlen(command));
    return G_SOURCE_REMOVE;
}

static gboolean check_title_overflow_smoke(gpointer user_data) {
    DeettyGridContext *context = focused_grid_context(user_data);
    DeettyGridContext *root = root_grid_context(context);
    const gchar *label = context->tab_label != NULL
        ? deetty_grid_label_get_text(GTK_LABEL(context->tab_label)) : "";
    gchar *tooltip = context->tab_label != NULL
        ? deetty_grid_widget_get_tooltip_text(context->tab_label) : NULL;
    if (strstr(label, "…") != NULL && root->event != NULL)
        root->event(root->event_data, root->pane_id, DEETTY_GRID_HOST_EVENT(TITLE_OVERFLOW_LABEL), 1, (uint64_t)(g_get_monotonic_time() / 1000));
    if (tooltip != NULL && strstr(tooltip, title_overflow_smoke_text) != NULL && root->event != NULL)
        root->event(root->event_data, root->pane_id, DEETTY_GRID_HOST_EVENT(TITLE_OVERFLOW_TOOLTIP), 1, (uint64_t)(g_get_monotonic_time() / 1000));
    deetty_grid_memory_free(tooltip);
    return G_SOURCE_REMOVE;
}

static gboolean check_title_rename_smoke(gpointer user_data) {
    DeettyGridContext *context = focused_grid_context(user_data);
    DeettyGridContext *root = root_grid_context(context);
    const char *renamed = "Renamed native tab";
    if (root->event_data != NULL && deetty_grid_rename_tab(root->event_data,
            context->pane_id, renamed, strlen(renamed)) == 0) {
        update_compact_tab(context);
        const gchar *label = context->tab_label != NULL
            ? deetty_grid_label_get_text(GTK_LABEL(context->tab_label)) : "";
        if (strstr(label, renamed) != NULL && root->event != NULL)
            root->event(root->event_data, root->pane_id, DEETTY_GRID_HOST_EVENT(TITLE_RENAMED), 1, (uint64_t)(g_get_monotonic_time() / 1000));
    }
    return G_SOURCE_REMOVE;
}

static gboolean finish_title_smoke(gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    for (guint index = 0; root->contexts != NULL && index < root->contexts->len; index++) {
        DeettyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (candidate->active && !candidate->exited)
            (void)candidate->write(candidate->userdata, "exit 0\n", 7);
    }
    return G_SOURCE_REMOVE;
}

static gboolean trigger_dirty_smoke(gpointer user_data) {
    DeettyGridContext *context = focused_grid_context(user_data);
    DeettyGridContext *root = root_grid_context(context);
    if (root->event_data != NULL && deetty_grid_rename_tab(root->event_data,
            context->pane_id, dirty_smoke_title, strlen(dirty_smoke_title)) == 0) {
        update_compact_tab(context);
    }
    return G_SOURCE_REMOVE;
}

static gboolean emit_attention_smoke(gpointer user_data) {
    DeettyGridContext *context = focused_grid_context(user_data);
    const char *command =
        "printf '\\033]9;Agent needs input\\033\\\\'\n";
    (void)context->write(context->userdata, command, strlen(command));
    return G_SOURCE_REMOVE;
}

static gboolean check_dirty_smoke(gpointer user_data) {
    DeettyGridContext *context = focused_grid_context(user_data);
    DeettyGridContext *root = root_grid_context(context);
    const gchar *label = context->tab_label != NULL
        ? deetty_grid_label_get_text(GTK_LABEL(context->tab_label)) : "";
    gchar *tooltip = context->tab_label != NULL
        ? deetty_grid_widget_get_tooltip_text(context->tab_label) : NULL;
    if (strstr(label, dirty_smoke_title) != NULL && strstr(label, "◆") != NULL &&
        tooltip != NULL && strstr(tooltip, "unsaved workspace") != NULL &&
        root->event != NULL)
        root->event(root->event_data, root->pane_id, DEETTY_GRID_HOST_EVENT(DIRTY_MARKED), 1,
                    (uint64_t)(g_get_monotonic_time() / 1000));
    deetty_grid_memory_free(tooltip);
    return G_SOURCE_REMOVE;
}

static gboolean check_attention_smoke(gpointer user_data) {
    DeettyGridContext *context = focused_grid_context(user_data);
    DeettyGridContext *root = root_grid_context(context);
    if (context->status_kind == 4 &&
        deetty_grid_notification_serial(context->userdata) > 0 &&
        root->event != NULL)
        root->event(root->event_data, root->pane_id, DEETTY_GRID_HOST_EVENT(NOTIFICATION_ATTENTION), 1,
                    (uint64_t)(g_get_monotonic_time() / 1000));
    return G_SOURCE_REMOVE;
}

static gboolean acknowledge_attention_smoke(gpointer user_data) {
    DeettyGridContext *context = focused_grid_context(user_data);
    (void)deliver_grid_input(context, "\n", 1);
    return G_SOURCE_REMOVE;
}

static gboolean save_dirty_smoke(gpointer user_data) {
    DeettyGridContext *context = focused_grid_context(user_data);
    DeettyGridContext *root = root_grid_context(context);
    if (root->event != NULL)
        root->event(root->event_data, root->pane_id, DEETTY_GRID_HOST_EVENT(DIRTY_SAVED), 1,
                    (uint64_t)(g_get_monotonic_time() / 1000));
    update_compact_tab(context);
    return G_SOURCE_REMOVE;
}

static gboolean check_dirty_clear_smoke(gpointer user_data) {
    DeettyGridContext *context = focused_grid_context(user_data);
    DeettyGridContext *root = root_grid_context(context);
    const gchar *label = context->tab_label != NULL
        ? deetty_grid_label_get_text(GTK_LABEL(context->tab_label)) : "";
    gchar *tooltip = context->tab_label != NULL
        ? deetty_grid_widget_get_tooltip_text(context->tab_label) : NULL;
    if (strstr(label, dirty_smoke_title) != NULL && strstr(label, "◆") == NULL &&
        tooltip != NULL && strstr(tooltip, "unsaved workspace") == NULL &&
        root->event != NULL)
        root->event(root->event_data, root->pane_id, DEETTY_GRID_HOST_EVENT(DIRTY_CLEARED), 1,
                    (uint64_t)(g_get_monotonic_time() / 1000));
    deetty_grid_memory_free(tooltip);
    return G_SOURCE_REMOVE;
}

static gboolean announce_reorder_drag_smoke(gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    root->tab_reorder_ready_attempts++;
    if (root->contexts == NULL || root->contexts->len < 3 ||
        !deetty_grid_widget_get_mapped(root->window)) {
        return root->tab_reorder_ready_attempts < 30
            ? G_SOURCE_CONTINUE : G_SOURCE_REMOVE;
    }
    DeettyGridContext *source = g_ptr_array_index(root->contexts, 0);
    DeettyGridContext *target = g_ptr_array_index(root->contexts, 2);
    GtkWidget *source_tab = deetty_grid_notebook_get_tab_label(
        GTK_NOTEBOOK(root->notebook), source->page);
    GtkWidget *target_tab = deetty_grid_notebook_get_tab_label(
        GTK_NOTEBOOK(root->notebook), target->page);
    GtkAllocation source_allocation;
    GtkAllocation target_allocation;
    gint source_x = 0;
    gint source_y = 0;
    gint target_x = 0;
    gint target_y = 0;
    if (source_tab == NULL || target_tab == NULL) return G_SOURCE_REMOVE;
    deetty_grid_widget_get_allocation(source_tab, &source_allocation);
    deetty_grid_widget_get_allocation(target_tab, &target_allocation);
    if (!deetty_grid_widget_translate_coordinates(
            source_tab, root->window,
            MAX(4, source_allocation.width / 3),
            MAX(4, source_allocation.height / 2),
            &source_x, &source_y) ||
        !deetty_grid_widget_translate_coordinates(
            target_tab, root->window,
            MAX(4, target_allocation.width - 3),
            MAX(4, target_allocation.height / 2),
            &target_x, &target_y))
        return G_SOURCE_REMOVE;
    GdkWindow *native_window = deetty_grid_widget_get_window(root->window);
    if (native_window == NULL) return G_SOURCE_CONTINUE;
    gint origin_x = 0;
    gint origin_y = 0;
    deetty_grid_gdk_window_get_origin(native_window, &origin_x, &origin_y);
    source_x += origin_x;
    source_y += origin_y;
    target_x += origin_x;
    target_y += origin_y;
    g_printerr("native_grid_tab_reorder_ready source_x=%d source_y=%d target_x=%d target_y=%d tabs=3\n",
               source_x, source_y, target_x, target_y);
    fflush(stderr);
    return G_SOURCE_REMOVE;
}

static gboolean check_reorder_smoke(gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    if (root->contexts == NULL || root->contexts->len < 3) return G_SOURCE_REMOVE;
    DeettyGridContext *first = g_ptr_array_index(root->contexts, 0);
    DeettyGridContext *second = g_ptr_array_index(root->contexts, 1);
    DeettyGridContext *third = g_ptr_array_index(root->contexts, 2);
    GtkWidget *page_zero = deetty_grid_notebook_get_nth_page(GTK_NOTEBOOK(root->notebook), 0);
    GtkWidget *page_one = deetty_grid_notebook_get_nth_page(GTK_NOTEBOOK(root->notebook), 1);
    GtkWidget *page_two = deetty_grid_notebook_get_nth_page(GTK_NOTEBOOK(root->notebook), 2);
    GtkWidget *active = deetty_grid_notebook_get_nth_page(
        GTK_NOTEBOOK(root->notebook),
        deetty_grid_notebook_get_current_page(GTK_NOTEBOOK(root->notebook)));
    gboolean valid = page_zero == second->page && page_one == third->page &&
        page_two == first->page && active == third->page &&
        root->tab_reorder_pointer_press_seen &&
        root->tab_reorder_count > 0;
    if (!valid)
        g_printerr("native_grid_tab_reorder_flags press=%d release=%d begin=%d end=%d count=%d order=%d,%d,%d active=%d\n",
                   root->tab_reorder_pointer_press_seen,
                   root->tab_reorder_pointer_release_seen,
                   root->tab_reorder_drag_begin_seen,
                   root->tab_reorder_drag_end_seen,
                   root->tab_reorder_count,
                   page_zero == second->page,
                   page_one == third->page,
                   page_two == first->page,
                   active == third->page);
    if (valid && root->event != NULL)
        root->event(root->event_data, root->pane_id, DEETTY_GRID_HOST_EVENT(TAB_REORDERED), 1,
                    (uint64_t)(g_get_monotonic_time() / 1000));
    return G_SOURCE_REMOVE;
}

static gboolean persist_reorder_smoke(gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    if (root->event != NULL)
        root->event(root->event_data, root->pane_id, DEETTY_GRID_HOST_EVENT(TAB_REORDER_PERSISTED), 1,
                    (uint64_t)(g_get_monotonic_time() / 1000));
    return G_SOURCE_REMOVE;
}

static void activate_palette_rename_smoke(DeettyGridContext *root) {
    open_command_palette(root);
    if (root->palette_search == NULL || root->palette_list == NULL) return;
    deetty_grid_entry_set_text(GTK_ENTRY(root->palette_search), "Rename active tab");
    on_palette_search_activate(GTK_ENTRY(root->palette_search), root);
}

static gboolean palette_rename_smoke(gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    activate_palette_rename_smoke(root);
    if (root->tab_rename_entry == NULL) return G_SOURCE_REMOVE;
    deetty_grid_entry_set_text(GTK_ENTRY(root->tab_rename_entry), "");
    g_signal_emit_by_name(root->tab_rename_entry, "activate");
    gchar *validation_text = root->tab_rename_entry != NULL
        ? deetty_grid_widget_get_tooltip_text(root->tab_rename_entry) : NULL;
    gboolean validation = root->tab_rename_entry != NULL &&
        g_strcmp0(validation_text, "Enter a tab name.") == 0;
    deetty_grid_memory_free(validation_text);
    if (validation && root->event != NULL)
        root->event(root->event_data, root->pane_id, DEETTY_GRID_HOST_EVENT(RENAME_VALIDATION), 1,
                    (uint64_t)(g_get_monotonic_time() / 1000));
    deetty_grid_entry_set_text(GTK_ENTRY(root->tab_rename_entry), "Palette renamed tab");
    g_signal_emit_by_name(root->tab_rename_entry, "activate");
    const gchar *label = root->tab_label != NULL
        ? deetty_grid_label_get_text(GTK_LABEL(root->tab_label)) : "";
    if (root->tab_rename_entry == NULL && strstr(label, "Palette renamed tab") != NULL &&
        root->tab_rename_applied && root->event != NULL)
        root->event(root->event_data, root->pane_id, DEETTY_GRID_HOST_EVENT(RENAME_APPLIED), 1,
                    (uint64_t)(g_get_monotonic_time() / 1000));

    activate_palette_rename_smoke(root);
    if (root->tab_rename_entry != NULL) {
        deetty_grid_entry_set_text(GTK_ENTRY(root->tab_rename_entry), "Cancelled palette rename");
        GdkEventKey escape = {0};
        escape.type = GDK_KEY_PRESS;
        escape.keyval = GDK_KEY_Escape;
        (void)on_tab_rename_key(root->tab_rename_entry, &escape, root);
        label = root->tab_label != NULL
            ? deetty_grid_label_get_text(GTK_LABEL(root->tab_label)) : "";
        if (root->tab_rename_entry == NULL && strstr(label, "Palette renamed tab") != NULL &&
            deetty_grid_widget_has_focus(root->area) && root->event != NULL)
            root->event(root->event_data, root->pane_id, DEETTY_GRID_HOST_EVENT(RENAME_CANCELLED), 1,
                        (uint64_t)(g_get_monotonic_time() / 1000));
    }
    return G_SOURCE_REMOVE;
}

static gboolean emit_tab_cycle_next_smoke(gpointer user_data) {
    DeettyGridContext *context = focused_grid_context(user_data);
    DeettyGridContext *root = root_grid_context(context);
    GdkEventKey event = {0};
    event.type = GDK_KEY_PRESS;
    event.keyval = GDK_KEY_Page_Down;
    event.state = GDK_CONTROL_MASK;
    if (on_key_press(context->area, &event, context) && root->tab_cycle_next && root->event != NULL)
        root->event(root->event_data, root->pane_id, DEETTY_GRID_HOST_EVENT(TAB_CYCLE), 1, (uint64_t)(g_get_monotonic_time() / 1000));
    return G_SOURCE_REMOVE;
}

static gboolean grid_context_owns_window_focus(DeettyGridContext *context) {
    DeettyGridContext *root = root_grid_context(context);
    return context != NULL && context->area != NULL && root->window != NULL &&
        deetty_grid_window_get_focus(GTK_WINDOW(root->window)) == context->area;
}

static gboolean emit_pane_cycle_shortcut_smoke(gpointer user_data) {
    DeettyGridContext *context = focused_grid_context(user_data);
    DeettyGridContext *root = root_grid_context(context);
    GtkWidget *page = context->page;
    uint64_t starting_pane = context->pane_id;
    GdkEventKey event = {0};
    event.type = GDK_KEY_PRESS;
    event.keyval = GDK_KEY_Tab;
    event.state = GDK_CONTROL_MASK;
    gboolean handled = on_key_press(context->area, &event, context);
    DeettyGridContext *focused = focused_grid_context(root);
    if (handled && root->pane_cycle_next && focused != NULL &&
        focused->page == page && focused->pane_id != starting_pane &&
        root->event != NULL)
        root->event(root->event_data, focused->pane_id, DEETTY_GRID_HOST_EVENT(PANE_CYCLE_SHORTCUT), 1,
                    (uint64_t)(g_get_monotonic_time() / 1000));
    return G_SOURCE_REMOVE;
}

static gboolean emit_alt_scroll_next_smoke(gpointer user_data) {
    DeettyGridContext *context = focused_grid_context(user_data);
    DeettyGridContext *root = root_grid_context(context);
    root->alt_scroll_start_pane_id = context->pane_id;
    root->alt_scroll_start_page = context->page;
    GdkEventScroll event = {0};
    event.type = GDK_SCROLL;
    event.direction = GDK_SCROLL_DOWN;
    event.state = GDK_MOD1_MASK;
    gboolean handled = on_scroll(context->area, &event, context);
    DeettyGridContext *focused = focused_grid_context(root);
    root->alt_scroll_cycle_next = handled && focused != NULL &&
        focused->pane_id != root->alt_scroll_start_pane_id &&
        focused->page == root->alt_scroll_start_page &&
        grid_context_owns_window_focus(focused) &&
        focused->pane_cycle_feedback_visible;
    if (!root->alt_scroll_cycle_next)
        g_printerr("native_grid_alt_scroll_next handled=%d start=%" G_GUINT64_FORMAT " focused=%" G_GUINT64_FORMAT " same_page=%d widget_focus=%d feedback=%d\n",
                   handled, root->alt_scroll_start_pane_id,
                   focused != NULL ? focused->pane_id : 0,
                   focused != NULL && focused->page == root->alt_scroll_start_page,
                   focused != NULL && grid_context_owns_window_focus(focused),
                   focused != NULL && focused->pane_cycle_feedback_visible);
    root->alt_scroll_current_tab = root->alt_scroll_cycle_next &&
        deetty_grid_notebook_get_nth_page(
            GTK_NOTEBOOK(root->notebook),
            deetty_grid_notebook_get_current_page(GTK_NOTEBOOK(root->notebook))) ==
            root->alt_scroll_start_page;
    return G_SOURCE_REMOVE;
}

static gboolean emit_alt_scroll_previous_smoke(gpointer user_data) {
    DeettyGridContext *context = focused_grid_context(user_data);
    DeettyGridContext *root = root_grid_context(context);
    gboolean feedback_drawn = context->pane_cycle_feedback_visible &&
        root->pane_cycle_feedback_drawn;
    GdkEventScroll event = {0};
    event.type = GDK_SCROLL;
    event.direction = GDK_SCROLL_UP;
    event.state = GDK_MOD1_MASK;
    gboolean handled = on_scroll(context->area, &event, context);
    DeettyGridContext *focused = focused_grid_context(root);
    root->alt_scroll_cycle_previous = handled && feedback_drawn &&
        focused != NULL &&
        focused->pane_id == root->alt_scroll_start_pane_id &&
        focused->page == root->alt_scroll_start_page &&
        grid_context_owns_window_focus(focused) &&
        focused->pane_cycle_feedback_visible;
    if (!root->alt_scroll_cycle_previous)
        g_printerr("native_grid_alt_scroll_previous handled=%d feedback_drawn=%d start=%" G_GUINT64_FORMAT " focused=%" G_GUINT64_FORMAT " same_page=%d widget_focus=%d feedback=%d\n",
                   handled, feedback_drawn, root->alt_scroll_start_pane_id,
                   focused != NULL ? focused->pane_id : 0,
                   focused != NULL && focused->page == root->alt_scroll_start_page,
                   focused != NULL && grid_context_owns_window_focus(focused),
                   focused != NULL && focused->pane_cycle_feedback_visible);
    return G_SOURCE_REMOVE;
}

static gboolean emit_ctrl_alt_scroll_next_smoke(gpointer user_data) {
    DeettyGridContext *context = focused_grid_context(user_data);
    DeettyGridContext *root = root_grid_context(context);
    gint count = deetty_grid_notebook_get_n_pages(GTK_NOTEBOOK(root->notebook));
    gint before = deetty_grid_notebook_get_current_page(GTK_NOTEBOOK(root->notebook));
    root->ctrl_alt_scroll_start_page = context->page;
    GdkEventScroll event = {0};
    event.type = GDK_SCROLL;
    event.direction = GDK_SCROLL_DOWN;
    event.state = GDK_CONTROL_MASK | GDK_MOD1_MASK;
    gboolean handled = on_scroll(context->area, &event, context);
    gint after = deetty_grid_notebook_get_current_page(GTK_NOTEBOOK(root->notebook));
    GtkWidget *page = deetty_grid_notebook_get_nth_page(GTK_NOTEBOOK(root->notebook),
                                                after);
    DeettyGridContext *focused = focused_grid_context(root);
    root->ctrl_alt_scroll_cycle_next = handled && count >= 2 &&
        before != after && page != root->ctrl_alt_scroll_start_page &&
        focused != NULL && focused->page == page &&
        grid_context_owns_window_focus(focused) &&
        focused->tab_cycle_feedback_visible;
    root->ctrl_alt_scroll_wraparound = count >= 2 &&
        before == count - 1 && after == 0;
    if (!root->ctrl_alt_scroll_cycle_next ||
        !root->ctrl_alt_scroll_wraparound)
        g_printerr("native_grid_ctrl_alt_scroll_next handled=%d count=%d before=%d after=%d page_changed=%d focused_page=%d widget_focus=%d feedback=%d wrap=%d\n",
                   handled, count, before, after,
                   page != root->ctrl_alt_scroll_start_page,
                   focused != NULL && focused->page == page,
                   focused != NULL && grid_context_owns_window_focus(focused),
                   focused != NULL && focused->tab_cycle_feedback_visible,
                   root->ctrl_alt_scroll_wraparound);
    return G_SOURCE_REMOVE;
}

static gboolean emit_ctrl_alt_scroll_previous_smoke(gpointer user_data) {
    DeettyGridContext *context = focused_grid_context(user_data);
    DeettyGridContext *root = root_grid_context(context);
    gboolean feedback_drawn = context->tab_cycle_feedback_visible &&
        root->tab_cycle_feedback_drawn;
    GdkEventScroll event = {0};
    event.type = GDK_SCROLL;
    event.direction = GDK_SCROLL_UP;
    event.state = GDK_CONTROL_MASK | GDK_MOD1_MASK;
    gboolean handled = on_scroll(context->area, &event, context);
    gint after = deetty_grid_notebook_get_current_page(GTK_NOTEBOOK(root->notebook));
    GtkWidget *page = deetty_grid_notebook_get_nth_page(GTK_NOTEBOOK(root->notebook),
                                                after);
    DeettyGridContext *focused = focused_grid_context(root);
    root->ctrl_alt_scroll_cycle_previous = handled && feedback_drawn &&
        page == root->ctrl_alt_scroll_start_page && focused != NULL &&
        focused->page == page && grid_context_owns_window_focus(focused) &&
        focused->tab_cycle_feedback_visible;
    if (!root->ctrl_alt_scroll_cycle_previous)
        g_printerr("native_grid_ctrl_alt_scroll_previous handled=%d feedback_drawn=%d page_restored=%d focused_page=%d widget_focus=%d feedback=%d\n",
                   handled, feedback_drawn,
                   page == root->ctrl_alt_scroll_start_page,
                   focused != NULL && focused->page == page,
                   focused != NULL && grid_context_owns_window_focus(focused),
                   focused != NULL && focused->tab_cycle_feedback_visible);
    if (root->ctrl_alt_scroll_cycle_next &&
        root->ctrl_alt_scroll_cycle_previous &&
        root->ctrl_alt_scroll_wraparound &&
        root->tab_cycle_feedback_drawn && root->event != NULL &&
        focused != NULL)
        root->event(root->event_data, focused->pane_id, DEETTY_GRID_HOST_EVENT(CTRL_ALT_SCROLL), 1,
                    (uint64_t)(g_get_monotonic_time() / 1000));
    return G_SOURCE_REMOVE;
}

static gboolean prepare_smart_tab_cycle_smoke(gpointer user_data) {
    DeettyGridContext *context = focused_grid_context(user_data);
    DeettyGridContext *root = root_grid_context(context);
    if (context == NULL || context->pane_id > 9 || root->event_data == NULL)
        return G_SOURCE_REMOVE;
    if (root->event != NULL)
        root->event(root->event_data, context->pane_id,
                    30 + (int)context->pane_id, 0,
                    (uint64_t)(g_get_monotonic_time() / 1000));
    if (deetty_grid_tag_selected_panes(root->event_data, "navigation", 10) != 0 ||
        deetty_grid_set_smart_filter(root->event_data, "navigation", 10) != 0)
        return G_SOURCE_REMOVE;
    root->smart_filter_tag = deetty_grid_memory_clear(root->smart_filter_tag);
    root->smart_filter_tag = g_strdup("navigation");
    apply_smart_filter(root);
    return G_SOURCE_REMOVE;
}

static gboolean emit_alt_scroll_filtered_smoke(gpointer user_data) {
    DeettyGridContext *context = focused_grid_context(user_data);
    DeettyGridContext *root = root_grid_context(context);
    GtkWidget *page = context->page;
    uint64_t pane_id = context->pane_id;
    guint visible_count = 0;
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        DeettyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (candidate->active && !candidate->exited &&
            candidate->page == page && candidate->area != NULL &&
            deetty_grid_widget_get_visible(candidate->area)) visible_count++;
    }
    GdkEventScroll event = {0};
    event.type = GDK_SCROLL;
    event.direction = GDK_SCROLL_DOWN;
    event.state = GDK_MOD1_MASK;
    gboolean handled = on_scroll(context->area, &event, context);
    DeettyGridContext *focused = focused_grid_context(root);
    root->alt_scroll_hidden_skipped = handled && visible_count == 1 &&
        focused != NULL && focused->pane_id == pane_id &&
        focused->page == page && grid_context_owns_window_focus(focused) &&
        focused->pane_cycle_feedback_visible;
    if (!root->alt_scroll_hidden_skipped)
        g_printerr("native_grid_alt_scroll_filtered handled=%d visible=%u start=%" G_GUINT64_FORMAT " focused=%" G_GUINT64_FORMAT " same_page=%d widget_focus=%d feedback=%d\n",
                   handled, visible_count, pane_id,
                   focused != NULL ? focused->pane_id : 0,
                   focused != NULL && focused->page == page,
                   focused != NULL && grid_context_owns_window_focus(focused),
                   focused != NULL && focused->pane_cycle_feedback_visible);
    if (root->alt_scroll_cycle_next && root->alt_scroll_cycle_previous &&
        root->alt_scroll_current_tab && root->alt_scroll_hidden_skipped &&
        root->pane_cycle_feedback_drawn && root->event != NULL &&
        focused != NULL)
        root->event(root->event_data, focused->pane_id, DEETTY_GRID_HOST_EVENT(ALT_SCROLL_NEXT), 1,
                    (uint64_t)(g_get_monotonic_time() / 1000));
    return G_SOURCE_REMOVE;
}

static gboolean emit_smart_tab_cycle_shortcut_smoke(gpointer user_data) {
    DeettyGridContext *context = focused_grid_context(user_data);
    DeettyGridContext *root = root_grid_context(context);
    gint before = deetty_grid_notebook_get_current_page(GTK_NOTEBOOK(root->notebook));
    GdkEventKey event = {0};
    event.type = GDK_KEY_PRESS;
    event.keyval = GDK_KEY_ISO_Left_Tab;
    event.state = GDK_CONTROL_MASK | GDK_SHIFT_MASK;
    gboolean handled = on_key_press(context->area, &event, context);
    gint after = deetty_grid_notebook_get_current_page(GTK_NOTEBOOK(root->notebook));
    GtkWidget *page = deetty_grid_notebook_get_nth_page(GTK_NOTEBOOK(root->notebook), after);
    DeettyGridContext *target = grid_context_for_page(root, page);
    const gchar *label = target != NULL && target->tab_label != NULL
        ? deetty_grid_label_get_text(GTK_LABEL(target->tab_label)) : "";
    gboolean smart_filter_visible = root->smart_filter_tag != NULL &&
        g_strcmp0(root->smart_filter_tag, "navigation") == 0 &&
        strstr(label, "navigation") != NULL;
    if (handled && before != after && smart_filter_visible) {
        root->tab_cycle_smart_filter = 1;
        if (root->event != NULL && target != NULL)
            root->event(root->event_data, target->pane_id, DEETTY_GRID_HOST_EVENT(ALT_SCROLL_PREVIOUS), 1,
                        (uint64_t)(g_get_monotonic_time() / 1000));
    }
    return G_SOURCE_REMOVE;
}

static gboolean clear_tab_navigation_filter_smoke(gpointer user_data) {
    (void)clear_smart_filter(user_data);
    return G_SOURCE_REMOVE;
}

static gboolean emit_tab_cycle_previous_smoke(gpointer user_data) {
    DeettyGridContext *context = focused_grid_context(user_data);
    DeettyGridContext *root = root_grid_context(context);
    GdkEventKey event = {0};
    event.type = GDK_KEY_PRESS;
    event.keyval = GDK_KEY_Page_Up;
    event.state = GDK_CONTROL_MASK;
    if (on_key_press(context->area, &event, context) && root->tab_cycle_previous && root->event != NULL)
        root->event(root->event_data, root->pane_id, DEETTY_GRID_HOST_EVENT(TAB_CYCLE), -1, (uint64_t)(g_get_monotonic_time() / 1000));
    return G_SOURCE_REMOVE;
}

static gboolean emit_tab_close_shortcut_smoke(gpointer user_data) {
    DeettyGridContext *context = focused_grid_context(user_data);
    DeettyGridContext *root = root_grid_context(context);
    GdkEventKey event = {0};
    event.type = GDK_KEY_PRESS;
    event.keyval = GDK_KEY_w;
    event.state = GDK_CONTROL_MASK | GDK_SHIFT_MASK;
    if (on_key_press(context->area, &event, context) && root->tab_shortcut_close && root->event != NULL)
        root->event(root->event_data, root->pane_id, DEETTY_GRID_HOST_EVENT(TAB_CLOSE), 1, (uint64_t)(g_get_monotonic_time() / 1000));
    return G_SOURCE_REMOVE;
}

static gboolean emit_tab_reopen_shortcut_smoke(gpointer user_data) {
    DeettyGridContext *context = focused_grid_context(user_data);
    DeettyGridContext *root = root_grid_context(context);
    GdkEventKey event = {0};
    event.type = GDK_KEY_PRESS;
    event.keyval = GDK_KEY_t;
    event.state = GDK_CONTROL_MASK | GDK_SHIFT_MASK;
    if (on_key_press(context->area, &event, context) && root->tab_shortcut_reopen && root->event != NULL)
        root->event(root->event_data, root->pane_id, DEETTY_GRID_HOST_EVENT(TAB_REOPEN), 1, (uint64_t)(g_get_monotonic_time() / 1000));
    return G_SOURCE_REMOVE;
}

static gboolean finish_tab_navigation_smoke(gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    DeettyGridContext *focused = focused_grid_context(root);
    if (focused->event != NULL)
        focused->event(focused->event_data, focused->pane_id, DEETTY_GRID_HOST_EVENT(PANE_CYCLE),
                       grid_context_owns_window_focus(focused) ? 1 : 0,
                       (uint64_t)(g_get_monotonic_time() / 1000));
    for (guint index = 0; root->contexts != NULL && index < root->contexts->len; index++) {
        DeettyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (candidate->active && !candidate->exited)
            (void)candidate->write(candidate->userdata, "exit 0\n", 7);
    }
    return G_SOURCE_REMOVE;
}

static gboolean start_tab_navigation_interactions(gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    gint page_index = deetty_grid_notebook_get_current_page(
        GTK_NOTEBOOK(root->notebook));
    GtkWidget *page = deetty_grid_notebook_get_nth_page(
        GTK_NOTEBOOK(root->notebook), page_index);
    guint visible_drawn = 0;
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        DeettyGridContext *candidate =
            g_ptr_array_index(root->contexts, index);
        if (candidate->active && !candidate->exited &&
            candidate->page == page && candidate->area != NULL &&
            deetty_grid_widget_get_visible(candidate->area) &&
            deetty_grid_widget_get_mapped(candidate->area) && candidate->saw_draw)
            visible_drawn++;
    }
    DeettyGridContext *focus_target = focused_grid_context(root);
    gboolean surfaces_ready =
        deetty_grid_notebook_get_n_pages(GTK_NOTEBOOK(root->notebook)) == 2 &&
        page_index == 1 && visible_drawn == 2 &&
        root->window_presented && deetty_grid_widget_get_mapped(root->window) &&
        focus_target != NULL && focus_target->area != NULL;
    if (surfaces_ready && !grid_context_owns_window_focus(focus_target)) {
        deetty_grid_focus_widget(root->window, focus_target->area);
    }
    if ((!surfaces_ready || !grid_context_owns_window_focus(focus_target)) &&
        root->project_smoke_attempts++ < 200) {
        deetty_grid_source_timeout_add(25, start_tab_navigation_interactions, root);
        return G_SOURCE_REMOVE;
    }
    root->project_smoke_attempts = 0;
    if (!surfaces_ready || !grid_context_owns_window_focus(focus_target)) {
        g_printerr("native_grid_navigation_start pages=%d page=%d visible_drawn=%u window_presented=%d window_mapped=%d focus_target=%d widget_focus=%d\n",
                   deetty_grid_notebook_get_n_pages(GTK_NOTEBOOK(root->notebook)),
                   page_index, visible_drawn, root->window_presented,
                   deetty_grid_widget_get_mapped(root->window),
                   focus_target != NULL && focus_target->area != NULL,
                   focus_target != NULL && focus_target->area != NULL &&
                       grid_context_owns_window_focus(focus_target));
        deetty_grid_source_timeout_add(50, finish_tab_navigation_smoke, root);
        return G_SOURCE_REMOVE;
    }
    deetty_grid_source_timeout_add(50, emit_pane_cycle_shortcut_smoke, root);
    deetty_grid_source_timeout_add(200, emit_alt_scroll_next_smoke, root);
    deetty_grid_source_timeout_add(350, emit_alt_scroll_previous_smoke, root);
    deetty_grid_source_timeout_add(500, emit_ctrl_alt_scroll_next_smoke, root);
    deetty_grid_source_timeout_add(700, emit_ctrl_alt_scroll_previous_smoke, root);
    deetty_grid_source_timeout_add(900, prepare_smart_tab_cycle_smoke, root);
    deetty_grid_source_timeout_add(1050, emit_alt_scroll_filtered_smoke, root);
    deetty_grid_source_timeout_add(1200, emit_smart_tab_cycle_shortcut_smoke, root);
    deetty_grid_source_timeout_add(1350, clear_tab_navigation_filter_smoke, root);
    deetty_grid_source_timeout_add(1500, emit_tab_cycle_next_smoke, root);
    deetty_grid_source_timeout_add(1650, emit_tab_cycle_previous_smoke, root);
    deetty_grid_source_timeout_add(1800, emit_tab_close_shortcut_smoke, root);
    deetty_grid_source_timeout_add(2000, emit_tab_reopen_shortcut_smoke, root);
    deetty_grid_source_timeout_add(2450, finish_tab_navigation_smoke, root);
    return G_SOURCE_REMOVE;
}

static DeettyGridContext *active_grid_context(DeettyGridContext *context) {
    DeettyGridContext *root = root_grid_context(context);
    if (root->notebook != NULL) {
        gint page_index = deetty_grid_notebook_get_current_page(GTK_NOTEBOOK(root->notebook));
        GtkWidget *page = deetty_grid_notebook_get_nth_page(GTK_NOTEBOOK(root->notebook),
                                                    page_index);
        for (guint index = 0; root->contexts != NULL &&
             index < root->contexts->len; index++) {
            DeettyGridContext *candidate = g_ptr_array_index(root->contexts, index);
            if (candidate->active && !candidate->exited &&
                candidate->area != NULL && candidate->page == page) return candidate;
        }
    }
    if (context != NULL && context->active && !context->exited &&
        context->area != NULL) return context;
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        DeettyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (candidate->active && !candidate->exited && candidate->area != NULL)
            return candidate;
    }
    return root;
}

static DeettyGridContext *focused_grid_context(DeettyGridContext *fallback) {
    DeettyGridContext *root = root_grid_context(fallback);
    if (root->contexts == NULL) return fallback;
    GtkWidget *focus = root->window != NULL
        ? deetty_grid_window_get_focus(GTK_WINDOW(root->window)) : NULL;
    if (focus != NULL) {
        for (guint index = 0; index < root->contexts->len; index++) {
            DeettyGridContext *candidate =
                g_ptr_array_index(root->contexts, index);
            if (candidate->active && !candidate->exited &&
                candidate->area == focus)
                return candidate;
        }
    }
    for (guint index = 0; index < root->contexts->len; index++) {
        DeettyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (candidate->active && candidate->focused && !candidate->exited) return candidate;
    }
    return active_grid_context(fallback);
}

static gboolean emit_workspace_smoke_split(gpointer user_data) {
    DeettyGridContext *context = user_data;
    emit_grid_workspace_event(focused_grid_context(context), DEETTY_GRID_HOST_EVENT(WORKSPACE_SPLIT));
    return G_SOURCE_REMOVE;
}

static gboolean emit_workspace_smoke_split_left(gpointer user_data) {
    DeettyGridContext *context = user_data;
    emit_grid_workspace_event(focused_grid_context(context), DEETTY_GRID_HOST_EVENT(WORKSPACE_SPLIT_ALT));
    return G_SOURCE_REMOVE;
}

static gboolean emit_workspace_smoke_balanced_split(gpointer user_data) {
    DeettyGridContext *root = user_data;
    DeettyGridContext *largest = NULL;
    gint largest_area = -1;
    for (guint index = 0; root->contexts != NULL && index < root->contexts->len; index++) {
        DeettyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (!candidate->active || candidate->exited ||
            deetty_grid_widget_get_parent(candidate->area) == NULL) continue;
        GtkAllocation allocation;
        deetty_grid_widget_get_allocation(candidate->area, &allocation);
        gint area = allocation.width * allocation.height;
        if (area > largest_area) {
            largest = candidate;
            largest_area = area;
        }
    }
    if (largest == NULL) return G_SOURCE_REMOVE;
    GtkAllocation allocation;
    deetty_grid_widget_get_allocation(largest->area, &allocation);
    emit_grid_workspace_event(largest,
                              allocation.width >= allocation.height
                                  ? DEETTY_GRID_HOST_EVENT(WORKSPACE_SPLIT_ALT)
                                  : DEETTY_GRID_HOST_EVENT(WORKSPACE_SPLIT));
    return G_SOURCE_REMOVE;
}

static gboolean check_resize_overlay_initially_hidden(gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    root->resize_overlay_smoke_initial_hidden =
        !root->resize_overlay_visible;
    return G_SOURCE_REMOVE;
}

static gboolean move_resize_overlay_divider(gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    GtkWidget *split = NULL;
    for (guint index = 0; root->contexts != NULL && index < root->contexts->len; index++) {
        DeettyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        GtkWidget *parent = deetty_grid_widget_get_parent(candidate->area);
        if (deetty_grid_widget_is_type(parent, DEETTY_GTK_PANED)) {
            split = parent;
            break;
        }
    }
    if (split == NULL) return G_SOURCE_REMOVE;
    GtkAllocation allocation;
    deetty_grid_widget_get_allocation(split, &allocation);
    GtkOrientation orientation = (GtkOrientation)
        deetty_grid_orientable_get_orientation(GTK_ORIENTABLE(split));
    gint extent = orientation == GTK_ORIENTATION_VERTICAL
        ? allocation.height
        : allocation.width;
    root->resize_overlay_smoke_moves++;
    gint numerator = root->resize_overlay_smoke_moves % 2 == 1 ? 1 : 2;
    deetty_paned_set_position(split, MAX(24, extent * numerator / 3));
    return G_SOURCE_REMOVE;
}

static gboolean check_resize_overlay_visible(gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    guint active = 0;
    gboolean visible = TRUE;
    gboolean realtime = TRUE;
    for (guint index = 0; root->contexts != NULL && index < root->contexts->len; index++) {
        DeettyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (!candidate->active || candidate->page != root->page) continue;
        active++;
        visible = visible && candidate->resize_overlay_visible &&
            candidate->resize_overlay_drawn &&
            candidate->resize_overlay_columns == candidate->columns &&
            candidate->resize_overlay_rows == candidate->rows;
        realtime = realtime && candidate->resize_overlay_update_count > 0;
    }
    root->resize_overlay_smoke_visible = active >= 2 && visible;
    root->resize_overlay_smoke_realtime = active >= 2 && realtime;
    return G_SOURCE_REMOVE;
}

static gboolean check_resize_overlay_hidden_and_finish(gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    guint active = 0;
    gboolean hidden = TRUE;
    for (guint index = 0; root->contexts != NULL && index < root->contexts->len; index++) {
        DeettyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (!candidate->active || candidate->page != root->page) continue;
        active++;
        hidden = hidden && !candidate->resize_overlay_visible &&
            candidate->resize_overlay_hidden;
        if (!candidate->exited)
            (void)candidate->write(candidate->userdata, "exit 0\n", 7);
    }
    root->resize_overlay_smoke_hidden = active >= 2 && hidden;
    return G_SOURCE_REMOVE;
}

static gboolean emit_workspace_smoke_broadcast(gpointer user_data) {
    DeettyGridContext *context = user_data;
    GdkEventKey event = {0};
    event.state = GDK_CONTROL_MASK | GDK_SHIFT_MASK;
    event.keyval = GDK_KEY_B;
    (void)on_key_press(context->area, &event, context);
    return G_SOURCE_REMOVE;
}

static gboolean emit_workspace_smoke_select(gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    if (root->event != NULL) root->event(root->event_data, root->pane_id, DEETTY_GRID_HOST_EVENT(BROADCAST_SELECTION), 0, (uint64_t)(g_get_monotonic_time() / 1000));
    DeettyGridContext *selected = grid_context_for_pane(root, 3);
    if (selected != NULL) update_compact_tab(selected);
    gchar *tooltip = selected != NULL && selected->tab_label != NULL
        ? deetty_grid_widget_get_tooltip_text(selected->tab_label) : NULL;
    root->selection_indicator_visible = tooltip != NULL &&
        strstr(tooltip, "selection group active") != NULL &&
        strstr(tooltip, "broadcast on") != NULL;
    deetty_grid_memory_free(tooltip);
    root->broadcast_state_label =
        g_strcmp0(deetty_grid_broadcast_menu_label(
                      root->event_data != NULL &&
                      deetty_grid_broadcast_enabled(root->event_data) != 0),
                  "Disable Broadcast Input") == 0;
    on_broadcast_menu_activate(NULL, root);
    if (root->event != NULL)
        root->event(root->event_data, root->pane_id, DEETTY_GRID_HOST_EVENT(WORKSPACE_BROADCAST), 0,
                    (uint64_t)(g_get_monotonic_time() / 1000));
    return G_SOURCE_REMOVE;
}

static gboolean emit_workspace_smoke_focus(gpointer user_data) {
    DeettyGridContext *context = user_data;
    if (context->event != NULL) context->event(context->event_data, context->pane_id, DEETTY_GRID_HOST_EVENT(WORKSPACE_FOCUS), 0, (uint64_t)(g_get_monotonic_time() / 1000));
    return G_SOURCE_REMOVE;
}

static gboolean emit_workspace_smoke_tag_filter(gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    if (root->event_data == NULL) return G_SOURCE_REMOVE;
    if (deetty_grid_tag_selected_panes(root->event_data, "ci", 2) != 0)
        return G_SOURCE_REMOVE;
    GtkWidget *suggestions = deetty_tag_combo_new();
    int suggestion_count = populate_tag_suggestions(root, GTK_COMBO_BOX_TEXT(suggestions));
    GtkTreeModel *suggestion_model = deetty_grid_combo_box_get_model(GTK_COMBO_BOX(suggestions));
    root->tag_suggestions_visible = suggestion_count == 1 &&
        deetty_grid_tree_model_iter_n_children(suggestion_model, NULL) == 1;
    deetty_grid_widget_destroy(suggestions);
    if (deetty_grid_set_smart_filter(root->event_data, "missing", 7) != 0)
        return G_SOURCE_REMOVE;
    root->smart_filter_tag = deetty_grid_memory_clear(root->smart_filter_tag);
    root->smart_filter_tag = g_strdup("missing");
    apply_smart_filter(root);
    root->tag_filter_empty_state_visible = root->smart_filter_empty_label != NULL &&
        deetty_grid_widget_get_visible(root->smart_filter_empty_label);
    root->tag_filter_empty_context = root->smart_filter_empty_label != NULL &&
        strstr(deetty_grid_label_get_text(GTK_LABEL(root->smart_filter_empty_label)), "missing") != NULL;
    if (root->smart_filter_empty_clear_button != NULL)
        deetty_grid_button_clicked(GTK_BUTTON(root->smart_filter_empty_clear_button));
    root->tag_filter_empty_clear = root->smart_filter_tag == NULL &&
        root->smart_filter_empty_box == NULL;
    if (deetty_grid_set_smart_filter(root->event_data, "missing", 7) != 0)
        return G_SOURCE_REMOVE;
    root->smart_filter_tag = deetty_grid_memory_clear(root->smart_filter_tag);
    root->smart_filter_tag = g_strdup("missing");
    apply_smart_filter(root);
    GdkEventKey escape_event = {0};
    escape_event.keyval = GDK_KEY_Escape;
    root->tag_filter_empty_escape = on_key_press(root->area, &escape_event, root) &&
        root->smart_filter_tag == NULL && root->smart_filter_empty_box == NULL;
    if (deetty_grid_set_smart_filter(root->event_data, "ci", 2) != 0)
        return G_SOURCE_REMOVE;
    root->smart_filter_tag = deetty_grid_memory_clear(root->smart_filter_tag);
    root->smart_filter_tag = g_strdup("ci");
    root->tag_filter_applied = 1;
    root->tag_filter_match = deetty_grid_pane_matches_smart_filter(
        root->event_data, 3) != 0;
    root->tag_filter_untagged_hidden = deetty_grid_pane_matches_smart_filter(
        root->event_data, 2) == 0;
    apply_smart_filter(root);
    root->tag_filter_indicator_visible = root->tab_label != NULL &&
        strstr(deetty_grid_label_get_text(GTK_LABEL(root->tab_label)), "ci") != NULL;
    DeettyGridContext *focused = focused_grid_context(root);
    root->tag_filter_focus_restored = focused != NULL && focused->pane_id == 3;
    if (deetty_grid_set_smart_filter(root->event_data, "", 0) == 0) {
        root->smart_filter_tag = deetty_grid_memory_clear(root->smart_filter_tag);
        root->tag_filter_cleared = deetty_grid_pane_matches_smart_filter(
            root->event_data, 2) != 0;
        apply_smart_filter(root);
    }
    return G_SOURCE_REMOVE;
}

static gboolean emit_workspace_smoke_move(gpointer user_data) {
    DeettyGridContext *context = user_data;
    DeettyGridContext *source = grid_context_for_pane(context, 3);
    if (source != NULL) emit_grid_workspace_event(source, DEETTY_GRID_HOST_EVENT(WORKSPACE_MOVE));
    return G_SOURCE_REMOVE;
}

static gboolean finish_workspace_smoke(gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    DeettyGridNativeHostPolicy policy = {0};
    deetty_grid_native_host_policy(&policy);
    DeettyGridContext *selected = grid_context_for_pane(root, 3);
    GtkWidget *pending_page = NULL;
    int window_width = 0;
    int window_height = 0;
    deetty_grid_window_get_size(GTK_WINDOW(root->window),
                        &window_width, &window_height);
    root->dropdown_minimum_geometry =
        window_width >= policy.dropdown_min_width_px &&
        window_height >= policy.dropdown_min_height_px;
    gboolean visual_ready = root->pane_move_applied &&
        root->selection_border_drawn && selected != NULL;
    for (guint index = 0;
         root->contexts != NULL && index < root->contexts->len; index++) {
        DeettyGridContext *candidate = g_ptr_array_index(
            root->contexts, index);
        if (!candidate->active || candidate->exited) continue;
        if (!candidate->saw_draw) {
            visual_ready = FALSE;
            pending_page = candidate->page;
            break;
        }
    }
    if (!root->selection_border_drawn && selected != NULL)
        pending_page = selected->page;
    if (!visual_ready && root->workspace_visual_attempts++ < 200) {
        if (pending_page != NULL) {
            gint page_index = deetty_grid_notebook_page_num(
                GTK_NOTEBOOK(root->notebook), pending_page);
            if (page_index >= 0)
                deetty_grid_notebook_select_page(root->notebook, page_index);
        }
        for (guint index = 0;
             root->contexts != NULL && index < root->contexts->len; index++) {
            DeettyGridContext *candidate = g_ptr_array_index(
                root->contexts, index);
            if (candidate->active && !candidate->exited &&
                candidate->page == pending_page && candidate->area != NULL)
                deetty_grid_widget_queue_draw(candidate->area);
        }
        deetty_grid_source_timeout_add(25, finish_workspace_smoke, root);
        return G_SOURCE_REMOVE;
    }
    root->workspace_visual_attempts = 0;
    if (selected != NULL && selected->page != NULL) {
        gint page_index = deetty_grid_notebook_page_num(
            GTK_NOTEBOOK(root->notebook), selected->page);
        if (page_index >= 0)
            deetty_grid_notebook_select_page(root->notebook, page_index);
        if (selected->area != NULL) deetty_grid_focus_widget(NULL, selected->area);
    }
    for (guint index = 0;
         root->contexts != NULL && index < root->contexts->len; index++) {
        DeettyGridContext *candidate = g_ptr_array_index(
            root->contexts, index);
        if (candidate->active && !candidate->exited)
            (void)candidate->write(candidate->userdata, "\n", 1);
    }
    return G_SOURCE_REMOVE;
}

static gboolean emit_workspace_smoke_move_last_pane(gpointer user_data) {
    DeettyGridContext *context = focused_grid_context(user_data);
    emit_grid_workspace_event(context, DEETTY_GRID_HOST_EVENT(WORKSPACE_MOVE));
    return G_SOURCE_REMOVE;
}

static gboolean finish_grid_hide(gpointer user_data) {
    DeettyGridContext *root = user_data;
    root->hide_source = 0;
    deetty_grid_widget_hide(root->window);
    return G_SOURCE_REMOVE;
}

static gboolean retain_xdg_activation_token_bytes(
    DeettyGridContext *context, const gchar *token, gsize length) {
    DeettyGridContext *root = root_grid_context(context);
    if (deetty_grid_text_valid((const uint8_t *)token, length, 4096) == 0)
        return FALSE;
    gchar *owned = g_strndup(token, length);
    if (owned == NULL) return FALSE;
    deetty_grid_memory_free(root->xdg_activation_token);
    root->xdg_activation_token = owned;
    root->xdg_activation_token_received = 1;
    return TRUE;
}

static gboolean retain_xdg_activation_token(DeettyGridContext *context,
                                             const gchar *token) {
    return token != NULL && retain_xdg_activation_token_bytes(
        context, token, strlen(token));
}

static void clear_xdg_activation_token(DeettyGridContext *context) {
    DeettyGridContext *root = root_grid_context(context);
    root->xdg_activation_token = deetty_grid_memory_clear(root->xdg_activation_token);
}

static void apply_xdg_activation_token(DeettyGridContext *context) {
    DeettyGridContext *root = root_grid_context(context);
    if (root->xdg_activation_token == NULL ||
        !deetty_grid_widget_is_type(root->window, DEETTY_GTK_WINDOW)) return;
    deetty_grid_window_set_startup_id(
        root->window, root->xdg_activation_token);
    root->xdg_activation_token_applied = 1;
    if (g_getenv("DEETTY_DEBUG_ACTIVATION") != NULL)
        g_printerr("deetty_xdg_activation applied=true backend=%s\n",
                   deetty_grid_gdk_default_display_is_wayland()
                       ? "wayland" : "x11");
    clear_xdg_activation_token(root);
}

static void toggle_grid_window(DeettyGridContext *context) {
    DeettyGridContext *root = root_grid_context(context);
    gboolean visible = deetty_grid_widget_is_type(root->window, DEETTY_GTK_WIDGET) &&
        !deetty_grid_widget_in_destruction(root->window) &&
        deetty_grid_widget_get_visible(root->window);
    DeettyGridWindowVisibilityPlan visibility_plan = {0};
    deetty_grid_window_visibility_plan(root->window_presented, visible ? 1 : 0, &visibility_plan);
    DeettyGridLifecycleTimingPlan timing = {0};
    deetty_grid_lifecycle_timing_plan(&timing);
    if (visibility_plan.action == DEETTY_GRID_WINDOW_VISIBILITY_HIDE) {
        clear_xdg_activation_token(root);
        set_grid_layer_keyboard_active(root, FALSE);
        hide_quick_note_overlays(root);
        dismiss_grid_popup_windows(root);
        root->window_presented = 0;
        guint dogfood_omp_count = dogfood_active_omp_count(root);
        if (dogfood_omp_count >= 4) {
            root->dogfood_omp_hidden_count = dogfood_omp_count;
            root->dogfood_omp_hide_seen = 1;
            emit_dogfood_event(root, "omp_hide", 0,
                               (int)dogfood_omp_count, "active");
        }
        GtkWidget *grab = deetty_grid_grab_get_current();
        if (grab != NULL && deetty_grid_widget_is_type(grab, DEETTY_GTK_MENU)) {
            deetty_grid_menu_popdown(GTK_MENU(grab));
        }
        if (root->revealer != NULL && root->dropdown_animation_ms > 0) {
            deetty_grid_revealer_set_reveal_child(GTK_REVEALER(root->revealer), FALSE);
            if (root->hide_source != 0) deetty_grid_source_remove(root->hide_source);
            root->hide_source = deetty_grid_source_timeout_add((guint)root->dropdown_animation_ms,
                                              finish_grid_hide, root);
        } else if (root->layer_shell_active) {
            if (root->hide_source != 0) deetty_grid_source_remove(root->hide_source);
            // Give keyboard-interactivity NONE one frame to commit before
            // unmapping the layer surface, avoiding a combined KWin focus and
            // surface-destroy transition on the cold path.
            root->hide_source = deetty_grid_source_timeout_add(
                (guint)timing.layer_surface_hide_commit_ms,
                finish_grid_hide, root);
        } else deetty_grid_widget_hide(root->window);
    } else {
        set_grid_layer_keyboard_active(root, TRUE);
        root->window_presented = 1;
        apply_xdg_activation_token(root);
        if (root->hide_source != 0) {
            deetty_grid_source_remove(root->hide_source);
            root->hide_source = 0;
        }
        show_all_with_action_affordances(root->window);
        if (root->revealer != NULL)
            deetty_grid_revealer_set_reveal_child(GTK_REVEALER(root->revealer), TRUE);
        if (!root->layer_shell_active)
            deetty_grid_window_present(root->window);
        schedule_resolution_adapt(root);
        DeettyGridContext *focus_target = active_grid_context(context);
        if (focus_target->area != NULL)
            deetty_grid_focus_widget(NULL, focus_target->area);
        guint dogfood_omp_count = dogfood_active_omp_count(root);
        if (root->dogfood_omp_hide_seen &&
            root->dogfood_omp_hidden_count >= 4 &&
            dogfood_omp_count >= 4 &&
            !root->dogfood_omp_hide_show_seen) {
            root->dogfood_omp_hide_show_seen = 1;
            emit_dogfood_event(root, "omp_show_after_hide", 0,
                               (int)dogfood_omp_count, "active");
        }
    }
    emit_grid_tray_tooltip(root);
    emit_grid_tray_menu_layout(root);
}

static const char deetty_control_xml[] =
    "<node>"
    " <interface name='com.deetty.DEETTY.Control'>"
    "  <method name='Toggle'><arg type='b' name='visible' direction='out'/></method>"
    "  <method name='ToggleWithActivation'><arg type='s' name='token' direction='in'/><arg type='b' name='visible' direction='out'/></method>"
    "  <method name='Show'><arg type='b' name='visible' direction='out'/></method>"
    "  <method name='ShowWithActivation'><arg type='s' name='token' direction='in'/><arg type='b' name='visible' direction='out'/></method>"
    "  <method name='Hide'><arg type='b' name='visible' direction='out'/></method>"
    "  <method name='GetState'><arg type='b' name='visible' direction='out'/></method>"
    " </interface>"
    "</node>";

static gboolean finish_grid_control_smoke(gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    if (root->write != NULL && !root->exited)
        (void)root->write(root->userdata, "done\n", 5);
    return G_SOURCE_REMOVE;
}

static void on_control_method_call(GDBusConnection *connection,
                                   const gchar *sender,
                                   const gchar *object_path,
                                   const gchar *interface_name,
                                   const gchar *method_name,
                                   GVariant *parameters,
                                   GDBusMethodInvocation *invocation,
                                   gpointer user_data) {
    (void)connection; (void)sender; (void)object_path; (void)interface_name;
    DeettyGridContext *root = root_grid_context(user_data);
    gboolean visible = root->window_presented;
    gboolean activated_toggle =
        g_strcmp0(method_name, "ToggleWithActivation") == 0;
    gboolean activated_show =
        g_strcmp0(method_name, "ShowWithActivation") == 0;
    if (activated_toggle || activated_show) {
        const gchar *token = NULL;
        g_variant_get(parameters, "(&s)", &token);
        gboolean will_show = !visible;
        if (will_show && !retain_xdg_activation_token(root, token)) {
            g_dbus_method_invocation_return_error(
                invocation, G_DBUS_ERROR, G_DBUS_ERROR_INVALID_ARGS,
                "Invalid or oversized XDG activation token");
            return;
        }
    }
    if (g_strcmp0(method_name, "Toggle") == 0 || activated_toggle) {
        root->control_toggle_seen = 1;
        if (visible) clear_xdg_activation_token(root);
        toggle_grid_window(root);
        visible = !visible;
    } else if (g_strcmp0(method_name, "Show") == 0 || activated_show) {
        root->control_show_seen = 1;
        if (!visible) toggle_grid_window(root);
        else clear_xdg_activation_token(root);
        visible = TRUE;
    } else if (g_strcmp0(method_name, "Hide") == 0) {
        root->control_hide_seen = 1;
        if (visible) toggle_grid_window(root);
        visible = FALSE;
    } else if (g_strcmp0(method_name, "GetState") == 0) {
        root->control_status_seen = 1;
        root->control_status_count++;
    } else {
        g_dbus_method_invocation_return_error(invocation, G_DBUS_ERROR,
                                              G_DBUS_ERROR_UNKNOWN_METHOD,
                                              "Unknown DEETTY control method");
        return;
    }
    g_dbus_method_invocation_return_value(invocation,
                                          g_variant_new("(b)", visible));
    if (root->workspace_smoke == 16 && root->control_status_count == 2 &&
        root->control_show_seen && root->control_hide_seen &&
        root->control_toggle_seen)
        deetty_grid_source_idle_add(finish_grid_control_smoke, root);
}

static const GDBusInterfaceVTable deetty_control_vtable = {
    on_control_method_call,
    NULL,
    NULL,
    {0},
};

static void begin_grid_dbus_operation(DeettyGridContext *context) {
    root_grid_context(context)->dbus_pending_operations++;
}

static void finish_grid_dbus_operation(DeettyGridContext *context) {
    DeettyGridContext *root = root_grid_context(context);
    if (root->dbus_pending_operations > 0) root->dbus_pending_operations--;
}

static void cancel_grid_dbus_operations(DeettyGridContext *context) {
    DeettyGridContext *root = root_grid_context(context);
    if (root->dbus_cancellable != NULL)
        g_cancellable_cancel(root->dbus_cancellable);
    while (root->dbus_pending_operations > 0)
        deetty_grid_main_context_iteration(TRUE);
    root->dbus_cancellable = deetty_grid_object_clear(root->dbus_cancellable);
}

static void drain_grid_dbus_operations(DeettyGridContext *context) {
    DeettyGridContext *root = root_grid_context(context);
    DeettyGridLifecycleTimingPlan timing = {0};
    deetty_grid_lifecycle_timing_plan(&timing);
    gint64 deadline = g_get_monotonic_time() +
        (gint64)timing.dbus_drain_ms * 1000;
    while (root->dbus_pending_operations > 0 &&
           g_get_monotonic_time() < deadline) {
        while (deetty_grid_main_context_iteration(FALSE)) {}
        if (root->dbus_pending_operations > 0)
            g_usleep((gulong)timing.dbus_poll_us);
    }
}

static void on_grid_control_name_requested(GObject *source,
                                           GAsyncResult *result,
                                           gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    DeettyGridLifecycleTimingPlan timing = {0};
    deetty_grid_lifecycle_timing_plan(&timing);
    GError *error = NULL;
    GVariant *reply = g_dbus_connection_call_finish(
        G_DBUS_CONNECTION(source), result, &error);
    if (reply != NULL) {
        guint32 request_result = 0;
        DeettyGridControlNameRequestPlan request_plan = {0};
        g_variant_get(reply, "(u)", &request_result);
        deetty_grid_control_name_request_plan(
            (int)request_result, &request_plan);
        root->control_registered = request_plan.registered != 0;
        root->control_name_conflict = request_plan.conflict != 0;
        if (g_getenv("DEETTY_DEBUG_CONTROL_OWNERSHIP") != NULL)
            g_printerr("deetty_control_ownership pid=%ld result=%u owner=%d conflict=%d\n",
                       (long)getpid(), request_result,
                       root->control_registered, root->control_name_conflict);
        deetty_grid_variant_unref(reply);
    }
    deetty_grid_error_clear(&error);
    if (root->control_name_conflict && root->show_on_control_conflict) {
        GVariant *forwarded = g_dbus_connection_call_sync(
            root->control_bus, "com.deetty.DEETTY", "/com/deetty/DEETTY",
            "com.deetty.DEETTY.Control", "Show", NULL,
            G_VARIANT_TYPE("(b)"), G_DBUS_CALL_FLAGS_NONE,
            timing.dbus_call_timeout_ms, NULL, NULL);
        if (forwarded != NULL) {
            root->control_conflict_forwarded = 1;
            deetty_grid_variant_unref(forwarded);
        }
    }
    if (root->control_registered && root->shortcut_transport == 2 &&
        root->mode == 0 && root->workspace_smoke == 16)
        (void)g_file_set_contents("/tmp/deetty-noctalia-control-ready",
                                  "ready\n", -1, NULL);
    finish_grid_dbus_operation(root);
}

static void on_grid_control_bus_ready(GObject *source, GAsyncResult *result,
                                      gpointer user_data) {
    (void)source;
    DeettyGridContext *root = root_grid_context(user_data);
    DeettyGridLifecycleTimingPlan timing = {0};
    deetty_grid_lifecycle_timing_plan(&timing);
    GError *error = NULL;
    root->control_bus = g_bus_get_finish(result, &error);
    if (root->control_bus == NULL) goto failed;
    root->control_node = g_dbus_node_info_new_for_xml(deetty_control_xml,
                                                       &error);
    if (root->control_node == NULL) goto failed;
    root->control_object_id = g_dbus_connection_register_object(
        root->control_bus, "/com/deetty/DEETTY",
        root->control_node->interfaces[0], &deetty_control_vtable, root, NULL,
        &error);
    if (root->control_object_id == 0) goto failed;
    g_dbus_connection_call(
        root->control_bus, "org.freedesktop.DBus", "/org/freedesktop/DBus",
        "org.freedesktop.DBus", "RequestName",
        g_variant_new("(su)", "com.deetty.DEETTY", 4u),
        G_VARIANT_TYPE("(u)"), G_DBUS_CALL_FLAGS_NONE,
        timing.dbus_call_timeout_ms,
        root->dbus_cancellable, on_grid_control_name_requested, root);
    return;

failed:
    deetty_grid_error_clear(&error);
    finish_grid_dbus_operation(root);
}

static void unregister_grid_control(DeettyGridContext *context) {
    DeettyGridContext *root = root_grid_context(context);
    DeettyGridLifecycleTimingPlan timing = {0};
    deetty_grid_lifecycle_timing_plan(&timing);
    if (root->control_bus == NULL) return;
    if (root->control_object_id != 0) {
        g_dbus_connection_unregister_object(root->control_bus,
                                            root->control_object_id);
        root->control_object_id = 0;
    }
    g_dbus_connection_call(
        root->control_bus, "org.freedesktop.DBus", "/org/freedesktop/DBus",
        "org.freedesktop.DBus", "ReleaseName",
        g_variant_new("(s)", "com.deetty.DEETTY"), G_VARIANT_TYPE("(u)"),
        G_DBUS_CALL_FLAGS_NONE, timing.dbus_call_timeout_ms,
        NULL, NULL, NULL);
    g_clear_pointer(&root->control_node, g_dbus_node_info_unref);
    root->control_bus = deetty_grid_object_clear(root->control_bus);
    root->control_registered = 0;
}

static int register_grid_control(DeettyGridContext *context) {
    DeettyGridContext *root = root_grid_context(context);
    begin_grid_dbus_operation(root);
    g_bus_get(G_BUS_TYPE_SESSION, root->dbus_cancellable,
              on_grid_control_bus_ready, root);
    return 1;
}

static gboolean quit_control_name_conflict(gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    root->window_presented = 0;
    deetty_grid_main_quit();
    return G_SOURCE_REMOVE;
}

static const char deetty_tray_xml[] =
    "<node>"
    " <interface name='org.kde.StatusNotifierItem'>"
    "  <method name='ProvideXdgActivationToken'><arg type='s' name='token' direction='in'/></method>"
    "  <method name='ContextMenu'><arg type='i' name='x' direction='in'/><arg type='i' name='y' direction='in'/></method>"
    "  <method name='Activate'><arg type='i' name='x' direction='in'/><arg type='i' name='y' direction='in'/></method>"
    "  <method name='SecondaryActivate'><arg type='i' name='x' direction='in'/><arg type='i' name='y' direction='in'/></method>"
    "  <method name='Scroll'><arg type='i' name='delta' direction='in'/><arg type='s' name='orientation' direction='in'/></method>"
    "  <property name='Category' type='s' access='read'/>"
    "  <property name='Id' type='s' access='read'/>"
    "  <property name='Title' type='s' access='read'/>"
    "  <property name='Status' type='s' access='read'/>"
    "  <property name='WindowId' type='i' access='read'/>"
    "  <property name='IconThemePath' type='s' access='read'/>"
    "  <property name='Menu' type='o' access='read'/>"
    "  <property name='ItemIsMenu' type='b' access='read'/>"
    "  <property name='IconName' type='s' access='read'/>"
    "  <property name='IconPixmap' type='a(iiay)' access='read'/>"
    "  <property name='OverlayIconName' type='s' access='read'/>"
    "  <property name='OverlayIconPixmap' type='a(iiay)' access='read'/>"
    "  <property name='AttentionIconName' type='s' access='read'/>"
    "  <property name='AttentionIconPixmap' type='a(iiay)' access='read'/>"
    "  <property name='AttentionMovieName' type='s' access='read'/>"
    "  <property name='ToolTip' type='(sa(iiay)ss)' access='read'/>"
    "  <signal name='NewTitle'/>"
    "  <signal name='NewIcon'/>"
    "  <signal name='NewAttentionIcon'/>"
    "  <signal name='NewOverlayIcon'/>"
    "  <signal name='NewMenu'/>"
    "  <signal name='NewToolTip'/>"
    "  <signal name='NewStatus'><arg type='s' name='status'/></signal>"
    " </interface>"
    "</node>";

static const char deetty_tray_menu_xml[] =
    "<node>"
    " <interface name='com.canonical.dbusmenu'>"
    "  <property name='Version' type='u' access='read'/>"
    "  <property name='Status' type='s' access='read'/>"
    "  <method name='GetLayout'>"
    "   <arg type='i' name='parentId' direction='in'/>"
    "   <arg type='i' name='recursionDepth' direction='in'/>"
    "   <arg type='as' name='propertyNames' direction='in'/>"
    "   <arg type='u' name='revision' direction='out'/>"
    "   <arg type='(ia{sv}av)' name='layout' direction='out'/>"
    "  </method>"
    "  <method name='GetGroupProperties'>"
    "   <arg type='ai' name='ids' direction='in'/>"
    "   <arg type='as' name='propertyNames' direction='in'/>"
    "   <arg type='a(ia{sv})' name='properties' direction='out'/>"
    "  </method>"
    "  <method name='GetProperty'>"
    "   <arg type='i' name='id' direction='in'/>"
    "   <arg type='s' name='property' direction='in'/>"
    "   <arg type='v' name='value' direction='out'/>"
    "  </method>"
    "  <method name='Event'>"
    "   <annotation name='org.freedesktop.DBus.Method.NoReply' value='true'/>"
    "   <arg type='i' name='id' direction='in'/>"
    "   <arg type='s' name='eventId' direction='in'/>"
    "   <arg type='v' name='data' direction='in'/>"
    "   <arg type='u' name='timestamp' direction='in'/>"
    "  </method>"
    "  <method name='AboutToShow'>"
    "   <arg type='i' name='id' direction='in'/>"
    "   <arg type='b' name='needUpdate' direction='out'/>"
    "  </method>"
    "  <signal name='ItemsPropertiesUpdated'>"
    "   <arg type='a(ia{sv})' name='updatedProps'/>"
    "   <arg type='a(ias)' name='removedProps'/>"
    "  </signal>"
    "  <signal name='LayoutUpdated'>"
    "   <arg type='u' name='revision'/>"
    "   <arg type='i' name='parentId'/>"
    "  </signal>"
    "  <signal name='ItemActivationRequested'>"
    "   <arg type='i' name='id'/>"
    "   <arg type='u' name='timestamp'/>"
    "  </signal>"
    " </interface>"
    "</node>";

enum {
    DEETTY_TRAY_MENU_ROOT = 0,
    DEETTY_TRAY_MENU_TOGGLE = 1,
    DEETTY_TRAY_MENU_SETTINGS = 2,
    DEETTY_TRAY_MENU_SEPARATOR = 3,
    DEETTY_TRAY_MENU_CLOSE = 4,
};

static GVariant *new_empty_grid_tray_pixmaps(void) {
    GVariantBuilder builder;
    g_variant_builder_init(&builder, G_VARIANT_TYPE("a(iiay)"));
    return g_variant_builder_end(&builder);
}



static GVariant *new_grid_tray_menu_properties(DeettyGridContext *root,
                                                gint32 id) {
    DeettyGridTrayMenuItemPlan plan = {0};
    deetty_grid_tray_menu_plan(id, &plan);
    GVariantBuilder properties;
    g_variant_builder_init(&properties, G_VARIANT_TYPE("a{sv}"));
    if (plan.valid == 0) return g_variant_builder_end(&properties);
    if (plan.kind == DEETTY_GRID_TRAY_MENU_KIND_ROOT) {
        g_variant_builder_add(&properties, "{sv}", "children-display",
                              g_variant_new_string("submenu"));
    } else if (plan.kind == DEETTY_GRID_TRAY_MENU_KIND_SEPARATOR) {
        g_variant_builder_add(&properties, "{sv}", "type",
                              g_variant_new_string("separator"));
    } else {
        g_variant_builder_add(&properties, "{sv}", "label",
                              g_variant_new_string(
                                  deetty_grid_tray_menu_label(id, root->window_presented)));
        g_variant_builder_add(&properties, "{sv}", "icon-name",
                              g_variant_new_string(
                                  deetty_grid_tray_menu_icon_name(id)));
    }
    return g_variant_builder_end(&properties);
}

static GVariant *new_grid_tray_menu_layout(DeettyGridContext *root,
                                            gint32 id,
                                            gint32 recursion_depth) {
    DeettyGridTrayMenuItemPlan plan = {0};
    deetty_grid_tray_menu_plan(id, &plan);
    GVariantBuilder children;
    g_variant_builder_init(&children, G_VARIANT_TYPE("av"));
    if (plan.has_children != 0 && recursion_depth != 0) {
        const gint32 child_ids[] = {
            DEETTY_TRAY_MENU_TOGGLE,
            DEETTY_TRAY_MENU_SETTINGS,
            DEETTY_TRAY_MENU_SEPARATOR,
            DEETTY_TRAY_MENU_CLOSE,
        };
        gint32 child_depth = recursion_depth > 0 ? recursion_depth - 1
                                                 : recursion_depth;
        for (guint index = 0; index < G_N_ELEMENTS(child_ids); index++) {
            GVariant *child = new_grid_tray_menu_layout(
                root, child_ids[index], child_depth);
            g_variant_builder_add_value(&children,
                                        g_variant_new_variant(child));
        }
    }
    return g_variant_new("(i@a{sv}@av)", id,
                         new_grid_tray_menu_properties(root, id),
                         g_variant_builder_end(&children));
}


static GVariant *new_grid_tray_menu_property(DeettyGridContext *root,
                                              gint32 id,
                                              const char *name) {
    DeettyGridTrayMenuItemPlan plan = {0};
    deetty_grid_tray_menu_plan(id, &plan);
    if (plan.valid == 0) return NULL;
    if (g_strcmp0(name, "label") == 0)
        return g_variant_new_string(deetty_grid_tray_menu_label(id, root->window_presented));
    if (g_strcmp0(name, "icon-name") == 0)
        return g_variant_new_string(deetty_grid_tray_menu_icon_name(id));
    if (g_strcmp0(name, "type") == 0)
        return g_variant_new_string(plan.kind == DEETTY_GRID_TRAY_MENU_KIND_SEPARATOR
                                        ? "separator"
                                        : "standard");
    if (g_strcmp0(name, "children-display") == 0)
        return g_variant_new_string(plan.has_children != 0 ? "submenu" : "");
    if (g_strcmp0(name, "enabled") == 0 ||
        g_strcmp0(name, "visible") == 0)
        return g_variant_new_boolean(TRUE);
    return NULL;
}

static GVariant *on_grid_tray_menu_get_property(
    GDBusConnection *connection, const gchar *sender,
    const gchar *object_path, const gchar *interface_name,
    const gchar *property_name, GError **error, gpointer user_data) {
    (void)connection; (void)sender; (void)object_path; (void)interface_name;
    (void)user_data;
    if (g_strcmp0(property_name, "Version") == 0)
        return g_variant_new_uint32(2);
    if (g_strcmp0(property_name, "Status") == 0)
        return g_variant_new_string("normal");
    g_set_error(error, G_IO_ERROR, G_IO_ERROR_NOT_SUPPORTED,
                "Unknown D-Bus menu property: %s", property_name);
    return NULL;
}

static void on_grid_tray_menu_method_call(
    GDBusConnection *connection, const gchar *sender,
    const gchar *object_path, const gchar *interface_name,
    const gchar *method_name, GVariant *parameters,
    GDBusMethodInvocation *invocation, gpointer user_data) {
    (void)connection; (void)sender; (void)object_path; (void)interface_name;
    DeettyGridContext *root = root_grid_context(user_data);
    if (g_strcmp0(method_name, "GetLayout") == 0) {
        gint32 parent_id = 0;
        gint32 recursion_depth = 0;
        GVariant *property_names = NULL;
        g_variant_get(parameters, "(ii@as)", &parent_id, &recursion_depth,
                      &property_names);
        deetty_grid_variant_unref(property_names);
        if (!deetty_grid_tray_menu_id_valid(parent_id)) {
            g_dbus_method_invocation_return_error(
                invocation, G_DBUS_ERROR, G_DBUS_ERROR_INVALID_ARGS,
                "Unknown tray menu item: %d", parent_id);
            return;
        }
        root->tray_menu_layout_seen = 1;
        g_dbus_method_invocation_return_value(
            invocation,
            g_variant_new("(u@(ia{sv}av))", root->tray_menu_revision,
                          new_grid_tray_menu_layout(root, parent_id,
                                                    recursion_depth)));
        return;
    }
    if (g_strcmp0(method_name, "GetGroupProperties") == 0) {
        GVariant *ids = NULL;
        GVariant *property_names = NULL;
        g_variant_get(parameters, "(@ai@as)", &ids, &property_names);
        GVariantBuilder properties;
        g_variant_builder_init(&properties, G_VARIANT_TYPE("a(ia{sv})"));
        GVariantIter iterator;
        gint32 id = 0;
        g_variant_iter_init(&iterator, ids);
        while (g_variant_iter_next(&iterator, "i", &id)) {
            if (!deetty_grid_tray_menu_id_valid(id)) continue;
            g_variant_builder_add(&properties, "(i@a{sv})", id,
                                  new_grid_tray_menu_properties(root, id));
        }
        deetty_grid_variant_unref(ids);
        deetty_grid_variant_unref(property_names);
        g_dbus_method_invocation_return_value(
            invocation,
            g_variant_new("(@a(ia{sv}))",
                          g_variant_builder_end(&properties)));
        return;
    }
    if (g_strcmp0(method_name, "GetProperty") == 0) {
        gint32 id = 0;
        const gchar *name = NULL;
        g_variant_get(parameters, "(i&s)", &id, &name);
        GVariant *value = new_grid_tray_menu_property(root, id, name);
        if (value == NULL) {
            g_dbus_method_invocation_return_error(
                invocation, G_DBUS_ERROR, G_DBUS_ERROR_INVALID_ARGS,
                "Unknown tray menu property '%s' for item %d", name, id);
            return;
        }
        g_dbus_method_invocation_return_value(
            invocation, g_variant_new("(v)", value));
        return;
    }
    if (g_strcmp0(method_name, "Event") == 0) {
        gint32 id = 0;
        const gchar *event_id = NULL;
        GVariant *data = NULL;
        guint32 timestamp = 0;
        g_variant_get(parameters, "(i&s@vu)", &id, &event_id, &data,
                      &timestamp);
        (void)timestamp;
        deetty_grid_variant_unref(data);
        if (g_strcmp0(event_id, "clicked") == 0) {
            DeettyGridTrayMenuItemPlan plan = {0};
            deetty_grid_tray_menu_plan(id, &plan);
            switch (plan.action) {
                case DEETTY_GRID_TRAY_MENU_ACTION_TOGGLE:
                    toggle_grid_window(root);
                    break;
                case DEETTY_GRID_TRAY_MENU_ACTION_SETTINGS:
                    if (!root->window_presented) toggle_grid_window(root);
                    open_grid_settings(root);
                    break;
                case DEETTY_GRID_TRAY_MENU_ACTION_CLOSE:
                    root->tray_close_seen = 1;
                    (void)request_grid_application_close(
                        root, DEETTY_CLOSE_ORIGIN_TRAY);
                    break;
                default:
                    break;
            }
        }
        g_dbus_method_invocation_return_value(invocation, NULL);
        return;
    }
    if (g_strcmp0(method_name, "AboutToShow") == 0) {
        gint32 id = 0;
        g_variant_get(parameters, "(i)", &id);
        (void)id;
        g_dbus_method_invocation_return_value(
            invocation, g_variant_new("(b)", FALSE));
        return;
    }
    g_dbus_method_invocation_return_error(
        invocation, G_DBUS_ERROR, G_DBUS_ERROR_UNKNOWN_METHOD,
        "Unknown D-Bus menu method");
}

static const GDBusInterfaceVTable deetty_tray_menu_vtable = {
    on_grid_tray_menu_method_call,
    on_grid_tray_menu_get_property,
    NULL,
    {0},
};

static GVariant *on_grid_tray_get_property(
    GDBusConnection *connection, const gchar *sender,
    const gchar *object_path, const gchar *interface_name,
    const gchar *property_name, GError **error, gpointer user_data) {
    (void)connection; (void)sender; (void)object_path; (void)interface_name;
    DeettyGridContext *root = root_grid_context(user_data);
    if (g_strcmp0(property_name, "Category") == 0)
        return g_variant_new_string("ApplicationStatus");
    if (g_strcmp0(property_name, "Id") == 0)
        return g_variant_new_string("deetty");
    if (g_strcmp0(property_name, "Title") == 0)
        return g_variant_new_string("DEETTY");
    if (g_strcmp0(property_name, "Status") == 0)
        return g_variant_new_string("Active");
    if (g_strcmp0(property_name, "WindowId") == 0)
        return g_variant_new_int32(0);
    if (g_strcmp0(property_name, "IconThemePath") == 0)
        return g_variant_new_string("");
    if (g_strcmp0(property_name, "Menu") == 0)
        return g_variant_new_object_path("/MenuBar");
    if (g_strcmp0(property_name, "ItemIsMenu") == 0)
        return g_variant_new_boolean(FALSE);
    if (g_strcmp0(property_name, "IconName") == 0)
        return g_variant_new_string("com.deetty.DEETTY");
    if (g_strcmp0(property_name, "IconPixmap") == 0)
        return root->tray_icon_pixmaps != NULL
            ? deetty_grid_variant_ref(root->tray_icon_pixmaps)
            : new_empty_grid_tray_pixmaps();
    if (g_strcmp0(property_name, "OverlayIconName") == 0 ||
        g_strcmp0(property_name, "AttentionIconName") == 0 ||
        g_strcmp0(property_name, "AttentionMovieName") == 0)
        return g_variant_new_string("");
    if (g_strcmp0(property_name, "OverlayIconPixmap") == 0 ||
        g_strcmp0(property_name, "AttentionIconPixmap") == 0)
        return new_empty_grid_tray_pixmaps();
    if (g_strcmp0(property_name, "ToolTip") == 0) {
        GVariant *pixmaps = root->tray_icon_pixmaps != NULL
            ? deetty_grid_variant_ref(root->tray_icon_pixmaps)
            : new_empty_grid_tray_pixmaps();
        return g_variant_new(
            "(s@a(iiay)ss)", "com.deetty.DEETTY", pixmaps, "DEETTY",
            root->window_presented
                ? "Terminal window is visible"
                : "Click to show the terminal window");
    }
    g_set_error(error, G_IO_ERROR, G_IO_ERROR_NOT_SUPPORTED,
                "Unknown StatusNotifierItem property: %s", property_name);
    return NULL;
}

static void on_grid_tray_method_call(
    GDBusConnection *connection, const gchar *sender,
    const gchar *object_path, const gchar *interface_name,
    const gchar *method_name, GVariant *parameters,
    GDBusMethodInvocation *invocation, gpointer user_data) {
    (void)connection; (void)sender; (void)object_path; (void)interface_name;
    DeettyGridContext *root = root_grid_context(user_data);
    if (g_strcmp0(method_name, "ProvideXdgActivationToken") == 0) {
        const gchar *token = NULL;
        g_variant_get(parameters, "(&s)", &token);
        if (!retain_xdg_activation_token(root, token)) {
            g_dbus_method_invocation_return_error(
                invocation, G_DBUS_ERROR, G_DBUS_ERROR_INVALID_ARGS,
                "Invalid or oversized XDG activation token");
            return;
        }
    } else if (g_strcmp0(method_name, "Activate") == 0) {
        root->tray_activation_count++;
        if (root->window_presented) clear_xdg_activation_token(root);
        toggle_grid_window(root);
    } else if (g_strcmp0(method_name, "SecondaryActivate") == 0) {
        root->tray_secondary_seen = 1;
        if (!root->window_presented) toggle_grid_window(root);
        open_grid_settings(root);
    } else if (g_strcmp0(method_name, "ContextMenu") == 0) {
        root->tray_context_seen = 1;
    } else if (g_strcmp0(method_name, "Scroll") != 0 &&
               g_strcmp0(method_name, "ProvideXdgActivationToken") != 0) {
        g_dbus_method_invocation_return_error(
            invocation, G_DBUS_ERROR, G_DBUS_ERROR_UNKNOWN_METHOD,
            "Unknown StatusNotifierItem method");
        return;
    }
    g_dbus_method_invocation_return_value(invocation, NULL);
}

static const GDBusInterfaceVTable deetty_tray_vtable = {
    on_grid_tray_method_call,
    on_grid_tray_get_property,
    NULL,
    {0},
};

static void on_grid_tray_watcher_registered(GObject *source,
                                             GAsyncResult *result,
                                             gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    GError *error = NULL;
    GVariant *reply = g_dbus_connection_call_finish(
        G_DBUS_CONNECTION(source), result, &error);
    root->tray_watcher_registered = reply != NULL;
    if (reply != NULL) deetty_grid_variant_unref(reply);
    deetty_grid_error_clear(&error);
    finish_grid_dbus_operation(root);
}

static int register_grid_tray_watcher(DeettyGridContext *context) {
    DeettyGridContext *root = root_grid_context(context);
    DeettyGridLifecycleTimingPlan timing = {0};
    deetty_grid_lifecycle_timing_plan(&timing);
    if (root->tray_bus == NULL || root->tray_object_id == 0) return 0;
    begin_grid_dbus_operation(root);
    g_dbus_connection_call(
        root->tray_bus, "org.kde.StatusNotifierWatcher",
        "/StatusNotifierWatcher", "org.kde.StatusNotifierWatcher",
        "RegisterStatusNotifierItem", g_variant_new("(s)",
        "/StatusNotifierItem"), NULL, G_DBUS_CALL_FLAGS_NONE,
        timing.dbus_call_timeout_ms,
        root->dbus_cancellable, on_grid_tray_watcher_registered, root);
    return 1;
}

static void on_grid_tray_watcher_owner_changed(
    GDBusConnection *connection, const gchar *sender_name,
    const gchar *object_path, const gchar *interface_name,
    const gchar *signal_name, GVariant *parameters, gpointer user_data) {
    (void)connection; (void)sender_name; (void)object_path;
    (void)interface_name; (void)signal_name;
    DeettyGridContext *root = root_grid_context(user_data);
    const gchar *name = NULL;
    const gchar *old_owner = NULL;
    const gchar *new_owner = NULL;
    g_variant_get(parameters, "(&s&s&s)", &name, &old_owner, &new_owner);
    (void)name; (void)old_owner;
    if (new_owner == NULL || new_owner[0] == '\0')
        root->tray_watcher_registered = 0;
    else
        (void)register_grid_tray_watcher(root);
}

static void emit_grid_tray_tooltip(DeettyGridContext *context) {
    DeettyGridContext *root = root_grid_context(context);
    if (root->tray_bus == NULL || root->tray_object_id == 0) return;
    (void)g_dbus_connection_emit_signal(
        root->tray_bus, NULL, "/StatusNotifierItem",
        "org.kde.StatusNotifierItem", "NewToolTip", NULL, NULL);
}

static void emit_grid_tray_menu_layout(DeettyGridContext *context) {
    DeettyGridContext *root = root_grid_context(context);
    if (root->tray_bus == NULL || root->tray_menu_object_id == 0) return;
    root->tray_menu_revision++;
    if (root->tray_menu_revision == 0) root->tray_menu_revision = 1;
    (void)g_dbus_connection_emit_signal(
        root->tray_bus, NULL, "/MenuBar", "com.canonical.dbusmenu",
        "LayoutUpdated", g_variant_new("(ui)", root->tray_menu_revision,
                                         DEETTY_TRAY_MENU_ROOT), NULL);
}

static void unregister_grid_tray(DeettyGridContext *context) {
    DeettyGridContext *root = root_grid_context(context);
    if (root->tray_bus != NULL && root->tray_watcher_subscription != 0) {
        g_dbus_connection_signal_unsubscribe(
            root->tray_bus, root->tray_watcher_subscription);
        root->tray_watcher_subscription = 0;
    }
    if (root->tray_bus != NULL && root->tray_object_id != 0) {
        g_dbus_connection_unregister_object(root->tray_bus,
                                            root->tray_object_id);
        root->tray_object_id = 0;
    }
    if (root->tray_bus != NULL && root->tray_menu_object_id != 0) {
        g_dbus_connection_unregister_object(root->tray_bus,
                                            root->tray_menu_object_id);
        root->tray_menu_object_id = 0;
    }
    g_clear_pointer(&root->tray_node, g_dbus_node_info_unref);
    g_clear_pointer(&root->tray_menu_node, g_dbus_node_info_unref);
    root->tray_icon_pixmaps = deetty_grid_variant_clear(root->tray_icon_pixmaps);
    root->tray_bus = deetty_grid_object_clear(root->tray_bus);
    root->tray_registered = 0;
    root->tray_menu_registered = 0;
    root->tray_watcher_registered = 0;
}

static void on_grid_tray_bus_ready(GObject *source, GAsyncResult *result,
                                   gpointer user_data) {
    (void)source;
    DeettyGridContext *root = root_grid_context(user_data);
    GError *error = NULL;
    root->tray_bus = g_bus_get_finish(result, &error);
    if (root->tray_bus == NULL) goto failed;
    root->tray_node = g_dbus_node_info_new_for_xml(deetty_tray_xml, &error);
    if (root->tray_node == NULL) goto failed;
    root->tray_menu_node = g_dbus_node_info_new_for_xml(
        deetty_tray_menu_xml, &error);
    if (root->tray_menu_node == NULL) goto failed;
    root->tray_icon_available = 1;
    root->tray_menu_revision = 1;
    root->tray_menu_object_id = g_dbus_connection_register_object(
        root->tray_bus, "/MenuBar", root->tray_menu_node->interfaces[0],
        &deetty_tray_menu_vtable, root, NULL, &error);
    if (root->tray_menu_object_id == 0) goto failed;
    root->tray_menu_registered = 1;
    root->tray_object_id = g_dbus_connection_register_object(
        root->tray_bus, "/StatusNotifierItem",
        root->tray_node->interfaces[0], &deetty_tray_vtable, root, NULL,
        &error);
    if (root->tray_object_id == 0) goto failed;
    root->tray_watcher_subscription = g_dbus_connection_signal_subscribe(
        root->tray_bus, "org.freedesktop.DBus", "org.freedesktop.DBus",
        "NameOwnerChanged", "/org/freedesktop/DBus",
        "org.kde.StatusNotifierWatcher", G_DBUS_SIGNAL_FLAGS_NONE,
        on_grid_tray_watcher_owner_changed, root, NULL);
    root->tray_registered = 1;
    (void)register_grid_tray_watcher(root);
    finish_grid_dbus_operation(root);
    return;

failed:
    deetty_grid_error_clear(&error);
    finish_grid_dbus_operation(root);
}

static int register_grid_tray(DeettyGridContext *context) {
    DeettyGridContext *root = root_grid_context(context);
    begin_grid_dbus_operation(root);
    g_bus_get(G_BUS_TYPE_SESSION, root->dbus_cancellable,
              on_grid_tray_bus_ready, root);
    return 1;
}

static void on_grid_shortcut(GDBusConnection *connection, const gchar *sender_name,
                             const gchar *object_path, const gchar *interface_name,
                             const gchar *signal_name, GVariant *parameters,
                             gpointer user_data) {
    (void)connection; (void)sender_name; (void)object_path; (void)interface_name;
    (void)signal_name; (void)parameters;
    DeettyGridContext *context = user_data;
    context->shortcut_invoked = 1;
    if (context->workspace_smoke == 9)
        (void)g_file_set_contents("/tmp/deetty-native-grid-shortcut-activated",
                                  "activated\n", -1, NULL);
    toggle_grid_window(context);
    if (context->workspace_smoke == 9)
        deetty_grid_source_idle_add(open_grid_shortcut_recorder_live_smoke, context);
}

static gboolean mark_shortcut_smoke_ready(gpointer user_data);

typedef struct {
    DeettyGridContext *root;
    guint generation;
    int requested_key;
    int prior_key;
    int purpose;
} DeettyShortcutRequest;
static const char *grid_shortcut_component_name(
    const DeettyGridContext *root);
static const char *grid_shortcut_action_name(
    const DeettyGridContext *root);
static const char *grid_shortcut_display_name(
    const DeettyGridContext *root);
static const char *grid_shortcut_description(
    const DeettyGridContext *root);
static const char *grid_shortcut_component_path(
    const DeettyGridContext *root);


static void start_grid_shortcut_registration(DeettyGridContext *context,
                                             int requested_key,
                                             int purpose,
                                             int prior_key);

static gboolean grid_shortcut_request_current(
    const DeettyShortcutRequest *request) {
    return request->generation == request->root->shortcut_generation &&
        request->root->dbus_cancellable != NULL &&
        !g_cancellable_is_cancelled(request->root->dbus_cancellable);
}

static void finish_grid_shortcut_request(DeettyShortcutRequest *request,
                                         int status) {
    DeettyGridContext *root = request->root;
    gboolean current = grid_shortcut_request_current(request);
    if (current && status == 1) {
        const char *component_path = grid_shortcut_component_path(root);
        root->shortcut_subscription = g_dbus_connection_signal_subscribe(
            root->shortcut_bus, "org.kde.kglobalaccel",
            "org.kde.kglobalaccel.Component", "globalShortcutPressed",
            component_path, NULL, G_DBUS_SIGNAL_FLAGS_NONE,
            on_grid_shortcut, root, NULL);
        root->shortcut_registered = 1;
        root->requested_shortcut_key = request->requested_key;
        if (request->purpose == 1) {
            root->shortcut_recorder_restore_on_destroy = 0;
            root->shortcut_recorded = 1;
            if (root->workspace_smoke == 9)
                (void)g_file_set_contents(
                    "/tmp/deetty-native-grid-shortcut-recorder-captured",
                    "captured\n", -1, NULL);
            if (root->event != NULL)
                root->event(root->event_data, root->pane_id,
                            deetty_grid_settings_event_code(DEETTY_GRID_SETTINGS_EVENT_SHORTCUT),
                            request->requested_key,
                            (uint64_t)(g_get_monotonic_time() / 1000));
            if (root->shortcut_recorder_dialog != NULL)
                deetty_grid_widget_destroy(root->shortcut_recorder_dialog);
        } else if (request->purpose == 0) {
            if (root->event != NULL)
                root->event(root->event_data, root->pane_id, DEETTY_GRID_HOST_EVENT(SHORTCUT_CANCELLED), 0,
                            (uint64_t)(g_get_monotonic_time() / 1000));
            if (root->workspace_smoke == 9)
                deetty_grid_source_idle_add(mark_shortcut_smoke_ready, root);
        }
    } else if (current && request->purpose == 1) {
        if (root->shortcut_recorder_feedback != NULL)
            deetty_grid_label_set_text(
                GTK_LABEL(root->shortcut_recorder_feedback),
                deetty_grid_shortcut_feedback_message(0));
    } else if (current && request->purpose == 0 && root->event != NULL) {
        root->event(root->event_data, root->pane_id,
                    status == 0
                        ? DEETTY_GRID_HOST_EVENT(SHORTCUT_CONFLICT)
                        : DEETTY_GRID_HOST_EVENT(SHORTCUT_FAILED), 0,
                    (uint64_t)(g_get_monotonic_time() / 1000));
    }
    finish_grid_dbus_operation(root);
    deetty_grid_memory_free(request);
}

static const char *grid_shortcut_component_name(
    const DeettyGridContext *root) {
    return deetty_grid_shortcut_field(0, root->workspace_smoke == 9);
}

static const char *grid_shortcut_action_name(
    const DeettyGridContext *root) {
    return deetty_grid_shortcut_field(1, root->workspace_smoke == 9);
}

static const char *grid_shortcut_display_name(
    const DeettyGridContext *root) {
    return deetty_grid_shortcut_field(2, root->workspace_smoke == 9);
}

static const char *grid_shortcut_description(
    const DeettyGridContext *root) {
    return deetty_grid_shortcut_field(3, root->workspace_smoke == 9);
}
static gchar *grid_shortcut_label_alloc(
    const DeettyGridContext *root) {
    uint8_t label[64] = {0};
    uint32_t encoded = root != NULL
        ? (uint32_t)root->requested_shortcut_key : 0;
    int length = deetty_grid_shortcut_label(
        encoded, label, G_N_ELEMENTS(label));
    return length > 0
        ? g_strndup((const gchar *)label, (gsize)length)
        : g_strdup("Unknown");
}


static void configure_grid_settings_shortcut_button(
    DeettyGridContext *context, GtkWidget *button) {
    DeettyGridContext *root = root_grid_context(context);
    if (!deetty_grid_widget_is_type(button, DEETTY_GTK_BUTTON)) return;
    char label[128] = {0};
    char tooltip[256] = {0};
    DeettyGridShortcutTextPlan plan = {0};
    if (deetty_grid_shortcut_settings_text(
            root != NULL ? (uint32_t)root->requested_shortcut_key : 0,
            root != NULL && root->shortcut_transport == 1,
            (unsigned char *)label, sizeof(label),
            (unsigned char *)tooltip, sizeof(tooltip),
            &plan) == 0)
        return;
    deetty_grid_button_set_label(GTK_BUTTON(button), label);
    deetty_grid_widget_set_tooltip_text(button, tooltip);
}

static void refresh_grid_settings_shortcut_button(
    DeettyGridContext *context) {
    DeettyGridContext *root = root_grid_context(context);
    if (!deetty_grid_widget_is_type(root->settings_dialog, DEETTY_GTK_WINDOW)) return;
    GtkWidget *button = deetty_grid_object_get_data(
        root->settings_dialog, "deetty-settings-shortcut");
    configure_grid_settings_shortcut_button(root, button);
}


static const char *grid_shortcut_component_path(
    const DeettyGridContext *root) {
    return deetty_grid_shortcut_field(4, root->workspace_smoke == 9);
}

static void on_grid_shortcut_set(GObject *source, GAsyncResult *result,
                                 gpointer user_data) {
    DeettyShortcutRequest *request = user_data;
    GError *error = NULL;
    GVariant *reply = g_dbus_connection_call_finish(
        G_DBUS_CONNECTION(source), result, &error);
    if (!grid_shortcut_request_current(request) || reply == NULL) {
        if (reply != NULL) deetty_grid_variant_unref(reply);
        deetty_grid_error_clear(&error);
        finish_grid_shortcut_request(request, -1);
        return;
    }
    GVariant *accepted_keys = NULL;
    g_variant_get(reply, "(@ai)", &accepted_keys);
    gsize accepted_count = 0;
    const gint32 *accepted = g_variant_get_fixed_array(
        accepted_keys, &accepted_count, sizeof(gint32));
    gboolean accepted_requested = accepted_count == 1 && accepted != NULL &&
        accepted[0] == request->requested_key;
    deetty_grid_variant_unref(accepted_keys);
    deetty_grid_variant_unref(reply);
    finish_grid_shortcut_request(request, accepted_requested ? 1 : 0);
}

static void on_grid_shortcut_available(GObject *source, GAsyncResult *result,
                                       gpointer user_data) {
    DeettyShortcutRequest *request = user_data;
    DeettyGridLifecycleTimingPlan timing = {0};
    deetty_grid_lifecycle_timing_plan(&timing);
    GError *error = NULL;
    GVariant *reply = g_dbus_connection_call_finish(
        G_DBUS_CONNECTION(source), result, &error);
    if (!grid_shortcut_request_current(request) || reply == NULL) {
        if (reply != NULL) deetty_grid_variant_unref(reply);
        deetty_grid_error_clear(&error);
        finish_grid_shortcut_request(request, -1);
        return;
    }
    gboolean available = FALSE;
    g_variant_get(reply, "(b)", &available);
    deetty_grid_variant_unref(reply);
    if (!available) {
        finish_grid_shortcut_request(request, 0);
        return;
    }
    const gchar *action_id[] = {
        grid_shortcut_component_name(request->root),
        grid_shortcut_action_name(request->root),
        grid_shortcut_display_name(request->root),
        grid_shortcut_description(request->root),
        NULL};
    GVariantBuilder keys;
    g_variant_builder_init(&keys, G_VARIANT_TYPE("ai"));
    g_variant_builder_add(&keys, "i", request->requested_key);
    g_dbus_connection_call(
        request->root->shortcut_bus, "org.kde.kglobalaccel",
        "/kglobalaccel", "org.kde.KGlobalAccel", "setShortcut",
        g_variant_new("(^asaiu)", action_id, &keys, 2u),
        G_VARIANT_TYPE("(ai)"), G_DBUS_CALL_FLAGS_NONE,
        timing.dbus_operation_timeout_ms,
        request->root->dbus_cancellable, on_grid_shortcut_set, request);
}

static void on_grid_shortcut_action_registered(GObject *source,
                                                GAsyncResult *result,
                                                gpointer user_data) {
    DeettyShortcutRequest *request = user_data;
    DeettyGridLifecycleTimingPlan timing = {0};
    deetty_grid_lifecycle_timing_plan(&timing);
    GError *error = NULL;
    GVariant *reply = g_dbus_connection_call_finish(
        G_DBUS_CONNECTION(source), result, &error);
    if (!grid_shortcut_request_current(request) || reply == NULL) {
        if (reply != NULL) deetty_grid_variant_unref(reply);
        deetty_grid_error_clear(&error);
        finish_grid_shortcut_request(request, -1);
        return;
    }
    deetty_grid_variant_unref(reply);
    request->root->shortcut_action_registered = 1;
    const char *component = grid_shortcut_component_name(request->root);
    g_dbus_connection_call(
        request->root->shortcut_bus, "org.kde.kglobalaccel",
        "/kglobalaccel", "org.kde.KGlobalAccel",
        "isGlobalShortcutAvailable",
        g_variant_new("(is)", request->requested_key, component),
        G_VARIANT_TYPE("(b)"), G_DBUS_CALL_FLAGS_NONE,
        timing.dbus_operation_timeout_ms,
        request->root->dbus_cancellable, on_grid_shortcut_available, request);
}

static void on_grid_shortcut_bus_ready(GObject *source, GAsyncResult *result,
                                       gpointer user_data) {
    (void)source;
    DeettyShortcutRequest *request = user_data;
    DeettyGridLifecycleTimingPlan timing = {0};
    deetty_grid_lifecycle_timing_plan(&timing);
    GError *error = NULL;
    GDBusConnection *bus = g_bus_get_finish(result, &error);
    if (!grid_shortcut_request_current(request) || bus == NULL) {
        if (bus != NULL) deetty_grid_object_unref(bus);
        deetty_grid_error_clear(&error);
        finish_grid_shortcut_request(request, -1);
        return;
    }
    request->root->shortcut_bus = bus;
    const gchar *action_id[] = {
        grid_shortcut_component_name(request->root),
        grid_shortcut_action_name(request->root),
        grid_shortcut_display_name(request->root),
        grid_shortcut_description(request->root),
        NULL};
    g_dbus_connection_call(
        bus, "org.kde.kglobalaccel", "/kglobalaccel",
        "org.kde.KGlobalAccel", "doRegister",
        g_variant_new("(^as)", action_id), NULL, G_DBUS_CALL_FLAGS_NONE,
        timing.dbus_operation_timeout_ms, request->root->dbus_cancellable,
        on_grid_shortcut_action_registered, request);
}

static void start_grid_shortcut_registration(DeettyGridContext *context,
                                             int requested_key,
                                             int purpose,
                                             int prior_key) {
    DeettyGridContext *root = root_grid_context(context);
    DeettyShortcutRequest *request = g_new0(DeettyShortcutRequest, 1);
    request->root = root;
    request->generation = ++root->shortcut_generation;
    request->requested_key = requested_key;
    request->prior_key = prior_key;
    request->purpose = purpose;
    begin_grid_dbus_operation(root);
    g_bus_get(G_BUS_TYPE_SESSION, root->dbus_cancellable,
              on_grid_shortcut_bus_ready, request);
}

static int register_grid_shortcut(DeettyGridContext *context,
                                  int requested_key) {
    start_grid_shortcut_registration(context, requested_key, 0, 0);
    return 1;
}

static void unregister_grid_shortcut(DeettyGridContext *context) {
    DeettyGridLifecycleTimingPlan timing = {0};
    deetty_grid_lifecycle_timing_plan(&timing);
    context->shortcut_generation++;
    if (context->shortcut_bus == NULL) return;
    if (context->shortcut_subscription != 0) g_dbus_connection_signal_unsubscribe(context->shortcut_bus, context->shortcut_subscription);
    GError *error = NULL;
    const char *component = grid_shortcut_component_name(context);
    const char *action = grid_shortcut_action_name(context);
    GVariant *reply = g_dbus_connection_call_sync(
        context->shortcut_bus, "org.kde.kglobalaccel", "/kglobalaccel",
        "org.kde.KGlobalAccel", "unregister",
        g_variant_new("(ss)", component, action),
        G_VARIANT_TYPE("(b)"), G_DBUS_CALL_FLAGS_NONE,
        timing.dbus_call_timeout_ms, NULL, &error);
    if (reply != NULL) deetty_grid_variant_unref(reply);
    deetty_grid_error_clear(&error);
    deetty_grid_object_unref(context->shortcut_bus);
    context->shortcut_bus = NULL;
    context->shortcut_subscription = 0;
    context->shortcut_action_registered = 0;
    context->shortcut_registered = 0;
}

static void on_grid_shortcut_recorder_destroy(GtkWidget *widget,
                                               gpointer user_data) {
    (void)widget;
    DeettyGridContext *root = root_grid_context(user_data);
    gboolean restore = root->shortcut_recorder_restore_on_destroy;
    int prior_key = root->shortcut_recorder_prior_key;
    root->shortcut_recorder_dialog = NULL;
    root->shortcut_recorder_feedback = NULL;
    root->shortcut_recorder_restore_on_destroy = 0;
    refresh_grid_settings_shortcut_button(root);
    if (root->shortcut_recorder_settings_hidden) {
        root->shortcut_recorder_settings_hidden = 0;
        if (deetty_grid_widget_is_type(root->settings_dialog, DEETTY_GTK_WINDOW)) {
            deetty_grid_widget_show(root->settings_dialog);
            present_configured_window(root->settings_dialog);
            root->shortcut_recorder_settings_restored =
                deetty_grid_widget_get_visible(root->settings_dialog) &&
                deetty_grid_widget_get_mapped(root->settings_dialog);
        }
    }
    if (root->shortcut_transport == 1 && restore &&
        root->dbus_cancellable != NULL) {
        unregister_grid_shortcut(root);
        start_grid_shortcut_registration(root, prior_key, 2, 0);
    }
}

static gboolean on_grid_shortcut_capture(GtkWidget *widget, GdkEventKey *event,
                                         gpointer user_data) {
    (void)widget;
    DeettyGridContext *root = root_grid_context(user_data);
    if (event->keyval == GDK_KEY_Escape) {
        deetty_grid_widget_destroy(root->shortcut_recorder_dialog);
        return TRUE;
    }
    int key = deetty_qt_shortcut_from_gdk(event->keyval, event->state);
    int base = key & 0x01ffffff;
    gboolean function_key = base >= 0x01000030 && base <= 0x0100003b;
    gboolean has_modifier = (key & 0x1e000000) != 0;
    if (key == 0 || (!function_key && !has_modifier)) {
        deetty_grid_label_set_text(
            GTK_LABEL(root->shortcut_recorder_feedback),
            deetty_grid_shortcut_feedback_message(1));
        return TRUE;
    }
    int prior_key = root->requested_shortcut_key;
    if (root->shortcut_transport == 1) {
        unregister_grid_shortcut(root);
        deetty_grid_label_set_text(
            GTK_LABEL(root->shortcut_recorder_feedback),
            deetty_grid_shortcut_feedback_message(2));
        start_grid_shortcut_registration(root, key, 1, prior_key);
        return TRUE;
    }
    root->requested_shortcut_key = key;
    root->shortcut_recorded = 1;
    if (root->event != NULL)
        root->event(root->event_data, root->pane_id,
                    deetty_grid_settings_event_code(DEETTY_GRID_SETTINGS_EVENT_SHORTCUT), key,
                    (uint64_t)(g_get_monotonic_time() / 1000));
    deetty_grid_widget_destroy(root->shortcut_recorder_dialog);
    return TRUE;
}

static void open_grid_shortcut_recorder(DeettyGridContext *context) {
    DeettyGridContext *root = root_grid_context(context);
    if (root->shortcut_recorder_dialog != NULL) {
        present_configured_window(root->shortcut_recorder_dialog);
        return;
    }
    GtkWidget *dialog = deetty_dialog_new(
        GTK_WIDGET(root->window), "Global shortcut",
        GTK_DIALOG_MODAL | GTK_DIALOG_DESTROY_WITH_PARENT,
        NULL, 0, NULL, 0);
    (void)configure_overlay_window_stacking(
        root, dialog, "deetty-shortcut-recorder");
    if (deetty_grid_widget_is_type(root->settings_dialog, DEETTY_GTK_WINDOW) &&
        deetty_grid_widget_get_visible(root->settings_dialog)) {
        deetty_grid_widget_hide(root->settings_dialog);
        root->shortcut_recorder_settings_hidden =
            !deetty_grid_widget_get_visible(root->settings_dialog);
        root->shortcut_recorder_settings_handoff =
            root->shortcut_recorder_settings_hidden;
        root->shortcut_recorder_settings_restored = 0;
    }
    GtkWidget *label = deetty_shortcut_recorder_label_new(
        root->shortcut_transport == 1);
    if (label == NULL) {
        deetty_grid_widget_destroy(dialog);
        return;
    }
    deetty_container_add(
        deetty_grid_dialog_get_content_area(GTK_DIALOG(dialog)), label);
    root->shortcut_recorder_prior_key = root->requested_shortcut_key;
    root->shortcut_recorder_restore_on_destroy =
        root->shortcut_transport == 1;
    if (root->shortcut_transport == 1) unregister_grid_shortcut(root);
    root->shortcut_recorder_dialog = dialog;
    root->shortcut_recorder_feedback = label;
    root->shortcut_recorder_shown = 1;
    deetty_grid_signal_connect(dialog, "key-press-event",
                     G_CALLBACK(on_grid_shortcut_capture), root);
    deetty_grid_signal_connect(dialog, "destroy",
                     G_CALLBACK(on_grid_shortcut_recorder_destroy), root);
    show_all_with_action_affordances(dialog);
    present_configured_window(dialog);
}

static gboolean open_grid_shortcut_recorder_live_smoke(gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    open_grid_shortcut_recorder(root);
    if (root->shortcut_recorder_dialog != NULL &&
        !root->shortcut_registered)
        (void)g_file_set_contents(
            "/tmp/deetty-native-grid-shortcut-recorder-ready",
            "ready\n", -1, NULL);
    return G_SOURCE_REMOVE;
}

static gboolean mark_shortcut_smoke_ready(gpointer user_data) {
    (void)user_data;
    (void)g_file_set_contents("/tmp/deetty-native-grid-shortcut-ready",
                              "ready\n", -1, NULL);
    return G_SOURCE_REMOVE;
}

static void on_window_destroy(GtkWidget *widget, gpointer user_data) {
    (void)widget;
    (void)user_data;
    if (deetty_grid_main_level() > 0) deetty_grid_main_quit();
}

static gboolean on_window_delete_event(GtkWidget *widget, GdkEvent *event,
                                       gpointer user_data) {
    (void)widget;
    (void)event;
    DeettyGridContext *root = root_grid_context(user_data);
    (void)request_grid_application_close(
        root, DEETTY_CLOSE_ORIGIN_WINDOW);
    return TRUE;
}

static gboolean grid_has_visible_transient(DeettyGridContext *root) {
    GList *windows = deetty_grid_window_list_toplevels();
    gboolean found = FALSE;
    for (GList *item = windows; item != NULL; item = item->next) {
        if (!deetty_grid_widget_is_type(item->data, DEETTY_GTK_WINDOW) || item->data == root->window) continue;
        if (deetty_grid_window_get_transient_for(GTK_WINDOW(item->data)) == GTK_WINDOW(root->window) &&
            deetty_grid_widget_get_visible(GTK_WIDGET(item->data))) {
            found = TRUE;
            break;
        }
    }
    g_list_free(windows);
    return found;
}

static gboolean grid_has_open_menu(DeettyGridContext *root) {
    GtkWidget *grab = deetty_grid_grab_get_current();
    return (grab != NULL &&
            deetty_grid_widget_is_type(grab, DEETTY_GTK_MENU)) ||
           (root->workspace_menu != NULL &&
            deetty_grid_widget_get_visible(root->workspace_menu));
}

static void queue_quick_note_overlay_draws(DeettyGridContext *root) {
    if (root->contexts == NULL) return;
    for (guint index = 0; index < root->contexts->len; index++) {
        DeettyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (candidate->active && candidate->area != NULL &&
            deetty_grid_widget_get_mapped(candidate->area))
            deetty_grid_widget_queue_draw(candidate->area);
    }
}

static gboolean show_quick_note_overlays(DeettyGridContext *context) {
    DeettyGridContext *root = root_grid_context(context);
    root->note_overlay_alt_pressed = 1;
    if (root->note_overlay_visible) return TRUE;

    root->note_overlay_text = deetty_grid_memory_clear(root->note_overlay_text);
    root->note_overlay_label = deetty_grid_memory_clear(root->note_overlay_label);
    root->note_overlay_content_loaded = 0;
    if (root->text_action == NULL) return FALSE;

    const size_t capacity = 4096;
    char *contents = g_malloc(capacity);
    int length = root->text_action(root->text_action_data, 8, "", 0,
                                   contents, capacity, 1);
    if (length <= 0 || (size_t)length > capacity) {
        deetty_grid_memory_free(contents);
        return FALSE;
    }
    gchar *valid = g_utf8_make_valid(contents, length);
    deetty_grid_memory_free(contents);
    g_strstrip(valid);
    if (valid[0] == '\0') {
        deetty_grid_memory_free(valid);
        return FALSE;
    }
    glong characters = g_utf8_strlen(valid, -1);
    root->note_overlay_text = characters > 512
        ? g_utf8_substring(valid, 0, 512)
        : g_strdup(valid);
    deetty_grid_memory_free(valid);
    char note_label[4096] = {0};
    if (deetty_grid_note_overlay_label(
            (const unsigned char *)root->note_overlay_text,
            root->note_overlay_text != NULL
                ? strlen(root->note_overlay_text) : 0,
            (unsigned char *)note_label, sizeof(note_label)) <= 0)
        return FALSE;
    root->note_overlay_label = g_strdup(note_label);
    root->note_overlay_content_loaded = 1;
    root->note_overlay_visible = 1;
    if (root->contexts != NULL) {
        for (guint index = 0; index < root->contexts->len; index++) {
            DeettyGridContext *candidate =
                g_ptr_array_index(root->contexts, index);
            candidate->note_overlay_drawn = 0;
            candidate->note_overlay_compact = 0;
        }
    }
    queue_quick_note_overlay_draws(root);
    return TRUE;
}

static void hide_quick_note_overlays(DeettyGridContext *context) {
    DeettyGridContext *root = root_grid_context(context);
    if (!root->note_overlay_visible && root->note_overlay_text == NULL &&
        root->note_overlay_label == NULL) return;
    root->note_overlay_visible = 0;
    root->note_overlay_text = deetty_grid_memory_clear(root->note_overlay_text);
    root->note_overlay_label = deetty_grid_memory_clear(root->note_overlay_label);
    queue_quick_note_overlay_draws(root);
}


static gboolean deferred_focus_hide(gpointer user_data) {
    DeettyGridContext *root = user_data;
    root->focus_hide_source = 0;
    if (grid_has_open_menu(root)) {
        DeettyGridLifecycleTimingPlan timing = {0};
        deetty_grid_lifecycle_timing_plan(&timing);
        if (root->workspace_menu != NULL &&
            deetty_grid_widget_get_mapped(root->workspace_menu) &&
            deetty_grid_widget_get_mapped(root->window))
            root->context_menu_survived = 1;
        root->focus_hide_source = deetty_grid_source_timeout_add(
            (guint)timing.focus_hide_ms, deferred_focus_hide, root);
        return G_SOURCE_REMOVE;
    }
    if (root->mode == 0 && root->hide_on_focus_loss &&
        root->window_presented &&
        deetty_grid_widget_get_visible(root->window) &&
        !deetty_grid_window_is_active(GTK_WINDOW(root->window)) &&
        !grid_has_visible_transient(root)) toggle_grid_window(root);
    return G_SOURCE_REMOVE;
}

static gboolean on_window_focus_out(GtkWidget *widget, GdkEventFocus *event,
                                    gpointer user_data) {
    (void)widget;
    (void)event;
    DeettyGridContext *root = user_data;
    hide_quick_note_overlays(root);
    if (root->focus_hide_source != 0) deetty_grid_source_remove(root->focus_hide_source);
    DeettyGridLifecycleTimingPlan timing = {0};
    deetty_grid_lifecycle_timing_plan(&timing);
    root->focus_hide_source = deetty_grid_source_timeout_add(
        (guint)timing.focus_hide_ms, deferred_focus_hide, root);
    return FALSE;
}

static void update_status_tooltip(DeettyGridContext *context, const gchar *status) {
    char tag_buffer[256] = {0};
    int tag_length = context->event_data != NULL
        ? deetty_grid_pane_tags(context->event_data, context->pane_id,
                                tag_buffer, sizeof(tag_buffer) - 1)
        : 0;
    char text[384];
    int text_length = deetty_grid_pane_tooltip(
        context->pane_id,
        (const unsigned char *)(status != NULL ? status : ""),
        status != NULL ? strlen(status) : 0,
        (const unsigned char *)tag_buffer,
        tag_length > 0 ? (size_t)tag_length : 0,
        (unsigned char *)text,
        sizeof(text));
    if (text_length <= 0) return;
    const gchar *cached = deetty_grid_object_get_data(
        context->area, "deetty-pane-tooltip-cache");
    if (g_strcmp0(cached, text) != 0) {
        deetty_grid_widget_set_tooltip_text(context->area, text);
        AtkObject *accessible = deetty_grid_widget_get_accessible(context->area);
        if (accessible != NULL) deetty_grid_atk_object_set_description(accessible, text);
        deetty_grid_object_set_data_full(
            context->area, "deetty-pane-tooltip-cache",
            g_strdup(text), g_free);
    }
}

static void refresh_tag_tooltips(DeettyGridContext *context) {
    DeettyGridContext *root = root_grid_context(context);
    for (guint index = 0; root->contexts != NULL && index < root->contexts->len; index++) {
        DeettyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (candidate->active && candidate->area != NULL)
            update_status_tooltip(candidate,
                                  deetty_grid_status_name(candidate->status_kind));
    }
}

static DeettyGridContext *root_grid_context(DeettyGridContext *context) {
    if (context == NULL || context->root == NULL) return context;
    return context->root;
}

static gboolean dogfood_evidence_enabled(void) {
    const char *session_id = g_getenv("DEETTY_DOGFOOD_SESSION_ID");
    return session_id != NULL && session_id[0] != '\0';
}

static void emit_dogfood_event(DeettyGridContext *context,
                               const char *event_name,
                               uint64_t pane_id,
                               int value,
                               const char *detail) {
    const char *session_id = g_getenv("DEETTY_DOGFOOD_SESSION_ID");
    if (session_id == NULL || session_id[0] == '\0' ||
        event_name == NULL || event_name[0] == '\0')
        return;
    g_printerr(
        "dogfood_event session=%s event=%s pane=%" G_GUINT64_FORMAT
        " value=%d detail=%s monotonic_ms=%" G_GINT64_FORMAT "\n",
        session_id, event_name, pane_id, value,
        detail != NULL && detail[0] != '\0' ? detail : "none",
        g_get_monotonic_time() / 1000);
    (void)context;
}

static guint dogfood_active_omp_count(DeettyGridContext *context) {
    DeettyGridContext *root = root_grid_context(context);
    guint count = 0;
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        DeettyGridContext *candidate =
            g_ptr_array_index(root->contexts, index);
        if (candidate->active && !candidate->exited &&
            candidate->dogfood_omp_seen)
            count++;
    }
    return count;
}

static void detect_dogfood_omp_sessions(DeettyGridContext *context,
                                        gint64 now_us) {
    if (!dogfood_evidence_enabled()) return;
    DeettyGridContext *root = root_grid_context(context);
    guint active_count = 0;
    guint streaming_count = 0;
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        DeettyGridContext *candidate =
            g_ptr_array_index(root->contexts, index);
        if (!grid_context_session_available(candidate) || candidate->exited)
            continue;
        if (!candidate->dogfood_omp_seen) {
            uint8_t process_name[64];
            int process_name_length = deetty_grid_process_name(
                candidate->userdata, process_name, sizeof(process_name) - 1);
            if (process_name_length == 3 &&
                memcmp(process_name, "omp", 3) == 0) {
                candidate->dogfood_omp_seen = 1;
                char cwd[4096];
                int cwd_length = deetty_grid_current_directory(
                    candidate->userdata, candidate->event_data,
                    candidate->pane_id, cwd, sizeof(cwd));
                gchar *cwd_hash = cwd_length > 0
                    ? g_compute_checksum_for_data(
                        G_CHECKSUM_SHA256, (const guchar *)cwd,
                        (gsize)cwd_length)
                    : NULL;
                emit_dogfood_event(
                    root, "omp_detected", candidate->pane_id, 1,
                    cwd_hash != NULL ? cwd_hash : "unknown");
                deetty_grid_memory_free(cwd_hash);
            }
        }
        if (!candidate->dogfood_omp_seen) continue;
        active_count++;
        if (candidate->last_output_us > 0 &&
            now_us - candidate->last_output_us <= 2 * G_USEC_PER_SEC)
            streaming_count++;
    }
    if (active_count > root->dogfood_omp_max_concurrent) {
        root->dogfood_omp_max_concurrent = active_count;
        emit_dogfood_event(root, "omp_concurrency", 0,
                           (int)active_count, "active");
        if (active_count >= 4 && !root->dogfood_omp_workspace_emitted) {
            root->dogfood_omp_workspace_emitted = 1;
            GChecksum *workspace = g_checksum_new(G_CHECKSUM_SHA256);
            for (guint index = 0; root->contexts != NULL &&
                 index < root->contexts->len; index++) {
                DeettyGridContext *candidate =
                    g_ptr_array_index(root->contexts, index);
                if (!grid_context_session_available(candidate) ||
                    candidate->exited || !candidate->dogfood_omp_seen)
                    continue;
                guint64 pane_id_be = GUINT64_TO_BE(candidate->pane_id);
                g_checksum_update(
                    workspace, (const guchar *)&pane_id_be,
                    sizeof(pane_id_be));
            }
            emit_dogfood_event(
                root, "omp_workspace", 0, (int)active_count,
                g_checksum_get_string(workspace));
            g_checksum_free(workspace);
        }
    }
    if (streaming_count >= 4 && !root->dogfood_omp_streaming_seen) {
        root->dogfood_omp_streaming_seen = 1;
        emit_dogfood_event(root, "omp_concurrent_streaming", 0,
                           (int)streaming_count, "two_second_window");
    }
    if (root->hot_session_restored && active_count >= 4 &&
        !root->dogfood_omp_hot_restore_seen) {
        root->dogfood_omp_hot_restore_seen = 1;
        emit_dogfood_event(root, "omp_hot_restore", 0,
                           (int)active_count, "restored");
    }
}

static void record_dogfood_omp_action(DeettyGridContext *context,
                                      const char *event_name,
                                      int *seen) {
    if (context == NULL || !context->dogfood_omp_seen ||
        seen == NULL || *seen)
        return;
    *seen = 1;
    emit_dogfood_event(context, event_name, context->pane_id, 1, "observed");
}

static gboolean on_grid_write_flush(gpointer user_data) {
    DeettyGridContext *context = user_data;
    if (!grid_context_session_available(context) || context->exited) {
        context->write_flush_source = 0;
        return G_SOURCE_REMOVE;
    }
    int flushed = deetty_grid_flush_write(context->userdata);
    if (flushed > 0 || flushed < 0) {
        context->write_flush_source = 0;
        if (flushed < 0)
            show_status_feedback(
                context,
                deetty_grid_status_feedback_message(
                    DEETTY_GRID_FEEDBACK_INPUT_FLUSH));
        return G_SOURCE_REMOVE;
    }
    return G_SOURCE_CONTINUE;
}

static void schedule_grid_write_flush(DeettyGridContext *context) {
    if (context->write_flush_source != 0 ||
        deetty_grid_write_pending(context->userdata) == 0)
        return;
    DeettyGridLifecycleTimingPlan timing = {0};
    deetty_grid_lifecycle_timing_plan(&timing);
    context->write_flush_source = g_timeout_add_full(
        G_PRIORITY_DEFAULT, (guint)timing.write_flush_ms,
        on_grid_write_flush, context, NULL);
}

static void acknowledge_grid_attention(DeettyGridContext *context) {
    if (!context->attention && context->status_kind != 4) return;
    DeettyGridNativeHostPolicy policy = {0};
    deetty_grid_native_host_policy(&policy);
    context->attention = 0;
    context->status_kind = 0;
    update_status_tooltip(context, "idle");
    update_compact_tab(context);
    if (context->event != NULL)
        context->event(context->event_data, context->pane_id,
                       policy.event_status_acknowledged, 0,
                       (uint64_t)(g_get_monotonic_time() / 1000));
}

static int deliver_grid_input(DeettyGridContext *source, const char *bytes,
                              size_t length) {
    if (!grid_context_session_available(source)) return -1;
    DeettyGridContext *root = root_grid_context(source);
    if (root->contexts == NULL ||
        root->event_data == NULL ||
        deetty_grid_broadcast_enabled(root->event_data) == 0) {
        acknowledge_grid_attention(source);
        source->cursor_visible = 1;
        queue_grid_cursor_cell(source, source->cursor(source->userdata));
        (void)scroll_terminal_to_offset(source, 0);
        int delivered = source->write(source->userdata, bytes, length);
        if (delivered >= 0) {
            schedule_grid_write_flush(source);
            record_dogfood_omp_action(
                source, "omp_independent_input",
                &source->dogfood_omp_input_seen);
        }
        return delivered;
    }

    guint selected = 0;
    for (guint index = 0; index < root->contexts->len; index++) {
        DeettyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (candidate->active && !candidate->exited &&
            candidate->page == source->page &&
            deetty_grid_pane_selected(root->event_data, candidate->pane_id) != 0)
            selected++;
    }

    int delivered = 0;
    for (guint index = 0; index < root->contexts->len; index++) {
        DeettyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (!grid_context_session_available(candidate) || candidate->exited ||
            candidate->page != source->page)
            continue;
        if (selected > 0 &&
            deetty_grid_pane_selected(root->event_data, candidate->pane_id) == 0)
            continue;
        acknowledge_grid_attention(candidate);
        candidate->cursor_visible = 1;
        queue_grid_cursor_cell(candidate, candidate->cursor(candidate->userdata));
        (void)scroll_terminal_to_offset(candidate, 0);
        if (candidate->write(candidate->userdata, bytes, length) < 0) return -1;
        schedule_grid_write_flush(candidate);
        delivered = 1;
    }
    return delivered ? (int)length : -1;
}

static int deliver_grid_paste(DeettyGridContext *source, const char *bytes,
                              size_t length) {
    if (!grid_context_session_available(source)) return -1;
    DeettyGridContext *root = root_grid_context(source);
    if (root->contexts == NULL || root->event_data == NULL ||
        deetty_grid_broadcast_enabled(root->event_data) == 0) {
        acknowledge_grid_attention(source);
        source->cursor_visible = 1;
        queue_grid_cursor_cell(source, source->cursor(source->userdata));
        (void)scroll_terminal_to_offset(source, 0);
        int delivered = source->paste(source->userdata, bytes, length);
        if (delivered >= 0) {
            schedule_grid_write_flush(source);
            record_dogfood_omp_action(
                source, "omp_independent_paste",
                &source->dogfood_omp_paste_seen);
        }
        return delivered;
    }

    guint selected = 0;
    for (guint index = 0; index < root->contexts->len; index++) {
        DeettyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (candidate->active && !candidate->exited && candidate->page == source->page &&
            deetty_grid_pane_selected(root->event_data, candidate->pane_id) != 0)
            selected++;
    }
    int delivered = 0;
    for (guint index = 0; index < root->contexts->len; index++) {
        DeettyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (!grid_context_session_available(candidate) || candidate->exited ||
            candidate->page != source->page)
            continue;
        if (selected > 0 &&
            deetty_grid_pane_selected(root->event_data, candidate->pane_id) == 0)
            continue;
        acknowledge_grid_attention(candidate);
        candidate->cursor_visible = 1;
        queue_grid_cursor_cell(candidate, candidate->cursor(candidate->userdata));
        (void)scroll_terminal_to_offset(candidate, 0);
        if (candidate->paste(candidate->userdata, bytes, length) < 0) return -1;
        schedule_grid_write_flush(candidate);
        delivered = 1;
    }
    return delivered ? (int)length : -1;
}

static DeettyGridContext *grid_context_for_page(DeettyGridContext *context,
                                                GtkWidget *page) {
    DeettyGridContext *root = root_grid_context(context);
    if (root != NULL && root->active && root->page == page) return root;
    for (guint index = 0; root != NULL && root->contexts != NULL &&
         index < root->contexts->len; index++) {
        DeettyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (candidate != root && candidate->active && candidate->page == page)
            return candidate;
    }
    return NULL;
}

static gchar *current_tab_title_alloc(DeettyGridContext *context) {
    DeettyGridContext *root = root_grid_context(context);
    DeettyGridContext *representative = grid_context_for_page(root, context->page);
    char model_title[512] = {0};
    size_t model_length = 0;
    if (representative != NULL && root->event_data != NULL) {
        int length = deetty_grid_tab_title(
            root->event_data, representative->pane_id,
            model_title, sizeof(model_title) - 1);
        if (length > 0 && (size_t)length < sizeof(model_title)) {
            model_title[length] = '\0';
            model_length = (size_t)length;
        }
    }

    const char *display_title = NULL;
    for (guint index = 0;
         root->contexts != NULL && index < root->contexts->len;
         index++) {
        DeettyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (!candidate->active || candidate->page != context->page) continue;
        if (candidate->display_title != NULL && candidate->display_title[0] != '\0') {
            display_title = candidate->display_title;
            break;
        }
    }

    gchar *directory_name = NULL;
    if (representative != NULL && root->event_data != NULL) {
        char cwd[4096];
        int length = deetty_grid_current_directory(
            representative->userdata, root->event_data, representative->pane_id,
            cwd, sizeof(cwd) - 1);
        if (length > 0 && length < (int)sizeof(cwd)) {
            cwd[length] = '\0';
            directory_name = g_path_get_basename(cwd);
            if (directory_name == NULL || directory_name[0] == '\0' ||
                g_strcmp0(directory_name, "/") == 0)
                directory_name = deetty_grid_memory_clear(directory_name);
        }
    }

    gint page_index = deetty_grid_notebook_page_num(
        GTK_NOTEBOOK(root->notebook), context->page);
    char output[4096] = "Tab 1";
    (void)deetty_grid_tab_title_text(
        (const unsigned char *)model_title, model_length,
        (const unsigned char *)display_title,
        display_title != NULL ? strlen(display_title) : 0,
        (const unsigned char *)directory_name,
        directory_name != NULL ? strlen(directory_name) : 0,
        page_index >= 0 ? page_index + 1 : 1,
        (unsigned char *)output, sizeof(output));
    deetty_grid_memory_free(directory_name);
    return g_strdup(output);
}

static void update_compact_tab(DeettyGridContext *context) {
    if (context->page == NULL || context->tab_label == NULL) return;
    DeettyGridContext *root = root_grid_context(context);
    if (root->tab_rename_entry != NULL &&
        root->tab_rename_page == context->page)
        return;
    DeettyGridContext *representative = grid_context_for_page(
        root, context->page);
    int tab_color_preset = -1;
    int tab_color_shade = 0;
    uint32_t tab_color_rgb = representative != NULL &&
            root->event_data != NULL
        ? deetty_grid_tab_color(root->event_data,
                                representative->pane_id,
                                &tab_color_preset,
                                &tab_color_shade)
        : 0;
    int status = 0;
    int attention = 0;
    int dirty = root->event_data != NULL && deetty_grid_workspace_dirty(root->event_data) != 0;
    guint panes = 0;
    guint selected = 0;
    for (guint index = 0; root->contexts != NULL && index < root->contexts->len; index++) {
        DeettyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (!candidate->active || candidate->page != context->page) continue;
        panes++;
        if (root->event_data != NULL &&
            deetty_grid_pane_selected(root->event_data, candidate->pane_id) != 0)
            selected++;
        if (candidate->status_kind > status) status = candidate->status_kind;
        if (candidate->attention) attention = 1;
    }
    gchar *title = current_tab_title_alloc(context);
    gchar *basename = g_path_get_basename(title);
    gint page_index = deetty_grid_notebook_page_num(GTK_NOTEBOOK(root->notebook),
                                            context->page);
    gboolean is_active = page_index >= 0 &&
        deetty_grid_notebook_get_current_page(GTK_NOTEBOOK(root->notebook)) == page_index;
    char color[8];
    DeettyGridStatusColorPlan status_color = {0};
    deetty_grid_status_color_plan(status, attention, &status_color);
    if (status_color.muted != 0) {
        g_strlcpy(color, "#6f7480", sizeof(color));
    } else {
        format_ui_color(
            root, status_color.role, status_color.fallback, color);
    }
    char markup[4096];
    char tooltip[4096];
    char close_name[1024];
    DeettyGridCompactTabTextInput text_input = {
        .title = (const unsigned char *)basename,
        .title_length = basename != NULL ? strlen(basename) : 0,
        .filter = (const unsigned char *)root->smart_filter_tag,
        .filter_length = root->smart_filter_tag != NULL
            ? strlen(root->smart_filter_tag) : 0,
        .status_color = (const unsigned char *)color,
        .status_color_length = strlen(color),
        .pane_count = panes,
        .selected_count = selected,
        .filter_active = root->smart_filter_tag != NULL,
        .attention = attention,
        .dirty = dirty,
        .broadcast = root->event_data != NULL &&
            deetty_grid_broadcast_enabled(root->event_data) != 0,
        .active = is_active,
        .tab_color_rgb = tab_color_rgb,
        .tab_color_preset = tab_color_preset,
        .tab_color_shade = tab_color_shade,
    };
    DeettyGridCompactTabTextPlan text_plan = {0};
    if (deetty_grid_compact_tab_text(
            &text_input,
            (unsigned char *)markup, sizeof(markup),
            (unsigned char *)tooltip, sizeof(tooltip),
            (unsigned char *)close_name, sizeof(close_name),
            &text_plan) == 0) {
        deetty_grid_memory_free(basename);
        deetty_grid_memory_free(title);
        return;
    }
    if (root->workspace_smoke == 15 && tab_color_rgb == 0) {
        const gchar *title_end = strstr(markup, "</span>");
        if (title_end != NULL &&
            g_strstr_len(markup, title_end - markup, "foreground=") == NULL)
            root->compact_light_tab_title_inherits = 1;
    }
    const gchar *cached_markup = deetty_grid_object_get_data(
        context->tab_label, "deetty-tab-markup-cache");
    if (g_strcmp0(cached_markup, markup) != 0) {
        deetty_grid_label_set_markup(GTK_LABEL(context->tab_label), markup);
        deetty_grid_object_set_data_full(
            context->tab_label, "deetty-tab-markup-cache",
            g_strdup(markup), g_free);
    }
    deetty_grid_widget_show(context->tab_label);
    GtkWidget *tab_content = deetty_grid_widget_get_parent(context->tab_label);
    if (tab_content != NULL) deetty_grid_widget_show(tab_content);
    GtkWidget *tab_widget = tab_content != NULL
        ? deetty_grid_widget_get_parent(tab_content) : NULL;
    if (tab_widget != NULL) deetty_grid_widget_show(tab_widget);
    apply_tab_color_style(tab_widget, tab_color_rgb, is_active);
    DeettyGridCompactTabMetrics tab_metrics = {0};
    deetty_grid_compact_tab_metrics(root->compact_tab_height, &tab_metrics);
    deetty_grid_widget_set_size_request(
        context->tab_label, -1, tab_metrics.label_height);
    const char *cached_tooltip = deetty_grid_object_get_data(
        context->tab_label, "deetty-tab-tooltip-cache");
    if (g_strcmp0(cached_tooltip, tooltip) != 0) {
        deetty_grid_widget_set_tooltip_text(context->tab_label, tooltip);
        if (deetty_grid_widget_is_type(tab_widget, DEETTY_GTK_EVENT_BOX)) {
            deetty_grid_widget_set_tooltip_text(tab_widget, tooltip);
            AtkObject *accessible = deetty_grid_widget_get_accessible(tab_widget);
            if (accessible != NULL)
                deetty_grid_atk_object_set_description(accessible, tooltip);
        }
        deetty_grid_object_set_data_full(
            context->tab_label, "deetty-tab-tooltip-cache",
            g_strdup(tooltip), g_free);
    }
    if (deetty_grid_widget_is_type(tab_widget, DEETTY_GTK_EVENT_BOX)) {
        const char *cached_name = deetty_grid_object_get_data(
            tab_widget, "deetty-tab-accessible-name-cache");
        if (g_strcmp0(cached_name, title) != 0) {
            set_widget_accessible_name(
                tab_widget, title != NULL ? title : "DEETTY tab");
            deetty_grid_object_set_data_full(
                tab_widget, "deetty-tab-accessible-name-cache",
                g_strdup(title != NULL ? title : "DEETTY tab"), g_free);
        }
    }
    GtkWidget *close_button = tab_close_button_from_widget(tab_widget);
    if (deetty_grid_widget_is_type(close_button, DEETTY_GTK_BUTTON)) {
        const gchar *cached_close_name = deetty_grid_object_get_data(
            close_button, "deetty-tab-close-name-cache");
        if (g_strcmp0(cached_close_name, close_name) != 0) {
            deetty_grid_widget_set_tooltip_text(close_button, close_name);
            set_widget_accessible_name(close_button, close_name);
            deetty_grid_object_set_data_full(
                close_button, "deetty-tab-close-name-cache",
                g_strdup(close_name), g_free);
        }
    }
    if (root->workspace_smoke == 3 && is_active) {
        root->tab_active_styled = 1;
        GtkWidget *close = tab_close_button_from_widget(tab_widget);
        root->tab_close_button_visible = close != NULL &&
            deetty_grid_widget_get_visible(close) && deetty_grid_widget_get_mapped(close);
    }
    deetty_grid_memory_free(basename);
    deetty_grid_memory_free(title);
}

static void on_notebook_switch_page(GtkNotebook *notebook, GtkWidget *page,
                                    guint page_num, gpointer user_data) {
    (void)notebook;
    (void)page_num;
    DeettyGridContext *root = root_grid_context(user_data);
    if (root->tab_rename_entry != NULL && root->tab_rename_page != page)
        finish_tab_rename(root, FALSE);
    for (guint index = 0; root->contexts != NULL && index < root->contexts->len; index++) {
        DeettyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (candidate->active && candidate->page != NULL)
            update_compact_tab(candidate);
    }
    apply_smart_filter(root);
    apply_panel_layout_metrics(root);
    refresh_active_pane_info(root);
}

static gboolean close_grid_tab(DeettyGridContext *context, GtkWidget *page);

static void clear_tab_rename_error(DeettyGridContext *root) {
    if (!deetty_grid_widget_is_type(root->tab_rename_entry, DEETTY_GTK_ENTRY)) return;
    GtkStyleContext *style = deetty_grid_widget_get_style_context(root->tab_rename_entry);
    deetty_grid_style_context_remove_class(style, "error");
    deetty_grid_entry_set_icon_from_icon_name(GTK_ENTRY(root->tab_rename_entry),
                                      GTK_ENTRY_ICON_SECONDARY, NULL);
    deetty_grid_widget_set_tooltip_text(
        root->tab_rename_entry,
        deetty_grid_tab_rename_feedback_message(0));
}

static void set_tab_rename_error(DeettyGridContext *root,
                                 const gchar *message) {
    if (!deetty_grid_widget_is_type(root->tab_rename_entry, DEETTY_GTK_ENTRY)) return;
    GtkStyleContext *style = deetty_grid_widget_get_style_context(root->tab_rename_entry);
    deetty_grid_style_context_add_class(style, "error");
    deetty_grid_entry_set_icon_from_icon_name(GTK_ENTRY(root->tab_rename_entry),
                                      GTK_ENTRY_ICON_SECONDARY,
                                      "dialog-warning-symbolic");
    deetty_grid_entry_set_icon_tooltip_text(GTK_ENTRY(root->tab_rename_entry),
                                    GTK_ENTRY_ICON_SECONDARY, message);
    deetty_grid_widget_set_tooltip_text(root->tab_rename_entry, message);
}

static void finish_tab_rename(DeettyGridContext *context,
                              gboolean restore_terminal_focus) {
    DeettyGridContext *root = root_grid_context(context);
    GtkWidget *entry = root->tab_rename_entry;
    GtkWidget *page = root->tab_rename_page;
    GtkWidget *event_box = root->tab_rename_event_box;
    DeettyGridContext *target = grid_context_for_page(root, page);

    root->tab_rename_entry = NULL;
    root->tab_rename_page = NULL;
    root->tab_rename_event_box = NULL;
    if (deetty_grid_widget_is_type(event_box, DEETTY_GTK_EVENT_BOX))
        deetty_grid_event_box_set_above_child(GTK_EVENT_BOX(event_box), FALSE);
    if (deetty_grid_widget_is_type(entry, DEETTY_GTK_WIDGET)) deetty_grid_widget_destroy(entry);
    if (target != NULL && target->tab_label != NULL) {
        deetty_grid_widget_set_no_show_all(target->tab_label, FALSE);
        deetty_grid_widget_show(target->tab_label);
        update_compact_tab(target);
    }
    if (restore_terminal_focus && target != NULL && target->area != NULL) {
        deetty_grid_focus_widget(NULL, target->area);
        root->tab_rename_focus_restored = 1;
    }
}

static gboolean apply_tab_rename(DeettyGridContext *root) {
    if (!deetty_grid_widget_is_type(root->tab_rename_entry, DEETTY_GTK_ENTRY))
        return FALSE;
    GtkWidget *page = root->tab_rename_page;
    DeettyGridContext *target = grid_context_for_page(root, page);
    if (target == NULL) {
        set_tab_rename_error(
            root, deetty_grid_tab_rename_feedback_message(1));
        return FALSE;
    }
    const char *raw = deetty_grid_entry_get_text(
        GTK_ENTRY(root->tab_rename_entry));
    const size_t raw_length = raw != NULL ? strlen(raw) : 0;
    DeettyGridTabRenamePlan plan = {0};
    deetty_grid_tab_rename_plan(
        (const unsigned char *)raw, raw_length, &plan);
    if (plan.valid == 0) {
        set_tab_rename_error(root, plan.message);
        return FALSE;
    }
    gchar *title = g_strndup(raw + plan.start, plan.length);
    if (title == NULL) {
        set_tab_rename_error(
            root, deetty_grid_tab_rename_feedback_message(2));
        return FALSE;
    }
    if (root->event_data == NULL ||
        deetty_grid_rename_tab(root->event_data, target->pane_id,
                               title, plan.length) != 0) {
        set_tab_rename_error(
            root, deetty_grid_tab_rename_feedback_message(2));
        deetty_grid_memory_free(title);
        return FALSE;
    }
    root->tab_rename_applied = 1;
    deetty_grid_memory_free(title);
    finish_tab_rename(root, TRUE);
    return TRUE;
}


static void on_tab_rename_entry_destroy(GtkWidget *widget, gpointer user_data) {
    DeettyGridContext *root = user_data;
    if (root->tab_rename_entry != widget) return;
    GtkWidget *page = root->tab_rename_page;
    GtkWidget *event_box = root->tab_rename_event_box;
    root->tab_rename_entry = NULL;
    root->tab_rename_page = NULL;
    root->tab_rename_event_box = NULL;
    if (deetty_grid_widget_is_type(event_box, DEETTY_GTK_EVENT_BOX))
        deetty_grid_event_box_set_above_child(GTK_EVENT_BOX(event_box), FALSE);
    DeettyGridContext *target = grid_context_for_page(root, page);
    if (target != NULL && target->tab_label != NULL) {
        deetty_grid_widget_set_no_show_all(target->tab_label, FALSE);
        deetty_grid_widget_show(target->tab_label);
        update_compact_tab(target);
    }
}

static void on_tab_rename_activate(GtkEntry *entry, gpointer user_data) {
    (void)entry;
    (void)apply_tab_rename(root_grid_context(user_data));
}

static gboolean on_tab_rename_key(GtkWidget *widget, GdkEventKey *event,
                                  gpointer user_data) {
    (void)widget;
    if (event->keyval != GDK_KEY_Escape) return FALSE;
    finish_tab_rename(root_grid_context(user_data), TRUE);
    return TRUE;
}

static gboolean on_tab_rename_focus_out(GtkWidget *widget,
                                        GdkEventFocus *event,
                                        gpointer user_data) {
    (void)event;
    DeettyGridContext *root = root_grid_context(user_data);
    if (root->tab_rename_entry != widget) return FALSE;
    finish_tab_rename(root, FALSE);
    return FALSE;
}

static void open_tab_rename(DeettyGridContext *context, GtkWidget *page) {
    DeettyGridContext *root = root_grid_context(context);
    DeettyGridContext *target = grid_context_for_page(root, page);
    if (target == NULL) return;
    if (root->tab_rename_entry != NULL && root->tab_rename_page == page) {
        clear_tab_rename_error(root);
        deetty_grid_focus_widget(NULL, root->tab_rename_entry);
        deetty_grid_editable_select_region(GTK_EDITABLE(root->tab_rename_entry), 0, -1);
        return;
    }
    if (root->tab_rename_entry != NULL) finish_tab_rename(root, FALSE);

    GtkWidget *tab_widget = page != NULL
        ? deetty_grid_notebook_get_tab_label(GTK_NOTEBOOK(root->notebook), page)
        : NULL;
    if (!deetty_grid_widget_is_type(tab_widget, DEETTY_GTK_EVENT_BOX)) return;
    GtkWidget *content = deetty_grid_bin_get_child(GTK_BIN(tab_widget));
    if (!deetty_grid_widget_is_type(content, DEETTY_GTK_BOX) ||
        target->tab_label == NULL) return;
    gchar *title = current_tab_title_alloc(target);
    gint title_length = (gint)g_utf8_strlen(title, -1);
    GtkWidget *entry = deetty_tab_rename_entry_new(
        title, deetty_grid_tab_title_width(title_length),
        root->compact_tab_height);
    deetty_grid_memory_free(title);
    if (entry == NULL) return;
    deetty_box_pack_start(content, entry, TRUE, TRUE, 0);
    deetty_box_reorder_child(content, entry, 0);
    deetty_grid_widget_set_no_show_all(target->tab_label, TRUE);
    deetty_grid_widget_hide(target->tab_label);
    deetty_grid_event_box_set_above_child(GTK_EVENT_BOX(tab_widget), FALSE);
    root->tab_rename_entry = entry;
    root->tab_rename_page = page;
    root->tab_rename_event_box = tab_widget;
    root->tab_rename_inline_shown = 1;
    root->tab_rename_inline_embedded =
        deetty_grid_widget_get_toplevel(entry) == root->window;
    deetty_grid_signal_connect(entry, "activate", G_CALLBACK(on_tab_rename_activate), root);
    deetty_grid_signal_connect(entry, "key-press-event", G_CALLBACK(on_tab_rename_key), root);
    deetty_grid_signal_connect(entry, "focus-out-event", G_CALLBACK(on_tab_rename_focus_out), root);
    deetty_grid_signal_connect(entry, "destroy", G_CALLBACK(on_tab_rename_entry_destroy), root);
    deetty_grid_widget_show(entry);
    deetty_grid_focus_widget(NULL, entry);
    deetty_grid_editable_select_region(GTK_EDITABLE(entry), 0, -1);
}

static void show_tab_menu(DeettyGridContext *context, GtkWidget *page,
                          GdkEventButton *event);

static gboolean on_tab_button_press(GtkWidget *widget, GdkEventButton *event,
                                    gpointer user_data) {
    GtkWidget *page = deetty_grid_object_get_data(widget, "deetty-tab-page");
    if (page == NULL) return FALSE;
    DeettyGridContext *root = root_grid_context(user_data);
    if (event->button == 1 && event->type == GDK_BUTTON_PRESS) {
        gint active_index = deetty_grid_notebook_get_current_page(
            GTK_NOTEBOOK(root->notebook));
        root->tab_reorder_pressed_active_page = active_index >= 0
            ? deetty_grid_notebook_get_nth_page(GTK_NOTEBOOK(root->notebook),
                                        active_index)
            : NULL;
        root->tab_reorder_pointer_press_seen = 1;
    }
    if (event->button == 3 && event->type == GDK_BUTTON_PRESS) {
        show_tab_menu(root, page, event);
        return TRUE;
    }
    if (event->button != 1 || event->type != GDK_2BUTTON_PRESS) return FALSE;
    root->tab_rename_double_click_seen = 1;
    open_tab_rename(root, page);
    return TRUE;
}

static gboolean on_tab_button_release(GtkWidget *widget,
                                      GdkEventButton *event,
                                      gpointer user_data) {
    (void)widget;
    DeettyGridContext *root = root_grid_context(user_data);
    if (event->button == 1 && event->type == GDK_BUTTON_RELEASE) {
        root->tab_reorder_pointer_release_seen = 1;
        if (!root->tab_reorder_dragging)
            root->tab_reorder_pressed_active_page = NULL;
    }
    return FALSE;
}

static void on_notebook_drag_begin(GtkWidget *widget, GdkDragContext *drag,
                                   gpointer user_data) {
    (void)widget;
    (void)drag;
    DeettyGridContext *root = root_grid_context(user_data);
    root->tab_reorder_dragging = 1;
    root->tab_reorder_drag_begin_seen = 1;
    root->tab_reorder_drag_active_page =
        root->tab_reorder_pressed_active_page;
    if (root->tab_reorder_drag_active_page == NULL) {
        gint active_index = deetty_grid_notebook_get_current_page(
            GTK_NOTEBOOK(root->notebook));
        root->tab_reorder_drag_active_page = active_index >= 0
            ? deetty_grid_notebook_get_nth_page(GTK_NOTEBOOK(root->notebook),
                                        active_index)
            : NULL;
    }
}

static void on_notebook_drag_end(GtkWidget *widget, GdkDragContext *drag,
                                 gpointer user_data) {
    (void)widget;
    (void)drag;
    DeettyGridContext *root = root_grid_context(user_data);
    GtkWidget *active_page = root->tab_reorder_drag_active_page;
    if (active_page != NULL) {
        gint active_index = deetty_grid_notebook_page_num(
            GTK_NOTEBOOK(root->notebook), active_page);
        if (active_index >= 0)
            deetty_grid_notebook_select_page(root->notebook, active_index);
    }
    root->tab_reorder_drag_end_seen = root->tab_reorder_count > 0;
    root->tab_reorder_dragging = 0;
    root->tab_reorder_pressed_active_page = NULL;
    root->tab_reorder_drag_active_page = NULL;
    if (root->tab_reorder_count > 0)
        schedule_grid_hot_session_flush(root);
}

static void on_tab_close_button_clicked(GtkButton *button, gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    GtkWidget *page = deetty_grid_object_get_data(button, "deetty-tab-page");
    (void)close_grid_tab(root, page);
}

static GtkWidget *create_compact_tab_widget(DeettyGridContext *context,
                                            GtkWidget *page,
                                            const gchar *text) {
    DeettyGridContext *root = root_grid_context(context);
    DeettyCompactTabOptions options = {
        .page = page,
        .text = text,
        .callback_data = root,
    };
    DeettyCompactTabCallbacks callbacks = {
        .button_press = G_CALLBACK(on_tab_button_press),
        .button_release = G_CALLBACK(on_tab_button_release),
        .drag_begin = G_CALLBACK(on_notebook_drag_begin),
        .drag_end = G_CALLBACK(on_notebook_drag_end),
        .close_clicked = G_CALLBACK(on_tab_close_button_clicked),
    };
    DeettyCompactTabContents contents = {0};
    if (!deetty_compact_tab_new(&options, &callbacks, &contents))
        return NULL;
    return contents.tab;
}

static void on_new_tab_button_clicked(GtkButton *button, gpointer user_data) {
    (void)button;
    DeettyGridContext *target = active_grid_context(user_data);
    if (target != NULL && target->active && !target->exited &&
        target->area != NULL)
        emit_grid_workspace_event(target, DEETTY_GRID_HOST_EVENT(WORKSPACE_NEW_TAB));
}

static void on_notebook_page_reordered(GtkNotebook *notebook, GtkWidget *page,
                                       guint page_num, gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    if (root->layout_restore_applying || root->tab_reorder_syncing) return;
    DeettyGridContext *representative = grid_context_for_page(root, page);
    if (representative == NULL || root->event_data == NULL) return;
    GtkWidget *active_page = root->tab_reorder_dragging
        ? root->tab_reorder_drag_active_page
        : root->tab_reorder_pressed_active_page;
    if (active_page == NULL) {
        gint active_index = deetty_grid_notebook_get_current_page(notebook);
        active_page = active_index >= 0
            ? deetty_grid_notebook_get_nth_page(notebook, active_index) : NULL;
    }
    if (deetty_grid_reorder_tab(root->event_data, representative->pane_id,
                                (int)page_num) != 0) {
        int model_index = deetty_grid_tab_index_for_pane(
            root->event_data, representative->pane_id);
        if (model_index >= 0) {
            root->tab_reorder_syncing = 1;
            deetty_grid_notebook_reorder_child(notebook, page, model_index);
            root->tab_reorder_syncing = 0;
        }
        return;
    }
    root->tab_reorder_count++;
    gint active_page_num = active_page != NULL
        ? deetty_grid_notebook_page_num(notebook, active_page) : -1;
    if (active_page_num >= 0)
        deetty_grid_notebook_select_page(GTK_WIDGET(notebook), active_page_num);
    update_compact_tab(representative);
    schedule_grid_hot_session_flush(root);
}

static GtkWidget *create_new_tab_button(DeettyGridContext *context) {
    DeettyGridContext *root = root_grid_context(context);
    DeettyGridCompactTabMetrics tab_metrics = {0};
    deetty_grid_compact_tab_metrics(root->compact_tab_height, &tab_metrics);
    return deetty_new_tab_button_new(
        tab_metrics.action_extent, root, G_CALLBACK(on_new_tab_button_clicked));
}

static void on_recovery_notice_response(GtkInfoBar *bar, gint response_id,
                                        gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    if (response_id == GTK_RESPONSE_APPLY) open_grid_settings(root);
    deetty_grid_widget_hide(GTK_WIDGET(bar));
}

static GtkWidget *create_recovery_notice(DeettyGridContext *context) {
    DeettyGridContext *root = root_grid_context(context);
    guint32 flags = root->recovery_notice_flags;
    if (flags == 0) return NULL;

    char message[1024];
    int message_length = deetty_grid_recovery_notice_text(
        flags, (unsigned char *)message, sizeof(message));
    if (message_length <= 0) return NULL;

    GtkWidget *bar = deetty_recovery_notice_new(
        message, GTK_RESPONSE_APPLY, GTK_RESPONSE_CLOSE);
    if (bar == NULL) return NULL;
    deetty_grid_signal_connect(bar, "response",
                     G_CALLBACK(on_recovery_notice_response), root);
    g_print("deetty_startup_recovery_notice flags=%u "
            "config_backup=%d config_defaults=%d theme_backup=%d "
            "theme_defaults=%d workspace_defaults=%d\n",
            flags,
            (flags & DEETTY_GRID_RECOVERY_CONFIG_BACKUP) != 0,
            (flags & DEETTY_GRID_RECOVERY_CONFIG_DEFAULTS) != 0,
            (flags & DEETTY_GRID_RECOVERY_THEME_BACKUP) != 0,
            (flags & DEETTY_GRID_RECOVERY_THEME_DEFAULTS) != 0,
            (flags & DEETTY_GRID_RECOVERY_WORKSPACE_DEFAULTS) != 0);
    return bar;
}

static void on_window_settings_button_clicked(GtkButton *button,
                                              gpointer user_data) {
    (void)button;
    DeettyGridContext *root = root_grid_context(user_data);
    root->window_settings_button_activated = 1;
    open_grid_settings(root);
}

static void on_window_close_button_clicked(GtkButton *button,
                                           gpointer user_data) {
    (void)button;
    DeettyGridContext *root = root_grid_context(user_data);
    root->window_close_button_activated = 1;
    (void)request_grid_application_close(
        root, DEETTY_CLOSE_ORIGIN_TOOLBAR);
}

static void update_window_toolbar_controls(DeettyGridContext *context) {
    DeettyGridContext *root = root_grid_context(context);
    deetty_window_toolbar_set_close_visible(
        root->window_close_button, root->mode != 1);
}

static GtkWidget *create_window_toolbar_controls(DeettyGridContext *context) {
    DeettyGridContext *root = root_grid_context(context);
    DeettyWindowToolbarCallbacks callbacks = {
        .settings_clicked = G_CALLBACK(on_window_settings_button_clicked),
        .close_clicked = G_CALLBACK(on_window_close_button_clicked),
    };
    DeettyWindowToolbarContents contents = {0};
    DeettyGridCompactTabMetrics tab_metrics = {0};
    deetty_grid_compact_tab_metrics(root->compact_tab_height, &tab_metrics);
    if (!deetty_window_toolbar_new(
            tab_metrics.action_extent, root, &callbacks, &contents))
        return NULL;
    root->window_toolbar_controls = contents.controls;
    root->window_settings_button = contents.settings;
    root->window_close_button = contents.close_button;
    update_window_toolbar_controls(root);
    return contents.controls;
}

static gboolean request_new_tab_button_smoke(gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    GtkWidget *button = root->new_tab_button;
    GtkWidget *icon = deetty_grid_widget_is_type(button, DEETTY_GTK_BUTTON)
        ? deetty_grid_button_get_image(GTK_BUTTON(button))
        : NULL;
    const gchar *icon_name = NULL;
    GtkIconSize icon_size = GTK_ICON_SIZE_INVALID;
    if (deetty_grid_widget_is_type(icon, DEETTY_GTK_IMAGE))
        deetty_grid_image_get_icon_name(GTK_IMAGE(icon), &icon_name, &icon_size);
    AtkObject *accessible = button != NULL
        ? deetty_grid_widget_get_accessible(button)
        : NULL;
    root->new_tab_button_visible = button != NULL &&
        deetty_grid_notebook_get_n_pages(GTK_NOTEBOOK(root->notebook)) == 1 &&
        deetty_grid_notebook_get_show_tabs(GTK_NOTEBOOK(root->notebook)) &&
        deetty_grid_widget_get_mapped(button);
    root->new_tab_button_at_start = button != NULL &&
        deetty_grid_notebook_get_action_widget(GTK_NOTEBOOK(root->notebook),
                                       GTK_PACK_START) == button;
    root->new_tab_button_icon = deetty_grid_widget_is_type(icon, DEETTY_GTK_IMAGE) &&
        icon_size == GTK_ICON_SIZE_MENU &&
        g_strcmp0(icon_name, "list-add-symbolic") == 0;
    root->new_tab_button_accessible = accessible != NULL &&
        g_strcmp0(deetty_grid_atk_object_get_name(accessible), "New Tab, Ctrl+Shift+T") == 0;
    if (button != NULL) deetty_grid_button_clicked(GTK_BUTTON(button));
    root->new_tab_button_clicked =
        deetty_grid_notebook_get_n_pages(GTK_NOTEBOOK(root->notebook)) == 2 &&
        deetty_grid_notebook_get_current_page(GTK_NOTEBOOK(root->notebook)) == 1;
    return G_SOURCE_REMOVE;
}

static gboolean inspect_compact_tab_geometry_smoke(gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    gint page_count = deetty_grid_notebook_get_n_pages(GTK_NOTEBOOK(root->notebook));
    gint active_index = deetty_grid_notebook_get_current_page(
        GTK_NOTEBOOK(root->notebook));
    GtkWidget *page = active_index >= 0
        ? deetty_grid_notebook_get_nth_page(GTK_NOTEBOOK(root->notebook), active_index)
        : NULL;
    GtkWidget *tab_widget = page != NULL
        ? deetty_grid_notebook_get_tab_label(GTK_NOTEBOOK(root->notebook), page)
        : NULL;
    GtkWidget *close = tab_close_button_from_widget(tab_widget);
    GtkWidget *close_icon = deetty_grid_widget_is_type(close, DEETTY_GTK_BUTTON)
        ? deetty_grid_button_get_image(GTK_BUTTON(close))
        : NULL;
    const gchar *close_icon_name = NULL;
    GtkIconSize close_icon_size = GTK_ICON_SIZE_INVALID;
    if (deetty_grid_widget_is_type(close_icon, DEETTY_GTK_IMAGE))
        deetty_grid_image_get_icon_name(GTK_IMAGE(close_icon),
                                        &close_icon_name, &close_icon_size);
    AtkObject *tab_accessible = tab_widget != NULL
        ? deetty_grid_widget_get_accessible(tab_widget) : NULL;
    const gchar *tab_accessible_name = tab_accessible != NULL
        ? deetty_grid_atk_object_get_name(tab_accessible) : NULL;
    const gchar *tab_accessible_description = tab_accessible != NULL
        ? deetty_grid_atk_object_get_description(tab_accessible) : NULL;
    gboolean tab_accessible_named =
        tab_accessible_name != NULL && tab_accessible_name[0] != '\0' &&
        tab_accessible_description != NULL &&
        tab_accessible_description[0] != '\0';
    GtkAllocation notebook_allocation = {0};
    GtkAllocation page_allocation = {0};
    GtkAllocation tab_allocation = {0};
    GtkAllocation close_allocation = {0};
    GtkAllocation action_allocation = {0};
    if (root->notebook != NULL)
        deetty_grid_widget_get_allocation(root->notebook, &notebook_allocation);
    if (page != NULL) deetty_grid_widget_get_allocation(page, &page_allocation);
    if (tab_widget != NULL)
        deetty_grid_widget_get_allocation(tab_widget, &tab_allocation);
    if (close != NULL) deetty_grid_widget_get_allocation(close, &close_allocation);
    if (root->new_tab_button != NULL)
        deetty_grid_widget_get_allocation(root->new_tab_button, &action_allocation);
    GtkPositionType position = (GtkPositionType)deetty_grid_notebook_get_tab_pos(
        GTK_NOTEBOOK(root->notebook));
    gboolean horizontal = position == GTK_POS_TOP || position == GTK_POS_BOTTOM;
    root->compact_tab_max_width = tab_allocation.width;
    for (gint index = 1; index < page_count; index++) {
        GtkWidget *candidate_page = deetty_grid_notebook_get_nth_page(
            GTK_NOTEBOOK(root->notebook), index);
        GtkWidget *candidate_tab = deetty_grid_notebook_get_tab_label(
            GTK_NOTEBOOK(root->notebook), candidate_page);
        GtkAllocation candidate_allocation = {0};
        if (candidate_tab != NULL)
            deetty_grid_widget_get_allocation(candidate_tab, &candidate_allocation);
        root->compact_tab_max_width = MAX(root->compact_tab_max_width,
                                          candidate_allocation.width);
    }
    DeettyGridCompactTabMeasurements measurements = {
        .horizontal = horizontal,
        .notebook_width = notebook_allocation.width,
        .notebook_height = notebook_allocation.height,
        .page_width = page_allocation.width,
        .page_height = page_allocation.height,
        .tab_width = tab_allocation.width,
        .tab_height = tab_allocation.height,
        .max_tab_width = root->compact_tab_max_width,
        .close_width = close_allocation.width,
        .close_height = close_allocation.height,
        .action_width = action_allocation.width,
        .action_height = action_allocation.height,
    };
    DeettyGridCompactTabGeometry geometry = {0};
    deetty_grid_compact_tab_geometry(&measurements, &geometry);
    root->compact_tab_strip_extent = geometry.strip_extent;
    root->compact_tab_widget_extent = geometry.widget_extent;
    root->compact_tab_max_width = geometry.max_width;
    root->compact_tab_close_extent = geometry.close_extent;
    root->compact_tab_action_extent = geometry.action_extent;
    DeettyGridCompactTabMetrics tab_metrics = {0};
    deetty_grid_compact_tab_metrics(root->compact_tab_height, &tab_metrics);
    root->compact_tab_geometry = page_count == 2 && horizontal &&
        tab_accessible_named &&
        close != NULL && deetty_grid_widget_get_visible(close) &&
        deetty_grid_widget_get_mapped(close) &&
        root->compact_tab_strip_extent > 0 &&
        root->compact_tab_strip_extent <= tab_metrics.strip_limit &&
        root->compact_tab_widget_extent <= tab_metrics.strip_limit &&
        root->compact_tab_max_width <= 150 &&
        deetty_grid_widget_is_type(close_icon, DEETTY_GTK_IMAGE) &&
        close_icon_size == GTK_ICON_SIZE_MENU &&
        g_strcmp0(close_icon_name, "window-close-symbolic") == 0 &&
        root->compact_tab_close_extent >= 24 &&
        root->compact_tab_close_extent <= 30 &&
        root->compact_tab_action_extent >= 24 &&
        root->compact_tab_action_extent <= 30;
    return G_SOURCE_REMOVE;
}

static gboolean request_tab_rename_smoke(gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    gint page_index = deetty_grid_notebook_get_current_page(
        GTK_NOTEBOOK(root->notebook));
    GtkWidget *page = deetty_grid_notebook_get_nth_page(
        GTK_NOTEBOOK(root->notebook), 1);
    GtkWidget *tab_widget = deetty_grid_notebook_get_tab_label(
        GTK_NOTEBOOK(root->notebook), page);
    DeettyGridContext *target = grid_context_for_page(root, page);
    gboolean ready = deetty_grid_notebook_get_n_pages(GTK_NOTEBOOK(root->notebook)) == 2 &&
        page_index == 1 && page != NULL && tab_widget != NULL &&
        deetty_grid_widget_get_mapped(tab_widget) && target != NULL &&
        root->saw_draw && target->saw_draw;
    if (!ready) {
        if (root->project_smoke_attempts++ < 200) {
            gint pending_index = root->saw_draw ? 1 : 0;
            deetty_grid_notebook_select_page(root->notebook, pending_index);
            DeettyGridContext *pending = pending_index == 0 ? root : target;
            if (pending != NULL && pending->area != NULL)
                deetty_grid_widget_queue_draw(pending->area);
            deetty_grid_source_timeout_add(25, request_tab_rename_smoke, root);
            return G_SOURCE_REMOVE;
        }
        for (guint index = 0; root->contexts != NULL &&
             index < root->contexts->len; index++) {
            DeettyGridContext *candidate =
                g_ptr_array_index(root->contexts, index);
            if (candidate->active && candidate->write != NULL)
                (void)candidate->write(candidate->userdata, "done\n", 5);
        }
        return G_SOURCE_REMOVE;
    }
    root->project_smoke_attempts = 0;
    gchar *original_title = target != NULL
        ? current_tab_title_alloc(target) : NULL;
    if (tab_widget != NULL) {
        GdkEventButton event = {0};
        event.type = GDK_2BUTTON_PRESS;
        event.button = 1;
        (void)on_tab_button_press(tab_widget, &event, root);
    }
    if (root->tab_rename_entry != NULL && target != NULL) {
        deetty_grid_entry_set_text(GTK_ENTRY(root->tab_rename_entry),
                           "Cancelled tab rename");
        GdkEventButton outside = {0};
        outside.type = GDK_BUTTON_PRESS;
        outside.button = 1;
        outside.x = 4;
        outside.y = 4;
        (void)on_mouse_button(target->area, &outside, target);
        outside.type = GDK_BUTTON_RELEASE;
        (void)on_mouse_button(target->area, &outside, target);
        if (root->tab_rename_entry != NULL) {
            GdkEventFocus focus = {0};
            (void)on_tab_rename_focus_out(
                root->tab_rename_entry, &focus, root);
        }
        gchar *after_cancel = current_tab_title_alloc(target);
        const gchar *label = target->tab_label != NULL
            ? deetty_grid_label_get_text(GTK_LABEL(target->tab_label)) : "";
        root->tab_rename_outside_cancelled =
            root->tab_rename_entry == NULL && original_title != NULL &&
            g_strcmp0(original_title, after_cancel) == 0 &&
            strstr(label, "Cancelled tab rename") == NULL;
        deetty_grid_memory_free(after_cancel);

        GdkEventButton event = {0};
        event.type = GDK_2BUTTON_PRESS;
        event.button = 1;
        (void)on_tab_button_press(tab_widget, &event, root);
    }
    if (root->tab_rename_entry != NULL) {
        deetty_grid_entry_set_text(GTK_ENTRY(root->tab_rename_entry), "Build logs");
        g_signal_emit_by_name(root->tab_rename_entry, "activate");
    }
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        DeettyGridContext *candidate =
            g_ptr_array_index(root->contexts, index);
        if (candidate->active && candidate->write != NULL)
            (void)candidate->write(candidate->userdata, "done\n", 5);
    }
    deetty_grid_memory_free(original_title);
    return G_SOURCE_REMOVE;
}

static void apply_panel_layout_metrics(DeettyGridContext *root) {
    if (deetty_grid_widget_is_type(root->notebook, DEETTY_GTK_NOTEBOOK)) {
        int pages = deetty_grid_notebook_get_n_pages(GTK_NOTEBOOK(root->notebook));
        for (int index = 0; index < pages; index++) {
            GtkWidget *page = deetty_grid_notebook_get_nth_page(
                GTK_NOTEBOOK(root->notebook), index);
            if (deetty_grid_widget_is_type(page, DEETTY_GTK_CONTAINER))
                deetty_container_set_border_width(
                    page, (guint)root->panel_padding_px);
            DeettyGridContext *representative =
                grid_context_for_page(root, page);
            uint32_t gap_rgb = representative != NULL &&
                    root->event_data != NULL
                ? deetty_grid_pane_gap_rgb(
                      root->event_data, representative->pane_id)
                : 0x0b0d12u;
            gboolean gap_opaque = root->pane_gaps_enabled &&
                !root->pane_gaps_transparent;
            deetty_apply_pane_gap_style(page, gap_rgb, gap_opaque);
        }
        deetty_apply_pane_divider_style(
            root->notebook, root->pane_divider_px);
    }
    DeettyGridPanelSpacingPlan spacing = {0};
    deetty_grid_panel_spacing_plan(
        root->pane_gaps_enabled, root->pane_spacing_px, &spacing);
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        DeettyGridContext *candidate =
            g_ptr_array_index(root->contexts, index);
        if (candidate->area == NULL) continue;
        deetty_grid_widget_set_margins(
            candidate->area,
            spacing.leading,
            spacing.leading,
            spacing.trailing,
            spacing.trailing);
    }
}

static void update_notebook_chrome(DeettyGridContext *context) {
    DeettyGridContext *root = root_grid_context(context);
    DeettyGridNotebookChromePlan chrome = {0};
    deetty_grid_notebook_chrome_plan(
        root->zoomed_pane_id,
        deetty_grid_notebook_get_n_pages(GTK_NOTEBOOK(root->notebook)),
        &chrome);
    deetty_grid_notebook_apply_policy(
        root->notebook, root->window_toolbar_controls,
        root->tab_position, chrome.show != 0);
}

typedef struct {
    DeettyGridContext *root;
    uint64_t pane_id;
    int exit_code;
    int attention;
    char title[129];
    char body[1025];
} DeettyNotificationRequest;

static void on_grid_notification_sent(GObject *source, GAsyncResult *result,
                                      gpointer user_data) {
    DeettyNotificationRequest *request = user_data;
    GError *error = NULL;
    GVariant *reply = g_dbus_connection_call_finish(
        G_DBUS_CONNECTION(source), result, &error);
    if (reply != NULL) {
        request->root->notification_delivered = 1;
        deetty_grid_variant_unref(reply);
    }
    deetty_grid_error_clear(&error);
    finish_grid_dbus_operation(request->root);
    deetty_grid_memory_free(request);
}

static void on_grid_notification_bus_ready(GObject *source,
                                           GAsyncResult *result,
                                           gpointer user_data) {
    (void)source;
    DeettyNotificationRequest *request = user_data;
    DeettyGridLifecycleTimingPlan timing = {0};
    deetty_grid_lifecycle_timing_plan(&timing);
    GError *error = NULL;
    GDBusConnection *bus = g_bus_get_finish(result, &error);
    if (bus == NULL) {
        deetty_grid_error_clear(&error);
        finish_grid_dbus_operation(request->root);
        deetty_grid_memory_free(request);
        return;
    }
    char fallback_body[256];
    const char *body = request->body[0] != '\0'
        ? request->body
        : fallback_body;
    if (request->body[0] == '\0' &&
        deetty_grid_attention_notification_text(
            request->pane_id, request->attention, request->exit_code,
            (unsigned char *)fallback_body, sizeof(fallback_body)) <= 0) {
        finish_grid_dbus_operation(request->root);
        deetty_grid_memory_free(request);
        deetty_grid_object_unref(bus);
        return;
    }
    const char *summary =
        request->attention && request->title[0] != '\0'
            ? request->title
            : request->attention ? "Terminal needs attention"
                                  : "Terminal finished";
    GVariantBuilder hints;
    g_variant_builder_init(&hints, G_VARIANT_TYPE("a{sv}"));
    g_dbus_connection_call(
        bus, "org.freedesktop.Notifications",
        "/org/freedesktop/Notifications", "org.freedesktop.Notifications",
        "Notify",
        g_variant_new("(susss@as@a{sv}i)", "DEETTY", 0u,
                      "com.lichforge.DEETTY",
                      summary,
                      body,
                      g_variant_new_strv(NULL, 0),
                      g_variant_builder_end(&hints),
                      timing.dbus_notification_timeout_ms),
        G_VARIANT_TYPE("(u)"), G_DBUS_CALL_FLAGS_NONE,
        timing.dbus_operation_timeout_ms,
        request->root->dbus_cancellable, on_grid_notification_sent, request);
    deetty_grid_object_unref(bus);
}

static void send_exit_notification(DeettyGridContext *context, int exit_code) {
    if (!context->enable_notifications) return;
    DeettyGridContext *root = root_grid_context(context);
    DeettyNotificationRequest *request = g_new0(DeettyNotificationRequest, 1);
    request->root = root;
    request->pane_id = context->pane_id;
    request->exit_code = exit_code;
    begin_grid_dbus_operation(root);
    g_bus_get(G_BUS_TYPE_SESSION, root->dbus_cancellable,
              on_grid_notification_bus_ready, request);
}

static void send_attention_notification(DeettyGridContext *context,
                                        gint64 now_us) {
    if (!context->enable_notifications || context->focused) return;
    if (now_us - context->last_desktop_notification_us < G_USEC_PER_SEC)
        return;
    context->last_desktop_notification_us = now_us;
    DeettyGridContext *root = root_grid_context(context);
    DeettyNotificationRequest *request = g_new0(DeettyNotificationRequest, 1);
    request->root = root;
    request->pane_id = context->pane_id;
    request->attention = 1;
    if (deetty_grid_notification_title(
            context->userdata, request->title, sizeof(request->title) - 1) < 0)
        request->title[0] = '\0';
    if (deetty_grid_notification_body(
            context->userdata, request->body, sizeof(request->body) - 1) < 0)
        request->body[0] = '\0';
    begin_grid_dbus_operation(root);
    g_bus_get(G_BUS_TYPE_SESSION, root->dbus_cancellable,
              on_grid_notification_bus_ready, request);
}

static gboolean all_grid_contexts_exited(DeettyGridContext *context) {
    if (context->contexts == NULL) return context->exited;
    for (guint index = 0; index < context->contexts->len; index++) {
        DeettyGridContext *candidate = g_ptr_array_index(context->contexts, index);
        if (candidate->active && !candidate->exited) return FALSE;
    }
    return TRUE;
}

static void queue_grid_draw_when_mapped(DeettyGridContext *context) {
    if (context->area != NULL && deetty_grid_widget_get_mapped(context->area))
        deetty_grid_widget_queue_draw(context->area);
}

static gboolean ensure_grid_dirty_rows(DeettyGridContext *context) {
    size_t required = deetty_grid_damage_buffer_capacity(context->rows);
    if (context->dirty_row_buffer != NULL &&
        context->dirty_row_capacity == required)
        return TRUE;
    uint8_t *dirty = g_try_realloc_n(context->dirty_row_buffer, required,
                                     sizeof(*dirty));
    if (dirty == NULL) return FALSE;
    context->dirty_row_buffer = dirty;
    context->dirty_row_capacity = required;
    context->damage_initialized = 0;
    return TRUE;
}

static gboolean ensure_grid_dirty_spans(DeettyGridContext *context) {
    size_t required = deetty_grid_damage_buffer_capacity(context->rows);
    if (context->dirty_span_buffer != NULL &&
        context->dirty_span_capacity == required)
        return TRUE;
    DeettyGridDirtySpan *dirty = g_try_realloc_n(
        context->dirty_span_buffer, required, sizeof(*dirty));
    if (dirty == NULL) return FALSE;
    context->dirty_span_buffer = dirty;
    context->dirty_span_capacity = required;
    context->damage_initialized = 0;
    return TRUE;
}

static void queue_grid_row_range(DeettyGridContext *context, int first,
                                 int end) {
    if (first < 0 || end <= first || context->area == NULL) return;
    GtkAllocation allocation;
    deetty_grid_widget_get_allocation(context->area, &allocation);
    DeettyGridFontMetrics metrics = grid_font_metrics(context);
    DeettyGridRectangle damage;
    deetty_grid_row_span(first, end, metrics.cell_height, &damage);
    DeettyGridDamageRect clipped;
    deetty_grid_damage_rect(
        0, damage.y, allocation.width, damage.height,
        allocation.width, allocation.height, &clipped);
    deetty_grid_widget_queue_draw_area(
        context->area, clipped.x, clipped.y, clipped.width, clipped.height);
    root_grid_context(context)->damage_rows_queued += (guint)(end - first);
    root_grid_context(context)->damage_cells_queued +=
        (guint)(end - first) * (guint)context->columns;
}

static void queue_grid_cell_span(DeettyGridContext *context, int row,
                                 int first, int end) {
    if (row < 0 || row >= context->rows || first < 0 || end <= first ||
        first >= context->columns || context->area == NULL)
        return;
    end = MIN(end, context->columns);
    GtkAllocation allocation;
    deetty_grid_widget_get_allocation(context->area, &allocation);
    DeettyGridFontMetrics metrics = grid_font_metrics(context);
    DeettyGridRectangle damage;
    deetty_grid_cell_span(
        first, end, row, metrics.cell_width, metrics.cell_height, 1, &damage);
    DeettyGridDamageRect clipped;
    deetty_grid_damage_rect(
        damage.x, damage.y, damage.width, damage.height,
        allocation.width, allocation.height, &clipped);
    deetty_grid_widget_queue_draw_area(
        context->area, clipped.x, clipped.y, clipped.width, clipped.height);
    DeettyGridContext *root = root_grid_context(context);
    root->damage_rows_queued++;
    root->damage_cells_queued += (guint)(end - first);
    root->damage_spans_queued++;
}

static void queue_grid_cursor_cell(DeettyGridContext *context,
                                   uint32_t packed_cursor) {
    if (context->area == NULL) return;
    DeettyGridCursorPosition cursor_position = {0};
    deetty_grid_cursor_position(packed_cursor, &cursor_position);
    if (cursor_position.valid == 0) return;
    int column = cursor_position.column;
    int row = cursor_position.row;
    if (column < 0 || column >= context->columns ||
        row < 0 || row >= context->rows) return;
    DeettyGridFontMetrics metrics = grid_font_metrics(context);
    DeettyGridDamageRect damage;
    deetty_grid_cursor_damage(
        column, row, metrics.cell_width, metrics.cell_height, &damage);
    deetty_grid_widget_queue_draw_area(
        context->area, damage.x, damage.y, damage.width, damage.height);
}

static void queue_grid_damage_when_mapped(DeettyGridContext *context) {
    if (context->area == NULL || !deetty_grid_widget_get_mapped(context->area)) return;
    uint32_t cursor = context->cursor(context->userdata);
    if (context->dirty_spans != NULL && ensure_grid_dirty_spans(context)) {
        int dirty_count = context->dirty_spans(
            context->userdata, context->dirty_span_buffer,
            context->dirty_span_capacity);
        if (dirty_count >= context->rows) {
            context->terminal_dirty_spans_used = 1;
            if (!context->damage_initialized) {
                context->damage_initialized = 1;
                context->last_cursor_position = cursor;
                DeettyGridContext *root = root_grid_context(context);
                root->damage_rows_queued += (guint)context->rows;
                root->damage_cells_queued +=
                    (guint)context->rows * (guint)context->columns;
                deetty_grid_widget_queue_draw(context->area);
                return;
            }
            for (int row = 0; row < context->rows; row++) {
                DeettyGridDirtySpan span = context->dirty_span_buffer[row];
                if (span.end > span.first)
                    queue_grid_cell_span(context, row, (int)span.first,
                                         (int)span.end);
            }
            if (cursor != context->last_cursor_position) {
                context->cursor_visible = 1;
                queue_grid_cursor_cell(context, context->last_cursor_position);
                queue_grid_cursor_cell(context, cursor);
                context->last_cursor_position = cursor;
            }
            return;
        }
        queue_grid_draw_when_mapped(context);
        return;
    }
    if (context->dirty_rows == NULL || !ensure_grid_dirty_rows(context)) {
        queue_grid_draw_when_mapped(context);
        return;
    }
    int dirty_count = context->dirty_rows(
        context->userdata, context->dirty_row_buffer,
        context->dirty_row_capacity);
    if (dirty_count < 0 || dirty_count < context->rows) {
        queue_grid_draw_when_mapped(context);
        return;
    }
    context->terminal_dirty_rows_used = 1;
    if (!context->damage_initialized) {
        context->damage_initialized = 1;
        context->last_cursor_position = cursor;
        root_grid_context(context)->damage_rows_queued += (guint)context->rows;
        deetty_grid_widget_queue_draw(context->area);
        return;
    }

    int range_start = -1;
    for (int row = 0; row < context->rows; row++) {
        if (context->dirty_row_buffer[row] != 0) {
            if (range_start < 0) range_start = row;
        } else if (range_start >= 0) {
            queue_grid_row_range(context, range_start, row);
            range_start = -1;
        }
    }
    if (range_start >= 0)
        queue_grid_row_range(context, range_start, context->rows);
    if (cursor != context->last_cursor_position) {
        context->cursor_visible = 1;
        queue_grid_cursor_cell(context, context->last_cursor_position);
        queue_grid_cursor_cell(context, cursor);
        context->last_cursor_position = cursor;
    }
}

static void remove_grid_source(guint *source);

static gboolean on_synchronized_output_deadman(gpointer user_data) {
    DeettyGridContext *context = user_data;
    context->synchronized_output_source = 0;
    if (!grid_context_session_available(context) || context->exited ||
        !context->synchronized_output_pending)
        return G_SOURCE_REMOVE;
    context->synchronized_output_pending = 0;
    DeettyGridContext *root = root_grid_context(context);
    root->synchronized_output_deadman_releases++;
    queue_grid_damage_when_mapped(context);
    return G_SOURCE_REMOVE;
}

static void queue_grid_output_when_ready(DeettyGridContext *context) {
    if (context->presentation_ready(context->userdata) == 0) {
        context->synchronized_output_pending = 1;
        root_grid_context(context)->synchronized_output_deferrals++;
        if (context->synchronized_output_source == 0) {
            DeettyGridLifecycleTimingPlan timing = {0};
            deetty_grid_lifecycle_timing_plan(&timing);
            context->synchronized_output_source = g_timeout_add_full(
                G_PRIORITY_DEFAULT, (guint)timing.output_deadman_ms,
                on_synchronized_output_deadman, context, NULL);
        }
        return;
    }
    if (context->synchronized_output_pending) {
        context->synchronized_output_pending = 0;
        root_grid_context(context)->synchronized_output_releases++;
    }
    remove_grid_source(&context->synchronized_output_source);
    queue_grid_damage_when_mapped(context);
    if (context->area != NULL && deetty_grid_widget_get_mapped(context->area)) {
        GdkFrameClock *clock = deetty_grid_widget_get_frame_clock(context->area);
        if (clock != NULL)
            deetty_grid_gdk_request_paint(clock, GDK_FRAME_CLOCK_PHASE_PAINT);
    }
}

static void mark_grid_output_activity(DeettyGridContext *context) {
    context->last_output_us = g_get_monotonic_time();
    context->idle_history_compacted = 0;
#if DEETTY_ENABLE_SMOKE
    DeettyGridContext *root = root_grid_context(context);
    if (root->workspace_smoke == 36)
        root->presentation_output_serial++;
#endif
}

static void record_dogfood_omp_output(DeettyGridContext *context,
                                      int pumped) {
    if (!context->dogfood_omp_seen) return;
    if (pumped > 0)
        context->dogfood_omp_output_bytes += (uint64_t)pumped;
    else if (pumped == -1)
        context->dogfood_omp_feed_failed = 1;
}

static void set_grid_window_title(DeettyGridContext *context,
                                  GtkWidget *window,
                                  const char *title) {
    DeettyGridContext *root = root_grid_context(context);
    if (!deetty_grid_widget_is_type(window, DEETTY_GTK_WINDOW) || title == NULL || title[0] == '\0')
        return;
    char display[576];
    if (deetty_grid_window_title_text(
            root->mode, (const unsigned char *)title, strlen(title),
            (unsigned char *)display, sizeof(display)) <= 0)
        return;
    deetty_grid_window_set_title(window, display);
}

static int pump_grid_context(DeettyGridContext *context,
                             gboolean *exited_now) {
    if (!grid_context_session_available(context) || context->exited)
        return -2;
    DeettyGridLifecycleTimingPlan timing = {0};
    deetty_grid_lifecycle_timing_plan(&timing);
    DeettyGridNativeHostPolicy policy = {0};
    deetty_grid_native_host_policy(&policy);
    int pumped = context->pty_fd == -1
        ? context->pump(context->userdata)
        : -2;
    record_dogfood_omp_output(context, pumped);
    if (pumped != -2) schedule_grid_write_flush(context);

    if (pumped == 0) {
        (void)deetty_grid_close_transport(context->userdata);
        context->pty_fd = -2;
    }
    if (pumped > 0) mark_grid_output_activity(context);
    gboolean had_output = pumped > 0 || context->pty_output_dirty;
    gboolean notification_requested = FALSE;
    context->pty_output_dirty = 0;
    if (had_output || !context->terminal_metadata_initialized) {
        context->terminal_metadata_initialized = 1;
        char title[512];
        int title_length = context->title(
            context->userdata, title, sizeof(title) - 1);
        if (title_length > 0) {
            title_length = MIN(title_length, (int)sizeof(title) - 1);
            title[title_length] = '\0';
            if (context->display_title == NULL ||
                strcmp(context->display_title, title) != 0) {
                deetty_grid_memory_free(context->display_title);
                context->display_title = g_strdup(title);
                update_compact_tab(context);
            }
            if ((context->focused || context->primary) &&
                root_grid_context(context)->workspace_smoke != 39)
                set_grid_window_title(
                    context, root_grid_context(context)->window, title);
        }

        uint64_t bell_serial = deetty_grid_bell_serial(context->userdata);
        if (bell_serial != context->last_bell_serial) {
            if (bell_serial > context->last_bell_serial) {
                context->attention = 1;
                root_grid_context(context)->compact_attention_seen = 1;
            }
            context->last_bell_serial = bell_serial;
            update_compact_tab(context);
        }

        uint64_t notification_serial =
            deetty_grid_notification_serial(context->userdata);
        if (notification_serial != context->last_notification_serial) {
            context->last_notification_serial = notification_serial;
            context->pending_notification_action =
                deetty_grid_notification_action(context->userdata);
            notification_requested = TRUE;
        }
    }

    gint64 now_us = g_get_monotonic_time();
    int exit_code = -1;
    if (pumped != -2 || had_output || context->last_exit_poll_us == 0 ||
        now_us - context->last_exit_poll_us >= timing.exit_poll_us) {
        context->last_exit_poll_us = now_us;
        exit_code = context->poll_exit(context->userdata);
    }
    if (exit_code >= 0) {
        if (context->event != NULL) context->event(context->event_data, context->pane_id, DEETTY_GRID_HOST_EVENT(SESSION_EXITED), exit_code, (uint64_t)(g_get_monotonic_time() / 1000));
        context->exited = 1;
        context->attention = 0;
        if (context->workspace_smoke == 24 && context->event != NULL)
            context->event(context->event_data, context->pane_id, DEETTY_GRID_HOST_EVENT(SESSION_EXIT_SMOKE), 1,
                           (uint64_t)(g_get_monotonic_time() / 1000));
        context->exit_code = exit_code;
        context->status_kind = exit_code == 0 ? 2 : 3;
        update_status_tooltip(context, exit_code == 0 ? "done" : "error");
        send_exit_notification(context, exit_code);
        update_compact_tab(context);
        queue_grid_draw_when_mapped(context);
        if (all_grid_contexts_exited(context))
            (void)request_grid_application_close(
                context, DEETTY_CLOSE_ORIGIN_NATURAL);
        *exited_now = TRUE;
        return pumped;
    }
    DeettyGridStatusPlan status = {0};
    deetty_grid_status_plan(context->status_kind, context->attention, &status);
    int active_status = status.active_kind;
    int status_changed = status.changed;
    context->status_kind = active_status;
    if (context->event != NULL && (had_output || status_changed))
        context->event(context->event_data, context->pane_id,
                       active_status == 4 ? 109 : 2, 0,
                       (uint64_t)(g_get_monotonic_time() / 1000));
    if (status_changed) {
        update_status_tooltip(context, deetty_grid_status_name(active_status));
        update_compact_tab(context);
    }
    if (notification_requested) {
        context->attention = !context->focused;
        root_grid_context(context)->compact_attention_seen = 1;
        context->status_kind = 4;
        update_status_tooltip(
            context,
            context->pending_notification_action == 1
                ? "agent action: focus pane"
                : context->pending_notification_action == 2
                    ? "agent action: open project"
                    : "pending input");
        update_compact_tab(context);
        if (context->event != NULL)
            context->event(context->event_data, context->pane_id,
                           policy.event_status_notification, 0,
                           (uint64_t)(now_us / 1000));
        send_attention_notification(context, now_us);
        status_changed = 1;
    }
    if (had_output) queue_grid_output_when_ready(context);
    if (status_changed) queue_grid_draw_when_mapped(context);
    return pumped;
}

static gboolean on_output_present(gpointer user_data);
static gboolean on_output_frame(GtkWidget *widget, GdkFrameClock *frame_clock,
                                gpointer user_data);
static gboolean on_pty_ready(gint fd, GIOCondition condition,
                             gpointer user_data);
static void remove_grid_source(guint *source);

static int register_grid_pty(DeettyGridContext *context) {
    context->pty_source = g_unix_fd_add_full(
        G_PRIORITY_DEFAULT, context->pty_fd,
        (GIOCondition)(G_IO_IN | G_IO_HUP | G_IO_ERR), on_pty_ready,
        context, NULL);
    return context->pty_source != 0;
}

static void remove_grid_source(guint *source) {
    if (*source == 0) return;
    deetty_grid_source_remove(*source);
    *source = 0;
}

static void remove_output_present(DeettyGridContext *context) {
    if (context->output_present_source == 0) return;
    if (context->output_present_is_tick && context->area != NULL)
        deetty_grid_widget_remove_tick_callback(
            context->area, context->output_present_source);
    else
        deetty_grid_source_remove(context->output_present_source);
    context->output_present_source = 0;
    context->output_present_is_tick = 0;
}

static void stop_grid_io_sources(DeettyGridContext *context) {
    remove_grid_source(&context->tick_source);
    remove_grid_source(&context->pty_source);
    remove_grid_source(&context->write_flush_source);
    remove_output_present(context);
    remove_grid_source(&context->synchronized_output_source);
    context->synchronized_output_pending = 0;
}

static void stop_grid_io_after_exit(DeettyGridContext *context) {
    stop_grid_io_sources(context);
    if (context->dogfood_omp_seen && context->exit_code == 0 &&
        !context->dogfood_omp_normal_exit_seen) {
        context->dogfood_omp_normal_exit_seen = 1;
        emit_dogfood_event(
            context, "omp_normal_exit_cleanup", context->pane_id,
            context->exit_code, "sources_stopped");
        if (context->dogfood_omp_output_bytes > 0 &&
            !context->dogfood_omp_feed_failed)
            emit_dogfood_event(
                context, "omp_output_integrity", context->pane_id,
                (int)MIN(context->dogfood_omp_output_bytes,
                         (uint64_t)G_MAXINT),
                "pty_bytes_fed_once");
    }
}

static void stop_grid_context_sources(DeettyGridContext *context) {
    DeettyGridContext *root = root_grid_context(context);
    stop_grid_io_sources(context);
    remove_grid_source(&context->note_save_source);
    remove_grid_source(&context->hide_source);
    remove_grid_source(&context->focus_hide_source);
    remove_grid_source(&context->resize_overlay_arm_source);
    remove_grid_source(&context->resize_overlay_hide_source);
    remove_grid_source(&context->focus_deferred_source);
    remove_grid_source(&context->resize_commit_source);
    remove_grid_source(&context->pane_cycle_feedback_source);
    remove_grid_source(&context->tab_cycle_feedback_source);
    if (context == root)
        remove_grid_source(&root->resolution_adapt_source);
    root->source_cleanup_count++;
}

static void schedule_output_present(DeettyGridContext *context) {
    DeettyGridOutputPresentPlan plan = {0};
    deetty_grid_output_present_plan(
        grid_context_session_available(context),
        context->exited,
        context->output_present_source != 0,
        context->area != NULL &&
            deetty_grid_widget_get_mapped(context->area),
        &plan);
    if (plan.schedule == 0) return;
    if (plan.use_tick != 0) {
        context->output_present_is_tick = 1;
        context->output_present_source = deetty_grid_widget_add_tick_callback(
            context->area, G_CALLBACK(on_output_frame), context, NULL);
        if (context->output_present_source != 0) return;
        context->output_present_is_tick = 0;
    }
    context->output_present_source = g_timeout_add_full(
        G_PRIORITY_DEFAULT, (guint)plan.timeout_ms,
        on_output_present, context, NULL);
}

static gboolean on_pty_ready(gint fd, GIOCondition condition,
                             gpointer user_data) {
    DeettyGridContext *context = user_data;
    if (!grid_context_session_available(context) || context->exited ||
        fd != context->pty_fd) {
        context->pty_source = 0;
        return G_SOURCE_REMOVE;
    }
    int pumped = context->pump(context->userdata);
    record_dogfood_omp_output(context, pumped);
    schedule_grid_write_flush(context);
    if (pumped > 0) {
        mark_grid_output_activity(context);
        context->pty_output_dirty = 1;
        queue_grid_output_when_ready(context);
        schedule_output_present(context);
        return G_SOURCE_CONTINUE;
    }
    if (pumped == -2 &&
        (condition & (G_IO_HUP | G_IO_ERR | G_IO_NVAL)) == 0)
        return G_SOURCE_CONTINUE;
    context->pty_source = 0;
    (void)deetty_grid_close_transport(context->userdata);
    context->pty_fd = -2;
    context->last_exit_poll_us = 0;
    schedule_output_present(context);
    return G_SOURCE_REMOVE;
}

static gboolean on_output_present(gpointer user_data) {
    DeettyGridContext *context = user_data;
    context->output_present_source = 0;
    context->output_present_is_tick = 0;
    context->timeout_presentations++;
#if DEETTY_ENABLE_SMOKE
    DeettyGridContext *root = root_grid_context(context);
    if (root->workspace_smoke == 40) {
        if (root->stability_phase == 1)
            root->stability_visible_presents++;
        else if (root->stability_phase == 2)
            root->stability_hidden_presents++;
    }
#endif
    if (!grid_context_session_available(context) || context->exited)
        return G_SOURCE_REMOVE;
    gboolean exited_now = FALSE;
    (void)pump_grid_context(context, &exited_now);
    if (exited_now) stop_grid_io_after_exit(context);
    return G_SOURCE_REMOVE;
}

static gboolean on_output_frame(GtkWidget *widget, GdkFrameClock *frame_clock,
                                gpointer user_data) {
    (void)widget;
    (void)frame_clock;
    DeettyGridContext *context = user_data;
    context->output_present_source = 0;
    context->output_present_is_tick = 0;
    context->frame_presentations++;
#if DEETTY_ENABLE_SMOKE
    DeettyGridContext *root = root_grid_context(context);
    if (root->workspace_smoke == 37) {
        if (root->full_stack_phase == 1)
            root->full_stack_idle_output_frames++;
        else if (root->full_stack_phase == 2)
            root->full_stack_fullscreen_output_frames++;
    } else if (root->workspace_smoke == 40) {
        if (root->stability_phase == 1)
            root->stability_visible_presents++;
        else if (root->stability_phase == 2)
            root->stability_hidden_presents++;
    }
#endif
    if (!grid_context_session_available(context) || context->exited)
        return G_SOURCE_REMOVE;
    gboolean exited_now = FALSE;
    (void)pump_grid_context(context, &exited_now);
    if (exited_now) stop_grid_io_after_exit(context);
    return G_SOURCE_REMOVE;
}

static gboolean on_tick(gpointer user_data) {
    DeettyGridContext *context = user_data;
#if DEETTY_ENABLE_SMOKE
    DeettyGridContext *root = root_grid_context(context);
    if (root->workspace_smoke == 37) {
        if (root->full_stack_phase == 1)
            root->full_stack_idle_ticks++;
        else if (root->full_stack_phase == 2)
            root->full_stack_fullscreen_ticks++;
    } else if (root->workspace_smoke == 40) {
        if (root->stability_phase == 1)
            root->stability_visible_ticks++;
        else if (root->stability_phase == 2)
            root->stability_hidden_ticks++;
    }
#endif
    if (!grid_context_session_available(context) || context->exited) {
        context->tick_source = 0;
        return G_SOURCE_REMOVE;
    }
    gboolean exited_now = FALSE;
    (void)pump_grid_context(context, &exited_now);
    if (exited_now) {
        stop_grid_io_after_exit(context);
        return G_SOURCE_REMOVE;
    }
    return G_SOURCE_CONTINUE;
}

static gboolean on_cursor_blink(gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
#if DEETTY_ENABLE_SMOKE
    if (root->workspace_smoke == 37) {
        if (root->full_stack_phase == 1)
            root->full_stack_idle_cursor_blinks++;
        else if (root->full_stack_phase == 2)
            root->full_stack_fullscreen_cursor_blinks++;
    } else if (root->workspace_smoke == 40) {
        if (root->stability_phase == 1)
            root->stability_visible_cursor_blinks++;
        else if (root->stability_phase == 2)
            root->stability_hidden_cursor_blinks++;
    }
#endif
    DeettyGridContext *context = focused_grid_context(root);
    if (!grid_context_session_available(context) || context->exited ||
        context->area == NULL || !deetty_grid_widget_get_mapped(context->area))
        return G_SOURCE_CONTINUE;
    context->cursor_visible = !context->cursor_visible;
    queue_grid_cursor_cell(context, context->cursor(context->userdata));
    return G_SOURCE_CONTINUE;
}

static gboolean on_grid_maintenance(gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    DeettyGridLifecycleTimingPlan timing = {0};
    deetty_grid_lifecycle_timing_plan(&timing);
    DeettyGridNativeHostPolicy policy = {0};
    deetty_grid_native_host_policy(&policy);
#if DEETTY_ENABLE_SMOKE
    if (root->workspace_smoke == 37) {
        if (root->full_stack_phase == 1)
            root->full_stack_idle_maintenance++;
        else if (root->full_stack_phase == 2)
            root->full_stack_fullscreen_maintenance++;
    } else if (root->workspace_smoke == 40) {
        if (root->stability_phase == 1)
            root->stability_visible_maintenance++;
        else if (root->stability_phase == 2)
            root->stability_hidden_maintenance++;
    }
#endif
    gint64 now_us = g_get_monotonic_time();
    detect_dogfood_omp_sessions(root, now_us);
    uint64_t now_ms = (uint64_t)(now_us / 1000);
    guint idle_history_steps = 0;
    gboolean idle_history_released = FALSE;
    DeettyGridContext *active = NULL;
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        DeettyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (!grid_context_session_available(candidate) || candidate->exited)
            continue;
        if (candidate->descriptor_tick_coalesced &&
            candidate->tick_source == 0) {
            root->descriptor_maintenance_fallback_seen = 1;
            gboolean exited_now = FALSE;
            (void)pump_grid_context(candidate, &exited_now);
            if (exited_now) {
                stop_grid_io_after_exit(candidate);
                continue;
            }
        }
        schedule_grid_write_flush(candidate);
        if (!candidate->idle_history_compacted &&
            idle_history_steps < (guint)timing.idle_steps_per_tick) {
            gint64 idle_threshold_us = candidate->focused
                ? timing.idle_focused_us
                : timing.idle_background_us;
            if (now_us - candidate->last_output_us >= idle_threshold_us) {
                int compacted = deetty_grid_compact_idle_history(
                    candidate->userdata);
                idle_history_steps++;
                if (compacted != 0) {
                    candidate->idle_history_compacted = 1;
                    if (compacted > 1) idle_history_released = TRUE;
                    if (compacted > 1 && candidate->event != NULL)
                        candidate->event(
                            candidate->event_data, candidate->pane_id,
                            policy.event_idle_history_compacted, 0, now_ms);
                }
            }
        }
        if (active == NULL) active = candidate;
        if (candidate->event != NULL)
            candidate->event(candidate->event_data, candidate->pane_id, DEETTY_GRID_HOST_EVENT(OUTPUT_ACTIVITY), 0,
                             now_ms);
    }
    /* History slabs use libc; trim only after a bounded completion wave. */
    if (idle_history_released) (void)malloc_trim(0);
    if (active != NULL && root->event != NULL) {
        gboolean project_visible = root->project_dialog != NULL &&
            deetty_grid_widget_get_mapped(root->project_dialog);
        root->event(root->event_data, active->pane_id, DEETTY_GRID_HOST_EVENT(PROJECT_VISIBILITY),
                    project_visible || root->workspace_smoke == 34,
                    now_ms);
    }
    refresh_active_pane_info(root);
    return G_SOURCE_CONTINUE;
}

static void start_grid_context(DeettyGridContext *context) {
    if (context == NULL || context->userdata == NULL) return;
    DeettyGridLifecycleTimingPlan timing = {0};
    deetty_grid_lifecycle_timing_plan(&timing);
    context->retiring = 0;
    context->active = 1;
    context->last_output_us = g_get_monotonic_time();
    context->idle_history_compacted = 0;
    if (context->event != NULL) context->event(context->event_data, context->pane_id, DEETTY_GRID_HOST_EVENT(SESSION_STARTED), 0, (uint64_t)(g_get_monotonic_time() / 1000));
    context->pty_fd = deetty_grid_pty_fd(context->userdata);
    if (context->pty_fd >= 0) {
        (void)register_grid_pty(context);
    }
    if (context->pty_source != 0) {
        context->pty_event_source_started = 1;
        context->descriptor_tick_coalesced = 1;
    } else {
        context->pty_fd = -1;
        context->descriptor_tick_coalesced = 0;
        context->tick_source = deetty_grid_source_timeout_add(
            (guint)timing.tick_ms, on_tick, context);
    }
    DeettyGridContext *root = root_grid_context(context);
    if (root->cursor_blink_source == 0)
        root->cursor_blink_source = deetty_grid_source_timeout_add(
            (guint)timing.cursor_blink_ms, on_cursor_blink, root);
    if (root->maintenance_source == 0)
        root->maintenance_source = deetty_grid_source_timeout_add_seconds(
            (guint)timing.maintenance_seconds, on_grid_maintenance, root);
}

static void connect_grid_area(DeettyGridContext *context);

static void inherit_grid_session_context(DeettyGridContext *created,
                                         DeettyGridContext *source) {
    DeettyGridContext *root = root_grid_context(source);
    created->root = root;
    created->window = root->window;
    created->notebook = root->notebook;
    created->revealer = root->revealer;
    created->content_box = root->content_box;
    created->pane_info_strip = root->pane_info_strip;
    created->resize_grip = root->resize_grip;
    created->window_layout = root->window_layout;
    created->contexts = root->contexts;
    created->pump = root->pump;
    created->write = root->write;
    created->frame = root->frame;
    created->dirty_rows = root->dirty_rows;
    created->dirty_spans = root->dirty_spans;
    created->presentation_ready = root->presentation_ready;
    created->color_rgb = root->color_rgb;
    created->ui_color_rgb = root->ui_color_rgb;
    created->cell_text = root->cell_text;
    created->cell_hyperlink = root->cell_hyperlink;
    created->poll_exit = root->poll_exit;
    created->resize = root->resize;
    created->mouse = root->mouse;
    created->paste = root->paste;
    created->copy = root->copy;
    created->scroll = root->scroll;
    created->cursor = root->cursor;
    created->title = root->title;
    created->cursor_mode = root->cursor_mode;
    created->mouse_mode = root->mouse_mode;
    created->focus = root->focus;
    created->event = root->event;
    created->text_action = root->text_action;
    created->create_session = root->create_session;
    created->event_data = root->event_data;
    created->text_action_data = root->text_action_data;
    created->columns = source->columns;
    created->rows = source->rows;
    created->mode = root->mode;
    created->workspace_smoke = root->workspace_smoke;
    created->enable_notifications = root->enable_notifications;
    created->shortcut_transport = root->shortcut_transport;
    created->requested_shortcut_key = root->requested_shortcut_key;
    created->dropdown_width_percent = root->dropdown_width_percent;
    created->dropdown_height_percent = root->dropdown_height_percent;
    created->dropdown_width_px = root->dropdown_width_px;
    created->dropdown_height_px = root->dropdown_height_px;
    created->dropdown_animation_ms = root->dropdown_animation_ms;
    created->hide_on_focus_loss = root->hide_on_focus_loss;
    created->focus_follows_pointer = root->focus_follows_pointer;
    created->background_translucency = root->background_translucency;
    created->background_opacity_percent = root->background_opacity_percent;
    created->background_alpha_supported = root->background_alpha_supported;
    created->panel_padding_px = root->panel_padding_px;
    created->pane_spacing_px = root->pane_spacing_px;
    created->pane_gaps_enabled = root->pane_gaps_enabled;
    created->pane_gaps_transparent = root->pane_gaps_transparent;
    created->inactive_pane_dim_enabled = root->inactive_pane_dim_enabled;
    created->inactive_pane_brightness_percent =
        root->inactive_pane_brightness_percent;
    created->pane_divider_px = root->pane_divider_px;
    created->pane_border_px = root->pane_border_px;
    created->pane_border_focused_px = root->pane_border_focused_px;
    created->pane_border_selected_px = root->pane_border_selected_px;
    created->status_border_px = root->status_border_px;
    created->overlay_border_px = root->overlay_border_px;
    created->window_border_px = root->window_border_px;
    created->dragger_px = root->dragger_px;
    created->terminal_scroll_lines = root->terminal_scroll_lines;
    created->terminal_smooth_scroll = root->terminal_smooth_scroll;
    created->show_pane_info = root->show_pane_info;
    created->compact_tab_height = root->compact_tab_height;
    created->font_size = source->requested_font_size;
    created->requested_font_size = source->requested_font_size;
    created->font_min_size = root->font_min_size;
    created->font_max_size = root->font_max_size;
    created->ligatures = source->ligatures;
    created->font_antialias = root->font_antialias;
    created->font_hinting = root->font_hinting;
    created->renderer_backend = root->renderer_backend;
    created->renderer_backend_requested = root->renderer_backend_requested;
    created->profile_preset = source->profile_preset;
}

static DeettyGridContext *create_grid_context_for_session(
    DeettyGridContext *source, void *userdata, uint64_t pane_id) {
    DeettyGridContext *created = g_new0(DeettyGridContext, 1);
    inherit_grid_session_context(created, source);
    created->area = deetty_terminal_area_new(created->renderer_backend);
    int spacing_leading = created->pane_spacing_px / 2;
    int spacing_trailing = created->pane_spacing_px - spacing_leading;
    deetty_grid_widget_set_margins(
        created->area,
        spacing_leading,
        spacing_leading,
        spacing_trailing,
        spacing_trailing);
    created->im_context = deetty_grid_input_context_new();
    created->font_family = g_strdup(source->font_family != NULL
                                        ? source->font_family
                                        : "monospace");
    created->userdata = userdata;
    created->pane_id = pane_id;
    created->profile_preset = -1;
    (void)sync_grid_context_profile(created);
    created->cursor_visible = 1;
    created->last_cursor_position = UINT32_MAX;
    created->last_bell_serial = deetty_grid_bell_serial(userdata);
    created->last_notification_serial =
        deetty_grid_notification_serial(userdata);
    created->pty_fd = -1;
    created->heap_allocated = 1;

    g_ptr_array_add(source->contexts, created);
    connect_grid_area(created);
    update_status_tooltip(created, "starting");
    return created;
}

static DeettyGridContext *create_grid_context(DeettyGridContext *source,
                                               int event_code) {
    if (source->create_session == NULL) return NULL;
    uint64_t pane_id = 0;
    void *userdata = source->create_session(
        source->event_data, source->pane_id, event_code,
        deetty_grid_session_dimension(source->columns),
        deetty_grid_session_dimension(source->rows), &pane_id);
    if (userdata == NULL || pane_id == 0) return NULL;
    return create_grid_context_for_session(source, userdata, pane_id);
}

static DeettyGridContext *restore_grid_context(
    DeettyGridContext *source, uint64_t pane_id,
    int columns, int rows) {
    if (source->create_session == NULL || pane_id == 0) return NULL;
    uint64_t restored_pane_id = 0;
    void *userdata = source->create_session(
        source->event_data, pane_id, DEETTY_GRID_HOST_EVENT(RESTORED_PANE),
        deetty_grid_session_dimension(columns),
        deetty_grid_session_dimension(rows), &restored_pane_id);
    if (userdata == NULL || restored_pane_id != pane_id) return NULL;
    return create_grid_context_for_session(source, userdata, pane_id);
}

static GtkWidget *pane_info_strip_for_page(GtkWidget *page) {
    if (!deetty_grid_widget_is_type(page, DEETTY_GTK_WIDGET)) return NULL;
    return deetty_grid_object_get_data(page, "deetty-pane-info-strip");
}

static GtkWidget *create_grid_page(DeettyGridContext *context) {
    DeettyGridContext *root = root_grid_context(context);
    return deetty_grid_page_new(
        root->panel_padding_px, root->pane_info_strip);
}

static GtkWidget *grid_page_content_root(DeettyGridContext *context,
                                         GtkWidget *page) {
    if (!deetty_grid_widget_is_type(page, DEETTY_GTK_CONTAINER)) return NULL;
    DeettyGridContext *root = root_grid_context(context);
    GtkWidget *strip = pane_info_strip_for_page(page);
    GList *children = deetty_grid_container_get_children(GTK_CONTAINER(page));
    GtkWidget *content = NULL;
    for (GList *item = children; item != NULL; item = item->next) {
        GtkWidget *candidate = GTK_WIDGET(item->data);
        if (candidate == strip || candidate == root->smart_filter_empty_box)
            continue;
        content = candidate;
        break;
    }
    g_list_free(children);
    return content;
}

static void refresh_active_pane_info(DeettyGridContext *context) {
    DeettyGridContext *root = root_grid_context(context);
    if (root->notebook == NULL) return;
    gint page_index = deetty_grid_notebook_get_current_page(GTK_NOTEBOOK(root->notebook));
    GtkWidget *page = deetty_grid_notebook_get_nth_page(
        GTK_NOTEBOOK(root->notebook), page_index);
    GtkWidget *strip = pane_info_strip_for_page(page);
    if (strip == NULL) return;
    deetty_pane_info_strip_set_enabled(strip, root->show_pane_info);
    if (!root->show_pane_info) return;

    DeettyGridContext *active = focused_grid_context(root);
    if (!grid_context_session_available(active) || active->page != page)
        active = active_grid_context(root);
    if (!grid_context_session_available(active) || active->page != page)
        return;

    char display[512] = {0};
    char tooltip[4608] = {0};
    if (deetty_grid_pane_info(active->userdata, root->event_data,
                              active->pane_id, display, sizeof(display),
                              tooltip, sizeof(tooltip)) <= 0)
        return;
    (void)deetty_pane_info_strip_update(strip, display, tooltip);
}

static gboolean add_grid_tab(DeettyGridContext *source, DeettyGridContext *created) {
    if (source->notebook == NULL) return FALSE;
    DeettyGridContext *root = root_grid_context(source);
    if (root->zoomed_pane_id != 0) restore_zoomed_page(root);
    GtkWidget *page = create_grid_page(source);
    created->page = page;
    deetty_box_pack_start(page, created->area, TRUE, TRUE, 0);
    char label_text[64] = {0};
    if (deetty_grid_tab_title_text(
            NULL, 0, NULL, 0, NULL, 0,
            deetty_grid_notebook_get_n_pages(GTK_NOTEBOOK(source->notebook)) + 1,
            (unsigned char *)label_text, sizeof(label_text)) <= 0)
        return FALSE;
    GtkWidget *tab_widget = create_compact_tab_widget(source, page, label_text);
    GtkWidget *tab_label = tab_label_from_widget(tab_widget);
    created->tab_label = tab_label;
    gint page_index = deetty_grid_notebook_append_page(
        source->notebook, page, tab_widget);
    deetty_grid_widget_show_all(page);
    show_all_with_action_affordances(tab_widget);
    deetty_grid_notebook_select_page(source->notebook, page_index);
    update_compact_tab(created);
    update_notebook_chrome(source);
    return TRUE;
}

static gboolean split_grid_context(DeettyGridContext *source, DeettyGridContext *created,
                                   int event_code) {
    DeettyGridContext *root = root_grid_context(source);
    if (root->zoomed_pane_id != 0) restore_zoomed_page(root);
    GtkWidget *parent = deetty_grid_widget_get_parent(source->area);
    if (parent == NULL) return FALSE;
    created->page = source->page;
    created->tab_label = source->tab_label;
    GtkAllocation source_allocation;
    deetty_grid_widget_get_allocation(source->area, &source_allocation);

    gboolean parent_is_paned = deetty_grid_widget_is_type(parent, DEETTY_GTK_PANED);
    gboolean source_was_first = parent_is_paned &&
        deetty_grid_paned_get_child1(GTK_PANED(parent)) == source->area;
    if (!parent_is_paned && !deetty_grid_widget_is_type(parent, DEETTY_GTK_BOX)) return FALSE;

    DeettyGridSplitRenderPlan split_plan = {0};
    deetty_grid_split_render_plan(event_code, &split_plan);
    if (split_plan.valid == 0) return FALSE;
    GtkOrientation orientation = (GtkOrientation)split_plan.orientation;
    GtkWidget *split = deetty_paned_new((int)orientation, root->pane_divider_px);
    deetty_grid_object_ref(source->area);
    deetty_container_remove(parent, source->area);
    if (parent_is_paned) {
        if (source_was_first) deetty_paned_pack1(parent, split, TRUE, FALSE);
        else deetty_paned_pack2(parent, split, TRUE, FALSE);
    } else {
        deetty_box_pack_start(parent, split, TRUE, TRUE, 0);
    }

    if (split_plan.reverse != 0) {
        deetty_paned_pack1(split, created->area, TRUE, FALSE);
        deetty_paned_pack2(split, source->area, TRUE, FALSE);
    } else {
        deetty_paned_pack1(split, source->area, TRUE, FALSE);
        deetty_paned_pack2(split, created->area, TRUE, FALSE);
    }
    deetty_grid_object_unref(source->area);
    deetty_grid_widget_show_all(split);
    deetty_grid_widget_queue_resize(parent);
    gint midpoint = orientation == GTK_ORIENTATION_VERTICAL
        ? source_allocation.height / 2
        : source_allocation.width / 2;
    if (midpoint > 0) deetty_paned_set_position(split, midpoint);
    if (source->event != NULL) {
        source->event(source->event_data, created->pane_id,
                      split_plan.rendered_event, 0,
                      (uint64_t)(g_get_monotonic_time() / 1000));
    }
    schedule_even_pane_distribution(
        source, grid_page_content_root(source, source->page));
    return TRUE;
}

static guint grid_contexts_on_page(DeettyGridContext *context, GtkWidget *page) {
    DeettyGridContext *root = root_grid_context(context);
    guint count = root != NULL && root->active && root->page == page ? 1 : 0;
    for (guint index = 0; root != NULL && root->contexts != NULL &&
         index < root->contexts->len; index++) {
        DeettyGridContext *candidate =
            g_ptr_array_index(root->contexts, index);
        if (candidate != root && candidate->active && candidate->page == page)
            count++;
    }
    return count;
}

static DeettyGridContext *grid_context_for_pane(DeettyGridContext *context,
                                                uint64_t pane_id) {
    DeettyGridContext *root = root_grid_context(context);
    DeettyGridContext *fallback = NULL;
    if (root != NULL && root->pane_id == pane_id) {
        if (root->userdata != NULL && !root->retiring && !root->exited)
            return root;
        fallback = root;
    }
    for (guint index = 0; root != NULL && root->contexts != NULL &&
         index < root->contexts->len; index++) {
        DeettyGridContext *candidate =
            g_ptr_array_index(root->contexts, index);
        if (candidate == root || candidate->pane_id != pane_id) continue;
        if (candidate->userdata != NULL && !candidate->retiring &&
            !candidate->exited)
            return candidate;
        fallback = candidate;
    }
    return fallback;
}

static gboolean flush_grid_layout_hot_session(gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    root->layout_save_source = 0;
    if (!root->control_name_conflict && root->event_data != NULL &&
        deetty_grid_flush_hot_session(root->event_data) != 0)
        show_status_feedback(
            root,
            deetty_grid_status_feedback_message(
                DEETTY_GRID_FEEDBACK_RECOVERY_SAVE));
    return G_SOURCE_REMOVE;
}

static void schedule_grid_hot_session_flush(DeettyGridContext *context) {
    DeettyGridContext *root = root_grid_context(context);
    if (root->layout_save_source != 0)
        deetty_grid_source_remove(root->layout_save_source);
    root->layout_save_source = deetty_grid_source_timeout_add(
        120, flush_grid_layout_hot_session, root);
}

static void on_grid_layout_position_changed(
    GObject *object, GParamSpec *parameter, gpointer user_data) {
    (void)parameter;
    if (!deetty_grid_widget_is_type(object, DEETTY_GTK_PANED)) return;
    DeettyGridContext *root = root_grid_context(user_data);
    int tab_index = GPOINTER_TO_INT(deetty_grid_object_get_data(
        object, "deetty-layout-tab-index")) - 1;
    int node_index = GPOINTER_TO_INT(deetty_grid_object_get_data(
        object, "deetty-layout-node-index")) - 1;
    gint max_position = 0;
    g_object_get(object, "max-position", &max_position, NULL);
    if (root->event_data == NULL || tab_index < 0 || node_index < 0 ||
        max_position <= 0 || max_position >= G_MAXINT / 2 ||
        root->layout_restore_applying)
        return;
    int position = deetty_grid_paned_get_position(GTK_PANED(object));
    int ratio_permille = deetty_grid_split_ratio(position, max_position);
    deetty_grid_object_set_data(
        object, "deetty-preset-ratio",
        GUINT_TO_POINTER((guint)ratio_permille));
    if (deetty_grid_set_layout_ratio(
            root->event_data, tab_index, node_index,
            ratio_permille) != 0)
        return;
    schedule_grid_hot_session_flush(root);
}

static gboolean on_grid_layout_button_release(
    GtkWidget *widget, GdkEventButton *event, gpointer user_data) {
    (void)user_data;
    if (event->type != GDK_BUTTON_RELEASE || event->button != 1 ||
        !deetty_grid_widget_is_type(widget, DEETTY_GTK_PANED))
        return FALSE;
    gint max_position = 0;
    g_object_get(G_OBJECT(widget), "max-position", &max_position, NULL);
    if (max_position <= 0 || max_position >= G_MAXINT / 2) return FALSE;
    int position = deetty_grid_paned_get_position(GTK_PANED(widget));
    int snapped_position = deetty_grid_snap_pane_position(
        max_position, position);
    if (snapped_position >= 0)
        deetty_paned_set_position(widget, snapped_position);
    return FALSE;
}

static gboolean bind_grid_layout_node(
    DeettyGridContext *root, GtkWidget *widget, int tab_index,
    int node_index, int node_count, int depth) {
    if (widget == NULL || node_index < 0 || node_index >= node_count ||
        depth > node_count)
        return FALSE;
    int kind = -1;
    int axis = -1;
    int first = -1;
    int second = -1;
    int ratio_permille = 0;
    uint64_t pane_id = 0;
    if (deetty_grid_restore_layout_node(
            root->event_data, tab_index, node_index, &kind, &pane_id,
            &axis, &first, &second, &ratio_permille) != 0)
        return FALSE;
    if (kind == 0) {
        DeettyGridContext *pane = grid_context_for_pane(root, pane_id);
        return pane != NULL && pane->area == widget;
    }
    if (kind != 1 || !deetty_grid_widget_is_type(widget, DEETTY_GTK_PANED) || first < 0 || second < 0)
        return FALSE;
    GtkOrientation orientation = (GtkOrientation)
        deetty_grid_orientable_get_orientation(GTK_ORIENTABLE(widget));
    if ((axis == 0 && orientation != GTK_ORIENTATION_HORIZONTAL) ||
        (axis == 1 && orientation != GTK_ORIENTATION_VERTICAL))
        return FALSE;
    deetty_grid_object_set_data(
        widget, "deetty-layout-tab-index",
        GINT_TO_POINTER(tab_index + 1));
    deetty_grid_object_set_data(
        widget, "deetty-layout-node-index",
        GINT_TO_POINTER(node_index + 1));
    if (deetty_grid_object_get_data(
            widget, "deetty-layout-position-bound") == NULL) {
        deetty_grid_signal_connect(widget, "notify::position",
                         G_CALLBACK(on_grid_layout_position_changed), root);
        deetty_grid_object_set_data(
            widget, "deetty-layout-position-bound",
            GINT_TO_POINTER(1));
    }
    if (deetty_grid_object_get_data(widget, "deetty-layout-snap-bound") == NULL) {
        deetty_grid_widget_add_events(widget, GDK_BUTTON_RELEASE_MASK);
        deetty_grid_signal_connect(widget, "button-release-event",
                         G_CALLBACK(on_grid_layout_button_release), root);
        deetty_grid_object_set_data(
            widget, "deetty-layout-snap-bound",
            GINT_TO_POINTER(1));
    }
    return bind_grid_layout_node(
               root, deetty_grid_paned_get_child1(GTK_PANED(widget)),
               tab_index, first, node_count, depth + 1) &&
        bind_grid_layout_node(
               root, deetty_grid_paned_get_child2(GTK_PANED(widget)),
               tab_index, second, node_count, depth + 1);
}

static gboolean bind_grid_layout_for_page(DeettyGridContext *context) {
    if (context == NULL) return FALSE;
    DeettyGridContext *root = root_grid_context(context);
    if (root->event_data == NULL || !deetty_grid_widget_is_type(context->page, DEETTY_GTK_BOX))
        return FALSE;
    DeettyGridContext *representative = grid_context_for_page(
        root, context->page);
    if (representative == NULL) return FALSE;
    int tab_index = deetty_grid_restore_tab_index_for_pane(
        root->event_data, representative->pane_id);
    int pane_count = 0;
    int node_count = 0;
    int root_node = -1;
    uint64_t active_pane_id = 0;
    if (tab_index < 0 || deetty_grid_restore_tab_info(
            root->event_data, tab_index, &pane_count, &active_pane_id,
            &node_count, &root_node) != 0)
        return FALSE;
    GtkWidget *layout = grid_page_content_root(context, context->page);
    return bind_grid_layout_node(
        root, layout, tab_index, root_node, node_count, 0);
}

static GtkWidget *build_hot_session_layout_node(
    DeettyGridContext *root, int tab_index, int node_index,
    int node_count, GtkWidget *page, int depth) {
    if (root == NULL || root->event_data == NULL || page == NULL ||
        node_index < 0 || node_index >= node_count || depth > node_count)
        return NULL;
    int kind = -1;
    int axis = -1;
    int first = -1;
    int second = -1;
    int ratio_permille = 0;
    uint64_t pane_id = 0;
    if (deetty_grid_restore_layout_node(
            root->event_data, tab_index, node_index, &kind, &pane_id,
            &axis, &first, &second, &ratio_permille) != 0)
        return NULL;
    if (kind == 0) {
        DeettyGridContext *pane = grid_context_for_pane(root, pane_id);
        return pane != NULL && pane->page == page ? pane->area : NULL;
    }
    if (kind != 1 || (axis != 0 && axis != 1) || first < 0 ||
        second < 0 || first == second || ratio_permille < 0 ||
        ratio_permille > 1000)
        return NULL;
    GtkWidget *first_widget = build_hot_session_layout_node(
        root, tab_index, first, node_count, page, depth + 1);
    GtkWidget *second_widget = build_hot_session_layout_node(
        root, tab_index, second, node_count, page, depth + 1);
    if (first_widget == NULL || second_widget == NULL) return NULL;
    GtkWidget *split = deetty_paned_new(
        axis == 0 ? GTK_ORIENTATION_HORIZONTAL : GTK_ORIENTATION_VERTICAL,
        root->pane_divider_px);
    deetty_paned_pack1(split, first_widget, TRUE, FALSE);
    deetty_paned_pack2(split, second_widget, TRUE, FALSE);
    deetty_grid_object_set_data(
        split, "deetty-preset-ratio",
        GUINT_TO_POINTER((guint)ratio_permille));
    deetty_grid_object_set_data(
        split, "deetty-layout-tab-index",
        GINT_TO_POINTER(tab_index + 1));
    deetty_grid_object_set_data(
        split, "deetty-layout-node-index",
        GINT_TO_POINTER(node_index + 1));
    deetty_grid_signal_connect(split, "notify::position",
                     G_CALLBACK(on_grid_layout_position_changed), root);
    deetty_grid_widget_add_events(split, GDK_BUTTON_RELEASE_MASK);
    deetty_grid_signal_connect(split, "button-release-event",
                     G_CALLBACK(on_grid_layout_button_release), root);
    deetty_grid_object_set_data(G_OBJECT(split), "deetty-layout-position-bound",
                      GINT_TO_POINTER(1));
    deetty_grid_object_set_data(G_OBJECT(split), "deetty-layout-snap-bound",
                      GINT_TO_POINTER(1));
    return split;
}

static void on_restored_layout_size_allocate(GtkWidget *widget,
                                             GtkAllocation *allocation,
                                             gpointer user_data) {
    (void)user_data;
    if (allocation->width > 0 && allocation->height > 0)
        apply_preset_paned_positions(widget, allocation->width,
                                     allocation->height);
}

static gboolean rebuild_hot_session_page(
    DeettyGridContext *root, int tab_index, GtkWidget *page,
    int node_count, int root_node) {
    if (root == NULL || !deetty_grid_widget_is_type(page, DEETTY_GTK_BOX)) return FALSE;
    GPtrArray *held_areas = g_ptr_array_new();
    if (root->page == page && root->area != NULL &&
        deetty_grid_widget_get_parent(root->area) != NULL) {
        deetty_grid_object_ref(root->area);
        g_ptr_array_add(held_areas, root->area);
    }
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        DeettyGridContext *candidate =
            g_ptr_array_index(root->contexts, index);
        if (candidate == root) continue;
        if (candidate->page == page && candidate->area != NULL &&
            deetty_grid_widget_get_parent(candidate->area) != NULL) {
            deetty_grid_object_ref(candidate->area);
            g_ptr_array_add(held_areas, candidate->area);
        }
    }
    GtkWidget *strip = pane_info_strip_for_page(page);
    GList *children = deetty_grid_container_get_children(GTK_CONTAINER(page));
    for (GList *item = children; item != NULL; item = item->next) {
        GtkWidget *child = GTK_WIDGET(item->data);
        if (child != strip)
            deetty_container_remove(page, child);
    }
    g_list_free(children);

    GtkWidget *layout = build_hot_session_layout_node(
        root, tab_index, root_node, node_count, page, 0);
    if (layout != NULL) {
        deetty_box_pack_start(page, layout, TRUE, TRUE, 0);
        deetty_grid_signal_connect(layout, "size-allocate",
                         G_CALLBACK(on_restored_layout_size_allocate), NULL);
    }
    /* A successful repack transfers the held widget ownership to the container. */
    if (layout == NULL) {
        for (guint index = 0; index < held_areas->len; index++)
            deetty_grid_object_unref(g_ptr_array_index(held_areas, index));
    }
    g_ptr_array_free(held_areas, TRUE);
    return layout != NULL;
}

static gboolean restore_hot_session(DeettyGridContext *root) {
    if (root == NULL || root->event_data == NULL ||
        root->create_session == NULL ||
        deetty_grid_hot_session_loaded(root->event_data) == 0)
        return FALSE;
    int tab_count = deetty_grid_restore_tab_count(root->event_data);
    int active_tab = deetty_grid_restore_active_tab(root->event_data);
    int root_tab = deetty_grid_restore_tab_index_for_pane(
        root->event_data, root->pane_id);
    if (tab_count <= 0 || tab_count > 512 || active_tab < 0 ||
        active_tab >= tab_count || root_tab != active_tab)
        return FALSE;

    GtkWidget **pages = g_new0(GtkWidget *, (gsize)tab_count);
    pages[root_tab] = root->page;
    for (int tab_index = 0; tab_index < tab_count; tab_index++) {
        if (tab_index == root_tab) continue;
        GtkWidget *page = create_grid_page(root);
        char placeholder[64] = {0};
        if (deetty_grid_tab_title_text(
                NULL, 0, NULL, 0, NULL, 0, tab_index + 1,
                (unsigned char *)placeholder, sizeof(placeholder)) <= 0) {
            deetty_grid_widget_destroy(page);
            g_free(pages);
            return FALSE;
        }
        GtkWidget *tab_widget = create_compact_tab_widget(
            root, page, placeholder);
        (void)deetty_grid_notebook_append_page(
            root->notebook, page, tab_widget);
        pages[tab_index] = page;
    }
    if (root_tab != 0)
        deetty_grid_notebook_reorder_child(GTK_NOTEBOOK(root->notebook),
                                   root->page, root_tab);

    int pane_total = 0;
    gboolean layout_ready = TRUE;
    uint64_t active_pane_id = 0;
    for (int tab_index = 0; tab_index < tab_count; tab_index++) {
        int pane_count = 0;
        int node_count = 0;
        int root_node = -1;
        uint64_t tab_active_pane_id = 0;
        if (deetty_grid_restore_tab_info(
                root->event_data, tab_index, &pane_count,
                &tab_active_pane_id, &node_count, &root_node) != 0 ||
            pane_count <= 0 || pane_count > 512 || node_count <= 0 ||
            node_count > 1023 || root_node < 0 || root_node >= node_count) {
            layout_ready = FALSE;
            break;
        }
        if (tab_index == active_tab) active_pane_id = tab_active_pane_id;
        GtkWidget *page = pages[tab_index];
        GtkWidget *tab_widget = deetty_grid_notebook_get_tab_label(
            GTK_NOTEBOOK(root->notebook), page);
        GtkWidget *tab_label = tab_label_from_widget(tab_widget);
        for (int pane_index = 0; pane_index < pane_count; pane_index++) {
            uint64_t pane_id = 0;
            if (deetty_grid_restore_pane_id(
                    root->event_data, tab_index, pane_index, &pane_id) != 0 ||
                pane_id == 0) {
                layout_ready = FALSE;
                break;
            }
            DeettyGridContext *pane_context = NULL;
            if (pane_id == root->pane_id) {
                pane_context = root;
            } else {
                uint64_t restored_pane_id = 0;
                void *userdata = root->create_session(
                    root->event_data, pane_id, DEETTY_GRID_HOST_EVENT(RESTORED_PANE),
                    deetty_grid_session_dimension(root->columns),
                    deetty_grid_session_dimension(root->rows),
                    &restored_pane_id);
                if (userdata == NULL || restored_pane_id != pane_id) {
                    layout_ready = FALSE;
                    break;
                }
                pane_context = create_grid_context_for_session(
                    root, userdata, pane_id);
                if (pane_context == NULL) {
                    layout_ready = FALSE;
                    break;
                }
                pane_context->active = 1;
            }
            pane_context->page = page;
            pane_context->tab_label = tab_label;
            pane_total++;
        }
        if (!layout_ready || !rebuild_hot_session_page(
                root, tab_index, page, node_count, root_node)) {
            layout_ready = FALSE;
            break;
        }
    }

    root->hot_session_tab_count = tab_count;
    root->hot_session_pane_count = pane_total;
    root->hot_session_layout_ready = layout_ready;
    root->hot_session_restored = layout_ready;
    if (layout_ready) {
        deetty_grid_notebook_select_page(root->notebook, active_tab);
        DeettyGridContext *active = grid_context_for_pane(
            root, active_pane_id);
        root->hot_session_active_ready = active != NULL &&
            active->page == pages[active_tab];
        if (root->hot_session_active_ready) {
            for (guint index = 0; index < root->contexts->len; index++) {
                DeettyGridContext *candidate =
                    g_ptr_array_index(root->contexts, index);
                candidate->focused = candidate == active;
            }
                deetty_grid_focus_widget(NULL, active->area);
        }
        char smart_filter[1024] = {0};
        int smart_filter_length = deetty_grid_smart_filter_tag(
            root->event_data, smart_filter, sizeof(smart_filter) - 1);
        if (smart_filter_length >= 0 &&
            (size_t)smart_filter_length < sizeof(smart_filter)) {
            smart_filter[smart_filter_length] = '\0';
            root->smart_filter_tag = deetty_grid_memory_clear(root->smart_filter_tag);
            root->smart_filter_tag = smart_filter_length > 0
                ? g_strdup(smart_filter) : NULL;
            root->hot_session_smart_filter_ready = 1;
        }
    }
    deetty_grid_memory_free(pages);
    return layout_ready;
}

static DeettyGridContext *grid_context_on_other_page(DeettyGridContext *source) {
    for (guint index = 0; source->contexts != NULL &&
         index < source->contexts->len; index++) {
        DeettyGridContext *candidate =
            g_ptr_array_index(source->contexts, index);
        if (candidate->active && candidate->page != source->page) return candidate;
    }
    return NULL;
}

static gboolean replace_grid_widget(GtkWidget *parent, GtkWidget *old_widget,
                                    GtkWidget *replacement) {
    if (deetty_grid_widget_is_type(parent, DEETTY_GTK_PANED)) {
        gboolean was_first =
            deetty_grid_paned_get_child1(GTK_PANED(parent)) == old_widget;
        deetty_container_remove(parent, old_widget);
        if (was_first) {
            deetty_paned_pack1(parent, replacement, TRUE, FALSE);
        } else {
            deetty_paned_pack2(parent, replacement, TRUE, FALSE);
        }
        return TRUE;
    }
    if (deetty_grid_widget_is_type(parent, DEETTY_GTK_BOX)) {
        deetty_container_remove(parent, old_widget);
        deetty_box_pack_start(parent, replacement, TRUE, TRUE, 0);
        return TRUE;
    }
    return FALSE;
}

static gboolean detach_grid_context(DeettyGridContext *source) {
    if (source->page == NULL) return FALSE;
    if (grid_contexts_on_page(source, source->page) == 1) {
        gint page_index =
            deetty_grid_notebook_page_num(GTK_NOTEBOOK(source->notebook), source->page);
        if (page_index < 0) return FALSE;
        deetty_grid_object_ref(source->area);
        deetty_grid_notebook_remove_page(GTK_NOTEBOOK(source->notebook), page_index);
        update_notebook_chrome(source);
        return TRUE;
    }
    GtkWidget *split = deetty_grid_widget_get_parent(source->area);
    if (!deetty_grid_widget_is_type(split, DEETTY_GTK_PANED)) return FALSE;
    GtkWidget *first = deetty_grid_paned_get_child1(GTK_PANED(split));
    GtkWidget *second = deetty_grid_paned_get_child2(GTK_PANED(split));
    GtkWidget *sibling = first == source->area ? second : first;
    GtkWidget *grandparent = deetty_grid_widget_get_parent(split);
    if (sibling == NULL || grandparent == NULL ||
        (!deetty_grid_widget_is_type(grandparent, DEETTY_GTK_PANED) &&
         !deetty_grid_widget_is_type(grandparent, DEETTY_GTK_BOX))) return FALSE;

    deetty_grid_object_ref(source->area);
    deetty_grid_object_ref(sibling);
    deetty_container_remove(split, source->area);
    deetty_container_remove(split, sibling);
    gboolean replaced = replace_grid_widget(grandparent, split, sibling);
    deetty_grid_object_unref(sibling);
    if (!replaced) {
        deetty_grid_object_unref(source->area);
        return FALSE;
    }
    return TRUE;
}

typedef struct {
    DeettyGridContext *root;
    GtkWidget *layout;
    guint source_id;
    gulong layout_destroy_handler_id;
    guint attempts_remaining;
    gboolean resize_ratios_bound;
    gboolean layout_destroyed;
} DeettyEvenPaneRequest;

static void destroy_even_pane_request(gpointer user_data) {
    DeettyEvenPaneRequest *request = user_data;
    if (!request->layout_destroyed &&
        request->layout_destroy_handler_id != 0) {
        g_signal_handler_disconnect(request->layout,
                                    request->layout_destroy_handler_id);
    }
    deetty_grid_object_unref(request->layout);
    deetty_grid_memory_free(request);
}

static void stop_even_pane_distribution_on_layout_destroy(
    GtkWidget *layout, gpointer user_data) {
    (void)layout;
    DeettyEvenPaneRequest *request = user_data;
    request->layout_destroyed = TRUE;
    request->root->compact_even_distribution_cancelled = TRUE;
    request->layout_destroy_handler_id = 0;
    guint source_id = request->source_id;
    request->source_id = 0;
    if (source_id != 0) deetty_grid_source_remove(source_id);
}

static gboolean apply_even_pane_distribution(gpointer user_data) {
    DeettyEvenPaneRequest *request = user_data;
    if (deetty_grid_widget_in_destruction(request->layout) ||
        deetty_grid_widget_get_parent(request->layout) == NULL)
        return G_SOURCE_REMOVE;
    (void)deetty_apply_even_pane_positions(request->layout);
    if (!request->resize_ratios_bound) {
        bind_preset_max_positions(request->root, request->layout);
        request->resize_ratios_bound = TRUE;
    }
    deetty_grid_widget_queue_resize(request->layout);
    deetty_grid_widget_queue_draw(request->layout);
    g_assert(request->attempts_remaining > 0);
    request->attempts_remaining--;
    return request->attempts_remaining == 0
        ? G_SOURCE_REMOVE : G_SOURCE_CONTINUE;
}

static void schedule_even_pane_distribution(DeettyGridContext *context,
                                            GtkWidget *layout) {
    if (context == NULL || layout == NULL) return;
    DeettyGridLifecycleTimingPlan timing = {0};
    deetty_grid_lifecycle_timing_plan(&timing);
    DeettyEvenPaneRequest *request = g_new0(DeettyEvenPaneRequest, 1);
    request->root = root_grid_context(context);
    request->layout = deetty_grid_object_ref(layout);
    request->attempts_remaining = (guint)timing.even_pane_settle_attempts;
    /* GTK can report provisional allocations for several frames after a split
     * tree is mapped. Retry briefly, but bind cancellation to widget teardown
     * so an early tab/window close cannot leave a source holding the layout. */
    request->layout_destroy_handler_id = deetty_grid_signal_connect(
        layout, "destroy",
        G_CALLBACK(stop_even_pane_distribution_on_layout_destroy), request);
    request->source_id = g_timeout_add_full(
        G_PRIORITY_LOW, (guint)timing.even_pane_settle_interval_ms,
        apply_even_pane_distribution,
        request, destroy_even_pane_request);
    if (request->source_id == 0) destroy_even_pane_request(request);
}

static gboolean attach_grid_context(DeettyGridContext *source,
                                    DeettyGridContext *target) {
    if (target->page == NULL) return FALSE;
    GtkWidget *content_root = grid_page_content_root(target, target->page);
    if (content_root == NULL) {
        deetty_box_pack_start(target->page, source->area, TRUE, TRUE, 0);
    } else {
        GtkAllocation allocation;
        deetty_grid_widget_get_allocation(target->page, &allocation);
        deetty_grid_object_ref(content_root);
        deetty_container_remove(target->page, content_root);
        GtkWidget *split = deetty_paned_new(
            GTK_ORIENTATION_HORIZONTAL,
            root_grid_context(target)->pane_divider_px);
        deetty_paned_pack1(split, content_root, TRUE, FALSE);
        deetty_paned_pack2(split, source->area, TRUE, FALSE);
        deetty_box_pack_start(target->page, split, TRUE, TRUE, 0);
        deetty_grid_object_unref(content_root);
        deetty_grid_widget_show_all(split);
        if (allocation.width > 0) {
            deetty_paned_set_position(split, allocation.width / 2);
        }
    }
    deetty_grid_object_unref(source->area);
    source->page = target->page;
    source->tab_label = target->tab_label;
    source->pane_move_applied = 1;
    target->pane_move_applied = 1;
    gint page_index = deetty_grid_notebook_page_num(GTK_NOTEBOOK(source->notebook),
                                            target->page);
    if (page_index >= 0) {
        deetty_grid_notebook_select_page(source->notebook, page_index);
    }
    deetty_grid_widget_show_all(target->page);
    apply_smart_filter(root_grid_context(target));
    update_compact_tab(target);
    deetty_grid_focus_widget(NULL, source->area);
    if (source->event != NULL) {
        source->event(source->event_data, source->pane_id, DEETTY_GRID_HOST_EVENT(PANE_MOVED_RENDERED), 0,
                      (uint64_t)(g_get_monotonic_time() / 1000));
    }
    (void)bind_grid_layout_for_page(source);
    schedule_even_pane_distribution(
        source, grid_page_content_root(source, source->page));
    return TRUE;
}

static gboolean move_grid_context(DeettyGridContext *source,
                                  DeettyGridContext *target) {
    if (source == NULL || target == NULL || source == target ||
        source->page == target->page) return FALSE;
    DeettyGridContext *root = root_grid_context(source);
    if (root->zoomed_pane_id != 0) restore_zoomed_page(root);
    if (!detach_grid_context(source)) return FALSE;
    return attach_grid_context(source, target);
}

static void restore_zoomed_page(DeettyGridContext *root) {
    if (root->zoomed_pane_id == 0) return;
    DeettyGridContext *zoomed = grid_context_for_pane(root, root->zoomed_pane_id);
    GtkWidget *page = zoomed != NULL ? zoomed->page : NULL;
    if (page != NULL) deetty_grid_widget_show_all(page);
    for (guint index = 0; root->contexts != NULL && index < root->contexts->len; index++) {
        DeettyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (candidate->page != page) continue;
        gboolean visible = candidate->active &&
            (root->smart_filter_tag == NULL ||
             deetty_grid_pane_matches_smart_filter(
                 root->event_data, candidate->pane_id) != 0);
        deetty_grid_widget_set_visible(candidate->area, visible);
    }
    if (page != NULL) sync_grid_page_branch_visibility(root, page);
    root->zoomed_pane_id = 0;
    update_notebook_chrome(root);
}

static void destroy_retired_grid_context(DeettyGridContext *root,
                                         DeettyGridContext *context) {
    if (root == NULL || context == NULL || !context->heap_allocated) return;
    if (context->clipboard_requests != 0) return;
    stop_grid_context_sources(context);
    remove_grid_source(&context->cursor_blink_source);
    remove_grid_source(&context->maintenance_source);
    if (context->settings_dialog != NULL) deetty_grid_widget_destroy(context->settings_dialog);
    if (context->theme_dialog != NULL) deetty_grid_widget_destroy(context->theme_dialog);
    if (context->sharing_dialog != NULL) deetty_grid_widget_destroy(context->sharing_dialog);
    if (context->palette_dialog != NULL) deetty_grid_widget_destroy(context->palette_dialog);
    if (context->find_dialog != NULL) deetty_grid_widget_destroy(context->find_dialog);
    if (context->note_dialog != NULL) deetty_grid_widget_destroy(context->note_dialog);
    if (context->shortcuts_dialog != NULL) deetty_grid_widget_destroy(context->shortcuts_dialog);
    if (context->project_dialog != NULL) deetty_grid_widget_destroy(context->project_dialog);
    if (context->workspace_menu != NULL) deetty_grid_widget_destroy(context->workspace_menu);
    if (context->im_context != NULL) deetty_grid_im_context_focus_out(context->im_context);
    context->note_overlay_text = deetty_grid_memory_clear(context->note_overlay_text);
    context->note_overlay_label = deetty_grid_memory_clear(context->note_overlay_label);
    g_clear_pointer(&context->note_overlay_font, pango_font_description_free);
    context->status_feedback_text = deetty_grid_memory_clear(context->status_feedback_text);
    remove_grid_source(&context->status_feedback_source);
    remove_grid_source(&context->sharing_status_source);
    context->display_title = deetty_grid_memory_clear(context->display_title);
    context->font_family = deetty_grid_memory_clear(context->font_family);
    context->frame_cells = deetty_grid_memory_clear(context->frame_cells);
    context->dirty_row_buffer = deetty_grid_memory_clear(context->dirty_row_buffer);
    context->dirty_span_buffer = deetty_grid_memory_clear(context->dirty_span_buffer);
    destroy_grid_glyph_cache(context);
    destroy_gpu_resources(context);
    context->im_context = deetty_grid_object_clear(context->im_context);
    g_ptr_array_remove(root->contexts, context);
    deetty_grid_memory_free(context);
}

static void dispatch_grid_application_close_effects(
    DeettyGridContext *context, DeettyGridCloseTransition transition);

static gboolean dispatch_deferred_grid_application_close(gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    root->application_close_deferred_source = 0;
    dispatch_grid_application_close_effects(
        root, deetty_grid_close_source_fired(
                  &root->application_close, DEETTY_CLOSE_SOURCE_DEFERRED));
    return G_SOURCE_REMOVE;
}

static gboolean close_grid_application_idle(gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    root->application_close_preflight_source = 0;
    dispatch_grid_application_close_effects(
        root, deetty_grid_close_source_fired(
                  &root->application_close, DEETTY_CLOSE_SOURCE_PREFLIGHT));
    return G_SOURCE_REMOVE;
}

static void commit_grid_application_close(
    DeettyGridContext *root, DeettyApplicationCloseOrigin origin) {
    remove_grid_source(&root->application_close_deferred_source);
    dismiss_workspace_menu(root);
    remove_grid_source(&root->cursor_blink_source);
    remove_grid_source(&root->maintenance_source);
    guint active_sessions = 0;
    guint stopped_sessions = 0;
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        DeettyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (!candidate->active) continue;
        gboolean already_exited = candidate->exited;
        candidate->retiring = 1;
        if (!already_exited) candidate->active = 0;
        candidate->focused = 0;
        stop_grid_context_sources(candidate);
        if (candidate->im_context != NULL)
            deetty_grid_im_context_focus_out(candidate->im_context);
        active_sessions++;
        int close_status = already_exited
            ? 1 : deetty_grid_close_session(candidate->userdata,
                                             root->event_data);
        if (close_status > 1) candidate->userdata = NULL;
        if (already_exited || close_status > 0) stopped_sessions++;
        if (candidate->peer != NULL) {
            if (candidate->peer->peer == candidate)
                candidate->peer->peer = NULL;
            candidate->peer = NULL;
        }
        if (!already_exited) {
            candidate->exited = 1;
            candidate->exit_code = 0;
        }
    }
    gboolean all_sessions_stopped =
        active_sessions > 0 && stopped_sessions == active_sessions;
    root->tray_close_session_stopped =
        origin == DEETTY_CLOSE_ORIGIN_TRAY && all_sessions_stopped;
    root->window_close_session_stopped =
        origin == DEETTY_CLOSE_ORIGIN_TOOLBAR && all_sessions_stopped;
    if (deetty_grid_main_level() > 0) deetty_grid_main_quit();
}

static void dispatch_grid_application_close_effects(
    DeettyGridContext *context, DeettyGridCloseTransition transition) {
    DeettyGridContext *root = root_grid_context(context);
    if ((transition.effects & DEETTY_CLOSE_EFFECT_CANCEL_DEFERRED) != 0)
        remove_grid_source(&root->application_close_deferred_source);
    if ((transition.effects & DEETTY_CLOSE_EFFECT_CANCEL_PREFLIGHT) != 0)
        remove_grid_source(&root->application_close_preflight_source);
    if ((transition.effects & DEETTY_CLOSE_EFFECT_SCHEDULE_DEFERRED) != 0 &&
        root->application_close_deferred_source == 0)
        root->application_close_deferred_source = deetty_grid_source_idle_add(
            dispatch_deferred_grid_application_close, root);
    if ((transition.effects & DEETTY_CLOSE_EFFECT_SCHEDULE_PREFLIGHT) != 0 &&
        root->application_close_preflight_source == 0)
        root->application_close_preflight_source = deetty_grid_source_idle_add(
            close_grid_application_idle, root);
    if ((transition.effects & DEETTY_CLOSE_EFFECT_SCHEDULE_DWELL) != 0 &&
        root->application_close_preflight_source == 0)
        root->application_close_preflight_source = deetty_grid_source_timeout_add(
            80, close_grid_application_idle, root);
    if ((transition.effects & DEETTY_CLOSE_EFFECT_RUN_PREFLIGHT) != 0) {
        gboolean confirmed = confirm_grid_application_close(root);
        dispatch_grid_application_close_effects(
            root, deetty_grid_close_preflight_result(
                      &root->application_close, confirmed));
    }
    if ((transition.effects & DEETTY_CLOSE_EFFECT_COMMIT) != 0)
        commit_grid_application_close(root, transition.origin);
}

static void begin_grid_modal(DeettyGridContext *context) {
    DeettyGridContext *root = root_grid_context(context);
    dispatch_grid_application_close_effects(
        root, deetty_grid_close_modal_begin(&root->application_close));
}

static void end_grid_modal(DeettyGridContext *context) {
    DeettyGridContext *root = root_grid_context(context);
    dispatch_grid_application_close_effects(
        root, deetty_grid_close_modal_end(&root->application_close));
}

static gint run_grid_modal_dialog(DeettyGridContext *context,
                                  GtkDialog *dialog) {
    (void)configure_overlay_window_stacking(
        context, GTK_WIDGET(dialog), "deetty-dialog");
    begin_grid_modal(context);
    gint response = deetty_grid_dialog_run(dialog);
    end_grid_modal(context);
    return response;
}

static gboolean request_grid_application_close(
    DeettyGridContext *context, DeettyApplicationCloseOrigin origin) {
    DeettyGridContext *root = root_grid_context(context);
    DeettyGridCloseTransition transition =
        deetty_grid_close_request(&root->application_close, origin);
    dispatch_grid_application_close_effects(root, transition);
    return transition.accepted != 0;
}

static guint active_grid_context_count(DeettyGridContext *context) {
    DeettyGridContext *root = root_grid_context(context);
    guint count = 0;
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        DeettyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (candidate->active && !candidate->exited &&
            candidate->area != NULL && candidate->page != NULL) count++;
    }
    return count;
}

static gboolean focus_grid_context_idle(gpointer user_data) {
    DeettyGridContext *context = user_data;
    context->focus_deferred_source = 0;
    if (!grid_context_session_available(context) || context->exited ||
        context->area == NULL || context->page == NULL) return G_SOURCE_REMOVE;
    DeettyGridContext *root = root_grid_context(context);
    gint page_index = deetty_grid_notebook_page_num(GTK_NOTEBOOK(root->notebook),
                                            context->page);
    if (page_index >= 0)
        deetty_grid_notebook_select_page(root->notebook, page_index);
    deetty_grid_focus_widget(NULL, context->area);
    return G_SOURCE_REMOVE;
}

static gboolean focus_grid_area_idle(gpointer user_data) {
    GtkWidget *area = GTK_WIDGET(user_data);
    if (!deetty_grid_widget_in_destruction(area) && deetty_grid_widget_get_visible(area))
        deetty_grid_focus_widget(NULL, area);
    deetty_grid_object_unref(area);
    return G_SOURCE_REMOVE;
}

static void defer_grid_context_focus(DeettyGridContext *context) {
    if (context == NULL || context->area == NULL) return;
    /* Let the activating key event finish before the new terminal owns focus. */
    root_grid_context(context)->session_creation_focus_deferred = 1;
    deetty_grid_source_idle_add(focus_grid_area_idle, deetty_grid_object_ref(context->area));
}

static guint foreground_process_count(DeettyGridContext *context,
                                      GtkWidget *page) {
    DeettyGridContext *root = root_grid_context(context);
    guint count = 0;
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        DeettyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (!candidate->active || candidate->exited ||
            candidate->userdata == NULL ||
            (page != NULL && candidate->page != page))
            continue;
        if (deetty_grid_has_foreground_process(candidate->userdata) > 0)
            count++;
    }
    return count;
}

static gboolean accept_dialog_smoke(gpointer user_data) {
    GtkWidget *dialog = user_data;
    if (deetty_grid_widget_is_type(dialog, DEETTY_GTK_DIALOG))
        deetty_grid_dialog_response(GTK_DIALOG(dialog), GTK_RESPONSE_ACCEPT);
    return G_SOURCE_REMOVE;
}

static gboolean confirm_terminal_process_close(DeettyGridContext *context,
                                               const char *scope,
                                               guint busy_count,
                                               gboolean force_prompt) {
    if (busy_count == 0 && !force_prompt) return TRUE;
    DeettyGridContext *root = root_grid_context(context);
    if (!root->window_presented)
        toggle_grid_window(root);
    else if (!root->layer_shell_active)
        deetty_grid_window_present(root->window);

    char title[64] = {0};
    char detail[256] = {0};
    char secondary[32] = {0};
    char primary[32] = {0};
    if (deetty_grid_close_confirmation_text(
            (const unsigned char *)scope,
            scope != NULL ? strlen(scope) : 0,
            busy_count,
            (unsigned char *)title, sizeof(title),
            (unsigned char *)detail, sizeof(detail),
            (unsigned char *)secondary, sizeof(secondary),
            (unsigned char *)primary, sizeof(primary)) <= 0)
        return FALSE;
    GtkWidget *dialog = deetty_message_dialog_new(
        GTK_WIDGET(root->window), GTK_MESSAGE_WARNING, title, detail,
        secondary, primary);
    root->terminal_close_prompt_count++;
    root->terminal_close_prompt_busy_count += (int)busy_count;
    (void)configure_overlay_window_stacking(
        root, dialog, "deetty-close-confirmation");
    show_all_with_action_affordances(dialog);
    if (root->workspace_smoke >= 0)
        deetty_grid_source_idle_add(accept_dialog_smoke, dialog);
    gint response = run_grid_modal_dialog(root, GTK_DIALOG(dialog));
    deetty_grid_widget_destroy(dialog);
    if (response == GTK_RESPONSE_ACCEPT) {
        root->terminal_close_prompt_accepted++;
        if (g_strcmp0(scope, "pane") == 0 &&
            dogfood_active_omp_count(root) >= 4)
            emit_dogfood_event(root, "omp_close_accept", 0,
                               (int)busy_count, "pane");
        return TRUE;
    }
    if (g_strcmp0(scope, "pane") == 0 &&
        dogfood_active_omp_count(root) >= 4)
        emit_dogfood_event(root, "omp_close_cancel", 0,
                           (int)busy_count, "pane");
    return FALSE;
}

static gboolean close_grid_pane(DeettyGridContext *context) {
    DeettyGridContext *root = root_grid_context(context);
    if (context == NULL || !context->active || context->area == NULL ||
        context->page == NULL || root->event_data == NULL ||
        active_grid_context_count(root) <= 1) return FALSE;
    gboolean dogfood_omp_target = context->dogfood_omp_seen;
    guint page_context_count = grid_contexts_on_page(root, context->page);
    gboolean closes_tab = page_context_count == 1;
    if (!closes_tab) {
        GtkWidget *split = deetty_grid_widget_get_parent(context->area);
        if (!deetty_grid_widget_is_type(split, DEETTY_GTK_PANED)) return FALSE;
        GtkWidget *grandparent = deetty_grid_widget_get_parent(split);
        if (grandparent == NULL ||
            (!deetty_grid_widget_is_type(grandparent, DEETTY_GTK_PANED) &&
             !deetty_grid_widget_is_type(grandparent, DEETTY_GTK_BOX)))
            return FALSE;
    }
    if (deetty_grid_has_foreground_process(context->userdata) > 0 &&
        !confirm_terminal_process_close(root, "pane", 1, FALSE))
        return FALSE;

    uint64_t active_pane_id = 0;
    int model_tab_closed = 0;
    if (deetty_grid_close_pane(root->event_data, context->pane_id,
                               &active_pane_id, &model_tab_closed) <= 0 ||
        active_pane_id == 0) return FALSE;
    if (root->zoomed_pane_id != 0) restore_zoomed_page(root);

    stop_grid_context_sources(context);
    context->retiring = 1;
    context->focused = 0;
    if (context->im_context != NULL) deetty_grid_im_context_focus_out(context->im_context);
    int close_status = deetty_grid_close_session(context->userdata,
                                                  root->event_data);
    if (close_status > 1) context->userdata = NULL;
    gboolean session_stopped = close_status > 0;
    if (context->peer != NULL) {
        if (context->peer->peer == context) context->peer->peer = NULL;
        context->peer = NULL;
    }

    GtkWidget *area = context->area;
    GtkWidget *page = context->page;
    gboolean rendered_closed = FALSE;
    if (model_tab_closed != 0) {
        gint page_index = deetty_grid_notebook_page_num(GTK_NOTEBOOK(root->notebook),
                                                page);
        if (page_index >= 0) {
            deetty_grid_notebook_remove_page(GTK_NOTEBOOK(root->notebook), page_index);
            rendered_closed = TRUE;
        }
    } else if (detach_grid_context(context)) {
        deetty_grid_widget_destroy(area);
        deetty_grid_object_unref(area);
        rendered_closed = TRUE;
    }

    context->active = 0;
    if (!context->primary) context->exited = 1;
    context->area = NULL;
    context->page = NULL;
    context->tab_label = NULL;
    update_notebook_chrome(root);

    DeettyGridContext *remaining = grid_context_for_pane(root, active_pane_id);
    if (remaining == NULL || !remaining->active || remaining->area == NULL)
        remaining = active_grid_context(root);
    if (rendered_closed && model_tab_closed == 0 && remaining != NULL &&
        remaining->page == page && grid_contexts_on_page(root, page) > 1) {
        deetty_grid_widget_show_all(page);
        deetty_grid_widget_queue_resize(page);
        (void)bind_grid_layout_for_page(remaining);
        schedule_even_pane_distribution(
            remaining, grid_page_content_root(remaining, page));
    }
    if (remaining != NULL && remaining->active && remaining->area != NULL) {
        gint page_index = deetty_grid_notebook_page_num(GTK_NOTEBOOK(root->notebook),
                                                remaining->page);
        if (page_index >= 0)
            deetty_grid_notebook_select_page(root->notebook, page_index);
        deetty_grid_widget_show_all(remaining->page);
        apply_smart_filter(root);
        update_compact_tab(remaining);
        if (deetty_grid_widget_get_visible(remaining->area))
            deetty_grid_focus_widget(NULL, remaining->area);
        remove_grid_source(&remaining->focus_deferred_source);
        remaining->focus_deferred_source =
            deetty_grid_source_idle_add(focus_grid_context_idle, remaining);
    }
    root->pane_close_session_stopped = session_stopped;
    root->pane_close_applied = rendered_closed && session_stopped;
    gboolean applied = root->pane_close_applied;
    if (applied && dogfood_omp_target) {
        guint dogfood_remaining = dogfood_active_omp_count(root);
        if (dogfood_remaining >= 3)
            emit_dogfood_event(
                root, "omp_close_accept_isolated", context->pane_id,
                (int)dogfood_remaining, "session_stopped");
    }
    if (context->heap_allocated)
        destroy_retired_grid_context(root, context);
    return applied;
}

static gboolean close_grid_tab(DeettyGridContext *context, GtkWidget *page) {
    DeettyGridContext *root = root_grid_context(context);
    if (page == NULL || root->notebook == NULL ||
        deetty_grid_notebook_get_n_pages(GTK_NOTEBOOK(root->notebook)) <= 1) return FALSE;
    gint page_index = deetty_grid_notebook_page_num(GTK_NOTEBOOK(root->notebook), page);
    DeettyGridContext *representative = grid_context_for_page(root, page);
    guint context_count = grid_contexts_on_page(root, page);
    if (page_index < 0 || representative == NULL || context_count == 0 ||
        root->event_data == NULL) return FALSE;

    guint busy_count = foreground_process_count(root, page);
    if (!confirm_terminal_process_close(root, "tab", busy_count, FALSE)) return FALSE;

    int model_pane_count = deetty_grid_close_tab(root->event_data,
                                                 representative->pane_id);
    if (model_pane_count <= 0) return FALSE;
    if (root->zoomed_pane_id != 0) {
        DeettyGridContext *zoomed = grid_context_for_pane(root,
                                                          root->zoomed_pane_id);
        if (zoomed != NULL && zoomed->page == page) restore_zoomed_page(root);
    }

    guint stopped_sessions = 0;
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        DeettyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (!candidate->active || candidate->page != page) continue;
        stop_grid_context_sources(candidate);
        candidate->retiring = 1;
        candidate->active = 0;
        candidate->focused = 0;
        if (candidate->im_context != NULL)
            deetty_grid_im_context_focus_out(candidate->im_context);
        int close_status = deetty_grid_close_session(candidate->userdata,
                                                      root->event_data);
        if (close_status > 1) candidate->userdata = NULL;
        stopped_sessions += close_status > 0;
        if (candidate->peer != NULL) {
            if (candidate->peer->peer == candidate)
                candidate->peer->peer = NULL;
            candidate->peer = NULL;
        }
        if (!candidate->primary) candidate->exited = 1;
    }

    deetty_grid_notebook_remove_page(GTK_NOTEBOOK(root->notebook), page_index);
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        DeettyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (candidate->page != page) continue;
        candidate->area = NULL;
        candidate->page = NULL;
        candidate->tab_label = NULL;
    }
    guint retire_index = 0;
    while (root->contexts != NULL && retire_index < root->contexts->len) {
        DeettyGridContext *candidate = g_ptr_array_index(root->contexts,
                                                         retire_index);
        if (candidate->heap_allocated && !candidate->active &&
            candidate->page == NULL) {
            guint previous_length = root->contexts->len;
            destroy_retired_grid_context(root, candidate);
            if (root->contexts->len < previous_length) continue;
        }
        retire_index++;
    }
    update_notebook_chrome(root);
    DeettyGridContext *remaining = active_grid_context(root);
    if (remaining->area != NULL) deetty_grid_focus_widget(NULL, remaining->area);
    root->tab_close_session_stopped =
        stopped_sessions == context_count &&
        context_count == (guint)model_pane_count;
    root->tab_close_applied = root->tab_close_session_stopped &&
        deetty_grid_notebook_get_n_pages(GTK_NOTEBOOK(root->notebook)) >= 1;
    root->tab_close_remaining_focused = remaining->area != NULL &&
        deetty_grid_widget_has_focus(remaining->area);
    return root->tab_close_applied;
}

static void toggle_grid_zoom(DeettyGridContext *context) {
    DeettyGridContext *root = root_grid_context(context);
    DeettyGridZoomPlan zoom_plan = {0};
    deetty_grid_zoom_plan(
        root->zoomed_pane_id, context->pane_id, &zoom_plan);
    restore_zoomed_page(root);
    if (zoom_plan.enter != 0) {
        deetty_grid_widget_show_all(context->page);
        for (guint index = 0; root->contexts != NULL && index < root->contexts->len; index++) {
            DeettyGridContext *candidate = g_ptr_array_index(root->contexts, index);
            if (candidate->page != context->page) continue;
            if (candidate == context) deetty_grid_widget_show(candidate->area);
            else deetty_grid_widget_hide(candidate->area);
        }
        sync_grid_page_branch_visibility(root, context->page);
        deetty_grid_notebook_apply_policy(
            root->notebook, root->window_toolbar_controls,
            root->tab_position, FALSE);
        root->zoomed_pane_id = context->pane_id;
        char title[513] = {0};
        size_t title_length = 0;
        int title_result = context->title != NULL
            ? context->title(context->userdata, title, sizeof(title) - 1) : 0;
        if (title_result > 0 && title_result < (int)sizeof(title)) {
            title[title_result] = '\0';
            title_length = (size_t)title_result;
        }
        char message[1024];
        if (deetty_grid_pane_zoom_feedback_text(
                context->pane_id,
                (const unsigned char *)title, title_length,
                (const unsigned char *)context->display_title,
                context->display_title != NULL
                    ? strlen(context->display_title) : 0,
                (unsigned char *)message, sizeof(message)) > 0)
            show_status_feedback(context, message);
    }
    root->compact_zoom_toggled = 1;
    if (context->event != NULL) {
        context->event(context->event_data, context->pane_id, DEETTY_GRID_HOST_EVENT(ZOOM_TOGGLED),
                       zoom_plan.enter,
                       (uint64_t)(g_get_monotonic_time() / 1000));
    }
    deetty_grid_focus_widget(NULL, context->area);
    deetty_grid_widget_queue_resize(context->page);
}

static gboolean focus_grid_direction(DeettyGridContext *context, int dx, int dy) {
    DeettyGridContext *root = root_grid_context(context);
    gint source_x = 0, source_y = 0;
    GtkAllocation source_allocation;
    deetty_grid_widget_get_allocation(context->area, &source_allocation);
    if (!deetty_grid_widget_translate_coordinates(context->area, root->window, 0, 0,
                                          &source_x, &source_y)) return FALSE;
    DeettyGridRectangle source = {
        .x = source_x,
        .y = source_y,
        .width = source_allocation.width,
        .height = source_allocation.height,
    };
    DeettyGridDirectionalFocusPlan plan;
    deetty_grid_directional_focus_begin(&source, dx, dy, &plan);
    if (!plan.active) return FALSE;

    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        DeettyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (candidate == context || !candidate->active || candidate->exited ||
            candidate->page != context->page || candidate->area == NULL ||
            !deetty_grid_widget_get_visible(candidate->area) || index > G_MAXINT)
            continue;
        gint x = 0, y = 0;
        GtkAllocation allocation;
        deetty_grid_widget_get_allocation(candidate->area, &allocation);
        if (!deetty_grid_widget_translate_coordinates(candidate->area, root->window,
                                              0, 0, &x, &y))
            continue;
        DeettyGridRectangle rectangle = {
            .x = x,
            .y = y,
            .width = allocation.width,
            .height = allocation.height,
        };
        deetty_grid_directional_focus_consider(
            &plan, &rectangle, (gint)index);
    }
    if (plan.target_index < 0 || root->contexts == NULL ||
        (guint)plan.target_index >= root->contexts->len)
        return FALSE;
    DeettyGridContext *best =
        g_ptr_array_index(root->contexts, (guint)plan.target_index);
    root->compact_directional_focus = 1;
    if (best->event != NULL)
        best->event(best->event_data, best->pane_id, DEETTY_GRID_HOST_EVENT(DIRECTIONAL_FOCUS), 0,
                    (uint64_t)(g_get_monotonic_time() / 1000));
    deetty_grid_focus_widget(NULL, best->area);
    return TRUE;
}

static GtkWidget *build_preset_line(GtkWidget **widgets, guint count,
                                    GtkOrientation orientation) {
    if (count == 0) return NULL;
    if (count == 1) return widgets[0];
    GtkWidget *rest = build_preset_line(widgets + 1, count - 1,
                                        orientation);
    if (rest == NULL) return NULL;
    GtkWidget *split = deetty_paned_new((int)orientation, 0);
    deetty_paned_pack1(split, widgets[0], TRUE, FALSE);
    deetty_paned_pack2(split, rest, TRUE, FALSE);
    guint ratio_permille = 1000 / count;
    deetty_grid_object_set_data(
        split, "deetty-preset-ratio",
        GUINT_TO_POINTER(ratio_permille));
    return split;
}

static void apply_preset_paned_positions(GtkWidget *widget,
                                         gint width, gint height) {
    (void)width;
    (void)height;
    if (!deetty_grid_widget_is_type(widget, DEETTY_GTK_PANED)) return;
    gint max_position = 0;
    g_object_get(G_OBJECT(widget), "max-position", &max_position, NULL);
    guint ratio_permille = GPOINTER_TO_UINT(deetty_grid_object_get_data(
        widget, "deetty-preset-ratio"));
    if (max_position > 0 && max_position < G_MAXINT / 2)
        deetty_paned_set_position(
            widget,
            deetty_grid_split_position(max_position, (int)ratio_permille));
    apply_preset_paned_positions(
        deetty_grid_paned_get_child1(GTK_PANED(widget)), 0, 0);
    apply_preset_paned_positions(
        deetty_grid_paned_get_child2(GTK_PANED(widget)), 0, 0);
}

static gboolean apply_preset_split_position(gpointer user_data) {
    GtkWidget *widget = GTK_WIDGET(user_data);
    deetty_grid_object_set_data(widget, "deetty-preset-position-source", NULL);
    DeettyGridContext *root = deetty_grid_object_get_data(
        widget, "deetty-grid-root-context");
    if (root != NULL && deetty_grid_widget_is_type(widget, DEETTY_GTK_PANED)) {
        root->layout_restore_applying = 1;
        gint max_position = 0;
        g_object_get(G_OBJECT(widget), "max-position", &max_position, NULL);
        guint ratio_permille = GPOINTER_TO_UINT(deetty_grid_object_get_data(
            widget, "deetty-preset-ratio"));
        if (max_position > 0 && max_position < G_MAXINT / 2)
            deetty_paned_set_position(
                widget,
                deetty_grid_split_position(max_position, (int)ratio_permille));
        root->layout_restore_applying = 0;
    }
    deetty_grid_object_unref(widget);
    return G_SOURCE_REMOVE;
}

static void on_preset_max_position_changed(
    GObject *object, GParamSpec *parameter, gpointer user_data) {
    (void)parameter;
    (void)user_data;
    if (!deetty_grid_widget_is_type(object, DEETTY_GTK_PANED) ||
        deetty_grid_object_get_data(object, "deetty-preset-position-source") != NULL)
        return;
    guint source = deetty_grid_source_idle_add(apply_preset_split_position,
                              deetty_grid_object_ref(object));
    deetty_grid_object_set_data(object, "deetty-preset-position-source",
                                GUINT_TO_POINTER(source));
}

static void bind_preset_max_positions(DeettyGridContext *root,
                                      GtkWidget *widget) {
    if (!deetty_grid_widget_is_type(widget, DEETTY_GTK_PANED)) return;
    deetty_grid_object_set_data(widget, "deetty-grid-root-context", root);
    if (deetty_grid_object_get_data(
            widget, "deetty-max-position-bound") == NULL) {
        deetty_grid_signal_connect(widget, "notify::max-position",
                         G_CALLBACK(on_preset_max_position_changed), root);
        deetty_grid_object_set_data(
            widget, "deetty-max-position-bound",
            GINT_TO_POINTER(1));
    }
    bind_preset_max_positions(
        root, deetty_grid_paned_get_child1(GTK_PANED(widget)));
    bind_preset_max_positions(
        root, deetty_grid_paned_get_child2(GTK_PANED(widget)));
}


typedef struct {
    GtkWidget *page;
    guint attempts_remaining;
} DeettyPresetSettleRequest;

static void queue_grid_preset_widget_draw(GtkWidget *widget,
                                          gpointer user_data) {
    (void)user_data;
    deetty_grid_widget_queue_draw(widget);
    if (deetty_grid_widget_is_type(widget, DEETTY_GTK_CONTAINER))
        deetty_grid_container_forall(
            widget, queue_grid_preset_widget_draw, NULL);
}

static void destroy_grid_preset_settle_request(gpointer user_data) {
    DeettyPresetSettleRequest *request = user_data;
    deetty_grid_object_unref(request->page);
    deetty_grid_memory_free(request);
}

static gboolean settle_grid_preset_page(gpointer user_data) {
    DeettyPresetSettleRequest *request = user_data;
    if (deetty_grid_widget_in_destruction(request->page)) return G_SOURCE_REMOVE;

    /* KWin may defer child paints while nested GtkPaned allocations settle.
     * Refreshing the bounded widget tree over four main-loop turns ensures
     * every terminal receives damage without blocking the UI thread. The
     * request owns the page, so closing the tab cannot leave a stale context
     * callback behind. */
    deetty_grid_widget_queue_resize(request->page);
    queue_grid_preset_widget_draw(request->page, NULL);

    g_assert(request->attempts_remaining > 0);
    request->attempts_remaining--;
    return request->attempts_remaining == 0
        ? G_SOURCE_REMOVE
        : G_SOURCE_CONTINUE;
}

static void schedule_grid_preset_settle(GtkWidget *page) {
    DeettyGridLifecycleTimingPlan timing = {0};
    deetty_grid_lifecycle_timing_plan(&timing);
    DeettyPresetSettleRequest *request = g_new0(
        DeettyPresetSettleRequest, 1);
    request->page = deetty_grid_object_ref(page);
    request->attempts_remaining = (guint)timing.preset_settle_attempts;
    guint source = g_timeout_add_full(
        G_PRIORITY_DEFAULT, (guint)timing.preset_settle_interval_ms,
        settle_grid_preset_page, request,
        destroy_grid_preset_settle_request);
    if (source == 0) destroy_grid_preset_settle_request(request);
}

static gboolean rebuild_grid_preset_page(
    DeettyGridContext *source, DeettyGridContext **ordered,
    guint count, guint rows, guint columns) {
    if (source == NULL || source->page == NULL || count == 0 ||
        count > 16 || rows == 0 || columns == 0 ||
        rows * columns != count) return FALSE;
    DeettyGridContext *root = root_grid_context(source);
    GtkWidget *page = source->page;
    GtkWidget *areas[16] = {0};
    gboolean held[16] = {FALSE};
    for (guint index = 0; index < count; index++) {
        if (ordered[index] == NULL || ordered[index]->area == NULL) return FALSE;
        areas[index] = ordered[index]->area;
        if (deetty_grid_widget_get_parent(areas[index]) != NULL) {
            deetty_grid_object_ref(areas[index]);
            held[index] = TRUE;
        }
    }

    GtkWidget *old_root = grid_page_content_root(source, page);
    if (old_root != NULL)
        deetty_container_remove(page, old_root);

    GtkWidget *row_widgets[4] = {0};
    for (guint row = 0; row < rows; row++) {
        row_widgets[row] = build_preset_line(
            areas + row * columns, columns, GTK_ORIENTATION_HORIZONTAL);
        if (row_widgets[row] == NULL) return FALSE;
    }
    GtkWidget *grid_root = build_preset_line(
        row_widgets, rows, GTK_ORIENTATION_VERTICAL);
    if (grid_root == NULL) return FALSE;
    deetty_apply_pane_divider_style(grid_root, root->pane_divider_px);
    bind_preset_max_positions(root, grid_root);
    deetty_box_pack_start(page, grid_root, TRUE, TRUE, 0);
    for (guint index = 0; index < count; index++) {
        ordered[index]->page = page;
        ordered[index]->tab_label = source->tab_label;
        if (held[index]) deetty_grid_object_unref(areas[index]);
    }
    deetty_grid_widget_show_all(page);
    deetty_grid_widget_queue_resize(page);
    schedule_even_pane_distribution(source, grid_root);
    schedule_grid_preset_settle(page);
    for (guint index = 0; index < count; index++) {
        if (!ordered[index]->active) start_grid_context(ordered[index]);
        deetty_grid_widget_set_sensitive(ordered[index]->area, TRUE);
        deetty_grid_widget_set_can_focus(ordered[index]->area, TRUE);
        deetty_grid_widget_show(ordered[index]->area);
        deetty_grid_widget_queue_draw(ordered[index]->area);
        update_compact_tab(ordered[index]);
    }
    gint page_index = deetty_grid_notebook_page_num(GTK_NOTEBOOK(source->notebook),
                                            page);
    if (page_index >= 0)
        deetty_grid_notebook_select_page(source->notebook, page_index);
    apply_smart_filter(root);
    if (deetty_grid_widget_get_visible(ordered[0]->area))
        defer_grid_context_focus(ordered[0]);
    return TRUE;
}

static gboolean respond_layout_preset_prompt_smoke(gpointer user_data) {
    GtkDialog *dialog = GTK_DIALOG(user_data);
    deetty_grid_dialog_response(dialog, GPOINTER_TO_INT(
        deetty_grid_object_get_data(dialog, "deetty-layout-prompt-response")));
    return G_SOURCE_REMOVE;
}

static gboolean apply_grid_layout_preset(DeettyGridContext *context,
                                         int event_code,
                                         gboolean restore_missing) {
    DeettyGridContext *root = root_grid_context(context);
    if (context == NULL || !context->active || context->area == NULL ||
        context->page == NULL || root->event_data == NULL)
        return FALSE;
    DeettyGridLayoutPresetPlan layout_plan = {0};
    deetty_grid_layout_preset_plan(event_code, &layout_plan);
    if (layout_plan.valid == 0) return FALSE;
    guint rows = (guint)layout_plan.rows;
    guint cols = (guint)layout_plan.columns;
    guint target_count = (guint)layout_plan.target_count;
    GtkWidget *page = context->page;
    if (root->zoomed_pane_id != 0) restore_zoomed_page(root);
    if (context->event != NULL)
        context->event(context->event_data, context->pane_id, DEETTY_GRID_HOST_EVENT(PANE_FOCUS), 0,
                       (uint64_t)(g_get_monotonic_time() / 1000));

    guint current_count = grid_contexts_on_page(root, page);
    if (current_count > target_count &&
        !(root->workspace_smoke == 21 && !root->layout_preset_finalizing)) {
        guint extra_count = current_count - target_count;
        if (root->workspace_smoke == 21) {
            char title[128] = {0};
            char detail[256] = {0};
            char secondary[32] = {0};
            char primary[32] = {0};
            if (deetty_grid_layout_prompt_text(
                    extra_count,
                    (unsigned char *)title, sizeof(title),
                    (unsigned char *)detail, sizeof(detail),
                    (unsigned char *)secondary, sizeof(secondary),
                    (unsigned char *)primary, sizeof(primary)) <= 0)
                return FALSE;
            GtkWidget *dialog = deetty_message_dialog_new(
                GTK_WIDGET(root->window), GTK_MESSAGE_WARNING, title, detail,
                secondary, primary);
            gint smoke_response = root->layout_preset_prompt_count++ == 0
                ? GTK_RESPONSE_CANCEL : GTK_RESPONSE_ACCEPT;
            deetty_grid_object_set_data(
                dialog, "deetty-layout-prompt-response",
                GINT_TO_POINTER(smoke_response));
            deetty_grid_source_idle_add(respond_layout_preset_prompt_smoke, dialog);
            gint response = run_grid_modal_dialog(root, GTK_DIALOG(dialog));
            deetty_grid_widget_destroy(dialog);
            if (response != GTK_RESPONSE_ACCEPT) {
                root->layout_preset_prompt_cancelled++;
                return FALSE;
            }
            root->layout_preset_prompt_accepted++;
        }

        DeettyGridContext *extras[15] = {0};
        guint collected = 0;
        for (gint index = (gint)root->contexts->len - 1;
             index >= 0 && collected < extra_count; index--) {
            DeettyGridContext *candidate = g_ptr_array_index(
                root->contexts, (guint)index);
            if (candidate != context && candidate->active &&
                !candidate->exited && candidate->page == page &&
                candidate->area != NULL && candidate->pane_id <= G_MAXINT)
                extras[collected++] = candidate;
        }
        if (collected != extra_count) return FALSE;
        DeettyGridContext *destination = create_grid_context(context, DEETTY_GRID_HOST_EVENT(WORKSPACE_NEW_TAB));
        if (destination == NULL || !add_grid_tab(context, destination)) return FALSE;
        start_grid_context(destination);
        for (guint extra_index = 0; extra_index < extra_count; extra_index++) {
            if (context->event != NULL)
                context->event(context->event_data, destination->pane_id, DEETTY_GRID_HOST_EVENT(PANE_MOVED),
                               (int)extras[extra_index]->pane_id,
                               (uint64_t)(g_get_monotonic_time() / 1000));
            if (!move_grid_context(extras[extra_index], destination)) return FALSE;
        }
        if (!close_grid_pane(destination)) return FALSE;
        if (context->event != NULL)
            context->event(context->event_data, context->pane_id, DEETTY_GRID_HOST_EVENT(PANE_FOCUS), 0,
                           (uint64_t)(g_get_monotonic_time() / 1000));
        root->layout_preset_moved_count += (int)extra_count;
        current_count = target_count;
    }
    while (current_count > target_count) {
        DeettyGridContext *candidate = NULL;
        for (gint index = root->contexts != NULL
                 ? (gint)root->contexts->len - 1
                 : -1;
             index >= 0; index--) {
            DeettyGridContext *next = g_ptr_array_index(root->contexts,
                                                        (guint)index);
            if (next != context && next->active && !next->exited &&
                next->page == page && next->area != NULL) {
                candidate = next;
                break;
            }
        }
        if (candidate == NULL || !close_grid_pane(candidate)) return FALSE;
        root->layout_preset_closed_count++;
        current_count--;
    }

    while (!restore_missing && current_count < target_count) {
        DeettyGridContext *created = create_grid_context(context, DEETTY_GRID_HOST_EVENT(WORKSPACE_SPLIT));
        if (created == NULL) return FALSE;
        created->page = page;
        created->tab_label = context->tab_label;
        root->layout_preset_created_count++;
        current_count++;
    }

    uint64_t pane_ids[16] = {0};
    int model_count = deetty_grid_apply_preset(
        root->event_data, context->pane_id, event_code,
        pane_ids, G_N_ELEMENTS(pane_ids));
    if (model_count != (int)target_count) {
        g_printerr("native_grid_layout_apply event=%d reason=model_count expected=%u actual=%d\n",
                   event_code, target_count, model_count);
        return FALSE;
    }
    DeettyGridContext *ordered[16] = {0};
    for (guint index = 0; index < target_count; index++) {
        ordered[index] = grid_context_for_pane(root, pane_ids[index]);
        if (ordered[index] == NULL || ordered[index]->userdata == NULL ||
            ordered[index]->retiring || ordered[index]->exited) {
            ordered[index] = restore_grid_context(
                context, pane_ids[index],
                deetty_grid_partition_size(context->columns, (int)cols),
                deetty_grid_partition_size(context->rows, (int)rows));
            if (ordered[index] != NULL) {
                ordered[index]->page = page;
                ordered[index]->tab_label = context->tab_label;
            }
        }
        if (ordered[index] == NULL || ordered[index]->area == NULL ||
            ordered[index]->page != page) {
            g_printerr("native_grid_layout_apply event=%d reason=context pane=%" G_GUINT64_FORMAT " found=%d area=%d page=%d\n",
                       event_code, pane_ids[index], ordered[index] != NULL,
                       ordered[index] != NULL && ordered[index]->area != NULL,
                       ordered[index] != NULL && ordered[index]->page == page);
            return FALSE;
        }
    }
    gboolean rebuilt = rebuild_grid_preset_page(
        context, ordered, target_count, rows, cols);
    if (rebuilt) {
        gboolean bound = bind_grid_layout_for_page(context);
        if (!bound)
            g_printerr("native_grid_layout_apply event=%d reason=bind_failed contexts=%u\n",
                       event_code, grid_contexts_on_page(root, page));
        rebuilt = bound;
    } else {
        g_printerr("native_grid_layout_apply event=%d reason=rebuild_failed contexts=%u\n",
                   event_code, grid_contexts_on_page(root, page));
    }
    if (rebuilt && event_code == DEETTY_GRID_HOST_EVENT(LAYOUT_PRESET_1X1)) root->layout_preset_1x1_applied = 1;
    if (rebuilt && event_code == DEETTY_GRID_HOST_EVENT(LAYOUT_PRESET_2X2)) root->layout_preset_2x2_applied = 1;
    if (rebuilt && event_code == DEETTY_GRID_HOST_EVENT(LAYOUT_PRESET_4X2)) root->layout_preset_4x2_applied = 1;
    if (rebuilt && event_code == DEETTY_GRID_HOST_EVENT(LAYOUT_PRESET_3X3)) root->layout_preset_3x3_applied = 1;
    if (rebuilt && event_code == DEETTY_GRID_HOST_EVENT(LAYOUT_PRESET_4X4)) root->layout_preset_4x4_applied = 1;
    return rebuilt;
}

static gboolean open_grid_layout_preset_tab(DeettyGridContext *context,
                                             int event_code) {
    DeettyGridContext *root = root_grid_context(context);
    DeettyGridContext *created = create_grid_context(context, DEETTY_GRID_HOST_EVENT(WORKSPACE_NEW_TAB));
    if (created == NULL || !add_grid_tab(context, created)) return FALSE;
    GtkWidget *page = created->page;
    start_grid_context(created);
    if (!apply_grid_layout_preset(created, event_code, TRUE)) {
        g_printerr("native_grid_new_layout_failed event=%d pane=%" G_GUINT64_FORMAT "\n",
                   event_code, created->pane_id);
        if (page != NULL) (void)close_grid_tab(root, page);
        return FALSE;
    }
    return TRUE;
}

static void emit_grid_workspace_event(DeettyGridContext *context, int event_code) {
    DeettyGridContext *root = root_grid_context(context);
    DeettyGridWorkspaceEventPlan plan = {0};
    deetty_grid_workspace_event_plan(
        event_code, root->workspace_smoke, &plan);
    if (plan.action == DEETTY_GRID_WORKSPACE_EVENT_CREATE_TAB ||
        plan.action == DEETTY_GRID_WORKSPACE_EVENT_SPLIT) {
        DeettyGridContext *created = NULL;
        if (context->peer != NULL && !context->peer->active &&
            !context->peer->exited && context->peer->area != NULL &&
            context->peer->page != NULL && context->peer->userdata != NULL) {
            if (context->event != NULL)
                context->event(
                    context->event_data, context->pane_id, event_code, 0,
                    (uint64_t)(g_get_monotonic_time() / 1000));
            created = context->peer;
        } else {
            created = create_grid_context(context, event_code);
        }
        if (created == NULL) return;
        gboolean presented =
            plan.action == DEETTY_GRID_WORKSPACE_EVENT_CREATE_TAB
                ? add_grid_tab(context, created)
                : split_grid_context(context, created, event_code);
        if (!presented) return;
        if (plan.bind_layout != 0)
            (void)bind_grid_layout_for_page(created);
        start_grid_context(created);
        apply_smart_filter(root_grid_context(created));
        if (deetty_grid_widget_get_visible(created->area))
            defer_grid_context_focus(created);
        return;
    }
    if (plan.action == DEETTY_GRID_WORKSPACE_EVENT_LAYOUT_PRESET) {
        if (plan.restore_missing == 0)
            (void)apply_grid_layout_preset(context, event_code, FALSE);
        else
            (void)open_grid_layout_preset_tab(context, event_code);
        return;
    }
    if (plan.action == DEETTY_GRID_WORKSPACE_EVENT_MOVE) {
        DeettyGridContext *target = grid_context_on_other_page(context);
        if (target == NULL) return;
        if (context->event != NULL)
            context->event(
                context->event_data, context->pane_id, event_code, 0,
                (uint64_t)(g_get_monotonic_time() / 1000));
        (void)move_grid_context(context, target);
        return;
    }
    if (context->event != NULL)
        context->event(
            context->event_data, context->pane_id, event_code, 0,
            (uint64_t)(g_get_monotonic_time() / 1000));
}

static void deactivate_grid_context(DeettyGridContext *context) {
    if (context == NULL || !context->focused) return;
    context->focused = 0;
    context->cursor_visible = 0;
    context->selection_dragging = 0;
    context->suppress_primary_release = 0;
    if (context->im_context != NULL)
        deetty_grid_im_context_focus_out(context->im_context);
    if (grid_context_session_available(context))
        (void)context->focus(context->userdata, 0);
    if (context->area != NULL) deetty_grid_widget_queue_draw(context->area);
}

static void activate_grid_context(DeettyGridContext *context) {
    if (!grid_context_session_available(context) || context->exited) return;
    DeettyGridContext *root = root_grid_context(context);
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        DeettyGridContext *candidate =
            g_ptr_array_index(root->contexts, index);
        if (candidate != context) deactivate_grid_context(candidate);
    }
    gboolean changed = !context->focused;
    gboolean acknowledged_attention = context->attention ||
        context->status_kind == 4;
    DeettyGridNativeHostPolicy policy = {0};
    deetty_grid_native_host_policy(&policy);
    context->focused = 1;
    root->active_pane_id_for_render = context->pane_id;
    context->cursor_visible = 1;
    context->attention = 0;
    if (acknowledged_attention) {
        context->status_kind = 0;
        update_status_tooltip(context, "idle");
        if (context->event != NULL)
            context->event(context->event_data, context->pane_id,
                           policy.event_status_acknowledged, 0,
                           (uint64_t)(g_get_monotonic_time() / 1000));
    }
    if (changed) {
        if (context->im_context != NULL)
            deetty_grid_im_context_focus_in(context->im_context);
        (void)context->focus(context->userdata, 1);
        record_dogfood_omp_action(
            context, "omp_focus", &context->dogfood_omp_focus_seen);
        if (context->event != NULL)
            context->event(context->event_data, context->pane_id, DEETTY_GRID_HOST_EVENT(PANE_FOCUS), 0,
                           (uint64_t)(g_get_monotonic_time() / 1000));
    }
    deetty_grid_widget_queue_draw(context->area);
    update_compact_tab(context);
    refresh_active_pane_info(context);
}

static gboolean on_focus_in(GtkWidget *widget, GdkEventFocus *event,
                            gpointer user_data) {
    (void)widget;
    (void)event;
    activate_grid_context(user_data);
    return FALSE;
}

static gboolean on_focus_out(GtkWidget *widget, GdkEventFocus *event, gpointer user_data) {
    DeettyGridContext *context = user_data;
    (void)widget;
    (void)event;
    deactivate_grid_context(context);
    return FALSE;
}

static void open_command_palette(DeettyGridContext *context);
static void open_terminal_find(DeettyGridContext *context);
static void open_quick_note(DeettyGridContext *context);
static void open_shortcuts_overlay(DeettyGridContext *context);
static void save_grid_scrollback(DeettyGridContext *context);
static void on_smart_filter_button_clicked(GtkButton *button, gpointer user_data);
static void on_tag_selected_menu_activate(GtkMenuItem *item, gpointer user_data);
static void on_tag_remove_menu_activate(GtkMenuItem *item, gpointer user_data);

static gboolean on_key_press(GtkWidget *widget, GdkEventKey *event, gpointer user_data) {
    DeettyGridContext *context = user_data;
    if (!grid_context_session_available(context) || context->exited)
        return FALSE;
    DeettyGridContext *root = root_grid_context(context);
#if DEETTY_ENABLE_SMOKE
    if (root->workspace_smoke == 36 && root->presentation_armed &&
        !root->presentation_pending &&
        root->presentation_samples_started <
            DEETTY_PRESENTATION_QUALIFICATION_SAMPLES) {
        guint index = root->presentation_samples_started++;
        root->presentation_armed = 0;
        root->presentation_pending = 1;
        root->presentation_key_start_us[index] = g_get_monotonic_time();
        root->presentation_expected_output_serial =
            root->presentation_output_serial + 1;
    }
#endif
    char bytes[8];
    size_t length = 0;
    (void)widget;
    uint32_t modifier_flags = deetty_grid_input_modifiers(event->state);
    gboolean smart_filter_clear_available =
        event->keyval == GDK_KEY_Escape &&
        root->smart_filter_tag != NULL &&
        root->smart_filter_empty_box != NULL &&
        deetty_grid_widget_get_visible(root->smart_filter_empty_box);
    DeettyGridKeyCommandPlan key_plan;
    deetty_grid_key_command_plan(
        TRUE, deetty_grid_is_alt_key(event->keyval), smart_filter_clear_available,
        event->keyval, modifier_flags, &key_plan);
    switch (key_plan.action) {
        case DEETTY_GRID_KEY_ACTION_SHOW_NOTE_OVERLAYS:
            (void)show_quick_note_overlays(root);
            return TRUE;
        case DEETTY_GRID_KEY_ACTION_CLEAR_SMART_FILTER:
            return clear_smart_filter(root);
        case DEETTY_GRID_KEY_ACTION_CYCLE_TAB: {
            gboolean cycled = cycle_grid_tab(context, key_plan.direction);
            return key_plan.consume_without_effect ? TRUE : cycled;
        }
        case DEETTY_GRID_KEY_ACTION_CYCLE_PANE:
            return cycle_grid_pane(context, key_plan.direction);
        case DEETTY_GRID_KEY_ACTION_FOCUS_DIRECTION:
            if (focus_grid_direction(context, key_plan.dx, key_plan.dy))
                return TRUE;
            break;
        default:
            break;
    }
    DeettyGridKeyChordPlan chord_plan = {0};
    deetty_grid_key_chord_plan(
        event->keyval, event->state, &chord_plan);
    switch (chord_plan.action) {
        case DEETTY_GRID_CHORD_COMMAND_PALETTE:
            open_command_palette(context);
            return TRUE;
        case DEETTY_GRID_CHORD_TERMINAL_FIND:
            open_terminal_find(context);
            return TRUE;
        case DEETTY_GRID_CHORD_QUICK_NOTE:
            open_quick_note(context);
            return TRUE;
        case DEETTY_GRID_CHORD_SMART_FILTER:
            on_smart_filter_button_clicked(NULL, context);
            return TRUE;
        case DEETTY_GRID_CHORD_TAG_SELECTED:
            on_tag_selected_menu_activate(NULL, context);
            return TRUE;
        case DEETTY_GRID_CHORD_ZOOM:
            toggle_grid_zoom(context);
            return TRUE;
        case DEETTY_GRID_CHORD_FONT_ZOOM:
            (void)apply_pane_font_size(
                context,
                context->requested_font_size + chord_plan.value,
                TRUE);
            return TRUE;
        case DEETTY_GRID_CHORD_SHORTCUTS:
            open_shortcuts_overlay(context);
            return TRUE;
        case DEETTY_GRID_CHORD_CLOSE_TAB: {
            gint page_index = deetty_grid_notebook_get_current_page(
                GTK_NOTEBOOK(root->notebook));
            GtkWidget *page = deetty_grid_notebook_get_nth_page(
                GTK_NOTEBOOK(root->notebook), page_index);
            root->tab_shortcut_close = close_grid_tab(root, page);
            return TRUE;
        }
        case DEETTY_GRID_CHORD_RENAME_TAB: {
            gint page_index = deetty_grid_notebook_get_current_page(
                GTK_NOTEBOOK(root->notebook));
            GtkWidget *page = deetty_grid_notebook_get_nth_page(
                GTK_NOTEBOOK(root->notebook), page_index);
            open_tab_rename(root, page);
            return TRUE;
        }
        case DEETTY_GRID_CHORD_EMIT_EVENT:
            if (context->event != NULL)
                context->event(
                    context->event_data, context->pane_id,
                    chord_plan.value, 0,
                    (uint64_t)(g_get_monotonic_time() / 1000));
            if (chord_plan.reopen_tab != 0)
                root->tab_shortcut_reopen = 1;
            if (chord_plan.queue_draw != 0)
                deetty_grid_widget_queue_draw(context->area);
            return TRUE;
        case DEETTY_GRID_CHORD_BROADCAST:
            on_broadcast_menu_activate(NULL, context);
            return TRUE;
        case DEETTY_GRID_CHORD_TAB_COLOR:
            return adjust_active_tab_color(context, chord_plan.value);
        case DEETTY_GRID_CHORD_PASTE:
            request_grid_clipboard_text(context);
            return TRUE;
        case DEETTY_GRID_CHORD_COPY:
            copy_grid_selection_to_clipboard(context);
            return TRUE;
        case DEETTY_GRID_CHORD_SCROLL_KEYBOARD:
            return scroll_terminal_from_keyboard(
                context, (guint)chord_plan.value);
        case DEETTY_GRID_CHORD_CTRL_D:
            root->ctrl_d_close_attempted = 1;
            if (close_grid_pane(context)) root->ctrl_d_close_succeeded = 1;
            return TRUE;
        case DEETTY_GRID_CHORD_CTRL_C:
            acknowledge_grid_attention(context);
            if (context->write(context->userdata, "\x03", 1) == 1) {
                schedule_grid_write_flush(context);
                root->ctrl_c_local_interrupt = 1;
            } else {
                show_status_feedback(
                    context,
                    deetty_grid_status_feedback_message(
                        DEETTY_GRID_FEEDBACK_INTERRUPT));
            }
            return TRUE;
        default:
            break;
    }
    if (context->im_context != NULL &&
        deetty_grid_im_context_filter_keypress(context->im_context, event)) return TRUE;
    gunichar unicode = deetty_grid_gdk_keyval_to_unicode(event->keyval);
    uint32_t modifiers = 0;
    if ((event->state & GDK_CONTROL_MASK) != 0)
        modifiers |= DEETTY_GRID_MODIFIER_CONTROL;
    if ((event->state & GDK_MOD1_MASK) != 0)
        modifiers |= DEETTY_GRID_MODIFIER_ALT;
    int encoded = deetty_grid_terminal_key_sequence(
        event->keyval, unicode, modifiers,
        context->cursor_mode(context->userdata),
        (uint8_t *)bytes, sizeof(bytes));
    if (encoded <= 0) return FALSE;
    length = (size_t)encoded;
    if (deliver_grid_input(context, bytes, length) < 0)
        show_status_feedback(
            context,
            deetty_grid_status_feedback_message(
                DEETTY_GRID_FEEDBACK_DELIVER_INPUT));
    return TRUE;
}

static gboolean on_key_release(GtkWidget *widget, GdkEventKey *event,
                               gpointer user_data) {
    (void)widget;
    DeettyGridContext *context = user_data;
    if (!grid_context_session_available(context) || context->exited)
        return FALSE;
    DeettyGridContext *root = root_grid_context(context);
    DeettyGridKeyCommandPlan key_plan;
    deetty_grid_key_command_plan(
        FALSE, deetty_grid_is_alt_key(event->keyval), FALSE, event->keyval, 0, &key_plan);
    if (key_plan.action != DEETTY_GRID_KEY_ACTION_HIDE_NOTE_OVERLAYS)
        return FALSE;
    root->note_overlay_alt_released = 1;
    hide_quick_note_overlays(root);
    return TRUE;
}

static void show_workspace_menu(DeettyGridContext *context, GdkEventButton *event);

static void clear_grid_selection(DeettyGridContext *context) {
    context->selecting = 0;
    context->selection_dragging = 0;
    context->selection_start_column = 0;
    context->selection_start_row = 0;
    context->selection_end_column = 0;
    context->selection_end_row = 0;
    if (context->area != NULL) deetty_grid_widget_queue_draw(context->area);
}

static int grid_column_at_pointer(DeettyGridContext *context, double x) {
    int column = 0;
    int row = 0;
    DeettyGridFontMetrics metrics = grid_font_metrics(context);
    (void)deetty_grid_pointer_cell(
        x, 2.0, metrics.cell_width, metrics.cell_height,
        context->columns, context->rows, 1, &column, &row);
    return column;
}

static int grid_row_at_pointer(DeettyGridContext *context, double y) {
    int column = 0;
    int row = 0;
    DeettyGridFontMetrics metrics = grid_font_metrics(context);
    (void)deetty_grid_pointer_cell(
        4.0, y, metrics.cell_width, metrics.cell_height,
        context->columns, context->rows, 1, &column, &row);
    return row;
}

static gboolean grid_cell_at_point(DeettyGridContext *context,
                                   double x, double y,
                                   int *column, int *row) {
    DeettyGridFontMetrics metrics = grid_font_metrics(context);
    return deetty_grid_pointer_cell(
        x, y, metrics.cell_width, metrics.cell_height,
        context->columns, context->rows, 0, column, row) != 0;
}

static gboolean grid_cell_is_background(DeettyGridContext *context,
                                        int column, int row) {
    char text[64] = {0};
    int length = context->cell_text(
        context->userdata, column, row, text, sizeof(text));
    return deetty_grid_cell_is_background(
        (const uint8_t *)text, length) != 0;
}

static gboolean select_grid_word(DeettyGridContext *context,
                                 int column, int row) {
    DeettyGridSelectionWordPlan plan = {0};
    deetty_grid_selection_word_plan(
        context->userdata, column, row, context->columns,
        context->cell_text, &plan);
    if (!plan.valid) return FALSE;
    context->selecting = 1;
    context->selection_dragging = 0;
    context->selection_start_column = plan.start_column;
    context->selection_start_row = row;
    context->selection_end_column = plan.end_column;
    context->selection_end_row = row;
    deetty_grid_widget_queue_draw(context->area);
    return TRUE;
}
static int read_grid_hyperlink(DeettyGridContext *context,
                               int column, int row,
                               char uri[2049]) {
    return deetty_grid_read_hyperlink(
        context->userdata, column, row, uri, 2049, context->cell_hyperlink);
}

static void popup_menu_at_toplevel_pointer(
    DeettyGridContext *context, GtkWidget *menu, GtkWidget *anchor,
    GdkEventButton *event);


static gboolean open_grid_uri(DeettyGridContext *context,
                              const char *uri, guint32 time) {
    DeettyGridContext *root = root_grid_context(context);
    if (root->workspace_smoke == 15) {
        root->compact_hyperlink_open_attempted = 1;
        return TRUE;
    }
    GError *error = NULL;
    gboolean opened = deetty_grid_show_uri_on_window(
        GTK_WINDOW(context->window), uri, time, &error);
    if (!opened)
        show_status_feedback(
            context,
            deetty_grid_status_feedback_message(
                DEETTY_GRID_FEEDBACK_OPEN_BROWSER));
    if (error != NULL) g_error_free(error);
    return TRUE;
}

static gboolean open_grid_hyperlink(DeettyGridContext *context,
                                    int column, int row, guint32 time) {
    char uri[2049];
    int length = read_grid_hyperlink(context, column, row, uri);
    if (length == 0) return FALSE;
    if (length < 0) {
        show_status_feedback(
            context,
            deetty_grid_status_feedback_message(
                DEETTY_GRID_FEEDBACK_LINK_TYPE));
        return TRUE;
    }
    return open_grid_uri(context, uri, time);
}

typedef struct {
    DeettyGridContext *context;
    gchar *uri;
    guint32 time;
} DeettyHyperlinkMenu;

static void on_hyperlink_menu_open(GtkMenuItem *item, gpointer user_data) {
    (void)item;
    DeettyHyperlinkMenu *menu = user_data;
    (void)open_grid_uri(menu->context, menu->uri, menu->time);
}

static void on_hyperlink_menu_copy(GtkMenuItem *item, gpointer user_data) {
    (void)item;
    DeettyHyperlinkMenu *menu = user_data;
    deetty_grid_clipboard_set_text(
        deetty_grid_clipboard_get(GDK_SELECTION_CLIPBOARD), menu->uri, -1);
    show_status_feedback(
        menu->context,
        deetty_grid_status_feedback_message(
            DEETTY_GRID_FEEDBACK_LINK_COPIED));
}

static void destroy_hyperlink_menu_data(gpointer user_data) {
    DeettyHyperlinkMenu *menu = user_data;
    deetty_grid_memory_free(menu->uri);
    deetty_grid_memory_free(menu);
}

static void on_hyperlink_menu_destroy(GtkWidget *menu,
                                      gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    if (root->workspace_menu == menu) root->workspace_menu = NULL;
}

static gboolean show_hyperlink_menu(
    DeettyGridContext *context, GdkEventButton *event,
    int column, int row) {
    char uri[2049];
    if (read_grid_hyperlink(context, column, row, uri) <= 0) return FALSE;
    DeettyGridContext *root = root_grid_context(context);
    dismiss_grid_popup_windows(root);
    DeettyHyperlinkMenuContents contents = {0};
    if (!deetty_hyperlink_menu_new(&contents))
        return FALSE;
    GtkWidget *menu = contents.menu;
    GtkWidget *open = contents.open;
    GtkWidget *copy = contents.copy;
    DeettyHyperlinkMenu *data = g_new0(DeettyHyperlinkMenu, 1);
    data->context = context;
    data->uri = g_strdup(uri);
    data->time = event->time;
    deetty_grid_object_set_data_full(
        menu, "deetty-hyperlink-menu", data,
        destroy_hyperlink_menu_data);
    deetty_grid_signal_connect(open, "activate", G_CALLBACK(on_hyperlink_menu_open), data);
    deetty_grid_signal_connect(copy, "activate", G_CALLBACK(on_hyperlink_menu_copy), data);
    deetty_grid_signal_connect_swapped(
        open, "activate", G_CALLBACK(deetty_grid_widget_destroy), menu);
    deetty_grid_signal_connect_swapped(
        copy, "activate", G_CALLBACK(deetty_grid_widget_destroy), menu);
    deetty_grid_signal_connect_swapped(
        menu, "selection-done", G_CALLBACK(deetty_grid_widget_destroy), menu);
    deetty_grid_signal_connect(menu, "destroy",
                     G_CALLBACK(on_hyperlink_menu_destroy), root);
    root->workspace_menu = menu;
    deetty_grid_widget_show_all(menu);
    if (root->workspace_smoke == 15) {
        root->compact_hyperlink_context_menu =
            g_strcmp0(deetty_grid_menu_item_get_label(GTK_MENU_ITEM(open)),
                      "Open Link in Browser") == 0 &&
            g_strcmp0(deetty_grid_menu_item_get_label(GTK_MENU_ITEM(copy)),
                      "Copy Link") == 0;
        deetty_grid_menu_item_activate(GTK_MENU_ITEM(open));
        root->compact_hyperlink_context_open =
            root->compact_hyperlink_open_attempted;
        return TRUE;
    }
    popup_menu_at_toplevel_pointer(context, menu, context->area, event);
    return TRUE;
}


static gboolean handle_terminal_scrollbar_button(
    DeettyGridContext *context, GtkWidget *widget, GdkEventButton *event,
    const DeettyTerminalScrollbarGeometry *geometry) {
    if (event->type == GDK_BUTTON_RELEASE) {
        context->scrollbar_dragging = 0;
        deetty_grid_widget_queue_draw(context->area);
        return TRUE;
    }
    if (event->type != GDK_BUTTON_PRESS) return TRUE;

    if (!deetty_grid_widget_has_focus(widget)) deetty_grid_focus_widget(NULL, widget);
    activate_grid_context(context);
    DeettyTerminalScrollbarPressPlan plan = {0};
    deetty_grid_scrollbar_press_plan(geometry, event->y, &plan);
    if (plan.action == DEETTY_GRID_SCROLLBAR_PRESS_DRAG) {
        context->scrollbar_dragging = 1;
        context->scrollbar_drag_offset = plan.drag_offset;
        deetty_grid_widget_queue_draw(context->area);
        return TRUE;
    }
    if (plan.action == DEETTY_GRID_SCROLLBAR_PRESS_PAGE &&
        scroll_terminal_to_offset(context, plan.target_offset))
        root_grid_context(context)->compact_scrollbar_track_scrolled = 1;
    return TRUE;
}

static gboolean on_mouse_button(GtkWidget *widget, GdkEventButton *event, gpointer user_data) {
    DeettyGridContext *context = user_data;
    if (!grid_context_session_available(context) || context->exited)
        return FALSE;
    GtkAllocation allocation;
    deetty_grid_widget_get_allocation(widget, &allocation);
    DeettyTerminalScrollbarGeometry scrollbar;
    gboolean scrollbar_owned =
        terminal_scrollbar_geometry(context, allocation, &scrollbar) &&
        event->button == 1 &&
        (event->x >= scrollbar.x || context->scrollbar_dragging);
    int terminal_mode_flags =
        scrollbar_owned ? 0 : context->mouse_mode(context->userdata);
    int terminal_mouse_mode =
        terminal_mode_flags & DEETTY_GRID_TERMINAL_MODE_MOUSE;
    int route = deetty_grid_input_route(
        DEETTY_GRID_INPUT_POINTER, scrollbar_owned, terminal_mode_flags, 0,
        event->button == 1, deetty_grid_input_modifiers(event->state));
    if (route == DEETTY_GRID_ROUTE_SCROLLBAR)
        return handle_terminal_scrollbar_button(
            context, widget, event, &scrollbar);
    int column = grid_column_at_pointer(context, event->x);
    int row = grid_row_at_pointer(context, event->y);
    int hyperlink_column = 0;
    int hyperlink_row = 0;
    gboolean hyperlink_point = grid_cell_at_point(
        context, event->x, event->y, &hyperlink_column, &hyperlink_row);
    int button = event->button >= 1 && event->button <= 3
        ? (int)event->button - 1 : 0;
    int event_kind = event->type == GDK_BUTTON_PRESS
        ? DEETTY_GRID_POINTER_EVENT_PRESS
        : event->type == GDK_BUTTON_RELEASE
            ? DEETTY_GRID_POINTER_EVENT_RELEASE
            : event->type == GDK_2BUTTON_PRESS
                ? DEETTY_GRID_POINTER_EVENT_DOUBLE_PRESS : 0;
    int pressed = event_kind == DEETTY_GRID_POINTER_EVENT_PRESS;
    if (event_kind == DEETTY_GRID_POINTER_EVENT_PRESS &&
        event->button == 1) {
        context->preserve_double_click_selection = 0;
        context->suppress_primary_release = 0;
    }
    gboolean background = FALSE;
    gboolean multiple_panes = FALSE;
    if (event_kind == DEETTY_GRID_POINTER_EVENT_DOUBLE_PRESS &&
        event->button == 1) {
        background = grid_cell_is_background(context, column, row);
        multiple_panes =
            grid_contexts_on_page(root_grid_context(context), context->page) > 1;
    }
    DeettyGridPointerEventPlan pointer_plan = {0};
    deetty_grid_pointer_event_plan(
        event_kind, (int)event->button, route, hyperlink_point,
        (event->state & GDK_CONTROL_MASK) != 0,
        background, multiple_panes,
        context->suppress_primary_release,
        context->preserve_double_click_selection,
        &pointer_plan);
    switch (pointer_plan.action) {
        case DEETTY_GRID_POINTER_ACTION_ZOOM:
            clear_grid_selection(context);
            context->suppress_primary_release = 1;
            toggle_grid_zoom(context);
            return TRUE;
        case DEETTY_GRID_POINTER_ACTION_SELECT_WORD:
            if (select_grid_word(context, column, row)) {
                context->preserve_double_click_selection = 1;
                context->suppress_primary_release = 1;
                return TRUE;
            }
            clear_grid_selection(context);
            context->suppress_primary_release = 1;
            return TRUE;
        case DEETTY_GRID_POINTER_ACTION_CLEAR_SELECTION:
            clear_grid_selection(context);
            context->suppress_primary_release = 1;
            return TRUE;
        case DEETTY_GRID_POINTER_ACTION_OPEN_HYPERLINK:
            if (open_grid_hyperlink(
                    context, hyperlink_column, hyperlink_row, event->time)) {
                clear_grid_selection(context);
                context->suppress_primary_release = 1;
                if (terminal_mouse_mode && context->workspace_smoke == 15)
                    root_grid_context(context)->compact_hyperlink_mouse_mode_override = 1;
                return TRUE;
            }
            break;
        case DEETTY_GRID_POINTER_ACTION_CONSUME: {
            const int preserve_selection =
                context->preserve_double_click_selection;
            context->preserve_double_click_selection = 0;
            context->suppress_primary_release = 0;
            if (!preserve_selection) clear_grid_selection(context);
            return TRUE;
        }
        default:
            break;
    }
    if (pressed) {
        if (!deetty_grid_widget_has_focus(widget))
            deetty_grid_focus_widget(NULL, widget);
        activate_grid_context(context);
    }
    switch (pointer_plan.action) {
        case DEETTY_GRID_POINTER_ACTION_SHOW_HYPERLINK_MENU:
            if (show_hyperlink_menu(
                    context, event, hyperlink_column, hyperlink_row))
                return TRUE;
            show_workspace_menu(context, event);
            return TRUE;
        case DEETTY_GRID_POINTER_ACTION_SHOW_WORKSPACE_MENU:
            show_workspace_menu(context, event);
            return TRUE;
        case DEETTY_GRID_POINTER_ACTION_BEGIN_SELECTION:
            context->selecting = 0;
            context->selection_dragging = 1;
            context->selection_start_column = column;
            context->selection_start_row = row;
            context->selection_end_column = column;
            context->selection_end_row = row;
            deetty_grid_widget_queue_draw(context->area);
            return TRUE;
        case DEETTY_GRID_POINTER_ACTION_UPDATE_SELECTION:
            context->selection_end_column = column;
            context->selection_end_row = row;
            context->selection_dragging = 0;
            context->selecting =
                context->selection_start_column != context->selection_end_column ||
                context->selection_start_row != context->selection_end_row;
            deetty_grid_widget_queue_draw(context->area);
            return TRUE;
        case DEETTY_GRID_POINTER_ACTION_DELIVER_MOUSE:
            acknowledge_grid_attention(context);
            {
                int delivered = context->mouse(
                    context->userdata, column, row, button, pressed);
                if (delivered <= 0) {
                    show_status_feedback(
                        context,
                        deetty_grid_status_feedback_message(
                            DEETTY_GRID_FEEDBACK_POINTER_INPUT));
                } else {
                    schedule_grid_write_flush(context);
                }
            }
            return TRUE;
        case DEETTY_GRID_POINTER_ACTION_CONSUME:
        case DEETTY_GRID_POINTER_ACTION_NONE:
        default:
            return TRUE;
    }
}

static gboolean on_mouse_motion(GtkWidget *widget, GdkEventMotion *event,
                                gpointer user_data);

static DeettyGridContext *focus_click_smoke_target(
    DeettyGridContext *root, gboolean primary) {
    if (root->contexts == NULL || root->contexts->len < 2) return NULL;
    guint index = primary ? 0 : root->contexts->len - 1;
    DeettyGridContext *target = g_ptr_array_index(root->contexts, index);
    return grid_context_session_available(target) ? target : NULL;
}

static gboolean focus_click_smoke_surface_ready(
    DeettyGridContext *root, DeettyGridContext *target) {
    if (root->window == NULL || target == NULL || target->area == NULL ||
        !root->window_presented || !deetty_grid_widget_get_mapped(root->window) ||
        !deetty_grid_widget_get_mapped(target->area))
        return FALSE;
    if (!root->layer_shell_active &&
        !deetty_grid_window_is_active(GTK_WINDOW(root->window)))
        deetty_grid_window_present(root->window);
    return TRUE;
}

static void emit_focus_click_smoke(DeettyGridContext *target) {
    GdkEventButton event = {0};
    event.type = GDK_BUTTON_PRESS;
    event.button = 1;
    event.x = 4;
    event.y = 4;
    (void)on_mouse_button(target->area, &event, target);
    event.type = GDK_BUTTON_RELEASE;
    (void)on_mouse_button(target->area, &event, target);
    GdkEventMotion motion = {0};
    motion.type = GDK_MOTION_NOTIFY;
    motion.x = 90;
    motion.y = 36;
    motion.state = 0;
    (void)on_mouse_motion(target->area, &motion, target);
}

static gboolean inspect_focus_click_smoke(DeettyGridContext *root,
                                          DeettyGridContext *target,
                                          const char *command,
                                          int *verified) {
    if (deetty_grid_window_get_focus(GTK_WINDOW(root->window)) != target->area ||
        !target->focused)
        return FALSE;
    *verified = !target->selection_dragging && !target->selecting &&
        target->write(target->userdata, command, strlen(command)) >= 0;
    return TRUE;
}

static gboolean drive_focus_click_smoke(gpointer user_data);

static gboolean wait_for_focus_click_smoke(DeettyGridContext *root) {
    if (root->focus_click_smoke_attempts++ < 80) {
        deetty_grid_source_timeout_add(25, drive_focus_click_smoke, root);
        return G_SOURCE_REMOVE;
    }
    g_printerr("native_grid_click_focus_timeout stage=%d mapped=%d active=%d contexts=%u\n",
               root->focus_click_smoke_stage,
               root->window != NULL && deetty_grid_widget_get_mapped(root->window),
               root->window != NULL && deetty_grid_window_is_active(GTK_WINDOW(root->window)),
               root->contexts != NULL ? root->contexts->len : 0);
    root->focus_click_smoke_attempts = 0;
    root->focus_click_smoke_stage = DEETTY_FOCUS_SMOKE_RELEASE;
    deetty_grid_source_idle_add(drive_focus_click_smoke, root);
    return G_SOURCE_REMOVE;
}

static void emit_zoom_double_click(DeettyGridContext *target,
                                   double release_x, double release_y) {
    GdkEventButton event = {0};
    event.button = 1;
    event.x = 4;
    event.y = 4;
    event.type = GDK_BUTTON_PRESS;
    (void)on_mouse_button(target->area, &event, target);
    event.type = GDK_BUTTON_RELEASE;
    (void)on_mouse_button(target->area, &event, target);
    event.x = release_x;
    event.y = release_y;
    event.type = GDK_2BUTTON_PRESS;
    (void)on_mouse_button(target->area, &event, target);
    event.type = GDK_BUTTON_RELEASE;
    (void)on_mouse_button(target->area, &event, target);
}

static void run_zoom_selection_smoke(DeettyGridContext *root) {
    DeettyGridContext *target = g_ptr_array_index(root->contexts,
                                                  root->contexts->len - 1);
    clear_grid_selection(target);
    GtkWidget *split = deetty_grid_widget_get_parent(target->area);
    int original_split_position = deetty_grid_widget_is_type(split, DEETTY_GTK_PANED)
        ? deetty_grid_paned_get_position(GTK_PANED(split)) : -1;
    emit_zoom_double_click(target, 900, 300);
    root->focus_double_click_zoom_clean =
        root->zoomed_pane_id == target->pane_id &&
        !target->selection_dragging && !target->selecting &&
        !target->suppress_primary_release;
    emit_zoom_double_click(target, 850, 280);
    root->focus_double_click_restore_clean =
        root->zoomed_pane_id == 0 &&
        !target->selection_dragging && !target->selecting &&
        !target->suppress_primary_release &&
        (!deetty_grid_widget_is_type(split, DEETTY_GTK_PANED) ||
         deetty_grid_paned_get_position(GTK_PANED(split)) == original_split_position);
    int word_column = -1;
    int word_row = -1;
    for (int row = 0; row < target->rows && word_row < 0; row++) {
        for (int column = 0; column < target->columns; column++) {
            if (!grid_cell_is_background(target, column, row)) {
                word_column = column;
                word_row = row;
                break;
            }
        }
    }
    if (word_row >= 0) {
        DeettyGridFontMetrics metrics = grid_font_metrics(target);
        emit_zoom_double_click(
            target,
            4.0 + (word_column + 0.5) * metrics.cell_width,
            2.0 + (word_row + 0.5) * metrics.cell_height);
        root->focus_double_click_word_selection =
            target->selecting && !target->selection_dragging &&
            !target->suppress_primary_release;
        clear_grid_selection(target);
    }
    GdkEventButton button = {0};
    button.type = GDK_BUTTON_PRESS;
    button.button = 1;
    button.x = 4;
    button.y = 4;
    (void)on_mouse_button(target->area, &button, target);
    GdkEventMotion motion = {0};
    motion.type = GDK_MOTION_NOTIFY;
    motion.state = GDK_BUTTON1_MASK;
    motion.x = 45;
    motion.y = 36;
    (void)on_mouse_motion(target->area, &motion, target);
    button.type = GDK_BUTTON_RELEASE;
    button.x = motion.x;
    button.y = motion.y;
    (void)on_mouse_button(target->area, &button, target);
    root->focus_drag_selection_preserved =
        target->selecting && !target->selection_dragging;
    clear_grid_selection(target);
}

static gboolean drive_focus_click_smoke(gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    gboolean primary =
        root->focus_click_smoke_stage <= DEETTY_FOCUS_SMOKE_PRIMARY_CHECK;
    DeettyGridContext *target = focus_click_smoke_target(root, primary);

    if (root->focus_click_smoke_stage == DEETTY_FOCUS_SMOKE_RELEASE) {
        guint expected = 0;
        guint released = 0;
        for (guint index = 0; root->contexts != NULL &&
             index < root->contexts->len; index++) {
            DeettyGridContext *candidate =
                g_ptr_array_index(root->contexts, index);
            if (!grid_context_session_available(candidate) || candidate->exited)
                continue;
            expected++;
            if (candidate->write(candidate->userdata, "exit 0\n", 7) >= 0)
                released++;
        }
        root->focus_click_controlled_exit = expected == 2 && released == expected;
        return G_SOURCE_REMOVE;
    }

    if (!focus_click_smoke_surface_ready(root, target))
        return wait_for_focus_click_smoke(root);

    if (root->focus_click_smoke_stage == DEETTY_FOCUS_SMOKE_PRIMARY_ACTION ||
        root->focus_click_smoke_stage == DEETTY_FOCUS_SMOKE_SECONDARY_ACTION) {
        emit_focus_click_smoke(target);
        root->focus_click_smoke_attempts = 0;
        root->focus_click_smoke_stage++;
        deetty_grid_source_timeout_add(25, drive_focus_click_smoke, root);
        return G_SOURCE_REMOVE;
    }

    if (root->focus_click_smoke_stage == DEETTY_FOCUS_SMOKE_PRIMARY_CHECK ||
        root->focus_click_smoke_stage == DEETTY_FOCUS_SMOKE_SECONDARY_CHECK) {
        const char *command = primary
            ? "printf 'DEETTY_FOCUS_PRIMARY'\n"
            : "printf 'DEETTY_FOCUS_SECONDARY'\n";
        int *verified = primary
            ? &root->focus_click_primary
            : &root->focus_click_secondary;
        if (!inspect_focus_click_smoke(root, target, command, verified))
            return wait_for_focus_click_smoke(root);
        root->focus_click_smoke_attempts = 0;
        root->focus_click_smoke_stage++;
        deetty_grid_source_timeout_add(50, drive_focus_click_smoke, root);
        return G_SOURCE_REMOVE;
    }

    run_zoom_selection_smoke(root);
    root->focus_click_smoke_attempts = 0;
    root->focus_click_smoke_stage = DEETTY_FOCUS_SMOKE_RELEASE;
    deetty_grid_source_timeout_add(50, drive_focus_click_smoke, root);
    return G_SOURCE_REMOVE;
}

static void restore_settings_parent_layer(DeettyGridContext *context);

static void on_settings_destroy(GtkWidget *widget, gpointer user_data) {
    (void)widget;
    DeettyGridContext *context = root_grid_context(user_data);
    context->settings_dialog = NULL;
    context->settings_categories = NULL;
    context->settings_stack = NULL;
    context->settings_pane_info_toggle = NULL;
    context->settings_launch_library = NULL;
    context->settings_launch_name = NULL;
    context->settings_launch_kind = NULL;
    context->settings_launch_shell = NULL;
    context->settings_launch_command = NULL;
    context->settings_launch_cwd = NULL;
    context->settings_launch_environment = NULL;
    context->settings_launch_ssh_target = NULL;
    context->settings_launch_scrollback = NULL;
    context->settings_launch_apply = NULL;
    context->settings_launch_save = NULL;
    context->settings_launch_delete = NULL;
    context->settings_launch_status = NULL;
}

typedef gboolean (*DeettyLayerIsSupported)(void);
typedef guint (*DeettyLayerGetProtocolVersion)(void);
typedef void (*DeettyLayerInitForWindow)(GtkWindow *);
typedef void (*DeettyLayerSetNamespace)(GtkWindow *, const char *);
typedef void (*DeettyLayerSetMonitor)(GtkWindow *, GdkMonitor *);
typedef void (*DeettyLayerSetInt)(GtkWindow *, int);
typedef int (*DeettyLayerGetInt)(GtkWindow *);
typedef gboolean (*DeettyLayerIsLayerWindow)(GtkWindow *);
typedef void (*DeettyLayerSetEdge)(GtkWindow *, int, gboolean);
typedef void (*DeettyLayerSetMargin)(GtkWindow *, int, int);

static gboolean apply_grid_layer_surface_size(
    DeettyGridContext *context, int width, int height) {
    DeettyGridContext *root = root_grid_context(context);
    if (root->window == NULL) return FALSE;
    deetty_grid_widget_set_size_request(root->window, width, height);
    if (!root->layer_shell_active || root->layer_shell_library == NULL ||
        width <= 0 || height <= 0)
        return FALSE;
    /* gtk-layer-shell documents gtk_window_resize(1, 1) as the portable
     * way to force a new size request onto an already-mapped layer surface. */
    deetty_grid_window_resize(root->window, 1, 1);
    return TRUE;
}

static void set_grid_layer_keyboard_active(DeettyGridContext *context,
                                           gboolean active) {
    DeettyGridContext *root = root_grid_context(context);
    if (!root->layer_shell_active || root->layer_shell_library == NULL ||
        root->window == NULL || deetty_grid_widget_in_destruction(root->window))
        return;
    DeettyLayerSetInt set_keyboard_mode =
        (DeettyLayerSetInt)dlsym(root->layer_shell_library,
                                 "gtk_layer_set_keyboard_mode");
    if (set_keyboard_mode == NULL) return;
    set_keyboard_mode(GTK_WINDOW(root->window),
                      active ? root->layer_shell_keyboard_mode : 0);
}

static GdkMonitor *grid_monitor_for_window(GtkWidget *window) {
    GdkDisplay *display = deetty_grid_widget_get_display(window);
    GdkWindow *gdk_window = deetty_grid_widget_get_window(window);
    GdkMonitor *window_monitor = gdk_window != NULL
        ? deetty_grid_gdk_monitor_at_window(display, gdk_window)
        : NULL;
    GdkMonitor *primary_monitor =
        deetty_grid_gdk_primary_monitor(display);
    GdkMonitor *pointer_monitor = NULL;
    if (window_monitor == NULL && primary_monitor == NULL) {
        gint x = 0;
        gint y = 0;
        if (deetty_grid_gdk_pointer_position(display, &x, &y))
            pointer_monitor = deetty_grid_gdk_monitor_at_point(display, x, y);
    }
    int monitor_count = deetty_grid_gdk_monitor_count(display);
    GdkMonitor *first_monitor = NULL;
    if (window_monitor == NULL && primary_monitor == NULL &&
        pointer_monitor == NULL && monitor_count > 0)
        first_monitor = deetty_grid_gdk_monitor_at_index(display, 0);
    DeettyGridMonitorSelectionPlan plan = {0};
    deetty_grid_monitor_selection_plan(
        window_monitor != NULL ? 1 : 0,
        primary_monitor != NULL ? 1 : 0,
        pointer_monitor != NULL ? 1 : 0,
        monitor_count, &plan);
    switch (plan.action) {
    case DEETTY_GRID_MONITOR_SELECTION_WINDOW:
        return window_monitor;
    case DEETTY_GRID_MONITOR_SELECTION_PRIMARY:
        return primary_monitor;
    case DEETTY_GRID_MONITOR_SELECTION_POINTER:
        return pointer_monitor;
    case DEETTY_GRID_MONITOR_SELECTION_FIRST:
        return first_monitor;
    default:
        return NULL;
    }
}

static gboolean grid_monitor_metrics(
    GtkWidget *window, GdkMonitor **monitor_output,
    GdkRectangle *geometry_output, GdkRectangle *workarea_output,
    int *scale_factor_output) {
    GdkMonitor *monitor = grid_monitor_for_window(window);
    if (monitor == NULL) return FALSE;
    if (monitor_output != NULL) *monitor_output = monitor;
    if (geometry_output != NULL)
        deetty_grid_gdk_monitor_get_geometry(monitor, geometry_output);
    if (workarea_output != NULL)
        deetty_grid_gdk_monitor_get_workarea(monitor, workarea_output);
    if (scale_factor_output != NULL)
        *scale_factor_output = deetty_grid_monitor_scale_factor(
            deetty_grid_gdk_monitor_get_scale_factor(monitor));
    return TRUE;
}

static void apply_grid_layer_geometry(DeettyGridContext *context) {
    DeettyGridContext *root = root_grid_context(context);
    if (!root->layer_shell_active || root->layer_shell_library == NULL) return;
    DeettyLayerSetNamespace set_namespace =
        (DeettyLayerSetNamespace)dlsym(root->layer_shell_library,
                                        "gtk_layer_set_namespace");
    DeettyLayerSetEdge set_anchor =
        (DeettyLayerSetEdge)dlsym(root->layer_shell_library,
                                  "gtk_layer_set_anchor");
    DeettyLayerSetMargin set_margin =
        (DeettyLayerSetMargin)dlsym(root->layer_shell_library,
                                    "gtk_layer_set_margin");
    if (set_namespace == NULL || set_anchor == NULL || set_margin == NULL) return;

    GdkMonitor *monitor = grid_monitor_for_window(root->window);
    GdkRectangle geometry = {0, 0, 900, 420};
    if (monitor != NULL) deetty_grid_gdk_monitor_get_geometry(monitor, &geometry);
    DeettyLayerSetMonitor set_monitor =
        (DeettyLayerSetMonitor)dlsym(root->layer_shell_library,
                                     "gtk_layer_set_monitor");
    if (set_monitor != NULL && monitor != NULL &&
        monitor != root->layer_shell_monitor) {
        set_monitor(GTK_WINDOW(root->window), monitor);
        root->layer_shell_monitor = monitor;
    }
    DeettyGridLayerGeometryPlan geometry_plan = {0};
    deetty_grid_layer_geometry_plan(
        root->mode, geometry.width, geometry.height,
        root->dropdown_width_px, root->dropdown_width_percent,
        root->dropdown_height_px, root->dropdown_height_percent,
        &geometry_plan);

    for (int edge = 0; edge < 4; edge++) {
        set_anchor(GTK_WINDOW(root->window), edge, FALSE);
        set_margin(GTK_WINDOW(root->window), edge, 0);
    }
    if (geometry_plan.action == DEETTY_GRID_LAYER_GEOMETRY_DROPDOWN) {
        set_namespace(GTK_WINDOW(root->window), "deetty-dropdown");
        set_anchor(GTK_WINDOW(root->window), 0, TRUE);
        set_anchor(GTK_WINDOW(root->window), 1, TRUE);
        set_anchor(GTK_WINDOW(root->window), 2, TRUE);
        set_anchor(GTK_WINDOW(root->window), 3, TRUE);
        set_margin(GTK_WINDOW(root->window), 0, geometry_plan.left);
        set_margin(GTK_WINDOW(root->window), 1, geometry_plan.right);
        set_margin(GTK_WINDOW(root->window), 3, geometry_plan.bottom);
        (void)apply_grid_layer_surface_size(
            root, geometry_plan.width, geometry_plan.height);
    } else if (geometry_plan.action == DEETTY_GRID_LAYER_GEOMETRY_ZEN) {
        set_namespace(GTK_WINDOW(root->window), "deetty-zen");
        for (int edge = 0; edge < 4; edge++)
            set_anchor(GTK_WINDOW(root->window), edge, TRUE);
        (void)apply_grid_layer_surface_size(
            root, geometry_plan.width, geometry_plan.height);
    } else if (geometry_plan.action == DEETTY_GRID_LAYER_GEOMETRY_WINDOW) {
        set_namespace(GTK_WINDOW(root->window), "deetty-window");
        (void)apply_grid_layer_surface_size(
            root, geometry_plan.width, geometry_plan.height);
    }
}

static int configure_grid_layer_shell(DeettyGridContext *context) {
    DeettyGridContext *root = root_grid_context(context);
    if (root->mode != 0 || !root->layer_shell_allowed ||
        !GDK_IS_WAYLAND_DISPLAY(deetty_grid_widget_get_display(root->window))) return 0;
    if (root->layer_shell_library == NULL)
        root->layer_shell_library = dlopen("libgtk-layer-shell.so.0",
                                           RTLD_NOW | RTLD_LOCAL);
    if (root->layer_shell_library == NULL) return 0;

    DeettyLayerIsSupported is_supported =
        (DeettyLayerIsSupported)dlsym(root->layer_shell_library,
                                      "gtk_layer_is_supported");
    DeettyLayerGetProtocolVersion get_protocol_version =
        (DeettyLayerGetProtocolVersion)dlsym(
            root->layer_shell_library, "gtk_layer_get_protocol_version");
    DeettyLayerInitForWindow init_for_window =
        (DeettyLayerInitForWindow)dlsym(root->layer_shell_library,
                                        "gtk_layer_init_for_window");
    DeettyLayerSetMonitor set_monitor =
        (DeettyLayerSetMonitor)dlsym(root->layer_shell_library,
                                     "gtk_layer_set_monitor");
    DeettyLayerSetInt set_layer =
        (DeettyLayerSetInt)dlsym(root->layer_shell_library,
                                 "gtk_layer_set_layer");
    DeettyLayerSetInt set_keyboard_mode =
        (DeettyLayerSetInt)dlsym(root->layer_shell_library,
                                 "gtk_layer_set_keyboard_mode");
    DeettyLayerSetInt set_exclusive_zone =
        (DeettyLayerSetInt)dlsym(root->layer_shell_library,
                                 "gtk_layer_set_exclusive_zone");
    if (is_supported == NULL || init_for_window == NULL ||
        set_monitor == NULL || set_layer == NULL ||
        set_keyboard_mode == NULL || set_exclusive_zone == NULL ||
        !is_supported()) {
        dlclose(root->layer_shell_library);
        root->layer_shell_library = NULL;
        return 0;
    }
    init_for_window(GTK_WINDOW(root->window));
    GdkMonitor *monitor = grid_monitor_for_window(root->window);
    if (monitor != NULL) {
        set_monitor(GTK_WINDOW(root->window), monitor);
        root->layer_shell_monitor = monitor;
    }
    // Keep the dropdown on TOP. Plasma composites alpha correctly there;
    // OVERLAY became translucent only while a modal temporarily lowered it.
    set_layer(GTK_WINDOW(root->window), 2);
    guint protocol_version = get_protocol_version != NULL
        ? get_protocol_version() : 0;
    root->layer_shell_keyboard_mode = protocol_version >= 4 ? 2 : 1;
    set_keyboard_mode(GTK_WINDOW(root->window),
                      root->layer_shell_keyboard_mode);
    set_exclusive_zone(GTK_WINDOW(root->window), 0);
    root->layer_shell_active = 1;
    apply_grid_layer_geometry(root);
    g_debug("DEETTY dropdown layer-shell active protocol=%u keyboard_mode=%s",
            protocol_version,
            root->layer_shell_keyboard_mode == 2 ? "on-demand" : "exclusive");
    return 1;
}

static void restore_settings_parent_layer(DeettyGridContext *context) {
    DeettyGridContext *root = root_grid_context(context);
    if (root->overlay_dialog_count != 0) return;
    if (!root->settings_parent_layer_lowered) return;
    root->settings_parent_layer_lowered = 0;
    if (!root->layer_shell_active || root->layer_shell_library == NULL ||
        root->window == NULL || deetty_grid_widget_in_destruction(root->window))
        return;
    DeettyLayerSetInt set_layer =
        (DeettyLayerSetInt)dlsym(root->layer_shell_library,
                                 "gtk_layer_set_layer");
    DeettyLayerGetInt get_layer =
        (DeettyLayerGetInt)dlsym(root->layer_shell_library,
                                 "gtk_layer_get_layer");
    if (set_layer == NULL || get_layer == NULL) return;
    set_layer(GTK_WINDOW(root->window), 2);
    root->settings_parent_layer_restored =
        get_layer(GTK_WINDOW(root->window)) == 2;
}

static void on_overlay_window_destroy(GtkWidget *widget,
                                      gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    if (deetty_grid_object_get_data(
            widget, "deetty-overlay-window") == NULL)
        return;
    deetty_grid_object_set_data(widget, "deetty-overlay-window", NULL);
    if (root->overlay_dialog_count > 0) root->overlay_dialog_count--;
    restore_settings_parent_layer(root);
}

static gboolean configure_overlay_window_stacking(
    DeettyGridContext *context, GtkWidget *dialog,
    const char *namespace_name) {
    DeettyGridContext *root = root_grid_context(context);
    if (!deetty_grid_widget_is_type(dialog, DEETTY_GTK_WINDOW) ||
        !deetty_grid_widget_is_type(root->window, DEETTY_GTK_WINDOW)) return FALSE;

    deetty_grid_window_set_transient_for(dialog, root->window);
    deetty_grid_window_set_destroy_with_parent(dialog, TRUE);
    deetty_grid_window_set_type_hint(dialog, GDK_WINDOW_TYPE_HINT_DIALOG);
    deetty_grid_window_set_keep_above(GTK_WIDGET(dialog), TRUE);
    root->settings_transient_parent =
        deetty_grid_window_get_transient_for(GTK_WINDOW(dialog)) ==
        GTK_WINDOW(root->window);
    root->settings_keep_above = 1;
    root->settings_layer_overlay = 0;
    root->settings_parent_layer_lowered =
        root->overlay_dialog_count > 0 ? 1 : 0;
    root->settings_parent_layer_restored = !root->layer_shell_active;

    DeettyGridOverlayStackingPlan stacking_plan = {0};
    deetty_grid_overlay_stacking_plan(
        root->layer_shell_active,
        root->layer_shell_library != NULL,
        deetty_grid_object_get_data(
            dialog, "deetty-overlay-window") != NULL,
        (int)root->overlay_dialog_count, &stacking_plan);
    if (stacking_plan.action == DEETTY_GRID_OVERLAY_STACKING_EXISTING) {
        root->settings_layer_overlay = 1;
        return TRUE;
    }
    if (stacking_plan.action == DEETTY_GRID_OVERLAY_STACKING_BASIC)
        return root->settings_transient_parent && root->settings_keep_above;
    if (stacking_plan.action != DEETTY_GRID_OVERLAY_STACKING_LAYER)
        return FALSE;

    DeettyLayerInitForWindow init_for_window =
        (DeettyLayerInitForWindow)dlsym(root->layer_shell_library,
                                        "gtk_layer_init_for_window");
    DeettyLayerIsLayerWindow is_layer_window =
        (DeettyLayerIsLayerWindow)dlsym(root->layer_shell_library,
                                        "gtk_layer_is_layer_window");
    DeettyLayerSetNamespace set_namespace =
        (DeettyLayerSetNamespace)dlsym(root->layer_shell_library,
                                        "gtk_layer_set_namespace");
    DeettyLayerSetInt set_layer =
        (DeettyLayerSetInt)dlsym(root->layer_shell_library,
                                 "gtk_layer_set_layer");
    DeettyLayerGetInt get_layer =
        (DeettyLayerGetInt)dlsym(root->layer_shell_library,
                                 "gtk_layer_get_layer");
    DeettyLayerSetInt set_keyboard_mode =
        (DeettyLayerSetInt)dlsym(root->layer_shell_library,
                                 "gtk_layer_set_keyboard_mode");
    DeettyLayerSetInt set_exclusive_zone =
        (DeettyLayerSetInt)dlsym(root->layer_shell_library,
                                 "gtk_layer_set_exclusive_zone");
    DeettyLayerSetMonitor set_monitor =
        (DeettyLayerSetMonitor)dlsym(root->layer_shell_library,
                                     "gtk_layer_set_monitor");
    if (init_for_window == NULL || is_layer_window == NULL ||
        set_namespace == NULL || set_layer == NULL || get_layer == NULL ||
        set_keyboard_mode == NULL || set_exclusive_zone == NULL)
        return FALSE;

    init_for_window(GTK_WINDOW(dialog));
    if (stacking_plan.lower_parent != 0) {
        set_layer(GTK_WINDOW(root->window), 2);
        root->settings_parent_layer_lowered =
            get_layer(GTK_WINDOW(root->window)) == 2;
        root->settings_parent_layer_lowered_seen =
            root->settings_parent_layer_lowered;
    } else {
        root->settings_parent_layer_lowered = 1;
    }
    if (set_monitor != NULL) {
        GdkMonitor *monitor = grid_monitor_for_window(root->window);
        if (monitor != NULL) set_monitor(GTK_WINDOW(dialog), monitor);
    }
    set_namespace(GTK_WINDOW(dialog), namespace_name);
    set_layer(GTK_WINDOW(dialog), 3);
    set_keyboard_mode(GTK_WINDOW(dialog), 1);
    set_exclusive_zone(GTK_WINDOW(dialog), 0);
    root->settings_layer_overlay =
        is_layer_window(GTK_WINDOW(dialog)) &&
        get_layer(GTK_WINDOW(dialog)) == 3;
    gboolean configured = root->settings_transient_parent &&
        root->settings_keep_above && root->settings_parent_layer_lowered &&
        root->settings_layer_overlay;
    if (!configured) {
        restore_settings_parent_layer(root);
        return FALSE;
    }
    root->overlay_dialog_count++;
    deetty_grid_object_set_data(
        dialog, "deetty-overlay-window", GINT_TO_POINTER(1));
    deetty_grid_signal_connect(dialog, "destroy",
                     G_CALLBACK(on_overlay_window_destroy), root);
    return TRUE;
}

static void configure_overlay_window_geometry(
    DeettyGridContext *context, GtkWidget *window,
    const GdkRectangle *workarea, int width, int height) {
    DeettyGridContext *root = root_grid_context(context);
    if (!root->layer_shell_active || root->layer_shell_library == NULL ||
        deetty_grid_object_get_data(window, "deetty-overlay-window") == NULL)
        return;

    DeettyLayerSetEdge set_anchor =
        (DeettyLayerSetEdge)dlsym(root->layer_shell_library,
                                  "gtk_layer_set_anchor");
    DeettyLayerSetMargin set_margin =
        (DeettyLayerSetMargin)dlsym(root->layer_shell_library,
                                    "gtk_layer_set_margin");
    if (set_anchor == NULL || set_margin == NULL) return;

    GdkRectangle monitor_geometry = *workarea;
    GdkMonitor *monitor = grid_monitor_for_window(root->window);
    if (monitor != NULL) deetty_grid_gdk_monitor_get_geometry(monitor, &monitor_geometry);
    DeettyGridOverlayGeometryPlan geometry_plan = {0};
    deetty_grid_overlay_geometry_plan(
        workarea->x, workarea->y, workarea->width, workarea->height,
        monitor_geometry.x, monitor_geometry.y,
        monitor_geometry.width, monitor_geometry.height,
        width, height, &geometry_plan);
    for (int edge = 0; edge < 4; edge++)
        set_anchor(GTK_WINDOW(window), edge, TRUE);
    set_margin(GTK_WINDOW(window), 0, geometry_plan.left);
    set_margin(GTK_WINDOW(window), 1, geometry_plan.right);
    set_margin(GTK_WINDOW(window), 2, geometry_plan.top);
    set_margin(GTK_WINDOW(window), 3, geometry_plan.bottom);
}

static void apply_dropdown_dimensions(DeettyGridContext *context) {
    DeettyGridContext *root = root_grid_context(context);
    DeettyGridNativeHostPolicy policy = {0};
    deetty_grid_native_host_policy(&policy);
    if (root->layer_shell_active) {
        apply_grid_layer_geometry(root);
        return;
    }
    GdkMonitor *monitor = grid_monitor_for_window(root->window);
    GdkRectangle workarea = {0, 0, 900, 420};
    if (monitor != NULL) deetty_grid_gdk_monitor_get_workarea(monitor, &workarea);
    int dropdown_width = deetty_grid_dropdown_dimension(
        root->dropdown_width_px, root->dropdown_width_percent,
        workarea.width, policy.dropdown_min_width_px);
    int dropdown_height = deetty_grid_dropdown_dimension(
        root->dropdown_height_px, root->dropdown_height_percent,
        workarea.height, policy.dropdown_min_height_px);
    DeettyGridAdaptiveWindowGeometry geometry = {0};
    if (!deetty_grid_adapt_window_geometry(
            0, 0, 0, 0, 0,
            workarea.x, workarea.y, workarea.width, workarea.height,
            dropdown_width, dropdown_height, &geometry))
        return;
    deetty_grid_window_resize(root->window, geometry.width, geometry.height);
    deetty_grid_window_move(root->window, geometry.x, geometry.y);
}

static void apply_window_dimensions(DeettyGridContext *context) {
    DeettyGridContext *root = root_grid_context(context);
    GdkMonitor *monitor = grid_monitor_for_window(root->window);
    GdkRectangle workarea = {0, 0, 900, 420};
    if (monitor != NULL) deetty_grid_gdk_monitor_get_workarea(monitor, &workarea);
    DeettyGridWindowDimensionsPlan dimensions = {0};
    deetty_grid_window_dimensions_plan(
        workarea.width, workarea.height, &dimensions);
    deetty_grid_widget_set_size_request(root->window, -1, -1);
    deetty_grid_window_resize(
        root->window, dimensions.width, dimensions.height);
}

static void apply_fullscreen_dimensions(DeettyGridContext *context) {
    DeettyGridContext *root = root_grid_context(context);
    if (!deetty_grid_widget_is_type(root->window, DEETTY_GTK_WINDOW)) return;
    deetty_grid_widget_set_size_request(root->window, -1, -1);
    GdkDisplay *display = deetty_grid_widget_get_display(root->window);
    GdkMonitor *monitor = grid_monitor_for_window(root->window);
    int monitor_index = -1;
    for (int index = 0; monitor != NULL && display != NULL &&
         index < deetty_grid_gdk_monitor_count(display); index++) {
        if (deetty_grid_gdk_monitor_at_index(display, index) == monitor) {
            monitor_index = index;
            break;
        }
    }
    GdkWindow *gdk_window = deetty_grid_widget_get_window(root->window);
    DeettyGridFullscreenPlan fullscreen_plan = {0};
    deetty_grid_fullscreen_plan(
        gdk_window != NULL ? 1 : 0,
        (display != NULL && GDK_IS_WAYLAND_DISPLAY(display)) ? 1 : 0,
        monitor_index, &fullscreen_plan);
    if (fullscreen_plan.action == DEETTY_GRID_FULLSCREEN_WINDOW) {
        deetty_grid_window_set_fullscreen(root->window, TRUE);
    } else {
        deetty_grid_gdk_window_set_fullscreen_mode(
            gdk_window, GDK_FULLSCREEN_ON_CURRENT_MONITOR);
        if (fullscreen_plan.action == DEETTY_GRID_FULLSCREEN_MONITOR)
            deetty_grid_gdk_window_fullscreen_on_monitor(gdk_window, monitor_index);
        else
            deetty_grid_gdk_window_fullscreen(gdk_window);
    }
}

static void schedule_resolution_adapt(DeettyGridContext *context) {
    DeettyGridContext *root = root_grid_context(context);
    if (root->resolution_adapt_source == 0)
        root->resolution_adapt_source =
            deetty_grid_source_idle_add(adapt_window_to_resolution, root);
}

static gboolean adapt_window_to_resolution(gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    DeettyGridNativeHostPolicy policy = {0};
    deetty_grid_native_host_policy(&policy);
    root->resolution_adapt_source = 0;
    if (!deetty_grid_widget_is_type(root->window, DEETTY_GTK_WINDOW)) return G_SOURCE_REMOVE;
    GdkMonitor *monitor = NULL;
    GdkRectangle monitor_geometry = {0};
    GdkRectangle workarea = {0};
    int scale_factor = 1;
    if (!grid_monitor_metrics(root->window, &monitor, &monitor_geometry,
                              &workarea, &scale_factor))
        return G_SOURCE_REMOVE;
    root->monitor_geometry_x = monitor_geometry.x;
    root->monitor_geometry_y = monitor_geometry.y;
    root->monitor_geometry_width = monitor_geometry.width;
    root->monitor_geometry_height = monitor_geometry.height;
    root->monitor_workarea_x = workarea.x;
    root->monitor_workarea_y = workarea.y;
    root->monitor_workarea_width = workarea.width;
    root->monitor_workarea_height = workarea.height;
    root->monitor_scale_factor = scale_factor;
    int current_x = 0;
    int current_y = 0;
    int current_width = 1;
    int current_height = 1;
    deetty_grid_window_get_position(GTK_WINDOW(root->window), &current_x, &current_y);
    deetty_grid_window_get_size(GTK_WINDOW(root->window),
                        &current_width, &current_height);
    const GdkRectangle *dropdown_space =
        root->layer_shell_active ? &monitor_geometry : &workarea;
    int dropdown_width = deetty_grid_dropdown_dimension(
        root->dropdown_width_px, root->dropdown_width_percent,
        dropdown_space->width, policy.dropdown_min_width_px);
    int dropdown_height = deetty_grid_dropdown_dimension(
        root->dropdown_height_px, root->dropdown_height_percent,
        dropdown_space->height, policy.dropdown_min_height_px);
    DeettyGridAdaptiveWindowGeometry geometry;
    if (!deetty_grid_adapt_window_geometry(
            root->mode, current_x, current_y, current_width, current_height,
            workarea.x, workarea.y, workarea.width, workarea.height,
            dropdown_width, dropdown_height, &geometry))
        return G_SOURCE_REMOVE;
    if (root->mode == 0 && root->layer_shell_active) {
        apply_grid_layer_geometry(root);
    } else if (root->mode == 2) {
        apply_fullscreen_dimensions(root);
    } else {
        deetty_grid_window_resize(root->window, geometry.width, geometry.height);
        deetty_grid_window_move(root->window, geometry.x, geometry.y);
    }
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        DeettyGridContext *candidate =
            g_ptr_array_index(root->contexts, index);
        if (candidate->active && candidate->area != NULL)
            deetty_grid_widget_queue_resize(candidate->area);
    }
    return G_SOURCE_REMOVE;
}

static gboolean on_window_resolution_configure(
    GtkWidget *widget, GdkEventConfigure *event, gpointer user_data) {
    (void)event;
    DeettyGridContext *root = root_grid_context(user_data);
    GdkRectangle geometry = {0};
    GdkRectangle workarea = {0};
    int scale_factor = 1;
    if (!grid_monitor_metrics(widget, NULL, &geometry, &workarea,
                              &scale_factor))
        return FALSE;
    const int changed = deetty_grid_monitor_metrics_changed(
        geometry.x, geometry.y, geometry.width, geometry.height,
        workarea.x, workarea.y, workarea.width, workarea.height,
        scale_factor,
        root->monitor_geometry_x, root->monitor_geometry_y,
        root->monitor_geometry_width, root->monitor_geometry_height,
        root->monitor_workarea_x, root->monitor_workarea_y,
        root->monitor_workarea_width, root->monitor_workarea_height,
        root->monitor_scale_factor);
    if (changed) schedule_resolution_adapt(root);
    return FALSE;
}

static void on_screen_geometry_changed(GdkScreen *screen,
                                       gpointer user_data) {
    (void)screen;
    GtkWidget *window = GTK_WIDGET(user_data);
    DeettyGridContext *root = deetty_grid_object_get_data(
        window, "deetty-grid-root-context");
    if (root != NULL) schedule_resolution_adapt(root);
}

static void on_window_map(GtkWidget *widget, gpointer user_data) {
    (void)widget;
    DeettyGridContext *root = root_grid_context(user_data);
    root->window_map_count++;
    schedule_resolution_adapt(root);
#if DEETTY_ENABLE_SMOKE
    if (root->workspace_smoke == 44 || root->workspace_smoke == 45) {
        g_printerr(
            "native_grid_resolution_window_ready mode=%s layer_shell=%s\n",
            root->mode == 0 ? "dropdown" : "fullscreen",
            root->layer_shell_active ? "true" : "false");
    }
#endif
}

static GtkWidget *create_grid_toplevel(DeettyGridContext *context) {
    DeettyGridContext *root = root_grid_context(context);
    GtkWidget *window = deetty_grid_window_new();
    GdkScreen *screen = deetty_grid_widget_get_screen(window);
    GdkVisual *visual = screen != NULL
        ? deetty_grid_gdk_screen_get_rgba_visual(screen) : NULL;
    gboolean wayland = GDK_IS_WAYLAND_DISPLAY(
        deetty_grid_widget_get_display(window));
    root->background_alpha_supported = visual != NULL && screen != NULL &&
        (wayland || deetty_grid_gdk_screen_is_composited(screen));
    if (root->background_alpha_supported) {
        deetty_grid_widget_set_visual(window, visual);
        deetty_grid_widget_set_app_paintable(window, TRUE);
    }
    deetty_grid_window_configure(
        window,
        root->workspace_smoke == 21 ? 1200 : 1100,
        root->workspace_smoke == 21 ? 720 : 640,
        root->mode == 1,
        root->mode == 0);
    root->translucent_surface_ready =
        deetty_grid_object_get_data(
            window, "deetty-style-provider-installed") != NULL &&
        deetty_grid_style_context_has_class(deetty_grid_widget_get_style_context(window),
                                    "deetty-terminal-window") &&
        (!root->background_alpha_supported ||
         deetty_grid_widget_get_app_paintable(window));
    root->application_icon_ready = g_strcmp0(
        deetty_grid_window_get_icon_name(GTK_WINDOW(window)),
        "com.deetty.DEETTY") == 0;
    set_grid_window_title(
        root,
        window,
        root->workspace_smoke == 44
            ? "DEETTY resolution dropdown qualification"
            : root->workspace_smoke == 45
                ? "DEETTY resolution fullscreen qualification"
                : root->workspace_smoke == 39
                    ? "DEETTY installed continuity qualification"
                    : "DEETTY native grid");
    deetty_grid_object_set_data(window, "deetty-grid-root-context", root);
    if (screen != NULL) {
        deetty_grid_signal_connect_object(
            screen, "size-changed", G_CALLBACK(on_screen_geometry_changed),
            window, 0);
        deetty_grid_signal_connect_object(
            screen, "monitors-changed",
            G_CALLBACK(on_screen_geometry_changed), window, 0);
    }
    DeettyGridWindowCallbacks window_callbacks = {
        .delete_event = G_CALLBACK(on_window_delete_event),
        .destroy = G_CALLBACK(on_window_destroy),
        .focus_out_event = G_CALLBACK(on_window_focus_out),
        .map = G_CALLBACK(on_window_map),
        .configure_event = G_CALLBACK(on_window_resolution_configure),
        .button_release_event = G_CALLBACK(on_window_resize_handle_release),
    };
    if (!deetty_grid_window_connect_signals(
            window, root, &window_callbacks)) {
        deetty_grid_widget_destroy(window);
        return NULL;
    }
    deetty_grid_widget_add_events(
        window, GDK_BUTTON_RELEASE_MASK | GDK_POINTER_MOTION_MASK);
    deetty_grid_signal_connect(
        window, "motion-notify-event",
        G_CALLBACK(on_window_resize_handle_motion), root);
    return window;
}

static gboolean recreate_grid_toplevel_idle(gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    root->window_mode_recreate_source = 0;
    GtkWidget *old_window = root->window;
    GtkWidget *layout = root->window_layout;
    if (!deetty_grid_widget_is_type(old_window, DEETTY_GTK_WINDOW) || layout == NULL ||
        deetty_grid_widget_in_destruction(old_window))
        return G_SOURCE_REMOVE;

    gboolean was_presented = root->window_presented &&
        deetty_grid_widget_get_visible(old_window);
    DeettyGridContext *title_context = active_grid_context(root);
    const char *title = title_context != NULL
        ? title_context->display_title : NULL;
    gboolean reopen_settings = deetty_grid_widget_is_type(root->settings_dialog, DEETTY_GTK_WINDOW) &&
        deetty_grid_widget_get_visible(root->settings_dialog);
    if (reopen_settings) deetty_grid_widget_destroy(root->settings_dialog);
    dismiss_grid_popup_windows(root);
    while (deetty_grid_events_pending()) deetty_grid_main_iteration_do(FALSE);

    g_signal_handlers_disconnect_by_func(
        old_window, G_CALLBACK(on_window_delete_event), root);
    g_signal_handlers_disconnect_by_func(
        old_window, G_CALLBACK(on_window_focus_out), root);
    g_signal_handlers_disconnect_by_func(
        old_window, G_CALLBACK(on_window_destroy), NULL);
    deetty_grid_widget_hide(old_window);
    deetty_grid_object_ref(layout);
    deetty_container_remove(old_window, layout);

    root->layer_shell_active = 0;
    root->layer_shell_monitor = NULL;
    root->window = create_grid_toplevel(root);
    if (title != NULL) set_grid_window_title(root, root->window, title);
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++)
        ((DeettyGridContext *)g_ptr_array_index(root->contexts, index))
            ->window = root->window;
    deetty_container_add(root->window, layout);
    deetty_grid_object_unref(layout);

    root->window_presented = was_presented;
    if (root->mode == 0) {
        (void)configure_grid_layer_shell(root);
        (void)normalize_dropdown_pixel_dimensions(root, TRUE);
    }
    if (was_presented) show_all_with_action_affordances(root->window);
    update_window_toolbar_controls(root);
    update_window_resize_handles(root);
    if (root->mode == 0) apply_dropdown_dimensions(root);
    else if (root->mode == 1) apply_window_dimensions(root);
    else apply_fullscreen_dimensions(root);
    if (!was_presented) deetty_grid_widget_hide(root->window);
    else {
        root->window_presented = 1;
        if (!root->layer_shell_active)
            deetty_grid_window_present(root->window);
        DeettyGridContext *focus_target = active_grid_context(root);
        if (focus_target != NULL) defer_grid_context_focus(focus_target);
    }
    deetty_grid_widget_destroy(old_window);
    if (reopen_settings && was_presented) {
        open_grid_settings(root);
        root->settings_reopened_after_mode_change =
            deetty_grid_widget_is_type(root->settings_dialog, DEETTY_GTK_WINDOW) &&
            deetty_grid_widget_get_visible(root->settings_dialog);
    }
    root->window_mode_surface_recreated = 1;
    return G_SOURCE_REMOVE;
}

static void sync_compact_setting(DeettyGridContext *context, int field, int value) {
    DeettyGridContext *root = root_grid_context(context);
    DeettyGridCompactSettingPlan plan = {0};
    deetty_grid_compact_setting_plan(field, &plan);
    if (!plan.valid) return;
    for (guint index = 0; root->contexts != NULL && index < root->contexts->len; index++) {
        DeettyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        switch (plan.target) {
        case DEETTY_GRID_COMPACT_TARGET_WIDTH_PERCENT:
            candidate->dropdown_width_percent = value;
            break;
        case DEETTY_GRID_COMPACT_TARGET_HEIGHT_PERCENT:
            candidate->dropdown_height_percent = value;
            break;
        case DEETTY_GRID_COMPACT_TARGET_ANIMATION:
            candidate->dropdown_animation_ms = value;
            break;
        case DEETTY_GRID_COMPACT_TARGET_HIDE_FOCUS:
            candidate->hide_on_focus_loss = value;
            break;
        case DEETTY_GRID_COMPACT_TARGET_FOCUS_POINTER:
            candidate->focus_follows_pointer = value;
            break;
        case DEETTY_GRID_COMPACT_TARGET_PANE_INFO:
            candidate->show_pane_info = value;
            break;
        case DEETTY_GRID_COMPACT_TARGET_WIDTH_PIXELS:
            candidate->dropdown_width_px = value;
            break;
        case DEETTY_GRID_COMPACT_TARGET_HEIGHT_PIXELS:
            candidate->dropdown_height_px = value;
            break;
        default:
            break;
        }
    }
}

static gboolean normalize_dropdown_pixel_dimensions(
    DeettyGridContext *context, gboolean notify) {
    DeettyGridContext *root = root_grid_context(context);
    if (root->dropdown_width_px <= 0 && root->dropdown_height_px <= 0)
        return FALSE;
    GdkMonitor *monitor = grid_monitor_for_window(root->window);
    if (monitor == NULL) return FALSE;
    GdkRectangle available = {0};
    if (root->layer_shell_active)
        deetty_grid_gdk_monitor_get_geometry(monitor, &available);
    else
        deetty_grid_gdk_monitor_get_workarea(monitor, &available);
    int width_percent = deetty_grid_dropdown_percent(
        root->dropdown_width_px, available.width,
        root->dropdown_width_percent);
    int height_percent = deetty_grid_dropdown_percent(
        root->dropdown_height_px, available.height,
        root->dropdown_height_percent);
    sync_compact_setting(root, DEETTY_GRID_COMPACT_FIELD_WIDTH_PERCENT, width_percent);
    sync_compact_setting(root, DEETTY_GRID_COMPACT_FIELD_HEIGHT_PERCENT, height_percent);
    sync_compact_setting(root, DEETTY_GRID_COMPACT_FIELD_WIDTH_PIXELS, 0);
    sync_compact_setting(root, DEETTY_GRID_COMPACT_FIELD_HEIGHT_PIXELS, 0);
    if (notify && root->event != NULL) {
        uint64_t timestamp =
            (uint64_t)(g_get_monotonic_time() / 1000);
        root->event(root->event_data, root->pane_id,
                    deetty_grid_settings_event_code(DEETTY_GRID_SETTINGS_EVENT_DROPDOWN_WIDTH),
                    width_percent, timestamp);
        root->event(root->event_data, root->pane_id,
                    deetty_grid_settings_event_code(DEETTY_GRID_SETTINGS_EVENT_DROPDOWN_HEIGHT),
                    height_percent, timestamp);
    }
    return TRUE;
}

static void apply_pane_info_visibility(DeettyGridContext *context,
                                       int enabled) {
    DeettyGridContext *root = root_grid_context(context);
    sync_compact_setting(
        context, DEETTY_GRID_COMPACT_FIELD_TAB_HEIGHT, enabled);
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++)
        ((DeettyGridContext *)g_ptr_array_index(root->contexts, index))
            ->show_pane_info = enabled != 0;
    deetty_pane_info_strip_set_enabled(root->pane_info_strip, enabled);
    update_window_resize_handles(root);
    if (enabled) refresh_active_pane_info(root);
}

static void on_settings_dropdown_width_changed(GtkSpinButton *spin, gpointer user_data) {
    DeettyGridContext *context = user_data;
    int value = deetty_grid_spin_button_get_value_as_int(spin);
    sync_compact_setting(
        context, DEETTY_GRID_COMPACT_FIELD_WIDTH_PERCENT, value);
    sync_compact_setting(context, DEETTY_GRID_COMPACT_FIELD_WIDTH_PIXELS, 0);
    sync_compact_setting(context, DEETTY_GRID_COMPACT_FIELD_HEIGHT_PIXELS, 0);
    apply_dropdown_dimensions(context);
    if (context->event != NULL) context->event(context->event_data, context->pane_id, deetty_grid_settings_event_code(DEETTY_GRID_SETTINGS_EVENT_DROPDOWN_WIDTH), value, (uint64_t)(g_get_monotonic_time() / 1000));
}

static void on_settings_dropdown_height_changed(GtkSpinButton *spin, gpointer user_data) {
    DeettyGridContext *context = user_data;
    int value = deetty_grid_spin_button_get_value_as_int(spin);
    sync_compact_setting(
        context, DEETTY_GRID_COMPACT_FIELD_HEIGHT_PERCENT, value);
    sync_compact_setting(context, DEETTY_GRID_COMPACT_FIELD_WIDTH_PIXELS, 0);
    sync_compact_setting(context, DEETTY_GRID_COMPACT_FIELD_HEIGHT_PIXELS, 0);
    apply_dropdown_dimensions(context);
    if (context->event != NULL) context->event(context->event_data, context->pane_id, deetty_grid_settings_event_code(DEETTY_GRID_SETTINGS_EVENT_DROPDOWN_HEIGHT), value, (uint64_t)(g_get_monotonic_time() / 1000));
}

static void on_settings_animation_changed(GtkSpinButton *spin, gpointer user_data) {
    DeettyGridContext *context = user_data;
    int value = deetty_grid_spin_button_get_value_as_int(spin);
    sync_compact_setting(
        context, DEETTY_GRID_COMPACT_FIELD_ANIMATION, value);
    DeettyGridContext *root = root_grid_context(context);
    if (root->revealer != NULL)
        deetty_grid_revealer_set_transition_duration(GTK_REVEALER(root->revealer),
                                             (guint)value);
    if (context->event != NULL) context->event(context->event_data, context->pane_id, deetty_grid_settings_event_code(DEETTY_GRID_SETTINGS_EVENT_ANIMATION), value, (uint64_t)(g_get_monotonic_time() / 1000));
}

static void on_settings_hide_focus_toggled(GtkToggleButton *toggle, gpointer user_data) {
    DeettyGridContext *context = user_data;
    int value = deetty_grid_toggle_button_get_active(toggle);
    sync_compact_setting(
        context, DEETTY_GRID_COMPACT_FIELD_HIDE_FOCUS, value);
    if (context->event != NULL) context->event(context->event_data, context->pane_id, deetty_grid_settings_event_code(DEETTY_GRID_SETTINGS_EVENT_HIDE_FOCUS), value, (uint64_t)(g_get_monotonic_time() / 1000));
}

static void on_settings_focus_pointer_toggled(GtkToggleButton *toggle, gpointer user_data) {
    DeettyGridContext *context = user_data;
    int value = deetty_grid_toggle_button_get_active(toggle);
    sync_compact_setting(
        context, DEETTY_GRID_COMPACT_FIELD_FOCUS_POINTER, value);
    if (context->event != NULL) context->event(context->event_data, context->pane_id, deetty_grid_settings_event_code(DEETTY_GRID_SETTINGS_EVENT_FOCUS_POINTER), value, (uint64_t)(g_get_monotonic_time() / 1000));
}

static void on_settings_pane_info_toggled(GtkToggleButton *toggle,
                                          gpointer user_data) {
    DeettyGridContext *context = user_data;
    int value = deetty_grid_toggle_button_get_active(toggle);
    apply_pane_info_visibility(context, value);
    root_grid_context(context)->pane_info_setting_toggled = 1;
    if (context->event != NULL)
        context->event(context->event_data, context->pane_id,
                       deetty_grid_settings_event_code(DEETTY_GRID_SETTINGS_EVENT_PANE_INFO), value,
                       (uint64_t)(g_get_monotonic_time() / 1000));
}

static void on_settings_scrollback_changed(GtkSpinButton *spin,
                                           gpointer user_data) {
    DeettyGridContext *context = user_data;
    int value = deetty_grid_spin_button_get_value_as_int(spin);
    if (context->event != NULL)
        context->event(context->event_data, context->pane_id,
                       deetty_grid_settings_event_code(DEETTY_GRID_SETTINGS_EVENT_SCROLLBACK), value,
                       (uint64_t)(g_get_monotonic_time() / 1000));
}

static void apply_terminal_scroll_setting(DeettyGridContext *context,
                                          int event_code, int value) {
    DeettyGridContext *root = root_grid_context(context);
    int resolved = deetty_grid_terminal_scroll_setting(event_code, value);
    if (resolved < 0) return;
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        DeettyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (event_code == deetty_grid_settings_event_code(
                DEETTY_GRID_SETTINGS_EVENT_SCROLL_LINES))
            candidate->terminal_scroll_lines = resolved;
        else
            candidate->terminal_smooth_scroll = resolved != 0;
        candidate->terminal_scroll_accumulator = 0.0;
    }
    if (context->event != NULL)
        context->event(context->event_data, context->pane_id, event_code,
                       value, (uint64_t)(g_get_monotonic_time() / 1000));
}

static void on_settings_scroll_lines_changed(GtkSpinButton *spin,
                                             gpointer user_data) {
    apply_terminal_scroll_setting(
        user_data, deetty_grid_settings_event_code(
            DEETTY_GRID_SETTINGS_EVENT_SCROLL_LINES),
        deetty_grid_spin_button_get_value_as_int(spin));
}

static void on_settings_smooth_scroll_toggled(GtkToggleButton *toggle,
                                              gpointer user_data) {
    apply_terminal_scroll_setting(
        user_data, deetty_grid_settings_event_code(
            DEETTY_GRID_SETTINGS_EVENT_SMOOTH_SCROLL),
        deetty_grid_toggle_button_get_active(toggle));
}

static void on_settings_mode_changed(GtkComboBox *combo, gpointer user_data) {
    DeettyGridContext *context = user_data;
    int mode = deetty_grid_combo_box_get_active(combo);
    if (mode < 0 || mode > 2) return;
    DeettyGridContext *root = root_grid_context(context);
    int previous_mode = root->mode;
    for (guint index = 0; root->contexts != NULL && index < root->contexts->len; index++)
        ((DeettyGridContext *)g_ptr_array_index(root->contexts, index))->mode = mode;
    DeettyGridWindowModePlan mode_plan = {0};
    deetty_grid_window_mode_plan(
        previous_mode, mode, root->layer_shell_active, &mode_plan);
    if (mode_plan.action == DEETTY_GRID_WINDOW_MODE_ACTION_RECREATE) {
        if (root->window_mode_recreate_source == 0)
            root->window_mode_recreate_source =
                deetty_grid_source_idle_add(recreate_grid_toplevel_idle, root);
        if (context->event != NULL)
            context->event(context->event_data, context->pane_id,
                           deetty_grid_settings_event_code(DEETTY_GRID_SETTINGS_EVENT_MODE), mode,
                           (uint64_t)(g_get_monotonic_time() / 1000));
        return;
    }
    if (mode_plan.action == DEETTY_GRID_WINDOW_MODE_ACTION_NONE) return;
    deetty_grid_window_apply_mode(
        root->window, mode == 1, mode == 0);
    update_window_resize_handles(root);
    switch (mode_plan.action) {
    case DEETTY_GRID_WINDOW_MODE_ACTION_APPLY_LAYER_GEOMETRY:
        apply_grid_layer_geometry(root);
        break;
    case DEETTY_GRID_WINDOW_MODE_ACTION_APPLY_FULLSCREEN:
        apply_fullscreen_dimensions(root);
        break;
    case DEETTY_GRID_WINDOW_MODE_ACTION_APPLY_WINDOW:
        deetty_grid_window_set_fullscreen(root->window, FALSE);
        apply_window_dimensions(root);
        break;
    case DEETTY_GRID_WINDOW_MODE_ACTION_APPLY_DROPDOWN:
        deetty_grid_window_set_fullscreen(root->window, FALSE);
        apply_dropdown_dimensions(root);
        break;
    default:
        return;
    }
    if (context->event != NULL) context->event(context->event_data, context->pane_id, deetty_grid_settings_event_code(DEETTY_GRID_SETTINGS_EVENT_MODE), mode, (uint64_t)(g_get_monotonic_time() / 1000));
}

static gboolean apply_grid_font_size(DeettyGridContext *context,
                                     double requested, gboolean notify) {
    DeettyGridContext *root = root_grid_context(context);
    double next = deetty_grid_font_size_clamp(
        requested, root->font_min_size, root->font_max_size);
    gboolean changed = FALSE;
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        DeettyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (candidate->requested_font_size != next) {
            changed = TRUE;
            break;
        }
    }
    if (!changed) return FALSE;
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        DeettyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        candidate->requested_font_size = next;
        candidate->font_size = next;
        clear_ascii_glyph_cache(candidate);
        if (candidate->area != NULL) {
            GtkAllocation allocation;
            deetty_grid_widget_get_allocation(candidate->area, &allocation);
            resize_grid_to_allocation(candidate, &allocation);
            deetty_grid_widget_queue_draw(candidate->area);
        }
    }
    if (notify && context->event != NULL)
        context->event(context->event_data, context->pane_id,
                       deetty_grid_settings_event_code(DEETTY_GRID_SETTINGS_EVENT_FONT_SIZE),
                       deetty_grid_font_size_event_value(
                           next, root->font_min_size, root->font_max_size),
                       (uint64_t)(g_get_monotonic_time() / 1000));
    return TRUE;
}

static gboolean apply_pane_font_size(DeettyGridContext *context,
                                     double requested, gboolean notify) {
    DeettyGridContext *root = root_grid_context(context);
    double next = deetty_grid_font_size_clamp(
        requested, root->font_min_size, root->font_max_size);
    if (next == context->requested_font_size) return FALSE;
    context->requested_font_size = next;
    context->font_size = next;
    clear_ascii_glyph_cache(context);
    if (context->area != NULL) {
        GtkAllocation allocation;
        deetty_grid_widget_get_allocation(context->area, &allocation);
        resize_grid_to_allocation(context, &allocation);
        deetty_grid_widget_queue_draw(context->area);
    }
    if (notify && context->event != NULL)
        context->event(context->event_data, context->pane_id,
                       deetty_grid_settings_event_code(DEETTY_GRID_SETTINGS_EVENT_PANE_FONT_SIZE),
                       deetty_grid_font_size_event_value(
                           next, root->font_min_size, root->font_max_size),
                       (uint64_t)(g_get_monotonic_time() / 1000));
    return TRUE;
}

static gboolean sync_grid_context_profile(DeettyGridContext *context) {
    if (context == NULL || context->event_data == NULL ||
        context->pane_id == 0)
        return FALSE;
    char family[256] = {0};
    int font_size_hundredths = 0;
    int high_contrast = 0;
    int ligatures = 1;
    int preset = deetty_grid_pane_profile(
        context->event_data, context->pane_id, family, sizeof(family),
        &font_size_hundredths, &high_contrast, &ligatures);
    if (font_size_hundredths <= 0 || family[0] == '\0') return FALSE;

    gboolean changed = FALSE;
    if (g_strcmp0(context->font_family, family) != 0) {
        deetty_grid_memory_free(context->font_family);
        context->font_family = g_strdup(family);
        clear_ascii_glyph_cache(context);
        changed = TRUE;
    }
    if (context->high_contrast != (high_contrast != 0)) {
        context->high_contrast = high_contrast != 0;
        changed = TRUE;
    }
    if (context->ligatures != (ligatures != 0)) {
        context->ligatures = ligatures != 0;
        clear_ascii_glyph_cache(context);
        changed = TRUE;
    }
    int resolved_preset = deetty_grid_profile_preset_valid(preset)
        ? preset : -1;
    if (context->profile_preset != resolved_preset) {
        context->profile_preset = resolved_preset;
        changed = TRUE;
    }
    double resolved_size = deetty_grid_font_size_clamp(
        font_size_hundredths / 100.0,
        context->font_min_size, context->font_max_size);
    if (context->area != NULL && deetty_grid_widget_get_mapped(context->area)) {
        if (apply_pane_font_size(context, resolved_size, FALSE))
            changed = TRUE;
    } else if (context->requested_font_size != resolved_size) {
        context->requested_font_size = resolved_size;
        context->font_size = resolved_size;
        changed = TRUE;
    }
    if (changed && context->area != NULL)
        deetty_grid_widget_queue_draw(context->area);
    return TRUE;
}

static void on_settings_font_changed(GtkSpinButton *spin, gpointer user_data) {
    DeettyGridContext *context = user_data;
    (void)apply_grid_font_size(
        context, deetty_grid_spin_button_get_value(spin), TRUE);
}

static void on_settings_notifications_toggled(GtkToggleButton *toggle, gpointer user_data) {
    DeettyGridContext *context = user_data;
    context->enable_notifications = deetty_grid_toggle_button_get_active(toggle);
    if (context->event != NULL) context->event(context->event_data, context->pane_id, deetty_grid_settings_event_code(DEETTY_GRID_SETTINGS_EVENT_NOTIFICATIONS), context->enable_notifications, (uint64_t)(g_get_monotonic_time() / 1000));
}

static void on_settings_preset_changed(GtkComboBox *combo, gpointer user_data) {
    DeettyGridContext *context = user_data;
    int preset = deetty_grid_combo_box_get_active(combo);
    if (preset >= 0 && context->event != NULL) {
        context->event(context->event_data, context->pane_id,
                       deetty_grid_settings_event_code(DEETTY_GRID_SETTINGS_EVENT_PRESET), preset,
                       (uint64_t)(g_get_monotonic_time() / 1000));
        (void)sync_grid_context_profile(context);
    }
}


static void apply_grid_tab_position(DeettyGridContext *context, int value,
                                    gboolean notify) {
    if (value < 0 || value > 3) return;
    DeettyGridContext *root = root_grid_context(context);
    DeettyGridNotebookChromePlan chrome = {0};
    deetty_grid_notebook_chrome_plan(
        root->zoomed_pane_id,
        deetty_grid_notebook_get_n_pages(GTK_NOTEBOOK(root->notebook)),
        &chrome);
    deetty_grid_notebook_apply_policy(
        context->notebook, context->window_toolbar_controls,
        value, chrome.show != 0);
    for (guint index = 0; context->contexts != NULL &&
         index < context->contexts->len; index++) {
        DeettyGridContext *candidate =
            g_ptr_array_index(context->contexts, index);
        candidate->tab_position = value;
    }
    if (notify && context->event != NULL) {
        context->event(context->event_data, context->pane_id,
                       deetty_grid_settings_event_code(DEETTY_GRID_SETTINGS_EVENT_TAB_POSITION), value,
                       (uint64_t)(g_get_monotonic_time() / 1000));
    }
}

static void on_settings_tabs_changed(GtkComboBox *combo, gpointer user_data) {
    DeettyGridContext *context = user_data;
    int value = deetty_grid_combo_box_get_active(combo);
    if (value >= 0 && context->event != NULL) context->event(context->event_data, context->pane_id, deetty_grid_settings_event_code(DEETTY_GRID_SETTINGS_EVENT_TABS), value, (uint64_t)(g_get_monotonic_time() / 1000));
    apply_grid_tab_position(context, value, TRUE);
}

static void on_settings_status_changed(GtkComboBox *combo, gpointer user_data) {
    DeettyGridContext *context = user_data;
    int value = deetty_grid_combo_box_get_active(combo);
    if (value >= 0 && context->event != NULL) context->event(context->event_data, context->pane_id, deetty_grid_settings_event_code(DEETTY_GRID_SETTINGS_EVENT_STATUS), value, (uint64_t)(g_get_monotonic_time() / 1000));
}

static void apply_panel_metric_setting(DeettyGridContext *context,
                                       int event_code, int value) {
    DeettyGridContext *root = root_grid_context(context);
    int affects_layout = 0;
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        DeettyGridContext *candidate =
            g_ptr_array_index(root->contexts, index);
        DeettyGridPanelSettings settings = {
            .panel_padding_px = candidate->panel_padding_px,
            .pane_spacing_px = candidate->pane_spacing_px,
            .pane_divider_px = candidate->pane_divider_px,
            .pane_border_px = candidate->pane_border_px,
            .pane_border_focused_px = candidate->pane_border_focused_px,
            .pane_border_selected_px = candidate->pane_border_selected_px,
            .status_border_px = candidate->status_border_px,
            .overlay_border_px = candidate->overlay_border_px,
            .window_border_px = candidate->window_border_px,
            .dragger_px = candidate->dragger_px,
            .pane_gaps_enabled = candidate->pane_gaps_enabled,
            .pane_gaps_transparent = candidate->pane_gaps_transparent,
            .inactive_pane_dim_enabled = candidate->inactive_pane_dim_enabled,
            .inactive_pane_brightness_percent =
                candidate->inactive_pane_brightness_percent,
            .background_translucency = candidate->background_translucency,
            .background_opacity_percent =
                candidate->background_opacity_percent,
        };
        if (deetty_grid_panel_settings_apply(
                event_code, value, &settings) == 0)
            return;
        candidate->panel_padding_px = settings.panel_padding_px;
        candidate->pane_spacing_px = settings.pane_spacing_px;
        candidate->pane_divider_px = settings.pane_divider_px;
        candidate->pane_border_px = settings.pane_border_px;
        candidate->pane_border_focused_px = settings.pane_border_focused_px;
        candidate->pane_border_selected_px = settings.pane_border_selected_px;
        candidate->status_border_px = settings.status_border_px;
        candidate->overlay_border_px = settings.overlay_border_px;
        candidate->window_border_px = settings.window_border_px;
        candidate->dragger_px = settings.dragger_px;
        candidate->pane_gaps_enabled = settings.pane_gaps_enabled;
        candidate->pane_gaps_transparent = settings.pane_gaps_transparent;
        candidate->inactive_pane_dim_enabled =
            settings.inactive_pane_dim_enabled;
        candidate->inactive_pane_brightness_percent =
            settings.inactive_pane_brightness_percent;
        candidate->background_translucency = settings.background_translucency;
        candidate->background_opacity_percent =
            settings.background_opacity_percent;
        affects_layout = settings.affects_layout;
        if (candidate->active && candidate->area != NULL)
            deetty_grid_widget_queue_draw(candidate->area);
    }
    if (affects_layout) {
        apply_panel_layout_metrics(root);
        update_window_resize_handles(root);
    }
    if (context->event != NULL)
        context->event(context->event_data, context->pane_id, event_code,
                       value, (uint64_t)(g_get_monotonic_time() / 1000));
}

static void on_settings_panel_metric_changed(GtkSpinButton *spin,
                                             gpointer user_data) {
    int event_code = GPOINTER_TO_INT(deetty_grid_object_get_data(
        G_OBJECT(spin), "deetty-panel-metric-event"));
    apply_panel_metric_setting(
        user_data, event_code, deetty_grid_spin_button_get_value_as_int(spin));
}

static void on_settings_panel_toggle(GtkToggleButton *toggle,
                                     gpointer user_data) {
    int event_code = GPOINTER_TO_INT(deetty_grid_object_get_data(
        G_OBJECT(toggle), "deetty-panel-metric-event"));
    gboolean active = deetty_grid_toggle_button_get_active(toggle);
    apply_panel_metric_setting(user_data, event_code, active);
    if (event_code == deetty_grid_settings_event_code(
            DEETTY_GRID_SETTINGS_EVENT_PANE_GAPS_ENABLED)) {
        GtkWidget *width = deetty_grid_object_get_data(
            G_OBJECT(toggle), "deetty-gap-width");
        GtkWidget *transparent = deetty_grid_object_get_data(
            G_OBJECT(toggle), "deetty-gap-transparent");
        if (width != NULL) deetty_grid_widget_set_sensitive(width, active);
        if (transparent != NULL)
            deetty_grid_widget_set_sensitive(transparent, active);
    } else if (event_code == deetty_grid_settings_event_code(
                   DEETTY_GRID_SETTINGS_EVENT_INACTIVE_PANE_DIM)) {
        GtkWidget *brightness = deetty_grid_object_get_data(
            G_OBJECT(toggle), "deetty-inactive-brightness");
        if (brightness != NULL)
            deetty_grid_widget_set_sensitive(brightness, active);
    }
}

static void on_settings_inactive_brightness_changed(GtkRange *range,
                                                     gpointer user_data) {
    apply_panel_metric_setting(
        user_data, deetty_grid_settings_event_code(
            DEETTY_GRID_SETTINGS_EVENT_INACTIVE_PANE_BRIGHTNESS),
        (int)deetty_grid_range_get_value(range));
}

static void populate_theme_combo(DeettyGridContext *context,
                                 GtkComboBoxText *combo) {
    char active[97] = {0};
    if (context->event_data != NULL) {
        if (deetty_grid_pane_theme_name(
                context->event_data, context->pane_id,
                active, sizeof(active)) <= 0)
            (void)deetty_grid_active_theme_name(
                context->event_data, active, sizeof(active));
    }
    int count = context->event_data != NULL
        ? deetty_grid_theme_count(context->event_data) : 0;
    for (int index = 0; index < count; index++) {
        char name[97] = {0};
        int length = deetty_grid_theme_name(
            context->event_data, index, name, sizeof(name));
        if (length <= 0) continue;
        char label[128] = {0};
        int label_length = deetty_grid_theme_display_label(
            (const unsigned char *)name, strlen(name),
            (unsigned char *)label, sizeof(label));
        if (label_length <= 0) continue;
        deetty_grid_combo_box_text_append(combo, name, label);
    }
    if (active[0] != '\0')
        deetty_grid_combo_box_set_active_id(GTK_COMBO_BOX(combo), active);
    if (deetty_grid_combo_box_get_active(GTK_COMBO_BOX(combo)) < 0)
        deetty_grid_combo_box_set_active(GTK_COMBO_BOX(combo), 0);
}

static void refresh_theme_combo(DeettyGridContext *context,
                                GtkWidget *combo) {
    if (!deetty_grid_widget_is_type(combo, DEETTY_GTK_COMBO_BOX_TEXT)) return;
    deetty_grid_combo_box_text_remove_all(combo);
    populate_theme_combo(context, GTK_COMBO_BOX_TEXT(combo));
}

static void refresh_open_theme_selectors(DeettyGridContext *context) {
    DeettyGridContext *root = root_grid_context(context);
    if (deetty_grid_widget_is_type(root->settings_dialog, DEETTY_GTK_WINDOW))
        refresh_theme_combo(active_grid_context(root), deetty_grid_object_get_data(
            G_OBJECT(root->settings_dialog), "deetty-settings-theme"));
    if (deetty_grid_widget_is_type(root->theme_dialog, DEETTY_GTK_WINDOW))
        refresh_theme_combo(root, deetty_grid_object_get_data(
            G_OBJECT(root->theme_dialog), "deetty-theme-selector"));
}

static void set_theme_library_status(DeettyGridContext *context,
                                     const gchar *message,
                                     gboolean is_error) {
    DeettyGridContext *root = root_grid_context(context);
    if (!deetty_grid_widget_is_type(root->theme_dialog, DEETTY_GTK_WINDOW)) return;
    GtkWidget *status = deetty_grid_object_get_data(
        G_OBJECT(root->theme_dialog), "deetty-theme-status");
    set_status_label_feedback(status, message, is_error);
}


static void on_settings_theme_changed(GtkComboBox *combo, gpointer user_data) {
    DeettyGridContext *target = active_grid_context(user_data);
    DeettyGridContext *context = root_grid_context(user_data);
    const gchar *name = deetty_grid_combo_box_get_active_id(combo);
    if (name == NULL || context->text_action == NULL || target == NULL) return;
    DeettyGridNativeHostPolicy policy = {0};
    deetty_grid_native_host_policy(&policy);
    GtkWidget *scope = deetty_grid_object_get_data(
        G_OBJECT(combo), "deetty-theme-scope-tab");
    gboolean current_tab_only = deetty_grid_widget_is_type(scope, DEETTY_GTK_TOGGLE_BUTTON) &&
        deetty_grid_toggle_button_get_active(GTK_TOGGLE_BUTTON(scope));
    int result = current_tab_only
        ? deetty_grid_set_tab_theme(
              context->event_data, target->pane_id, name, strlen(name))
        : context->text_action(
              context->text_action_data, 21, name, strlen(name), "", 0, 0);
    if (result != 0 && result != policy.text_action_persistence_failed) {
        g_signal_handlers_block_by_func(
            combo, G_CALLBACK(on_settings_theme_changed), user_data);
        refresh_theme_combo(context, GTK_WIDGET(combo));
        g_signal_handlers_unblock_by_func(
            combo, G_CALLBACK(on_settings_theme_changed), user_data);
        set_theme_library_status(
            context, "Theme selection could not be applied.", TRUE);
        return;
    }
    for (guint index = 0; context->contexts != NULL &&
         index < context->contexts->len; index++) {
        DeettyGridContext *candidate =
            g_ptr_array_index(context->contexts, index);
        (void)sync_grid_context_profile(candidate);
        if (candidate->active && candidate->area != NULL)
            deetty_grid_widget_queue_draw(candidate->area);
    }
    apply_panel_layout_metrics(context);
    if (result == policy.text_action_persistence_failed)
        set_theme_library_status(
            context,
            "Theme selected for this session but the selection could not be saved.",
            TRUE);
    else
        set_theme_library_status(
            context,
            current_tab_only
                ? "Theme applied to the current tab and saved."
                : "Default theme selected and saved.",
            FALSE);
}

typedef struct {
    DeettyGridContext *context;
    uint32_t role;
} DeettyThemeColorControl;

static void set_theme_color_button_from_model(GtkColorButton *button,
                                              DeettyGridContext *context,
                                              uint32_t role) {
    uint32_t rgb = context->ui_color_rgb != NULL
        ? context->ui_color_rgb(context->event_data, role) : UINT32_MAX;
    if (rgb == UINT32_MAX) rgb = 0x000000;
    deetty_grid_color_chooser_set_rgb(
        button,
        deetty_grid_theme_color_channel(rgb, 0),
        deetty_grid_theme_color_channel(rgb, 1),
        deetty_grid_theme_color_channel(rgb, 2));
}

static void on_theme_color_control_destroy(GtkWidget *widget,
                                           gpointer user_data) {
    (void)widget;
    deetty_grid_memory_free(user_data);
}

static void on_theme_color_changed(GtkColorButton *button, gpointer user_data) {
    DeettyThemeColorControl *control = user_data;
    DeettyGridContext *context = root_grid_context(control->context);
    if (context->text_action == NULL) return;
    DeettyGridNativeHostPolicy policy = {0};
    deetty_grid_native_host_policy(&policy);
    double red = 0.0;
    double green = 0.0;
    double blue = 0.0;
    if (!deetty_grid_color_chooser_get_rgb(button, &red, &green, &blue))
        return;
    gchar value[8] = {0};
    if (deetty_grid_theme_color_text(
            red, green, blue,
            (uint8_t *)value, sizeof(value)) != 7)
        return;
    if (context->text_action(context->text_action_data, 20, value,
                             strlen(value), "", 0, (int)control->role) != 0) {
        set_theme_color_button_from_model(button, context, control->role);
        set_theme_library_status(
            context, "Theme color could not be saved; review the current value and retry.",
            TRUE);
        return;
    }
    set_theme_library_status(context, "Theme color saved.", FALSE);
    for (guint index = 0; context->contexts != NULL &&
         index < context->contexts->len; index++) {
        DeettyGridContext *candidate =
            g_ptr_array_index(context->contexts, index);
        if (!candidate->active || candidate->area == NULL) continue;
        deetty_grid_widget_queue_draw(candidate->area);
        update_compact_tab(candidate);
    }
    if (control->role == (uint32_t)policy.ui_color_pane_gap)
        apply_panel_layout_metrics(context);
}

static void theme_color_button_configure(DeettyGridContext *context,
                                         GtkWidget *button, uint32_t role) {
    if (button == NULL) return;
    set_theme_color_button_from_model(
        GTK_COLOR_BUTTON(button), root_grid_context(context), role);
    DeettyThemeColorControl *control = g_new0(DeettyThemeColorControl, 1);
    control->context = root_grid_context(context);
    control->role = role;
    deetty_grid_signal_connect(button, "color-set",
                     G_CALLBACK(on_theme_color_changed), control);
    deetty_grid_signal_connect(button, "destroy",
                     G_CALLBACK(on_theme_color_control_destroy), control);
}

static void apply_background_setting(DeettyGridContext *context,
                                     int event_code, int value) {
    DeettyGridContext *root = root_grid_context(context);
    apply_panel_metric_setting(context, event_code, value);
    if (root->window != NULL) deetty_grid_widget_queue_draw(root->window);
}

static void on_background_translucency_toggled(
    GtkToggleButton *toggle, gpointer user_data) {
    int enabled = deetty_grid_toggle_button_get_active(toggle);
    GtkWidget *opacity = deetty_grid_object_get_data(
        G_OBJECT(toggle), "deetty-background-opacity");
    DeettyGridContext *context = root_grid_context(user_data);
    if (opacity != NULL)
        deetty_grid_widget_set_sensitive(
            opacity, enabled && context->background_alpha_supported);
    apply_background_setting(
        context,
        deetty_grid_settings_event_code(
            DEETTY_GRID_SETTINGS_EVENT_BACKGROUND_TRANSLUCENCY),
        enabled);
}

static void on_background_opacity_changed(GtkRange *range,
                                          gpointer user_data) {
    apply_background_setting(
        user_data, deetty_grid_settings_event_code(
            DEETTY_GRID_SETTINGS_EVENT_BACKGROUND_OPACITY),
        deetty_grid_background_opacity_value(
            (int)round(deetty_grid_range_get_value(range))));
}

static void on_settings_family_changed(GtkComboBox *combo, gpointer user_data) {
    DeettyGridContext *context = user_data;
    int value = deetty_grid_combo_box_get_active(combo);
    gchar *family = deetty_grid_combo_box_text_get_active_text(GTK_COMBO_BOX_TEXT(combo));
    if (value < 0 || family == NULL) return;
    DeettyGridContext *root = root_grid_context(context);
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        DeettyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (g_strcmp0(candidate->font_family, family) == 0) continue;
        deetty_grid_memory_free(candidate->font_family);
        candidate->font_family = g_strdup(family);
        clear_ascii_glyph_cache(candidate);
        if (candidate->area != NULL) {
            GtkAllocation allocation;
            deetty_grid_widget_get_allocation(candidate->area, &allocation);
            resize_grid_to_allocation(candidate, &allocation);
            deetty_grid_widget_queue_draw(candidate->area);
        }
    }
    deetty_grid_memory_free(family);
    if (context->event != NULL)
        context->event(context->event_data, context->pane_id,
                       deetty_grid_settings_event_code(DEETTY_GRID_SETTINGS_EVENT_FONT_FAMILY), value,
                       (uint64_t)(g_get_monotonic_time() / 1000));
}

static void apply_font_rendering_setting(DeettyGridContext *context,
                                         int event_code, int value) {
    DeettyGridContext *root = root_grid_context(context);
    DeettyGridFontRenderingPlan plan = {0};
    deetty_grid_font_rendering_plan(event_code, value, &plan);
    if (!plan.valid) return;
    if (plan.target == DEETTY_GRID_FONT_RENDERING_TARGET_ANTIALIAS)
        root->font_antialias = plan.value;
    else
        root->font_hinting = plan.value;
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        DeettyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        clear_ascii_glyph_cache(candidate);
        if (candidate->active && candidate->area != NULL)
            deetty_grid_widget_queue_draw(candidate->area);
    }
    if (context->event != NULL)
        context->event(context->event_data, context->pane_id, event_code,
                       plan.value, (uint64_t)(g_get_monotonic_time() / 1000));
}

static void on_settings_antialias_changed(GtkComboBox *combo,
                                          gpointer user_data) {
    int value = deetty_grid_combo_box_get_active(combo);
    if (value >= 0) apply_font_rendering_setting(
        user_data, deetty_grid_settings_event_code(
            DEETTY_GRID_SETTINGS_EVENT_ANTIALIAS), value);
}

static void on_settings_hinting_changed(GtkComboBox *combo,
                                        gpointer user_data) {
    int value = deetty_grid_combo_box_get_active(combo);
    if (value >= 0) apply_font_rendering_setting(
        user_data, deetty_grid_settings_event_code(
            DEETTY_GRID_SETTINGS_EVENT_HINTING), value);
}
static void on_settings_renderer_changed(GtkComboBox *combo,
                                         gpointer user_data) {
    DeettyGridContext *context = user_data;
    int value = deetty_grid_combo_box_get_active(combo);
    if (value >= 0 && context->event != NULL)
        context->event(
            context->event_data, context->pane_id,
            deetty_grid_settings_event_code(
                DEETTY_GRID_SETTINGS_EVENT_RENDERER_BACKEND),
            value, (uint64_t)(g_get_monotonic_time() / 1000));
}

static void on_settings_shortcut_clicked(GtkButton *button, gpointer user_data) {
    (void)button;
    open_grid_shortcut_recorder(user_data);
}

static void sync_launch_profile_sensitivity(DeettyGridContext *context) {
    if (!deetty_grid_widget_is_type(context->settings_launch_kind, DEETTY_GTK_COMBO_BOX)) return;
    int kind = deetty_grid_combo_box_get_active(
        GTK_COMBO_BOX(context->settings_launch_kind));
    DeettyGridLaunchProfileControlsPlan controls = {0};
    deetty_grid_launch_profile_controls_plan(kind, &controls);
    if (context->settings_launch_command != NULL)
        deetty_grid_widget_set_sensitive(
            context->settings_launch_command, controls.command_sensitive != 0);
    if (context->settings_launch_ssh_target != NULL)
        deetty_grid_widget_set_sensitive(
            context->settings_launch_ssh_target,
            controls.ssh_target_sensitive != 0);
}

static void load_current_launch_profile(DeettyGridContext *context) {
    if (context->event_data == NULL) return;
    char shell[257] = {0};
    char command[1025] = {0};
    char cwd[4097] = {0};
    char environment[2049] = {0};
    char ssh_target[257] = {0};
    int kind = deetty_grid_launch_profile(
        context->event_data, 0, shell, sizeof(shell));
    (void)deetty_grid_launch_profile(context->event_data, 1, shell,
                                     sizeof(shell));
    (void)deetty_grid_launch_profile(context->event_data, 2, command,
                                     sizeof(command));
    (void)deetty_grid_launch_profile(context->event_data, 3, cwd,
                                     sizeof(cwd));
    (void)deetty_grid_launch_profile(context->event_data, 4, environment,
                                     sizeof(environment));
    (void)deetty_grid_launch_profile(context->event_data, 5, ssh_target,
                                     sizeof(ssh_target));
    int scrollback = deetty_grid_launch_profile(
        context->event_data, 6, shell, sizeof(shell));
    DeettyGridLaunchProfileControlsPlan controls = {0};
    deetty_grid_launch_profile_controls_plan(kind, &controls);
    deetty_grid_combo_box_set_active(
        GTK_COMBO_BOX(context->settings_launch_kind), controls.kind);
    deetty_grid_entry_set_text(GTK_ENTRY(context->settings_launch_shell), shell);
    deetty_grid_entry_set_text(GTK_ENTRY(context->settings_launch_command), command);
    deetty_grid_entry_set_text(GTK_ENTRY(context->settings_launch_cwd), cwd);
    deetty_grid_entry_set_text(GTK_ENTRY(context->settings_launch_environment),
                       environment);
    deetty_grid_entry_set_text(GTK_ENTRY(context->settings_launch_ssh_target),
                       ssh_target);
    deetty_grid_spin_button_set_value(
        GTK_SPIN_BUTTON(context->settings_launch_scrollback), scrollback);
    sync_launch_profile_sensitivity(context);
}

static void refresh_launch_profile_library(DeettyGridContext *context) {
    if (context->event_data == NULL ||
        !deetty_grid_widget_is_type(context->settings_launch_library, DEETTY_GTK_COMBO_BOX_TEXT))
        return;
    GtkComboBoxText *combo =
        GTK_COMBO_BOX_TEXT(context->settings_launch_library);
    char name[65] = {0};
    int count = deetty_grid_launch_profile_library(
        context->event_data, -1, 0, name, sizeof(name));
    int selected = deetty_grid_launch_profile_library(
        context->event_data, -2, 0, name, sizeof(name));
    deetty_grid_combo_box_text_remove_all(combo);
    deetty_grid_combo_box_text_append_text(combo, "Custom current");
    for (int index = 0; index < count; index++) {
        if (deetty_grid_launch_profile_library(
                context->event_data, index, 0, name, sizeof(name)) >= 0)
            deetty_grid_combo_box_text_append_text(combo, name);
    }
    deetty_grid_combo_box_set_active(GTK_COMBO_BOX(combo),
                             selected >= 0 ? selected + 1 : 0);
    if (deetty_grid_widget_is_type(context->settings_launch_name, DEETTY_GTK_ENTRY)) {
        name[0] = '\0';
        if (selected >= 0)
            (void)deetty_grid_launch_profile_library(
                context->event_data, selected, 0, name, sizeof(name));
        deetty_grid_entry_set_text(GTK_ENTRY(context->settings_launch_name), name);
    }
    deetty_grid_widget_set_sensitive(context->settings_launch_delete,
                                     selected >= 0);
}

static void on_settings_launch_kind_changed(GtkComboBox *combo,
                                            gpointer user_data) {
    (void)combo;
    sync_launch_profile_sensitivity(root_grid_context(user_data));
}

static int submit_settings_launch_profile(DeettyGridContext *context,
                                          int action,
                                          const char *name) {
    if (context->text_action == NULL ||
        !deetty_grid_widget_is_type(context->settings_launch_kind, DEETTY_GTK_COMBO_BOX) ||
        !deetty_grid_widget_is_type(context->settings_launch_shell, DEETTY_GTK_ENTRY) ||
        !deetty_grid_widget_is_type(context->settings_launch_command, DEETTY_GTK_ENTRY) ||
        !deetty_grid_widget_is_type(context->settings_launch_cwd, DEETTY_GTK_ENTRY) ||
        !deetty_grid_widget_is_type(context->settings_launch_environment, DEETTY_GTK_ENTRY) ||
        !deetty_grid_widget_is_type(context->settings_launch_ssh_target, DEETTY_GTK_ENTRY) ||
        !deetty_grid_widget_is_type(context->settings_launch_scrollback, DEETTY_GTK_SPIN_BUTTON))
        return -1;
    int raw_kind = deetty_grid_combo_box_get_active(
        GTK_COMBO_BOX(context->settings_launch_kind));
    DeettyGridLaunchProfileControlsPlan controls = {0};
    deetty_grid_launch_profile_controls_plan(raw_kind, &controls);
    int kind = controls.kind;
    const char *shell = deetty_grid_entry_get_text(
        GTK_ENTRY(context->settings_launch_shell));
    const char *command = deetty_grid_entry_get_text(
        GTK_ENTRY(context->settings_launch_command));
    const char *cwd = deetty_grid_entry_get_text(
        GTK_ENTRY(context->settings_launch_cwd));
    const char *environment = deetty_grid_entry_get_text(
        GTK_ENTRY(context->settings_launch_environment));
    const char *ssh_target = deetty_grid_entry_get_text(
        GTK_ENTRY(context->settings_launch_ssh_target));
    int scrollback = deetty_grid_spin_button_get_value_as_int(
        GTK_SPIN_BUTTON(context->settings_launch_scrollback));
    const char *profile_name = name != NULL ? name : "";
    const size_t profile_name_length = strlen(profile_name);
    const size_t shell_length = strlen(shell);
    const size_t command_length = strlen(command);
    const size_t cwd_length = strlen(cwd);
    const size_t ssh_target_length = strlen(ssh_target);
    const int payload_length = deetty_grid_launch_profile_payload(
        action,
        (const unsigned char *)profile_name, profile_name_length,
        (const unsigned char *)shell, shell_length,
        (const unsigned char *)command, command_length,
        (const unsigned char *)cwd, cwd_length,
        (const unsigned char *)ssh_target, ssh_target_length,
        scrollback, NULL, 0);
    if (payload_length <= 0) return -1;
    gchar *payload = g_malloc((gsize)payload_length + 1);
    if (payload == NULL) return -1;
    if (deetty_grid_launch_profile_payload(
            action,
            (const unsigned char *)profile_name, profile_name_length,
            (const unsigned char *)shell, shell_length,
            (const unsigned char *)command, command_length,
            (const unsigned char *)cwd, cwd_length,
            (const unsigned char *)ssh_target, ssh_target_length,
            scrollback, (unsigned char *)payload,
            (gsize)payload_length + 1) != payload_length) {
        deetty_grid_memory_free(payload);
        return -1;
    }
    int result = context->text_action(
        context->text_action_data, action, payload, (size_t)payload_length,
        environment, strlen(environment), kind);
    deetty_grid_memory_free(payload);
    return result;
}

static void set_launch_profile_status(
    DeettyGridContext *context, const char *message, gboolean error,
    GtkWidget *focus) {
    if (!deetty_grid_widget_is_type(context->settings_launch_status, DEETTY_GTK_LABEL)) return;
    deetty_grid_label_set_text(
        GTK_LABEL(context->settings_launch_status), message);
    deetty_grid_widget_set_visible(context->settings_launch_status, TRUE);
    context->launch_profile_feedback = message != NULL && message[0] != '\0';
    GtkStyleContext *style =
        deetty_grid_widget_get_style_context(context->settings_launch_status);
    if (error)
        deetty_grid_style_context_add_class(style, "error");
    else
        deetty_grid_style_context_remove_class(style, "error");
    AtkObject *accessible =
        deetty_grid_widget_get_accessible(context->settings_launch_status);
    if (accessible != NULL) {
        deetty_grid_atk_object_set_role(
            accessible, error ? ATK_ROLE_ALERT : ATK_ROLE_STATUSBAR);
        deetty_grid_atk_object_set_description(accessible, message);
        g_signal_emit_by_name(accessible, "visible-data-changed");
    }
    if (error && focus != NULL) deetty_grid_focus_widget(NULL, focus);
}

static void on_settings_launch_apply(GtkButton *button, gpointer user_data) {
    (void)button;
    DeettyGridContext *context = root_grid_context(user_data);
    if (submit_settings_launch_profile(context, 15, "") == 0) {
        context->launch_profile_setting_applied = 1;
        refresh_launch_profile_library(context);
        set_launch_profile_status(
            context,
            deetty_grid_launch_profile_status_message(0),
            FALSE, NULL);
    } else {
        set_launch_profile_status(
            context,
            deetty_grid_launch_profile_status_message(1),
            TRUE, context->settings_launch_kind);
    }
}

static void on_settings_launch_save(GtkButton *button, gpointer user_data) {
    (void)button;
    DeettyGridContext *context = root_grid_context(user_data);
    if (!deetty_grid_widget_is_type(context->settings_launch_name, DEETTY_GTK_ENTRY))
        return;
    const char *name = deetty_grid_entry_get_text(
        GTK_ENTRY(context->settings_launch_name));
    gboolean valid_name =
        deetty_grid_launch_profile_name_valid(
            (const unsigned char *)name,
            name != NULL ? strlen(name) : 0) != 0;
    if (!valid_name) {
        set_launch_profile_status(
            context,
            deetty_grid_launch_profile_status_message(3),
            TRUE, context->settings_launch_name);
        return;
    }
    if (submit_settings_launch_profile(context, 16, name) == 0) {
        context->launch_profile_setting_applied = 1;
        context->launch_profile_library_saved = 1;
        refresh_launch_profile_library(context);
        set_launch_profile_status(
            context,
            deetty_grid_launch_profile_status_message(2),
            FALSE, NULL);
    } else {
        set_launch_profile_status(
            context,
            deetty_grid_launch_profile_status_message(1),
            TRUE, context->settings_launch_kind);
    }
}

static void on_settings_launch_library_changed(GtkComboBox *combo,
                                               gpointer user_data) {
    DeettyGridContext *context = root_grid_context(user_data);
    int active = deetty_grid_combo_box_get_active(combo);
    if (active < 0 || context->text_action == NULL) return;
    if (active == 0) {
        if (submit_settings_launch_profile(context, 15, "") == 0) {
            context->launch_profile_setting_applied = 1;
            deetty_grid_entry_set_text(GTK_ENTRY(context->settings_launch_name), "");
            deetty_grid_widget_set_sensitive(context->settings_launch_delete, FALSE);
        }
        return;
    }
    int index = active - 1;
    if (context->text_action(context->text_action_data, 17, "", 0, "", 0,
                             index) != 0)
        return;
    context->launch_profile_library_selected = 1;
    char name[65] = {0};
    if (deetty_grid_launch_profile_library(context->event_data, index, 0,
                                           name, sizeof(name)) >= 0)
        deetty_grid_entry_set_text(GTK_ENTRY(context->settings_launch_name), name);
    deetty_grid_widget_set_sensitive(context->settings_launch_delete, TRUE);
    load_current_launch_profile(context);
}

static void on_settings_launch_delete(GtkButton *button, gpointer user_data) {
    (void)button;
    DeettyGridContext *context = root_grid_context(user_data);
    if (!deetty_grid_widget_is_type(context->settings_launch_library, DEETTY_GTK_COMBO_BOX) ||
        context->text_action == NULL)
        return;
    int active = deetty_grid_combo_box_get_active(
        GTK_COMBO_BOX(context->settings_launch_library));
    if (active <= 0) return;
    if (context->text_action(
            context->text_action_data, 18, "", 0, "", 0,
            active - 1) != 0) {
        set_launch_profile_status(
            context,
            deetty_grid_launch_profile_status_message(4),
            TRUE, context->settings_launch_library);
        return;
    }
    context->launch_profile_library_removed = 1;
    deetty_grid_entry_set_text(GTK_ENTRY(context->settings_launch_name), "");
    refresh_launch_profile_library(context);
    set_launch_profile_status(
        context,
        deetty_grid_launch_profile_status_message(5),
        FALSE, NULL);
}

static void open_grid_settings(DeettyGridContext *context) {
    DeettyGridContext *target = active_grid_context(context);
    (void)sync_grid_context_profile(target);
    context = root_grid_context(context);
    DeettyGridNativeHostPolicy policy = {0};
    deetty_grid_native_host_policy(&policy);
    if (context->settings_dialog != NULL) {
        deetty_grid_window_set_keep_above(context->settings_dialog, TRUE);
        present_configured_window(context->settings_dialog);
        return;
    }
    GtkWidget *dialog = deetty_dialog_new(
        GTK_WIDGET(context->window), "Configure DEETTY",
        GTK_DIALOG_DESTROY_WITH_PARENT, "_Close", GTK_RESPONSE_CLOSE,
        NULL, 0);
    (void)configure_overlay_window_stacking(
        context, dialog, "deetty-settings");
    GdkRectangle settings_workarea = {0, 0, 900, 680};
    GdkMonitor *settings_monitor = grid_monitor_for_window(context->window);
    if (settings_monitor != NULL)
        deetty_grid_gdk_monitor_get_workarea(settings_monitor, &settings_workarea);
    gboolean compact_settings = settings_workarea.width < 800;
    DeettyGridSettingsGeometryPlan settings_geometry = {0};
    deetty_grid_settings_geometry_plan(
        settings_workarea.width, settings_workarea.height,
        &settings_geometry);
    configure_overlay_window_geometry(
        context, dialog, &settings_workarea,
        settings_geometry.width, settings_geometry.height);
    deetty_grid_window_set_geometry_hints(
        dialog,
        settings_geometry.min_width,
        settings_geometry.min_height,
        settings_geometry.max_width,
        settings_geometry.max_height,
        GDK_HINT_MIN_SIZE | GDK_HINT_MAX_SIZE);
    deetty_grid_window_set_default_size(
        dialog, settings_geometry.width, settings_geometry.height);
    deetty_grid_window_resize(
        dialog, settings_geometry.width, settings_geometry.height);
    deetty_grid_window_set_position(dialog, GTK_WIN_POS_CENTER_ON_PARENT);
    deetty_grid_window_set_resizable(GTK_WIDGET(dialog), TRUE);
    deetty_grid_dialog_set_default_response(GTK_DIALOG(dialog), GTK_RESPONSE_CLOSE);


    char shortcut_button_label[128] = "Unknown — Change shortcut…";
    char shortcut_button_tooltip[256] = {0};
    DeettyGridShortcutTextPlan shortcut_text_plan = {0};
    (void)deetty_grid_shortcut_settings_text(
        context != NULL ? (uint32_t)context->requested_shortcut_key : 0,
        context != NULL && context->shortcut_transport == 1,
        (unsigned char *)shortcut_button_label,
        sizeof(shortcut_button_label),
        (unsigned char *)shortcut_button_tooltip,
        sizeof(shortcut_button_tooltip),
        &shortcut_text_plan);
    GtkWidget *shortcut =
        deetty_grid_button_new_with_label(shortcut_button_label);
    configure_grid_settings_shortcut_button(context, shortcut);
    int scrollback_lines = context->event_data != NULL
        ? deetty_grid_compact_setting(
            context->event_data, DEETTY_GRID_COMPACT_FIELD_SCROLLBACK) : 10000;
    const DeettySettingsCoreOptions core_options = {
        .shortcut = shortcut,
        .mode = context->mode,
        .dropdown_width = context->dropdown_width_percent,
        .dropdown_height = context->dropdown_height_percent,
        .animation_ms = context->dropdown_animation_ms,
        .hide_focus = context->hide_on_focus_loss,
        .focus_pointer = context->focus_follows_pointer,
        .notifications = context->enable_notifications,
        .preset = target->profile_preset,
        .scrollback = scrollback_lines,
        .scroll_lines = context->terminal_scroll_lines,
        .smooth_scroll = context->terminal_smooth_scroll,
        .compact = compact_settings,
    };
    DeettySettingsCoreContents core_contents = {0};
    if (!deetty_settings_core_contents_new(
            &core_options, &core_contents)) {
        deetty_grid_widget_destroy(dialog);
        return;
    }
    GtkWidget *window_page = core_contents.window_page;
    GtkWidget *behavior_page = core_contents.behavior_page;
    GtkWidget *behavior_page_body = core_contents.behavior_body;
    GtkWidget *mode = core_contents.mode;
    GtkWidget *dropdown_width = core_contents.dropdown_width;
    GtkWidget *dropdown_height = core_contents.dropdown_height;
    GtkWidget *animation = core_contents.animation;
    GtkWidget *hide_focus = core_contents.hide_focus;
    GtkWidget *focus_pointer = core_contents.focus_pointer;
    GtkWidget *notifications = core_contents.notifications;
    GtkWidget *preset = core_contents.preset;
    GtkWidget *scrollback = core_contents.scrollback;
    GtkWidget *scroll_lines = core_contents.scroll_lines;
    GtkWidget *smooth_scroll = core_contents.smooth_scroll;

    char launch_shell[257] = {0};
    char launch_command[1025] = {0};
    char launch_cwd[4097] = {0};
    char launch_environment[2049] = {0};
    char launch_ssh_target[257] = {0};
    int launch_kind_value = 0;
    int launch_scrollback_value = 10000;
    if (context->event_data != NULL) {
        launch_kind_value = deetty_grid_launch_profile(
            context->event_data, 0, launch_shell, sizeof(launch_shell));
        (void)deetty_grid_launch_profile(context->event_data, 1,
                                         launch_shell,
                                         sizeof(launch_shell));
        (void)deetty_grid_launch_profile(context->event_data, 2,
                                         launch_command,
                                         sizeof(launch_command));
        (void)deetty_grid_launch_profile(context->event_data, 3, launch_cwd,
                                         sizeof(launch_cwd));
        (void)deetty_grid_launch_profile(context->event_data, 4,
                                         launch_environment,
                                         sizeof(launch_environment));
        (void)deetty_grid_launch_profile(context->event_data, 5,
                                         launch_ssh_target,
                                         sizeof(launch_ssh_target));
        launch_scrollback_value = deetty_grid_launch_profile(
            context->event_data, 6, launch_shell, sizeof(launch_shell));
    }
    const DeettyLaunchProfileOptions launch_options = {
        .shell = launch_shell,
        .command = launch_command,
        .cwd = launch_cwd,
        .environment = launch_environment,
        .ssh_target = launch_ssh_target,
        .kind = launch_kind_value,
        .scrollback = launch_scrollback_value,
    };
    DeettyLaunchProfileContents launch_contents = {0};
    if (!deetty_launch_profile_contents_new(
            behavior_page_body, &launch_options, &launch_contents)) {
        deetty_grid_widget_destroy(dialog);
        return;
    }
    GtkWidget *launch_library = launch_contents.library;
    GtkWidget *launch_name_entry = launch_contents.name;
    GtkWidget *launch_kind = launch_contents.kind;
    GtkWidget *launch_shell_entry = launch_contents.shell;
    GtkWidget *launch_command_entry = launch_contents.command;
    GtkWidget *launch_cwd_entry = launch_contents.cwd;
    GtkWidget *launch_environment_entry = launch_contents.environment;
    GtkWidget *launch_ssh_entry = launch_contents.ssh_target;
    GtkWidget *launch_scrollback = launch_contents.scrollback;
    GtkWidget *launch_apply = launch_contents.apply;
    GtkWidget *launch_save = launch_contents.save;
    GtkWidget *launch_delete = launch_contents.delete_button;
    GtkWidget *launch_status = launch_contents.status;
    GtkWidget *notification_box =
        deetty_settings_notifications_box_new(notifications);
    if (notification_box == NULL) {
        deetty_grid_widget_destroy(dialog);
        return;
    }
    deetty_box_pack_start(
        behavior_page_body,
        settings_group_new("Notifications", notification_box),
        FALSE, FALSE, 0);

    GtkWidget *theme = deetty_theme_combo_new();
    populate_theme_combo(target, GTK_COMBO_BOX_TEXT(theme));
    GtkWidget *background_tint = deetty_color_button_new("Background tint");
    if (theme == NULL || background_tint == NULL) {
        deetty_grid_widget_destroy(dialog);
        return;
    }
    theme_color_button_configure(
        context, background_tint, (uint32_t)policy.ui_color_workspace_background);
    DeettyGridWorkspaceColor workspace_colors[17] = {0};
    for (guint index = 0; index < G_N_ELEMENTS(workspace_colors); index++)
        (void)deetty_grid_workspace_color((int)index, &workspace_colors[index]);
    GtkWidget *color_buttons[G_N_ELEMENTS(workspace_colors)] = {0};
    for (guint index = 0; index < G_N_ELEMENTS(workspace_colors); index++) {
        color_buttons[index] = deetty_color_button_new(
            workspace_colors[index].label);
        if (color_buttons[index] == NULL) {
            deetty_grid_widget_destroy(dialog);
            return;
        }
        theme_color_button_configure(
            context, color_buttons[index], workspace_colors[index].role);
    }
    int family_active = g_ascii_strcasecmp(
        target->font_family != NULL ? target->font_family : "Monospace",
        "JetBrains Mono") == 0 ? 1 : 0;
    const DeettySettingsAppearanceOptions appearance_options = {
        .theme = theme,
        .background_tint = background_tint,
        .color_buttons = color_buttons,
        .color_count = G_N_ELEMENTS(color_buttons),
        .tab_position = context->tab_position,
        .panel_padding = context->panel_padding_px,
        .pane_spacing = context->pane_spacing_px,
        .pane_gaps_enabled = context->pane_gaps_enabled,
        .pane_gaps_transparent = context->pane_gaps_transparent,
        .inactive_pane_dim_enabled = context->inactive_pane_dim_enabled,
        .inactive_pane_brightness_percent =
            context->inactive_pane_brightness_percent,
        .pane_divider = context->pane_divider_px,
        .pane_border = context->pane_border_px,
        .focused_border = context->pane_border_focused_px,
        .selected_border = context->pane_border_selected_px,
        .status_border = context->status_border_px,
        .overlay_border = context->overlay_border_px,
        .window_border = context->window_border_px,
        .dragger = context->dragger_px,
        .show_pane_info = context->show_pane_info,
        .family = family_active,
        .font_min = context->font_min_size,
        .font_max = context->font_max_size,
        .font_size = context->font_size,
        .antialias = context->font_antialias,
        .renderer_backend = context->event_data != NULL
            ? deetty_grid_compact_setting(context->event_data, 34)
            : context->renderer_backend,
        .translucency = context->background_translucency,
        .alpha_supported = context->background_alpha_supported,
        .opacity_percent = context->background_opacity_percent,
        .compact = compact_settings,
    };
    DeettySettingsAppearanceContents appearance = {0};
    if (!deetty_settings_appearance_contents_new(
            &appearance_options, &appearance)) {
        deetty_grid_widget_destroy(dialog);
        return;
    }
    GtkWidget *appearance_page = appearance.page;
    GtkWidget *tabs = appearance.tabs;
    GtkWidget *status = appearance.status;
    GtkWidget *padding = appearance.padding;
    GtkWidget *spacing = appearance.spacing;
    GtkWidget *pane_gaps_enabled = appearance.pane_gaps_enabled;
    GtkWidget *pane_gaps_transparent = appearance.pane_gaps_transparent;
    GtkWidget *inactive_pane_dim_enabled =
        appearance.inactive_pane_dim_enabled;
    GtkWidget *inactive_pane_brightness = appearance.inactive_pane_brightness;
    GtkWidget *theme_scope_tab = appearance.theme_scope_tab;
    GtkWidget *divider = appearance.divider;
    GtkWidget *pane_border = appearance.pane_border;
    GtkWidget *focused_border = appearance.focused_border;
    GtkWidget *selected_border = appearance.selected_border;
    GtkWidget *status_border = appearance.status_border;
    GtkWidget *overlay_border = appearance.overlay_border;
    GtkWidget *window_border = appearance.window_border;
    GtkWidget *dragger = appearance.dragger;
    GtkWidget *pane_info = appearance.pane_info;
    GtkWidget *theme_library = appearance.theme_library;
    GtkWidget *family = appearance.family;
    GtkWidget *font = appearance.font;
    GtkWidget *antialias = appearance.antialias;
    GtkWidget *hinting = appearance.hinting;
    GtkWidget *renderer = appearance.renderer;
    GtkWidget *translucency = appearance.translucency;
    GtkWidget *background_opacity = appearance.opacity;
    GtkWidget *transparency_status = appearance.transparency_status;
    deetty_grid_object_set_data(G_OBJECT(dialog), "deetty-settings-background-tint",
                      background_tint);
    deetty_grid_object_set_data(G_OBJECT(dialog), "deetty-settings-transparency-status",
                      transparency_status);

    DeettySettingsShellContents shell = {0};
    if (!deetty_settings_shell_new(
            dialog, compact_settings, window_page, behavior_page,
            appearance_page, &shell)) {
        deetty_grid_widget_destroy(dialog);
        return;
    }
    GtkWidget *categories = shell.categories;
    GtkWidget *stack = shell.stack;

    deetty_grid_object_set_data(G_OBJECT(dialog), "deetty-settings-mode", mode);
    deetty_grid_object_set_data(G_OBJECT(dialog), "deetty-settings-shortcut", shortcut);
    deetty_grid_object_set_data(G_OBJECT(dialog), "deetty-settings-width", dropdown_width);
    deetty_grid_object_set_data(G_OBJECT(dialog), "deetty-settings-height", dropdown_height);
    deetty_grid_object_set_data(G_OBJECT(dialog), "deetty-settings-animation", animation);
    deetty_grid_object_set_data(G_OBJECT(dialog), "deetty-settings-hide-focus", hide_focus);
    deetty_grid_object_set_data(G_OBJECT(dialog), "deetty-settings-focus-pointer", focus_pointer);
    deetty_grid_object_set_data(G_OBJECT(dialog), "deetty-settings-preset", preset);
    deetty_grid_object_set_data(G_OBJECT(dialog), "deetty-settings-scrollback", scrollback);
    deetty_grid_object_set_data(G_OBJECT(dialog), "deetty-settings-scroll-lines",
                      scroll_lines);
    deetty_grid_object_set_data(G_OBJECT(dialog), "deetty-settings-smooth-scroll",
                      smooth_scroll);
    deetty_grid_object_set_data(G_OBJECT(dialog), "deetty-settings-notifications", notifications);
    deetty_grid_object_set_data(G_OBJECT(dialog), "deetty-settings-tabs", tabs);
    deetty_grid_object_set_data(G_OBJECT(dialog), "deetty-settings-status", status);
    deetty_grid_object_set_data(G_OBJECT(dialog), "deetty-settings-padding", padding);
    deetty_grid_object_set_data(G_OBJECT(dialog), "deetty-settings-spacing", spacing);
    deetty_grid_object_set_data(G_OBJECT(dialog), "deetty-settings-pane-gaps",
                      pane_gaps_enabled);
    deetty_grid_object_set_data(G_OBJECT(dialog), "deetty-settings-gap-transparent",
                      pane_gaps_transparent);
    deetty_grid_object_set_data(G_OBJECT(dialog), "deetty-settings-inactive-dim",
                      inactive_pane_dim_enabled);
    deetty_grid_object_set_data(G_OBJECT(dialog), "deetty-settings-inactive-brightness",
                      inactive_pane_brightness);
    deetty_grid_object_set_data(G_OBJECT(dialog), "deetty-settings-theme-scope-tab",
                      theme_scope_tab);
    deetty_grid_object_set_data(G_OBJECT(theme), "deetty-theme-scope-tab",
                      theme_scope_tab);
    deetty_grid_object_set_data(G_OBJECT(dialog), "deetty-settings-divider", divider);
    deetty_grid_object_set_data(G_OBJECT(dialog), "deetty-settings-pane-border",
                      pane_border);
    deetty_grid_object_set_data(G_OBJECT(dialog), "deetty-settings-focused-border",
                      focused_border);
    deetty_grid_object_set_data(G_OBJECT(dialog), "deetty-settings-selected-border",
                      selected_border);
    deetty_grid_object_set_data(G_OBJECT(dialog), "deetty-settings-status-border",
                      status_border);
    deetty_grid_object_set_data(G_OBJECT(dialog), "deetty-settings-overlay-border",
                      overlay_border);
    deetty_grid_object_set_data(G_OBJECT(dialog), "deetty-settings-window-border",
                      window_border);
    deetty_grid_object_set_data(G_OBJECT(dialog), "deetty-settings-dragger", dragger);
    deetty_grid_object_set_data(G_OBJECT(dialog), "deetty-settings-theme", theme);
    deetty_grid_object_set_data(G_OBJECT(dialog), "deetty-settings-translucency",
                      translucency);
    deetty_grid_object_set_data(G_OBJECT(dialog), "deetty-settings-opacity",
                      background_opacity);
    deetty_grid_object_set_data(G_OBJECT(dialog), "deetty-settings-family", family);
    deetty_grid_object_set_data(G_OBJECT(dialog), "deetty-settings-font", font);
    deetty_grid_object_set_data(G_OBJECT(dialog), "deetty-settings-antialias", antialias);
    deetty_grid_object_set_data(G_OBJECT(dialog), "deetty-settings-hinting", hinting);
    deetty_grid_object_set_data(G_OBJECT(dialog), "deetty-settings-renderer", renderer);
    context->settings_dialog = dialog;
    context->settings_categories = categories;
    context->settings_stack = stack;
    context->settings_pane_info_toggle = pane_info;
    context->settings_launch_library = launch_library;
    context->settings_launch_name = launch_name_entry;
    context->settings_launch_kind = launch_kind;
    context->settings_launch_shell = launch_shell_entry;
    context->settings_launch_command = launch_command_entry;
    context->settings_launch_cwd = launch_cwd_entry;
    context->settings_launch_environment = launch_environment_entry;
    context->settings_launch_ssh_target = launch_ssh_entry;
    context->settings_launch_scrollback = launch_scrollback;
    context->settings_launch_apply = launch_apply;
    context->settings_launch_save = launch_save;
    context->settings_launch_delete = launch_delete;
    context->settings_launch_status = launch_status;
    context->pane_info_setting_control = deetty_grid_widget_is_type(pane_info, DEETTY_GTK_CHECK_BUTTON);
    context->launch_profile_setting_control =
        deetty_grid_widget_is_type(launch_kind, DEETTY_GTK_COMBO_BOX) &&
        deetty_grid_widget_is_type(launch_shell_entry, DEETTY_GTK_ENTRY) &&
        deetty_grid_widget_is_type(launch_command_entry, DEETTY_GTK_ENTRY) &&
        deetty_grid_widget_is_type(launch_cwd_entry, DEETTY_GTK_ENTRY) &&
        deetty_grid_widget_is_type(launch_environment_entry, DEETTY_GTK_ENTRY) &&
        deetty_grid_widget_is_type(launch_ssh_entry, DEETTY_GTK_ENTRY) &&
        deetty_grid_widget_is_type(launch_scrollback, DEETTY_GTK_SPIN_BUTTON) &&
        deetty_grid_widget_is_type(launch_apply, DEETTY_GTK_BUTTON);
    context->launch_profile_library_control =
        deetty_grid_widget_is_type(launch_library, DEETTY_GTK_COMBO_BOX) &&
        deetty_grid_widget_is_type(launch_name_entry, DEETTY_GTK_ENTRY) &&
        deetty_grid_widget_is_type(launch_save, DEETTY_GTK_BUTTON) &&
        deetty_grid_widget_is_type(launch_delete, DEETTY_GTK_BUTTON);
    refresh_launch_profile_library(context);
    GList *category_rows = deetty_grid_container_get_children(GTK_CONTAINER(categories));
    context->settings_category_count = (int)g_list_length(category_rows);
    g_list_free(category_rows);
    deetty_grid_signal_connect(categories, "row-selected",
                     G_CALLBACK(on_settings_category_selected), stack);
    deetty_grid_signal_connect(mode, "changed", G_CALLBACK(on_settings_mode_changed), target);
    deetty_grid_signal_connect(shortcut, "clicked", G_CALLBACK(on_settings_shortcut_clicked), target);
    deetty_grid_signal_connect(dropdown_width, "value-changed", G_CALLBACK(on_settings_dropdown_width_changed), target);
    deetty_grid_signal_connect(dropdown_height, "value-changed", G_CALLBACK(on_settings_dropdown_height_changed), target);
    deetty_grid_signal_connect(animation, "value-changed", G_CALLBACK(on_settings_animation_changed), target);
    deetty_grid_signal_connect(hide_focus, "toggled", G_CALLBACK(on_settings_hide_focus_toggled), target);
    deetty_grid_signal_connect(focus_pointer, "toggled", G_CALLBACK(on_settings_focus_pointer_toggled), target);
    deetty_grid_signal_connect(pane_info, "toggled", G_CALLBACK(on_settings_pane_info_toggled), target);
    deetty_grid_signal_connect(scrollback, "value-changed",
                     G_CALLBACK(on_settings_scrollback_changed), target);
    deetty_grid_signal_connect(scroll_lines, "value-changed",
                     G_CALLBACK(on_settings_scroll_lines_changed), target);
    deetty_grid_signal_connect(smooth_scroll, "toggled",
                     G_CALLBACK(on_settings_smooth_scroll_toggled), target);
    deetty_grid_signal_connect(launch_kind, "changed",
                     G_CALLBACK(on_settings_launch_kind_changed), context);
    deetty_grid_signal_connect(launch_library, "changed",
                     G_CALLBACK(on_settings_launch_library_changed), context);
    deetty_grid_signal_connect(launch_apply, "clicked",
                     G_CALLBACK(on_settings_launch_apply), context);
    deetty_grid_signal_connect(launch_save, "clicked",
                     G_CALLBACK(on_settings_launch_save), context);
    deetty_grid_signal_connect(launch_delete, "clicked",
                     G_CALLBACK(on_settings_launch_delete), context);
    deetty_grid_signal_connect(font, "value-changed", G_CALLBACK(on_settings_font_changed), target);
    deetty_grid_signal_connect(notifications, "toggled", G_CALLBACK(on_settings_notifications_toggled), target);
    deetty_grid_signal_connect(preset, "changed", G_CALLBACK(on_settings_preset_changed), target);
    deetty_grid_signal_connect(tabs, "changed", G_CALLBACK(on_settings_tabs_changed), target);
    deetty_grid_signal_connect(status, "changed", G_CALLBACK(on_settings_status_changed), target);
    GtkWidget *panel_metric_controls[] = {
        padding, spacing, divider, pane_border, focused_border,
        selected_border, status_border, overlay_border,
        window_border, dragger,
    };
    for (guint index = 0; index < G_N_ELEMENTS(panel_metric_controls); index++)
        deetty_grid_signal_connect(panel_metric_controls[index], "value-changed",
                         G_CALLBACK(on_settings_panel_metric_changed), target);
    deetty_grid_signal_connect(pane_gaps_enabled, "toggled",
                     G_CALLBACK(on_settings_panel_toggle), target);
    deetty_grid_signal_connect(pane_gaps_transparent, "toggled",
                     G_CALLBACK(on_settings_panel_toggle), target);
    deetty_grid_signal_connect(inactive_pane_dim_enabled, "toggled",
                     G_CALLBACK(on_settings_panel_toggle), target);
    deetty_grid_signal_connect(inactive_pane_brightness, "value-changed",
                     G_CALLBACK(on_settings_inactive_brightness_changed),
                     target);
    deetty_grid_signal_connect(theme, "changed", G_CALLBACK(on_settings_theme_changed), target);
    deetty_grid_signal_connect(theme_library, "clicked",
                     G_CALLBACK(on_open_theme_library_clicked), target);
    deetty_grid_signal_connect(translucency, "toggled",
                     G_CALLBACK(on_background_translucency_toggled), target);
    deetty_grid_signal_connect(background_opacity, "value-changed",
                     G_CALLBACK(on_background_opacity_changed), target);
    deetty_grid_signal_connect(family, "changed", G_CALLBACK(on_settings_family_changed), target);
    deetty_grid_signal_connect(antialias, "changed", G_CALLBACK(on_settings_antialias_changed), target);
    deetty_grid_signal_connect(hinting, "changed", G_CALLBACK(on_settings_hinting_changed), target);
    deetty_grid_signal_connect(renderer, "changed", G_CALLBACK(on_settings_renderer_changed), target);
    deetty_grid_signal_connect(dialog, "response", G_CALLBACK(on_settings_response), NULL);
    deetty_grid_signal_connect(dialog, "destroy", G_CALLBACK(on_settings_destroy), context);
    GtkListBoxRow *first = deetty_grid_list_box_get_row_at_index(
        GTK_LIST_BOX(categories), 0);
    deetty_grid_list_box_select_row(GTK_LIST_BOX(categories), first);
    show_all_with_action_affordances(dialog);
    sync_launch_profile_sensitivity(context);
    present_configured_window(dialog);
    gint rendered_width = 0;
    gint rendered_height = 0;
    deetty_grid_window_get_size(GTK_WINDOW(dialog), &rendered_width,
                        &rendered_height);
    context->settings_geometry_sane =
        rendered_width >= settings_geometry.min_width &&
        rendered_height >= settings_geometry.min_height &&
        rendered_width <= settings_geometry.max_width &&
        rendered_height <= settings_geometry.max_height;
    if (!context->settings_geometry_sane && context->workspace_smoke == 6) {
        g_printerr(
            "native_grid_settings_geometry workarea=%dx%d requested=%dx%d rendered=%dx%d bounds=%dx%d..%dx%d scale=%d\n",
            settings_workarea.width, settings_workarea.height,
            settings_geometry.width, settings_geometry.height,
            rendered_width, rendered_height,
            settings_geometry.min_width, settings_geometry.min_height,
            settings_geometry.max_width, settings_geometry.max_height,
            deetty_grid_widget_get_scale_factor(dialog));
    }
    if (first != NULL) deetty_grid_focus_widget(NULL, GTK_WIDGET(first));
}

static void on_settings_menu_activate(GtkWidget *item, gpointer user_data) {
    (void)item;
    open_grid_settings(user_data);
}

static void on_theme_import_clicked(GtkButton *button, gpointer user_data) {
    (void)button;
    DeettyGridContext *context = user_data;
    DeettyGridNativeHostPolicy policy = {0};
    deetty_grid_native_host_policy(&policy);
    GtkWidget *noctalia_variant = NULL;
    GtkWidget *chooser = deetty_theme_import_dialog_new(
        context->window, &noctalia_variant);
    if (chooser == NULL) {
        set_theme_library_status(
            context, "Could not open the theme import dialog.", TRUE);
        return;
    }
    prepare_action_button_tree(chooser);
    if (run_grid_modal_dialog(context, GTK_DIALOG(chooser)) ==
        GTK_RESPONSE_ACCEPT) {
        gchar *filename = deetty_grid_file_chooser_get_filename(GTK_FILE_CHOOSER(chooser));
        if (filename == NULL) {
            set_theme_library_status(
                context,
                "Could not read that theme. Choose a regular file up to 4 MiB.",
                TRUE);
        } else if (context->text_action != NULL) {
            int variant = deetty_grid_combo_box_get_active(
                GTK_COMBO_BOX(noctalia_variant));
            int result = context->text_action(
                context->text_action_data, 22, filename, strlen(filename),
                "", 0, variant);
            if (result == 0) {
                queue_theme_redraw(context);
                refresh_open_theme_selectors(context);
                set_theme_library_status(
                    context, "Theme imported, selected, and saved.", FALSE);
            } else if (result == policy.text_action_persistence_failed) {
                queue_theme_redraw(context);
                refresh_open_theme_selectors(context);
                set_theme_library_status(
                    context,
                    "Theme imported and selected for this session, but the selection could not be saved.",
                    TRUE);
            } else {
                set_theme_library_status(
                    context,
                    "Could not finish importing and saving that theme. Check its format, storage, and try again.",
                    TRUE);
            }
        }
        deetty_grid_memory_free(filename);
    }
    deetty_grid_widget_destroy(chooser);
}

static void queue_theme_redraw(DeettyGridContext *context) {
    DeettyGridContext *root = root_grid_context(context);
    root->high_contrast = 0;
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        DeettyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        candidate->high_contrast = 0;
        if (!candidate->active || candidate->area == NULL) continue;
        deetty_grid_widget_queue_draw(candidate->area);
        update_compact_tab(candidate);
    }
}

static void on_noctalia_current_theme_clicked(GtkButton *button,
                                               gpointer user_data) {
    (void)button;
    DeettyGridContext *context = user_data;
    DeettyGridNativeHostPolicy policy = {0};
    deetty_grid_native_host_policy(&policy);
    gchar *path = g_build_filename(
        g_get_user_config_dir(), "noctalia", "colors.json", NULL);
    int result = -1;
    if (path != NULL && context->text_action != NULL)
        result = context->text_action(
            context->text_action_data, 22, path, strlen(path), "", 0, 0);
    if (result == 0) {
        queue_theme_redraw(context);
        refresh_open_theme_selectors(context);
        set_theme_library_status(
            context, "Current Noctalia colors imported, selected, and saved.",
            FALSE);
    } else if (result == policy.text_action_persistence_failed) {
        queue_theme_redraw(context);
        refresh_open_theme_selectors(context);
        set_theme_library_status(
            context,
            "Current Noctalia colors are active for this session, but the selection could not be saved.",
            TRUE);
    } else {
        set_theme_library_status(
            context,
            "Could not import current Noctalia colors from colors.json.", TRUE);
    }
    deetty_grid_memory_free(path);
}

typedef struct {
    DeettyGridContext *context;
    GtkWidget *scheme;
    GtkWidget *variant;
    GtkWidget *status;
} DeettyNoctaliaThemeControls;

static guint populate_noctalia_scheme_combo(
    GtkComboBoxText *combo, DeettyGridContext *context) {
    if (context == NULL || context->text_action == NULL) return 0;
    gchar *root = g_build_filename(
        g_get_user_config_dir(), "noctalia", "colorschemes", NULL);
    if (root == NULL) return 0;
    const gsize capacity = 256 * 1024;
    gchar *records = g_malloc0(capacity);
    int length = context->text_action(
        context->text_action_data, 23, root, strlen(root),
        records, capacity, 0);
    if (length <= 0 || (gsize)length >= capacity) {
        deetty_grid_memory_free(records);
        deetty_grid_memory_free(root);
        return 0;
    }
    guint count = deetty_theme_library_append_noctalia_records(
        GTK_WIDGET(combo), records, (gsize)length);
    deetty_grid_memory_free(records);
    deetty_grid_memory_free(root);
    return count;
}

static void on_noctalia_theme_controls_destroy(GtkWidget *widget,
                                                gpointer user_data) {
    (void)widget;
    deetty_grid_memory_free(user_data);
}

static void on_noctalia_system_theme_clicked(GtkButton *button,
                                              gpointer user_data) {
    (void)button;
    DeettyNoctaliaThemeControls *controls = user_data;
    DeettyGridContext *context = root_grid_context(controls->context);
    DeettyGridNativeHostPolicy policy = {0};
    deetty_grid_native_host_policy(&policy);
    const gchar *path = deetty_grid_combo_box_get_active_id(
        GTK_COMBO_BOX(controls->scheme));
    gchar *label = deetty_grid_combo_box_text_get_active_text(
        GTK_COMBO_BOX_TEXT(controls->scheme));
    int variant = deetty_grid_combo_box_get_active(GTK_COMBO_BOX(controls->variant));
    if (path == NULL || label == NULL || variant < 0 ||
        context->text_action == NULL) {
        set_status_label_feedback(
            controls->status, "Select an installed Noctalia scheme.", TRUE);
        deetty_grid_memory_free(label);
        return;
    }
    int result = context->text_action(
        context->text_action_data, 22, path, strlen(path),
        label, strlen(label), variant + 1);
    if (result != 0 && result != policy.text_action_persistence_failed) {
        set_status_label_feedback(
            controls->status,
            "Could not finish importing and saving this Noctalia theme.", TRUE);
        deetty_grid_memory_free(label);
        return;
    }
    char message[4608] = {0};
    const gboolean persistence_failed =
        result == policy.text_action_persistence_failed;
    if (deetty_grid_theme_apply_status_text(
            persistence_failed,
            (const unsigned char *)label, strlen(label),
            variant, (unsigned char *)message, sizeof(message)) <= 0) {
        deetty_grid_memory_free(label);
        return;
    }
    set_status_label_feedback(
        controls->status, message, persistence_failed);
    queue_theme_redraw(context);
    refresh_open_theme_selectors(context);
    context->system_noctalia_theme_applied = 1;
    deetty_grid_memory_free(label);
}

static void on_open_theme_library_clicked(GtkButton *button,
                                          gpointer user_data) {
    (void)button;
    open_theme_library(user_data);
}

static void on_theme_library_destroy(GtkWidget *widget,
                                     gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    if (root->theme_dialog == widget) root->theme_dialog = NULL;
}

static void open_theme_library(DeettyGridContext *context) {
    DeettyGridContext *root = root_grid_context(context);
    if (deetty_grid_widget_is_type(root->theme_dialog, DEETTY_GTK_WINDOW)) {
        present_configured_window(root->theme_dialog);
        return;
    }
    GtkWidget *dialog = deetty_dialog_new(
        GTK_WIDGET(context->window), "DEETTY Theme Library",
        GTK_DIALOG_DESTROY_WITH_PARENT, "Close", GTK_RESPONSE_CLOSE,
        NULL, 0);
    root->theme_dialog = dialog;
    (void)configure_overlay_window_stacking(
        context, dialog, "deetty-theme-library");
    GtkWidget *themes = deetty_theme_combo_new();
    populate_theme_combo(context, GTK_COMBO_BOX_TEXT(themes));
    GtkWidget *noctalia_scheme = deetty_theme_combo_new();
    guint noctalia_count = populate_noctalia_scheme_combo(
        GTK_COMBO_BOX_TEXT(noctalia_scheme), context);
    DeettyThemeLibraryContents contents = {0};
    if (!deetty_theme_library_contents_new(
            dialog, themes, noctalia_scheme, noctalia_count, &contents)) {
        root->theme_dialog = NULL;
        deetty_grid_widget_destroy(dialog);
        return;
    }
    GtkWidget *noctalia_variant = contents.variant;
    GtkWidget *use_noctalia = contents.apply;
    GtkWidget *noctalia_status = contents.status;
    GtkWidget *import_noctalia = contents.import_current;
    GtkWidget *import = contents.import_file;
    DeettyNoctaliaThemeControls *noctalia_controls =
        g_new0(DeettyNoctaliaThemeControls, 1);
    noctalia_controls->context = root_grid_context(context);
    noctalia_controls->scheme = noctalia_scheme;
    noctalia_controls->variant = noctalia_variant;
    noctalia_controls->status = noctalia_status;
    root->system_noctalia_theme_listed = noctalia_count > 0;
    deetty_grid_signal_connect(themes, "changed", G_CALLBACK(on_settings_theme_changed), context);
    deetty_grid_signal_connect(use_noctalia, "clicked",
                     G_CALLBACK(on_noctalia_system_theme_clicked),
                     noctalia_controls);
    deetty_grid_signal_connect(use_noctalia, "destroy",
                     G_CALLBACK(on_noctalia_theme_controls_destroy),
                     noctalia_controls);
    deetty_grid_signal_connect(import_noctalia, "clicked",
                     G_CALLBACK(on_noctalia_current_theme_clicked), context);
    deetty_grid_signal_connect(import, "clicked", G_CALLBACK(on_theme_import_clicked), context);
    deetty_grid_signal_connect(dialog, "response", G_CALLBACK(deetty_grid_widget_destroy), NULL);
    deetty_grid_signal_connect(dialog, "destroy",
                     G_CALLBACK(on_theme_library_destroy), root);
    show_all_with_action_affordances(dialog);
}

static void on_theme_menu_activate(GtkWidget *item, gpointer user_data) {
    (void)item;
    open_theme_library(user_data);
}

static gboolean request_theme_smoke(gpointer user_data) {
    DeettyGridContext *context = user_data;
    open_theme_library(context);
    GtkWidget *import_variant = NULL;
    GtkWidget *import_dialog = deetty_theme_import_dialog_new(
        context->window, &import_variant);
    if (import_dialog != NULL && import_variant != NULL) {
        context->theme_import_dialog_built = 1;
        deetty_grid_widget_destroy(import_dialog);
    }
    DeettyGridContext *root = root_grid_context(context);
    GtkWidget *system_apply = root->theme_dialog != NULL
        ? deetty_grid_object_get_data(G_OBJECT(root->theme_dialog),
                            "deetty-system-noctalia-apply")
        : NULL;
    if (deetty_grid_widget_is_type(system_apply, DEETTY_GTK_BUTTON))
        deetty_grid_button_clicked(GTK_BUTTON(system_apply));
    GtkWidget *theme_status = root->theme_dialog != NULL
        ? deetty_grid_object_get_data(
              G_OBJECT(root->theme_dialog), "deetty-theme-status")
        : NULL;
    context->theme_visual_polish =
        root->theme_dialog != NULL &&
        deetty_grid_style_context_has_class(
            deetty_grid_widget_get_style_context(root->theme_dialog),
            "deetty-theme-dialog") &&
        theme_status != NULL &&
        deetty_grid_style_context_has_class(
            deetty_grid_widget_get_style_context(theme_status),
            "deetty-utility-status") &&
        system_apply != NULL &&
        deetty_grid_object_get_data(
            G_OBJECT(system_apply), "deetty-action-affordance") != NULL;
    const char *name = "Imported Night";
    const char *contents = "background = #000011\nforeground = #eeeeee\ncursor-color = #ff00aa\npalette = 1=#cc0000\n";
    if (context->text_action != NULL && context->text_action(context->text_action_data, 1, name, strlen(name), contents, strlen(contents), 0) == 0) context->theme_imported = 1;
    return G_SOURCE_REMOVE;
}

static gboolean confirm_grid_application_close(DeettyGridContext *context) {
    DeettyGridContext *root = root_grid_context(context);
    guint busy_count = foreground_process_count(root, NULL);
    return confirm_terminal_process_close(root, "application", busy_count,
                                          TRUE);
}

static gchar *find_nocted_binary(void) {
    GError *error = NULL;
    gchar *self_path = g_file_read_link("/proc/self/exe", &error);
    deetty_grid_error_clear(&error);
    if (self_path != NULL) {
        gchar *directory = g_path_get_dirname(self_path);
        gchar *candidate = g_build_filename(directory, "nocted", NULL);
        deetty_grid_memory_free(directory);
        deetty_grid_memory_free(self_path);
        if (g_file_test(candidate, G_FILE_TEST_IS_EXECUTABLE))
            return candidate;
        deetty_grid_memory_free(candidate);
    }
    return g_find_program_in_path("nocted");
}

static gboolean launch_nocted(DeettyGridContext *context,
                              const gchar *directory, gboolean smoke,
                              GError **error) {
    context->nocted_launch_attempted = 1;
    context->nocted_launch_succeeded = 0;
    context->nocted_process_separate = 0;
    context->nocted_directory_resolved = directory != NULL &&
        g_path_is_absolute(directory) &&
        g_file_test(directory, G_FILE_TEST_IS_DIR);
    gchar *binary = find_nocted_binary();
    if (binary == NULL) {
        g_set_error_literal(error, G_SPAWN_ERROR, G_SPAWN_ERROR_NOENT,
                            "Install the NoctEd binary beside DEETTY or on PATH.");
        return FALSE;
    }
    gchar *normal_argv[] = {binary, NULL};
    gchar *smoke_argv[] = {binary, "--version", NULL};
    gboolean launched = g_spawn_async(
        context->nocted_directory_resolved ? directory : NULL,
        smoke ? smoke_argv : normal_argv, NULL, G_SPAWN_DEFAULT,
        NULL, NULL, NULL, error);
    deetty_grid_memory_free(binary);
    context->nocted_launch_succeeded = launched;
    context->nocted_process_separate = launched;
    return launched;
}

static void show_nocted_launch_error(DeettyGridContext *context,
                                     const gchar *detail) {
    GtkWidget *dialog = deetty_error_dialog_new(
        GTK_WIDGET(context->window),
        "NoctEd could not be started",
        detail != NULL ? detail : "The standalone editor is unavailable.");
    (void)run_grid_modal_dialog(context, GTK_DIALOG(dialog));
    deetty_grid_widget_destroy(dialog);
}

static void open_editor_here(DeettyGridContext *context) {
    char path[4096];
    int length = deetty_grid_current_directory(
        context->userdata, context->event_data, context->pane_id, path,
        sizeof(path) - 1);
    gchar *directory = NULL;
    if (length > 0 && length < (int)sizeof(path)) {
        path[length] = '\0';
        directory = g_canonicalize_filename(path, NULL);
    } else {
        directory = g_get_current_dir();
    }
    GError *error = NULL;
    gboolean launched = launch_nocted(
        context, directory, context->workspace_smoke == 8, &error);
    context->editor_here_opened = launched;
    if (!launched && context->workspace_smoke != 8)
        show_nocted_launch_error(
            context, error != NULL ? error->message : NULL);
    deetty_grid_error_clear(&error);
    deetty_grid_memory_free(directory);
}

static void on_project_editor_open(GtkButton *button, gpointer user_data) {
    (void)button;
    open_editor_here(user_data);
}

static gboolean spawn_workspace_window(DeettyGridContext *context,
                                        const gchar *path,
                                        int restore_mode) {
    if (context == NULL || path == NULL || path[0] != '/') return FALSE;
    GError *error = NULL;
    gchar *executable = g_file_read_link("/proc/self/exe", &error);
    if (executable == NULL) {
        deetty_grid_error_clear(&error);
        return FALSE;
    }
    gchar restore_mode_text[32] = {0};
    if (deetty_grid_decimal_text(
            restore_mode, (unsigned char *)restore_mode_text,
            sizeof(restore_mode_text)) <= 0) {
        deetty_grid_memory_free(executable);
        return FALSE;
    }
    gchar *arguments[] = {
        executable,
        (gchar *)"--open-workspace",
        (gchar *)path,
        (gchar *)"--restore-mode",
        restore_mode_text,
        NULL,
    };
    gboolean launched = g_spawn_async(
        NULL, arguments, NULL, G_SPAWN_DEFAULT, NULL, NULL, NULL, &error);
    if (context->workspace_smoke == 35)
        context->recent_workspace_child_launched = launched;
    if (launched && context->text_action != NULL)
        (void)context->text_action(
            context->text_action_data, 19, path, strlen(path), "", 0, restore_mode);
    deetty_grid_error_clear(&error);
    deetty_grid_memory_free(executable);
    return launched;
}

static void on_project_recent_open(GtkButton *button, gpointer user_data) {
    DeettyGridContext *context = user_data;
    GtkWidget *combo = deetty_grid_object_get_data(
        G_OBJECT(button), "deetty-recent-workspace-combo");
    if (!deetty_grid_widget_is_type(combo, DEETTY_GTK_COMBO_BOX_TEXT)) return;
    gchar *path = deetty_grid_combo_box_text_get_active_text(
        GTK_COMBO_BOX_TEXT(combo));
    if (path != NULL && !spawn_workspace_window(context, path, 0)) {
        GtkWidget *dialog = deetty_error_dialog_new(
            GTK_WIDGET(context->window),
            "Could not open the selected workspace",
            "The workspace was not opened. Check that the file still exists and try again.");
        (void)run_grid_modal_dialog(context, GTK_DIALOG(dialog));
        deetty_grid_widget_destroy(dialog);
    }
    deetty_grid_memory_free(path);
}

static int choose_restore_mode(DeettyGridContext *context) {
    GtkWidget *dialog = deetty_dialog_new(
        GTK_WIDGET(context->window), "Restore Workspace",
        GTK_DIALOG_MODAL | GTK_DIALOG_DESTROY_WITH_PARENT,
        "Cancel", GTK_RESPONSE_CANCEL, "Restore", GTK_RESPONSE_ACCEPT);
    GtkWidget *combo = NULL;
    if (!deetty_restore_workspace_contents_new(dialog, &combo)) {
        deetty_grid_widget_destroy(dialog);
        return -1;
    }
    prepare_action_button_tree(dialog);
    int response = run_grid_modal_dialog(context, GTK_DIALOG(dialog));
    int mode = response == GTK_RESPONSE_ACCEPT
        ? deetty_grid_combo_box_get_active(GTK_COMBO_BOX(combo)) : -1;
    deetty_grid_widget_destroy(dialog);
    return mode;
}

static void choose_workspace_file(DeettyGridContext *context, int action) {
    GtkWidget *chooser = deetty_workspace_file_chooser_new(
        GTK_WIDGET(context->window), action == 2);
    if (chooser == NULL) return;
    prepare_action_button_tree(chooser);
    if (run_grid_modal_dialog(context, GTK_DIALOG(chooser)) ==
        GTK_RESPONSE_ACCEPT) {
        gchar *path = deetty_grid_file_chooser_get_filename(GTK_FILE_CHOOSER(chooser));
        if (path != NULL) {
            deetty_grid_widget_hide(chooser);
            if (action == 2 && context->text_action != NULL) {
                if (context->text_action(
                        context->text_action_data, action, path, strlen(path),
                        "", 0, 0) != 0) {
                    GtkWidget *dialog = deetty_error_dialog_new(
                        GTK_WIDGET(context->window),
                        "Could not save the workspace",
                        "The selected file was not changed. Check the path and permissions, then try again.");
                    (void)run_grid_modal_dialog(context, GTK_DIALOG(dialog));
                    deetty_grid_widget_destroy(dialog);
                }
            }
            else if (action == 3) {
                const int restore_mode = choose_restore_mode(context);
                if (restore_mode >= 0 &&
                    !spawn_workspace_window(context, path, restore_mode)) {
                    GtkWidget *dialog = deetty_error_dialog_new(
                        GTK_WIDGET(context->window),
                        "Could not restore the workspace",
                        "The workspace was not opened. Check the file and DEETTY installation, then try again.");
                    (void)run_grid_modal_dialog(context, GTK_DIALOG(dialog));
                    deetty_grid_widget_destroy(dialog);
                }
            }
        }
        deetty_grid_memory_free(path);
    }
    deetty_grid_widget_destroy(chooser);
}

static void on_project_workspace_save(GtkButton *button, gpointer user_data) { (void)button; choose_workspace_file(user_data, 2); }
static void on_project_workspace_open(GtkButton *button, gpointer user_data) { (void)button; choose_workspace_file(user_data, 3); }
static void on_project_destroy(GtkWidget *widget, gpointer user_data) {
    (void)widget;
    DeettyGridContext *context = user_data;
    context->project_dialog = NULL;
    context->recent_workspace_combo = NULL;
    context->recent_workspace_open = NULL;
}

static void open_project_tools(DeettyGridContext *context) {
    if (context->project_dialog != NULL) {
        present_configured_window(context->project_dialog);
        return;
    }
    /* Refresh project data only when the GUI surface that consumes it opens.
     * Background git subprocesses every ten seconds caused avoidable process
     * and descriptor churn throughout long terminal-only sessions. */
    if (context->event != NULL)
        context->event(context->event_data, context->pane_id, DEETTY_GRID_HOST_EVENT(PROJECT_TOOLS_OPENED), 0,
                       (uint64_t)(g_get_monotonic_time() / 1000));
    GtkWidget *dialog = deetty_dialog_new(
        GTK_WIDGET(context->window), "DEETTY Project Workspace",
        GTK_DIALOG_DESTROY_WITH_PARENT, "Close", GTK_RESPONSE_CLOSE,
        NULL, 0);
    (void)configure_overlay_window_stacking(
        context, dialog, "deetty-project-workspace");
    GdkRectangle project_workarea = {0, 0, 680, 520};
    GdkMonitor *project_monitor = grid_monitor_for_window(context->window);
    if (project_monitor != NULL)
        deetty_grid_gdk_monitor_get_workarea(project_monitor, &project_workarea);
    deetty_grid_window_set_default_size(
        dialog,
        deetty_grid_dialog_dimension(project_workarea.width, 680, 1, 32),
        deetty_grid_dialog_dimension(project_workarea.height, 520, 1, 32));
    deetty_grid_window_set_resizable(GTK_WIDGET(dialog), TRUE);
    char summary_text[4096] = "Project data unavailable";
    if (context->text_action != NULL) {
        int length = context->text_action(context->text_action_data, 6, "", 0,
                                          summary_text,
                                          sizeof(summary_text) - 1, 0);
        if (length >= 0 && length < (int)sizeof(summary_text))
            summary_text[length] = '\0';
    }
    DeettyProjectContents contents = {0};
    if (!deetty_project_contents_new(dialog, summary_text, &contents)) {
        deetty_grid_widget_destroy(dialog);
        return;
    }
    GtkWidget *save = contents.save;
    GtkWidget *open = contents.open;
    GtkWidget *recent_combo = contents.recent_combo;
    GtkWidget *recent_open = contents.recent_open;
    GtkWidget *editor = contents.editor;
    AtkObject *summary_accessible =
        deetty_grid_widget_get_accessible(contents.summary);
    AtkObject *recent_accessible = deetty_grid_widget_get_accessible(recent_combo);
    context->project_summary_scrollable =
        deetty_grid_widget_is_type(contents.summary_scroll, DEETTY_GTK_SCROLLED_WINDOW);
    context->project_summary_accessible = summary_accessible != NULL &&
        g_strcmp0(deetty_grid_atk_object_get_name(summary_accessible),
                  "Workspace summary") == 0 &&
        recent_accessible != NULL &&
        g_strcmp0(deetty_grid_atk_object_get_name(recent_accessible),
                  "Recent workspaces") == 0;
    context->project_visual_polish =
        deetty_grid_style_context_has_class(
            deetty_grid_widget_get_style_context(dialog),
            "deetty-project-dialog") &&
        deetty_grid_style_context_has_class(
            deetty_grid_widget_get_style_context(contents.summary_scroll),
            "deetty-utility-scroll") &&
        deetty_grid_style_context_has_class(
            deetty_grid_widget_get_style_context(contents.summary),
            "deetty-project-summary");
    int recent_count = context->event_data != NULL
        ? deetty_grid_recent_workspace(
              context->event_data, -1, summary_text, 0)
        : 0;
    int recent_added = 0;
    for (int index = 0; index < recent_count && index < 8; index++) {
        char path[4097] = {0};
        int length = deetty_grid_recent_workspace(
            context->event_data, index, path, sizeof(path) - 1);
        if (length <= 0 || length >= (int)sizeof(path)) continue;
        path[length] = '\0';
        deetty_grid_combo_box_text_append_text(recent_combo, path);
        recent_added++;
    }
    if (recent_added > 0)
        deetty_grid_combo_box_set_active(GTK_COMBO_BOX(recent_combo), 0);
    deetty_grid_widget_set_sensitive(recent_combo, recent_added > 0);
    deetty_grid_widget_set_sensitive(recent_open, recent_added > 0);
    context->recent_workspace_control = recent_added > 0 &&
        recent_added == recent_count;
    context->project_dialog = dialog;
    context->recent_workspace_combo = recent_combo;
    context->recent_workspace_open = recent_open;
    deetty_grid_signal_connect(save, "clicked", G_CALLBACK(on_project_workspace_save), context);
    deetty_grid_signal_connect(open, "clicked", G_CALLBACK(on_project_workspace_open), context);
    deetty_grid_object_set_data(G_OBJECT(recent_open),
                      "deetty-recent-workspace-combo", recent_combo);
    deetty_grid_signal_connect(recent_open, "clicked",
                     G_CALLBACK(on_project_recent_open), context);
    deetty_grid_signal_connect(editor, "clicked", G_CALLBACK(on_project_editor_open), context);
    deetty_grid_signal_connect(dialog, "response", G_CALLBACK(deetty_grid_widget_destroy), NULL);
    deetty_grid_signal_connect(dialog, "destroy", G_CALLBACK(on_project_destroy), context);
    show_all_with_action_affordances(dialog);
}

#if DEETTY_ENABLE_SMOKE
#include "../../tests/native_grid_activation_child_smoke.inc"
#endif

static void on_project_menu_activate(GtkWidget *item, gpointer user_data) { (void)item; open_project_tools(user_data); }

static GtkWidget *find_workspace_menu_item(GtkWidget *menu,
                                           const gchar *label) {
    if (!deetty_grid_widget_is_type(menu, DEETTY_GTK_CONTAINER)) return NULL;
    GList *items = deetty_grid_container_get_children(GTK_CONTAINER(menu));
    GtkWidget *match = NULL;
    for (GList *item = items; item != NULL && match == NULL;
         item = item->next) {
        if (!deetty_grid_widget_is_type(item->data, DEETTY_GTK_MENU_ITEM)) continue;
        const gchar *candidate = deetty_grid_menu_item_get_label(
            GTK_MENU_ITEM(item->data));
        if (g_strcmp0(candidate, label) == 0) {
            match = item->data;
            break;
        }
        GtkWidget *submenu = deetty_grid_menu_item_get_submenu(
            GTK_MENU_ITEM(item->data));
        if (submenu != NULL)
            match = find_workspace_menu_item(submenu, label);
    }
    g_list_free(items);
    return match;
}

static gboolean workspace_split_menu_has_order(GtkWidget *menu) {
    GtkWidget *split_parent = find_workspace_menu_item(menu, "Split Pane");
    if (split_parent == NULL) return FALSE;
    GtkWidget *split_menu = deetty_grid_menu_item_get_submenu(
        GTK_MENU_ITEM(split_parent));
    if (split_menu == NULL) return FALSE;
    const gchar *expected[] = {
        "Split Right", "Split Down", "Split Up", "Split Left",
    };
    GList *items = deetty_grid_container_get_children(GTK_CONTAINER(split_menu));
    gboolean matches = g_list_length(items) == (gint)G_N_ELEMENTS(expected);
    guint index = 0;
    for (GList *item = items; matches && item != NULL;
         item = item->next, index++) {
        if (!deetty_grid_widget_is_type(item->data, DEETTY_GTK_MENU_ITEM) ||
            g_strcmp0(deetty_grid_menu_item_get_label(GTK_MENU_ITEM(item->data)),
                      expected[index]) != 0)
            matches = FALSE;
    }
    g_list_free(items);
    return matches;
}

static gboolean finish_project_smoke(gpointer user_data) {
    DeettyGridContext *context = user_data;
    open_project_tools(context);
    gboolean project_ready = context->project_dialog != NULL &&
        deetty_grid_widget_get_mapped(context->project_dialog);
    if (!project_ready && context->project_smoke_attempts++ < 40) {
        deetty_grid_source_timeout_add(25, finish_project_smoke, context);
        return G_SOURCE_REMOVE;
    }
    context->project_smoke_attempts = 0;
    context->project_smoke_done = context->project_smoke_done &&
        context->context_menu_opened && context->context_menu_survived &&
        context->editor_here_opened && context->nocted_launch_attempted &&
        context->nocted_launch_succeeded && context->nocted_process_separate &&
        context->nocted_directory_resolved &&
        context->project_dialog != NULL &&
        context->project_summary_scrollable &&
        context->project_summary_accessible &&
        project_ready;
    if (context->write != NULL)
        (void)context->write(context->userdata, "done\n", 5);
    return G_SOURCE_REMOVE;
}

static gboolean continue_project_smoke(gpointer user_data) {
    DeettyGridContext *context = user_data;
    DeettyGridContext *root = root_grid_context(context);
    GtkWidget *menu = root->workspace_menu;
    gboolean menu_mapped = menu != NULL && deetty_grid_widget_get_mapped(menu) &&
        deetty_grid_widget_get_mapped(root->window) && root->window_presented;
    if (menu_mapped) root->context_menu_survived = 1;
    gboolean menu_ready = root->context_menu_survived && menu_mapped;
    GtkWidget *editor_item = menu_ready
        ? find_workspace_menu_item(menu, "Open NoctEd Here")
        : NULL;
    if (editor_item == NULL) {
        if (context->project_smoke_attempts++ < 80) {
            deetty_grid_source_timeout_add(25, continue_project_smoke, context);
            return G_SOURCE_REMOVE;
        }
        context->project_smoke_done = 0;
        return G_SOURCE_REMOVE;
    }
    deetty_grid_menu_shell_select_item(GTK_MENU_SHELL(menu), editor_item);
    deetty_grid_menu_shell_activate_item(GTK_MENU_SHELL(menu), editor_item, TRUE);
    context->project_smoke_attempts = 0;
    deetty_grid_source_timeout_add(250, finish_project_smoke, context);
    return G_SOURCE_REMOVE;
}

static gboolean wait_project_menu_mapped_smoke(gpointer user_data) {
    DeettyGridContext *context = user_data;
    DeettyGridContext *root = root_grid_context(context);
    GtkWidget *menu = root->workspace_menu;
    gboolean menu_mapped = menu != NULL && deetty_grid_widget_get_mapped(menu) &&
        deetty_grid_widget_get_mapped(root->window) && root->window_presented;
    if (!menu_mapped && context->project_smoke_attempts++ < 80) {
        deetty_grid_source_timeout_add(25, wait_project_menu_mapped_smoke, context);
        return G_SOURCE_REMOVE;
    }
    if (!menu_mapped) {
        context->project_smoke_attempts = 0;
        context->project_smoke_done = 0;
        return G_SOURCE_REMOVE;
    }
    context->project_smoke_attempts = 0;
    (void)on_window_focus_out(root->window, NULL, root);
    deetty_grid_source_timeout_add(180, continue_project_smoke, context);
    return G_SOURCE_REMOVE;
}

static gboolean request_project_smoke(gpointer user_data) {
    DeettyGridContext *context = user_data;
    DeettyGridContext *root = root_grid_context(context);
    gboolean surface_ready = root->window != NULL && context->area != NULL &&
        root->window_presented && deetty_grid_widget_get_mapped(root->window) &&
        deetty_grid_widget_get_mapped(context->area);
    if (!surface_ready && context->project_smoke_attempts++ < 200) {
        deetty_grid_source_timeout_add(25, request_project_smoke, context);
        return G_SOURCE_REMOVE;
    }
    if (!surface_ready) {
        context->project_smoke_attempts = 0;
        context->project_smoke_done = 0;
        return G_SOURCE_REMOVE;
    }
    const char *workspace = "/tmp/deetty-native-grid-project.deettyws";
    int ok = context->text_action != NULL;
    if (ok) ok = context->text_action(context->text_action_data, 2, workspace,
                                      strlen(workspace), "", 0, 0) == 0;
    if (ok) ok = context->text_action(context->text_action_data, 3, workspace,
                                      strlen(workspace), "", 0, 0) == 0;
    context->project_smoke_done = ok;
    context->project_smoke_attempts = 0;
    if (!ok) return G_SOURCE_REMOVE;
    (void)open_smoke_workspace_menu(context);
    deetty_grid_source_timeout_add(25, wait_project_menu_mapped_smoke, context);
    return G_SOURCE_REMOVE;
}

static gboolean compact_escape_closes(GtkWidget *widget, GdkEventKey *event,
                                      gpointer user_data) {
    (void)user_data;
    if (event->keyval != GDK_KEY_Escape) return FALSE;
    deetty_grid_widget_destroy(widget);
    return TRUE;
}

static void on_find_destroy(GtkWidget *widget, gpointer user_data) {
    (void)widget;
    DeettyGridContext *root = user_data;
    root->find_dialog = NULL;
    root->find_entry = NULL;
    root->find_status = NULL;
}

static void set_widget_accessible_name(GtkWidget *widget, const char *name) {
    AtkObject *accessible = deetty_grid_widget_get_accessible(widget);
    if (accessible != NULL) deetty_grid_atk_object_set_name(accessible, name);
}

static void set_status_label_feedback(GtkWidget *label, const char *message,
                                      gboolean is_error) {
    if (!deetty_grid_widget_is_type(label, DEETTY_GTK_LABEL) || message == NULL) return;
    AtkObject *accessible = deetty_grid_widget_get_accessible(label);
    AtkRole target_role = is_error ? ATK_ROLE_ALERT : ATK_ROLE_STATUSBAR;
    gboolean text_changed =
        g_strcmp0(deetty_grid_label_get_text(GTK_LABEL(label)), message) != 0;
    gboolean role_changed =
        accessible != NULL && deetty_grid_atk_object_get_role(accessible) != target_role;
    gboolean description_changed =
        accessible != NULL &&
        g_strcmp0(deetty_grid_atk_object_get_description(accessible), message) != 0;
    if (text_changed) deetty_grid_label_set_text(GTK_LABEL(label), message);
    if (accessible == NULL) return;
    if (role_changed) deetty_grid_atk_object_set_role(accessible, target_role);
    if (description_changed) deetty_grid_atk_object_set_description(accessible, message);
    if (text_changed || role_changed || description_changed)
        g_signal_emit_by_name(accessible, "visible-data-changed");
}

static gboolean widget_has_accessible_name(GtkWidget *widget,
                                           const char *name) {
    AtkObject *accessible = deetty_grid_widget_get_accessible(widget);
    const char *actual = accessible != NULL
        ? deetty_grid_atk_object_get_name(accessible) : NULL;
    return g_strcmp0(actual, name) == 0;
}

static void apply_terminal_find(DeettyGridContext *root) {
    if (root->find_dialog == NULL || root->find_entry == NULL) return;
    DeettyGridContext *target = deetty_grid_object_get_data(G_OBJECT(root->find_dialog),
                                                  "deetty-find-target");
    if (target == NULL) return;
    char status[96] = {0};
    const gchar *query = deetty_grid_entry_get_text(GTK_ENTRY(root->find_entry));
    if (query == NULL || query[0] == '\0') {
        target->selecting = 0;
        if (deetty_grid_find_status_text(
                0, 0, 0, (unsigned char *)status, sizeof(status)) <= 0)
            return;
        deetty_grid_label_set_text(GTK_LABEL(root->find_status), status);
        deetty_grid_widget_queue_draw(target->area);
        return;
    }
    int column = 0, row = 0, length = 0, matches = 0;
    int found = deetty_grid_find(target->userdata, query, strlen(query), 1,
                                 root->find_ordinal, &column, &row, &length,
                                 &matches);
    if (found == 1) {
        target->selection_start_column = column;
        target->selection_end_column =
            column + deetty_grid_selection_end(length);
        target->selection_start_row = row;
        target->selection_end_row = row;
        target->selection_dragging = 0;
        target->selecting = 1;
        if (deetty_grid_find_status_text(
                1,
                deetty_grid_search_display_ordinal(root->find_ordinal, matches),
                matches, (unsigned char *)status, sizeof(status)) <= 0)
            return;
        deetty_grid_label_set_text(GTK_LABEL(root->find_status), status);
    } else {
        target->selecting = 0;
        if (deetty_grid_find_status_text(
                2, 0, matches, (unsigned char *)status, sizeof(status)) <= 0)
            return;
        deetty_grid_label_set_text(GTK_LABEL(root->find_status), status);
    }
    deetty_grid_widget_queue_draw(target->area);
}

static void on_find_changed(GtkEditable *editable, gpointer user_data) {
    (void)editable;
    DeettyGridContext *root = user_data;
    root->find_ordinal = 0;
    apply_terminal_find(root);
}

static gboolean on_find_key(GtkWidget *widget, GdkEventKey *event,
                            gpointer user_data) {
    DeettyGridContext *root = user_data;
    if (event->keyval == GDK_KEY_Escape) {
        deetty_grid_widget_destroy(root->find_dialog);
        return TRUE;
    }
    if (event->keyval == GDK_KEY_Return || event->keyval == GDK_KEY_KP_Enter) {
        root->find_ordinal += 1;
        apply_terminal_find(root);
        return TRUE;
    }
    (void)widget;
    return FALSE;
}

static void open_terminal_find(DeettyGridContext *context) {
    DeettyGridContext *root = root_grid_context(context);
    if (root->find_dialog != NULL) {
        deetty_grid_object_set_data(G_OBJECT(root->find_dialog), "deetty-find-target", context);
        present_configured_window(root->find_dialog);
        deetty_grid_focus_widget(NULL, root->find_entry);
        return;
    }
    GdkRectangle workarea = {0, 0, 640, 360};
    GdkMonitor *monitor = grid_monitor_for_window(root->window);
    if (monitor != NULL) deetty_grid_gdk_monitor_get_workarea(monitor, &workarea);
    int dialog_width =
        deetty_grid_dialog_dimension(workarea.width, 640, 1, 32);
    int dialog_height = workarea.width < 600 ? 132 : 76;
    dialog_height = deetty_grid_dialog_dimension(
        workarea.height, dialog_height, 1, 32);
    GtkWidget *dialog = deetty_dialog_new(
        GTK_WIDGET(root->window), "", 0, NULL, 0, NULL, 0);
    DeettyFindContents contents = {0};
    if (!deetty_terminal_find_contents_new(
            dialog, dialog_width, workarea.width < 600, &contents)) {
        deetty_grid_widget_destroy(dialog);
        return;
    }
    GtkWidget *entry = contents.entry;
    GtkWidget *status = contents.status;
    (void)configure_overlay_window_stacking(
        root, dialog, "deetty-terminal-find");
    configure_overlay_window_geometry(
        root, dialog, &workarea, dialog_width, dialog_height);
    deetty_grid_window_set_default_size(dialog, dialog_width, dialog_height);
    deetty_grid_window_set_modal(dialog, TRUE);
    deetty_grid_window_set_decorated(GTK_WIDGET(dialog), FALSE);
    deetty_grid_window_set_position(dialog, GTK_WIN_POS_CENTER_ON_PARENT);
    deetty_grid_object_set_data(G_OBJECT(dialog), "deetty-find-target", context);
    root->find_dialog = dialog;
    root->find_entry = entry;
    root->find_status = status;
    root->find_ordinal = 0;
    root->compact_find_shown = 1;
    if (context->event != NULL) context->event(context->event_data, context->pane_id, DEETTY_GRID_HOST_EVENT(TERMINAL_FIND_OPENED), 0, (uint64_t)(g_get_monotonic_time() / 1000));
    deetty_grid_signal_connect(entry, "changed", G_CALLBACK(on_find_changed), root);
    deetty_grid_signal_connect(entry, "key-press-event", G_CALLBACK(on_find_key), root);
    deetty_grid_signal_connect(dialog, "destroy", G_CALLBACK(on_find_destroy), root);
    show_all_with_action_affordances(dialog);
    deetty_grid_focus_widget(NULL, entry);
}

static gboolean save_quick_note(DeettyGridContext *root) {
    if (root->note_load_failed) return TRUE;
    if (root->note_view == NULL || root->text_action == NULL) return FALSE;
    GtkTextBuffer *buffer = deetty_grid_text_view_get_buffer(GTK_TEXT_VIEW(root->note_view));
    GtkTextIter start, end;
    deetty_grid_text_buffer_get_bounds(buffer, &start, &end);
    gchar *text = deetty_grid_text_buffer_get_text(buffer, &start, &end, FALSE);
    gboolean saved = root->text_action(
        root->text_action_data, 9, "", 0, text, strlen(text), 0) == 0;
    deetty_grid_memory_free(text);
    set_status_label_feedback(
        root->note_status,
        saved ? "Workspace note · saved automatically"
              : "Workspace note · save failed; keep this window open",
        !saved);
    if (saved) root->compact_note_shown = 1;
    return saved;
}

static gboolean flush_quick_note(gpointer user_data) {
    DeettyGridContext *root = user_data;
    root->note_save_source = 0;
    (void)save_quick_note(root);
    return G_SOURCE_REMOVE;
}

static void on_quick_note_changed(GtkTextBuffer *buffer, gpointer user_data) {
    (void)buffer;
    DeettyGridContext *root = user_data;
    DeettyGridLifecycleTimingPlan timing = {0};
    deetty_grid_lifecycle_timing_plan(&timing);
    if (root->note_save_source != 0) deetty_grid_source_remove(root->note_save_source);
    root->note_save_source = deetty_grid_source_timeout_add(
        (guint)timing.quick_note_save_debounce_ms, flush_quick_note, root);
}

static void on_quick_note_destroy(GtkWidget *widget, gpointer user_data) {
    (void)widget;
    DeettyGridContext *root = user_data;
    if (root->note_save_source != 0) {
        deetty_grid_source_remove(root->note_save_source);
        root->note_save_source = 0;
        (void)save_quick_note(root);
    }
    root->note_dialog = NULL;
    root->note_view = NULL;
    root->note_status = NULL;
    root->note_load_failed = 0;
}

static void on_quick_note_response(GtkDialog *dialog, gint response,
                                   gpointer user_data) {
    (void)response;
    DeettyGridContext *root = user_data;
    if (root->note_save_source != 0) {
        deetty_grid_source_remove(root->note_save_source);
        root->note_save_source = 0;
    }
    if (save_quick_note(root)) deetty_grid_widget_destroy(GTK_WIDGET(dialog));
}

static gboolean on_quick_note_delete(GtkWidget *widget, GdkEvent *event,
                                     gpointer user_data) {
    (void)widget;
    (void)event;
    DeettyGridContext *root = user_data;
    if (root->note_save_source != 0) {
        deetty_grid_source_remove(root->note_save_source);
        root->note_save_source = 0;
    }
    return save_quick_note(root) ? FALSE : TRUE;
}

static gboolean on_quick_note_key(GtkWidget *widget, GdkEventKey *event,
                                  gpointer user_data) {
    if (event->keyval != GDK_KEY_Escape) return FALSE;
    on_quick_note_response(GTK_DIALOG(widget), GTK_RESPONSE_CLOSE, user_data);
    return TRUE;
}

static void open_quick_note(DeettyGridContext *context) {
    DeettyGridContext *root = root_grid_context(context);
    if (root->note_dialog != NULL) {
        present_configured_window(root->note_dialog);
        deetty_grid_focus_widget(NULL, root->note_view);
        return;
    }
    GdkRectangle workarea = {0, 0, 640, 480};
    GdkMonitor *monitor = grid_monitor_for_window(root->window);
    if (monitor != NULL) deetty_grid_gdk_monitor_get_workarea(monitor, &workarea);
    int dialog_width =
        deetty_grid_dialog_dimension(workarea.width, 600, 1, 32);
    int dialog_height =
        deetty_grid_dialog_dimension(workarea.height, 380, 1, 32);
    GtkWidget *dialog = deetty_dialog_new(
        GTK_WIDGET(root->window), "Quick Note",
        GTK_DIALOG_DESTROY_WITH_PARENT, "Close", GTK_RESPONSE_CLOSE,
        NULL, 0);
    (void)configure_overlay_window_stacking(
        root, dialog, "deetty-quick-note");
    configure_overlay_window_geometry(
        root, dialog, &workarea, dialog_width, dialog_height);
    deetty_grid_window_set_default_size(dialog, dialog_width, dialog_height);
    DeettyQuickNoteContents note_contents = {0};
    if (!deetty_quick_note_contents_new(
            dialog, dialog_width, dialog_height, &note_contents)) {
        deetty_grid_widget_destroy(dialog);
        return;
    }
    GtkWidget *view = note_contents.view;
    GtkWidget *hint = note_contents.status;
    root->note_dialog = dialog;
    root->note_view = view;
    root->note_status = hint;
    root->note_load_failed = 0;
    char *contents = g_malloc0(1024 * 1024 + 1);
    int length = root->text_action != NULL
        ? root->text_action(root->text_action_data, 8, "", 0, contents,
                            1024 * 1024, 0)
        : 0;
    if (length < 0) {
        root->note_load_failed = 1;
        deetty_grid_text_view_set_editable(GTK_TEXT_VIEW(view), FALSE);
        set_status_label_feedback(
            hint,
            "Workspace note could not be loaded; close this window and try again.",
            TRUE);
    } else {
        if (length > 0)
            deetty_grid_text_buffer_set_text(
                deetty_grid_text_view_get_buffer(GTK_TEXT_VIEW(view)), contents, length);
        set_status_label_feedback(
            hint, "Workspace note · saved automatically", FALSE);
    }
    deetty_grid_memory_free(contents);
    deetty_grid_signal_connect(deetty_grid_text_view_get_buffer(GTK_TEXT_VIEW(view)), "changed",
                     G_CALLBACK(on_quick_note_changed), root);
    deetty_grid_signal_connect(dialog, "response", G_CALLBACK(on_quick_note_response), root);
    deetty_grid_signal_connect(dialog, "delete-event", G_CALLBACK(on_quick_note_delete), root);
    deetty_grid_signal_connect(dialog, "key-press-event", G_CALLBACK(on_quick_note_key), root);
    deetty_grid_signal_connect(dialog, "destroy", G_CALLBACK(on_quick_note_destroy), root);
    deetty_grid_window_set_decorated(GTK_WIDGET(dialog), FALSE);
    show_all_with_action_affordances(dialog);
    deetty_grid_focus_widget(NULL, view);
}

static void on_shortcuts_destroy(GtkWidget *widget, gpointer user_data) {
    (void)widget;
    root_grid_context(user_data)->shortcuts_dialog = NULL;
}

static void open_shortcuts_overlay(DeettyGridContext *context) {
    DeettyGridContext *root = root_grid_context(context);
    if (root->shortcuts_dialog != NULL) {
        present_configured_window(root->shortcuts_dialog);
        return;
    }
    GdkRectangle workarea = {0, 0, 640, 560};
    GdkMonitor *monitor = grid_monitor_for_window(root->window);
    if (monitor != NULL) deetty_grid_gdk_monitor_get_workarea(monitor, &workarea);
    int dialog_width =
        deetty_grid_dialog_dimension(workarea.width, 620, 1, 32);
    int dialog_height =
        deetty_grid_dialog_dimension(workarea.height, 620, 1, 32);
    char shortcuts[4096] = {0};
    if (deetty_grid_shortcuts_text(
            root != NULL ? (uint32_t)root->requested_shortcut_key : 0,
            (unsigned char *)shortcuts, sizeof(shortcuts)) <= 0)
        return;
    GtkWidget *dialog = deetty_dialog_new(
        GTK_WIDGET(root->window), "DEETTY Shortcuts",
        GTK_DIALOG_DESTROY_WITH_PARENT, "Close", GTK_RESPONSE_CLOSE,
        NULL, 0);
    (void)configure_overlay_window_stacking(
        root, dialog, "deetty-shortcuts");
    configure_overlay_window_geometry(
        root, dialog, &workarea, dialog_width, dialog_height);
    deetty_grid_window_set_default_size(dialog, dialog_width, dialog_height);
    if (!deetty_shortcuts_contents_new(
            dialog, shortcuts, dialog_width, dialog_height)) {
        deetty_grid_widget_destroy(dialog);
        return;
    }
    root->shortcuts_dialog = dialog;
    deetty_grid_signal_connect(dialog, "response", G_CALLBACK(deetty_grid_widget_destroy), NULL);
    deetty_grid_signal_connect(dialog, "key-press-event", G_CALLBACK(compact_escape_closes), NULL);
    deetty_grid_signal_connect(dialog, "destroy", G_CALLBACK(on_shortcuts_destroy), root);
    deetty_grid_window_set_decorated(GTK_WIDGET(dialog), FALSE);
    show_all_with_action_affordances(dialog);
}

static gboolean save_grid_scrollback_to_path(DeettyGridContext *context,
                                             const gchar *path) {
    if (context->text_action == NULL || path == NULL) return FALSE;
    const size_t capacity = 4 * 1024 * 1024;
    char *contents = g_malloc(capacity);
    int length = deetty_grid_scrollback(context->userdata, contents, capacity);
    gboolean saved = length >= 0 &&
        context->text_action(context->text_action_data, 10, path, strlen(path),
                             contents, (size_t)MAX(0, length), 0) == 0;
    deetty_grid_memory_free(contents);
    if (saved) root_grid_context(context)->compact_scrollback_saved = 1;
    return saved;
}

static void save_grid_encrypted_history(DeettyGridContext *context) {
    GtkWidget *chooser = deetty_save_file_chooser_new(
        GTK_WIDGET(context->window),
        "Export Encrypted Screen History",
        "Export",
        "deetty-history.deettyhs");
    if (chooser == NULL) return;
    prepare_action_button_tree(chooser);
    if (run_grid_modal_dialog(context, GTK_DIALOG(chooser)) == GTK_RESPONSE_ACCEPT) {
        gchar *path = deetty_grid_file_chooser_get_filename(GTK_FILE_CHOOSER(chooser));
        GtkWidget *password_dialog = deetty_dialog_new(
            GTK_WIDGET(context->window), "Protect Screen History",
            GTK_DIALOG_MODAL | GTK_DIALOG_DESTROY_WITH_PARENT,
            "Cancel", GTK_RESPONSE_CANCEL, "Export", GTK_RESPONSE_ACCEPT);
        GtkWidget *entry = NULL;
        if (!deetty_history_password_contents_new(
                password_dialog, &entry)) {
            deetty_grid_widget_destroy(password_dialog);
            deetty_grid_memory_free(path);
            deetty_grid_widget_destroy(chooser);
            return;
        }
        prepare_action_button_tree(password_dialog);
        if (run_grid_modal_dialog(context, GTK_DIALOG(password_dialog)) == GTK_RESPONSE_ACCEPT) {
            const char *password = deetty_grid_entry_get_text(GTK_ENTRY(entry));
            if (deetty_grid_save_encrypted_history(
                    context->userdata, context->event_data, path, strlen(path),
                    password, strlen(password)) != 0) {
                GtkWidget *error_dialog = deetty_error_dialog_new(
                    GTK_WIDGET(context->window),
                    "Could not export encrypted screen history",
                    NULL);
                (void)run_grid_modal_dialog(context, GTK_DIALOG(error_dialog));
                deetty_grid_widget_destroy(error_dialog);
            }
        }
        deetty_grid_widget_destroy(password_dialog);
        deetty_grid_memory_free(path);
    }
    deetty_grid_widget_destroy(chooser);
}

static void set_agent_resume_reference(DeettyGridContext *context) {
    GtkWidget *dialog = deetty_dialog_new(
        GTK_WIDGET(context->window), "Register Agent Resume Reference",
        GTK_DIALOG_MODAL | GTK_DIALOG_DESTROY_WITH_PARENT,
        "Cancel", GTK_RESPONSE_CANCEL, "Register", GTK_RESPONSE_ACCEPT);
    GtkWidget *provider = NULL;
    GtkWidget *session = NULL;
    GtkWidget *label = NULL;
    if (!deetty_agent_resume_contents_new(
            dialog, &provider, &session, &label)) {
        deetty_grid_widget_destroy(dialog);
        return;
    }
    prepare_action_button_tree(dialog);
    if (run_grid_modal_dialog(context, GTK_DIALOG(dialog)) == GTK_RESPONSE_ACCEPT) {
        const char *session_id = deetty_grid_entry_get_text(GTK_ENTRY(session));
        const char *display_label = deetty_grid_entry_get_text(GTK_ENTRY(label));
        if (deetty_grid_set_agent_resume(
                context->event_data, context->pane_id,
                deetty_grid_combo_box_get_active(GTK_COMBO_BOX(provider)),
                session_id, strlen(session_id), display_label, strlen(display_label)) != 0) {
            GtkWidget *error_dialog = deetty_error_dialog_new(
                GTK_WIDGET(context->window),
                "Invalid agent resume reference",
                NULL);
            (void)run_grid_modal_dialog(context, GTK_DIALOG(error_dialog));
            deetty_grid_widget_destroy(error_dialog);
        }
        refresh_active_pane_info(context);
    }
    deetty_grid_widget_destroy(dialog);
}

static void clear_agent_resume_reference(DeettyGridContext *context) {
    if (deetty_grid_clear_agent_resume(
            context->event_data, context->pane_id) == 0) {
        refresh_active_pane_info(context);
        return;
    }
    GtkWidget *error_dialog = deetty_error_dialog_new(
        GTK_WIDGET(context->window),
        "Could not clear the agent resume reference",
        "The current reference was left unchanged. Try again after the pane is available.");
    (void)run_grid_modal_dialog(context, GTK_DIALOG(error_dialog));
    deetty_grid_widget_destroy(error_dialog);
}

static void save_grid_scrollback(DeettyGridContext *context) {
    GtkWidget *chooser = deetty_save_file_chooser_new(
        GTK_WIDGET(context->window),
        "Save Terminal Scrollback",
        "Save",
        "deetty-scrollback.txt");
    if (chooser == NULL) return;
    prepare_action_button_tree(chooser);
    if (run_grid_modal_dialog(context, GTK_DIALOG(chooser)) ==
        GTK_RESPONSE_ACCEPT) {
        gchar *path = deetty_grid_file_chooser_get_filename(GTK_FILE_CHOOSER(chooser));
        if (!save_grid_scrollback_to_path(context, path)) {
            GtkWidget *error_dialog = deetty_error_dialog_new(
                GTK_WIDGET(context->window),
                "Could not save terminal scrollback",
                "The selected file was not changed. Check the path and permissions, then try again.");
            (void)run_grid_modal_dialog(context, GTK_DIALOG(error_dialog));
            deetty_grid_widget_destroy(error_dialog);
        }
        deetty_grid_memory_free(path);
    }
    deetty_grid_widget_destroy(chooser);
}


static void on_palette_search_changed(GtkEditable *editable, gpointer user_data) {
    DeettyGridContext *root = user_data;
    const gchar *query = deetty_grid_entry_get_text(GTK_ENTRY(editable));
    GList *rows = deetty_grid_container_get_children(GTK_CONTAINER(root->palette_list));
    GtkListBoxRow *first_visible = NULL;
    for (GList *item = rows; item != NULL; item = item->next) {
        GtkWidget *row = item->data;
        const gchar *search = deetty_grid_object_get_data(G_OBJECT(row), "deetty-palette-search");
        gboolean visible = search != NULL &&
            deetty_grid_fuzzy_match_ascii(
                (const uint8_t *)search, (uint32_t)strlen(search),
                (const uint8_t *)query, (uint32_t)strlen(query)) != 0;
        deetty_grid_widget_set_visible(row, visible);
        if (visible && first_visible == NULL) first_visible = GTK_LIST_BOX_ROW(row);
    }
    g_list_free(rows);
    if (first_visible != NULL)
        deetty_grid_list_box_select_row(GTK_LIST_BOX(root->palette_list), first_visible);
}

static void accept_pending_agent_action(DeettyGridContext *context) {
    if (context->pending_notification_action == 1) {
        context->pending_notification_action = 0;
        acknowledge_grid_attention(context);
        activate_grid_context(context);
        return;
    }
    if (context->pending_notification_action == 2) {
        context->pending_notification_action = 0;
        acknowledge_grid_attention(context);
        open_project_tools(context);
    }
}

static void execute_palette_action(DeettyGridContext *context, int id) {
    DeettyGridPaletteDispatchPlan plan = {0};
    deetty_grid_palette_action_plan(
        id, context->high_contrast, context->tab_position, &plan);
    if (plan.valid == 0) return;
    switch (plan.action) {
    case DEETTY_GRID_PALETTE_DISPATCH_WORKSPACE_EVENT:
        emit_grid_workspace_event(context, plan.event_code);
        break;
    case DEETTY_GRID_PALETTE_DISPATCH_ZOOM:
        toggle_grid_zoom(context);
        break;
    case DEETTY_GRID_PALETTE_DISPATCH_FIND:
        open_terminal_find(context);
        break;
    case DEETTY_GRID_PALETTE_DISPATCH_NOTE:
        open_quick_note(context);
        break;
    case DEETTY_GRID_PALETTE_DISPATCH_BROADCAST:
        on_broadcast_menu_activate(NULL, context);
        break;
    case DEETTY_GRID_PALETTE_DISPATCH_SETTINGS:
        open_grid_settings(context);
        break;
    case DEETTY_GRID_PALETTE_DISPATCH_THEME:
        open_theme_library(context);
        break;
    case DEETTY_GRID_PALETTE_DISPATCH_PROJECT:
        open_project_tools(context);
        break;
    case DEETTY_GRID_PALETTE_DISPATCH_EDITOR:
        open_editor_here(context);
        break;
    case DEETTY_GRID_PALETTE_DISPATCH_SCROLLBACK:
        save_grid_scrollback(context);
        break;
    case DEETTY_GRID_PALETTE_DISPATCH_AGENT_SET:
        set_agent_resume_reference(context);
        break;
    case DEETTY_GRID_PALETTE_DISPATCH_AGENT_CLEAR:
        clear_agent_resume_reference(context);
        break;
    case DEETTY_GRID_PALETTE_DISPATCH_HISTORY:
        save_grid_encrypted_history(context);
        break;
    case DEETTY_GRID_PALETTE_DISPATCH_PENDING_AGENT:
        accept_pending_agent_action(context);
        break;
    case DEETTY_GRID_PALETTE_DISPATCH_SHORTCUTS:
        open_shortcuts_overlay(context);
        break;
    case DEETTY_GRID_PALETTE_DISPATCH_WINDOW:
        toggle_grid_window(context);
        break;
    case DEETTY_GRID_PALETTE_DISPATCH_SETTINGS_EVENT:
        if (plan.event_code == deetty_grid_settings_event_code(
                DEETTY_GRID_SETTINGS_EVENT_HIGH_CONTRAST)) {
            context->high_contrast = plan.value;
            if (context->event != NULL)
                context->event(
                    context->event_data, context->pane_id,
                    plan.event_code, plan.value,
                    (uint64_t)(g_get_monotonic_time() / 1000));
            deetty_grid_widget_queue_draw(context->area);
        } else if (plan.event_code == deetty_grid_settings_event_code(
                       DEETTY_GRID_SETTINGS_EVENT_TABS)) {
            if (context->event != NULL)
                context->event(
                    context->event_data, context->pane_id,
                    plan.event_code, plan.value,
                    (uint64_t)(g_get_monotonic_time() / 1000));
            apply_grid_tab_position(context, plan.value, TRUE);
        }
        break;
    case DEETTY_GRID_PALETTE_DISPATCH_RENAME: {
        DeettyGridContext *root = root_grid_context(context);
        gint page_index = deetty_grid_notebook_get_current_page(
            GTK_NOTEBOOK(root->notebook));
        GtkWidget *page = deetty_grid_notebook_get_nth_page(
            GTK_NOTEBOOK(root->notebook), page_index);
        open_tab_rename(root, page);
        break;
    }
    case DEETTY_GRID_PALETTE_DISPATCH_SMART_FILTER:
        on_smart_filter_button_clicked(NULL, context);
        break;
    case DEETTY_GRID_PALETTE_DISPATCH_TAG_SELECTED:
        on_tag_selected_menu_activate(NULL, context);
        break;
    case DEETTY_GRID_PALETTE_DISPATCH_TAG_REMOVE:
        on_tag_remove_menu_activate(NULL, context);
        break;
    case DEETTY_GRID_PALETTE_DISPATCH_TAB_COLOR:
        (void)adjust_active_tab_color(context, plan.value);
        break;
    default:
        break;
    }
}

static void on_palette_row_activated(GtkListBox *box, GtkListBoxRow *row,
                                     gpointer user_data) {
    (void)box;
    DeettyGridContext *root = user_data;
    DeettyGridContext *target = deetty_grid_object_get_data(G_OBJECT(root->palette_dialog),
                                                  "deetty-palette-target");
    int action = GPOINTER_TO_INT(deetty_grid_object_get_data(G_OBJECT(row),
                                                   "deetty-palette-action"));
    deetty_grid_widget_destroy(root->palette_dialog);
    if (target != NULL) execute_palette_action(target, action);
}

static void on_palette_search_activate(GtkEntry *entry, gpointer user_data) {
    (void)entry;
    DeettyGridContext *root = user_data;
    GtkListBoxRow *row = deetty_grid_list_box_get_selected_row(root->palette_list);
    if (row != NULL)
        on_palette_row_activated(GTK_LIST_BOX(root->palette_list), row, root);
}

static void on_palette_destroy(GtkWidget *widget, gpointer user_data) {
    (void)widget;
    DeettyGridContext *root = user_data;
    root->palette_dialog = NULL;
    root->palette_search = NULL;
    root->palette_list = NULL;
}

static void open_command_palette(DeettyGridContext *context) {
    DeettyGridContext *root = root_grid_context(context);
    if (root->palette_dialog != NULL) {
        deetty_grid_object_set_data(G_OBJECT(root->palette_dialog), "deetty-palette-target", context);
        present_configured_window(root->palette_dialog);
        deetty_grid_focus_widget(NULL, root->palette_search);
        return;
    }
    GdkRectangle workarea = {0, 0, 680, 460};
    GdkMonitor *monitor = grid_monitor_for_window(root->window);
    if (monitor != NULL) deetty_grid_gdk_monitor_get_workarea(monitor, &workarea);
    int dialog_width =
        deetty_grid_dialog_dimension(workarea.width, 660, 1, 32);
    int dialog_height =
        deetty_grid_dialog_dimension(workarea.height, 390, 1, 32);
    gboolean vertical_rows = workarea.width < 640;
    GtkWidget *dialog = deetty_dialog_new(
        GTK_WIDGET(root->window), "", 0, NULL, 0, NULL, 0);
    DeettyPaletteAction compact_actions[27] = {0};
    guint compact_action_count = deetty_grid_palette_actions(
        compact_actions, G_N_ELEMENTS(compact_actions));
    if (compact_action_count == 0) {
        deetty_grid_widget_destroy(dialog);
        return;
    }
    gchar *visibility_hint = grid_shortcut_label_alloc(root);
    DeettyPaletteContents contents = {0};
    gboolean contents_ready = deetty_command_palette_contents_new(
        dialog, dialog_width, dialog_height, vertical_rows,
        compact_actions, compact_action_count, visibility_hint,
        &contents);
    deetty_grid_memory_free(visibility_hint);
    if (!contents_ready) {
        deetty_grid_widget_destroy(dialog);
        return;
    }
    GtkWidget *search = contents.search;
    GtkWidget *list = contents.list;
    root->palette_dialog = dialog;
    root->palette_search = search;
    root->palette_list = list;
    root->compact_palette_shown = 1;
    deetty_grid_object_set_data(G_OBJECT(dialog), "deetty-palette-target", context);
    if (root->layer_shell_active)
        (void)configure_overlay_window_stacking(
            root, dialog, "deetty-command-palette");
    else
        deetty_grid_window_set_transient_for(dialog, root->window);
    configure_overlay_window_geometry(
        root, dialog, &workarea, dialog_width, dialog_height);
    deetty_grid_window_set_default_size(dialog, dialog_width, dialog_height);
    deetty_grid_window_set_modal(dialog, TRUE);
    deetty_grid_window_set_decorated(GTK_WIDGET(dialog), FALSE);
    deetty_grid_window_set_position(dialog, GTK_WIN_POS_CENTER_ON_PARENT);
    if (context->event != NULL) context->event(context->event_data, context->pane_id, DEETTY_GRID_HOST_EVENT(COMMAND_PALETTE_OPENED), 0, (uint64_t)(g_get_monotonic_time() / 1000));
    deetty_grid_signal_connect(search, "changed", G_CALLBACK(on_palette_search_changed), root);
    deetty_grid_signal_connect(search, "activate", G_CALLBACK(on_palette_search_activate), root);
    deetty_grid_signal_connect(dialog, "key-press-event", G_CALLBACK(compact_escape_closes), NULL);
    deetty_grid_signal_connect(dialog, "destroy", G_CALLBACK(on_palette_destroy), root);
    deetty_grid_signal_connect(list, "row-activated", G_CALLBACK(on_palette_row_activated), root);
    show_all_with_action_affordances(dialog);
    GtkListBoxRow *first = deetty_grid_list_box_get_row_at_index(GTK_LIST_BOX(list), 0);
    if (first != NULL) deetty_grid_list_box_select_row(GTK_LIST_BOX(list), first);
    deetty_grid_focus_widget(NULL, search);
}

#if DEETTY_ENABLE_SMOKE
#include "../../tests/native_grid_compact_ux_smoke.inc"
#include "../../tests/native_grid_zoom_smoke.inc"
#endif

static gboolean draw_sharing_preview(GtkWidget *widget, cairo_t *cr,
                                     gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    DeettyGridSharingPreviewResult result = {0};
    if (deetty_grid_render_sharing_preview(
            cr, root->event_data,
            deetty_grid_widget_get_allocated_width(widget),
            deetty_grid_widget_get_allocated_height(widget), &result)) {
        root->sharing_layout_pane_mask |= result.pane_mask;
        root->sharing_layout_selected_seen |= result.selected_seen;
        root->sharing_layout_host_active_seen |= result.host_active_seen;
    }
    return FALSE;
}

static gboolean on_sharing_preview_button(GtkWidget *widget,
                                          GdkEventButton *event,
                                          gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    int width = deetty_grid_widget_get_allocated_width(widget);
    int height = deetty_grid_widget_get_allocated_height(widget);
    uint64_t pane_id = 0;
    uint64_t tab_id = 0;
    int ignored = 0;
    int count = deetty_grid_share_view_stream(
        root->event_data, -1, NULL, 0, &pane_id, &tab_id, &ignored);
    if (event->button != GDK_BUTTON_PRIMARY || width <= 0 || height <= 0)
        return FALSE;
    for (int pane_index = 0; pane_index < count; pane_index++) {
        uint32_t x = 0;
        uint32_t y = 0;
        uint32_t pane_width = 0;
        uint32_t pane_height = 0;
        int selected = 0;
        int host_active = 0;
        if (deetty_grid_share_view_pane_layout(
                root->event_data, pane_index, &x, &y, &pane_width,
                &pane_height, &selected, &host_active) <= 0)
            continue;
        if (deetty_grid_sharing_pane_hit(
                event->x, event->y, width, height,
                (double)x, (double)y, (double)pane_width,
                (double)pane_height) == 0)
            continue;
        GtkComboBox *streams = root->sharing_dialog != NULL
            ? GTK_COMBO_BOX(deetty_grid_object_get_data(
                  G_OBJECT(root->sharing_dialog), "deetty-sharing-streams"))
            : NULL;
        char index_id[24] = {0};
        if (deetty_grid_sharing_index_text(
                pane_index, (uint8_t *)index_id, sizeof(index_id)) <= 0)
            continue;
        if (streams != NULL &&
            deetty_grid_combo_box_set_active_id(streams, index_id)) {
            deetty_grid_focus_widget(NULL, widget);
            return TRUE;
        }
        if (deetty_grid_share_view_select(root->event_data, pane_index) == 0) {
            deetty_grid_focus_widget(NULL, widget);
            deetty_grid_widget_queue_draw(widget);
            return TRUE;
        }
    }
    return FALSE;
}
static gboolean on_sharing_preview_scroll(
    GtkWidget *widget, GdkEventScroll *event, gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    double delta_y = 0.0;
    if (event->direction == GDK_SCROLL_SMOOTH)
        (void)deetty_grid_event_get_scroll_deltas(
            (GdkEvent *)event, &(double){0.0}, &delta_y);
    int lines = deetty_grid_sharing_preview_scroll_lines(
        (int)event->direction, delta_y);
    if (lines == 0 ||
        deetty_grid_share_view_scroll(root->event_data, lines) != 0)
        return FALSE;
    deetty_grid_widget_queue_draw(widget);
    return TRUE;
}


static gboolean send_sharing_input(
    DeettyGridContext *root, const uint8_t *bytes, size_t length) {
    if (bytes == NULL || length == 0) return FALSE;
    return deetty_grid_share_view_input(root->event_data, bytes, length) ==
           (int)length;
}


static void set_sharing_transient_feedback(
    DeettyGridContext *root, const char *text, gboolean is_error) {
    GtkWidget *dialog = root->sharing_dialog;
    if (!deetty_grid_widget_is_type(dialog, DEETTY_GTK_DIALOG) || deetty_grid_widget_in_destruction(dialog)) return;
    GtkWidget *status = deetty_grid_object_get_data(
        G_OBJECT(dialog), "deetty-sharing-status");
    if (deetty_grid_widget_is_type(status, DEETTY_GTK_LABEL))
        set_status_label_feedback(status, text, is_error);
    root->sharing_feedback_until_us =
        g_get_monotonic_time() + 3 * G_USEC_PER_SEC;
}

static void on_sharing_clipboard_text(
    GtkClipboard *clipboard, const gchar *text, gpointer user_data) {
    (void)clipboard;
    DeettyGridContext *root = root_grid_context(user_data);
    if (root->sharing_dialog == NULL || text == NULL || text[0] == '\0')
        return;
    const size_t text_length = strlen(text);
    if (deetty_grid_sharing_paste_allowed(text_length) == 0) {
        set_sharing_transient_feedback(
            root,
            "Paste was not sent because it exceeds the 64 KiB sharing limit.",
            TRUE);
        return;
    }
    uint8_t begin[6] = {0};
    uint8_t end[6] = {0};
    int begin_length = deetty_grid_bracketed_paste_marker(
        0, begin, sizeof(begin));
    int end_length = deetty_grid_bracketed_paste_marker(
        1, end, sizeof(end));
    gboolean bracketed =
        deetty_grid_share_view_bracketed_paste(root->event_data) != 0;
    gboolean began_bracketed_paste = FALSE;
    gboolean sent = TRUE;
    if (bracketed) {
        sent = begin_length > 0 &&
            send_sharing_input(root, begin, (size_t)begin_length);
        began_bracketed_paste = sent;
    }
    const uint8_t *next = (const uint8_t *)text;
    size_t remaining = text_length;
    while (sent && remaining > 0) {
        size_t count = deetty_grid_sharing_paste_chunk_size(remaining);
        sent = send_sharing_input(root, next, count);
        next += count;
        remaining -= count;
    }
    // If a chunk failed after bracketed paste began, still make a best-effort
    // attempt to leave the remote terminal's bracketed-paste mode.
    if (began_bracketed_paste &&
        (end_length <= 0 ||
         !send_sharing_input(root, end, (size_t)end_length)))
        sent = FALSE;
    if (!sent)
        set_sharing_transient_feedback(
            root,
            "Paste was not fully sent. Confirm remote control is granted and "
            "the connection is still active.",
            TRUE);
}

static gboolean on_sharing_preview_key(GtkWidget *widget, GdkEventKey *event,
                                       gpointer user_data) {
    (void)widget;
    DeettyGridContext *root = root_grid_context(user_data);
    gboolean shift = (event->state & GDK_SHIFT_MASK) != 0;
    gboolean control = (event->state & GDK_CONTROL_MASK) != 0;
    if ((control && shift && event->keyval == GDK_KEY_v) ||
        (shift && event->keyval == GDK_KEY_Insert)) {
        deetty_grid_clipboard_request_text(
            deetty_grid_clipboard_get(GDK_SELECTION_CLIPBOARD),
            on_sharing_clipboard_text,
            root);
        return TRUE;
    }

    uint8_t sequence[32] = {0};
    gboolean application_cursor =
        deetty_grid_share_view_cursor_mode(root->event_data) != 0;
    int sequence_length = deetty_grid_sharing_key_event_sequence(
        event->keyval,
        event->state,
        application_cursor,
        event->string != NULL && event->length > 0
            ? (const uint8_t *)event->string : NULL,
        event->length > 0 ? (size_t)event->length : 0,
        sequence,
        sizeof(sequence));
    if (sequence_length <= 0) return FALSE;
    const uint8_t *bytes = sequence;
    size_t length = (size_t)sequence_length;
    if (bytes == NULL || length == 0) return FALSE;
    if (send_sharing_input(root, bytes, length)) return TRUE;
    set_sharing_transient_feedback(
        root,
        "Input was not sent. Request control and wait for the host to grant "
        "this pane.",
        TRUE);
    return TRUE;
}

static int refresh_sharing_peers(DeettyGridContext *context) {
    DeettyGridContext *root = root_grid_context(context);
    GtkWidget *dialog = root->sharing_dialog;
    if (dialog == NULL) return 0;
    GtkComboBoxText *combo = GTK_COMBO_BOX_TEXT(deetty_grid_object_get_data(
        G_OBJECT(dialog), "deetty-sharing-peers"));
    if (combo == NULL) return 0;
    const char *active_id = deetty_grid_combo_box_get_active_id(GTK_COMBO_BOX(combo));
    char *previous_id = active_id != NULL ? g_strdup(active_id) : NULL;
    deetty_grid_combo_box_text_remove_all(combo);
    int count = deetty_grid_share_peer(root->event_data, -1, NULL, 0, NULL, 0,
                                       &(uint16_t){0}, &(int){0});
    int visible_count = 0;
    for (int index = 0; index < count; index++) {
        char alias[129] = {0};
        char endpoint[254] = {0};
        uint16_t port = 0;
        int revoked = 0;
        if (deetty_grid_share_peer(root->event_data, index, alias,
                                   sizeof(alias), endpoint, sizeof(endpoint),
                                   &port, &revoked) < 0)
            continue;
        if (revoked) continue;
        char label[512] = {0};
        if (deetty_grid_sharing_peer_label(
                (const unsigned char *)alias, strlen(alias),
                (const unsigned char *)endpoint, strlen(endpoint),
                port, (unsigned char *)label, sizeof(label)) <= 0)
            continue;
        char index_id[24] = {0};
        if (deetty_grid_decimal_text(
                index, (unsigned char *)index_id, sizeof(index_id)) <= 0) {
            deetty_grid_memory_free(label);
            continue;
        }
        deetty_grid_combo_box_text_append(combo, index_id, label);
        deetty_grid_memory_free(label);
        visible_count++;
    }
    if (previous_id == NULL ||
        !deetty_grid_combo_box_set_active_id(GTK_COMBO_BOX(combo), previous_id)) {
        if (visible_count > 0)
            deetty_grid_combo_box_set_active(GTK_COMBO_BOX(combo), 0);
    }
    deetty_grid_memory_free(previous_id);
    deetty_grid_object_set_data(G_OBJECT(dialog), "deetty-sharing-active-peer-count",
                      GINT_TO_POINTER(visible_count));
    return visible_count;
}

static int sharing_selected_peer_index(GtkComboBox *combo) {
    const char *active_id = combo != NULL
        ? deetty_grid_combo_box_get_active_id(combo)
        : NULL;
    return active_id == NULL
        ? -1
        : deetty_grid_sharing_index(
              (const uint8_t *)active_id, strlen(active_id));
}

static void refresh_sharing_streams(DeettyGridContext *context);

static void on_sharing_stream_changed(GtkComboBox *combo, gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    if (GPOINTER_TO_INT(deetty_grid_object_get_data(
            G_OBJECT(combo), "deetty-sharing-stream-refreshing")) != 0)
        return;
    const char *active_id = deetty_grid_combo_box_get_active_id(combo);
    if (active_id == NULL) return;
    int parsed = deetty_grid_sharing_index(
        (const uint8_t *)active_id, strlen(active_id));
    if (parsed < 0) return;
    if (deetty_grid_share_view_select(root->event_data, parsed) == 0 &&
        root->sharing_dialog != NULL) {
        GtkWidget *preview = deetty_grid_object_get_data(
            G_OBJECT(root->sharing_dialog), "deetty-sharing-preview");
        if (preview != NULL) deetty_grid_widget_queue_draw(preview);
    }
}

static void on_sharing_tab_changed(GtkComboBox *combo, gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    if (GPOINTER_TO_INT(deetty_grid_object_get_data(
            G_OBJECT(combo), "deetty-sharing-tab-refreshing")) != 0)
        return;
    int index = deetty_grid_combo_box_get_active(combo);
    if (index < 0) return;
    if (deetty_grid_share_view_select_tab(root->event_data, index) == 0) {
        root->sharing_stream_revision = 0;
        refresh_sharing_streams(root);
        if (root->sharing_dialog != NULL) {
            GtkWidget *preview = deetty_grid_object_get_data(
                G_OBJECT(root->sharing_dialog), "deetty-sharing-preview");
            if (preview != NULL) deetty_grid_widget_queue_draw(preview);
        }
    }
}

static void refresh_sharing_tabs(DeettyGridContext *context) {
    DeettyGridContext *root = root_grid_context(context);
    GtkWidget *dialog = root->sharing_dialog;
    if (dialog == NULL) return;
    GtkComboBoxText *combo = GTK_COMBO_BOX_TEXT(deetty_grid_object_get_data(
        G_OBJECT(dialog), "deetty-sharing-tabs"));
    if (combo == NULL) return;
    uint8_t ignored_title = 0;
    int count = deetty_grid_share_view_tab(
        root->event_data, -1, &ignored_title, 0, &(uint64_t){0}, &(int){0},
        &(int){0});
    deetty_grid_object_set_data(G_OBJECT(combo), "deetty-sharing-tab-refreshing",
                      GINT_TO_POINTER(1));
    deetty_grid_combo_box_text_remove_all(combo);
    int selected = -1;
    for (int index = 0; index < count; index++) {
        uint8_t title[4097] = {0};
        uint64_t tab_id = 0;
        int is_selected = 0;
        int is_active = 0;
        int title_length = deetty_grid_share_view_tab(
            root->event_data, index, title, sizeof(title) - 1u, &tab_id,
            &is_selected, &is_active);
        if (title_length < 0) continue;
        title[(size_t)title_length] = '\0';
        char label[4608] = {0};
        if (deetty_grid_sharing_tab_label(
                title, (size_t)title_length, tab_id, is_active,
                (unsigned char *)label, sizeof(label)) <= 0)
            continue;
        deetty_grid_combo_box_text_append_text(combo, label);
        if (is_selected) selected = index;
    }
    if (count > 0)
        deetty_grid_combo_box_set_active(GTK_COMBO_BOX(combo),
                                 selected >= 0 ? selected : 0);
    deetty_grid_object_set_data(G_OBJECT(combo), "deetty-sharing-tab-refreshing",
                      GINT_TO_POINTER(0));
}

static void refresh_sharing_streams(DeettyGridContext *context) {
    DeettyGridContext *root = root_grid_context(context);
    GtkWidget *dialog = root->sharing_dialog;
    if (dialog == NULL) return;
    GtkComboBoxText *combo = GTK_COMBO_BOX_TEXT(deetty_grid_object_get_data(
        G_OBJECT(dialog), "deetty-sharing-streams"));
    GtkComboBox *tabs = GTK_COMBO_BOX(deetty_grid_object_get_data(
        G_OBJECT(dialog), "deetty-sharing-tabs"));
    if (combo == NULL || tabs == NULL) return;
    uint64_t revision = deetty_grid_share_view_revision(root->event_data);
    if (revision == root->sharing_stream_revision) return;
    int tab_index = deetty_grid_combo_box_get_active(tabs);
    uint64_t selected_tab_id = 0;
    if (tab_index >= 0) {
        uint8_t ignored_tab_title = 0;
        if (deetty_grid_share_view_tab(
                root->event_data, tab_index, &ignored_tab_title, 0,
                &selected_tab_id, &(int){0}, &(int){0}) < 0)
            selected_tab_id = 0;
    }
    uint8_t ignored_title = 0;
    int count = deetty_grid_share_view_stream(
        root->event_data, -1, &ignored_title, 0, &(uint64_t){0},
        &(uint64_t){0}, &(int){0});
    deetty_grid_object_set_data(G_OBJECT(combo), "deetty-sharing-stream-refreshing",
                      GINT_TO_POINTER(1));
    deetty_grid_combo_box_text_remove_all(combo);
    char selected_id[24] = {0};
    int visible_count = 0;
    for (int index = 0; index < count; index++) {
        uint8_t title[4097] = {0};
        uint64_t pane_id = 0;
        uint64_t tab_id = 0;
        int is_selected = 0;
        int title_length = deetty_grid_share_view_stream(
            root->event_data, index, title, sizeof(title) - 1u, &pane_id,
            &tab_id, &is_selected);
        if (title_length < 0 || tab_id != selected_tab_id) continue;
        title[(size_t)title_length] = '\0';
        char label[4608] = {0};
        if (deetty_grid_sharing_pane_label(
                title, (size_t)title_length, pane_id,
                (unsigned char *)label, sizeof(label)) <= 0)
            continue;
        char index_id[24] = {0};
        if (deetty_grid_decimal_text(
                index, (unsigned char *)index_id, sizeof(index_id)) <= 0)
            continue;
        deetty_grid_combo_box_text_append(combo, index_id, label);
        visible_count++;
        if (is_selected)
            g_strlcpy(selected_id, index_id, sizeof(selected_id));
    }
    if (selected_id[0] != '\0')
        deetty_grid_combo_box_set_active_id(GTK_COMBO_BOX(combo), selected_id);
    else if (visible_count > 0)
        deetty_grid_combo_box_set_active(GTK_COMBO_BOX(combo), 0);
    deetty_grid_object_set_data(G_OBJECT(combo), "deetty-sharing-stream-refreshing",
                      GINT_TO_POINTER(0));
    root->sharing_stream_revision = revision;
}

static gboolean refresh_sharing_status(gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    GtkWidget *dialog = root->sharing_dialog;
    if (!deetty_grid_widget_is_type(dialog, DEETTY_GTK_DIALOG) || deetty_grid_widget_in_destruction(dialog)) {
        root->sharing_status_source = 0;
        return G_SOURCE_REMOVE;
    }
    GtkWidget *status_label = deetty_grid_object_get_data(
        G_OBJECT(dialog), "deetty-sharing-status");
    GtkWidget *pair_listen = deetty_grid_object_get_data(
        G_OBJECT(dialog), "deetty-sharing-pair-listen");
    GtkWidget *pair_connect = deetty_grid_object_get_data(
        G_OBJECT(dialog), "deetty-sharing-pair-connect");
    GtkWidget *discover = deetty_grid_object_get_data(
        G_OBJECT(dialog), "deetty-sharing-discover");
    GtkWidget *confirm = deetty_grid_object_get_data(
        G_OBJECT(dialog), "deetty-sharing-confirm");
    GtkWidget *cancel_pairing = deetty_grid_object_get_data(
        G_OBJECT(dialog), "deetty-sharing-cancel-pairing");
    GtkWidget *stop = deetty_grid_object_get_data(
        G_OBJECT(dialog), "deetty-sharing-stop");
    GtkWidget *grant = deetty_grid_object_get_data(
        G_OBJECT(dialog), "deetty-sharing-grant");
    GtkWidget *revoke = deetty_grid_object_get_data(
        G_OBJECT(dialog), "deetty-sharing-revoke");
    GtkWidget *stop_receive = deetty_grid_object_get_data(
        G_OBJECT(dialog), "deetty-sharing-stop-receive");
    GtkWidget *request_control = deetty_grid_object_get_data(
        G_OBJECT(dialog), "deetty-sharing-request-control");
    GtkWidget *reconnect = deetty_grid_object_get_data(
        G_OBJECT(dialog), "deetty-sharing-reconnect");
    GtkWidget *share_pane = deetty_grid_object_get_data(
        G_OBJECT(dialog), "deetty-sharing-share-pane");
    GtkWidget *share_tab = deetty_grid_object_get_data(
        G_OBJECT(dialog), "deetty-sharing-share-tab");
    GtkWidget *share_session = deetty_grid_object_get_data(
        G_OBJECT(dialog), "deetty-sharing-share-session");
    GtkWidget *revoke_device = deetty_grid_object_get_data(
        G_OBJECT(dialog), "deetty-sharing-revoke-device");
    GtkWidget *receive = deetty_grid_object_get_data(
        G_OBJECT(dialog), "deetty-sharing-receive");
    GtkWidget *retry_save = deetty_grid_object_get_data(
        G_OBJECT(dialog), "deetty-sharing-retry-save");
    GtkWidget *peers = deetty_grid_object_get_data(
        G_OBJECT(dialog), "deetty-sharing-peers");
    GtkWidget *preview = deetty_grid_object_get_data(
        G_OBJECT(dialog), "deetty-sharing-preview");
    GtkEntry *alias_entry = GTK_ENTRY(deetty_grid_object_get_data(
        G_OBJECT(dialog), "deetty-sharing-alias"));
    GtkEntry *endpoint_entry = GTK_ENTRY(deetty_grid_object_get_data(
        G_OBJECT(dialog), "deetty-sharing-endpoint"));
    GtkSpinButton *port_spin = GTK_SPIN_BUTTON(deetty_grid_object_get_data(
        G_OBJECT(dialog), "deetty-sharing-port"));
    uint32_t sas = 0;
    uint16_t port = 0;
    int status = deetty_grid_share_status(root->event_data, &sas, &port);
    char alias[129] = {0};
    char endpoint[254] = {0};
    uint16_t discovered_port = 0;
    int discovered = 0;
    if (status == 401 &&
        deetty_grid_share_discovered(
            root->event_data, alias, sizeof(alias), endpoint,
            sizeof(endpoint), &discovered_port) > 0) {
        discovered = 1;
        deetty_grid_entry_set_text(alias_entry, alias);
        deetty_grid_entry_set_text(endpoint_entry, endpoint);
        deetty_grid_spin_button_set_value(port_spin, discovered_port);
    }
    char text[256];
    DeettyGridSharingStatusTextPlan text_plan = {0};
    (void)deetty_grid_sharing_status_text(
        status, sas, port,
        (const unsigned char *)alias, strlen(alias),
        (const unsigned char *)endpoint, strlen(endpoint),
        discovered_port, discovered,
        (unsigned char *)text, sizeof(text), &text_plan);
    if (g_get_monotonic_time() >= root->sharing_feedback_until_us)
        set_status_label_feedback(status_label, text, text_plan.is_error);
    int known_count = GPOINTER_TO_INT(deetty_grid_object_get_data(
        G_OBJECT(dialog), "deetty-sharing-peer-count"));
    int current_count = deetty_grid_share_peer(root->event_data, -1, NULL, 0,
                                               NULL, 0, &(uint16_t){0},
                                               &(int){0});
    gboolean pairing_finished =
        root->sharing_last_status >= 101 &&
        root->sharing_last_status <= 105 &&
        (status == 0 || status == 106 || status == 107);
    if (current_count != known_count || pairing_finished) {
        refresh_sharing_peers(root);
        deetty_grid_object_set_data(G_OBJECT(dialog), "deetty-sharing-peer-count",
                          GINT_TO_POINTER(current_count));
    }
    int active_peer_count = GPOINTER_TO_INT(deetty_grid_object_get_data(
        G_OBJECT(dialog), "deetty-sharing-active-peer-count"));
    DeettyGridSharingControlPlan control_plan = {0};
    deetty_grid_sharing_control_plan(status, active_peer_count, &control_plan);
    deetty_grid_widget_set_sensitive(
        confirm,
        (control_plan.enabled & DEETTY_GRID_SHARING_CONTROL_CONFIRM) != 0);
    deetty_grid_widget_set_sensitive(
        pair_listen,
        (control_plan.enabled & DEETTY_GRID_SHARING_CONTROL_PAIRING) != 0);
    deetty_grid_widget_set_sensitive(
        pair_connect,
        (control_plan.enabled & DEETTY_GRID_SHARING_CONTROL_PAIRING) != 0);
    deetty_grid_widget_set_sensitive(
        discover,
        (control_plan.enabled & DEETTY_GRID_SHARING_CONTROL_DISCOVER) != 0);
    deetty_grid_widget_set_sensitive(
        share_pane,
        (control_plan.enabled & DEETTY_GRID_SHARING_CONTROL_SESSION) != 0);
    deetty_grid_widget_set_sensitive(
        share_tab,
        (control_plan.enabled & DEETTY_GRID_SHARING_CONTROL_SESSION) != 0);
    deetty_grid_widget_set_sensitive(
        share_session,
        (control_plan.enabled & DEETTY_GRID_SHARING_CONTROL_SESSION) != 0);
    deetty_grid_widget_set_sensitive(
        receive,
        (control_plan.enabled & DEETTY_GRID_SHARING_CONTROL_SESSION) != 0);
    deetty_grid_widget_set_sensitive(
        peers,
        (control_plan.enabled & DEETTY_GRID_SHARING_CONTROL_PEERS) != 0);
    deetty_grid_widget_set_sensitive(
        revoke_device,
        (control_plan.enabled & DEETTY_GRID_SHARING_CONTROL_REVOKE_DEVICE) != 0);
    deetty_grid_widget_set_sensitive(
        stop,
        (control_plan.enabled & DEETTY_GRID_SHARING_CONTROL_STOP) != 0);
    deetty_grid_widget_set_sensitive(
        cancel_pairing,
        (control_plan.enabled & DEETTY_GRID_SHARING_CONTROL_CANCEL_PAIRING) != 0);
    deetty_grid_widget_set_sensitive(
        grant,
        (control_plan.enabled & DEETTY_GRID_SHARING_CONTROL_GRANT) != 0);
    deetty_grid_widget_set_sensitive(
        revoke,
        (control_plan.enabled & DEETTY_GRID_SHARING_CONTROL_REVOKE) != 0);
    deetty_grid_widget_set_sensitive(
        stop_receive,
        (control_plan.enabled & DEETTY_GRID_SHARING_CONTROL_STOP_RECEIVE) != 0);
    deetty_grid_widget_set_sensitive(
        request_control,
        (control_plan.enabled & DEETTY_GRID_SHARING_CONTROL_REQUEST_CONTROL) != 0);
    deetty_grid_widget_set_sensitive(
        reconnect,
        (control_plan.enabled & DEETTY_GRID_SHARING_CONTROL_RECONNECT) != 0);
    deetty_grid_widget_set_sensitive(
        retry_save,
        (control_plan.enabled & DEETTY_GRID_SHARING_CONTROL_RETRY_SAVE) != 0);
    deetty_grid_button_set_label(
        GTK_BUTTON(stop),
        control_plan.stop_label == DEETTY_GRID_SHARING_LABEL_CLOSE_SHARING
            ? "Close sharing session"
            : "Stop sharing");
    deetty_grid_button_set_label(
        GTK_BUTTON(stop_receive),
        control_plan.stop_receive_label == DEETTY_GRID_SHARING_LABEL_CLOSE_REMOTE
            ? "Close remote session"
            : "Stop receiving");
    deetty_grid_button_set_label(
        GTK_BUTTON(revoke),
        control_plan.revoke_label == DEETTY_GRID_SHARING_LABEL_DENY_CONTROL
            ? "Deny control"
            : "Revoke control");
    deetty_grid_button_set_label(
        GTK_BUTTON(cancel_pairing),
        control_plan.cancel_pairing_label == DEETTY_GRID_SHARING_LABEL_CLEAR_PAIRING
            ? "Clear pairing result"
            : "Cancel pairing");
    if (deetty_grid_widget_is_type(preview, DEETTY_GTK_WIDGET) && !deetty_grid_widget_in_destruction(preview))
        deetty_grid_widget_queue_draw(preview);
    refresh_sharing_tabs(root);
    refresh_sharing_streams(root);
    root->sharing_last_status = status;
    return G_SOURCE_CONTINUE;
}

static void on_sharing_action(GtkButton *button, gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    GtkWidget *dialog = root->sharing_dialog;
    if (dialog == NULL) return;
    int action = GPOINTER_TO_INT(deetty_grid_object_get_data(
        G_OBJECT(button), "deetty-sharing-action"));
    GtkComboBox *peers = GTK_COMBO_BOX(deetty_grid_object_get_data(
        G_OBJECT(dialog), "deetty-sharing-peers"));
    GtkEntry *alias_entry = GTK_ENTRY(deetty_grid_object_get_data(
        G_OBJECT(dialog), "deetty-sharing-alias"));
    GtkEntry *endpoint_entry = GTK_ENTRY(deetty_grid_object_get_data(
        G_OBJECT(dialog), "deetty-sharing-endpoint"));
    GtkSpinButton *port_spin = GTK_SPIN_BUTTON(deetty_grid_object_get_data(
        G_OBJECT(dialog), "deetty-sharing-port"));
    const char *alias = deetty_grid_entry_get_text(alias_entry);
    const char *endpoint = deetty_grid_entry_get_text(endpoint_entry);
    uint16_t port = (uint16_t)deetty_grid_spin_button_get_value_as_int(port_spin);
    int peer_index = sharing_selected_peer_index(peers);
    if (action == 9 && peer_index >= 0) {
        gchar *peer_label = deetty_grid_combo_box_text_get_active_text(
            GTK_COMBO_BOX_TEXT(peers));
        char detail[512] = {0};
        const char *peer_name = peer_label != NULL
            ? peer_label : "The selected device";
        if (deetty_grid_sharing_revoke_detail(
                (const unsigned char *)peer_name, strlen(peer_name),
                (unsigned char *)detail, sizeof(detail)) <= 0) {
            deetty_grid_memory_free(peer_label);
            return;
        }
        GtkWidget *confirmation = deetty_message_dialog_new(
            GTK_WIDGET(dialog), GTK_MESSAGE_WARNING,
            "Revoke this paired device?", detail,
            "Keep Device", "Revoke Device");
        (void)configure_overlay_window_stacking(
            root, confirmation, "deetty-share-revoke-confirmation");
        show_all_with_action_affordances(confirmation);
        gint response = run_grid_modal_dialog(
            root, GTK_DIALOG(confirmation));
        deetty_grid_widget_destroy(confirmation);
        deetty_grid_memory_free(peer_label);
        if (response != GTK_RESPONSE_ACCEPT) return;
    }
    int result = deetty_grid_share_action(
            root->event_data, action, peer_index, alias, strlen(alias),
            endpoint, strlen(endpoint), port);
    if (action == 9) {
        refresh_sharing_peers(root);
        int current_count = deetty_grid_share_peer(
            root->event_data, -1, NULL, 0, NULL, 0,
            &(uint16_t){0}, &(int){0});
        deetty_grid_object_set_data(G_OBJECT(dialog), "deetty-sharing-peer-count",
                          GINT_TO_POINTER(current_count));
    }
    if (result < 0) {
        set_sharing_transient_feedback(
            root,
            result == -2
                ? "The change is active for this run but could not be saved. "
                  "Check configuration-directory permissions and retry."
                :
                "Sharing action failed. Check the selected device, endpoint, "
                "port, and current state.",
            TRUE);
        return;
    }
    root->sharing_feedback_until_us = 0;
    if (action == 10 || action == 17) {
        GtkWidget *preview = deetty_grid_object_get_data(
            G_OBJECT(dialog), "deetty-sharing-preview");
        deetty_grid_focus_widget(NULL, preview);
    }
    (void)refresh_sharing_status(root);
}

static void on_sharing_dialog_destroy(GtkWidget *dialog, gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    remove_grid_source(&root->sharing_status_source);
    // There is no separate persistent sharing indicator, so closing this
    // surface is the unambiguous fail-closed stop for every network role.
    // Keep host/viewer teardown idempotent: only the active action succeeds.
    (void)deetty_grid_share_action(root->event_data, 6, -1, "", 0, "", 0, 0);
    (void)deetty_grid_share_action(root->event_data, 11, -1, "", 0, "", 0, 0);
    (void)deetty_grid_share_action(root->event_data, 4, -1, "", 0, "", 0, 0);
    (void)deetty_grid_share_action(root->event_data, 14, -1, "", 0, "", 0, 0);
    root->sharing_stream_revision = 0;
    root->sharing_feedback_until_us = 0;
    root->sharing_last_status = 0;
    if (root->sharing_dialog == dialog) root->sharing_dialog = NULL;
}

static void show_session_sharing_dialog(DeettyGridContext *context) {
    DeettyGridContext *root = root_grid_context(context);
    if (root->sharing_dialog != NULL) {
        present_configured_window(root->sharing_dialog);
        return;
    }
    GtkWidget *dialog = deetty_dialog_new(
        GTK_WIDGET(root->window), "Session Sharing",
        GTK_DIALOG_DESTROY_WITH_PARENT, "_Close", GTK_RESPONSE_CLOSE,
        NULL, 0);
    root->sharing_dialog = dialog;
    GdkRectangle workarea = {0, 0, 900, 700};
    GdkMonitor *monitor = grid_monitor_for_window(root->window);
    if (monitor != NULL) deetty_grid_gdk_monitor_get_workarea(monitor, &workarea);
    int width =
        deetty_grid_dialog_dimension(workarea.width, 920, 480, 64);
    int height =
        deetty_grid_dialog_dimension(workarea.height, 760, 480, 64);
    width = deetty_grid_dialog_dimension(workarea.width, width, 1, 32);
    height = deetty_grid_dialog_dimension(workarea.height, height, 1, 32);
    configure_overlay_window_geometry(
        root, dialog, &workarea, width, height);
    deetty_grid_window_set_default_size(dialog, width, height);
    deetty_grid_window_set_resizable(GTK_WIDGET(dialog), TRUE);
    const DeettySharingCallbacks callbacks = {
        .action = G_CALLBACK(on_sharing_action),
        .tab_changed = G_CALLBACK(on_sharing_tab_changed),
        .stream_changed = G_CALLBACK(on_sharing_stream_changed),
        .preview_draw = G_CALLBACK(draw_sharing_preview),
        .preview_button = G_CALLBACK(on_sharing_preview_button),
        .preview_key = G_CALLBACK(on_sharing_preview_key),
        .preview_scroll = G_CALLBACK(on_sharing_preview_scroll),
    };
    if (!deetty_sharing_contents_new(
            dialog, width, height, root, &callbacks)) {
        root->sharing_dialog = NULL;
        deetty_grid_widget_destroy(dialog);
        return;
    }
    root->sharing_dialog_scrollable = TRUE;
    root->sharing_dialog_grouped_actions = TRUE;

    deetty_grid_signal_connect_swapped(dialog, "response",
                             G_CALLBACK(deetty_grid_widget_destroy), dialog);
    deetty_grid_signal_connect(dialog, "destroy",
                     G_CALLBACK(on_sharing_dialog_destroy), root);
    refresh_sharing_peers(root);
    deetty_grid_object_set_data(G_OBJECT(dialog), "deetty-sharing-peer-count",
                      GINT_TO_POINTER(deetty_grid_share_peer(
                          root->event_data, -1, NULL, 0, NULL, 0,
                          &(uint16_t){0}, &(int){0})));
    (void)refresh_sharing_status(root);
    DeettyGridLifecycleTimingPlan timing = {0};
    deetty_grid_lifecycle_timing_plan(&timing);
    if (root->sharing_status_source == 0)
        root->sharing_status_source =
            deetty_grid_source_timeout_add(
                (guint)timing.sharing_status_refresh_ms,
                refresh_sharing_status, root);
    deetty_grid_widget_show_all(dialog);
}

static void on_session_sharing_menu_activate(GtkMenuItem *item,
                                             gpointer user_data) {
    (void)item;
    show_session_sharing_dialog(user_data);
}
#if DEETTY_ENABLE_SMOKE
#include "../../tests/native_grid_sharing_scope_smoke.inc"
#endif

static gboolean request_window_close_button_smoke(gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    if (root->window_close_button != NULL)
        deetty_grid_button_clicked(GTK_BUTTON(root->window_close_button));
    return G_SOURCE_REMOVE;
}

static void mark_workspace_menu_action(GtkWidget *item) {
    GtkWidget *menu = deetty_grid_widget_get_ancestor(item, GTK_TYPE_MENU);
    while (deetty_grid_widget_is_type(menu, DEETTY_GTK_MENU)) {
        deetty_grid_object_set_data(G_OBJECT(menu), "deetty-workspace-action",
                          GINT_TO_POINTER(1));
        GtkWidget *attach = deetty_grid_menu_get_attach_widget(GTK_MENU(menu));
        menu = attach != NULL
            ? deetty_grid_widget_get_ancestor(attach, GTK_TYPE_MENU) : NULL;
    }
}

static void on_workspace_menu_activate(GtkWidget *item, gpointer user_data) {
    DeettyGridContext *context = user_data;
    mark_workspace_menu_action(item);
    int event_code = GPOINTER_TO_INT(deetty_grid_object_get_data(G_OBJECT(item), "deetty-workspace-event"));
    emit_grid_workspace_event(context, event_code);
}


static void on_broadcast_menu_activate(GtkWidget *item, gpointer user_data) {
    (void)item;
    DeettyGridContext *context = user_data;
    DeettyGridContext *root = root_grid_context(context);
    gboolean enabled = root->event_data != NULL &&
        deetty_grid_broadcast_enabled(root->event_data) != 0;
    if (enabled) {
        emit_grid_workspace_event(context, DEETTY_GRID_HOST_EVENT(WORKSPACE_BROADCAST));
        show_status_feedback(
            context,
            deetty_grid_status_feedback_message(
                DEETTY_GRID_FEEDBACK_BROADCAST_DISABLED));
        root->broadcast_disable_feedback = 1;
        if (root->workspace_smoke == 1)
            root->broadcast_disable_immediate =
                deetty_grid_broadcast_enabled(root->event_data) == 0;
        return;
    }

    GtkWidget *dialog = deetty_message_dialog_new(
        GTK_WIDGET(context->window), GTK_MESSAGE_WARNING,
        "Enable broadcast input?",
        "Each keystroke will be sent to every selected terminal, or every "
        "terminal in this tab when none are selected. Review the targets "
        "before continuing.",
        "Keep Off", "Enable Broadcast");
    prepare_action_button_tree(dialog);
    if (root->workspace_smoke == 1) {
        GtkWidget *cancel = deetty_grid_dialog_get_widget_for_response(
            dialog, GTK_RESPONSE_CANCEL);
        GtkWidget *accept = deetty_grid_dialog_get_widget_for_response(
            dialog, GTK_RESPONSE_ACCEPT);
        root->broadcast_confirmation_explicit =
            deetty_grid_widget_is_type(cancel, DEETTY_GTK_BUTTON) &&
            deetty_grid_widget_is_type(accept, DEETTY_GTK_BUTTON) &&
            g_strcmp0(deetty_grid_button_get_label(cancel),
                      "Keep Off") == 0 &&
            g_strcmp0(deetty_grid_button_get_label(accept),
                      "Enable Broadcast") == 0;
        root->broadcast_confirmation_cancel_default =
            deetty_grid_window_get_default_widget(dialog) == cancel;
        deetty_grid_source_idle_add(accept_dialog_smoke, dialog);
    }
    if (run_grid_modal_dialog(context, GTK_DIALOG(dialog)) ==
        GTK_RESPONSE_ACCEPT)
        emit_grid_workspace_event(context, DEETTY_GRID_HOST_EVENT(WORKSPACE_BROADCAST));
    deetty_grid_widget_destroy(dialog);
}

static void on_pane_close_menu_activate(GtkWidget *item, gpointer user_data) {
    DeettyGridContext *context = user_data;
    DeettyGridContext *root = root_grid_context(context);
    mark_workspace_menu_action(item);
    GtkWidget *menu = deetty_grid_widget_get_ancestor(item, GTK_TYPE_MENU);
    if (deetty_grid_widget_is_type(menu, DEETTY_GTK_MENU)) {
        deetty_grid_menu_popdown(GTK_MENU(menu));
        root->pane_close_menu_popped_down = 1;
    }
    (void)close_grid_pane(context);
}

static void on_terminal_menu_activate(GtkMenuItem *item,
                                      gpointer user_data) {
    DeettyGridContext *context = user_data;
    int action = GPOINTER_TO_INT(deetty_grid_object_get_data(
        G_OBJECT(item), "deetty-terminal-action"));
    DeettyGridTerminalMenuPlan plan = {0};
    deetty_grid_terminal_menu_plan(
        action, context->columns, context->rows, &plan);
    switch (plan.action) {
    case DEETTY_GRID_TERMINAL_MENU_ACTION_COPY:
        copy_grid_selection_to_clipboard(context);
        break;
    case DEETTY_GRID_TERMINAL_MENU_ACTION_PASTE:
        request_grid_clipboard_text(context);
        break;
    case DEETTY_GRID_TERMINAL_MENU_ACTION_SELECT_ALL:
        context->selecting = 1;
        context->selection_dragging = 0;
        context->selection_start_column = 0;
        context->selection_start_row = 0;
        context->selection_end_column = plan.selection_end_column;
        context->selection_end_row = plan.selection_end_row;
        deetty_grid_widget_queue_draw(context->area);
        break;
    case DEETTY_GRID_TERMINAL_MENU_ACTION_CLEAR_SELECTION:
        clear_grid_selection(context);
        break;
    case DEETTY_GRID_TERMINAL_MENU_ACTION_CLEAR_SCREEN:
        clear_grid_screen(context);
        break;
    case DEETTY_GRID_TERMINAL_MENU_ACTION_CLEAR_SCROLLBACK:
        clear_grid_scrollback(context);
        break;
    case DEETTY_GRID_TERMINAL_MENU_ACTION_RESET:
        reset_grid_terminal(context);
        break;
    default:
        break;
    }
}


static int populate_tag_suggestions(DeettyGridContext *context,
                                    GtkComboBoxText *combo) {
    DeettyGridContext *root = root_grid_context(context);
    char buffer[1024] = {0};
    int length = root->event_data != NULL
        ? deetty_grid_known_tags(root->event_data, buffer, sizeof(buffer) - 1)
        : 0;
    if (length <= 0) return 0;
    if ((size_t)length >= sizeof(buffer)) length = (int)sizeof(buffer) - 1;
    buffer[length] = '\0';
    gchar **tags = g_strsplit(buffer, "\n", -1);
    int count = 0;
    for (gchar **tag = tags; tag != NULL && *tag != NULL; tag++) {
        if ((*tag)[0] == '\0') continue;
        deetty_grid_combo_box_text_append_text(combo, *tag);
        count++;
    }
    g_strfreev(tags);
    return count;
}

static gchar *run_tag_entry_dialog(DeettyGridContext *context, const gchar *title,
                                   const gchar *value, gboolean allow_empty) {
    GtkWidget *dialog = deetty_dialog_new(
        GTK_WIDGET(root_grid_context(context)->window), title,
        GTK_DIALOG_MODAL, "Cancel", GTK_RESPONSE_CANCEL,
        "Apply", GTK_RESPONSE_OK);
    GtkWidget *content = deetty_grid_dialog_get_content_area(GTK_DIALOG(dialog));
    GtkWidget *combo = deetty_tag_combo_new();
    if (combo == NULL) {
        deetty_grid_widget_destroy(dialog);
        return NULL;
    }
    GtkWidget *entry = deetty_grid_bin_get_child(GTK_BIN(combo));
    if (value != NULL) deetty_grid_entry_set_text(GTK_ENTRY(entry), value);
    int suggestion_count = populate_tag_suggestions(context, GTK_COMBO_BOX_TEXT(combo));
    deetty_box_pack_start(content, combo, FALSE, FALSE, 12);
    if (suggestion_count > 0) {
        GtkWidget *hint = deetty_tag_hint_new();
        if (hint != NULL)
            deetty_box_pack_start(content, hint, FALSE, FALSE, 0);
    }
    (void)configure_overlay_window_stacking(
        context, dialog, "deetty-tag-dialog");
    show_all_with_action_affordances(dialog);
    gchar *result = NULL;
    if (run_grid_modal_dialog(context, GTK_DIALOG(dialog)) ==
        GTK_RESPONSE_OK) {
        const gchar *text = deetty_grid_entry_get_text(GTK_ENTRY(entry));
        if (text != NULL) {
            gchar *trimmed = g_strdup(text);
            g_strstrip(trimmed);
            if (allow_empty || trimmed[0] != '\0')
                result = trimmed;
            else
                deetty_grid_memory_free(trimmed);
        }
    }
    deetty_grid_widget_destroy(dialog);
    return result;
}

static void on_tag_selected_menu_activate(GtkMenuItem *item, gpointer user_data) {
    (void)item;
    DeettyGridContext *root = root_grid_context(user_data);
    gchar *tag = run_tag_entry_dialog(root, "Tag selected panes", NULL, FALSE);
    if (tag != NULL) {
        if (deetty_grid_tag_selected_panes(root->event_data, tag, strlen(tag)) == 0) {
            apply_smart_filter(root);
            refresh_tag_tooltips(root);
        }
        deetty_grid_memory_free(tag);
    }
}

static void on_tag_remove_menu_activate(GtkMenuItem *item, gpointer user_data) {
    (void)item;
    DeettyGridContext *root = root_grid_context(user_data);
    gchar *tag = run_tag_entry_dialog(root, "Remove tag from selected panes", NULL, FALSE);
    if (tag != NULL) {
        (void)deetty_grid_remove_tag_from_selected_panes(root->event_data,
                                                         tag, strlen(tag));
        apply_smart_filter(root);
        refresh_tag_tooltips(root);
        deetty_grid_memory_free(tag);
    }
}

static void on_smart_filter_button_clicked(GtkButton *button, gpointer user_data) {
    (void)button;
    DeettyGridContext *root = root_grid_context(user_data);
    gchar *tag = run_tag_entry_dialog(root, "Smart tab filter (blank clears)",
                                      root->smart_filter_tag, TRUE);
    if (tag != NULL) {
        if (deetty_grid_set_smart_filter(root->event_data, tag, strlen(tag)) == 0) {
            deetty_grid_memory_free(root->smart_filter_tag);
            root->smart_filter_tag = tag[0] == '\0' ? NULL : g_strdup(tag);
        }
        deetty_grid_memory_free(tag);
    }
    apply_smart_filter(root);
}

static void on_smart_filter_menu_activate(GtkMenuItem *item, gpointer user_data) {
    (void)item;
    on_smart_filter_button_clicked(NULL, user_data);
}

static void on_command_palette_menu_activate(GtkWidget *item,
                                             gpointer user_data) {
    DeettyGridContext *context = user_data;
    GtkWidget *menu = deetty_grid_widget_get_ancestor(item, GTK_TYPE_MENU);
    if (!deetty_grid_widget_is_type(menu, DEETTY_GTK_MENU)) return;
    mark_workspace_menu_action(item);
    DeettyGridContext *root = root_grid_context(context);
    if (root->workspace_menu != NULL)
        deetty_grid_object_set_data(G_OBJECT(root->workspace_menu),
                          "deetty-open-command-palette", context);
}

static void on_compact_menu_activate(GtkWidget *item, gpointer user_data) {
    DeettyGridContext *context = user_data;
    int action = GPOINTER_TO_INT(deetty_grid_object_get_data(G_OBJECT(item),
                                                   "deetty-compact-action"));
    execute_palette_action(context, action);
}


static void on_profile_preset_toggled(GtkCheckMenuItem *item,
                                      gpointer user_data) {
    if (!deetty_grid_check_menu_item_get_active(item)) return;
    DeettyGridContext *context = user_data;
    DeettyGridContext *root = root_grid_context(context);
    int preset = GPOINTER_TO_INT(deetty_grid_object_get_data(
        G_OBJECT(item), "deetty-profile-preset"));
    if (!deetty_grid_profile_preset_valid(preset) || context->event == NULL) return;
    context->event(context->event_data, context->pane_id, DEETTY_GRID_HOST_EVENT(PROFILE_SELECTED), preset,
                   (uint64_t)(g_get_monotonic_time() / 1000));
    context->profile_menu_active = 0;
    root->profile_menu_selected++;
    (void)sync_grid_context_profile(context);
}

static GtkWidget *create_profile_preset_menu(DeettyGridContext *context) {
    DeettyGridContext *root = root_grid_context(context);
    if (context->event != NULL) {
        context->event(context->event_data, context->pane_id, DEETTY_GRID_HOST_EVENT(PROFILE_MENU_OPENED), 0,
                       (uint64_t)(g_get_monotonic_time() / 1000));
        context->profile_menu_active = 1;
    }
    (void)sync_grid_context_profile(context);
    const char *labels[5] = {0};
    for (int preset = 0; preset < 5; preset++)
        labels[preset] = deetty_grid_profile_preset_label(preset);
    GtkWidget *menu = deetty_profile_preset_menu_new(
        labels, G_N_ELEMENTS(labels), context->profile_preset,
        G_CALLBACK(on_profile_preset_toggled), context);
    if (menu == NULL) return NULL;
    root->profile_menu_opened++;
    return menu;
}

static void on_workspace_menu_destroy(GtkWidget *menu, gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    DeettyGridLifecycleTimingPlan timing = {0};
    deetty_grid_lifecycle_timing_plan(&timing);
    gboolean action_activated = GPOINTER_TO_INT(deetty_grid_object_get_data(
        G_OBJECT(menu), "deetty-workspace-action")) != 0;
    DeettyGridContext *profile_context = deetty_grid_object_get_data(
        G_OBJECT(menu), "deetty-profile-context");
    DeettyGridContext *palette_context = deetty_grid_object_get_data(
        G_OBJECT(menu), "deetty-open-command-palette");
    gboolean profile_registered =
        grid_context_is_registered(root, profile_context);
    gboolean palette_registered =
        grid_context_is_registered(root, palette_context);
    if (profile_registered && profile_context->profile_menu_active) {
        if (profile_context->event != NULL)
            profile_context->event(
                profile_context->event_data, profile_context->pane_id,
                107, 0, (uint64_t)(g_get_monotonic_time() / 1000));
        profile_context->profile_menu_active = 0;
    }
    if (root->workspace_menu == menu) root->workspace_menu = NULL;
    if (root->focus_hide_source != 0)
        deetty_grid_source_remove(root->focus_hide_source);
    if (action_activated) {
        root->focus_hide_source = 0;
        DeettyGridContext *active = active_grid_context(root);
        if (active != NULL && active->area != NULL)
            deetty_grid_focus_widget(NULL, active->area);
        if (palette_registered &&
            grid_context_session_available(palette_context))
            open_command_palette(palette_context);
        }
    root->focus_hide_source = deetty_grid_source_timeout_add(
        (guint)timing.focus_hide_ms, deferred_focus_hide, root);
}
static void dismiss_workspace_menu(DeettyGridContext *context) {
    DeettyGridContext *root = root_grid_context(context);
    GtkWidget *menu = root->workspace_menu;
    if (menu == NULL) return;
    deetty_grid_object_ref(menu);
    if (deetty_grid_widget_is_type(menu, DEETTY_GTK_MENU) && deetty_grid_widget_get_mapped(menu))
        deetty_grid_menu_popdown(GTK_MENU(menu));
    if (!deetty_grid_widget_in_destruction(menu)) deetty_grid_widget_destroy(menu);
    deetty_grid_object_unref(menu);
}

static void dismiss_grid_popup_windows(DeettyGridContext *context) {
    DeettyGridContext *root = root_grid_context(context);
    dismiss_workspace_menu(root);
    GtkWidget *grab = deetty_grid_grab_get_current();
    if (grab != NULL && deetty_grid_widget_is_type(grab, DEETTY_GTK_MENU))
        deetty_grid_menu_popdown(GTK_MENU(grab));
    GList *windows = deetty_grid_window_list_toplevels();
    for (GList *item = windows; item != NULL; item = item->next) {
        GtkWidget *window = item->data;
        if (!deetty_grid_widget_is_type(window, DEETTY_GTK_WINDOW) || window == root->window ||
            deetty_grid_window_get_window_type(window) != GTK_WINDOW_POPUP ||
            !deetty_grid_widget_get_visible(window))
            continue;
        deetty_grid_widget_hide(window);
    }
    g_list_free(windows);
}

static void on_tab_close_menu_activate(GtkWidget *item, gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    GtkWidget *page = deetty_grid_object_get_data(G_OBJECT(item), "deetty-tab-page");
    (void)close_grid_tab(root, page);
}

static gboolean adjust_tab_color_for_page(DeettyGridContext *context,
                                          GtkWidget *page, int delta) {
    DeettyGridContext *root = root_grid_context(context);
    DeettyGridContext *representative = grid_context_for_page(root, page);
    if (representative == NULL || root->event_data == NULL || delta == 0)
        return FALSE;
    if (deetty_grid_adjust_tab_color(root->event_data,
                                     representative->pane_id,
                                     delta) != 0)
        return FALSE;
    update_compact_tab(representative);
    if (delta > 0) root->tab_color_shortcut_lighten = 1;
    else root->tab_color_shortcut_darken = 1;
    return TRUE;
}

static gboolean adjust_active_tab_color(DeettyGridContext *context,
                                        int delta) {
    DeettyGridContext *root = root_grid_context(context);
    gint page_index = deetty_grid_notebook_get_current_page(
        GTK_NOTEBOOK(root->notebook));
    GtkWidget *page = deetty_grid_notebook_get_nth_page(
        GTK_NOTEBOOK(root->notebook), page_index);
    return page != NULL && adjust_tab_color_for_page(root, page, delta);
}

static void on_tab_color_preset_toggled(GtkCheckMenuItem *item,
                                        gpointer user_data) {
    if (!deetty_grid_check_menu_item_get_active(item)) return;
    DeettyGridContext *root = root_grid_context(user_data);
    GtkWidget *page = deetty_grid_object_get_data(G_OBJECT(item), "deetty-tab-page");
    DeettyGridContext *representative = grid_context_for_page(root, page);
    int preset = GPOINTER_TO_INT(deetty_grid_object_get_data(
        G_OBJECT(item), "deetty-tab-color-preset"));
    if (representative == NULL || root->event_data == NULL) return;
    if (deetty_grid_set_tab_color(root->event_data,
                                  representative->pane_id,
                                  preset) == 0) {
        root->tab_color_preset_applied = 1;
        update_compact_tab(representative);
    }
}

static void on_tab_color_adjust_activate(GtkMenuItem *item,
                                         gpointer user_data) {
    GtkWidget *page = deetty_grid_object_get_data(G_OBJECT(item), "deetty-tab-page");
    int delta = GPOINTER_TO_INT(deetty_grid_object_get_data(
        G_OBJECT(item), "deetty-tab-color-delta"));
    (void)adjust_tab_color_for_page(user_data, page, delta);
}

static GtkWidget *create_tab_color_menu(DeettyGridContext *context,
                                        GtkWidget *page) {
    DeettyGridContext *root = root_grid_context(context);
    DeettyGridContext *representative = grid_context_for_page(root, page);
    int current_preset = -1;
    int current_shade = 0;
    if (representative != NULL && root->event_data != NULL)
        (void)deetty_grid_tab_color(root->event_data,
                                    representative->pane_id,
                                    &current_preset, &current_shade);
    const char *labels[9] = {0};
    for (int preset = -1; preset < 8; preset++)
        labels[preset + 1] = deetty_grid_tab_color_preset_name(preset);
    (void)current_shade;
    return deetty_tab_color_menu_new(
        labels, G_N_ELEMENTS(labels), current_preset, page,
        G_CALLBACK(on_tab_color_preset_toggled),
        G_CALLBACK(on_tab_color_adjust_activate), root,
        "Lighten (Ctrl+Alt+=)", "Darken (Ctrl+Alt+-)");
}

static void popup_menu_at_toplevel_pointer(
    DeettyGridContext *context, GtkWidget *menu, GtkWidget *anchor,
    GdkEventButton *event) {
    DeettyGridContext *root = root_grid_context(context);
    if (event != NULL && event->send_event) {
        deetty_grid_menu_popup_at_widget(GTK_MENU(menu), anchor,
                                 GDK_GRAVITY_SOUTH_WEST,
                                 GDK_GRAVITY_NORTH_WEST,
                                 (GdkEvent *)event);
        return;
    }
    gint x = event != NULL ? (gint)event->x : 0;
    gint y = event != NULL ? (gint)event->y : 0;
    if (anchor != root->window)
        (void)deetty_grid_widget_translate_coordinates(
            anchor, root->window, x, y, &x, &y);
    GdkWindow *window = deetty_grid_widget_get_window(root->window);
    if (window == NULL) {
        deetty_grid_menu_popup_at_widget(GTK_MENU(menu), anchor,
                                 GDK_GRAVITY_SOUTH_WEST,
                                 GDK_GRAVITY_NORTH_WEST,
                                 (GdkEvent *)event);
        return;
    }
    GdkRectangle point = {x, y, 1, 1};
    deetty_grid_menu_popup_at_rect(GTK_MENU(menu), window, &point,
                           GDK_GRAVITY_SOUTH_WEST,
                           GDK_GRAVITY_NORTH_WEST,
                           (GdkEvent *)event);
}

static void show_tab_menu(DeettyGridContext *context, GtkWidget *page,
                          GdkEventButton *event) {
    DeettyGridContext *root = root_grid_context(context);
    dismiss_grid_popup_windows(root);
    GtkWidget *color_menu = create_tab_color_menu(root, page);
    GtkWidget *menu = deetty_tab_context_menu_new(
        page, color_menu,
        deetty_grid_notebook_get_n_pages(GTK_NOTEBOOK(root->notebook)) > 1,
        G_CALLBACK(on_tab_close_menu_activate), root);
    if (menu == NULL) return;
    root->workspace_menu = menu;
    root->tab_context_menu_opened = 1;
    root->tab_color_menu_opened = 1;
    deetty_grid_signal_connect(menu, "selection-done",
                     G_CALLBACK(deetty_grid_widget_destroy), NULL);
    deetty_grid_signal_connect(menu, "destroy",
                     G_CALLBACK(on_workspace_menu_destroy), root);
    deetty_grid_widget_show_all(menu);
    GtkWidget *anchor = deetty_grid_notebook_get_tab_label(
        GTK_NOTEBOOK(root->notebook), page);
    popup_menu_at_toplevel_pointer(
        root, menu, anchor != NULL ? anchor : root->notebook, event);
}

static gboolean finish_tab_color_smoke(gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    DeettyGridContext *active = active_grid_context(root);
    int preset = -1;
    int shade = 0;
    root->tab_color_restored_rgb = active != NULL && root->event_data != NULL
        ? deetty_grid_tab_color(root->event_data, active->pane_id,
                                &preset, &shade)
        : 0;
    root->tab_color_shortcut_darken = root->tab_color_shortcut_darken &&
        preset == 5 && shade == 0 && root->tab_color_restored_rgb ==
        root->tab_color_initial_rgb;
    if (active != NULL && active->write != NULL)
        (void)active->write(active->userdata, "exit 0\n", 7);
    return G_SOURCE_REMOVE;
}

static gboolean darken_tab_color_smoke(gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    DeettyGridContext *active = active_grid_context(root);
    int preset = -1;
    int shade = 0;
    root->tab_color_lightened_rgb = active != NULL && root->event_data != NULL
        ? deetty_grid_tab_color(root->event_data, active->pane_id,
                                &preset, &shade)
        : 0;
    root->tab_color_shortcut_lighten = root->tab_color_shortcut_lighten &&
        preset == 5 && shade == 1 &&
        root->tab_color_lightened_rgb != 0 &&
        root->tab_color_lightened_rgb != root->tab_color_initial_rgb;
    GdkEventKey event = {0};
    event.type = GDK_KEY_PRESS;
    event.state = GDK_CONTROL_MASK | GDK_MOD1_MASK;
    event.keyval = GDK_KEY_minus;
    (void)on_key_press(root->area, &event, root);
    deetty_grid_source_timeout_add(180, finish_tab_color_smoke, root);
    return G_SOURCE_REMOVE;
}

static gboolean lighten_tab_color_smoke(gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    gint page_index = deetty_grid_notebook_get_current_page(
        GTK_NOTEBOOK(root->notebook));
    GtkWidget *page = deetty_grid_notebook_get_nth_page(
        GTK_NOTEBOOK(root->notebook), page_index);
    GtkWidget *tab_widget = page != NULL
        ? deetty_grid_notebook_get_tab_label(GTK_NOTEBOOK(root->notebook), page)
        : NULL;
    GtkWidget *content = deetty_grid_widget_is_type(tab_widget, DEETTY_GTK_BIN)
        ? deetty_grid_bin_get_child(GTK_BIN(tab_widget)) : NULL;
    GtkWidget *label = tab_label_from_widget(tab_widget);
    guint rendered_rgb = 0;
    guint rendered_alpha = 0;
    if (content != NULL) {
        cairo_surface_t *surface = cairo_image_surface_create(
            CAIRO_FORMAT_ARGB32, 8, 8);
        cairo_t *cr = cairo_create(surface);
        deetty_grid_render_background(
            deetty_grid_widget_get_style_context(content), cr, 8, 8);
        cairo_destroy(cr);
        cairo_surface_flush(surface);
        unsigned char *data = cairo_image_surface_get_data(surface);
        int stride = cairo_image_surface_get_stride(surface);
        uint32_t sample = 0;
        memcpy(&sample, data + 4 * stride + 4 * 4, sizeof(sample));
        rendered_rgb = sample & 0x00ffffffu;
        rendered_alpha = sample >> 24;
        cairo_surface_destroy(surface);
    }
    const gchar *markup = deetty_grid_widget_is_type(label, DEETTY_GTK_LABEL)
        ? deetty_grid_label_get_label(label) : "";
    gchar *tooltip = label != NULL
        ? deetty_grid_widget_get_tooltip_text(label) : NULL;
    root->tab_color_rendered = tab_widget != NULL && content != NULL &&
        deetty_grid_widget_get_mapped(tab_widget) && deetty_grid_widget_get_mapped(content) &&
        GPOINTER_TO_UINT(deetty_grid_object_get_data(
            G_OBJECT(tab_widget), "deetty-tab-color-rgb")) ==
                root->tab_color_initial_rgb &&
        rendered_rgb == root->tab_color_initial_rgb &&
        rendered_alpha == 0xff;
    root->tab_color_contrast_ready = markup != NULL &&
        strstr(markup, "foreground='#11151b'") != NULL &&
        tooltip != NULL && strstr(tooltip, "tab color Blue") != NULL;
    deetty_grid_memory_free(tooltip);

    GdkEventKey event = {0};
    event.type = GDK_KEY_PRESS;
    event.state = GDK_CONTROL_MASK | GDK_MOD1_MASK;
    event.keyval = GDK_KEY_equal;
    (void)on_key_press(root->area, &event, root);
    deetty_grid_source_timeout_add(180, darken_tab_color_smoke, root);
    return G_SOURCE_REMOVE;
}

static gboolean choose_tab_color_smoke(gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    GtkWidget *color = root->workspace_menu != NULL &&
            deetty_grid_widget_get_mapped(root->workspace_menu)
        ? find_workspace_menu_item(root->workspace_menu, "Tab Color")
        : NULL;
    GtkWidget *submenu = color != NULL
        ? deetty_grid_menu_item_get_submenu(GTK_MENU_ITEM(color)) : NULL;
    GtkWidget *blue = submenu != NULL
        ? find_workspace_menu_item(submenu, "Blue") : NULL;
    if (blue != NULL)
        deetty_grid_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(blue), TRUE);
    DeettyGridContext *active = active_grid_context(root);
    int preset = -1;
    int shade = 0;
    root->tab_color_initial_rgb = active != NULL && root->event_data != NULL
        ? deetty_grid_tab_color(root->event_data, active->pane_id,
                                &preset, &shade)
        : 0;
    root->tab_color_preset_applied = root->tab_color_preset_applied &&
        color != NULL && submenu != NULL && blue != NULL &&
        preset == 5 && shade == 0 &&
        root->tab_color_initial_rgb == 0x4285f4;
    dismiss_workspace_menu(root);
    deetty_grid_source_timeout_add(180, lighten_tab_color_smoke, root);
    return G_SOURCE_REMOVE;
}

static gboolean request_tab_color_smoke(gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    gint page_index = deetty_grid_notebook_get_current_page(
        GTK_NOTEBOOK(root->notebook));
    GtkWidget *page = deetty_grid_notebook_get_nth_page(
        GTK_NOTEBOOK(root->notebook), page_index);
    GtkWidget *tab_widget = page != NULL
        ? deetty_grid_notebook_get_tab_label(GTK_NOTEBOOK(root->notebook), page)
        : NULL;
    if (tab_widget == NULL) return G_SOURCE_REMOVE;
    GdkEventButton event = {0};
    event.type = GDK_BUTTON_PRESS;
    event.window = deetty_grid_widget_get_window(tab_widget);
    event.send_event = TRUE;
    event.time = GDK_CURRENT_TIME;
    event.button = 3;
    (void)on_tab_button_press(tab_widget, &event, root);
    (void)on_window_focus_out(root->window, NULL, root);
    deetty_grid_source_timeout_add(250, choose_tab_color_smoke, root);
    return G_SOURCE_REMOVE;
}

static gboolean request_new_tab_after_close_smoke(gpointer user_data);
static gboolean cleanup_new_tab_after_close_smoke(gpointer user_data);
static gboolean continue_tab_close_smoke(gpointer user_data);
static gboolean focus_out_tab_close_smoke(gpointer user_data);

static gboolean finish_tab_close_smoke(gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    DeettyGridContext *remaining = active_grid_context(root);
    if (remaining->area != NULL)
        deetty_grid_focus_widget(NULL, remaining->area);
    gint current_index = deetty_grid_notebook_get_current_page(GTK_NOTEBOOK(root->notebook));
    GtkWidget *current_page = deetty_grid_notebook_get_nth_page(
        GTK_NOTEBOOK(root->notebook), current_index);
    root->tab_close_remaining_focused = remaining->area != NULL &&
        remaining->pane_id == 2 && remaining->page == current_page;
    root->new_tab_button_visible_after_close =
        root->new_tab_button != NULL &&
        deetty_grid_notebook_get_n_pages(GTK_NOTEBOOK(root->notebook)) == 1 &&
        deetty_grid_notebook_get_show_tabs(GTK_NOTEBOOK(root->notebook)) &&
        deetty_grid_widget_get_mapped(root->new_tab_button);
    if (!root->tab_close_remaining_focused ||
        !root->new_tab_button_visible_after_close)
        g_printerr("native_grid_tab_close_finish pane=%" G_GUINT64_FORMAT " expected=2 current_page=%d page_match=%d pages=%d tabs_visible=%d add_mapped=%d\n",
                   remaining != NULL ? remaining->pane_id : 0,
                   current_index,
                   remaining != NULL && remaining->page == current_page,
                   deetty_grid_notebook_get_n_pages(GTK_NOTEBOOK(root->notebook)),
                   deetty_grid_notebook_get_show_tabs(GTK_NOTEBOOK(root->notebook)),
                   root->new_tab_button != NULL &&
                       deetty_grid_widget_get_mapped(root->new_tab_button));
    if (root->tab_close_remaining_focused &&
        root->new_tab_button_visible_after_close)
        deetty_grid_source_timeout_add(150, request_new_tab_after_close_smoke, root);
    return G_SOURCE_REMOVE;
}

static gboolean probe_retired_tab_callback(gpointer user_data) {
    DeettyGridContext *context = user_data;
    DeettyGridContext *root = root_grid_context(context);
    gboolean retired = context->retiring && !context->active &&
        context->area == NULL && context->page == NULL;
    (void)on_focus_out(NULL, NULL, context);
    root->late_callback_guarded = retired &&
        !grid_context_session_available(context);
    return G_SOURCE_REMOVE;
}

static gboolean open_tab_close_smoke_menu(DeettyGridContext *root) {
    GtkWidget *page = deetty_grid_notebook_get_nth_page(
        GTK_NOTEBOOK(root->notebook), 0);
    GtkWidget *tab_widget = page != NULL
        ? deetty_grid_notebook_get_tab_label(GTK_NOTEBOOK(root->notebook), page)
        : NULL;
    if (tab_widget == NULL || deetty_grid_widget_get_window(tab_widget) == NULL)
        return FALSE;
    GdkEventButton event = {0};
    event.type = GDK_BUTTON_PRESS;
    event.window = deetty_grid_widget_get_window(tab_widget);
    event.send_event = TRUE;
    event.time = GDK_CURRENT_TIME;
    event.button = 3;
    (void)on_tab_button_press(tab_widget, &event, root);
    return root->workspace_menu != NULL;
}

static gboolean continue_tab_close_smoke(gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    GtkWidget *menu = root->workspace_menu;
    gboolean menu_ready = menu != NULL && deetty_grid_widget_get_mapped(menu) &&
        deetty_grid_widget_get_mapped(root->window) && root->window_presented;
    GtkWidget *close = menu_ready
        ? find_workspace_menu_item(menu, "Close Tab")
        : NULL;
    if (close == NULL) {
        if (root->tab_close_smoke_attempts++ < 80) {
            if (root->tab_close_smoke_attempts % 20 == 0)
                (void)open_tab_close_smoke_menu(root);
            deetty_grid_source_timeout_add(25, focus_out_tab_close_smoke, root);
        }
        return G_SOURCE_REMOVE;
    }
    root->tab_close_smoke_attempts = 0;
    root->tab_context_menu_survived = 1;
    GtkWidget *page = deetty_grid_object_get_data(G_OBJECT(close), "deetty-tab-page");
    DeettyGridContext *closing = grid_context_for_page(root, page);
    deetty_grid_menu_shell_select_item(GTK_MENU_SHELL(menu), close);
    deetty_grid_menu_shell_activate_item(GTK_MENU_SHELL(menu), close, TRUE);
    if (closing != NULL && !closing->heap_allocated)
        deetty_grid_source_timeout_add(25, probe_retired_tab_callback, closing);
    deetty_grid_source_timeout_add(150, finish_tab_close_smoke, root);
    return G_SOURCE_REMOVE;
}

static gboolean focus_out_tab_close_smoke(gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    GtkWidget *menu = root->workspace_menu;
    if ((menu == NULL || !deetty_grid_widget_get_mapped(menu)) &&
        root->tab_close_smoke_attempts++ < 80) {
        if (root->tab_close_smoke_attempts % 20 == 0)
            (void)open_tab_close_smoke_menu(root);
        deetty_grid_source_timeout_add(25, focus_out_tab_close_smoke, root);
        return G_SOURCE_REMOVE;
    }
    root->tab_close_smoke_attempts = 0;
    if (menu == NULL || !deetty_grid_widget_get_mapped(menu))
        return G_SOURCE_REMOVE;
    (void)on_window_focus_out(root->window, NULL, root);
    deetty_grid_source_timeout_add(150, continue_tab_close_smoke, root);
    return G_SOURCE_REMOVE;
}

static gboolean request_tab_close_smoke(gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    GtkWidget *page = deetty_grid_notebook_get_nth_page(GTK_NOTEBOOK(root->notebook), 0);
    GtkWidget *current = deetty_grid_notebook_get_nth_page(
        GTK_NOTEBOOK(root->notebook),
        deetty_grid_notebook_get_current_page(GTK_NOTEBOOK(root->notebook)));
    root->tab_close_targeted_background = page != NULL && page != current;
    if (!root->tab_close_targeted_background) return G_SOURCE_REMOVE;
    root->tab_close_smoke_attempts = 0;
    (void)open_tab_close_smoke_menu(root);
    deetty_grid_source_timeout_add(25, focus_out_tab_close_smoke, root);
    return G_SOURCE_REMOVE;
}

static gboolean request_new_tab_after_close_smoke(gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    DeettyGridContext *retired = root->contexts != NULL &&
        root->contexts->len > 0
        ? g_ptr_array_index(root->contexts, 0)
        : NULL;
    DeettyGridContext *source = active_grid_context(root);
    guint context_count = root->contexts != NULL ? root->contexts->len : 0;
    gboolean retired_safely = retired != NULL && !retired->active &&
        retired->area == NULL && retired->page == NULL &&
        retired->peer == NULL && source != NULL && source != retired &&
        source->peer == NULL && source->pane_id == 2;
    if (root->new_tab_button != NULL)
        deetty_grid_button_clicked(GTK_BUTTON(root->new_tab_button));
    DeettyGridContext *created = active_grid_context(root);
    root->new_tab_button_reopened_after_close =
        deetty_grid_notebook_get_n_pages(GTK_NOTEBOOK(root->notebook)) == 2 &&
        deetty_grid_notebook_get_current_page(GTK_NOTEBOOK(root->notebook)) == 1;
    root->new_tab_button_fresh_context = retired_safely &&
        root->contexts != NULL && root->contexts->len == context_count + 1 &&
        created != NULL && created != retired && created != source &&
        created->heap_allocated && created->pane_id != 1 &&
        created->pane_id != 2 && created->area != NULL;
    if (root->new_tab_button_reopened_after_close &&
        root->new_tab_button_fresh_context)
        deetty_grid_source_timeout_add(200, cleanup_new_tab_after_close_smoke, root);
    return G_SOURCE_REMOVE;
}

static gboolean cleanup_new_tab_after_close_smoke(gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    int first_close_focused = root->tab_close_remaining_focused;
    int first_close_add_visible = root->new_tab_button_visible_after_close;
    gint current_index = deetty_grid_notebook_get_current_page(
        GTK_NOTEBOOK(root->notebook));
    GtkWidget *page = deetty_grid_notebook_get_nth_page(GTK_NOTEBOOK(root->notebook),
                                                current_index);
    gboolean closed =
        deetty_grid_notebook_get_n_pages(GTK_NOTEBOOK(root->notebook)) == 2 &&
        close_grid_tab(root, page);
    root->new_tab_button_cleanup = closed &&
        deetty_grid_notebook_get_n_pages(GTK_NOTEBOOK(root->notebook)) == 1 &&
        deetty_grid_notebook_get_show_tabs(GTK_NOTEBOOK(root->notebook)) &&
        root->new_tab_button != NULL &&
        deetty_grid_widget_get_mapped(root->new_tab_button);
    root->tab_close_remaining_focused = first_close_focused;
    root->new_tab_button_visible_after_close = first_close_add_visible;
    return G_SOURCE_REMOVE;
}

static void show_workspace_menu(DeettyGridContext *context, GdkEventButton *event) {
    DeettyGridContext *root = root_grid_context(context);
    dismiss_grid_popup_windows(root);
    GtkWidget *profile_menu = create_profile_preset_menu(context);
    const DeettyWorkspaceMenuOptions options = {
        .context = context,
        .root = root,
        .profile_menu = profile_menu,
        .broadcast_label = deetty_grid_broadcast_menu_label(
            root->event_data != NULL &&
            deetty_grid_broadcast_enabled(root->event_data) != 0),
        .selection_active = context->selecting,
        .pane_close_sensitive = active_grid_context_count(root) > 1,
    };
    const DeettyWorkspaceMenuCallbacks callbacks = {
        .workspace = G_CALLBACK(on_workspace_menu_activate),
        .terminal = G_CALLBACK(on_terminal_menu_activate),
        .compact = G_CALLBACK(on_compact_menu_activate),
        .tag_selected = G_CALLBACK(on_tag_selected_menu_activate),
        .tag_remove = G_CALLBACK(on_tag_remove_menu_activate),
        .smart_filter = G_CALLBACK(on_smart_filter_menu_activate),
        .broadcast = G_CALLBACK(on_broadcast_menu_activate),
        .theme = G_CALLBACK(on_theme_menu_activate),
        .command_palette = G_CALLBACK(on_command_palette_menu_activate),
        .sharing = G_CALLBACK(on_session_sharing_menu_activate),
        .project = G_CALLBACK(on_project_menu_activate),
        .pane_close = G_CALLBACK(on_pane_close_menu_activate),
        .settings = G_CALLBACK(on_settings_menu_activate),
        .selection_done = G_CALLBACK(deetty_grid_widget_destroy),
        .destroy = G_CALLBACK(on_workspace_menu_destroy),
    };
    GtkWidget *menu = deetty_workspace_menu_new(&options, &callbacks);
    if (menu == NULL) return;
    root->workspace_menu = menu;
    root->context_menu_opened = 1;
    root->pane_close_menu_opened = 1;
    deetty_grid_widget_show_all(menu);
    if (event != NULL && event->send_event) {
        /* Smoke events are constructed in-process rather than dispatched by
         * GDK, so popup-at-pointer has no compositor-owned trigger event to
         * position from. Anchor those menus to the pane itself; real pointer
         * events keep the normal desktop placement path. */
        GdkEvent *trigger = deetty_grid_button_event_new(
            event->window,
            event->time,
            event->x,
            event->y,
            event->state,
            event->button,
            event->x_root,
            event->y_root);
        deetty_grid_event_set_pointer_device(
            trigger, deetty_grid_widget_get_display(context->area));
        deetty_grid_menu_popup_at_widget(GTK_MENU(menu), context->area,
                                 GDK_GRAVITY_SOUTH_WEST,
                                 GDK_GRAVITY_NORTH_WEST,
                                 trigger);
        deetty_grid_event_free(trigger);
    } else
        popup_menu_at_toplevel_pointer(context, menu, context->area, event);
}

static gboolean open_smoke_workspace_menu(DeettyGridContext *context) {
    if (context == NULL || context->area == NULL ||
        !deetty_grid_widget_get_mapped(context->area)) return FALSE;
    GdkEventButton event = {0};
    event.type = GDK_BUTTON_PRESS;
    event.window = deetty_grid_widget_get_window(context->area);
    event.send_event = TRUE;
    event.time = GDK_CURRENT_TIME;
    event.x = 12.0;
    event.y = 12.0;
    event.x_root = 12.0;
    event.y_root = 12.0;
    event.button = 3;
    show_workspace_menu(context, &event);
    return TRUE;
}

static gboolean finish_profile_preset_smoke(gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    for (guint index = 0;
         root->contexts != NULL && index < root->contexts->len; index++) {
        DeettyGridContext *candidate = g_ptr_array_index(
            root->contexts, index);
        if (candidate->active && !candidate->exited &&
            candidate->write != NULL)
            (void)candidate->write(candidate->userdata, "exit 0\n", 7);
    }
    return G_SOURCE_REMOVE;
}

static gboolean open_profile_preset_smoke_menu(gpointer user_data);

static gboolean check_profile_preset_smoke(gpointer user_data) {
    DeettyGridContext *target = user_data;
    DeettyGridContext *root = root_grid_context(target);
    DeettyGridContext *neighbor = root->contexts != NULL &&
            root->contexts->len >= 2
        ? g_ptr_array_index(root->contexts, 0) : NULL;
    gboolean target_synced = sync_grid_context_profile(target);
    gboolean neighbor_synced = neighbor != NULL &&
        sync_grid_context_profile(neighbor);
    gboolean neighbor_unchanged = neighbor_synced &&
        neighbor->profile_preset == root->profile_neighbor_preset &&
        ABS(neighbor->font_size - root->profile_neighbor_font_size) < 0.01 &&
        neighbor->high_contrast == root->profile_neighbor_high_contrast &&
        neighbor->ligatures == root->profile_neighbor_ligatures;
    root->profile_isolated = root->profile_isolated && neighbor_unchanged;

    if (root->profile_smoke_stage == 1) {
        root->profile_readable = target_synced &&
            target->profile_preset == 2 &&
            ABS(target->font_size - 14.0) < 0.01 &&
            !target->high_contrast;
        root->profile_exact_target = root->profile_exact_target &&
            root->profile_readable && neighbor_unchanged;
        root->profile_smoke_stage = 2;
        deetty_grid_source_timeout_add(120, open_profile_preset_smoke_menu, target);
    } else if (root->profile_smoke_stage == 2) {
        root->profile_high_contrast = target_synced &&
            target->profile_preset == 3 &&
            ABS(target->font_size - 12.0) < 0.01 &&
            target->high_contrast;
        root->profile_exact_target = root->profile_exact_target &&
            root->profile_high_contrast && neighbor_unchanged;
        root->profile_smoke_stage = 3;
        deetty_grid_source_timeout_add(120, open_profile_preset_smoke_menu, target);
    } else if (root->profile_smoke_stage == 3) {
        root->profile_mono_no_ligatures = target_synced &&
            target->profile_preset == 4 && !target->ligatures &&
            !target->high_contrast;
        root->profile_exact_target = root->profile_exact_target &&
            root->profile_mono_no_ligatures && neighbor_unchanged;
        deetty_grid_source_timeout_add(180, finish_profile_preset_smoke, root);
    }
    return G_SOURCE_REMOVE;
}

static gboolean activate_profile_preset_smoke(gpointer user_data) {
    DeettyGridContext *target = user_data;
    DeettyGridContext *root = root_grid_context(target);
    GtkWidget *menu = root->workspace_menu;
    GtkWidget *profile = menu != NULL
        ? find_workspace_menu_item(menu, "Profile") : NULL;
    GtkWidget *submenu = profile != NULL
        ? deetty_grid_menu_item_get_submenu(GTK_MENU_ITEM(profile)) : NULL;
    const int stage = root->profile_smoke_stage;
    const int expected = stage == 1 ? 0 : stage == 2 ? 2 : 3;
    const int selected = stage == 1 ? 2 : stage == 2 ? 3 : 4;
    GtkWidget *current = submenu != NULL
        ? find_workspace_menu_item(submenu,
                                   deetty_grid_profile_preset_label(expected)) : NULL;
    GtkWidget *choice = submenu != NULL
        ? find_workspace_menu_item(submenu,
                                   deetty_grid_profile_preset_label(selected)) : NULL;
    int preset_count = 0;
    if (submenu != NULL) {
        GList *items = deetty_grid_container_get_children(GTK_CONTAINER(submenu));
        for (GList *item = items; item != NULL; item = item->next)
            if (deetty_grid_widget_is_type(item->data, DEETTY_GTK_RADIO_MENU_ITEM)) preset_count++;
        g_list_free(items);
    }
    gboolean current_ready = current != NULL &&
        deetty_grid_check_menu_item_get_active(current);
    gboolean menus_mapped = menu != NULL && submenu != NULL &&
        deetty_grid_widget_get_mapped(menu) && deetty_grid_widget_get_mapped(submenu);
    if ((!menus_mapped || !current_ready || choice == NULL ||
         preset_count != 5) && root->profile_smoke_attempts++ < 20) {
        deetty_grid_source_timeout_add(25, activate_profile_preset_smoke, target);
        return G_SOURCE_REMOVE;
    }
    root->profile_smoke_attempts = 0;
    DeettyGridContext *neighbor = root->contexts != NULL &&
            root->contexts->len >= 2
        ? g_ptr_array_index(root->contexts, 0) : NULL;
    root->profile_exact_target = root->profile_exact_target &&
        neighbor != NULL && focused_grid_context(root) == neighbor &&
        deetty_grid_window_get_focus(GTK_WINDOW(root->window)) == neighbor->area;
    if (current_ready) root->profile_menu_current++;
    root->profile_menu_survived = root->profile_menu_survived ||
        (menus_mapped && preset_count == 5);
    if (choice == NULL) {
        if (submenu != NULL) deetty_grid_menu_popdown(GTK_MENU(submenu));
        if (menu != NULL && root->workspace_menu == menu)
            deetty_grid_widget_destroy(menu);
        deetty_grid_source_timeout_add(100, finish_profile_preset_smoke, root);
        return G_SOURCE_REMOVE;
    }
    deetty_grid_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(choice), TRUE);
    if (submenu != NULL) deetty_grid_menu_popdown(GTK_MENU(submenu));
    if (menu != NULL && root->workspace_menu == menu)
        deetty_grid_widget_destroy(menu);
    deetty_grid_source_timeout_add(240, check_profile_preset_smoke, target);
    return G_SOURCE_REMOVE;
}

static gboolean present_profile_preset_submenu_smoke(gpointer user_data) {
    DeettyGridContext *target = user_data;
    DeettyGridContext *root = root_grid_context(target);
    GtkWidget *menu = root->workspace_menu;
    GtkWidget *profile = menu != NULL && deetty_grid_widget_get_mapped(menu)
        ? find_workspace_menu_item(menu, "Profile") : NULL;
    GtkWidget *submenu = profile != NULL
        ? deetty_grid_menu_item_get_submenu(GTK_MENU_ITEM(profile)) : NULL;
    if (profile == NULL || submenu == NULL) {
        if (root->profile_smoke_attempts++ < 20) {
            deetty_grid_source_timeout_add(25, present_profile_preset_submenu_smoke, target);
            return G_SOURCE_REMOVE;
        }
        root->profile_smoke_attempts = 0;
        deetty_grid_source_timeout_add(100, finish_profile_preset_smoke, root);
        return G_SOURCE_REMOVE;
    }
    root->profile_smoke_attempts = 0;
    deetty_grid_menu_shell_select_item(GTK_MENU_SHELL(menu), profile);
    GdkWindow *window = deetty_grid_widget_get_window(profile);
    GdkEvent *trigger = deetty_grid_button_event_new(
        window, GDK_CURRENT_TIME, 0.0, 0.0, 0, 3, 0.0, 0.0);
    deetty_grid_event_set_pointer_device(
        trigger, deetty_grid_widget_get_display(profile));
    deetty_grid_source_timeout_add(140, activate_profile_preset_smoke, target);
    return G_SOURCE_REMOVE;
}

static gboolean wait_profile_preset_parent_menu_smoke(gpointer user_data) {
    DeettyGridContext *target = user_data;
    DeettyGridContext *root = root_grid_context(target);
    GtkWidget *menu = root->workspace_menu;
    if ((menu == NULL || !deetty_grid_widget_get_mapped(menu)) &&
        root->profile_smoke_attempts++ < 20) {
        deetty_grid_source_timeout_add(25, wait_profile_preset_parent_menu_smoke, target);
        return G_SOURCE_REMOVE;
    }
    if (menu == NULL || !deetty_grid_widget_get_mapped(menu)) {
        root->profile_smoke_attempts = 0;
        deetty_grid_source_timeout_add(100, finish_profile_preset_smoke, root);
        return G_SOURCE_REMOVE;
    }
    root->profile_smoke_attempts = 0;
    (void)on_window_focus_out(root->window, NULL, root);
    deetty_grid_source_timeout_add(180, present_profile_preset_submenu_smoke, target);
    return G_SOURCE_REMOVE;
}

static gboolean open_profile_preset_smoke_menu(gpointer user_data) {
    DeettyGridContext *target = user_data;
    DeettyGridContext *root = root_grid_context(target);
    if (target == NULL || target->area == NULL) {
        deetty_grid_source_timeout_add(100, finish_profile_preset_smoke, root);
        return G_SOURCE_REMOVE;
    }
    (void)open_smoke_workspace_menu(target);
    root->profile_smoke_attempts = 0;
    deetty_grid_source_timeout_add(25, wait_profile_preset_parent_menu_smoke, target);
    return G_SOURCE_REMOVE;
}

static gboolean request_profile_preset_smoke(gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    if (root->contexts == NULL || root->contexts->len != 2) {
        deetty_grid_source_timeout_add(100, finish_profile_preset_smoke, root);
        return G_SOURCE_REMOVE;
    }
    DeettyGridContext *neighbor = g_ptr_array_index(root->contexts, 0);
    DeettyGridContext *target = g_ptr_array_index(root->contexts, 1);
    (void)sync_grid_context_profile(neighbor);
    (void)sync_grid_context_profile(target);
    root->profile_neighbor_font_size = neighbor->font_size;
    root->profile_neighbor_high_contrast = neighbor->high_contrast;
    root->profile_neighbor_ligatures = neighbor->ligatures;
    root->profile_neighbor_preset = neighbor->profile_preset;
    root->profile_isolated = 1;
    if (neighbor->area != NULL) deetty_grid_focus_widget(NULL, neighbor->area);
    root->profile_exact_target = neighbor != target &&
        neighbor->pane_id != target->pane_id && target->active &&
        neighbor->active && focused_grid_context(root) == neighbor &&
        deetty_grid_window_get_focus(GTK_WINDOW(root->window)) == neighbor->area;
    root->profile_smoke_stage = 1;
    return open_profile_preset_smoke_menu(target);
}

static gboolean finish_pane_close_resize_smoke(gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    root->pane_close_user_resize_preserved =
        deetty_grid_widget_is_type(root->pane_close_resize_split, DEETTY_GTK_PANED) &&
        deetty_grid_paned_get_position(GTK_PANED(root->pane_close_resize_split)) ==
            root->pane_close_resize_position;
    root->pane_close_resize_split = NULL;

    for (;;) {
        DeettyGridContext *extra = NULL;
        for (guint index = 0; root->contexts != NULL &&
             index < root->contexts->len; index++) {
            DeettyGridContext *candidate = g_ptr_array_index(
                root->contexts, index);
            if (candidate->active && candidate->pane_id != 2) {
                extra = candidate;
                break;
            }
        }
        if (extra == NULL || !close_grid_pane(extra)) break;
    }

    DeettyGridContext *remaining = grid_context_for_pane(root, 2);
    if (remaining != NULL && remaining->area != NULL) {
        (void)open_smoke_workspace_menu(remaining);
        GtkWidget *close_terminal = root->workspace_menu != NULL
            ? find_workspace_menu_item(root->workspace_menu, "Close Terminal")
            : NULL;
        root->pane_close_last_terminal_protected = close_terminal != NULL &&
            !deetty_grid_widget_get_sensitive(close_terminal);
        dismiss_workspace_menu(root);
        if (!remaining->exited && remaining->write != NULL)
            (void)remaining->write(remaining->userdata, "\n", 1);
    }
    return G_SOURCE_REMOVE;
}

static guint smoke_unique_coordinate_count(const gint *values, guint count) {
    gint unique[4] = {0};
    guint unique_count = 0;
    for (guint index = 0; index < count; index++) {
        gboolean found = FALSE;
        for (guint candidate = 0; candidate < unique_count; candidate++) {
            if (ABS(values[index] - unique[candidate]) <= 4) {
                found = TRUE;
                break;
            }
        }
        if (!found && unique_count < G_N_ELEMENTS(unique))
            unique[unique_count++] = values[index];
    }
    return unique_count;
}

static gboolean smoke_page_is_even_two_by_two(
    DeettyGridContext *root, GtkWidget *page) {
    gint x_positions[4] = {0};
    gint y_positions[4] = {0};
    gint width_min = G_MAXINT;
    gint width_max = 0;
    gint height_min = G_MAXINT;
    gint height_max = 0;
    guint measured = 0;
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        DeettyGridContext *candidate = g_ptr_array_index(
            root->contexts, index);
        if (!candidate->active || candidate->page != page ||
            candidate->area == NULL) continue;
        if (measured >= G_N_ELEMENTS(x_positions)) return FALSE;
        GtkAllocation allocation;
        deetty_grid_widget_get_allocation(candidate->area, &allocation);
        if (!deetty_grid_widget_translate_coordinates(
                candidate->area, page, 0, 0,
                &x_positions[measured], &y_positions[measured]))
            return FALSE;
        width_min = MIN(width_min, allocation.width);
        width_max = MAX(width_max, allocation.width);
        height_min = MIN(height_min, allocation.height);
        height_max = MAX(height_max, allocation.height);
        measured++;
    }
    gboolean valid = measured == 4 &&
        smoke_unique_coordinate_count(x_positions, measured) == 2 &&
        smoke_unique_coordinate_count(y_positions, measured) == 2 &&
        width_max - width_min <= 8 && height_max - height_min <= 8;
    if (!valid && root->workspace_smoke == 20)
        g_printerr("native_grid_manual_2x2_geometry measured=%u x=%d,%d,%d,%d y=%d,%d,%d,%d width=%d..%d height=%d..%d\n",
                   measured, x_positions[0], x_positions[1], x_positions[2],
                   x_positions[3], y_positions[0], y_positions[1],
                   y_positions[2], y_positions[3], width_min, width_max,
                   height_min, height_max);
    return valid;
}

static gboolean smoke_page_panes_evenly_distributed(
    DeettyGridContext *root, GtkWidget *page, guint expected_count) {
    gint64 minimum_area = G_MAXINT64;
    gint64 maximum_area = 0;
    guint measured = 0;
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        DeettyGridContext *candidate = g_ptr_array_index(
            root->contexts, index);
        if (!candidate->active || candidate->page != page ||
            candidate->area == NULL) continue;
        GtkAllocation allocation;
        deetty_grid_widget_get_allocation(candidate->area, &allocation);
        gint64 area = (gint64)allocation.width * allocation.height;
        minimum_area = MIN(minimum_area, area);
        maximum_area = MAX(maximum_area, area);
        measured++;
    }
    return measured == expected_count && maximum_area > 0 &&
        (maximum_area - minimum_area) * 100 <= maximum_area * 5;
}

static gboolean finish_pane_close_smoke(gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    DeettyGridContext *closed = grid_context_for_pane(root, 1);
    DeettyGridContext *remaining = grid_context_for_pane(root, 2);
    gint current_index = deetty_grid_notebook_get_current_page(
        GTK_NOTEBOOK(root->notebook));
    GtkWidget *current_page = deetty_grid_notebook_get_nth_page(
        GTK_NOTEBOOK(root->notebook), current_index);
    root->pane_close_rendered_collapsed = closed != NULL &&
        !closed->active && closed->area == NULL && closed->page == NULL &&
        remaining != NULL && remaining->active && remaining->area != NULL &&
        deetty_grid_widget_get_parent(remaining->area) != NULL;
    if (remaining != NULL && remaining->area != NULL)
        deetty_grid_focus_widget(NULL, remaining->area);
    root->pane_close_remaining_focused = remaining != NULL &&
        remaining->active && remaining->pane_id == 2 &&
        remaining->page == current_page;

    root->pane_close_evenly_distributed =
        smoke_page_panes_evenly_distributed(root, current_page, 3);

    GtkWidget *layout = remaining != NULL
        ? grid_page_content_root(remaining, current_page) : NULL;
    if (deetty_grid_widget_is_type(layout, DEETTY_GTK_PANED)) {
        gint max_position = 0;
        g_object_get(G_OBJECT(layout), "max-position", &max_position, NULL);
        if (max_position > 0) {
            root->pane_close_resize_split = layout;
            root->pane_close_resize_position = MAX(1, max_position / 4);
            deetty_paned_set_position(
                layout, root->pane_close_resize_position);
        }
    }
    deetty_grid_source_timeout_add(120, finish_pane_close_resize_smoke, root);
    return G_SOURCE_REMOVE;
}

static gboolean continue_pane_close_smoke(gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    GtkWidget *menu = root->workspace_menu;
    gboolean menu_ready = menu != NULL && deetty_grid_widget_get_mapped(menu) &&
        deetty_grid_widget_get_mapped(root->window) && root->window_presented;
    GtkWidget *close_terminal = menu_ready
        ? find_workspace_menu_item(menu, "Close Terminal")
        : NULL;
    if (close_terminal == NULL || !deetty_grid_widget_get_sensitive(close_terminal)) {
        if (root->pane_close_smoke_attempts++ < 80) {
            if (root->pane_close_smoke_attempts % 20 == 0) {
                DeettyGridContext *target = grid_context_for_pane(root, 1);
                (void)open_smoke_workspace_menu(target);
            }
            deetty_grid_source_timeout_add(25, continue_pane_close_smoke, root);
            return G_SOURCE_REMOVE;
        }
        for (guint index = 0;
             root->contexts != NULL && index < root->contexts->len; index++) {
            DeettyGridContext *candidate = g_ptr_array_index(
                root->contexts, index);
            if (candidate->active && !candidate->exited &&
                candidate->write != NULL)
                (void)candidate->write(candidate->userdata, "\n", 1);
        }
        return G_SOURCE_REMOVE;
    }
    root->pane_close_smoke_attempts = 0;
    root->pane_close_menu_survived = 1;
    deetty_grid_menu_shell_select_item(GTK_MENU_SHELL(menu), close_terminal);
    deetty_grid_menu_shell_activate_item(GTK_MENU_SHELL(menu), close_terminal, TRUE);
    deetty_grid_source_timeout_add(180, finish_pane_close_smoke, root);
    return G_SOURCE_REMOVE;
}

static gboolean inspect_and_resize_pane_close_layout(gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    DeettyGridContext *pane = grid_context_for_pane(root, 1);
    GtkWidget *page = pane != NULL ? pane->page : NULL;
    root->pane_split_evenly_distributed =
        smoke_page_panes_evenly_distributed(root, page, 4);
    root->pane_split_two_by_two = smoke_page_is_even_two_by_two(root, page);
    gint width = 0;
    gint height = 0;
    deetty_grid_window_get_size(GTK_WINDOW(root->window), &width, &height);
    deetty_grid_window_resize(root->window, width + 320, height + 180);
    return G_SOURCE_REMOVE;
}

static gboolean disturb_pane_close_layout(gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    DeettyGridContext *pane = grid_context_for_pane(root, 1);
    GtkWidget *page = pane != NULL ? pane->page : NULL;
    root->pane_split_resize_equal = smoke_page_is_even_two_by_two(root, page);
    GtkWidget *layout = pane != NULL
        ? grid_page_content_root(pane, page) : NULL;
    if (deetty_grid_widget_is_type(layout, DEETTY_GTK_PANED)) {
        gint max_position = 0;
        g_object_get(G_OBJECT(layout), "max-position", &max_position, NULL);
        if (max_position > 0)
            deetty_paned_set_position(layout, MAX(1, max_position / 5));
    }
    return G_SOURCE_REMOVE;
}

static gboolean emit_pane_close_primary_split_right(gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    DeettyGridContext *target = grid_context_for_pane(root, 1);
    if (target != NULL) emit_grid_workspace_event(target, DEETTY_GRID_HOST_EVENT(WORKSPACE_SPLIT_CLOSE));
    return G_SOURCE_REMOVE;
}

static gboolean emit_pane_close_secondary_split_right(gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    DeettyGridContext *target = grid_context_for_pane(root, 2);
    if (target != NULL) emit_grid_workspace_event(target, DEETTY_GRID_HOST_EVENT(WORKSPACE_SPLIT_CLOSE));
    return G_SOURCE_REMOVE;
}

static gboolean request_pane_close_smoke(gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    DeettyGridContext *target = grid_context_for_pane(root, 1);
    DeettyGridContext *remaining = grid_context_for_pane(root, 2);
    root->pane_close_targeted_primary = target != NULL && target->primary &&
        target->active && target->area != NULL && remaining != NULL &&
        remaining->active && remaining->area != NULL;
    if (!root->pane_close_targeted_primary) return G_SOURCE_REMOVE;
    root->pane_close_smoke_attempts = 0;
    (void)open_smoke_workspace_menu(target);
    (void)on_window_focus_out(root->window, NULL, root);
    deetty_grid_source_timeout_add(250, continue_pane_close_smoke, root);
    return G_SOURCE_REMOVE;
}

static DeettyGridContext *terminal_chord_smoke_target(
    DeettyGridContext *context) {
    DeettyGridContext *root = root_grid_context(context);
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        DeettyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (candidate != root && candidate->active && !candidate->exited &&
            candidate->area != NULL && candidate->page != NULL)
            return candidate;
    }
    return NULL;
}

static gboolean request_terminal_interrupt_chord_smoke(gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    DeettyGridContext *target = terminal_chord_smoke_target(root);
    if (target == NULL) return G_SOURCE_REMOVE;
    deetty_grid_focus_widget(NULL, target->area);
    GdkEventKey event = {0};
    event.type = GDK_KEY_PRESS;
    event.keyval = GDK_KEY_c;
    event.state = GDK_CONTROL_MASK;
    gboolean handled = on_key_press(target->area, &event, target);
    root->terminal_chord_interrupt_focused = handled &&
        root->ctrl_c_local_interrupt &&
        deetty_grid_window_get_focus(GTK_WINDOW(root->window)) == target->area;
    GdkEventKey enter_event = {0};
    enter_event.type = GDK_KEY_PRESS;
    enter_event.window = deetty_grid_widget_get_window(target->area);
    enter_event.keyval = GDK_KEY_Return;
    root->terminal_chord_enter_forwarded =
        on_key_press(target->area, &enter_event, target) &&
        deetty_grid_window_get_focus(GTK_WINDOW(root->window)) == target->area;
    if (root->event != NULL)
        root->event(root->event_data, target->pane_id, DEETTY_GRID_HOST_EVENT(TERMINAL_INTERRUPT_CHORD),
                    root->terminal_chord_interrupt_focused &&
                        root->terminal_chord_enter_forwarded,
                    (uint64_t)(g_get_monotonic_time() / 1000));
    return G_SOURCE_REMOVE;
}

static gboolean finish_terminal_close_focus_smoke(gpointer user_data);

static gboolean request_terminal_close_chord_smoke(gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    DeettyGridContext *target = terminal_chord_smoke_target(root);
    if (target == NULL) return G_SOURCE_REMOVE;
    deetty_grid_focus_widget(NULL, target->area);
    root->terminal_chord_closed_pane_id = target->pane_id;
    GdkEventKey event = {0};
    event.type = GDK_KEY_PRESS;
    event.keyval = GDK_KEY_d;
    event.state = GDK_CONTROL_MASK;
    gboolean handled = on_key_press(target->area, &event, target);
    DeettyGridContext *remaining = active_grid_context(root);
    root->terminal_chord_close_exact = handled &&
        root->ctrl_d_close_attempted && root->ctrl_d_close_succeeded &&
        !target->active && target->area == NULL && target->page == NULL;
    root->terminal_chord_close_rendered = remaining != NULL &&
        remaining->active && remaining->area != NULL &&
        deetty_grid_widget_get_parent(remaining->area) == remaining->page;
    root->terminal_chord_close_session_stopped =
        root->pane_close_session_stopped;
    deetty_grid_source_idle_add(finish_terminal_close_focus_smoke, root);
    return G_SOURCE_REMOVE;
}

static gboolean finish_terminal_close_focus_smoke(gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    DeettyGridContext *remaining = active_grid_context(root);
    root->terminal_chord_remaining_focused = remaining != NULL &&
        remaining->active && remaining->area != NULL &&
        deetty_grid_window_get_focus(GTK_WINDOW(root->window)) == remaining->area;
    if (root->event != NULL && remaining != NULL)
        root->event(root->event_data, remaining->pane_id, DEETTY_GRID_HOST_EVENT(TERMINAL_CLOSE_CHORD),
                    root->terminal_chord_close_exact &&
                        root->terminal_chord_close_rendered &&
                        root->terminal_chord_close_session_stopped &&
                        root->terminal_chord_remaining_focused,
                    root->terminal_chord_closed_pane_id);
    return G_SOURCE_REMOVE;
}

static gboolean request_terminal_final_pane_guard_smoke(gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    DeettyGridContext *remaining = active_grid_context(root);
    if (remaining == NULL || remaining->area == NULL) return G_SOURCE_REMOVE;
    GdkEventKey event = {0};
    event.type = GDK_KEY_PRESS;
    event.keyval = GDK_KEY_d;
    event.state = GDK_CONTROL_MASK;
    gboolean handled = on_key_press(remaining->area, &event, remaining);
    root->terminal_chord_final_protected = handled &&
        active_grid_context_count(root) == 1 && remaining->active &&
        remaining->area != NULL && remaining->page != NULL;
    if (root->event != NULL)
        root->event(root->event_data, remaining->pane_id, DEETTY_GRID_HOST_EVENT(FINAL_PANE_GUARD),
                    root->terminal_chord_final_protected,
                    (uint64_t)(g_get_monotonic_time() / 1000));
    return G_SOURCE_REMOVE;
}

static gboolean finish_terminal_chord_smoke(gpointer user_data) {
    DeettyGridContext *remaining = active_grid_context(user_data);
    if (remaining != NULL && remaining->write != NULL)
        (void)remaining->write(remaining->userdata, "done\n", 5);
    return G_SOURCE_REMOVE;
}

static guint preset_unique_band_count(const gint *values, guint count) {
    gint bands[16] = {0};
    guint band_count = 0;
    for (guint index = 0; index < count; index++) {
        gboolean found = FALSE;
        for (guint band = 0; band < band_count; band++) {
            if (ABS(values[index] - bands[band]) <= 12) {
                found = TRUE;
                break;
            }
        }
        if (!found && band_count < G_N_ELEMENTS(bands))
            bands[band_count++] = values[index];
    }
    return band_count;
}

static gboolean verify_layout_preset_geometry(DeettyGridContext *context,
                                              guint rows, guint cols) {
    DeettyGridContext *root = root_grid_context(context);
    gint current_index = deetty_grid_notebook_get_current_page(
        GTK_NOTEBOOK(root->notebook));
    GtkWidget *page = deetty_grid_notebook_get_nth_page(GTK_NOTEBOOK(root->notebook),
                                                current_index);
    gint centers_x[16] = {0};
    gint centers_y[16] = {0};
    gint min_width = G_MAXINT;
    gint max_width = 0;
    gint min_height = G_MAXINT;
    gint max_height = 0;
    guint count = 0;
    gboolean mapped = TRUE;
    gboolean io_ready = TRUE;
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        DeettyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (!candidate->active || candidate->exited ||
            candidate->page != page || candidate->area == NULL) continue;
        if (count >= G_N_ELEMENTS(centers_x)) return FALSE;
        GtkAllocation allocation;
        gint x = 0;
        gint y = 0;
        deetty_grid_widget_get_allocation(candidate->area, &allocation);
        gboolean translated = deetty_grid_widget_translate_coordinates(
            candidate->area, page, 0, 0, &x, &y);
        mapped = mapped && deetty_grid_widget_get_mapped(candidate->area) &&
            translated;
        io_ready = io_ready &&
            ((candidate->descriptor_tick_coalesced &&
              candidate->pty_event_source_started &&
              candidate->tick_source == 0) ||
             (!candidate->descriptor_tick_coalesced &&
              candidate->tick_source != 0));
        centers_x[count] = x + allocation.width / 2;
        centers_y[count] = y + allocation.height / 2;
        min_width = MIN(min_width, allocation.width);
        max_width = MAX(max_width, allocation.width);
        min_height = MIN(min_height, allocation.height);
        max_height = MAX(max_height, allocation.height);
        count++;
    }
    guint target_count = rows * cols;
    guint x_bands = preset_unique_band_count(centers_x, count);
    guint y_bands = preset_unique_band_count(centers_y, count);
    gint width_tolerance = rows == 2 && cols == 2
        ? 8 : MAX(16, max_width / 5);
    gint height_tolerance = rows == 2 && cols == 2
        ? 8 : MAX(16, max_height / 5);
    gboolean balanced = max_width - min_width <= width_tolerance &&
        max_height - min_height <= height_tolerance;
    gboolean valid = mapped && io_ready && count == target_count &&
        x_bands == cols && y_bands == rows && balanced;
    if (!valid && (root->workspace_smoke == 21 ||
                   root->workspace_smoke == 43))
        g_printerr("native_grid_layout_geometry rows=%u cols=%u count=%u mapped=%d io_ready=%d x_bands=%u y_bands=%u width=%d..%d height=%d..%d balanced=%d\n",
                   rows, cols, count, mapped, io_ready, x_bands, y_bands,
                   min_width, max_width, min_height, max_height, balanced);
    return valid;
}

static guint count_grid_nonblank(DeettyGridContext *context, guint limit) {
    if (context == NULL || limit == 0 || context->frame == NULL ||
        context->columns <= 0 || context->rows <= 0)
        return 0;
    uint64_t *cells = g_try_malloc_n(
        (gsize)context->columns, sizeof(*cells));
    if (cells == NULL) return 0;
    guint count = 0;
    for (int row = 0; row < context->rows && count < limit; row++) {
        if (context->frame(
                context->userdata, row, 1, cells,
                (size_t)context->columns) != 1)
            continue;
        for (int column = 0;
             column < context->columns && count < limit;
             column++) {
            uint32_t glyph = (uint32_t)cells[column];
            if (glyph != 0 && glyph != ' ') count++;
        }
    }
    g_free(cells);
    return count;
}

static gboolean verify_layout_terminals_ready(DeettyGridContext *context,
                                               guint expected) {
    DeettyGridContext *root = root_grid_context(context);
    GtkWidget *page = deetty_grid_notebook_get_nth_page(
        GTK_NOTEBOOK(root->notebook),
        deetty_grid_notebook_get_current_page(GTK_NOTEBOOK(root->notebook)));
    guint ready = 0;
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        DeettyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (!candidate->active || candidate->exited ||
            candidate->page != page || candidate->area == NULL)
            continue;
        gboolean nonblank = count_grid_nonblank(candidate, 1) > 0;
        /* Buffer content alone does not prove a visible pane. Requiring the
         * draw callback catches mapped terminals that GTK has not painted. */
        if (grid_context_session_available(candidate) &&
            deetty_grid_widget_get_parent(candidate->area) != NULL &&
            deetty_grid_widget_get_mapped(candidate->area) && candidate->saw_draw &&
            nonblank)
            ready++;
    }
    return ready == expected;
}

static gboolean verify_layout_auto_fit(DeettyGridContext *context) {
    DeettyGridContext *root = root_grid_context(context);
    GtkWidget *page = deetty_grid_notebook_get_nth_page(
        GTK_NOTEBOOK(root->notebook),
        deetty_grid_notebook_get_current_page(GTK_NOTEBOOK(root->notebook)));
    guint count = 0;
    gboolean fitted = TRUE;
    gboolean overlay = TRUE;
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        DeettyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (!candidate->active || candidate->exited ||
            candidate->page != page) continue;
        count++;
        fitted = fitted && candidate->font_size <
            candidate->requested_font_size && candidate->columns >= 80 &&
            candidate->rows >= 24;
        overlay = overlay && candidate->resize_overlay_zoom_percent < 100 &&
            candidate->resize_overlay_show_count > 0 &&
            candidate->resize_overlay_drawn;
    }
    return count == 16 && fitted && overlay;
}

static gboolean write_layout_smoke_input(DeettyGridContext *context,
                                           const char *bytes,
                                           size_t length) {
    if (context->write == NULL ||
        context->write(context->userdata, bytes, length) != (int)length)
        return FALSE;
    /* TerminalSession writes may be buffered under PTY backpressure. Production
     * keyboard paths already arm this source; smoke-generated input must do the
     * same or a busy 16-pane fixture can retain queued keys indefinitely. */
    schedule_grid_write_flush(context);
    return TRUE;
}

static gboolean verify_layout_tui(DeettyGridContext *context) {
    const char *tui = g_getenv("DEETTY_LAYOUT_TUI");
    DeettyGridContext *root = root_grid_context(context);
    if (tui == NULL || tui[0] == '\0') return TRUE;
    GtkWidget *page = deetty_grid_notebook_get_nth_page(
        GTK_NOTEBOOK(root->notebook),
        deetty_grid_notebook_get_current_page(GTK_NOTEBOOK(root->notebook)));
    guint rendered = 0;
    guint input = 0;
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        DeettyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (!candidate->active || candidate->exited ||
            candidate->page != page) continue;
        guint nonblank = count_grid_nonblank(candidate, 8);
        if (nonblank >= 8) rendered++;
        if (write_layout_smoke_input(candidate, "l", 1)) input++;
    }
    if (rendered != 16 || input != 16)
        g_printerr("native_grid_layout_tui_not_ready app=%s rendered=%u input=%u\n",
                   tui, rendered, input);
    return rendered == 16 && input == 16;
}

static gboolean verify_layout_floor_feedback(DeettyGridContext *context) {
    DeettyGridContext *root = root_grid_context(context);
    DeettyGridContext *candidate = active_grid_context(root);
    if (candidate == NULL || candidate->area == NULL) return FALSE;
    GtkAllocation actual;
    deetty_grid_widget_get_allocation(candidate->area, &actual);
    GtkAllocation impossible = { .x = 0, .y = 0, .width = 100, .height = 80 };
    resize_grid_to_allocation(candidate, &impossible);
    gboolean reached = candidate->resize_overlay_floor_reached &&
        fabs(candidate->font_size - 3.0) < 0.01;
    resize_grid_to_allocation(candidate, &actual);
    return reached;
}

static gboolean apply_layout_preset_smoke_stage(gpointer user_data);

static void finish_layout_preset_smoke_sessions(DeettyGridContext *root) {
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        DeettyGridContext *candidate = g_ptr_array_index(
            root->contexts, index);
        if (candidate->active && candidate->write != NULL) {
            const char *tui = g_getenv("DEETTY_LAYOUT_TUI");
            if (g_strcmp0(tui, "vim") == 0)
                (void)write_layout_smoke_input(
                    candidate, "\033:q!\r", 5);
            else if (g_strcmp0(tui, "btop") == 0)
                (void)write_layout_smoke_input(candidate, "\003", 1);
            else
                (void)write_layout_smoke_input(
                    candidate, "exit 0\n", 7);
        }
    }
}

static gboolean check_layout_preset_smoke(gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    DeettyGridContext *remaining;
    if (root->layout_preset_smoke_stage == 9) {
        gboolean geometry = verify_layout_preset_geometry(root, 4, 4);
        gboolean terminals = verify_layout_terminals_ready(root, 16);
        gboolean tui = geometry && terminals && verify_layout_tui(root);
        root->layout_preset_4x4_rendered =
            root->layout_preset_4x4_applied && geometry && terminals && tui;
        if (!root->layout_preset_4x4_rendered &&
            root->layout_preset_smoke_attempts++ < 40) {
            GtkWidget *page = deetty_grid_notebook_get_nth_page(
                GTK_NOTEBOOK(root->notebook),
                deetty_grid_notebook_get_current_page(GTK_NOTEBOOK(root->notebook)));
            if (page != NULL) queue_grid_preset_widget_draw(page, NULL);
            deetty_grid_source_timeout_add(50, check_layout_preset_smoke, root);
            return G_SOURCE_REMOVE;
        }
        if (!root->layout_preset_4x4_rendered)
            g_printerr("native_grid_4x4_not_ready applied=%d geometry=%d terminals=%d tui=%d attempts=%d\n",
                       root->layout_preset_4x4_applied, geometry, terminals,
                       tui, root->layout_preset_smoke_attempts);
        finish_layout_preset_smoke_sessions(root);
    } else if (root->layout_preset_smoke_stage == 2) {
        gboolean rendered =
            root->layout_preset_2x2_applied &&
            verify_layout_preset_geometry(root, 2, 2);
        root->layout_preset_2x2_rendered =
            root->layout_preset_churn_rounds == 1
                ? rendered
                : root->layout_preset_2x2_rendered && rendered;
        root->layout_preset_smoke_stage = 1;
        deetty_grid_source_timeout_add(180, apply_layout_preset_smoke_stage, root);
    } else if (root->layout_preset_smoke_stage == 3) {
        root->layout_preset_4x2_rendered =
            root->layout_preset_4x2_applied &&
            verify_layout_preset_geometry(root, 2, 4);
        root->layout_preset_smoke_stage = 1;
        deetty_grid_source_timeout_add(180, apply_layout_preset_smoke_stage, root);
    } else if (root->layout_preset_smoke_stage == 4) {
        root->layout_preset_3x3_rendered =
            root->layout_preset_3x3_applied &&
            verify_layout_preset_geometry(root, 3, 3);
        root->layout_preset_smoke_stage = 5;
        deetty_grid_source_timeout_add(180, apply_layout_preset_smoke_stage, root);
    } else if (root->layout_preset_smoke_stage == 5) {
        gboolean geometry = verify_layout_preset_geometry(root, 4, 4);
        gboolean auto_fit = verify_layout_auto_fit(root);
        gboolean terminals = verify_layout_terminals_ready(root, 16);
        gboolean tui = verify_layout_tui(root);
        gboolean floor = verify_layout_floor_feedback(root);
        root->layout_preset_4x4_rendered =
            root->layout_preset_4x4_applied && geometry && auto_fit &&
            terminals && tui && floor;
        root->layout_preset_finalizing = 1;
        root->layout_preset_smoke_stage = 6;
        deetty_grid_source_timeout_add(180, apply_layout_preset_smoke_stage, root);
    } else if (root->layout_preset_smoke_stage == 6) {
        root->layout_preset_4x4_rendered =
            root->layout_preset_4x4_rendered &&
            root->layout_preset_prompt_cancelled == 1 &&
            verify_layout_preset_geometry(root, 4, 4);
        root->layout_preset_smoke_stage = 7;
        deetty_grid_source_timeout_add(180, apply_layout_preset_smoke_stage, root);
    } else if (root->layout_preset_smoke_stage == 8) {
        gint current_index = deetty_grid_notebook_get_current_page(
            GTK_NOTEBOOK(root->notebook));
        GtkWidget *production_page = deetty_grid_notebook_get_nth_page(
            GTK_NOTEBOOK(root->notebook), current_index);
        gboolean geometry = verify_layout_preset_geometry(root, 4, 4);
        gboolean terminals = verify_layout_terminals_ready(root, 16);
        gboolean auto_fit = verify_layout_auto_fit(root);
        gboolean tui = geometry && terminals && verify_layout_tui(root);
        gboolean rendered = root->layout_preset_4x4_applied &&
            geometry && terminals && auto_fit && tui;
        root->layout_preset_4x4_rendered = rendered;
        if (!rendered && root->layout_preset_smoke_attempts++ < 40) {
            GtkWidget *page = deetty_grid_notebook_get_nth_page(
                GTK_NOTEBOOK(root->notebook),
                deetty_grid_notebook_get_current_page(GTK_NOTEBOOK(root->notebook)));
            if (page != NULL) {
                deetty_grid_widget_queue_resize(page);
                queue_grid_preset_widget_draw(page, NULL);
            }
            deetty_grid_source_timeout_add(50, check_layout_preset_smoke, root);
            return G_SOURCE_REMOVE;
        }
        if (production_page != NULL && production_page != root->page)
            (void)close_grid_tab(root, production_page);
        finish_layout_preset_smoke_sessions(root);
    } else if (root->layout_preset_smoke_stage == 7) {
        gint source_index = deetty_grid_notebook_page_num(
            GTK_NOTEBOOK(root->notebook), root->page);
        GtkWidget *overflow_page = deetty_grid_notebook_get_nth_page(
            GTK_NOTEBOOK(root->notebook), source_index == 0 ? 1 : 0);
        if (source_index >= 0)
            deetty_grid_notebook_select_page(root->notebook, source_index);
        gboolean sessions_ready = active_grid_context_count(root) == 16;
        for (guint index = 0; root->contexts != NULL &&
             index < root->contexts->len; index++) {
            DeettyGridContext *candidate = g_ptr_array_index(
                root->contexts, index);
            if (candidate->active)
                sessions_ready = sessions_ready &&
                    grid_context_session_available(candidate) &&
                    candidate->write != NULL;
        }
        root->layout_preset_1x1_rendered =
            root->layout_preset_1x1_rendered &&
            root->layout_preset_1x1_applied &&
            verify_layout_preset_geometry(root, 1, 1) &&
            root->layout_preset_prompt_accepted == 1 &&
            root->layout_preset_moved_count == 15 &&
            deetty_grid_notebook_get_n_pages(GTK_NOTEBOOK(root->notebook)) == 2 &&
            grid_contexts_on_page(root, overflow_page) == 15 &&
            sessions_ready;
        remaining = root;
        if (remaining->active && remaining->area != NULL)
            deetty_grid_focus_widget(NULL, remaining->area);
        root->layout_preset_remaining_focused = remaining != NULL &&
            remaining->active && remaining->area != NULL &&
            remaining->page == root->page;
        root->layout_preset_smoke_stage = 8;
        if (!open_grid_layout_preset_tab(root, DEETTY_GRID_HOST_EVENT(LAYOUT_PRESET_4X4))) {
            root->layout_preset_4x4_rendered = 0;
            finish_layout_preset_smoke_sessions(root);
        } else {
            deetty_grid_source_timeout_add(420, check_layout_preset_smoke, root);
        }
    } else if (root->layout_preset_smoke_stage == 1) {
        gboolean rendered = root->layout_preset_1x1_applied &&
            verify_layout_preset_geometry(root, 1, 1);
        if (!root->layout_preset_finalizing) {
            root->layout_preset_churn_rounds++;
            root->layout_preset_1x1_rendered =
                root->layout_preset_churn_rounds == 1
                    ? rendered
                    : root->layout_preset_1x1_rendered && rendered;
            root->layout_preset_smoke_stage =
                root->layout_preset_churn_rounds < 8 ? 2 : 4;
            deetty_grid_source_timeout_add(180, apply_layout_preset_smoke_stage, root);
        }
    }
    return G_SOURCE_REMOVE;
}

static gboolean continue_layout_preset_smoke(gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    GtkWidget *menu = root->workspace_menu;
    gboolean menu_ready = menu != NULL && deetty_grid_widget_get_mapped(menu) &&
        deetty_grid_widget_get_mapped(root->window) && root->window_presented;
    if (root->workspace_smoke == 43) {
        GtkWidget *layout_4x4 = menu_ready
            ? find_workspace_menu_item(menu, "New 4×4") : NULL;
        gboolean route_ready = layout_4x4 != NULL &&
            GPOINTER_TO_INT(deetty_grid_object_get_data(
                G_OBJECT(layout_4x4), "deetty-workspace-event")) == DEETTY_GRID_HOST_EVENT(LAYOUT_PRESET_4X4);
        if (!route_ready) {
            if (root->layout_preset_smoke_attempts++ < 40) {
                if (root->layout_preset_smoke_attempts == 20)
                    (void)open_smoke_workspace_menu(active_grid_context(root));
                deetty_grid_source_timeout_add(25, continue_layout_preset_smoke, root);
            } else {
                DeettyGridContext *remaining = active_grid_context(root);
                if (remaining != NULL && remaining->write != NULL)
                    (void)remaining->write(remaining->userdata, "exit 1\n", 7);
            }
            return G_SOURCE_REMOVE;
        }
        root->layout_preset_menu_survived = 1;
        root->layout_preset_smoke_attempts = 0;
        deetty_grid_menu_shell_select_item(GTK_MENU_SHELL(menu), layout_4x4);
        deetty_grid_menu_shell_activate_item(GTK_MENU_SHELL(menu), layout_4x4, TRUE);
        deetty_grid_source_timeout_add(600, check_layout_preset_smoke, root);
        return G_SOURCE_REMOVE;
    }
    GtkWidget *layout_1x1 = menu_ready
        ? find_workspace_menu_item(menu, "New 1×1") : NULL;
    GtkWidget *layout_2x2 = menu_ready
        ? find_workspace_menu_item(menu, "New 2×2") : NULL;
    GtkWidget *layout_4x2 = menu_ready
        ? find_workspace_menu_item(menu, "New 4×2") : NULL;
    GtkWidget *layout_3x3 = menu_ready
        ? find_workspace_menu_item(menu, "New 3×3") : NULL;
    GtkWidget *layout_4x4 = menu_ready
        ? find_workspace_menu_item(menu, "New 4×4") : NULL;
    gboolean routes_ready =
        layout_1x1 == NULL && layout_2x2 != NULL && layout_4x2 != NULL &&
        layout_3x3 != NULL && layout_4x4 != NULL &&
        GPOINTER_TO_INT(deetty_grid_object_get_data(
            G_OBJECT(layout_2x2), "deetty-workspace-event")) == DEETTY_GRID_HOST_EVENT(LAYOUT_PRESET_2X2) &&
        GPOINTER_TO_INT(deetty_grid_object_get_data(
            G_OBJECT(layout_4x2), "deetty-workspace-event")) == DEETTY_GRID_HOST_EVENT(LAYOUT_PRESET_4X2) &&
        GPOINTER_TO_INT(deetty_grid_object_get_data(
            G_OBJECT(layout_3x3), "deetty-workspace-event")) == DEETTY_GRID_HOST_EVENT(LAYOUT_PRESET_3X3) &&
        GPOINTER_TO_INT(deetty_grid_object_get_data(
            G_OBJECT(layout_4x4), "deetty-workspace-event")) == DEETTY_GRID_HOST_EVENT(LAYOUT_PRESET_4X4);
    if (!routes_ready) {
        if (root->layout_preset_smoke_attempts++ < 40) {
            if (root->layout_preset_smoke_attempts == 20)
                (void)open_smoke_workspace_menu(active_grid_context(root));
            deetty_grid_source_timeout_add(25, continue_layout_preset_smoke, root);
        } else {
            DeettyGridContext *remaining = active_grid_context(root);
            if (remaining != NULL && remaining->write != NULL)
                (void)remaining->write(remaining->userdata, "exit 1\n", 7);
        }
        return G_SOURCE_REMOVE;
    }
    root->layout_preset_menu_survived = 1;
    deetty_grid_menu_shell_select_item(GTK_MENU_SHELL(menu), layout_4x2);
    deetty_grid_menu_shell_activate_item(GTK_MENU_SHELL(menu), layout_4x2, TRUE);
    deetty_grid_source_timeout_add(420, check_layout_preset_smoke, root);
    return G_SOURCE_REMOVE;
}

static gboolean apply_layout_preset_smoke_stage(gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    DeettyGridContext *target = active_grid_context(root);
    if (target == NULL || target->area == NULL) return G_SOURCE_REMOVE;
    int event_code = root->layout_preset_smoke_stage == 5
        ? DEETTY_GRID_HOST_EVENT(LAYOUT_PRESET_4X4)
        : root->layout_preset_smoke_stage == 4
        ? DEETTY_GRID_HOST_EVENT(LAYOUT_PRESET_3X3)
        : root->layout_preset_smoke_stage == 3
        ? DEETTY_GRID_HOST_EVENT(LAYOUT_PRESET_4X2)
        : root->layout_preset_smoke_stage == 2
        ? DEETTY_GRID_HOST_EVENT(LAYOUT_PRESET_2X2)
        : DEETTY_GRID_HOST_EVENT(LAYOUT_PRESET_1X1);
    emit_grid_workspace_event(target, event_code);
    deetty_grid_source_timeout_add(420, check_layout_preset_smoke, root);
    return G_SOURCE_REMOVE;
}

static gboolean request_layout_preset_smoke(gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    DeettyGridContext *target = active_grid_context(root);
    if (target == NULL || target->area == NULL) return G_SOURCE_REMOVE;
    root->layout_preset_smoke_attempts = 0;
    (void)open_smoke_workspace_menu(target);
    (void)on_window_focus_out(root->window, NULL, root);
    deetty_grid_source_timeout_add(250, continue_layout_preset_smoke, root);
    return G_SOURCE_REMOVE;
}

static gboolean start_layout_preset_smoke(gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    root->layout_preset_churn_rounds = 0;
    root->layout_preset_finalizing = 0;
    root->layout_preset_smoke_stage =
        root->workspace_smoke == 43 ? 9 : 3;
    return request_layout_preset_smoke(root);
}

static gboolean handle_terminal_scrollbar_motion(
    DeettyGridContext *context, GtkWidget *widget, GdkEventMotion *event) {
    if (!context->scrollbar_dragging) return FALSE;
    GtkAllocation allocation;
    deetty_grid_widget_get_allocation(widget, &allocation);
    DeettyTerminalScrollbarGeometry geometry;
    if (!terminal_scrollbar_geometry(context, allocation, &geometry))
        return TRUE;

    uint64_t target_offset = 0;
    if (deetty_grid_scrollbar_drag_target(
            &geometry, event->y, context->scrollbar_drag_offset,
            &target_offset) != 0 &&
        scroll_terminal_to_offset(context, target_offset))
        root_grid_context(context)->compact_scrollbar_thumb_dragged = 1;
    return TRUE;
}

static gboolean on_mouse_motion(GtkWidget *widget, GdkEventMotion *event, gpointer user_data) {
    DeettyGridContext *context = user_data;
    if (!grid_context_session_available(context) || context->exited)
        return FALSE;
    GtkAllocation allocation;
    deetty_grid_widget_get_allocation(widget, &allocation);
    DeettyTerminalScrollbarGeometry scrollbar;
    gboolean scrollbar_hovered =
        terminal_scrollbar_geometry(context, allocation, &scrollbar) &&
        event->x >= scrollbar.x &&
        event->x <= scrollbar.x + scrollbar.width &&
        event->y >= scrollbar.thumb_y &&
        event->y <= scrollbar.thumb_y + scrollbar.thumb_height;
    if (context->scrollbar_hovered != scrollbar_hovered) {
        context->scrollbar_hovered = scrollbar_hovered;
        deetty_grid_widget_queue_draw(context->area);
    }
    if (handle_terminal_scrollbar_motion(context, widget, event)) return TRUE;
    if (context->focus_follows_pointer && !(event->state & GDK_BUTTON1_MASK) &&
        !deetty_grid_widget_has_focus(widget)) deetty_grid_focus_widget(NULL, widget);
    if (!context->selection_dragging) return FALSE;
    if (!(event->state & GDK_BUTTON1_MASK)) {
        context->selection_dragging = 0;
        return FALSE;
    }
    context->selection_end_column =
        grid_column_at_pointer(context, event->x);
    context->selection_end_row = grid_row_at_pointer(context, event->y);
    context->selecting =
        context->selection_start_column != context->selection_end_column ||
        context->selection_start_row != context->selection_end_row;
    deetty_grid_widget_queue_draw(context->area);
    return TRUE;
}

static gboolean on_grid_area_leave(GtkWidget *widget, GdkEventCrossing *event,
                                   gpointer user_data) {
    (void)widget;
    (void)event;
    DeettyGridContext *context = user_data;
    if (context->scrollbar_hovered) {
        context->scrollbar_hovered = 0;
        deetty_grid_widget_queue_draw(context->area);
    }
    return FALSE;
}

static int terminal_scroll_steps(DeettyGridContext *context,
                                 GdkEventScroll *event) {
    return deetty_grid_scroll_steps(
        context->terminal_scroll_lines, context->terminal_smooth_scroll,
        deetty_grid_scroll_direction((int)event->direction), event->delta_y,
        &context->terminal_scroll_accumulator);
}

static gboolean report_terminal_mouse_wheel(
    DeettyGridContext *context, GdkEventScroll *event, int steps) {
    if (steps == 0) return TRUE;
    int column = grid_column_at_pointer(context, event->x);
    int row = grid_row_at_pointer(context, event->y);
    int button = steps > 0 ? 64 : 65;
    gboolean delivered = TRUE;
    acknowledge_grid_attention(context);
    for (int step = 0; step < ABS(steps); step++) {
        int result =
            context->mouse(context->userdata, column, row, button, 1);
        if (result <= 0) delivered = FALSE;
    }
    if (!delivered)
        show_status_feedback(
            context,
            deetty_grid_status_feedback_message(
                DEETTY_GRID_FEEDBACK_MOUSE_WHEEL));
#if DEETTY_ENABLE_SMOKE
    DeettyGridContext *root = root_grid_context(context);
    if (delivered && root->workspace_smoke == 42)
        root->compact_scrollbar_tui_forwarded = 1;
    if (delivered && root->workspace_smoke == 15 &&
        column >= 0 && column < context->columns &&
        row >= 0 && row < context->rows)
        root->compact_tui_wheel_mapping |= steps > 0 ? 1 : 2;
#endif
    if (delivered) schedule_grid_write_flush(context);
    return TRUE;
}

static gboolean report_terminal_wheel_keys(
    DeettyGridContext *context, int steps) {
    uint8_t sequence[192];
    int length = deetty_grid_wheel_key_sequence(
        context->cursor_mode(context->userdata), steps, sequence,
        sizeof(sequence));
    if (length <= 0) return TRUE;
    acknowledge_grid_attention(context);
    if (context->write(
            context->userdata, (const char *)sequence,
            (size_t)length) == length) {
        schedule_grid_write_flush(context);
    } else {
        show_status_feedback(
            context,
            deetty_grid_status_feedback_message(
                DEETTY_GRID_FEEDBACK_ALT_SCROLL));
    }
    return TRUE;
}

static gboolean on_scroll(GtkWidget *widget, GdkEventScroll *event, gpointer user_data) {
    DeettyGridContext *context = user_data;
    if (!grid_context_session_available(context) || context->exited)
        return FALSE;
    GtkAllocation allocation;
    deetty_grid_widget_get_allocation(widget, &allocation);
    DeettyTerminalScrollbarGeometry scrollbar;
    gboolean scrollbar_owned =
        terminal_scrollbar_geometry(context, allocation, &scrollbar) &&
        event->x >= scrollbar.x;
    int terminal_mode_flags =
        scrollbar_owned ? 0 : context->mouse_mode(context->userdata);
    uint64_t history_lines = 0;
    uint64_t viewport_offset = 0;
    uint32_t visible_rows = 0;
    int history_available = 0;
    if (terminal_mode_flags & DEETTY_GRID_TERMINAL_MODE_ALTERNATE_SCREEN) {
        if (deetty_grid_scroll_state(
                context->userdata, &history_lines, &viewport_offset,
                &visible_rows) == 0)
            history_available = history_lines > 0;
    }
    DeettyGridContext *root = root_grid_context(context);
    DeettyGridScrollRoutePlan scroll_plan = {0};
    deetty_grid_scroll_route_plan(
        scrollbar_owned,
        terminal_mode_flags,
        history_available,
        deetty_grid_input_modifiers(event->state),
        deetty_grid_scroll_direction((int)event->direction),
        event->delta_y,
        &root->tab_cycle_scroll_accumulator,
        &root->pane_cycle_scroll_accumulator,
        &context->font_scroll_accumulator,
        &scroll_plan);
    const int route = scroll_plan.route;
    /* The native rail owns pointer events inside its visible hit target even
     * when the foreground TUI enables terminal mouse reporting. Otherwise
     * full-screen apps consume the wheel before DEETTY can move history. */
    if (route == DEETTY_GRID_ROUTE_SCROLLBAR) {
        int steps = terminal_scroll_steps(context, event);
        if (steps != 0)
            (void)scroll_terminal_by_lines(context, steps);
        deetty_grid_widget_queue_draw(context->area);
        return TRUE;
    }
    if (route == DEETTY_GRID_ROUTE_TAB_CYCLE ||
        route == DEETTY_GRID_ROUTE_PANE_CYCLE ||
        route == DEETTY_GRID_ROUTE_FONT_ZOOM) {
        if (route == DEETTY_GRID_ROUTE_TAB_CYCLE) {
            for (int step = 0; step < scroll_plan.steps; step++) {
                (void)cycle_grid_tab(context, scroll_plan.direction);
                show_active_tab_cycle_feedback(root);
            }
        } else if (route == DEETTY_GRID_ROUTE_PANE_CYCLE) {
            for (int step = 0; step < scroll_plan.steps; step++)
                (void)cycle_grid_pane(context, scroll_plan.direction);
        } else if (scroll_plan.steps != 0) {
            (void)apply_pane_font_size(
                context,
                context->requested_font_size +
                    scroll_plan.steps * scroll_plan.direction,
                TRUE);
        }
        return TRUE;
    }
    int steps = terminal_scroll_steps(context, event);
    if (route == DEETTY_GRID_ROUTE_TERMINAL_SCROLL) {
        if (steps != 0)
            (void)scroll_terminal_by_lines(context, steps);
        if (context->workspace_smoke == 15 && steps != 0)
            root_grid_context(context)->compact_plain_scroll_preserved = 1;
        deetty_grid_widget_queue_draw(context->area);
        return TRUE;
    }
    if (route == DEETTY_GRID_ROUTE_APPLICATION_MOUSE)
        return report_terminal_mouse_wheel(context, event, steps);
    if (route == DEETTY_GRID_ROUTE_APPLICATION_KEYS)
        return report_terminal_wheel_keys(context, steps);
    return TRUE;
}

static GtkTargetEntry deetty_pane_drag_targets[] = {{"application/x-deetty-pane", GTK_TARGET_SAME_APP, 0}};

static void on_pane_drag_data_get(GtkWidget *widget, GdkDragContext *drag, GtkSelectionData *selection, guint info, guint time, gpointer user_data) {
    (void)widget; (void)drag; (void)info; (void)time;
    DeettyGridContext *context = user_data;
    if (!grid_context_session_available(context) || context->exited) return;
    char pane[32] = {0};
    int length = deetty_grid_decimal_text(
        (int64_t)context->pane_id, (unsigned char *)pane, sizeof(pane));
    if (length <= 0) return;
    deetty_grid_selection_data_set_text(selection, pane, length);
}

static void on_pane_drag_data_received(GtkWidget *widget, GdkDragContext *drag, gint x, gint y, GtkSelectionData *selection, guint info, guint time, gpointer user_data) {
    (void)widget; (void)x; (void)y; (void)info;
    DeettyGridContext *context = user_data;
    gboolean moved = FALSE;
    if (!grid_context_session_available(context) || context->exited) {
        deetty_grid_drag_finish(drag, FALSE, FALSE, time);
        return;
    }
    gchar *text = deetty_grid_selection_data_get_text(selection);
    if (text != NULL) {
        guint64 source_pane = g_ascii_strtoull(text, NULL, 10);
        DeettyGridContext *source =
            grid_context_for_pane(context, source_pane);
        if (source_pane > 0 && source_pane <= G_MAXINT &&
            source != NULL && source->page != context->page) {
            if (context->event != NULL) {
                context->event(context->event_data, context->pane_id, DEETTY_GRID_HOST_EVENT(PANE_MOVED),
                               (int)source_pane,
                               (uint64_t)(g_get_monotonic_time() / 1000));
            }
            moved = move_grid_context(source, context);
        }
        deetty_grid_memory_free(text);
    }
    deetty_grid_drag_finish(drag, moved, moved, time);
}

static gboolean arm_resize_overlay(gpointer user_data) {
    DeettyGridContext *context = user_data;
    context->resize_overlay_arm_source = 0;
    context->resize_overlay_armed = 1;
    if (context->resize_overlay_zoom_percent > 0 &&
        context->resize_overlay_zoom_percent < 100)
        show_resize_overlay(context, context->columns, context->rows);
    return G_SOURCE_REMOVE;
}

static gboolean hide_resize_overlay(gpointer user_data) {
    DeettyGridContext *context = user_data;
    context->resize_overlay_hide_source = 0;
    context->resize_overlay_visible = 0;
    context->resize_overlay_hidden = 1;
    if (context->area != NULL) deetty_grid_widget_queue_draw(context->area);
    return G_SOURCE_REMOVE;
}

static void show_resize_overlay(DeettyGridContext *context,
                                int columns, int rows) {
    if (!context->resize_overlay_armed) {
        context->resize_overlay_initial_suppressed = 1;
        return;
    }
    if (context->resize_overlay_visible) context->resize_overlay_update_count++;
    else context->resize_overlay_show_count++;
    context->resize_overlay_columns = columns;
    context->resize_overlay_rows = rows;
    context->resize_overlay_visible = 1;
    context->resize_overlay_hidden = 0;
    DeettyGridLifecycleTimingPlan timing = {0};
    deetty_grid_lifecycle_timing_plan(&timing);
    if (context->resize_overlay_hide_source != 0)
        deetty_grid_source_remove(context->resize_overlay_hide_source);
    context->resize_overlay_hide_source =
        deetty_grid_source_timeout_add(
            (guint)timing.resize_overlay_hide_ms,
            hide_resize_overlay, context);
    deetty_grid_widget_queue_draw(context->area);
}

static gboolean commit_grid_resize(gpointer user_data) {
    DeettyGridContext *context = user_data;
    context->resize_commit_source = 0;
    if (!grid_context_session_available(context) || context->exited)
        return G_SOURCE_REMOVE;
    int columns = context->pending_resize_columns;
    int rows = context->pending_resize_rows;
    int width = context->pending_resize_width;
    int height = context->pending_resize_height;
    context->pending_resize_columns = 0;
    context->pending_resize_rows = 0;
    context->pending_resize_width = 0;
    context->pending_resize_height = 0;
    if (columns <= 0 || rows <= 0 ||
        (columns == context->columns && rows == context->rows))
        return G_SOURCE_REMOVE;
    if (context->resize(context->userdata, columns, rows, width, height) == 0) {
        context->columns = columns;
        context->rows = rows;
        context->damage_initialized = 0;
        context->resize_commits++;
        if (context->dogfood_omp_seen && context->last_output_us > 0 &&
            g_get_monotonic_time() - context->last_output_us <=
                2 * G_USEC_PER_SEC)
            record_dogfood_omp_action(
                context, "omp_resize_during_output",
                &context->dogfood_omp_resize_seen);
        queue_grid_draw_when_mapped(context);
    }
    return G_SOURCE_REMOVE;
}

static void resize_grid_to_allocation(DeettyGridContext *context,
                                      GtkAllocation *allocation) {
    if (!grid_context_session_available(context) || context->exited) return;
    DeettyGridNativeHostPolicy policy = {0};
    deetty_grid_native_host_policy(&policy);
    DeettyGridLifecycleTimingPlan timing = {0};
    deetty_grid_lifecycle_timing_plan(&timing);

    double base_size = context->requested_font_size > 0
        ? context->requested_font_size : context->font_size;
    double next_size = base_size;
    int zoom_percent = 100;
    int floor_reached = 0;
    DeettyGridAutoFitBounds fit_bounds = {
        allocation->width, allocation->height};
    DeettyGridContext *root = root_grid_context(context);
    int auto_fit_enabled = root->workspace_smoke == 21 &&
        context->page != NULL &&
        grid_contexts_on_page(root, context->page) >= 4 &&
        allocation->width > 0 && allocation->height > 0;
    if (auto_fit_enabled) {
        for (guint index = 0; root->contexts != NULL &&
             index < root->contexts->len; index++) {
            DeettyGridContext *candidate =
                g_ptr_array_index(root->contexts, index);
            if (!candidate->active || candidate->exited ||
                candidate->page != context->page || candidate->area == NULL)
                continue;
            GtkAllocation candidate_allocation;
            deetty_grid_widget_get_allocation(candidate->area, &candidate_allocation);
            DeettyGridAutoFitBounds candidate_bounds = {0};
            deetty_grid_auto_fit_bounds(
                fit_bounds.width, fit_bounds.height,
                candidate_allocation.width, candidate_allocation.height,
                &candidate_bounds);
            fit_bounds = candidate_bounds;
        }
    }
    deetty_grid_auto_fit(
        base_size, fit_bounds.width, fit_bounds.height, auto_fit_enabled, &next_size,
        &zoom_percent, &floor_reached);
    context->resize_overlay_floor_reached = floor_reached;
    gboolean font_changed = fabs(context->font_size - next_size) > 0.01;
    if (font_changed) {
        for (guint index = 0; root->contexts != NULL &&
             index < root->contexts->len; index++) {
            DeettyGridContext *candidate =
                g_ptr_array_index(root->contexts, index);
            if (!candidate->active || candidate->exited ||
                candidate->page != context->page || candidate->area == NULL)
                continue;
            candidate->font_size = next_size;
            candidate->resize_overlay_zoom_percent = zoom_percent;
            clear_ascii_glyph_cache(candidate);
            deetty_grid_widget_queue_draw(candidate->area);
        }
        if (!root->auto_fit_propagating) {
            root->auto_fit_propagating = 1;
            for (guint index = 0; root->contexts != NULL &&
                 index < root->contexts->len; index++) {
                DeettyGridContext *candidate =
                    g_ptr_array_index(root->contexts, index);
                if (!candidate->active || candidate->exited ||
                    candidate->page != context->page ||
                    candidate->area == NULL)
                    continue;
                GtkAllocation candidate_allocation;
                deetty_grid_widget_get_allocation(
                    candidate->area, &candidate_allocation);
                resize_grid_to_allocation(
                    candidate, &candidate_allocation);
            }
            root->auto_fit_propagating = 0;
        }
    }
    context->resize_overlay_zoom_percent = zoom_percent;

    DeettyGridFontMetrics metrics = grid_font_metrics(context);
    DeettyGridResizePlan resize_plan = {0};
    if (!deetty_grid_resize_plan(
            allocation->width, allocation->height,
            policy.terminal_scrollbar_width_px, metrics.cell_width,
            metrics.cell_height, context->columns, context->rows,
            &resize_plan))
        return;
    int terminal_width = resize_plan.terminal_width;
    int columns = resize_plan.columns;
    int rows = resize_plan.rows;
    if (!resize_plan.changed) {
        if (font_changed) show_resize_overlay(context, columns, rows);
        if (context->resize_commit_source != 0) {
            remove_grid_source(&context->resize_commit_source);
            context->pending_resize_columns = 0;
            context->pending_resize_rows = 0;
            context->pending_resize_width = 0;
            context->pending_resize_height = 0;
        }
        return;
    }
    context->pending_resize_columns = columns;
    context->pending_resize_rows = rows;
    context->pending_resize_width = terminal_width;
    context->pending_resize_height = allocation->height;
    context->resize_requests++;
    show_resize_overlay(context, columns, rows);
    if (context->resize_commit_source == 0)
        context->resize_commit_source = g_timeout_add_full(
            G_PRIORITY_DEFAULT, (guint)timing.resize_commit_ms,
            commit_grid_resize, context, NULL);
}

static void on_size_allocate(GtkWidget *widget, GtkAllocation *allocation, gpointer user_data) {
    DeettyGridContext *context = user_data;
    /* Reparenting can emit transient 1x1 allocations that must not reach the PTY. */
    if (!deetty_grid_widget_get_mapped(widget)) {
        root_grid_context(context)->unmapped_resize_suppressed++;
        return;
    }
    resize_grid_to_allocation(context, allocation);
}



static void on_window_resize_handle_realize(GtkWidget *widget,
                                            gpointer user_data) {
    (void)user_data;
    int index = deetty_grid_resize_handle_index(GPOINTER_TO_INT(
        deetty_grid_object_get_data(G_OBJECT(widget), "deetty-resize-index")));
    if (index < 0 || index >= 8) return;
    GdkWindow *window = deetty_grid_widget_get_window(widget);
    if (window == NULL) return;
    GdkDisplay *display = deetty_grid_widget_get_display(widget);
    if (!deetty_grid_gdk_set_cursor(
            window, display, deetty_grid_window_resize_cursor_name(index),
            g_strcmp0(deetty_grid_window_resize_cursor_name(index), "ew-resize") == 0
                ? GDK_SB_H_DOUBLE_ARROW : GDK_SB_V_DOUBLE_ARROW))
        return;
    deetty_grid_object_set_data(G_OBJECT(widget), "deetty-resize-cursor-name",
                      (gpointer)deetty_grid_window_resize_cursor_name(index));
}

static void finish_window_resize_drag(DeettyGridContext *root) {
    int index = root->window_resize_drag_handle;
    gboolean commit_dropdown_size =
        root->window_resize_drag_active && root->mode == 0;
    root->window_resize_drag_active = 0;
    if (index >= 0 && index < 8 &&
        deetty_grid_widget_has_grab(root->window_resize_handles[index]))
        deetty_grid_grab_remove(root->window_resize_handles[index]);
    if (commit_dropdown_size && !root->layer_shell_active) {
        int width = 0;
        int height = 0;
        deetty_grid_window_get_size(GTK_WINDOW(root->window), &width, &height);
        sync_compact_setting(
            root, DEETTY_GRID_COMPACT_FIELD_WIDTH_PIXELS, width);
        sync_compact_setting(
            root, DEETTY_GRID_COMPACT_FIELD_HEIGHT_PIXELS, height);
    }
    if (commit_dropdown_size &&
        normalize_dropdown_pixel_dimensions(root, TRUE))
        apply_dropdown_dimensions(root);
}

static gboolean begin_window_resize_drag(GtkWidget *widget,
                                           DeettyGridContext *root,
                                           int index, guint button,
                                           double x_root, double y_root,
                                           guint32 time) {
    root->window_resize_handle_mask |= 1 << index;
    if (root->workspace_smoke == 19) return TRUE;
    finish_window_resize_drag(root);
    root->window_resize_drag_active = 1;
    root->window_resize_drag_handle = index;
    root->window_resize_drag_start_x = x_root;
    root->window_resize_drag_start_y = y_root;
    deetty_grid_window_get_size(GTK_WINDOW(root->window),
                        &root->window_resize_drag_start_width,
                        &root->window_resize_drag_start_height);
    root->window_resize_drag_start_width_percent =
        root->dropdown_width_percent;
    root->window_resize_drag_start_height_percent =
        root->dropdown_height_percent;
    if (!root->layer_shell_active) {
        deetty_grid_window_begin_resize_drag(
            GTK_WINDOW(root->window), (int)deetty_grid_resize_edge(index),
            (gint)button, (gint)x_root, (gint)y_root, time);
        return TRUE;
    }
    GtkWidget *grab_widget = root->window_resize_handles[index] != NULL
        ? root->window_resize_handles[index] : widget;
    deetty_grid_grab_add(grab_widget);
    return TRUE;
}

static void cancel_dragger_double_click_timer(DeettyGridContext *root) {
    if (root->dragger_double_click_source == 0) return;
    deetty_grid_source_remove(root->dragger_double_click_source);
    root->dragger_double_click_source = 0;
}

static gboolean toggle_dragger_height(DeettyGridContext *root) {
    int maximized = root->dropdown_height_percent >= 95;
    int target_height = maximized ? 50 : 100;
    cancel_dragger_double_click_timer(root);
    root->dragger_height_toggled = !maximized;
    root->dragger_click_pending = 0;
    root->dragger_last_press_time = 0;
    finish_window_resize_drag(root);
    sync_compact_setting(
        root, DEETTY_GRID_COMPACT_FIELD_HEIGHT_PERCENT, target_height);
    sync_compact_setting(root, DEETTY_GRID_COMPACT_FIELD_HEIGHT_PIXELS, 0);
    apply_dropdown_dimensions(root);
    if (root->event != NULL)
        root->event(root->event_data, root->pane_id,
                    deetty_grid_settings_event_code(DEETTY_GRID_SETTINGS_EVENT_DROPDOWN_HEIGHT),
                    target_height,
                    (uint64_t)(g_get_monotonic_time() / 1000));
    return TRUE;
}

static gboolean finish_dragger_click_fallback(gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    root->dragger_double_click_source = 0;
    if (root->dragger_click_pending >= 2) {
        toggle_dragger_height(root);
        return G_SOURCE_REMOVE;
    }
    root->dragger_click_pending = 0;
    root->dragger_last_press_time = 0;
    return G_SOURCE_REMOVE;
}

static gboolean on_window_resize_handle_button(GtkWidget *widget,
                                                GdkEventButton *event,
                                                gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    int index = deetty_grid_resize_handle_index(GPOINTER_TO_INT(
        deetty_grid_object_get_data(G_OBJECT(widget), "deetty-resize-index")));
    DeettyGridResizeEventPlan plan = {0};
    int event_kind = event->type == GDK_2BUTTON_PRESS
        ? DEETTY_GRID_RESIZE_EVENT_DOUBLE_PRESS
        : DEETTY_GRID_RESIZE_EVENT_PRESS;
    deetty_grid_resize_event_plan(
        event_kind, index, (int)event->button, root->mode,
        root->window_resize_drag_active, root->dragger_click_pending,
        0, 0.0, &plan);
    switch (plan.action) {
    case DEETTY_GRID_RESIZE_ACTION_TOGGLE_HEIGHT:
        return toggle_dragger_height(root);
    case DEETTY_GRID_RESIZE_ACTION_DELAY_DOUBLE_CLICK:
        root->dragger_click_pending = 2;
        cancel_dragger_double_click_timer(root);
        root->dragger_double_click_source = deetty_grid_source_timeout_add(
            75, finish_dragger_click_fallback, root);
        return TRUE;
    case DEETTY_GRID_RESIZE_ACTION_ARM_CLICK:
        cancel_dragger_double_click_timer(root);
        root->dragger_click_pending = 1;
        root->dragger_last_press_time = event->time;
        root->window_resize_drag_start_x = event->x_root;
        root->window_resize_drag_start_y = event->y_root;
        root->dragger_double_click_source = deetty_grid_source_timeout_add(
            500, finish_dragger_click_fallback, root);
        return TRUE;
    case DEETTY_GRID_RESIZE_ACTION_BEGIN_DRAG:
        return begin_window_resize_drag(
            widget, root, index, event->button,
            event->x_root, event->y_root, event->time);
    default:
        return FALSE;
    }
}

static gboolean on_window_resize_handle_motion(GtkWidget *widget,
                                                GdkEventMotion *event,
                                                gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    DeettyGridNativeHostPolicy policy = {0};
    deetty_grid_native_host_policy(&policy);
    int index = deetty_grid_resize_handle_index(GPOINTER_TO_INT(
        deetty_grid_object_get_data(G_OBJECT(widget), "deetty-resize-index")));
    if (index < 0) {
        if (root->window_resize_drag_active)
            index = root->window_resize_drag_handle;
        else if (root->dragger_click_pending == 1 && root->mode == 0)
            index = 6;
        else
            return FALSE;
    }
    double delta_x = event->x_root - root->window_resize_drag_start_x;
    double delta_y = event->y_root - root->window_resize_drag_start_y;
    DeettyGridResizeEventPlan plan = {0};
    deetty_grid_resize_event_plan(
        DEETTY_GRID_RESIZE_EVENT_MOTION, index, 1, root->mode,
        root->window_resize_drag_active, root->dragger_click_pending,
        (event->state & GDK_BUTTON1_MASK) != 0,
        delta_x * delta_x + delta_y * delta_y, &plan);
    if (plan.action == DEETTY_GRID_RESIZE_ACTION_BEGIN_DRAG) {
        cancel_dragger_double_click_timer(root);
        root->dragger_click_pending = 0;
        return begin_window_resize_drag(
            widget, root, index, 1,
            root->window_resize_drag_start_x,
            root->window_resize_drag_start_y, event->time);
    }
    if (plan.action == DEETTY_GRID_RESIZE_ACTION_CONSUME)
        return TRUE;
    if (plan.action == DEETTY_GRID_RESIZE_ACTION_FINISH_DRAG) {
        finish_window_resize_drag(root);
        return FALSE;
    }
    if (plan.action != DEETTY_GRID_RESIZE_ACTION_UPDATE_DRAG)
        return FALSE;
    GdkMonitor *monitor = grid_monitor_for_window(root->window);
    GdkRectangle geometry = {0, 0, 900, 420};
    if (monitor != NULL) deetty_grid_gdk_monitor_get_geometry(monitor, &geometry);

    double horizontal = 0.0;
    double vertical = 0.0;
    deetty_grid_resize_delta(
        index, root->window_resize_drag_start_x,
        root->window_resize_drag_start_y, event->x_root, event->y_root,
        &horizontal, &vertical);

    if (root->mode == 1 && root->layer_shell_active) {
        int width = deetty_grid_clamp_resize(
            root->window_resize_drag_start_width, horizontal, 320, G_MAXINT);
        int height = deetty_grid_clamp_resize(
            root->window_resize_drag_start_height, vertical, 180, G_MAXINT);
        if (!apply_grid_layer_surface_size(root, width, height))
            deetty_grid_window_resize(root->window, width, height);
        return TRUE;
    }
    if (root->mode != 0) return FALSE;
    int width = deetty_grid_clamp_resize(
        root->window_resize_drag_start_width, horizontal,
        MIN(policy.dropdown_min_width_px, geometry.width), geometry.width);
    int height = deetty_grid_clamp_resize(
        root->window_resize_drag_start_height, vertical,
        MIN(policy.dropdown_min_height_px, geometry.height), geometry.height);
    gboolean changed = FALSE;
    if (horizontal != 0.0 && width != root->dropdown_width_px) {
        sync_compact_setting(
            root, DEETTY_GRID_COMPACT_FIELD_WIDTH_PIXELS, width);
        changed = TRUE;
    }
    if (vertical != 0.0 && height != root->dropdown_height_px) {
        sync_compact_setting(
            root, DEETTY_GRID_COMPACT_FIELD_HEIGHT_PIXELS, height);
        changed = TRUE;
    }
    if (changed) apply_dropdown_dimensions(root);
    return TRUE;
}

static gboolean on_window_resize_handle_release(GtkWidget *widget,
                                                 GdkEventButton *event,
                                                 gpointer user_data) {
    (void)widget;
    DeettyGridContext *root = root_grid_context(user_data);
    DeettyGridResizeEventPlan plan = {0};
    int index = deetty_grid_resize_handle_index(GPOINTER_TO_INT(
        deetty_grid_object_get_data(G_OBJECT(widget),
                                    "deetty-resize-index")));
    if (index < 0 && root->window_resize_drag_active)
        index = root->window_resize_drag_handle;
    deetty_grid_resize_event_plan(
        DEETTY_GRID_RESIZE_EVENT_RELEASE,
        index,
        (int)event->button, root->mode,
        root->window_resize_drag_active, root->dragger_click_pending,
        0, 0.0, &plan);
    if (plan.action != DEETTY_GRID_RESIZE_ACTION_FINISH_DRAG)
        return FALSE;
    finish_window_resize_drag(root);
    DeettyGridContext *focus_target = active_grid_context(root);
    if (focus_target->area != NULL)
        deetty_grid_focus_widget(NULL, focus_target->area);
    return TRUE;
}

static GtkWidget *create_window_resize_handle(DeettyGridContext *context,
                                              int index, int width,
                                              int height) {
    GtkWidget *handle = deetty_resize_handle_new(
        index, width, height,
        deetty_grid_window_resize_cursor_name(index));
    if (handle == NULL) return NULL;
    deetty_grid_signal_connect(handle, "realize",
                     G_CALLBACK(on_window_resize_handle_realize), context);
    deetty_grid_signal_connect(handle, "button-press-event",
                     G_CALLBACK(on_window_resize_handle_button), context);
    deetty_grid_signal_connect(handle, "button-release-event",
                     G_CALLBACK(on_window_resize_handle_release), context);
    deetty_grid_signal_connect(handle, "motion-notify-event",
                     G_CALLBACK(on_window_resize_handle_motion), context);
    context->window_resize_handles[index] = handle;
    context->window_resize_handle_count++;
    return handle;
}

static GtkWidget *create_window_resize_layout(DeettyGridContext *context,
                                              GtkWidget *content) {
    DeettyWindowResizeLayout layouts[8] = {0};
    int border_px = context->window_border_px;
    int dragger_px = context->dragger_px;
    for (int index = 0; index < 8; index++) {
        DeettyGridResizeHandleLayout handle_layout = {0};
        if (deetty_grid_resize_handle_layout(
                index, border_px, dragger_px, &handle_layout) == 0)
            continue;
        layouts[index] = (DeettyWindowResizeLayout){
            .column = handle_layout.column,
            .row = handle_layout.row,
            .width = handle_layout.width,
            .height = handle_layout.height,
        };
        (void)create_window_resize_handle(
            context, index, handle_layout.width, handle_layout.height);
    }
    return deetty_window_resize_layout_new(
        content, context->window_resize_handles, layouts, 8,
        &context->resize_grip);
}

static void update_window_resize_handles(DeettyGridContext *context) {
    DeettyGridContext *root = root_grid_context(context);
    int dragger_px = root->dragger_px;
    if (root->resize_grip != NULL)
        deetty_grid_widget_set_size_request(root->resize_grip, -1, dragger_px);
    for (int index = 0; index < 8; index++) {
        GtkWidget *handle = root->window_resize_handles[index];
        if (handle == NULL || index == 6) continue;
        DeettyGridResizeHandleLayout handle_layout = {0};
        if (deetty_grid_resize_handle_layout(
                index, root->window_border_px, dragger_px, &handle_layout) == 0)
            continue;
        deetty_grid_widget_set_size_request(
            handle, handle_layout.width, handle_layout.height);
    }
    int visible = 0;
    for (int index = 0; index < 8; index++) {
        GtkWidget *handle = root->window_resize_handles[index];
        if (handle == NULL) continue;
        gboolean cardinal = index == 1 || index == 3 ||
            index == 4 || index == 6;
        gboolean show = cardinal && root->mode == 0 && index != 1;
        if (show) {
            deetty_grid_widget_show(handle);
            visible++;
        } else {
            deetty_grid_widget_hide(handle);
        }
    }
    root->window_resize_affordance_ready =
        (root->mode == 1 && visible == 0 &&
         deetty_grid_window_get_decorated(GTK_WINDOW(root->window)) &&
         deetty_grid_window_get_resizable(GTK_WINDOW(root->window))) ||
        (root->mode == 0 && visible == 3);
    deetty_grid_window_set_resizable(root->window, TRUE);
}

static gboolean check_window_resize_smoke(gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    int width = 0;
    int height = 0;
    deetty_grid_window_get_size(GTK_WINDOW(root->window), &width, &height);
    root->window_resize_geometry_changed =
        width > root->window_resize_initial_width &&
        height > root->window_resize_initial_height;
    if (root->workspace_smoke == 19 && root->tray_bus != NULL &&
        root->tray_watcher_registered) {
        const char *unique_name = g_dbus_connection_get_unique_name(
            root->tray_bus);
        if (unique_name != NULL)
            (void)g_file_set_contents(
                "/tmp/deetty-native-grid-window-tray-ready",
                unique_name, -1, NULL);
    }
    return G_SOURCE_REMOVE;
}

static gboolean request_window_resize_smoke(gpointer user_data) {
    DeettyGridContext *root = root_grid_context(user_data);
    deetty_grid_window_get_size(GTK_WINDOW(root->window),
                        &root->window_resize_initial_width,
                        &root->window_resize_initial_height);
    gboolean custom_handles_hidden = root->window_resize_handle_count == 8;
    for (int index = 0; index < 8; index++) {
        GtkWidget *handle = root->window_resize_handles[index];
        custom_handles_hidden = custom_handles_hidden && handle != NULL &&
            !deetty_grid_widget_get_visible(handle);
    }
    root->window_native_decorated =
        deetty_grid_window_get_decorated(GTK_WINDOW(root->window));
    root->window_native_resizable =
        deetty_grid_window_get_resizable(GTK_WINDOW(root->window));
    root->window_resize_affordance_ready =
        custom_handles_hidden && root->window_native_decorated &&
        root->window_native_resizable;
    deetty_grid_window_resize(
        root->window,
        root->window_resize_initial_width + 120,
        root->window_resize_initial_height + 80);
    deetty_grid_source_timeout_add(500, check_window_resize_smoke, root);
    return G_SOURCE_REMOVE;
}

static void on_im_commit(GtkIMContext *im_context, const gchar *text,
                         gpointer user_data) {
    (void)im_context;
    DeettyGridContext *context = user_data;
    if (grid_context_session_available(context) && !context->exited &&
        text != NULL && text[0] != '\0' &&
        deliver_grid_input(context, text, strlen(text)) < 0)
        show_status_feedback(
            context,
            deetty_grid_status_feedback_message(
                DEETTY_GRID_FEEDBACK_COMPOSED_TEXT));
}

static void on_grid_area_realize(GtkWidget *widget, gpointer user_data) {
    DeettyGridContext *context = user_data;
    GdkWindow *window = deetty_grid_widget_get_window(widget);
    if (window != NULL) {
        GdkDisplay *display = deetty_grid_widget_get_display(widget);
        if (deetty_grid_gdk_set_cursor(
                window, display, "text", GDK_XTERM))
            deetty_grid_object_set_data(G_OBJECT(widget), "deetty-cursor-name",
                              (gpointer)"text");
    }
    if (context->im_context != NULL)
        deetty_grid_im_context_set_client_window(context->im_context, window);
    if (context->renderer_backend != 0 && GTK_IS_GL_AREA(widget)) {
        gtk_gl_area_make_current(GTK_GL_AREA(widget));
        if (gtk_gl_area_get_error(GTK_GL_AREA(widget)) != NULL)
            request_gpu_fallback(context);
    }
}

static void on_grid_area_unrealize(GtkWidget *widget, gpointer user_data) {
    (void)widget;
    DeettyGridContext *context = user_data;
    if (context->im_context != NULL)
        deetty_grid_im_context_set_client_window(context->im_context, NULL);
}

static void on_grid_area_map(GtkWidget *widget, gpointer user_data) {
    DeettyGridContext *context = user_data;
    GtkAllocation allocation;
    deetty_grid_widget_get_allocation(widget, &allocation);
    resize_grid_to_allocation(context, &allocation);
    context->damage_initialized = 0;
    queue_grid_damage_when_mapped(context);
}

static void connect_grid_area(DeettyGridContext *context) {
    context->resize_overlay_initial_suppressed = 1;
    deetty_grid_style_context_add_class(deetty_grid_widget_get_style_context(context->area),
                                "deetty-grid-area");
    deetty_grid_widget_set_can_focus(context->area, TRUE);
    deetty_grid_object_set_data(
        G_OBJECT(context->area), "deetty-grid-context", context);
    AtkObject *accessible = deetty_grid_widget_get_accessible(context->area);
    if (accessible != NULL) {
        char name[64] = {0};
        if (deetty_grid_terminal_accessible_name(
                context->pane_id, (unsigned char *)name, sizeof(name)) > 0)
            deetty_grid_atk_object_set_name(accessible, name);
    }
    if (context->renderer_backend != 0)
        deetty_grid_signal_connect(
            context->area, "render", G_CALLBACK(on_gpu_render), context);
    else
        deetty_grid_signal_connect(
            context->area, "draw", G_CALLBACK(on_draw), context);
    deetty_grid_signal_connect(context->area, "key-press-event", G_CALLBACK(on_key_press), context);
    deetty_grid_signal_connect(context->area, "key-release-event",
                     G_CALLBACK(on_key_release), context);
    deetty_grid_signal_connect(context->area, "focus-in-event", G_CALLBACK(on_focus_in), context);
    deetty_grid_signal_connect(context->area, "focus-out-event", G_CALLBACK(on_focus_out), context);
    deetty_grid_signal_connect(context->area, "button-press-event", G_CALLBACK(on_mouse_button), context);
    deetty_grid_signal_connect(context->area, "button-release-event", G_CALLBACK(on_mouse_button), context);
    deetty_grid_signal_connect(context->area, "motion-notify-event", G_CALLBACK(on_mouse_motion), context);
    deetty_grid_signal_connect(context->area, "leave-notify-event",
                     G_CALLBACK(on_grid_area_leave), context);
    deetty_grid_signal_connect(context->area, "scroll-event", G_CALLBACK(on_scroll), context);
    deetty_grid_signal_connect(context->area, "size-allocate", G_CALLBACK(on_size_allocate), context);
    deetty_grid_signal_connect(context->area, "map", G_CALLBACK(on_grid_area_map), context);
    deetty_grid_signal_connect(context->area, "realize", G_CALLBACK(on_grid_area_realize), context);
    deetty_grid_signal_connect(context->area, "unrealize", G_CALLBACK(on_grid_area_unrealize), context);
    if (context->im_context != NULL)
        deetty_grid_signal_connect(context->im_context, "commit", G_CALLBACK(on_im_commit), context);
    deetty_grid_widget_add_events(
        context->area,
        GDK_KEY_PRESS_MASK | GDK_KEY_RELEASE_MASK |
            GDK_BUTTON_PRESS_MASK | GDK_BUTTON_RELEASE_MASK |
            GDK_SCROLL_MASK | GDK_POINTER_MOTION_MASK |
            GDK_SMOOTH_SCROLL_MASK);
    deetty_grid_drag_source_set(context->area, GDK_BUTTON2_MASK, deetty_pane_drag_targets, 1, GDK_ACTION_MOVE);
    deetty_grid_drag_dest_set(context->area, GTK_DEST_DEFAULT_ALL, deetty_pane_drag_targets, 1, GDK_ACTION_MOVE);
    deetty_grid_signal_connect(context->area, "drag-data-get", G_CALLBACK(on_pane_drag_data_get), context);
    deetty_grid_signal_connect(context->area, "drag-data-received", G_CALLBACK(on_pane_drag_data_received), context);
    DeettyGridLifecycleTimingPlan timing = {0};
    deetty_grid_lifecycle_timing_plan(&timing);
    context->resize_overlay_arm_source =
        deetty_grid_source_timeout_add(
            (guint)timing.resize_overlay_arm_ms,
            arm_resize_overlay, context);
}
#if DEETTY_ENABLE_SMOKE
static GSourceFunc smoke_callback_for_action(int action) {
    static const GSourceFunc callbacks[] = {
        write_activation_child_receipt_smoke,
        emit_workspace_smoke_tab,
        emit_workspace_smoke_split,
        emit_workspace_smoke_split_left,
        emit_workspace_smoke_broadcast,
        emit_workspace_smoke_select,
        emit_workspace_smoke_tag_filter,
        emit_workspace_smoke_focus,
        emit_workspace_smoke_move,
        finish_workspace_smoke,
        request_new_tab_button_smoke,
        inspect_compact_tab_geometry_smoke,
        request_tab_close_smoke,
        request_clipboard_smoke,
        inspect_window_toolbar_smoke,
        request_settings_smoke,
        request_window_close_button_smoke,
        request_theme_smoke,
        request_project_smoke,
        request_recursive_zoom_smoke,
        drive_focus_click_smoke,
        emit_workspace_smoke_balanced_split,
        emit_workspace_smoke_move_last_pane,
        request_compact_hyperlink_smoke,
        request_compact_palette_smoke,
        request_compact_find_smoke,
        request_compact_note_smoke,
        request_compact_zoom_smoke,
        request_compact_navigation_smoke,
        inspect_compact_pane_info_smoke,
        request_compact_font_scroll_smoke,
        request_compact_linear_selection_smoke,
        request_compact_save_smoke,
        request_pane_scrollbar_smoke,
        finish_compact_smoke,
        request_tab_rename_smoke,
        check_resize_overlay_initially_hidden,
        move_resize_overlay_divider,
        check_resize_overlay_visible,
        check_resize_overlay_hidden_and_finish,
        emit_pane_close_primary_split_right,
        emit_pane_close_secondary_split_right,
        inspect_and_resize_pane_close_layout,
        disturb_pane_close_layout,
        request_pane_close_smoke,
        start_layout_preset_smoke,
        start_tab_navigation_interactions,
        check_title_fallback_smoke,
        emit_title_overflow_smoke,
        check_title_overflow_smoke,
        check_title_rename_smoke,
        finish_title_smoke,
        trigger_dirty_smoke,
        emit_attention_smoke,
        check_dirty_smoke,
        check_attention_smoke,
        save_dirty_smoke,
        check_dirty_clear_smoke,
        acknowledge_attention_smoke,
        announce_reorder_drag_smoke,
        check_reorder_smoke,
        persist_reorder_smoke,
        palette_rename_smoke,
        request_tab_color_smoke,
        request_settings_stacking_smoke,
        check_settings_stacking_smoke,
        request_note_overlay_alt_press_smoke,
        check_note_overlay_drawn_smoke,
        request_terminal_interrupt_chord_smoke,
        request_terminal_close_chord_smoke,
        request_terminal_final_pane_guard_smoke,
        finish_terminal_chord_smoke,
        request_profile_preset_smoke,
        request_recent_workspace_child_smoke,
        start_presentation_qualification_smoke,
        start_full_stack_qualification_smoke,
        poll_installed_continuity_detach_smoke,
        start_stability_qualification_smoke,
        request_sharing_scope_smoke,
        request_window_resize_smoke,
    };
    if (action <= 0 ||
        (size_t)action > sizeof(callbacks) / sizeof(callbacks[0]))
        return NULL;
    return callbacks[action - 1];
}
#endif

int deetty_native_grid_host_run_v2(const DeettyGridCallbacks *callbacks,
                                   const DeettyGridLaunchOptions *options) {
    if (callbacks == NULL || options == NULL ||
        callbacks->abi_version != DEETTY_NATIVE_GRID_ABI_VERSION ||
        options->abi_version != DEETTY_NATIVE_GRID_ABI_VERSION ||
        callbacks->struct_size < sizeof(*callbacks) ||
        options->struct_size < sizeof(*options) ||
        callbacks->pump == NULL || callbacks->write == NULL ||
        callbacks->frame == NULL ||
        callbacks->dirty_rows == NULL || callbacks->dirty_spans == NULL ||
        callbacks->presentation_ready == NULL ||
        callbacks->color_rgb == NULL ||
        callbacks->cell_text == NULL ||
        callbacks->cell_hyperlink == NULL ||
        callbacks->poll_exit == NULL ||
        callbacks->resize == NULL || callbacks->mouse == NULL ||
        callbacks->paste == NULL || callbacks->copy == NULL ||
        callbacks->scroll == NULL || callbacks->cursor == NULL ||
        callbacks->title == NULL || callbacks->cursor_mode == NULL ||
        callbacks->mouse_mode == NULL || callbacks->focus == NULL ||
        callbacks->event == NULL) {
        g_printerr("native_grid_abi_rejected expected=%u callbacks_version=%u options_version=%u callbacks_size=%u/%zu options_size=%u/%zu\n",
                   DEETTY_NATIVE_GRID_ABI_VERSION,
                   callbacks != NULL ? callbacks->abi_version : 0,
                   options != NULL ? options->abi_version : 0,
                   callbacks != NULL ? callbacks->struct_size : 0,
                   sizeof(*callbacks),
                   options != NULL ? options->struct_size : 0,
                   sizeof(*options));
        return -4;
    }
    void *userdata = callbacks->userdata;
    DeettyGridPump pump = callbacks->pump;
    DeettyGridWrite write = callbacks->write;
    DeettyGridFrame frame = callbacks->frame;
    DeettyGridPollExit poll_exit = callbacks->poll_exit;
    DeettyGridResize resize = callbacks->resize;
    DeettyGridMouse mouse = callbacks->mouse;
    DeettyGridPaste paste = callbacks->paste;
    DeettyGridCopy copy = callbacks->copy;
    DeettyGridScroll scroll = callbacks->scroll;
    DeettyGridCursor cursor = callbacks->cursor;
    DeettyGridTitle title = callbacks->title;
    DeettyGridCursorMode cursor_mode = callbacks->cursor_mode;
    DeettyGridMouseMode mouse_mode = callbacks->mouse_mode;
    DeettyGridFocus focus = callbacks->focus;
    DeettyGridEvent event = callbacks->event;
    DeettyGridTextAction text_action = callbacks->text_action;
    void *event_data = callbacks->event_data;
    void *text_action_data = callbacks->text_action_data;
    uint64_t pane_id = options->pane_id;
    int columns = options->columns;
    int rows = options->rows;
    int mode = options->mode;
    int shortcut_key = options->shortcut_key;
    int enable_shortcut = options->enable_shortcut;
    int workspace_smoke = options->workspace_smoke;
    void *secondary_userdata = options->secondary_userdata;
    uint64_t secondary_pane_id = options->secondary_pane_id;
    int secondary_initially_active = options->secondary_initially_active;
    int enable_notifications = options->enable_notifications;
    int use_layer_shell = options->use_layer_shell;
    int claim_control = options->claim_control;
    int show_on_control_conflict = options->show_on_control_conflict;
    guint32 recovery_notice_flags = options->recovery_notice_flags;
    const gchar *startup_activation_token =
        options->startup_activation_token;
    gsize startup_activation_token_length =
        options->startup_activation_token_length;
#if !DEETTY_ENABLE_SMOKE
    if (workspace_smoke >= 0) return -3;
    workspace_smoke = -1;
#endif
    g_set_prgname("com.deetty.DEETTY");
    g_set_application_name("DEETTY");
    if (!deetty_grid_gtk_init_check()) {
        g_printerr("native_grid_gtk_init_failed display=%s wayland_display=%s gdk_backend=%s\n",
                   g_getenv("DISPLAY") != NULL ? g_getenv("DISPLAY") : "",
                   g_getenv("WAYLAND_DISPLAY") != NULL ? g_getenv("WAYLAND_DISPLAY") : "",
                   g_getenv("GDK_BACKEND") != NULL ? g_getenv("GDK_BACKEND") : "");
        return -1;
    }
    deetty_grid_window_set_default_icon_name("com.deetty.DEETTY");
    DeettyGridContext context = {0};
    DeettyGridNativeHostPolicy policy = {0};
    deetty_grid_native_host_policy(&policy);
    DeettyGridContext secondary = {0};
    context.root = &context;
    context.dbus_cancellable = g_cancellable_new();
    context.userdata = userdata;
    context.pump = pump;
    context.write = write;
    context.frame = frame;
    context.dirty_rows = callbacks->dirty_rows;
    context.dirty_spans = callbacks->dirty_spans;
    context.presentation_ready = callbacks->presentation_ready;
    context.color_rgb = callbacks->color_rgb;
    context.ui_color_rgb = callbacks->ui_color_rgb;
    context.cell_text = callbacks->cell_text;
    context.cell_hyperlink = callbacks->cell_hyperlink;
    context.poll_exit = poll_exit;
    context.resize = resize;
    context.mouse = mouse;
    context.paste = paste;
    context.copy = copy;
    context.scroll = scroll;
    context.cursor = cursor;
    context.title = title;
    context.cursor_mode = cursor_mode;
    context.mouse_mode = mouse_mode;
    context.focus = focus;
    context.pane_id = pane_id;
    context.active_pane_id_for_render = pane_id;
    context.event = event;
    context.event_data = event_data;
    context.text_action = text_action;
    context.text_action_data = text_action_data;
    context.create_session = event_data != NULL ? deetty_grid_create_session : NULL;
    context.mode = mode;
    DeettyGridSettingsPlan settings = {0};
    deetty_grid_settings_plan(
        deetty_grid_compact_setting,
        event_data,
        event_data != NULL,
        &settings);
    context.dropdown_width_percent = settings.width_percent;
    context.dropdown_height_percent = settings.height_percent;
    context.dropdown_width_px = settings.width_pixels;
    context.dropdown_height_px = settings.height_pixels;
    context.dropdown_animation_ms = settings.animation_ms;
    context.hide_on_focus_loss = settings.hide_on_focus_loss;
    context.focus_follows_pointer = settings.focus_follows_pointer;
    context.background_translucency = settings.background_translucency;
    context.background_opacity_percent = settings.background_opacity_percent;
    context.terminal_scroll_lines =
        deetty_grid_terminal_scroll_setting(
            DEETTY_GRID_SETTINGS_EVENT_SCROLL_LINES,
            context.terminal_scroll_lines);
    context.terminal_smooth_scroll = settings.terminal_smooth_scroll;
    context.panel_padding_px = settings.panel_padding_px;
    context.pane_spacing_px = settings.pane_spacing_px;
    context.pane_gaps_enabled = settings.pane_gaps_enabled;
    context.pane_gaps_transparent = settings.pane_gaps_transparent;
    context.inactive_pane_dim_enabled = settings.inactive_pane_dim_enabled;
    context.inactive_pane_brightness_percent =
        settings.inactive_pane_brightness_percent;
    context.renderer_backend = settings.renderer_backend;
    context.renderer_backend_requested = settings.renderer_backend;
    context.pane_divider_px = settings.pane_divider_px;
    context.pane_border_px = settings.pane_border_px;
    context.pane_border_focused_px = settings.pane_border_focused_px;
    context.pane_border_selected_px = settings.pane_border_selected_px;
    context.status_border_px = settings.status_border_px;
    context.overlay_border_px = settings.overlay_border_px;
    context.window_border_px = settings.window_border_px;
    context.dragger_px = settings.dragger_px;
    context.show_pane_info = settings.show_pane_info;
    context.compact_tab_height = settings.compact_tab_height;
    context.workspace_smoke = workspace_smoke;
    context.shortcut_transport = enable_shortcut;
    context.requested_shortcut_key = shortcut_key;
    context.primary = 1;
    context.active = 1;
    context.enable_notifications = enable_notifications;
    context.layer_shell_allowed = use_layer_shell;
    context.claim_control = claim_control;
    context.show_on_control_conflict = show_on_control_conflict;
    context.recovery_notice_flags = recovery_notice_flags;
    context.font_size = settings.font_size;
    context.font_min_size = settings.font_min_size;
    context.font_max_size = settings.font_max_size;
    context.font_size = deetty_grid_font_size_clamp(
        context.font_size, context.font_min_size, context.font_max_size);
    context.requested_font_size = context.font_size;
    context.font_family = g_strdup("monospace");
    context.font_antialias = settings.font_antialias;
    context.font_hinting = settings.font_hinting;
    context.ligatures = 1;
    context.profile_preset = -1;
    context.cursor_visible = 1;
    context.last_cursor_position = UINT32_MAX;
    context.focused = 1;
    context.window_presented = 1;
    context.columns = columns;
    context.rows = rows;
    context.last_bell_serial = deetty_grid_bell_serial(userdata);
    context.last_notification_serial =
        deetty_grid_notification_serial(userdata);
    context.window = create_grid_toplevel(&context);
    context.area = deetty_terminal_area_new(context.renderer_backend);
    context.im_context = deetty_grid_input_context_new();
    context.contexts = g_ptr_array_new();
    if (g_getenv("DEETTY_BENCH_RENDERER") != NULL &&
        context.renderer_backend == 0) {
        g_print(
            "native_grid_renderer_receipt renderer_requested=cairo renderer_effective=cairo gpu_render_frames=0 gpu_texture_uploads=0 gpu_fallbacks=0\n");
        fflush(stdout);
        context.gpu_receipt_reported = 1;
    }
    (void)sync_grid_context_profile(&context);
    if (secondary_userdata != NULL) {
        inherit_grid_session_context(&secondary, &context);
        secondary.font_family = g_strdup(
            context.font_family != NULL ? context.font_family : "monospace");
        secondary.userdata = secondary_userdata;
        secondary.last_bell_serial = deetty_grid_bell_serial(secondary_userdata);
        secondary.last_notification_serial =
            deetty_grid_notification_serial(secondary_userdata);
        secondary.pane_id = secondary_pane_id;
        secondary.profile_preset = -1;
        secondary.primary = 0;
        secondary.active = secondary_initially_active;
        secondary.focused = 0;
        secondary.last_cursor_position = UINT32_MAX;
        secondary.window = context.window;
        secondary.area = deetty_terminal_area_new(secondary.renderer_backend);
        secondary.im_context = deetty_grid_input_context_new();
        g_ptr_array_add(context.contexts, &secondary);
        (void)sync_grid_context_profile(&secondary);
        context.peer = &secondary;
        secondary.peer = &context;
    }
    if (mode == 2) apply_fullscreen_dimensions(&context);
    context.notebook = deetty_grid_notebook_new();
    DeettyGridNotebookCallbacks notebook_callbacks = {
        .switch_page = G_CALLBACK(on_notebook_switch_page),
        .drag_begin = G_CALLBACK(on_notebook_drag_begin),
        .drag_end = G_CALLBACK(on_notebook_drag_end),
        .page_reordered = G_CALLBACK(on_notebook_page_reordered),
    };
    context.new_tab_button = create_new_tab_button(&context);
    context.window_toolbar_controls =
        create_window_toolbar_controls(&context);
    if (!deetty_grid_notebook_configure(
            context.notebook,
            context.new_tab_button,
            context.window_toolbar_controls,
            &context,
            &notebook_callbacks)) {
        g_printerr("native_grid_host_init_failed stage=notebook_configure\n");
        deetty_grid_widget_destroy(context.window);
        return 2;
    }
    DeettyGridShellContents shell = {0};
    if (!deetty_grid_shell_contents_new(&shell)) {
        g_printerr("native_grid_host_init_failed stage=shell_contents\n");
        deetty_grid_widget_destroy(context.window);
        return 2;
    }
    context.revealer = shell.revealer;
    context.content_box = shell.content_box;
    context.recovery_notice = create_recovery_notice(&context);
    if (context.recovery_notice != NULL)
        deetty_box_pack_start(
            context.content_box, context.recovery_notice, FALSE, FALSE, 0);
    context.pane_info_strip =
        deetty_pane_info_strip_new(context.show_pane_info);
    if (context.pane_info_strip == NULL) {
        g_printerr("native_grid_host_init_failed stage=pane_info_strip\n");
        deetty_grid_widget_destroy(context.window);
        return 2;
    }
    deetty_grid_revealer_set_transition_type(GTK_REVEALER(context.revealer),
                                     GTK_REVEALER_TRANSITION_TYPE_SLIDE_DOWN);
    deetty_grid_revealer_set_transition_duration(GTK_REVEALER(context.revealer),
                                         (guint)context.dropdown_animation_ms);
    deetty_grid_revealer_set_reveal_child(GTK_REVEALER(context.revealer), TRUE);
    secondary.notebook = context.notebook;
    secondary.revealer = context.revealer;
    secondary.content_box = context.content_box;
    secondary.pane_info_strip = context.pane_info_strip;
    GtkWidget *first_page = create_grid_page(&context);
    context.page = first_page;
    secondary.page = first_page;
    if (secondary_userdata != NULL && secondary.active) {
        context.paned = deetty_paned_new(
            GTK_ORIENTATION_VERTICAL, context.pane_divider_px);
        secondary.paned = context.paned;
        deetty_paned_pack1(context.paned, context.area, TRUE, FALSE);
        deetty_paned_pack2(context.paned, secondary.area, TRUE, FALSE);
        deetty_box_pack_start(first_page, context.paned, TRUE, TRUE, 0);
    } else {
        deetty_box_pack_start(first_page, context.area, TRUE, TRUE, 0);
    }
    GtkWidget *first_tab_widget = create_compact_tab_widget(&context, first_page, "Tab 1");
    GtkWidget *first_tab_label = tab_label_from_widget(first_tab_widget);
    context.tab_label = first_tab_label;
    secondary.tab_label = first_tab_label;
    (void)deetty_grid_notebook_append_page(
        context.notebook, first_page, first_tab_widget);
    deetty_box_pack_start(context.content_box, context.notebook, TRUE, TRUE, 0);
    deetty_box_pack_end(
        context.content_box, context.pane_info_strip, FALSE, FALSE, 0);
    deetty_container_add(context.revealer, context.content_box);
    context.window_layout = create_window_resize_layout(
        &context, context.revealer);
    secondary.window_layout = context.window_layout;
    secondary.resize_grip = context.resize_grip;
    deetty_container_add(context.window, context.window_layout);
    int initial_tab_position = event_data != NULL
        ? deetty_grid_tab_position(event_data)
        : 0;
    apply_grid_tab_position(&context, initial_tab_position, FALSE);

    connect_grid_area(&context);
    if (secondary_userdata != NULL) connect_grid_area(&secondary);
    context.layout_restore_applying = 1;
    gboolean hot_session_restored = restore_hot_session(&context);
    apply_panel_layout_metrics(&context);
    (void)configure_grid_layer_shell(&context);
    if (mode == 0)
        (void)normalize_dropdown_pixel_dimensions(&context, TRUE);
    if (claim_control) {
        (void)register_grid_control(&context);
        drain_grid_dbus_operations(&context);
    }
    gboolean control_conflict = context.control_name_conflict;
    gboolean activation_retained = FALSE;
    if (!control_conflict && startup_activation_token != NULL) {
        activation_retained = retain_xdg_activation_token_bytes(
            &context, startup_activation_token,
            startup_activation_token_length);
    }
    DeettyGridStartupWindowPlan startup_plan = {0};
    deetty_grid_startup_window_plan(
        claim_control, enable_shortcut, context.control_registered,
        mode, control_conflict, activation_retained ? 1 : 0,
        &startup_plan);
    gboolean start_hidden = startup_plan.start_hidden != 0;
    if (startup_plan.apply_activation != 0) {
        apply_xdg_activation_token(&context);
    } else if (!activation_retained && !control_conflict &&
               startup_activation_token != NULL &&
               g_getenv("DEETTY_DEBUG_ACTIVATION") != NULL) {
        g_printerr("deetty_xdg_activation retained=false source=startup\n");
    }
    int tray_ready = 0;
    if (((workspace_smoke < 0 && context.control_registered) ||
         workspace_smoke == 19) && !control_conflict)
        tray_ready = register_grid_tray(&context);
    show_all_with_action_affordances(
        startup_plan.show_layout_only != 0
            ? context.window_layout : context.window);
    update_window_resize_handles(&context);
    update_notebook_chrome(&context);
    for (guint index = 0; index < context.contexts->len; index++) {
        DeettyGridContext *candidate =
            g_ptr_array_index(context.contexts, index);
        if (candidate->active) update_compact_tab(candidate);
    }
    if (hot_session_restored) {
        int restored_active_tab = deetty_grid_restore_active_tab(
            context.event_data);
        if (restored_active_tab >= 0)
            deetty_grid_notebook_select_page(context.notebook, restored_active_tab);
        apply_smart_filter(&context);
    }
    context.layout_restore_applying = 0;
    if (mode == 0) apply_dropdown_dimensions(&context);
    else if (mode == 1 && !context.layer_shell_active)
        apply_window_dimensions(&context);
    update_status_tooltip(&context, "starting");
    if (secondary_userdata != NULL) update_status_tooltip(&secondary, secondary.active ? "starting" : "idle");
    if (secondary_userdata != NULL && !secondary.active) deetty_grid_widget_hide(secondary.area);
    if (enable_shortcut == 1 && claim_control && !control_conflict) {
        (void)register_grid_shortcut(&context, shortcut_key);
    }
    if (control_conflict) {
        context.window_presented = 0;
        deetty_grid_source_idle_add(quit_control_name_conflict, &context);
    }
    if (start_hidden) {
        deetty_grid_revealer_set_reveal_child(GTK_REVEALER(context.revealer), FALSE);
        context.window_presented = 0;
        if (enable_shortcut == 1)
            context.shortcut_hidden_before_registration =
                !deetty_grid_widget_get_visible(context.window) &&
                !deetty_grid_widget_get_mapped(context.window) &&
                context.window_map_count == 0;
    }
    emit_grid_tray_tooltip(&context);
    (void)tray_ready;
    DeettyGridContext *initial_focus = hot_session_restored
        ? focused_grid_context(&context) : &context;
    deetty_grid_focus_widget(NULL, initial_focus->area);
    if (context.active && context.tick_source == 0)
        start_grid_context(&context);
    for (guint index = 0; index < context.contexts->len; index++) {
        DeettyGridContext *candidate =
            g_ptr_array_index(context.contexts, index);
        if (candidate->active && candidate->tick_source == 0)
            start_grid_context(candidate);
    }
    refresh_active_pane_info(&context);
#if DEETTY_ENABLE_SMOKE
    DeettyGridSmokeScheduleStep smoke_steps[32] = {0};
    int smoke_step_count = deetty_grid_smoke_schedule(
        workspace_smoke,
        g_getenv("DEETTY_ACTIVATION_CHILD_RECEIPT") != NULL ? 1 : 0,
        smoke_steps, (int)G_N_ELEMENTS(smoke_steps));
    for (int index = 0; index < smoke_step_count; index++) {
        GSourceFunc callback =
            smoke_callback_for_action(smoke_steps[index].action);
        if (callback == NULL) continue;
        gpointer target = smoke_steps[index].target ==
                DEETTY_GRID_SMOKE_TARGET_PEER && context.peer != NULL
            ? context.peer : &context;
        g_timeout_add((guint)MAX(smoke_steps[index].delay_ms, 0),
                      callback, target);
    }
#endif
    deetty_grid_gtk_main();
#if !DEETTY_ENABLE_SMOKE
    if (context.layout_save_source != 0) {
        deetty_grid_source_remove(context.layout_save_source);
        context.layout_save_source = 0;
        if (!context.control_name_conflict && context.event_data != NULL)
            (void)deetty_grid_flush_hot_session(context.event_data);
    }
    drain_grid_dbus_operations(&context);
    unregister_grid_shortcut(&context);
    unregister_grid_tray(&context);
    unregister_grid_control(&context);
    cancel_grid_dbus_operations(&context);
    remove_grid_source(&context.application_close_deferred_source);
    remove_grid_source(&context.application_close_preflight_source);
    remove_grid_source(&context.window_mode_recreate_source);
    remove_grid_source(&context.cursor_blink_source);
    remove_grid_source(&context.maintenance_source);
    cancel_dragger_double_click_timer(&context);
    for (guint index = 0; index < context.contexts->len; index++) {
        DeettyGridContext *candidate = g_ptr_array_index(context.contexts, index);
        stop_grid_context_sources(candidate);
    }
    dismiss_grid_popup_windows(&context);
    while (deetty_grid_events_pending()) deetty_grid_main_iteration_do(FALSE);
    deetty_grid_widget_destroy(context.window);
    if (context.layer_shell_library != NULL) {
        dlclose(context.layer_shell_library);
        context.layer_shell_library = NULL;
    }
    context.xdg_activation_token = deetty_grid_memory_clear(context.xdg_activation_token);
    context.note_overlay_text = deetty_grid_memory_clear(context.note_overlay_text);
    context.note_overlay_label = deetty_grid_memory_clear(context.note_overlay_label);
    g_clear_pointer(&context.note_overlay_font, pango_font_description_free);
    remove_grid_source(&context.status_feedback_source);
    remove_grid_source(&context.sharing_status_source);
    context.status_feedback_text = deetty_grid_memory_clear(context.status_feedback_text);
    context.smart_filter_tag = deetty_grid_memory_clear(context.smart_filter_tag);
    for (guint index = 0; index < context.contexts->len; index++) {
        DeettyGridContext *candidate = g_ptr_array_index(context.contexts, index);
        candidate->display_title = deetty_grid_memory_clear(candidate->display_title);
        candidate->font_family = deetty_grid_memory_clear(candidate->font_family);
        candidate->frame_cells = deetty_grid_memory_clear(candidate->frame_cells);
        candidate->dirty_row_buffer = deetty_grid_memory_clear(candidate->dirty_row_buffer);
        candidate->dirty_span_buffer = deetty_grid_memory_clear(candidate->dirty_span_buffer);
        destroy_grid_glyph_cache(candidate);
        destroy_gpu_resources(candidate);
        g_clear_pointer(&candidate->note_overlay_font,
                        pango_font_description_free);
        candidate->im_context = deetty_grid_object_clear(candidate->im_context);
        if (candidate->heap_allocated) deetty_grid_memory_free(candidate);
    }
    g_ptr_array_free(context.contexts, TRUE);
    return context.control_name_conflict ? 3 : 0;
#else
    if (context.layout_save_source != 0) {
        deetty_grid_source_remove(context.layout_save_source);
        context.layout_save_source = 0;
        if (!context.control_name_conflict && context.event_data != NULL)
            (void)deetty_grid_flush_hot_session(context.event_data);
    }
    int control_was_registered = context.control_registered;
    int tray_was_registered = context.tray_registered;
    int tray_menu_was_registered = context.tray_menu_registered;
    int tray_watcher_was_registered = context.tray_watcher_registered;
    int tray_icon_was_available = context.tray_icon_available;
    drain_grid_dbus_operations(&context);
    unregister_grid_shortcut(&context);
    unregister_grid_tray(&context);
    unregister_grid_control(&context);
    cancel_grid_dbus_operations(&context);
    remove_grid_source(&context.application_close_deferred_source);
    remove_grid_source(&context.application_close_preflight_source);
    remove_grid_source(&context.window_mode_recreate_source);
    remove_grid_source(&context.cursor_blink_source);
    remove_grid_source(&context.maintenance_source);
    int contexts_ok = 1;
    gboolean activation_child_smoke =
        g_getenv("DEETTY_ACTIVATION_CHILD_RECEIPT") != NULL;
    guint descriptor_contexts = 0;
    guint descriptor_contexts_coalesced = 0;
    for (guint index = 0; index < context.contexts->len; index++) {
        DeettyGridContext *candidate = g_ptr_array_index(context.contexts, index);
        if (candidate->pty_event_source_started) {
            descriptor_contexts++;
            if (candidate->descriptor_tick_coalesced)
                descriptor_contexts_coalesced++;
        }
        stop_grid_context_sources(candidate);
        if (candidate->active &&
            (!candidate->exited ||
             candidate->exit_code != 0 ||
             (!candidate->saw_draw && workspace_smoke != 16 &&
              workspace_smoke != 30 && !activation_child_smoke))) {
            contexts_ok = 0;
        }
        if ((workspace_smoke == 2 || workspace_smoke == 20) &&
            !candidate->pty_event_source_started) contexts_ok = 0;
    }
    GtkPositionType final_tab_position =
        (GtkPositionType)deetty_grid_notebook_get_tab_pos(GTK_NOTEBOOK(context.notebook));
    gint final_page_count =
        deetty_grid_notebook_get_n_pages(GTK_NOTEBOOK(context.notebook));
    gint final_active_page =
        deetty_grid_notebook_get_current_page(GTK_NOTEBOOK(context.notebook));
    gboolean final_tabs_visible =
        deetty_grid_notebook_get_show_tabs(GTK_NOTEBOOK(context.notebook));
    int resize_grip_request_height = -1;
    if (context.resize_grip != NULL)
        deetty_grid_widget_get_size_request(context.resize_grip, NULL,
                                    &resize_grip_request_height);
    int compact_im_ready = context.im_context != NULL;
    int resize_side_request_width = -1;
    if (context.window_resize_handles[3] != NULL)
        deetty_grid_widget_get_size_request(context.window_resize_handles[3],
                                    &resize_side_request_width, NULL);
    const char *terminal_cursor_name = context.area != NULL
        ? deetty_grid_object_get_data(G_OBJECT(context.area), "deetty-cursor-name")
        : NULL;
    const char *dragger_cursor_name = context.resize_grip != NULL
        ? deetty_grid_object_get_data(G_OBJECT(context.resize_grip),
                            "deetty-resize-cursor-name")
        : NULL;
    int cursor_chrome_ok =
        g_strcmp0(terminal_cursor_name, "text") == 0 &&
        g_strcmp0(dragger_cursor_name, "ns-resize") == 0 &&
        resize_side_request_width == policy.window_resize_border_px;
    for (int index = 0; index < 8; index++) {
        const char *name = context.window_resize_handles[index] != NULL
            ? deetty_grid_object_get_data(
                  G_OBJECT(context.window_resize_handles[index]),
                  "deetty-resize-cursor-name")
            : NULL;
        if (name != NULL && (strstr(name, "nwse") != NULL ||
                             strstr(name, "nesw") != NULL))
            cursor_chrome_ok = 0;
    }
    GList *content_children = deetty_grid_container_get_children(
        GTK_CONTAINER(context.content_box));
    int pane_info_below_notebook = content_children != NULL &&
        GTK_WIDGET(content_children->data) == context.notebook &&
        GTK_WIDGET(g_list_last(content_children)->data) ==
            context.pane_info_strip;
    g_list_free(content_children);
    int tab_rename_rendered = 0;
    int hot_session_titles_rendered = 0;
    int hot_session_color_rendered = 0;
    for (gint page_index = 0; page_index < final_page_count; page_index++) {
        GtkWidget *page = deetty_grid_notebook_get_nth_page(GTK_NOTEBOOK(context.notebook),
                                                    page_index);
        GtkWidget *tab_widget = deetty_grid_notebook_get_tab_label(
            GTK_NOTEBOOK(context.notebook), page);
        GtkWidget *label = tab_label_from_widget(tab_widget);
        const gchar *text = deetty_grid_widget_is_type(label, DEETTY_GTK_LABEL)
            ? deetty_grid_label_get_text(GTK_LABEL(label))
            : NULL;
        if (text != NULL && strstr(text, "Build logs") != NULL) {
            tab_rename_rendered = 1;
            if (workspace_smoke == 30) hot_session_titles_rendered++;
        }
        if (workspace_smoke == 30 && text != NULL &&
            strstr(text, "Deploy") != NULL)
            hot_session_titles_rendered++;
        if (workspace_smoke == 30 &&
            GPOINTER_TO_UINT(deetty_grid_object_get_data(
                G_OBJECT(tab_widget), "deetty-tab-color-rgb")) == 0x4285f4)
            hot_session_color_rendered = 1;
    }
    int hot_session_tag_tooltip = 0;
    int hot_session_profile = 0;
    if (workspace_smoke == 30) {
        for (guint index = 0; index < context.contexts->len; index++) {
            DeettyGridContext *candidate =
                g_ptr_array_index(context.contexts, index);
            gchar *tooltip = candidate->area != NULL
                ? deetty_grid_widget_get_tooltip_text(candidate->area) : NULL;
            if (tooltip != NULL && strstr(tooltip, "tags: ops") != NULL)
                hot_session_tag_tooltip = 1;
            deetty_grid_memory_free(tooltip);
            if (candidate->font_size > 13.9 && candidate->font_size < 14.1)
                hot_session_profile = 1;
        }
    }
    int hot_session_ok = workspace_smoke != 30 ||
        (context.hot_session_restored &&
         context.hot_session_tab_count == 2 &&
         context.hot_session_pane_count == 5 &&
         context.hot_session_layout_ready &&
         context.hot_session_active_ready &&
         context.hot_session_smart_filter_ready &&
         context.smart_filter_tag != NULL &&
         g_strcmp0(context.smart_filter_tag, "ops") == 0 &&
         context.contexts->len == 5 && final_page_count == 2 &&
         final_active_page == 1 &&
         final_tab_position == GTK_POS_BOTTOM &&
         hot_session_titles_rendered == 2 &&
         hot_session_color_rendered && hot_session_tag_tooltip &&
         hot_session_profile);
    int layer_shell_was_active = context.layer_shell_active;
    const gchar *final_window_title =
        deetty_grid_window_get_title(context.window);
    int dropdown_identity_ready = workspace_smoke != 16 ||
        (final_window_title != NULL &&
         g_str_has_prefix(final_window_title, "DEETTY Dropdown"));
    dismiss_grid_popup_windows(&context);
    while (deetty_grid_events_pending()) deetty_grid_main_iteration_do(FALSE);
    deetty_grid_widget_destroy(context.window);
    if (context.layer_shell_library != NULL) {
        dlclose(context.layer_shell_library);
        context.layer_shell_library = NULL;
        context.layer_shell_active = 0;
    }
    int clipboard_ok = workspace_smoke != 4 ||
        (context.clipboard_pasted && context.clipboard_copy_valid);
    int broadcast_safety_ok = workspace_smoke != 1 ||
        (context.broadcast_confirmation_explicit &&
         context.broadcast_confirmation_cancel_default &&
         context.broadcast_disable_immediate &&
         context.broadcast_disable_feedback &&
         context.broadcast_state_label);
    int notification_ok = workspace_smoke != 5 || context.notification_delivered;
    int sharing_scope_ok = workspace_smoke != 41 ||
        (context.sharing_scope_smoke_ok &&
         context.sharing_dialog_scrollable &&
         context.sharing_dialog_stacking &&
         context.sharing_dialog_grouped_actions);
    int settings_ok = workspace_smoke != 6 ||
        (context.window_settings_button_activated &&
         context.window_close_button_activated &&
         context.window_close_session_stopped &&
         context.settings_opened && context.settings_category_count == 3 &&
         context.settings_category_accessible &&
         context.settings_category_focusable &&
         context.settings_category_focus_initial &&
         context.settings_category_tooltips &&
         context.settings_visual_polish &&
         context.settings_background_support_notice &&
         context.translucent_surface_ready &&
         context.settings_metric_thickness_live &&
         context.settings_narrow_access &&
         context.settings_geometry_sane &&
         context.window_mode_surface_recreated &&
         context.settings_reopened_after_mode_change &&
         context.settings_page_switched && context.tab_position == 1 &&
         final_tab_position == GTK_POS_BOTTOM && pane_info_below_notebook &&
         context.shortcut_recorder_shown && context.shortcut_recorded &&
         context.shortcut_recorder_settings_handoff &&
         context.shortcut_recorder_settings_restored &&
         context.settings_shortcut_label_current &&
         context.settings_shortcut_label_updated &&
         context.pane_info_setting_control &&
         context.pane_info_setting_toggled && context.show_pane_info &&
         context.launch_profile_setting_control &&
         context.launch_profile_setting_applied &&
         context.launch_profile_feedback &&
         context.launch_profile_library_control &&
         context.launch_profile_library_saved &&
         context.launch_profile_library_selected &&
         context.launch_profile_library_removed);
    int settings_stacking_ok = workspace_smoke != 28 ||
        (context.settings_stacking_ready &&
         context.settings_stacking_visible &&
         context.settings_geometry_sane &&
         context.settings_transient_parent &&
         context.settings_keep_above &&
         context.settings_parent_layer_restored &&
         (!layer_shell_was_active ||
          (context.settings_layer_overlay &&
           context.settings_parent_layer_lowered_seen)));
    int note_overlay_ok = workspace_smoke != 29 ||
        (context.note_overlay_alt_pressed &&
         context.note_overlay_alt_released &&
         context.note_overlay_content_loaded &&
         context.note_overlay_smoke_panes >= 2 &&
         context.note_overlay_smoke_all_drawn &&
         context.note_overlay_smoke_hidden);
    int navigation_ok = workspace_smoke != 22 ||
        (context.pane_cycle_next && context.alt_scroll_cycle_next &&
         context.alt_scroll_cycle_previous && context.alt_scroll_current_tab &&
         context.alt_scroll_hidden_skipped &&
         context.pane_cycle_feedback_drawn &&
         context.ctrl_alt_scroll_cycle_next &&
         context.ctrl_alt_scroll_cycle_previous &&
         context.ctrl_alt_scroll_wraparound &&
         context.tab_cycle_feedback_drawn && context.tab_cycle_next &&
         context.tab_cycle_previous && context.tab_cycle_smart_filter &&
         context.tab_shortcut_close && context.tab_shortcut_reopen);
    int terminal_chords_ok = workspace_smoke != 31 ||
        (context.ctrl_c_local_interrupt &&
         context.terminal_chord_interrupt_focused &&
         context.terminal_chord_enter_forwarded &&
         context.ctrl_d_close_attempted && context.ctrl_d_close_succeeded &&
         context.terminal_chord_close_exact &&
         context.terminal_chord_close_rendered &&
         context.terminal_chord_close_session_stopped &&
         context.terminal_chord_remaining_focused &&
         context.terminal_chord_final_protected &&
         final_page_count == 1 && final_tabs_visible);
    int theme_ok = workspace_smoke != 7 ||
        (context.theme_imported && context.theme_import_dialog_built &&
         context.system_noctalia_theme_listed &&
         context.system_noctalia_theme_applied &&
         context.theme_visual_polish);
    int project_ok = workspace_smoke != 8 ||
        (context.project_smoke_done && context.recent_workspace_control &&
         context.project_summary_scrollable &&
         context.project_summary_accessible &&
         context.project_visual_polish &&
         context.nocted_launch_attempted &&
         context.nocted_launch_succeeded && context.nocted_process_separate &&
         context.nocted_directory_resolved);
    int recent_workspace_activation_ok = workspace_smoke != 35 ||
        (context.recent_workspace_control &&
         context.recent_workspace_parent_rendered &&
         context.recent_workspace_child_clicked &&
         context.recent_workspace_child_launched);
    int shortcut_ok = workspace_smoke != 9 ||
        (context.shortcut_invoked &&
         context.shortcut_hidden_before_registration &&
         context.shortcut_recorder_shown && context.shortcut_recorded &&
         context.requested_shortcut_key == 16777273);
    int control_ok = workspace_smoke != 16 ||
        (!layer_shell_was_active && control_was_registered &&
         dropdown_identity_ready &&
         context.control_status_seen && context.control_status_count >= 2 &&
         context.control_show_seen && context.control_hide_seen &&
         context.control_toggle_seen &&
         resize_grip_request_height == context.dragger_px);
    int recursive_zoom_ok = workspace_smoke != 11 ||
        (context.recursive_zoom_full_page &&
         context.recursive_zoom_restored);
    int focus_ok = workspace_smoke != 12 ||
        (context.focus_click_primary && context.focus_click_secondary &&
         context.focus_click_controlled_exit &&
         context.focus_double_click_word_selection &&
         context.focus_double_click_zoom_clean &&
         context.focus_double_click_restore_clean &&
         context.focus_drag_selection_preserved);
    int move_ok = (workspace_smoke != 1 && workspace_smoke != 14) ||
        (context.pane_move_applied &&
         final_page_count == (workspace_smoke == 14 ? 1 : 2));
    int compact_ok = workspace_smoke != 15 ||
        (context.compact_palette_shown &&
         context.compact_palette_context_opened &&
         context.compact_context_submenus &&
         context.compact_new_1x1_removed &&
         context.compact_even_distribution_cancelled &&
         context.compact_palette_rename_suppressed &&
         context.compact_find_shown && context.compact_note_shown &&
         context.compact_accessibility_mask == 7u &&
         context.compact_utility_visual_polish == 7u &&
         context.compact_shortcut_label_dynamic &&
         context.compact_light_tab_title_inherits &&
         context.compact_zoom_toggled && context.status_feedback_drawn &&
         context.compact_directional_focus && context.compact_scrollback_saved &&
         context.compact_attention_seen && compact_im_ready &&
         context.resize_grip != NULL && context.compact_font_scroll_up &&
         context.compact_font_scroll_down && context.compact_font_scroll_isolated &&
         context.compact_font_key_up && context.compact_font_key_down &&
         context.compact_font_smooth &&
         context.compact_plain_scroll_preserved &&
         context.compact_hyperlink_open_attempted &&
         context.compact_hyperlink_context_menu &&
         context.compact_hyperlink_context_open &&
         context.compact_hyperlink_mouse_mode_override &&
         context.compact_hyperlink_underline_positioned &&
         context.compact_linear_selection &&
         context.compact_linear_selection_copy &&
         context.compact_background_fill_seamless &&
         context.compact_terminal_caret_drawn &&
         context.compact_dragger_height_toggle &&
         context.compact_scrollbar_drawn &&
         context.compact_terminal_accessible_text &&
         context.compact_zoom_hid_tab_bar &&
         context.compact_zoom_restored_tab_bar &&
         context.compact_pane_info_rendered &&
         context.compact_pane_info_positioned &&
         context.compact_pane_info_source &&
         context.compact_pane_info_dedup &&
         cursor_chrome_ok &&
         resize_side_request_width == context.window_border_px &&
         resize_grip_request_height == context.dragger_px);
    int tab_rename_ok = workspace_smoke != 17 ||
        (context.tab_rename_double_click_seen && context.tab_rename_inline_shown &&
         context.tab_rename_inline_embedded &&
         context.tab_rename_outside_cancelled && context.tab_rename_applied &&
         context.tab_rename_focus_restored && tab_rename_rendered);
    int tab_color_ok = workspace_smoke != 27 ||
        (context.tab_color_menu_opened &&
         context.tab_color_preset_applied &&
         context.tab_color_rendered &&
         context.tab_color_contrast_ready &&
         context.tab_color_shortcut_lighten &&
         context.tab_color_shortcut_darken &&
         context.tab_color_initial_rgb == 0x4285f4 &&
         context.tab_color_lightened_rgb != context.tab_color_initial_rgb &&
         context.tab_color_restored_rgb == context.tab_color_initial_rgb);
    int profile_preset_ok = workspace_smoke != 33 ||
        (context.context_menu_opened && context.context_menu_survived &&
         context.profile_menu_opened == 3 &&
         context.profile_menu_survived &&
         context.profile_menu_current == 3 &&
         context.profile_menu_selected == 3 &&
         context.profile_exact_target && context.profile_readable &&
         context.profile_isolated && context.profile_high_contrast &&
         context.profile_rendered && context.profile_mono_no_ligatures);
    int tab_add_ok = workspace_smoke != 3 ||
        (context.new_tab_button_visible && context.new_tab_button_at_start &&
         context.new_tab_button_icon && context.new_tab_button_accessible &&
         context.new_tab_button_clicked &&
         context.new_tab_button_visible_after_close &&
         context.new_tab_button_reopened_after_close &&
         context.new_tab_button_fresh_context &&
         context.new_tab_button_cleanup &&
         context.tab_active_styled &&
         context.tab_close_button_visible &&
         context.compact_tab_geometry);
    int tab_close_ok = workspace_smoke != 3 ||
        (context.tab_context_menu_opened &&
         context.tab_context_menu_survived &&
         context.tab_close_targeted_background &&
         context.tab_close_applied && context.tab_close_session_stopped &&
         context.tab_close_remaining_focused &&
         context.late_callback_guarded && final_page_count == 1 &&
         final_tabs_visible);
    int pane_close_ok = workspace_smoke != 20 ||
        (context.pane_close_menu_opened &&
         context.pane_close_menu_survived &&
         context.pane_close_menu_popped_down &&
         context.pane_close_targeted_primary &&
         context.pane_close_applied &&
         context.pane_close_session_stopped &&
         context.pane_close_rendered_collapsed &&
         context.pane_close_remaining_focused &&
         context.pane_close_last_terminal_protected &&
         context.pane_split_evenly_distributed &&
         context.pane_split_two_by_two &&
         context.pane_split_resize_equal &&
         context.pane_close_evenly_distributed &&
         context.pane_close_user_resize_preserved &&
         context.terminal_close_prompt_count > 0 &&
         context.terminal_close_prompt_accepted > 0 &&
         context.terminal_close_prompt_busy_count > 0 &&
         final_page_count == 1 && final_tabs_visible);
    int layout_preset_ok = workspace_smoke == 43
        ? (context.context_menu_opened &&
           context.session_creation_focus_deferred &&
           context.layout_preset_menu_survived &&
           context.layout_preset_4x4_applied &&
           context.layout_preset_4x4_rendered &&
           context.layout_preset_created_count == 0 &&
           context.layout_preset_closed_count == 0 &&
           final_page_count == 2 && final_tabs_visible)
        : workspace_smoke != 21 ||
          (context.context_menu_opened &&
           context.session_creation_focus_deferred &&
           context.layout_preset_menu_survived &&
           context.layout_preset_2x2_applied &&
           context.layout_preset_2x2_rendered &&
           context.layout_preset_4x2_applied &&
           context.layout_preset_4x2_rendered &&
           context.layout_preset_3x3_applied &&
           context.layout_preset_3x3_rendered &&
           context.layout_preset_4x4_applied &&
           context.layout_preset_4x4_rendered &&
           context.layout_preset_1x1_applied &&
           context.layout_preset_1x1_rendered &&
           context.layout_preset_churn_rounds == 8 &&
           context.layout_preset_created_count == 43 &&
           context.layout_preset_closed_count == 28 &&
           context.layout_preset_prompt_count == 2 &&
           context.layout_preset_prompt_cancelled == 1 &&
           context.layout_preset_prompt_accepted == 1 &&
           context.layout_preset_moved_count == 15 &&
           context.layout_preset_remaining_focused &&
           final_page_count == 2 && final_tabs_visible);
    if (workspace_smoke == 21 && !layout_preset_ok)
        g_printerr("native_grid_layout_preset_failure context_menu=%d focus_deferred=%d menu=%d 2x2=%d/%d 4x2=%d/%d 3x3=%d/%d 4x4=%d/%d 1x1=%d/%d churn=%d created=%d closed=%d prompts=%d/%d/%d moved=%d focused=%d pages=%d tabs_visible=%d\n",
                   context.context_menu_opened,
                   context.session_creation_focus_deferred,
                   context.layout_preset_menu_survived,
                   context.layout_preset_2x2_applied,
                   context.layout_preset_2x2_rendered,
                   context.layout_preset_4x2_applied,
                   context.layout_preset_4x2_rendered,
                   context.layout_preset_3x3_applied,
                   context.layout_preset_3x3_rendered,
                   context.layout_preset_4x4_applied,
                   context.layout_preset_4x4_rendered,
                   context.layout_preset_1x1_applied,
                   context.layout_preset_1x1_rendered,
                   context.layout_preset_churn_rounds,
                   context.layout_preset_created_count,
                   context.layout_preset_closed_count,
                   context.layout_preset_prompt_count,
                   context.layout_preset_prompt_cancelled,
                   context.layout_preset_prompt_accepted,
                   context.layout_preset_moved_count,
                   context.layout_preset_remaining_focused,
                   final_page_count, final_tabs_visible);
    if (workspace_smoke == 43 && !layout_preset_ok)
        g_printerr("native_grid_4x4_failure context_menu=%d focus_deferred=%d menu=%d applied=%d rendered=%d created=%d closed=%d pages=%d tabs_visible=%d\n",
                   context.context_menu_opened,
                   context.session_creation_focus_deferred,
                   context.layout_preset_menu_survived,
                   context.layout_preset_4x4_applied,
                   context.layout_preset_4x4_rendered,
                   context.layout_preset_created_count,
                   context.layout_preset_closed_count,
                   final_page_count, final_tabs_visible);
    int resize_overlay_ok = workspace_smoke != 18 ||
        (context.resize_overlay_initial_suppressed &&
         context.resize_overlay_smoke_initial_hidden &&
         context.resize_overlay_smoke_moves == 2 &&
         context.resize_overlay_smoke_visible &&
         context.resize_overlay_smoke_realtime &&
         context.resize_overlay_smoke_hidden);
    int session_creation_focus_ok =
        (workspace_smoke != 1 && workspace_smoke != 3) ||
        context.session_creation_focus_deferred;
    int window_tray_ok = workspace_smoke != 19 ||
        (context.window_resize_handle_count == 8 &&
         context.window_resize_affordance_ready &&
         context.window_native_decorated &&
         context.window_native_resizable &&
         context.window_resize_geometry_changed &&
         tray_was_registered && tray_menu_was_registered &&
         tray_watcher_was_registered &&
         tray_icon_was_available && context.tray_activation_count >= 2 &&
         context.tray_secondary_seen && context.tray_context_seen &&
         context.tray_menu_layout_seen && context.tray_close_seen &&
         context.tray_close_session_stopped);
    int selection_visual_ok = workspace_smoke != 1 ||
        (context.selection_border_drawn &&
         context.dropdown_minimum_geometry);
    int tag_filter_ok = workspace_smoke != 1 ||
        (context.tag_filter_applied && context.tag_filter_match &&
         context.tag_filter_untagged_hidden && context.tag_filter_cleared &&
         context.tag_filter_indicator_visible && context.tag_filter_focus_restored &&
         context.tag_filter_empty_state_visible && context.tag_filter_empty_clear &&
         context.tag_filter_empty_context && context.tag_filter_empty_escape &&
         context.tag_suggestions_visible);
    int selection_indicator_ok = workspace_smoke != 1 ||
        context.selection_indicator_visible;
    int descriptor_timer_ok =
        (workspace_smoke != 13 && workspace_smoke != 34) ||
        (descriptor_contexts == context.contexts->len &&
         descriptor_contexts_coalesced == descriptor_contexts &&
         context.descriptor_maintenance_fallback_seen);
    int source_cleanup_ok =
        context.source_cleanup_count >= context.contexts->len &&
        (workspace_smoke != 21 ||
         context.source_cleanup_count >=
             (guint)context.layout_preset_closed_count +
                 context.contexts->len);
    int renderer_damage_ok = workspace_smoke != 0 ||
        (context.frame_batches_drawn > 0 && context.damage_rows_queued > 0 &&
         context.damage_cells_queued > 0 && context.damage_spans_queued > 0 &&
         context.terminal_dirty_spans_used &&
         context.glyph_batches_drawn > 0 &&
         context.glyph_cells_batched > 0 && context.glyph_cache_hits > 0 &&
         context.grapheme_cells_drawn > 0 &&
         context.rich_style_cells_drawn > 0 &&
         context.frame_presentations > 0 && context.resize_requests > 0 &&
         context.resize_commits > 0 &&
         context.synchronized_output_deferrals > 0 &&
         context.synchronized_output_releases > 0 &&
         context.synchronized_output_deadman_releases > 0 &&
         !context.output_present_is_tick);
#if DEETTY_ENABLE_SMOKE
#include "../../tests/native_grid_smoke_results.inc"
#else
    int presentation_ok = 1;
    int full_stack_ok = 1;
    int stability_ok = 1;
    int installed_continuity_ok = 1;
#endif
    int pane_scrollbar_ok = workspace_smoke != 42 ||
        (context.compact_scrollbar_drawn &&
         context.compact_scrollbar_history_lines > 0 &&
         context.compact_scrollbar_mouse_mode_wheel &&
         !context.compact_scrollbar_tui_forwarded &&
         context.compact_scrollbar_track_scrolled &&
         context.compact_scrollbar_thumb_dragged &&
         context.compact_keyboard_scrollback_up &&
         context.compact_keyboard_scrollback_down);
    context.xdg_activation_token = deetty_grid_memory_clear(context.xdg_activation_token);
    context.note_overlay_text = deetty_grid_memory_clear(context.note_overlay_text);
    context.note_overlay_label = deetty_grid_memory_clear(context.note_overlay_label);
    g_clear_pointer(&context.note_overlay_font, pango_font_description_free);
    remove_grid_source(&context.status_feedback_source);
    remove_grid_source(&context.sharing_status_source);
    context.status_feedback_text = deetty_grid_memory_clear(context.status_feedback_text);
    context.smart_filter_tag = deetty_grid_memory_clear(context.smart_filter_tag);
    for (guint index = 0; index < context.contexts->len; index++) {
        DeettyGridContext *candidate = g_ptr_array_index(context.contexts, index);
        candidate->display_title = deetty_grid_memory_clear(candidate->display_title);
        candidate->font_family = deetty_grid_memory_clear(candidate->font_family);
        candidate->frame_cells = deetty_grid_memory_clear(candidate->frame_cells);
        candidate->dirty_row_buffer = deetty_grid_memory_clear(candidate->dirty_row_buffer);
        candidate->dirty_span_buffer = deetty_grid_memory_clear(candidate->dirty_span_buffer);
        destroy_grid_glyph_cache(candidate);
        destroy_gpu_resources(candidate);
        g_clear_pointer(&candidate->note_overlay_font, pango_font_description_free);
        candidate->im_context = deetty_grid_object_clear(candidate->im_context);
        if (candidate->heap_allocated) deetty_grid_memory_free(candidate);
    }
    g_ptr_array_free(context.contexts, TRUE);
    int host_ok = recursive_zoom_ok && contexts_ok && clipboard_ok && broadcast_safety_ok &&
        notification_ok && sharing_scope_ok && settings_ok &&
        settings_stacking_ok && note_overlay_ok && navigation_ok &&
        terminal_chords_ok && hot_session_ok &&
        theme_ok && project_ok && shortcut_ok && control_ok && focus_ok && move_ok &&
        compact_ok && tab_rename_ok && tab_color_ok && profile_preset_ok &&
        tab_add_ok && tab_close_ok && pane_close_ok &&
        layout_preset_ok && resize_overlay_ok && selection_visual_ok &&
        tag_filter_ok && selection_indicator_ok &&
        session_creation_focus_ok &&
        descriptor_timer_ok && source_cleanup_ok && window_tray_ok &&
        recent_workspace_activation_ok && presentation_ok && full_stack_ok &&
        stability_ok && installed_continuity_ok && pane_scrollbar_ok;
    host_ok = host_ok && renderer_damage_ok &&
        context.application_icon_ready;
    const gboolean renderer_benchmark =
        workspace_smoke == 0 || g_getenv("DEETTY_BENCH_RENDERER") != NULL;
    if (renderer_benchmark) {
        g_print("native_grid_renderer_smoke abi=%d frame_batches=%u damage_rows=%u damage_cells=%u damage_spans=%u damage_source=dirty_spans glyph_batches=%u glyph_cells=%u glyph_cache_hits=%u glyph_fallback_conversions=%u grapheme_cells=%u rich_style_cells=%u frame_presentations=%u timeout_presentations=%u resize_requests=%u resize_commits=%u sync_deferrals=%u sync_releases=%u sync_deadman_releases=%u renderer_requested=%s renderer_effective=%s gpu_render_frames=%u gpu_texture_uploads=%u gpu_fallbacks=%u passed=%s\n",
                DEETTY_NATIVE_GRID_ABI_VERSION,
                context.frame_batches_drawn, context.damage_rows_queued,
                context.damage_cells_queued, context.damage_spans_queued,
                context.glyph_batches_drawn, context.glyph_cells_batched,
                context.glyph_cache_hits,
                context.glyph_fallback_conversions,
                context.grapheme_cells_drawn,
                context.rich_style_cells_drawn,
                context.frame_presentations,
                context.timeout_presentations,
                context.resize_requests, context.resize_commits,
                context.synchronized_output_deferrals,
                context.synchronized_output_releases,
                context.synchronized_output_deadman_releases,
                context.renderer_backend_requested != 0 ? "opengl" : "cairo",
                context.renderer_backend != 0 ? "opengl" : "cairo",
                context.gpu_render_frames,
                context.gpu_texture_uploads,
                context.gpu_fallbacks,
                renderer_damage_ok ? "true" : "false");
        fflush(stdout);
    }
#if DEETTY_ENABLE_SMOKE
#include "../../tests/native_grid_smoke_reports.inc"
#endif
    if (!host_ok && (workspace_smoke == 13 || workspace_smoke == 34)) {
        g_printerr("native_grid_descriptor_timer_flags contexts=%u coalesced=%u maintenance_fallback=%d cleanup_calls=%u\n",
                   descriptor_contexts, descriptor_contexts_coalesced,
                   context.descriptor_maintenance_fallback_seen,
                   context.source_cleanup_count);
    }
    if (!host_ok && workspace_smoke == 22) {
        g_printerr("native_grid_navigation_flags pane_ctrl_tab=%d alt_next=%d alt_previous=%d current_tab=%d hidden_skipped=%d pane_feedback=%d ctrl_alt_next=%d ctrl_alt_previous=%d tab_wrap=%d tab_feedback=%d tab_next=%d tab_previous=%d smart_filter=%d shortcut_close=%d shortcut_reopen=%d\n",
                   context.pane_cycle_next,
                   context.alt_scroll_cycle_next,
                   context.alt_scroll_cycle_previous,
                   context.alt_scroll_current_tab,
                   context.alt_scroll_hidden_skipped,
                   context.pane_cycle_feedback_drawn,
                   context.ctrl_alt_scroll_cycle_next,
                   context.ctrl_alt_scroll_cycle_previous,
                   context.ctrl_alt_scroll_wraparound,
                   context.tab_cycle_feedback_drawn,
                   context.tab_cycle_next,
                   context.tab_cycle_previous,
                   context.tab_cycle_smart_filter,
                   context.tab_shortcut_close,
                   context.tab_shortcut_reopen);
    }
    if (!host_ok && workspace_smoke == 31) {
        g_printerr("native_grid_terminal_chord_flags ctrl_c_local=%d interrupt_focused=%d enter_forwarded=%d ctrl_d_attempted=%d ctrl_d_succeeded=%d close_exact=%d close_rendered=%d session_stopped=%d remaining_focused=%d final_protected=%d pages=%d tabs_visible=%d\n",
                   context.ctrl_c_local_interrupt,
                   context.terminal_chord_interrupt_focused,
                   context.terminal_chord_enter_forwarded,
                   context.ctrl_d_close_attempted,
                   context.ctrl_d_close_succeeded,
                   context.terminal_chord_close_exact,
                   context.terminal_chord_close_rendered,
                   context.terminal_chord_close_session_stopped,
                   context.terminal_chord_remaining_focused,
                   context.terminal_chord_final_protected,
                   final_page_count,
                   final_tabs_visible);
    }
    if (!host_ok && workspace_smoke == 12) {
        g_printerr("native_grid_click_focus_flags stage=%d primary=%d secondary=%d controlled_exit=%d word=%d zoom=%d restore=%d drag=%d\n",
                   context.focus_click_smoke_stage,
                   context.focus_click_primary,
                   context.focus_click_secondary,
                   context.focus_click_controlled_exit,
                   context.focus_double_click_word_selection,
                   context.focus_double_click_zoom_clean,
                   context.focus_double_click_restore_clean,
                   context.focus_drag_selection_preserved);
    }
    if (!host_ok && workspace_smoke == 8) {
        g_printerr("native_grid_nocted_flags project=%d recent_control=%d summary_scroll=%d project_accessible=%d attempted=%d launched=%d separate=%d directory_resolved=%d\n",
                   context.project_smoke_done,
                   context.recent_workspace_control,
                   context.project_summary_scrollable,
                   context.project_summary_accessible,
                   context.nocted_launch_attempted,
                   context.nocted_launch_succeeded,
                   context.nocted_process_separate,
                   context.nocted_directory_resolved);
    }
    if (!host_ok && workspace_smoke == 6) {
        g_printerr("native_grid_settings_flags toolbar=%d order=%d button_pointer=%d button_tooltips=%d settings_activated=%d close_activated=%d session_stopped=%d settings_opened=%d categories=%d category_accessible=%d category_focusable=%d category_initial_focus=%d category_tooltips=%d support_notice=%d translucent=%d metric=%d narrow_access=%d geometry=%d page_switch=%d mode_recreated=%d settings_reopened=%d tab_position=%d shortcut_shown=%d shortcut_recorded=%d handoff=%d restored=%d labels=%d/%d pane_info=%d/%d launch_control=%d launch_applied=%d library_control=%d library_saved=%d library_selected=%d library_removed=%d\n",
                   context.window_toolbar_visible,
                   context.window_toolbar_yakuake_order,
                   context.action_button_pointer_normal,
                   context.action_button_tooltips_ready,
                   context.window_settings_button_activated,
                   context.window_close_button_activated,
                   context.window_close_session_stopped,
                   context.settings_opened,
                   context.settings_category_count,
                   context.settings_category_accessible,
                   context.settings_category_focusable,
                   context.settings_category_focus_initial,
                   context.settings_category_tooltips,
                   context.settings_background_support_notice,
                   context.translucent_surface_ready,
                   context.settings_metric_thickness_live,
                   context.settings_narrow_access,
                   context.settings_geometry_sane,
                   context.settings_page_switched,
                   context.window_mode_surface_recreated,
                   context.settings_reopened_after_mode_change,
                   context.tab_position,
                   context.shortcut_recorder_shown,
                   context.shortcut_recorded,
                   context.shortcut_recorder_settings_handoff,
                   context.shortcut_recorder_settings_restored,
                   context.settings_shortcut_label_current,
                   context.settings_shortcut_label_updated,
                   context.pane_info_setting_control,
                   context.pane_info_setting_toggled,
                   context.launch_profile_setting_control,
                   context.launch_profile_setting_applied,
                   context.launch_profile_library_control,
                   context.launch_profile_library_saved,
                   context.launch_profile_library_selected,
                   context.launch_profile_library_removed);
    }
    if (!host_ok && workspace_smoke == 28) {
        g_printerr("native_grid_settings_stacking_flags visible=%d transient=%d keep_above=%d layer_overlay=%d parent_lowered=%d parent_restored=%d ready=%d\n",
                   context.settings_stacking_visible,
                   context.settings_transient_parent,
                   context.settings_keep_above,
                   context.settings_layer_overlay,
                   context.settings_parent_layer_lowered_seen,
                   context.settings_parent_layer_restored,
                   context.settings_stacking_ready);
    }
    if (!host_ok && workspace_smoke == 15) {
        g_printerr("native_grid_compact_new_flags submenus=%d new_1x1_removed=%d distribution_cancelled=%d caret=%d dragger=%d height=%d toggled=%d hyperlink_open=%d hyperlink_tui=%d hyperlink_underline=%d linear_selection=%d linear_selection_copy=%d seamless_background=%d\n",
                   context.compact_context_submenus,
                   context.compact_new_1x1_removed,
                   context.compact_even_distribution_cancelled,
                   context.compact_terminal_caret_drawn,
                   context.compact_dragger_height_toggle,
                   context.dropdown_height_percent,
                   context.dragger_height_toggled,
                   context.compact_hyperlink_open_attempted,
                   context.compact_hyperlink_mouse_mode_override,
                   context.compact_hyperlink_underline_positioned,
                   context.compact_linear_selection,
                   context.compact_linear_selection_copy,
                   context.compact_background_fill_seamless);
        g_printerr("native_grid_compact_ux_flags palette=%d find=%d note=%d accessibility_mask=%u dynamic_shortcut=%d zoom=%d direction=%d scrollback=%d attention=%d im=%d grip=%d grip_height=%d cursor_chrome=%d terminal_cursor=%s dragger_cursor=%s side_width=%d font_up=%d font_down=%d font_isolated=%d font_key_up=%d font_key_down=%d font_smooth=%d plain_scroll=%d tui_wheel=%d scrollbar_drawn=%d scrollbar_history=%" G_GUINT64_FORMAT " scrollbar_track=%d scrollbar_drag=%d terminal_accessible=%d tab_hidden=%d tab_restored=%d pane_rendered=%d pane_positioned=%d pane_source=%d pane_dedup=%d\n",
                   context.compact_palette_shown, context.compact_find_shown,
                   context.compact_note_shown,
                   context.compact_accessibility_mask,
                   context.compact_shortcut_label_dynamic,
                   context.compact_zoom_toggled,
                   context.compact_directional_focus,
                   context.compact_scrollback_saved,
                   context.compact_attention_seen, compact_im_ready,
                   context.resize_grip != NULL, resize_grip_request_height,
                   cursor_chrome_ok,
                   terminal_cursor_name != NULL ? terminal_cursor_name : "null",
                   dragger_cursor_name != NULL ? dragger_cursor_name : "null",
                   resize_side_request_width, context.compact_font_scroll_up,
                   context.compact_font_scroll_down,
                   context.compact_font_scroll_isolated,
                   context.compact_font_key_up,
                   context.compact_font_key_down,
                   context.compact_font_smooth,
                   context.compact_plain_scroll_preserved,
                   context.compact_tui_wheel_mapping,
                   context.compact_scrollbar_drawn,
                   context.compact_scrollbar_history_lines,
                   context.compact_scrollbar_track_scrolled,
                   context.compact_scrollbar_thumb_dragged,
                   context.compact_terminal_accessible_text,
                   context.compact_zoom_hid_tab_bar,
                   context.compact_zoom_restored_tab_bar,
                   context.compact_pane_info_rendered,
                   context.compact_pane_info_positioned,
                   context.compact_pane_info_source,
                   context.compact_pane_info_dedup);
    }
    if (!host_ok && workspace_smoke == 29) {
        g_printerr("native_grid_note_overlay_flags alt_pressed=%d alt_released=%d content=%d panes=%d drawn=%d hidden=%d\n",
                   context.note_overlay_alt_pressed,
                   context.note_overlay_alt_released,
                   context.note_overlay_content_loaded,
                   context.note_overlay_smoke_panes,
                   context.note_overlay_smoke_all_drawn,
                   context.note_overlay_smoke_hidden);
    }
    if (!host_ok && workspace_smoke == 30) {
        g_printerr("native_grid_hot_session_flags restored=%d tabs=%d panes=%d layout=%d active=%d smart_filter=%d titles=%d color=%d tags=%d profile=%d pages=%d active_page=%d tab_position=%d\n",
                   context.hot_session_restored,
                   context.hot_session_tab_count,
                   context.hot_session_pane_count,
                   context.hot_session_layout_ready,
                   context.hot_session_active_ready,
                   context.hot_session_smart_filter_ready,
                   hot_session_titles_rendered,
                   hot_session_color_rendered,
                   hot_session_tag_tooltip,
                   hot_session_profile,
                   final_page_count,
                   final_active_page,
                   final_tab_position);
    }
    if (!host_ok && workspace_smoke == 3) {
        g_printerr("native_grid_compact_tab_flags geometry=%d strip=%d tab=%d max_width=%d close=%d action=%d configured=%d\n",
                   context.compact_tab_geometry,
                   context.compact_tab_strip_extent,
                   context.compact_tab_widget_extent,
                   context.compact_tab_max_width,
                   context.compact_tab_close_extent,
                   context.compact_tab_action_extent,
                   context.compact_tab_height);
    }
    if (!host_ok && workspace_smoke == 27) {
        g_printerr("native_grid_tab_color_flags menu=%d preset=%d rendered=%d contrast=%d lighten=%d darken=%d initial=%06x lighter=%06x restored=%06x\n",
                   context.tab_color_menu_opened,
                   context.tab_color_preset_applied,
                   context.tab_color_rendered,
                   context.tab_color_contrast_ready,
                   context.tab_color_shortcut_lighten,
                   context.tab_color_shortcut_darken,
                   context.tab_color_initial_rgb,
                   context.tab_color_lightened_rgb,
                   context.tab_color_restored_rgb);
    }
    if (!host_ok && workspace_smoke == 33) {
        g_printerr("native_grid_profile_preset_flags context_menu=%d context_survived=%d opens=%d submenu_survived=%d current=%d selected=%d exact_target=%d readable=%d isolation=%d high_contrast=%d rendered=%d mono_no_ligatures=%d\n",
                   context.context_menu_opened,
                   context.context_menu_survived,
                   context.profile_menu_opened,
                   context.profile_menu_survived,
                   context.profile_menu_current,
                   context.profile_menu_selected,
                   context.profile_exact_target,
                   context.profile_readable,
                   context.profile_isolated,
                   context.profile_high_contrast,
                   context.profile_rendered,
                   context.profile_mono_no_ligatures);
    }
    if (!host_ok) {
        g_printerr("native_grid_host_failure smoke=%d contexts=%d clipboard=%d notification=%d settings=%d theme=%d project=%d shortcut=%d control=%d control_registered=%d layer_shell=%d control_status=%d control_show=%d control_hide=%d control_toggle=%d focus=%d move=%d compact=%d tab_rename=%d tab_add=%d add_visible=%d add_start=%d add_icon=%d add_accessible=%d add_clicked=%d add_after_close=%d add_reopened=%d add_fresh=%d add_cleanup=%d tab_close=%d tab_menu_opened=%d tab_menu_survived=%d tab_background=%d tab_applied=%d tab_session_stopped=%d tab_remaining_focused=%d pane_close=%d pane_menu_opened=%d pane_menu_survived=%d pane_target_primary=%d pane_applied=%d pane_session_stopped=%d pane_rendered=%d pane_remaining_focused=%d pane_last_protected=%d split_even=%d split_2x2=%d split_resize_equal=%d pane_even=%d pane_resize=%d layout_preset=%d layout_menu=%d layout_2x2=%d layout_3x3=%d layout_1x1=%d layout_created=%d layout_closed=%d layout_focused=%d final_pages=%d final_tabs_visible=%d resize_overlay=%d window_tray=%d resize_handles=%d resize_affordance=%d native_decorated=%d resize_geometry=%d tray_registered=%d tray_menu_registered=%d tray_watcher=%d tray_icon=%d tray_activations=%d tray_secondary=%d tray_context=%d tray_menu_layout=%d tray_close=%d tray_close_session_stopped=%d\n",
                   workspace_smoke, contexts_ok, clipboard_ok, notification_ok,
                   settings_ok, theme_ok, project_ok, shortcut_ok, control_ok,
                   control_was_registered, layer_shell_was_active,
                   context.control_status_seen, context.control_show_seen,
                   context.control_hide_seen, context.control_toggle_seen,
                   focus_ok, move_ok, compact_ok, tab_rename_ok, tab_add_ok,
                   context.new_tab_button_visible,
                   context.new_tab_button_at_start,
                   context.new_tab_button_icon,
                   context.new_tab_button_accessible,
                   context.new_tab_button_clicked,
                   context.new_tab_button_visible_after_close,
                   context.new_tab_button_reopened_after_close,
                   context.new_tab_button_fresh_context,
                   context.new_tab_button_cleanup,
                   tab_close_ok,
                   context.tab_context_menu_opened,
                   context.tab_context_menu_survived,
                   context.tab_close_targeted_background,
                   context.tab_close_applied,
                   context.tab_close_session_stopped,
                   context.tab_close_remaining_focused,
                   pane_close_ok,
                   context.pane_close_menu_opened,
                   context.pane_close_menu_survived,
                   context.pane_close_targeted_primary,
                   context.pane_close_applied,
                   context.pane_close_session_stopped,
                   context.pane_close_rendered_collapsed,
                   context.pane_close_remaining_focused,
                   context.pane_close_last_terminal_protected,
                   context.pane_split_evenly_distributed,
                   context.pane_split_two_by_two,
                   context.pane_split_resize_equal,
                   context.pane_close_evenly_distributed,
                   context.pane_close_user_resize_preserved,
                   layout_preset_ok,
                   context.layout_preset_menu_survived,
                   context.layout_preset_2x2_rendered,
                   context.layout_preset_3x3_rendered,
                   context.layout_preset_1x1_rendered,
                   context.layout_preset_created_count,
                   context.layout_preset_closed_count,
                   context.layout_preset_remaining_focused,
                   final_page_count, final_tabs_visible,
                   resize_overlay_ok, window_tray_ok,
                   context.window_resize_handle_count,
                   context.window_resize_affordance_ready,
                   context.window_native_decorated,
                   context.window_resize_geometry_changed,
                   tray_was_registered, tray_menu_was_registered,
                   tray_watcher_was_registered,
                   tray_icon_was_available, context.tray_activation_count,
                   context.tray_secondary_seen, context.tray_context_seen,
                   context.tray_menu_layout_seen, context.tray_close_seen,
                   context.tray_close_session_stopped);
    }
    return host_ok ? 0 : -2;
#endif
}
