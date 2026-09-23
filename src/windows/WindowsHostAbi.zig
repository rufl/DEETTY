//! Shared callback and Win32 handle types for the native host and renderer.
//!
//! These declarations are Zig-owned because no C translation unit consumes
//! them. Keeping one Windows header import also prevents pseudo-handle types
//! from diverging across independently translated declarations.

pub const c = @cImport({
    @cDefine("UNICODE", "1");
    @cDefine("_UNICODE", "1");
    @cDefine("WIN32_LEAN_AND_MEAN", "1");
    @cDefine("NOMINMAX", "1");
    @cDefine("_FORTIFY_SOURCE", "0");
    @cInclude("windows.h");
    @cInclude("commctrl.h");
    @cInclude("commdlg.h");
});

const LaunchProfile = @import("noctty_share").launch_profile;
const Feed = *const fn (?*anyopaque, [*]const u8, usize) callconv(.c) c_int;
const Write = *const fn (?*anyopaque, [*]const u8, usize) callconv(.c) c_int;
const TakeReply = *const fn (?*anyopaque, [*]u8, usize) callconv(.c) c_int;
const TakeRemote = *const fn (?*anyopaque, ?*anyopaque, [*]u8, usize) callconv(.c) c_int;
const Cell = *const fn (?*anyopaque, c_int, c_int) callconv(.c) u64;
const CellText = *const fn (?*anyopaque, c_int, c_int, [*]u8, usize) callconv(.c) c_int;
const ColorRgb = *const fn (?*anyopaque, u32) callconv(.c) u32;
const Cursor = *const fn (?*anyopaque) callconv(.c) u32;
const Title = *const fn (?*anyopaque, [*]u8, usize) callconv(.c) c_int;
const Resize = *const fn (?*anyopaque, c_int, c_int) callconv(.c) c_int;
const Scroll = *const fn (?*anyopaque, c_int) callconv(.c) c_int;
const CursorMode = *const fn (?*anyopaque) callconv(.c) c_int;
const Unary = *const fn (?*anyopaque) callconv(.c) c_int;
const PaneLayout = *const fn (
    ?*anyopaque,
    c_int,
    *u32,
    *u32,
    *u32,
    *u32,
    *c_int,
    *c_int,
) callconv(.c) c_int;
const PaneDimensions = *const fn (?*anyopaque, c_int, *u16, *u16) callconv(.c) c_int;
const PaneCell = *const fn (?*anyopaque, c_int, c_int, c_int) callconv(.c) u64;
const PaneCellText = *const fn (
    ?*anyopaque,
    c_int,
    c_int,
    c_int,
    [*]u8,
    usize,
) callconv(.c) c_int;
const PaneColorRgb = *const fn (?*anyopaque, c_int, u32) callconv(.c) u32;
const PaneCursor = *const fn (?*anyopaque, c_int) callconv(.c) u32;
const PaneSelect = *const fn (?*anyopaque, c_int) callconv(.c) c_int;
const PaneTagMask = *const fn (?*anyopaque, c_int) callconv(.c) c_int;
const PaneTagSet = *const fn (?*anyopaque, c_int, c_int) callconv(.c) c_int;
const SmartFilterGet = *const fn (?*anyopaque) callconv(.c) c_int;
const PaneFeed = *const fn (?*anyopaque, c_int, [*]const u8, usize) callconv(.c) c_int;
const SmartFilterSet = *const fn (?*anyopaque, c_int) callconv(.c) c_int;
const PaneTakeReply = *const fn (?*anyopaque, c_int, [*]u8, usize) callconv(.c) c_int;
const PaneResize = *const fn (?*anyopaque, c_int, c_int, c_int) callconv(.c) c_int;
const WorkspaceAction = *const fn (?*anyopaque, c_int, c_int, c_int) callconv(.c) c_int;
const WorkspaceClose = *const fn (?*anyopaque, c_int) callconv(.c) u32;
const PreferenceGet = *const fn (?*anyopaque, c_int) callconv(.c) c_int;
const PreferenceSet = *const fn (?*anyopaque, c_int, c_int) callconv(.c) c_int;
const WorkspacePersistence = *const fn (?*anyopaque, c_int, c_int, c_int) callconv(.c) c_int;
const PaneMouseMode = *const fn (?*anyopaque, c_int) callconv(.c) u32;
const PaneMouseEncode = *const fn (
    ?*anyopaque,
    c_int,
    c_int,
    c_int,
    c_int,
    c_int,
    c_int,
    [*]u8,
    usize,
) callconv(.c) c_int;
const PaneCopy = *const fn (
    ?*anyopaque,
    c_int,
    [*]u8,
    usize,
    c_int,
    c_int,
    c_int,
    c_int,
) callconv(.c) c_int;
const SharePeerInfo = *const fn (
    ?*anyopaque,
    c_int,
    [*]u8,
    usize,
    *usize,
    [*]u8,
    usize,
    *usize,
    *u16,
) callconv(.c) c_int;
const SharePair = *const fn (?*anyopaque, [*]const u8, usize, [*]const u8, usize, u16) callconv(.c) c_int;
const TabTitle = *const fn (?*anyopaque, c_int, [*]u8, usize) callconv(.c) c_int;
const TabRename = *const fn (?*anyopaque, c_int, [*]const u8, usize) callconv(.c) c_int;
const TabMove = *const fn (?*anyopaque, c_int, c_int) callconv(.c) c_int;
const DividerInfo = *const fn (
    ?*anyopaque,
    c_int,
    *c_int,
    *c_int,
    *u32,
    *u32,
    *u32,
    *u32,
    *u32,
) callconv(.c) c_int;
const DividerSet = *const fn (?*anyopaque, c_int, c_int) callconv(.c) c_int;
const DividerAdjust = *const fn (?*anyopaque, c_int, c_int) callconv(.c) c_int;

