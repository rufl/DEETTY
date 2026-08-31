/*
 * Win32/GDI and ConPTY adapter for the experimental Windows host.
 *
 * Zig owns terminal/workspace state through native_host.h. This file owns all
 * Win32 HANDLE, HWND, timer, clipboard, and rendering lifetimes; every handle
 * acquired here must be released here so platform concerns do not cross the
 * shared terminal boundary.
 */
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX

#include "native_host.h"

#include <dbghelp.h>
#include <shellapi.h>
#include <windowsx.h>
#include <limits.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define NOCTTY_TIMER_ID 1u
#define NOCTTY_TIMER_INTERVAL_MS 16u
#define NOCTTY_OUTPUT_RING_BYTES (1u * 1024u * 1024u)
#define NOCTTY_OUTPUT_DRAIN_BYTES (128u * 1024u)
#define NOCTTY_PASTE_BYTES_MAX (8u * 1024u * 1024u)
#define NOCTTY_COPY_BYTES_MAX (2u * 1024u * 1024u)
#define NOCTTY_DEFAULT_COLUMNS 120
#define NOCTTY_DEFAULT_ROWS 36
#define NOCTTY_MAX_SESSIONS 32
#define NOCTTY_WINDOW_WIDTH 1120
#define NOCTTY_WINDOW_HEIGHT 720
#define NOCTTY_WINDOW_MIN_WIDTH 640
#define NOCTTY_WINDOW_MIN_HEIGHT 360
#define NOCTTY_WM_OUTPUT (WM_APP + 1u)
#define NOCTTY_DEFAULT_FOREGROUND 0xd8dee9u
#define NOCTTY_DEFAULT_BACKGROUND 0x0b0d12u
#define NOCTTY_DEFAULT_COLOR_ID 0x0fffu
#define NOCTTY_PREF_THEME 1
#define NOCTTY_PREF_FONT_SIZE 2
#define NOCTTY_PREF_LAUNCH_PROFILE 3
#define NOCTTY_PREF_RESTORE_WORKSPACE 4
#define NOCTTY_WORKSPACE_SAVE 1
#define NOCTTY_WORKSPACE_RESTORE 2
#define NOCTTY_MENU_THEME_DARK 40001
#define NOCTTY_MENU_THEME_HIGH_CONTRAST 40002
#define NOCTTY_MENU_FONT_11 40011
#define NOCTTY_MENU_FONT_13 40013
#define NOCTTY_MENU_FONT_16 40016
#define NOCTTY_MENU_FONT_18 40018
#define NOCTTY_MENU_PROFILE_POWERSHELL 40021
#define NOCTTY_MENU_PROFILE_COMMAND 40022
#define NOCTTY_MENU_RESTORE_STARTUP 40031
#define NOCTTY_MENU_WORKSPACE_SAVE 40041
#define NOCTTY_MENU_WORKSPACE_RESTORE 40042
#define NOCTTY_MENU_OPEN_NOCTED 40051

typedef struct NocttyWindowsHost NocttyWindowsHost;

typedef struct {
    NocttyWindowsHost *host;
    int index;
    int columns;
    int rows;
    HPCON pseudo_console;
    HANDLE input_write;
    HANDLE output_read;
    HANDLE process;
    HANDLE reader_thread;
    CRITICAL_SECTION output_lock;
    uint8_t *output_ring;
    size_t output_start;
    size_t output_length;
    volatile LONG stopping;
    int process_exited;
    DWORD process_exit_code;
} NocttyWindowsSession;

typedef struct {
    int pane_index;
    int column;
    int selected;
    int host_active;
    int row;
    int inside_content;
    RECT pane;
    RECT content;
    int columns;
    int rows;
} NocttyPaneHit;

struct NocttyWindowsHost {
    const NocttyWindowsCallbacks *callbacks;
    HWND window;
    HFONT font_normal;
    HFONT font_bold;
    int cell_width;
    int cell_height;
    int columns;
    HMENU menu;
    HMENU settings_menu;
    HMENU theme_menu;
    HMENU font_menu;
    HMENU profile_menu;
    HMENU workspace_menu;
    int theme;
    int font_size_pt;
    int launch_profile;
    int restore_workspace;
    uint32_t foreground;
    uint32_t background;
    int settings_menu_ready;
    int preferences_ready;
    int rows;
    NocttyWindowsSession sessions[NOCTTY_MAX_SESSIONS];
    int remote_mode;
    int suppress_character;
    int smoke_mode;
    int exit_code;
    unsigned paint_count;
    unsigned smoke_ticks;
    unsigned smoke_marker_paint_count;
    int smoke_marker_seen;
    WCHAR pending_high_surrogate;
    int selection_active;
    int selection_dragging;
    int selection_pane;
    int selection_anchor_column;
    int selection_anchor_row;
    int selection_extent_column;
    int selection_extent_row;
    unsigned pressed_buttons;
    int application_capture;
    int capture_pane;
    int capture_last_column;
    int capture_last_row;
    int smoke_mouse_input;
    int smoke_coordinates;
    int smoke_selection;
    int smoke_clipboard;
};

static HANDLE noctty_log_file = INVALID_HANDLE_VALUE;
static WCHAR noctty_dump_path[MAX_PATH * 2];

static void noctty_log(const char *format, ...);
static void noctty_update_title(NocttyWindowsHost *host);
static void noctty_resize_terminal(NocttyWindowsHost *host, int width, int height);
static void noctty_drain_output(NocttyWindowsHost *host, int session_index);
static void noctty_drain_remote_input(NocttyWindowsHost *host);
static LRESULT CALLBACK noctty_window_proc(HWND window, UINT message,
                                           WPARAM word, LPARAM long_value);

static COLORREF noctty_color_ref(uint32_t rgb) {
    return RGB((rgb >> 16u) & 0xffu, (rgb >> 8u) & 0xffu, rgb & 0xffu);
}

static uint32_t noctty_blend(uint32_t foreground, uint32_t background,
                             unsigned foreground_weight) {
    unsigned background_weight = 255u - foreground_weight;
    unsigned red = (((foreground >> 16u) & 0xffu) * foreground_weight +
                    ((background >> 16u) & 0xffu) * background_weight) /
                   255u;
    unsigned green = (((foreground >> 8u) & 0xffu) * foreground_weight +
                      ((background >> 8u) & 0xffu) * background_weight) /
                     255u;
    unsigned blue = ((foreground & 0xffu) * foreground_weight +
                     (background & 0xffu) * background_weight) /
                    255u;
    return (red << 16u) | (green << 8u) | blue;
}

static uint32_t noctty_terminal_color(NocttyWindowsHost *host, int pane_index,
                                      uint32_t color_id,
                                      uint32_t fallback) {
    uint32_t value;
    if (color_id == NOCTTY_DEFAULT_COLOR_ID) return fallback;
    value = pane_index >= 0
                ? host->callbacks->pane_color_rgb(
                      host->callbacks->userdata, pane_index, color_id)
                : host->callbacks->color_rgb(
                      host->callbacks->userdata, color_id);
    return value == 0xffffffffu ? fallback : value;
}

static void noctty_close_handle(HANDLE *handle) {
    if (*handle != NULL && *handle != INVALID_HANDLE_VALUE) {
        CloseHandle(*handle);
        *handle = NULL;
    }
}

static LONG WINAPI noctty_unhandled_exception(EXCEPTION_POINTERS *exception) {
    HANDLE dump;
    MINIDUMP_EXCEPTION_INFORMATION information;

    noctty_log("crash exception_code=0x%08lx address=%p\r\n",
               exception->ExceptionRecord->ExceptionCode,
               exception->ExceptionRecord->ExceptionAddress);
    dump = CreateFileW(noctty_dump_path, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS,
                       FILE_ATTRIBUTE_NORMAL, NULL);
    if (dump != INVALID_HANDLE_VALUE) {
        information.ThreadId = GetCurrentThreadId();
        information.ExceptionPointers = exception;
        information.ClientPointers = FALSE;
        MiniDumpWriteDump(GetCurrentProcess(), GetCurrentProcessId(), dump,
                          MiniDumpNormal, &information, NULL, NULL);
        CloseHandle(dump);
    }
    return EXCEPTION_EXECUTE_HANDLER;
}

static void noctty_initialize_logging(void) {
    WCHAR base[MAX_PATH];
    WCHAR app_directory[MAX_PATH * 2];
    WCHAR log_directory[MAX_PATH * 2];
    WCHAR log_path[MAX_PATH * 2];
    SYSTEMTIME time;
    DWORD length;
    int count;

    length = GetEnvironmentVariableW(L"LOCALAPPDATA", base, MAX_PATH);
    if (length == 0 || length >= MAX_PATH) {
        length = GetTempPathW(MAX_PATH, base);
        if (length == 0 || length >= MAX_PATH) return;
    }
    count = swprintf(app_directory, sizeof(app_directory) / sizeof(WCHAR),
                     L"%ls\\NOCTTY", base);
    if (count < 0 || (size_t)count >= sizeof(app_directory) / sizeof(WCHAR))
        return;
    CreateDirectoryW(app_directory, NULL);
    count = swprintf(log_directory, sizeof(log_directory) / sizeof(WCHAR),
                     L"%ls\\logs", app_directory);
    if (count < 0 || (size_t)count >= sizeof(log_directory) / sizeof(WCHAR))
        return;
    CreateDirectoryW(log_directory, NULL);

    GetLocalTime(&time);
    count = swprintf(
        log_path, sizeof(log_path) / sizeof(WCHAR),
        L"%ls\\noctty-%04u%02u%02u-%02u%02u%02u-%lu.log", log_directory,
        time.wYear, time.wMonth, time.wDay, time.wHour, time.wMinute,
        time.wSecond, GetCurrentProcessId());
    if (count < 0 || (size_t)count >= sizeof(log_path) / sizeof(WCHAR)) return;
    noctty_log_file = CreateFileW(log_path, FILE_APPEND_DATA, FILE_SHARE_READ,
                                  NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL,
                                  NULL);
    count = swprintf(
        noctty_dump_path, sizeof(noctty_dump_path) / sizeof(WCHAR),
        L"%ls\\noctty-%04u%02u%02u-%02u%02u%02u-%lu.dmp", log_directory,
        time.wYear, time.wMonth, time.wDay, time.wHour, time.wMinute,
        time.wSecond, GetCurrentProcessId());
    if (count < 0 ||
        (size_t)count >= sizeof(noctty_dump_path) / sizeof(WCHAR)) {
        noctty_dump_path[0] = L'\0';
    }
    SetUnhandledExceptionFilter(noctty_unhandled_exception);
    noctty_log("windows_launch pid=%lu conpty=true renderer=win32_gdi "
               "telemetry=false uploads=false\r\n",
               GetCurrentProcessId());
}

static void noctty_log(const char *format, ...) {
    char buffer[2048];
    DWORD written = 0;
    int length;
    va_list arguments;

    if (noctty_log_file == INVALID_HANDLE_VALUE) return;
    va_start(arguments, format);
    length = vsnprintf(buffer, sizeof(buffer), format, arguments);
    va_end(arguments);
    if (length <= 0) return;
    if ((size_t)length > sizeof(buffer)) length = (int)sizeof(buffer);
    WriteFile(noctty_log_file, buffer, (DWORD)length, &written, NULL);
}

static int noctty_create_fonts(NocttyWindowsHost *host, UINT dpi) {
    HDC device;
    HFONT previous;
    TEXTMETRICW metrics;
    int height;

    if (host->font_normal != NULL) DeleteObject(host->font_normal);
    if (host->font_bold != NULL) DeleteObject(host->font_bold);
    height = -MulDiv(host->font_size_pt, (int)dpi, 72);
    host->font_normal = CreateFontW(
        height, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE, DEFAULT_CHARSET,
        OUT_TT_PRECIS, CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY,
        FIXED_PITCH | FF_MODERN, L"Cascadia Mono");
    host->font_bold = CreateFontW(
        height, 0, 0, 0, FW_BOLD, FALSE, FALSE, FALSE, DEFAULT_CHARSET,
        OUT_TT_PRECIS, CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY,
        FIXED_PITCH | FF_MODERN, L"Cascadia Mono");
    if (host->font_normal == NULL || host->font_bold == NULL) return 0;

    device = GetDC(host->window);
    if (device == NULL) return 0;
    previous = SelectObject(device, host->font_normal);
    if (!GetTextMetricsW(device, &metrics)) {
        SelectObject(device, previous);
        ReleaseDC(host->window, device);
        return 0;
    }
    SelectObject(device, previous);
    ReleaseDC(host->window, device);
    host->cell_width = metrics.tmAveCharWidth > 0 ? metrics.tmAveCharWidth : 9;
    host->cell_height = metrics.tmHeight + metrics.tmExternalLeading;
    if (host->cell_height < 1) host->cell_height = 18;
    return 1;
}

