#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdbool.h>
#include <stddef.h>

typedef bool (*ghostty_paste_is_safe_fn)(const char *, size_t);

static void *noctty_vt_handle(void) {
    static void *handle;
    static bool attempted;
    if (!attempted) {
        attempted = true;
        handle = dlopen("libghostty-vt.so", RTLD_NOW | RTLD_LOCAL);
        if (!handle) handle = dlopen("libghostty-vt.so.0", RTLD_NOW | RTLD_LOCAL);
    }
    return handle;
}

bool noctty_vt_public_available(void) {
    void *handle = noctty_vt_handle();
    return handle != NULL && dlsym(handle, "ghostty_paste_is_safe") != NULL;
}

bool noctty_vt_paste_is_safe(const char *data, size_t length) {
    void *handle = noctty_vt_handle();
    if (!handle) return false;
    ghostty_paste_is_safe_fn function = (ghostty_paste_is_safe_fn)dlsym(handle, "ghostty_paste_is_safe");
    return function != NULL && function(data, length);
}
