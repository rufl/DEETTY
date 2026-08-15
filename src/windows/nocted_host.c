#ifndef UNICODE
#define UNICODE
#endif
#ifndef _UNICODE
#define _UNICODE
#endif
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <commctrl.h>
#include <commdlg.h>
#include <richedit.h>
#include <shellapi.h>
#include <shlobj.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <wchar.h>
#include "nocted_host.h"

#define NOCTED_CLASS_NAME L"NoctEdWindowsEditor"
#define NOCTED_INVALID_INDEX ((size_t)-1)
#define NOCTED_MAX_TABS 32u
#define ID_FILE_NEW 41001
#define ID_FILE_OPEN 41002
#define ID_FILE_OPEN_FOLDER 41003
#define ID_FILE_SAVE 41004
#define ID_FILE_SAVE_AS 41005
#define ID_FILE_CLOSE 41006
#define ID_FILE_EXIT 41007
#define ID_EDIT_UNDO 41101
#define ID_EDIT_REDO 41102
#define ID_EDIT_CUT 41103
#define ID_EDIT_COPY 41104
#define ID_EDIT_PASTE 41105
#define ID_EDIT_SELECT_ALL 41106
#define ID_EDIT_FIND 41107
#define ID_CONTROL_TABS 42001
#define ID_CONTROL_TREE 42002
#define ID_CONTROL_EDITOR 42003
#define ID_CONTROL_STATUS 42004
#define ID_CONTROL_FIND 42005
#define ID_CONTROL_FIND_NEXT 42006

typedef struct {
    HINSTANCE instance;
    HWND window, tabs, tree, editor, status, find_edit, find_button;
    HFONT font;
    HACCEL accelerators;
    HMODULE rich_edit;
    const NoctedWindowsCallbacks *callbacks;
    int suppress_change, find_visible;
    UINT dpi;
} NoctedHost;

static LRESULT CALLBACK nocted_window_proc(HWND, UINT, WPARAM, LPARAM);
static void nocted_sync(NoctedHost *host);
static int nocted_save(NoctedHost *host, int force_path);

static wchar_t *utf8_to_wide(const uint8_t *bytes, size_t length) {
    int count;
    wchar_t *wide;
    if (length > (size_t)INT_MAX) return NULL;
    if (length == 0) return (wchar_t *)calloc(1u, sizeof(wchar_t));
    count = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
                                (const char *)bytes, (int)length, NULL, 0);
    if (count <= 0) return NULL;
    wide = (wchar_t *)calloc((size_t)count + 1u, sizeof(wchar_t));
    if (wide == NULL) return NULL;
    if (MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
                            (const char *)bytes, (int)length, wide, count) != count) {
        free(wide);
        return NULL;
    }
    return wide;
}

static uint8_t *wide_to_utf8(const wchar_t *wide, size_t *length_out) {
    size_t wide_size;
    int wide_length, count;
    uint8_t *bytes;
    if (wide == NULL || length_out == NULL) return NULL;
    wide_size = wcslen(wide);
    if (wide_size > (size_t)INT_MAX) return NULL;
    wide_length = (int)wide_size;
    if (wide_length == 0) {
        bytes = (uint8_t *)calloc(1u, 1u);
        if (bytes != NULL) *length_out = 0;
        return bytes;
    }
    count = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, wide, wide_length,
                                NULL, 0, NULL, NULL);
    if (count <= 0) return NULL;
    bytes = (uint8_t *)malloc((size_t)count + 1u);
    if (bytes == NULL) return NULL;
    if (WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, wide, wide_length,
                            (char *)bytes, count, NULL, NULL) != count) {
        free(bytes);
        return NULL;
    }
    bytes[count] = 0;
    *length_out = (size_t)count;
    return bytes;
}

static wchar_t *callback_text(NoctedHost *host,
                              size_t (*callback)(void *, uint8_t *, size_t)) {
    uint8_t ignored = 0;
    size_t length = callback(host->callbacks->userdata, &ignored, 0);
    uint8_t *bytes;
    wchar_t *wide;
    if (length == 0) return utf8_to_wide((const uint8_t *)"", 0);
    bytes = (uint8_t *)malloc(length);
    if (bytes == NULL) return NULL;
    if (callback(host->callbacks->userdata, bytes, length) != length) {
        free(bytes);
        return NULL;
    }
    wide = utf8_to_wide(bytes, length);
    free(bytes);
    return wide;
}

static void show_error(NoctedHost *host, const wchar_t *fallback) {
    wchar_t *detail = callback_text(host, host->callbacks->last_error);
    MessageBoxW(host->window,
                detail != NULL && detail[0] != L'\0' ? detail : fallback,
                L"NoctEd", MB_OK | MB_ICONERROR);
    free(detail);
}

void nocted_windows_show_message(const wchar_t *message, int is_error) {
    MessageBoxW(NULL, message, L"NoctEd",
                MB_OK | (is_error ? MB_ICONERROR : MB_ICONINFORMATION));
}

