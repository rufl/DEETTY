const std = @import("std");

const X25519 = std.crypto.dh.X25519;
const Cipher = std.crypto.aead.chacha_poly.ChaCha20Poly1305;
const Blake2s = std.crypto.hash.blake2.Blake2s256;
const HmacBlake2s = std.crypto.auth.hmac.Hmac(Blake2s);

pub const protocol_name = "Noise_XX_25519_ChaChaPoly_BLAKE2s";
pub const prologue = "NOCTTY-PAIR-v1";
pub const public_key_length = X25519.public_length;
pub const secret_key_length = X25519.secret_length;
pub const message1_length = 32;
pub const message2_length = 96;
pub const message3_length = 64;
pub const transport_tag_length = Cipher.tag_length;
pub const max_plaintext_bytes: usize = 60 * 1024;

pub const Role = enum { initiator, responder };
pub const RandomContext = std.Io;

pub fn fromIo(io: std.Io) RandomContext {
    return io;
}

pub fn testingRandomContext() RandomContext {
    return std.testing.io;
}

pub const Identity = struct {
    public_key: [public_key_length]u8,
    secret_key: [secret_key_length]u8,

    pub fn generate(random: RandomContext) Identity {
        const pair = X25519.KeyPair.generate(random);
        return .{ .public_key = pair.public_key, .secret_key = pair.secret_key };
    }

    pub fn fromSecret(secret_key: [secret_key_length]u8) !Identity {
        return .{
            .public_key = X25519.recoverPublicKey(secret_key),
            .secret_key = secret_key,
        };
    }

    pub fn deinit(self: *Identity) void {
        std.crypto.secureZero(u8, self.secret_key[0..]);
    }
};

const CipherState = struct {
    key: ?[32]u8 = null,
    nonce: u64 = 0,

    fn initializeKey(self: *CipherState, key: [32]u8) void {
        self.key = key;
        self.nonce = 0;
    }

    fn encrypt(self: *CipherState, output: []u8, plaintext: []const u8, ad: []const u8) !usize {
        if (self.key) |key| {
            if (self.nonce == std.math.maxInt(u64)) return error.NoiseNonceExhausted;
            if (output.len < plaintext.len + Cipher.tag_length) return error.NoiseOutputTooSmall;
            var tag: [Cipher.tag_length]u8 = undefined;
            Cipher.encrypt(output[0..plaintext.len], &tag, plaintext, ad, noiseNonce(self.nonce), key);
            @memcpy(output[plaintext.len .. plaintext.len + tag.len], tag[0..]);
            self.nonce += 1;
            return plaintext.len + tag.len;
        }
        if (output.len < plaintext.len) return error.NoiseOutputTooSmall;
        @memcpy(output[0..plaintext.len], plaintext);
        return plaintext.len;
    }

    fn decrypt(self: *CipherState, output: []u8, ciphertext: []const u8, ad: []const u8) !usize {
        if (self.key) |key| {
            if (self.nonce == std.math.maxInt(u64)) return error.NoiseNonceExhausted;
            if (ciphertext.len < Cipher.tag_length) return error.InvalidNoiseCiphertext;
            const plaintext_len = ciphertext.len - Cipher.tag_length;
            if (output.len < plaintext_len) return error.NoiseOutputTooSmall;
            var tag: [Cipher.tag_length]u8 = undefined;
            @memcpy(tag[0..], ciphertext[plaintext_len..]);
            Cipher.decrypt(output[0..plaintext_len], ciphertext[0..plaintext_len], tag, ad, noiseNonce(self.nonce), key) catch
                return error.NoiseAuthenticationFailed;
            self.nonce += 1;
            return plaintext_len;
        }
        if (output.len < ciphertext.len) return error.NoiseOutputTooSmall;
        @memcpy(output[0..ciphertext.len], ciphertext);
        return ciphertext.len;
    }

    fn deinit(self: *CipherState) void {
        if (self.key) |*key| std.crypto.secureZero(u8, key[0..]);
        self.* = .{};
    }
};

