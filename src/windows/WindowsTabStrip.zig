//! Native common-control tab strip and bounded, system-styled rename dialog.
//! Child HWNDs belong to the host; cached labels avoid rebuilding controls on ticks.
const std = @import("std");
const Abi = @import("WindowsHostAbi.zig");
const c = Abi.c;
const Protocol = @import("dintty_share").protocol;

pub const control_id = 40301;
const edit_id = 40302;
const error_id = 40303;
const name_capacity = 128;
const drag_subclass_id = 1;
const reordered_message = c.WM_APP + 90;

const Drag = struct {
    source: c_int,
    pane: c_int,
    count: usize,
    identities: [Protocol.max_tabs]c_int = undefined,
    origin: c.POINT,
    threshold_x: c_int,
    threshold_y: c_int,
    active: bool = false,
    destination: c_int = -1,
    marker: c.RECT = std.mem.zeroes(c.RECT),
    brush: c.HBRUSH = null,
};

// Like NoctedHost, permit integer child IDs in CreateWindowExW's HMENU slot.
const CreateWindowExW = *const fn (
    c.DWORD,
    c.LPCWSTR,
    c.LPCWSTR,
    c.DWORD,
    c_int,
    c_int,
    c_int,
    c_int,
    c.HWND,
    ?*align(1) anyopaque,
    c.HINSTANCE,
    c.LPVOID,
) callconv(.winapi) c.HWND;
const createWindowExW: CreateWindowExW = @ptrCast(&c.CreateWindowExW);