static uint32_t noctty_rgb_from_colorref(COLORREF color) {
    return ((color & 0xffu) << 16u) | (color & 0xff00u) |
           ((color >> 16u) & 0xffu);
}

static void noctty_apply_theme(NocttyWindowsHost *host) {
    if (host->theme == 1) {
        host->foreground =
            noctty_rgb_from_colorref(GetSysColor(COLOR_WINDOWTEXT));
        host->background = noctty_rgb_from_colorref(GetSysColor(COLOR_WINDOW));
    } else {
        host->foreground = NOCTTY_DEFAULT_FOREGROUND;
        host->background = NOCTTY_DEFAULT_BACKGROUND;
    }
}

static int noctty_load_preferences(NocttyWindowsHost *host) {
    int theme = host->callbacks->preference_get(host->callbacks->userdata,
                                                NOCTTY_PREF_THEME);
    int font_size = host->callbacks->preference_get(
        host->callbacks->userdata, NOCTTY_PREF_FONT_SIZE);
    int profile = host->callbacks->preference_get(
        host->callbacks->userdata, NOCTTY_PREF_LAUNCH_PROFILE);
    int restore = host->callbacks->preference_get(
        host->callbacks->userdata, NOCTTY_PREF_RESTORE_WORKSPACE);
    int valid = (theme == 0 || theme == 1) &&
                font_size >= 10 && font_size <= 24 &&
                (profile == 0 || profile == 1) &&
                (restore == 0 || restore == 1);
    host->theme = theme == 1 ? 1 : 0;
    host->font_size_pt =
        font_size >= 10 && font_size <= 24 ? font_size : 13;
    host->launch_profile = profile == 1 ? 1 : 0;
    host->restore_workspace = restore == 0 ? 0 : 1;
    host->preferences_ready = valid;
    noctty_apply_theme(host);
    return valid;
}

static void noctty_update_menu(NocttyWindowsHost *host) {
    UINT workspace_state = host->remote_mode ? MF_GRAYED : MF_ENABLED;
    if (host->menu == NULL) return;
    CheckMenuRadioItem(host->theme_menu, NOCTTY_MENU_THEME_DARK,
                       NOCTTY_MENU_THEME_HIGH_CONTRAST,
                       host->theme == 1 ? NOCTTY_MENU_THEME_HIGH_CONTRAST
                                        : NOCTTY_MENU_THEME_DARK,
                       MF_BYCOMMAND);
    CheckMenuRadioItem(host->font_menu, NOCTTY_MENU_FONT_11,
                       NOCTTY_MENU_FONT_18,
                       host->font_size_pt == 11
                           ? NOCTTY_MENU_FONT_11
                           : host->font_size_pt == 16
                                 ? NOCTTY_MENU_FONT_16
                                 : host->font_size_pt == 18
                                       ? NOCTTY_MENU_FONT_18
                                       : NOCTTY_MENU_FONT_13,
                       MF_BYCOMMAND);
    CheckMenuRadioItem(host->profile_menu, NOCTTY_MENU_PROFILE_POWERSHELL,
                       NOCTTY_MENU_PROFILE_COMMAND,
                       host->launch_profile == 1
                           ? NOCTTY_MENU_PROFILE_COMMAND
                           : NOCTTY_MENU_PROFILE_POWERSHELL,
                       MF_BYCOMMAND);
    CheckMenuItem(host->settings_menu, NOCTTY_MENU_RESTORE_STARTUP,
                  MF_BYCOMMAND |
                      (host->restore_workspace ? MF_CHECKED : MF_UNCHECKED));
    EnableMenuItem(host->profile_menu, NOCTTY_MENU_PROFILE_POWERSHELL,
                   MF_BYCOMMAND | workspace_state);
    EnableMenuItem(host->profile_menu, NOCTTY_MENU_PROFILE_COMMAND,
                   MF_BYCOMMAND | workspace_state);
    EnableMenuItem(host->workspace_menu, NOCTTY_MENU_WORKSPACE_SAVE,
                   MF_BYCOMMAND | workspace_state);
    EnableMenuItem(host->workspace_menu, NOCTTY_MENU_WORKSPACE_RESTORE,
                   MF_BYCOMMAND | workspace_state);
    DrawMenuBar(host->window);
}

static int noctty_create_menu(NocttyWindowsHost *host) {
    HMENU menu = CreateMenu();
    HMENU settings = CreatePopupMenu();
    HMENU theme = CreatePopupMenu();
    HMENU font = CreatePopupMenu();
    HMENU profile = CreatePopupMenu();
    HMENU workspace = CreatePopupMenu();
    int ok;
    if (menu == NULL || settings == NULL || theme == NULL || font == NULL ||
        profile == NULL || workspace == NULL) {
        if (menu != NULL) DestroyMenu(menu);
        if (settings != NULL) DestroyMenu(settings);
        if (theme != NULL) DestroyMenu(theme);
        if (font != NULL) DestroyMenu(font);
        if (profile != NULL) DestroyMenu(profile);
        if (workspace != NULL) DestroyMenu(workspace);
        return 0;
    }
    ok = AppendMenuW(theme, MF_STRING, NOCTTY_MENU_THEME_DARK, L"&Dark") &&
         AppendMenuW(theme, MF_STRING, NOCTTY_MENU_THEME_HIGH_CONTRAST,
                     L"&High contrast") &&
         AppendMenuW(font, MF_STRING, NOCTTY_MENU_FONT_11, L"11 pt") &&
         AppendMenuW(font, MF_STRING, NOCTTY_MENU_FONT_13, L"13 pt") &&
         AppendMenuW(font, MF_STRING, NOCTTY_MENU_FONT_16, L"16 pt") &&
         AppendMenuW(font, MF_STRING, NOCTTY_MENU_FONT_18, L"18 pt") &&
         AppendMenuW(profile, MF_STRING, NOCTTY_MENU_PROFILE_POWERSHELL,
                     L"&PowerShell") &&
         AppendMenuW(profile, MF_STRING, NOCTTY_MENU_PROFILE_COMMAND,
                     L"&Command Prompt") &&
         AppendMenuW(settings, MF_POPUP, (UINT_PTR)theme, L"&Theme") &&
         AppendMenuW(settings, MF_POPUP, (UINT_PTR)font, L"&Font size") &&
         AppendMenuW(settings, MF_POPUP, (UINT_PTR)profile,
                     L"&Launch profile") &&
         AppendMenuW(settings, MF_SEPARATOR, 0, NULL) &&
         AppendMenuW(settings, MF_STRING, NOCTTY_MENU_RESTORE_STARTUP,
                     L"&Restore saved workspace on startup") &&
         AppendMenuW(workspace, MF_STRING, NOCTTY_MENU_WORKSPACE_SAVE,
                     L"&Save current layout") &&
         AppendMenuW(workspace, MF_STRING, NOCTTY_MENU_WORKSPACE_RESTORE,
                     L"&Restore saved layout...") &&
         AppendMenuW(menu, MF_POPUP, (UINT_PTR)settings, L"&Settings") &&
         AppendMenuW(menu, MF_POPUP, (UINT_PTR)workspace, L"&Workspace") &&
         AppendMenuW(menu, MF_STRING, NOCTTY_MENU_OPEN_NOCTED,
                     L"Open &NoctEd") &&
         SetMenu(host->window, menu);
    if (!ok) {
        DestroyMenu(menu);
        return 0;
    }
    host->menu = menu;
    host->settings_menu = settings;
    host->theme_menu = theme;
    host->font_menu = font;
    host->profile_menu = profile;
    host->workspace_menu = workspace;
    host->settings_menu_ready = 1;
    noctty_update_menu(host);
    return 1;
}

static int noctty_pane_geometry(NocttyWindowsHost *host, int pane_index,
                                const RECT *client, NocttyPaneHit *result) {
    uint32_t x = 0;
    uint32_t y = 0;
    uint32_t width = 0;
    uint32_t height = 0;
    int selected = 0;
    int host_active = 0;
    uint16_t columns = 0;
    uint16_t rows = 0;
    const int inset = 3;
    int client_width = client->right - client->left;
    int client_height = client->bottom - client->top;
    if (host->callbacks->pane_layout(
            host->callbacks->userdata, pane_index, &x, &y, &width, &height,
            &selected, &host_active) <= 0 ||
        host->callbacks->pane_dimensions(
            host->callbacks->userdata, pane_index, &columns, &rows) <= 0 ||
        columns == 0 || rows == 0)
        return 0;
    result->pane_index = pane_index;
    result->pane.left =
        client->left + (int)((int64_t)client_width * x / 1000000);
    result->pane.top =
        client->top + (int)((int64_t)client_height * y / 1000000);
    result->pane.right =
        client->left +
        (int)((int64_t)client_width * (x + width) / 1000000);
    result->pane.bottom =
        client->top +
        (int)((int64_t)client_height * (y + height) / 1000000);
    if (result->pane.right - result->pane.left <= inset * 2 ||
        result->pane.bottom - result->pane.top <= inset * 2)
        return 0;
    result->content = result->pane;
    InflateRect(&result->content, -inset, -inset);
    result->columns = (int)columns;
    result->rows = (int)rows;
    result->column = 0;
    result->row = 0;
    result->inside_content = 0;
    result->selected = selected;
    result->host_active = host_active;
    return 1;
}

static int noctty_cell_for_pane(NocttyWindowsHost *host, int pane_index,
                                int pointer_x, int pointer_y, int clamp,
                                NocttyPaneHit *result) {
    RECT client;
    int x;
    int y;
    int width;
    int height;
    GetClientRect(host->window, &client);
    if (!noctty_pane_geometry(host, pane_index, &client, result)) return 0;
    result->inside_content =
        pointer_x >= result->content.left && pointer_x < result->content.right &&
        pointer_y >= result->content.top && pointer_y < result->content.bottom;
    if (!result->inside_content && !clamp) return 1;
    x = pointer_x;
    y = pointer_y;
    if (x < result->content.left) x = result->content.left;
    if (x >= result->content.right) x = result->content.right - 1;
    if (y < result->content.top) y = result->content.top;
    if (y >= result->content.bottom) y = result->content.bottom - 1;
    width = result->content.right - result->content.left;
    height = result->content.bottom - result->content.top;
    result->column = (int)((int64_t)(x - result->content.left) *
                           result->columns / width);
    result->row = (int)((int64_t)(y - result->content.top) *
                        result->rows / height);
    return 1;
}

static int noctty_hit_test_pane_cell(NocttyWindowsHost *host, int pointer_x,
                                     int pointer_y, NocttyPaneHit *result) {
    RECT client;
    int pane_count =
        host->callbacks->pane_count(host->callbacks->userdata);
    GetClientRect(host->window, &client);
    for (int pane_index = 0; pane_index < pane_count; pane_index++) {
        NocttyPaneHit candidate;
        if (!noctty_pane_geometry(host, pane_index, &client, &candidate))
            continue;
        if (pointer_x < candidate.pane.left ||
            pointer_x >= candidate.pane.right ||
            pointer_y < candidate.pane.top ||
            pointer_y >= candidate.pane.bottom)
            continue;
        noctty_cell_for_pane(host, pane_index, pointer_x, pointer_y, 0,
                             &candidate);
        *result = candidate;
        return 1;
    }
    return 0;
}

static void noctty_clear_selection(NocttyWindowsHost *host) {
    int release_capture =
        host->selection_dragging && GetCapture() == host->window;
    if (!host->selection_active && !host->selection_dragging) return;
    host->selection_active = 0;
    host->selection_dragging = 0;
    host->selection_pane = -1;
    if (release_capture) ReleaseCapture();
    InvalidateRect(host->window, NULL, FALSE);
}

