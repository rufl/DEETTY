//! Experimental native Windows executable.
//!
//! Shared VT and sharing models remain platform-neutral. Win32 windows,
//! ConPTY, clipboard, menu, font, title, and GDI rendering are composed by
//! focused Zig adapters; GTK and POSIX-only state stay out of this target.

const std = @import("std");
const windows = std.os.windows;
const Share = @import("noctty_share");
const Vt = Share.vt;
const Crypto = Share.crypto;
const Release = @import("noctty_release");
const WindowsHostLogic = @import("WindowsHostLogic.zig");
const WindowsDiagnostics = @import("WindowsDiagnostics.zig");
const WindowsPty = @import("WindowsPty.zig");
const WindowsClipboard = @import("WindowsClipboard.zig");
const WindowsProcess = @import("WindowsProcess.zig");
const WindowsMenu = @import("WindowsMenu.zig");
const WindowsFonts = @import("WindowsFonts.zig");
const WindowsTitle = @import("WindowsTitle.zig");
const WindowsRenderer = @import("WindowsRenderer.zig");
const Dpapi = @import("Dpapi.zig");
const WindowsHost = @import("WindowsHost.zig");
const Workspace = @import("WindowsWorkspace.zig");
const WindowsAppearance = @import("WindowsAppearance.zig");
const WindowsThemeLibrary = @import("WindowsThemeLibrary.zig");
const WindowsLaunchProfiles = @import("WindowsLaunchProfiles.zig");
const LaunchProfile = Share.launch_profile;
const WindowsWorkspace = Workspace.WindowsWorkspace;
const WorkspaceSnapshot = Workspace.WorkspaceSnapshot;
const WindowsPreferences = Workspace.WindowsPreferences;
const PersistedWindowsState = Workspace.PersistedWindowsState;
const persisted_state_capacity = Workspace.persisted_state_capacity;
const encodePersistedWindowsState = Workspace.encodePersistedWindowsState;
const decodePersistedWindowsState = Workspace.decodePersistedWindowsState;

comptime {
    _ = WindowsHostLogic.noctty_windows_workspace_state_init;
    _ = WindowsHostLogic.noctty_windows_workspace_local_operation;
    _ = WindowsHostLogic.noctty_windows_workspace_startup_plan;
    _ = WindowsHostLogic.noctty_windows_session_start_plan;
    _ = WindowsHostLogic.noctty_windows_session_started;
    _ = WindowsHostLogic.noctty_windows_session_start_failed;
    _ = WindowsHostLogic.noctty_windows_session_is_live;
    _ = WindowsHostLogic.noctty_windows_workspace_resize_count;
    _ = WindowsHostLogic.noctty_windows_session_resize_plan;
    _ = WindowsHostLogic.noctty_windows_workspace_action_result;
    _ = WindowsHostLogic.noctty_windows_workspace_rollback_matches;
    _ = WindowsHostLogic.noctty_windows_workspace_close_plan;
    _ = WindowsHostLogic.noctty_windows_workspace_close_commit;
    _ = WindowsHostLogic.noctty_windows_workspace_reset;
    _ = WindowsHostLogic.noctty_windows_decode_key_action;
    _ = WindowsHostLogic.noctty_windows_decode_menu_command;
    _ = WindowsHostLogic.noctty_windows_normalize_preferences;
    _ = WindowsHostLogic.noctty_windows_blend_rgb;
    _ = WindowsHostLogic.noctty_windows_rgb_from_colorref;
    _ = WindowsHostLogic.noctty_windows_colorref_from_rgb;
    _ = WindowsHostLogic.noctty_windows_grid_dimensions;
    _ = WindowsHostLogic.noctty_windows_encode_utf16_input;
    _ = WindowsHostLogic.noctty_windows_compute_pane_geometry;
    _ = WindowsHostLogic.noctty_windows_pointer_cell;
    _ = WindowsHostLogic.noctty_windows_cell_selected;
    _ = WindowsHostLogic.noctty_windows_mouse_route;
    _ = WindowsHostLogic.noctty_windows_mouse_transition;
    _ = WindowsHostLogic.noctty_windows_special_key_sequence;
    _ = WindowsDiagnostics.noctty_windows_diagnostics_init;
    _ = WindowsDiagnostics.noctty_windows_diagnostics_write;
    _ = WindowsDiagnostics.noctty_windows_diagnostics_deinit;
    _ = WindowsPty.noctty_windows_pty_create;
    _ = WindowsPty.noctty_windows_pty_destroy;
    _ = WindowsPty.noctty_windows_pty_write;
    _ = WindowsPty.noctty_windows_pty_drain;
    _ = WindowsPty.noctty_windows_pty_resize;
    _ = WindowsPty.noctty_windows_pty_poll_exit;
    _ = WindowsPty.noctty_windows_pty_exited;
    _ = WindowsPty.noctty_windows_pty_exit_code;
    _ = WindowsClipboard.noctty_windows_clipboard_paste;
    _ = WindowsClipboard.noctty_windows_clipboard_copy;
    _ = WindowsProcess.noctty_windows_launch_nocted;
    _ = WindowsMenu.noctty_windows_menu_create;
    _ = WindowsMenu.noctty_windows_menu_update;
    _ = WindowsMenu.noctty_windows_menu_deinit;
    _ = WindowsFonts.noctty_windows_fonts_update;
    _ = WindowsFonts.noctty_windows_fonts_deinit;
    _ = WindowsTitle.noctty_windows_update_title;
    _ = WindowsRenderer.noctty_windows_theme_colors;
    _ = WindowsRenderer.noctty_windows_render;
}

const columns_initial: usize = 120;
const rows_initial: usize = 36;
const State = struct {
    workspace: WindowsWorkspace,
    store: Share.identity.Store,
    preferences: WindowsPreferences = .{},
    themes: WindowsThemeLibrary.Library = .init(std.heap.page_allocator, 0),
    profiles: WindowsLaunchProfiles.Library = .init(0),
    saved_workspace: ?WorkspaceSnapshot = null,
    live_host: ?*Share.live_host.LiveHost = null,
    control_prompt_active: bool = false,
    shared_pane: ?usize = null,
    live_viewer: ?*Share.live_viewer.LiveViewer = null,
};

extern "user32" fn MessageBoxW(
    ?windows.HWND,
    [*:0]const u16,
    [*:0]const u16,
    windows.UINT,
) callconv(.winapi) c_int;
extern "user32" fn IsWindow(windows.HWND) callconv(.winapi) windows.BOOL;

fn readPersistedWindowsState() !?PersistedWindowsState {
    var bytes: [persisted_state_capacity]u8 = undefined;
    const length = Dpapi.stateLoad(&bytes) catch return error.WindowsStateLoadFailed;
    return try decodePersistedWindowsState(bytes[0..(length orelse return null)]);
}

fn writePersistedWindowsState(state: *const State) !void {
    var bytes: [persisted_state_capacity]u8 = undefined;
    const length = try encodePersistedWindowsState(.{
        .preferences = state.preferences,
        .workspace = state.saved_workspace,
    }, &bytes);
    Dpapi.stateSave(bytes[0..length]) catch return error.WindowsStateSaveFailed;
}

fn applyPersistedWindowsState(state: *State) void {
    const persisted = readPersistedWindowsState() catch return;
    const value = persisted orelse return;
    state.preferences = value.preferences;
    state.saved_workspace = value.workspace;
    if (state.preferences.restore_workspace) {
        const snapshot_value = state.saved_workspace orelse return;
        state.workspace.restore(
            snapshot_value,
            columns_initial,
            rows_initial,
        ) catch {};
    }
}

const ThemeSink = struct {
    pub fn save(_: @This(), bytes: []const u8) !void {
        try Dpapi.themeStateSave(bytes);
    }
};

fn applyPersistedThemes(state: *State) void {
    // Legacy preferences seed only the fallback; corrupt state is never repaired
    // implicitly. An explicit selection/import is the only durable replacement.
    state.themes.selected = @intFromEnum(state.preferences.theme);
    const allocator = state.themes.allocator;
    const bytes = (Dpapi.themeStateLoadAlloc(allocator, WindowsThemeLibrary.max_state_bytes) catch return) orelse return;
    defer allocator.free(bytes);
    const loaded = WindowsThemeLibrary.decodeStateAlloc(allocator, bytes) catch return;
    state.themes.deinit();
    state.themes = loaded;
}

const ProfileSink = struct {
    pub fn save(_: @This(), bytes: []const u8) !void {
        try Dpapi.profileStateSave(bytes);
    }
};

fn applyPersistedProfiles(state: *State) void {
    state.profiles = .init(@intFromEnum(state.preferences.launch_profile));
    var bytes: [WindowsLaunchProfiles.max_state_bytes]u8 = undefined;
    const length = (Dpapi.profileStateLoad(&bytes) catch return) orelse return;
    state.profiles = WindowsLaunchProfiles.decodeState(bytes[0..length]) catch return;
}

