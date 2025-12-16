// Home OS - Cryptography API
// Copyright © 2025 Romy Rianata - Home OS
// Phase 21: Cryptography Foundation - Main API

const serial = @import("../drivers/serial.zig");

pub const rng = @import("rng.zig");
pub const sha256 = @import("sha256.zig");

var crypto_initialized: bool = false;

/// Initialize cryptography subsystem
pub fn init() bool {
    serial.write("Crypto: Initializing cryptography subsystem...\n");

    // Initialize RNG
    rng.init();

    crypto_initialized = true;
    serial.write("Crypto: Ready\n");
    return true;
}

/// Check if initialized
pub fn isInitialized() bool {
    return crypto_initialized;
}

/// Get random bytes (convenience wrapper)
pub fn randomBytes(buf: []u8) void {
    rng.getBytes(buf);
}

/// Get random u32 (convenience wrapper)
pub fn randomU32() u32 {
    return rng.getU32();
}

/// Get random u64 (convenience wrapper)
pub fn randomU64() u64 {
    return rng.getU64();
}

/// Hash data with SHA-256 (convenience wrapper)
pub fn hashSha256(data: []const u8) sha256.Hash {
    return sha256.hash(data);
}

/// Secure memory wipe (prevent compiler optimization)
pub fn secureZero(buf: []u8) void {
    // Use volatile to prevent optimization
    for (buf) |*b| {
        @as(*volatile u8, b).* = 0;
    }
    // Memory barrier
    asm volatile ("" ::: .{ .memory = true });
}

/// Constant-time comparison (prevent timing attacks)
pub fn constantTimeCompare(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;

    var diff: u8 = 0;
    for (a, b) |x, y| {
        diff |= x ^ y;
    }
    return diff == 0;
}

/// XOR two byte arrays
pub fn xorBytes(dst: []u8, src: []const u8) void {
    const len = @min(dst.len, src.len);
    for (dst[0..len], src[0..len]) |*d, s| {
        d.* ^= s;
    }
}

/// Simple key derivation (PBKDF2-like, simplified)
pub fn deriveKey(password: []const u8, salt: []const u8, iterations: u32, output: []u8) void {
    var block: [sha256.HASH_SIZE]u8 = undefined;
    var u: [sha256.HASH_SIZE]u8 = undefined;

    var block_num: u32 = 1;
    var offset: usize = 0;

    while (offset < output.len) {
        // U1 = PRF(Password, Salt || INT(i))
        var ctx = sha256.Sha256.init();
        ctx.update(password);
        ctx.update(salt);

        // Append block number (big-endian)
        const block_bytes: [4]u8 = .{
            @truncate(block_num >> 24),
            @truncate(block_num >> 16),
            @truncate(block_num >> 8),
            @truncate(block_num),
        };
        ctx.update(&block_bytes);
        u = ctx.final();
        block = u;

        // Iterate
        var i: u32 = 1;
        while (i < iterations) : (i += 1) {
            var ctx2 = sha256.Sha256.init();
            ctx2.update(password);
            ctx2.update(&u);
            u = ctx2.final();

            // XOR into block
            for (&block, u) |*b, x| {
                b.* ^= x;
            }
        }

        // Copy to output
        const to_copy = @min(sha256.HASH_SIZE, output.len - offset);
        for (block[0..to_copy], 0..) |b, j| {
            output[offset + j] = b;
        }

        offset += to_copy;
        block_num += 1;
    }

    // Wipe sensitive data
    secureZero(&block);
    secureZero(&u);
}

/// Generate random hex string
pub fn randomHex(buf: []u8) void {
    const hex = "0123456789abcdef";
    var i: usize = 0;
    while (i < buf.len) {
        const r = rng.getU32();
        const bytes: [4]u8 = @bitCast(r);

        for (bytes) |b| {
            if (i >= buf.len) break;
            buf[i] = hex[b >> 4];
            i += 1;
            if (i >= buf.len) break;
            buf[i] = hex[b & 0x0F];
            i += 1;
        }
    }
}
