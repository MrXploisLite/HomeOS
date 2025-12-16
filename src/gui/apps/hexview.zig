// Home OS - Hex Viewer App
// Copyright © 2025 Romy Rianata - Home OS

const graphics = @import("../../drivers/graphics.zig");
const font = @import("../../drivers/font.zig");
const window = @import("../window.zig");
const fat32 = @import("../../fs/fat32.zig");
const Window = window.Window;
const TITLE_BAR_HEIGHT = window.TITLE_BAR_HEIGHT;

// Buffer for file data
var file_data: [256]u8 = [_]u8{0} ** 256;
var file_len: usize = 0;
var file_name: [12]u8 = [_]u8{' '} ** 12;
var scroll_offset: usize = 0;

const BYTES_PER_LINE: usize = 8;

pub fn draw(win: *const Window, x: i32, y: i32) void {
    // Calculate responsive dimensions
    const content_w = win.width - 8;
    const content_h = win.height - @as(u32, @intCast(TITLE_BAR_HEIGHT)) - 8;

    // Title
    font.drawString(x, y, "Hex Viewer", graphics.BLACK, null);
    // Clip filename to available space
    const name_max: usize = @min(12, @max(1, (content_w - 100) / 8));
    font.drawString(x + 100, y, file_name[0..name_max], graphics.DARK_GRAY, null);

    // Header (responsive width)
    const header_y = y + 16;
    const header_w: u32 = @max(200, content_w);
    graphics.fillRect(x, header_y, header_w, 14, graphics.Color.rgb(60, 60, 65));
    font.drawString(x + 4, header_y + 2, "Offset", graphics.WHITE, null);
    font.drawString(x + 60, header_y + 2, "Hex", graphics.WHITE, null);
    // ASCII column position based on width
    const ascii_col_x = x + @as(i32, @intCast(@min(200, content_w - 60)));
    font.drawString(ascii_col_x, header_y + 2, "ASCII", graphics.WHITE, null);

    // Data area (responsive)
    const data_y = header_y + 16;
    const data_h: u32 = @max(50, content_h - 50);
    graphics.fillRect(x, data_y, header_w, data_h, graphics.WHITE);
    graphics.drawRect(x, data_y, header_w, data_h, graphics.DARK_GRAY);

    // Calculate visible lines based on height
    const visible_lines: usize = @max(1, @divTrunc(data_h - 8, 14));

    if (file_len == 0) {
        font.drawString(x + 8, data_y + @as(i32, @intCast(data_h / 2)) - 8, "No file loaded", graphics.GRAY, null);
        font.drawString(x + 8, data_y + @as(i32, @intCast(data_h / 2)) + 8, "Use File Manager", graphics.GRAY, null);
        return;
    }

    // Draw hex data
    var line: usize = 0;
    var offset = scroll_offset;
    while (line < visible_lines and offset < file_len) : (line += 1) {
        const line_y = data_y + 4 + @as(i32, @intCast(line * 14));

        // Offset column
        var offset_buf: [6]u8 = undefined;
        formatHex16(@truncate(offset), &offset_buf);
        font.drawString(x + 4, line_y, offset_buf[0..4], graphics.Color.rgb(100, 100, 200), null);

        // Hex bytes
        var hex_x = x + 60;
        var ascii_buf: [BYTES_PER_LINE]u8 = undefined;
        var byte_idx: usize = 0;

        while (byte_idx < BYTES_PER_LINE and offset + byte_idx < file_len) : (byte_idx += 1) {
            const b = file_data[offset + byte_idx];
            var hex_buf: [3]u8 = undefined;
            formatHex8(b, &hex_buf);
            font.drawString(hex_x, line_y, hex_buf[0..2], graphics.BLACK, null);
            hex_x += 18;

            // ASCII representation
            ascii_buf[byte_idx] = if (b >= 32 and b < 127) b else '.';
        }

        // Draw ASCII (responsive position)
        font.drawString(ascii_col_x, line_y, ascii_buf[0..byte_idx], graphics.Color.rgb(80, 150, 80), null);

        offset += BYTES_PER_LINE;
    }

    // Status bar (responsive)
    const status_y = data_y + @as(i32, @intCast(data_h)) + 4;
    var size_buf: [16]u8 = undefined;
    const size_len = formatSize(file_len, &size_buf);
    font.drawString(x, status_y, size_buf[0..size_len], graphics.GRAY, null);
    // Only show hint if space
    if (content_w > 200) {
        font.drawString(x + @as(i32, @intCast(content_w)) - 120, status_y, "PgUp/PgDn:Scroll", graphics.GRAY, null);
    }
}

