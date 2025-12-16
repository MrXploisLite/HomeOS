// Home OS - PS/2 Keyboard Driver
// Copyright © 2025 Romy Rianata - Home OS

const io = @import("../arch/io.zig");

// Keyboard ports
const KEYBOARD_DATA: u16 = 0x60;
const KEYBOARD_STATUS: u16 = 0x64;

// US keyboard scancode to ASCII (set 1, lowercase only for now)
// Scancode 0x01 = ESC (ASCII 27)
const scancode_to_ascii = [_]u8{
    0, 27, '1', '2', '3', '4', '5', '6', // 0x00-0x07 (ESC=27)
    '7', '8', '9', '0', '-', '=', 8, '\t', // 0x08-0x0F (backspace=8, tab)
    'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', // 0x10-0x17
    'o', 'p', '[', ']', '\n', 0, 'a', 's', // 0x18-0x1F (enter, ctrl)
    'd', 'f', 'g', 'h', 'j', 'k', 'l', ';', // 0x20-0x27
    '\'', '`', 0, '\\', 'z', 'x', 'c', 'v', // 0x28-0x2F (lshift)
    'b', 'n', 'm', ',', '.', '/', 0, '*', // 0x30-0x37 (rshift)
    0, ' ', 0, 0, 0, 0, 0, 0, // 0x38-0x3F (alt, space, caps, F1-F3)
    0, 0, 0, 0, 0, 0, 0, '7', // 0x40-0x47 (F4-F10, numlock, scroll, numpad7)
    '8', '9', '-', '4', '5', '6', '+', '1', // 0x48-0x4F (numpad)
    '2', '3', '0', '.', 0, 0, 0, 0, // 0x50-0x57
    0, 0, 0, 0, 0, 0, 0, 0, // 0x58-0x5F
};

// Shift key scancode to ASCII
const scancode_to_ascii_shift = [_]u8{
    0, 27, '!', '@', '#', '$', '%', '^', // 0x00-0x07 (ESC=27)
    '&', '*', '(', ')', '_', '+', 8, '\t', // 0x08-0x0F
    'Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', // 0x10-0x17
    'O', 'P', '{', '}', '\n', 0, 'A', 'S', // 0x18-0x1F
    'D', 'F', 'G', 'H', 'J', 'K', 'L', ':', // 0x20-0x27
    '"', '~', 0, '|', 'Z', 'X', 'C', 'V', // 0x28-0x2F
    'B', 'N', 'M', '<', '>', '?', 0, '*', // 0x30-0x37
    0, ' ', 0, 0, 0, 0, 0, 0, // 0x38-0x3F
    0, 0, 0, 0, 0, 0, 0, '7', // 0x40-0x47
    '8', '9', '-', '4', '5', '6', '+', '1', // 0x48-0x4F
    '2', '3', '0', '.', 0, 0, 0, 0, // 0x50-0x57
    0, 0, 0, 0, 0, 0, 0, 0, // 0x58-0x5F
};

// Special key codes (above ASCII range)
pub const KEY_PAGE_UP: u8 = 0x80;
pub const KEY_PAGE_DOWN: u8 = 0x81;
pub const KEY_UP: u8 = 0x82;
pub const KEY_DOWN: u8 = 0x83;
pub const KEY_LEFT: u8 = 0x84;
pub const KEY_RIGHT: u8 = 0x85;
pub const KEY_HOME: u8 = 0x86;
pub const KEY_END: u8 = 0x87;

// Function keys
pub const KEY_F1: u8 = 0x88;
pub const KEY_F2: u8 = 0x89;
pub const KEY_F3: u8 = 0x8A;
pub const KEY_F4: u8 = 0x8B;
pub const KEY_F5: u8 = 0x8C;
pub const KEY_F6: u8 = 0x8D;
pub const KEY_F7: u8 = 0x8E;
pub const KEY_F8: u8 = 0x8F;
pub const KEY_F9: u8 = 0x90;
pub const KEY_F10: u8 = 0x91;
pub const KEY_F11: u8 = 0x92;
pub const KEY_F12: u8 = 0x93;

