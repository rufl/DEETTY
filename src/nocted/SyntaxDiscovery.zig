const std = @import("std");

pub const Candidate = struct {
    path: []u8,
    additional_specs: usize,

    pub fn deinit(self: *Candidate, allocator: std.mem.Allocator) void {
        allocator.free(self.path);
        self.* = undefined;
    }
};

pub fn countLanguageSpecs(io: std.Io, path: []const u8) !usize {
    var directory = try std.Io.Dir.openDirAbsolute(io, path, .{ .iterate = true });
    defer directory.close(io);
    var iterator = directory.iterate();
    var count: usize = 0;
    while (try iterator.next(io)) |entry| {
        if (entry.kind != .file or !std.mem.endsWith(u8, entry.name, ".lang"))
            continue;
        count += 1;
    }
    return count;
}

pub fn countAdditionalLanguageSpecs(
    allocator: std.mem.Allocator,
    io: std.Io,
    candidate_path: []const u8,
    baseline_paths: []const []const u8,
) !usize {
    var directory = try std.Io.Dir.openDirAbsolute(io, candidate_path, .{ .iterate = true });
    defer directory.close(io);
    var iterator = directory.iterate();
    var count: usize = 0;
    while (try iterator.next(io)) |entry| {
        if (entry.kind != .file or !std.mem.endsWith(u8, entry.name, ".lang"))
            continue;
        var already_available = false;
        for (baseline_paths) |baseline| {
            const existing = try std.fs.path.join(allocator, &.{ baseline, entry.name });
            defer allocator.free(existing);
            if (std.Io.Dir.cwd().statFile(io, existing, .{})) |_| {
                already_available = true;
                break;
            } else |_| {}
        }
        if (!already_available) count += 1;
    }
    return count;
}

fn appendCandidate(
    allocator: std.mem.Allocator,
    candidates: *std.array_list.Managed(Candidate),
    path: []const u8,
    additional_specs: usize,
) !void {
    const owned_path = try allocator.dupe(u8, path);
    errdefer allocator.free(owned_path);
    try candidates.append(.{
        .path = owned_path,
        .additional_specs = additional_specs,
    });
}

pub fn discoverLegacyCandidatesAlloc(
    allocator: std.mem.Allocator,
    io: std.Io,
    home: []const u8,
) ![]Candidate {
    const user_v3 = try std.fs.path.join(allocator, &.{
        home,
        ".local/share/gtksourceview-3.0/language-specs",
    });
    defer allocator.free(user_v3);
    const user_v4 = try std.fs.path.join(allocator, &.{
        home,
        ".local/share/gtksourceview-4/language-specs",
    });
    defer allocator.free(user_v4);
    const system_v4 = "/usr/share/gtksourceview-4/language-specs";
    const paths = [_][]const u8{
        user_v3,
        "/usr/share/gtksourceview-3.0/language-specs",
    };
    const baseline = [_][]const u8{ user_v4, system_v4 };

    var candidates = std.array_list.Managed(Candidate).init(allocator);
    errdefer {
        for (candidates.items) |*candidate| candidate.deinit(allocator);
        candidates.deinit();
    }
    for (paths) |path| {
        const additional = countAdditionalLanguageSpecs(
            allocator,
            io,
            path,
            &baseline,
        ) catch |err| switch (err) {
            error.FileNotFound => continue,
            else => return err,
        };
        if (additional == 0) continue;
        try appendCandidate(allocator, &candidates, path, additional);
    }
    return candidates.toOwnedSlice();
}

pub fn deinitCandidates(allocator: std.mem.Allocator, candidates: []Candidate) void {
    for (candidates) |*candidate| candidate.deinit(allocator);
    allocator.free(candidates);
}

fn exerciseCandidateAllocationFailures(allocator: std.mem.Allocator) !void {
    var candidates = std.array_list.Managed(Candidate).init(allocator);
    defer {
        for (candidates.items) |*candidate| candidate.deinit(allocator);
        candidates.deinit();
    }
    try appendCandidate(allocator, &candidates, "/first", 1);
    try appendCandidate(allocator, &candidates, "/second", 2);
}

test "legacy syntax candidate ownership survives allocation failures" {
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        exerciseCandidateAllocationFailures,
        .{},
    );
}

test "counts only compatible language definitions missing from baselines" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.createDirPath(io, "candidate");
    try tmp.dir.createDirPath(io, "baseline");
    try tmp.dir.writeFile(io, .{ .sub_path = "candidate/zig.lang", .data = "zig" });
    try tmp.dir.writeFile(io, .{ .sub_path = "candidate/c.lang", .data = "c" });
    try tmp.dir.writeFile(io, .{ .sub_path = "candidate/readme.txt", .data = "skip" });
    try tmp.dir.writeFile(io, .{ .sub_path = "baseline/c.lang", .data = "c" });
    const candidate = try tmp.dir.realPathFileAlloc(io, "candidate", allocator);
    defer allocator.free(candidate);
    const baseline = try tmp.dir.realPathFileAlloc(io, "baseline", allocator);
    defer allocator.free(baseline);

    try std.testing.expectEqual(
        @as(usize, 2),
        try countLanguageSpecs(io, candidate),
    );
    try std.testing.expectEqual(
        @as(usize, 1),
        try countAdditionalLanguageSpecs(allocator, io, candidate, &.{baseline}),
    );
}
