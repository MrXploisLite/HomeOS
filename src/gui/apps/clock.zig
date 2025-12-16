// Home OS - Clock App
// Copyright © 2025 Romy Rianata - Home OS

const graphics = @import("../../drivers/graphics.zig");
const font = @import("../../drivers/font.zig");
const rtc = @import("../../drivers/rtc.zig");
const pit = @import("../../drivers/pit.zig");
const window = @import("../window.zig");
const Window = window.Window;

const TITLE_BAR_HEIGHT = window.TITLE_BAR_HEIGHT;

// Stopwatch state
var stopwatch_mode: bool = false;
var stopwatch_running: bool = false;
var stopwatch_start_tick: u32 = 0;
var stopwatch_elapsed: u32 = 0; // In ticks (100Hz)

// Alarm state
var alarm_mode: bool = false;
var alarm_hour: u8 = 7;
var alarm_minute: u8 = 0;
var alarm_enabled: bool = false;
var alarm_triggered: bool = false;

// 12/24 hour format
var use_24h: bool = true;

pub fn draw(win: *const Window, x: i32, y: i32) void {
    // Calculate responsive dimensions with safe arithmetic
    const content_w = win.width -| 8;
    const content_h = win.height -| @as(u32, @intCast(TITLE_BAR_HEIGHT)) -| 8;
    const min_dim = @min(content_w, content_h -| 50); // Leave space for text
    const radius: i32 = @intCast(@max(30, (min_dim / 2) -| 10));
    const center_x: i32 = @intCast(@divTrunc(content_w, 2));
    const center_y: i32 = radius + 10;

    // Clock face background
    graphics.fillCircle(x + center_x, y + center_y, @intCast(radius + 5), graphics.Color.rgb(40, 40, 45));
    graphics.fillCircle(x + center_x, y + center_y, @intCast(radius), graphics.Color.rgb(250, 250, 255));
    graphics.drawCircle(x + center_x, y + center_y, @intCast(radius), graphics.Color.rgb(80, 80, 85));

    // Hour markers (scaled)
    var h: i32 = 0;
    while (h < 12) : (h += 1) {
        const angle = @as(f32, @floatFromInt(h)) * 30.0 - 90.0;
        const rad = angle * 3.14159 / 180.0;
        const inner_r: f32 = @floatFromInt(radius - 8);
        const outer_r: f32 = @floatFromInt(radius - 3);

        const cos_val = @cos(rad);
        const sin_val = @sin(rad);

        const x1 = x + center_x + @as(i32, @intFromFloat(inner_r * cos_val));
        const y1 = y + center_y + @as(i32, @intFromFloat(inner_r * sin_val));
        const x2 = x + center_x + @as(i32, @intFromFloat(outer_r * cos_val));
        const y2 = y + center_y + @as(i32, @intFromFloat(outer_r * sin_val));

        graphics.drawLine(x1, y1, x2, y2, graphics.DARK_GRAY);
    }

    // Get current time
    const dt = rtc.getDateTime();
    const hour = dt.hour % 12;
    const minute = dt.minute;
    const second = dt.second;

    // Hand lengths scaled to radius
    const hour_len: f32 = @floatFromInt(@divTrunc(radius * 6, 10));
    const min_len: f32 = @floatFromInt(@divTrunc(radius * 8, 10));
    const sec_len: f32 = @floatFromInt(@divTrunc(radius * 9, 10));

    // Hour hand
    const hour_angle = (@as(f32, @floatFromInt(hour)) + @as(f32, @floatFromInt(minute)) / 60.0) * 30.0 - 90.0;
    const hour_rad = hour_angle * 3.14159 / 180.0;
    const hx = x + center_x + @as(i32, @intFromFloat(hour_len * @cos(hour_rad)));
    const hy = y + center_y + @as(i32, @intFromFloat(hour_len * @sin(hour_rad)));
    graphics.drawLine(x + center_x, y + center_y, hx, hy, graphics.BLACK);
    graphics.drawLine(x + center_x + 1, y + center_y, hx + 1, hy, graphics.BLACK);

    // Minute hand
    const min_angle = @as(f32, @floatFromInt(minute)) * 6.0 - 90.0;
    const min_rad = min_angle * 3.14159 / 180.0;
    const mx = x + center_x + @as(i32, @intFromFloat(min_len * @cos(min_rad)));
    const my = y + center_y + @as(i32, @intFromFloat(min_len * @sin(min_rad)));
    graphics.drawLine(x + center_x, y + center_y, mx, my, graphics.DARK_GRAY);

    // Second hand
    const sec_angle = @as(f32, @floatFromInt(second)) * 6.0 - 90.0;
    const sec_rad = sec_angle * 3.14159 / 180.0;
    const sx = x + center_x + @as(i32, @intFromFloat(sec_len * @cos(sec_rad)));
    const sy = y + center_y + @as(i32, @intFromFloat(sec_len * @sin(sec_rad)));
    graphics.drawLine(x + center_x, y + center_y, sx, sy, graphics.RED);

    // Center dot
    graphics.fillCircle(x + center_x, y + center_y, 4, graphics.Color.rgb(60, 60, 65));

    // Digital time below (centered)
    var time_buf: [12]u8 = undefined;
    if (use_24h) {
        _ = rtc.getTimeString(time_buf[0..8]);
        font.drawString(x + center_x - 28, y + center_y + radius + 15, time_buf[0..8], graphics.BLACK, null);
    } else {
        // 12-hour format
        var hour12 = dt.hour;
        const is_pm = hour12 >= 12;
        if (hour12 > 12) hour12 -= 12;
        if (hour12 == 0) hour12 = 12;
        time_buf[0] = '0' + hour12 / 10;
        time_buf[1] = '0' + hour12 % 10;
        time_buf[2] = ':';
        time_buf[3] = '0' + dt.minute / 10;
        time_buf[4] = '0' + dt.minute % 10;
        time_buf[5] = ' ';
        time_buf[6] = if (is_pm) 'P' else 'A';
        time_buf[7] = 'M';
        font.drawString(x + center_x - 32, y + center_y + radius + 15, time_buf[0..8], graphics.BLACK, null);
    }

    // Date, stopwatch, or alarm (only if space)
    if (content_h > @as(u32, @intCast(center_y + radius + 45))) {
        if (alarm_mode) {
            // Alarm display
            var alarm_buf: [6]u8 = undefined;
            alarm_buf[0] = '0' + alarm_hour / 10;
            alarm_buf[1] = '0' + alarm_hour % 10;
            alarm_buf[2] = ':';
            alarm_buf[3] = '0' + alarm_minute / 10;
            alarm_buf[4] = '0' + alarm_minute % 10;
            alarm_buf[5] = 0;

            const alarm_color = if (alarm_enabled) graphics.GREEN else graphics.GRAY;
            font.drawString(x + center_x - 20, y + center_y + radius + 30, alarm_buf[0..5], alarm_color, null);

            // Alarm status
            const status = if (alarm_enabled) "ON " else "OFF";
            font.drawString(x + center_x + 28, y + center_y + radius + 30, status, alarm_color, null);

            font.drawString(x + 4, y + center_y + radius + 45, "+/-:Hour []:Min E:Toggle", graphics.GRAY, null);
        } else if (stopwatch_mode) {
            // Stopwatch display
            var elapsed = stopwatch_elapsed;
            if (stopwatch_running) {
                elapsed += pit.getTicks() - stopwatch_start_tick;
            }
            const total_secs = elapsed / 100;
            const mins = total_secs / 60;
            const secs = total_secs % 60;
            const hundredths = elapsed % 100;

            var sw_buf: [10]u8 = undefined;
            sw_buf[0] = '0' + @as(u8, @truncate(mins / 10));
            sw_buf[1] = '0' + @as(u8, @truncate(mins % 10));
            sw_buf[2] = ':';
            sw_buf[3] = '0' + @as(u8, @truncate(secs / 10));
            sw_buf[4] = '0' + @as(u8, @truncate(secs % 10));
            sw_buf[5] = '.';
            sw_buf[6] = '0' + @as(u8, @truncate(hundredths / 10));
            sw_buf[7] = '0' + @as(u8, @truncate(hundredths % 10));

            const sw_color = if (stopwatch_running) graphics.GREEN else graphics.Color.rgb(255, 200, 100);
            font.drawString(x + center_x - 32, y + center_y + radius + 30, sw_buf[0..8], sw_color, null);
            font.drawString(x + 4, y + center_y + radius + 45, "Space:Start/Stop R:Reset", graphics.GRAY, null);
        } else {
            var date_buf: [10]u8 = undefined;
            const date_len = rtc.getDateString(&date_buf);
            font.drawString(x + center_x - 36, y + center_y + radius + 30, date_buf[0..date_len], graphics.DARK_GRAY, null);
            font.drawString(x + 4, y + center_y + radius + 45, "M:Stopwatch A:Alarm", graphics.GRAY, null);
        }
    }
}

