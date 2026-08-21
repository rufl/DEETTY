#ifndef NOCTED_WINDOWS_HOST_H
#define NOCTED_WINDOWS_HOST_H

#include <stddef.h>
#include <stdint.h>
#include <windows.h>

#define NOCTED_WINDOWS_ABI_VERSION 3u
#define NOCTED_CLOSE_OK 1
#define NOCTED_CLOSE_DIRTY 2
#define NOCTED_SAVE_NEEDS_PATH 2

typedef struct {
    uint32_t abi_version;
    void *userdata;
    int (*new_document)(void *userdata);
    int (*open_document)(void *userdata, const uint8_t *path, size_t length);
    int (*open_project)(void *userdata, const uint8_t *path, size_t length);
    int (*open_project_entry)(void *userdata, size_t index);
    int (*save_document)(void *userdata, const uint8_t *path, size_t length);
    int (*close_document)(void *userdata, size_t index, int discard);
    int (*discard_document)(void *userdata, size_t index);
    int (*activate_document)(void *userdata, size_t index);
    int (*replace_contents)(void *userdata, const uint8_t *contents,
                            size_t length);
    size_t (*tab_count)(void *userdata);
    size_t (*active_tab)(void *userdata);
    size_t (*tab_title)(void *userdata, size_t index, uint8_t *output,
                        size_t capacity, int *dirty, int *read_only);
    size_t (*active_content_length)(void *userdata);
    size_t (*active_content)(void *userdata, uint8_t *output, size_t capacity);
    size_t (*active_path)(void *userdata, uint8_t *output, size_t capacity);
    size_t (*project_name)(void *userdata, uint8_t *output, size_t capacity);
    size_t (*project_entry_count)(void *userdata);
    size_t (*project_entry)(void *userdata, size_t index, uint8_t *output,
                            size_t capacity, size_t *parent, int *directory);
    size_t (*last_error)(void *userdata, uint8_t *output, size_t capacity);
    int (*persist_session)(void *userdata);
    int (*editor_font_size)(void *userdata);
    int (*set_editor_font_size)(void *userdata, int value);
} NoctedWindowsCallbacks;

int nocted_windows_host_run(HINSTANCE instance, int show_command,
                            const NoctedWindowsCallbacks *callbacks);
int nocted_windows_session_path(uint8_t *output, size_t capacity);
int nocted_windows_has_argument(const wchar_t *argument);
void nocted_windows_show_message(const wchar_t *message, int error_message);

#endif
