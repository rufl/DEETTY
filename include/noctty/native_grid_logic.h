#ifndef NOCTTY_NATIVE_GRID_LOGIC_H
#define NOCTTY_NATIVE_GRID_LOGIC_H

#include <stddef.h>
#include <stdint.h>

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
    double x;
    double y;
    double width;
    double height;
} NocttyGridRectangle;
typedef struct {
    int steps;
    int direction;
} NocttyGridWheelActionPlan;

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

int noctty_grid_input_route(int input_kind, int scrollbar_owned,
                            int terminal_mode_flags, int history_available,
                            int primary_button, uint32_t modifier_flags);
void noctty_grid_wheel_action_plan(
    int route, int scroll_direction, double delta_y, double *accumulator,
    NocttyGridWheelActionPlan *plan);
int noctty_grid_wheel_key_sequence(int application_cursor, int steps,
                                   uint8_t *output, uint32_t capacity);
int noctty_grid_terminal_key_sequence(uint32_t keyval, uint32_t codepoint,
                                      uint32_t modifier_flags,
                                      int application_cursor, uint8_t *output,
                                      uint32_t capacity);
int noctty_grid_shortcut_label(uint32_t encoded, uint8_t *output,
                               uint32_t capacity);
int noctty_grid_text_valid(const uint8_t *text, size_t length,
                           size_t max_length);
int noctty_grid_hyperlink_valid(const uint8_t *uri, uint32_t length);
int noctty_grid_fuzzy_match_ascii(const uint8_t *haystack,
                                  uint32_t haystack_length,
                                  const uint8_t *needle,
                                  uint32_t needle_length);
int noctty_grid_dropdown_dimension(int stored_px, int percent,
                                   int available_px, int minimum_px);
int noctty_grid_dropdown_percent(int pixels, int available_px,
                                 int fallback_percent);

enum {
    NOCTTY_GRID_SHARING_ALLOW_PAIRING = 1u << 0,
    NOCTTY_GRID_SHARING_ALLOW_SESSION = 1u << 1,
    NOCTTY_GRID_SHARING_CLEAR_HOST = 1u << 2,
    NOCTTY_GRID_SHARING_CLEAR_VIEWER = 1u << 3,
};
uint32_t noctty_grid_sharing_status_actions(int status);

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

void noctty_grid_cell_span(int first, int end, int row, double cell_width,
                           double cell_height, int snap_horizontal,
                           NocttyGridRectangle *rectangle);
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

#endif
