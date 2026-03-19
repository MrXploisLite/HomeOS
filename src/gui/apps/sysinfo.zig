// Home OS - System Info & About Apps
// Copyright © 2025 Romy Rianata - Home OS

const graphics = @import("../../drivers/graphics.zig");
const font = @import("../../drivers/font.zig");
const rtc = @import("../../drivers/rtc.zig");
const window = @import("../window.zig");

/// Draw System Info content (responsive)
pub fn drawSysInfo(win: *const window.Window, x: i32, y: i32) void {
    const content_h = win.height - @as(u32, @intCast(window.TITLE_BAR_HEIGHT)) - 8;
    const line_spacing: i32 = @intCast(@min(14, @max(10, content_h / 10)));

    var line_y = y;
    font.drawString(x, line_y, "Home OS System Information", graphics.BLACK, null);
    line_y += line_spacing + 6;

    font.drawString(x, line_y, "Architecture: x86 (32-bit)", graphics.DARK_GRAY, null);
    line_y += line_spacing;

    // Dynamic display resolution
    const vbe = @import("../../drivers/vbe.zig");
    font.drawString(x, line_y, "Display: ", graphics.DARK_GRAY, null);
    var res_buf: [20]u8 = undefined;
    var res_len: usize = 0;
    res_len = formatU32(vbe.getWidth(), res_buf[res_len..]);
    res_buf[res_len] = 'x';
    res_len += 1;
    res_len += formatU32(vbe.getHeight(), res_buf[res_len..]);
    res_buf[res_len] = 'x';
    res_len += 1;
    res_buf[res_len] = '3';
    res_len += 1;
    res_buf[res_len] = '2';
    res_len += 1;
    font.drawString(x + 72, line_y, res_buf[0..res_len], graphics.DARK_GRAY, null);
    line_y += line_spacing;

    // Get date/time
    const dt = rtc.getDateTime();
    var date_buf: [32]u8 = undefined;
    var date_len: usize = 0;

    const prefix = "Date: ";
    for (prefix) |c| {
        date_buf[date_len] = c;
        date_len += 1;
    }
    date_buf[date_len] = '0' + @as(u8, @truncate(dt.year / 1000));
    date_len += 1;
    date_buf[date_len] = '0' + @as(u8, @truncate((dt.year / 100) % 10));
    date_len += 1;
    date_buf[date_len] = '0' + @as(u8, @truncate((dt.year / 10) % 10));
    date_len += 1;
    date_buf[date_len] = '0' + @as(u8, @truncate(dt.year % 10));
    date_len += 1;
    date_buf[date_len] = '-';
    date_len += 1;
    date_buf[date_len] = '0' + dt.month / 10;
    date_len += 1;
    date_buf[date_len] = '0' + dt.month % 10;
    date_len += 1;
    date_buf[date_len] = '-';
    date_len += 1;
    date_buf[date_len] = '0' + dt.day / 10;
    date_len += 1;
    date_buf[date_len] = '0' + dt.day % 10;
    date_len += 1;

    font.drawString(x, line_y, date_buf[0..date_len], graphics.DARK_GRAY, null);
    line_y += line_spacing;

    // Time
    var time_buf: [16]u8 = undefined;
    var time_len: usize = 0;
    const time_prefix = "Time: ";
    for (time_prefix) |c| {
        time_buf[time_len] = c;
        time_len += 1;
    }
    time_buf[time_len] = '0' + dt.hour / 10;
    time_len += 1;
    time_buf[time_len] = '0' + dt.hour % 10;
    time_len += 1;
    time_buf[time_len] = ':';
    time_len += 1;
    time_buf[time_len] = '0' + dt.minute / 10;
    time_len += 1;
    time_buf[time_len] = '0' + dt.minute % 10;
    time_len += 1;
    time_buf[time_len] = ':';
    time_len += 1;
    time_buf[time_len] = '0' + dt.second / 10;
    time_len += 1;
    time_buf[time_len] = '0' + dt.second % 10;
    time_len += 1;

    font.drawString(x, line_y, time_buf[0..time_len], graphics.DARK_GRAY, null);
    line_y += line_spacing + 6;

    font.drawString(x, line_y, "Press ESC to exit GUI", graphics.BLUE, null);
}