const SymmetricState = struct {
    cipher: CipherState = .{},
    chaining_key: [32]u8,
    handshake_hash: [32]u8,

    fn init() SymmetricState {
        var initial: [32]u8 = @splat(0);
        if (protocol_name.len <= initial.len) {
            @memcpy(initial[0..protocol_name.len], protocol_name);
        } else {
            Blake2s.hash(protocol_name, &initial, .{});
        }
        return .{ .chaining_key = initial, .handshake_hash = initial };
    }

    fn mixHash(self: *SymmetricState, data: []const u8) void {
        var hash = Blake2s.init(.{});
        hash.update(&self.handshake_hash);
        hash.update(data);
        hash.final(&self.handshake_hash);
    }

    fn mixKey(self: *SymmetricState, input: []const u8) void {
        const outputs = hkdf2(self.chaining_key, input);
        self.chaining_key = outputs[0];
        self.cipher.initializeKey(outputs[1]);
    }

    fn encryptAndHash(self: *SymmetricState, output: []u8, plaintext: []const u8) !usize {
        const count = try self.cipher.encrypt(output, plaintext, &self.handshake_hash);
        self.mixHash(output[0..count]);
        return count;
    }

    fn decryptAndHash(self: *SymmetricState, output: []u8, ciphertext: []const u8) !usize {
        const count = try self.cipher.decrypt(output, ciphertext, &self.handshake_hash);
        self.mixHash(ciphertext);
        return count;
    }

    fn split(self: *SymmetricState, role: Role) Transport {
        const outputs = hkdf2(self.chaining_key, "");
        const transport = switch (role) {
            .initiator => Transport.init(outputs[0], outputs[1], self.handshake_hash),
            .responder => Transport.init(outputs[1], outputs[0], self.handshake_hash),
        };
        self.cipher.deinit();
        std.crypto.secureZero(u8, self.chaining_key[0..]);
        return transport;
    }

    fn deinit(self: *SymmetricState) void {
        self.cipher.deinit();
        std.crypto.secureZero(u8, self.chaining_key[0..]);
        std.crypto.secureZero(u8, self.handshake_hash[0..]);
    }
};

pub const HandshakeResult = struct {
    remote_static: [public_key_length]u8,
    sas: u32,
    transport: Transport,
};

