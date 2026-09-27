#ifndef NOCTTY_NATIVE_GRID_LOGIC_H
#define NOCTTY_NATIVE_GRID_LOGIC_H

#include <stddef.h>
#include <stdint.h>

int noctty_grid_split_ratio(int position, int extent);
int noctty_grid_split_position(int extent, int ratio);

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
} NocttyTerminalScrollbarGeometry;

typedef struct {
    int action;
    double drag_offset;
    uint64_t target_offset;
} NocttyTerminalScrollbarPressPlan;

enum {
    NOCTTY_GRID_SCROLLBAR_PRESS_NONE = 0,
    NOCTTY_GRID_SCROLLBAR_PRESS_DRAG = 1,
    NOCTTY_GRID_SCROLLBAR_PRESS_PAGE = 2,
};

typedef struct {
    double font_px;
    double cell_width;
    double cell_height;
} NocttyGridFontMetrics;

typedef struct {
    int leading;
    int trailing;
} NocttyGridPanelSpacingPlan;

typedef struct {
    int width;
    int height;
} NocttyGridAutoFitBounds;

typedef struct {
    int terminal_width;
    int columns;
    int rows;
    int changed;
} NocttyGridResizePlan;


typedef struct {
    int active_kind;
    int changed;
} NocttyGridStatusPlan;

typedef struct {
    uint32_t role;
    uint32_t fallback;
    int muted;
} NocttyGridStatusColorPlan;

typedef struct {
    int show;
} NocttyGridNotebookChromePlan;
typedef struct {
    double x;
    double y;
    double width;
    double height;
} NocttyGridRectangle;
typedef struct {
    int x;
    int y;
    int width;
    int height;
} NocttyGridDamageRect;

typedef struct {
    int column;
    int row;
    int valid;
} NocttyGridCursorPosition;
typedef struct {
    int steps;
    int direction;
} NocttyGridWheelActionPlan;

typedef struct {
    int visible;
    int first_visible;
    int focused_visible;
} NocttyGridSmartFilterVisibilityPlan;

typedef struct {
    int focus_first;
    int show_empty;
} NocttyGridSmartFilterSummaryPlan;

typedef struct {
    int start;
    int end;
    int valid;
} NocttyGridAccessibleOffsetPlan;
typedef struct {
    int start;
    int end;
    int valid;
} NocttyGridAccessibleRangePlan;
typedef struct {
    int start_hidden;
    int apply_activation;
    int show_layout_only;
} NocttyGridStartupWindowPlan;

typedef struct {
    int delay_ms;
    int action;
    int target;
} NocttyGridSmokeScheduleStep;
typedef struct {
    int schedule;
    int use_tick;
    int timeout_ms;
} NocttyGridOutputPresentPlan;
typedef struct {
    int unzoom;
    int enter;
} NocttyGridZoomPlan;

enum {
    NOCTTY_GRID_SMOKE_TARGET_CONTEXT = 0,
    NOCTTY_GRID_SMOKE_TARGET_PEER = 1,
};

