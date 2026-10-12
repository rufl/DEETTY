const std = @import("std");

/// LSP transport limits. A language server is local but still untrusted input.
pub const max_message_bytes: usize = 4 * 1024 * 1024;
pub const max_header_bytes: usize = 16 * 1024;

/// Incremental Content-Length framed JSON-RPC decoder.
pub const Framer = struct {
    allocator: std.mem.Allocator,
    bytes: std.array_list.Managed(u8),

    pub fn init(allocator: std.mem.Allocator) Framer {
        return .{ .allocator = allocator, .bytes = std.array_list.Managed(u8).init(allocator) };
    }

    pub fn deinit(self: *Framer) void {
        self.bytes.deinit();
    }

    pub fn feed(self: *Framer, input: []const u8) !void {
        if (self.bytes.items.len + input.len > max_message_bytes + max_header_bytes)
            return error.MessageTooLarge;
        try self.bytes.appendSlice(input);
    }

    /// Returns one newly allocated JSON payload, or null until a complete frame exists.
    /// The caller owns the returned bytes.
    pub fn next(self: *Framer) !?[]u8 {
        const separator = std.mem.indexOf(u8, self.bytes.items, "\r\n\r\n") orelse
            std.mem.indexOf(u8, self.bytes.items, "\n\n") orelse {
            if (self.bytes.items.len > max_header_bytes) return error.HeaderTooLarge;
            return null;
        };
        const header_end = if (self.bytes.items[separator] == '\r') separator + 4 else separator + 2;
        if (separator > max_header_bytes) return error.HeaderTooLarge;

        const length = parseContentLength(self.bytes.items[0..separator]) orelse
            return error.ContentLengthMissing;
        if (length > max_message_bytes) return error.MessageTooLarge;
        if (self.bytes.items.len < header_end + length) return null;

        const payload = try self.allocator.dupe(u8, self.bytes.items[header_end .. header_end + length]);
        const remaining = self.bytes.items[header_end + length ..];
        std.mem.copyForwards(u8, self.bytes.items[0..remaining.len], remaining);
        self.bytes.shrinkRetainingCapacity(remaining.len);
        return payload;
    }
};

fn parseContentLength(headers: []const u8) ?usize {
    var lines = std.mem.splitScalar(u8, headers, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trimEnd(u8, line, "\r");
        const colon = std.mem.indexOfScalar(u8, trimmed, ':') orelse continue;
        const name = std.mem.trim(u8, trimmed[0..colon], " \t");
        if (!std.ascii.eqlIgnoreCase(name, "Content-Length")) continue;
        const value = std.mem.trim(u8, trimmed[colon + 1 ..], " \t");
        if (value.len == 0) return null;
        return std.fmt.parseInt(usize, value, 10) catch null;
    }
    return null;
}

fn encodeValue(allocator: std.mem.Allocator, value: anytype) ![]u8 {
    var json: std.Io.Writer.Allocating = .init(allocator);
    defer json.deinit();
    try std.json.Stringify.value(value, .{}, &json.writer);

    var output: std.Io.Writer.Allocating = .init(allocator);
    errdefer output.deinit();
    try output.writer.print("Content-Length: {d}\r\n\r\n", .{json.writer.buffered().len});
    try output.writer.writeAll(json.writer.buffered());
    return output.toOwnedSlice();
}

