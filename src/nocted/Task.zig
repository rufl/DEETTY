const std = @import("std");

const manifest_bytes_max = 256 * 1024;
const root_entries_max = 4096;

pub const Action = enum { check, build, test_project, run };

pub const Plan = struct {
    name: []const u8,
    argv: []const []const u8,
};

pub fn detect(io: std.Io, root: []const u8, action: Action) ?Plan {
    if (has(io, root, "build.zig")) return zigPlan(action);
    if (has(io, root, "Cargo.toml")) return cargoPlan(action);
    if (has(io, root, "go.mod")) return goPlan(action);
    if (has(io, root, ".metadata") and has(io, root, "pubspec.yaml")) {
        return flutterPlan(io, root, action);
    }
    if (has(io, root, "pubspec.yaml")) return dartPlan(action);
    if (has(io, root, "package.json")) return npmPlan(io, root, action);
    if (hasProjectFileExtension(io, root, &.{ ".sln", ".csproj", ".fsproj" })) {
        return dotnetPlan(action);
    }
    if (hasPythonManifest(io, root)) return pythonPlan(io, root, action);
    if (has(io, root, "Makefile")) {
        return makePlan(io, root, "Makefile", action);
    }
    if (has(io, root, "makefile")) {
        return makePlan(io, root, "makefile", action);
    }
    return null;
}

fn zigPlan(action: Action) Plan {
    return .{
        .name = "Zig",
        .argv = switch (action) {
            .check => &.{ "zig", "build", "check" },
            .build => &.{ "zig", "build" },
            .test_project => &.{ "zig", "build", "test" },
            .run => &.{ "zig", "build", "run" },
        },
    };
}

fn cargoPlan(action: Action) Plan {
    return .{
        .name = "Cargo",
        .argv = switch (action) {
            .check => &.{ "cargo", "check" },
            .build => &.{ "cargo", "build" },
            .test_project => &.{ "cargo", "test" },
            .run => &.{ "cargo", "run" },
        },
    };
}

fn goPlan(action: Action) Plan {
    return .{
        .name = "Go",
        .argv = switch (action) {
            .check => &.{ "go", "vet", "./..." },
            .build => &.{ "go", "build", "./..." },
            .test_project => &.{ "go", "test", "./..." },
            .run => &.{ "go", "run", "." },
        },
    };
}

fn flutterPlan(io: std.Io, root: []const u8, action: Action) ?Plan {
    return .{
        .name = "Flutter",
        .argv = switch (action) {
            .check => &.{ "flutter", "analyze" },
            .build => if (has(io, root, "linux"))
                &.{ "flutter", "build", "linux" }
            else
                return null,
            .test_project => &.{ "flutter", "test" },
            .run => if (has(io, root, "linux"))
                &.{ "flutter", "run", "-d", "linux" }
            else
                return null,
        },
    };
}

fn dartPlan(action: Action) ?Plan {
    return .{
        .name = "Dart",
        .argv = switch (action) {
            .check => &.{ "dart", "analyze" },
            .build => return null,
            .test_project => &.{ "dart", "test" },
            .run => &.{ "dart", "run" },
        },
    };
}

fn npmPlan(io: std.Io, root: []const u8, action: Action) ?Plan {
    switch (action) {
        .check => {
            if (packageHasScript(io, root, "check")) {
                return .{ .name = "npm", .argv = &.{ "npm", "run", "check" } };
            }
            if (packageHasScript(io, root, "lint")) {
                return .{ .name = "npm", .argv = &.{ "npm", "run", "lint" } };
            }
        },
        .build => {
            if (packageHasScript(io, root, "build")) {
                return .{ .name = "npm", .argv = &.{ "npm", "run", "build" } };
            }
        },
        .test_project => {
            if (packageHasScript(io, root, "test")) {
                return .{ .name = "npm", .argv = &.{ "npm", "test" } };
            }
        },
        .run => {
            if (packageHasScript(io, root, "start")) {
                return .{ .name = "npm", .argv = &.{ "npm", "start" } };
            }
            if (packageHasScript(io, root, "dev")) {
                return .{ .name = "npm", .argv = &.{ "npm", "run", "dev" } };
            }
        },
    }
    return null;
}

fn dotnetPlan(action: Action) Plan {
    return .{
        .name = ".NET",
        .argv = switch (action) {
            .check, .build => &.{ "dotnet", "build" },
            .test_project => &.{ "dotnet", "test" },
            .run => &.{ "dotnet", "run" },
        },
    };
}

fn pythonPlan(io: std.Io, root: []const u8, action: Action) ?Plan {
    return .{
        .name = "Python",
        .argv = switch (action) {
            .check => &.{ "python3", "-m", "compileall", "-q", "." },
            .build => if (has(io, root, "pyproject.toml") or
                has(io, root, "setup.py"))
                &.{ "python3", "-m", "build" }
            else
                return null,
            .test_project => &.{ "python3", "-m", "pytest" },
            .run => if (has(io, root, "main.py"))
                &.{ "python3", "main.py" }
            else if (has(io, root, "__main__.py"))
                &.{ "python3", "." }
            else
                return null,
        },
    };
}

