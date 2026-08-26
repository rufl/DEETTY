const std = @import("std");
const ignore = @import("Ignore.zig");

pub const max_entries: usize = 100_000;
pub const max_depth: usize = 32;
pub const max_filesystem_changes: usize = 256;
pub const no_parent: u32 = std.math.maxInt(u32);

pub const EntryKind = enum(u8) { directory, file };

pub const InputEntry = struct { path: []const u8, kind: EntryKind };

pub const FilesystemChangeKind = enum(u8) {
    created,
    deleted,
    renamed,
    moved_in,
    moved_out,
};

/// Coalesced structural filesystem event. Paths are project-relative and the
/// caller retains ownership for the duration of applyFilesystemChangesAlloc.
pub const FilesystemChange = struct {
    kind: FilesystemChangeKind,
    path: []const u8,
    other_path: ?[]const u8 = null,
};

pub const DeltaStats = struct {
    events: usize = 0,
    refreshed_paths: usize = 0,
    removed_entries: usize = 0,
    added_entries: usize = 0,
};

pub const DeltaResult = struct {
    index: Index,
    stats: DeltaStats,
};

/// Offset-only worktree record. Paths and child lists live once in Storage.
pub const Entry = struct {
    path_offset: u32,
    path_length: u32,
    basename_offset: u32,
    parent_index: u32 = no_parent,
    first_child: u32 = 0,
    child_count: u32 = 0,
    boundary_mask: u64 = 1,
    kind: EntryKind,
};

const Storage = struct {
    references: std.atomic.Value(usize) = .init(1),
    arena: []u8,
    entries: []Entry,
    children: []u32,
    roots: []u32,
};

pub const Index = struct {
    storage: ?*Storage = null,
    entries: []const Entry = &.{},
    truncated: bool = false,

    pub fn deinit(self: *Index, allocator: std.mem.Allocator) void {
        const storage = self.storage orelse {
            self.* = .{};
            return;
        };
        if (storage.references.fetchSub(1, .acq_rel) == 1) {
            allocator.free(storage.roots);
            allocator.free(storage.children);
            allocator.free(storage.entries);
            allocator.free(storage.arena);
            allocator.destroy(storage);
        }
        self.* = .{};
    }

    /// Retains immutable storage; no path or entry bytes are copied.
    pub fn retain(self: Index) Index {
        if (self.storage) |storage| _ = storage.references.fetchAdd(1, .monotonic);
        return self;
    }

    pub fn path(self: Index, entry: Entry) []const u8 {
        const storage = self.storage orelse return &.{};
        const start: usize = entry.path_offset;
        return storage.arena[start .. start + entry.path_length];
    }

    pub fn pathAt(self: Index, entry_index: usize) []const u8 {
        if (entry_index >= self.entries.len) return &.{};
        return self.path(self.entries[entry_index]);
    }

    pub fn basename(self: Index, entry: Entry) []const u8 {
        const path_value = self.path(entry);
        return path_value[@min(entry.basename_offset, path_value.len)..];
    }

    pub fn childIndices(self: Index, entry: Entry) []const u32 {
        const storage = self.storage orelse return &.{};
        const first: usize = entry.first_child;
        return storage.children[first .. first + entry.child_count];
    }

    pub fn rootIndices(self: Index) []const u32 {
        const storage = self.storage orelse return &.{};
        return storage.roots;
    }

    pub fn findPath(self: Index, path_value: []const u8) ?usize {
        var low: usize = 0;
        var high = self.entries.len;
        while (low < high) {
            const middle = low + (high - low) / 2;
            const ordering = std.mem.order(u8, self.pathAt(middle), path_value);
            switch (ordering) {
                .lt => low = middle + 1,
                .gt => high = middle,
                .eq => return middle,
            }
        }
        return null;
    }

    pub fn retainedCount(self: Index) usize {
        const storage = self.storage orelse return 0;
        return storage.references.load(.acquire);
    }

    pub fn memoryBytes(self: Index) usize {
        const storage = self.storage orelse return 0;
        return @sizeOf(Storage) + storage.arena.len +
            storage.entries.len * @sizeOf(Entry) +
            (storage.children.len + storage.roots.len) * @sizeOf(u32);
    }
};