pub export fn wWinMain(
    instance: windows.HINSTANCE,
    previous_instance: ?windows.HINSTANCE,
    command_line: [*:0]u16,
    show_command: c_int,
) callconv(.c) c_int {
    _ = previous_instance;
    if (WindowsPty.qualificationChild(command_line)) |result| return result;

    const command = std.mem.span(command_line);
    if (firstAsciiTokenIs(command, "--version")) {
        const version_text = std.unicode.utf8ToUtf16LeStringLiteral(
            "NOCTTY " ++ Release.version ++ " Windows alpha",
        );
        _ = MessageBoxW(
            null,
            version_text,
            std.unicode.utf8ToUtf16LeStringLiteral("NOCTTY"),
            0x40,
        );
        return 0;
    }
    const self_test_requested = firstAsciiTokenIs(command, "--self-test");

    var threaded: std.Io.Threaded = .init(std.heap.page_allocator, .{});
    defer threaded.deinit();
    const random = Crypto.fromIo(threaded.io());
    var store = loadOrCreateStore() catch return 1;
    const mode = parseShareMode(command) catch {
        showWindowsMessage(
            "Usage: --pair-listen PORT ALIAS REMOTE_HOST, " ++ "--pair-connect HOST PORT ALIAS, --discover, --list-pairs, " ++ "--revoke INDEX, --share INDEX PORT, or --receive INDEX",
        );
        store.deinit();
        return 1;
    };
    if (mode.kind == .pair_listen or mode.kind == .pair_connect) {
        const result = runPairing(&store, random, mode);
        store.deinit();
        return result;
    }
    if (mode.kind == .discover) {
        const result = runDiscovery();
        store.deinit();
        return result;
    }
    if (mode.kind == .list_pairs) {
        showWindowsPeers(&store);
        store.deinit();
        return 0;
    }
    if (mode.kind == .revoke) {
        if (mode.index >= store.peer_count) {
            showWindowsMessage("No paired device has that index.");
            store.deinit();
            return 1;
        }
        store.peerSlice()[mode.index].revoked = true;
        saveStore(&store) catch {
            showWindowsMessage("Could not persist paired-device revocation.");
            store.deinit();
            return 1;
        };
        showWindowsMessage("Paired device revoked.");
        store.deinit();
        return 0;
    }
    var state = State{
        .workspace = WindowsWorkspace.init(
            std.heap.page_allocator,
            columns_initial,
            rows_initial,
        ) catch {
            store.deinit();
            return 1;
        },
        .store = store,
    };
    defer {
        if (state.live_host) |host| host.destroy();
        if (state.live_viewer) |viewer| viewer.destroy();
        state.workspace.deinit();
        state.store.deinit();
        state.themes.deinit();
    }
    if (!self_test_requested) {
        applyPersistedWindowsState(&state);
        applyPersistedThemes(&state);
        applyPersistedProfiles(&state);
    }

    if (self_test_requested) return if (selfTest(&state)) 0 else 1;
    if (mode.kind == .share) {
        if (mode.index >= state.store.peer_count) {
            showWindowsMessage("No paired device has that index.");
            return 1;
        }
        if (state.store.peerSliceConst()[mode.index].revoked) {
            showWindowsMessage(
                "That paired device is revoked. Pair it again before sharing.",
            );
            return 1;
        }
        if (mode.port == 0) {
            showWindowsMessage("Sharing requires a nonzero TCP port.");
            return 1;
        }
        state.live_host = Share.live_host.LiveHost.create(
            std.heap.page_allocator,
            random,
            state.store.identity,
            state.store.peerSliceConst()[mode.index],
            pairedPeerTrusted,
            null,
            mode.port,
            .pane,
            &.{.{
                .tab_id = 1,
                .title = "Windows terminal",
                .active = true,
                .active_pane_id = 1,
                .root_node = 0,
                .node_count = 1,
            }},
            &.{.{ .pane_id = 1, .tab_id = 1, .title = "ConPTY" }},
            &.{.{
                .tab_id = 1,
                .kind = .leaf,
                .pane_id = 1,
                .ratio_permille = 0,
            }},
        ) catch {
            showWindowsMessage(
                "Could not start sharing. Check the selected device and port.",
            );
            return 1;
        };
        state.shared_pane = state.workspace.activePaneIndex();
    } else if (mode.kind == .receive) {
        if (mode.index >= state.store.peer_count) {
            showWindowsMessage("No paired device has that index.");
            return 1;
        }
        if (state.store.peerSliceConst()[mode.index].revoked) {
            showWindowsMessage(
                "That paired device is revoked. Pair it again before receiving.",
            );
            return 1;
        }
        state.live_viewer = Share.live_viewer.LiveViewer.create(
            std.heap.page_allocator,
            random,
            state.store.identity,
            state.store.peerSliceConst()[mode.index],
        ) catch {
            showWindowsMessage(
                "Could not receive the selected device. Check its endpoint.",
            );
            return 1;
        };
    }

    const callbacks = WindowsHost.Callbacks{
        .userdata = &state,
        .feed = feed,
        .write = localWrite,
        .take_reply = takeReply,
        .take_remote = takeRemote,
        .cell = cell,
        .cell_text = cellText,
        .color_rgb = colorRgb,
        .cursor = cursor,
        .title = title,
        .resize = resize,
        .scroll = scroll,
        .cursor_mode = cursorMode,
        .smoke_ready = smokeReady,
        .start = localStart,
        .stop = localStop,
        .next_stream = nextStream,
        .next_tab = nextTab,
        .tab_count = tabCount,
        .tab_active = tabActive,
        .tab_identity = tabIdentity,
        .tab_title = tabTitle,
        .tab_select = tabSelect,
        .tab_rename = tabRename,
        .tab_move = tabMove,
        .pane_count = paneCount,
        .pane_layout = paneLayout,
        .divider_count = dividerCount,
        .divider_info = dividerInfo,
        .divider_set = dividerSet,
        .divider_adjust = dividerAdjust,
        .divider_reset = dividerReset,
        .pane_dimensions = paneDimensions,
        .pane_cell = paneCell,
        .pane_cell_text = paneCellText,
        .pane_color_rgb = paneColorRgb,
        .pane_cursor = paneCursor,
        .pane_tag_mask = paneTagMask,
        .pane_tag_set = paneTagSet,
        .smart_filter_get = smartFilterGet,
        .smart_filter_set = smartFilterSet,
        .pane_select = paneSelect,
        .pane_feed = paneFeed,
        .pane_take_reply = paneTakeReply,
        .pane_resize = paneResize,
        .workspace_action = workspaceAction,
        .active_pane = activePane,
        .workspace_close = workspaceClose,
        .remote_pane = remotePane,
        .preference_get = preferenceGet,
        .preference_set = preferenceSet,
        .theme_count = themeCount,
        .theme_active = themeActive,
        .theme_name = themeName,
        .theme_select = themeSelect,
        .theme_import = themeImport,
        .theme_export = themeExport,
        .theme_color = themeColor,
        .profile_count = profileCount,
        .profile_active = profileActive,
        .profile_name = profileName,
        .profile_get = profileGet,
        .profile_save = profileSave,
        .profile_remove = profileRemove,
        .profile_select = profileSelect,
        .profile_launch = profileLaunch,
        .workspace_persistence = workspacePersistence,
        .pane_mouse_mode = paneMouseMode,
        .pane_mouse_encode = paneMouseEncode,
        .pane_copy = paneCopy,
    };
    return WindowsHost.run(@ptrCast(@alignCast(instance)), show_command, &callbacks);
}

fn loadOrCreateIdentity() !Crypto.Identity {
    var secret: [Crypto.secret_key_length]u8 = undefined;
    defer std.crypto.secureZero(u8, &secret);
    const loaded = Dpapi.identityLoad(&secret) catch
        return error.WindowsIdentityLoadFailed;
    if (loaded) return Crypto.Identity.fromSecret(secret);

    Dpapi.random(&secret) catch return error.WindowsRandomFailed;
    const identity = try Crypto.Identity.fromSecret(secret);
    Dpapi.identitySave(&identity.secret_key) catch
        return error.WindowsIdentitySaveFailed;
    return identity;
}

fn loadOrCreateStore() !Share.identity.Store {
    var bytes: [Share.identity.max_file_bytes]u8 = undefined;
    defer std.crypto.secureZero(u8, &bytes);
    const length = Dpapi.peersLoad(&bytes, null) catch
        return error.WindowsPeerStoreLoadFailed;
    if (length) |count| return Share.identity.import(bytes[0..count]);
    return Share.identity.Store.init(try loadOrCreateIdentity());
}

// LiveHost serializes this callback. Atomic replacement changes the file identity;
// the loaded version is captured from the same open file as the decrypted bytes.
var peer_trust_cache: ?struct {
    version: Dpapi.PeerStoreVersion,
    public_key: [Crypto.public_key_length]u8,
    trusted: bool,
} = null;

fn pairedPeerTrusted(public_key: [Crypto.public_key_length]u8) bool {
    const current_version = Dpapi.peersVersion() catch {
        peer_trust_cache = null;
        return false;
    };
    if (peer_trust_cache) |cache| {
        if (std.meta.eql(cache.version, current_version) and
            std.mem.eql(u8, &cache.public_key, &public_key)) return cache.trusted;
    }
    peer_trust_cache = null;
    var bytes: [Share.identity.max_file_bytes]u8 = undefined;
    defer std.crypto.secureZero(u8, &bytes);
    var loaded_version: Dpapi.PeerStoreVersion = undefined;
    const length = (Dpapi.peersLoad(&bytes, &loaded_version) catch return false) orelse return false;
    var store = Share.identity.import(bytes[0..length]) catch return false;
    defer store.deinit();
    const peer = store.find(public_key) orelse return false;
    peer_trust_cache = .{
        .version = loaded_version,
        .public_key = public_key,
        .trusted = !peer.revoked,
    };
    return !peer.revoked;
}

fn saveStore(store: *const Share.identity.Store) !void {
    const bytes = try Share.identity.exportAlloc(std.heap.page_allocator, store);
    defer {
        std.crypto.secureZero(u8, bytes);
        std.heap.page_allocator.free(bytes);
    }
    Dpapi.peersSave(bytes) catch return error.WindowsPeerStoreSaveFailed;
}

const ShareMode = struct {
    const Kind = enum { local, pair_listen, pair_connect, discover, list_pairs, revoke, share, receive };
    kind: Kind = .local,
    index: usize = 0,
    port: u16 = 0,
    host: [Share.identity.max_endpoint_bytes]u8 = [_]u8{0} ** Share.identity.max_endpoint_bytes,
    host_length: usize = 0,
    alias: [Share.protocol.max_alias_bytes]u8 = [_]u8{0} ** Share.protocol.max_alias_bytes,
    alias_length: usize = 0,

    fn hostSlice(self: *const ShareMode) []const u8 {
        return self.host[0..self.host_length];
    }

    fn aliasSlice(self: *const ShareMode) []const u8 {
        return self.alias[0..self.alias_length];
    }
};

fn nextAsciiToken(command: []const u16, cursor_index: *usize, output: []u8) ![]const u8 {
    var cursor_index_value = cursor_index.*;
    while (cursor_index_value < command.len and command[cursor_index_value] == ' ')
        cursor_index_value += 1;
    if (cursor_index_value == command.len) return error.MissingWindowsShareArgument;
    const quoted = command[cursor_index_value] == '"';
    if (quoted) cursor_index_value += 1;
    var length: usize = 0;
    while (cursor_index_value < command.len) : (cursor_index_value += 1) {
        const value = command[cursor_index_value];
        if ((quoted and value == '"') or (!quoted and value == ' ')) break;
        if (value > 0x7f or length == output.len) return error.InvalidWindowsShareArgument;
        output[length] = @intCast(value);
        length += 1;
    }
    if (quoted) {
        if (cursor_index_value == command.len or command[cursor_index_value] != '"')
            return error.InvalidWindowsShareArgument;
        cursor_index_value += 1;
    }
    cursor_index.* = cursor_index_value;
    if (length == 0) return error.InvalidWindowsShareArgument;
    return output[0..length];
}

