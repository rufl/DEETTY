//! PTY plus VT-grid session ownership and nonblocking input/output buffering.
//!
//! `TerminalSession` owns its PTY, grid, scratch storage, and pending writes.
//! Native hosts may schedule pumps but must close through this type so process
//! groups, descriptors, allocator state, and history storage are released once.

const std = @import("std");
const Compat = @import("compat");
const Pty = @import("Pty.zig");
const Vt = @import("Vt.zig");
const LaunchProfile = @import("LaunchProfile.zig");

pub const TerminalSession = struct {
    // Bound each main-loop dispatch while amortizing PTY readiness and redraw scheduling.
    const max_pump_bytes = 2 * 1024 * 1024;
    const output_buffer_bytes = 128 * 1024;
    // Queue blocked PTY input instead of sleeping on the native UI thread.
    pub const max_pending_write_bytes = 64 * 1024 * 1024;
    const retained_write_capacity = 256 * 1024;
    // Libc keeps hot-history growth cheap and lets native idle compaction trim pages.
    const history_allocator = std.heap.c_allocator;

    pub const PumpScratch = struct {
        bytes: [output_buffer_bytes]u8 = undefined,
        in_use: bool = false,
    };

    allocator: std.mem.Allocator,
    pty: Pty.Session,
    grid: Vt.Grid,
    pump_scratch: *PumpScratch,
    pump_scratch_owned: bool,
    pending_write: std.array_list.Managed(u8),
    pending_write_start: usize = 0,
    // Lazily caches packed visible rows; resize, damage, and viewport tokens invalidate it.
    frame_cache_cells: ?[]u64 = null,
    frame_cache_row_generations: ?[]u64 = null,
    frame_cache_row_valid: ?[]bool = null,
    frame_cache_columns: usize = 0,
    frame_cache_rows: usize = 0,
    frame_cache_viewport_offset: usize = std.math.maxInt(usize),
    frame_cache_history_count: usize = std.math.maxInt(usize),
    frame_cache_damage_generation: u64 = 0,
    deinitialized: bool = false,

    pub fn spawn(allocator: std.mem.Allocator, cwd: [:0]const u8, shell: [:0]const u8, columns: u16, rows: u16) !TerminalSession {
        return spawnWithHistoryLimit(
            allocator,
            cwd,
            shell,
            columns,
            rows,
            LaunchProfile.default_scrollback_lines,
        );
    }

    pub fn spawnWithHistoryLimit(
        allocator: std.mem.Allocator,
        cwd: [:0]const u8,
        shell: [:0]const u8,
        columns: u16,
        rows: u16,
        history_limit: usize,
    ) !TerminalSession {
        const pump_scratch = try allocator.create(PumpScratch);
        errdefer allocator.destroy(pump_scratch);
        pump_scratch.* = .{};
        var session = try spawnWithHistoryLimitAndScratch(
            allocator,
            cwd,
            shell,
            columns,
            rows,
            history_limit,
            pump_scratch,
        );
        session.pump_scratch_owned = true;
        return session;
    }

    pub fn spawnWithHistoryLimitAndScratch(
        allocator: std.mem.Allocator,
        cwd: [:0]const u8,
        shell: [:0]const u8,
        columns: u16,
        rows: u16,
        history_limit: usize,
        pump_scratch: *PumpScratch,
    ) !TerminalSession {
        var pty = try Pty.Session.spawn(cwd, shell);
        errdefer pty.deinit();
        const normalized_history_limit = if (history_limit == 0)
            LaunchProfile.default_scrollback_lines
        else
            history_limit;
        var grid = try Vt.Grid.initWithHistoryAllocator(
            allocator,
            history_allocator,
            columns,
            rows,
            normalized_history_limit,
        );
        errdefer grid.deinit();
        try pty.resize(rows, columns, 0, 0);
        return .{
            .allocator = allocator,
            .pty = pty,
            .grid = grid,
            .pump_scratch = pump_scratch,
            .pump_scratch_owned = false,
            .pending_write = std.array_list.Managed(u8).init(allocator),
        };
    }

    pub fn spawnProfile(
        allocator: std.mem.Allocator,
        profile: *const LaunchProfile.Profile,
        pane_cwd: []const u8,
        fallback_shell: []const u8,
        columns: u16,
        rows: u16,
    ) !TerminalSession {
        const pump_scratch = try allocator.create(PumpScratch);
        errdefer allocator.destroy(pump_scratch);
        pump_scratch.* = .{};
        var session = try spawnProfileWithScratch(
            allocator,
            profile,
            pane_cwd,
            fallback_shell,
            columns,
            rows,
            pump_scratch,
        );
        session.pump_scratch_owned = true;
        return session;
    }

    pub fn spawnProfileWithScratch(
        allocator: std.mem.Allocator,
        profile: *const LaunchProfile.Profile,
        pane_cwd: []const u8,
        fallback_shell: []const u8,
        columns: u16,
        rows: u16,
        pump_scratch: *PumpScratch,
    ) !TerminalSession {
        var normalized_profile = profile.*;
        normalized_profile.normalizeScrollback();
        try normalized_profile.validate();
        const profile_effective = &normalized_profile;
        const cwd = try Compat.dupeZ(allocator, profile_effective.workingDirectory(pane_cwd));
        defer allocator.free(cwd);
        const program = try Compat.dupeZ(allocator, profile_effective.shellPath(fallback_shell));
        defer allocator.free(program);
        const argument = try Compat.dupeZ(allocator, profile_effective.argument());
        defer allocator.free(argument);
        const environment = try Compat.dupeZ(allocator, profile_effective.environment.slice());
        defer allocator.free(environment);

        var pty = try Pty.Session.spawnProfile(.{
            .cwd = cwd,
            .program = program,
            .kind = profile_effective.kind,
            .argument = argument,
            .environment = environment,
        });
        errdefer pty.deinit();
        var grid = try Vt.Grid.initWithHistoryAllocator(
            allocator,
            history_allocator,
            columns,
            rows,
            profile_effective.scrollback_lines,
        );
        errdefer grid.deinit();
        try pty.resize(rows, columns, 0, 0);
        return .{
            .allocator = allocator,
            .pty = pty,
            .grid = grid,
            .pump_scratch = pump_scratch,
            .pump_scratch_owned = false,
            .pending_write = std.array_list.Managed(u8).init(allocator),
        };
    }

    fn clearFrameCache(self: *TerminalSession) void {
        if (self.frame_cache_cells) |cells| self.allocator.free(cells);
        if (self.frame_cache_row_generations) |generations|
            self.allocator.free(generations);
        if (self.frame_cache_row_valid) |valid| self.allocator.free(valid);
        self.frame_cache_cells = null;
        self.frame_cache_row_generations = null;
        self.frame_cache_row_valid = null;
        self.frame_cache_columns = 0;
        self.frame_cache_rows = 0;
        self.frame_cache_viewport_offset = std.math.maxInt(usize);
        self.frame_cache_history_count = std.math.maxInt(usize);
        self.frame_cache_damage_generation = 0;
    }

    fn ensureFrameCache(self: *TerminalSession) !void {
        const columns = self.grid.columns;
        const rows = self.grid.rows;
        const required = std.math.mul(usize, columns, rows) catch
            return error.FrameCacheTooLarge;
        if (self.frame_cache_cells) |cells| {
            if (cells.len == required and
                self.frame_cache_columns == columns and
                self.frame_cache_rows == rows and
                self.frame_cache_row_generations != null and
                self.frame_cache_row_valid != null)
                return;
        }

        const cells = try self.allocator.alloc(u64, required);
        errdefer self.allocator.free(cells);
        const generations = try self.allocator.alloc(u64, rows);
        errdefer self.allocator.free(generations);
        const valid = try self.allocator.alloc(bool, rows);
        errdefer self.allocator.free(valid);
        @memset(valid, false);
        self.clearFrameCache();
        self.frame_cache_cells = cells;
        self.frame_cache_row_generations = generations;
        self.frame_cache_row_valid = valid;
        self.frame_cache_columns = columns;
        self.frame_cache_rows = rows;
    }

    pub fn packedFrame(
        self: *TerminalSession,
        first_row: usize,
        requested_rows: usize,
        output: []u64,
    ) !usize {
        if (requested_rows == 0 or first_row >= self.grid.rows) return 0;
        const row_count = @min(requested_rows, self.grid.rows - first_row);
        const columns = self.grid.columns;
        const required = std.math.mul(usize, row_count, columns) catch
            return error.FrameCacheTooLarge;
        if (output.len < required) return error.FrameCacheCapacity;
        try self.ensureFrameCache();

        const cache = self.frame_cache_cells.?;
        const generations = self.frame_cache_row_generations.?;
        const valid = self.frame_cache_row_valid.?;
        const viewport_offset = self.grid.viewportOffset();
        const history_count = self.grid.historyCount();
        const damage_generation = self.grid.damageGeneration();
        const viewport_changed =
            self.frame_cache_viewport_offset != viewport_offset or
            self.frame_cache_history_count != history_count;
        const scrolled_damage =
            viewport_offset > 0 and
            self.frame_cache_damage_generation != damage_generation;
        const damage_wrapped = damage_generation < self.frame_cache_damage_generation;
        if (viewport_changed or scrolled_damage or damage_wrapped) @memset(valid, false);
        self.frame_cache_viewport_offset = viewport_offset;
        self.frame_cache_history_count = history_count;
        self.frame_cache_damage_generation = damage_generation;

        const blank: u64 = @as(u64, ' ');
        for (0..row_count) |offset| {
            const row = first_row + offset;
            const generation = if (viewport_offset == 0)
                self.grid.rowDamageGeneration(row)
            else
                damage_generation;
            const cache_row = cache[row * columns ..][0..columns];
            if (!valid[row] or generations[row] != generation) {
                const copied = self.grid.packedRow(row, cache_row);
                if (copied < columns) @memset(cache_row[copied..], blank);
                generations[row] = generation;
                valid[row] = true;
            }
            @memcpy(output[offset * columns ..][0..columns], cache_row);
        }
        return row_count;
    }

    pub fn deinit(self: *TerminalSession) void {
        if (self.deinitialized) return;
        self.pty.deinit();
        self.grid.deinit();
        self.clearFrameCache();
        self.pending_write.deinit();
        if (self.pump_scratch_owned) self.allocator.destroy(self.pump_scratch);
        self.deinitialized = true;
    }

    pub fn closeTransport(self: *TerminalSession) void {
        self.pty.closeDescriptor();
    }

    pub fn write(self: *TerminalSession, bytes: []const u8) !void {
        if (self.deinitialized) return error.TerminalSessionClosed;
        if (bytes.len == 0) return;
        _ = try self.flushPendingWrites();
        if (bytes.len > max_pending_write_bytes - self.pendingWriteBytes())
            return error.TerminalSessionWriteQueueFull;
        self.compactPendingWrites();
        if (self.pendingWriteBytes() == 0) {
            try self.pending_write.ensureUnusedCapacity(bytes.len);
            const written = self.pty.write(bytes) catch |err| switch (err) {
                error.PtyWouldBlock => 0,
                else => return err,
            };
            if (written == bytes.len) {
                self.pending_write.clearRetainingCapacity();
                return;
            }
            self.pending_write.appendSliceAssumeCapacity(bytes[written..]);
            return;
        }
        try self.pending_write.appendSlice(bytes);
        _ = try self.flushPendingWrites();
    }

    pub fn hasPendingWrites(self: *const TerminalSession) bool {
        return self.pendingWriteBytes() > 0;
    }

    pub fn flushPendingWrites(self: *TerminalSession) !bool {
        if (self.deinitialized) return error.TerminalSessionClosed;
        while (self.pending_write_start < self.pending_write.items.len) {
            const written = self.pty.write(
                self.pending_write.items[self.pending_write_start..],
            ) catch |err| switch (err) {
                error.PtyWouldBlock => return false,
                else => return err,
            };
            if (written == 0) return false;
            self.pending_write_start += written;
        }
        self.pending_write_start = 0;
        if (self.pending_write.capacity > retained_write_capacity) {
            self.pending_write.deinit();
            self.pending_write = std.array_list.Managed(u8).init(self.allocator);
        } else {
            self.pending_write.clearRetainingCapacity();
        }
        return true;
    }

    fn pendingWriteBytes(self: *const TerminalSession) usize {
        return self.pending_write.items.len - self.pending_write_start;
    }

    fn compactPendingWrites(self: *TerminalSession) void {
        if (self.pending_write_start == 0) return;
        const remaining = self.pending_write.items[self.pending_write_start..];
        std.mem.copyForwards(u8, self.pending_write.items[0..remaining.len], remaining);
        self.pending_write.items.len = remaining.len;
        self.pending_write_start = 0;
    }

    pub fn fileDescriptor(self: *const TerminalSession) i32 {
        return if (self.deinitialized) -1 else self.pty.fileDescriptor();
    }

    pub fn processId(self: *const TerminalSession) i32 {
        return if (self.deinitialized) 0 else self.pty.processId();
    }

    pub fn hasForegroundProcess(self: *const TerminalSession) bool {
        return !self.deinitialized and self.pty.hasForegroundProcess();
    }

    pub fn processInfo(self: *const TerminalSession, cwd: []u8, name: []u8) ?Pty.ProcessInfo {
        if (self.deinitialized) return null;
        return self.pty.processInfo(cwd, name);
    }

    pub fn resize(self: *TerminalSession, columns: u16, rows: u16, width_px: u32, height_px: u32) !void {
        if (self.deinitialized) return error.TerminalSessionClosed;
        const changed = columns != self.grid.columns or rows != self.grid.rows;
        try self.pty.resize(rows, columns, width_px, height_px);
        try self.grid.resize(columns, rows);
        if (changed) self.clearFrameCache();
    }

    pub fn pump(self: *TerminalSession) !Pumped {
        if (self.deinitialized) return error.TerminalSessionClosed;
        if (self.pump_scratch.in_use) return error.TerminalSessionPumpReentered;
        self.pump_scratch.in_use = true;
        defer self.pump_scratch.in_use = false;
        if (self.hasPendingWrites()) _ = try self.flushPendingWrites();
        const result = try self.pumpFrom(&self.pty);
        try self.flushReplies();
        if (self.hasPendingWrites()) _ = try self.flushPendingWrites();
        return result;
    }

    fn flushReplies(self: *TerminalSession) !void {
        const replies = self.grid.pendingReplies();
        if (replies.len == 0) return;
        try self.write(replies);
        self.grid.consumeReplies(replies.len);
    }

    fn pumpFrom(self: *TerminalSession, reader: anytype) !Pumped {
        var total: usize = 0;
        while (total < max_pump_bytes) {
            switch (try reader.read(&self.pump_scratch.bytes)) {
                .bytes => |count| {
                    if (count == 0) return if (total == 0) .eof else .{ .bytes = total };
                    try self.grid.feed(self.pump_scratch.bytes[0..count]);
                    total += count;
                },
                .would_block => return if (total == 0) .would_block else .{ .bytes = total },
                .eof => return if (total == 0) .eof else .{ .bytes = total },
            }
        }
        return .{ .bytes = total };
    }

    pub fn pollExit(self: *TerminalSession) !?u8 {
        if (self.deinitialized) return error.TerminalSessionClosed;
        return self.pty.pollExit();
    }

    pub const Pumped = union(enum) {
        bytes: usize,
        would_block,
        eof,
    };
};

