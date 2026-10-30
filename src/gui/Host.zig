//! Platform-neutral native-host contracts and presentation state.
//!
//! These types describe requests and receipts; they do not call GTK, Win32, or
//! compositor APIs directly. Keep backend side effects in adapters so model
//! tests can cover lifecycle, geometry, accessibility, and failure reporting.

const std = @import("std");
const Config = @import("../config/Config.zig");
const Paste = @import("../terminal/Paste.zig");
const Terminal = @import("../terminal/Terminal.zig");
const Workspace = @import("../workspace/Workspace.zig");
const Backend = @import("Backend.zig");
const Noctalia = @import("Noctalia.zig");

pub const Screen = struct {
    x: i32 = 0,
    y: i32 = 0,
    width_px: u32 = 1920,
    height_px: u32 = 1080,
    scale: f32 = 1.0,

    pub fn default() Screen {
        return .{};
    }
};

pub const Rect = struct {
    x: i32,
    y: i32,
    width_px: u32,
    height_px: u32,
};

pub const WindowState = struct {
    mode: Config.WindowMode,
    visible: bool,
    rect: Rect,
    fullscreen: bool = false,
};

pub const SurfaceIntent = enum {
    unavailable,
    hidden_dropdown,
    visible_dropdown,
    visible_windowed,
    visible_fullscreen,
};

pub const LaunchReadiness = enum {
    ready,
    degraded,
    unavailable,
};

pub const LaunchPlan = struct {
    backend: Backend.BackendKind,
    readiness: LaunchReadiness,
    initial_surface: SurfaceIntent,
    shortcut_activation_surface: SurfaceIntent,
    initial_rect: Rect,
    shortcut_activation_rect: Rect,
    chrome: Backend.WindowChrome,
    shortcut: Config.Shortcut,
    register_global_shortcut: bool,
    use_layer_shell: bool,
    use_desktop_notifications: bool,
    use_external_activation: bool,
    use_drag_and_drop: bool,
    hidpi: bool,

    pub fn canPresentWindow(self: LaunchPlan) bool {
        return self.readiness != .unavailable;
    }

    pub fn needsShortcutRegistration(self: LaunchPlan) bool {
        return self.initial_surface == .hidden_dropdown and self.register_global_shortcut;
    }
};

pub const PresentationTrigger = enum {
    startup,
    shortcut_activation,
};

pub const PresentationProtocol = enum {
    unavailable,
    wayland_layer_shell,
    wayland_toplevel,
    x11_ewmh,
};

pub const PresentationAction = enum {
    create_surface,
    configure_zero_chrome,
    configure_layer_shell,
    configure_wayland_toplevel,
    configure_x11_ewmh,
    set_window_rect,
    register_global_shortcut,
    bind_external_activation,
    enable_drag_and_drop,
    bind_desktop_notifications,
    show_surface,
    hide_surface,
    enter_fullscreen,
};

pub const PresentationPlan = struct {
    trigger: PresentationTrigger,
    protocol: PresentationProtocol,
    readiness: LaunchReadiness,
    target_surface: SurfaceIntent,
    target_rect: Rect,
    actions: [12]PresentationAction = undefined,
    action_count: usize = 0,

    pub fn actionSlice(self: *const PresentationPlan) []const PresentationAction {
        return self.actions[0..self.action_count];
    }

    pub fn containsAction(self: PresentationPlan, action: PresentationAction) bool {
        for (self.actionSlice()) |candidate| {
            if (candidate == action) return true;
        }
        return false;
    }

    pub fn hasTransportWork(self: PresentationPlan) bool {
        return self.action_count > 0;
    }

    fn appendAction(self: *PresentationPlan, action: PresentationAction) void {
        std.debug.assert(self.action_count < self.actions.len);
        self.actions[self.action_count] = action;
        self.action_count += 1;
    }
};

pub const ShortcutRegistrationTransport = enum {
    unavailable,
    kde_global_accel,
    compositor_binding,
    x11_grab_key,
};

pub const ShortcutRegistrationStatus = enum {
    not_requested,
    unavailable,
    pending,
    registered,
    denied,
    conflict,
    failed,
};

pub const ShortcutRegistrationRequest = struct {
    shortcut: Config.Shortcut,
    transport: ShortcutRegistrationTransport,
    status: ShortcutRegistrationStatus,

    pub fn canRegister(self: ShortcutRegistrationRequest) bool {
        return self.transport != .unavailable and self.status == .pending;
    }
};

pub const ShortcutRegistrationReceipt = struct {
    shortcut: Config.Shortcut,
    transport: ShortcutRegistrationTransport,
    status: ShortcutRegistrationStatus,

    pub fn completed(self: ShortcutRegistrationReceipt) bool {
        return switch (self.status) {
            .registered, .denied, .conflict, .failed, .unavailable => true,
            .not_requested, .pending => false,
        };
    }
};

pub const WindowLifecycleStatus = enum {
    not_requested,
    unavailable,
    create_requested,
    created,
    shown,
    hidden,
    destroyed,
    failed,
};

pub const WindowLifecycleRequest = struct {
    trigger: PresentationTrigger,
    protocol: PresentationProtocol,
    target_surface: SurfaceIntent,
    target_rect: Rect,
    status: WindowLifecycleStatus,

    pub fn canCreate(self: WindowLifecycleRequest) bool {
        return self.protocol != .unavailable and self.status == .create_requested;
    }
};

pub const WindowLifecycleReceipt = struct {
    trigger: PresentationTrigger,
    protocol: PresentationProtocol,
    target_surface: SurfaceIntent,
    target_rect: Rect,
    status: WindowLifecycleStatus,
    window_id: ?u64 = null,

    pub fn completed(self: WindowLifecycleReceipt) bool {
        return switch (self.status) {
            .created, .shown, .hidden, .destroyed, .failed, .unavailable => true,
            .not_requested, .create_requested => false,
        };
    }
};

pub const ResizePreview = struct {
    width_px: u32,
    height_px: u32,
    cols: u16,
    rows: u16,
};

pub const ShortcutRecorder = struct {
    active: bool = false,
    captured: ?Config.Shortcut = null,

    pub fn begin(self: *ShortcutRecorder) void {
        self.active = true;
        self.captured = null;
    }

    pub fn cancel(self: *ShortcutRecorder) void {
        self.active = false;
        self.captured = null;
    }

    pub fn capture(self: *ShortcutRecorder, event: Config.KeyEvent) !Config.Shortcut {
        if (!self.active) return error.ShortcutRecorderInactive;
        const shortcut = try Config.Shortcut.fromKeyEvent(event);
        self.captured = shortcut;
        self.active = false;
        return shortcut;
    }
};

pub const NotificationUrgency = enum {
    normal,
    critical,
};

pub const NotificationReason = enum {
    completed,
    failed,
    pending_interaction,
    long_running,
};

pub const NotificationRequest = struct {
    pane_id: Terminal.PaneId,
    status: Terminal.TerminalStatus,
    reason: NotificationReason,
    urgency: NotificationUrgency,

    pub fn title(self: NotificationRequest) []const u8 {
        return switch (self.reason) {
            .completed => "Terminal completed",
            .failed => "Terminal failed",
            .pending_interaction => "Terminal needs input",
            .long_running => "Terminal still running",
        };
    }
};

pub const NotificationTransport = enum {
    unavailable,
    freedesktop_dbus,
};

pub const NotificationDeliveryStatus = enum {
    not_requested,
    unavailable,
    pending,
    delivered,
    denied,
    failed,
};

pub const NotificationDeliveryRequest = struct {
    notification: ?NotificationRequest,
    transport: NotificationTransport,
    status: NotificationDeliveryStatus,

    pub fn canDeliver(self: NotificationDeliveryRequest) bool {
        return self.notification != null and self.transport != .unavailable and self.status == .pending;
    }
};

pub const NotificationDeliveryReceipt = struct {
    request: NotificationRequest,
    transport: NotificationTransport,
    status: NotificationDeliveryStatus,

    pub fn completed(self: NotificationDeliveryReceipt) bool {
        return switch (self.status) {
            .delivered, .denied, .failed, .unavailable => true,
            .not_requested, .pending => false,
        };
    }
};

pub const ClipboardSelection = enum {
    clipboard,
    primary,
};

pub const ClipboardOperation = enum {
    read,
    write,
};

pub const ClipboardTransport = enum {
    unavailable,
    wayland_data_control,
    x11_selection,
};

pub const ClipboardTransferStatus = enum {
    not_requested,
    unavailable,
    pending,
    completed,
    denied,
    failed,
};

pub const ClipboardTransferRequest = struct {
    operation: ClipboardOperation,
    selection: ClipboardSelection,
    transport: ClipboardTransport,
    status: ClipboardTransferStatus,
    bytes: usize = 0,

    pub fn canTransfer(self: ClipboardTransferRequest) bool {
        return self.transport != .unavailable and self.status == .pending;
    }
};

pub const ClipboardTransferReceipt = struct {
    operation: ClipboardOperation,
    selection: ClipboardSelection,
    transport: ClipboardTransport,
    status: ClipboardTransferStatus,
    bytes: usize = 0,

    pub fn completed(self: ClipboardTransferReceipt) bool {
        return switch (self.status) {
            .completed, .denied, .failed, .unavailable => true,
            .not_requested, .pending => false,
        };
    }
};

pub const PasteDeliveryStatus = enum {
    not_requested,
    unavailable,
    pending,
    delivered,
    failed,
};

pub const PasteDeliveryRequest = struct {
    pane_id: Terminal.PaneId,
    bytes: usize,
    bracketed: bool,
    policy: Paste.PastePolicy,
    status: PasteDeliveryStatus,

    pub fn canDeliver(self: PasteDeliveryRequest) bool {
        return self.bytes > 0 and self.status == .pending;
    }
};

pub const PasteDeliveryReceipt = struct {
    pane_id: Terminal.PaneId,
    bytes: usize,
    status: PasteDeliveryStatus,

    pub fn completed(self: PasteDeliveryReceipt) bool {
        return switch (self.status) {
            .delivered, .failed, .unavailable => true,
            .not_requested, .pending => false,
        };
    }
};

pub const StatusTooltipStatus = enum {
    hidden,
    disabled,
    show_requested,
    shown,
    dismissed,
    failed,
};

pub const StatusTooltipRequest = struct {
    tab_id: u64,
    summary: Workspace.TabStatusSummary,
    details_enabled: bool,
    status: StatusTooltipStatus,

    pub fn canRequest(self: StatusTooltipRequest) bool {
        return self.details_enabled and self.status == .show_requested;
    }

    pub fn lineSlice(self: *const StatusTooltipRequest) []const Workspace.TabStatusLine {
        return self.summary.lines[0..self.summary.line_count];
    }

    pub fn formatTooltip(self: StatusTooltipRequest, writer: anytype) !void {
        if (!self.canRequest()) return error.StatusTooltipUnavailable;
        try self.summary.formatTooltip(writer);
    }
};

pub const StatusTooltipReceipt = struct {
    tab_id: u64,
    status: StatusTooltipStatus,

    pub fn completed(self: StatusTooltipReceipt) bool {
        return switch (self.status) {
            .disabled, .shown, .dismissed, .failed => true,
            .hidden, .show_requested => false,
        };
    }
};

pub const ProfilePresetMenuStatus = enum {
    hidden,
    unavailable,
    show_requested,
    shown,
    selected,
    dismissed,
    failed,
};

pub const ProfilePresetMenuItem = struct {
    preset: Terminal.ProfilePreset,
    profile: Terminal.TerminalProfile,
    current: bool,
};

