#define WIN32_LEAN_AND_MEAN
#define NOMINMAX

#include "native_host.h"

#include <dbghelp.h>
#include <shellapi.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define NOCTTY_TIMER_ID 1u
#define NOCTTY_TIMER_INTERVAL_MS 16u
#define NOCTTY_OUTPUT_RING_BYTES (4u * 1024u * 1024u)
#define NOCTTY_OUTPUT_DRAIN_BYTES (128u * 1024u)
#define NOCTTY_PASTE_BYTES_MAX (8u * 1024u * 1024u)
#define NOCTTY_COPY_BYTES_MAX (2u * 1024u * 1024u)
#define NOCTTY_DEFAULT_COLUMNS 120
#define NOCTTY_DEFAULT_ROWS 36
#define NOCTTY_WINDOW_WIDTH 1120
#define NOCTTY_WINDOW_HEIGHT 720
#define NOCTTY_WINDOW_MIN_WIDTH 640
#define NOCTTY_WINDOW_MIN_HEIGHT 360
#define NOCTTY_WM_OUTPUT (WM_APP + 1u)
#define NOCTTY_DEFAULT_FOREGROUND 0xd8dee9u
#define NOCTTY_DEFAULT_BACKGROUND 0x0b0d12u
#define NOCTTY_DEFAULT_COLOR_ID 0x0fffu

struct NocttyWindowsHost {
    const NocttyWindowsCallbacks *callbacks;
    HWND window;
    HFONT font_normal;
    HFONT font_bold;
    int cell_width;
    int cell_height;
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
    int suppress_character;
    int smoke_mode;
    int exit_code;
    DWORD process_exit_code;
    unsigned paint_count;
    unsigned smoke_ticks;
    unsigned smoke_marker_paint_count;
    int smoke_marker_seen;
    WCHAR pending_high_surrogate;
};

typedef struct NocttyWindowsHost NocttyWindowsHost;

static HANDLE noctty_log_file = INVALID_HANDLE_VALUE;
static WCHAR noctty_dump_path[MAX_PATH * 2];

static void noctty_log(const char *format, ...);
static void noctty_update_title(NocttyWindowsHost *host);
static void noctty_resize_terminal(NocttyWindowsHost *host, int width, int height);
static void noctty_drain_output(NocttyWindowsHost *host);
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