pub const Strip = struct {
    window: c.HWND = null,
    count: usize = 0,
    height: c_int = 0,
    lengths: [Protocol.max_tabs]usize = @splat(0),
    labels: [Protocol.max_tabs][Protocol.max_title_bytes]u8 = undefined,
    callbacks: ?*const Abi.Callbacks = null,
    remote: bool = true,
    drag: ?Drag = null,

    pub fn create(self: *Strip, parent: c.HWND) bool {
        var controls = c.INITCOMMONCONTROLSEX{ .dwSize = @sizeOf(c.INITCOMMONCONTROLSEX), .dwICC = c.ICC_TAB_CLASSES };
        if (c.InitCommonControlsEx(&controls) == 0) return false;
        self.window = createWindowExW(0, wide("SysTabControl32"), wide("Workspace tabs"), c.WS_CHILD | c.WS_VISIBLE | c.WS_TABSTOP | c.WS_CLIPSIBLINGS | c.TCS_FOCUSONBUTTONDOWN, 0, 0, 0, 0, parent, @ptrFromInt(control_id), c.GetModuleHandleW(null), null);
        if (self.window == null) return false;
        if (c.SetWindowSubclass(self.window, stripProc, drag_subclass_id, @intFromPtr(self)) == 0) {
            _ = c.DestroyWindow(self.window);
            self.window = null;
            return false;
        }
        return true;
    }

    pub fn setFont(self: *Strip, font: c.HFONT, dpi: c.UINT, cell_height: c_int) void {
        if (self.window == null) return;
        self.cancelDrag();
        _ = c.SendMessageW(self.window, c.WM_SETFONT, @intFromPtr(font), 1);
        // Single-line tabs retain native overflow scrolling in narrow windows.
        self.height = @max(c.MulDiv(30, @intCast(dpi), 96), cell_height + c.MulDiv(12, @intCast(dpi), 96));
    }

    pub fn layout(self: *Strip, width: c_int, height: c_int) c_int {
        if (self.window == null) return 0;
        const inset = @min(self.height, @max(height, 0));
        _ = c.MoveWindow(self.window, 0, 0, @max(width, 0), inset, c.TRUE);
        return inset;
    }

    pub fn sync(self: *Strip, callbacks: *const Abi.Callbacks) bool {
        if (self.window == null) return false;
        const requested = callbacks.tab_count(callbacks.userdata);
        if (self.callbacks != callbacks) self.cancelDrag();
        self.callbacks = callbacks;
        if (self.drag != null and !self.dragValid()) self.cancelDrag();
        if (requested < 0 or requested > Protocol.max_tabs) return false;
        const count: usize = @intCast(requested);
        while (self.count > count) {
            if (c.SendMessageW(self.window, c.TCM_DELETEITEM, self.count - 1, 0) == 0) return false;
            self.count -= 1;
        }
        for (0..count) |index| {
            var bytes: [Protocol.max_title_bytes]u8 = undefined;
            const length = callbacks.tab_title(callbacks.userdata, @intCast(index), &bytes, bytes.len);
            if (length < 0 or length > bytes.len) return false;
            const len: usize = @intCast(length);
            const insert = index == self.count;
            if (!insert and self.lengths[index] == len and std.mem.eql(u8, self.labels[index][0..len], bytes[0..len])) continue;
            var text: [Protocol.max_title_bytes * 2 + 1]u16 = undefined;
            const wide_length = if (len == 0) 0 else c.MultiByteToWideChar(c.CP_UTF8, c.MB_ERR_INVALID_CHARS, @ptrCast(&bytes), length, &text, @intCast(text.len - 1));
            if (len != 0 and wide_length <= 0) return false;
            // Native tab text uses DrawText mnemonic syntax; titles are literal.
            var end: usize = @intCast(wide_length);
            for (text[0..end]) |unit| end += @intFromBool(unit == '&');
            text[end] = 0;
            var source: usize = @intCast(wide_length);
            while (source > 0) {
                source -= 1;
                const unit = text[source];
                end -= 1;
                text[end] = unit;
                if (unit == '&') {
                    end -= 1;
                    text[end] = unit;
                }
            }
            var item: c.TCITEMW = std.mem.zeroes(c.TCITEMW);
            item.mask = c.TCIF_TEXT;
            item.pszText = &text;
            const result = c.SendMessageW(self.window, if (insert) c.TCM_INSERTITEMW else c.TCM_SETITEMW, index, pointer(&item));
            if ((insert and result < 0) or (!insert and result == 0)) return false;
            if (insert) self.count += 1;
            @memcpy(self.labels[index][0..len], bytes[0..len]);
            self.lengths[index] = len;
        }
        const active = callbacks.tab_active(callbacks.userdata);
        if (active >= 0 and active < requested and self.selected() != active)
            _ = c.SendMessageW(self.window, c.TCM_SETCURSEL, @intCast(active), 0);
        return true;
    }

    pub fn selected(self: *const Strip) c_int {
        return @intCast(c.SendMessageW(self.window, c.TCM_GETCURSEL, 0, 0));
    }

    pub fn matches(self: *const Strip, callbacks: *const Abi.Callbacks) bool {
        if (c.SendMessageW(self.window, c.TCM_GETITEMCOUNT, 0, 0) != callbacks.tab_count(callbacks.userdata) or
            self.selected() != callbacks.tab_active(callbacks.userdata)) return false;
        for (0..self.count) |index| {
            var text: [Protocol.max_title_bytes * 2 + 1]u16 = undefined;
            var item: c.TCITEMW = std.mem.zeroes(c.TCITEMW);
            item.mask = c.TCIF_TEXT;
            item.pszText = &text;
            item.cchTextMax = text.len;
            if (c.SendMessageW(self.window, c.TCM_GETITEMW, index, pointer(&item)) == 0) return false;
            const text_length = std.mem.indexOfScalar(u16, &text, 0) orelse return false;
            var source: usize = 0;
            var decoded_length: usize = 0;
            while (source < text_length) : (source += 1) {
                const unit = text[source];
                if (unit == '&') {
                    source += 1;
                    if (source >= text_length or text[source] != '&') return false;
                }
                text[decoded_length] = unit;
                decoded_length += 1;
            }
            var bytes: [Protocol.max_title_bytes]u8 = undefined;
            const len = c.WideCharToMultiByte(c.CP_UTF8, c.WC_ERR_INVALID_CHARS, &text, @intCast(decoded_length), @ptrCast(&bytes), bytes.len, null, null);
            if (len < 0 or len != self.lengths[index] or !std.mem.eql(u8, bytes[0..@intCast(len)], self.labels[index][0..self.lengths[index]])) return false;
        }
        return true;
    }

    pub fn configureDrag(self: *Strip, callbacks: *const Abi.Callbacks, remote: bool) void {
        if (self.callbacks != callbacks or self.remote != remote) self.cancelDrag();
        self.callbacks = callbacks;
        self.remote = remote;
    }

    pub fn cancelDrag(self: *Strip) void {
        const drag = self.drag orelse return;
        // ReleaseCapture synchronously sends WM_CAPTURECHANGED. Clear all owned
        // state first; never refresh the host/model from that nested callback.
        self.drag = null;
        if (drag.brush != null) _ = c.DeleteObject(drag.brush);
        if (self.window != null) {
            _ = c.InvalidateRect(self.window, null, c.FALSE);
            if (c.GetCapture() == self.window) _ = c.ReleaseCapture();
        }
    }

    fn dragValid(self: *const Strip) bool {
        if (self.drag) |*drag| return self.snapshotValid(drag);
        return false;
    }

    fn snapshotValid(self: *const Strip, drag: *const Drag) bool {
        const cb = self.callbacks orelse return false;
        if (self.remote or cb.tab_count(cb.userdata) != drag.count or
            cb.tab_active(cb.userdata) != drag.source or cb.active_pane(cb.userdata) != drag.pane) return false;
        for (0..drag.count) |index| {
            if (cb.tab_identity(cb.userdata, @intCast(index)) != drag.identities[index]) return false;
            var bytes: [Protocol.max_title_bytes]u8 = undefined;
            const len = cb.tab_title(cb.userdata, @intCast(index), &bytes, bytes.len);
            if (len < 0 or len != self.lengths[index] or
                !std.mem.eql(u8, bytes[0..@intCast(len)], self.labels[index][0..self.lengths[index]])) return false;
        }
        return true;
    }

    fn beginDrag(self: *Strip, point: c.POINT) void {
        const cb = self.callbacks orelse return;
        if (self.remote or self.count < 2 or !self.sync(cb)) return;
        var hit = c.TCHITTESTINFO{ .pt = point, .flags = 0 };
        const index: c_int = @intCast(c.SendMessageW(self.window, c.TCM_HITTEST, 0, pointer(&hit)));
        if (index < 0 or index != cb.tab_active(cb.userdata)) return;
        const pane = cb.active_pane(cb.userdata);
        if (pane < 0) return;
        const dpi = windowDpi(self.window);
        var drag = Drag{
            .source = index,
            .pane = pane,
            .count = self.count,
            .origin = point,
            .threshold_x = @max(1, c.GetSystemMetricsForDpi(c.SM_CXDRAG, dpi)),
            .threshold_y = @max(1, c.GetSystemMetricsForDpi(c.SM_CYDRAG, dpi)),
        };
        for (0..self.count) |tab| {
            drag.identities[tab] = cb.tab_identity(cb.userdata, @intCast(tab));
            if (drag.identities[tab] < 0) return;
        }
        self.drag = drag;
        _ = c.SetCapture(self.window);
        if (c.GetCapture() != self.window) self.cancelDrag();
    }

    fn moveDrag(self: *Strip, point: c.POINT) void {
        if (!self.dragValid() or c.GetCapture() != self.window) {
            self.cancelDrag();
            return;
        }
        if (!self.drag.?.active) {
            const origin = self.drag.?.origin;
            if (@abs(point.x - origin.x) < self.drag.?.threshold_x and
                @abs(point.y - origin.y) < self.drag.?.threshold_y) return;
            self.drag.?.brush = c.CreateSolidBrush(c.GetSysColor(c.COLOR_HIGHLIGHT));
            if (self.drag.?.brush == null) {
                self.cancelDrag();
                return;
            }
            self.drag.?.active = true;
        }
        self.drag.?.destination = -1;
        var client: c.RECT = undefined;
        if (c.GetClientRect(self.window, &client) != 0 and
            point.x >= client.left and point.x < client.right and
            point.y >= client.top and point.y < client.bottom and
            c.ChildWindowFromPointEx(self.window, point, c.CWP_SKIPINVISIBLE | c.CWP_SKIPDISABLED) == self.window)
        {
            for (0..self.count) |index| {
                var rect: c.RECT = undefined;
                if (c.SendMessageW(self.window, c.TCM_GETITEMRECT, index, pointer(&rect)) == 0) break;
                if (rect.right <= client.left or rect.left >= client.right) continue;
                const after = point.x >= @divTrunc(rect.left + rect.right, 2);
                if (after and index + 1 != self.count and point.x >= rect.right) continue;
                const insertion: c_int = @as(c_int, @intCast(index)) + @intFromBool(after);
                self.drag.?.destination = insertion - @intFromBool(insertion > self.drag.?.source);
                const thickness = @max(2, c.MulDiv(3, @intCast(windowDpi(self.window)), 96));
                const edge = if (after) rect.right else rect.left;
                const x = std.math.clamp(edge - @divTrunc(thickness, 2), client.left, @max(client.left, client.right - thickness));
                self.drag.?.marker = .{
                    .left = x,
                    .right = @min(client.right, x + thickness),
                    .top = @max(client.top, rect.top),
                    .bottom = @min(client.bottom, rect.bottom),
                };
                break;
            }
        }
        _ = c.InvalidateRect(self.window, null, c.FALSE);
    }

    fn dropDrag(self: *Strip, point: c.POINT) void {
        self.moveDrag(point);
        const drag = self.drag orelse return;
        const cb = self.callbacks orelse return;
        const commit = drag.active and drag.destination >= 0 and
            drag.destination != drag.source and self.dragValid();
        self.cancelDrag();
        if (!commit or self.callbacks != cb or !self.snapshotValid(&drag)) return;
        const result = cb.tab_move(cb.userdata, drag.source, drag.destination);
        if (result > 0) {
            _ = c.SendMessageW(c.GetParent(self.window), reordered_message, 0, 0);
        } else if (result < 0) {
            _ = c.MessageBoxW(c.GetParent(self.window), wide("DINTTY could not move this tab."), wide("DINTTY Windows alpha"), c.MB_OK | c.MB_ICONERROR);
        }
    }
};