pub const ProfilePresetMenuRequest = struct {
    pane_id: Terminal.PaneId,
    current_profile: Terminal.TerminalProfile,
    items: [profile_preset_menu_order.len]ProfilePresetMenuItem = undefined,
    item_count: usize = 0,
    status: ProfilePresetMenuStatus,

    pub fn canShow(self: ProfilePresetMenuRequest) bool {
        return self.status == .show_requested and self.item_count > 0;
    }

    pub fn itemSlice(self: *const ProfilePresetMenuRequest) []const ProfilePresetMenuItem {
        return self.items[0..self.item_count];
    }

    pub fn containsPreset(self: *const ProfilePresetMenuRequest, preset: Terminal.ProfilePreset) bool {
        for (self.itemSlice()) |item| {
            if (item.preset == preset) return true;
        }
        return false;
    }
};

pub const ProfilePresetMenuReceipt = struct {
    pane_id: Terminal.PaneId,
    status: ProfilePresetMenuStatus,
    selected_preset: ?Terminal.ProfilePreset = null,

    pub fn completed(self: ProfilePresetMenuReceipt) bool {
        return switch (self.status) {
            .unavailable, .shown, .selected, .dismissed, .failed => true,
            .hidden, .show_requested => false,
        };
    }
};

pub const WorkspaceFileDialogOperation = enum {
    save,
    open,
};

pub const WorkspaceFileDialogTransport = enum {
    unavailable,
    gtk_native_dialog,
    xdg_desktop_portal,
};

pub const WorkspaceFileDialogStatus = enum {
    not_requested,
    unavailable,
    pending,
    shown,
    selected,
    canceled,
    failed,
};

pub const WorkspaceFileDialogRequest = struct {
    operation: WorkspaceFileDialogOperation,
    suggested_path: []const u8,
    transport: WorkspaceFileDialogTransport,
    status: WorkspaceFileDialogStatus,

    pub fn canShow(self: WorkspaceFileDialogRequest) bool {
        return self.suggested_path.len > 0 and self.transport != .unavailable and self.status == .pending;
    }
};

pub const WorkspaceFileDialogReceipt = struct {
    operation: WorkspaceFileDialogOperation,
    transport: WorkspaceFileDialogTransport,
    status: WorkspaceFileDialogStatus,
    selected_path: ?[]const u8 = null,

    pub fn completed(self: WorkspaceFileDialogReceipt) bool {
        return switch (self.status) {
            .shown, .selected, .canceled, .failed, .unavailable => true,
            .not_requested, .pending => false,
        };
    }
};

pub const ProjectPanelPresentationStatus = enum {
    hidden,
    show_requested,
    shown,
    dismissed,
    failed,
};

pub const ProjectPanelPresentationRequest = struct {
    summary: Workspace.ProjectPanelSummary,
    status: ProjectPanelPresentationStatus,
    show_git_status: bool,
    show_git_graph: bool,
    show_files: bool,

    pub fn canShow(self: ProjectPanelPresentationRequest) bool {
        return self.status == .show_requested;
    }

    pub fn hasPanelData(self: ProjectPanelPresentationRequest) bool {
        return self.show_git_status or self.show_git_graph or self.show_files;
    }
};

pub const ProjectPanelPresentationReceipt = struct {
    status: ProjectPanelPresentationStatus,

    pub fn completed(self: ProjectPanelPresentationReceipt) bool {
        return switch (self.status) {
            .shown, .dismissed, .failed => true,
            .hidden, .show_requested => false,
        };
    }
};

pub const ProjectPanelActionTransport = enum {
    unavailable,
    native_workspace_action,
};

pub const ProjectPanelActionStatus = enum {
    not_requested,
    unavailable,
    pending,
    completed,
    denied,
    failed,
};

pub const ProjectPanelActionRequest = struct {
    activation: Workspace.ProjectPanelActivation,
    transport: ProjectPanelActionTransport,
    status: ProjectPanelActionStatus,

    pub fn canDispatch(self: ProjectPanelActionRequest) bool {
        return self.transport != .unavailable and self.status == .pending;
    }
};

pub const ProjectPanelActionReceipt = struct {
    source: Workspace.ProjectPanelActivationRequest,
    kind: Workspace.ProjectPanelActivationKind,
    transport: ProjectPanelActionTransport,
    status: ProjectPanelActionStatus,

    pub fn completed(self: ProjectPanelActionReceipt) bool {
        return switch (self.status) {
            .completed, .denied, .failed, .unavailable => true,
            .not_requested, .pending => false,
        };
    }
};

const ProjectPanelActionTracker = struct {
    source: Workspace.ProjectPanelActivationRequest,
    kind: Workspace.ProjectPanelActivationKind,
    transport: ProjectPanelActionTransport,
};

pub const SessionEnvironment = struct {
    wayland_display: ?[]const u8 = null,
    display: ?[]const u8 = null,
    current_desktop: ?[]const u8 = null,
    session_desktop: ?[]const u8 = null,
    xdg_session_type: ?[]const u8 = null,
    kde_full_session: bool = false,
    shell_override: ?[]const u8 = null,
    compositor_override: ?[]const u8 = null,
    noctalia_version: ?[]const u8 = null,
    niri_socket: ?[]const u8 = null,
    hyprland_instance_signature: ?[]const u8 = null,
    sway_socket: ?[]const u8 = null,
    labwc_pid: ?[]const u8 = null,
    mango_socket: ?[]const u8 = null,

    pub fn isPlasma(self: SessionEnvironment) bool {
        if (self.kde_full_session) return true;
        if (self.current_desktop) |desktop| {
            return containsIgnoreCase(desktop, "KDE") or containsIgnoreCase(desktop, "PLASMA");
        }
        return false;
    }

    pub fn noctaliaDetection(self: SessionEnvironment) Noctalia.Detection {
        return Noctalia.detect(.{
            .wayland_display = self.wayland_display,
            .current_desktop = self.current_desktop,
            .session_desktop = self.session_desktop,
            .compositor_override = self.compositor_override,
            .shell_override = self.shell_override,
            .noctalia_version = self.noctalia_version,
            .niri_socket = self.niri_socket,
            .hyprland_instance_signature = self.hyprland_instance_signature,
            .sway_socket = self.sway_socket,
            .labwc_pid = self.labwc_pid,
            .mango_socket = self.mango_socket,
        });
    }
};