fn parseShareMode(command: []const u16) !ShareMode {
    var cursor_index: usize = 0;
    var token_buffer: [256]u8 = undefined;
    const first = nextAsciiToken(command, &cursor_index, &token_buffer) catch |err| switch (err) {
        error.MissingWindowsShareArgument => return .{},
        else => return err,
    };
    var mode = ShareMode{};
    if (std.mem.eql(u8, first, "--pair-listen")) {
        mode.kind = .pair_listen;
        mode.port = try std.fmt.parseInt(u16, try nextAsciiToken(command, &cursor_index, &token_buffer), 10);
        const alias = try nextAsciiToken(command, &cursor_index, &token_buffer);
        if (alias.len > mode.alias.len) return error.InvalidWindowsShareArgument;
        @memcpy(mode.alias[0..alias.len], alias);
        mode.alias_length = alias.len;
        const host = try nextAsciiToken(command, &cursor_index, &token_buffer);
        if (host.len > mode.host.len) return error.InvalidWindowsShareArgument;
        @memcpy(mode.host[0..host.len], host);
        mode.host_length = host.len;
    } else if (std.mem.eql(u8, first, "--pair-connect")) {
        mode.kind = .pair_connect;
        const host = try nextAsciiToken(command, &cursor_index, &token_buffer);
        if (host.len > mode.host.len) return error.InvalidWindowsShareArgument;
        @memcpy(mode.host[0..host.len], host);
        mode.host_length = host.len;
        mode.port = try std.fmt.parseInt(u16, try nextAsciiToken(command, &cursor_index, &token_buffer), 10);
        const alias = try nextAsciiToken(command, &cursor_index, &token_buffer);
        if (alias.len > mode.alias.len) return error.InvalidWindowsShareArgument;
        @memcpy(mode.alias[0..alias.len], alias);
        mode.alias_length = alias.len;
    } else if (std.mem.eql(u8, first, "--discover")) {
        mode.kind = .discover;
    } else if (std.mem.eql(u8, first, "--list-pairs")) {
        mode.kind = .list_pairs;
    } else if (std.mem.eql(u8, first, "--revoke")) {
        mode.kind = .revoke;
        mode.index = try std.fmt.parseInt(usize, try nextAsciiToken(command, &cursor_index, &token_buffer), 10);
    } else if (std.mem.eql(u8, first, "--share")) {
        mode.kind = .share;
        mode.index = try std.fmt.parseInt(usize, try nextAsciiToken(command, &cursor_index, &token_buffer), 10);
        mode.port = try std.fmt.parseInt(u16, try nextAsciiToken(command, &cursor_index, &token_buffer), 10);
    } else if (std.mem.eql(u8, first, "--receive")) {
        mode.kind = .receive;
        mode.index = try std.fmt.parseInt(usize, try nextAsciiToken(command, &cursor_index, &token_buffer), 10);
    }
    return mode;
}

fn showWindowsMessage(message: []const u8) void {
    var wide: [4096:0]u16 = [_:0]u16{0} ** 4096;
    const count = @min(message.len, wide.len - 1);
    for (message[0..count], 0..) |byte, index| wide[index] = byte;
    _ = MessageBoxW(
        null,
        &wide,
        std.unicode.utf8ToUtf16LeStringLiteral("NOCTTY Session Sharing"),
        0x40,
    );
}

fn showWindowsPeers(store: *const Share.identity.Store) void {
    if (store.peer_count == 0) {
        showWindowsMessage("No paired devices.");
        return;
    }
    var text: [4096]u8 = undefined;
    var length: usize = 0;
    const heading = "Paired devices:\r\n";
    @memcpy(text[0..heading.len], heading);
    length = heading.len;
    for (store.peerSliceConst(), 0..) |peer, index| {
        const line = std.fmt.bufPrint(
            text[length..],
            "{d}: {s} - {s}:{d}{s}\r\n",
            .{
                index,
                peer.alias(),
                peer.endpoint(),
                peer.port,
                if (peer.revoked) " (revoked)" else "",
            },
        ) catch break;
        length += line.len;
    }
    showWindowsMessage(text[0..length]);
}

fn confirmWindowsSas(sas: u32) bool {
    var message: [128]u8 = undefined;
    const text = std.fmt.bufPrint(
        &message,
        "Compare this code on both devices: {d:0>6}. Confirm only if identical.",
        .{sas},
    ) catch return false;
    var wide: [128:0]u16 = [_:0]u16{0} ** 128;
    for (text, 0..) |byte, index| wide[index] = byte;
    return MessageBoxW(
        null,
        &wide,
        std.unicode.utf8ToUtf16LeStringLiteral("NOCTTY Pairing"),
        0x34,
    ) == 6;
}
fn runDiscovery() c_int {
    var discovery = Share.transport.Discovery.open() catch {
        showWindowsMessage("Could not start LAN discovery.");
        return 1;
    };
    defer discovery.close();
    var packet: [Share.transport.max_discovery_bytes]u8 = undefined;
    var source: [64]u8 = undefined;
    for (0..750) |_| {
        if (!(discovery.readable(20) catch false)) continue;
        const found = discovery.receive(&packet, &source) catch continue;
        if (!found.announcement.accepts_sessions) continue;
        var message: [512]u8 = undefined;
        const text = std.fmt.bufPrint(
            &message,
            "Untrusted LAN hint: {s} at {s}:{d}.\r\nUse --pair-connect {s} {d} ALIAS, then trust only if the six-digit code matches.",
            .{
                found.announcement.alias,
                found.source,
                found.announcement.tcp_port,
                found.source,
                found.announcement.tcp_port,
            },
        ) catch return 1;
        showWindowsMessage(text);
        return 0;
    }
    showWindowsMessage("No pairing listener was discovered on this LAN. Use a direct endpoint for tailnets and routed VPNs.");
    return 1;
}

fn runPairing(store: *Share.identity.Store, random: Crypto.RandomContext, mode: ShareMode) c_int {
    const controller = switch (mode.kind) {
        .pair_listen => Share.pair_controller.Controller.listen(
            std.heap.page_allocator,
            random,
            store.identity,
            null,
            mode.port,
            mode.aliasSlice(),
            mode.hostSlice(),
            mode.port,
        ),
        .pair_connect => Share.pair_controller.Controller.connect(
            std.heap.page_allocator,
            random,
            store.identity,
            mode.hostSlice(),
            mode.port,
            mode.aliasSlice(),
        ),
        else => return 1,
    } catch {
        showWindowsMessage("Could not start pairing. Check the endpoint and port.");
        return 1;
    };
    defer controller.destroy();
    var announcement: ?Share.transport.Discovery = if (mode.kind == .pair_listen)
        Share.transport.Discovery.open() catch null
    else
        null;
    defer if (announcement) |*active| active.close();
    var announcement_instance: [16]u8 = undefined;
    if (announcement != null) {
        var ephemeral = Crypto.Identity.generate(random);
        defer ephemeral.deinit();
        announcement_instance = ephemeral.public_key[0..16].*;
    }
    for (0..3000) |attempt| {
        const status = controller.statusSnapshot();
        if (status == .sas_ready or status == .failed or status == .rejected) break;
        if (announcement) |*active| {
            if (attempt % 100 == 0) active.announce(.{
                .instance_id = announcement_instance,
                .tcp_port = controller.listeningPort(),
                .accepts_sessions = true,
                .alias = "NOCTTY Windows pairing listener",
            }) catch {
                active.close();
                announcement = null;
            };
        }
        Share.transport.sleepMilliseconds(random, 20);
    }
    if (controller.statusSnapshot() != .sas_ready) {
        showWindowsMessage("Pairing timed out or failed.");
        return 1;
    }
    if (!confirmWindowsSas(controller.sas())) {
        controller.reject();
        return 1;
    }
    controller.confirm();
    for (0..3000) |_| {
        const status = controller.statusSnapshot();
        if (status == .paired or status == .failed or status == .rejected) break;
        Share.transport.sleepMilliseconds(random, 20);
    }
    const peer = controller.takePeer() orelse {
        showWindowsMessage("Pairing confirmation failed.");
        return 1;
    };
    store.addOrUpdate(peer) catch {
        showWindowsMessage(
            "Could not retain the paired device. Revoke an unused device and " ++
                "try again.",
        );
        return 1;
    };
    saveStore(store) catch {
        showWindowsMessage(
            "The pairing handshake succeeded, but Windows could not save the " ++
                "device. Check profile-storage permissions and pair again.",
        );
        return 1;
    };
    showWindowsMessage("Paired device saved. Use --share 0 PORT or --receive 0.");
    return 0;
}

fn confirmWindowsControl(owner: windows.HWND) bool {
    return MessageBoxW(
        owner,
        std.unicode.utf8ToUtf16LeStringLiteral(
            "The paired viewer requests terminal control for one shared pane on this connection. Grant it?",
        ),
        std.unicode.utf8ToUtf16LeStringLiteral("NOCTTY Remote Control"),
        0x34,
    ) == 6;
}

fn localWrite(raw: ?*anyopaque, bytes: [*]const u8, length: usize) callconv(.c) c_int {
    const state = stateFromRaw(raw) orelse return -1;
    const viewer = state.live_viewer orelse return 0;
    viewer.sendInput(bytes[0..length]) catch |err| {
        if (err == error.ShareInputNotGranted and viewer.currentStatus() == .connected)
            viewer.requestControl() catch return -1;
        return 0;
    };
    return std.math.cast(c_int, length) orelse -1;
}

fn localStart(raw: ?*anyopaque) callconv(.c) c_int {
    const state = stateFromRaw(raw) orelse return -1;
    return @intFromBool(state.live_viewer != null);
}

fn localStop(_: ?*anyopaque) callconv(.c) c_int {
    return 0;
}

fn stateFromRaw(raw: ?*anyopaque) ?*State {
    return @ptrCast(@alignCast(raw orelse return null));
}
const RemoteInputSink = struct {
    output: []u8,
    length: usize = 0,

    pub fn write(self: *RemoteInputSink, bytes: []const u8) !void {
        if (self.length + bytes.len > self.output.len) return error.RemoteInputBufferFull;
        @memcpy(self.output[self.length .. self.length + bytes.len], bytes);
        self.length += bytes.len;
    }
};

