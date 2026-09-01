//! Owns the platform socket boundary for opt-in LAN session sharing.
//!
//! Socket handles stay opaque to the protocol layer. All operations are bounded
//! so a stalled or malformed peer cannot retain a sharing worker indefinitely.

const std = @import("std");
const builtin = @import("builtin");

const is_windows = builtin.os.tag == .windows;
const c = if (is_windows) @cImport({
    @cDefine("WIN32_LEAN_AND_MEAN", "1");
    @cDefine("_FORTIFY_SOURCE", "0");
    @cInclude("winsock2.h");
    @cInclude("ws2tcpip.h");
}) else @cImport({
    @cDefine("_FORTIFY_SOURCE", "0");
    @cDefine("_POSIX_C_SOURCE", "200112L");
    @cDefine("_DEFAULT_SOURCE", "1");
    @cInclude("arpa/inet.h");
    @cInclude("errno.h");
    @cInclude("fcntl.h");
    @cInclude("netdb.h");
    @cInclude("netinet/in.h");
    @cInclude("poll.h");
    @cInclude("sys/socket.h");
    @cInclude("unistd.h");
});

pub const Socket = isize;
pub const invalid_socket: Socket = -1;

const NativeSocket = if (is_windows) c.SOCKET else c_int;
const SocketAddressV6 = if (is_windows) extern struct {
    family: u16,
    port: u16,
    flow_info: u32,
    address: [16]u8,
    scope_id: u32,
} else c.struct_sockaddr_in6;
const windows_fionbio: c_long = @bitCast(@as(u32, 0x8004667e));
const discovery_group = "239.255.78.84";
const discovery_bytes_max: usize = 1024;
const connect_timeout_ms: c_int = 5_000;
const io_timeout_ms: c_int = 5_000;

const WinsockState = enum(u8) {
    uninitialized,
    initializing,
    ready,
    failed,
};

var winsock_state: WinsockState = .uninitialized;

fn nativeSocket(socket: Socket) NativeSocket {
    return if (is_windows) @bitCast(socket) else @intCast(socket);
}

fn shareSocket(socket: NativeSocket) Socket {
    if (socket == invalidNativeSocket()) return invalid_socket;
    return if (is_windows) @bitCast(socket) else @intCast(socket);
}

fn invalidNativeSocket() NativeSocket {
    return if (is_windows) c.INVALID_SOCKET else -1;
}

fn setIPv4Address(address: *c.struct_in_addr, value: u32) void {
    if (is_windows) {
        address.S_un.S_addr = value;
    } else {
        address.s_addr = value;
    }
}

fn closeNativeSocket(socket: NativeSocket) void {
    if (is_windows) {
        _ = c.closesocket(socket);
    } else {
        _ = c.close(socket);
    }
}

fn startup() bool {
    if (!is_windows) return true;

    const previous = @cmpxchgStrong(
        WinsockState,
        &winsock_state,
        .uninitialized,
        .initializing,
        .acq_rel,
        .acquire,
    );
    if (previous == null) {
        var data: c.WSADATA = undefined;
        const state: WinsockState = if (c.WSAStartup(c.MAKEWORD(2, 2), &data) == 0)
            .ready
        else
            .failed;
        @atomicStore(WinsockState, &winsock_state, state, .release);
        return state == .ready;
    }

    for (0..100_000) |_| {
        const state = @atomicLoad(WinsockState, &winsock_state, .acquire);
        switch (state) {
            .ready => return true,
            .failed => return false,
            .uninitialized => unreachable,
            .initializing => std.atomic.spinLoopHint(),
        }
    }
    return false;
}

fn setSocketOption(
    socket: NativeSocket,
    level: c_int,
    option: c_int,
    value: *const anyopaque,
    value_size: usize,
) bool {
    if (is_windows) {
        return c.setsockopt(
            socket,
            level,
            option,
            @ptrCast(value),
            @intCast(value_size),
        ) == 0;
    }
    return c.setsockopt(
        socket,
        level,
        option,
        value,
        @intCast(value_size),
    ) == 0;
}

