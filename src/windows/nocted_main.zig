const std = @import("std");
const windows = std.os.windows;
const core = @import("nocted_core");

const allocator = std.heap.page_allocator;
const invalid_index = std.math.maxInt(usize);
const max_error_bytes = 511;

const EditorDocument = struct {
    path: ?[:0]u8,
    display_name: []u8,
    contents: []u8,
    mode: core.document.Mode,
    dirty: bool,
    identity: ?core.document.FileIdentity,

    fn deinit(self: *EditorDocument) void {
        if (self.path) |value| allocator.free(value);
        allocator.free(self.display_name);
        allocator.free(self.contents);
        self.* = undefined;
    }
};

const EditorApp = struct {
    io: std.Io,
    documents: std.array_list.Managed(EditorDocument),
    active: ?usize = null,
    next_untitled: usize = 1,
    session_path: []u8,
    project_root: ?[]u8 = null,
    project_index: core.project_index.Index = .{},
    error_bytes: [max_error_bytes]u8 = undefined,
    error_length: usize = 0,
    restoring: bool = true,

    fn init(io: std.Io) !EditorApp {
        const session_path = try windowsSessionPathAlloc();
        var self = EditorApp{
            .io = io,
            .documents = std.array_list.Managed(EditorDocument).init(allocator),
            .session_path = session_path,
        };
        errdefer self.deinit();
        try self.restoreSession();
        self.restoring = false;
        if (self.documents.items.len == 0) _ = try self.newDocument();
        return self;
    }

    fn deinit(self: *EditorApp) void {
        if (!self.restoring) self.persistSession() catch {};
        for (self.documents.items) |*document| document.deinit();
        self.documents.deinit();
        self.project_index.deinit(allocator);
        if (self.project_root) |value| allocator.free(value);
        allocator.free(self.session_path);
        self.* = undefined;
    }

    fn clearError(self: *EditorApp) void {
        self.error_length = 0;
    }

    fn setError(self: *EditorApp, context: []const u8, err: anyerror) void {
        const rendered = std.fmt.bufPrint(
            &self.error_bytes,
            "{s}: {s}",
            .{ context, @errorName(err) },
        ) catch context[0..@min(context.len, self.error_bytes.len)];
        self.error_length = rendered.len;
    }

    fn untitledName(self: *EditorApp) ![]u8 {
        const name = try std.fmt.allocPrint(allocator, "Untitled {d}", .{self.next_untitled});
        self.next_untitled += 1;
        return name;
    }

    fn newDocument(self: *EditorApp) !usize {
        if (self.documents.items.len >= core.session.max_open_files)
            return error.TooManyOpenFiles;
        const name = try self.untitledName();
        errdefer allocator.free(name);
        const contents = try allocator.alloc(u8, 0);
        errdefer allocator.free(contents);
        try self.documents.append(.{
            .path = null,
            .display_name = name,
            .contents = contents,
            .mode = .editable,
            .dirty = false,
            .identity = null,
        });
        self.active = self.documents.items.len - 1;
        if (!self.restoring) self.persistSession() catch {};
        return self.active.?;
    }

    fn pathsEqual(left: []const u8, right: []const u8) bool {
        if (left.len != right.len) return false;
        for (left, right) |left_byte, right_byte| {
            const normalized_left = if (left_byte == '/') '\\' else std.ascii.toLower(left_byte);
            const normalized_right = if (right_byte == '/') '\\' else std.ascii.toLower(right_byte);
            if (normalized_left != normalized_right) return false;
        }
        return true;
    }

    fn requireUnchangedDocument(
        io: std.Io,
        path: [:0]const u8,
        expected: ?core.document.FileIdentity,
    ) !void {
        const prior = expected orelse return error.FileIdentityUnavailable;
        const current = try core.document.identityForPath(io, path);
        if (!prior.eql(current)) return error.DocumentChangedOnDisk;
    }

    fn findPath(self: *const EditorApp, path: []const u8) ?usize {
        for (self.documents.items, 0..) |document, index| {
            if (document.path) |existing| {
                if (pathsEqual(existing, path)) return index;
            }
        }
        return null;
    }

    fn openDocument(self: *EditorApp, path: []const u8) !usize {
        var loaded = try core.document.loadFileAlloc(allocator, self.io, path);
        errdefer loaded.deinit(allocator);
        if (self.findPath(loaded.path)) |index| {
            loaded.deinit(allocator);
            self.active = index;
            return index;
        }
        if (self.documents.items.len >= core.session.max_open_files)
            return error.TooManyOpenFiles;
        const name = try allocator.dupe(u8, std.fs.path.basename(loaded.path));
        errdefer allocator.free(name);
        const item = EditorDocument{
            .path = loaded.path,
            .display_name = name,
            .contents = loaded.contents,
            .mode = loaded.mode,
            .dirty = false,
            .identity = loaded.identity,
        };
        try self.documents.append(item);
        loaded = undefined;
        self.active = self.documents.items.len - 1;
        if (!self.restoring) self.persistSession() catch {};
        return self.active.?;
    }

    fn replaceContents(self: *EditorApp, contents: []const u8) !void {
        const index = self.active orelse return error.NoActiveDocument;
        var document = &self.documents.items[index];
        if (document.mode != .editable) return error.ReadOnlyPreview;
        if (contents.len > core.document.editable_byte_limit)
            return error.DocumentTooLarge;
        if (!std.unicode.utf8ValidateSlice(contents)) return error.InvalidUtf8;
        if (std.mem.indexOfScalar(u8, contents, 0) != null)
            return error.UnsupportedNul;
        const replacement = try allocator.dupe(u8, contents);
        allocator.free(document.contents);
        document.contents = replacement;
        document.dirty = true;
    }

    fn saveDocument(self: *EditorApp, requested_path: ?[]const u8) !void {
        const index = self.active orelse return error.NoActiveDocument;
        var document = &self.documents.items[index];
        const original_path = document.path;
        const path = requested_path orelse original_path orelse
            return error.SavePathRequired;
        const resolved = try core.document.resolveSavePathAlloc(allocator, self.io, path);
        var keep_resolved = false;
        defer if (!keep_resolved) allocator.free(resolved);
        if (self.findPath(resolved)) |other| {
            if (other != index) return error.DocumentAlreadyOpen;
        }
        if (original_path) |existing| {
            if (pathsEqual(existing, resolved)) {
                try requireUnchangedDocument(
                    self.io,
                    existing,
                    document.identity,
                );
            }
        }
        const new_name = try allocator.dupe(u8, std.fs.path.basename(resolved));
        var keep_name = false;
        defer if (!keep_name) allocator.free(new_name);
        try core.document.saveFileAtomic(self.io, resolved, document.contents);
        const saved_identity = try core.document.identityForPath(self.io, resolved);
        if (original_path) |value| allocator.free(value);
        document.path = resolved;
        keep_resolved = true;
        allocator.free(document.display_name);
        document.display_name = new_name;
        keep_name = true;
        document.mode = .editable;
        document.dirty = false;
        document.identity = saved_identity;
        if (!self.restoring) self.persistSession() catch {};
    }

    fn removeDocument(self: *EditorApp, index: usize) !void {
        if (index >= self.documents.items.len) return error.InvalidDocument;
        const active_before = self.active;
        var removed = self.documents.orderedRemove(index);
        removed.deinit();
        if (self.documents.items.len == 0) {
            self.active = null;
        } else if (active_before) |active| {
            self.active = if (active > index)
                active - 1
            else if (active == index)
                @min(index, self.documents.items.len - 1)
            else
                active;
        }
    }

    fn closeDocument(self: *EditorApp, index: usize, discard: bool) !void {
        if (index >= self.documents.items.len) return error.InvalidDocument;
        if (self.documents.items[index].dirty and !discard)
            return error.DocumentDirty;
        try self.removeDocument(index);
        if (!self.restoring) self.persistSession() catch {};
    }

    fn discardDocumentChanges(self: *EditorApp, index: usize) !void {
        try self.removeDocument(index);
    }

    fn canonicalDirectoryAlloc(self: *EditorApp, path: []const u8) ![]u8 {
        const resolved = try std.fs.path.resolve(allocator, &.{path});
        defer allocator.free(resolved);
        var directory = try std.Io.Dir.openDirAbsolute(self.io, resolved, .{ .iterate = true });
        defer directory.close(self.io);
        var buffer: [std.fs.max_path_bytes]u8 = undefined;
        const length = try directory.realPath(self.io, &buffer);
        return allocator.dupe(u8, buffer[0..length]);
    }

    fn openProject(self: *EditorApp, path: []const u8) !void {
        const root = try self.canonicalDirectoryAlloc(path);
        errdefer allocator.free(root);
        var index = try core.project_index.scanAlloc(allocator, self.io, root);
        errdefer index.deinit(allocator);
        self.project_index.deinit(allocator);
        if (self.project_root) |value| allocator.free(value);
        self.project_root = root;
        self.project_index = index;
        if (!self.restoring) self.persistSession() catch {};
    }

    fn openProjectEntry(self: *EditorApp, entry_index: usize) !usize {
        if (entry_index >= self.project_index.entries.len)
            return error.InvalidProjectEntry;
        const entry = self.project_index.entries[entry_index];
        if (entry.kind != .file) return error.ProjectEntryIsDirectory;
        const root = self.project_root orelse return error.NoProjectOpen;
        const path = try std.fs.path.join(allocator, &.{ root, self.project_index.path(entry) });
        defer allocator.free(path);
        return self.openDocument(path);
    }

    fn restoreSession(self: *EditorApp) !void {
        var saved = try core.session.loadAlloc(allocator, self.io, self.session_path);
        defer saved.deinit(allocator);
        if (saved.project) |project| self.openProject(project) catch {};
        for (saved.tabs.items) |tab| {
            if (self.documents.items.len >= core.session.max_open_files) break;
            if (tab.path) |path| {
                if (tab.contents == null) {
                    _ = self.openDocument(path) catch continue;
                    continue;
                }
            }
            const name = try allocator.dupe(u8, tab.display_name);
            errdefer allocator.free(name);
            const contents = try allocator.dupe(u8, tab.contents orelse "");
            errdefer allocator.free(contents);
            const path = if (tab.path) |value| try allocator.dupeZ(u8, value) else null;
            errdefer if (path) |value| allocator.free(value);
            try self.documents.append(.{
                .path = path,
                .display_name = name,
                .contents = contents,
                .mode = .editable,
                .dirty = tab.contents != null,
                // A recovered dirty buffer cannot prove which on-disk version it
                // was based on. Saving to the same path must fail; Save As to a
                // different path is the explicit conflict-resolution path.
                .identity = null,
            });
        }
        if (saved.active_tab) |index| {
            if (index < self.documents.items.len) self.active = index;
        }
        if (self.active == null and self.documents.items.len != 0) self.active = 0;
    }

    fn persistSession(self: *EditorApp) !void {
        const inputs = try allocator.alloc(core.session.TabInput, self.documents.items.len);
        defer allocator.free(inputs);
        for (self.documents.items, 0..) |document, index| {
            inputs[index] = .{
                .path = if (document.path) |value| value else null,
                .display_name = document.display_name,
                .contents = if (document.dirty) document.contents else null,
            };
        }
        var state = core.session.State.init(allocator);
        defer state.deinit(allocator);
        try state.setSession(
            allocator,
            self.project_root,
            inputs,
            self.active,
        );
        if (self.project_root) |root| try state.rememberProject(allocator, root);
        try core.session.save(self.io, self.session_path, &state);
    }
};