fn makePlan(
    io: std.Io,
    root: []const u8,
    filename: []const u8,
    action: Action,
) ?Plan {
    return .{
        .name = "Make",
        .argv = switch (action) {
            .check => if (makeHasTarget(io, root, filename, "check"))
                &.{ "make", "check" }
            else
                return null,
            .build => &.{"make"},
            .test_project => if (makeHasTarget(io, root, filename, "test"))
                &.{ "make", "test" }
            else
                return null,
            .run => if (makeHasTarget(io, root, filename, "run"))
                &.{ "make", "run" }
            else
                return null,
        },
    };
}

fn hasPythonManifest(io: std.Io, root: []const u8) bool {
    return has(io, root, "pyproject.toml") or
        has(io, root, "setup.py") or
        has(io, root, "requirements.txt");
}

fn hasProjectFileExtension(
    io: std.Io,
    root: []const u8,
    extensions: []const []const u8,
) bool {
    var directory = std.Io.Dir.openDirAbsolute(io, root, .{ .iterate = true }) catch {
        return false;
    };
    defer directory.close(io);

    var iterator = directory.iterate();
    var entries_seen: usize = 0;
    while (entries_seen < root_entries_max) : (entries_seen += 1) {
        const entry = iterator.next(io) catch return false;
        const present = entry orelse return false;
        if (present.kind != .file and present.kind != .sym_link) continue;
        for (extensions) |extension| {
            if (std.ascii.endsWithIgnoreCase(present.name, extension)) return true;
        }
    }
    return false;
}

fn makeHasTarget(
    io: std.Io,
    root: []const u8,
    filename: []const u8,
    target: []const u8,
) bool {
    const bytes = readProjectFileAlloc(io, root, filename) orelse return false;
    defer std.heap.page_allocator.free(bytes);
    var lines = std.mem.splitScalar(u8, bytes, '\n');
    while (lines.next()) |raw_line| {
        const line = std.mem.trimEnd(u8, raw_line, "\r");
        if (line.len == 0 or line[0] == '\t' or line[0] == ' ' or
            line[0] == '#') continue;
        const colon = std.mem.indexOfScalar(u8, line, ':') orelse continue;
        if (colon + 1 < line.len and line[colon + 1] == '=') continue;
        var targets = std.mem.tokenizeAny(u8, line[0..colon], " \t");
        while (targets.next()) |candidate| {
            if (std.mem.eql(u8, candidate, target)) return true;
        }
    }
    return false;
}

fn packageHasScript(io: std.Io, root: []const u8, script: []const u8) bool {
    const bytes = readProjectFileAlloc(io, root, "package.json") orelse return false;
    defer std.heap.page_allocator.free(bytes);

    var parsed = std.json.parseFromSlice(
        std.json.Value,
        std.heap.page_allocator,
        bytes,
        .{},
    ) catch return false;
    defer parsed.deinit();
    const object = switch (parsed.value) {
        .object => |value| value,
        else => return false,
    };
    const scripts_value = object.get("scripts") orelse return false;
    const scripts = switch (scripts_value) {
        .object => |value| value,
        else => return false,
    };
    const command = scripts.get(script) orelse return false;
    return command == .string and
        std.mem.trim(u8, command.string, " \t\r\n").len > 0;
}

fn readProjectFileAlloc(
    io: std.Io,
    root: []const u8,
    name: []const u8,
) ?[]u8 {
    const path = std.fs.path.join(
        std.heap.page_allocator,
        &.{ root, name },
    ) catch return null;
    defer std.heap.page_allocator.free(path);
    return std.Io.Dir.cwd().readFileAlloc(
        io,
        path,
        std.heap.page_allocator,
        .limited(manifest_bytes_max),
    ) catch null;
}

fn has(io: std.Io, root: []const u8, name: []const u8) bool {
    const path = std.fs.path.join(
        std.heap.page_allocator,
        &.{ root, name },
    ) catch return false;
    defer std.heap.page_allocator.free(path);
    _ = std.Io.Dir.cwd().statFile(io, path, .{}) catch return false;
    return true;
}

pub const Result = struct {
    output: []u8,
    success: bool,
};