pub const NativeHost = struct {
    config: Config.Config,
    backend: Backend.Descriptor,
    screen: Screen,
    window: WindowState,
    shortcut_recorder: ShortcutRecorder = .{},
    last_resize_preview: ?ResizePreview = null,
    last_notification: ?NotificationRequest = null,
    notification_count: usize = 0,
    notification_delivery_status: NotificationDeliveryStatus = .not_requested,
    notification_transport: NotificationTransport = .unavailable,
    last_clipboard_transfer: ?ClipboardTransferRequest = null,
    clipboard_transfer_status: ClipboardTransferStatus = .not_requested,
    clipboard_transfer_transport: ClipboardTransport = .unavailable,
    clipboard_transfer_operation: ClipboardOperation = .read,
    clipboard_transfer_selection: ClipboardSelection = .clipboard,
    last_paste_delivery: ?PasteDeliveryRequest = null,
    paste_delivery_status: PasteDeliveryStatus = .not_requested,
    paste_delivery_pane_id: ?Terminal.PaneId = null,
    last_status_tooltip: ?StatusTooltipRequest = null,
    status_tooltip_status: StatusTooltipStatus = .hidden,
    status_tooltip_tab_id: ?u64 = null,
    last_profile_preset_menu: ?ProfilePresetMenuRequest = null,
    profile_preset_menu_status: ProfilePresetMenuStatus = .hidden,
    profile_preset_menu_pane_id: ?Terminal.PaneId = null,
    profile_preset_menu_selected: ?Terminal.ProfilePreset = null,
    workspace_file_dialog_status: WorkspaceFileDialogStatus = .not_requested,
    workspace_file_dialog_transport: WorkspaceFileDialogTransport = .unavailable,
    workspace_file_dialog_operation: ?WorkspaceFileDialogOperation = null,
    last_project_panel: ?ProjectPanelPresentationRequest = null,
    project_panel_status: ProjectPanelPresentationStatus = .hidden,
    last_project_panel_action: ?ProjectPanelActionTracker = null,
    project_panel_action_status: ProjectPanelActionStatus = .not_requested,
    project_panel_action_transport: ProjectPanelActionTransport = .unavailable,
    shortcut_registration_status: ShortcutRegistrationStatus = .not_requested,
    shortcut_registration_transport: ShortcutRegistrationTransport = .unavailable,
    window_lifecycle_status: WindowLifecycleStatus = .not_requested,
    window_lifecycle_protocol: PresentationProtocol = .unavailable,
    window_lifecycle_trigger: PresentationTrigger = .startup,
    window_transport_id: ?u64 = null,

    pub fn init(config: Config.Config, backend: Backend.Descriptor, screen: Screen) NativeHost {
        return .{
            .config = config,
            .backend = backend,
            .screen = screen,
            .window = initialWindow(config, screen),
        };
    }

    pub fn fromEnvironment(config: Config.Config, env: SessionEnvironment, screen: Screen) NativeHost {
        return init(config, backendForEnvironment(env), screen);
    }

    pub fn setMode(self: *NativeHost, mode: Config.WindowMode) void {
        self.window.mode = mode;
        self.window.visible = true;
        self.window.fullscreen = mode == .zen_fullscreen;
        self.window.rect = rectForMode(mode, self.config, self.screen);
    }

    pub fn toggleDropdown(self: *NativeHost) void {
        if (self.window.mode == .dropdown and self.window.visible) {
            self.window.visible = false;
            return;
        }
        self.setMode(.dropdown);
    }

    pub fn beginShortcutRecording(self: *NativeHost) void {
        self.shortcut_recorder.begin();
    }

    pub fn captureShortcut(self: *NativeHost, event: Config.KeyEvent) !Config.Shortcut {
        const shortcut = try self.shortcut_recorder.capture(event);
        self.config.dropdown.shortcut = shortcut;
        self.resetShortcutRegistration();
        return shortcut;
    }

    pub fn previewResize(self: *NativeHost, width_px: u32, height_px: u32, cell_width_px: u32, cell_height_px: u32) !ResizePreview {
        if (cell_width_px == 0 or cell_height_px == 0) return error.InvalidCellSize;
        const cols = @max(1, width_px / cell_width_px);
        const rows = @max(1, height_px / cell_height_px);
        const preview = ResizePreview{
            .width_px = width_px,
            .height_px = height_px,
            .cols = @intCast(@min(cols, std.math.maxInt(u16))),
            .rows = @intCast(@min(rows, std.math.maxInt(u16))),
        };
        self.last_resize_preview = preview;
        return preview;
    }

    pub fn queueStatusNotification(self: *NativeHost, pane_id: Terminal.PaneId, status: Terminal.TerminalStatus, enabled: bool) ?NotificationRequest {
        if (!enabled or !self.backend.capabilities.desktop_notifications) return null;
        const reason = notificationReasonForStatus(status) orelse return null;
        const request = NotificationRequest{
            .pane_id = pane_id,
            .status = status,
            .reason = reason,
            .urgency = if (status == .@"error") .critical else .normal,
        };
        self.last_notification = request;
        self.notification_count += 1;
        self.resetNotificationDelivery();
        return request;
    }

    pub fn notificationDeliveryRequest(self: NativeHost) NotificationDeliveryRequest {
        const transport = notificationTransportFor(self.backend);
        const status: NotificationDeliveryStatus = if (self.last_notification == null)
            .not_requested
        else if (transport == .unavailable)
            .unavailable
        else
            .pending;
        return .{
            .notification = self.last_notification,
            .transport = transport,
            .status = status,
        };
    }

    pub fn beginNotificationDelivery(self: *NativeHost) NotificationDeliveryRequest {
        const request = self.notificationDeliveryRequest();
        self.notification_transport = request.transport;
        self.notification_delivery_status = request.status;
        return request;
    }

    pub fn applyNotificationDeliveryReceipt(self: *NativeHost, receipt: NotificationDeliveryReceipt) !NotificationDeliveryStatus {
        if (!receipt.completed()) return error.InvalidNotificationDeliveryReceipt;

        const expected = self.notificationDeliveryRequest();
        const expected_notification = expected.notification orelse return error.NotificationDeliveryMismatch;
        if (!notificationRequestEql(receipt.request, expected_notification)) return error.NotificationDeliveryMismatch;
        if (receipt.transport != expected.transport) return error.NotificationDeliveryTransportMismatch;

        self.notification_transport = receipt.transport;
        self.notification_delivery_status = receipt.status;
        return self.notification_delivery_status;
    }

    pub fn clipboardTransferRequest(
        self: NativeHost,
        operation: ClipboardOperation,
        selection: ClipboardSelection,
        bytes: usize,
    ) !ClipboardTransferRequest {
        if (operation == .read and bytes != 0) return error.InvalidClipboardTransfer;
        if (operation == .write and bytes == 0) return error.EmptyClipboardTransfer;
        const transport = clipboardTransportFor(self.backend);
        return .{
            .operation = operation,
            .selection = selection,
            .transport = transport,
            .status = if (transport == .unavailable) .unavailable else .pending,
            .bytes = bytes,
        };
    }

    pub fn beginClipboardTransfer(
        self: *NativeHost,
        operation: ClipboardOperation,
        selection: ClipboardSelection,
        bytes: usize,
    ) !ClipboardTransferRequest {
        const request = try self.clipboardTransferRequest(operation, selection, bytes);
        self.last_clipboard_transfer = request;
        self.clipboard_transfer_status = request.status;
        self.clipboard_transfer_transport = request.transport;
        self.clipboard_transfer_operation = request.operation;
        self.clipboard_transfer_selection = request.selection;
        return request;
    }

    pub fn applyClipboardTransferReceipt(self: *NativeHost, receipt: ClipboardTransferReceipt) !ClipboardTransferStatus {
        if (!receipt.completed()) return error.InvalidClipboardTransferReceipt;
        const expected = self.last_clipboard_transfer orelse return error.ClipboardTransferMismatch;
        if (receipt.operation != expected.operation or receipt.selection != expected.selection) return error.ClipboardTransferMismatch;
        if (receipt.transport != expected.transport) return error.ClipboardTransferTransportMismatch;
        if (receipt.status != .completed and receipt.bytes != 0) return error.InvalidClipboardTransferReceipt;
        if (expected.operation == .write and receipt.status == .completed and receipt.bytes != expected.bytes) return error.ClipboardTransferMismatch;

        self.clipboard_transfer_status = receipt.status;
        self.clipboard_transfer_transport = receipt.transport;
        self.clipboard_transfer_operation = receipt.operation;
        self.clipboard_transfer_selection = receipt.selection;
        return self.clipboard_transfer_status;
    }

    pub fn pasteDeliveryRequest(
        self: NativeHost,
        pane_id: Terminal.PaneId,
        bytes: usize,
        bracketed: bool,
        policy: Paste.PastePolicy,
    ) !PasteDeliveryRequest {
        _ = self;
        if (bytes == 0) return error.EmptyPasteDelivery;
        return .{
            .pane_id = pane_id,
            .bytes = bytes,
            .bracketed = bracketed,
            .policy = policy,
            .status = .pending,
        };
    }

    pub fn beginPasteDelivery(
        self: *NativeHost,
        pane_id: Terminal.PaneId,
        bytes: usize,
        bracketed: bool,
        policy: Paste.PastePolicy,
    ) !PasteDeliveryRequest {
        const request = try self.pasteDeliveryRequest(pane_id, bytes, bracketed, policy);
        self.last_paste_delivery = request;
        self.paste_delivery_status = request.status;
        self.paste_delivery_pane_id = request.pane_id;
        return request;
    }

    pub fn applyPasteDeliveryReceipt(self: *NativeHost, receipt: PasteDeliveryReceipt) !PasteDeliveryStatus {
        if (!receipt.completed()) return error.InvalidPasteDeliveryReceipt;
        const expected = self.last_paste_delivery orelse return error.PasteDeliveryMismatch;
        if (receipt.pane_id != expected.pane_id) return error.PasteDeliveryMismatch;
        if (receipt.status == .delivered and receipt.bytes != expected.bytes) return error.PasteDeliveryMismatch;
        if (receipt.status != .delivered and receipt.bytes != 0) return error.InvalidPasteDeliveryReceipt;

        self.paste_delivery_status = receipt.status;
        if (receipt.status == .delivered or receipt.status == .failed or receipt.status == .unavailable) {
            self.paste_delivery_pane_id = null;
        }
        return self.paste_delivery_status;
    }

    pub fn statusTooltipRequest(self: NativeHost, tab_id: u64, summary: Workspace.TabStatusSummary, details_enabled: bool) StatusTooltipRequest {
        _ = self;
        return .{
            .tab_id = tab_id,
            .summary = summary,
            .details_enabled = details_enabled,
            .status = if (details_enabled) .show_requested else .disabled,
        };
    }

    pub fn beginStatusTooltip(self: *NativeHost, tab_id: u64, summary: Workspace.TabStatusSummary, details_enabled: bool) StatusTooltipRequest {
        const request = self.statusTooltipRequest(tab_id, summary, details_enabled);
        self.last_status_tooltip = request;
        self.status_tooltip_status = request.status;
        self.status_tooltip_tab_id = tab_id;
        return request;
    }

    pub fn applyStatusTooltipReceipt(self: *NativeHost, receipt: StatusTooltipReceipt) !StatusTooltipStatus {
        if (!receipt.completed()) return error.InvalidStatusTooltipReceipt;
        if (self.status_tooltip_tab_id == null or self.status_tooltip_tab_id.? != receipt.tab_id) return error.StatusTooltipMismatch;

        self.status_tooltip_status = receipt.status;
        if (receipt.status == .dismissed or receipt.status == .failed) {
            self.status_tooltip_tab_id = null;
        }
        return self.status_tooltip_status;
    }

    pub fn hideStatusTooltip(self: *NativeHost) StatusTooltipStatus {
        self.last_status_tooltip = null;
        self.status_tooltip_tab_id = null;
        self.status_tooltip_status = .hidden;
        return self.status_tooltip_status;
    }

    pub fn profilePresetMenuRequest(self: NativeHost, pane_id: Terminal.PaneId, current_profile: Terminal.TerminalProfile) !ProfilePresetMenuRequest {
        var request = ProfilePresetMenuRequest{
            .pane_id = pane_id,
            .current_profile = current_profile,
            .status = .show_requested,
        };
        for (profile_preset_menu_order) |preset| {
            const profile = preset.profile(self.config);
            try profile.validate(self.config.font);
            request.items[request.item_count] = .{
                .preset = preset,
                .profile = profile,
                .current = profileEql(current_profile, profile),
            };
            request.item_count += 1;
        }
        return request;
    }

    pub fn beginProfilePresetMenu(self: *NativeHost, pane_id: Terminal.PaneId, current_profile: Terminal.TerminalProfile) !ProfilePresetMenuRequest {
        const request = try self.profilePresetMenuRequest(pane_id, current_profile);
        self.last_profile_preset_menu = request;
        self.profile_preset_menu_status = request.status;
        self.profile_preset_menu_pane_id = pane_id;
        self.profile_preset_menu_selected = null;
        return request;
    }

    pub fn applyProfilePresetMenuReceipt(self: *NativeHost, receipt: ProfilePresetMenuReceipt) !ProfilePresetMenuStatus {
        if (!receipt.completed()) return error.InvalidProfilePresetMenuReceipt;
        if (self.profile_preset_menu_pane_id == null or self.profile_preset_menu_pane_id.? != receipt.pane_id) return error.ProfilePresetMenuMismatch;
        if (receipt.status == .selected) {
            const preset = receipt.selected_preset orelse return error.InvalidProfilePresetMenuReceipt;
            const request = self.last_profile_preset_menu orelse return error.ProfilePresetMenuMismatch;
            if (!request.containsPreset(preset)) return error.ProfilePresetMenuMismatch;
            self.profile_preset_menu_selected = preset;
        } else if (receipt.selected_preset != null) {
            return error.InvalidProfilePresetMenuReceipt;
        } else {
            self.profile_preset_menu_selected = null;
        }

        self.profile_preset_menu_status = receipt.status;
        if (receipt.status == .selected or receipt.status == .dismissed or receipt.status == .failed or receipt.status == .unavailable) {
            self.profile_preset_menu_pane_id = null;
        }
        return self.profile_preset_menu_status;
    }

    pub fn hideProfilePresetMenu(self: *NativeHost) ProfilePresetMenuStatus {
        self.last_profile_preset_menu = null;
        self.profile_preset_menu_pane_id = null;
        self.profile_preset_menu_selected = null;
        self.profile_preset_menu_status = .hidden;
        return self.profile_preset_menu_status;
    }

    pub fn workspaceFileDialogRequest(
        self: NativeHost,
        operation: WorkspaceFileDialogOperation,
        suggested_path: []const u8,
    ) !WorkspaceFileDialogRequest {
        if (suggested_path.len == 0) return error.InvalidWorkspaceFileDialogPath;
        const transport = workspaceFileDialogTransportFor(self.backend);
        return .{
            .operation = operation,
            .suggested_path = suggested_path,
            .transport = transport,
            .status = if (transport == .unavailable) .unavailable else .pending,
        };
    }

    pub fn beginWorkspaceFileDialog(
        self: *NativeHost,
        operation: WorkspaceFileDialogOperation,
        suggested_path: []const u8,
    ) !WorkspaceFileDialogRequest {
        const request = try self.workspaceFileDialogRequest(operation, suggested_path);
        self.workspace_file_dialog_operation = request.operation;
        self.workspace_file_dialog_transport = request.transport;
        self.workspace_file_dialog_status = request.status;
        return request;
    }

    pub fn applyWorkspaceFileDialogReceipt(self: *NativeHost, receipt: WorkspaceFileDialogReceipt) !WorkspaceFileDialogStatus {
        if (!receipt.completed()) return error.InvalidWorkspaceFileDialogReceipt;
        const operation = self.workspace_file_dialog_operation orelse return error.WorkspaceFileDialogMismatch;
        if (receipt.operation != operation) return error.WorkspaceFileDialogMismatch;
        if (receipt.transport != self.workspace_file_dialog_transport) return error.WorkspaceFileDialogTransportMismatch;
        if (receipt.status == .selected) {
            const path = receipt.selected_path orelse return error.InvalidWorkspaceFileDialogReceipt;
            if (path.len == 0) return error.InvalidWorkspaceFileDialogReceipt;
        } else if (receipt.selected_path != null) {
            return error.InvalidWorkspaceFileDialogReceipt;
        }

        self.workspace_file_dialog_status = receipt.status;
        if (receipt.status == .selected or receipt.status == .canceled or receipt.status == .failed or receipt.status == .unavailable) {
            self.workspace_file_dialog_operation = null;
        }
        return self.workspace_file_dialog_status;
    }

    pub fn projectPanelPresentationRequest(self: NativeHost, summary: Workspace.ProjectPanelSummary) ProjectPanelPresentationRequest {
        _ = self;
        return .{
            .summary = summary,
            .status = .show_requested,
            .show_git_status = summary.git_status_count > 0,
            .show_git_graph = summary.git_graph_count > 0,
            .show_files = summary.file_entry_count > 0,
        };
    }

    pub fn beginProjectPanelPresentation(self: *NativeHost, summary: Workspace.ProjectPanelSummary) ProjectPanelPresentationRequest {
        const request = self.projectPanelPresentationRequest(summary);
        self.last_project_panel = request;
        self.project_panel_status = request.status;
        return request;
    }

    pub fn applyProjectPanelPresentationReceipt(self: *NativeHost, receipt: ProjectPanelPresentationReceipt) !ProjectPanelPresentationStatus {
        if (!receipt.completed()) return error.InvalidProjectPanelPresentationReceipt;
        _ = self.last_project_panel orelse return error.ProjectPanelPresentationMismatch;

        self.project_panel_status = receipt.status;
        if (receipt.status == .dismissed or receipt.status == .failed) {
            self.last_project_panel = null;
        }
        return self.project_panel_status;
    }

    pub fn hideProjectPanelPresentation(self: *NativeHost) ProjectPanelPresentationStatus {
        self.last_project_panel = null;
        self.project_panel_status = .hidden;
        return self.project_panel_status;
    }

    pub fn projectPanelActionRequest(self: NativeHost, activation: Workspace.ProjectPanelActivation) ProjectPanelActionRequest {
        const transport = projectPanelActionTransportFor(self.backend);
        return .{
            .activation = activation,
            .transport = transport,
            .status = if (transport == .unavailable) .unavailable else .pending,
        };
    }

    pub fn beginProjectPanelAction(self: *NativeHost, activation: Workspace.ProjectPanelActivation) ProjectPanelActionRequest {
        const request = self.projectPanelActionRequest(activation);
        self.last_project_panel_action = .{
            .source = activation.source,
            .kind = activation.kind,
            .transport = request.transport,
        };
        self.project_panel_action_status = request.status;
        self.project_panel_action_transport = request.transport;
        return request;
    }

    pub fn applyProjectPanelActionReceipt(self: *NativeHost, receipt: ProjectPanelActionReceipt) !ProjectPanelActionStatus {
        if (!receipt.completed()) return error.InvalidProjectPanelActionReceipt;
        const expected = self.last_project_panel_action orelse return error.ProjectPanelActionMismatch;
        if (receipt.source.kind != expected.source.kind or receipt.source.source_index != expected.source.source_index or receipt.kind != expected.kind) {
            return error.ProjectPanelActionMismatch;
        }
        if (receipt.transport != expected.transport) return error.ProjectPanelActionTransportMismatch;

        self.project_panel_action_status = receipt.status;
        self.project_panel_action_transport = receipt.transport;
        self.last_project_panel_action = null;
        return self.project_panel_action_status;
    }

    pub fn launchPlan(self: NativeHost) LaunchPlan {
        const activation_window = dropdownActivationWindow(self.window, self.config, self.screen);
        const readiness = launchReadiness(self.backend);
        return .{
            .backend = self.backend.kind,
            .readiness = readiness,
            .initial_surface = surfaceIntentForWindow(self.window, readiness),
            .shortcut_activation_surface = surfaceIntentForWindow(activation_window, readiness),
            .initial_rect = self.window.rect,
            .shortcut_activation_rect = activation_window.rect,
            .chrome = self.backend.chrome,
            .shortcut = self.config.dropdown.shortcut,
            .register_global_shortcut = self.backend.capabilities.app_shortcut_registration,
            .use_layer_shell = self.backend.capabilities.layer_shell and self.window.mode == .dropdown,
            .use_desktop_notifications = self.backend.capabilities.desktop_notifications and self.config.status.desktop_notifications,
            .use_external_activation = self.backend.capabilities.external_activation,
            .use_drag_and_drop = self.backend.capabilities.drag_and_drop,
            .hidpi = self.backend.capabilities.hidpi and self.config.font.hidpi,
        };
    }

    pub fn presentationPlan(self: NativeHost, trigger: PresentationTrigger) PresentationPlan {
        const target_window = switch (trigger) {
            .startup => self.window,
            .shortcut_activation => dropdownActivationWindow(self.window, self.config, self.screen),
        };
        return presentationPlanForWindow(self, trigger, target_window);
    }

    pub fn windowLifecycleRequest(self: NativeHost, trigger: PresentationTrigger) WindowLifecycleRequest {
        const plan = self.presentationPlan(trigger);
        return .{
            .trigger = trigger,
            .protocol = plan.protocol,
            .target_surface = plan.target_surface,
            .target_rect = plan.target_rect,
            .status = if (plan.hasTransportWork()) .create_requested else .unavailable,
        };
    }

    pub fn beginWindowLifecycle(self: *NativeHost, trigger: PresentationTrigger) WindowLifecycleRequest {
        const request = self.windowLifecycleRequest(trigger);
        self.window_lifecycle_trigger = request.trigger;
        self.window_lifecycle_protocol = request.protocol;
        self.window_lifecycle_status = request.status;
        if (request.status == .unavailable) self.window_transport_id = null;
        return request;
    }

    pub fn applyWindowLifecycleReceipt(self: *NativeHost, receipt: WindowLifecycleReceipt) !WindowLifecycleStatus {
        if (!receipt.completed()) return error.InvalidWindowLifecycleReceipt;
        if (receipt.trigger != self.window_lifecycle_trigger) return error.WindowLifecycleMismatch;
        if (receipt.protocol != self.window_lifecycle_protocol) return error.WindowLifecycleTransportMismatch;

        const expected = self.windowLifecycleRequest(receipt.trigger);
        if (receipt.protocol != expected.protocol or
            receipt.target_surface != expected.target_surface or
            !rectEql(receipt.target_rect, expected.target_rect))
        {
            return error.WindowLifecycleMismatch;
        }

        self.window_lifecycle_status = receipt.status;
        switch (receipt.status) {
            .created => {
                self.window_transport_id = receipt.window_id;
            },
            .shown => {
                self.window_transport_id = receipt.window_id;
                self.window.mode = modeForSurface(receipt.target_surface) orelse self.window.mode;
                self.window.visible = true;
                self.window.fullscreen = receipt.target_surface == .visible_fullscreen;
                self.window.rect = receipt.target_rect;
            },
            .hidden => {
                self.window_transport_id = receipt.window_id;
                self.window.mode = .dropdown;
                self.window.visible = false;
                self.window.fullscreen = false;
                self.window.rect = receipt.target_rect;
            },
            .destroyed, .failed, .unavailable => {
                self.window_transport_id = null;
            },
            .not_requested, .create_requested => unreachable,
        }
        return self.window_lifecycle_status;
    }

    pub fn shortcutRegistrationRequest(self: NativeHost) ShortcutRegistrationRequest {
        const transport = shortcutRegistrationTransportFor(self.backend);
        return .{
            .shortcut = self.config.dropdown.shortcut,
            .transport = transport,
            .status = if (transport == .unavailable) .unavailable else .pending,
        };
    }

    pub fn beginShortcutRegistration(self: *NativeHost) ShortcutRegistrationRequest {
        const request = self.shortcutRegistrationRequest();
        self.shortcut_registration_transport = request.transport;
        self.shortcut_registration_status = request.status;
        return request;
    }

    pub fn applyShortcutRegistrationReceipt(self: *NativeHost, receipt: ShortcutRegistrationReceipt) !ShortcutRegistrationStatus {
        if (!shortcutEql(receipt.shortcut, self.config.dropdown.shortcut)) return error.ShortcutRegistrationMismatch;
        if (!receipt.completed()) return error.InvalidShortcutRegistrationReceipt;

        const expected_transport = shortcutRegistrationTransportFor(self.backend);
        if (receipt.transport != expected_transport) return error.ShortcutRegistrationTransportMismatch;

        self.shortcut_registration_transport = receipt.transport;
        self.shortcut_registration_status = receipt.status;
        return self.shortcut_registration_status;
    }

    pub fn resetShortcutRegistration(self: *NativeHost) void {
        self.shortcut_registration_status = .not_requested;
        self.shortcut_registration_transport = .unavailable;
    }

    pub fn resetNotificationDelivery(self: *NativeHost) void {
        self.notification_delivery_status = .not_requested;
        self.notification_transport = .unavailable;
    }
};