fn configureTcpSocket(socket: NativeSocket) bool {
    if (is_windows) {
        const timeout: c.DWORD = io_timeout_ms;
        return setSocketOption(socket, c.SOL_SOCKET, c.SO_RCVTIMEO, &timeout, @sizeOf(c.DWORD)) and
            setSocketOption(socket, c.SOL_SOCKET, c.SO_SNDTIMEO, &timeout, @sizeOf(c.DWORD));
    }

    const timeout: c.struct_timeval = .{
        .tv_sec = @divFloor(io_timeout_ms, 1_000),
        .tv_usec = @mod(io_timeout_ms, 1_000) * 1_000,
    };
    return setSocketOption(socket, c.SOL_SOCKET, c.SO_RCVTIMEO, &timeout, @sizeOf(c.struct_timeval)) and
        setSocketOption(socket, c.SOL_SOCKET, c.SO_SNDTIMEO, &timeout, @sizeOf(c.struct_timeval));
}

fn setNonblocking(socket: NativeSocket, enabled: bool, original_flags: *c_int) bool {
    if (is_windows) {
        var mode: c_ulong = @intFromBool(enabled);
        return c.ioctlsocket(socket, windows_fionbio, &mode) == 0;
    }

    if (enabled) {
        original_flags.* = c.fcntl(socket, c.F_GETFL, @as(c_int, 0));
        if (original_flags.* < 0) return false;
        return c.fcntl(socket, c.F_SETFL, original_flags.* | c.O_NONBLOCK) == 0;
    }
    return c.fcntl(socket, c.F_SETFL, original_flags.*) == 0;
}

fn pollSocket(
    socket: NativeSocket,
    events: c_short,
    timeout_ms: c_int,
    returned_events: *c_short,
) c_int {
    var descriptor: c.struct_pollfd = .{
        .fd = socket,
        .events = events,
        .revents = 0,
    };
    const result = if (is_windows)
        c.WSAPoll(&descriptor, 1, timeout_ms)
    else
        c.poll(&descriptor, 1, timeout_ms);
    returned_events.* = descriptor.revents;
    return result;
}

fn connectWithTimeout(
    socket: NativeSocket,
    address: *const c.struct_sockaddr,
    address_length: c.socklen_t,
) bool {
    var original_flags: c_int = 0;
    if (!setNonblocking(socket, true, &original_flags)) return false;

    const connect_result = c.connect(socket, address, address_length);
    if (connect_result != 0) {
        if (is_windows) {
            const socket_error = c.WSAGetLastError();
            if (socket_error != c.WSAEWOULDBLOCK and
                socket_error != c.WSAEINPROGRESS and
                socket_error != c.WSAEINVAL)
            {
                _ = setNonblocking(socket, false, &original_flags);
                return false;
            }
        } else if (std.posix.errno(connect_result) != .INPROGRESS) {
            _ = setNonblocking(socket, false, &original_flags);
            return false;
        }

        var returned_events: c_short = 0;
        if (pollSocket(socket, c.POLLOUT, connect_timeout_ms, &returned_events) <= 0 or
            returned_events & c.POLLOUT == 0)
        {
            _ = setNonblocking(socket, false, &original_flags);
            return false;
        }

        var socket_error: c_int = 0;
        if (is_windows) {
            var error_size: c_int = @sizeOf(c_int);
            if (c.getsockopt(
                socket,
                c.SOL_SOCKET,
                c.SO_ERROR,
                @ptrCast(&socket_error),
                &error_size,
            ) != 0 or socket_error != 0) {
                _ = setNonblocking(socket, false, &original_flags);
                return false;
            }
        } else {
            var error_size: c.socklen_t = @sizeOf(c_int);
            if (c.getsockopt(
                socket,
                c.SOL_SOCKET,
                c.SO_ERROR,
                &socket_error,
                &error_size,
            ) != 0 or socket_error != 0) {
                _ = setNonblocking(socket, false, &original_flags);
                return false;
            }
        }
    }

    if (!setNonblocking(socket, false, &original_flags)) return false;
    return configureTcpSocket(socket);
}