pub const Initiator = struct {
    identity: Identity,
    ephemeral: Identity,
    symmetric: SymmetricState,
    remote_ephemeral: ?[public_key_length]u8 = null,
    remote_static: ?[public_key_length]u8 = null,
    step: u8 = 0,

    pub fn init(identity: Identity, random: RandomContext) Initiator {
        return initDeterministic(identity, Identity.generate(random));
    }

    fn initDeterministic(identity: Identity, ephemeral: Identity) Initiator {
        var symmetric = SymmetricState.init();
        symmetric.mixHash(prologue);
        return .{ .identity = identity, .ephemeral = ephemeral, .symmetric = symmetric };
    }

    pub fn deinit(self: *Initiator) void {
        self.identity.deinit();
        self.ephemeral.deinit();
        if (self.remote_ephemeral) |*key| std.crypto.secureZero(u8, key[0..]);
        if (self.remote_static) |*key| std.crypto.secureZero(u8, key[0..]);
        self.remote_ephemeral = null;
        self.remote_static = null;
        self.symmetric.deinit();
        self.step = 0;
    }

    pub fn writeMessage1(self: *Initiator) ![message1_length]u8 {
        if (self.step != 0) return error.InvalidNoiseHandshakeState;
        const output = self.ephemeral.public_key;
        self.symmetric.mixHash(&output);
        self.step = 1;
        return output;
    }

    pub fn readMessage2(self: *Initiator, message: *const [message2_length]u8) !void {
        if (self.step != 1) return error.InvalidNoiseHandshakeState;
        const remote_ephemeral = message[0..32].*;
        self.symmetric.mixHash(&remote_ephemeral);
        var shared = try X25519.scalarmult(self.ephemeral.secret_key, remote_ephemeral);
        defer std.crypto.secureZero(u8, shared[0..]);
        self.symmetric.mixKey(&shared);
        var remote_static: [32]u8 = undefined;
        if (try self.symmetric.decryptAndHash(&remote_static, message[32..80]) != 32)
            return error.InvalidNoiseHandshakeMessage;
        shared = try X25519.scalarmult(self.ephemeral.secret_key, remote_static);
        self.symmetric.mixKey(&shared);
        var empty: [0]u8 = .{};
        if (try self.symmetric.decryptAndHash(&empty, message[80..96]) != 0)
            return error.InvalidNoiseHandshakeMessage;
        self.remote_ephemeral = remote_ephemeral;
        self.remote_static = remote_static;
        self.step = 2;
    }

    pub fn writeMessage3(self: *Initiator) ![message3_length]u8 {
        if (self.step != 2) return error.InvalidNoiseHandshakeState;
        var output: [message3_length]u8 = undefined;
        if (try self.symmetric.encryptAndHash(output[0..48], &self.identity.public_key) != 48)
            return error.InvalidNoiseHandshakeMessage;
        var shared = try X25519.scalarmult(self.identity.secret_key, self.remote_ephemeral.?);
        defer std.crypto.secureZero(u8, shared[0..]);
        self.symmetric.mixKey(&shared);
        if (try self.symmetric.encryptAndHash(output[48..64], "") != 16)
            return error.InvalidNoiseHandshakeMessage;
        self.step = 3;
        return output;
    }

    pub fn finish(self: *Initiator, pinned_remote: ?[public_key_length]u8) !HandshakeResult {
        if (self.step != 3) return error.InvalidNoiseHandshakeState;
        const remote_static = self.remote_static.?;
        if (pinned_remote) |expected| {
            if (!std.crypto.timing_safe.eql([32]u8, expected, remote_static))
                return error.PairedDeviceKeyChanged;
        }
        const sas = shortAuthenticationString(self.symmetric.handshake_hash);
        self.step = 4;
        return .{ .remote_static = remote_static, .sas = sas, .transport = self.symmetric.split(.initiator) };
    }
};

pub const Responder = struct {
    identity: Identity,
    ephemeral: Identity,
    symmetric: SymmetricState,
    remote_ephemeral: ?[public_key_length]u8 = null,
    remote_static: ?[public_key_length]u8 = null,
    step: u8 = 0,

    pub fn init(identity: Identity, random: RandomContext) Responder {
        return initDeterministic(identity, Identity.generate(random));
    }

    fn initDeterministic(identity: Identity, ephemeral: Identity) Responder {
        var symmetric = SymmetricState.init();
        symmetric.mixHash(prologue);
        return .{ .identity = identity, .ephemeral = ephemeral, .symmetric = symmetric };
    }

    pub fn deinit(self: *Responder) void {
        self.identity.deinit();
        self.ephemeral.deinit();
        if (self.remote_ephemeral) |*key| std.crypto.secureZero(u8, key[0..]);
        if (self.remote_static) |*key| std.crypto.secureZero(u8, key[0..]);
        self.remote_ephemeral = null;
        self.remote_static = null;
        self.symmetric.deinit();
        self.step = 0;
    }

    pub fn readMessage1(self: *Responder, message: *const [message1_length]u8) !void {
        if (self.step != 0) return error.InvalidNoiseHandshakeState;
        self.remote_ephemeral = message.*;
        self.symmetric.mixHash(message);
        self.step = 1;
    }

    pub fn writeMessage2(self: *Responder) ![message2_length]u8 {
        if (self.step != 1) return error.InvalidNoiseHandshakeState;
        var output: [message2_length]u8 = undefined;
        @memcpy(output[0..32], &self.ephemeral.public_key);
        self.symmetric.mixHash(output[0..32]);
        var shared = try X25519.scalarmult(self.ephemeral.secret_key, self.remote_ephemeral.?);
        defer std.crypto.secureZero(u8, shared[0..]);
        self.symmetric.mixKey(&shared);
        if (try self.symmetric.encryptAndHash(output[32..80], &self.identity.public_key) != 48)
            return error.InvalidNoiseHandshakeMessage;
        shared = try X25519.scalarmult(self.identity.secret_key, self.remote_ephemeral.?);
        self.symmetric.mixKey(&shared);
        if (try self.symmetric.encryptAndHash(output[80..96], "") != 16)
            return error.InvalidNoiseHandshakeMessage;
        self.step = 2;
        return output;
    }

    pub fn readMessage3(self: *Responder, message: *const [message3_length]u8) !void {
        if (self.step != 2) return error.InvalidNoiseHandshakeState;
        var remote_static: [32]u8 = undefined;
        if (try self.symmetric.decryptAndHash(&remote_static, message[0..48]) != 32)
            return error.InvalidNoiseHandshakeMessage;
        var shared = try X25519.scalarmult(self.ephemeral.secret_key, remote_static);
        defer std.crypto.secureZero(u8, shared[0..]);
        self.symmetric.mixKey(&shared);
        var empty: [0]u8 = .{};
        if (try self.symmetric.decryptAndHash(&empty, message[48..64]) != 0)
            return error.InvalidNoiseHandshakeMessage;
        self.remote_static = remote_static;
        self.step = 3;
    }

    pub fn finish(self: *Responder, pinned_remote: ?[public_key_length]u8) !HandshakeResult {
        if (self.step != 3) return error.InvalidNoiseHandshakeState;
        const remote_static = self.remote_static.?;
        if (pinned_remote) |expected| {
            if (!std.crypto.timing_safe.eql([32]u8, expected, remote_static))
                return error.PairedDeviceKeyChanged;
        }
        const sas = shortAuthenticationString(self.symmetric.handshake_hash);
        self.step = 4;
        return .{ .remote_static = remote_static, .sas = sas, .transport = self.symmetric.split(.responder) };
    }
};