fn windowDpi(window: c.HWND) c.UINT {
    const dpi = c.GetDpiForWindow(window);
    return if (dpi == 0) 96 else dpi;
}

fn mousePoint(value: c.LPARAM) c.POINT {
    const bits: usize = @bitCast(value);
    return .{ .x = @as(i16, @bitCast(@as(u16, @truncate(bits)))), .y = @as(i16, @bitCast(@as(u16, @truncate(bits >> 16)))) };
}

fn stripProc(window: c.HWND, message: c.UINT, word: c.WPARAM, long_value: c.LPARAM, _: c.UINT_PTR, reference: c.DWORD_PTR) callconv(.winapi) c.LRESULT {
    const self: *Strip = @ptrFromInt(reference);
    switch (message) {
        c.WM_LBUTTONDOWN => {
            self.cancelDrag();
            // Let the common control notify the host and finish its synchronous
            // selection/layout before recording the authoritative drag source.
            const result = c.DefSubclassProc(window, message, word, long_value);
            self.beginDrag(mousePoint(long_value));
            return result;
        },
        c.WM_MOUSEMOVE => if (self.drag != null) {
            if (word & c.MK_LBUTTON == 0) self.cancelDrag() else self.moveDrag(mousePoint(long_value));
            return 0;
        },
        c.WM_LBUTTONUP => if (self.drag != null) {
            const active = self.drag.?.active;
            if (active) self.dropDrag(mousePoint(long_value)) else self.cancelDrag();
            if (active) return 0;
        },
        c.WM_KEYDOWN, c.WM_SYSKEYDOWN => if (self.drag != null) {
            self.cancelDrag();
            if (word == c.VK_ESCAPE) return 0;
        },
        c.WM_CAPTURECHANGED,
        c.WM_CANCELMODE,
        c.WM_SIZE,
        c.WM_KILLFOCUS,
        c.WM_SETFONT,
        c.WM_DPICHANGED,
        c.WM_CONTEXTMENU,
        c.TCM_DELETEITEM,
        c.TCM_DELETEALLITEMS,
        c.TCM_INSERTITEMW,
        c.TCM_SETITEMW,
        c.TCM_SETCURSEL,
        => self.cancelDrag(),
        c.WM_PAINT => {
            const result = c.DefSubclassProc(window, message, word, long_value);
            if (self.drag) |drag| {
                if (drag.active and drag.destination >= 0) {
                    const dc = c.GetDC(window);
                    if (dc != null) {
                        _ = c.FillRect(dc, &drag.marker, drag.brush);
                        _ = c.ReleaseDC(window, dc);
                    }
                }
            }
            return result;
        },
        c.WM_NCDESTROY => {
            self.cancelDrag();
            _ = c.RemoveWindowSubclass(window, stripProc, drag_subclass_id);
            self.window = null;
        },
        else => {},
    }
    return c.DefSubclassProc(window, message, word, long_value);
}

