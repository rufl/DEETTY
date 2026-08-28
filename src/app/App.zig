const std = @import("std");
const Config = @import("../config/Config.zig");
const ConfigStorage = @import("../config/Storage.zig");
const Gui = @import("../gui/Backend.zig");
const Host = @import("../gui/Host.zig");
const Paste = @import("../terminal/Paste.zig");
const LaunchProfile = @import("../terminal/LaunchProfile.zig");
const Terminal = @import("../terminal/Terminal.zig");
const Theme = @import("../theme/Theme.zig");
const ThemeStorage = @import("../theme/Storage.zig");
const ProjectScan = @import("../workspace/ProjectScan.zig");
const Storage = @import("../workspace/Storage.zig");
const WorkspaceActivation = @import("../workspace/Activation.zig");
const Workspace = @import("../workspace/Workspace.zig");

pub const App = struct {
    allocator: std.mem.Allocator,
    config: Config.Config,
    backend: Gui.Descriptor,
    host: Host.NativeHost,
    workspace: Workspace.Workspace,
    themes: std.array_list.Managed(ThemeEntry),
    owned_font_family: ?[]u8 = null,
    owned_default_theme: ?[]u8 = null,
    owned_syntax_theme: ?[]u8 = null,
    owned_preview_theme_name: ?[]u8 = null,
    preview_theme: ?Theme.Theme = null,
    recovery: Storage.RecoveryState = .{},
    maintenance_policy: MaintenancePolicy = .{},
    maintenance: MaintenanceState = .{},
    pending_project_panel_action_execution: ?ProjectPanelActionExecutionTracker = null,
    last_project_panel_action_result: ?Workspace.ProjectPanelActionExecutionResult = null,
    telemetry_enabled: bool = false,

    pub const ThemeEntry = struct {
        theme: Theme.Theme,
        owned_name: []u8,
    };

    const ProjectPanelActionExecutionTracker = struct {
        source: Workspace.ProjectPanelActivationRequest,
        executor: Workspace.ProjectPanelActionExecutor,
        operation: Workspace.ProjectPanelActionOperation,

        fn matches(self: ProjectPanelActionExecutionTracker, receipt: Workspace.ProjectPanelActionExecutionReceipt) bool {
            return self.source.kind == receipt.source.kind and
                self.source.source_index == receipt.source.source_index and
                self.executor == receipt.executor and
                self.operation == receipt.operation;
        }
    };

    pub const Command = union(enum) {
        new_tab,
        reopen_tab,
        rename_tab: RenameTab,
        reorder_tab: ReorderTab,
        set_tab_accent: SetTabAccent,
        adjust_tab_accent: AdjustTabAccent,
        close_tab: u64,
        close_pane: Terminal.PaneId,
        focus_pane: Terminal.PaneId,
        focus_next_pane,
        focus_previous_pane,
        toggle_pane_zoom: Terminal.PaneId,
        move_pane_to_tab: MovePaneToTab,
        split_left,
        split_right,
        split_up,
        split_down,
        preset: Workspace.LayoutPreset,
        toggle_broadcast,
        set_window_mode: Config.WindowMode,
        set_dropdown_dimensions: DropdownDimensions,
        set_dropdown_animation_ms: u16,
        set_hide_on_focus_loss: bool,
        set_focus_follows_pointer: bool,
        set_show_pane_info: bool,
        set_scrollback_lines: u32,
        set_scroll_behavior: ScrollBehavior,
        set_launch_profile: LaunchProfile.Profile,
        save_named_launch_profile: struct {
            name: []const u8,
            profile: LaunchProfile.Profile,
        },
        select_named_launch_profile: usize,
        remove_named_launch_profile: usize,
        toggle_dropdown,
        request_window_lifecycle: Host.PresentationTrigger,
        window_lifecycle_receipt: Host.WindowLifecycleReceipt,
        begin_shortcut_recording,
        capture_shortcut: Config.KeyEvent,
        register_global_shortcut,
        shortcut_registration_receipt: Host.ShortcutRegistrationReceipt,
        deliver_last_notification,
        notification_delivery_receipt: Host.NotificationDeliveryReceipt,
        show_status_tooltip: StatusTooltipTarget,
        status_tooltip_receipt: Host.StatusTooltipReceipt,
        hide_status_tooltip,
        show_profile_preset_menu: ProfilePresetMenuTarget,
        profile_preset_menu_receipt: Host.ProfilePresetMenuReceipt,
        hide_profile_preset_menu,
        select_profile_preset_from_menu: PaneProfilePreset,
        read_clipboard: Host.ClipboardSelection,
        write_clipboard: ClipboardWrite,
        clipboard_transfer_receipt: Host.ClipboardTransferReceipt,
        deliver_paste_to_pane: PaneClipboardPaste,
        paste_delivery_receipt: Host.PasteDeliveryReceipt,
        font_larger,
        font_smaller,
        select_pane: SelectPane,
        tag_selected_panes: []const u8,
        remove_tag_from_selected_panes: []const u8,
        set_smart_filter: ?[]const u8,
        terminal_status: PaneStatusEvent,
        set_tab_position: Config.TabPosition,
        set_status_indicator: Config.StatusIndicator,
        set_show_status_counts: bool,
        set_tooltip_details: bool,
        set_desktop_notifications: bool,
        set_long_running_minutes: u16,
        set_font_size: f32,
        set_font_family: []const u8,
        set_font_antialias: Config.FontAntialias,
        set_font_hinting: Config.FontHinting,
        set_background: Config.BackgroundConfig,
        set_default_theme: []const u8,
        set_syntax_theme: []const u8,
        set_panel_metrics: Config.PanelMetrics,
        set_pane_profile_preset: PaneProfilePreset,
        set_pane_font_size: PaneFontSize,
        set_agent_resume: AgentResumeChange,
        clear_agent_resume: Terminal.PaneId,
        preview_theme_import: ThemeImport,
        install_theme_import: ThemeImport,
        select_theme: []const u8,
        set_theme_chrome_color: ThemeChromeColorChange,
        read_quick_note,
        set_quick_note: []const u8,
        prepare_paste: ClipboardPaste,
        capture_workspace,
        restore_workspace: Workspace.ProjectSnapshot,
        export_workspace,
        import_workspace: []const u8,
        maintenance_tick: MaintenanceTick,
        project_refresh_receipt: ProjectRefreshReceipt,
        recovery_cleanup_receipt: RecoveryCleanupMaintenanceReceipt,
        show_workspace_file_dialog: WorkspaceFileDialogTarget,
        workspace_file_dialog_receipt: Host.WorkspaceFileDialogReceipt,
        show_project_panel,
        project_panel_receipt: Host.ProjectPanelPresentationReceipt,
        hide_project_panel,
        project_panel_view: Workspace.ProjectPanelViewOptions,
        activate_project_panel_row: Workspace.ProjectPanelActivationRequest,
        plan_project_panel_action: Workspace.ProjectPanelActivationRequest,
        prepare_project_panel_action: Workspace.ProjectPanelActivationRequest,
        project_panel_action_execution_receipt: Workspace.ProjectPanelActionExecutionReceipt,
        project_panel_action_result_view,
        request_project_panel_action: Workspace.ProjectPanelActivationRequest,
        project_panel_action_receipt: Host.ProjectPanelActionReceipt,
        set_project_panel_scan: ProjectScan.ScanResult,
        set_project_panels: Workspace.ProjectPanelUpdate,
    };

    pub const MaintenancePolicy = struct {
        project_refresh_interval_seconds: u16 = 10,
        recovery_cleanup_interval_seconds: u16 = 300,
        project_refresh_enabled: bool = true,
        recovery_cleanup_enabled: bool = true,

        pub fn validate(self: MaintenancePolicy) !void {
            if (self.project_refresh_enabled and self.project_refresh_interval_seconds == 0) return error.InvalidMaintenancePolicy;
            if (self.recovery_cleanup_enabled and self.recovery_cleanup_interval_seconds == 0) return error.InvalidMaintenancePolicy;
        }
    };

    pub const MaintenanceState = struct {
        workspace_dirty_since_ms: ?u64 = null,
        autosave_pending: bool = false,
        project_refresh_pending: bool = false,
        recovery_cleanup_pending: bool = false,
        last_project_refresh_ms: ?u64 = null,
        last_recovery_cleanup_ms: ?u64 = null,
        last_project_refresh_summary: Workspace.ProjectPanelSummary = .{},
        last_recovery_cleanup_receipt: Storage.RecoveryCleanupReceipt = .{},
    };

    pub const MaintenanceTick = struct {
        now_ms: u64,
    };

    pub const MaintenancePlan = struct {
        now_ms: u64,
        autosave_due: bool = false,
        project_refresh_due: bool = false,
        recovery_cleanup_due: bool = false,
        autosave_pending: bool = false,
        project_refresh_pending: bool = false,
        recovery_cleanup_pending: bool = false,
        dirty_generation: u64 = 0,
        saved_generation: u64 = 0,

        pub fn hasDueWork(self: MaintenancePlan) bool {
            return self.autosave_due or self.project_refresh_due or self.recovery_cleanup_due;
        }
    };

    pub const ProjectRefreshReceipt = struct {
        completed_at_ms: u64,
        summary: Workspace.ProjectPanelSummary,
    };

    pub const RecoveryCleanupMaintenanceReceipt = struct {
        completed_at_ms: u64,
        receipt: Storage.RecoveryCleanupReceipt,
    };

    pub const WorkspaceFileDialogTarget = struct {
        operation: Host.WorkspaceFileDialogOperation,
        suggested_path: []const u8,
    };

    pub const WorkspaceFileDialogFileResult = struct {
        status: Host.WorkspaceFileDialogStatus,
        file_receipt: ?Storage.WorkspaceFileReceipt = null,

        pub fn deinit(self: WorkspaceFileDialogFileResult, allocator: std.mem.Allocator) void {
            if (self.file_receipt) |receipt| receipt.deinit(allocator);
        }
    };

    pub const SelectPane = struct {
        pane_id: Terminal.PaneId,
        mode: Workspace.SelectionMode,
    };

    pub const MovePaneToTab = struct {
        pane_id: Terminal.PaneId,
        target_tab_id: u64,
    };

    pub const RenameTab = struct {
        tab_id: u64,
        title: []const u8,
    };

    pub const ReorderTab = struct {
        tab_id: u64,
        destination_index: usize,
    };

    pub const SetTabAccent = struct {
        tab_id: u64,
        preset: ?Workspace.TabColorPreset,
    };

    pub const AdjustTabAccent = struct {
        tab_id: u64,
        delta: i8,
    };

    pub const DropdownDimensions = struct {
        width_percent: u8,
        height_percent: u8,
        width_px: u16 = 0,
        height_px: u16 = 0,
    };

    pub const PaneStatusEvent = struct {
        pane_id: Terminal.PaneId,
        event: Terminal.StatusEvent,
    };

    pub const PaneProfilePreset = struct {
        pane_id: Terminal.PaneId,
        preset: Terminal.ProfilePreset,
    };

    pub const PaneFontSize = struct {
        pane_id: Terminal.PaneId,
        size_pt: f32,
    };

    pub const AgentResumeChange = struct {
        pane_id: Terminal.PaneId,
        reference: @import("../terminal/Continuity.zig").AgentResume,
    };

    pub const ProfilePresetMenuTarget = struct {
        pane_id: Terminal.PaneId,
    };

    pub const ThemeImport = struct {
        format: Theme.ImportFormat,
        name: []const u8,
        contents: []const u8,
    };

    pub const ScrollBehavior = struct {
        lines: u8,
        smooth: bool,
    };

    pub const ThemeChromeColorChange = struct {
        role: Theme.ChromeColor,
        color: Theme.Color,
    };

    pub const ClipboardPaste = struct {
        input: []const u8,
        policy: Paste.PastePolicy = .literal,
    };

    pub const ClipboardWrite = struct {
        selection: Host.ClipboardSelection = .clipboard,
        bytes: []const u8,
    };

    pub const PaneClipboardPaste = struct {
        pane_id: Terminal.PaneId,
        input: []const u8,
        policy: Paste.PastePolicy = .literal,
    };

    pub const StatusTooltipTarget = struct {
        tab_id: ?u64 = null,
    };

    pub const StatusChange = struct {
        pane_id: Terminal.PaneId,
        previous: Terminal.TerminalStatus,
        current: Terminal.TerminalStatus,
        notification_queued: bool,
    };

    pub const ConfigSetting = enum {
        dropdown_dimensions,
        dropdown_animation,
        hide_on_focus_loss,
        focus_follows_pointer,
        show_pane_info,
        scrollback_lines,
        scroll_behavior,
        launch_profile,
        launch_profile_library,
        tab_position,
        status_indicator,
        show_status_counts,
        tooltip_details,
        desktop_notifications,
        long_running_minutes,
        font_size,
        font_family,
        font_antialias,
        font_hinting,
        background,
        default_theme,
        syntax_theme,
        panel_metrics,
    };

    pub const CommandResult = union(enum) {
        none,
        tab_created: u64,
        tab_reopened: u64,
        tab_renamed: u64,
        tab_accent_changed: u64,
        tab_closed: Workspace.TabCloseResult,
        pane_closed: Workspace.PaneCloseResult,
        pane_created: Terminal.PaneId,
        pane_zoom_changed: ?Terminal.PaneId,
        preset_applied: Workspace.LayoutPreset,
        broadcast_changed: bool,
        mode_changed: Config.WindowMode,
        window_lifecycle_requested: Host.WindowLifecycleRequest,
        window_lifecycle_changed: Host.WindowLifecycleStatus,
        shortcut_changed: Config.Shortcut,
        shortcut_registration_requested: Host.ShortcutRegistrationRequest,
        shortcut_registration_changed: Host.ShortcutRegistrationStatus,
        notification_delivery_requested: Host.NotificationDeliveryRequest,
        notification_delivery_changed: Host.NotificationDeliveryStatus,
        status_tooltip_requested: Host.StatusTooltipRequest,
        status_tooltip_changed: Host.StatusTooltipStatus,
        profile_preset_menu_requested: Host.ProfilePresetMenuRequest,
        profile_preset_menu_changed: Host.ProfilePresetMenuStatus,
        clipboard_transfer_requested: Host.ClipboardTransferRequest,
        clipboard_transfer_changed: Host.ClipboardTransferStatus,
        paste_delivery_requested: Host.PasteDeliveryRequest,
        paste_delivery_changed: Host.PasteDeliveryStatus,
        font_changed: f32,
        pane_selection_changed,
        status_changed: StatusChange,
        config_changed: ConfigSetting,
        profile_changed: Workspace.PaneProfileChange,
        theme_previewed: Theme.Preview,
        theme_installed: Theme.Preview,
        theme_selected: Theme.Preview,
        quick_note_read: []const u8,
        quick_note_changed: usize,
        paste_prepared: Paste.PreparedPaste,
        workspace_captured: Workspace.ProjectSnapshot,
        workspace_exported: Workspace.WorkspaceExport,
        workspace_restored,
        project_panels_changed: Workspace.ProjectPanelSummary,
        maintenance_planned: MaintenancePlan,
        project_refresh_recorded: Workspace.ProjectPanelSummary,
        recovery_cleanup_recorded: Storage.RecoveryCleanupReceipt,
        workspace_file_dialog_requested: Host.WorkspaceFileDialogRequest,
        workspace_file_dialog_changed: Host.WorkspaceFileDialogStatus,
        project_panel_requested: Host.ProjectPanelPresentationRequest,
        project_panel_changed: Host.ProjectPanelPresentationStatus,
        project_panel_viewed: Workspace.ProjectPanelView,
        project_panel_activated: Workspace.ProjectPanelActivation,
        project_panel_action_planned: Workspace.ProjectPanelActionPlan,
        project_panel_action_prepared: Workspace.ProjectPanelActionExecutionSpec,
        project_panel_action_execution_result: Workspace.ProjectPanelActionExecutionResult,
        project_panel_action_result_viewed: Workspace.ProjectPanelActionResultView,
        project_panel_action_requested: Host.ProjectPanelActionRequest,
        project_panel_action_changed: Host.ProjectPanelActionStatus,
    };

    pub fn init(allocator: std.mem.Allocator) !App {
        var cwd_buffer: [std.fs.max_path_bytes]u8 = undefined;
        const cwd_pointer = std.c.getcwd(&cwd_buffer, cwd_buffer.len) orelse
            return error.CurrentWorkingDirectoryUnavailable;
        const cwd = std.mem.sliceTo(cwd_pointer[0..cwd_buffer.len], 0);
        const config = Config.Config.defaults();
        const backend = Gui.Descriptor.preferredForLinux();
        var app = App{
            .allocator = allocator,
            .config = config,
            .backend = backend,
            .host = Host.NativeHost.init(config, backend, .default()),
            .workspace = try Workspace.Workspace.init(allocator, cwd),
            .themes = std.array_list.Managed(ThemeEntry).init(allocator),
            .telemetry_enabled = false,
        };
        errdefer app.deinit();
        _ = try app.installThemeCopy(Theme.Theme.builtinDark());
        return app;
    }

    pub fn deinit(self: *App) void {
        self.workspace.deinit();
        self.deinitThemeEntries();
        if (self.owned_font_family) |value| self.allocator.free(value);
        if (self.owned_default_theme) |value| self.allocator.free(value);
        if (self.owned_syntax_theme) |value| self.allocator.free(value);
        if (self.owned_preview_theme_name) |value| self.allocator.free(value);
        self.recovery.deinit(self.allocator);
    }

    pub fn applySessionEnvironment(self: *App, env: Host.SessionEnvironment) void {
        const backend = Host.backendForEnvironment(env);
        self.backend = backend;
        self.host.backend = backend;
    }

    pub fn validate(self: App) !void {
        try self.config.validate();
        if (self.telemetry_enabled) return error.TelemetryForbidden;
        if (self.backend.chrome.main_titlebar_px != 0 or self.backend.chrome.terminal_titlebar_px != 0) {
            return error.ThickTitlebarForbidden;
        }
    }

    pub fn activeTabStatusSummary(self: *App) !Workspace.TabStatusSummary {
        const tab = self.workspace.activeTab() orelse return error.NoActiveTab;
        return tab.statusSummary();
    }

    pub fn launchPlan(self: App) Host.LaunchPlan {
        return self.host.launchPlan();
    }

    pub fn presentationPlan(self: App, trigger: Host.PresentationTrigger) Host.PresentationPlan {
        return self.host.presentationPlan(trigger);
    }

    pub fn windowLifecycleRequest(self: App, trigger: Host.PresentationTrigger) Host.WindowLifecycleRequest {
        return self.host.windowLifecycleRequest(trigger);
    }

    pub fn shortcutRegistrationRequest(self: App) Host.ShortcutRegistrationRequest {
        return self.host.shortcutRegistrationRequest();
    }

    pub fn notificationDeliveryRequest(self: App) Host.NotificationDeliveryRequest {
        return self.host.notificationDeliveryRequest();
    }

    pub fn statusTooltipRequest(self: *App, target: StatusTooltipTarget) !Host.StatusTooltipRequest {
        const tab = try self.resolveTooltipTab(target);
        return self.host.statusTooltipRequest(tab.id, tab.statusSummary(), self.config.tabs.tooltip_details);
    }

    pub fn profilePresetMenuRequest(self: *App, target: ProfilePresetMenuTarget) !Host.ProfilePresetMenuRequest {
        const pane = self.workspace.findPane(target.pane_id) orelse return error.PaneNotFound;
        return self.host.profilePresetMenuRequest(target.pane_id, pane.profile);
    }

    pub fn clipboardTransferRequest(
        self: App,
        operation: Host.ClipboardOperation,
        selection: Host.ClipboardSelection,
        bytes: usize,
    ) !Host.ClipboardTransferRequest {
        return self.host.clipboardTransferRequest(operation, selection, bytes);
    }

    pub fn pasteDeliveryRequest(
        self: App,
        pane_id: Terminal.PaneId,
        bytes: usize,
        bracketed: bool,
        policy: Paste.PastePolicy,
    ) !Host.PasteDeliveryRequest {
        return self.host.pasteDeliveryRequest(pane_id, bytes, bracketed, policy);
    }

    pub fn configureRecoveryPolicy(self: *App, policy: Storage.RecoveryPolicy) !void {
        try policy.validate();
        self.recovery.policy = policy;
    }

    pub fn configureMaintenancePolicy(self: *App, policy: MaintenancePolicy) !void {
        try policy.validate();
        self.maintenance_policy = policy;
    }

    pub fn markWorkspaceDirty(self: *App) void {
        self.recovery.markDirty();
        self.maintenance.workspace_dirty_since_ms = null;
    }

    pub fn markWorkspaceDirtyAt(self: *App, now_ms: u64) void {
        self.recovery.markDirty();
        self.maintenance.workspace_dirty_since_ms = now_ms;
    }

    pub fn defaultWorkspacePathAlloc(self: App, home_dir: []const u8, project_name: []const u8, role: Storage.WorkspaceFileRole) ![]u8 {
        return Storage.defaultWorkspacePathAlloc(self.allocator, home_dir, project_name, role);
    }

    pub fn defaultConfigPathAlloc(self: App, home_dir: []const u8) ![]u8 {
        return ConfigStorage.defaultConfigPathAlloc(self.allocator, home_dir);
    }

    pub fn defaultThemeLibraryPathAlloc(self: App, home_dir: []const u8) ![]u8 {
        return ThemeStorage.defaultThemeLibraryPathAlloc(self.allocator, home_dir);
    }

    pub fn saveConfigFile(
        self: App,
        io: std.Io,
        dir: std.Io.Dir,
        path: []const u8,
        role: ConfigStorage.ConfigFileRole,
    ) !ConfigStorage.ConfigFileReceipt {
        return ConfigStorage.saveConfigFile(self.allocator, io, dir, path, self.config, role);
    }

    pub fn loadConfigFile(
        self: *App,
        io: std.Io,
        dir: std.Io.Dir,
        path: []const u8,
        role: ConfigStorage.ConfigFileRole,
    ) !ConfigStorage.ConfigFileReceipt {
        var loaded = try ConfigStorage.loadConfigFile(self.allocator, io, dir, path, role);
        errdefer loaded.deinit(self.allocator);
        try self.applyLoadedConfig(loaded.loaded.config);
        loaded.loaded.deinit(self.allocator);
        const receipt = loaded.receipt;
        loaded.receipt = undefined;
        return receipt;
    }

    pub fn saveThemeLibraryFile(
        self: App,
        io: std.Io,
        dir: std.Io.Dir,
        path: []const u8,
        role: ThemeStorage.ThemeFileRole,
    ) !ThemeStorage.ThemeFileReceipt {
        const themes = try self.themeListAlloc();
        defer self.allocator.free(themes);
        return ThemeStorage.saveThemeLibraryFile(self.allocator, io, dir, path, themes, role);
    }

    pub fn loadThemeLibraryFile(
        self: *App,
        io: std.Io,
        dir: std.Io.Dir,
        path: []const u8,
        role: ThemeStorage.ThemeFileRole,
    ) !ThemeStorage.ThemeFileReceipt {
        var loaded = try ThemeStorage.loadThemeLibraryFile(self.allocator, io, dir, path, role);
        errdefer loaded.deinit(self.allocator);
        try self.replaceThemeLibrary(loaded.loaded.entries);
        loaded.loaded.deinit(self.allocator);
        const receipt = loaded.receipt;
        loaded.receipt = undefined;
        return receipt;
    }

    pub fn saveWorkspaceFile(
        self: *App,
        io: std.Io,
        dir: std.Io.Dir,
        path: []const u8,
        role: Storage.WorkspaceFileRole,
    ) !Storage.WorkspaceFileReceipt {
        var snapshot = try self.workspace.captureSnapshot();
        defer snapshot.deinit(self.allocator);

        const receipt = try Storage.saveSnapshotFile(
            self.allocator,
            io,
            dir,
            path,
            snapshot,
            role,
            role == .autosave or role == .recovery or self.recovery.hasPendingRecovery(),
        );
        errdefer receipt.deinit(self.allocator);
        try self.recovery.markSaved(self.allocator, receipt.path, role);
        self.maintenance.autosave_pending = false;
        self.maintenance.workspace_dirty_since_ms = null;
        return receipt;
    }

    pub fn loadWorkspaceFile(
        self: *App,
        io: std.Io,
        dir: std.Io.Dir,
        path: []const u8,
        role: Storage.WorkspaceFileRole,
    ) !Storage.WorkspaceFileReceipt {
        var loaded = try Storage.loadSnapshotFile(self.allocator, io, dir, path, role);
        errdefer loaded.deinit(self.allocator);
        try self.workspace.restoreSnapshot(loaded.snapshot);
        try self.recovery.markLoaded(self.allocator, loaded.receipt.path, role);
        const receipt = loaded.receipt;
        loaded.snapshot.deinit(self.allocator);
        loaded.receipt = undefined;
        return receipt;
    }

    pub fn recordRecentWorkspace(self: *App, path: []const u8) !void {
        var next = self.config;
        try next.recent_workspaces.record(path);
        try self.applyConfig(next);
    }

    pub fn loadActivatedWorkspacePath(
        self: *App,
        io: std.Io,
        dir: std.Io.Dir,
        path: []const u8,
    ) !Storage.WorkspaceFileReceipt {
        _ = try WorkspaceActivation.WorkspacePath.init(path);
        const receipt = try self.loadWorkspaceFile(io, dir, path, .manual);
        errdefer receipt.deinit(self.allocator);
        try self.recordRecentWorkspace(path);
        return receipt;
    }

    pub fn loadActivatedWorkspaceUri(
        self: *App,
        io: std.Io,
        dir: std.Io.Dir,
        uri: []const u8,
    ) !Storage.WorkspaceFileReceipt {
        const parsed = try WorkspaceActivation.parseWorkspaceUri(uri);
        return self.loadActivatedWorkspacePath(io, dir, parsed.slice());
    }

    pub fn planRecoveryCleanup(self: App, candidates: []const Storage.RecoveryCleanupCandidate) !Storage.RecoveryCleanupPlan {
        return Storage.planRecoveryCleanupAlloc(self.allocator, self.recovery.policy, candidates);
    }

    pub fn applyRecoveryCleanup(self: App, io: std.Io, dir: std.Io.Dir, plan: Storage.RecoveryCleanupPlan) !Storage.RecoveryCleanupReceipt {
        _ = self;
        return Storage.applyRecoveryCleanup(io, dir, plan);
    }

    pub fn applyProjectScan(self: *App, scan: ProjectScan.ScanResult) !Workspace.ProjectPanelSummary {
        return self.workspace.updateProjectPanels(scan.update());
    }

    pub fn workspaceFileDialogRequest(self: App, target: WorkspaceFileDialogTarget) !Host.WorkspaceFileDialogRequest {
        return self.host.workspaceFileDialogRequest(target.operation, target.suggested_path);
    }

    pub fn projectPanelPresentationRequest(self: App) Host.ProjectPanelPresentationRequest {
        return self.host.projectPanelPresentationRequest(self.workspace.project_panels.summary());
    }

    pub fn projectPanelView(self: App, options: Workspace.ProjectPanelViewOptions) Workspace.ProjectPanelView {
        return self.workspace.projectPanelView(options);
    }

    pub fn activateProjectPanelRow(self: App, request: Workspace.ProjectPanelActivationRequest) !Workspace.ProjectPanelActivation {
        return self.workspace.activateProjectPanelRow(request);
    }

    pub fn projectPanelActionPlan(self: App, request: Workspace.ProjectPanelActivationRequest) !Workspace.ProjectPanelActionPlan {
        return self.workspace.projectPanelActionPlan(request);
    }

    pub fn projectPanelActionExecutionSpec(self: App, request: Workspace.ProjectPanelActivationRequest) !Workspace.ProjectPanelActionExecutionSpec {
        return self.workspace.projectPanelActionExecutionSpec(request);
    }

    pub fn prepareProjectPanelActionExecution(self: *App, request: Workspace.ProjectPanelActivationRequest) !Workspace.ProjectPanelActionExecutionSpec {
        const spec = try self.projectPanelActionExecutionSpec(request);
        self.pending_project_panel_action_execution = .{
            .source = spec.source,
            .executor = spec.executor,
            .operation = spec.operation,
        };
        return spec;
    }

    pub fn applyProjectPanelActionExecutionReceipt(
        self: *App,
        receipt: Workspace.ProjectPanelActionExecutionReceipt,
    ) !Workspace.ProjectPanelActionExecutionResult {
        if (!receipt.completed()) return error.InvalidProjectPanelActionExecutionReceipt;
        const expected = self.pending_project_panel_action_execution orelse return error.ProjectPanelActionExecutionMismatch;
        if (!expected.matches(receipt)) return error.ProjectPanelActionExecutionMismatch;

        const result = try Workspace.ProjectPanelActionExecutionResult.fromReceipt(receipt);
        self.pending_project_panel_action_execution = null;
        self.last_project_panel_action_result = result;
        return result;
    }

    pub fn projectPanelActionResultView(self: App) !Workspace.ProjectPanelActionResultView {
        const result = self.last_project_panel_action_result orelse return error.ProjectPanelActionResultMissing;
        return result.view();
    }

    pub fn projectPanelActionRequest(self: App, request: Workspace.ProjectPanelActivationRequest) !Host.ProjectPanelActionRequest {
        return self.host.projectPanelActionRequest(try self.activateProjectPanelRow(request));
    }

    pub fn applyWorkspaceFileDialogFileAction(
        self: *App,
        io: std.Io,
        dir: std.Io.Dir,
        receipt: Host.WorkspaceFileDialogReceipt,
        role: Storage.WorkspaceFileRole,
    ) !WorkspaceFileDialogFileResult {
        if (role != .manual) return error.InvalidWorkspaceFileDialogRole;

        const status = try self.host.applyWorkspaceFileDialogReceipt(receipt);
        if (status != .selected) return .{ .status = status };

        const selected_path = receipt.selected_path orelse return error.InvalidWorkspaceFileDialogReceipt;
        const file_receipt = switch (receipt.operation) {
            .save => try self.saveWorkspaceFile(io, dir, selected_path, role),
            .open => try self.loadWorkspaceFile(io, dir, selected_path, role),
        };
        return .{
            .status = status,
            .file_receipt = file_receipt,
        };
    }

    pub fn advanceMaintenance(self: *App, tick: MaintenanceTick) !MaintenancePlan {
        try self.maintenance_policy.validate();

        if (self.recovery.dirty and self.maintenance.workspace_dirty_since_ms == null) {
            self.maintenance.workspace_dirty_since_ms = tick.now_ms;
        }

        var plan = MaintenancePlan{
            .now_ms = tick.now_ms,
            .dirty_generation = self.recovery.generation,
            .saved_generation = self.recovery.saved_generation,
            .autosave_pending = self.maintenance.autosave_pending,
            .project_refresh_pending = self.maintenance.project_refresh_pending,
            .recovery_cleanup_pending = self.maintenance.recovery_cleanup_pending,
        };

        if (!self.maintenance.autosave_pending and self.recovery.dirty) {
            const dirty_since = self.maintenance.workspace_dirty_since_ms orelse tick.now_ms;
            if (elapsedSeconds(dirty_since, tick.now_ms) >= self.recovery.policy.autosave_interval_seconds and
                self.recovery.generation != self.recovery.saved_generation and
                self.recovery.policy.enabled)
            {
                self.maintenance.autosave_pending = true;
                plan.autosave_due = true;
            }
        }

        if (!self.maintenance.project_refresh_pending and self.maintenance_policy.project_refresh_enabled) {
            if (self.maintenance.last_project_refresh_ms == null or
                elapsedSeconds(self.maintenance.last_project_refresh_ms.?, tick.now_ms) >= self.maintenance_policy.project_refresh_interval_seconds)
            {
                self.maintenance.project_refresh_pending = true;
                plan.project_refresh_due = true;
            }
        }

        if (!self.maintenance.recovery_cleanup_pending and self.maintenance_policy.recovery_cleanup_enabled) {
            if (self.maintenance.last_recovery_cleanup_ms == null or
                elapsedSeconds(self.maintenance.last_recovery_cleanup_ms.?, tick.now_ms) >= self.maintenance_policy.recovery_cleanup_interval_seconds)
            {
                self.maintenance.recovery_cleanup_pending = true;
                plan.recovery_cleanup_due = true;
            }
        }

        plan.autosave_pending = self.maintenance.autosave_pending;
        plan.project_refresh_pending = self.maintenance.project_refresh_pending;
        plan.recovery_cleanup_pending = self.maintenance.recovery_cleanup_pending;
        return plan;
    }

    pub fn recordProjectRefresh(self: *App, receipt: ProjectRefreshReceipt) !Workspace.ProjectPanelSummary {
        if (self.maintenance.last_project_refresh_ms) |last| {
            if (receipt.completed_at_ms < last) return error.StaleProjectRefreshReceipt;
        }
        self.maintenance.project_refresh_pending = false;
        self.maintenance.last_project_refresh_ms = receipt.completed_at_ms;
        self.maintenance.last_project_refresh_summary = receipt.summary;
        return receipt.summary;
    }

    pub fn recordRecoveryCleanup(self: *App, receipt: RecoveryCleanupMaintenanceReceipt) !Storage.RecoveryCleanupReceipt {
        if (self.maintenance.last_recovery_cleanup_ms) |last| {
            if (receipt.completed_at_ms < last) return error.StaleRecoveryCleanupReceipt;
        }
        self.maintenance.recovery_cleanup_pending = false;
        self.maintenance.last_recovery_cleanup_ms = receipt.completed_at_ms;
        self.maintenance.last_recovery_cleanup_receipt = receipt.receipt;
        return receipt.receipt;
    }

    pub fn findTheme(self: App, name: []const u8) ?Theme.Theme {
        for (self.themes.items) |entry| {
            if (std.mem.eql(u8, entry.theme.name, name)) return entry.theme;
        }
        return null;
    }

    pub fn activeTheme(self: App) Theme.Theme {
        if (self.findTheme(self.config.default_theme)) |theme| return theme;
        if (std.mem.eql(u8, self.config.default_theme, "noctty-high-contrast"))
            return Theme.Theme.builtinHighContrast();
        return Theme.Theme.builtinDark();
    }

    pub fn dispatch(self: *App, command: Command) !CommandResult {
        switch (command) {
            .new_tab => {
                const tab = self.workspace.activeTab() orelse return error.NoActiveTab;
                const pane = tab.findPane(tab.active_pane_id) orelse return error.PaneNotFound;
                const id = try self.workspace.addDefaultTab(pane.cwd);
                self.markWorkspaceDirtyAt(0);
                return .{ .tab_created = id };
            },
            .reopen_tab => {
                const reopened = try self.workspace.reopenLastClosedTab();
                self.markWorkspaceDirtyAt(0);
                return .{ .tab_reopened = reopened };
            },
            .rename_tab => |rename| {
                _ = try self.workspace.renameTab(rename.tab_id, rename.title);
                self.markWorkspaceDirtyAt(0);
                return .{ .tab_renamed = rename.tab_id };
            },
            .reorder_tab => |reorder| {
                try self.workspace.reorderTab(reorder.tab_id, reorder.destination_index);
                self.markWorkspaceDirtyAt(0);
                return .none;
            },
            .set_tab_accent => |request| {
                _ = try self.workspace.setTabAccent(request.tab_id, request.preset);
                self.markWorkspaceDirtyAt(0);
                return .{ .tab_accent_changed = request.tab_id };
            },
            .adjust_tab_accent => |request| {
                _ = try self.workspace.adjustTabAccent(request.tab_id, request.delta);
                self.markWorkspaceDirtyAt(0);
                return .{ .tab_accent_changed = request.tab_id };
            },
            .close_tab => |tab_id| {
                const closed = try self.workspace.closeTab(tab_id);
                self.markWorkspaceDirtyAt(0);
                return .{ .tab_closed = closed };
            },
            .close_pane => |pane_id| {
                const closed = try self.workspace.closePane(pane_id);
                self.markWorkspaceDirtyAt(0);
                return .{ .pane_closed = closed };
            },
            .focus_pane => |pane_id| {
                try self.workspace.activatePane(pane_id);
                self.markWorkspaceDirtyAt(0);
                return .pane_selection_changed;
            },
            .focus_next_pane => {
                const tab = self.workspace.activeTab() orelse return error.NoActiveTab;
                _ = try tab.focusPaneRelative(true);
                self.markWorkspaceDirtyAt(0);
                return .pane_selection_changed;
            },
            .focus_previous_pane => {
                const tab = self.workspace.activeTab() orelse return error.NoActiveTab;
                _ = try tab.focusPaneRelative(false);
                self.markWorkspaceDirtyAt(0);
                return .pane_selection_changed;
            },
            .toggle_pane_zoom => |pane_id| {
                try self.workspace.activatePane(pane_id);
                const tab = self.workspace.activeTab() orelse return error.NoActiveTab;
                return .{ .pane_zoom_changed = try tab.togglePaneZoom(pane_id) };
            },
            .move_pane_to_tab => |move| {
                try self.workspace.movePaneToTab(move.pane_id, move.target_tab_id);
                self.markWorkspaceDirtyAt(0);
                return .pane_selection_changed;
            },
            .split_left => {
                const pane_id = try self.workspace.splitActivePane(.left);
                self.markWorkspaceDirtyAt(0);
                return .{ .pane_created = pane_id };
            },
            .split_right => {
                const pane_id = try self.workspace.splitActivePane(.right);
                self.markWorkspaceDirtyAt(0);
                return .{ .pane_created = pane_id };
            },
            .split_up => {
                const pane_id = try self.workspace.splitActivePane(.up);
                self.markWorkspaceDirtyAt(0);
                return .{ .pane_created = pane_id };
            },
            .split_down => {
                const pane_id = try self.workspace.splitActivePane(.down);
                self.markWorkspaceDirtyAt(0);
                return .{ .pane_created = pane_id };
            },
            .preset => |preset| {
                try self.workspace.applyPresetToActiveTab(preset);
                self.markWorkspaceDirtyAt(0);
                return .{ .preset_applied = preset };
            },
            .toggle_broadcast => {
                self.workspace.broadcast_enabled = !self.workspace.broadcast_enabled;
                self.markWorkspaceDirtyAt(0);
                return .{ .broadcast_changed = self.workspace.broadcast_enabled };
            },
            .set_window_mode => |mode| {
                self.config.default_mode = mode;
                self.host.config.default_mode = mode;
                self.host.setMode(mode);
                return .{ .mode_changed = mode };
            },
            .set_dropdown_dimensions => |dimensions| {
                var next = self.config;
                next.dropdown.width_percent = dimensions.width_percent;
                next.dropdown.height_percent = dimensions.height_percent;
                next.dropdown.width_px = dimensions.width_px;
                next.dropdown.height_px = dimensions.height_px;
                try self.applyConfig(next);
                return .{ .config_changed = .dropdown_dimensions };
            },
            .set_dropdown_animation_ms => |duration| {
                var next = self.config;
                next.dropdown.animation_ms = @min(duration, 2000);
                try self.applyConfig(next);
                return .{ .config_changed = .dropdown_animation };
            },
            .set_hide_on_focus_loss => |enabled| {
                var next = self.config;
                next.dropdown.hide_on_focus_loss = enabled;
                try self.applyConfig(next);
                return .{ .config_changed = .hide_on_focus_loss };
            },
            .set_focus_follows_pointer => |enabled| {
                var next = self.config;
                next.tabs.focus_follows_pointer = enabled;
                try self.applyConfig(next);
                return .{ .config_changed = .focus_follows_pointer };
            },
            .set_show_pane_info => |enabled| {
                var next = self.config;
                next.tabs.show_pane_info = enabled;
                try self.applyConfig(next);
                return .{ .config_changed = .show_pane_info };
            },
            .set_scrollback_lines => |lines| {
                var next = self.config;
                try next.terminal.setScrollbackLines(lines);
                try self.applyConfig(next);
                return .{ .config_changed = .scrollback_lines };
            },
            .set_scroll_behavior => |behavior| {
                var next = self.config;
                next.terminal.scroll_lines = behavior.lines;
                next.terminal.smooth_scroll = behavior.smooth;
                try self.applyConfig(next);
                return .{ .config_changed = .scroll_behavior };
            },
            .set_launch_profile => |profile| {
                var next = self.config;
                try next.terminal.setLaunchProfile(profile);
                try self.applyConfig(next);
                return .{ .config_changed = .launch_profile };
            },
            .save_named_launch_profile => |request| {
                var next = self.config;
                _ = try next.terminal.saveAndSelectLaunchProfile(request.name, request.profile);
                try self.applyConfig(next);
                return .{ .config_changed = .launch_profile_library };
            },
            .select_named_launch_profile => |index| {
                var next = self.config;
                try next.terminal.selectLaunchProfile(index);
                try self.applyConfig(next);
                return .{ .config_changed = .launch_profile_library };
            },
            .remove_named_launch_profile => |index| {
                var next = self.config;
                try next.terminal.removeLaunchProfile(index);
                try self.applyConfig(next);
                return .{ .config_changed = .launch_profile_library };
            },
            .toggle_dropdown => {
                self.host.toggleDropdown();
                return .{ .mode_changed = self.host.window.mode };
            },
            .request_window_lifecycle => |trigger| {
                return .{ .window_lifecycle_requested = self.host.beginWindowLifecycle(trigger) };
            },
            .window_lifecycle_receipt => |receipt| {
                return .{ .window_lifecycle_changed = try self.host.applyWindowLifecycleReceipt(receipt) };
            },
            .begin_shortcut_recording => {
                self.host.beginShortcutRecording();
                return .none;
            },
            .capture_shortcut => |event| {
                const shortcut = try self.host.captureShortcut(event);
                self.config.dropdown.shortcut = shortcut;
                return .{ .shortcut_changed = shortcut };
            },
            .register_global_shortcut => {
                return .{ .shortcut_registration_requested = self.host.beginShortcutRegistration() };
            },
            .shortcut_registration_receipt => |receipt| {
                return .{ .shortcut_registration_changed = try self.host.applyShortcutRegistrationReceipt(receipt) };
            },
            .deliver_last_notification => {
                return .{ .notification_delivery_requested = self.host.beginNotificationDelivery() };
            },
            .notification_delivery_receipt => |receipt| {
                return .{ .notification_delivery_changed = try self.host.applyNotificationDeliveryReceipt(receipt) };
            },
            .show_status_tooltip => |target| {
                const tab = try self.resolveTooltipTab(target);
                return .{ .status_tooltip_requested = self.host.beginStatusTooltip(tab.id, tab.statusSummary(), self.config.tabs.tooltip_details) };
            },
            .status_tooltip_receipt => |receipt| {
                return .{ .status_tooltip_changed = try self.host.applyStatusTooltipReceipt(receipt) };
            },
            .hide_status_tooltip => {
                return .{ .status_tooltip_changed = self.host.hideStatusTooltip() };
            },
            .show_profile_preset_menu => |target| {
                const pane = self.workspace.findPane(target.pane_id) orelse return error.PaneNotFound;
                return .{ .profile_preset_menu_requested = try self.host.beginProfilePresetMenu(target.pane_id, pane.profile) };
            },
            .profile_preset_menu_receipt => |receipt| {
                return .{ .profile_preset_menu_changed = try self.host.applyProfilePresetMenuReceipt(receipt) };
            },
            .hide_profile_preset_menu => {
                return .{ .profile_preset_menu_changed = self.host.hideProfilePresetMenu() };
            },
            .select_profile_preset_from_menu => |change| {
                _ = self.workspace.findPane(change.pane_id) orelse return error.PaneNotFound;
                _ = try self.host.applyProfilePresetMenuReceipt(.{
                    .pane_id = change.pane_id,
                    .status = .selected,
                    .selected_preset = change.preset,
                });
                const profile_change = try self.workspace.applyProfilePreset(change.pane_id, change.preset, self.config);
                self.markWorkspaceDirtyAt(0);
                return .{ .profile_changed = profile_change };
            },
            .read_clipboard => |selection| {
                return .{ .clipboard_transfer_requested = try self.host.beginClipboardTransfer(.read, selection, 0) };
            },
            .write_clipboard => |request| {
                return .{ .clipboard_transfer_requested = try self.host.beginClipboardTransfer(.write, request.selection, request.bytes.len) };
            },
            .clipboard_transfer_receipt => |receipt| {
                return .{ .clipboard_transfer_changed = try self.host.applyClipboardTransferReceipt(receipt) };
            },
            .deliver_paste_to_pane => |request| {
                _ = self.workspace.findPane(request.pane_id) orelse return error.PaneNotFound;
                const prepared = try self.prepareClipboardPaste(request.input, request.policy);
                defer prepared.deinit(self.allocator);
                return .{ .paste_delivery_requested = try self.host.beginPasteDelivery(
                    request.pane_id,
                    prepared.bytes.len,
                    prepared.bracketed,
                    prepared.applied_policy,
                ) };
            },
            .paste_delivery_receipt => |receipt| {
                return .{ .paste_delivery_changed = try self.host.applyPasteDeliveryReceipt(receipt) };
            },
            .font_larger => {
                self.config.font.size_pt = self.config.font.clampSize(self.config.font.size_pt + 1.0);
                self.host.config.font.size_pt = self.config.font.size_pt;
                return .{ .font_changed = self.config.font.size_pt };
            },
            .font_smaller => {
                self.config.font.size_pt = self.config.font.clampSize(self.config.font.size_pt - 1.0);
                self.host.config.font.size_pt = self.config.font.size_pt;
                return .{ .font_changed = self.config.font.size_pt };
            },
            .select_pane => |selection| {
                const tab = self.workspace.activeTab() orelse return error.NoActiveTab;
                try tab.selectPane(selection.pane_id, selection.mode);
                self.markWorkspaceDirtyAt(0);
                return .pane_selection_changed;
            },
            .tag_selected_panes => |tag| {
                _ = try self.workspace.tagSelectedPanes(tag);
                self.markWorkspaceDirtyAt(0);
                return .pane_selection_changed;
            },
            .remove_tag_from_selected_panes => |tag| {
                _ = self.workspace.removeTagFromSelectedPanes(tag);
                self.markWorkspaceDirtyAt(0);
                return .pane_selection_changed;
            },
            .set_smart_filter => |tag| {
                try self.workspace.setSmartFilterTag(tag);
                self.markWorkspaceDirtyAt(0);
                return .pane_selection_changed;
            },
            .terminal_status => |status_event| {
                const change = try self.workspace.applyStatusEvent(
                    status_event.pane_id,
                    status_event.event,
                    self.config.status.long_running_minutes,
                );
                const notification_queued = change.current != change.previous and
                    self.host.queueStatusNotification(
                        status_event.pane_id,
                        change.current,
                        self.config.status.desktop_notifications,
                    ) != null;
                return .{ .status_changed = .{
                    .pane_id = change.pane_id,
                    .previous = change.previous,
                    .current = change.current,
                    .notification_queued = notification_queued,
                } };
            },
            .set_tab_position => |position| {
                var next = self.config;
                next.tabs.position = position;
                try self.applyConfig(next);
                return .{ .config_changed = .tab_position };
            },
            .set_status_indicator => |indicator| {
                var next = self.config;
                next.status.indicator = indicator;
                try self.applyConfig(next);
                return .{ .config_changed = .status_indicator };
            },
            .set_show_status_counts => |enabled| {
                var next = self.config;
                next.tabs.show_status_counts = enabled;
                try self.applyConfig(next);
                return .{ .config_changed = .show_status_counts };
            },
            .set_tooltip_details => |enabled| {
                var next = self.config;
                next.tabs.tooltip_details = enabled;
                try self.applyConfig(next);
                return .{ .config_changed = .tooltip_details };
            },
            .set_desktop_notifications => |enabled| {
                var next = self.config;
                next.status.desktop_notifications = enabled;
                try self.applyConfig(next);
                return .{ .config_changed = .desktop_notifications };
            },
            .set_long_running_minutes => |minutes| {
                var next = self.config;
                next.status.long_running_minutes = minutes;
                try self.applyConfig(next);
                return .{ .config_changed = .long_running_minutes };
            },
            .set_font_size => |size| {
                var next = self.config;
                next.font.size_pt = size;
                try self.applyConfig(next);
                return .{ .config_changed = .font_size };
            },
            .set_font_family => |family| {
                try self.setOwnedFontFamily(family);
                return .{ .config_changed = .font_family };
            },
            .set_font_antialias => |antialias| {
                var next = self.config;
                next.font.antialias = antialias;
                try self.applyConfig(next);
                return .{ .config_changed = .font_antialias };
            },
            .set_font_hinting => |hinting| {
                var next = self.config;
                next.font.hinting = hinting;
                try self.applyConfig(next);
                return .{ .config_changed = .font_hinting };
            },
            .set_background => |background| {
                var next = self.config;
                next.background = background;
                try self.applyConfig(next);
                return .{ .config_changed = .background };
            },
            .set_default_theme => |name| {
                try self.setOwnedDefaultTheme(name);
                return .{ .config_changed = .default_theme };
            },
            .set_syntax_theme => |name| {
                try self.setOwnedSyntaxTheme(name);
                return .{ .config_changed = .syntax_theme };
            },
            .set_panel_metrics => |metrics| {
                var next = self.config;
                next.panels = metrics;
                try self.applyConfig(next);
                return .{ .config_changed = .panel_metrics };
            },
            .set_pane_profile_preset => |change| {
                const profile_change = try self.workspace.applyProfilePreset(change.pane_id, change.preset, self.config);
                self.markWorkspaceDirtyAt(0);
                return .{ .profile_changed = profile_change };
            },
            .set_pane_font_size => |change| {
                const profile_change = try self.workspace.setPaneFontSize(change.pane_id, change.size_pt, self.config.font);
                self.markWorkspaceDirtyAt(0);
                return .{ .profile_changed = profile_change };
            },
            .set_agent_resume => |change| {
                const pane = self.workspace.findPane(change.pane_id) orelse return error.PaneNotFound;
                try pane.setAgentResume(change.reference);
                self.markWorkspaceDirtyAt(0);
                return .none;
            },
            .clear_agent_resume => |pane_id| {
                const pane = self.workspace.findPane(pane_id) orelse return error.PaneNotFound;
                pane.clearAgentResume();
                self.markWorkspaceDirtyAt(0);
                return .none;
            },
            .preview_theme_import => |request| {
                const theme = try self.previewThemeImport(request);
                return .{ .theme_previewed = Theme.Preview.fromTheme(theme) };
            },
            .install_theme_import => |request| {
                const imported = try Theme.importTheme(self.allocator, request.format, std.mem.trim(u8, request.name, " \t\r\n"), request.contents);
                const theme = try self.installThemeCopy(imported);
                return .{ .theme_installed = Theme.Preview.fromTheme(theme) };
            },
            .select_theme => |name| {
                const theme_name = std.mem.trim(u8, name, " \t\r\n");
                const theme = self.findTheme(theme_name) orelse builtin: {
                    if (std.mem.eql(u8, theme_name, "noctty-high-contrast"))
                        break :builtin try self.installThemeCopy(
                            Theme.Theme.builtinHighContrast(),
                        );
                    return error.ThemeNotInstalled;
                };
                try self.setOwnedDefaultTheme(theme.name);
                return .{ .theme_selected = Theme.Preview.fromTheme(theme) };
            },
            .set_theme_chrome_color => |change| {
                const theme = try self.setActiveThemeChromeColor(change);
                return .{ .theme_installed = Theme.Preview.fromTheme(theme) };
            },
            .read_quick_note => return .{ .quick_note_read = self.workspace.quick_note },
            .set_quick_note => |text| {
                const changed = try self.workspace.setQuickNote(text);
                self.markWorkspaceDirtyAt(0);
                return .{ .quick_note_changed = changed };
            },
            .prepare_paste => |request| {
                const prepared = try self.prepareClipboardPaste(request.input, request.policy);
                return .{ .paste_prepared = prepared };
            },
            .capture_workspace => {
                return .{ .workspace_captured = try self.workspace.captureSnapshot() };
            },
            .restore_workspace => |snapshot| {
                try self.workspace.restoreSnapshot(snapshot);
                return .workspace_restored;
            },
            .export_workspace => {
                var snapshot = try self.workspace.captureSnapshot();
                defer snapshot.deinit(self.allocator);
                return .{ .workspace_exported = .{
                    .bytes = try Workspace.exportSnapshotAlloc(self.allocator, snapshot),
                } };
            },
            .import_workspace => |bytes| {
                var snapshot = try Workspace.importSnapshotAlloc(self.allocator, bytes);
                defer snapshot.deinit(self.allocator);
                try self.workspace.restoreSnapshot(snapshot);
                return .workspace_restored;
            },
            .maintenance_tick => |tick| {
                return .{ .maintenance_planned = try self.advanceMaintenance(tick) };
            },
            .project_refresh_receipt => |receipt| {
                return .{ .project_refresh_recorded = try self.recordProjectRefresh(receipt) };
            },
            .recovery_cleanup_receipt => |receipt| {
                return .{ .recovery_cleanup_recorded = try self.recordRecoveryCleanup(receipt) };
            },
            .show_workspace_file_dialog => |target| {
                return .{ .workspace_file_dialog_requested = try self.host.beginWorkspaceFileDialog(
                    target.operation,
                    target.suggested_path,
                ) };
            },
            .workspace_file_dialog_receipt => |receipt| {
                return .{ .workspace_file_dialog_changed = try self.host.applyWorkspaceFileDialogReceipt(receipt) };
            },
            .show_project_panel => {
                return .{ .project_panel_requested = self.host.beginProjectPanelPresentation(self.workspace.project_panels.summary()) };
            },
            .project_panel_receipt => |receipt| {
                return .{ .project_panel_changed = try self.host.applyProjectPanelPresentationReceipt(receipt) };
            },
            .hide_project_panel => {
                return .{ .project_panel_changed = self.host.hideProjectPanelPresentation() };
            },
            .project_panel_view => |options| {
                return .{ .project_panel_viewed = self.projectPanelView(options) };
            },
            .activate_project_panel_row => |request| {
                return .{ .project_panel_activated = try self.activateProjectPanelRow(request) };
            },
            .plan_project_panel_action => |request| {
                return .{ .project_panel_action_planned = try self.projectPanelActionPlan(request) };
            },
            .prepare_project_panel_action => |request| {
                return .{ .project_panel_action_prepared = try self.prepareProjectPanelActionExecution(request) };
            },
            .project_panel_action_execution_receipt => |receipt| {
                return .{ .project_panel_action_execution_result = try self.applyProjectPanelActionExecutionReceipt(receipt) };
            },
            .project_panel_action_result_view => {
                return .{ .project_panel_action_result_viewed = try self.projectPanelActionResultView() };
            },
            .request_project_panel_action => |request| {
                const activation = try self.activateProjectPanelRow(request);
                return .{ .project_panel_action_requested = self.host.beginProjectPanelAction(activation) };
            },
            .project_panel_action_receipt => |receipt| {
                return .{ .project_panel_action_changed = try self.host.applyProjectPanelActionReceipt(receipt) };
            },
            .set_project_panel_scan => |scan| {
                return .{ .project_panels_changed = try self.applyProjectScan(scan) };
            },
            .set_project_panels => |update| {
                return .{ .project_panels_changed = try self.workspace.updateProjectPanels(update) };
            },
        }
    }

    fn resolveTooltipTab(self: *App, target: StatusTooltipTarget) !*Workspace.Tab {
        if (target.tab_id) |tab_id| {
            return self.workspace.findTab(tab_id) orelse return error.TabNotFound;
        }
        return self.workspace.activeTab() orelse return error.NoActiveTab;
    }

    fn elapsedSeconds(start_ms: u64, now_ms: u64) u64 {
        if (now_ms <= start_ms) return 0;
        return (now_ms - start_ms) / 1000;
    }

    fn applyConfig(self: *App, next: Config.Config) !void {
        try next.validate();
        self.config = next;
        self.host.config = next;
    }

    fn applyLoadedConfig(self: *App, loaded: Config.Config) !void {
        const owned_font_family = try self.allocator.dupe(u8, loaded.font.family);
        errdefer self.allocator.free(owned_font_family);
        const owned_default_theme = try self.allocator.dupe(u8, loaded.default_theme);
        errdefer self.allocator.free(owned_default_theme);
        const owned_syntax_theme = try self.allocator.dupe(u8, loaded.syntax_theme);
        errdefer self.allocator.free(owned_syntax_theme);

        var next = loaded;
        next.font.family = owned_font_family;
        next.default_theme = owned_default_theme;
        next.syntax_theme = owned_syntax_theme;
        try next.validate();

        if (self.owned_font_family) |old| self.allocator.free(old);
        if (self.owned_default_theme) |old| self.allocator.free(old);
        if (self.owned_syntax_theme) |old| self.allocator.free(old);
        self.owned_font_family = owned_font_family;
        self.owned_default_theme = owned_default_theme;
        self.owned_syntax_theme = owned_syntax_theme;
        self.config = next;
        self.host.config = next;
    }

    fn setOwnedFontFamily(self: *App, family_raw: []const u8) !void {
        const family = std.mem.trim(u8, family_raw, " \t\r\n");
        if (family.len == 0) return error.InvalidFontFamily;
        const owned = try self.allocator.dupe(u8, family);
        errdefer self.allocator.free(owned);
        var next = self.config;
        next.font.family = owned;
        try next.validate();
        if (self.owned_font_family) |old| self.allocator.free(old);
        self.owned_font_family = owned;
        self.config = next;
        self.host.config = next;
    }

    fn setOwnedDefaultTheme(self: *App, theme_raw: []const u8) !void {
        const theme_name = std.mem.trim(u8, theme_raw, " \t\r\n");
        if (theme_name.len == 0) return error.InvalidThemeName;
        try Theme.validateName(theme_name);
        const owned = try self.allocator.dupe(u8, theme_name);
        errdefer self.allocator.free(owned);
        var next = self.config;
        next.default_theme = owned;
        try next.validate();
        if (self.owned_default_theme) |old| self.allocator.free(old);
        self.owned_default_theme = owned;
        self.config = next;
        self.host.config = next;
    }

    fn setOwnedSyntaxTheme(self: *App, theme_raw: []const u8) !void {
        const theme_name = std.mem.trim(u8, theme_raw, " \t\r\n");
        if (theme_name.len == 0) return error.InvalidSyntaxThemeName;
        try Theme.validateName(theme_name);
        const owned = try self.allocator.dupe(u8, theme_name);
        errdefer self.allocator.free(owned);
        var next = self.config;
        next.syntax_theme = owned;
        try next.validate();
        if (self.owned_syntax_theme) |old| self.allocator.free(old);
        self.owned_syntax_theme = owned;
        self.config = next;
        self.host.config = next;
    }

    fn previewThemeImport(self: *App, request: ThemeImport) !Theme.Theme {
        const theme_name = std.mem.trim(u8, request.name, " \t\r\n");
        const imported = try Theme.importTheme(self.allocator, request.format, theme_name, request.contents);
        const owned_name = try self.allocator.dupe(u8, imported.name);
        errdefer self.allocator.free(owned_name);
        if (self.owned_preview_theme_name) |old| self.allocator.free(old);
        self.owned_preview_theme_name = owned_name;
        self.preview_theme = imported;
        self.preview_theme.?.name = owned_name;
        return self.preview_theme.?;
    }

    fn prepareClipboardPaste(self: App, input: []const u8, policy: Paste.PastePolicy) !Paste.PreparedPaste {
        return Paste.preparePasteAlloc(self.allocator, input, .{
            .policy = policy,
            .bracketed_paste = self.config.clipboard.bracketed_paste,
            .repair_multiline_shell_commands = self.config.clipboard.repair_multiline_shell_commands,
            .strip_unsafe_controls = self.config.clipboard.strip_unsafe_controls,
        });
    }

    fn installThemeCopy(self: *App, theme: Theme.Theme) !Theme.Theme {
        try Theme.validateName(theme.name);
        const owned_name = try self.allocator.dupe(u8, theme.name);
        errdefer self.allocator.free(owned_name);
        const installed = Theme.Theme{
            .name = owned_name,
            .foreground = theme.foreground,
            .background = theme.background,
            .cursor = theme.cursor,
            .palette = theme.palette,
            .chrome = theme.chrome,
        };

        for (self.themes.items) |*entry| {
            if (std.mem.eql(u8, entry.theme.name, theme.name)) {
                self.allocator.free(entry.owned_name);
                entry.* = .{
                    .theme = installed,
                    .owned_name = owned_name,
                };
                return entry.theme;
            }
        }

        try self.themes.append(.{
            .theme = installed,
            .owned_name = owned_name,
        });
        return self.themes.items[self.themes.items.len - 1].theme;
    }

    fn setActiveThemeChromeColor(
        self: *App,
        change: ThemeChromeColorChange,
    ) !Theme.Theme {
        for (self.themes.items) |*entry| {
            if (!std.mem.eql(u8, entry.theme.name, self.config.default_theme)) continue;
            entry.theme.setChromeColor(change.role, change.color);
            return entry.theme;
        }
        var fallback = self.activeTheme();
        fallback.name = self.config.default_theme;
        _ = try self.installThemeCopy(fallback);
        for (self.themes.items) |*entry| {
            if (!std.mem.eql(u8, entry.theme.name, self.config.default_theme)) continue;
            entry.theme.setChromeColor(change.role, change.color);
            return entry.theme;
        }
        return error.ThemeNotInstalled;
    }

    fn themeListAlloc(self: App) ![]Theme.Theme {
        const themes = try self.allocator.alloc(Theme.Theme, self.themes.items.len);
        for (self.themes.items, 0..) |entry, idx| {
            themes[idx] = entry.theme;
        }
        return themes;
    }

    fn replaceThemeLibrary(self: *App, records: []const ThemeStorage.ThemeRecord) !void {
        if (records.len == 0) return error.EmptyThemeLibrary;
        var next = std.array_list.Managed(ThemeEntry).init(self.allocator);
        errdefer {
            for (next.items) |entry| self.allocator.free(entry.owned_name);
            next.deinit();
        }

        for (records) |record| {
            try Theme.validateName(record.theme.name);
            if (themeEntryListContains(next.items, record.theme.name)) return error.DuplicateThemeName;
            {
                const owned_name = try self.allocator.dupe(u8, record.theme.name);
                errdefer self.allocator.free(owned_name);
                try next.append(.{
                    .theme = .{
                        .name = owned_name,
                        .foreground = record.theme.foreground,
                        .background = record.theme.background,
                        .cursor = record.theme.cursor,
                        .palette = record.theme.palette,
                        .chrome = record.theme.chrome,
                    },
                    .owned_name = owned_name,
                });
            }
        }

        const selected_name = if (themeEntryListContains(next.items, self.config.default_theme))
            self.config.default_theme
        else
            next.items[0].theme.name;
        const owned_default_theme = try self.allocator.dupe(u8, selected_name);
        errdefer self.allocator.free(owned_default_theme);

        self.deinitThemeEntries();
        self.themes = next;
        if (self.owned_default_theme) |old| self.allocator.free(old);
        self.owned_default_theme = owned_default_theme;
        self.config.default_theme = owned_default_theme;
        self.host.config.default_theme = owned_default_theme;
    }

    fn deinitThemeEntries(self: *App) void {
        for (self.themes.items) |entry| self.allocator.free(entry.owned_name);
        self.themes.deinit();
    }

    fn themeEntryListContains(entries: []const ThemeEntry, name: []const u8) bool {
        for (entries) |entry| {
            if (std.mem.eql(u8, entry.theme.name, name)) return true;
        }
        return false;
    }
};

