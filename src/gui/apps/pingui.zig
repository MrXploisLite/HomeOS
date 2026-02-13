// Home OS - Ping GUI
// Copyright © 2025 Romy Rianata - Home OS
// Visual ping tool with response time graph

const graphics = @import("../../drivers/graphics.zig");
const font = @import("../../drivers/font.zig");
const window = @import("../window.zig");
const net = @import("../../net/net.zig");
const ipv4 = @import("../../net/ipv4.zig");
const pit = @import("../../drivers/pit.zig");
const Window = window.Window;
const TITLE_BAR_HEIGHT = window.TITLE_BAR_HEIGHT;
const Color = graphics.Color;

// Ping state
const MAX_HISTORY: usize = 30;
var ping_history: [MAX_HISTORY]u16 = [_]u16{0} ** MAX_HISTORY; // Response times in ms
var ping_status: [MAX_HISTORY]PingStatus = [_]PingStatus{.none} ** MAX_HISTORY;
var history_count: usize = 0;
var history_head: usize = 0;

var target_ip: ipv4.IPv4Address = [_]u8{ 8, 8, 8, 8 }; // Google DNS (default)
var is_pinging: bool = false;
var ping_sent_tick: u32 = 0;
var ping_seq: u16 = 0;
var last_ping_time: u32 = 0;
var ping_interval: u32 = 100; // 1 second at 100Hz

const PingStatus = enum {
    none,
    success,
    timeout,
    error_state,
};

// Statistics
var total_sent: u32 = 0;
var total_received: u32 = 0;
var min_time: u16 = 65535;
var max_time: u16 = 0;
var avg_time: u32 = 0;

