const share = @import("share/root.zig");

pub const protocol = share.protocol;
pub const crypto = share.crypto;
pub const identity = share.identity;
pub const transport = share.transport;
pub const pair_controller = share.pair_controller;
pub const live_host = share.live_host;
pub const live_viewer = share.live_viewer;
pub const vt = @import("terminal/Vt.zig");

test {
    _ = share;
}