int nocted_windows_has_argument(const wchar_t *argument) {
    int count = 0, index, found = 0;
    LPWSTR *arguments = CommandLineToArgvW(GetCommandLineW(), &count);
    if (arguments == NULL) return 0;
    for (index = 1; index < count; index++)
        if (wcscmp(arguments[index], argument) == 0) { found = 1; break; }
    LocalFree(arguments);
    return found;
}

int nocted_windows_session_path(uint8_t *output, size_t capacity) {
    wchar_t base[32768], directory[32768], editor[32768], session[32768];
    DWORD length;
    int count;
    length = GetEnvironmentVariableW(L"LOCALAPPDATA", base,
                                     (DWORD)(sizeof(base) / sizeof(base[0])));
    if (length == 0 || length >= (DWORD)(sizeof(base) / sizeof(base[0]))) return 0;
    if (wcslen(base) + 8u >= sizeof(directory) / sizeof(directory[0])) return 0;
    wcscpy(directory, base); wcscat(directory, L"\\NOCTTY");
    if (!CreateDirectoryW(directory, NULL) && GetLastError() != ERROR_ALREADY_EXISTS) return 0;
    if (wcslen(directory) + 9u >= sizeof(editor) / sizeof(editor[0])) return 0;
    wcscpy(editor, directory); wcscat(editor, L"\\NoctEd");
    if (!CreateDirectoryW(editor, NULL) && GetLastError() != ERROR_ALREADY_EXISTS) return 0;
    if (wcslen(editor) + 14u >= sizeof(session) / sizeof(session[0])) return 0;
    wcscpy(session, editor); wcscat(session, L"\\session.conf");
    count = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, session, -1,
                                NULL, 0, NULL, NULL);
    if (count <= 1 || (size_t)count > capacity) return 0;
    if (WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, session, -1,
                            (char *)output, count, NULL, NULL) != count) return 0;
    return count - 1;
}

static UINT window_dpi(HWND window) {
    typedef UINT(WINAPI *DpiFn)(HWND);
    HMODULE user = GetModuleHandleW(L"user32.dll");
    DpiFn function = user == NULL ? NULL :
        (DpiFn)(void *)GetProcAddress(user, "GetDpiForWindow");
    return function == NULL ? 96u : function(window);
}

static void update_font(NoctedHost *host) {
    LOGFONTW description;
    if (host->font != NULL) DeleteObject(host->font);
    ZeroMemory(&description, sizeof(description));
    description.lfHeight = -MulDiv(11, (int)host->dpi, 72);
    wcscpy(description.lfFaceName, L"Consolas");
    host->font = CreateFontIndirectW(&description);
    if (host->font == NULL) return;
    SendMessageW(host->editor, WM_SETFONT, (WPARAM)host->font, TRUE);
    SendMessageW(host->tabs, WM_SETFONT, (WPARAM)host->font, TRUE);
    SendMessageW(host->tree, WM_SETFONT, (WPARAM)host->font, TRUE);
    SendMessageW(host->status, WM_SETFONT, (WPARAM)host->font, TRUE);
    SendMessageW(host->find_edit, WM_SETFONT, (WPARAM)host->font, TRUE);
    SendMessageW(host->find_button, WM_SETFONT, (WPARAM)host->font, TRUE);
}

static void layout(NoctedHost *host) {
    RECT client;
    int width, height, tree_width, status_height, tab_height, find_height, bottom;
    GetClientRect(host->window, &client);
    width = client.right; height = client.bottom;
    tree_width = host->callbacks->project_entry_count(host->callbacks->userdata) != 0
                     ? MulDiv(260, (int)host->dpi, 96) : 0;
    status_height = MulDiv(24, (int)host->dpi, 96);
    tab_height = MulDiv(30, (int)host->dpi, 96);
    find_height = host->find_visible ? MulDiv(30, (int)host->dpi, 96) : 0;
    bottom = height - status_height;
    MoveWindow(host->tabs, tree_width, 0, width - tree_width, tab_height, TRUE);
    MoveWindow(host->tree, 0, 0, tree_width, bottom, TRUE);
    ShowWindow(host->tree, tree_width != 0 ? SW_SHOW : SW_HIDE);
    MoveWindow(host->editor, tree_width, tab_height, width - tree_width,
               bottom - tab_height - find_height, TRUE);
    MoveWindow(host->find_edit, tree_width + 4, bottom - find_height + 3,
               width - tree_width - 104, find_height - 6, TRUE);
    MoveWindow(host->find_button, width - 96, bottom - find_height + 3, 92,
               find_height - 6, TRUE);
    ShowWindow(host->find_edit, host->find_visible ? SW_SHOW : SW_HIDE);
    ShowWindow(host->find_button, host->find_visible ? SW_SHOW : SW_HIDE);
    MoveWindow(host->status, 0, bottom, width, status_height, TRUE);
}

