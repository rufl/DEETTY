const std = @import("std");
const task = @import("Task.zig");

pub const max_status_bytes: usize = 256 * 1024;
pub const max_diff_bytes: usize = 512 * 1024;
pub const max_preview_bytes: usize = 48 * 1024;

pub const Counts = struct {
    changed: usize = 0,
    staged: usize = 0,
    unstaged: usize = 0,
    untracked: usize = 0,
    added: usize = 0,
    deleted: usize = 0,
    modified: usize = 0,
    renamed: usize = 0,
};

pub const Snapshot = struct {
    status: []u8,
    diff: []u8,
    counts: Counts,

    pub fn deinit(self: *Snapshot, allocator: std.mem.Allocator) void {
        allocator.free(self.status);
        allocator.free(self.diff);
        self.* = undefined;
    }
};

pub fn snapshotAlloc(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: []const u8,
) !Snapshot {
    const status_result = try runGit(
        allocator,
        io,
        root,
        &.{
            "git",
            "-c",
            "color.ui=false",
            "--no-optional-locks",
            "status",
            "--short",
            "--untracked-files=all",
            "--",
        },
    );
    defer allocator.free(status_result.output);
    if (!status_result.success) return error.GitStatusFailed;
    if (status_result.output.len > max_status_bytes) return error.GitStatusTooLarge;
    const status = try allocator.dupe(u8, status_result.output);
    errdefer allocator.free(status);

    const diff_result = try runGit(
        allocator,
        io,
        root,
        &.{
            "git",
            "-c",
            "color.ui=false",
            "--no-pager",
            "--no-optional-locks",
            "diff",
            "--no-ext-diff",
            "--unified=0",
            "--",
        },
    );
    defer allocator.free(diff_result.output);
    if (!diff_result.success) return error.GitDiffFailed;
    if (diff_result.output.len > max_diff_bytes) return error.GitDiffTooLarge;
    const diff = try allocator.dupe(u8, diff_result.output);
    return .{ .status = status, .diff = diff, .counts = countStatus(status) };
}

fn runGit(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: []const u8,
    argv: []const []const u8,
) !task.Result {
    return task.runControlledAlloc(
        allocator,
        io,
        root,
        .{ .name = "Git", .argv = argv },
        .{ .timeout_ms = 15_000 },
    );
}

pub fn countStatus(status: []const u8) Counts {
    var counts: Counts = .{};
    var lines = std.mem.splitScalar(u8, status, '\n');
    while (lines.next()) |line| {
        if (line.len < 2 or (line[0] == ' ' and line[1] == ' ')) continue;
        const index_status = line[0];
        const worktree_status = line[1];
        counts.changed += 1;
        if (index_status == '?' and worktree_status == '?') {
            counts.untracked += 1;
            continue;
        }
        if (index_status != ' ') counts.staged += 1;
        if (worktree_status != ' ') counts.unstaged += 1;
        const kind = if (index_status != ' ') index_status else worktree_status;
        switch (kind) {
            'A' => counts.added += 1,
            'D' => counts.deleted += 1,
            'M' => counts.modified += 1,
            'R' => counts.renamed += 1,
            else => {},
        }
    }
    return counts;
}

pub fn formatAlloc(
    allocator: std.mem.Allocator,
    snapshot: Snapshot,
) ![]u8 {
    var output: std.Io.Writer.Allocating = .init(allocator);
    errdefer output.deinit();
    try output.writer.print(
        "Git changes: changed={d} staged={d} unstaged={d} untracked={d} added={d} deleted={d} modified={d} renamed={d}\n\nStatus:\n",
        .{
            snapshot.counts.changed,
            snapshot.counts.staged,
            snapshot.counts.unstaged,
            snapshot.counts.untracked,
            snapshot.counts.added,
            snapshot.counts.deleted,
            snapshot.counts.modified,
            snapshot.counts.renamed,
        },
    );
    try writePreview(&output.writer, snapshot.status);
    try output.writer.writeAll("\nDiff:\n");
    try writePreview(&output.writer, snapshot.diff);
    return output.toOwnedSlice();
}

fn writePreview(writer: anytype, text: []const u8) !void {
    const length = @min(text.len, max_preview_bytes);
    try writer.writeAll(text[0..length]);
    if (length < text.len) try writer.writeAll("\n[preview truncated]\n");
}

test "parses porcelain status into change markers" {
    const counts = countStatus(" M src/main.zig\nA  new.zig\nD  old.zig\nR  old.zig -> new.zig\n?? scratch.txt\n");
    try std.testing.expectEqual(@as(usize, 5), counts.changed);
    try std.testing.expectEqual(@as(usize, 3), counts.staged);
    try std.testing.expectEqual(@as(usize, 1), counts.unstaged);
    try std.testing.expectEqual(@as(usize, 1), counts.untracked);
    try std.testing.expectEqual(@as(usize, 1), counts.added);
    try std.testing.expectEqual(@as(usize, 1), counts.deleted);
    try std.testing.expectEqual(@as(usize, 1), counts.modified);
    try std.testing.expectEqual(@as(usize, 1), counts.renamed);
}

test "ignores empty status lines" {
    const counts = countStatus("\n  \n");
    try std.testing.expectEqual(@as(usize, 0), counts.changed);
}
