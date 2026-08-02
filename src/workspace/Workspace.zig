const std = @import("std");
const Config = @import("../config/Config.zig");
const Terminal = @import("../terminal/Terminal.zig");
const Continuity = @import("../terminal/Continuity.zig");

pub const SplitDirection = enum {
    left,
    right,
    up,
    down,
};

pub const LayoutPreset = enum {
    one_by_one,
    two_by_two,
    four_by_two,
    three_by_three,
    four_by_four,

    pub fn dimensions(self: LayoutPreset) struct { rows: usize, cols: usize } {
        return switch (self) {
            .one_by_one => .{ .rows = 1, .cols = 1 },
            .two_by_two => .{ .rows = 2, .cols = 2 },
            .four_by_two => .{ .rows = 2, .cols = 4 },
            .three_by_three => .{ .rows = 3, .cols = 3 },
            .four_by_four => .{ .rows = 4, .cols = 4 },
        };
    }
};

pub const SelectionMode = enum {
    replace,
    add,
    toggle,
};

pub const Axis = enum {
    horizontal,
    vertical,
};

pub const Node = struct {
    kind: Kind,
    pane_id: Terminal.PaneId = 0,
    axis: Axis = .horizontal,
    first: ?usize = null,
    second: ?usize = null,
    ratio_permille: u16 = 500,

    pub const Kind = enum {
        leaf,
        split,
    };
};

pub const SplitLayout = struct {
    allocator: std.mem.Allocator,
    nodes: std.array_list.Managed(Node),
    root: ?usize = null,

    const RemoveCopyResult = struct {
        root: ?usize,
        removed: bool,
    };

    pub fn init(allocator: std.mem.Allocator) SplitLayout {
        return .{
            .allocator = allocator,
            .nodes = std.array_list.Managed(Node).init(allocator),
        };
    }

    pub fn deinit(self: *SplitLayout) void {
        self.nodes.deinit();
    }

    pub fn setSingle(self: *SplitLayout, pane_id: Terminal.PaneId) !void {
        self.nodes.clearRetainingCapacity();
        try self.nodes.append(.{ .kind = .leaf, .pane_id = pane_id });
        self.root = 0;
    }

    pub fn splitPane(self: *SplitLayout, pane_id: Terminal.PaneId, new_pane_id: Terminal.PaneId, direction: SplitDirection) !void {
        const idx = self.findLeafByPane(pane_id) orelse return error.PaneNotInLayout;
        const old_leaf_idx = self.nodes.items.len;
        try self.nodes.append(.{ .kind = .leaf, .pane_id = pane_id });
        const new_leaf_idx = self.nodes.items.len;
        try self.nodes.append(.{ .kind = .leaf, .pane_id = new_pane_id });

        const horizontal = direction == .left or direction == .right;
        self.nodes.items[idx] = .{
            .kind = .split,
            .axis = if (horizontal) .horizontal else .vertical,
            .first = if (direction == .left or direction == .up) new_leaf_idx else old_leaf_idx,
            .second = if (direction == .left or direction == .up) old_leaf_idx else new_leaf_idx,
            .ratio_permille = 500,
        };
    }

    pub fn removePane(self: *SplitLayout, pane_id: Terminal.PaneId) !void {
        const root = self.root orelse return error.PaneNotInLayout;
        var rebuilt = SplitLayout.init(self.allocator);
        errdefer rebuilt.deinit();
        const result = try self.copyWithoutPane(root, pane_id, &rebuilt);
        if (!result.removed) return error.PaneNotInLayout;
        rebuilt.root = result.root orelse return error.CannotRemoveLastPane;
        std.mem.swap(SplitLayout, self, &rebuilt);
        rebuilt.deinit();
    }

    fn copyWithoutPane(
        self: SplitLayout,
        node_index: usize,
        pane_id: Terminal.PaneId,
        rebuilt: *SplitLayout,
    ) !RemoveCopyResult {
        if (node_index >= self.nodes.items.len) return error.InvalidSplitLayout;
        const node = self.nodes.items[node_index];
        if (node.kind == .leaf) {
            if (node.pane_id == pane_id) return .{ .root = null, .removed = true };
            return .{
                .root = try rebuilt.appendLeaf(node.pane_id),
                .removed = false,
            };
        }

        const first_index = node.first orelse return error.InvalidSplitLayout;
        const second_index = node.second orelse return error.InvalidSplitLayout;
        const first = try self.copyWithoutPane(first_index, pane_id, rebuilt);
        const second = try self.copyWithoutPane(second_index, pane_id, rebuilt);
        const removed = first.removed or second.removed;
        if (first.root == null) return .{ .root = second.root, .removed = removed };
        if (second.root == null) return .{ .root = first.root, .removed = removed };
        const next_index = rebuilt.nodes.items.len;
        try rebuilt.nodes.append(.{
            .kind = .split,
            .axis = node.axis,
            .first = first.root,
            .second = second.root,
            .ratio_permille = node.ratio_permille,
        });
        return .{ .root = next_index, .removed = removed };
    }

    pub fn setGrid(self: *SplitLayout, pane_ids: []const Terminal.PaneId, rows: usize, cols: usize) !void {
        if (rows == 0 or cols == 0 or pane_ids.len != rows * cols) return error.InvalidGrid;
        self.nodes.clearRetainingCapacity();
        self.root = try self.buildRows(pane_ids, rows, cols, 0);
    }

    fn buildRows(self: *SplitLayout, pane_ids: []const Terminal.PaneId, rows: usize, cols: usize, row: usize) !usize {
        if (row + 1 == rows) {
            return self.buildCols(pane_ids[row * cols .. row * cols + cols], 0);
        }
        const first_row = try self.buildCols(pane_ids[row * cols .. row * cols + cols], 0);
        const rest = try self.buildRows(pane_ids, rows, cols, row + 1);
        const remaining_rows = rows - row;
        return self.appendSplit(
            .vertical,
            first_row,
            rest,
            @intCast(1000 / remaining_rows),
        );
    }

    fn buildCols(self: *SplitLayout, pane_ids: []const Terminal.PaneId, col: usize) !usize {
        if (col + 1 == pane_ids.len) {
            return self.appendLeaf(pane_ids[col]);
        }
        const first = try self.appendLeaf(pane_ids[col]);
        const rest = try self.buildCols(pane_ids, col + 1);
        const remaining_cols = pane_ids.len - col;
        return self.appendSplit(
            .horizontal,
            first,
            rest,
            @intCast(1000 / remaining_cols),
        );
    }

    fn appendLeaf(self: *SplitLayout, pane_id: Terminal.PaneId) !usize {
        const idx = self.nodes.items.len;
        try self.nodes.append(.{ .kind = .leaf, .pane_id = pane_id });
        return idx;
    }

    fn appendSplit(
        self: *SplitLayout,
        axis: Axis,
        first: usize,
        second: usize,
        ratio_permille: u16,
    ) !usize {
        const idx = self.nodes.items.len;
        try self.nodes.append(.{
            .kind = .split,
            .axis = axis,
            .first = first,
            .second = second,
            .ratio_permille = ratio_permille,
        });
        return idx;
    }

    fn findLeafByPane(self: SplitLayout, pane_id: Terminal.PaneId) ?usize {
        for (self.nodes.items, 0..) |node, idx| {
            if (node.kind == .leaf and node.pane_id == pane_id) return idx;
        }
        return null;
    }
};

pub const TabStats = struct {
    total: usize = 0,
    idle: usize = 0,
    running: usize = 0,
    pending_interaction: usize = 0,
    done: usize = 0,
    @"error": usize = 0,
    long_running: usize = 0,

    pub fn countForStatus(self: TabStats, status: Terminal.TerminalStatus) usize {
        return switch (status) {
            .idle => self.idle,
            .running => self.running,
            .pending_interaction => self.pending_interaction,
            .done => self.done,
            .@"error" => self.@"error",
            .long_running => self.long_running,
        };
    }

    pub fn attentionTotal(self: TabStats) usize {
        return self.pending_interaction + self.@"error" + self.long_running;
    }
};

pub const PaneStatusChange = struct {
    pane_id: Terminal.PaneId,
    previous: Terminal.TerminalStatus,
    current: Terminal.TerminalStatus,
};

pub const PaneProfileChange = struct {
    pane_id: Terminal.PaneId,
    profile: Terminal.TerminalProfile,
};

pub const GitFileState = enum {
    unmodified,
    modified,
    added,
    deleted,
    renamed,
    untracked,
    conflicted,
    ignored,

    pub fn isChanged(self: GitFileState) bool {
        return switch (self) {
            .unmodified, .ignored => false,
            .modified, .added, .deleted, .renamed, .untracked, .conflicted => true,
        };
    }
};

pub const ProjectFileKind = enum {
    file,
    directory,
};

pub const GitStatusInput = struct {
    path: []const u8,
    state: GitFileState,
};

pub const GitGraphInput = struct {
    commit: []const u8,
    summary: []const u8,
    branch: ?[]const u8 = null,
};

pub const ProjectFileInput = struct {
    path: []const u8,
    kind: ProjectFileKind,
    dirty: bool = false,
};

pub const ProjectPanelUpdate = struct {
    git_status: []const GitStatusInput = &.{},
    git_graph: []const GitGraphInput = &.{},
    files: []const ProjectFileInput = &.{},
};

pub const GitStatusEntry = struct {
    path: []u8 = &.{},
    state: GitFileState = .unmodified,

    pub fn deinit(self: *GitStatusEntry, allocator: std.mem.Allocator) void {
        allocator.free(self.path);
        self.* = .{};
    }
};

pub const GitGraphNode = struct {
    commit: []u8 = &.{},
    summary: []u8 = &.{},
    branch: ?[]u8 = null,

    pub fn deinit(self: *GitGraphNode, allocator: std.mem.Allocator) void {
        allocator.free(self.commit);
        allocator.free(self.summary);
        if (self.branch) |branch| allocator.free(branch);
        self.* = .{};
    }
};

pub const ProjectFileEntry = struct {
    path: []u8 = &.{},
    kind: ProjectFileKind = .file,
    dirty: bool = false,

    pub fn deinit(self: *ProjectFileEntry, allocator: std.mem.Allocator) void {
        allocator.free(self.path);
        self.* = .{};
    }
};

pub const ProjectPanelSummary = struct {
    git_status_count: usize = 0,
    changed_count: usize = 0,
    conflict_count: usize = 0,
    git_graph_count: usize = 0,
    file_entry_count: usize = 0,
    directory_count: usize = 0,
    dirty_file_count: usize = 0,
};

pub const max_project_panel_view_rows: usize = 16;

pub const ProjectPanelViewKind = enum {
    git_status,
    git_graph,
    files,
};

pub const ProjectPanelViewOptions = struct {
    kind: ProjectPanelViewKind = .git_status,
    max_rows: usize = max_project_panel_view_rows,
    selected_index: ?usize = null,
    changed_only: bool = false,
    conflicts_only: bool = false,
    dirty_only: bool = false,

    pub fn boundedMaxRows(self: ProjectPanelViewOptions) usize {
        return @min(self.max_rows, max_project_panel_view_rows);
    }
};

pub const GitStatusViewRow = struct {
    source_index: usize,
    path: []const u8,
    state: GitFileState,
    changed: bool,
    selected: bool,
};

pub const GitGraphViewRow = struct {
    source_index: usize,
    commit: []const u8,
    summary: []const u8,
    branch: ?[]const u8 = null,
    selected: bool,
};

pub const ProjectFileViewRow = struct {
    source_index: usize,
    path: []const u8,
    kind: ProjectFileKind,
    dirty: bool,
    selected: bool,
};

pub const ProjectPanelViewRow = union(ProjectPanelViewKind) {
    git_status: GitStatusViewRow,
    git_graph: GitGraphViewRow,
    files: ProjectFileViewRow,
};

pub const ProjectPanelView = struct {
    kind: ProjectPanelViewKind,
    summary: ProjectPanelSummary,
    total_rows: usize = 0,
    visible_rows: usize = 0,
    row_count: usize = 0,
    max_rows: usize = 0,
    selected_index: ?usize = null,
    selected_visible: bool = false,
    changed_only: bool = false,
    conflicts_only: bool = false,
    dirty_only: bool = false,
    rows: [max_project_panel_view_rows]ProjectPanelViewRow = undefined,

    pub fn rowSlice(self: *const ProjectPanelView) []const ProjectPanelViewRow {
        return self.rows[0..self.row_count];
    }

    pub fn truncated(self: ProjectPanelView) bool {
        return self.visible_rows > self.row_count;
    }
};

pub const ProjectPanelActivationKind = enum {
    show_git_diff,
    show_git_commit,
    open_file,
    open_directory,
};

pub const ProjectPanelActivationRequest = struct {
    kind: ProjectPanelViewKind,
    source_index: usize,
};

pub const ProjectPanelActivation = struct {
    kind: ProjectPanelActivationKind,
    source: ProjectPanelActivationRequest,
    path: ?[]const u8 = null,
    commit: ?[]const u8 = null,
    summary: ?[]const u8 = null,
    branch: ?[]const u8 = null,
    git_state: ?GitFileState = null,
    file_kind: ?ProjectFileKind = null,

    pub fn targetsPath(self: ProjectPanelActivation) bool {
        return self.path != null;
    }

    pub fn targetsCommit(self: ProjectPanelActivation) bool {
        return self.commit != null;
    }

    pub fn actionPlan(self: ProjectPanelActivation) !ProjectPanelActionPlan {
        return ProjectPanelActionPlan.fromActivation(self);
    }
};

pub const ProjectPanelActionExecutor = enum {
    native_git_diff,
    native_git_commit,
    native_file_open,
    native_directory_open,
};

pub const ProjectPanelActionOperation = enum {
    run_git_diff,
    run_git_commit_show,
    open_editor_document,
    open_directory_view,
};

pub const ProjectPanelActionPlan = struct {
    kind: ProjectPanelActivationKind,
    source: ProjectPanelActivationRequest,
    executor: ProjectPanelActionExecutor,
    path: ?[]const u8 = null,
    commit: ?[]const u8 = null,
    summary: ?[]const u8 = null,
    branch: ?[]const u8 = null,
    git_state: ?GitFileState = null,
    file_kind: ?ProjectFileKind = null,
    requires_path: bool = false,
    requires_commit: bool = false,
    requires_git: bool = false,
    opens_editor: bool = false,
    opens_directory: bool = false,

    pub fn fromActivation(activation: ProjectPanelActivation) !ProjectPanelActionPlan {
        return switch (activation.kind) {
            .show_git_diff => {
                const path = activation.path orelse return error.MissingProjectPanelActionPath;
                if (activation.git_state) |state| {
                    if (!state.isChanged()) return error.ProjectPanelActionNotExecutable;
                }
                return .{
                    .kind = activation.kind,
                    .source = activation.source,
                    .executor = .native_git_diff,
                    .path = path,
                    .git_state = activation.git_state,
                    .requires_path = true,
                    .requires_git = true,
                };
            },
            .show_git_commit => {
                const commit = activation.commit orelse return error.MissingProjectPanelActionCommit;
                return .{
                    .kind = activation.kind,
                    .source = activation.source,
                    .executor = .native_git_commit,
                    .commit = commit,
                    .summary = activation.summary,
                    .branch = activation.branch,
                    .requires_commit = true,
                    .requires_git = true,
                };
            },
            .open_file => {
                const path = activation.path orelse return error.MissingProjectPanelActionPath;
                if (activation.file_kind) |kind| {
                    if (kind != .file) return error.ProjectPanelActionTargetMismatch;
                }
                return .{
                    .kind = activation.kind,
                    .source = activation.source,
                    .executor = .native_file_open,
                    .path = path,
                    .file_kind = activation.file_kind,
                    .requires_path = true,
                    .opens_editor = true,
                };
            },
            .open_directory => {
                const path = activation.path orelse return error.MissingProjectPanelActionPath;
                if (activation.file_kind) |kind| {
                    if (kind != .directory) return error.ProjectPanelActionTargetMismatch;
                }
                return .{
                    .kind = activation.kind,
                    .source = activation.source,
                    .executor = .native_directory_open,
                    .path = path,
                    .file_kind = activation.file_kind,
                    .requires_path = true,
                    .opens_directory = true,
                };
            },
        };
    }

    pub fn canExecute(self: ProjectPanelActionPlan) bool {
        if (self.requires_path and self.path == null) return false;
        if (self.requires_commit and self.commit == null) return false;
        return true;
    }
};

pub const max_project_panel_action_argv: usize = 6;

pub const ProjectPanelActionExecutionSpec = struct {
    kind: ProjectPanelActivationKind,
    source: ProjectPanelActivationRequest,
    executor: ProjectPanelActionExecutor,
    operation: ProjectPanelActionOperation,
    path: ?[]const u8 = null,
    commit: ?[]const u8 = null,
    argv: [max_project_panel_action_argv][]const u8 = .{""} ** max_project_panel_action_argv,
    argv_count: usize = 0,
    requires_process: bool = false,
    requires_editor: bool = false,
    requires_directory_view: bool = false,
    requires_git: bool = false,
    mutates_workspace: bool = false,

    pub fn fromPlan(plan: ProjectPanelActionPlan) !ProjectPanelActionExecutionSpec {
        if (!plan.canExecute()) return error.ProjectPanelActionNotExecutable;

        var spec = ProjectPanelActionExecutionSpec{
            .kind = plan.kind,
            .source = plan.source,
            .executor = plan.executor,
            .operation = undefined,
            .path = plan.path,
            .commit = plan.commit,
            .requires_git = plan.requires_git,
        };

        switch (plan.executor) {
            .native_git_diff => {
                const path = plan.path orelse return error.MissingProjectPanelActionPath;
                spec.operation = .run_git_diff;
                spec.requires_process = true;
                try spec.appendArg("git");
                try spec.appendArg("diff");
                try spec.appendArg("--");
                try spec.appendArg(path);
            },
            .native_git_commit => {
                const commit = plan.commit orelse return error.MissingProjectPanelActionCommit;
                spec.operation = .run_git_commit_show;
                spec.requires_process = true;
                try spec.appendArg("git");
                try spec.appendArg("show");
                try spec.appendArg("--stat");
                try spec.appendArg("--patch");
                try spec.appendArg(commit);
            },
            .native_file_open => {
                _ = plan.path orelse return error.MissingProjectPanelActionPath;
                spec.operation = .open_editor_document;
                spec.requires_editor = true;
            },
            .native_directory_open => {
                _ = plan.path orelse return error.MissingProjectPanelActionPath;
                spec.operation = .open_directory_view;
                spec.requires_directory_view = true;
            },
        }

        return spec;
    }

    pub fn argvSlice(self: *const ProjectPanelActionExecutionSpec) []const []const u8 {
        return self.argv[0..self.argv_count];
    }

    pub fn hasProcessArgv(self: ProjectPanelActionExecutionSpec) bool {
        return self.argv_count != 0;
    }

    fn appendArg(self: *ProjectPanelActionExecutionSpec, arg: []const u8) !void {
        if (self.argv_count >= self.argv.len) return error.ProjectPanelActionArgvOverflow;
        self.argv[self.argv_count] = arg;
        self.argv_count += 1;
    }
};

