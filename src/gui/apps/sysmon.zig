// Home OS - System Monitor App
// Copyright © 2025 Romy Rianata - Home OS
// Real-time CPU, Memory, and Disk monitoring

const graphics = @import("../../drivers/graphics.zig");
const font = @import("../../drivers/font.zig");
const window = @import("../window.zig");
const Window = window.Window;
const pit = @import("../../drivers/pit.zig");
const pmm = @import("../../mm/pmm.zig");
const ata = @import("../../drivers/ata.zig");

const TITLE_BAR_HEIGHT = window.TITLE_BAR_HEIGHT;

// History for graphs
const HISTORY_SIZE: usize = 60;
var cpu_history: [HISTORY_SIZE]u8 = [_]u8{0} ** HISTORY_SIZE;
var mem_history: [HISTORY_SIZE]u8 = [_]u8{0} ** HISTORY_SIZE;
var history_idx: usize = 0;
var last_update_tick: u32 = 0;

pub fn draw(win: *const Window, x: i32, y: i32) void {
    const content_w = win.width - 8;
    const content_h = win.height - @as(u32, @intCast(TITLE_BAR_HEIGHT)) - 8;

    // Update history every second
    const current_tick = pit.getTicks();
    if (current_tick -% last_update_tick >= 100) {
        last_update_tick = current_tick;
        cpu_history[history_idx] = pit.getCpuUsage();
        const total = pmm.getTotalPages();
        const free = pmm.getFreePages();
        // Safe calculation: ensure free <= total to avoid underflow
        const used = if (free <= total) total - free else 0;
        // Use u64 to avoid overflow in multiplication
        const used_pct: u8 = if (total > 0) @truncate((@as(u64, used) * 100) / @as(u64, total)) else 0;
        mem_history[history_idx] = used_pct;
        history_idx = (history_idx + 1) % HISTORY_SIZE;
    }

    // Background
    graphics.fillRect(x, y, content_w, content_h, graphics.Color.rgb(30, 30, 35));

    var line_y = y + 4;

    // CPU Section
    font.drawString(x + 4, line_y, "CPU Usage", graphics.WHITE, null);
    const cpu_usage = pit.getCpuUsage();
    var cpu_buf: [5]u8 = undefined;
    const cpu_len = formatPct(cpu_usage, &cpu_buf);
    const cpu_color = if (cpu_usage > 80) graphics.RED else if (cpu_usage > 50) graphics.YELLOW else graphics.GREEN;
    font.drawString(x + @as(i32, @intCast(content_w)) - 40, line_y, cpu_buf[0..cpu_len], cpu_color, null);
    line_y += 14;

    // CPU Graph
    const graph_w: u32 = content_w - 8;
    const graph_h: u32 = 40;
    graphics.fillRect(x + 4, line_y, graph_w, graph_h, graphics.Color.rgb(20, 20, 25));
    graphics.drawRect(x + 4, line_y, graph_w, graph_h, graphics.Color.rgb(60, 60, 65));
    drawGraph(x + 4, line_y, graph_w, graph_h, &cpu_history, graphics.Color.rgb(100, 200, 100));
    line_y += @as(i32, @intCast(graph_h)) + 8;

    // Memory Section
    font.drawString(x + 4, line_y, "Memory Usage", graphics.WHITE, null);
    const total_mb = pmm.getTotalMemory() / (1024 * 1024);
    const free_mb = pmm.getFreeMemory() / (1024 * 1024);
    // Safe subtraction to avoid underflow
    const used_mb = if (free_mb <= total_mb) total_mb - free_mb else 0;
    var mem_buf: [16]u8 = undefined;
    const mem_len = formatMemory(used_mb, total_mb, &mem_buf);
    font.drawString(x + @as(i32, @intCast(content_w)) - 80, line_y, mem_buf[0..mem_len], graphics.CYAN, null);
    line_y += 14;

    // Memory Graph
    graphics.fillRect(x + 4, line_y, graph_w, graph_h, graphics.Color.rgb(20, 20, 25));
    graphics.drawRect(x + 4, line_y, graph_w, graph_h, graphics.Color.rgb(60, 60, 65));
    drawGraph(x + 4, line_y, graph_w, graph_h, &mem_history, graphics.Color.rgb(100, 150, 255));
    line_y += @as(i32, @intCast(graph_h)) + 8;

    // Memory Bar
    const bar_w: u32 = content_w - 8;
    graphics.fillRect(x + 4, line_y, bar_w, 12, graphics.Color.rgb(50, 50, 55));
    // Safe calculation using u64 to avoid overflow
    const used_w: u32 = if (total_mb > 0) @truncate((@as(u64, used_mb) * @as(u64, bar_w)) / @as(u64, total_mb)) else 0;
    if (used_w > 0 and used_w <= bar_w) {
        graphics.fillRect(x + 4, line_y, used_w, 12, graphics.Color.rgb(100, 150, 255));
    }
    graphics.drawRect(x + 4, line_y, bar_w, 12, graphics.Color.rgb(80, 80, 85));
    line_y += 20;

    // Disk Section
    if (ata.hasDrive()) {
        font.drawString(x + 4, line_y, "Disk", graphics.WHITE, null);
        const disk_mb: u32 = @truncate(ata.getDiskSize() / 1024 / 1024);
        var disk_buf: [12]u8 = undefined;
        const disk_len = formatSize(disk_mb, &disk_buf);
        font.drawString(x + @as(i32, @intCast(content_w)) - 60, line_y, disk_buf[0..disk_len], graphics.Color.rgb(255, 200, 100), null);
        line_y += 14;

        // Disk bar (simplified - show total capacity)
        graphics.fillRect(x + 4, line_y, bar_w, 12, graphics.Color.rgb(50, 50, 55));
        graphics.fillRect(x + 4, line_y, bar_w / 4, 12, graphics.Color.rgb(255, 200, 100)); // ~25% used estimate
        graphics.drawRect(x + 4, line_y, bar_w, 12, graphics.Color.rgb(80, 80, 85));
        line_y += 20;
    }

    // Uptime
    const uptime = pit.getUptime();
    const hours = uptime / 3600;
    const mins = (uptime % 3600) / 60;
    const secs = uptime % 60;
    font.drawString(x + 4, line_y, "Uptime:", graphics.GRAY, null);
    var up_buf: [16]u8 = undefined;
    const up_len = formatUptime(hours, mins, secs, &up_buf);
    font.drawString(x + 64, line_y, up_buf[0..up_len], graphics.WHITE, null);
}