static int noctty_cell_selected(const NocttyWindowsHost *host, int pane_index,
                                int column, int row) {
    int first_column;
    int last_column;
    int first_row;
    int last_row;
    if (!host->selection_active || host->selection_pane != pane_index)
        return 0;
    first_column =
        host->selection_anchor_column < host->selection_extent_column
            ? host->selection_anchor_column
            : host->selection_extent_column;
    last_column =
        host->selection_anchor_column > host->selection_extent_column
            ? host->selection_anchor_column
            : host->selection_extent_column;
    first_row = host->selection_anchor_row < host->selection_extent_row
                    ? host->selection_anchor_row
                    : host->selection_extent_row;
    last_row = host->selection_anchor_row > host->selection_extent_row
                   ? host->selection_anchor_row
                   : host->selection_extent_row;
    return column >= first_column && column <= last_column &&
           row >= first_row && row <= last_row;
}
static void noctty_draw_cell(NocttyWindowsHost *host, HDC device,
                             int pane_index, int origin_x, int origin_y,
                             int content_width, int content_height,
                             int columns, int rows, int column, int row) {
    uint64_t packed =
        pane_index >= 0
            ? host->callbacks->pane_cell(host->callbacks->userdata, pane_index,
                                         column, row)
            : host->callbacks->cell(host->callbacks->userdata, column, row);
    uint32_t style = (uint32_t)(packed >> 32u);
    uint32_t foreground_id = (style >> 8u) & 0x0fffu;
    uint32_t background_id = (style >> 20u) & 0x0fffu;
    uint32_t foreground = noctty_terminal_color(
        host, pane_index, foreground_id, host->foreground);
    uint32_t background = noctty_terminal_color(
        host, pane_index, background_id, host->background);
    RECT rectangle;
    uint8_t text_utf8[128];
    WCHAR text_utf16[128];
    int text_length;
    int wide_length;
    int old_mode;
    HFONT previous_font;

    if ((style & 2u) != 0u) {
        uint32_t temporary = foreground;
        foreground = background;
        background = temporary;
    }
    if ((style & 32u) != 0u)
        foreground = noctty_blend(foreground, background, 150u);
    if (pane_index >= 0 &&
        noctty_cell_selected(host, pane_index, column, row)) {
        foreground = noctty_rgb_from_colorref(GetSysColor(COLOR_HIGHLIGHTTEXT));
        background = noctty_rgb_from_colorref(GetSysColor(COLOR_HIGHLIGHT));
    }

    rectangle.left = origin_x + column * content_width / columns;
    rectangle.top = origin_y + row * content_height / rows;
    rectangle.right = origin_x + (column + 1) * content_width / columns;
    rectangle.bottom = origin_y + (row + 1) * content_height / rows;
    SetTextColor(device, noctty_color_ref(foreground));
    SetBkColor(device, noctty_color_ref(background));
    old_mode = SetBkMode(device, OPAQUE);

    if ((style & 128u) != 0u) {
        ExtTextOutW(device, rectangle.left, rectangle.top, ETO_OPAQUE,
                    &rectangle, L"", 0, NULL);
        SetBkMode(device, old_mode);
        return;
    }

    text_length =
        pane_index >= 0
            ? host->callbacks->pane_cell_text(
                  host->callbacks->userdata, pane_index, column, row, text_utf8,
                  sizeof(text_utf8))
            : host->callbacks->cell_text(host->callbacks->userdata, column, row,
                                         text_utf8, sizeof(text_utf8));
    if (text_length <= 0) {
        ExtTextOutW(device, rectangle.left, rectangle.top, ETO_OPAQUE,
                    &rectangle, L"", 0, NULL);
        SetBkMode(device, old_mode);
        return;
    }
    wide_length = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
                                      (const char *)text_utf8, text_length,
                                      text_utf16,
                                      (int)(sizeof(text_utf16) / sizeof(WCHAR)));
    if (wide_length <= 0) {
        text_utf16[0] = 0xfffdu;
        wide_length = 1;
    }
    if (column + 1 < columns) {
        uint64_t next =
            pane_index >= 0
                ? host->callbacks->pane_cell(
                      host->callbacks->userdata, pane_index, column + 1, row)
                : host->callbacks->cell(host->callbacks->userdata, column + 1,
                                        row);
        if ((((uint32_t)(next >> 32u)) & 128u) != 0u)
            rectangle.right =
                origin_x + (column + 2) * content_width / columns;
    }
    previous_font = SelectObject(device,
                                 (style & 1u) != 0u ? host->font_bold
                                                   : host->font_normal);
    ExtTextOutW(device, rectangle.left, rectangle.top, ETO_OPAQUE | ETO_CLIPPED,
                &rectangle, text_utf16, (UINT)wide_length, NULL);
    SelectObject(device, previous_font);
    if ((style & 8u) != 0u) {
        HPEN pen = CreatePen(PS_SOLID, 1, noctty_color_ref(foreground));
        HPEN previous_pen = SelectObject(device, pen);
        MoveToEx(device, rectangle.left, rectangle.bottom - 2, NULL);
        LineTo(device, rectangle.right, rectangle.bottom - 2);
        SelectObject(device, previous_pen);
        DeleteObject(pen);
    }
    if ((style & 16u) != 0u) {
        HPEN pen = CreatePen(PS_SOLID, 1, noctty_color_ref(foreground));
        HPEN previous_pen = SelectObject(device, pen);
        MoveToEx(device, rectangle.left,
                 rectangle.top + (rectangle.bottom - rectangle.top) / 2, NULL);
        LineTo(device, rectangle.right,
               rectangle.top + (rectangle.bottom - rectangle.top) / 2);
        SelectObject(device, previous_pen);
        DeleteObject(pen);
    }
    SetBkMode(device, old_mode);
}

static void noctty_draw_shared_pane(NocttyWindowsHost *host, HDC device,
                                    const RECT *client, int pane_index) {
    NocttyPaneHit geometry;
    if (!noctty_pane_geometry(host, pane_index, client, &geometry)) return;
    int content_width = geometry.content.right - geometry.content.left;
    int content_height = geometry.content.bottom - geometry.content.top;
    for (int row = 0; row < geometry.rows; row++) {
        for (int column = 0; column < geometry.columns; column++) {
            noctty_draw_cell(host, device, pane_index, geometry.content.left,
                             geometry.content.top, content_width,
                             content_height, geometry.columns, geometry.rows,
                             column, row);
        }
    }
    if (geometry.host_active) {
        uint32_t cursor = host->callbacks->pane_cursor(
            host->callbacks->userdata, pane_index);
        int cursor_column = (int)(cursor & 0xffffu);
        int cursor_row = (int)(cursor >> 16u);
        if (cursor != 0xffffffffu && cursor_column < geometry.columns &&
            cursor_row < geometry.rows) {
            RECT cursor_rectangle;
            cursor_rectangle.left =
                geometry.content.left +
                cursor_column * content_width / geometry.columns;
            cursor_rectangle.top =
                geometry.content.top +
                cursor_row * content_height / geometry.rows;
            cursor_rectangle.right =
                geometry.content.left +
                (cursor_column + 1) * content_width / geometry.columns;
            cursor_rectangle.bottom =
                geometry.content.top +
                (cursor_row + 1) * content_height / geometry.rows;
            InvertRect(device, &cursor_rectangle);
        }
    }
    HPEN border = CreatePen(PS_SOLID, geometry.selected ? 3 : 1,
                            noctty_color_ref(geometry.selected ? 0x94e2d5u
                                                              : 0x45475au));
    HPEN previous_pen = SelectObject(device, border);
    HGDIOBJ previous_brush = SelectObject(device, GetStockObject(NULL_BRUSH));
    Rectangle(device, geometry.pane.left + 1, geometry.pane.top + 1,
              geometry.pane.right - 1, geometry.pane.bottom - 1);
    SelectObject(device, previous_brush);
    SelectObject(device, previous_pen);
    DeleteObject(border);
    if (geometry.host_active) {
        HPEN active_border =
            CreatePen(PS_SOLID, 1, noctty_color_ref(0xf9e2afu));
        previous_pen = SelectObject(device, active_border);
        previous_brush = SelectObject(device, GetStockObject(NULL_BRUSH));
        Rectangle(device, geometry.pane.left + 3, geometry.pane.top + 3,
                  geometry.pane.right - 3, geometry.pane.bottom - 3);
        SelectObject(device, previous_brush);
        SelectObject(device, previous_pen);
        DeleteObject(active_border);
    }
}

static void noctty_paint(NocttyWindowsHost *host) {
    PAINTSTRUCT paint;
    RECT client;
    HDC target;
    HDC buffer_device;
    HBITMAP buffer_bitmap;
    HBITMAP previous_bitmap;
    HBRUSH background;
    uint32_t cursor;
    int cursor_column;
    int cursor_row;

    target = BeginPaint(host->window, &paint);
    if (target == NULL) return;
    GetClientRect(host->window, &client);
    buffer_device = CreateCompatibleDC(target);
    buffer_bitmap = CreateCompatibleBitmap(target, client.right, client.bottom);
    if (buffer_device == NULL || buffer_bitmap == NULL) {
        if (buffer_device != NULL) DeleteDC(buffer_device);
        if (buffer_bitmap != NULL) DeleteObject(buffer_bitmap);
        EndPaint(host->window, &paint);
        return;
    }
    previous_bitmap = SelectObject(buffer_device, buffer_bitmap);
    background = CreateSolidBrush(noctty_color_ref(host->background));
    FillRect(buffer_device, &client, background);
    DeleteObject(background);

    int pane_count = host->callbacks->pane_count(host->callbacks->userdata);
    if (pane_count > 0) {
        for (int pane_index = 0; pane_index < pane_count; pane_index++)
            noctty_draw_shared_pane(host, buffer_device, &client, pane_index);
    } else {
        for (int row = 0; row < host->rows; row++) {
            for (int column = 0; column < host->columns; column++)
                noctty_draw_cell(
                    host, buffer_device, -1, 0, 0,
                    host->columns * host->cell_width,
                    host->rows * host->cell_height, host->columns, host->rows,
                    column, row);
        }
        cursor = host->callbacks->cursor(host->callbacks->userdata);
        if (cursor != 0xffffffffu && GetFocus() == host->window) {
            RECT cursor_rectangle;
            cursor_column = (int)(cursor & 0xffffu);
            cursor_row = (int)(cursor >> 16u);
            if (cursor_column >= 0 && cursor_column < host->columns &&
                cursor_row >= 0 && cursor_row < host->rows) {
                cursor_rectangle.left = cursor_column * host->cell_width;
                cursor_rectangle.top = cursor_row * host->cell_height;
                cursor_rectangle.right =
                    cursor_rectangle.left + host->cell_width;
                cursor_rectangle.bottom =
                    cursor_rectangle.top + host->cell_height;
                InvertRect(buffer_device, &cursor_rectangle);
            }
        }
    }

    BitBlt(target, 0, 0, client.right, client.bottom, buffer_device, 0, 0,
           SRCCOPY);
    host->paint_count++;
    SelectObject(buffer_device, previous_bitmap);
    DeleteObject(buffer_bitmap);
    DeleteDC(buffer_device);
    EndPaint(host->window, &paint);
}

static NocttyWindowsSession *noctty_active_session(
    NocttyWindowsHost *host) {
    int index = host->callbacks->active_pane(host->callbacks->userdata);
    if (index < 0 || index >= NOCTTY_MAX_SESSIONS) return NULL;
    if (host->sessions[index].output_ring == NULL) return NULL;
    return &host->sessions[index];
}

static int noctty_write_session(NocttyWindowsSession *session,
                                const uint8_t *bytes, size_t length) {
    size_t offset = 0;
    if (session == NULL || session->process_exited ||
        session->input_write == NULL)
        return 0;
    while (offset < length) {
        DWORD written = 0;
        DWORD request = (DWORD)((length - offset) > 65536u
                                    ? 65536u
                                    : (length - offset));
        if (!WriteFile(session->input_write, bytes + offset, request, &written,
                       NULL)) {
            noctty_log("input_write_failed pane=%d error=%lu\r\n",
                       session->index, GetLastError());
            return 0;
        }
        if (written == 0) return 0;
        offset += written;
    }
    return 1;
}

