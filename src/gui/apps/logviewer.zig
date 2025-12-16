// Home OS - System Log Viewer
// Copyright © 2025 Romy Rianata - Home OS
// GUI app for viewing kernel/system logs

const graphics = @import("../../drivers/graphics.zig");
const font = @import("../../drivers/font.zig");
const window = @import("../window.zig");
const serial = @import("../../drivers/serial.zig");
const Window = window.Window;
const TITLE_BAR_HEIGHT = window.TITLE_BAR_HEIGHT;
const Color = graphics.Color;

// Log buffer - circular buffer for log entries
const MAX_LOG_ENTRIES: usize = 100;
const MAX_LOG_LINE: usize = 80;

var log_buffer: [MAX_LOG_ENTRIES][MAX_LOG_LINE]u8 = [_][MAX_LOG_LINE]u8{[_]u8{0} ** MAX_LOG_LINE} ** MAX_LOG_ENTRIES;
var log_lengths: [MAX_LOG_ENTRIES]usize = [_]usize{0} ** MAX_LOG_ENTRIES;
var log_levels: [MAX_LOG_ENTRIES]LogLevel = [_]LogLevel{.info} ** MAX_LOG_ENTRIES;
var log_count: usize = 0;
var log_head: usize = 0; // Next write position
var scroll_offset: usize = 0;
var cached_max_visible: usize = 10;

pub const LogLevel = enum {
    info,
    warn,
    err,
    debug,
};

/// Add a log entry
pub fn log(level: LogLevel, message: []const u8) void {
    const idx = log_head;

    // Copy message
    const copy_len = @min(message.len, MAX_LOG_LINE - 1);
    for (message[0..copy_len], 0..) |c, i| {
        log_buffer[idx][i] = c;
    }
    log_lengths[idx] = copy_len;
    log_levels[idx] = level;

    // Advance head
    log_head = (log_head + 1) % MAX_LOG_ENTRIES;
    if (log_count < MAX_LOG_ENTRIES) {
        log_count += 1;
    }
}

/// Log info message
pub fn info(message: []const u8) void {
    log(.info, message);
}

/// Log warning message
pub fn warn(message: []const u8) void {
    log(.warn, message);
}

/// Log error message
pub fn err(message: []const u8) void {
    log(.err, message);
}

/// Log debug message
pub fn debug(message: []const u8) void {
    log(.debug, message);
}

/// Draw log viewer content
pub fn draw(win: *const Window, x: i32, y: i32) void {
    const content_width = win.width - 8;
    const content_height = win.height - @as(u32, @intCast(TITLE_BAR_HEIGHT)) - 8;
    const header_height: u32 = 20;
    const status_height: u32 = 18;
    const list_height = content_height - header_height - status_height - 4;
    const max_visible: usize = @intCast(@max(1, @divTrunc(@as(i32, @intCast(list_height)), 14)));
    cached_max_visible = max_visible;

    // Header
    graphics.fillRect(x, y, content_width, header_height, Color.rgb(50, 55, 65));
    font.drawString(x + 4, y + 3, "System Logs", graphics.WHITE, null);

    // Log count
    var count_buf: [16]u8 = undefined;
    const count_len = formatNum(log_count, &count_buf);
    font.drawString(x + @as(i32, @intCast(content_width)) - 60, y + 3, count_buf[0..count_len], Color.rgb(150, 150, 160), null);
    font.drawString(x + @as(i32, @intCast(content_width)) - 40, y + 3, "entries", Color.rgb(150, 150, 160), null);

    // Log list area
    const list_y = y + @as(i32, @intCast(header_height)) + 2;
    graphics.fillRect(x, list_y, content_width, list_height, Color.rgb(25, 28, 35));
    graphics.drawRect(x, list_y, content_width, list_height, Color.rgb(60, 65, 75));

    if (log_count == 0) {
        font.drawString(x + 8, list_y + 16, "No log entries", Color.rgb(100, 100, 110), null);
        return;
    }

    // Draw log entries
    var row_y = list_y + 2;
    const row_height: i32 = 14;
    var displayed: usize = 0;

    // Calculate start index (oldest visible entry)
    var start_idx: usize = 0;
    if (log_count > max_visible + scroll_offset) {
        start_idx = log_count - max_visible - scroll_offset;
    }

    var i: usize = start_idx;
    while (i < log_count and displayed < max_visible) : (i += 1) {
        // Calculate actual buffer index
        const buf_idx = if (log_count >= MAX_LOG_ENTRIES)
            (log_head + i) % MAX_LOG_ENTRIES
        else
            i;

        // Level indicator color
        const level_color = switch (log_levels[buf_idx]) {
            .info => Color.rgb(80, 180, 120),
            .warn => Color.rgb(220, 180, 60),
            .err => Color.rgb(220, 80, 80),
            .debug => Color.rgb(100, 150, 220),
        };

        // Level indicator
        graphics.fillRect(x + 4, row_y + 2, 4, 10, level_color);

        // Log message
        const msg_len = log_lengths[buf_idx];
        if (msg_len > 0) {
            const max_chars: usize = @intCast(@max(10, @divTrunc(@as(i32, @intCast(content_width)) - 20, 6)));
            const display_len = @min(msg_len, max_chars);
            font.drawString(x + 12, row_y + 1, log_buffer[buf_idx][0..display_len], Color.rgb(200, 200, 210), null);
        }

        row_y += row_height;
        displayed += 1;
    }

    // Status bar
    const status_y = list_y + @as(i32, @intCast(list_height)) + 2;
    graphics.fillRect(x, status_y, content_width, status_height, Color.rgb(45, 48, 55));

    // Legend
    graphics.fillRect(x + 4, status_y + 4, 8, 8, Color.rgb(80, 180, 120));
    font.drawString(x + 14, status_y + 2, "Info", Color.rgb(150, 150, 160), null);

    graphics.fillRect(x + 50, status_y + 4, 8, 8, Color.rgb(220, 180, 60));
    font.drawString(x + 60, status_y + 2, "Warn", Color.rgb(150, 150, 160), null);

    graphics.fillRect(x + 100, status_y + 4, 8, 8, Color.rgb(220, 80, 80));
    font.drawString(x + 110, status_y + 2, "Err", Color.rgb(150, 150, 160), null);

    if (content_width > 180) {
        graphics.fillRect(x + 145, status_y + 4, 8, 8, Color.rgb(100, 150, 220));
        font.drawString(x + 155, status_y + 2, "Debug", Color.rgb(150, 150, 160), null);
    }
}