pub fn notificationReasonForStatus(status: Terminal.TerminalStatus) ?NotificationReason {
    return switch (status) {
        .done => .completed,
        .@"error" => .failed,
        .pending_interaction => .pending_interaction,
        .long_running => .long_running,
        .idle, .running => null,
    };
}

pub fn backendForEnvironment(env: SessionEnvironment) Backend.Descriptor {
    if (env.wayland_display != null or stringEqlIgnoreCase(env.xdg_session_type, "wayland")) {
        if (!env.isPlasma()) {
            const detection = env.noctaliaDetection();
            if (detection.supported()) return Backend.Descriptor.noctaliaFor(detection.compositor);
            return Backend.Descriptor.genericWayland(detection.compositor);
        }
        var descriptor = Backend.Descriptor.preferredForLinux();
        descriptor.capabilities.wayland = true;
        descriptor.capabilities.x11 = env.display != null;
        return descriptor;
    }
    var descriptor = Backend.Descriptor.preferredForLinux();
    if (env.display != null or stringEqlIgnoreCase(env.xdg_session_type, "x11")) {
        descriptor.kind = .x11;
        descriptor.shell = if (env.isPlasma()) .plasma else .other;
        descriptor.compositor = .none;
        descriptor.capabilities.wayland = false;
        descriptor.capabilities.x11 = true;
        descriptor.capabilities.layer_shell = false;
    } else {
        descriptor.kind = .portable_test;
        descriptor.shell = .other;
        descriptor.compositor = .none;
        descriptor.capabilities.wayland = false;
        descriptor.capabilities.x11 = false;
        descriptor.capabilities.global_shortcuts = false;
        descriptor.capabilities.app_shortcut_registration = false;
        descriptor.capabilities.external_activation = false;
        descriptor.capabilities.desktop_notifications = false;
        descriptor.capabilities.layer_shell = false;
        descriptor.capabilities.drag_and_drop = false;
    }

    if (!env.isPlasma()) {
        descriptor.capabilities.global_shortcuts = false;
        descriptor.capabilities.app_shortcut_registration = false;
    }
    return descriptor;
}

pub fn rectForMode(mode: Config.WindowMode, config: Config.Config, screen: Screen) Rect {
    return switch (mode) {
        .dropdown => .{
            .x = screen.x,
            .y = screen.y,
            .width_px = if (config.dropdown.width_px > 0)
                @min(screen.width_px, @as(u32, config.dropdown.width_px))
            else
                percentOf(screen.width_px, config.dropdown.width_percent),
            .height_px = if (config.dropdown.height_px > 0)
                @min(screen.height_px, @as(u32, config.dropdown.height_px))
            else
                percentOf(screen.height_px, config.dropdown.height_percent),
        },
        .windowed => .{
            .x = screen.x + @as(i32, @intCast(screen.width_px / 10)),
            .y = screen.y + @as(i32, @intCast(screen.height_px / 10)),
            .width_px = percentOf(screen.width_px, 80),
            .height_px = percentOf(screen.height_px, 75),
        },
        .zen_fullscreen => .{
            .x = screen.x,
            .y = screen.y,
            .width_px = screen.width_px,
            .height_px = screen.height_px,
        },
    };
}

fn initialWindow(config: Config.Config, screen: Screen) WindowState {
    return .{
        .mode = config.default_mode,
        .visible = config.default_mode != .dropdown,
        .rect = rectForMode(config.default_mode, config, screen),
        .fullscreen = config.default_mode == .zen_fullscreen,
    };
}

