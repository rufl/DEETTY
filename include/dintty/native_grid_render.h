#ifndef DINTTY_NATIVE_GRID_RENDER_H
#define DINTTY_NATIVE_GRID_RENDER_H

#include <cairo.h>
#include <pango/pango.h>
#include <stddef.h>
#include <stdint.h>

#include "native_grid_logic.h"

typedef uint32_t (*DinttyGridRenderColor)(void *, uint32_t);

typedef struct {
    void *userdata;
    DinttyGridRenderColor resolve;
} DinttyGridRenderPalette;

typedef struct {
    void *userdata;
    DinttyGridRenderColor resolve;
} DinttyGridTerminalPalette;

typedef struct {
    DinttyGridRenderPalette palette;
    const char *font_family;
    int allocation_width;
    int allocation_height;
    int columns;
    int rows;
    int floor_reached;
    int zoom_percent;
    double border_width;
    int high_contrast;
} DinttyGridResizeOverlay;

typedef struct {
    DinttyGridRenderPalette palette;
    const char *label;
    int allocation_width;
    int allocation_height;
    double pane_border_width;
    double overlay_border_width;
    uint32_t accent_rgb;
} DinttyGridCycleOverlay;

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
} DinttyGridGlyphCache;

typedef void (*DinttyGridDrawCodepoint)(
    void *, cairo_t *, uint32_t, double, double, uint32_t);

typedef int (*DinttyGridFrameValue)(
    void *, int, int, uint64_t *, size_t);
typedef int (*DinttyGridCellSelected)(void *, int, int);
typedef void (*DinttyGridDrawCellText)(
    void *, cairo_t *, int, int, double, double, uint32_t);

typedef struct {
    DinttyGridRenderPalette ui_palette;
    DinttyGridTerminalPalette terminal_palette;
    DinttyGridGlyphCache glyph_cache;
    uint64_t **frame_cells;
    size_t *frame_capacity;
    unsigned int *frame_allocations;
    unsigned int *frame_batches;
    unsigned int *glyph_batches;
    unsigned int *glyph_cells;
    unsigned int *rich_style_cells;
    void *source_context;
    DinttyGridFrameValue frame;
    void *selection_context;
    DinttyGridCellSelected selected;
    void *draw_context;
    DinttyGridDrawCodepoint draw_codepoint;
    DinttyGridDrawCellText draw_cell_text;
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
    DinttyGridRenderChrome chrome;
} DinttyGridCells;

typedef struct {
    DinttyGridGlyphCache cache;
    const uint64_t *cells;
    int first;
    int end;
    double x_origin;
    double cell_width;
    double baseline;
    int face;
    void *fallback_context;
    DinttyGridDrawCodepoint draw_codepoint;
} DinttyGridAsciiRun;

typedef struct {
    PangoFontDescription **descriptions;
    const char *family;
    double size_px;
} DinttyGridTerminalFont;

typedef struct {
    DinttyGridRenderPalette palette;
    const char *text;
    PangoFontDescription **font_cache;
    int allocation_width;
    int allocation_height;
    double border_width;
    int high_contrast;
} DinttyGridTextOverlay;

typedef struct {
    DinttyGridTerminalPalette palette;
    uint32_t style;
    uint32_t foreground;
    int row;
    int first;
    int end;
    double cell_width;
    double cell_height;
    double baseline;
} DinttyGridTextDecoration;

typedef struct {
    uint64_t pane_mask;
    int selected_seen;
    int host_active_seen;
} DinttyGridSharingPreviewResult;

typedef struct {
    DinttyGridRenderPalette palette;
    int allocation_height;
    double x;
    double width;
    double thumb_y;
    double thumb_height;
    int dragging;
    int hovered;
} DinttyGridRenderScrollbar;

int dintty_grid_render_ascii_run(
    cairo_t *cr, const DinttyGridAsciiRun *options);
int dintty_grid_render_cells(
    cairo_t *cr, const DinttyGridCells *options);
void dintty_grid_render_apply_font_options(
    cairo_t *cr, int antialias, int hinting);
int dintty_grid_render_terminal_text(
    cairo_t *cr, const DinttyGridTerminalFont *font,
    const char *text, int length, double x, double baseline, uint32_t style);
int dintty_grid_render_resize_overlay(
    cairo_t *cr, const DinttyGridResizeOverlay *options);
int dintty_grid_render_cycle_overlay(
    cairo_t *cr, const DinttyGridCycleOverlay *options);
int dintty_grid_render_quick_note(
    cairo_t *cr, const DinttyGridTextOverlay *options, int *compact_out);
int dintty_grid_render_status_feedback(
    cairo_t *cr, const DinttyGridTextOverlay *options);
int dintty_grid_render_text_decoration(
    cairo_t *cr, const DinttyGridTextDecoration *options);
int dintty_grid_render_sharing_preview(
    cairo_t *cr, void *event_data, int width, int height,
    DinttyGridSharingPreviewResult *result);
int dintty_grid_render_scrollbar(
    cairo_t *cr, const DinttyGridRenderScrollbar *options);

#endif
