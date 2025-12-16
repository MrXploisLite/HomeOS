// Home OS - Task Manager App
// Copyright © 2025 Romy Rianata - Home OS
// Shows running processes and system resources

const graphics = @import("../../drivers/graphics.zig");
const font = @import("../../drivers/font.zig");
const window = @import("../window.zig");
const Window = window.Window;
const task = @import("../../proc/task.zig");
const pmm = @import("../../mm/pmm.zig");
const heap = @import("../../mm/heap.zig");
const pit = @import("../../drivers/pit.zig");
const desktop = @import("../desktop.zig");

const tabs = [_][]const u8{ "Processes", "Windows", "Perf", "Memory", "Network" };

pub fn draw(win: *const Window, x: i32, y: i32) void {
    const current_tab = win.taskmanager_tab;
    const content_w = win.width - 8;
    const content_h = win.height - @as(u32, @intCast(window.TITLE_BAR_HEIGHT)) - 8;

    // Title
    font.drawString(x, y, "Task Manager", graphics.BLACK, null);
    graphics.drawLine(x, y + 12, x + @as(i32, @intCast(content_w)), y + 12, graphics.DARK_GRAY);

    // Tabs with modern styling (responsive width for 5 tabs)
    const tab_w: i32 = @intCast(@max(40, @min(60, @divTrunc(content_w, 5) - 2)));
    var tab_x = x;
    for (tabs, 0..) |tab, i| {
        const is_selected = (i == current_tab);
        const bg = if (is_selected) graphics.Color.rgb(50, 120, 200) else graphics.Color.rgb(230, 230, 235);
        const fg = if (is_selected) graphics.WHITE else graphics.DARK_GRAY;

        graphics.fillRect(tab_x, y + 18, @intCast(tab_w), 20, bg);
        if (is_selected) {
            graphics.fillRect(tab_x, y + 36, @intCast(tab_w), 2, graphics.Color.rgb(50, 120, 200));
        }
        font.drawString(tab_x + 4, y + 22, tab, fg, null);
        tab_x += tab_w + 2;
    }

    // Content area (responsive)
    const content_area_y = y + 42;
    const content_area_h: u32 = @max(100, content_h - 60);
    graphics.fillRect(x, content_area_y, content_w, content_area_h, graphics.WHITE);
    graphics.drawRect(x, content_area_y, content_w, content_area_h, graphics.Color.rgb(200, 200, 205));

    switch (current_tab) {
        0 => drawProcesses(x + 4, content_area_y + 4),
        1 => drawWindows(x + 4, content_area_y + 4),
        2 => drawPerformance(x + 4, content_area_y + 4),
        3 => drawMemory(x + 4, content_area_y + 4),
        4 => drawNetwork(x + 4, content_area_y + 4),
        else => {},
    }

    // Help text at bottom
    if (content_h > 200) {
        font.drawString(x, y + @as(i32, @intCast(content_h)) - 12, "Press 1-5 to switch tabs", graphics.DARK_GRAY, null);
    }
}

fn drawProcesses(x: i32, y: i32) void {
    // Header (compact layout)
    font.drawString(x, y, "PID", graphics.BLACK, null);
    font.drawString(x + 32, y, "Name", graphics.BLACK, null);
    font.drawString(x + 100, y, "State", graphics.BLACK, null);
    font.drawString(x + 160, y, "Ring", graphics.BLACK, null);
    graphics.drawLine(x, y + 12, x + 200, y + 12, graphics.DARK_GRAY);

    var line_y = y + 16;
    const count = task.getTaskCount();

    var i: usize = 0;
    while (i < count and i < 10) : (i += 1) {
        if (task.getTaskInfo(i)) |info| {
            // PID
            drawInt(x, line_y, info.id);

            // Name (truncate to 8 chars)
            const name = info.getName();
            const name_len = @min(name.len, 8);
            font.drawString(x + 32, line_y, name[0..name_len], graphics.DARK_GRAY, null);

            // State (short)
            const state_str = switch (info.state) {
                0 => "Rdy",
                1 => "Run",
                2 => "Blk",
                3 => "End",
                else => "?",
            };
            const state_color = switch (info.state) {
                1 => graphics.GREEN,
                2 => graphics.YELLOW,
                3 => graphics.RED,
                else => graphics.DARK_GRAY,
            };
            font.drawString(x + 100, line_y, state_str, state_color, null);

            // Ring (short)
            if (info.ring == 0) {
                font.drawString(x + 160, line_y, "K", graphics.CYAN, null);
            } else {
                font.drawString(x + 160, line_y, "U", graphics.DARK_GRAY, null);
            }

            line_y += 14;
        }
    }

    // Total
    line_y += 4;
    font.drawString(x, line_y, "Total:", graphics.BLACK, null);
    drawInt(x + 48, line_y, @truncate(count));
}