pub fn runAlloc(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: []const u8,
    plan_value: Plan,
) !Result {
    const result = try std.process.run(allocator, io, .{
        .argv = plan_value.argv,
        .cwd = .{ .path = root },
        .stdout_limit = .limited(1024 * 1024),
        .stderr_limit = .limited(1024 * 1024),
        .timeout = .{
            .duration = .{ .raw = .fromSeconds(120), .clock = .awake },
        },
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);
    var output: std.Io.Writer.Allocating = .init(allocator);
    errdefer output.deinit();
    try output.writer.writeAll(result.stdout);
    try output.writer.writeAll(result.stderr);
    return .{
        .output = try output.toOwnedSlice(),
        .success = switch (result.term) {
            .exited => |code| code == 0,
            else => false,
        },
    };
}

fn temporaryRoot(tmp: *std.testing.TmpDir, buffer: []u8) ![]const u8 {
    const length = try tmp.dir.realPath(std.testing.io, buffer);
    return buffer[0..length];
}

test "detects native build manifests with deterministic precedence" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "Cargo.toml",
        .data = "[package]\nname = \"sample\"\n",
    });
    var root_buffer: [std.fs.max_path_bytes]u8 = undefined;
    const root = try temporaryRoot(&tmp, &root_buffer);
    const cargo = detect(std.testing.io, root, .test_project).?;
    try std.testing.expectEqualStrings("Cargo", cargo.name);
    try std.testing.expectEqualStrings("test", cargo.argv[1]);

    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "build.zig", .data = "" });
    const zig = detect(std.testing.io, root, .check).?;
    try std.testing.expectEqualStrings("Zig", zig.name);
    try std.testing.expectEqualStrings("check", zig.argv[2]);
}

test "detects package scripts without inventing absent actions" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "package.json",
        .data =
        \\{"scripts":{"lint":"eslint .","build":"vite build","test":"  ","dev":"vite"}}
        ,
    });
    var root_buffer: [std.fs.max_path_bytes]u8 = undefined;
    const root = try temporaryRoot(&tmp, &root_buffer);
    const check = detect(std.testing.io, root, .check).?;
    try std.testing.expectEqualStrings("lint", check.argv[2]);
    const run = detect(std.testing.io, root, .run).?;
    try std.testing.expectEqualStrings("dev", run.argv[2]);
    try std.testing.expect(detect(std.testing.io, root, .test_project) == null);
}

test "distinguishes Flutter and Dart actions" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "pubspec.yaml",
        .data = "name: sample\n",
    });
    var root_buffer: [std.fs.max_path_bytes]u8 = undefined;
    const root = try temporaryRoot(&tmp, &root_buffer);
    try std.testing.expectEqualStrings("Dart", detect(std.testing.io, root, .run).?.name);
    try std.testing.expect(detect(std.testing.io, root, .build) == null);

    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = ".metadata", .data = "version: 1\n" });
    try std.testing.expect(detect(std.testing.io, root, .build) == null);
    try tmp.dir.createDirPath(std.testing.io, "linux");
    const flutter = detect(std.testing.io, root, .build).?;
    try std.testing.expectEqualStrings("Flutter", flutter.name);
    try std.testing.expectEqualStrings("linux", flutter.argv[2]);
}

test "detects dotnet and bounded Python entry points" {
    var dotnet_tmp = std.testing.tmpDir(.{});
    defer dotnet_tmp.cleanup();
    try dotnet_tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "Sample.CSPROJ",
        .data = "<Project />\n",
    });
    var dotnet_root_buffer: [std.fs.max_path_bytes]u8 = undefined;
    const dotnet_root = try temporaryRoot(&dotnet_tmp, &dotnet_root_buffer);
    try std.testing.expectEqualStrings(
        ".NET",
        detect(std.testing.io, dotnet_root, .build).?.name,
    );

    var python_tmp = std.testing.tmpDir(.{});
    defer python_tmp.cleanup();
    try python_tmp.dir.writeFile(std.testing.io, .{ .sub_path = "requirements.txt", .data = "" });
    var python_root_buffer: [std.fs.max_path_bytes]u8 = undefined;
    const python_root = try temporaryRoot(&python_tmp, &python_root_buffer);
    try std.testing.expect(detect(std.testing.io, python_root, .run) == null);
    try python_tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "main.py",
        .data = "print('ok')\n",
    });
    const python = detect(std.testing.io, python_root, .run).?;
    try std.testing.expectEqualStrings("Python", python.name);
    try std.testing.expectEqualStrings("main.py", python.argv[1]);
}

test "detects Go and Make project actions" {
    var go_tmp = std.testing.tmpDir(.{});
    defer go_tmp.cleanup();
    try go_tmp.dir.writeFile(std.testing.io, .{ .sub_path = "go.mod", .data = "module sample\n" });
    var go_root_buffer: [std.fs.max_path_bytes]u8 = undefined;
    const go_root = try temporaryRoot(&go_tmp, &go_root_buffer);
    const go = detect(std.testing.io, go_root, .check).?;
    try std.testing.expectEqualStrings("Go", go.name);
    try std.testing.expectEqualStrings("vet", go.argv[1]);

    var make_tmp = std.testing.tmpDir(.{});
    defer make_tmp.cleanup();
    try make_tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "Makefile",
        .data = "run := not-a-target\ncheck:\n\t@true\n",
    });
    var make_root_buffer: [std.fs.max_path_bytes]u8 = undefined;
    const make_root = try temporaryRoot(&make_tmp, &make_root_buffer);
    try std.testing.expectEqualStrings(
        "Make",
        detect(std.testing.io, make_root, .check).?.name,
    );
    try std.testing.expect(detect(std.testing.io, make_root, .run) == null);
}