enum {
    NOCTTY_GRID_SMOKE_ACTION_WRITE_ACTIVATION_CHILD_RECEIPT = 1,
    NOCTTY_GRID_SMOKE_ACTION_EMIT_WORKSPACE_TAB,
    NOCTTY_GRID_SMOKE_ACTION_EMIT_WORKSPACE_SPLIT,
    NOCTTY_GRID_SMOKE_ACTION_EMIT_WORKSPACE_SPLIT_LEFT,
    NOCTTY_GRID_SMOKE_ACTION_EMIT_WORKSPACE_BROADCAST,
    NOCTTY_GRID_SMOKE_ACTION_EMIT_WORKSPACE_SELECT,
    NOCTTY_GRID_SMOKE_ACTION_EMIT_WORKSPACE_TAG_FILTER,
    NOCTTY_GRID_SMOKE_ACTION_EMIT_WORKSPACE_FOCUS,
    NOCTTY_GRID_SMOKE_ACTION_EMIT_WORKSPACE_MOVE,
    NOCTTY_GRID_SMOKE_ACTION_FINISH_WORKSPACE,
    NOCTTY_GRID_SMOKE_ACTION_REQUEST_NEW_TAB_BUTTON,
    NOCTTY_GRID_SMOKE_ACTION_INSPECT_COMPACT_TAB_GEOMETRY,
    NOCTTY_GRID_SMOKE_ACTION_REQUEST_TAB_CLOSE,
    NOCTTY_GRID_SMOKE_ACTION_REQUEST_CLIPBOARD,
    NOCTTY_GRID_SMOKE_ACTION_INSPECT_WINDOW_TOOLBAR,
    NOCTTY_GRID_SMOKE_ACTION_REQUEST_SETTINGS,
    NOCTTY_GRID_SMOKE_ACTION_REQUEST_WINDOW_CLOSE_BUTTON,
    NOCTTY_GRID_SMOKE_ACTION_REQUEST_THEME,
    NOCTTY_GRID_SMOKE_ACTION_REQUEST_PROJECT,
    NOCTTY_GRID_SMOKE_ACTION_REQUEST_RECURSIVE_ZOOM,
    NOCTTY_GRID_SMOKE_ACTION_DRIVE_FOCUS_CLICK,
    NOCTTY_GRID_SMOKE_ACTION_EMIT_BALANCED_SPLIT,
    NOCTTY_GRID_SMOKE_ACTION_MOVE_LAST_PANE,
    NOCTTY_GRID_SMOKE_ACTION_REQUEST_COMPACT_HYPERLINK,
    NOCTTY_GRID_SMOKE_ACTION_REQUEST_COMPACT_PALETTE,
    NOCTTY_GRID_SMOKE_ACTION_REQUEST_COMPACT_FIND,
    NOCTTY_GRID_SMOKE_ACTION_REQUEST_COMPACT_NOTE,
    NOCTTY_GRID_SMOKE_ACTION_REQUEST_COMPACT_ZOOM,
    NOCTTY_GRID_SMOKE_ACTION_REQUEST_COMPACT_NAVIGATION,
    NOCTTY_GRID_SMOKE_ACTION_INSPECT_COMPACT_PANE_INFO,
    NOCTTY_GRID_SMOKE_ACTION_REQUEST_COMPACT_FONT_SCROLL,
    NOCTTY_GRID_SMOKE_ACTION_REQUEST_COMPACT_LINEAR_SELECTION,
    NOCTTY_GRID_SMOKE_ACTION_REQUEST_COMPACT_SAVE,
    NOCTTY_GRID_SMOKE_ACTION_REQUEST_PANE_SCROLLBAR,
    NOCTTY_GRID_SMOKE_ACTION_FINISH_COMPACT,
    NOCTTY_GRID_SMOKE_ACTION_REQUEST_TAB_RENAME,
    NOCTTY_GRID_SMOKE_ACTION_CHECK_RESIZE_OVERLAY_HIDDEN,
    NOCTTY_GRID_SMOKE_ACTION_MOVE_RESIZE_OVERLAY,
    NOCTTY_GRID_SMOKE_ACTION_CHECK_RESIZE_OVERLAY_VISIBLE,
    NOCTTY_GRID_SMOKE_ACTION_FINISH_RESIZE_OVERLAY,
    NOCTTY_GRID_SMOKE_ACTION_EMIT_PANE_CLOSE_PRIMARY,
    NOCTTY_GRID_SMOKE_ACTION_EMIT_PANE_CLOSE_SECONDARY,
    NOCTTY_GRID_SMOKE_ACTION_INSPECT_PANE_CLOSE_LAYOUT,
    NOCTTY_GRID_SMOKE_ACTION_DISTURB_PANE_CLOSE_LAYOUT,
    NOCTTY_GRID_SMOKE_ACTION_REQUEST_PANE_CLOSE,
    NOCTTY_GRID_SMOKE_ACTION_START_LAYOUT_PRESET,
    NOCTTY_GRID_SMOKE_ACTION_START_TAB_NAVIGATION,
    NOCTTY_GRID_SMOKE_ACTION_CHECK_TITLE_FALLBACK,
    NOCTTY_GRID_SMOKE_ACTION_EMIT_TITLE_OVERFLOW,
    NOCTTY_GRID_SMOKE_ACTION_CHECK_TITLE_OVERFLOW,
    NOCTTY_GRID_SMOKE_ACTION_CHECK_TITLE_RENAME,
    NOCTTY_GRID_SMOKE_ACTION_FINISH_TITLE,
    NOCTTY_GRID_SMOKE_ACTION_TRIGGER_DIRTY,
    NOCTTY_GRID_SMOKE_ACTION_EMIT_ATTENTION,
    NOCTTY_GRID_SMOKE_ACTION_CHECK_DIRTY,
    NOCTTY_GRID_SMOKE_ACTION_CHECK_ATTENTION,
    NOCTTY_GRID_SMOKE_ACTION_SAVE_DIRTY,
    NOCTTY_GRID_SMOKE_ACTION_CHECK_DIRTY_CLEAR,
    NOCTTY_GRID_SMOKE_ACTION_ACKNOWLEDGE_ATTENTION,
    NOCTTY_GRID_SMOKE_ACTION_ANNOUNCE_REORDER,
    NOCTTY_GRID_SMOKE_ACTION_CHECK_REORDER,
    NOCTTY_GRID_SMOKE_ACTION_PERSIST_REORDER,
    NOCTTY_GRID_SMOKE_ACTION_PALETTE_RENAME,
    NOCTTY_GRID_SMOKE_ACTION_REQUEST_TAB_COLOR,
    NOCTTY_GRID_SMOKE_ACTION_REQUEST_SETTINGS_STACKING,
    NOCTTY_GRID_SMOKE_ACTION_CHECK_SETTINGS_STACKING,
    NOCTTY_GRID_SMOKE_ACTION_REQUEST_NOTE_OVERLAY_ALT,
    NOCTTY_GRID_SMOKE_ACTION_CHECK_NOTE_OVERLAY,
    NOCTTY_GRID_SMOKE_ACTION_REQUEST_TERMINAL_INTERRUPT,
    NOCTTY_GRID_SMOKE_ACTION_REQUEST_TERMINAL_CLOSE,
    NOCTTY_GRID_SMOKE_ACTION_REQUEST_TERMINAL_FINAL_GUARD,
    NOCTTY_GRID_SMOKE_ACTION_FINISH_TERMINAL_CHORD,
    NOCTTY_GRID_SMOKE_ACTION_REQUEST_PROFILE_PRESET,
    NOCTTY_GRID_SMOKE_ACTION_REQUEST_RECENT_WORKSPACE_CHILD,
    NOCTTY_GRID_SMOKE_ACTION_START_PRESENTATION,
    NOCTTY_GRID_SMOKE_ACTION_START_FULL_STACK,
    NOCTTY_GRID_SMOKE_ACTION_POLL_CONTINUITY_DETACH,
    NOCTTY_GRID_SMOKE_ACTION_START_STABILITY,
    NOCTTY_GRID_SMOKE_ACTION_REQUEST_SHARING_SCOPE,
    NOCTTY_GRID_SMOKE_ACTION_REQUEST_WINDOW_RESIZE,
};

typedef struct {
    int initial_capacity;
} NocttyGridAccessibleTextPlan;

typedef struct {
    int route;
    int steps;
    int direction;
} NocttyGridScrollRoutePlan;

typedef struct {
    int valid;
    int start_column;
    int end_column;
} NocttyGridSelectionWordPlan;

typedef int (*NocttyGridCellTextReader)(
    void *, int, int, char *, size_t);
typedef int (*NocttyGridCellHyperlinkReader)(
    void *, int, int, char *, size_t);

typedef struct {
    int action;
    int value;
} NocttyGridKeyChordPlan;

