const std = @import("std");
const LaunchProfile = @import("LaunchProfile.zig");

pub const max_session_id_bytes: usize = 256;
pub const max_label_bytes: usize = 64;

pub const Provider = enum(u8) {
    pi,
    omp,
    zipi,
};

pub const RestoreMode = enum(u8) {
    restart_shells,
    attach_persistent,
    resume_agents,
};

pub const Kind = enum(u8) {
    restartable_shell,
    live_tmux,
    live_zellij,
    agent_resume,
};

pub const AgentResume = struct {
    enabled: bool = false,
    provider: Provider = .pi,
    session_id: LaunchProfile.BoundedText(max_session_id_bytes) = .{},
    label: LaunchProfile.BoundedText(max_label_bytes) = .{},

    pub fn validate(self: *const AgentResume) !void {
        if (!self.enabled) return;
        if (self.session_id.slice().len == 0) return error.InvalidAgentResumeReference;
        if (!std.unicode.utf8ValidateSlice(self.session_id.slice()))
            return error.InvalidAgentResumeReference;
        for (self.session_id.slice()) |byte| {
            if (!(std.ascii.isAlphanumeric(byte) or switch (byte) {
                '.', '_', '-', ':', '/', '@' => true,
                else => false,
            })) return error.InvalidAgentResumeReference;
        }
        if (self.label.slice().len > 0)
            try validateLabel(self.label.slice());
    }

    pub fn clear(self: *AgentResume) void {
        self.* = .{};
    }

    pub fn kind(self: AgentResume, launch_kind: LaunchProfile.Kind) Kind {
        if (self.enabled) return .agent_resume;
        return switch (launch_kind) {
            .tmux => .live_tmux,
            .zellij => .live_zellij,
            else => .restartable_shell,
        };
    }

    pub fn labelText(self: AgentResume, launch_kind: LaunchProfile.Kind) []const u8 {
        if (self.enabled) {
            if (self.label.slice().len > 0) return self.label.slice();
            return providerLabel(self.provider);
        }
        return switch (self.kind(launch_kind)) {
            .restartable_shell => "restartable shell",
            .live_tmux => "live tmux",
            .live_zellij => "live Zellij",
            .agent_resume => "agent resume",
        };
    }
};

pub fn providerLabel(provider: Provider) []const u8 {
    return switch (provider) {
        .pi => "Pi",
        .omp => "OMP",
        .zipi => "ZIPI (local)",
    };
}

pub fn providerFromInt(value: u8) !Provider {
    return switch (value) {
        0 => .pi,
        1 => .omp,
        2 => .zipi,
        else => error.InvalidAgentResumeReference,
    };
}

pub fn profileForResume(
    reference: AgentResume,
    cwd: []const u8,
    scrollback_lines: u32,
) !LaunchProfile.Profile {
    try reference.validate();
    if (!reference.enabled) return error.AgentResumeUnavailable;
    var profile = LaunchProfile.Profile{};
    profile.kind = .command;
    try profile.shell.set("/bin/sh");
    try profile.working_directory.set(cwd);
    profile.scrollback_lines = scrollback_lines;
    const command_name = switch (reference.provider) {
        .pi => "pi --resume ",
        .omp => "omp --resume=",
        .zipi => "zipi --resume ",
    };
    var command: [LaunchProfile.max_command_bytes]u8 = undefined;
    const command_slice = try std.fmt.bufPrint(&command, "{s}{s}", .{
        command_name,
        reference.session_id.slice(),
    });
    try profile.command.set(command_slice);
    try profile.validate();
    return profile;
}

fn validateLabel(value: []const u8) !void {
    if (value.len > max_label_bytes or !std.unicode.utf8ValidateSlice(value))
        return error.InvalidAgentResumeReference;
    for (value) |byte| {
        if (byte < 0x20 or byte == 0x7f) return error.InvalidAgentResumeReference;
    }
}

test "continuity labels distinguish restart, live, and agent sessions" {
    const reference = AgentResume{};
    try std.testing.expectEqualStrings("restartable shell", reference.labelText(.shell));
    try std.testing.expectEqualStrings("live tmux", reference.labelText(.tmux));
    try std.testing.expectEqualStrings("live Zellij", reference.labelText(.zellij));

    var configured = AgentResume{ .enabled = true, .provider = .pi };
    try configured.session_id.set("session-123");
    try configured.validate();
    try std.testing.expectEqualStrings("Pi", configured.labelText(.shell));

    configured.provider = .omp;
    try std.testing.expectEqualStrings("OMP", configured.labelText(.shell));
    configured.provider = .zipi;
    try std.testing.expectEqualStrings("ZIPI (local)", configured.labelText(.shell));
}

test "resume profiles use fixed launcher commands" {
    var reference = AgentResume{ .enabled = true, .provider = .pi };
    try reference.session_id.set("abc-123");
    const pi_profile = try profileForResume(reference, "/tmp/project", 1000);
    try std.testing.expectEqual(LaunchProfile.Kind.command, pi_profile.kind);
    try std.testing.expectEqualStrings("pi --resume abc-123", pi_profile.command.slice());

    reference.provider = .omp;
    const omp_profile = try profileForResume(reference, "/tmp/project", 1000);
    try std.testing.expectEqualStrings("omp --resume=abc-123", omp_profile.command.slice());

    reference.provider = .zipi;
    const zipi_profile = try profileForResume(reference, "/tmp/project", 1000);
    try std.testing.expectEqualStrings("zipi --resume abc-123", zipi_profile.command.slice());
}

test "resume references reject shell metacharacters" {
    var reference = AgentResume{ .enabled = true, .provider = .omp };
    try reference.session_id.set("bad;id");
    try std.testing.expectError(error.InvalidAgentResumeReference, reference.validate());
}
