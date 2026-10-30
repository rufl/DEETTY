const std = @import("std");
const builtin = @import("builtin");

const PasteIsSafeFn = *const fn ([*]const u8, usize) callconv(.c) bool;

const Runtime = if (builtin.os.tag == .windows) struct {
    paste_is_safe: PasteIsSafeFn,

    fn open(paths: []const []const u8) ?@This() {
        _ = paths;
        return null;
    }
} else struct {
    lib: std.DynLib,
    paste_is_safe: PasteIsSafeFn,

    fn open(paths: []const []const u8) ?@This() {
        for (paths) |path| {
            var lib = std.DynLib.open(path) catch continue;
            const paste_is_safe = lib.lookup(
                PasteIsSafeFn,
                "ghostty_paste_is_safe",
            ) orelse {
                lib.close();
                continue;
            };
            return .{ .lib = lib, .paste_is_safe = paste_is_safe };
        }
        return null;
    }
};

var attempted = false;
var runtime: ?Runtime = null;

fn loaded() ?*const Runtime {
    if (!attempted) {
        attempted = true;
        runtime = Runtime.open(&.{ "libghostty-vt.so", "libghostty-vt.so.0" });
    }
    return if (runtime) |*value| value else null;
}

pub fn available() bool {
    return loaded() != null;
}

pub fn pasteIsSafe(bytes: []const u8) bool {
    const value = loaded() orelse return false;
    return value.paste_is_safe(bytes.ptr, bytes.len);
}

test "missing Ghostty VT library is rejected" {
    try std.testing.expect(Runtime.open(&.{"libnoctty-missing-ghostty-vt.so"}) == null);
}