/// Requires a session-free local workspace with at least two tabs and room for
/// their headers. Uses real callbacks and the installed native subclass; restores
/// identity order, selection and the two effective titles before returning.
pub fn qualifyDrag(strip: *Strip, callbacks: *const Abi.Callbacks) bool {
    const count = callbacks.tab_count(callbacks.userdata);
    if (strip.window == null or count < 2 or count > Protocol.max_tabs) return false;
    const original_active = callbacks.tab_active(callbacks.userdata);
    const original_pane = callbacks.active_pane(callbacks.userdata);
    const pane_count = callbacks.pane_count(callbacks.userdata);
    const original_remote = strip.remote;
    var identities: [Protocol.max_tabs]c_int = undefined;
    for (0..@intCast(count)) |index| {
        identities[index] = callbacks.tab_identity(callbacks.userdata, @intCast(index));
        if (identities[index] < 0) return false;
    }
    var names: [2][Protocol.max_title_bytes]u8 = undefined;
    var lengths: [2]usize = undefined;
    for (0..2) |index| {
        const len = callbacks.tab_title(callbacks.userdata, @intCast(index), &names[index], names[index].len);
        if (len < 0 or len > names[index].len) return false;
        lengths[index] = @intCast(len);
    }
    defer {
        strip.cancelDrag();
        // Also repairs the fixture on a failed qualification, without sessions.
        for (0..@intCast(count)) |destination| {
            var source = destination;
            while (source < count) : (source += 1) {
                if (callbacks.tab_identity(callbacks.userdata, @intCast(source)) == identities[destination]) {
                    if (source != destination) _ = callbacks.tab_move(callbacks.userdata, @intCast(source), @intCast(destination));
                    break;
                }
            }
        }
        for (0..2) |index| _ = callbacks.tab_rename(callbacks.userdata, @intCast(index), &names[index], lengths[index]);
        _ = callbacks.tab_select(callbacks.userdata, original_active);
        strip.configureDrag(callbacks, original_remote);
        _ = strip.sync(callbacks);
    }
    strip.configureDrag(callbacks, false);
    for (0..2) |index| {
        if (callbacks.tab_rename(callbacks.userdata, @intCast(index), "Duplicate", 9) < 0) return false;
    }
    if (callbacks.tab_select(callbacks.userdata, 0) < 0 or !strip.sync(callbacks)) return false;
    const pane = callbacks.active_pane(callbacks.userdata);
    var first: c.RECT = undefined;
    var second: c.RECT = undefined;
    var client: c.RECT = undefined;
    if (c.GetClientRect(strip.window, &client) == 0 or
        c.SendMessageW(strip.window, c.TCM_GETITEMRECT, 0, pointer(&first)) == 0 or
        c.SendMessageW(strip.window, c.TCM_GETITEMRECT, 1, pointer(&second)) == 0 or
        first.left < 0 or second.right > client.right) return false;
    const down = packedPoint(@divTrunc(first.left + first.right, 2), first.top + 4);
    const right = packedPoint(second.right - 2, second.top + 4);
    const left = packedPoint(first.left + 2, first.top + 4);

    // Below threshold is a click, not a reorder.
    _ = c.SendMessageW(strip.window, c.WM_LBUTTONDOWN, c.MK_LBUTTON, down);
    if (strip.drag == null or strip.drag.?.active) return false;
    _ = c.SendMessageW(strip.window, c.WM_MOUSEMOVE, c.MK_LBUTTON, down);
    _ = c.SendMessageW(strip.window, c.WM_LBUTTONUP, 0, down);
    if (!dragIdle(strip) or !identityOrder(callbacks, identities[0..@intCast(count)])) return false;

    // Real capture loss, Escape, cancellation and resize all abandon the drop.
    inline for (.{ c.WM_KEYDOWN, c.WM_CANCELMODE, c.WM_SIZE, c.WM_CAPTURECHANGED }) |cancel_message| {
        if (!qualifyDragStart(strip, down, right)) return false;
        if (cancel_message == c.WM_CAPTURECHANGED) {
            _ = c.SetCapture(c.GetParent(strip.window));
            _ = c.ReleaseCapture();
        } else {
            _ = c.SendMessageW(strip.window, cancel_message, if (cancel_message == c.WM_KEYDOWN) c.VK_ESCAPE else 0, 0);
        }
        _ = c.SendMessageW(strip.window, c.WM_LBUTTONUP, 0, right);
        if (!dragIdle(strip) or !identityOrder(callbacks, identities[0..@intCast(count)])) return false;
    }
    // Dropping at the source boundary or outside the strip is a no-op.
    for ([_]c.LPARAM{ left, packedPoint(-10, -10) }) |target| {
        if (!qualifyDragStart(strip, down, right)) return false;
        _ = c.SendMessageW(strip.window, c.WM_MOUSEMOVE, c.MK_LBUTTON, target);
        _ = c.SendMessageW(strip.window, c.WM_LBUTTONUP, 0, target);
        if (!dragIdle(strip) or !identityOrder(callbacks, identities[0..@intCast(count)])) return false;
    }
    // A title/model sync and a mode change must cancel an in-flight gesture.
    if (!qualifyDragStart(strip, down, right) or callbacks.tab_rename(callbacks.userdata, 1, "Changed", 7) < 0 or
        !strip.sync(callbacks) or !dragIdle(strip)) return false;
    if (callbacks.tab_rename(callbacks.userdata, 1, "Duplicate", 9) < 0 or !strip.sync(callbacks)) return false;
    if (!qualifyDragStart(strip, down, right)) return false;
    strip.configureDrag(callbacks, true);
    if (!dragIdle(strip)) return false;
    _ = c.SendMessageW(strip.window, c.WM_LBUTTONDOWN, c.MK_LBUTTON, down);
    _ = c.SendMessageW(strip.window, c.WM_MOUSEMOVE, c.MK_LBUTTON, right);
    _ = c.SendMessageW(strip.window, c.WM_LBUTTONUP, 0, right);
    if (!dragIdle(strip) or callbacks.tab_active(callbacks.userdata) != 0 or
        !identityOrder(callbacks, identities[0..@intCast(count)])) return false;
    strip.configureDrag(callbacks, false);
    if (callbacks.tab_select(callbacks.userdata, 0) < 0 or !strip.sync(callbacks)) return false;

    // Duplicate labels cannot hide identity changes from a pending drop.
    if (!qualifyDragStart(strip, down, right) or callbacks.tab_move(callbacks.userdata, 0, 1) <= 0) return false;
    _ = c.SendMessageW(strip.window, c.WM_LBUTTONUP, 0, right);
    if (!dragIdle(strip) or callbacks.tab_identity(callbacks.userdata, 1) != identities[0] or
        callbacks.active_pane(callbacks.userdata) != pane) return false;
    if (callbacks.tab_move(callbacks.userdata, 1, 0) <= 0 or !strip.sync(callbacks)) return false;

    // Commit once through the subclass; the host's WM_APP+90 hook must sync.
    if (!qualifyDragStart(strip, down, right)) return false;
    _ = c.SendMessageW(strip.window, c.WM_LBUTTONUP, 0, right);
    _ = c.SendMessageW(strip.window, c.WM_LBUTTONUP, 0, right);
    if (!dragIdle(strip) or callbacks.tab_active(callbacks.userdata) != 1 or
        callbacks.tab_identity(callbacks.userdata, 1) != identities[0] or
        callbacks.tab_identity(callbacks.userdata, 0) != identities[1] or
        callbacks.active_pane(callbacks.userdata) != pane or !strip.matches(callbacks)) return false;
    if (!qualifyDragStart(strip, right, left)) return false;
    _ = c.SendMessageW(strip.window, c.WM_LBUTTONUP, 0, left);
    if (!dragIdle(strip) or !identityOrder(callbacks, identities[0..@intCast(count)]) or
        callbacks.active_pane(callbacks.userdata) != pane or callbacks.pane_count(callbacks.userdata) != pane_count or
        !strip.matches(callbacks)) return false;
    for (0..2) |index| {
        if (callbacks.tab_rename(callbacks.userdata, @intCast(index), &names[index], lengths[index]) < 0) return false;
    }
    if (callbacks.tab_select(callbacks.userdata, original_active) < 0 or !strip.sync(callbacks)) return false;
    return callbacks.active_pane(callbacks.userdata) == original_pane and strip.matches(callbacks);
}

