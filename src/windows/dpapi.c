#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <bcrypt.h>
#include <dpapi.h>
#include <string.h>
#include <wchar.h>

#include "noctty_dpapi.h"

#define NOCTTY_IDENTITY_MAX_BLOB 4096u

static int noctty_identity_path(WCHAR *path, size_t capacity) {
    static const WCHAR suffix[] = L"\\NOCTTY";
    static const WCHAR filename[] = L"\\sharing-identity.dpapi";
    DWORD count;
    size_t length;
    if (path == NULL || capacity < 64u) return 0;
    count = GetEnvironmentVariableW(L"LOCALAPPDATA", path, (DWORD)capacity);
    if (count == 0 || count >= capacity) return 0;
    length = (size_t)count;
    if (length + (sizeof(suffix) / sizeof(suffix[0])) >= capacity) return 0;
    memcpy(path + length, suffix, sizeof(suffix));
    if (!CreateDirectoryW(path, NULL) && GetLastError() != ERROR_ALREADY_EXISTS)
        return 0;
    length += (sizeof(suffix) / sizeof(suffix[0])) - 1u;
    if (length + (sizeof(filename) / sizeof(filename[0])) >= capacity) return 0;
    memcpy(path + length, filename, sizeof(filename));
    return 1;
}

int noctty_windows_identity_load(uint8_t *secret, size_t secret_length) {
    WCHAR path[MAX_PATH * 2];
    HANDLE file;
    DWORD size;
    DWORD read_count = 0;
    uint8_t blob[NOCTTY_IDENTITY_MAX_BLOB];
    DATA_BLOB protected_blob;
    DATA_BLOB plaintext = {0};
    int result = -1;
    if (secret == NULL || secret_length == 0 ||
        !noctty_identity_path(path, sizeof(path) / sizeof(path[0])))
        return -1;
    file = CreateFileW(path, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING,
                       FILE_ATTRIBUTE_NORMAL, NULL);
    if (file == INVALID_HANDLE_VALUE)
        return GetLastError() == ERROR_FILE_NOT_FOUND ? 0 : -1;
    size = GetFileSize(file, NULL);
    if (size == INVALID_FILE_SIZE || size == 0 || size > sizeof(blob)) goto done;
    if (!ReadFile(file, blob, size, &read_count, NULL) || read_count != size)
        goto done;
    protected_blob.pbData = blob;
    protected_blob.cbData = size;
    if (!CryptUnprotectData(&protected_blob, NULL, NULL, NULL, NULL,
                            CRYPTPROTECT_UI_FORBIDDEN, &plaintext))
        goto done;
    if (plaintext.cbData != secret_length) goto done;
    memcpy(secret, plaintext.pbData, secret_length);
    result = 1;
done:
    if (plaintext.pbData != NULL) {
        SecureZeroMemory(plaintext.pbData, plaintext.cbData);
        LocalFree(plaintext.pbData);
    }
    SecureZeroMemory(blob, sizeof(blob));
    CloseHandle(file);
    return result;
}

int noctty_windows_identity_save(const uint8_t *secret, size_t secret_length) {
    WCHAR path[MAX_PATH * 2];
    WCHAR temporary[MAX_PATH * 2];
    HANDLE file = INVALID_HANDLE_VALUE;
    DATA_BLOB plaintext;
    DATA_BLOB protected_blob = {0};
    DWORD written = 0;
    int result = -1;
    size_t path_length;
    if (secret == NULL || secret_length == 0 || secret_length > MAXDWORD ||
        !noctty_identity_path(path, sizeof(path) / sizeof(path[0])))
        return -1;
    path_length = wcslen(path);
    if (path_length + 5u >= sizeof(temporary) / sizeof(temporary[0])) return -1;
    memcpy(temporary, path, path_length * sizeof(WCHAR));
    memcpy(temporary + path_length, L".tmp", 5u * sizeof(WCHAR));
    plaintext.pbData = (BYTE *)secret;
    plaintext.cbData = (DWORD)secret_length;
    if (!CryptProtectData(&plaintext, L"NOCTTY session sharing identity", NULL,
                          NULL, NULL, CRYPTPROTECT_UI_FORBIDDEN,
                          &protected_blob))
        return -1;
    file = CreateFileW(temporary, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS,
                       FILE_ATTRIBUTE_HIDDEN | FILE_ATTRIBUTE_TEMPORARY, NULL);
    if (file == INVALID_HANDLE_VALUE) goto done;
    if (!WriteFile(file, protected_blob.pbData, protected_blob.cbData, &written,
                   NULL) || written != protected_blob.cbData ||
        !FlushFileBuffers(file))
        goto done;
    CloseHandle(file);
    file = INVALID_HANDLE_VALUE;
    if (!MoveFileExW(temporary, path,
                     MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH))
        goto done;
    result = 0;
done:
    if (file != INVALID_HANDLE_VALUE) CloseHandle(file);
    if (result != 0) DeleteFileW(temporary);
    if (protected_blob.pbData != NULL) {
        SecureZeroMemory(protected_blob.pbData, protected_blob.cbData);
        LocalFree(protected_blob.pbData);
    }
    return result;
}

