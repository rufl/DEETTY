#ifndef NOCTTY_WINDOWS_NATIVE_HOST_H
#define NOCTTY_WINDOWS_NATIVE_HOST_H

#include <stddef.h>
#include <stdint.h>
#include <windows.h>

#define NOCTTY_WINDOWS_HOST_ABI_VERSION 9u

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
typedef int (*NocttyWindowsNextTab)(void *);
typedef int (*NocttyWindowsPaneCount)(void *);
typedef int (*NocttyWindowsPaneLayout)(void *, int, uint32_t *, uint32_t *,
                                       uint32_t *, uint32_t *, int *, int *);
typedef int (*NocttyWindowsPaneDimensions)(void *, int, uint16_t *, uint16_t *);
typedef uint64_t (*NocttyWindowsPaneCell)(void *, int, int, int);
typedef int (*NocttyWindowsPaneCellText)(void *, int, int, int, uint8_t *,
                                         size_t);
typedef uint32_t (*NocttyWindowsPaneColorRgb)(void *, int, uint32_t);
typedef uint32_t (*NocttyWindowsPaneCursor)(void *, int);
typedef int (*NocttyWindowsPaneSelect)(void *, int);
typedef int (*NocttyWindowsPaneFeed)(void *, int, const uint8_t *, size_t);
typedef int (*NocttyWindowsPaneTakeReply)(void *, int, uint8_t *, size_t);
typedef int (*NocttyWindowsPaneResize)(void *, int, int, int);
typedef int (*NocttyWindowsWorkspaceAction)(void *, int, int, int);
typedef int (*NocttyWindowsActivePane)(void *);
typedef uint32_t (*NocttyWindowsWorkspaceClose)(void *, int);

typedef uint32_t (*NocttyWindowsPaneMouseMode)(void *, int);
typedef int (*NocttyWindowsPaneMouseEncode)(void *, int, int, int, int, int,
                                            int, uint8_t *, size_t);
typedef int (*NocttyWindowsPaneCopy)(void *, int, uint8_t *, size_t, int, int,
                                    int, int);

#define NOCTTY_WINDOWS_MOUSE_TRACKING_MASK 0x3u
#define NOCTTY_WINDOWS_MOUSE_ENCODING_SGR 0x100u
#define NOCTTY_WINDOWS_MOUSE_PRESS 0
#define NOCTTY_WINDOWS_MOUSE_RELEASE 1
#define NOCTTY_WINDOWS_MOUSE_MOTION 2
#define NOCTTY_WINDOWS_MOUSE_WHEEL 3
#define NOCTTY_WINDOWS_MOUSE_MOD_SHIFT 1
#define NOCTTY_WINDOWS_MOUSE_MOD_ALT 2
#define NOCTTY_WINDOWS_MOUSE_MOD_CONTROL 4
#define NOCTTY_WINDOWS_ACTION_NEW_TAB 1
typedef int (*NocttyWindowsPreferenceGet)(void *, int);
typedef int (*NocttyWindowsPreferenceSet)(void *, int, int);
typedef int (*NocttyWindowsWorkspacePersistence)(void *, int, int, int);
#define NOCTTY_WINDOWS_ACTION_SPLIT_DOWN 2
#define NOCTTY_WINDOWS_ACTION_SPLIT_LEFT 3
#define NOCTTY_WINDOWS_CLOSE_PANE 1
#define NOCTTY_WINDOWS_CLOSE_TAB 2
#define NOCTTY_WINDOWS_QUERY_CLOSE_PANE 3
#define NOCTTY_WINDOWS_QUERY_CLOSE_TAB 4

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
    NocttyWindowsNextTab next_tab;
    NocttyWindowsPaneCount pane_count;
    NocttyWindowsPaneLayout pane_layout;
    NocttyWindowsPaneDimensions pane_dimensions;
    NocttyWindowsPaneCell pane_cell;
    NocttyWindowsPaneCellText pane_cell_text;
    NocttyWindowsPaneColorRgb pane_color_rgb;
    NocttyWindowsPaneCursor pane_cursor;
    NocttyWindowsPaneSelect pane_select;
    NocttyWindowsPaneFeed pane_feed;
    NocttyWindowsPaneTakeReply pane_take_reply;
    NocttyWindowsPaneResize pane_resize;
    NocttyWindowsWorkspaceAction workspace_action;
    NocttyWindowsActivePane active_pane;
    NocttyWindowsWorkspaceClose workspace_close;
    NocttyWindowsActivePane remote_pane;
    NocttyWindowsPreferenceGet preference_get;
    NocttyWindowsPreferenceSet preference_set;
    NocttyWindowsWorkspacePersistence workspace_persistence;
    NocttyWindowsPaneMouseMode pane_mouse_mode;
    NocttyWindowsPaneMouseEncode pane_mouse_encode;
    NocttyWindowsPaneCopy pane_copy;
} NocttyWindowsCallbacks;

int noctty_windows_host_run(HINSTANCE instance, int show_command,
                            const NocttyWindowsCallbacks *callbacks);
void noctty_windows_show_version(HINSTANCE instance, const wchar_t *version);

#endif