static void sync_tabs(NoctedHost *host) {
    size_t count = host->callbacks->tab_count(host->callbacks->userdata);
    size_t active = host->callbacks->active_tab(host->callbacks->userdata), index;
    TabCtrl_DeleteAllItems(host->tabs);
    for (index = 0; index < count; index++) {
        uint8_t bytes[2048]; int dirty = 0, read_only = 0; TCITEMW item;
        size_t length = host->callbacks->tab_title(host->callbacks->userdata,
            index, bytes, sizeof(bytes) - 4u, &dirty, &read_only);
        wchar_t *title;
        (void)read_only;
        if (length > sizeof(bytes) - 4u) length = sizeof(bytes) - 4u;
        if (dirty) bytes[length++] = '*';
        title = utf8_to_wide(bytes, length);
        if (title == NULL) continue;
        ZeroMemory(&item, sizeof(item)); item.mask = TCIF_TEXT; item.pszText = title;
        TabCtrl_InsertItem(host->tabs, (int)index, &item); free(title);
    }
    if (active != NOCTED_INVALID_INDEX && active < count)
        TabCtrl_SetCurSel(host->tabs, (int)active);
}

static void sync_editor(NoctedHost *host) {
    size_t length = host->callbacks->active_content_length(host->callbacks->userdata);
    uint8_t *bytes = (uint8_t *)malloc(length == 0 ? 1u : length);
    wchar_t *wide; size_t active; int dirty = 0, read_only = 0; uint8_t ignored[1];
    if (bytes == NULL) return;
    if (length != 0 && host->callbacks->active_content(host->callbacks->userdata,
                                                        bytes, length) != length) {
        free(bytes); return;
    }
    wide = utf8_to_wide(bytes, length); free(bytes); if (wide == NULL) return;
    active = host->callbacks->active_tab(host->callbacks->userdata);
    if (active != NOCTED_INVALID_INDEX)
        (void)host->callbacks->tab_title(host->callbacks->userdata, active,
                                         ignored, 0, &dirty, &read_only);
    (void)dirty;
    host->suppress_change = 1;
    SetWindowTextW(host->editor, wide);
    SendMessageW(host->editor, EM_SETREADONLY, (WPARAM)read_only, 0);
    SendMessageW(host->editor, EM_SETMODIFY, FALSE, 0);
    host->suppress_change = 0; free(wide);
}

static void sync_project(NoctedHost *host) {
    size_t count = host->callbacks->project_entry_count(host->callbacks->userdata);
    HTREEITEM *items; size_t index;
    TreeView_DeleteAllItems(host->tree); if (count == 0) return;
    items = (HTREEITEM *)calloc(count, sizeof(HTREEITEM)); if (items == NULL) return;
    for (index = 0; index < count; index++) {
        uint8_t bytes[4096]; size_t parent = NOCTED_INVALID_INDEX;
        int directory = 0; TVINSERTSTRUCTW insert;
        size_t length = host->callbacks->project_entry(host->callbacks->userdata,
            index, bytes, sizeof(bytes), &parent, &directory);
        wchar_t *name;
        if (length > sizeof(bytes)) length = sizeof(bytes);
        name = utf8_to_wide(bytes, length); if (name == NULL) continue;
        ZeroMemory(&insert, sizeof(insert));
        insert.hParent = parent != NOCTED_INVALID_INDEX && parent < index
                             ? items[parent] : TVI_ROOT;
        insert.hInsertAfter = TVI_LAST;
        insert.item.mask = TVIF_TEXT | TVIF_PARAM | TVIF_CHILDREN;
        insert.item.pszText = name; insert.item.lParam = (LPARAM)index;
        insert.item.cChildren = directory;
        items[index] = TreeView_InsertItem(host->tree, &insert); free(name);
    }
    free(items);
}

static void update_chrome(NoctedHost *host) {
    wchar_t *path = callback_text(host, host->callbacks->active_path);
    wchar_t *project = callback_text(host, host->callbacks->project_name);
    wchar_t title[32768];
    const wchar_t *shown = path != NULL && path[0] != L'\0' ? path : L"Untitled";
    _snwprintf(title, sizeof(title) / sizeof(title[0]) - 1u, L"%ls - NoctEd", shown);
    title[sizeof(title) / sizeof(title[0]) - 1u] = L'\0';
    SetWindowTextW(host->window, title);
    SetWindowTextW(host->status, project != NULL && project[0] != L'\0'
                                    ? project : L"No project folder open");
    free(path); free(project);
}

static void nocted_sync(NoctedHost *host) {
    sync_tabs(host); sync_editor(host); sync_project(host); update_chrome(host);
    layout(host); SetFocus(host->editor);
}

static void editor_changed(NoctedHost *host) {
    int wide_length; wchar_t *wide; uint8_t *utf8; size_t length = 0;
    if (host->suppress_change) return;
    wide_length = GetWindowTextLengthW(host->editor);
    wide = (wchar_t *)calloc((size_t)wide_length + 1u, sizeof(wchar_t));
    if (wide == NULL) return;
    GetWindowTextW(host->editor, wide, wide_length + 1);
    utf8 = wide_to_utf8(wide, &length); free(wide); if (utf8 == NULL) return;
    if (host->callbacks->replace_contents(host->callbacks->userdata, utf8, length) < 0) {
        show_error(host, L"The edit could not be applied."); sync_editor(host);
    } else { sync_tabs(host); update_chrome(host); }
    free(utf8);
}