pub const ScanProgress = enum { pending, complete };

pub const Scanner = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    directory: std.Io.Dir,
    walker: std.Io.Dir.SelectiveWalker,
    entries: std.array_list.Managed(Entry),
    arena: std.array_list.Managed(u8),
    ignore_matcher: ignore.Matcher,
    truncated: bool = false,
    finished: bool = false,

    pub fn init(
        allocator: std.mem.Allocator,
        io: std.Io,
        root: []const u8,
    ) !Scanner {
        var directory = try std.Io.Dir.openDirAbsolute(io, root, .{ .iterate = true });
        errdefer directory.close(io);
        var walker = try directory.walkSelectively(allocator);
        errdefer walker.deinit();
        var ignore_matcher = ignore.Matcher.init(allocator);
        errdefer ignore_matcher.deinit();
        try ignore_matcher.loadDirectory(directory, io, "");
        return .{
            .allocator = allocator,
            .io = io,
            .directory = directory,
            .walker = walker,
            .entries = std.array_list.Managed(Entry).init(allocator),
            .arena = std.array_list.Managed(u8).init(allocator),
            .ignore_matcher = ignore_matcher,
            .truncated = ignore_matcher.truncated,
        };
    }

    pub fn deinit(self: *Scanner) void {
        if (!self.finished) {
            self.walker.deinit();
            self.directory.close(self.io);
        }
        self.entries.deinit();
        self.arena.deinit();
        self.ignore_matcher.deinit();
        self.* = undefined;
    }

    pub fn step(self: *Scanner, max_visits: usize) !ScanProgress {
        if (self.finished) return .complete;
        if (max_visits == 0) return error.InvalidScanBudget;

        var visits: usize = 0;
        while (visits < max_visits) : (visits += 1) {
            const candidate = try self.walker.next(self.io) orelse {
                self.finishTraversal();
                return .complete;
            };
            const depth = candidate.depth();
            const supported = candidate.kind == .directory or candidate.kind == .file;
            const skip = !supported or
                shouldSkip(candidate.basename, candidate.kind) or
                self.ignore_matcher.isIgnored(
                    candidate.path,
                    candidate.kind == .directory,
                );
            if (!skip and depth <= max_depth) {
                if (self.entries.items.len >= max_entries or
                    self.arena.items.len + candidate.path.len > std.math.maxInt(u32))
                {
                    self.truncated = true;
                    self.finishTraversal();
                    return .complete;
                }
                const offset = self.arena.items.len;
                try self.arena.appendSlice(candidate.path);
                try self.entries.append(.{
                    .path_offset = @intCast(offset),
                    .path_length = @intCast(candidate.path.len),
                    .basename_offset = @intCast(candidate.path.len - candidate.basename.len),
                    .boundary_mask = pathBoundaryMask(candidate.path),
                    .kind = if (candidate.kind == .directory) .directory else .file,
                });
            }
            if (!skip and candidate.kind == .directory and depth < max_depth) {
                try self.ignore_matcher.loadDirectory(
                    self.directory,
                    self.io,
                    candidate.path,
                );
                self.truncated = self.truncated or self.ignore_matcher.truncated;
                try self.walker.enter(self.io, candidate);
            }
        }
        return .pending;
    }

    pub fn takeIndex(self: *Scanner) !Index {
        if (!self.finished) return error.ScanIncomplete;
        std.sort.heap(Entry, self.entries.items, self.arena.items, lessThan);
        const arena = try self.arena.toOwnedSlice();
        errdefer self.allocator.free(arena);
        const entries = try self.entries.toOwnedSlice();
        errdefer self.allocator.free(entries);
        const relationships = try buildRelationships(self.allocator, arena, entries);
        errdefer relationships.deinit(self.allocator);
        const storage = try self.allocator.create(Storage);
        storage.* = .{
            .arena = arena,
            .entries = entries,
            .children = relationships.children,
            .roots = relationships.roots,
        };
        return .{
            .storage = storage,
            .entries = storage.entries,
            .truncated = self.truncated,
        };
    }

    fn finishTraversal(self: *Scanner) void {
        self.walker.deinit();
        self.directory.close(self.io);
        self.finished = true;
    }
};