int noctty_windows_random(uint8_t *bytes, size_t length) {
    if (bytes == NULL || length == 0 || length > ULONG_MAX) return -1;
    return BCryptGenRandom(NULL, bytes, (ULONG)length,
                           BCRYPT_USE_SYSTEM_PREFERRED_RNG) == 0 ? 0 : -1;
}

static int noctty_pairs_path(WCHAR *path, size_t capacity) {
    static const WCHAR suffix[] = L"\\NOCTTY";
    static const WCHAR filename[] = L"\\sharing-peers.dpapi";
    DWORD count;
    size_t length;
    if (path == NULL || capacity < 64u) return 0;
    count = GetEnvironmentVariableW(L"LOCALAPPDATA", path, (DWORD)capacity);
    if (count == 0 || count >= capacity) return 0;
    length = (size_t)count;
    if (length + (sizeof(suffix) / sizeof(suffix[0])) >= capacity) return 0;
    memcpy(path + length, suffix, sizeof(suffix));
    if (!CreateDirectoryW(path, NULL) && GetLastError() != ERROR_ALREADY_EXISTS)
        return 0;
    length += (sizeof(suffix) / sizeof(suffix[0])) - 1u;
    if (length + (sizeof(filename) / sizeof(filename[0])) >= capacity) return 0;
    memcpy(path + length, filename, sizeof(filename));
    return 1;
}

int noctty_windows_pairs_load(uint8_t *bytes, size_t capacity, size_t *length) {
    WCHAR path[MAX_PATH * 2];
    HANDLE file;
    DWORD size;
    DWORD read_count = 0;
    uint8_t blob[65536];
    DATA_BLOB protected_blob;
    DATA_BLOB plaintext = {0};
    int result = -1;
    if (bytes == NULL || capacity == 0 || length == NULL ||
        !noctty_pairs_path(path, sizeof(path) / sizeof(path[0])))
        return -1;
    *length = 0;
    file = CreateFileW(path, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING,
                       FILE_ATTRIBUTE_NORMAL, NULL);
    if (file == INVALID_HANDLE_VALUE)
        return GetLastError() == ERROR_FILE_NOT_FOUND ? 0 : -1;
    size = GetFileSize(file, NULL);
    if (size == INVALID_FILE_SIZE || size == 0 || size > sizeof(blob)) goto done;
    if (!ReadFile(file, blob, size, &read_count, NULL) || read_count != size)
        goto done;
    protected_blob.pbData = blob;
    protected_blob.cbData = size;
    if (!CryptUnprotectData(&protected_blob, NULL, NULL, NULL, NULL,
                            CRYPTPROTECT_UI_FORBIDDEN, &plaintext))
        goto done;
    if (plaintext.cbData > capacity) goto done;
    memcpy(bytes, plaintext.pbData, plaintext.cbData);
    *length = plaintext.cbData;
    result = 1;
done:
    if (plaintext.pbData != NULL) {
        SecureZeroMemory(plaintext.pbData, plaintext.cbData);
        LocalFree(plaintext.pbData);
    }
    SecureZeroMemory(blob, sizeof(blob));
    CloseHandle(file);
    return result;
}