test "app defaults enforce no telemetry and no thick title bars" {
    const allocator = std.testing.allocator;
    var app = try App.init(allocator);
    defer app.deinit();
    try app.validate();
    try std.testing.expect(!app.telemetry_enabled);
    const tab = app.workspace.activeTab().?;
    try std.testing.expect(std.fs.path.isAbsolute(app.workspace.findPane(tab.active_pane_id).?.cwd));
}

test "app dispatches context menu split and grid commands" {
    const allocator = std.testing.allocator;
    var app = try App.init(allocator);
    defer app.deinit();

    _ = try app.dispatch(.split_left);
    _ = try app.dispatch(.split_right);
    _ = try app.dispatch(.split_up);
    _ = try app.dispatch(.split_down);
    try std.testing.expectEqual(@as(usize, 5), app.workspace.activeTab().?.panes.items.len);

    _ = try app.dispatch(.{ .preset = .two_by_two });
    try std.testing.expectEqual(@as(usize, 4), app.workspace.activeTab().?.panes.items.len);

    _ = try app.dispatch(.{ .preset = .one_by_one });
    try std.testing.expectEqual(@as(usize, 1), app.workspace.activeTab().?.panes.items.len);
}

test "app dispatches host mode shortcut font and broadcast commands" {
    const allocator = std.testing.allocator;
    var app = try App.init(allocator);
    defer app.deinit();

    _ = try app.dispatch(.{ .set_window_mode = .zen_fullscreen });
    try std.testing.expect(app.host.window.fullscreen);

    _ = try app.dispatch(.begin_shortcut_recording);
    const shortcut_result = try app.dispatch(.{ .capture_shortcut = .{ .key = .t, .ctrl = true, .alt = true } });
    try std.testing.expectEqual(Config.Shortcut.Key.t, shortcut_result.shortcut_changed.key);
    try std.testing.expect(app.config.dropdown.shortcut.ctrl);

    const font_result = try app.dispatch(.font_larger);
    try std.testing.expectEqual(@as(f32, 14.0), font_result.font_changed);

    const broadcast_result = try app.dispatch(.toggle_broadcast);
    try std.testing.expect(broadcast_result.broadcast_changed);
}