pub const ProjectPanelActionExecutionStatus = enum {
    pending,
    completed,
    failed,
    unavailable,
    denied,
};

pub const ProjectPanelActionExecutionReceipt = struct {
    source: ProjectPanelActivationRequest,
    executor: ProjectPanelActionExecutor,
    operation: ProjectPanelActionOperation,
    status: ProjectPanelActionExecutionStatus,
    exit_code: ?u8 = null,
    stdout_bytes: usize = 0,
    stderr_bytes: usize = 0,
    truncated: bool = false,

    pub fn completed(self: ProjectPanelActionExecutionReceipt) bool {
        return switch (self.status) {
            .completed, .failed, .unavailable, .denied => true,
            .pending => false,
        };
    }
};

pub const ProjectPanelActionExecutionResult = struct {
    source: ProjectPanelActivationRequest,
    executor: ProjectPanelActionExecutor,
    operation: ProjectPanelActionOperation,
    status: ProjectPanelActionExecutionStatus,
    exit_code: ?u8 = null,
    stdout_bytes: usize = 0,
    stderr_bytes: usize = 0,
    truncated: bool = false,

    pub fn fromReceipt(receipt: ProjectPanelActionExecutionReceipt) !ProjectPanelActionExecutionResult {
        if (!receipt.completed()) return error.InvalidProjectPanelActionExecutionReceipt;
        return .{
            .source = receipt.source,
            .executor = receipt.executor,
            .operation = receipt.operation,
            .status = receipt.status,
            .exit_code = receipt.exit_code,
            .stdout_bytes = receipt.stdout_bytes,
            .stderr_bytes = receipt.stderr_bytes,
            .truncated = receipt.truncated,
        };
    }

    pub fn succeeded(self: ProjectPanelActionExecutionResult) bool {
        return self.status == .completed;
    }

    pub fn hasOutput(self: ProjectPanelActionExecutionResult) bool {
        return self.stdout_bytes != 0 or self.stderr_bytes != 0;
    }

    pub fn view(self: ProjectPanelActionExecutionResult) ProjectPanelActionResultView {
        return ProjectPanelActionResultView.fromResult(self);
    }
};

pub const ProjectPanelActionResultTone = enum {
    neutral,
    success,
    warning,
    @"error",
};

pub const ProjectPanelActionResultView = struct {
    source: ProjectPanelActivationRequest,
    executor: ProjectPanelActionExecutor,
    operation: ProjectPanelActionOperation,
    status: ProjectPanelActionExecutionStatus,
    tone: ProjectPanelActionResultTone,
    title: []const u8,
    detail: []const u8,
    exit_code: ?u8 = null,
    stdout_bytes: usize = 0,
    stderr_bytes: usize = 0,
    truncated: bool = false,
    shows_process_output: bool = false,
    shows_editor_target: bool = false,
    shows_directory_target: bool = false,
    has_output: bool = false,

    pub fn fromResult(result: ProjectPanelActionExecutionResult) ProjectPanelActionResultView {
        return .{
            .source = result.source,
            .executor = result.executor,
            .operation = result.operation,
            .status = result.status,
            .tone = toneForStatus(result.status),
            .title = titleForOperation(result.operation),
            .detail = detailForStatus(result.status),
            .exit_code = result.exit_code,
            .stdout_bytes = result.stdout_bytes,
            .stderr_bytes = result.stderr_bytes,
            .truncated = result.truncated,
            .shows_process_output = operationShowsProcessOutput(result.operation),
            .shows_editor_target = result.operation == .open_editor_document,
            .shows_directory_target = result.operation == .open_directory_view,
            .has_output = result.hasOutput(),
        };
    }

    pub fn needsAttention(self: ProjectPanelActionResultView) bool {
        return switch (self.tone) {
            .warning, .@"error" => true,
            .neutral, .success => false,
        };
    }

    fn toneForStatus(status: ProjectPanelActionExecutionStatus) ProjectPanelActionResultTone {
        return switch (status) {
            .pending => .neutral,
            .completed => .success,
            .failed => .@"error",
            .unavailable, .denied => .warning,
        };
    }

    fn titleForOperation(operation: ProjectPanelActionOperation) []const u8 {
        return switch (operation) {
            .run_git_diff => "Git diff",
            .run_git_commit_show => "Git commit",
            .open_editor_document => "Editor document",
            .open_directory_view => "Directory view",
        };
    }

    fn detailForStatus(status: ProjectPanelActionExecutionStatus) []const u8 {
        return switch (status) {
            .pending => "Pending",
            .completed => "Completed",
            .failed => "Failed",
            .unavailable => "Unavailable",
            .denied => "Denied",
        };
    }

    fn operationShowsProcessOutput(operation: ProjectPanelActionOperation) bool {
        return switch (operation) {
            .run_git_diff, .run_git_commit_show => true,
            .open_editor_document, .open_directory_view => false,
        };
    }
};

pub const ProjectPanelState = struct {
    git_status: []GitStatusEntry = &.{},
    git_graph: []GitGraphNode = &.{},
    files: []ProjectFileEntry = &.{},

    pub fn deinit(self: *ProjectPanelState, allocator: std.mem.Allocator) void {
        for (self.git_status) |*entry| entry.deinit(allocator);
        allocator.free(self.git_status);
        for (self.git_graph) |*node| node.deinit(allocator);
        allocator.free(self.git_graph);
        for (self.files) |*entry| entry.deinit(allocator);
        allocator.free(self.files);
        self.* = .{};
    }

    pub fn fromUpdate(allocator: std.mem.Allocator, update: ProjectPanelUpdate) !ProjectPanelState {
        var state = ProjectPanelState{};
        errdefer state.deinit(allocator);

        state.git_status = try allocator.alloc(GitStatusEntry, update.git_status.len);
        for (state.git_status) |*entry| entry.* = .{};
        for (update.git_status, 0..) |entry, idx| {
            state.git_status[idx] = try cloneGitStatusEntry(allocator, entry);
        }

        state.git_graph = try allocator.alloc(GitGraphNode, update.git_graph.len);
        for (state.git_graph) |*node| node.* = .{};
        for (update.git_graph, 0..) |node, idx| {
            state.git_graph[idx] = try cloneGitGraphNode(allocator, node);
        }

        state.files = try allocator.alloc(ProjectFileEntry, update.files.len);
        for (state.files) |*entry| entry.* = .{};
        for (update.files, 0..) |entry, idx| {
            state.files[idx] = try cloneProjectFileEntry(allocator, entry);
        }

        return state;
    }

    pub fn clone(self: ProjectPanelState, allocator: std.mem.Allocator) !ProjectPanelState {
        var state = ProjectPanelState{};
        errdefer state.deinit(allocator);

        state.git_status = try allocator.alloc(GitStatusEntry, self.git_status.len);
        for (state.git_status) |*entry| entry.* = .{};
        for (self.git_status, 0..) |entry, idx| {
            state.git_status[idx] = try cloneGitStatusEntry(allocator, .{
                .path = entry.path,
                .state = entry.state,
            });
        }

        state.git_graph = try allocator.alloc(GitGraphNode, self.git_graph.len);
        for (state.git_graph) |*node| node.* = .{};
        for (self.git_graph, 0..) |node, idx| {
            state.git_graph[idx] = try cloneGitGraphNode(allocator, .{
                .commit = node.commit,
                .summary = node.summary,
                .branch = node.branch,
            });
        }

        state.files = try allocator.alloc(ProjectFileEntry, self.files.len);
        for (state.files) |*entry| entry.* = .{};
        for (self.files, 0..) |entry, idx| {
            state.files[idx] = try cloneProjectFileEntry(allocator, .{
                .path = entry.path,
                .kind = entry.kind,
                .dirty = entry.dirty,
            });
        }

        return state;
    }

    pub fn summary(self: ProjectPanelState) ProjectPanelSummary {
        var result = ProjectPanelSummary{
            .git_status_count = self.git_status.len,
            .git_graph_count = self.git_graph.len,
            .file_entry_count = self.files.len,
        };

        for (self.git_status) |entry| {
            if (entry.state.isChanged()) result.changed_count += 1;
            if (entry.state == .conflicted) result.conflict_count += 1;
        }
        for (self.files) |entry| {
            if (entry.kind == .directory) result.directory_count += 1;
            if (entry.dirty) result.dirty_file_count += 1;
        }

        return result;
    }

    pub fn activate(self: ProjectPanelState, request: ProjectPanelActivationRequest) !ProjectPanelActivation {
        return switch (request.kind) {
            .git_status => {
                if (request.source_index >= self.git_status.len) return error.ProjectPanelRowNotFound;
                const entry = self.git_status[request.source_index];
                return .{
                    .kind = .show_git_diff,
                    .source = request,
                    .path = entry.path,
                    .git_state = entry.state,
                };
            },
            .git_graph => {
                if (request.source_index >= self.git_graph.len) return error.ProjectPanelRowNotFound;
                const node = self.git_graph[request.source_index];
                return .{
                    .kind = .show_git_commit,
                    .source = request,
                    .commit = node.commit,
                    .summary = node.summary,
                    .branch = node.branch,
                };
            },
            .files => {
                if (request.source_index >= self.files.len) return error.ProjectPanelRowNotFound;
                const entry = self.files[request.source_index];
                return .{
                    .kind = if (entry.kind == .directory) .open_directory else .open_file,
                    .source = request,
                    .path = entry.path,
                    .file_kind = entry.kind,
                };
            },
        };
    }

    pub fn view(self: ProjectPanelState, options: ProjectPanelViewOptions) ProjectPanelView {
        var result = ProjectPanelView{
            .kind = options.kind,
            .summary = self.summary(),
            .max_rows = options.boundedMaxRows(),
            .changed_only = options.changed_only,
            .conflicts_only = options.conflicts_only,
            .dirty_only = options.dirty_only,
        };

        result.total_rows = switch (options.kind) {
            .git_status => self.git_status.len,
            .git_graph => self.git_graph.len,
            .files => self.files.len,
        };
        if (options.selected_index) |idx| {
            if (idx < result.total_rows) result.selected_index = idx;
        }

        switch (options.kind) {
            .git_status => {
                for (self.git_status, 0..) |entry, idx| {
                    if (!gitStatusRowVisible(entry, options)) continue;
                    const selected = result.selected_index != null and result.selected_index.? == idx;
                    appendRow(&result, .{ .git_status = .{
                        .source_index = idx,
                        .path = entry.path,
                        .state = entry.state,
                        .changed = entry.state.isChanged(),
                        .selected = selected,
                    } }, selected);
                }
            },
            .git_graph => {
                for (self.git_graph, 0..) |node, idx| {
                    const selected = result.selected_index != null and result.selected_index.? == idx;
                    appendRow(&result, .{ .git_graph = .{
                        .source_index = idx,
                        .commit = node.commit,
                        .summary = node.summary,
                        .branch = node.branch,
                        .selected = selected,
                    } }, selected);
                }
            },
            .files => {
                for (self.files, 0..) |entry, idx| {
                    if (!projectFileRowVisible(entry, options)) continue;
                    const selected = result.selected_index != null and result.selected_index.? == idx;
                    appendRow(&result, .{ .files = .{
                        .source_index = idx,
                        .path = entry.path,
                        .kind = entry.kind,
                        .dirty = entry.dirty,
                        .selected = selected,
                    } }, selected);
                }
            },
        }

        return result;
    }
};

fn gitStatusRowVisible(entry: GitStatusEntry, options: ProjectPanelViewOptions) bool {
    if (options.conflicts_only and entry.state != .conflicted) return false;
    if (options.changed_only and !entry.state.isChanged()) return false;
    return true;
}

fn projectFileRowVisible(entry: ProjectFileEntry, options: ProjectPanelViewOptions) bool {
    if (options.dirty_only and !entry.dirty) return false;
    if (options.changed_only and !entry.dirty) return false;
    return true;
}

fn appendRow(self: *ProjectPanelView, row: ProjectPanelViewRow, selected: bool) void {
    self.visible_rows += 1;
    if (selected) self.selected_visible = true;
    if (self.row_count >= self.max_rows) return;
    self.rows[self.row_count] = row;
    self.row_count += 1;
}

fn cloneGitStatusEntry(allocator: std.mem.Allocator, entry: GitStatusInput) !GitStatusEntry {
    if (entry.path.len == 0) return error.InvalidProjectPanelEntry;
    return .{
        .path = try allocator.dupe(u8, entry.path),
        .state = entry.state,
    };
}

fn cloneGitGraphNode(allocator: std.mem.Allocator, node: GitGraphInput) !GitGraphNode {
    if (node.commit.len == 0 or node.summary.len == 0) return error.InvalidProjectPanelEntry;
    const commit = try allocator.dupe(u8, node.commit);
    errdefer allocator.free(commit);
    const summary = try allocator.dupe(u8, node.summary);
    errdefer allocator.free(summary);
    const branch = if (node.branch) |branch_name| blk: {
        if (branch_name.len == 0) break :blk null;
        break :blk try allocator.dupe(u8, branch_name);
    } else null;
    errdefer if (branch) |branch_name| allocator.free(branch_name);

    return .{
        .commit = commit,
        .summary = summary,
        .branch = branch,
    };
}

fn cloneProjectFileEntry(allocator: std.mem.Allocator, entry: ProjectFileInput) !ProjectFileEntry {
    if (entry.path.len == 0) return error.InvalidProjectPanelEntry;
    return .{
        .path = try allocator.dupe(u8, entry.path),
        .kind = entry.kind,
        .dirty = entry.dirty,
    };
}

pub const PaneSnapshot = struct {
    id: Terminal.PaneId,
    title: []u8,
    cwd: []u8,
    worktree_root: ?[]u8 = null,
    profile: Terminal.TerminalProfile,
    status: Terminal.TerminalStatus,
    selected: bool,
    tags: []const []u8,
    agent_resume: Continuity.AgentResume = .{},

    pub fn deinit(self: *PaneSnapshot, allocator: std.mem.Allocator) void {
        allocator.free(self.title);
        allocator.free(self.cwd);
        if (self.worktree_root) |root| allocator.free(root);
        allocator.free(self.profile.theme_name);
        allocator.free(self.profile.font_family);
        for (self.tags) |tag| allocator.free(tag);
        allocator.free(self.tags);
    }
};

pub const TabColorPreset = enum(u8) {
    red,
    orange,
    yellow,
    green,
    cyan,
    blue,
    purple,
    pink,

    pub fn baseRgb(self: TabColorPreset) u32 {
        return switch (self) {
            .red => 0xef5350,
            .orange => 0xfb8c00,
            .yellow => 0xfdd835,
            .green => 0x43a047,
            .cyan => 0x00acc1,
            .blue => 0x4285f4,
            .purple => 0x8e5bd9,
            .pink => 0xec407a,
        };
    }
};

pub const TabAccent = struct {
    pub const min_shade: i8 = -4;
    pub const max_shade: i8 = 4;
    pub const default_preset: TabColorPreset = .blue;

    preset: TabColorPreset,
    shade: i8 = 0,

    pub fn init(preset: TabColorPreset) TabAccent {
        return .{ .preset = preset };
    }

    pub fn adjusted(self: TabAccent, delta: i8) TabAccent {
        return .{
            .preset = self.preset,
            .shade = @intCast(std.math.clamp(
                @as(i16, self.shade) + @as(i16, delta),
                min_shade,
                max_shade,
            )),
        };
    }

    pub fn rgb(self: TabAccent) u32 {
        const base = self.preset.baseRgb();
        const red: u8 = @truncate(base >> 16);
        const green: u8 = @truncate(base >> 8);
        const blue: u8 = @truncate(base);
        return (@as(u32, adjustedChannel(red, self.shade)) << 16) |
            (@as(u32, adjustedChannel(green, self.shade)) << 8) |
            @as(u32, adjustedChannel(blue, self.shade));
    }

    fn adjustedChannel(channel: u8, shade: i8) u8 {
        if (shade == 0) return channel;
        const amount: u16 = @intCast(@abs(@as(i16, shade)));
        const source: u16 = channel;
        if (shade > 0) {
            const lift = ((255 - source) * amount * 12 + 50) / 100;
            return @intCast(@min(@as(u16, 255), source + lift));
        }
        const reduction = (source * amount * 12 + 50) / 100;
        return @intCast(source - @min(source, reduction));
    }
};

pub const TabSnapshot = struct {
    id: u64,
    title: []u8,
    title_overridden: bool = false,
    accent: ?TabAccent = null,
    position: Config.TabPosition,
    active_pane_id: Terminal.PaneId,
    panes: []PaneSnapshot,
    nodes: []Node,
    root: ?usize,

    pub fn deinit(self: *TabSnapshot, allocator: std.mem.Allocator) void {
        allocator.free(self.title);
        for (self.panes) |*pane| pane.deinit(allocator);
        allocator.free(self.panes);
        allocator.free(self.nodes);
    }
};

pub const ProjectSnapshot = struct {
    tabs: []TabSnapshot,
    active_tab: usize,
    next_tab_id: u64,
    next_pane_id: Terminal.PaneId,
    broadcast_enabled: bool,
    quick_note: []u8 = &.{},
    smart_filter_tag: ?[]u8 = null,
    project_panels: ProjectPanelState = .{},

    pub fn deinit(self: *ProjectSnapshot, allocator: std.mem.Allocator) void {
        for (self.tabs) |*tab| tab.deinit(allocator);
        allocator.free(self.tabs);
        allocator.free(self.quick_note);
        if (self.smart_filter_tag) |tag| allocator.free(tag);
        self.project_panels.deinit(allocator);
        self.* = .{
            .tabs = &.{},
            .active_tab = 0,
            .next_tab_id = 1,
            .next_pane_id = 1,
            .broadcast_enabled = false,
            .quick_note = &.{},
            .smart_filter_tag = null,
            .project_panels = .{},
        };
    }
};

