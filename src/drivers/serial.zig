// Home OS - Serial Port Driver (for debugging)
// Copyright © 2025 Romy Rianata - Home OS

const io = @import("../arch/io.zig");

// COM1 serial port
const PORT: u16 = 0x3F8;

var initialized: bool = false;

pub fn init() void {
    // Disable interrupts
    io.outb(PORT + 1, 0x00);

    // Enable DLAB (set baud rate divisor)
    io.outb(PORT + 3, 0x80);

    // Set divisor to 3 (38400 baud)
    io.outb(PORT + 0, 0x03);
    io.outb(PORT + 1, 0x00);

    // 8 bits, no parity, one stop bit
    io.outb(PORT + 3, 0x03);

    // Enable FIFO, clear them, with 14-byte threshold
    io.outb(PORT + 2, 0xC7);

    // IRQs enabled, RTS/DSR set
    io.outb(PORT + 4, 0x0B);

    initialized = true;
}

fn isTransmitEmpty() bool {
    return (io.inb(PORT + 5) & 0x20) != 0;
}

pub fn writeChar(char: u8) void {
    if (!initialized) return;

    // Wait for transmit buffer to be empty
    while (!isTransmitEmpty()) {
        asm volatile ("pause");
    }

    io.outb(PORT, char);
}

pub fn write(data: []const u8) void {
    for (data) |char| {
        writeChar(char);
    }
}

pub fn writeInt(value: u32) void {
    if (value == 0) {
        writeChar('0');
        return;
    }

    var buf: [10]u8 = undefined;
    var i: usize = 0;
    var v = value;

    while (v > 0) : (i += 1) {
        buf[i] = @truncate((v % 10) + '0');
        v /= 10;
    }

    while (i > 0) {
        i -= 1;
        writeChar(buf[i]);
    }
}

pub fn writeHex(value: u32) void {
    const hex_chars = "0123456789ABCDEF";

    var i: u6 = 32;
    while (i > 0) {
        i -= 4;
        const nibble: u4 = @truncate((value >> @truncate(i)) & 0xF);
        writeChar(hex_chars[nibble]);
    }
}

pub fn printInt(value: u32) void {
    writeInt(value);
}