enum {
    NOCTTY_GRID_CHORD_NONE = 0,
    NOCTTY_GRID_CHORD_COMMAND_PALETTE = 1,
    NOCTTY_GRID_CHORD_TERMINAL_FIND = 2,
    NOCTTY_GRID_CHORD_QUICK_NOTE = 3,
    NOCTTY_GRID_CHORD_SMART_FILTER = 4,
    NOCTTY_GRID_CHORD_TAG_SELECTED = 5,
    NOCTTY_GRID_CHORD_ZOOM = 6,
    NOCTTY_GRID_CHORD_SHORTCUTS = 7,
    NOCTTY_GRID_CHORD_CLOSE_TAB = 8,
    NOCTTY_GRID_CHORD_RENAME_TAB = 9,
    NOCTTY_GRID_CHORD_EMIT_EVENT = 10,
    NOCTTY_GRID_CHORD_BROADCAST = 11,
    NOCTTY_GRID_CHORD_TAB_COLOR = 12,
    NOCTTY_GRID_CHORD_PASTE = 13,
    NOCTTY_GRID_CHORD_COPY = 14,
    NOCTTY_GRID_CHORD_SCROLL_KEYBOARD = 15,
    NOCTTY_GRID_CHORD_CTRL_D = 16,
    NOCTTY_GRID_CHORD_CTRL_C = 17,
};
typedef struct {
    int action;
} NocttyGridPointerEventPlan;

enum {
    NOCTTY_GRID_POINTER_EVENT_PRESS = 1,
    NOCTTY_GRID_POINTER_EVENT_RELEASE = 2,
    NOCTTY_GRID_POINTER_EVENT_DOUBLE_PRESS = 3,
};

enum {
    NOCTTY_GRID_POINTER_ACTION_NONE = 0,
    NOCTTY_GRID_POINTER_ACTION_ZOOM = 1,
    NOCTTY_GRID_POINTER_ACTION_SELECT_WORD = 2,
    NOCTTY_GRID_POINTER_ACTION_CLEAR_SELECTION = 3,
    NOCTTY_GRID_POINTER_ACTION_OPEN_HYPERLINK = 4,
    NOCTTY_GRID_POINTER_ACTION_SHOW_HYPERLINK_MENU = 5,
    NOCTTY_GRID_POINTER_ACTION_SHOW_WORKSPACE_MENU = 6,
    NOCTTY_GRID_POINTER_ACTION_BEGIN_SELECTION = 7,
    NOCTTY_GRID_POINTER_ACTION_UPDATE_SELECTION = 8,
    NOCTTY_GRID_POINTER_ACTION_DELIVER_MOUSE = 9,
    NOCTTY_GRID_POINTER_ACTION_CONSUME = 10,
};

typedef struct {
    double source_center_x;
    double source_center_y;
    double best_score;
    int direction_x;
    int direction_y;
    int target_index;
    int active;
} NocttyGridDirectionalFocusPlan;

typedef struct {
    int action;
    int direction;
    int dx;
    int dy;
    int consume_without_effect;
} NocttyGridKeyCommandPlan;

typedef uint32_t NocttyApplicationCloseOrigin;

enum {
    NOCTTY_CLOSE_ORIGIN_NONE = 0,
    NOCTTY_CLOSE_ORIGIN_TOOLBAR = 1,
    NOCTTY_CLOSE_ORIGIN_TRAY = 2,
    NOCTTY_CLOSE_ORIGIN_WINDOW = 3,
    NOCTTY_CLOSE_ORIGIN_NATURAL = 4,
};

typedef struct {
    uint32_t phase;
    NocttyApplicationCloseOrigin origin;
    uint32_t modal_depth;
} NocttyGridCloseCoordinator;

typedef struct {
    uint32_t effects;
    NocttyApplicationCloseOrigin origin;
    uint32_t accepted;
} NocttyGridCloseTransition;

enum {
    NOCTTY_CLOSE_SOURCE_DEFERRED = 1,
    NOCTTY_CLOSE_SOURCE_PREFLIGHT = 2,
};

enum {
    NOCTTY_CLOSE_EFFECT_SCHEDULE_DEFERRED = 1u << 0,
    NOCTTY_CLOSE_EFFECT_SCHEDULE_PREFLIGHT = 1u << 1,
    NOCTTY_CLOSE_EFFECT_SCHEDULE_DWELL = 1u << 2,
    NOCTTY_CLOSE_EFFECT_CANCEL_DEFERRED = 1u << 3,
    NOCTTY_CLOSE_EFFECT_CANCEL_PREFLIGHT = 1u << 4,

    NOCTTY_CLOSE_EFFECT_RUN_PREFLIGHT = 1u << 5,
    NOCTTY_CLOSE_EFFECT_COMMIT = 1u << 6,
};
void noctty_grid_startup_window_plan(
    int claim_control, int enable_shortcut, int control_registered,
    int mode, int control_conflict, int activation_retained,
    NocttyGridStartupWindowPlan *plan);

NocttyGridCloseTransition noctty_grid_close_request(
    NocttyGridCloseCoordinator *coordinator,
    NocttyApplicationCloseOrigin origin);
NocttyGridCloseTransition noctty_grid_close_modal_begin(
    NocttyGridCloseCoordinator *coordinator);
NocttyGridCloseTransition noctty_grid_close_modal_end(
    NocttyGridCloseCoordinator *coordinator);
NocttyGridCloseTransition noctty_grid_close_source_fired(
    NocttyGridCloseCoordinator *coordinator, uint32_t source);
NocttyGridCloseTransition noctty_grid_close_preflight_result(
    NocttyGridCloseCoordinator *coordinator, int accepted);

enum {
    NOCTTY_GRID_INPUT_POINTER = 1,
    NOCTTY_GRID_INPUT_WHEEL = 2,
};

enum {
    NOCTTY_GRID_MODIFIER_SHIFT = 1u << 0,
    NOCTTY_GRID_MODIFIER_CONTROL = 1u << 1,
    NOCTTY_GRID_MODIFIER_ALT = 1u << 2,
};
int noctty_grid_is_alt_key(uint32_t keyval);
uint32_t noctty_grid_input_modifiers(uint32_t state);
int noctty_grid_tray_menu_id_valid(int id);
const char *noctty_grid_window_resize_cursor_name(int index);
const char *noctty_grid_tray_menu_label(int id, int window_presented);
const char *noctty_grid_tray_menu_icon_name(int id);
int noctty_grid_resize_edge(int index);

