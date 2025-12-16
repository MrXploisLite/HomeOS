// Home OS - Audio Manager
// Copyright © 2025 Romy Rianata - Home OS
// Phase 15: Audio System

const serial = @import("serial.zig");
const pcspk = @import("pcspk.zig");
const sb16 = @import("sb16.zig");

pub const AudioDevice = enum {
    none,
    pc_speaker,
    sound_blaster,
};

var active_device: AudioDevice = .none;
var initialized: bool = false;

/// Initialize audio system
pub fn init() bool {
    serial.write("Audio: Initializing audio system...\n");

    // Initialize PC Speaker (always available)
    pcspk.init();
    active_device = .pc_speaker;

    // Try to initialize Sound Blaster 16
    if (sb16.init()) {
        active_device = .sound_blaster;
        serial.write("Audio: Using Sound Blaster 16\n");
    } else {
        serial.write("Audio: Using PC Speaker (fallback)\n");
    }

    initialized = true;
    serial.write("Audio: Ready\n");
    return true;
}

/// Check if initialized
pub fn isInitialized() bool {
    return initialized;
}

/// Get active audio device
pub fn getActiveDevice() AudioDevice {
    return active_device;
}

/// Check if Sound Blaster is available
pub fn hasSoundBlaster() bool {
    return active_device == .sound_blaster;
}

/// Get device name
pub fn getDeviceName() []const u8 {
    return switch (active_device) {
        .none => "None",
        .pc_speaker => "PC Speaker",
        .sound_blaster => "Sound Blaster 16",
    };
}

/// Play a tone (uses PC Speaker) - BLOCKING
pub fn playTone(frequency: u32, duration_ticks: u32) void {
    pcspk.beep(frequency, duration_ticks);
}

/// Play a non-blocking tone (for UI sounds)
pub fn playToneAsync(frequency: u32, duration_ticks: u32) void {
    pcspk.playAsync(frequency, duration_ticks);
}

/// Update async audio (call in main loop)
pub fn updateAsync() void {
    pcspk.updateAsync();
}

/// Play standard beep
pub fn beep() void {
    pcspk.standardBeep();
}

/// Play startup sound
pub fn playStartup() void {
    pcspk.playStartupSound();
}

/// Play error sound
pub fn playError() void {
    pcspk.playErrorSound();
}

/// Play 8-bit PCM audio (requires Sound Blaster)
pub fn playPcm(data: []const u8, sample_rate: u32) bool {
    if (active_device == .sound_blaster) {
        return sb16.play8bit(data, sample_rate);
    }
    serial.write("Audio: PCM playback requires Sound Blaster\n");
    return false;
}

/// Stop audio playback
pub fn stop() void {
    pcspk.stop();
    if (active_device == .sound_blaster) {
        sb16.stop();
    }
}

/// Set volume (Sound Blaster only)
pub fn setVolume(volume: u8) void {
    if (active_device == .sound_blaster) {
        sb16.setVolume(volume);
    }
}

/// Get volume
pub fn getVolume() u8 {
    if (active_device == .sound_blaster) {
        return sb16.getVolume();
    }
    return 0;
}

/// Check if audio is playing
pub fn isPlaying() bool {
    if (pcspk.isPlaying()) return true;
    if (active_device == .sound_blaster and sb16.isPlaying()) return true;
    return false;
}

/// Handle audio interrupt (for Sound Blaster)
pub fn handleInterrupt() void {
    if (active_device == .sound_blaster) {
        sb16.handleInterrupt();
    }
}

// Re-export note constants for convenience
pub const NOTE_C4 = pcspk.NOTE_C4;
pub const NOTE_D4 = pcspk.NOTE_D4;
pub const NOTE_E4 = pcspk.NOTE_E4;
pub const NOTE_F4 = pcspk.NOTE_F4;
pub const NOTE_G4 = pcspk.NOTE_G4;
pub const NOTE_A4 = pcspk.NOTE_A4;
pub const NOTE_B4 = pcspk.NOTE_B4;
pub const NOTE_C5 = pcspk.NOTE_C5;
pub const NOTE_D5 = pcspk.NOTE_D5;
pub const NOTE_E5 = pcspk.NOTE_E5;
pub const NOTE_F5 = pcspk.NOTE_F5;
pub const NOTE_G5 = pcspk.NOTE_G5;
pub const NOTE_A5 = pcspk.NOTE_A5;
pub const NOTE_REST = pcspk.NOTE_REST;
pub const Note = pcspk.Note;

/// Play a melody
pub fn playMelody(notes: []const Note) void {
    pcspk.playMelody(notes);
}

/// Demo: Play a simple tune
pub fn playDemo() void {
    serial.write("Audio: Playing demo melody...\n");

    // Simple melody: C-E-G-C (arpeggio)
    const melody = [_]Note{
        .{ .frequency = NOTE_C4, .duration = 10 },
        .{ .frequency = NOTE_E4, .duration = 10 },
        .{ .frequency = NOTE_G4, .duration = 10 },
        .{ .frequency = NOTE_C5, .duration = 20 },
        .{ .frequency = NOTE_REST, .duration = 5 },
        .{ .frequency = NOTE_G4, .duration = 10 },
        .{ .frequency = NOTE_E4, .duration = 10 },
        .{ .frequency = NOTE_C4, .duration = 20 },
    };

    playMelody(&melody);
    serial.write("Audio: Demo complete\n");
}

/// Generate a simple square wave for testing
pub fn generateTestTone(buffer: []u8, frequency: u32, sample_rate: u32) void {
    const samples_per_cycle = sample_rate / frequency;
    const half_cycle = samples_per_cycle / 2;

    var i: usize = 0;
    var cycle_pos: usize = 0;

    while (i < buffer.len) : (i += 1) {
        // Square wave: high for half cycle, low for half cycle
        buffer[i] = if (cycle_pos < half_cycle) 0xFF else 0x00;

        cycle_pos += 1;
        if (cycle_pos >= samples_per_cycle) {
            cycle_pos = 0;
        }
    }
}