fn dropdownActivationWindow(window: WindowState, config: Config.Config, screen: Screen) WindowState {
    if (window.mode == .dropdown and window.visible) {
        return .{
            .mode = .dropdown,
            .visible = false,
            .rect = rectForMode(.dropdown, config, screen),
            .fullscreen = false,
        };
    }
    return .{
        .mode = .dropdown,
        .visible = true,
        .rect = rectForMode(.dropdown, config, screen),
        .fullscreen = false,
    };
}

fn presentationPlanForWindow(host: NativeHost, trigger: PresentationTrigger, window: WindowState) PresentationPlan {
    const readiness = launchReadiness(host.backend);
    const target_surface = surfaceIntentForWindow(window, readiness);
    var plan = PresentationPlan{
        .trigger = trigger,
        .protocol = presentationProtocolFor(host.backend, target_surface),
        .readiness = readiness,
        .target_surface = target_surface,
        .target_rect = window.rect,
    };

    if (plan.protocol == .unavailable or plan.target_surface == .unavailable) return plan;

    plan.appendAction(.create_surface);
    plan.appendAction(.configure_zero_chrome);
    switch (plan.protocol) {
        .wayland_layer_shell => plan.appendAction(.configure_layer_shell),
        .wayland_toplevel => plan.appendAction(.configure_wayland_toplevel),
        .x11_ewmh => plan.appendAction(.configure_x11_ewmh),
        .unavailable => unreachable,
    }
    plan.appendAction(.set_window_rect);

    if (trigger == .startup and host.backend.capabilities.global_shortcuts) {
        if (host.backend.capabilities.app_shortcut_registration)
            plan.appendAction(.register_global_shortcut);
    }
    if (trigger == .startup and host.backend.capabilities.external_activation)
        plan.appendAction(.bind_external_activation);
    if (host.backend.capabilities.drag_and_drop) {
        plan.appendAction(.enable_drag_and_drop);
    }
    if (host.backend.capabilities.desktop_notifications and host.config.status.desktop_notifications) {
        plan.appendAction(.bind_desktop_notifications);
    }

    switch (plan.target_surface) {
        .hidden_dropdown => plan.appendAction(.hide_surface),
        .visible_dropdown, .visible_windowed => plan.appendAction(.show_surface),
        .visible_fullscreen => {
            plan.appendAction(.enter_fullscreen);
            plan.appendAction(.show_surface);
        },
        .unavailable => unreachable,
    }
    return plan;
}

fn presentationProtocolFor(backend: Backend.Descriptor, target_surface: SurfaceIntent) PresentationProtocol {
    if (target_surface == .unavailable) return .unavailable;
    if (target_surface == .visible_dropdown or target_surface == .hidden_dropdown) {
        if (backend.capabilities.wayland and backend.capabilities.layer_shell) return .wayland_layer_shell;
    }
    if (backend.capabilities.wayland) return .wayland_toplevel;
    if (backend.capabilities.x11) return .x11_ewmh;
    return .unavailable;
}

fn shortcutRegistrationTransportFor(backend: Backend.Descriptor) ShortcutRegistrationTransport {
    if (!backend.capabilities.global_shortcuts) return .unavailable;
    return switch (backend.kind) {
        .plasma_wayland => .kde_global_accel,
        .noctalia_wayland => .compositor_binding,
        .wayland => .unavailable,
        .x11 => if (backend.capabilities.app_shortcut_registration) .kde_global_accel else .x11_grab_key,
        .portable_test => .unavailable,
    };
}

fn notificationTransportFor(backend: Backend.Descriptor) NotificationTransport {
    return if (backend.capabilities.desktop_notifications) .freedesktop_dbus else .unavailable;
}

fn clipboardTransportFor(backend: Backend.Descriptor) ClipboardTransport {
    if (backend.capabilities.wayland) return .wayland_data_control;
    if (backend.capabilities.x11) return .x11_selection;
    return .unavailable;
}

fn workspaceFileDialogTransportFor(backend: Backend.Descriptor) WorkspaceFileDialogTransport {
    return switch (backend.kind) {
        .plasma_wayland => if (backend.capabilities.wayland or backend.capabilities.x11) .gtk_native_dialog else .unavailable,
        .noctalia_wayland, .wayland => if (backend.capabilities.wayland) .gtk_native_dialog else .unavailable,
        .x11 => if (backend.capabilities.x11) .gtk_native_dialog else .unavailable,
        .portable_test => .unavailable,
    };
}

fn projectPanelActionTransportFor(backend: Backend.Descriptor) ProjectPanelActionTransport {
    if (backend.capabilities.wayland or backend.capabilities.x11) return .native_workspace_action;
    return .unavailable;
}

const profile_preset_menu_order = [_]Terminal.ProfilePreset{
    .global_default,
    .compact,
    .readable,
    .high_contrast,
    .mono_no_ligatures,
};

fn modeForSurface(surface: SurfaceIntent) ?Config.WindowMode {
    return switch (surface) {
        .visible_dropdown, .hidden_dropdown => .dropdown,
        .visible_windowed => .windowed,
        .visible_fullscreen => .zen_fullscreen,
        .unavailable => null,
    };
}

fn launchReadiness(backend: Backend.Descriptor) LaunchReadiness {
    if (!backend.capabilities.wayland and !backend.capabilities.x11) return .unavailable;
    if (!backend.capabilities.global_shortcuts or !backend.capabilities.desktop_notifications) return .degraded;
    return .ready;
}

fn surfaceIntentForWindow(window: WindowState, readiness: LaunchReadiness) SurfaceIntent {
    if (readiness == .unavailable) return .unavailable;
    return switch (window.mode) {
        .dropdown => if (window.visible) .visible_dropdown else .hidden_dropdown,
        .windowed => .visible_windowed,
        .zen_fullscreen => .visible_fullscreen,
    };
}

fn percentOf(value: u32, percent: u8) u32 {
    return @intCast((@as(u64, value) * percent) / 100);
}

fn containsIgnoreCase(haystack: []const u8, needle: []const u8) bool {
    if (needle.len == 0) return true;
    if (needle.len > haystack.len) return false;
    var i: usize = 0;
    while (i + needle.len <= haystack.len) : (i += 1) {
        if (std.ascii.eqlIgnoreCase(haystack[i .. i + needle.len], needle)) return true;
    }
    return false;
}

fn stringEqlIgnoreCase(value: ?[]const u8, expected: []const u8) bool {
    return if (value) |actual| std.ascii.eqlIgnoreCase(actual, expected) else false;
}

fn shortcutEql(lhs: Config.Shortcut, rhs: Config.Shortcut) bool {
    return lhs.key == rhs.key and
        lhs.ctrl == rhs.ctrl and
        lhs.shift == rhs.shift and
        lhs.alt == rhs.alt and
        lhs.super == rhs.super;
}

fn rectEql(lhs: Rect, rhs: Rect) bool {
    return lhs.x == rhs.x and
        lhs.y == rhs.y and
        lhs.width_px == rhs.width_px and
        lhs.height_px == rhs.height_px;
}

fn notificationRequestEql(lhs: NotificationRequest, rhs: NotificationRequest) bool {
    return lhs.pane_id == rhs.pane_id and
        lhs.status == rhs.status and
        lhs.reason == rhs.reason and
        lhs.urgency == rhs.urgency;
}

fn profileEql(lhs: Terminal.TerminalProfile, rhs: Terminal.TerminalProfile) bool {
    return std.mem.eql(u8, lhs.theme_name, rhs.theme_name) and
        std.mem.eql(u8, lhs.font_family, rhs.font_family) and
        lhs.font_size_pt == rhs.font_size_pt and
        lhs.ligatures == rhs.ligatures;
}

test "environment chooses Plasma Wayland when available" {
    const backend = backendForEnvironment(.{
        .wayland_display = "wayland-0",
        .display = ":0",
        .current_desktop = "KDE",
        .xdg_session_type = "wayland",
    });
    try std.testing.expectEqual(Backend.BackendKind.plasma_wayland, backend.kind);
    try std.testing.expect(backend.capabilities.global_shortcuts);
    try std.testing.expect(backend.capabilities.desktop_notifications);
}

test "environment falls back to X11 without Wayland" {
    const backend = backendForEnvironment(.{
        .display = ":0",
        .current_desktop = "KDE",
        .xdg_session_type = "x11",
    });
    try std.testing.expectEqual(Backend.BackendKind.x11, backend.kind);
    try std.testing.expect(!backend.capabilities.wayland);
    try std.testing.expect(backend.capabilities.x11);
}

test "environment chooses first-class Noctalia backend on supported compositor" {
    const backend = backendForEnvironment(.{
        .wayland_display = "wayland-1",
        .current_desktop = "niri",
        .xdg_session_type = "wayland",
        .niri_socket = "/run/user/1000/niri.sock",
    });
    try std.testing.expectEqual(Backend.BackendKind.noctalia_wayland, backend.kind);
    try std.testing.expectEqual(Backend.DesktopShell.noctalia, backend.shell);
    try std.testing.expectEqual(Backend.WaylandCompositor.niri, backend.compositor);
    try std.testing.expect(backend.capabilities.global_shortcuts);
    try std.testing.expect(!backend.capabilities.app_shortcut_registration);
    try std.testing.expect(backend.capabilities.external_activation);
    try std.testing.expect(backend.capabilities.desktop_notifications);
    try std.testing.expect(!backend.capabilities.layer_shell);

    const host = NativeHost.init(Config.Config.defaults(), backend, .default());
    const plan = host.launchPlan();
    try std.testing.expectEqual(LaunchReadiness.ready, plan.readiness);
    try std.testing.expect(!plan.register_global_shortcut);
    try std.testing.expect(plan.use_external_activation);
    try std.testing.expect(plan.use_desktop_notifications);
    try std.testing.expect(!plan.use_layer_shell);
    try std.testing.expectEqual(ShortcutRegistrationTransport.compositor_binding, host.shortcutRegistrationRequest().transport);
    try std.testing.expectEqual(NotificationTransport.freedesktop_dbus, host.notificationDeliveryRequest().transport);
    const presentation = host.presentationPlan(.startup);
    try std.testing.expect(presentation.containsAction(.bind_external_activation));
    try std.testing.expect(!presentation.containsAction(.register_global_shortcut));
    try std.testing.expectEqual(PresentationProtocol.wayland_toplevel, presentation.protocol);
}

test "dropdown geometry and zen mode are deterministic" {
    const cfg = Config.Config.defaults();
    var host = NativeHost.init(cfg, Backend.Descriptor.preferredForLinux(), .{
        .width_px = 3000,
        .height_px = 2000,
    });
    try std.testing.expectEqual(@as(u32, 2880), host.window.rect.width_px);
    try std.testing.expectEqual(@as(u32, 1100), host.window.rect.height_px);
    try std.testing.expect(!host.window.visible);

    host.toggleDropdown();
    try std.testing.expect(host.window.visible);

    host.setMode(.zen_fullscreen);
    try std.testing.expect(host.window.fullscreen);
    try std.testing.expectEqual(@as(u32, 3000), host.window.rect.width_px);
    try std.testing.expectEqual(@as(u32, 2000), host.window.rect.height_px);
}

test "shortcut recorder stores valid global shortcut" {
    var host = NativeHost.init(Config.Config.defaults(), Backend.Descriptor.preferredForLinux(), .default());
    host.beginShortcutRecording();
    const shortcut = try host.captureShortcut(.{ .key = .t, .ctrl = true, .alt = true });
    try std.testing.expectEqual(Config.Shortcut.Key.t, shortcut.key);
    try std.testing.expect(host.config.dropdown.shortcut.ctrl);
    try std.testing.expect(!host.shortcut_recorder.active);
}

