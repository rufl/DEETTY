const std = @import("std");

const Cairo = opaque {};
const PangoLayout = opaque {};
const PangoFontDescription = opaque {};
const CairoFontOptions = opaque {};
const CairoScaledFont = opaque {};
const CairoGlyph = extern struct {
    index: c_ulong,
    x: f64,
    y: f64,
};
const CairoTextCluster = extern struct {
    num_bytes: c_int,
    num_glyphs: c_int,
};

pub const ColorResolver = *const fn (?*anyopaque, u32) callconv(.c) u32;

pub const Palette = extern struct {
    userdata: ?*anyopaque,
    resolve: ?ColorResolver,
};

pub const TerminalPalette = extern struct {
    userdata: ?*anyopaque,
    resolve: ?ColorResolver,
};

pub const ResizeOverlay = extern struct {
    palette: Palette,
    font_family: ?[*:0]const u8,
    allocation_width: c_int,
    allocation_height: c_int,
    columns: c_int,
    rows: c_int,
    floor_reached: c_int,
    zoom_percent: c_int,
    border_width: f64,
    high_contrast: c_int,
};

pub const CycleOverlay = extern struct {
    palette: Palette,
    label: ?[*:0]const u8,
    allocation_width: c_int,
    allocation_height: c_int,
    pane_border_width: f64,
    overlay_border_width: f64,
    accent_rgb: u32,
};

pub const GlyphCache = extern struct {
    scratch: ?*?*CairoGlyph,
    capacity: ?*usize,
    scaled_fonts: ?[*]?*CairoScaledFont,
    indices: ?[*][95]c_ulong,
    valid: ?[*]u8,
    scratch_allocations: ?*c_uint,
    cache_builds: ?*c_uint,
    cache_hits: ?*c_uint,
    fallback_conversions: ?*c_uint,
};

pub const DrawCodepoint = *const fn (
    ?*anyopaque,
    ?*Cairo,
    u32,
    f64,
    f64,
    u32,
) callconv(.c) void;

pub const AsciiRun = extern struct {
    cache: GlyphCache,
    cells: ?[*]const u64,
    first: c_int,
    end: c_int,
    x_origin: f64,
    cell_width: f64,
    baseline: f64,
    face: c_int,
    fallback_context: ?*anyopaque,
    draw_codepoint: ?DrawCodepoint,
};

pub const TerminalFont = extern struct {
    descriptions: ?[*]?*PangoFontDescription,
    family: ?[*:0]const u8,
    size_px: f64,
};

pub const TextOverlay = extern struct {
    palette: Palette,
    text: ?[*:0]const u8,
    font_cache: ?*?*PangoFontDescription,
    allocation_width: c_int,
    allocation_height: c_int,
    border_width: f64,
    high_contrast: c_int,
};

pub const TextDecoration = extern struct {
    palette: TerminalPalette,
    style: u32,
    foreground: u32,
    row: c_int,
    first: c_int,
    end: c_int,
    cell_width: f64,
    cell_height: f64,
    baseline: f64,
};

pub const Scrollbar = extern struct {
    palette: Palette,
    allocation_height: c_int,
    x: f64,
    width: f64,
    thumb_y: f64,
    thumb_height: f64,
    dragging: c_int,
    hovered: c_int,
};

const FontExtents = extern struct {
    ascent: f64,
    descent: f64,
    height: f64,
    max_x_advance: f64,
    max_y_advance: f64,
};

const TextExtents = extern struct {
    x_bearing: f64,
    y_bearing: f64,
    width: f64,
    height: f64,
    x_advance: f64,
    y_advance: f64,
};

const operator_source: c_int = 1;
const font_slant_normal: c_int = 0;
const font_weight_bold: c_int = 1;
const pango_scale: c_int = 1024;
const pango_wrap_word_char: c_int = 2;
const pango_ellipsize_end: c_int = 3;
const pango_align_center: c_int = 1;
const pango_style_normal: c_int = 0;
const pango_style_italic: c_int = 2;
const pango_weight_normal: c_int = 400;
const pango_weight_bold: c_int = 700;
const cairo_antialias_default: c_int = 0;
const cairo_antialias_gray: c_int = 2;
const cairo_antialias_subpixel: c_int = 3;
const cairo_hint_style_none: c_int = 1;
const cairo_hint_style_slight: c_int = 2;
const cairo_hint_style_full: c_int = 4;
const cairo_hint_metrics_on: c_int = 2;
const cairo_line_cap_square: c_int = 2;

