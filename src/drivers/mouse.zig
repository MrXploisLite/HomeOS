// Home OS - PS/2 Mouse Driver
// Copyright © 2025 Romy Rianata - Home OS
// Phase 14: Graphics & Display

const serial = @import("serial.zig");
const io = @import("../arch/io.zig");
const pic = @import("../arch/pic.zig");
const isr = @import("../arch/isr.zig");

// PS/2 Controller ports
const PS2_DATA: u16 = 0x60;
const PS2_STATUS: u16 = 0x64;
const PS2_COMMAND: u16 = 0x64;

// PS/2 Controller commands
const PS2_CMD_READ_CONFIG: u8 = 0x20;
const PS2_CMD_WRITE_CONFIG: u8 = 0x60;
const PS2_CMD_DISABLE_MOUSE: u8 = 0xA7;
const PS2_CMD_ENABLE_MOUSE: u8 = 0xA8;
const PS2_CMD_TEST_MOUSE: u8 = 0xA9;
const PS2_CMD_WRITE_MOUSE: u8 = 0xD4;

// Mouse commands
const MOUSE_CMD_RESET: u8 = 0xFF;
const MOUSE_CMD_RESEND: u8 = 0xFE;
const MOUSE_CMD_SET_DEFAULTS: u8 = 0xF6;
const MOUSE_CMD_DISABLE_STREAMING: u8 = 0xF5;
const MOUSE_CMD_ENABLE_STREAMING: u8 = 0xF4;
const MOUSE_CMD_SET_SAMPLE_RATE: u8 = 0xF3;
const MOUSE_CMD_GET_DEVICE_ID: u8 = 0xF2;
const MOUSE_CMD_SET_RESOLUTION: u8 = 0xE8;

// Mouse responses
const MOUSE_ACK: u8 = 0xFA;
const MOUSE_RESEND: u8 = 0xFE;

// Mouse state
pub const MouseState = struct {
    x: i32,
    y: i32,
    buttons: u8,
    left: bool,
    right: bool,
    middle: bool,
    scroll: i8, // Scroll wheel delta (positive = up, negative = down)
};

var mouse_state: MouseState = MouseState{
    .x = 400,
    .y = 300,
    .buttons = 0,
    .left = false,
    .right = false,
    .middle = false,
    .scroll = 0,
};

var screen_width: i32 = 800;
var screen_height: i32 = 600;

var packet: [4]u8 = [_]u8{0} ** 4;
var packet_index: u8 = 0;
var packet_size: u8 = 3; // 3 for standard, 4 for scroll wheel
var initialized: bool = false;
var has_scroll_wheel: bool = false;

// Scroll event queue - accumulates scroll events between polls
const SCROLL_QUEUE_SIZE: usize = 32;
var scroll_queue: [SCROLL_QUEUE_SIZE]i8 = [_]i8{0} ** SCROLL_QUEUE_SIZE;
var scroll_queue_head: usize = 0;
var scroll_queue_tail: usize = 0;
var scroll_queue_count: usize = 0;

// Accumulated scroll delta (for smooth scrolling)
var accumulated_scroll: i32 = 0;

// Callback for mouse events
pub const MouseCallback = *const fn (state: *const MouseState) void;
var mouse_callback: ?MouseCallback = null;

fn waitInput() void {
    var timeout: u32 = 100000;
    while (timeout > 0) : (timeout -= 1) {
        if ((io.inb(PS2_STATUS) & 2) == 0) return;
    }
}

fn waitOutput() void {
    var timeout: u32 = 100000;
    while (timeout > 0) : (timeout -= 1) {
        if ((io.inb(PS2_STATUS) & 1) != 0) return;
    }
}

fn sendCommand(cmd: u8) void {
    waitInput();
    io.outb(PS2_COMMAND, cmd);
}

fn sendData(data: u8) void {
    waitInput();
    io.outb(PS2_DATA, data);
}

fn readData() u8 {
    waitOutput();
    return io.inb(PS2_DATA);
}

fn mouseWrite(data: u8) void {
    sendCommand(PS2_CMD_WRITE_MOUSE);
    sendData(data);
}

fn mouseRead() u8 {
    return readData();
}

pub fn init() bool {
    serial.write("Mouse: Initializing...\n");

    // Enable auxiliary device (mouse port)
    sendCommand(PS2_CMD_ENABLE_MOUSE);

    // Read and modify controller config
    sendCommand(PS2_CMD_READ_CONFIG);
    var config = readData();

    // Enable IRQ12 (bit 1) and enable mouse clock (clear bit 5)
    config |= 0x02;
    config &= ~@as(u8, 0x20);
    sendCommand(PS2_CMD_WRITE_CONFIG);
    sendData(config);

    // Set defaults
    mouseWrite(MOUSE_CMD_SET_DEFAULTS);
    _ = mouseRead();

    // Try to enable scroll wheel (IntelliMouse mode)
    // Magic sequence: set sample rate 200, 100, 80, then get device ID
    mouseWrite(MOUSE_CMD_SET_SAMPLE_RATE);
    _ = mouseRead();
    mouseWrite(200);
    _ = mouseRead();
    mouseWrite(MOUSE_CMD_SET_SAMPLE_RATE);
    _ = mouseRead();
    mouseWrite(100);
    _ = mouseRead();
    mouseWrite(MOUSE_CMD_SET_SAMPLE_RATE);
    _ = mouseRead();
    mouseWrite(80);
    _ = mouseRead();

    // Get device ID to check if scroll wheel enabled
    mouseWrite(MOUSE_CMD_GET_DEVICE_ID);
    _ = mouseRead(); // ACK
    const device_id = mouseRead();

    if (device_id == 0x03) {
        has_scroll_wheel = true;
        packet_size = 4;
    } else {
        has_scroll_wheel = false;
        packet_size = 3;
    }

    // Enable data reporting
    mouseWrite(MOUSE_CMD_ENABLE_STREAMING);
    _ = mouseRead();

    // Enable IRQ12 in PIC
    pic.clearMask(12);

    initialized = true;
    serial.write("Mouse: Ready\n");
    return true;
}