fn feed(raw: ?*anyopaque, bytes: [*]const u8, length: usize) callconv(.c) c_int {
    const state = stateFromRaw(raw) orelse return -1;
    const grid = state.workspace.activeGrid() orelse return -1;
    if (length > 2 * 1024 * 1024) return -1;
    grid.feed(bytes[0..length]) catch return -1;
    if (state.live_host) |host| {
        if (state.shared_pane == state.workspace.activePaneIndex())
            host.captureGrid(1, grid) catch return -1;
    }
    return std.math.cast(c_int, length) orelse -1;
}

fn takeReply(raw: ?*anyopaque, output: [*]u8, capacity: usize) callconv(.c) c_int {
    const state = stateFromRaw(raw) orelse return -1;
    if (state.live_viewer != null) return 0;
    if (capacity == 0) return 0;
    const grid = state.workspace.activeGrid() orelse return -1;
    const pending = grid.pendingReplies();
    const count = @min(pending.len, capacity);
    @memcpy(output[0..count], pending[0..count]);
    grid.consumeReplies(count);
    return std.math.cast(c_int, count) orelse -1;
}

fn paneFeed(
    raw: ?*anyopaque,
    index_raw: c_int,
    bytes: [*]const u8,
    length: usize,
) callconv(.c) c_int {
    if (index_raw < 0 or length > 2 * 1024 * 1024) return -1;
    const state = stateFromRaw(raw) orelse return -1;
    const pane_index: usize = @intCast(index_raw);
    const grid = state.workspace.paneGrid(pane_index) orelse return -1;
    grid.feed(bytes[0..length]) catch return -1;
    if (state.shared_pane == pane_index) {
        if (state.live_host) |host| host.captureGrid(1, grid) catch return -1;
    }
    return std.math.cast(c_int, length) orelse -1;
}

fn paneTakeReply(
    raw: ?*anyopaque,
    index_raw: c_int,
    output: [*]u8,
    capacity: usize,
) callconv(.c) c_int {
    if (index_raw < 0 or capacity == 0) return 0;
    const state = stateFromRaw(raw) orelse return -1;
    const grid = state.workspace.paneGrid(@intCast(index_raw)) orelse return -1;
    const pending = grid.pendingReplies();
    const count = @min(pending.len, capacity);
    @memcpy(output[0..count], pending[0..count]);
    grid.consumeReplies(count);
    return std.math.cast(c_int, count) orelse -1;
}

fn paneResize(
    raw: ?*anyopaque,
    index_raw: c_int,
    columns: c_int,
    rows: c_int,
) callconv(.c) c_int {
    if (index_raw < 0 or columns < 1 or rows < 1) return -1;
    if (columns > 1000 or rows > 500) return -1;
    const state = stateFromRaw(raw) orelse return -1;
    const grid = state.workspace.paneGrid(@intCast(index_raw)) orelse return -1;
    grid.resize(@intCast(columns), @intCast(rows)) catch return -1;
    return 0;
}

fn workspaceAction(
    raw: ?*anyopaque,
    action: c_int,
    columns: c_int,
    rows: c_int,
) callconv(.c) c_int {
    if (columns < 1 or rows < 1 or columns > 1000 or rows > 500) return -1;
    const state = stateFromRaw(raw) orelse return -1;
    if (state.live_viewer != null) return 0;
    const pane_index = switch (action) {
        1 => state.workspace.newTab(@intCast(columns), @intCast(rows)),
        2 => state.workspace.splitActive(
            .vertical,
            false,
            @intCast(columns),
            @intCast(rows),
        ),
        3 => state.workspace.splitActive(
            .horizontal,
            true,
            @intCast(columns),
            @intCast(rows),
        ),
        else => return -1,
    } catch return -1;
    return std.math.cast(c_int, pane_index + 1) orelse -1;
}

fn activePane(raw: ?*anyopaque) callconv(.c) c_int {
    const state = stateFromRaw(raw) orelse return -1;
    if (state.live_viewer) |viewer|
        return std.math.cast(c_int, viewer.selectedIndex()) orelse -1;
    const pane_index = state.workspace.activePaneIndex() orelse return -1;
    return std.math.cast(c_int, pane_index) orelse -1;
}

fn remotePane(raw: ?*anyopaque) callconv(.c) c_int {
    const state = stateFromRaw(raw) orelse return -1;
    const pane_index = state.shared_pane orelse return -1;
    return std.math.cast(c_int, pane_index) orelse -1;
}

fn workspaceClose(raw: ?*anyopaque, action: c_int) callconv(.c) u32 {
    const state = stateFromRaw(raw) orelse return 0;
    if (state.live_viewer != null) return 0;
    const result: u32 = switch (action) {
        1 => if (state.workspace.closeActivePane()) |pane_index|
            @as(u32, 1) << @intCast(pane_index)
        else
            0,
        2 => state.workspace.closeActiveTab(),
        3 => if (state.workspace.paneTotal() > 1)
            @as(u32, 1) << @intCast(state.workspace.activePaneIndex() orelse return 0)
        else
            0,
        4 => state.workspace.activeTabMask(),
        else => 0,
    };
    if ((action == 3 or action == 4) and result != 0) {
        if (state.shared_pane) |pane_index| {
            if ((result & (@as(u32, 1) << @intCast(pane_index))) != 0) {
                if (state.live_host) |host| host.destroy();
                state.live_host = null;
                state.shared_pane = null;
            }
        }
    }
    return result;
}

fn profileCount(raw: ?*anyopaque) callconv(.c) c_int {
    const state = stateFromRaw(raw) orelse return -1;
    return @intCast(state.profiles.count());
}

fn profileActive(raw: ?*anyopaque) callconv(.c) c_int {
    const state = stateFromRaw(raw) orelse return -1;
    return @intCast(state.profiles.selected);
}

fn profileName(raw: ?*anyopaque, index: c_int, output: [*]u8, capacity: usize) callconv(.c) c_int {
    if (index < 0) return -1;
    const state = stateFromRaw(raw) orelse return -1;
    const name = state.profiles.name(@intCast(index)) orelse return -1;
    if (name.len > capacity) return -1;
    @memcpy(output[0..name.len], name);
    return @intCast(name.len);
}

fn profileGet(raw: ?*anyopaque, index: c_int, output: *LaunchProfile.NamedProfile) callconv(.c) c_int {
    if (index < 2) return -1;
    const state = stateFromRaw(raw) orelse return -1;
    output.* = (state.profiles.get(@intCast(index)) orelse return -1).*;
    return 0;
}

fn profileSave(raw: ?*anyopaque, index: c_int, name: [*]const u8, length: usize, profile: *const LaunchProfile.Profile) callconv(.c) c_int {
    if (index < -1 or index == 0 or index == 1 or length == 0 or length > LaunchProfile.max_name_bytes) return -1;
    const state = stateFromRaw(raw) orelse return -1;
    _ = state.profiles.save(if (index == -1) null else @intCast(index), name[0..length], profile.*, ProfileSink{}) catch return -1;
    return 0;
}

fn profileRemove(raw: ?*anyopaque, index: c_int) callconv(.c) c_int {
    if (index < 2) return -1;
    const state = stateFromRaw(raw) orelse return -1;
    state.profiles.remove(@intCast(index), ProfileSink{}) catch return -1;
    if (state.profiles.selected < 2) state.preferences.launch_profile = @enumFromInt(state.profiles.selected);
    return 0;
}

fn profileSelect(raw: ?*anyopaque, index: c_int) callconv(.c) c_int {
    if (index < 0) return -1;
    const state = stateFromRaw(raw) orelse return -1;
    state.profiles.select(@intCast(index), ProfileSink{}) catch return -1;
    if (index < 2) state.preferences.launch_profile = @enumFromInt(index);
    return 0;
}

fn profileLaunch(raw: ?*anyopaque, pane_index: c_int, output: *LaunchProfile.Profile) callconv(.c) c_int {
    if (pane_index < 0) return -1;
    const state = stateFromRaw(raw) orelse return -1;
    const grid = state.workspace.paneGrid(@intCast(pane_index)) orelse return -1;
    if (state.profiles.selected < 2) {
        grid.setHistoryLimit(LaunchProfile.default_scrollback_lines) catch return -1;
        return @intCast(state.profiles.selected);
    }
    const profile = &(state.profiles.get(state.profiles.selected) orelse return -1).profile;
    WindowsLaunchProfiles.validateProfile(profile) catch return -1;
    grid.setHistoryLimit(profile.scrollback_lines) catch return -1;
    output.* = profile.*;
    return 2;
}

fn themeCount(raw: ?*anyopaque) callconv(.c) c_int {
    const state = stateFromRaw(raw) orelse return -1;
    return @intCast(state.themes.count());
}

fn themeActive(raw: ?*anyopaque) callconv(.c) c_int {
    const state = stateFromRaw(raw) orelse return -1;
    return @intCast(state.themes.selected);
}

fn themeName(raw: ?*anyopaque, index: c_int, output: [*]u8, capacity: usize) callconv(.c) c_int {
    if (index < 0) return -1;
    const state = stateFromRaw(raw) orelse return -1;
    const theme = state.themes.theme(@intCast(index)) orelse return -1;
    const name = std.mem.trim(u8, theme.name, " \t\r\n");
    if (name.len > capacity) return -1;
    @memcpy(output[0..name.len], name);
    return @intCast(name.len);
}

fn themeSelect(raw: ?*anyopaque, index: c_int) callconv(.c) c_int {
    if (index < 0) return -1;
    const state = stateFromRaw(raw) orelse return -1;
    state.themes.select(@intCast(index), ThemeSink{}) catch return -1;
    if (WindowsAppearance.validTheme(index)) state.preferences.theme = @enumFromInt(index);
    return 0;
}

