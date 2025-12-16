// Home OS - Real-Time Clock (RTC) Driver
// Copyright © 2025 Romy Rianata - Home OS
// CMOS RTC for date/time

const io = @import("../arch/io.zig");
const serial = @import("serial.zig");

// CMOS ports
const CMOS_ADDR: u16 = 0x70;
const CMOS_DATA: u16 = 0x71;

// CMOS registers
const RTC_SECONDS: u8 = 0x00;
const RTC_MINUTES: u8 = 0x02;
const RTC_HOURS: u8 = 0x04;
const RTC_WEEKDAY: u8 = 0x06;
const RTC_DAY: u8 = 0x07;
const RTC_MONTH: u8 = 0x08;
const RTC_YEAR: u8 = 0x09;
const RTC_CENTURY: u8 = 0x32; // May not exist on all systems
const RTC_STATUS_A: u8 = 0x0A;
const RTC_STATUS_B: u8 = 0x0B;

pub const DateTime = struct {
    year: u16,
    month: u8,
    day: u8,
    hour: u8,
    minute: u8,
    second: u8,
    weekday: u8,
};

var initialized: bool = false;

// Cached datetime for performance (RTC reads are slow)
var cached_datetime: DateTime = undefined;
var cache_valid: bool = false;
var last_cache_tick: u32 = 0;
const CACHE_DURATION: u32 = 100; // Cache for 100 ticks (1 second at 100Hz)

/// Read CMOS register
fn readCmos(reg: u8) u8 {
    io.outb(CMOS_ADDR, reg);
    return io.inb(CMOS_DATA);
}

/// Check if RTC update in progress
fn isUpdateInProgress() bool {
    io.outb(CMOS_ADDR, RTC_STATUS_A);
    return (io.inb(CMOS_DATA) & 0x80) != 0;
}

/// Convert BCD to binary
fn bcdToBinary(bcd: u8) u8 {
    return ((bcd >> 4) * 10) + (bcd & 0x0F);
}

/// Initialize RTC
pub fn init() void {
    serial.write("RTC: Initializing...\n");
    initialized = true;
    serial.write("RTC: Ready\n");
}

/// Get current date/time (cached for performance)
pub fn getDateTime() DateTime {
    const pit = @import("pit.zig");
    const current_tick = pit.getTicks();

    // Return cached value if still valid
    if (cache_valid and (current_tick -% last_cache_tick) < CACHE_DURATION) {
        return cached_datetime;
    }

    // Read fresh value from RTC
    cached_datetime = readDateTimeFromHardware();
    cache_valid = true;
    last_cache_tick = current_tick;

    return cached_datetime;
}

/// Force refresh of cached datetime
pub fn invalidateCache() void {
    cache_valid = false;
}

/// Read datetime directly from RTC hardware (slow)
fn readDateTimeFromHardware() DateTime {
    // Wait for update to complete
    while (isUpdateInProgress()) {}

    // Read values
    var second = readCmos(RTC_SECONDS);
    var minute = readCmos(RTC_MINUTES);
    var hour = readCmos(RTC_HOURS);
    var day = readCmos(RTC_DAY);
    var month = readCmos(RTC_MONTH);
    var year = readCmos(RTC_YEAR);
    const weekday = readCmos(RTC_WEEKDAY);

    // Check status register B for format
    const status_b = readCmos(RTC_STATUS_B);
    const is_bcd = (status_b & 0x04) == 0;
    const is_24h = (status_b & 0x02) != 0;

    // Convert BCD to binary if needed
    if (is_bcd) {
        second = bcdToBinary(second);
        minute = bcdToBinary(minute);
        hour = bcdToBinary(hour & 0x7F); // Mask PM bit
        day = bcdToBinary(day);
        month = bcdToBinary(month);
        year = bcdToBinary(year);
    }

    // Handle 12-hour format
    if (!is_24h and (hour & 0x80) != 0) {
        hour = ((hour & 0x7F) + 12) % 24;
    }

    // Calculate full year (assume 2000s)
    const full_year: u16 = 2000 + @as(u16, year);

    return DateTime{
        .year = full_year,
        .month = month,
        .day = day,
        .hour = hour,
        .minute = minute,
        .second = second,
        .weekday = weekday,
    };
}

/// Get time string "HH:MM:SS"
pub fn getTimeString(buf: []u8) usize {
    const dt = getDateTime();
    if (buf.len < 8) return 0;

    buf[0] = '0' + @as(u8, @truncate(dt.hour / 10));
    buf[1] = '0' + @as(u8, @truncate(dt.hour % 10));
    buf[2] = ':';
    buf[3] = '0' + @as(u8, @truncate(dt.minute / 10));
    buf[4] = '0' + @as(u8, @truncate(dt.minute % 10));
    buf[5] = ':';
    buf[6] = '0' + @as(u8, @truncate(dt.second / 10));
    buf[7] = '0' + @as(u8, @truncate(dt.second % 10));

    return 8;
}