pub fn setScreenSize(width: i32, height: i32) void {
    screen_width = width;
    screen_height = height;
    // Center mouse
    mouse_state.x = @divTrunc(width, 2);
    mouse_state.y = @divTrunc(height, 2);
}

pub fn setCallback(callback: MouseCallback) void {
    mouse_callback = callback;
}

pub fn handleInterrupt() void {
    const data = io.inb(PS2_DATA);

    // First byte must have bit 3 set (always 1)
    if (packet_index == 0 and (data & 0x08) == 0) {
        // Out of sync, discard
        return;
    }

    packet[packet_index] = data;
    packet_index += 1;

    if (packet_index >= packet_size) {
        packet_index = 0;
        processPacket();
    }
}

fn processPacket() void {
    const flags = packet[0];
    var dx: i32 = @as(i32, packet[1]);
    var dy: i32 = @as(i32, packet[2]);

    // Handle sign extension (negative values)
    if ((flags & 0x10) != 0) dx -= 256;
    if ((flags & 0x20) != 0) dy -= 256;

    // Check for overflow
    if ((flags & 0x40) != 0) dx = 0;
    if ((flags & 0x80) != 0) dy = 0;

    // Update position (Y is inverted)
    mouse_state.x += dx;
    mouse_state.y -= dy;

    // Clamp to screen bounds
    if (mouse_state.x < 0) mouse_state.x = 0;
    if (mouse_state.y < 0) mouse_state.y = 0;
    if (mouse_state.x >= screen_width) mouse_state.x = screen_width - 1;
    if (mouse_state.y >= screen_height) mouse_state.y = screen_height - 1;

    // Update buttons
    mouse_state.buttons = flags & 0x07;
    mouse_state.left = (flags & 0x01) != 0;
    mouse_state.right = (flags & 0x02) != 0;
    mouse_state.middle = (flags & 0x04) != 0;

    // Handle scroll wheel (4th byte if present)
    if (has_scroll_wheel and packet_size == 4) {
        // Scroll wheel is signed 8-bit value (two's complement)
        const scroll_raw = packet[3];
        if (scroll_raw != 0) {
            var scroll_delta: i8 = 0;
            // Convert to signed (two's complement)
            if (scroll_raw > 127) {
                scroll_delta = -@as(i8, @intCast(256 - @as(u16, scroll_raw)));
            } else {
                scroll_delta = @as(i8, @intCast(scroll_raw));
            }

            // Store in current state
            mouse_state.scroll = scroll_delta;

            // Add to scroll queue for event-based handling
            if (scroll_queue_count < SCROLL_QUEUE_SIZE) {
                scroll_queue[scroll_queue_tail] = scroll_delta;
                scroll_queue_tail = (scroll_queue_tail + 1) % SCROLL_QUEUE_SIZE;
                scroll_queue_count += 1;
            }

            // Accumulate for smooth scrolling
            accumulated_scroll += @as(i32, scroll_delta);
        } else {
            mouse_state.scroll = 0;
        }
    } else {
        mouse_state.scroll = 0;
    }

    // Call callback if set
    if (mouse_callback) |callback| {
        callback(&mouse_state);
    }
}

pub fn getState() *const MouseState {
    return &mouse_state;
}

pub fn getX() i32 {
    return mouse_state.x;
}

pub fn getY() i32 {
    return mouse_state.y;
}

pub fn isLeftPressed() bool {
    return mouse_state.left;
}

pub fn isRightPressed() bool {
    return mouse_state.right;
}

pub fn isMiddlePressed() bool {
    return mouse_state.middle;
}

pub fn isInitialized() bool {
    return initialized;
}

pub fn hasScrollWheel() bool {
    return has_scroll_wheel;
}

/// Get next scroll event from queue (returns 0 if empty)
pub fn getScrollEvent() i8 {
    if (scroll_queue_count == 0) return 0;

    const scroll = scroll_queue[scroll_queue_head];
    scroll_queue_head = (scroll_queue_head + 1) % SCROLL_QUEUE_SIZE;
    scroll_queue_count -= 1;
    return scroll;
}

/// Check if there are pending scroll events
pub fn hasScrollEvents() bool {
    return scroll_queue_count > 0;
}

/// Get accumulated scroll and reset (for smooth scrolling)
pub fn getAccumulatedScroll() i32 {
    const scroll = accumulated_scroll;
    accumulated_scroll = 0;
    return scroll;
}

/// Get current scroll delta (may be 0 if no recent scroll)
pub fn getScroll() i8 {
    return mouse_state.scroll;
}

/// Clear all pending scroll events
pub fn clearScrollEvents() void {
    scroll_queue_head = 0;
    scroll_queue_tail = 0;
    scroll_queue_count = 0;
    accumulated_scroll = 0;
    mouse_state.scroll = 0;
}

/// Get number of pending scroll events
pub fn getScrollEventCount() usize {
    return scroll_queue_count;
}