fn openTcp(
    host: ?[*:0]const u8,
    port: u16,
    passive: bool,
    connect_socket: bool,
    bound_port: ?*u16,
) NativeSocket {
    var service: [6:0]u8 = [_:0]u8{0} ** 6;
    const service_text = std.fmt.bufPrint(service[0..5], "{d}", .{port}) catch
        return invalidNativeSocket();
    service[service_text.len] = 0;

    var hints: c.struct_addrinfo = std.mem.zeroes(c.struct_addrinfo);
    hints.ai_family = c.AF_UNSPEC;
    hints.ai_socktype = c.SOCK_STREAM;
    hints.ai_protocol = c.IPPROTO_TCP;
    hints.ai_flags = if (passive) c.AI_PASSIVE else 0;

    const host_pointer = if (host) |value| if (value[0] == 0) null else value else null;
    var addresses: ?*c.struct_addrinfo = null;
    if (c.getaddrinfo(host_pointer, &service, &hints, &addresses) != 0)
        return invalidNativeSocket();
    defer c.freeaddrinfo(addresses);

    var result = invalidNativeSocket();
    var current = addresses;
    while (current) |address| : (current = address.ai_next) {
        result = c.socket(address.ai_family, address.ai_socktype, address.ai_protocol);
        if (result == invalidNativeSocket()) continue;

        var opened = false;
        if (connect_socket) {
            opened = connectWithTimeout(result, address.ai_addr, @intCast(address.ai_addrlen));
        } else {
            const yes: c_int = 1;
            _ = setSocketOption(result, c.SOL_SOCKET, c.SO_REUSEADDR, &yes, @sizeOf(c_int));
            opened = c.bind(result, address.ai_addr, @intCast(address.ai_addrlen)) == 0 and
                c.listen(result, 8) == 0;
        }
        if (opened) break;
        closeNativeSocket(result);
        result = invalidNativeSocket();
    }

    if (result != invalidNativeSocket() and !connect_socket) {
        if (bound_port) |output_port| setBoundPort(result, output_port);
    }
    return result;
}

fn setBoundPort(socket: NativeSocket, output_port: *u16) void {
    var address: c.struct_sockaddr_storage = std.mem.zeroes(c.struct_sockaddr_storage);
    if (is_windows) {
        var address_size: c_int = @sizeOf(c.struct_sockaddr_storage);
        if (c.getsockname(socket, @ptrCast(&address), &address_size) != 0) return;
    } else {
        var address_size: c.socklen_t = @sizeOf(c.struct_sockaddr_storage);
        if (c.getsockname(socket, @ptrCast(&address), &address_size) != 0) return;
    }
    if (address.ss_family == c.AF_INET) {
        const address_v4: *const c.struct_sockaddr_in = @ptrCast(@alignCast(&address));
        output_port.* = c.ntohs(address_v4.sin_port);
    } else if (address.ss_family == c.AF_INET6) {
        const address_v6: *const SocketAddressV6 = @ptrCast(@alignCast(&address));
        const port = if (is_windows) address_v6.port else address_v6.sin6_port;
        output_port.* = c.ntohs(port);
    }
}

pub fn tcpListen(host: ?[*:0]const u8, port: u16, bound_port: *u16) Socket {
    if (!startup()) return invalid_socket;
    return shareSocket(openTcp(host, port, true, false, bound_port));
}

pub fn tcpAccept(listener: Socket) Socket {
    const accepted = c.accept(nativeSocket(listener), null, null);
    if (accepted == invalidNativeSocket()) return invalid_socket;
    if (!configureTcpSocket(accepted)) {
        closeNativeSocket(accepted);
        return invalid_socket;
    }
    return shareSocket(accepted);
}

pub fn tcpConnect(host: [*:0]const u8, port: u16) Socket {
    if (!startup() or host[0] == 0) return invalid_socket;
    return shareSocket(openTcp(host, port, false, true, null));
}