static uint32_t noctty_terminal_color(NocttyWindowsHost *host,
                                      uint32_t color_id,
                                      uint32_t fallback) {
    uint32_t value;
    if (color_id == NOCTTY_DEFAULT_COLOR_ID) return fallback;
    value = host->callbacks->color_rgb(host->callbacks->userdata, color_id);
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
    height = -MulDiv(13, (int)dpi, 72);
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

static void noctty_draw_cell(NocttyWindowsHost *host, HDC device, int column,
                             int row) {
    uint64_t packed = host->callbacks->cell(host->callbacks->userdata, column,
                                            row);
    uint32_t style = (uint32_t)(packed >> 32u);
    uint32_t foreground_id = (style >> 8u) & 0x0fffu;
    uint32_t background_id = (style >> 20u) & 0x0fffu;
    uint32_t foreground = noctty_terminal_color(
        host, foreground_id, NOCTTY_DEFAULT_FOREGROUND);
    uint32_t background = noctty_terminal_color(
        host, background_id, NOCTTY_DEFAULT_BACKGROUND);
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

    rectangle.left = column * host->cell_width;
    rectangle.top = row * host->cell_height;
    rectangle.right = rectangle.left + host->cell_width;
    rectangle.bottom = rectangle.top + host->cell_height;
    SetTextColor(device, noctty_color_ref(foreground));
    SetBkColor(device, noctty_color_ref(background));
    old_mode = SetBkMode(device, OPAQUE);

    if ((style & 128u) != 0u) {
        ExtTextOutW(device, rectangle.left, rectangle.top, ETO_OPAQUE,
                    &rectangle, L"", 0, NULL);
        SetBkMode(device, old_mode);
        return;
    }

    text_length = host->callbacks->cell_text(
        host->callbacks->userdata, column, row, text_utf8, sizeof(text_utf8));
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
    if (column + 1 < host->columns) {
        uint64_t next = host->callbacks->cell(host->callbacks->userdata,
                                              column + 1, row);
        if ((((uint32_t)(next >> 32u)) & 128u) != 0u)
            rectangle.right += host->cell_width;
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
                 rectangle.top + host->cell_height / 2, NULL);
        LineTo(device, rectangle.right,
               rectangle.top + host->cell_height / 2);
        SelectObject(device, previous_pen);
        DeleteObject(pen);
    }
    SetBkMode(device, old_mode);
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
    background = CreateSolidBrush(noctty_color_ref(NOCTTY_DEFAULT_BACKGROUND));
    FillRect(buffer_device, &client, background);
    DeleteObject(background);

    for (int row = 0; row < host->rows; row++) {
        for (int column = 0; column < host->columns; column++)
            noctty_draw_cell(host, buffer_device, column, row);
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
            cursor_rectangle.right = cursor_rectangle.left + host->cell_width;
            cursor_rectangle.bottom = cursor_rectangle.top + host->cell_height;
            InvertRect(buffer_device, &cursor_rectangle);
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

static int noctty_write_terminal(NocttyWindowsHost *host,
                                 const uint8_t *bytes, size_t length) {
    size_t offset = 0;
    if (host->input_write == NULL) {
        int written = host->callbacks->write(host->callbacks->userdata, bytes,
                                             length);
        return written == (int)length;
    }
    if (host->process_exited) return 0;
    while (offset < length) {
        DWORD written = 0;
        DWORD request = (DWORD)((length - offset) > 65536u
                                    ? 65536u
                                    : (length - offset));
        if (!WriteFile(host->input_write, bytes + offset, request, &written,
                       NULL)) {
            noctty_log("input_write_failed error=%lu\r\n", GetLastError());
            return 0;
        }
        if (written == 0) return 0;
        offset += written;
    }
    return 1;
}

static void noctty_flush_replies(NocttyWindowsHost *host) {
    uint8_t replies[4096];
    for (int attempt = 0; attempt < 16; attempt++) {
        int count = host->callbacks->take_reply(
            host->callbacks->userdata, replies, sizeof(replies));
        if (count <= 0) break;
        if (!noctty_write_terminal(host, replies, (size_t)count)) break;
    }
}

static void noctty_drain_output(NocttyWindowsHost *host) {
    uint8_t scratch[NOCTTY_OUTPUT_DRAIN_BYTES];
    size_t total = 0;

    while (total < 2u * 1024u * 1024u) {
        size_t count;
        size_t first;
        EnterCriticalSection(&host->output_lock);
        count = host->output_length;
        if (count > sizeof(scratch)) count = sizeof(scratch);
        first = NOCTTY_OUTPUT_RING_BYTES - host->output_start;
        if (first > count) first = count;
        if (first > 0)
            memcpy(scratch, host->output_ring + host->output_start, first);
        if (count > first)
            memcpy(scratch + first, host->output_ring, count - first);
        host->output_start =
            (host->output_start + count) % NOCTTY_OUTPUT_RING_BYTES;
        host->output_length -= count;
        LeaveCriticalSection(&host->output_lock);
        if (count == 0) break;
        if (host->callbacks->feed(host->callbacks->userdata, scratch, count) <
            0) {
            noctty_log("vt_feed_failed bytes=%zu\r\n", count);
            DestroyWindow(host->window);
            return;
        }
        total += count;
    }
    if (total > 0) {
        noctty_flush_replies(host);
        noctty_update_title(host);
        InvalidateRect(host->window, NULL, FALSE);
    }
}

static DWORD WINAPI noctty_reader_thread(void *raw) {
    NocttyWindowsHost *host = raw;
    uint8_t input[65536];

    while (InterlockedCompareExchange(&host->stopping, 0, 0) == 0) {
        DWORD count = 0;
        if (!ReadFile(host->output_read, input, sizeof(input), &count, NULL)) {
            DWORD error = GetLastError();
            if (error != ERROR_BROKEN_PIPE && error != ERROR_OPERATION_ABORTED)
                noctty_log("output_read_failed error=%lu\r\n", error);
            break;
        }
        if (count == 0) break;
        size_t offset = 0;
        while (offset < count &&
               InterlockedCompareExchange(&host->stopping, 0, 0) == 0) {
            size_t available;
            size_t write_at;
            size_t chunk;
            EnterCriticalSection(&host->output_lock);
            available = NOCTTY_OUTPUT_RING_BYTES - host->output_length;
            write_at = (host->output_start + host->output_length) %
                       NOCTTY_OUTPUT_RING_BYTES;
            chunk = (size_t)count - offset;
            if (chunk > available) chunk = available;
            if (chunk > NOCTTY_OUTPUT_RING_BYTES - write_at)
                chunk = NOCTTY_OUTPUT_RING_BYTES - write_at;
            if (chunk > 0) {
                memcpy(host->output_ring + write_at, input + offset, chunk);
                host->output_length += chunk;
            }
            LeaveCriticalSection(&host->output_lock);
            if (chunk == 0) {
                Sleep(1);
            } else {
                offset += chunk;
            }
        }
        PostMessageW(host->window, NOCTTY_WM_OUTPUT, 0, 0);
    }
    PostMessageW(host->window, NOCTTY_WM_OUTPUT, 0, 0);
    return 0;
}

static int noctty_create_pseudo_console(NocttyWindowsHost *host) {
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

    if (!CreatePipe(&input_read, &host->input_write, NULL, 0)) goto failed;
    if (!CreatePipe(&host->output_read, &output_write, NULL, 0)) goto failed;
    size.X = (SHORT)host->columns;
    size.Y = (SHORT)host->rows;
    result = CreatePseudoConsole(size, input_read, output_write, 0,
                                 &host->pseudo_console);
    if (FAILED(result)) {
        noctty_log("conpty_create_failed hresult=0x%08lx\r\n",
                   (unsigned long)result);
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
            host->pseudo_console, sizeof(host->pseudo_console), NULL, NULL))
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
    commands[command_count++] = powershell_command;
    commands[command_count++] = cmd_command;

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
            host->process = process.hProcess;
            CloseHandle(process.hThread);
            noctty_log("shell_spawned candidate=%zu pid=%lu\r\n", index,
                       process.dwProcessId);
            if (attributes_initialized)
                DeleteProcThreadAttributeList(attributes);
            HeapFree(GetProcessHeap(), 0, attributes);
            return 1;
        }
        noctty_log("shell_spawn_failed candidate=%zu error=%lu\r\n", index,
                   GetLastError());
    }

