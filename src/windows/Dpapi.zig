//! Owns Windows-only durable state and DPAPI protection.
//!
//! Identity and peer material is encrypted for the current Windows user. Every
//! write uses a same-directory temporary file followed by a durable replacement.

const std = @import("std");

const c = @cImport({
    @cDefine("WIN32_LEAN_AND_MEAN", "1");
    @cDefine("_FORTIFY_SOURCE", "0");
    @cInclude("windows.h");
    @cInclude("bcrypt.h");
    @cInclude("dpapi.h");
});

const path_capacity: usize = c.MAX_PATH * 2;
const identity_blob_bytes_max: usize = 4_096;
const peers_blob_bytes_max: usize = 65_536;
const local_app_data = std.unicode.utf8ToUtf16LeStringLiteral("LOCALAPPDATA");
const directory = std.unicode.utf8ToUtf16LeStringLiteral("\\NOCTTY");
const identity_file = std.unicode.utf8ToUtf16LeStringLiteral("\\sharing-identity.dpapi");
const peers_file = std.unicode.utf8ToUtf16LeStringLiteral("\\sharing-peers.dpapi");
const state_file = std.unicode.utf8ToUtf16LeStringLiteral("\\windows-state-v1.bin");
const temporary_suffix = std.unicode.utf8ToUtf16LeStringLiteral(".tmp");
const identity_description = std.unicode.utf8ToUtf16LeStringLiteral(
    "NOCTTY session sharing identity",
);
const peers_description = std.unicode.utf8ToUtf16LeStringLiteral("NOCTTY paired devices");

pub const PeerStoreVersion = struct {
    volume: u32,
    file_index: u64,
    created: u64,
    written: u64,
    size: u64,
};

fn fileVersion(file: c.HANDLE) !PeerStoreVersion {
    var info: c.BY_HANDLE_FILE_INFORMATION = undefined;
    if (c.GetFileInformationByHandle(file, &info) == 0)
        return error.WindowsDataStatFailed;
    return .{
        .volume = info.dwVolumeSerialNumber,
        .file_index = (@as(u64, info.nFileIndexHigh) << 32) | info.nFileIndexLow,
        .created = (@as(u64, info.ftCreationTime.dwHighDateTime) << 32) | info.ftCreationTime.dwLowDateTime,
        .written = (@as(u64, info.ftLastWriteTime.dwHighDateTime) << 32) | info.ftLastWriteTime.dwLowDateTime,
        .size = (@as(u64, info.nFileSizeHigh) << 32) | info.nFileSizeLow,
    };
}

pub fn peersVersion() !PeerStoreVersion {
    var path: [path_capacity:0]u16 = undefined;
    if (!dataPath(&path, peers_file)) return error.WindowsDataPathUnavailable;
    const file = c.CreateFileW(
        &path,
        c.FILE_READ_ATTRIBUTES,
        c.FILE_SHARE_READ | c.FILE_SHARE_WRITE | c.FILE_SHARE_DELETE,
        null,
        c.OPEN_EXISTING,
        c.FILE_ATTRIBUTE_NORMAL,
        null,
    );
    if (file == c.INVALID_HANDLE_VALUE) return error.WindowsDataOpenFailed;
    defer closeHandle(file);
    return fileVersion(file);
}

fn dataPath(path: *[path_capacity:0]u16, filename: []const u16) bool {
    const count = c.GetEnvironmentVariableW(local_app_data, path, @intCast(path.len));
    if (count == 0 or count >= path.len) return false;

    var length: usize = count;
    if (length + directory.len + 1 >= path.len) return false;
    @memcpy(path[length..][0..directory.len], directory);
    length += directory.len;
    path[length] = 0;
    if (c.CreateDirectoryW(path, null) == 0 and c.GetLastError() != c.ERROR_ALREADY_EXISTS)
        return false;

    if (length + filename.len + 1 >= path.len) return false;
    @memcpy(path[length..][0..filename.len], filename);
    length += filename.len;
    path[length] = 0;
    return true;
}

fn temporaryPath(path: *const [path_capacity:0]u16) ?[path_capacity:0]u16 {
    const length = std.mem.indexOfScalar(u16, path, 0) orelse return null;
    if (length + temporary_suffix.len + 1 >= path.len) return null;
    var temporary: [path_capacity:0]u16 = [_:0]u16{0} ** path_capacity;
    @memcpy(temporary[0..length], path[0..length]);
    @memcpy(temporary[length..][0..temporary_suffix.len], temporary_suffix);
    temporary[length + temporary_suffix.len] = 0;
    return temporary;
}

