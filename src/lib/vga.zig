// Home OS - VGA Text Mode Driver
// Copyright © 2025 Romy Rianata - Home OS

const serial = @import("../drivers/serial.zig");

const VGA_WIDTH: usize = 80;
const VGA_HEIGHT: usize = 25;
const VGA_BUFFER: usize = 0xB8000;

pub const VgaColor = enum(u4) {
    black = 0,
    blue = 1,
    green = 2,
    cyan = 3,
    red = 4,
    magenta = 5,
    brown = 6,
    light_grey = 7,
    dark_grey = 8,
    light_blue = 9,
    light_green = 10,
    light_cyan = 11,
    light_red = 12,
    light_magenta = 13,
    yellow = 14,
    white = 15,
};

fn vgaEntryColor(fg: VgaColor, bg: VgaColor) u8 {
    return @as(u8, @intFromEnum(fg)) | (@as(u8, @intFromEnum(bg)) << 4);
}

fn vgaEntry(char: u8, color: u8) u16 {
    return @as(u16, char) | (@as(u16, color) << 8);
}

pub const VgaWriter = struct {
    row: usize = 0,
    column: usize = 0,
    color: u8 = vgaEntryColor(.light_grey, .black),
    buffer: [*]volatile u16 = @ptrFromInt(VGA_BUFFER),

    pub fn init() VgaWriter {
        return VgaWriter{};
    }

    pub fn initAndClear() VgaWriter {
        var w = VgaWriter{};
        w.clear();
        return w;
    }

    pub fn clear(self: *VgaWriter) void {
        var y: usize = 0;
        while (y < VGA_HEIGHT) : (y += 1) {
            var x: usize = 0;
            while (x < VGA_WIDTH) : (x += 1) {
                self.buffer[y * VGA_WIDTH + x] = vgaEntry(' ', self.color);
            }
        }
        self.row = 0;
        self.column = 0;
    }

    pub fn setColor(self: *VgaWriter, fg: VgaColor, bg: VgaColor) void {
        self.color = vgaEntryColor(fg, bg);
    }

    pub fn scroll(self: *VgaWriter) void {
        var y: usize = 0;
        while (y < VGA_HEIGHT - 1) : (y += 1) {
            var x: usize = 0;
            while (x < VGA_WIDTH) : (x += 1) {
                self.buffer[y * VGA_WIDTH + x] = self.buffer[(y + 1) * VGA_WIDTH + x];
            }
        }
        var x: usize = 0;
        while (x < VGA_WIDTH) : (x += 1) {
            self.buffer[(VGA_HEIGHT - 1) * VGA_WIDTH + x] = vgaEntry(' ', self.color);
        }
    }

    pub fn putChar(self: *VgaWriter, char: u8) void {
        serial.writeChar(char);

        if (char == '\n') {
            self.column = 0;
            self.row += 1;
        } else if (char == 8) {
            // Backspace - move cursor back and clear character
            if (self.column > 0) {
                self.column -= 1;
                self.buffer[self.row * VGA_WIDTH + self.column] = vgaEntry(' ', self.color);
            }
        } else if (char == '\t') {
            // Tab - move to next 8-column boundary
            self.column = (self.column + 8) & ~@as(usize, 7);
            if (self.column >= VGA_WIDTH) {
                self.column = 0;
                self.row += 1;
            }
        } else if (char >= 32) {
            // Only print printable characters
            self.buffer[self.row * VGA_WIDTH + self.column] = vgaEntry(char, self.color);
            self.column += 1;
        }
        // Ignore other control characters

        if (self.column >= VGA_WIDTH) {
            self.column = 0;
            self.row += 1;
        }
        if (self.row >= VGA_HEIGHT) {
            self.scroll();
            self.row = VGA_HEIGHT - 1;
        }
    }

    pub fn write(self: *VgaWriter, data: []const u8) void {
        for (data) |char| self.putChar(char);
    }

    pub fn printInt(self: *VgaWriter, value: u32) void {
        if (value == 0) {
            self.putChar('0');
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
            self.putChar(buf[i]);
        }
    }

    pub fn printSize(self: *VgaWriter, kb: u32) void {
        if (kb >= 1024 * 1024) {
            self.printInt(kb / (1024 * 1024));
            self.write(" GB");
        } else if (kb >= 1024) {
            self.printInt(kb / 1024);
            self.write(" MB");
        } else {
            self.printInt(kb);
            self.write(" KB");
        }
    }

    pub fn printHex16(self: *VgaWriter, val: u16) void {
        const hex = "0123456789ABCDEF";
        self.putChar(hex[(val >> 12) & 0xF]);
        self.putChar(hex[(val >> 8) & 0xF]);
        self.putChar(hex[(val >> 4) & 0xF]);
        self.putChar(hex[val & 0xF]);
    }

    pub fn printHex(self: *VgaWriter, val: u32) void {
        const hex = "0123456789ABCDEF";
        self.write("0x");
        self.putChar(hex[(val >> 28) & 0xF]);
        self.putChar(hex[(val >> 24) & 0xF]);
        self.putChar(hex[(val >> 20) & 0xF]);
        self.putChar(hex[(val >> 16) & 0xF]);
        self.putChar(hex[(val >> 12) & 0xF]);
        self.putChar(hex[(val >> 8) & 0xF]);
        self.putChar(hex[(val >> 4) & 0xF]);
        self.putChar(hex[val & 0xF]);
    }
};