fn packedPoint(x: c_int, y: c_int) c.LPARAM {
    return @intCast(@as(u32, @as(u16, @bitCast(@as(i16, @intCast(x))))) |
        (@as(u32, @as(u16, @bitCast(@as(i16, @intCast(y))))) << 16));
}

fn dragIdle(strip: *const Strip) bool {
    return strip.drag == null and c.GetCapture() != strip.window;
}

fn identityOrder(callbacks: *const Abi.Callbacks, identities: []const c_int) bool {
    if (callbacks.tab_count(callbacks.userdata) != identities.len) return false;
    for (identities, 0..) |identity, index| {
        if (callbacks.tab_identity(callbacks.userdata, @intCast(index)) != identity) return false;
    }
    return true;
}

fn qualifyDragStart(strip: *Strip, down: c.LPARAM, destination: c.LPARAM) bool {
    _ = c.SendMessageW(strip.window, c.WM_LBUTTONDOWN, c.MK_LBUTTON, down);
    _ = c.SendMessageW(strip.window, c.WM_MOUSEMOVE, c.MK_LBUTTON, destination);
    const drag = strip.drag orelse return false;
    return drag.active and drag.destination >= 0 and drag.brush != null and
        drag.marker.right > drag.marker.left and drag.marker.bottom > drag.marker.top and
        c.GetCapture() == strip.window;
}