typedef struct {
    int action;
} NocttyGridResizeEventPlan;

enum {
    NOCTTY_GRID_RESIZE_EVENT_PRESS = 1,
    NOCTTY_GRID_RESIZE_EVENT_MOTION = 2,
    NOCTTY_GRID_RESIZE_EVENT_RELEASE = 3,
    NOCTTY_GRID_RESIZE_EVENT_DOUBLE_PRESS = 4,
    NOCTTY_GRID_RESIZE_ACTION_NONE = 0,
    NOCTTY_GRID_RESIZE_ACTION_TOGGLE_HEIGHT = 1,
    NOCTTY_GRID_RESIZE_ACTION_ARM_CLICK = 2,
    NOCTTY_GRID_RESIZE_ACTION_DELAY_DOUBLE_CLICK = 3,
    NOCTTY_GRID_RESIZE_ACTION_BEGIN_DRAG = 4,
    NOCTTY_GRID_RESIZE_ACTION_CONSUME = 5,
    NOCTTY_GRID_RESIZE_ACTION_UPDATE_DRAG = 6,
    NOCTTY_GRID_RESIZE_ACTION_FINISH_DRAG = 7
};

void noctty_grid_resize_event_plan(
    int event_kind, int handle, int button, int mode,
    int drag_active, int click_pending, int button1_down,
    double motion_distance_squared, NocttyGridResizeEventPlan *plan);

typedef struct {
    int action;
} NocttyGridWindowModePlan;

enum {
    NOCTTY_GRID_WINDOW_MODE_ACTION_NONE = 0,
    NOCTTY_GRID_WINDOW_MODE_ACTION_RECREATE = 1,
    NOCTTY_GRID_WINDOW_MODE_ACTION_APPLY_DROPDOWN = 2,
    NOCTTY_GRID_WINDOW_MODE_ACTION_APPLY_WINDOW = 3,
    NOCTTY_GRID_WINDOW_MODE_ACTION_APPLY_FULLSCREEN = 4,
    NOCTTY_GRID_WINDOW_MODE_ACTION_APPLY_LAYER_GEOMETRY = 5
};

void noctty_grid_window_mode_plan(
    int previous_mode, int mode, int layer_shell_active,
    NocttyGridWindowModePlan *plan);

typedef struct {
    int action;
    int lower_parent;
} NocttyGridOverlayStackingPlan;

enum {
    NOCTTY_GRID_OVERLAY_STACKING_NONE = 0,
    NOCTTY_GRID_OVERLAY_STACKING_BASIC = 1,
    NOCTTY_GRID_OVERLAY_STACKING_EXISTING = 2,
    NOCTTY_GRID_OVERLAY_STACKING_LAYER = 3
};

void noctty_grid_overlay_stacking_plan(
    int layer_shell_active, int layer_shell_library_available,
    int existing_overlay, int overlay_count,
    NocttyGridOverlayStackingPlan *plan);

typedef struct {
    int action;
} NocttyGridWindowVisibilityPlan;

enum {
    NOCTTY_GRID_WINDOW_VISIBILITY_NONE = 0,
    NOCTTY_GRID_WINDOW_VISIBILITY_HIDE = 1,
    NOCTTY_GRID_WINDOW_VISIBILITY_SHOW = 2
};

void noctty_grid_window_visibility_plan(
    int window_presented, int window_visible,
    NocttyGridWindowVisibilityPlan *plan);

typedef struct {
    int left;
    int right;
    int top;
    int bottom;
} NocttyGridOverlayGeometryPlan;

void noctty_grid_overlay_geometry_plan(
    int workarea_x, int workarea_y, int workarea_width, int workarea_height,
    int monitor_x, int monitor_y, int monitor_width, int monitor_height,
    int window_width, int window_height,
    NocttyGridOverlayGeometryPlan *plan);

typedef struct {
    int action;
} NocttyGridFullscreenPlan;

enum {
    NOCTTY_GRID_FULLSCREEN_WINDOW = 1,
    NOCTTY_GRID_FULLSCREEN_CURRENT_MONITOR = 2,
    NOCTTY_GRID_FULLSCREEN_MONITOR = 3
};

void noctty_grid_fullscreen_plan(
    int gdk_window_present, int wayland_display, int monitor_index,
    NocttyGridFullscreenPlan *plan);

typedef struct {
    int action;
    int width;
    int height;
    int left;
    int right;
    int bottom;
} NocttyGridLayerGeometryPlan;

enum {
    NOCTTY_GRID_LAYER_GEOMETRY_NONE = 0,
    NOCTTY_GRID_LAYER_GEOMETRY_DROPDOWN = 1,
    NOCTTY_GRID_LAYER_GEOMETRY_ZEN = 2,
    NOCTTY_GRID_LAYER_GEOMETRY_WINDOW = 3
};

void noctty_grid_layer_geometry_plan(
    int mode, int monitor_width, int monitor_height,
    int dropdown_width_px, int dropdown_width_percent,
    int dropdown_height_px, int dropdown_height_percent,
    NocttyGridLayerGeometryPlan *plan);

typedef struct {
    int action;
} NocttyGridMonitorSelectionPlan;

enum {
    NOCTTY_GRID_MONITOR_SELECTION_NONE = 0,
    NOCTTY_GRID_MONITOR_SELECTION_WINDOW = 1,
    NOCTTY_GRID_MONITOR_SELECTION_PRIMARY = 2,
    NOCTTY_GRID_MONITOR_SELECTION_POINTER = 3,
    NOCTTY_GRID_MONITOR_SELECTION_FIRST = 4
};

void noctty_grid_monitor_selection_plan(
    int window_monitor, int primary_monitor,
    int pointer_monitor, int monitor_count,
    NocttyGridMonitorSelectionPlan *plan);