fn sourceThemeFormat(path: []const u8, contents: []const u8) ?Share.theme.ImportFormat {
    const basename_start = std.mem.lastIndexOfAny(u8, path, "/\\") orelse 0;
    const name = if (basename_start < path.len and (path[basename_start] == '/' or path[basename_start] == '\\'))
        path[basename_start + 1 ..]
    else
        path;
    if (std.ascii.endsWithIgnoreCase(name, ".conf") or std.ascii.endsWithIgnoreCase(name, ".ghostty")) return .ghostty;
    if (std.ascii.endsWithIgnoreCase(name, ".xresources") or std.ascii.endsWithIgnoreCase(name, ".xdefaults")) return .xresources;
    if (std.ascii.endsWithIgnoreCase(name, ".toml")) return .alacritty_toml;
    if (std.ascii.endsWithIgnoreCase(name, ".json")) {
        if (std.mem.indexOf(u8, contents, "\"dark\"") != null) return .noctalia_dark;
        if (std.mem.indexOf(u8, contents, "\"light\"") != null) return .noctalia_light;
        return .noctalia_active;
    }
    return null;
}

fn sourceThemeName(path: []const u8, output: *[97]u8) []const u8 {
    const separator = std.mem.lastIndexOfAny(u8, path, "/\\") orelse 0;
    const start = if (separator < path.len and (path[separator] == '/' or path[separator] == '\\')) separator + 1 else separator;
    const end = std.mem.lastIndexOfScalar(u8, path, '.') orelse path.len;
    const candidate = path[start..@min(end, path.len)];
    if (candidate.len > 0 and candidate.len <= 96) {
        Share.theme.validateName(candidate) catch return "Imported theme";
        @memcpy(output[0..candidate.len], candidate);
        return output[0..candidate.len];
    }
    const fallback = "Imported theme";
    @memcpy(output[0..fallback.len], fallback);
    return output[0..fallback.len];
}

fn importThemeSource(state: *State, path: []const u8, contents: []const u8) !void {
    const format = sourceThemeFormat(path, contents) orelse return error.UnsupportedThemeSource;
    var name_buffer: [97]u8 = undefined;
    const imported = try Share.theme.importTheme(
        state.themes.allocator,
        format,
        sourceThemeName(path, &name_buffer),
        contents,
    );
    const portable = try Share.theme_storage.exportThemeLibraryAlloc(state.themes.allocator, &.{imported});
    defer state.themes.allocator.free(portable);
    try state.themes.importPortable(portable, ThemeSink{});
}

fn themeImport(raw: ?*anyopaque, path: [*]const u8, length: usize) callconv(.c) c_int {
    if (length == 0 or length > 131_068) return -1;
    const state = stateFromRaw(raw) orelse return -1;
    const allocator = state.themes.allocator;
    const bytes = Dpapi.readFileAllocUtf8(allocator, path[0..length], WindowsThemeLibrary.max_file_bytes) catch return -1;
    defer allocator.free(bytes);
    if (sourceThemeFormat(path[0..length], bytes) != null) {
        importThemeSource(state, path[0..length], bytes) catch return -1;
    } else {
        state.themes.importPortable(bytes, ThemeSink{}) catch return -1;
    }
    return 0;
}

fn themeExport(raw: ?*anyopaque, path: [*]const u8, length: usize) callconv(.c) c_int {
    if (length == 0 or length > 131_068) return -1;
    const state = stateFromRaw(raw) orelse return -1;
    const allocator = state.themes.allocator;
    const bytes = state.themes.exportPortableAlloc() catch return -1;
    defer allocator.free(bytes);
    Dpapi.writeFileAtomicUtf8(allocator, path[0..length], bytes) catch return -1;
    return 0;
}

fn themeColor(raw: ?*anyopaque, role: c_int) callconv(.c) u32 {
    const state = stateFromRaw(raw) orelse return 0xffffffff;
    const theme = state.themes.selectedTheme();
    return switch (role) {
        0 => WindowsThemeLibrary.rgb(theme.foreground),
        1 => WindowsThemeLibrary.rgb(theme.background),
        2 => WindowsThemeLibrary.rgb(theme.cursor),
        else => 0xffffffff,
    };
}

fn preferenceGet(raw: ?*anyopaque, field: c_int) callconv(.c) c_int {
    const state = stateFromRaw(raw) orelse return -1;
    return switch (field) {
        1 => state.themes.preferenceTheme(),
        2 => state.preferences.font_size_pt,
        3 => @intCast(@min(state.profiles.selected, 2)),
        4 => @intFromBool(state.preferences.restore_workspace),
        else => -1,
    };
}

fn preferenceSet(
    raw: ?*anyopaque,
    field: c_int,
    value: c_int,
) callconv(.c) c_int {
    const state = stateFromRaw(raw) orelse return -1;
    const previous = state.preferences;
    switch (field) {
        1 => {
            if (!WindowsAppearance.validTheme(value)) return -1;
            return themeSelect(raw, value);
        },
        2 => {
            if (!WindowsAppearance.validFontSize(value)) return -1;
            state.preferences.font_size_pt = @intCast(value);
        },
        3 => {
            if (value != 0 and value != 1) return -1;
            return profileSelect(raw, value);
        },
        4 => state.preferences.restore_workspace = switch (value) {
            0 => false,
            1 => true,
            else => return -1,
        },
        else => return -1,
    }
    writePersistedWindowsState(state) catch {
        state.preferences = previous;
        return -1;
    };
    return 0;
}

fn workspacePersistence(
    raw: ?*anyopaque,
    action: c_int,
    columns: c_int,
    rows: c_int,
) callconv(.c) c_int {
    const state = stateFromRaw(raw) orelse return -1;
    if (state.live_host != null or state.live_viewer != null) return 0;
    switch (action) {
        1 => {
            const previous = state.saved_workspace;
            state.saved_workspace = state.workspace.snapshot();
            writePersistedWindowsState(state) catch {
                state.saved_workspace = previous;
                return -1;
            };
            return 1;
        },
        2 => {
            if (columns < 1 or rows < 1 or columns > 1000 or rows > 500)
                return -1;
            const snapshot_value = state.saved_workspace orelse return 0;
            state.workspace.restore(
                snapshot_value,
                @intCast(columns),
                @intCast(rows),
            ) catch return -1;
            return 1;
        },
        else => return -1,
    }
}

fn takeRemote(raw: ?*anyopaque, owner: ?*anyopaque, output: [*]u8, capacity: usize) callconv(.c) c_int {
    const state = stateFromRaw(raw) orelse return -1;
    if (state.control_prompt_active) return 0;
    const host = state.live_host orelse return 0;
    if (state.shared_pane) |pane_index| {
        const grid = state.workspace.paneGrid(pane_index) orelse return 0;
        host.captureGrid(1, grid) catch return -1;
    }
    if (host.controlRequest()) |request| {
        const window: windows.HWND = @ptrCast(owner orelse return 0);
        state.control_prompt_active = true;
        defer state.control_prompt_active = false;
        const approved = confirmWindowsControl(window);
        // The owned modal dialog pumps messages: closing a pane can destroy its host.
        if (state.live_host != host or !IsWindow(window).toBool()) return 0;
        _ = host.respondControl(request, approved);
    }
    var sink = RemoteInputSink{ .output = output[0..capacity] };
    _ = host.drainInput(1, &sink) catch return -1;
    return std.math.cast(c_int, sink.length) orelse -1;
}

fn cell(raw: ?*anyopaque, column: c_int, row: c_int) callconv(.c) u64 {
    const state = stateFromRaw(raw) orelse return ' ';
    if (column < 0 or row < 0) return ' ';
    if (state.live_viewer) |viewer|
        return viewer.packedCell(@intCast(column), @intCast(row));
    const grid = state.workspace.activeGrid() orelse return ' ';
    return grid.packedCell(@intCast(column), @intCast(row));
}

fn cellText(
    raw: ?*anyopaque,
    column: c_int,
    row: c_int,
    output: [*]u8,
    capacity: usize,
) callconv(.c) c_int {
    const state = stateFromRaw(raw) orelse return -1;
    if (column < 0 or row < 0 or capacity == 0) return 0;
    if (state.live_viewer) |viewer|
        return std.math.cast(c_int, viewer.cellText(
            @intCast(column),
            @intCast(row),
            output[0..capacity],
        )) orelse -1;
    const grid = state.workspace.activeGrid() orelse return -1;
    const count = grid.cellText(
        @intCast(column),
        @intCast(row),
        output[0..capacity],
    );
    return std.math.cast(c_int, count) orelse -1;
}

fn colorRgb(raw: ?*anyopaque, color_id: u32) callconv(.c) u32 {
    const state = stateFromRaw(raw) orelse return 0xffffffff;
    if (color_id > std.math.maxInt(u16)) return 0xffffffff;
    if (state.themes.indexedColor(color_id)) |rgb|
        return rgb;
    if (state.live_viewer) |viewer| return viewer.colorRgb(@intCast(color_id));
    const grid = state.workspace.activeGrid() orelse return 0xffffffff;
    return grid.colorRgb(@intCast(color_id));
}

fn cursor(raw: ?*anyopaque) callconv(.c) u32 {
    const state = stateFromRaw(raw) orelse return 0xffffffff;
    if (state.live_viewer) |viewer| return viewer.cursor();
    const grid = state.workspace.activeGrid() orelse return 0xffffffff;
    if (!grid.cursor_visible) return 0xffffffff;
    if (grid.cursor_row > std.math.maxInt(u16)) return 0xffffffff;
    if (grid.cursor_column > std.math.maxInt(u16)) return 0xffffffff;
    return (@as(u32, @intCast(grid.cursor_row)) << 16) |
        @as(u32, @intCast(grid.cursor_column));
}

fn title(raw: ?*anyopaque, output: [*]u8, capacity: usize) callconv(.c) c_int {
    const state = stateFromRaw(raw) orelse return -1;
    if (state.live_viewer) |viewer| {
        const selected = viewer.streamInfo(viewer.selectedIndex(), &.{}) orelse return 0;
        const scope_label = switch (viewer.shareScope()) {
            .pane => "Pane share · ",
            .tab => "Tab share · ",
            .session => "Session share · ",
        };
        const scope_count = @min(scope_label.len, capacity);
        @memcpy(output[0..scope_count], scope_label[0..scope_count]);
        var count = scope_count;
        var tab_title: [Share.protocol.max_title_bytes]u8 = undefined;
        for (0..viewer.tabCount()) |index| {
            const tab = viewer.tabInfo(index, &tab_title) orelse continue;
            if (tab.tab_id != selected.tab_id) continue;
            const copied = @min(tab.title_length, capacity - count);
            @memcpy(output[count .. count + copied], tab_title[0..copied]);
            count += copied;
        }
        if (count != 0 and count < capacity) {
            const separator = " — ";
            const copied = @min(separator.len, capacity - count);
            @memcpy(output[count .. count + copied], separator[0..copied]);
            count += copied;
        }
        if (count < capacity) count += viewer.title(output[count..capacity]);
        return std.math.cast(c_int, count) orelse -1;
    }
    const grid = state.workspace.activeGrid() orelse return 0;
    var count: usize = 0;
    const pane_count = state.workspace.activeTabPaneCount();
    if (state.workspace.tab_count > 1 or pane_count > 1) {
        var prefix_buffer: [96]u8 = undefined;
        const prefix = std.fmt.bufPrint(
            &prefix_buffer,
            "Tab {d}/{d} · {d} {s} — ",
            .{
                state.workspace.active_tab + 1,
                state.workspace.tab_count,
                pane_count,
                if (pane_count == 1) "pane" else "panes",
            },
        ) catch return -1;
        count = @min(prefix.len, capacity);
        @memcpy(output[0..count], prefix[0..count]);
    }
    const value = grid.titleSlice();
    const title_count = @min(value.len, capacity - count);
    @memcpy(output[count .. count + title_count], value[0..title_count]);
    return std.math.cast(c_int, count + title_count) orelse -1;
}