const Rename = struct {
    callbacks: *const Abi.Callbacks,
    index: c_int,
    pane: c_int,
    initial: [name_capacity + 1]u16 = @splat(0),
    modal: bool = true,
    result: c_int = 0,
};

pub fn rename(parent: c.HWND, callbacks: *const Abi.Callbacks, remote: bool) c_int {
    if (remote) return -1;
    var state = renameState(callbacks) orelse return -1;
    var template = dialogTemplate();
    const result = c.DialogBoxIndirectParamW(c.GetModuleHandleW(null), @ptrCast(&template.words), parent, renameProc, pointer(&state));
    return if (result == -1) -1 else state.result;
}

fn renameState(callbacks: *const Abi.Callbacks) ?Rename {
    const index = callbacks.tab_active(callbacks.userdata);
    if (index < 0 or index >= callbacks.tab_count(callbacks.userdata)) return null;
    const pane = callbacks.active_pane(callbacks.userdata);
    if (pane < 0) return null;
    var state = Rename{ .callbacks = callbacks, .index = index, .pane = pane };
    // Automatic terminal titles can exceed the editable name bound. Leave those
    // blank instead of silently truncating a name into a different UTF-8 string.
    var bytes: [Protocol.max_title_bytes]u8 = undefined;
    const len = callbacks.tab_title(callbacks.userdata, index, &bytes, bytes.len);
    if (len > 0 and len <= name_capacity) {
        const count = c.MultiByteToWideChar(c.CP_UTF8, c.MB_ERR_INVALID_CHARS, @ptrCast(&bytes), len, &state.initial, name_capacity);
        if (count > 0) state.initial[@intCast(count)] = 0;
    }
    return state;
}