const NewDocument = *const fn (?*anyopaque) callconv(.c) c_int;
const PathCommand = *const fn (?*anyopaque, [*]const u8, usize) callconv(.c) c_int;
const ProjectEntryCommand = *const fn (?*anyopaque, usize) callconv(.c) c_int;
const SaveDocument = *const fn (?*anyopaque, ?[*]const u8, usize) callconv(.c) c_int;
const CloseDocument = *const fn (?*anyopaque, usize, c_int) callconv(.c) c_int;
const DiscardDocument = *const fn (?*anyopaque, usize) callconv(.c) c_int;
const ActivateDocument = *const fn (?*anyopaque, usize) callconv(.c) c_int;
const ReplaceContents = *const fn (?*anyopaque, [*]const u8, usize) callconv(.c) c_int;
const Count = *const fn (?*anyopaque) callconv(.c) usize;
const TabTitle = *const fn (?*anyopaque, usize, [*]u8, usize, *c_int, *c_int) callconv(.c) usize;
const CopyBytes = *const fn (?*anyopaque, [*]u8, usize) callconv(.c) usize;
const ProjectEntry = *const fn (?*anyopaque, usize, [*]u8, usize, *usize, *c_int) callconv(.c) usize;
const Persist = *const fn (?*anyopaque) callconv(.c) c_int;