pub const Session = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    child: std.process.Child,
    framer: Framer,
    diagnostics: ?[]u8 = null,
    initialized: bool = false,
    document_uri: ?[]const u8 = null,

    pub fn start(
        allocator: std.mem.Allocator,
        io: std.Io,
        argv: []const []const u8,
        cwd: ?[]const u8,
    ) !Session {
        if (argv.len == 0) return error.EmptyServerCommand;
        return .{
            .allocator = allocator,
            .io = io,
            .child = try std.process.spawn(io, .{
                .argv = argv,
                .cwd = if (cwd) |path| .{ .path = path } else .inherit,
                .stdin = .pipe,
                .stdout = .pipe,
                .stderr = .ignore,
                .create_no_window = true,
            }),
            .framer = Framer.init(allocator),
        };
    }

    pub fn deinit(self: *Session) void {
        if (self.initialized) {
            self.closeDocument();
            self.shutdown();
        }
        self.child.kill(self.io);
        if (self.diagnostics) |diagnostics| self.allocator.free(diagnostics);
        self.framer.deinit();
        self.* = undefined;
    }

    fn closeDocument(self: *Session) void {
        const uri = self.document_uri orelse return;
        self.document_uri = null;
        self.send(.{
            .jsonrpc = "2.0",
            .method = "textDocument/didClose",
            .params = .{ .textDocument = .{ .uri = uri } },
        }) catch {};
    }

    fn shutdown(self: *Session) void {
        self.send(.{
            .jsonrpc = "2.0",
            .id = 3,
            .method = "shutdown",
            .params = @as(?u8, null),
        }) catch return;
        const response = self.responseAllocWithTimeout(3, 250 * std.time.ns_per_ms) catch {
            self.send(.{ .jsonrpc = "2.0", .method = "exit" }) catch {};
            return;
        };
        self.allocator.free(response);
        self.send(.{ .jsonrpc = "2.0", .method = "exit" }) catch {};
    }

    fn send(self: *Session, value: anytype) !void {
        const message = try encodeValue(self.allocator, value);
        defer self.allocator.free(message);
        try self.child.stdin.?.writeStreamingAll(self.io, message);
    }

    fn responseAlloc(self: *Session, wanted_id: i64) ![]u8 {
        return self.responseAllocWithTimeout(wanted_id, 8 * std.time.ns_per_s);
    }

    fn responseAllocWithTimeout(self: *Session, wanted_id: i64, timeout_ns: i128) ![]u8 {
        var read_buffer: [16 * 1024]u8 = undefined;
        const started = std.Io.Clock.awake.now(self.io);
        while (true) {
            while (try self.framer.next()) |payload| {
                var parsed = std.json.parseFromSlice(std.json.Value, self.allocator, payload, .{}) catch {
                    self.allocator.free(payload);
                    continue;
                };
                defer parsed.deinit();
                const object = switch (parsed.value) {
                    .object => |value| value,
                    else => {
                        self.allocator.free(payload);
                        continue;
                    },
                };
                if (fieldString(parsed.value, "method")) |method| {
                    if (std.mem.eql(u8, method, "textDocument/publishDiagnostics")) {
                        if (self.diagnostics) |diagnostics| self.allocator.free(diagnostics);
                        self.diagnostics = payload;
                        continue;
                    }
                }
                if (responseMatchesId(parsed.value, wanted_id)) return payload;
                if (object.get("method") != null) {
                    if (object.get("id")) |id| {
                        try self.send(.{ .jsonrpc = "2.0", .id = id, .result = @as(?u8, null) });
                    }
                }
                self.allocator.free(payload);
            }

            var descriptors = [_]std.posix.pollfd{.{
                .fd = self.child.stdout.?.handle,
                .events = std.posix.POLL.IN,
                .revents = 0,
            }};
            const elapsed_ns = @max(started.durationTo(std.Io.Clock.awake.now(self.io)).nanoseconds, 0);
            if (elapsed_ns >= timeout_ns) return error.ServerTimeout;
            const remaining_ms: i32 = @intCast(@max(@divTrunc(timeout_ns - elapsed_ns, std.time.ns_per_ms), 1));
            if (try std.posix.poll(&descriptors, remaining_ms) == 0) return error.ServerTimeout;
            if (descriptors[0].revents & (std.posix.POLL.ERR | std.posix.POLL.NVAL) != 0)
                return error.ServerPipeFailed;
            const count = try self.child.stdout.?.readStreaming(self.io, &.{read_buffer[0..]});
            if (count == 0) return error.ServerExited;
            try self.framer.feed(read_buffer[0..count]);
        }
    }
    fn responseMatchesId(value: std.json.Value, wanted_id: i64) bool {
        const object = switch (value) {
            .object => |object| object,
            else => return false,
        };
        if (object.get("method") != null) return false;
        const id = object.get("id") orelse return false;
        return switch (id) {
            .integer => |number| number == wanted_id,
            else => false,
        };
    }

    /// Starts the protocol, opens one in-memory document, and returns one raw
    /// JSON-RPC response. The process is local, bounded, and owned by this session.
    pub fn requestAlloc(
        self: *Session,
        root_uri: ?[]const u8,
        uri: []const u8,
        language_id: []const u8,
        text: []const u8,
        method: []const u8,
        params: anytype,
    ) ![]u8 {
        try self.send(.{
            .jsonrpc = "2.0",
            .id = 1,
            .method = "initialize",
            .params = .{
                .processId = @as(?u32, null),
                .clientInfo = .{ .name = "NoctEd", .version = "0.1" },
                .rootUri = root_uri,
                .capabilities = .{
                    .general = .{ .positionEncodings = &.{"utf-16"} },
                    .textDocument = .{
                        .completion = .{},
                        .hover = .{},
                        .definition = .{},
                        .references = .{},
                        .rename = .{ .prepareSupport = false },
                        .documentSymbol = .{},
                        .formatting = .{},
                    },
                    .workspace = .{ .workspaceFolders = true },
                },
                .workspaceFolders = if (root_uri) |root| &.{.{ .uri = root, .name = "workspace" }} else null,
            },
        });
        const initialized_response = try self.responseAlloc(1);
        self.allocator.free(initialized_response);
        self.initialized = true;
        try self.send(.{ .jsonrpc = "2.0", .method = "initialized", .params = .{} });
        try self.send(.{
            .jsonrpc = "2.0",
            .method = "textDocument/didOpen",
            .params = .{ .textDocument = .{
                .uri = uri,
                .languageId = language_id,
                .version = 1,
                .text = text,
            } },
        });
        self.document_uri = uri;
        try self.send(.{ .jsonrpc = "2.0", .id = 2, .method = method, .params = params });
        const response = try self.responseAlloc(2);
        if (std.mem.eql(u8, method, "textDocument/diagnostic") and self.diagnostics != null) {
            self.allocator.free(response);
            const diagnostics = self.diagnostics.?;
            self.diagnostics = null;
            return diagnostics;
        }
        return response;
    }
};

