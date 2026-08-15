const std = @import("std");
const builtin = @import("builtin");

pub const editable_byte_limit: usize = 1024 * 1024;
pub const preview_byte_limit: usize = 8 * 1024 * 1024;
pub const max_stable_read_attempts: usize = 3;
pub const direct_tree_sitter_byte_limit: usize = 32 * 1024;

pub fn useDirectTreeSitter(size_bytes: usize) bool {
    return size_bytes <= direct_tree_sitter_byte_limit;
}

pub const Mode = enum {
    editable,
    read_only_preview,
};

pub const FileIdentity = struct {
    device: u64,
    inode: u64,
    size: u64,
    mtime_ns: i128,

    pub fn eql(lhs: FileIdentity, rhs: FileIdentity) bool {
        return lhs.device == rhs.device and lhs.inode == rhs.inode and
            lhs.size == rhs.size and lhs.mtime_ns == rhs.mtime_ns;
    }
};

pub const LoadedFile = struct {
    path: [:0]u8,
    contents: []u8,
    mode: Mode,
    identity: FileIdentity,

    pub fn deinit(self: *LoadedFile, allocator: std.mem.Allocator) void {
        allocator.free(self.path);
        allocator.free(self.contents);
        self.* = undefined;
    }
};

pub fn loadFileAlloc(
    allocator: std.mem.Allocator,
    io: std.Io,
    path: []const u8,
) !LoadedFile {
    return loadFileAllocObserved(allocator, io, path, null);
}

const LoadObserver = struct {
    context: *anyopaque,
    after_read: *const fn (*anyopaque, std.Io, []const u8, usize) anyerror!void,
};

fn loadFileAllocObserved(
    allocator: std.mem.Allocator,
    io: std.Io,
    path: []const u8,
    observer: ?LoadObserver,
) !LoadedFile {
    if (path.len == 0) return error.InvalidDocumentPath;
    const canonical_path = try std.Io.Dir.cwd().realPathFileAlloc(
        io,
        path,
        allocator,
    );
    errdefer allocator.free(canonical_path);
    for (0..max_stable_read_attempts) |attempt| {
        const stat = try std.Io.Dir.cwd().statFile(io, canonical_path, .{});
        if (stat.kind != .file) return error.InvalidDocumentFile;
        const size = std.math.cast(usize, stat.size) orelse
            return error.DocumentTooLarge;
        if (size > preview_byte_limit) return error.DocumentTooLarge;
        const identity_before = try identityForPath(io, canonical_path);
        if (identity_before.size != stat.size) {
            if (attempt + 1 == max_stable_read_attempts)
                return error.DocumentChangedDuringRead;
            continue;
        }

        const contents = std.Io.Dir.cwd().readFileAlloc(
            io,
            canonical_path,
            allocator,
            .limited(preview_byte_limit + 1),
        ) catch |err| switch (err) {
            error.StreamTooLong => {
                const current = identityForPath(io, canonical_path) catch
                    return error.DocumentChangedDuringRead;
                if (current.size > preview_byte_limit) return error.DocumentTooLarge;
                if (attempt + 1 == max_stable_read_attempts)
                    return error.DocumentChangedDuringRead;
                continue;
            },
            else => return err,
        };
        var keep_contents = false;
        defer if (!keep_contents) allocator.free(contents);
        if (observer) |value|
            try value.after_read(value.context, io, canonical_path, attempt);
        const identity_after = identityForPath(io, canonical_path) catch {
            if (attempt + 1 == max_stable_read_attempts)
                return error.DocumentChangedDuringRead;
            continue;
        };
        if (!identity_before.eql(identity_after) or
            contents.len != identity_after.size)
        {
            if (attempt + 1 == max_stable_read_attempts)
                return error.DocumentChangedDuringRead;
            continue;
        }
        const mode = try classifyContents(contents);
        keep_contents = true;
        return .{
            .path = canonical_path,
            .contents = contents,
            .mode = mode,
            .identity = identity_after,
        };
    }
    unreachable;
}

fn classifyContents(contents: []const u8) !Mode {
    if (contents.len > preview_byte_limit) return error.DocumentTooLarge;
    if (!std.unicode.utf8ValidateSlice(contents)) return error.InvalidUtf8;
    if (std.mem.indexOfScalar(u8, contents, 0) != null)
        return error.UnsupportedNul;
    return if (contents.len <= editable_byte_limit)
        .editable
    else
        .read_only_preview;
}