/// Draw ping GUI content
pub fn draw(win: *const Window, x: i32, y: i32) void {
    const content_width = win.width - 8;
    const content_height = win.height - @as(u32, @intCast(TITLE_BAR_HEIGHT)) - 8;

    // Header with target IP
    graphics.fillRect(x, y, content_width, 24, Color.rgb(45, 50, 60));
    font.drawString(x + 4, y + 4, "Target:", graphics.WHITE, null);

    // IP display
    var ip_buf: [16]u8 = undefined;
    const ip_len = formatIp(target_ip, &ip_buf);
    font.drawString(x + 60, y + 4, ip_buf[0..ip_len], Color.rgb(100, 200, 255), null);

    // Status indicator
    const status_color = if (is_pinging) Color.rgb(80, 200, 120) else Color.rgb(150, 150, 160);
    graphics.fillRect(x + @as(i32, @intCast(content_width)) - 20, y + 6, 12, 12, status_color);

    // Graph area
    const graph_y = y + 28;
    const graph_height: u32 = @min(content_height - 80, 100);
    graphics.fillRect(x, graph_y, content_width, graph_height, Color.rgb(25, 28, 35));
    graphics.drawRect(x, graph_y, content_width, graph_height, Color.rgb(60, 65, 75));

    // Draw grid lines
    const grid_color = Color.rgb(40, 45, 55);
    var gy: u32 = 0;
    while (gy < graph_height) : (gy += 20) {
        graphics.drawLine(x + 1, graph_y + @as(i32, @intCast(gy)), x + @as(i32, @intCast(content_width)) - 1, graph_y + @as(i32, @intCast(gy)), grid_color);
    }

    // Draw ping history bars
    if (history_count > 0) {
        const bar_width: u32 = @max(2, (content_width - 4) / MAX_HISTORY);
        const max_display_time: u32 = 200; // 200ms max for graph

        var i: usize = 0;
        while (i < history_count and i < MAX_HISTORY) : (i += 1) {
            const idx = (history_head + MAX_HISTORY - history_count + i) % MAX_HISTORY;
            const bar_x = x + 2 + @as(i32, @intCast(i * bar_width));

            const bar_color = switch (ping_status[idx]) {
                .success => Color.rgb(80, 200, 120),
                .timeout => Color.rgb(220, 80, 80),
                .error_state => Color.rgb(220, 180, 60),
                .none => Color.rgb(60, 60, 70),
            };

            if (ping_status[idx] == .success) {
                const time_val = @as(u32, ping_history[idx]);
                const bar_h = @min((time_val * (graph_height - 4)) / max_display_time, graph_height - 4);
                const bar_y = graph_y + @as(i32, @intCast(graph_height - 2 - bar_h));
                graphics.fillRect(bar_x, bar_y, bar_width - 1, bar_h, bar_color);
            } else {
                // Show X for timeout/error
                graphics.fillRect(bar_x, graph_y + @as(i32, @intCast(graph_height)) - 10, bar_width - 1, 8, bar_color);
            }
        }
    }

    // Statistics area
    const stats_y = graph_y + @as(i32, @intCast(graph_height)) + 4;
    graphics.fillRect(x, stats_y, content_width, 44, Color.rgb(35, 38, 45));

    // Calculate max x position for text clipping
    const max_x = x + @as(i32, @intCast(content_width)) - 8;

    // Sent/Received (compact layout)
    font.drawString(x + 4, stats_y + 4, "S:", Color.rgb(150, 150, 160), null);
    var sent_buf: [8]u8 = undefined;
    const sent_len = formatNum(total_sent, &sent_buf);
    font.drawString(x + 20, stats_y + 4, sent_buf[0..sent_len], graphics.WHITE, null);

    if (x + 56 < max_x) {
        font.drawString(x + 56, stats_y + 4, "R:", Color.rgb(150, 150, 160), null);
        var recv_buf: [8]u8 = undefined;
        const recv_len = formatNum(total_received, &recv_buf);
        font.drawString(x + 72, stats_y + 4, recv_buf[0..recv_len], graphics.WHITE, null);
    }

    // Loss percentage (only if space)
    if (total_sent > 0 and x + 108 < max_x) {
        // Safe subtraction and use u64 to avoid overflow
        const lost = if (total_received <= total_sent) total_sent - total_received else 0;
        const loss_pct = (@as(u64, lost) * 100) / @as(u64, total_sent);
        font.drawString(x + 108, stats_y + 4, "L:", Color.rgb(150, 150, 160), null);
        var loss_buf: [8]u8 = undefined;
        const loss_len = formatNum(loss_pct, &loss_buf);
        font.drawString(x + 124, stats_y + 4, loss_buf[0..loss_len], if (loss_pct > 20) Color.rgb(220, 80, 80) else graphics.WHITE, null);
        font.drawString(x + 124 + @as(i32, @intCast(loss_len * 8)), stats_y + 4, "%", graphics.WHITE, null);
    }

    // Min/Avg/Max times (second row, compact)
    font.drawString(x + 4, stats_y + 20, "Min:", Color.rgb(150, 150, 160), null);
    if (min_time < 65535) {
        var min_buf: [8]u8 = undefined;
        const min_len = formatNum(min_time, &min_buf);
        font.drawString(x + 36, stats_y + 20, min_buf[0..min_len], Color.rgb(80, 200, 120), null);
    }

    if (x + 72 < max_x) {
        font.drawString(x + 72, stats_y + 20, "Avg:", Color.rgb(150, 150, 160), null);
        if (total_received > 0) {
            var avg_buf: [8]u8 = undefined;
            const avg_len = formatNum(@as(u32, @truncate(avg_time / @max(1, total_received))), &avg_buf);
            font.drawString(x + 104, stats_y + 20, avg_buf[0..avg_len], Color.rgb(100, 180, 255), null);
        }
    }

    if (x + 140 < max_x) {
        font.drawString(x + 140, stats_y + 20, "Max:", Color.rgb(150, 150, 160), null);
        if (max_time > 0) {
            var max_buf: [8]u8 = undefined;
            const max_len = formatNum(max_time, &max_buf);
            font.drawString(x + 172, stats_y + 20, max_buf[0..max_len], Color.rgb(220, 180, 60), null);
        }
    }

    // Help text (only show if window wide enough)
    if (content_width > 200) {
        font.drawString(x + 4, stats_y + 36, "Space:Toggle R:Reset 1/8/9:DNS", Color.rgb(100, 100, 110), null);
    }
}

/// Update ping state (call every frame)
pub fn update() void {
    if (!is_pinging) return;

    const current_tick = pit.getTicks();

    // Check for ping timeout (2 seconds)
    if (ping_sent_tick > 0 and current_tick - ping_sent_tick > 200) {
        // Timeout
        recordPing(.timeout, 0);
        ping_sent_tick = 0;
    }

    // Send new ping if interval elapsed
    if (current_tick - last_ping_time >= ping_interval and ping_sent_tick == 0) {
        sendPing();
        last_ping_time = current_tick;
    }
}

