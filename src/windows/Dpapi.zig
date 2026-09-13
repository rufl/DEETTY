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
const theme_state_file = std.unicode.utf8ToUtf16LeStringLiteral("\\windows-themes-v1.bin");
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

    const protected_bytes: [*]const u8 = @ptrCast(protected_blob.pbData);
    try writeFileAtomicW(&path, protected_bytes[0..protected_blob.cbData], true);
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
    const file = try openPlainW(&path) orelse return null;
    defer closeHandle(file);
    const size = try plainSize(file, output.len);
    try readPlain(file, output[0..size]);
    return size;
}

pub fn stateSave(bytes: []const u8) !void {
    var path: [path_capacity:0]u16 = undefined;
    if (!dataPath(&path, state_file)) return error.WindowsDataPathUnavailable;
    try writeFileAtomicW(&path, bytes, true);
}

pub fn themeStateLoadAlloc(allocator: std.mem.Allocator, maximum: usize) !?[]u8 {
    var path: [path_capacity:0]u16 = undefined;
    if (!dataPath(&path, theme_state_file)) return error.WindowsDataPathUnavailable;
    return readFileAllocW(allocator, &path, maximum);
}

pub fn themeStateSave(bytes: []const u8) !void {
    var path: [path_capacity:0]u16 = undefined;
    if (!dataPath(&path, theme_state_file)) return error.WindowsDataPathUnavailable;
    try writeFileAtomicW(&path, bytes, true);
}

pub fn readFileAllocUtf8(allocator: std.mem.Allocator, path: []const u8, maximum: usize) ![]u8 {
    const wide = try unicodePath(allocator, path);
    defer allocator.free(wide);
    return try readFileAllocW(allocator, wide, maximum) orelse error.WindowsDataFileNotFound;
}

pub fn writeFileAtomicUtf8(allocator: std.mem.Allocator, path: []const u8, bytes: []const u8) !void {
    const wide = try unicodePath(allocator, path);
    defer allocator.free(wide);
    try writeFileAtomicW(wide, bytes, false);
}

fn unicodePath(allocator: std.mem.Allocator, path: []const u8) ![:0]u16 {
    if (path.len == 0 or path.len > 131_068 or std.mem.indexOfScalar(u8, path, 0) != null)
        return error.InvalidWindowsDataPath;
    const wide = try std.unicode.utf8ToUtf16LeAllocZ(allocator, path);
    errdefer allocator.free(wide);
    if (wide.len > 32_700) return error.WindowsDataPathTooLong;
    return wide;
}

fn openPlainW(path: [*:0]const u16) !?c.HANDLE {
    const file = c.CreateFileW(path, c.GENERIC_READ, c.FILE_SHARE_READ, null, c.OPEN_EXISTING, c.FILE_ATTRIBUTE_NORMAL, null);
    if (file == c.INVALID_HANDLE_VALUE) {
        if (c.GetLastError() == c.ERROR_FILE_NOT_FOUND) return null;
        return error.WindowsDataOpenFailed;
    }
    return file;
}

fn plainSize(file: c.HANDLE, maximum: usize) !usize {
    var size: c.LARGE_INTEGER = undefined;
    if (c.GetFileSizeEx(file, &size) == 0) return error.WindowsDataStatFailed;
    if (size.QuadPart <= 0 or size.QuadPart > maximum or size.QuadPart > std.math.maxInt(c.DWORD))
        return error.InvalidWindowsState;
    return @intCast(size.QuadPart);
}

fn readPlain(file: c.HANDLE, output: []u8) !void {
    var read_count: c.DWORD = 0;
    if (c.ReadFile(file, output.ptr, @intCast(output.len), &read_count, null) == 0 or read_count != output.len)
        return error.WindowsDataReadFailed;
}

fn readFileAllocW(allocator: std.mem.Allocator, path: [*:0]const u16, maximum: usize) !?[]u8 {
    const file = try openPlainW(path) orelse return null;
    defer closeHandle(file);
    const size = try plainSize(file, maximum);
    const bytes = try allocator.alloc(u8, size);
    errdefer allocator.free(bytes);
    try readPlain(file, bytes);
    return bytes;
}

fn writeFileAtomicW(path: [*:0]const u16, bytes: []const u8, hidden: bool) !void {
    if (bytes.len == 0 or bytes.len > std.math.maxInt(c.DWORD))
        return error.InvalidWindowsState;
    const allocator = std.heap.page_allocator;
    const destination = std.mem.span(path);
    var entropy: [8]u8 = undefined;
    try random(&entropy);
    var suffix_buffer: [32]u8 = undefined;
    const suffix = try std.fmt.bufPrint(&suffix_buffer, ".tmp-{x}", .{std.mem.readInt(u64, &entropy, .little)});
    const temporary = try allocator.allocSentinel(u16, destination.len + suffix.len, 0);
    defer allocator.free(temporary);
    @memcpy(temporary[0..destination.len], destination);
    for (suffix, 0..) |ch, index| temporary[destination.len + index] = ch;
    var file = c.CreateFileW(
        temporary.ptr,
        c.GENERIC_WRITE,
        0,
        null,
        c.CREATE_NEW,
        if (hidden) c.FILE_ATTRIBUTE_HIDDEN | c.FILE_ATTRIBUTE_TEMPORARY else c.FILE_ATTRIBUTE_NORMAL,
        null,
    );
    if (file == c.INVALID_HANDLE_VALUE) return error.WindowsDataCreateFailed;
    var committed = false;
    defer {
        closeHandle(file);
        if (!committed) _ = c.DeleteFileW(temporary.ptr);
    }
    var written: c.DWORD = 0;
    if (c.WriteFile(file, bytes.ptr, @intCast(bytes.len), &written, null) == 0 or
        written != bytes.len or c.FlushFileBuffers(file) == 0) return error.WindowsDataWriteFailed;
    closeHandle(file);
    file = c.INVALID_HANDLE_VALUE;
    if (c.MoveFileExW(temporary.ptr, path, c.MOVEFILE_REPLACE_EXISTING | c.MOVEFILE_WRITE_THROUGH) == 0)
        return error.WindowsDataCommitFailed;
    committed = true;
}
