const std = @import("std");

pub const Input = struct {
    pane_id: u64,
    process_id: i32,
    cwd: []const u8,
    process_name: []const u8,
};

pub const Output = struct {
    display_length: usize,
    tooltip_length: usize,
};

pub fn format(input: Input, display: []u8, tooltip: []u8) !Output {
    const cwd = safeText(input.cwd, "?");
    const process_name = safeText(input.process_name, "shell");
    const short_cwd = shortDirectory(cwd);
    const display_text = try std.fmt.bufPrint(
        display,
        "{s} : {s}",
        .{ short_cwd, process_name },
    );
    const tooltip_text = try std.fmt.bufPrint(
        tooltip,
        "Pane {d}\nProcess: {s} (PID {d})\nDirectory: {s}",
        .{ input.pane_id, process_name, input.process_id, cwd },
    );
    return .{
        .display_length = display_text.len,
        .tooltip_length = tooltip_text.len,
    };
}

fn safeText(text: []const u8, fallback: []const u8) []const u8 {
    if (text.len == 0 or !std.unicode.utf8ValidateSlice(text)) return fallback;
    for (text) |byte| {
        if (byte < 0x20 or byte == 0x7f) return fallback;
    }
    return text;
}

fn shortDirectory(cwd: []const u8) []const u8 {
    if (std.mem.eql(u8, cwd, "/")) return cwd;
    const trimmed = std.mem.trimEnd(u8, cwd, "/");
    if (trimmed.len == 0) return "/";
    return std.fs.path.basename(trimmed);
}

test "pane info matches the local Yakuake title shape" {
    var display: [128]u8 = undefined;
    var tooltip: [256]u8 = undefined;
    const output = try format(.{
        .pane_id = 7,
        .process_id = 420,
        .cwd = "/home/alice/project",
        .process_name = "zig",
    }, &display, &tooltip);

    try std.testing.expectEqualStrings(
        "project : zig",
        display[0..output.display_length],
    );
    try std.testing.expectEqualStrings(
        "Pane 7\nProcess: zig (PID 420)\nDirectory: /home/alice/project",
        tooltip[0..output.tooltip_length],
    );
}

test "pane info handles root and rejects unsafe process metadata" {
    var display: [128]u8 = undefined;
    var tooltip: [256]u8 = undefined;
    const output = try format(.{
        .pane_id = 1,
        .process_id = 9,
        .cwd = "/",
        .process_name = "bad\nname",
    }, &display, &tooltip);

    try std.testing.expectEqualStrings("/ : shell", display[0..output.display_length]);
    try std.testing.expect(std.mem.indexOf(
        u8,
        tooltip[0..output.tooltip_length],
        "Process: shell (PID 9)",
    ) != null);
}

test "pane info stays within caller-owned buffers" {
    var display: [4]u8 = undefined;
    var tooltip: [8]u8 = undefined;
    try std.testing.expectError(error.NoSpaceLeft, format(.{
        .pane_id = 1,
        .process_id = 2,
        .cwd = "/tmp",
        .process_name = "sh",
    }, &display, &tooltip));
}