fn finishRename(window: c.HWND, state: *Rename) void {
    if (state.modal) _ = c.EndDialog(window, c.IDOK) else _ = c.DestroyWindow(window);
}

fn renameProc(window: c.HWND, message: c.UINT, word: c.WPARAM, long_value: c.LPARAM) callconv(.winapi) c.INT_PTR {
    if (message == c.WM_INITDIALOG) {
        const state: *Rename = @ptrFromInt(@as(usize, @bitCast(long_value)));
        _ = c.SetWindowLongPtrW(window, c.GWLP_USERDATA, long_value);
        const edit = c.GetDlgItem(window, edit_id);
        _ = c.SendMessageW(edit, c.EM_SETLIMITTEXT, name_capacity, 0);
        _ = c.SetWindowTextW(edit, &state.initial);
        _ = c.SendMessageW(edit, c.EM_SETSEL, 0, -1);
        _ = c.SetFocus(edit);
        return 0;
    }
    const raw = c.GetWindowLongPtrW(window, c.GWLP_USERDATA);
    if (raw == 0) return 0;
    const state: *Rename = @ptrFromInt(@as(usize, @bitCast(raw)));
    if (message == c.WM_CLOSE or (message == c.WM_COMMAND and (word & 0xffff) == c.IDCANCEL)) {
        state.result = 0;
        finishRename(window, state);
        return 1;
    }
    if (message == c.WM_COMMAND and (word & 0xffff) == c.IDOK) {
        if (state.callbacks.tab_active(state.callbacks.userdata) != state.index or
            state.callbacks.active_pane(state.callbacks.userdata) != state.pane)
        {
            _ = c.SetDlgItemTextW(window, error_id, wide("The active tab changed. Cancel and open Rename Tab again."));
            return 1;
        }
        if (c.GetWindowTextLengthW(c.GetDlgItem(window, edit_id)) > name_capacity) {
            _ = c.SetDlgItemTextW(window, error_id, wide("Use at most 128 UTF-8 bytes, without control characters."));
            _ = c.SetFocus(c.GetDlgItem(window, edit_id));
            return 1;
        }
        var text: [name_capacity + 1]u16 = undefined;
        const count = c.GetDlgItemTextW(window, edit_id, &text, text.len);
        var bytes: [name_capacity]u8 = undefined;
        const length = if (count == 0) 0 else c.WideCharToMultiByte(c.CP_UTF8, c.WC_ERR_INVALID_CHARS, &text, @intCast(count), @ptrCast(&bytes), bytes.len, null, null);
        var valid = count == 0 or length > 0;
        if (valid) for (bytes[0..@intCast(length)]) |byte| {
            if (byte < 0x20 or byte == 0x7f) valid = false;
        };
        if (!valid) {
            _ = c.SetDlgItemTextW(window, error_id, wide("Use at most 128 UTF-8 bytes, without control characters."));
            _ = c.SetFocus(c.GetDlgItem(window, edit_id));
            return 1;
        }
        const result = state.callbacks.tab_rename(state.callbacks.userdata, state.index, &bytes, @intCast(length));
        if (result < 0) {
            _ = c.SetDlgItemTextW(window, error_id, wide("The tab could not be renamed. Please try again."));
            return 1;
        }
        state.result = result;
        finishRename(window, state);
        return 1;
    }
    return 0;
}

// Standard DLGTEMPLATE/ITEMTEMPLATE serialization, word-sized fields with
// DWORD-aligned controls. Dialog manager supplies system colors and keyboard
// navigation (label mnemonic, Tab, Enter/default OK, Escape/Cancel).
const Template = struct {
    words: [512]u16 align(4) = @splat(0),
    used: usize = 0,
    fn word(self: *Template, value: u16) void {
        self.words[self.used] = value;
        self.used += 1;
    }
    fn dword(self: *Template, value: u32) void {
        self.word(@truncate(value));
        self.word(@truncate(value >> 16));
    }
    fn text(self: *Template, comptime value: []const u8) void {
        for (std.unicode.utf8ToUtf16LeStringLiteral(value)) |unit| self.word(unit);
        self.word(0);
    }
    fn control(self: *Template, style: u32, x: u16, y: u16, width: u16, height: u16, id: u16, class: u16, comptime title: []const u8) void {
        if (self.used % 2 != 0) self.word(0);
        self.dword(@as(u32, @intCast(c.WS_CHILD | c.WS_VISIBLE)) | style);
        self.dword(0);
        self.word(x);
        self.word(y);
        self.word(width);
        self.word(height);
        self.word(id);
        self.word(0xffff);
        self.word(class);
        self.text(title);
        self.word(0);
    }
};

