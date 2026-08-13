#ifndef NOCTTY_WINDOWS_NATIVE_HOST_H
#define NOCTTY_WINDOWS_NATIVE_HOST_H

#include <stddef.h>
#include <stdint.h>
#include <windows.h>

#define NOCTTY_WINDOWS_HOST_ABI_VERSION 4u

typedef int (*NocttyWindowsFeed)(void *, const uint8_t *, size_t);
typedef int (*NocttyWindowsWrite)(void *, const uint8_t *, size_t);
typedef int (*NocttyWindowsTakeReply)(void *, uint8_t *, size_t);
typedef int (*NocttyWindowsTakeRemote)(void *, uint8_t *, size_t);
typedef uint64_t (*NocttyWindowsCell)(void *, int, int);
typedef int (*NocttyWindowsCellText)(void *, int, int, uint8_t *, size_t);
typedef uint32_t (*NocttyWindowsColorRgb)(void *, uint32_t);
typedef uint32_t (*NocttyWindowsCursor)(void *);
typedef int (*NocttyWindowsTitle)(void *, uint8_t *, size_t);
typedef int (*NocttyWindowsResize)(void *, int, int);
typedef int (*NocttyWindowsScroll)(void *, int);
typedef int (*NocttyWindowsCursorMode)(void *);
typedef int (*NocttyWindowsSmokeReady)(void *);
typedef int (*NocttyWindowsStart)(void *);
typedef int (*NocttyWindowsStop)(void *);
typedef int (*NocttyWindowsNextStream)(void *);

typedef struct {
    uint32_t abi_version;
    uint32_t struct_size;
    void *userdata;
    NocttyWindowsFeed feed;
    NocttyWindowsWrite write;
    NocttyWindowsTakeReply take_reply;
    NocttyWindowsTakeRemote take_remote;
    NocttyWindowsCell cell;
    NocttyWindowsCellText cell_text;
    NocttyWindowsColorRgb color_rgb;
    NocttyWindowsCursor cursor;
    NocttyWindowsTitle title;
    NocttyWindowsResize resize;
    NocttyWindowsScroll scroll;
    NocttyWindowsCursorMode cursor_mode;
    NocttyWindowsSmokeReady smoke_ready;
    NocttyWindowsStart start;
    NocttyWindowsStop stop;
    NocttyWindowsNextStream next_stream;
} NocttyWindowsCallbacks;

int noctty_windows_host_run(HINSTANCE instance, int show_command,
                            const NocttyWindowsCallbacks *callbacks);
void noctty_windows_show_version(HINSTANCE instance, const wchar_t *version);

#endif