test "resize preview reports terminal cell dimensions" {
    var host = NativeHost.init(Config.Config.defaults(), Backend.Descriptor.preferredForLinux(), .default());
    const preview = try host.previewResize(1000, 600, 10, 20);
    try std.testing.expectEqual(@as(u16, 100), preview.cols);
    try std.testing.expectEqual(@as(u16, 30), preview.rows);
}

test "status notifications are queued only when backend supports desktop notifications" {
    var host = NativeHost.init(Config.Config.defaults(), Backend.Descriptor.preferredForLinux(), .default());
    const request = host.queueStatusNotification(7, .pending_interaction, true).?;
    try std.testing.expectEqual(@as(Terminal.PaneId, 7), request.pane_id);
    try std.testing.expectEqual(NotificationReason.pending_interaction, request.reason);
    try std.testing.expectEqualStrings("Terminal needs input", request.title());
    try std.testing.expectEqual(@as(usize, 1), host.notification_count);

    const running = host.queueStatusNotification(7, .running, true);
    try std.testing.expectEqual(@as(?NotificationRequest, null), running);
    try std.testing.expectEqual(@as(usize, 1), host.notification_count);

    var portable = NativeHost.fromEnvironment(Config.Config.defaults(), .{}, .default());
    const skipped = portable.queueStatusNotification(7, .@"error", true);
    try std.testing.expectEqual(@as(?NotificationRequest, null), skipped);
    try std.testing.expectEqual(@as(usize, 0), portable.notification_count);
}

test "notification delivery request chooses kde dbus and tracks receipts" {
    var host = NativeHost.init(Config.Config.defaults(), Backend.Descriptor.preferredForLinux(), .default());
    const notification = host.queueStatusNotification(7, .pending_interaction, true).?;
    const request = host.beginNotificationDelivery();
    try std.testing.expect(request.canDeliver());
    try std.testing.expectEqual(NotificationTransport.freedesktop_dbus, request.transport);
    try std.testing.expectEqual(NotificationDeliveryStatus.pending, host.notification_delivery_status);
    try std.testing.expect(notificationRequestEql(notification, request.notification.?));

    const status = try host.applyNotificationDeliveryReceipt(.{
        .request = notification,
        .transport = request.transport,
        .status = .delivered,
    });
    try std.testing.expectEqual(NotificationDeliveryStatus.delivered, status);
    try std.testing.expectEqual(NotificationDeliveryStatus.delivered, host.notification_delivery_status);

    _ = host.queueStatusNotification(7, .done, true).?;
    try std.testing.expectEqual(NotificationDeliveryStatus.not_requested, host.notification_delivery_status);
    try std.testing.expectEqual(NotificationTransport.unavailable, host.notification_transport);
}

test "notification delivery reports unavailable and rejects stale receipts" {
    var headless = NativeHost.fromEnvironment(Config.Config.defaults(), .{}, .default());
    const no_notification = headless.beginNotificationDelivery();
    try std.testing.expect(!no_notification.canDeliver());
    try std.testing.expectEqual(NotificationDeliveryStatus.not_requested, no_notification.status);
    try std.testing.expectEqual(NotificationTransport.unavailable, no_notification.transport);

    var host = NativeHost.init(Config.Config.defaults(), Backend.Descriptor.preferredForLinux(), .default());
    const notification = host.queueStatusNotification(7, .pending_interaction, true).?;
    const request = host.beginNotificationDelivery();
    try std.testing.expectError(error.NotificationDeliveryTransportMismatch, host.applyNotificationDeliveryReceipt(.{
        .request = notification,
        .transport = .unavailable,
        .status = .delivered,
    }));
    try std.testing.expectError(error.InvalidNotificationDeliveryReceipt, host.applyNotificationDeliveryReceipt(.{
        .request = notification,
        .transport = request.transport,
        .status = .pending,
    }));
    try std.testing.expectError(error.NotificationDeliveryMismatch, host.applyNotificationDeliveryReceipt(.{
        .request = .{
            .pane_id = 8,
            .status = notification.status,
            .reason = notification.reason,
            .urgency = notification.urgency,
        },
        .transport = request.transport,
        .status = .delivered,
    }));
}

test "clipboard transfer chooses wayland and x11 transports and tracks receipts" {
    var host = NativeHost.init(Config.Config.defaults(), Backend.Descriptor.preferredForLinux(), .default());
    const read = try host.beginClipboardTransfer(.read, .clipboard, 0);
    try std.testing.expect(read.canTransfer());
    try std.testing.expectEqual(ClipboardTransport.wayland_data_control, read.transport);
    try std.testing.expectEqual(ClipboardTransferStatus.pending, host.clipboard_transfer_status);

    const read_status = try host.applyClipboardTransferReceipt(.{
        .operation = read.operation,
        .selection = read.selection,
        .transport = read.transport,
        .status = .completed,
        .bytes = 14,
    });
    try std.testing.expectEqual(ClipboardTransferStatus.completed, read_status);

    const write = try host.beginClipboardTransfer(.write, .primary, 12);
    try std.testing.expectEqual(ClipboardTransport.wayland_data_control, write.transport);
    const write_status = try host.applyClipboardTransferReceipt(.{
        .operation = write.operation,
        .selection = write.selection,
        .transport = write.transport,
        .status = .completed,
        .bytes = write.bytes,
    });
    try std.testing.expectEqual(ClipboardTransferStatus.completed, write_status);

    var x11 = NativeHost.fromEnvironment(Config.Config.defaults(), .{
        .display = ":0",
        .current_desktop = "GNOME",
        .xdg_session_type = "x11",
    }, .default());
    const x11_request = try x11.beginClipboardTransfer(.read, .clipboard, 0);
    try std.testing.expectEqual(ClipboardTransport.x11_selection, x11_request.transport);
}

test "clipboard transfer reports unavailable and rejects stale receipts" {
    var headless = NativeHost.fromEnvironment(Config.Config.defaults(), .{}, .default());
    const unavailable = try headless.beginClipboardTransfer(.read, .clipboard, 0);
    try std.testing.expect(!unavailable.canTransfer());
    try std.testing.expectEqual(ClipboardTransport.unavailable, unavailable.transport);
    try std.testing.expectEqual(ClipboardTransferStatus.unavailable, unavailable.status);
    try std.testing.expectError(error.EmptyClipboardTransfer, headless.beginClipboardTransfer(.write, .clipboard, 0));
    try std.testing.expectError(error.InvalidClipboardTransfer, headless.beginClipboardTransfer(.read, .clipboard, 1));

    var host = NativeHost.init(Config.Config.defaults(), Backend.Descriptor.preferredForLinux(), .default());
    const request = try host.beginClipboardTransfer(.write, .clipboard, 5);
    try std.testing.expectError(error.ClipboardTransferTransportMismatch, host.applyClipboardTransferReceipt(.{
        .operation = request.operation,
        .selection = request.selection,
        .transport = .x11_selection,
        .status = .completed,
        .bytes = request.bytes,
    }));
    try std.testing.expectError(error.InvalidClipboardTransferReceipt, host.applyClipboardTransferReceipt(.{
        .operation = request.operation,
        .selection = request.selection,
        .transport = request.transport,
        .status = .pending,
        .bytes = request.bytes,
    }));
    try std.testing.expectError(error.ClipboardTransferMismatch, host.applyClipboardTransferReceipt(.{
        .operation = .read,
        .selection = request.selection,
        .transport = request.transport,
        .status = .completed,
        .bytes = request.bytes,
    }));
    try std.testing.expectError(error.ClipboardTransferMismatch, host.applyClipboardTransferReceipt(.{
        .operation = request.operation,
        .selection = request.selection,
        .transport = request.transport,
        .status = .completed,
        .bytes = request.bytes - 1,
    }));
}

test "paste delivery tracks prepared terminal delivery receipts" {
    var host = NativeHost.init(Config.Config.defaults(), Backend.Descriptor.preferredForLinux(), .default());
    const request = try host.beginPasteDelivery(7, 32, true, .shell_one_line);
    try std.testing.expect(request.canDeliver());
    try std.testing.expectEqual(@as(Terminal.PaneId, 7), request.pane_id);
    try std.testing.expectEqual(Paste.PastePolicy.shell_one_line, request.policy);
    try std.testing.expectEqual(PasteDeliveryStatus.pending, host.paste_delivery_status);

    const status = try host.applyPasteDeliveryReceipt(.{
        .pane_id = request.pane_id,
        .bytes = request.bytes,
        .status = .delivered,
    });
    try std.testing.expectEqual(PasteDeliveryStatus.delivered, status);
    try std.testing.expect(host.paste_delivery_pane_id == null);
}

test "paste delivery rejects stale and invalid receipts" {
    var host = NativeHost.init(Config.Config.defaults(), Backend.Descriptor.preferredForLinux(), .default());
    try std.testing.expectError(error.EmptyPasteDelivery, host.beginPasteDelivery(7, 0, false, .literal));
    const request = try host.beginPasteDelivery(7, 32, true, .literal);
    try std.testing.expectError(error.InvalidPasteDeliveryReceipt, host.applyPasteDeliveryReceipt(.{
        .pane_id = request.pane_id,
        .bytes = request.bytes,
        .status = .pending,
    }));
    try std.testing.expectError(error.PasteDeliveryMismatch, host.applyPasteDeliveryReceipt(.{
        .pane_id = 8,
        .bytes = request.bytes,
        .status = .delivered,
    }));
    try std.testing.expectError(error.PasteDeliveryMismatch, host.applyPasteDeliveryReceipt(.{
        .pane_id = request.pane_id,
        .bytes = request.bytes - 1,
        .status = .delivered,
    }));
    try std.testing.expectError(error.InvalidPasteDeliveryReceipt, host.applyPasteDeliveryReceipt(.{
        .pane_id = request.pane_id,
        .bytes = request.bytes,
        .status = .failed,
    }));
}

test "status tooltip requests carry summaries and track receipts" {
    var host = NativeHost.init(Config.Config.defaults(), Backend.Descriptor.preferredForLinux(), .default());
    const summary = Workspace.TabStatusSummary.fromStats(.{
        .total = 2,
        .pending_interaction = 1,
        .idle = 1,
    });
    const request = host.beginStatusTooltip(3, summary, true);
    try std.testing.expect(request.canRequest());
    try std.testing.expectEqual(@as(u64, 3), request.tab_id);
    try std.testing.expectEqual(StatusTooltipStatus.show_requested, host.status_tooltip_status);
    try std.testing.expectEqual(@as(usize, 2), request.lineSlice().len);

    var tooltip_buf: [192]u8 = undefined;
    var tooltip_writer = std.Io.Writer.fixed(&tooltip_buf);
    try request.formatTooltip(&tooltip_writer);
    try std.testing.expectEqualStrings(
        \\2 terminal panes, 1 needs attention
        \\Pending input: 1 (attention)
        \\Idle: 1
        \\
    , tooltip_writer.buffered());

    const status = try host.applyStatusTooltipReceipt(.{ .tab_id = request.tab_id, .status = .shown });
    try std.testing.expectEqual(StatusTooltipStatus.shown, status);
    try std.testing.expectEqual(StatusTooltipStatus.hidden, host.hideStatusTooltip());
}

