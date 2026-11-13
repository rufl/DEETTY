#ifndef DINTTY_NATIVE_GRID_LOGIC_H
#define DINTTY_NATIVE_GRID_LOGIC_H

#include <stddef.h>
#include <stdint.h>

int dintty_grid_split_ratio(int position, int extent);
int dintty_grid_split_position(int extent, int ratio);

typedef struct {
    double x;
    double y;
    double width;
    double height;
    double thumb_y;
    double thumb_height;
    uint64_t history_lines;
    uint64_t viewport_offset;
    uint32_t visible_rows;
} DinttyTerminalScrollbarGeometry;

typedef struct {
    int action;
    double drag_offset;
    uint64_t target_offset;
} DinttyTerminalScrollbarPressPlan;

enum {
    DINTTY_GRID_SCROLLBAR_PRESS_NONE = 0,
    DINTTY_GRID_SCROLLBAR_PRESS_DRAG = 1,
    DINTTY_GRID_SCROLLBAR_PRESS_PAGE = 2,
};

typedef struct {
    double font_px;
    double cell_width;
    double cell_height;
} DinttyGridFontMetrics;

typedef struct {
    int leading;
    int trailing;
} DinttyGridPanelSpacingPlan;

typedef struct {
    int width;
    int height;
} DinttyGridAutoFitBounds;

typedef struct {
    int terminal_width;
    int columns;
    int rows;
    int changed;
} DinttyGridResizePlan;


typedef struct {
    int active_kind;
    int changed;
} DinttyGridStatusPlan;

typedef struct {
    uint32_t role;
    uint32_t fallback;
    int muted;
} DinttyGridStatusColorPlan;

typedef struct {
    int show;
} DinttyGridNotebookChromePlan;
typedef struct {
    double x;
    double y;
    double width;
    double height;
} DinttyGridRectangle;
typedef struct {
    int x;
    int y;
    int width;
    int height;
} DinttyGridDamageRect;

typedef struct {
    int column;
    int row;
    int valid;
} DinttyGridCursorPosition;
typedef struct {
    int steps;
    int direction;
} DinttyGridWheelActionPlan;

typedef struct {
    int visible;
    int first_visible;
    int focused_visible;
} DinttyGridSmartFilterVisibilityPlan;

typedef struct {
    int focus_first;
    int show_empty;
} DinttyGridSmartFilterSummaryPlan;

typedef struct {
    int start;
    int end;
    int valid;
} DinttyGridAccessibleOffsetPlan;
typedef struct {
    int start;
    int end;
    int valid;
} DinttyGridAccessibleRangePlan;
typedef struct {
    int start_hidden;
    int apply_activation;
    int show_layout_only;
} DinttyGridStartupWindowPlan;
typedef struct {
    int registered;
    int conflict;
} DinttyGridControlNameRequestPlan;

typedef struct {
    int delay_ms;
    int action;
    int target;
} DinttyGridSmokeScheduleStep;
typedef struct {
    int schedule;
    int use_tick;
    int timeout_ms;
} DinttyGridOutputPresentPlan;
typedef struct {
    int unzoom;
    int enter;
} DinttyGridZoomPlan;
typedef struct {
    int valid;
    int rows;
    int columns;
    int target_count;
} DinttyGridLayoutPresetPlan;

typedef struct {
    int panel_padding_px;
    int pane_spacing_px;
    int pane_divider_px;
    int pane_border_px;
    int pane_border_focused_px;
    int pane_border_selected_px;
    int status_border_px;
    int overlay_border_px;
    int window_border_px;
    int dragger_px;
    int pane_gaps_enabled;
    int pane_gaps_transparent;
    int inactive_pane_dim_enabled;
    int inactive_pane_brightness_percent;
    int background_translucency;
    int background_opacity_percent;
    int affects_layout;
} DinttyGridPanelSettings;

typedef struct {
    int target;
    int valid;
} DinttyGridCompactSettingPlan;
typedef int (*DinttyGridCompactSettingReader)(void *userdata, int field);
typedef struct {
    int width_percent;
    int height_percent;
    int width_pixels;
    int height_pixels;
    int animation_ms;
    int hide_on_focus_loss;
    int focus_follows_pointer;
    int background_translucency;
    int background_opacity_percent;
    int terminal_smooth_scroll;
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
    double font_size;
    double font_min_size;
    double font_max_size;
    int font_antialias;
    int font_hinting;
    int renderer_backend;
} DinttyGridSettingsPlan;

enum {
    DINTTY_GRID_COMPACT_TARGET_WIDTH_PERCENT = 0,
    DINTTY_GRID_COMPACT_TARGET_HEIGHT_PERCENT = 1,
    DINTTY_GRID_COMPACT_TARGET_ANIMATION = 2,
    DINTTY_GRID_COMPACT_TARGET_HIDE_FOCUS = 3,
    DINTTY_GRID_COMPACT_TARGET_FOCUS_POINTER = 4,
    DINTTY_GRID_COMPACT_TARGET_PANE_INFO = 5,
    DINTTY_GRID_COMPACT_TARGET_WIDTH_PIXELS = 6,
    DINTTY_GRID_COMPACT_TARGET_HEIGHT_PIXELS = 7,
};
enum {
    DINTTY_GRID_COMPACT_FIELD_WIDTH_PERCENT = 0,
    DINTTY_GRID_COMPACT_FIELD_HEIGHT_PERCENT = 1,
    DINTTY_GRID_COMPACT_FIELD_ANIMATION = 2,
    DINTTY_GRID_COMPACT_FIELD_HIDE_FOCUS = 3,
    DINTTY_GRID_COMPACT_FIELD_FOCUS_POINTER = 4,
    DINTTY_GRID_COMPACT_FIELD_TAB_HEIGHT = 5,
    DINTTY_GRID_COMPACT_FIELD_FONT_SIZE = 6,
    DINTTY_GRID_COMPACT_FIELD_FONT_MIN = 7,
    DINTTY_GRID_COMPACT_FIELD_FONT_MAX = 8,
    DINTTY_GRID_COMPACT_FIELD_PANE_INFO = 9,
    DINTTY_GRID_COMPACT_FIELD_SCROLLBACK = 10,
    DINTTY_GRID_COMPACT_FIELD_ANTIALIAS = 11,
    DINTTY_GRID_COMPACT_FIELD_HINTING = 12,
    DINTTY_GRID_COMPACT_FIELD_WIDTH_PIXELS = 14,
    DINTTY_GRID_COMPACT_FIELD_HEIGHT_PIXELS = 15,
    DINTTY_GRID_COMPACT_FIELD_BACKGROUND_TRANSLUCENCY = 16,
    DINTTY_GRID_COMPACT_FIELD_BACKGROUND_OPACITY = 17,
    DINTTY_GRID_COMPACT_FIELD_SMOOTH_SCROLL = 19,
    DINTTY_GRID_COMPACT_FIELD_PANEL_PADDING = 20,
    DINTTY_GRID_COMPACT_FIELD_PANE_SPACING = 21,
    DINTTY_GRID_COMPACT_FIELD_PANE_DIVIDER = 22,
    DINTTY_GRID_COMPACT_FIELD_PANE_BORDER = 23,
    DINTTY_GRID_COMPACT_FIELD_PANE_BORDER_FOCUSED = 24,
    DINTTY_GRID_COMPACT_FIELD_PANE_BORDER_SELECTED = 25,
    DINTTY_GRID_COMPACT_FIELD_STATUS_BORDER = 26,
    DINTTY_GRID_COMPACT_FIELD_OVERLAY_BORDER = 27,
    DINTTY_GRID_COMPACT_FIELD_WINDOW_BORDER = 28,
    DINTTY_GRID_COMPACT_FIELD_DRAGGER = 29,
    DINTTY_GRID_COMPACT_FIELD_PANE_GAPS = 30,
    DINTTY_GRID_COMPACT_FIELD_PANE_GAPS_TRANSPARENT = 31,
    DINTTY_GRID_COMPACT_FIELD_INACTIVE_PANE_DIM = 32,
    DINTTY_GRID_COMPACT_FIELD_INACTIVE_PANE_BRIGHTNESS = 33,
    DINTTY_GRID_COMPACT_FIELD_RENDERER_BACKEND = 34,
};

typedef struct {
    int target;
    int value;
    int valid;
} DinttyGridFontRenderingPlan;