pub const Feature = enum {
    diagnostics,
    completion,
    hover,
    definition,
    references,
    rename,
    symbols,
    formatting,
};

pub fn runFeatureAlloc(
    allocator: std.mem.Allocator,
    io: std.Io,
    server: Server,
    cwd: ?[]const u8,
    root_uri: ?[]const u8,
    uri: []const u8,
    text: []const u8,
    line: u32,
    character: u32,
    feature: Feature,
    new_name: ?[]const u8,
) ![]u8 {
    var session = Session.start(allocator, io, server.argv, cwd) catch |err| switch (err) {
        error.FileNotFound => if (server.alternate_argv) |argv|
            try Session.start(allocator, io, argv, cwd)
        else
            return err,
        else => return err,
    };
    defer session.deinit();
    const document = .{ .uri = uri };
    const position = .{ .line = line, .character = character };
    const response = switch (feature) {
        .diagnostics => try session.requestAlloc(root_uri, uri, server.language_id, text, "textDocument/diagnostic", .{ .textDocument = document }),
        .completion => try session.requestAlloc(root_uri, uri, server.language_id, text, "textDocument/completion", .{ .textDocument = document, .position = position }),
        .hover => try session.requestAlloc(root_uri, uri, server.language_id, text, "textDocument/hover", .{ .textDocument = document, .position = position }),
        .definition => try session.requestAlloc(root_uri, uri, server.language_id, text, "textDocument/definition", .{ .textDocument = document, .position = position }),
        .references => try session.requestAlloc(root_uri, uri, server.language_id, text, "textDocument/references", .{
            .textDocument = document,
            .position = position,
            .context = .{ .includeDeclaration = true },
        }),
        .rename => try session.requestAlloc(root_uri, uri, server.language_id, text, "textDocument/rename", .{
            .textDocument = document,
            .position = position,
            .newName = new_name orelse return error.NewNameMissing,
        }),
        .symbols => try session.requestAlloc(root_uri, uri, server.language_id, text, "textDocument/documentSymbol", .{ .textDocument = document }),
        .formatting => try session.requestAlloc(root_uri, uri, server.language_id, text, "textDocument/formatting", .{
            .textDocument = document,
            .options = .{ .tabSize = 4, .insertSpaces = true },
        }),
    };
    return response;
}

pub const Server = struct {
    language_id: []const u8,
    argv: []const []const u8,
    alternate_argv: ?[]const []const u8 = null,
};