pub fn scanAlloc(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: []const u8,
) !Index {
    var scanner = try Scanner.init(allocator, io, root);
    defer scanner.deinit();
    while (try scanner.step(256) == .pending) {}
    return scanner.takeIndex();
}

const Relationships = struct {
    children: []u32,
    roots: []u32,

    fn deinit(self: Relationships, allocator: std.mem.Allocator) void {
        allocator.free(self.children);
        allocator.free(self.roots);
    }
};

fn buildRelationships(
    allocator: std.mem.Allocator,
    arena: []const u8,
    entries: []Entry,
) !Relationships {
    if (entries.len == 0) {
        return .{
            .children = try allocator.alloc(u32, 0),
            .roots = try allocator.alloc(u32, 0),
        };
    }
    var by_path = std.StringHashMap(u32).init(allocator);
    defer by_path.deinit();
    try by_path.ensureTotalCapacity(@intCast(entries.len));
    for (entries, 0..) |entry, index|
        by_path.putAssumeCapacity(pathFrom(arena, entry), @intCast(index));

    const counts = try allocator.alloc(u32, entries.len);
    defer allocator.free(counts);
    @memset(counts, 0);
    var child_total: usize = 0;
    var root_total: usize = 0;
    for (entries) |*entry| {
        const parent_path = std.fs.path.dirname(pathFrom(arena, entry.*)) orelse {
            root_total += 1;
            continue;
        };
        if (parent_path.len == 0) {
            root_total += 1;
            continue;
        }
        entry.parent_index = by_path.get(parent_path) orelse {
            root_total += 1;
            continue;
        };
        counts[entry.parent_index] += 1;
        child_total += 1;
    }

    var offset: u32 = 0;
    for (entries, counts) |*entry, count| {
        entry.first_child = offset;
        entry.child_count = count;
        offset += count;
    }
    const children = try allocator.alloc(u32, child_total);
    errdefer allocator.free(children);
    const roots = try allocator.alloc(u32, root_total);
    errdefer allocator.free(roots);
    const cursors = try allocator.alloc(u32, entries.len);
    defer allocator.free(cursors);
    for (entries, 0..) |entry, index| cursors[index] = entry.first_child;
    var root_index: usize = 0;
    for (entries, 0..) |entry, index| {
        if (entry.parent_index == no_parent) {
            roots[root_index] = @intCast(index);
            root_index += 1;
            continue;
        }
        const destination = cursors[entry.parent_index];
        children[destination] = @intCast(index);
        cursors[entry.parent_index] += 1;
    }
    return .{ .children = children, .roots = roots };
}

fn pathFrom(arena: []const u8, entry: Entry) []const u8 {
    const start: usize = entry.path_offset;
    return arena[start .. start + entry.path_length];
}

fn shouldSkip(name: []const u8, kind: std.Io.File.Kind) bool {
    if (kind != .directory) return false;
    return std.mem.eql(u8, name, ".git") or
        std.mem.eql(u8, name, ".zig-cache") or
        std.mem.eql(u8, name, "zig-out") or
        std.mem.eql(u8, name, "node_modules") or
        std.mem.eql(u8, name, "target") or
        std.mem.eql(u8, name, "dist") or
        std.mem.eql(u8, name, "build") or
        std.mem.eql(u8, name, "vendor") or
        std.mem.eql(u8, name, "__pycache__");
}

