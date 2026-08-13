const std = @import("std");
const windows = std.os.windows;
const Share = @import("noctty_share");
const Vt = Share.vt;
const Crypto = Share.crypto;
const Release = @import("noctty_release");

const host_abi_version: u32 = 4;
const columns_initial: usize = 120;
const rows_initial: usize = 36;

const State = struct {
    grid: Vt.Grid,
    store: Share.identity.Store,
    live_host: ?*Share.live_host.LiveHost = null,
    live_viewer: ?*Share.live_viewer.LiveViewer = null,
};

const Feed = *const fn (?*anyopaque, [*]const u8, usize) callconv(.c) c_int;
const Write = *const fn (?*anyopaque, [*]const u8, usize) callconv(.c) c_int;
const TakeReply = *const fn (?*anyopaque, [*]u8, usize) callconv(.c) c_int;
const TakeRemote = *const fn (?*anyopaque, [*]u8, usize) callconv(.c) c_int;
const Cell = *const fn (?*anyopaque, c_int, c_int) callconv(.c) u64;
const CellText = *const fn (
    ?*anyopaque,
    c_int,
    c_int,
    [*]u8,
    usize,
) callconv(.c) c_int;
const ColorRgb = *const fn (?*anyopaque, u32) callconv(.c) u32;
const Cursor = *const fn (?*anyopaque) callconv(.c) u32;
const Title = *const fn (?*anyopaque, [*]u8, usize) callconv(.c) c_int;
const Resize = *const fn (?*anyopaque, c_int, c_int) callconv(.c) c_int;
const Scroll = *const fn (?*anyopaque, c_int) callconv(.c) c_int;
const CursorMode = *const fn (?*anyopaque) callconv(.c) c_int;
const SmokeReady = *const fn (?*anyopaque) callconv(.c) c_int;
const Start = *const fn (?*anyopaque) callconv(.c) c_int;
const Stop = *const fn (?*anyopaque) callconv(.c) c_int;

const NextStream = *const fn (?*anyopaque) callconv(.c) c_int;
const Callbacks = extern struct {
    abi_version: u32 = host_abi_version,
    struct_size: u32 = @sizeOf(Callbacks),
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
    smoke_ready: SmokeReady,
    start: Start,
    stop: Stop,
    next_stream: NextStream,
};

extern fn noctty_windows_host_run(
    instance: windows.HINSTANCE,
    show_command: c_int,
    callbacks: *const Callbacks,
) c_int;
extern fn noctty_windows_identity_load([*]u8, usize) c_int;
extern fn noctty_windows_identity_save([*]const u8, usize) c_int;
extern fn noctty_windows_random([*]u8, usize) c_int;
extern fn noctty_windows_pairs_load([*]u8, usize, *usize) c_int;
extern fn noctty_windows_pairs_save([*]const u8, usize) c_int;
extern "user32" fn MessageBoxW(
    ?windows.HWND,
    [*:0]const u16,
    [*:0]const u16,
    windows.UINT,
) callconv(.winapi) c_int;
extern fn noctty_windows_show_version(
    instance: windows.HINSTANCE,
    version: [*:0]const u16,
) void;

pub export fn wWinMain(
    instance: windows.HINSTANCE,
    previous_instance: ?windows.HINSTANCE,
    command_line: [*:0]u16,
    show_command: c_int,
) callconv(.c) c_int {
    _ = previous_instance;

    const command = std.mem.span(command_line);
    if (wideContainsAscii(command, "--version")) {
        const version_text = std.unicode.utf8ToUtf16LeStringLiteral(
            "NOCTTY " ++ Release.version ++ " Windows alpha",
        );
        noctty_windows_show_version(instance, version_text);
        return 0;
    }

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
        .grid = Vt.Grid.init(
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
        state.grid.deinit();
        state.store.deinit();
    }

    if (wideContainsAscii(command, "--self-test")) {
        return if (selfTest(&state)) 0 else 1;
    }
    if (mode.kind == .share) {
        if (mode.index >= state.store.peer_count or mode.port == 0) return 1;
        state.live_host = Share.live_host.LiveHost.create(
            std.heap.page_allocator,
            random,
            state.store.identity,
            state.store.peerSliceConst()[mode.index],
            null,
            mode.port,
            &.{.{ .pane_id = 1, .title = "ConPTY" }},
        ) catch return 1;
    } else if (mode.kind == .receive) {
        if (mode.index >= state.store.peer_count) return 1;
        state.live_viewer = Share.live_viewer.LiveViewer.create(
            std.heap.page_allocator,
            random,
            state.store.identity,
            state.store.peerSliceConst()[mode.index],
        ) catch return 1;
    }

    const callbacks = Callbacks{
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
    };
    return noctty_windows_host_run(instance, show_command, &callbacks);
}