int noctty_grid_monitor_scale_factor(int raw_scale_factor);
int noctty_grid_monitor_metrics_changed(
    int geometry_x, int geometry_y, int geometry_width, int geometry_height,
    int workarea_x, int workarea_y, int workarea_width, int workarea_height,
    int scale_factor,
    int previous_geometry_x, int previous_geometry_y,
    int previous_geometry_width, int previous_geometry_height,
    int previous_workarea_x, int previous_workarea_y,
    int previous_workarea_width, int previous_workarea_height,
    int previous_scale_factor);
int noctty_grid_resize_handle_index(int stored_index);

enum {
    NOCTTY_GRID_KEY_ACTION_NONE = 0,
    NOCTTY_GRID_KEY_ACTION_SHOW_NOTE_OVERLAYS = 1,
    NOCTTY_GRID_KEY_ACTION_HIDE_NOTE_OVERLAYS = 2,
    NOCTTY_GRID_KEY_ACTION_CLEAR_SMART_FILTER = 3,
    NOCTTY_GRID_KEY_ACTION_CYCLE_TAB = 4,
    NOCTTY_GRID_KEY_ACTION_CYCLE_PANE = 5,
    NOCTTY_GRID_KEY_ACTION_FOCUS_DIRECTION = 6,
};

enum {
    NOCTTY_GRID_TERMINAL_MODE_MOUSE = 1u << 0,
    NOCTTY_GRID_TERMINAL_MODE_ALTERNATE_SCREEN = 1u << 1,
};

enum {
    NOCTTY_GRID_ROUTE_IGNORE = 0,
    NOCTTY_GRID_ROUTE_SCROLLBAR = 1,
    NOCTTY_GRID_ROUTE_SELECTION = 2,
    NOCTTY_GRID_ROUTE_APPLICATION_MOUSE = 3,
    NOCTTY_GRID_ROUTE_TERMINAL_SCROLL = 4,
    NOCTTY_GRID_ROUTE_TAB_CYCLE = 5,
    NOCTTY_GRID_ROUTE_PANE_CYCLE = 6,
    NOCTTY_GRID_ROUTE_FONT_ZOOM = 7,
    NOCTTY_GRID_ROUTE_LOCAL_POINTER = 8,
    NOCTTY_GRID_ROUTE_APPLICATION_KEYS = 9,
};

int noctty_grid_cycle_target(int count, int current_index,
                             int current_found, int direction);
void noctty_grid_directional_focus_begin(
    const NocttyGridRectangle *source, int dx, int dy,
    NocttyGridDirectionalFocusPlan *plan);
void noctty_grid_directional_focus_consider(
    NocttyGridDirectionalFocusPlan *plan,
    const NocttyGridRectangle *candidate, int candidate_index);
void noctty_grid_key_command_plan(
    int pressed, int alt_key, int smart_filter_clear_available,
    uint32_t keyval, uint32_t modifier_flags,
    NocttyGridKeyCommandPlan *plan);
void noctty_grid_key_chord_plan(
    uint32_t keyval, uint32_t state, NocttyGridKeyChordPlan *plan);
void noctty_grid_pointer_event_plan(
    int event_kind, int button, int route, int hyperlink_point,
    int control_pressed, int background, int multiple_panes,
    int suppress_primary_release, int preserve_double_click_selection,
    NocttyGridPointerEventPlan *plan);
void noctty_grid_smart_filter_visibility_plan(
    int filter_active, int matches, int focused,
    int first_visible_seen,
    NocttyGridSmartFilterVisibilityPlan *plan);
void noctty_grid_smart_filter_summary_plan(
    int filter_active, int page_available,
    int first_visible, int focused_visible,
    NocttyGridSmartFilterSummaryPlan *plan);

int noctty_grid_input_route(int input_kind, int scrollbar_owned,
                            int terminal_mode_flags, int history_available,
                            int primary_button, uint32_t modifier_flags);
void noctty_grid_wheel_action_plan(
    int route, int scroll_direction, double delta_y, double *accumulator,
    NocttyGridWheelActionPlan *plan);
void noctty_grid_scroll_route_plan(
    int scrollbar_owned, int terminal_mode_flags, int history_available,
    uint32_t modifier_flags, int scroll_direction, double delta_y,
    double *tab_accumulator, double *pane_accumulator,
    double *font_accumulator, NocttyGridScrollRoutePlan *plan);
void noctty_grid_selection_word_plan(
    void *userdata, int column, int row, int columns,
    NocttyGridCellTextReader cell_text,
    NocttyGridSelectionWordPlan *plan);
int noctty_grid_read_hyperlink(
    void *userdata, int column, int row, char *output, size_t capacity,
    NocttyGridCellHyperlinkReader cell_hyperlink);
int noctty_grid_wheel_key_sequence(int application_cursor, int steps,
                                   uint8_t *output, uint32_t capacity);
int noctty_grid_terminal_key_sequence(uint32_t keyval, uint32_t codepoint,
                                      uint32_t modifier_flags,
                                      int application_cursor, uint8_t *output,
                                      uint32_t capacity);
typedef struct {
    int label_length;
    int tooltip_length;
} NocttyGridShortcutTextPlan;

int noctty_grid_shortcut_label(uint32_t encoded, uint8_t *output,
                               uint32_t capacity);
int noctty_grid_shortcut_settings_text(
    uint32_t encoded, int plasma_transport,
    unsigned char *label, size_t label_capacity,
    unsigned char *tooltip, size_t tooltip_capacity,
    NocttyGridShortcutTextPlan *plan);
int noctty_grid_text_valid(const uint8_t *text, size_t length,
                           size_t max_length);
int noctty_grid_hyperlink_valid(const uint8_t *uri, uint32_t length);
void noctty_grid_accessible_offset_plan(
    int count, int start_offset, int end_offset,
    NocttyGridAccessibleOffsetPlan *plan);
void noctty_grid_accessible_range_plan(
    const uint8_t *text, size_t length, int offset, int granularity,
    NocttyGridAccessibleRangePlan *plan);
int noctty_grid_accessible_text_capacity(
    int columns, int rows, NocttyGridAccessibleTextPlan *plan);