const color_pane_active: u32 = 1;
const color_scrollbar_track: u32 = 4;
const color_scrollbar_thumb: u32 = 5;
const color_scrollbar_hover: u32 = 6;
const color_overlay_background: u32 = 7;
const color_overlay_border: u32 = 8;
const color_overlay_foreground: u32 = 9;

extern fn cairo_save(*Cairo) void;
extern fn cairo_restore(*Cairo) void;
extern fn cairo_set_operator(*Cairo, c_int) void;
extern fn cairo_set_source_rgba(*Cairo, f64, f64, f64, f64) void;
extern fn cairo_set_line_width(*Cairo, f64) void;
extern fn cairo_set_line_cap(*Cairo, c_int) void;
extern fn cairo_font_extents(*Cairo, *FontExtents) void;
extern fn cairo_rectangle(*Cairo, f64, f64, f64, f64) void;
extern fn cairo_fill(*Cairo) void;
extern fn cairo_fill_preserve(*Cairo) void;
extern fn cairo_stroke(*Cairo) void;
extern fn cairo_new_sub_path(*Cairo) void;
extern fn cairo_arc(*Cairo, f64, f64, f64, f64, f64) void;
extern fn cairo_close_path(*Cairo) void;
extern fn cairo_select_font_face(*Cairo, [*:0]const u8, c_int, c_int) void;
extern fn cairo_set_font_size(*Cairo, f64) void;
extern fn cairo_text_extents(*Cairo, [*:0]const u8, *TextExtents) void;
extern fn cairo_move_to(*Cairo, f64, f64) void;
extern fn cairo_line_to(*Cairo, f64, f64) void;
extern fn cairo_show_text(*Cairo, [*:0]const u8) void;
extern fn cairo_clip(*Cairo) void;
extern fn cairo_font_options_create() ?*CairoFontOptions;
extern fn cairo_font_options_destroy(*CairoFontOptions) void;
extern fn cairo_get_font_options(*Cairo, *CairoFontOptions) void;
extern fn cairo_set_font_options(*Cairo, *const CairoFontOptions) void;
extern fn cairo_font_options_set_antialias(*CairoFontOptions, c_int) void;
extern fn cairo_font_options_set_hint_style(*CairoFontOptions, c_int) void;
extern fn cairo_font_options_set_hint_metrics(*CairoFontOptions, c_int) void;
extern fn cairo_get_scaled_font(*Cairo) ?*CairoScaledFont;
extern fn cairo_scaled_font_status(*CairoScaledFont) c_int;
extern fn cairo_scaled_font_reference(*CairoScaledFont) ?*CairoScaledFont;
extern fn cairo_scaled_font_destroy(*CairoScaledFont) void;
extern fn cairo_scaled_font_text_to_glyphs(
    *CairoScaledFont,
    f64,
    f64,
    [*]const u8,
    c_int,
    *?*CairoGlyph,
    *c_int,
    ?*?*CairoTextCluster,
    ?*c_int,
    ?*c_int,
) c_int;
extern fn cairo_show_glyphs(*Cairo, [*]const CairoGlyph, c_int) void;
extern fn cairo_glyph_free(?*CairoGlyph) void;
extern fn cairo_text_cluster_free(?*CairoTextCluster) void;
extern fn g_try_realloc_n(?*anyopaque, usize, usize) ?*anyopaque;
extern fn g_free(?*anyopaque) void;
extern fn pango_cairo_create_layout(*Cairo) ?*PangoLayout;
extern fn pango_cairo_show_layout(*Cairo, *PangoLayout) void;
extern fn pango_font_description_from_string([*:0]const u8) ?*PangoFontDescription;
extern fn pango_font_description_new() ?*PangoFontDescription;
extern fn pango_font_description_set_family(*PangoFontDescription, [*:0]const u8) void;
extern fn pango_font_description_set_absolute_size(*PangoFontDescription, f64) void;
extern fn pango_font_description_set_style(*PangoFontDescription, c_int) void;
extern fn pango_font_description_set_weight(*PangoFontDescription, c_int) void;
extern fn pango_font_description_free(*PangoFontDescription) void;
extern fn pango_layout_set_font_description(*PangoLayout, *PangoFontDescription) void;
extern fn pango_layout_set_single_paragraph_mode(*PangoLayout, c_int) void;
extern fn pango_layout_get_baseline(*PangoLayout) c_int;
extern fn pango_layout_set_text(*PangoLayout, [*]const u8, c_int) void;
extern fn pango_layout_set_width(*PangoLayout, c_int) void;
extern fn pango_layout_set_wrap(*PangoLayout, c_int) void;
extern fn pango_layout_set_ellipsize(*PangoLayout, c_int) void;
extern fn pango_layout_set_height(*PangoLayout, c_int) void;
extern fn pango_layout_set_spacing(*PangoLayout, c_int) void;
extern fn pango_layout_set_alignment(*PangoLayout, c_int) void;
extern fn pango_layout_get_pixel_size(*PangoLayout, *c_int, *c_int) void;
extern fn g_object_unref(?*anyopaque) void;