static int open_file(NoctedHost *host) {
    OPENFILENAMEW dialog; wchar_t path[32768]; uint8_t *utf8; size_t length; int result;
    ZeroMemory(path, sizeof(path)); ZeroMemory(&dialog, sizeof(dialog));
    dialog.lStructSize = sizeof(dialog); dialog.hwndOwner = host->window;
    dialog.lpstrFile = path; dialog.nMaxFile = (DWORD)(sizeof(path) / sizeof(path[0]));
    dialog.lpstrFilter = L"Text files\0*.txt;*.zig;*.c;*.h;*.md;*.json;*.toml;*.yaml;*.yml\0All files\0*.*\0\0";
    dialog.Flags = OFN_FILEMUSTEXIST | OFN_PATHMUSTEXIST | OFN_HIDEREADONLY | OFN_EXPLORER;
    if (!GetOpenFileNameW(&dialog)) return 0;
    utf8 = wide_to_utf8(path, &length); if (utf8 == NULL) return 0;
    result = host->callbacks->open_document(host->callbacks->userdata, utf8, length); free(utf8);
    if (result < 0) { show_error(host, L"The file could not be opened."); return 0; }
    nocted_sync(host); return 1;
}

static int open_folder(NoctedHost *host) {
    BROWSEINFOW browse; PIDLIST_ABSOLUTE item; wchar_t path[32768];
    uint8_t *utf8; size_t length; int result;
    ZeroMemory(&browse, sizeof(browse)); browse.hwndOwner = host->window;
    browse.lpszTitle = L"Open a project folder";
    browse.ulFlags = BIF_RETURNONLYFSDIRS | BIF_NEWDIALOGSTYLE;
    item = SHBrowseForFolderW(&browse); if (item == NULL) return 0;
    if (!SHGetPathFromIDListW(item, path)) { CoTaskMemFree(item); return 0; }
    CoTaskMemFree(item); utf8 = wide_to_utf8(path, &length); if (utf8 == NULL) return 0;
    result = host->callbacks->open_project(host->callbacks->userdata, utf8, length); free(utf8);
    if (result < 0) { show_error(host, L"The folder could not be opened."); return 0; }
    nocted_sync(host); return 1;
}

static int save_as(NoctedHost *host) {
    OPENFILENAMEW dialog; wchar_t path[32768]; wchar_t *current;
    uint8_t *utf8; size_t length; int result;
    ZeroMemory(path, sizeof(path)); current = callback_text(host, host->callbacks->active_path);
    if (current != NULL && current[0] != L'\0')
        wcsncpy(path, current, sizeof(path) / sizeof(path[0]) - 1u);
    free(current); ZeroMemory(&dialog, sizeof(dialog)); dialog.lStructSize = sizeof(dialog);
    dialog.hwndOwner = host->window; dialog.lpstrFile = path;
    dialog.nMaxFile = (DWORD)(sizeof(path) / sizeof(path[0]));
    dialog.lpstrFilter = L"Text files\0*.txt\0All files\0*.*\0\0";
    dialog.Flags = OFN_PATHMUSTEXIST | OFN_OVERWRITEPROMPT | OFN_EXPLORER;
    if (!GetSaveFileNameW(&dialog)) return 0;
    utf8 = wide_to_utf8(path, &length); if (utf8 == NULL) return 0;
    result = host->callbacks->save_document(host->callbacks->userdata, utf8, length); free(utf8);
    if (result != NOCTED_CLOSE_OK) { show_error(host, L"The file could not be saved."); return 0; }
    nocted_sync(host); return 1;
}

static int nocted_save(NoctedHost *host, int force_path) {
    int result;
    if (force_path) return save_as(host);
    result = host->callbacks->save_document(host->callbacks->userdata, NULL, 0);
    if (result == NOCTED_SAVE_NEEDS_PATH) return save_as(host);
    if (result != NOCTED_CLOSE_OK) { show_error(host, L"The file could not be saved."); return 0; }
    nocted_sync(host); return 1;
}

static int close_current(NoctedHost *host, int exiting) {
    size_t active = host->callbacks->active_tab(host->callbacks->userdata);
    int result, answer;
    if (active == NOCTED_INVALID_INDEX) return 1;
    result = host->callbacks->close_document(host->callbacks->userdata, active, 0);
    if (result == NOCTED_CLOSE_DIRTY) {
        answer = MessageBoxW(host->window, L"Save changes before closing this document?",
                             L"Unsaved changes", MB_YESNOCANCEL | MB_ICONWARNING);
        if (answer == IDCANCEL) return 0;
        if (answer == IDYES && !nocted_save(host, 0)) return 0;
        result = host->callbacks->close_document(host->callbacks->userdata, active, 1);
    }
    if (result != NOCTED_CLOSE_OK) { show_error(host, L"The document could not be closed."); return 0; }
    if (!exiting && host->callbacks->tab_count(host->callbacks->userdata) == 0) {
        if (host->callbacks->new_document(host->callbacks->userdata) < 0) return 0;
    }
    if (!exiting) nocted_sync(host);
    return 1;
}