pub fn serverForPath(path: []const u8) ?Server {
    const extension = std.fs.path.extension(path);
    if (std.ascii.eqlIgnoreCase(extension, ".zig")) return .{ .language_id = "zig", .argv = &.{"zls"} };
    if (std.ascii.eqlIgnoreCase(extension, ".kf") or std.ascii.eqlIgnoreCase(extension, ".kof"))
        return .{ .language_id = "kof", .argv = &.{ "kof", "lsp" } };
    if (std.ascii.eqlIgnoreCase(extension, ".dart")) return .{ .language_id = "dart", .argv = &.{ "dart", "language-server", "--protocol=lsp" } };
    if (std.ascii.eqlIgnoreCase(extension, ".svelte")) return .{ .language_id = "svelte", .argv = &.{ "svelteserver", "--stdio" } };
    if (std.ascii.eqlIgnoreCase(extension, ".ts") or std.ascii.eqlIgnoreCase(extension, ".tsx") or
        std.ascii.eqlIgnoreCase(extension, ".js") or std.ascii.eqlIgnoreCase(extension, ".jsx"))
        return .{ .language_id = "typescript", .argv = &.{ "typescript-language-server", "--stdio" } };
    if (std.ascii.eqlIgnoreCase(extension, ".c") or std.ascii.eqlIgnoreCase(extension, ".h") or
        std.ascii.eqlIgnoreCase(extension, ".cc") or std.ascii.eqlIgnoreCase(extension, ".cpp") or
        std.ascii.eqlIgnoreCase(extension, ".cxx") or std.ascii.eqlIgnoreCase(extension, ".hpp"))
        return .{ .language_id = "cpp", .argv = &.{"clangd"} };
    if (std.ascii.eqlIgnoreCase(extension, ".cs")) return .{ .language_id = "csharp", .argv = &.{"csharp-ls"} };
    if (std.ascii.eqlIgnoreCase(extension, ".sh") or std.ascii.eqlIgnoreCase(extension, ".bash"))
        return .{ .language_id = "shellscript", .argv = &.{ "bash-language-server", "start" } };
    if (std.ascii.eqlIgnoreCase(extension, ".ps1") or std.ascii.eqlIgnoreCase(extension, ".psm1") or
        std.ascii.eqlIgnoreCase(extension, ".psd1"))
        return .{ .language_id = "powershell", .argv = &.{"powershell-editor-services"} };
    if (std.ascii.eqlIgnoreCase(extension, ".py") or std.ascii.eqlIgnoreCase(extension, ".pyi"))
        return .{ .language_id = "python", .argv = &.{ "pyright-langserver", "--stdio" }, .alternate_argv = &.{"pylsp"} };
    if (std.ascii.eqlIgnoreCase(extension, ".toml")) return .{ .language_id = "toml", .argv = &.{ "taplo", "lsp", "stdio" } };
    if (std.ascii.eqlIgnoreCase(extension, ".md") or std.ascii.eqlIgnoreCase(extension, ".markdown"))
        return .{ .language_id = "markdown", .argv = &.{ "marksman", "server" } };
    if (std.ascii.eqlIgnoreCase(extension, ".html") or std.ascii.eqlIgnoreCase(extension, ".htm"))
        return .{ .language_id = "html", .argv = &.{ "vscode-html-language-server", "--stdio" } };
    if (std.ascii.eqlIgnoreCase(extension, ".css") or std.ascii.eqlIgnoreCase(extension, ".scss"))
        return .{ .language_id = "css", .argv = &.{ "vscode-css-language-server", "--stdio" } };
    if (std.ascii.eqlIgnoreCase(extension, ".json") or std.ascii.eqlIgnoreCase(extension, ".jsonc"))
        return .{ .language_id = "json", .argv = &.{ "vscode-json-language-server", "--stdio" } };
    return null;
}
pub fn serverForPathInRoot(io: std.Io, path: []const u8, root: []const u8) ?Server {
    var server = serverForPath(path) orelse return null;
    if (!std.mem.eql(u8, server.language_id, "kof") or !hasKofDistribution(io, root))
        return server;
    server.argv = &.{ "./bin/kof", "lsp" };
    server.alternate_argv = &.{ "kof", "lsp" };
    return server;
}

fn hasKofDistribution(io: std.Io, root: []const u8) bool {
    return hasKind(io, root, "bin/kof", .file) and hasKind(io, root, "lib/kof.jar", .file);
}

fn hasKind(
    io: std.Io,
    root: []const u8,
    name: []const u8,
    expected: std.Io.File.Kind,
) bool {
    const path = std.fs.path.join(std.heap.page_allocator, &.{ root, name }) catch return false;
    defer std.heap.page_allocator.free(path);
    const stat = std.Io.Dir.cwd().statFile(io, path, .{}) catch return false;
    return stat.kind == expected;
}

pub fn fileUriAlloc(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    var output: std.Io.Writer.Allocating = .init(allocator);
    errdefer output.deinit();
    try output.writer.writeAll("file://");
    try (std.Uri.Component{ .raw = path }).formatPath(&output.writer);
    return output.toOwnedSlice();
}

pub fn utf16Column(line: []const u8, byte_offset: usize) !u32 {
    if (byte_offset > line.len) return error.InvalidPosition;
    var view = try std.unicode.Utf8View.init(line[0..byte_offset]);
    var iterator = view.iterator();
    var units: u32 = 0;
    while (iterator.nextCodepoint()) |codepoint| units += if (codepoint > 0xffff) 2 else 1;
    return units;
}

pub const Completion = struct {
    label: []u8,
    edit: TextEdit,

    pub fn deinit(self: *Completion, allocator: std.mem.Allocator) void {
        allocator.free(self.label);
        allocator.free(self.edit.new_text);
        self.* = undefined;
    }
};