fn closeHandle(handle: c.HANDLE) void {
    if (handle != c.INVALID_HANDLE_VALUE) _ = c.CloseHandle(handle);
}

fn wipeAndFreeBlob(blob: *c.DATA_BLOB) void {
    if (blob.pbData == null) return;
    const bytes: [*]u8 = @ptrCast(blob.pbData);
    std.crypto.secureZero(u8, bytes[0..blob.cbData]);
    _ = c.LocalFree(blob.pbData);
    blob.* = std.mem.zeroes(c.DATA_BLOB);
}

fn loadProtected(
    filename: []const u16,
    output: []u8,
    blob_size_max: usize,
    version: ?*PeerStoreVersion,
) !?usize {
    if (output.len == 0) return error.InvalidProtectedOutput;
    var path: [path_capacity:0]u16 = undefined;
    if (!dataPath(&path, filename)) return error.WindowsDataPathUnavailable;

    const file = c.CreateFileW(
        &path,
        c.GENERIC_READ,
        c.FILE_SHARE_READ,
        null,
        c.OPEN_EXISTING,
        c.FILE_ATTRIBUTE_NORMAL,
        null,
    );
    if (file == c.INVALID_HANDLE_VALUE) {
        if (c.GetLastError() == c.ERROR_FILE_NOT_FOUND) return null;
        return error.WindowsDataOpenFailed;
    }
    defer closeHandle(file);
    if (version) |output_version| output_version.* = try fileVersion(file);

    const size: usize = c.GetFileSize(file, null);
    if (size == c.INVALID_FILE_SIZE or size == 0 or size > blob_size_max)
        return error.InvalidProtectedBlob;
    var blob: [peers_blob_bytes_max]u8 = undefined;
    defer std.crypto.secureZero(u8, &blob);
    var read_count: c.DWORD = 0;
    if (c.ReadFile(file, &blob, @intCast(size), &read_count, null) == 0 or
        read_count != size)
    {
        return error.WindowsDataReadFailed;
    }

    var protected_blob = c.DATA_BLOB{
        .cbData = @intCast(size),
        .pbData = &blob,
    };
    var plaintext: c.DATA_BLOB = std.mem.zeroes(c.DATA_BLOB);
    if (c.CryptUnprotectData(
        &protected_blob,
        null,
        null,
        null,
        null,
        c.CRYPTPROTECT_UI_FORBIDDEN,
        &plaintext,
    ) == 0) return error.WindowsDataUnprotectFailed;
    defer wipeAndFreeBlob(&plaintext);
    if (plaintext.cbData > output.len) return error.ProtectedOutputTooSmall;

    const plaintext_bytes: [*]const u8 = @ptrCast(plaintext.pbData);
    @memcpy(output[0..plaintext.cbData], plaintext_bytes[0..plaintext.cbData]);
    return plaintext.cbData;
}

fn saveProtected(
    filename: []const u16,
    description: [*:0]const u16,
    bytes: []const u8,
) !void {
    if (bytes.len == 0 or bytes.len > std.math.maxInt(c.DWORD))
        return error.InvalidProtectedInput;
    var path: [path_capacity:0]u16 = undefined;
    if (!dataPath(&path, filename)) return error.WindowsDataPathUnavailable;
    var temporary = temporaryPath(&path) orelse return error.WindowsDataPathTooLong;

    var plaintext = c.DATA_BLOB{
        .cbData = @intCast(bytes.len),
        .pbData = @constCast(bytes.ptr),
    };
    var protected_blob: c.DATA_BLOB = std.mem.zeroes(c.DATA_BLOB);
    if (c.CryptProtectData(
        &plaintext,
        description,
        null,
        null,
        null,
        c.CRYPTPROTECT_UI_FORBIDDEN,
        &protected_blob,
    ) == 0) return error.WindowsDataProtectFailed;
    defer wipeAndFreeBlob(&protected_blob);

    var file = c.CreateFileW(
        &temporary,
        c.GENERIC_WRITE,
        0,
        null,
        c.CREATE_ALWAYS,
        c.FILE_ATTRIBUTE_HIDDEN | c.FILE_ATTRIBUTE_TEMPORARY,
        null,
    );
    if (file == c.INVALID_HANDLE_VALUE) return error.WindowsDataCreateFailed;
    var committed = false;
    defer {
        closeHandle(file);
        if (!committed) _ = c.DeleteFileW(&temporary);
    }

    var written: c.DWORD = 0;
    if (c.WriteFile(
        file,
        protected_blob.pbData,
        protected_blob.cbData,
        &written,
        null,
    ) == 0 or written != protected_blob.cbData or c.FlushFileBuffers(file) == 0) {
        return error.WindowsDataWriteFailed;
    }
    closeHandle(file);
    file = c.INVALID_HANDLE_VALUE;
    if (c.MoveFileExW(
        &temporary,
        &path,
        c.MOVEFILE_REPLACE_EXISTING | c.MOVEFILE_WRITE_THROUGH,
    ) == 0) return error.WindowsDataCommitFailed;
    committed = true;
}

