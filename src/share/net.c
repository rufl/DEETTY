#ifndef _WIN32
#define _POSIX_C_SOURCE 200112L
#define _DEFAULT_SOURCE
#endif

#include "net.h"

#include <stdio.h>
#include <string.h>

#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#include <winsock2.h>
#include <ws2tcpip.h>
typedef SOCKET NativeSocket;
#define NOCTTY_NATIVE_INVALID INVALID_SOCKET
#define noctty_close_socket closesocket
#else
#include <arpa/inet.h>
#include <errno.h>
#include <fcntl.h>
#include <netdb.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <sys/select.h>
#include <unistd.h>
typedef int NativeSocket;
#define NOCTTY_NATIVE_INVALID (-1)
#define noctty_close_socket close
#endif

#define NOCTTY_DISCOVERY_GROUP "239.255.78.84"
#define NOCTTY_DISCOVERY_MAX_BYTES 1024u
#define NOCTTY_CONNECT_TIMEOUT_MS 5000u
#define NOCTTY_IO_TIMEOUT_MS 5000u

#ifdef _WIN32
static INIT_ONCE noctty_winsock_once = INIT_ONCE_STATIC_INIT;
static int noctty_winsock_ready = 0;

static BOOL CALLBACK noctty_initialize_winsock(PINIT_ONCE once, PVOID parameter,
                                                PVOID *context) {
    WSADATA data;
    (void)once;
    (void)parameter;
    (void)context;
    noctty_winsock_ready = WSAStartup(MAKEWORD(2, 2), &data) == 0;
    return TRUE;
}
#endif

static int noctty_configure_tcp_socket(NativeSocket socket_value) {
#ifdef _WIN32
    DWORD timeout = NOCTTY_IO_TIMEOUT_MS;
    return setsockopt(socket_value, SOL_SOCKET, SO_RCVTIMEO,
                      (const char *)&timeout, (int)sizeof(timeout)) == 0 &&
           setsockopt(socket_value, SOL_SOCKET, SO_SNDTIMEO,
                      (const char *)&timeout, (int)sizeof(timeout)) == 0;
#else
    struct timeval timeout;
    timeout.tv_sec = (long)(NOCTTY_IO_TIMEOUT_MS / 1000u);
    timeout.tv_usec = (long)((NOCTTY_IO_TIMEOUT_MS % 1000u) * 1000u);
    return setsockopt(socket_value, SOL_SOCKET, SO_RCVTIMEO, &timeout,
                      (socklen_t)sizeof(timeout)) == 0 &&
           setsockopt(socket_value, SOL_SOCKET, SO_SNDTIMEO, &timeout,
                      (socklen_t)sizeof(timeout)) == 0;
#endif
}

static int noctty_connect_with_timeout(NativeSocket socket_value,
                                       const struct sockaddr *address,
                                       socklen_t address_length) {
    fd_set writable;
    struct timeval timeout;
    int result;
    int socket_error = 0;
#ifdef _WIN32
    u_long nonblocking = 1;
    u_long blocking = 0;
    int error_length = (int)sizeof(socket_error);
    if (ioctlsocket(socket_value, (long)FIONBIO, &nonblocking) != 0) return 0;
#else
    int flags = fcntl(socket_value, F_GETFL, 0);
    socklen_t error_length = (socklen_t)sizeof(socket_error);
    if (flags < 0 || fcntl(socket_value, F_SETFL, flags | O_NONBLOCK) != 0)
        return 0;
#endif
    result = connect(socket_value, address, address_length);
    if (result != 0) {
#ifdef _WIN32
        int error = WSAGetLastError();
        if (error != WSAEWOULDBLOCK && error != WSAEINPROGRESS &&
            error != WSAEINVAL)
            goto failed;
#else
        if (errno != EINPROGRESS) goto failed;
#endif
        FD_ZERO(&writable);
        FD_SET(socket_value, &writable);
        timeout.tv_sec = (long)(NOCTTY_CONNECT_TIMEOUT_MS / 1000u);
        timeout.tv_usec =
            (long)((NOCTTY_CONNECT_TIMEOUT_MS % 1000u) * 1000u);
#ifdef _WIN32
        result = select(0, NULL, &writable, NULL, &timeout);
#else
        result = select(socket_value + 1, NULL, &writable, NULL, &timeout);
#endif
        if (result <= 0 || !FD_ISSET(socket_value, &writable) ||
            getsockopt(socket_value, SOL_SOCKET, SO_ERROR,
                       (char *)&socket_error, &error_length) != 0 ||
            socket_error != 0)
            goto failed;
    }
#ifdef _WIN32
    if (ioctlsocket(socket_value, (long)FIONBIO, &blocking) != 0) return 0;
#else
    if (fcntl(socket_value, F_SETFL, flags) != 0) return 0;
#endif
    return noctty_configure_tcp_socket(socket_value);

failed:
#ifdef _WIN32
    (void)ioctlsocket(socket_value, (long)FIONBIO, &blocking);
#else
    (void)fcntl(socket_value, F_SETFL, flags);
#endif
    return 0;
}