static int noctty_write_terminal(NocttyWindowsHost *host,
                                 const uint8_t *bytes, size_t length) {
    if (host->remote_mode) {
        int written = host->callbacks->write(host->callbacks->userdata, bytes,
                                             length);
        return written == (int)length;
    }
    return noctty_write_session(noctty_active_session(host), bytes, length);
}

static void noctty_flush_replies(NocttyWindowsHost *host,
                                 NocttyWindowsSession *session) {
    uint8_t replies[4096];
    for (int attempt = 0; attempt < 16; attempt++) {
        int count = host->callbacks->pane_take_reply(
            host->callbacks->userdata, session->index, replies,
            sizeof(replies));
        if (count <= 0) break;
        if (!noctty_write_session(session, replies, (size_t)count)) break;
    }
}

static void noctty_drain_output(NocttyWindowsHost *host, int session_index) {
    uint8_t scratch[NOCTTY_OUTPUT_DRAIN_BYTES];
    size_t total = 0;
    NocttyWindowsSession *session;
    if (session_index < 0 || session_index >= NOCTTY_MAX_SESSIONS) return;
    session = &host->sessions[session_index];
    if (session->output_ring == NULL) return;

    while (total < 2u * 1024u * 1024u) {
        size_t count;
        size_t first;
        EnterCriticalSection(&session->output_lock);
        count = session->output_length;
        if (count > sizeof(scratch)) count = sizeof(scratch);
        first = NOCTTY_OUTPUT_RING_BYTES - session->output_start;
        if (first > count) first = count;
        if (first > 0)
            memcpy(scratch, session->output_ring + session->output_start,
                   first);
        if (count > first)
            memcpy(scratch + first, session->output_ring, count - first);
        session->output_start =
            (session->output_start + count) % NOCTTY_OUTPUT_RING_BYTES;
        session->output_length -= count;
        LeaveCriticalSection(&session->output_lock);
        if (count == 0) break;
        if (host->callbacks->pane_feed(host->callbacks->userdata,
                                       session_index, scratch, count) < 0) {
            noctty_log("vt_feed_failed pane=%d bytes=%zu\r\n", session_index,
                       count);
            DestroyWindow(host->window);
            return;
        }
        total += count;
    }
    if (total > 0) {
        noctty_flush_replies(host, session);
        noctty_update_title(host);
        InvalidateRect(host->window, NULL, FALSE);
    }
}

static DWORD WINAPI noctty_reader_thread(void *raw) {
    NocttyWindowsSession *session = raw;
    NocttyWindowsHost *host = session->host;
    uint8_t input[65536];

    while (InterlockedCompareExchange(&session->stopping, 0, 0) == 0) {
        DWORD count = 0;
        if (!ReadFile(session->output_read, input, sizeof(input), &count,
                      NULL)) {
            DWORD error = GetLastError();
            if (error != ERROR_BROKEN_PIPE && error != ERROR_OPERATION_ABORTED)
                noctty_log("output_read_failed pane=%d error=%lu\r\n",
                           session->index, error);
            break;
        }
        if (count == 0) break;
        size_t offset = 0;
        while (offset < count &&
               InterlockedCompareExchange(&session->stopping, 0, 0) == 0) {
            size_t available;
            size_t write_at;
            size_t chunk;
            EnterCriticalSection(&session->output_lock);
            available = NOCTTY_OUTPUT_RING_BYTES - session->output_length;
            write_at = (session->output_start + session->output_length) %
                       NOCTTY_OUTPUT_RING_BYTES;
            chunk = (size_t)count - offset;
            if (chunk > available) chunk = available;
            if (chunk > NOCTTY_OUTPUT_RING_BYTES - write_at)
                chunk = NOCTTY_OUTPUT_RING_BYTES - write_at;
            if (chunk > 0) {
                memcpy(session->output_ring + write_at, input + offset, chunk);
                session->output_length += chunk;
            }
            LeaveCriticalSection(&session->output_lock);
            if (chunk == 0) {
                Sleep(1);
            } else {
                offset += chunk;
            }
        }
        PostMessageW(host->window, NOCTTY_WM_OUTPUT,
                     (WPARAM)(unsigned int)session->index, 0);
    }
    PostMessageW(host->window, NOCTTY_WM_OUTPUT,
                 (WPARAM)(unsigned int)session->index, 0);
    return 0;
}

static int noctty_create_pseudo_console(NocttyWindowsSession *session) {
    HANDLE input_read = NULL;
    HANDLE output_write = NULL;
    SIZE_T attribute_bytes = 0;
    PPROC_THREAD_ATTRIBUTE_LIST attributes = NULL;
    int attributes_initialized = 0;
    STARTUPINFOEXW startup;
    PROCESS_INFORMATION process;
    COORD size;
    HRESULT result;
    DWORD flags = EXTENDED_STARTUPINFO_PRESENT | CREATE_UNICODE_ENVIRONMENT;
    WCHAR custom_command[2048];
    WCHAR powershell_command[] = L"powershell.exe -NoLogo";
    WCHAR cmd_command[] = L"cmd.exe";
    WCHAR *commands[3];
    size_t command_count = 0;
    WCHAR current_directory[MAX_PATH];
    WCHAR *directory = NULL;
    DWORD custom_length;
    DWORD directory_length;

    if (!CreatePipe(&input_read, &session->input_write, NULL, 0)) goto failed;
    if (!CreatePipe(&session->output_read, &output_write, NULL, 0)) goto failed;
    size.X = (SHORT)session->columns;
    size.Y = (SHORT)session->rows;
    result = CreatePseudoConsole(size, input_read, output_write, 0,
                                 &session->pseudo_console);
    if (FAILED(result)) {
        noctty_log("conpty_create_failed pane=%d hresult=0x%08lx\r\n",
                   session->index, (unsigned long)result);
        goto failed;
    }
    noctty_close_handle(&input_read);
    noctty_close_handle(&output_write);

    InitializeProcThreadAttributeList(NULL, 1, 0, &attribute_bytes);
    attributes = HeapAlloc(GetProcessHeap(), 0, attribute_bytes);
    if (attributes == NULL) goto failed;
    if (!InitializeProcThreadAttributeList(attributes, 1, 0,
                                           &attribute_bytes))
        goto failed;
    attributes_initialized = 1;
    if (!UpdateProcThreadAttribute(
            attributes, 0, PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE,
            session->pseudo_console, sizeof(session->pseudo_console), NULL,
            NULL))
        goto failed;

    ZeroMemory(&startup, sizeof(startup));
    startup.StartupInfo.cb = sizeof(startup);
    startup.lpAttributeList = attributes;
    ZeroMemory(&process, sizeof(process));

    SetEnvironmentVariableW(L"TERM", L"xterm-256color");
    SetEnvironmentVariableW(L"COLORTERM", L"truecolor");
    custom_length = GetEnvironmentVariableW(L"NOCTTY_WINDOWS_SHELL",
                                             custom_command,
                                             (DWORD)(sizeof(custom_command) /
                                                     sizeof(WCHAR)));
    if (custom_length > 0 &&
        custom_length < sizeof(custom_command) / sizeof(WCHAR))
        commands[command_count++] = custom_command;
    if (session->host->launch_profile == 1) {
        commands[command_count++] = cmd_command;
        commands[command_count++] = powershell_command;
    } else {
        commands[command_count++] = powershell_command;
        commands[command_count++] = cmd_command;
    }

    directory_length = GetEnvironmentVariableW(
        L"USERPROFILE", current_directory,
        (DWORD)(sizeof(current_directory) / sizeof(WCHAR)));
    if (directory_length > 0 &&
        directory_length < sizeof(current_directory) / sizeof(WCHAR))
        directory = current_directory;

    for (size_t index = 0; index < command_count; index++) {
        WCHAR command_line[2048];
        size_t command_length = wcslen(commands[index]);
        if (command_length >= sizeof(command_line) / sizeof(WCHAR)) continue;
        memcpy(command_line, commands[index],
               (command_length + 1) * sizeof(WCHAR));
        if (CreateProcessW(NULL, command_line, NULL, NULL, FALSE, flags, NULL,
                           directory, &startup.StartupInfo, &process)) {
            session->process = process.hProcess;
            CloseHandle(process.hThread);
            noctty_log("shell_spawned pane=%d candidate=%zu pid=%lu\r\n",
                       session->index, index, process.dwProcessId);
            if (attributes_initialized)
                DeleteProcThreadAttributeList(attributes);
            HeapFree(GetProcessHeap(), 0, attributes);
            return 1;
        }
        noctty_log("shell_spawn_failed pane=%d candidate=%zu error=%lu\r\n",
                   session->index, index, GetLastError());
    }

failed:
    if (attributes != NULL) {
        if (attributes_initialized)
            DeleteProcThreadAttributeList(attributes);
        HeapFree(GetProcessHeap(), 0, attributes);
    }
    noctty_close_handle(&input_read);
    noctty_close_handle(&output_write);
    noctty_close_handle(&session->input_write);
    noctty_close_handle(&session->output_read);
    if (session->pseudo_console != NULL) {
        ClosePseudoConsole(session->pseudo_console);
        session->pseudo_console = NULL;
    }
    return 0;
}

static void noctty_cleanup_session(NocttyWindowsSession *session) {
    if (session->output_ring == NULL) return;
    InterlockedExchange(&session->stopping, 1);
    if (session->reader_thread != NULL)
        CancelSynchronousIo(session->reader_thread);
    noctty_close_handle(&session->input_write);
    noctty_close_handle(&session->output_read);
    if (session->pseudo_console != NULL) {
        ClosePseudoConsole(session->pseudo_console);
        session->pseudo_console = NULL;
    }
    if (session->reader_thread != NULL) {
        WaitForSingleObject(session->reader_thread, INFINITE);
        noctty_close_handle(&session->reader_thread);
    }
    if (session->process != NULL) {
        if (WaitForSingleObject(session->process, 500) == WAIT_TIMEOUT) {
            TerminateProcess(session->process, 1);
            WaitForSingleObject(session->process, 500);
        }
        noctty_close_handle(&session->process);
    }
    DeleteCriticalSection(&session->output_lock);
    HeapFree(GetProcessHeap(), 0, session->output_ring);
    ZeroMemory(session, sizeof(*session));
}

static int noctty_start_session(NocttyWindowsHost *host, int session_index) {
    NocttyWindowsSession *session;
    uint16_t columns = 0;
    uint16_t rows = 0;
    if (session_index < 0 || session_index >= NOCTTY_MAX_SESSIONS) return 0;
    session = &host->sessions[session_index];
    if (session->output_ring != NULL) return 1;
    if (host->callbacks->pane_dimensions(host->callbacks->userdata,
                                          session_index, &columns, &rows) <= 0 ||
        columns == 0 || rows == 0)
        return 0;
    session->host = host;
    session->index = session_index;
    session->columns = (int)columns;
    session->rows = (int)rows;
    session->output_ring =
        HeapAlloc(GetProcessHeap(), 0, NOCTTY_OUTPUT_RING_BYTES);
    if (session->output_ring == NULL) return 0;
    InitializeCriticalSection(&session->output_lock);
    if (!noctty_create_pseudo_console(session)) {
        noctty_cleanup_session(session);
        return 0;
    }
    session->reader_thread =
        CreateThread(NULL, 0, noctty_reader_thread, session, 0, NULL);
    if (session->reader_thread == NULL) {
        noctty_log("reader_thread_failed pane=%d error=%lu\r\n",
                   session_index, GetLastError());
        noctty_cleanup_session(session);
        return 0;
    }
    return 1;
}