pub const WorkspaceExport = struct {
    bytes: []u8,

    pub fn deinit(self: WorkspaceExport, allocator: std.mem.Allocator) void {
        allocator.free(self.bytes);
    }
};

const workspace_export_magic = "NOCTTYWS";
const workspace_export_version: u8 = 7;

pub fn exportSnapshotAlloc(allocator: std.mem.Allocator, snapshot: ProjectSnapshot) ![]u8 {
    var writer = SnapshotWriter.init(allocator);
    errdefer writer.deinit();

    try writer.bytes.appendSlice(workspace_export_magic);
    try writer.writeU8(workspace_export_version);
    try writer.writeU64(snapshot.active_tab);
    try writer.writeU64(snapshot.next_tab_id);
    try writer.writeU64(snapshot.next_pane_id);
    try writer.writeBool(snapshot.broadcast_enabled);
    try writer.writeU64(snapshot.tabs.len);

    for (snapshot.tabs) |tab| {
        try writer.writeTab(tab);
    }
    try writer.writeProjectPanels(snapshot.project_panels);
    try writer.writeString(snapshot.quick_note);
    try writer.writeU64(snapshot.tabs.len);
    for (snapshot.tabs) |tab| try writer.writeBool(tab.title_overridden);
    try writer.writeU64(snapshot.tabs.len);
    for (snapshot.tabs) |tab| try writer.writeOptionalTabAccent(tab.accent);
    try writer.writeBool(snapshot.smart_filter_tag != null);
    if (snapshot.smart_filter_tag) |tag| try writer.writeString(tag);
    var resume_count: usize = 0;
    for (snapshot.tabs) |tab| resume_count += tab.panes.len;
    try writer.writeU64(resume_count);
    for (snapshot.tabs) |tab| for (tab.panes) |pane|
        try writer.writeAgentResume(pane.agent_resume);

    return writer.bytes.toOwnedSlice();
}

pub fn importSnapshotAlloc(allocator: std.mem.Allocator, bytes: []const u8) !ProjectSnapshot {
    var reader = SnapshotReader{
        .allocator = allocator,
        .bytes = bytes,
    };
    try reader.expectMagic();
    const version = try reader.readU8();
    if (version == 0 or version > workspace_export_version) return error.UnsupportedWorkspaceSnapshotVersion;

    const active_tab = try reader.readU64AsUsize();
    const next_tab_id = try reader.readU64();
    const next_pane_id = try reader.readU64();
    const broadcast_enabled = try reader.readBool();
    const tab_count = try reader.readU64AsUsize();
    if (tab_count == 0) return error.EmptyWorkspaceSnapshot;

    const tabs = try allocator.alloc(TabSnapshot, tab_count);
    errdefer allocator.free(tabs);
    var initialized_tabs: usize = 0;
    errdefer {
        for (tabs[0..initialized_tabs]) |*tab| tab.deinit(allocator);
    }

    for (tabs) |*tab| {
        tab.* = try reader.readTab();
        initialized_tabs += 1;
    }

    if (active_tab >= tabs.len) return error.InvalidWorkspaceSnapshot;
    var project_panels = if (version >= 2) try reader.readProjectPanels() else ProjectPanelState{};
    errdefer project_panels.deinit(allocator);
    const quick_note = if (version >= 3)
        try reader.readStringAlloc()
    else
        try allocator.dupe(u8, "");
    errdefer allocator.free(quick_note);
    if (version >= 4) {
        const title_override_count = try reader.readU64AsUsize();
        if (title_override_count != tabs.len) return error.InvalidWorkspaceSnapshot;
        for (tabs) |*tab| tab.title_overridden = try reader.readBool();
    }
    if (version >= 5) {
        const accent_count = try reader.readU64AsUsize();
        if (accent_count != tabs.len) return error.InvalidWorkspaceSnapshot;
        for (tabs) |*tab| tab.accent = try reader.readOptionalTabAccent();
    }
    const smart_filter_tag = if (version >= 6 and try reader.readBool())
        try reader.readStringAlloc()
    else
        null;
    errdefer if (smart_filter_tag) |tag| allocator.free(tag);
    if (version >= 7) {
        var resume_count: usize = 0;
        for (tabs) |tab| resume_count += tab.panes.len;
        if (try reader.readU64AsUsize() != resume_count)
            return error.InvalidWorkspaceSnapshot;
        for (tabs) |*tab| {
            for (tab.panes) |*pane| {
                pane.agent_resume = try reader.readAgentResume();
            }
        }
    }
    if (!reader.finished()) return error.TrailingWorkspaceSnapshotData;

    return .{
        .tabs = tabs,
        .active_tab = active_tab,
        .next_tab_id = next_tab_id,
        .next_pane_id = next_pane_id,
        .broadcast_enabled = broadcast_enabled,
        .quick_note = quick_note,
        .smart_filter_tag = smart_filter_tag,
        .project_panels = project_panels,
    };
}

const SnapshotWriter = struct {
    bytes: std.array_list.Managed(u8),

    fn init(allocator: std.mem.Allocator) SnapshotWriter {
        return .{ .bytes = std.array_list.Managed(u8).init(allocator) };
    }

    fn deinit(self: *SnapshotWriter) void {
        self.bytes.deinit();
    }

    fn writeTab(self: *SnapshotWriter, tab: TabSnapshot) !void {
        try self.writeU64(tab.id);
        try self.writeTabPosition(tab.position);
        try self.writeU64(tab.active_pane_id);
        try self.writeOptionalU64(tab.root);
        try self.writeString(tab.title);
        try self.writeU64(tab.nodes.len);
        for (tab.nodes) |node| try self.writeNode(node);
        try self.writeU64(tab.panes.len);
        for (tab.panes) |pane| try self.writePane(pane);
    }

    fn writePane(self: *SnapshotWriter, pane: PaneSnapshot) !void {
        try self.writeU64(pane.id);
        try self.writeString(pane.title);
        try self.writeString(pane.cwd);
        try self.writeOptionalString(pane.worktree_root);
        try self.writeString(pane.profile.theme_name);
        try self.writeString(pane.profile.font_family);
        try self.writeU32(@intFromFloat(pane.profile.font_size_pt * 1000.0));
        try self.writeBool(pane.profile.ligatures);
        try self.writeStatus(pane.status);
        try self.writeBool(pane.selected);
        try self.writeU64(pane.tags.len);
        for (pane.tags) |tag| try self.writeString(tag);
    }

    fn writeAgentResume(self: *SnapshotWriter, reference: Continuity.AgentResume) !void {
        try self.writeBool(reference.enabled);
        try self.writeU8(@intFromEnum(reference.provider));
        try self.writeString(reference.session_id.slice());
        try self.writeString(reference.label.slice());
    }

    fn writeProjectPanels(self: *SnapshotWriter, panels: ProjectPanelState) !void {
        try self.writeU64(panels.git_status.len);
        for (panels.git_status) |entry| {
            try self.writeString(entry.path);
            try self.writeGitFileState(entry.state);
        }

        try self.writeU64(panels.git_graph.len);
        for (panels.git_graph) |node| {
            try self.writeString(node.commit);
            try self.writeString(node.summary);
            try self.writeOptionalString(node.branch);
        }

        try self.writeU64(panels.files.len);
        for (panels.files) |entry| {
            try self.writeString(entry.path);
            try self.writeProjectFileKind(entry.kind);
            try self.writeBool(entry.dirty);
        }
    }

    fn writeNode(self: *SnapshotWriter, node: Node) !void {
        try self.writeNodeKind(node.kind);
        try self.writeU64(node.pane_id);
        try self.writeAxis(node.axis);
        try self.writeOptionalU64(node.first);
        try self.writeOptionalU64(node.second);
        try self.writeU16(node.ratio_permille);
    }

    fn writeString(self: *SnapshotWriter, value: []const u8) !void {
        try self.writeU64(value.len);
        try self.bytes.appendSlice(value);
    }

    fn writeOptionalString(self: *SnapshotWriter, value: ?[]const u8) !void {
        if (value) |payload| {
            try self.writeBool(true);
            try self.writeString(payload);
        } else {
            try self.writeBool(false);
        }
    }

    fn writeOptionalU64(self: *SnapshotWriter, value: ?usize) !void {
        if (value) |payload| {
            try self.writeBool(true);
            try self.writeU64(payload);
        } else {
            try self.writeBool(false);
        }
    }

    fn writeOptionalTabAccent(self: *SnapshotWriter, value: ?TabAccent) !void {
        if (value) |accent| {
            try self.writeBool(true);
            try self.writeU8(@intFromEnum(accent.preset));
            try self.writeU8(@intCast(accent.shade - TabAccent.min_shade));
        } else {
            try self.writeBool(false);
        }
    }

    fn writeTabPosition(self: *SnapshotWriter, position: Config.TabPosition) !void {
        try self.writeU8(switch (position) {
            .top => 0,
            .bottom => 1,
            .left => 2,
            .right => 3,
        });
    }

    fn writeNodeKind(self: *SnapshotWriter, kind: Node.Kind) !void {
        try self.writeU8(switch (kind) {
            .leaf => 0,
            .split => 1,
        });
    }

    fn writeAxis(self: *SnapshotWriter, axis: Axis) !void {
        try self.writeU8(switch (axis) {
            .horizontal => 0,
            .vertical => 1,
        });
    }

    fn writeStatus(self: *SnapshotWriter, status: Terminal.TerminalStatus) !void {
        try self.writeU8(switch (status) {
            .idle => 0,
            .running => 1,
            .pending_interaction => 2,
            .done => 3,
            .@"error" => 4,
            .long_running => 5,
        });
    }

    fn writeGitFileState(self: *SnapshotWriter, state: GitFileState) !void {
        try self.writeU8(switch (state) {
            .unmodified => 0,
            .modified => 1,
            .added => 2,
            .deleted => 3,
            .renamed => 4,
            .untracked => 5,
            .conflicted => 6,
            .ignored => 7,
        });
    }

    fn writeProjectFileKind(self: *SnapshotWriter, kind: ProjectFileKind) !void {
        try self.writeU8(switch (kind) {
            .file => 0,
            .directory => 1,
        });
    }

    fn writeBool(self: *SnapshotWriter, value: bool) !void {
        try self.writeU8(if (value) 1 else 0);
    }

    fn writeU8(self: *SnapshotWriter, value: u8) !void {
        try self.bytes.append(value);
    }

    fn writeU16(self: *SnapshotWriter, value: u16) !void {
        try self.writeIntLittle(value, 2);
    }

    fn writeU32(self: *SnapshotWriter, value: u32) !void {
        try self.writeIntLittle(value, 4);
    }

    fn writeU64(self: *SnapshotWriter, value: anytype) !void {
        try self.writeIntLittle(@as(u64, @intCast(value)), 8);
    }

    fn writeIntLittle(self: *SnapshotWriter, value: u64, comptime byte_count: usize) !void {
        var idx: usize = 0;
        while (idx < byte_count) : (idx += 1) {
            const shift: u6 = @intCast(idx * 8);
            try self.bytes.append(@intCast((value >> shift) & 0xff));
        }
    }
};

const SnapshotReader = struct {
    allocator: std.mem.Allocator,
    bytes: []const u8,
    offset: usize = 0,

    fn expectMagic(self: *SnapshotReader) !void {
        if (self.bytes.len < workspace_export_magic.len) return error.InvalidWorkspaceSnapshot;
        if (!std.mem.eql(u8, self.bytes[0..workspace_export_magic.len], workspace_export_magic)) {
            return error.InvalidWorkspaceSnapshot;
        }
        self.offset = workspace_export_magic.len;
    }

    fn finished(self: SnapshotReader) bool {
        return self.offset == self.bytes.len;
    }

    fn readTab(self: *SnapshotReader) !TabSnapshot {
        const id = try self.readU64();
        const position = try self.readTabPosition();
        const active_pane_id = try self.readU64();
        const root = try self.readOptionalU64AsUsize();
        const title = try self.readStringAlloc();
        errdefer self.allocator.free(title);

        const node_count = try self.readU64AsUsize();
        const nodes = try self.allocator.alloc(Node, node_count);
        errdefer self.allocator.free(nodes);
        for (nodes) |*node| node.* = try self.readNode();

        const pane_count = try self.readU64AsUsize();
        if (pane_count == 0) return error.InvalidWorkspaceSnapshot;
        const panes = try self.allocator.alloc(PaneSnapshot, pane_count);
        errdefer self.allocator.free(panes);
        var initialized_panes: usize = 0;
        errdefer {
            for (panes[0..initialized_panes]) |*pane| pane.deinit(self.allocator);
        }

        for (panes) |*pane| {
            pane.* = try self.readPane();
            initialized_panes += 1;
        }

        return .{
            .id = id,
            .title = title,
            .position = position,
            .active_pane_id = active_pane_id,
            .panes = panes,
            .nodes = nodes,
            .root = root,
        };
    }

    fn readPane(self: *SnapshotReader) !PaneSnapshot {
        const id = try self.readU64();
        const title = try self.readStringAlloc();
        errdefer self.allocator.free(title);
        const cwd = try self.readStringAlloc();
        errdefer self.allocator.free(cwd);
        const worktree_root = try self.readOptionalStringAlloc();
        errdefer if (worktree_root) |root| self.allocator.free(root);
        const theme_name = try self.readStringAlloc();
        errdefer self.allocator.free(theme_name);
        const font_family = try self.readStringAlloc();
        errdefer self.allocator.free(font_family);
        const font_size_pt = @as(f32, @floatFromInt(try self.readU32())) / 1000.0;
        const ligatures = try self.readBool();
        const status = try self.readStatus();
        const selected = try self.readBool();

        const tag_count = try self.readU64AsUsize();
        const tags = try self.allocator.alloc([]u8, tag_count);
        errdefer self.allocator.free(tags);
        var initialized_tags: usize = 0;
        errdefer {
            for (tags[0..initialized_tags]) |tag| self.allocator.free(tag);
        }
        for (tags) |*tag| {
            tag.* = try self.readStringAlloc();
            initialized_tags += 1;
        }

        return .{
            .id = id,
            .title = title,
            .cwd = cwd,
            .worktree_root = worktree_root,
            .profile = .{
                .theme_name = theme_name,
                .font_family = font_family,
                .font_size_pt = font_size_pt,
                .ligatures = ligatures,
            },
            .status = status,
            .selected = selected,
            .tags = tags,
            .agent_resume = .{},
        };
    }

    fn readAgentResume(self: *SnapshotReader) !Continuity.AgentResume {
        const enabled = try self.readBool();
        const provider = try Continuity.providerFromInt(try self.readU8());
        var reference = Continuity.AgentResume{ .enabled = enabled, .provider = provider };
        const session_id = try self.readStringAlloc();
        defer self.allocator.free(session_id);
        const label = try self.readStringAlloc();
        defer self.allocator.free(label);
        reference.session_id.set(session_id) catch return error.InvalidWorkspaceSnapshot;
        reference.label.set(label) catch return error.InvalidWorkspaceSnapshot;
        reference.validate() catch return error.InvalidWorkspaceSnapshot;
        return reference;
    }

    fn readOptionalTabAccent(self: *SnapshotReader) !?TabAccent {
        if (!try self.readBool()) return null;
        const preset_raw = try self.readU8();
        if (preset_raw > @intFromEnum(TabColorPreset.pink))
            return error.InvalidWorkspaceSnapshot;
        const preset: TabColorPreset = @enumFromInt(preset_raw);
        const encoded_shade = try self.readU8();
        const shade_range: u8 = @intCast(TabAccent.max_shade - TabAccent.min_shade);
        if (encoded_shade > shade_range) return error.InvalidWorkspaceSnapshot;
        return .{
            .preset = preset,
            .shade = @as(i8, @intCast(encoded_shade)) + TabAccent.min_shade,
        };
    }

    fn readProjectPanels(self: *SnapshotReader) !ProjectPanelState {
        var panels = ProjectPanelState{};
        errdefer panels.deinit(self.allocator);

        const status_count = try self.readU64AsUsize();
        panels.git_status = try self.allocator.alloc(GitStatusEntry, status_count);
        for (panels.git_status) |*entry| entry.* = .{};
        for (panels.git_status) |*entry| {
            entry.* = try self.readGitStatusEntry();
        }

        const graph_count = try self.readU64AsUsize();
        panels.git_graph = try self.allocator.alloc(GitGraphNode, graph_count);
        for (panels.git_graph) |*node| node.* = .{};
        for (panels.git_graph) |*node| {
            node.* = try self.readGitGraphNode();
        }

        const file_count = try self.readU64AsUsize();
        panels.files = try self.allocator.alloc(ProjectFileEntry, file_count);
        for (panels.files) |*entry| entry.* = .{};
        for (panels.files) |*entry| {
            entry.* = try self.readProjectFileEntry();
        }

        return panels;
    }

    fn readGitStatusEntry(self: *SnapshotReader) !GitStatusEntry {
        const path = try self.readStringAlloc();
        errdefer self.allocator.free(path);
        if (path.len == 0) return error.InvalidWorkspaceSnapshot;
        return .{
            .path = path,
            .state = try self.readGitFileState(),
        };
    }

    fn readGitGraphNode(self: *SnapshotReader) !GitGraphNode {
        const commit = try self.readStringAlloc();
        errdefer self.allocator.free(commit);
        const summary = try self.readStringAlloc();
        errdefer self.allocator.free(summary);
        const branch = try self.readOptionalStringAlloc();
        errdefer if (branch) |branch_name| self.allocator.free(branch_name);
        if (commit.len == 0 or summary.len == 0) return error.InvalidWorkspaceSnapshot;
        return .{
            .commit = commit,
            .summary = summary,
            .branch = branch,
        };
    }

    fn readProjectFileEntry(self: *SnapshotReader) !ProjectFileEntry {
        const path = try self.readStringAlloc();
        errdefer self.allocator.free(path);
        if (path.len == 0) return error.InvalidWorkspaceSnapshot;
        return .{
            .path = path,
            .kind = try self.readProjectFileKind(),
            .dirty = try self.readBool(),
        };
    }

    fn readNode(self: *SnapshotReader) !Node {
        return .{
            .kind = try self.readNodeKind(),
            .pane_id = try self.readU64(),
            .axis = try self.readAxis(),
            .first = try self.readOptionalU64AsUsize(),
            .second = try self.readOptionalU64AsUsize(),
            .ratio_permille = try self.readU16(),
        };
    }

    fn readStringAlloc(self: *SnapshotReader) ![]u8 {
        const len = try self.readU64AsUsize();
        if (self.offset + len > self.bytes.len) return error.InvalidWorkspaceSnapshot;
        const slice = self.bytes[self.offset .. self.offset + len];
        self.offset += len;
        return self.allocator.dupe(u8, slice);
    }

    fn readOptionalStringAlloc(self: *SnapshotReader) !?[]u8 {
        return if (try self.readBool()) try self.readStringAlloc() else null;
    }

    fn readOptionalU64AsUsize(self: *SnapshotReader) !?usize {
        return if (try self.readBool()) try self.readU64AsUsize() else null;
    }

    fn readTabPosition(self: *SnapshotReader) !Config.TabPosition {
        return switch (try self.readU8()) {
            0 => .top,
            1 => .bottom,
            2 => .left,
            3 => .right,
            else => error.InvalidWorkspaceSnapshot,
        };
    }

    fn readNodeKind(self: *SnapshotReader) !Node.Kind {
        return switch (try self.readU8()) {
            0 => .leaf,
            1 => .split,
            else => error.InvalidWorkspaceSnapshot,
        };
    }

    fn readAxis(self: *SnapshotReader) !Axis {
        return switch (try self.readU8()) {
            0 => .horizontal,
            1 => .vertical,
            else => error.InvalidWorkspaceSnapshot,
        };
    }

    fn readStatus(self: *SnapshotReader) !Terminal.TerminalStatus {
        return switch (try self.readU8()) {
            0 => .idle,
            1 => .running,
            2 => .pending_interaction,
            3 => .done,
            4 => .@"error",
            5 => .long_running,
            else => error.InvalidWorkspaceSnapshot,
        };
    }

    fn readGitFileState(self: *SnapshotReader) !GitFileState {
        return switch (try self.readU8()) {
            0 => .unmodified,
            1 => .modified,
            2 => .added,
            3 => .deleted,
            4 => .renamed,
            5 => .untracked,
            6 => .conflicted,
            7 => .ignored,
            else => error.InvalidWorkspaceSnapshot,
        };
    }

    fn readProjectFileKind(self: *SnapshotReader) !ProjectFileKind {
        return switch (try self.readU8()) {
            0 => .file,
            1 => .directory,
            else => error.InvalidWorkspaceSnapshot,
        };
    }

    fn readBool(self: *SnapshotReader) !bool {
        return switch (try self.readU8()) {
            0 => false,
            1 => true,
            else => error.InvalidWorkspaceSnapshot,
        };
    }

    fn readU8(self: *SnapshotReader) !u8 {
        if (self.offset >= self.bytes.len) return error.InvalidWorkspaceSnapshot;
        const value = self.bytes[self.offset];
        self.offset += 1;
        return value;
    }

    fn readU16(self: *SnapshotReader) !u16 {
        return @intCast(try self.readIntLittle(2));
    }

    fn readU32(self: *SnapshotReader) !u32 {
        return @intCast(try self.readIntLittle(4));
    }

    fn readU64(self: *SnapshotReader) !u64 {
        return try self.readIntLittle(8);
    }

    fn readU64AsUsize(self: *SnapshotReader) !usize {
        const value = try self.readU64();
        if (value > std.math.maxInt(usize)) return error.InvalidWorkspaceSnapshot;
        return @intCast(value);
    }

    fn readIntLittle(self: *SnapshotReader, comptime byte_count: usize) !u64 {
        if (self.offset + byte_count > self.bytes.len) return error.InvalidWorkspaceSnapshot;
        var value: u64 = 0;
        var idx: usize = 0;
        while (idx < byte_count) : (idx += 1) {
            const shift: u6 = @intCast(idx * 8);
            value |= @as(u64, self.bytes[self.offset + idx]) << shift;
        }
        self.offset += byte_count;
        return value;
    }
};
pub const TabStatusLine = struct {
    status: Terminal.TerminalStatus,
    count: usize,
    attention: bool,
};