enum {
    DINTTY_GRID_FONT_RENDERING_TARGET_ANTIALIAS = 0,
    DINTTY_GRID_FONT_RENDERING_TARGET_HINTING = 1,
};
enum {
    DINTTY_GRID_SETTINGS_EVENT_DROPDOWN_WIDTH = 0,
    DINTTY_GRID_SETTINGS_EVENT_DROPDOWN_HEIGHT = 1,
    DINTTY_GRID_SETTINGS_EVENT_ANIMATION = 2,
    DINTTY_GRID_SETTINGS_EVENT_HIDE_FOCUS = 3,
    DINTTY_GRID_SETTINGS_EVENT_FOCUS_POINTER = 4,
    DINTTY_GRID_SETTINGS_EVENT_MODE = 5,
    DINTTY_GRID_SETTINGS_EVENT_FONT_SIZE = 6,
    DINTTY_GRID_SETTINGS_EVENT_PANE_FONT_SIZE = 7,
    DINTTY_GRID_SETTINGS_EVENT_NOTIFICATIONS = 8,
    DINTTY_GRID_SETTINGS_EVENT_PRESET = 9,
    DINTTY_GRID_SETTINGS_EVENT_TABS = 10,
    DINTTY_GRID_SETTINGS_EVENT_STATUS = 11,
    DINTTY_GRID_SETTINGS_EVENT_TAB_POSITION = 12,
    DINTTY_GRID_SETTINGS_EVENT_HIGH_CONTRAST = 13,
    DINTTY_GRID_SETTINGS_EVENT_FONT_FAMILY = 14,
    DINTTY_GRID_SETTINGS_EVENT_BACKGROUND_OPACITY = 15,
    DINTTY_GRID_SETTINGS_EVENT_ANTIALIAS = 16,
    DINTTY_GRID_SETTINGS_EVENT_HINTING = 17,
    DINTTY_GRID_SETTINGS_EVENT_SHORTCUT = 18,
    DINTTY_GRID_SETTINGS_EVENT_PANE_INFO = 19,
    DINTTY_GRID_SETTINGS_EVENT_SCROLL_LINES = 20,
    DINTTY_GRID_SETTINGS_EVENT_SMOOTH_SCROLL = 21,
    DINTTY_GRID_SETTINGS_EVENT_PANEL_PADDING = 22,
    DINTTY_GRID_SETTINGS_EVENT_PANE_SPACING = 23,
    DINTTY_GRID_SETTINGS_EVENT_PANE_GAPS_ENABLED = 24,
    DINTTY_GRID_SETTINGS_EVENT_PANE_GAPS_TRANSPARENT = 25,
    DINTTY_GRID_SETTINGS_EVENT_INACTIVE_PANE_DIM = 26,
    DINTTY_GRID_SETTINGS_EVENT_PANE_DIVIDER = 27,
    DINTTY_GRID_SETTINGS_EVENT_PANE_BORDER = 28,
    DINTTY_GRID_SETTINGS_EVENT_FOCUSED_BORDER = 29,
    DINTTY_GRID_SETTINGS_EVENT_SELECTED_BORDER = 30,
    DINTTY_GRID_SETTINGS_EVENT_STATUS_BORDER = 31,
    DINTTY_GRID_SETTINGS_EVENT_OVERLAY_BORDER = 32,
    DINTTY_GRID_SETTINGS_EVENT_DRAGGER = 34,
    DINTTY_GRID_SETTINGS_EVENT_SCROLLBACK = 35,
    DINTTY_GRID_SETTINGS_EVENT_BACKGROUND_TRANSLUCENCY = 36,
    DINTTY_GRID_SETTINGS_EVENT_INACTIVE_PANE_BRIGHTNESS = 37,
    DINTTY_GRID_SETTINGS_EVENT_RENDERER_BACKEND = 38,
};
enum {
    DINTTY_GRID_HOST_EVENT_SESSION_STARTED = 0,
    DINTTY_GRID_HOST_EVENT_SESSION_EXITED = 1,
    DINTTY_GRID_HOST_EVENT_OUTPUT_ACTIVITY = 2,
    DINTTY_GRID_HOST_EVENT_SHORTCUT_CANCELLED = 3,
    DINTTY_GRID_HOST_EVENT_PROJECT_VISIBILITY = 4,
    DINTTY_GRID_HOST_EVENT_WORKSPACE_NEW_TAB = 5,
    DINTTY_GRID_HOST_EVENT_WORKSPACE_SPLIT = 6,
    DINTTY_GRID_HOST_EVENT_WORKSPACE_SPLIT_ALT = 7,
    DINTTY_GRID_HOST_EVENT_WORKSPACE_BROADCAST = 8,
    DINTTY_GRID_HOST_EVENT_WORKSPACE_FOCUS = 9,
    DINTTY_GRID_HOST_EVENT_BROADCAST_SELECTION = 10,
    DINTTY_GRID_HOST_EVENT_WORKSPACE_SPLIT_CLOSE = 11,
    DINTTY_GRID_HOST_EVENT_WORKSPACE_SPLIT_RESTORE = 12,
    DINTTY_GRID_HOST_EVENT_LAYOUT_PRESET_1X1 = 13,
    DINTTY_GRID_HOST_EVENT_LAYOUT_PRESET_2X2 = 14,
    DINTTY_GRID_HOST_EVENT_LAYOUT_PRESET_3X3 = 15,
    DINTTY_GRID_HOST_EVENT_LAYOUT_PRESET_4X4 = 16,
    DINTTY_GRID_HOST_EVENT_LAYOUT_PRESET_4X2 = 17,
    DINTTY_GRID_HOST_EVENT_PANE_MOVED = 18,
    DINTTY_GRID_HOST_EVENT_WORKSPACE_MOVE = 19,
    DINTTY_GRID_HOST_EVENT_PANE_FOCUS = 20,
    DINTTY_GRID_HOST_EVENT_SPLIT_RENDERED_VERTICAL = 21,
    DINTTY_GRID_HOST_EVENT_SPLIT_RENDERED_HORIZONTAL = 22,
    DINTTY_GRID_HOST_EVENT_PANE_MOVED_RENDERED = 23,
    DINTTY_GRID_HOST_EVENT_ZOOM_TOGGLED = 24,
    DINTTY_GRID_HOST_EVENT_COMMAND_PALETTE_OPENED = 25,
    DINTTY_GRID_HOST_EVENT_TERMINAL_FIND_OPENED = 26,
    DINTTY_GRID_HOST_EVENT_DIRECTIONAL_FOCUS = 27,
    DINTTY_GRID_HOST_EVENT_SPLIT_RENDERED_CLOSE = 28,
    DINTTY_GRID_HOST_EVENT_SPLIT_RENDERED_RESTORE = 29,
    DINTTY_GRID_HOST_EVENT_TAB_CYCLE = 30,
    DINTTY_GRID_HOST_EVENT_TAB_CLOSE = 31,
    DINTTY_GRID_HOST_EVENT_TAB_REOPEN = 32,
    DINTTY_GRID_HOST_EVENT_PANE_CYCLE = 33,
    DINTTY_GRID_HOST_EVENT_TITLE_FALLBACK = 34,
    DINTTY_GRID_HOST_EVENT_TITLE_OVERFLOW_LABEL = 35,
    DINTTY_GRID_HOST_EVENT_TITLE_OVERFLOW_TOOLTIP = 36,
    DINTTY_GRID_HOST_EVENT_TITLE_RENAMED = 37,
    DINTTY_GRID_HOST_EVENT_DIRTY_SAVED = 38,
    DINTTY_GRID_HOST_EVENT_SESSION_EXIT_SMOKE = 39,
    DINTTY_GRID_HOST_EVENT_DIRTY_MARKED = 40,
    DINTTY_GRID_HOST_EVENT_NOTIFICATION_ATTENTION = 41,
    DINTTY_GRID_HOST_EVENT_DIRTY_CLEARED = 42,
    DINTTY_GRID_HOST_EVENT_TAB_REORDERED = 43,
    DINTTY_GRID_HOST_EVENT_TAB_REORDER_PERSISTED = 44,
    DINTTY_GRID_HOST_EVENT_RENAME_VALIDATION = 45,
    DINTTY_GRID_HOST_EVENT_RENAME_APPLIED = 46,
    DINTTY_GRID_HOST_EVENT_RENAME_CANCELLED = 47,
    DINTTY_GRID_HOST_EVENT_PANE_CYCLE_SHORTCUT = 48,
    DINTTY_GRID_HOST_EVENT_ALT_SCROLL_PREVIOUS = 49,
    DINTTY_GRID_HOST_EVENT_RESTORED_PANE = 50,
    DINTTY_GRID_HOST_EVENT_ALT_SCROLL_NEXT = 51,
    DINTTY_GRID_HOST_EVENT_CTRL_ALT_SCROLL = 52,
    DINTTY_GRID_HOST_EVENT_TERMINAL_INTERRUPT_CHORD = 53,
    DINTTY_GRID_HOST_EVENT_TERMINAL_CLOSE_CHORD = 54,
    DINTTY_GRID_HOST_EVENT_FINAL_PANE_GUARD = 55,
    DINTTY_GRID_HOST_EVENT_PROFILE_MENU_OPENED = 56,
    DINTTY_GRID_HOST_EVENT_PROFILE_SELECTED = 57,
    DINTTY_GRID_HOST_EVENT_PROJECT_TOOLS_OPENED = 58,
    DINTTY_GRID_HOST_EVENT_WORKSPACE_NEW_TAB_RESTORE = 59,
    DINTTY_GRID_HOST_EVENT_SHORTCUT_CONFLICT = 60,
    DINTTY_GRID_HOST_EVENT_SHORTCUT_FAILED = 61,
};



typedef struct {
    int action;
    int selection_end_column;
    int selection_end_row;
} DinttyGridTerminalMenuPlan;

enum {
    DINTTY_GRID_TERMINAL_MENU_ACTION_NONE = 0,
    DINTTY_GRID_TERMINAL_MENU_ACTION_COPY = 1,
    DINTTY_GRID_TERMINAL_MENU_ACTION_PASTE = 2,
    DINTTY_GRID_TERMINAL_MENU_ACTION_SELECT_ALL = 3,
    DINTTY_GRID_TERMINAL_MENU_ACTION_CLEAR_SELECTION = 4,
    DINTTY_GRID_TERMINAL_MENU_ACTION_CLEAR_SCREEN = 5,
    DINTTY_GRID_TERMINAL_MENU_ACTION_CLEAR_SCROLLBACK = 6,
    DINTTY_GRID_TERMINAL_MENU_ACTION_RESET = 7,
};

typedef struct {
    int width;
    int height;
} DinttyGridWindowDimensionsPlan;

typedef struct {
    int kind;
    int command_sensitive;
    int ssh_target_sensitive;
} DinttyGridLaunchProfileControlsPlan;

