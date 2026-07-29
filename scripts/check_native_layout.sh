#!/usr/bin/env sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd -P)
cd "$repo_root"

grid=src/gui/native_grid_host.c
grid_abi=src/gui/native_grid_abi.h
grid_abi_zig=src/gui/NativeGridAbi.zig
native_gtk=src/gui/NativeGtk.zig
main=src/main.zig
pty=src/terminal/Pty.zig
vt=src/terminal/Vt.zig
nocted=src/nocted/main.zig

for path in "$grid" "$grid_abi" "$grid_abi_zig" "$native_gtk" "$main" "$pty" "$vt" "$nocted"; do
  test -s "$path"
done

test "$(find src -type f -name '*.c' | wc -l | tr -d ' ')" -eq 1
test ! -e src/editor

grep -F '#define NOCTTY_NATIVE_GRID_ABI_VERSION 2u' "$grid_abi" >/dev/null
grep -F 'pub const version: u32 = 2;' "$grid_abi_zig" >/dev/null
grep -F 'pub const Paste = *const fn (?*anyopaque, [*]const u8, usize)' "$grid_abi_zig" >/dev/null
grep -F 'test "paste callback accepts length-delimited bytes"' "$grid_abi_zig" >/dev/null
grep -F 'pub const NativeGridAbi = @import("NativeGridAbi.zig");' src/gui/root.zig >/dev/null
grep -F 'const NativeGridAbi = noctty.gui.NativeGridAbi;' "$main" >/dev/null

grep -F 'const NativeGridRunOptions = struct {' "$main" >/dev/null
grep -F 'fn runNativeGridHost(options: NativeGridRunOptions) c_int {' "$main" >/dev/null
! grep -F 'fn noctty_native_grid_host_run(' "$main" >/dev/null

grep -F 'pub export fn noctty_settings_page_new' "$native_gtk" >/dev/null
grep -F 'pub export fn noctty_settings_grid_attach_control' "$native_gtk" >/dev/null
grep -F 'gtk_label_set_mnemonic_widget(@ptrCast(label), control_widget);' "$native_gtk" >/dev/null
! grep -F 'static GtkWidget *settings_page_new' "$grid" >/dev/null
! grep -F 'static void settings_grid_attach_control' "$grid" >/dev/null
grep -F 'save failed; keep this window open' "$grid" >/dev/null
grep -F 'if (save_quick_note(root)) gtk_widget_destroy' "$grid" >/dev/null
grep -F 'Could not save terminal scrollback' "$grid" >/dev/null

grep -F 'typedef int (*NocttyGridRow)(void *, int, uint64_t *, size_t);' "$grid_abi" >/dev/null
grep -F 'int dirty_count = context->dirty_spans(' "$grid" >/dev/null
grep -F 'static int draw_ascii_run(' "$grid" >/dev/null
grep -F 'gtk_widget_add_tick_callback(' "$grid" >/dev/null
grep -F 'g_unix_fd_add_full(' "$grid" >/dev/null
! grep -F '*created = *source;' "$grid" >/dev/null

grep -F 'const child_pid = std.c.fork();' "$pty" >/dev/null
grep -F 'childCloseInheritedDescriptors();' "$pty" >/dev/null
grep -F '_ = execve(options.program.ptr' "$pty" >/dev/null
grep -F 'pub fn packedRow(self: Grid, row: usize, output: []u64) usize {' "$vt" >/dev/null

grep -F 'setAccessibleName(self.notebook, "Open files");' "$nocted" >/dev/null
grep -F 'setAccessibleName(self.tree, "Project files");' "$nocted" >/dev/null
grep -F 'setAccessibleName(self.project_search_tree, "Project search results");' "$nocted" >/dev/null
grep -F 'setAccessibleName(self.quick_open_tree, "Quick Open results");' "$nocted" >/dev/null

grep -F '"-Wconversion"' build.zig >/dev/null
grep -F '"-Wshadow"' build.zig >/dev/null
grep -F '"-Werror"' build.zig >/dev/null

echo 'native_layout gtk_host_c=true zig_state=true named_launch_options=true abi_v2=true length_delimited_paste=true settings_zig=true settings_accessible=true save_errors_visible=true packed_rows=true dirty_spans=true frame_clock=true pty_event_source=true inherited_fds_closed=true nocted_accessible=true strict_c_warnings=true embedded_editor=false'