static int confirm_exit(NoctedHost *host) {
    size_t count = host->callbacks->tab_count(host->callbacks->userdata);
    size_t original = host->callbacks->active_tab(host->callbacks->userdata);
    int discard[NOCTED_MAX_TABS] = {0};
    size_t index;
    if (count > NOCTED_MAX_TABS) {
        MessageBoxW(host->window, L"Too many editor tabs are open.",
                    L"NoctEd", MB_OK | MB_ICONERROR);
        return 0;
    }
    for (index = 0; index < count; index++) {
        uint8_t ignored[1];
        int dirty = 0;
        int read_only = 0;
        int answer;
        (void)host->callbacks->tab_title(host->callbacks->userdata, index,
                                         ignored, 0, &dirty, &read_only);
        (void)read_only;
        if (!dirty) continue;
        if (!host->callbacks->activate_document(host->callbacks->userdata,
                                                 index))
            return 0;
        answer = MessageBoxW(host->window,
                             L"Save changes before exiting NoctEd?",
                             L"Unsaved changes",
                             MB_YESNOCANCEL | MB_ICONWARNING);
        if (answer == IDCANCEL) {
            if (original < count)
                (void)host->callbacks->activate_document(
                    host->callbacks->userdata, original);
            nocted_sync(host);
            return 0;
        }
        if (answer == IDYES && !nocted_save(host, 0)) {
            if (original < count)
                (void)host->callbacks->activate_document(
                    host->callbacks->userdata, original);
            nocted_sync(host);
            return 0;
        }
        if (answer == IDNO) discard[index] = 1;
    }
    index = count;
    while (index > 0) {
        index--;
        if (discard[index] &&
            host->callbacks->discard_document(host->callbacks->userdata,
                                               index) != NOCTED_CLOSE_OK) {
            show_error(host, L"The document changes could not be discarded.");
            return 0;
        }
    }
    if (original < count && !discard[original]) {
        size_t restored_original = original;
        for (index = 0; index < original; index++) {
            if (discard[index]) restored_original--;
        }
        (void)host->callbacks->activate_document(host->callbacks->userdata,
                                                  restored_original);
    }
    nocted_sync(host);
    if (host->callbacks->persist_session(host->callbacks->userdata) <= 0) {
        show_error(host, L"The editor session could not be saved.");
        return 0;
    }
    return 1;
}

static void find_next(NoctedHost *host) {
    int length = GetWindowTextLengthW(host->find_edit); wchar_t *query;
    CHARRANGE selection; FINDTEXTEXW find; LRESULT result;
    if (length <= 0) return;
    query = (wchar_t *)calloc((size_t)length + 1u, sizeof(wchar_t)); if (query == NULL) return;
    GetWindowTextW(host->find_edit, query, length + 1);
    SendMessageW(host->editor, EM_EXGETSEL, 0, (LPARAM)&selection);
    ZeroMemory(&find, sizeof(find)); find.chrg.cpMin = selection.cpMax;
    find.chrg.cpMax = -1; find.lpstrText = query;
    result = SendMessageW(host->editor, EM_FINDTEXTEXW, FR_DOWN, (LPARAM)&find);
    if (result == -1) { find.chrg.cpMin = 0; find.chrg.cpMax = selection.cpMin;
        result = SendMessageW(host->editor, EM_FINDTEXTEXW, FR_DOWN, (LPARAM)&find); }
    if (result != -1) { SendMessageW(host->editor, EM_EXSETSEL, 0, (LPARAM)&find.chrgText);
        SendMessageW(host->editor, EM_SCROLLCARET, 0, 0); SetFocus(host->editor); }
    else MessageBeep(MB_ICONINFORMATION);
    free(query);
}

static void show_find(NoctedHost *host) {
    host->find_visible = 1; layout(host); SetFocus(host->find_edit);
    SendMessageW(host->find_edit, EM_SETSEL, 0, -1);
}

static void open_tree_selection(NoctedHost *host) {
    HTREEITEM selected = TreeView_GetSelection(host->tree); TVITEMW item; int result;
    if (selected == NULL) return; ZeroMemory(&item, sizeof(item));
    item.mask = TVIF_PARAM; item.hItem = selected;
    if (!TreeView_GetItem(host->tree, &item)) return;
    result = host->callbacks->open_project_entry(host->callbacks->userdata, (size_t)item.lParam);
    if (result < 0) { TreeView_Expand(host->tree, selected, TVE_TOGGLE); return; }
    nocted_sync(host);
}