fn resolvedRGB(palette: Palette, role: u32, fallback: u32) u32 {
    const resolver = palette.resolve orelse return fallback;
    const rgb = resolver(palette.userdata, role);
    return if (rgb == std.math.maxInt(u32)) fallback else rgb;
}

fn setColor(cr: *Cairo, palette: Palette, role: u32, fallback: u32, alpha: f64) void {
    const rgb = resolvedRGB(palette, role, fallback);
    cairo_set_source_rgba(
        cr,
        @as(f64, @floatFromInt((rgb >> 16) & 0xff)) / 255,
        @as(f64, @floatFromInt((rgb >> 8) & 0xff)) / 255,
        @as(f64, @floatFromInt(rgb & 0xff)) / 255,
        alpha,
    );
}

fn setTerminalColor(
    cr: *Cairo,
    palette: TerminalPalette,
    index: u32,
    alpha: f64,
) void {
    const rgb = if (palette.resolve) |resolver|
        resolver(palette.userdata, index)
    else
        std.math.maxInt(u32);
    if (rgb == std.math.maxInt(u32)) {
        cairo_set_source_rgba(cr, 0.84, 0.87, 0.91, alpha);
        return;
    }
    cairo_set_source_rgba(
        cr,
        @as(f64, @floatFromInt((rgb >> 16) & 0xff)) / 255,
        @as(f64, @floatFromInt((rgb >> 8) & 0xff)) / 255,
        @as(f64, @floatFromInt(rgb & 0xff)) / 255,
        alpha,
    );
}

fn roundedRectangle(cr: *Cairo, x: f64, y: f64, width: f64, height: f64, radius: f64) void {
    const right = x + width;
    const bottom = y + height;
    const pi: f64 = std.math.pi;
    cairo_new_sub_path(cr);
    cairo_arc(cr, right - radius, y + radius, radius, -pi / 2, 0);
    cairo_arc(cr, right - radius, bottom - radius, radius, 0, pi / 2);
    cairo_arc(cr, x + radius, bottom - radius, radius, pi / 2, pi);
    cairo_arc(cr, x + radius, y + radius, radius, pi, 3 * pi / 2);
    cairo_close_path(cr);
}

fn ensureGlyphScratch(cache: GlyphCache, required: usize) bool {
    const scratch = cache.scratch orelse return false;
    const capacity = cache.capacity orelse return false;
    if (scratch.* != null and capacity.* >= required) return true;
    var next_capacity = @max(@as(usize, 64), capacity.*);
    while (next_capacity < required and next_capacity < 512) next_capacity *= 2;
    next_capacity = @min(@as(usize, 512), @max(next_capacity, required));
    const allocation = g_try_realloc_n(scratch.*, next_capacity, @sizeOf(CairoGlyph)) orelse
        return false;
    scratch.* = @ptrCast(@alignCast(allocation));
    capacity.* = next_capacity;
    if (cache.scratch_allocations) |count| count.* +%= 1;
    return true;
}

