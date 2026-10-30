const std = @import("std");

pub const Mutex = struct {
    state: std.atomic.Value(u8) = .init(0),

    pub fn lock(self: *Mutex) void {
        var spins: u8 = 0;
        while (self.state.swap(1, .acquire) != 0) {
            while (self.state.load(.monotonic) != 0) {
                if (spins < 64) {
                    spins += 1;
                    std.atomic.spinLoopHint();
                } else {
                    std.Thread.yield() catch std.atomic.spinLoopHint();
                    spins = 0;
                }
            }
        }
    }

    pub fn unlock(self: *Mutex) void {
        self.state.store(0, .release);
    }
};

test "share mutex serializes access" {
    var mutex = Mutex{};
    mutex.lock();
    try std.testing.expectEqual(@as(u8, 1), mutex.state.load(.monotonic));
    mutex.unlock();
    try std.testing.expectEqual(@as(u8, 0), mutex.state.load(.monotonic));
}