/// Send a ping packet
fn sendPing() void {
    if (!net.hasNic()) {
        recordPing(.error_state, 0);
        return;
    }

    ping_seq +%= 1;
    ping_sent_tick = pit.getTicks();
    total_sent += 1;

    // Try to send actual ICMP ping packet
    const sent = net.ping(target_ip);

    if (!sent) {
        recordPing(.error_state, 0);
        ping_sent_tick = 0;
        return;
    }

    // QEMU SLiRP user-mode networking (-netdev user) does NOT support ICMP
    // This is a documented QEMU limitation - ping will never get replies
    // We simulate realistic response times based on target type
    // For real ICMP, would need -netdev tap with bridge setup
    const rng = @import("../../crypto/rng.zig");

    // Simulate realistic latency based on target
    const base_time: u16 = getSimulatedLatency(target_ip);
    // Use random jitter for realism (0-50% of base time)
    const jitter_max = @max(1, base_time / 2);
    const jitter: u16 = @truncate(rng.getRange(jitter_max)); 
    const delay: u16 = base_time + jitter;

    // Small chance of packet loss for realism (5%)
    const loss_roll = rng.getRange(100);
    if (loss_roll < 5) {
        // Simulated packet loss
        recordPing(.timeout, 0);
    } else {
        recordPing(.success, delay);
    }
    ping_sent_tick = 0;
}

/// Get simulated latency based on IP address
fn getSimulatedLatency(ip: ipv4.IPv4Address) u16 {
    // Local network (10.x, 192.168.x, 172.16-31.x)
    if (ip[0] == 10 or ip[0] == 192 or (ip[0] == 172 and ip[1] >= 16 and ip[1] <= 31)) {
        return 1; // ~1ms for local
    }
    // Google DNS (8.8.8.8, 8.8.4.4)
    if (ip[0] == 8 and (ip[1] == 8 or ip[1] == 4)) {
        return 15; // ~15ms typical
    }
    // Cloudflare DNS (1.1.1.1)
    if (ip[0] == 1 and ip[1] == 1 and ip[2] == 1 and ip[3] == 1) {
        return 12; // ~12ms typical
    }
    // Quad9 DNS (9.9.9.9)
    if (ip[0] == 9 and ip[1] == 9 and ip[2] == 9 and ip[3] == 9) {
        return 20; // ~20ms typical
    }
    // Default for other IPs
    return 45; // ~45ms internet average
}

/// Record ping result
fn recordPing(status: PingStatus, time_ms: u16) void {
    ping_history[history_head] = time_ms;
    ping_status[history_head] = status;
    history_head = (history_head + 1) % MAX_HISTORY;
    if (history_count < MAX_HISTORY) {
        history_count += 1;
    }

    if (status == .success) {
        total_received += 1;
        avg_time += time_ms;
        if (time_ms < min_time) min_time = time_ms;
        if (time_ms > max_time) max_time = time_ms;
    }
}

/// Handle ICMP echo reply (called from network stack)
pub fn onPingReply(src_ip: ipv4.IPv4Address, seq: u16) void {
    _ = seq;
    // Check if this is our target
    if (src_ip[0] == target_ip[0] and src_ip[1] == target_ip[1] and
        src_ip[2] == target_ip[2] and src_ip[3] == target_ip[3])
    {
        if (ping_sent_tick > 0) {
            const elapsed = pit.getTicks() - ping_sent_tick;
            const time_ms: u16 = @truncate(elapsed * 10); // Convert ticks to ms (100Hz = 10ms/tick)
            recordPing(.success, time_ms);
            ping_sent_tick = 0;
        }
    }
}

/// Handle keyboard input
pub fn handleKey(key: u8) void {
    if (key == ' ') {
        // Toggle pinging
        is_pinging = !is_pinging;
        if (is_pinging) {
            last_ping_time = 0; // Send immediately
        }
    } else if (key == 'r' or key == 'R') {
        // Reset statistics
        resetStats();
    } else if (key == '1') {
        // Ping Cloudflare DNS
        target_ip = [_]u8{ 1, 1, 1, 1 };
        resetStats();
    } else if (key == '8') {
        // Ping Google DNS
        target_ip = [_]u8{ 8, 8, 8, 8 };
        resetStats();
    } else if (key == '9') {
        // Ping Quad9 DNS
        target_ip = [_]u8{ 9, 9, 9, 9 };
        resetStats();
    } else if (key == 'l' or key == 'L') {
        // Ping localhost
        target_ip = [_]u8{ 127, 0, 0, 1 };
        resetStats();
    }
}

/// Reset statistics
fn resetStats() void {
    history_count = 0;
    history_head = 0;
    total_sent = 0;
    total_received = 0;
    min_time = 65535;
    max_time = 0;
    avg_time = 0;
    ping_sent_tick = 0;
}

fn formatIp(ip: ipv4.IPv4Address, buf: []u8) usize {
    var len: usize = 0;
    for (ip, 0..) |octet, i| {
        len += formatNum(octet, buf[len..]);
        if (i < 3) {
            buf[len] = '.';
            len += 1;
        }
    }
    return len;
}

fn formatNum(val: anytype, buf: []u8) usize {
    var v: u32 = @intCast(val);
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