fn ensureAsciiGlyphCache(cache: GlyphCache, cr: *Cairo, face: usize) bool {
    const scaled_fonts = cache.scaled_fonts orelse return false;
    const indices = cache.indices orelse return false;
    const valid = cache.valid orelse return false;
    const scratch_field = cache.scratch orelse return false;
    const capacity = cache.capacity orelse return false;
    const scaled_font = cairo_get_scaled_font(cr) orelse return false;
    if (cairo_scaled_font_status(scaled_font) != 0) return false;
    if (scaled_fonts[face] == scaled_font) return valid[face] != 0;

    var sample: [95]u8 = undefined;
    for (&sample, 0..) |*byte, index| byte.* = @intCast(' ' + index);
    if (!ensureGlyphScratch(cache, sample.len)) return false;
    var glyphs = scratch_field.*;
    var glyph_count: c_int = @intCast(capacity.*);
    var clusters: ?*CairoTextCluster = null;
    var cluster_count: c_int = 0;
    var cluster_flags: c_int = 0;
    const status = cairo_scaled_font_text_to_glyphs(
        scaled_font,
        0,
        0,
        &sample,
        sample.len,
        &glyphs,
        &glyph_count,
        &clusters,
        &cluster_count,
        &cluster_flags,
    );
    defer if (glyphs != scratch_field.*) cairo_glyph_free(glyphs);
    defer cairo_text_cluster_free(clusters);
    const glyph_slice: [*]CairoGlyph = @ptrCast(glyphs orelse return false);
    const cluster_slice: [*]CairoTextCluster = @ptrCast(clusters orelse return false);
    var usable = status == 0 and glyph_count == sample.len and
        cluster_count == sample.len and cluster_flags == 0;
    var index: usize = 0;
    while (usable and index < @as(usize, @intCast(cluster_count))) : (index += 1) {
        usable = cluster_slice[index].num_bytes == 1 and cluster_slice[index].num_glyphs == 1;
    }
    if (!usable) return false;
    for (0..sample.len) |glyph_index| indices[face][glyph_index] = glyph_slice[glyph_index].index;
    if (scaled_fonts[face]) |previous| cairo_scaled_font_destroy(previous);
    scaled_fonts[face] = cairo_scaled_font_reference(scaled_font);
    valid[face] = 1;
    if (cache.cache_builds) |count| count.* +%= 1;
    return true;
}

pub export fn noctty_grid_render_ascii_run(
    cr_raw: ?*Cairo,
    options_raw: ?*const AsciiRun,
) callconv(.c) c_int {
    const cr = cr_raw orelse return 0;
    const options = options_raw orelse return 0;
    const cells = options.cells orelse return 0;
    const scratch_field = options.cache.scratch orelse return 0;
    const capacity = options.cache.capacity orelse return 0;
    const indices = options.cache.indices orelse return 0;
    if (options.first < 0 or options.end <= options.first) return 0;
    if (options.face < 0 or options.face >= 4) return 0;
    const face: usize = @intCast(options.face);
    var first = options.first;
    var drawn: c_int = 0;
    while (first < options.end) {
        var text: [512]u8 = undefined;
        const count: c_int = @min(options.end - first, text.len);
        var has_visible = false;
        for (0..@intCast(count)) |index| {
            const codepoint: u32 = @truncate(cells[@intCast(first + @as(c_int, @intCast(index)))]);
            text[index] = @intCast(codepoint);
            if (codepoint != ' ') has_visible = true;
        }
        if (!has_visible) {
            first += count;
            continue;
        }
        if (ensureGlyphScratch(options.cache, @intCast(count)) and
            ensureAsciiGlyphCache(options.cache, cr, face))
        {
            const glyphs: [*]CairoGlyph = @ptrCast(scratch_field.* orelse return drawn);
            for (0..@intCast(count)) |index| {
                glyphs[index] = .{
                    .index = indices[face][@as(u8, @intCast(text[index] - ' '))],
                    .x = options.x_origin + @as(f64, @floatFromInt(first + @as(c_int, @intCast(index)))) * options.cell_width,
                    .y = options.baseline,
                };
            }
            cairo_show_glyphs(cr, glyphs, count);
            if (options.cache.cache_hits) |hits| hits.* +%= @intCast(count);
            drawn += count;
            first += count;
            continue;
        }
        var glyphs = scratch_field.*;
        var glyph_count: c_int = if (glyphs != null) @intCast(capacity.*) else 0;
        const status = if (cairo_get_scaled_font(cr)) |scaled_font|
            cairo_scaled_font_text_to_glyphs(
                scaled_font,
                0,
                options.baseline,
                &text,
                count,
                &glyphs,
                &glyph_count,
                null,
                null,
                null,
            )
        else
            -1;
        if (options.cache.fallback_conversions) |fallbacks| fallbacks.* +%= 1;
        if (status == 0 and glyph_count == count) {
            const glyph_slice: [*]CairoGlyph = @ptrCast(glyphs orelse return drawn);
            for (0..@intCast(glyph_count)) |index| {
                glyph_slice[index].x = options.x_origin +
                    @as(f64, @floatFromInt(first + @as(c_int, @intCast(index)))) * options.cell_width;
                glyph_slice[index].y = options.baseline;
            }
            cairo_show_glyphs(cr, glyph_slice, glyph_count);
            drawn += glyph_count;
        } else if (options.draw_codepoint) |draw_codepoint| {
            for (0..@intCast(count)) |index| {
                const codepoint: u32 = @truncate(cells[@intCast(first + @as(c_int, @intCast(index)))]);
                if (codepoint == ' ') continue;
                draw_codepoint(
                    options.fallback_context,
                    cr,
                    codepoint,
                    options.x_origin + @as(f64, @floatFromInt(first + @as(c_int, @intCast(index)))) * options.cell_width,
                    options.baseline,
                    (@as(u32, @intFromBool(face & 1 != 0))) |
                        (@as(u32, @intFromBool(face & 2 != 0)) << 2),
                );
                drawn += 1;
            }
        }
        if (glyphs != scratch_field.*) cairo_glyph_free(glyphs);
        first += count;
    }
    return drawn;
}

