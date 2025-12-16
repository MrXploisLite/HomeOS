// Home OS - Calendar App
// Copyright © 2025 Romy Rianata - Home OS
// Month view calendar with current date highlight

const graphics = @import("../../drivers/graphics.zig");
const font = @import("../../drivers/font.zig");
const rtc = @import("../../drivers/rtc.zig");
const window = @import("../window.zig");
const Window = window.Window;

const TITLE_BAR_HEIGHT = window.TITLE_BAR_HEIGHT;

// Current view month/year
var view_month: u8 = 0;
var view_year: u16 = 0;
var initialized: bool = false;

const month_names = [_][]const u8{
    "January", "February", "March",     "April",   "May",      "June",
    "July",    "August",   "September", "October", "November", "December",
};

const day_names = [_][]const u8{ "Su", "Mo", "Tu", "We", "Th", "Fr", "Sa" };

pub fn draw(win: *const Window, x: i32, y: i32) void {
    const content_w = win.width - 8;
    const content_h = win.height - @as(u32, @intCast(TITLE_BAR_HEIGHT)) - 8;

    // Initialize to current month if not set
    if (!initialized) {
        const dt = rtc.getDateTime();
        view_month = dt.month;
        view_year = dt.year;
        initialized = true;
    }

    // Background
    graphics.fillRect(x, y, content_w, content_h, graphics.WHITE);

    // Header with month/year
    graphics.fillRect(x, y, content_w, 24, graphics.Color.rgb(50, 120, 200));

    // Navigation arrows
    font.drawString(x + 8, y + 6, "<", graphics.WHITE, null);
    font.drawString(x + @as(i32, @intCast(content_w)) - 16, y + 6, ">", graphics.WHITE, null);

    // Month name and year
    const month_idx = if (view_month > 0 and view_month <= 12) view_month - 1 else 0;
    const month_name = month_names[month_idx];
    var header_buf: [20]u8 = undefined;
    var header_len: usize = 0;
    for (month_name) |c| {
        header_buf[header_len] = c;
        header_len += 1;
    }
    header_buf[header_len] = ' ';
    header_len += 1;
    header_len += formatYear(view_year, header_buf[header_len..]);

    const header_x = x + @as(i32, @intCast(content_w / 2)) - @as(i32, @intCast(header_len * 4));
    font.drawString(header_x, y + 6, header_buf[0..header_len], graphics.WHITE, null);

    // Day headers
    const cell_w: i32 = @intCast(@max(20, @divTrunc(content_w, 7)));
    const day_y = y + 28;
    var dx: i32 = x;
    for (day_names) |day| {
        font.drawString(dx + 4, day_y, day, graphics.Color.rgb(100, 100, 105), null);
        dx += cell_w;
    }

    // Separator
    graphics.drawLine(x, day_y + 14, x + @as(i32, @intCast(content_w)), day_y + 14, graphics.Color.rgb(220, 220, 225));

    // Calendar grid
    const first_day = getDayOfWeek(view_year, view_month, 1);
    const days_in_month = getDaysInMonth(view_year, view_month);
    const dt = rtc.getDateTime();
    const is_current_month = (view_month == dt.month and view_year == dt.year);

    var cell_y = day_y + 18;
    var day: u8 = 1;
    var row: usize = 0;

    while (day <= days_in_month and row < 6) : (row += 1) {
        var col: usize = 0;
        while (col < 7) : (col += 1) {
            const cell_x = x + @as(i32, @intCast(col)) * cell_w;

            if (row == 0 and col < first_day) {
                // Empty cell before first day
            } else if (day <= days_in_month) {
                // Draw day number
                const is_today = is_current_month and day == dt.day;
                const is_weekend = (col == 0 or col == 6);

                if (is_today) {
                    // Highlight today
                    graphics.fillRect(cell_x + 2, cell_y, @intCast(cell_w - 4), 16, graphics.Color.rgb(50, 120, 200));
                }

                var day_buf: [2]u8 = undefined;
                const day_len = formatDay(day, &day_buf);
                const text_color = if (is_today) graphics.WHITE else if (is_weekend) graphics.Color.rgb(200, 100, 100) else graphics.BLACK;
                font.drawString(cell_x + 6, cell_y + 2, day_buf[0..day_len], text_color, null);

                day += 1;
            }
            col += 1;
        }
        cell_y += 18;
    }

    // Footer with today's date
    if (content_h > 180) {
        const footer_y = y + @as(i32, @intCast(content_h)) - 16;
        font.drawString(x + 4, footer_y, "Today:", graphics.GRAY, null);
        var today_buf: [12]u8 = undefined;
        const today_len = formatDate(dt.day, dt.month, dt.year, &today_buf);
        font.drawString(x + 52, footer_y, today_buf[0..today_len], graphics.DARK_GRAY, null);
    }
}

