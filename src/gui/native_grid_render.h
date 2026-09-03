#ifndef NOCTTY_NATIVE_GRID_RENDER_H
#define NOCTTY_NATIVE_GRID_RENDER_H

#include <cairo.h>
#include <pango/pango.h>
#include <stddef.h>
#include <stdint.h>

typedef uint32_t (*NocttyGridRenderColor)(void *, uint32_t);

typedef struct {
    void *userdata;
    NocttyGridRenderColor resolve;
} NocttyGridRenderPalette;

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
    void *userdata;
    NocttyGridRenderColor resolve;
} NocttyGridTerminalPalette;

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
int noctty_grid_render_scrollbar(
    cairo_t *cr, const NocttyGridRenderScrollbar *options);

#endif