pub export fn noctty_grid_render_apply_font_options(
    cr_raw: ?*Cairo,
    antialias: c_int,
    hinting: c_int,
) callconv(.c) void {
    const cr = cr_raw orelse return;
    const options = cairo_font_options_create() orelse return;
    defer cairo_font_options_destroy(options);
    cairo_get_font_options(cr, options);
    const antialias_value = if (antialias <= 0)
        cairo_antialias_default
    else if (antialias == 1)
        cairo_antialias_gray
    else
        cairo_antialias_subpixel;
    const hinting_value = if (hinting <= 0)
        cairo_hint_style_none
    else if (hinting == 1)
        cairo_hint_style_slight
    else
        cairo_hint_style_full;
    cairo_font_options_set_antialias(options, antialias_value);
    cairo_font_options_set_hint_style(options, hinting_value);
    cairo_font_options_set_hint_metrics(options, cairo_hint_metrics_on);
    cairo_set_font_options(cr, options);
}

pub export fn noctty_grid_render_terminal_text(
    cr_raw: ?*Cairo,
    font_raw: ?*const TerminalFont,
    text_raw: ?[*]const u8,
    length: c_int,
    x: f64,
    baseline: f64,
    style: u32,
) callconv(.c) c_int {
    const cr = cr_raw orelse return 0;
    const font = font_raw orelse return 0;
    const text = text_raw orelse return 0;
    const descriptions = font.descriptions orelse return 0;
    if (length <= 0 or length > 4096 or !std.math.isFinite(font.size_px)) return 0;
    if (font.size_px <= 0) return 0;
    const face: usize = @as(usize, @intFromBool(style & 1 != 0)) |
        (@as(usize, @intFromBool(style & 4 != 0)) << 1);
    var description = descriptions[face];
    if (description == null) {
        description = pango_font_description_new() orelse return 0;
        pango_font_description_set_family(description.?, font.family orelse "monospace");
        pango_font_description_set_absolute_size(description.?, font.size_px * pango_scale);
        pango_font_description_set_style(
            description.?,
            if (face & 2 != 0) pango_style_italic else pango_style_normal,
        );
        pango_font_description_set_weight(
            description.?,
            if (face & 1 != 0) pango_weight_bold else pango_weight_normal,
        );
        descriptions[face] = description;
    }
    const layout = pango_cairo_create_layout(cr) orelse return 0;
    defer g_object_unref(layout);
    pango_layout_set_font_description(layout, description.?);
    pango_layout_set_single_paragraph_mode(layout, 1);
    pango_layout_set_text(layout, text, length);
    const pango_baseline = pango_layout_get_baseline(layout);
    const top = baseline - if (pango_baseline > 0)
        @as(f64, @floatFromInt(pango_baseline)) / pango_scale
    else
        font.size_px * 0.82;
    cairo_move_to(cr, x, top);
    pango_cairo_show_layout(cr, layout);
    return 1;
}

