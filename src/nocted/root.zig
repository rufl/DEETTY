pub const document = @import("Document.zig");
pub const folding = @import("Folding.zig");
pub const ignore = @import("Ignore.zig");
pub const lsp = @import("Lsp.zig");
pub const multi_selection = @import("MultiSelection.zig");
pub const project_index = @import("ProjectIndex.zig");
pub const project_search = @import("ProjectSearch.zig");
pub const quick_open = @import("QuickOpen.zig");
pub const settings = @import("Settings.zig");
pub const session = @import("Session.zig");
pub const syntax_discovery = @import("SyntaxDiscovery.zig");
pub const task = @import("Task.zig");
pub const textmate_grammar = @import("TextMateGrammar.zig");

test {
    _ = document;
    _ = folding;
    _ = ignore;
    _ = lsp;
    _ = multi_selection;
    _ = project_index;
    _ = project_search;
    _ = quick_open;
    _ = settings;
    _ = session;
    _ = syntax_discovery;
    _ = task;
    _ = textmate_grammar;
}