fn lessThan(arena: []u8, lhs: Entry, rhs: Entry) bool {
    return std.mem.lessThan(u8, pathFrom(arena, lhs), pathFrom(arena, rhs));
}

fn pathBoundaryMask(path: []const u8) u64 {
    var mask: u64 = 1;
    for (path, 0..) |byte, index| {
        if (index >= 64) break;
        const previous = if (index == 0) '/' else path[index - 1];
        if (index == 0 or previous == '/' or previous == '_' or
            previous == '-' or previous == '.' or
            (previous >= 'a' and previous <= 'z' and byte >= 'A' and byte <= 'Z'))
            mask |= @as(u64, 1) << @intCast(index);
    }
    return mask;
}

pub fn fromEntriesAlloc(
    allocator: std.mem.Allocator,
    input: []const InputEntry,
    truncated: bool,
) !Index {
    if (input.len > max_entries) return error.TooManyProjectEntries;
    var arena = std.array_list.Managed(u8).init(allocator);
    defer arena.deinit();
    var entries = std.array_list.Managed(Entry).init(allocator);
    defer entries.deinit();
    try entries.ensureTotalCapacity(input.len);
    for (input) |candidate| {
        if (arena.items.len + candidate.path.len > std.math.maxInt(u32))
            return error.ProjectPathArenaTooLarge;
        const offset = arena.items.len;
        try arena.appendSlice(candidate.path);
        entries.appendAssumeCapacity(.{
            .path_offset = @intCast(offset),
            .path_length = @intCast(candidate.path.len),
            .basename_offset = @intCast(candidate.path.len - std.fs.path.basename(candidate.path).len),
            .boundary_mask = pathBoundaryMask(candidate.path),
            .kind = candidate.kind,
        });
    }
    std.sort.heap(Entry, entries.items, arena.items, lessThan);
    const owned_arena = try arena.toOwnedSlice();
    errdefer allocator.free(owned_arena);
    const owned_entries = try entries.toOwnedSlice();
    errdefer allocator.free(owned_entries);
    const relationships = try buildRelationships(allocator, owned_arena, owned_entries);
    errdefer relationships.deinit(allocator);
    const storage = try allocator.create(Storage);
    storage.* = .{
        .arena = owned_arena,
        .entries = owned_entries,
        .children = relationships.children,
        .roots = relationships.roots,
    };
    return .{
        .storage = storage,
        .entries = storage.entries,
        .truncated = truncated,
    };
}