pub const Transport = struct {
    send: CipherState,
    receive: CipherState,
    channel_binding: [32]u8,

    fn init(send_key: [32]u8, receive_key: [32]u8, channel_binding: [32]u8) Transport {
        var send = CipherState{};
        var receive = CipherState{};
        send.initializeKey(send_key);
        receive.initializeKey(receive_key);
        return .{ .send = send, .receive = receive, .channel_binding = channel_binding };
    }

    pub fn seal(self: *Transport, output: []u8, plaintext: []const u8) !usize {
        if (plaintext.len > max_plaintext_bytes) return error.NoisePayloadTooLarge;
        return self.send.encrypt(output, plaintext, prologue);
    }

    pub fn open(self: *Transport, output: []u8, ciphertext: []const u8) !usize {
        if (ciphertext.len > max_plaintext_bytes + Cipher.tag_length)
            return error.NoisePayloadTooLarge;
        return self.receive.decrypt(output, ciphertext, prologue);
    }

    pub fn deinit(self: *Transport) void {
        self.send.deinit();
        self.receive.deinit();
        std.crypto.secureZero(u8, self.channel_binding[0..]);
    }
};

fn noiseNonce(value: u64) [Cipher.nonce_length]u8 {
    var nonce: [Cipher.nonce_length]u8 = @splat(0);
    std.mem.writeInt(u64, nonce[4..12], value, .little);
    return nonce;
}

fn hkdf2(chaining_key: [32]u8, input: []const u8) [2][32]u8 {
    var temporary: [32]u8 = undefined;
    HmacBlake2s.create(&temporary, input, &chaining_key);
    var first: [32]u8 = undefined;
    HmacBlake2s.create(&first, &.{1}, &temporary);
    var second_input: [33]u8 = undefined;
    @memcpy(second_input[0..32], &first);
    second_input[32] = 2;
    var second: [32]u8 = undefined;
    HmacBlake2s.create(&second, &second_input, &temporary);
    std.crypto.secureZero(u8, temporary[0..]);
    return .{ first, second };
}

fn shortAuthenticationString(handshake_hash: [32]u8) u32 {
    return std.mem.readInt(u32, handshake_hash[0..4], .big) % 1_000_000;
}

