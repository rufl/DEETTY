#ifndef NOCTTY_NATIVE_GRID_RENDER_H
#define NOCTTY_NATIVE_GRID_RENDER_H

#include <cairo.h>
#include <pango/pango.h>
#include <stddef.h>
#include <stdint.h>

#include "native_grid_logic.h"

typedef uint32_t (*NocttyGridRenderColor)(void *, uint32_t);

typedef struct {
    void *userdata;
    NocttyGridRenderColor resolve;
} NocttyGridRenderPalette;

typedef struct {
    void *userdata;
    NocttyGridRenderColor resolve;
} NocttyGridTerminalPalette;

typedef struct {
    NocttyGridRenderPalette palette;
    const char *font_family;
    int allocation_width;
    int allocation_height;
    int columns;
    int rows;
    int floor_reached;
    int zoom_percent;
    double border_width;
    int high_contrast;
} NocttyGridResizeOverlay;

typedef struct {
    NocttyGridRenderPalette palette;
    const char *label;
    int allocation_width;
    int allocation_height;
    double pane_border_width;
    double overlay_border_width;
    uint32_t accent_rgb;
} NocttyGridCycleOverlay;

typedef struct {
    cairo_glyph_t **scratch;
    size_t *capacity;
    cairo_scaled_font_t **scaled_fonts;
    unsigned long (*indices)[95];
    uint8_t *valid;
    unsigned int *scratch_allocations;
    unsigned int *cache_builds;
    unsigned int *cache_hits;
    unsigned int *fallback_conversions;
} NocttyGridGlyphCache;

typedef void (*NocttyGridDrawCodepoint)(
    void *, cairo_t *, uint32_t, double, double, uint32_t);

typedef uint64_t (*NocttyGridCellValue)(void *, int, int);
typedef int (*NocttyGridRowValue)(void *, int, uint64_t *, size_t);
typedef int (*NocttyGridCellSelected)(void *, int, int);
typedef void (*NocttyGridDrawCellText)(
    void *, cairo_t *, int, int, double, double, uint32_t);

typedef struct {
    NocttyGridRenderPalette ui_palette;
    NocttyGridTerminalPalette terminal_palette;
    NocttyGridGlyphCache glyph_cache;
    uint64_t **row_cells;
    size_t *row_capacity;
    unsigned int *row_allocations;
    unsigned int *row_batches;
    unsigned int *glyph_batches;
    unsigned int *glyph_cells;
    unsigned int *rich_style_cells;
    void *source_context;
    NocttyGridCellValue cell;
    NocttyGridRowValue row;
    void *selection_context;
    NocttyGridCellSelected selected;
    void *draw_context;
    NocttyGridDrawCodepoint draw_codepoint;
    NocttyGridDrawCellText draw_cell_text;
    const char *font_family;
    double font_px;
    int antialias;
    int hinting;
    int allocation_width;
    int allocation_height;
    int columns;
    int rows;
    double cell_width;
    double cell_height;
    double status_border_width;
    uint32_t cursor_rgb;
    NocttyGridRenderChrome chrome;
} NocttyGridCells;

typedef struct {
    NocttyGridGlyphCache cache;
    const uint64_t *cells;
    int first;
    int end;
    double x_origin;
    double cell_width;
    double baseline;
    int face;
    void *fallback_context;
    NocttyGridDrawCodepoint draw_codepoint;
} NocttyGridAsciiRun;

typedef struct {
    PangoFontDescription **descriptions;
    const char *family;
    double size_px;
} NocttyGridTerminalFont;

typedef struct {
    NocttyGridRenderPalette palette;
    const char *text;
    PangoFontDescription **font_cache;
    int allocation_width;
    int allocation_height;
    double border_width;
    int high_contrast;
} NocttyGridTextOverlay;

typedef struct {
    NocttyGridTerminalPalette palette;
    uint32_t style;
    uint32_t foreground;
    int row;
    int first;
    int end;
    double cell_width;
    double cell_height;
    double baseline;
} NocttyGridTextDecoration;

typedef struct {
    uint64_t pane_mask;
    int selected_seen;
    int host_active_seen;
} NocttyGridSharingPreviewResult;

typedef struct {
    NocttyGridRenderPalette palette;
    int allocation_height;
    double x;
    double width;
    double thumb_y;
    double thumb_height;
    int dragging;
    int hovered;
} NocttyGridRenderScrollbar;

int noctty_grid_render_ascii_run(
    cairo_t *cr, const NocttyGridAsciiRun *options);
int noctty_grid_render_cells(
    cairo_t *cr, const NocttyGridCells *options);
void noctty_grid_render_apply_font_options(
    cairo_t *cr, int antialias, int hinting);
int noctty_grid_render_terminal_text(
    cairo_t *cr, const NocttyGridTerminalFont *font,
    const char *text, int length, double x, double baseline, uint32_t style);
int noctty_grid_render_resize_overlay(
    cairo_t *cr, const NocttyGridResizeOverlay *options);
int noctty_grid_render_cycle_overlay(
    cairo_t *cr, const NocttyGridCycleOverlay *options);
int noctty_grid_render_quick_note(
    cairo_t *cr, const NocttyGridTextOverlay *options, int *compact_out);
int noctty_grid_render_status_feedback(
    cairo_t *cr, const NocttyGridTextOverlay *options);
int noctty_grid_render_text_decoration(
    cairo_t *cr, const NocttyGridTextDecoration *options);
int noctty_grid_render_sharing_preview(
    cairo_t *cr, void *event_data, int width, int height,
    NocttyGridSharingPreviewResult *result);
int noctty_grid_render_scrollbar(
    cairo_t *cr, const NocttyGridRenderScrollbar *options);

#endif