// Keyboard state
var shift_pressed: bool = false;
var ctrl_pressed: bool = false;
var alt_pressed: bool = false;
var extended_scancode: bool = false; // For 0xE0 prefix handling

// Keyboard buffer (circular buffer)
var key_buffer: [256]u8 = [_]u8{0} ** 256;
var buffer_head: usize = 0;
var buffer_tail: usize = 0;

// Callback for key press
var key_callback: ?*const fn (u8) callconv(.c) void = null;

pub fn setCallback(callback: *const fn (u8) callconv(.c) void) void {
    key_callback = callback;
}

// Initialize keyboard controller for interrupt mode
pub fn init() void {
    // Enable keyboard interrupts in the keyboard controller
    // Read current command byte
    io.outb(KEYBOARD_STATUS, 0x20);
    var status = io.inb(KEYBOARD_DATA);

    // Set bit 0 (enable IRQ1) and clear bit 4 (enable keyboard)
    status |= 0x01; // Enable keyboard interrupt
    status &= ~@as(u8, 0x10); // Enable keyboard

    // Write command byte back
    io.outb(KEYBOARD_STATUS, 0x60);
    io.outb(KEYBOARD_DATA, status);
}

// Handle keyboard interrupt (called from IRQ1 handler)
pub fn handleInterrupt() void {
    // CRITICAL: Must read port 0x60 to acknowledge IRQ and get scancode
    const scancode = io.inb(KEYBOARD_DATA);

    // Handle extended scancode prefixes (0xE0, 0xE1)
    // 0xE0 = extended keys (arrows, insert, delete, etc.)
    // 0xE1 = pause/break key (sends E1 1D 45 E1 9D C5)
    if (scancode == 0xE0 or scancode == 0xE1) {
        extended_scancode = true;
        return; // Wait for next scancode
    }

    // Handle extended scancodes (arrow keys, page up/down, etc.)
    if (extended_scancode) {
        extended_scancode = false;
        // Handle key release for extended keys
        if (scancode & 0x80 != 0) {
            return; // Ignore extended key releases
        }
        // Map extended scancodes to special key codes
        const special_key: ?u8 = switch (scancode) {
            0x48 => KEY_UP,
            0x50 => KEY_DOWN,
            0x4B => KEY_LEFT,
            0x4D => KEY_RIGHT,
            0x49 => KEY_PAGE_UP,
            0x51 => KEY_PAGE_DOWN,
            0x47 => KEY_HOME,
            0x4F => KEY_END,
            else => null,
        };
        if (special_key) |key| {
            const next_head = (buffer_head + 1) % key_buffer.len;
            if (next_head != buffer_tail) {
                key_buffer[buffer_head] = key;
                buffer_head = next_head;
            }
        }
        return;
    }

    // Ignore scancodes outside our table range (0x00-0x5F)
    // This catches any weird scancodes that might slip through
    if ((scancode & 0x7F) >= scancode_to_ascii.len) {
        return;
    }

    // Check for key release (bit 7 set)
    if (scancode & 0x80 != 0) {
        const released = scancode & 0x7F;
        switch (released) {
            0x2A, 0x36 => shift_pressed = false, // Left/Right Shift
            0x1D => ctrl_pressed = false, // Ctrl
            0x38 => alt_pressed = false, // Alt
            else => {},
        }
        return;
    }

    // Key press - handle modifier keys
    switch (scancode) {
        0x2A, 0x36 => shift_pressed = true, // Left/Right Shift
        0x1D => ctrl_pressed = true, // Ctrl
        0x38 => alt_pressed = true, // Alt
        // Function keys F1-F12
        0x3B => addKeyToBuffer(KEY_F1),
        0x3C => addKeyToBuffer(KEY_F2),
        0x3D => addKeyToBuffer(KEY_F3),
        0x3E => addKeyToBuffer(KEY_F4),
        0x3F => addKeyToBuffer(KEY_F5),
        0x40 => addKeyToBuffer(KEY_F6),
        0x41 => addKeyToBuffer(KEY_F7),
        0x42 => addKeyToBuffer(KEY_F8),
        0x43 => addKeyToBuffer(KEY_F9),
        0x44 => addKeyToBuffer(KEY_F10),
        0x57 => addKeyToBuffer(KEY_F11),
        0x58 => addKeyToBuffer(KEY_F12),
        else => {
            // Convert scancode to ASCII (already bounds-checked above)
            var ascii = if (shift_pressed)
                scancode_to_ascii_shift[scancode]
            else
                scancode_to_ascii[scancode];

            // Handle Ctrl key combinations
            // Ctrl+A = 1, Ctrl+B = 2, ..., Ctrl+Z = 26
            if (ctrl_pressed and ascii != 0) {
                if (ascii >= 'a' and ascii <= 'z') {
                    ascii = ascii - 'a' + 1; // Ctrl+a = 1, Ctrl+l = 12, etc.
                } else if (ascii >= 'A' and ascii <= 'Z') {
                    ascii = ascii - 'A' + 1;
                }
                addKeyToBuffer(ascii);
                return;
            }

            // Only add printable characters or control chars (backspace, enter, tab, esc)
            if (ascii != 0 and (ascii >= 32 or ascii == 8 or ascii == '\n' or ascii == '\t' or ascii == 27)) {
                addKeyToBuffer(ascii);
            }
        },
    }
}

