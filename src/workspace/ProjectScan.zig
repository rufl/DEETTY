const std = @import("std");
const Workspace = @import("Workspace.zig");

pub const ScanOptions = struct {
    max_git_status_entries: usize = 512,
    max_git_graph_entries: usize = 32,
    max_file_entries: usize = 512,
    max_depth: usize = 5,
    include_hidden: bool = false,
    include_generated_dirs: bool = false,
    include_git_dir: bool = false,

    pub fn validate(self: ScanOptions) !void {
        if (self.max_git_status_entries == 0) return error.InvalidProjectScanOptions;
        if (self.max_git_graph_entries == 0) return error.InvalidProjectScanOptions;
        if (self.max_file_entries == 0) return error.InvalidProjectScanOptions;
        if (self.max_depth == 0) return error.InvalidProjectScanOptions;
    }
};

pub const ScanResult = struct {
    git_status: []Workspace.GitStatusInput = &.{},
    git_graph: []Workspace.GitGraphInput = &.{},
    files: []Workspace.ProjectFileInput = &.{},
    git_status_truncated: bool = false,
    git_graph_truncated: bool = false,
    files_truncated: bool = false,

    pub fn deinit(self: *ScanResult, allocator: std.mem.Allocator) void {
        for (self.git_status) |entry| allocator.free(entry.path);
        if (self.git_status.len != 0) allocator.free(self.git_status);

        for (self.git_graph) |node| {
            allocator.free(node.commit);
            allocator.free(node.summary);
            if (node.branch) |branch| allocator.free(branch);
        }
        if (self.git_graph.len != 0) allocator.free(self.git_graph);

        for (self.files) |entry| allocator.free(entry.path);
        if (self.files.len != 0) allocator.free(self.files);
        self.* = .{};
    }

    pub fn update(self: ScanResult) Workspace.ProjectPanelUpdate {
        return .{
            .git_status = self.git_status,
            .git_graph = self.git_graph,
            .files = self.files,
        };
    }
};

const max_git_output_bytes: usize = 1024 * 1024;
const record_sep: u8 = 0x1e;
const field_sep: u8 = 0x1f;