pub const TabStatusSummary = struct {
    total: usize = 0,
    attention_total: usize = 0,
    lines: [6]TabStatusLine = undefined,
    line_count: usize = 0,

    pub fn fromStats(stats: TabStats) TabStatusSummary {
        var summary = TabStatusSummary{
            .total = stats.total,
            .attention_total = stats.attentionTotal(),
        };
        summary.appendIfPresent(stats, .@"error");
        summary.appendIfPresent(stats, .pending_interaction);
        summary.appendIfPresent(stats, .long_running);
        summary.appendIfPresent(stats, .running);
        summary.appendIfPresent(stats, .done);
        summary.appendIfPresent(stats, .idle);
        return summary;
    }

    pub fn formatCompact(self: TabStatusSummary, writer: anytype) !void {
        try writer.print("{d} pane{s}", .{ self.total, pluralSuffix(self.total) });
        for (self.lines[0..self.line_count]) |line| {
            if (line.status == .idle and self.line_count > 1) continue;
            try writer.print(" {s}:{d}", .{ Terminal.statusShortLabel(line.status), line.count });
        }
    }

    pub fn formatTooltip(self: TabStatusSummary, writer: anytype) !void {
        try writer.print("{d} terminal pane{s}", .{ self.total, pluralSuffix(self.total) });
        if (self.attention_total > 0) {
            try writer.print(", {d} need{s} attention", .{ self.attention_total, singularVerbSuffix(self.attention_total) });
        }
        try writer.writeAll("\n");
        for (self.lines[0..self.line_count]) |line| {
            try writer.print("{s}: {d}", .{ Terminal.statusLabel(line.status), line.count });
            if (line.attention) try writer.writeAll(" (attention)");
            try writer.writeAll("\n");
        }
    }

    fn appendIfPresent(self: *TabStatusSummary, stats: TabStats, status: Terminal.TerminalStatus) void {
        const count = stats.countForStatus(status);
        if (count == 0) return;
        self.lines[self.line_count] = .{
            .status = status,
            .count = count,
            .attention = Terminal.isAttentionStatus(status),
        };
        self.line_count += 1;
    }
};

pub const Tab = struct {
    allocator: std.mem.Allocator,
    id: u64,
    title: []u8,
    title_overridden: bool = false,
    accent: ?TabAccent = null,
    position: Config.TabPosition = .top,
    panes: std.array_list.Managed(Terminal.Pane),
    layout: SplitLayout,
    active_pane_id: Terminal.PaneId,
    zoomed_pane_id: ?Terminal.PaneId = null,

    pub fn init(allocator: std.mem.Allocator, id: u64, title: []const u8, cwd: []const u8, first_pane_id: Terminal.PaneId) !Tab {
        var tab = Tab{
            .allocator = allocator,
            .id = id,
            .title = try allocator.dupe(u8, title),
            .panes = std.array_list.Managed(Terminal.Pane).init(allocator),
            .layout = SplitLayout.init(allocator),
            .active_pane_id = first_pane_id,
        };
        errdefer tab.deinit();

        const pane_title = try std.fmt.allocPrint(allocator, "terminal-{d}", .{first_pane_id});
        defer allocator.free(pane_title);
        const pane = try Terminal.Pane.init(allocator, first_pane_id, pane_title, cwd);
        try tab.panes.append(pane);
        try tab.layout.setSingle(first_pane_id);
        return tab;
    }

    pub fn deinit(self: *Tab) void {
        for (self.panes.items) |*pane| pane.deinit();
        self.panes.deinit();
        self.layout.deinit();
        self.allocator.free(self.title);
    }

    pub fn rename(self: *Tab, requested_title: []const u8) ![]const u8 {
        const title = std.mem.trim(u8, requested_title, " \t\r\n");
        if (title.len == 0) return error.InvalidTabTitle;
        if (title.len > 128) return error.TabTitleTooLong;
        if (!std.unicode.utf8ValidateSlice(title)) return error.InvalidTabTitleEncoding;
        for (title) |byte| {
            if (byte < 0x20 or byte == 0x7f) return error.InvalidTabTitle;
        }

        const next = try self.allocator.dupe(u8, title);
        self.allocator.free(self.title);
        self.title = next;
        self.title_overridden = true;
        return self.title;
    }

    pub fn setAccent(self: *Tab, preset: ?TabColorPreset) ?TabAccent {
        self.accent = if (preset) |value| TabAccent.init(value) else null;
        return self.accent;
    }

    pub fn adjustAccent(self: *Tab, delta: i8) TabAccent {
        const current = self.accent orelse TabAccent.init(TabAccent.default_preset);
        self.accent = current.adjusted(delta);
        return self.accent.?;
    }

    pub fn splitActive(self: *Tab, id: Terminal.PaneId, direction: SplitDirection) !Terminal.PaneId {
        const active = self.findPane(self.active_pane_id) orelse return error.ActivePaneMissing;
        const title = try std.fmt.allocPrint(self.allocator, "terminal-{d}", .{id});
        defer self.allocator.free(title);
        const pane = try active.cloneForSplit(id, title);
        try self.panes.append(pane);
        try self.layout.splitPane(self.active_pane_id, id, direction);
        self.active_pane_id = id;
        self.zoomed_pane_id = null;
        return id;
    }

    pub fn closePane(self: *Tab, pane_id: Terminal.PaneId) !Terminal.PaneId {
        var pane_index: ?usize = null;
        for (self.panes.items, 0..) |pane, index| {
            if (pane.id == pane_id) {
                pane_index = index;
                break;
            }
        }
        const index = pane_index orelse return error.PaneNotFound;
        if (self.panes.items.len <= 1) return error.CannotCloseLastPane;
        try self.layout.removePane(pane_id);
        var removed = self.panes.orderedRemove(index);
        removed.deinit();
        if (self.active_pane_id == pane_id) {
            const next_index = @min(index, self.panes.items.len - 1);
            self.active_pane_id = self.panes.items[next_index].id;
        }
        self.zoomed_pane_id = null;
        return self.active_pane_id;
    }

    pub fn applyPreset(self: *Tab, preset: LayoutPreset, next_id: *Terminal.PaneId) !void {
        const dimensions = preset.dimensions();
        const target_count = dimensions.rows * dimensions.cols;
        while (self.panes.items.len > target_count) {
            var pane = self.panes.pop().?;
            pane.deinit();
        }
        while (self.panes.items.len < target_count) {
            const id = next_id.*;
            next_id.* += 1;
            const title = try std.fmt.allocPrint(self.allocator, "terminal-{d}", .{id});
            defer self.allocator.free(title);
            const base = self.panes.items[0];
            try self.panes.append(try base.cloneForSplit(id, title));
        }

        const rows = dimensions.rows;
        const cols = dimensions.cols;
        const ids = try self.allocator.alloc(Terminal.PaneId, target_count);
        defer self.allocator.free(ids);
        for (ids, 0..) |*slot, idx| slot.* = self.panes.items[idx].id;
        try self.layout.setGrid(ids, rows, cols);
        self.active_pane_id = ids[0];
        self.zoomed_pane_id = null;
    }

    pub fn selectPane(self: *Tab, pane_id: Terminal.PaneId, mode: SelectionMode) !void {
        const pane = self.findPane(pane_id) orelse return error.PaneNotFound;
        switch (mode) {
            .replace => {
                for (self.panes.items) |*candidate| candidate.selected = false;
                pane.selected = true;
            },
            .add => pane.selected = true,
            .toggle => pane.selected = !pane.selected,
        }
    }

    pub fn focusPaneRelative(self: *Tab, forward: bool) !Terminal.PaneId {
        if (self.panes.items.len == 0) return error.PaneNotFound;
        var index: usize = 0;
        for (self.panes.items, 0..) |pane, idx| {
            if (pane.id == self.active_pane_id) {
                index = idx;
                break;
            }
        }
        index = if (forward) (index + 1) % self.panes.items.len else if (index == 0) self.panes.items.len - 1 else index - 1;
        self.active_pane_id = self.panes.items[index].id;
        return self.active_pane_id;
    }

    pub fn togglePaneZoom(self: *Tab, pane_id: Terminal.PaneId) !?Terminal.PaneId {
        _ = self.findPane(pane_id) orelse return error.PaneNotFound;
        self.active_pane_id = pane_id;
        self.zoomed_pane_id = if (self.zoomed_pane_id == pane_id) null else pane_id;
        return self.zoomed_pane_id;
    }

    pub fn findPane(self: *Tab, id: Terminal.PaneId) ?*Terminal.Pane {
        for (self.panes.items) |*pane| {
            if (pane.id == id) return pane;
        }
        return null;
    }

    pub fn stats(self: Tab) TabStats {
        var result = TabStats{};
        result.total = self.panes.items.len;
        for (self.panes.items) |pane| {
            switch (pane.status) {
                .idle => result.idle += 1,
                .running => result.running += 1,
                .pending_interaction => result.pending_interaction += 1,
                .done => result.done += 1,
                .@"error" => result.@"error" += 1,
                .long_running => result.long_running += 1,
            }
        }
        return result;
    }

    pub fn statusSummary(self: Tab) TabStatusSummary {
        return TabStatusSummary.fromStats(self.stats());
    }

    pub fn selectedPaneIds(self: Tab, allocator: std.mem.Allocator) ![]Terminal.PaneId {
        var ids = std.array_list.Managed(Terminal.PaneId).init(allocator);
        errdefer ids.deinit();
        for (self.panes.items) |pane| {
            if (pane.selected) try ids.append(pane.id);
        }
        return ids.toOwnedSlice();
    }
};

fn pluralSuffix(count: usize) []const u8 {
    return if (count == 1) "" else "s";
}

fn singularVerbSuffix(count: usize) []const u8 {
    return if (count == 1) "s" else "";
}

fn rebuildTabLayout(tab: *Tab) !void {
    if (tab.panes.items.len == 0) return error.EmptyTab;
    const ids = try tab.allocator.alloc(Terminal.PaneId, tab.panes.items.len);
    defer tab.allocator.free(ids);
    for (tab.panes.items, 0..) |pane, index| ids[index] = pane.id;
    try tab.layout.setGrid(ids, 1, ids.len);
    if (tab.findPane(tab.active_pane_id) == null) tab.active_pane_id = ids[0];
}