/// Handle keyboard input
pub fn handleKey(key: u8) void {
    const keyboard = @import("../../drivers/keyboard.zig");

    if (key == keyboard.KEY_UP or key == 'w' or key == 'W') {
        if (scroll_offset < log_count -| cached_max_visible) {
            scroll_offset += 1;
        }
    } else if (key == keyboard.KEY_DOWN or key == 's' or key == 'S') {
        if (scroll_offset > 0) {
            scroll_offset -= 1;
        }
    } else if (key == keyboard.KEY_PAGE_UP) {
        scroll_offset +|= cached_max_visible;
        if (scroll_offset > log_count -| cached_max_visible) {
            scroll_offset = log_count -| cached_max_visible;
        }
    } else if (key == keyboard.KEY_PAGE_DOWN) {
        if (scroll_offset >= cached_max_visible) {
            scroll_offset -= cached_max_visible;
        } else {
            scroll_offset = 0;
        }
    } else if (key == keyboard.KEY_HOME) {
        scroll_offset = log_count -| cached_max_visible;
    } else if (key == keyboard.KEY_END) {
        scroll_offset = 0;
    } else if (key == 'c' or key == 'C') {
        // Clear logs
        log_count = 0;
        log_head = 0;
        scroll_offset = 0;
    }
}

/// Handle scroll wheel
pub fn handleScroll(delta: i8) void {
    if (delta < 0) {
        // Scroll up (show older)
        const amount = @as(usize, @intCast(@abs(delta)));
        scroll_offset +|= amount;
        if (scroll_offset > log_count -| cached_max_visible) {
            scroll_offset = log_count -| cached_max_visible;
        }
    } else if (delta > 0) {
        // Scroll down (show newer)
        const amount = @as(usize, @intCast(@abs(delta)));
        if (scroll_offset >= amount) {
            scroll_offset -= amount;
        } else {
            scroll_offset = 0;
        }
    }
}

fn formatNum(val: usize, buf: []u8) usize {
    var v = val;
    var len: usize = 0;

    if (v == 0) {
        buf[0] = '0';
        return 1;
    }

    var digits: [10]u8 = undefined;
    var digit_count: usize = 0;
    while (v > 0) : (digit_count += 1) {
        digits[digit_count] = @truncate((v % 10) + '0');
        v /= 10;
    }
    while (digit_count > 0) {
        digit_count -= 1;
        buf[len] = digits[digit_count];
        len += 1;
    }

    return len;
}

/// Initialize with some system logs
pub fn initSystemLogs() void {
    info("Home OS v0.24.0 started");
    info("GDT initialized");
    info("IDT initialized");
    info("Paging enabled (4MB pages)");
    info("PMM ready");
    info("VMM ready");
    info("PIC configured");
    info("PIT timer @ 100Hz");
    info("Heap initialized");
    info("ATA disk detected");
    info("FAT32 filesystem mounted");
    info("Network stack ready");
    info("Desktop started");
}