fn drawPerformance(x: i32, y: i32) void {
    font.drawString(x, y, "System Performance", graphics.BLACK, null);
    graphics.drawLine(x, y + 12, x + 280, y + 12, graphics.DARK_GRAY);

    var line_y = y + 20;

    // Uptime
    font.drawString(x, line_y, "Uptime: ", graphics.DARK_GRAY, null);
    const uptime = pit.getUptime();
    const hours = uptime / 3600;
    const mins = (uptime % 3600) / 60;
    const secs = uptime % 60;

    var pos_x = x + 64;
    if (hours > 0) {
        drawInt(pos_x, line_y, hours);
        pos_x += 24;
        font.drawString(pos_x, line_y, "h ", graphics.DARK_GRAY, null);
        pos_x += 16;
    }
    drawInt(pos_x, line_y, mins);
    pos_x += 16;
    font.drawString(pos_x, line_y, "m ", graphics.DARK_GRAY, null);
    pos_x += 16;
    drawInt(pos_x, line_y, secs);
    pos_x += 16;
    font.drawString(pos_x, line_y, "s", graphics.DARK_GRAY, null);

    line_y += 20;

    // Timer ticks
    font.drawString(x, line_y, "Timer Ticks: ", graphics.DARK_GRAY, null);
    drawInt(x + 104, line_y, pit.getTicks());

    line_y += 20;

    // CPU Usage (real measurement)
    font.drawString(x, line_y, "CPU Usage: ", graphics.DARK_GRAY, null);
    const cpu_usage = pit.getCpuUsage();
    var cpu_buf: [5]u8 = undefined;
    const cpu_len = formatPct(cpu_usage, &cpu_buf);
    const cpu_color = if (cpu_usage > 80) graphics.RED else if (cpu_usage > 50) graphics.YELLOW else graphics.GREEN;
    font.drawString(x + 88, line_y, cpu_buf[0..cpu_len], cpu_color, null);

    // CPU usage bar
    graphics.fillRect(x + 130, line_y, 80, 10, graphics.Color.rgb(200, 200, 205));
    const bar_width: u32 = (@as(u32, cpu_usage) * 80) / 100;
    if (bar_width > 0) {
        graphics.fillRect(x + 130, line_y, bar_width, 10, cpu_color);
    }
    graphics.drawRect(x + 130, line_y, 80, 10, graphics.DARK_GRAY);

    line_y += 20;

    // Interrupts enabled
    font.drawString(x, line_y, "Interrupts: ", graphics.DARK_GRAY, null);
    font.drawString(x + 96, line_y, "Enabled", graphics.GREEN, null);

    line_y += 20;

    // Idle ticks
    font.drawString(x, line_y, "Idle Ticks: ", graphics.DARK_GRAY, null);
    drawInt(x + 96, line_y, pit.getIdleTicks());
}