pub fn formatSas(output: *[6]u8, sas: u32) void {
    var value = sas % 1_000_000;
    var index: usize = output.len;
    while (index > 0) {
        index -= 1;
        output[index] = @intCast('0' + value % 10);
        value /= 10;
    }
}

test "Noise XX pairing agrees on identity SAS and transport keys" {
    const initiator_identity = try Identity.fromSecret(@as([32]u8, @splat(1)));
    const responder_identity = try Identity.fromSecret(@as([32]u8, @splat(2)));
    const initiator_ephemeral = try Identity.fromSecret(@as([32]u8, @splat(3)));
    const responder_ephemeral = try Identity.fromSecret(@as([32]u8, @splat(4)));
    var initiator = Initiator.initDeterministic(initiator_identity, initiator_ephemeral);
    var responder = Responder.initDeterministic(responder_identity, responder_ephemeral);

    const message1 = try initiator.writeMessage1();
    try responder.readMessage1(&message1);
    const message2 = try responder.writeMessage2();
    try initiator.readMessage2(&message2);
    const message3 = try initiator.writeMessage3();
    try responder.readMessage3(&message3);
    var initiator_result = try initiator.finish(responder_identity.public_key);
    defer initiator_result.transport.deinit();
    var responder_result = try responder.finish(initiator_identity.public_key);
    defer responder_result.transport.deinit();

    try std.testing.expectEqual(responder_identity.public_key, initiator_result.remote_static);
    try std.testing.expectEqual(initiator_identity.public_key, responder_result.remote_static);
    try std.testing.expectEqual(initiator_result.sas, responder_result.sas);

    const plaintext = "paired terminal output";
    var ciphertext: [plaintext.len + Cipher.tag_length]u8 = undefined;
    const encrypted = try initiator_result.transport.seal(&ciphertext, plaintext);
    var decrypted: [plaintext.len]u8 = undefined;
    const opened = try responder_result.transport.open(&decrypted, ciphertext[0..encrypted]);
    try std.testing.expectEqualStrings(plaintext, decrypted[0..opened]);
}

test "Noise transport rejects tampering replay and substituted pinned keys" {
    const first = try Identity.fromSecret(@as([32]u8, @splat(5)));
    const second = try Identity.fromSecret(@as([32]u8, @splat(6)));
    var initiator = Initiator.initDeterministic(first, try Identity.fromSecret(@as([32]u8, @splat(7))));
    var responder = Responder.initDeterministic(second, try Identity.fromSecret(@as([32]u8, @splat(8))));
    const message1 = try initiator.writeMessage1();
    try responder.readMessage1(&message1);
    const message2 = try responder.writeMessage2();
    try initiator.readMessage2(&message2);
    const message3 = try initiator.writeMessage3();
    try responder.readMessage3(&message3);
    try std.testing.expectError(error.PairedDeviceKeyChanged, initiator.finish(@as([32]u8, @splat(9))));

    var initiator_ok = Initiator.initDeterministic(first, try Identity.fromSecret(@as([32]u8, @splat(7))));
    var responder_ok = Responder.initDeterministic(second, try Identity.fromSecret(@as([32]u8, @splat(8))));
    const one = try initiator_ok.writeMessage1();
    try responder_ok.readMessage1(&one);
    const two = try responder_ok.writeMessage2();
    try initiator_ok.readMessage2(&two);
    const three = try initiator_ok.writeMessage3();
    try responder_ok.readMessage3(&three);
    var left = try initiator_ok.finish(second.public_key);
    defer left.transport.deinit();
    var right = try responder_ok.finish(first.public_key);
    defer right.transport.deinit();
    var ciphertext: [17]u8 = undefined;
    _ = try left.transport.seal(&ciphertext, "x");
    ciphertext[0] ^= 1;
    var plaintext: [1]u8 = undefined;
    try std.testing.expectError(error.NoiseAuthenticationFailed, right.transport.open(&plaintext, &ciphertext));
    ciphertext[0] ^= 1;
    _ = try right.transport.open(&plaintext, &ciphertext);
    try std.testing.expectError(error.NoiseAuthenticationFailed, right.transport.open(&plaintext, &ciphertext));
}