pub export fn noctty_grid_render_resize_overlay(
    cr_raw: ?*Cairo,
    options_raw: ?*const ResizeOverlay,
) callconv(.c) c_int {
    const cr = cr_raw orelse return 0;
    const options = options_raw orelse return 0;
    if (options.columns <= 0 or options.rows <= 0) return 0;
    if (options.allocation_width <= 0 or options.allocation_height <= 0) return 0;

    var label_buffer: [64]u8 = undefined;
    const label = if (options.floor_reached != 0)
        std.fmt.bufPrintZ(&label_buffer, "Min 3pt · {d} × {d}", .{ options.columns, options.rows }) catch return 0
    else if (options.zoom_percent > 0 and options.zoom_percent < 100)
        std.fmt.bufPrintZ(
            &label_buffer,
            "Zoom {d}% · {d} × {d}",
            .{ options.zoom_percent, options.columns, options.rows },
        ) catch return 0
    else
        std.fmt.bufPrintZ(&label_buffer, "{d} × {d}", .{ options.columns, options.rows }) catch return 0;

    cairo_save(cr);
    defer cairo_restore(cr);
    cairo_select_font_face(cr, options.font_family orelse "monospace", font_slant_normal, font_weight_bold);
    cairo_set_font_size(cr, 16);
    var extents: TextExtents = undefined;
    cairo_text_extents(cr, label, &extents);
    const width = @max(88, extents.width + 30);
    const height: f64 = 42;
    const x = @max(6, (@as(f64, @floatFromInt(options.allocation_width)) - width) / 2);
    const y = @max(6, (@as(f64, @floatFromInt(options.allocation_height)) - height) / 2);
    roundedRectangle(cr, x, y, width, height, 9);
    setColor(cr, options.palette, color_overlay_background, 0x12151d, 0.94);
    cairo_fill_preserve(cr);
    cairo_set_line_width(cr, options.border_width);
    setColor(
        cr,
        options.palette,
        color_overlay_border,
        0xf2b82e,
        if (options.high_contrast != 0) 0.95 else 0.20,
    );
    cairo_stroke(cr);
    setColor(cr, options.palette, color_overlay_foreground, 0xf7f8ff, 0.98);
    cairo_move_to(
        cr,
        x + (width - extents.width) / 2 - extents.x_bearing,
        y + (height - extents.height) / 2 - extents.y_bearing,
    );
    cairo_show_text(cr, label);
    return 1;
}

pub export fn noctty_grid_render_cycle_overlay(
    cr_raw: ?*Cairo,
    options_raw: ?*const CycleOverlay,
) callconv(.c) c_int {
    const cr = cr_raw orelse return 0;
    const options = options_raw orelse return 0;
    const label = options.label orelse return 0;
    if (options.allocation_width <= 0 or options.allocation_height <= 0) return 0;
    cairo_save(cr);
    defer cairo_restore(cr);
    cairo_set_line_width(cr, options.pane_border_width);
    setColor(cr, options.palette, color_pane_active, options.accent_rgb, 1);
    cairo_rectangle(
        cr,
        3,
        3,
        @max(1, @as(f64, @floatFromInt(options.allocation_width)) - 6),
        @max(1, @as(f64, @floatFromInt(options.allocation_height)) - 6),
    );
    cairo_stroke(cr);
    cairo_select_font_face(cr, "sans", font_slant_normal, font_weight_bold);
    cairo_set_font_size(cr, 12);
    var extents: TextExtents = undefined;
    cairo_text_extents(cr, label, &extents);
    const width = @min(
        @max(88, extents.width + 24),
        @max(24, @as(f64, @floatFromInt(options.allocation_width)) - 16),
    );
    const height: f64 = 28;
    roundedRectangle(cr, 9, 9, width, height, 6);
    setColor(cr, options.palette, color_overlay_background, 0x12151d, 0.94);
    cairo_fill_preserve(cr);
    cairo_set_line_width(cr, options.overlay_border_width);
    setColor(cr, options.palette, color_overlay_border, options.accent_rgb, 1);
    cairo_stroke(cr);
    cairo_rectangle(cr, 11, 11, @max(1, width - 4), height - 4);
    cairo_clip(cr);
    cairo_move_to(cr, 21, 28);
    setColor(cr, options.palette, color_overlay_foreground, 0xf7f8ff, 1);
    cairo_show_text(cr, label);
    return 1;
}

