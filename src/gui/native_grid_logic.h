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

int noctty_grid_scrollbar_geometry(
    int allocation_width, int allocation_height, double scrollbar_width,
    double thumb_height_min, uint64_t history_lines,
    uint64_t viewport_offset, uint32_t visible_rows,
    NocttyTerminalScrollbarGeometry *geometry);
int noctty_grid_cell_selected(int selecting, int start_column, int start_row,
                              int end_column, int end_row, int column,
                              int row);
void noctty_grid_cell_span(int first, int end, int row, double cell_width,
                           double cell_height, int snap_horizontal,
                           NocttyGridRectangle *rectangle);

#endif
