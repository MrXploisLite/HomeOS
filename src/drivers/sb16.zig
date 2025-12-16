// Home OS - Sound Blaster 16 Driver
// Copyright © 2025 Romy Rianata - Home OS
// Phase 15: Audio System

const io = @import("../arch/io.zig");
const serial = @import("serial.zig");
const pic = @import("../arch/pic.zig");
const heap = @import("../mm/heap.zig");

// Sound Blaster 16 I/O ports (base 0x220)
const SB_BASE: u16 = 0x220;
const SB_MIXER_ADDR: u16 = SB_BASE + 0x04;
const SB_MIXER_DATA: u16 = SB_BASE + 0x05;
const SB_RESET: u16 = SB_BASE + 0x06;
const SB_READ: u16 = SB_BASE + 0x0A;
const SB_WRITE: u16 = SB_BASE + 0x0C;
const SB_WRITE_STATUS: u16 = SB_BASE + 0x0C;
const SB_READ_STATUS: u16 = SB_BASE + 0x0E;
const SB_INT_ACK_16: u16 = SB_BASE + 0x0F;

// DMA ports
const DMA_MASK_REG: u16 = 0x0A;
const DMA_MODE_REG: u16 = 0x0B;
const DMA_CLEAR_FF: u16 = 0x0C;

// DMA channel 1 (8-bit) ports
const DMA1_ADDR: u16 = 0x02;
const DMA1_COUNT: u16 = 0x03;
const DMA1_PAGE: u16 = 0x83;

// DMA channel 5 (16-bit) ports
const DMA5_ADDR: u16 = 0xC4;
const DMA5_COUNT: u16 = 0xC6;
const DMA5_PAGE: u16 = 0x8B;

// DSP commands
const DSP_SET_TIME_CONST: u8 = 0x40;
const DSP_SET_SAMPLE_RATE: u8 = 0x41;
const DSP_SPEAKER_ON: u8 = 0xD1;
const DSP_SPEAKER_OFF: u8 = 0xD3;
const DSP_STOP_8BIT: u8 = 0xD0;
const DSP_RESUME_8BIT: u8 = 0xD4;
const DSP_STOP_16BIT: u8 = 0xD5;
const DSP_RESUME_16BIT: u8 = 0xD6;
const DSP_GET_VERSION: u8 = 0xE1;

// DSP playback commands
const DSP_PLAY_8BIT: u8 = 0xC0; // 8-bit single cycle
const DSP_PLAY_8BIT_AUTO: u8 = 0xC6; // 8-bit auto-init
const DSP_PLAY_16BIT: u8 = 0xB0; // 16-bit single cycle
const DSP_PLAY_16BIT_AUTO: u8 = 0xB6; // 16-bit auto-init

// Mixer registers
const MIXER_MASTER_VOL: u8 = 0x22;
const MIXER_VOICE_VOL: u8 = 0x04;
const MIXER_IRQ_SETUP: u8 = 0x80;
const MIXER_DMA_SETUP: u8 = 0x81;
const MIXER_IRQ_STATUS: u8 = 0x82;

// Audio buffer
const AUDIO_BUFFER_SIZE: usize = 32768; // 32KB buffer
var audio_buffer: ?[*]u8 = null;
var buffer_physical: u32 = 0;

var initialized: bool = false;
var dsp_version_major: u8 = 0;
var dsp_version_minor: u8 = 0;
var current_sample_rate: u32 = 22050;
var is_playing: bool = false;

/// Reset DSP
fn resetDsp() bool {
    // Write 1 to reset port
    io.outb(SB_RESET, 1);

    // Wait ~3 microseconds
    var i: u32 = 0;
    while (i < 100) : (i += 1) {
        _ = io.inb(SB_RESET);
    }

    // Write 0 to reset port
    io.outb(SB_RESET, 0);

    // Wait for ready (0xAA)
    var timeout: u32 = 0;
    while (timeout < 1000) : (timeout += 1) {
        if ((io.inb(SB_READ_STATUS) & 0x80) != 0) {
            if (io.inb(SB_READ) == 0xAA) {
                return true;
            }
        }
    }

    return false;
}

/// Write to DSP
fn writeDsp(value: u8) void {
    // Wait until DSP is ready to receive
    while ((io.inb(SB_WRITE_STATUS) & 0x80) != 0) {}
    io.outb(SB_WRITE, value);
}

/// Read from DSP
fn readDsp() u8 {
    // Wait until data is available
    while ((io.inb(SB_READ_STATUS) & 0x80) == 0) {}
    return io.inb(SB_READ);
}

/// Set mixer register
fn setMixer(reg: u8, value: u8) void {
    io.outb(SB_MIXER_ADDR, reg);
    io.outb(SB_MIXER_DATA, value);
}

/// Get mixer register
fn getMixer(reg: u8) u8 {
    io.outb(SB_MIXER_ADDR, reg);
    return io.inb(SB_MIXER_DATA);
}