test "app exposes native host launch plan" {
    var app = try App.init(std.testing.allocator);
    defer app.deinit();

    const plan = app.launchPlan();
    try std.testing.expectEqual(Host.LaunchReadiness.ready, plan.readiness);
    try std.testing.expectEqual(Host.SurfaceIntent.hidden_dropdown, plan.initial_surface);
    try std.testing.expectEqual(Host.SurfaceIntent.visible_dropdown, plan.shortcut_activation_surface);
    try std.testing.expect(plan.needsShortcutRegistration());
    try std.testing.expect(plan.use_layer_shell);
}

test "app exposes native host presentation plan" {
    var app = try App.init(std.testing.allocator);
    defer app.deinit();

    const startup = app.presentationPlan(.startup);
    try std.testing.expectEqual(Host.PresentationProtocol.wayland_layer_shell, startup.protocol);
    try std.testing.expect(startup.containsAction(.register_global_shortcut));
    try std.testing.expect(startup.containsAction(.hide_surface));

    const shortcut = app.presentationPlan(.shortcut_activation);
    try std.testing.expectEqual(Host.SurfaceIntent.visible_dropdown, shortcut.target_surface);
    try std.testing.expect(shortcut.containsAction(.show_surface));
    try std.testing.expect(!shortcut.containsAction(.register_global_shortcut));
}