typedef struct {
    int action;
    int bind_layout;
    int restore_missing;
} DinttyGridWorkspaceEventPlan;

typedef struct {
    int valid;
    int kind;
    int has_children;
    int action;
} DinttyGridTrayMenuItemPlan;

typedef struct {
    int output_deadman_ms;
    int write_flush_ms;
    int64_t exit_poll_us;
    int tick_ms;
    int cursor_blink_ms;
    int maintenance_seconds;
    int64_t idle_background_us;
    int64_t idle_focused_us;
    int idle_steps_per_tick;
    int preset_settle_interval_ms;
    int preset_settle_attempts;
    int status_feedback_ms;
    int pane_cycle_feedback_ms;
    int tab_cycle_feedback_ms;
    int focus_hide_ms;
    int layer_surface_hide_commit_ms;
    int quick_note_save_debounce_ms;
    int sharing_status_refresh_ms;
    int resize_overlay_hide_ms;
    int resize_commit_ms;
    int resize_overlay_arm_ms;
    int even_pane_settle_interval_ms;
    int even_pane_settle_attempts;
    int dbus_call_timeout_ms;
    int dbus_operation_timeout_ms;
    int dbus_notification_timeout_ms;
    int dbus_drain_ms;
    int64_t dbus_poll_us;
} DinttyGridLifecycleTimingPlan;

typedef struct {
    int dropdown_min_width_px;
    int dropdown_min_height_px;
    int window_resize_border_px;
    int pane_info_height_px;
    int terminal_scrollbar_width_px;
    int terminal_scrollbar_min_thumb_px;
    int64_t selection_copy_max_bytes;
    int event_idle_history_compacted;
    int event_status_notification;
    int event_status_acknowledged;
    int text_action_persistence_failed;
    int ui_color_workspace_background;
    int ui_color_pane_border_active;
    int ui_color_pane_border_selected;
    int ui_color_pane_border_inactive;
    int ui_color_scrollbar_track;
    int ui_color_scrollbar_thumb;
    int ui_color_scrollbar_thumb_hover;
    int ui_color_overlay_background;
    int ui_color_overlay_border;
    int ui_color_overlay_foreground;
    int ui_color_selection_background;
    int ui_color_search_match_background;
    int ui_color_status_info;
    int ui_color_status_success;
    int ui_color_status_warning;
    int ui_color_status_error;
    int ui_color_terminal_cursor;
    int ui_color_pane_gap;
    uint32_t default_workspace_background_rgb;
    uint32_t default_terminal_cursor_rgb;
} DinttyGridNativeHostPolicy;

enum {
    DINTTY_GRID_WORKSPACE_EVENT_EMIT = 0,
    DINTTY_GRID_WORKSPACE_EVENT_CREATE_TAB = 1,
    DINTTY_GRID_WORKSPACE_EVENT_SPLIT = 2,
    DINTTY_GRID_WORKSPACE_EVENT_LAYOUT_PRESET = 3,
    DINTTY_GRID_WORKSPACE_EVENT_MOVE = 4,
};

enum {
    DINTTY_GRID_TRAY_MENU_KIND_ROOT = 0,
    DINTTY_GRID_TRAY_MENU_KIND_STANDARD = 1,
    DINTTY_GRID_TRAY_MENU_KIND_SEPARATOR = 2,
};

enum {
    DINTTY_GRID_TRAY_MENU_ACTION_NONE = 0,
    DINTTY_GRID_TRAY_MENU_ACTION_TOGGLE = 1,
    DINTTY_GRID_TRAY_MENU_ACTION_SETTINGS = 2,
    DINTTY_GRID_TRAY_MENU_ACTION_CLOSE = 3,
};



enum {
    DINTTY_GRID_SMOKE_TARGET_CONTEXT = 0,
    DINTTY_GRID_SMOKE_TARGET_PEER = 1,
};

enum {
    DINTTY_GRID_SMOKE_ACTION_WRITE_ACTIVATION_CHILD_RECEIPT = 1,
    DINTTY_GRID_SMOKE_ACTION_EMIT_WORKSPACE_TAB,
    DINTTY_GRID_SMOKE_ACTION_EMIT_WORKSPACE_SPLIT,
    DINTTY_GRID_SMOKE_ACTION_EMIT_WORKSPACE_SPLIT_LEFT,
    DINTTY_GRID_SMOKE_ACTION_EMIT_WORKSPACE_BROADCAST,
    DINTTY_GRID_SMOKE_ACTION_EMIT_WORKSPACE_SELECT,
    DINTTY_GRID_SMOKE_ACTION_EMIT_WORKSPACE_TAG_FILTER,
    DINTTY_GRID_SMOKE_ACTION_EMIT_WORKSPACE_FOCUS,
    DINTTY_GRID_SMOKE_ACTION_EMIT_WORKSPACE_MOVE,
    DINTTY_GRID_SMOKE_ACTION_FINISH_WORKSPACE,
    DINTTY_GRID_SMOKE_ACTION_REQUEST_NEW_TAB_BUTTON,
    DINTTY_GRID_SMOKE_ACTION_INSPECT_COMPACT_TAB_GEOMETRY,
    DINTTY_GRID_SMOKE_ACTION_REQUEST_TAB_CLOSE,
    DINTTY_GRID_SMOKE_ACTION_REQUEST_CLIPBOARD,
    DINTTY_GRID_SMOKE_ACTION_INSPECT_WINDOW_TOOLBAR,
    DINTTY_GRID_SMOKE_ACTION_REQUEST_SETTINGS,
    DINTTY_GRID_SMOKE_ACTION_REQUEST_WINDOW_CLOSE_BUTTON,
    DINTTY_GRID_SMOKE_ACTION_REQUEST_THEME,
    DINTTY_GRID_SMOKE_ACTION_REQUEST_PROJECT,
    DINTTY_GRID_SMOKE_ACTION_REQUEST_RECURSIVE_ZOOM,
    DINTTY_GRID_SMOKE_ACTION_DRIVE_FOCUS_CLICK,
    DINTTY_GRID_SMOKE_ACTION_EMIT_BALANCED_SPLIT,
    DINTTY_GRID_SMOKE_ACTION_MOVE_LAST_PANE,
    DINTTY_GRID_SMOKE_ACTION_REQUEST_COMPACT_HYPERLINK,
    DINTTY_GRID_SMOKE_ACTION_REQUEST_COMPACT_PALETTE,
    DINTTY_GRID_SMOKE_ACTION_REQUEST_COMPACT_FIND,
    DINTTY_GRID_SMOKE_ACTION_REQUEST_COMPACT_NOTE,
    DINTTY_GRID_SMOKE_ACTION_REQUEST_COMPACT_ZOOM,
    DINTTY_GRID_SMOKE_ACTION_REQUEST_COMPACT_NAVIGATION,
    DINTTY_GRID_SMOKE_ACTION_INSPECT_COMPACT_PANE_INFO,
    DINTTY_GRID_SMOKE_ACTION_REQUEST_COMPACT_FONT_SCROLL,
    DINTTY_GRID_SMOKE_ACTION_REQUEST_COMPACT_LINEAR_SELECTION,
    DINTTY_GRID_SMOKE_ACTION_REQUEST_COMPACT_SAVE,
    DINTTY_GRID_SMOKE_ACTION_REQUEST_PANE_SCROLLBAR,
    DINTTY_GRID_SMOKE_ACTION_FINISH_COMPACT,
    DINTTY_GRID_SMOKE_ACTION_REQUEST_TAB_RENAME,
    DINTTY_GRID_SMOKE_ACTION_CHECK_RESIZE_OVERLAY_HIDDEN,
    DINTTY_GRID_SMOKE_ACTION_MOVE_RESIZE_OVERLAY,
    DINTTY_GRID_SMOKE_ACTION_CHECK_RESIZE_OVERLAY_VISIBLE,
    DINTTY_GRID_SMOKE_ACTION_FINISH_RESIZE_OVERLAY,
    DINTTY_GRID_SMOKE_ACTION_EMIT_PANE_CLOSE_PRIMARY,
    DINTTY_GRID_SMOKE_ACTION_EMIT_PANE_CLOSE_SECONDARY,
    DINTTY_GRID_SMOKE_ACTION_INSPECT_PANE_CLOSE_LAYOUT,
    DINTTY_GRID_SMOKE_ACTION_DISTURB_PANE_CLOSE_LAYOUT,
    DINTTY_GRID_SMOKE_ACTION_REQUEST_PANE_CLOSE,
    DINTTY_GRID_SMOKE_ACTION_START_LAYOUT_PRESET,
    DINTTY_GRID_SMOKE_ACTION_START_TAB_NAVIGATION,
    DINTTY_GRID_SMOKE_ACTION_CHECK_TITLE_FALLBACK,
    DINTTY_GRID_SMOKE_ACTION_EMIT_TITLE_OVERFLOW,
    DINTTY_GRID_SMOKE_ACTION_CHECK_TITLE_OVERFLOW,
    DINTTY_GRID_SMOKE_ACTION_CHECK_TITLE_RENAME,
    DINTTY_GRID_SMOKE_ACTION_FINISH_TITLE,
    DINTTY_GRID_SMOKE_ACTION_TRIGGER_DIRTY,
    DINTTY_GRID_SMOKE_ACTION_EMIT_ATTENTION,
    DINTTY_GRID_SMOKE_ACTION_CHECK_DIRTY,
    DINTTY_GRID_SMOKE_ACTION_CHECK_ATTENTION,
    DINTTY_GRID_SMOKE_ACTION_SAVE_DIRTY,
    DINTTY_GRID_SMOKE_ACTION_CHECK_DIRTY_CLEAR,
    DINTTY_GRID_SMOKE_ACTION_ACKNOWLEDGE_ATTENTION,
    DINTTY_GRID_SMOKE_ACTION_ANNOUNCE_REORDER,
    DINTTY_GRID_SMOKE_ACTION_CHECK_REORDER,
    DINTTY_GRID_SMOKE_ACTION_PERSIST_REORDER,
    DINTTY_GRID_SMOKE_ACTION_PALETTE_RENAME,
    DINTTY_GRID_SMOKE_ACTION_REQUEST_TAB_COLOR,
    DINTTY_GRID_SMOKE_ACTION_REQUEST_SETTINGS_STACKING,
    DINTTY_GRID_SMOKE_ACTION_CHECK_SETTINGS_STACKING,
    DINTTY_GRID_SMOKE_ACTION_REQUEST_NOTE_OVERLAY_ALT,
    DINTTY_GRID_SMOKE_ACTION_CHECK_NOTE_OVERLAY,
    DINTTY_GRID_SMOKE_ACTION_REQUEST_TERMINAL_INTERRUPT,
    DINTTY_GRID_SMOKE_ACTION_REQUEST_TERMINAL_CLOSE,
    DINTTY_GRID_SMOKE_ACTION_REQUEST_TERMINAL_FINAL_GUARD,
    DINTTY_GRID_SMOKE_ACTION_FINISH_TERMINAL_CHORD,
    DINTTY_GRID_SMOKE_ACTION_REQUEST_PROFILE_PRESET,
    DINTTY_GRID_SMOKE_ACTION_REQUEST_RECENT_WORKSPACE_CHILD,
    DINTTY_GRID_SMOKE_ACTION_START_PRESENTATION,
    DINTTY_GRID_SMOKE_ACTION_START_FULL_STACK,
    DINTTY_GRID_SMOKE_ACTION_POLL_CONTINUITY_DETACH,
    DINTTY_GRID_SMOKE_ACTION_START_STABILITY,
    DINTTY_GRID_SMOKE_ACTION_REQUEST_SHARING_SCOPE,
    DINTTY_GRID_SMOKE_ACTION_REQUEST_WINDOW_RESIZE,
};

