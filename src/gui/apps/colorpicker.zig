// Home OS - Color Picker Tool
// Copyright © 2025 Romy Rianata - Home OS

const graphics = @import("../../drivers/graphics.zig");
const font = @import("../../drivers/font.zig");
const window = @import("../window.zig");
const Window = window.Window;
const TITLE_BAR_HEIGHT = window.TITLE_BAR_HEIGHT;

// Current color values
var red: u8 = 128;
var green: u8 = 128;
var blue: u8 = 128;
var selected_channel: u8 = 0; // 0=R, 1=G, 2=B

pub fn draw(win: *const Window, x: i32, y: i32) void {
    const content_w = win.width - 8;
    const content_h = win.height - @as(u32, @intCast(TITLE_BAR_HEIGHT)) - 8;

    // Title
    font.drawString(x, y, "Color Picker", graphics.BLACK, null);

    // Color preview (responsive size)
    const preview_y = y + 16;
    const preview_w: u32 = @min(100, @divTrunc(content_w, 3));
    const preview_h: u32 = @min(60, content_h - 40);
    graphics.fillRect(x, preview_y, preview_w, preview_h, graphics.Color.rgb(red, green, blue));
    graphics.drawRect(x, preview_y, preview_w, preview_h, graphics.DARK_GRAY);

    // RGB sliders (responsive width)
    const slider_x = x + @as(i32, @intCast(preview_w)) + 10;
    const slider_w: u32 = @max(50, content_w - preview_w - 60);

    // Red slider
    drawSlider(slider_x, preview_y, slider_w, red, graphics.RED, selected_channel == 0);
    font.drawString(slider_x + @as(i32, @intCast(slider_w)) + 4, preview_y + 2, "R", graphics.DARK_GRAY, null);

    // Green slider
    drawSlider(slider_x, preview_y + 20, slider_w, green, graphics.GREEN, selected_channel == 1);
    font.drawString(slider_x + @as(i32, @intCast(slider_w)) + 4, preview_y + 22, "G", graphics.DARK_GRAY, null);

    // Blue slider
    drawSlider(slider_x, preview_y + 40, slider_w, blue, graphics.BLUE, selected_channel == 2);
    font.drawString(slider_x + @as(i32, @intCast(slider_w)) + 4, preview_y + 42, "B", graphics.DARK_GRAY, null);

    // Hex value (only if space)
    if (content_h > 90) {
        const hex_y = preview_y + @as(i32, @intCast(preview_h)) + 10;
        font.drawString(x, hex_y, "Hex: #", graphics.DARK_GRAY, null);
        var hex_buf: [6]u8 = undefined;
        formatHex(red, hex_buf[0..2]);
        formatHex(green, hex_buf[2..4]);
        formatHex(blue, hex_buf[4..6]);
        font.drawString(x + 48, hex_y, &hex_buf, graphics.BLACK, null);

        // Instructions (only if more space)
        if (content_h > 110) {
            font.drawString(x, hex_y + 16, "Tab:Channel +/-:Value", graphics.GRAY, null);
        }
    }
}

fn drawSlider(x: i32, y: i32, w: u32, value: u8, color: graphics.Color, selected: bool) void {
    // Background
    graphics.fillRect(x, y, w, 14, graphics.Color.rgb(60, 60, 65));
    // Fill
    const fill_w: u32 = (@as(u32, value) * w) / 255;
    graphics.fillRect(x, y, fill_w, 14, color);
    // Border
    const border_color = if (selected) graphics.WHITE else graphics.DARK_GRAY;
    graphics.drawRect(x, y, w, 14, border_color);
}

fn drawValue(x: i32, y: i32, value: u8) void {
    var buf: [3]u8 = undefined;
    var v = value;
    buf[2] = '0' + @as(u8, @truncate(v % 10));
    v /= 10;
    buf[1] = '0' + @as(u8, @truncate(v % 10));
    v /= 10;
    buf[0] = '0' + @as(u8, @truncate(v % 10));
    font.drawString(x, y, &buf, graphics.DARK_GRAY, null);
}

fn formatHex(value: u8, buf: []u8) void {
    const hex = "0123456789ABCDEF";
    buf[0] = hex[value >> 4];
    buf[1] = hex[value & 0x0F];
}

pub fn handleKey(key: u8) void {
    if (key == '\t') {
        // Cycle through channels
        selected_channel = (selected_channel + 1) % 3;
    } else if (key == '+' or key == '=') {
        // Increase value
        switch (selected_channel) {
            0 => red = if (red < 245) red + 10 else 255,
            1 => green = if (green < 245) green + 10 else 255,
            2 => blue = if (blue < 245) blue + 10 else 255,
            else => {},
        }
    } else if (key == '-' or key == '_') {
        // Decrease value
        switch (selected_channel) {
            0 => red = if (red > 10) red - 10 else 0,
            1 => green = if (green > 10) green - 10 else 0,
            2 => blue = if (blue > 10) blue - 10 else 0,
            else => {},
        }
    } else if (key == 'r' or key == 'R') {
        selected_channel = 0;
    } else if (key == 'g' or key == 'G') {
        selected_channel = 1;
    } else if (key == 'b' or key == 'B') {
        selected_channel = 2;
    }
}

/// Get current color
pub fn getColor() graphics.Color {
    return graphics.Color.rgb(red, green, blue);
}