const Callbacks = extern struct {
    abi_version: u32 = 2,
    userdata: ?*anyopaque,
    new_document: NewDocument,
    open_document: PathCommand,
    open_project: PathCommand,
    open_project_entry: ProjectEntryCommand,
    save_document: SaveDocument,
    close_document: CloseDocument,
    discard_document: DiscardDocument,
    activate_document: ActivateDocument,
    replace_contents: ReplaceContents,
    tab_count: Count,
    active_tab: Count,
    tab_title: TabTitle,
    active_content_length: Count,
    active_content: CopyBytes,
    active_path: CopyBytes,
    project_name: CopyBytes,
    project_entry_count: Count,
    project_entry: ProjectEntry,
    last_error: CopyBytes,
    persist_session: Persist,
};

extern fn nocted_windows_host_run(windows.HINSTANCE, c_int, *const Callbacks) c_int;
extern fn nocted_windows_session_path([*]u8, usize) c_int;
extern fn nocted_windows_has_argument([*:0]const u16) c_int;
extern fn nocted_windows_show_message([*:0]const u16, c_int) void;

fn appFromOpaque(raw: ?*anyopaque) *EditorApp {
    return @ptrCast(@alignCast(raw.?));
}

fn copySlice(value: []const u8, output: [*]u8, capacity: usize) usize {
    const count = @min(value.len, capacity);
    if (count != 0) @memcpy(output[0..count], value[0..count]);
    return value.len;
}