pub fn runGitStatusAlloc(
    allocator: std.mem.Allocator,
    io: std.Io,
    cwd_path: ?[]const u8,
    options: ScanOptions,
) !ScanResult {
    try options.validate();
    const argv = [_][]const u8{ "git", "status", "--porcelain=v1", "-z" };
    const result = try std.process.run(allocator, io, .{
        .argv = &argv,
        .cwd = if (cwd_path) |path| .{ .path = path } else .inherit,
        .stdout_limit = .limited(max_git_output_bytes),
        .stderr_limit = .limited(64 * 1024),
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    switch (result.term) {
        .exited => |code| if (code != 0) return error.GitCommandFailed,
        else => return error.GitCommandFailed,
    }
    return parseGitStatusPorcelainAlloc(allocator, result.stdout, options.max_git_status_entries);
}

pub fn runGitGraphAlloc(
    allocator: std.mem.Allocator,
    io: std.Io,
    cwd_path: ?[]const u8,
    options: ScanOptions,
) !ScanResult {
    try options.validate();
    const count_arg = try std.fmt.allocPrint(allocator, "-n{d}", .{options.max_git_graph_entries});
    defer allocator.free(count_arg);
    const argv = [_][]const u8{
        "git",
        "log",
        "--decorate=short",
        "--format=%h%x1f%d%x1f%s%x1e",
        count_arg,
    };
    const result = try std.process.run(allocator, io, .{
        .argv = &argv,
        .cwd = if (cwd_path) |path| .{ .path = path } else .inherit,
        .stdout_limit = .limited(max_git_output_bytes),
        .stderr_limit = .limited(64 * 1024),
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    switch (result.term) {
        .exited => |code| if (code != 0) return error.GitCommandFailed,
        else => return error.GitCommandFailed,
    }
    return parseGitGraphAlloc(allocator, result.stdout, options.max_git_graph_entries);
}

pub fn parseGitStatusPorcelainAlloc(
    allocator: std.mem.Allocator,
    bytes: []const u8,
    max_entries: usize,
) !ScanResult {
    if (max_entries == 0) return error.InvalidProjectScanOptions;

    var entries = std.array_list.Managed(Workspace.GitStatusInput).init(allocator);
    errdefer entries.deinit();
    errdefer freeGitStatusInputs(allocator, entries.items);

    var truncated = false;
    if (std.mem.indexOfScalar(u8, bytes, 0) != null) {
        var cursor: usize = 0;
        while (cursor < bytes.len) {
            const end = std.mem.indexOfScalarPos(u8, bytes, cursor, 0) orelse bytes.len;
            const raw = bytes[cursor..end];
            cursor = if (end < bytes.len) end + 1 else end;
            if (raw.len == 0) continue;

            if (entries.items.len >= max_entries) {
                truncated = true;
                break;
            }
            const parsed = try parseStatusRecordAlloc(allocator, raw) orelse continue;
            errdefer allocator.free(parsed.path);
            try entries.append(parsed);

            if (isRenameOrCopyStatus(raw) and cursor < bytes.len) {
                const old_end = std.mem.indexOfScalarPos(u8, bytes, cursor, 0) orelse bytes.len;
                cursor = if (old_end < bytes.len) old_end + 1 else old_end;
            }
        }
    } else {
        var it = std.mem.splitScalar(u8, bytes, '\n');
        while (it.next()) |line| {
            const raw = std.mem.trim(u8, line, "\r\n");
            if (raw.len == 0) continue;

            if (entries.items.len >= max_entries) {
                truncated = true;
                break;
            }
            const parsed = try parseStatusRecordAlloc(allocator, raw) orelse continue;
            errdefer allocator.free(parsed.path);
            try entries.append(parsed);
        }
    }

    return .{
        .git_status = try entries.toOwnedSlice(),
        .git_status_truncated = truncated,
    };
}

pub fn parseGitGraphAlloc(
    allocator: std.mem.Allocator,
    bytes: []const u8,
    max_entries: usize,
) !ScanResult {
    if (max_entries == 0) return error.InvalidProjectScanOptions;

    var nodes = std.array_list.Managed(Workspace.GitGraphInput).init(allocator);
    errdefer nodes.deinit();
    errdefer freeGitGraphInputs(allocator, nodes.items);

    var truncated = false;
    const sep = if (std.mem.indexOfScalar(u8, bytes, record_sep) != null) record_sep else '\n';
    var it = std.mem.splitScalar(u8, bytes, sep);
    while (it.next()) |record_raw| {
        const record = std.mem.trim(u8, record_raw, " \t\r\n");
        if (record.len == 0) continue;

        if (nodes.items.len >= max_entries) {
            truncated = true;
            break;
        }
        const parsed = try parseGraphRecordAlloc(allocator, record) orelse continue;
        errdefer freeGitGraphInput(allocator, parsed);
        try nodes.append(parsed);
    }

    return .{
        .git_graph = try nodes.toOwnedSlice(),
        .git_graph_truncated = truncated,
    };
}

pub fn scanFilesAlloc(
    allocator: std.mem.Allocator,
    io: std.Io,
    dir: std.Io.Dir,
    options: ScanOptions,
) !ScanResult {
    try options.validate();

    var files = std.array_list.Managed(Workspace.ProjectFileInput).init(allocator);
    errdefer files.deinit();
    errdefer freeProjectFileInputs(allocator, files.items);

    var truncated = false;
    var walker = try dir.walkSelectively(allocator);
    defer walker.deinit();

    while (try walker.next(io)) |entry| {
        const depth = entry.depth();
        const skip = shouldSkipEntry(entry.basename, entry.path, entry.kind, options);
        if (!skip and depth <= options.max_depth) {
            if (files.items.len >= options.max_file_entries) {
                truncated = true;
                break;
            }
            const owned_path = try allocator.dupe(u8, entry.path);
            errdefer allocator.free(owned_path);
            try files.append(.{
                .path = owned_path,
                .kind = if (entry.kind == .directory) .directory else .file,
                .dirty = false,
            });
        }

        if (!skip and entry.kind == .directory and depth < options.max_depth) {
            try walker.enter(io, entry);
        }
    }

    std.sort.heap(Workspace.ProjectFileInput, files.items, {}, lessProjectFileInput);

    return .{
        .files = try files.toOwnedSlice(),
        .files_truncated = truncated,
    };
}

fn parseStatusRecordAlloc(allocator: std.mem.Allocator, raw: []const u8) !?Workspace.GitStatusInput {
    if (raw.len < 3) return null;
    const x = raw[0];
    const y = raw[1];
    var path = if (raw.len > 3 and raw[2] == ' ') raw[3..] else raw[2..];
    path = std.mem.trim(u8, path, " \t\r\n");
    if (path.len == 0) return null;
    if (std.mem.indexOf(u8, path, " -> ")) |arrow| {
        path = path[arrow + 4 ..];
    }

    return .{
        .path = try allocator.dupe(u8, path),
        .state = stateFromPorcelain(x, y),
    };
}

fn parseGraphRecordAlloc(allocator: std.mem.Allocator, record: []const u8) !?Workspace.GitGraphInput {
    if (std.mem.indexOfScalar(u8, record, field_sep) != null) {
        var fields = std.mem.splitScalar(u8, record, field_sep);
        const commit = std.mem.trim(u8, fields.next() orelse return null, " \t\r\n");
        const decorations = std.mem.trim(u8, fields.next() orelse "", " \t\r\n");
        const summary = std.mem.trim(u8, fields.next() orelse return null, " \t\r\n");
        return cloneGraphFields(allocator, commit, decorations, summary);
    }

    if (std.mem.indexOfScalar(u8, record, '\t') != null) {
        var fields = std.mem.splitScalar(u8, record, '\t');
        const commit = std.mem.trim(u8, fields.next() orelse return null, " \t\r\n");
        const branch = std.mem.trim(u8, fields.next() orelse "", " \t\r\n");
        const summary = std.mem.trim(u8, fields.next() orelse return null, " \t\r\n");
        return cloneGraphFields(allocator, commit, branch, summary);
    }

    const space = std.mem.indexOfScalar(u8, record, ' ') orelse return null;
    const commit = std.mem.trim(u8, record[0..space], " \t\r\n");
    const summary = std.mem.trim(u8, record[space + 1 ..], " \t\r\n");
    return cloneGraphFields(allocator, commit, "", summary);
}

fn cloneGraphFields(
    allocator: std.mem.Allocator,
    commit: []const u8,
    decorations: []const u8,
    summary: []const u8,
) !?Workspace.GitGraphInput {
    if (commit.len == 0 or summary.len == 0) return null;

    const owned_commit = try allocator.dupe(u8, commit);
    errdefer allocator.free(owned_commit);
    const owned_summary = try allocator.dupe(u8, summary);
    errdefer allocator.free(owned_summary);
    const owned_branch = try branchFromDecorationsAlloc(allocator, decorations);
    errdefer if (owned_branch) |branch| allocator.free(branch);

    return .{
        .commit = owned_commit,
        .summary = owned_summary,
        .branch = owned_branch,
    };
}

fn branchFromDecorationsAlloc(allocator: std.mem.Allocator, decorations_raw: []const u8) !?[]u8 {
    var decorations = std.mem.trim(u8, decorations_raw, " \t\r\n()");
    if (decorations.len == 0) return null;

    if (std.mem.indexOf(u8, decorations, "HEAD -> ")) |idx| {
        decorations = decorations[idx + "HEAD -> ".len ..];
    }
    if (std.mem.indexOfScalar(u8, decorations, ',')) |comma| {
        decorations = decorations[0..comma];
    }
    decorations = std.mem.trim(u8, decorations, " \t\r\n()");
    if (decorations.len == 0 or std.mem.eql(u8, decorations, "HEAD")) return null;
    if (std.mem.startsWith(u8, decorations, "tag: ")) return null;
    return try allocator.dupe(u8, decorations);
}

fn stateFromPorcelain(x: u8, y: u8) Workspace.GitFileState {
    if (x == 'U' or y == 'U' or
        (x == 'A' and y == 'A') or
        (x == 'D' and y == 'D') or
        (x == 'A' and y == 'D') or
        (x == 'D' and y == 'A'))
    {
        return .conflicted;
    }
    if (x == '?' or y == '?') return .untracked;
    if (x == '!' or y == '!') return .ignored;
    if (x == 'R' or y == 'R') return .renamed;
    if (x == 'A' or y == 'A') return .added;
    if (x == 'D' or y == 'D') return .deleted;
    if (x == 'M' or y == 'M' or x == 'T' or y == 'T' or x == 'C' or y == 'C') return .modified;
    return .unmodified;
}

fn isRenameOrCopyStatus(raw: []const u8) bool {
    return raw.len >= 2 and (raw[0] == 'R' or raw[1] == 'R' or raw[0] == 'C' or raw[1] == 'C');
}

fn shouldSkipEntry(
    basename: []const u8,
    path: []const u8,
    kind: std.Io.File.Kind,
    options: ScanOptions,
) bool {
    if (!options.include_hidden and basename.len > 0 and basename[0] == '.') return true;
    if (!options.include_git_dir and (std.mem.eql(u8, basename, ".git") or std.mem.startsWith(u8, path, ".git/"))) return true;
    if (!options.include_generated_dirs and kind == .directory) {
        if (std.mem.eql(u8, basename, ".zig-cache")) return true;
        if (std.mem.eql(u8, basename, ".zig-global-cache")) return true;
        if (std.mem.eql(u8, basename, "zig-out")) return true;
        if (std.mem.eql(u8, basename, "node_modules")) return true;
        if (std.mem.eql(u8, basename, "target")) return true;
        if (std.mem.eql(u8, basename, "vendor")) return true;
    }
    return false;
}

fn lessProjectFileInput(_: void, lhs: Workspace.ProjectFileInput, rhs: Workspace.ProjectFileInput) bool {
    return std.mem.lessThan(u8, lhs.path, rhs.path);
}

fn freeGitStatusInputs(allocator: std.mem.Allocator, entries: []Workspace.GitStatusInput) void {
    for (entries) |entry| allocator.free(entry.path);
}

fn freeGitGraphInputs(allocator: std.mem.Allocator, nodes: []Workspace.GitGraphInput) void {
    for (nodes) |node| freeGitGraphInput(allocator, node);
}

fn freeGitGraphInput(allocator: std.mem.Allocator, node: Workspace.GitGraphInput) void {
    allocator.free(node.commit);
    allocator.free(node.summary);
    if (node.branch) |branch| allocator.free(branch);
}

fn freeProjectFileInputs(allocator: std.mem.Allocator, entries: []Workspace.ProjectFileInput) void {
    for (entries) |entry| allocator.free(entry.path);
}

test "project scan parses porcelain git status including renames and conflicts" {
    const allocator = std.testing.allocator;
    var scan = try parseGitStatusPorcelainAlloc(
        allocator,
        " M src/main.zig\x00R  src/new.zig\x00src/old.zig\x00?? docs/new.md\x00UU merge.txt\x00!! .zig-cache\x00",
        8,
    );
    defer scan.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 5), scan.git_status.len);
    try std.testing.expectEqual(Workspace.GitFileState.modified, scan.git_status[0].state);
    try std.testing.expectEqualStrings("src/main.zig", scan.git_status[0].path);
    try std.testing.expectEqual(Workspace.GitFileState.renamed, scan.git_status[1].state);
    try std.testing.expectEqualStrings("src/new.zig", scan.git_status[1].path);
    try std.testing.expectEqual(Workspace.GitFileState.untracked, scan.git_status[2].state);
    try std.testing.expectEqual(Workspace.GitFileState.conflicted, scan.git_status[3].state);
    try std.testing.expectEqual(Workspace.GitFileState.ignored, scan.git_status[4].state);
}

test "project scan parses git graph decoration records" {
    const allocator = std.testing.allocator;
    var scan = try parseGitGraphAlloc(
        allocator,
        "abc1234\x1f (HEAD -> main, origin/main)\x1fproject scan\x1e" ++ "def5678\x1f (tag: v0)\x1farchive slice\x1e",
        8,
    );
    defer scan.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 2), scan.git_graph.len);
    try std.testing.expectEqualStrings("abc1234", scan.git_graph[0].commit);
    try std.testing.expectEqualStrings("main", scan.git_graph[0].branch.?);
    try std.testing.expectEqualStrings("project scan", scan.git_graph[0].summary);
    try std.testing.expect(scan.git_graph[1].branch == null);
}