fn drawMemory(x: i32, y: i32) void {
    font.drawString(x, y, "Memory Usage", graphics.BLACK, null);
    graphics.drawLine(x, y + 12, x + 280, y + 12, graphics.DARK_GRAY);

    var line_y = y + 20;

    // Physical memory
    font.drawString(x, line_y, "Physical Memory:", graphics.BLACK, null);
    line_y += 16;

    const total_pages = pmm.getTotalPages();
    const free_pages = pmm.getFreePages();
    const used_pages = total_pages - free_pages;
    const total_mb = (total_pages * 4096) / (1024 * 1024);
    const used_mb = (used_pages * 4096) / (1024 * 1024);

    font.drawString(x + 8, line_y, "Total: ", graphics.DARK_GRAY, null);
    drawInt(x + 64, line_y, @truncate(total_mb));
    font.drawString(x + 96, line_y, " MB", graphics.DARK_GRAY, null);
    line_y += 14;

    font.drawString(x + 8, line_y, "Used:  ", graphics.DARK_GRAY, null);
    drawInt(x + 64, line_y, @truncate(used_mb));
    font.drawString(x + 96, line_y, " MB", graphics.DARK_GRAY, null);
    line_y += 14;

    font.drawString(x + 8, line_y, "Free:  ", graphics.DARK_GRAY, null);
    drawInt(x + 64, line_y, @truncate(total_mb - used_mb));
    font.drawString(x + 96, line_y, " MB", graphics.DARK_GRAY, null);
    line_y += 20;

    // Memory bar with gradient effect
    const bar_width: u32 = 200;
    // Use u64 to avoid overflow
    const used_width: u32 = if (total_pages > 0) @truncate((@as(u64, used_pages) * @as(u64, bar_width)) / @as(u64, total_pages)) else 0;
    graphics.fillRect(x + 8, line_y, bar_width, 16, graphics.Color.rgb(230, 230, 235));
    if (used_width > 0 and used_width <= bar_width) {
        // Gradient-like effect
        graphics.fillRect(x + 8, line_y, used_width, 8, graphics.Color.rgb(80, 200, 120));
        graphics.fillRect(x + 8, line_y + 8, used_width, 8, graphics.Color.rgb(60, 180, 100));
    }
    graphics.drawRect(x + 8, line_y, bar_width, 16, graphics.Color.rgb(180, 180, 185));
    // Percentage text - use u64 to avoid overflow
    const pct: u32 = if (total_pages > 0) @truncate((@as(u64, used_pages) * 100) / @as(u64, total_pages)) else 0;
    var pct_buf: [4]u8 = undefined;
    const pct_len = formatPct(pct, &pct_buf);
    font.drawString(x + 8 + @as(i32, @intCast(bar_width)) + 8, line_y + 2, pct_buf[0..pct_len], graphics.DARK_GRAY, null);

    line_y += 24;

    // Heap
    font.drawString(x, line_y, "Kernel Heap:", graphics.BLACK, null);
    line_y += 16;

    const heap_free = heap.getFreeMemory();
    font.drawString(x + 8, line_y, "Free: ", graphics.DARK_GRAY, null);
    drawInt(x + 56, line_y, @truncate(heap_free / 1024));
    font.drawString(x + 96, line_y, " KB", graphics.DARK_GRAY, null);
}

pub fn handleKey(win: *Window, key: u8) void {
    if (key >= '1' and key <= '5') {
        win.taskmanager_tab = key - '1';
    }
}

fn drawWindows(x: i32, y: i32) void {
    // Header
    font.drawString(x, y, "GUI Windows", graphics.BLACK, null);
    graphics.drawLine(x, y + 12, x + 200, y + 12, graphics.DARK_GRAY);

    var line_y = y + 16;
    const count = desktop.getWindowCount();

    if (count == 0) {
        font.drawString(x, line_y, "No windows open", graphics.GRAY, null);
        return;
    }

    // Count visible windows
    var visible_count: usize = 0;
    var i: usize = 0;
    while (i < count and visible_count < 10) : (i += 1) {
        if (desktop.getWindowInfo(i)) |info| {
            if (!info.visible) continue; // Skip invisible windows

            // Status indicator
            const status_color = if (info.focused) graphics.GREEN else if (info.minimized) graphics.YELLOW else graphics.Color.rgb(100, 150, 255);
            graphics.fillRect(x, line_y + 2, 8, 8, status_color);

            // Title (truncate to 14 chars)
            const title_len = @min(info.title.len, 14);
            font.drawString(x + 12, line_y, info.title[0..title_len], graphics.DARK_GRAY, null);

            // State with icon
            const state_str = if (info.focused) "[*]" else if (info.minimized) "[-]" else "[o]";
            font.drawString(x + 130, line_y, state_str, status_color, null);

            line_y += 14;
            visible_count += 1;
        }
    }

    // Total visible
    line_y += 4;
    font.drawString(x, line_y, "Visible:", graphics.BLACK, null);
    drawInt(x + 64, line_y, @truncate(visible_count));
    font.drawString(x + 100, line_y, "/", graphics.DARK_GRAY, null);
    drawInt(x + 110, line_y, @truncate(count));
}