/// Draw About content with system specs (responsive)
pub fn drawAbout(win: *const window.Window, x: i32, y: i32) void {
    const pmm = @import("../../mm/pmm.zig");
    const vbe = @import("../../drivers/vbe.zig");
    const net = @import("../../net/net.zig");
    const pit = @import("../../drivers/pit.zig");

    const content_w = win.width - 8;
    const content_h = win.height - @as(u32, @intCast(window.TITLE_BAR_HEIGHT)) - 8;
    const line_spacing: i32 = @intCast(@min(12, @max(10, content_h / 12)));

    var line_y = y;

    // Title
    font.drawString(x, line_y, "Home OS", graphics.Color.rgb(50, 120, 200), null);
    font.drawString(x + 64, line_y, "v0.32.0", graphics.DARK_GRAY, null);
    line_y += line_spacing;
    font.drawString(x, line_y, "Kernel: Ciko v0.1", graphics.DARK_GRAY, null);
    line_y += line_spacing + 6;

    // Separator
    graphics.drawLine(x, line_y, x + @as(i32, @intCast(@min(250, content_w - 10))), line_y, graphics.Color.rgb(200, 200, 205));
    line_y += 6;

    // System specs (dynamic)
    const cpu_info = "CPU: x86 (i386) 32-bit (QEMU/TCG)";
    font.drawString(x, line_y, cpu_info, graphics.DARK_GRAY, null);
    line_y += line_spacing;

    // Memory
    const total_mb = pmm.getTotalMemory() / (1024 * 1024);
    const free_mb = pmm.getFreeMemory() / (1024 * 1024);
    font.drawString(x, line_y, "RAM: ", graphics.DARK_GRAY, null);
    drawInt(x + 40, line_y, @truncate(free_mb));
    font.drawString(x + 64, line_y, "/", graphics.DARK_GRAY, null);
    drawInt(x + 72, line_y, @truncate(total_mb));
    font.drawString(x + 104, line_y, "MB free", graphics.DARK_GRAY, null);
    line_y += line_spacing;

    // Display
    font.drawString(x, line_y, "Display: ", graphics.DARK_GRAY, null);
    var res_buf: [20]u8 = undefined;
    const res_len = formatRes(vbe.getWidth(), vbe.getHeight(), &res_buf);
    font.drawString(x + 72, line_y, res_buf[0..res_len], graphics.DARK_GRAY, null);
    line_y += line_spacing;

    // Network
    font.drawString(x, line_y, "Network: ", graphics.DARK_GRAY, null);
    if (net.hasNic()) {
        font.drawString(x + 72, line_y, "RTL8139", graphics.GREEN, null);
    } else {
        font.drawString(x + 72, line_y, "No NIC", graphics.RED, null);
    }
    line_y += line_spacing;

    // IP Address
    if (net.hasNic()) {
        font.drawString(x, line_y, "IP: ", graphics.DARK_GRAY, null);
        var ip_buf: [16]u8 = undefined;
        const ip_len = formatIp(net.getLocalIp(), &ip_buf);
        font.drawString(x + 32, line_y, ip_buf[0..ip_len], graphics.DARK_GRAY, null);
        line_y += line_spacing;

        // MAC Address
        const rtl8139 = @import("../../net/rtl8139.zig");
        font.drawString(x, line_y, "MAC: ", graphics.DARK_GRAY, null);
        var mac_buf: [18]u8 = undefined;
        const mac_len = formatMac(rtl8139.getMacAddress(), &mac_buf);
        font.drawString(x + 40, line_y, mac_buf[0..mac_len], graphics.DARK_GRAY, null);
        line_y += line_spacing;
    }

    // CPU Usage
    const cpu_usage = pit.getCpuUsage();
    font.drawString(x, line_y, "CPU: ", graphics.DARK_GRAY, null);
    drawInt(x + 40, line_y, @as(u32, cpu_usage));
    font.drawString(x + 64, line_y, "%", graphics.DARK_GRAY, null);
    const cpu_color = if (cpu_usage > 80) graphics.RED else if (cpu_usage > 50) graphics.YELLOW else graphics.GREEN;
    graphics.fillRect(x + 80, line_y, 60, 10, graphics.Color.rgb(200, 200, 205));
    const bar_w: u32 = (@as(u32, cpu_usage) * 60) / 100;
    if (bar_w > 0) graphics.fillRect(x + 80, line_y, bar_w, 10, cpu_color);
    graphics.drawRect(x + 80, line_y, 60, 10, graphics.DARK_GRAY);
    line_y += line_spacing;

    // Uptime
    const uptime_secs = pit.getUptime();
    const hours = uptime_secs / 3600;
    const mins = (uptime_secs % 3600) / 60;
    const secs = uptime_secs % 60;
    font.drawString(x, line_y, "Uptime: ", graphics.DARK_GRAY, null);
    drawInt(x + 64, line_y, @truncate(hours));
    font.drawString(x + 80, line_y, "h ", graphics.DARK_GRAY, null);
    drawInt(x + 96, line_y, @truncate(mins));
    font.drawString(x + 112, line_y, "m ", graphics.DARK_GRAY, null);
    drawInt(x + 128, line_y, @truncate(secs));
    font.drawString(x + 144, line_y, "s", graphics.DARK_GRAY, null);
    line_y += line_spacing;

    // Disk usage
    const ata = @import("../../drivers/ata.zig");
    if (ata.hasDrive()) {
        const disk_mb = ata.getDiskSize() / 1024 / 1024;
        font.drawString(x, line_y, "Disk: ", graphics.DARK_GRAY, null);
        drawInt(x + 48, line_y, @truncate(disk_mb));
        font.drawString(x + 80, line_y, "MB", graphics.DARK_GRAY, null);
    }
    line_y += line_spacing + 4;

    // Separator
    graphics.drawLine(x, line_y, x + @as(i32, @intCast(@min(250, content_w - 10))), line_y, graphics.Color.rgb(200, 200, 205));
    line_y += 6;

    // Copyright
    font.drawString(x, line_y, "(C) 2025 Romy Rianata", graphics.GRAY, null);
    line_y += line_spacing;
    font.drawString(x, line_y, "Privacy-focused hobby OS", graphics.GRAY, null);
}