test "terminal session pump drains PTY bytes to a bounded per-tick budget" {
    const FakeReader = struct {
        bytes: []const u8,
        offset: usize = 0,

        fn read(self: *@This(), output: []u8) !Pty.ReadResult {
            if (self.offset == self.bytes.len) return .would_block;
            const count = @min(output.len, self.bytes.len - self.offset);
            @memcpy(output[0..count], self.bytes[self.offset..][0..count]);
            self.offset += count;
            return .{ .bytes = count };
        }
    };

    const input = try std.testing.allocator.alloc(u8, TerminalSession.max_pump_bytes + 4096);
    defer std.testing.allocator.free(input);
    @memset(input, 0);

    var pump_scratch = TerminalSession.PumpScratch{};
    var session = TerminalSession{
        .allocator = std.testing.allocator,
        .pty = undefined,
        .grid = try Vt.Grid.init(std.testing.allocator, 8, 2),
        .pump_scratch = &pump_scratch,
        .pump_scratch_owned = false,
        .pending_write = std.array_list.Managed(u8).init(std.testing.allocator),
    };
    defer session.pending_write.deinit();
    defer session.grid.deinit();
    var reader = FakeReader{ .bytes = input };

    switch (try session.pumpFrom(&reader)) {
        .bytes => |count| try std.testing.expectEqual(TerminalSession.max_pump_bytes, count),
        else => return error.ExpectedBoundedPumpBytes,
    }
    switch (try session.pumpFrom(&reader)) {
        .bytes => |count| try std.testing.expectEqual(@as(usize, 4096), count),
        else => return error.ExpectedRemainingPumpBytes,
    }
    switch (try session.pumpFrom(&reader)) {
        .would_block => {},
        else => return error.ExpectedPumpWouldBlock,
    }
}