static NativeSocket noctty_native_socket(NocttyShareSocket socket) {
    return (NativeSocket)socket;
}

static NocttyShareSocket noctty_share_socket(NativeSocket socket) {
    if (socket == NOCTTY_NATIVE_INVALID) return NOCTTY_SHARE_INVALID_SOCKET;
    return (NocttyShareSocket)socket;
}

int noctty_share_net_startup(void) {
#ifdef _WIN32
    if (!InitOnceExecuteOnce(&noctty_winsock_once, noctty_initialize_winsock,
                             NULL, NULL))
        return 0;
    return noctty_winsock_ready;
#else
    return 1;
#endif
}

static NativeSocket noctty_open_tcp(const char *host, uint16_t port,
                                    int passive, int connect_socket,
                                    uint16_t *bound_port) {
    struct addrinfo hints;
    struct addrinfo *addresses = NULL;
    struct addrinfo *current;
    char service[6];
    NativeSocket result = NOCTTY_NATIVE_INVALID;
    int yes = 1;
    int formatted = snprintf(service, sizeof(service), "%u", (unsigned)port);
    if (formatted <= 0 || (size_t)formatted >= sizeof(service))
        return NOCTTY_NATIVE_INVALID;
    memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;
    hints.ai_protocol = IPPROTO_TCP;
    hints.ai_flags = passive ? AI_PASSIVE : 0;
    if (getaddrinfo(host != NULL && host[0] != '\0' ? host : NULL, service,
                    &hints, &addresses) != 0)
        return NOCTTY_NATIVE_INVALID;
    for (current = addresses; current != NULL; current = current->ai_next) {
        result = socket(current->ai_family, current->ai_socktype,
                        current->ai_protocol);
        if (result == NOCTTY_NATIVE_INVALID) continue;
        if (!connect_socket) {
            (void)setsockopt(result, SOL_SOCKET, SO_REUSEADDR,
                             (const char *)&yes, (socklen_t)sizeof(yes));
            if (bind(result, current->ai_addr,
                     (socklen_t)current->ai_addrlen) == 0 &&
                listen(result, 8) == 0)
                break;
        } else if (noctty_connect_with_timeout(
                       result, current->ai_addr,
                       (socklen_t)current->ai_addrlen)) {
            break;
        }
        noctty_close_socket(result);
        result = NOCTTY_NATIVE_INVALID;
    }
    freeaddrinfo(addresses);
    if (result != NOCTTY_NATIVE_INVALID && !connect_socket &&
        bound_port != NULL) {
        struct sockaddr_storage address;
        socklen_t length = (socklen_t)sizeof(address);
        if (getsockname(result, (struct sockaddr *)&address, &length) == 0) {
            if (address.ss_family == AF_INET)
                *bound_port = ntohs(((struct sockaddr_in *)&address)->sin_port);
            else if (address.ss_family == AF_INET6)
                *bound_port = ntohs(((struct sockaddr_in6 *)&address)->sin6_port);
        }
    }
    return result;
}

NocttyShareSocket noctty_share_tcp_listen(const char *host, uint16_t port,
                                           uint16_t *bound_port) {
    if (!noctty_share_net_startup()) return NOCTTY_SHARE_INVALID_SOCKET;
    return noctty_share_socket(noctty_open_tcp(host, port, 1, 0, bound_port));
}

NocttyShareSocket noctty_share_tcp_accept(NocttyShareSocket listener) {
    NativeSocket accepted = accept(noctty_native_socket(listener), NULL, NULL);
    if (accepted != NOCTTY_NATIVE_INVALID &&
        !noctty_configure_tcp_socket(accepted)) {
        noctty_close_socket(accepted);
        accepted = NOCTTY_NATIVE_INVALID;
    }
    return noctty_share_socket(accepted);
}

