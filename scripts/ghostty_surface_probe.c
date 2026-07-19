#include "ghostty.h"
#include <stdint.h>
#include <stdio.h>

int main(int argc, char **argv) {
    if (ghostty_init((uintptr_t)argc, argv) != 0) {
        puts("ghostty_surface_probe init=false");
        return 0;
    }

    ghostty_config_t config = ghostty_config_new();
    if (config == NULL) {
        puts("ghostty_surface_probe config=false");
        return 0;
    }
    ghostty_config_finalize(config);

    ghostty_runtime_config_s runtime = {0};
    runtime.supports_selection_clipboard = true;
    ghostty_app_t app = ghostty_app_new(&runtime, config);
    if (app == NULL) {
        ghostty_config_free(config);
        puts("ghostty_surface_probe app=false");
        return 0;
    }

    ghostty_surface_config_s surface_config = ghostty_surface_config_new();
    surface_config.platform_tag = GHOSTTY_PLATFORM_INVALID;
    surface_config.context = GHOSTTY_SURFACE_CONTEXT_WINDOW;
    ghostty_surface_t surface = ghostty_surface_new(app, &surface_config);
    printf("ghostty_surface_probe init=true config=true app=true surface_created=%s platform=invalid\n",
           surface == NULL ? "false" : "true");

    if (surface != NULL) ghostty_surface_free(surface);
    ghostty_app_free(app);
    ghostty_config_free(config);
    return 0;
}