pub const Callbacks = extern struct {
    userdata: ?*anyopaque,
    feed: Feed,
    write: Write,
    take_reply: TakeReply,
    take_remote: TakeRemote,
    cell: Cell,
    cell_text: CellText,
    color_rgb: ColorRgb,
    cursor: Cursor,
    title: Title,
    resize: Resize,
    scroll: Scroll,
    cursor_mode: CursorMode,
    smoke_ready: Unary,
    start: Unary,
    stop: Unary,
    next_stream: Unary,
    next_tab: Unary,
    tab_count: Unary,
    tab_active: Unary,
    /// Stable local root identity; negative in remote mode or for invalid index.
    tab_identity: PaneSelect,
    /// UTF-8 bytes without NUL; negative means failure.
    tab_title: TabTitle,
    /// Selection/mutation: positive success, zero unchanged, negative failure.
    tab_select: PaneSelect,
    tab_rename: TabRename,
    tab_move: TabMove,
    divider_count: Unary,
    /// Ordinal -> stable node, axis (0=width/1=height), normalized parent rect,
    /// ratio in permille. Positive success, zero absent, negative failure.
    divider_info: DividerInfo,
    divider_set: DividerSet,
    divider_adjust: DividerAdjust,
    divider_reset: Unary,
    pane_count: Unary,
    pane_layout: PaneLayout,
    pane_dimensions: PaneDimensions,
    pane_cell: PaneCell,
    pane_cell_text: PaneCellText,
    pane_color_rgb: PaneColorRgb,
    pane_cursor: PaneCursor,
    pane_tag_mask: PaneTagMask,
    pane_tag_set: PaneTagSet,
    smart_filter_get: SmartFilterGet,
    smart_filter_set: SmartFilterSet,
    pane_select: PaneSelect,
    pane_feed: PaneFeed,
    pane_take_reply: PaneTakeReply,
    pane_resize: PaneResize,
    workspace_action: WorkspaceAction,
    active_pane: Unary,
    workspace_close: WorkspaceClose,
    remote_pane: Unary,
    preference_get: PreferenceGet,
    preference_set: PreferenceSet,
    profile_count: Unary,
    profile_active: Unary,
    profile_name: TabTitle,
    /// Custom-only read; all mutations return zero on success, negative on failure.
    profile_get: *const fn (?*anyopaque, c_int, *LaunchProfile.NamedProfile) callconv(.c) c_int,
    /// Index -1 creates; indices >= 2 edit and rename. Save atomically selects.
    profile_save: *const fn (?*anyopaque, c_int, [*]const u8, usize, *const LaunchProfile.Profile) callconv(.c) c_int,
    profile_remove: PaneSelect,
    profile_select: PaneSelect,
    /// Resolves each new pane: 0/1 builtin, 2 copied custom spec, negative failure.
    profile_launch: *const fn (?*anyopaque, c_int, *LaunchProfile.Profile) callconv(.c) c_int,
    theme_count: Unary,
    theme_active: Unary,
    /// UTF-8 bytes without NUL; negative means failure.
    theme_name: TabTitle,
    /// Theme mutation returns zero on success, negative on failure.
    theme_select: PaneSelect,
    theme_import: Write,
    theme_export: Write,
    /// Roles 0/1/2 are foreground/background/cursor; packed 0xRRGGBB.
    theme_color: *const fn (?*anyopaque, c_int) callconv(.c) u32,
    workspace_persistence: WorkspacePersistence,
    pane_mouse_mode: PaneMouseMode,
    pane_mouse_encode: PaneMouseEncode,
    share_peer_count: Unary,
    share_peer_info: SharePeerInfo,
    share_peer_revoke: PaneSelect,
    share_pair: SharePair,
    share_discover: Unary,
    pane_copy: PaneCopy,
};

pub const RenderState = extern struct {
    window: c.HWND,
    callbacks: *const Callbacks,
    font_normal: c.HFONT,
    font_bold: c.HFONT,
    cell_width: c_int,
    cell_height: c_int,
    content_top: c_int,
    columns: c_int,
    rows: c_int,
    foreground: u32,
    background: u32,
    selection_active: c_int,
    selection_pane: c_int,
    selection_anchor_column: c_int,
    selection_anchor_row: c_int,
    selection_extent_column: c_int,
    selection_extent_row: c_int,
    divider_preview_node: c_int,
    divider_preview_ratio: u32,
};