NocttyShareSocket noctty_share_tcp_connect(const char *host, uint16_t port) {
    if (!noctty_share_net_startup() || host == NULL || host[0] == '\0')
        return NOCTTY_SHARE_INVALID_SOCKET;
    return noctty_share_socket(noctty_open_tcp(host, port, 0, 1, NULL));
}

int noctty_share_socket_read(NocttyShareSocket socket, uint8_t *output,
                             size_t capacity) {
    if (output == NULL || capacity == 0 || capacity > 65535u) return -1;
#ifdef _WIN32
    return recv(noctty_native_socket(socket), (char *)output, (int)capacity, 0);
#else
    ssize_t count = recv(noctty_native_socket(socket), output, capacity, 0);
    return count > INT32_MAX ? -1 : (int)count;
#endif
}

int noctty_share_socket_write(NocttyShareSocket socket, const uint8_t *bytes,
                              size_t length) {
    size_t offset = 0;
    if (bytes == NULL || length > 65535u) return -1;
    while (offset < length) {
        size_t remaining = length - offset;
#ifdef _WIN32
        int count = send(noctty_native_socket(socket),
                         (const char *)bytes + offset, (int)remaining, 0);
#else
        ssize_t count = send(noctty_native_socket(socket), bytes + offset,
                             remaining,
#ifdef MSG_NOSIGNAL
                             MSG_NOSIGNAL
#else
                             0
#endif
        );
#endif
        if (count <= 0) return -1;
        offset += (size_t)count;
    }
    return (int)length;
}

int noctty_share_socket_readable(NocttyShareSocket socket,
                                 uint32_t timeout_milliseconds) {
    NativeSocket native = noctty_native_socket(socket);
    fd_set readable;
    struct timeval timeout;
    int result;
    FD_ZERO(&readable);
    FD_SET(native, &readable);
    timeout.tv_sec = (long)(timeout_milliseconds / 1000u);
    timeout.tv_usec = (long)((timeout_milliseconds % 1000u) * 1000u);
#ifdef _WIN32
    result = select(0, &readable, NULL, NULL, &timeout);
#else
    result = select(native + 1, &readable, NULL, NULL, &timeout);
#endif
    if (result < 0) return -1;
    return result > 0 && FD_ISSET(native, &readable) ? 1 : 0;
}

void noctty_share_socket_close(NocttyShareSocket socket) {
    if (socket == NOCTTY_SHARE_INVALID_SOCKET) return;
#ifdef _WIN32
    (void)shutdown(noctty_native_socket(socket), SD_BOTH);
#else
    (void)shutdown(noctty_native_socket(socket), SHUT_RDWR);
#endif
    noctty_close_socket(noctty_native_socket(socket));
}

NocttyShareSocket noctty_share_discovery_open(uint16_t port) {
    NativeSocket socket_value;
    struct sockaddr_in bind_address;
    struct ip_mreq membership;
    int yes = 1;
    int multicast_hops = 1;
    if (!noctty_share_net_startup()) return NOCTTY_SHARE_INVALID_SOCKET;
    socket_value = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
    if (socket_value == NOCTTY_NATIVE_INVALID)
        return NOCTTY_SHARE_INVALID_SOCKET;
    (void)setsockopt(socket_value, SOL_SOCKET, SO_REUSEADDR,
                     (const char *)&yes, (socklen_t)sizeof(yes));
    (void)setsockopt(socket_value, SOL_SOCKET, SO_BROADCAST,
                     (const char *)&yes, (socklen_t)sizeof(yes));
    (void)setsockopt(socket_value, IPPROTO_IP, IP_MULTICAST_TTL,
                     (const char *)&multicast_hops,
                     (socklen_t)sizeof(multicast_hops));
    (void)setsockopt(socket_value, IPPROTO_IP, IP_MULTICAST_LOOP,
                     (const char *)&multicast_hops,
                     (socklen_t)sizeof(multicast_hops));
    memset(&bind_address, 0, sizeof(bind_address));
    bind_address.sin_family = AF_INET;
    bind_address.sin_port = htons(port);
    bind_address.sin_addr.s_addr = htonl(INADDR_ANY);
    if (bind(socket_value, (struct sockaddr *)&bind_address,
             (socklen_t)sizeof(bind_address)) != 0) {
        noctty_close_socket(socket_value);
        return NOCTTY_SHARE_INVALID_SOCKET;
    }
    memset(&membership, 0, sizeof(membership));
    membership.imr_multiaddr.s_addr = inet_addr(NOCTTY_DISCOVERY_GROUP);
    membership.imr_interface.s_addr = htonl(INADDR_ANY);
    if (setsockopt(socket_value, IPPROTO_IP, IP_ADD_MEMBERSHIP,
                   (const char *)&membership,
                   (socklen_t)sizeof(membership)) != 0) {
        noctty_close_socket(socket_value);
        return NOCTTY_SHARE_INVALID_SOCKET;
    }
    return noctty_share_socket(socket_value);
}

