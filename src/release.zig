const std = @import("std");

pub const version = "0.1.0";
pub const release_date = "2026-07-14";
pub const package_revision = "1";

test "release metadata has stable package shapes" {
    try std.testing.expectEqualStrings("0.1.0", version);
    try std.testing.expectEqualStrings("2026-07-14", release_date);
    try std.testing.expectEqualStrings("1", package_revision);
}