pub fn socketRead(socket: Socket, output: []u8) c_int {
    if (output.len == 0 or output.len > std.math.maxInt(u16)) return -1;
    const count = if (is_windows)
        c.recv(nativeSocket(socket), @ptrCast(output.ptr), @intCast(output.len), 0)
    else
        c.recv(nativeSocket(socket), output.ptr, output.len, 0);
    if (count > std.math.maxInt(c_int)) return -1;
    return @intCast(count);
}

pub fn socketWrite(socket: Socket, bytes: []const u8) c_int {
    if (bytes.len > std.math.maxInt(u16)) return -1;
    var offset: usize = 0;
    while (offset < bytes.len) {
        const count = if (is_windows)
            c.send(
                nativeSocket(socket),
                @ptrCast(bytes[offset..].ptr),
                @intCast(bytes.len - offset),
                0,
            )
        else
            c.send(
                nativeSocket(socket),
                bytes[offset..].ptr,
                bytes.len - offset,
                if (@hasDecl(c, "MSG_NOSIGNAL")) c.MSG_NOSIGNAL else 0,
            );
        if (count <= 0) return -1;
        offset += @intCast(count);
    }
    return @intCast(bytes.len);
}

pub fn socketReadable(socket: Socket, timeout_ms: u32) c_int {
    var returned_events: c_short = 0;
    const result = pollSocket(
        nativeSocket(socket),
        c.POLLIN,
        @intCast(@min(timeout_ms, @as(u32, std.math.maxInt(c_int)))),
        &returned_events,
    );
    if (result < 0) return -1;
    if (result == 0) return 0;
    if (returned_events & c.POLLIN != 0) return 1;
    return -1;
}

pub fn socketClose(socket: Socket) void {
    if (socket == invalid_socket) return;
    if (is_windows) {
        _ = c.shutdown(nativeSocket(socket), c.SD_BOTH);
    } else {
        _ = c.shutdown(nativeSocket(socket), c.SHUT_RDWR);
    }
    closeNativeSocket(nativeSocket(socket));
}

pub fn discoveryOpen(port: u16) Socket {
    if (!startup()) return invalid_socket;
    const socket = c.socket(c.AF_INET, c.SOCK_DGRAM, c.IPPROTO_UDP);
    if (socket == invalidNativeSocket()) return invalid_socket;
    var retain_socket = false;
    defer if (!retain_socket) closeNativeSocket(socket);

    const yes: c_int = 1;
    _ = setSocketOption(socket, c.SOL_SOCKET, c.SO_REUSEADDR, &yes, @sizeOf(c_int));
    _ = setSocketOption(socket, c.SOL_SOCKET, c.SO_BROADCAST, &yes, @sizeOf(c_int));
    _ = setSocketOption(socket, c.IPPROTO_IP, c.IP_MULTICAST_TTL, &yes, @sizeOf(c_int));
    _ = setSocketOption(socket, c.IPPROTO_IP, c.IP_MULTICAST_LOOP, &yes, @sizeOf(c_int));

    var bind_address: c.struct_sockaddr_in = std.mem.zeroes(c.struct_sockaddr_in);
    bind_address.sin_family = c.AF_INET;
    bind_address.sin_port = c.htons(port);
    setIPv4Address(&bind_address.sin_addr, @intCast(c.htonl(c.INADDR_ANY)));
    if (c.bind(
        socket,
        @ptrCast(&bind_address),
        @intCast(@sizeOf(c.struct_sockaddr_in)),
    ) != 0) return invalid_socket;

    var membership: c.struct_ip_mreq = std.mem.zeroes(c.struct_ip_mreq);
    setIPv4Address(&membership.imr_multiaddr, @intCast(c.inet_addr(discovery_group)));
    setIPv4Address(&membership.imr_interface, @intCast(c.htonl(c.INADDR_ANY)));
    if (!setSocketOption(
        socket,
        c.IPPROTO_IP,
        c.IP_ADD_MEMBERSHIP,
        &membership,
        @sizeOf(c.struct_ip_mreq),
    )) return invalid_socket;

    retain_socket = true;
    return shareSocket(socket);
}

