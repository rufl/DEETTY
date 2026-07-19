const build_options = @import("noctty_build_options");

pub const app = @import("app/App.zig");
pub const config = @import("config/Config.zig");
pub const config_storage = @import("config/Storage.zig");
pub const editor = @import("editor/TextBuffer.zig");
pub const editor_syntax_theme = @import("editor/SyntaxTheme.zig");
pub const editor_tree_sitter = if (build_options.enable_legacy_editor)
    @import("editor/TreeSitter.zig")
else
    @import("editor/TreeSitterDisabled.zig");
pub const ghostty = @import("ghostty/root.zig");
pub const gui = @import("gui/root.zig");
pub const terminal = @import("terminal/Terminal.zig");
pub const terminal_session = @import("terminal/Session.zig");
pub const vt = @import("terminal/Vt.zig");
pub const paste = @import("terminal/Paste.zig");
pub const pty = @import("terminal/Pty.zig");
pub const launch_profile = @import("terminal/LaunchProfile.zig");
pub const pane_info = @import("terminal/PaneInfo.zig");
pub const theme = @import("theme/Theme.zig");
pub const theme_storage = @import("theme/Storage.zig");
pub const project_scan = @import("workspace/ProjectScan.zig");
pub const release = @import("release.zig");
pub const workspace_storage = @import("workspace/Storage.zig");
pub const workspace = @import("workspace/Workspace.zig");
pub const workspace_activation = @import("workspace/Activation.zig");

test {
    _ = app;
    _ = config;
    _ = config_storage;
    _ = editor;
    _ = editor_syntax_theme;
    _ = editor_tree_sitter;
    _ = ghostty;
    _ = gui;
    _ = terminal;
    _ = terminal_session;
    _ = vt;
    _ = paste;
    _ = pty;
    _ = launch_profile;
    _ = pane_info;
    _ = theme;
    _ = theme_storage;
    _ = project_scan;
    _ = release;
    _ = workspace_storage;
    _ = workspace;
    _ = workspace_activation;
}
