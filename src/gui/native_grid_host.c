/*
 * Native Linux GTK/Cairo host for the production terminal grid.
 *
 * Zig owns terminal, workspace, configuration, and persistence state. This
 * file owns GTK object lifetimes, Pango glyph caches, GLib main-loop sources,
 * and the C side of native_grid_abi.h. Zig owns extracted Cairo primitives and
 * model policy. Keep decisions behind those ABIs so GTK
 * object lifetimes and terminal-session lifetimes remain independently
 * testable. NOCTTY_ENABLE_SMOKE adds qualification orchestration; it must not
 * alter production behavior.
 */
#include <gtk/gtk.h>
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

#include "../../include/noctty/native_gtk.h"
#include "../../include/noctty/native_grid_abi.h"
#include "../../include/noctty/native_grid_logic.h"
#include "../../include/noctty/native_grid_render.h"

#ifndef NOCTTY_ENABLE_SMOKE
#define NOCTTY_ENABLE_SMOKE 0
#endif
#if NOCTTY_ENABLE_SMOKE
#include "../../tests/native_grid_smoke_constants.inc"
#endif
#define NOCTTY_DROPDOWN_MIN_WIDTH_PX 480
#define NOCTTY_DROPDOWN_MIN_HEIGHT_PX 240
#define NOCTTY_WINDOW_RESIZE_BORDER_PX 2
#define NOCTTY_PANE_INFO_HEIGHT_PX 18
#define NOCTTY_TERMINAL_SCROLLBAR_WIDTH_PX 12
#define NOCTTY_TERMINAL_SCROLLBAR_MIN_THUMB_PX 24
#define NOCTTY_SELECTION_COPY_MAX_BYTES (4u * 1024u * 1024u)
#define NOCTTY_IDLE_HISTORY_BACKGROUND_US (30 * G_USEC_PER_SEC)
#define NOCTTY_IDLE_HISTORY_FOCUSED_US (300 * G_USEC_PER_SEC)
#define NOCTTY_IDLE_HISTORY_STEPS_PER_TICK 16
#define NOCTTY_WRITE_FLUSH_MS 4
#define NOCTTY_EVENT_IDLE_HISTORY_COMPACTED 112
#define NOCTTY_EVENT_STATUS_NOTIFICATION 113
#define NOCTTY_EVENT_STATUS_ACKNOWLEDGED 114
#define NOCTTY_TEXT_ACTION_PERSISTENCE_FAILED (-2)

#define NOCTTY_UI_COLOR_WORKSPACE_BACKGROUND 0u
#define NOCTTY_UI_COLOR_PANE_BORDER_ACTIVE 1u
#define NOCTTY_UI_COLOR_PANE_BORDER_SELECTED 2u
#define NOCTTY_UI_COLOR_PANE_BORDER_INACTIVE 3u
#define NOCTTY_UI_COLOR_SCROLLBAR_TRACK 4u
#define NOCTTY_UI_COLOR_SCROLLBAR_THUMB 5u
#define NOCTTY_UI_COLOR_SCROLLBAR_THUMB_HOVER 6u
#define NOCTTY_UI_COLOR_OVERLAY_BACKGROUND 7u
#define NOCTTY_UI_COLOR_OVERLAY_BORDER 8u
#define NOCTTY_UI_COLOR_OVERLAY_FOREGROUND 9u
#define NOCTTY_UI_COLOR_SELECTION_BACKGROUND 10u
#define NOCTTY_UI_COLOR_SEARCH_MATCH_BACKGROUND 11u
#define NOCTTY_UI_COLOR_STATUS_INFO 12u
#define NOCTTY_UI_COLOR_STATUS_SUCCESS 13u
#define NOCTTY_UI_COLOR_STATUS_WARNING 14u
#define NOCTTY_UI_COLOR_STATUS_ERROR 15u
#define NOCTTY_UI_COLOR_TERMINAL_CURSOR 16u
#define NOCTTY_UI_COLOR_PANE_GAP 17u


typedef enum {
    NOCTTY_FOCUS_SMOKE_PRIMARY_ACTION = 0,
    NOCTTY_FOCUS_SMOKE_PRIMARY_CHECK = 1,
    NOCTTY_FOCUS_SMOKE_SECONDARY_ACTION = 2,
    NOCTTY_FOCUS_SMOKE_SECONDARY_CHECK = 3,
    NOCTTY_FOCUS_SMOKE_ZOOM = 4,
    NOCTTY_FOCUS_SMOKE_RELEASE = 5,
} NocttyFocusSmokeStage;
extern void *noctty_grid_create_session(void *, uint64_t, int, int, int, uint64_t *);
extern int noctty_grid_tab_position(void *);
extern int noctty_grid_tab_title(void *, uint64_t, char *, size_t);
extern uint32_t noctty_grid_tab_color(void *, uint64_t, int *, int *);
extern int noctty_grid_set_tab_color(void *, uint64_t, int);
extern int noctty_grid_adjust_tab_color(void *, uint64_t, int);
extern int noctty_grid_rename_tab(void *, uint64_t, const char *, size_t);
extern int noctty_grid_reorder_tab(void *, uint64_t, int);
extern int noctty_grid_tab_index_for_pane(void *, uint64_t);
extern int noctty_grid_close_tab(void *, uint64_t);
extern int noctty_grid_close_pane(void *, uint64_t, uint64_t *, int *);
extern int noctty_grid_close_session(void *, void *);
extern int noctty_grid_close_transport(void *);
extern int noctty_grid_has_foreground_process(void *);
extern int noctty_grid_process_name(void *, uint8_t *, size_t);
extern int noctty_grid_apply_preset(void *, uint64_t, int, uint64_t *, size_t);
extern int noctty_grid_current_directory(void *, void *, uint64_t, char *, size_t);
extern int noctty_grid_pane_info(void *, void *, uint64_t, char *, size_t,
                                 char *, size_t);
extern int noctty_grid_compact_setting(void *, int);
extern int noctty_grid_theme_count(void *);
extern int noctty_grid_theme_name(void *, int, char *, size_t);
extern int noctty_grid_active_theme_name(void *, char *, size_t);
extern int noctty_grid_pane_theme_name(void *, uint64_t, char *, size_t);
extern int noctty_grid_set_tab_theme(void *, uint64_t, const char *, size_t);
extern uint32_t noctty_grid_pane_terminal_color_rgb(void *, uint64_t, uint32_t);
extern uint32_t noctty_grid_pane_background_rgb(void *, uint64_t);
extern uint32_t noctty_grid_pane_cursor_rgb(void *, uint64_t);
extern uint32_t noctty_grid_pane_gap_rgb(void *, uint64_t);
extern int noctty_grid_launch_profile(void *, int, char *, size_t);
extern int noctty_grid_launch_profile_library(void *, int, int, char *, size_t);
extern int noctty_grid_find(void *, const char *, size_t, int, size_t,
                            int *, int *, int *, int *);
extern int noctty_grid_scrollback(void *, char *, size_t);
extern int noctty_grid_scroll_state(void *, uint64_t *, uint64_t *, uint32_t *);
extern uint64_t noctty_grid_bell_serial(void *);
extern uint64_t noctty_grid_notification_serial(void *);
extern int noctty_grid_notification_action(void *);
extern int noctty_grid_set_agent_resume(void *, uint64_t, int, const char *, size_t, const char *, size_t);
extern int noctty_grid_clear_agent_resume(void *, uint64_t);
extern int noctty_grid_save_encrypted_history(void *, void *, const char *, size_t, const char *, size_t);
extern int noctty_grid_pty_fd(void *);
extern int noctty_grid_compact_idle_history(void *);
extern int noctty_grid_control(void *, const char *, size_t);
extern int noctty_grid_write_pending(void *);
extern int noctty_grid_flush_write(void *);
extern int noctty_grid_workspace_dirty(void *);
extern int noctty_grid_pane_selected(void *, uint64_t);
extern int noctty_grid_pane_profile(void *, uint64_t, char *, size_t,
                                    int *, int *, int *);
extern int noctty_grid_pane_tags(void *, uint64_t, char *, size_t);
extern int noctty_grid_known_tags(void *, char *, size_t);
extern int noctty_grid_pane_matches_smart_filter(void *, uint64_t);
extern int noctty_grid_tag_selected_panes(void *, const char *, size_t);
extern int noctty_grid_remove_tag_from_selected_panes(void *, const char *, size_t);
extern int noctty_grid_set_smart_filter(void *, const char *, size_t);
extern int noctty_grid_broadcast_enabled(void *);
extern int noctty_grid_hot_session_loaded(void *);
extern int noctty_grid_recent_workspace(void *, int, char *, size_t);
extern int noctty_grid_restore_tab_count(void *);
extern int noctty_grid_restore_active_tab(void *);
extern int noctty_grid_restore_tab_index_for_pane(void *, uint64_t);
extern int noctty_grid_restore_tab_info(void *, int, int *, uint64_t *, int *, int *);
extern int noctty_grid_restore_pane_id(void *, int, int, uint64_t *);
extern int noctty_grid_restore_layout_node(void *, int, int, int *, uint64_t *, int *, int *, int *, int *);
extern int noctty_grid_set_layout_ratio(void *, int, int, int);
extern int noctty_grid_flush_hot_session(void *);
extern int noctty_grid_smart_filter_tag(void *, char *, size_t);
extern int noctty_grid_share_peer(void *, int, char *, size_t, char *, size_t,
                                  uint16_t *, int *);
extern int noctty_grid_share_discovered(void *, char *, size_t, char *, size_t,
                                        uint16_t *);
extern int noctty_grid_share_action(void *, int, int, const char *, size_t,
                                    const char *, size_t, uint16_t);
extern int noctty_grid_share_status(void *, uint32_t *, uint16_t *);
extern int noctty_grid_share_view_dimensions(void *, uint16_t *, uint16_t *);
extern uint64_t noctty_grid_share_view_cell(void *, int, int);
extern int noctty_grid_share_view_cell_text(void *, int, int, uint8_t *, size_t);
extern uint32_t noctty_grid_share_view_color(void *, uint32_t);
extern uint32_t noctty_grid_share_view_cursor(void *);
extern int noctty_grid_share_view_cursor_mode(void *);
extern int noctty_grid_share_view_bracketed_paste(void *);
extern int noctty_grid_share_view_title(void *, uint8_t *, size_t);
extern int noctty_grid_share_view_tab(void *, int, uint8_t *, size_t,
                                      uint64_t *, int *, int *);
extern int noctty_grid_share_view_select_tab(void *, int);
extern int noctty_grid_share_view_stream(void *, int, uint8_t *, size_t,
                                         uint64_t *, uint64_t *, int *);
extern uint64_t noctty_grid_share_view_revision(void *);
extern int noctty_grid_share_view_select(void *, int);
extern int noctty_grid_share_view_scroll(void *, int);
extern int noctty_grid_share_view_input(void *, const uint8_t *, size_t);
extern int noctty_grid_share_view_pane_layout(
    void *, int, uint32_t *, uint32_t *, uint32_t *, uint32_t *, int *, int *);
extern int noctty_grid_share_view_pane_dimensions(void *, int, uint16_t *,
                                                   uint16_t *);
extern uint64_t noctty_grid_share_view_pane_cell(void *, int, int, int);
extern int noctty_grid_share_view_pane_cell_text(
    void *, int, int, int, uint8_t *, size_t);
extern uint32_t noctty_grid_share_view_pane_color(void *, int, uint32_t);
extern uint32_t noctty_grid_share_view_pane_cursor(void *, int);
extern int noctty_qt_shortcut_from_gdk(guint keyval, guint state);

typedef struct NocttyGridContextTag {
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
    struct NocttyGridContextTag *root;
    void *userdata;
    NocttyGridPump pump;
    NocttyGridWrite write;
    NocttyGridCell cell;
    NocttyGridRow row;
    NocttyGridDirtyRows dirty_rows;
    NocttyGridDirtySpans dirty_spans;
    NocttyGridPresentationReady presentation_ready;
    NocttyGridColorRgb color_rgb;
    NocttyGridUiColorRgb ui_color_rgb;
    NocttyGridCellText cell_text;
    NocttyGridCellHyperlink cell_hyperlink;
    NocttyGridPollExit poll_exit;
    NocttyGridResize resize;
    NocttyGridMouse mouse;
    NocttyGridPaste paste;
    NocttyGridCopy copy;
    NocttyGridScroll scroll;
    NocttyGridCursor cursor;
    NocttyGridTitle title;
    NocttyGridCursorMode cursor_mode;
    NocttyGridMouseMode mouse_mode;
    NocttyGridFocus focus;
    NocttyGridEvent event;
    NocttyGridTextAction text_action;
    NocttyGridCreateSession create_session;
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
    NocttyGridCloseCoordinator application_close;
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
    int theme_import_dialog_built;
    int system_noctalia_theme_listed;
    int system_noctalia_theme_applied;
    int project_smoke_done;
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
    NocttyFocusSmokeStage focus_click_smoke_stage;
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
    guint resize_commit_source;
    int pending_resize_columns;
    int pending_resize_rows;
    int pending_resize_width;
    int pending_resize_height;
    uint64_t *row_cells;
    size_t row_cell_capacity;
    uint8_t *dirty_row_buffer;
    size_t dirty_row_capacity;
    NocttyGridDirtySpan *dirty_span_buffer;
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
    guint row_batches_drawn;
    guint glyph_batches_drawn;
    guint glyph_cells_batched;
    guint glyph_cache_hits;
    guint glyph_fallback_conversions;
    guint row_buffer_allocations;
    guint glyph_scratch_allocations;
    guint glyph_cache_builds;
    guint grapheme_cells_drawn;
    guint rich_style_cells_drawn;
    guint frame_presentations;
    guint timeout_presentations;
#if NOCTTY_ENABLE_SMOKE
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
    struct NocttyGridContextTag *peer;
} NocttyGridContext;

static NocttyGridContext *root_grid_context(NocttyGridContext *context);
static gchar *current_tab_title_alloc(NocttyGridContext *context);
static void update_compact_tab(NocttyGridContext *context);
static void open_grid_settings(NocttyGridContext *context);
static void open_theme_library(NocttyGridContext *context);
static void queue_theme_redraw(NocttyGridContext *context);
static void on_open_theme_library_clicked(GtkButton *button,
                                          gpointer user_data);
static void open_grid_shortcut_recorder(NocttyGridContext *context);
static gboolean open_grid_shortcut_recorder_live_smoke(gpointer user_data);
static void emit_grid_tray_tooltip(NocttyGridContext *context);
static void emit_grid_tray_menu_layout(NocttyGridContext *context);
static void set_widget_accessible_name(GtkWidget *widget, const char *name);
static void set_status_label_feedback(GtkWidget *label, const char *message,
                                      gboolean is_error);
static gboolean request_grid_application_close(
    NocttyGridContext *context, NocttyApplicationCloseOrigin origin);
static gboolean confirm_grid_application_close(NocttyGridContext *context);
static void begin_grid_modal(NocttyGridContext *context);
static void end_grid_modal(NocttyGridContext *context);
static gint run_grid_modal_dialog(NocttyGridContext *context,
                                  GtkDialog *dialog);
static gboolean configure_overlay_window_stacking(
    NocttyGridContext *context, GtkWidget *dialog,
    const char *namespace_name);
static void present_configured_window(GtkWidget *window) {
    if (!GTK_IS_WINDOW(window) ||
        g_object_get_data(G_OBJECT(window),
                          "noctty-overlay-window") != NULL)
        return;
    gtk_window_present(GTK_WINDOW(window));
}

static void update_window_resize_handles(NocttyGridContext *context);
static gboolean on_window_resize_handle_button(
    GtkWidget *widget, GdkEventButton *event, gpointer user_data);
static gboolean on_window_resize_handle_release(
    GtkWidget *widget, GdkEventButton *event, gpointer user_data);
static void queue_grid_cursor_cell(NocttyGridContext *context,
                                   uint32_t packed_cursor);
static void apply_panel_layout_metrics(NocttyGridContext *root);
static void resize_grid_to_allocation(NocttyGridContext *context,
                                      GtkAllocation *allocation);
static void emit_dogfood_event(NocttyGridContext *context,
                               const char *event_name,
                               uint64_t pane_id,
                               int value,
                               const char *detail);
static guint dogfood_active_omp_count(NocttyGridContext *context);
static void show_resize_overlay(NocttyGridContext *context,
                                int columns, int rows);
static void show_status_feedback(NocttyGridContext *context,
                                 const char *message);
static void schedule_grid_hot_session_flush(NocttyGridContext *context);
static void bind_preset_max_positions(NocttyGridContext *root,
                                      GtkWidget *widget);
static void schedule_even_pane_distribution(NocttyGridContext *context,
                                            GtkWidget *layout);
static gboolean on_scroll(GtkWidget *widget, GdkEventScroll *event,
                          gpointer user_data);
static gboolean on_key_press(GtkWidget *widget, GdkEventKey *event,
                             gpointer user_data);
static gboolean on_key_release(GtkWidget *widget, GdkEventKey *event,
                               gpointer user_data);
static void toggle_grid_window(NocttyGridContext *context);
static void set_grid_layer_keyboard_active(NocttyGridContext *context,
                                           gboolean active);
static gboolean adapt_window_to_resolution(gpointer user_data);
static void schedule_resolution_adapt(NocttyGridContext *context);
static void apply_fullscreen_dimensions(NocttyGridContext *context);
static gboolean normalize_dropdown_pixel_dimensions(
    NocttyGridContext *context, gboolean notify);
static void on_broadcast_menu_activate(GtkWidget *item, gpointer user_data);
#if NOCTTY_ENABLE_SMOKE
static void record_presentation_draw_smoke(NocttyGridContext *context);
#endif
static gboolean show_quick_note_overlays(NocttyGridContext *context);
static void hide_quick_note_overlays(NocttyGridContext *context);
static gboolean adjust_active_tab_color(NocttyGridContext *context,
                                        int delta);
static gboolean on_tab_rename_key(GtkWidget *widget, GdkEventKey *event,
                                  gpointer user_data);
static gboolean on_mouse_button(GtkWidget *widget, GdkEventButton *event,
                                gpointer user_data);
static NocttyGridContext *focused_grid_context(NocttyGridContext *fallback);
static void activate_grid_context(NocttyGridContext *context);
static int deliver_grid_input(NocttyGridContext *source, const char *bytes,
                              size_t length);
static int deliver_grid_paste(NocttyGridContext *source, const char *bytes,
                              size_t length);
static void schedule_grid_write_flush(NocttyGridContext *context);
static void finish_tab_rename(NocttyGridContext *context,
                              gboolean restore_terminal_focus);
static void apply_preset_paned_positions(GtkWidget *widget,
                                         gint width, gint height);
static gboolean bind_grid_layout_for_page(NocttyGridContext *context);
static gboolean sync_grid_context_profile(NocttyGridContext *context);
static void restore_zoomed_page(NocttyGridContext *root);
static void destroy_retired_grid_context(NocttyGridContext *root,
                                         NocttyGridContext *context);
static void dismiss_workspace_menu(NocttyGridContext *context);
static void dismiss_grid_popup_windows(NocttyGridContext *context);
static void refresh_active_pane_info(NocttyGridContext *context);
static gboolean open_smoke_workspace_menu(NocttyGridContext *context);
static GtkWidget *grid_page_content_root(NocttyGridContext *context,
                                         GtkWidget *page);

static gboolean grid_context_session_available(
    const NocttyGridContext *context) {
    return context != NULL && context->active && !context->retiring &&
        context->userdata != NULL;
}

static gboolean grid_context_is_registered(
    const NocttyGridContext *root, const NocttyGridContext *candidate) {
    if (root == NULL || candidate == NULL || root->contexts == NULL)
        return FALSE;
    for (guint index = 0; index < root->contexts->len; index++) {
        if (g_ptr_array_index(root->contexts, index) == candidate)
            return TRUE;
    }
    return FALSE;
}

static NocttyGridFontMetrics grid_font_metrics(
    const NocttyGridContext *context) {
    NocttyGridFontMetrics metrics;
    noctty_grid_font_metrics(
        context != NULL ? context->font_size : 0, &metrics);
    return metrics;
}

typedef struct {
    GtkWidgetAccessible parent;
    gchar *text;
} NocttyTerminalAccessible;

typedef struct {
    GtkWidgetAccessibleClass parent_class;
} NocttyTerminalAccessibleClass;

static void noctty_terminal_accessible_text_iface_init(
    AtkTextIface *interface);

G_DEFINE_TYPE_WITH_CODE(
    NocttyTerminalAccessible, noctty_terminal_accessible,
    GTK_TYPE_WIDGET_ACCESSIBLE,
    G_IMPLEMENT_INTERFACE(
        ATK_TYPE_TEXT, noctty_terminal_accessible_text_iface_init))

static const gchar *noctty_terminal_accessible_contents(AtkText *text) {
    NocttyTerminalAccessible *accessible =
        (NocttyTerminalAccessible *)text;
    return accessible->text != NULL ? accessible->text : "";
}

static gchar *noctty_terminal_accessible_get_text(
    AtkText *text, gint start_offset, gint end_offset) {
    const gchar *contents = noctty_terminal_accessible_contents(text);
    gint count = (gint)g_utf8_strlen(contents, -1);
    gint start = CLAMP(start_offset, 0, count);
    gint end = end_offset < 0 ? count : CLAMP(end_offset, start, count);
    const gchar *start_pointer = g_utf8_offset_to_pointer(contents, start);
    const gchar *end_pointer = g_utf8_offset_to_pointer(contents, end);
    return g_strndup(start_pointer, (gsize)(end_pointer - start_pointer));
}

static gunichar noctty_terminal_accessible_get_character(
    AtkText *text, gint offset) {
    const gchar *contents = noctty_terminal_accessible_contents(text);
    gint count = (gint)g_utf8_strlen(contents, -1);
    if (offset < 0 || offset >= count) return 0;
    return g_utf8_get_char(g_utf8_offset_to_pointer(contents, offset));
}

static gint noctty_terminal_accessible_get_character_count(AtkText *text) {
    return (gint)g_utf8_strlen(
        noctty_terminal_accessible_contents(text), -1);
}

static gint noctty_terminal_accessible_get_caret_offset(AtkText *text) {
    return noctty_terminal_accessible_get_character_count(text);
}

static gchar *noctty_terminal_accessible_get_string_at_offset(
    AtkText *text, gint offset, AtkTextGranularity granularity,
    gint *start_offset, gint *end_offset) {
    const gchar *contents = noctty_terminal_accessible_contents(text);
    gint count = (gint)g_utf8_strlen(contents, -1);
    if (count == 0 || offset < 0 || offset >= count) {
        if (start_offset != NULL) *start_offset = 0;
        if (end_offset != NULL) *end_offset = 0;
        return g_strdup("");
    }

    const gchar *start = g_utf8_offset_to_pointer(contents, offset);
    const gchar *end = g_utf8_next_char(start);
    if (granularity == ATK_TEXT_GRANULARITY_WORD) {
        while (start > contents) {
            const gchar *previous = g_utf8_prev_char(start);
            if (g_unichar_isspace(g_utf8_get_char(previous))) break;
            start = previous;
        }
        while (*end != '\0' &&
               !g_unichar_isspace(g_utf8_get_char(end)))
            end = g_utf8_next_char(end);
    } else if (granularity == ATK_TEXT_GRANULARITY_LINE ||
               granularity == ATK_TEXT_GRANULARITY_PARAGRAPH ||
               granularity == ATK_TEXT_GRANULARITY_SENTENCE) {
        while (start > contents) {
            const gchar *previous = g_utf8_prev_char(start);
            if (*previous == '\n') break;
            start = previous;
        }
        while (*end != '\0' && *end != '\n')
            end = g_utf8_next_char(end);
    }

    if (start_offset != NULL)
        *start_offset = (gint)g_utf8_pointer_to_offset(contents, start);
    if (end_offset != NULL)
        *end_offset = (gint)g_utf8_pointer_to_offset(contents, end);
    return g_strndup(start, (gsize)(end - start));
}

static void noctty_terminal_accessible_finalize(GObject *object) {
    NocttyTerminalAccessible *accessible =
        (NocttyTerminalAccessible *)object;
    g_clear_pointer(&accessible->text, g_free);
    G_OBJECT_CLASS(noctty_terminal_accessible_parent_class)->finalize(object);
}

static void noctty_terminal_accessible_initialize(
    AtkObject *object, gpointer data) {
    ATK_OBJECT_CLASS(noctty_terminal_accessible_parent_class)
        ->initialize(object, data);
    atk_object_set_role(object, ATK_ROLE_TERMINAL);
}

static void noctty_terminal_accessible_class_init(
    NocttyTerminalAccessibleClass *class) {
    GObjectClass *object_class = G_OBJECT_CLASS(class);
    AtkObjectClass *atk_class = ATK_OBJECT_CLASS(class);
    object_class->finalize = noctty_terminal_accessible_finalize;
    atk_class->initialize = noctty_terminal_accessible_initialize;
}

static void noctty_terminal_accessible_init(
    NocttyTerminalAccessible *accessible) {
    accessible->text = g_strdup("");
}

static void noctty_terminal_accessible_text_iface_init(
    AtkTextIface *interface) {
    interface->get_text = noctty_terminal_accessible_get_text;
    interface->get_character_at_offset =
        noctty_terminal_accessible_get_character;
    interface->get_character_count =
        noctty_terminal_accessible_get_character_count;
    interface->get_caret_offset =
        noctty_terminal_accessible_get_caret_offset;
    interface->get_string_at_offset =
        noctty_terminal_accessible_get_string_at_offset;
}

typedef struct {
    GtkDrawingArea parent;
} NocttyTerminalArea;

typedef struct {
    GtkDrawingAreaClass parent_class;
} NocttyTerminalAreaClass;

G_DEFINE_TYPE(
    NocttyTerminalArea, noctty_terminal_area, GTK_TYPE_DRAWING_AREA)

static void noctty_terminal_area_class_init(
    NocttyTerminalAreaClass *class) {
    gtk_widget_class_set_accessible_type(
        GTK_WIDGET_CLASS(class), noctty_terminal_accessible_get_type());
}

static void noctty_terminal_area_init(NocttyTerminalArea *area) {
    (void)area;
}

static GtkWidget *noctty_terminal_area_new(void) {
    GtkWidget *area = GTK_WIDGET(
        g_object_new(noctty_terminal_area_get_type(), NULL));
    gtk_widget_set_app_paintable(area, TRUE);
    return area;
}

static void refresh_terminal_accessible_text(NocttyGridContext *context) {
    if (context == NULL || context->area == NULL ||
        context->cell_text == NULL ||
        !grid_context_session_available(context))
        return;
    AtkObject *object = gtk_widget_get_accessible(context->area);
    if (!ATK_IS_TEXT(object) ||
        !G_TYPE_CHECK_INSTANCE_TYPE(
            object, noctty_terminal_accessible_get_type()))
        return;

    GString *next = g_string_sized_new(
        (gsize)MAX(context->columns * context->rows, 64));
    for (int row = 0; row < context->rows; row++) {
        gsize row_start = next->len;
        for (int column = 0; column < context->columns; column++) {
            char cell[64] = {0};
            int length = context->cell_text(
                context->userdata, column, row, cell, sizeof(cell));
            if (length > 0 && length < (int)sizeof(cell))
                g_string_append_len(next, cell, length);
        }
        while (next->len > row_start &&
               next->str[next->len - 1] == ' ')
            g_string_truncate(next, next->len - 1);
        if (row + 1 < context->rows) g_string_append_c(next, '\n');
    }
    while (next->len > 0 && next->str[next->len - 1] == '\n')
        g_string_truncate(next, next->len - 1);

    NocttyTerminalAccessible *accessible =
        (NocttyTerminalAccessible *)object;
    if (g_strcmp0(accessible->text, next->str) != 0) {
        gint old_count = accessible->text != NULL
            ? (gint)g_utf8_strlen(accessible->text, -1) : 0;
        gint new_count = (gint)g_utf8_strlen(next->str, -1);
        if (old_count > 0)
            g_signal_emit_by_name(
                accessible, "text-changed::delete", 0, old_count);
        g_free(accessible->text);
        accessible->text = g_string_free(next, FALSE);
        if (new_count > 0)
            g_signal_emit_by_name(
                accessible, "text-changed::insert", 0, new_count);
    } else {
        g_string_free(next, TRUE);
    }
#if NOCTTY_ENABLE_SMOKE
    if (noctty_terminal_accessible_get_character_count(
            ATK_TEXT(accessible)) > 0)
        root_grid_context(context)->compact_terminal_accessible_text = 1;
#endif
}

static gboolean terminal_scrollbar_geometry(
    NocttyGridContext *context, GtkAllocation allocation,
    NocttyTerminalScrollbarGeometry *geometry) {
    if (!grid_context_session_available(context) || context->scroll == NULL ||
        geometry == NULL ||
        allocation.width <= NOCTTY_TERMINAL_SCROLLBAR_WIDTH_PX ||
        allocation.height <= 4)
        return FALSE;

    uint64_t history_lines = 0;
    uint64_t viewport_offset = 0;
    uint32_t visible_rows = 0;
    if (noctty_grid_scroll_state(
            context->userdata, &history_lines, &viewport_offset,
            &visible_rows) != 0)
        return FALSE;

    return noctty_grid_scrollbar_geometry(
        allocation.width, allocation.height,
        NOCTTY_TERMINAL_SCROLLBAR_WIDTH_PX,
        NOCTTY_TERMINAL_SCROLLBAR_MIN_THUMB_PX, history_lines,
        viewport_offset, visible_rows, geometry) != 0;
}

static gboolean scroll_terminal_by_lines(
    NocttyGridContext *context, int lines) {
    if (lines == 0) return TRUE;
    int result = context->scroll(context->userdata, lines);
    if (result != 0) {
        show_status_feedback(context, "Could not scroll the terminal history.");
        return FALSE;
    }
    return TRUE;
}

static gboolean scroll_terminal_to_offset(
    NocttyGridContext *context, uint64_t target_offset) {
    GtkAllocation allocation;
    gtk_widget_get_allocation(context->area, &allocation);
    NocttyTerminalScrollbarGeometry geometry;
    if (!terminal_scrollbar_geometry(context, allocation, &geometry))
        return FALSE;

    int lines = noctty_grid_scroll_target_delta(
        geometry.history_lines, geometry.viewport_offset, target_offset);
    if (lines == 0) return FALSE;
    if (!scroll_terminal_by_lines(context, lines)) return FALSE;
    gtk_widget_queue_draw(context->area);
    return TRUE;
}
static gboolean scroll_terminal_from_keyboard(
    NocttyGridContext *context, guint keyval) {
    GtkAllocation allocation;
    gtk_widget_get_allocation(context->area, &allocation);
    NocttyTerminalScrollbarGeometry geometry;
    if (!terminal_scrollbar_geometry(context, allocation, &geometry))
        return TRUE;

    int action = keyval == GDK_KEY_Page_Up
        ? 1
        : keyval == GDK_KEY_Page_Down
            ? 2
            : keyval == GDK_KEY_Home ? 3 : keyval == GDK_KEY_End ? 4 : 0;
    uint64_t target = noctty_grid_keyboard_scroll_target(
        geometry.history_lines, geometry.viewport_offset,
        geometry.visible_rows, action);
    (void)scroll_terminal_to_offset(context, target);
    return TRUE;
}

static int grid_cell_is_selected(const NocttyGridContext *context,
                                      int column, int row) {
    return noctty_grid_cell_selected(
        context->selecting, context->selection_start_column,
        context->selection_start_row, context->selection_end_column,
        context->selection_end_row, column, row) != 0;
}

static void draw_terminal_text_pango(NocttyGridContext *context, cairo_t *cr,
                                     const char *text, int length,
                                     double x, double baseline,
                                     uint32_t style) {
    if (text == NULL || length <= 0) return;
    NocttyGridFontMetrics metrics = grid_font_metrics(context);
    const NocttyGridTerminalFont font = {
        .descriptions = context->terminal_font_descriptions,
        .family = context->font_family,
        .size_px = metrics.font_px,
    };
    (void)noctty_grid_render_terminal_text(
        cr, &font, text, length, x, baseline, style);
}

static void draw_codepoint(NocttyGridContext *context, cairo_t *cr,
                           uint32_t codepoint, double x, double y,
                           uint32_t style) {
    char text[4] = {0};
    int length = noctty_grid_codepoint_utf8(
        codepoint, (uint8_t *)text, sizeof(text));
    if (length > 0)
        draw_terminal_text_pango(context, cr, text, length, x, y, style);
}

static void draw_grid_cell_text(NocttyGridContext *context, cairo_t *cr,
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

static void clear_ascii_glyph_cache(NocttyGridContext *context) {
    for (int face = 0; face < 4; face++) {
        g_clear_pointer(&context->terminal_font_descriptions[face],
                        pango_font_description_free);
        if (context->ascii_scaled_fonts[face] != NULL)
            cairo_scaled_font_destroy(context->ascii_scaled_fonts[face]);
        context->ascii_scaled_fonts[face] = NULL;
        context->ascii_glyph_cache_valid[face] = 0;
    }
}

static void destroy_grid_glyph_cache(NocttyGridContext *context) {
    clear_ascii_glyph_cache(context);
    g_clear_pointer(&context->glyph_scratch, g_free);
    context->glyph_scratch_capacity = 0;
}

static void draw_codepoint_bridge(
    void *userdata, cairo_t *cr, uint32_t codepoint,
    double x, double y, uint32_t style) {
    draw_codepoint(userdata, cr, codepoint, x, y, style);
}

static uint32_t ui_color_rgb(NocttyGridContext *context, uint32_t color,
                             uint32_t fallback) {
    uint32_t rgb = context->ui_color_rgb != NULL
        ? context->ui_color_rgb(context->event_data, color) : UINT32_MAX;
    return rgb == UINT32_MAX ? fallback : rgb;
}

static void format_ui_color(NocttyGridContext *context, uint32_t color,
                            uint32_t fallback, char output[8]) {
    uint32_t rgb = ui_color_rgb(context, color, fallback);
    g_snprintf(output, 8, "#%06x", rgb & 0xffffffu);
}

static void draw_resize_overlay(NocttyGridContext *context, cairo_t *cr,
                                GtkAllocation allocation) {
    if (!context->resize_overlay_visible) return;
    const NocttyGridResizeOverlay options = {
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
    if (noctty_grid_render_resize_overlay(cr, &options))
        context->resize_overlay_drawn = 1;
}

static void draw_quick_note_overlay(NocttyGridContext *context, cairo_t *cr,
                                    GtkAllocation allocation) {
    NocttyGridContext *root = root_grid_context(context);
    if (!root->note_overlay_visible || root->note_overlay_label == NULL)
        return;
    const NocttyGridTextOverlay options = {
        .palette = { context->event_data, context->ui_color_rgb },
        .text = root->note_overlay_label,
        .font_cache = &root->note_overlay_font,
        .allocation_width = allocation.width,
        .allocation_height = allocation.height,
        .border_width = context->overlay_border_px,
        .high_contrast = context->high_contrast,
    };
    int compact = 0;
    if (noctty_grid_render_quick_note(cr, &options, &compact)) {
        context->note_overlay_drawn = 1;
        context->note_overlay_compact = compact;
    }
}

static gboolean clear_status_feedback(gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    root->status_feedback_source = 0;
    g_clear_pointer(&root->status_feedback_text, g_free);
    NocttyGridContext *focused = focused_grid_context(root);
    if (focused != NULL && focused->area != NULL)
        gtk_widget_queue_draw(focused->area);
    return G_SOURCE_REMOVE;
}

static void show_status_feedback(NocttyGridContext *context,
                                 const char *message) {
    NocttyGridContext *root = root_grid_context(context);
    g_clear_pointer(&root->status_feedback_text, g_free);
    if (root->status_feedback_source != 0) {
        g_source_remove(root->status_feedback_source);
        root->status_feedback_source = 0;
    }
    root->status_feedback_text = g_strdup(message);
    root->status_feedback_source = g_timeout_add(
        4500, clear_status_feedback, root);
    if (context->area != NULL) gtk_widget_queue_draw(context->area);
}

static void draw_status_feedback(NocttyGridContext *context, cairo_t *cr,
                                 GtkAllocation allocation) {
    NocttyGridContext *root = root_grid_context(context);
    if (root->status_feedback_text == NULL ||
        focused_grid_context(root) != context)
        return;
    const NocttyGridTextOverlay options = {
        .palette = { context->event_data, context->ui_color_rgb },
        .text = root->status_feedback_text,
        .font_cache = NULL,
        .allocation_width = allocation.width,
        .allocation_height = allocation.height,
        .border_width = context->overlay_border_px,
        .high_contrast = context->high_contrast,
    };
    if (noctty_grid_render_status_feedback(cr, &options))
        root->status_feedback_drawn = 1;
}

static void draw_cycle_feedback(NocttyGridContext *context, cairo_t *cr,
                                GtkAllocation allocation, const char *label,
                                double red, double green, double blue) {
    const uint32_t accent =
        ((uint32_t)(red * 255.0) << 16) |
        ((uint32_t)(green * 255.0) << 8) |
        (uint32_t)(blue * 255.0);
    const NocttyGridCycleOverlay options = {
        .palette = { context->event_data, context->ui_color_rgb },
        .label = label,
        .allocation_width = allocation.width,
        .allocation_height = allocation.height,
        .pane_border_width = context->pane_border_focused_px,
        .overlay_border_width = context->overlay_border_px,
        .accent_rgb = accent,
    };
    (void)noctty_grid_render_cycle_overlay(cr, &options);
}

static void draw_pane_cycle_feedback(NocttyGridContext *context, cairo_t *cr,
                                     GtkAllocation allocation) {
    if (!context->pane_cycle_feedback_visible ||
        context->pane_cycle_feedback_count <= 0) return;

    char label[64];
    g_snprintf(label, sizeof(label), "Pane %d / %d",
               context->pane_cycle_feedback_index,
               context->pane_cycle_feedback_count);
    draw_cycle_feedback(context, cr, allocation, label, 0.28, 0.68, 1.0);

    root_grid_context(context)->pane_cycle_feedback_drawn = 1;
}

static void draw_tab_cycle_feedback(NocttyGridContext *context, cairo_t *cr,
                                    GtkAllocation allocation) {
    if (!context->tab_cycle_feedback_visible ||
        context->tab_cycle_feedback_count <= 0) return;

    char label[64];
    g_snprintf(label, sizeof(label), "Tab %d / %d",
               context->tab_cycle_feedback_index,
               context->tab_cycle_feedback_count);
    draw_cycle_feedback(context, cr, allocation, label, 0.74, 0.48, 1.0);

    root_grid_context(context)->tab_cycle_feedback_drawn = 1;
}

static void draw_terminal_scrollbar(
    NocttyGridContext *context, cairo_t *cr, GtkAllocation allocation) {
    NocttyTerminalScrollbarGeometry geometry;
    if (!terminal_scrollbar_geometry(context, allocation, &geometry)) return;
    const NocttyGridRenderScrollbar options = {
        .palette = { context->event_data, context->ui_color_rgb },
        .allocation_height = allocation.height,
        .x = geometry.x,
        .width = geometry.width,
        .thumb_y = geometry.thumb_y,
        .thumb_height = geometry.thumb_height,
        .dragging = context->scrollbar_dragging,
        .hovered = context->scrollbar_hovered,
    };
    if (noctty_grid_render_scrollbar(cr, &options))
        root_grid_context(context)->compact_scrollbar_drawn = 1;
}

static uint32_t scale_pane_brightness(NocttyGridContext *context,
                                      uint32_t rgb) {
    NocttyGridContext *root = root_grid_context(context);
    gboolean active = noctty_grid_pane_is_active(
        root->active_pane_id_for_render, context->pane_id, context->focused);
    return noctty_grid_scale_brightness(
        rgb, context->inactive_pane_dim_enabled, active,
        context->inactive_pane_brightness_percent);
}

static uint32_t resolve_pane_terminal_color(void *userdata,
                                            uint32_t color_id) {
    NocttyGridContext *context = userdata;
    uint32_t rgb = context->event_data != NULL
        ? noctty_grid_pane_terminal_color_rgb(
              context->event_data, context->pane_id, color_id)
        : UINT32_MAX;
    if (rgb == UINT32_MAX && context->color_rgb != NULL)
        rgb = context->color_rgb(context->userdata, color_id);
    return rgb == UINT32_MAX ? rgb : scale_pane_brightness(context, rgb);
}

static int grid_cell_selected_bridge(void *userdata, int column, int row) {
    const NocttyGridContext *context = userdata;
    return noctty_grid_cell_selected(
        context->selecting, context->selection_start_column,
        context->selection_start_row, context->selection_end_column,
        context->selection_end_row, column, row) != 0;
}

static void draw_grid_cell_text_bridge(
    void *userdata, cairo_t *cr, int column, int row,
    double x, double y, uint32_t style) {
    draw_grid_cell_text(userdata, cr, column, row, x, y, style);
}

static gboolean draw_grid_contents(NocttyGridContext *context, cairo_t *cr,
                                   GtkAllocation allocation) {
    double background_alpha = context->background_translucency &&
        context->background_alpha_supported
        ? context->background_opacity_percent / 100.0 : 1.0;
    cairo_save(cr);
    cairo_set_operator(cr, CAIRO_OPERATOR_SOURCE);
    uint32_t background_rgb = context->event_data != NULL
        ? noctty_grid_pane_background_rgb(
              context->event_data, context->pane_id)
        : ui_color_rgb(
              context, NOCTTY_UI_COLOR_WORKSPACE_BACKGROUND, 0x0b0d12);
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
    NocttyGridContext *root = root_grid_context(context);
    gboolean pane_selected = context->event_data != NULL &&
        noctty_grid_pane_selected(context->event_data, context->pane_id) != 0;
    NocttyGridFontMetrics metrics = grid_font_metrics(context);
    double cell_width = metrics.cell_width;
    double cell_height = metrics.cell_height;
    uint32_t cursor = context->cursor(context->userdata);
    int cursor_column = cursor != 0xffffffff ? (int)(cursor & 0xffff) : -1;
    int cursor_row = cursor != 0xffffffff ? (int)(cursor >> 16) : -1;
    NocttyTerminalScrollbarGeometry cursor_scrollbar;
    gboolean cursor_at_live_bottom =
        !terminal_scrollbar_geometry(context, allocation, &cursor_scrollbar) ||
        cursor_scrollbar.viewport_offset == 0;
    NocttyGridRenderChrome chrome;
    noctty_grid_render_chrome(
        context->status_kind, context->focused, pane_selected,
        context->pane_border_px, context->pane_border_focused_px,
        context->pane_border_selected_px, context->cursor_visible,
        cursor_at_live_bottom, cursor_column, cursor_row,
        context->columns, context->rows, cell_width, cell_height, &chrome);
    if (pane_selected && context->contexts != NULL &&
        context->contexts->len > 0)
        root->selection_border_drawn = 1;

    const NocttyGridCells options = {
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
        .row_cells = &context->row_cells,
        .row_capacity = &context->row_cell_capacity,
        .row_allocations = &context->row_buffer_allocations,
        .row_batches = &root->row_batches_drawn,
        .glyph_batches = &root->glyph_batches_drawn,
        .glyph_cells = &root->glyph_cells_batched,
        .rich_style_cells = &root->rich_style_cells_drawn,
        .source_context = context->userdata,
        .cell = context->cell,
        .row = context->row,
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
        .cursor_rgb = scale_pane_brightness(
            context,
            context->event_data != NULL
                ? noctty_grid_pane_cursor_rgb(
                      context->event_data, context->pane_id)
                : 0x8fb8ffu),
        .chrome = chrome,
    };
    int render_result = noctty_grid_render_cells(cr, &options);
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
    NocttyGridContext *context = user_data;
    GtkAllocation allocation;
    gtk_widget_get_allocation(widget, &allocation);
    gboolean result = draw_grid_contents(context, cr, allocation);
    refresh_terminal_accessible_text(context);
#if NOCTTY_ENABLE_SMOKE
#include "../../tests/native_grid_smoke_draw_counters.inc"
#endif
    return result;
}

#if NOCTTY_ENABLE_SMOKE
#include "../../tests/native_grid_qualification.inc"
#endif

static void on_clipboard_text(GtkClipboard *clipboard, const gchar *text, gpointer user_data) {
    NocttyGridContext *context = user_data;
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
                context, "Could not paste into every target terminal.");
        }
    }
}

static void request_grid_clipboard_text(NocttyGridContext *context) {
    if (!grid_context_session_available(context)) return;
    context->clipboard_requests++;
    gtk_clipboard_request_text(gtk_clipboard_get(GDK_SELECTION_CLIPBOARD),
                               on_clipboard_text, context);
}
static void copy_grid_selection_to_clipboard(NocttyGridContext *context) {
    if (!grid_context_session_available(context) || context->copy == NULL)
        return;
    gsize capacity = 16u * 1024u;
    gchar *text = NULL;
    int copied_length = -1;
    while (capacity <= NOCTTY_SELECTION_COPY_MAX_BYTES) {
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
        if (capacity == NOCTTY_SELECTION_COPY_MAX_BYTES) break;
        capacity = MIN(capacity * 2, NOCTTY_SELECTION_COPY_MAX_BYTES);
    }
    if (copied_length > 0 && (gsize)copied_length < capacity) {
        text[copied_length] = '\0';
        gtk_clipboard_set_text(
            gtk_clipboard_get(GDK_SELECTION_CLIPBOARD), text, copied_length);
    } else if (copied_length < 0 ||
               (gsize)copied_length >= NOCTTY_SELECTION_COPY_MAX_BYTES) {
        show_status_feedback(context, "Could not copy the terminal selection.");
    }
    g_free(text);
}

static void apply_terminal_control(NocttyGridContext *context,
                                   const char *bytes, size_t length) {
    if (!grid_context_session_available(context)) return;
    if (noctty_grid_control(context->userdata, bytes, length) != (int)length) {
        show_status_feedback(context, "Could not update the terminal state.");
        return;
    }
    gtk_widget_queue_draw(context->area);
}

static void clear_grid_screen(NocttyGridContext *context) {
    if (context->write == NULL ||
        context->write(context->userdata, "\x0c", 1) != 1) {
        show_status_feedback(context, "Could not send Ctrl+L to the terminal.");
        return;
    }
    schedule_grid_write_flush(context);
}

static void clear_grid_scrollback(NocttyGridContext *context) {
    apply_terminal_control(context, "\x1b[3J", 4);
}

static void reset_grid_terminal(NocttyGridContext *context) {
    apply_terminal_control(context,
                           "\x1b[3J\x1b[2J\x1b[H\x1b" "c", 13);
}
static gboolean verify_clipboard_copy_smoke(gpointer user_data) {
    NocttyGridContext *context = user_data;
    if (!grid_context_session_available(context) || context->copy == NULL)
        return G_SOURCE_REMOVE;
    char text[16384];
    int copied_length = context->copy(
        context->userdata, text, sizeof(text) - 1, -1, -1, -1, -1);
    if (copied_length <= 1 || (size_t)copied_length >= sizeof(text))
        return G_SOURCE_REMOVE;
    text[copied_length] = '\0';
    context->clipboard_copy_valid =
        strstr(text, "NOCTTY_COPY_") != NULL &&
        strstr(text, "_END") != NULL &&
        memchr(text, '\0', (size_t)copied_length - 1) == NULL;
    return G_SOURCE_REMOVE;
}

static gboolean read_clipboard_smoke(gpointer user_data) {
    NocttyGridContext *context = user_data;
    request_grid_clipboard_text(context);
    g_timeout_add(400, verify_clipboard_copy_smoke, context);
    return G_SOURCE_REMOVE;
}
static gboolean request_clipboard_smoke(gpointer user_data) {
    NocttyGridContext *context = user_data;
    GtkClipboard *clipboard = gtk_clipboard_get(GDK_SELECTION_CLIPBOARD);
    const gchar *command =
        "printf 'NOCTTY_CLIPBOARD_OK NOCTTY_COPY_\xF0\x9F\x98\x80_END'; "
        "sleep 1; exit 0\n";
    gtk_clipboard_set_text(clipboard, command, -1);
    g_timeout_add(200, read_clipboard_smoke, context);
    return G_SOURCE_REMOVE;
}

static void emit_grid_workspace_event(NocttyGridContext *context, int event_code);
static gboolean close_grid_tab(NocttyGridContext *context, GtkWidget *page);
static NocttyGridContext *root_grid_context(NocttyGridContext *context);
static NocttyGridContext *grid_context_for_page(NocttyGridContext *context,
                                                GtkWidget *page);
static void apply_smart_filter(NocttyGridContext *context);
static int populate_tag_suggestions(NocttyGridContext *context,
                                    GtkComboBoxText *combo);

static void sync_grid_page_branch_visibility(
    NocttyGridContext *root, GtkWidget *page) {
    GtkWidget *panes[16] = {0};
    guint pane_count = 0;
    NocttyGridContext *representative = NULL;
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len && pane_count < G_N_ELEMENTS(panes);
         index++) {
        NocttyGridContext *candidate = g_ptr_array_index(
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
        (void)noctty_grid_sync_split_visibility(
            content, panes, pane_count);
}

static gboolean clear_smart_filter(NocttyGridContext *context) {
    NocttyGridContext *root = root_grid_context(context);
    if (root->event_data == NULL || noctty_grid_set_smart_filter(root->event_data, "", 0) != 0)
        return FALSE;
    g_clear_pointer(&root->smart_filter_tag, g_free);
    apply_smart_filter(root);
    if (root->area != NULL) gtk_widget_grab_focus(root->area);
    return TRUE;
}

static void on_smart_filter_empty_clear_clicked(GtkButton *button, gpointer user_data) {
    (void)button;
    (void)clear_smart_filter(user_data);
}

static void apply_smart_filter(NocttyGridContext *context) {
    NocttyGridContext *root = root_grid_context(context);
    GtkWidget *page = root->notebook != NULL
        ? gtk_notebook_get_nth_page(GTK_NOTEBOOK(root->notebook),
                                    gtk_notebook_get_current_page(GTK_NOTEBOOK(root->notebook)))
        : NULL;
    NocttyGridContext *first_visible = NULL;
    gboolean focused_visible = FALSE;
    for (guint index = 0; root->contexts != NULL && index < root->contexts->len; index++) {
        NocttyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (!candidate->active || candidate->page != page || candidate->area == NULL) continue;
        gboolean visible = root->smart_filter_tag == NULL ||
            noctty_grid_pane_matches_smart_filter(root->event_data, candidate->pane_id) != 0;
        gtk_widget_set_visible(candidate->area, visible);
        if (visible && first_visible == NULL) first_visible = candidate;
        if (visible && candidate->focused) focused_visible = TRUE;
    }
    if (page != NULL) sync_grid_page_branch_visibility(root, page);
    if (root->smart_filter_tag != NULL && !focused_visible && first_visible != NULL) {
        gtk_widget_grab_focus(first_visible->area);
    }
    if (root->smart_filter_empty_box != NULL &&
        gtk_widget_get_parent(root->smart_filter_empty_box) != page) {
        gtk_widget_destroy(root->smart_filter_empty_box);
        root->smart_filter_empty_box = NULL;
        root->smart_filter_empty_label = NULL;
        root->smart_filter_empty_clear_button = NULL;
    }
    if (root->smart_filter_tag != NULL && first_visible == NULL && page != NULL) {
        if (root->smart_filter_empty_box == NULL) {
            root->smart_filter_empty_box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 8);
            gtk_widget_set_margin_top(root->smart_filter_empty_box, 16);
            gtk_widget_set_margin_bottom(root->smart_filter_empty_box, 16);
            gtk_widget_set_halign(root->smart_filter_empty_box, GTK_ALIGN_CENTER);
            gchar *empty_text = g_strdup_printf("No panes match Smart Tab tag: %s",
                                                root->smart_filter_tag);
            root->smart_filter_empty_label = gtk_label_new(empty_text);
            gtk_widget_set_tooltip_text(root->smart_filter_empty_label,
                                        "The current Smart Tab tag matches no visible panes");
            g_free(empty_text);
            gtk_widget_set_opacity(root->smart_filter_empty_label, 0.72);
            gtk_box_pack_start(GTK_BOX(root->smart_filter_empty_box),
                               root->smart_filter_empty_label, FALSE, FALSE, 0);
            root->smart_filter_empty_clear_button = gtk_button_new_with_label("Clear filter");
            configure_action_button(
                root->smart_filter_empty_clear_button,
                "Clear the Smart Tab filter and show all panes");
            g_signal_connect(root->smart_filter_empty_clear_button, "clicked",
                             G_CALLBACK(on_smart_filter_empty_clear_clicked), root);
            gtk_box_pack_start(GTK_BOX(root->smart_filter_empty_box),
                               root->smart_filter_empty_clear_button,
                               FALSE, FALSE, 0);
            gtk_box_pack_start(GTK_BOX(page), root->smart_filter_empty_box,
                               FALSE, FALSE, 0);
        }
        show_all_with_action_affordances(root->smart_filter_empty_box);
    } else if (root->smart_filter_empty_box != NULL) {
        gtk_widget_destroy(root->smart_filter_empty_box);
        root->smart_filter_empty_box = NULL;
        root->smart_filter_empty_label = NULL;
        root->smart_filter_empty_clear_button = NULL;
    }
    if (root->smart_filter_button != NULL) {
        char label[256];
        const char *label_text = "Filter";
        if (root->smart_filter_tag != NULL) {
            g_snprintf(label, sizeof(label), "Tag: %s", root->smart_filter_tag);
            label_text = label;
        }
        gtk_button_set_label(GTK_BUTTON(root->smart_filter_button), label_text);
        configure_action_button(root->smart_filter_button,
                                root->smart_filter_tag == NULL
                                    ? "Smart Tab: show all panes"
                                    : "Smart Tab: clear pane tag filter");
    }
    for (guint index = 0; root->contexts != NULL && index < root->contexts->len; index++) {
        NocttyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (candidate->active && candidate->page != NULL)
            update_compact_tab(candidate);
    }
}

static void focus_notebook_page(NocttyGridContext *context, GtkWidget *page) {
    NocttyGridContext *root = root_grid_context(context);
    NocttyGridContext *target = grid_context_for_page(root, page);
    if (target == NULL) return;
    if (target->event != NULL)
        target->event(target->event_data, target->pane_id, 57, 0,
                      (uint64_t)(g_get_monotonic_time() / 1000));
    if (target->area != NULL) {
        gtk_window_set_focus(GTK_WINDOW(root->window), target->area);
        gtk_widget_grab_focus(target->area);
    }
}

static gboolean cycle_grid_tab(NocttyGridContext *context, int direction) {
    NocttyGridContext *root = root_grid_context(context);
    gint count = gtk_notebook_get_n_pages(GTK_NOTEBOOK(root->notebook));
    if (count < 2) return FALSE;
    gint current = gtk_notebook_get_current_page(GTK_NOTEBOOK(root->notebook));
    gint next = noctty_grid_cycle_target(count, current, TRUE, direction);
    if (next < 0) return FALSE;
    GtkWidget *page = gtk_notebook_get_nth_page(GTK_NOTEBOOK(root->notebook), next);
    if (page == NULL) return FALSE;
    gtk_notebook_set_current_page(GTK_NOTEBOOK(root->notebook), next);
    focus_notebook_page(root, page);
    if (direction > 0) root->tab_cycle_next = 1;
    else root->tab_cycle_previous = 1;
    return TRUE;
}

static gboolean clear_pane_cycle_feedback(gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    root->pane_cycle_feedback_source = 0;
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        NocttyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (!candidate->pane_cycle_feedback_visible) continue;
        candidate->pane_cycle_feedback_visible = 0;
        if (candidate->area != NULL) gtk_widget_queue_draw(candidate->area);
    }
    return G_SOURCE_REMOVE;
}

static void show_pane_cycle_feedback(NocttyGridContext *context,
                                     guint visible_index,
                                     guint visible_count) {
    NocttyGridContext *root = root_grid_context(context);
    if (root->pane_cycle_feedback_source != 0) {
        g_source_remove(root->pane_cycle_feedback_source);
        root->pane_cycle_feedback_source = 0;
    }
    if (root->tab_cycle_feedback_source != 0) {
        g_source_remove(root->tab_cycle_feedback_source);
        root->tab_cycle_feedback_source = 0;
    }
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        NocttyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (candidate->tab_cycle_feedback_visible) {
            candidate->tab_cycle_feedback_visible = 0;
            if (candidate->area != NULL) gtk_widget_queue_draw(candidate->area);
        }
        if (candidate != context && candidate->pane_cycle_feedback_visible) {
            candidate->pane_cycle_feedback_visible = 0;
            if (candidate->area != NULL) gtk_widget_queue_draw(candidate->area);
        }
    }
    context->pane_cycle_feedback_visible = 1;
    context->pane_cycle_feedback_index = (int)visible_index + 1;
    context->pane_cycle_feedback_count = (int)visible_count;
    if (context->area != NULL) gtk_widget_queue_draw(context->area);
    root->pane_cycle_feedback_source = g_timeout_add(
        800, clear_pane_cycle_feedback, root);
}

static gboolean clear_tab_cycle_feedback(gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    root->tab_cycle_feedback_source = 0;
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        NocttyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (!candidate->tab_cycle_feedback_visible) continue;
        candidate->tab_cycle_feedback_visible = 0;
        if (candidate->area != NULL) gtk_widget_queue_draw(candidate->area);
    }
    return G_SOURCE_REMOVE;
}

static void show_tab_cycle_feedback(NocttyGridContext *context,
                                    guint tab_index,
                                    guint tab_count) {
    NocttyGridContext *root = root_grid_context(context);
    if (root->pane_cycle_feedback_source != 0) {
        g_source_remove(root->pane_cycle_feedback_source);
        root->pane_cycle_feedback_source = 0;
    }
    if (root->tab_cycle_feedback_source != 0) {
        g_source_remove(root->tab_cycle_feedback_source);
        root->tab_cycle_feedback_source = 0;
    }
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        NocttyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (candidate->pane_cycle_feedback_visible ||
            (candidate != context && candidate->tab_cycle_feedback_visible)) {
            candidate->pane_cycle_feedback_visible = 0;
            candidate->tab_cycle_feedback_visible = 0;
            if (candidate->area != NULL) gtk_widget_queue_draw(candidate->area);
        }
    }
    context->tab_cycle_feedback_visible = 1;
    context->tab_cycle_feedback_index = (int)tab_index + 1;
    context->tab_cycle_feedback_count = (int)tab_count;
    if (context->area != NULL) gtk_widget_queue_draw(context->area);
    root->tab_cycle_feedback_source = g_timeout_add(
        800, clear_tab_cycle_feedback, root);
}

static void show_active_tab_cycle_feedback(NocttyGridContext *context) {
    NocttyGridContext *root = root_grid_context(context);
    gint count = gtk_notebook_get_n_pages(GTK_NOTEBOOK(root->notebook));
    gint index = gtk_notebook_get_current_page(GTK_NOTEBOOK(root->notebook));
    if (count <= 0 || index < 0) return;
    GtkWidget *page = gtk_notebook_get_nth_page(GTK_NOTEBOOK(root->notebook),
                                                index);
    NocttyGridContext *target = focused_grid_context(root);
    if (target == NULL || target->page != page)
        target = grid_context_for_page(root, page);
    if (target != NULL)
        show_tab_cycle_feedback(target, (guint)index, (guint)count);
}

static gboolean cycle_grid_pane(NocttyGridContext *context, int direction) {
    NocttyGridContext *root = root_grid_context(context);
    gint page_index = gtk_notebook_get_current_page(GTK_NOTEBOOK(root->notebook));
    GtkWidget *page = gtk_notebook_get_nth_page(GTK_NOTEBOOK(root->notebook),
                                                page_index);
    NocttyGridContext *current = focused_grid_context(context);
    guint count = 0;
    guint current_index = 0;
    gboolean current_found = FALSE;
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        NocttyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (!candidate->active || candidate->exited || candidate->page != page ||
            candidate->area == NULL || !gtk_widget_get_visible(candidate->area))
            continue;
        if (candidate == current) {
            current_index = count;
            current_found = TRUE;
        }
        count++;
    }
    if (count == 0) return TRUE;

    if (count > G_MAXINT) return TRUE;
    gint target_index = noctty_grid_cycle_target(
        (gint)count, (gint)current_index, current_found, direction);
    if (target_index < 0) return TRUE;

    NocttyGridContext *target = NULL;
    guint visible_index = 0;
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        NocttyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (!candidate->active || candidate->exited || candidate->page != page ||
            candidate->area == NULL || !gtk_widget_get_visible(candidate->area))
            continue;
        if ((gint)visible_index == target_index) {
            target = candidate;
            break;
        }
        visible_index++;
    }
    if (target == NULL) return TRUE;
    if (target != current) {
        gtk_window_set_focus(GTK_WINDOW(root->window), target->area);
        gtk_widget_grab_focus(target->area);
        if (root->workspace_smoke == 22)
            activate_grid_context(target);
        if (direction > 0) root->pane_cycle_next = 1;
    }
    show_pane_cycle_feedback(target, (guint)target_index, count);
    return TRUE;
}
static NocttyGridContext *grid_context_for_pane(NocttyGridContext *context,
                                                uint64_t pane_id);
static gboolean move_grid_context(NocttyGridContext *source,
                                  NocttyGridContext *target);

static gboolean emit_workspace_smoke_tab(gpointer user_data) {
    NocttyGridContext *context = user_data;
    emit_grid_workspace_event(context, 20);
    return G_SOURCE_REMOVE;
}

static const char *title_overflow_smoke_text = "A deliberately long shell title for native overflow verification";
static const char *dirty_smoke_title = "Dirty native tab";
static void open_command_palette(NocttyGridContext *context);
static void on_palette_search_activate(GtkEntry *entry, gpointer user_data);

static gboolean check_title_fallback_smoke(gpointer user_data) {
    NocttyGridContext *context = focused_grid_context(user_data);
    NocttyGridContext *root = root_grid_context(context);
    gchar *title = current_tab_title_alloc(context);
    const gchar *label = context->tab_label != NULL
        ? gtk_label_get_text(GTK_LABEL(context->tab_label)) : "";
    if (g_strcmp0(title, ".") == 0 || g_strcmp0(title, "tmp") == 0 || g_strcmp0(title, "Tab 1") == 0)
        if (root->event != NULL) root->event(root->event_data, root->pane_id, 82, 1, (uint64_t)(g_get_monotonic_time() / 1000));
    (void)label;
    g_free(title);
    return G_SOURCE_REMOVE;
}

static gboolean emit_title_overflow_smoke(gpointer user_data) {
    NocttyGridContext *context = focused_grid_context(user_data);
    const char *command = "printf '\\033]2;A deliberately long shell title for native overflow verification\\007'\n";
    (void)context->write(context->userdata, command, strlen(command));
    return G_SOURCE_REMOVE;
}

static gboolean check_title_overflow_smoke(gpointer user_data) {
    NocttyGridContext *context = focused_grid_context(user_data);
    NocttyGridContext *root = root_grid_context(context);
    const gchar *label = context->tab_label != NULL
        ? gtk_label_get_text(GTK_LABEL(context->tab_label)) : "";
    gchar *tooltip = context->tab_label != NULL
        ? gtk_widget_get_tooltip_text(context->tab_label) : NULL;
    if (strstr(label, "…") != NULL && root->event != NULL)
        root->event(root->event_data, root->pane_id, 83, 1, (uint64_t)(g_get_monotonic_time() / 1000));
    if (tooltip != NULL && strstr(tooltip, title_overflow_smoke_text) != NULL && root->event != NULL)
        root->event(root->event_data, root->pane_id, 84, 1, (uint64_t)(g_get_monotonic_time() / 1000));
    g_free(tooltip);
    return G_SOURCE_REMOVE;
}

static gboolean check_title_rename_smoke(gpointer user_data) {
    NocttyGridContext *context = focused_grid_context(user_data);
    NocttyGridContext *root = root_grid_context(context);
    const char *renamed = "Renamed native tab";
    if (root->event_data != NULL && noctty_grid_rename_tab(root->event_data,
            context->pane_id, renamed, strlen(renamed)) == 0) {
        update_compact_tab(context);
        const gchar *label = context->tab_label != NULL
            ? gtk_label_get_text(GTK_LABEL(context->tab_label)) : "";
        if (strstr(label, renamed) != NULL && root->event != NULL)
            root->event(root->event_data, root->pane_id, 85, 1, (uint64_t)(g_get_monotonic_time() / 1000));
    }
    return G_SOURCE_REMOVE;
}

static gboolean finish_title_smoke(gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    for (guint index = 0; root->contexts != NULL && index < root->contexts->len; index++) {
        NocttyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (candidate->active && !candidate->exited)
            (void)candidate->write(candidate->userdata, "exit 0\n", 7);
    }
    return G_SOURCE_REMOVE;
}

static gboolean trigger_dirty_smoke(gpointer user_data) {
    NocttyGridContext *context = focused_grid_context(user_data);
    NocttyGridContext *root = root_grid_context(context);
    if (root->event_data != NULL && noctty_grid_rename_tab(root->event_data,
            context->pane_id, dirty_smoke_title, strlen(dirty_smoke_title)) == 0) {
        update_compact_tab(context);
    }
    return G_SOURCE_REMOVE;
}

static gboolean emit_attention_smoke(gpointer user_data) {
    NocttyGridContext *context = focused_grid_context(user_data);
    const char *command =
        "printf '\\033]9;Agent needs input\\033\\\\'\n";
    (void)context->write(context->userdata, command, strlen(command));
    return G_SOURCE_REMOVE;
}

static gboolean check_dirty_smoke(gpointer user_data) {
    NocttyGridContext *context = focused_grid_context(user_data);
    NocttyGridContext *root = root_grid_context(context);
    const gchar *label = context->tab_label != NULL
        ? gtk_label_get_text(GTK_LABEL(context->tab_label)) : "";
    gchar *tooltip = context->tab_label != NULL
        ? gtk_widget_get_tooltip_text(context->tab_label) : NULL;
    if (strstr(label, dirty_smoke_title) != NULL && strstr(label, "◆") != NULL &&
        tooltip != NULL && strstr(tooltip, "unsaved workspace") != NULL &&
        root->event != NULL)
        root->event(root->event_data, root->pane_id, 88, 1,
                    (uint64_t)(g_get_monotonic_time() / 1000));
    g_free(tooltip);
    return G_SOURCE_REMOVE;
}

static gboolean check_attention_smoke(gpointer user_data) {
    NocttyGridContext *context = focused_grid_context(user_data);
    NocttyGridContext *root = root_grid_context(context);
    if (context->status_kind == 4 &&
        noctty_grid_notification_serial(context->userdata) > 0 &&
        root->event != NULL)
        root->event(root->event_data, root->pane_id, 89, 1,
                    (uint64_t)(g_get_monotonic_time() / 1000));
    return G_SOURCE_REMOVE;
}

static gboolean acknowledge_attention_smoke(gpointer user_data) {
    NocttyGridContext *context = focused_grid_context(user_data);
    (void)deliver_grid_input(context, "\n", 1);
    return G_SOURCE_REMOVE;
}

static gboolean save_dirty_smoke(gpointer user_data) {
    NocttyGridContext *context = focused_grid_context(user_data);
    NocttyGridContext *root = root_grid_context(context);
    if (root->event != NULL)
        root->event(root->event_data, root->pane_id, 86, 1,
                    (uint64_t)(g_get_monotonic_time() / 1000));
    update_compact_tab(context);
    return G_SOURCE_REMOVE;
}

static gboolean check_dirty_clear_smoke(gpointer user_data) {
    NocttyGridContext *context = focused_grid_context(user_data);
    NocttyGridContext *root = root_grid_context(context);
    const gchar *label = context->tab_label != NULL
        ? gtk_label_get_text(GTK_LABEL(context->tab_label)) : "";
    gchar *tooltip = context->tab_label != NULL
        ? gtk_widget_get_tooltip_text(context->tab_label) : NULL;
    if (strstr(label, dirty_smoke_title) != NULL && strstr(label, "◆") == NULL &&
        tooltip != NULL && strstr(tooltip, "unsaved workspace") == NULL &&
        root->event != NULL)
        root->event(root->event_data, root->pane_id, 90, 1,
                    (uint64_t)(g_get_monotonic_time() / 1000));
    g_free(tooltip);
    return G_SOURCE_REMOVE;
}

static gboolean announce_reorder_drag_smoke(gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    root->tab_reorder_ready_attempts++;
    if (root->contexts == NULL || root->contexts->len < 3 ||
        !gtk_widget_get_mapped(root->window)) {
        return root->tab_reorder_ready_attempts < 30
            ? G_SOURCE_CONTINUE : G_SOURCE_REMOVE;
    }
    NocttyGridContext *source = g_ptr_array_index(root->contexts, 0);
    NocttyGridContext *target = g_ptr_array_index(root->contexts, 2);
    GtkWidget *source_tab = gtk_notebook_get_tab_label(
        GTK_NOTEBOOK(root->notebook), source->page);
    GtkWidget *target_tab = gtk_notebook_get_tab_label(
        GTK_NOTEBOOK(root->notebook), target->page);
    GtkAllocation source_allocation;
    GtkAllocation target_allocation;
    gint source_x = 0;
    gint source_y = 0;
    gint target_x = 0;
    gint target_y = 0;
    if (source_tab == NULL || target_tab == NULL) return G_SOURCE_REMOVE;
    gtk_widget_get_allocation(source_tab, &source_allocation);
    gtk_widget_get_allocation(target_tab, &target_allocation);
    if (!gtk_widget_translate_coordinates(
            source_tab, root->window,
            MAX(4, source_allocation.width / 3),
            MAX(4, source_allocation.height / 2),
            &source_x, &source_y) ||
        !gtk_widget_translate_coordinates(
            target_tab, root->window,
            MAX(4, target_allocation.width - 3),
            MAX(4, target_allocation.height / 2),
            &target_x, &target_y))
        return G_SOURCE_REMOVE;
    GdkWindow *native_window = gtk_widget_get_window(root->window);
    if (native_window == NULL) return G_SOURCE_CONTINUE;
    gint origin_x = 0;
    gint origin_y = 0;
    gdk_window_get_origin(native_window, &origin_x, &origin_y);
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
    NocttyGridContext *root = root_grid_context(user_data);
    if (root->contexts == NULL || root->contexts->len < 3) return G_SOURCE_REMOVE;
    NocttyGridContext *first = g_ptr_array_index(root->contexts, 0);
    NocttyGridContext *second = g_ptr_array_index(root->contexts, 1);
    NocttyGridContext *third = g_ptr_array_index(root->contexts, 2);
    GtkWidget *page_zero = gtk_notebook_get_nth_page(GTK_NOTEBOOK(root->notebook), 0);
    GtkWidget *page_one = gtk_notebook_get_nth_page(GTK_NOTEBOOK(root->notebook), 1);
    GtkWidget *page_two = gtk_notebook_get_nth_page(GTK_NOTEBOOK(root->notebook), 2);
    GtkWidget *active = gtk_notebook_get_nth_page(
        GTK_NOTEBOOK(root->notebook),
        gtk_notebook_get_current_page(GTK_NOTEBOOK(root->notebook)));
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
        root->event(root->event_data, root->pane_id, 91, 1,
                    (uint64_t)(g_get_monotonic_time() / 1000));
    return G_SOURCE_REMOVE;
}

static gboolean persist_reorder_smoke(gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    if (root->event != NULL)
        root->event(root->event_data, root->pane_id, 92, 1,
                    (uint64_t)(g_get_monotonic_time() / 1000));
    return G_SOURCE_REMOVE;
}

static void activate_palette_rename_smoke(NocttyGridContext *root) {
    open_command_palette(root);
    if (root->palette_search == NULL || root->palette_list == NULL) return;
    gtk_entry_set_text(GTK_ENTRY(root->palette_search), "Rename active tab");
    on_palette_search_activate(GTK_ENTRY(root->palette_search), root);
}

static gboolean palette_rename_smoke(gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    activate_palette_rename_smoke(root);
    if (root->tab_rename_entry == NULL) return G_SOURCE_REMOVE;
    gtk_entry_set_text(GTK_ENTRY(root->tab_rename_entry), "");
    g_signal_emit_by_name(root->tab_rename_entry, "activate");
    gchar *validation_text = root->tab_rename_entry != NULL
        ? gtk_widget_get_tooltip_text(root->tab_rename_entry) : NULL;
    gboolean validation = root->tab_rename_entry != NULL &&
        g_strcmp0(validation_text, "Enter a tab name.") == 0;
    g_free(validation_text);
    if (validation && root->event != NULL)
        root->event(root->event_data, root->pane_id, 93, 1,
                    (uint64_t)(g_get_monotonic_time() / 1000));
    gtk_entry_set_text(GTK_ENTRY(root->tab_rename_entry), "Palette renamed tab");
    g_signal_emit_by_name(root->tab_rename_entry, "activate");
    const gchar *label = root->tab_label != NULL
        ? gtk_label_get_text(GTK_LABEL(root->tab_label)) : "";
    if (root->tab_rename_entry == NULL && strstr(label, "Palette renamed tab") != NULL &&
        root->tab_rename_applied && root->event != NULL)
        root->event(root->event_data, root->pane_id, 94, 1,
                    (uint64_t)(g_get_monotonic_time() / 1000));

    activate_palette_rename_smoke(root);
    if (root->tab_rename_entry != NULL) {
        gtk_entry_set_text(GTK_ENTRY(root->tab_rename_entry), "Cancelled palette rename");
        GdkEventKey escape = {0};
        escape.type = GDK_KEY_PRESS;
        escape.keyval = GDK_KEY_Escape;
        (void)on_tab_rename_key(root->tab_rename_entry, &escape, root);
        label = root->tab_label != NULL
            ? gtk_label_get_text(GTK_LABEL(root->tab_label)) : "";
        if (root->tab_rename_entry == NULL && strstr(label, "Palette renamed tab") != NULL &&
            gtk_widget_has_focus(root->area) && root->event != NULL)
            root->event(root->event_data, root->pane_id, 95, 1,
                        (uint64_t)(g_get_monotonic_time() / 1000));
    }
    return G_SOURCE_REMOVE;
}

static gboolean emit_tab_cycle_next_smoke(gpointer user_data) {
    NocttyGridContext *context = focused_grid_context(user_data);
    NocttyGridContext *root = root_grid_context(context);
    GdkEventKey event = {0};
    event.type = GDK_KEY_PRESS;
    event.keyval = GDK_KEY_Page_Down;
    event.state = GDK_CONTROL_MASK;
    if (on_key_press(context->area, &event, context) && root->tab_cycle_next && root->event != NULL)
        root->event(root->event_data, root->pane_id, 78, 1, (uint64_t)(g_get_monotonic_time() / 1000));
    return G_SOURCE_REMOVE;
}

static gboolean grid_context_owns_window_focus(NocttyGridContext *context) {
    NocttyGridContext *root = root_grid_context(context);
    return context != NULL && context->area != NULL && root->window != NULL &&
        gtk_window_get_focus(GTK_WINDOW(root->window)) == context->area;
}

static gboolean emit_pane_cycle_shortcut_smoke(gpointer user_data) {
    NocttyGridContext *context = focused_grid_context(user_data);
    NocttyGridContext *root = root_grid_context(context);
    GtkWidget *page = context->page;
    uint64_t starting_pane = context->pane_id;
    GdkEventKey event = {0};
    event.type = GDK_KEY_PRESS;
    event.keyval = GDK_KEY_Tab;
    event.state = GDK_CONTROL_MASK;
    gboolean handled = on_key_press(context->area, &event, context);
    NocttyGridContext *focused = focused_grid_context(root);
    if (handled && root->pane_cycle_next && focused != NULL &&
        focused->page == page && focused->pane_id != starting_pane &&
        root->event != NULL)
        root->event(root->event_data, focused->pane_id, 97, 1,
                    (uint64_t)(g_get_monotonic_time() / 1000));
    return G_SOURCE_REMOVE;
}

static gboolean emit_alt_scroll_next_smoke(gpointer user_data) {
    NocttyGridContext *context = focused_grid_context(user_data);
    NocttyGridContext *root = root_grid_context(context);
    root->alt_scroll_start_pane_id = context->pane_id;
    root->alt_scroll_start_page = context->page;
    GdkEventScroll event = {0};
    event.type = GDK_SCROLL;
    event.direction = GDK_SCROLL_DOWN;
    event.state = GDK_MOD1_MASK;
    gboolean handled = on_scroll(context->area, &event, context);
    NocttyGridContext *focused = focused_grid_context(root);
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
        gtk_notebook_get_nth_page(
            GTK_NOTEBOOK(root->notebook),
            gtk_notebook_get_current_page(GTK_NOTEBOOK(root->notebook))) ==
            root->alt_scroll_start_page;
    return G_SOURCE_REMOVE;
}

static gboolean emit_alt_scroll_previous_smoke(gpointer user_data) {
    NocttyGridContext *context = focused_grid_context(user_data);
    NocttyGridContext *root = root_grid_context(context);
    gboolean feedback_drawn = context->pane_cycle_feedback_visible &&
        root->pane_cycle_feedback_drawn;
    GdkEventScroll event = {0};
    event.type = GDK_SCROLL;
    event.direction = GDK_SCROLL_UP;
    event.state = GDK_MOD1_MASK;
    gboolean handled = on_scroll(context->area, &event, context);
    NocttyGridContext *focused = focused_grid_context(root);
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
    NocttyGridContext *context = focused_grid_context(user_data);
    NocttyGridContext *root = root_grid_context(context);
    gint count = gtk_notebook_get_n_pages(GTK_NOTEBOOK(root->notebook));
    gint before = gtk_notebook_get_current_page(GTK_NOTEBOOK(root->notebook));
    root->ctrl_alt_scroll_start_page = context->page;
    GdkEventScroll event = {0};
    event.type = GDK_SCROLL;
    event.direction = GDK_SCROLL_DOWN;
    event.state = GDK_CONTROL_MASK | GDK_MOD1_MASK;
    gboolean handled = on_scroll(context->area, &event, context);
    gint after = gtk_notebook_get_current_page(GTK_NOTEBOOK(root->notebook));
    GtkWidget *page = gtk_notebook_get_nth_page(GTK_NOTEBOOK(root->notebook),
                                                after);
    NocttyGridContext *focused = focused_grid_context(root);
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
    NocttyGridContext *context = focused_grid_context(user_data);
    NocttyGridContext *root = root_grid_context(context);
    gboolean feedback_drawn = context->tab_cycle_feedback_visible &&
        root->tab_cycle_feedback_drawn;
    GdkEventScroll event = {0};
    event.type = GDK_SCROLL;
    event.direction = GDK_SCROLL_UP;
    event.state = GDK_CONTROL_MASK | GDK_MOD1_MASK;
    gboolean handled = on_scroll(context->area, &event, context);
    gint after = gtk_notebook_get_current_page(GTK_NOTEBOOK(root->notebook));
    GtkWidget *page = gtk_notebook_get_nth_page(GTK_NOTEBOOK(root->notebook),
                                                after);
    NocttyGridContext *focused = focused_grid_context(root);
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
        root->event(root->event_data, focused->pane_id, 101, 1,
                    (uint64_t)(g_get_monotonic_time() / 1000));
    return G_SOURCE_REMOVE;
}

static gboolean prepare_smart_tab_cycle_smoke(gpointer user_data) {
    NocttyGridContext *context = focused_grid_context(user_data);
    NocttyGridContext *root = root_grid_context(context);
    if (context == NULL || context->pane_id > 9 || root->event_data == NULL)
        return G_SOURCE_REMOVE;
    if (root->event != NULL)
        root->event(root->event_data, context->pane_id,
                    30 + (int)context->pane_id, 0,
                    (uint64_t)(g_get_monotonic_time() / 1000));
    if (noctty_grid_tag_selected_panes(root->event_data, "navigation", 10) != 0 ||
        noctty_grid_set_smart_filter(root->event_data, "navigation", 10) != 0)
        return G_SOURCE_REMOVE;
    g_clear_pointer(&root->smart_filter_tag, g_free);
    root->smart_filter_tag = g_strdup("navigation");
    apply_smart_filter(root);
    return G_SOURCE_REMOVE;
}

static gboolean emit_alt_scroll_filtered_smoke(gpointer user_data) {
    NocttyGridContext *context = focused_grid_context(user_data);
    NocttyGridContext *root = root_grid_context(context);
    GtkWidget *page = context->page;
    uint64_t pane_id = context->pane_id;
    guint visible_count = 0;
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        NocttyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (candidate->active && !candidate->exited &&
            candidate->page == page && candidate->area != NULL &&
            gtk_widget_get_visible(candidate->area)) visible_count++;
    }
    GdkEventScroll event = {0};
    event.type = GDK_SCROLL;
    event.direction = GDK_SCROLL_DOWN;
    event.state = GDK_MOD1_MASK;
    gboolean handled = on_scroll(context->area, &event, context);
    NocttyGridContext *focused = focused_grid_context(root);
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
        root->event(root->event_data, focused->pane_id, 100, 1,
                    (uint64_t)(g_get_monotonic_time() / 1000));
    return G_SOURCE_REMOVE;
}

static gboolean emit_smart_tab_cycle_shortcut_smoke(gpointer user_data) {
    NocttyGridContext *context = focused_grid_context(user_data);
    NocttyGridContext *root = root_grid_context(context);
    gint before = gtk_notebook_get_current_page(GTK_NOTEBOOK(root->notebook));
    GdkEventKey event = {0};
    event.type = GDK_KEY_PRESS;
    event.keyval = GDK_KEY_ISO_Left_Tab;
    event.state = GDK_CONTROL_MASK | GDK_SHIFT_MASK;
    gboolean handled = on_key_press(context->area, &event, context);
    gint after = gtk_notebook_get_current_page(GTK_NOTEBOOK(root->notebook));
    GtkWidget *page = gtk_notebook_get_nth_page(GTK_NOTEBOOK(root->notebook), after);
    NocttyGridContext *target = grid_context_for_page(root, page);
    const gchar *label = target != NULL && target->tab_label != NULL
        ? gtk_label_get_text(GTK_LABEL(target->tab_label)) : "";
    gboolean smart_filter_visible = root->smart_filter_tag != NULL &&
        g_strcmp0(root->smart_filter_tag, "navigation") == 0 &&
        strstr(label, "navigation") != NULL;
    if (handled && before != after && smart_filter_visible) {
        root->tab_cycle_smart_filter = 1;
        if (root->event != NULL && target != NULL)
            root->event(root->event_data, target->pane_id, 98, 1,
                        (uint64_t)(g_get_monotonic_time() / 1000));
    }
    return G_SOURCE_REMOVE;
}

static gboolean clear_tab_navigation_filter_smoke(gpointer user_data) {
    (void)clear_smart_filter(user_data);
    return G_SOURCE_REMOVE;
}

static gboolean emit_tab_cycle_previous_smoke(gpointer user_data) {
    NocttyGridContext *context = focused_grid_context(user_data);
    NocttyGridContext *root = root_grid_context(context);
    GdkEventKey event = {0};
    event.type = GDK_KEY_PRESS;
    event.keyval = GDK_KEY_Page_Up;
    event.state = GDK_CONTROL_MASK;
    if (on_key_press(context->area, &event, context) && root->tab_cycle_previous && root->event != NULL)
        root->event(root->event_data, root->pane_id, 78, -1, (uint64_t)(g_get_monotonic_time() / 1000));
    return G_SOURCE_REMOVE;
}

static gboolean emit_tab_close_shortcut_smoke(gpointer user_data) {
    NocttyGridContext *context = focused_grid_context(user_data);
    NocttyGridContext *root = root_grid_context(context);
    GdkEventKey event = {0};
    event.type = GDK_KEY_PRESS;
    event.keyval = GDK_KEY_w;
    event.state = GDK_CONTROL_MASK | GDK_SHIFT_MASK;
    if (on_key_press(context->area, &event, context) && root->tab_shortcut_close && root->event != NULL)
        root->event(root->event_data, root->pane_id, 79, 1, (uint64_t)(g_get_monotonic_time() / 1000));
    return G_SOURCE_REMOVE;
}

static gboolean emit_tab_reopen_shortcut_smoke(gpointer user_data) {
    NocttyGridContext *context = focused_grid_context(user_data);
    NocttyGridContext *root = root_grid_context(context);
    GdkEventKey event = {0};
    event.type = GDK_KEY_PRESS;
    event.keyval = GDK_KEY_t;
    event.state = GDK_CONTROL_MASK | GDK_SHIFT_MASK;
    if (on_key_press(context->area, &event, context) && root->tab_shortcut_reopen && root->event != NULL)
        root->event(root->event_data, root->pane_id, 80, 1, (uint64_t)(g_get_monotonic_time() / 1000));
    return G_SOURCE_REMOVE;
}

static gboolean finish_tab_navigation_smoke(gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    NocttyGridContext *focused = focused_grid_context(root);
    if (focused->event != NULL)
        focused->event(focused->event_data, focused->pane_id, 81,
                       grid_context_owns_window_focus(focused) ? 1 : 0,
                       (uint64_t)(g_get_monotonic_time() / 1000));
    for (guint index = 0; root->contexts != NULL && index < root->contexts->len; index++) {
        NocttyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (candidate->active && !candidate->exited)
            (void)candidate->write(candidate->userdata, "exit 0\n", 7);
    }
    return G_SOURCE_REMOVE;
}

static gboolean start_tab_navigation_interactions(gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    gint page_index = gtk_notebook_get_current_page(
        GTK_NOTEBOOK(root->notebook));
    GtkWidget *page = gtk_notebook_get_nth_page(
        GTK_NOTEBOOK(root->notebook), page_index);
    guint visible_drawn = 0;
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        NocttyGridContext *candidate =
            g_ptr_array_index(root->contexts, index);
        if (candidate->active && !candidate->exited &&
            candidate->page == page && candidate->area != NULL &&
            gtk_widget_get_visible(candidate->area) &&
            gtk_widget_get_mapped(candidate->area) && candidate->saw_draw)
            visible_drawn++;
    }
    NocttyGridContext *focus_target = focused_grid_context(root);
    gboolean surfaces_ready =
        gtk_notebook_get_n_pages(GTK_NOTEBOOK(root->notebook)) == 2 &&
        page_index == 1 && visible_drawn == 2 &&
        root->window_presented && gtk_widget_get_mapped(root->window) &&
        focus_target != NULL && focus_target->area != NULL;
    if (surfaces_ready && !grid_context_owns_window_focus(focus_target)) {
        gtk_window_set_focus(GTK_WINDOW(root->window), focus_target->area);
        gtk_widget_grab_focus(focus_target->area);
    }
    if ((!surfaces_ready || !grid_context_owns_window_focus(focus_target)) &&
        root->project_smoke_attempts++ < 200) {
        g_timeout_add(25, start_tab_navigation_interactions, root);
        return G_SOURCE_REMOVE;
    }
    root->project_smoke_attempts = 0;
    if (!surfaces_ready || !grid_context_owns_window_focus(focus_target)) {
        g_printerr("native_grid_navigation_start pages=%d page=%d visible_drawn=%u window_presented=%d window_mapped=%d focus_target=%d widget_focus=%d\n",
                   gtk_notebook_get_n_pages(GTK_NOTEBOOK(root->notebook)),
                   page_index, visible_drawn, root->window_presented,
                   gtk_widget_get_mapped(root->window),
                   focus_target != NULL && focus_target->area != NULL,
                   focus_target != NULL && focus_target->area != NULL &&
                       grid_context_owns_window_focus(focus_target));
        g_timeout_add(50, finish_tab_navigation_smoke, root);
        return G_SOURCE_REMOVE;
    }
    g_timeout_add(50, emit_pane_cycle_shortcut_smoke, root);
    g_timeout_add(200, emit_alt_scroll_next_smoke, root);
    g_timeout_add(350, emit_alt_scroll_previous_smoke, root);
    g_timeout_add(500, emit_ctrl_alt_scroll_next_smoke, root);
    g_timeout_add(700, emit_ctrl_alt_scroll_previous_smoke, root);
    g_timeout_add(900, prepare_smart_tab_cycle_smoke, root);
    g_timeout_add(1050, emit_alt_scroll_filtered_smoke, root);
    g_timeout_add(1200, emit_smart_tab_cycle_shortcut_smoke, root);
    g_timeout_add(1350, clear_tab_navigation_filter_smoke, root);
    g_timeout_add(1500, emit_tab_cycle_next_smoke, root);
    g_timeout_add(1650, emit_tab_cycle_previous_smoke, root);
    g_timeout_add(1800, emit_tab_close_shortcut_smoke, root);
    g_timeout_add(2000, emit_tab_reopen_shortcut_smoke, root);
    g_timeout_add(2450, finish_tab_navigation_smoke, root);
    return G_SOURCE_REMOVE;
}

static NocttyGridContext *active_grid_context(NocttyGridContext *context) {
    NocttyGridContext *root = root_grid_context(context);
    if (root->notebook != NULL) {
        gint page_index = gtk_notebook_get_current_page(GTK_NOTEBOOK(root->notebook));
        GtkWidget *page = gtk_notebook_get_nth_page(GTK_NOTEBOOK(root->notebook),
                                                    page_index);
        for (guint index = 0; root->contexts != NULL &&
             index < root->contexts->len; index++) {
            NocttyGridContext *candidate = g_ptr_array_index(root->contexts, index);
            if (candidate->active && !candidate->exited &&
                candidate->area != NULL && candidate->page == page) return candidate;
        }
    }
    if (context != NULL && context->active && !context->exited &&
        context->area != NULL) return context;
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        NocttyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (candidate->active && !candidate->exited && candidate->area != NULL)
            return candidate;
    }
    return root;
}

static NocttyGridContext *focused_grid_context(NocttyGridContext *fallback) {
    NocttyGridContext *root = root_grid_context(fallback);
    if (root->contexts == NULL) return fallback;
    GtkWidget *focus = root->window != NULL
        ? gtk_window_get_focus(GTK_WINDOW(root->window)) : NULL;
    if (focus != NULL) {
        for (guint index = 0; index < root->contexts->len; index++) {
            NocttyGridContext *candidate =
                g_ptr_array_index(root->contexts, index);
            if (candidate->active && !candidate->exited &&
                candidate->area == focus)
                return candidate;
        }
    }
    for (guint index = 0; index < root->contexts->len; index++) {
        NocttyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (candidate->active && candidate->focused && !candidate->exited) return candidate;
    }
    return active_grid_context(fallback);
}

static gboolean emit_workspace_smoke_split(gpointer user_data) {
    NocttyGridContext *context = user_data;
    emit_grid_workspace_event(focused_grid_context(context), 21);
    return G_SOURCE_REMOVE;
}

static gboolean emit_workspace_smoke_split_left(gpointer user_data) {
    NocttyGridContext *context = user_data;
    emit_grid_workspace_event(focused_grid_context(context), 22);
    return G_SOURCE_REMOVE;
}

static gboolean emit_workspace_smoke_balanced_split(gpointer user_data) {
    NocttyGridContext *root = user_data;
    NocttyGridContext *largest = NULL;
    gint largest_area = -1;
    for (guint index = 0; root->contexts != NULL && index < root->contexts->len; index++) {
        NocttyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (!candidate->active || candidate->exited ||
            gtk_widget_get_parent(candidate->area) == NULL) continue;
        GtkAllocation allocation;
        gtk_widget_get_allocation(candidate->area, &allocation);
        gint area = allocation.width * allocation.height;
        if (area > largest_area) {
            largest = candidate;
            largest_area = area;
        }
    }
    if (largest == NULL) return G_SOURCE_REMOVE;
    GtkAllocation allocation;
    gtk_widget_get_allocation(largest->area, &allocation);
    emit_grid_workspace_event(largest,
                              allocation.width >= allocation.height ? 22 : 21);
    return G_SOURCE_REMOVE;
}

static gboolean check_resize_overlay_initially_hidden(gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    root->resize_overlay_smoke_initial_hidden =
        !root->resize_overlay_visible;
    return G_SOURCE_REMOVE;
}

static gboolean move_resize_overlay_divider(gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    GtkWidget *split = NULL;
    for (guint index = 0; root->contexts != NULL && index < root->contexts->len; index++) {
        NocttyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        GtkWidget *parent = gtk_widget_get_parent(candidate->area);
        if (GTK_IS_PANED(parent)) {
            split = parent;
            break;
        }
    }
    if (split == NULL) return G_SOURCE_REMOVE;
    GtkAllocation allocation;
    gtk_widget_get_allocation(split, &allocation);
    GtkOrientation orientation = gtk_orientable_get_orientation(GTK_ORIENTABLE(split));
    gint extent = orientation == GTK_ORIENTATION_VERTICAL
        ? allocation.height
        : allocation.width;
    root->resize_overlay_smoke_moves++;
    gint numerator = root->resize_overlay_smoke_moves % 2 == 1 ? 1 : 2;
    gtk_paned_set_position(GTK_PANED(split), MAX(24, extent * numerator / 3));
    return G_SOURCE_REMOVE;
}

static gboolean check_resize_overlay_visible(gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    guint active = 0;
    gboolean visible = TRUE;
    gboolean realtime = TRUE;
    for (guint index = 0; root->contexts != NULL && index < root->contexts->len; index++) {
        NocttyGridContext *candidate = g_ptr_array_index(root->contexts, index);
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
    NocttyGridContext *root = root_grid_context(user_data);
    guint active = 0;
    gboolean hidden = TRUE;
    for (guint index = 0; root->contexts != NULL && index < root->contexts->len; index++) {
        NocttyGridContext *candidate = g_ptr_array_index(root->contexts, index);
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
    NocttyGridContext *context = user_data;
    GdkEventKey event = {0};
    event.state = GDK_CONTROL_MASK | GDK_SHIFT_MASK;
    event.keyval = GDK_KEY_B;
    (void)on_key_press(context->area, &event, context);
    return G_SOURCE_REMOVE;
}

static gboolean emit_workspace_smoke_select(gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    if (root->event != NULL) root->event(root->event_data, root->pane_id, 33, 0, (uint64_t)(g_get_monotonic_time() / 1000));
    NocttyGridContext *selected = grid_context_for_pane(root, 3);
    if (selected != NULL) update_compact_tab(selected);
    gchar *tooltip = selected != NULL && selected->tab_label != NULL
        ? gtk_widget_get_tooltip_text(selected->tab_label) : NULL;
    root->selection_indicator_visible = tooltip != NULL &&
        strstr(tooltip, "selection group active") != NULL &&
        strstr(tooltip, "broadcast on") != NULL;
    g_free(tooltip);
    root->broadcast_state_label =
        g_strcmp0(noctty_grid_broadcast_menu_label(
                      root->event_data != NULL &&
                      noctty_grid_broadcast_enabled(root->event_data) != 0),
                  "Disable Broadcast Input") == 0;
    on_broadcast_menu_activate(NULL, root);
    if (root->event != NULL)
        root->event(root->event_data, root->pane_id, 23, 0,
                    (uint64_t)(g_get_monotonic_time() / 1000));
    return G_SOURCE_REMOVE;
}

static gboolean emit_workspace_smoke_focus(gpointer user_data) {
    NocttyGridContext *context = user_data;
    if (context->event != NULL) context->event(context->event_data, context->pane_id, 24, 0, (uint64_t)(g_get_monotonic_time() / 1000));
    return G_SOURCE_REMOVE;
}

static gboolean emit_workspace_smoke_tag_filter(gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    if (root->event_data == NULL) return G_SOURCE_REMOVE;
    if (noctty_grid_tag_selected_panes(root->event_data, "ci", 2) != 0)
        return G_SOURCE_REMOVE;
    GtkWidget *suggestions = gtk_combo_box_text_new_with_entry();
    int suggestion_count = populate_tag_suggestions(root, GTK_COMBO_BOX_TEXT(suggestions));
    GtkTreeModel *suggestion_model = gtk_combo_box_get_model(GTK_COMBO_BOX(suggestions));
    root->tag_suggestions_visible = suggestion_count == 1 &&
        gtk_tree_model_iter_n_children(suggestion_model, NULL) == 1;
    gtk_widget_destroy(suggestions);
    if (noctty_grid_set_smart_filter(root->event_data, "missing", 7) != 0)
        return G_SOURCE_REMOVE;
    g_clear_pointer(&root->smart_filter_tag, g_free);
    root->smart_filter_tag = g_strdup("missing");
    apply_smart_filter(root);
    root->tag_filter_empty_state_visible = root->smart_filter_empty_label != NULL &&
        gtk_widget_get_visible(root->smart_filter_empty_label);
    root->tag_filter_empty_context = root->smart_filter_empty_label != NULL &&
        strstr(gtk_label_get_text(GTK_LABEL(root->smart_filter_empty_label)), "missing") != NULL;
    if (root->smart_filter_empty_clear_button != NULL)
        gtk_button_clicked(GTK_BUTTON(root->smart_filter_empty_clear_button));
    root->tag_filter_empty_clear = root->smart_filter_tag == NULL &&
        root->smart_filter_empty_box == NULL;
    if (noctty_grid_set_smart_filter(root->event_data, "missing", 7) != 0)
        return G_SOURCE_REMOVE;
    g_clear_pointer(&root->smart_filter_tag, g_free);
    root->smart_filter_tag = g_strdup("missing");
    apply_smart_filter(root);
    GdkEventKey escape_event = {0};
    escape_event.keyval = GDK_KEY_Escape;
    root->tag_filter_empty_escape = on_key_press(root->area, &escape_event, root) &&
        root->smart_filter_tag == NULL && root->smart_filter_empty_box == NULL;
    if (noctty_grid_set_smart_filter(root->event_data, "ci", 2) != 0)
        return G_SOURCE_REMOVE;
    g_clear_pointer(&root->smart_filter_tag, g_free);
    root->smart_filter_tag = g_strdup("ci");
    root->tag_filter_applied = 1;
    root->tag_filter_match = noctty_grid_pane_matches_smart_filter(
        root->event_data, 3) != 0;
    root->tag_filter_untagged_hidden = noctty_grid_pane_matches_smart_filter(
        root->event_data, 2) == 0;
    apply_smart_filter(root);
    root->tag_filter_indicator_visible = root->tab_label != NULL &&
        strstr(gtk_label_get_text(GTK_LABEL(root->tab_label)), "ci") != NULL;
    NocttyGridContext *focused = focused_grid_context(root);
    root->tag_filter_focus_restored = focused != NULL && focused->pane_id == 3;
    if (noctty_grid_set_smart_filter(root->event_data, "", 0) == 0) {
        g_clear_pointer(&root->smart_filter_tag, g_free);
        root->tag_filter_cleared = noctty_grid_pane_matches_smart_filter(
            root->event_data, 2) != 0;
        apply_smart_filter(root);
    }
    return G_SOURCE_REMOVE;
}

static gboolean emit_workspace_smoke_move(gpointer user_data) {
    NocttyGridContext *context = user_data;
    NocttyGridContext *source = grid_context_for_pane(context, 3);
    if (source != NULL) emit_grid_workspace_event(source, 56);
    return G_SOURCE_REMOVE;
}

static gboolean finish_workspace_smoke(gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    NocttyGridContext *selected = grid_context_for_pane(root, 3);
    GtkWidget *pending_page = NULL;
    int window_width = 0;
    int window_height = 0;
    gtk_window_get_size(GTK_WINDOW(root->window),
                        &window_width, &window_height);
    root->dropdown_minimum_geometry =
        window_width >= NOCTTY_DROPDOWN_MIN_WIDTH_PX &&
        window_height >= NOCTTY_DROPDOWN_MIN_HEIGHT_PX;
    gboolean visual_ready = root->pane_move_applied &&
        root->selection_border_drawn && selected != NULL;
    for (guint index = 0;
         root->contexts != NULL && index < root->contexts->len; index++) {
        NocttyGridContext *candidate = g_ptr_array_index(
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
            gint page_index = gtk_notebook_page_num(
                GTK_NOTEBOOK(root->notebook), pending_page);
            if (page_index >= 0)
                gtk_notebook_set_current_page(
                    GTK_NOTEBOOK(root->notebook), page_index);
        }
        for (guint index = 0;
             root->contexts != NULL && index < root->contexts->len; index++) {
            NocttyGridContext *candidate = g_ptr_array_index(
                root->contexts, index);
            if (candidate->active && !candidate->exited &&
                candidate->page == pending_page && candidate->area != NULL)
                gtk_widget_queue_draw(candidate->area);
        }
        g_timeout_add(25, finish_workspace_smoke, root);
        return G_SOURCE_REMOVE;
    }
    root->workspace_visual_attempts = 0;
    if (selected != NULL && selected->page != NULL) {
        gint page_index = gtk_notebook_page_num(
            GTK_NOTEBOOK(root->notebook), selected->page);
        if (page_index >= 0)
            gtk_notebook_set_current_page(
                GTK_NOTEBOOK(root->notebook), page_index);
        if (selected->area != NULL) gtk_widget_grab_focus(selected->area);
    }
    for (guint index = 0;
         root->contexts != NULL && index < root->contexts->len; index++) {
        NocttyGridContext *candidate = g_ptr_array_index(
            root->contexts, index);
        if (candidate->active && !candidate->exited)
            (void)candidate->write(candidate->userdata, "\n", 1);
    }
    return G_SOURCE_REMOVE;
}

static gboolean emit_workspace_smoke_move_last_pane(gpointer user_data) {
    NocttyGridContext *context = focused_grid_context(user_data);
    emit_grid_workspace_event(context, 56);
    return G_SOURCE_REMOVE;
}

static gboolean finish_grid_hide(gpointer user_data) {
    NocttyGridContext *root = user_data;
    root->hide_source = 0;
    gtk_widget_hide(root->window);
    return G_SOURCE_REMOVE;
}

static gboolean retain_xdg_activation_token_bytes(
    NocttyGridContext *context, const gchar *token, gsize length) {
    NocttyGridContext *root = root_grid_context(context);
    if (noctty_grid_text_valid((const uint8_t *)token, length, 4096) == 0)
        return FALSE;
    gchar *owned = g_strndup(token, length);
    if (owned == NULL) return FALSE;
    g_free(root->xdg_activation_token);
    root->xdg_activation_token = owned;
    root->xdg_activation_token_received = 1;
    return TRUE;
}

static gboolean retain_xdg_activation_token(NocttyGridContext *context,
                                             const gchar *token) {
    return token != NULL && retain_xdg_activation_token_bytes(
        context, token, strlen(token));
}

static void clear_xdg_activation_token(NocttyGridContext *context) {
    NocttyGridContext *root = root_grid_context(context);
    g_clear_pointer(&root->xdg_activation_token, g_free);
}

static void apply_xdg_activation_token(NocttyGridContext *context) {
    NocttyGridContext *root = root_grid_context(context);
    if (root->xdg_activation_token == NULL ||
        !GTK_IS_WINDOW(root->window)) return;
    gtk_window_set_startup_id(GTK_WINDOW(root->window),
                              root->xdg_activation_token);
    root->xdg_activation_token_applied = 1;
    if (g_getenv("NOCTTY_DEBUG_ACTIVATION") != NULL)
        g_printerr("noctty_xdg_activation applied=true backend=%s\n",
                   GDK_IS_WAYLAND_DISPLAY(gdk_display_get_default())
                       ? "wayland" : "x11");
    clear_xdg_activation_token(root);
}

static void toggle_grid_window(NocttyGridContext *context) {
    NocttyGridContext *root = root_grid_context(context);
    gboolean visible = GTK_IS_WIDGET(root->window) &&
        !gtk_widget_in_destruction(root->window) &&
        gtk_widget_get_visible(root->window);
    if (root->window_presented && visible) {
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
        GtkWidget *grab = gtk_grab_get_current();
        if (grab != NULL && GTK_IS_MENU(grab)) gtk_menu_popdown(GTK_MENU(grab));
        if (root->revealer != NULL && root->dropdown_animation_ms > 0) {
            gtk_revealer_set_reveal_child(GTK_REVEALER(root->revealer), FALSE);
            if (root->hide_source != 0) g_source_remove(root->hide_source);
            root->hide_source = g_timeout_add((guint)root->dropdown_animation_ms,
                                              finish_grid_hide, root);
        } else if (root->layer_shell_active) {
            if (root->hide_source != 0) g_source_remove(root->hide_source);
            // Give keyboard-interactivity NONE one frame to commit before
            // unmapping the layer surface, avoiding a combined KWin focus and
            // surface-destroy transition on the cold path.
            root->hide_source = g_timeout_add(16, finish_grid_hide, root);
        } else gtk_widget_hide(root->window);
    } else {
        set_grid_layer_keyboard_active(root, TRUE);
        root->window_presented = 1;
        apply_xdg_activation_token(root);
        if (root->hide_source != 0) {
            g_source_remove(root->hide_source);
            root->hide_source = 0;
        }
        show_all_with_action_affordances(root->window);
        if (root->revealer != NULL)
            gtk_revealer_set_reveal_child(GTK_REVEALER(root->revealer), TRUE);
        if (!root->layer_shell_active)
            gtk_window_present(GTK_WINDOW(root->window));
        schedule_resolution_adapt(root);
        NocttyGridContext *focus_target = active_grid_context(context);
        if (focus_target->area != NULL)
            gtk_widget_grab_focus(focus_target->area);
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

static const char noctty_control_xml[] =
    "<node>"
    " <interface name='com.noctty.NOCTTY.Control'>"
    "  <method name='Toggle'><arg type='b' name='visible' direction='out'/></method>"
    "  <method name='ToggleWithActivation'><arg type='s' name='token' direction='in'/><arg type='b' name='visible' direction='out'/></method>"
    "  <method name='Show'><arg type='b' name='visible' direction='out'/></method>"
    "  <method name='ShowWithActivation'><arg type='s' name='token' direction='in'/><arg type='b' name='visible' direction='out'/></method>"
    "  <method name='Hide'><arg type='b' name='visible' direction='out'/></method>"
    "  <method name='GetState'><arg type='b' name='visible' direction='out'/></method>"
    " </interface>"
    "</node>";

static gboolean finish_grid_control_smoke(gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
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
    NocttyGridContext *root = root_grid_context(user_data);
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
                                              "Unknown NOCTTY control method");
        return;
    }
    g_dbus_method_invocation_return_value(invocation,
                                          g_variant_new("(b)", visible));
    if (root->workspace_smoke == 16 && root->control_status_count == 2 &&
        root->control_show_seen && root->control_hide_seen &&
        root->control_toggle_seen)
        g_idle_add(finish_grid_control_smoke, root);
}

static const GDBusInterfaceVTable noctty_control_vtable = {
    on_control_method_call,
    NULL,
    NULL,
    {0},
};

static void begin_grid_dbus_operation(NocttyGridContext *context) {
    root_grid_context(context)->dbus_pending_operations++;
}

static void finish_grid_dbus_operation(NocttyGridContext *context) {
    NocttyGridContext *root = root_grid_context(context);
    if (root->dbus_pending_operations > 0) root->dbus_pending_operations--;
}

static void cancel_grid_dbus_operations(NocttyGridContext *context) {
    NocttyGridContext *root = root_grid_context(context);
    if (root->dbus_cancellable != NULL)
        g_cancellable_cancel(root->dbus_cancellable);
    while (root->dbus_pending_operations > 0)
        g_main_context_iteration(NULL, TRUE);
    g_clear_object(&root->dbus_cancellable);
}

static void drain_grid_dbus_operations(NocttyGridContext *context) {
    NocttyGridContext *root = root_grid_context(context);
    gint64 deadline = g_get_monotonic_time() + 2000 * 1000;
    while (root->dbus_pending_operations > 0 &&
           g_get_monotonic_time() < deadline) {
        while (g_main_context_iteration(NULL, FALSE)) {}
        if (root->dbus_pending_operations > 0) g_usleep(1000);
    }
}

static void on_grid_control_name_requested(GObject *source,
                                           GAsyncResult *result,
                                           gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    GError *error = NULL;
    GVariant *reply = g_dbus_connection_call_finish(
        G_DBUS_CONNECTION(source), result, &error);
    if (reply != NULL) {
        guint32 request_result = 0;
        g_variant_get(reply, "(u)", &request_result);
        root->control_registered = request_result == 1u || request_result == 4u;
        root->control_name_conflict = request_result == 2u || request_result == 3u;
        if (g_getenv("NOCTTY_DEBUG_CONTROL_OWNERSHIP") != NULL)
            g_printerr("noctty_control_ownership pid=%ld result=%u owner=%d conflict=%d\n",
                       (long)getpid(), request_result,
                       root->control_registered, root->control_name_conflict);
        g_variant_unref(reply);
    }
    g_clear_error(&error);
    if (root->control_name_conflict && root->show_on_control_conflict) {
        GVariant *forwarded = g_dbus_connection_call_sync(
            root->control_bus, "com.noctty.NOCTTY", "/com/noctty/NOCTTY",
            "com.noctty.NOCTTY.Control", "Show", NULL,
            G_VARIANT_TYPE("(b)"), G_DBUS_CALL_FLAGS_NONE, 1000, NULL, NULL);
        if (forwarded != NULL) {
            root->control_conflict_forwarded = 1;
            g_variant_unref(forwarded);
        }
    }
    if (root->control_registered && root->shortcut_transport == 2 &&
        root->mode == 0 && root->workspace_smoke == 16)
        (void)g_file_set_contents("/tmp/noctty-noctalia-control-ready",
                                  "ready\n", -1, NULL);
    finish_grid_dbus_operation(root);
}

static void on_grid_control_bus_ready(GObject *source, GAsyncResult *result,
                                      gpointer user_data) {
    (void)source;
    NocttyGridContext *root = root_grid_context(user_data);
    GError *error = NULL;
    root->control_bus = g_bus_get_finish(result, &error);
    if (root->control_bus == NULL) goto failed;
    root->control_node = g_dbus_node_info_new_for_xml(noctty_control_xml,
                                                       &error);
    if (root->control_node == NULL) goto failed;
    root->control_object_id = g_dbus_connection_register_object(
        root->control_bus, "/com/noctty/NOCTTY",
        root->control_node->interfaces[0], &noctty_control_vtable, root, NULL,
        &error);
    if (root->control_object_id == 0) goto failed;
    g_dbus_connection_call(
        root->control_bus, "org.freedesktop.DBus", "/org/freedesktop/DBus",
        "org.freedesktop.DBus", "RequestName",
        g_variant_new("(su)", "com.noctty.NOCTTY", 4u),
        G_VARIANT_TYPE("(u)"), G_DBUS_CALL_FLAGS_NONE, 1000,
        root->dbus_cancellable, on_grid_control_name_requested, root);
    return;

failed:
    g_clear_error(&error);
    finish_grid_dbus_operation(root);
}

static void unregister_grid_control(NocttyGridContext *context) {
    NocttyGridContext *root = root_grid_context(context);
    if (root->control_bus == NULL) return;
    if (root->control_object_id != 0) {
        g_dbus_connection_unregister_object(root->control_bus,
                                            root->control_object_id);
        root->control_object_id = 0;
    }
    g_dbus_connection_call(
        root->control_bus, "org.freedesktop.DBus", "/org/freedesktop/DBus",
        "org.freedesktop.DBus", "ReleaseName",
        g_variant_new("(s)", "com.noctty.NOCTTY"), G_VARIANT_TYPE("(u)"),
        G_DBUS_CALL_FLAGS_NONE, 1000, NULL, NULL, NULL);
    g_clear_pointer(&root->control_node, g_dbus_node_info_unref);
    g_clear_object(&root->control_bus);
    root->control_registered = 0;
}

static int register_grid_control(NocttyGridContext *context) {
    NocttyGridContext *root = root_grid_context(context);
    begin_grid_dbus_operation(root);
    g_bus_get(G_BUS_TYPE_SESSION, root->dbus_cancellable,
              on_grid_control_bus_ready, root);
    return 1;
}

static gboolean quit_control_name_conflict(gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    root->window_presented = 0;
    gtk_main_quit();
    return G_SOURCE_REMOVE;
}

static const char noctty_tray_xml[] =
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

static const char noctty_tray_menu_xml[] =
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
    NOCTTY_TRAY_MENU_ROOT = 0,
    NOCTTY_TRAY_MENU_TOGGLE = 1,
    NOCTTY_TRAY_MENU_SETTINGS = 2,
    NOCTTY_TRAY_MENU_SEPARATOR = 3,
    NOCTTY_TRAY_MENU_CLOSE = 4,
};

static GVariant *new_empty_grid_tray_pixmaps(void) {
    GVariantBuilder builder;
    g_variant_builder_init(&builder, G_VARIANT_TYPE("a(iiay)"));
    return g_variant_builder_end(&builder);
}



static GVariant *new_grid_tray_menu_properties(NocttyGridContext *root,
                                                gint32 id) {
    GVariantBuilder properties;
    g_variant_builder_init(&properties, G_VARIANT_TYPE("a{sv}"));
    if (id == NOCTTY_TRAY_MENU_ROOT) {
        g_variant_builder_add(&properties, "{sv}", "children-display",
                              g_variant_new_string("submenu"));
    } else if (id == NOCTTY_TRAY_MENU_SEPARATOR) {
        g_variant_builder_add(&properties, "{sv}", "type",
                              g_variant_new_string("separator"));
    } else {
        g_variant_builder_add(&properties, "{sv}", "label",
                              g_variant_new_string(
                                  noctty_grid_tray_menu_label(id, root->window_presented)));
        g_variant_builder_add(&properties, "{sv}", "icon-name",
                              g_variant_new_string(
                                  noctty_grid_tray_menu_icon_name(id)));
    }
    return g_variant_builder_end(&properties);
}

static GVariant *new_grid_tray_menu_layout(NocttyGridContext *root,
                                            gint32 id,
                                            gint32 recursion_depth) {
    GVariantBuilder children;
    g_variant_builder_init(&children, G_VARIANT_TYPE("av"));
    if (id == NOCTTY_TRAY_MENU_ROOT && recursion_depth != 0) {
        const gint32 child_ids[] = {
            NOCTTY_TRAY_MENU_TOGGLE,
            NOCTTY_TRAY_MENU_SETTINGS,
            NOCTTY_TRAY_MENU_SEPARATOR,
            NOCTTY_TRAY_MENU_CLOSE,
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

static GVariant *new_grid_tray_menu_property(NocttyGridContext *root,
                                              gint32 id,
                                              const char *name) {
    if (!noctty_grid_tray_menu_id_valid(id)) return NULL;
    if (g_strcmp0(name, "label") == 0)
        return g_variant_new_string(noctty_grid_tray_menu_label(id, root->window_presented));
    if (g_strcmp0(name, "icon-name") == 0)
        return g_variant_new_string(noctty_grid_tray_menu_icon_name(id));
    if (g_strcmp0(name, "type") == 0)
        return g_variant_new_string(id == NOCTTY_TRAY_MENU_SEPARATOR
                                        ? "separator"
                                        : "standard");
    if (g_strcmp0(name, "children-display") == 0)
        return g_variant_new_string(id == NOCTTY_TRAY_MENU_ROOT
                                        ? "submenu"
                                        : "");
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
    NocttyGridContext *root = root_grid_context(user_data);
    if (g_strcmp0(method_name, "GetLayout") == 0) {
        gint32 parent_id = 0;
        gint32 recursion_depth = 0;
        GVariant *property_names = NULL;
        g_variant_get(parameters, "(ii@as)", &parent_id, &recursion_depth,
                      &property_names);
        g_variant_unref(property_names);
        if (!noctty_grid_tray_menu_id_valid(parent_id)) {
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
            if (!noctty_grid_tray_menu_id_valid(id)) continue;
            g_variant_builder_add(&properties, "(i@a{sv})", id,
                                  new_grid_tray_menu_properties(root, id));
        }
        g_variant_unref(ids);
        g_variant_unref(property_names);
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
        g_variant_unref(data);
        if (g_strcmp0(event_id, "clicked") == 0) {
            if (id == NOCTTY_TRAY_MENU_TOGGLE) {
                toggle_grid_window(root);
            } else if (id == NOCTTY_TRAY_MENU_SETTINGS) {
                if (!root->window_presented) toggle_grid_window(root);
                open_grid_settings(root);
            } else if (id == NOCTTY_TRAY_MENU_CLOSE) {
                root->tray_close_seen = 1;
                (void)request_grid_application_close(
                    root, NOCTTY_CLOSE_ORIGIN_TRAY);
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

static const GDBusInterfaceVTable noctty_tray_menu_vtable = {
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
    NocttyGridContext *root = root_grid_context(user_data);
    if (g_strcmp0(property_name, "Category") == 0)
        return g_variant_new_string("ApplicationStatus");
    if (g_strcmp0(property_name, "Id") == 0)
        return g_variant_new_string("noctty");
    if (g_strcmp0(property_name, "Title") == 0)
        return g_variant_new_string("NOCTTY");
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
        return g_variant_new_string("com.noctty.NOCTTY");
    if (g_strcmp0(property_name, "IconPixmap") == 0)
        return root->tray_icon_pixmaps != NULL
            ? g_variant_ref(root->tray_icon_pixmaps)
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
            ? g_variant_ref(root->tray_icon_pixmaps)
            : new_empty_grid_tray_pixmaps();
        return g_variant_new(
            "(s@a(iiay)ss)", "com.noctty.NOCTTY", pixmaps, "NOCTTY",
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
    NocttyGridContext *root = root_grid_context(user_data);
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

static const GDBusInterfaceVTable noctty_tray_vtable = {
    on_grid_tray_method_call,
    on_grid_tray_get_property,
    NULL,
    {0},
};

static void on_grid_tray_watcher_registered(GObject *source,
                                             GAsyncResult *result,
                                             gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    GError *error = NULL;
    GVariant *reply = g_dbus_connection_call_finish(
        G_DBUS_CONNECTION(source), result, &error);
    root->tray_watcher_registered = reply != NULL;
    if (reply != NULL) g_variant_unref(reply);
    g_clear_error(&error);
    finish_grid_dbus_operation(root);
}

static int register_grid_tray_watcher(NocttyGridContext *context) {
    NocttyGridContext *root = root_grid_context(context);
    if (root->tray_bus == NULL || root->tray_object_id == 0) return 0;
    begin_grid_dbus_operation(root);
    g_dbus_connection_call(
        root->tray_bus, "org.kde.StatusNotifierWatcher",
        "/StatusNotifierWatcher", "org.kde.StatusNotifierWatcher",
        "RegisterStatusNotifierItem", g_variant_new("(s)",
        "/StatusNotifierItem"), NULL, G_DBUS_CALL_FLAGS_NONE, 1000,
        root->dbus_cancellable, on_grid_tray_watcher_registered, root);
    return 1;
}

static void on_grid_tray_watcher_owner_changed(
    GDBusConnection *connection, const gchar *sender_name,
    const gchar *object_path, const gchar *interface_name,
    const gchar *signal_name, GVariant *parameters, gpointer user_data) {
    (void)connection; (void)sender_name; (void)object_path;
    (void)interface_name; (void)signal_name;
    NocttyGridContext *root = root_grid_context(user_data);
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

static void emit_grid_tray_tooltip(NocttyGridContext *context) {
    NocttyGridContext *root = root_grid_context(context);
    if (root->tray_bus == NULL || root->tray_object_id == 0) return;
    (void)g_dbus_connection_emit_signal(
        root->tray_bus, NULL, "/StatusNotifierItem",
        "org.kde.StatusNotifierItem", "NewToolTip", NULL, NULL);
}

static void emit_grid_tray_menu_layout(NocttyGridContext *context) {
    NocttyGridContext *root = root_grid_context(context);
    if (root->tray_bus == NULL || root->tray_menu_object_id == 0) return;
    root->tray_menu_revision++;
    if (root->tray_menu_revision == 0) root->tray_menu_revision = 1;
    (void)g_dbus_connection_emit_signal(
        root->tray_bus, NULL, "/MenuBar", "com.canonical.dbusmenu",
        "LayoutUpdated", g_variant_new("(ui)", root->tray_menu_revision,
                                         NOCTTY_TRAY_MENU_ROOT), NULL);
}

static void unregister_grid_tray(NocttyGridContext *context) {
    NocttyGridContext *root = root_grid_context(context);
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
    g_clear_pointer(&root->tray_icon_pixmaps, g_variant_unref);
    g_clear_object(&root->tray_bus);
    root->tray_registered = 0;
    root->tray_menu_registered = 0;
    root->tray_watcher_registered = 0;
}

static void on_grid_tray_bus_ready(GObject *source, GAsyncResult *result,
                                   gpointer user_data) {
    (void)source;
    NocttyGridContext *root = root_grid_context(user_data);
    GError *error = NULL;
    root->tray_bus = g_bus_get_finish(result, &error);
    if (root->tray_bus == NULL) goto failed;
    root->tray_node = g_dbus_node_info_new_for_xml(noctty_tray_xml, &error);
    if (root->tray_node == NULL) goto failed;
    root->tray_menu_node = g_dbus_node_info_new_for_xml(
        noctty_tray_menu_xml, &error);
    if (root->tray_menu_node == NULL) goto failed;
    root->tray_icon_available = 1;
    root->tray_menu_revision = 1;
    root->tray_menu_object_id = g_dbus_connection_register_object(
        root->tray_bus, "/MenuBar", root->tray_menu_node->interfaces[0],
        &noctty_tray_menu_vtable, root, NULL, &error);
    if (root->tray_menu_object_id == 0) goto failed;
    root->tray_menu_registered = 1;
    root->tray_object_id = g_dbus_connection_register_object(
        root->tray_bus, "/StatusNotifierItem",
        root->tray_node->interfaces[0], &noctty_tray_vtable, root, NULL,
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
    g_clear_error(&error);
    finish_grid_dbus_operation(root);
}

static int register_grid_tray(NocttyGridContext *context) {
    NocttyGridContext *root = root_grid_context(context);
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
    NocttyGridContext *context = user_data;
    context->shortcut_invoked = 1;
    if (context->workspace_smoke == 9)
        (void)g_file_set_contents("/tmp/noctty-native-grid-shortcut-activated",
                                  "activated\n", -1, NULL);
    toggle_grid_window(context);
    if (context->workspace_smoke == 9)
        g_idle_add(open_grid_shortcut_recorder_live_smoke, context);
}

static gboolean mark_shortcut_smoke_ready(gpointer user_data);

typedef struct {
    NocttyGridContext *root;
    guint generation;
    int requested_key;
    int prior_key;
    int purpose;
} NocttyShortcutRequest;
static const char *grid_shortcut_component_name(
    const NocttyGridContext *root);
static const char *grid_shortcut_action_name(
    const NocttyGridContext *root);
static const char *grid_shortcut_display_name(
    const NocttyGridContext *root);
static const char *grid_shortcut_description(
    const NocttyGridContext *root);
static const char *grid_shortcut_component_path(
    const NocttyGridContext *root);


static void start_grid_shortcut_registration(NocttyGridContext *context,
                                             int requested_key,
                                             int purpose,
                                             int prior_key);

static gboolean grid_shortcut_request_current(
    const NocttyShortcutRequest *request) {
    return request->generation == request->root->shortcut_generation &&
        request->root->dbus_cancellable != NULL &&
        !g_cancellable_is_cancelled(request->root->dbus_cancellable);
}

static void finish_grid_shortcut_request(NocttyShortcutRequest *request,
                                         int status) {
    NocttyGridContext *root = request->root;
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
                    "/tmp/noctty-native-grid-shortcut-recorder-captured",
                    "captured\n", -1, NULL);
            if (root->event != NULL)
                root->event(root->event_data, root->pane_id, 75,
                            request->requested_key,
                            (uint64_t)(g_get_monotonic_time() / 1000));
            if (root->shortcut_recorder_dialog != NULL)
                gtk_widget_destroy(root->shortcut_recorder_dialog);
        } else if (request->purpose == 0) {
            if (root->event != NULL)
                root->event(root->event_data, root->pane_id, 11, 0,
                            (uint64_t)(g_get_monotonic_time() / 1000));
            if (root->workspace_smoke == 9)
                g_idle_add(mark_shortcut_smoke_ready, root);
        }
    } else if (current && request->purpose == 1) {
        if (root->shortcut_recorder_feedback != NULL)
            gtk_label_set_text(GTK_LABEL(root->shortcut_recorder_feedback),
                               "Shortcut is unavailable. Press another key or Esc.");
    } else if (current && request->purpose == 0 && root->event != NULL) {
        root->event(root->event_data, root->pane_id,
                    status == 0 ? 14 : 15, 0,
                    (uint64_t)(g_get_monotonic_time() / 1000));
    }
    finish_grid_dbus_operation(root);
    g_free(request);
}

static const char *grid_shortcut_component_name(
    const NocttyGridContext *root) {
    return noctty_grid_shortcut_field(0, root->workspace_smoke == 9);
}

static const char *grid_shortcut_action_name(
    const NocttyGridContext *root) {
    return noctty_grid_shortcut_field(1, root->workspace_smoke == 9);
}

static const char *grid_shortcut_display_name(
    const NocttyGridContext *root) {
    return noctty_grid_shortcut_field(2, root->workspace_smoke == 9);
}

static const char *grid_shortcut_description(
    const NocttyGridContext *root) {
    return noctty_grid_shortcut_field(3, root->workspace_smoke == 9);
}
static gchar *grid_shortcut_label_alloc(
    const NocttyGridContext *root) {
    uint8_t label[64] = {0};
    uint32_t encoded = root != NULL
        ? (uint32_t)root->requested_shortcut_key : 0;
    int length = noctty_grid_shortcut_label(
        encoded, label, G_N_ELEMENTS(label));
    return length > 0
        ? g_strndup((const gchar *)label, (gsize)length)
        : g_strdup("Unknown");
}

static gchar *grid_settings_shortcut_button_label_alloc(
    const NocttyGridContext *root) {
    gchar *shortcut = grid_shortcut_label_alloc(root);
    gchar *label = g_strdup_printf("%s — Change shortcut…", shortcut);
    g_free(shortcut);
    return label;
}

static void configure_grid_settings_shortcut_button(
    NocttyGridContext *context, GtkWidget *button) {
    NocttyGridContext *root = root_grid_context(context);
    if (!GTK_IS_BUTTON(button)) return;
    gchar *shortcut = grid_shortcut_label_alloc(root);
    gchar *label = g_strdup_printf("%s — Change shortcut…", shortcut);
    gchar *tooltip = g_strdup_printf(
        root->shortcut_transport == 1
            ? "Current shortcut: %s. Select to change the Plasma global shortcut."
            : "Current shortcut: %s. Select to record and update the Noctalia binding plan.",
        shortcut);
    gtk_button_set_label(GTK_BUTTON(button), label);
    gtk_widget_set_tooltip_text(button, tooltip);
    g_free(tooltip);
    g_free(label);
    g_free(shortcut);
}

static void refresh_grid_settings_shortcut_button(
    NocttyGridContext *context) {
    NocttyGridContext *root = root_grid_context(context);
    if (!GTK_IS_WINDOW(root->settings_dialog)) return;
    GtkWidget *button = g_object_get_data(
        G_OBJECT(root->settings_dialog), "noctty-settings-shortcut");
    configure_grid_settings_shortcut_button(root, button);
}


static const char *grid_shortcut_component_path(
    const NocttyGridContext *root) {
    return noctty_grid_shortcut_field(4, root->workspace_smoke == 9);
}

static void on_grid_shortcut_set(GObject *source, GAsyncResult *result,
                                 gpointer user_data) {
    NocttyShortcutRequest *request = user_data;
    GError *error = NULL;
    GVariant *reply = g_dbus_connection_call_finish(
        G_DBUS_CONNECTION(source), result, &error);
    if (!grid_shortcut_request_current(request) || reply == NULL) {
        if (reply != NULL) g_variant_unref(reply);
        g_clear_error(&error);
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
    g_variant_unref(accepted_keys);
    g_variant_unref(reply);
    finish_grid_shortcut_request(request, accepted_requested ? 1 : 0);
}

static void on_grid_shortcut_available(GObject *source, GAsyncResult *result,
                                       gpointer user_data) {
    NocttyShortcutRequest *request = user_data;
    GError *error = NULL;
    GVariant *reply = g_dbus_connection_call_finish(
        G_DBUS_CONNECTION(source), result, &error);
    if (!grid_shortcut_request_current(request) || reply == NULL) {
        if (reply != NULL) g_variant_unref(reply);
        g_clear_error(&error);
        finish_grid_shortcut_request(request, -1);
        return;
    }
    gboolean available = FALSE;
    g_variant_get(reply, "(b)", &available);
    g_variant_unref(reply);
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
        G_VARIANT_TYPE("(ai)"), G_DBUS_CALL_FLAGS_NONE, 1500,
        request->root->dbus_cancellable, on_grid_shortcut_set, request);
}

static void on_grid_shortcut_action_registered(GObject *source,
                                                GAsyncResult *result,
                                                gpointer user_data) {
    NocttyShortcutRequest *request = user_data;
    GError *error = NULL;
    GVariant *reply = g_dbus_connection_call_finish(
        G_DBUS_CONNECTION(source), result, &error);
    if (!grid_shortcut_request_current(request) || reply == NULL) {
        if (reply != NULL) g_variant_unref(reply);
        g_clear_error(&error);
        finish_grid_shortcut_request(request, -1);
        return;
    }
    g_variant_unref(reply);
    request->root->shortcut_action_registered = 1;
    const char *component = grid_shortcut_component_name(request->root);
    g_dbus_connection_call(
        request->root->shortcut_bus, "org.kde.kglobalaccel",
        "/kglobalaccel", "org.kde.KGlobalAccel",
        "isGlobalShortcutAvailable",
        g_variant_new("(is)", request->requested_key, component),
        G_VARIANT_TYPE("(b)"), G_DBUS_CALL_FLAGS_NONE, 1500,
        request->root->dbus_cancellable, on_grid_shortcut_available, request);
}

static void on_grid_shortcut_bus_ready(GObject *source, GAsyncResult *result,
                                       gpointer user_data) {
    (void)source;
    NocttyShortcutRequest *request = user_data;
    GError *error = NULL;
    GDBusConnection *bus = g_bus_get_finish(result, &error);
    if (!grid_shortcut_request_current(request) || bus == NULL) {
        if (bus != NULL) g_object_unref(bus);
        g_clear_error(&error);
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
        1500, request->root->dbus_cancellable,
        on_grid_shortcut_action_registered, request);
}

static void start_grid_shortcut_registration(NocttyGridContext *context,
                                             int requested_key,
                                             int purpose,
                                             int prior_key) {
    NocttyGridContext *root = root_grid_context(context);
    NocttyShortcutRequest *request = g_new0(NocttyShortcutRequest, 1);
    request->root = root;
    request->generation = ++root->shortcut_generation;
    request->requested_key = requested_key;
    request->prior_key = prior_key;
    request->purpose = purpose;
    begin_grid_dbus_operation(root);
    g_bus_get(G_BUS_TYPE_SESSION, root->dbus_cancellable,
              on_grid_shortcut_bus_ready, request);
}

static int register_grid_shortcut(NocttyGridContext *context,
                                  int requested_key) {
    start_grid_shortcut_registration(context, requested_key, 0, 0);
    return 1;
}

static void unregister_grid_shortcut(NocttyGridContext *context) {
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
        G_VARIANT_TYPE("(b)"), G_DBUS_CALL_FLAGS_NONE, 1000,
        NULL, &error);
    if (reply != NULL) g_variant_unref(reply);
    g_clear_error(&error);
    g_object_unref(context->shortcut_bus);
    context->shortcut_bus = NULL;
    context->shortcut_subscription = 0;
    context->shortcut_action_registered = 0;
    context->shortcut_registered = 0;
}

static void on_grid_shortcut_recorder_destroy(GtkWidget *widget,
                                               gpointer user_data) {
    (void)widget;
    NocttyGridContext *root = root_grid_context(user_data);
    gboolean restore = root->shortcut_recorder_restore_on_destroy;
    int prior_key = root->shortcut_recorder_prior_key;
    root->shortcut_recorder_dialog = NULL;
    root->shortcut_recorder_feedback = NULL;
    root->shortcut_recorder_restore_on_destroy = 0;
    refresh_grid_settings_shortcut_button(root);
    if (root->shortcut_recorder_settings_hidden) {
        root->shortcut_recorder_settings_hidden = 0;
        if (GTK_IS_WINDOW(root->settings_dialog)) {
            gtk_widget_show(root->settings_dialog);
            present_configured_window(root->settings_dialog);
            root->shortcut_recorder_settings_restored =
                gtk_widget_get_visible(root->settings_dialog) &&
                gtk_widget_get_mapped(root->settings_dialog);
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
    NocttyGridContext *root = root_grid_context(user_data);
    if (event->keyval == GDK_KEY_Escape) {
        gtk_widget_destroy(root->shortcut_recorder_dialog);
        return TRUE;
    }
    int key = noctty_qt_shortcut_from_gdk(event->keyval, event->state);
    int base = key & 0x01ffffff;
    gboolean function_key = base >= 0x01000030 && base <= 0x0100003b;
    gboolean has_modifier = (key & 0x1e000000) != 0;
    if (key == 0 || (!function_key && !has_modifier)) {
        gtk_label_set_text(GTK_LABEL(root->shortcut_recorder_feedback),
                           "Use F1-F12, or add Ctrl, Alt, or Super. Esc cancels.");
        return TRUE;
    }
    int prior_key = root->requested_shortcut_key;
    if (root->shortcut_transport == 1) {
        unregister_grid_shortcut(root);
        gtk_label_set_text(GTK_LABEL(root->shortcut_recorder_feedback),
                           "Checking shortcut availability…");
        start_grid_shortcut_registration(root, key, 1, prior_key);
        return TRUE;
    }
    root->requested_shortcut_key = key;
    root->shortcut_recorded = 1;
    if (root->event != NULL)
        root->event(root->event_data, root->pane_id, 75, key,
                    (uint64_t)(g_get_monotonic_time() / 1000));
    gtk_widget_destroy(root->shortcut_recorder_dialog);
    return TRUE;
}

static void open_grid_shortcut_recorder(NocttyGridContext *context) {
    NocttyGridContext *root = root_grid_context(context);
    if (root->shortcut_recorder_dialog != NULL) {
        present_configured_window(root->shortcut_recorder_dialog);
        return;
    }
    GtkWidget *dialog = gtk_dialog_new_with_buttons(
        "Global shortcut", GTK_WINDOW(root->window),
        GTK_DIALOG_MODAL | GTK_DIALOG_DESTROY_WITH_PARENT, NULL, NULL);
    (void)configure_overlay_window_stacking(
        root, dialog, "noctty-shortcut-recorder");
    if (GTK_IS_WINDOW(root->settings_dialog) &&
        gtk_widget_get_visible(root->settings_dialog)) {
        gtk_widget_hide(root->settings_dialog);
        root->shortcut_recorder_settings_hidden =
            !gtk_widget_get_visible(root->settings_dialog);
        root->shortcut_recorder_settings_handoff =
            root->shortcut_recorder_settings_hidden;
        root->shortcut_recorder_settings_restored = 0;
    }
    GtkWidget *label = gtk_label_new(
        root->shortcut_transport == 1
            ? "Press the Plasma shortcut to register. Esc cancels."
            : "Press a shortcut. NOCTTY will update the Noctalia compositor binding plan. Esc cancels.");
    gtk_label_set_line_wrap(GTK_LABEL(label), TRUE);
    gtk_widget_set_margin_start(label, 16);
    gtk_widget_set_margin_end(label, 16);
    gtk_widget_set_margin_top(label, 14);
    gtk_widget_set_margin_bottom(label, 14);
    gtk_container_add(GTK_CONTAINER(gtk_dialog_get_content_area(GTK_DIALOG(dialog))), label);
    root->shortcut_recorder_prior_key = root->requested_shortcut_key;
    root->shortcut_recorder_restore_on_destroy =
        root->shortcut_transport == 1;
    if (root->shortcut_transport == 1) unregister_grid_shortcut(root);
    root->shortcut_recorder_dialog = dialog;
    root->shortcut_recorder_feedback = label;
    root->shortcut_recorder_shown = 1;
    g_signal_connect(dialog, "key-press-event",
                     G_CALLBACK(on_grid_shortcut_capture), root);
    g_signal_connect(dialog, "destroy",
                     G_CALLBACK(on_grid_shortcut_recorder_destroy), root);
    show_all_with_action_affordances(dialog);
    present_configured_window(dialog);
}

static gboolean open_grid_shortcut_recorder_live_smoke(gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    open_grid_shortcut_recorder(root);
    if (root->shortcut_recorder_dialog != NULL &&
        !root->shortcut_registered)
        (void)g_file_set_contents(
            "/tmp/noctty-native-grid-shortcut-recorder-ready",
            "ready\n", -1, NULL);
    return G_SOURCE_REMOVE;
}

static gboolean mark_shortcut_smoke_ready(gpointer user_data) {
    (void)user_data;
    (void)g_file_set_contents("/tmp/noctty-native-grid-shortcut-ready",
                              "ready\n", -1, NULL);
    return G_SOURCE_REMOVE;
}

static void on_window_destroy(GtkWidget *widget, gpointer user_data) {
    (void)widget;
    (void)user_data;
    if (gtk_main_level() > 0) gtk_main_quit();
}

static gboolean on_window_delete_event(GtkWidget *widget, GdkEvent *event,
                                       gpointer user_data) {
    (void)widget;
    (void)event;
    NocttyGridContext *root = root_grid_context(user_data);
    (void)request_grid_application_close(
        root, NOCTTY_CLOSE_ORIGIN_WINDOW);
    return TRUE;
}

static gboolean grid_has_visible_transient(NocttyGridContext *root) {
    GList *windows = gtk_window_list_toplevels();
    gboolean found = FALSE;
    for (GList *item = windows; item != NULL; item = item->next) {
        if (!GTK_IS_WINDOW(item->data) || item->data == root->window) continue;
        if (gtk_window_get_transient_for(GTK_WINDOW(item->data)) == GTK_WINDOW(root->window) &&
            gtk_widget_get_visible(GTK_WIDGET(item->data))) {
            found = TRUE;
            break;
        }
    }
    g_list_free(windows);
    return found;
}

static gboolean grid_has_open_menu(NocttyGridContext *root) {
    GtkWidget *grab = gtk_grab_get_current();
    return (grab != NULL && GTK_IS_MENU(grab)) ||
           (root->workspace_menu != NULL &&
            gtk_widget_get_visible(root->workspace_menu));
}

static void queue_quick_note_overlay_draws(NocttyGridContext *root) {
    if (root->contexts == NULL) return;
    for (guint index = 0; index < root->contexts->len; index++) {
        NocttyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (candidate->active && candidate->area != NULL &&
            gtk_widget_get_mapped(candidate->area))
            gtk_widget_queue_draw(candidate->area);
    }
}

static gboolean show_quick_note_overlays(NocttyGridContext *context) {
    NocttyGridContext *root = root_grid_context(context);
    root->note_overlay_alt_pressed = 1;
    if (root->note_overlay_visible) return TRUE;

    g_clear_pointer(&root->note_overlay_text, g_free);
    g_clear_pointer(&root->note_overlay_label, g_free);
    root->note_overlay_content_loaded = 0;
    if (root->text_action == NULL) return FALSE;

    const size_t capacity = 4096;
    char *contents = g_malloc(capacity);
    int length = root->text_action(root->text_action_data, 8, "", 0,
                                   contents, capacity, 1);
    if (length <= 0 || (size_t)length > capacity) {
        g_free(contents);
        return FALSE;
    }
    gchar *valid = g_utf8_make_valid(contents, length);
    g_free(contents);
    g_strstrip(valid);
    if (valid[0] == '\0') {
        g_free(valid);
        return FALSE;
    }
    glong characters = g_utf8_strlen(valid, -1);
    root->note_overlay_text = characters > 512
        ? g_utf8_substring(valid, 0, 512)
        : g_strdup(valid);
    g_free(valid);
    root->note_overlay_label = g_strdup_printf("Note · %s",
                                               root->note_overlay_text);
    root->note_overlay_content_loaded = 1;
    root->note_overlay_visible = 1;
    if (root->contexts != NULL) {
        for (guint index = 0; index < root->contexts->len; index++) {
            NocttyGridContext *candidate =
                g_ptr_array_index(root->contexts, index);
            candidate->note_overlay_drawn = 0;
            candidate->note_overlay_compact = 0;
        }
    }
    queue_quick_note_overlay_draws(root);
    return TRUE;
}

static void hide_quick_note_overlays(NocttyGridContext *context) {
    NocttyGridContext *root = root_grid_context(context);
    if (!root->note_overlay_visible && root->note_overlay_text == NULL &&
        root->note_overlay_label == NULL) return;
    root->note_overlay_visible = 0;
    g_clear_pointer(&root->note_overlay_text, g_free);
    g_clear_pointer(&root->note_overlay_label, g_free);
    queue_quick_note_overlay_draws(root);
}


static gboolean deferred_focus_hide(gpointer user_data) {
    NocttyGridContext *root = user_data;
    root->focus_hide_source = 0;
    if (grid_has_open_menu(root)) {
        if (root->workspace_menu != NULL &&
            gtk_widget_get_mapped(root->workspace_menu) &&
            gtk_widget_get_mapped(root->window))
            root->context_menu_survived = 1;
        root->focus_hide_source = g_timeout_add(120, deferred_focus_hide, root);
        return G_SOURCE_REMOVE;
    }
    if (root->mode == 0 && root->hide_on_focus_loss &&
        root->window_presented &&
        gtk_widget_get_visible(root->window) &&
        !gtk_window_is_active(GTK_WINDOW(root->window)) &&
        !grid_has_visible_transient(root)) toggle_grid_window(root);
    return G_SOURCE_REMOVE;
}

static gboolean on_window_focus_out(GtkWidget *widget, GdkEventFocus *event,
                                    gpointer user_data) {
    (void)widget;
    (void)event;
    NocttyGridContext *root = user_data;
    hide_quick_note_overlays(root);
    if (root->focus_hide_source != 0) g_source_remove(root->focus_hide_source);
    root->focus_hide_source = g_timeout_add(120, deferred_focus_hide, root);
    return FALSE;
}

static void update_status_tooltip(NocttyGridContext *context, const gchar *status) {
    char tag_buffer[256] = {0};
    int tag_length = context->event_data != NULL
        ? noctty_grid_pane_tags(context->event_data, context->pane_id,
                                tag_buffer, sizeof(tag_buffer) - 1)
        : 0;
    char text[384];
    if (tag_length > 0) {
        g_snprintf(text, sizeof(text), "Pane %" G_GUINT64_FORMAT " · %s · %s",
                   context->pane_id, status, tag_buffer);
    } else {
        g_snprintf(text, sizeof(text), "Pane %" G_GUINT64_FORMAT " · %s",
                   context->pane_id, status);
    }
    const gchar *cached = g_object_get_data(
        G_OBJECT(context->area), "noctty-pane-tooltip-cache");
    if (g_strcmp0(cached, text) != 0) {
        gtk_widget_set_tooltip_text(context->area, text);
        AtkObject *accessible = gtk_widget_get_accessible(context->area);
        if (accessible != NULL) atk_object_set_description(accessible, text);
        g_object_set_data_full(G_OBJECT(context->area),
                               "noctty-pane-tooltip-cache",
                               g_strdup(text), g_free);
    }
}

static void refresh_tag_tooltips(NocttyGridContext *context) {
    NocttyGridContext *root = root_grid_context(context);
    for (guint index = 0; root->contexts != NULL && index < root->contexts->len; index++) {
        NocttyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (candidate->active && candidate->area != NULL)
            update_status_tooltip(candidate,
                                  noctty_grid_status_name(candidate->status_kind));
    }
}

static NocttyGridContext *root_grid_context(NocttyGridContext *context) {
    if (context == NULL || context->root == NULL) return context;
    return context->root;
}

static gboolean dogfood_evidence_enabled(void) {
    const char *session_id = g_getenv("NOCTTY_DOGFOOD_SESSION_ID");
    return session_id != NULL && session_id[0] != '\0';
}

static void emit_dogfood_event(NocttyGridContext *context,
                               const char *event_name,
                               uint64_t pane_id,
                               int value,
                               const char *detail) {
    const char *session_id = g_getenv("NOCTTY_DOGFOOD_SESSION_ID");
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

static guint dogfood_active_omp_count(NocttyGridContext *context) {
    NocttyGridContext *root = root_grid_context(context);
    guint count = 0;
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        NocttyGridContext *candidate =
            g_ptr_array_index(root->contexts, index);
        if (candidate->active && !candidate->exited &&
            candidate->dogfood_omp_seen)
            count++;
    }
    return count;
}

static void detect_dogfood_omp_sessions(NocttyGridContext *context,
                                        gint64 now_us) {
    if (!dogfood_evidence_enabled()) return;
    NocttyGridContext *root = root_grid_context(context);
    guint active_count = 0;
    guint streaming_count = 0;
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        NocttyGridContext *candidate =
            g_ptr_array_index(root->contexts, index);
        if (!grid_context_session_available(candidate) || candidate->exited)
            continue;
        if (!candidate->dogfood_omp_seen) {
            uint8_t process_name[64];
            int process_name_length = noctty_grid_process_name(
                candidate->userdata, process_name, sizeof(process_name) - 1);
            if (process_name_length == 3 &&
                memcmp(process_name, "omp", 3) == 0) {
                candidate->dogfood_omp_seen = 1;
                char cwd[4096];
                int cwd_length = noctty_grid_current_directory(
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
                g_free(cwd_hash);
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
                NocttyGridContext *candidate =
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

static void record_dogfood_omp_action(NocttyGridContext *context,
                                      const char *event_name,
                                      int *seen) {
    if (context == NULL || !context->dogfood_omp_seen ||
        seen == NULL || *seen)
        return;
    *seen = 1;
    emit_dogfood_event(context, event_name, context->pane_id, 1, "observed");
}

static gboolean on_grid_write_flush(gpointer user_data) {
    NocttyGridContext *context = user_data;
    if (!grid_context_session_available(context) || context->exited) {
        context->write_flush_source = 0;
        return G_SOURCE_REMOVE;
    }
    int flushed = noctty_grid_flush_write(context->userdata);
    if (flushed > 0 || flushed < 0) {
        context->write_flush_source = 0;
        if (flushed < 0)
            show_status_feedback(context, "Terminal input flush failed.");
        return G_SOURCE_REMOVE;
    }
    return G_SOURCE_CONTINUE;
}

static void schedule_grid_write_flush(NocttyGridContext *context) {
    if (context->write_flush_source != 0 ||
        noctty_grid_write_pending(context->userdata) == 0)
        return;
    context->write_flush_source = g_timeout_add_full(
        G_PRIORITY_DEFAULT, NOCTTY_WRITE_FLUSH_MS,
        on_grid_write_flush, context, NULL);
}

static void acknowledge_grid_attention(NocttyGridContext *context) {
    if (!context->attention && context->status_kind != 4) return;
    context->attention = 0;
    context->status_kind = 0;
    update_status_tooltip(context, "idle");
    update_compact_tab(context);
    if (context->event != NULL)
        context->event(context->event_data, context->pane_id,
                       NOCTTY_EVENT_STATUS_ACKNOWLEDGED, 0,
                       (uint64_t)(g_get_monotonic_time() / 1000));
}

static int deliver_grid_input(NocttyGridContext *source, const char *bytes,
                              size_t length) {
    if (!grid_context_session_available(source)) return -1;
    NocttyGridContext *root = root_grid_context(source);
    if (root->contexts == NULL ||
        root->event_data == NULL ||
        noctty_grid_broadcast_enabled(root->event_data) == 0) {
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
        NocttyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (candidate->active && !candidate->exited &&
            candidate->page == source->page &&
            noctty_grid_pane_selected(root->event_data, candidate->pane_id) != 0)
            selected++;
    }

    int delivered = 0;
    for (guint index = 0; index < root->contexts->len; index++) {
        NocttyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (!grid_context_session_available(candidate) || candidate->exited ||
            candidate->page != source->page)
            continue;
        if (selected > 0 &&
            noctty_grid_pane_selected(root->event_data, candidate->pane_id) == 0)
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

static int deliver_grid_paste(NocttyGridContext *source, const char *bytes,
                              size_t length) {
    if (!grid_context_session_available(source)) return -1;
    NocttyGridContext *root = root_grid_context(source);
    if (root->contexts == NULL || root->event_data == NULL ||
        noctty_grid_broadcast_enabled(root->event_data) == 0) {
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
        NocttyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (candidate->active && !candidate->exited && candidate->page == source->page &&
            noctty_grid_pane_selected(root->event_data, candidate->pane_id) != 0)
            selected++;
    }
    int delivered = 0;
    for (guint index = 0; index < root->contexts->len; index++) {
        NocttyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (!grid_context_session_available(candidate) || candidate->exited ||
            candidate->page != source->page)
            continue;
        if (selected > 0 &&
            noctty_grid_pane_selected(root->event_data, candidate->pane_id) == 0)
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

static NocttyGridContext *grid_context_for_page(NocttyGridContext *context,
                                                GtkWidget *page) {
    NocttyGridContext *root = root_grid_context(context);
    for (guint index = 0; root->contexts != NULL && index < root->contexts->len; index++) {
        NocttyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (candidate->active && candidate->page == page) return candidate;
    }
    return NULL;
}

static gchar *current_tab_title_alloc(NocttyGridContext *context) {
    NocttyGridContext *root = root_grid_context(context);
    NocttyGridContext *representative = grid_context_for_page(root, context->page);
    if (representative != NULL && root->event_data != NULL) {
        char title[512];
        int length = noctty_grid_tab_title(root->event_data,
                                           representative->pane_id,
                                           title, sizeof(title) - 1);
        if (length > 0 && (size_t)length < sizeof(title)) {
            title[length] = '\0';
            return g_strdup(title);
        }
    }
    for (guint index = 0; root->contexts != NULL && index < root->contexts->len; index++) {
        NocttyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (!candidate->active || candidate->page != context->page) continue;
        if (candidate->display_title != NULL && candidate->display_title[0] != '\0')
            return g_strdup(candidate->display_title);
    }
    if (representative != NULL && root->event_data != NULL) {
        char cwd[4096];
        int length = noctty_grid_current_directory(
            representative->userdata, root->event_data, representative->pane_id,
            cwd, sizeof(cwd) - 1);
        if (length > 0 && length < (int)sizeof(cwd)) {
            cwd[length] = '\0';
            gchar *basename = g_path_get_basename(cwd);
            if (basename != NULL && basename[0] != '\0' && g_strcmp0(basename, "/") != 0)
                return basename;
            g_free(basename);
        }
    }
    gint page_index = gtk_notebook_page_num(GTK_NOTEBOOK(root->notebook),
                                            context->page);
    return g_strdup_printf("Tab %d", page_index >= 0 ? page_index + 1 : 1);
}

static void update_compact_tab(NocttyGridContext *context) {
    if (context->page == NULL || context->tab_label == NULL) return;
    NocttyGridContext *root = root_grid_context(context);
    if (root->tab_rename_entry != NULL &&
        root->tab_rename_page == context->page)
        return;
    NocttyGridContext *representative = grid_context_for_page(
        root, context->page);
    int tab_color_preset = -1;
    int tab_color_shade = 0;
    uint32_t tab_color_rgb = representative != NULL &&
            root->event_data != NULL
        ? noctty_grid_tab_color(root->event_data,
                                representative->pane_id,
                                &tab_color_preset,
                                &tab_color_shade)
        : 0;
    int status = 0;
    int attention = 0;
    int dirty = root->event_data != NULL && noctty_grid_workspace_dirty(root->event_data) != 0;
    guint panes = 0;
    guint selected = 0;
    for (guint index = 0; root->contexts != NULL && index < root->contexts->len; index++) {
        NocttyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (!candidate->active || candidate->page != context->page) continue;
        panes++;
        if (root->event_data != NULL &&
            noctty_grid_pane_selected(root->event_data, candidate->pane_id) != 0)
            selected++;
        if (candidate->status_kind > status) status = candidate->status_kind;
        if (candidate->attention) attention = 1;
    }
    gchar *title = current_tab_title_alloc(context);
    gchar *basename = g_path_get_basename(title);
    gchar *title_prefix = g_utf8_strlen(basename, -1) > 18
        ? g_utf8_substring(basename, 0, 17)
        : NULL;
    gchar *escaped = g_markup_escape_text(title_prefix != NULL
                                          ? title_prefix : basename, -1);
    const gchar *title_ellipsis = title_prefix != NULL ? "…" : "";
    gchar *escaped_filter = root->smart_filter_tag != NULL
        ? g_markup_escape_text(root->smart_filter_tag, -1) : NULL;
    gchar *filter_suffix = escaped_filter != NULL
        ? g_strdup_printf(" <span foreground='#b8a7ff'>⌕ %s</span>", escaped_filter)
        : NULL;
    char selection_suffix[64] = {0};
    if (selected > 0)
        g_snprintf(selection_suffix, sizeof(selection_suffix),
                   " <span foreground='#f6c85f'>⌁%u</span>", selected);
    const gchar *broadcast_suffix = root->event_data != NULL &&
        noctty_grid_broadcast_enabled(root->event_data) != 0
        ? " <span foreground='#70d6a7'>B</span>" : "";
    char pane_suffix[32] = {0};
    if (panes > 1)
        g_snprintf(pane_suffix, sizeof(pane_suffix), " ×%u", panes);
    gint page_index = gtk_notebook_page_num(GTK_NOTEBOOK(root->notebook),
                                            context->page);
    gboolean is_active = page_index >= 0 &&
        gtk_notebook_get_current_page(GTK_NOTEBOOK(root->notebook)) == page_index;
    gchar *title_color_attribute = tab_color_rgb != 0
        ? g_strdup_printf(
              " foreground='%s'",
              tab_color_uses_dark_text(tab_color_rgb) ? "#11151b" : "#ffffff")
        : g_strdup("");
    char color[8];
    if (!attention && status == 0) {
        g_strlcpy(color, "#6f7480", sizeof(color));
    } else {
        uint32_t status_role = attention || status == 4
            ? NOCTTY_UI_COLOR_STATUS_WARNING
            : status == 3 ? NOCTTY_UI_COLOR_STATUS_ERROR
            : status == 2 ? NOCTTY_UI_COLOR_STATUS_SUCCESS
            : NOCTTY_UI_COLOR_STATUS_INFO;
        uint32_t status_fallback = attention || status == 4
            ? 0xf5b82e : status == 3 ? 0xe64040
            : status == 2 ? 0x40cc66 : 0x408cf2;
        format_ui_color(root, status_role, status_fallback, color);
    }
    gchar *markup = g_strdup_printf(
        "<span size='small' weight='%s'%s>%s%s%s</span> <span foreground='%s'>●</span>%s%s%s%s",
        is_active ? "bold" : "normal", title_color_attribute,
        escaped, title_ellipsis, pane_suffix, color,
        dirty ? " <span foreground='#e8a85c'>◆</span>" : "",
        filter_suffix != NULL ? filter_suffix : "",
        selection_suffix, broadcast_suffix);
    g_free(title_color_attribute);
    if (root->workspace_smoke == 15 && tab_color_rgb == 0) {
        const gchar *title_end = strstr(markup, "</span>");
        if (title_end != NULL &&
            g_strstr_len(markup, title_end - markup, "foreground=") == NULL)
            root->compact_light_tab_title_inherits = 1;
    }
    const gchar *cached_markup = g_object_get_data(
        G_OBJECT(context->tab_label), "noctty-tab-markup-cache");
    if (g_strcmp0(cached_markup, markup) != 0) {
        gtk_label_set_markup(GTK_LABEL(context->tab_label), markup);
        g_object_set_data_full(G_OBJECT(context->tab_label),
                               "noctty-tab-markup-cache",
                               g_strdup(markup), g_free);
    }
    gtk_widget_show(context->tab_label);
    GtkWidget *tab_content = gtk_widget_get_parent(context->tab_label);
    if (tab_content != NULL) gtk_widget_show(tab_content);
    GtkWidget *tab_widget = tab_content != NULL
        ? gtk_widget_get_parent(tab_content) : NULL;
    if (tab_widget != NULL) gtk_widget_show(tab_widget);
    apply_tab_color_style(tab_widget, tab_color_rgb, is_active);
    gtk_widget_set_size_request(context->tab_label, -1,
                                MAX(12, root->compact_tab_height));
    char tab_color_tooltip[96] = {0};
    if (tab_color_rgb != 0)
        g_snprintf(tab_color_tooltip, sizeof(tab_color_tooltip),
                   " · tab color %s, %s",
                   noctty_grid_tab_color_preset_name(tab_color_preset),
                   noctty_grid_tab_color_shade_name(tab_color_shade));
    gchar *tooltip = g_strdup_printf("%s · %u pane%s%s%s%s%s%s%s", title, panes,
                                     panes == 1 ? "" : "s",
                                     attention ? " · attention requested" : "",
                                     dirty ? " · unsaved workspace" : "",
                                     root->smart_filter_tag != NULL ? " · Smart Tab filter active" : "",
                                     selected > 0 ? " · selection group active" : "",
                                     root->event_data != NULL && noctty_grid_broadcast_enabled(root->event_data) != 0
                                         ? " · broadcast on" : "",
                                     tab_color_tooltip);
    const gchar *cached_tooltip = g_object_get_data(
        G_OBJECT(context->tab_label), "noctty-tab-tooltip-cache");
    if (g_strcmp0(cached_tooltip, tooltip) != 0) {
        gtk_widget_set_tooltip_text(context->tab_label, tooltip);
        if (GTK_IS_EVENT_BOX(tab_widget))
            gtk_widget_set_tooltip_text(tab_widget, tooltip);
        g_object_set_data_full(G_OBJECT(context->tab_label),
                               "noctty-tab-tooltip-cache",
                               g_strdup(tooltip), g_free);
    }
    GtkWidget *close_button = tab_close_button_from_widget(tab_widget);
    if (GTK_IS_BUTTON(close_button)) {
        gchar *close_name = g_strdup_printf("Close tab: %s", title);
        const gchar *cached_close_name = g_object_get_data(
            G_OBJECT(close_button), "noctty-tab-close-name-cache");
        if (g_strcmp0(cached_close_name, close_name) != 0) {
            gtk_widget_set_tooltip_text(close_button, close_name);
            set_widget_accessible_name(close_button, close_name);
            g_object_set_data_full(
                G_OBJECT(close_button), "noctty-tab-close-name-cache",
                g_strdup(close_name), g_free);
        }
        g_free(close_name);
    }
    if (root->workspace_smoke == 3 && is_active) {
        root->tab_active_styled = 1;
        GtkWidget *close = tab_close_button_from_widget(tab_widget);
        root->tab_close_button_visible = close != NULL &&
            gtk_widget_get_visible(close) && gtk_widget_get_mapped(close);
    }
    g_free(tooltip);
    g_free(markup);
    g_free(escaped);
    g_free(title_prefix);
    g_free(filter_suffix);
    g_free(escaped_filter);
    g_free(basename);
    g_free(title);
}

static void on_notebook_switch_page(GtkNotebook *notebook, GtkWidget *page,
                                    guint page_num, gpointer user_data) {
    (void)notebook;
    (void)page_num;
    NocttyGridContext *root = root_grid_context(user_data);
    if (root->tab_rename_entry != NULL && root->tab_rename_page != page)
        finish_tab_rename(root, FALSE);
    for (guint index = 0; root->contexts != NULL && index < root->contexts->len; index++) {
        NocttyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (candidate->active && candidate->page != NULL)
            update_compact_tab(candidate);
    }
    apply_smart_filter(root);
    apply_panel_layout_metrics(root);
    refresh_active_pane_info(root);
}

static gboolean close_grid_tab(NocttyGridContext *context, GtkWidget *page);

static void clear_tab_rename_error(NocttyGridContext *root) {
    if (!GTK_IS_ENTRY(root->tab_rename_entry)) return;
    GtkStyleContext *style = gtk_widget_get_style_context(root->tab_rename_entry);
    gtk_style_context_remove_class(style, "error");
    gtk_entry_set_icon_from_icon_name(GTK_ENTRY(root->tab_rename_entry),
                                      GTK_ENTRY_ICON_SECONDARY, NULL);
    gtk_widget_set_tooltip_text(root->tab_rename_entry,
                               "Enter to save · Esc or click elsewhere to cancel");
}

static void set_tab_rename_error(NocttyGridContext *root,
                                 const gchar *message) {
    if (!GTK_IS_ENTRY(root->tab_rename_entry)) return;
    GtkStyleContext *style = gtk_widget_get_style_context(root->tab_rename_entry);
    gtk_style_context_add_class(style, "error");
    gtk_entry_set_icon_from_icon_name(GTK_ENTRY(root->tab_rename_entry),
                                      GTK_ENTRY_ICON_SECONDARY,
                                      "dialog-warning-symbolic");
    gtk_entry_set_icon_tooltip_text(GTK_ENTRY(root->tab_rename_entry),
                                    GTK_ENTRY_ICON_SECONDARY, message);
    gtk_widget_set_tooltip_text(root->tab_rename_entry, message);
}

static void finish_tab_rename(NocttyGridContext *context,
                              gboolean restore_terminal_focus) {
    NocttyGridContext *root = root_grid_context(context);
    GtkWidget *entry = root->tab_rename_entry;
    GtkWidget *page = root->tab_rename_page;
    GtkWidget *event_box = root->tab_rename_event_box;
    NocttyGridContext *target = grid_context_for_page(root, page);

    root->tab_rename_entry = NULL;
    root->tab_rename_page = NULL;
    root->tab_rename_event_box = NULL;
    if (GTK_IS_EVENT_BOX(event_box))
        gtk_event_box_set_above_child(GTK_EVENT_BOX(event_box), FALSE);
    if (GTK_IS_WIDGET(entry)) gtk_widget_destroy(entry);
    if (target != NULL && target->tab_label != NULL) {
        gtk_widget_set_no_show_all(target->tab_label, FALSE);
        gtk_widget_show(target->tab_label);
        update_compact_tab(target);
    }
    if (restore_terminal_focus && target != NULL && target->area != NULL) {
        gtk_widget_grab_focus(target->area);
        root->tab_rename_focus_restored = 1;
    }
}

static gboolean apply_tab_rename(NocttyGridContext *root) {
    if (!GTK_IS_ENTRY(root->tab_rename_entry)) return FALSE;
    GtkWidget *page = root->tab_rename_page;
    NocttyGridContext *target = grid_context_for_page(root, page);
    if (target == NULL) {
        set_tab_rename_error(root, "This tab is no longer available.");
        return FALSE;
    }
    gchar *title = g_strdup(gtk_entry_get_text(GTK_ENTRY(root->tab_rename_entry)));
    g_strstrip(title);
    size_t length = strlen(title);
    gboolean valid =
        noctty_grid_text_valid((const uint8_t *)title, length, 128) != 0;
    if (!valid) {
        set_tab_rename_error(root,
            length == 0 ? "Enter a tab name." : "Use a single-line name up to 128 bytes.");
        g_free(title);
        return FALSE;
    }
    if (root->event_data == NULL ||
        noctty_grid_rename_tab(root->event_data, target->pane_id,
                               title, length) != 0) {
        set_tab_rename_error(root, "Could not rename this tab.");
        g_free(title);
        return FALSE;
    }
    root->tab_rename_applied = 1;
    g_free(title);
    finish_tab_rename(root, TRUE);
    return TRUE;
}

static void on_tab_rename_entry_destroy(GtkWidget *widget, gpointer user_data) {
    NocttyGridContext *root = user_data;
    if (root->tab_rename_entry != widget) return;
    GtkWidget *page = root->tab_rename_page;
    GtkWidget *event_box = root->tab_rename_event_box;
    root->tab_rename_entry = NULL;
    root->tab_rename_page = NULL;
    root->tab_rename_event_box = NULL;
    if (GTK_IS_EVENT_BOX(event_box))
        gtk_event_box_set_above_child(GTK_EVENT_BOX(event_box), FALSE);
    NocttyGridContext *target = grid_context_for_page(root, page);
    if (target != NULL && target->tab_label != NULL) {
        gtk_widget_set_no_show_all(target->tab_label, FALSE);
        gtk_widget_show(target->tab_label);
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
    NocttyGridContext *root = root_grid_context(user_data);
    if (root->tab_rename_entry != widget) return FALSE;
    finish_tab_rename(root, FALSE);
    return FALSE;
}

static void open_tab_rename(NocttyGridContext *context, GtkWidget *page) {
    NocttyGridContext *root = root_grid_context(context);
    NocttyGridContext *target = grid_context_for_page(root, page);
    if (target == NULL) return;
    if (root->tab_rename_entry != NULL && root->tab_rename_page == page) {
        clear_tab_rename_error(root);
        gtk_widget_grab_focus(root->tab_rename_entry);
        gtk_editable_select_region(GTK_EDITABLE(root->tab_rename_entry), 0, -1);
        return;
    }
    if (root->tab_rename_entry != NULL) finish_tab_rename(root, FALSE);

    GtkWidget *tab_widget = page != NULL
        ? gtk_notebook_get_tab_label(GTK_NOTEBOOK(root->notebook), page)
        : NULL;
    if (!GTK_IS_EVENT_BOX(tab_widget)) return;
    GtkWidget *content = gtk_bin_get_child(GTK_BIN(tab_widget));
    if (!GTK_IS_BOX(content) || target->tab_label == NULL) return;
    GtkWidget *entry = gtk_entry_new();
    gchar *title = current_tab_title_alloc(target);
    gtk_entry_set_text(GTK_ENTRY(entry), title);
    gint title_length = (gint)g_utf8_strlen(title, -1);
    g_free(title);
    gtk_entry_set_has_frame(GTK_ENTRY(entry), FALSE);
    gtk_entry_set_alignment(GTK_ENTRY(entry), 0.5);
    gtk_entry_set_max_length(GTK_ENTRY(entry), 128);
    gtk_entry_set_width_chars(
        GTK_ENTRY(entry), noctty_grid_tab_title_width(title_length));
    gtk_entry_set_max_width_chars(GTK_ENTRY(entry), 24);
    gtk_widget_set_size_request(entry, -1, MAX(12, root->compact_tab_height));
    gtk_style_context_add_class(gtk_widget_get_style_context(entry), "flat");
    gtk_style_context_add_class(gtk_widget_get_style_context(entry),
                                "noctty-tab-rename");
    gtk_widget_set_tooltip_text(entry,
                               "Enter to save · Esc or click elsewhere to cancel");
    gtk_box_pack_start(GTK_BOX(content), entry, TRUE, TRUE, 0);
    gtk_box_reorder_child(GTK_BOX(content), entry, 0);
    gtk_widget_set_no_show_all(target->tab_label, TRUE);
    gtk_widget_hide(target->tab_label);
    gtk_event_box_set_above_child(GTK_EVENT_BOX(tab_widget), FALSE);
    root->tab_rename_entry = entry;
    root->tab_rename_page = page;
    root->tab_rename_event_box = tab_widget;
    root->tab_rename_inline_shown = 1;
    root->tab_rename_inline_embedded =
        gtk_widget_get_toplevel(entry) == root->window;
    g_signal_connect(entry, "activate", G_CALLBACK(on_tab_rename_activate), root);
    g_signal_connect(entry, "key-press-event", G_CALLBACK(on_tab_rename_key), root);
    g_signal_connect(entry, "focus-out-event", G_CALLBACK(on_tab_rename_focus_out), root);
    g_signal_connect(entry, "destroy", G_CALLBACK(on_tab_rename_entry_destroy), root);
    gtk_widget_show(entry);
    gtk_widget_grab_focus(entry);
    gtk_editable_select_region(GTK_EDITABLE(entry), 0, -1);
}

static void show_tab_menu(NocttyGridContext *context, GtkWidget *page,
                          GdkEventButton *event);

static gboolean on_tab_button_press(GtkWidget *widget, GdkEventButton *event,
                                    gpointer user_data) {
    GtkWidget *page = g_object_get_data(G_OBJECT(widget), "noctty-tab-page");
    if (page == NULL) return FALSE;
    NocttyGridContext *root = root_grid_context(user_data);
    if (event->button == 1 && event->type == GDK_BUTTON_PRESS) {
        gint active_index = gtk_notebook_get_current_page(
            GTK_NOTEBOOK(root->notebook));
        root->tab_reorder_pressed_active_page = active_index >= 0
            ? gtk_notebook_get_nth_page(GTK_NOTEBOOK(root->notebook),
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
    NocttyGridContext *root = root_grid_context(user_data);
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
    NocttyGridContext *root = root_grid_context(user_data);
    root->tab_reorder_dragging = 1;
    root->tab_reorder_drag_begin_seen = 1;
    root->tab_reorder_drag_active_page =
        root->tab_reorder_pressed_active_page;
    if (root->tab_reorder_drag_active_page == NULL) {
        gint active_index = gtk_notebook_get_current_page(
            GTK_NOTEBOOK(root->notebook));
        root->tab_reorder_drag_active_page = active_index >= 0
            ? gtk_notebook_get_nth_page(GTK_NOTEBOOK(root->notebook),
                                        active_index)
            : NULL;
    }
}

static void on_notebook_drag_end(GtkWidget *widget, GdkDragContext *drag,
                                 gpointer user_data) {
    (void)widget;
    (void)drag;
    NocttyGridContext *root = root_grid_context(user_data);
    GtkWidget *active_page = root->tab_reorder_drag_active_page;
    if (active_page != NULL) {
        gint active_index = gtk_notebook_page_num(
            GTK_NOTEBOOK(root->notebook), active_page);
        if (active_index >= 0)
            gtk_notebook_set_current_page(GTK_NOTEBOOK(root->notebook),
                                          active_index);
    }
    root->tab_reorder_drag_end_seen = root->tab_reorder_count > 0;
    root->tab_reorder_dragging = 0;
    root->tab_reorder_pressed_active_page = NULL;
    root->tab_reorder_drag_active_page = NULL;
    if (root->tab_reorder_count > 0)
        schedule_grid_hot_session_flush(root);
}

static void on_tab_close_button_clicked(GtkButton *button, gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    GtkWidget *page = g_object_get_data(G_OBJECT(button), "noctty-tab-page");
    (void)close_grid_tab(root, page);
}

static GtkWidget *create_compact_tab_widget(NocttyGridContext *context,
                                            GtkWidget *page,
                                            const gchar *text) {
    NocttyGridContext *root = root_grid_context(context);
    NocttyCompactTabOptions options = {
        .page = page,
        .text = text,
        .callback_data = root,
    };
    NocttyCompactTabCallbacks callbacks = {
        .button_press = G_CALLBACK(on_tab_button_press),
        .button_release = G_CALLBACK(on_tab_button_release),
        .drag_begin = G_CALLBACK(on_notebook_drag_begin),
        .drag_end = G_CALLBACK(on_notebook_drag_end),
        .close_clicked = G_CALLBACK(on_tab_close_button_clicked),
    };
    NocttyCompactTabContents contents = {0};
    if (!noctty_compact_tab_new(&options, &callbacks, &contents))
        return NULL;
    return contents.tab;
}

static void on_new_tab_button_clicked(GtkButton *button, gpointer user_data) {
    (void)button;
    NocttyGridContext *target = active_grid_context(user_data);
    if (target != NULL && target->active && !target->exited &&
        target->area != NULL)
        emit_grid_workspace_event(target, 20);
}

static void on_notebook_page_reordered(GtkNotebook *notebook, GtkWidget *page,
                                       guint page_num, gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    if (root->layout_restore_applying || root->tab_reorder_syncing) return;
    NocttyGridContext *representative = grid_context_for_page(root, page);
    if (representative == NULL || root->event_data == NULL) return;
    GtkWidget *active_page = root->tab_reorder_dragging
        ? root->tab_reorder_drag_active_page
        : root->tab_reorder_pressed_active_page;
    if (active_page == NULL) {
        gint active_index = gtk_notebook_get_current_page(notebook);
        active_page = active_index >= 0
            ? gtk_notebook_get_nth_page(notebook, active_index) : NULL;
    }
    if (noctty_grid_reorder_tab(root->event_data, representative->pane_id,
                                (int)page_num) != 0) {
        int model_index = noctty_grid_tab_index_for_pane(
            root->event_data, representative->pane_id);
        if (model_index >= 0) {
            root->tab_reorder_syncing = 1;
            gtk_notebook_reorder_child(notebook, page, model_index);
            root->tab_reorder_syncing = 0;
        }
        return;
    }
    root->tab_reorder_count++;
    gint active_page_num = active_page != NULL
        ? gtk_notebook_page_num(notebook, active_page) : -1;
    if (active_page_num >= 0)
        gtk_notebook_set_current_page(notebook, active_page_num);
    update_compact_tab(representative);
    schedule_grid_hot_session_flush(root);
}

static GtkWidget *create_new_tab_button(NocttyGridContext *context) {
    NocttyGridContext *root = root_grid_context(context);
    gint extent = MAX(24, root->compact_tab_height + 2);
    return noctty_new_tab_button_new(
        extent, root, G_CALLBACK(on_new_tab_button_clicked));
}

enum {
    NOCTTY_RECOVERY_CONFIG_BACKUP = 1u << 0,
    NOCTTY_RECOVERY_CONFIG_DEFAULTS = 1u << 1,
    NOCTTY_RECOVERY_THEME_BACKUP = 1u << 2,
    NOCTTY_RECOVERY_THEME_DEFAULTS = 1u << 3,
    NOCTTY_RECOVERY_WORKSPACE_DEFAULTS = 1u << 4,
};

static void on_recovery_notice_response(GtkInfoBar *bar, gint response_id,
                                        gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    if (response_id == GTK_RESPONSE_APPLY) open_grid_settings(root);
    gtk_widget_hide(GTK_WIDGET(bar));
}

static GtkWidget *create_recovery_notice(NocttyGridContext *context) {
    NocttyGridContext *root = root_grid_context(context);
    guint32 flags = root->recovery_notice_flags;
    if (flags == 0) return NULL;

    GString *message = g_string_new(NULL);
    if (flags & NOCTTY_RECOVERY_CONFIG_BACKUP)
        g_string_append(message,
            "Settings were damaged. Last-known-good settings were loaded.");
    else if (flags & NOCTTY_RECOVERY_CONFIG_DEFAULTS)
        g_string_append(message,
            "Settings were damaged. Safe defaults were loaded.");
    if (flags & NOCTTY_RECOVERY_THEME_BACKUP) {
        if (message->len > 0) g_string_append_c(message, ' ');
        g_string_append(message,
            "The last-known-good theme library was restored.");
    } else if (flags & NOCTTY_RECOVERY_THEME_DEFAULTS) {
        if (message->len > 0) g_string_append_c(message, ' ');
        g_string_append(message,
            "Built-in themes are available while the damaged library is retained.");
    }
    if (flags & NOCTTY_RECOVERY_WORKSPACE_DEFAULTS) {
        if (message->len > 0) g_string_append_c(message, ' ');
        g_string_append(message,
            "The damaged workspace snapshot was skipped; a clean workspace was opened.");
    }

    GtkWidget *bar = gtk_info_bar_new_with_buttons(
        "Open Settings", GTK_RESPONSE_APPLY,
        "Dismiss", GTK_RESPONSE_CLOSE, NULL);
    gtk_info_bar_set_message_type(GTK_INFO_BAR(bar), GTK_MESSAGE_WARNING);
    gtk_widget_set_name(bar, "noctty-recovery-notice");
    GtkWidget *content = gtk_info_bar_get_content_area(GTK_INFO_BAR(bar));
    GtkWidget *label = gtk_label_new(message->str);
    gtk_label_set_xalign(GTK_LABEL(label), 0.0f);
    gtk_label_set_line_wrap(GTK_LABEL(label), TRUE);
    gtk_label_set_max_width_chars(GTK_LABEL(label), 96);
    set_widget_accessible_name(label, "NOCTTY startup recovery notice");
    gtk_box_pack_start(GTK_BOX(content), label, TRUE, TRUE, 0);
    g_signal_connect(bar, "response",
                     G_CALLBACK(on_recovery_notice_response), root);
    g_print("noctty_startup_recovery_notice flags=%u "
            "config_backup=%d config_defaults=%d theme_backup=%d "
            "theme_defaults=%d workspace_defaults=%d\n",
            flags,
            (flags & NOCTTY_RECOVERY_CONFIG_BACKUP) != 0,
            (flags & NOCTTY_RECOVERY_CONFIG_DEFAULTS) != 0,
            (flags & NOCTTY_RECOVERY_THEME_BACKUP) != 0,
            (flags & NOCTTY_RECOVERY_THEME_DEFAULTS) != 0,
            (flags & NOCTTY_RECOVERY_WORKSPACE_DEFAULTS) != 0);
    g_string_free(message, TRUE);
    return bar;
}

static void on_window_settings_button_clicked(GtkButton *button,
                                              gpointer user_data) {
    (void)button;
    NocttyGridContext *root = root_grid_context(user_data);
    root->window_settings_button_activated = 1;
    open_grid_settings(root);
}

static void on_window_close_button_clicked(GtkButton *button,
                                           gpointer user_data) {
    (void)button;
    NocttyGridContext *root = root_grid_context(user_data);
    root->window_close_button_activated = 1;
    (void)request_grid_application_close(
        root, NOCTTY_CLOSE_ORIGIN_TOOLBAR);
}

static void update_window_toolbar_controls(NocttyGridContext *context) {
    NocttyGridContext *root = root_grid_context(context);
    noctty_window_toolbar_set_close_visible(
        root->window_close_button, root->mode != 1);
}

static GtkWidget *create_window_toolbar_controls(NocttyGridContext *context) {
    NocttyGridContext *root = root_grid_context(context);
    NocttyWindowToolbarCallbacks callbacks = {
        .settings_clicked = G_CALLBACK(on_window_settings_button_clicked),
        .close_clicked = G_CALLBACK(on_window_close_button_clicked),
    };
    NocttyWindowToolbarContents contents = {0};
    gint extent = MAX(24, root->compact_tab_height + 2);
    if (!noctty_window_toolbar_new(
            extent, root, &callbacks, &contents))
        return NULL;
    root->window_toolbar_controls = contents.controls;
    root->window_settings_button = contents.settings;
    root->window_close_button = contents.close_button;
    update_window_toolbar_controls(root);
    return contents.controls;
}

static gboolean request_new_tab_button_smoke(gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    GtkWidget *button = root->new_tab_button;
    GtkWidget *icon = GTK_IS_BUTTON(button)
        ? gtk_button_get_image(GTK_BUTTON(button))
        : NULL;
    const gchar *icon_name = NULL;
    GtkIconSize icon_size = GTK_ICON_SIZE_INVALID;
    if (GTK_IS_IMAGE(icon))
        gtk_image_get_icon_name(GTK_IMAGE(icon), &icon_name, &icon_size);
    AtkObject *accessible = button != NULL
        ? gtk_widget_get_accessible(button)
        : NULL;
    root->new_tab_button_visible = button != NULL &&
        gtk_notebook_get_n_pages(GTK_NOTEBOOK(root->notebook)) == 1 &&
        gtk_notebook_get_show_tabs(GTK_NOTEBOOK(root->notebook)) &&
        gtk_widget_get_mapped(button);
    root->new_tab_button_at_start = button != NULL &&
        gtk_notebook_get_action_widget(GTK_NOTEBOOK(root->notebook),
                                       GTK_PACK_START) == button;
    root->new_tab_button_icon = GTK_IS_IMAGE(icon) &&
        icon_size == GTK_ICON_SIZE_MENU &&
        g_strcmp0(icon_name, "list-add-symbolic") == 0;
    root->new_tab_button_accessible = accessible != NULL &&
        g_strcmp0(atk_object_get_name(accessible), "New Tab, Ctrl+Shift+T") == 0;
    if (button != NULL) gtk_button_clicked(GTK_BUTTON(button));
    root->new_tab_button_clicked =
        gtk_notebook_get_n_pages(GTK_NOTEBOOK(root->notebook)) == 2 &&
        gtk_notebook_get_current_page(GTK_NOTEBOOK(root->notebook)) == 1;
    return G_SOURCE_REMOVE;
}

static gboolean inspect_compact_tab_geometry_smoke(gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    gint page_count = gtk_notebook_get_n_pages(GTK_NOTEBOOK(root->notebook));
    gint active_index = gtk_notebook_get_current_page(
        GTK_NOTEBOOK(root->notebook));
    GtkWidget *page = active_index >= 0
        ? gtk_notebook_get_nth_page(GTK_NOTEBOOK(root->notebook), active_index)
        : NULL;
    GtkWidget *tab_widget = page != NULL
        ? gtk_notebook_get_tab_label(GTK_NOTEBOOK(root->notebook), page)
        : NULL;
    GtkWidget *close = tab_close_button_from_widget(tab_widget);
    GtkWidget *close_icon = GTK_IS_BUTTON(close)
        ? gtk_button_get_image(GTK_BUTTON(close))
        : NULL;
    const gchar *close_icon_name = NULL;
    GtkIconSize close_icon_size = GTK_ICON_SIZE_INVALID;
    if (GTK_IS_IMAGE(close_icon))
        gtk_image_get_icon_name(GTK_IMAGE(close_icon),
                                &close_icon_name, &close_icon_size);
    GtkAllocation notebook_allocation = {0};
    GtkAllocation page_allocation = {0};
    GtkAllocation tab_allocation = {0};
    GtkAllocation close_allocation = {0};
    GtkAllocation action_allocation = {0};
    if (root->notebook != NULL)
        gtk_widget_get_allocation(root->notebook, &notebook_allocation);
    if (page != NULL) gtk_widget_get_allocation(page, &page_allocation);
    if (tab_widget != NULL)
        gtk_widget_get_allocation(tab_widget, &tab_allocation);
    if (close != NULL) gtk_widget_get_allocation(close, &close_allocation);
    if (root->new_tab_button != NULL)
        gtk_widget_get_allocation(root->new_tab_button, &action_allocation);
    GtkPositionType position = gtk_notebook_get_tab_pos(
        GTK_NOTEBOOK(root->notebook));
    gboolean horizontal = position == GTK_POS_TOP || position == GTK_POS_BOTTOM;
    root->compact_tab_strip_extent = horizontal
        ? notebook_allocation.height - page_allocation.height
        : notebook_allocation.width - page_allocation.width;
    root->compact_tab_widget_extent = horizontal
        ? tab_allocation.height
        : tab_allocation.width;
    root->compact_tab_max_width = tab_allocation.width;
    for (gint index = 1; index < page_count; index++) {
        GtkWidget *candidate_page = gtk_notebook_get_nth_page(
            GTK_NOTEBOOK(root->notebook), index);
        GtkWidget *candidate_tab = gtk_notebook_get_tab_label(
            GTK_NOTEBOOK(root->notebook), candidate_page);
        GtkAllocation candidate_allocation = {0};
        if (candidate_tab != NULL)
            gtk_widget_get_allocation(candidate_tab, &candidate_allocation);
        root->compact_tab_max_width = MAX(root->compact_tab_max_width,
                                          candidate_allocation.width);
    }
    root->compact_tab_close_extent = MIN(
        close_allocation.width, close_allocation.height);
    root->compact_tab_action_extent = MIN(
        action_allocation.width, action_allocation.height);
    gint strip_limit = MAX(30, root->compact_tab_height * 3 / 2 + 1);
    root->compact_tab_geometry = page_count == 2 && horizontal &&
        close != NULL && gtk_widget_get_visible(close) &&
        gtk_widget_get_mapped(close) &&
        root->compact_tab_strip_extent > 0 &&
        root->compact_tab_strip_extent <= strip_limit &&
        root->compact_tab_widget_extent <= strip_limit &&
        root->compact_tab_max_width <= 150 &&
        GTK_IS_IMAGE(close_icon) &&
        close_icon_size == GTK_ICON_SIZE_MENU &&
        g_strcmp0(close_icon_name, "window-close-symbolic") == 0 &&
        root->compact_tab_close_extent >= 24 &&
        root->compact_tab_close_extent <= 30 &&
        root->compact_tab_action_extent >= 24 &&
        root->compact_tab_action_extent <= 30;
    return G_SOURCE_REMOVE;
}

static gboolean request_tab_rename_smoke(gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    gint page_index = gtk_notebook_get_current_page(
        GTK_NOTEBOOK(root->notebook));
    GtkWidget *page = gtk_notebook_get_nth_page(
        GTK_NOTEBOOK(root->notebook), 1);
    GtkWidget *tab_widget = gtk_notebook_get_tab_label(
        GTK_NOTEBOOK(root->notebook), page);
    NocttyGridContext *target = grid_context_for_page(root, page);
    gboolean ready = gtk_notebook_get_n_pages(GTK_NOTEBOOK(root->notebook)) == 2 &&
        page_index == 1 && page != NULL && tab_widget != NULL &&
        gtk_widget_get_mapped(tab_widget) && target != NULL &&
        root->saw_draw && target->saw_draw;
    if (!ready) {
        if (root->project_smoke_attempts++ < 200) {
            gint pending_index = root->saw_draw ? 1 : 0;
            gtk_notebook_set_current_page(GTK_NOTEBOOK(root->notebook),
                                          pending_index);
            NocttyGridContext *pending = pending_index == 0 ? root : target;
            if (pending != NULL && pending->area != NULL)
                gtk_widget_queue_draw(pending->area);
            g_timeout_add(25, request_tab_rename_smoke, root);
            return G_SOURCE_REMOVE;
        }
        for (guint index = 0; root->contexts != NULL &&
             index < root->contexts->len; index++) {
            NocttyGridContext *candidate =
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
        gtk_entry_set_text(GTK_ENTRY(root->tab_rename_entry),
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
            ? gtk_label_get_text(GTK_LABEL(target->tab_label)) : "";
        root->tab_rename_outside_cancelled =
            root->tab_rename_entry == NULL && original_title != NULL &&
            g_strcmp0(original_title, after_cancel) == 0 &&
            strstr(label, "Cancelled tab rename") == NULL;
        g_free(after_cancel);

        GdkEventButton event = {0};
        event.type = GDK_2BUTTON_PRESS;
        event.button = 1;
        (void)on_tab_button_press(tab_widget, &event, root);
    }
    if (root->tab_rename_entry != NULL) {
        gtk_entry_set_text(GTK_ENTRY(root->tab_rename_entry), "Build logs");
        g_signal_emit_by_name(root->tab_rename_entry, "activate");
    }
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        NocttyGridContext *candidate =
            g_ptr_array_index(root->contexts, index);
        if (candidate->active && candidate->write != NULL)
            (void)candidate->write(candidate->userdata, "done\n", 5);
    }
    g_free(original_title);
    return G_SOURCE_REMOVE;
}

static void apply_panel_layout_metrics(NocttyGridContext *root) {
    if (GTK_IS_NOTEBOOK(root->notebook)) {
        int pages = gtk_notebook_get_n_pages(GTK_NOTEBOOK(root->notebook));
        for (int index = 0; index < pages; index++) {
            GtkWidget *page = gtk_notebook_get_nth_page(
                GTK_NOTEBOOK(root->notebook), index);
            if (GTK_IS_CONTAINER(page))
                gtk_container_set_border_width(
                    GTK_CONTAINER(page), (guint)root->panel_padding_px);
            NocttyGridContext *representative =
                grid_context_for_page(root, page);
            uint32_t gap_rgb = representative != NULL &&
                    root->event_data != NULL
                ? noctty_grid_pane_gap_rgb(
                      root->event_data, representative->pane_id)
                : 0x0b0d12u;
            gboolean gap_opaque = root->pane_gaps_enabled &&
                !root->pane_gaps_transparent;
            noctty_apply_pane_gap_style(page, gap_rgb, gap_opaque);
        }
        noctty_apply_pane_divider_style(
            root->notebook, root->pane_divider_px);
    }
    int gap_width = root->pane_gaps_enabled ? root->pane_spacing_px : 0;
    int spacing_leading = gap_width / 2;
    int spacing_trailing = gap_width - spacing_leading;
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        NocttyGridContext *candidate =
            g_ptr_array_index(root->contexts, index);
        if (candidate->area == NULL) continue;
        gtk_widget_set_margin_start(candidate->area, spacing_leading);
        gtk_widget_set_margin_top(candidate->area, spacing_leading);
        gtk_widget_set_margin_end(candidate->area, spacing_trailing);
        gtk_widget_set_margin_bottom(candidate->area, spacing_trailing);
    }
}

static void update_notebook_chrome(NocttyGridContext *context) {
    NocttyGridContext *root = root_grid_context(context);
    gboolean show = root->zoomed_pane_id == 0 &&
        gtk_notebook_get_n_pages(GTK_NOTEBOOK(root->notebook)) > 0;
    gtk_notebook_set_show_tabs(GTK_NOTEBOOK(root->notebook), show);
    gtk_notebook_set_show_border(GTK_NOTEBOOK(root->notebook), FALSE);
}

typedef struct {
    NocttyGridContext *root;
    uint64_t pane_id;
    int exit_code;
    int attention;
} NocttyNotificationRequest;

static void on_grid_notification_sent(GObject *source, GAsyncResult *result,
                                      gpointer user_data) {
    NocttyNotificationRequest *request = user_data;
    GError *error = NULL;
    GVariant *reply = g_dbus_connection_call_finish(
        G_DBUS_CONNECTION(source), result, &error);
    if (reply != NULL) {
        request->root->notification_delivered = 1;
        g_variant_unref(reply);
    }
    g_clear_error(&error);
    finish_grid_dbus_operation(request->root);
    g_free(request);
}

static void on_grid_notification_bus_ready(GObject *source,
                                           GAsyncResult *result,
                                           gpointer user_data) {
    (void)source;
    NocttyNotificationRequest *request = user_data;
    GError *error = NULL;
    GDBusConnection *bus = g_bus_get_finish(result, &error);
    if (bus == NULL) {
        g_clear_error(&error);
        finish_grid_dbus_operation(request->root);
        g_free(request);
        return;
    }
    gchar *body = request->attention
        ? g_strdup_printf("Pane %" G_GUINT64_FORMAT " requested attention",
                          request->pane_id)
        : g_strdup_printf("Pane %" G_GUINT64_FORMAT " exited with code %d",
                          request->pane_id, request->exit_code);
    GVariantBuilder hints;
    g_variant_builder_init(&hints, G_VARIANT_TYPE("a{sv}"));
    g_dbus_connection_call(
        bus, "org.freedesktop.Notifications",
        "/org/freedesktop/Notifications", "org.freedesktop.Notifications",
        "Notify",
        g_variant_new("(susss@as@a{sv}i)", "NOCTTY", 0u,
                      "com.lichforge.NOCTTY",
                      request->attention ? "Terminal needs attention" :
                                           "Terminal finished",
                      body,
                      g_variant_new_strv(NULL, 0),
                      g_variant_builder_end(&hints), 5000),
        G_VARIANT_TYPE("(u)"), G_DBUS_CALL_FLAGS_NONE, 1500,
        request->root->dbus_cancellable, on_grid_notification_sent, request);
    g_free(body);
    g_object_unref(bus);
}

static void send_exit_notification(NocttyGridContext *context, int exit_code) {
    if (!context->enable_notifications) return;
    NocttyGridContext *root = root_grid_context(context);
    NocttyNotificationRequest *request = g_new0(NocttyNotificationRequest, 1);
    request->root = root;
    request->pane_id = context->pane_id;
    request->exit_code = exit_code;
    begin_grid_dbus_operation(root);
    g_bus_get(G_BUS_TYPE_SESSION, root->dbus_cancellable,
              on_grid_notification_bus_ready, request);
}

static void send_attention_notification(NocttyGridContext *context,
                                        gint64 now_us) {
    if (!context->enable_notifications || context->focused) return;
    if (now_us - context->last_desktop_notification_us < G_USEC_PER_SEC)
        return;
    context->last_desktop_notification_us = now_us;
    NocttyGridContext *root = root_grid_context(context);
    NocttyNotificationRequest *request = g_new0(NocttyNotificationRequest, 1);
    request->root = root;
    request->pane_id = context->pane_id;
    request->attention = 1;
    begin_grid_dbus_operation(root);
    g_bus_get(G_BUS_TYPE_SESSION, root->dbus_cancellable,
              on_grid_notification_bus_ready, request);
}

static gboolean all_grid_contexts_exited(NocttyGridContext *context) {
    if (context->contexts == NULL) return context->exited;
    for (guint index = 0; index < context->contexts->len; index++) {
        NocttyGridContext *candidate = g_ptr_array_index(context->contexts, index);
        if (candidate->active && !candidate->exited) return FALSE;
    }
    return TRUE;
}

static void queue_grid_draw_when_mapped(NocttyGridContext *context) {
    if (context->area != NULL && gtk_widget_get_mapped(context->area))
        gtk_widget_queue_draw(context->area);
}

static gboolean ensure_grid_dirty_rows(NocttyGridContext *context) {
    size_t required = (size_t)MAX(context->rows, 1);
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

static gboolean ensure_grid_dirty_spans(NocttyGridContext *context) {
    size_t required = (size_t)MAX(context->rows, 1);
    if (context->dirty_span_buffer != NULL &&
        context->dirty_span_capacity == required)
        return TRUE;
    NocttyGridDirtySpan *dirty = g_try_realloc_n(
        context->dirty_span_buffer, required, sizeof(*dirty));
    if (dirty == NULL) return FALSE;
    context->dirty_span_buffer = dirty;
    context->dirty_span_capacity = required;
    context->damage_initialized = 0;
    return TRUE;
}

static void queue_grid_row_range(NocttyGridContext *context, int first,
                                 int end) {
    if (first < 0 || end <= first || context->area == NULL) return;
    GtkAllocation allocation;
    gtk_widget_get_allocation(context->area, &allocation);
    NocttyGridFontMetrics metrics = grid_font_metrics(context);
    NocttyGridRectangle damage;
    noctty_grid_row_span(first, end, metrics.cell_height, &damage);
    NocttyGridDamageRect clipped;
    noctty_grid_damage_rect(
        0, damage.y, allocation.width, damage.height,
        allocation.width, allocation.height, &clipped);
    gtk_widget_queue_draw_area(
        context->area, clipped.x, clipped.y, clipped.width, clipped.height);
    root_grid_context(context)->damage_rows_queued += (guint)(end - first);
    root_grid_context(context)->damage_cells_queued +=
        (guint)(end - first) * (guint)context->columns;
}

static void queue_grid_cell_span(NocttyGridContext *context, int row,
                                 int first, int end) {
    if (row < 0 || row >= context->rows || first < 0 || end <= first ||
        first >= context->columns || context->area == NULL)
        return;
    end = MIN(end, context->columns);
    GtkAllocation allocation;
    gtk_widget_get_allocation(context->area, &allocation);
    NocttyGridFontMetrics metrics = grid_font_metrics(context);
    NocttyGridRectangle damage;
    noctty_grid_cell_span(
        first, end, row, metrics.cell_width, metrics.cell_height, 1, &damage);
    NocttyGridDamageRect clipped;
    noctty_grid_damage_rect(
        damage.x, damage.y, damage.width, damage.height,
        allocation.width, allocation.height, &clipped);
    gtk_widget_queue_draw_area(
        context->area, clipped.x, clipped.y, clipped.width, clipped.height);
    NocttyGridContext *root = root_grid_context(context);
    root->damage_rows_queued++;
    root->damage_cells_queued += (guint)(end - first);
    root->damage_spans_queued++;
}

static void queue_grid_cursor_cell(NocttyGridContext *context,
                                   uint32_t packed_cursor) {
    if (packed_cursor == UINT32_MAX || context->area == NULL) return;
    int column = (int)(packed_cursor & 0xffff);
    int row = (int)(packed_cursor >> 16);
    if (column < 0 || column >= context->columns ||
        row < 0 || row >= context->rows) return;
    NocttyGridFontMetrics metrics = grid_font_metrics(context);
    NocttyGridDamageRect damage;
    noctty_grid_cursor_damage(
        column, row, metrics.cell_width, metrics.cell_height, &damage);
    gtk_widget_queue_draw_area(
        context->area, damage.x, damage.y, damage.width, damage.height);
}

static void queue_grid_damage_when_mapped(NocttyGridContext *context) {
    if (context->area == NULL || !gtk_widget_get_mapped(context->area)) return;
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
                NocttyGridContext *root = root_grid_context(context);
                root->damage_rows_queued += (guint)context->rows;
                root->damage_cells_queued +=
                    (guint)context->rows * (guint)context->columns;
                gtk_widget_queue_draw(context->area);
                return;
            }
            for (int row = 0; row < context->rows; row++) {
                NocttyGridDirtySpan span = context->dirty_span_buffer[row];
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
        gtk_widget_queue_draw(context->area);
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
    NocttyGridContext *context = user_data;
    context->synchronized_output_source = 0;
    if (!grid_context_session_available(context) || context->exited ||
        !context->synchronized_output_pending)
        return G_SOURCE_REMOVE;
    context->synchronized_output_pending = 0;
    NocttyGridContext *root = root_grid_context(context);
    root->synchronized_output_deadman_releases++;
    queue_grid_damage_when_mapped(context);
    return G_SOURCE_REMOVE;
}

static void queue_grid_output_when_ready(NocttyGridContext *context) {
    if (context->presentation_ready(context->userdata) == 0) {
        context->synchronized_output_pending = 1;
        root_grid_context(context)->synchronized_output_deferrals++;
        if (context->synchronized_output_source == 0)
            context->synchronized_output_source = g_timeout_add_full(
                G_PRIORITY_DEFAULT, 200, on_synchronized_output_deadman,
                context, NULL);
        return;
    }
    if (context->synchronized_output_pending) {
        context->synchronized_output_pending = 0;
        root_grid_context(context)->synchronized_output_releases++;
    }
    remove_grid_source(&context->synchronized_output_source);
    queue_grid_damage_when_mapped(context);
    if (context->area != NULL && gtk_widget_get_mapped(context->area)) {
        GdkFrameClock *clock = gtk_widget_get_frame_clock(context->area);
        if (clock != NULL)
            gdk_frame_clock_request_phase(clock, GDK_FRAME_CLOCK_PHASE_PAINT);
    }
}

static void mark_grid_output_activity(NocttyGridContext *context) {
    context->last_output_us = g_get_monotonic_time();
    context->idle_history_compacted = 0;
#if NOCTTY_ENABLE_SMOKE
    NocttyGridContext *root = root_grid_context(context);
    if (root->workspace_smoke == 36)
        root->presentation_output_serial++;
#endif
}

static void record_dogfood_omp_output(NocttyGridContext *context,
                                      int pumped) {
    if (!context->dogfood_omp_seen) return;
    if (pumped > 0)
        context->dogfood_omp_output_bytes += (uint64_t)pumped;
    else if (pumped == -1)
        context->dogfood_omp_feed_failed = 1;
}

static void set_grid_window_title(NocttyGridContext *context,
                                  GtkWidget *window,
                                  const char *title) {
    NocttyGridContext *root = root_grid_context(context);
    if (!GTK_IS_WINDOW(window) || title == NULL || title[0] == '\0')
        return;
    const char *prefix = root->mode == 0
        ? "NOCTTY Dropdown — "
        : root->mode == 2 ? "NOCTTY Zen — " : "";
    char display[576];
    g_snprintf(display, sizeof(display), "%s%s", prefix, title);
    const gchar *current = gtk_window_get_title(GTK_WINDOW(window));
    if (g_strcmp0(current, display) != 0)
        gtk_window_set_title(GTK_WINDOW(window), display);
}

static int pump_grid_context(NocttyGridContext *context,
                             gboolean *exited_now) {
    if (!grid_context_session_available(context) || context->exited)
        return -2;
    int pumped = context->pty_fd == -1
        ? context->pump(context->userdata)
        : -2;
    record_dogfood_omp_output(context, pumped);
    if (pumped != -2) schedule_grid_write_flush(context);

    if (pumped == 0) {
        (void)noctty_grid_close_transport(context->userdata);
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
                g_free(context->display_title);
                context->display_title = g_strdup(title);
                update_compact_tab(context);
            }
            if ((context->focused || context->primary) &&
                root_grid_context(context)->workspace_smoke != 39)
                set_grid_window_title(
                    context, root_grid_context(context)->window, title);
        }

        uint64_t bell_serial = noctty_grid_bell_serial(context->userdata);
        if (bell_serial != context->last_bell_serial) {
            if (bell_serial > context->last_bell_serial) {
                context->attention = 1;
                root_grid_context(context)->compact_attention_seen = 1;
            }
            context->last_bell_serial = bell_serial;
            update_compact_tab(context);
        }

        uint64_t notification_serial =
            noctty_grid_notification_serial(context->userdata);
        if (notification_serial != context->last_notification_serial) {
            context->last_notification_serial = notification_serial;
            context->pending_notification_action =
                noctty_grid_notification_action(context->userdata);
            notification_requested = TRUE;
        }
    }

    gint64 now_us = g_get_monotonic_time();
    int exit_code = -1;
    if (pumped != -2 || had_output || context->last_exit_poll_us == 0 ||
        now_us - context->last_exit_poll_us >= 250 * 1000) {
        context->last_exit_poll_us = now_us;
        exit_code = context->poll_exit(context->userdata);
    }
    if (exit_code >= 0) {
        if (context->event != NULL) context->event(context->event_data, context->pane_id, 3, exit_code, (uint64_t)(g_get_monotonic_time() / 1000));
        context->exited = 1;
        context->attention = 0;
        if (context->workspace_smoke == 24 && context->event != NULL)
            context->event(context->event_data, context->pane_id, 87, 1,
                           (uint64_t)(g_get_monotonic_time() / 1000));
        context->exit_code = exit_code;
        context->status_kind = exit_code == 0 ? 2 : 3;
        update_status_tooltip(context, exit_code == 0 ? "done" : "error");
        send_exit_notification(context, exit_code);
        update_compact_tab(context);
        queue_grid_draw_when_mapped(context);
        if (all_grid_contexts_exited(context))
            (void)request_grid_application_close(
                context, NOCTTY_CLOSE_ORIGIN_NATURAL);
        *exited_now = TRUE;
        return pumped;
    }
    int active_status = context->status_kind == 4 || context->attention ? 4 : 1;
    int status_changed = context->status_kind != active_status;
    context->status_kind = active_status;
    if (context->event != NULL && (had_output || status_changed))
        context->event(context->event_data, context->pane_id,
                       active_status == 4 ? 109 : 2, 0,
                       (uint64_t)(g_get_monotonic_time() / 1000));
    if (status_changed) {
        update_status_tooltip(context, noctty_grid_status_name(active_status));
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
                           NOCTTY_EVENT_STATUS_NOTIFICATION, 0,
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

static int register_grid_pty(NocttyGridContext *context) {
    context->pty_source = g_unix_fd_add_full(
        G_PRIORITY_DEFAULT, context->pty_fd,
        (GIOCondition)(G_IO_IN | G_IO_HUP | G_IO_ERR), on_pty_ready,
        context, NULL);
    return context->pty_source != 0;
}

static void remove_grid_source(guint *source) {
    if (*source == 0) return;
    g_source_remove(*source);
    *source = 0;
}

static void remove_output_present(NocttyGridContext *context) {
    if (context->output_present_source == 0) return;
    if (context->output_present_is_tick && context->area != NULL)
        gtk_widget_remove_tick_callback(
            context->area, context->output_present_source);
    else
        g_source_remove(context->output_present_source);
    context->output_present_source = 0;
    context->output_present_is_tick = 0;
}

static void stop_grid_io_sources(NocttyGridContext *context) {
    remove_grid_source(&context->tick_source);
    remove_grid_source(&context->pty_source);
    remove_grid_source(&context->write_flush_source);
    remove_output_present(context);
    remove_grid_source(&context->synchronized_output_source);
    context->synchronized_output_pending = 0;
}

static void stop_grid_io_after_exit(NocttyGridContext *context) {
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

static void stop_grid_context_sources(NocttyGridContext *context) {
    NocttyGridContext *root = root_grid_context(context);
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

static void schedule_output_present(NocttyGridContext *context) {
    if (!grid_context_session_available(context) || context->exited ||
        context->output_present_source != 0) return;
    if (context->area != NULL && gtk_widget_get_mapped(context->area)) {
        context->output_present_is_tick = 1;
        context->output_present_source = gtk_widget_add_tick_callback(
            context->area, on_output_frame, context, NULL);
        if (context->output_present_source != 0) return;
        context->output_present_is_tick = 0;
    }
    context->output_present_source = g_timeout_add_full(
        G_PRIORITY_DEFAULT, 100, on_output_present, context, NULL);
}

static gboolean on_pty_ready(gint fd, GIOCondition condition,
                             gpointer user_data) {
    NocttyGridContext *context = user_data;
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
    (void)noctty_grid_close_transport(context->userdata);
    context->pty_fd = -2;
    context->last_exit_poll_us = 0;
    schedule_output_present(context);
    return G_SOURCE_REMOVE;
}

static gboolean on_output_present(gpointer user_data) {
    NocttyGridContext *context = user_data;
    context->output_present_source = 0;
    context->output_present_is_tick = 0;
    context->timeout_presentations++;
#if NOCTTY_ENABLE_SMOKE
    NocttyGridContext *root = root_grid_context(context);
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
    NocttyGridContext *context = user_data;
    context->output_present_source = 0;
    context->output_present_is_tick = 0;
    context->frame_presentations++;
#if NOCTTY_ENABLE_SMOKE
    NocttyGridContext *root = root_grid_context(context);
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
    NocttyGridContext *context = user_data;
#if NOCTTY_ENABLE_SMOKE
    NocttyGridContext *root = root_grid_context(context);
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
    NocttyGridContext *root = root_grid_context(user_data);
#if NOCTTY_ENABLE_SMOKE
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
    NocttyGridContext *context = focused_grid_context(root);
    if (!grid_context_session_available(context) || context->exited ||
        context->area == NULL || !gtk_widget_get_mapped(context->area))
        return G_SOURCE_CONTINUE;
    context->cursor_visible = !context->cursor_visible;
    queue_grid_cursor_cell(context, context->cursor(context->userdata));
    return G_SOURCE_CONTINUE;
}

static gboolean on_grid_maintenance(gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
#if NOCTTY_ENABLE_SMOKE
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
    NocttyGridContext *active = NULL;
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        NocttyGridContext *candidate = g_ptr_array_index(root->contexts, index);
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
            idle_history_steps < NOCTTY_IDLE_HISTORY_STEPS_PER_TICK) {
            gint64 idle_threshold_us = candidate->focused
                ? NOCTTY_IDLE_HISTORY_FOCUSED_US
                : NOCTTY_IDLE_HISTORY_BACKGROUND_US;
            if (now_us - candidate->last_output_us >= idle_threshold_us) {
                int compacted = noctty_grid_compact_idle_history(
                    candidate->userdata);
                idle_history_steps++;
                if (compacted != 0) {
                    candidate->idle_history_compacted = 1;
                    if (compacted > 1) idle_history_released = TRUE;
                    if (compacted > 1 && candidate->event != NULL)
                        candidate->event(
                            candidate->event_data, candidate->pane_id,
                            NOCTTY_EVENT_IDLE_HISTORY_COMPACTED, 0, now_ms);
                }
            }
        }
        if (active == NULL) active = candidate;
        if (candidate->event != NULL)
            candidate->event(candidate->event_data, candidate->pane_id, 4, 0,
                             now_ms);
    }
    /* History slabs use libc; trim only after a bounded completion wave. */
    if (idle_history_released) (void)malloc_trim(0);
    if (active != NULL && root->event != NULL) {
        gboolean project_visible = root->project_dialog != NULL &&
            gtk_widget_get_mapped(root->project_dialog);
        root->event(root->event_data, active->pane_id, 19,
                    project_visible || root->workspace_smoke == 34,
                    now_ms);
    }
    refresh_active_pane_info(root);
    return G_SOURCE_CONTINUE;
}

static void start_grid_context(NocttyGridContext *context) {
    if (context == NULL || context->userdata == NULL) return;
    context->retiring = 0;
    context->active = 1;
    context->last_output_us = g_get_monotonic_time();
    context->idle_history_compacted = 0;
    if (context->event != NULL) context->event(context->event_data, context->pane_id, 1, 0, (uint64_t)(g_get_monotonic_time() / 1000));
    context->pty_fd = noctty_grid_pty_fd(context->userdata);
    if (context->pty_fd >= 0) {
        (void)register_grid_pty(context);
    }
    if (context->pty_source != 0) {
        context->pty_event_source_started = 1;
        context->descriptor_tick_coalesced = 1;
    } else {
        context->pty_fd = -1;
        context->descriptor_tick_coalesced = 0;
        context->tick_source = g_timeout_add(16, on_tick, context);
    }
    NocttyGridContext *root = root_grid_context(context);
    if (root->cursor_blink_source == 0)
        root->cursor_blink_source = g_timeout_add(500, on_cursor_blink, root);
    if (root->maintenance_source == 0)
        root->maintenance_source = g_timeout_add_seconds(
            1, on_grid_maintenance, root);
}

static void connect_grid_area(NocttyGridContext *context);

static void inherit_grid_session_context(NocttyGridContext *created,
                                         NocttyGridContext *source) {
    NocttyGridContext *root = root_grid_context(source);
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
    created->cell = root->cell;
    created->row = root->row;
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
    created->high_contrast = source->high_contrast;
    created->profile_preset = source->profile_preset;
}

static NocttyGridContext *create_grid_context_for_session(
    NocttyGridContext *source, void *userdata, uint64_t pane_id) {
    NocttyGridContext *created = g_new0(NocttyGridContext, 1);
    inherit_grid_session_context(created, source);
    created->area = noctty_terminal_area_new();
    int spacing_leading = created->pane_spacing_px / 2;
    int spacing_trailing = created->pane_spacing_px - spacing_leading;
    gtk_widget_set_margin_start(created->area, spacing_leading);
    gtk_widget_set_margin_top(created->area, spacing_leading);
    gtk_widget_set_margin_end(created->area, spacing_trailing);
    gtk_widget_set_margin_bottom(created->area, spacing_trailing);
    created->im_context = gtk_im_multicontext_new();
    created->font_family = g_strdup(source->font_family != NULL
                                        ? source->font_family
                                        : "monospace");
    created->userdata = userdata;
    created->pane_id = pane_id;
    created->profile_preset = -1;
    (void)sync_grid_context_profile(created);
    created->cursor_visible = 1;
    created->last_cursor_position = UINT32_MAX;
    created->last_bell_serial = noctty_grid_bell_serial(userdata);
    created->last_notification_serial =
        noctty_grid_notification_serial(userdata);
    created->pty_fd = -1;
    created->heap_allocated = 1;

    g_ptr_array_add(source->contexts, created);
    connect_grid_area(created);
    update_status_tooltip(created, "starting");
    return created;
}

static NocttyGridContext *create_grid_context(NocttyGridContext *source,
                                               int event_code) {
    if (source->create_session == NULL) return NULL;
    uint64_t pane_id = 0;
    void *userdata = source->create_session(
        source->event_data, source->pane_id, event_code,
        MAX(source->columns, 2), MAX(source->rows, 2), &pane_id);
    if (userdata == NULL || pane_id == 0) return NULL;
    return create_grid_context_for_session(source, userdata, pane_id);
}

static NocttyGridContext *restore_grid_context(
    NocttyGridContext *source, uint64_t pane_id,
    int columns, int rows) {
    if (source->create_session == NULL || pane_id == 0) return NULL;
    uint64_t restored_pane_id = 0;
    void *userdata = source->create_session(
        source->event_data, pane_id, 99,
        MAX(columns, 2), MAX(rows, 2), &restored_pane_id);
    if (userdata == NULL || restored_pane_id != pane_id) return NULL;
    return create_grid_context_for_session(source, userdata, pane_id);
}

static GtkWidget *pane_info_strip_for_page(GtkWidget *page) {
    if (!GTK_IS_WIDGET(page)) return NULL;
    return g_object_get_data(G_OBJECT(page), "noctty-pane-info-strip");
}

static GtkWidget *create_grid_page(NocttyGridContext *context) {
    NocttyGridContext *root = root_grid_context(context);
    GtkWidget *page = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
    gtk_container_set_border_width(GTK_CONTAINER(page),
                                   (guint)root->panel_padding_px);
    g_object_set_data(G_OBJECT(page), "noctty-pane-info-strip",
                      root->pane_info_strip);
    return page;
}

static GtkWidget *grid_page_content_root(NocttyGridContext *context,
                                         GtkWidget *page) {
    if (!GTK_IS_CONTAINER(page)) return NULL;
    NocttyGridContext *root = root_grid_context(context);
    GtkWidget *strip = pane_info_strip_for_page(page);
    GList *children = gtk_container_get_children(GTK_CONTAINER(page));
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

static void refresh_active_pane_info(NocttyGridContext *context) {
    NocttyGridContext *root = root_grid_context(context);
    if (root->notebook == NULL) return;
    gint page_index = gtk_notebook_get_current_page(GTK_NOTEBOOK(root->notebook));
    GtkWidget *page = gtk_notebook_get_nth_page(
        GTK_NOTEBOOK(root->notebook), page_index);
    GtkWidget *strip = pane_info_strip_for_page(page);
    if (strip == NULL) return;
    noctty_pane_info_strip_set_enabled(strip, root->show_pane_info);
    if (!root->show_pane_info) return;

    NocttyGridContext *active = focused_grid_context(root);
    if (!grid_context_session_available(active) || active->page != page)
        active = active_grid_context(root);
    if (!grid_context_session_available(active) || active->page != page)
        return;

    char display[512] = {0};
    char tooltip[4608] = {0};
    if (noctty_grid_pane_info(active->userdata, root->event_data,
                              active->pane_id, display, sizeof(display),
                              tooltip, sizeof(tooltip)) <= 0)
        return;
    (void)noctty_pane_info_strip_update(strip, display, tooltip);
}

static gboolean add_grid_tab(NocttyGridContext *source, NocttyGridContext *created) {
    if (source->notebook == NULL) return FALSE;
    NocttyGridContext *root = root_grid_context(source);
    if (root->zoomed_pane_id != 0) restore_zoomed_page(root);
    GtkWidget *page = create_grid_page(source);
    created->page = page;
    gtk_box_pack_start(GTK_BOX(page), created->area, TRUE, TRUE, 0);
    gchar *label_text = g_strdup_printf("Tab %u",
                                        gtk_notebook_get_n_pages(GTK_NOTEBOOK(source->notebook)) + 1);
    GtkWidget *tab_widget = create_compact_tab_widget(source, page, label_text);
    GtkWidget *tab_label = tab_label_from_widget(tab_widget);
    created->tab_label = tab_label;
    gint page_index = gtk_notebook_append_page(GTK_NOTEBOOK(source->notebook), page,
                                               tab_widget);
    gtk_notebook_set_tab_reorderable(GTK_NOTEBOOK(source->notebook), page, TRUE);
    gtk_notebook_set_tab_detachable(GTK_NOTEBOOK(source->notebook), page, FALSE);
    g_free(label_text);
    gtk_widget_show_all(page);
    show_all_with_action_affordances(tab_widget);
    gtk_notebook_set_current_page(GTK_NOTEBOOK(source->notebook), page_index);
    update_compact_tab(created);
    update_notebook_chrome(source);
    return TRUE;
}

static gboolean split_grid_context(NocttyGridContext *source, NocttyGridContext *created,
                                   int event_code) {
    NocttyGridContext *root = root_grid_context(source);
    if (root->zoomed_pane_id != 0) restore_zoomed_page(root);
    GtkWidget *parent = gtk_widget_get_parent(source->area);
    if (parent == NULL) return FALSE;
    created->page = source->page;
    created->tab_label = source->tab_label;
    GtkAllocation source_allocation;
    gtk_widget_get_allocation(source->area, &source_allocation);

    gboolean parent_is_paned = GTK_IS_PANED(parent);
    gboolean source_was_first = parent_is_paned &&
        gtk_paned_get_child1(GTK_PANED(parent)) == source->area;
    if (!parent_is_paned && !GTK_IS_BOX(parent)) return FALSE;

    GtkOrientation orientation = event_code == 21 || event_code == 28
        ? GTK_ORIENTATION_VERTICAL
        : GTK_ORIENTATION_HORIZONTAL;
    GtkWidget *split = gtk_paned_new(orientation);
    noctty_apply_pane_divider_style(split, root->pane_divider_px);
    g_object_ref(source->area);
    gtk_container_remove(GTK_CONTAINER(parent), source->area);
    if (parent_is_paned) {
        if (source_was_first) gtk_paned_pack1(GTK_PANED(parent), split, TRUE, FALSE);
        else gtk_paned_pack2(GTK_PANED(parent), split, TRUE, FALSE);
    } else {
        gtk_box_pack_start(GTK_BOX(parent), split, TRUE, TRUE, 0);
    }

    if (event_code == 22 || event_code == 28) {
        gtk_paned_pack1(GTK_PANED(split), created->area, TRUE, FALSE);
        gtk_paned_pack2(GTK_PANED(split), source->area, TRUE, FALSE);
    } else {
        gtk_paned_pack1(GTK_PANED(split), source->area, TRUE, FALSE);
        gtk_paned_pack2(GTK_PANED(split), created->area, TRUE, FALSE);
    }
    g_object_unref(source->area);
    gtk_widget_show_all(split);
    gtk_widget_queue_resize(parent);
    gint midpoint = orientation == GTK_ORIENTATION_VERTICAL
        ? source_allocation.height / 2
        : source_allocation.width / 2;
    if (midpoint > 0) gtk_paned_set_position(GTK_PANED(split), midpoint);
    if (source->event != NULL) {
        int rendered_event = event_code == 21 ? 58
            : event_code == 22 ? 59
            : event_code == 27 ? 68 : 69;
        source->event(source->event_data, created->pane_id,
                      rendered_event, 0,
                      (uint64_t)(g_get_monotonic_time() / 1000));
    }
    schedule_even_pane_distribution(
        source, grid_page_content_root(source, source->page));
    return TRUE;
}

static guint grid_contexts_on_page(NocttyGridContext *context, GtkWidget *page) {
    guint count = 0;
    for (guint index = 0; context->contexts != NULL &&
         index < context->contexts->len; index++) {
        NocttyGridContext *candidate =
            g_ptr_array_index(context->contexts, index);
        if (candidate->active && candidate->page == page) count++;
    }
    return count;
}

static NocttyGridContext *grid_context_for_pane(NocttyGridContext *context,
                                                uint64_t pane_id) {
    NocttyGridContext *fallback = NULL;
    for (guint index = 0; context->contexts != NULL &&
         index < context->contexts->len; index++) {
        NocttyGridContext *candidate =
            g_ptr_array_index(context->contexts, index);
        if (candidate->pane_id != pane_id) continue;
        if (candidate->userdata != NULL && !candidate->retiring &&
            !candidate->exited)
            return candidate;
        fallback = candidate;
    }
    return fallback;
}

static gboolean flush_grid_layout_hot_session(gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    root->layout_save_source = 0;
    if (!root->control_name_conflict && root->event_data != NULL &&
        noctty_grid_flush_hot_session(root->event_data) != 0)
        show_status_feedback(
            root, "Could not save the workspace recovery snapshot.");
    return G_SOURCE_REMOVE;
}

static void schedule_grid_hot_session_flush(NocttyGridContext *context) {
    NocttyGridContext *root = root_grid_context(context);
    if (root->layout_save_source != 0)
        g_source_remove(root->layout_save_source);
    root->layout_save_source = g_timeout_add(
        120, flush_grid_layout_hot_session, root);
}

static void on_grid_layout_position_changed(
    GObject *object, GParamSpec *parameter, gpointer user_data) {
    (void)parameter;
    if (!GTK_IS_PANED(object)) return;
    NocttyGridContext *root = root_grid_context(user_data);
    int tab_index = GPOINTER_TO_INT(g_object_get_data(
        object, "noctty-layout-tab-index")) - 1;
    int node_index = GPOINTER_TO_INT(g_object_get_data(
        object, "noctty-layout-node-index")) - 1;
    gint max_position = 0;
    g_object_get(object, "max-position", &max_position, NULL);
    if (root->event_data == NULL || tab_index < 0 || node_index < 0 ||
        max_position <= 0 || max_position >= G_MAXINT / 2 ||
        root->layout_restore_applying)
        return;
    int position = gtk_paned_get_position(GTK_PANED(object));
    int ratio_permille = noctty_grid_split_ratio(position, max_position);
    g_object_set_data(G_OBJECT(object), "noctty-preset-ratio",
                      GUINT_TO_POINTER((guint)ratio_permille));
    if (noctty_grid_set_layout_ratio(
            root->event_data, tab_index, node_index,
            ratio_permille) != 0)
        return;
    schedule_grid_hot_session_flush(root);
}

static gboolean on_grid_layout_button_release(
    GtkWidget *widget, GdkEventButton *event, gpointer user_data) {
    (void)user_data;
    if (event->type != GDK_BUTTON_RELEASE || event->button != 1 ||
        !GTK_IS_PANED(widget))
        return FALSE;
    gint max_position = 0;
    g_object_get(G_OBJECT(widget), "max-position", &max_position, NULL);
    if (max_position <= 0 || max_position >= G_MAXINT / 2) return FALSE;
    int position = gtk_paned_get_position(GTK_PANED(widget));
    int snapped_position = noctty_grid_snap_pane_position(
        max_position, position);
    if (snapped_position >= 0)
        gtk_paned_set_position(GTK_PANED(widget), snapped_position);
    return FALSE;
}

static gboolean bind_grid_layout_node(
    NocttyGridContext *root, GtkWidget *widget, int tab_index,
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
    if (noctty_grid_restore_layout_node(
            root->event_data, tab_index, node_index, &kind, &pane_id,
            &axis, &first, &second, &ratio_permille) != 0)
        return FALSE;
    if (kind == 0) {
        NocttyGridContext *pane = grid_context_for_pane(root, pane_id);
        return pane != NULL && pane->area == widget;
    }
    if (kind != 1 || !GTK_IS_PANED(widget) || first < 0 || second < 0)
        return FALSE;
    GtkOrientation orientation = gtk_orientable_get_orientation(
        GTK_ORIENTABLE(widget));
    if ((axis == 0 && orientation != GTK_ORIENTATION_HORIZONTAL) ||
        (axis == 1 && orientation != GTK_ORIENTATION_VERTICAL))
        return FALSE;
    g_object_set_data(G_OBJECT(widget), "noctty-layout-tab-index",
                      GINT_TO_POINTER(tab_index + 1));
    g_object_set_data(G_OBJECT(widget), "noctty-layout-node-index",
                      GINT_TO_POINTER(node_index + 1));
    if (g_object_get_data(G_OBJECT(widget),
                          "noctty-layout-position-bound") == NULL) {
        g_signal_connect(widget, "notify::position",
                         G_CALLBACK(on_grid_layout_position_changed), root);
        g_object_set_data(G_OBJECT(widget),
                          "noctty-layout-position-bound",
                          GINT_TO_POINTER(1));
    }
    if (g_object_get_data(G_OBJECT(widget), "noctty-layout-snap-bound") == NULL) {
        gtk_widget_add_events(widget, GDK_BUTTON_RELEASE_MASK);
        g_signal_connect(widget, "button-release-event",
                         G_CALLBACK(on_grid_layout_button_release), root);
        g_object_set_data(G_OBJECT(widget), "noctty-layout-snap-bound",
                          GINT_TO_POINTER(1));
    }
    return bind_grid_layout_node(
               root, gtk_paned_get_child1(GTK_PANED(widget)),
               tab_index, first, node_count, depth + 1) &&
        bind_grid_layout_node(
               root, gtk_paned_get_child2(GTK_PANED(widget)),
               tab_index, second, node_count, depth + 1);
}

static gboolean bind_grid_layout_for_page(NocttyGridContext *context) {
    if (context == NULL) return FALSE;
    NocttyGridContext *root = root_grid_context(context);
    if (root->event_data == NULL || !GTK_IS_BOX(context->page))
        return FALSE;
    NocttyGridContext *representative = grid_context_for_page(
        root, context->page);
    if (representative == NULL) return FALSE;
    int tab_index = noctty_grid_restore_tab_index_for_pane(
        root->event_data, representative->pane_id);
    int pane_count = 0;
    int node_count = 0;
    int root_node = -1;
    uint64_t active_pane_id = 0;
    if (tab_index < 0 || noctty_grid_restore_tab_info(
            root->event_data, tab_index, &pane_count, &active_pane_id,
            &node_count, &root_node) != 0)
        return FALSE;
    GtkWidget *layout = grid_page_content_root(context, context->page);
    return bind_grid_layout_node(
        root, layout, tab_index, root_node, node_count, 0);
}

static GtkWidget *build_hot_session_layout_node(
    NocttyGridContext *root, int tab_index, int node_index,
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
    if (noctty_grid_restore_layout_node(
            root->event_data, tab_index, node_index, &kind, &pane_id,
            &axis, &first, &second, &ratio_permille) != 0)
        return NULL;
    if (kind == 0) {
        NocttyGridContext *pane = grid_context_for_pane(root, pane_id);
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
    GtkWidget *split = gtk_paned_new(
        axis == 0 ? GTK_ORIENTATION_HORIZONTAL : GTK_ORIENTATION_VERTICAL);
    noctty_apply_pane_divider_style(split, root->pane_divider_px);
    gtk_paned_pack1(GTK_PANED(split), first_widget, TRUE, FALSE);
    gtk_paned_pack2(GTK_PANED(split), second_widget, TRUE, FALSE);
    g_object_set_data(G_OBJECT(split), "noctty-preset-ratio",
                      GUINT_TO_POINTER((guint)ratio_permille));
    g_object_set_data(G_OBJECT(split), "noctty-layout-tab-index",
                      GINT_TO_POINTER(tab_index + 1));
    g_object_set_data(G_OBJECT(split), "noctty-layout-node-index",
                      GINT_TO_POINTER(node_index + 1));
    g_signal_connect(split, "notify::position",
                     G_CALLBACK(on_grid_layout_position_changed), root);
    gtk_widget_add_events(split, GDK_BUTTON_RELEASE_MASK);
    g_signal_connect(split, "button-release-event",
                     G_CALLBACK(on_grid_layout_button_release), root);
    g_object_set_data(G_OBJECT(split), "noctty-layout-position-bound",
                      GINT_TO_POINTER(1));
    g_object_set_data(G_OBJECT(split), "noctty-layout-snap-bound",
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
    NocttyGridContext *root, int tab_index, GtkWidget *page,
    int node_count, int root_node) {
    if (root == NULL || !GTK_IS_BOX(page)) return FALSE;
    GPtrArray *held_areas = g_ptr_array_new();
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        NocttyGridContext *candidate =
            g_ptr_array_index(root->contexts, index);
        if (candidate->page == page && candidate->area != NULL &&
            gtk_widget_get_parent(candidate->area) != NULL) {
            g_object_ref(candidate->area);
            g_ptr_array_add(held_areas, candidate->area);
        }
    }
    GtkWidget *strip = pane_info_strip_for_page(page);
    GList *children = gtk_container_get_children(GTK_CONTAINER(page));
    for (GList *item = children; item != NULL; item = item->next) {
        GtkWidget *child = GTK_WIDGET(item->data);
        if (child != strip)
            gtk_container_remove(GTK_CONTAINER(page), child);
    }
    g_list_free(children);

    GtkWidget *layout = build_hot_session_layout_node(
        root, tab_index, root_node, node_count, page, 0);
    if (layout != NULL) {
        gtk_box_pack_start(GTK_BOX(page), layout, TRUE, TRUE, 0);
        g_signal_connect(layout, "size-allocate",
                         G_CALLBACK(on_restored_layout_size_allocate), NULL);
    }
    for (guint index = 0; index < held_areas->len; index++)
        g_object_unref(g_ptr_array_index(held_areas, index));
    g_ptr_array_free(held_areas, TRUE);
    return layout != NULL;
}

static gboolean restore_hot_session(NocttyGridContext *root) {
    if (root == NULL || root->event_data == NULL ||
        root->create_session == NULL ||
        noctty_grid_hot_session_loaded(root->event_data) == 0)
        return FALSE;
    int tab_count = noctty_grid_restore_tab_count(root->event_data);
    int active_tab = noctty_grid_restore_active_tab(root->event_data);
    int root_tab = noctty_grid_restore_tab_index_for_pane(
        root->event_data, root->pane_id);
    if (tab_count <= 0 || tab_count > 512 || active_tab < 0 ||
        active_tab >= tab_count || root_tab != active_tab)
        return FALSE;

    GtkWidget **pages = g_new0(GtkWidget *, (gsize)tab_count);
    pages[root_tab] = root->page;
    for (int tab_index = 0; tab_index < tab_count; tab_index++) {
        if (tab_index == root_tab) continue;
        GtkWidget *page = create_grid_page(root);
        gchar *placeholder = g_strdup_printf("Tab %d", tab_index + 1);
        GtkWidget *tab_widget = create_compact_tab_widget(
            root, page, placeholder);
        g_free(placeholder);
        gtk_notebook_append_page(GTK_NOTEBOOK(root->notebook), page,
                                 tab_widget);
        gtk_notebook_set_tab_reorderable(GTK_NOTEBOOK(root->notebook),
                                         page, TRUE);
        gtk_notebook_set_tab_detachable(GTK_NOTEBOOK(root->notebook),
                                        page, FALSE);
        pages[tab_index] = page;
    }
    if (root_tab != 0)
        gtk_notebook_reorder_child(GTK_NOTEBOOK(root->notebook),
                                   root->page, root_tab);

    int pane_total = 0;
    gboolean layout_ready = TRUE;
    uint64_t active_pane_id = 0;
    for (int tab_index = 0; tab_index < tab_count; tab_index++) {
        int pane_count = 0;
        int node_count = 0;
        int root_node = -1;
        uint64_t tab_active_pane_id = 0;
        if (noctty_grid_restore_tab_info(
                root->event_data, tab_index, &pane_count,
                &tab_active_pane_id, &node_count, &root_node) != 0 ||
            pane_count <= 0 || pane_count > 512 || node_count <= 0 ||
            node_count > 1023 || root_node < 0 || root_node >= node_count) {
            layout_ready = FALSE;
            break;
        }
        if (tab_index == active_tab) active_pane_id = tab_active_pane_id;
        GtkWidget *page = pages[tab_index];
        GtkWidget *tab_widget = gtk_notebook_get_tab_label(
            GTK_NOTEBOOK(root->notebook), page);
        GtkWidget *tab_label = tab_label_from_widget(tab_widget);
        for (int pane_index = 0; pane_index < pane_count; pane_index++) {
            uint64_t pane_id = 0;
            if (noctty_grid_restore_pane_id(
                    root->event_data, tab_index, pane_index, &pane_id) != 0 ||
                pane_id == 0) {
                layout_ready = FALSE;
                break;
            }
            NocttyGridContext *pane_context = NULL;
            if (pane_id == root->pane_id) {
                pane_context = root;
            } else {
                uint64_t restored_pane_id = 0;
                void *userdata = root->create_session(
                    root->event_data, pane_id, 99,
                    MAX(root->columns, 2), MAX(root->rows, 2),
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
        gtk_notebook_set_current_page(GTK_NOTEBOOK(root->notebook), active_tab);
        NocttyGridContext *active = grid_context_for_pane(
            root, active_pane_id);
        root->hot_session_active_ready = active != NULL &&
            active->page == pages[active_tab];
        if (root->hot_session_active_ready) {
            for (guint index = 0; index < root->contexts->len; index++) {
                NocttyGridContext *candidate =
                    g_ptr_array_index(root->contexts, index);
                candidate->focused = candidate == active;
            }
            gtk_widget_grab_focus(active->area);
        }
        char smart_filter[1024] = {0};
        int smart_filter_length = noctty_grid_smart_filter_tag(
            root->event_data, smart_filter, sizeof(smart_filter) - 1);
        if (smart_filter_length >= 0 &&
            (size_t)smart_filter_length < sizeof(smart_filter)) {
            smart_filter[smart_filter_length] = '\0';
            g_clear_pointer(&root->smart_filter_tag, g_free);
            root->smart_filter_tag = smart_filter_length > 0
                ? g_strdup(smart_filter) : NULL;
            root->hot_session_smart_filter_ready = 1;
        }
    }
    g_free(pages);
    return layout_ready;
}

static NocttyGridContext *grid_context_on_other_page(NocttyGridContext *source) {
    for (guint index = 0; source->contexts != NULL &&
         index < source->contexts->len; index++) {
        NocttyGridContext *candidate =
            g_ptr_array_index(source->contexts, index);
        if (candidate->active && candidate->page != source->page) return candidate;
    }
    return NULL;
}

static gboolean replace_grid_widget(GtkWidget *parent, GtkWidget *old_widget,
                                    GtkWidget *replacement) {
    if (GTK_IS_PANED(parent)) {
        gboolean was_first =
            gtk_paned_get_child1(GTK_PANED(parent)) == old_widget;
        gtk_container_remove(GTK_CONTAINER(parent), old_widget);
        if (was_first) {
            gtk_paned_pack1(GTK_PANED(parent), replacement, TRUE, FALSE);
        } else {
            gtk_paned_pack2(GTK_PANED(parent), replacement, TRUE, FALSE);
        }
        return TRUE;
    }
    if (GTK_IS_BOX(parent)) {
        gtk_container_remove(GTK_CONTAINER(parent), old_widget);
        gtk_box_pack_start(GTK_BOX(parent), replacement, TRUE, TRUE, 0);
        return TRUE;
    }
    return FALSE;
}

static gboolean detach_grid_context(NocttyGridContext *source) {
    if (source->page == NULL) return FALSE;
    if (grid_contexts_on_page(source, source->page) == 1) {
        gint page_index =
            gtk_notebook_page_num(GTK_NOTEBOOK(source->notebook), source->page);
        if (page_index < 0) return FALSE;
        g_object_ref(source->area);
        gtk_notebook_remove_page(GTK_NOTEBOOK(source->notebook), page_index);
        update_notebook_chrome(source);
        return TRUE;
    }
    GtkWidget *split = gtk_widget_get_parent(source->area);
    if (!GTK_IS_PANED(split)) return FALSE;
    GtkWidget *first = gtk_paned_get_child1(GTK_PANED(split));
    GtkWidget *second = gtk_paned_get_child2(GTK_PANED(split));
    GtkWidget *sibling = first == source->area ? second : first;
    GtkWidget *grandparent = gtk_widget_get_parent(split);
    if (sibling == NULL || grandparent == NULL ||
        (!GTK_IS_PANED(grandparent) && !GTK_IS_BOX(grandparent))) return FALSE;

    g_object_ref(source->area);
    g_object_ref(sibling);
    gtk_container_remove(GTK_CONTAINER(split), source->area);
    gtk_container_remove(GTK_CONTAINER(split), sibling);
    gboolean replaced = replace_grid_widget(grandparent, split, sibling);
    g_object_unref(sibling);
    if (!replaced) {
        g_object_unref(source->area);
        return FALSE;
    }
    return TRUE;
}

typedef struct {
    NocttyGridContext *root;
    GtkWidget *layout;
    guint source_id;
    gulong layout_destroy_handler_id;
    guint attempts_remaining;
    gboolean resize_ratios_bound;
    gboolean layout_destroyed;
} NocttyEvenPaneRequest;

static void destroy_even_pane_request(gpointer user_data) {
    NocttyEvenPaneRequest *request = user_data;
    if (!request->layout_destroyed &&
        request->layout_destroy_handler_id != 0) {
        g_signal_handler_disconnect(request->layout,
                                    request->layout_destroy_handler_id);
    }
    g_object_unref(request->layout);
    g_free(request);
}

static void stop_even_pane_distribution_on_layout_destroy(
    GtkWidget *layout, gpointer user_data) {
    (void)layout;
    NocttyEvenPaneRequest *request = user_data;
    request->layout_destroyed = TRUE;
    request->root->compact_even_distribution_cancelled = TRUE;
    request->layout_destroy_handler_id = 0;
    guint source_id = request->source_id;
    request->source_id = 0;
    if (source_id != 0) g_source_remove(source_id);
}

static gboolean apply_even_pane_distribution(gpointer user_data) {
    NocttyEvenPaneRequest *request = user_data;
    if (gtk_widget_in_destruction(request->layout) ||
        gtk_widget_get_parent(request->layout) == NULL)
        return G_SOURCE_REMOVE;
    (void)noctty_apply_even_pane_positions(request->layout);
    if (!request->resize_ratios_bound) {
        bind_preset_max_positions(request->root, request->layout);
        request->resize_ratios_bound = TRUE;
    }
    gtk_widget_queue_resize(request->layout);
    gtk_widget_queue_draw(request->layout);
    g_assert(request->attempts_remaining > 0);
    request->attempts_remaining--;
    return request->attempts_remaining == 0
        ? G_SOURCE_REMOVE : G_SOURCE_CONTINUE;
}

static void schedule_even_pane_distribution(NocttyGridContext *context,
                                            GtkWidget *layout) {
    if (context == NULL || layout == NULL) return;
    NocttyEvenPaneRequest *request = g_new0(NocttyEvenPaneRequest, 1);
    request->root = root_grid_context(context);
    request->layout = g_object_ref(layout);
    request->attempts_remaining = 4;
    /* GTK can report provisional allocations for several frames after a split
     * tree is mapped. Retry briefly, but bind cancellation to widget teardown
     * so an early tab/window close cannot leave a source holding the layout. */
    request->layout_destroy_handler_id = g_signal_connect(
        layout, "destroy",
        G_CALLBACK(stop_even_pane_distribution_on_layout_destroy), request);
    request->source_id = g_timeout_add_full(
        G_PRIORITY_LOW, 16, apply_even_pane_distribution,
        request, destroy_even_pane_request);
    if (request->source_id == 0) destroy_even_pane_request(request);
}

static gboolean attach_grid_context(NocttyGridContext *source,
                                    NocttyGridContext *target) {
    if (target->page == NULL) return FALSE;
    GtkWidget *content_root = grid_page_content_root(target, target->page);
    if (content_root == NULL) {
        gtk_box_pack_start(GTK_BOX(target->page), source->area, TRUE, TRUE, 0);
    } else {
        GtkAllocation allocation;
        gtk_widget_get_allocation(target->page, &allocation);
        g_object_ref(content_root);
        gtk_container_remove(GTK_CONTAINER(target->page), content_root);
        GtkWidget *split = gtk_paned_new(GTK_ORIENTATION_HORIZONTAL);
        noctty_apply_pane_divider_style(
            split, root_grid_context(target)->pane_divider_px);
        gtk_paned_pack1(GTK_PANED(split), content_root, TRUE, FALSE);
        gtk_paned_pack2(GTK_PANED(split), source->area, TRUE, FALSE);
        gtk_box_pack_start(GTK_BOX(target->page), split, TRUE, TRUE, 0);
        g_object_unref(content_root);
        gtk_widget_show_all(split);
        if (allocation.width > 0) {
            gtk_paned_set_position(GTK_PANED(split), allocation.width / 2);
        }
    }
    g_object_unref(source->area);
    source->page = target->page;
    source->tab_label = target->tab_label;
    source->pane_move_applied = 1;
    target->pane_move_applied = 1;
    gint page_index = gtk_notebook_page_num(GTK_NOTEBOOK(source->notebook),
                                            target->page);
    if (page_index >= 0) {
        gtk_notebook_set_current_page(GTK_NOTEBOOK(source->notebook), page_index);
    }
    gtk_widget_show_all(target->page);
    apply_smart_filter(root_grid_context(target));
    update_compact_tab(target);
    gtk_widget_grab_focus(source->area);
    if (source->event != NULL) {
        source->event(source->event_data, source->pane_id, 62, 0,
                      (uint64_t)(g_get_monotonic_time() / 1000));
    }
    (void)bind_grid_layout_for_page(source);
    schedule_even_pane_distribution(
        source, grid_page_content_root(source, source->page));
    return TRUE;
}

static gboolean move_grid_context(NocttyGridContext *source,
                                  NocttyGridContext *target) {
    if (source == NULL || target == NULL || source == target ||
        source->page == target->page) return FALSE;
    NocttyGridContext *root = root_grid_context(source);
    if (root->zoomed_pane_id != 0) restore_zoomed_page(root);
    if (!detach_grid_context(source)) return FALSE;
    return attach_grid_context(source, target);
}

static void restore_zoomed_page(NocttyGridContext *root) {
    if (root->zoomed_pane_id == 0) return;
    NocttyGridContext *zoomed = grid_context_for_pane(root, root->zoomed_pane_id);
    GtkWidget *page = zoomed != NULL ? zoomed->page : NULL;
    if (page != NULL) gtk_widget_show_all(page);
    for (guint index = 0; root->contexts != NULL && index < root->contexts->len; index++) {
        NocttyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (candidate->page != page) continue;
        gboolean visible = candidate->active &&
            (root->smart_filter_tag == NULL ||
             noctty_grid_pane_matches_smart_filter(
                 root->event_data, candidate->pane_id) != 0);
        gtk_widget_set_visible(candidate->area, visible);
    }
    if (page != NULL) sync_grid_page_branch_visibility(root, page);
    root->zoomed_pane_id = 0;
    update_notebook_chrome(root);
}

static void destroy_retired_grid_context(NocttyGridContext *root,
                                         NocttyGridContext *context) {
    if (root == NULL || context == NULL || !context->heap_allocated) return;
    if (context->clipboard_requests != 0) return;
    stop_grid_context_sources(context);
    remove_grid_source(&context->cursor_blink_source);
    remove_grid_source(&context->maintenance_source);
    if (context->settings_dialog != NULL) gtk_widget_destroy(context->settings_dialog);
    if (context->theme_dialog != NULL) gtk_widget_destroy(context->theme_dialog);
    if (context->sharing_dialog != NULL) gtk_widget_destroy(context->sharing_dialog);
    if (context->palette_dialog != NULL) gtk_widget_destroy(context->palette_dialog);
    if (context->find_dialog != NULL) gtk_widget_destroy(context->find_dialog);
    if (context->note_dialog != NULL) gtk_widget_destroy(context->note_dialog);
    if (context->shortcuts_dialog != NULL) gtk_widget_destroy(context->shortcuts_dialog);
    if (context->project_dialog != NULL) gtk_widget_destroy(context->project_dialog);
    if (context->workspace_menu != NULL) gtk_widget_destroy(context->workspace_menu);
    if (context->im_context != NULL) gtk_im_context_focus_out(context->im_context);
    g_clear_pointer(&context->note_overlay_text, g_free);
    g_clear_pointer(&context->note_overlay_label, g_free);
    g_clear_pointer(&context->note_overlay_font, pango_font_description_free);
    g_clear_pointer(&context->status_feedback_text, g_free);
    remove_grid_source(&context->status_feedback_source);
    remove_grid_source(&context->sharing_status_source);
    g_clear_pointer(&context->display_title, g_free);
    g_clear_pointer(&context->font_family, g_free);
    g_clear_pointer(&context->row_cells, g_free);
    g_clear_pointer(&context->dirty_row_buffer, g_free);
    g_clear_pointer(&context->dirty_span_buffer, g_free);
    destroy_grid_glyph_cache(context);
    g_clear_object(&context->im_context);
    g_ptr_array_remove(root->contexts, context);
    g_free(context);
}

static void dispatch_grid_application_close_effects(
    NocttyGridContext *context, NocttyGridCloseTransition transition);

static gboolean dispatch_deferred_grid_application_close(gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    root->application_close_deferred_source = 0;
    dispatch_grid_application_close_effects(
        root, noctty_grid_close_source_fired(
                  &root->application_close, NOCTTY_CLOSE_SOURCE_DEFERRED));
    return G_SOURCE_REMOVE;
}

static gboolean close_grid_application_idle(gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    root->application_close_preflight_source = 0;
    dispatch_grid_application_close_effects(
        root, noctty_grid_close_source_fired(
                  &root->application_close, NOCTTY_CLOSE_SOURCE_PREFLIGHT));
    return G_SOURCE_REMOVE;
}

static void commit_grid_application_close(
    NocttyGridContext *root, NocttyApplicationCloseOrigin origin) {
    remove_grid_source(&root->application_close_deferred_source);
    dismiss_workspace_menu(root);
    remove_grid_source(&root->cursor_blink_source);
    remove_grid_source(&root->maintenance_source);
    guint active_sessions = 0;
    guint stopped_sessions = 0;
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        NocttyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (!candidate->active) continue;
        gboolean already_exited = candidate->exited;
        candidate->retiring = 1;
        if (!already_exited) candidate->active = 0;
        candidate->focused = 0;
        stop_grid_context_sources(candidate);
        if (candidate->im_context != NULL)
            gtk_im_context_focus_out(candidate->im_context);
        active_sessions++;
        int close_status = already_exited
            ? 1 : noctty_grid_close_session(candidate->userdata,
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
        origin == NOCTTY_CLOSE_ORIGIN_TRAY && all_sessions_stopped;
    root->window_close_session_stopped =
        origin == NOCTTY_CLOSE_ORIGIN_TOOLBAR && all_sessions_stopped;
    if (gtk_main_level() > 0) gtk_main_quit();
}

static void dispatch_grid_application_close_effects(
    NocttyGridContext *context, NocttyGridCloseTransition transition) {
    NocttyGridContext *root = root_grid_context(context);
    if ((transition.effects & NOCTTY_CLOSE_EFFECT_CANCEL_DEFERRED) != 0)
        remove_grid_source(&root->application_close_deferred_source);
    if ((transition.effects & NOCTTY_CLOSE_EFFECT_CANCEL_PREFLIGHT) != 0)
        remove_grid_source(&root->application_close_preflight_source);
    if ((transition.effects & NOCTTY_CLOSE_EFFECT_SCHEDULE_DEFERRED) != 0 &&
        root->application_close_deferred_source == 0)
        root->application_close_deferred_source = g_idle_add(
            dispatch_deferred_grid_application_close, root);
    if ((transition.effects & NOCTTY_CLOSE_EFFECT_SCHEDULE_PREFLIGHT) != 0 &&
        root->application_close_preflight_source == 0)
        root->application_close_preflight_source = g_idle_add(
            close_grid_application_idle, root);
    if ((transition.effects & NOCTTY_CLOSE_EFFECT_SCHEDULE_DWELL) != 0 &&
        root->application_close_preflight_source == 0)
        root->application_close_preflight_source = g_timeout_add(
            80, close_grid_application_idle, root);
    if ((transition.effects & NOCTTY_CLOSE_EFFECT_RUN_PREFLIGHT) != 0) {
        gboolean confirmed = confirm_grid_application_close(root);
        dispatch_grid_application_close_effects(
            root, noctty_grid_close_preflight_result(
                      &root->application_close, confirmed));
    }
    if ((transition.effects & NOCTTY_CLOSE_EFFECT_COMMIT) != 0)
        commit_grid_application_close(root, transition.origin);
}

static void begin_grid_modal(NocttyGridContext *context) {
    NocttyGridContext *root = root_grid_context(context);
    dispatch_grid_application_close_effects(
        root, noctty_grid_close_modal_begin(&root->application_close));
}

static void end_grid_modal(NocttyGridContext *context) {
    NocttyGridContext *root = root_grid_context(context);
    dispatch_grid_application_close_effects(
        root, noctty_grid_close_modal_end(&root->application_close));
}

static gint run_grid_modal_dialog(NocttyGridContext *context,
                                  GtkDialog *dialog) {
    (void)configure_overlay_window_stacking(
        context, GTK_WIDGET(dialog), "noctty-dialog");
    begin_grid_modal(context);
    gint response = gtk_dialog_run(dialog);
    end_grid_modal(context);
    return response;
}

static gboolean request_grid_application_close(
    NocttyGridContext *context, NocttyApplicationCloseOrigin origin) {
    NocttyGridContext *root = root_grid_context(context);
    NocttyGridCloseTransition transition =
        noctty_grid_close_request(&root->application_close, origin);
    dispatch_grid_application_close_effects(root, transition);
    return transition.accepted != 0;
}

static guint active_grid_context_count(NocttyGridContext *context) {
    NocttyGridContext *root = root_grid_context(context);
    guint count = 0;
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        NocttyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (candidate->active && !candidate->exited &&
            candidate->area != NULL && candidate->page != NULL) count++;
    }
    return count;
}

static gboolean focus_grid_context_idle(gpointer user_data) {
    NocttyGridContext *context = user_data;
    context->focus_deferred_source = 0;
    if (!grid_context_session_available(context) || context->exited ||
        context->area == NULL || context->page == NULL) return G_SOURCE_REMOVE;
    NocttyGridContext *root = root_grid_context(context);
    gint page_index = gtk_notebook_page_num(GTK_NOTEBOOK(root->notebook),
                                            context->page);
    if (page_index >= 0)
        gtk_notebook_set_current_page(GTK_NOTEBOOK(root->notebook), page_index);
    gtk_widget_grab_focus(context->area);
    return G_SOURCE_REMOVE;
}

static gboolean focus_grid_area_idle(gpointer user_data) {
    GtkWidget *area = GTK_WIDGET(user_data);
    if (!gtk_widget_in_destruction(area) && gtk_widget_get_visible(area))
        gtk_widget_grab_focus(area);
    g_object_unref(area);
    return G_SOURCE_REMOVE;
}

static void defer_grid_context_focus(NocttyGridContext *context) {
    if (context == NULL || context->area == NULL) return;
    /* Let the activating key event finish before the new terminal owns focus. */
    root_grid_context(context)->session_creation_focus_deferred = 1;
    g_idle_add(focus_grid_area_idle, g_object_ref(context->area));
}

static guint foreground_process_count(NocttyGridContext *context,
                                      GtkWidget *page) {
    NocttyGridContext *root = root_grid_context(context);
    guint count = 0;
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        NocttyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (!candidate->active || candidate->exited ||
            candidate->userdata == NULL ||
            (page != NULL && candidate->page != page))
            continue;
        if (noctty_grid_has_foreground_process(candidate->userdata) > 0)
            count++;
    }
    return count;
}

static gboolean accept_dialog_smoke(gpointer user_data) {
    GtkWidget *dialog = user_data;
    if (GTK_IS_DIALOG(dialog))
        gtk_dialog_response(GTK_DIALOG(dialog), GTK_RESPONSE_ACCEPT);
    return G_SOURCE_REMOVE;
}

static gboolean confirm_terminal_process_close(NocttyGridContext *context,
                                               const char *scope,
                                               guint busy_count,
                                               gboolean force_prompt) {
    if (busy_count == 0 && !force_prompt) return TRUE;
    NocttyGridContext *root = root_grid_context(context);
    if (!root->window_presented)
        toggle_grid_window(root);
    else if (!root->layer_shell_active)
        gtk_window_present(GTK_WINDOW(root->window));

    const char *title = g_strcmp0(scope, "application") == 0
        ? "Close NOCTTY?"
        : g_strcmp0(scope, "tab") == 0 ? "Close tab?" : "Close terminal?";
    gchar *detail = busy_count == 0
        ? g_strdup("Closing NOCTTY ends all terminal sessions in this window.")
        : busy_count == 1
            ? g_strdup("A foreground process is still running. Closing will stop it and its child processes.")
            : g_strdup_printf("%u terminals have foreground processes. Closing will stop them and their child processes.",
                              busy_count);
    GtkWidget *dialog = gtk_message_dialog_new(
        GTK_WINDOW(root->window),
        GTK_DIALOG_MODAL | GTK_DIALOG_DESTROY_WITH_PARENT,
        GTK_MESSAGE_WARNING, GTK_BUTTONS_NONE, "%s", title);
    gtk_message_dialog_format_secondary_text(GTK_MESSAGE_DIALOG(dialog),
                                             "%s", detail);
    gtk_dialog_add_buttons(GTK_DIALOG(dialog),
                           "Keep Open", GTK_RESPONSE_CANCEL,
                           "Close Anyway", GTK_RESPONSE_ACCEPT, NULL);
    gtk_dialog_set_default_response(GTK_DIALOG(dialog), GTK_RESPONSE_CANCEL);
    root->terminal_close_prompt_count++;
    root->terminal_close_prompt_busy_count += (int)busy_count;
    (void)configure_overlay_window_stacking(
        root, dialog, "noctty-close-confirmation");
    show_all_with_action_affordances(dialog);
    if (root->workspace_smoke >= 0)
        g_idle_add(accept_dialog_smoke, dialog);
    gint response = run_grid_modal_dialog(root, GTK_DIALOG(dialog));
    gtk_widget_destroy(dialog);
    g_free(detail);
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

static gboolean close_grid_pane(NocttyGridContext *context) {
    NocttyGridContext *root = root_grid_context(context);
    if (context == NULL || !context->active || context->area == NULL ||
        context->page == NULL || root->event_data == NULL ||
        active_grid_context_count(root) <= 1) return FALSE;
    gboolean dogfood_omp_target = context->dogfood_omp_seen;
    guint page_context_count = grid_contexts_on_page(root, context->page);
    gboolean closes_tab = page_context_count == 1;
    if (!closes_tab) {
        GtkWidget *split = gtk_widget_get_parent(context->area);
        if (!GTK_IS_PANED(split)) return FALSE;
        GtkWidget *grandparent = gtk_widget_get_parent(split);
        if (grandparent == NULL ||
            (!GTK_IS_PANED(grandparent) && !GTK_IS_BOX(grandparent)))
            return FALSE;
    }
    if (noctty_grid_has_foreground_process(context->userdata) > 0 &&
        !confirm_terminal_process_close(root, "pane", 1, FALSE))
        return FALSE;

    uint64_t active_pane_id = 0;
    int model_tab_closed = 0;
    if (noctty_grid_close_pane(root->event_data, context->pane_id,
                               &active_pane_id, &model_tab_closed) <= 0 ||
        active_pane_id == 0) return FALSE;
    if (root->zoomed_pane_id != 0) restore_zoomed_page(root);

    stop_grid_context_sources(context);
    context->retiring = 1;
    context->focused = 0;
    if (context->im_context != NULL) gtk_im_context_focus_out(context->im_context);
    int close_status = noctty_grid_close_session(context->userdata,
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
        gint page_index = gtk_notebook_page_num(GTK_NOTEBOOK(root->notebook),
                                                page);
        if (page_index >= 0) {
            gtk_notebook_remove_page(GTK_NOTEBOOK(root->notebook), page_index);
            rendered_closed = TRUE;
        }
    } else if (detach_grid_context(context)) {
        gtk_widget_destroy(area);
        g_object_unref(area);
        rendered_closed = TRUE;
    }

    context->active = 0;
    if (!context->primary) context->exited = 1;
    context->area = NULL;
    context->page = NULL;
    context->tab_label = NULL;
    update_notebook_chrome(root);

    NocttyGridContext *remaining = grid_context_for_pane(root, active_pane_id);
    if (remaining == NULL || !remaining->active || remaining->area == NULL)
        remaining = active_grid_context(root);
    if (rendered_closed && model_tab_closed == 0 && remaining != NULL &&
        remaining->page == page && grid_contexts_on_page(root, page) > 1) {
        gtk_widget_show_all(page);
        gtk_widget_queue_resize(page);
        (void)bind_grid_layout_for_page(remaining);
        schedule_even_pane_distribution(
            remaining, grid_page_content_root(remaining, page));
    }
    if (remaining != NULL && remaining->active && remaining->area != NULL) {
        gint page_index = gtk_notebook_page_num(GTK_NOTEBOOK(root->notebook),
                                                remaining->page);
        if (page_index >= 0)
            gtk_notebook_set_current_page(GTK_NOTEBOOK(root->notebook),
                                          page_index);
        gtk_widget_show_all(remaining->page);
        apply_smart_filter(root);
        update_compact_tab(remaining);
        if (gtk_widget_get_visible(remaining->area))
            gtk_widget_grab_focus(remaining->area);
        remove_grid_source(&remaining->focus_deferred_source);
        remaining->focus_deferred_source =
            g_idle_add(focus_grid_context_idle, remaining);
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

static gboolean close_grid_tab(NocttyGridContext *context, GtkWidget *page) {
    NocttyGridContext *root = root_grid_context(context);
    if (page == NULL || root->notebook == NULL ||
        gtk_notebook_get_n_pages(GTK_NOTEBOOK(root->notebook)) <= 1) return FALSE;
    gint page_index = gtk_notebook_page_num(GTK_NOTEBOOK(root->notebook), page);
    NocttyGridContext *representative = grid_context_for_page(root, page);
    guint context_count = grid_contexts_on_page(root, page);
    if (page_index < 0 || representative == NULL || context_count == 0 ||
        root->event_data == NULL) return FALSE;

    guint busy_count = foreground_process_count(root, page);
    if (!confirm_terminal_process_close(root, "tab", busy_count, FALSE)) return FALSE;

    int model_pane_count = noctty_grid_close_tab(root->event_data,
                                                 representative->pane_id);
    if (model_pane_count <= 0) return FALSE;
    if (root->zoomed_pane_id != 0) {
        NocttyGridContext *zoomed = grid_context_for_pane(root,
                                                          root->zoomed_pane_id);
        if (zoomed != NULL && zoomed->page == page) restore_zoomed_page(root);
    }

    guint stopped_sessions = 0;
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        NocttyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (!candidate->active || candidate->page != page) continue;
        stop_grid_context_sources(candidate);
        candidate->retiring = 1;
        candidate->active = 0;
        candidate->focused = 0;
        if (candidate->im_context != NULL)
            gtk_im_context_focus_out(candidate->im_context);
        int close_status = noctty_grid_close_session(candidate->userdata,
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

    gtk_notebook_remove_page(GTK_NOTEBOOK(root->notebook), page_index);
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        NocttyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (candidate->page != page) continue;
        candidate->area = NULL;
        candidate->page = NULL;
        candidate->tab_label = NULL;
    }
    guint retire_index = 0;
    while (root->contexts != NULL && retire_index < root->contexts->len) {
        NocttyGridContext *candidate = g_ptr_array_index(root->contexts,
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
    NocttyGridContext *remaining = active_grid_context(root);
    if (remaining->area != NULL) gtk_widget_grab_focus(remaining->area);
    root->tab_close_session_stopped =
        stopped_sessions == context_count &&
        context_count == (guint)model_pane_count;
    root->tab_close_applied = root->tab_close_session_stopped &&
        gtk_notebook_get_n_pages(GTK_NOTEBOOK(root->notebook)) >= 1;
    root->tab_close_remaining_focused = remaining->area != NULL &&
        gtk_widget_has_focus(remaining->area);
    return root->tab_close_applied;
}

static gchar *pane_session_name_alloc(NocttyGridContext *context) {
    char title[513] = {0};
    int length = context->title != NULL
        ? context->title(context->userdata, title, sizeof(title) - 1) : 0;
    if (length > 0 && length < (int)sizeof(title)) {
        title[length] = '\0';
        gchar *trimmed = g_strstrip(title);
        if (trimmed[0] != '\0') return g_strdup(trimmed);
    }
    if (context->display_title != NULL && context->display_title[0] != '\0')
        return g_strdup(context->display_title);
    return g_strdup_printf("Pane %" G_GUINT64_FORMAT,
                           (guint64)context->pane_id);
}

static void toggle_grid_zoom(NocttyGridContext *context) {
    NocttyGridContext *root = root_grid_context(context);
    gboolean unzoom = root->zoomed_pane_id == context->pane_id;
    restore_zoomed_page(root);
    if (!unzoom) {
        gtk_widget_show_all(context->page);
        for (guint index = 0; root->contexts != NULL && index < root->contexts->len; index++) {
            NocttyGridContext *candidate = g_ptr_array_index(root->contexts, index);
            if (candidate->page != context->page) continue;
            if (candidate == context) gtk_widget_show(candidate->area);
            else gtk_widget_hide(candidate->area);
        }
        sync_grid_page_branch_visibility(root, context->page);
        gtk_notebook_set_show_tabs(GTK_NOTEBOOK(root->notebook), FALSE);
        root->zoomed_pane_id = context->pane_id;
        gchar *session_name = pane_session_name_alloc(context);
        gchar *message = g_strdup_printf(
            "Session %s is focused. Double click again on pane to go back.",
            session_name);
        show_status_feedback(context, message);
        g_free(message);
        g_free(session_name);
    }
    root->compact_zoom_toggled = 1;
    if (context->event != NULL) {
        context->event(context->event_data, context->pane_id, 64,
                       unzoom ? 0 : 1,
                       (uint64_t)(g_get_monotonic_time() / 1000));
    }
    gtk_widget_grab_focus(context->area);
    gtk_widget_queue_resize(context->page);
}

static gboolean focus_grid_direction(NocttyGridContext *context, int dx, int dy) {
    NocttyGridContext *root = root_grid_context(context);
    gint source_x = 0, source_y = 0;
    GtkAllocation source_allocation;
    gtk_widget_get_allocation(context->area, &source_allocation);
    if (!gtk_widget_translate_coordinates(context->area, root->window, 0, 0,
                                          &source_x, &source_y)) return FALSE;
    NocttyGridRectangle source = {
        .x = source_x,
        .y = source_y,
        .width = source_allocation.width,
        .height = source_allocation.height,
    };
    NocttyGridDirectionalFocusPlan plan;
    noctty_grid_directional_focus_begin(&source, dx, dy, &plan);
    if (!plan.active) return FALSE;

    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        NocttyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (candidate == context || !candidate->active || candidate->exited ||
            candidate->page != context->page || candidate->area == NULL ||
            !gtk_widget_get_visible(candidate->area) || index > G_MAXINT)
            continue;
        gint x = 0, y = 0;
        GtkAllocation allocation;
        gtk_widget_get_allocation(candidate->area, &allocation);
        if (!gtk_widget_translate_coordinates(candidate->area, root->window,
                                              0, 0, &x, &y))
            continue;
        NocttyGridRectangle rectangle = {
            .x = x,
            .y = y,
            .width = allocation.width,
            .height = allocation.height,
        };
        noctty_grid_directional_focus_consider(
            &plan, &rectangle, (gint)index);
    }
    if (plan.target_index < 0 || root->contexts == NULL ||
        (guint)plan.target_index >= root->contexts->len)
        return FALSE;
    NocttyGridContext *best =
        g_ptr_array_index(root->contexts, (guint)plan.target_index);
    root->compact_directional_focus = 1;
    if (best->event != NULL)
        best->event(best->event_data, best->pane_id, 67, 0,
                    (uint64_t)(g_get_monotonic_time() / 1000));
    gtk_widget_grab_focus(best->area);
    return TRUE;
}

static GtkWidget *build_preset_line(GtkWidget **widgets, guint count,
                                    GtkOrientation orientation) {
    if (count == 0) return NULL;
    if (count == 1) return widgets[0];
    GtkWidget *rest = build_preset_line(widgets + 1, count - 1,
                                        orientation);
    if (rest == NULL) return NULL;
    GtkWidget *split = gtk_paned_new(orientation);
    gtk_paned_pack1(GTK_PANED(split), widgets[0], TRUE, FALSE);
    gtk_paned_pack2(GTK_PANED(split), rest, TRUE, FALSE);
    guint ratio_permille = 1000 / count;
    g_object_set_data(G_OBJECT(split), "noctty-preset-ratio",
                      GUINT_TO_POINTER(ratio_permille));
    return split;
}

static void apply_preset_paned_positions(GtkWidget *widget,
                                         gint width, gint height) {
    (void)width;
    (void)height;
    if (!GTK_IS_PANED(widget)) return;
    gint max_position = 0;
    g_object_get(G_OBJECT(widget), "max-position", &max_position, NULL);
    guint ratio_permille = GPOINTER_TO_UINT(g_object_get_data(
        G_OBJECT(widget), "noctty-preset-ratio"));
    if (max_position > 0 && max_position < G_MAXINT / 2)
        gtk_paned_set_position(GTK_PANED(widget),
            noctty_grid_split_position(max_position, (int)ratio_permille));
    apply_preset_paned_positions(
        gtk_paned_get_child1(GTK_PANED(widget)), 0, 0);
    apply_preset_paned_positions(
        gtk_paned_get_child2(GTK_PANED(widget)), 0, 0);
}

static gboolean apply_preset_split_position(gpointer user_data) {
    GtkWidget *widget = GTK_WIDGET(user_data);
    g_object_set_data(G_OBJECT(widget), "noctty-preset-position-source", NULL);
    NocttyGridContext *root = g_object_get_data(
        G_OBJECT(widget), "noctty-grid-root-context");
    if (root != NULL && GTK_IS_PANED(widget)) {
        root->layout_restore_applying = 1;
        gint max_position = 0;
        g_object_get(G_OBJECT(widget), "max-position", &max_position, NULL);
        guint ratio_permille = GPOINTER_TO_UINT(g_object_get_data(
            G_OBJECT(widget), "noctty-preset-ratio"));
        if (max_position > 0 && max_position < G_MAXINT / 2)
            gtk_paned_set_position(GTK_PANED(widget),
                noctty_grid_split_position(max_position, (int)ratio_permille));
        root->layout_restore_applying = 0;
    }
    g_object_unref(widget);
    return G_SOURCE_REMOVE;
}

static void on_preset_max_position_changed(
    GObject *object, GParamSpec *parameter, gpointer user_data) {
    (void)parameter;
    (void)user_data;
    if (!GTK_IS_PANED(object) ||
        g_object_get_data(object, "noctty-preset-position-source") != NULL)
        return;
    guint source = g_idle_add(apply_preset_split_position,
                              g_object_ref(object));
    g_object_set_data(object, "noctty-preset-position-source",
                      GUINT_TO_POINTER(source));
}

static void bind_preset_max_positions(NocttyGridContext *root,
                                      GtkWidget *widget) {
    if (!GTK_IS_PANED(widget)) return;
    g_object_set_data(G_OBJECT(widget), "noctty-grid-root-context", root);
    if (g_object_get_data(G_OBJECT(widget),
                          "noctty-max-position-bound") == NULL) {
        g_signal_connect(widget, "notify::max-position",
                         G_CALLBACK(on_preset_max_position_changed), root);
        g_object_set_data(G_OBJECT(widget), "noctty-max-position-bound",
                          GINT_TO_POINTER(1));
    }
    bind_preset_max_positions(
        root, gtk_paned_get_child1(GTK_PANED(widget)));
    bind_preset_max_positions(
        root, gtk_paned_get_child2(GTK_PANED(widget)));
}

enum {
    NOCTTY_PRESET_SETTLE_INTERVAL_MS = 50,
    NOCTTY_PRESET_SETTLE_ATTEMPTS = 4,
};

typedef struct {
    GtkWidget *page;
    guint attempts_remaining;
} NocttyPresetSettleRequest;

static void queue_grid_preset_widget_draw(GtkWidget *widget,
                                          gpointer user_data) {
    (void)user_data;
    gtk_widget_queue_draw(widget);
    if (GTK_IS_CONTAINER(widget))
        gtk_container_forall(GTK_CONTAINER(widget),
                             queue_grid_preset_widget_draw, NULL);
}

static void destroy_grid_preset_settle_request(gpointer user_data) {
    NocttyPresetSettleRequest *request = user_data;
    g_object_unref(request->page);
    g_free(request);
}

static gboolean settle_grid_preset_page(gpointer user_data) {
    NocttyPresetSettleRequest *request = user_data;
    if (gtk_widget_in_destruction(request->page)) return G_SOURCE_REMOVE;

    /* KWin may defer child paints while nested GtkPaned allocations settle.
     * Refreshing the bounded widget tree over four main-loop turns ensures
     * every terminal receives damage without blocking the UI thread. The
     * request owns the page, so closing the tab cannot leave a stale context
     * callback behind. */
    gtk_widget_queue_resize(request->page);
    queue_grid_preset_widget_draw(request->page, NULL);

    g_assert(request->attempts_remaining > 0);
    request->attempts_remaining--;
    return request->attempts_remaining == 0
        ? G_SOURCE_REMOVE
        : G_SOURCE_CONTINUE;
}

static void schedule_grid_preset_settle(GtkWidget *page) {
    NocttyPresetSettleRequest *request = g_new0(
        NocttyPresetSettleRequest, 1);
    request->page = g_object_ref(page);
    request->attempts_remaining = NOCTTY_PRESET_SETTLE_ATTEMPTS;
    guint source = g_timeout_add_full(
        G_PRIORITY_DEFAULT, NOCTTY_PRESET_SETTLE_INTERVAL_MS,
        settle_grid_preset_page, request,
        destroy_grid_preset_settle_request);
    if (source == 0) destroy_grid_preset_settle_request(request);
}

static gboolean rebuild_grid_preset_page(
    NocttyGridContext *source, NocttyGridContext **ordered,
    guint count, guint rows, guint columns) {
    if (source == NULL || source->page == NULL || count == 0 ||
        count > 16 || rows == 0 || columns == 0 ||
        rows * columns != count) return FALSE;
    NocttyGridContext *root = root_grid_context(source);
    GtkWidget *page = source->page;
    GtkWidget *areas[16] = {0};
    gboolean held[16] = {FALSE};
    for (guint index = 0; index < count; index++) {
        if (ordered[index] == NULL || ordered[index]->area == NULL) return FALSE;
        areas[index] = ordered[index]->area;
        if (gtk_widget_get_parent(areas[index]) != NULL) {
            g_object_ref(areas[index]);
            held[index] = TRUE;
        }
    }

    GtkWidget *old_root = grid_page_content_root(source, page);
    if (old_root != NULL)
        gtk_container_remove(GTK_CONTAINER(page), old_root);

    GtkWidget *row_widgets[4] = {0};
    for (guint row = 0; row < rows; row++) {
        row_widgets[row] = build_preset_line(
            areas + row * columns, columns, GTK_ORIENTATION_HORIZONTAL);
        if (row_widgets[row] == NULL) return FALSE;
    }
    GtkWidget *grid_root = build_preset_line(
        row_widgets, rows, GTK_ORIENTATION_VERTICAL);
    if (grid_root == NULL) return FALSE;
    noctty_apply_pane_divider_style(grid_root, root->pane_divider_px);
    bind_preset_max_positions(root, grid_root);
    gtk_box_pack_start(GTK_BOX(page), grid_root, TRUE, TRUE, 0);
    for (guint index = 0; index < count; index++) {
        ordered[index]->page = page;
        ordered[index]->tab_label = source->tab_label;
        if (held[index]) g_object_unref(areas[index]);
    }
    gtk_widget_show_all(page);
    gtk_widget_queue_resize(page);
    schedule_even_pane_distribution(source, grid_root);
    schedule_grid_preset_settle(page);
    for (guint index = 0; index < count; index++) {
        if (!ordered[index]->active) start_grid_context(ordered[index]);
        gtk_widget_set_sensitive(ordered[index]->area, TRUE);
        gtk_widget_set_can_focus(ordered[index]->area, TRUE);
        gtk_widget_show(ordered[index]->area);
        gtk_widget_queue_draw(ordered[index]->area);
        update_compact_tab(ordered[index]);
    }
    gint page_index = gtk_notebook_page_num(GTK_NOTEBOOK(source->notebook),
                                            page);
    if (page_index >= 0)
        gtk_notebook_set_current_page(GTK_NOTEBOOK(source->notebook),
                                      page_index);
    apply_smart_filter(root);
    if (gtk_widget_get_visible(ordered[0]->area))
        defer_grid_context_focus(ordered[0]);
    return TRUE;
}

static gboolean respond_layout_preset_prompt_smoke(gpointer user_data) {
    GtkDialog *dialog = GTK_DIALOG(user_data);
    gtk_dialog_response(dialog, GPOINTER_TO_INT(g_object_get_data(
        G_OBJECT(dialog), "noctty-layout-prompt-response")));
    return G_SOURCE_REMOVE;
}

static gboolean apply_grid_layout_preset(NocttyGridContext *context,
                                         int event_code,
                                         gboolean restore_missing) {
    NocttyGridContext *root = root_grid_context(context);
    if (context == NULL || !context->active || context->area == NULL ||
        context->page == NULL || root->event_data == NULL ||
        !((event_code >= 50 && event_code <= 52) || event_code == 60 ||
          event_code == 61))
        return FALSE;
    guint rows = event_code == 50 ? 1 : event_code == 51 ? 2 :
        event_code == 61 ? 2 : event_code == 52 ? 3 : 4;
    guint cols = event_code == 50 ? 1 : event_code == 51 ? 2 :
        event_code == 61 ? 4 : event_code == 52 ? 3 : 4;
    guint target_count = rows * cols;
    GtkWidget *page = context->page;
    if (root->zoomed_pane_id != 0) restore_zoomed_page(root);
    if (context->event != NULL)
        context->event(context->event_data, context->pane_id, 57, 0,
                       (uint64_t)(g_get_monotonic_time() / 1000));

    guint current_count = grid_contexts_on_page(root, page);
    if (current_count > target_count &&
        !(root->workspace_smoke == 21 && !root->layout_preset_finalizing)) {
        guint extra_count = current_count - target_count;
        if (root->workspace_smoke == 21) {
            GtkWidget *dialog = gtk_message_dialog_new(
                GTK_WINDOW(root->window), GTK_DIALOG_MODAL,
                GTK_MESSAGE_WARNING, GTK_BUTTONS_NONE,
                "Move %u terminal session%s to a new tab?", extra_count,
                extra_count == 1 ? "" : "s");
            gtk_message_dialog_format_secondary_text(
                GTK_MESSAGE_DIALOG(dialog),
                "Changing this layout would otherwise close live terminals. "
                "Cancel keeps the current layout.");
            gtk_dialog_add_buttons(GTK_DIALOG(dialog), "Cancel",
                                   GTK_RESPONSE_CANCEL, "Move sessions",
                                   GTK_RESPONSE_ACCEPT, NULL);
            gtk_dialog_set_default_response(GTK_DIALOG(dialog),
                                            GTK_RESPONSE_CANCEL);
            gint smoke_response = root->layout_preset_prompt_count++ == 0
                ? GTK_RESPONSE_CANCEL : GTK_RESPONSE_ACCEPT;
            g_object_set_data(G_OBJECT(dialog), "noctty-layout-prompt-response",
                              GINT_TO_POINTER(smoke_response));
            g_idle_add(respond_layout_preset_prompt_smoke, dialog);
            gint response = run_grid_modal_dialog(root, GTK_DIALOG(dialog));
            gtk_widget_destroy(dialog);
            if (response != GTK_RESPONSE_ACCEPT) {
                root->layout_preset_prompt_cancelled++;
                return FALSE;
            }
            root->layout_preset_prompt_accepted++;
        }

        NocttyGridContext *extras[15] = {0};
        guint collected = 0;
        for (gint index = (gint)root->contexts->len - 1;
             index >= 0 && collected < extra_count; index--) {
            NocttyGridContext *candidate = g_ptr_array_index(
                root->contexts, (guint)index);
            if (candidate != context && candidate->active &&
                !candidate->exited && candidate->page == page &&
                candidate->area != NULL && candidate->pane_id <= G_MAXINT)
                extras[collected++] = candidate;
        }
        if (collected != extra_count) return FALSE;
        NocttyGridContext *destination = create_grid_context(context, 20);
        if (destination == NULL || !add_grid_tab(context, destination)) return FALSE;
        start_grid_context(destination);
        for (guint extra_index = 0; extra_index < extra_count; extra_index++) {
            if (context->event != NULL)
                context->event(context->event_data, destination->pane_id, 55,
                               (int)extras[extra_index]->pane_id,
                               (uint64_t)(g_get_monotonic_time() / 1000));
            if (!move_grid_context(extras[extra_index], destination)) return FALSE;
        }
        if (!close_grid_pane(destination)) return FALSE;
        if (context->event != NULL)
            context->event(context->event_data, context->pane_id, 57, 0,
                           (uint64_t)(g_get_monotonic_time() / 1000));
        root->layout_preset_moved_count += (int)extra_count;
        current_count = target_count;
    }
    while (current_count > target_count) {
        NocttyGridContext *candidate = NULL;
        for (gint index = root->contexts != NULL
                 ? (gint)root->contexts->len - 1
                 : -1;
             index >= 0; index--) {
            NocttyGridContext *next = g_ptr_array_index(root->contexts,
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
        NocttyGridContext *created = create_grid_context(context, 21);
        if (created == NULL) return FALSE;
        created->page = page;
        created->tab_label = context->tab_label;
        root->layout_preset_created_count++;
        current_count++;
    }

    uint64_t pane_ids[16] = {0};
    int model_count = noctty_grid_apply_preset(
        root->event_data, context->pane_id, event_code,
        pane_ids, G_N_ELEMENTS(pane_ids));
    if (model_count != (int)target_count) {
        g_printerr("native_grid_layout_apply event=%d reason=model_count expected=%u actual=%d\n",
                   event_code, target_count, model_count);
        return FALSE;
    }
    NocttyGridContext *ordered[16] = {0};
    for (guint index = 0; index < target_count; index++) {
        ordered[index] = grid_context_for_pane(root, pane_ids[index]);
        if (ordered[index] == NULL || ordered[index]->userdata == NULL ||
            ordered[index]->retiring || ordered[index]->exited) {
            ordered[index] = restore_grid_context(
                context, pane_ids[index],
                noctty_grid_partition_size(context->columns, (int)cols),
                noctty_grid_partition_size(context->rows, (int)rows));
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
    if (rebuilt && event_code == 50) root->layout_preset_1x1_applied = 1;
    if (rebuilt && event_code == 51) root->layout_preset_2x2_applied = 1;
    if (rebuilt && event_code == 61) root->layout_preset_4x2_applied = 1;
    if (rebuilt && event_code == 52) root->layout_preset_3x3_applied = 1;
    if (rebuilt && event_code == 60) root->layout_preset_4x4_applied = 1;
    return rebuilt;
}

static gboolean open_grid_layout_preset_tab(NocttyGridContext *context,
                                             int event_code) {
    NocttyGridContext *root = root_grid_context(context);
    NocttyGridContext *created = create_grid_context(context, 20);
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

static void emit_grid_workspace_event(NocttyGridContext *context, int event_code) {
    if (event_code == 20 || event_code == 21 || event_code == 22 ||
        event_code == 26 || event_code == 27 || event_code == 28) {
        NocttyGridContext *created = NULL;
        if (context->peer != NULL && !context->peer->active &&
            !context->peer->exited && context->peer->area != NULL &&
            context->peer->page != NULL && context->peer->userdata != NULL) {
            if (context->event != NULL) context->event(context->event_data, context->pane_id, event_code, 0, (uint64_t)(g_get_monotonic_time() / 1000));
            created = context->peer;
        } else {
            created = create_grid_context(context, event_code);
        }
        if (created == NULL) return;
        gboolean presented = event_code == 20 || event_code == 26
            ? add_grid_tab(context, created)
            : split_grid_context(context, created, event_code);
        if (!presented) return;
        if (event_code == 21 || event_code == 22 ||
            event_code == 27 || event_code == 28)
            (void)bind_grid_layout_for_page(created);
        start_grid_context(created);
        apply_smart_filter(root_grid_context(created));
        if (gtk_widget_get_visible(created->area))
            defer_grid_context_focus(created);
        return;
    }
    if ((event_code >= 50 && event_code <= 52) || event_code == 60 ||
        event_code == 61) {
        NocttyGridContext *root = root_grid_context(context);
        if (root->workspace_smoke == 21) {
            (void)apply_grid_layout_preset(context, event_code, FALSE);
            return;
        }
        (void)open_grid_layout_preset_tab(context, event_code);
        return;
    }
    if (event_code == 56) {
        NocttyGridContext *target = grid_context_on_other_page(context);
        if (target == NULL) return;
        if (context->event != NULL) {
            context->event(context->event_data, context->pane_id, event_code, 0,
                           (uint64_t)(g_get_monotonic_time() / 1000));
        }
        (void)move_grid_context(context, target);
        return;
    }
    if (context->event != NULL) context->event(context->event_data, context->pane_id, event_code, 0, (uint64_t)(g_get_monotonic_time() / 1000));
}

static void deactivate_grid_context(NocttyGridContext *context) {
    if (context == NULL || !context->focused) return;
    context->focused = 0;
    context->cursor_visible = 0;
    context->selection_dragging = 0;
    context->suppress_primary_release = 0;
    if (context->im_context != NULL)
        gtk_im_context_focus_out(context->im_context);
    if (grid_context_session_available(context))
        (void)context->focus(context->userdata, 0);
    if (context->area != NULL) gtk_widget_queue_draw(context->area);
}

static void activate_grid_context(NocttyGridContext *context) {
    if (!grid_context_session_available(context) || context->exited) return;
    NocttyGridContext *root = root_grid_context(context);
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        NocttyGridContext *candidate =
            g_ptr_array_index(root->contexts, index);
        if (candidate != context) deactivate_grid_context(candidate);
    }
    gboolean changed = !context->focused;
    gboolean acknowledged_attention = context->attention ||
        context->status_kind == 4;
    context->focused = 1;
    root->active_pane_id_for_render = context->pane_id;
    context->cursor_visible = 1;
    context->attention = 0;
    if (acknowledged_attention) {
        context->status_kind = 0;
        update_status_tooltip(context, "idle");
        if (context->event != NULL)
            context->event(context->event_data, context->pane_id,
                           NOCTTY_EVENT_STATUS_ACKNOWLEDGED, 0,
                           (uint64_t)(g_get_monotonic_time() / 1000));
    }
    if (changed) {
        if (context->im_context != NULL)
            gtk_im_context_focus_in(context->im_context);
        (void)context->focus(context->userdata, 1);
        record_dogfood_omp_action(
            context, "omp_focus", &context->dogfood_omp_focus_seen);
        if (context->event != NULL)
            context->event(context->event_data, context->pane_id, 57, 0,
                           (uint64_t)(g_get_monotonic_time() / 1000));
    }
    gtk_widget_queue_draw(context->area);
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
    NocttyGridContext *context = user_data;
    (void)widget;
    (void)event;
    deactivate_grid_context(context);
    return FALSE;
}

static void open_command_palette(NocttyGridContext *context);
static void open_terminal_find(NocttyGridContext *context);
static void open_quick_note(NocttyGridContext *context);
static void open_shortcuts_overlay(NocttyGridContext *context);
static void save_grid_scrollback(NocttyGridContext *context);
static void on_smart_filter_button_clicked(GtkButton *button, gpointer user_data);
static void on_tag_selected_menu_activate(GtkMenuItem *item, gpointer user_data);
static void on_tag_remove_menu_activate(GtkMenuItem *item, gpointer user_data);

static gboolean on_key_press(GtkWidget *widget, GdkEventKey *event, gpointer user_data) {
    NocttyGridContext *context = user_data;
    if (!grid_context_session_available(context) || context->exited)
        return FALSE;
    NocttyGridContext *root = root_grid_context(context);
#if NOCTTY_ENABLE_SMOKE
    if (root->workspace_smoke == 36 && root->presentation_armed &&
        !root->presentation_pending &&
        root->presentation_samples_started <
            NOCTTY_PRESENTATION_QUALIFICATION_SAMPLES) {
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
    uint32_t modifier_flags = noctty_grid_input_modifiers(event->state);
    gboolean smart_filter_clear_available =
        event->keyval == GDK_KEY_Escape &&
        root->smart_filter_tag != NULL &&
        root->smart_filter_empty_box != NULL &&
        gtk_widget_get_visible(root->smart_filter_empty_box);
    NocttyGridKeyCommandPlan key_plan;
    noctty_grid_key_command_plan(
        TRUE, noctty_grid_is_alt_key(event->keyval), smart_filter_clear_available,
        event->keyval, modifier_flags, &key_plan);
    switch (key_plan.action) {
        case NOCTTY_GRID_KEY_ACTION_SHOW_NOTE_OVERLAYS:
            (void)show_quick_note_overlays(root);
            return TRUE;
        case NOCTTY_GRID_KEY_ACTION_CLEAR_SMART_FILTER:
            return clear_smart_filter(root);
        case NOCTTY_GRID_KEY_ACTION_CYCLE_TAB: {
            gboolean cycled = cycle_grid_tab(context, key_plan.direction);
            return key_plan.consume_without_effect ? TRUE : cycled;
        }
        case NOCTTY_GRID_KEY_ACTION_CYCLE_PANE:
            return cycle_grid_pane(context, key_plan.direction);
        case NOCTTY_GRID_KEY_ACTION_FOCUS_DIRECTION:
            if (focus_grid_direction(context, key_plan.dx, key_plan.dy))
                return TRUE;
            break;
        default:
            break;
    }
    if ((event->state & GDK_CONTROL_MASK) && (event->state & GDK_SHIFT_MASK) &&
        (event->keyval == GDK_KEY_p || event->keyval == GDK_KEY_P)) {
        open_command_palette(context);
        return TRUE;
    }
    if ((event->state & GDK_CONTROL_MASK) && (event->state & GDK_SHIFT_MASK) &&
        (event->keyval == GDK_KEY_f || event->keyval == GDK_KEY_F)) {
        open_terminal_find(context);
        return TRUE;
    }
    if ((event->state & GDK_CONTROL_MASK) && (event->state & GDK_SHIFT_MASK) &&
        (event->keyval == GDK_KEY_n || event->keyval == GDK_KEY_N)) {
        open_quick_note(context);
        return TRUE;
    }
    if ((event->state & GDK_CONTROL_MASK) && (event->state & GDK_SHIFT_MASK) &&
        (event->keyval == GDK_KEY_g || event->keyval == GDK_KEY_G)) {
        on_smart_filter_button_clicked(NULL, context);
        return TRUE;
    }
    if ((event->state & GDK_CONTROL_MASK) && (event->state & GDK_SHIFT_MASK) &&
        (event->keyval == GDK_KEY_y || event->keyval == GDK_KEY_Y)) {
        on_tag_selected_menu_activate(NULL, context);
        return TRUE;
    }
    if ((event->state & GDK_CONTROL_MASK) && (event->state & GDK_SHIFT_MASK) &&
        (event->keyval == GDK_KEY_z || event->keyval == GDK_KEY_Z)) {
        toggle_grid_zoom(context);
        return TRUE;
    }
    if ((event->state & GDK_CONTROL_MASK) && (event->state & GDK_SHIFT_MASK) &&
        (event->keyval == GDK_KEY_k || event->keyval == GDK_KEY_K)) {
        open_shortcuts_overlay(context);
        return TRUE;
    }
    if ((event->state & GDK_CONTROL_MASK) && (event->state & GDK_SHIFT_MASK) &&
        (event->keyval == GDK_KEY_w || event->keyval == GDK_KEY_W)) {
        gint page_index = gtk_notebook_get_current_page(GTK_NOTEBOOK(root->notebook));
        GtkWidget *page = gtk_notebook_get_nth_page(GTK_NOTEBOOK(root->notebook), page_index);
        root->tab_shortcut_close = close_grid_tab(root, page);
        return TRUE;
    }
    if ((event->state & GDK_CONTROL_MASK) && (event->state & GDK_SHIFT_MASK) &&
        (event->keyval == GDK_KEY_r || event->keyval == GDK_KEY_R)) {
        gint page_index = gtk_notebook_get_current_page(GTK_NOTEBOOK(root->notebook));
        GtkWidget *page = gtk_notebook_get_nth_page(GTK_NOTEBOOK(root->notebook), page_index);
        open_tab_rename(root, page);
        return TRUE;
    }
    if ((event->state & GDK_CONTROL_MASK) && (event->state & GDK_SHIFT_MASK) &&
        (event->keyval == GDK_KEY_t || event->keyval == GDK_KEY_T)) {
        emit_grid_workspace_event(context, 26);
        root_grid_context(context)->tab_shortcut_reopen = 1;
        return TRUE;
    }
    if ((event->state & GDK_CONTROL_MASK) && (event->state & GDK_SHIFT_MASK) &&
        (event->keyval == GDK_KEY_s || event->keyval == GDK_KEY_S)) {
        emit_grid_workspace_event(context, 21);
        return TRUE;
    }
    if ((event->state & GDK_CONTROL_MASK) && (event->state & GDK_SHIFT_MASK) &&
        (event->keyval == GDK_KEY_l || event->keyval == GDK_KEY_L)) {
        emit_grid_workspace_event(context, 22);
        return TRUE;
    }
    if ((event->state & GDK_CONTROL_MASK) &&
        (event->state & (GDK_SHIFT_MASK | GDK_MOD1_MASK)) &&
        (event->keyval == GDK_KEY_b || event->keyval == GDK_KEY_B)) {
        on_broadcast_menu_activate(NULL, context);
        return TRUE;
    }
    if ((event->state & GDK_CONTROL_MASK) &&
        (event->state & GDK_MOD1_MASK) &&
        (event->keyval == GDK_KEY_equal ||
         event->keyval == GDK_KEY_plus ||
         event->keyval == GDK_KEY_KP_Add)) {
        return adjust_active_tab_color(context, 1);
    }
    if ((event->state & GDK_CONTROL_MASK) &&
        (event->state & GDK_MOD1_MASK) &&
        (event->keyval == GDK_KEY_minus ||
         event->keyval == GDK_KEY_KP_Subtract)) {
        return adjust_active_tab_color(context, -1);
    }
    if ((event->state & GDK_CONTROL_MASK) && (event->state & GDK_MOD1_MASK) &&
        event->keyval >= GDK_KEY_1 && event->keyval <= GDK_KEY_9) {
        if (context->event != NULL) context->event(context->event_data, context->pane_id, 30 + (int)(event->keyval - GDK_KEY_0), 0, (uint64_t)(g_get_monotonic_time() / 1000));
        gtk_widget_queue_draw(context->area);
        return TRUE;
    }
    if ((event->state & GDK_CONTROL_MASK) && (event->state & GDK_MOD1_MASK) && event->keyval == GDK_KEY_bracketright) {
        if (context->event != NULL) context->event(context->event_data, context->pane_id, 24, 0, (uint64_t)(g_get_monotonic_time() / 1000));
        return TRUE;
    }
    if ((event->state & GDK_CONTROL_MASK) && (event->state & GDK_MOD1_MASK) && event->keyval == GDK_KEY_bracketleft) {
        if (context->event != NULL) context->event(context->event_data, context->pane_id, 25, 0, (uint64_t)(g_get_monotonic_time() / 1000));
        return TRUE;
    }
    if ((event->state & GDK_CONTROL_MASK) && (event->state & GDK_SHIFT_MASK) &&
        (event->keyval == GDK_KEY_v || event->keyval == GDK_KEY_V)) {
        request_grid_clipboard_text(context);
        return TRUE;
    }
    if ((event->state & GDK_CONTROL_MASK) && (event->state & GDK_SHIFT_MASK) &&
        (event->keyval == GDK_KEY_c || event->keyval == GDK_KEY_C)) {
        copy_grid_selection_to_clipboard(context);
        return TRUE;
    }
    gboolean plain_shift = (event->state & GDK_SHIFT_MASK) &&
        !(event->state &
          (GDK_CONTROL_MASK | GDK_MOD1_MASK | GDK_SUPER_MASK));
    if (plain_shift &&
        (event->keyval == GDK_KEY_Page_Up ||
         event->keyval == GDK_KEY_Page_Down ||
         event->keyval == GDK_KEY_Home ||
         event->keyval == GDK_KEY_End))
        return scroll_terminal_from_keyboard(context, event->keyval);

    gboolean plain_control = (event->state & GDK_CONTROL_MASK) &&
        !(event->state & (GDK_SHIFT_MASK | GDK_MOD1_MASK | GDK_SUPER_MASK));
    if (plain_control &&
        (event->keyval == GDK_KEY_d || event->keyval == GDK_KEY_D)) {
        root->ctrl_d_close_attempted = 1;
        if (close_grid_pane(context)) root->ctrl_d_close_succeeded = 1;
        return TRUE;
    }
    if (plain_control &&
        (event->keyval == GDK_KEY_c || event->keyval == GDK_KEY_C)) {
        acknowledge_grid_attention(context);
        if (context->write(context->userdata, "\x03", 1) == 1) {
            schedule_grid_write_flush(context);
            root->ctrl_c_local_interrupt = 1;
        } else {
            show_status_feedback(context, "Could not interrupt the terminal.");
        }
        return TRUE;
    }
    if (context->im_context != NULL &&
        gtk_im_context_filter_keypress(context->im_context, event)) return TRUE;
    gunichar unicode = gdk_keyval_to_unicode(event->keyval);
    uint32_t modifiers = 0;
    if ((event->state & GDK_CONTROL_MASK) != 0)
        modifiers |= NOCTTY_GRID_MODIFIER_CONTROL;
    if ((event->state & GDK_MOD1_MASK) != 0)
        modifiers |= NOCTTY_GRID_MODIFIER_ALT;
    int encoded = noctty_grid_terminal_key_sequence(
        event->keyval, unicode, modifiers,
        context->cursor_mode(context->userdata),
        (uint8_t *)bytes, sizeof(bytes));
    if (encoded <= 0) return FALSE;
    length = (size_t)encoded;
    if (deliver_grid_input(context, bytes, length) < 0)
        show_status_feedback(
            context, "Could not deliver input to every target terminal.");
    return TRUE;
}

static gboolean on_key_release(GtkWidget *widget, GdkEventKey *event,
                               gpointer user_data) {
    (void)widget;
    NocttyGridContext *context = user_data;
    if (!grid_context_session_available(context) || context->exited)
        return FALSE;
    NocttyGridContext *root = root_grid_context(context);
    NocttyGridKeyCommandPlan key_plan;
    noctty_grid_key_command_plan(
        FALSE, noctty_grid_is_alt_key(event->keyval), FALSE, event->keyval, 0, &key_plan);
    if (key_plan.action != NOCTTY_GRID_KEY_ACTION_HIDE_NOTE_OVERLAYS)
        return FALSE;
    root->note_overlay_alt_released = 1;
    hide_quick_note_overlays(root);
    return TRUE;
}

static void show_workspace_menu(NocttyGridContext *context, GdkEventButton *event);

static void clear_grid_selection(NocttyGridContext *context) {
    context->selecting = 0;
    context->selection_dragging = 0;
    context->selection_start_column = 0;
    context->selection_start_row = 0;
    context->selection_end_column = 0;
    context->selection_end_row = 0;
    if (context->area != NULL) gtk_widget_queue_draw(context->area);
}

static int grid_column_at_pointer(NocttyGridContext *context, double x) {
    int column = 0;
    int row = 0;
    NocttyGridFontMetrics metrics = grid_font_metrics(context);
    (void)noctty_grid_pointer_cell(
        x, 2.0, metrics.cell_width, metrics.cell_height,
        context->columns, context->rows, 1, &column, &row);
    return column;
}

static int grid_row_at_pointer(NocttyGridContext *context, double y) {
    int column = 0;
    int row = 0;
    NocttyGridFontMetrics metrics = grid_font_metrics(context);
    (void)noctty_grid_pointer_cell(
        4.0, y, metrics.cell_width, metrics.cell_height,
        context->columns, context->rows, 1, &column, &row);
    return row;
}

static gboolean grid_cell_at_point(NocttyGridContext *context,
                                   double x, double y,
                                   int *column, int *row) {
    NocttyGridFontMetrics metrics = grid_font_metrics(context);
    return noctty_grid_pointer_cell(
        x, y, metrics.cell_width, metrics.cell_height,
        context->columns, context->rows, 0, column, row) != 0;
}

static gboolean grid_cell_is_background(NocttyGridContext *context,
                                        int column, int row) {
    char text[64] = {0};
    int length = context->cell_text(
        context->userdata, column, row, text, sizeof(text));
    return noctty_grid_cell_is_background(
        (const uint8_t *)text, length) != 0;
}

static gboolean select_grid_word(NocttyGridContext *context,
                                 int column, int row) {
    if (grid_cell_is_background(context, column, row)) return FALSE;
    int start = column;
    int end = column;
    while (start > 0 &&
           !grid_cell_is_background(context, start - 1, row))
        start--;
    while (end + 1 < context->columns &&
           !grid_cell_is_background(context, end + 1, row))
        end++;
    context->selecting = 1;
    context->selection_dragging = 0;
    context->selection_start_column = start;
    context->selection_start_row = row;
    context->selection_end_column = end;
    context->selection_end_row = row;
    gtk_widget_queue_draw(context->area);
    return TRUE;
}

static void popup_menu_at_toplevel_pointer(
    NocttyGridContext *context, GtkWidget *menu, GtkWidget *anchor,
    GdkEventButton *event);

static int read_grid_hyperlink(NocttyGridContext *context,
                               int column, int row,
                               char uri[2049]) {
    int length = context->cell_hyperlink(
        context->userdata, column, row, uri, 2048);
    if (length <= 0) return 0;
    length = MIN(length, 2048);
    uri[length] = '\0';
    return noctty_grid_hyperlink_valid(
        (const uint8_t *)uri, (uint32_t)length) ? length : -1;
}

static gboolean open_grid_uri(NocttyGridContext *context,
                              const char *uri, guint32 time) {
    NocttyGridContext *root = root_grid_context(context);
    if (root->workspace_smoke == 15) {
        root->compact_hyperlink_open_attempted = 1;
        return TRUE;
    }
    GError *error = NULL;
    gboolean opened = gtk_show_uri_on_window(
        GTK_WINDOW(context->window), uri, time, &error);
    if (!opened)
        show_status_feedback(
            context, "Could not open the link in the default browser.");
    if (error != NULL) g_error_free(error);
    return TRUE;
}

static gboolean open_grid_hyperlink(NocttyGridContext *context,
                                    int column, int row, guint32 time) {
    char uri[2049];
    int length = read_grid_hyperlink(context, column, row, uri);
    if (length == 0) return FALSE;
    if (length < 0) {
        show_status_feedback(context, "This link type is not allowed.");
        return TRUE;
    }
    return open_grid_uri(context, uri, time);
}

typedef struct {
    NocttyGridContext *context;
    gchar *uri;
    guint32 time;
} NocttyHyperlinkMenu;

static void on_hyperlink_menu_open(GtkMenuItem *item, gpointer user_data) {
    (void)item;
    NocttyHyperlinkMenu *menu = user_data;
    (void)open_grid_uri(menu->context, menu->uri, menu->time);
}

static void on_hyperlink_menu_copy(GtkMenuItem *item, gpointer user_data) {
    (void)item;
    NocttyHyperlinkMenu *menu = user_data;
    gtk_clipboard_set_text(
        gtk_clipboard_get(GDK_SELECTION_CLIPBOARD), menu->uri, -1);
    show_status_feedback(menu->context, "Link copied.");
}

static void destroy_hyperlink_menu_data(gpointer user_data) {
    NocttyHyperlinkMenu *menu = user_data;
    g_free(menu->uri);
    g_free(menu);
}

static void on_hyperlink_menu_destroy(GtkWidget *menu,
                                      gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    if (root->workspace_menu == menu) root->workspace_menu = NULL;
}

static gboolean show_hyperlink_menu(
    NocttyGridContext *context, GdkEventButton *event,
    int column, int row) {
    char uri[2049];
    if (read_grid_hyperlink(context, column, row, uri) <= 0) return FALSE;
    NocttyGridContext *root = root_grid_context(context);
    dismiss_grid_popup_windows(root);
    GtkWidget *menu = gtk_menu_new();
    GtkWidget *open = gtk_menu_item_new_with_label("Open Link in Browser");
    GtkWidget *copy = gtk_menu_item_new_with_label("Copy Link");
    NocttyHyperlinkMenu *data = g_new0(NocttyHyperlinkMenu, 1);
    data->context = context;
    data->uri = g_strdup(uri);
    data->time = event->time;
    g_object_set_data_full(
        G_OBJECT(menu), "noctty-hyperlink-menu", data,
        destroy_hyperlink_menu_data);
    set_widget_accessible_name(open, "Open link in default browser");
    set_widget_accessible_name(copy, "Copy hyperlink address");
    g_signal_connect(open, "activate", G_CALLBACK(on_hyperlink_menu_open), data);
    g_signal_connect(copy, "activate", G_CALLBACK(on_hyperlink_menu_copy), data);
    g_signal_connect_swapped(
        open, "activate", G_CALLBACK(gtk_widget_destroy), menu);
    g_signal_connect_swapped(
        copy, "activate", G_CALLBACK(gtk_widget_destroy), menu);
    g_signal_connect_swapped(
        menu, "selection-done", G_CALLBACK(gtk_widget_destroy), menu);
    g_signal_connect(menu, "destroy",
                     G_CALLBACK(on_hyperlink_menu_destroy), root);
    gtk_menu_shell_append(GTK_MENU_SHELL(menu), open);
    gtk_menu_shell_append(GTK_MENU_SHELL(menu), copy);
    root->workspace_menu = menu;
    gtk_widget_show_all(menu);
    if (root->workspace_smoke == 15) {
        root->compact_hyperlink_context_menu =
            g_strcmp0(gtk_menu_item_get_label(GTK_MENU_ITEM(open)),
                      "Open Link in Browser") == 0 &&
            g_strcmp0(gtk_menu_item_get_label(GTK_MENU_ITEM(copy)),
                      "Copy Link") == 0;
        gtk_menu_item_activate(GTK_MENU_ITEM(open));
        root->compact_hyperlink_context_open =
            root->compact_hyperlink_open_attempted;
        return TRUE;
    }
    popup_menu_at_toplevel_pointer(context, menu, context->area, event);
    return TRUE;
}


static gboolean handle_terminal_scrollbar_button(
    NocttyGridContext *context, GtkWidget *widget, GdkEventButton *event,
    const NocttyTerminalScrollbarGeometry *geometry) {
    if (event->type == GDK_BUTTON_RELEASE) {
        context->scrollbar_dragging = 0;
        gtk_widget_queue_draw(context->area);
        return TRUE;
    }
    if (event->type != GDK_BUTTON_PRESS) return TRUE;

    if (!gtk_widget_has_focus(widget)) gtk_widget_grab_focus(widget);
    activate_grid_context(context);
    NocttyTerminalScrollbarPressPlan plan = {0};
    noctty_grid_scrollbar_press_plan(geometry, event->y, &plan);
    if (plan.action == NOCTTY_GRID_SCROLLBAR_PRESS_DRAG) {
        context->scrollbar_dragging = 1;
        context->scrollbar_drag_offset = plan.drag_offset;
        gtk_widget_queue_draw(context->area);
        return TRUE;
    }
    if (plan.action == NOCTTY_GRID_SCROLLBAR_PRESS_PAGE &&
        scroll_terminal_to_offset(context, plan.target_offset))
        root_grid_context(context)->compact_scrollbar_track_scrolled = 1;
    return TRUE;
}

static gboolean on_mouse_button(GtkWidget *widget, GdkEventButton *event, gpointer user_data) {
    NocttyGridContext *context = user_data;
    if (!grid_context_session_available(context) || context->exited)
        return FALSE;
    GtkAllocation allocation;
    gtk_widget_get_allocation(widget, &allocation);
    NocttyTerminalScrollbarGeometry scrollbar;
    gboolean scrollbar_owned =
        terminal_scrollbar_geometry(context, allocation, &scrollbar) &&
        event->button == 1 &&
        (event->x >= scrollbar.x || context->scrollbar_dragging);
    int terminal_mode_flags =
        scrollbar_owned ? 0 : context->mouse_mode(context->userdata);
    int terminal_mouse_mode =
        terminal_mode_flags & NOCTTY_GRID_TERMINAL_MODE_MOUSE;
    int route = noctty_grid_input_route(
        NOCTTY_GRID_INPUT_POINTER, scrollbar_owned, terminal_mode_flags, 0,
        event->button == 1, noctty_grid_input_modifiers(event->state));
    if (route == NOCTTY_GRID_ROUTE_SCROLLBAR)
        return handle_terminal_scrollbar_button(
            context, widget, event, &scrollbar);
    int column = grid_column_at_pointer(context, event->x);
    int row = grid_row_at_pointer(context, event->y);
    int hyperlink_column = 0;
    int hyperlink_row = 0;
    gboolean hyperlink_point = grid_cell_at_point(
        context, event->x, event->y, &hyperlink_column, &hyperlink_row);
    int button = event->button >= 1 && event->button <= 3 ? (int)event->button - 1 : 0;
    int pressed = event->type == GDK_BUTTON_PRESS;
    if (event->type == GDK_BUTTON_PRESS && event->button == 1) {
        context->preserve_double_click_selection = 0;
        context->suppress_primary_release = 0;
    }
    if (event->type == GDK_2BUTTON_PRESS && event->button == 1) {
        gboolean background = grid_cell_is_background(context, column, row);
        if (background &&
            grid_contexts_on_page(root_grid_context(context), context->page) > 1) {
            clear_grid_selection(context);
            context->suppress_primary_release = 1;
            toggle_grid_zoom(context);
            return TRUE;
        }
        if (!background && select_grid_word(context, column, row)) {
            context->preserve_double_click_selection = 1;
            context->suppress_primary_release = 1;
            return TRUE;
        }
        clear_grid_selection(context);
        context->suppress_primary_release = 1;
        return TRUE;
    }
    if (event->type == GDK_BUTTON_RELEASE && event->button == 1 &&
        context->suppress_primary_release) {
        const int preserve_selection = context->preserve_double_click_selection;
        context->preserve_double_click_selection = 0;
        context->suppress_primary_release = 0;
        if (!preserve_selection) clear_grid_selection(context);
        return TRUE;
    }
    if (pressed && event->button == 1 && hyperlink_point &&
        (event->state & GDK_CONTROL_MASK) &&
        open_grid_hyperlink(
            context, hyperlink_column, hyperlink_row, event->time)) {
        clear_grid_selection(context);
        context->suppress_primary_release = 1;
        if (terminal_mouse_mode && context->workspace_smoke == 15)
            root_grid_context(context)->compact_hyperlink_mouse_mode_override = 1;
        return TRUE;
    }
    if (pressed) {
        if (!gtk_widget_has_focus(widget)) gtk_widget_grab_focus(widget);
        activate_grid_context(context);
    }
    if (pressed && event->button == 3 && hyperlink_point &&
        show_hyperlink_menu(
            context, event, hyperlink_column, hyperlink_row))
        return TRUE;
    if (pressed && event->button == 3) {
        show_workspace_menu(context, event);
        return TRUE;
    }
    if (route == NOCTTY_GRID_ROUTE_SELECTION) {
        if (pressed) {
            context->selecting = 0;
            context->selection_dragging = 1;
            context->selection_start_column = column;
            context->selection_start_row = row;
            context->selection_end_column = column;
            context->selection_end_row = row;
        } else {
            context->selection_end_column = column;
            context->selection_end_row = row;
            context->selection_dragging = 0;
            context->selecting =
                context->selection_start_column != context->selection_end_column ||
                context->selection_start_row != context->selection_end_row;
        }
        gtk_widget_queue_draw(context->area);
        return TRUE;
    }
    if (route != NOCTTY_GRID_ROUTE_APPLICATION_MOUSE) return TRUE;
    acknowledge_grid_attention(context);
    int delivered = context->mouse(
        context->userdata, column, row, button, pressed);
    if (delivered <= 0) {
        show_status_feedback(
            context, "The application did not accept pointer input.");
    } else {
        schedule_grid_write_flush(context);
    }
    return TRUE;
}

static gboolean on_mouse_motion(GtkWidget *widget, GdkEventMotion *event,
                                gpointer user_data);

static NocttyGridContext *focus_click_smoke_target(
    NocttyGridContext *root, gboolean primary) {
    if (root->contexts == NULL || root->contexts->len < 2) return NULL;
    guint index = primary ? 0 : root->contexts->len - 1;
    NocttyGridContext *target = g_ptr_array_index(root->contexts, index);
    return grid_context_session_available(target) ? target : NULL;
}

static gboolean focus_click_smoke_surface_ready(
    NocttyGridContext *root, NocttyGridContext *target) {
    if (root->window == NULL || target == NULL || target->area == NULL ||
        !root->window_presented || !gtk_widget_get_mapped(root->window) ||
        !gtk_widget_get_mapped(target->area))
        return FALSE;
    if (!root->layer_shell_active &&
        !gtk_window_is_active(GTK_WINDOW(root->window)))
        gtk_window_present(GTK_WINDOW(root->window));
    return TRUE;
}

static void emit_focus_click_smoke(NocttyGridContext *target) {
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

static gboolean inspect_focus_click_smoke(NocttyGridContext *root,
                                          NocttyGridContext *target,
                                          const char *command,
                                          int *verified) {
    if (gtk_window_get_focus(GTK_WINDOW(root->window)) != target->area ||
        !target->focused)
        return FALSE;
    *verified = !target->selection_dragging && !target->selecting &&
        target->write(target->userdata, command, strlen(command)) >= 0;
    return TRUE;
}

static gboolean drive_focus_click_smoke(gpointer user_data);

static gboolean wait_for_focus_click_smoke(NocttyGridContext *root) {
    if (root->focus_click_smoke_attempts++ < 80) {
        g_timeout_add(25, drive_focus_click_smoke, root);
        return G_SOURCE_REMOVE;
    }
    g_printerr("native_grid_click_focus_timeout stage=%d mapped=%d active=%d contexts=%u\n",
               root->focus_click_smoke_stage,
               root->window != NULL && gtk_widget_get_mapped(root->window),
               root->window != NULL && gtk_window_is_active(GTK_WINDOW(root->window)),
               root->contexts != NULL ? root->contexts->len : 0);
    root->focus_click_smoke_attempts = 0;
    root->focus_click_smoke_stage = NOCTTY_FOCUS_SMOKE_RELEASE;
    g_idle_add(drive_focus_click_smoke, root);
    return G_SOURCE_REMOVE;
}

static void emit_zoom_double_click(NocttyGridContext *target,
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

static void run_zoom_selection_smoke(NocttyGridContext *root) {
    NocttyGridContext *target = g_ptr_array_index(root->contexts,
                                                  root->contexts->len - 1);
    clear_grid_selection(target);
    GtkWidget *split = gtk_widget_get_parent(target->area);
    int original_split_position = GTK_IS_PANED(split)
        ? gtk_paned_get_position(GTK_PANED(split)) : -1;
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
        (!GTK_IS_PANED(split) ||
         gtk_paned_get_position(GTK_PANED(split)) == original_split_position);
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
        NocttyGridFontMetrics metrics = grid_font_metrics(target);
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
    NocttyGridContext *root = root_grid_context(user_data);
    gboolean primary =
        root->focus_click_smoke_stage <= NOCTTY_FOCUS_SMOKE_PRIMARY_CHECK;
    NocttyGridContext *target = focus_click_smoke_target(root, primary);

    if (root->focus_click_smoke_stage == NOCTTY_FOCUS_SMOKE_RELEASE) {
        guint expected = 0;
        guint released = 0;
        for (guint index = 0; root->contexts != NULL &&
             index < root->contexts->len; index++) {
            NocttyGridContext *candidate =
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

    if (root->focus_click_smoke_stage == NOCTTY_FOCUS_SMOKE_PRIMARY_ACTION ||
        root->focus_click_smoke_stage == NOCTTY_FOCUS_SMOKE_SECONDARY_ACTION) {
        emit_focus_click_smoke(target);
        root->focus_click_smoke_attempts = 0;
        root->focus_click_smoke_stage++;
        g_timeout_add(25, drive_focus_click_smoke, root);
        return G_SOURCE_REMOVE;
    }

    if (root->focus_click_smoke_stage == NOCTTY_FOCUS_SMOKE_PRIMARY_CHECK ||
        root->focus_click_smoke_stage == NOCTTY_FOCUS_SMOKE_SECONDARY_CHECK) {
        const char *command = primary
            ? "printf 'NOCTTY_FOCUS_PRIMARY'\n"
            : "printf 'NOCTTY_FOCUS_SECONDARY'\n";
        int *verified = primary
            ? &root->focus_click_primary
            : &root->focus_click_secondary;
        if (!inspect_focus_click_smoke(root, target, command, verified))
            return wait_for_focus_click_smoke(root);
        root->focus_click_smoke_attempts = 0;
        root->focus_click_smoke_stage++;
        g_timeout_add(50, drive_focus_click_smoke, root);
        return G_SOURCE_REMOVE;
    }

    run_zoom_selection_smoke(root);
    root->focus_click_smoke_attempts = 0;
    root->focus_click_smoke_stage = NOCTTY_FOCUS_SMOKE_RELEASE;
    g_timeout_add(50, drive_focus_click_smoke, root);
    return G_SOURCE_REMOVE;
}

static void restore_settings_parent_layer(NocttyGridContext *context);

static void on_settings_destroy(GtkWidget *widget, gpointer user_data) {
    (void)widget;
    NocttyGridContext *context = root_grid_context(user_data);
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

typedef gboolean (*NocttyLayerIsSupported)(void);
typedef guint (*NocttyLayerGetProtocolVersion)(void);
typedef void (*NocttyLayerInitForWindow)(GtkWindow *);
typedef void (*NocttyLayerSetNamespace)(GtkWindow *, const char *);
typedef void (*NocttyLayerSetMonitor)(GtkWindow *, GdkMonitor *);
typedef void (*NocttyLayerSetInt)(GtkWindow *, int);
typedef int (*NocttyLayerGetInt)(GtkWindow *);
typedef gboolean (*NocttyLayerIsLayerWindow)(GtkWindow *);
typedef void (*NocttyLayerSetEdge)(GtkWindow *, int, gboolean);
typedef void (*NocttyLayerSetMargin)(GtkWindow *, int, int);

static void set_grid_layer_keyboard_active(NocttyGridContext *context,
                                           gboolean active) {
    NocttyGridContext *root = root_grid_context(context);
    if (!root->layer_shell_active || root->layer_shell_library == NULL ||
        root->window == NULL || gtk_widget_in_destruction(root->window))
        return;
    NocttyLayerSetInt set_keyboard_mode =
        (NocttyLayerSetInt)dlsym(root->layer_shell_library,
                                 "gtk_layer_set_keyboard_mode");
    if (set_keyboard_mode == NULL) return;
    set_keyboard_mode(GTK_WINDOW(root->window),
                      active ? root->layer_shell_keyboard_mode : 0);
}

static GdkMonitor *grid_monitor_for_window(GtkWidget *window) {
    GdkDisplay *display = gtk_widget_get_display(window);
    GdkWindow *gdk_window = gtk_widget_get_window(window);
    GdkMonitor *monitor = gdk_window != NULL
        ? gdk_display_get_monitor_at_window(display, gdk_window)
        : NULL;
    if (monitor == NULL) monitor = gdk_display_get_primary_monitor(display);
    if (monitor == NULL) {
        GdkSeat *seat = gdk_display_get_default_seat(display);
        GdkDevice *pointer = seat != NULL ? gdk_seat_get_pointer(seat) : NULL;
        gint x = 0;
        gint y = 0;
        if (pointer != NULL) {
            gdk_device_get_position(pointer, NULL, &x, &y);
            monitor = gdk_display_get_monitor_at_point(display, x, y);
        }
    }
    if (monitor == NULL && gdk_display_get_n_monitors(display) > 0)
        monitor = gdk_display_get_monitor(display, 0);
    return monitor;
}

static gboolean grid_monitor_metrics(
    GtkWidget *window, GdkMonitor **monitor_output,
    GdkRectangle *geometry_output, GdkRectangle *workarea_output,
    int *scale_factor_output) {
    GdkMonitor *monitor = grid_monitor_for_window(window);
    if (monitor == NULL) return FALSE;
    if (monitor_output != NULL) *monitor_output = monitor;
    if (geometry_output != NULL) gdk_monitor_get_geometry(monitor, geometry_output);
    if (workarea_output != NULL) gdk_monitor_get_workarea(monitor, workarea_output);
    if (scale_factor_output != NULL)
        *scale_factor_output = MAX(1, gdk_monitor_get_scale_factor(monitor));
    return TRUE;
}

static void apply_grid_layer_geometry(NocttyGridContext *context) {
    NocttyGridContext *root = root_grid_context(context);
    if (!root->layer_shell_active || root->layer_shell_library == NULL) return;
    NocttyLayerSetNamespace set_namespace =
        (NocttyLayerSetNamespace)dlsym(root->layer_shell_library,
                                        "gtk_layer_set_namespace");
    NocttyLayerSetEdge set_anchor =
        (NocttyLayerSetEdge)dlsym(root->layer_shell_library,
                                  "gtk_layer_set_anchor");
    NocttyLayerSetMargin set_margin =
        (NocttyLayerSetMargin)dlsym(root->layer_shell_library,
                                    "gtk_layer_set_margin");
    if (set_namespace == NULL || set_anchor == NULL || set_margin == NULL) return;

    GdkMonitor *monitor = grid_monitor_for_window(root->window);
    GdkRectangle geometry = {0, 0, 900, 420};
    if (monitor != NULL) gdk_monitor_get_geometry(monitor, &geometry);
    NocttyLayerSetMonitor set_monitor =
        (NocttyLayerSetMonitor)dlsym(root->layer_shell_library,
                                     "gtk_layer_set_monitor");
    if (set_monitor != NULL && monitor != NULL &&
        monitor != root->layer_shell_monitor) {
        set_monitor(GTK_WINDOW(root->window), monitor);
        root->layer_shell_monitor = monitor;
    }
    int width = noctty_grid_dropdown_dimension(
        root->dropdown_width_px, root->dropdown_width_percent,
        geometry.width, NOCTTY_DROPDOWN_MIN_WIDTH_PX);
    int height = noctty_grid_dropdown_dimension(
        root->dropdown_height_px, root->dropdown_height_percent,
        geometry.height, NOCTTY_DROPDOWN_MIN_HEIGHT_PX);
    int horizontal_margin = MAX(0, (geometry.width - width) / 2);
    int horizontal_remainder = MAX(0, geometry.width - width - horizontal_margin);

    for (int edge = 0; edge < 4; edge++) {
        set_anchor(GTK_WINDOW(root->window), edge, FALSE);
        set_margin(GTK_WINDOW(root->window), edge, 0);
    }
    if (root->mode == 0) {
        set_namespace(GTK_WINDOW(root->window), "noctty-dropdown");
        set_anchor(GTK_WINDOW(root->window), 0, TRUE);
        set_anchor(GTK_WINDOW(root->window), 1, TRUE);
        set_anchor(GTK_WINDOW(root->window), 2, TRUE);
        set_anchor(GTK_WINDOW(root->window), 3, TRUE);
        set_margin(GTK_WINDOW(root->window), 0, horizontal_margin);
        set_margin(GTK_WINDOW(root->window), 1, horizontal_remainder);
        set_margin(GTK_WINDOW(root->window), 3,
                   MAX(0, geometry.height - height));
        gtk_widget_set_size_request(root->window, width, height);
    } else if (root->mode == 2) {
        set_namespace(GTK_WINDOW(root->window), "noctty-zen");
        for (int edge = 0; edge < 4; edge++)
            set_anchor(GTK_WINDOW(root->window), edge, TRUE);
        gtk_widget_set_size_request(root->window, -1, -1);
    } else {
        set_namespace(GTK_WINDOW(root->window), "noctty-window");
        gtk_widget_set_size_request(root->window,
                                    MAX(480, geometry.width * 80 / 100),
                                    MAX(320, geometry.height * 75 / 100));
    }
}

static int configure_grid_layer_shell(NocttyGridContext *context) {
    NocttyGridContext *root = root_grid_context(context);
    if (root->mode != 0 || !root->layer_shell_allowed ||
        !GDK_IS_WAYLAND_DISPLAY(gtk_widget_get_display(root->window))) return 0;
    if (root->layer_shell_library == NULL)
        root->layer_shell_library = dlopen("libgtk-layer-shell.so.0",
                                           RTLD_NOW | RTLD_LOCAL);
    if (root->layer_shell_library == NULL) return 0;

    NocttyLayerIsSupported is_supported =
        (NocttyLayerIsSupported)dlsym(root->layer_shell_library,
                                      "gtk_layer_is_supported");
    NocttyLayerGetProtocolVersion get_protocol_version =
        (NocttyLayerGetProtocolVersion)dlsym(
            root->layer_shell_library, "gtk_layer_get_protocol_version");
    NocttyLayerInitForWindow init_for_window =
        (NocttyLayerInitForWindow)dlsym(root->layer_shell_library,
                                        "gtk_layer_init_for_window");
    NocttyLayerSetMonitor set_monitor =
        (NocttyLayerSetMonitor)dlsym(root->layer_shell_library,
                                     "gtk_layer_set_monitor");
    NocttyLayerSetInt set_layer =
        (NocttyLayerSetInt)dlsym(root->layer_shell_library,
                                 "gtk_layer_set_layer");
    NocttyLayerSetInt set_keyboard_mode =
        (NocttyLayerSetInt)dlsym(root->layer_shell_library,
                                 "gtk_layer_set_keyboard_mode");
    NocttyLayerSetInt set_exclusive_zone =
        (NocttyLayerSetInt)dlsym(root->layer_shell_library,
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
    g_debug("NOCTTY dropdown layer-shell active protocol=%u keyboard_mode=%s",
            protocol_version,
            root->layer_shell_keyboard_mode == 2 ? "on-demand" : "exclusive");
    return 1;
}

static void restore_settings_parent_layer(NocttyGridContext *context) {
    NocttyGridContext *root = root_grid_context(context);
    if (root->overlay_dialog_count != 0) return;
    if (!root->settings_parent_layer_lowered) return;
    root->settings_parent_layer_lowered = 0;
    if (!root->layer_shell_active || root->layer_shell_library == NULL ||
        root->window == NULL || gtk_widget_in_destruction(root->window))
        return;
    NocttyLayerSetInt set_layer =
        (NocttyLayerSetInt)dlsym(root->layer_shell_library,
                                 "gtk_layer_set_layer");
    NocttyLayerGetInt get_layer =
        (NocttyLayerGetInt)dlsym(root->layer_shell_library,
                                 "gtk_layer_get_layer");
    if (set_layer == NULL || get_layer == NULL) return;
    set_layer(GTK_WINDOW(root->window), 2);
    root->settings_parent_layer_restored =
        get_layer(GTK_WINDOW(root->window)) == 2;
}

static void on_overlay_window_destroy(GtkWidget *widget,
                                      gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    if (g_object_get_data(G_OBJECT(widget),
                          "noctty-overlay-window") == NULL)
        return;
    g_object_set_data(G_OBJECT(widget), "noctty-overlay-window", NULL);
    if (root->overlay_dialog_count > 0) root->overlay_dialog_count--;
    restore_settings_parent_layer(root);
}

static gboolean configure_overlay_window_stacking(
    NocttyGridContext *context, GtkWidget *dialog,
    const char *namespace_name) {
    NocttyGridContext *root = root_grid_context(context);
    if (!GTK_IS_WINDOW(dialog) || !GTK_IS_WINDOW(root->window)) return FALSE;

    gtk_window_set_transient_for(GTK_WINDOW(dialog), GTK_WINDOW(root->window));
    gtk_window_set_destroy_with_parent(GTK_WINDOW(dialog), TRUE);
    gtk_window_set_type_hint(GTK_WINDOW(dialog), GDK_WINDOW_TYPE_HINT_DIALOG);
    gtk_window_set_keep_above(GTK_WINDOW(dialog), TRUE);
    root->settings_transient_parent =
        gtk_window_get_transient_for(GTK_WINDOW(dialog)) ==
        GTK_WINDOW(root->window);
    root->settings_keep_above = 1;
    root->settings_layer_overlay = 0;
    root->settings_parent_layer_lowered =
        root->overlay_dialog_count > 0 ? 1 : 0;
    root->settings_parent_layer_restored = !root->layer_shell_active;

    if (g_object_get_data(G_OBJECT(dialog),
                          "noctty-overlay-window") != NULL) {
        root->settings_layer_overlay = 1;
        return TRUE;
    }

    if (!root->layer_shell_active || root->layer_shell_library == NULL)
        return root->settings_transient_parent && root->settings_keep_above;

    NocttyLayerInitForWindow init_for_window =
        (NocttyLayerInitForWindow)dlsym(root->layer_shell_library,
                                        "gtk_layer_init_for_window");
    NocttyLayerIsLayerWindow is_layer_window =
        (NocttyLayerIsLayerWindow)dlsym(root->layer_shell_library,
                                        "gtk_layer_is_layer_window");
    NocttyLayerSetNamespace set_namespace =
        (NocttyLayerSetNamespace)dlsym(root->layer_shell_library,
                                        "gtk_layer_set_namespace");
    NocttyLayerSetInt set_layer =
        (NocttyLayerSetInt)dlsym(root->layer_shell_library,
                                 "gtk_layer_set_layer");
    NocttyLayerGetInt get_layer =
        (NocttyLayerGetInt)dlsym(root->layer_shell_library,
                                 "gtk_layer_get_layer");
    NocttyLayerSetInt set_keyboard_mode =
        (NocttyLayerSetInt)dlsym(root->layer_shell_library,
                                 "gtk_layer_set_keyboard_mode");
    NocttyLayerSetInt set_exclusive_zone =
        (NocttyLayerSetInt)dlsym(root->layer_shell_library,
                                 "gtk_layer_set_exclusive_zone");
    NocttyLayerSetMonitor set_monitor =
        (NocttyLayerSetMonitor)dlsym(root->layer_shell_library,
                                     "gtk_layer_set_monitor");
    if (init_for_window == NULL || is_layer_window == NULL ||
        set_namespace == NULL || set_layer == NULL || get_layer == NULL ||
        set_keyboard_mode == NULL || set_exclusive_zone == NULL)
        return FALSE;

    init_for_window(GTK_WINDOW(dialog));
    if (root->overlay_dialog_count == 0) {
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
    g_object_set_data(G_OBJECT(dialog), "noctty-overlay-window",
                      GINT_TO_POINTER(1));
    g_signal_connect(dialog, "destroy",
                     G_CALLBACK(on_overlay_window_destroy), root);
    return TRUE;
}

static void configure_overlay_window_geometry(
    NocttyGridContext *context, GtkWidget *window,
    const GdkRectangle *workarea, int width, int height) {
    NocttyGridContext *root = root_grid_context(context);
    if (!root->layer_shell_active || root->layer_shell_library == NULL ||
        g_object_get_data(G_OBJECT(window),
                          "noctty-overlay-window") == NULL)
        return;

    NocttyLayerSetEdge set_anchor =
        (NocttyLayerSetEdge)dlsym(root->layer_shell_library,
                                  "gtk_layer_set_anchor");
    NocttyLayerSetMargin set_margin =
        (NocttyLayerSetMargin)dlsym(root->layer_shell_library,
                                    "gtk_layer_set_margin");
    if (set_anchor == NULL || set_margin == NULL) return;

    GdkRectangle monitor_geometry = *workarea;
    GdkMonitor *monitor = grid_monitor_for_window(root->window);
    if (monitor != NULL) gdk_monitor_get_geometry(monitor, &monitor_geometry);
    int left = MAX(0, workarea->x - monitor_geometry.x +
                          (workarea->width - width) / 2);
    int top = MAX(0, workarea->y - monitor_geometry.y +
                         (workarea->height - height) / 2);
    int right = MAX(0, monitor_geometry.width - left - width);
    int bottom = MAX(0, monitor_geometry.height - top - height);
    for (int edge = 0; edge < 4; edge++)
        set_anchor(GTK_WINDOW(window), edge, TRUE);
    set_margin(GTK_WINDOW(window), 0, left);
    set_margin(GTK_WINDOW(window), 1, right);
    set_margin(GTK_WINDOW(window), 2, top);
    set_margin(GTK_WINDOW(window), 3, bottom);
}

static void apply_dropdown_dimensions(NocttyGridContext *context) {
    NocttyGridContext *root = root_grid_context(context);
    if (root->layer_shell_active) {
        apply_grid_layer_geometry(root);
        return;
    }
    GdkMonitor *monitor = grid_monitor_for_window(root->window);
    GdkRectangle workarea = {0, 0, 900, 420};
    if (monitor != NULL) gdk_monitor_get_workarea(monitor, &workarea);
    int width = noctty_grid_dropdown_dimension(
        root->dropdown_width_px, root->dropdown_width_percent,
        workarea.width, NOCTTY_DROPDOWN_MIN_WIDTH_PX);
    int height = noctty_grid_dropdown_dimension(
        root->dropdown_height_px, root->dropdown_height_percent,
        workarea.height, NOCTTY_DROPDOWN_MIN_HEIGHT_PX);
    gtk_window_resize(GTK_WINDOW(root->window), width, height);
    if (root->mode == 0)
        gtk_window_move(GTK_WINDOW(root->window),
                        workarea.x + (workarea.width - width) / 2, workarea.y);
}

static void apply_window_dimensions(NocttyGridContext *context) {
    NocttyGridContext *root = root_grid_context(context);
    GdkMonitor *monitor = grid_monitor_for_window(root->window);
    GdkRectangle workarea = {0, 0, 900, 420};
    if (monitor != NULL) gdk_monitor_get_workarea(monitor, &workarea);
    int width = noctty_grid_percent_dimension(workarea.width, 80, 480);
    int height = noctty_grid_percent_dimension(workarea.height, 75, 320);
    gtk_widget_set_size_request(root->window, -1, -1);
    gtk_window_resize(GTK_WINDOW(root->window), width, height);
}

static void apply_fullscreen_dimensions(NocttyGridContext *context) {
    NocttyGridContext *root = root_grid_context(context);
    if (!GTK_IS_WINDOW(root->window)) return;
    gtk_widget_set_size_request(root->window, -1, -1);
    GdkDisplay *display = gtk_widget_get_display(root->window);
    GdkMonitor *monitor = grid_monitor_for_window(root->window);
    int monitor_index = -1;
    for (int index = 0; monitor != NULL && display != NULL &&
         index < gdk_display_get_n_monitors(display); index++) {
        if (gdk_display_get_monitor(display, index) == monitor) {
            monitor_index = index;
            break;
        }
    }
    GdkWindow *gdk_window = gtk_widget_get_window(root->window);
    if (gdk_window == NULL) {
        gtk_window_fullscreen(GTK_WINDOW(root->window));
    } else {
        gdk_window_set_fullscreen_mode(
            gdk_window, GDK_FULLSCREEN_ON_CURRENT_MONITOR);
        if (!GDK_IS_WAYLAND_DISPLAY(display) && monitor_index >= 0)
            gdk_window_fullscreen_on_monitor(gdk_window, monitor_index);
        else
            gdk_window_fullscreen(gdk_window);
    }
}

static void schedule_resolution_adapt(NocttyGridContext *context) {
    NocttyGridContext *root = root_grid_context(context);
    if (root->resolution_adapt_source == 0)
        root->resolution_adapt_source =
            g_idle_add(adapt_window_to_resolution, root);
}

static gboolean adapt_window_to_resolution(gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    root->resolution_adapt_source = 0;
    if (!GTK_IS_WINDOW(root->window)) return G_SOURCE_REMOVE;
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
    gtk_window_get_position(GTK_WINDOW(root->window), &current_x, &current_y);
    gtk_window_get_size(GTK_WINDOW(root->window),
                        &current_width, &current_height);
    const GdkRectangle *dropdown_space =
        root->layer_shell_active ? &monitor_geometry : &workarea;
    int dropdown_width = noctty_grid_dropdown_dimension(
        root->dropdown_width_px, root->dropdown_width_percent,
        dropdown_space->width, NOCTTY_DROPDOWN_MIN_WIDTH_PX);
    int dropdown_height = noctty_grid_dropdown_dimension(
        root->dropdown_height_px, root->dropdown_height_percent,
        dropdown_space->height, NOCTTY_DROPDOWN_MIN_HEIGHT_PX);
    NocttyGridAdaptiveWindowGeometry geometry;
    if (!noctty_grid_adapt_window_geometry(
            root->mode, current_x, current_y, current_width, current_height,
            workarea.x, workarea.y, workarea.width, workarea.height,
            dropdown_width, dropdown_height, &geometry))
        return G_SOURCE_REMOVE;
    if (root->mode == 0 && root->layer_shell_active) {
        apply_grid_layer_geometry(root);
    } else if (root->mode == 2) {
        apply_fullscreen_dimensions(root);
    } else {
        gtk_window_resize(
            GTK_WINDOW(root->window), geometry.width, geometry.height);
        gtk_window_move(GTK_WINDOW(root->window), geometry.x, geometry.y);
    }
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        NocttyGridContext *candidate =
            g_ptr_array_index(root->contexts, index);
        if (candidate->active && candidate->area != NULL)
            gtk_widget_queue_resize(candidate->area);
    }
    return G_SOURCE_REMOVE;
}

static gboolean on_window_resolution_configure(
    GtkWidget *widget, GdkEventConfigure *event, gpointer user_data) {
    (void)event;
    NocttyGridContext *root = root_grid_context(user_data);
    GdkRectangle geometry = {0};
    GdkRectangle workarea = {0};
    int scale_factor = 1;
    if (!grid_monitor_metrics(widget, NULL, &geometry, &workarea,
                              &scale_factor))
        return FALSE;
    gboolean changed = geometry.x != root->monitor_geometry_x ||
        geometry.y != root->monitor_geometry_y ||
        geometry.width != root->monitor_geometry_width ||
        geometry.height != root->monitor_geometry_height ||
        workarea.x != root->monitor_workarea_x ||
        workarea.y != root->monitor_workarea_y ||
        workarea.width != root->monitor_workarea_width ||
        workarea.height != root->monitor_workarea_height ||
        scale_factor != root->monitor_scale_factor;
    if (changed) schedule_resolution_adapt(root);
    return FALSE;
}

static void on_screen_geometry_changed(GdkScreen *screen,
                                       gpointer user_data) {
    (void)screen;
    GtkWidget *window = GTK_WIDGET(user_data);
    NocttyGridContext *root = g_object_get_data(
        G_OBJECT(window), "noctty-grid-root-context");
    if (root != NULL) schedule_resolution_adapt(root);
}

static void on_window_map(GtkWidget *widget, gpointer user_data) {
    (void)widget;
    NocttyGridContext *root = root_grid_context(user_data);
    root->window_map_count++;
    schedule_resolution_adapt(root);
#if NOCTTY_ENABLE_SMOKE
    if (root->workspace_smoke == 44 || root->workspace_smoke == 45) {
        g_printerr(
            "native_grid_resolution_window_ready mode=%s layer_shell=%s\n",
            root->mode == 0 ? "dropdown" : "fullscreen",
            root->layer_shell_active ? "true" : "false");
    }
#endif
}

static GtkWidget *create_grid_toplevel(NocttyGridContext *context) {
    NocttyGridContext *root = root_grid_context(context);
    GtkWidget *window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    GdkScreen *screen = gtk_widget_get_screen(window);
    GdkVisual *visual = screen != NULL
        ? gdk_screen_get_rgba_visual(screen) : NULL;
    gboolean wayland = GDK_IS_WAYLAND_DISPLAY(
        gtk_widget_get_display(window));
    root->background_alpha_supported = visual != NULL && screen != NULL &&
        (wayland || gdk_screen_is_composited(screen));
    if (root->background_alpha_supported) {
        gtk_widget_set_visual(window, visual);
        gtk_widget_set_app_paintable(window, TRUE);
    }
    gtk_style_context_add_class(
        gtk_widget_get_style_context(window), "noctty-terminal-window");
    // Install transparent root/container CSS before the first realization.
    // Installing it later with the notebook lets Wayland commit an opaque
    // initial buffer and opaque region that only changes when a modal maps.
    install_compact_tab_styles(window);
    root->translucent_surface_ready =
        g_object_get_data(G_OBJECT(window),
                          "noctty-style-provider-installed") != NULL &&
        gtk_style_context_has_class(gtk_widget_get_style_context(window),
                                    "noctty-terminal-window") &&
        (!root->background_alpha_supported ||
         gtk_widget_get_app_paintable(window));
    gtk_window_set_icon_name(GTK_WINDOW(window), "com.noctty.NOCTTY");
    root->application_icon_ready = g_strcmp0(
        gtk_window_get_icon_name(GTK_WINDOW(window)),
        "com.noctty.NOCTTY") == 0;
    set_grid_window_title(
        root,
        window,
        root->workspace_smoke == 44
            ? "NOCTTY resolution dropdown qualification"
            : root->workspace_smoke == 45
                ? "NOCTTY resolution fullscreen qualification"
                : root->workspace_smoke == 39
                    ? "NOCTTY installed continuity qualification"
                    : "NOCTTY native grid");
    gtk_window_set_default_size(GTK_WINDOW(window), 1100, 640);
    gtk_window_set_decorated(GTK_WINDOW(window), root->mode == 1);
    gtk_window_set_resizable(GTK_WINDOW(window), TRUE);
    gtk_window_set_keep_above(GTK_WINDOW(window), root->mode == 0);
    g_object_set_data(G_OBJECT(window), "noctty-grid-root-context", root);
    if (screen != NULL) {
        g_signal_connect_object(
            screen, "size-changed", G_CALLBACK(on_screen_geometry_changed),
            window, 0);
        g_signal_connect_object(
            screen, "monitors-changed",
            G_CALLBACK(on_screen_geometry_changed), window, 0);
    }
    g_signal_connect(window, "delete-event",
                     G_CALLBACK(on_window_delete_event), root);
    g_signal_connect(window, "destroy", G_CALLBACK(on_window_destroy), NULL);
    g_signal_connect(window, "focus-out-event",
                     G_CALLBACK(on_window_focus_out), root);
    g_signal_connect(window, "map", G_CALLBACK(on_window_map), root);
    g_signal_connect(window, "configure-event",
                     G_CALLBACK(on_window_resolution_configure), root);
    g_signal_connect(window, "button-release-event",
                     G_CALLBACK(on_window_resize_handle_release), root);
    return window;
}

static gboolean recreate_grid_toplevel_idle(gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    root->window_mode_recreate_source = 0;
    GtkWidget *old_window = root->window;
    GtkWidget *layout = root->window_layout;
    if (!GTK_IS_WINDOW(old_window) || layout == NULL ||
        gtk_widget_in_destruction(old_window))
        return G_SOURCE_REMOVE;

    gboolean was_presented = root->window_presented &&
        gtk_widget_get_visible(old_window);
    NocttyGridContext *title_context = active_grid_context(root);
    const char *title = title_context != NULL
        ? title_context->display_title : NULL;
    gboolean reopen_settings = GTK_IS_WINDOW(root->settings_dialog) &&
        gtk_widget_get_visible(root->settings_dialog);
    if (reopen_settings) gtk_widget_destroy(root->settings_dialog);
    dismiss_grid_popup_windows(root);
    while (gtk_events_pending()) gtk_main_iteration_do(FALSE);

    g_signal_handlers_disconnect_by_func(
        old_window, G_CALLBACK(on_window_delete_event), root);
    g_signal_handlers_disconnect_by_func(
        old_window, G_CALLBACK(on_window_focus_out), root);
    g_signal_handlers_disconnect_by_func(
        old_window, G_CALLBACK(on_window_destroy), NULL);
    gtk_widget_hide(old_window);
    g_object_ref(layout);
    gtk_container_remove(GTK_CONTAINER(old_window), layout);

    root->layer_shell_active = 0;
    root->layer_shell_monitor = NULL;
    root->window = create_grid_toplevel(root);
    if (title != NULL) set_grid_window_title(root, root->window, title);
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++)
        ((NocttyGridContext *)g_ptr_array_index(root->contexts, index))
            ->window = root->window;
    gtk_container_add(GTK_CONTAINER(root->window), layout);
    g_object_unref(layout);

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
    if (!was_presented) gtk_widget_hide(root->window);
    else {
        root->window_presented = 1;
        if (!root->layer_shell_active)
            gtk_window_present(GTK_WINDOW(root->window));
        NocttyGridContext *focus_target = active_grid_context(root);
        if (focus_target != NULL) defer_grid_context_focus(focus_target);
    }
    gtk_widget_destroy(old_window);
    if (reopen_settings && was_presented) {
        open_grid_settings(root);
        root->settings_reopened_after_mode_change =
            GTK_IS_WINDOW(root->settings_dialog) &&
            gtk_widget_get_visible(root->settings_dialog);
    }
    root->window_mode_surface_recreated = 1;
    return G_SOURCE_REMOVE;
}

static void sync_compact_setting(NocttyGridContext *context, int field, int value) {
    NocttyGridContext *root = root_grid_context(context);
    for (guint index = 0; root->contexts != NULL && index < root->contexts->len; index++) {
        NocttyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (field == 0) candidate->dropdown_width_percent = value;
        else if (field == 1) candidate->dropdown_height_percent = value;
        else if (field == 2) candidate->dropdown_animation_ms = value;
        else if (field == 14) candidate->dropdown_width_px = value;
        else if (field == 15) candidate->dropdown_height_px = value;
        else if (field == 3) candidate->hide_on_focus_loss = value;
        else if (field == 4) candidate->focus_follows_pointer = value;
        else if (field == 5) candidate->show_pane_info = value;
    }
}

static gboolean normalize_dropdown_pixel_dimensions(
    NocttyGridContext *context, gboolean notify) {
    NocttyGridContext *root = root_grid_context(context);
    if (root->dropdown_width_px <= 0 && root->dropdown_height_px <= 0)
        return FALSE;
    GdkMonitor *monitor = grid_monitor_for_window(root->window);
    if (monitor == NULL) return FALSE;
    GdkRectangle available = {0};
    if (root->layer_shell_active)
        gdk_monitor_get_geometry(monitor, &available);
    else
        gdk_monitor_get_workarea(monitor, &available);
    int width_percent = noctty_grid_dropdown_percent(
        root->dropdown_width_px, available.width,
        root->dropdown_width_percent);
    int height_percent = noctty_grid_dropdown_percent(
        root->dropdown_height_px, available.height,
        root->dropdown_height_percent);
    sync_compact_setting(root, 0, width_percent);
    sync_compact_setting(root, 1, height_percent);
    sync_compact_setting(root, 14, 0);
    sync_compact_setting(root, 15, 0);
    if (notify && root->event != NULL) {
        uint64_t timestamp =
            (uint64_t)(g_get_monotonic_time() / 1000);
        root->event(root->event_data, root->pane_id, 76,
                    width_percent, timestamp);
        root->event(root->event_data, root->pane_id, 77,
                    height_percent, timestamp);
    }
    return TRUE;
}

static void apply_pane_info_visibility(NocttyGridContext *context,
                                       int enabled) {
    NocttyGridContext *root = root_grid_context(context);
    sync_compact_setting(root, 5, enabled);
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++)
        ((NocttyGridContext *)g_ptr_array_index(root->contexts, index))
            ->show_pane_info = enabled != 0;
    noctty_pane_info_strip_set_enabled(root->pane_info_strip, enabled);
    update_window_resize_handles(root);
    if (enabled) refresh_active_pane_info(root);
}

static void on_settings_dropdown_width_changed(GtkSpinButton *spin, gpointer user_data) {
    NocttyGridContext *context = user_data;
    int value = gtk_spin_button_get_value_as_int(spin);
    sync_compact_setting(context, 0, value);
    sync_compact_setting(context, 14, 0);
    sync_compact_setting(context, 15, 0);
    apply_dropdown_dimensions(context);
    if (context->event != NULL) context->event(context->event_data, context->pane_id, 76, value, (uint64_t)(g_get_monotonic_time() / 1000));
}

static void on_settings_dropdown_height_changed(GtkSpinButton *spin, gpointer user_data) {
    NocttyGridContext *context = user_data;
    int value = gtk_spin_button_get_value_as_int(spin);
    sync_compact_setting(context, 1, value);
    sync_compact_setting(context, 14, 0);
    sync_compact_setting(context, 15, 0);
    apply_dropdown_dimensions(context);
    if (context->event != NULL) context->event(context->event_data, context->pane_id, 77, value, (uint64_t)(g_get_monotonic_time() / 1000));
}

static void on_settings_animation_changed(GtkSpinButton *spin, gpointer user_data) {
    NocttyGridContext *context = user_data;
    int value = gtk_spin_button_get_value_as_int(spin);
    sync_compact_setting(context, 2, value);
    NocttyGridContext *root = root_grid_context(context);
    if (root->revealer != NULL)
        gtk_revealer_set_transition_duration(GTK_REVEALER(root->revealer),
                                             (guint)value);
    if (context->event != NULL) context->event(context->event_data, context->pane_id, 72, value, (uint64_t)(g_get_monotonic_time() / 1000));
}

static void on_settings_hide_focus_toggled(GtkToggleButton *toggle, gpointer user_data) {
    NocttyGridContext *context = user_data;
    int value = gtk_toggle_button_get_active(toggle);
    sync_compact_setting(context, 3, value);
    if (context->event != NULL) context->event(context->event_data, context->pane_id, 73, value, (uint64_t)(g_get_monotonic_time() / 1000));
}

static void on_settings_focus_pointer_toggled(GtkToggleButton *toggle, gpointer user_data) {
    NocttyGridContext *context = user_data;
    int value = gtk_toggle_button_get_active(toggle);
    sync_compact_setting(context, 4, value);
    if (context->event != NULL) context->event(context->event_data, context->pane_id, 74, value, (uint64_t)(g_get_monotonic_time() / 1000));
}

static void on_settings_pane_info_toggled(GtkToggleButton *toggle,
                                          gpointer user_data) {
    NocttyGridContext *context = user_data;
    int value = gtk_toggle_button_get_active(toggle);
    apply_pane_info_visibility(context, value);
    root_grid_context(context)->pane_info_setting_toggled = 1;
    if (context->event != NULL)
        context->event(context->event_data, context->pane_id, 108, value,
                       (uint64_t)(g_get_monotonic_time() / 1000));
}

static void on_settings_scrollback_changed(GtkSpinButton *spin,
                                           gpointer user_data) {
    NocttyGridContext *context = user_data;
    int value = gtk_spin_button_get_value_as_int(spin);
    if (context->event != NULL)
        context->event(context->event_data, context->pane_id, 109, value,
                       (uint64_t)(g_get_monotonic_time() / 1000));
}

static void apply_terminal_scroll_setting(NocttyGridContext *context,
                                          int event_code, int value) {
    NocttyGridContext *root = root_grid_context(context);
    int resolved = noctty_grid_terminal_scroll_setting(event_code, value);
    if (resolved < 0) return;
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        NocttyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (event_code == 117)
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
        user_data, 117, gtk_spin_button_get_value_as_int(spin));
}

static void on_settings_smooth_scroll_toggled(GtkToggleButton *toggle,
                                              gpointer user_data) {
    apply_terminal_scroll_setting(
        user_data, 118, gtk_toggle_button_get_active(toggle));
}

static void on_settings_mode_changed(GtkComboBox *combo, gpointer user_data) {
    NocttyGridContext *context = user_data;
    int mode = gtk_combo_box_get_active(combo);
    if (mode < 0 || mode > 2) return;
    NocttyGridContext *root = root_grid_context(context);
    int previous_mode = root->mode;
    for (guint index = 0; root->contexts != NULL && index < root->contexts->len; index++)
        ((NocttyGridContext *)g_ptr_array_index(root->contexts, index))->mode = mode;
    if ((previous_mode == 0) != (mode == 0)) {
        if (root->window_mode_recreate_source == 0)
            root->window_mode_recreate_source =
                g_idle_add(recreate_grid_toplevel_idle, root);
        if (context->event != NULL) context->event(context->event_data, context->pane_id, 40, mode, (uint64_t)(g_get_monotonic_time() / 1000));
        return;
    }
    gtk_window_set_keep_above(GTK_WINDOW(root->window), mode == 0);
    gtk_window_set_decorated(GTK_WINDOW(root->window), mode == 1);
    gtk_window_set_resizable(GTK_WINDOW(root->window), TRUE);
    update_window_resize_handles(root);
    if (root->layer_shell_active) apply_grid_layer_geometry(root);
    else if (mode == 2) apply_fullscreen_dimensions(root);
    else {
        gtk_window_unfullscreen(GTK_WINDOW(root->window));
        if (mode == 1) apply_window_dimensions(root);
    }
    if (mode == 0) apply_dropdown_dimensions(root);
    if (context->event != NULL) context->event(context->event_data, context->pane_id, 40, mode, (uint64_t)(g_get_monotonic_time() / 1000));
}

static gboolean apply_grid_font_size(NocttyGridContext *context,
                                     double requested, gboolean notify) {
    NocttyGridContext *root = root_grid_context(context);
    double next = noctty_grid_font_size_clamp(
        requested, root->font_min_size, root->font_max_size);
    gboolean changed = FALSE;
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        NocttyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (candidate->requested_font_size != next) {
            changed = TRUE;
            break;
        }
    }
    if (!changed) return FALSE;
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        NocttyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        candidate->requested_font_size = next;
        candidate->font_size = next;
        clear_ascii_glyph_cache(candidate);
        if (candidate->area != NULL) {
            GtkAllocation allocation;
            gtk_widget_get_allocation(candidate->area, &allocation);
            resize_grid_to_allocation(candidate, &allocation);
            gtk_widget_queue_draw(candidate->area);
        }
    }
    if (notify && context->event != NULL)
        context->event(context->event_data, context->pane_id, 41,
                       noctty_grid_font_size_event_value(
                           next, root->font_min_size, root->font_max_size),
                       (uint64_t)(g_get_monotonic_time() / 1000));
    return TRUE;
}

static gboolean apply_pane_font_size(NocttyGridContext *context,
                                     double requested, gboolean notify) {
    NocttyGridContext *root = root_grid_context(context);
    double next = noctty_grid_font_size_clamp(
        requested, root->font_min_size, root->font_max_size);
    if (next == context->requested_font_size) return FALSE;
    context->requested_font_size = next;
    context->font_size = next;
    clear_ascii_glyph_cache(context);
    if (context->area != NULL) {
        GtkAllocation allocation;
        gtk_widget_get_allocation(context->area, &allocation);
        resize_grid_to_allocation(context, &allocation);
        gtk_widget_queue_draw(context->area);
    }
    if (notify && context->event != NULL)
        context->event(context->event_data, context->pane_id, 96,
                       noctty_grid_font_size_event_value(
                           next, root->font_min_size, root->font_max_size),
                       (uint64_t)(g_get_monotonic_time() / 1000));
    return TRUE;
}

static gboolean sync_grid_context_profile(NocttyGridContext *context) {
    if (context == NULL || context->event_data == NULL ||
        context->pane_id == 0)
        return FALSE;
    char family[256] = {0};
    int font_size_hundredths = 0;
    int high_contrast = 0;
    int ligatures = 1;
    int preset = noctty_grid_pane_profile(
        context->event_data, context->pane_id, family, sizeof(family),
        &font_size_hundredths, &high_contrast, &ligatures);
    if (font_size_hundredths <= 0 || family[0] == '\0') return FALSE;

    gboolean changed = FALSE;
    if (g_strcmp0(context->font_family, family) != 0) {
        g_free(context->font_family);
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
    int resolved_preset = preset >= 0 && preset < 5 ? preset : -1;
    if (context->profile_preset != resolved_preset) {
        context->profile_preset = resolved_preset;
        changed = TRUE;
    }
    double resolved_size = noctty_grid_font_size_clamp(
        font_size_hundredths / 100.0,
        context->font_min_size, context->font_max_size);
    if (context->area != NULL && gtk_widget_get_mapped(context->area)) {
        if (apply_pane_font_size(context, resolved_size, FALSE))
            changed = TRUE;
    } else if (context->requested_font_size != resolved_size) {
        context->requested_font_size = resolved_size;
        context->font_size = resolved_size;
        changed = TRUE;
    }
    if (changed && context->area != NULL)
        gtk_widget_queue_draw(context->area);
    return TRUE;
}

static void on_settings_font_changed(GtkSpinButton *spin, gpointer user_data) {
    NocttyGridContext *context = user_data;
    (void)apply_grid_font_size(context, gtk_spin_button_get_value(spin), TRUE);
}

static void on_settings_notifications_toggled(GtkToggleButton *toggle, gpointer user_data) {
    NocttyGridContext *context = user_data;
    context->enable_notifications = gtk_toggle_button_get_active(toggle);
    if (context->event != NULL) context->event(context->event_data, context->pane_id, 42, context->enable_notifications, (uint64_t)(g_get_monotonic_time() / 1000));
}

static void on_settings_preset_changed(GtkComboBox *combo, gpointer user_data) {
    NocttyGridContext *context = user_data;
    int preset = gtk_combo_box_get_active(combo);
    if (preset >= 0 && context->event != NULL) {
        context->event(context->event_data, context->pane_id, 43, preset,
                       (uint64_t)(g_get_monotonic_time() / 1000));
        (void)sync_grid_context_profile(context);
    }
}


static void apply_grid_tab_position(NocttyGridContext *context, int value,
                                    gboolean notify) {
    GtkPositionType position = GTK_POS_TOP;
    if (value == 1) position = GTK_POS_BOTTOM;
    else if (value == 2) position = GTK_POS_LEFT;
    else if (value == 3) position = GTK_POS_RIGHT;
    if (value < 0 || value > 3) return;
    gtk_notebook_set_tab_pos(GTK_NOTEBOOK(context->notebook), position);
    if (context->window_toolbar_controls != NULL) {
        GtkOrientation orientation = value < 2
            ? GTK_ORIENTATION_HORIZONTAL
            : GTK_ORIENTATION_VERTICAL;
        gtk_orientable_set_orientation(
            GTK_ORIENTABLE(context->window_toolbar_controls), orientation);
    }
    for (guint index = 0; context->contexts != NULL &&
         index < context->contexts->len; index++) {
        NocttyGridContext *candidate =
            g_ptr_array_index(context->contexts, index);
        candidate->tab_position = value;
    }
    if (notify && context->event != NULL) {
        context->event(context->event_data, context->pane_id, 63, value,
                       (uint64_t)(g_get_monotonic_time() / 1000));
    }
}

static void on_settings_tabs_changed(GtkComboBox *combo, gpointer user_data) {
    NocttyGridContext *context = user_data;
    int value = gtk_combo_box_get_active(combo);
    if (value >= 0 && context->event != NULL) context->event(context->event_data, context->pane_id, 44, value, (uint64_t)(g_get_monotonic_time() / 1000));
    apply_grid_tab_position(context, value, TRUE);
}

static void on_settings_status_changed(GtkComboBox *combo, gpointer user_data) {
    NocttyGridContext *context = user_data;
    int value = gtk_combo_box_get_active(combo);
    if (value >= 0 && context->event != NULL) context->event(context->event_data, context->pane_id, 45, value, (uint64_t)(g_get_monotonic_time() / 1000));
}

static void apply_panel_metric_setting(NocttyGridContext *context,
                                       int event_code, int value) {
    NocttyGridContext *root = root_grid_context(context);
    int resolved = noctty_grid_panel_metric_value(event_code, value);
    if (resolved < 0) return;
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        NocttyGridContext *candidate =
            g_ptr_array_index(root->contexts, index);
        switch (event_code) {
            case 46: candidate->panel_padding_px = resolved; break;
            case 47: candidate->pane_spacing_px = resolved; break;
            case 119: candidate->pane_divider_px = resolved; break;
            case 120: candidate->pane_border_px = resolved; break;
            case 121: candidate->pane_border_focused_px = resolved; break;
            case 122: candidate->pane_border_selected_px = resolved; break;
            case 123: candidate->status_border_px = resolved; break;
            case 124: candidate->overlay_border_px = resolved; break;
            case 125: candidate->window_border_px = resolved; break;
            case 126: candidate->dragger_px = resolved; break;
            case 127: candidate->pane_gaps_enabled = resolved != 0; break;
            case 128: candidate->pane_gaps_transparent = resolved != 0; break;
            case 129: candidate->inactive_pane_dim_enabled = resolved != 0; break;
            case 130:
                candidate->inactive_pane_brightness_percent = resolved;
                break;
            default: return;
        }
        if (candidate->active && candidate->area != NULL)
            gtk_widget_queue_draw(candidate->area);
    }
    apply_panel_layout_metrics(root);
    update_window_resize_handles(root);
    if (context->event != NULL)
        context->event(context->event_data, context->pane_id, event_code,
                       value, (uint64_t)(g_get_monotonic_time() / 1000));
}

static void on_settings_panel_metric_changed(GtkSpinButton *spin,
                                             gpointer user_data) {
    int event_code = GPOINTER_TO_INT(g_object_get_data(
        G_OBJECT(spin), "noctty-panel-metric-event"));
    apply_panel_metric_setting(
        user_data, event_code, gtk_spin_button_get_value_as_int(spin));
}

static void on_settings_panel_toggle(GtkToggleButton *toggle,
                                     gpointer user_data) {
    int event_code = GPOINTER_TO_INT(g_object_get_data(
        G_OBJECT(toggle), "noctty-panel-metric-event"));
    gboolean active = gtk_toggle_button_get_active(toggle);
    apply_panel_metric_setting(user_data, event_code, active);
    if (event_code == 127) {
        GtkWidget *width = g_object_get_data(
            G_OBJECT(toggle), "noctty-gap-width");
        GtkWidget *transparent = g_object_get_data(
            G_OBJECT(toggle), "noctty-gap-transparent");
        if (width != NULL) gtk_widget_set_sensitive(width, active);
        if (transparent != NULL)
            gtk_widget_set_sensitive(transparent, active);
    } else if (event_code == 129) {
        GtkWidget *brightness = g_object_get_data(
            G_OBJECT(toggle), "noctty-inactive-brightness");
        if (brightness != NULL)
            gtk_widget_set_sensitive(brightness, active);
    }
}

static void on_settings_inactive_brightness_changed(GtkRange *range,
                                                     gpointer user_data) {
    apply_panel_metric_setting(
        user_data, 130, (int)gtk_range_get_value(range));
}

static void populate_theme_combo(NocttyGridContext *context,
                                 GtkComboBoxText *combo) {
    char active[97] = {0};
    if (context->event_data != NULL) {
        if (noctty_grid_pane_theme_name(
                context->event_data, context->pane_id,
                active, sizeof(active)) <= 0)
            (void)noctty_grid_active_theme_name(
                context->event_data, active, sizeof(active));
    }
    int count = context->event_data != NULL
        ? noctty_grid_theme_count(context->event_data) : 0;
    for (int index = 0; index < count; index++) {
        char name[97] = {0};
        int length = noctty_grid_theme_name(
            context->event_data, index, name, sizeof(name));
        if (length <= 0) continue;
        const char *label = g_strcmp0(name, "noctty-dark") == 0
            ? "NOCTTY Dark"
            : g_strcmp0(name, "paseo-black-zinc") == 0
                ? "Paseo Black Zinc"
                : g_strcmp0(name, "noctty-high-contrast") == 0
                    ? "NOCTTY High Contrast" : name;
        gtk_combo_box_text_append(combo, name, label);
    }
    if (active[0] != '\0')
        gtk_combo_box_set_active_id(GTK_COMBO_BOX(combo), active);
    if (gtk_combo_box_get_active(GTK_COMBO_BOX(combo)) < 0)
        gtk_combo_box_set_active(GTK_COMBO_BOX(combo), 0);
}

static void refresh_theme_combo(NocttyGridContext *context,
                                GtkWidget *combo) {
    if (!GTK_IS_COMBO_BOX_TEXT(combo)) return;
    gtk_combo_box_text_remove_all(GTK_COMBO_BOX_TEXT(combo));
    populate_theme_combo(context, GTK_COMBO_BOX_TEXT(combo));
}

static void refresh_open_theme_selectors(NocttyGridContext *context) {
    NocttyGridContext *root = root_grid_context(context);
    if (GTK_IS_WINDOW(root->settings_dialog))
        refresh_theme_combo(active_grid_context(root), g_object_get_data(
            G_OBJECT(root->settings_dialog), "noctty-settings-theme"));
    if (GTK_IS_WINDOW(root->theme_dialog))
        refresh_theme_combo(root, g_object_get_data(
            G_OBJECT(root->theme_dialog), "noctty-theme-selector"));
}

static void set_theme_library_status(NocttyGridContext *context,
                                     const gchar *message,
                                     gboolean is_error) {
    NocttyGridContext *root = root_grid_context(context);
    if (!GTK_IS_WINDOW(root->theme_dialog)) return;
    GtkWidget *status = g_object_get_data(
        G_OBJECT(root->theme_dialog), "noctty-theme-status");
    set_status_label_feedback(status, message, is_error);
}

static gboolean read_theme_file_bounded(const gchar *path, goffset maximum,
                                         gchar **contents, gsize *length) {
    if (path == NULL || contents == NULL || length == NULL) return FALSE;
    *contents = NULL;
    *length = 0;
    GStatBuf stat_buffer;
    if (g_stat(path, &stat_buffer) != 0 ||
        !S_ISREG(stat_buffer.st_mode) || stat_buffer.st_size <= 0 ||
        stat_buffer.st_size > maximum)
        return FALSE;
    if (!g_file_get_contents(path, contents, length, NULL)) return FALSE;
    if (*length == 0 || *length > (gsize)maximum) {
        g_clear_pointer(contents, g_free);
        *length = 0;
        return FALSE;
    }
    return TRUE;
}

static void on_settings_theme_changed(GtkComboBox *combo, gpointer user_data) {
    NocttyGridContext *target = active_grid_context(user_data);
    NocttyGridContext *context = root_grid_context(user_data);
    const gchar *name = gtk_combo_box_get_active_id(combo);
    if (name == NULL || context->text_action == NULL || target == NULL) return;
    GtkWidget *scope = g_object_get_data(
        G_OBJECT(combo), "noctty-theme-scope-tab");
    gboolean current_tab_only = GTK_IS_TOGGLE_BUTTON(scope) &&
        gtk_toggle_button_get_active(GTK_TOGGLE_BUTTON(scope));
    int result = current_tab_only
        ? noctty_grid_set_tab_theme(
              context->event_data, target->pane_id, name, strlen(name))
        : context->text_action(
              context->text_action_data, 21, name, strlen(name), "", 0, 0);
    if (result != 0 && result != NOCTTY_TEXT_ACTION_PERSISTENCE_FAILED) {
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
        NocttyGridContext *candidate =
            g_ptr_array_index(context->contexts, index);
        (void)sync_grid_context_profile(candidate);
        if (candidate->active && candidate->area != NULL)
            gtk_widget_queue_draw(candidate->area);
    }
    apply_panel_layout_metrics(context);
    if (result == NOCTTY_TEXT_ACTION_PERSISTENCE_FAILED)
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
    NocttyGridContext *context;
    uint32_t role;
} NocttyThemeColorControl;

static void set_theme_color_button_from_model(GtkColorButton *button,
                                              NocttyGridContext *context,
                                              uint32_t role) {
    uint32_t rgb = context->ui_color_rgb != NULL
        ? context->ui_color_rgb(context->event_data, role) : UINT32_MAX;
    if (rgb == UINT32_MAX) rgb = 0x000000;
    GdkRGBA rgba = {
        .red = noctty_grid_theme_color_channel(rgb, 0),
        .green = noctty_grid_theme_color_channel(rgb, 1),
        .blue = noctty_grid_theme_color_channel(rgb, 2),
        .alpha = 1.0,
    };
    gtk_color_chooser_set_rgba(GTK_COLOR_CHOOSER(button), &rgba);
}

static void on_theme_color_control_destroy(GtkWidget *widget,
                                           gpointer user_data) {
    (void)widget;
    g_free(user_data);
}

static void on_theme_color_changed(GtkColorButton *button, gpointer user_data) {
    NocttyThemeColorControl *control = user_data;
    NocttyGridContext *context = root_grid_context(control->context);
    if (context->text_action == NULL) return;
    GdkRGBA rgba;
    gtk_color_chooser_get_rgba(GTK_COLOR_CHOOSER(button), &rgba);
    gchar value[8] = {0};
    if (noctty_grid_theme_color_text(
            rgba.red, rgba.green, rgba.blue,
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
        NocttyGridContext *candidate =
            g_ptr_array_index(context->contexts, index);
        if (!candidate->active || candidate->area == NULL) continue;
        gtk_widget_queue_draw(candidate->area);
        update_compact_tab(candidate);
    }
    if (control->role == NOCTTY_UI_COLOR_PANE_GAP)
        apply_panel_layout_metrics(context);
}

static GtkWidget *theme_color_button_new(NocttyGridContext *context,
                                         uint32_t role, const char *name) {
    GtkWidget *button = gtk_color_button_new();
    set_theme_color_button_from_model(
        GTK_COLOR_BUTTON(button), root_grid_context(context), role);
    gtk_color_chooser_set_use_alpha(GTK_COLOR_CHOOSER(button), FALSE);
    set_widget_accessible_name(button, name);
    NocttyThemeColorControl *control = g_new0(NocttyThemeColorControl, 1);
    control->context = root_grid_context(context);
    control->role = role;
    g_signal_connect(button, "color-set", G_CALLBACK(on_theme_color_changed),
                     control);
    g_signal_connect(button, "destroy",
                     G_CALLBACK(on_theme_color_control_destroy), control);
    return button;
}

static void apply_background_setting(NocttyGridContext *context,
                                     int event_code, int value) {
    NocttyGridContext *root = root_grid_context(context);
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        NocttyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (event_code == 115)
            candidate->background_translucency = value;
        else
            candidate->background_opacity_percent =
                noctty_grid_background_opacity_value(value);
        if (candidate->active && candidate->area != NULL)
            gtk_widget_queue_draw(candidate->area);
    }
    if (root->window != NULL) gtk_widget_queue_draw(root->window);
    if (context->event != NULL)
        context->event(context->event_data, context->pane_id, event_code,
                       value, (uint64_t)(g_get_monotonic_time() / 1000));
}

static void on_background_translucency_toggled(
    GtkToggleButton *toggle, gpointer user_data) {
    int enabled = gtk_toggle_button_get_active(toggle);
    GtkWidget *opacity = g_object_get_data(
        G_OBJECT(toggle), "noctty-background-opacity");
    NocttyGridContext *context = root_grid_context(user_data);
    if (opacity != NULL)
        gtk_widget_set_sensitive(
            opacity, enabled && context->background_alpha_supported);
    apply_background_setting(context, 115, enabled);
}

static void on_background_opacity_changed(GtkRange *range,
                                          gpointer user_data) {
    apply_background_setting(
        user_data, 116, noctty_grid_background_opacity_value(
            (int)round(gtk_range_get_value(range))));
}

static void on_settings_family_changed(GtkComboBox *combo, gpointer user_data) {
    NocttyGridContext *context = user_data;
    int value = gtk_combo_box_get_active(combo);
    gchar *family = gtk_combo_box_text_get_active_text(GTK_COMBO_BOX_TEXT(combo));
    if (value < 0 || family == NULL) return;
    NocttyGridContext *root = root_grid_context(context);
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        NocttyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (g_strcmp0(candidate->font_family, family) == 0) continue;
        g_free(candidate->font_family);
        candidate->font_family = g_strdup(family);
        clear_ascii_glyph_cache(candidate);
        if (candidate->area != NULL) {
            GtkAllocation allocation;
            gtk_widget_get_allocation(candidate->area, &allocation);
            resize_grid_to_allocation(candidate, &allocation);
            gtk_widget_queue_draw(candidate->area);
        }
    }
    g_free(family);
    if (context->event != NULL)
        context->event(context->event_data, context->pane_id, 49, value,
                       (uint64_t)(g_get_monotonic_time() / 1000));
}

static void apply_font_rendering_setting(NocttyGridContext *context,
                                         int event_code, int value) {
    NocttyGridContext *root = root_grid_context(context);
    if (event_code == 110) root->font_antialias = value;
    else root->font_hinting = value;
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        NocttyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        clear_ascii_glyph_cache(candidate);
        if (candidate->active && candidate->area != NULL)
            gtk_widget_queue_draw(candidate->area);
    }
    if (context->event != NULL)
        context->event(context->event_data, context->pane_id, event_code,
                       value, (uint64_t)(g_get_monotonic_time() / 1000));
}

static void on_settings_antialias_changed(GtkComboBox *combo,
                                          gpointer user_data) {
    int value = gtk_combo_box_get_active(combo);
    if (value >= 0) apply_font_rendering_setting(user_data, 110, value);
}

static void on_settings_hinting_changed(GtkComboBox *combo,
                                        gpointer user_data) {
    int value = gtk_combo_box_get_active(combo);
    if (value >= 0) apply_font_rendering_setting(user_data, 111, value);
}

static void on_settings_shortcut_clicked(GtkButton *button, gpointer user_data) {
    (void)button;
    open_grid_shortcut_recorder(user_data);
}

static void sync_launch_profile_sensitivity(NocttyGridContext *context) {
    if (!GTK_IS_COMBO_BOX(context->settings_launch_kind)) return;
    int kind = gtk_combo_box_get_active(
        GTK_COMBO_BOX(context->settings_launch_kind));
    if (context->settings_launch_command != NULL)
        gtk_widget_set_sensitive(context->settings_launch_command, kind == 1);
    if (context->settings_launch_ssh_target != NULL)
        gtk_widget_set_sensitive(context->settings_launch_ssh_target,
                                 kind >= 2);
}

static void load_current_launch_profile(NocttyGridContext *context) {
    if (context->event_data == NULL) return;
    char shell[257] = {0};
    char command[1025] = {0};
    char cwd[4097] = {0};
    char environment[2049] = {0};
    char ssh_target[257] = {0};
    int kind = noctty_grid_launch_profile(
        context->event_data, 0, shell, sizeof(shell));
    (void)noctty_grid_launch_profile(context->event_data, 1, shell,
                                     sizeof(shell));
    (void)noctty_grid_launch_profile(context->event_data, 2, command,
                                     sizeof(command));
    (void)noctty_grid_launch_profile(context->event_data, 3, cwd,
                                     sizeof(cwd));
    (void)noctty_grid_launch_profile(context->event_data, 4, environment,
                                     sizeof(environment));
    (void)noctty_grid_launch_profile(context->event_data, 5, ssh_target,
                                     sizeof(ssh_target));
    int scrollback = noctty_grid_launch_profile(
        context->event_data, 6, shell, sizeof(shell));
    gtk_combo_box_set_active(GTK_COMBO_BOX(context->settings_launch_kind),
                             CLAMP(kind, 0, 4));
    gtk_entry_set_text(GTK_ENTRY(context->settings_launch_shell), shell);
    gtk_entry_set_text(GTK_ENTRY(context->settings_launch_command), command);
    gtk_entry_set_text(GTK_ENTRY(context->settings_launch_cwd), cwd);
    gtk_entry_set_text(GTK_ENTRY(context->settings_launch_environment),
                       environment);
    gtk_entry_set_text(GTK_ENTRY(context->settings_launch_ssh_target),
                       ssh_target);
    gtk_spin_button_set_value(
        GTK_SPIN_BUTTON(context->settings_launch_scrollback), scrollback);
    sync_launch_profile_sensitivity(context);
}

static void refresh_launch_profile_library(NocttyGridContext *context) {
    if (context->event_data == NULL ||
        !GTK_IS_COMBO_BOX_TEXT(context->settings_launch_library))
        return;
    GtkComboBoxText *combo =
        GTK_COMBO_BOX_TEXT(context->settings_launch_library);
    char name[65] = {0};
    int count = noctty_grid_launch_profile_library(
        context->event_data, -1, 0, name, sizeof(name));
    int selected = noctty_grid_launch_profile_library(
        context->event_data, -2, 0, name, sizeof(name));
    gtk_combo_box_text_remove_all(combo);
    gtk_combo_box_text_append_text(combo, "Custom current");
    for (int index = 0; index < count; index++) {
        if (noctty_grid_launch_profile_library(
                context->event_data, index, 0, name, sizeof(name)) >= 0)
            gtk_combo_box_text_append_text(combo, name);
    }
    gtk_combo_box_set_active(GTK_COMBO_BOX(combo),
                             selected >= 0 ? selected + 1 : 0);
    if (GTK_IS_ENTRY(context->settings_launch_name)) {
        name[0] = '\0';
        if (selected >= 0)
            (void)noctty_grid_launch_profile_library(
                context->event_data, selected, 0, name, sizeof(name));
        gtk_entry_set_text(GTK_ENTRY(context->settings_launch_name), name);
    }
    gtk_widget_set_sensitive(context->settings_launch_delete,
                             selected >= 0);
}

static void on_settings_launch_kind_changed(GtkComboBox *combo,
                                            gpointer user_data) {
    (void)combo;
    sync_launch_profile_sensitivity(root_grid_context(user_data));
}

static int submit_settings_launch_profile(NocttyGridContext *context,
                                          int action,
                                          const char *name) {
    if (context->text_action == NULL ||
        !GTK_IS_COMBO_BOX(context->settings_launch_kind) ||
        !GTK_IS_ENTRY(context->settings_launch_shell) ||
        !GTK_IS_ENTRY(context->settings_launch_command) ||
        !GTK_IS_ENTRY(context->settings_launch_cwd) ||
        !GTK_IS_ENTRY(context->settings_launch_environment) ||
        !GTK_IS_ENTRY(context->settings_launch_ssh_target) ||
        !GTK_IS_SPIN_BUTTON(context->settings_launch_scrollback))
        return -1;
    int kind = gtk_combo_box_get_active(
        GTK_COMBO_BOX(context->settings_launch_kind));
    const char *shell = gtk_entry_get_text(
        GTK_ENTRY(context->settings_launch_shell));
    const char *command = gtk_entry_get_text(
        GTK_ENTRY(context->settings_launch_command));
    const char *cwd = gtk_entry_get_text(
        GTK_ENTRY(context->settings_launch_cwd));
    const char *environment = gtk_entry_get_text(
        GTK_ENTRY(context->settings_launch_environment));
    const char *ssh_target = gtk_entry_get_text(
        GTK_ENTRY(context->settings_launch_ssh_target));
    int scrollback = gtk_spin_button_get_value_as_int(
        GTK_SPIN_BUTTON(context->settings_launch_scrollback));
    gchar *payload = action == 16
        ? g_strdup_printf("%s\t%s\t%s\t%s\t%s\t%d", name, shell,
                          command, cwd, ssh_target, scrollback)
        : g_strdup_printf("%s\t%s\t%s\t%s\t%d", shell, command, cwd,
                          ssh_target, scrollback);
    int result = context->text_action(
        context->text_action_data, action, payload, strlen(payload), environment,
        strlen(environment), kind);
    g_free(payload);
    return result;
}

static void set_launch_profile_status(
    NocttyGridContext *context, const char *message, gboolean error,
    GtkWidget *focus) {
    if (!GTK_IS_LABEL(context->settings_launch_status)) return;
    gtk_label_set_text(
        GTK_LABEL(context->settings_launch_status), message);
    gtk_widget_set_visible(context->settings_launch_status, TRUE);
    context->launch_profile_feedback = message != NULL && message[0] != '\0';
    GtkStyleContext *style =
        gtk_widget_get_style_context(context->settings_launch_status);
    if (error)
        gtk_style_context_add_class(style, "error");
    else
        gtk_style_context_remove_class(style, "error");
    AtkObject *accessible =
        gtk_widget_get_accessible(context->settings_launch_status);
    if (accessible != NULL) {
        atk_object_set_role(
            accessible, error ? ATK_ROLE_ALERT : ATK_ROLE_STATUSBAR);
        atk_object_set_description(accessible, message);
        g_signal_emit_by_name(accessible, "visible-data-changed");
    }
    if (error && focus != NULL) gtk_widget_grab_focus(focus);
}

static void on_settings_launch_apply(GtkButton *button, gpointer user_data) {
    (void)button;
    NocttyGridContext *context = root_grid_context(user_data);
    if (submit_settings_launch_profile(context, 15, "") == 0) {
        context->launch_profile_setting_applied = 1;
        refresh_launch_profile_library(context);
        set_launch_profile_status(
            context, "Launch profile saved for new sessions.", FALSE, NULL);
    } else {
        set_launch_profile_status(
            context,
            "Profile was not saved. Check absolute paths, environment "
            "entries, and fields required by the selected launch type.",
            TRUE, context->settings_launch_kind);
    }
}

static void on_settings_launch_save(GtkButton *button, gpointer user_data) {
    (void)button;
    NocttyGridContext *context = root_grid_context(user_data);
    if (!GTK_IS_ENTRY(context->settings_launch_name)) return;
    const char *name = gtk_entry_get_text(
        GTK_ENTRY(context->settings_launch_name));
    gchar *trimmed = g_strdup(name);
    g_strstrip(trimmed);
    gboolean valid_name =
        trimmed[0] != '\0' && g_strcmp0(trimmed, name) == 0;
    g_free(trimmed);
    if (!valid_name) {
        set_launch_profile_status(
            context,
            "Enter a profile name without leading or trailing spaces.",
            TRUE, context->settings_launch_name);
        return;
    }
    if (submit_settings_launch_profile(context, 16, name) == 0) {
        context->launch_profile_setting_applied = 1;
        context->launch_profile_library_saved = 1;
        refresh_launch_profile_library(context);
        set_launch_profile_status(
            context, "Named launch profile saved and selected.",
            FALSE, NULL);
    } else {
        set_launch_profile_status(
            context,
            "Profile was not saved. Check absolute paths, environment "
            "entries, and fields required by the selected launch type.",
            TRUE, context->settings_launch_kind);
    }
}

static void on_settings_launch_library_changed(GtkComboBox *combo,
                                               gpointer user_data) {
    NocttyGridContext *context = root_grid_context(user_data);
    int active = gtk_combo_box_get_active(combo);
    if (active < 0 || context->text_action == NULL) return;
    if (active == 0) {
        if (submit_settings_launch_profile(context, 15, "") == 0) {
            context->launch_profile_setting_applied = 1;
            gtk_entry_set_text(GTK_ENTRY(context->settings_launch_name), "");
            gtk_widget_set_sensitive(context->settings_launch_delete, FALSE);
        }
        return;
    }
    int index = active - 1;
    if (context->text_action(context->text_action_data, 17, "", 0, "", 0,
                             index) != 0)
        return;
    context->launch_profile_library_selected = 1;
    char name[65] = {0};
    if (noctty_grid_launch_profile_library(context->event_data, index, 0,
                                           name, sizeof(name)) >= 0)
        gtk_entry_set_text(GTK_ENTRY(context->settings_launch_name), name);
    gtk_widget_set_sensitive(context->settings_launch_delete, TRUE);
    load_current_launch_profile(context);
}

static void on_settings_launch_delete(GtkButton *button, gpointer user_data) {
    (void)button;
    NocttyGridContext *context = root_grid_context(user_data);
    if (!GTK_IS_COMBO_BOX(context->settings_launch_library) ||
        context->text_action == NULL)
        return;
    int active = gtk_combo_box_get_active(
        GTK_COMBO_BOX(context->settings_launch_library));
    if (active <= 0) return;
    if (context->text_action(
            context->text_action_data, 18, "", 0, "", 0,
            active - 1) != 0) {
        set_launch_profile_status(
            context, "The selected profile could not be deleted.",
            TRUE, context->settings_launch_library);
        return;
    }
    context->launch_profile_library_removed = 1;
    gtk_entry_set_text(GTK_ENTRY(context->settings_launch_name), "");
    refresh_launch_profile_library(context);
    set_launch_profile_status(
        context, "Named launch profile deleted.", FALSE, NULL);
}

static void open_grid_settings(NocttyGridContext *context) {
    NocttyGridContext *target = active_grid_context(context);
    (void)sync_grid_context_profile(target);
    context = root_grid_context(context);
    if (context->settings_dialog != NULL) {
        gtk_window_set_keep_above(GTK_WINDOW(context->settings_dialog), TRUE);
        present_configured_window(context->settings_dialog);
        return;
    }
    GtkWidget *dialog = gtk_dialog_new_with_buttons(
        "Configure NOCTTY", GTK_WINDOW(context->window),
        GTK_DIALOG_DESTROY_WITH_PARENT, "_Close", GTK_RESPONSE_CLOSE, NULL);
    (void)configure_overlay_window_stacking(
        context, dialog, "noctty-settings");
    GdkRectangle settings_workarea = {0, 0, 900, 680};
    GdkMonitor *settings_monitor = grid_monitor_for_window(context->window);
    if (settings_monitor != NULL)
        gdk_monitor_get_workarea(settings_monitor, &settings_workarea);
    gboolean compact_settings = settings_workarea.width < 800;
    int settings_width =
        noctty_grid_dialog_dimension(settings_workarea.width, 980, 720, 96);
    int settings_height =
        noctty_grid_dialog_dimension(settings_workarea.height, 720, 560, 96);
    settings_width = noctty_grid_dialog_dimension(
        settings_workarea.width, settings_width, 1, 32);
    settings_height = noctty_grid_dialog_dimension(
        settings_workarea.height, settings_height, 1, 32);
    configure_overlay_window_geometry(
        context, dialog, &settings_workarea,
        settings_width, settings_height);
    GdkGeometry settings_geometry = {
        .min_width = MIN(720, settings_width),
        .min_height = MIN(560, settings_height),
        /* GTK decorations can add a few logical pixels beyond the requested
         * client size at HiDPI. The work area itself is the hard boundary. */
        .max_width = MAX(1, settings_workarea.width),
        .max_height = MAX(1, settings_workarea.height),
    };
    gtk_window_set_geometry_hints(
        GTK_WINDOW(dialog), NULL, &settings_geometry,
        GDK_HINT_MIN_SIZE | GDK_HINT_MAX_SIZE);
    gtk_window_set_default_size(GTK_WINDOW(dialog),
                                settings_width, settings_height);
    gtk_window_resize(GTK_WINDOW(dialog), settings_width, settings_height);
    gtk_window_set_position(GTK_WINDOW(dialog), GTK_WIN_POS_CENTER_ON_PARENT);
    gtk_window_set_resizable(GTK_WINDOW(dialog), TRUE);
    gtk_dialog_set_default_response(GTK_DIALOG(dialog), GTK_RESPONSE_CLOSE);

    GtkWidget *layout = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0);
    gtk_widget_set_hexpand(layout, TRUE);
    gtk_widget_set_vexpand(layout, TRUE);
    GtkWidget *categories = gtk_list_box_new();
    gtk_list_box_set_selection_mode(GTK_LIST_BOX(categories),
                                    GTK_SELECTION_BROWSE);
    gtk_widget_set_size_request(categories,
                                compact_settings ? 136 : 184, -1);
    gtk_widget_set_hexpand(categories, FALSE);
    gtk_widget_set_vexpand(categories, TRUE);
    gtk_style_context_add_class(gtk_widget_get_style_context(categories),
                                "sidebar");
    gtk_container_set_border_width(GTK_CONTAINER(categories), 4);
    gtk_container_add(GTK_CONTAINER(categories), settings_category_row_new(
        "preferences-system-windows", "Window", "window"));
    gtk_container_add(GTK_CONTAINER(categories), settings_category_row_new(
        "preferences-system-windows-actions", "Behavior", "behavior"));
    gtk_container_add(GTK_CONTAINER(categories), settings_category_row_new(
        "preferences-desktop-theme", "Appearance", "appearance"));

    GtkWidget *stack = gtk_stack_new();
    gtk_stack_set_transition_type(GTK_STACK(stack),
                                  GTK_STACK_TRANSITION_TYPE_CROSSFADE);
    gtk_stack_set_transition_duration(GTK_STACK(stack), 120);
    gtk_widget_set_hexpand(stack, TRUE);
    gtk_widget_set_vexpand(stack, TRUE);

    gchar *shortcut_button_label =
        grid_settings_shortcut_button_label_alloc(context);
    GtkWidget *shortcut = gtk_button_new_with_label(shortcut_button_label);
    g_free(shortcut_button_label);
    configure_grid_settings_shortcut_button(context, shortcut);
    int scrollback_lines = context->event_data != NULL
        ? noctty_grid_compact_setting(context->event_data, 10) : 10000;
    const NocttySettingsCoreOptions core_options = {
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
    NocttySettingsCoreContents core_contents = {0};
    if (!noctty_settings_core_contents_new(
            &core_options, &core_contents)) {
        gtk_widget_destroy(dialog);
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
        launch_kind_value = noctty_grid_launch_profile(
            context->event_data, 0, launch_shell, sizeof(launch_shell));
        (void)noctty_grid_launch_profile(context->event_data, 1,
                                         launch_shell,
                                         sizeof(launch_shell));
        (void)noctty_grid_launch_profile(context->event_data, 2,
                                         launch_command,
                                         sizeof(launch_command));
        (void)noctty_grid_launch_profile(context->event_data, 3, launch_cwd,
                                         sizeof(launch_cwd));
        (void)noctty_grid_launch_profile(context->event_data, 4,
                                         launch_environment,
                                         sizeof(launch_environment));
        (void)noctty_grid_launch_profile(context->event_data, 5,
                                         launch_ssh_target,
                                         sizeof(launch_ssh_target));
        launch_scrollback_value = noctty_grid_launch_profile(
            context->event_data, 6, launch_shell, sizeof(launch_shell));
    }
    const NocttyLaunchProfileOptions launch_options = {
        .shell = launch_shell,
        .command = launch_command,
        .cwd = launch_cwd,
        .environment = launch_environment,
        .ssh_target = launch_ssh_target,
        .kind = launch_kind_value,
        .scrollback = launch_scrollback_value,
    };
    NocttyLaunchProfileContents launch_contents = {0};
    if (!noctty_launch_profile_contents_new(
            behavior_page_body, &launch_options, &launch_contents)) {
        gtk_widget_destroy(dialog);
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
    GtkWidget *notification_box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 8);
    gtk_box_pack_start(GTK_BOX(notification_box), notifications,
                       FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(behavior_page_body),
                       settings_group_new("Notifications", notification_box),
                       FALSE, FALSE, 0);

    GtkWidget *theme = gtk_combo_box_text_new();
    populate_theme_combo(target, GTK_COMBO_BOX_TEXT(theme));
    GtkWidget *background_tint = theme_color_button_new(
        context, NOCTTY_UI_COLOR_WORKSPACE_BACKGROUND, "Background tint");
    NocttyGridWorkspaceColor workspace_colors[17] = {0};
    for (guint index = 0; index < G_N_ELEMENTS(workspace_colors); index++)
        (void)noctty_grid_workspace_color((int)index, &workspace_colors[index]);
    GtkWidget *color_buttons[G_N_ELEMENTS(workspace_colors)] = {0};
    for (guint index = 0; index < G_N_ELEMENTS(workspace_colors); index++)
        color_buttons[index] = theme_color_button_new(
            context, workspace_colors[index].role,
            workspace_colors[index].label);
    int family_active = g_ascii_strcasecmp(
        target->font_family != NULL ? target->font_family : "Monospace",
        "JetBrains Mono") == 0 ? 1 : 0;
    const NocttySettingsAppearanceOptions appearance_options = {
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
        .hinting = context->font_hinting,
        .translucency = context->background_translucency,
        .alpha_supported = context->background_alpha_supported,
        .opacity_percent = context->background_opacity_percent,
        .compact = compact_settings,
    };
    NocttySettingsAppearanceContents appearance = {0};
    if (!noctty_settings_appearance_contents_new(
            &appearance_options, &appearance)) {
        gtk_widget_destroy(dialog);
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
    GtkWidget *translucency = appearance.translucency;
    GtkWidget *background_opacity = appearance.opacity;
    GtkWidget *transparency_status = appearance.transparency_status;
    g_object_set_data(G_OBJECT(dialog), "noctty-settings-background-tint",
                      background_tint);
    g_object_set_data(G_OBJECT(dialog), "noctty-settings-transparency-status",
                      transparency_status);

    gtk_stack_add_named(GTK_STACK(stack), window_page, "window");
    gtk_stack_add_named(GTK_STACK(stack), behavior_page, "behavior");
    gtk_stack_add_named(GTK_STACK(stack), appearance_page, "appearance");
    GtkWidget *separator = gtk_separator_new(GTK_ORIENTATION_VERTICAL);
    GtkWidget *content = gtk_dialog_get_content_area(GTK_DIALOG(dialog));
    gtk_box_set_spacing(GTK_BOX(content), 0);
    gtk_container_set_border_width(GTK_CONTAINER(content), 0);
    gtk_container_add(GTK_CONTAINER(content), layout);
    gtk_widget_set_hexpand(stack, TRUE);
    gtk_widget_set_vexpand(stack, TRUE);
    gtk_box_pack_start(GTK_BOX(layout), categories, FALSE, TRUE, 0);
    gtk_box_pack_start(GTK_BOX(layout), separator, FALSE, TRUE, 0);
    gtk_box_pack_start(GTK_BOX(layout), stack, TRUE, TRUE, 0);

    g_object_set_data(G_OBJECT(dialog), "noctty-settings-mode", mode);
    g_object_set_data(G_OBJECT(dialog), "noctty-settings-shortcut", shortcut);
    g_object_set_data(G_OBJECT(dialog), "noctty-settings-width", dropdown_width);
    g_object_set_data(G_OBJECT(dialog), "noctty-settings-height", dropdown_height);
    g_object_set_data(G_OBJECT(dialog), "noctty-settings-animation", animation);
    g_object_set_data(G_OBJECT(dialog), "noctty-settings-hide-focus", hide_focus);
    g_object_set_data(G_OBJECT(dialog), "noctty-settings-focus-pointer", focus_pointer);
    g_object_set_data(G_OBJECT(dialog), "noctty-settings-preset", preset);
    g_object_set_data(G_OBJECT(dialog), "noctty-settings-scrollback", scrollback);
    g_object_set_data(G_OBJECT(dialog), "noctty-settings-scroll-lines",
                      scroll_lines);
    g_object_set_data(G_OBJECT(dialog), "noctty-settings-smooth-scroll",
                      smooth_scroll);
    g_object_set_data(G_OBJECT(dialog), "noctty-settings-notifications", notifications);
    g_object_set_data(G_OBJECT(dialog), "noctty-settings-tabs", tabs);
    g_object_set_data(G_OBJECT(dialog), "noctty-settings-status", status);
    g_object_set_data(G_OBJECT(dialog), "noctty-settings-padding", padding);
    g_object_set_data(G_OBJECT(dialog), "noctty-settings-spacing", spacing);
    g_object_set_data(G_OBJECT(dialog), "noctty-settings-pane-gaps",
                      pane_gaps_enabled);
    g_object_set_data(G_OBJECT(dialog), "noctty-settings-gap-transparent",
                      pane_gaps_transparent);
    g_object_set_data(G_OBJECT(dialog), "noctty-settings-inactive-dim",
                      inactive_pane_dim_enabled);
    g_object_set_data(G_OBJECT(dialog), "noctty-settings-inactive-brightness",
                      inactive_pane_brightness);
    g_object_set_data(G_OBJECT(dialog), "noctty-settings-theme-scope-tab",
                      theme_scope_tab);
    g_object_set_data(G_OBJECT(theme), "noctty-theme-scope-tab",
                      theme_scope_tab);
    g_object_set_data(G_OBJECT(dialog), "noctty-settings-divider", divider);
    g_object_set_data(G_OBJECT(dialog), "noctty-settings-pane-border",
                      pane_border);
    g_object_set_data(G_OBJECT(dialog), "noctty-settings-focused-border",
                      focused_border);
    g_object_set_data(G_OBJECT(dialog), "noctty-settings-selected-border",
                      selected_border);
    g_object_set_data(G_OBJECT(dialog), "noctty-settings-status-border",
                      status_border);
    g_object_set_data(G_OBJECT(dialog), "noctty-settings-overlay-border",
                      overlay_border);
    g_object_set_data(G_OBJECT(dialog), "noctty-settings-window-border",
                      window_border);
    g_object_set_data(G_OBJECT(dialog), "noctty-settings-dragger", dragger);
    g_object_set_data(G_OBJECT(dialog), "noctty-settings-theme", theme);
    g_object_set_data(G_OBJECT(dialog), "noctty-settings-translucency",
                      translucency);
    g_object_set_data(G_OBJECT(dialog), "noctty-settings-opacity",
                      background_opacity);
    g_object_set_data(G_OBJECT(dialog), "noctty-settings-family", family);
    g_object_set_data(G_OBJECT(dialog), "noctty-settings-font", font);
    g_object_set_data(G_OBJECT(dialog), "noctty-settings-antialias", antialias);
    g_object_set_data(G_OBJECT(dialog), "noctty-settings-hinting", hinting);
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
    context->pane_info_setting_control = GTK_IS_CHECK_BUTTON(pane_info);
    context->launch_profile_setting_control =
        GTK_IS_COMBO_BOX(launch_kind) && GTK_IS_ENTRY(launch_shell_entry) &&
        GTK_IS_ENTRY(launch_command_entry) && GTK_IS_ENTRY(launch_cwd_entry) &&
        GTK_IS_ENTRY(launch_environment_entry) &&
        GTK_IS_ENTRY(launch_ssh_entry) &&
        GTK_IS_SPIN_BUTTON(launch_scrollback) && GTK_IS_BUTTON(launch_apply);
    context->launch_profile_library_control =
        GTK_IS_COMBO_BOX(launch_library) && GTK_IS_ENTRY(launch_name_entry) &&
        GTK_IS_BUTTON(launch_save) && GTK_IS_BUTTON(launch_delete);
    refresh_launch_profile_library(context);
    GList *category_rows = gtk_container_get_children(GTK_CONTAINER(categories));
    context->settings_category_count = (int)g_list_length(category_rows);
    g_list_free(category_rows);
    g_signal_connect(categories, "row-selected",
                     G_CALLBACK(on_settings_category_selected), stack);
    g_signal_connect(mode, "changed", G_CALLBACK(on_settings_mode_changed), target);
    g_signal_connect(shortcut, "clicked", G_CALLBACK(on_settings_shortcut_clicked), target);
    g_signal_connect(dropdown_width, "value-changed", G_CALLBACK(on_settings_dropdown_width_changed), target);
    g_signal_connect(dropdown_height, "value-changed", G_CALLBACK(on_settings_dropdown_height_changed), target);
    g_signal_connect(animation, "value-changed", G_CALLBACK(on_settings_animation_changed), target);
    g_signal_connect(hide_focus, "toggled", G_CALLBACK(on_settings_hide_focus_toggled), target);
    g_signal_connect(focus_pointer, "toggled", G_CALLBACK(on_settings_focus_pointer_toggled), target);
    g_signal_connect(pane_info, "toggled", G_CALLBACK(on_settings_pane_info_toggled), target);
    g_signal_connect(scrollback, "value-changed",
                     G_CALLBACK(on_settings_scrollback_changed), target);
    g_signal_connect(scroll_lines, "value-changed",
                     G_CALLBACK(on_settings_scroll_lines_changed), target);
    g_signal_connect(smooth_scroll, "toggled",
                     G_CALLBACK(on_settings_smooth_scroll_toggled), target);
    g_signal_connect(launch_kind, "changed",
                     G_CALLBACK(on_settings_launch_kind_changed), context);
    g_signal_connect(launch_library, "changed",
                     G_CALLBACK(on_settings_launch_library_changed), context);
    g_signal_connect(launch_apply, "clicked",
                     G_CALLBACK(on_settings_launch_apply), context);
    g_signal_connect(launch_save, "clicked",
                     G_CALLBACK(on_settings_launch_save), context);
    g_signal_connect(launch_delete, "clicked",
                     G_CALLBACK(on_settings_launch_delete), context);
    g_signal_connect(font, "value-changed", G_CALLBACK(on_settings_font_changed), target);
    g_signal_connect(notifications, "toggled", G_CALLBACK(on_settings_notifications_toggled), target);
    g_signal_connect(preset, "changed", G_CALLBACK(on_settings_preset_changed), target);
    g_signal_connect(tabs, "changed", G_CALLBACK(on_settings_tabs_changed), target);
    g_signal_connect(status, "changed", G_CALLBACK(on_settings_status_changed), target);
    GtkWidget *panel_metric_controls[] = {
        padding, spacing, divider, pane_border, focused_border,
        selected_border, status_border, overlay_border,
        window_border, dragger,
    };
    for (guint index = 0; index < G_N_ELEMENTS(panel_metric_controls); index++)
        g_signal_connect(panel_metric_controls[index], "value-changed",
                         G_CALLBACK(on_settings_panel_metric_changed), target);
    g_signal_connect(pane_gaps_enabled, "toggled",
                     G_CALLBACK(on_settings_panel_toggle), target);
    g_signal_connect(pane_gaps_transparent, "toggled",
                     G_CALLBACK(on_settings_panel_toggle), target);
    g_signal_connect(inactive_pane_dim_enabled, "toggled",
                     G_CALLBACK(on_settings_panel_toggle), target);
    g_signal_connect(inactive_pane_brightness, "value-changed",
                     G_CALLBACK(on_settings_inactive_brightness_changed),
                     target);
    g_signal_connect(theme, "changed", G_CALLBACK(on_settings_theme_changed), target);
    g_signal_connect(theme_library, "clicked",
                     G_CALLBACK(on_open_theme_library_clicked), target);
    g_signal_connect(translucency, "toggled",
                     G_CALLBACK(on_background_translucency_toggled), target);
    g_signal_connect(background_opacity, "value-changed",
                     G_CALLBACK(on_background_opacity_changed), target);
    g_signal_connect(family, "changed", G_CALLBACK(on_settings_family_changed), target);
    g_signal_connect(antialias, "changed", G_CALLBACK(on_settings_antialias_changed), target);
    g_signal_connect(hinting, "changed", G_CALLBACK(on_settings_hinting_changed), target);
    g_signal_connect(dialog, "response", G_CALLBACK(on_settings_response), NULL);
    g_signal_connect(dialog, "destroy", G_CALLBACK(on_settings_destroy), context);
    GtkListBoxRow *first = gtk_list_box_get_row_at_index(
        GTK_LIST_BOX(categories), 0);
    gtk_list_box_select_row(GTK_LIST_BOX(categories), first);
    show_all_with_action_affordances(dialog);
    sync_launch_profile_sensitivity(context);
    present_configured_window(dialog);
    gint rendered_width = 0;
    gint rendered_height = 0;
    gtk_window_get_size(GTK_WINDOW(dialog), &rendered_width,
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
            settings_width, settings_height, rendered_width, rendered_height,
            settings_geometry.min_width, settings_geometry.min_height,
            settings_geometry.max_width, settings_geometry.max_height,
            gtk_widget_get_scale_factor(dialog));
    }
    if (first != NULL) gtk_widget_grab_focus(GTK_WIDGET(first));
}

static void on_settings_menu_activate(GtkWidget *item, gpointer user_data) {
    (void)item;
    open_grid_settings(user_data);
}

static void on_theme_import_clicked(GtkButton *button, gpointer user_data) {
    (void)button;
    NocttyGridContext *context = user_data;
    GtkWidget *noctalia_variant = NULL;
    GtkWidget *chooser = noctty_theme_import_dialog_new(
        context->window, &noctalia_variant);
    if (chooser == NULL) {
        set_theme_library_status(
            context, "Could not open the theme import dialog.", TRUE);
        return;
    }
    prepare_action_button_tree(chooser);
    if (run_grid_modal_dialog(context, GTK_DIALOG(chooser)) ==
        GTK_RESPONSE_ACCEPT) {
        gchar *filename = gtk_file_chooser_get_filename(GTK_FILE_CHOOSER(chooser));
        gchar *contents = NULL;
        gsize length = 0;
        if (filename == NULL ||
            !read_theme_file_bounded(filename, 4 * 1024 * 1024,
                                     &contents, &length)) {
            set_theme_library_status(
                context,
                "Could not read that theme. Choose a regular file up to 4 MiB.",
                TRUE);
        } else if (context->text_action != NULL) {
            int format = -1;
            const gsize filename_length = strlen(filename);
            if (filename_length >= 5 &&
                g_ascii_strcasecmp(
                    filename + filename_length - 5, ".json") == 0) {
                int variant = gtk_combo_box_get_active(
                    GTK_COMBO_BOX(noctalia_variant));
                format = variant == 1 ? 3 : variant == 2 ? 4 : -1;
            }
            int result = context->text_action(
                context->text_action_data, 1, filename, strlen(filename),
                contents, length, format);
            if (result == 0) {
                queue_theme_redraw(context);
                refresh_open_theme_selectors(context);
                set_theme_library_status(
                    context, "Theme imported, selected, and saved.", FALSE);
            } else if (result == NOCTTY_TEXT_ACTION_PERSISTENCE_FAILED) {
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
        g_free(contents);
        g_free(filename);
    }
    gtk_widget_destroy(chooser);
}

static void queue_theme_redraw(NocttyGridContext *context) {
    NocttyGridContext *root = root_grid_context(context);
    root->high_contrast = 0;
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        NocttyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        candidate->high_contrast = 0;
        if (!candidate->active || candidate->area == NULL) continue;
        gtk_widget_queue_draw(candidate->area);
        update_compact_tab(candidate);
    }
}

static void on_noctalia_current_theme_clicked(GtkButton *button,
                                               gpointer user_data) {
    (void)button;
    NocttyGridContext *context = user_data;
    gchar *path = g_build_filename(
        g_get_user_config_dir(), "noctalia", "colors.json", NULL);
    gchar *contents = NULL;
    gsize length = 0;
    int result = -1;
    if (read_theme_file_bounded(path, 1024 * 1024, &contents, &length) &&
        context->text_action != NULL)
        result = context->text_action(
            context->text_action_data, 1, path, strlen(path),
            contents, length, 5);
    if (result == 0) {
        queue_theme_redraw(context);
        refresh_open_theme_selectors(context);
        set_theme_library_status(
            context, "Current Noctalia colors imported, selected, and saved.",
            FALSE);
    } else if (result == NOCTTY_TEXT_ACTION_PERSISTENCE_FAILED) {
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
    g_free(contents);
    g_free(path);
}

typedef struct {
    gchar *path;
    gchar *label;
} NocttyNoctaliaScheme;

typedef struct {
    NocttyGridContext *context;
    GtkWidget *scheme;
    GtkWidget *variant;
    GtkWidget *status;
} NocttyNoctaliaThemeControls;

static void free_noctalia_scheme(gpointer data) {
    NocttyNoctaliaScheme *scheme = data;
    if (scheme == NULL) return;
    g_free(scheme->path);
    g_free(scheme->label);
    g_free(scheme);
}

static gint compare_noctalia_schemes(gconstpointer left_raw,
                                     gconstpointer right_raw) {
    const NocttyNoctaliaScheme *left =
        *(NocttyNoctaliaScheme * const *)left_raw;
    const NocttyNoctaliaScheme *right =
        *(NocttyNoctaliaScheme * const *)right_raw;
    return g_utf8_collate(left->label, right->label);
}

static gchar *find_noctalia_scheme_json(const gchar *root,
                                         const gchar *entry) {
    gchar *entry_path = g_build_filename(root, entry, NULL);
    if (g_file_test(entry_path, G_FILE_TEST_IS_REGULAR) &&
        g_str_has_suffix(entry, ".json"))
        return entry_path;
    if (!g_file_test(entry_path, G_FILE_TEST_IS_DIR)) {
        g_free(entry_path);
        return NULL;
    }
    gchar *expected_name = g_strdup_printf("%s.json", entry);
    gchar *expected_path = g_build_filename(
        entry_path, expected_name, NULL);
    g_free(expected_name);
    if (g_file_test(expected_path, G_FILE_TEST_IS_REGULAR)) {
        g_free(entry_path);
        return expected_path;
    }
    g_free(expected_path);

    GDir *directory = g_dir_open(entry_path, 0, NULL);
    if (directory == NULL) {
        g_free(entry_path);
        return NULL;
    }
    gchar *match = NULL;
    const gchar *child = NULL;
    while ((child = g_dir_read_name(directory)) != NULL) {
        if (!g_str_has_suffix(child, ".json")) continue;
        gchar *candidate = g_build_filename(entry_path, child, NULL);
        if (g_file_test(candidate, G_FILE_TEST_IS_REGULAR)) {
            match = candidate;
            break;
        }
        g_free(candidate);
    }
    g_dir_close(directory);
    g_free(entry_path);
    return match;
}

static guint populate_noctalia_scheme_combo(GtkComboBoxText *combo) {
    gchar *root = g_build_filename(
        g_get_user_config_dir(), "noctalia", "colorschemes", NULL);
    GDir *directory = g_dir_open(root, 0, NULL);
    if (directory == NULL) {
        g_free(root);
        return 0;
    }
    GPtrArray *schemes = g_ptr_array_new_with_free_func(free_noctalia_scheme);
    const gchar *entry = NULL;
    while (schemes->len < 128 &&
           (entry = g_dir_read_name(directory)) != NULL) {
        if (entry[0] == '.') continue;
        gchar *path = find_noctalia_scheme_json(root, entry);
        if (path == NULL) continue;
        NocttyNoctaliaScheme *scheme = g_new0(NocttyNoctaliaScheme, 1);
        scheme->path = path;
        scheme->label = g_str_has_suffix(entry, ".json")
            ? g_strndup(entry, strlen(entry) - strlen(".json"))
            : g_strdup(entry);
        g_ptr_array_add(schemes, scheme);
    }
    g_dir_close(directory);
    g_free(root);
    g_ptr_array_sort(schemes, compare_noctalia_schemes);
    for (guint index = 0; index < schemes->len; index++) {
        NocttyNoctaliaScheme *scheme = g_ptr_array_index(schemes, index);
        gtk_combo_box_text_append(combo, scheme->path, scheme->label);
    }
    guint count = schemes->len;
    g_ptr_array_unref(schemes);
    if (count > 0) gtk_combo_box_set_active(GTK_COMBO_BOX(combo), 0);
    return count;
}

static void on_noctalia_theme_controls_destroy(GtkWidget *widget,
                                                gpointer user_data) {
    (void)widget;
    g_free(user_data);
}

static void on_noctalia_system_theme_clicked(GtkButton *button,
                                              gpointer user_data) {
    (void)button;
    NocttyNoctaliaThemeControls *controls = user_data;
    NocttyGridContext *context = root_grid_context(controls->context);
    const gchar *path = gtk_combo_box_get_active_id(
        GTK_COMBO_BOX(controls->scheme));
    gchar *label = gtk_combo_box_text_get_active_text(
        GTK_COMBO_BOX_TEXT(controls->scheme));
    int variant = gtk_combo_box_get_active(GTK_COMBO_BOX(controls->variant));
    if (path == NULL || label == NULL || variant < 0 ||
        context->text_action == NULL) {
        set_status_label_feedback(
            controls->status, "Select an installed Noctalia scheme.", TRUE);
        g_free(label);
        return;
    }
    gchar *contents = NULL;
    gsize length = 0;
    int format = variant == 0 ? 3 : 4;
    if (!read_theme_file_bounded(path, 1024 * 1024, &contents, &length)) {
        set_status_label_feedback(
            controls->status, "Theme file is unavailable or too large.", TRUE);
        g_free(label);
        return;
    }
    int result = context->text_action(
        context->text_action_data, 1, label, strlen(label), contents, length,
        format);
    if (result != 0 && result != NOCTTY_TEXT_ACTION_PERSISTENCE_FAILED) {
        set_status_label_feedback(
            controls->status,
            "Could not finish importing and saving this Noctalia theme.", TRUE);
        g_free(contents);
        g_free(label);
        return;
    }
    gchar *message = g_strdup_printf(
        result == NOCTTY_TEXT_ACTION_PERSISTENCE_FAILED
            ? "Using %s — %s for this session; the selection could not be saved."
            : "Using %s — %s.",
        label, variant == 0 ? "Dark" : "Light");
    set_status_label_feedback(
        controls->status, message,
        result == NOCTTY_TEXT_ACTION_PERSISTENCE_FAILED);
    g_free(message);
    queue_theme_redraw(context);
    refresh_open_theme_selectors(context);
    context->system_noctalia_theme_applied = 1;
    g_free(contents);
    g_free(label);
}

static void on_open_theme_library_clicked(GtkButton *button,
                                          gpointer user_data) {
    (void)button;
    open_theme_library(user_data);
}

static void on_theme_library_destroy(GtkWidget *widget,
                                     gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    if (root->theme_dialog == widget) root->theme_dialog = NULL;
}

static void open_theme_library(NocttyGridContext *context) {
    NocttyGridContext *root = root_grid_context(context);
    if (GTK_IS_WINDOW(root->theme_dialog)) {
        present_configured_window(root->theme_dialog);
        return;
    }
    GtkWidget *dialog = gtk_dialog_new_with_buttons("NOCTTY Theme Library", GTK_WINDOW(context->window), GTK_DIALOG_DESTROY_WITH_PARENT, "Close", GTK_RESPONSE_CLOSE, NULL);
    root->theme_dialog = dialog;
    (void)configure_overlay_window_stacking(
        context, dialog, "noctty-theme-library");
    GtkWidget *themes = gtk_combo_box_text_new();
    populate_theme_combo(context, GTK_COMBO_BOX_TEXT(themes));
    GtkWidget *noctalia_scheme = gtk_combo_box_text_new();
    guint noctalia_count = populate_noctalia_scheme_combo(
        GTK_COMBO_BOX_TEXT(noctalia_scheme));
    NocttyThemeLibraryContents contents = {0};
    if (!noctty_theme_library_contents_new(
            dialog, themes, noctalia_scheme, noctalia_count, &contents)) {
        root->theme_dialog = NULL;
        gtk_widget_destroy(dialog);
        return;
    }
    GtkWidget *noctalia_variant = contents.variant;
    GtkWidget *use_noctalia = contents.apply;
    GtkWidget *noctalia_status = contents.status;
    GtkWidget *import_noctalia = contents.import_current;
    GtkWidget *import = contents.import_file;
    NocttyNoctaliaThemeControls *noctalia_controls =
        g_new0(NocttyNoctaliaThemeControls, 1);
    noctalia_controls->context = root_grid_context(context);
    noctalia_controls->scheme = noctalia_scheme;
    noctalia_controls->variant = noctalia_variant;
    noctalia_controls->status = noctalia_status;
    root->system_noctalia_theme_listed = noctalia_count > 0;
    g_signal_connect(themes, "changed", G_CALLBACK(on_settings_theme_changed), context);
    g_signal_connect(use_noctalia, "clicked",
                     G_CALLBACK(on_noctalia_system_theme_clicked),
                     noctalia_controls);
    g_signal_connect(use_noctalia, "destroy",
                     G_CALLBACK(on_noctalia_theme_controls_destroy),
                     noctalia_controls);
    g_signal_connect(import_noctalia, "clicked",
                     G_CALLBACK(on_noctalia_current_theme_clicked), context);
    g_signal_connect(import, "clicked", G_CALLBACK(on_theme_import_clicked), context);
    g_signal_connect(dialog, "response", G_CALLBACK(gtk_widget_destroy), NULL);
    g_signal_connect(dialog, "destroy",
                     G_CALLBACK(on_theme_library_destroy), root);
    show_all_with_action_affordances(dialog);
}

static void on_theme_menu_activate(GtkWidget *item, gpointer user_data) {
    (void)item;
    open_theme_library(user_data);
}

static gboolean request_theme_smoke(gpointer user_data) {
    NocttyGridContext *context = user_data;
    open_theme_library(context);
    GtkWidget *import_variant = NULL;
    GtkWidget *import_dialog = noctty_theme_import_dialog_new(
        context->window, &import_variant);
    if (import_dialog != NULL && import_variant != NULL) {
        context->theme_import_dialog_built = 1;
        gtk_widget_destroy(import_dialog);
    }
    NocttyGridContext *root = root_grid_context(context);
    GtkWidget *system_apply = root->theme_dialog != NULL
        ? g_object_get_data(G_OBJECT(root->theme_dialog),
                            "noctty-system-noctalia-apply")
        : NULL;
    if (GTK_IS_BUTTON(system_apply))
        gtk_button_clicked(GTK_BUTTON(system_apply));
    const char *name = "Imported Night";
    const char *contents = "background = #000011\nforeground = #eeeeee\ncursor-color = #ff00aa\npalette = 1=#cc0000\n";
    if (context->text_action != NULL && context->text_action(context->text_action_data, 1, name, strlen(name), contents, strlen(contents), 0) == 0) context->theme_imported = 1;
    return G_SOURCE_REMOVE;
}

static gboolean confirm_grid_application_close(NocttyGridContext *context) {
    NocttyGridContext *root = root_grid_context(context);
    guint busy_count = foreground_process_count(root, NULL);
    return confirm_terminal_process_close(root, "application", busy_count,
                                          TRUE);
}

static gchar *find_nocted_binary(void) {
    GError *error = NULL;
    gchar *self_path = g_file_read_link("/proc/self/exe", &error);
    g_clear_error(&error);
    if (self_path != NULL) {
        gchar *directory = g_path_get_dirname(self_path);
        gchar *candidate = g_build_filename(directory, "nocted", NULL);
        g_free(directory);
        g_free(self_path);
        if (g_file_test(candidate, G_FILE_TEST_IS_EXECUTABLE))
            return candidate;
        g_free(candidate);
    }
    return g_find_program_in_path("nocted");
}

static gboolean launch_nocted(NocttyGridContext *context,
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
                            "Install the NoctEd binary beside NOCTTY or on PATH.");
        return FALSE;
    }
    gchar *normal_argv[] = {binary, NULL};
    gchar *smoke_argv[] = {binary, "--version", NULL};
    gboolean launched = g_spawn_async(
        context->nocted_directory_resolved ? directory : NULL,
        smoke ? smoke_argv : normal_argv, NULL, G_SPAWN_DEFAULT,
        NULL, NULL, NULL, error);
    g_free(binary);
    context->nocted_launch_succeeded = launched;
    context->nocted_process_separate = launched;
    return launched;
}

static void show_nocted_launch_error(NocttyGridContext *context,
                                     const gchar *detail) {
    GtkWidget *dialog = gtk_message_dialog_new(
        GTK_WINDOW(context->window),
        GTK_DIALOG_MODAL | GTK_DIALOG_DESTROY_WITH_PARENT,
        GTK_MESSAGE_ERROR, GTK_BUTTONS_CLOSE,
        "NoctEd could not be started");
    gtk_message_dialog_format_secondary_text(
        GTK_MESSAGE_DIALOG(dialog), "%s",
        detail != NULL ? detail : "The standalone editor is unavailable.");
    (void)run_grid_modal_dialog(context, GTK_DIALOG(dialog));
    gtk_widget_destroy(dialog);
}

static void open_editor_here(NocttyGridContext *context) {
    char path[4096];
    int length = noctty_grid_current_directory(
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
    g_clear_error(&error);
    g_free(directory);
}

static void on_project_editor_open(GtkButton *button, gpointer user_data) {
    (void)button;
    open_editor_here(user_data);
}

static gboolean spawn_workspace_window(NocttyGridContext *context,
                                        const gchar *path,
                                        int restore_mode) {
    if (context == NULL || path == NULL || path[0] != '/') return FALSE;
    GError *error = NULL;
    gchar *executable = g_file_read_link("/proc/self/exe", &error);
    if (executable == NULL) {
        g_clear_error(&error);
        return FALSE;
    }
    gchar restore_mode_text[8];
    g_snprintf(restore_mode_text, sizeof(restore_mode_text), "%d", restore_mode);
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
    g_clear_error(&error);
    g_free(executable);
    return launched;
}

static void on_project_recent_open(GtkButton *button, gpointer user_data) {
    NocttyGridContext *context = user_data;
    GtkWidget *combo = g_object_get_data(
        G_OBJECT(button), "noctty-recent-workspace-combo");
    if (!GTK_IS_COMBO_BOX_TEXT(combo)) return;
    gchar *path = gtk_combo_box_text_get_active_text(
        GTK_COMBO_BOX_TEXT(combo));
    if (path != NULL && !spawn_workspace_window(context, path, 0)) {
        GtkWidget *dialog = gtk_message_dialog_new(
            GTK_WINDOW(context->window),
            GTK_DIALOG_MODAL | GTK_DIALOG_DESTROY_WITH_PARENT,
            GTK_MESSAGE_ERROR, GTK_BUTTONS_CLOSE,
            "Could not open the selected workspace");
        gtk_message_dialog_format_secondary_text(
            GTK_MESSAGE_DIALOG(dialog),
            "The workspace was not opened. Check that the file still exists and try again.");
        (void)run_grid_modal_dialog(context, GTK_DIALOG(dialog));
        gtk_widget_destroy(dialog);
    }
    g_free(path);
}

static int choose_restore_mode(NocttyGridContext *context) {
    GtkWidget *dialog = gtk_dialog_new_with_buttons(
        "Restore Workspace", GTK_WINDOW(context->window),
        GTK_DIALOG_MODAL | GTK_DIALOG_DESTROY_WITH_PARENT,
        "Cancel", GTK_RESPONSE_CANCEL, "Restore", GTK_RESPONSE_ACCEPT, NULL);
    GtkWidget *box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 8);
    GtkWidget *label = gtk_label_new(
        "Choose what should survive restore. Agent resume uses only registered references.");
    GtkWidget *combo = gtk_combo_box_text_new();
    gtk_label_set_xalign(GTK_LABEL(label), 0.0);
    gtk_combo_box_text_append_text(GTK_COMBO_BOX_TEXT(combo),
                                   "Restart shells (layout and directories)");
    gtk_combo_box_text_append_text(GTK_COMBO_BOX_TEXT(combo),
                                   "Attach persistent tmux/Zellij sessions");
    gtk_combo_box_text_append_text(GTK_COMBO_BOX_TEXT(combo),
                                   "Resume registered agents");
    gtk_combo_box_set_active(GTK_COMBO_BOX(combo), 0);
    set_widget_accessible_name(combo, "Workspace restore mode");
    gtk_container_set_border_width(GTK_CONTAINER(box), 12);
    gtk_box_pack_start(GTK_BOX(box), label, FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(box), combo, FALSE, FALSE, 0);
    gtk_container_add(GTK_CONTAINER(gtk_dialog_get_content_area(GTK_DIALOG(dialog))), box);
    prepare_action_button_tree(dialog);
    int response = run_grid_modal_dialog(context, GTK_DIALOG(dialog));
    int mode = response == GTK_RESPONSE_ACCEPT
        ? gtk_combo_box_get_active(GTK_COMBO_BOX(combo)) : -1;
    gtk_widget_destroy(dialog);
    return mode;
}

static void choose_workspace_file(NocttyGridContext *context, int action) {
    GtkFileChooserAction chooser_action = action == 2 ? GTK_FILE_CHOOSER_ACTION_SAVE : GTK_FILE_CHOOSER_ACTION_OPEN;
    GtkWidget *chooser = gtk_file_chooser_dialog_new(action == 2 ? "Save NOCTTY Workspace" : "Open NOCTTY Workspace", GTK_WINDOW(context->window), chooser_action, "Cancel", GTK_RESPONSE_CANCEL, action == 2 ? "Save" : "Open", GTK_RESPONSE_ACCEPT, NULL);
    prepare_action_button_tree(chooser);
    if (action == 2) gtk_file_chooser_set_current_name(GTK_FILE_CHOOSER(chooser), "workspace.nocttyws");
    if (run_grid_modal_dialog(context, GTK_DIALOG(chooser)) ==
        GTK_RESPONSE_ACCEPT) {
        gchar *path = gtk_file_chooser_get_filename(GTK_FILE_CHOOSER(chooser));
        if (path != NULL) {
            gtk_widget_hide(chooser);
            if (action == 2 && context->text_action != NULL) {
                if (context->text_action(
                        context->text_action_data, action, path, strlen(path),
                        "", 0, 0) != 0) {
                    GtkWidget *dialog = gtk_message_dialog_new(
                        GTK_WINDOW(context->window),
                        GTK_DIALOG_MODAL | GTK_DIALOG_DESTROY_WITH_PARENT,
                        GTK_MESSAGE_ERROR, GTK_BUTTONS_CLOSE,
                        "Could not save the workspace");
                    gtk_message_dialog_format_secondary_text(
                        GTK_MESSAGE_DIALOG(dialog),
                        "The selected file was not changed. Check the path and permissions, then try again.");
                    (void)run_grid_modal_dialog(context, GTK_DIALOG(dialog));
                    gtk_widget_destroy(dialog);
                }
            }
            else if (action == 3) {
                const int restore_mode = choose_restore_mode(context);
                if (restore_mode >= 0 &&
                    !spawn_workspace_window(context, path, restore_mode)) {
                    GtkWidget *dialog = gtk_message_dialog_new(
                        GTK_WINDOW(context->window),
                        GTK_DIALOG_MODAL | GTK_DIALOG_DESTROY_WITH_PARENT,
                        GTK_MESSAGE_ERROR, GTK_BUTTONS_CLOSE,
                        "Could not restore the workspace");
                    gtk_message_dialog_format_secondary_text(
                        GTK_MESSAGE_DIALOG(dialog),
                        "The workspace was not opened. Check the file and NOCTTY installation, then try again.");
                    (void)run_grid_modal_dialog(context, GTK_DIALOG(dialog));
                    gtk_widget_destroy(dialog);
                }
            }
        }
        g_free(path);
    }
    gtk_widget_destroy(chooser);
}

static void on_project_workspace_save(GtkButton *button, gpointer user_data) { (void)button; choose_workspace_file(user_data, 2); }
static void on_project_workspace_open(GtkButton *button, gpointer user_data) { (void)button; choose_workspace_file(user_data, 3); }
static void on_project_destroy(GtkWidget *widget, gpointer user_data) {
    (void)widget;
    NocttyGridContext *context = user_data;
    context->project_dialog = NULL;
    context->recent_workspace_combo = NULL;
    context->recent_workspace_open = NULL;
}

static void open_project_tools(NocttyGridContext *context) {
    if (context->project_dialog != NULL) {
        present_configured_window(context->project_dialog);
        return;
    }
    /* Refresh project data only when the GUI surface that consumes it opens.
     * Background git subprocesses every ten seconds caused avoidable process
     * and descriptor churn throughout long terminal-only sessions. */
    if (context->event != NULL)
        context->event(context->event_data, context->pane_id, 108, 0,
                       (uint64_t)(g_get_monotonic_time() / 1000));
    GtkWidget *dialog = gtk_dialog_new_with_buttons("NOCTTY Project Workspace", GTK_WINDOW(context->window), GTK_DIALOG_DESTROY_WITH_PARENT, "Close", GTK_RESPONSE_CLOSE, NULL);
    (void)configure_overlay_window_stacking(
        context, dialog, "noctty-project-workspace");
    GdkRectangle project_workarea = {0, 0, 680, 520};
    GdkMonitor *project_monitor = grid_monitor_for_window(context->window);
    if (project_monitor != NULL)
        gdk_monitor_get_workarea(project_monitor, &project_workarea);
    gtk_window_set_default_size(
        GTK_WINDOW(dialog),
        noctty_grid_dialog_dimension(project_workarea.width, 680, 1, 32),
        noctty_grid_dialog_dimension(project_workarea.height, 520, 1, 32));
    gtk_window_set_resizable(GTK_WINDOW(dialog), TRUE);
    char summary_text[4096] = "Project data unavailable";
    if (context->text_action != NULL) {
        int length = context->text_action(context->text_action_data, 6, "", 0,
                                          summary_text,
                                          sizeof(summary_text) - 1, 0);
        if (length >= 0 && length < (int)sizeof(summary_text))
            summary_text[length] = '\0';
    }
    NocttyProjectContents contents = {0};
    if (!noctty_project_contents_new(dialog, summary_text, &contents)) {
        gtk_widget_destroy(dialog);
        return;
    }
    GtkWidget *save = contents.save;
    GtkWidget *open = contents.open;
    GtkWidget *recent_combo = contents.recent_combo;
    GtkWidget *recent_open = contents.recent_open;
    GtkWidget *editor = contents.editor;
    AtkObject *summary_accessible =
        gtk_widget_get_accessible(contents.summary);
    AtkObject *recent_accessible = gtk_widget_get_accessible(recent_combo);
    context->project_summary_scrollable =
        GTK_IS_SCROLLED_WINDOW(contents.summary_scroll);
    context->project_summary_accessible = summary_accessible != NULL &&
        g_strcmp0(atk_object_get_name(summary_accessible),
                  "Workspace summary") == 0 &&
        recent_accessible != NULL &&
        g_strcmp0(atk_object_get_name(recent_accessible),
                  "Recent workspaces") == 0;
    int recent_count = context->event_data != NULL
        ? noctty_grid_recent_workspace(
              context->event_data, -1, summary_text, 0)
        : 0;
    int recent_added = 0;
    for (int index = 0; index < recent_count && index < 8; index++) {
        char path[4097] = {0};
        int length = noctty_grid_recent_workspace(
            context->event_data, index, path, sizeof(path) - 1);
        if (length <= 0 || length >= (int)sizeof(path)) continue;
        path[length] = '\0';
        gtk_combo_box_text_append_text(GTK_COMBO_BOX_TEXT(recent_combo), path);
        recent_added++;
    }
    if (recent_added > 0)
        gtk_combo_box_set_active(GTK_COMBO_BOX(recent_combo), 0);
    gtk_widget_set_sensitive(recent_combo, recent_added > 0);
    gtk_widget_set_sensitive(recent_open, recent_added > 0);
    context->recent_workspace_control = recent_added > 0 &&
        recent_added == recent_count;
    context->project_dialog = dialog;
    context->recent_workspace_combo = recent_combo;
    context->recent_workspace_open = recent_open;
    g_signal_connect(save, "clicked", G_CALLBACK(on_project_workspace_save), context);
    g_signal_connect(open, "clicked", G_CALLBACK(on_project_workspace_open), context);
    g_object_set_data(G_OBJECT(recent_open),
                      "noctty-recent-workspace-combo", recent_combo);
    g_signal_connect(recent_open, "clicked",
                     G_CALLBACK(on_project_recent_open), context);
    g_signal_connect(editor, "clicked", G_CALLBACK(on_project_editor_open), context);
    g_signal_connect(dialog, "response", G_CALLBACK(gtk_widget_destroy), NULL);
    g_signal_connect(dialog, "destroy", G_CALLBACK(on_project_destroy), context);
    show_all_with_action_affordances(dialog);
}

#if NOCTTY_ENABLE_SMOKE
#include "../../tests/native_grid_activation_child_smoke.inc"
#endif

static void on_project_menu_activate(GtkWidget *item, gpointer user_data) { (void)item; open_project_tools(user_data); }

static GtkWidget *find_workspace_menu_item(GtkWidget *menu,
                                           const gchar *label) {
    if (!GTK_IS_CONTAINER(menu)) return NULL;
    GList *items = gtk_container_get_children(GTK_CONTAINER(menu));
    GtkWidget *match = NULL;
    for (GList *item = items; item != NULL && match == NULL;
         item = item->next) {
        if (!GTK_IS_MENU_ITEM(item->data)) continue;
        const gchar *candidate = gtk_menu_item_get_label(
            GTK_MENU_ITEM(item->data));
        if (g_strcmp0(candidate, label) == 0) {
            match = item->data;
            break;
        }
        GtkWidget *submenu = gtk_menu_item_get_submenu(
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
    GtkWidget *split_menu = gtk_menu_item_get_submenu(
        GTK_MENU_ITEM(split_parent));
    if (split_menu == NULL) return FALSE;
    const gchar *expected[] = {
        "Split Right", "Split Down", "Split Up", "Split Left",
    };
    GList *items = gtk_container_get_children(GTK_CONTAINER(split_menu));
    gboolean matches = g_list_length(items) == (gint)G_N_ELEMENTS(expected);
    guint index = 0;
    for (GList *item = items; matches && item != NULL;
         item = item->next, index++) {
        if (!GTK_IS_MENU_ITEM(item->data) ||
            g_strcmp0(gtk_menu_item_get_label(GTK_MENU_ITEM(item->data)),
                      expected[index]) != 0)
            matches = FALSE;
    }
    g_list_free(items);
    return matches;
}

static gboolean finish_project_smoke(gpointer user_data) {
    NocttyGridContext *context = user_data;
    open_project_tools(context);
    gboolean project_ready = context->project_dialog != NULL &&
        gtk_widget_get_mapped(context->project_dialog);
    if (!project_ready && context->project_smoke_attempts++ < 40) {
        g_timeout_add(25, finish_project_smoke, context);
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
    NocttyGridContext *context = user_data;
    NocttyGridContext *root = root_grid_context(context);
    GtkWidget *menu = root->workspace_menu;
    gboolean menu_mapped = menu != NULL && gtk_widget_get_mapped(menu) &&
        gtk_widget_get_mapped(root->window) && root->window_presented;
    if (menu_mapped) root->context_menu_survived = 1;
    gboolean menu_ready = root->context_menu_survived && menu_mapped;
    GtkWidget *editor_item = menu_ready
        ? find_workspace_menu_item(menu, "Open NoctEd Here")
        : NULL;
    if (editor_item == NULL) {
        if (context->project_smoke_attempts++ < 80) {
            g_timeout_add(25, continue_project_smoke, context);
            return G_SOURCE_REMOVE;
        }
        context->project_smoke_done = 0;
        return G_SOURCE_REMOVE;
    }
    gtk_menu_shell_select_item(GTK_MENU_SHELL(menu), editor_item);
    gtk_menu_shell_activate_item(GTK_MENU_SHELL(menu), editor_item, TRUE);
    context->project_smoke_attempts = 0;
    g_timeout_add(250, finish_project_smoke, context);
    return G_SOURCE_REMOVE;
}

static gboolean wait_project_menu_mapped_smoke(gpointer user_data) {
    NocttyGridContext *context = user_data;
    NocttyGridContext *root = root_grid_context(context);
    GtkWidget *menu = root->workspace_menu;
    gboolean menu_mapped = menu != NULL && gtk_widget_get_mapped(menu) &&
        gtk_widget_get_mapped(root->window) && root->window_presented;
    if (!menu_mapped && context->project_smoke_attempts++ < 80) {
        g_timeout_add(25, wait_project_menu_mapped_smoke, context);
        return G_SOURCE_REMOVE;
    }
    if (!menu_mapped) {
        context->project_smoke_attempts = 0;
        context->project_smoke_done = 0;
        return G_SOURCE_REMOVE;
    }
    context->project_smoke_attempts = 0;
    (void)on_window_focus_out(root->window, NULL, root);
    g_timeout_add(180, continue_project_smoke, context);
    return G_SOURCE_REMOVE;
}

static gboolean request_project_smoke(gpointer user_data) {
    NocttyGridContext *context = user_data;
    NocttyGridContext *root = root_grid_context(context);
    gboolean surface_ready = root->window != NULL && context->area != NULL &&
        root->window_presented && gtk_widget_get_mapped(root->window) &&
        gtk_widget_get_mapped(context->area);
    if (!surface_ready && context->project_smoke_attempts++ < 200) {
        g_timeout_add(25, request_project_smoke, context);
        return G_SOURCE_REMOVE;
    }
    if (!surface_ready) {
        context->project_smoke_attempts = 0;
        context->project_smoke_done = 0;
        return G_SOURCE_REMOVE;
    }
    const char *workspace = "/tmp/noctty-native-grid-project.nocttyws";
    int ok = context->text_action != NULL;
    if (ok) ok = context->text_action(context->text_action_data, 2, workspace,
                                      strlen(workspace), "", 0, 0) == 0;
    if (ok) ok = context->text_action(context->text_action_data, 3, workspace,
                                      strlen(workspace), "", 0, 0) == 0;
    context->project_smoke_done = ok;
    context->project_smoke_attempts = 0;
    if (!ok) return G_SOURCE_REMOVE;
    (void)open_smoke_workspace_menu(context);
    g_timeout_add(25, wait_project_menu_mapped_smoke, context);
    return G_SOURCE_REMOVE;
}

static gboolean compact_escape_closes(GtkWidget *widget, GdkEventKey *event,
                                      gpointer user_data) {
    (void)user_data;
    if (event->keyval != GDK_KEY_Escape) return FALSE;
    gtk_widget_destroy(widget);
    return TRUE;
}

static void on_find_destroy(GtkWidget *widget, gpointer user_data) {
    (void)widget;
    NocttyGridContext *root = user_data;
    root->find_dialog = NULL;
    root->find_entry = NULL;
    root->find_status = NULL;
}

static void set_widget_accessible_name(GtkWidget *widget, const char *name) {
    AtkObject *accessible = gtk_widget_get_accessible(widget);
    if (accessible != NULL) atk_object_set_name(accessible, name);
}

static void set_status_label_feedback(GtkWidget *label, const char *message,
                                      gboolean is_error) {
    if (!GTK_IS_LABEL(label) || message == NULL) return;
    AtkObject *accessible = gtk_widget_get_accessible(label);
    AtkRole target_role = is_error ? ATK_ROLE_ALERT : ATK_ROLE_STATUSBAR;
    gboolean text_changed =
        g_strcmp0(gtk_label_get_text(GTK_LABEL(label)), message) != 0;
    gboolean role_changed =
        accessible != NULL && atk_object_get_role(accessible) != target_role;
    gboolean description_changed =
        accessible != NULL &&
        g_strcmp0(atk_object_get_description(accessible), message) != 0;
    if (text_changed) gtk_label_set_text(GTK_LABEL(label), message);
    if (accessible == NULL) return;
    if (role_changed) atk_object_set_role(accessible, target_role);
    if (description_changed) atk_object_set_description(accessible, message);
    if (text_changed || role_changed || description_changed)
        g_signal_emit_by_name(accessible, "visible-data-changed");
}

static gboolean widget_has_accessible_name(GtkWidget *widget,
                                           const char *name) {
    AtkObject *accessible = gtk_widget_get_accessible(widget);
    const char *actual = accessible != NULL
        ? atk_object_get_name(accessible) : NULL;
    return g_strcmp0(actual, name) == 0;
}

static void apply_terminal_find(NocttyGridContext *root) {
    if (root->find_dialog == NULL || root->find_entry == NULL) return;
    NocttyGridContext *target = g_object_get_data(G_OBJECT(root->find_dialog),
                                                  "noctty-find-target");
    if (target == NULL) return;
    const gchar *query = gtk_entry_get_text(GTK_ENTRY(root->find_entry));
    if (query == NULL || query[0] == '\0') {
        target->selecting = 0;
        gtk_label_set_text(GTK_LABEL(root->find_status), "Type to search scrollback");
        gtk_widget_queue_draw(target->area);
        return;
    }
    int column = 0, row = 0, length = 0, matches = 0;
    int found = noctty_grid_find(target->userdata, query, strlen(query), 1,
                                 root->find_ordinal, &column, &row, &length,
                                 &matches);
    if (found == 1) {
        target->selection_start_column = column;
        target->selection_end_column =
            column + noctty_grid_selection_end(length);
        target->selection_start_row = row;
        target->selection_end_row = row;
        target->selection_dragging = 0;
        target->selecting = 1;
        char status[96];
        g_snprintf(status, sizeof(status), "%zu / %d  ·  Enter for previous",
                   noctty_grid_search_display_ordinal(
                       root->find_ordinal, matches),
                   matches);
        gtk_label_set_text(GTK_LABEL(root->find_status), status);
    } else {
        target->selecting = 0;
        gtk_label_set_text(GTK_LABEL(root->find_status), "No matches");
    }
    gtk_widget_queue_draw(target->area);
}

static void on_find_changed(GtkEditable *editable, gpointer user_data) {
    (void)editable;
    NocttyGridContext *root = user_data;
    root->find_ordinal = 0;
    apply_terminal_find(root);
}

static gboolean on_find_key(GtkWidget *widget, GdkEventKey *event,
                            gpointer user_data) {
    NocttyGridContext *root = user_data;
    if (event->keyval == GDK_KEY_Escape) {
        gtk_widget_destroy(root->find_dialog);
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

static void open_terminal_find(NocttyGridContext *context) {
    NocttyGridContext *root = root_grid_context(context);
    if (root->find_dialog != NULL) {
        g_object_set_data(G_OBJECT(root->find_dialog), "noctty-find-target", context);
        present_configured_window(root->find_dialog);
        gtk_widget_grab_focus(root->find_entry);
        return;
    }
    GdkRectangle workarea = {0, 0, 640, 360};
    GdkMonitor *monitor = grid_monitor_for_window(root->window);
    if (monitor != NULL) gdk_monitor_get_workarea(monitor, &workarea);
    int dialog_width =
        noctty_grid_dialog_dimension(workarea.width, 640, 1, 32);
    int dialog_height = workarea.width < 600 ? 132 : 76;
    dialog_height = noctty_grid_dialog_dimension(
        workarea.height, dialog_height, 1, 32);
    GtkWidget *dialog = gtk_dialog_new();
    NocttyFindContents contents = {0};
    if (!noctty_terminal_find_contents_new(
            dialog, dialog_width, workarea.width < 600, &contents)) {
        gtk_widget_destroy(dialog);
        return;
    }
    GtkWidget *entry = contents.entry;
    GtkWidget *status = contents.status;
    (void)configure_overlay_window_stacking(
        root, dialog, "noctty-terminal-find");
    configure_overlay_window_geometry(
        root, dialog, &workarea, dialog_width, dialog_height);
    gtk_window_set_default_size(
        GTK_WINDOW(dialog), dialog_width, dialog_height);
    gtk_window_set_modal(GTK_WINDOW(dialog), TRUE);
    gtk_window_set_decorated(GTK_WINDOW(dialog), FALSE);
    gtk_window_set_position(GTK_WINDOW(dialog), GTK_WIN_POS_CENTER_ON_PARENT);
    g_object_set_data(G_OBJECT(dialog), "noctty-find-target", context);
    root->find_dialog = dialog;
    root->find_entry = entry;
    root->find_status = status;
    root->find_ordinal = 0;
    root->compact_find_shown = 1;
    if (context->event != NULL) context->event(context->event_data, context->pane_id, 66, 0, (uint64_t)(g_get_monotonic_time() / 1000));
    g_signal_connect(entry, "changed", G_CALLBACK(on_find_changed), root);
    g_signal_connect(entry, "key-press-event", G_CALLBACK(on_find_key), root);
    g_signal_connect(dialog, "destroy", G_CALLBACK(on_find_destroy), root);
    show_all_with_action_affordances(dialog);
    gtk_widget_grab_focus(entry);
}

static gboolean save_quick_note(NocttyGridContext *root) {
    if (root->note_load_failed) return TRUE;
    if (root->note_view == NULL || root->text_action == NULL) return FALSE;
    GtkTextBuffer *buffer = gtk_text_view_get_buffer(GTK_TEXT_VIEW(root->note_view));
    GtkTextIter start, end;
    gtk_text_buffer_get_bounds(buffer, &start, &end);
    gchar *text = gtk_text_buffer_get_text(buffer, &start, &end, FALSE);
    gboolean saved = root->text_action(
        root->text_action_data, 9, "", 0, text, strlen(text), 0) == 0;
    g_free(text);
    set_status_label_feedback(
        root->note_status,
        saved ? "Workspace note · saved automatically"
              : "Workspace note · save failed; keep this window open",
        !saved);
    if (saved) root->compact_note_shown = 1;
    return saved;
}

static gboolean flush_quick_note(gpointer user_data) {
    NocttyGridContext *root = user_data;
    root->note_save_source = 0;
    (void)save_quick_note(root);
    return G_SOURCE_REMOVE;
}

static void on_quick_note_changed(GtkTextBuffer *buffer, gpointer user_data) {
    (void)buffer;
    NocttyGridContext *root = user_data;
    if (root->note_save_source != 0) g_source_remove(root->note_save_source);
    root->note_save_source = g_timeout_add(250, flush_quick_note, root);
}

static void on_quick_note_destroy(GtkWidget *widget, gpointer user_data) {
    (void)widget;
    NocttyGridContext *root = user_data;
    if (root->note_save_source != 0) {
        g_source_remove(root->note_save_source);
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
    NocttyGridContext *root = user_data;
    if (root->note_save_source != 0) {
        g_source_remove(root->note_save_source);
        root->note_save_source = 0;
    }
    if (save_quick_note(root)) gtk_widget_destroy(GTK_WIDGET(dialog));
}

static gboolean on_quick_note_delete(GtkWidget *widget, GdkEvent *event,
                                     gpointer user_data) {
    (void)widget;
    (void)event;
    NocttyGridContext *root = user_data;
    if (root->note_save_source != 0) {
        g_source_remove(root->note_save_source);
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

static void open_quick_note(NocttyGridContext *context) {
    NocttyGridContext *root = root_grid_context(context);
    if (root->note_dialog != NULL) {
        present_configured_window(root->note_dialog);
        gtk_widget_grab_focus(root->note_view);
        return;
    }
    GdkRectangle workarea = {0, 0, 640, 480};
    GdkMonitor *monitor = grid_monitor_for_window(root->window);
    if (monitor != NULL) gdk_monitor_get_workarea(monitor, &workarea);
    int dialog_width =
        noctty_grid_dialog_dimension(workarea.width, 600, 1, 32);
    int dialog_height =
        noctty_grid_dialog_dimension(workarea.height, 380, 1, 32);
    GtkWidget *dialog = gtk_dialog_new_with_buttons("Quick Note", GTK_WINDOW(root->window),
        GTK_DIALOG_DESTROY_WITH_PARENT, "Close", GTK_RESPONSE_CLOSE, NULL);
    (void)configure_overlay_window_stacking(
        root, dialog, "noctty-quick-note");
    configure_overlay_window_geometry(
        root, dialog, &workarea, dialog_width, dialog_height);
    gtk_window_set_default_size(
        GTK_WINDOW(dialog), dialog_width, dialog_height);
    NocttyQuickNoteContents note_contents = {0};
    if (!noctty_quick_note_contents_new(
            dialog, dialog_width, dialog_height, &note_contents)) {
        gtk_widget_destroy(dialog);
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
        gtk_text_view_set_editable(GTK_TEXT_VIEW(view), FALSE);
        set_status_label_feedback(
            hint,
            "Workspace note could not be loaded; close this window and try again.",
            TRUE);
    } else {
        if (length > 0)
            gtk_text_buffer_set_text(
                gtk_text_view_get_buffer(GTK_TEXT_VIEW(view)), contents, length);
        set_status_label_feedback(
            hint, "Workspace note · saved automatically", FALSE);
    }
    g_free(contents);
    g_signal_connect(gtk_text_view_get_buffer(GTK_TEXT_VIEW(view)), "changed",
                     G_CALLBACK(on_quick_note_changed), root);
    g_signal_connect(dialog, "response", G_CALLBACK(on_quick_note_response), root);
    g_signal_connect(dialog, "delete-event", G_CALLBACK(on_quick_note_delete), root);
    g_signal_connect(dialog, "key-press-event", G_CALLBACK(on_quick_note_key), root);
    g_signal_connect(dialog, "destroy", G_CALLBACK(on_quick_note_destroy), root);
    gtk_window_set_decorated(GTK_WINDOW(dialog), FALSE);
    show_all_with_action_affordances(dialog);
    gtk_widget_grab_focus(view);
}

static void on_shortcuts_destroy(GtkWidget *widget, gpointer user_data) {
    (void)widget;
    root_grid_context(user_data)->shortcuts_dialog = NULL;
}

static void open_shortcuts_overlay(NocttyGridContext *context) {
    NocttyGridContext *root = root_grid_context(context);
    if (root->shortcuts_dialog != NULL) {
        present_configured_window(root->shortcuts_dialog);
        return;
    }
    GdkRectangle workarea = {0, 0, 640, 560};
    GdkMonitor *monitor = grid_monitor_for_window(root->window);
    if (monitor != NULL) gdk_monitor_get_workarea(monitor, &workarea);
    int dialog_width =
        noctty_grid_dialog_dimension(workarea.width, 620, 1, 32);
    int dialog_height =
        noctty_grid_dialog_dimension(workarea.height, 620, 1, 32);
    gchar *visibility_shortcut = grid_shortcut_label_alloc(root);
    gchar *shortcuts = g_strdup_printf(
        "Ctrl+Shift+P   Command palette\n"
        "Ctrl+Shift+F   Find in scrollback\n"
        "Ctrl+Shift+N   Quick note\n"
        "Ctrl+Shift+G   Smart Tab filter\n"
        "Ctrl+Shift+Y   Tag selected panes\n"
        "Ctrl+Shift+Z   Zoom / restore pane\n"
        "Ctrl+Tab       Next terminal pane\n"
        "Ctrl+Shift+Tab Next tab / Smart Tab\n"
        "Hold Alt       Show note in each pane\n"
        "Alt+Arrow      Focus pane by direction\n"
        "Alt+wheel      Previous / next pane\n"
        "Ctrl+Alt+wheel Previous / next tab\n"
        "Ctrl+wheel     Pane font up / down\n"
        "Shift+PageUp   Scroll terminal history up\n"
        "Shift+PageDown Scroll terminal history down\n"
        "Shift+Home     Oldest terminal history\n"
        "Shift+End      Live terminal output\n"
        "Ctrl+C         Interrupt active pane\n"
        "Ctrl+D         Close active pane\n"
        "Ctrl+PageUp    Previous tab\n"
        "Ctrl+PageDown  Next tab\n"
        "Ctrl+Shift+W   Close tab\n"
        "Ctrl+Shift+R   Rename active tab\n"
        "Ctrl+Shift+T   Reopen last tab / new tab\n"
        "Ctrl+Shift+S   Split down\n"
        "Ctrl+Shift+L   Split left\n"
        "Ctrl+Alt+B     Enable / disable broadcast input\n"
        "Ctrl+Alt+=     Lighten active tab color\n"
        "Ctrl+Alt+-     Darken active tab color\n"
        "Ctrl+Shift+K   This shortcut card\n"
        "Double-click   Zoom pane\n"
        "%-15s Show / hide NOCTTY",
        visibility_shortcut);
    GtkWidget *dialog = gtk_dialog_new_with_buttons("NOCTTY Shortcuts", GTK_WINDOW(root->window),
        GTK_DIALOG_DESTROY_WITH_PARENT, "Close", GTK_RESPONSE_CLOSE, NULL);
    (void)configure_overlay_window_stacking(
        root, dialog, "noctty-shortcuts");
    configure_overlay_window_geometry(
        root, dialog, &workarea, dialog_width, dialog_height);
    gtk_window_set_default_size(
        GTK_WINDOW(dialog), dialog_width, dialog_height);
    if (!noctty_shortcuts_contents_new(
            dialog, shortcuts, dialog_width, dialog_height)) {
        g_free(shortcuts);
        g_free(visibility_shortcut);
        gtk_widget_destroy(dialog);
        return;
    }
    g_free(shortcuts);
    g_free(visibility_shortcut);
    root->shortcuts_dialog = dialog;
    g_signal_connect(dialog, "response", G_CALLBACK(gtk_widget_destroy), NULL);
    g_signal_connect(dialog, "key-press-event", G_CALLBACK(compact_escape_closes), NULL);
    g_signal_connect(dialog, "destroy", G_CALLBACK(on_shortcuts_destroy), root);
    gtk_window_set_decorated(GTK_WINDOW(dialog), FALSE);
    show_all_with_action_affordances(dialog);
}

static gboolean save_grid_scrollback_to_path(NocttyGridContext *context,
                                             const gchar *path) {
    if (context->text_action == NULL || path == NULL) return FALSE;
    const size_t capacity = 4 * 1024 * 1024;
    char *contents = g_malloc(capacity);
    int length = noctty_grid_scrollback(context->userdata, contents, capacity);
    gboolean saved = length >= 0 &&
        context->text_action(context->text_action_data, 10, path, strlen(path),
                             contents, (size_t)MAX(0, length), 0) == 0;
    g_free(contents);
    if (saved) root_grid_context(context)->compact_scrollback_saved = 1;
    return saved;
}

static void save_grid_encrypted_history(NocttyGridContext *context) {
    GtkWidget *chooser = gtk_file_chooser_dialog_new(
        "Export Encrypted Screen History", GTK_WINDOW(context->window),
        GTK_FILE_CHOOSER_ACTION_SAVE, "Cancel", GTK_RESPONSE_CANCEL,
        "Export", GTK_RESPONSE_ACCEPT, NULL);
    prepare_action_button_tree(chooser);
    gtk_file_chooser_set_current_name(
        GTK_FILE_CHOOSER(chooser), "noctty-history.nocttyhs");
    gtk_file_chooser_set_do_overwrite_confirmation(GTK_FILE_CHOOSER(chooser), TRUE);
    if (run_grid_modal_dialog(context, GTK_DIALOG(chooser)) == GTK_RESPONSE_ACCEPT) {
        gchar *path = gtk_file_chooser_get_filename(GTK_FILE_CHOOSER(chooser));
        GtkWidget *password_dialog = gtk_dialog_new_with_buttons(
            "Protect Screen History", GTK_WINDOW(context->window),
            GTK_DIALOG_MODAL | GTK_DIALOG_DESTROY_WITH_PARENT,
            "Cancel", GTK_RESPONSE_CANCEL, "Export", GTK_RESPONSE_ACCEPT, NULL);
        GtkWidget *box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 8);
        GtkWidget *label = gtk_label_new(
            "Use at least 8 characters. The password is not stored by NOCTTY.");
        GtkWidget *entry = gtk_entry_new();
        gtk_label_set_xalign(GTK_LABEL(label), 0.0);
        gtk_entry_set_visibility(GTK_ENTRY(entry), FALSE);
        gtk_entry_set_max_length(GTK_ENTRY(entry), 4096);
        set_widget_accessible_name(entry, "Screen history password");
        gtk_container_set_border_width(GTK_CONTAINER(box), 12);
        gtk_box_pack_start(GTK_BOX(box), label, FALSE, FALSE, 0);
        gtk_box_pack_start(GTK_BOX(box), entry, FALSE, FALSE, 0);
        gtk_container_add(GTK_CONTAINER(gtk_dialog_get_content_area(GTK_DIALOG(password_dialog))), box);
        prepare_action_button_tree(password_dialog);
        if (run_grid_modal_dialog(context, GTK_DIALOG(password_dialog)) == GTK_RESPONSE_ACCEPT) {
            const char *password = gtk_entry_get_text(GTK_ENTRY(entry));
            if (noctty_grid_save_encrypted_history(
                    context->userdata, context->event_data, path, strlen(path),
                    password, strlen(password)) != 0) {
                GtkWidget *error_dialog = gtk_message_dialog_new(
                    GTK_WINDOW(context->window), GTK_DIALOG_MODAL | GTK_DIALOG_DESTROY_WITH_PARENT,
                    GTK_MESSAGE_ERROR, GTK_BUTTONS_CLOSE,
                    "Could not export encrypted screen history");
                (void)run_grid_modal_dialog(context, GTK_DIALOG(error_dialog));
                gtk_widget_destroy(error_dialog);
            }
        }
        gtk_widget_destroy(password_dialog);
        g_free(path);
    }
    gtk_widget_destroy(chooser);
}

static void set_agent_resume_reference(NocttyGridContext *context) {
    GtkWidget *dialog = gtk_dialog_new_with_buttons(
        "Register Agent Resume Reference", GTK_WINDOW(context->window),
        GTK_DIALOG_MODAL | GTK_DIALOG_DESTROY_WITH_PARENT,
        "Cancel", GTK_RESPONSE_CANCEL, "Register", GTK_RESPONSE_ACCEPT, NULL);
    GtkWidget *box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 8);
    GtkWidget *provider = gtk_combo_box_text_new();
    GtkWidget *session = gtk_entry_new();
    GtkWidget *label = gtk_entry_new();
    gtk_combo_box_text_append_text(GTK_COMBO_BOX_TEXT(provider), "Claude Code");
    gtk_combo_box_text_append_text(GTK_COMBO_BOX_TEXT(provider), "Codex");
    gtk_combo_box_set_active(GTK_COMBO_BOX(provider), 0);
    gtk_entry_set_placeholder_text(GTK_ENTRY(session), "Opaque session ID");
    gtk_entry_set_placeholder_text(GTK_ENTRY(label), "Optional label");
    gtk_entry_set_max_length(GTK_ENTRY(session), 256);
    gtk_entry_set_max_length(GTK_ENTRY(label), 64);
    set_widget_accessible_name(provider, "Agent provider");
    set_widget_accessible_name(session, "Agent session reference");
    set_widget_accessible_name(label, "Agent display label");
    gtk_box_pack_start(GTK_BOX(box), gtk_label_new("Provider"), FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(box), provider, FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(box), gtk_label_new("Session reference"), FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(box), session, FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(box), gtk_label_new("Display label"), FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(box), label, FALSE, FALSE, 0);
    gtk_container_set_border_width(GTK_CONTAINER(box), 12);
    gtk_container_add(GTK_CONTAINER(gtk_dialog_get_content_area(GTK_DIALOG(dialog))), box);
    prepare_action_button_tree(dialog);
    if (run_grid_modal_dialog(context, GTK_DIALOG(dialog)) == GTK_RESPONSE_ACCEPT) {
        const char *session_id = gtk_entry_get_text(GTK_ENTRY(session));
        const char *display_label = gtk_entry_get_text(GTK_ENTRY(label));
        if (noctty_grid_set_agent_resume(
                context->event_data, context->pane_id,
                gtk_combo_box_get_active(GTK_COMBO_BOX(provider)),
                session_id, strlen(session_id), display_label, strlen(display_label)) != 0) {
            GtkWidget *error_dialog = gtk_message_dialog_new(
                GTK_WINDOW(context->window), GTK_DIALOG_MODAL | GTK_DIALOG_DESTROY_WITH_PARENT,
                GTK_MESSAGE_ERROR, GTK_BUTTONS_CLOSE,
                "Invalid agent resume reference");
            (void)run_grid_modal_dialog(context, GTK_DIALOG(error_dialog));
            gtk_widget_destroy(error_dialog);
        }
        refresh_active_pane_info(context);
    }
    gtk_widget_destroy(dialog);
}

static void clear_agent_resume_reference(NocttyGridContext *context) {
    if (noctty_grid_clear_agent_resume(
            context->event_data, context->pane_id) == 0) {
        refresh_active_pane_info(context);
        return;
    }
    GtkWidget *error_dialog = gtk_message_dialog_new(
        GTK_WINDOW(context->window),
        GTK_DIALOG_MODAL | GTK_DIALOG_DESTROY_WITH_PARENT,
        GTK_MESSAGE_ERROR, GTK_BUTTONS_CLOSE,
        "Could not clear the agent resume reference");
    gtk_message_dialog_format_secondary_text(
        GTK_MESSAGE_DIALOG(error_dialog),
        "The current reference was left unchanged. Try again after the pane is available.");
    (void)run_grid_modal_dialog(context, GTK_DIALOG(error_dialog));
    gtk_widget_destroy(error_dialog);
}

static void save_grid_scrollback(NocttyGridContext *context) {
    GtkWidget *chooser = gtk_file_chooser_dialog_new("Save Terminal Scrollback",
        GTK_WINDOW(context->window), GTK_FILE_CHOOSER_ACTION_SAVE,
        "Cancel", GTK_RESPONSE_CANCEL, "Save", GTK_RESPONSE_ACCEPT, NULL);
    prepare_action_button_tree(chooser);
    gtk_file_chooser_set_current_name(GTK_FILE_CHOOSER(chooser), "noctty-scrollback.txt");
    gtk_file_chooser_set_do_overwrite_confirmation(GTK_FILE_CHOOSER(chooser), TRUE);
    if (run_grid_modal_dialog(context, GTK_DIALOG(chooser)) ==
        GTK_RESPONSE_ACCEPT) {
        gchar *path = gtk_file_chooser_get_filename(GTK_FILE_CHOOSER(chooser));
        if (!save_grid_scrollback_to_path(context, path)) {
            GtkWidget *error_dialog = gtk_message_dialog_new(
                GTK_WINDOW(context->window),
                GTK_DIALOG_MODAL | GTK_DIALOG_DESTROY_WITH_PARENT,
                GTK_MESSAGE_ERROR, GTK_BUTTONS_CLOSE,
                "Could not save terminal scrollback");
            gtk_message_dialog_format_secondary_text(
                GTK_MESSAGE_DIALOG(error_dialog),
                "The selected file was not changed. Check the path and permissions, then try again.");
            (void)run_grid_modal_dialog(context, GTK_DIALOG(error_dialog));
            gtk_widget_destroy(error_dialog);
        }
        g_free(path);
    }
    gtk_widget_destroy(chooser);
}


static void on_palette_search_changed(GtkEditable *editable, gpointer user_data) {
    NocttyGridContext *root = user_data;
    const gchar *query = gtk_entry_get_text(GTK_ENTRY(editable));
    GList *rows = gtk_container_get_children(GTK_CONTAINER(root->palette_list));
    GtkListBoxRow *first_visible = NULL;
    for (GList *item = rows; item != NULL; item = item->next) {
        GtkWidget *row = item->data;
        const gchar *search = g_object_get_data(G_OBJECT(row), "noctty-palette-search");
        gboolean visible = search != NULL &&
            noctty_grid_fuzzy_match_ascii(
                (const uint8_t *)search, (uint32_t)strlen(search),
                (const uint8_t *)query, (uint32_t)strlen(query)) != 0;
        gtk_widget_set_visible(row, visible);
        if (visible && first_visible == NULL) first_visible = GTK_LIST_BOX_ROW(row);
    }
    g_list_free(rows);
    if (first_visible != NULL)
        gtk_list_box_select_row(GTK_LIST_BOX(root->palette_list), first_visible);
}

static void accept_pending_agent_action(NocttyGridContext *context) {
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

static void execute_palette_action(NocttyGridContext *context, int id) {
    if (id == 1) emit_grid_workspace_event(context, 20);
    else if (id == 2) emit_grid_workspace_event(context, 21);
    else if (id == 3) emit_grid_workspace_event(context, 22);
    else if (id == 4) toggle_grid_zoom(context);
    else if (id == 5) open_terminal_find(context);
    else if (id == 6) open_quick_note(context);
    else if (id == 7) on_broadcast_menu_activate(NULL, context);
    else if (id == 8) emit_grid_workspace_event(context, 56);
    else if (id == 9) open_grid_settings(context);
    else if (id == 10) open_theme_library(context);
    else if (id == 11) open_project_tools(context);
    else if (id == 18) open_editor_here(context);
    else if (id == 12) save_grid_scrollback(context);
    else if (id == 24) set_agent_resume_reference(context);
    else if (id == 25) clear_agent_resume_reference(context);
    else if (id == 26) save_grid_encrypted_history(context);
    else if (id == 27) accept_pending_agent_action(context);
    else if (id == 13) open_shortcuts_overlay(context);
    else if (id == 14) toggle_grid_window(context);
    else if (id == 15) {
        context->high_contrast = !context->high_contrast;
        if (context->event != NULL) context->event(context->event_data, context->pane_id, 48, context->high_contrast, (uint64_t)(g_get_monotonic_time() / 1000));
        gtk_widget_queue_draw(context->area);
    } else if (id == 16) {
        int position = (context->tab_position + 1) % 4;
        if (context->event != NULL) context->event(context->event_data, context->pane_id, 44, position, (uint64_t)(g_get_monotonic_time() / 1000));
        apply_grid_tab_position(context, position, TRUE);
    } else if (id == 17) {
        NocttyGridContext *root = root_grid_context(context);
        gint page_index = gtk_notebook_get_current_page(GTK_NOTEBOOK(root->notebook));
        GtkWidget *page = gtk_notebook_get_nth_page(GTK_NOTEBOOK(root->notebook), page_index);
        open_tab_rename(root, page);
    } else if (id == 19) {
        on_smart_filter_button_clicked(NULL, context);
    } else if (id == 20) {
        on_tag_selected_menu_activate(NULL, context);
    } else if (id == 21) {
        on_tag_remove_menu_activate(NULL, context);
    } else if (id == 22) {
        (void)adjust_active_tab_color(context, 1);
    } else if (id == 23) {
        (void)adjust_active_tab_color(context, -1);
    }
}

static void on_palette_row_activated(GtkListBox *box, GtkListBoxRow *row,
                                     gpointer user_data) {
    (void)box;
    NocttyGridContext *root = user_data;
    NocttyGridContext *target = g_object_get_data(G_OBJECT(root->palette_dialog),
                                                  "noctty-palette-target");
    int action = GPOINTER_TO_INT(g_object_get_data(G_OBJECT(row),
                                                   "noctty-palette-action"));
    gtk_widget_destroy(root->palette_dialog);
    if (target != NULL) execute_palette_action(target, action);
}

static void on_palette_search_activate(GtkEntry *entry, gpointer user_data) {
    (void)entry;
    NocttyGridContext *root = user_data;
    GtkListBoxRow *row = gtk_list_box_get_selected_row(GTK_LIST_BOX(root->palette_list));
    if (row != NULL) on_palette_row_activated(GTK_LIST_BOX(root->palette_list), row, root);
}

static void on_palette_destroy(GtkWidget *widget, gpointer user_data) {
    (void)widget;
    NocttyGridContext *root = user_data;
    root->palette_dialog = NULL;
    root->palette_search = NULL;
    root->palette_list = NULL;
}

static void open_command_palette(NocttyGridContext *context) {
    NocttyGridContext *root = root_grid_context(context);
    if (root->palette_dialog != NULL) {
        g_object_set_data(G_OBJECT(root->palette_dialog), "noctty-palette-target", context);
        present_configured_window(root->palette_dialog);
        gtk_widget_grab_focus(root->palette_search);
        return;
    }
    GdkRectangle workarea = {0, 0, 680, 460};
    GdkMonitor *monitor = grid_monitor_for_window(root->window);
    if (monitor != NULL) gdk_monitor_get_workarea(monitor, &workarea);
    int dialog_width =
        noctty_grid_dialog_dimension(workarea.width, 660, 1, 32);
    int dialog_height =
        noctty_grid_dialog_dimension(workarea.height, 390, 1, 32);
    gboolean vertical_rows = workarea.width < 640;
    GtkWidget *dialog = gtk_dialog_new();
    NocttyPaletteAction compact_actions[27] = {0};
    guint compact_action_count = noctty_grid_palette_actions(
        compact_actions, G_N_ELEMENTS(compact_actions));
    if (compact_action_count == 0) {
        gtk_widget_destroy(dialog);
        return;
    }
    gchar *visibility_hint = grid_shortcut_label_alloc(root);
    NocttyPaletteContents contents = {0};
    gboolean contents_ready = noctty_command_palette_contents_new(
        dialog, dialog_width, dialog_height, vertical_rows,
        compact_actions, compact_action_count, visibility_hint,
        &contents);
    g_free(visibility_hint);
    if (!contents_ready) {
        gtk_widget_destroy(dialog);
        return;
    }
    GtkWidget *search = contents.search;
    GtkWidget *list = contents.list;
    root->palette_dialog = dialog;
    root->palette_search = search;
    root->palette_list = list;
    root->compact_palette_shown = 1;
    g_object_set_data(G_OBJECT(dialog), "noctty-palette-target", context);
    if (root->layer_shell_active)
        (void)configure_overlay_window_stacking(
            root, dialog, "noctty-command-palette");
    else
        gtk_window_set_transient_for(GTK_WINDOW(dialog),
                                     GTK_WINDOW(root->window));
    configure_overlay_window_geometry(
        root, dialog, &workarea, dialog_width, dialog_height);
    gtk_window_set_default_size(
        GTK_WINDOW(dialog), dialog_width, dialog_height);
    gtk_window_set_modal(GTK_WINDOW(dialog), TRUE);
    gtk_window_set_decorated(GTK_WINDOW(dialog), FALSE);
    gtk_window_set_position(GTK_WINDOW(dialog), GTK_WIN_POS_CENTER_ON_PARENT);
    if (context->event != NULL) context->event(context->event_data, context->pane_id, 65, 0, (uint64_t)(g_get_monotonic_time() / 1000));
    g_signal_connect(search, "changed", G_CALLBACK(on_palette_search_changed), root);
    g_signal_connect(search, "activate", G_CALLBACK(on_palette_search_activate), root);
    g_signal_connect(dialog, "key-press-event", G_CALLBACK(compact_escape_closes), NULL);
    g_signal_connect(dialog, "destroy", G_CALLBACK(on_palette_destroy), root);
    g_signal_connect(list, "row-activated", G_CALLBACK(on_palette_row_activated), root);
    show_all_with_action_affordances(dialog);
    GtkListBoxRow *first = gtk_list_box_get_row_at_index(GTK_LIST_BOX(list), 0);
    if (first != NULL) gtk_list_box_select_row(GTK_LIST_BOX(list), first);
    gtk_widget_grab_focus(search);
}

#if NOCTTY_ENABLE_SMOKE
#include "../../tests/native_grid_compact_ux_smoke.inc"
#include "../../tests/native_grid_zoom_smoke.inc"
#endif

static gboolean draw_sharing_preview(GtkWidget *widget, cairo_t *cr,
                                     gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    NocttyGridSharingPreviewResult result = {0};
    if (noctty_grid_render_sharing_preview(
            cr, root->event_data,
            gtk_widget_get_allocated_width(widget),
            gtk_widget_get_allocated_height(widget), &result)) {
        root->sharing_layout_pane_mask |= result.pane_mask;
        root->sharing_layout_selected_seen |= result.selected_seen;
        root->sharing_layout_host_active_seen |= result.host_active_seen;
    }
    return FALSE;
}

static gboolean on_sharing_preview_button(GtkWidget *widget,
                                          GdkEventButton *event,
                                          gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    int width = gtk_widget_get_allocated_width(widget);
    int height = gtk_widget_get_allocated_height(widget);
    uint64_t pane_id = 0;
    uint64_t tab_id = 0;
    int ignored = 0;
    int count = noctty_grid_share_view_stream(
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
        if (noctty_grid_share_view_pane_layout(
                root->event_data, pane_index, &x, &y, &pane_width,
                &pane_height, &selected, &host_active) <= 0)
            continue;
        if (noctty_grid_sharing_pane_hit(
                event->x, event->y, width, height,
                (double)x, (double)y, (double)pane_width,
                (double)pane_height) == 0)
            continue;
        GtkComboBox *streams = root->sharing_dialog != NULL
            ? GTK_COMBO_BOX(g_object_get_data(
                  G_OBJECT(root->sharing_dialog), "noctty-sharing-streams"))
            : NULL;
        char index_id[24] = {0};
        if (noctty_grid_sharing_index_text(
                pane_index, (uint8_t *)index_id, sizeof(index_id)) <= 0)
            continue;
        if (streams != NULL &&
            gtk_combo_box_set_active_id(streams, index_id)) {
            gtk_widget_grab_focus(widget);
            return TRUE;
        }
        if (noctty_grid_share_view_select(root->event_data, pane_index) == 0) {
            gtk_widget_grab_focus(widget);
            gtk_widget_queue_draw(widget);
            return TRUE;
        }
    }
    return FALSE;
}
static gboolean on_sharing_preview_scroll(
    GtkWidget *widget, GdkEventScroll *event, gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    double delta_y = 0.0;
    if (event->direction == GDK_SCROLL_SMOOTH)
        (void)gdk_event_get_scroll_deltas(
            (GdkEvent *)event, &(double){0.0}, &delta_y);
    int lines = noctty_grid_sharing_preview_scroll_lines(
        (int)event->direction, delta_y);
    if (lines == 0 ||
        noctty_grid_share_view_scroll(root->event_data, lines) != 0)
        return FALSE;
    gtk_widget_queue_draw(widget);
    return TRUE;
}


static gboolean send_sharing_input(
    NocttyGridContext *root, const uint8_t *bytes, size_t length) {
    if (bytes == NULL || length == 0) return FALSE;
    return noctty_grid_share_view_input(root->event_data, bytes, length) ==
           (int)length;
}


static void set_sharing_transient_feedback(
    NocttyGridContext *root, const char *text, gboolean is_error) {
    GtkWidget *dialog = root->sharing_dialog;
    if (!GTK_IS_DIALOG(dialog) || gtk_widget_in_destruction(dialog)) return;
    GtkWidget *status = g_object_get_data(
        G_OBJECT(dialog), "noctty-sharing-status");
    if (GTK_IS_LABEL(status))
        set_status_label_feedback(status, text, is_error);
    root->sharing_feedback_until_us =
        g_get_monotonic_time() + 3 * G_USEC_PER_SEC;
}

static void on_sharing_clipboard_text(
    GtkClipboard *clipboard, const gchar *text, gpointer user_data) {
    (void)clipboard;
    NocttyGridContext *root = root_grid_context(user_data);
    if (root->sharing_dialog == NULL || text == NULL || text[0] == '\0')
        return;
    const size_t text_length = strlen(text);
    if (noctty_grid_sharing_paste_allowed(text_length) == 0) {
        set_sharing_transient_feedback(
            root,
            "Paste was not sent because it exceeds the 64 KiB sharing limit.",
            TRUE);
        return;
    }
    uint8_t begin[6] = {0};
    uint8_t end[6] = {0};
    int begin_length = noctty_grid_bracketed_paste_marker(
        0, begin, sizeof(begin));
    int end_length = noctty_grid_bracketed_paste_marker(
        1, end, sizeof(end));
    gboolean bracketed =
        noctty_grid_share_view_bracketed_paste(root->event_data) != 0;
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
        size_t count = noctty_grid_sharing_paste_chunk_size(remaining);
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
    NocttyGridContext *root = root_grid_context(user_data);
    gboolean shift = (event->state & GDK_SHIFT_MASK) != 0;
    gboolean control = (event->state & GDK_CONTROL_MASK) != 0;
    gboolean alt = (event->state & GDK_MOD1_MASK) != 0;
    if ((control && shift && event->keyval == GDK_KEY_v) ||
        (shift && event->keyval == GDK_KEY_Insert)) {
        gtk_clipboard_request_text(
            gtk_clipboard_get(GDK_SELECTION_CLIPBOARD),
            on_sharing_clipboard_text,
            root);
        return TRUE;
    }

    const uint8_t *bytes = NULL;
    size_t length = 0;
    uint8_t special[32] = {0};
    guint key = event->keyval;
    int modifier = 1 + (shift ? 1 : 0) + (alt ? 2 : 0) +
                   (control ? 4 : 0);
    gboolean application_cursor =
        noctty_grid_share_view_cursor_mode(root->event_data) != 0;
    int special_kind = -1;
    if (key == GDK_KEY_Return || key == GDK_KEY_KP_Enter) {
        special_kind = 0;
    } else if (key == GDK_KEY_BackSpace) {
        special_kind = 1;
    } else if (key == GDK_KEY_Tab || key == GDK_KEY_ISO_Left_Tab) {
        special_kind = shift ? 3 : 2;
    } else if (key == GDK_KEY_Escape) {
        special_kind = 4;
    } else if (key == GDK_KEY_Up || key == GDK_KEY_Down ||
               key == GDK_KEY_Right || key == GDK_KEY_Left) {
        int arrow = key == GDK_KEY_Up ? 0 : key == GDK_KEY_Down ? 1 :
                    key == GDK_KEY_Right ? 2 : 3;
        int arrow_length = noctty_grid_sharing_arrow_sequence(
            arrow, modifier, application_cursor, special, sizeof(special));
        if (arrow_length > 0) {
            bytes = special;
            length = (size_t)arrow_length;
        }
    }
    if (special_kind >= 0) {
        int special_length = noctty_grid_sharing_key_sequence(
            special_kind, application_cursor, special, sizeof(special));
        if (special_length > 0) {
            bytes = special;
            length = (size_t)special_length;
        }
    } else if (key == GDK_KEY_Home || key == GDK_KEY_End ||
               key == GDK_KEY_Insert || key == GDK_KEY_Delete ||
               key == GDK_KEY_Page_Up || key == GDK_KEY_Page_Down ||
               (key >= GDK_KEY_F1 && key <= GDK_KEY_F12)) {
        int extended_kind = key == GDK_KEY_Home ? 0 :
                            key == GDK_KEY_End ? 1 :
                            key == GDK_KEY_Insert ? 2 :
                            key == GDK_KEY_Delete ? 3 :
                            key == GDK_KEY_Page_Up ? 4 :
                            key == GDK_KEY_Page_Down ? 5 :
                            key <= GDK_KEY_F4 ? 6 + (int)(key - GDK_KEY_F1) :
                            10 + (int)(key - GDK_KEY_F5);
        int extended_length = noctty_grid_sharing_extended_key_sequence(
            extended_kind, modifier, special, sizeof(special));
        if (extended_length > 0) {
            bytes = special;
            length = (size_t)extended_length;
        }
    } else if (event->string != NULL && event->length > 0) {
        int text_length = noctty_grid_sharing_text_sequence(
            alt,
            (const uint8_t *)event->string,
            (size_t)event->length,
            special,
            sizeof(special));
        if (text_length > 0) {
            bytes = special;
            length = (size_t)text_length;
        }
    }
    if (bytes == NULL || length == 0) return FALSE;
    if (send_sharing_input(root, bytes, length)) return TRUE;
    set_sharing_transient_feedback(
        root,
        "Input was not sent. Request control and wait for the host to grant "
        "this pane.",
        TRUE);
    return TRUE;
}

static int refresh_sharing_peers(NocttyGridContext *context) {
    NocttyGridContext *root = root_grid_context(context);
    GtkWidget *dialog = root->sharing_dialog;
    if (dialog == NULL) return 0;
    GtkComboBoxText *combo = GTK_COMBO_BOX_TEXT(g_object_get_data(
        G_OBJECT(dialog), "noctty-sharing-peers"));
    if (combo == NULL) return 0;
    const char *active_id = gtk_combo_box_get_active_id(GTK_COMBO_BOX(combo));
    char *previous_id = active_id != NULL ? g_strdup(active_id) : NULL;
    gtk_combo_box_text_remove_all(combo);
    int count = noctty_grid_share_peer(root->event_data, -1, NULL, 0, NULL, 0,
                                       &(uint16_t){0}, &(int){0});
    int visible_count = 0;
    for (int index = 0; index < count; index++) {
        char alias[129] = {0};
        char endpoint[254] = {0};
        uint16_t port = 0;
        int revoked = 0;
        if (noctty_grid_share_peer(root->event_data, index, alias,
                                   sizeof(alias), endpoint, sizeof(endpoint),
                                   &port, &revoked) < 0)
            continue;
        if (revoked) continue;
        char *label = g_strdup_printf(
            "%s — %s:%u", alias, endpoint, (unsigned)port);
        char index_id[24];
        g_snprintf(index_id, sizeof(index_id), "%d", index);
        gtk_combo_box_text_append(combo, index_id, label);
        g_free(label);
        visible_count++;
    }
    if (previous_id == NULL ||
        !gtk_combo_box_set_active_id(GTK_COMBO_BOX(combo), previous_id)) {
        if (visible_count > 0)
            gtk_combo_box_set_active(GTK_COMBO_BOX(combo), 0);
    }
    g_free(previous_id);
    g_object_set_data(G_OBJECT(dialog), "noctty-sharing-active-peer-count",
                      GINT_TO_POINTER(visible_count));
    return visible_count;
}

static int sharing_selected_peer_index(GtkComboBox *combo) {
    const char *active_id = combo != NULL
        ? gtk_combo_box_get_active_id(combo)
        : NULL;
    return active_id == NULL
        ? -1
        : noctty_grid_sharing_index(
              (const uint8_t *)active_id, strlen(active_id));
}

static void refresh_sharing_streams(NocttyGridContext *context);

static void on_sharing_stream_changed(GtkComboBox *combo, gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    if (GPOINTER_TO_INT(g_object_get_data(
            G_OBJECT(combo), "noctty-sharing-stream-refreshing")) != 0)
        return;
    const char *active_id = gtk_combo_box_get_active_id(combo);
    if (active_id == NULL) return;
    int parsed = noctty_grid_sharing_index(
        (const uint8_t *)active_id, strlen(active_id));
    if (parsed < 0) return;
    if (noctty_grid_share_view_select(root->event_data, parsed) == 0 &&
        root->sharing_dialog != NULL) {
        GtkWidget *preview = g_object_get_data(
            G_OBJECT(root->sharing_dialog), "noctty-sharing-preview");
        if (preview != NULL) gtk_widget_queue_draw(preview);
    }
}

static void on_sharing_tab_changed(GtkComboBox *combo, gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    if (GPOINTER_TO_INT(g_object_get_data(
            G_OBJECT(combo), "noctty-sharing-tab-refreshing")) != 0)
        return;
    int index = gtk_combo_box_get_active(combo);
    if (index < 0) return;
    if (noctty_grid_share_view_select_tab(root->event_data, index) == 0) {
        root->sharing_stream_revision = 0;
        refresh_sharing_streams(root);
        if (root->sharing_dialog != NULL) {
            GtkWidget *preview = g_object_get_data(
                G_OBJECT(root->sharing_dialog), "noctty-sharing-preview");
            if (preview != NULL) gtk_widget_queue_draw(preview);
        }
    }
}

static void refresh_sharing_tabs(NocttyGridContext *context) {
    NocttyGridContext *root = root_grid_context(context);
    GtkWidget *dialog = root->sharing_dialog;
    if (dialog == NULL) return;
    GtkComboBoxText *combo = GTK_COMBO_BOX_TEXT(g_object_get_data(
        G_OBJECT(dialog), "noctty-sharing-tabs"));
    if (combo == NULL) return;
    uint8_t ignored_title = 0;
    int count = noctty_grid_share_view_tab(
        root->event_data, -1, &ignored_title, 0, &(uint64_t){0}, &(int){0},
        &(int){0});
    g_object_set_data(G_OBJECT(combo), "noctty-sharing-tab-refreshing",
                      GINT_TO_POINTER(1));
    gtk_combo_box_text_remove_all(combo);
    int selected = -1;
    for (int index = 0; index < count; index++) {
        uint8_t title[4097] = {0};
        uint64_t tab_id = 0;
        int is_selected = 0;
        int is_active = 0;
        int title_length = noctty_grid_share_view_tab(
            root->event_data, index, title, sizeof(title) - 1u, &tab_id,
            &is_selected, &is_active);
        if (title_length < 0) continue;
        title[(size_t)title_length] = '\0';
        char *label = g_strdup_printf(
            "%s%s%llu%s", title_length == 0 ? "Tab " : (char *)title,
            title_length == 0 ? "" : " — tab ", (unsigned long long)tab_id,
            is_active ? " (host active)" : "");
        gtk_combo_box_text_append_text(combo, label);
        g_free(label);
        if (is_selected) selected = index;
    }
    if (count > 0)
        gtk_combo_box_set_active(GTK_COMBO_BOX(combo),
                                 selected >= 0 ? selected : 0);
    g_object_set_data(G_OBJECT(combo), "noctty-sharing-tab-refreshing",
                      GINT_TO_POINTER(0));
}

static void refresh_sharing_streams(NocttyGridContext *context) {
    NocttyGridContext *root = root_grid_context(context);
    GtkWidget *dialog = root->sharing_dialog;
    if (dialog == NULL) return;
    GtkComboBoxText *combo = GTK_COMBO_BOX_TEXT(g_object_get_data(
        G_OBJECT(dialog), "noctty-sharing-streams"));
    GtkComboBox *tabs = GTK_COMBO_BOX(g_object_get_data(
        G_OBJECT(dialog), "noctty-sharing-tabs"));
    if (combo == NULL || tabs == NULL) return;
    uint64_t revision = noctty_grid_share_view_revision(root->event_data);
    if (revision == root->sharing_stream_revision) return;
    int tab_index = gtk_combo_box_get_active(tabs);
    uint64_t selected_tab_id = 0;
    if (tab_index >= 0) {
        uint8_t ignored_tab_title = 0;
        if (noctty_grid_share_view_tab(
                root->event_data, tab_index, &ignored_tab_title, 0,
                &selected_tab_id, &(int){0}, &(int){0}) < 0)
            selected_tab_id = 0;
    }
    uint8_t ignored_title = 0;
    int count = noctty_grid_share_view_stream(
        root->event_data, -1, &ignored_title, 0, &(uint64_t){0},
        &(uint64_t){0}, &(int){0});
    g_object_set_data(G_OBJECT(combo), "noctty-sharing-stream-refreshing",
                      GINT_TO_POINTER(1));
    gtk_combo_box_text_remove_all(combo);
    char selected_id[24] = {0};
    int visible_count = 0;
    for (int index = 0; index < count; index++) {
        uint8_t title[4097] = {0};
        uint64_t pane_id = 0;
        uint64_t tab_id = 0;
        int is_selected = 0;
        int title_length = noctty_grid_share_view_stream(
            root->event_data, index, title, sizeof(title) - 1u, &pane_id,
            &tab_id, &is_selected);
        if (title_length < 0 || tab_id != selected_tab_id) continue;
        title[(size_t)title_length] = '\0';
        char *label = g_strdup_printf(
            "%s%s%llu", title_length == 0 ? "Pane " : (char *)title,
            title_length == 0 ? "" : " — pane ",
            (unsigned long long)pane_id);
        char index_id[24];
        g_snprintf(index_id, sizeof(index_id), "%d", index);
        gtk_combo_box_text_append(combo, index_id, label);
        g_free(label);
        visible_count++;
        if (is_selected)
            g_strlcpy(selected_id, index_id, sizeof(selected_id));
    }
    if (selected_id[0] != '\0')
        gtk_combo_box_set_active_id(GTK_COMBO_BOX(combo), selected_id);
    else if (visible_count > 0)
        gtk_combo_box_set_active(GTK_COMBO_BOX(combo), 0);
    g_object_set_data(G_OBJECT(combo), "noctty-sharing-stream-refreshing",
                      GINT_TO_POINTER(0));
    root->sharing_stream_revision = revision;
}

static gboolean refresh_sharing_status(gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    GtkWidget *dialog = root->sharing_dialog;
    if (!GTK_IS_DIALOG(dialog) || gtk_widget_in_destruction(dialog)) {
        root->sharing_status_source = 0;
        return G_SOURCE_REMOVE;
    }
    GtkWidget *status_label = g_object_get_data(
        G_OBJECT(dialog), "noctty-sharing-status");
    GtkWidget *pair_listen = g_object_get_data(
        G_OBJECT(dialog), "noctty-sharing-pair-listen");
    GtkWidget *pair_connect = g_object_get_data(
        G_OBJECT(dialog), "noctty-sharing-pair-connect");
    GtkWidget *discover = g_object_get_data(
        G_OBJECT(dialog), "noctty-sharing-discover");
    GtkWidget *confirm = g_object_get_data(
        G_OBJECT(dialog), "noctty-sharing-confirm");
    GtkWidget *cancel_pairing = g_object_get_data(
        G_OBJECT(dialog), "noctty-sharing-cancel-pairing");
    GtkWidget *stop = g_object_get_data(
        G_OBJECT(dialog), "noctty-sharing-stop");
    GtkWidget *grant = g_object_get_data(
        G_OBJECT(dialog), "noctty-sharing-grant");
    GtkWidget *revoke = g_object_get_data(
        G_OBJECT(dialog), "noctty-sharing-revoke");
    GtkWidget *stop_receive = g_object_get_data(
        G_OBJECT(dialog), "noctty-sharing-stop-receive");
    GtkWidget *request_control = g_object_get_data(
        G_OBJECT(dialog), "noctty-sharing-request-control");
    GtkWidget *reconnect = g_object_get_data(
        G_OBJECT(dialog), "noctty-sharing-reconnect");
    GtkWidget *share_pane = g_object_get_data(
        G_OBJECT(dialog), "noctty-sharing-share-pane");
    GtkWidget *share_tab = g_object_get_data(
        G_OBJECT(dialog), "noctty-sharing-share-tab");
    GtkWidget *share_session = g_object_get_data(
        G_OBJECT(dialog), "noctty-sharing-share-session");
    GtkWidget *revoke_device = g_object_get_data(
        G_OBJECT(dialog), "noctty-sharing-revoke-device");
    GtkWidget *receive = g_object_get_data(
        G_OBJECT(dialog), "noctty-sharing-receive");
    GtkWidget *retry_save = g_object_get_data(
        G_OBJECT(dialog), "noctty-sharing-retry-save");
    GtkWidget *peers = g_object_get_data(
        G_OBJECT(dialog), "noctty-sharing-peers");
    GtkWidget *preview = g_object_get_data(
        G_OBJECT(dialog), "noctty-sharing-preview");
    GtkEntry *alias_entry = GTK_ENTRY(g_object_get_data(
        G_OBJECT(dialog), "noctty-sharing-alias"));
    GtkEntry *endpoint_entry = GTK_ENTRY(g_object_get_data(
        G_OBJECT(dialog), "noctty-sharing-endpoint"));
    GtkSpinButton *port_spin = GTK_SPIN_BUTTON(g_object_get_data(
        G_OBJECT(dialog), "noctty-sharing-port"));
    uint32_t sas = 0;
    uint16_t port = 0;
    int status = noctty_grid_share_status(root->event_data, &sas, &port);
    char text[256];
    if (status == 101)
        g_snprintf(text, sizeof(text), "Pairing connection in progress…");
    else if (status == 102)
        g_snprintf(text, sizeof(text),
                   "Compare on both devices: %06u. Confirm only if identical.",
                   (unsigned)sas);
    else if (status == 104)
        g_snprintf(text, sizeof(text), "Pairing rejected.");
    else if (status == 105)
        g_snprintf(text, sizeof(text), "Pairing failed.");
    else if (status == 106)
        g_snprintf(
            text, sizeof(text),
            "Paired-device changes are active for this run but could not be "
            "saved. Check configuration-directory permissions and retry.");
    else if (status == 107)
        g_snprintf(
            text, sizeof(text),
            "The paired-device store is full. Revoke an unused device before "
            "pairing a new one.");
    else if (status == 201)
        g_snprintf(text, sizeof(text),
                   "Sharing listener ready on TCP port %u.", (unsigned)port);
    else if (status == 202)
        g_snprintf(text, sizeof(text),
                   "Paired viewer connected. View-only.");
    else if (status == 203)
        g_snprintf(text, sizeof(text),
                   "Viewer requests control. Grant only if expected.");
    else if (status == 204)
        g_snprintf(text, sizeof(text),
                   "Remote control granted for this share only.");
    else if (status == 205)
        g_snprintf(text, sizeof(text),
                   "Sharing stopped. Close the sharing session to reset.");
    else if (status == 206)
        g_snprintf(text, sizeof(text),
                   "Sharing failed. Close the sharing session to reset.");
    else if (status < 0)
        g_snprintf(text, sizeof(text),
                   "Sharing state synchronization failed. Close and reopen NOCTTY.");
    else if (status == 301)
        g_snprintf(text, sizeof(text), "Connecting to paired terminal…");
    else if (status == 302)
        g_snprintf(text, sizeof(text), "Receiving paired terminal. View-only.");
    else if (status == 303)
        g_snprintf(text, sizeof(text), "Control requested. Waiting for host approval.");
    else if (status == 304)
        g_snprintf(text, sizeof(text), "Remote control granted for this connection.");
    else if (status == 305)
        g_snprintf(text, sizeof(text),
                   "Remote terminal closed. Close this remote session or reconnect.");
    else if (status == 306)
        g_snprintf(text, sizeof(text),
                   "Remote terminal connection failed. Close this remote session or reconnect.");
    else if (status == 400)
        g_snprintf(text, sizeof(text), "Discovering pairing listeners on this LAN…");
    else if (status == 401) {
        char alias[129] = {0};
        char endpoint[254] = {0};
        uint16_t discovered_port = 0;
        if (noctty_grid_share_discovered(
                root->event_data, alias, sizeof(alias), endpoint,
                sizeof(endpoint), &discovered_port) > 0) {
            gtk_entry_set_text(alias_entry, alias);
            gtk_entry_set_text(endpoint_entry, endpoint);
            gtk_spin_button_set_value(port_spin, discovered_port);
            g_snprintf(
                text, sizeof(text),
                "Untrusted LAN hint: %s at %s:%u. Review it, connect, and trust "
                "only after the six-digit code matches.",
                alias, endpoint, (unsigned)discovered_port);
        } else
            g_snprintf(text, sizeof(text), "LAN listener discovery completed.");
    } else
        g_snprintf(text, sizeof(text),
                   "Idle. Pair a device or share with a paired device.");
    if (g_get_monotonic_time() >= root->sharing_feedback_until_us)
        set_status_label_feedback(
            status_label, text,
            status == 104 || status == 105 || status == 106 ||
                status == 107 || status == 206 || status == 306 ||
                status < 0);
    int known_count = GPOINTER_TO_INT(g_object_get_data(
        G_OBJECT(dialog), "noctty-sharing-peer-count"));
    int current_count = noctty_grid_share_peer(root->event_data, -1, NULL, 0,
                                               NULL, 0, &(uint16_t){0},
                                               &(int){0});
    gboolean pairing_finished =
        root->sharing_last_status >= 101 &&
        root->sharing_last_status <= 105 &&
        (status == 0 || status == 106 || status == 107);
    if (current_count != known_count || pairing_finished) {
        refresh_sharing_peers(root);
        g_object_set_data(G_OBJECT(dialog), "noctty-sharing-peer-count",
                          GINT_TO_POINTER(current_count));
    }
    int active_peer_count = GPOINTER_TO_INT(g_object_get_data(
        G_OBJECT(dialog), "noctty-sharing-active-peer-count"));
    uint32_t sharing_actions =
        noctty_grid_sharing_status_actions(status);
    gboolean pair_ready =
        (sharing_actions & NOCTTY_GRID_SHARING_ALLOW_PAIRING) != 0;
    gboolean session_ready =
        (sharing_actions & NOCTTY_GRID_SHARING_ALLOW_SESSION) != 0 &&
        active_peer_count > 0;
    gtk_widget_set_sensitive(confirm, status == 102);
    gtk_widget_set_sensitive(pair_listen, pair_ready);
    gtk_widget_set_sensitive(pair_connect, pair_ready);
    gtk_widget_set_sensitive(discover, status == 0 || status == 401);
    gtk_widget_set_sensitive(share_pane, session_ready);
    gtk_widget_set_sensitive(share_tab, session_ready);
    gtk_widget_set_sensitive(share_session, session_ready);
    gtk_widget_set_sensitive(receive, session_ready);
    gtk_widget_set_sensitive(peers, active_peer_count > 0);
    gtk_widget_set_sensitive(revoke_device, active_peer_count > 0);
    gtk_widget_set_sensitive(
        stop, (sharing_actions & NOCTTY_GRID_SHARING_CLEAR_HOST) != 0);
    gtk_widget_set_sensitive(cancel_pairing,
                             status == 101 || status == 102 || status == 104 ||
                                 status == 105 || status == 400);
    gtk_widget_set_sensitive(grant, status == 203);
    gtk_widget_set_sensitive(revoke, status == 203 || status == 204);
    gtk_widget_set_sensitive(
        stop_receive,
        (sharing_actions & NOCTTY_GRID_SHARING_CLEAR_VIEWER) != 0);
    gtk_widget_set_sensitive(request_control, status == 302);
    gtk_widget_set_sensitive(reconnect, status == 305 || status == 306);
    gtk_widget_set_sensitive(retry_save, status == 106);
    gtk_button_set_label(
        GTK_BUTTON(stop),
        status == 205 || status == 206
            ? "Close sharing session"
            : "Stop sharing");
    gtk_button_set_label(
        GTK_BUTTON(stop_receive),
        status == 305 || status == 306
            ? "Close remote session"
            : "Stop receiving");
    gtk_button_set_label(
        GTK_BUTTON(revoke), status == 203 ? "Deny control" : "Revoke control");
    gtk_button_set_label(
        GTK_BUTTON(cancel_pairing),
        status == 104 || status == 105 ? "Clear pairing result" : "Cancel pairing");
    if (GTK_IS_WIDGET(preview) && !gtk_widget_in_destruction(preview))
        gtk_widget_queue_draw(preview);
    refresh_sharing_tabs(root);
    refresh_sharing_streams(root);
    root->sharing_last_status = status;
    return G_SOURCE_CONTINUE;
}

static void on_sharing_action(GtkButton *button, gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    GtkWidget *dialog = root->sharing_dialog;
    if (dialog == NULL) return;
    int action = GPOINTER_TO_INT(g_object_get_data(
        G_OBJECT(button), "noctty-sharing-action"));
    GtkComboBox *peers = GTK_COMBO_BOX(g_object_get_data(
        G_OBJECT(dialog), "noctty-sharing-peers"));
    GtkEntry *alias_entry = GTK_ENTRY(g_object_get_data(
        G_OBJECT(dialog), "noctty-sharing-alias"));
    GtkEntry *endpoint_entry = GTK_ENTRY(g_object_get_data(
        G_OBJECT(dialog), "noctty-sharing-endpoint"));
    GtkSpinButton *port_spin = GTK_SPIN_BUTTON(g_object_get_data(
        G_OBJECT(dialog), "noctty-sharing-port"));
    const char *alias = gtk_entry_get_text(alias_entry);
    const char *endpoint = gtk_entry_get_text(endpoint_entry);
    uint16_t port = (uint16_t)gtk_spin_button_get_value_as_int(port_spin);
    int peer_index = sharing_selected_peer_index(peers);
    if (action == 9 && peer_index >= 0) {
        gchar *peer_label = gtk_combo_box_text_get_active_text(
            GTK_COMBO_BOX_TEXT(peers));
        GtkWidget *confirmation = gtk_message_dialog_new(
            GTK_WINDOW(dialog),
            GTK_DIALOG_MODAL | GTK_DIALOG_DESTROY_WITH_PARENT,
            GTK_MESSAGE_WARNING, GTK_BUTTONS_NONE,
            "Revoke this paired device?");
        gtk_message_dialog_format_secondary_text(
            GTK_MESSAGE_DIALOG(confirmation),
            "%s will lose sharing access immediately. Pairing it again will "
            "require a new matching six-digit confirmation.",
            peer_label != NULL ? peer_label : "The selected device");
        gtk_dialog_add_buttons(
            GTK_DIALOG(confirmation),
            "Keep Device", GTK_RESPONSE_CANCEL,
            "Revoke Device", GTK_RESPONSE_ACCEPT, NULL);
        gtk_dialog_set_default_response(
            GTK_DIALOG(confirmation), GTK_RESPONSE_CANCEL);
        (void)configure_overlay_window_stacking(
            root, confirmation, "noctty-share-revoke-confirmation");
        show_all_with_action_affordances(confirmation);
        gint response = run_grid_modal_dialog(
            root, GTK_DIALOG(confirmation));
        gtk_widget_destroy(confirmation);
        g_free(peer_label);
        if (response != GTK_RESPONSE_ACCEPT) return;
    }
    int result = noctty_grid_share_action(
            root->event_data, action, peer_index, alias, strlen(alias),
            endpoint, strlen(endpoint), port);
    if (action == 9) {
        refresh_sharing_peers(root);
        int current_count = noctty_grid_share_peer(
            root->event_data, -1, NULL, 0, NULL, 0,
            &(uint16_t){0}, &(int){0});
        g_object_set_data(G_OBJECT(dialog), "noctty-sharing-peer-count",
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
        GtkWidget *preview = g_object_get_data(
            G_OBJECT(dialog), "noctty-sharing-preview");
        gtk_widget_grab_focus(preview);
    }
    (void)refresh_sharing_status(root);
}

static void on_sharing_dialog_destroy(GtkWidget *dialog, gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    remove_grid_source(&root->sharing_status_source);
    // There is no separate persistent sharing indicator, so closing this
    // surface is the unambiguous fail-closed stop for every network role.
    // Keep host/viewer teardown idempotent: only the active action succeeds.
    (void)noctty_grid_share_action(root->event_data, 6, -1, "", 0, "", 0, 0);
    (void)noctty_grid_share_action(root->event_data, 11, -1, "", 0, "", 0, 0);
    (void)noctty_grid_share_action(root->event_data, 4, -1, "", 0, "", 0, 0);
    (void)noctty_grid_share_action(root->event_data, 14, -1, "", 0, "", 0, 0);
    root->sharing_stream_revision = 0;
    root->sharing_feedback_until_us = 0;
    root->sharing_last_status = 0;
    if (root->sharing_dialog == dialog) root->sharing_dialog = NULL;
}

static void show_session_sharing_dialog(NocttyGridContext *context) {
    NocttyGridContext *root = root_grid_context(context);
    if (root->sharing_dialog != NULL) {
        present_configured_window(root->sharing_dialog);
        return;
    }
    GtkWidget *dialog = gtk_dialog_new_with_buttons(
        "Session Sharing", GTK_WINDOW(root->window),
        GTK_DIALOG_DESTROY_WITH_PARENT, "_Close", GTK_RESPONSE_CLOSE, NULL);
    root->sharing_dialog = dialog;
    GdkRectangle workarea = {0, 0, 900, 700};
    GdkMonitor *monitor = grid_monitor_for_window(root->window);
    if (monitor != NULL) gdk_monitor_get_workarea(monitor, &workarea);
    int width =
        noctty_grid_dialog_dimension(workarea.width, 920, 480, 64);
    int height =
        noctty_grid_dialog_dimension(workarea.height, 760, 480, 64);
    width = noctty_grid_dialog_dimension(workarea.width, width, 1, 32);
    height = noctty_grid_dialog_dimension(workarea.height, height, 1, 32);
    configure_overlay_window_geometry(
        root, dialog, &workarea, width, height);
    gtk_window_set_default_size(GTK_WINDOW(dialog), width, height);
    gtk_window_set_resizable(GTK_WINDOW(dialog), TRUE);
    const NocttySharingCallbacks callbacks = {
        .action = G_CALLBACK(on_sharing_action),
        .tab_changed = G_CALLBACK(on_sharing_tab_changed),
        .stream_changed = G_CALLBACK(on_sharing_stream_changed),
        .preview_draw = G_CALLBACK(draw_sharing_preview),
        .preview_button = G_CALLBACK(on_sharing_preview_button),
        .preview_key = G_CALLBACK(on_sharing_preview_key),
        .preview_scroll = G_CALLBACK(on_sharing_preview_scroll),
    };
    if (!noctty_sharing_contents_new(
            dialog, width, height, root, &callbacks)) {
        root->sharing_dialog = NULL;
        gtk_widget_destroy(dialog);
        return;
    }
    root->sharing_dialog_scrollable = TRUE;
    root->sharing_dialog_grouped_actions = TRUE;

    g_signal_connect_swapped(dialog, "response",
                             G_CALLBACK(gtk_widget_destroy), dialog);
    g_signal_connect(dialog, "destroy",
                     G_CALLBACK(on_sharing_dialog_destroy), root);
    refresh_sharing_peers(root);
    g_object_set_data(G_OBJECT(dialog), "noctty-sharing-peer-count",
                      GINT_TO_POINTER(noctty_grid_share_peer(
                          root->event_data, -1, NULL, 0, NULL, 0,
                          &(uint16_t){0}, &(int){0})));
    (void)refresh_sharing_status(root);
    if (root->sharing_status_source == 0)
        root->sharing_status_source =
            g_timeout_add(200, refresh_sharing_status, root);
    gtk_widget_show_all(dialog);
}

static void on_session_sharing_menu_activate(GtkMenuItem *item,
                                             gpointer user_data) {
    (void)item;
    show_session_sharing_dialog(user_data);
}
#if NOCTTY_ENABLE_SMOKE
#include "../../tests/native_grid_sharing_scope_smoke.inc"
#endif

static gboolean request_window_close_button_smoke(gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    if (root->window_close_button != NULL)
        gtk_button_clicked(GTK_BUTTON(root->window_close_button));
    return G_SOURCE_REMOVE;
}

static void mark_workspace_menu_action(GtkWidget *item) {
    GtkWidget *menu = gtk_widget_get_ancestor(item, GTK_TYPE_MENU);
    while (GTK_IS_MENU(menu)) {
        g_object_set_data(G_OBJECT(menu), "noctty-workspace-action",
                          GINT_TO_POINTER(1));
        GtkWidget *attach = gtk_menu_get_attach_widget(GTK_MENU(menu));
        menu = attach != NULL
            ? gtk_widget_get_ancestor(attach, GTK_TYPE_MENU) : NULL;
    }
}

static void on_workspace_menu_activate(GtkWidget *item, gpointer user_data) {
    NocttyGridContext *context = user_data;
    mark_workspace_menu_action(item);
    int event_code = GPOINTER_TO_INT(g_object_get_data(G_OBJECT(item), "noctty-workspace-event"));
    emit_grid_workspace_event(context, event_code);
}


static void on_broadcast_menu_activate(GtkWidget *item, gpointer user_data) {
    (void)item;
    NocttyGridContext *context = user_data;
    NocttyGridContext *root = root_grid_context(context);
    gboolean enabled = root->event_data != NULL &&
        noctty_grid_broadcast_enabled(root->event_data) != 0;
    if (enabled) {
        emit_grid_workspace_event(context, 23);
        show_status_feedback(context, "Broadcast mode disabled.");
        root->broadcast_disable_feedback = 1;
        if (root->workspace_smoke == 1)
            root->broadcast_disable_immediate =
                noctty_grid_broadcast_enabled(root->event_data) == 0;
        return;
    }

    GtkWidget *dialog = gtk_message_dialog_new(
        GTK_WINDOW(context->window),
        GTK_DIALOG_MODAL | GTK_DIALOG_DESTROY_WITH_PARENT,
        GTK_MESSAGE_WARNING, GTK_BUTTONS_NONE,
        "Enable broadcast input?");
    gtk_message_dialog_format_secondary_text(
        GTK_MESSAGE_DIALOG(dialog),
        "Each keystroke will be sent to every selected terminal, or every "
        "terminal in this tab when none are selected. Review the targets "
        "before continuing.");
    gtk_dialog_add_buttons(GTK_DIALOG(dialog),
                           "Keep Off", GTK_RESPONSE_CANCEL,
                           "Enable Broadcast", GTK_RESPONSE_ACCEPT, NULL);
    gtk_dialog_set_default_response(GTK_DIALOG(dialog), GTK_RESPONSE_CANCEL);
    prepare_action_button_tree(dialog);
    if (root->workspace_smoke == 1) {
        GtkWidget *cancel = gtk_dialog_get_widget_for_response(
            GTK_DIALOG(dialog), GTK_RESPONSE_CANCEL);
        GtkWidget *accept = gtk_dialog_get_widget_for_response(
            GTK_DIALOG(dialog), GTK_RESPONSE_ACCEPT);
        root->broadcast_confirmation_explicit =
            GTK_IS_BUTTON(cancel) && GTK_IS_BUTTON(accept) &&
            g_strcmp0(gtk_button_get_label(GTK_BUTTON(cancel)),
                      "Keep Off") == 0 &&
            g_strcmp0(gtk_button_get_label(GTK_BUTTON(accept)),
                      "Enable Broadcast") == 0;
        root->broadcast_confirmation_cancel_default =
            gtk_window_get_default_widget(GTK_WINDOW(dialog)) == cancel;
        g_idle_add(accept_dialog_smoke, dialog);
    }
    if (run_grid_modal_dialog(context, GTK_DIALOG(dialog)) ==
        GTK_RESPONSE_ACCEPT)
        emit_grid_workspace_event(context, 23);
    gtk_widget_destroy(dialog);
}

static void on_pane_close_menu_activate(GtkWidget *item, gpointer user_data) {
    NocttyGridContext *context = user_data;
    NocttyGridContext *root = root_grid_context(context);
    mark_workspace_menu_action(item);
    GtkWidget *menu = gtk_widget_get_ancestor(item, GTK_TYPE_MENU);
    if (GTK_IS_MENU(menu)) {
        gtk_menu_popdown(GTK_MENU(menu));
        root->pane_close_menu_popped_down = 1;
    }
    (void)close_grid_pane(context);
}

static void on_terminal_menu_activate(GtkMenuItem *item,
                                      gpointer user_data) {
    NocttyGridContext *context = user_data;
    int action = GPOINTER_TO_INT(g_object_get_data(
        G_OBJECT(item), "noctty-terminal-action"));
    switch (action) {
    case 1:
        copy_grid_selection_to_clipboard(context);
        break;
    case 2:
        request_grid_clipboard_text(context);
        break;
    case 3:
        context->selecting = 1;
        context->selection_dragging = 0;
        context->selection_start_column = 0;
        context->selection_start_row = 0;
        context->selection_end_column = MAX(0, context->columns - 1);
        context->selection_end_row = MAX(0, context->rows - 1);
        gtk_widget_queue_draw(context->area);
        break;
    case 4:
        clear_grid_selection(context);
        break;
    case 5:
        clear_grid_screen(context);
        break;
    case 6:
        clear_grid_scrollback(context);
        break;
    case 7:
        reset_grid_terminal(context);
        break;
    default:
        break;
    }
}


static int populate_tag_suggestions(NocttyGridContext *context,
                                    GtkComboBoxText *combo) {
    NocttyGridContext *root = root_grid_context(context);
    char buffer[1024] = {0};
    int length = root->event_data != NULL
        ? noctty_grid_known_tags(root->event_data, buffer, sizeof(buffer) - 1)
        : 0;
    if (length <= 0) return 0;
    if ((size_t)length >= sizeof(buffer)) length = (int)sizeof(buffer) - 1;
    buffer[length] = '\0';
    gchar **tags = g_strsplit(buffer, "\n", -1);
    int count = 0;
    for (gchar **tag = tags; tag != NULL && *tag != NULL; tag++) {
        if ((*tag)[0] == '\0') continue;
        gtk_combo_box_text_append_text(combo, *tag);
        count++;
    }
    g_strfreev(tags);
    return count;
}

static gchar *run_tag_entry_dialog(NocttyGridContext *context, const gchar *title,
                                   const gchar *value, gboolean allow_empty) {
    GtkWidget *dialog = gtk_dialog_new_with_buttons(
        title, GTK_WINDOW(root_grid_context(context)->window),
        GTK_DIALOG_MODAL, "Cancel", GTK_RESPONSE_CANCEL,
        "Apply", GTK_RESPONSE_OK, NULL);
    GtkWidget *content = gtk_dialog_get_content_area(GTK_DIALOG(dialog));
    GtkWidget *combo = gtk_combo_box_text_new_with_entry();
    GtkWidget *entry = gtk_bin_get_child(GTK_BIN(combo));
    gtk_entry_set_placeholder_text(GTK_ENTRY(entry), "e.g. backend, tests, review");
    set_widget_accessible_name(entry, "Workspace tag");
    if (value != NULL) gtk_entry_set_text(GTK_ENTRY(entry), value);
    int suggestion_count = populate_tag_suggestions(context, GTK_COMBO_BOX_TEXT(combo));
    gtk_box_pack_start(GTK_BOX(content), combo, FALSE, FALSE, 12);
    if (suggestion_count > 0) {
        GtkWidget *hint = gtk_label_new("Choose an existing tag or type a new one");
        gtk_widget_set_halign(hint, GTK_ALIGN_START);
        gtk_widget_set_opacity(hint, 0.72);
        gtk_box_pack_start(GTK_BOX(content), hint, FALSE, FALSE, 0);
    }
    (void)configure_overlay_window_stacking(
        context, dialog, "noctty-tag-dialog");
    show_all_with_action_affordances(dialog);
    gchar *result = NULL;
    if (run_grid_modal_dialog(context, GTK_DIALOG(dialog)) ==
        GTK_RESPONSE_OK) {
        const gchar *text = gtk_entry_get_text(GTK_ENTRY(entry));
        if (text != NULL) {
            gchar *trimmed = g_strdup(text);
            g_strstrip(trimmed);
            if (allow_empty || trimmed[0] != '\0')
                result = trimmed;
            else
                g_free(trimmed);
        }
    }
    gtk_widget_destroy(dialog);
    return result;
}

static void on_tag_selected_menu_activate(GtkMenuItem *item, gpointer user_data) {
    (void)item;
    NocttyGridContext *root = root_grid_context(user_data);
    gchar *tag = run_tag_entry_dialog(root, "Tag selected panes", NULL, FALSE);
    if (tag != NULL) {
        if (noctty_grid_tag_selected_panes(root->event_data, tag, strlen(tag)) == 0) {
            apply_smart_filter(root);
            refresh_tag_tooltips(root);
        }
        g_free(tag);
    }
}

static void on_tag_remove_menu_activate(GtkMenuItem *item, gpointer user_data) {
    (void)item;
    NocttyGridContext *root = root_grid_context(user_data);
    gchar *tag = run_tag_entry_dialog(root, "Remove tag from selected panes", NULL, FALSE);
    if (tag != NULL) {
        (void)noctty_grid_remove_tag_from_selected_panes(root->event_data,
                                                         tag, strlen(tag));
        apply_smart_filter(root);
        refresh_tag_tooltips(root);
        g_free(tag);
    }
}

static void on_smart_filter_button_clicked(GtkButton *button, gpointer user_data) {
    (void)button;
    NocttyGridContext *root = root_grid_context(user_data);
    gchar *tag = run_tag_entry_dialog(root, "Smart tab filter (blank clears)",
                                      root->smart_filter_tag, TRUE);
    if (tag != NULL) {
        if (noctty_grid_set_smart_filter(root->event_data, tag, strlen(tag)) == 0) {
            g_free(root->smart_filter_tag);
            root->smart_filter_tag = tag[0] == '\0' ? NULL : g_strdup(tag);
        }
        g_free(tag);
    }
    apply_smart_filter(root);
}

static void on_smart_filter_menu_activate(GtkMenuItem *item, gpointer user_data) {
    (void)item;
    on_smart_filter_button_clicked(NULL, user_data);
}

static void on_command_palette_menu_activate(GtkWidget *item,
                                             gpointer user_data) {
    NocttyGridContext *context = user_data;
    GtkWidget *menu = gtk_widget_get_ancestor(item, GTK_TYPE_MENU);
    if (!GTK_IS_MENU(menu)) return;
    mark_workspace_menu_action(item);
    NocttyGridContext *root = root_grid_context(context);
    if (root->workspace_menu != NULL)
        g_object_set_data(G_OBJECT(root->workspace_menu),
                          "noctty-open-command-palette", context);
}

static void on_compact_menu_activate(GtkWidget *item, gpointer user_data) {
    NocttyGridContext *context = user_data;
    int action = GPOINTER_TO_INT(g_object_get_data(G_OBJECT(item),
                                                   "noctty-compact-action"));
    execute_palette_action(context, action);
}


static void on_profile_preset_toggled(GtkCheckMenuItem *item,
                                      gpointer user_data) {
    if (!gtk_check_menu_item_get_active(item)) return;
    NocttyGridContext *context = user_data;
    NocttyGridContext *root = root_grid_context(context);
    int preset = GPOINTER_TO_INT(g_object_get_data(
        G_OBJECT(item), "noctty-profile-preset"));
    if (preset < 0 || preset > 4 || context->event == NULL) return;
    context->event(context->event_data, context->pane_id, 106, preset,
                   (uint64_t)(g_get_monotonic_time() / 1000));
    context->profile_menu_active = 0;
    root->profile_menu_selected++;
    (void)sync_grid_context_profile(context);
}

static GtkWidget *create_profile_preset_menu(NocttyGridContext *context) {
    NocttyGridContext *root = root_grid_context(context);
    if (context->event != NULL) {
        context->event(context->event_data, context->pane_id, 105, 0,
                       (uint64_t)(g_get_monotonic_time() / 1000));
        context->profile_menu_active = 1;
    }
    (void)sync_grid_context_profile(context);
    GtkWidget *menu = gtk_menu_new();
    GSList *group = NULL;
    for (int preset = 0; preset < 5; preset++) {
        GtkWidget *item = gtk_radio_menu_item_new_with_label(
            group, noctty_grid_profile_preset_label(preset));
        group = gtk_radio_menu_item_get_group(GTK_RADIO_MENU_ITEM(item));
        g_object_set_data(G_OBJECT(item), "noctty-profile-preset",
                          GINT_TO_POINTER(preset));
        gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(item),
                                       context->profile_preset == preset);
        g_signal_connect(item, "toggled",
                         G_CALLBACK(on_profile_preset_toggled), context);
        gtk_menu_shell_append(GTK_MENU_SHELL(menu), item);
    }
    root->profile_menu_opened++;
    return menu;
}

static void on_workspace_menu_destroy(GtkWidget *menu, gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    gboolean action_activated = GPOINTER_TO_INT(g_object_get_data(
        G_OBJECT(menu), "noctty-workspace-action")) != 0;
    NocttyGridContext *profile_context = g_object_get_data(
        G_OBJECT(menu), "noctty-profile-context");
    NocttyGridContext *palette_context = g_object_get_data(
        G_OBJECT(menu), "noctty-open-command-palette");
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
        g_source_remove(root->focus_hide_source);
    if (action_activated) {
        root->focus_hide_source = 0;
        NocttyGridContext *active = active_grid_context(root);
        if (active != NULL && active->area != NULL)
            gtk_widget_grab_focus(active->area);
        if (palette_registered &&
            grid_context_session_available(palette_context))
            open_command_palette(palette_context);
        return;
    }
    root->focus_hide_source = g_timeout_add(120, deferred_focus_hide, root);
}

static void dismiss_workspace_menu(NocttyGridContext *context) {
    NocttyGridContext *root = root_grid_context(context);
    GtkWidget *menu = root->workspace_menu;
    if (menu == NULL) return;
    g_object_ref(menu);
    if (GTK_IS_MENU(menu) && gtk_widget_get_mapped(menu))
        gtk_menu_popdown(GTK_MENU(menu));
    if (!gtk_widget_in_destruction(menu)) gtk_widget_destroy(menu);
    g_object_unref(menu);
}

static void dismiss_grid_popup_windows(NocttyGridContext *context) {
    NocttyGridContext *root = root_grid_context(context);
    dismiss_workspace_menu(root);
    GtkWidget *grab = gtk_grab_get_current();
    if (grab != NULL && GTK_IS_MENU(grab))
        gtk_menu_popdown(GTK_MENU(grab));
    GList *windows = gtk_window_list_toplevels();
    for (GList *item = windows; item != NULL; item = item->next) {
        GtkWidget *window = item->data;
        if (!GTK_IS_WINDOW(window) || window == root->window ||
            gtk_window_get_window_type(GTK_WINDOW(window)) !=
                GTK_WINDOW_POPUP ||
            !gtk_widget_get_visible(window))
            continue;
        gtk_widget_hide(window);
    }
    g_list_free(windows);
}

static void on_tab_close_menu_activate(GtkWidget *item, gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    GtkWidget *page = g_object_get_data(G_OBJECT(item), "noctty-tab-page");
    (void)close_grid_tab(root, page);
}

static gboolean adjust_tab_color_for_page(NocttyGridContext *context,
                                          GtkWidget *page, int delta) {
    NocttyGridContext *root = root_grid_context(context);
    NocttyGridContext *representative = grid_context_for_page(root, page);
    if (representative == NULL || root->event_data == NULL || delta == 0)
        return FALSE;
    if (noctty_grid_adjust_tab_color(root->event_data,
                                     representative->pane_id,
                                     delta) != 0)
        return FALSE;
    update_compact_tab(representative);
    if (delta > 0) root->tab_color_shortcut_lighten = 1;
    else root->tab_color_shortcut_darken = 1;
    return TRUE;
}

static gboolean adjust_active_tab_color(NocttyGridContext *context,
                                        int delta) {
    NocttyGridContext *root = root_grid_context(context);
    gint page_index = gtk_notebook_get_current_page(
        GTK_NOTEBOOK(root->notebook));
    GtkWidget *page = gtk_notebook_get_nth_page(
        GTK_NOTEBOOK(root->notebook), page_index);
    return page != NULL && adjust_tab_color_for_page(root, page, delta);
}

static void on_tab_color_preset_toggled(GtkCheckMenuItem *item,
                                        gpointer user_data) {
    if (!gtk_check_menu_item_get_active(item)) return;
    NocttyGridContext *root = root_grid_context(user_data);
    GtkWidget *page = g_object_get_data(G_OBJECT(item), "noctty-tab-page");
    NocttyGridContext *representative = grid_context_for_page(root, page);
    int preset = GPOINTER_TO_INT(g_object_get_data(
        G_OBJECT(item), "noctty-tab-color-preset"));
    if (representative == NULL || root->event_data == NULL) return;
    if (noctty_grid_set_tab_color(root->event_data,
                                  representative->pane_id,
                                  preset) == 0) {
        root->tab_color_preset_applied = 1;
        update_compact_tab(representative);
    }
}

static void on_tab_color_adjust_activate(GtkMenuItem *item,
                                         gpointer user_data) {
    GtkWidget *page = g_object_get_data(G_OBJECT(item), "noctty-tab-page");
    int delta = GPOINTER_TO_INT(g_object_get_data(
        G_OBJECT(item), "noctty-tab-color-delta"));
    (void)adjust_tab_color_for_page(user_data, page, delta);
}

static GtkWidget *create_tab_color_menu(NocttyGridContext *context,
                                        GtkWidget *page) {
    NocttyGridContext *root = root_grid_context(context);
    NocttyGridContext *representative = grid_context_for_page(root, page);
    int current_preset = -1;
    int current_shade = 0;
    if (representative != NULL && root->event_data != NULL)
        (void)noctty_grid_tab_color(root->event_data,
                                    representative->pane_id,
                                    &current_preset, &current_shade);
    GtkWidget *menu = gtk_menu_new();
    GSList *group = NULL;
    for (int preset = -1; preset < 8; preset++) {
        GtkWidget *item = gtk_radio_menu_item_new_with_label(
            group, noctty_grid_tab_color_preset_name(preset));
        group = gtk_radio_menu_item_get_group(GTK_RADIO_MENU_ITEM(item));
        g_object_set_data(G_OBJECT(item), "noctty-tab-page", page);
        g_object_set_data(G_OBJECT(item), "noctty-tab-color-preset",
                          GINT_TO_POINTER(preset));
        gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(item),
                                       preset == current_preset);
        g_signal_connect(item, "toggled",
                         G_CALLBACK(on_tab_color_preset_toggled), root);
        gtk_menu_shell_append(GTK_MENU_SHELL(menu), item);
        if (preset == -1)
            gtk_menu_shell_append(GTK_MENU_SHELL(menu),
                                  gtk_separator_menu_item_new());
    }
    gtk_menu_shell_append(GTK_MENU_SHELL(menu),
                          gtk_separator_menu_item_new());
    GtkWidget *lighter = gtk_menu_item_new_with_label(
        "Lighten (Ctrl+Alt+=)");
    GtkWidget *darker = gtk_menu_item_new_with_label(
        "Darken (Ctrl+Alt+-)");
    GtkWidget *adjustments[] = { lighter, darker };
    int deltas[] = { 1, -1 };
    for (guint index = 0; index < G_N_ELEMENTS(adjustments); index++) {
        g_object_set_data(G_OBJECT(adjustments[index]), "noctty-tab-page",
                          page);
        g_object_set_data(G_OBJECT(adjustments[index]),
                          "noctty-tab-color-delta",
                          GINT_TO_POINTER(deltas[index]));
        g_signal_connect(adjustments[index], "activate",
                         G_CALLBACK(on_tab_color_adjust_activate), root);
        gtk_menu_shell_append(GTK_MENU_SHELL(menu), adjustments[index]);
    }
    (void)current_shade;
    return menu;
}

static void popup_menu_at_toplevel_pointer(
    NocttyGridContext *context, GtkWidget *menu, GtkWidget *anchor,
    GdkEventButton *event) {
    NocttyGridContext *root = root_grid_context(context);
    if (event != NULL && event->send_event) {
        gtk_menu_popup_at_widget(GTK_MENU(menu), anchor,
                                 GDK_GRAVITY_SOUTH_WEST,
                                 GDK_GRAVITY_NORTH_WEST,
                                 (GdkEvent *)event);
        return;
    }
    gint x = event != NULL ? (gint)event->x : 0;
    gint y = event != NULL ? (gint)event->y : 0;
    if (anchor != root->window)
        (void)gtk_widget_translate_coordinates(
            anchor, root->window, x, y, &x, &y);
    GdkWindow *window = gtk_widget_get_window(root->window);
    if (window == NULL) {
        gtk_menu_popup_at_widget(GTK_MENU(menu), anchor,
                                 GDK_GRAVITY_SOUTH_WEST,
                                 GDK_GRAVITY_NORTH_WEST,
                                 (GdkEvent *)event);
        return;
    }
    GdkRectangle point = {x, y, 1, 1};
    gtk_menu_popup_at_rect(GTK_MENU(menu), window, &point,
                           GDK_GRAVITY_SOUTH_WEST,
                           GDK_GRAVITY_NORTH_WEST,
                           (GdkEvent *)event);
}

static void show_tab_menu(NocttyGridContext *context, GtkWidget *page,
                          GdkEventButton *event) {
    NocttyGridContext *root = root_grid_context(context);
    dismiss_grid_popup_windows(root);
    GtkWidget *menu = gtk_menu_new();
    GtkWidget *color = gtk_menu_item_new_with_label("Tab Color");
    GtkWidget *close = gtk_menu_item_new_with_label("Close Tab");
    root->workspace_menu = menu;
    root->tab_context_menu_opened = 1;
    root->tab_color_menu_opened = 1;
    gtk_menu_item_set_submenu(GTK_MENU_ITEM(color),
                              create_tab_color_menu(root, page));
    gtk_menu_shell_append(GTK_MENU_SHELL(menu), color);
    gtk_menu_shell_append(GTK_MENU_SHELL(menu),
                          gtk_separator_menu_item_new());
    g_object_set_data(G_OBJECT(close), "noctty-tab-page", page);
    gtk_widget_set_sensitive(
        close,
        gtk_notebook_get_n_pages(GTK_NOTEBOOK(root->notebook)) > 1);
    g_signal_connect(close, "activate",
                     G_CALLBACK(on_tab_close_menu_activate), root);
    gtk_menu_shell_append(GTK_MENU_SHELL(menu), close);
    g_signal_connect(menu, "selection-done",
                     G_CALLBACK(gtk_widget_destroy), NULL);
    g_signal_connect(menu, "destroy",
                     G_CALLBACK(on_workspace_menu_destroy), root);
    gtk_widget_show_all(menu);
    GtkWidget *anchor = gtk_notebook_get_tab_label(
        GTK_NOTEBOOK(root->notebook), page);
    popup_menu_at_toplevel_pointer(
        root, menu, anchor != NULL ? anchor : root->notebook, event);
}

static gboolean finish_tab_color_smoke(gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    NocttyGridContext *active = active_grid_context(root);
    int preset = -1;
    int shade = 0;
    root->tab_color_restored_rgb = active != NULL && root->event_data != NULL
        ? noctty_grid_tab_color(root->event_data, active->pane_id,
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
    NocttyGridContext *root = root_grid_context(user_data);
    NocttyGridContext *active = active_grid_context(root);
    int preset = -1;
    int shade = 0;
    root->tab_color_lightened_rgb = active != NULL && root->event_data != NULL
        ? noctty_grid_tab_color(root->event_data, active->pane_id,
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
    g_timeout_add(180, finish_tab_color_smoke, root);
    return G_SOURCE_REMOVE;
}

static gboolean lighten_tab_color_smoke(gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    gint page_index = gtk_notebook_get_current_page(
        GTK_NOTEBOOK(root->notebook));
    GtkWidget *page = gtk_notebook_get_nth_page(
        GTK_NOTEBOOK(root->notebook), page_index);
    GtkWidget *tab_widget = page != NULL
        ? gtk_notebook_get_tab_label(GTK_NOTEBOOK(root->notebook), page)
        : NULL;
    GtkWidget *content = GTK_IS_BIN(tab_widget)
        ? gtk_bin_get_child(GTK_BIN(tab_widget)) : NULL;
    GtkWidget *label = tab_label_from_widget(tab_widget);
    guint rendered_rgb = 0;
    guint rendered_alpha = 0;
    if (content != NULL) {
        cairo_surface_t *surface = cairo_image_surface_create(
            CAIRO_FORMAT_ARGB32, 8, 8);
        cairo_t *cr = cairo_create(surface);
        gtk_render_background(gtk_widget_get_style_context(content), cr,
                              0, 0, 8, 8);
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
    const gchar *markup = GTK_IS_LABEL(label)
        ? gtk_label_get_label(GTK_LABEL(label)) : "";
    gchar *tooltip = label != NULL
        ? gtk_widget_get_tooltip_text(label) : NULL;
    root->tab_color_rendered = tab_widget != NULL && content != NULL &&
        gtk_widget_get_mapped(tab_widget) && gtk_widget_get_mapped(content) &&
        GPOINTER_TO_UINT(g_object_get_data(
            G_OBJECT(tab_widget), "noctty-tab-color-rgb")) ==
                root->tab_color_initial_rgb &&
        rendered_rgb == root->tab_color_initial_rgb &&
        rendered_alpha == 0xff;
    root->tab_color_contrast_ready = markup != NULL &&
        strstr(markup, "foreground='#11151b'") != NULL &&
        tooltip != NULL && strstr(tooltip, "tab color Blue") != NULL;
    g_free(tooltip);

    GdkEventKey event = {0};
    event.type = GDK_KEY_PRESS;
    event.state = GDK_CONTROL_MASK | GDK_MOD1_MASK;
    event.keyval = GDK_KEY_equal;
    (void)on_key_press(root->area, &event, root);
    g_timeout_add(180, darken_tab_color_smoke, root);
    return G_SOURCE_REMOVE;
}

static gboolean choose_tab_color_smoke(gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    GtkWidget *color = root->workspace_menu != NULL &&
            gtk_widget_get_mapped(root->workspace_menu)
        ? find_workspace_menu_item(root->workspace_menu, "Tab Color")
        : NULL;
    GtkWidget *submenu = color != NULL
        ? gtk_menu_item_get_submenu(GTK_MENU_ITEM(color)) : NULL;
    GtkWidget *blue = submenu != NULL
        ? find_workspace_menu_item(submenu, "Blue") : NULL;
    if (blue != NULL)
        gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(blue), TRUE);
    NocttyGridContext *active = active_grid_context(root);
    int preset = -1;
    int shade = 0;
    root->tab_color_initial_rgb = active != NULL && root->event_data != NULL
        ? noctty_grid_tab_color(root->event_data, active->pane_id,
                                &preset, &shade)
        : 0;
    root->tab_color_preset_applied = root->tab_color_preset_applied &&
        color != NULL && submenu != NULL && blue != NULL &&
        preset == 5 && shade == 0 &&
        root->tab_color_initial_rgb == 0x4285f4;
    dismiss_workspace_menu(root);
    g_timeout_add(180, lighten_tab_color_smoke, root);
    return G_SOURCE_REMOVE;
}

static gboolean request_tab_color_smoke(gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    gint page_index = gtk_notebook_get_current_page(
        GTK_NOTEBOOK(root->notebook));
    GtkWidget *page = gtk_notebook_get_nth_page(
        GTK_NOTEBOOK(root->notebook), page_index);
    GtkWidget *tab_widget = page != NULL
        ? gtk_notebook_get_tab_label(GTK_NOTEBOOK(root->notebook), page)
        : NULL;
    if (tab_widget == NULL) return G_SOURCE_REMOVE;
    GdkEventButton event = {0};
    event.type = GDK_BUTTON_PRESS;
    event.window = gtk_widget_get_window(tab_widget);
    event.send_event = TRUE;
    event.time = GDK_CURRENT_TIME;
    event.button = 3;
    (void)on_tab_button_press(tab_widget, &event, root);
    (void)on_window_focus_out(root->window, NULL, root);
    g_timeout_add(250, choose_tab_color_smoke, root);
    return G_SOURCE_REMOVE;
}

static gboolean request_new_tab_after_close_smoke(gpointer user_data);
static gboolean cleanup_new_tab_after_close_smoke(gpointer user_data);
static gboolean continue_tab_close_smoke(gpointer user_data);
static gboolean focus_out_tab_close_smoke(gpointer user_data);

static gboolean finish_tab_close_smoke(gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    NocttyGridContext *remaining = active_grid_context(root);
    if (remaining->area != NULL)
        gtk_widget_grab_focus(remaining->area);
    gint current_index = gtk_notebook_get_current_page(GTK_NOTEBOOK(root->notebook));
    GtkWidget *current_page = gtk_notebook_get_nth_page(
        GTK_NOTEBOOK(root->notebook), current_index);
    root->tab_close_remaining_focused = remaining->area != NULL &&
        remaining->pane_id == 2 && remaining->page == current_page;
    root->new_tab_button_visible_after_close =
        root->new_tab_button != NULL &&
        gtk_notebook_get_n_pages(GTK_NOTEBOOK(root->notebook)) == 1 &&
        gtk_notebook_get_show_tabs(GTK_NOTEBOOK(root->notebook)) &&
        gtk_widget_get_mapped(root->new_tab_button);
    if (!root->tab_close_remaining_focused ||
        !root->new_tab_button_visible_after_close)
        g_printerr("native_grid_tab_close_finish pane=%" G_GUINT64_FORMAT " expected=2 current_page=%d page_match=%d pages=%d tabs_visible=%d add_mapped=%d\n",
                   remaining != NULL ? remaining->pane_id : 0,
                   current_index,
                   remaining != NULL && remaining->page == current_page,
                   gtk_notebook_get_n_pages(GTK_NOTEBOOK(root->notebook)),
                   gtk_notebook_get_show_tabs(GTK_NOTEBOOK(root->notebook)),
                   root->new_tab_button != NULL &&
                       gtk_widget_get_mapped(root->new_tab_button));
    if (root->tab_close_remaining_focused &&
        root->new_tab_button_visible_after_close)
        g_timeout_add(150, request_new_tab_after_close_smoke, root);
    return G_SOURCE_REMOVE;
}

static gboolean probe_retired_tab_callback(gpointer user_data) {
    NocttyGridContext *context = user_data;
    NocttyGridContext *root = root_grid_context(context);
    gboolean retired = context->retiring && !context->active &&
        context->area == NULL && context->page == NULL;
    (void)on_focus_out(NULL, NULL, context);
    root->late_callback_guarded = retired &&
        !grid_context_session_available(context);
    return G_SOURCE_REMOVE;
}

static gboolean open_tab_close_smoke_menu(NocttyGridContext *root) {
    GtkWidget *page = gtk_notebook_get_nth_page(
        GTK_NOTEBOOK(root->notebook), 0);
    GtkWidget *tab_widget = page != NULL
        ? gtk_notebook_get_tab_label(GTK_NOTEBOOK(root->notebook), page)
        : NULL;
    if (tab_widget == NULL || gtk_widget_get_window(tab_widget) == NULL)
        return FALSE;
    GdkEventButton event = {0};
    event.type = GDK_BUTTON_PRESS;
    event.window = gtk_widget_get_window(tab_widget);
    event.send_event = TRUE;
    event.time = GDK_CURRENT_TIME;
    event.button = 3;
    (void)on_tab_button_press(tab_widget, &event, root);
    return root->workspace_menu != NULL;
}

static gboolean continue_tab_close_smoke(gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    GtkWidget *menu = root->workspace_menu;
    gboolean menu_ready = menu != NULL && gtk_widget_get_mapped(menu) &&
        gtk_widget_get_mapped(root->window) && root->window_presented;
    GtkWidget *close = menu_ready
        ? find_workspace_menu_item(menu, "Close Tab")
        : NULL;
    if (close == NULL) {
        if (root->tab_close_smoke_attempts++ < 80) {
            if (root->tab_close_smoke_attempts % 20 == 0)
                (void)open_tab_close_smoke_menu(root);
            g_timeout_add(25, focus_out_tab_close_smoke, root);
        }
        return G_SOURCE_REMOVE;
    }
    root->tab_close_smoke_attempts = 0;
    root->tab_context_menu_survived = 1;
    GtkWidget *page = g_object_get_data(G_OBJECT(close), "noctty-tab-page");
    NocttyGridContext *closing = grid_context_for_page(root, page);
    gtk_menu_shell_select_item(GTK_MENU_SHELL(menu), close);
    gtk_menu_shell_activate_item(GTK_MENU_SHELL(menu), close, TRUE);
    if (closing != NULL && !closing->heap_allocated)
        g_timeout_add(25, probe_retired_tab_callback, closing);
    g_timeout_add(150, finish_tab_close_smoke, root);
    return G_SOURCE_REMOVE;
}

static gboolean focus_out_tab_close_smoke(gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    GtkWidget *menu = root->workspace_menu;
    if ((menu == NULL || !gtk_widget_get_mapped(menu)) &&
        root->tab_close_smoke_attempts++ < 80) {
        if (root->tab_close_smoke_attempts % 20 == 0)
            (void)open_tab_close_smoke_menu(root);
        g_timeout_add(25, focus_out_tab_close_smoke, root);
        return G_SOURCE_REMOVE;
    }
    root->tab_close_smoke_attempts = 0;
    if (menu == NULL || !gtk_widget_get_mapped(menu))
        return G_SOURCE_REMOVE;
    (void)on_window_focus_out(root->window, NULL, root);
    g_timeout_add(150, continue_tab_close_smoke, root);
    return G_SOURCE_REMOVE;
}

static gboolean request_tab_close_smoke(gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    GtkWidget *page = gtk_notebook_get_nth_page(GTK_NOTEBOOK(root->notebook), 0);
    GtkWidget *current = gtk_notebook_get_nth_page(
        GTK_NOTEBOOK(root->notebook),
        gtk_notebook_get_current_page(GTK_NOTEBOOK(root->notebook)));
    root->tab_close_targeted_background = page != NULL && page != current;
    if (!root->tab_close_targeted_background) return G_SOURCE_REMOVE;
    root->tab_close_smoke_attempts = 0;
    (void)open_tab_close_smoke_menu(root);
    g_timeout_add(25, focus_out_tab_close_smoke, root);
    return G_SOURCE_REMOVE;
}

static gboolean request_new_tab_after_close_smoke(gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    NocttyGridContext *retired = root->contexts != NULL &&
        root->contexts->len > 0
        ? g_ptr_array_index(root->contexts, 0)
        : NULL;
    NocttyGridContext *source = active_grid_context(root);
    guint context_count = root->contexts != NULL ? root->contexts->len : 0;
    gboolean retired_safely = retired != NULL && !retired->active &&
        retired->area == NULL && retired->page == NULL &&
        retired->peer == NULL && source != NULL && source != retired &&
        source->peer == NULL && source->pane_id == 2;
    if (root->new_tab_button != NULL)
        gtk_button_clicked(GTK_BUTTON(root->new_tab_button));
    NocttyGridContext *created = active_grid_context(root);
    root->new_tab_button_reopened_after_close =
        gtk_notebook_get_n_pages(GTK_NOTEBOOK(root->notebook)) == 2 &&
        gtk_notebook_get_current_page(GTK_NOTEBOOK(root->notebook)) == 1;
    root->new_tab_button_fresh_context = retired_safely &&
        root->contexts != NULL && root->contexts->len == context_count + 1 &&
        created != NULL && created != retired && created != source &&
        created->heap_allocated && created->pane_id != 1 &&
        created->pane_id != 2 && created->area != NULL;
    if (root->new_tab_button_reopened_after_close &&
        root->new_tab_button_fresh_context)
        g_timeout_add(200, cleanup_new_tab_after_close_smoke, root);
    return G_SOURCE_REMOVE;
}

static gboolean cleanup_new_tab_after_close_smoke(gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    int first_close_focused = root->tab_close_remaining_focused;
    int first_close_add_visible = root->new_tab_button_visible_after_close;
    gint current_index = gtk_notebook_get_current_page(
        GTK_NOTEBOOK(root->notebook));
    GtkWidget *page = gtk_notebook_get_nth_page(GTK_NOTEBOOK(root->notebook),
                                                current_index);
    gboolean closed =
        gtk_notebook_get_n_pages(GTK_NOTEBOOK(root->notebook)) == 2 &&
        close_grid_tab(root, page);
    root->new_tab_button_cleanup = closed &&
        gtk_notebook_get_n_pages(GTK_NOTEBOOK(root->notebook)) == 1 &&
        gtk_notebook_get_show_tabs(GTK_NOTEBOOK(root->notebook)) &&
        root->new_tab_button != NULL &&
        gtk_widget_get_mapped(root->new_tab_button);
    root->tab_close_remaining_focused = first_close_focused;
    root->new_tab_button_visible_after_close = first_close_add_visible;
    return G_SOURCE_REMOVE;
}

static void show_workspace_menu(NocttyGridContext *context, GdkEventButton *event) {
    NocttyGridContext *root = root_grid_context(context);
    dismiss_grid_popup_windows(root);
    GtkWidget *profile_menu = create_profile_preset_menu(context);
    const NocttyWorkspaceMenuOptions options = {
        .context = context,
        .root = root,
        .profile_menu = profile_menu,
        .broadcast_label = noctty_grid_broadcast_menu_label(
            root->event_data != NULL &&
            noctty_grid_broadcast_enabled(root->event_data) != 0),
        .selection_active = context->selecting,
        .pane_close_sensitive = active_grid_context_count(root) > 1,
    };
    const NocttyWorkspaceMenuCallbacks callbacks = {
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
        .selection_done = G_CALLBACK(gtk_widget_destroy),
        .destroy = G_CALLBACK(on_workspace_menu_destroy),
    };
    GtkWidget *menu = noctty_workspace_menu_new(&options, &callbacks);
    if (menu == NULL) return;
    root->workspace_menu = menu;
    root->context_menu_opened = 1;
    root->pane_close_menu_opened = 1;
    gtk_widget_show_all(menu);
    if (event != NULL && event->send_event) {
        /* Smoke events are constructed in-process rather than dispatched by
         * GDK, so popup-at-pointer has no compositor-owned trigger event to
         * position from. Anchor those menus to the pane itself; real pointer
         * events keep the normal desktop placement path. */
        GdkEvent *trigger = gdk_event_new(GDK_BUTTON_PRESS);
        trigger->button.window = event->window != NULL
            ? g_object_ref(event->window) : NULL;
        trigger->button.send_event = TRUE;
        trigger->button.time = event->time;
        trigger->button.x = event->x;
        trigger->button.y = event->y;
        trigger->button.state = event->state;
        trigger->button.button = event->button;
        trigger->button.x_root = event->x_root;
        trigger->button.y_root = event->y_root;
        GdkDisplay *display = gtk_widget_get_display(context->area);
        GdkSeat *seat = display != NULL
            ? gdk_display_get_default_seat(display) : NULL;
        GdkDevice *pointer = seat != NULL
            ? gdk_seat_get_pointer(seat) : NULL;
        if (pointer != NULL)
            gdk_event_set_device(trigger, pointer);
        gtk_menu_popup_at_widget(GTK_MENU(menu), context->area,
                                 GDK_GRAVITY_SOUTH_WEST,
                                 GDK_GRAVITY_NORTH_WEST,
                                 trigger);
        gdk_event_free(trigger);
    } else
        popup_menu_at_toplevel_pointer(context, menu, context->area, event);
}

static gboolean open_smoke_workspace_menu(NocttyGridContext *context) {
    if (context == NULL || context->area == NULL ||
        !gtk_widget_get_mapped(context->area)) return FALSE;
    GdkEventButton event = {0};
    event.type = GDK_BUTTON_PRESS;
    event.window = gtk_widget_get_window(context->area);
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
    NocttyGridContext *root = root_grid_context(user_data);
    for (guint index = 0;
         root->contexts != NULL && index < root->contexts->len; index++) {
        NocttyGridContext *candidate = g_ptr_array_index(
            root->contexts, index);
        if (candidate->active && !candidate->exited &&
            candidate->write != NULL)
            (void)candidate->write(candidate->userdata, "exit 0\n", 7);
    }
    return G_SOURCE_REMOVE;
}

static gboolean open_profile_preset_smoke_menu(gpointer user_data);

static gboolean check_profile_preset_smoke(gpointer user_data) {
    NocttyGridContext *target = user_data;
    NocttyGridContext *root = root_grid_context(target);
    NocttyGridContext *neighbor = root->contexts != NULL &&
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
        g_timeout_add(120, open_profile_preset_smoke_menu, target);
    } else if (root->profile_smoke_stage == 2) {
        root->profile_high_contrast = target_synced &&
            target->profile_preset == 3 &&
            ABS(target->font_size - 12.0) < 0.01 &&
            target->high_contrast;
        root->profile_exact_target = root->profile_exact_target &&
            root->profile_high_contrast && neighbor_unchanged;
        root->profile_smoke_stage = 3;
        g_timeout_add(120, open_profile_preset_smoke_menu, target);
    } else if (root->profile_smoke_stage == 3) {
        root->profile_mono_no_ligatures = target_synced &&
            target->profile_preset == 4 && !target->ligatures &&
            !target->high_contrast;
        root->profile_exact_target = root->profile_exact_target &&
            root->profile_mono_no_ligatures && neighbor_unchanged;
        g_timeout_add(180, finish_profile_preset_smoke, root);
    }
    return G_SOURCE_REMOVE;
}

static gboolean activate_profile_preset_smoke(gpointer user_data) {
    NocttyGridContext *target = user_data;
    NocttyGridContext *root = root_grid_context(target);
    GtkWidget *menu = root->workspace_menu;
    GtkWidget *profile = menu != NULL
        ? find_workspace_menu_item(menu, "Profile") : NULL;
    GtkWidget *submenu = profile != NULL
        ? gtk_menu_item_get_submenu(GTK_MENU_ITEM(profile)) : NULL;
    const int stage = root->profile_smoke_stage;
    const int expected = stage == 1 ? 0 : stage == 2 ? 2 : 3;
    const int selected = stage == 1 ? 2 : stage == 2 ? 3 : 4;
    GtkWidget *current = submenu != NULL
        ? find_workspace_menu_item(submenu,
                                   noctty_grid_profile_preset_label(expected)) : NULL;
    GtkWidget *choice = submenu != NULL
        ? find_workspace_menu_item(submenu,
                                   noctty_grid_profile_preset_label(selected)) : NULL;
    int preset_count = 0;
    if (submenu != NULL) {
        GList *items = gtk_container_get_children(GTK_CONTAINER(submenu));
        for (GList *item = items; item != NULL; item = item->next)
            if (GTK_IS_RADIO_MENU_ITEM(item->data)) preset_count++;
        g_list_free(items);
    }
    gboolean current_ready = current != NULL &&
        gtk_check_menu_item_get_active(GTK_CHECK_MENU_ITEM(current));
    gboolean menus_mapped = menu != NULL && submenu != NULL &&
        gtk_widget_get_mapped(menu) && gtk_widget_get_mapped(submenu);
    if ((!menus_mapped || !current_ready || choice == NULL ||
         preset_count != 5) && root->profile_smoke_attempts++ < 20) {
        g_timeout_add(25, activate_profile_preset_smoke, target);
        return G_SOURCE_REMOVE;
    }
    root->profile_smoke_attempts = 0;
    NocttyGridContext *neighbor = root->contexts != NULL &&
            root->contexts->len >= 2
        ? g_ptr_array_index(root->contexts, 0) : NULL;
    root->profile_exact_target = root->profile_exact_target &&
        neighbor != NULL && focused_grid_context(root) == neighbor &&
        gtk_window_get_focus(GTK_WINDOW(root->window)) == neighbor->area;
    if (current_ready) root->profile_menu_current++;
    root->profile_menu_survived = root->profile_menu_survived ||
        (menus_mapped && preset_count == 5);
    if (choice == NULL) {
        if (submenu != NULL) gtk_menu_popdown(GTK_MENU(submenu));
        if (menu != NULL && root->workspace_menu == menu)
            gtk_widget_destroy(menu);
        g_timeout_add(100, finish_profile_preset_smoke, root);
        return G_SOURCE_REMOVE;
    }
    gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(choice), TRUE);
    if (submenu != NULL) gtk_menu_popdown(GTK_MENU(submenu));
    if (menu != NULL && root->workspace_menu == menu)
        gtk_widget_destroy(menu);
    g_timeout_add(240, check_profile_preset_smoke, target);
    return G_SOURCE_REMOVE;
}

static gboolean present_profile_preset_submenu_smoke(gpointer user_data) {
    NocttyGridContext *target = user_data;
    NocttyGridContext *root = root_grid_context(target);
    GtkWidget *menu = root->workspace_menu;
    GtkWidget *profile = menu != NULL && gtk_widget_get_mapped(menu)
        ? find_workspace_menu_item(menu, "Profile") : NULL;
    GtkWidget *submenu = profile != NULL
        ? gtk_menu_item_get_submenu(GTK_MENU_ITEM(profile)) : NULL;
    if (profile == NULL || submenu == NULL) {
        if (root->profile_smoke_attempts++ < 20) {
            g_timeout_add(25, present_profile_preset_submenu_smoke, target);
            return G_SOURCE_REMOVE;
        }
        root->profile_smoke_attempts = 0;
        g_timeout_add(100, finish_profile_preset_smoke, root);
        return G_SOURCE_REMOVE;
    }
    root->profile_smoke_attempts = 0;
    gtk_menu_shell_select_item(GTK_MENU_SHELL(menu), profile);
    GdkEvent *trigger = gdk_event_new(GDK_BUTTON_PRESS);
    GdkWindow *window = gtk_widget_get_window(profile);
    trigger->button.window = window != NULL ? g_object_ref(window) : NULL;
    trigger->button.send_event = TRUE;
    trigger->button.time = GDK_CURRENT_TIME;
    trigger->button.button = 3;
    GdkDisplay *display = gtk_widget_get_display(profile);
    GdkSeat *seat = display != NULL
        ? gdk_display_get_default_seat(display) : NULL;
    GdkDevice *pointer = seat != NULL
        ? gdk_seat_get_pointer(seat) : NULL;
    if (pointer != NULL)
        gdk_event_set_device(trigger, pointer);
    gtk_menu_popup_at_widget(GTK_MENU(submenu), profile,
                             GDK_GRAVITY_NORTH_EAST,
                             GDK_GRAVITY_NORTH_WEST,
                             trigger);
    gdk_event_free(trigger);
    g_timeout_add(140, activate_profile_preset_smoke, target);
    return G_SOURCE_REMOVE;
}

static gboolean wait_profile_preset_parent_menu_smoke(gpointer user_data) {
    NocttyGridContext *target = user_data;
    NocttyGridContext *root = root_grid_context(target);
    GtkWidget *menu = root->workspace_menu;
    if ((menu == NULL || !gtk_widget_get_mapped(menu)) &&
        root->profile_smoke_attempts++ < 20) {
        g_timeout_add(25, wait_profile_preset_parent_menu_smoke, target);
        return G_SOURCE_REMOVE;
    }
    if (menu == NULL || !gtk_widget_get_mapped(menu)) {
        root->profile_smoke_attempts = 0;
        g_timeout_add(100, finish_profile_preset_smoke, root);
        return G_SOURCE_REMOVE;
    }
    root->profile_smoke_attempts = 0;
    (void)on_window_focus_out(root->window, NULL, root);
    g_timeout_add(180, present_profile_preset_submenu_smoke, target);
    return G_SOURCE_REMOVE;
}

static gboolean open_profile_preset_smoke_menu(gpointer user_data) {
    NocttyGridContext *target = user_data;
    NocttyGridContext *root = root_grid_context(target);
    if (target == NULL || target->area == NULL) {
        g_timeout_add(100, finish_profile_preset_smoke, root);
        return G_SOURCE_REMOVE;
    }
    (void)open_smoke_workspace_menu(target);
    root->profile_smoke_attempts = 0;
    g_timeout_add(25, wait_profile_preset_parent_menu_smoke, target);
    return G_SOURCE_REMOVE;
}

static gboolean request_profile_preset_smoke(gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    if (root->contexts == NULL || root->contexts->len != 2) {
        g_timeout_add(100, finish_profile_preset_smoke, root);
        return G_SOURCE_REMOVE;
    }
    NocttyGridContext *neighbor = g_ptr_array_index(root->contexts, 0);
    NocttyGridContext *target = g_ptr_array_index(root->contexts, 1);
    (void)sync_grid_context_profile(neighbor);
    (void)sync_grid_context_profile(target);
    root->profile_neighbor_font_size = neighbor->font_size;
    root->profile_neighbor_high_contrast = neighbor->high_contrast;
    root->profile_neighbor_ligatures = neighbor->ligatures;
    root->profile_neighbor_preset = neighbor->profile_preset;
    root->profile_isolated = 1;
    if (neighbor->area != NULL) gtk_widget_grab_focus(neighbor->area);
    root->profile_exact_target = neighbor != target &&
        neighbor->pane_id != target->pane_id && target->active &&
        neighbor->active && focused_grid_context(root) == neighbor &&
        gtk_window_get_focus(GTK_WINDOW(root->window)) == neighbor->area;
    root->profile_smoke_stage = 1;
    return open_profile_preset_smoke_menu(target);
}

static gboolean finish_pane_close_resize_smoke(gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    root->pane_close_user_resize_preserved =
        GTK_IS_PANED(root->pane_close_resize_split) &&
        gtk_paned_get_position(GTK_PANED(root->pane_close_resize_split)) ==
            root->pane_close_resize_position;
    root->pane_close_resize_split = NULL;

    for (;;) {
        NocttyGridContext *extra = NULL;
        for (guint index = 0; root->contexts != NULL &&
             index < root->contexts->len; index++) {
            NocttyGridContext *candidate = g_ptr_array_index(
                root->contexts, index);
            if (candidate->active && candidate->pane_id != 2) {
                extra = candidate;
                break;
            }
        }
        if (extra == NULL || !close_grid_pane(extra)) break;
    }

    NocttyGridContext *remaining = grid_context_for_pane(root, 2);
    if (remaining != NULL && remaining->area != NULL) {
        (void)open_smoke_workspace_menu(remaining);
        GtkWidget *close_terminal = root->workspace_menu != NULL
            ? find_workspace_menu_item(root->workspace_menu, "Close Terminal")
            : NULL;
        root->pane_close_last_terminal_protected = close_terminal != NULL &&
            !gtk_widget_get_sensitive(close_terminal);
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
    NocttyGridContext *root, GtkWidget *page) {
    gint x_positions[4] = {0};
    gint y_positions[4] = {0};
    gint width_min = G_MAXINT;
    gint width_max = 0;
    gint height_min = G_MAXINT;
    gint height_max = 0;
    guint measured = 0;
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        NocttyGridContext *candidate = g_ptr_array_index(
            root->contexts, index);
        if (!candidate->active || candidate->page != page ||
            candidate->area == NULL) continue;
        if (measured >= G_N_ELEMENTS(x_positions)) return FALSE;
        GtkAllocation allocation;
        gtk_widget_get_allocation(candidate->area, &allocation);
        if (!gtk_widget_translate_coordinates(
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
    NocttyGridContext *root, GtkWidget *page, guint expected_count) {
    gint64 minimum_area = G_MAXINT64;
    gint64 maximum_area = 0;
    guint measured = 0;
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        NocttyGridContext *candidate = g_ptr_array_index(
            root->contexts, index);
        if (!candidate->active || candidate->page != page ||
            candidate->area == NULL) continue;
        GtkAllocation allocation;
        gtk_widget_get_allocation(candidate->area, &allocation);
        gint64 area = (gint64)allocation.width * allocation.height;
        minimum_area = MIN(minimum_area, area);
        maximum_area = MAX(maximum_area, area);
        measured++;
    }
    return measured == expected_count && maximum_area > 0 &&
        (maximum_area - minimum_area) * 100 <= maximum_area * 5;
}

static gboolean finish_pane_close_smoke(gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    NocttyGridContext *closed = grid_context_for_pane(root, 1);
    NocttyGridContext *remaining = grid_context_for_pane(root, 2);
    gint current_index = gtk_notebook_get_current_page(
        GTK_NOTEBOOK(root->notebook));
    GtkWidget *current_page = gtk_notebook_get_nth_page(
        GTK_NOTEBOOK(root->notebook), current_index);
    root->pane_close_rendered_collapsed = closed != NULL &&
        !closed->active && closed->area == NULL && closed->page == NULL &&
        remaining != NULL && remaining->active && remaining->area != NULL &&
        gtk_widget_get_parent(remaining->area) != NULL;
    if (remaining != NULL && remaining->area != NULL)
        gtk_widget_grab_focus(remaining->area);
    root->pane_close_remaining_focused = remaining != NULL &&
        remaining->active && remaining->pane_id == 2 &&
        remaining->page == current_page;

    root->pane_close_evenly_distributed =
        smoke_page_panes_evenly_distributed(root, current_page, 3);

    GtkWidget *layout = remaining != NULL
        ? grid_page_content_root(remaining, current_page) : NULL;
    if (GTK_IS_PANED(layout)) {
        gint max_position = 0;
        g_object_get(G_OBJECT(layout), "max-position", &max_position, NULL);
        if (max_position > 0) {
            root->pane_close_resize_split = layout;
            root->pane_close_resize_position = MAX(1, max_position / 4);
            gtk_paned_set_position(GTK_PANED(layout),
                                   root->pane_close_resize_position);
        }
    }
    g_timeout_add(120, finish_pane_close_resize_smoke, root);
    return G_SOURCE_REMOVE;
}

static gboolean continue_pane_close_smoke(gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    GtkWidget *menu = root->workspace_menu;
    gboolean menu_ready = menu != NULL && gtk_widget_get_mapped(menu) &&
        gtk_widget_get_mapped(root->window) && root->window_presented;
    GtkWidget *close_terminal = menu_ready
        ? find_workspace_menu_item(menu, "Close Terminal")
        : NULL;
    if (close_terminal == NULL || !gtk_widget_get_sensitive(close_terminal)) {
        if (root->pane_close_smoke_attempts++ < 80) {
            if (root->pane_close_smoke_attempts % 20 == 0) {
                NocttyGridContext *target = grid_context_for_pane(root, 1);
                (void)open_smoke_workspace_menu(target);
            }
            g_timeout_add(25, continue_pane_close_smoke, root);
            return G_SOURCE_REMOVE;
        }
        for (guint index = 0;
             root->contexts != NULL && index < root->contexts->len; index++) {
            NocttyGridContext *candidate = g_ptr_array_index(
                root->contexts, index);
            if (candidate->active && !candidate->exited &&
                candidate->write != NULL)
                (void)candidate->write(candidate->userdata, "\n", 1);
        }
        return G_SOURCE_REMOVE;
    }
    root->pane_close_smoke_attempts = 0;
    root->pane_close_menu_survived = 1;
    gtk_menu_shell_select_item(GTK_MENU_SHELL(menu), close_terminal);
    gtk_menu_shell_activate_item(GTK_MENU_SHELL(menu), close_terminal, TRUE);
    g_timeout_add(180, finish_pane_close_smoke, root);
    return G_SOURCE_REMOVE;
}

static gboolean inspect_and_resize_pane_close_layout(gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    NocttyGridContext *pane = grid_context_for_pane(root, 1);
    GtkWidget *page = pane != NULL ? pane->page : NULL;
    root->pane_split_evenly_distributed =
        smoke_page_panes_evenly_distributed(root, page, 4);
    root->pane_split_two_by_two = smoke_page_is_even_two_by_two(root, page);
    gint width = 0;
    gint height = 0;
    gtk_window_get_size(GTK_WINDOW(root->window), &width, &height);
    gtk_window_resize(GTK_WINDOW(root->window), width + 320, height + 180);
    return G_SOURCE_REMOVE;
}

static gboolean disturb_pane_close_layout(gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    NocttyGridContext *pane = grid_context_for_pane(root, 1);
    GtkWidget *page = pane != NULL ? pane->page : NULL;
    root->pane_split_resize_equal = smoke_page_is_even_two_by_two(root, page);
    GtkWidget *layout = pane != NULL
        ? grid_page_content_root(pane, page) : NULL;
    if (GTK_IS_PANED(layout)) {
        gint max_position = 0;
        g_object_get(G_OBJECT(layout), "max-position", &max_position, NULL);
        if (max_position > 0)
            gtk_paned_set_position(GTK_PANED(layout),
                                   MAX(1, max_position / 5));
    }
    return G_SOURCE_REMOVE;
}

static gboolean emit_pane_close_primary_split_right(gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    NocttyGridContext *target = grid_context_for_pane(root, 1);
    if (target != NULL) emit_grid_workspace_event(target, 27);
    return G_SOURCE_REMOVE;
}

static gboolean emit_pane_close_secondary_split_right(gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    NocttyGridContext *target = grid_context_for_pane(root, 2);
    if (target != NULL) emit_grid_workspace_event(target, 27);
    return G_SOURCE_REMOVE;
}

static gboolean request_pane_close_smoke(gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    NocttyGridContext *target = grid_context_for_pane(root, 1);
    NocttyGridContext *remaining = grid_context_for_pane(root, 2);
    root->pane_close_targeted_primary = target != NULL && target->primary &&
        target->active && target->area != NULL && remaining != NULL &&
        remaining->active && remaining->area != NULL;
    if (!root->pane_close_targeted_primary) return G_SOURCE_REMOVE;
    root->pane_close_smoke_attempts = 0;
    (void)open_smoke_workspace_menu(target);
    (void)on_window_focus_out(root->window, NULL, root);
    g_timeout_add(250, continue_pane_close_smoke, root);
    return G_SOURCE_REMOVE;
}

static NocttyGridContext *terminal_chord_smoke_target(
    NocttyGridContext *context) {
    NocttyGridContext *root = root_grid_context(context);
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        NocttyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (candidate != root && candidate->active && !candidate->exited &&
            candidate->area != NULL && candidate->page != NULL)
            return candidate;
    }
    return NULL;
}

static gboolean request_terminal_interrupt_chord_smoke(gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    NocttyGridContext *target = terminal_chord_smoke_target(root);
    if (target == NULL) return G_SOURCE_REMOVE;
    gtk_widget_grab_focus(target->area);
    GdkEventKey event = {0};
    event.type = GDK_KEY_PRESS;
    event.keyval = GDK_KEY_c;
    event.state = GDK_CONTROL_MASK;
    gboolean handled = on_key_press(target->area, &event, target);
    root->terminal_chord_interrupt_focused = handled &&
        root->ctrl_c_local_interrupt &&
        gtk_window_get_focus(GTK_WINDOW(root->window)) == target->area;
    GdkEventKey enter_event = {0};
    enter_event.type = GDK_KEY_PRESS;
    enter_event.window = gtk_widget_get_window(target->area);
    enter_event.keyval = GDK_KEY_Return;
    root->terminal_chord_enter_forwarded =
        on_key_press(target->area, &enter_event, target) &&
        gtk_window_get_focus(GTK_WINDOW(root->window)) == target->area;
    if (root->event != NULL)
        root->event(root->event_data, target->pane_id, 102,
                    root->terminal_chord_interrupt_focused &&
                        root->terminal_chord_enter_forwarded,
                    (uint64_t)(g_get_monotonic_time() / 1000));
    return G_SOURCE_REMOVE;
}

static gboolean finish_terminal_close_focus_smoke(gpointer user_data);

static gboolean request_terminal_close_chord_smoke(gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    NocttyGridContext *target = terminal_chord_smoke_target(root);
    if (target == NULL) return G_SOURCE_REMOVE;
    gtk_widget_grab_focus(target->area);
    root->terminal_chord_closed_pane_id = target->pane_id;
    GdkEventKey event = {0};
    event.type = GDK_KEY_PRESS;
    event.keyval = GDK_KEY_d;
    event.state = GDK_CONTROL_MASK;
    gboolean handled = on_key_press(target->area, &event, target);
    NocttyGridContext *remaining = active_grid_context(root);
    root->terminal_chord_close_exact = handled &&
        root->ctrl_d_close_attempted && root->ctrl_d_close_succeeded &&
        !target->active && target->area == NULL && target->page == NULL;
    root->terminal_chord_close_rendered = remaining != NULL &&
        remaining->active && remaining->area != NULL &&
        gtk_widget_get_parent(remaining->area) == remaining->page;
    root->terminal_chord_close_session_stopped =
        root->pane_close_session_stopped;
    g_idle_add(finish_terminal_close_focus_smoke, root);
    return G_SOURCE_REMOVE;
}

static gboolean finish_terminal_close_focus_smoke(gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    NocttyGridContext *remaining = active_grid_context(root);
    root->terminal_chord_remaining_focused = remaining != NULL &&
        remaining->active && remaining->area != NULL &&
        gtk_window_get_focus(GTK_WINDOW(root->window)) == remaining->area;
    if (root->event != NULL && remaining != NULL)
        root->event(root->event_data, remaining->pane_id, 103,
                    root->terminal_chord_close_exact &&
                        root->terminal_chord_close_rendered &&
                        root->terminal_chord_close_session_stopped &&
                        root->terminal_chord_remaining_focused,
                    root->terminal_chord_closed_pane_id);
    return G_SOURCE_REMOVE;
}

static gboolean request_terminal_final_pane_guard_smoke(gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    NocttyGridContext *remaining = active_grid_context(root);
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
        root->event(root->event_data, remaining->pane_id, 104,
                    root->terminal_chord_final_protected,
                    (uint64_t)(g_get_monotonic_time() / 1000));
    return G_SOURCE_REMOVE;
}

static gboolean finish_terminal_chord_smoke(gpointer user_data) {
    NocttyGridContext *remaining = active_grid_context(user_data);
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

static gboolean verify_layout_preset_geometry(NocttyGridContext *context,
                                              guint rows, guint cols) {
    NocttyGridContext *root = root_grid_context(context);
    gint current_index = gtk_notebook_get_current_page(
        GTK_NOTEBOOK(root->notebook));
    GtkWidget *page = gtk_notebook_get_nth_page(GTK_NOTEBOOK(root->notebook),
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
        NocttyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (!candidate->active || candidate->exited ||
            candidate->page != page || candidate->area == NULL) continue;
        if (count >= G_N_ELEMENTS(centers_x)) return FALSE;
        GtkAllocation allocation;
        gint x = 0;
        gint y = 0;
        gtk_widget_get_allocation(candidate->area, &allocation);
        gboolean translated = gtk_widget_translate_coordinates(
            candidate->area, page, 0, 0, &x, &y);
        mapped = mapped && gtk_widget_get_mapped(candidate->area) &&
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

static gboolean verify_layout_terminals_ready(NocttyGridContext *context,
                                               guint expected) {
    NocttyGridContext *root = root_grid_context(context);
    GtkWidget *page = gtk_notebook_get_nth_page(
        GTK_NOTEBOOK(root->notebook),
        gtk_notebook_get_current_page(GTK_NOTEBOOK(root->notebook)));
    guint ready = 0;
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        NocttyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (!candidate->active || candidate->exited ||
            candidate->page != page || candidate->area == NULL)
            continue;
        gboolean nonblank = FALSE;
        for (int row = 0; row < candidate->rows && !nonblank; row++) {
            for (int column = 0; column < candidate->columns; column++) {
                uint32_t glyph = (uint32_t)candidate->cell(
                    candidate->userdata, column, row);
                if (glyph != 0 && glyph != ' ') {
                    nonblank = TRUE;
                    break;
                }
            }
        }
        /* Buffer content alone does not prove a visible pane. Requiring the
         * draw callback catches mapped terminals that GTK has not painted. */
        if (grid_context_session_available(candidate) &&
            gtk_widget_get_parent(candidate->area) != NULL &&
            gtk_widget_get_mapped(candidate->area) && candidate->saw_draw &&
            nonblank)
            ready++;
    }
    return ready == expected;
}

static gboolean verify_layout_auto_fit(NocttyGridContext *context) {
    NocttyGridContext *root = root_grid_context(context);
    GtkWidget *page = gtk_notebook_get_nth_page(
        GTK_NOTEBOOK(root->notebook),
        gtk_notebook_get_current_page(GTK_NOTEBOOK(root->notebook)));
    guint count = 0;
    gboolean fitted = TRUE;
    gboolean overlay = TRUE;
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        NocttyGridContext *candidate = g_ptr_array_index(root->contexts, index);
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

static gboolean write_layout_smoke_input(NocttyGridContext *context,
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

static gboolean verify_layout_tui(NocttyGridContext *context) {
    const char *tui = g_getenv("NOCTTY_LAYOUT_TUI");
    NocttyGridContext *root = root_grid_context(context);
    if (tui == NULL || tui[0] == '\0') return TRUE;
    GtkWidget *page = gtk_notebook_get_nth_page(
        GTK_NOTEBOOK(root->notebook),
        gtk_notebook_get_current_page(GTK_NOTEBOOK(root->notebook)));
    guint rendered = 0;
    guint input = 0;
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        NocttyGridContext *candidate = g_ptr_array_index(root->contexts, index);
        if (!candidate->active || candidate->exited ||
            candidate->page != page) continue;
        guint nonblank = 0;
        for (int row = 0; row < candidate->rows && nonblank < 8; row++) {
            for (int column = 0; column < candidate->columns && nonblank < 8;
                 column++) {
                uint32_t glyph = (uint32_t)candidate->cell(
                    candidate->userdata, column, row);
                if (glyph != 0 && glyph != ' ') nonblank++;
            }
        }
        if (nonblank >= 8) rendered++;
        if (write_layout_smoke_input(candidate, "l", 1)) input++;
    }
    if (rendered != 16 || input != 16)
        g_printerr("native_grid_layout_tui_not_ready app=%s rendered=%u input=%u\n",
                   tui, rendered, input);
    return rendered == 16 && input == 16;
}

static gboolean verify_layout_floor_feedback(NocttyGridContext *context) {
    NocttyGridContext *root = root_grid_context(context);
    NocttyGridContext *candidate = active_grid_context(root);
    if (candidate == NULL || candidate->area == NULL) return FALSE;
    GtkAllocation actual;
    gtk_widget_get_allocation(candidate->area, &actual);
    GtkAllocation impossible = { .x = 0, .y = 0, .width = 100, .height = 80 };
    resize_grid_to_allocation(candidate, &impossible);
    gboolean reached = candidate->resize_overlay_floor_reached &&
        fabs(candidate->font_size - 3.0) < 0.01;
    resize_grid_to_allocation(candidate, &actual);
    return reached;
}

static gboolean apply_layout_preset_smoke_stage(gpointer user_data);

static void finish_layout_preset_smoke_sessions(NocttyGridContext *root) {
    for (guint index = 0; root->contexts != NULL &&
         index < root->contexts->len; index++) {
        NocttyGridContext *candidate = g_ptr_array_index(
            root->contexts, index);
        if (candidate->active && candidate->write != NULL) {
            const char *tui = g_getenv("NOCTTY_LAYOUT_TUI");
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
    NocttyGridContext *root = root_grid_context(user_data);
    NocttyGridContext *remaining;
    if (root->layout_preset_smoke_stage == 9) {
        gboolean geometry = verify_layout_preset_geometry(root, 4, 4);
        gboolean terminals = verify_layout_terminals_ready(root, 16);
        gboolean tui = geometry && terminals && verify_layout_tui(root);
        root->layout_preset_4x4_rendered =
            root->layout_preset_4x4_applied && geometry && terminals && tui;
        if (!root->layout_preset_4x4_rendered &&
            root->layout_preset_smoke_attempts++ < 40) {
            GtkWidget *page = gtk_notebook_get_nth_page(
                GTK_NOTEBOOK(root->notebook),
                gtk_notebook_get_current_page(GTK_NOTEBOOK(root->notebook)));
            if (page != NULL) queue_grid_preset_widget_draw(page, NULL);
            g_timeout_add(50, check_layout_preset_smoke, root);
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
        g_timeout_add(180, apply_layout_preset_smoke_stage, root);
    } else if (root->layout_preset_smoke_stage == 3) {
        root->layout_preset_4x2_rendered =
            root->layout_preset_4x2_applied &&
            verify_layout_preset_geometry(root, 2, 4);
        root->layout_preset_smoke_stage = 1;
        g_timeout_add(180, apply_layout_preset_smoke_stage, root);
    } else if (root->layout_preset_smoke_stage == 4) {
        root->layout_preset_3x3_rendered =
            root->layout_preset_3x3_applied &&
            verify_layout_preset_geometry(root, 3, 3);
        root->layout_preset_smoke_stage = 5;
        g_timeout_add(180, apply_layout_preset_smoke_stage, root);
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
        g_timeout_add(180, apply_layout_preset_smoke_stage, root);
    } else if (root->layout_preset_smoke_stage == 6) {
        root->layout_preset_4x4_rendered =
            root->layout_preset_4x4_rendered &&
            root->layout_preset_prompt_cancelled == 1 &&
            verify_layout_preset_geometry(root, 4, 4);
        root->layout_preset_smoke_stage = 7;
        g_timeout_add(180, apply_layout_preset_smoke_stage, root);
    } else if (root->layout_preset_smoke_stage == 8) {
        gint current_index = gtk_notebook_get_current_page(
            GTK_NOTEBOOK(root->notebook));
        GtkWidget *production_page = gtk_notebook_get_nth_page(
            GTK_NOTEBOOK(root->notebook), current_index);
        gboolean geometry = verify_layout_preset_geometry(root, 4, 4);
        gboolean terminals = verify_layout_terminals_ready(root, 16);
        gboolean auto_fit = verify_layout_auto_fit(root);
        gboolean tui = geometry && terminals && verify_layout_tui(root);
        root->layout_preset_4x4_rendered =
            root->layout_preset_4x4_applied && geometry && terminals &&
            auto_fit && tui;
        if (!root->layout_preset_4x4_rendered &&
            root->layout_preset_smoke_attempts++ < 40) {
            GtkWidget *page = gtk_notebook_get_nth_page(
                GTK_NOTEBOOK(root->notebook),
                gtk_notebook_get_current_page(GTK_NOTEBOOK(root->notebook)));
            if (page != NULL) {
                gtk_widget_queue_resize(page);
                queue_grid_preset_widget_draw(page, NULL);
            }
            g_timeout_add(50, check_layout_preset_smoke, root);
            return G_SOURCE_REMOVE;
        }
        if (production_page != NULL && production_page != root->page)
            (void)close_grid_tab(root, production_page);
        finish_layout_preset_smoke_sessions(root);
    } else if (root->layout_preset_smoke_stage == 7) {
        gint source_index = gtk_notebook_page_num(
            GTK_NOTEBOOK(root->notebook), root->page);
        GtkWidget *overflow_page = gtk_notebook_get_nth_page(
            GTK_NOTEBOOK(root->notebook), source_index == 0 ? 1 : 0);
        if (source_index >= 0)
            gtk_notebook_set_current_page(GTK_NOTEBOOK(root->notebook),
                                          source_index);
        gboolean sessions_ready = active_grid_context_count(root) == 16;
        for (guint index = 0; root->contexts != NULL &&
             index < root->contexts->len; index++) {
            NocttyGridContext *candidate = g_ptr_array_index(
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
            gtk_notebook_get_n_pages(GTK_NOTEBOOK(root->notebook)) == 2 &&
            grid_contexts_on_page(root, overflow_page) == 15 &&
            sessions_ready;
        remaining = root;
        if (remaining->active && remaining->area != NULL)
            gtk_widget_grab_focus(remaining->area);
        root->layout_preset_remaining_focused = remaining != NULL &&
            remaining->active && remaining->area != NULL &&
            remaining->page == root->page;
        root->layout_preset_smoke_stage = 8;
        if (!open_grid_layout_preset_tab(root, 60)) {
            root->layout_preset_4x4_rendered = 0;
            finish_layout_preset_smoke_sessions(root);
        } else {
            g_timeout_add(420, check_layout_preset_smoke, root);
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
            g_timeout_add(180, apply_layout_preset_smoke_stage, root);
        }
    }
    return G_SOURCE_REMOVE;
}

static gboolean continue_layout_preset_smoke(gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    GtkWidget *menu = root->workspace_menu;
    gboolean menu_ready = menu != NULL && gtk_widget_get_mapped(menu) &&
        gtk_widget_get_mapped(root->window) && root->window_presented;
    if (root->workspace_smoke == 43) {
        GtkWidget *layout_4x4 = menu_ready
            ? find_workspace_menu_item(menu, "New 4×4") : NULL;
        gboolean route_ready = layout_4x4 != NULL &&
            GPOINTER_TO_INT(g_object_get_data(
                G_OBJECT(layout_4x4), "noctty-workspace-event")) == 60;
        if (!route_ready) {
            if (root->layout_preset_smoke_attempts++ < 40) {
                if (root->layout_preset_smoke_attempts == 20)
                    (void)open_smoke_workspace_menu(active_grid_context(root));
                g_timeout_add(25, continue_layout_preset_smoke, root);
            } else {
                NocttyGridContext *remaining = active_grid_context(root);
                if (remaining != NULL && remaining->write != NULL)
                    (void)remaining->write(remaining->userdata, "exit 1\n", 7);
            }
            return G_SOURCE_REMOVE;
        }
        root->layout_preset_menu_survived = 1;
        root->layout_preset_smoke_attempts = 0;
        gtk_menu_shell_select_item(GTK_MENU_SHELL(menu), layout_4x4);
        gtk_menu_shell_activate_item(GTK_MENU_SHELL(menu), layout_4x4, TRUE);
        g_timeout_add(600, check_layout_preset_smoke, root);
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
        GPOINTER_TO_INT(g_object_get_data(
            G_OBJECT(layout_2x2), "noctty-workspace-event")) == 51 &&
        GPOINTER_TO_INT(g_object_get_data(
            G_OBJECT(layout_4x2), "noctty-workspace-event")) == 61 &&
        GPOINTER_TO_INT(g_object_get_data(
            G_OBJECT(layout_3x3), "noctty-workspace-event")) == 52 &&
        GPOINTER_TO_INT(g_object_get_data(
            G_OBJECT(layout_4x4), "noctty-workspace-event")) == 60;
    if (!routes_ready) {
        if (root->layout_preset_smoke_attempts++ < 40) {
            if (root->layout_preset_smoke_attempts == 20)
                (void)open_smoke_workspace_menu(active_grid_context(root));
            g_timeout_add(25, continue_layout_preset_smoke, root);
        } else {
            NocttyGridContext *remaining = active_grid_context(root);
            if (remaining != NULL && remaining->write != NULL)
                (void)remaining->write(remaining->userdata, "exit 1\n", 7);
        }
        return G_SOURCE_REMOVE;
    }
    root->layout_preset_menu_survived = 1;
    gtk_menu_shell_select_item(GTK_MENU_SHELL(menu), layout_4x2);
    gtk_menu_shell_activate_item(GTK_MENU_SHELL(menu), layout_4x2, TRUE);
    g_timeout_add(420, check_layout_preset_smoke, root);
    return G_SOURCE_REMOVE;
}

static gboolean apply_layout_preset_smoke_stage(gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    NocttyGridContext *target = active_grid_context(root);
    if (target == NULL || target->area == NULL) return G_SOURCE_REMOVE;
    int event_code = root->layout_preset_smoke_stage == 5
        ? 60 : root->layout_preset_smoke_stage == 4
        ? 52 : root->layout_preset_smoke_stage == 3
        ? 61 : root->layout_preset_smoke_stage == 2 ? 51 : 50;
    emit_grid_workspace_event(target, event_code);
    g_timeout_add(420, check_layout_preset_smoke, root);
    return G_SOURCE_REMOVE;
}

static gboolean request_layout_preset_smoke(gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    NocttyGridContext *target = active_grid_context(root);
    if (target == NULL || target->area == NULL) return G_SOURCE_REMOVE;
    root->layout_preset_smoke_attempts = 0;
    (void)open_smoke_workspace_menu(target);
    (void)on_window_focus_out(root->window, NULL, root);
    g_timeout_add(250, continue_layout_preset_smoke, root);
    return G_SOURCE_REMOVE;
}

static gboolean start_layout_preset_smoke(gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    root->layout_preset_churn_rounds = 0;
    root->layout_preset_finalizing = 0;
    root->layout_preset_smoke_stage =
        root->workspace_smoke == 43 ? 9 : 3;
    return request_layout_preset_smoke(root);
}

static gboolean handle_terminal_scrollbar_motion(
    NocttyGridContext *context, GtkWidget *widget, GdkEventMotion *event) {
    if (!context->scrollbar_dragging) return FALSE;
    GtkAllocation allocation;
    gtk_widget_get_allocation(widget, &allocation);
    NocttyTerminalScrollbarGeometry geometry;
    if (!terminal_scrollbar_geometry(context, allocation, &geometry))
        return TRUE;

    uint64_t target_offset = 0;
    if (noctty_grid_scrollbar_drag_target(
            &geometry, event->y, context->scrollbar_drag_offset,
            &target_offset) != 0 &&
        scroll_terminal_to_offset(context, target_offset))
        root_grid_context(context)->compact_scrollbar_thumb_dragged = 1;
    return TRUE;
}

static gboolean on_mouse_motion(GtkWidget *widget, GdkEventMotion *event, gpointer user_data) {
    NocttyGridContext *context = user_data;
    if (!grid_context_session_available(context) || context->exited)
        return FALSE;
    GtkAllocation allocation;
    gtk_widget_get_allocation(widget, &allocation);
    NocttyTerminalScrollbarGeometry scrollbar;
    gboolean scrollbar_hovered =
        terminal_scrollbar_geometry(context, allocation, &scrollbar) &&
        event->x >= scrollbar.x &&
        event->x <= scrollbar.x + scrollbar.width &&
        event->y >= scrollbar.thumb_y &&
        event->y <= scrollbar.thumb_y + scrollbar.thumb_height;
    if (context->scrollbar_hovered != scrollbar_hovered) {
        context->scrollbar_hovered = scrollbar_hovered;
        gtk_widget_queue_draw(context->area);
    }
    if (handle_terminal_scrollbar_motion(context, widget, event)) return TRUE;
    if (context->focus_follows_pointer && !(event->state & GDK_BUTTON1_MASK) &&
        !gtk_widget_has_focus(widget)) gtk_widget_grab_focus(widget);
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
    gtk_widget_queue_draw(context->area);
    return TRUE;
}

static gboolean on_grid_area_leave(GtkWidget *widget, GdkEventCrossing *event,
                                   gpointer user_data) {
    (void)widget;
    (void)event;
    NocttyGridContext *context = user_data;
    if (context->scrollbar_hovered) {
        context->scrollbar_hovered = 0;
        gtk_widget_queue_draw(context->area);
    }
    return FALSE;
}

static int terminal_scroll_steps(NocttyGridContext *context,
                                 GdkEventScroll *event) {
    return noctty_grid_scroll_steps(
        context->terminal_scroll_lines, context->terminal_smooth_scroll,
        noctty_grid_scroll_direction((int)event->direction), event->delta_y,
        &context->terminal_scroll_accumulator);
}

static gboolean report_terminal_mouse_wheel(
    NocttyGridContext *context, GdkEventScroll *event, int steps) {
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
            context, "The application did not accept mouse-wheel input.");
#if NOCTTY_ENABLE_SMOKE
    NocttyGridContext *root = root_grid_context(context);
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
    NocttyGridContext *context, int steps) {
    uint8_t sequence[192];
    int length = noctty_grid_wheel_key_sequence(
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
            context, "Could not deliver alternate-screen scroll input.");
    }
    return TRUE;
}

static gboolean on_scroll(GtkWidget *widget, GdkEventScroll *event, gpointer user_data) {
    NocttyGridContext *context = user_data;
    if (!grid_context_session_available(context) || context->exited)
        return FALSE;
    GtkAllocation allocation;
    gtk_widget_get_allocation(widget, &allocation);
    NocttyTerminalScrollbarGeometry scrollbar;
    gboolean scrollbar_owned =
        terminal_scrollbar_geometry(context, allocation, &scrollbar) &&
        event->x >= scrollbar.x;
    int terminal_mode_flags =
        scrollbar_owned ? 0 : context->mouse_mode(context->userdata);
    uint64_t history_lines = 0;
    uint64_t viewport_offset = 0;
    uint32_t visible_rows = 0;
    int history_available = 0;
    if (terminal_mode_flags & NOCTTY_GRID_TERMINAL_MODE_ALTERNATE_SCREEN) {
        if (noctty_grid_scroll_state(
                context->userdata, &history_lines, &viewport_offset,
                &visible_rows) == 0)
            history_available = history_lines > 0;
    }
    int route = noctty_grid_input_route(
        NOCTTY_GRID_INPUT_WHEEL, scrollbar_owned, terminal_mode_flags,
        history_available, 0, noctty_grid_input_modifiers(event->state));
    /* The native rail owns pointer events inside its visible hit target even
     * when the foreground TUI enables terminal mouse reporting. Otherwise
     * apps such as Codex consume the wheel before NOCTTY can move history. */
    if (route == NOCTTY_GRID_ROUTE_SCROLLBAR) {
        int steps = terminal_scroll_steps(context, event);
        if (steps != 0)
            (void)scroll_terminal_by_lines(context, steps);
        gtk_widget_queue_draw(context->area);
        return TRUE;
    }
    if (route == NOCTTY_GRID_ROUTE_TAB_CYCLE ||
        route == NOCTTY_GRID_ROUTE_PANE_CYCLE ||
        route == NOCTTY_GRID_ROUTE_FONT_ZOOM) {
        NocttyGridContext *root = root_grid_context(context);
        double *accumulator = route == NOCTTY_GRID_ROUTE_TAB_CYCLE
            ? &root->tab_cycle_scroll_accumulator
            : route == NOCTTY_GRID_ROUTE_PANE_CYCLE
                ? &root->pane_cycle_scroll_accumulator
                : &context->font_scroll_accumulator;
        NocttyGridWheelActionPlan plan;
        noctty_grid_wheel_action_plan(
            route, noctty_grid_scroll_direction((int)event->direction),
            event->delta_y, accumulator,
            &plan);
        if (route == NOCTTY_GRID_ROUTE_TAB_CYCLE) {
            for (int step = 0; step < plan.steps; step++) {
                (void)cycle_grid_tab(context, plan.direction);
                show_active_tab_cycle_feedback(root);
            }
        } else if (route == NOCTTY_GRID_ROUTE_PANE_CYCLE) {
            for (int step = 0; step < plan.steps; step++)
                (void)cycle_grid_pane(context, plan.direction);
        } else if (plan.steps != 0) {
            (void)apply_pane_font_size(
                context,
                context->requested_font_size + plan.steps * plan.direction,
                TRUE);
        }
        return TRUE;
    }
    int steps = terminal_scroll_steps(context, event);
    if (route == NOCTTY_GRID_ROUTE_TERMINAL_SCROLL) {
        if (steps != 0)
            (void)scroll_terminal_by_lines(context, steps);
        if (context->workspace_smoke == 15 && steps != 0)
            root_grid_context(context)->compact_plain_scroll_preserved = 1;
        gtk_widget_queue_draw(context->area);
        return TRUE;
    }
    if (route == NOCTTY_GRID_ROUTE_APPLICATION_MOUSE)
        return report_terminal_mouse_wheel(context, event, steps);
    if (route == NOCTTY_GRID_ROUTE_APPLICATION_KEYS)
        return report_terminal_wheel_keys(context, steps);
    return TRUE;
}

static GtkTargetEntry noctty_pane_drag_targets[] = {{"application/x-noctty-pane", GTK_TARGET_SAME_APP, 0}};

static void on_pane_drag_data_get(GtkWidget *widget, GdkDragContext *drag, GtkSelectionData *selection, guint info, guint time, gpointer user_data) {
    (void)widget; (void)drag; (void)info; (void)time;
    NocttyGridContext *context = user_data;
    if (!grid_context_session_available(context) || context->exited) return;
    char pane[32];
    int length = g_snprintf(pane, sizeof(pane), "%" G_GUINT64_FORMAT, context->pane_id);
    gtk_selection_data_set_text(selection, pane, length);
}

static void on_pane_drag_data_received(GtkWidget *widget, GdkDragContext *drag, gint x, gint y, GtkSelectionData *selection, guint info, guint time, gpointer user_data) {
    (void)widget; (void)x; (void)y; (void)info;
    NocttyGridContext *context = user_data;
    gboolean moved = FALSE;
    if (!grid_context_session_available(context) || context->exited) {
        gtk_drag_finish(drag, FALSE, FALSE, time);
        return;
    }
    gchar *text = (gchar *)gtk_selection_data_get_text(selection);
    if (text != NULL) {
        guint64 source_pane = g_ascii_strtoull(text, NULL, 10);
        NocttyGridContext *source =
            grid_context_for_pane(context, source_pane);
        if (source_pane > 0 && source_pane <= G_MAXINT &&
            source != NULL && source->page != context->page) {
            if (context->event != NULL) {
                context->event(context->event_data, context->pane_id, 55,
                               (int)source_pane,
                               (uint64_t)(g_get_monotonic_time() / 1000));
            }
            moved = move_grid_context(source, context);
        }
        g_free(text);
    }
    gtk_drag_finish(drag, moved, moved, time);
}

static gboolean arm_resize_overlay(gpointer user_data) {
    NocttyGridContext *context = user_data;
    context->resize_overlay_arm_source = 0;
    context->resize_overlay_armed = 1;
    if (context->resize_overlay_zoom_percent > 0 &&
        context->resize_overlay_zoom_percent < 100)
        show_resize_overlay(context, context->columns, context->rows);
    return G_SOURCE_REMOVE;
}

static gboolean hide_resize_overlay(gpointer user_data) {
    NocttyGridContext *context = user_data;
    context->resize_overlay_hide_source = 0;
    context->resize_overlay_visible = 0;
    context->resize_overlay_hidden = 1;
    if (context->area != NULL) gtk_widget_queue_draw(context->area);
    return G_SOURCE_REMOVE;
}

static void show_resize_overlay(NocttyGridContext *context,
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
    if (context->resize_overlay_hide_source != 0)
        g_source_remove(context->resize_overlay_hide_source);
    context->resize_overlay_hide_source =
        g_timeout_add(750, hide_resize_overlay, context);
    gtk_widget_queue_draw(context->area);
}

static gboolean commit_grid_resize(gpointer user_data) {
    NocttyGridContext *context = user_data;
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

static void resize_grid_to_allocation(NocttyGridContext *context,
                                      GtkAllocation *allocation) {
    if (!grid_context_session_available(context) || context->exited) return;

    double base_size = context->requested_font_size > 0
        ? context->requested_font_size : context->font_size;
    double next_size = base_size;
    int zoom_percent = 100;
    int floor_reached = 0;
    int fit_width = allocation->width;
    int fit_height = allocation->height;
    NocttyGridContext *root = root_grid_context(context);
    int auto_fit_enabled = root->workspace_smoke == 21 &&
        context->page != NULL &&
        grid_contexts_on_page(root, context->page) >= 4 &&
        allocation->width > 0 && allocation->height > 0;
    if (auto_fit_enabled) {
        for (guint index = 0; root->contexts != NULL &&
             index < root->contexts->len; index++) {
            NocttyGridContext *candidate =
                g_ptr_array_index(root->contexts, index);
            if (!candidate->active || candidate->exited ||
                candidate->page != context->page || candidate->area == NULL)
                continue;
            GtkAllocation candidate_allocation;
            gtk_widget_get_allocation(candidate->area, &candidate_allocation);
            if (candidate_allocation.width > 1)
                fit_width = MIN(fit_width, candidate_allocation.width);
            if (candidate_allocation.height > 1)
                fit_height = MIN(fit_height, candidate_allocation.height);
        }
    }
    noctty_grid_auto_fit(
        base_size, fit_width, fit_height, auto_fit_enabled, &next_size,
        &zoom_percent, &floor_reached);
    context->resize_overlay_floor_reached = floor_reached;
    gboolean font_changed = fabs(context->font_size - next_size) > 0.01;
    if (font_changed) {
        for (guint index = 0; root->contexts != NULL &&
             index < root->contexts->len; index++) {
            NocttyGridContext *candidate =
                g_ptr_array_index(root->contexts, index);
            if (!candidate->active || candidate->exited ||
                candidate->page != context->page || candidate->area == NULL)
                continue;
            candidate->font_size = next_size;
            candidate->resize_overlay_zoom_percent = zoom_percent;
            clear_ascii_glyph_cache(candidate);
            gtk_widget_queue_draw(candidate->area);
        }
    }
    context->resize_overlay_zoom_percent = zoom_percent;

    int terminal_width = 0;
    int columns = 0;
    int rows = 0;
    NocttyGridFontMetrics metrics = grid_font_metrics(context);
    if (!noctty_grid_dimensions(
            allocation->width, allocation->height,
            NOCTTY_TERMINAL_SCROLLBAR_WIDTH_PX, metrics.cell_width,
            metrics.cell_height, &terminal_width, &columns, &rows))
        return;
    if (columns == context->columns && rows == context->rows) {
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
            G_PRIORITY_DEFAULT, 75, commit_grid_resize, context, NULL);
}

static void on_size_allocate(GtkWidget *widget, GtkAllocation *allocation, gpointer user_data) {
    NocttyGridContext *context = user_data;
    /* Reparenting can emit transient 1x1 allocations that must not reach the PTY. */
    if (!gtk_widget_get_mapped(widget)) {
        root_grid_context(context)->unmapped_resize_suppressed++;
        return;
    }
    resize_grid_to_allocation(context, allocation);
}



static void on_window_resize_handle_realize(GtkWidget *widget,
                                            gpointer user_data) {
    (void)user_data;
    int index = noctty_grid_resize_handle_index(GPOINTER_TO_INT(
        g_object_get_data(G_OBJECT(widget), "noctty-resize-index")));
    if (index < 0 || index >= 8) return;
    GdkWindow *window = gtk_widget_get_window(widget);
    if (window == NULL) return;
    GdkDisplay *display = gtk_widget_get_display(widget);
    GdkCursor *cursor = gdk_cursor_new_from_name(
        display, noctty_grid_window_resize_cursor_name(index));
    if (cursor == NULL)
        cursor = gdk_cursor_new_for_display(
            display,
            g_strcmp0(noctty_grid_window_resize_cursor_name(index), "ew-resize") == 0
                ? GDK_SB_H_DOUBLE_ARROW : GDK_SB_V_DOUBLE_ARROW);
    if (cursor == NULL) return;
    gdk_window_set_cursor(window, cursor);
    g_object_set_data(G_OBJECT(widget), "noctty-resize-cursor-name",
                      (gpointer)noctty_grid_window_resize_cursor_name(index));
    g_object_unref(cursor);
}

static void finish_window_resize_drag(NocttyGridContext *root) {
    int index = root->window_resize_drag_handle;
    gboolean commit_dropdown_size =
        root->window_resize_drag_active && root->mode == 0;
    root->window_resize_drag_active = 0;
    if (index >= 0 && index < 8 &&
        gtk_widget_has_grab(root->window_resize_handles[index]))
        gtk_grab_remove(root->window_resize_handles[index]);
    if (commit_dropdown_size && !root->layer_shell_active) {
        int width = 0;
        int height = 0;
        gtk_window_get_size(GTK_WINDOW(root->window), &width, &height);
        sync_compact_setting(root, 14, width);
        sync_compact_setting(root, 15, height);
    }
    if (commit_dropdown_size &&
        normalize_dropdown_pixel_dimensions(root, TRUE))
        apply_dropdown_dimensions(root);
}

static gboolean begin_window_resize_drag(GtkWidget *widget,
                                           NocttyGridContext *root,
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
    gtk_window_get_size(GTK_WINDOW(root->window),
                        &root->window_resize_drag_start_width,
                        &root->window_resize_drag_start_height);
    root->window_resize_drag_start_width_percent =
        root->dropdown_width_percent;
    root->window_resize_drag_start_height_percent =
        root->dropdown_height_percent;
    if (!root->layer_shell_active) {
        gtk_window_begin_resize_drag(
            GTK_WINDOW(root->window), (GdkWindowEdge)noctty_grid_resize_edge(index),
            (gint)button, (gint)x_root, (gint)y_root, time);
        return TRUE;
    }
    gtk_grab_add(widget);
    return TRUE;
}

static void cancel_dragger_double_click_timer(NocttyGridContext *root) {
    if (root->dragger_double_click_source == 0) return;
    g_source_remove(root->dragger_double_click_source);
    root->dragger_double_click_source = 0;
}

static gboolean toggle_dragger_height(NocttyGridContext *root) {
    int maximized = root->dropdown_height_percent >= 95;
    int target_height = maximized ? 50 : 100;
    cancel_dragger_double_click_timer(root);
    root->dragger_height_toggled = !maximized;
    root->dragger_click_pending = 0;
    root->dragger_last_press_time = 0;
    finish_window_resize_drag(root);
    sync_compact_setting(root, 1, target_height);
    sync_compact_setting(root, 15, 0);
    apply_dropdown_dimensions(root);
    if (root->event != NULL)
        root->event(root->event_data, root->pane_id, 77,
                    target_height,
                    (uint64_t)(g_get_monotonic_time() / 1000));
    return TRUE;
}

static gboolean finish_dragger_click_fallback(gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
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
    NocttyGridContext *root = root_grid_context(user_data);
    int index = noctty_grid_resize_handle_index(GPOINTER_TO_INT(
        g_object_get_data(G_OBJECT(widget), "noctty-resize-index")));
    if (index < 0 || index >= 8 || event->button != 1 || root->mode == 2)
        return FALSE;

    if (index == 6 && root->mode == 0) {
        if (event->type == GDK_2BUTTON_PRESS)
            return toggle_dragger_height(root);
        if (event->type == GDK_BUTTON_PRESS) {
            gboolean within_double_click = root->dragger_click_pending == 1 &&
                (event->time - root->dragger_last_press_time) <= 500;
            if (within_double_click) {
                // GTK may deliver this press immediately before the
                // GDK_2BUTTON_PRESS. Wait briefly so one physical double
                // click cannot toggle twice; retain a fallback for backends
                // that expose only ordinary button presses.
                root->dragger_click_pending = 2;
                cancel_dragger_double_click_timer(root);
                root->dragger_double_click_source = g_timeout_add(
                    75, finish_dragger_click_fallback, root);
                return TRUE;
            }
            // Do not start a resize until motion proves this is a drag. This
            // leaves the second click free to be the height toggle.
            cancel_dragger_double_click_timer(root);
            root->dragger_click_pending = 1;
            root->dragger_last_press_time = event->time;
            root->window_resize_drag_start_x = event->x_root;
            root->window_resize_drag_start_y = event->y_root;
            root->dragger_double_click_source = g_timeout_add(
                500, finish_dragger_click_fallback, root);
            return TRUE;
        }
        return FALSE;
    }
    if (event->type != GDK_BUTTON_PRESS) return FALSE;
    return begin_window_resize_drag(widget, root, index, event->button,
                                    event->x_root, event->y_root,
                                    event->time);
}

static gboolean on_window_resize_handle_motion(GtkWidget *widget,
                                                GdkEventMotion *event,
                                                gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    if (!root->window_resize_drag_active &&
        noctty_grid_resize_handle_index(GPOINTER_TO_INT(
            g_object_get_data(G_OBJECT(widget), "noctty-resize-index"))) == 6 && root->mode == 0 &&
        root->dragger_click_pending == 1 && (event->state & GDK_BUTTON1_MASK)) {
        double delta_x = event->x_root - root->window_resize_drag_start_x;
        double delta_y = event->y_root - root->window_resize_drag_start_y;
        if (delta_x * delta_x + delta_y * delta_y >= 16.0) {
            cancel_dragger_double_click_timer(root);
            root->dragger_click_pending = 0;
            return begin_window_resize_drag(
                widget, root, 6, 1, root->window_resize_drag_start_x,
                root->window_resize_drag_start_y, event->time);
        }
        return TRUE;
    }
    if (!root->window_resize_drag_active) return FALSE;
    if (!(event->state & GDK_BUTTON1_MASK)) {
        finish_window_resize_drag(root);
        return FALSE;
    }
    int index = root->window_resize_drag_handle;
    GdkMonitor *monitor = grid_monitor_for_window(root->window);
    GdkRectangle geometry = {0, 0, 900, 420};
    if (monitor != NULL) gdk_monitor_get_geometry(monitor, &geometry);

    double horizontal = 0.0;
    double vertical = 0.0;
    noctty_grid_resize_delta(
        index, root->window_resize_drag_start_x,
        root->window_resize_drag_start_y, event->x_root, event->y_root,
        &horizontal, &vertical);

    if (root->mode == 1 && root->layer_shell_active) {
        int width = noctty_grid_clamp_resize(
            root->window_resize_drag_start_width, horizontal, 320, G_MAXINT);
        int height = noctty_grid_clamp_resize(
            root->window_resize_drag_start_height, vertical, 180, G_MAXINT);
        gtk_widget_set_size_request(root->window, width, height);
        gtk_window_resize(GTK_WINDOW(root->window), width, height);
        return TRUE;
    }
    if (root->mode != 0) return FALSE;
    int width = noctty_grid_clamp_resize(
        root->window_resize_drag_start_width, horizontal,
        MIN(NOCTTY_DROPDOWN_MIN_WIDTH_PX, geometry.width), geometry.width);
    int height = noctty_grid_clamp_resize(
        root->window_resize_drag_start_height, vertical,
        MIN(NOCTTY_DROPDOWN_MIN_HEIGHT_PX, geometry.height), geometry.height);
    gboolean changed = FALSE;
    if (horizontal != 0.0 && width != root->dropdown_width_px) {
        sync_compact_setting(root, 14, width);
        changed = TRUE;
    }
    if (vertical != 0.0 && height != root->dropdown_height_px) {
        sync_compact_setting(root, 15, height);
        changed = TRUE;
    }
    if (changed) apply_dropdown_dimensions(root);
    return TRUE;
}

static gboolean on_window_resize_handle_release(GtkWidget *widget,
                                                 GdkEventButton *event,
                                                 gpointer user_data) {
    (void)widget;
    NocttyGridContext *root = root_grid_context(user_data);
    if (!root->window_resize_drag_active || event->button != 1) return FALSE;
    finish_window_resize_drag(root);
    NocttyGridContext *focus_target = active_grid_context(root);
    if (focus_target->area != NULL)
        gtk_widget_grab_focus(focus_target->area);
    return TRUE;
}

static GtkWidget *create_window_resize_handle(NocttyGridContext *context,
                                              int index, int width,
                                              int height) {
    GtkWidget *handle = gtk_event_box_new();
    gtk_event_box_set_visible_window(GTK_EVENT_BOX(handle), FALSE);
    gtk_event_box_set_above_child(GTK_EVENT_BOX(handle), TRUE);
    gtk_widget_set_size_request(handle, width, height);
    gtk_widget_set_hexpand(handle, width < 0);
    gtk_widget_set_vexpand(handle, height < 0);
    gtk_widget_set_tooltip_text(
        handle,
        index == 6
            ? "Drag to resize; double-click to maximize / minimize height"
            : "Drag to resize NOCTTY");
    gtk_widget_set_no_show_all(handle, TRUE);
    gtk_widget_add_events(handle, GDK_BUTTON_PRESS_MASK |
        GDK_BUTTON_RELEASE_MASK | GDK_POINTER_MOTION_MASK);
    g_object_set_data(G_OBJECT(handle), "noctty-resize-index",
                      GINT_TO_POINTER(index + 1));
    g_object_set_data(G_OBJECT(handle), "noctty-resize-cursor-name",
                      (gpointer)noctty_grid_window_resize_cursor_name(index));
    g_signal_connect(handle, "realize",
                     G_CALLBACK(on_window_resize_handle_realize), context);
    g_signal_connect(handle, "button-press-event",
                     G_CALLBACK(on_window_resize_handle_button), context);
    g_signal_connect(handle, "button-release-event",
                     G_CALLBACK(on_window_resize_handle_release), context);
    g_signal_connect(handle, "motion-notify-event",
                     G_CALLBACK(on_window_resize_handle_motion), context);
    context->window_resize_handles[index] = handle;
    context->window_resize_handle_count++;
    return handle;
}

static GtkWidget *create_window_resize_layout(NocttyGridContext *context,
                                              GtkWidget *content) {
    GtkWidget *layout = gtk_grid_new();
    gtk_widget_set_hexpand(layout, TRUE);
    gtk_widget_set_vexpand(layout, TRUE);
    gtk_widget_set_hexpand(content, TRUE);
    gtk_widget_set_vexpand(content, TRUE);
    int border_px = context->window_border_px;
    int dragger_px = context->dragger_px;
    for (int index = 0; index < 8; index++) {
        NocttyGridResizeHandleLayout handle_layout = {0};
        if (noctty_grid_resize_handle_layout(
                index, border_px, dragger_px, &handle_layout) == 0)
            continue;
        GtkWidget *handle = create_window_resize_handle(
            context, index, handle_layout.width, handle_layout.height);
        if (index != 6)
            gtk_grid_attach(GTK_GRID(layout), handle, handle_layout.column,
                            handle_layout.row, 1, 1);
    }
    context->resize_grip = context->window_resize_handles[6];
    gtk_grid_attach(GTK_GRID(layout), content, 1, 1, 1, 1);
    GtkWidget *overlay = gtk_overlay_new();
    gtk_container_add(GTK_CONTAINER(overlay), layout);
    gtk_widget_set_halign(context->resize_grip, GTK_ALIGN_FILL);
    gtk_widget_set_valign(context->resize_grip, GTK_ALIGN_END);
    gtk_overlay_add_overlay(GTK_OVERLAY(overlay), context->resize_grip);
    return overlay;
}

static void update_window_resize_handles(NocttyGridContext *context) {
    NocttyGridContext *root = root_grid_context(context);
    int dragger_px = root->dragger_px;
    if (root->resize_grip != NULL)
        gtk_widget_set_size_request(root->resize_grip, -1, dragger_px);
    for (int index = 0; index < 8; index++) {
        GtkWidget *handle = root->window_resize_handles[index];
        if (handle == NULL || index == 6) continue;
        NocttyGridResizeHandleLayout handle_layout = {0};
        if (noctty_grid_resize_handle_layout(
                index, root->window_border_px, dragger_px, &handle_layout) == 0)
            continue;
        gtk_widget_set_size_request(handle, handle_layout.width,
                                    handle_layout.height);
    }
    int visible = 0;
    for (int index = 0; index < 8; index++) {
        GtkWidget *handle = root->window_resize_handles[index];
        if (handle == NULL) continue;
        gboolean cardinal = index == 1 || index == 3 ||
            index == 4 || index == 6;
        gboolean show = cardinal && root->mode == 0 && index != 1;
        if (show) {
            gtk_widget_show(handle);
            visible++;
        } else {
            gtk_widget_hide(handle);
        }
    }
    root->window_resize_affordance_ready =
        (root->mode == 1 && visible == 0 &&
         gtk_window_get_decorated(GTK_WINDOW(root->window)) &&
         gtk_window_get_resizable(GTK_WINDOW(root->window))) ||
        (root->mode == 0 && visible == 3);
    gtk_window_set_resizable(GTK_WINDOW(root->window), TRUE);
}

static gboolean check_window_resize_smoke(gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    int width = 0;
    int height = 0;
    gtk_window_get_size(GTK_WINDOW(root->window), &width, &height);
    root->window_resize_geometry_changed =
        width > root->window_resize_initial_width &&
        height > root->window_resize_initial_height;
    if (root->workspace_smoke == 19 && root->tray_bus != NULL &&
        root->tray_watcher_registered) {
        const char *unique_name = g_dbus_connection_get_unique_name(
            root->tray_bus);
        if (unique_name != NULL)
            (void)g_file_set_contents(
                "/tmp/noctty-native-grid-window-tray-ready",
                unique_name, -1, NULL);
    }
    return G_SOURCE_REMOVE;
}

static gboolean request_window_resize_smoke(gpointer user_data) {
    NocttyGridContext *root = root_grid_context(user_data);
    gtk_window_get_size(GTK_WINDOW(root->window),
                        &root->window_resize_initial_width,
                        &root->window_resize_initial_height);
    gboolean custom_handles_hidden = root->window_resize_handle_count == 8;
    for (int index = 0; index < 8; index++) {
        GtkWidget *handle = root->window_resize_handles[index];
        custom_handles_hidden = custom_handles_hidden && handle != NULL &&
            !gtk_widget_get_visible(handle);
    }
    root->window_native_decorated =
        gtk_window_get_decorated(GTK_WINDOW(root->window));
    root->window_native_resizable =
        gtk_window_get_resizable(GTK_WINDOW(root->window));
    root->window_resize_affordance_ready =
        custom_handles_hidden && root->window_native_decorated &&
        root->window_native_resizable;
    gtk_window_resize(GTK_WINDOW(root->window),
                      root->window_resize_initial_width + 120,
                      root->window_resize_initial_height + 80);
    g_timeout_add(500, check_window_resize_smoke, root);
    return G_SOURCE_REMOVE;
}

static void on_im_commit(GtkIMContext *im_context, const gchar *text,
                         gpointer user_data) {
    (void)im_context;
    NocttyGridContext *context = user_data;
    if (grid_context_session_available(context) && !context->exited &&
        text != NULL && text[0] != '\0' &&
        deliver_grid_input(context, text, strlen(text)) < 0)
        show_status_feedback(
            context, "Could not deliver composed text to every terminal.");
}

static void on_grid_area_realize(GtkWidget *widget, gpointer user_data) {
    NocttyGridContext *context = user_data;
    GdkWindow *window = gtk_widget_get_window(widget);
    if (window != NULL) {
        GdkDisplay *display = gtk_widget_get_display(widget);
        GdkCursor *cursor = gdk_cursor_new_from_name(display, "text");
        if (cursor == NULL)
            cursor = gdk_cursor_new_for_display(display, GDK_XTERM);
        if (cursor != NULL) {
            gdk_window_set_cursor(window, cursor);
            g_object_unref(cursor);
            g_object_set_data(G_OBJECT(widget), "noctty-cursor-name",
                              (gpointer)"text");
        }
    }
    if (context->im_context != NULL)
        gtk_im_context_set_client_window(context->im_context,
                                         window);
}

static void on_grid_area_unrealize(GtkWidget *widget, gpointer user_data) {
    (void)widget;
    NocttyGridContext *context = user_data;
    if (context->im_context != NULL)
        gtk_im_context_set_client_window(context->im_context, NULL);
}

static void on_grid_area_map(GtkWidget *widget, gpointer user_data) {
    NocttyGridContext *context = user_data;
    GtkAllocation allocation;
    gtk_widget_get_allocation(widget, &allocation);
    resize_grid_to_allocation(context, &allocation);
    context->damage_initialized = 0;
    queue_grid_damage_when_mapped(context);
}

static void connect_grid_area(NocttyGridContext *context) {
    context->resize_overlay_initial_suppressed = 1;
    gtk_style_context_add_class(gtk_widget_get_style_context(context->area),
                                "noctty-grid-area");
    gtk_widget_set_can_focus(context->area, TRUE);
    g_object_set_data(
        G_OBJECT(context->area), "noctty-grid-context", context);
    AtkObject *accessible = gtk_widget_get_accessible(context->area);
    if (accessible != NULL) {
        char name[64];
        g_snprintf(name, sizeof(name), "Terminal pane %" G_GUINT64_FORMAT,
                   context->pane_id);
        atk_object_set_name(accessible, name);
    }
    g_signal_connect(context->area, "draw", G_CALLBACK(on_draw), context);
    g_signal_connect(context->area, "key-press-event", G_CALLBACK(on_key_press), context);
    g_signal_connect(context->area, "key-release-event",
                     G_CALLBACK(on_key_release), context);
    g_signal_connect(context->area, "focus-in-event", G_CALLBACK(on_focus_in), context);
    g_signal_connect(context->area, "focus-out-event", G_CALLBACK(on_focus_out), context);
    g_signal_connect(context->area, "button-press-event", G_CALLBACK(on_mouse_button), context);
    g_signal_connect(context->area, "button-release-event", G_CALLBACK(on_mouse_button), context);
    g_signal_connect(context->area, "motion-notify-event", G_CALLBACK(on_mouse_motion), context);
    g_signal_connect(context->area, "leave-notify-event",
                     G_CALLBACK(on_grid_area_leave), context);
    g_signal_connect(context->area, "scroll-event", G_CALLBACK(on_scroll), context);
    g_signal_connect(context->area, "size-allocate", G_CALLBACK(on_size_allocate), context);
    g_signal_connect(context->area, "map", G_CALLBACK(on_grid_area_map), context);
    g_signal_connect(context->area, "realize", G_CALLBACK(on_grid_area_realize), context);
    g_signal_connect(context->area, "unrealize", G_CALLBACK(on_grid_area_unrealize), context);
    if (context->im_context != NULL)
        g_signal_connect(context->im_context, "commit", G_CALLBACK(on_im_commit), context);
    gtk_widget_add_events(context->area,
                          GDK_KEY_PRESS_MASK | GDK_KEY_RELEASE_MASK |
                          GDK_BUTTON_PRESS_MASK | GDK_BUTTON_RELEASE_MASK |
                          GDK_SCROLL_MASK | GDK_POINTER_MOTION_MASK |
                          GDK_LEAVE_NOTIFY_MASK);
    gtk_drag_source_set(context->area, GDK_BUTTON2_MASK, noctty_pane_drag_targets, 1, GDK_ACTION_MOVE);
    gtk_drag_dest_set(context->area, GTK_DEST_DEFAULT_ALL, noctty_pane_drag_targets, 1, GDK_ACTION_MOVE);
    g_signal_connect(context->area, "drag-data-get", G_CALLBACK(on_pane_drag_data_get), context);
    g_signal_connect(context->area, "drag-data-received", G_CALLBACK(on_pane_drag_data_received), context);
    context->resize_overlay_arm_source =
        g_timeout_add(250, arm_resize_overlay, context);
}

int noctty_native_grid_host_run_v2(const NocttyGridCallbacks *callbacks,
                                   const NocttyGridLaunchOptions *options) {
    if (callbacks == NULL || options == NULL ||
        callbacks->abi_version != NOCTTY_NATIVE_GRID_ABI_VERSION ||
        options->abi_version != NOCTTY_NATIVE_GRID_ABI_VERSION ||
        callbacks->struct_size < sizeof(*callbacks) ||
        options->struct_size < sizeof(*options) ||
        callbacks->pump == NULL || callbacks->write == NULL ||
        callbacks->cell == NULL || callbacks->row == NULL ||
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
                   NOCTTY_NATIVE_GRID_ABI_VERSION,
                   callbacks != NULL ? callbacks->abi_version : 0,
                   options != NULL ? options->abi_version : 0,
                   callbacks != NULL ? callbacks->struct_size : 0,
                   sizeof(*callbacks),
                   options != NULL ? options->struct_size : 0,
                   sizeof(*options));
        return -4;
    }
    void *userdata = callbacks->userdata;
    NocttyGridPump pump = callbacks->pump;
    NocttyGridWrite write = callbacks->write;
    NocttyGridCell cell = callbacks->cell;
    NocttyGridPollExit poll_exit = callbacks->poll_exit;
    NocttyGridResize resize = callbacks->resize;
    NocttyGridMouse mouse = callbacks->mouse;
    NocttyGridPaste paste = callbacks->paste;
    NocttyGridCopy copy = callbacks->copy;
    NocttyGridScroll scroll = callbacks->scroll;
    NocttyGridCursor cursor = callbacks->cursor;
    NocttyGridTitle title = callbacks->title;
    NocttyGridCursorMode cursor_mode = callbacks->cursor_mode;
    NocttyGridMouseMode mouse_mode = callbacks->mouse_mode;
    NocttyGridFocus focus = callbacks->focus;
    NocttyGridEvent event = callbacks->event;
    NocttyGridTextAction text_action = callbacks->text_action;
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
#if !NOCTTY_ENABLE_SMOKE
    if (workspace_smoke >= 0) return -3;
    workspace_smoke = -1;
#endif
    g_set_prgname("com.noctty.NOCTTY");
    g_set_application_name("NOCTTY");
    if (!gtk_init_check(NULL, NULL)) {
        g_printerr("native_grid_gtk_init_failed display=%s wayland_display=%s gdk_backend=%s\n",
                   g_getenv("DISPLAY") != NULL ? g_getenv("DISPLAY") : "",
                   g_getenv("WAYLAND_DISPLAY") != NULL ? g_getenv("WAYLAND_DISPLAY") : "",
                   g_getenv("GDK_BACKEND") != NULL ? g_getenv("GDK_BACKEND") : "");
        return -1;
    }
    gtk_window_set_default_icon_name("com.noctty.NOCTTY");
    NocttyGridContext context = {0};
    NocttyGridContext secondary = {0};
    context.root = &context;
    context.dbus_cancellable = g_cancellable_new();
    context.userdata = userdata;
    context.pump = pump;
    context.write = write;
    context.cell = cell;
    context.row = callbacks->row;
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
    context.create_session = event_data != NULL ? noctty_grid_create_session : NULL;
    context.mode = mode;
    context.dropdown_width_percent = event_data != NULL ? noctty_grid_compact_setting(event_data, 0) : 96;
    context.dropdown_height_percent = event_data != NULL ? noctty_grid_compact_setting(event_data, 1) : 55;
    context.dropdown_width_px = event_data != NULL ? noctty_grid_compact_setting(event_data, 14) : 0;
    context.dropdown_height_px = event_data != NULL ? noctty_grid_compact_setting(event_data, 15) : 0;
    context.dropdown_animation_ms = event_data != NULL ? noctty_grid_compact_setting(event_data, 2) : 120;
    context.hide_on_focus_loss = event_data != NULL ? noctty_grid_compact_setting(event_data, 3) : 1;
    context.focus_follows_pointer = event_data != NULL ? noctty_grid_compact_setting(event_data, 4) : 0;
    context.background_translucency = event_data != NULL
        ? noctty_grid_compact_setting(event_data, 16) : 1;
    context.background_opacity_percent = event_data != NULL
        ? noctty_grid_compact_setting(event_data, 17) : 92;
    context.background_opacity_percent =
        noctty_grid_background_opacity_value(
            context.background_opacity_percent);
    context.terminal_scroll_lines =
        noctty_grid_terminal_scroll_setting(
            117, context.terminal_scroll_lines);
    context.terminal_smooth_scroll = event_data != NULL
        ? noctty_grid_compact_setting(event_data, 19) : 1;
    context.panel_padding_px = event_data != NULL
        ? noctty_grid_compact_setting(event_data, 20) : 6;
    context.pane_spacing_px = event_data != NULL
        ? noctty_grid_compact_setting(event_data, 21) : 4;
    context.pane_gaps_enabled = event_data != NULL
        ? noctty_grid_compact_setting(event_data, 30) : 1;
    context.pane_gaps_transparent = event_data != NULL
        ? noctty_grid_compact_setting(event_data, 31) : 1;
    context.inactive_pane_dim_enabled = event_data != NULL
        ? noctty_grid_compact_setting(event_data, 32) : 1;
    context.inactive_pane_brightness_percent = event_data != NULL
        ? noctty_grid_compact_setting(event_data, 33) : 70;
    context.pane_divider_px = event_data != NULL
        ? noctty_grid_compact_setting(event_data, 22) : 1;
    context.pane_border_px = event_data != NULL
        ? noctty_grid_compact_setting(event_data, 23) : 1;
    context.pane_border_focused_px = event_data != NULL
        ? noctty_grid_compact_setting(event_data, 24) : 1;
    context.pane_border_selected_px = event_data != NULL
        ? noctty_grid_compact_setting(event_data, 25) : 2;
    context.status_border_px = event_data != NULL
        ? noctty_grid_compact_setting(event_data, 26) : 1;
    context.overlay_border_px = event_data != NULL
        ? noctty_grid_compact_setting(event_data, 27) : 1;
    context.window_border_px = event_data != NULL
        ? noctty_grid_compact_setting(event_data, 28) : 2;
    context.dragger_px = event_data != NULL
        ? noctty_grid_compact_setting(event_data, 29) : 2;
    context.panel_padding_px =
        noctty_grid_panel_metric_value(46, context.panel_padding_px);
    context.pane_spacing_px =
        noctty_grid_panel_metric_value(47, context.pane_spacing_px);
    context.inactive_pane_brightness_percent =
        noctty_grid_panel_metric_value(
            130, context.inactive_pane_brightness_percent);
    context.pane_divider_px =
        noctty_grid_panel_metric_value(119, context.pane_divider_px);
    context.pane_border_px =
        noctty_grid_panel_metric_value(120, context.pane_border_px);
    context.pane_border_focused_px =
        noctty_grid_panel_metric_value(121, context.pane_border_focused_px);
    context.pane_border_selected_px =
        noctty_grid_panel_metric_value(122, context.pane_border_selected_px);
    context.status_border_px =
        noctty_grid_panel_metric_value(123, context.status_border_px);
    context.overlay_border_px =
        noctty_grid_panel_metric_value(124, context.overlay_border_px);
    context.window_border_px =
        noctty_grid_panel_metric_value(125, context.window_border_px);
    context.dragger_px =
        noctty_grid_panel_metric_value(126, context.dragger_px);
    context.show_pane_info = event_data != NULL ? noctty_grid_compact_setting(event_data, 9) : 1;
    context.compact_tab_height = event_data != NULL ? noctty_grid_compact_setting(event_data, 5) : 16;
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
    context.font_size = event_data != NULL
        ? noctty_grid_compact_setting(event_data, 6) / 100.0
        : 13.0;
    context.font_min_size = event_data != NULL
        ? noctty_grid_compact_setting(event_data, 7) / 100.0
        : 7.0;
    context.font_max_size = event_data != NULL
        ? noctty_grid_compact_setting(event_data, 8) / 100.0
        : 28.0;
    if (context.font_min_size <= 0.0) context.font_min_size = 7.0;
    if (context.font_max_size < context.font_min_size)
        context.font_max_size = 28.0;
    context.font_size = noctty_grid_font_size_clamp(
        context.font_size, context.font_min_size, context.font_max_size);
    context.requested_font_size = context.font_size;
    context.font_family = g_strdup("monospace");
    context.font_antialias = event_data != NULL
        ? noctty_grid_compact_setting(event_data, 11) : 2;
    context.font_hinting = event_data != NULL
        ? noctty_grid_compact_setting(event_data, 12) : 1;
    context.ligatures = 1;
    context.profile_preset = -1;
    context.cursor_visible = 1;
    context.last_cursor_position = UINT32_MAX;
    context.focused = 1;
    context.window_presented = 1;
    context.columns = columns;
    context.rows = rows;
    context.last_bell_serial = noctty_grid_bell_serial(userdata);
    context.last_notification_serial =
        noctty_grid_notification_serial(userdata);
    context.window = create_grid_toplevel(&context);
    context.area = noctty_terminal_area_new();
    context.im_context = gtk_im_multicontext_new();
    context.contexts = g_ptr_array_new();
    g_ptr_array_add(context.contexts, &context);
    (void)sync_grid_context_profile(&context);
    if (secondary_userdata != NULL) {
        inherit_grid_session_context(&secondary, &context);
        secondary.font_family = g_strdup(
            context.font_family != NULL ? context.font_family : "monospace");
        secondary.userdata = secondary_userdata;
        secondary.last_bell_serial = noctty_grid_bell_serial(secondary_userdata);
        secondary.last_notification_serial =
            noctty_grid_notification_serial(secondary_userdata);
        secondary.pane_id = secondary_pane_id;
        secondary.profile_preset = -1;
        secondary.primary = 0;
        secondary.active = secondary_initially_active;
        secondary.focused = 0;
        secondary.last_cursor_position = UINT32_MAX;
        secondary.window = context.window;
        secondary.area = noctty_terminal_area_new();
        secondary.im_context = gtk_im_multicontext_new();
        g_ptr_array_add(context.contexts, &secondary);
        (void)sync_grid_context_profile(&secondary);
        context.peer = &secondary;
        secondary.peer = &context;
    }
    if (mode == 2) apply_fullscreen_dimensions(&context);
    context.notebook = gtk_notebook_new();
    gtk_notebook_set_scrollable(GTK_NOTEBOOK(context.notebook), TRUE);
    install_compact_tab_styles(context.notebook);
    g_signal_connect(context.notebook, "switch-page",
                     G_CALLBACK(on_notebook_switch_page), &context);
    g_signal_connect(context.notebook, "drag-begin",
                     G_CALLBACK(on_notebook_drag_begin), &context);
    g_signal_connect(context.notebook, "drag-end",
                     G_CALLBACK(on_notebook_drag_end), &context);
    context.new_tab_button = create_new_tab_button(&context);
    gtk_notebook_set_action_widget(GTK_NOTEBOOK(context.notebook),
                                   context.new_tab_button,
                                   GTK_PACK_START);
    gtk_widget_show_all(context.new_tab_button);
    context.window_toolbar_controls =
        create_window_toolbar_controls(&context);
    gtk_notebook_set_action_widget(GTK_NOTEBOOK(context.notebook),
                                   context.window_toolbar_controls,
                                   GTK_PACK_END);
    gtk_widget_show_all(context.window_toolbar_controls);
    context.revealer = gtk_revealer_new();
    context.content_box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
    context.recovery_notice = create_recovery_notice(&context);
    if (context.recovery_notice != NULL)
        gtk_box_pack_start(GTK_BOX(context.content_box),
                           context.recovery_notice, FALSE, FALSE, 0);
    context.pane_info_strip =
        noctty_pane_info_strip_new(context.show_pane_info);
    if (context.pane_info_strip == NULL) {
        gtk_widget_destroy(context.window);
        return 2;
    }
    gtk_revealer_set_transition_type(GTK_REVEALER(context.revealer),
                                     GTK_REVEALER_TRANSITION_TYPE_SLIDE_DOWN);
    gtk_revealer_set_transition_duration(GTK_REVEALER(context.revealer),
                                         (guint)context.dropdown_animation_ms);
    gtk_revealer_set_reveal_child(GTK_REVEALER(context.revealer), TRUE);
    secondary.notebook = context.notebook;
    secondary.revealer = context.revealer;
    secondary.content_box = context.content_box;
    secondary.pane_info_strip = context.pane_info_strip;
    GtkWidget *first_page = create_grid_page(&context);
    context.page = first_page;
    secondary.page = first_page;
    if (secondary_userdata != NULL && secondary.active) {
        context.paned = gtk_paned_new(GTK_ORIENTATION_VERTICAL);
        secondary.paned = context.paned;
        gtk_paned_pack1(GTK_PANED(context.paned), context.area, TRUE, FALSE);
        gtk_paned_pack2(GTK_PANED(context.paned), secondary.area, TRUE, FALSE);
        gtk_box_pack_start(GTK_BOX(first_page), context.paned, TRUE, TRUE, 0);
    } else {
        gtk_box_pack_start(GTK_BOX(first_page), context.area, TRUE, TRUE, 0);
    }
    GtkWidget *first_tab_widget = create_compact_tab_widget(&context, first_page, "Tab 1");
    GtkWidget *first_tab_label = tab_label_from_widget(first_tab_widget);
    context.tab_label = first_tab_label;
    secondary.tab_label = first_tab_label;
    gtk_notebook_append_page(GTK_NOTEBOOK(context.notebook), first_page,
                             first_tab_widget);
    gtk_notebook_set_tab_reorderable(GTK_NOTEBOOK(context.notebook), first_page, TRUE);
    gtk_notebook_set_tab_detachable(GTK_NOTEBOOK(context.notebook), first_page, FALSE);
    g_signal_connect(context.notebook, "page-reordered",
                     G_CALLBACK(on_notebook_page_reordered), &context);
    gtk_box_pack_start(GTK_BOX(context.content_box), context.notebook, TRUE, TRUE, 0);
    gtk_box_pack_end(GTK_BOX(context.content_box), context.pane_info_strip,
                     FALSE, FALSE, 0);
    gtk_container_add(GTK_CONTAINER(context.revealer), context.content_box);
    context.window_layout = create_window_resize_layout(
        &context, context.revealer);
    secondary.window_layout = context.window_layout;
    secondary.resize_grip = context.resize_grip;
    gtk_container_add(GTK_CONTAINER(context.window), context.window_layout);
    int initial_tab_position = event_data != NULL
        ? noctty_grid_tab_position(event_data)
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
    gboolean start_hidden = claim_control &&
        (enable_shortcut == 1 || enable_shortcut == 2) &&
        context.control_registered && mode == 0;
    int tray_ready = 0;
    if (((workspace_smoke < 0 && context.control_registered) ||
         workspace_smoke == 19) && !control_conflict)
        tray_ready = register_grid_tray(&context);
    if (!control_conflict && startup_activation_token != NULL) {
        gboolean retained = retain_xdg_activation_token_bytes(
            &context, startup_activation_token,
            startup_activation_token_length);
        if (retained && !start_hidden)
            apply_xdg_activation_token(&context);
        else if (!retained && g_getenv("NOCTTY_DEBUG_ACTIVATION") != NULL)
            g_printerr("noctty_xdg_activation retained=false source=startup\n");
    }
    show_all_with_action_affordances(
        (start_hidden || control_conflict)
            ? context.window_layout : context.window);
    update_window_resize_handles(&context);
    update_notebook_chrome(&context);
    for (guint index = 0; index < context.contexts->len; index++) {
        NocttyGridContext *candidate =
            g_ptr_array_index(context.contexts, index);
        if (candidate->active) update_compact_tab(candidate);
    }
    if (hot_session_restored) {
        int restored_active_tab = noctty_grid_restore_active_tab(
            context.event_data);
        if (restored_active_tab >= 0)
            gtk_notebook_set_current_page(
                GTK_NOTEBOOK(context.notebook), restored_active_tab);
        apply_smart_filter(&context);
    }
    context.layout_restore_applying = 0;
    if (mode == 0) apply_dropdown_dimensions(&context);
    else if (mode == 1 && !context.layer_shell_active)
        apply_window_dimensions(&context);
    update_status_tooltip(&context, "starting");
    if (secondary_userdata != NULL) update_status_tooltip(&secondary, secondary.active ? "starting" : "idle");
    if (secondary_userdata != NULL && !secondary.active) gtk_widget_hide(secondary.area);
    if (enable_shortcut == 1 && claim_control && !control_conflict) {
        (void)register_grid_shortcut(&context, shortcut_key);
    }
    if (control_conflict) {
        context.window_presented = 0;
        g_idle_add(quit_control_name_conflict, &context);
    }
    if (start_hidden) {
        gtk_revealer_set_reveal_child(GTK_REVEALER(context.revealer), FALSE);
        context.window_presented = 0;
        if (enable_shortcut == 1)
            context.shortcut_hidden_before_registration =
                !gtk_widget_get_visible(context.window) &&
                !gtk_widget_get_mapped(context.window) &&
                context.window_map_count == 0;
    }
    emit_grid_tray_tooltip(&context);
    (void)tray_ready;
    NocttyGridContext *initial_focus = hot_session_restored
        ? focused_grid_context(&context) : &context;
    gtk_widget_grab_focus(initial_focus->area);
    for (guint index = 0; index < context.contexts->len; index++) {
        NocttyGridContext *candidate =
            g_ptr_array_index(context.contexts, index);
        if (candidate->active && candidate->tick_source == 0)
            start_grid_context(candidate);
    }
    refresh_active_pane_info(&context);
#if NOCTTY_ENABLE_SMOKE
#include "../../tests/native_grid_smoke_schedule.inc"
#endif
    gtk_main();
#if !NOCTTY_ENABLE_SMOKE
    if (context.layout_save_source != 0) {
        g_source_remove(context.layout_save_source);
        context.layout_save_source = 0;
        if (!context.control_name_conflict && context.event_data != NULL)
            (void)noctty_grid_flush_hot_session(context.event_data);
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
        NocttyGridContext *candidate = g_ptr_array_index(context.contexts, index);
        stop_grid_context_sources(candidate);
    }
    dismiss_grid_popup_windows(&context);
    while (gtk_events_pending()) gtk_main_iteration_do(FALSE);
    gtk_widget_destroy(context.window);
    if (context.layer_shell_library != NULL) {
        dlclose(context.layer_shell_library);
        context.layer_shell_library = NULL;
    }
    g_clear_pointer(&context.xdg_activation_token, g_free);
    g_clear_pointer(&context.note_overlay_text, g_free);
    g_clear_pointer(&context.note_overlay_label, g_free);
    g_clear_pointer(&context.note_overlay_font, pango_font_description_free);
    remove_grid_source(&context.status_feedback_source);
    remove_grid_source(&context.sharing_status_source);
    g_clear_pointer(&context.status_feedback_text, g_free);
    g_clear_pointer(&context.smart_filter_tag, g_free);
    for (guint index = 0; index < context.contexts->len; index++) {
        NocttyGridContext *candidate = g_ptr_array_index(context.contexts, index);
        g_clear_pointer(&candidate->display_title, g_free);
        g_clear_pointer(&candidate->font_family, g_free);
        g_clear_pointer(&candidate->row_cells, g_free);
        g_clear_pointer(&candidate->dirty_row_buffer, g_free);
        g_clear_pointer(&candidate->dirty_span_buffer, g_free);
        destroy_grid_glyph_cache(candidate);
        g_clear_pointer(&candidate->note_overlay_font,
                        pango_font_description_free);
        g_clear_object(&candidate->im_context);
        if (candidate->heap_allocated) g_free(candidate);
    }
    g_ptr_array_free(context.contexts, TRUE);
    return context.control_name_conflict ? 3 : 0;
#else
    if (context.layout_save_source != 0) {
        g_source_remove(context.layout_save_source);
        context.layout_save_source = 0;
        if (!context.control_name_conflict && context.event_data != NULL)
            (void)noctty_grid_flush_hot_session(context.event_data);
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
        g_getenv("NOCTTY_ACTIVATION_CHILD_RECEIPT") != NULL;
    guint descriptor_contexts = 0;
    guint descriptor_contexts_coalesced = 0;
    for (guint index = 0; index < context.contexts->len; index++) {
        NocttyGridContext *candidate = g_ptr_array_index(context.contexts, index);
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
        gtk_notebook_get_tab_pos(GTK_NOTEBOOK(context.notebook));
    gint final_page_count =
        gtk_notebook_get_n_pages(GTK_NOTEBOOK(context.notebook));
    gint final_active_page =
        gtk_notebook_get_current_page(GTK_NOTEBOOK(context.notebook));
    gboolean final_tabs_visible =
        gtk_notebook_get_show_tabs(GTK_NOTEBOOK(context.notebook));
    int resize_grip_request_height = -1;
    if (context.resize_grip != NULL)
        gtk_widget_get_size_request(context.resize_grip, NULL,
                                    &resize_grip_request_height);
    int compact_im_ready = context.im_context != NULL;
    int resize_side_request_width = -1;
    if (context.window_resize_handles[3] != NULL)
        gtk_widget_get_size_request(context.window_resize_handles[3],
                                    &resize_side_request_width, NULL);
    const char *terminal_cursor_name = context.area != NULL
        ? g_object_get_data(G_OBJECT(context.area), "noctty-cursor-name")
        : NULL;
    const char *dragger_cursor_name = context.resize_grip != NULL
        ? g_object_get_data(G_OBJECT(context.resize_grip),
                            "noctty-resize-cursor-name")
        : NULL;
    int cursor_chrome_ok =
        g_strcmp0(terminal_cursor_name, "text") == 0 &&
        g_strcmp0(dragger_cursor_name, "ns-resize") == 0 &&
        resize_side_request_width == NOCTTY_WINDOW_RESIZE_BORDER_PX;
    for (int index = 0; index < 8; index++) {
        const char *name = context.window_resize_handles[index] != NULL
            ? g_object_get_data(
                  G_OBJECT(context.window_resize_handles[index]),
                  "noctty-resize-cursor-name")
            : NULL;
        if (name != NULL && (strstr(name, "nwse") != NULL ||
                             strstr(name, "nesw") != NULL))
            cursor_chrome_ok = 0;
    }
    GList *content_children = gtk_container_get_children(
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
        GtkWidget *page = gtk_notebook_get_nth_page(GTK_NOTEBOOK(context.notebook),
                                                    page_index);
        GtkWidget *tab_widget = gtk_notebook_get_tab_label(
            GTK_NOTEBOOK(context.notebook), page);
        GtkWidget *label = tab_label_from_widget(tab_widget);
        const gchar *text = GTK_IS_LABEL(label)
            ? gtk_label_get_text(GTK_LABEL(label))
            : NULL;
        if (text != NULL && strstr(text, "Build logs") != NULL) {
            tab_rename_rendered = 1;
            if (workspace_smoke == 30) hot_session_titles_rendered++;
        }
        if (workspace_smoke == 30 && text != NULL &&
            strstr(text, "Deploy") != NULL)
            hot_session_titles_rendered++;
        if (workspace_smoke == 30 &&
            GPOINTER_TO_UINT(g_object_get_data(
                G_OBJECT(tab_widget), "noctty-tab-color-rgb")) == 0x4285f4)
            hot_session_color_rendered = 1;
    }
    int hot_session_tag_tooltip = 0;
    int hot_session_profile = 0;
    if (workspace_smoke == 30) {
        for (guint index = 0; index < context.contexts->len; index++) {
            NocttyGridContext *candidate =
                g_ptr_array_index(context.contexts, index);
            gchar *tooltip = candidate->area != NULL
                ? gtk_widget_get_tooltip_text(candidate->area) : NULL;
            if (tooltip != NULL && strstr(tooltip, "tags: ops") != NULL)
                hot_session_tag_tooltip = 1;
            g_free(tooltip);
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
        gtk_window_get_title(GTK_WINDOW(context.window));
    int dropdown_identity_ready = workspace_smoke != 16 ||
        (final_window_title != NULL &&
         g_str_has_prefix(final_window_title, "NOCTTY Dropdown"));
    dismiss_grid_popup_windows(&context);
    while (gtk_events_pending()) gtk_main_iteration_do(FALSE);
    gtk_widget_destroy(context.window);
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
         context.system_noctalia_theme_applied);
    int project_ok = workspace_smoke != 8 ||
        (context.project_smoke_done && context.recent_workspace_control &&
         context.project_summary_scrollable &&
         context.project_summary_accessible &&
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
         context.compact_shortcut_label_dynamic &&
         context.compact_light_tab_title_inherits &&
         context.compact_zoom_toggled && context.status_feedback_drawn &&
         context.compact_directional_focus && context.compact_scrollback_saved &&
         context.compact_attention_seen && compact_im_ready &&
         context.resize_grip != NULL && context.compact_font_scroll_up &&
         context.compact_font_scroll_down && context.compact_font_scroll_isolated &&
         context.compact_plain_scroll_preserved &&
         context.compact_tui_wheel_mapping &&
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
        (context.row_batches_drawn > 0 && context.damage_rows_queued > 0 &&
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
#if NOCTTY_ENABLE_SMOKE
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
    g_clear_pointer(&context.xdg_activation_token, g_free);
    g_clear_pointer(&context.note_overlay_text, g_free);
    g_clear_pointer(&context.note_overlay_label, g_free);
    g_clear_pointer(&context.note_overlay_font, pango_font_description_free);
    remove_grid_source(&context.status_feedback_source);
    remove_grid_source(&context.sharing_status_source);
    g_clear_pointer(&context.status_feedback_text, g_free);
    g_clear_pointer(&context.smart_filter_tag, g_free);
    for (guint index = 0; index < context.contexts->len; index++) {
        NocttyGridContext *candidate = g_ptr_array_index(context.contexts, index);
        g_clear_pointer(&candidate->display_title, g_free);
        g_clear_pointer(&candidate->font_family, g_free);
        g_clear_pointer(&candidate->row_cells, g_free);
        g_clear_pointer(&candidate->dirty_row_buffer, g_free);
        g_clear_pointer(&candidate->dirty_span_buffer, g_free);
        destroy_grid_glyph_cache(candidate);
        g_clear_pointer(&candidate->note_overlay_font, pango_font_description_free);
        g_clear_object(&candidate->im_context);
        if (candidate->heap_allocated) g_free(candidate);
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
    if (workspace_smoke == 0) {
        g_print("native_grid_renderer_smoke abi=%d row_batches=%u damage_rows=%u damage_cells=%u damage_spans=%u damage_source=dirty_spans glyph_batches=%u glyph_cells=%u glyph_cache_hits=%u glyph_fallback_conversions=%u grapheme_cells=%u rich_style_cells=%u frame_presentations=%u timeout_presentations=%u resize_requests=%u resize_commits=%u sync_deferrals=%u sync_releases=%u sync_deadman_releases=%u passed=%s\n",
                NOCTTY_NATIVE_GRID_ABI_VERSION,
                context.row_batches_drawn, context.damage_rows_queued,
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
                renderer_damage_ok ? "true" : "false");
    }
#if NOCTTY_ENABLE_SMOKE
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
        g_printerr("native_grid_compact_ux_flags palette=%d find=%d note=%d accessibility_mask=%u dynamic_shortcut=%d zoom=%d direction=%d scrollback=%d attention=%d im=%d grip=%d grip_height=%d cursor_chrome=%d terminal_cursor=%s dragger_cursor=%s side_width=%d font_up=%d font_down=%d font_isolated=%d plain_scroll=%d tui_wheel=%d scrollbar_drawn=%d scrollbar_history=%" G_GUINT64_FORMAT " scrollbar_track=%d scrollbar_drag=%d terminal_accessible=%d tab_hidden=%d tab_restored=%d pane_rendered=%d pane_positioned=%d pane_source=%d pane_dedup=%d\n",
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