fn formatRes(w: u32, h: u32, buf: []u8) usize {
    var pos: usize = 0;
    pos += formatU32(w, buf[pos..]);
    buf[pos] = 'x';
    pos += 1;
    pos += formatU32(h, buf[pos..]);
    return pos;
}

fn formatU32(val: u32, buf: []u8) usize {
    if (val == 0) {
        buf[0] = '0';
        return 1;
    }
    var v = val;
    var len: usize = 0;
    var temp: [10]u8 = undefined;
    while (v > 0 and len < 10) : (len += 1) {
        temp[len] = @truncate((v % 10) + '0');
        v /= 10;
    }
    var i: usize = 0;
    while (i < len) : (i += 1) {
        buf[i] = temp[len - 1 - i];
    }
    return len;
}

fn drawInt(x: i32, y: i32, value: u32) void {
    var buf: [10]u8 = undefined;
    var len: usize = 0;
    var v = value;

    if (v == 0) {
        font.drawString(x, y, "0", graphics.DARK_GRAY, null);
        return;
    }

    while (v > 0 and len < 10) : (len += 1) {
        buf[9 - len] = @truncate((v % 10) + '0');
        v /= 10;
    }

    font.drawString(x, y, buf[10 - len .. 10], graphics.DARK_GRAY, null);
}

fn formatIp(ip: [4]u8, buf: []u8) usize {
    var pos: usize = 0;
    for (ip, 0..) |octet, i| {
        if (octet >= 100) {
            buf[pos] = '0' + octet / 100;
            pos += 1;
        }
        if (octet >= 10) {
            buf[pos] = '0' + (octet / 10) % 10;
            pos += 1;
        }
        buf[pos] = '0' + octet % 10;
        pos += 1;
        if (i < 3) {
            buf[pos] = '.';
            pos += 1;
        }
    }
    return pos;
}

fn formatMac(mac: [6]u8, buf: []u8) usize {
    const hex = "0123456789ABCDEF";
    var pos: usize = 0;
    for (mac, 0..) |byte, i| {
        buf[pos] = hex[byte >> 4];
        pos += 1;
        buf[pos] = hex[byte & 0x0F];
        pos += 1;
        if (i < 5) {
            buf[pos] = ':';
            pos += 1;
        }
    }
    return pos;
}