static void noctty_update_title(NocttyWindowsHost *host) {
    uint8_t title_utf8[512];
    WCHAR title_utf16[640];
    static const WCHAR suffix[] = L" — NOCTTY Windows alpha";
    int count;
    int wide_count;
    size_t suffix_length;

    count = host->callbacks->title(host->callbacks->userdata, title_utf8,
                                   sizeof(title_utf8));
    if (count <= 0) {
        NocttyWindowsSession *active = noctty_active_session(host);
        SetWindowTextW(host->window,
                       active != NULL && active->process_exited
                           ? L"NOCTTY Windows alpha — exited"
                           : L"NOCTTY Windows alpha");
        return;
    }
    wide_count = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
                                     (const char *)title_utf8, count,
                                     title_utf16, 511);
    if (wide_count <= 0) return;
    suffix_length = wcslen(suffix);
    if ((size_t)wide_count + suffix_length >=
        sizeof(title_utf16) / sizeof(WCHAR))
        return;
    memcpy(title_utf16 + wide_count, suffix,
           (suffix_length + 1) * sizeof(WCHAR));
    SetWindowTextW(host->window, title_utf16);
}

static void noctty_resize_terminal(NocttyWindowsHost *host, int width,
                                   int height) {
    if (host->cell_width <= 0 || host->cell_height <= 0) return;
    host->columns = width / host->cell_width;
    host->rows = height / host->cell_height;
    if (host->columns < 1) host->columns = 1;
    if (host->rows < 1) host->rows = 1;
    if (host->columns > 1000) host->columns = 1000;
    if (host->rows > 500) host->rows = 500;
    if (!host->remote_mode) {
        int pane_count =
            host->callbacks->pane_count(host->callbacks->userdata);
        if (pane_count > NOCTTY_MAX_SESSIONS)
            pane_count = NOCTTY_MAX_SESSIONS;
        for (int index = 0; index < pane_count; index++) {
            uint32_t x = 0;
            uint32_t y = 0;
            uint32_t pane_width = 0;
            uint32_t pane_height = 0;
            int selected = 0;
            int host_active = 0;
            if (host->callbacks->pane_layout(
                    host->callbacks->userdata, index, &x, &y, &pane_width,
                    &pane_height, &selected, &host_active) <= 0)
                continue;
            int pixel_width =
                (int)((int64_t)width * pane_width / 1000000) - 6;
            int pixel_height =
                (int)((int64_t)height * pane_height / 1000000) - 6;
            int columns = pixel_width / host->cell_width;
            int rows = pixel_height / host->cell_height;
            if (columns < 1) columns = 1;
            if (rows < 1) rows = 1;
            if (columns > 1000) columns = 1000;
            if (rows > 500) rows = 500;
            if (host->callbacks->pane_resize(host->callbacks->userdata, index,
                                              columns, rows) < 0)
                continue;
            NocttyWindowsSession *session = &host->sessions[index];
            if (session->output_ring == NULL) continue;
            session->columns = columns;
            session->rows = rows;
            if (session->pseudo_console != NULL) {
                COORD size;
                size.X = (SHORT)columns;
                size.Y = (SHORT)rows;
                if (FAILED(ResizePseudoConsole(session->pseudo_console, size)))
                    noctty_log("conpty_resize_failed pane=%d columns=%d "
                               "rows=%d\r\n",
                               index, columns, rows);
            }
        }
    }
    InvalidateRect(host->window, NULL, FALSE);
}

static void noctty_send_special_key(NocttyWindowsHost *host, WPARAM key) {
    const char *sequence = NULL;
    int application = host->callbacks->cursor_mode(host->callbacks->userdata);
    switch (key) {
        case VK_UP:
            sequence = application ? "\x1bOA" : "\x1b[A";
            break;
        case VK_DOWN:
            sequence = application ? "\x1bOB" : "\x1b[B";
            break;
        case VK_RIGHT:
            sequence = application ? "\x1bOC" : "\x1b[C";
            break;
        case VK_LEFT:
            sequence = application ? "\x1bOD" : "\x1b[D";
            break;
        case VK_HOME:
            sequence = "\x1b[H";
            break;
        case VK_END:
            sequence = "\x1b[F";
            break;
        case VK_PRIOR:
            sequence = "\x1b[5~";
            break;
        case VK_NEXT:
            sequence = "\x1b[6~";
            break;
        case VK_INSERT:
            sequence = "\x1b[2~";
            break;
        case VK_DELETE:
            sequence = "\x1b[3~";
            break;
        case VK_F1:
            sequence = "\x1bOP";
            break;
        case VK_F2:
            sequence = "\x1bOQ";
            break;
        case VK_F3:
            sequence = "\x1bOR";
            break;
        case VK_F4:
            sequence = "\x1bOS";
            break;
        case VK_F5:
            sequence = "\x1b[15~";
            break;
        case VK_F6:
            sequence = "\x1b[17~";
            break;
        case VK_F7:
            sequence = "\x1b[18~";
            break;
        case VK_F8:
            sequence = "\x1b[19~";
            break;
        case VK_F9:
            sequence = "\x1b[20~";
            break;
        case VK_F10:
            sequence = "\x1b[21~";
            break;
        case VK_F11:
            sequence = "\x1b[23~";
            break;
        case VK_F12:
            sequence = "\x1b[24~";
            break;
        default:
            break;
    }
    if (sequence != NULL)
        noctty_write_terminal(host, (const uint8_t *)sequence,
                              strlen(sequence));
}

static void noctty_send_wide_character(NocttyWindowsHost *host,
                                       WCHAR character) {
    WCHAR source[2];
    int source_count = 1;
    uint8_t utf8[8];
    int count;

    if (character >= 0xd800u && character <= 0xdbffu) {
        host->pending_high_surrogate = character;
        return;
    }
    if (character >= 0xdc00u && character <= 0xdfffu &&
        host->pending_high_surrogate != 0) {
        source[0] = host->pending_high_surrogate;
        source[1] = character;
        source_count = 2;
        host->pending_high_surrogate = 0;
    } else {
        host->pending_high_surrogate = 0;
        source[0] = character;
    }
    count = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, source,
                                source_count, (char *)utf8, sizeof(utf8), NULL,
                                NULL);
    if (count > 0) noctty_write_terminal(host, utf8, (size_t)count);
}

static void noctty_paste_clipboard(NocttyWindowsHost *host) {
    HANDLE memory;
    WCHAR *text;
    size_t characters;
    int bytes;
    uint8_t *utf8;

    if (!OpenClipboard(host->window)) return;
    memory = GetClipboardData(CF_UNICODETEXT);
    if (memory == NULL) {
        CloseClipboard();
        return;
    }
    text = GlobalLock(memory);
    if (text == NULL) {
        CloseClipboard();
        return;
    }
    characters = wcsnlen(text, NOCTTY_PASTE_BYTES_MAX / sizeof(WCHAR));
    bytes = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, text,
                                (int)characters, NULL, 0, NULL, NULL);
    if (bytes <= 0 || (size_t)bytes > NOCTTY_PASTE_BYTES_MAX) {
        GlobalUnlock(memory);
        CloseClipboard();
        return;
    }
    utf8 = HeapAlloc(GetProcessHeap(), 0, (size_t)bytes);
    if (utf8 != NULL &&
        WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, text,
                            (int)characters, (char *)utf8, bytes, NULL, NULL) ==
            bytes)
        noctty_write_terminal(host, utf8, (size_t)bytes);
    if (utf8 != NULL) HeapFree(GetProcessHeap(), 0, utf8);
    GlobalUnlock(memory);
    CloseClipboard();
}

static int noctty_set_clipboard_utf8(NocttyWindowsHost *host,
                                     const uint8_t *utf8, size_t length) {
    int wide_count;
    HGLOBAL memory;
    WCHAR *wide;
    int success = 0;
    if (length > INT_MAX) return 0;
    wide_count =
        length == 0
            ? 0
            : MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
                                  (const char *)utf8, (int)length, NULL, 0);
    if (length != 0 && wide_count <= 0) return 0;
    memory = GlobalAlloc(GMEM_MOVEABLE,
                         ((size_t)wide_count + 1u) * sizeof(WCHAR));
    if (memory == NULL) return 0;
    wide = GlobalLock(memory);
    if (wide == NULL) {
        GlobalFree(memory);
        return 0;
    }
    if (wide_count > 0 &&
        MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
                            (const char *)utf8, (int)length, wide,
                            wide_count) != wide_count) {
        GlobalUnlock(memory);
        GlobalFree(memory);
        return 0;
    }
    wide[wide_count] = L'\0';
    GlobalUnlock(memory);
    if (OpenClipboard(host->window)) {
        if (EmptyClipboard() &&
            SetClipboardData(CF_UNICODETEXT, memory) != NULL) {
            memory = NULL;
            success = 1;
        }
        CloseClipboard();
    }
    if (memory != NULL) GlobalFree(memory);
    return success;
}

static void noctty_copy_terminal(NocttyWindowsHost *host) {
    int pane_index =
        host->callbacks->active_pane(host->callbacks->userdata);
    uint8_t *utf8;
    int copied;
    int selected;
    if (pane_index < 0) return;
    utf8 = HeapAlloc(GetProcessHeap(), 0, NOCTTY_COPY_BYTES_MAX);
    if (utf8 == NULL) return;
    selected =
        host->selection_active && host->selection_pane == pane_index;
    copied = host->callbacks->pane_copy(
        host->callbacks->userdata, pane_index, utf8, NOCTTY_COPY_BYTES_MAX,
        selected ? host->selection_anchor_column : -1,
        selected ? host->selection_anchor_row : -1,
        selected ? host->selection_extent_column : -1,
        selected ? host->selection_extent_row : -1);
    if (copied >= 0 && (size_t)copied <= NOCTTY_COPY_BYTES_MAX)
        (void)noctty_set_clipboard_utf8(host, utf8, (size_t)copied);
    HeapFree(GetProcessHeap(), 0, utf8);
}

static int noctty_workspace_action(NocttyWindowsHost *host, int action) {
    RECT client;
    int result;
    int session_index;
    if (host->remote_mode) return 0;
    result = host->callbacks->workspace_action(
        host->callbacks->userdata, action, host->columns, host->rows);
    if (result <= 0) return 0;
    noctty_clear_selection(host);
    session_index = result - 1;
    GetClientRect(host->window, &client);
    noctty_resize_terminal(host, client.right, client.bottom);
    if (!noctty_start_session(host, session_index)) {
        uint32_t rollback = host->callbacks->workspace_close(
            host->callbacks->userdata, NOCTTY_WINDOWS_CLOSE_PANE);
        (void)rollback;
        noctty_resize_terminal(host, client.right, client.bottom);
        MessageBoxW(host->window, L"NOCTTY could not start another ConPTY.",
                    L"NOCTTY Windows alpha", MB_OK | MB_ICONERROR);
        return 0;
    }
    noctty_update_title(host);
    InvalidateRect(host->window, NULL, FALSE);
    SetFocus(host->window);
    return 1;
}

static int noctty_workspace_close(NocttyWindowsHost *host, int close_action,
                                  int query_action) {
    RECT client;
    uint32_t mask;
    uint32_t committed;
    if (host->remote_mode) return 0;
    mask = host->callbacks->workspace_close(host->callbacks->userdata,
                                             query_action);
    if (mask == 0) return 0;
    noctty_clear_selection(host);
    for (int index = 0; index < NOCTTY_MAX_SESSIONS; index++) {
        if ((mask & ((uint32_t)1u << (unsigned int)index)) != 0)
            noctty_cleanup_session(&host->sessions[index]);
    }
    committed = host->callbacks->workspace_close(host->callbacks->userdata,
                                                  close_action);
    if (committed != mask) {
        noctty_log("workspace_close_mismatch expected=0x%08lx actual=0x%08lx"
                   "\r\n",
                   (unsigned long)mask, (unsigned long)committed);
        DestroyWindow(host->window);
        return 0;
    }
    GetClientRect(host->window, &client);
    noctty_resize_terminal(host, client.right, client.bottom);
    noctty_update_title(host);
    InvalidateRect(host->window, NULL, FALSE);
    SetFocus(host->window);
    return 1;
}


static void noctty_cleanup_all_sessions(NocttyWindowsHost *host) {
    for (int index = 0; index < NOCTTY_MAX_SESSIONS; index++)
        noctty_cleanup_session(&host->sessions[index]);
}

static int noctty_start_workspace_sessions(NocttyWindowsHost *host) {
    int pane_count =
        host->callbacks->pane_count(host->callbacks->userdata);
    if (pane_count <= 0 || pane_count > NOCTTY_MAX_SESSIONS) return 0;
    for (int index = 0; index < pane_count; index++) {
        uint16_t columns = 0;
        uint16_t rows = 0;
        if (host->callbacks->pane_dimensions(host->callbacks->userdata, index,
                                              &columns, &rows) <= 0)
            continue;
        if (!noctty_start_session(host, index)) {
            noctty_cleanup_all_sessions(host);
            return 0;
        }
    }
    return 1;
}