test "app dispatches native window lifecycle requests and receipts" {
    var app = try App.init(std.testing.allocator);
    defer app.deinit();

    const request = (try app.dispatch(.{ .request_window_lifecycle = .startup })).window_lifecycle_requested;
    try std.testing.expect(request.canCreate());
    try std.testing.expectEqual(Host.WindowLifecycleStatus.create_requested, app.host.window_lifecycle_status);

    const hidden = (try app.dispatch(.{ .window_lifecycle_receipt = .{
        .trigger = request.trigger,
        .protocol = request.protocol,
        .target_surface = request.target_surface,
        .target_rect = request.target_rect,
        .status = .hidden,
        .window_id = 1,
    } })).window_lifecycle_changed;
    try std.testing.expectEqual(Host.WindowLifecycleStatus.hidden, hidden);
    try std.testing.expectEqual(@as(?u64, 1), app.host.window_transport_id);
    try std.testing.expect(!app.host.window.visible);

    const show = (try app.dispatch(.{ .request_window_lifecycle = .shortcut_activation })).window_lifecycle_requested;
    try std.testing.expectEqual(Host.SurfaceIntent.visible_dropdown, show.target_surface);
    _ = try app.dispatch(.{ .window_lifecycle_receipt = .{
        .trigger = show.trigger,
        .protocol = show.protocol,
        .target_surface = show.target_surface,
        .target_rect = show.target_rect,
        .status = .shown,
        .window_id = 1,
    } });
    try std.testing.expect(app.host.window.visible);
}