/// Get short time string "HH:MM"
pub fn getShortTimeString(buf: []u8) usize {
    const dt = getDateTime();
    if (buf.len < 5) return 0;

    buf[0] = '0' + @as(u8, @truncate(dt.hour / 10));
    buf[1] = '0' + @as(u8, @truncate(dt.hour % 10));
    buf[2] = ':';
    buf[3] = '0' + @as(u8, @truncate(dt.minute / 10));
    buf[4] = '0' + @as(u8, @truncate(dt.minute % 10));

    return 5;
}

/// Get date string "YYYY-MM-DD"
pub fn getDateString(buf: []u8) usize {
    const dt = getDateTime();
    if (buf.len < 10) return 0;

    buf[0] = '0' + @as(u8, @truncate(dt.year / 1000));
    buf[1] = '0' + @as(u8, @truncate((dt.year / 100) % 10));
    buf[2] = '0' + @as(u8, @truncate((dt.year / 10) % 10));
    buf[3] = '0' + @as(u8, @truncate(dt.year % 10));
    buf[4] = '-';
    buf[5] = '0' + @as(u8, @truncate(dt.month / 10));
    buf[6] = '0' + @as(u8, @truncate(dt.month % 10));
    buf[7] = '-';
    buf[8] = '0' + @as(u8, @truncate(dt.day / 10));
    buf[9] = '0' + @as(u8, @truncate(dt.day % 10));

    return 10;
}

/// Get short date string "DD/MM"
pub fn getShortDateString(buf: []u8) usize {
    const dt = getDateTime();
    if (buf.len < 5) return 0;

    buf[0] = '0' + @as(u8, @truncate(dt.day / 10));
    buf[1] = '0' + @as(u8, @truncate(dt.day % 10));
    buf[2] = '/';
    buf[3] = '0' + @as(u8, @truncate(dt.month / 10));
    buf[4] = '0' + @as(u8, @truncate(dt.month % 10));

    return 5;
}

/// Get weekday name
pub fn getWeekdayName(weekday: u8) []const u8 {
    return switch (weekday) {
        1 => "Sunday",
        2 => "Monday",
        3 => "Tuesday",
        4 => "Wednesday",
        5 => "Thursday",
        6 => "Friday",
        7 => "Saturday",
        else => "Unknown",
    };
}

/// Get month name
pub fn getMonthName(month: u8) []const u8 {
    return switch (month) {
        1 => "January",
        2 => "February",
        3 => "March",
        4 => "April",
        5 => "May",
        6 => "June",
        7 => "July",
        8 => "August",
        9 => "September",
        10 => "October",
        11 => "November",
        12 => "December",
        else => "Unknown",
    };
}

pub fn isInitialized() bool {
    return initialized;
}

/// Get full date string "DD Mon YYYY"
pub fn getFullDateString(buf: []u8) usize {
    const dt = getDateTime();
    if (buf.len < 12) return 0;

    var pos: usize = 0;

    // Day
    buf[pos] = '0' + @as(u8, @truncate(dt.day / 10));
    pos += 1;
    buf[pos] = '0' + @as(u8, @truncate(dt.day % 10));
    pos += 1;
    buf[pos] = ' ';
    pos += 1;

    // Month name (short)
    const month_names = [_][]const u8{ "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" };
    if (dt.month >= 1 and dt.month <= 12) {
        const name = month_names[dt.month - 1];
        for (name) |c| {
            buf[pos] = c;
            pos += 1;
        }
    }
    buf[pos] = ' ';
    pos += 1;

    // Year
    buf[pos] = '0' + @as(u8, @truncate(dt.year / 1000));
    pos += 1;
    buf[pos] = '0' + @as(u8, @truncate((dt.year / 100) % 10));
    pos += 1;
    buf[pos] = '0' + @as(u8, @truncate((dt.year / 10) % 10));
    pos += 1;
    buf[pos] = '0' + @as(u8, @truncate(dt.year % 10));
    pos += 1;

    return pos;
}

/// Get full time string "HH:MM:SS"
pub fn getFullTimeString(buf: []u8) usize {
    return getTimeString(buf);
}

/// Get day of week (0=Sunday, 6=Saturday)
pub fn getDayOfWeek() u8 {
    const dt = getDateTime();
    // RTC weekday is 1-7, convert to 0-6
    if (dt.weekday >= 1 and dt.weekday <= 7) {
        return dt.weekday - 1;
    }
    return 0;
}