fn sendTo(socket: Socket, target: *const c.struct_sockaddr_in, bytes: []const u8) c_int {
    const count = if (is_windows)
        c.sendto(
            nativeSocket(socket),
            @ptrCast(bytes.ptr),
            @intCast(bytes.len),
            0,
            @ptrCast(target),
            @intCast(@sizeOf(c.struct_sockaddr_in)),
        )
    else
        c.sendto(
            nativeSocket(socket),
            bytes.ptr,
            bytes.len,
            0,
            @ptrCast(target),
            @intCast(@sizeOf(c.struct_sockaddr_in)),
        );
    if (count > std.math.maxInt(c_int)) return -1;
    return @intCast(count);
}

pub fn discoveryAnnounce(socket: Socket, port: u16, bytes: []const u8) c_int {
    if (bytes.len == 0 or bytes.len > discovery_bytes_max) return -1;

    var target: c.struct_sockaddr_in = std.mem.zeroes(c.struct_sockaddr_in);
    target.sin_family = c.AF_INET;
    target.sin_port = c.htons(port);
    setIPv4Address(&target.sin_addr, @intCast(c.inet_addr(discovery_group)));
    const multicast_count = sendTo(socket, &target, bytes);
    setIPv4Address(&target.sin_addr, @intCast(c.htonl(c.INADDR_BROADCAST)));
    const broadcast_count = sendTo(socket, &target, bytes);
    setIPv4Address(&target.sin_addr, @intCast(c.htonl(c.INADDR_LOOPBACK)));
    const loopback_count = sendTo(socket, &target, bytes);

    const expected: c_int = @intCast(bytes.len);
    if (multicast_count == expected or
        broadcast_count == expected or
        loopback_count == expected)
    {
        return expected;
    }
    return -1;
}

pub fn discoveryReceive(socket: Socket, output: []u8, source: []u8) c_int {
    if (output.len == 0 or output.len > discovery_bytes_max or source.len == 0) return -1;

    var address: c.struct_sockaddr_storage = std.mem.zeroes(c.struct_sockaddr_storage);
    const count = if (is_windows) receive: {
        var address_size: c_int = @sizeOf(c.struct_sockaddr_storage);
        break :receive c.recvfrom(
            nativeSocket(socket),
            @ptrCast(output.ptr),
            @intCast(output.len),
            0,
            @ptrCast(&address),
            &address_size,
        );
    } else receive: {
        var address_size: c.socklen_t = @sizeOf(c.struct_sockaddr_storage);
        break :receive c.recvfrom(
            nativeSocket(socket),
            output.ptr,
            output.len,
            0,
            @ptrCast(&address),
            &address_size,
        );
    };
    if (count <= 0) return @intCast(count);

    const address_bytes: ?*const anyopaque = if (address.ss_family == c.AF_INET) address: {
        const address_v4: *const c.struct_sockaddr_in = @ptrCast(@alignCast(&address));
        break :address &address_v4.sin_addr;
    } else if (address.ss_family == c.AF_INET6) address: {
        const address_v6: *const SocketAddressV6 = @ptrCast(@alignCast(&address));
        break :address if (is_windows) &address_v6.address else &address_v6.sin6_addr;
    } else null;

    source[0] = 0;
    if (address_bytes) |bytes| {
        if (is_windows) {
            if (c.inet_ntop(
                address.ss_family,
                bytes,
                @ptrCast(source.ptr),
                @intCast(source.len),
            ) == null) source[0] = 0;
        } else {
            if (source.len <= std.math.maxInt(c.socklen_t) and c.inet_ntop(
                address.ss_family,
                bytes,
                source.ptr,
                @intCast(source.len),
            ) == null) source[0] = 0;
        }
    }

    if (count > std.math.maxInt(c_int)) return -1;
    return @intCast(count);
}