typedef struct {
    int initial_capacity;
} DinttyGridAccessibleTextPlan;

typedef struct {
    int route;
    int steps;
    int direction;
} DinttyGridScrollRoutePlan;

typedef struct {
    int valid;
    int start_column;
    int end_column;
} DinttyGridSelectionWordPlan;

typedef int (*DinttyGridCellTextReader)(
    void *, int, int, char *, size_t);
typedef int (*DinttyGridCellHyperlinkReader)(
    void *, int, int, char *, size_t);

typedef struct {
    int action;
    int value;
    int reopen_tab;
    int queue_draw;
} DinttyGridKeyChordPlan;

enum {
    DINTTY_GRID_CHORD_NONE = 0,
    DINTTY_GRID_CHORD_COMMAND_PALETTE = 1,
    DINTTY_GRID_CHORD_TERMINAL_FIND = 2,
    DINTTY_GRID_CHORD_QUICK_NOTE = 3,
    DINTTY_GRID_CHORD_SMART_FILTER = 4,
    DINTTY_GRID_CHORD_TAG_SELECTED = 5,
    DINTTY_GRID_CHORD_ZOOM = 6,
    DINTTY_GRID_CHORD_SHORTCUTS = 7,
    DINTTY_GRID_CHORD_CLOSE_TAB = 8,
    DINTTY_GRID_CHORD_RENAME_TAB = 9,
    DINTTY_GRID_CHORD_EMIT_EVENT = 10,
    DINTTY_GRID_CHORD_BROADCAST = 11,
    DINTTY_GRID_CHORD_TAB_COLOR = 12,
    DINTTY_GRID_CHORD_PASTE = 13,
    DINTTY_GRID_CHORD_COPY = 14,
    DINTTY_GRID_CHORD_SCROLL_KEYBOARD = 15,
    DINTTY_GRID_CHORD_CTRL_D = 16,
    DINTTY_GRID_CHORD_CTRL_C = 17,
};
typedef struct {
    int action;
} DinttyGridPointerEventPlan;

enum {
    DINTTY_GRID_POINTER_EVENT_PRESS = 1,
    DINTTY_GRID_POINTER_EVENT_RELEASE = 2,
    DINTTY_GRID_POINTER_EVENT_DOUBLE_PRESS = 3,
};

enum {
    DINTTY_GRID_POINTER_ACTION_NONE = 0,
    DINTTY_GRID_POINTER_ACTION_ZOOM = 1,
    DINTTY_GRID_POINTER_ACTION_SELECT_WORD = 2,
    DINTTY_GRID_POINTER_ACTION_CLEAR_SELECTION = 3,
    DINTTY_GRID_POINTER_ACTION_OPEN_HYPERLINK = 4,
    DINTTY_GRID_POINTER_ACTION_SHOW_HYPERLINK_MENU = 5,
    DINTTY_GRID_POINTER_ACTION_SHOW_WORKSPACE_MENU = 6,
    DINTTY_GRID_POINTER_ACTION_BEGIN_SELECTION = 7,
    DINTTY_GRID_POINTER_ACTION_UPDATE_SELECTION = 8,
    DINTTY_GRID_POINTER_ACTION_DELIVER_MOUSE = 9,
    DINTTY_GRID_POINTER_ACTION_CONSUME = 10,
};

typedef struct {
    double source_center_x;
    double source_center_y;
    double best_score;
    int direction_x;
    int direction_y;
    int target_index;
    int active;
} DinttyGridDirectionalFocusPlan;

typedef struct {
    int action;
    int direction;
    int dx;
    int dy;
    int consume_without_effect;
} DinttyGridKeyCommandPlan;

typedef uint32_t DinttyApplicationCloseOrigin;

enum {
    DINTTY_CLOSE_ORIGIN_NONE = 0,
    DINTTY_CLOSE_ORIGIN_TOOLBAR = 1,
    DINTTY_CLOSE_ORIGIN_TRAY = 2,
    DINTTY_CLOSE_ORIGIN_WINDOW = 3,
    DINTTY_CLOSE_ORIGIN_NATURAL = 4,
};

typedef struct {
    uint32_t phase;
    DinttyApplicationCloseOrigin origin;
    uint32_t modal_depth;
} DinttyGridCloseCoordinator;

typedef struct {
    uint32_t effects;
    DinttyApplicationCloseOrigin origin;
    uint32_t accepted;
} DinttyGridCloseTransition;

enum {
    DINTTY_CLOSE_SOURCE_DEFERRED = 1,
    DINTTY_CLOSE_SOURCE_PREFLIGHT = 2,
};

enum {
    DINTTY_CLOSE_EFFECT_SCHEDULE_DEFERRED = 1u << 0,
    DINTTY_CLOSE_EFFECT_SCHEDULE_PREFLIGHT = 1u << 1,
    DINTTY_CLOSE_EFFECT_SCHEDULE_DWELL = 1u << 2,
    DINTTY_CLOSE_EFFECT_CANCEL_DEFERRED = 1u << 3,
    DINTTY_CLOSE_EFFECT_CANCEL_PREFLIGHT = 1u << 4,

    DINTTY_CLOSE_EFFECT_RUN_PREFLIGHT = 1u << 5,
    DINTTY_CLOSE_EFFECT_COMMIT = 1u << 6,
};
void dintty_grid_startup_window_plan(
    int claim_control, int enable_shortcut, int control_registered,
    int mode, int control_conflict, int activation_retained,
    DinttyGridStartupWindowPlan *plan);
void dintty_grid_control_name_request_plan(
    int request_result, DinttyGridControlNameRequestPlan *plan);

DinttyGridCloseTransition dintty_grid_close_request(
    DinttyGridCloseCoordinator *coordinator,
    DinttyApplicationCloseOrigin origin);
DinttyGridCloseTransition dintty_grid_close_modal_begin(
    DinttyGridCloseCoordinator *coordinator);
DinttyGridCloseTransition dintty_grid_close_modal_end(
    DinttyGridCloseCoordinator *coordinator);
DinttyGridCloseTransition dintty_grid_close_source_fired(
    DinttyGridCloseCoordinator *coordinator, uint32_t source);
DinttyGridCloseTransition dintty_grid_close_preflight_result(
    DinttyGridCloseCoordinator *coordinator, int accepted);

enum {
    DINTTY_GRID_INPUT_POINTER = 1,
    DINTTY_GRID_INPUT_WHEEL = 2,
};

enum {
    DINTTY_GRID_MODIFIER_SHIFT = 1u << 0,
    DINTTY_GRID_MODIFIER_CONTROL = 1u << 1,
    DINTTY_GRID_MODIFIER_ALT = 1u << 2,
};
int dintty_grid_is_alt_key(uint32_t keyval);
uint32_t dintty_grid_input_modifiers(uint32_t state);
int dintty_grid_tray_menu_id_valid(int id);
void dintty_grid_tray_menu_plan(
    int id, DinttyGridTrayMenuItemPlan *plan);
void dintty_grid_workspace_event_plan(
    int event_code, int workspace_smoke,
    DinttyGridWorkspaceEventPlan *plan);
const char *dintty_grid_window_resize_cursor_name(int index);
const char *dintty_grid_tray_menu_label(int id, int window_presented);
const char *dintty_grid_tray_menu_icon_name(int id);
int dintty_grid_resize_edge(int index);

typedef struct {
    int action;
} DinttyGridResizeEventPlan;