pub fn identityForPath(io: std.Io, path: [:0]const u8) !FileIdentity {
    if (builtin.os.tag == .linux) {
        const linux = std.os.linux;
        var statx: linux.Statx = undefined;
        const result = linux.statx(
            linux.AT.FDCWD,
            path.ptr,
            0,
            linux.STATX.BASIC_STATS,
            &statx,
        );
        if (linux.errno(result) != .SUCCESS) return error.FileIdentityUnavailable;
        return .{
            .device = (@as(u64, statx.dev_major) << 32) | statx.dev_minor,
            .inode = statx.ino,
            .size = statx.size,
            .mtime_ns = @as(i128, statx.mtime.sec) * std.time.ns_per_s +
                statx.mtime.nsec,
        };
    }
    const stat = try std.Io.Dir.cwd().statFile(io, path, .{});
    return .{
        .device = 0,
        .inode = @bitCast(stat.inode),
        .size = stat.size,
        .mtime_ns = stat.mtime.nanoseconds,
    };
}

pub fn saveFileAtomic(io: std.Io, path: []const u8, contents: []const u8) !void {
    if (path.len == 0) return error.InvalidDocumentPath;
    if (!std.unicode.utf8ValidateSlice(contents)) return error.InvalidUtf8;
    if (std.mem.indexOfScalar(u8, contents, 0) != null)
        return error.UnsupportedNul;
    const permissions = if (std.Io.Dir.cwd().statFile(io, path, .{})) |stat| blk: {
        if (stat.kind != .file) return error.InvalidDocumentFile;
        break :blk stat.permissions;
    } else |err| switch (err) {
        error.FileNotFound => std.Io.File.Permissions.default_file,
        else => return err,
    };
    var atomic = try std.Io.Dir.cwd().createFileAtomic(io, path, .{
        .permissions = permissions,
        .make_path = false,
        .replace = true,
    });
    defer atomic.deinit(io);
    try atomic.file.writeStreamingAll(io, contents);
    try atomic.replace(io);
}

pub fn resolveSavePathAlloc(
    allocator: std.mem.Allocator,
    io: std.Io,
    requested_path: []const u8,
) ![:0]u8 {
    if (requested_path.len == 0 or
        std.mem.indexOfScalar(u8, requested_path, 0) != null)
        return error.InvalidDocumentPath;
    const resolved = try std.fs.path.resolve(allocator, &.{requested_path});
    defer allocator.free(resolved);

    if (std.Io.Dir.cwd().statFile(io, resolved, .{})) |stat| {
        if (stat.kind != .file) return error.InvalidDocumentFile;
        return std.Io.Dir.cwd().realPathFileAlloc(io, resolved, allocator);
    } else |err| switch (err) {
        error.FileNotFound => {},
        else => return err,
    }
    if (std.Io.Dir.cwd().statFile(io, resolved, .{ .follow_symlinks = false })) |stat| {
        if (stat.kind == .sym_link) return error.DanglingDocumentSymlink;
        return error.InvalidDocumentFile;
    } else |err| switch (err) {
        error.FileNotFound => {},
        else => return err,
    }

    const parent_path = std.fs.path.dirname(resolved) orelse
        return error.InvalidDocumentPath;
    const basename = std.fs.path.basename(resolved);
    if (basename.len == 0 or std.mem.eql(u8, basename, ".") or
        std.mem.eql(u8, basename, ".."))
        return error.InvalidDocumentPath;
    var parent = try std.Io.Dir.openDirAbsolute(io, parent_path, .{});
    defer parent.close(io);
    var canonical_parent_buffer: [std.fs.max_path_bytes]u8 = undefined;
    const canonical_parent_length = try parent.realPath(io, &canonical_parent_buffer);
    const joined = try std.fs.path.join(
        allocator,
        &.{ canonical_parent_buffer[0..canonical_parent_length], basename },
    );
    defer allocator.free(joined);
    return allocator.dupeZ(u8, joined);
}