fn newDocumentCallback(raw: ?*anyopaque) callconv(.c) c_int {
    const app = appFromOpaque(raw);
    app.clearError();
    const index = app.newDocument() catch |err| {
        app.setError("Could not create a document", err);
        return -1;
    };
    return @intCast(index);
}

fn openDocumentCallback(raw: ?*anyopaque, path: [*]const u8, length: usize) callconv(.c) c_int {
    const app = appFromOpaque(raw);
    app.clearError();
    const index = app.openDocument(path[0..length]) catch |err| {
        app.setError("Could not open the file", err);
        return -1;
    };
    return @intCast(index);
}

fn openProjectCallback(raw: ?*anyopaque, path: [*]const u8, length: usize) callconv(.c) c_int {
    const app = appFromOpaque(raw);
    app.clearError();
    app.openProject(path[0..length]) catch |err| {
        app.setError("Could not open the folder", err);
        return -1;
    };
    return 1;
}

fn openProjectEntryCallback(raw: ?*anyopaque, index: usize) callconv(.c) c_int {
    const app = appFromOpaque(raw);
    app.clearError();
    const document_index = app.openProjectEntry(index) catch |err| {
        app.setError("Could not open the project file", err);
        return -1;
    };
    return @intCast(document_index);
}

fn saveDocumentCallback(raw: ?*anyopaque, path: ?[*]const u8, length: usize) callconv(.c) c_int {
    const app = appFromOpaque(raw);
    app.clearError();
    const requested = if (path) |value| value[0..length] else null;
    app.saveDocument(requested) catch |err| {
        if (err == error.SavePathRequired) return 2;
        app.setError("Could not save the file", err);
        return -1;
    };
    return 1;
}