fn resize(raw: ?*anyopaque, columns: c_int, rows: c_int) callconv(.c) c_int {
    const state = stateFromRaw(raw) orelse return -1;
    if (state.live_viewer != null) return 0;
    if (columns < 1 or rows < 1) return -1;
    if (columns > 1000 or rows > 500) return -1;
    const grid = state.workspace.activeGrid() orelse return -1;
    grid.resize(@intCast(columns), @intCast(rows)) catch return -1;
    return 0;
}

fn scroll(raw: ?*anyopaque, lines: c_int) callconv(.c) c_int {
    const state = stateFromRaw(raw) orelse return -1;
    if (state.live_viewer) |viewer| {
        viewer.scrollViewport(lines) catch return -1;
        return 0;
    }
    const grid = state.workspace.activeGrid() orelse return -1;
    grid.scrollViewport(lines);
    return 0;
}

fn cursorMode(raw: ?*anyopaque) callconv(.c) c_int {
    const state = stateFromRaw(raw) orelse return 0;
    if (state.live_viewer) |viewer|
        return @intFromBool(viewer.applicationCursorKeys());
    const grid = state.workspace.activeGrid() orelse return 0;
    return @intFromBool(grid.application_cursor_keys);
}

fn paneCount(raw: ?*anyopaque) callconv(.c) c_int {
    const state = stateFromRaw(raw) orelse return -1;
    if (state.live_viewer) |viewer|
        return std.math.cast(c_int, viewer.streamCount()) orelse -1;
    return std.math.cast(c_int, state.workspace.highestPaneIndex()) orelse -1;
}

fn paneTagMask(raw: ?*anyopaque, index_raw: c_int) callconv(.c) c_int {
    const state = stateFromRaw(raw) orelse return -1;
    if (state.live_viewer != null or index_raw < 0) return -1;
    return state.workspace.paneTagMask(@intCast(index_raw)) orelse -1;
}

fn paneTagSet(raw: ?*anyopaque, index_raw: c_int, tag_mask: c_int) callconv(.c) c_int {
    const state = stateFromRaw(raw) orelse return -1;
    if (state.live_viewer != null or index_raw < 0 or tag_mask < 0 or tag_mask > 255) return -1;
    return @intFromBool(state.workspace.setPaneTagMask(@intCast(index_raw), @intCast(tag_mask)) catch return -1);
}

fn smartFilterGet(raw: ?*anyopaque) callconv(.c) c_int {
    const state = stateFromRaw(raw) orelse return -1;
    if (state.live_viewer != null) return -1;
    return state.workspace.smartFilterMask();
}

fn smartFilterSet(raw: ?*anyopaque, filter_mask: c_int) callconv(.c) c_int {
    const state = stateFromRaw(raw) orelse return -1;
    if (state.live_viewer != null or filter_mask < 0 or filter_mask > 255) return -1;
    return @intFromBool(state.workspace.setSmartFilterMask(@intCast(filter_mask)));
}

fn paneLayout(
    raw: ?*anyopaque,
    index_raw: c_int,
    x_output: *u32,
    y_output: *u32,
    width_output: *u32,
    height_output: *u32,
    selected_output: *c_int,
    host_active_output: *c_int,
) callconv(.c) c_int {
    if (index_raw < 0) return -1;
    const state = stateFromRaw(raw) orelse return -1;
    if (state.live_viewer) |viewer| {
        const layout = viewer.paneLayout(@intCast(index_raw)) orelse return -1;
        x_output.* = layout.x;
        y_output.* = layout.y;
        width_output.* = layout.width;
        height_output.* = layout.height;
        selected_output.* = @intFromBool(layout.selected);
        host_active_output.* = @intFromBool(layout.host_active);
        return @intFromBool(layout.visible);
    }
    const pane_index: usize = @intCast(index_raw);
    const rectangle = state.workspace.paneRect(pane_index) orelse return 0;
    x_output.* = rectangle.x;
    y_output.* = rectangle.y;
    width_output.* = rectangle.width;
    height_output.* = rectangle.height;
    const active = state.workspace.activePaneIndex() == pane_index;
    selected_output.* = @intFromBool(active);
    host_active_output.* = @intFromBool(active);
    return 1;
}

fn dividerCount(raw: ?*anyopaque) callconv(.c) c_int {
    const state = stateFromRaw(raw) orelse return 0;
    if (state.live_viewer != null) return 0;
    return @intCast(state.workspace.dividerCount());
}

fn dividerInfo(
    raw: ?*anyopaque,
    ordinal: c_int,
    node: *c_int,
    axis: *c_int,
    x: *u32,
    y: *u32,
    width: *u32,
    height: *u32,
    ratio: *u32,
) callconv(.c) c_int {
    const state = stateFromRaw(raw) orelse return -1;
    if (state.live_viewer != null or ordinal < 0) return -1;
    const divider = state.workspace.dividerInfo(@intCast(ordinal)) orelse return 0;
    node.* = @intCast(divider.node);
    axis.* = divider.axis;
    x.* = divider.rectangle.x;
    y.* = divider.rectangle.y;
    width.* = divider.rectangle.width;
    height.* = divider.rectangle.height;
    ratio.* = divider.ratio_permille;
    return 1;
}

fn dividerSet(raw: ?*anyopaque, node: c_int, ratio: c_int) callconv(.c) c_int {
    const state = stateFromRaw(raw) orelse return -1;
    if (state.live_viewer != null or node < 0) return -1;
    return @intFromBool(state.workspace.setDividerRatio(@intCast(node), ratio) catch return -1);
}

fn dividerAdjust(raw: ?*anyopaque, axis: c_int, delta: c_int) callconv(.c) c_int {
    const state = stateFromRaw(raw) orelse return -1;
    if (state.live_viewer != null or axis < 0 or axis > 1) return -1;
    return @intFromBool(state.workspace.adjustDivider(@intCast(axis), delta) catch return -1);
}

fn dividerReset(raw: ?*anyopaque) callconv(.c) c_int {
    const state = stateFromRaw(raw) orelse return -1;
    if (state.live_viewer != null) return -1;
    return @intFromBool(state.workspace.resetDividers());
}

fn paneDimensions(
    raw: ?*anyopaque,
    index_raw: c_int,
    columns_output: *u16,
    rows_output: *u16,
) callconv(.c) c_int {
    if (index_raw < 0) return -1;
    const state = stateFromRaw(raw) orelse return -1;
    if (state.live_viewer) |viewer| {
        const dimensions = viewer.streamDimensions(@intCast(index_raw));
        columns_output.* = dimensions.columns;
        rows_output.* = dimensions.rows;
        return @intFromBool(dimensions.columns != 0 and dimensions.rows != 0);
    }
    const grid = state.workspace.paneGrid(@intCast(index_raw)) orelse return 0;
    columns_output.* = std.math.cast(u16, grid.columns) orelse return -1;
    rows_output.* = std.math.cast(u16, grid.rows) orelse return -1;
    return 1;
}

fn paneCell(
    raw: ?*anyopaque,
    index_raw: c_int,
    column: c_int,
    row: c_int,
) callconv(.c) u64 {
    if (index_raw < 0 or column < 0 or row < 0) return ' ';
    const state = stateFromRaw(raw) orelse return ' ';
    if (state.live_viewer) |viewer|
        return viewer.streamPackedCell(@intCast(index_raw), @intCast(column), @intCast(row));
    const grid = state.workspace.paneGrid(@intCast(index_raw)) orelse return ' ';
    return grid.packedCell(@intCast(column), @intCast(row));
}

fn paneCellText(
    raw: ?*anyopaque,
    index_raw: c_int,
    column: c_int,
    row: c_int,
    output: [*]u8,
    capacity: usize,
) callconv(.c) c_int {
    if (index_raw < 0 or column < 0 or row < 0 or capacity == 0) return 0;
    const state = stateFromRaw(raw) orelse return -1;
    if (state.live_viewer) |viewer|
        return std.math.cast(c_int, viewer.streamCellText(
            @intCast(index_raw),
            @intCast(column),
            @intCast(row),
            output[0..capacity],
        )) orelse -1;
    const grid = state.workspace.paneGrid(@intCast(index_raw)) orelse return 0;
    return std.math.cast(c_int, grid.cellText(
        @intCast(column),
        @intCast(row),
        output[0..capacity],
    )) orelse -1;
}

fn paneColorRgb(raw: ?*anyopaque, index_raw: c_int, color_id: u32) callconv(.c) u32 {
    if (index_raw < 0 or color_id > std.math.maxInt(u16)) return 0xffffffff;
    const state = stateFromRaw(raw) orelse return 0xffffffff;
    if (state.themes.indexedColor(color_id)) |rgb|
        return rgb;
    if (state.live_viewer) |viewer|
        return viewer.streamColorRgb(@intCast(index_raw), @intCast(color_id));
    const grid = state.workspace.paneGrid(@intCast(index_raw)) orelse return 0xffffffff;
    return grid.colorRgb(@intCast(color_id));
}