pub fn completionsAlloc(
    allocator: std.mem.Allocator,
    response: []const u8,
    line: u32,
    character: u32,
) ![]Completion {
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, response, .{});
    defer parsed.deinit();
    const root = switch (parsed.value) {
        .object => |object| object,
        else => return error.InvalidResponse,
    };
    const result = root.get("result") orelse return error.InvalidResponse;
    const values = switch (result) {
        .array => |array| array.items,
        .object => |object| if (object.get("items")) |items| switch (items) {
            .array => |array| array.items,
            else => return error.InvalidCompletion,
        } else return error.InvalidCompletion,
        .null => return allocator.alloc(Completion, 0),
        else => return error.InvalidCompletion,
    };
    var output = std.array_list.Managed(Completion).init(allocator);
    errdefer {
        for (output.items) |*item| item.deinit(allocator);
        output.deinit();
    }
    for (values[0..@min(values.len, 256)]) |value| {
        const label = fieldString(value, "label") orelse continue;
        const insert_text = fieldString(value, "insertText") orelse label;
        var edit = TextEdit{
            .start_line = line,
            .start_character = character,
            .end_line = line,
            .end_character = character,
            .new_text = undefined,
        };
        if (objectField(value, "textEdit")) |text_edit| {
            const new_text = fieldString(text_edit, "newText") orelse insert_text;
            const range = objectField(text_edit, "range") orelse
                objectField(text_edit, "replace");
            if (range) |actual_range| {
                const start = objectField(actual_range, "start") orelse continue;
                const end = objectField(actual_range, "end") orelse continue;
                edit.start_line = try unsignedField(start, "line");
                edit.start_character = try unsignedField(start, "character");
                edit.end_line = try unsignedField(end, "line");
                edit.end_character = try unsignedField(end, "character");
            }
            edit.new_text = try allocator.dupe(u8, new_text);
        } else edit.new_text = try allocator.dupe(u8, insert_text);
        const owned_label = allocator.dupe(u8, label) catch |err| {
            allocator.free(edit.new_text);
            return err;
        };
        try output.append(.{ .label = owned_label, .edit = edit });
    }
    return output.toOwnedSlice();
}

pub const Location = struct {
    uri: []u8,
    line: u32,
    character: u32,

    pub fn deinit(self: *Location, allocator: std.mem.Allocator) void {
        allocator.free(self.uri);
        self.* = undefined;
    }
};

pub fn firstLocationAlloc(allocator: std.mem.Allocator, response: []const u8) !?Location {
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, response, .{});
    defer parsed.deinit();
    const root = switch (parsed.value) {
        .object => |object| object,
        else => return error.InvalidResponse,
    };
    var value = root.get("result") orelse return error.InvalidResponse;
    if (value == .null) return null;
    if (value == .array) {
        if (value.array.items.len == 0) return null;
        value = value.array.items[0];
    }
    const uri = fieldString(value, "uri") orelse
        fieldString(value, "targetUri") orelse
        return error.InvalidLocation;
    const range = objectField(value, "range") orelse
        objectField(value, "targetSelectionRange") orelse
        return error.InvalidLocation;
    const start = objectField(range, "start") orelse return error.InvalidLocation;
    return .{
        .uri = try allocator.dupe(u8, uri),
        .line = try unsignedField(start, "line"),
        .character = try unsignedField(start, "character"),
    };
}

pub const TextEdit = struct {
    start_line: u32,
    start_character: u32,
    end_line: u32,
    end_character: u32,
    new_text: []u8,
};

pub const FileEdits = struct {
    uri: []u8,
    edits: []TextEdit,

    pub fn deinit(self: *FileEdits, allocator: std.mem.Allocator) void {
        for (self.edits) |edit| allocator.free(edit.new_text);
        allocator.free(self.edits);
        allocator.free(self.uri);
        self.* = undefined;
    }
};

pub fn editsAlloc(
    allocator: std.mem.Allocator,
    response: []const u8,
    fallback_uri: []const u8,
) ![]FileEdits {
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, response, .{});
    defer parsed.deinit();
    const root = switch (parsed.value) {
        .object => |object| object,
        else => return error.InvalidResponse,
    };
    const result = root.get("result") orelse return error.InvalidResponse;
    var output = std.array_list.Managed(FileEdits).init(allocator);
    errdefer {
        for (output.items) |*item| item.deinit(allocator);
        output.deinit();
    }
    switch (result) {
        .array => |array| try appendFileEdits(allocator, &output, fallback_uri, array.items),
        .object => |object| {
            if (object.get("changes")) |changes_value| switch (changes_value) {
                .object => |changes| {
                    var iterator = changes.iterator();
                    while (iterator.next()) |entry| switch (entry.value_ptr.*) {
                        .array => |array| try appendFileEdits(allocator, &output, entry.key_ptr.*, array.items),
                        else => return error.InvalidWorkspaceEdit,
                    };
                },
                else => return error.InvalidWorkspaceEdit,
            } else if (object.get("documentChanges")) |changes_value| switch (changes_value) {
                .array => |changes| for (changes.items) |change| {
                    const text_document = objectField(change, "textDocument") orelse
                        return error.UnsupportedWorkspaceEdit;
                    const uri = fieldString(text_document, "uri") orelse
                        return error.UnsupportedWorkspaceEdit;
                    const edits_value = objectField(change, "edits") orelse
                        return error.InvalidWorkspaceEdit;
                    const edits = switch (edits_value) {
                        .array => |array| array.items,
                        else => return error.InvalidWorkspaceEdit,
                    };
                    try appendFileEdits(allocator, &output, uri, edits);
                },
                else => return error.InvalidWorkspaceEdit,
            } else return error.UnsupportedWorkspaceEdit;
        },
        .null => {},
        else => return error.InvalidResponse,
    }
    return output.toOwnedSlice();
}