/// Applies precise monitor events without walking the unchanged worktree.
/// Ignore-file mutations and malformed/ambiguous paths deliberately request a
/// full rescan so the caller never publishes a guessed index.
pub fn applyFilesystemChangesAlloc(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: []const u8,
    current: Index,
    changes: []const FilesystemChange,
) !DeltaResult {
    if (changes.len == 0) return .{ .index = current.retain(), .stats = .{} };
    if (changes.len > max_filesystem_changes)
        return error.ProjectDeltaRequiresRescan;

    var directory = try std.Io.Dir.openDirAbsolute(io, root, .{ .iterate = true });
    defer directory.close(io);
    var entries = std.StringHashMap(EntryKind).init(allocator);
    defer {
        var iterator = entries.iterator();
        while (iterator.next()) |item| allocator.free(item.key_ptr.*);
        entries.deinit();
    }
    try entries.ensureTotalCapacity(@intCast(current.entries.len));
    for (current.entries) |entry| {
        const path_value = try allocator.dupe(u8, current.path(entry));
        errdefer allocator.free(path_value);
        try entries.put(path_value, entry.kind);
    }

    var stats = DeltaStats{ .events = changes.len };
    var truncated = current.truncated;
    for (changes) |change| {
        try validateDeltaPath(change.path);
        if (isIgnoreControlPath(change.path)) return error.ProjectDeltaRequiresRescan;
        switch (change.kind) {
            .deleted, .moved_out => {
                stats.removed_entries += try removeSubtreeAlloc(
                    allocator,
                    &entries,
                    change.path,
                );
            },
            .created, .moved_in => {
                stats.removed_entries += try removeSubtreeAlloc(
                    allocator,
                    &entries,
                    change.path,
                );
                const added = try refreshPathAlloc(
                    allocator,
                    io,
                    directory,
                    change.path,
                    &entries,
                    &truncated,
                );
                stats.added_entries += added;
                stats.refreshed_paths += 1;
            },
            .renamed => {
                const destination = change.other_path orelse
                    return error.ProjectDeltaRequiresRescan;
                try validateDeltaPath(destination);
                if (isIgnoreControlPath(destination))
                    return error.ProjectDeltaRequiresRescan;
                stats.removed_entries += try removeSubtreeAlloc(
                    allocator,
                    &entries,
                    change.path,
                );
                stats.removed_entries += try removeSubtreeAlloc(
                    allocator,
                    &entries,
                    destination,
                );
                const added = try refreshPathAlloc(
                    allocator,
                    io,
                    directory,
                    destination,
                    &entries,
                    &truncated,
                );
                stats.added_entries += added;
                stats.refreshed_paths += 1;
            },
        }
    }

    if (entries.count() > max_entries) return error.ProjectDeltaRequiresRescan;
    const input = try allocator.alloc(InputEntry, entries.count());
    defer allocator.free(input);
    var iterator = entries.iterator();
    var input_index: usize = 0;
    while (iterator.next()) |item| : (input_index += 1) {
        input[input_index] = .{
            .path = item.key_ptr.*,
            .kind = item.value_ptr.*,
        };
    }
    return .{
        .index = try fromEntriesAlloc(allocator, input, truncated),
        .stats = stats,
    };
}

fn validateDeltaPath(path_value: []const u8) !void {
    if (path_value.len == 0 or std.fs.path.isAbsolute(path_value) or
        path_value[0] == std.fs.path.sep or
        path_value[path_value.len - 1] == std.fs.path.sep)
        return error.ProjectDeltaRequiresRescan;
    var components = std.mem.splitScalar(u8, path_value, std.fs.path.sep);
    while (components.next()) |component| {
        if (component.len == 0 or std.mem.eql(u8, component, ".") or
            std.mem.eql(u8, component, ".."))
            return error.ProjectDeltaRequiresRescan;
    }
}

fn isIgnoreControlPath(path_value: []const u8) bool {
    const basename = std.fs.path.basename(path_value);
    return std.mem.eql(u8, basename, ".gitignore") or
        std.mem.eql(u8, basename, ".ignore");
}

fn pathIsSubtree(path_value: []const u8, prefix: []const u8) bool {
    return std.mem.eql(u8, path_value, prefix) or
        (path_value.len > prefix.len and
            std.mem.startsWith(u8, path_value, prefix) and
            path_value[prefix.len] == std.fs.path.sep);
}

fn removeSubtreeAlloc(
    allocator: std.mem.Allocator,
    entries: *std.StringHashMap(EntryKind),
    prefix: []const u8,
) !usize {
    var removals = std.array_list.Managed([]const u8).init(allocator);
    defer removals.deinit();
    var iterator = entries.iterator();
    while (iterator.next()) |item| {
        if (pathIsSubtree(item.key_ptr.*, prefix))
            try removals.append(item.key_ptr.*);
    }
    for (removals.items) |path_value| {
        const removed = entries.fetchRemove(path_value) orelse continue;
        allocator.free(removed.key);
    }
    return removals.items.len;
}