test "app dispatches global shortcut registration requests and receipts" {
    var app = try App.init(std.testing.allocator);
    defer app.deinit();

    const request = (try app.dispatch(.register_global_shortcut)).shortcut_registration_requested;
    try std.testing.expect(request.canRegister());
    try std.testing.expectEqual(Host.ShortcutRegistrationTransport.kde_global_accel, request.transport);
    try std.testing.expectEqual(Host.ShortcutRegistrationStatus.pending, app.host.shortcut_registration_status);

    const changed = (try app.dispatch(.{ .shortcut_registration_receipt = .{
        .shortcut = request.shortcut,
        .transport = request.transport,
        .status = .registered,
    } })).shortcut_registration_changed;
    try std.testing.expectEqual(Host.ShortcutRegistrationStatus.registered, changed);
    try std.testing.expectEqual(Host.ShortcutRegistrationStatus.registered, app.host.shortcut_registration_status);

    _ = try app.dispatch(.begin_shortcut_recording);
    _ = try app.dispatch(.{ .capture_shortcut = .{ .key = .t, .ctrl = true, .alt = true } });
    try std.testing.expectEqual(Host.ShortcutRegistrationStatus.not_requested, app.host.shortcut_registration_status);
}

test "app dispatches notification delivery requests and receipts" {
    var app = try App.init(std.testing.allocator);
    defer app.deinit();

    _ = try app.dispatch(.{ .terminal_status = .{ .pane_id = 1, .event = .{ .waiting_for_input = 100 } } });
    const notification = app.host.last_notification.?;
    const request = (try app.dispatch(.deliver_last_notification)).notification_delivery_requested;
    try std.testing.expect(request.canDeliver());
    try std.testing.expectEqual(Host.NotificationTransport.freedesktop_dbus, request.transport);
    try std.testing.expectEqual(Host.NotificationDeliveryStatus.pending, app.host.notification_delivery_status);
    try std.testing.expectEqual(Host.NotificationDeliveryStatus.pending, app.notificationDeliveryRequest().status);

    const changed = (try app.dispatch(.{ .notification_delivery_receipt = .{
        .request = notification,
        .transport = request.transport,
        .status = .delivered,
    } })).notification_delivery_changed;
    try std.testing.expectEqual(Host.NotificationDeliveryStatus.delivered, changed);
    try std.testing.expectEqual(Host.NotificationDeliveryStatus.delivered, app.host.notification_delivery_status);
}

test "app dispatches status tooltip requests and receipts" {
    var app = try App.init(std.testing.allocator);
    defer app.deinit();

    _ = try app.dispatch(.split_down);
    _ = try app.dispatch(.{ .terminal_status = .{ .pane_id = 2, .event = .{ .waiting_for_input = 100 } } });

    const request = (try app.dispatch(.{ .show_status_tooltip = .{} })).status_tooltip_requested;
    try std.testing.expect(request.canRequest());
    try std.testing.expectEqual(@as(u64, 1), request.tab_id);
    try std.testing.expectEqual(Host.StatusTooltipStatus.show_requested, app.host.status_tooltip_status);
    try std.testing.expectEqual(@as(usize, 1), request.summary.attention_total);

    var tooltip_buf: [256]u8 = undefined;
    var tooltip_writer = std.Io.Writer.fixed(&tooltip_buf);
    try request.formatTooltip(&tooltip_writer);
    try std.testing.expectEqualStrings(
        \\2 terminal panes, 1 needs attention
        \\Pending input: 1 (attention)
        \\Idle: 1
        \\
    , tooltip_writer.buffered());

    const shown = (try app.dispatch(.{ .status_tooltip_receipt = .{
        .tab_id = request.tab_id,
        .status = .shown,
    } })).status_tooltip_changed;
    try std.testing.expectEqual(Host.StatusTooltipStatus.shown, shown);
    try std.testing.expectEqual(Host.StatusTooltipStatus.hidden, (try app.dispatch(.hide_status_tooltip)).status_tooltip_changed);
}

test "app dispatches durable tab rename commands" {
    var app = try App.init(std.testing.allocator);
    defer app.deinit();

    const tab_id = (try app.dispatch(.{ .rename_tab = .{
        .tab_id = 1,
        .title = "  Build logs  ",
    } })).tab_renamed;
    try std.testing.expectEqual(@as(u64, 1), tab_id);
    try std.testing.expectEqualStrings("Build logs", app.workspace.tabs.items[0].title);
    try std.testing.expect(app.workspace.tabs.items[0].title_overridden);
}

test "app dispatches durable tab accent and shade commands" {
    var app = try App.init(std.testing.allocator);
    defer app.deinit();

    const set_id = (try app.dispatch(.{ .set_tab_accent = .{
        .tab_id = 1,
        .preset = .cyan,
    } })).tab_accent_changed;
    try std.testing.expectEqual(@as(u64, 1), set_id);
    try std.testing.expectEqual(Workspace.TabColorPreset.cyan, app.workspace.tabs.items[0].accent.?.preset);
    try std.testing.expect(app.recovery.dirty);

    const adjusted_id = (try app.dispatch(.{ .adjust_tab_accent = .{
        .tab_id = 1,
        .delta = -1,
    } })).tab_accent_changed;
    try std.testing.expectEqual(@as(u64, 1), adjusted_id);
    try std.testing.expectEqual(@as(i8, -1), app.workspace.tabs.items[0].accent.?.shade);

    _ = try app.dispatch(.{ .set_tab_accent = .{ .tab_id = 1, .preset = null } });
    try std.testing.expect(app.workspace.tabs.items[0].accent == null);
}

test "app dispatches exact tab close commands" {
    var app = try App.init(std.testing.allocator);
    defer app.deinit();

    const second_tab_id = (try app.dispatch(.new_tab)).tab_created;
    const closed = (try app.dispatch(.{ .close_tab = 1 })).tab_closed;
    try std.testing.expectEqual(@as(u64, 1), closed.tab_id);
    try std.testing.expectEqual(@as(usize, 1), closed.pane_count);
    try std.testing.expectEqual(second_tab_id, closed.active_tab_id);
    try std.testing.expectEqual(@as(usize, 1), app.workspace.tabs.items.len);
    try std.testing.expectError(error.CannotCloseLastTab, app.dispatch(.{ .close_tab = second_tab_id }));
}

test "app dispatches numbered default tab titles" {
    var app = try App.init(std.testing.allocator);
    defer app.deinit();

    try std.testing.expectEqualStrings("Tab 1", app.workspace.tabs.items[0].title);
    _ = try app.dispatch(.new_tab);
    _ = try app.dispatch(.new_tab);
    try std.testing.expectEqualStrings("Tab 2", app.workspace.tabs.items[1].title);
    try std.testing.expectEqualStrings("Tab 3", app.workspace.tabs.items[2].title);
}

test "app dispatches reopen for the last closed tab" {
    var app = try App.init(std.testing.allocator);
    defer app.deinit();

    _ = try app.dispatch(.{ .rename_tab = .{ .tab_id = 1, .title = "Build logs" } });
    _ = try app.dispatch(.new_tab);
    _ = try app.dispatch(.{ .close_tab = 1 });
    const reopened = (try app.dispatch(.reopen_tab)).tab_reopened;

    try std.testing.expectEqual(@as(u64, 1), reopened);
    try std.testing.expectEqualStrings("Build logs", app.workspace.activeTab().?.title);
}

test "app dispatches exact pane close commands" {
    var app = try App.init(std.testing.allocator);
    defer app.deinit();

    const pane_id = (try app.dispatch(.split_down)).pane_created;
    const closed = (try app.dispatch(.{ .close_pane = 1 })).pane_closed;
    try std.testing.expectEqual(@as(Terminal.PaneId, 1), closed.pane_id);
    try std.testing.expect(!closed.tab_closed);
    try std.testing.expectEqual(pane_id, closed.active_pane_id);
    try std.testing.expect(app.workspace.findPane(1) == null);
    try std.testing.expect(app.workspace.findPane(pane_id) != null);
    try std.testing.expectError(
        error.CannotCloseLastTerminal,
        app.dispatch(.{ .close_pane = pane_id }),
    );
}

test "app status tooltip requests honor settings and tab targeting" {
    var app = try App.init(std.testing.allocator);
    defer app.deinit();

    const second_tab = try app.workspace.addTab("agent", "/tmp/agent");
    _ = try app.dispatch(.{ .set_tooltip_details = false });

    const disabled = (try app.dispatch(.{ .show_status_tooltip = .{ .tab_id = second_tab } })).status_tooltip_requested;
    try std.testing.expectEqual(second_tab, disabled.tab_id);
    try std.testing.expect(!disabled.canRequest());
    try std.testing.expectEqual(Host.StatusTooltipStatus.disabled, disabled.status);
    try std.testing.expectError(error.TabNotFound, app.dispatch(.{ .show_status_tooltip = .{ .tab_id = 99 } }));
}

test "app dispatches profile preset menu requests receipts and selections" {
    var app = try App.init(std.testing.allocator);
    defer app.deinit();

    _ = try app.dispatch(.{ .set_font_family = "Commit Mono" });
    _ = try app.dispatch(.{ .set_default_theme = "workspace-dark" });
    _ = try app.dispatch(.{ .set_pane_profile_preset = .{
        .pane_id = 1,
        .preset = .global_default,
    } });

    const request = (try app.dispatch(.{ .show_profile_preset_menu = .{ .pane_id = 1 } })).profile_preset_menu_requested;
    try std.testing.expect(request.canShow());
    try std.testing.expectEqual(@as(Terminal.PaneId, 1), request.pane_id);
    try std.testing.expectEqual(@as(usize, 5), request.itemSlice().len);
    try std.testing.expectEqual(Terminal.ProfilePreset.global_default, request.itemSlice()[0].preset);
    try std.testing.expect(request.itemSlice()[0].current);
    try std.testing.expectEqual(Host.ProfilePresetMenuStatus.show_requested, app.host.profile_preset_menu_status);

    const shown = (try app.dispatch(.{ .profile_preset_menu_receipt = .{
        .pane_id = request.pane_id,
        .status = .shown,
    } })).profile_preset_menu_changed;
    try std.testing.expectEqual(Host.ProfilePresetMenuStatus.shown, shown);

    const selected = (try app.dispatch(.{ .select_profile_preset_from_menu = .{
        .pane_id = request.pane_id,
        .preset = .readable,
    } })).profile_changed;
    try std.testing.expectEqual(@as(Terminal.PaneId, 1), selected.pane_id);
    try std.testing.expectEqual(@as(f32, 14.0), selected.profile.font_size_pt);
    try std.testing.expectEqualStrings("Commit Mono", selected.profile.font_family);
    try std.testing.expectEqualStrings("workspace-dark", selected.profile.theme_name);
    try std.testing.expectEqual(Host.ProfilePresetMenuStatus.selected, app.host.profile_preset_menu_status);
    try std.testing.expectEqual(Terminal.ProfilePreset.readable, app.host.profile_preset_menu_selected.?);
    try std.testing.expect(app.host.profile_preset_menu_pane_id == null);
}

test "app rejects stale profile preset menu selection" {
    var app = try App.init(std.testing.allocator);
    defer app.deinit();

    try std.testing.expectError(error.ProfilePresetMenuMismatch, app.dispatch(.{ .select_profile_preset_from_menu = .{
        .pane_id = 1,
        .preset = .compact,
    } }));
    try std.testing.expectEqual(@as(f32, 13.0), app.workspace.findPane(1).?.profile.font_size_pt);
    try std.testing.expectError(error.PaneNotFound, app.dispatch(.{ .show_profile_preset_menu = .{ .pane_id = 99 } }));

    const request = (try app.dispatch(.{ .show_profile_preset_menu = .{ .pane_id = 1 } })).profile_preset_menu_requested;
    try std.testing.expectError(error.InvalidProfilePresetMenuReceipt, app.dispatch(.{ .profile_preset_menu_receipt = .{
        .pane_id = request.pane_id,
        .status = .selected,
    } }));

    const hidden = (try app.dispatch(.hide_profile_preset_menu)).profile_preset_menu_changed;
    try std.testing.expectEqual(Host.ProfilePresetMenuStatus.hidden, hidden);
    try std.testing.expectError(error.ProfilePresetMenuMismatch, app.dispatch(.{ .select_profile_preset_from_menu = .{
        .pane_id = 1,
        .preset = .compact,
    } }));
}

test "app dispatches typed gui settings commands" {
    const allocator = std.testing.allocator;
    var app = try App.init(allocator);
    defer app.deinit();

    try std.testing.expectEqual(App.ConfigSetting.tab_position, (try app.dispatch(.{ .set_tab_position = .bottom })).config_changed);
    try std.testing.expectEqual(Config.TabPosition.bottom, app.config.tabs.position);

    try std.testing.expectEqual(App.ConfigSetting.dropdown_dimensions, (try app.dispatch(.{ .set_dropdown_dimensions = .{ .width_percent = 88, .height_percent = 42 } })).config_changed);
    _ = try app.dispatch(.{ .set_dropdown_animation_ms = 140 });
    _ = try app.dispatch(.{ .set_hide_on_focus_loss = false });
    _ = try app.dispatch(.{ .set_focus_follows_pointer = true });
    try std.testing.expectEqual(App.ConfigSetting.show_pane_info, (try app.dispatch(.{ .set_show_pane_info = false })).config_changed);
    try std.testing.expectEqual(@as(u8, 88), app.config.dropdown.width_percent);
    try std.testing.expectEqual(@as(u8, 42), app.config.dropdown.height_percent);
    try std.testing.expectEqual(@as(u16, 140), app.config.dropdown.animation_ms);
    try std.testing.expect(!app.config.dropdown.hide_on_focus_loss);
    try std.testing.expect(app.config.tabs.focus_follows_pointer);
    try std.testing.expect(!app.config.tabs.show_pane_info);

    _ = try app.dispatch(.{ .set_scrollback_lines = 12_345 });
    try std.testing.expectEqual(@as(u32, 12_345), app.config.terminal.scrollback_lines);
    try std.testing.expectEqual(
        @as(u32, 12_345),
        app.config.terminal.launch_profile.scrollback_lines,
    );

    try std.testing.expectEqual(
        App.ConfigSetting.scroll_behavior,
        (try app.dispatch(.{ .set_scroll_behavior = .{
            .lines = 6,
            .smooth = false,
        } })).config_changed,
    );
    try std.testing.expectEqual(@as(u8, 6), app.config.terminal.scroll_lines);
    try std.testing.expect(!app.host.config.terminal.smooth_scroll);

    try std.testing.expectEqual(App.ConfigSetting.status_indicator, (try app.dispatch(.{ .set_status_indicator = .background })).config_changed);
    try std.testing.expectEqual(Config.StatusIndicator.background, app.config.status.indicator);

    _ = try app.dispatch(.{ .set_show_status_counts = false });
    _ = try app.dispatch(.{ .set_tooltip_details = false });
    _ = try app.dispatch(.{ .set_desktop_notifications = false });
    try std.testing.expect(!app.config.tabs.show_status_counts);
    try std.testing.expect(!app.config.tabs.tooltip_details);
    try std.testing.expect(!app.config.status.desktop_notifications);

    _ = try app.dispatch(.{ .set_long_running_minutes = 45 });
    _ = try app.dispatch(.{ .set_font_size = 13.5 });
    try std.testing.expectEqual(@as(u16, 45), app.host.config.status.long_running_minutes);
    try std.testing.expectEqual(@as(f32, 13.5), app.host.config.font.size_pt);

    _ = try app.dispatch(.{ .set_font_family = " JetBrains Mono " });
    _ = try app.dispatch(.{ .set_default_theme = " noctty-high-contrast " });
    try std.testing.expectEqualStrings("JetBrains Mono", app.config.font.family);
    try std.testing.expectEqualStrings("noctty-high-contrast", app.host.config.default_theme);

    try std.testing.expectEqual(
        App.ConfigSetting.background,
        (try app.dispatch(.{ .set_background = .{
            .translucency = false,
            .opacity_percent = 68,
        } })).config_changed,
    );
    try std.testing.expect(!app.config.background.translucency);
    try std.testing.expectEqual(@as(u8, 68), app.host.config.background.opacity_percent);

    var metrics = app.config.panels;
    metrics.padding_px = 8;
    metrics.spacing_px = 3;
    metrics.border_px = 2;
    _ = try app.dispatch(.{ .set_panel_metrics = metrics });
    try std.testing.expectEqual(@as(u16, 8), app.config.panels.padding_px);
    try std.testing.expectEqual(@as(u16, 3), app.host.config.panels.spacing_px);
}

test "app dispatches named launch profile library commands atomically" {
    var app = try App.init(std.testing.allocator);
    defer app.deinit();

    var build = LaunchProfile.Profile{ .kind = .command };
    try build.command.set("printf build");
    try std.testing.expectEqual(
        App.ConfigSetting.launch_profile_library,
        (try app.dispatch(.{ .save_named_launch_profile = .{
            .name = "Local build",
            .profile = build,
        } })).config_changed,
    );
    try std.testing.expectEqual(@as(u8, 1), app.config.terminal.launch_profiles.count);
    try std.testing.expectEqual(@as(u8, 0), app.config.terminal.launch_profiles.selected_index);
    try std.testing.expect(app.config.terminal.launch_profile.eql(&build));

    var shell = LaunchProfile.Profile{};
    try shell.shell.set("/bin/sh");
    _ = try app.dispatch(.{ .set_launch_profile = shell });
    try std.testing.expectEqual(LaunchProfile.no_selection, app.config.terminal.launch_profiles.selected_index);
    _ = try app.dispatch(.{ .select_named_launch_profile = 0 });
    try std.testing.expect(app.config.terminal.launch_profile.eql(&build));

    try std.testing.expectError(
        error.InvalidLaunchProfileName,
        app.dispatch(.{ .save_named_launch_profile = .{ .name = " bad ", .profile = shell } }),
    );
    try std.testing.expectEqual(@as(u8, 1), app.config.terminal.launch_profiles.count);
    _ = try app.dispatch(.{ .remove_named_launch_profile = 0 });
    try std.testing.expectEqual(@as(u8, 0), app.config.terminal.launch_profiles.count);
    try std.testing.expect(app.config.terminal.launch_profile.eql(&build));
}