int noctty_grid_accessible_cell_length(int length, int capacity);
size_t noctty_grid_accessible_trim_row_length(
    const uint8_t *bytes, size_t length);
size_t noctty_grid_accessible_trim_newline_length(
    const uint8_t *bytes, size_t length);
int noctty_grid_pane_tooltip(
    uint64_t pane_id,
    const unsigned char *status, size_t status_length,
    const unsigned char *tags, size_t tags_length,
    unsigned char *output, size_t capacity);

void noctty_grid_output_present_plan(
    int session_available, int exited, int source_active, int mapped,
    NocttyGridOutputPresentPlan *plan);
void noctty_grid_zoom_plan(
    uint64_t zoomed_pane_id, uint64_t pane_id, NocttyGridZoomPlan *plan);

enum {
    NOCTTY_GRID_RECOVERY_CONFIG_BACKUP = 1u << 0,
    NOCTTY_GRID_RECOVERY_CONFIG_DEFAULTS = 1u << 1,
    NOCTTY_GRID_RECOVERY_THEME_BACKUP = 1u << 2,
    NOCTTY_GRID_RECOVERY_THEME_DEFAULTS = 1u << 3,
    NOCTTY_GRID_RECOVERY_WORKSPACE_DEFAULTS = 1u << 4,
};

int noctty_grid_recovery_notice_text(
    uint32_t flags, unsigned char *output, size_t capacity);

int noctty_grid_smoke_schedule(
    int workspace_smoke, int activation_child_receipt,
    NocttyGridSmokeScheduleStep *steps, int capacity);
int noctty_grid_fuzzy_match_ascii(const uint8_t *haystack,
                                  uint32_t haystack_length,
                                  const uint8_t *needle,
                                  uint32_t needle_length);
int noctty_grid_dropdown_dimension(int stored_px, int percent,
                                   int available_px, int minimum_px);
int noctty_grid_dropdown_percent(int pixels, int available_px,
                                 int fallback_percent);
int noctty_grid_dialog_dimension(
    int available_px, int maximum_px, int minimum_px, int margin_px);
int noctty_grid_percent_dimension(
    int available_px, int percent, int minimum_px);
typedef struct {
    int label_height;
    int action_extent;
    int strip_limit;
} NocttyGridCompactTabMetrics;

void noctty_grid_compact_tab_metrics(
    int tab_height, NocttyGridCompactTabMetrics *metrics);

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
} NocttyGridCompactTabMeasurements;

typedef struct {
    int strip_extent;
    int widget_extent;
    int max_width;
    int close_extent;
    int action_extent;
} NocttyGridCompactTabGeometry;

void noctty_grid_compact_tab_geometry(
    const NocttyGridCompactTabMeasurements *measurements,
    NocttyGridCompactTabGeometry *geometry);

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
} NocttyGridCompactTabTextInput;

typedef struct {
    int markup_length;
    int tooltip_length;
    int close_name_length;
    int title_truncated;
} NocttyGridCompactTabTextPlan;
typedef struct {
    int empty_length;
    int label_length;
    int tooltip_length;
} NocttyGridSmartFilterTextPlan;


int noctty_grid_compact_tab_text(
    const NocttyGridCompactTabTextInput *input,
    unsigned char *markup, size_t markup_capacity,
    unsigned char *tooltip, size_t tooltip_capacity,
    unsigned char *close_name, size_t close_name_capacity,
    NocttyGridCompactTabTextPlan *plan);
int noctty_grid_smart_filter_text(
    int active, const unsigned char *tag, size_t tag_length,
    unsigned char *empty_text, size_t empty_capacity,
    unsigned char *label, size_t label_capacity,
    unsigned char *tooltip, size_t tooltip_capacity,
    NocttyGridSmartFilterTextPlan *plan);

int noctty_grid_cycle_feedback_text(
    int kind, int index, int count,
    unsigned char *output, size_t capacity);

int noctty_grid_attention_notification_text(
    uint64_t pane_id, int attention, int exit_code,
    unsigned char *output, size_t capacity);

int noctty_grid_tab_title_text(
    const unsigned char *model_title, size_t model_length,
    const unsigned char *display_title, size_t display_length,
    const unsigned char *directory_name, size_t directory_length,
    int page_number, unsigned char *output, size_t capacity);

int noctty_grid_pane_zoom_feedback_text(
    uint64_t pane_id,
    const unsigned char *title, size_t title_length,
    const unsigned char *display_title, size_t display_length,
    unsigned char *output, size_t capacity);

enum {
    NOCTTY_GRID_FEEDBACK_SCROLL_HISTORY = 1,
    NOCTTY_GRID_FEEDBACK_PASTE,
    NOCTTY_GRID_FEEDBACK_COPY,
    NOCTTY_GRID_FEEDBACK_TERMINAL_STATE,
    NOCTTY_GRID_FEEDBACK_CTRL_L,
    NOCTTY_GRID_FEEDBACK_INPUT_FLUSH,
    NOCTTY_GRID_FEEDBACK_RECOVERY_SAVE,
    NOCTTY_GRID_FEEDBACK_INTERRUPT,
    NOCTTY_GRID_FEEDBACK_DELIVER_INPUT,
    NOCTTY_GRID_FEEDBACK_OPEN_BROWSER,
    NOCTTY_GRID_FEEDBACK_LINK_TYPE,
    NOCTTY_GRID_FEEDBACK_LINK_COPIED,
    NOCTTY_GRID_FEEDBACK_POINTER_INPUT,
    NOCTTY_GRID_FEEDBACK_BROADCAST_DISABLED,
    NOCTTY_GRID_FEEDBACK_MOUSE_WHEEL,
    NOCTTY_GRID_FEEDBACK_ALT_SCROLL,
    NOCTTY_GRID_FEEDBACK_COMPOSED_TEXT,
};

const char *noctty_grid_status_feedback_message(int kind);

typedef struct {
    int width;
    int height;
    int min_width;
    int min_height;
    int max_width;
    int max_height;
} NocttyGridSettingsGeometryPlan;