fn appendFileEdits(
    allocator: std.mem.Allocator,
    output: *std.array_list.Managed(FileEdits),
    uri: []const u8,
    values: []const std.json.Value,
) !void {
    var edits = std.array_list.Managed(TextEdit).init(allocator);
    errdefer {
        for (edits.items) |edit| allocator.free(edit.new_text);
        edits.deinit();
    }
    for (values) |value| {
        const new_text = fieldString(value, "newText") orelse return error.InvalidTextEdit;
        const range = objectField(value, "range") orelse return error.InvalidTextEdit;
        const start = objectField(range, "start") orelse return error.InvalidTextEdit;
        const end = objectField(range, "end") orelse return error.InvalidTextEdit;
        const owned_text = try allocator.dupe(u8, new_text);
        errdefer allocator.free(owned_text);
        try edits.append(.{
            .start_line = try unsignedField(start, "line"),
            .start_character = try unsignedField(start, "character"),
            .end_line = try unsignedField(end, "line"),
            .end_character = try unsignedField(end, "character"),
            .new_text = owned_text,
        });
    }
    const owned_uri = try allocator.dupe(u8, uri);
    errdefer allocator.free(owned_uri);
    const owned_edits = try edits.toOwnedSlice();
    errdefer {
        for (owned_edits) |edit| allocator.free(edit.new_text);
        allocator.free(owned_edits);
    }
    try output.append(.{ .uri = owned_uri, .edits = owned_edits });
}

fn objectField(value: std.json.Value, name: []const u8) ?std.json.Value {
    return switch (value) {
        .object => |object| object.get(name),
        else => null,
    };
}

fn unsignedField(value: std.json.Value, name: []const u8) !u32 {
    const field = objectField(value, name) orelse return error.InvalidTextEdit;
    return switch (field) {
        .integer => |number| if (number >= 0 and number <= std.math.maxInt(u32)) @intCast(number) else error.InvalidTextEdit,
        else => error.InvalidTextEdit,
    };
}

pub fn applyTextEditsAlloc(
    allocator: std.mem.Allocator,
    text: []const u8,
    edits: []const TextEdit,
) ![]u8 {
    const Replacement = struct { start: usize, end: usize, text: []const u8 };
    const replacements = try allocator.alloc(Replacement, edits.len);
    defer allocator.free(replacements);
    for (edits, 0..) |edit, index| replacements[index] = .{
        .start = try positionByteOffset(text, edit.start_line, edit.start_character),
        .end = try positionByteOffset(text, edit.end_line, edit.end_character),
        .text = edit.new_text,
    };
    std.mem.sort(Replacement, replacements, {}, struct {
        fn lessThan(_: void, lhs: Replacement, rhs: Replacement) bool {
            return lhs.start < rhs.start;
        }
    }.lessThan);
    var previous_end: usize = 0;
    var output: std.Io.Writer.Allocating = .init(allocator);
    errdefer output.deinit();
    for (replacements) |replacement| {
        if (replacement.start < previous_end or replacement.end < replacement.start)
            return error.OverlappingTextEdits;
        try output.writer.writeAll(text[previous_end..replacement.start]);
        try output.writer.writeAll(replacement.text);
        previous_end = replacement.end;
    }
    try output.writer.writeAll(text[previous_end..]);
    return output.toOwnedSlice();
}

fn positionByteOffset(text: []const u8, wanted_line: u32, wanted_character: u32) !usize {
    var line: u32 = 0;
    var start: usize = 0;
    while (line < wanted_line) : (line += 1) {
        start = (std.mem.indexOfScalarPos(u8, text, start, '\n') orelse return error.InvalidPosition) + 1;
    }
    const end = std.mem.indexOfScalarPos(u8, text, start, '\n') orelse text.len;
    var view = try std.unicode.Utf8View.init(text[start..end]);
    var iterator = view.iterator();
    var units: u32 = 0;
    while (units < wanted_character) {
        const codepoint = iterator.nextCodepoint() orelse return error.InvalidPosition;
        units += if (codepoint > 0xffff) 2 else 1;
        if (units > wanted_character) return error.InvalidPosition;
    }
    return start + iterator.i;
}

pub fn filePathAlloc(allocator: std.mem.Allocator, uri: []const u8) ![]u8 {
    if (!std.mem.startsWith(u8, uri, "file:///")) return error.NonLocalUri;
    const encoded = uri[7..];
    const encoded_copy = try allocator.dupe(u8, encoded);
    defer allocator.free(encoded_copy);
    return allocator.dupe(u8, std.Uri.percentDecodeInPlace(encoded_copy));
}