pub const Workspace = struct {
    allocator: std.mem.Allocator,
    tabs: std.array_list.Managed(Tab),
    active_tab: usize = 0,
    next_tab_id: u64 = 2,
    next_pane_id: Terminal.PaneId = 2,
    broadcast_enabled: bool = false,
    last_closed_tab: ?TabSnapshot = null,
    quick_note: []u8,
    project_panels: ProjectPanelState = .{},
    smart_filter_tag: ?[]u8 = null,

    pub fn init(allocator: std.mem.Allocator, cwd: []const u8) !Workspace {
        var workspace = Workspace{
            .allocator = allocator,
            .tabs = std.array_list.Managed(Tab).init(allocator),
            .quick_note = try allocator.dupe(u8, ""),
        };
        errdefer workspace.deinit();
        try workspace.tabs.append(try Tab.init(allocator, 1, "Tab 1", cwd, 1));
        return workspace;
    }

    pub fn deinit(self: *Workspace) void {
        for (self.tabs.items) |*tab| tab.deinit();
        self.tabs.deinit();
        if (self.last_closed_tab) |*tab| tab.deinit(self.allocator);
        self.allocator.free(self.quick_note);
        if (self.smart_filter_tag) |tag| self.allocator.free(tag);
        self.project_panels.deinit(self.allocator);
    }

    pub fn captureSnapshot(self: Workspace) !ProjectSnapshot {
        const tabs = try self.allocator.alloc(TabSnapshot, self.tabs.items.len);
        errdefer self.allocator.free(tabs);
        var initialized_tabs: usize = 0;
        errdefer {
            for (tabs[0..initialized_tabs]) |*tab| tab.deinit(self.allocator);
        }

        for (self.tabs.items, 0..) |tab, idx| {
            tabs[idx] = try self.captureTabSnapshot(tab);
            initialized_tabs += 1;
        }

        var project_panels = try self.project_panels.clone(self.allocator);
        errdefer project_panels.deinit(self.allocator);
        const quick_note = try self.allocator.dupe(u8, self.quick_note);
        errdefer self.allocator.free(quick_note);
        const smart_filter_tag = if (self.smart_filter_tag) |tag|
            try self.allocator.dupe(u8, tag)
        else
            null;
        errdefer if (smart_filter_tag) |tag| self.allocator.free(tag);

        return .{
            .tabs = tabs,
            .active_tab = self.active_tab,
            .next_tab_id = self.next_tab_id,
            .next_pane_id = self.next_pane_id,
            .broadcast_enabled = self.broadcast_enabled,
            .quick_note = quick_note,
            .smart_filter_tag = smart_filter_tag,
            .project_panels = project_panels,
        };
    }

    pub fn restoreSnapshot(self: *Workspace, snapshot: ProjectSnapshot) !void {
        if (snapshot.tabs.len == 0) return error.EmptyWorkspaceSnapshot;
        if (snapshot.active_tab >= snapshot.tabs.len) return error.InvalidWorkspaceSnapshot;

        for (snapshot.tabs, 0..) |tab_snapshot, tab_index| {
            try self.validateTabSnapshot(tab_snapshot);
            if (tab_snapshot.id == 0) return error.InvalidWorkspaceSnapshot;
            for (snapshot.tabs[0..tab_index]) |prior_tab| {
                if (prior_tab.id == tab_snapshot.id) return error.InvalidWorkspaceSnapshot;
            }
            for (tab_snapshot.panes, 0..) |pane_snapshot, pane_index| {
                if (pane_snapshot.id == 0) return error.InvalidWorkspaceSnapshot;
                for (tab_snapshot.panes[0..pane_index]) |prior_pane| {
                    if (prior_pane.id == pane_snapshot.id) return error.InvalidWorkspaceSnapshot;
                }
                for (snapshot.tabs[0..tab_index]) |prior_tab| {
                    for (prior_tab.panes) |prior_pane| {
                        if (prior_pane.id == pane_snapshot.id) return error.InvalidWorkspaceSnapshot;
                    }
                }
            }
        }

        var restored_tabs = std.array_list.Managed(Tab).init(self.allocator);
        errdefer {
            for (restored_tabs.items) |*tab| tab.deinit();
            restored_tabs.deinit();
        }

        for (snapshot.tabs) |tab_snapshot| {
            try restored_tabs.append(try self.restoreTabSnapshot(tab_snapshot));
        }

        var restored_panels = try snapshot.project_panels.clone(self.allocator);
        errdefer restored_panels.deinit(self.allocator);
        const restored_quick_note = try self.allocator.dupe(u8, snapshot.quick_note);
        errdefer self.allocator.free(restored_quick_note);
        const restored_smart_filter_tag = if (snapshot.smart_filter_tag) |tag|
            try self.allocator.dupe(u8, tag)
        else
            null;
        errdefer if (restored_smart_filter_tag) |tag| self.allocator.free(tag);

        for (self.tabs.items) |*tab| tab.deinit();
        self.tabs.deinit();
        self.allocator.free(self.quick_note);
        self.project_panels.deinit(self.allocator);
        self.tabs = restored_tabs;
        self.active_tab = snapshot.active_tab;
        self.next_tab_id = snapshot.next_tab_id;
        self.next_pane_id = snapshot.next_pane_id;
        self.broadcast_enabled = snapshot.broadcast_enabled;
        if (self.smart_filter_tag) |tag| self.allocator.free(tag);
        self.smart_filter_tag = restored_smart_filter_tag;
        self.quick_note = restored_quick_note;
        self.project_panels = restored_panels;
        if (self.last_closed_tab) |*tab| tab.deinit(self.allocator);
        self.last_closed_tab = null;
    }

    pub fn activeTab(self: *Workspace) ?*Tab {
        if (self.tabs.items.len == 0) return null;
        return &self.tabs.items[self.active_tab];
    }

    pub fn findTab(self: *Workspace, tab_id: u64) ?*Tab {
        for (self.tabs.items) |*tab| {
            if (tab.id == tab_id) return tab;
        }
        return null;
    }

    pub fn findPane(self: *Workspace, pane_id: Terminal.PaneId) ?*Terminal.Pane {
        for (self.tabs.items) |*tab| {
            if (tab.findPane(pane_id)) |pane| return pane;
        }
        return null;
    }

    pub fn tagSelectedPanes(self: *Workspace, tag: []const u8) !usize {
        const active = self.activeTab() orelse return error.NoActiveTab;
        const trimmed = std.mem.trim(u8, tag, " \t\r\n");
        if (trimmed.len == 0) return error.EmptyTag;
        var changed: usize = 0;
        for (active.panes.items) |*pane| {
            if (pane.selected and !pane.hasTag(trimmed)) {
                try pane.addTag(trimmed);
                changed += 1;
            }
        }
        return changed;
    }

    pub fn removeTagFromSelectedPanes(self: *Workspace, tag: []const u8) usize {
        const active = self.activeTab() orelse return 0;
        const trimmed = std.mem.trim(u8, tag, " \t\r\n");
        if (trimmed.len == 0) return 0;
        var changed: usize = 0;
        for (active.panes.items) |*pane| {
            if (pane.selected and pane.removeTag(trimmed)) changed += 1;
        }
        return changed;
    }

    pub fn knownTags(self: *Workspace, allocator: std.mem.Allocator) ![][]const u8 {
        var known = std.array_list.Managed([]const u8).init(allocator);
        errdefer known.deinit();
        for (self.tabs.items) |tab| {
            for (tab.panes.items) |pane| {
                for (pane.tags.items) |tag| {
                    var duplicate = false;
                    for (known.items) |existing| {
                        if (std.mem.eql(u8, existing, tag)) {
                            duplicate = true;
                            break;
                        }
                    }
                    if (!duplicate) try known.append(tag);
                }
            }
        }
        return known.toOwnedSlice();
    }

    pub fn setSmartFilterTag(self: *Workspace, tag: ?[]const u8) !void {
        if (self.smart_filter_tag) |old| self.allocator.free(old);
        self.smart_filter_tag = null;
        if (tag) |value| {
            const trimmed = std.mem.trim(u8, value, " \t\r\n");
            if (trimmed.len > 0) self.smart_filter_tag = try self.allocator.dupe(u8, trimmed);
        }
    }

    pub fn paneMatchesSmartFilter(self: Workspace, pane_id: Terminal.PaneId) bool {
        const tag = self.smart_filter_tag orelse return true;
        for (self.tabs.items) |tab| {
            for (tab.panes.items) |pane| {
                if (pane.id == pane_id) return pane.hasTag(tag);
            }
        }
        return false;
    }

    pub fn activatePane(self: *Workspace, pane_id: Terminal.PaneId) !void {
        for (self.tabs.items, 0..) |*tab, tab_index| {
            if (tab.findPane(pane_id) != null) {
                self.active_tab = tab_index;
                tab.active_pane_id = pane_id;
                return;
            }
        }
        return error.PaneNotFound;
    }

    pub fn addTab(self: *Workspace, title: []const u8, cwd: []const u8) !u64 {
        const id = self.next_tab_id;
        self.next_tab_id += 1;
        const pane_id = self.next_pane_id;
        self.next_pane_id += 1;
        try self.tabs.append(try Tab.init(self.allocator, id, title, cwd, pane_id));
        self.active_tab = self.tabs.items.len - 1;
        return id;
    }

    pub fn addDefaultTab(self: *Workspace, cwd: []const u8) !u64 {
        const title = try std.fmt.allocPrint(self.allocator, "Tab {d}", .{self.next_tab_id});
        defer self.allocator.free(title);
        return self.addTab(title, cwd);
    }

    pub fn reorderTab(self: *Workspace, tab_id: u64, destination_index: usize) !void {
        var source_index: ?usize = null;
        for (self.tabs.items, 0..) |tab, index| {
            if (tab.id == tab_id) {
                source_index = index;
                break;
            }
        }
        const source = source_index orelse return error.TabNotFound;
        if (self.tabs.items.len == 0) return error.EmptyWorkspace;
        const target = @min(destination_index, self.tabs.items.len - 1);
        const active_id = self.activeTab().?.id;
        if (source != target) {
            const moved = self.tabs.items[source];
            if (source < target) {
                std.mem.copyForwards(Tab, self.tabs.items[source..target], self.tabs.items[source + 1 .. target + 1]);
            } else {
                std.mem.copyBackwards(Tab, self.tabs.items[target + 1 .. source + 1], self.tabs.items[target..source]);
            }
            self.tabs.items[target] = moved;
        }
        for (self.tabs.items, 0..) |tab, index| {
            if (tab.id == active_id) {
                self.active_tab = index;
                break;
            }
        }
    }

    pub fn renameTab(self: *Workspace, tab_id: u64, title: []const u8) ![]const u8 {
        const tab = self.findTab(tab_id) orelse return error.TabNotFound;
        return tab.rename(title);
    }

    pub fn setTabAccent(self: *Workspace, tab_id: u64, preset: ?TabColorPreset) !?TabAccent {
        const tab = self.findTab(tab_id) orelse return error.TabNotFound;
        return tab.setAccent(preset);
    }

    pub fn adjustTabAccent(self: *Workspace, tab_id: u64, delta: i8) !TabAccent {
        if (delta == 0) return error.InvalidTabAccentAdjustment;
        const tab = self.findTab(tab_id) orelse return error.TabNotFound;
        return tab.adjustAccent(if (delta > 0) 1 else -1);
    }

    pub fn closeTab(self: *Workspace, tab_id: u64) !TabCloseResult {
        var close_index: ?usize = null;
        for (self.tabs.items, 0..) |tab, index| {
            if (tab.id == tab_id) {
                close_index = index;
                break;
            }
        }
        const index = close_index orelse return error.TabNotFound;
        if (self.tabs.items.len <= 1) return error.CannotCloseLastTab;
        const closed_snapshot = try self.captureTabSnapshot(self.tabs.items[index]);
        const pane_count = self.tabs.items[index].panes.items.len;
        var removed = self.tabs.orderedRemove(index);
        removed.deinit();
        if (self.last_closed_tab) |*tab| tab.deinit(self.allocator);
        self.last_closed_tab = closed_snapshot;
        if (self.active_tab > index) {
            self.active_tab -= 1;
        } else if (self.active_tab == index and
            self.active_tab >= self.tabs.items.len)
        {
            self.active_tab = self.tabs.items.len - 1;
        }
        return .{
            .tab_id = tab_id,
            .pane_count = pane_count,
            .active_tab_id = self.tabs.items[self.active_tab].id,
        };
    }

    pub fn reopenLastClosedTab(self: *Workspace) !u64 {
        var snapshot = self.last_closed_tab orelse return error.NoClosedTab;
        self.last_closed_tab = null;
        errdefer snapshot.deinit(self.allocator);
        const tab = try self.restoreTabSnapshot(snapshot);
        const id = tab.id;
        snapshot.deinit(self.allocator);
        try self.tabs.append(tab);
        self.active_tab = self.tabs.items.len - 1;
        return id;
    }

    pub fn closePane(self: *Workspace, pane_id: Terminal.PaneId) !PaneCloseResult {
        var source_index: ?usize = null;
        for (self.tabs.items, 0..) |*tab, tab_index| {
            if (tab.findPane(pane_id) != null) {
                source_index = tab_index;
                break;
            }
        }
        const tab_index = source_index orelse return error.PaneNotFound;
        const tab_id = self.tabs.items[tab_index].id;
        if (self.tabs.items[tab_index].panes.items.len == 1) {
            if (self.tabs.items.len == 1) return error.CannotCloseLastTerminal;
            const closed = try self.closeTab(tab_id);
            const active = self.activeTab() orelse return error.NoActiveTab;
            return .{
                .pane_id = pane_id,
                .tab_id = tab_id,
                .tab_closed = true,
                .active_tab_id = closed.active_tab_id,
                .active_pane_id = active.active_pane_id,
            };
        }

        const active_pane_id = try self.tabs.items[tab_index].closePane(pane_id);
        const active = self.activeTab() orelse return error.NoActiveTab;
        return .{
            .pane_id = pane_id,
            .tab_id = tab_id,
            .tab_closed = false,
            .active_tab_id = active.id,
            .active_pane_id = if (self.active_tab == tab_index)
                active_pane_id
            else
                active.active_pane_id,
        };
    }

    pub fn splitActivePane(self: *Workspace, direction: SplitDirection) !Terminal.PaneId {
        const tab = self.activeTab() orelse return error.NoActiveTab;
        const id = self.next_pane_id;
        self.next_pane_id += 1;
        return tab.splitActive(id, direction);
    }

    pub fn setQuickNote(self: *Workspace, text: []const u8) !usize {
        if (text.len > 1024 * 1024) return error.QuickNoteTooLarge;
        const next = try self.allocator.dupe(u8, text);
        self.allocator.free(self.quick_note);
        self.quick_note = next;
        return self.quick_note.len;
    }

    pub fn movePaneToTab(self: *Workspace, pane_id: Terminal.PaneId, target_tab_id: u64) !void {
        var source_index: ?usize = null;
        var pane_index: ?usize = null;
        for (self.tabs.items, 0..) |tab, tab_index| for (tab.panes.items, 0..) |pane, index| {
            if (pane.id == pane_id) {
                source_index = tab_index;
                pane_index = index;
            }
        };
        const source_idx = source_index orelse return error.PaneNotFound;
        var target_idx: ?usize = null;
        for (self.tabs.items, 0..) |tab, index| if (tab.id == target_tab_id) {
            target_idx = index;
            break;
        };
        const destination_idx = target_idx orelse return error.TabNotFound;
        if (source_idx == destination_idx) return;
        self.tabs.items[source_idx].zoomed_pane_id = null;
        self.tabs.items[destination_idx].zoomed_pane_id = null;
        try self.tabs.items[destination_idx].panes.ensureUnusedCapacity(1);
        const source_becomes_empty =
            self.tabs.items[source_idx].panes.items.len == 1;
        var pane = self.tabs.items[source_idx].panes.orderedRemove(pane_index.?);
        errdefer pane.deinit();
        var adjusted_destination_idx = destination_idx;
        if (source_becomes_empty) {
            var removed_tab = self.tabs.orderedRemove(source_idx);
            removed_tab.deinit();
            if (source_idx < destination_idx) adjusted_destination_idx -= 1;
        } else {
            try rebuildTabLayout(&self.tabs.items[source_idx]);
        }
        self.tabs.items[adjusted_destination_idx].panes.appendAssumeCapacity(pane);
        try rebuildTabLayout(&self.tabs.items[adjusted_destination_idx]);
        self.tabs.items[adjusted_destination_idx].active_pane_id = pane_id;
        self.active_tab = adjusted_destination_idx;
    }

    pub fn applyStatusEvent(self: *Workspace, pane_id: Terminal.PaneId, event: Terminal.StatusEvent, long_running_minutes: u16) !PaneStatusChange {
        const pane = self.findPane(pane_id) orelse return error.PaneNotFound;
        const previous = pane.status;
        const current = pane.applyStatusEvent(event, long_running_minutes);
        return .{
            .pane_id = pane_id,
            .previous = previous,
            .current = current,
        };
    }

    pub fn applyProfilePreset(self: *Workspace, pane_id: Terminal.PaneId, preset: Terminal.ProfilePreset, config: Config.Config) !PaneProfileChange {
        const pane = self.findPane(pane_id) orelse return error.PaneNotFound;
        const profile = try pane.applyProfilePreset(preset, config);
        return .{
            .pane_id = pane_id,
            .profile = profile,
        };
    }

    pub fn setPaneFontSize(self: *Workspace, pane_id: Terminal.PaneId, size: f32, font_config: Config.FontConfig) !PaneProfileChange {
        const pane = self.findPane(pane_id) orelse return error.PaneNotFound;
        var profile = pane.profile;
        profile.font_size_pt = size;
        try profile.validate(font_config);
        return .{
            .pane_id = pane_id,
            .profile = try pane.setProfile(profile),
        };
    }

    pub fn updateProjectPanels(self: *Workspace, update: ProjectPanelUpdate) !ProjectPanelSummary {
        var next = try ProjectPanelState.fromUpdate(self.allocator, update);
        errdefer next.deinit(self.allocator);
        self.project_panels.deinit(self.allocator);
        self.project_panels = next;
        return self.project_panels.summary();
    }

    pub fn projectPanelView(self: Workspace, options: ProjectPanelViewOptions) ProjectPanelView {
        return self.project_panels.view(options);
    }

    pub fn activateProjectPanelRow(self: Workspace, request: ProjectPanelActivationRequest) !ProjectPanelActivation {
        return self.project_panels.activate(request);
    }

    pub fn projectPanelActionPlan(self: Workspace, request: ProjectPanelActivationRequest) !ProjectPanelActionPlan {
        return (try self.activateProjectPanelRow(request)).actionPlan();
    }

    pub fn projectPanelActionExecutionSpec(self: Workspace, request: ProjectPanelActivationRequest) !ProjectPanelActionExecutionSpec {
        return ProjectPanelActionExecutionSpec.fromPlan(try self.projectPanelActionPlan(request));
    }

    pub fn applyPresetToActiveTab(self: *Workspace, preset: LayoutPreset) !void {
        const tab = self.activeTab() orelse return error.NoActiveTab;
        try tab.applyPreset(preset, &self.next_pane_id);
    }

    pub fn broadcastTargets(self: *Workspace, allocator: std.mem.Allocator) ![]Terminal.PaneId {
        const tab = self.activeTab() orelse return error.NoActiveTab;
        if (!self.broadcast_enabled) {
            const one = try allocator.alloc(Terminal.PaneId, 1);
            one[0] = tab.active_pane_id;
            return one;
        }
        var ids = std.array_list.Managed(Terminal.PaneId).init(allocator);
        errdefer ids.deinit();
        for (tab.panes.items) |pane| {
            if (pane.selected) try ids.append(pane.id);
        }
        if (ids.items.len == 0) {
            for (tab.panes.items) |pane| try ids.append(pane.id);
        }
        return ids.toOwnedSlice();
    }

    fn captureTabSnapshot(self: Workspace, tab: Tab) !TabSnapshot {
        const panes = try self.allocator.alloc(PaneSnapshot, tab.panes.items.len);
        errdefer self.allocator.free(panes);
        var initialized_panes: usize = 0;
        errdefer {
            for (panes[0..initialized_panes]) |*pane| pane.deinit(self.allocator);
        }

        for (tab.panes.items, 0..) |pane, idx| {
            panes[idx] = try self.capturePaneSnapshot(pane);
            initialized_panes += 1;
        }

        const nodes = try self.allocator.dupe(Node, tab.layout.nodes.items);
        errdefer self.allocator.free(nodes);

        return .{
            .id = tab.id,
            .title = try self.allocator.dupe(u8, tab.title),
            .title_overridden = tab.title_overridden,
            .accent = tab.accent,
            .position = tab.position,
            .active_pane_id = tab.active_pane_id,
            .panes = panes,
            .nodes = nodes,
            .root = tab.layout.root,
        };
    }

    fn capturePaneSnapshot(self: Workspace, pane: Terminal.Pane) !PaneSnapshot {
        const tags = try self.allocator.alloc([]u8, pane.tags.items.len);
        errdefer self.allocator.free(tags);
        var initialized_tags: usize = 0;
        errdefer {
            for (tags[0..initialized_tags]) |tag| self.allocator.free(tag);
        }

        for (pane.tags.items, 0..) |tag, idx| {
            tags[idx] = try self.allocator.dupe(u8, tag);
            initialized_tags += 1;
        }

        const title = try self.allocator.dupe(u8, pane.title);
        errdefer self.allocator.free(title);
        const cwd = try self.allocator.dupe(u8, pane.cwd);
        errdefer self.allocator.free(cwd);
        const worktree_root = if (pane.worktree_root) |root| try self.allocator.dupe(u8, root) else null;
        errdefer if (worktree_root) |root| self.allocator.free(root);
        const theme_name = try self.allocator.dupe(u8, pane.profile.theme_name);
        errdefer self.allocator.free(theme_name);
        const font_family = try self.allocator.dupe(u8, pane.profile.font_family);
        errdefer self.allocator.free(font_family);

        return .{
            .id = pane.id,
            .title = title,
            .cwd = cwd,
            .worktree_root = worktree_root,
            .profile = .{
                .theme_name = theme_name,
                .font_family = font_family,
                .font_size_pt = pane.profile.font_size_pt,
                .ligatures = pane.profile.ligatures,
            },
            .status = pane.status,
            .selected = pane.selected,
            .tags = tags,
            .agent_resume = pane.agent_resume,
        };
    }

    fn restoreTabSnapshot(self: Workspace, snapshot: TabSnapshot) !Tab {
        if (snapshot.panes.len == 0) return error.InvalidWorkspaceSnapshot;
        var tab = Tab{
            .allocator = self.allocator,
            .id = snapshot.id,
            .title = try self.allocator.dupe(u8, snapshot.title),
            .title_overridden = snapshot.title_overridden,
            .accent = snapshot.accent,
            .position = snapshot.position,
            .panes = std.array_list.Managed(Terminal.Pane).init(self.allocator),
            .layout = SplitLayout.init(self.allocator),
            .active_pane_id = snapshot.active_pane_id,
        };
        errdefer tab.deinit();

        for (snapshot.panes) |pane_snapshot| {
            try tab.panes.append(try self.restorePaneSnapshot(pane_snapshot));
        }

        try tab.layout.nodes.appendSlice(snapshot.nodes);
        tab.layout.root = snapshot.root;
        if (tab.findPane(tab.active_pane_id) == null) return error.InvalidWorkspaceSnapshot;
        return tab;
    }

    fn validateTabSnapshot(self: Workspace, snapshot: TabSnapshot) !void {
        if (snapshot.panes.len == 0 or snapshot.nodes.len == 0) return error.InvalidWorkspaceSnapshot;
        const root = snapshot.root orelse return error.InvalidWorkspaceSnapshot;
        if (root >= snapshot.nodes.len) return error.InvalidWorkspaceSnapshot;

        const visited_nodes = try self.allocator.alloc(bool, snapshot.nodes.len);
        defer self.allocator.free(visited_nodes);
        @memset(visited_nodes, false);
        const visited_panes = try self.allocator.alloc(bool, snapshot.panes.len);
        defer self.allocator.free(visited_panes);
        @memset(visited_panes, false);

        try validateSnapshotNode(snapshot, root, visited_nodes, visited_panes);
        for (visited_nodes) |visited| if (!visited) return error.InvalidWorkspaceSnapshot;
        for (visited_panes) |visited| if (!visited) return error.InvalidWorkspaceSnapshot;
    }

    fn validateSnapshotNode(
        snapshot: TabSnapshot,
        node_index: usize,
        visited_nodes: []bool,
        visited_panes: []bool,
    ) !void {
        if (node_index >= snapshot.nodes.len or visited_nodes[node_index]) return error.InvalidWorkspaceSnapshot;
        visited_nodes[node_index] = true;
        const node = snapshot.nodes[node_index];
        switch (node.kind) {
            .leaf => {
                if (node.first != null or node.second != null) return error.InvalidWorkspaceSnapshot;
                var pane_index: ?usize = null;
                for (snapshot.panes, 0..) |pane, index| {
                    if (pane.id == node.pane_id) {
                        pane_index = index;
                        break;
                    }
                }
                const index = pane_index orelse return error.InvalidWorkspaceSnapshot;
                if (visited_panes[index]) return error.InvalidWorkspaceSnapshot;
                visited_panes[index] = true;
            },
            .split => {
                const first = node.first orelse return error.InvalidWorkspaceSnapshot;
                const second = node.second orelse return error.InvalidWorkspaceSnapshot;
                if (first == second or node.ratio_permille > 1000) return error.InvalidWorkspaceSnapshot;
                try validateSnapshotNode(snapshot, first, visited_nodes, visited_panes);
                try validateSnapshotNode(snapshot, second, visited_nodes, visited_panes);
            },
        }
    }

    fn restorePaneSnapshot(self: Workspace, snapshot: PaneSnapshot) !Terminal.Pane {
        var pane = try Terminal.Pane.init(self.allocator, snapshot.id, snapshot.title, snapshot.cwd);
        errdefer pane.deinit();
        try pane.setWorktreeRoot(snapshot.worktree_root);
        _ = try pane.setProfile(snapshot.profile);
        pane.status = snapshot.status;
        pane.selected = snapshot.selected;
        try pane.setAgentResume(snapshot.agent_resume);
        for (snapshot.tags) |tag| try pane.addTag(tag);
        return pane;
    }
};