enum {
    DINTTY_GRID_RESIZE_EVENT_PRESS = 1,
    DINTTY_GRID_RESIZE_EVENT_MOTION = 2,
    DINTTY_GRID_RESIZE_EVENT_RELEASE = 3,
    DINTTY_GRID_RESIZE_EVENT_DOUBLE_PRESS = 4,
    DINTTY_GRID_RESIZE_ACTION_NONE = 0,
    DINTTY_GRID_RESIZE_ACTION_TOGGLE_HEIGHT = 1,
    DINTTY_GRID_RESIZE_ACTION_ARM_CLICK = 2,
    DINTTY_GRID_RESIZE_ACTION_DELAY_DOUBLE_CLICK = 3,
    DINTTY_GRID_RESIZE_ACTION_BEGIN_DRAG = 4,
    DINTTY_GRID_RESIZE_ACTION_CONSUME = 5,
    DINTTY_GRID_RESIZE_ACTION_UPDATE_DRAG = 6,
    DINTTY_GRID_RESIZE_ACTION_FINISH_DRAG = 7
};

void dintty_grid_resize_event_plan(
    int event_kind, int handle, int button, int mode,
    int drag_active, int click_pending, int button1_down,
    double motion_distance_squared, DinttyGridResizeEventPlan *plan);

typedef struct {
    int action;
} DinttyGridWindowModePlan;

enum {
    DINTTY_GRID_WINDOW_MODE_ACTION_NONE = 0,
    DINTTY_GRID_WINDOW_MODE_ACTION_RECREATE = 1,
    DINTTY_GRID_WINDOW_MODE_ACTION_APPLY_DROPDOWN = 2,
    DINTTY_GRID_WINDOW_MODE_ACTION_APPLY_WINDOW = 3,
    DINTTY_GRID_WINDOW_MODE_ACTION_APPLY_FULLSCREEN = 4,
    DINTTY_GRID_WINDOW_MODE_ACTION_APPLY_LAYER_GEOMETRY = 5
};

void dintty_grid_window_mode_plan(
    int previous_mode, int mode, int layer_shell_active,
    DinttyGridWindowModePlan *plan);

typedef struct {
    int action;
    int lower_parent;
} DinttyGridOverlayStackingPlan;

enum {
    DINTTY_GRID_OVERLAY_STACKING_NONE = 0,
    DINTTY_GRID_OVERLAY_STACKING_BASIC = 1,
    DINTTY_GRID_OVERLAY_STACKING_EXISTING = 2,
    DINTTY_GRID_OVERLAY_STACKING_LAYER = 3
};

void dintty_grid_overlay_stacking_plan(
    int layer_shell_active, int layer_shell_library_available,
    int existing_overlay, int overlay_count,
    DinttyGridOverlayStackingPlan *plan);

typedef struct {
    int action;
} DinttyGridWindowVisibilityPlan;

enum {
    DINTTY_GRID_WINDOW_VISIBILITY_NONE = 0,
    DINTTY_GRID_WINDOW_VISIBILITY_HIDE = 1,
    DINTTY_GRID_WINDOW_VISIBILITY_SHOW = 2
};

void dintty_grid_window_visibility_plan(
    int window_presented, int window_visible,
    DinttyGridWindowVisibilityPlan *plan);

typedef struct {
    int left;
    int right;
    int top;
    int bottom;
} DinttyGridOverlayGeometryPlan;

void dintty_grid_overlay_geometry_plan(
    int workarea_x, int workarea_y, int workarea_width, int workarea_height,
    int monitor_x, int monitor_y, int monitor_width, int monitor_height,
    int window_width, int window_height,
    DinttyGridOverlayGeometryPlan *plan);

typedef struct {
    int action;
} DinttyGridFullscreenPlan;

enum {
    DINTTY_GRID_FULLSCREEN_WINDOW = 1,
    DINTTY_GRID_FULLSCREEN_CURRENT_MONITOR = 2,
    DINTTY_GRID_FULLSCREEN_MONITOR = 3
};

void dintty_grid_fullscreen_plan(
    int gdk_window_present, int wayland_display, int monitor_index,
    DinttyGridFullscreenPlan *plan);

typedef struct {
    int action;
    int width;
    int height;
    int left;
    int right;
    int bottom;
} DinttyGridLayerGeometryPlan;

enum {
    DINTTY_GRID_LAYER_GEOMETRY_NONE = 0,
    DINTTY_GRID_LAYER_GEOMETRY_DROPDOWN = 1,
    DINTTY_GRID_LAYER_GEOMETRY_ZEN = 2,
    DINTTY_GRID_LAYER_GEOMETRY_WINDOW = 3
};

void dintty_grid_layout_preset_plan(
    int event_code, DinttyGridLayoutPresetPlan *plan);

int dintty_grid_panel_settings_apply(
    int event_code, int value, DinttyGridPanelSettings *settings);

int dintty_grid_launch_profile_payload(
    int action,
    const unsigned char *name, size_t name_length,
    const unsigned char *shell, size_t shell_length,
    const unsigned char *command, size_t command_length,
    const unsigned char *cwd, size_t cwd_length,
    const unsigned char *ssh_target, size_t ssh_target_length,
    int scrollback,
    unsigned char *output, size_t capacity);
int dintty_grid_launch_profile_name_valid(
    const unsigned char *text, size_t length);
const char *dintty_grid_launch_profile_status_message(int kind);
void dintty_grid_launch_profile_controls_plan(
    int kind, DinttyGridLaunchProfileControlsPlan *plan);


int dintty_grid_theme_apply_status_text(
    int persistence_failed,
    const unsigned char *label, size_t label_length,
    int variant,
    unsigned char *output, size_t capacity);

int dintty_grid_decimal_text(
    int64_t value, unsigned char *output, size_t capacity);
int dintty_grid_terminal_accessible_name(
    uint64_t pane_id, unsigned char *output, size_t capacity);

void dintty_grid_layer_geometry_plan(
    int mode, int monitor_width, int monitor_height,
    int dropdown_width_px, int dropdown_width_percent,
    int dropdown_height_px, int dropdown_height_percent,
    DinttyGridLayerGeometryPlan *plan);

typedef struct {
    int action;
} DinttyGridMonitorSelectionPlan;

enum {
    DINTTY_GRID_MONITOR_SELECTION_NONE = 0,
    DINTTY_GRID_MONITOR_SELECTION_WINDOW = 1,
    DINTTY_GRID_MONITOR_SELECTION_PRIMARY = 2,
    DINTTY_GRID_MONITOR_SELECTION_POINTER = 3,
    DINTTY_GRID_MONITOR_SELECTION_FIRST = 4
};

void dintty_grid_monitor_selection_plan(
    int window_monitor, int primary_monitor,
    int pointer_monitor, int monitor_count,
    DinttyGridMonitorSelectionPlan *plan);
int dintty_grid_monitor_scale_factor(int raw_scale_factor);
int dintty_grid_monitor_metrics_changed(
    int geometry_x, int geometry_y, int geometry_width, int geometry_height,
    int workarea_x, int workarea_y, int workarea_width, int workarea_height,
    int scale_factor,
    int previous_geometry_x, int previous_geometry_y,
    int previous_geometry_width, int previous_geometry_height,
    int previous_workarea_x, int previous_workarea_y,
    int previous_workarea_width, int previous_workarea_height,
    int previous_scale_factor);
int dintty_grid_resize_handle_index(int stored_index);

enum {
    DINTTY_GRID_KEY_ACTION_NONE = 0,
    DINTTY_GRID_KEY_ACTION_SHOW_NOTE_OVERLAYS = 1,
    DINTTY_GRID_KEY_ACTION_HIDE_NOTE_OVERLAYS = 2,
    DINTTY_GRID_KEY_ACTION_CLEAR_SMART_FILTER = 3,
    DINTTY_GRID_KEY_ACTION_CYCLE_TAB = 4,
    DINTTY_GRID_KEY_ACTION_CYCLE_PANE = 5,
    DINTTY_GRID_KEY_ACTION_FOCUS_DIRECTION = 6,
};
enum {
    DINTTY_GRID_KEYBOARD_SCROLL_NONE = 0,
    DINTTY_GRID_KEYBOARD_SCROLL_PAGE_UP = 1,
    DINTTY_GRID_KEYBOARD_SCROLL_PAGE_DOWN = 2,
    DINTTY_GRID_KEYBOARD_SCROLL_HOME = 3,
    DINTTY_GRID_KEYBOARD_SCROLL_END = 4,
};

enum {
    DINTTY_GRID_TERMINAL_MODE_MOUSE = 1u << 0,
    DINTTY_GRID_TERMINAL_MODE_ALTERNATE_SCREEN = 1u << 1,
};

enum {
    DINTTY_GRID_ROUTE_IGNORE = 0,
    DINTTY_GRID_ROUTE_SCROLLBAR = 1,
    DINTTY_GRID_ROUTE_SELECTION = 2,
    DINTTY_GRID_ROUTE_APPLICATION_MOUSE = 3,
    DINTTY_GRID_ROUTE_TERMINAL_SCROLL = 4,
    DINTTY_GRID_ROUTE_TAB_CYCLE = 5,
    DINTTY_GRID_ROUTE_PANE_CYCLE = 6,
    DINTTY_GRID_ROUTE_FONT_ZOOM = 7,
    DINTTY_GRID_ROUTE_LOCAL_POINTER = 8,
    DINTTY_GRID_ROUTE_APPLICATION_KEYS = 9,
};

int dintty_grid_cycle_target(int count, int current_index,
                             int current_found, int direction);
void dintty_grid_directional_focus_begin(
    const DinttyGridRectangle *source, int dx, int dy,
    DinttyGridDirectionalFocusPlan *plan);