static void noctty_set_preference(NocttyWindowsHost *host, int field,
                                  int value) {
    RECT client;
    if (host->callbacks->preference_set(host->callbacks->userdata, field,
                                        value) != 0) {
        MessageBoxW(host->window,
                    L"NOCTTY could not persist this Windows setting.",
                    L"NOCTTY Windows alpha", MB_OK | MB_ICONERROR);
        return;
    }
    noctty_load_preferences(host);
    if (field == NOCTTY_PREF_FONT_SIZE) {
        UINT dpi = GetDpiForWindow(host->window);
        if (dpi == 0) dpi = 96;
        if (!noctty_create_fonts(host, dpi)) {
            MessageBoxW(host->window, L"NOCTTY could not apply this font size.",
                        L"NOCTTY Windows alpha", MB_OK | MB_ICONERROR);
            return;
        }
        noctty_clear_selection(host);
        GetClientRect(host->window, &client);
        noctty_resize_terminal(host, client.right, client.bottom);
    }
    noctty_update_menu(host);
    InvalidateRect(host->window, NULL, FALSE);
    SetFocus(host->window);
}

static void noctty_workspace_persistence(NocttyWindowsHost *host,
                                         int action) {
    RECT client;
    int result;
    if (host->remote_mode) return;
    if (action == NOCTTY_WORKSPACE_RESTORE &&
        MessageBoxW(host->window,
                    L"Restore the saved layout? Current shells will be closed "
                    L"and replacement shells will start.",
                    L"Restore NOCTTY workspace",
                    MB_OKCANCEL | MB_ICONWARNING | MB_DEFBUTTON2) != IDOK)
        return;
    result = host->callbacks->workspace_persistence(
        host->callbacks->userdata, action, host->columns, host->rows);
    if (result < 0) {
        MessageBoxW(host->window,
                    action == NOCTTY_WORKSPACE_SAVE
                        ? L"NOCTTY could not save this workspace layout."
                        : L"NOCTTY could not restore the saved workspace.",
                    L"NOCTTY Windows alpha", MB_OK | MB_ICONERROR);
        return;
    }
    if (result == 0) {
        MessageBoxW(host->window,
                    L"No saved workspace layout is available.",
                    L"NOCTTY Windows alpha", MB_OK | MB_ICONINFORMATION);
        return;
    }
    if (action == NOCTTY_WORKSPACE_SAVE) {
        MessageBoxW(host->window,
                    L"Workspace layout saved. Shell contents are not stored.",
                    L"NOCTTY Windows alpha", MB_OK | MB_ICONINFORMATION);
        SetFocus(host->window);
        return;
    }
    noctty_clear_selection(host);
    noctty_cleanup_all_sessions(host);
    if (!noctty_start_workspace_sessions(host)) {
        MessageBoxW(host->window,
                    L"The layout was restored, but NOCTTY could not start all "
                    L"replacement shells.",
                    L"NOCTTY Windows alpha", MB_OK | MB_ICONERROR);
    }
    GetClientRect(host->window, &client);
    noctty_resize_terminal(host, client.right, client.bottom);
    noctty_update_title(host);
    InvalidateRect(host->window, NULL, FALSE);
    SetFocus(host->window);
}

static int noctty_write_pane(NocttyWindowsHost *host, int pane_index,
                             const uint8_t *bytes, size_t length) {
    if (host->remote_mode) {
        int written = host->callbacks->write(host->callbacks->userdata, bytes,
                                             length);
        return written == (int)length;
    }
    if (pane_index < 0 || pane_index >= NOCTTY_MAX_SESSIONS) return 0;
    return noctty_write_session(&host->sessions[pane_index], bytes, length);
}

static int noctty_mouse_modifiers(void) {
    int modifiers = 0;
    if ((GetKeyState(VK_SHIFT) & 0x8000) != 0)
        modifiers |= NOCTTY_WINDOWS_MOUSE_MOD_SHIFT;
    if ((GetKeyState(VK_MENU) & 0x8000) != 0)
        modifiers |= NOCTTY_WINDOWS_MOUSE_MOD_ALT;
    if ((GetKeyState(VK_CONTROL) & 0x8000) != 0)
        modifiers |= NOCTTY_WINDOWS_MOUSE_MOD_CONTROL;
    return modifiers;
}

static int noctty_select_pane(NocttyWindowsHost *host, int pane_index) {
    int previous =
        host->callbacks->active_pane(host->callbacks->userdata);
    if (host->callbacks->pane_select(host->callbacks->userdata, pane_index) !=
        0)
        return 0;
    if (previous != pane_index) noctty_clear_selection(host);
    SetFocus(host->window);
    noctty_update_title(host);
    return 1;
}

static int noctty_report_mouse(NocttyWindowsHost *host,
                               const NocttyPaneHit *hit, int button, int kind,
                               int modifiers) {
    uint8_t encoded[64];
    int count = host->callbacks->pane_mouse_encode(
        host->callbacks->userdata, hit->pane_index, hit->column, hit->row,
        button, kind, modifiers, encoded, sizeof(encoded));
    if (count <= 0 || (size_t)count > sizeof(encoded)) return 0;
    return noctty_write_pane(host, hit->pane_index, encoded, (size_t)count);
}

static void noctty_release_mouse_capture(NocttyWindowsHost *host) {
    if (host->application_capture && host->pressed_buttons != 0 &&
        host->capture_pane >= 0) {
        RECT client;
        NocttyPaneHit hit;
        GetClientRect(host->window, &client);
        if (noctty_pane_geometry(host, host->capture_pane, &client, &hit)) {
            hit.column = host->capture_last_column;
            hit.row = host->capture_last_row;
            for (int button = 0; button < 3; button++) {
                if ((host->pressed_buttons &
                     (1u << (unsigned int)button)) == 0)
                    continue;
                (void)noctty_report_mouse(
                    host, &hit, button, NOCTTY_WINDOWS_MOUSE_RELEASE,
                    noctty_mouse_modifiers());
            }
        }
    }
    host->selection_dragging = 0;
    host->application_capture = 0;
    host->pressed_buttons = 0;
    host->capture_pane = -1;
    if (GetCapture() == host->window) ReleaseCapture();
}

static void noctty_launch_nocted(NocttyWindowsHost *host) {
    WCHAR executable[MAX_PATH * 2];
    WCHAR command[MAX_PATH * 2 + 3];
    DWORD length =
        GetModuleFileNameW(NULL, executable,
                           (DWORD)(sizeof(executable) / sizeof(executable[0])));
    WCHAR *separator;
    static const WCHAR editor_name[] = L"nocted.exe";
    STARTUPINFOW startup;
    PROCESS_INFORMATION process;
    size_t directory_length;
    size_t editor_length = ARRAYSIZE(editor_name) - 1u;
    if (length == 0 || length >= ARRAYSIZE(executable)) goto failed;
    separator = wcsrchr(executable, L'\\');
    if (separator == NULL) goto failed;
    directory_length = (size_t)(separator + 1 - executable);
    if (directory_length + editor_length >= ARRAYSIZE(executable) ||
        directory_length + editor_length + 3u > ARRAYSIZE(command))
        goto failed;
    memcpy(executable + directory_length, editor_name,
           (editor_length + 1u) * sizeof(WCHAR));
    command[0] = L'"';
    memcpy(command + 1, executable,
           (directory_length + editor_length) * sizeof(WCHAR));
    command[directory_length + editor_length + 1u] = L'"';
    command[directory_length + editor_length + 2u] = L'\0';
    ZeroMemory(&startup, sizeof(startup));
    ZeroMemory(&process, sizeof(process));
    startup.cb = sizeof(startup);
    if (!CreateProcessW(executable, command, NULL, NULL, FALSE, 0, NULL, NULL,
                        &startup, &process))
        goto failed;
    CloseHandle(process.hThread);
    CloseHandle(process.hProcess);
    return;

failed:
    MessageBoxW(host->window,
                L"NOCTTY could not launch the sibling nocted.exe.",
                L"NOCTTY Windows alpha", MB_OK | MB_ICONERROR);
}