pub const TabCloseResult = struct {
    tab_id: u64,
    pane_count: usize,
    active_tab_id: u64,
};

pub const PaneCloseResult = struct {
    pane_id: Terminal.PaneId,
    tab_id: u64,
    tab_closed: bool,
    active_tab_id: u64,
    active_pane_id: Terminal.PaneId,
};

test "workspace gives new tabs numbered default titles" {
    var workspace = try Workspace.init(std.testing.allocator, "/tmp");
    defer workspace.deinit();

    try std.testing.expectEqualStrings("Tab 1", workspace.tabs.items[0].title);
    _ = try workspace.addDefaultTab("/tmp");
    _ = try workspace.addDefaultTab("/tmp");
    try std.testing.expectEqualStrings("Tab 2", workspace.tabs.items[1].title);
    try std.testing.expectEqualStrings("Tab 3", workspace.tabs.items[2].title);
    try std.testing.expect(!workspace.tabs.items[1].title_overridden);
}

test "workspace can split panes and report status counts" {
    const allocator = std.testing.allocator;
    var ws = try Workspace.init(allocator, "/tmp");
    defer ws.deinit();

    _ = try ws.splitActivePane(.right);
    _ = try ws.splitActivePane(.down);
    const tab = ws.activeTab().?;
    tab.findPane(2).?.status = .running;
    tab.findPane(3).?.status = .@"error";

    const stats = tab.stats();
    try std.testing.expectEqual(@as(usize, 3), stats.total);
    try std.testing.expectEqual(@as(usize, 1), stats.running);
    try std.testing.expectEqual(@as(usize, 1), stats.@"error");
}

test "workspace activates an exact pane across tabs" {
    var workspace = try Workspace.init(std.testing.allocator, "/tmp");
    defer workspace.deinit();

    _ = try workspace.splitActivePane(.down);
    _ = try workspace.addTab("second", "/tmp");
    try workspace.activatePane(2);

    try std.testing.expectEqual(@as(usize, 0), workspace.active_tab);
    try std.testing.expectEqual(@as(Terminal.PaneId, 2), workspace.activeTab().?.active_pane_id);
    try std.testing.expectError(error.PaneNotFound, workspace.activatePane(999));
}

test "workspace renames tabs with bounded durable titles" {
    var workspace = try Workspace.init(std.testing.allocator, "/tmp");
    defer workspace.deinit();

    const renamed = try workspace.renameTab(1, "  Build logs  ");
    try std.testing.expectEqualStrings("Build logs", renamed);
    try std.testing.expectEqualStrings("Build logs", workspace.tabs.items[0].title);
    try std.testing.expect(workspace.tabs.items[0].title_overridden);
    try std.testing.expectError(error.InvalidTabTitle, workspace.renameTab(1, "  \t "));
    try std.testing.expectError(error.TabNotFound, workspace.renameTab(99, "missing"));
    try std.testing.expectEqualStrings("Build logs", workspace.tabs.items[0].title);
}

test "workspace assigns reversible bounded tab accent shades" {
    var workspace = try Workspace.init(std.testing.allocator, "/tmp");
    defer workspace.deinit();

    const blue = (try workspace.setTabAccent(1, .blue)).?;
    try std.testing.expectEqual(TabColorPreset.blue, blue.preset);
    try std.testing.expectEqual(@as(i8, 0), blue.shade);
    try std.testing.expectEqual(@as(u32, 0x4285f4), blue.rgb());

    const lighter = try workspace.adjustTabAccent(1, 1);
    try std.testing.expectEqual(@as(i8, 1), lighter.shade);
    try std.testing.expect(lighter.rgb() > blue.rgb());
    const restored = try workspace.adjustTabAccent(1, -1);
    try std.testing.expectEqual(blue.rgb(), restored.rgb());

    for (0..10) |_| _ = try workspace.adjustTabAccent(1, -1);
    try std.testing.expectEqual(TabAccent.min_shade, workspace.tabs.items[0].accent.?.shade);
    for (0..20) |_| _ = try workspace.adjustTabAccent(1, 1);
    try std.testing.expectEqual(TabAccent.max_shade, workspace.tabs.items[0].accent.?.shade);

    _ = try workspace.setTabAccent(1, null);
    try std.testing.expect(workspace.tabs.items[0].accent == null);
    const seeded = try workspace.adjustTabAccent(1, -1);
    try std.testing.expectEqual(TabAccent.default_preset, seeded.preset);
    try std.testing.expectError(error.InvalidTabAccentAdjustment, workspace.adjustTabAccent(1, 0));
    try std.testing.expectError(error.TabNotFound, workspace.setTabAccent(99, .red));
}

test "workspace closes an exact background tab and preserves one tab" {
    var workspace = try Workspace.init(std.testing.allocator, "/tmp");
    defer workspace.deinit();

    _ = try workspace.splitActivePane(.down);
    const remaining_tab_id = try workspace.addTab("second", "/tmp");
    const closed = try workspace.closeTab(1);

    try std.testing.expectEqual(@as(u64, 1), closed.tab_id);
    try std.testing.expectEqual(@as(usize, 2), closed.pane_count);
    try std.testing.expectEqual(remaining_tab_id, closed.active_tab_id);
    try std.testing.expectEqual(@as(usize, 1), workspace.tabs.items.len);
    try std.testing.expectEqual(@as(usize, 0), workspace.active_tab);
    try std.testing.expect(workspace.findPane(1) == null);
    try std.testing.expect(workspace.findPane(2) == null);
    try std.testing.expectEqual(remaining_tab_id, workspace.activeTab().?.id);
    try std.testing.expectError(error.CannotCloseLastTab, workspace.closeTab(remaining_tab_id));
    try std.testing.expectError(error.TabNotFound, workspace.closeTab(999));
}

test "workspace closing active tabs selects an adjacent survivor" {
    var workspace = try Workspace.init(std.testing.allocator, "/tmp");
    defer workspace.deinit();

    const second_tab_id = try workspace.addTab("second", "/tmp");
    const third_tab_id = try workspace.addTab("third", "/tmp");
    const closed_third = try workspace.closeTab(third_tab_id);
    try std.testing.expectEqual(second_tab_id, closed_third.active_tab_id);
    try std.testing.expectEqual(@as(usize, 1), workspace.active_tab);

    const closed_second = try workspace.closeTab(second_tab_id);
    try std.testing.expectEqual(@as(u64, 1), closed_second.active_tab_id);
    try std.testing.expectEqual(@as(usize, 0), workspace.active_tab);
}

test "workspace reopens the last closed tab with its durable title" {
    var workspace = try Workspace.init(std.testing.allocator, "/tmp");
    defer workspace.deinit();

    _ = try workspace.renameTab(1, "Build logs");
    _ = try workspace.setTabAccent(1, .pink);
    _ = try workspace.adjustTabAccent(1, -1);
    _ = try workspace.addTab("second", "/tmp/agent");
    _ = try workspace.closeTab(1);
    const reopened = try workspace.reopenLastClosedTab();

    try std.testing.expectEqual(@as(u64, 1), reopened);
    try std.testing.expectEqualStrings("Build logs", workspace.activeTab().?.title);
    try std.testing.expectEqual(TabColorPreset.pink, workspace.activeTab().?.accent.?.preset);
    try std.testing.expectEqual(@as(i8, -1), workspace.activeTab().?.accent.?.shade);
    try std.testing.expectEqualStrings("/tmp", workspace.activeTab().?.panes.items[0].cwd);
    try std.testing.expectError(error.NoClosedTab, workspace.reopenLastClosedTab());
}

test "workspace reorders tabs while preserving the active tab identity" {
    var workspace = try Workspace.init(std.testing.allocator, "/tmp");
    defer workspace.deinit();

    const second = try workspace.addTab("second", "/tmp/second");
    const third = try workspace.addTab("third", "/tmp/third");
    try workspace.activatePane(2);
    try workspace.reorderTab(1, 2);

    try std.testing.expectEqual(@as(u64, 2), workspace.activeTab().?.id);
    try std.testing.expectEqual(second, workspace.tabs.items[0].id);
    try std.testing.expectEqual(third, workspace.tabs.items[1].id);
    try std.testing.expectEqual(@as(u64, 1), workspace.tabs.items[2].id);
}

test "workspace reorders tabs backward, clamps destinations, and keeps no-op identity" {
    var workspace = try Workspace.init(std.testing.allocator, "/tmp");
    defer workspace.deinit();

    _ = try workspace.addTab("second", "/tmp/second");
    const third = try workspace.addTab("third", "/tmp/third");

    try workspace.reorderTab(third, 0);
    try std.testing.expectEqualSlices(
        u64,
        &.{ third, 1, 2 },
        &.{ workspace.tabs.items[0].id, workspace.tabs.items[1].id, workspace.tabs.items[2].id },
    );
    try std.testing.expectEqual(third, workspace.activeTab().?.id);

    try workspace.reorderTab(1, 99);
    try std.testing.expectEqualSlices(
        u64,
        &.{ third, 2, 1 },
        &.{ workspace.tabs.items[0].id, workspace.tabs.items[1].id, workspace.tabs.items[2].id },
    );
    try std.testing.expectEqual(third, workspace.activeTab().?.id);

    try workspace.reorderTab(2, 1);
    try std.testing.expectEqualSlices(
        u64,
        &.{ third, 2, 1 },
        &.{ workspace.tabs.items[0].id, workspace.tabs.items[1].id, workspace.tabs.items[2].id },
    );
}

test "workspace moves a pane into another tab and activates it" {
    var workspace = try Workspace.init(std.testing.allocator, "/tmp");
    defer workspace.deinit();

    _ = try workspace.splitActivePane(.down);
    const target_tab_id = try workspace.addTab("second", "/tmp");
    try workspace.movePaneToTab(2, target_tab_id);

    try std.testing.expectEqual(@as(usize, 2), workspace.tabs.items.len);
    try std.testing.expectEqual(@as(usize, 1), workspace.tabs.items[0].panes.items.len);
    try std.testing.expectEqual(@as(usize, 2), workspace.tabs.items[1].panes.items.len);
    try std.testing.expectEqual(@as(usize, 1), workspace.active_tab);
    try std.testing.expectEqual(@as(Terminal.PaneId, 2), workspace.activeTab().?.active_pane_id);
}

test "workspace moving the last pane closes its source tab" {
    var workspace = try Workspace.init(std.testing.allocator, "/tmp");
    defer workspace.deinit();

    _ = try workspace.addTab("second", "/tmp");
    try workspace.movePaneToTab(2, 1);

    try std.testing.expectEqual(@as(usize, 1), workspace.tabs.items.len);
    try std.testing.expectEqual(@as(usize, 2), workspace.tabs.items[0].panes.items.len);
    try std.testing.expectEqual(@as(usize, 0), workspace.active_tab);
    try std.testing.expectEqual(@as(Terminal.PaneId, 2), workspace.activeTab().?.active_pane_id);
}

test "split down is vertical and split left is horizontal" {
    var workspace = try Workspace.init(std.testing.allocator, "/tmp");
    defer workspace.deinit();

    _ = try workspace.splitActivePane(.down);
    const tab = workspace.activeTab().?;
    try std.testing.expectEqual(Axis.vertical, tab.layout.nodes.items[tab.layout.root.?].axis);

    const active_leaf = tab.layout.findLeafByPane(tab.active_pane_id).?;
    _ = try workspace.splitActivePane(.left);
    try std.testing.expectEqual(Axis.horizontal, tab.layout.nodes.items[active_leaf].axis);
}

test "workspace closes an exact pane without flattening surviving topology" {
    var workspace = try Workspace.init(std.testing.allocator, "/tmp");
    defer workspace.deinit();

    _ = try workspace.splitActivePane(.down);
    _ = try workspace.splitActivePane(.left);
    const tab = workspace.activeTab().?;
    tab.zoomed_pane_id = 3;

    const closed = try workspace.closePane(3);
    try std.testing.expectEqual(@as(Terminal.PaneId, 3), closed.pane_id);
    try std.testing.expect(!closed.tab_closed);
    try std.testing.expectEqual(@as(Terminal.PaneId, 2), closed.active_pane_id);
    try std.testing.expectEqual(@as(usize, 2), tab.panes.items.len);
    try std.testing.expect(tab.findPane(3) == null);
    try std.testing.expectEqual(@as(?Terminal.PaneId, null), tab.zoomed_pane_id);
    const root = tab.layout.nodes.items[tab.layout.root.?];
    try std.testing.expectEqual(Node.Kind.split, root.kind);
    try std.testing.expectEqual(Axis.vertical, root.axis);
    try std.testing.expect(tab.layout.findLeafByPane(1) != null);
    try std.testing.expect(tab.layout.findLeafByPane(2) != null);
    try std.testing.expect(tab.layout.findLeafByPane(3) == null);
}

test "workspace pane close preserves an inactive survivor and protects final terminal" {
    var workspace = try Workspace.init(std.testing.allocator, "/tmp");
    defer workspace.deinit();

    _ = try workspace.splitActivePane(.right);
    const tab = workspace.activeTab().?;
    try workspace.activatePane(1);
    const closed = try workspace.closePane(2);
    try std.testing.expectEqual(@as(Terminal.PaneId, 1), closed.active_pane_id);
    try std.testing.expectEqual(@as(Terminal.PaneId, 1), tab.active_pane_id);
    try std.testing.expectError(error.CannotCloseLastTerminal, workspace.closePane(1));
    try std.testing.expectError(error.PaneNotFound, workspace.closePane(99));
}

test "workspace closes a sole-pane tab through terminal close" {
    var workspace = try Workspace.init(std.testing.allocator, "/tmp");
    defer workspace.deinit();

    _ = try workspace.addTab("second", "/tmp");
    const closed = try workspace.closePane(2);
    try std.testing.expect(closed.tab_closed);
    try std.testing.expectEqual(@as(u64, 2), closed.tab_id);
    try std.testing.expectEqual(@as(u64, 1), closed.active_tab_id);
    try std.testing.expectEqual(@as(Terminal.PaneId, 1), closed.active_pane_id);
    try std.testing.expectEqual(@as(usize, 1), workspace.tabs.items.len);
}

test "tab status summary formats compact counts and tooltip breakdowns" {
    const allocator = std.testing.allocator;
    var ws = try Workspace.init(allocator, "/tmp");
    defer ws.deinit();

    _ = try ws.splitActivePane(.right);
    _ = try ws.splitActivePane(.down);
    const tab = ws.activeTab().?;
    tab.findPane(1).?.status = .idle;
    tab.findPane(2).?.status = .pending_interaction;
    tab.findPane(3).?.status = .@"error";

    const summary = tab.statusSummary();
    try std.testing.expectEqual(@as(usize, 3), summary.total);
    try std.testing.expectEqual(@as(usize, 2), summary.attention_total);
    try std.testing.expectEqual(Terminal.TerminalStatus.@"error", summary.lines[0].status);
    try std.testing.expect(summary.lines[0].attention);

    var compact_buf: [96]u8 = undefined;
    var compact_writer = std.Io.Writer.fixed(&compact_buf);
    try summary.formatCompact(&compact_writer);
    try std.testing.expectEqualStrings("3 panes err:1 wait:1", compact_writer.buffered());

    var tooltip_buf: [256]u8 = undefined;
    var tooltip_writer = std.Io.Writer.fixed(&tooltip_buf);
    try summary.formatTooltip(&tooltip_writer);
    try std.testing.expectEqualStrings(
        \\3 terminal panes, 2 need attention
        \\Error: 1 (attention)
        \\Pending input: 1 (attention)
        \\Idle: 1
        \\
    , tooltip_writer.buffered());
}

