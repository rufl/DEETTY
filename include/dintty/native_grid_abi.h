#ifndef DINTTY_NATIVE_GRID_ABI_H
#define DINTTY_NATIVE_GRID_ABI_H

#include <stddef.h>
#include <stdint.h>

#define DINTTY_NATIVE_GRID_ABI_VERSION 7u

typedef struct {
    uint32_t first;
    uint32_t end;
} DinttyGridDirtySpan;

typedef int (*DinttyGridPump)(void *);
typedef int (*DinttyGridWrite)(void *, const char *, size_t);
typedef int (*DinttyGridFrame)(void *, int, int, uint64_t *, size_t);
typedef int (*DinttyGridDirtyRows)(void *, uint8_t *, size_t);
typedef int (*DinttyGridDirtySpans)(void *, DinttyGridDirtySpan *, size_t);
typedef int (*DinttyGridPresentationReady)(void *);
typedef uint32_t (*DinttyGridColorRgb)(void *, uint32_t);
typedef uint32_t (*DinttyGridUiColorRgb)(void *, uint32_t);
typedef int (*DinttyGridCellText)(void *, int, int, char *, size_t);
typedef int (*DinttyGridCellHyperlink)(void *, int, int, char *, size_t);
typedef int (*DinttyGridPollExit)(void *);
typedef int (*DinttyGridResize)(void *, int, int, int, int);
typedef int (*DinttyGridMouse)(void *, int, int, int, int);
typedef int (*DinttyGridPaste)(void *, const char *, size_t);
typedef int (*DinttyGridCopy)(void *, char *, size_t, int, int, int, int);
typedef int (*DinttyGridScroll)(void *, int);
typedef uint32_t (*DinttyGridCursor)(void *);
typedef int (*DinttyGridTitle)(void *, char *, size_t);
typedef int (*DinttyGridCursorMode)(void *);
typedef int (*DinttyGridMouseMode)(void *);
typedef int (*DinttyGridFocus)(void *, int);
typedef void (*DinttyGridEvent)(void *, uint64_t, int, int, uint64_t);
typedef int (*DinttyGridTextAction)(void *, int, const char *, size_t,
                                    const char *, size_t, int);
typedef void *(*DinttyGridCreateSession)(void *, uint64_t, int, int, int,
                                         uint64_t *);
typedef int (*DinttyGridPipelineAdvance)(void *, size_t, uint64_t *,
                                         uint64_t *, size_t *);

typedef struct {
    uint32_t abi_version;
    uint32_t struct_size;
    void *userdata;
    DinttyGridPump pump;
    DinttyGridWrite write;
    DinttyGridFrame frame;
    DinttyGridDirtyRows dirty_rows;
    DinttyGridDirtySpans dirty_spans;
    DinttyGridPresentationReady presentation_ready;
    DinttyGridColorRgb color_rgb;
    DinttyGridUiColorRgb ui_color_rgb;
    DinttyGridCellText cell_text;
    DinttyGridCellHyperlink cell_hyperlink;
    DinttyGridPollExit poll_exit;
    DinttyGridResize resize;
    DinttyGridMouse mouse;
    DinttyGridPaste paste;
    DinttyGridCopy copy;
    DinttyGridScroll scroll;
    DinttyGridCursor cursor;
    DinttyGridTitle title;
    DinttyGridCursorMode cursor_mode;
    DinttyGridMouseMode mouse_mode;
    DinttyGridFocus focus;
    DinttyGridEvent event;
    void *event_data;
    DinttyGridTextAction text_action;
    void *text_action_data;
} DinttyGridCallbacks;

typedef struct {
    uint32_t abi_version;
    uint32_t struct_size;
    uint64_t pane_id;
    int columns;
    int rows;
    int mode;
    int shortcut_key;
    int enable_shortcut;
    int workspace_smoke;
    void *secondary_userdata;
    uint64_t secondary_pane_id;
    int secondary_initially_active;
    int enable_notifications;
    int use_layer_shell;
    int claim_control;
    int show_on_control_conflict;
    uint32_t recovery_notice_flags;
    const char *startup_activation_token;
    size_t startup_activation_token_length;
} DinttyGridLaunchOptions;

int dintty_native_grid_host_run_v2(const DinttyGridCallbacks *callbacks,
                                   const DinttyGridLaunchOptions *options);

int dintty_native_grid_pipeline_qualification(
    const DinttyGridCallbacks *callbacks, int columns, int rows,
    DinttyGridPipelineAdvance advance, void *advance_data,
    const char *artifact_path, const char *mode);

#endif
