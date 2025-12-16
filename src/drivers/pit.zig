// Home OS - PIT (Programmable Interval Timer) Driver
// Copyright © 2025 Romy Rianata - Home OS
// 8253/8254 PIT for system timing

const io = @import("../arch/io.zig");
const serial = @import("serial.zig");

// PIT ports
const PIT_CHANNEL0: u16 = 0x40; // Channel 0 data port (system timer)
const PIT_CHANNEL1: u16 = 0x41; // Channel 1 data port (RAM refresh - obsolete)
const PIT_CHANNEL2: u16 = 0x42; // Channel 2 data port (PC speaker)
const PIT_COMMAND: u16 = 0x43; // Command register

// PIT frequency: 1.193182 MHz
const PIT_FREQUENCY: u32 = 1193182;

// Desired tick rate (Hz)
pub const TICK_RATE: u32 = 100; // 100 Hz = 10ms per tick

// Tick counter (use u32 to avoid 64-bit operations on 32-bit CPU)
var ticks: u32 = 0;
var tick_counter: u32 = 0; // Counter for seconds calculation
var seconds: u32 = 0;

// CPU usage tracking
var idle_ticks: u32 = 0; // Total idle calls since boot
var sample_ticks: u32 = 0; // Ticks in current sample period
var busy_ticks: u32 = 0; // Ticks where work was done in current sample
var cpu_usage: u8 = 0; // CPU usage percentage (0-100)
var was_busy: bool = false; // Flag set when work is done between ticks
const SAMPLE_PERIOD: u32 = 100; // Sample every 100 ticks (1 second at 100Hz)

// Initialize PIT
pub fn init() void {
    serial.write("PIT: Initializing timer...\n");

    // Calculate divisor for desired frequency
    const divisor: u16 = @truncate(PIT_FREQUENCY / TICK_RATE);

    serial.write("PIT: Frequency = ");
    serial.writeInt(TICK_RATE);
    serial.write(" Hz (divisor = ");
    serial.writeInt(divisor);
    serial.write(")\n");

    // Command byte:
    // Bits 7-6: Channel (00 = Channel 0)
    // Bits 5-4: Access mode (11 = lobyte/hibyte)
    // Bits 3-1: Operating mode (011 = Mode 3, Square Wave Generator)
    // Bit 0: BCD/Binary (0 = Binary)
    // Result: 00110110b = 0x36
    io.outb(PIT_COMMAND, 0x36);

    // Send divisor (low byte, then high byte)
    io.outb(PIT_CHANNEL0, @truncate(divisor & 0xFF));
    io.outb(PIT_CHANNEL0, @truncate((divisor >> 8) & 0xFF));

    serial.write("PIT: Timer initialized\n");
}

// Handle timer tick (called from IRQ0 handler)
pub fn handleTick() void {
    ticks +%= 1; // Use wrapping add to avoid overflow issues
    tick_counter += 1;
    sample_ticks += 1;

    // Update seconds counter every TICK_RATE ticks
    if (tick_counter >= TICK_RATE) {
        tick_counter = 0;
        seconds +%= 1;
    }

    // Track if this tick had work done
    if (was_busy) {
        busy_ticks += 1;
        was_busy = false;
    }

    // Calculate CPU usage every sample period
    if (sample_ticks >= SAMPLE_PERIOD) {
        // CPU usage = percentage of ticks where work was done
        if (sample_ticks > 0) {
            cpu_usage = @truncate((@as(u64, busy_ticks) * 100) / @as(u64, sample_ticks));
        }
        sample_ticks = 0;
        busy_ticks = 0;
    }
}

/// Called when CPU enters idle state (HLT instruction)
pub fn markIdle() void {
    idle_ticks +%= 1;
}

/// Called when CPU does work (not idle)
pub fn markBusy() void {
    was_busy = true;
}

// Get tick count
pub fn getTicks() u32 {
    return ticks;
}

// Get uptime in seconds
pub fn getUptime() u32 {
    return seconds;
}

// Sleep for specified number of ticks
pub fn sleep(tick_count: u32) void {
    const target = ticks +% tick_count;
    while (ticks != target) {
        asm volatile ("hlt");
    }
}

// Sleep for milliseconds
pub fn sleepMs(ms: u32) void {
    const tick_count = (ms * TICK_RATE) / 1000;
    sleep(tick_count);
}

// Get milliseconds since boot
pub fn getMilliseconds() u32 {
    return (ticks * 1000) / TICK_RATE;
}

/// Get CPU usage percentage (0-100)
pub fn getCpuUsage() u8 {
    return cpu_usage;
}

/// Get total idle ticks since boot
pub fn getIdleTicks() u32 {
    return idle_ticks;
}