pub fn handleKey(key: u8) void {
    if (key == 'm' or key == 'M') {
        // Toggle stopwatch mode
        stopwatch_mode = !stopwatch_mode;
        alarm_mode = false;
        if (!stopwatch_mode) {
            stopwatch_running = false;
            stopwatch_elapsed = 0;
        }
    } else if (key == 'a' or key == 'A') {
        // Toggle alarm mode
        alarm_mode = !alarm_mode;
        stopwatch_mode = false;
        alarm_triggered = false;
    } else if (key == 'h' or key == 'H') {
        // Toggle 12/24 hour format
        use_24h = !use_24h;
    } else if (alarm_mode) {
        if (key == 'e' or key == 'E') {
            // Enable/disable alarm
            alarm_enabled = !alarm_enabled;
            alarm_triggered = false;
        } else if (key == '+' or key == '=') {
            // Increase alarm hour
            alarm_hour = (alarm_hour + 1) % 24;
        } else if (key == '-') {
            // Decrease alarm hour
            alarm_hour = if (alarm_hour == 0) 23 else alarm_hour - 1;
        } else if (key == ']') {
            // Increase alarm minute
            alarm_minute = (alarm_minute + 1) % 60;
        } else if (key == '[') {
            // Decrease alarm minute
            alarm_minute = if (alarm_minute == 0) 59 else alarm_minute - 1;
        }
    } else if (stopwatch_mode) {
        if (key == ' ') {
            // Start/stop stopwatch
            if (stopwatch_running) {
                stopwatch_elapsed += pit.getTicks() - stopwatch_start_tick;
                stopwatch_running = false;
            } else {
                stopwatch_start_tick = pit.getTicks();
                stopwatch_running = true;
            }
        } else if (key == 'r' or key == 'R') {
            // Reset stopwatch
            stopwatch_elapsed = 0;
            stopwatch_running = false;
        }
    }
}

/// Check and trigger alarm (called from update)
pub fn checkAlarm() bool {
    if (!alarm_enabled or alarm_triggered) return false;
    const dt = rtc.getDateTime();
    if (dt.hour == alarm_hour and dt.minute == alarm_minute and dt.second < 2) {
        alarm_triggered = true;
        return true;
    }
    return false;
}
