#ifndef NOCTTY_WINDOWS_DPAPI_H
#define NOCTTY_WINDOWS_DPAPI_H

#include <stddef.h>
#include <stdint.h>

int noctty_windows_identity_load(uint8_t *secret, size_t secret_length);
int noctty_windows_identity_save(const uint8_t *secret, size_t secret_length);
int noctty_windows_random(uint8_t *bytes, size_t length);
int noctty_windows_pairs_load(uint8_t *bytes, size_t capacity, size_t *length);
int noctty_windows_pairs_save(const uint8_t *bytes, size_t length);

#endif
