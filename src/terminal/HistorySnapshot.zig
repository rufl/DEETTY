const std = @import("std");

const HmacSha256 = std.crypto.auth.hmac.sha2.HmacSha256;
const Cipher = std.crypto.aead.chacha_poly.XChaCha20Poly1305;

pub const max_password_bytes: usize = 4096;
pub const max_plaintext_bytes: usize = 16 * 1024 * 1024;
const salt_length = 16;
const key_length = 32;
const iterations: u32 = 200_000;
const magic = "DINTTYHS";
const version: u8 = 1;
const header_length = magic.len + 1 + salt_length + Cipher.nonce_length + 8;

pub fn encryptAlloc(
    allocator: std.mem.Allocator,
    plaintext: []const u8,
    password: []const u8,
) ![]u8 {
    try validateInput(plaintext, password);
    var salt: [salt_length]u8 = undefined;
    var nonce: [Cipher.nonce_length]u8 = undefined;
    var key: [key_length]u8 = undefined;
    defer std.crypto.secureZero(u8, key[0..]);
    try fillRandom(salt[0..]);
    try fillRandom(nonce[0..]);
    try deriveKey(&key, password, salt[0..]);

    const total = try std.math.add(usize, header_length, plaintext.len);
    const total_with_tag = try std.math.add(usize, total, Cipher.tag_length);
    var output = try allocator.alloc(u8, total_with_tag);
    errdefer allocator.free(output);
    @memcpy(output[0..magic.len], magic);
    output[magic.len] = version;
    var offset = magic.len + 1;
    @memcpy(output[offset .. offset + salt.len], salt[0..]);
    offset += salt.len;
    @memcpy(output[offset .. offset + nonce.len], nonce[0..]);
    offset += nonce.len;
    var plaintext_length_bytes: [8]u8 = undefined;
    std.mem.writeInt(u64, &plaintext_length_bytes, plaintext.len, .little);
    @memcpy(output[offset .. offset + 8], plaintext_length_bytes[0..]);
    offset += 8;
    const ciphertext = output[offset .. offset + plaintext.len];
    const tag_ptr: *[Cipher.tag_length]u8 = @ptrCast(output[offset + plaintext.len ..][0..Cipher.tag_length]);
    Cipher.encrypt(ciphertext, tag_ptr, plaintext, output[0..header_length], nonce, key);
    return output;
}

pub fn decryptAlloc(
    allocator: std.mem.Allocator,
    encrypted: []const u8,
    password: []const u8,
) ![]u8 {
    if (encrypted.len < header_length + Cipher.tag_length)
        return error.InvalidHistorySnapshot;
    if (!std.mem.eql(u8, encrypted[0..magic.len], magic) or
        encrypted[magic.len] != version)
        return error.InvalidHistorySnapshot;
    try validatePassword(password);
    var offset = magic.len + 1;
    const salt = encrypted[offset .. offset + salt_length];
    offset += salt_length;
    var nonce: [Cipher.nonce_length]u8 = undefined;
    @memcpy(nonce[0..], encrypted[offset .. offset + nonce.len]);
    offset += nonce.len;
    var plaintext_length_bytes: [8]u8 = undefined;
    @memcpy(plaintext_length_bytes[0..], encrypted[offset .. offset + 8]);
    const plaintext_length = std.mem.readInt(u64, &plaintext_length_bytes, .little);
    offset += 8;
    if (plaintext_length > max_plaintext_bytes or
        plaintext_length != encrypted.len - header_length - Cipher.tag_length)
        return error.InvalidHistorySnapshot;
    var key: [key_length]u8 = undefined;
    defer std.crypto.secureZero(u8, key[0..]);
    try deriveKey(&key, password, salt);
    const ciphertext = encrypted[offset .. offset + @as(usize, @intCast(plaintext_length))];
    const tag_slice = encrypted[offset + ciphertext.len ..][0..Cipher.tag_length];
    var tag: [Cipher.tag_length]u8 = undefined;
    @memcpy(tag[0..], tag_slice);
    const plaintext = try allocator.alloc(u8, ciphertext.len);
    errdefer allocator.free(plaintext);
    Cipher.decrypt(plaintext, ciphertext, tag, encrypted[0..header_length], nonce, key) catch
        return error.InvalidHistorySnapshotPassword;
    return plaintext;
}

fn fillRandom(output: []u8) !void {
    if (std.os.linux.getrandom(output.ptr, output.len, 0) != output.len)
        return error.EntropyUnavailable;
}

fn deriveKey(key: *[key_length]u8, password: []const u8, salt: []const u8) !void {
    try std.crypto.pwhash.pbkdf2(key[0..], password, salt, iterations, HmacSha256);
}

fn validateInput(plaintext: []const u8, password: []const u8) !void {
    if (plaintext.len > max_plaintext_bytes) return error.HistorySnapshotTooLarge;
    try validatePassword(password);
}

fn validatePassword(password: []const u8) !void {
    if (password.len < 8 or password.len > max_password_bytes)
        return error.InvalidHistorySnapshotPassword;
    if (std.mem.indexOfAny(u8, password, "\x00\r\n") != null)
        return error.InvalidHistorySnapshotPassword;
}

test "encrypted history snapshots round trip and authenticate" {
    const plaintext = "agent output\nwith secrets kept encrypted\n";
    const encrypted = try encryptAlloc(std.testing.allocator, plaintext, "correct horse battery");
    defer std.testing.allocator.free(encrypted);
    try std.testing.expect(!std.mem.eql(u8, encrypted[header_length..][0..plaintext.len], plaintext));
    const decrypted = try decryptAlloc(std.testing.allocator, encrypted, "correct horse battery");
    defer std.testing.allocator.free(decrypted);
    try std.testing.expectEqualStrings(plaintext, decrypted);
    try std.testing.expectError(
        error.InvalidHistorySnapshotPassword,
        decryptAlloc(std.testing.allocator, encrypted, "wrong password"),
    );
}

test "encrypted history snapshots reject oversized and weak inputs" {
    try std.testing.expectError(
        error.InvalidHistorySnapshotPassword,
        encryptAlloc(std.testing.allocator, "text", "short"),
    );
    const oversized = try std.testing.allocator.alloc(u8, max_plaintext_bytes + 1);
    defer std.testing.allocator.free(oversized);
    try std.testing.expectError(
        error.HistorySnapshotTooLarge,
        encryptAlloc(std.testing.allocator, oversized, "long enough password"),
    );
}