fn closeDocumentCallback(raw: ?*anyopaque, index: usize, discard: c_int) callconv(.c) c_int {
    const app = appFromOpaque(raw);
    app.clearError();
    app.closeDocument(index, discard != 0) catch |err| {
        if (err == error.DocumentDirty) return 2;
        app.setError("Could not close the document", err);
        return -1;
    };
    return 1;
}

fn discardDocumentCallback(raw: ?*anyopaque, index: usize) callconv(.c) c_int {
    const app = appFromOpaque(raw);
    app.clearError();
    app.discardDocumentChanges(index) catch |err| {
        app.setError("Could not discard the document changes", err);
        return -1;
    };
    return 1;
}

fn activateDocumentCallback(raw: ?*anyopaque, index: usize) callconv(.c) c_int {
    const app = appFromOpaque(raw);
    if (index >= app.documents.items.len) return 0;
    app.active = index;
    return 1;
}

fn replaceContentsCallback(raw: ?*anyopaque, contents: [*]const u8, length: usize) callconv(.c) c_int {
    const app = appFromOpaque(raw);
    app.clearError();
    app.replaceContents(contents[0..length]) catch |err| {
        app.setError("The edit could not be applied", err);
        return -1;
    };
    return 1;
}

fn tabCountCallback(raw: ?*anyopaque) callconv(.c) usize {
    return appFromOpaque(raw).documents.items.len;
}

fn activeTabCallback(raw: ?*anyopaque) callconv(.c) usize {
    return appFromOpaque(raw).active orelse invalid_index;
}

fn tabTitleCallback(raw: ?*anyopaque, index: usize, output: [*]u8, capacity: usize, dirty: *c_int, read_only: *c_int) callconv(.c) usize {
    const app = appFromOpaque(raw);
    if (index >= app.documents.items.len) return 0;
    const document = app.documents.items[index];
    dirty.* = @intFromBool(document.dirty);
    read_only.* = @intFromBool(document.mode == .read_only_preview);
    return copySlice(document.display_name, output, capacity);
}

fn activeContentLengthCallback(raw: ?*anyopaque) callconv(.c) usize {
    const app = appFromOpaque(raw);
    const index = app.active orelse return 0;
    return app.documents.items[index].contents.len;
}

fn activeContentCallback(raw: ?*anyopaque, output: [*]u8, capacity: usize) callconv(.c) usize {
    const app = appFromOpaque(raw);
    const index = app.active orelse return 0;
    return copySlice(app.documents.items[index].contents, output, capacity);
}

fn activePathCallback(raw: ?*anyopaque, output: [*]u8, capacity: usize) callconv(.c) usize {
    const app = appFromOpaque(raw);
    const index = app.active orelse return 0;
    return if (app.documents.items[index].path) |path|
        copySlice(path, output, capacity)
    else
        0;
}

fn projectNameCallback(raw: ?*anyopaque, output: [*]u8, capacity: usize) callconv(.c) usize {
    const app = appFromOpaque(raw);
    const root = app.project_root orelse return 0;
    return copySlice(std.fs.path.basename(root), output, capacity);
}

fn projectEntryCountCallback(raw: ?*anyopaque) callconv(.c) usize {
    return appFromOpaque(raw).project_index.entries.len;
}

fn projectEntryCallback(raw: ?*anyopaque, index: usize, output: [*]u8, capacity: usize, parent: *usize, directory: *c_int) callconv(.c) usize {
    const app = appFromOpaque(raw);
    if (index >= app.project_index.entries.len) return 0;
    const entry = app.project_index.entries[index];
    parent.* = if (entry.parent_index == core.project_index.no_parent)
        invalid_index
    else
        entry.parent_index;
    directory.* = @intFromBool(entry.kind == .directory);
    return copySlice(app.project_index.basename(entry), output, capacity);
}

fn lastErrorCallback(raw: ?*anyopaque, output: [*]u8, capacity: usize) callconv(.c) usize {
    const app = appFromOpaque(raw);
    return copySlice(app.error_bytes[0..app.error_length], output, capacity);
}