static void parse_launch(NoctedHost *host) {
    int count = 0, index; LPWSTR *arguments = CommandLineToArgvW(GetCommandLineW(), &count);
    if (arguments == NULL) return;
    for (index = 1; index < count; index++) {
        int project = 0, result; const wchar_t *path; uint8_t *utf8; size_t length;
        if (wcscmp(arguments[index], L"--self-test") == 0) continue;
        if (wcscmp(arguments[index], L"--project") == 0) {
            project = 1; if (++index >= count) { MessageBoxW(host->window,
                L"--project requires a folder path.", L"NoctEd", MB_OK | MB_ICONERROR); break; }
        } else if (wcscmp(arguments[index], L"--open") == 0) {
            if (++index >= count) { MessageBoxW(host->window,
                L"--open requires a file path.", L"NoctEd", MB_OK | MB_ICONERROR); break; }
        } else if (arguments[index][0] == L'-') {
            MessageBoxW(host->window, L"Unknown NoctEd command-line option.", L"NoctEd", MB_OK | MB_ICONERROR); break;
        }
        path = arguments[index]; utf8 = wide_to_utf8(path, &length); if (utf8 == NULL) continue;
        result = project ? host->callbacks->open_project(host->callbacks->userdata, utf8, length)
                         : host->callbacks->open_document(host->callbacks->userdata, utf8, length);
        free(utf8); if (result < 0) show_error(host, project ? L"The folder could not be opened." : L"The file could not be opened.");
    }
    LocalFree(arguments); nocted_sync(host);
}

static int create_menu(NoctedHost *host) {
    HMENU menu = CreateMenu(), file = CreatePopupMenu(), edit = CreatePopupMenu();
    if (menu == NULL || file == NULL || edit == NULL) return 0;
    if (!AppendMenuW(file, MF_STRING, ID_FILE_NEW, L"&New\tCtrl+N") ||
        !AppendMenuW(file, MF_STRING, ID_FILE_OPEN, L"&Open...\tCtrl+O") ||
        !AppendMenuW(file, MF_STRING, ID_FILE_OPEN_FOLDER, L"Open &Folder...") ||
        !AppendMenuW(file, MF_SEPARATOR, 0, NULL) ||
        !AppendMenuW(file, MF_STRING, ID_FILE_SAVE, L"&Save\tCtrl+S") ||
        !AppendMenuW(file, MF_STRING, ID_FILE_SAVE_AS, L"Save &As...\tCtrl+Shift+S") ||
        !AppendMenuW(file, MF_STRING, ID_FILE_CLOSE, L"&Close\tCtrl+W") ||
        !AppendMenuW(file, MF_SEPARATOR, 0, NULL) ||
        !AppendMenuW(file, MF_STRING, ID_FILE_EXIT, L"E&xit") ||
        !AppendMenuW(edit, MF_STRING, ID_EDIT_UNDO, L"&Undo\tCtrl+Z") ||
        !AppendMenuW(edit, MF_STRING, ID_EDIT_REDO, L"&Redo\tCtrl+Y") ||
        !AppendMenuW(edit, MF_SEPARATOR, 0, NULL) ||
        !AppendMenuW(edit, MF_STRING, ID_EDIT_CUT, L"Cu&t\tCtrl+X") ||
        !AppendMenuW(edit, MF_STRING, ID_EDIT_COPY, L"&Copy\tCtrl+C") ||
        !AppendMenuW(edit, MF_STRING, ID_EDIT_PASTE, L"&Paste\tCtrl+V") ||
        !AppendMenuW(edit, MF_STRING, ID_EDIT_SELECT_ALL, L"Select &All\tCtrl+A") ||
        !AppendMenuW(edit, MF_SEPARATOR, 0, NULL) ||
        !AppendMenuW(edit, MF_STRING, ID_EDIT_FIND, L"&Find...\tCtrl+F") ||
        !AppendMenuW(menu, MF_POPUP, (UINT_PTR)file, L"&File") ||
        !AppendMenuW(menu, MF_POPUP, (UINT_PTR)edit, L"&Edit") || !SetMenu(host->window, menu)) {
        DestroyMenu(menu); return 0;
    }
    return 1;
}

static HACCEL create_accelerators(void) {
    ACCEL entries[] = {{FVIRTKEY | FCONTROL, 'N', ID_FILE_NEW},
        {FVIRTKEY | FCONTROL, 'O', ID_FILE_OPEN}, {FVIRTKEY | FCONTROL, 'S', ID_FILE_SAVE},
        {FVIRTKEY | FCONTROL | FSHIFT, 'S', ID_FILE_SAVE_AS},
        {FVIRTKEY | FCONTROL, 'W', ID_FILE_CLOSE}, {FVIRTKEY | FCONTROL, 'F', ID_EDIT_FIND}};
    return CreateAcceleratorTableW(entries, (int)(sizeof(entries) / sizeof(entries[0])));
}