fn drawGraph(gx: i32, gy: i32, gw: u32, gh: u32, history: *const [HISTORY_SIZE]u8, color: graphics.Color) void {
    if (gh < 3 or gw == 0) return; // Safety check
    const step: u32 = if (gw > HISTORY_SIZE) gw / HISTORY_SIZE else 1;
    var i: usize = 0;
    var px: u32 = 0;
    while (i < HISTORY_SIZE and px < gw) : (i += 1) {
        const idx = (history_idx + i) % HISTORY_SIZE;
        const val = history[idx];
        // Safe calculation to avoid overflow/underflow
        const max_bar_h = gh -| 2; // Saturating subtraction
        const bar_h: u32 = if (max_bar_h > 0) (@as(u32, val) *| max_bar_h) / 100 else 0;
        if (bar_h > 0 and bar_h < gh) {
            const bar_y = gh -| bar_h -| 1;
            graphics.fillRect(gx + @as(i32, @intCast(px)), gy + @as(i32, @intCast(bar_y)), step, bar_h, color);
        }
        px +|= step; // Saturating add
    }
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
    var dc: usize = 0;
    while (v > 0 and dc < 3) : (dc += 1) {
        digits[dc] = @truncate((v % 10) + '0');
        v /= 10;
    }
    while (dc > 0) {
        dc -= 1;
        buf[len] = digits[dc];
        len += 1;
    }
    buf[len] = '%';
    return len + 1;
}

fn formatMemory(used: u32, total: u32, buf: []u8) usize {
    var len: usize = 0;
    len += formatNum(used, buf[len..]);
    buf[len] = '/';
    len += 1;
    len += formatNum(total, buf[len..]);
    buf[len] = 'M';
    len += 1;
    buf[len] = 'B';
    return len + 1;
}

fn formatSize(mb: u32, buf: []u8) usize {
    const len = formatNum(mb, buf);
    buf[len] = ' ';
    buf[len + 1] = 'M';
    buf[len + 2] = 'B';
    return len + 3;
}

fn formatUptime(h: u32, m: u32, s: u32, buf: []u8) usize {
    var len: usize = 0;
    len += formatNum(h, buf[len..]);
    buf[len] = 'h';
    len += 1;
    buf[len] = ' ';
    len += 1;
    len += formatNum(m, buf[len..]);
    buf[len] = 'm';
    len += 1;
    buf[len] = ' ';
    len += 1;
    len += formatNum(s, buf[len..]);
    buf[len] = 's';
    return len + 1;
}

fn formatNum(val: u32, buf: []u8) usize {
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

pub fn handleKey(key: u8) void {
    _ = key;
    // No special keys needed - auto-updates
}