void noctty_grid_settings_geometry_plan(
    int workarea_width, int workarea_height,
    NocttyGridSettingsGeometryPlan *plan);
int noctty_grid_scroll_target_delta(
    uint64_t history_lines, uint64_t viewport_offset, uint64_t target_offset);
int noctty_grid_tab_title_width(int title_length);
uint64_t noctty_grid_search_display_ordinal(
    uint64_t ordinal, int matches);
int noctty_grid_selection_end(int length);
int noctty_grid_partition_size(int total, int parts);

enum {
    NOCTTY_GRID_SHARING_ALLOW_PAIRING = 1u << 0,
    NOCTTY_GRID_SHARING_ALLOW_SESSION = 1u << 1,
    NOCTTY_GRID_SHARING_CLEAR_HOST = 1u << 2,
    NOCTTY_GRID_SHARING_CLEAR_VIEWER = 1u << 3,
};
uint32_t noctty_grid_sharing_status_actions(int status);

typedef struct {
    uint32_t enabled;
    int stop_label;
    int stop_receive_label;
    int revoke_label;
    int cancel_pairing_label;
} NocttyGridSharingControlPlan;
typedef struct {
    int length;
    int is_error;
} NocttyGridSharingStatusTextPlan;

int noctty_grid_sharing_status_text(
    int status, uint32_t sas, uint16_t port,
    const unsigned char *alias, size_t alias_length,
    const unsigned char *endpoint, size_t endpoint_length,
    uint16_t discovered_port, int discovered,
    unsigned char *output, size_t capacity,
    NocttyGridSharingStatusTextPlan *plan);


enum {
    NOCTTY_GRID_SHARING_CONTROL_CONFIRM = 1u << 0,
    NOCTTY_GRID_SHARING_CONTROL_PAIRING = 1u << 1,
    NOCTTY_GRID_SHARING_CONTROL_DISCOVER = 1u << 2,
    NOCTTY_GRID_SHARING_CONTROL_SESSION = 1u << 3,
    NOCTTY_GRID_SHARING_CONTROL_PEERS = 1u << 4,
    NOCTTY_GRID_SHARING_CONTROL_REVOKE_DEVICE = 1u << 5,
    NOCTTY_GRID_SHARING_CONTROL_STOP = 1u << 6,
    NOCTTY_GRID_SHARING_CONTROL_CANCEL_PAIRING = 1u << 7,
    NOCTTY_GRID_SHARING_CONTROL_GRANT = 1u << 8,
    NOCTTY_GRID_SHARING_CONTROL_REVOKE = 1u << 9,
    NOCTTY_GRID_SHARING_CONTROL_STOP_RECEIVE = 1u << 10,
    NOCTTY_GRID_SHARING_CONTROL_REQUEST_CONTROL = 1u << 11,
    NOCTTY_GRID_SHARING_CONTROL_RECONNECT = 1u << 12,
    NOCTTY_GRID_SHARING_CONTROL_RETRY_SAVE = 1u << 13,
};

enum {
    NOCTTY_GRID_SHARING_LABEL_STOP = 0,
    NOCTTY_GRID_SHARING_LABEL_CLOSE_SHARING = 1,
    NOCTTY_GRID_SHARING_LABEL_STOP_RECEIVING = 0,
    NOCTTY_GRID_SHARING_LABEL_CLOSE_REMOTE = 1,
    NOCTTY_GRID_SHARING_LABEL_REVOKE_CONTROL = 0,
    NOCTTY_GRID_SHARING_LABEL_DENY_CONTROL = 1,
    NOCTTY_GRID_SHARING_LABEL_CANCEL_PAIRING = 0,
    NOCTTY_GRID_SHARING_LABEL_CLEAR_PAIRING = 1,
};

void noctty_grid_sharing_control_plan(
    int status, int active_peer_count,
    NocttyGridSharingControlPlan *plan);
int noctty_grid_bracketed_paste_marker(
    int kind, unsigned char *output, size_t capacity);
int noctty_grid_sharing_key_sequence(
    int kind, int application_cursor, unsigned char *output, size_t capacity);
int noctty_grid_sharing_extended_key_sequence(
    int kind, int modifier, unsigned char *output, size_t capacity);
int noctty_grid_sharing_text_sequence(
    int alt, const unsigned char *input, size_t length,
    unsigned char *output, size_t capacity);
int noctty_grid_sharing_arrow_sequence(
    int arrow, int modifier, int application_cursor,
    unsigned char *output, size_t capacity);
int noctty_grid_sharing_paste_allowed(size_t length);
size_t noctty_grid_sharing_paste_chunk_size(size_t remaining);
size_t noctty_grid_damage_buffer_capacity(int rows);
size_t noctty_grid_selection_copy_capacity_next(size_t current);
int noctty_grid_sharing_preview_scroll_lines(int direction, double delta_y);
int noctty_grid_sharing_index(const unsigned char *text, size_t length);
int noctty_grid_sharing_index_text(
    int index, unsigned char *output, size_t capacity);
int noctty_grid_theme_color_text(
    double red, double green, double blue,
    unsigned char *output, size_t capacity);
double noctty_grid_theme_color_channel(uint32_t rgb, int channel);
int noctty_grid_terminal_scroll_setting(int event_code, int value);
double noctty_grid_font_size_clamp(
    double requested, double minimum, double maximum);
int noctty_grid_font_size_event_value(
    double requested, double minimum, double maximum);
int noctty_grid_panel_metric_value(int event_code, int value);
int noctty_grid_background_opacity_value(int value);
int noctty_grid_sharing_pane_hit(
    double x, double y, double width, double height,
    double pane_x, double pane_y, double pane_width, double pane_height);

int noctty_grid_scroll_direction(int direction);
const char *noctty_grid_tab_color_preset_name(int preset);
const char *noctty_grid_tab_color_shade_name(int shade);
int noctty_grid_scrollbar_geometry(
    int allocation_width, int allocation_height, double scrollbar_width,
    double thumb_height_min, uint64_t history_lines,
    uint64_t viewport_offset, uint32_t visible_rows,
    NocttyTerminalScrollbarGeometry *geometry);
