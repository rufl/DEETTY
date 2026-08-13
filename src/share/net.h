#ifndef NOCTTY_SHARE_NET_H
#define NOCTTY_SHARE_NET_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef intptr_t NocttyShareSocket;

#define NOCTTY_SHARE_INVALID_SOCKET ((NocttyShareSocket)-1)

int noctty_share_net_startup(void);
NocttyShareSocket noctty_share_tcp_listen(const char *host, uint16_t port,
                                           uint16_t *bound_port);
NocttyShareSocket noctty_share_tcp_accept(NocttyShareSocket listener);
NocttyShareSocket noctty_share_tcp_connect(const char *host, uint16_t port);
int noctty_share_socket_read(NocttyShareSocket socket, uint8_t *output,
                             size_t capacity);
int noctty_share_socket_write(NocttyShareSocket socket, const uint8_t *bytes,
                              size_t length);
int noctty_share_socket_readable(NocttyShareSocket socket,
                                 uint32_t timeout_milliseconds);
void noctty_share_socket_close(NocttyShareSocket socket);
NocttyShareSocket noctty_share_discovery_open(uint16_t port);
int noctty_share_discovery_announce(NocttyShareSocket socket, uint16_t port,
                                    const uint8_t *bytes, size_t length);
int noctty_share_discovery_receive(NocttyShareSocket socket, uint8_t *output,
                                   size_t capacity, char *source,
                                   size_t source_capacity);

#ifdef __cplusplus
}
#endif

#endif