test "loads editable UTF-8 and writes it back atomically" {
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(io, .{
        .sub_path = "sample.zig",
        .data = "const before = true;\n",
        .flags = .{ .permissions = .executable_file },
    });

    const absolute = try tmp.dir.realPathFileAlloc(io, "sample.zig", std.testing.allocator);
    defer std.testing.allocator.free(absolute);
    var loaded = try loadFileAlloc(std.testing.allocator, io, absolute);
    defer loaded.deinit(std.testing.allocator);
    try std.testing.expectEqual(Mode.editable, loaded.mode);
    try std.testing.expectEqualStrings("const before = true;\n", loaded.contents);
    try std.testing.expect(loaded.identity.inode != 0);
    try std.testing.expectEqual(@as(u64, loaded.contents.len), loaded.identity.size);

    const before = try tmp.dir.statFile(io, "sample.zig", .{});
    try saveFileAtomic(io, absolute, "const after = true;\n");
    const after = try tmp.dir.statFile(io, "sample.zig", .{});
    try std.testing.expectEqual(before.permissions, after.permissions);
    const saved = try tmp.dir.readFileAlloc(io, "sample.zig", std.testing.allocator, .limited(128));
    defer std.testing.allocator.free(saved);
    try std.testing.expectEqualStrings("const after = true;\n", saved);
    const after_identity = try identityForPath(io, absolute);
    try std.testing.expectEqual(@as(u64, saved.len), after_identity.size);
}

test "rejects non UTF-8 and files above the preview limit" {
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(io, .{ .sub_path = "binary", .data = &.{ 0xff, 0xfe } });
    try tmp.dir.writeFile(io, .{ .sub_path = "nul", .data = "text\x00data" });
    const binary = try tmp.dir.realPathFileAlloc(io, "binary", std.testing.allocator);
    defer std.testing.allocator.free(binary);
    try std.testing.expectError(
        error.InvalidUtf8,
        loadFileAlloc(std.testing.allocator, io, binary),
    );
    const nul = try tmp.dir.realPathFileAlloc(io, "nul", std.testing.allocator);
    defer std.testing.allocator.free(nul);
    try std.testing.expectError(
        error.UnsupportedNul,
        loadFileAlloc(std.testing.allocator, io, nul),
    );
    try std.testing.expectError(
        error.UnsupportedNul,
        saveFileAtomic(io, nul, "text\x00data"),
    );

    const oversized = try std.testing.allocator.alloc(u8, preview_byte_limit + 1);
    defer std.testing.allocator.free(oversized);
    @memset(oversized, 'x');
    try tmp.dir.writeFile(io, .{ .sub_path = "oversized", .data = oversized });
    const oversized_path = try tmp.dir.realPathFileAlloc(io, "oversized", std.testing.allocator);
    defer std.testing.allocator.free(oversized_path);
    try std.testing.expectError(
        error.DocumentTooLarge,
        loadFileAlloc(std.testing.allocator, io, oversized_path),
    );
}

test "direct Tree-sitter highlighting stays within the main-thread budget" {
    try std.testing.expect(useDirectTreeSitter(direct_tree_sitter_byte_limit));
    try std.testing.expect(!useDirectTreeSitter(direct_tree_sitter_byte_limit + 1));
}

test "deterministic invalid-file corpus stays bounded and classified" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var random_state: u64 = 0x6e6f_6374_7479_3130;
    var accepted: usize = 0;
    var invalid_utf8: usize = 0;
    var rejected_nul: usize = 0;

    for (0..256) |case_index| {
        random_state ^= random_state << 13;
        random_state ^= random_state >> 7;
        random_state ^= random_state << 17;
        const length: usize = @intCast(random_state % 97);
        const contents = try allocator.alloc(u8, length);
        defer allocator.free(contents);
        switch (case_index % 4) {
            0 => @memset(contents, 'a'),
            1 => for (contents) |*byte| {
                random_state ^= random_state << 13;
                random_state ^= random_state >> 7;
                random_state ^= random_state << 17;
                byte.* = @truncate(random_state);
            },
            2 => {
                @memset(contents, 'u');
                if (contents.len >= 2) {
                    contents[0] = 0xc3;
                    contents[1] = 0xa9;
                }
            },
            3 => {
                @memset(contents, 'n');
                if (contents.len != 0) contents[contents.len / 2] = 0;
            },
            else => unreachable,
        }
        var name_buffer: [32]u8 = undefined;
        const name = try std.fmt.bufPrint(&name_buffer, "case-{d}", .{case_index});
        try tmp.dir.writeFile(io, .{ .sub_path = name, .data = contents });
        const path = try tmp.dir.realPathFileAlloc(io, name, allocator);
        defer allocator.free(path);

        if (loadFileAlloc(allocator, io, path)) |loaded_value| {
            var loaded = loaded_value;
            defer loaded.deinit(allocator);
            try std.testing.expect(std.unicode.utf8ValidateSlice(contents));
            try std.testing.expect(std.mem.indexOfScalar(u8, contents, 0) == null);
            try std.testing.expectEqualStrings(contents, loaded.contents);
            accepted += 1;
        } else |err| {
            if (!std.unicode.utf8ValidateSlice(contents)) {
                try std.testing.expectEqual(error.InvalidUtf8, err);
                invalid_utf8 += 1;
            } else if (std.mem.indexOfScalar(u8, contents, 0) != null) {
                try std.testing.expectEqual(error.UnsupportedNul, err);
                rejected_nul += 1;
            } else {
                return err;
            }
        }
    }
    try std.testing.expect(accepted >= 128);
    try std.testing.expect(invalid_utf8 > 0);
    try std.testing.expect(rejected_nul > 0);
}