void dintty_grid_directional_focus_consider(
    DinttyGridDirectionalFocusPlan *plan,
    const DinttyGridRectangle *candidate, int candidate_index);
void dintty_grid_key_command_plan(
    int pressed, int alt_key, int smart_filter_clear_available,
    uint32_t keyval, uint32_t modifier_flags,
    DinttyGridKeyCommandPlan *plan);
void dintty_grid_key_chord_plan(
    uint32_t keyval, uint32_t state, DinttyGridKeyChordPlan *plan);
int dintty_grid_keyboard_scroll_action(uint32_t keyval);
void dintty_grid_pointer_event_plan(
    int event_kind, int button, int route, int hyperlink_point,
    int control_pressed, int background, int multiple_panes,
    int suppress_primary_release, int preserve_double_click_selection,
    DinttyGridPointerEventPlan *plan);
void dintty_grid_smart_filter_visibility_plan(
    int filter_active, int matches, int focused,
    int first_visible_seen,
    DinttyGridSmartFilterVisibilityPlan *plan);
void dintty_grid_smart_filter_summary_plan(
    int filter_active, int page_available,
    int first_visible, int focused_visible,
    DinttyGridSmartFilterSummaryPlan *plan);

int dintty_grid_host_event_code(int kind);
int dintty_grid_input_route(int input_kind, int scrollbar_owned,
                            int terminal_mode_flags, int history_available,
                            int primary_button, uint32_t modifier_flags);
void dintty_grid_wheel_action_plan(
    int route, int scroll_direction, double delta_y, double *accumulator,
    DinttyGridWheelActionPlan *plan);
void dintty_grid_scroll_route_plan(
    int scrollbar_owned, int terminal_mode_flags, int history_available,
    uint32_t modifier_flags, int scroll_direction, double delta_y,
    double *tab_accumulator, double *pane_accumulator,
    double *font_accumulator, DinttyGridScrollRoutePlan *plan);
void dintty_grid_selection_word_plan(
    void *userdata, int column, int row, int columns,
    DinttyGridCellTextReader cell_text,
    DinttyGridSelectionWordPlan *plan);
int dintty_grid_read_hyperlink(
    void *userdata, int column, int row, char *output, size_t capacity,
    DinttyGridCellHyperlinkReader cell_hyperlink);
int dintty_grid_wheel_key_sequence(int application_cursor, int steps,
                                   uint8_t *output, uint32_t capacity);
int dintty_grid_terminal_key_sequence(uint32_t keyval, uint32_t codepoint,
                                      uint32_t modifier_flags,
                                      int application_cursor, uint8_t *output,
                                      uint32_t capacity);
typedef struct {
    int label_length;
    int tooltip_length;
} DinttyGridShortcutTextPlan;

int dintty_grid_shortcut_label(uint32_t encoded, uint8_t *output,
                               uint32_t capacity);
int dintty_grid_shortcut_settings_text(
    uint32_t encoded, int plasma_transport,
    unsigned char *label, size_t label_capacity,
    unsigned char *tooltip, size_t tooltip_capacity,
    DinttyGridShortcutTextPlan *plan);
int dintty_grid_text_valid(const uint8_t *text, size_t length,
                           size_t max_length);
int dintty_grid_hyperlink_valid(const uint8_t *uri, uint32_t length);
int dintty_grid_accessible_granularity(int granularity);
void dintty_grid_accessible_offset_plan(
    int count, int start_offset, int end_offset,
    DinttyGridAccessibleOffsetPlan *plan);
void dintty_grid_accessible_range_plan(
    const uint8_t *text, size_t length, int offset, int granularity,
    DinttyGridAccessibleRangePlan *plan);
int dintty_grid_accessible_text_capacity(
    int columns, int rows, DinttyGridAccessibleTextPlan *plan);
int dintty_grid_accessible_cell_length(int length, int capacity);
size_t dintty_grid_accessible_trim_row_length(
    const uint8_t *bytes, size_t length);
size_t dintty_grid_accessible_trim_newline_length(
    const uint8_t *bytes, size_t length);
int dintty_grid_pane_tooltip(
    uint64_t pane_id,
    const unsigned char *status, size_t status_length,
    const unsigned char *tags, size_t tags_length,
    unsigned char *output, size_t capacity);

void dintty_grid_output_present_plan(
    int session_available, int exited, int source_active, int mapped,
    DinttyGridOutputPresentPlan *plan);
int dintty_grid_settings_event_code(int kind);

void dintty_grid_lifecycle_timing_plan(
    DinttyGridLifecycleTimingPlan *plan);
void dintty_grid_native_host_policy(DinttyGridNativeHostPolicy *policy);
void dintty_grid_zoom_plan(
    uint64_t zoomed_pane_id, uint64_t pane_id, DinttyGridZoomPlan *plan);

enum {
    DINTTY_GRID_RECOVERY_CONFIG_BACKUP = 1u << 0,
    DINTTY_GRID_RECOVERY_CONFIG_DEFAULTS = 1u << 1,
    DINTTY_GRID_RECOVERY_THEME_BACKUP = 1u << 2,
    DINTTY_GRID_RECOVERY_THEME_DEFAULTS = 1u << 3,
    DINTTY_GRID_RECOVERY_WORKSPACE_DEFAULTS = 1u << 4,
};

int dintty_grid_recovery_notice_text(
    uint32_t flags, unsigned char *output, size_t capacity);

int dintty_grid_smoke_schedule(
    int workspace_smoke, int activation_child_receipt,
    DinttyGridSmokeScheduleStep *steps, int capacity);
int dintty_grid_fuzzy_match_ascii(const uint8_t *haystack,
                                  uint32_t haystack_length,
                                  const uint8_t *needle,
                                  uint32_t needle_length);
int dintty_grid_dropdown_dimension(int stored_px, int percent,
                                   int available_px, int minimum_px);
int dintty_grid_dropdown_percent(int pixels, int available_px,
                                 int fallback_percent);
int dintty_grid_dialog_dimension(
    int available_px, int maximum_px, int minimum_px, int margin_px);
int dintty_grid_percent_dimension(
    int available_px, int percent, int minimum_px);
void dintty_grid_window_dimensions_plan(
    int workarea_width, int workarea_height,
    DinttyGridWindowDimensionsPlan *plan);
typedef struct {
    int label_height;
    int action_extent;
    int strip_limit;
} DinttyGridCompactTabMetrics;

void dintty_grid_compact_tab_metrics(
    int tab_height, DinttyGridCompactTabMetrics *metrics);

typedef struct {
    int horizontal;
    int notebook_width;
    int notebook_height;
    int page_width;
    int page_height;
    int tab_width;
    int tab_height;
    int max_tab_width;
    int close_width;
    int close_height;
    int action_width;
    int action_height;
} DinttyGridCompactTabMeasurements;

typedef struct {
    int strip_extent;
    int widget_extent;
    int max_width;
    int close_extent;
    int action_extent;
} DinttyGridCompactTabGeometry;

void dintty_grid_compact_tab_geometry(
    const DinttyGridCompactTabMeasurements *measurements,
    DinttyGridCompactTabGeometry *geometry);

typedef struct {
    const unsigned char *title;
    size_t title_length;
    const unsigned char *filter;
    size_t filter_length;
    const unsigned char *status_color;
    size_t status_color_length;
    uint32_t pane_count;
    uint32_t selected_count;
    int filter_active;
    int attention;
    int dirty;
    int broadcast;
    int active;
    uint32_t tab_color_rgb;
    int tab_color_preset;
    int tab_color_shade;
} DinttyGridCompactTabTextInput;

typedef struct {
    int markup_length;
    int tooltip_length;
    int close_name_length;
    int title_truncated;
} DinttyGridCompactTabTextPlan;
typedef struct {
    int empty_length;
    int label_length;
    int tooltip_length;
} DinttyGridSmartFilterTextPlan;


int dintty_grid_compact_tab_text(
    const DinttyGridCompactTabTextInput *input,
    unsigned char *markup, size_t markup_capacity,
    unsigned char *tooltip, size_t tooltip_capacity,
    unsigned char *close_name, size_t close_name_capacity,
    DinttyGridCompactTabTextPlan *plan);
int dintty_grid_smart_filter_text(
    int active, const unsigned char *tag, size_t tag_length,
    unsigned char *empty_text, size_t empty_capacity,
    unsigned char *label, size_t label_capacity,
    unsigned char *tooltip, size_t tooltip_capacity,
    DinttyGridSmartFilterTextPlan *plan);

int dintty_grid_cycle_feedback_text(
    int kind, int index, int count,
    unsigned char *output, size_t capacity);

int dintty_grid_attention_notification_text(
    uint64_t pane_id, int attention, int exit_code,
    unsigned char *output, size_t capacity);

int dintty_grid_tab_title_text(
    const unsigned char *model_title, size_t model_length,
    const unsigned char *display_title, size_t display_length,
    const unsigned char *directory_name, size_t directory_length,
    int page_number, unsigned char *output, size_t capacity);

int dintty_grid_pane_zoom_feedback_text(
    uint64_t pane_id,
    const unsigned char *title, size_t title_length,
    const unsigned char *display_title, size_t display_length,
    unsigned char *output, size_t capacity);
const char *dintty_grid_shortcut_feedback_message(int kind);
const char *dintty_grid_tab_rename_feedback_message(int kind);

int dintty_grid_note_overlay_label(
    const unsigned char *text, size_t text_length,
    unsigned char *output, size_t capacity);
int dintty_grid_window_title_text(
    int mode, const unsigned char *title, size_t title_length,
    unsigned char *output, size_t capacity);