fn paneCursor(raw: ?*anyopaque, index_raw: c_int) callconv(.c) u32 {
    if (index_raw < 0) return 0xffffffff;
    const state = stateFromRaw(raw) orelse return 0xffffffff;
    if (state.live_viewer) |viewer| return viewer.streamCursor(@intCast(index_raw));
    const grid = state.workspace.paneGrid(@intCast(index_raw)) orelse return 0xffffffff;
    if (!grid.cursor_visible or grid.cursor_row > std.math.maxInt(u16) or
        grid.cursor_column > std.math.maxInt(u16)) return 0xffffffff;
    return (@as(u32, @intCast(grid.cursor_row)) << 16) |
        @as(u32, @intCast(grid.cursor_column));
}

fn paneMouseMode(raw: ?*anyopaque, index_raw: c_int) callconv(.c) u32 {
    if (index_raw < 0) return 0;
    const state = stateFromRaw(raw) orelse return 0;
    if (state.live_viewer != null) return 0;
    const grid = state.workspace.paneGrid(@intCast(index_raw)) orelse return 0;
    return grid.mouseModeBits();
}

fn paneMouseEncode(
    raw: ?*anyopaque,
    index_raw: c_int,
    column: c_int,
    row: c_int,
    button: c_int,
    kind_raw: c_int,
    modifiers: c_int,
    output: [*]u8,
    capacity: usize,
) callconv(.c) c_int {
    if (index_raw < 0 or column < 0 or row < 0 or button < 0 or
        button > std.math.maxInt(u8)) return -1;
    const kind: Vt.MouseEventKind = switch (kind_raw) {
        0 => .press,
        1 => .release,
        2 => .motion,
        3 => .wheel,
        else => return -1,
    };
    const state = stateFromRaw(raw) orelse return -1;
    if (state.live_viewer != null) return 0;
    const grid = state.workspace.paneGrid(@intCast(index_raw)) orelse return -1;
    const length = grid.encodeMouse(.{
        .column = @intCast(column),
        .row = @intCast(row),
        .button = @intCast(button),
        .kind = kind,
        .modifiers = .{
            .shift = modifiers & 1 != 0,
            .alt = modifiers & 2 != 0,
            .control = modifiers & 4 != 0,
        },
    }, output[0..capacity]) orelse return 0;
    return std.math.cast(c_int, length) orelse -1;
}

fn paneCopy(
    raw: ?*anyopaque,
    index_raw: c_int,
    output: [*]u8,
    capacity: usize,
    start_column: c_int,
    start_row: c_int,
    end_column: c_int,
    end_row: c_int,
) callconv(.c) c_int {
    if (index_raw < 0) return -1;
    const state = stateFromRaw(raw) orelse return -1;
    const selected = start_column >= 0 and start_row >= 0 and
        end_column >= 0 and end_row >= 0;
    const range: ?Vt.SelectionRange = if (selected) .{
        .start_column = @intCast(start_column),
        .start_row = @intCast(start_row),
        .end_column = @intCast(end_column),
        .end_row = @intCast(end_row),
    } else null;
    const length = if (state.live_viewer) |viewer|
        viewer.copyStreamSelection(
            @intCast(index_raw),
            output[0..capacity],
            range,
        ) orelse return -1
    else blk: {
        const grid = state.workspace.paneGrid(@intCast(index_raw)) orelse
            return -1;
        break :blk grid.copySelection(output[0..capacity], range) orelse
            return -1;
    };
    return std.math.cast(c_int, length) orelse -1;
}
fn paneSelect(raw: ?*anyopaque, index_raw: c_int) callconv(.c) c_int {
    if (index_raw < 0) return -1;
    const state = stateFromRaw(raw) orelse return -1;
    if (state.live_viewer) |viewer| {
        viewer.selectStream(@intCast(index_raw)) catch return -1;
        return 0;
    }
    return if (state.workspace.selectPane(@intCast(index_raw))) 0 else -1;
}

fn nextStream(raw: ?*anyopaque) callconv(.c) c_int {
    const state = stateFromRaw(raw) orelse return -1;
    if (state.live_viewer) |viewer| {
        const count = viewer.streamCount();
        if (count < 2) return 0;
        const selected_index = viewer.selectedIndex();
        const selected = viewer.streamInfo(selected_index, &.{}) orelse return -1;
        for (1..count) |offset| {
            const next = (selected_index + offset) % count;
            const candidate = viewer.streamInfo(next, &.{}) orelse continue;
            if (candidate.tab_id != selected.tab_id) continue;
            viewer.selectStream(next) catch return -1;
            return std.math.cast(c_int, next + 1) orelse -1;
        }
        return 0;
    }
    return @intFromBool(state.workspace.nextPane());
}

fn tabCount(raw: ?*anyopaque) callconv(.c) c_int {
    const state = stateFromRaw(raw) orelse return -1;
    const count = if (state.live_viewer) |viewer|
        viewer.tabCount()
    else
        state.workspace.tab_count;
    return std.math.cast(c_int, count) orelse -1;
}

fn tabActive(raw: ?*anyopaque) callconv(.c) c_int {
    const state = stateFromRaw(raw) orelse return -1;
    if (state.live_viewer) |viewer| {
        for (0..viewer.tabCount()) |index| {
            const tab = viewer.tabInfo(index, &.{}) orelse continue;
            if (tab.selected) return std.math.cast(c_int, index) orelse -1;
        }
        return -1;
    }
    if (state.workspace.tab_count == 0) return -1;
    return @intCast(state.workspace.active_tab);
}

fn tabIdentity(raw: ?*anyopaque, index_raw: c_int) callconv(.c) c_int {
    if (index_raw < 0) return -1;
    const state = stateFromRaw(raw) orelse return -1;
    if (state.live_viewer != null) return -1;
    const index: usize = @intCast(index_raw);
    if (index >= state.workspace.tab_count) return -1;
    return state.workspace.tabs[index].root;
}

fn tabTitle(
    raw: ?*anyopaque,
    index_raw: c_int,
    output: [*]u8,
    capacity: usize,
) callconv(.c) c_int {
    if (index_raw < 0) return -1;
    const state = stateFromRaw(raw) orelse return -1;
    const index: usize = @intCast(index_raw);
    const length = if (state.live_viewer) |viewer| remote: {
        var buffer: [Share.protocol.max_title_bytes]u8 = undefined;
        const tab = viewer.tabInfo(index, &buffer) orelse return -1;
        if (tab.title_length != 0)
            break :remote Workspace.copyTitle(buffer[0..tab.title_length], output[0..capacity]);
        const fallback = std.fmt.bufPrint(&buffer, "Tab {d}", .{tab.tab_id}) catch return -1;
        break :remote Workspace.copyTitle(fallback, output[0..capacity]);
    } else state.workspace.tabTitle(index, output[0..capacity]) catch return -1;
    return std.math.cast(c_int, length) orelse -1;
}

fn tabSelect(raw: ?*anyopaque, index_raw: c_int) callconv(.c) c_int {
    if (index_raw < 0) return -1;
    const state = stateFromRaw(raw) orelse return -1;
    const index: usize = @intCast(index_raw);
    if (state.live_viewer) |viewer| {
        const tab = viewer.tabInfo(index, &.{}) orelse return -1;
        if (tab.selected) return 0;
        viewer.selectTab(index) catch return -1;
        return 1;
    }
    return @intFromBool(state.workspace.selectTab(index) catch return -1);
}

fn tabRename(
    raw: ?*anyopaque,
    index_raw: c_int,
    bytes: [*]const u8,
    length: usize,
) callconv(.c) c_int {
    if (index_raw < 0 or length > Workspace.max_tab_name_bytes) return -1;
    const state = stateFromRaw(raw) orelse return -1;
    if (state.live_viewer != null) return -1;
    return @intFromBool(state.workspace.renameTab(@intCast(index_raw), bytes[0..length]) catch return -1);
}

fn tabMove(raw: ?*anyopaque, from_raw: c_int, to_raw: c_int) callconv(.c) c_int {
    if (from_raw < 0 or to_raw < 0) return -1;
    const state = stateFromRaw(raw) orelse return -1;
    if (state.live_viewer != null) return -1;
    return @intFromBool(state.workspace.moveTab(@intCast(from_raw), @intCast(to_raw)) catch return -1);
}

fn nextTab(raw: ?*anyopaque) callconv(.c) c_int {
    const count = tabCount(raw);
    if (count < 0) return -1;
    if (count < 2) return 0;
    const selected = tabActive(raw);
    if (selected < 0) return -1;
    return tabSelect(raw, @mod(selected + 1, count));
}

fn smokeReady(raw: ?*anyopaque) callconv(.c) c_int {
    const state = stateFromRaw(raw) orelse return 0;
    const grid = state.workspace.activeGrid() orelse return 0;
    const marker = grid.findText(
        "NOCTTY_WINDOWS_HOST_OK",
        false,
        0,
    );
    return @intFromBool(marker != null);
}

fn firstAsciiTokenIs(command: []const u16, expected: []const u8) bool {
    var cursor_index: usize = 0;
    var token_buffer: [256]u8 = undefined;
    const token = nextAsciiToken(
        command,
        &cursor_index,
        &token_buffer,
    ) catch return false;
    return std.mem.eql(u8, token, expected);
}

fn profileSelfTest(state: *State) bool {
    const previous = state.profiles;
    defer state.profiles = previous;
    if (profileCount(state) != 2 or profileActive(state) != 0 or preferenceGet(state, 3) != 0) return false;
    var name: [LaunchProfile.max_name_bytes]u8 = undefined;
    const length = profileName(state, 1, &name, name.len);
    if (length < 0 or !std.mem.eql(u8, name[0..@intCast(length)], "Command Prompt")) return false;
    var named: LaunchProfile.NamedProfile = .{};
    if (profileGet(state, 0, &named) != -1 or profileRemove(state, 0) != -1 or
        profileSelect(state, 2) != -1 or profileName(state, 0, &name, 1) != -1) return false;
    var profile: LaunchProfile.Profile = .{};
    tryProfile: {
        profile.shell.set("C:\\Windows\\System32\\cmd.exe") catch break :tryProfile;
        profile.scrollback_lines = 321;
        var fixture: LaunchProfile.NamedProfile = .{ .profile = profile };
        fixture.name.set("Self-test") catch break :tryProfile;
        state.profiles.custom.entries[0] = fixture;
        state.profiles.custom.count = 1;
        state.profiles.custom.selected_index = 0;
        state.profiles.selected = 2;
        state.profiles.validate() catch break :tryProfile;
        if (profileGet(state, 2, &named) != 0 or !named.profile.eql(&profile) or
            preferenceGet(state, 3) != 2 or profileActive(state) != 2) return false;
        const grid = state.workspace.paneGrid(0) orelse return false;
        const history_limit = grid.history_limit;
        defer grid.setHistoryLimit(history_limit) catch {};
        var launch: LaunchProfile.Profile = .{};
        if (profileLaunch(state, 0, &launch) != 2 or !launch.eql(&profile) or grid.history_limit != 321) return false;
        if (profileLaunch(state, -1, &launch) != -1) return false;
        profile.shell.len = LaunchProfile.max_shell_bytes + 1;
        if (profileSave(state, 2, "Self-test", 9, &profile) != -1) return false;
        if (profileGet(state, 2, &named) != 0 or !named.profile.eql(&launch)) return false;
        var bytes: [WindowsLaunchProfiles.max_state_bytes]u8 = undefined;
        const encoded = state.profiles.encodeState(&bytes) catch return false;
        const loaded = WindowsLaunchProfiles.decodeState(bytes[0..encoded]) catch return false;
        if (loaded.selected != 2 or !loaded.get(2).?.profile.eql(&launch)) return false;
        return true;
    }
    return false;
}