static int noctty_handle_menu_command(NocttyWindowsHost *host, UINT command) {
    switch (command) {
        case NOCTTY_MENU_THEME_DARK:
            noctty_set_preference(host, NOCTTY_PREF_THEME, 0);
            return 1;
        case NOCTTY_MENU_THEME_HIGH_CONTRAST:
            noctty_set_preference(host, NOCTTY_PREF_THEME, 1);
            return 1;
        case NOCTTY_MENU_FONT_11:
        case NOCTTY_MENU_FONT_13:
        case NOCTTY_MENU_FONT_16:
        case NOCTTY_MENU_FONT_18:
            noctty_set_preference(host, NOCTTY_PREF_FONT_SIZE,
                                  (int)(command - 40000u));
            return 1;
        case NOCTTY_MENU_PROFILE_POWERSHELL:
            noctty_set_preference(host, NOCTTY_PREF_LAUNCH_PROFILE, 0);
            return 1;
        case NOCTTY_MENU_PROFILE_COMMAND:
            noctty_set_preference(host, NOCTTY_PREF_LAUNCH_PROFILE, 1);
            return 1;
        case NOCTTY_MENU_RESTORE_STARTUP:
            noctty_set_preference(host, NOCTTY_PREF_RESTORE_WORKSPACE,
                                  !host->restore_workspace);
            return 1;
        case NOCTTY_MENU_WORKSPACE_SAVE:
            noctty_workspace_persistence(host, NOCTTY_WORKSPACE_SAVE);
            return 1;
        case NOCTTY_MENU_WORKSPACE_RESTORE:
            noctty_workspace_persistence(host, NOCTTY_WORKSPACE_RESTORE);
            return 1;
        case NOCTTY_MENU_OPEN_NOCTED:
            noctty_launch_nocted(host);
            return 1;
        default:
            return 0;
    }
}
static LRESULT CALLBACK noctty_window_proc(HWND window, UINT message,
                                           WPARAM word, LPARAM long_value) {
    NocttyWindowsHost *host =
        (NocttyWindowsHost *)GetWindowLongPtrW(window, GWLP_USERDATA);
    if (message == WM_NCCREATE) {
        CREATESTRUCTW *create = (CREATESTRUCTW *)long_value;
        host = create->lpCreateParams;
        host->window = window;
        SetWindowLongPtrW(window, GWLP_USERDATA, (LONG_PTR)host);
    }
    if (host == NULL) return DefWindowProcW(window, message, word, long_value);

    switch (message) {
        case WM_PAINT:
            noctty_paint(host);
            return 0;
        case WM_ERASEBKGND:
            return 1;
        case WM_COMMAND:
            if (HIWORD(word) == 0 &&
                noctty_handle_menu_command(host, LOWORD(word)))
                return 0;
            return DefWindowProcW(window, message, word, long_value);
        case WM_SYSCOLORCHANGE:
            if (host->theme == 1) {
                noctty_apply_theme(host);
                InvalidateRect(window, NULL, FALSE);
            }
            return 0;
        case WM_SIZE:
            if (word != SIZE_MINIMIZED) {
                noctty_clear_selection(host);
                noctty_resize_terminal(host, LOWORD(long_value),
                                       HIWORD(long_value));
            }
            return 0;
        case WM_GETMINMAXINFO: {
            MINMAXINFO *limits = (MINMAXINFO *)long_value;
            limits->ptMinTrackSize.x = NOCTTY_WINDOW_MIN_WIDTH;
            limits->ptMinTrackSize.y = NOCTTY_WINDOW_MIN_HEIGHT;
            return 0;
        }
        case WM_DPICHANGED: {
            RECT *suggested = (RECT *)long_value;
            noctty_clear_selection(host);
            noctty_create_fonts(host, HIWORD(word));
            SetWindowPos(window, NULL, suggested->left, suggested->top,
                         suggested->right - suggested->left,
                         suggested->bottom - suggested->top,
                         SWP_NOACTIVATE | SWP_NOZORDER);
            return 0;
        }
        case WM_SETFOCUS:
            InvalidateRect(window, NULL, FALSE);
            return 0;
        case WM_KILLFOCUS:
            if (host->selection_dragging || host->application_capture)
                noctty_release_mouse_capture(host);
            InvalidateRect(window, NULL, FALSE);
            return 0;
        case WM_LBUTTONDOWN:
        case WM_MBUTTONDOWN:
        case WM_RBUTTONDOWN: {
            NocttyPaneHit hit;
            int pointer_x = GET_X_LPARAM(long_value);
            int pointer_y = GET_Y_LPARAM(long_value);
            int button = message == WM_LBUTTONDOWN
                             ? 0
                             : message == WM_MBUTTONDOWN ? 1 : 2;
            int shift = (GetKeyState(VK_SHIFT) & 0x8000) != 0;
            uint32_t mode;
            if (!noctty_hit_test_pane_cell(host, pointer_x, pointer_y, &hit))
                return 0;
            if (!noctty_select_pane(host, hit.pane_index)) return 0;
            InvalidateRect(window, NULL, FALSE);
            if (!hit.inside_content) return 0;
            mode = host->callbacks->pane_mouse_mode(
                       host->callbacks->userdata, hit.pane_index) &
                   NOCTTY_WINDOWS_MOUSE_TRACKING_MASK;
            /* Shift+left is the local selection escape hatch. Without Shift,
               application tracking wins; otherwise left drag selects. */
            if (button == 0 && (shift || mode == 0)) {
                noctty_release_mouse_capture(host);
                host->selection_active = 1;
                host->selection_dragging = 1;
                host->selection_pane = hit.pane_index;
                host->selection_anchor_column = hit.column;
                host->selection_anchor_row = hit.row;
                host->selection_extent_column = hit.column;
                host->selection_extent_row = hit.row;
                host->capture_pane = hit.pane_index;
                SetCapture(window);
                InvalidateRect(window, NULL, FALSE);
                return 0;
            }
            if (mode != 0) {
                host->pressed_buttons |= 1u << (unsigned)button;
                host->application_capture = 1;
                host->capture_pane = hit.pane_index;
                host->capture_last_column = hit.column;
                host->capture_last_row = hit.row;
                SetCapture(window);
                (void)noctty_report_mouse(host, &hit, button,
                                          NOCTTY_WINDOWS_MOUSE_PRESS,
                                          noctty_mouse_modifiers());
            }
            return 0;
        }
        case WM_LBUTTONUP:
        case WM_MBUTTONUP:
        case WM_RBUTTONUP: {
            NocttyPaneHit hit;
            int pointer_x = GET_X_LPARAM(long_value);
            int pointer_y = GET_Y_LPARAM(long_value);
            int button = message == WM_LBUTTONUP
                             ? 0
                             : message == WM_MBUTTONUP ? 1 : 2;
            if (button == 0 && host->selection_dragging) {
                if (noctty_cell_for_pane(host, host->selection_pane, pointer_x,
                                         pointer_y, 1, &hit)) {
                    host->selection_extent_column = hit.column;
                    host->selection_extent_row = hit.row;
                }
                noctty_release_mouse_capture(host);
                InvalidateRect(window, NULL, FALSE);
                return 0;
            }
            if ((host->pressed_buttons & (1u << (unsigned)button)) != 0 &&
                noctty_cell_for_pane(host, host->capture_pane, pointer_x,
                                     pointer_y, 1, &hit)) {
                (void)noctty_report_mouse(host, &hit, button,
                                          NOCTTY_WINDOWS_MOUSE_RELEASE,
                                          noctty_mouse_modifiers());
                host->pressed_buttons &= ~(1u << (unsigned)button);
            }
            if (host->pressed_buttons == 0)
                noctty_release_mouse_capture(host);
            return 0;
        }
        case WM_MOUSEMOVE: {
            NocttyPaneHit hit;
            int pointer_x = GET_X_LPARAM(long_value);
            int pointer_y = GET_Y_LPARAM(long_value);
            if (host->selection_dragging) {
                if (noctty_cell_for_pane(host, host->selection_pane, pointer_x,
                                         pointer_y, 1, &hit) &&
                    (hit.column != host->selection_extent_column ||
                     hit.row != host->selection_extent_row)) {
                    host->selection_extent_column = hit.column;
                    host->selection_extent_row = hit.row;
                    InvalidateRect(window, NULL, FALSE);
                }
                return 0;
            }
            if (host->application_capture && host->pressed_buttons != 0) {
                int button = (host->pressed_buttons & 1u) != 0
                                 ? 0
                                 : (host->pressed_buttons & 2u) != 0 ? 1 : 2;
                if (noctty_cell_for_pane(host, host->capture_pane, pointer_x,
                                         pointer_y, 1, &hit) &&
                    (hit.column != host->capture_last_column ||
                     hit.row != host->capture_last_row)) {
                    host->capture_last_column = hit.column;
                    host->capture_last_row = hit.row;
                    (void)noctty_report_mouse(host, &hit, button,
                                              NOCTTY_WINDOWS_MOUSE_MOTION,
                                              noctty_mouse_modifiers());
                }
                return 0;
            }
            if (noctty_hit_test_pane_cell(host, pointer_x, pointer_y, &hit) &&
                hit.inside_content &&
                (host->callbacks->pane_mouse_mode(
                     host->callbacks->userdata, hit.pane_index) &
                 NOCTTY_WINDOWS_MOUSE_TRACKING_MASK) == 3u) {
                if (noctty_select_pane(host, hit.pane_index))
                    (void)noctty_report_mouse(
                        host, &hit, 3, NOCTTY_WINDOWS_MOUSE_MOTION,
                        noctty_mouse_modifiers());
            }
            return 0;
        }
        case WM_MOUSEWHEEL: {
            POINT pointer = {GET_X_LPARAM(long_value),
                             GET_Y_LPARAM(long_value)};
            NocttyPaneHit hit;
            int steps = GET_WHEEL_DELTA_WPARAM(word) / WHEEL_DELTA;
            if (steps == 0) return 0;
            ScreenToClient(window, &pointer);
            if (!noctty_hit_test_pane_cell(host, pointer.x, pointer.y, &hit) ||
                !noctty_select_pane(host, hit.pane_index))
                return 0;
            if (hit.inside_content &&
                (host->callbacks->pane_mouse_mode(
                     host->callbacks->userdata, hit.pane_index) &
                 NOCTTY_WINDOWS_MOUSE_TRACKING_MASK) != 0u) {
                int count = steps < 0 ? -steps : steps;
                int button = steps > 0 ? 64 : 65;
                for (int index = 0; index < count; index++)
                    (void)noctty_report_mouse(
                        host, &hit, button, NOCTTY_WINDOWS_MOUSE_WHEEL,
                        noctty_mouse_modifiers());
            } else {
                host->callbacks->scroll(host->callbacks->userdata, steps * 3);
                InvalidateRect(window, NULL, FALSE);
            }
            return 0;
        }
        case WM_CAPTURECHANGED:
            noctty_release_mouse_capture(host);
            InvalidateRect(window, NULL, FALSE);
            return 0;
        case WM_CANCELMODE:
            noctty_release_mouse_capture(host);
            InvalidateRect(window, NULL, FALSE);
            return 0;
        case WM_KEYDOWN:
        case WM_SYSKEYDOWN: {
            int control = (GetKeyState(VK_CONTROL) & 0x8000) != 0;
            int shift = (GetKeyState(VK_SHIFT) & 0x8000) != 0;
            int alt = (GetKeyState(VK_MENU) & 0x8000) != 0;
            if (alt && word == VK_F4)
                return DefWindowProcW(window, message, word, long_value);
            if (control && shift && word == 'C') {
                host->suppress_character = 1;
                noctty_copy_terminal(host);
                return 0;
            }
            if (control && shift && word == 'V') {
                host->suppress_character = 1;
                noctty_paste_clipboard(host);
                return 0;
            }
            if (!host->remote_mode && control && shift && word == 'T') {
                host->suppress_character = 1;
                noctty_workspace_action(host, NOCTTY_WINDOWS_ACTION_NEW_TAB);
                return 0;
            }
            if (!host->remote_mode && control && shift && word == 'S') {
                host->suppress_character = 1;
                noctty_workspace_action(host,
                                        NOCTTY_WINDOWS_ACTION_SPLIT_DOWN);
                return 0;
            }
            if (!host->remote_mode && control && shift && word == 'L') {
                host->suppress_character = 1;
                noctty_workspace_action(host,
                                        NOCTTY_WINDOWS_ACTION_SPLIT_LEFT);
                return 0;
            }
            if (!host->remote_mode && control && shift && word == 'W') {
                host->suppress_character = 1;
                noctty_workspace_close(host, NOCTTY_WINDOWS_CLOSE_TAB,
                                       NOCTTY_WINDOWS_QUERY_CLOSE_TAB);
                return 0;
            }
            if (!host->remote_mode && control && !shift && word == 'D') {
                host->suppress_character = 1;
                noctty_workspace_close(host, NOCTTY_WINDOWS_CLOSE_PANE,
                                       NOCTTY_WINDOWS_QUERY_CLOSE_PANE);
                return 0;
            }
            if (control && word == VK_TAB) {
                int changed;
                host->suppress_character = 1;
                if (host->remote_mode) {
                    changed = shift
                        ? host->callbacks->next_stream(
                              host->callbacks->userdata)
                        : host->callbacks->next_tab(
                              host->callbacks->userdata);
                } else {
                    changed = shift
                        ? host->callbacks->next_tab(
                              host->callbacks->userdata)
                        : host->callbacks->next_stream(
                              host->callbacks->userdata);
                }
                if (changed > 0) {
                    noctty_clear_selection(host);
                    if (!host->remote_mode) {
                        RECT client;
                        GetClientRect(window, &client);
                        noctty_resize_terminal(host, client.right,
                                               client.bottom);
                    }
                    noctty_update_title(host);
                    InvalidateRect(window, NULL, FALSE);
                }
                return 0;
            }
            if (shift && word == VK_INSERT) {
                noctty_paste_clipboard(host);
                return 0;
            }
            if (word == VK_UP || word == VK_DOWN || word == VK_LEFT ||
                word == VK_RIGHT || word == VK_HOME || word == VK_END ||
                word == VK_PRIOR || word == VK_NEXT || word == VK_INSERT ||
                word == VK_DELETE || (word >= VK_F1 && word <= VK_F12)) {
                noctty_send_special_key(host, word);
                return 0;
            }
            return DefWindowProcW(window, message, word, long_value);
        }
        case WM_CHAR:
            if (host->suppress_character) {
                host->suppress_character = 0;
                return 0;
            }
            if (word == VK_RETURN) {
                static const uint8_t carriage_return = '\r';
                noctty_write_terminal(host, &carriage_return, 1);
            } else if (word == VK_BACK) {
                static const uint8_t backspace = 0x7f;
                noctty_write_terminal(host, &backspace, 1);
            } else {
                noctty_send_wide_character(host, (WCHAR)word);
            }
            return 0;
        case WM_SYSCHAR: {
            static const uint8_t escape = 0x1b;
            if (word == VK_RETURN) return 0;
            noctty_write_terminal(host, &escape, 1);
            noctty_send_wide_character(host, (WCHAR)word);
            return 0;
        }
        case NOCTTY_WM_OUTPUT:
            if (word < NOCTTY_MAX_SESSIONS)
                noctty_drain_output(host, (int)word);
            return 0;
        case WM_TIMER: {
            for (int index = 0; index < NOCTTY_MAX_SESSIONS; index++) {
                NocttyWindowsSession *session = &host->sessions[index];
                if (session->output_ring == NULL) continue;
                noctty_drain_output(host, index);
                if (!session->process_exited && session->process != NULL &&
                    WaitForSingleObject(session->process, 0) ==
                        WAIT_OBJECT_0) {
                    DWORD process_exit_code = 255;
                    GetExitCodeProcess(session->process, &process_exit_code);
                    session->process_exited = 1;
                    session->process_exit_code = process_exit_code;
                    noctty_log("shell_exit pane=%d code=%lu\r\n", index,
                               process_exit_code);
                    noctty_update_title(host);
                    InvalidateRect(window, NULL, FALSE);
                }
            }
            noctty_drain_remote_input(host);
            if (host->remote_mode) {
                noctty_update_title(host);
                InvalidateRect(window, NULL, FALSE);
            }
            host->smoke_ticks++;
            NocttyWindowsSession *smoke_session =
                noctty_active_session(host);
            if (host->smoke_mode && smoke_session != NULL &&
                smoke_session->process_exited) {
                int marker = host->callbacks->smoke_ready(
                    host->callbacks->userdata);
                if (marker && !host->smoke_marker_seen) {
                    host->smoke_marker_seen = 1;
                    host->smoke_marker_paint_count = host->paint_count;
                    InvalidateRect(window, NULL, FALSE);
                    UpdateWindow(window);
                }
                if (marker && host->smoke_marker_seen &&
                    host->paint_count > host->smoke_marker_paint_count &&
                    smoke_session->process_exit_code == 0 &&
                    host->settings_menu_ready && host->preferences_ready &&
                    host->smoke_mouse_input && host->smoke_coordinates &&
                    host->smoke_selection && host->smoke_clipboard) {
                    noctty_log("windows_host_smoke conpty=true vt=true "
                               "gdi=true settings_menu=true preferences=true "
                               "mouse_input=true coordinates=true "
                               "selection=true clipboard=true "
                               "clean_exit=true\r\n");
                    host->exit_code = 0;
                    DestroyWindow(window);
                } else if (host->smoke_ticks > 625u) {
                    noctty_log(
                        "windows_host_smoke conpty=true vt=%s gdi=%s "
                        "mouse_input=%s coordinates=%s selection=%s "
                        "clipboard=%s process_exit=%lu clean_exit=false\r\n",
                        marker ? "true" : "false",
                        host->paint_count > 0 ? "true" : "false",
                        host->smoke_mouse_input ? "true" : "false",
                        host->smoke_coordinates ? "true" : "false",
                        host->smoke_selection ? "true" : "false",
                        host->smoke_clipboard ? "true" : "false",
                        smoke_session->process_exit_code);
                    host->exit_code = 2;
                    DestroyWindow(window);
                }
            }
            return 0;
        }
        case WM_CLOSE:
            DestroyWindow(window);
            return 0;
        case WM_DESTROY:
            KillTimer(window, NOCTTY_TIMER_ID);
            PostQuitMessage(host->exit_code);
            return 0;
        default:
            return DefWindowProcW(window, message, word, long_value);
    }
}