test "status tooltip honors disabled setting and rejects stale receipts" {
    var host = NativeHost.init(Config.Config.defaults(), Backend.Descriptor.preferredForLinux(), .default());
    const summary = Workspace.TabStatusSummary.fromStats(.{ .total = 1, .idle = 1 });
    const disabled = host.beginStatusTooltip(1, summary, false);
    try std.testing.expect(!disabled.canRequest());
    try std.testing.expectEqual(StatusTooltipStatus.disabled, disabled.status);
    var tooltip_buf: [64]u8 = undefined;
    var tooltip_writer = std.Io.Writer.fixed(&tooltip_buf);
    try std.testing.expectError(error.StatusTooltipUnavailable, disabled.formatTooltip(&tooltip_writer));

    try std.testing.expectError(error.InvalidStatusTooltipReceipt, host.applyStatusTooltipReceipt(.{
        .tab_id = 1,
        .status = .show_requested,
    }));
    try std.testing.expectError(error.StatusTooltipMismatch, host.applyStatusTooltipReceipt(.{
        .tab_id = 2,
        .status = .shown,
    }));
    const status = try host.applyStatusTooltipReceipt(.{ .tab_id = 1, .status = .disabled });
    try std.testing.expectEqual(StatusTooltipStatus.disabled, status);
}

test "profile preset menu lists choices and tracks selected receipt" {
    var host = NativeHost.init(Config.Config.defaults(), Backend.Descriptor.preferredForLinux(), .default());
    const current = Terminal.ProfilePreset.global_default.profile(host.config);
    const request = try host.beginProfilePresetMenu(7, current);
    try std.testing.expect(request.canShow());
    try std.testing.expectEqual(@as(Terminal.PaneId, 7), request.pane_id);
    try std.testing.expectEqual(ProfilePresetMenuStatus.show_requested, host.profile_preset_menu_status);
    try std.testing.expectEqual(@as(usize, 5), request.itemSlice().len);
    try std.testing.expectEqual(Terminal.ProfilePreset.global_default, request.itemSlice()[0].preset);
    try std.testing.expect(request.itemSlice()[0].current);
    try std.testing.expect(request.containsPreset(.mono_no_ligatures));

    const shown = try host.applyProfilePresetMenuReceipt(.{ .pane_id = request.pane_id, .status = .shown });
    try std.testing.expectEqual(ProfilePresetMenuStatus.shown, shown);
    const selected = try host.applyProfilePresetMenuReceipt(.{
        .pane_id = request.pane_id,
        .status = .selected,
        .selected_preset = .readable,
    });
    try std.testing.expectEqual(ProfilePresetMenuStatus.selected, selected);
    try std.testing.expectEqual(Terminal.ProfilePreset.readable, host.profile_preset_menu_selected.?);
    try std.testing.expect(host.profile_preset_menu_pane_id == null);
}

test "profile preset menu rejects stale and invalid receipts" {
    var host = NativeHost.init(Config.Config.defaults(), Backend.Descriptor.preferredForLinux(), .default());
    const request = try host.beginProfilePresetMenu(7, Terminal.ProfilePreset.global_default.profile(host.config));
    try std.testing.expectError(error.InvalidProfilePresetMenuReceipt, host.applyProfilePresetMenuReceipt(.{
        .pane_id = request.pane_id,
        .status = .show_requested,
    }));
    try std.testing.expectError(error.ProfilePresetMenuMismatch, host.applyProfilePresetMenuReceipt(.{
        .pane_id = 8,
        .status = .shown,
    }));
    try std.testing.expectError(error.InvalidProfilePresetMenuReceipt, host.applyProfilePresetMenuReceipt(.{
        .pane_id = request.pane_id,
        .status = .selected,
    }));
    try std.testing.expectError(error.InvalidProfilePresetMenuReceipt, host.applyProfilePresetMenuReceipt(.{
        .pane_id = request.pane_id,
        .status = .dismissed,
        .selected_preset = .compact,
    }));
    try std.testing.expectEqual(ProfilePresetMenuStatus.hidden, host.hideProfilePresetMenu());
}

test "workspace file dialog chooses native transport and tracks receipts" {
    var host = NativeHost.init(Config.Config.defaults(), Backend.Descriptor.preferredForLinux(), .default());
    const request = try host.beginWorkspaceFileDialog(.save, "/home/alice/project.nocttyws");
    try std.testing.expect(request.canShow());
    try std.testing.expectEqual(WorkspaceFileDialogOperation.save, request.operation);
    try std.testing.expectEqual(WorkspaceFileDialogTransport.gtk_native_dialog, request.transport);
    try std.testing.expectEqual(WorkspaceFileDialogStatus.pending, host.workspace_file_dialog_status);

    const shown = try host.applyWorkspaceFileDialogReceipt(.{
        .operation = request.operation,
        .transport = request.transport,
        .status = .shown,
    });
    try std.testing.expectEqual(WorkspaceFileDialogStatus.shown, shown);

    const selected = try host.applyWorkspaceFileDialogReceipt(.{
        .operation = request.operation,
        .transport = request.transport,
        .status = .selected,
        .selected_path = "/home/alice/project.nocttyws",
    });
    try std.testing.expectEqual(WorkspaceFileDialogStatus.selected, selected);
    try std.testing.expect(host.workspace_file_dialog_operation == null);

    var x11 = NativeHost.fromEnvironment(Config.Config.defaults(), .{
        .display = ":0",
        .current_desktop = "KDE",
        .xdg_session_type = "x11",
    }, .default());
    const x11_request = try x11.beginWorkspaceFileDialog(.open, "/home/alice/project.nocttyws");
    try std.testing.expectEqual(WorkspaceFileDialogTransport.gtk_native_dialog, x11_request.transport);
}

test "workspace file dialog reports unavailable and rejects invalid receipts" {
    var headless = NativeHost.fromEnvironment(Config.Config.defaults(), .{}, .default());
    const unavailable = try headless.beginWorkspaceFileDialog(.open, "/home/alice/project.nocttyws");
    try std.testing.expect(!unavailable.canShow());
    try std.testing.expectEqual(WorkspaceFileDialogTransport.unavailable, unavailable.transport);
    try std.testing.expectEqual(WorkspaceFileDialogStatus.unavailable, unavailable.status);
    try std.testing.expectError(error.InvalidWorkspaceFileDialogPath, headless.beginWorkspaceFileDialog(.save, ""));

    var host = NativeHost.init(Config.Config.defaults(), Backend.Descriptor.preferredForLinux(), .default());
    const request = try host.beginWorkspaceFileDialog(.open, "/home/alice/project.nocttyws");
    try std.testing.expectError(error.InvalidWorkspaceFileDialogReceipt, host.applyWorkspaceFileDialogReceipt(.{
        .operation = request.operation,
        .transport = request.transport,
        .status = .pending,
    }));
    try std.testing.expectError(error.WorkspaceFileDialogMismatch, host.applyWorkspaceFileDialogReceipt(.{
        .operation = .save,
        .transport = request.transport,
        .status = .shown,
    }));
    try std.testing.expectError(error.WorkspaceFileDialogTransportMismatch, host.applyWorkspaceFileDialogReceipt(.{
        .operation = request.operation,
        .transport = .unavailable,
        .status = .shown,
    }));
    try std.testing.expectError(error.InvalidWorkspaceFileDialogReceipt, host.applyWorkspaceFileDialogReceipt(.{
        .operation = request.operation,
        .transport = request.transport,
        .status = .selected,
    }));
    try std.testing.expectError(error.InvalidWorkspaceFileDialogReceipt, host.applyWorkspaceFileDialogReceipt(.{
        .operation = request.operation,
        .transport = request.transport,
        .status = .canceled,
        .selected_path = "/home/alice/project.nocttyws",
    }));
}

test "project panel presentation carries summary and tracks receipts" {
    var host = NativeHost.init(Config.Config.defaults(), Backend.Descriptor.preferredForLinux(), .default());
    const request = host.beginProjectPanelPresentation(.{
        .git_status_count = 2,
        .changed_count = 1,
        .git_graph_count = 3,
        .file_entry_count = 4,
        .directory_count = 1,
    });
    try std.testing.expect(request.canShow());
    try std.testing.expect(request.hasPanelData());
    try std.testing.expect(request.show_git_status);
    try std.testing.expect(request.show_git_graph);
    try std.testing.expect(request.show_files);
    try std.testing.expectEqual(@as(usize, 2), request.summary.git_status_count);
    try std.testing.expectEqual(ProjectPanelPresentationStatus.show_requested, host.project_panel_status);

    const shown = try host.applyProjectPanelPresentationReceipt(.{ .status = .shown });
    try std.testing.expectEqual(ProjectPanelPresentationStatus.shown, shown);
    try std.testing.expect(host.last_project_panel != null);

    const dismissed = try host.applyProjectPanelPresentationReceipt(.{ .status = .dismissed });
    try std.testing.expectEqual(ProjectPanelPresentationStatus.dismissed, dismissed);
    try std.testing.expect(host.last_project_panel == null);
}

test "project panel presentation supports empty state and rejects invalid receipts" {
    var host = NativeHost.init(Config.Config.defaults(), Backend.Descriptor.preferredForLinux(), .default());
    const empty = host.beginProjectPanelPresentation(.{});
    try std.testing.expect(empty.canShow());
    try std.testing.expect(!empty.hasPanelData());
    try std.testing.expect(!empty.show_git_status);
    try std.testing.expect(!empty.show_git_graph);
    try std.testing.expect(!empty.show_files);

    try std.testing.expectError(error.InvalidProjectPanelPresentationReceipt, host.applyProjectPanelPresentationReceipt(.{
        .status = .show_requested,
    }));
    try std.testing.expectEqual(ProjectPanelPresentationStatus.hidden, host.hideProjectPanelPresentation());
    try std.testing.expectError(error.ProjectPanelPresentationMismatch, host.applyProjectPanelPresentationReceipt(.{
        .status = .shown,
    }));
}

test "project panel action chooses native handoff and tracks receipts" {
    var host = NativeHost.init(Config.Config.defaults(), Backend.Descriptor.preferredForLinux(), .default());
    const activation = Workspace.ProjectPanelActivation{
        .kind = .show_git_diff,
        .source = .{ .kind = .git_status, .source_index = 0 },
        .path = "src/main.zig",
        .git_state = .modified,
    };
    const request = host.beginProjectPanelAction(activation);
    try std.testing.expect(request.canDispatch());
    try std.testing.expectEqual(ProjectPanelActionTransport.native_workspace_action, request.transport);
    try std.testing.expectEqual(ProjectPanelActionStatus.pending, host.project_panel_action_status);
    try std.testing.expectEqual(Workspace.ProjectPanelActivationKind.show_git_diff, host.last_project_panel_action.?.kind);

    const completed = try host.applyProjectPanelActionReceipt(.{
        .source = activation.source,
        .kind = activation.kind,
        .transport = request.transport,
        .status = .completed,
    });
    try std.testing.expectEqual(ProjectPanelActionStatus.completed, completed);
    try std.testing.expect(host.last_project_panel_action == null);
}

test "project panel action reports unavailable and rejects invalid receipts" {
    var headless = NativeHost.fromEnvironment(Config.Config.defaults(), .{}, .default());
    const activation = Workspace.ProjectPanelActivation{
        .kind = .open_file,
        .source = .{ .kind = .files, .source_index = 1 },
        .path = "src/main.zig",
        .file_kind = .file,
    };
    const unavailable = headless.beginProjectPanelAction(activation);
    try std.testing.expect(!unavailable.canDispatch());
    try std.testing.expectEqual(ProjectPanelActionTransport.unavailable, unavailable.transport);
    try std.testing.expectEqual(ProjectPanelActionStatus.unavailable, unavailable.status);
    const unavailable_receipt = try headless.applyProjectPanelActionReceipt(.{
        .source = activation.source,
        .kind = activation.kind,
        .transport = unavailable.transport,
        .status = .unavailable,
    });
    try std.testing.expectEqual(ProjectPanelActionStatus.unavailable, unavailable_receipt);

    var host = NativeHost.init(Config.Config.defaults(), Backend.Descriptor.preferredForLinux(), .default());
    const request = host.beginProjectPanelAction(activation);
    try std.testing.expectError(error.InvalidProjectPanelActionReceipt, host.applyProjectPanelActionReceipt(.{
        .source = activation.source,
        .kind = activation.kind,
        .transport = request.transport,
        .status = .pending,
    }));
    try std.testing.expectError(error.ProjectPanelActionMismatch, host.applyProjectPanelActionReceipt(.{
        .source = .{ .kind = .files, .source_index = 0 },
        .kind = activation.kind,
        .transport = request.transport,
        .status = .completed,
    }));
    try std.testing.expectError(error.ProjectPanelActionTransportMismatch, host.applyProjectPanelActionReceipt(.{
        .source = activation.source,
        .kind = activation.kind,
        .transport = .unavailable,
        .status = .completed,
    }));
}