pub export fn noctty_grid_render_quick_note(
    cr_raw: ?*Cairo,
    options_raw: ?*const TextOverlay,
    compact_out: ?*c_int,
) callconv(.c) c_int {
    const cr = cr_raw orelse return 0;
    const options = options_raw orelse return 0;
    const label = options.text orelse return 0;
    const font_cache = options.font_cache orelse return 0;
    if (label[0] == 0 or options.allocation_width < 48 or options.allocation_height < 32) return 0;
    const available_width = @max(32, @as(f64, @floatFromInt(options.allocation_width)) - 16);
    const max_width = @min(320, available_width);
    if (font_cache.* == null) font_cache.* = pango_font_description_from_string("Sans 9");
    const font = font_cache.* orelse return 0;
    const layout = pango_cairo_create_layout(cr) orelse return 0;
    defer g_object_unref(layout);
    pango_layout_set_font_description(layout, font);
    pango_layout_set_text(layout, label, -1);
    pango_layout_set_width(layout, @intFromFloat(@max(12, max_width - 20) * @as(f64, pango_scale)));
    pango_layout_set_wrap(layout, pango_wrap_word_char);
    pango_layout_set_ellipsize(layout, pango_ellipsize_end);
    pango_layout_set_height(layout, -3);
    pango_layout_set_spacing(layout, pango_scale);
    var text_width: c_int = 0;
    var text_height: c_int = 0;
    pango_layout_get_pixel_size(layout, &text_width, &text_height);
    const width = @min(max_width, @max(@min(96, max_width), @as(f64, @floatFromInt(text_width)) + 20));
    const max_height = @max(24, @min(92, @as(f64, @floatFromInt(options.allocation_height)) - 16));
    const height = @min(max_height, @max(30, @as(f64, @floatFromInt(text_height)) + 14));
    const x = @max(8, @as(f64, @floatFromInt(options.allocation_width)) - width - 8);
    const y: f64 = 8;
    cairo_save(cr);
    defer cairo_restore(cr);
    roundedRectangle(cr, x, y, width, height, 7);
    setColor(cr, options.palette, color_overlay_background, 0x12151d, 0.94);
    cairo_fill_preserve(cr);
    cairo_set_line_width(cr, options.border_width);
    setColor(
        cr,
        options.palette,
        color_overlay_border,
        0xf2b82e,
        if (options.high_contrast != 0) 0.98 else 0.78,
    );
    cairo_stroke(cr);
    cairo_rectangle(cr, x + 8, y + 5, @max(1, width - 16), @max(1, height - 10));
    cairo_clip(cr);
    setColor(cr, options.palette, color_overlay_foreground, 0xf7f8ff, 0.98);
    cairo_move_to(cr, x + 10, y + 7);
    pango_cairo_show_layout(cr, layout);
    if (compact_out) |compact| {
        compact.* = @intFromBool(
            width <= 320 and height <= 92 and x >= 0 and
                x + width <= @as(f64, @floatFromInt(options.allocation_width)) + 0.5 and
                y + height <= @as(f64, @floatFromInt(options.allocation_height)) + 0.5,
        );
    }
    return 1;
}

pub export fn noctty_grid_render_status_feedback(
    cr_raw: ?*Cairo,
    options_raw: ?*const TextOverlay,
) callconv(.c) c_int {
    const cr = cr_raw orelse return 0;
    const options = options_raw orelse return 0;
    const text = options.text orelse return 0;
    if (text[0] == 0 or options.allocation_width <= 0 or options.allocation_height <= 0) return 0;
    const layout = pango_cairo_create_layout(cr) orelse return 0;
    defer g_object_unref(layout);
    pango_layout_set_text(layout, text, -1);
    const max_width = @max(120, @as(f64, @floatFromInt(options.allocation_width)) - 40);
    pango_layout_set_width(layout, @intFromFloat(@min(560, max_width) * @as(f64, pango_scale)));
    pango_layout_set_wrap(layout, pango_wrap_word_char);
    pango_layout_set_alignment(layout, pango_align_center);
    const font = pango_font_description_from_string("Sans Bold 11") orelse return 0;
    defer pango_font_description_free(font);
    pango_layout_set_font_description(layout, font);
    var text_width: c_int = 0;
    var text_height: c_int = 0;
    pango_layout_get_pixel_size(layout, &text_width, &text_height);
    const width = @min(max_width, @max(160, @as(f64, @floatFromInt(text_width)) + 28));
    const height = @max(38, @as(f64, @floatFromInt(text_height)) + 20);
    const x = @max(8, (@as(f64, @floatFromInt(options.allocation_width)) - width) / 2);
    const y: f64 = 16;
    cairo_save(cr);
    defer cairo_restore(cr);
    roundedRectangle(cr, x, y, width, height, 8);
    setColor(cr, options.palette, color_overlay_background, 0x12151d, 0.96);
    cairo_fill_preserve(cr);
    cairo_set_line_width(cr, options.border_width);
    setColor(cr, options.palette, color_overlay_border, 0xf2b82e, 0.92);
    cairo_stroke(cr);
    setColor(cr, options.palette, color_overlay_foreground, 0xf7f8ff, 1);
    cairo_move_to(
        cr,
        x + (width - @as(f64, @floatFromInt(text_width))) / 2,
        y + (height - @as(f64, @floatFromInt(text_height))) / 2,
    );
    pango_cairo_show_layout(cr, layout);
    return 1;
}