static int create_controls(NoctedHost *host) {
    host->tabs = CreateWindowExW(0, WC_TABCONTROLW, L"", WS_CHILD | WS_VISIBLE | TCS_FOCUSNEVER,
        0, 0, 1, 1, host->window, (HMENU)(INT_PTR)ID_CONTROL_TABS, host->instance, NULL);
    host->tree = CreateWindowExW(WS_EX_CLIENTEDGE, WC_TREEVIEWW, L"", WS_CHILD | WS_VISIBLE |
        TVS_HASBUTTONS | TVS_HASLINES | TVS_LINESATROOT | TVS_SHOWSELALWAYS,
        0, 0, 1, 1, host->window, (HMENU)(INT_PTR)ID_CONTROL_TREE, host->instance, NULL);
    host->editor = CreateWindowExW(WS_EX_CLIENTEDGE, MSFTEDIT_CLASS, L"", WS_CHILD | WS_VISIBLE |
        WS_TABSTOP | WS_VSCROLL | WS_HSCROLL | ES_MULTILINE | ES_WANTRETURN |
        ES_AUTOVSCROLL | ES_AUTOHSCROLL | ES_NOHIDESEL, 0, 0, 1, 1, host->window,
        (HMENU)(INT_PTR)ID_CONTROL_EDITOR, host->instance, NULL);
    host->status = CreateWindowExW(0, L"STATIC", L"", WS_CHILD | WS_VISIBLE | SS_LEFTNOWORDWRAP,
        0, 0, 1, 1, host->window, (HMENU)(INT_PTR)ID_CONTROL_STATUS, host->instance, NULL);
    host->find_edit = CreateWindowExW(WS_EX_CLIENTEDGE, L"EDIT", L"", WS_CHILD | WS_TABSTOP | ES_AUTOHSCROLL,
        0, 0, 1, 1, host->window, (HMENU)(INT_PTR)ID_CONTROL_FIND, host->instance, NULL);
    host->find_button = CreateWindowExW(0, L"BUTTON", L"Find next", WS_CHILD | WS_TABSTOP | BS_DEFPUSHBUTTON,
        0, 0, 1, 1, host->window, (HMENU)(INT_PTR)ID_CONTROL_FIND_NEXT, host->instance, NULL);
    if (host->tabs == NULL || host->tree == NULL || host->editor == NULL || host->status == NULL ||
        host->find_edit == NULL || host->find_button == NULL) return 0;
    SendMessageW(host->editor, EM_EXLIMITTEXT, 0, (LPARAM)(1024u * 1024u));
    SendMessageW(host->editor, EM_SETEVENTMASK, 0,
        SendMessageW(host->editor, EM_GETEVENTMASK, 0, 0) | ENM_CHANGE);
    return 1;
}

static int handle_command(NoctedHost *host, UINT command) {
    switch (command) {
        case ID_FILE_NEW: if (host->callbacks->new_document(host->callbacks->userdata) < 0)
            show_error(host, L"A document could not be created."); else nocted_sync(host); return 1;
        case ID_FILE_OPEN: (void)open_file(host); return 1;
        case ID_FILE_OPEN_FOLDER: (void)open_folder(host); return 1;
        case ID_FILE_SAVE: (void)nocted_save(host, 0); return 1;
        case ID_FILE_SAVE_AS: (void)nocted_save(host, 1); return 1;
        case ID_FILE_CLOSE: (void)close_current(host, 0); return 1;
        case ID_FILE_EXIT: SendMessageW(host->window, WM_CLOSE, 0, 0); return 1;
        case ID_EDIT_UNDO: SendMessageW(host->editor, EM_UNDO, 0, 0); return 1;
        case ID_EDIT_REDO: SendMessageW(host->editor, EM_REDO, 0, 0); return 1;
        case ID_EDIT_CUT: SendMessageW(host->editor, WM_CUT, 0, 0); return 1;
        case ID_EDIT_COPY: SendMessageW(host->editor, WM_COPY, 0, 0); return 1;
        case ID_EDIT_PASTE: SendMessageW(host->editor, WM_PASTE, 0, 0); return 1;
        case ID_EDIT_SELECT_ALL: SendMessageW(host->editor, EM_SETSEL, 0, -1); return 1;
        case ID_EDIT_FIND: show_find(host); return 1;
        case ID_CONTROL_FIND_NEXT: find_next(host); return 1;
        default: return 0;
    }
}