fn loadOrCreateIdentity() !Crypto.Identity {
    var secret: [Crypto.secret_key_length]u8 = undefined;
    defer std.crypto.secureZero(u8, &secret);
    switch (noctty_windows_identity_load(&secret, secret.len)) {
        1 => return Crypto.Identity.fromSecret(secret),
        0 => {
            if (noctty_windows_random(&secret, secret.len) != 0)
                return error.WindowsRandomFailed;
            const identity = try Crypto.Identity.fromSecret(secret);
            if (noctty_windows_identity_save(&identity.secret_key, identity.secret_key.len) != 0)
                return error.WindowsIdentitySaveFailed;
            return identity;
        },
        else => return error.WindowsIdentityLoadFailed,
    }
}

fn loadOrCreateStore() !Share.identity.Store {
    var bytes: [Share.identity.max_file_bytes]u8 = undefined;
    defer std.crypto.secureZero(u8, &bytes);
    var length: usize = 0;
    switch (noctty_windows_pairs_load(&bytes, bytes.len, &length)) {
        1 => return Share.identity.import(bytes[0..length]),
        0 => return Share.identity.Store.init(try loadOrCreateIdentity()),
        else => return error.WindowsPeerStoreLoadFailed,
    }
}

fn saveStore(store: *const Share.identity.Store) !void {
    const bytes = try Share.identity.exportAlloc(std.heap.page_allocator, store);
    defer {
        std.crypto.secureZero(u8, bytes);
        std.heap.page_allocator.free(bytes);
    }
    if (noctty_windows_pairs_save(bytes.ptr, bytes.len) != 0)
        return error.WindowsPeerStoreSaveFailed;
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
    store.addOrUpdate(peer) catch return 1;
    saveStore(store) catch return 1;
    showWindowsMessage("Paired device saved. Use --share 0 PORT or --receive 0.");
    return 0;
}