fn refreshPathAlloc(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    relative_path: []const u8,
    entries: *std.StringHashMap(EntryKind),
    truncated: *bool,
) !usize {
    const stat = root.statFile(io, relative_path, .{ .follow_symlinks = false }) catch |err| switch (err) {
        error.FileNotFound => return 0,
        else => return err,
    };
    const kind: EntryKind = switch (stat.kind) {
        .directory => .directory,
        .file => .file,
        else => return 0,
    };
    if (pathDepth(relative_path) > max_depth) return 0;

    var matcher = ignore.Matcher.init(allocator);
    defer matcher.deinit();
    if (!try loadAncestorIgnoreRules(&matcher, root, io, relative_path)) return 0;
    if (kind == .directory and shouldSkip(std.fs.path.basename(relative_path), .directory))
        return 0;
    if (matcher.isIgnored(relative_path, kind == .directory)) return 0;

    var added = try putEntryAlloc(allocator, entries, relative_path, kind);
    if (kind == .file) {
        truncated.* = truncated.* or matcher.truncated;
        return added;
    }

    try matcher.loadDirectory(root, io, relative_path);
    var subtree = try root.openDir(io, relative_path, .{ .iterate = true });
    defer subtree.close(io);
    var walker = try subtree.walkSelectively(allocator);
    defer walker.deinit();
    while (try walker.next(io)) |candidate| {
        const supported = candidate.kind == .directory or candidate.kind == .file;
        if (!supported) continue;
        const full_path = try std.fs.path.join(allocator, &.{ relative_path, candidate.path });
        defer allocator.free(full_path);
        const depth = pathDepth(full_path);
        const skip = shouldSkip(candidate.basename, candidate.kind) or
            matcher.isIgnored(full_path, candidate.kind == .directory) or
            depth > max_depth;
        if (!skip) {
            if (entries.count() >= max_entries)
                return error.ProjectDeltaRequiresRescan;
            added += try putEntryAlloc(
                allocator,
                entries,
                full_path,
                if (candidate.kind == .directory) .directory else .file,
            );
        }
        if (!skip and candidate.kind == .directory and depth < max_depth) {
            try matcher.loadDirectory(root, io, full_path);
            try walker.enter(io, candidate);
        }
    }
    truncated.* = truncated.* or matcher.truncated;
    return added;
}

fn loadAncestorIgnoreRules(
    matcher: *ignore.Matcher,
    root: std.Io.Dir,
    io: std.Io,
    relative_path: []const u8,
) !bool {
    try matcher.loadDirectory(root, io, "");
    const parent = std.fs.path.dirname(relative_path) orelse return true;
    if (parent.len == 0) return true;
    var base = std.array_list.Managed(u8).init(matcher.allocator);
    defer base.deinit();
    var components = std.mem.splitScalar(u8, parent, std.fs.path.sep);
    while (components.next()) |component| {
        if (base.items.len != 0) try base.append(std.fs.path.sep);
        try base.appendSlice(component);
        if (shouldSkip(component, .directory) or matcher.isIgnored(base.items, true))
            return false;
        try matcher.loadDirectory(root, io, base.items);
    }
    return true;
}

fn pathDepth(path_value: []const u8) usize {
    if (path_value.len == 0) return 0;
    return std.mem.count(u8, path_value, &.{std.fs.path.sep}) + 1;
}

fn putEntryAlloc(
    allocator: std.mem.Allocator,
    entries: *std.StringHashMap(EntryKind),
    path_value: []const u8,
    kind: EntryKind,
) !usize {
    if (entries.getPtr(path_value)) |existing| {
        existing.* = kind;
        return 0;
    }
    const owned = try allocator.dupe(u8, path_value);
    errdefer allocator.free(owned);
    try entries.put(owned, kind);
    return 1;
}