test "app models pane zoom and workspace quick note" {
    const allocator = std.testing.allocator;
    var app = try App.init(allocator);
    defer app.deinit();

    _ = try app.dispatch(.split_down);
    try std.testing.expectEqual(@as(Terminal.PaneId, 2), (try app.dispatch(.{ .toggle_pane_zoom = 2 })).pane_zoom_changed.?);
    try std.testing.expect((try app.dispatch(.{ .toggle_pane_zoom = 2 })).pane_zoom_changed == null);
    try std.testing.expectEqual(@as(usize, 10), (try app.dispatch(.{ .set_quick_note = "ship notes" })).quick_note_changed);
    try std.testing.expectEqualStrings("ship notes", (try app.dispatch(.read_quick_note)).quick_note_read);
}

test "app rejects invalid gui settings without mutating current config" {
    const allocator = std.testing.allocator;
    var app = try App.init(allocator);
    defer app.deinit();

    try std.testing.expectError(error.InvalidFontSize, app.dispatch(.{ .set_font_size = 99 }));
    try std.testing.expectEqual(@as(f32, 13.0), app.config.font.size_pt);

    try std.testing.expectError(error.InvalidFontFamily, app.dispatch(.{ .set_font_family = "   " }));
    try std.testing.expectEqualStrings("Monospace", app.config.font.family);

    var metrics = app.config.panels;
    metrics.main_titlebar_px = 12;
    try std.testing.expectError(error.ThickTitlebarForbidden, app.dispatch(.{ .set_panel_metrics = metrics }));
    try std.testing.expectEqual(@as(u16, 0), app.config.panels.main_titlebar_px);
}

test "app saves and loads gui configuration files" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var app = try App.init(allocator);
    defer app.deinit();

    const default_path = try app.defaultConfigPathAlloc("/home/alice");
    defer allocator.free(default_path);
    try std.testing.expectEqualStrings("/home/alice/.config/noctty/settings.nocttycfg", default_path);

    _ = try app.dispatch(.{ .set_window_mode = .windowed });
    _ = try app.dispatch(.begin_shortcut_recording);
    _ = try app.dispatch(.{ .capture_shortcut = .{ .key = .t, .ctrl = true, .alt = true } });
    _ = try app.dispatch(.{ .set_tab_position = .bottom });
    _ = try app.dispatch(.{ .set_status_indicator = .background });
    _ = try app.dispatch(.{ .set_tooltip_details = false });
    _ = try app.dispatch(.{ .set_long_running_minutes = 45 });
    _ = try app.dispatch(.{ .set_font_family = "Commit Mono" });
    _ = try app.dispatch(.{ .set_default_theme = "workspace-night" });

    const saved = try app.saveConfigFile(io, tmp.dir, "settings/noctty.nocttycfg", .settings);
    defer saved.deinit(allocator);
    try std.testing.expect(saved.bytes > 16);

    _ = try app.dispatch(.{ .set_window_mode = .dropdown });
    _ = try app.dispatch(.begin_shortcut_recording);
    _ = try app.dispatch(.{ .capture_shortcut = .{ .key = .f10 } });
    _ = try app.dispatch(.{ .set_tab_position = .top });
    _ = try app.dispatch(.{ .set_status_indicator = .border });
    _ = try app.dispatch(.{ .set_tooltip_details = true });
    _ = try app.dispatch(.{ .set_long_running_minutes = 20 });
    _ = try app.dispatch(.{ .set_font_family = "JetBrains Mono" });
    _ = try app.dispatch(.{ .set_default_theme = "noctty-dark" });

    const loaded = try app.loadConfigFile(io, tmp.dir, "settings/noctty.nocttycfg", .settings);
    defer loaded.deinit(allocator);
    try std.testing.expectEqual(Config.WindowMode.windowed, app.config.default_mode);
    try std.testing.expectEqual(Config.Shortcut.Key.t, app.config.dropdown.shortcut.key);
    try std.testing.expect(app.config.dropdown.shortcut.ctrl);
    try std.testing.expect(app.config.dropdown.shortcut.alt);
    try std.testing.expectEqual(Config.TabPosition.bottom, app.config.tabs.position);
    try std.testing.expectEqual(Config.StatusIndicator.background, app.config.status.indicator);
    try std.testing.expect(!app.config.tabs.tooltip_details);
    try std.testing.expectEqual(@as(u16, 45), app.config.status.long_running_minutes);
    try std.testing.expectEqualStrings("Commit Mono", app.config.font.family);
    try std.testing.expectEqualStrings("workspace-night", app.config.default_theme);
    try std.testing.expectEqualStrings("Commit Mono", app.host.config.font.family);
    try std.testing.expectEqualStrings("workspace-night", app.host.config.default_theme);
}

test "app dispatches per-pane profile presets from context commands" {
    const allocator = std.testing.allocator;
    var app = try App.init(allocator);
    defer app.deinit();

    _ = try app.dispatch(.split_down);
    _ = try app.dispatch(.{ .set_font_family = "Commit Mono" });
    _ = try app.dispatch(.{ .set_default_theme = "workspace-dark" });

    const readable = try app.dispatch(.{ .set_pane_profile_preset = .{
        .pane_id = 2,
        .preset = .readable,
    } });
    try std.testing.expectEqual(@as(Terminal.PaneId, 2), readable.profile_changed.pane_id);
    try std.testing.expectEqual(@as(f32, 14.0), readable.profile_changed.profile.font_size_pt);
    try std.testing.expectEqualStrings("Commit Mono", app.workspace.findPane(2).?.profile.font_family);
    try std.testing.expectEqualStrings("workspace-dark", app.workspace.findPane(2).?.profile.theme_name);

    const high_contrast = try app.dispatch(.{ .set_pane_profile_preset = .{
        .pane_id = 1,
        .preset = .high_contrast,
    } });
    try std.testing.expectEqualStrings("noctty-high-contrast", high_contrast.profile_changed.profile.theme_name);
    try std.testing.expectEqualStrings("workspace-dark", app.workspace.findPane(2).?.profile.theme_name);

    const resized = try app.dispatch(.{ .set_pane_font_size = .{
        .pane_id = 2,
        .size_pt = 15.0,
    } });
    try std.testing.expectEqual(@as(f32, 15.0), resized.profile_changed.profile.font_size_pt);
    try std.testing.expectEqual(@as(f32, 12.0), app.workspace.findPane(1).?.profile.font_size_pt);
    try std.testing.expect(app.recovery.dirty);
}

test "app rejects pane profile presets for missing panes" {
    const allocator = std.testing.allocator;
    var app = try App.init(allocator);
    defer app.deinit();

    try std.testing.expectError(error.PaneNotFound, app.dispatch(.{ .set_pane_profile_preset = .{
        .pane_id = 99,
        .preset = .compact,
    } }));
}

test "app previews installs and selects imported themes" {
    const allocator = std.testing.allocator;
    var app = try App.init(allocator);
    defer app.deinit();

    const preview = try app.dispatch(.{ .preview_theme_import = .{
        .format = .ghostty,
        .name = " Workspace Night ",
        .contents =
        \\background = #000011
        \\foreground = #eeeeee
        \\cursor-color = #ff00aa
        ,
    } });
    try std.testing.expectEqualStrings("Workspace Night", preview.theme_previewed.name);
    try std.testing.expectEqual(Theme.Color.fromHex(0x000011), preview.theme_previewed.background);
    try std.testing.expectEqual(@as(usize, 1), app.themes.items.len);

    const installed = try app.dispatch(.{ .install_theme_import = .{
        .format = .ghostty,
        .name = "Workspace Night",
        .contents =
        \\background = #000011
        \\foreground = #eeeeee
        \\cursor-color = #ff00aa
        ,
    } });
    try std.testing.expectEqualStrings("Workspace Night", installed.theme_installed.name);
    try std.testing.expectEqual(@as(usize, 2), app.themes.items.len);

    const selected = try app.dispatch(.{ .select_theme = "Workspace Night" });
    try std.testing.expectEqualStrings("Workspace Night", selected.theme_selected.name);
    try std.testing.expectEqualStrings("Workspace Night", app.config.default_theme);
    try std.testing.expectEqualStrings("Workspace Night", app.host.config.default_theme);
}

test "app replaces installed themes by name and rejects missing selection" {
    const allocator = std.testing.allocator;
    var app = try App.init(allocator);
    defer app.deinit();

    _ = try app.dispatch(.{ .install_theme_import = .{
        .format = .ghostty,
        .name = "replace-me",
        .contents = "background = #111111",
    } });
    _ = try app.dispatch(.{ .install_theme_import = .{
        .format = .ghostty,
        .name = "replace-me",
        .contents = "background = #222222",
    } });
    try std.testing.expectEqual(@as(usize, 2), app.themes.items.len);
    try std.testing.expectEqual(Theme.Color.fromHex(0x222222), app.findTheme("replace-me").?.background);

    try std.testing.expectError(error.ThemeNotInstalled, app.dispatch(.{ .select_theme = "missing-theme" }));
}

test "app saves and loads durable theme library files" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var source = try App.init(allocator);
    defer source.deinit();

    const default_path = try source.defaultThemeLibraryPathAlloc("/home/alice");
    defer allocator.free(default_path);
    try std.testing.expectEqualStrings("/home/alice/.config/noctty/themes.nocttythemes", default_path);

    _ = try source.dispatch(.{ .install_theme_import = .{
        .format = .ghostty,
        .name = "Workspace Night",
        .contents =
        \\background = #000011
        \\foreground = #eeeeee
        \\cursor-color = #ff00aa
        ,
    } });
    const saved = try source.saveThemeLibraryFile(io, tmp.dir, "themes/library.nocttythemes", .library);
    defer saved.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 2), saved.theme_count);

    var loaded_app = try App.init(allocator);
    defer loaded_app.deinit();
    const loaded = try loaded_app.loadThemeLibraryFile(io, tmp.dir, "themes/library.nocttythemes", .library);
    defer loaded.deinit(allocator);
    try std.testing.expectEqual(ThemeStorage.ThemeFileRole.library, loaded.role);
    try std.testing.expectEqual(@as(usize, 2), loaded.theme_count);
    try std.testing.expectEqual(@as(usize, 2), loaded_app.themes.items.len);
    try std.testing.expectEqual(Theme.Color.fromHex(0x000011), loaded_app.findTheme("Workspace Night").?.background);
    try std.testing.expectEqualStrings("noctty-dark", loaded_app.config.default_theme);
}

test "app falls back to first loaded theme when current default is absent" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const workspace = try Theme.importTheme(allocator, .xresources, "Workspace Night",
        \\*.background: #010203
        \\*.foreground: #aabbcc
    );
    const themes = [_]Theme.Theme{workspace};
    const saved = try ThemeStorage.saveThemeLibraryFile(allocator, io, tmp.dir, "themes/single.nocttythemes", &themes, .library);
    defer saved.deinit(allocator);

    var app = try App.init(allocator);
    defer app.deinit();
    _ = try app.dispatch(.{ .set_default_theme = "theme-not-in-library" });

    const loaded = try app.loadThemeLibraryFile(io, tmp.dir, "themes/single.nocttythemes", .library);
    defer loaded.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 1), app.themes.items.len);
    try std.testing.expectEqualStrings("Workspace Night", app.config.default_theme);
    try std.testing.expectEqualStrings("Workspace Night", app.host.config.default_theme);
    try std.testing.expectEqual(Theme.Color.fromHex(0x010203), app.findTheme("Workspace Night").?.background);
}

test "app prepares clipboard paste through configured policy" {
    const allocator = std.testing.allocator;
    var app = try App.init(allocator);
    defer app.deinit();

    const result = try app.dispatch(.{ .prepare_paste = .{
        .input =
        \\git status
        \\git diff --check
        ,
        .policy = .shell_one_line,
    } });
    defer result.paste_prepared.deinit(allocator);

    try std.testing.expectEqual(Paste.PastePolicy.shell_one_line, result.paste_prepared.applied_policy);
    try std.testing.expectEqualStrings("\x1b[200~git status; git diff --check\x1b[201~", result.paste_prepared.bytes);
}

test "app paste preparation follows clipboard config toggles" {
    const allocator = std.testing.allocator;
    var app = try App.init(allocator);
    defer app.deinit();
    app.config.clipboard.bracketed_paste = false;
    app.config.clipboard.repair_multiline_shell_commands = false;

    const result = try app.dispatch(.{ .prepare_paste = .{
        .input =
        \\git status
        \\git diff --check
        ,
        .policy = .shell_one_line,
    } });
    defer result.paste_prepared.deinit(allocator);

    try std.testing.expect(!result.paste_prepared.bracketed);
    try std.testing.expectEqual(Paste.PastePolicy.literal, result.paste_prepared.applied_policy);
    try std.testing.expectEqualStrings("git status\ngit diff --check", result.paste_prepared.bytes);
}

test "app dispatches clipboard transfer requests and receipts" {
    var app = try App.init(std.testing.allocator);
    defer app.deinit();

    const read = (try app.dispatch(.{ .read_clipboard = .clipboard })).clipboard_transfer_requested;
    try std.testing.expect(read.canTransfer());
    try std.testing.expectEqual(Host.ClipboardOperation.read, read.operation);
    try std.testing.expectEqual(Host.ClipboardTransport.wayland_data_control, read.transport);

    const read_status = (try app.dispatch(.{ .clipboard_transfer_receipt = .{
        .operation = read.operation,
        .selection = read.selection,
        .transport = read.transport,
        .status = .completed,
        .bytes = 24,
    } })).clipboard_transfer_changed;
    try std.testing.expectEqual(Host.ClipboardTransferStatus.completed, read_status);

    const write = (try app.dispatch(.{ .write_clipboard = .{
        .selection = .primary,
        .bytes = "copied text",
    } })).clipboard_transfer_requested;
    try std.testing.expectEqual(Host.ClipboardOperation.write, write.operation);
    try std.testing.expectEqual(Host.ClipboardSelection.primary, write.selection);
    try std.testing.expectEqual(@as(usize, 11), write.bytes);

    const write_status = (try app.dispatch(.{ .clipboard_transfer_receipt = .{
        .operation = write.operation,
        .selection = write.selection,
        .transport = write.transport,
        .status = .completed,
        .bytes = write.bytes,
    } })).clipboard_transfer_changed;
    try std.testing.expectEqual(Host.ClipboardTransferStatus.completed, write_status);
}

test "app dispatches pane paste delivery requests and receipts" {
    var app = try App.init(std.testing.allocator);
    defer app.deinit();

    const request = (try app.dispatch(.{ .deliver_paste_to_pane = .{
        .pane_id = 1,
        .input =
        \\git status
        \\git diff --check
        ,
        .policy = .shell_one_line,
    } })).paste_delivery_requested;
    try std.testing.expect(request.canDeliver());
    try std.testing.expectEqual(@as(Terminal.PaneId, 1), request.pane_id);
    try std.testing.expectEqual(Paste.PastePolicy.shell_one_line, request.policy);
    try std.testing.expect(request.bracketed);

    const changed = (try app.dispatch(.{ .paste_delivery_receipt = .{
        .pane_id = request.pane_id,
        .bytes = request.bytes,
        .status = .delivered,
    } })).paste_delivery_changed;
    try std.testing.expectEqual(Host.PasteDeliveryStatus.delivered, changed);
    try std.testing.expectError(error.PaneNotFound, app.dispatch(.{ .deliver_paste_to_pane = .{
        .pane_id = 99,
        .input = "echo nope",
    } }));
}

test "app captures and restores project workspace snapshots" {
    const allocator = std.testing.allocator;
    var app = try App.init(allocator);
    defer app.deinit();

    _ = try app.dispatch(.split_down);
    try app.workspace.findPane(2).?.addTag("worker");
    try app.workspace.findPane(2).?.setWorktreeRoot("/repo/wt");
    _ = try app.dispatch(.{ .set_pane_profile_preset = .{
        .pane_id = 2,
        .preset = .mono_no_ligatures,
    } });
    _ = try app.dispatch(.{ .set_project_panels = .{
        .git_status = &.{
            .{ .path = "src/app/App.zig", .state = .modified },
            .{ .path = "README.md", .state = .conflicted },
        },
        .git_graph = &.{
            .{ .commit = "abc1234", .summary = "app panels", .branch = "main" },
        },
        .files = &.{
            .{ .path = "src/app/App.zig", .kind = .file, .dirty = true },
        },
    } });

    var captured = (try app.dispatch(.capture_workspace)).workspace_captured;
    defer captured.deinit(allocator);

    _ = try app.dispatch(.{ .preset = .three_by_three });
    _ = try app.dispatch(.{ .set_project_panels = .{} });
    try std.testing.expectEqual(@as(usize, 9), app.workspace.activeTab().?.panes.items.len);

    _ = try app.dispatch(.{ .restore_workspace = captured });
    try std.testing.expectEqual(@as(usize, 2), app.workspace.activeTab().?.panes.items.len);
    try std.testing.expectEqualStrings("worker", app.workspace.findPane(2).?.tags.items[0]);
    try std.testing.expectEqualStrings("/repo/wt", app.workspace.findPane(2).?.worktree_root.?);
    try std.testing.expect(!app.workspace.findPane(2).?.profile.ligatures);
    try std.testing.expectEqual(@as(usize, 2), app.workspace.project_panels.git_status.len);
    try std.testing.expectEqual(Workspace.GitFileState.conflicted, app.workspace.project_panels.git_status[1].state);
}