test "terminal session packed frame cache follows output and viewport changes" {
    var pump_scratch = TerminalSession.PumpScratch{};
    var session = TerminalSession{
        .allocator = std.testing.allocator,
        .pty = undefined,
        .grid = try Vt.Grid.init(std.testing.allocator, 4, 2),
        .pump_scratch = &pump_scratch,
        .pump_scratch_owned = false,
        .pending_write = std.array_list.Managed(u8).init(std.testing.allocator),
    };
    defer session.clearFrameCache();
    defer session.pending_write.deinit();
    defer session.grid.deinit();

    try session.grid.feed("ab\r\ncd\r\nef");
    try std.testing.expect(session.grid.historyCount() > 0);
    var cached: [8]u64 = undefined;
    var direct: [8]u64 = undefined;
    try std.testing.expectEqual(@as(usize, 2), try session.packedFrame(
        0,
        2,
        &cached,
    ));
    for (0..2) |row| _ = session.grid.packedRow(
        row,
        direct[row * 4 ..][0..4],
    );
    try std.testing.expectEqualSlices(u64, &direct, &cached);

    try session.grid.feed("\x1b[1;1HZ");
    _ = try session.packedFrame(0, 2, &cached);
    for (0..2) |row| _ = session.grid.packedRow(
        row,
        direct[row * 4 ..][0..4],
    );
    try std.testing.expectEqualSlices(u64, &direct, &cached);

    session.grid.scrollViewport(1);
    try std.testing.expect(session.grid.viewportOffset() > 0);
    _ = try session.packedFrame(0, 2, &cached);
    for (0..2) |row| _ = session.grid.packedRow(
        row,
        direct[row * 4 ..][0..4],
    );
    try std.testing.expectEqualSlices(u64, &direct, &cached);
}

