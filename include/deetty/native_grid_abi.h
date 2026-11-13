#ifndef DEETTY_NATIVE_GRID_ABI_H
#define DEETTY_NATIVE_GRID_ABI_H

#include <stddef.h>
#include <stdint.h>

#define DEETTY_NATIVE_GRID_ABI_VERSION 7u

typedef struct {
    uint32_t first;
    uint32_t end;
} DeettyGridDirtySpan;

typedef int (*DeettyGridPump)(void *);
typedef int (*DeettyGridWrite)(void *, const char *, size_t);
typedef int (*DeettyGridFrame)(void *, int, int, uint64_t *, size_t);
typedef int (*DeettyGridDirtyRows)(void *, uint8_t *, size_t);
typedef int (*DeettyGridDirtySpans)(void *, DeettyGridDirtySpan *, size_t);
typedef int (*DeettyGridPresentationReady)(void *);
typedef uint32_t (*DeettyGridColorRgb)(void *, uint32_t);
typedef uint32_t (*DeettyGridUiColorRgb)(void *, uint32_t);
typedef int (*DeettyGridCellText)(void *, int, int, char *, size_t);
typedef int (*DeettyGridCellHyperlink)(void *, int, int, char *, size_t);
typedef int (*DeettyGridPollExit)(void *);
typedef int (*DeettyGridResize)(void *, int, int, int, int);
typedef int (*DeettyGridMouse)(void *, int, int, int, int);
typedef int (*DeettyGridPaste)(void *, const char *, size_t);
typedef int (*DeettyGridCopy)(void *, char *, size_t, int, int, int, int);
typedef int (*DeettyGridScroll)(void *, int);
typedef uint32_t (*DeettyGridCursor)(void *);
typedef int (*DeettyGridTitle)(void *, char *, size_t);
typedef int (*DeettyGridCursorMode)(void *);
typedef int (*DeettyGridMouseMode)(void *);
typedef int (*DeettyGridFocus)(void *, int);
typedef void (*DeettyGridEvent)(void *, uint64_t, int, int, uint64_t);
typedef int (*DeettyGridTextAction)(void *, int, const char *, size_t,
                                    const char *, size_t, int);
typedef void *(*DeettyGridCreateSession)(void *, uint64_t, int, int, int,
                                         uint64_t *);
typedef int (*DeettyGridPipelineAdvance)(void *, size_t, uint64_t *,
                                         uint64_t *, size_t *);

typedef struct {
    uint32_t abi_version;
    uint32_t struct_size;
    void *userdata;
    DeettyGridPump pump;
    DeettyGridWrite write;
    DeettyGridFrame frame;
    DeettyGridDirtyRows dirty_rows;
    DeettyGridDirtySpans dirty_spans;
    DeettyGridPresentationReady presentation_ready;
    DeettyGridColorRgb color_rgb;
    DeettyGridUiColorRgb ui_color_rgb;
    DeettyGridCellText cell_text;
    DeettyGridCellHyperlink cell_hyperlink;
    DeettyGridPollExit poll_exit;
    DeettyGridResize resize;
    DeettyGridMouse mouse;
    DeettyGridPaste paste;
    DeettyGridCopy copy;
    DeettyGridScroll scroll;
    DeettyGridCursor cursor;
    DeettyGridTitle title;
    DeettyGridCursorMode cursor_mode;
    DeettyGridMouseMode mouse_mode;
    DeettyGridFocus focus;
    DeettyGridEvent event;
    void *event_data;
    DeettyGridTextAction text_action;
    void *text_action_data;
} DeettyGridCallbacks;

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
} DeettyGridLaunchOptions;

int deetty_native_grid_host_run_v2(const DeettyGridCallbacks *callbacks,
                                   const DeettyGridLaunchOptions *options);

int deetty_native_grid_pipeline_qualification(
    const DeettyGridCallbacks *callbacks, int columns, int rows,
    DeettyGridPipelineAdvance advance, void *advance_data,
    const char *artifact_path, const char *mode);

#endif