test "project scan checks git caps before cloning overflow records" {
    const allocator = std.testing.allocator;
    var status_scan = try parseGitStatusPorcelainAlloc(
        allocator,
        " M src/one.zig\x00 M src/two.zig\x00 M src/three.zig\x00",
        2,
    );
    defer status_scan.deinit(allocator);
    try std.testing.expect(status_scan.git_status_truncated);
    try std.testing.expectEqual(@as(usize, 2), status_scan.git_status.len);
    try std.testing.expectEqualStrings("src/two.zig", status_scan.git_status[1].path);

    var graph_scan = try parseGitGraphAlloc(
        allocator,
        "abc1234\x1f (HEAD -> main)\x1fone\x1e" ++
            "def5678\x1f \x1ftwo\x1e" ++
            "fed9999\x1f \x1fthree\x1e",
        2,
    );
    defer graph_scan.deinit(allocator);
    try std.testing.expect(graph_scan.git_graph_truncated);
    try std.testing.expectEqual(@as(usize, 2), graph_scan.git_graph.len);
    try std.testing.expectEqualStrings("two", graph_scan.git_graph[1].summary);
}

test "project scan walks files with hidden and generated directories skipped" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try writeTestFile(io, tmp.dir, "README.md", "readme");
    try writeTestFile(io, tmp.dir, "src/app/App.zig", "const app = 1;");
    try writeTestFile(io, tmp.dir, ".git/objects/pack", "git");
    try writeTestFile(io, tmp.dir, ".hidden", "hidden");
    try writeTestFile(io, tmp.dir, ".zig-cache/o/hash", "cache");
    try writeTestFile(io, tmp.dir, "vendor/tree-sitter/parser.c", "vendor");
    try writeTestFile(io, tmp.dir, "zig-out/bin/noctty", "binary");

    var root = try tmp.dir.openDir(io, ".", .{ .iterate = true });
    defer root.close(io);

    var scan = try scanFilesAlloc(allocator, io, root, .{ .max_file_entries = 16, .max_depth = 4 });
    defer scan.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 4), scan.files.len);
    try std.testing.expectEqualStrings("README.md", scan.files[0].path);
    try std.testing.expectEqualStrings("src", scan.files[1].path);
    try std.testing.expectEqual(Workspace.ProjectFileKind.directory, scan.files[1].kind);
    try std.testing.expectEqualStrings("src/app", scan.files[2].path);
    try std.testing.expectEqualStrings("src/app/App.zig", scan.files[3].path);
}

fn writeTestFile(io: std.Io, dir: std.Io.Dir, path: []const u8, data: []const u8) !void {
    var atomic = try dir.createFileAtomic(io, path, .{
        .make_path = true,
        .replace = true,
    });
    defer atomic.deinit(io);
    try atomic.file.writeStreamingAll(io, data);
    try atomic.replace(io);
}