/// Handle mouse click - check if clicking on tabs
pub fn handleClick(win: *Window, mx: i32, my: i32) void {
    const content_x = win.x + 4;
    const content_y = win.y + window.TITLE_BAR_HEIGHT + 4;
    const content_w = win.width - 8;

    // Tab area: y + 18, height 20, responsive tab width (must match draw())
    const tab_w: u32 = @max(40, @min(60, @divTrunc(content_w, 5) -| 2));
    const tab_spacing: u32 = tab_w + 2;
    const tab_y = content_y + 18;

    if (my >= tab_y and my < tab_y + 20) {
        const rel_x = mx - content_x;
        if (rel_x >= 0) {
            const rel_xu: u32 = @intCast(rel_x);
            // Check each tab individually to be precise
            var i: u8 = 0;
            while (i < tabs.len) : (i += 1) {
                const tab_start = @as(u32, i) * tab_spacing;
                const tab_end = tab_start + tab_w;
                if (rel_xu >= tab_start and rel_xu < tab_end) {
                    win.taskmanager_tab = i;
                    return;
                }
            }
        }
    }
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

fn formatPct(val: u32, buf: []u8) usize {
    var v = val;
    var len: usize = 0;
    if (v == 0) {
        buf[0] = '0';
        buf[1] = '%';
        return 2;
    }
    var digits: [3]u8 = undefined;
    var digit_count: usize = 0;
    while (v > 0 and digit_count < 3) : (digit_count += 1) {
        digits[digit_count] = @truncate((v % 10) + '0');
        v /= 10;
    }
    while (digit_count > 0) {
        digit_count -= 1;
        buf[len] = digits[digit_count];
        len += 1;
    }
    buf[len] = '%';
    return len + 1;
}

fn drawNetwork(x: i32, y: i32) void {
    const net = @import("../../net/net.zig");
    const rtl8139 = @import("../../net/rtl8139.zig");

    font.drawString(x, y, "Network Status", graphics.BLACK, null);
    graphics.drawLine(x, y + 12, x + 280, y + 12, graphics.DARK_GRAY);

    var line_y = y + 20;

    // NIC Status
    font.drawString(x, line_y, "Adapter: ", graphics.DARK_GRAY, null);
    if (rtl8139.isInitialized()) {
        font.drawString(x + 72, line_y, "RTL8139", graphics.GREEN, null);
    } else {
        font.drawString(x + 72, line_y, "None", graphics.RED, null);
    }
    line_y += 16;

    // IP Address
    font.drawString(x, line_y, "IP: ", graphics.DARK_GRAY, null);
    const ip = net.getLocalIp();
    var ip_buf: [16]u8 = undefined;
    const ip_len = formatIp(ip, &ip_buf);
    font.drawString(x + 32, line_y, ip_buf[0..ip_len], graphics.DARK_GRAY, null);
    line_y += 16;

    // MAC Address
    font.drawString(x, line_y, "MAC: ", graphics.DARK_GRAY, null);
    if (rtl8139.isInitialized()) {
        const mac = rtl8139.getMacAddress();
        var mac_buf: [18]u8 = undefined;
        const mac_len = formatMac(mac, &mac_buf);
        font.drawString(x + 40, line_y, mac_buf[0..mac_len], graphics.DARK_GRAY, null);
    }
    line_y += 16;

    // Packets
    const stats = net.getStats();
    font.drawString(x, line_y, "TX Packets: ", graphics.DARK_GRAY, null);
    drawInt(x + 96, line_y, stats.tx_packets);
    line_y += 14;

    font.drawString(x, line_y, "RX Packets: ", graphics.DARK_GRAY, null);
    drawInt(x + 96, line_y, stats.rx_packets);
    line_y += 16;

    // Firewall
    const firewall = @import("../../net/firewall.zig");
    font.drawString(x, line_y, "Firewall: ", graphics.DARK_GRAY, null);
    if (firewall.isEnabled()) {
        font.drawString(x + 80, line_y, "ON", graphics.GREEN, null);
    } else {
        font.drawString(x + 80, line_y, "OFF", graphics.YELLOW, null);
    }
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
    for (mac, 0..) |b, i| {
        buf[pos] = hex[b >> 4];
        buf[pos + 1] = hex[b & 0x0F];
        pos += 2;
        if (i < 5) {
            buf[pos] = ':';
            pos += 1;
        }
    }
    return pos;
}