fn dialogTemplate() Template {
    var result: Template = .{};
    result.dword(c.WS_POPUP | c.WS_CAPTION | c.WS_SYSMENU | c.DS_MODALFRAME | c.DS_SETFONT | c.DS_CENTER);
    result.dword(0);
    result.word(6);
    result.word(0);
    result.word(0);
    result.word(270);
    result.word(116);
    result.word(0);
    result.word(0);
    result.text("Rename Tab");
    result.word(9);
    result.text("Segoe UI");
    result.control(0, 10, 9, 250, 10, 0xffff, 0x82, "Tab &name:");
    result.control(c.WS_TABSTOP | c.WS_BORDER | c.ES_AUTOHSCROLL, 10, 22, 250, 15, edit_id, 0x81, "");
    result.control(0, 10, 43, 250, 20, 0xffff, 0x82, "Blank resets the automatic title. Maximum 128 UTF-8 bytes.");
    result.control(0, 10, 66, 250, 20, error_id, 0x82, "");
    result.control(c.WS_TABSTOP | c.BS_DEFPUSHBUTTON, 148, 92, 52, 16, c.IDOK, 0x80, "OK");
    result.control(c.WS_TABSTOP | c.BS_PUSHBUTTON, 208, 92, 52, 16, c.IDCANCEL, 0x80, "Cancel");
    return result;
}

/// Exercises the same dialog procedure and callback as the modal UI, without
/// showing a desktop surface or entering an unbounded interactive dialog loop.
pub fn qualifyRename(parent: c.HWND, callbacks: *const Abi.Callbacks) bool {
    var template = dialogTemplate();
    var state = renameState(callbacks) orelse return false;
    state.modal = false;
    var dialog = c.CreateDialogIndirectParamW(c.GetModuleHandleW(null), @ptrCast(&template.words), parent, renameProc, pointer(&state)) orelse return false;
    defer {
        if (c.IsWindow(dialog) != 0) _ = c.DestroyWindow(dialog);
    }
    if (c.IsWindowVisible(dialog) != 0 or c.GetDlgItem(dialog, edit_id) == null or c.GetDlgItem(dialog, c.IDOK) == null or c.GetDlgItem(dialog, c.IDCANCEL) == null) return false;
    // The native edit accepts UTF-16; byte-bound validation must reject 129 bytes.
    var overlong: [44]u16 = @splat(0x4e2d);
    overlong[43] = 0;
    _ = c.SetDlgItemTextW(dialog, edit_id, &overlong);
    _ = c.SendMessageW(dialog, c.WM_COMMAND, c.IDOK, 0);
    if (c.IsWindow(dialog) == 0 or state.result != 0) return false;
    var oversized: [name_capacity + 2]u16 = @splat('X');
    oversized[oversized.len - 1] = 0;
    _ = c.SetDlgItemTextW(dialog, edit_id, &oversized);
    _ = c.SendMessageW(dialog, c.WM_COMMAND, c.IDOK, 0);
    if (c.IsWindow(dialog) == 0 or state.result != 0) return false;
    _ = c.SetDlgItemTextW(dialog, edit_id, wide("Native & 中"));
    _ = c.SendMessageW(dialog, c.WM_COMMAND, c.IDOK, 0);
    if (c.IsWindow(dialog) != 0 or state.result <= 0 or !titleMatches(callbacks, state.index, "Native & 中")) return false;
    state = renameState(callbacks) orelse return false;
    state.modal = false;
    dialog = c.CreateDialogIndirectParamW(c.GetModuleHandleW(null), @ptrCast(&template.words), parent, renameProc, pointer(&state)) orelse return false;
    _ = c.SetDlgItemTextW(dialog, edit_id, wide("Cancelled"));
    _ = c.SendMessageW(dialog, c.WM_COMMAND, c.IDCANCEL, 0);
    return c.IsWindow(dialog) == 0 and state.result == 0 and titleMatches(callbacks, state.index, "Native & 中");
}

pub fn titleMatches(callbacks: *const Abi.Callbacks, index: c_int, expected: []const u8) bool {
    var bytes: [Protocol.max_title_bytes]u8 = undefined;
    const len = callbacks.tab_title(callbacks.userdata, index, &bytes, bytes.len);
    return len >= 0 and len == expected.len and std.mem.eql(u8, bytes[0..@intCast(len)], expected);
}

pub fn pointer(value: anytype) c.LPARAM {
    return @bitCast(@intFromPtr(value));
}
fn wide(comptime text: []const u8) [*:0]const u16 {
    return std.unicode.utf8ToUtf16LeStringLiteral(text);
}