static LRESULT CALLBACK nocted_window_proc(HWND window, UINT message, WPARAM word, LPARAM long_value) {
    NoctedHost *host = (NoctedHost *)GetWindowLongPtrW(window, GWLP_USERDATA);
    if (message == WM_NCCREATE) { CREATESTRUCTW *create = (CREATESTRUCTW *)long_value;
        host = (NoctedHost *)create->lpCreateParams; host->window = window;
        SetWindowLongPtrW(window, GWLP_USERDATA, (LONG_PTR)host); }
    if (host == NULL) return DefWindowProcW(window, message, word, long_value);
    switch (message) {
        case WM_CREATE: if (!create_controls(host) || !create_menu(host)) return -1;
            host->dpi = window_dpi(window); update_font(host); return 0;
        case WM_SIZE: layout(host); return 0;
        case WM_GETMINMAXINFO: { MINMAXINFO *limits = (MINMAXINFO *)long_value;
            limits->ptMinTrackSize.x = MulDiv(720, (int)host->dpi, 96);
            limits->ptMinTrackSize.y = MulDiv(480, (int)host->dpi, 96); return 0; }
        case WM_DPICHANGED: { RECT *suggested = (RECT *)long_value; host->dpi = HIWORD(word);
            SetWindowPos(window, NULL, suggested->left, suggested->top,
                suggested->right - suggested->left, suggested->bottom - suggested->top,
                SWP_NOACTIVATE | SWP_NOZORDER); update_font(host); layout(host); return 0; }
        case WM_COMMAND:
            if (LOWORD(word) == ID_CONTROL_EDITOR && HIWORD(word) == EN_CHANGE) {
                editor_changed(host); return 0; }
            if (handle_command(host, LOWORD(word))) return 0; break;
        case WM_NOTIFY: { NMHDR *note = (NMHDR *)long_value;
            if (note->idFrom == ID_CONTROL_TABS && note->code == TCN_SELCHANGE) {
                int index = TabCtrl_GetCurSel(host->tabs);
                if (index >= 0 && host->callbacks->activate_document(host->callbacks->userdata, (size_t)index)) {
                    sync_editor(host); update_chrome(host); SetFocus(host->editor); }
                return 0; }
            if (note->idFrom == ID_CONTROL_TREE && note->code == NM_DBLCLK) {
                open_tree_selection(host); return 0; } break; }
        case WM_CLOSE: if (confirm_exit(host)) DestroyWindow(window); return 0;
        case WM_DESTROY: PostQuitMessage(0); return 0;
        default: break;
    }
    return DefWindowProcW(window, message, word, long_value);
}

int nocted_windows_host_run(HINSTANCE instance, int show_command,
                            const NoctedWindowsCallbacks *callbacks) {
    INITCOMMONCONTROLSEX controls;
    WNDCLASSEXW wc;
    NoctedHost host;
    HWND window;
    MSG message;
    int result;
    HRESULT com_result;
    if (callbacks == NULL ||
        callbacks->abi_version != NOCTED_WINDOWS_ABI_VERSION)
        return 1;
    com_result = CoInitializeEx(NULL, COINIT_APARTMENTTHREADED |
                                     COINIT_DISABLE_OLE1DDE);
    if (FAILED(com_result)) return 1;
    ZeroMemory(&host, sizeof(host));
    host.instance = instance;
    host.callbacks = callbacks;
    SetProcessDPIAware();
    controls.dwSize = sizeof(controls);
    controls.dwICC =
        ICC_TAB_CLASSES | ICC_TREEVIEW_CLASSES | ICC_STANDARD_CLASSES;
    if (!InitCommonControlsEx(&controls)) {
        CoUninitialize();
        return 1;
    }
    host.rich_edit = LoadLibraryW(L"Msftedit.dll");
    if (host.rich_edit == NULL) {
        CoUninitialize();
        return 1;
    }
    ZeroMemory(&wc, sizeof(wc));
    wc.cbSize = sizeof(wc);
    wc.style = CS_HREDRAW | CS_VREDRAW;
    wc.lpfnWndProc = nocted_window_proc;
    wc.hInstance = instance;
    wc.hCursor = LoadCursorW(NULL, IDC_IBEAM);
    wc.hIcon = LoadIconW(NULL, IDI_APPLICATION);
    wc.hbrBackground = (HBRUSH)(COLOR_WINDOW + 1);
    wc.lpszClassName = NOCTED_CLASS_NAME;
    if (!RegisterClassExW(&wc)) {
        FreeLibrary(host.rich_edit);
        CoUninitialize();
        return 1;
    }
    window = CreateWindowExW(
        0, NOCTED_CLASS_NAME, L"NoctEd",
        WS_OVERLAPPEDWINDOW | WS_CLIPCHILDREN, CW_USEDEFAULT, CW_USEDEFAULT,
        1180, 760, NULL, NULL, instance, &host);
    if (window == NULL) {
        UnregisterClassW(NOCTED_CLASS_NAME, instance);
        FreeLibrary(host.rich_edit);
        CoUninitialize();
        return 1;
    }
    host.accelerators = create_accelerators();
    nocted_sync(&host);
    parse_launch(&host);
    ShowWindow(window, show_command == 0 ? SW_SHOWNORMAL : show_command);
    UpdateWindow(window);
    while ((result = GetMessageW(&message, NULL, 0, 0)) > 0) {
        if (host.accelerators == NULL ||
            !TranslateAcceleratorW(window, host.accelerators, &message)) {
            TranslateMessage(&message);
            DispatchMessageW(&message);
        }
    }
    if (host.accelerators != NULL)
        DestroyAcceleratorTable(host.accelerators);
    if (host.font != NULL) DeleteObject(host.font);
    UnregisterClassW(NOCTED_CLASS_NAME, instance);
    FreeLibrary(host.rich_edit);
    CoUninitialize();
    return result < 0 ? 1 : (int)message.wParam;
}
