// Home OS - PC Speaker Driver
// Copyright © 2025 Romy Rianata - Home OS
// Phase 15: Audio System

const io = @import("../arch/io.zig");
const pit = @import("pit.zig");
const serial = @import("serial.zig");

// PC Speaker uses PIT Channel 2
const PIT_CHANNEL2: u16 = 0x42;
const PIT_COMMAND: u16 = 0x43;
const SPEAKER_PORT: u16 = 0x61;

// PIT base frequency
const PIT_FREQUENCY: u32 = 1193182;

var speaker_enabled: bool = false;
var current_frequency: u32 = 0;

/// Initialize PC Speaker
pub fn init() void {
    serial.write("PC Speaker: Initializing...\n");
    stop();
    serial.write("PC Speaker: Ready\n");
}

/// Play a tone at specified frequency (Hz)
pub fn play(frequency: u32) void {
    if (frequency == 0) {
        stop();
        return;
    }

    // Calculate divisor for PIT
    const divisor: u32 = PIT_FREQUENCY / frequency;

    // Configure PIT Channel 2 for square wave
    // Command: Channel 2, lobyte/hibyte, mode 3 (square wave), binary
    io.outb(PIT_COMMAND, 0xB6);

    // Set frequency divisor
    io.outb(PIT_CHANNEL2, @truncate(divisor & 0xFF));
    io.outb(PIT_CHANNEL2, @truncate((divisor >> 8) & 0xFF));

    // Enable speaker (bits 0 and 1 of port 0x61)
    const tmp = io.inb(SPEAKER_PORT);
    if ((tmp & 3) != 3) {
        io.outb(SPEAKER_PORT, tmp | 3);
    }

    speaker_enabled = true;
    current_frequency = frequency;
}

/// Stop playing
pub fn stop() void {
    // Disable speaker (clear bits 0 and 1)
    const tmp = io.inb(SPEAKER_PORT);
    io.outb(SPEAKER_PORT, tmp & 0xFC);

    speaker_enabled = false;
    current_frequency = 0;
}

/// Check if speaker is playing
pub fn isPlaying() bool {
    return speaker_enabled;
}

/// Get current frequency
pub fn getFrequency() u32 {
    return current_frequency;
}

/// Play a beep for specified duration (in timer ticks, ~10ms each) - BLOCKING
pub fn beep(frequency: u32, duration_ticks: u32) void {
    play(frequency);

    // Wait for duration
    const start = pit.getTicks();
    while (pit.getTicks() - start < duration_ticks) {
        asm volatile ("hlt");
    }

    stop();
}

// Non-blocking tone state
var async_end_tick: u32 = 0;
var async_active: bool = false;

/// Start a non-blocking tone (call updateAsync() to stop it)
pub fn playAsync(frequency: u32, duration_ticks: u32) void {
    if (frequency == 0 or duration_ticks == 0) return;
    play(frequency);
    async_end_tick = pit.getTicks() +% duration_ticks;
    async_active = true;
}

/// Update async tone - call this periodically (e.g., in main loop)
pub fn updateAsync() void {
    if (async_active and pit.getTicks() >= async_end_tick) {
        stop();
        async_active = false;
    }
}

/// Check if async tone is playing
pub fn isAsyncPlaying() bool {
    return async_active;
}

/// Play standard beep (1000 Hz for 300ms - longer for audibility)
pub fn standardBeep() void {
    beep(1000, 30);
}

// Musical note frequencies (octave 4)
pub const NOTE_C4: u32 = 262;
pub const NOTE_CS4: u32 = 277;
pub const NOTE_D4: u32 = 294;
pub const NOTE_DS4: u32 = 311;
pub const NOTE_E4: u32 = 330;
pub const NOTE_F4: u32 = 349;
pub const NOTE_FS4: u32 = 370;
pub const NOTE_G4: u32 = 392;
pub const NOTE_GS4: u32 = 415;
pub const NOTE_A4: u32 = 440;
pub const NOTE_AS4: u32 = 466;
pub const NOTE_B4: u32 = 494;
pub const NOTE_C5: u32 = 523;
pub const NOTE_D5: u32 = 587;
pub const NOTE_E5: u32 = 659;
pub const NOTE_F5: u32 = 698;
pub const NOTE_G5: u32 = 784;
pub const NOTE_A5: u32 = 880;
pub const NOTE_REST: u32 = 0;

/// Note structure for melodies
pub const Note = struct {
    frequency: u32,
    duration: u32, // in ticks (~10ms each)
};

/// Play a melody (array of notes)
pub fn playMelody(notes: []const Note) void {
    for (notes) |note| {
        if (note.frequency == NOTE_REST) {
            stop();
        } else {
            play(note.frequency);
        }

        // Wait for note duration
        const start = pit.getTicks();
        while (pit.getTicks() - start < note.duration) {
            asm volatile ("hlt");
        }
    }
    stop();
}

/// Startup sound
pub fn playStartupSound() void {
    const melody = [_]Note{
        .{ .frequency = NOTE_C5, .duration = 5 },
        .{ .frequency = NOTE_E5, .duration = 5 },
        .{ .frequency = NOTE_G5, .duration = 10 },
    };
    playMelody(&melody);
}

/// Error sound
pub fn playErrorSound() void {
    const melody = [_]Note{
        .{ .frequency = 200, .duration = 10 },
        .{ .frequency = 150, .duration = 15 },
    };
    playMelody(&melody);
}
