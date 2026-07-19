#ifndef NOCTTY_NATIVE_GRID_ABI_H
#define NOCTTY_NATIVE_GRID_ABI_H

#include <stddef.h>
#include <stdint.h>

#define NOCTTY_NATIVE_GRID_ABI_VERSION 2u

typedef struct {
    uint32_t first;
    uint32_t end;
} NocttyGridDirtySpan;

typedef int (*NocttyGridPump)(void *);
typedef int (*NocttyGridWrite)(void *, const char *, size_t);
typedef uint64_t (*NocttyGridCell)(void *, int, int);
typedef int (*NocttyGridRow)(void *, int, uint64_t *, size_t);
typedef int (*NocttyGridDirtyRows)(void *, uint8_t *, size_t);
typedef int (*NocttyGridDirtySpans)(void *, NocttyGridDirtySpan *, size_t);
typedef int (*NocttyGridPresentationReady)(void *);
typedef uint32_t (*NocttyGridColorRgb)(void *, uint32_t);
typedef int (*NocttyGridCellText)(void *, int, int, char *, size_t);
typedef int (*NocttyGridCellHyperlink)(void *, int, int, char *, size_t);
typedef int (*NocttyGridPollExit)(void *);
typedef int (*NocttyGridResize)(void *, int, int, int, int);
typedef int (*NocttyGridMouse)(void *, int, int, int, int);
typedef int (*NocttyGridPaste)(void *, const char *, size_t);
typedef int (*NocttyGridCopy)(void *, char *, size_t, int, int, int, int);
typedef int (*NocttyGridScroll)(void *, int);
typedef uint32_t (*NocttyGridCursor)(void *);
typedef int (*NocttyGridTitle)(void *, char *, size_t);
typedef int (*NocttyGridCursorMode)(void *);
typedef int (*NocttyGridMouseMode)(void *);
typedef int (*NocttyGridFocus)(void *, int);
typedef void (*NocttyGridEvent)(void *, uint64_t, int, int, uint64_t);
typedef int (*NocttyGridTextAction)(void *, int, const char *, size_t,
                                    const char *, size_t, int);
typedef void *(*NocttyGridCreateSession)(void *, uint64_t, int, int, int,
                                         uint64_t *);
typedef int (*NocttyGridPipelineAdvance)(void *, size_t, uint64_t *,
                                         uint64_t *, size_t *);

typedef struct {
    uint32_t abi_version;
    uint32_t struct_size;
    void *userdata;
    NocttyGridPump pump;
    NocttyGridWrite write;
    NocttyGridCell cell;
    NocttyGridRow row;
    NocttyGridDirtyRows dirty_rows;
    NocttyGridDirtySpans dirty_spans;
    NocttyGridPresentationReady presentation_ready;
    NocttyGridColorRgb color_rgb;
    NocttyGridCellText cell_text;
    NocttyGridCellHyperlink cell_hyperlink;
    NocttyGridPollExit poll_exit;
    NocttyGridResize resize;
    NocttyGridMouse mouse;
    NocttyGridPaste paste;
    NocttyGridCopy copy;
    NocttyGridScroll scroll;
    NocttyGridCursor cursor;
    NocttyGridTitle title;
    NocttyGridCursorMode cursor_mode;
    NocttyGridMouseMode mouse_mode;
    NocttyGridFocus focus;
    NocttyGridEvent event;
    void *event_data;
    NocttyGridTextAction text_action;
    void *text_action_data;
} NocttyGridCallbacks;

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
} NocttyGridLaunchOptions;

int noctty_native_grid_host_run_v2(const NocttyGridCallbacks *callbacks,
                                   const NocttyGridLaunchOptions *options);

int noctty_native_grid_pipeline_qualification(
    const NocttyGridCallbacks *callbacks, int columns, int rows,
    NocttyGridPipelineAdvance advance, void *advance_data,
    const char *artifact_path, const char *mode);

#endif