test "terminal sessions keep recurring pump storage outside the session value" {
    try std.testing.expect(@sizeOf(TerminalSession) < 16 * 1024);
    try std.testing.expectEqual(
        TerminalSession.output_buffer_bytes + 1,
        @sizeOf(TerminalSession.PumpScratch),
    );
}

test "terminal sessions can share caller-owned serial pump scratch" {
    var pump_scratch = TerminalSession.PumpScratch{};
    var first = try TerminalSession.spawnWithHistoryLimitAndScratch(
        std.testing.allocator,
        "/tmp",
        "/bin/sh",
        40,
        4,
        Vt.Grid.default_history_lines,
        &pump_scratch,
    );
    defer first.deinit();
    var second = try TerminalSession.spawnWithHistoryLimitAndScratch(
        std.testing.allocator,
        "/tmp",
        "/bin/sh",
        40,
        4,
        Vt.Grid.default_history_lines,
        &pump_scratch,
    );
    defer second.deinit();

    try std.testing.expect(first.pump_scratch == second.pump_scratch);
    pump_scratch.in_use = true;
    try std.testing.expectError(error.TerminalSessionPumpReentered, first.pump());
    pump_scratch.in_use = false;
}

test "terminal session queues and flushes blocked PTY writes" {
    var session = try TerminalSession.spawn(
        std.testing.allocator,
        "/tmp",
        "/bin/sh",
        40,
        4,
    );
    defer session.deinit();
    try session.write("sleep 1; cat >/dev/null\n");
    Pty.sleepBrief(50);

    const input = try std.testing.allocator.alloc(u8, 8 * 1024 * 1024);
    defer std.testing.allocator.free(input);
    @memset(input, 'x');
    try session.write(input);
    try std.testing.expect(session.hasPendingWrites());
    for (0..60_000) |_| {
        if (try session.flushPendingWrites()) break;
        Pty.sleepBrief(1);
    }
    try std.testing.expect(!session.hasPendingWrites());
}