void noctty_grid_scrollbar_press_plan(
    const NocttyTerminalScrollbarGeometry *geometry, double pointer_y,
    NocttyTerminalScrollbarPressPlan *plan);
int noctty_grid_scrollbar_drag_target(
    const NocttyTerminalScrollbarGeometry *geometry, double pointer_y,
    double drag_offset, uint64_t *target_offset);
int noctty_grid_cell_selected(int selecting, int start_column, int start_row,
                              int end_column, int end_row, int column,
                              int row);
typedef struct {
    int first_row;
    int end_row;
    int first_column;
    int end_column;
} NocttyGridRenderViewport;

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
} NocttyGridRenderChrome;

int noctty_grid_render_viewport(
    double clip_x1, double clip_y1, double clip_x2, double clip_y2,
    double cell_width, double cell_height, int columns, int rows,
    NocttyGridRenderViewport *output);
void noctty_grid_render_chrome(
    int status_kind, int focused, int selected, int pane_width,
    int focused_width, int selected_width, int cursor_visible,
    int cursor_live, int cursor_column, int cursor_row, int columns,
    int rows, double cell_width, double cell_height,
    NocttyGridRenderChrome *output);
void noctty_grid_status_plan(
    int status_kind, int attention,
    NocttyGridStatusPlan *plan);
void noctty_grid_status_color_plan(
    int status_kind, int attention,
    NocttyGridStatusColorPlan *plan);
void noctty_grid_notebook_chrome_plan(
    uint64_t zoomed_pane_id, int page_count,
    NocttyGridNotebookChromePlan *plan);

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
} NocttyGridRenderCell;

int noctty_grid_codepoint_utf8(uint32_t codepoint, uint8_t *output,
                               uint32_t output_size);
void noctty_grid_render_cell(uint64_t packed_cell,
                             NocttyGridRenderCell *output);
int noctty_grid_render_run_end(const uint64_t *cells, int start, int end,
                               int kind);
void noctty_grid_damage_rect(
    double x, double y, double width, double height,
    int allocation_width, int allocation_height,
    NocttyGridDamageRect *output);
void noctty_grid_cursor_damage(
    int column, int row, double cell_width, double cell_height,
    NocttyGridDamageRect *output);
void noctty_grid_cursor_position(
    uint32_t packed_cursor, NocttyGridCursorPosition *output);
double noctty_grid_background_alpha(
    int translucency, int alpha_supported, double opacity_percent);

void noctty_grid_cell_span(int first, int end, int row, double cell_width,
                           double cell_height, int snap_horizontal,
                           NocttyGridRectangle *rectangle);
void noctty_grid_panel_spacing_plan(
    int enabled, int spacing_px,
    NocttyGridPanelSpacingPlan *plan);
void noctty_grid_auto_fit_bounds(
    int allocation_width, int allocation_height,
    int candidate_width, int candidate_height,
    NocttyGridAutoFitBounds *bounds);
int noctty_grid_resize_plan(
    int allocation_width, int allocation_height,
    double scrollbar_width, double cell_width, double cell_height,
    int current_columns, int current_rows,
    NocttyGridResizePlan *plan);
void noctty_grid_row_span(int first, int end, double cell_height,
                          NocttyGridRectangle *rectangle);
int noctty_grid_scroll_steps(int configured_lines, int smooth_enabled,
                             int direction, double delta_y,
                             double *accumulator);
uint64_t noctty_grid_keyboard_scroll_target(uint64_t history_lines,
                                            uint64_t viewport_offset,
                                            uint32_t visible_rows, int action);
void noctty_grid_font_metrics(double requested_points,
                              NocttyGridFontMetrics *metrics);
void noctty_grid_auto_fit(double base_size, int fit_width, int fit_height,
                          int enabled, double *next_size, int *zoom_percent,
                          int *floor_reached);
int noctty_grid_dimensions(int allocation_width, int allocation_height,
                           double scrollbar_width, double cell_width,
                           double cell_height, int *terminal_width,
                           int *columns, int *rows);
uint32_t noctty_grid_scale_brightness(
    uint32_t rgb, int enabled, int active, int percent);

int noctty_grid_pane_is_active(uint64_t active_pane_id,
                               uint64_t pane_id, int focused);
const char *noctty_grid_status_name(int status_kind);
const char *noctty_grid_profile_preset_label(int preset);
const char *noctty_grid_broadcast_menu_label(int enabled);
const char *noctty_grid_shortcut_field(int field, int smoke);
typedef struct {
    int column;
    int row;
    int width;
    int height;
} NocttyGridResizeHandleLayout;
int noctty_grid_resize_handle_layout(int index, int border_px,
                                     int dragger_px,
                                     NocttyGridResizeHandleLayout *output);
int noctty_grid_snap_pane_position(int max_position, int position);
unsigned int noctty_grid_palette_actions(
    NocttyPaletteAction *output, unsigned int capacity);
typedef struct {
    const char *label;
    unsigned int role;
} NocttyGridWorkspaceColor;
int noctty_grid_workspace_color(int index, NocttyGridWorkspaceColor *output);
typedef struct {
    int x;
    int y;
    int width;
    int height;
} NocttyGridAdaptiveWindowGeometry;

int noctty_grid_adapt_window_geometry(
    int mode, int current_x, int current_y, int current_width,
    int current_height, int workarea_x, int workarea_y,
    int workarea_width, int workarea_height, int dropdown_width,
    int dropdown_height, NocttyGridAdaptiveWindowGeometry *output);

void noctty_grid_resize_delta(int handle, double start_x, double start_y,
                              double pointer_x, double pointer_y,
                              double *horizontal, double *vertical);
int noctty_grid_clamp_resize(int start, double delta, int minimum,
                             int maximum);
int noctty_grid_pointer_cell(double x, double y, double cell_width,
                             double cell_height, int columns, int rows,
                             int clamp, int *column, int *row);

int noctty_grid_cell_is_background(const unsigned char *text, int length);
#endif
