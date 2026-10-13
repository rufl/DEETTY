#if defined(_WIN32) || defined(_WIN64)
#define WIN32_LEAN_AND_MEAN 1
#define _FORTIFY_SOURCE 0
#include <winsock2.h>
#include <ws2tcpip.h>
#else
#define _FORTIFY_SOURCE 0
#define _POSIX_C_SOURCE 200112L
#define _DEFAULT_SOURCE 1
#include <arpa/inet.h>
#include <errno.h>
#include <fcntl.h>
#include <netdb.h>
#include <netinet/in.h>
#include <poll.h>
#include <sys/socket.h>
#include <unistd.h>
#endif