test "terminal session routes real PTY bytes into the Zig VT grid" {
    var session = try TerminalSession.spawn(std.testing.allocator, "/tmp", "/bin/sh", 40, 4);
    defer session.deinit();
    try session.resize(48, 5, 480, 180);
    try std.testing.expectEqual(@as(usize, 48), session.grid.columns);
    try std.testing.expectEqual(@as(usize, 5), session.grid.rows);
    try session.write("printf '\\033[2;1mDINTTY_SESSION_OK\\033]2;session-title\\007'; exit 0\n");

    var saw_marker = false;
    var saw_exit = false;
    var saw_eof = false;
    var attempts: usize = 0;
    while (attempts < 30_000 and !(saw_marker and saw_exit)) : (attempts += 1) {
        if (!saw_eof) {
            switch (try session.pump()) {
                .bytes => {},
                .would_block => Pty.sleepBrief(2),
                .eof => {
                    saw_eof = true;
                    session.closeTransport();
                },
            }
        } else {
            Pty.sleepBrief(1);
        }
        if (std.mem.eql(u8, session.grid.titleSlice(), "session-title")) {
            for (0..session.grid.rows) |row| for (0..session.grid.columns) |column| {
                if (session.grid.cell(column, row).codepoint == 'N') saw_marker = true;
            };
        }
        if (saw_eof) {
            if (try session.pollExit()) |code| {
                try std.testing.expectEqual(@as(u8, 0), code);
                saw_exit = true;
            }
        }
    }
    try std.testing.expect(saw_eof);
    try std.testing.expect(saw_marker);
    try std.testing.expect(saw_exit);
    try std.testing.expectEqual(@as(i32, -1), session.fileDescriptor());
    try std.testing.expect(std.mem.eql(u8, session.grid.titleSlice(), "session-title"));
}