fn confirmWindowsControl() bool {
    return MessageBoxW(
        null,
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
    if (length > 2 * 1024 * 1024) return -1;
    state.grid.feed(bytes[0..length]) catch return -1;
    if (state.live_host) |host| host.capture(1, state) catch return -1;
    return std.math.cast(c_int, length) orelse -1;
}

fn takeReply(raw: ?*anyopaque, output: [*]u8, capacity: usize) callconv(.c) c_int {
    const state = stateFromRaw(raw) orelse return -1;
    if (state.live_viewer != null) return 0;
    if (capacity == 0) return 0;
    const pending = state.grid.pendingReplies();
    const count = @min(pending.len, capacity);
    @memcpy(output[0..count], pending[0..count]);
    state.grid.consumeReplies(count);
    return std.math.cast(c_int, count) orelse -1;
}

fn takeRemote(raw: ?*anyopaque, output: [*]u8, capacity: usize) callconv(.c) c_int {
    const state = stateFromRaw(raw) orelse return -1;
    const host = state.live_host orelse return 0;
    host.capture(1, state) catch return -1;
    if (host.currentStatus() == .control_requested) {
        if (confirmWindowsControl())
            host.grantControl()
        else
            host.revokeControl();
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
    return state.grid.packedCell(@intCast(column), @intCast(row));
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
    const count = state.grid.cellText(
        @intCast(column),
        @intCast(row),
        output[0..capacity],
    );
    return std.math.cast(c_int, count) orelse -1;
}

fn colorRgb(raw: ?*anyopaque, color_id: u32) callconv(.c) u32 {
    const state = stateFromRaw(raw) orelse return 0xffffffff;
    if (color_id > std.math.maxInt(u16)) return 0xffffffff;
    if (state.live_viewer) |viewer| return viewer.colorRgb(@intCast(color_id));
    return state.grid.colorRgb(@intCast(color_id));
}

fn cursor(raw: ?*anyopaque) callconv(.c) u32 {
    const state = stateFromRaw(raw) orelse return 0xffffffff;
    if (state.live_viewer) |viewer| return viewer.cursor();
    if (!state.grid.cursor_visible) return 0xffffffff;
    if (state.grid.cursor_row > std.math.maxInt(u16)) return 0xffffffff;
    if (state.grid.cursor_column > std.math.maxInt(u16)) return 0xffffffff;
    return (@as(u32, @intCast(state.grid.cursor_row)) << 16) |
        @as(u32, @intCast(state.grid.cursor_column));
}

fn title(raw: ?*anyopaque, output: [*]u8, capacity: usize) callconv(.c) c_int {
    const state = stateFromRaw(raw) orelse return -1;
    if (state.live_viewer) |viewer|
        return std.math.cast(c_int, viewer.title(output[0..capacity])) orelse -1;
    const value = state.grid.titleSlice();
    const count = @min(value.len, capacity);
    @memcpy(output[0..count], value[0..count]);
    return std.math.cast(c_int, count) orelse -1;
}

fn resize(raw: ?*anyopaque, columns: c_int, rows: c_int) callconv(.c) c_int {
    const state = stateFromRaw(raw) orelse return -1;
    if (state.live_viewer != null) return 0;
    if (columns < 1 or rows < 1) return -1;
    if (columns > 1000 or rows > 500) return -1;
    state.grid.resize(@intCast(columns), @intCast(rows)) catch return -1;
    return 0;
}

fn scroll(raw: ?*anyopaque, lines: c_int) callconv(.c) c_int {
    const state = stateFromRaw(raw) orelse return -1;
    if (state.live_viewer != null) return 0;
    state.grid.scrollViewport(lines);
    return 0;
}

fn cursorMode(raw: ?*anyopaque) callconv(.c) c_int {
    const state = stateFromRaw(raw) orelse return 0;
    if (state.live_viewer) |viewer|
        return @intFromBool(viewer.applicationCursorKeys());
    return @intFromBool(state.grid.application_cursor_keys);
}

fn nextStream(raw: ?*anyopaque) callconv(.c) c_int {
    const state = stateFromRaw(raw) orelse return -1;
    const viewer = state.live_viewer orelse return 0;
    const count = viewer.streamCount();
    if (count < 2) return 0;
    const next = (viewer.selectedIndex() + 1) % count;
    viewer.selectStream(next) catch return -1;
    return std.math.cast(c_int, next + 1) orelse -1;
}

fn smokeReady(raw: ?*anyopaque) callconv(.c) c_int {
    const state = stateFromRaw(raw) orelse return 0;
    const marker = state.grid.findText(
        "NOCTTY_WINDOWS_HOST_OK",
        false,
        0,
    );
    return @intFromBool(marker != null);
}

fn wideContainsAscii(haystack: []const u16, needle: []const u8) bool {
    if (needle.len == 0 or haystack.len < needle.len) return false;
    for (0..haystack.len - needle.len + 1) |start| {
        var matches = true;
        for (needle, 0..) |byte, index| {
            if (haystack[start + index] != byte) {
                matches = false;
                break;
            }
        }
        if (matches) return true;
    }
    return false;
}

fn selfTest(state: *State) bool {
    state.grid.feed("\x1b[2J\x1b[3;4H\x1b[1;38;2;143;184;255mWIN_OK") catch
        return false;
    const first = state.grid.cell(3, 2);
    const last = state.grid.cell(8, 2);
    if (first.codepoint != 'W') return false;
    if (last.codepoint != 'K') return false;
    if (!first.flags.bold) return false;
    if (state.grid.colorRgb(first.foreground) != 0x8fb8ff) return false;
    state.grid.feed("\r\nNOCTTY_WINDOWS_HOST_OK\r\n") catch return false;
    return smokeReady(state) == 1;
}