int noctty_windows_pairs_save(const uint8_t *bytes, size_t length) {
    WCHAR path[MAX_PATH * 2];
    WCHAR temporary[MAX_PATH * 2];
    HANDLE file = INVALID_HANDLE_VALUE;
    DATA_BLOB plaintext;
    DATA_BLOB protected_blob = {0};
    DWORD written = 0;
    int result = -1;
    size_t path_length;
    if (bytes == NULL || length == 0 || length > MAXDWORD ||
        !noctty_pairs_path(path, sizeof(path) / sizeof(path[0])))
        return -1;
    path_length = wcslen(path);
    if (path_length + 5u >= sizeof(temporary) / sizeof(temporary[0])) return -1;
    memcpy(temporary, path, path_length * sizeof(WCHAR));
    memcpy(temporary + path_length, L".tmp", 5u * sizeof(WCHAR));
    plaintext.pbData = (BYTE *)bytes;
    plaintext.cbData = (DWORD)length;
    if (!CryptProtectData(&plaintext, L"NOCTTY paired devices", NULL, NULL,
                          NULL, CRYPTPROTECT_UI_FORBIDDEN, &protected_blob))
        return -1;
    file = CreateFileW(temporary, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS,
                       FILE_ATTRIBUTE_HIDDEN | FILE_ATTRIBUTE_TEMPORARY, NULL);
    if (file == INVALID_HANDLE_VALUE) goto save_done;
    if (!WriteFile(file, protected_blob.pbData, protected_blob.cbData, &written,
                   NULL) || written != protected_blob.cbData ||
        !FlushFileBuffers(file))
        goto save_done;
    CloseHandle(file);
    file = INVALID_HANDLE_VALUE;
    if (!MoveFileExW(temporary, path,
                     MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH))
        goto save_done;
    result = 0;
save_done:
    if (file != INVALID_HANDLE_VALUE) CloseHandle(file);
    if (result != 0) DeleteFileW(temporary);
    if (protected_blob.pbData != NULL) {
        SecureZeroMemory(protected_blob.pbData, protected_blob.cbData);
        LocalFree(protected_blob.pbData);
    }
    return result;
}

static int noctty_state_path(WCHAR *path, size_t capacity) {
    static const WCHAR suffix[] = L"\\NOCTTY";
    static const WCHAR filename[] = L"\\windows-state-v1.bin";
    DWORD count;
    size_t length;
    if (path == NULL || capacity < 64u) return 0;
    count = GetEnvironmentVariableW(L"LOCALAPPDATA", path, (DWORD)capacity);
    if (count == 0 || count >= capacity) return 0;
    length = (size_t)count;
    if (length + (sizeof(suffix) / sizeof(suffix[0])) >= capacity) return 0;
    memcpy(path + length, suffix, sizeof(suffix));
    if (!CreateDirectoryW(path, NULL) && GetLastError() != ERROR_ALREADY_EXISTS)
        return 0;
    length += (sizeof(suffix) / sizeof(suffix[0])) - 1u;
    if (length + (sizeof(filename) / sizeof(filename[0])) >= capacity) return 0;
    memcpy(path + length, filename, sizeof(filename));
    return 1;
}

int noctty_windows_state_load(uint8_t *bytes, size_t capacity, size_t *length) {
    WCHAR path[MAX_PATH * 2];
    HANDLE file;
    DWORD size;
    DWORD read_count = 0;
    int result = -1;
    if (bytes == NULL || capacity == 0 || length == NULL ||
        !noctty_state_path(path, sizeof(path) / sizeof(path[0])))
        return -1;
    *length = 0;
    file = CreateFileW(path, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING,
                       FILE_ATTRIBUTE_NORMAL, NULL);
    if (file == INVALID_HANDLE_VALUE)
        return GetLastError() == ERROR_FILE_NOT_FOUND ? 0 : -1;
    size = GetFileSize(file, NULL);
    if (size == INVALID_FILE_SIZE || size == 0 || size > capacity) goto done;
    if (!ReadFile(file, bytes, size, &read_count, NULL) || read_count != size)
        goto done;
    *length = size;
    result = 1;
done:
    CloseHandle(file);
    return result;
}

int noctty_windows_state_save(const uint8_t *bytes, size_t length) {
    WCHAR path[MAX_PATH * 2];
    WCHAR temporary[MAX_PATH * 2];
    HANDLE file = INVALID_HANDLE_VALUE;
    DWORD written = 0;
    int result = -1;
    size_t path_length;
    if (bytes == NULL || length == 0 || length > MAXDWORD ||
        !noctty_state_path(path, sizeof(path) / sizeof(path[0])))
        return -1;
    path_length = wcslen(path);
    if (path_length + 5u >= sizeof(temporary) / sizeof(temporary[0])) return -1;
    memcpy(temporary, path, path_length * sizeof(WCHAR));
    memcpy(temporary + path_length, L".tmp", 5u * sizeof(WCHAR));
    file = CreateFileW(temporary, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS,
                       FILE_ATTRIBUTE_HIDDEN | FILE_ATTRIBUTE_TEMPORARY, NULL);
    if (file == INVALID_HANDLE_VALUE) goto save_done;
    if (!WriteFile(file, bytes, (DWORD)length, &written, NULL) ||
        written != (DWORD)length || !FlushFileBuffers(file))
        goto save_done;
    CloseHandle(file);
    file = INVALID_HANDLE_VALUE;
    if (!MoveFileExW(temporary, path,
                     MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH))
        goto save_done;
    result = 0;
save_done:
    if (file != INVALID_HANDLE_VALUE) CloseHandle(file);
    if (result != 0) DeleteFileW(temporary);
    return result;
}