test "launch plan describes first visible dropdown activation" {
    const cfg = Config.Config.defaults();
    const host = NativeHost.init(cfg, Backend.Descriptor.preferredForLinux(), .{
        .width_px = 2560,
        .height_px = 1440,
    });
    const plan = host.launchPlan();
    try std.testing.expectEqual(LaunchReadiness.ready, plan.readiness);
    try std.testing.expectEqual(SurfaceIntent.hidden_dropdown, plan.initial_surface);
    try std.testing.expectEqual(SurfaceIntent.visible_dropdown, plan.shortcut_activation_surface);
    try std.testing.expect(plan.canPresentWindow());
    try std.testing.expect(plan.needsShortcutRegistration());
    try std.testing.expect(plan.register_global_shortcut);
    try std.testing.expect(plan.use_layer_shell);
    try std.testing.expect(plan.use_desktop_notifications);
    try std.testing.expect(plan.use_external_activation);
    try std.testing.expect(plan.hidpi);
    try std.testing.expectEqual(@as(u32, 2457), plan.shortcut_activation_rect.width_px);
    try std.testing.expectEqual(@as(u32, 792), plan.shortcut_activation_rect.height_px);
    try std.testing.expectEqual(@as(u16, 0), plan.chrome.main_titlebar_px);
}

test "launch plan degrades outside Plasma and is unavailable headless" {
    const cfg = Config.Config.defaults();
    const non_plasma = NativeHost.fromEnvironment(cfg, .{
        .display = ":0",
        .current_desktop = "GNOME",
        .xdg_session_type = "x11",
    }, .default()).launchPlan();
    try std.testing.expectEqual(LaunchReadiness.degraded, non_plasma.readiness);
    try std.testing.expect(non_plasma.canPresentWindow());
    try std.testing.expect(!non_plasma.register_global_shortcut);
    try std.testing.expect(non_plasma.use_desktop_notifications);

    const headless = NativeHost.fromEnvironment(cfg, .{}, .default()).launchPlan();
    try std.testing.expectEqual(LaunchReadiness.unavailable, headless.readiness);
    try std.testing.expectEqual(SurfaceIntent.unavailable, headless.initial_surface);
    try std.testing.expect(!headless.canPresentWindow());
}

test "presentation plan lists startup transport actions for hidden dropdown" {
    const host = NativeHost.init(Config.Config.defaults(), Backend.Descriptor.preferredForLinux(), .default());
    const plan = host.presentationPlan(.startup);
    try std.testing.expectEqual(PresentationTrigger.startup, plan.trigger);
    try std.testing.expectEqual(PresentationProtocol.wayland_layer_shell, plan.protocol);
    try std.testing.expectEqual(SurfaceIntent.hidden_dropdown, plan.target_surface);
    try std.testing.expect(plan.hasTransportWork());
    try std.testing.expect(plan.containsAction(.create_surface));
    try std.testing.expect(plan.containsAction(.configure_zero_chrome));
    try std.testing.expect(plan.containsAction(.configure_layer_shell));
    try std.testing.expect(plan.containsAction(.set_window_rect));
    try std.testing.expect(plan.containsAction(.register_global_shortcut));
    try std.testing.expect(plan.containsAction(.enable_drag_and_drop));
    try std.testing.expect(plan.containsAction(.bind_desktop_notifications));
    try std.testing.expect(plan.containsAction(.hide_surface));
    try std.testing.expect(!plan.containsAction(.show_surface));
}

test "presentation plan lists shortcut show and hide actions" {
    var host = NativeHost.init(Config.Config.defaults(), Backend.Descriptor.preferredForLinux(), .default());
    var show_plan = host.presentationPlan(.shortcut_activation);
    try std.testing.expectEqual(SurfaceIntent.visible_dropdown, show_plan.target_surface);
    try std.testing.expect(show_plan.containsAction(.show_surface));
    try std.testing.expect(!show_plan.containsAction(.register_global_shortcut));

    host.toggleDropdown();
    const hide_plan = host.presentationPlan(.shortcut_activation);
    try std.testing.expectEqual(SurfaceIntent.hidden_dropdown, hide_plan.target_surface);
    try std.testing.expect(hide_plan.containsAction(.hide_surface));
    try std.testing.expect(!hide_plan.containsAction(.show_surface));
}

test "presentation plan models x11 degradation and headless unavailability" {
    const cfg = Config.Config.defaults();
    const x11 = NativeHost.fromEnvironment(cfg, .{
        .display = ":0",
        .current_desktop = "GNOME",
        .xdg_session_type = "x11",
    }, .default()).presentationPlan(.shortcut_activation);
    try std.testing.expectEqual(LaunchReadiness.degraded, x11.readiness);
    try std.testing.expectEqual(PresentationProtocol.x11_ewmh, x11.protocol);
    try std.testing.expect(x11.containsAction(.configure_x11_ewmh));
    try std.testing.expect(!x11.containsAction(.register_global_shortcut));
    try std.testing.expect(x11.containsAction(.bind_desktop_notifications));

    const headless = NativeHost.fromEnvironment(cfg, .{}, .default()).presentationPlan(.startup);
    try std.testing.expectEqual(LaunchReadiness.unavailable, headless.readiness);
    try std.testing.expectEqual(PresentationProtocol.unavailable, headless.protocol);
    try std.testing.expect(!headless.hasTransportWork());
}

test "window lifecycle request and receipts track hidden and shown dropdowns" {
    var host = NativeHost.init(Config.Config.defaults(), Backend.Descriptor.preferredForLinux(), .default());
    const startup = host.beginWindowLifecycle(.startup);
    try std.testing.expect(startup.canCreate());
    try std.testing.expectEqual(PresentationProtocol.wayland_layer_shell, startup.protocol);
    try std.testing.expectEqual(SurfaceIntent.hidden_dropdown, startup.target_surface);
    try std.testing.expectEqual(WindowLifecycleStatus.create_requested, host.window_lifecycle_status);

    const hidden = try host.applyWindowLifecycleReceipt(.{
        .trigger = startup.trigger,
        .protocol = startup.protocol,
        .target_surface = startup.target_surface,
        .target_rect = startup.target_rect,
        .status = .hidden,
        .window_id = 42,
    });
    try std.testing.expectEqual(WindowLifecycleStatus.hidden, hidden);
    try std.testing.expectEqual(@as(?u64, 42), host.window_transport_id);
    try std.testing.expect(!host.window.visible);

    const shortcut = host.beginWindowLifecycle(.shortcut_activation);
    try std.testing.expectEqual(SurfaceIntent.visible_dropdown, shortcut.target_surface);
    const shown = try host.applyWindowLifecycleReceipt(.{
        .trigger = shortcut.trigger,
        .protocol = shortcut.protocol,
        .target_surface = shortcut.target_surface,
        .target_rect = shortcut.target_rect,
        .status = .shown,
        .window_id = 42,
    });
    try std.testing.expectEqual(WindowLifecycleStatus.shown, shown);
    try std.testing.expect(host.window.visible);
    try std.testing.expectEqual(Config.WindowMode.dropdown, host.window.mode);
    try std.testing.expectEqual(startup.target_rect.width_px, host.window.rect.width_px);
}

test "window lifecycle reports unavailable and rejects stale receipts" {
    var headless = NativeHost.fromEnvironment(Config.Config.defaults(), .{}, .default());
    const unavailable = headless.beginWindowLifecycle(.startup);
    try std.testing.expect(!unavailable.canCreate());
    try std.testing.expectEqual(WindowLifecycleStatus.unavailable, unavailable.status);

    var host = NativeHost.init(Config.Config.defaults(), Backend.Descriptor.preferredForLinux(), .default());
    const request = host.beginWindowLifecycle(.shortcut_activation);
    try std.testing.expectError(error.WindowLifecycleTransportMismatch, host.applyWindowLifecycleReceipt(.{
        .trigger = request.trigger,
        .protocol = .x11_ewmh,
        .target_surface = request.target_surface,
        .target_rect = request.target_rect,
        .status = .shown,
        .window_id = 7,
    }));
    try std.testing.expectError(error.InvalidWindowLifecycleReceipt, host.applyWindowLifecycleReceipt(.{
        .trigger = request.trigger,
        .protocol = request.protocol,
        .target_surface = request.target_surface,
        .target_rect = request.target_rect,
        .status = .create_requested,
    }));
    try std.testing.expectError(error.WindowLifecycleMismatch, host.applyWindowLifecycleReceipt(.{
        .trigger = .startup,
        .protocol = request.protocol,
        .target_surface = request.target_surface,
        .target_rect = request.target_rect,
        .status = .shown,
        .window_id = 7,
    }));
}

test "shortcut registration request chooses kde transport and tracks receipts" {
    var host = NativeHost.init(Config.Config.defaults(), Backend.Descriptor.preferredForLinux(), .default());
    const request = host.beginShortcutRegistration();
    try std.testing.expect(request.canRegister());
    try std.testing.expectEqual(ShortcutRegistrationTransport.kde_global_accel, request.transport);
    try std.testing.expectEqual(ShortcutRegistrationStatus.pending, host.shortcut_registration_status);

    const status = try host.applyShortcutRegistrationReceipt(.{
        .shortcut = request.shortcut,
        .transport = request.transport,
        .status = .registered,
    });
    try std.testing.expectEqual(ShortcutRegistrationStatus.registered, status);
    try std.testing.expectEqual(ShortcutRegistrationStatus.registered, host.shortcut_registration_status);

    host.beginShortcutRecording();
    _ = try host.captureShortcut(.{ .key = .t, .ctrl = true, .alt = true });
    try std.testing.expectEqual(ShortcutRegistrationStatus.not_requested, host.shortcut_registration_status);
}

test "shortcut registration reports unavailable and rejects stale receipts" {
    var headless = NativeHost.fromEnvironment(Config.Config.defaults(), .{}, .default());
    const request = headless.beginShortcutRegistration();
    try std.testing.expect(!request.canRegister());
    try std.testing.expectEqual(ShortcutRegistrationTransport.unavailable, request.transport);
    try std.testing.expectEqual(ShortcutRegistrationStatus.unavailable, headless.shortcut_registration_status);

    var host = NativeHost.init(Config.Config.defaults(), Backend.Descriptor.preferredForLinux(), .default());
    const live = host.beginShortcutRegistration();
    try std.testing.expectError(error.ShortcutRegistrationTransportMismatch, host.applyShortcutRegistrationReceipt(.{
        .shortcut = live.shortcut,
        .transport = .x11_grab_key,
        .status = .registered,
    }));
    try std.testing.expectError(error.InvalidShortcutRegistrationReceipt, host.applyShortcutRegistrationReceipt(.{
        .shortcut = live.shortcut,
        .transport = live.transport,
        .status = .pending,
    }));
    try std.testing.expectError(error.ShortcutRegistrationMismatch, host.applyShortcutRegistrationReceipt(.{
        .shortcut = .{ .key = .t, .ctrl = true },
        .transport = live.transport,
        .status = .registered,
    }));
}