test "app exports and imports workspace bytes" {
    const allocator = std.testing.allocator;
    var app = try App.init(allocator);
    defer app.deinit();

    _ = try app.dispatch(.split_down);
    try app.workspace.findPane(2).?.addTag("agent");
    try app.workspace.findPane(2).?.setWorktreeRoot("/repo/agent");
    app.workspace.findPane(2).?.status = .running;
    _ = try app.dispatch(.{ .set_project_panels = .{
        .git_status = &.{
            .{ .path = "src/workspace/Workspace.zig", .state = .added },
        },
        .git_graph = &.{
            .{ .commit = "feedbee", .summary = "export panels" },
        },
        .files = &.{
            .{ .path = "src/workspace/Workspace.zig", .kind = .file, .dirty = true },
        },
    } });

    const exported = (try app.dispatch(.export_workspace)).workspace_exported;
    defer exported.deinit(allocator);
    try std.testing.expect(exported.bytes.len > 16);

    _ = try app.dispatch(.{ .preset = .three_by_three });
    _ = try app.dispatch(.{ .import_workspace = exported.bytes });

    try std.testing.expectEqual(@as(usize, 2), app.workspace.activeTab().?.panes.items.len);
    try std.testing.expectEqual(Terminal.TerminalStatus.running, app.workspace.findPane(2).?.status);
    try std.testing.expectEqualStrings("agent", app.workspace.findPane(2).?.tags.items[0]);
    try std.testing.expectEqualStrings("/repo/agent", app.workspace.findPane(2).?.worktree_root.?);
    try std.testing.expectEqual(Workspace.GitFileState.added, app.workspace.project_panels.git_status[0].state);
    try std.testing.expectEqualStrings("export panels", app.workspace.project_panels.git_graph[0].summary);
}

test "app dispatches project panel updates" {
    const allocator = std.testing.allocator;
    var app = try App.init(allocator);
    defer app.deinit();

    const result = try app.dispatch(.{ .set_project_panels = .{
        .git_status = &.{
            .{ .path = "src/main.zig", .state = .modified },
            .{ .path = "docs/ARCHITECTURE.md", .state = .untracked },
        },
        .git_graph = &.{
            .{ .commit = "abc1234", .summary = "panel dispatcher", .branch = "main" },
        },
        .files = &.{
            .{ .path = "src", .kind = .directory },
            .{ .path = "src/main.zig", .kind = .file, .dirty = true },
        },
    } });

    try std.testing.expectEqual(@as(usize, 2), result.project_panels_changed.changed_count);
    try std.testing.expectEqual(@as(usize, 1), result.project_panels_changed.directory_count);
    try std.testing.expectEqualStrings("src/main.zig", app.workspace.project_panels.git_status[0].path);
    try std.testing.expectError(error.InvalidProjectPanelEntry, app.dispatch(.{ .set_project_panels = .{
        .git_graph = &.{.{ .commit = "", .summary = "missing commit" }},
    } }));
    try std.testing.expectEqual(@as(usize, 2), app.workspace.project_panels.git_status.len);
}

test "app presents project panels from current workspace summary" {
    const allocator = std.testing.allocator;
    var app = try App.init(allocator);
    defer app.deinit();

    _ = try app.dispatch(.{ .set_project_panels = .{
        .git_status = &.{
            .{ .path = "src/main.zig", .state = .modified },
            .{ .path = "docs/ARCHITECTURE.md", .state = .conflicted },
        },
        .git_graph = &.{
            .{ .commit = "abc1234", .summary = "panel presentation", .branch = "main" },
        },
        .files = &.{
            .{ .path = "src", .kind = .directory },
            .{ .path = "src/main.zig", .kind = .file, .dirty = true },
        },
    } });

    const preview = app.projectPanelPresentationRequest();
    try std.testing.expect(preview.canShow());
    try std.testing.expect(preview.hasPanelData());
    try std.testing.expect(preview.show_git_status);
    try std.testing.expect(preview.show_git_graph);
    try std.testing.expect(preview.show_files);
    try std.testing.expectEqual(@as(usize, 2), preview.summary.git_status_count);
    try std.testing.expectEqual(@as(usize, 1), preview.summary.git_graph_count);
    try std.testing.expectEqual(@as(usize, 2), preview.summary.file_entry_count);
    try std.testing.expectEqual(@as(usize, 2), preview.summary.changed_count);
    try std.testing.expectEqual(@as(usize, 1), preview.summary.conflict_count);

    const request = (try app.dispatch(.show_project_panel)).project_panel_requested;
    try std.testing.expect(request.canShow());
    try std.testing.expect(request.hasPanelData());
    try std.testing.expectEqual(@as(usize, 1), request.summary.dirty_file_count);
    try std.testing.expectEqual(Host.ProjectPanelPresentationStatus.show_requested, app.host.project_panel_status);

    const shown = (try app.dispatch(.{ .project_panel_receipt = .{ .status = .shown } })).project_panel_changed;
    try std.testing.expectEqual(Host.ProjectPanelPresentationStatus.shown, shown);
    try std.testing.expect(app.host.last_project_panel != null);

    const hidden = (try app.dispatch(.hide_project_panel)).project_panel_changed;
    try std.testing.expectEqual(Host.ProjectPanelPresentationStatus.hidden, hidden);
    try std.testing.expect(app.host.last_project_panel == null);
}

test "app project panel presentation handles empty and invalid receipts" {
    const allocator = std.testing.allocator;
    var app = try App.init(allocator);
    defer app.deinit();

    const empty = (try app.dispatch(.show_project_panel)).project_panel_requested;
    try std.testing.expect(empty.canShow());
    try std.testing.expect(!empty.hasPanelData());
    try std.testing.expectEqual(@as(usize, 0), empty.summary.file_entry_count);

    try std.testing.expectError(error.InvalidProjectPanelPresentationReceipt, app.dispatch(.{ .project_panel_receipt = .{
        .status = .show_requested,
    } }));

    const dismissed = (try app.dispatch(.{ .project_panel_receipt = .{ .status = .dismissed } })).project_panel_changed;
    try std.testing.expectEqual(Host.ProjectPanelPresentationStatus.dismissed, dismissed);
    try std.testing.expect(app.host.last_project_panel == null);
    try std.testing.expectError(error.ProjectPanelPresentationMismatch, app.dispatch(.{ .project_panel_receipt = .{
        .status = .shown,
    } }));
}

test "app dispatches bounded project panel views" {
    const allocator = std.testing.allocator;
    var app = try App.init(allocator);
    defer app.deinit();

    _ = try app.dispatch(.{ .set_project_panels = .{
        .git_status = &.{
            .{ .path = "src/main.zig", .state = .modified },
            .{ .path = "README.md", .state = .conflicted },
            .{ .path = "zig-cache", .state = .ignored },
        },
        .git_graph = &.{
            .{ .commit = "abc1234", .summary = "app panel view", .branch = "main" },
        },
        .files = &.{
            .{ .path = "src", .kind = .directory },
            .{ .path = "src/main.zig", .kind = .file, .dirty = true },
        },
    } });

    const changed = (try app.dispatch(.{ .project_panel_view = .{
        .kind = .git_status,
        .max_rows = 2,
        .changed_only = true,
        .selected_index = 1,
    } })).project_panel_viewed;
    try std.testing.expectEqual(Workspace.ProjectPanelViewKind.git_status, changed.kind);
    try std.testing.expectEqual(@as(usize, 2), changed.visible_rows);
    try std.testing.expectEqual(@as(usize, 2), changed.row_count);
    try std.testing.expect(changed.selected_visible);
    try std.testing.expectEqualStrings("README.md", changed.rowSlice()[1].git_status.path);

    const files = app.projectPanelView(.{
        .kind = .files,
        .dirty_only = true,
    });
    try std.testing.expectEqual(Workspace.ProjectPanelViewKind.files, files.kind);
    try std.testing.expectEqual(@as(usize, 1), files.visible_rows);
    try std.testing.expectEqualStrings("src/main.zig", files.rowSlice()[0].files.path);
}

test "app dispatches project panel row activation intents" {
    const allocator = std.testing.allocator;
    var app = try App.init(allocator);
    defer app.deinit();

    _ = try app.dispatch(.{ .set_project_panels = .{
        .git_status = &.{
            .{ .path = "src/main.zig", .state = .modified },
        },
        .git_graph = &.{
            .{ .commit = "abc1234", .summary = "app panel action", .branch = "main" },
        },
        .files = &.{
            .{ .path = "src", .kind = .directory },
            .{ .path = "src/main.zig", .kind = .file, .dirty = true },
        },
    } });

    const diff = (try app.dispatch(.{ .activate_project_panel_row = .{
        .kind = .git_status,
        .source_index = 0,
    } })).project_panel_activated;
    try std.testing.expectEqual(Workspace.ProjectPanelActivationKind.show_git_diff, diff.kind);
    try std.testing.expectEqualStrings("src/main.zig", diff.path.?);

    const file = try app.activateProjectPanelRow(.{
        .kind = .files,
        .source_index = 1,
    });
    try std.testing.expectEqual(Workspace.ProjectPanelActivationKind.open_file, file.kind);
    try std.testing.expectEqualStrings("src/main.zig", file.path.?);

    const commit = (try app.dispatch(.{ .activate_project_panel_row = .{
        .kind = .git_graph,
        .source_index = 0,
    } })).project_panel_activated;
    try std.testing.expectEqual(Workspace.ProjectPanelActivationKind.show_git_commit, commit.kind);
    try std.testing.expectEqualStrings("abc1234", commit.commit.?);
    try std.testing.expectError(error.ProjectPanelRowNotFound, app.dispatch(.{ .activate_project_panel_row = .{
        .kind = .files,
        .source_index = 2,
    } }));
}

test "app requests project panel action handoff and applies receipts" {
    const allocator = std.testing.allocator;
    var app = try App.init(allocator);
    defer app.deinit();

    _ = try app.dispatch(.{ .set_project_panels = .{
        .git_status = &.{
            .{ .path = "src/main.zig", .state = .modified },
        },
        .git_graph = &.{
            .{ .commit = "abc1234", .summary = "app panel handoff", .branch = "main" },
        },
        .files = &.{
            .{ .path = "src", .kind = .directory },
            .{ .path = "src/main.zig", .kind = .file, .dirty = true },
        },
    } });

    const plan = (try app.dispatch(.{ .plan_project_panel_action = .{
        .kind = .files,
        .source_index = 1,
    } })).project_panel_action_planned;
    try std.testing.expect(plan.canExecute());
    try std.testing.expectEqual(Workspace.ProjectPanelActionExecutor.native_file_open, plan.executor);
    try std.testing.expect(plan.opens_editor);
    try std.testing.expectEqualStrings("src/main.zig", plan.path.?);
    try std.testing.expectError(error.ProjectPanelActionResultMissing, app.dispatch(.project_panel_action_result_view));

    const spec = (try app.dispatch(.{ .prepare_project_panel_action = .{
        .kind = .git_status,
        .source_index = 0,
    } })).project_panel_action_prepared;
    try std.testing.expectEqual(Workspace.ProjectPanelActionOperation.run_git_diff, spec.operation);
    try std.testing.expect(spec.requires_process);
    try std.testing.expectEqual(@as(usize, 4), spec.argvSlice().len);
    try std.testing.expectEqualStrings("src/main.zig", spec.argvSlice()[3]);
    try std.testing.expect(app.pending_project_panel_action_execution != null);

    const result = (try app.dispatch(.{ .project_panel_action_execution_receipt = .{
        .source = spec.source,
        .executor = spec.executor,
        .operation = spec.operation,
        .status = .completed,
        .exit_code = 0,
        .stdout_bytes = 256,
    } })).project_panel_action_execution_result;
    try std.testing.expect(result.succeeded());
    try std.testing.expectEqual(Workspace.ProjectPanelActionOperation.run_git_diff, result.operation);
    try std.testing.expectEqual(@as(usize, 256), result.stdout_bytes);
    try std.testing.expect(app.pending_project_panel_action_execution == null);
    try std.testing.expect(app.last_project_panel_action_result != null);

    const result_view = (try app.dispatch(.project_panel_action_result_view)).project_panel_action_result_viewed;
    try std.testing.expectEqual(Workspace.ProjectPanelActionResultTone.success, result_view.tone);
    try std.testing.expectEqualStrings("Git diff", result_view.title);
    try std.testing.expect(result_view.shows_process_output);
    try std.testing.expect(result_view.has_output);
    try std.testing.expect(!result_view.needsAttention());

    try std.testing.expectError(error.ProjectPanelActionExecutionMismatch, app.dispatch(.{ .project_panel_action_execution_receipt = .{
        .source = spec.source,
        .executor = spec.executor,
        .operation = spec.operation,
        .status = .completed,
    } }));

    const preview = try app.projectPanelActionRequest(.{
        .kind = .files,
        .source_index = 1,
    });
    try std.testing.expect(preview.canDispatch());
    try std.testing.expectEqual(Host.ProjectPanelActionStatus.pending, preview.status);
    try std.testing.expectEqual(Workspace.ProjectPanelActivationKind.open_file, preview.activation.kind);

    const request = (try app.dispatch(.{ .request_project_panel_action = .{
        .kind = .git_graph,
        .source_index = 0,
    } })).project_panel_action_requested;
    try std.testing.expect(request.canDispatch());
    try std.testing.expectEqual(Host.ProjectPanelActionTransport.native_workspace_action, request.transport);
    try std.testing.expectEqual(Workspace.ProjectPanelActivationKind.show_git_commit, request.activation.kind);
    try std.testing.expectEqual(Host.ProjectPanelActionStatus.pending, app.host.project_panel_action_status);

    const completed = (try app.dispatch(.{ .project_panel_action_receipt = .{
        .source = request.activation.source,
        .kind = request.activation.kind,
        .transport = request.transport,
        .status = .completed,
    } })).project_panel_action_changed;
    try std.testing.expectEqual(Host.ProjectPanelActionStatus.completed, completed);
    try std.testing.expect(app.host.last_project_panel_action == null);

    try std.testing.expectError(error.ProjectPanelActionMismatch, app.dispatch(.{ .project_panel_action_receipt = .{
        .source = request.activation.source,
        .kind = request.activation.kind,
        .transport = request.transport,
        .status = .completed,
    } }));
}

test "app applies parsed project scan results to project panels" {
    const allocator = std.testing.allocator;
    var app = try App.init(allocator);
    defer app.deinit();

    var status_scan = try ProjectScan.parseGitStatusPorcelainAlloc(
        allocator,
        " M src/app/App.zig\x00?? docs/project.md\x00",
        8,
    );
    defer status_scan.deinit(allocator);

    const result = try app.dispatch(.{ .set_project_panel_scan = status_scan });
    try std.testing.expectEqual(@as(usize, 2), result.project_panels_changed.changed_count);
    try std.testing.expectEqualStrings("src/app/App.zig", app.workspace.project_panels.git_status[0].path);
    try std.testing.expectEqual(Workspace.GitFileState.untracked, app.workspace.project_panels.git_status[1].state);
}

test "app saves loads workspace files and tracks recovery state" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var app = try App.init(allocator);
    defer app.deinit();

    const default_path = try app.defaultWorkspacePathAlloc("/home/alice", "NOCTTY repo", .recovery);
    defer allocator.free(default_path);
    try std.testing.expectEqualStrings("/home/alice/.local/state/noctty/recovery/NOCTTY-repo.nocttyws", default_path);

    try app.configureRecoveryPolicy(.{
        .autosave_interval_seconds = 10,
        .max_recovery_snapshots = 2,
    });
    _ = try app.dispatch(.split_down);
    try app.workspace.findPane(2).?.addTag("agent");
    _ = try app.dispatch(.{ .set_project_panels = .{
        .git_status = &.{.{ .path = "src/app/App.zig", .state = .modified }},
        .files = &.{.{ .path = "src/app/App.zig", .kind = .file, .dirty = true }},
    } });
    app.markWorkspaceDirty();
    try std.testing.expect(app.recovery.shouldAutosave(10));

    const saved = try app.saveWorkspaceFile(io, tmp.dir, "state/recovery/project.nocttyws", .recovery);
    defer saved.deinit(allocator);
    try std.testing.expect(saved.bytes > 16);
    try std.testing.expect(saved.recovery_pending);
    try std.testing.expect(!app.recovery.dirty);
    try std.testing.expectEqualStrings("state/recovery/project.nocttyws", app.recovery.recovery_path.?);

    _ = try app.dispatch(.{ .preset = .three_by_three });
    try std.testing.expectEqual(@as(usize, 9), app.workspace.activeTab().?.panes.items.len);

    const loaded = try app.loadWorkspaceFile(io, tmp.dir, "state/recovery/project.nocttyws", .recovery);
    defer loaded.deinit(allocator);
    try std.testing.expect(loaded.recovery_pending);
    try std.testing.expectEqual(@as(usize, 2), app.workspace.activeTab().?.panes.items.len);
    try std.testing.expectEqualStrings("agent", app.workspace.findPane(2).?.tags.items[0]);
    try std.testing.expectEqual(Workspace.GitFileState.modified, app.workspace.project_panels.git_status[0].state);
    try std.testing.expect(!app.recovery.dirty);

    app.markWorkspaceDirty();
    const manual = try app.saveWorkspaceFile(io, tmp.dir, "saved/project.nocttyws", .manual);
    defer manual.deinit(allocator);
    try std.testing.expect(app.recovery.recovery_path == null);
    try std.testing.expectEqualStrings("saved/project.nocttyws", app.recovery.last_path.?);
}