fn selfTest(state: *State) bool {
    if (!firstAsciiTokenIs(
        std.unicode.utf8ToUtf16LeStringLiteral("--self-test"),
        "--self-test",
    )) return false;
    if (firstAsciiTokenIs(
        std.unicode.utf8ToUtf16LeStringLiteral("device--self-test-backup"),
        "--self-test",
    )) return false;
    if (!profileSelfTest(state)) return false;
    const grid = state.workspace.activeGrid() orelse return false;
    grid.feed("\x1b[2J\x1b[3;4H\x1b[1;38;2;143;184;255mWIN_OK") catch
        return false;
    const first = grid.cell(3, 2);
    const last = grid.cell(8, 2);
    if (first.codepoint != 'W' or last.codepoint != 'K') return false;
    if (!first.flags.bold) return false;
    if (grid.colorRgb(first.foreground) != 0x8fb8ff) return false;
    for ([_]Workspace.WindowsPreferences{ .{ .theme = .dark }, .{ .theme = .high_contrast }, .{ .theme = .paseo_black_zinc } }) |preferences| {
        state.preferences = preferences;
        state.themes.selected = @intFromEnum(preferences.theme);
        if (themeActive(state) != @intFromEnum(preferences.theme) or themeCount(state) != 3) return false;
        const defaults = WindowsAppearance.colors(@intFromEnum(preferences.theme));
        if (themeColor(state, 0) != defaults.foreground or themeColor(state, 1) != defaults.background)
            return false;
        var name: [128]u8 = undefined;
        const name_length = themeName(state, themeActive(state), &name, name.len);
        if (name_length < 0 or !std.mem.eql(u8, name[0..@intCast(name_length)], state.themes.selectedTheme().name))
            return false;
        if (colorRgb(state, first.foreground) != 0x8fb8ff or
            paneColorRgb(state, 0, first.foreground) != 0x8fb8ff or
            colorRgb(state, 202) != grid.colorRgb(202) or
            paneColorRgb(state, 0, 202) != grid.colorRgb(202))
            return false;
        const red = WindowsAppearance.indexedColor(@intFromEnum(preferences.theme), 1) orelse return false;
        if (colorRgb(state, 1) != red or paneColorRgb(state, 0, 1) != red)
            return false;
    }
    state.preferences = .{};
    state.themes.selected = 0;
    grid.feed("\r\nNOCTTY_WINDOWS_HOST_OK\r\n") catch return false;
    if (smokeReady(state) != 1) return false;

    const lower = state.workspace.splitActive(
        .vertical,
        false,
        columns_initial,
        rows_initial,
    ) catch return false;
    if (lower != 1 or state.workspace.activePaneIndex() != 1) return false;
    const upper_rect = state.workspace.paneRect(0) orelse return false;
    const lower_rect = state.workspace.paneRect(1) orelse return false;
    if (upper_rect.y != 0 or upper_rect.height != 500_000) return false;
    if (lower_rect.y != 500_000 or lower_rect.height != 500_000) return false;

    const lower_left = state.workspace.splitActive(
        .horizontal,
        true,
        columns_initial,
        rows_initial,
    ) catch return false;
    if (lower_left != 2 or state.workspace.activePaneIndex() != 2) return false;
    const left_rect = state.workspace.paneRect(2) orelse return false;
    const right_rect = state.workspace.paneRect(1) orelse return false;
    if (left_rect.x != 0 or left_rect.y != 500_000 or
        left_rect.width != 500_000 or left_rect.height != 500_000) return false;
    if (right_rect.x != 500_000 or right_rect.y != 500_000 or
        right_rect.width != 500_000 or right_rect.height != 500_000) return false;
    var divider_node: c_int = undefined;
    var divider_axis: c_int = undefined;
    var divider_x: u32 = undefined;
    var divider_y: u32 = undefined;
    var divider_width: u32 = undefined;
    var divider_height: u32 = undefined;
    var divider_ratio: u32 = undefined;
    if (dividerCount(state) != 2 or dividerInfo(
        state,
        1,
        &divider_node,
        &divider_axis,
        &divider_x,
        &divider_y,
        &divider_width,
        &divider_height,
        &divider_ratio,
    ) != 1) return false;
    if (divider_axis != 0 or divider_x != 0 or divider_y != 500_000 or
        divider_width != 1_000_000 or divider_height != 500_000 or divider_ratio != 500)
        return false;
    if (dividerSet(state, divider_node, 333) != 1 or
        dividerSet(state, divider_node, 333) != 0 or
        dividerAdjust(state, 0, 100) != 1 or
        dividerAdjust(state, 2, 100) != -1 or dividerSet(state, -1, 500) != -1)
        return false;
    if ((state.workspace.paneRect(2) orelse return false).width != 433_000 or
        state.workspace.activePaneIndex() != 2) return false;
    if (dividerReset(state) != 1 or dividerReset(state) != 0) return false;

    const input_grid = state.workspace.paneGrid(0) orelse return false;
    input_grid.feed(
        "\x1b[?1002h\x1b[?1006h\x1b[2J\x1b[HAe\u{301}  \r\n中Z  ",
    ) catch return false;
    if (paneMouseMode(state, 0) != 0x102) return false;
    var mouse_buffer: [64]u8 = undefined;
    const mouse_length = paneMouseEncode(
        state,
        0,
        1,
        1,
        0,
        2,
        4,
        &mouse_buffer,
        mouse_buffer.len,
    );
    if (mouse_length <= 0 or !std.mem.eql(
        u8,
        mouse_buffer[0..@intCast(mouse_length)],
        "\x1b[<48;2;2M",
    )) return false;
    if (paneMouseEncode(
        state,
        0,
        1,
        1,
        3,
        2,
        0,
        &mouse_buffer,
        mouse_buffer.len,
    ) != 0) return false;
    var copy_buffer: [64]u8 = undefined;
    const copied = paneCopy(
        state,
        0,
        &copy_buffer,
        copy_buffer.len,
        7,
        1,
        0,
        0,
    );
    if (copied <= 0 or !std.mem.eql(
        u8,
        copy_buffer[0..@intCast(copied)],
        "Ae\u{301}\n中Z",
    )) return false;

    const second_tab = state.workspace.newTab(
        columns_initial,
        rows_initial,
    ) catch return false;
    if (second_tab != 3 or state.workspace.tab_count != 2) return false;
    if (nextTab(state) != 1 or tabActive(state) != 0) return false;
    if (!state.workspace.nextPane() or state.workspace.activePaneIndex() != 0)
        return false;
    var title_buffer: [128]u8 = undefined;
    if (tabCount(state) != 2 or tabSelect(state, 0) != 0 or
        tabSelect(state, -1) != -1 or tabSelect(state, 2) != -1)
        return false;
    if (tabRename(state, 0, "build", 5) != 1 or
        tabRename(state, 0, "build", 5) != 0 or
        tabRename(state, 0, "bad\n", 4) != -1)
        return false;
    const title_length = tabTitle(state, 0, &title_buffer, title_buffer.len);
    if (title_length != 5 or !std.mem.eql(u8, title_buffer[0..5], "build"))
        return false;
    const selected_grid = state.workspace.activeGrid() orelse return false;
    if (tabMove(state, 0, 1) != 1 or tabActive(state) != 1 or
        state.workspace.activeGrid() != selected_grid or
        tabSelect(state, 0) != 1 or activePane(state) != 3 or
        tabSelect(state, 1) != 1 or activePane(state) != 0 or
        tabMove(state, 1, 0) != 1 or tabActive(state) != 0 or
        tabMove(state, 0, 0) != 0)
        return false;

    const snapshot_value = state.workspace.snapshot();
    var encoded: [persisted_state_capacity]u8 = undefined;
    const encoded_length = encodePersistedWindowsState(.{
        .preferences = .{
            .theme = .paseo_black_zinc,
            .font_size_pt = 32,
            .launch_profile = .command_prompt,
            .restore_workspace = true,
        },
        .workspace = snapshot_value,
    }, &encoded) catch return false;
    const decoded = decodePersistedWindowsState(encoded[0..encoded_length]) catch
        return false;
    if (decoded.preferences.theme != .paseo_black_zinc or
        decoded.preferences.font_size_pt != 32 or
        decoded.preferences.launch_profile != .command_prompt or
        !decoded.preferences.restore_workspace)
        return false;
    var restored = WindowsWorkspace.init(
        state.workspace.allocator,
        columns_initial,
        rows_initial,
    ) catch return false;
    defer restored.deinit();
    restored.restore(
        decoded.workspace orelse return false,
        columns_initial,
        rows_initial,
    ) catch return false;
    if (restored.tab_count != 2 or restored.paneTotal() != 4 or
        restored.active_tab != 0 or restored.activePaneIndex() != 0)
        return false;
    encoded[encoded_length - 1] ^= 1;
    if (decodePersistedWindowsState(encoded[0..encoded_length])) |_| {
        return false;
    } else |_| {}
    if (state.workspace.closeActivePane() != 0) return false;
    if (state.workspace.paneTotal() != 3 or
        state.workspace.activePaneIndex() != 2) return false;
    if (state.workspace.closeActiveTab() != 0b110) return false;
    return state.workspace.tab_count == 1 and
        state.workspace.paneTotal() == 1 and
        state.workspace.activePaneIndex() == 3;
}
