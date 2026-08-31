#ifndef NOCTTY_WINDOWS_NATIVE_HOST_H
#define NOCTTY_WINDOWS_NATIVE_HOST_H

#include <stddef.h>
#include <stdint.h>
#include <windows.h>

#define NOCTTY_WINDOWS_HOST_ABI_VERSION 9u

typedef struct {
    int pane_left;
    int pane_top;
    int pane_right;
    int pane_bottom;
    int content_left;
    int content_top;
    int content_right;
    int content_bottom;
} NocttyWindowsPaneGeometry;

typedef struct {
    int theme;
    int font_size_pt;
    int launch_profile;
    int restore_workspace;
} NocttyWindowsPreferences;

typedef struct {
    int kind;
    int value;
} NocttyWindowsMenuAction;
#define NOCTTY_WINDOWS_MENU_PREFERENCE_THEME 1
#define NOCTTY_WINDOWS_MENU_PREFERENCE_FONT 2
#define NOCTTY_WINDOWS_MENU_PREFERENCE_PROFILE 3
#define NOCTTY_WINDOWS_MENU_PREFERENCE_RESTORE 4
#define NOCTTY_WINDOWS_MENU_WORKSPACE_SAVE 5
#define NOCTTY_WINDOWS_MENU_WORKSPACE_RESTORE 6
#define NOCTTY_WINDOWS_MENU_LAUNCH_NOCTED 7

int noctty_windows_decode_menu_command(
    uint32_t command, int restore_workspace, NocttyWindowsMenuAction *output);
int noctty_windows_normalize_preferences(
    int theme, int font_size_pt, int launch_profile, int restore_workspace,
    NocttyWindowsPreferences *output);
uint32_t noctty_windows_blend_rgb(uint32_t foreground, uint32_t background,
                                  uint32_t foreground_weight);
uint32_t noctty_windows_rgb_from_colorref(uint32_t color);
uint32_t noctty_windows_colorref_from_rgb(uint32_t rgb);
int noctty_windows_grid_dimensions(int pixel_width, int pixel_height,
                                   int cell_width, int cell_height,
                                   int *columns, int *rows);
size_t noctty_windows_encode_utf16_input(uint16_t character,
                                         uint16_t *pending_high_surrogate,
                                         uint8_t *output, size_t capacity);
int noctty_windows_compute_pane_geometry(
    int client_left, int client_top, int client_right, int client_bottom,
    uint32_t x_millionths, uint32_t y_millionths,
    uint32_t width_millionths, uint32_t height_millionths, int inset,
    NocttyWindowsPaneGeometry *output);
int noctty_windows_pointer_cell(
    int content_left, int content_top, int content_right, int content_bottom,
    int columns, int rows, int pointer_x, int pointer_y, int clamp,
    int *column, int *row, int *inside);
int noctty_windows_cell_selected(
    int selection_active, int selection_pane, int pane_index,
    int anchor_column, int anchor_row, int extent_column, int extent_row,
    int column, int row);
size_t noctty_windows_special_key_sequence(uintptr_t key,
                                           int application_cursor,
                                           uint8_t *output,
                                           size_t capacity);
int noctty_windows_diagnostics_init(void);
void noctty_windows_diagnostics_write(const uint8_t *bytes, size_t length);
void noctty_windows_diagnostics_deinit(void);

typedef struct NocttyWindowsPty NocttyWindowsPty;
NocttyWindowsPty *noctty_windows_pty_create(
    int index, int columns, int rows, int launch_profile, HWND window,
    UINT output_message);
void noctty_windows_pty_destroy(NocttyWindowsPty *pty);
int noctty_windows_pty_write(NocttyWindowsPty *pty, const uint8_t *bytes,
                             size_t length);
size_t noctty_windows_pty_drain(NocttyWindowsPty *pty, uint8_t *output,
                                size_t capacity);
int noctty_windows_pty_resize(NocttyWindowsPty *pty, int columns, int rows);
int noctty_windows_pty_poll_exit(NocttyWindowsPty *pty, uint32_t *exit_code);
int noctty_windows_pty_exited(const NocttyWindowsPty *pty);
uint32_t noctty_windows_pty_exit_code(const NocttyWindowsPty *pty);
int noctty_windows_launch_nocted(void);
typedef struct NocttyWindowsMenu NocttyWindowsMenu;
NocttyWindowsMenu *noctty_windows_menu_create(HWND window);
void noctty_windows_menu_update(NocttyWindowsMenu *menu, int theme,
                                int font_size_pt, int launch_profile,
                                int restore_workspace, int remote_mode);
void noctty_windows_menu_deinit(NocttyWindowsMenu *menu);
int noctty_windows_fonts_update(HWND window, int font_size_pt, UINT dpi,
                                HFONT *normal, HFONT *bold, int *cell_width,
                                int *cell_height);
void noctty_windows_fonts_deinit(HFONT *normal, HFONT *bold);

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
int noctty_windows_clipboard_paste(HWND owner, void *userdata,
                                    NocttyWindowsWrite write);
int noctty_windows_clipboard_copy(
    HWND owner, void *userdata, int pane_index, NocttyWindowsPaneCopy copy,
    int anchor_column, int anchor_row, int extent_column, int extent_row);

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

#endif