pub fn summaryAlloc(allocator: std.mem.Allocator, response: []const u8) ![]u8 {
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, response, .{});
    defer parsed.deinit();
    const root = switch (parsed.value) {
        .object => |value| value,
        else => return allocator.dupe(u8, "Invalid language-server response"),
    };
    if (root.get("error")) |error_value| {
        if (fieldString(error_value, "message")) |message| return allocator.dupe(u8, message);
        return allocator.dupe(u8, "Language server returned an error");
    }
    const result = root.get("result") orelse blk: {
        const params = root.get("params") orelse return allocator.dupe(u8, "No result");
        break :blk objectField(params, "diagnostics") orelse return allocator.dupe(u8, "No result");
    };
    if (result == .null) return allocator.dupe(u8, "No result");
    if (hoverText(result)) |text| return allocator.dupe(u8, text);

    var output: std.Io.Writer.Allocating = .init(allocator);
    errdefer output.deinit();
    const values: []const std.json.Value = switch (result) {
        .array => |items| items.items,
        .object => |object| if (object.get("items")) |items| switch (items) {
            .array => |array| array.items,
            else => &.{result},
        } else &.{result},
        else => &.{result},
    };
    for (values, 0..) |value, index| {
        if (index == 80 or output.writer.buffered().len >= 16 * 1024) {
            try output.writer.writeAll("…\n");
            break;
        }
        if (fieldString(value, "message") orelse fieldString(value, "label") orelse
            fieldString(value, "name") orelse fieldString(value, "uri")) |label|
        {
            try output.writer.print("{s}\n", .{label});
        } else {
            try output.writer.print("{f}\n", .{std.json.fmt(value, .{})});
        }
    }
    if (output.writer.buffered().len == 0) try output.writer.writeAll("No result");
    return output.toOwnedSlice();
}

fn fieldString(value: std.json.Value, name: []const u8) ?[]const u8 {
    const object = switch (value) {
        .object => |item| item,
        else => return null,
    };
    const field = object.get(name) orelse return null;
    return switch (field) {
        .string => |text| text,
        else => null,
    };
}

fn hoverText(value: std.json.Value) ?[]const u8 {
    const object = switch (value) {
        .object => |item| item,
        else => return null,
    };
    const contents = object.get("contents") orelse return null;
    return switch (contents) {
        .string => |text| text,
        .object => fieldString(contents, "value"),
        else => null,
    };
}

test "parses completion edits" {
    const response =
        "{\"jsonrpc\":\"2.0\",\"id\":2,\"result\":{\"items\":[{\"label\":\"alpha\",\"insertText\":\"alpha()\"}]}}";
    const completions = try completionsAlloc(std.testing.allocator, response, 2, 3);
    defer {
        for (completions) |*completion| completion.deinit(std.testing.allocator);
        std.testing.allocator.free(completions);
    }
    try std.testing.expectEqualStrings("alpha", completions[0].label);
    try std.testing.expectEqualStrings("alpha()", completions[0].edit.new_text);
}

test "does not consume server requests that reuse response IDs" {
    const request = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"workspace/configuration\",\"params\":{}}",
        .{},
    );
    defer request.deinit();
    try std.testing.expect(!Session.responseMatchesId(request.value, 2));

    const response = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "{\"jsonrpc\":\"2.0\",\"id\":2,\"result\":null}",
        .{},
    );
    defer response.deinit();
    try std.testing.expect(Session.responseMatchesId(response.value, 2));
}

fn exerciseWorkspaceEditAllocationFailures(allocator: std.mem.Allocator) !void {
    const response =
        "{\"jsonrpc\":\"2.0\",\"id\":2,\"result\":{\"changes\":{\"file:///tmp/a.zig\":[{\"range\":{\"start\":{\"line\":0,\"character\":1},\"end\":{\"line\":0,\"character\":2}},\"newText\":\"x\"}],\"file:///tmp/b.zig\":[{\"range\":{\"start\":{\"line\":1,\"character\":0},\"end\":{\"line\":1,\"character\":1}},\"newText\":\"y\"}]}}}";
    const edits = try editsAlloc(allocator, response, "file:///tmp/fallback.zig");
    defer {
        for (edits) |*item| item.deinit(allocator);
        allocator.free(edits);
    }
}

test "workspace edit ownership survives allocation failures" {
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        exerciseWorkspaceEditAllocationFailures,
        .{},
    );
}

test "parses formatting and workspace edits" {
    const formatting =
        "{\"jsonrpc\":\"2.0\",\"id\":2,\"result\":[{\"range\":{\"start\":{\"line\":0,\"character\":1},\"end\":{\"line\":0,\"character\":2}},\"newText\":\"x\"}]}";
    const edits = try editsAlloc(std.testing.allocator, formatting, "file:///tmp/a.zig");
    defer {
        for (edits) |*item| item.deinit(std.testing.allocator);
        std.testing.allocator.free(edits);
    }
    try std.testing.expectEqual(@as(usize, 1), edits.len);
    try std.testing.expectEqualStrings("x", edits[0].edits[0].new_text);
    const changed = try applyTextEditsAlloc(std.testing.allocator, "abc", edits[0].edits);
    defer std.testing.allocator.free(changed);
    try std.testing.expectEqualStrings("axc", changed);

    const path = try filePathAlloc(std.testing.allocator, "file:///tmp/a%20b.zig");
    defer std.testing.allocator.free(path);
    try std.testing.expectEqualStrings("/tmp/a b.zig", path);
}

