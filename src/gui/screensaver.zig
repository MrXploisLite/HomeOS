// Home OS - Screensaver
// Copyright © 2025 Romy Rianata - Home OS

const graphics = @import("../drivers/graphics.zig");
const font = @import("../drivers/font.zig");

// Screensaver state
var active: bool = false;
var idle_ticks: u32 = 0;
const IDLE_TIMEOUT: u32 = 6000; // 60 seconds at 100Hz

// Bouncing text position
var text_x: i32 = 100;
var text_y: i32 = 100;
var dx: i32 = 2;
var dy: i32 = 1;

/// Reset idle timer (call on any input)
pub fn resetIdle() void {
    idle_ticks = 0;
    if (active) {
        active = false;
    }
}

/// Update screensaver state
pub fn update() void {
    if (!active) {
        idle_ticks += 1;
        if (idle_ticks >= IDLE_TIMEOUT) {
            active = true;
        }
    }
}

/// Check if screensaver is active
pub fn isActive() bool {
    return active;
}

/// Draw screensaver
pub fn draw(screen_width: u32, screen_height: u32) void {
    if (!active) return;

    // Black background
    graphics.fillRect(0, 0, screen_width, screen_height, graphics.BLACK);

    // Bouncing "Home OS" text
    const text = "Home OS";
    const text_width: i32 = 56; // 7 chars * 8 pixels

    // Update position
    text_x += dx;
    text_y += dy;

    // Bounce off edges
    if (text_x <= 0 or text_x >= @as(i32, @intCast(screen_width)) - text_width) {
        dx = -dx;
    }
    if (text_y <= 0 or text_y >= @as(i32, @intCast(screen_height)) - 16) {
        dy = -dy;
    }

    // Clamp to bounds
    if (text_x < 0) text_x = 0;
    if (text_y < 0) text_y = 0;

    // Draw text with color cycling based on position
    const r: u8 = @truncate(@as(u32, @intCast(@abs(text_x))) % 200 + 55);
    const g: u8 = @truncate(@as(u32, @intCast(@abs(text_y))) % 200 + 55);
    const b: u8 = @truncate((@as(u32, @intCast(@abs(text_x + text_y)))) % 200 + 55);

    font.drawString(text_x, text_y, text, graphics.Color.rgb(r, g, b), null);

    // Draw "Press any key" at bottom
    font.drawString(@as(i32, @intCast(screen_width / 2)) - 60, @as(i32, @intCast(screen_height)) - 30, "Press any key...", graphics.Color.rgb(80, 80, 80), null);
}

/// Enable/disable screensaver
pub fn setEnabled(enabled: bool) void {
    if (!enabled) {
        active = false;
        idle_ticks = 0;
    }
}
