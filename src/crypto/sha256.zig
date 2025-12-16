// Home OS - SHA-256 Hash
// Copyright © 2025 Romy Rianata - Home OS
// Phase 21: Cryptography Foundation - SHA-256

const serial = @import("../drivers/serial.zig");

// SHA-256 Constants (first 32 bits of fractional parts of cube roots of first 64 primes)
const K: [64]u32 = .{
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
};

// Initial hash values (first 32 bits of fractional parts of square roots of first 8 primes)
const H_INIT: [8]u32 = .{
    0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
    0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
};

pub const HASH_SIZE: usize = 32; // 256 bits = 32 bytes
pub const BLOCK_SIZE: usize = 64; // 512 bits = 64 bytes

pub const Hash = [HASH_SIZE]u8;

/// SHA-256 Context
pub const Sha256 = struct {
    state: [8]u32,
    count: u64,
    buffer: [BLOCK_SIZE]u8,
    buffer_len: usize,

    pub fn init() Sha256 {
        return Sha256{
            .state = H_INIT,
            .count = 0,
            .buffer = [_]u8{0} ** BLOCK_SIZE,
            .buffer_len = 0,
        };
    }

    /// Update hash with data
    pub fn update(self: *Sha256, data: []const u8) void {
        var offset: usize = 0;

        // Fill buffer if partially filled
        if (self.buffer_len > 0) {
            const space = BLOCK_SIZE - self.buffer_len;
            const to_copy = @min(space, data.len);

            for (data[0..to_copy], 0..) |b, i| {
                self.buffer[self.buffer_len + i] = b;
            }
            self.buffer_len += to_copy;
            offset = to_copy;

            if (self.buffer_len == BLOCK_SIZE) {
                self.processBlock(&self.buffer);
                self.buffer_len = 0;
            }
        }

        // Process full blocks
        while (offset + BLOCK_SIZE <= data.len) {
            self.processBlock(data[offset..][0..BLOCK_SIZE]);
            offset += BLOCK_SIZE;
        }

        // Store remaining bytes
        if (offset < data.len) {
            const remaining = data.len - offset;
            for (data[offset..], 0..) |b, i| {
                self.buffer[i] = b;
            }
            self.buffer_len = remaining;
        }

        self.count += data.len;
    }

    /// Finalize and get hash
    pub fn final(self: *Sha256) Hash {
        // Padding
        const bit_len = self.count * 8;

        // Append 1 bit (0x80)
        self.buffer[self.buffer_len] = 0x80;
        self.buffer_len += 1;

        // Pad with zeros
        if (self.buffer_len > 56) {
            // Need extra block
            while (self.buffer_len < BLOCK_SIZE) {
                self.buffer[self.buffer_len] = 0;
                self.buffer_len += 1;
            }
            self.processBlock(&self.buffer);
            self.buffer_len = 0;
        }

        while (self.buffer_len < 56) {
            self.buffer[self.buffer_len] = 0;
            self.buffer_len += 1;
        }

        // Append length (big-endian)
        self.buffer[56] = @truncate(bit_len >> 56);
        self.buffer[57] = @truncate(bit_len >> 48);
        self.buffer[58] = @truncate(bit_len >> 40);
        self.buffer[59] = @truncate(bit_len >> 32);
        self.buffer[60] = @truncate(bit_len >> 24);
        self.buffer[61] = @truncate(bit_len >> 16);
        self.buffer[62] = @truncate(bit_len >> 8);
        self.buffer[63] = @truncate(bit_len);

        self.processBlock(&self.buffer);

        // Output hash (big-endian)
        var result: Hash = undefined;
        for (self.state, 0..) |s, i| {
            result[i * 4 + 0] = @truncate(s >> 24);
            result[i * 4 + 1] = @truncate(s >> 16);
            result[i * 4 + 2] = @truncate(s >> 8);
            result[i * 4 + 3] = @truncate(s);
        }

        return result;
    }

    /// Process a 64-byte block
    fn processBlock(self: *Sha256, block: *const [BLOCK_SIZE]u8) void {
        var w: [64]u32 = undefined;

        // Prepare message schedule
        for (0..16) |i| {
            w[i] = (@as(u32, block[i * 4]) << 24) |
                (@as(u32, block[i * 4 + 1]) << 16) |
                (@as(u32, block[i * 4 + 2]) << 8) |
                @as(u32, block[i * 4 + 3]);
        }

        for (16..64) |i| {
            const s0 = rotr(w[i - 15], 7) ^ rotr(w[i - 15], 18) ^ (w[i - 15] >> 3);
            const s1 = rotr(w[i - 2], 17) ^ rotr(w[i - 2], 19) ^ (w[i - 2] >> 10);
            w[i] = w[i - 16] +% s0 +% w[i - 7] +% s1;
        }

        // Working variables
        var a = self.state[0];
        var b = self.state[1];
        var c = self.state[2];
        var d = self.state[3];
        var e = self.state[4];
        var f = self.state[5];
        var g = self.state[6];
        var h = self.state[7];

        // Compression
        for (0..64) |i| {
            const S1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25);
            const ch = (e & f) ^ ((~e) & g);
            const temp1 = h +% S1 +% ch +% K[i] +% w[i];
            const S0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22);
            const maj = (a & b) ^ (a & c) ^ (b & c);
            const temp2 = S0 +% maj;

            h = g;
            g = f;
            f = e;
            e = d +% temp1;
            d = c;
            c = b;
            b = a;
            a = temp1 +% temp2;
        }

        // Update state
        self.state[0] +%= a;
        self.state[1] +%= b;
        self.state[2] +%= c;
        self.state[3] +%= d;
        self.state[4] +%= e;
        self.state[5] +%= f;
        self.state[6] +%= g;
        self.state[7] +%= h;
    }
};

/// Right rotate
fn rotr(x: u32, comptime n: comptime_int) u32 {
    const shift: u5 = n;
    const inv_shift: u5 = 32 - n;
    return (x >> shift) | (x << inv_shift);
}

/// Hash data in one call
pub fn hash(data: []const u8) Hash {
    var ctx = Sha256.init();
    ctx.update(data);
    return ctx.final();
}

/// Hash to hex string
pub fn hashToHex(h: Hash, buf: []u8) usize {
    const hex = "0123456789abcdef";
    var pos: usize = 0;

    for (h) |byte| {
        if (pos + 2 > buf.len) break;
        buf[pos] = hex[byte >> 4];
        buf[pos + 1] = hex[byte & 0x0F];
        pos += 2;
    }

    return pos;
}

/// Compare two hashes (constant time)
pub fn hashEqual(a: Hash, b: Hash) bool {
    var diff: u8 = 0;
    for (a, b) |x, y| {
        diff |= x ^ y;
    }
    return diff == 0;
}