/// Initialize Sound Blaster 16
pub fn init() bool {
    serial.write("SB16: Initializing Sound Blaster 16...\n");

    // Reset DSP
    if (!resetDsp()) {
        serial.write("SB16: DSP reset failed - no Sound Blaster found\n");
        return false;
    }

    // Get DSP version
    writeDsp(DSP_GET_VERSION);
    dsp_version_major = readDsp();
    dsp_version_minor = readDsp();

    serial.write("SB16: DSP version ");
    serial.writeInt(@as(u32, dsp_version_major));
    serial.write(".");
    serial.writeInt(@as(u32, dsp_version_minor));
    serial.write("\n");

    // Check for SB16 (version 4.x)
    if (dsp_version_major < 4) {
        serial.write("SB16: Warning - older Sound Blaster detected\n");
    }

    // Allocate DMA buffer (must be in lower 16MB and not cross 64K boundary)
    audio_buffer = heap.alloc(AUDIO_BUFFER_SIZE);
    if (audio_buffer == null) {
        serial.write("SB16: Failed to allocate audio buffer\n");
        return false;
    }
    buffer_physical = @intFromPtr(audio_buffer);

    // Check DMA boundary (buffer must not cross 64K boundary)
    const buffer_end = buffer_physical + AUDIO_BUFFER_SIZE - 1;
    if ((buffer_physical & 0xFFFF0000) != (buffer_end & 0xFFFF0000)) {
        serial.write("SB16: Warning - buffer crosses 64K boundary\n");
    }

    // Set IRQ 5 for Sound Blaster
    setMixer(MIXER_IRQ_SETUP, 0x02); // IRQ 5

    // Set DMA channels (1 for 8-bit, 5 for 16-bit)
    setMixer(MIXER_DMA_SETUP, 0x22); // DMA 1 and 5

    // Set master volume to max
    setMixer(MIXER_MASTER_VOL, 0xFF);
    setMixer(MIXER_VOICE_VOL, 0xFF);

    // Enable speaker
    writeDsp(DSP_SPEAKER_ON);

    // Enable IRQ5
    pic.clearMask(5);

    initialized = true;
    serial.write("SB16: Initialized successfully\n");
    return true;
}

/// Set sample rate
pub fn setSampleRate(rate: u32) void {
    if (!initialized) return;

    current_sample_rate = rate;

    // For SB16, use direct sample rate command
    if (dsp_version_major >= 4) {
        writeDsp(DSP_SET_SAMPLE_RATE);
        writeDsp(@truncate((rate >> 8) & 0xFF));
        writeDsp(@truncate(rate & 0xFF));
    } else {
        // For older cards, use time constant
        const time_const: u8 = @truncate(256 - (1000000 / rate));
        writeDsp(DSP_SET_TIME_CONST);
        writeDsp(time_const);
    }
}

/// Setup DMA for 8-bit playback
fn setupDma8(length: u32) void {
    const addr = buffer_physical;
    const count = length - 1;

    // Disable DMA channel 1
    io.outb(DMA_MASK_REG, 0x05); // Mask channel 1

    // Clear flip-flop
    io.outb(DMA_CLEAR_FF, 0);

    // Set mode: single mode, address increment, auto-init, read (playback)
    io.outb(DMA_MODE_REG, 0x59); // Channel 1, single, auto-init, read

    // Set address
    io.outb(DMA1_ADDR, @truncate(addr & 0xFF));
    io.outb(DMA1_ADDR, @truncate((addr >> 8) & 0xFF));
    io.outb(DMA1_PAGE, @truncate((addr >> 16) & 0xFF));

    // Set count
    io.outb(DMA1_COUNT, @truncate(count & 0xFF));
    io.outb(DMA1_COUNT, @truncate((count >> 8) & 0xFF));

    // Enable DMA channel 1
    io.outb(DMA_MASK_REG, 0x01); // Unmask channel 1
}

/// Play 8-bit unsigned PCM audio
pub fn play8bit(data: []const u8, sample_rate: u32) bool {
    if (!initialized) return false;
    if (data.len > AUDIO_BUFFER_SIZE) return false;

    // Copy data to DMA buffer
    for (data, 0..) |byte, i| {
        audio_buffer.?[i] = byte;
    }

    // Set sample rate
    setSampleRate(sample_rate);

    // Setup DMA
    setupDma8(@truncate(data.len));

    // Start playback
    // Command format: C0 + mode bits
    // Mode: bit 4 = signed (0=unsigned), bit 5 = stereo (0=mono)
    writeDsp(DSP_PLAY_8BIT);
    writeDsp(0x00); // Mode: unsigned mono
    writeDsp(@truncate((data.len - 1) & 0xFF));
    writeDsp(@truncate(((data.len - 1) >> 8) & 0xFF));

    is_playing = true;
    serial.write("SB16: Playing 8-bit audio (");
    serial.writeInt(@truncate(data.len));
    serial.write(" bytes)\n");

    return true;
}

/// Stop playback
pub fn stop() void {
    if (!initialized) return;

    writeDsp(DSP_STOP_8BIT);
    writeDsp(DSP_SPEAKER_OFF);
    is_playing = false;
}

/// Resume playback
pub fn resumePlayback() void {
    if (!initialized) return;

    writeDsp(DSP_SPEAKER_ON);
    writeDsp(DSP_RESUME_8BIT);
    is_playing = true;
}

/// Handle IRQ (called from interrupt handler)
pub fn handleInterrupt() void {
    // Acknowledge interrupt
    _ = io.inb(SB_READ_STATUS); // 8-bit ack

    serial.write("SB16: IRQ\n");
    is_playing = false;
}

/// Check if initialized
pub fn isInitialized() bool {
    return initialized;
}

/// Check if playing
pub fn isPlaying() bool {
    return is_playing;
}

/// Get DSP version
pub fn getVersion() struct { major: u8, minor: u8 } {
    return .{ .major = dsp_version_major, .minor = dsp_version_minor };
}

/// Set master volume (0-255)
pub fn setVolume(volume: u8) void {
    if (!initialized) return;
    setMixer(MIXER_MASTER_VOL, volume);
}

/// Get master volume
pub fn getVolume() u8 {
    if (!initialized) return 0;
    return getMixer(MIXER_MASTER_VOL);
}
