// Home OS - Random Number Generator
// Copyright © 2025 Romy Rianata - Home OS
// Phase 21: Cryptography Foundation - RNG

const serial = @import("../drivers/serial.zig");
const pit = @import("../drivers/pit.zig");

// RNG State
var rng_initialized: bool = false;
var has_rdrand: bool = false;
var has_rdseed: bool = false;

// Software PRNG state (xorshift128+)
var prng_state: [2]u64 = undefined;

/// Check CPU for RDRAND/RDSEED support
fn detectHardwareRng() void {
    // For now, assume no hardware RNG (QEMU may not support RDRAND)
    // This can be enabled later with proper CPUID detection
    has_rdrand = false;
    has_rdseed = false;

    // Try CPUID to check for RDRAND support (bit 30 of ECX from CPUID.01H)
    var ecx: u32 = undefined;
    asm volatile ("cpuid"
        : [ecx] "={ecx}" (ecx),
        : [eax] "{eax}" (@as(u32, 1)),
        : .{ .ebx = true, .edx = true });

    if ((ecx & (1 << 30)) != 0) {
        has_rdrand = true;
    }
}

/// Initialize RNG
pub fn init() void {
    serial.write("RNG: Initializing...\n");

    detectHardwareRng();

    if (has_rdrand) {
        serial.write("RNG: RDRAND supported\n");
    }
    if (has_rdseed) {
        serial.write("RNG: RDSEED supported\n");
    }

    // Seed software PRNG with available entropy
    seedPrng();

    rng_initialized = true;
    serial.write("RNG: Ready\n");
}

/// Seed the software PRNG
fn seedPrng() void {
    // Try hardware RNG first
    if (has_rdrand) {
        prng_state[0] = rdrand64() orelse getMixedEntropy();
        prng_state[1] = rdrand64() orelse getMixedEntropy();
    } else {
        // Use mixed entropy sources
        prng_state[0] = getMixedEntropy();
        prng_state[1] = getMixedEntropy() ^ 0x5DEECE66D;
    }

    // Ensure non-zero state
    if (prng_state[0] == 0) prng_state[0] = 0x853c49e6748fea9b;
    if (prng_state[1] == 0) prng_state[1] = 0xda3e39cb94b95bdb;
}

/// Get entropy from various sources
fn getMixedEntropy() u64 {
    const ticks = pit.getTicks();
    const uptime = pit.getUptime();

    // Read TSC if available
    var tsc_low: u32 = undefined;
    var tsc_high: u32 = undefined;
    asm volatile ("rdtsc"
        : [low] "={eax}" (tsc_low),
          [high] "={edx}" (tsc_high),
    );

    const tsc: u64 = (@as(u64, tsc_high) << 32) | @as(u64, tsc_low);

    // Mix entropy sources
    var entropy: u64 = tsc;
    entropy ^= @as(u64, ticks) << 32;
    entropy ^= @as(u64, uptime) * 0x9E3779B97F4A7C15;
    entropy ^= 0xBB67AE8584CAA73B; // Constant from SHA-256

    return entropy;
}

/// RDRAND instruction (32-bit)
fn rdrand32() ?u32 {
    if (!has_rdrand) return null;

    var result: u32 = undefined;
    var cf: u8 = undefined;

    // Try up to 10 times
    var attempts: u32 = 10;
    while (attempts > 0) : (attempts -= 1) {
        // RDRAND opcode: 0x0F 0xC7 /6 (with r32)
        // 0x0F 0xC7 0xF0 = rdrand eax
        asm volatile (
            \\.byte 0x0f, 0xc7, 0xf0
            \\setc %[cf]
            : [out] "={eax}" (result),
              [cf] "=r" (cf),
            :
            : .{ .cc = true });
        if (cf != 0) return result;
    }
    return null;
}

/// RDRAND instruction (64-bit via two 32-bit calls)
fn rdrand64() ?u64 {
    const low = rdrand32() orelse return null;
    const high = rdrand32() orelse return null;
    return (@as(u64, high) << 32) | @as(u64, low);
}

/// Xorshift128+ PRNG
fn xorshift128plus() u64 {
    var s1 = prng_state[0];
    const s0 = prng_state[1];

    prng_state[0] = s0;
    s1 ^= s1 << 23;
    s1 ^= s1 >> 17;
    s1 ^= s0;
    s1 ^= s0 >> 26;
    prng_state[1] = s1;

    return s0 +% s1;
}

/// Get random u32
pub fn getU32() u32 {
    if (has_rdrand) {
        if (rdrand32()) |val| return val;
    }
    return @truncate(xorshift128plus());
}

/// Get random u64
pub fn getU64() u64 {
    if (has_rdrand) {
        if (rdrand64()) |val| return val;
    }
    return xorshift128plus();
}

/// Get random bytes
pub fn getBytes(buf: []u8) void {
    var i: usize = 0;
    while (i < buf.len) {
        const rand = getU64();
        const rand_bytes: [8]u8 = @bitCast(rand);

        var j: usize = 0;
        while (j < 8 and i < buf.len) : ({
            j += 1;
            i += 1;
        }) {
            buf[i] = rand_bytes[j];
        }
    }
}

/// Get random number in range [0, max)
pub fn getRange(max: u32) u32 {
    if (max == 0) return 0;
    return getU32() % max;
}

/// Check if hardware RNG available
pub fn hasHardwareRng() bool {
    return has_rdrand;
}

/// Check if initialized
pub fn isInitialized() bool {
    return rng_initialized;
}

/// Reseed PRNG with fresh entropy
pub fn reseed() void {
    seedPrng();
}