test "project index is compact hierarchical and prunes generated trees" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.createDirPath(io, "src/app");
    try tmp.dir.createDirPath(io, ".zig-cache/o");
    try tmp.dir.createDirPath(io, "vendor/dependency");
    try tmp.dir.writeFile(io, .{ .sub_path = "README.md", .data = "readme" });
    try tmp.dir.writeFile(io, .{ .sub_path = "src/app/main.zig", .data = "const x = 1;" });
    try tmp.dir.writeFile(io, .{ .sub_path = ".zig-cache/o/cache", .data = "cache" });
    try tmp.dir.writeFile(io, .{ .sub_path = "vendor/dependency/file", .data = "vendor" });
    var root_buffer: [std.fs.max_path_bytes]u8 = undefined;
    const root_length = try tmp.dir.realPath(io, &root_buffer);

    var index = try scanAlloc(allocator, io, root_buffer[0..root_length]);
    defer index.deinit(allocator);
    try std.testing.expect(!index.truncated);
    try std.testing.expect(index.entries.len >= 4);
    for (index.entries) |entry| {
        const path_value = index.path(entry);
        try std.testing.expect(!std.mem.startsWith(u8, path_value, ".zig-cache"));
        try std.testing.expect(!std.mem.startsWith(u8, path_value, "vendor"));
    }
    try std.testing.expect(index.memoryBytes() < index.entries.len * (std.fs.max_path_bytes + 32));
    try std.testing.expect(index.rootIndices().len >= 2);
    const main_index = index.findPath("src/app/main.zig") orelse
        return error.ExpectedIndexedPath;
    try std.testing.expectEqualStrings("main.zig", index.basename(index.entries[main_index]));
    try std.testing.expectEqual(@as(?usize, null), index.findPath("missing.zig"));
}

test "project scanner advances within an explicit visit budget" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(io, .{ .sub_path = "a", .data = "a" });
    try tmp.dir.writeFile(io, .{ .sub_path = "b", .data = "b" });
    var root_buffer: [std.fs.max_path_bytes]u8 = undefined;
    const root_length = try tmp.dir.realPath(io, &root_buffer);

    var scanner = try Scanner.init(allocator, io, root_buffer[0..root_length]);
    defer scanner.deinit();
    try std.testing.expectEqual(ScanProgress.pending, try scanner.step(1));
    try std.testing.expect(scanner.entries.items.len <= 1);
    while (try scanner.step(1) == .pending) {}
    var index = try scanner.takeIndex();
    defer index.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 2), index.entries.len);
}

test "project scanner applies root and directory scoped ignore files" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.createDirPath(io, "src/nested");
    try tmp.dir.writeFile(io, .{
        .sub_path = ".gitignore",
        .data = "*.tmp\nignored/\n",
    });
    try tmp.dir.writeFile(io, .{
        .sub_path = "src/.ignore",
        .data = "generated*.zig\n!generated_keep.zig\n",
    });
    try tmp.dir.writeFile(io, .{ .sub_path = "root.tmp", .data = "ignored" });
    try tmp.dir.writeFile(io, .{ .sub_path = "src/generated1.zig", .data = "ignored" });
    try tmp.dir.writeFile(io, .{ .sub_path = "src/generated_keep.zig", .data = "kept" });
    try tmp.dir.writeFile(io, .{ .sub_path = "src/nested/main.zig", .data = "kept" });
    var root_buffer: [std.fs.max_path_bytes]u8 = undefined;
    const root_length = try tmp.dir.realPath(io, &root_buffer);

    var index = try scanAlloc(allocator, io, root_buffer[0..root_length]);
    defer index.deinit(allocator);
    try std.testing.expectEqual(@as(?usize, null), index.findPath("root.tmp"));
    try std.testing.expectEqual(@as(?usize, null), index.findPath("src/generated1.zig"));
    try std.testing.expect(index.findPath("src/generated_keep.zig") != null);
    try std.testing.expect(index.findPath("src/nested/main.zig") != null);
}

test "project index retention shares one immutable arena" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.createDirPath(io, "src");
    try tmp.dir.writeFile(io, .{ .sub_path = "src/main.zig", .data = "const x = 1;" });
    var root_buffer: [std.fs.max_path_bytes]u8 = undefined;
    const root_length = try tmp.dir.realPath(io, &root_buffer);
    var source = try scanAlloc(allocator, io, root_buffer[0..root_length]);
    defer source.deinit(allocator);
    var retained = source.retain();
    defer retained.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 2), source.retainedCount());
    try std.testing.expectEqual(source.storage, retained.storage);
    try std.testing.expectEqualStrings(source.pathAt(1), retained.pathAt(1));
}