pub fn identityLoad(secret: []u8) !bool {
    const length = try loadProtected(identity_file, secret, identity_blob_bytes_max, null) orelse
        return false;
    if (length != secret.len) return error.InvalidIdentityLength;
    return true;
}

pub fn identitySave(secret: []const u8) !void {
    try saveProtected(identity_file, identity_description, secret);
}

pub fn random(bytes: []u8) !void {
    if (bytes.len == 0 or bytes.len > std.math.maxInt(c.ULONG))
        return error.InvalidRandomOutput;
    if (c.BCryptGenRandom(
        null,
        bytes.ptr,
        @intCast(bytes.len),
        c.BCRYPT_USE_SYSTEM_PREFERRED_RNG,
    ) != 0) return error.WindowsRandomFailed;
}

pub fn peersLoad(output: []u8, version: ?*PeerStoreVersion) !?usize {
    return loadProtected(peers_file, output, peers_blob_bytes_max, version);
}

pub fn peersSave(bytes: []const u8) !void {
    try saveProtected(peers_file, peers_description, bytes);
}

pub fn stateLoad(output: []u8) !?usize {
    if (output.len == 0) return error.InvalidStateOutput;
    var path: [path_capacity:0]u16 = undefined;
    if (!dataPath(&path, state_file)) return error.WindowsDataPathUnavailable;

    const file = c.CreateFileW(
        &path,
        c.GENERIC_READ,
        c.FILE_SHARE_READ,
        null,
        c.OPEN_EXISTING,
        c.FILE_ATTRIBUTE_NORMAL,
        null,
    );
    if (file == c.INVALID_HANDLE_VALUE) {
        if (c.GetLastError() == c.ERROR_FILE_NOT_FOUND) return null;
        return error.WindowsDataOpenFailed;
    }
    defer closeHandle(file);

    const size: usize = c.GetFileSize(file, null);
    if (size == c.INVALID_FILE_SIZE or size == 0 or size > output.len)
        return error.InvalidWindowsState;
    var read_count: c.DWORD = 0;
    if (c.ReadFile(file, output.ptr, @intCast(size), &read_count, null) == 0 or
        read_count != size)
    {
        return error.WindowsDataReadFailed;
    }
    return size;
}

pub fn stateSave(bytes: []const u8) !void {
    if (bytes.len == 0 or bytes.len > std.math.maxInt(c.DWORD))
        return error.InvalidWindowsState;
    var path: [path_capacity:0]u16 = undefined;
    if (!dataPath(&path, state_file)) return error.WindowsDataPathUnavailable;
    var temporary = temporaryPath(&path) orelse return error.WindowsDataPathTooLong;

    var file = c.CreateFileW(
        &temporary,
        c.GENERIC_WRITE,
        0,
        null,
        c.CREATE_ALWAYS,
        c.FILE_ATTRIBUTE_HIDDEN | c.FILE_ATTRIBUTE_TEMPORARY,
        null,
    );
    if (file == c.INVALID_HANDLE_VALUE) return error.WindowsDataCreateFailed;
    var committed = false;
    defer {
        closeHandle(file);
        if (!committed) _ = c.DeleteFileW(&temporary);
    }

    var written: c.DWORD = 0;
    if (c.WriteFile(file, bytes.ptr, @intCast(bytes.len), &written, null) == 0 or
        written != bytes.len or c.FlushFileBuffers(file) == 0)
    {
        return error.WindowsDataWriteFailed;
    }
    closeHandle(file);
    file = c.INVALID_HANDLE_VALUE;
    if (c.MoveFileExW(
        &temporary,
        &path,
        c.MOVEFILE_REPLACE_EXISTING | c.MOVEFILE_WRITE_THROUGH,
    ) == 0) return error.WindowsDataCommitFailed;
    committed = true;
}
