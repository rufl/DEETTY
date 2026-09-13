//! Callback-owned split geometry shared by native hit testing and GDI painting.
const Abi = @import("WindowsHostAbi.zig");
const Ratio = @import("noctty_share").split_ratio;
const c = Abi.c;

pub const Divider = struct {
    node: c_int = -1,
    axis: c_int = 0,
    x: u32 = 0,
    y: u32 = 0,
    width: u32 = 0,
    height: u32 = 0,
    ratio: u32 = 500,

    pub fn read(callbacks: *const Abi.Callbacks, ordinal: c_int) ?Divider {
        var value: Divider = .{};
        if (callbacks.divider_info(callbacks.userdata, ordinal, &value.node, &value.axis, &value.x, &value.y, &value.width, &value.height, &value.ratio) <= 0 or
            value.node < 0 or value.axis < 0 or value.axis > 1 or value.x > 1_000_000 or value.y > 1_000_000 or
            value.width > 1_000_000 - value.x or value.height > 1_000_000 - value.y or value.ratio > 1000) return null;
        return value;
    }

    pub fn sameParent(self: Divider, other: Divider) bool {
        return self.node == other.node and self.axis == other.axis and self.x == other.x and self.y == other.y and self.width == other.width and self.height == other.height and self.ratio == other.ratio;
    }

    pub fn parent(self: Divider, client: c.RECT) c.RECT {
        return .{
            .left = pixel(client.left, client.right, self.x),
            .top = pixel(client.top, client.bottom, self.y),
            .right = pixel(client.left, client.right, self.x + self.width),
            .bottom = pixel(client.top, client.bottom, self.y + self.height),
        };
    }

    pub fn band(self: Divider, client: c.RECT, radius: c_int, ratio: u32) c.RECT {
        var rect = self.parent(client);
        // Partition normalized coordinates before mapping to pixels, exactly as
        // the model's pane rectangles do; never derive a second split layout.
        if (self.axis == 0) {
            const line = pixel(client.left, client.right, self.x + Ratio.position(self.width, @intCast(ratio)));
            rect.left = @max(rect.left, line - radius);
            rect.right = @min(rect.right, line + radius + 1);
        } else {
            const line = pixel(client.top, client.bottom, self.y + Ratio.position(self.height, @intCast(ratio)));
            rect.top = @max(rect.top, line - radius);
            rect.bottom = @min(rect.bottom, line + radius + 1);
        }
        return rect;
    }

    pub fn pointerRatio(self: Divider, client: c.RECT, x: c_int, y: c_int) u16 {
        const rect = self.parent(client);
        const position: i64 = if (self.axis == 0) @as(i64, x) - rect.left else @as(i64, y) - rect.top;
        const extent = if (self.axis == 0) rect.right - rect.left else rect.bottom - rect.top;
        return @max(50, @min(950, Ratio.fromPosition(position, @intCast(@max(0, extent)))));
    }
};

fn pixel(first: c_int, last: c_int, normalized: u32) c_int {
    return first + @as(c_int, @intCast(@divTrunc(@as(i64, last - first) * normalized, 1_000_000)));
}

pub fn contains(rect: c.RECT, x: c_int, y: c_int) bool {
    return x >= rect.left and x < rect.right and y >= rect.top and y < rect.bottom;
}

pub fn hit(callbacks: *const Abi.Callbacks, client: c.RECT, dpi: u32, x: c_int, y: c_int) ?Divider {
    if (!contains(client, x, y)) return null;
    const radius = @max(2, c.MulDiv(3, @intCast(dpi), 96));
    var ordinal = callbacks.divider_count(callbacks.userdata);
    while (ordinal > 0) {
        ordinal -= 1;
        const divider = Divider.read(callbacks, ordinal) orelse continue;
        if (contains(divider.band(client, radius, divider.ratio), x, y)) return divider;
    }
    return null;
}