int dintty_grid_close_confirmation_text(
    const unsigned char *scope, size_t scope_length, uint32_t busy_count,
    unsigned char *title, size_t title_capacity,
    unsigned char *detail, size_t detail_capacity,
    unsigned char *secondary_action, size_t secondary_capacity,
    unsigned char *primary_action, size_t primary_capacity);
int dintty_grid_layout_prompt_text(
    uint32_t extra_count,
    unsigned char *title, size_t title_capacity,
    unsigned char *detail, size_t detail_capacity,
    unsigned char *secondary_action, size_t secondary_capacity,
    unsigned char *primary_action, size_t primary_capacity);
int dintty_grid_find_status_text(
    int state, uint64_t ordinal, int matches,
    unsigned char *output, size_t capacity);
int dintty_grid_shortcuts_text(
    uint32_t encoded, unsigned char *output, size_t capacity);
int dintty_grid_sharing_peer_label(
    const unsigned char *alias, size_t alias_length,
    const unsigned char *endpoint, size_t endpoint_length,
    uint32_t port, unsigned char *output, size_t capacity);
int dintty_grid_sharing_tab_label(
    const unsigned char *title, size_t title_length,
    uint64_t tab_id, int active,
    unsigned char *output, size_t capacity);
int dintty_grid_sharing_pane_label(
    const unsigned char *title, size_t title_length,
    uint64_t pane_id, unsigned char *output, size_t capacity);
int dintty_grid_sharing_revoke_detail(
    const unsigned char *peer, size_t peer_length,
    unsigned char *output, size_t capacity);

enum {
    DINTTY_GRID_FEEDBACK_SCROLL_HISTORY = 1,
    DINTTY_GRID_FEEDBACK_PASTE,
    DINTTY_GRID_FEEDBACK_COPY,
    DINTTY_GRID_FEEDBACK_TERMINAL_STATE,
    DINTTY_GRID_FEEDBACK_CTRL_L,
    DINTTY_GRID_FEEDBACK_INPUT_FLUSH,
    DINTTY_GRID_FEEDBACK_RECOVERY_SAVE,
    DINTTY_GRID_FEEDBACK_INTERRUPT,
    DINTTY_GRID_FEEDBACK_DELIVER_INPUT,
    DINTTY_GRID_FEEDBACK_OPEN_BROWSER,
    DINTTY_GRID_FEEDBACK_LINK_TYPE,
    DINTTY_GRID_FEEDBACK_LINK_COPIED,
    DINTTY_GRID_FEEDBACK_POINTER_INPUT,
    DINTTY_GRID_FEEDBACK_BROADCAST_DISABLED,
    DINTTY_GRID_FEEDBACK_MOUSE_WHEEL,
    DINTTY_GRID_FEEDBACK_ALT_SCROLL,
    DINTTY_GRID_FEEDBACK_COMPOSED_TEXT,
};

const char *dintty_grid_status_feedback_message(int kind);

typedef struct {
    int width;
    int height;
    int min_width;
    int min_height;
    int max_width;
    int max_height;
} DinttyGridSettingsGeometryPlan;

void dintty_grid_settings_geometry_plan(
    int workarea_width, int workarea_height,
    DinttyGridSettingsGeometryPlan *plan);
int dintty_grid_scroll_target_delta(
    uint64_t history_lines, uint64_t viewport_offset, uint64_t target_offset);
int dintty_grid_tab_title_width(int title_length);
uint64_t dintty_grid_search_display_ordinal(
    uint64_t ordinal, int matches);
int dintty_grid_selection_end(int length);
int dintty_grid_partition_size(int total, int parts);

enum {
    DINTTY_GRID_SHARING_ALLOW_PAIRING = 1u << 0,
    DINTTY_GRID_SHARING_ALLOW_SESSION = 1u << 1,
    DINTTY_GRID_SHARING_CLEAR_HOST = 1u << 2,
    DINTTY_GRID_SHARING_CLEAR_VIEWER = 1u << 3,
};
uint32_t dintty_grid_sharing_status_actions(int status);

typedef struct {
    uint32_t enabled;
    int stop_label;
    int stop_receive_label;
    int revoke_label;
    int cancel_pairing_label;
} DinttyGridSharingControlPlan;
typedef struct {
    int length;
    int is_error;
} DinttyGridSharingStatusTextPlan;

int dintty_grid_sharing_status_text(
    int status, uint32_t sas, uint16_t port,
    const unsigned char *alias, size_t alias_length,
    const unsigned char *endpoint, size_t endpoint_length,
    uint16_t discovered_port, int discovered,
    unsigned char *output, size_t capacity,
    DinttyGridSharingStatusTextPlan *plan);


enum {
    DINTTY_GRID_SHARING_CONTROL_CONFIRM = 1u << 0,
    DINTTY_GRID_SHARING_CONTROL_PAIRING = 1u << 1,
    DINTTY_GRID_SHARING_CONTROL_DISCOVER = 1u << 2,
    DINTTY_GRID_SHARING_CONTROL_SESSION = 1u << 3,
    DINTTY_GRID_SHARING_CONTROL_PEERS = 1u << 4,
    DINTTY_GRID_SHARING_CONTROL_REVOKE_DEVICE = 1u << 5,
    DINTTY_GRID_SHARING_CONTROL_STOP = 1u << 6,
    DINTTY_GRID_SHARING_CONTROL_CANCEL_PAIRING = 1u << 7,
    DINTTY_GRID_SHARING_CONTROL_GRANT = 1u << 8,
    DINTTY_GRID_SHARING_CONTROL_REVOKE = 1u << 9,
    DINTTY_GRID_SHARING_CONTROL_STOP_RECEIVE = 1u << 10,
    DINTTY_GRID_SHARING_CONTROL_REQUEST_CONTROL = 1u << 11,
    DINTTY_GRID_SHARING_CONTROL_RECONNECT = 1u << 12,
    DINTTY_GRID_SHARING_CONTROL_RETRY_SAVE = 1u << 13,
};

enum {
    DINTTY_GRID_SHARING_LABEL_STOP = 0,
    DINTTY_GRID_SHARING_LABEL_CLOSE_SHARING = 1,
    DINTTY_GRID_SHARING_LABEL_STOP_RECEIVING = 0,
    DINTTY_GRID_SHARING_LABEL_CLOSE_REMOTE = 1,
    DINTTY_GRID_SHARING_LABEL_REVOKE_CONTROL = 0,
    DINTTY_GRID_SHARING_LABEL_DENY_CONTROL = 1,
    DINTTY_GRID_SHARING_LABEL_CANCEL_PAIRING = 0,
    DINTTY_GRID_SHARING_LABEL_CLEAR_PAIRING = 1,
};

void dintty_grid_sharing_control_plan(
    int status, int active_peer_count,
    DinttyGridSharingControlPlan *plan);
int dintty_grid_bracketed_paste_marker(
    int kind, unsigned char *output, size_t capacity);
int dintty_grid_sharing_key_sequence(
    int kind, int application_cursor, unsigned char *output, size_t capacity);
int dintty_grid_sharing_extended_key_sequence(
    int kind, int modifier, unsigned char *output, size_t capacity);
int dintty_grid_sharing_text_sequence(
    int alt, const unsigned char *input, size_t length,
    unsigned char *output, size_t capacity);
int dintty_grid_sharing_arrow_sequence(
    int arrow, int modifier, int application_cursor,
    unsigned char *output, size_t capacity);
int dintty_grid_sharing_key_event_sequence(
    uint32_t keyval, uint32_t state, int application_cursor,
    const unsigned char *input, size_t length,
    unsigned char *output, size_t capacity);
int dintty_grid_sharing_paste_allowed(size_t length);
size_t dintty_grid_sharing_paste_chunk_size(size_t remaining);
size_t dintty_grid_damage_buffer_capacity(int rows);
size_t dintty_grid_selection_copy_capacity_next(size_t current);
int dintty_grid_sharing_preview_scroll_lines(int direction, double delta_y);
int dintty_grid_sharing_index(const unsigned char *text, size_t length);
int dintty_grid_sharing_index_text(
    int index, unsigned char *output, size_t capacity);
int dintty_grid_theme_color_text(
    double red, double green, double blue,
    unsigned char *output, size_t capacity);
double dintty_grid_theme_color_channel(uint32_t rgb, int channel);
int dintty_grid_terminal_scroll_setting(int event_code, int value);
void dintty_grid_compact_setting_plan(
    int field, DinttyGridCompactSettingPlan *plan);
void dintty_grid_settings_plan(
    DinttyGridCompactSettingReader reader,
    void *userdata,
    int available,
    DinttyGridSettingsPlan *plan);
void dintty_grid_font_rendering_plan(
    int event_code, int value, DinttyGridFontRenderingPlan *plan);
void dintty_grid_terminal_menu_plan(
    int action, int columns, int rows, DinttyGridTerminalMenuPlan *plan);
int dintty_grid_theme_display_label(
    const unsigned char *name, size_t name_length,
    unsigned char *output, size_t capacity);

double dintty_grid_font_size_clamp(
    double requested, double minimum, double maximum);
int dintty_grid_font_size_event_value(
    double requested, double minimum, double maximum);
int dintty_grid_panel_metric_value(int event_code, int value);
int dintty_grid_background_opacity_value(int value);
int dintty_grid_sharing_pane_hit(
    double x, double y, double width, double height,
    double pane_x, double pane_y, double pane_width, double pane_height);

int dintty_grid_scroll_direction(int direction);
const char *dintty_grid_tab_color_preset_name(int preset);
const char *dintty_grid_tab_color_shade_name(int shade);
int dintty_grid_scrollbar_geometry(
    int allocation_width, int allocation_height, double scrollbar_width,
    double thumb_height_min, uint64_t history_lines,
    uint64_t viewport_offset, uint32_t visible_rows,
    DinttyTerminalScrollbarGeometry *geometry);