fn persistSessionCallback(raw: ?*anyopaque) callconv(.c) c_int {
    const app = appFromOpaque(raw);
    app.clearError();
    app.persistSession() catch |err| {
        app.setError("Could not save the editor session", err);
        return -1;
    };
    return 1;
}

fn windowsSessionPathAlloc() ![]u8 {
    var buffer: [std.fs.max_path_bytes]u8 = undefined;
    const length = nocted_windows_session_path(&buffer, buffer.len);
    if (length <= 0) return error.SessionPathUnavailable;
    return allocator.dupe(u8, buffer[0..@intCast(length)]);
}

fn selfTest(io: std.Io, session_path: []const u8) !void {
    const path = try std.mem.concat(allocator, u8, &.{ session_path, ".document-self-test" });
    defer allocator.free(path);
    defer std.Io.Dir.cwd().deleteFile(io, path) catch {};
    const resolved = try core.document.resolveSavePathAlloc(allocator, io, path);
    defer allocator.free(resolved);
    try core.document.saveFileAtomic(io, resolved, "NoctEd Windows UTF-8 bridge: \xcf\x80\n");
    var loaded = try core.document.loadFileAlloc(allocator, io, resolved);
    defer loaded.deinit(allocator);
    if (loaded.mode != .editable or
        !std.mem.eql(u8, loaded.contents, "NoctEd Windows UTF-8 bridge: \xcf\x80\n"))
        return error.DocumentBridgeMismatch;
    try core.document.saveFileAtomic(io, loaded.path, "external edit\n");
    if (EditorApp.requireUnchangedDocument(
        io,
        loaded.path,
        loaded.identity,
    )) {
        return error.ExternalDocumentChangeUndetected;
    } else |err| {
        if (err != error.DocumentChangedOnDisk) return err;
    }
    if (EditorApp.requireUnchangedDocument(io, loaded.path, null)) {
        return error.RecoveredDocumentConflictUndetected;
    } else |err| {
        if (err != error.FileIdentityUnavailable) return err;
    }
}

pub export fn wWinMain(instance: windows.HINSTANCE, previous_instance: ?windows.HINSTANCE, command_line: [*:0]u16, show_command: c_int) callconv(.c) c_int {
    _ = previous_instance;
    _ = command_line;
    var threaded: std.Io.Threaded = .init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    if (nocted_windows_has_argument(std.unicode.utf8ToUtf16LeStringLiteral("--self-test")) != 0) {
        const session_path = windowsSessionPathAlloc() catch return 1;
        defer allocator.free(session_path);
        selfTest(io, session_path) catch {
            nocted_windows_show_message(std.unicode.utf8ToUtf16LeStringLiteral("NoctEd document bridge self-test failed."), 1);
            return 1;
        };
        return 0;
    }

    var app = EditorApp.init(io) catch {
        nocted_windows_show_message(std.unicode.utf8ToUtf16LeStringLiteral("NoctEd could not initialize its document session."), 1);
        return 1;
    };
    defer app.deinit();
    const callbacks = Callbacks{
        .userdata = &app,
        .new_document = newDocumentCallback,
        .open_document = openDocumentCallback,
        .open_project = openProjectCallback,
        .open_project_entry = openProjectEntryCallback,
        .save_document = saveDocumentCallback,
        .close_document = closeDocumentCallback,
        .discard_document = discardDocumentCallback,
        .activate_document = activateDocumentCallback,
        .replace_contents = replaceContentsCallback,
        .tab_count = tabCountCallback,
        .active_tab = activeTabCallback,
        .tab_title = tabTitleCallback,
        .active_content_length = activeContentLengthCallback,
        .active_content = activeContentCallback,
        .active_path = activePathCallback,
        .project_name = projectNameCallback,
        .project_entry_count = projectEntryCountCallback,
        .project_entry = projectEntryCallback,
        .last_error = lastErrorCallback,
        .persist_session = persistSessionCallback,
    };
    return nocted_windows_host_run(instance, show_command, &callbacks);
}