/// Add key to circular buffer
fn addKeyToBuffer(key: u8) void {
    const next_head = (buffer_head + 1) % key_buffer.len;
    if (next_head != buffer_tail) {
        key_buffer[buffer_head] = key;
        buffer_head = next_head;
    }
}

// Get a key from buffer (non-blocking)
pub fn getKey() ?u8 {
    if (buffer_head == buffer_tail) {
        return null;
    }
    const key = key_buffer[buffer_tail];
    buffer_tail = (buffer_tail + 1) % key_buffer.len;
    return key;
}

// Check if key is available
pub fn hasKey() bool {
    return buffer_head != buffer_tail;
}

// Wait for a key (blocking)
pub fn waitKey() u8 {
    while (!hasKey()) {
        asm volatile ("hlt");
    }
    return getKey().?;
}

// Get modifier key states
pub fn isShiftPressed() bool {
    return shift_pressed;
}

pub fn isCtrlPressed() bool {
    return ctrl_pressed;
}

pub fn isAltPressed() bool {
    return alt_pressed;
}

// Keyboard LED control
const LED_SCROLL: u8 = 0x01;
const LED_NUM: u8 = 0x02;
const LED_CAPS: u8 = 0x04;

var led_state: u8 = 0;

/// Set keyboard LEDs (Scroll Lock, Num Lock, Caps Lock)
pub fn setLEDs(scroll: bool, num: bool, caps: bool) void {
    led_state = 0;
    if (scroll) led_state |= LED_SCROLL;
    if (num) led_state |= LED_NUM;
    if (caps) led_state |= LED_CAPS;

    // Wait for keyboard controller ready
    while ((io.inb(KEYBOARD_STATUS) & 0x02) != 0) {}

    // Send LED command
    io.outb(KEYBOARD_DATA, 0xED);

    // Wait for ACK
    while ((io.inb(KEYBOARD_STATUS) & 0x02) != 0) {}

    // Send LED state
    io.outb(KEYBOARD_DATA, led_state);
}

/// Get current LED state
pub fn getLEDState() u8 {
    return led_state;
}

/// Check if Caps Lock is on
pub fn isCapsLockOn() bool {
    return (led_state & LED_CAPS) != 0;
}

/// Check if Num Lock is on
pub fn isNumLockOn() bool {
    return (led_state & LED_NUM) != 0;
}