static void noctty_cleanup(NocttyWindowsHost *host) {
    for (int index = 0; index < NOCTTY_MAX_SESSIONS; index++)
        noctty_cleanup_session(&host->sessions[index]);
    if (host->font_normal != NULL) DeleteObject(host->font_normal);
    if (host->font_bold != NULL) DeleteObject(host->font_bold);
    noctty_log("windows_exit clean=true\r\n");
    noctty_close_handle(&noctty_log_file);
}

static void noctty_drain_remote_input(NocttyWindowsHost *host) {
    uint8_t input[4096];
    int session_index =
        host->callbacks->remote_pane(host->callbacks->userdata);
    if (session_index < 0 || session_index >= NOCTTY_MAX_SESSIONS) return;
    NocttyWindowsSession *session = &host->sessions[session_index];
    if (session->output_ring == NULL) return;
    for (int attempt = 0; attempt < 16; attempt++) {
        int count = host->callbacks->take_remote(
            host->callbacks->userdata, input, sizeof(input));
        if (count <= 0) break;
        if (!noctty_write_session(session, input, (size_t)count)) break;
    }
}

static void noctty_input_smoke_observables(NocttyWindowsHost *host) {
    NocttyPaneHit geometry;
    NocttyPaneHit first;
    NocttyPaneHit last;
    RECT client;
    int pane_index =
        host->callbacks->active_pane(host->callbacks->userdata);
    static const uint8_t clipboard_probe[] = {
        'N', 'C', 'T', '-', 0xe4, 0xb8, 0xad,
    };
    WCHAR wide_probe[16];
    int wide_count = MultiByteToWideChar(
        CP_UTF8, MB_ERR_INVALID_CHARS, (const char *)clipboard_probe,
        (int)sizeof(clipboard_probe), wide_probe, ARRAYSIZE(wide_probe));
    host->smoke_clipboard =
        wide_count == 5 && wide_probe[4] == (WCHAR)0x4e2d;
    host->smoke_mouse_input = 0;
    host->smoke_coordinates = 0;
    host->smoke_selection = 0;
    if (pane_index < 0) return;
    {
        uint32_t mode = host->callbacks->pane_mouse_mode(
            host->callbacks->userdata, pane_index);
        host->smoke_mouse_input =
            (mode & ~(NOCTTY_WINDOWS_MOUSE_TRACKING_MASK |
                      NOCTTY_WINDOWS_MOUSE_ENCODING_SGR)) == 0;
        if (host->smoke_mode && !host->remote_mode) {
            static const uint8_t enable_mouse[] =
                "\x1b[?1003h\x1b[?1006h";
            static const uint8_t disable_mouse[] =
                "\x1b[?1003l\x1b[?1006l";
            static const uint8_t expected[] = "\x1b[<48;3;4M";
            uint8_t encoded[64];
            int encoded_length = -1;
            if (host->callbacks->pane_feed(
                    host->callbacks->userdata, pane_index, enable_mouse,
                    sizeof(enable_mouse) - 1u) >= 0 &&
                host->callbacks->pane_mouse_mode(
                    host->callbacks->userdata, pane_index) ==
                    (3u | NOCTTY_WINDOWS_MOUSE_ENCODING_SGR)) {
                encoded_length = host->callbacks->pane_mouse_encode(
                    host->callbacks->userdata, pane_index, 2, 3, 0,
                    NOCTTY_WINDOWS_MOUSE_MOTION,
                    NOCTTY_WINDOWS_MOUSE_MOD_CONTROL, encoded,
                    sizeof(encoded));
            }
            host->smoke_mouse_input =
                encoded_length == (int)(sizeof(expected) - 1u) &&
                memcmp(encoded, expected, sizeof(expected) - 1u) == 0;
            (void)host->callbacks->pane_feed(
                host->callbacks->userdata, pane_index, disable_mouse,
                sizeof(disable_mouse) - 1u);
        }
    }
    GetClientRect(host->window, &client);
    if (!noctty_pane_geometry(host, pane_index, &client, &geometry)) return;
    if (noctty_cell_for_pane(host, pane_index, geometry.content.left,
                             geometry.content.top, 0, &first) &&
        first.inside_content && first.column == 0 && first.row == 0 &&
        noctty_cell_for_pane(host, pane_index, geometry.content.right - 1,
                             geometry.content.bottom - 1, 0, &last) &&
        last.inside_content && last.column == geometry.columns - 1 &&
        last.row == geometry.rows - 1)
        host->smoke_coordinates = 1;

    host->selection_active = 1;
    host->selection_pane = pane_index;
    host->selection_anchor_column = 4;
    host->selection_anchor_row = 3;
    host->selection_extent_column = 1;
    host->selection_extent_row = 1;
    host->smoke_selection =
        noctty_cell_selected(host, pane_index, 1, 1) &&
        noctty_cell_selected(host, pane_index, 4, 3) &&
        !noctty_cell_selected(host, pane_index, 0, 0);
    host->selection_active = 0;
    host->selection_pane = -1;
}

int noctty_windows_host_run(HINSTANCE instance, int show_command,
                            const NocttyWindowsCallbacks *callbacks) {
    static const WCHAR class_name[] = L"NOCTTY.Windows.NativeHost";
    WNDCLASSEXW window_class;
    NocttyWindowsHost *host;
    MSG message;
    RECT client;
    WCHAR smoke_value[8];
    UINT dpi = 96;
    int exit_code = 1;
    int session_started = 0;

    if (callbacks == NULL ||
        callbacks->abi_version != NOCTTY_WINDOWS_HOST_ABI_VERSION ||
        callbacks->struct_size < sizeof(NocttyWindowsCallbacks))
        return 1;
    noctty_initialize_logging();
    host = HeapAlloc(GetProcessHeap(), HEAP_ZERO_MEMORY, sizeof(*host));
    if (host == NULL) return 1;
    host->callbacks = callbacks;
    noctty_load_preferences(host);
    host->smoke_mode =
        GetEnvironmentVariableW(L"NOCTTY_WINDOWS_HOST_SMOKE", smoke_value,
                                sizeof(smoke_value) / sizeof(WCHAR)) > 0 &&
        smoke_value[0] != L'0';
    host->columns = NOCTTY_DEFAULT_COLUMNS;
    host->rows = NOCTTY_DEFAULT_ROWS;
    host->selection_pane = -1;
    host->capture_pane = -1;


    ZeroMemory(&window_class, sizeof(window_class));
    window_class.cbSize = sizeof(window_class);
    window_class.style = CS_HREDRAW | CS_VREDRAW | CS_DBLCLKS;
    window_class.lpfnWndProc = noctty_window_proc;
    window_class.hInstance = instance;
    window_class.hCursor = LoadCursorW(NULL, IDC_IBEAM);
    window_class.hIcon = LoadIconW(NULL, IDI_APPLICATION);
    window_class.hbrBackground = (HBRUSH)(COLOR_WINDOW + 1);
    window_class.lpszClassName = class_name;
    if (RegisterClassExW(&window_class) == 0 &&
        GetLastError() != ERROR_CLASS_ALREADY_EXISTS) {
        noctty_log("window_class_failed error=%lu\r\n", GetLastError());
        goto finished;
    }
    host->window = CreateWindowExW(
        0, class_name, L"NOCTTY Windows alpha", WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT, CW_USEDEFAULT, NOCTTY_WINDOW_WIDTH,
        NOCTTY_WINDOW_HEIGHT, NULL, NULL, instance, host);
    if (host->window == NULL) {
        noctty_log("window_create_failed error=%lu\r\n", GetLastError());
        goto finished;
    }
    if (!noctty_create_menu(host)) {
        MessageBoxW(host->window, L"NOCTTY could not create its native menu.",
                    L"NOCTTY Windows alpha", MB_OK | MB_ICONERROR);
        goto finished;
    }
    dpi = GetDpiForWindow(host->window);
    if (dpi == 0) dpi = 96;
    if (!noctty_create_fonts(host, dpi)) goto finished;
    {
        int start_mode = host->callbacks->start(host->callbacks->userdata);
        if (start_mode < 0) {
            MessageBoxW(host->window, L"NOCTTY could not start this session.",
                        L"NOCTTY Windows alpha", MB_OK | MB_ICONERROR);
            goto finished;
        }
        session_started = 1;
        host->remote_mode = start_mode > 0;
    }
    noctty_update_menu(host);
    GetClientRect(host->window, &client);
    noctty_resize_terminal(host, client.right, client.bottom);
    if (!host->remote_mode && !noctty_start_workspace_sessions(host)) {
        MessageBoxW(host->window,
                    L"NOCTTY could not start Windows ConPTY. Windows 10 "
                    L"version 1809 or newer is required.",
                    L"NOCTTY Windows alpha", MB_OK | MB_ICONERROR);
        goto finished;
    }
    noctty_input_smoke_observables(host);
    SetTimer(host->window, NOCTTY_TIMER_ID, NOCTTY_TIMER_INTERVAL_MS, NULL);
    ShowWindow(host->window, show_command == 0 ? SW_SHOW : show_command);
    UpdateWindow(host->window);
    SetFocus(host->window);

    while (GetMessageW(&message, NULL, 0, 0) > 0) {
        TranslateMessage(&message);
        DispatchMessageW(&message);
    }
    exit_code = (int)message.wParam;

finished:
    if (session_started)
        host->callbacks->stop(host->callbacks->userdata);
    if (host->window != NULL && IsWindow(host->window))
        DestroyWindow(host->window);
    noctty_cleanup(host);
    HeapFree(GetProcessHeap(), 0, host);
    return exit_code;
}

void noctty_windows_show_version(HINSTANCE instance, const wchar_t *version) {
    (void)instance;
    MessageBoxW(NULL, version, L"NOCTTY", MB_OK | MB_ICONINFORMATION);
}
