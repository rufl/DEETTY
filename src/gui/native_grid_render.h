#ifndef NOCTTY_NATIVE_GRID_RENDER_H
#define NOCTTY_NATIVE_GRID_RENDER_H

#include <cairo.h>
#include <pango/pango.h>
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
    NocttyGridRenderPalette palette;
    int allocation_height;
    double x;
    double width;
    double thumb_y;
    double thumb_height;
    int dragging;
    int hovered;
} NocttyGridRenderScrollbar;

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
int noctty_grid_render_scrollbar(
    cairo_t *cr, const NocttyGridRenderScrollbar *options);

#endif
