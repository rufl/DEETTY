#ifndef NOCTTY_NATIVE_GRID_LOGIC_H
#define NOCTTY_NATIVE_GRID_LOGIC_H

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
    double x;
    double y;
    double width;
    double height;
} NocttyGridRectangle;
typedef struct {
    int steps;
    int direction;
} NocttyGridWheelActionPlan;

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
};

int noctty_grid_input_route(int input_kind, int scrollbar_owned,
                            int terminal_mouse_mode, int primary_button,
                            uint32_t modifier_flags);
void noctty_grid_wheel_action_plan(
    int route, int scroll_direction, double delta_y, double *accumulator,
    NocttyGridWheelActionPlan *plan);



int noctty_grid_scrollbar_geometry(
    int allocation_width, int allocation_height, double scrollbar_width,
    double thumb_height_min, uint64_t history_lines,
    uint64_t viewport_offset, uint32_t visible_rows,
    NocttyTerminalScrollbarGeometry *geometry);
int noctty_grid_cell_selected(int selecting, int start_column, int start_row,
                              int end_column, int end_row, int column,
                              int row);
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
int noctty_grid_scroll_steps(int configured_lines, int smooth_enabled,
                             int direction, double delta_y,
                             double *accumulator);
uint64_t noctty_grid_keyboard_scroll_target(uint64_t history_lines,
                                            uint64_t viewport_offset,
                                            uint32_t visible_rows, int action);
void noctty_grid_auto_fit(double base_size, int fit_width, int fit_height,
                          int enabled, double *next_size, int *zoom_percent,
                          int *floor_reached);
int noctty_grid_dimensions(int allocation_width, int allocation_height,
                           double scrollbar_width, double cell_width,
                           double cell_height, int *terminal_width,
                           int *columns, int *rows);
void noctty_grid_resize_delta(int handle, double start_x, double start_y,
                              double pointer_x, double pointer_y,
                              double *horizontal, double *vertical);
int noctty_grid_clamp_resize(int start, double delta, int minimum,
                             int maximum);
int noctty_grid_pointer_cell(double x, double y, double cell_width,
                             double cell_height, int columns, int rows,
                             int clamp, int *column, int *row);

#endif