test "summarizes hover and completion responses" {
    const hover = try summaryAlloc(std.testing.allocator, "{\"jsonrpc\":\"2.0\",\"id\":2,\"result\":{\"contents\":{\"kind\":\"markdown\",\"value\":\"hello\"}}}");
    defer std.testing.allocator.free(hover);
    try std.testing.expectEqualStrings("hello", hover);
    const completion = try summaryAlloc(std.testing.allocator, "{\"jsonrpc\":\"2.0\",\"id\":2,\"result\":{\"items\":[{\"label\":\"alpha\"},{\"label\":\"beta\"}]}}");
    defer std.testing.allocator.free(completion);
    try std.testing.expectEqualStrings("alpha\nbeta\n", completion);
}

test "maps common languages to existing local LSP commands" {
    try std.testing.expectEqualStrings("zls", serverForPath("build.zig").?.argv[0]);
    try std.testing.expectEqualStrings("svelteserver", serverForPath("App.svelte").?.argv[0]);
    try std.testing.expectEqualStrings("clangd", serverForPath("native.cpp").?.argv[0]);
    const kof = serverForPath("Main.KF").?;
    try std.testing.expectEqualStrings("kof", kof.language_id);
    try std.testing.expectEqualStrings("kof", kof.argv[0]);
    try std.testing.expectEqualStrings("lsp", kof.argv[1]);
    try std.testing.expect(serverForPath("data.csv") == null);
}

test "prefers the project-local Kof launcher for a packaged distribution" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.createDirPath(std.testing.io, "bin");
    try tmp.dir.createDirPath(std.testing.io, "lib");
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "bin/kof", .data = "#!/bin/sh\n" });
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "lib/kof.jar", .data = "fixture\n" });

    var root_buffer: [std.fs.max_path_bytes]u8 = undefined;
    const root_length = try tmp.dir.realPath(std.testing.io, &root_buffer);
    const root = root_buffer[0..root_length];
    const path = try std.fs.path.join(std.testing.allocator, &.{ root, "Main.kf" });
    defer std.testing.allocator.free(path);

    const server = serverForPathInRoot(std.testing.io, path, root).?;
    try std.testing.expectEqualStrings("./bin/kof", server.argv[0]);
    try std.testing.expectEqualStrings("lsp", server.argv[1]);
    try std.testing.expectEqualStrings("kof", server.alternate_argv.?[0]);
}

test "encodes file URIs and UTF-16 positions" {
    const uri = try fileUriAlloc(std.testing.allocator, "/tmp/a b.zig");
    defer std.testing.allocator.free(uri);
    try std.testing.expectEqualStrings("file:///tmp/a%20b.zig", uri);
    try std.testing.expectEqual(@as(u32, 3), try utf16Column("a😀", "a😀".len));
}

test "decodes fragmented and coalesced LSP frames" {
    var framer = Framer.init(std.testing.allocator);
    defer framer.deinit();
    try framer.feed("Content-Length: 7\r\n\r\n{");
    try std.testing.expect((try framer.next()) == null);
    try framer.feed("\"a\":1}");
    const first = (try framer.next()).?;
    defer std.testing.allocator.free(first);
    try std.testing.expectEqualStrings("{\"a\":1}", first);

    try framer.feed("Content-Length: 2\r\n\r\n[]Content-Length: 1\r\n\r\n0");
    const second = (try framer.next()).?;
    defer std.testing.allocator.free(second);
    try std.testing.expectEqualStrings("[]", second);
    const third = (try framer.next()).?;
    defer std.testing.allocator.free(third);
    try std.testing.expectEqualStrings("0", third);
}

test "rejects missing and oversized content lengths" {
    var framer = Framer.init(std.testing.allocator);
    defer framer.deinit();
    try framer.feed("Content-Type: application/vscode-jsonrpc; charset=utf-8\r\n\r\n{}");
    try std.testing.expectError(error.ContentLengthMissing, framer.next());

    framer.bytes.clearRetainingCapacity();
    try framer.feed("Content-Length: 999999999\r\n\r\n");
    try std.testing.expectError(error.MessageTooLarge, framer.next());
}

test "encodes a framed request" {
    const message = try encodeValue(std.testing.allocator, .{
        .jsonrpc = "2.0",
        .id = 4,
        .method = "initialize",
        .params = struct {}{},
    });
    defer std.testing.allocator.free(message);
    try std.testing.expect(std.mem.startsWith(u8, message, "Content-Length: "));
    try std.testing.expect(std.mem.endsWith(u8, message, "{\"jsonrpc\":\"2.0\",\"id\":4,\"method\":\"initialize\",\"params\":{}}"));
}