test "tab status summary keeps all-idle tabs explicit" {
    const allocator = std.testing.allocator;
    var ws = try Workspace.init(allocator, "/tmp");
    defer ws.deinit();

    const summary = ws.activeTab().?.statusSummary();
    var compact_buf: [64]u8 = undefined;
    var compact_writer = std.Io.Writer.fixed(&compact_buf);
    try summary.formatCompact(&compact_writer);
    try std.testing.expectEqualStrings("1 pane idle:1", compact_writer.buffered());

    var tooltip_buf: [128]u8 = undefined;
    var tooltip_writer = std.Io.Writer.fixed(&tooltip_buf);
    try summary.formatTooltip(&tooltip_writer);
    try std.testing.expectEqualStrings(
        \\1 terminal pane
        \\Idle: 1
        \\
    , tooltip_writer.buffered());
}

test "workspace presets create compact grids" {
    const allocator = std.testing.allocator;
    var ws = try Workspace.init(allocator, "/tmp");
    defer ws.deinit();

    try ws.applyPresetToActiveTab(.two_by_two);
    const tab = ws.activeTab().?;
    try std.testing.expectEqual(@as(usize, 4), tab.panes.items.len);
    try std.testing.expect(tab.layout.root != null);

    try ws.applyPresetToActiveTab(.four_by_two);
    try std.testing.expectEqual(@as(usize, 8), tab.panes.items.len);
    const two_row_root = tab.layout.nodes.items[tab.layout.root.?];
    try std.testing.expectEqual(Axis.vertical, two_row_root.axis);
    try std.testing.expectEqual(@as(u16, 500), two_row_root.ratio_permille);
    const first_four = tab.layout.nodes.items[two_row_root.first.?];
    try std.testing.expectEqual(Axis.horizontal, first_four.axis);
    try std.testing.expectEqual(@as(u16, 250), first_four.ratio_permille);

    try ws.applyPresetToActiveTab(.three_by_three);
    try std.testing.expectEqual(@as(usize, 9), tab.panes.items.len);
    const root = tab.layout.nodes.items[tab.layout.root.?];
    try std.testing.expectEqual(Axis.vertical, root.axis);
    try std.testing.expectEqual(@as(u16, 333), root.ratio_permille);
    const first_row = tab.layout.nodes.items[root.first.?];
    try std.testing.expectEqual(Axis.horizontal, first_row.axis);
    try std.testing.expectEqual(@as(u16, 333), first_row.ratio_permille);
    const remaining_rows = tab.layout.nodes.items[root.second.?];
    try std.testing.expectEqual(@as(u16, 500), remaining_rows.ratio_permille);

    const first_nine = [_]Terminal.PaneId{ 1, 2, 3, 4, 5, 6, 7, 8, 9 };
    try ws.applyPresetToActiveTab(.four_by_four);
    try std.testing.expectEqual(@as(usize, 16), tab.panes.items.len);
    for (first_nine, tab.panes.items[0..first_nine.len]) |expected, pane|
        try std.testing.expectEqual(expected, pane.id);
    const four_root = tab.layout.nodes.items[tab.layout.root.?];
    try std.testing.expectEqual(Axis.vertical, four_root.axis);
    try std.testing.expectEqual(@as(u16, 250), four_root.ratio_permille);
}

test "workspace 1x1 preset removes extra panes" {
    const allocator = std.testing.allocator;
    var ws = try Workspace.init(allocator, "/tmp");
    defer ws.deinit();

    try ws.applyPresetToActiveTab(.three_by_three);
    try std.testing.expectEqual(@as(usize, 9), ws.activeTab().?.panes.items.len);

    try ws.applyPresetToActiveTab(.one_by_one);
    const tab = ws.activeTab().?;
    try std.testing.expectEqual(@as(usize, 1), tab.panes.items.len);
    try std.testing.expectEqual(@as(Terminal.PaneId, 1), tab.active_pane_id);
}

test "pane selection supports replace add and toggle" {
    const allocator = std.testing.allocator;
    var ws = try Workspace.init(allocator, "/tmp");
    defer ws.deinit();
    try ws.applyPresetToActiveTab(.two_by_two);

    const tab = ws.activeTab().?;
    try tab.selectPane(2, .replace);
    try tab.selectPane(3, .add);
    try tab.selectPane(2, .toggle);

    const selected = try tab.selectedPaneIds(allocator);
    defer allocator.free(selected);
    try std.testing.expectEqual(@as(usize, 1), selected.len);
    try std.testing.expectEqual(@as(Terminal.PaneId, 3), selected[0]);
}

test "selected panes receive tags and smart filter matches tagged panes" {
    const allocator = std.testing.allocator;
    var ws = try Workspace.init(allocator, "/tmp");
    defer ws.deinit();
    try ws.applyPresetToActiveTab(.two_by_two);
    const tab = ws.activeTab().?;
    try tab.selectPane(2, .replace);
    try tab.selectPane(4, .add);
    try std.testing.expectEqual(@as(usize, 2), try ws.tagSelectedPanes(" build "));
    try std.testing.expect(ws.findPane(2).?.hasTag("build"));
    try std.testing.expect(ws.findPane(4).?.hasTag("build"));
    try ws.setSmartFilterTag("build");
    try std.testing.expect(ws.paneMatchesSmartFilter(2));
    try std.testing.expect(!ws.paneMatchesSmartFilter(3));
    try tab.selectPane(4, .toggle);
    try std.testing.expectEqual(@as(usize, 1), ws.removeTagFromSelectedPanes("build"));
    try std.testing.expect(ws.findPane(4).?.hasTag("build"));
    try std.testing.expect(!ws.findPane(2).?.hasTag("build"));
    try ws.setSmartFilterTag(null);
    try std.testing.expect(ws.paneMatchesSmartFilter(3));
}

test "workspace exposes unique known tags for native suggestions" {
    const allocator = std.testing.allocator;
    var ws = try Workspace.init(allocator, "/tmp");
    defer ws.deinit();
    try ws.applyPresetToActiveTab(.two_by_two);
    try ws.findPane(1).?.addTag("backend");
    try ws.findPane(2).?.addTag("review");
    try ws.findPane(3).?.addTag("backend");

    const tags = try ws.knownTags(allocator);
    defer allocator.free(tags);
    try std.testing.expectEqual(@as(usize, 2), tags.len);
    try std.testing.expectEqualStrings("backend", tags[0]);
    try std.testing.expectEqualStrings("review", tags[1]);
}

test "pane font size changes remain isolated" {
    const allocator = std.testing.allocator;
    var ws = try Workspace.init(allocator, "/tmp");
    defer ws.deinit();
    try ws.applyPresetToActiveTab(.two_by_two);
    const font_config = Config.Config.defaults().font;

    const change = try ws.setPaneFontSize(2, 14.0, font_config);
    try std.testing.expectEqual(@as(Terminal.PaneId, 2), change.pane_id);
    try std.testing.expectEqual(@as(f32, 14.0), ws.findPane(2).?.profile.font_size_pt);
    try std.testing.expectEqual(@as(f32, 13.0), ws.findPane(1).?.profile.font_size_pt);
    try std.testing.expectError(error.InvalidFontSize, ws.setPaneFontSize(2, 99.0, font_config));
}

test "broadcast mode targets selected panes or all panes" {
    const allocator = std.testing.allocator;
    var ws = try Workspace.init(allocator, "/tmp");
    defer ws.deinit();
    try ws.applyPresetToActiveTab(.two_by_two);
    ws.broadcast_enabled = true;

    const targets = try ws.broadcastTargets(allocator);
    defer allocator.free(targets);
    try std.testing.expectEqual(@as(usize, 4), targets.len);

    const tab = ws.activeTab().?;
    tab.findPane(2).?.selected = true;
    tab.findPane(4).?.selected = true;
    const selected = try ws.broadcastTargets(allocator);
    defer allocator.free(selected);
    try std.testing.expectEqual(@as(usize, 2), selected.len);
}

test "workspace applies status events by pane id across tabs" {
    const allocator = std.testing.allocator;
    var ws = try Workspace.init(allocator, "/tmp");
    defer ws.deinit();
    _ = try ws.addTab("second", "/repo");

    const change = try ws.applyStatusEvent(2, .{ .process_started = 10 }, 20);
    try std.testing.expectEqual(Terminal.TerminalStatus.idle, change.previous);
    try std.testing.expectEqual(Terminal.TerminalStatus.running, change.current);
    try std.testing.expectEqual(Terminal.TerminalStatus.idle, ws.findPane(1).?.status);
    try std.testing.expectEqual(Terminal.TerminalStatus.running, ws.findPane(2).?.status);

    const done = try ws.applyStatusEvent(2, .{ .exited = .{ .code = 0, .at_ms = 20 } }, 20);
    try std.testing.expectEqual(Terminal.TerminalStatus.done, done.current);
}

test "workspace applies per-pane profile presets by stable pane id" {
    const allocator = std.testing.allocator;
    var ws = try Workspace.init(allocator, "/tmp");
    defer ws.deinit();
    _ = try ws.addTab("second", "/repo");

    var cfg = Config.Config.defaults();
    cfg.default_theme = "workspace-dark";
    cfg.font.family = "Commit Mono";

    const change = try ws.applyProfilePreset(2, .high_contrast, cfg);
    try std.testing.expectEqual(@as(Terminal.PaneId, 2), change.pane_id);
    try std.testing.expectEqualStrings("noctty-high-contrast", change.profile.theme_name);
    try std.testing.expectEqualStrings("Commit Mono", ws.findPane(2).?.profile.font_family);
    try std.testing.expectEqualStrings("noctty-dark", ws.findPane(1).?.profile.theme_name);
}

test "workspace owns project panel git graph status and file lists" {
    const allocator = std.testing.allocator;
    var ws = try Workspace.init(allocator, "/repo/main");
    defer ws.deinit();

    var mutable_path = [_]u8{ 's', 'r', 'c', '/', 'm', 'a', 'i', 'n', '.', 'z', 'i', 'g' };
    const summary = try ws.updateProjectPanels(.{
        .git_status = &.{
            .{ .path = mutable_path[0..], .state = .modified },
            .{ .path = "README.md", .state = .conflicted },
            .{ .path = "zig-cache", .state = .ignored },
        },
        .git_graph = &.{
            .{ .commit = "abc1234", .summary = "project panel state", .branch = "main" },
            .{ .commit = "def5678", .summary = "workspace export" },
        },
        .files = &.{
            .{ .path = "src", .kind = .directory },
            .{ .path = "src/main.zig", .kind = .file, .dirty = true },
        },
    });
    mutable_path[0] = 'X';

    try std.testing.expectEqual(@as(usize, 3), summary.git_status_count);
    try std.testing.expectEqual(@as(usize, 2), summary.changed_count);
    try std.testing.expectEqual(@as(usize, 1), summary.conflict_count);
    try std.testing.expectEqual(@as(usize, 2), summary.git_graph_count);
    try std.testing.expectEqual(@as(usize, 2), summary.file_entry_count);
    try std.testing.expectEqual(@as(usize, 1), summary.directory_count);
    try std.testing.expectEqual(@as(usize, 1), summary.dirty_file_count);
    try std.testing.expectEqualStrings("src/main.zig", ws.project_panels.git_status[0].path);
    try std.testing.expectEqualStrings("main", ws.project_panels.git_graph[0].branch.?);

    try std.testing.expectError(error.InvalidProjectPanelEntry, ws.updateProjectPanels(.{
        .files = &.{.{ .path = "", .kind = .file }},
    }));
    try std.testing.expectEqual(@as(usize, 3), ws.project_panels.git_status.len);
}

test "workspace creates bounded project panel views with filters and selection" {
    const allocator = std.testing.allocator;
    var ws = try Workspace.init(allocator, "/repo/main");
    defer ws.deinit();

    _ = try ws.updateProjectPanels(.{
        .git_status = &.{
            .{ .path = "src/main.zig", .state = .modified },
            .{ .path = "README.md", .state = .conflicted },
            .{ .path = "zig-cache", .state = .ignored },
        },
        .git_graph = &.{
            .{ .commit = "abc1234", .summary = "panel view", .branch = "main" },
            .{ .commit = "def5678", .summary = "bounded rows" },
        },
        .files = &.{
            .{ .path = "src", .kind = .directory },
            .{ .path = "src/main.zig", .kind = .file, .dirty = true },
            .{ .path = "README.md", .kind = .file },
        },
    });

    const changed = ws.projectPanelView(.{
        .kind = .git_status,
        .max_rows = 1,
        .selected_index = 1,
        .changed_only = true,
    });
    try std.testing.expectEqual(ProjectPanelViewKind.git_status, changed.kind);
    try std.testing.expectEqual(@as(usize, 3), changed.total_rows);
    try std.testing.expectEqual(@as(usize, 2), changed.visible_rows);
    try std.testing.expectEqual(@as(usize, 1), changed.row_count);
    try std.testing.expect(changed.truncated());
    try std.testing.expect(changed.selected_visible);
    try std.testing.expectEqual(@as(?usize, 1), changed.selected_index);
    const status_row = changed.rowSlice()[0].git_status;
    try std.testing.expectEqual(@as(usize, 0), status_row.source_index);
    try std.testing.expectEqual(GitFileState.modified, status_row.state);
    try std.testing.expect(!status_row.selected);
    try std.testing.expectEqualStrings("src/main.zig", status_row.path);

    const conflicts = ws.projectPanelView(.{
        .kind = .git_status,
        .conflicts_only = true,
        .selected_index = 1,
    });
    try std.testing.expectEqual(@as(usize, 1), conflicts.visible_rows);
    try std.testing.expectEqual(@as(usize, 1), conflicts.row_count);
    try std.testing.expect(conflicts.rowSlice()[0].git_status.selected);
    try std.testing.expectEqualStrings("README.md", conflicts.rowSlice()[0].git_status.path);

    const dirty_files = ws.projectPanelView(.{
        .kind = .files,
        .dirty_only = true,
        .selected_index = 1,
    });
    try std.testing.expectEqual(@as(usize, 3), dirty_files.total_rows);
    try std.testing.expectEqual(@as(usize, 1), dirty_files.visible_rows);
    try std.testing.expect(dirty_files.selected_visible);
    try std.testing.expectEqual(ProjectFileKind.file, dirty_files.rowSlice()[0].files.kind);
    try std.testing.expect(dirty_files.rowSlice()[0].files.dirty);

    const graph = ws.projectPanelView(.{
        .kind = .git_graph,
        .max_rows = 4,
        .selected_index = 0,
    });
    try std.testing.expectEqual(@as(usize, 2), graph.row_count);
    try std.testing.expect(graph.rowSlice()[0].git_graph.selected);
    try std.testing.expectEqualStrings("panel view", graph.rowSlice()[0].git_graph.summary);
    try std.testing.expectEqualStrings("main", graph.rowSlice()[0].git_graph.branch.?);
}

test "workspace creates project panel activation intents" {
    const allocator = std.testing.allocator;
    var ws = try Workspace.init(allocator, "/repo/main");
    defer ws.deinit();

    _ = try ws.updateProjectPanels(.{
        .git_status = &.{
            .{ .path = "src/main.zig", .state = .modified },
        },
        .git_graph = &.{
            .{ .commit = "abc1234", .summary = "panel action", .branch = "main" },
        },
        .files = &.{
            .{ .path = "src", .kind = .directory },
            .{ .path = "src/main.zig", .kind = .file, .dirty = true },
        },
    });

    const status = try ws.activateProjectPanelRow(.{ .kind = .git_status, .source_index = 0 });
    try std.testing.expectEqual(ProjectPanelActivationKind.show_git_diff, status.kind);
    try std.testing.expect(status.targetsPath());
    try std.testing.expect(!status.targetsCommit());
    try std.testing.expectEqual(GitFileState.modified, status.git_state.?);
    try std.testing.expectEqualStrings("src/main.zig", status.path.?);

    const directory = try ws.activateProjectPanelRow(.{ .kind = .files, .source_index = 0 });
    try std.testing.expectEqual(ProjectPanelActivationKind.open_directory, directory.kind);
    try std.testing.expectEqual(ProjectFileKind.directory, directory.file_kind.?);
    try std.testing.expectEqualStrings("src", directory.path.?);

    const file = try ws.activateProjectPanelRow(.{ .kind = .files, .source_index = 1 });
    try std.testing.expectEqual(ProjectPanelActivationKind.open_file, file.kind);
    try std.testing.expectEqual(ProjectFileKind.file, file.file_kind.?);
    try std.testing.expectEqualStrings("src/main.zig", file.path.?);

    const commit = try ws.activateProjectPanelRow(.{ .kind = .git_graph, .source_index = 0 });
    try std.testing.expectEqual(ProjectPanelActivationKind.show_git_commit, commit.kind);
    try std.testing.expect(!commit.targetsPath());
    try std.testing.expect(commit.targetsCommit());
    try std.testing.expectEqualStrings("abc1234", commit.commit.?);
    try std.testing.expectEqualStrings("panel action", commit.summary.?);
    try std.testing.expectEqualStrings("main", commit.branch.?);

    try std.testing.expectError(error.ProjectPanelRowNotFound, ws.activateProjectPanelRow(.{
        .kind = .git_graph,
        .source_index = 1,
    }));
}