test "filesystem delta refreshes created deleted and renamed subtrees" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.createDirPath(io, "src/old");
    try tmp.dir.writeFile(io, .{ .sub_path = "src/old/main.zig", .data = "old" });
    try tmp.dir.writeFile(io, .{ .sub_path = "src/remove.zig", .data = "remove" });
    var root_buffer: [std.fs.max_path_bytes]u8 = undefined;
    const root_length = try tmp.dir.realPath(io, &root_buffer);

    var initial = try scanAlloc(allocator, io, root_buffer[0..root_length]);
    defer initial.deinit(allocator);
    try tmp.dir.rename("src/old", tmp.dir, "src/renamed", io);
    try tmp.dir.deleteFile(io, "src/remove.zig");
    try tmp.dir.createDirPath(io, "generated/nested");
    try tmp.dir.writeFile(io, .{
        .sub_path = "generated/nested/new.zig",
        .data = "new",
    });

    const changes = [_]FilesystemChange{
        .{ .kind = .renamed, .path = "src/old", .other_path = "src/renamed" },
        .{ .kind = .deleted, .path = "src/remove.zig" },
        .{ .kind = .created, .path = "generated" },
    };
    var delta = try applyFilesystemChangesAlloc(
        allocator,
        io,
        root_buffer[0..root_length],
        initial,
        &changes,
    );
    defer delta.index.deinit(allocator);
    try std.testing.expectEqual(@as(?usize, null), delta.index.findPath("src/old"));
    try std.testing.expectEqual(@as(?usize, null), delta.index.findPath("src/old/main.zig"));
    try std.testing.expect(delta.index.findPath("src/renamed") != null);
    try std.testing.expect(delta.index.findPath("src/renamed/main.zig") != null);
    try std.testing.expectEqual(@as(?usize, null), delta.index.findPath("src/remove.zig"));
    try std.testing.expect(delta.index.findPath("generated/nested/new.zig") != null);
    try std.testing.expectEqual(@as(usize, changes.len), delta.stats.events);
    try std.testing.expectEqual(@as(usize, 2), delta.stats.refreshed_paths);
    try std.testing.expect(delta.stats.removed_entries >= 3);
    try std.testing.expect(delta.stats.added_entries >= 5);
}

test "filesystem delta honors inherited ignores and rejects ignore mutations" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.createDirPath(io, "src");
    try tmp.dir.writeFile(io, .{ .sub_path = ".gitignore", .data = "*.tmp\n" });
    var root_buffer: [std.fs.max_path_bytes]u8 = undefined;
    const root_length = try tmp.dir.realPath(io, &root_buffer);
    var initial = try scanAlloc(allocator, io, root_buffer[0..root_length]);
    defer initial.deinit(allocator);
    try tmp.dir.writeFile(io, .{ .sub_path = "src/ignored.tmp", .data = "ignored" });
    try tmp.dir.writeFile(io, .{ .sub_path = "src/kept.zig", .data = "kept" });

    const changes = [_]FilesystemChange{
        .{ .kind = .created, .path = "src/ignored.tmp" },
        .{ .kind = .created, .path = "src/kept.zig" },
    };
    var delta = try applyFilesystemChangesAlloc(
        allocator,
        io,
        root_buffer[0..root_length],
        initial,
        &changes,
    );
    defer delta.index.deinit(allocator);
    try std.testing.expectEqual(@as(?usize, null), delta.index.findPath("src/ignored.tmp"));
    try std.testing.expect(delta.index.findPath("src/kept.zig") != null);

    const ignore_change = [_]FilesystemChange{
        .{ .kind = .created, .path = "src/.ignore" },
    };
    try std.testing.expectError(
        error.ProjectDeltaRequiresRescan,
        applyFilesystemChangesAlloc(
            allocator,
            io,
            root_buffer[0..root_length],
            initial,
            &ignore_change,
        ),
    );
}