test "terminal session teardown is idempotent and closes its public boundary" {
    var session = try TerminalSession.spawn(std.testing.allocator, "/tmp", "/bin/sh", 40, 4);
    session.deinit();
    session.deinit();

    try std.testing.expectEqual(@as(i32, -1), session.fileDescriptor());
    try std.testing.expect(!session.hasForegroundProcess());
    try std.testing.expectError(error.TerminalSessionClosed, session.write("ignored"));
    try std.testing.expectError(error.TerminalSessionClosed, session.resize(80, 24, 0, 0));
    try std.testing.expectError(error.TerminalSessionClosed, session.pump());
    try std.testing.expectError(error.TerminalSessionClosed, session.pollExit());
}

test "terminal launch profile applies command cwd environment and scrollback" {
    var profile = LaunchProfile.Profile{ .kind = .command };
    try profile.shell.set("/bin/sh");
    try profile.command.set("printf 'DINTTY_PROFILE=%s:%s' \"$PWD\" \"$DINTTY_PROFILE\"");
    try profile.working_directory.set("/tmp");
    try profile.environment.set("DINTTY_PROFILE=ready;DINTTY_SECOND=value");
    profile.scrollback_lines = 321;

    var session = try TerminalSession.spawnProfile(std.testing.allocator, &profile, "/", "/bin/false", 96, 4);
    defer session.deinit();
    try std.testing.expectEqual(@as(usize, 321), session.grid.history_limit);

    var saw_exit = false;
    for (0..60_000) |_| {
        _ = try session.pump();
        if (try session.pollExit()) |code| {
            try std.testing.expectEqual(@as(u8, 0), code);
            saw_exit = true;
            break;
        }
        Pty.sleepBrief(1);
    }
    try std.testing.expect(saw_exit);

    var row_bytes: [96]u8 = undefined;
    var saw_marker = false;
    for (0..session.grid.rows) |row| {
        for (0..session.grid.columns) |column| {
            const codepoint = session.grid.cell(column, row).codepoint;
            row_bytes[column] = if (codepoint <= 0x7f) @intCast(codepoint) else '?';
        }
        if (std.mem.indexOf(u8, row_bytes[0..session.grid.columns], "DINTTY_PROFILE=/tmp:ready") != null) {
            saw_marker = true;
            break;
        }
    }
    try std.testing.expect(saw_marker);
}