void dintty_grid_scrollbar_press_plan(
    const DinttyTerminalScrollbarGeometry *geometry, double pointer_y,
    DinttyTerminalScrollbarPressPlan *plan);
int dintty_grid_scrollbar_drag_target(
    const DinttyTerminalScrollbarGeometry *geometry, double pointer_y,
    double drag_offset, uint64_t *target_offset);
int dintty_grid_cell_selected(int selecting, int start_column, int start_row,
                              int end_column, int end_row, int column,
                              int row);
typedef struct {
    int first_row;
    int end_row;
    int first_column;
    int end_column;
} DinttyGridRenderViewport;

typedef struct {
    uint32_t status_role;
    uint32_t status_fallback;
    uint32_t pane_role;
    uint32_t pane_fallback;
    int pane_width;
    double pane_inset;
    int caret_draw;
    double caret_x;
    double caret_y;
    double caret_width;
    double caret_height;
} DinttyGridRenderChrome;

int dintty_grid_render_viewport(
    double clip_x1, double clip_y1, double clip_x2, double clip_y2,
    double cell_width, double cell_height, int columns, int rows,
    DinttyGridRenderViewport *output);
void dintty_grid_render_chrome(
    int status_kind, int focused, int selected, int pane_width,
    int focused_width, int selected_width, int cursor_visible,
    int cursor_live, int cursor_column, int cursor_row, int columns,
    int rows, double cell_width, double cell_height,
    DinttyGridRenderChrome *output);
void dintty_grid_status_plan(
    int status_kind, int attention,
    DinttyGridStatusPlan *plan);
void dintty_grid_status_color_plan(
    int status_kind, int attention,
    DinttyGridStatusColorPlan *plan);
void dintty_grid_notebook_chrome_plan(
    uint64_t zoomed_pane_id, int page_count,
    DinttyGridNotebookChromePlan *plan);

typedef struct {
    uint32_t codepoint;
    uint32_t style;
    uint32_t foreground;
    uint32_t background;
    int face;
    double alpha;
    int drawable;
    int ascii;
    int grapheme;
    int decorated;
} DinttyGridRenderCell;

int dintty_grid_codepoint_utf8(uint32_t codepoint, uint8_t *output,
                               uint32_t output_size);
void dintty_grid_render_cell(uint64_t packed_cell,
                             DinttyGridRenderCell *output);
int dintty_grid_render_run_end(const uint64_t *cells, int start, int end,
                               int kind);
void dintty_grid_damage_rect(
    double x, double y, double width, double height,
    int allocation_width, int allocation_height,
    DinttyGridDamageRect *output);
void dintty_grid_cursor_damage(
    int column, int row, double cell_width, double cell_height,
    DinttyGridDamageRect *output);
void dintty_grid_cursor_position(
    uint32_t packed_cursor, DinttyGridCursorPosition *output);
double dintty_grid_background_alpha(
    int translucency, int alpha_supported, double opacity_percent);

void dintty_grid_cell_span(int first, int end, int row, double cell_width,
                           double cell_height, int snap_horizontal,
                           DinttyGridRectangle *rectangle);
void dintty_grid_panel_spacing_plan(
    int enabled, int spacing_px,
    DinttyGridPanelSpacingPlan *plan);
void dintty_grid_auto_fit_bounds(
    int allocation_width, int allocation_height,
    int candidate_width, int candidate_height,
    DinttyGridAutoFitBounds *bounds);
int dintty_grid_resize_plan(
    int allocation_width, int allocation_height,
    double scrollbar_width, double cell_width, double cell_height,
    int current_columns, int current_rows,
    DinttyGridResizePlan *plan);
void dintty_grid_row_span(int first, int end, double cell_height,
                          DinttyGridRectangle *rectangle);
int dintty_grid_scroll_steps(int configured_lines, int smooth_enabled,
                             int direction, double delta_y,
                             double *accumulator);
uint64_t dintty_grid_keyboard_scroll_target(uint64_t history_lines,
                                            uint64_t viewport_offset,
                                            uint32_t visible_rows, int action);
void dintty_grid_font_metrics(double requested_points,
                              DinttyGridFontMetrics *metrics);
void dintty_grid_auto_fit(double base_size, int fit_width, int fit_height,
                          int enabled, double *next_size, int *zoom_percent,
                          int *floor_reached);
int dintty_grid_dimensions(int allocation_width, int allocation_height,
                           double scrollbar_width, double cell_width,
                           double cell_height, int *terminal_width,
                           int *columns, int *rows);
uint32_t dintty_grid_scale_brightness(
    uint32_t rgb, int enabled, int active, int percent);

int dintty_grid_pane_is_active(uint64_t active_pane_id,
                               uint64_t pane_id, int focused);
const char *dintty_grid_status_name(int status_kind);
const char *dintty_grid_profile_preset_label(int preset);
int dintty_grid_profile_preset_valid(int preset);
const char *dintty_grid_broadcast_menu_label(int enabled);
const char *dintty_grid_shortcut_field(int field, int smoke);
typedef struct {
    int column;
    int row;
    int width;
    int height;
} DinttyGridResizeHandleLayout;
int dintty_grid_resize_handle_layout(int index, int border_px,
                                     int dragger_px,
                                     DinttyGridResizeHandleLayout *output);
int dintty_grid_snap_pane_position(int max_position, int position);
unsigned int dintty_grid_palette_actions(
    DinttyPaletteAction *output, unsigned int capacity);
typedef struct {
    int action;
    int event_code;
    int value;
    int valid;
} DinttyGridPaletteDispatchPlan;
enum {
    DINTTY_GRID_PALETTE_DISPATCH_NONE = 0,
    DINTTY_GRID_PALETTE_DISPATCH_WORKSPACE_EVENT = 1,
    DINTTY_GRID_PALETTE_DISPATCH_ZOOM = 2,
    DINTTY_GRID_PALETTE_DISPATCH_FIND = 3,
    DINTTY_GRID_PALETTE_DISPATCH_NOTE = 4,
    DINTTY_GRID_PALETTE_DISPATCH_BROADCAST = 5,
    DINTTY_GRID_PALETTE_DISPATCH_SETTINGS = 6,
    DINTTY_GRID_PALETTE_DISPATCH_THEME = 7,
    DINTTY_GRID_PALETTE_DISPATCH_PROJECT = 8,
    DINTTY_GRID_PALETTE_DISPATCH_EDITOR = 9,
    DINTTY_GRID_PALETTE_DISPATCH_SCROLLBACK = 10,
    DINTTY_GRID_PALETTE_DISPATCH_AGENT_SET = 11,
    DINTTY_GRID_PALETTE_DISPATCH_AGENT_CLEAR = 12,
    DINTTY_GRID_PALETTE_DISPATCH_HISTORY = 13,
    DINTTY_GRID_PALETTE_DISPATCH_PENDING_AGENT = 14,
    DINTTY_GRID_PALETTE_DISPATCH_SHORTCUTS = 15,
    DINTTY_GRID_PALETTE_DISPATCH_WINDOW = 16,
    DINTTY_GRID_PALETTE_DISPATCH_SETTINGS_EVENT = 17,
    DINTTY_GRID_PALETTE_DISPATCH_RENAME = 18,
    DINTTY_GRID_PALETTE_DISPATCH_SMART_FILTER = 19,
    DINTTY_GRID_PALETTE_DISPATCH_TAG_SELECTED = 20,
    DINTTY_GRID_PALETTE_DISPATCH_TAG_REMOVE = 21,
    DINTTY_GRID_PALETTE_DISPATCH_TAB_COLOR = 22,
};
void dintty_grid_palette_action_plan(
    int id, int high_contrast, int tab_position,
    DinttyGridPaletteDispatchPlan *plan);
typedef struct {
    int orientation;
    int reverse;
    int rendered_event;
    int valid;
} DinttyGridSplitRenderPlan;
enum {
    DINTTY_GRID_SPLIT_ORIENTATION_HORIZONTAL = 0,
    DINTTY_GRID_SPLIT_ORIENTATION_VERTICAL = 1,
};
void dintty_grid_split_render_plan(
    int event_code, DinttyGridSplitRenderPlan *plan);
typedef struct {
    int valid;
    size_t start;
    size_t length;
    const char *message;
} DinttyGridTabRenamePlan;
void dintty_grid_tab_rename_plan(
    const unsigned char *text, size_t length, DinttyGridTabRenamePlan *plan);
int dintty_grid_session_dimension(int value);
typedef struct {
    const char *label;
    unsigned int role;
} DinttyGridWorkspaceColor;
int dintty_grid_workspace_color(int index, DinttyGridWorkspaceColor *output);
typedef struct {
    int x;
    int y;
    int width;
    int height;
} DinttyGridAdaptiveWindowGeometry;

int dintty_grid_adapt_window_geometry(
    int mode, int current_x, int current_y, int current_width,
    int current_height, int workarea_x, int workarea_y,
    int workarea_width, int workarea_height, int dropdown_width,
    int dropdown_height, DinttyGridAdaptiveWindowGeometry *output);

void dintty_grid_resize_delta(int handle, double start_x, double start_y,
                              double pointer_x, double pointer_y,
                              double *horizontal, double *vertical);
int dintty_grid_clamp_resize(int start, double delta, int minimum,
                             int maximum);
int dintty_grid_pointer_cell(double x, double y, double cell_width,
                             double cell_height, int columns, int rows,
                             int clamp, int *column, int *row);

int dintty_grid_cell_is_background(const unsigned char *text, int length);
#endif