pub export fn noctty_grid_render_text_decoration(
    cr_raw: ?*Cairo,
    options_raw: ?*const TextDecoration,
) callconv(.c) c_int {
    const cr = cr_raw orelse return 0;
    const options = options_raw orelse return 0;
    if (options.style & (8 | 16) == 0 or options.end <= options.first) return 0;
    if (!std.math.isFinite(options.cell_width) or
        !std.math.isFinite(options.cell_height) or
        !std.math.isFinite(options.baseline) or
        options.cell_width <= 0 or options.cell_height <= 0) return 0;

    cairo_save(cr);
    defer cairo_restore(cr);
    setTerminalColor(
        cr,
        options.palette,
        options.foreground,
        if (options.style & 32 != 0) 0.55 else 1,
    );
    cairo_set_line_width(cr, 1);
    cairo_set_line_cap(cr, cairo_line_cap_square);
    var extents: FontExtents = undefined;
    cairo_font_extents(cr, &extents);
    const left = 4 + @as(f64, @floatFromInt(options.first)) * options.cell_width;
    const right = 4 + @as(f64, @floatFromInt(options.end)) * options.cell_width;
    const top = 2 + @as(f64, @floatFromInt(options.row)) * options.cell_height;
    var result: c_int = 1;
    if (options.style & 8 != 0) {
        const bottom = top + options.cell_height - 1.5;
        const candidate = options.baseline + @max(1.5, extents.descent * 0.75);
        const y = @min(bottom, @floor(candidate) + 0.5);
        cairo_move_to(cr, left, y);
        cairo_line_to(cr, right, y);
        cairo_stroke(cr);
        if (y > options.baseline and y <= bottom) result |= 2;
    }
    if (options.style & 16 != 0) {
        const candidate = options.baseline - extents.ascent * 0.34;
        const y = @floor(candidate) + 0.5;
        cairo_move_to(cr, left, y);
        cairo_line_to(cr, right, y);
        cairo_stroke(cr);
    }
    return result;
}

pub export fn noctty_grid_render_scrollbar(
    cr_raw: ?*Cairo,
    options_raw: ?*const Scrollbar,
) callconv(.c) c_int {
    const cr = cr_raw orelse return 0;
    const options = options_raw orelse return 0;
    if (options.allocation_height <= 0 or options.width <= 0 or options.thumb_height <= 0) return 0;
    cairo_save(cr);
    defer cairo_restore(cr);
    cairo_rectangle(cr, options.x, 0, options.width, @floatFromInt(options.allocation_height));
    setColor(cr, options.palette, color_scrollbar_track, 0x0e1016, 1);
    cairo_fill(cr);
    const thumb_x = options.x + 2;
    const thumb_width = @max(4, options.width - 4);
    roundedRectangle(cr, thumb_x, options.thumb_y, thumb_width, options.thumb_height, thumb_width / 2);
    const active = options.dragging != 0 or options.hovered != 0;
    setColor(
        cr,
        options.palette,
        if (active) color_scrollbar_hover else color_scrollbar_thumb,
        if (active) 0xf2b82e else 0x8c96aa,
        if (options.dragging != 0) 0.95 else 0.88,
    );
    cairo_fill(cr);
    return 1;
}

fn testColorResolver(_: ?*anyopaque, role: u32) callconv(.c) u32 {
    return if (role == color_overlay_border) 0x123456 else std.math.maxInt(u32);
}

test "palette resolution is explicit and preserves fallback colors" {
    const palette: Palette = .{ .userdata = null, .resolve = testColorResolver };
    try std.testing.expectEqual(@as(u32, 0x123456), resolvedRGB(
        palette,
        color_overlay_border,
        0xffffff,
    ));
    try std.testing.expectEqual(@as(u32, 0xabcdef), resolvedRGB(
        palette,
        color_overlay_background,
        0xabcdef,
    ));
    try std.testing.expectEqual(@as(u32, 0x654321), resolvedRGB(
        .{ .userdata = null, .resolve = null },
        color_overlay_border,
        0x654321,
    ));
}

// Cairo constants used by this adapter are asserted here rather than inherited
// through translated system headers.
comptime {
    std.debug.assert(operator_source == 1);
    std.debug.assert(@sizeOf(Palette) == @sizeOf(usize) * 2);
}