pub fn handleKey(key: u8) void {
    if (key == '-' or key == '[') {
        // Previous month
        if (view_month > 1) {
            view_month -= 1;
        } else {
            view_month = 12;
            if (view_year > 2000) view_year -= 1;
        }
    } else if (key == '+' or key == '=' or key == ']') {
        // Next month
        if (view_month < 12) {
            view_month += 1;
        } else {
            view_month = 1;
            if (view_year < 2099) view_year += 1;
        }
    } else if (key == 't' or key == 'T') {
        // Go to today
        const dt = rtc.getDateTime();
        view_month = dt.month;
        view_year = dt.year;
    }
}

pub fn handleClick(win: *const Window, mx: i32, my: i32) void {
    const content_x = win.x + 4;
    const content_y = win.y + TITLE_BAR_HEIGHT + 4;
    const content_w = win.width - 8;

    // Check header navigation
    if (my >= content_y and my < content_y + 24) {
        if (mx >= content_x and mx < content_x + 24) {
            // Left arrow - previous month
            if (view_month > 1) {
                view_month -= 1;
            } else {
                view_month = 12;
                if (view_year > 2000) view_year -= 1;
            }
        } else if (mx >= content_x + @as(i32, @intCast(content_w)) - 24) {
            // Right arrow - next month
            if (view_month < 12) {
                view_month += 1;
            } else {
                view_month = 1;
                if (view_year < 2099) view_year += 1;
            }
        }
    }
}

fn getDayOfWeek(year: u16, month: u8, day: u8) usize {
    // Zeller's congruence (simplified)
    var y = year;
    var m = month;
    if (m < 3) {
        m += 12;
        y -= 1;
    }
    const q = day;
    const k = @as(u32, y) % 100;
    const j = @as(u32, y) / 100;
    const h = (@as(u32, q) + (13 * (@as(u32, m) + 1)) / 5 + k + k / 4 + j / 4 + 5 * j) % 7;
    // Convert to Sunday=0
    return @as(usize, (h + 6) % 7);
}

fn getDaysInMonth(year: u16, month: u8) u8 {
    const days = [_]u8{ 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };
    if (month < 1 or month > 12) return 30;
    var d = days[month - 1];
    // Leap year check for February
    if (month == 2) {
        if ((year % 4 == 0 and year % 100 != 0) or (year % 400 == 0)) {
            d = 29;
        }
    }
    return d;
}

fn formatYear(year: u16, buf: []u8) usize {
    buf[0] = '0' + @as(u8, @truncate(year / 1000));
    buf[1] = '0' + @as(u8, @truncate((year / 100) % 10));
    buf[2] = '0' + @as(u8, @truncate((year / 10) % 10));
    buf[3] = '0' + @as(u8, @truncate(year % 10));
    return 4;
}

fn formatDay(day: u8, buf: []u8) usize {
    if (day < 10) {
        buf[0] = '0' + day;
        return 1;
    }
    buf[0] = '0' + day / 10;
    buf[1] = '0' + day % 10;
    return 2;
}

fn formatDate(day: u8, month: u8, year: u16, buf: []u8) usize {
    var len: usize = 0;
    len += formatDay(day, buf[len..]);
    buf[len] = '/';
    len += 1;
    len += formatDay(month, buf[len..]);
    buf[len] = '/';
    len += 1;
    len += formatYear(year, buf[len..]);
    return len;
}
