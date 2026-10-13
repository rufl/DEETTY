//! Bounded UTF-8 window-title conversion for the Win32 terminal host.

const c = @import("c");

const title_utf8_max: usize = 512;
const title_utf16_max: usize = 640;

pub export fn noctty_windows_update_title(
    window: c.HWND,
    title: ?[*]const u8,
    title_length: usize,
    process_exited: c_int,
) c_int {
    if (window == null or title_length > title_utf8_max) return 0;
    if (title_length == 0) {
        const value = if (process_exited != 0)
            wide("NOCTTY Windows alpha — exited")
        else
            wide("NOCTTY Windows alpha");
        return @intFromBool(c.SetWindowTextW(window, value) != 0);
    }
    const source = title orelse return 0;
    if (title_length > @as(usize, @intCast(std.math.maxInt(c_int)))) return 0;
    var output: [title_utf16_max]u16 = undefined;
    const converted = c.MultiByteToWideChar(
        c.CP_UTF8,
        c.MB_ERR_INVALID_CHARS,
        source,
        @intCast(title_length),
        &output,
        title_utf16_max - 1,
    );
    if (converted <= 0) return 0;
    const suffix = wide(" — NOCTTY Windows alpha");
    const suffix_length = std.mem.len(suffix);
    const converted_length: usize = @intCast(converted);
    if (converted_length + suffix_length + 1 > output.len) return 0;
    @memcpy(output[converted_length..][0..suffix_length], suffix[0..suffix_length]);
    output[converted_length + suffix_length] = 0;
    return @intFromBool(c.SetWindowTextW(window, &output) != 0);
}

const std = @import("std");

fn wide(comptime text: []const u8) [*:0]const u16 {
    return @ptrCast(std.unicode.utf8ToUtf16LeStringLiteral(text));
}