failed:
    if (attributes != NULL) {
        if (attributes_initialized)
            DeleteProcThreadAttributeList(attributes);
        HeapFree(GetProcessHeap(), 0, attributes);
    }
    noctty_close_handle(&input_read);
    noctty_close_handle(&output_write);
    noctty_close_handle(&host->input_write);
    noctty_close_handle(&host->output_read);
    if (host->pseudo_console != NULL) {
        ClosePseudoConsole(host->pseudo_console);
        host->pseudo_console = NULL;
    }
    return 0;
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
        SetWindowTextW(host->window, host->process_exited
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
    int columns;
    int rows;
    COORD size;
    if (host->cell_width <= 0 || host->cell_height <= 0) return;
    columns = width / host->cell_width;
    rows = height / host->cell_height;
    if (columns < 1) columns = 1;
    if (rows < 1) rows = 1;
    if (columns > 1000) columns = 1000;
    if (rows > 500) rows = 500;
    if (columns == host->columns && rows == host->rows) return;
    if (host->callbacks->resize(host->callbacks->userdata, columns, rows) < 0)
        return;
    host->columns = columns;
    host->rows = rows;
    if (host->pseudo_console != NULL) {
        size.X = (SHORT)columns;
        size.Y = (SHORT)rows;
        if (FAILED(ResizePseudoConsole(host->pseudo_console, size)))
            noctty_log("conpty_resize_failed columns=%d rows=%d\r\n", columns,
                       rows);
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

static void noctty_copy_visible(NocttyWindowsHost *host) {
    uint8_t *utf8;
    size_t used = 0;
    int wide_count;
    HGLOBAL memory;
    WCHAR *wide;

    utf8 = HeapAlloc(GetProcessHeap(), 0, NOCTTY_COPY_BYTES_MAX);
    if (utf8 == NULL) return;
    for (int row = 0; row < host->rows; row++) {
        size_t row_start = used;
        for (int column = 0; column < host->columns; column++) {
            uint8_t text[128];
            int count = host->callbacks->cell_text(
                host->callbacks->userdata, column, row, text, sizeof(text));
            if (count <= 0) continue;
            if (used + (size_t)count + 2u > NOCTTY_COPY_BYTES_MAX) goto done;
            memcpy(utf8 + used, text, (size_t)count);
            used += (size_t)count;
        }
        while (used > row_start && utf8[used - 1] == ' ') used--;
        if (row + 1 < host->rows) {
            if (used >= NOCTTY_COPY_BYTES_MAX) goto done;
            utf8[used++] = '\n';
        }
    }

done:
    wide_count = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
                                     (const char *)utf8, (int)used, NULL, 0);
    if (wide_count <= 0) {
        HeapFree(GetProcessHeap(), 0, utf8);
        return;
    }
    memory = GlobalAlloc(GMEM_MOVEABLE,
                         ((size_t)wide_count + 1u) * sizeof(WCHAR));
    if (memory == NULL) {
        HeapFree(GetProcessHeap(), 0, utf8);
        return;
    }
    wide = GlobalLock(memory);
    if (wide != NULL) {
        MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
                            (const char *)utf8, (int)used, wide, wide_count);
        wide[wide_count] = L'\0';
        GlobalUnlock(memory);
        if (OpenClipboard(host->window)) {
            EmptyClipboard();
            if (SetClipboardData(CF_UNICODETEXT, memory) != NULL) memory = NULL;
            CloseClipboard();
        }
    }
    if (memory != NULL) GlobalFree(memory);
    HeapFree(GetProcessHeap(), 0, utf8);
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
        case WM_SIZE:
            if (word != SIZE_MINIMIZED)
                noctty_resize_terminal(host, LOWORD(long_value),
                                       HIWORD(long_value));
            return 0;
        case WM_GETMINMAXINFO: {
            MINMAXINFO *limits = (MINMAXINFO *)long_value;
            limits->ptMinTrackSize.x = NOCTTY_WINDOW_MIN_WIDTH;
            limits->ptMinTrackSize.y = NOCTTY_WINDOW_MIN_HEIGHT;
            return 0;
        }
        case WM_DPICHANGED: {
            RECT *suggested = (RECT *)long_value;
            noctty_create_fonts(host, HIWORD(word));
            SetWindowPos(window, NULL, suggested->left, suggested->top,
                         suggested->right - suggested->left,
                         suggested->bottom - suggested->top,
                         SWP_NOACTIVATE | SWP_NOZORDER);
            return 0;
        }
        case WM_SETFOCUS:
        case WM_KILLFOCUS:
            InvalidateRect(window, NULL, FALSE);
            return 0;
        case WM_MOUSEWHEEL: {
            int steps = GET_WHEEL_DELTA_WPARAM(word) / WHEEL_DELTA;
            if (steps != 0) {
                host->callbacks->scroll(host->callbacks->userdata, steps * 3);
                InvalidateRect(window, NULL, FALSE);
            }
            return 0;
        }
        case WM_KEYDOWN:
        case WM_SYSKEYDOWN: {
            int control = (GetKeyState(VK_CONTROL) & 0x8000) != 0;
            int shift = (GetKeyState(VK_SHIFT) & 0x8000) != 0;
            int alt = (GetKeyState(VK_MENU) & 0x8000) != 0;
            if (alt && word == VK_F4)
                return DefWindowProcW(window, message, word, long_value);
            if (control && shift && word == 'C') {
                host->suppress_character = 1;
                noctty_copy_visible(host);
                return 0;
            }
            if (control && shift && word == 'V') {
                host->suppress_character = 1;
                noctty_paste_clipboard(host);
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
            noctty_drain_output(host);
            return 0;
        case WM_TIMER:
            noctty_drain_output(host);
            noctty_drain_remote_input(host);
            if (host->process == NULL) {
                noctty_update_title(host);
                InvalidateRect(window, NULL, FALSE);
            }
            host->smoke_ticks++;
            if (!host->process_exited && host->process != NULL &&
                WaitForSingleObject(host->process, 0) == WAIT_OBJECT_0) {
                DWORD process_exit_code = 255;
                GetExitCodeProcess(host->process, &process_exit_code);
                host->process_exited = 1;
                host->process_exit_code = process_exit_code;
                noctty_log("shell_exit code=%lu\r\n", process_exit_code);
                noctty_update_title(host);
                InvalidateRect(window, NULL, FALSE);
            }
            if (host->smoke_mode && host->process_exited) {
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
                    host->process_exit_code == 0) {
                    noctty_log("windows_host_smoke conpty=true vt=true "
                               "gdi=true clean_exit=true\r\n");
                    host->exit_code = 0;
                    DestroyWindow(window);
                } else if (host->smoke_ticks > 625u) {
                    noctty_log("windows_host_smoke conpty=true vt=%s "
                               "gdi=%s process_exit=%lu clean_exit=false\r\n",
                               marker ? "true" : "false",
                               host->paint_count > 0 ? "true" : "false",
                               host->process_exit_code);
                    host->exit_code = 2;
                    DestroyWindow(window);
                }
            }
            return 0;
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
    InterlockedExchange(&host->stopping, 1);
    if (host->reader_thread != NULL)
        CancelSynchronousIo(host->reader_thread);
    noctty_close_handle(&host->input_write);
    noctty_close_handle(&host->output_read);
    if (host->pseudo_console != NULL) {
        ClosePseudoConsole(host->pseudo_console);
        host->pseudo_console = NULL;
    }
    if (host->reader_thread != NULL) {
        WaitForSingleObject(host->reader_thread, INFINITE);
        noctty_close_handle(&host->reader_thread);
    }
    if (host->process != NULL) {
        if (WaitForSingleObject(host->process, 500) == WAIT_TIMEOUT) {
            TerminateProcess(host->process, 1);
            WaitForSingleObject(host->process, 500);
        }
        noctty_close_handle(&host->process);
    }
    if (host->font_normal != NULL) DeleteObject(host->font_normal);
    if (host->font_bold != NULL) DeleteObject(host->font_bold);
    DeleteCriticalSection(&host->output_lock);
    if (host->output_ring != NULL)
        HeapFree(GetProcessHeap(), 0, host->output_ring);
    noctty_log("windows_exit clean=true\r\n");
    noctty_close_handle(&noctty_log_file);
}

static void noctty_drain_remote_input(NocttyWindowsHost *host) {
    uint8_t input[4096];
    if (host->input_write == NULL) return;
    for (int attempt = 0; attempt < 16; attempt++) {
        int count = host->callbacks->take_remote(
            host->callbacks->userdata, input, sizeof(input));
        if (count <= 0) break;
        if (!noctty_write_terminal(host, input, (size_t)count)) break;
    }
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
    host->smoke_mode =
        GetEnvironmentVariableW(L"NOCTTY_WINDOWS_HOST_SMOKE", smoke_value,
                                sizeof(smoke_value) / sizeof(WCHAR)) > 0 &&
        smoke_value[0] != L'0';
    host->columns = NOCTTY_DEFAULT_COLUMNS;
    host->rows = NOCTTY_DEFAULT_ROWS;
    host->output_ring =
        HeapAlloc(GetProcessHeap(), 0, NOCTTY_OUTPUT_RING_BYTES);
    if (host->output_ring == NULL) {
        HeapFree(GetProcessHeap(), 0, host);
        return 1;
    }
    InitializeCriticalSection(&host->output_lock);

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
    dpi = GetDpiForWindow(host->window);
    if (dpi == 0) dpi = 96;
    if (!noctty_create_fonts(host, dpi)) goto finished;
    GetClientRect(host->window, &client);
    noctty_resize_terminal(host, client.right, client.bottom);
    {
        int start_mode = host->callbacks->start(host->callbacks->userdata);
        if (start_mode < 0) {
            MessageBoxW(host->window, L"NOCTTY could not start this session.",
                        L"NOCTTY Windows alpha", MB_OK | MB_ICONERROR);
            goto finished;
        }
        session_started = 1;
        if (start_mode > 0) goto renderer_started;
    }
    if (!noctty_create_pseudo_console(host)) {
        MessageBoxW(host->window,
                    L"NOCTTY could not start Windows ConPTY. Windows 10 "
                    L"version 1809 or newer is required.",
                    L"NOCTTY Windows alpha", MB_OK | MB_ICONERROR);
        goto finished;
    }
    host->reader_thread =
        CreateThread(NULL, 0, noctty_reader_thread, host, 0, NULL);
    if (host->reader_thread == NULL) {
        noctty_log("reader_thread_failed error=%lu\r\n", GetLastError());
        goto finished;
    }
renderer_started:
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