test "external rewrite during read retries to one stable generation" {
    const RewriteOnce = struct {
        fired: bool = false,

        fn afterRead(raw: *anyopaque, io: std.Io, path: []const u8, _: usize) !void {
            const self: *@This() = @ptrCast(@alignCast(raw));
            if (self.fired) return;
            self.fired = true;
            try std.Io.Dir.cwd().writeFile(io, .{
                .sub_path = path,
                .data = "const generation = 2;\n",
            });
        }
    };
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(io, .{
        .sub_path = "race.zig",
        .data = "const generation = 1;\n",
    });
    const path = try tmp.dir.realPathFileAlloc(io, "race.zig", allocator);
    defer allocator.free(path);
    var context = RewriteOnce{};
    var loaded = try loadFileAllocObserved(allocator, io, path, .{
        .context = &context,
        .after_read = RewriteOnce.afterRead,
    });
    defer loaded.deinit(allocator);
    try std.testing.expect(context.fired);
    try std.testing.expectEqualStrings("const generation = 2;\n", loaded.contents);
    const current = try identityForPath(io, loaded.path);
    try std.testing.expect(loaded.identity.eql(current));
}

test "continuous external churn stops at the stable-read cap" {
    const RewriteEveryTime = struct {
        rewrites: usize = 0,

        fn afterRead(raw: *anyopaque, io: std.Io, path: []const u8, attempt: usize) !void {
            const self: *@This() = @ptrCast(@alignCast(raw));
            self.rewrites += 1;
            var buffer: [96]u8 = undefined;
            var writer = std.Io.Writer.fixed(&buffer);
            try writer.print("generation-{d}-", .{attempt});
            try writer.splatByteAll('x', attempt + 1);
            try writer.writeByte('\n');
            try std.Io.Dir.cwd().writeFile(io, .{
                .sub_path = path,
                .data = writer.buffered(),
            });
        }
    };
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(io, .{ .sub_path = "churn", .data = "generation-0\n" });
    const path = try tmp.dir.realPathFileAlloc(io, "churn", allocator);
    defer allocator.free(path);
    var context = RewriteEveryTime{};
    try std.testing.expectError(
        error.DocumentChangedDuringRead,
        loadFileAllocObserved(allocator, io, path, .{
            .context = &context,
            .after_read = RewriteEveryTime.afterRead,
        }),
    );
    try std.testing.expectEqual(max_stable_read_attempts, context.rewrites);
}

test "resolves save targets and creates a first file atomically" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var root_buffer: [std.fs.max_path_bytes]u8 = undefined;
    const root_length = try tmp.dir.realPath(io, &root_buffer);
    const requested = try std.fs.path.join(
        allocator,
        &.{ root_buffer[0..root_length], "created.zig" },
    );
    defer allocator.free(requested);
    const resolved = try resolveSavePathAlloc(allocator, io, requested);
    defer allocator.free(resolved);
    try std.testing.expectEqualStrings(requested, resolved);
    try saveFileAtomic(io, resolved, "const created = true;\n");
    const saved = try tmp.dir.readFileAlloc(
        io,
        "created.zig",
        allocator,
        .limited(128),
    );
    defer allocator.free(saved);
    try std.testing.expectEqualStrings("const created = true;\n", saved);

    const existing = try resolveSavePathAlloc(allocator, io, requested);
    defer allocator.free(existing);
    try std.testing.expectEqualStrings(resolved, existing);
    try std.testing.expectError(
        error.InvalidDocumentFile,
        resolveSavePathAlloc(allocator, io, root_buffer[0..root_length]),
    );
}
