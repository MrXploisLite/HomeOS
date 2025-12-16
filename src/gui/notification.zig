// Home OS - Notification System
// Copyright © 2025 Romy Rianata - Home OS

const graphics = @import("../drivers/graphics.zig");
const font = @import("../drivers/font.zig");

const MAX_NOTIFICATIONS: usize = 4;
const NOTIFICATION_WIDTH: u32 = 200;
const NOTIFICATION_HEIGHT: u32 = 40;
const DISPLAY_TICKS: u32 = 300; // ~3 seconds at 100Hz

pub const NotificationType = enum { info, success, warning, error_type };

const Notification = struct {
    message: [64]u8,
    msg_len: usize,
    ntype: NotificationType,
    ticks_remaining: u32,
    active: bool,
};

var notifications: [MAX_NOTIFICATIONS]Notification = [_]Notification{.{
    .message = [_]u8{0} ** 64,
    .msg_len = 0,
    .ntype = .info,
    .ticks_remaining = 0,
    .active = false,
}} ** MAX_NOTIFICATIONS;

/// Show a notification toast
pub fn show(message: []const u8, ntype: NotificationType) void {
    // Find free slot
    for (&notifications) |*n| {
        if (!n.active) {
            const len = @min(message.len, 63);
            for (0..len) |i| {
                n.message[i] = message[i];
            }
            n.msg_len = len;
            n.ntype = ntype;
            n.ticks_remaining = DISPLAY_TICKS;
            n.active = true;
            return;
        }
    }
    // If all slots full, replace oldest
    notifications[0].msg_len = @min(message.len, 63);
    for (0..notifications[0].msg_len) |i| {
        notifications[0].message[i] = message[i];
    }
    notifications[0].ntype = ntype;
    notifications[0].ticks_remaining = DISPLAY_TICKS;
}

/// Update notifications (call each frame)
pub fn update() void {
    for (&notifications) |*n| {
        if (n.active and n.ticks_remaining > 0) {
            n.ticks_remaining -= 1;
            if (n.ticks_remaining == 0) {
                n.active = false;
            }
        }
    }
}

/// Draw all active notifications
pub fn draw(screen_width: u32) void {
    var y: i32 = 40; // Start below top
    const x = @as(i32, @intCast(screen_width)) - @as(i32, @intCast(NOTIFICATION_WIDTH)) - 10;

    for (&notifications) |*n| {
        if (n.active) {
            // Background color based on type
            const bg_color = switch (n.ntype) {
                .info => graphics.Color.rgb(50, 50, 60),
                .success => graphics.Color.rgb(40, 80, 40),
                .warning => graphics.Color.rgb(100, 80, 30),
                .error_type => graphics.Color.rgb(100, 40, 40),
            };
            const border_color = switch (n.ntype) {
                .info => graphics.Color.rgb(80, 80, 100),
                .success => graphics.Color.rgb(80, 150, 80),
                .warning => graphics.Color.rgb(180, 140, 60),
                .error_type => graphics.Color.rgb(180, 80, 80),
            };

            // Draw notification box
            graphics.fillRect(x, y, NOTIFICATION_WIDTH, NOTIFICATION_HEIGHT, bg_color);
            graphics.drawRect(x, y, NOTIFICATION_WIDTH, NOTIFICATION_HEIGHT, border_color);

            // Draw message
            font.drawString(x + 8, y + 14, n.message[0..n.msg_len], graphics.WHITE, null);

            y += @as(i32, @intCast(NOTIFICATION_HEIGHT)) + 5;
        }
    }
}

/// Convenience functions
pub fn info(message: []const u8) void {
    show(message, .info);
}

pub fn success(message: []const u8) void {
    show(message, .success);
}

pub fn warning(message: []const u8) void {
    show(message, .warning);
}

pub fn err(message: []const u8) void {
    show(message, .error_type);
}