test "workspace creates project panel action execution plans" {
    const allocator = std.testing.allocator;
    var ws = try Workspace.init(allocator, "/repo/main");
    defer ws.deinit();

    _ = try ws.updateProjectPanels(.{
        .git_status = &.{
            .{ .path = "src/main.zig", .state = .modified },
        },
        .git_graph = &.{
            .{ .commit = "abc1234", .summary = "panel action plan", .branch = "main" },
        },
        .files = &.{
            .{ .path = "src", .kind = .directory },
            .{ .path = "src/main.zig", .kind = .file, .dirty = true },
        },
    });

    const diff = try ws.projectPanelActionPlan(.{ .kind = .git_status, .source_index = 0 });
    try std.testing.expect(diff.canExecute());
    try std.testing.expectEqual(ProjectPanelActionExecutor.native_git_diff, diff.executor);
    try std.testing.expect(diff.requires_path);
    try std.testing.expect(!diff.requires_commit);
    try std.testing.expect(diff.requires_git);
    try std.testing.expectEqual(GitFileState.modified, diff.git_state.?);
    try std.testing.expectEqualStrings("src/main.zig", diff.path.?);

    const directory = try ws.projectPanelActionPlan(.{ .kind = .files, .source_index = 0 });
    try std.testing.expectEqual(ProjectPanelActionExecutor.native_directory_open, directory.executor);
    try std.testing.expect(directory.opens_directory);
    try std.testing.expect(!directory.opens_editor);
    try std.testing.expect(!directory.requires_git);
    try std.testing.expectEqual(ProjectFileKind.directory, directory.file_kind.?);

    const file = try ws.projectPanelActionPlan(.{ .kind = .files, .source_index = 1 });
    try std.testing.expectEqual(ProjectPanelActionExecutor.native_file_open, file.executor);
    try std.testing.expect(file.opens_editor);
    try std.testing.expect(!file.opens_directory);
    try std.testing.expectEqual(ProjectFileKind.file, file.file_kind.?);

    const commit = try ws.projectPanelActionPlan(.{ .kind = .git_graph, .source_index = 0 });
    try std.testing.expectEqual(ProjectPanelActionExecutor.native_git_commit, commit.executor);
    try std.testing.expect(commit.requires_commit);
    try std.testing.expect(commit.requires_git);
    try std.testing.expect(!commit.requires_path);
    try std.testing.expectEqualStrings("abc1234", commit.commit.?);
    try std.testing.expectEqualStrings("panel action plan", commit.summary.?);
    try std.testing.expectEqualStrings("main", commit.branch.?);

    try std.testing.expectError(error.MissingProjectPanelActionPath, ProjectPanelActionPlan.fromActivation(.{
        .kind = .open_file,
        .source = .{ .kind = .files, .source_index = 0 },
    }));
    try std.testing.expectError(error.ProjectPanelActionTargetMismatch, ProjectPanelActionPlan.fromActivation(.{
        .kind = .open_file,
        .source = .{ .kind = .files, .source_index = 0 },
        .path = "src",
        .file_kind = .directory,
    }));
    try std.testing.expectError(error.ProjectPanelActionNotExecutable, ProjectPanelActionPlan.fromActivation(.{
        .kind = .show_git_diff,
        .source = .{ .kind = .git_status, .source_index = 0 },
        .path = "zig-cache",
        .git_state = .ignored,
    }));
}

test "workspace creates project panel action execution specs" {
    const allocator = std.testing.allocator;
    var ws = try Workspace.init(allocator, "/repo/main");
    defer ws.deinit();

    _ = try ws.updateProjectPanels(.{
        .git_status = &.{
            .{ .path = "src/main.zig", .state = .modified },
        },
        .git_graph = &.{
            .{ .commit = "abc1234", .summary = "panel action spec", .branch = "main" },
        },
        .files = &.{
            .{ .path = "src", .kind = .directory },
            .{ .path = "src/main.zig", .kind = .file, .dirty = true },
        },
    });

    const diff = try ws.projectPanelActionExecutionSpec(.{ .kind = .git_status, .source_index = 0 });
    try std.testing.expectEqual(ProjectPanelActionOperation.run_git_diff, diff.operation);
    try std.testing.expect(diff.requires_process);
    try std.testing.expect(diff.requires_git);
    try std.testing.expect(!diff.mutates_workspace);
    try std.testing.expectEqual(@as(usize, 4), diff.argvSlice().len);
    try std.testing.expectEqualStrings("git", diff.argvSlice()[0]);
    try std.testing.expectEqualStrings("diff", diff.argvSlice()[1]);
    try std.testing.expectEqualStrings("--", diff.argvSlice()[2]);
    try std.testing.expectEqualStrings("src/main.zig", diff.argvSlice()[3]);

    const directory = try ws.projectPanelActionExecutionSpec(.{ .kind = .files, .source_index = 0 });
    try std.testing.expectEqual(ProjectPanelActionOperation.open_directory_view, directory.operation);
    try std.testing.expect(directory.requires_directory_view);
    try std.testing.expect(!directory.requires_process);
    try std.testing.expect(!directory.hasProcessArgv());
    try std.testing.expectEqualStrings("src", directory.path.?);

    const file = try ws.projectPanelActionExecutionSpec(.{ .kind = .files, .source_index = 1 });
    try std.testing.expectEqual(ProjectPanelActionOperation.open_editor_document, file.operation);
    try std.testing.expect(file.requires_editor);
    try std.testing.expect(!file.requires_process);
    try std.testing.expect(!file.hasProcessArgv());
    try std.testing.expectEqualStrings("src/main.zig", file.path.?);

    const commit = try ws.projectPanelActionExecutionSpec(.{ .kind = .git_graph, .source_index = 0 });
    try std.testing.expectEqual(ProjectPanelActionOperation.run_git_commit_show, commit.operation);
    try std.testing.expect(commit.requires_process);
    try std.testing.expect(commit.requires_git);
    try std.testing.expectEqual(@as(usize, 5), commit.argvSlice().len);
    try std.testing.expectEqualStrings("git", commit.argvSlice()[0]);
    try std.testing.expectEqualStrings("show", commit.argvSlice()[1]);
    try std.testing.expectEqualStrings("--stat", commit.argvSlice()[2]);
    try std.testing.expectEqualStrings("--patch", commit.argvSlice()[3]);
    try std.testing.expectEqualStrings("abc1234", commit.argvSlice()[4]);

    const completed = try ProjectPanelActionExecutionResult.fromReceipt(.{
        .source = diff.source,
        .executor = diff.executor,
        .operation = diff.operation,
        .status = .completed,
        .exit_code = 0,
        .stdout_bytes = 128,
    });
    try std.testing.expect(completed.succeeded());
    try std.testing.expect(completed.hasOutput());
    try std.testing.expectEqual(ProjectPanelActionOperation.run_git_diff, completed.operation);
    try std.testing.expectEqual(@as(?u8, 0), completed.exit_code);
    try std.testing.expectEqual(@as(usize, 128), completed.stdout_bytes);

    const completed_view = completed.view();
    try std.testing.expectEqual(ProjectPanelActionResultTone.success, completed_view.tone);
    try std.testing.expectEqualStrings("Git diff", completed_view.title);
    try std.testing.expectEqualStrings("Completed", completed_view.detail);
    try std.testing.expect(completed_view.shows_process_output);
    try std.testing.expect(!completed_view.shows_editor_target);
    try std.testing.expect(!completed_view.shows_directory_target);
    try std.testing.expect(completed_view.has_output);
    try std.testing.expect(!completed_view.needsAttention());

    const failed_editor_view = ProjectPanelActionResultView.fromResult(.{
        .source = file.source,
        .executor = file.executor,
        .operation = file.operation,
        .status = .failed,
    });
    try std.testing.expectEqual(ProjectPanelActionResultTone.@"error", failed_editor_view.tone);
    try std.testing.expectEqualStrings("Editor document", failed_editor_view.title);
    try std.testing.expect(failed_editor_view.shows_editor_target);
    try std.testing.expect(failed_editor_view.needsAttention());

    const denied_directory_view = ProjectPanelActionResultView.fromResult(.{
        .source = directory.source,
        .executor = directory.executor,
        .operation = directory.operation,
        .status = .denied,
    });
    try std.testing.expectEqual(ProjectPanelActionResultTone.warning, denied_directory_view.tone);
    try std.testing.expectEqualStrings("Directory view", denied_directory_view.title);
    try std.testing.expect(denied_directory_view.shows_directory_target);
    try std.testing.expect(denied_directory_view.needsAttention());

    try std.testing.expectError(error.InvalidProjectPanelActionExecutionReceipt, ProjectPanelActionExecutionResult.fromReceipt(.{
        .source = diff.source,
        .executor = diff.executor,
        .operation = diff.operation,
        .status = .pending,
    }));
}

test "workspace snapshots and restores tabs panes layout tags worktrees and profiles" {
    const allocator = std.testing.allocator;
    var ws = try Workspace.init(allocator, "/repo/main");
    defer ws.deinit();

    _ = try ws.splitActivePane(.right);
    const first = ws.activeTab().?;
    try first.findPane(1).?.addTag("api");
    try first.findPane(1).?.setWorktreeRoot("/repo/main");
    _ = try first.findPane(1).?.setProfile(.{
        .theme_name = "workspace-dark",
        .font_family = "Commit Mono",
        .font_size_pt = 12.5,
        .ligatures = false,
    });
    first.findPane(2).?.status = .pending_interaction;
    try first.selectPane(2, .replace);
    ws.broadcast_enabled = true;

    _ = try ws.addTab("agent", "/repo/agent");
    const second = ws.activeTab().?;
    _ = try ws.setTabAccent(second.id, .purple);
    _ = try ws.adjustTabAccent(second.id, -1);
    try second.findPane(3).?.addTag("worker");
    try second.findPane(3).?.setWorktreeRoot("/repo/agent-wt");
    second.findPane(3).?.status = .running;
    _ = try second.togglePaneZoom(3);
    _ = try ws.setQuickNote("deploy checklist\n- verify logs");
    try ws.setSmartFilterTag("worker");
    _ = try ws.updateProjectPanels(.{
        .git_status = &.{
            .{ .path = "src/workspace/Workspace.zig", .state = .modified },
            .{ .path = "BACKLOG.md", .state = .conflicted },
        },
        .git_graph = &.{
            .{ .commit = "abc1234", .summary = "workspace snapshots", .branch = "main" },
        },
        .files = &.{
            .{ .path = "src", .kind = .directory },
            .{ .path = "src/workspace/Workspace.zig", .kind = .file, .dirty = true },
        },
    });

    var snapshot = try ws.captureSnapshot();
    defer snapshot.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 2), snapshot.tabs.len);
    try std.testing.expectEqual(@as(usize, 1), snapshot.active_tab);
    try std.testing.expectEqual(@as(Terminal.PaneId, 4), snapshot.next_pane_id);
    try std.testing.expect(snapshot.broadcast_enabled);
    try std.testing.expectEqualStrings("Commit Mono", snapshot.tabs[0].panes[0].profile.font_family);
    try std.testing.expectEqualStrings("/repo/agent-wt", snapshot.tabs[1].panes[0].worktree_root.?);
    try std.testing.expectEqual(@as(usize, 2), snapshot.project_panels.summary().changed_count);
    try std.testing.expectEqualStrings("workspace snapshots", snapshot.project_panels.git_graph[0].summary);
    try std.testing.expectEqualStrings("deploy checklist\n- verify logs", snapshot.quick_note);
    try std.testing.expectEqualStrings("worker", snapshot.smart_filter_tag.?);
    try std.testing.expectEqual(TabColorPreset.purple, snapshot.tabs[1].accent.?.preset);
    try std.testing.expectEqual(@as(i8, -1), snapshot.tabs[1].accent.?.shade);

    try ws.applyPresetToActiveTab(.three_by_three);
    ws.broadcast_enabled = false;
    _ = try ws.setQuickNote("temporary");
    _ = try ws.updateProjectPanels(.{});
    try ws.restoreSnapshot(snapshot);

    try std.testing.expectEqual(@as(usize, 2), ws.tabs.items.len);
    try std.testing.expectEqual(@as(usize, 1), ws.active_tab);
    try std.testing.expect(ws.broadcast_enabled);
    try std.testing.expectEqual(@as(Terminal.PaneId, 4), ws.next_pane_id);
    try std.testing.expectEqual(@as(usize, 2), ws.tabs.items[0].panes.items.len);
    try std.testing.expectEqual(@as(usize, 3), ws.tabs.items[0].layout.nodes.items.len);
    try std.testing.expectEqual(Terminal.TerminalStatus.pending_interaction, ws.findPane(2).?.status);
    try std.testing.expect(ws.findPane(2).?.selected);
    try std.testing.expectEqualStrings("api", ws.findPane(1).?.tags.items[0]);
    try std.testing.expectEqualStrings("/repo/main", ws.findPane(1).?.worktree_root.?);
    try std.testing.expectEqualStrings("workspace-dark", ws.findPane(1).?.profile.theme_name);
    try std.testing.expect(!ws.findPane(1).?.profile.ligatures);
    try std.testing.expectEqualStrings("worker", ws.findPane(3).?.tags.items[0]);
    try std.testing.expectEqual(@as(usize, 2), ws.project_panels.git_status.len);
    try std.testing.expectEqual(GitFileState.conflicted, ws.project_panels.git_status[1].state);
    try std.testing.expectEqual(ProjectFileKind.directory, ws.project_panels.files[0].kind);
    try std.testing.expectEqualStrings("deploy checklist\n- verify logs", ws.quick_note);
    try std.testing.expectEqualStrings("worker", ws.smart_filter_tag.?);
    try std.testing.expectEqual(snapshot.tabs[1].accent.?.rgb(), ws.tabs.items[1].accent.?.rgb());
    try std.testing.expect(ws.activeTab().?.zoomed_pane_id == null);
}

test "workspace snapshot export imports equivalent owned snapshot" {
    const allocator = std.testing.allocator;
    var ws = try Workspace.init(allocator, "/repo/main");
    defer ws.deinit();

    _ = try ws.splitActivePane(.down);
    try ws.findPane(2).?.addTag("agent");
    try ws.findPane(2).?.setWorktreeRoot("/repo/worktree");
    _ = try ws.findPane(2).?.setProfile(.{
        .theme_name = "workspace-dark",
        .font_family = "Commit Mono",
        .font_size_pt = 13.25,
        .ligatures = false,
    });
    ws.findPane(2).?.status = .long_running;
    var resume_reference = Continuity.AgentResume{ .enabled = true, .provider = .codex };
    try resume_reference.session_id.set("codex-session-42");
    try resume_reference.label.set("Review agent");
    try ws.findPane(2).?.setAgentResume(resume_reference);
    _ = try ws.renameTab(1, "Build logs");
    _ = try ws.setTabAccent(1, .orange);
    _ = try ws.adjustTabAccent(1, 1);
    ws.broadcast_enabled = true;
    _ = try ws.setQuickNote("release note");
    try ws.setSmartFilterTag("agent");
    _ = try ws.updateProjectPanels(.{
        .git_status = &.{
            .{ .path = "src/app/App.zig", .state = .renamed },
        },
        .git_graph = &.{
            .{ .commit = "feedbee", .summary = "native panels", .branch = "panel-state" },
        },
        .files = &.{
            .{ .path = "src/app/App.zig", .kind = .file, .dirty = true },
        },
    });

    var snapshot = try ws.captureSnapshot();
    defer snapshot.deinit(allocator);
    const bytes = try exportSnapshotAlloc(allocator, snapshot);
    defer allocator.free(bytes);

    var imported = try importSnapshotAlloc(allocator, bytes);
    defer imported.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 1), imported.tabs.len);
    try std.testing.expect(imported.broadcast_enabled);
    try std.testing.expect(imported.tabs[0].title_overridden);
    try std.testing.expectEqual(TabColorPreset.orange, imported.tabs[0].accent.?.preset);
    try std.testing.expectEqual(@as(i8, 1), imported.tabs[0].accent.?.shade);
    try std.testing.expectEqualStrings("Build logs", imported.tabs[0].title);
    try std.testing.expectEqualStrings("release note", imported.quick_note);
    try std.testing.expectEqualStrings("agent", imported.smart_filter_tag.?);
    try std.testing.expectEqual(@as(usize, 2), imported.tabs[0].panes.len);
    try std.testing.expectEqual(Terminal.TerminalStatus.long_running, imported.tabs[0].panes[1].status);
    try std.testing.expectEqualStrings("/repo/worktree", imported.tabs[0].panes[1].worktree_root.?);
    try std.testing.expectEqualStrings("workspace-dark", imported.tabs[0].panes[1].profile.theme_name);
    try std.testing.expectEqualStrings("agent", imported.tabs[0].panes[1].tags[0]);
    try std.testing.expect(imported.tabs[0].panes[1].agent_resume.enabled);
    try std.testing.expectEqual(Continuity.Provider.codex, imported.tabs[0].panes[1].agent_resume.provider);
    try std.testing.expectEqualStrings("codex-session-42", imported.tabs[0].panes[1].agent_resume.session_id.slice());
    try std.testing.expectEqualStrings("Review agent", imported.tabs[0].panes[1].agent_resume.label.slice());
    try std.testing.expect(imported.tabs[0].panes[1].profile.theme_name.ptr != snapshot.tabs[0].panes[1].profile.theme_name.ptr);
    try std.testing.expectEqual(GitFileState.renamed, imported.project_panels.git_status[0].state);
    try std.testing.expectEqualStrings("panel-state", imported.project_panels.git_graph[0].branch.?);
    try std.testing.expect(imported.project_panels.files[0].path.ptr != snapshot.project_panels.files[0].path.ptr);
}

test "workspace snapshot import rejects malformed or trailing data" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(error.InvalidWorkspaceSnapshot, importSnapshotAlloc(allocator, "bad"));

    var ws = try Workspace.init(allocator, "/repo/main");
    defer ws.deinit();
    var snapshot = try ws.captureSnapshot();
    defer snapshot.deinit(allocator);
    const bytes = try exportSnapshotAlloc(allocator, snapshot);
    defer allocator.free(bytes);

    var snapshot_pane_count: usize = 0;
    for (snapshot.tabs) |tab| snapshot_pane_count += tab.panes.len;
    const post_v1_payload_len = 6 * @sizeOf(u64) +
        (2 * snapshot.tabs.len) + 1 +
        @sizeOf(u64) + snapshot_pane_count * (1 + 1 + 2 * @sizeOf(u64));
    const v1_bytes = try allocator.alloc(u8, bytes.len - post_v1_payload_len);
    defer allocator.free(v1_bytes);
    @memcpy(v1_bytes, bytes[0..v1_bytes.len]);
    v1_bytes[workspace_export_magic.len] = 1;
    var v1_imported = try importSnapshotAlloc(allocator, v1_bytes);
    defer v1_imported.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 0), v1_imported.project_panels.git_status.len);

    const with_trailing = try allocator.alloc(u8, bytes.len + 1);
    defer allocator.free(with_trailing);
    @memcpy(with_trailing[0..bytes.len], bytes);
    with_trailing[bytes.len] = 0xff;
    try std.testing.expectError(error.TrailingWorkspaceSnapshotData, importSnapshotAlloc(allocator, with_trailing));
}