test "app rejects invalid recovery policies without mutating current policy" {
    const allocator = std.testing.allocator;
    var app = try App.init(allocator);
    defer app.deinit();

    try std.testing.expectError(error.InvalidRecoveryPolicy, app.configureRecoveryPolicy(.{
        .autosave_interval_seconds = 0,
    }));
    try std.testing.expectEqual(@as(u16, 1), app.recovery.policy.autosave_interval_seconds);
}

test "app plans and applies recovery cleanup with configured retention" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var app = try App.init(allocator);
    defer app.deinit();
    try app.configureRecoveryPolicy(.{ .max_recovery_snapshots = 1 });

    try tmp.dir.writeFile(io, .{ .sub_path = "keep.nocttyws", .data = "new" });
    try tmp.dir.writeFile(io, .{ .sub_path = "delete.nocttyws", .data = "old" });

    var plan = try app.planRecoveryCleanup(&.{
        .{ .path = "keep.nocttyws", .role = .recovery, .saved_generation = 2, .saved_at_ms = 2000 },
        .{ .path = "delete.nocttyws", .role = .autosave, .saved_generation = 1, .saved_at_ms = 1000 },
    });
    defer plan.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 1), plan.retained_count);
    try std.testing.expectEqualStrings("delete.nocttyws", plan.delete_entries[0].path);

    const receipt = try app.applyRecoveryCleanup(io, tmp.dir, plan);
    try std.testing.expectEqual(@as(usize, 1), receipt.deleted_count);
    try std.testing.expectEqual(@as(usize, 0), receipt.missing_count);

    const kept = try tmp.dir.readFileAlloc(io, "keep.nocttyws", allocator, .limited(16));
    defer allocator.free(kept);
    try std.testing.expectEqualStrings("new", kept);
    try std.testing.expectError(error.FileNotFound, tmp.dir.readFileAlloc(io, "delete.nocttyws", allocator, .limited(16)));
}

test "app maintenance tick plans autosave project refresh and recovery cleanup" {
    const allocator = std.testing.allocator;
    var app = try App.init(allocator);
    defer app.deinit();

    try app.configureRecoveryPolicy(.{
        .autosave_interval_seconds = 10,
        .max_recovery_snapshots = 2,
    });
    try app.configureMaintenancePolicy(.{
        .project_refresh_interval_seconds = 5,
        .recovery_cleanup_interval_seconds = 20,
    });
    app.markWorkspaceDirtyAt(1000);

    const first = (try app.dispatch(.{ .maintenance_tick = .{ .now_ms = 6000 } })).maintenance_planned;
    try std.testing.expect(!first.autosave_due);
    try std.testing.expect(first.project_refresh_due);
    try std.testing.expect(first.recovery_cleanup_due);
    try std.testing.expect(first.project_refresh_pending);
    try std.testing.expect(first.recovery_cleanup_pending);
    try std.testing.expect(first.hasDueWork());

    const second = (try app.dispatch(.{ .maintenance_tick = .{ .now_ms = 7000 } })).maintenance_planned;
    try std.testing.expect(!second.autosave_due);
    try std.testing.expect(!second.project_refresh_due);
    try std.testing.expect(!second.recovery_cleanup_due);
    try std.testing.expect(second.project_refresh_pending);
    try std.testing.expect(second.recovery_cleanup_pending);

    const autosave = (try app.dispatch(.{ .maintenance_tick = .{ .now_ms = 11000 } })).maintenance_planned;
    try std.testing.expect(autosave.autosave_due);
    try std.testing.expect(autosave.autosave_pending);
    try std.testing.expectEqual(app.recovery.generation, autosave.dirty_generation);
    try std.testing.expectEqual(app.recovery.saved_generation, autosave.saved_generation);
}

test "app maintenance receipts clear pending refresh and cleanup work" {
    const allocator = std.testing.allocator;
    var app = try App.init(allocator);
    defer app.deinit();

    try app.configureMaintenancePolicy(.{
        .project_refresh_interval_seconds = 5,
        .recovery_cleanup_interval_seconds = 20,
    });
    _ = try app.dispatch(.{ .maintenance_tick = .{ .now_ms = 1000 } });

    const summary = Workspace.ProjectPanelSummary{
        .git_status_count = 2,
        .changed_count = 1,
        .file_entry_count = 5,
        .directory_count = 2,
    };
    const recorded = (try app.dispatch(.{ .project_refresh_receipt = .{
        .completed_at_ms = 2000,
        .summary = summary,
    } })).project_refresh_recorded;
    try std.testing.expectEqual(@as(usize, 2), recorded.git_status_count);
    try std.testing.expect(!app.maintenance.project_refresh_pending);
    try std.testing.expectEqual(@as(?u64, 2000), app.maintenance.last_project_refresh_ms);

    const cleanup = Storage.RecoveryCleanupReceipt{
        .retained_count = 2,
        .deleted_count = 1,
    };
    const cleanup_recorded = (try app.dispatch(.{ .recovery_cleanup_receipt = .{
        .completed_at_ms = 3000,
        .receipt = cleanup,
    } })).recovery_cleanup_recorded;
    try std.testing.expectEqual(@as(usize, 1), cleanup_recorded.deleted_count);
    try std.testing.expect(!app.maintenance.recovery_cleanup_pending);
    try std.testing.expectEqual(@as(?u64, 3000), app.maintenance.last_recovery_cleanup_ms);

    const quiet = (try app.dispatch(.{ .maintenance_tick = .{ .now_ms = 6000 } })).maintenance_planned;
    try std.testing.expect(!quiet.project_refresh_due);
    try std.testing.expect(!quiet.recovery_cleanup_due);

    try std.testing.expectError(error.StaleProjectRefreshReceipt, app.dispatch(.{ .project_refresh_receipt = .{
        .completed_at_ms = 1000,
        .summary = .{},
    } }));
    try std.testing.expectError(error.StaleRecoveryCleanupReceipt, app.dispatch(.{ .recovery_cleanup_receipt = .{
        .completed_at_ms = 1000,
        .receipt = .{},
    } }));
}

test "workspace autosave clears pending maintenance autosave state" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var app = try App.init(allocator);
    defer app.deinit();
    try app.configureRecoveryPolicy(.{
        .autosave_interval_seconds = 1,
        .max_recovery_snapshots = 2,
    });
    app.markWorkspaceDirtyAt(0);

    const plan = (try app.dispatch(.{ .maintenance_tick = .{ .now_ms = 1000 } })).maintenance_planned;
    try std.testing.expect(plan.autosave_due);
    try std.testing.expect(app.maintenance.autosave_pending);

    const saved = try app.saveWorkspaceFile(io, tmp.dir, "autosave/project.nocttyws", .autosave);
    defer saved.deinit(allocator);
    try std.testing.expect(!app.recovery.dirty);
    try std.testing.expect(!app.maintenance.autosave_pending);
    try std.testing.expect(app.maintenance.workspace_dirty_since_ms == null);
}

test "app dispatches workspace save and open dialog requests" {
    const allocator = std.testing.allocator;
    var app = try App.init(allocator);
    defer app.deinit();

    const save_request = (try app.dispatch(.{ .show_workspace_file_dialog = .{
        .operation = .save,
        .suggested_path = "/home/alice/project.nocttyws",
    } })).workspace_file_dialog_requested;
    try std.testing.expect(save_request.canShow());
    try std.testing.expectEqual(Host.WorkspaceFileDialogOperation.save, save_request.operation);
    try std.testing.expectEqual(Host.WorkspaceFileDialogTransport.gtk_native_dialog, save_request.transport);
    try std.testing.expectEqual(Host.WorkspaceFileDialogStatus.pending, app.host.workspace_file_dialog_status);

    const shown = (try app.dispatch(.{ .workspace_file_dialog_receipt = .{
        .operation = save_request.operation,
        .transport = save_request.transport,
        .status = .shown,
    } })).workspace_file_dialog_changed;
    try std.testing.expectEqual(Host.WorkspaceFileDialogStatus.shown, shown);

    const selected = (try app.dispatch(.{ .workspace_file_dialog_receipt = .{
        .operation = save_request.operation,
        .transport = save_request.transport,
        .status = .selected,
        .selected_path = "/home/alice/project.nocttyws",
    } })).workspace_file_dialog_changed;
    try std.testing.expectEqual(Host.WorkspaceFileDialogStatus.selected, selected);
    try std.testing.expect(app.host.workspace_file_dialog_operation == null);

    const open_request = try app.workspaceFileDialogRequest(.{
        .operation = .open,
        .suggested_path = "/home/alice/project.nocttyws",
    });
    try std.testing.expect(open_request.canShow());
    try std.testing.expectEqual(Host.WorkspaceFileDialogOperation.open, open_request.operation);
}

test "app rejects invalid workspace file dialog receipts" {
    const allocator = std.testing.allocator;
    var app = try App.init(allocator);
    defer app.deinit();

    try std.testing.expectError(error.InvalidWorkspaceFileDialogPath, app.dispatch(.{ .show_workspace_file_dialog = .{
        .operation = .save,
        .suggested_path = "",
    } }));

    const request = (try app.dispatch(.{ .show_workspace_file_dialog = .{
        .operation = .open,
        .suggested_path = "/home/alice/project.nocttyws",
    } })).workspace_file_dialog_requested;
    try std.testing.expectError(error.InvalidWorkspaceFileDialogReceipt, app.dispatch(.{ .workspace_file_dialog_receipt = .{
        .operation = request.operation,
        .transport = request.transport,
        .status = .selected,
    } }));
    const canceled = (try app.dispatch(.{ .workspace_file_dialog_receipt = .{
        .operation = request.operation,
        .transport = request.transport,
        .status = .canceled,
    } })).workspace_file_dialog_changed;
    try std.testing.expectEqual(Host.WorkspaceFileDialogStatus.canceled, canceled);
}

test "workspace file dialog selected paths save and load workspace files" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var app = try App.init(allocator);
    defer app.deinit();
    _ = try app.dispatch(.split_down);
    try app.workspace.findPane(2).?.addTag("dialog-save");
    app.markWorkspaceDirtyAt(0);

    const save_request = (try app.dispatch(.{ .show_workspace_file_dialog = .{
        .operation = .save,
        .suggested_path = "manual/project.nocttyws",
    } })).workspace_file_dialog_requested;
    const saved = try app.applyWorkspaceFileDialogFileAction(io, tmp.dir, .{
        .operation = save_request.operation,
        .transport = save_request.transport,
        .status = .selected,
        .selected_path = "manual/project.nocttyws",
    }, .manual);
    defer saved.deinit(allocator);
    try std.testing.expectEqual(Host.WorkspaceFileDialogStatus.selected, saved.status);
    try std.testing.expectEqual(Storage.WorkspaceFileRole.manual, saved.file_receipt.?.role);
    try std.testing.expect(saved.file_receipt.?.bytes > 16);
    try std.testing.expect(!app.recovery.dirty);
    try std.testing.expect(app.host.workspace_file_dialog_operation == null);

    _ = try app.dispatch(.{ .preset = .three_by_three });
    try std.testing.expectEqual(@as(usize, 9), app.workspace.activeTab().?.panes.items.len);

    const open_request = (try app.dispatch(.{ .show_workspace_file_dialog = .{
        .operation = .open,
        .suggested_path = "manual/project.nocttyws",
    } })).workspace_file_dialog_requested;
    const loaded = try app.applyWorkspaceFileDialogFileAction(io, tmp.dir, .{
        .operation = open_request.operation,
        .transport = open_request.transport,
        .status = .selected,
        .selected_path = "manual/project.nocttyws",
    }, .manual);
    defer loaded.deinit(allocator);
    try std.testing.expectEqual(Host.WorkspaceFileDialogStatus.selected, loaded.status);
    try std.testing.expectEqual(Storage.WorkspaceFileRole.manual, loaded.file_receipt.?.role);
    try std.testing.expectEqual(@as(usize, 2), app.workspace.activeTab().?.panes.items.len);
    try std.testing.expectEqualStrings("dialog-save", app.workspace.findPane(2).?.tags.items[0]);
}

test "workspace file dialog canceled selection does not touch files" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var app = try App.init(allocator);
    defer app.deinit();
    const request = (try app.dispatch(.{ .show_workspace_file_dialog = .{
        .operation = .save,
        .suggested_path = "manual/project.nocttyws",
    } })).workspace_file_dialog_requested;
    const result = try app.applyWorkspaceFileDialogFileAction(io, tmp.dir, .{
        .operation = request.operation,
        .transport = request.transport,
        .status = .canceled,
    }, .manual);
    defer result.deinit(allocator);
    try std.testing.expectEqual(Host.WorkspaceFileDialogStatus.canceled, result.status);
    try std.testing.expect(result.file_receipt == null);
    try std.testing.expectError(error.FileNotFound, tmp.dir.readFileAlloc(io, "manual/project.nocttyws", allocator, .limited(16)));

    const second = (try app.dispatch(.{ .show_workspace_file_dialog = .{
        .operation = .save,
        .suggested_path = "manual/project.nocttyws",
    } })).workspace_file_dialog_requested;
    try std.testing.expectError(error.InvalidWorkspaceFileDialogRole, app.applyWorkspaceFileDialogFileAction(io, tmp.dir, .{
        .operation = second.operation,
        .transport = second.transport,
        .status = .selected,
        .selected_path = "manual/project.nocttyws",
    }, .autosave));
}

test "app dispatches terminal status detection and notification requests" {
    const allocator = std.testing.allocator;
    var app = try App.init(allocator);
    defer app.deinit();

    const started = try app.dispatch(.{ .terminal_status = .{ .pane_id = 1, .event = .{ .process_started = 0 } } });
    try std.testing.expectEqual(Terminal.TerminalStatus.running, started.status_changed.current);
    try std.testing.expect(!started.status_changed.notification_queued);
    try std.testing.expectEqual(@as(usize, 0), app.host.notification_count);

    const pending = try app.dispatch(.{ .terminal_status = .{ .pane_id = 1, .event = .{ .waiting_for_input = 100 } } });
    try std.testing.expectEqual(Terminal.TerminalStatus.pending_interaction, pending.status_changed.current);
    try std.testing.expect(pending.status_changed.notification_queued);
    try std.testing.expectEqual(Host.NotificationReason.pending_interaction, app.host.last_notification.?.reason);

    const repeated = try app.dispatch(.{ .terminal_status = .{ .pane_id = 1, .event = .{ .waiting_for_input = 200 } } });
    try std.testing.expectEqual(Terminal.TerminalStatus.pending_interaction, repeated.status_changed.current);
    try std.testing.expect(!repeated.status_changed.notification_queued);
    try std.testing.expectEqual(@as(usize, 1), app.host.notification_count);

    _ = try app.dispatch(.{ .terminal_status = .{ .pane_id = 1, .event = .{ .output_received = 300 } } });
    const done = try app.dispatch(.{ .terminal_status = .{ .pane_id = 1, .event = .{ .exited = .{ .code = 0, .at_ms = 400 } } } });
    try std.testing.expectEqual(Terminal.TerminalStatus.done, done.status_changed.current);
    try std.testing.expect(done.status_changed.notification_queued);
    try std.testing.expectEqual(Host.NotificationReason.completed, app.host.last_notification.?.reason);
}

test "app persists active theme workspace color changes" {
    const allocator = std.testing.allocator;
    var app = try App.init(allocator);
    defer app.deinit();

    _ = try app.dispatch(.{ .set_theme_chrome_color = .{
        .role = .scrollbar_thumb,
        .color = Theme.Color.fromHex(0x123456),
    } });
    try std.testing.expectEqual(
        Theme.Color.fromHex(0x123456),
        app.activeTheme().chromeColor(.scrollbar_thumb),
    );
}

test "app materializes a missing active theme before changing workspace colors" {
    const allocator = std.testing.allocator;
    var app = try App.init(allocator);
    defer app.deinit();

    _ = try app.dispatch(.{ .set_default_theme = "missing-library-theme" });
    _ = try app.dispatch(.{ .set_theme_chrome_color = .{
        .role = .overlay_border,
        .color = Theme.Color.fromHex(0xabcdef),
    } });
    try std.testing.expect(app.findTheme("missing-library-theme") != null);
    try std.testing.expectEqual(
        Theme.Color.fromHex(0xabcdef),
        app.activeTheme().chromeColor(.overlay_border),
    );
}

test "app exposes active tab status summary for host chrome" {
    const allocator = std.testing.allocator;
    var app = try App.init(allocator);
    defer app.deinit();

    _ = try app.dispatch(.split_down);
    _ = try app.dispatch(.{ .terminal_status = .{ .pane_id = 2, .event = .{ .waiting_for_input = 100 } } });

    const summary = try app.activeTabStatusSummary();
    try std.testing.expectEqual(@as(usize, 2), summary.total);
    try std.testing.expectEqual(@as(usize, 1), summary.attention_total);
    try std.testing.expectEqual(Terminal.TerminalStatus.pending_interaction, summary.lines[0].status);
}