int noctty_share_discovery_announce(NocttyShareSocket socket, uint16_t port,
                                    const uint8_t *bytes, size_t length) {
    struct sockaddr_in target;
    int multicast_count;
    int broadcast_count;
    int loopback_count;
    if (bytes == NULL || length == 0 || length > NOCTTY_DISCOVERY_MAX_BYTES ||
        length > INT32_MAX)
        return -1;
    memset(&target, 0, sizeof(target));
    target.sin_family = AF_INET;
    target.sin_port = htons(port);
    target.sin_addr.s_addr = inet_addr(NOCTTY_DISCOVERY_GROUP);
#ifdef _WIN32
    multicast_count =
        sendto(noctty_native_socket(socket), (const char *)bytes, (int)length,
               0, (struct sockaddr *)&target, (int)sizeof(target));
#else
    {
        ssize_t count =
            sendto(noctty_native_socket(socket), bytes, length, 0,
                   (struct sockaddr *)&target, (socklen_t)sizeof(target));
        multicast_count = count > INT32_MAX ? -1 : (int)count;
    }
#endif
    target.sin_addr.s_addr = htonl(INADDR_BROADCAST);
#ifdef _WIN32
    broadcast_count =
        sendto(noctty_native_socket(socket), (const char *)bytes, (int)length,
               0, (struct sockaddr *)&target, (int)sizeof(target));
#else
    {
        ssize_t count =
            sendto(noctty_native_socket(socket), bytes, length, 0,
                   (struct sockaddr *)&target, (socklen_t)sizeof(target));
        broadcast_count = count > INT32_MAX ? -1 : (int)count;
    }
#endif
    target.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
#ifdef _WIN32
    loopback_count =
        sendto(noctty_native_socket(socket), (const char *)bytes, (int)length,
               0, (struct sockaddr *)&target, (int)sizeof(target));
#else
    {
        ssize_t count =
            sendto(noctty_native_socket(socket), bytes, length, 0,
                   (struct sockaddr *)&target, (socklen_t)sizeof(target));
        loopback_count = count > INT32_MAX ? -1 : (int)count;
    }
#endif
    if (multicast_count == (int)length || broadcast_count == (int)length ||
        loopback_count == (int)length)
        return (int)length;
    return -1;
}

int noctty_share_discovery_receive(NocttyShareSocket socket, uint8_t *output,
                                   size_t capacity, char *source,
                                   size_t source_capacity) {
    struct sockaddr_storage address;
    socklen_t address_length = (socklen_t)sizeof(address);
    void *address_bytes = NULL;
    if (output == NULL || capacity == 0 || capacity > NOCTTY_DISCOVERY_MAX_BYTES ||
        source == NULL || source_capacity == 0)
        return -1;
#ifdef _WIN32
    int count = recvfrom(noctty_native_socket(socket), (char *)output,
                         (int)capacity, 0, (struct sockaddr *)&address,
                         (int *)&address_length);
#else
    ssize_t count = recvfrom(noctty_native_socket(socket), output, capacity, 0,
                             (struct sockaddr *)&address, &address_length);
#endif
    if (count <= 0) return (int)count;
    if (address.ss_family == AF_INET)
        address_bytes = &((struct sockaddr_in *)&address)->sin_addr;
    else if (address.ss_family == AF_INET6)
        address_bytes = &((struct sockaddr_in6 *)&address)->sin6_addr;
    if (address_bytes == NULL) {
        source[0] = '\0';
    } else {
#ifdef _WIN32
        if (inet_ntop(address.ss_family, address_bytes, source,
                      source_capacity) == NULL)
#else
        if (source_capacity > (size_t)INT32_MAX ||
            inet_ntop(address.ss_family, address_bytes, source,
                      (socklen_t)source_capacity) == NULL)
#endif
            source[0] = '\0';
    }
    return count > INT32_MAX ? -1 : (int)count;
}