pub fn loadFile(name: []const u8) void {
    if (!fat32.isInitialized()) return;
    if (fat32.getFS()) |fs| {
        if (fs.findFile(fs.root_cluster, name)) |entry| {
            file_len = fs.readFile(&entry, &file_data, 256);
            const len = @min(name.len, 12);
            for (0..len) |i| {
                file_name[i] = name[i];
            }
            scroll_offset = 0;
        }
    }
}

/// Handle mouse scroll wheel
pub fn handleScroll(delta: i8) void {
    // QEMU/IntelliMouse: positive = scroll down, negative = scroll up
    const scroll_amount = BYTES_PER_LINE * 2; // Scroll 2 lines at a time

    if (delta < 0) {
        // Scroll wheel UP - see earlier content (decrease offset)
        const amount = @as(usize, @intCast(@abs(delta))) * scroll_amount;
        if (scroll_offset >= amount) {
            scroll_offset -= amount;
        } else {
            scroll_offset = 0;
        }
    } else if (delta > 0) {
        // Scroll wheel DOWN - see later content (increase offset)
        const amount = @as(usize, @intCast(@abs(delta))) * scroll_amount;
        if (file_len > 0 and scroll_offset + amount < file_len) {
            scroll_offset += amount;
        }
    }
}

pub fn handleKey(key: u8) void {
    const keyboard = @import("../../drivers/keyboard.zig");
    const scroll_amount = BYTES_PER_LINE * 4;
    if (key == keyboard.KEY_PAGE_UP) {
        if (scroll_offset >= scroll_amount) {
            scroll_offset -= scroll_amount;
        } else {
            scroll_offset = 0;
        }
    } else if (key == keyboard.KEY_PAGE_DOWN) {
        if (scroll_offset + scroll_amount < file_len) {
            scroll_offset += scroll_amount;
        }
    } else if (key == keyboard.KEY_UP) {
        if (scroll_offset >= BYTES_PER_LINE) {
            scroll_offset -= BYTES_PER_LINE;
        } else {
            scroll_offset = 0;
        }
    } else if (key == keyboard.KEY_DOWN) {
        if (scroll_offset + BYTES_PER_LINE < file_len) {
            scroll_offset += BYTES_PER_LINE;
        }
    }
}

fn formatHex8(val: u8, buf: []u8) void {
    const hex = "0123456789ABCDEF";
    buf[0] = hex[val >> 4];
    buf[1] = hex[val & 0x0F];
    buf[2] = ' ';
}

fn formatHex16(val: u16, buf: []u8) void {
    const hex = "0123456789ABCDEF";
    buf[0] = hex[(val >> 12) & 0x0F];
    buf[1] = hex[(val >> 8) & 0x0F];
    buf[2] = hex[(val >> 4) & 0x0F];
    buf[3] = hex[val & 0x0F];
    buf[4] = ':';
    buf[5] = ' ';
}

fn formatSize(size: usize, buf: []u8) usize {
    var len: usize = 0;
    var v = size;
    if (v == 0) {
        buf[0] = '0';
        len = 1;
    } else {
        var temp: [10]u8 = undefined;
        var tlen: usize = 0;
        while (v > 0) : (tlen += 1) {
            temp[tlen] = @truncate((v % 10) + '0');
            v /= 10;
        }
        while (tlen > 0) : (len += 1) {
            tlen -= 1;
            buf[len] = temp[tlen];
        }
    }
    const suffix = " bytes";
    for (suffix) |c| {
        buf[len] = c;
        len += 1;
    }
    return len;
}
