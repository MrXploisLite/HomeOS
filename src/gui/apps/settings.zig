// Home OS - Settings App
// Copyright © 2025 Romy R - Home OS
// System settings and configuration

const graphics = @import("../../drivers/graphics.zig");
const font = @import("../../drivers/font.zig");
const window = @import("../window.zig");
const Window = window.Window;
const net = @import("../../net/net.zig");
const audio = @import("../../drivers/audio.zig");
const vbe = @import("../../drivers/vbe.zig");

var selected_tab: usize = 0;
var selected_resolution: usize = 0; // Track selected resolution in UI (synced on draw)
var resolution_synced: bool = false;
const tabs = [_][]const u8{ "Display", "Network", "Audio", "Security", "About" };

pub fn draw(win: *const Window, x: i32, y: i32) void {
    const content_w = win.width - 8;
    const content_h = win.height - @as(u32, @intCast(window.TITLE_BAR_HEIGHT)) - 8;

    // Title with icon
    graphics.fillRect(x, y, 16, 16, graphics.Color.rgb(150, 150, 155));
    graphics.drawRect(x + 4, y + 4, 8, 8, graphics.DARK_GRAY);
    font.drawString(x + 22, y + 2, "Settings", graphics.BLACK, null);
    graphics.drawLine(x, y + 18, x + @as(i32, @intCast(content_w)), y + 18, graphics.Color.rgb(220, 220, 225));

    // Tabs with modern styling (responsive width)
    const tab_w: i32 = @intCast(@max(40, @min(52, @divTrunc(content_w, 5) - 2)));
    var tab_x = x;
    for (tabs, 0..) |tab, i| {
        const is_selected = (i == selected_tab);
        const bg = if (is_selected) graphics.Color.rgb(50, 120, 200) else graphics.Color.rgb(230, 230, 235);
        const fg = if (is_selected) graphics.WHITE else graphics.DARK_GRAY;

        graphics.fillRect(tab_x, y + 24, @intCast(tab_w), 20, bg);
        if (is_selected) {
            graphics.fillRect(tab_x, y + 42, @intCast(tab_w), 2, graphics.Color.rgb(50, 120, 200));
        }
        font.drawString(tab_x + 4, y + 28, tab, fg, null);
        tab_x += tab_w + 2;
    }

    // Content area (responsive)
    const content_area_y = y + 48;
    const content_area_h: u32 = @max(80, content_h - 60);
    graphics.fillRect(x, content_area_y, content_w, content_area_h, graphics.WHITE);
    graphics.drawRect(x, content_area_y, content_w, content_area_h, graphics.Color.rgb(200, 200, 205));

    switch (selected_tab) {
        0 => drawDisplaySettings(x + 8, content_area_y + 6),
        1 => drawNetworkSettings(x + 8, content_area_y + 6),
        2 => drawAudioSettings(x + 8, content_area_y + 6),
        3 => drawSecuritySettings(x + 8, content_area_y + 6),
        4 => drawAboutSettings(x + 8, content_area_y + 6),
        else => {},
    }

    // Help text at bottom
    if (content_h > 180) {
        font.drawString(x, y + @as(i32, @intCast(content_h)) - 12, "Click tabs or press 1-5", graphics.GRAY, null);
    }
}

fn drawDisplaySettings(x: i32, y: i32) void {
    const desktop = @import("../desktop.zig");

    // Sync selected_resolution with current on first draw
    if (!resolution_synced) {
        selected_resolution = vbe.getCurrentResolutionIdx();
        resolution_synced = true;
    }

    font.drawString(x, y, "Display Settings", graphics.BLACK, null);

    // Theme toggle
    font.drawString(x, y + 16, "Theme: ", graphics.DARK_GRAY, null);
    if (desktop.dark_theme) {
        font.drawString(x + 56, y + 16, "Dark", graphics.WHITE, graphics.Color.rgb(50, 50, 55));
    } else {
        font.drawString(x + 56, y + 16, "Light", graphics.BLACK, graphics.Color.rgb(200, 200, 205));
    }
    font.drawString(x + 100, y + 16, "[T]", graphics.Color.rgb(50, 120, 200), null);

    // Current resolution
    font.drawString(x, y + 32, "Resolution: ", graphics.DARK_GRAY, null);
    var res_buf: [20]u8 = undefined;
    const res_len = formatResolution(vbe.getWidth(), vbe.getHeight(), &res_buf);
    font.drawString(x + 96, y + 32, res_buf[0..res_len], graphics.BLACK, null);

    // Resolution options
    font.drawString(x, y + 48, "Select:", graphics.DARK_GRAY, null);

    var opt_y = y + 62;
    var i: usize = 0;
    while (i < vbe.getResolutionCount() and i < 5) : (i += 1) {
        if (vbe.getResolution(i)) |res| {
            const is_current = (i == vbe.getCurrentResolutionIdx());
            const is_selected = (i == selected_resolution);

            // Selection indicator
            if (is_selected) {
                font.drawString(x, opt_y, ">", graphics.Color.rgb(50, 120, 200), null);
            }

            // Resolution name
            const color = if (is_current) graphics.GREEN else graphics.DARK_GRAY;
            font.drawString(x + 12, opt_y, res.name, color, null);

            // Current marker
            if (is_current) {
                font.drawString(x + 100, opt_y, "*", graphics.GREEN, null);
            }

            opt_y += 12;
        }
    }

    // Wallpaper style
    font.drawString(x + 130, y + 48, "Wall:", graphics.DARK_GRAY, null);
    const wall_names = [_][]const u8{ "Grad", "Blue", "Grn", "Purp", "Brn", "Gray", "Blk" };
    if (desktop.wallpaper_style < wall_names.len) {
        font.drawString(x + 170, y + 48, wall_names[desktop.wallpaper_style], graphics.CYAN, null);
    }
    font.drawString(x + 130, y + 62, "[/]:Wall", graphics.GRAY, null);

    font.drawString(x, y + 124, "T:Theme W/S:Sel Enter:Apply", graphics.GRAY, null);
}

fn formatResolution(w: u32, h: u32, buf: []u8) usize {
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

fn drawNetworkSettings(x: i32, y: i32) void {
    font.drawString(x, y, "Network Settings", graphics.BLACK, null);

    font.drawString(x, y + 20, "IP Address: ", graphics.DARK_GRAY, null);
    const ip = net.getLocalIp();
    var ip_str: [15]u8 = undefined;
    const ip_len = formatIp(ip, &ip_str);
    font.drawString(x + 96, y + 20, ip_str[0..ip_len], graphics.DARK_GRAY, null);

    font.drawString(x, y + 36, "Firewall: ", graphics.DARK_GRAY, null);
    if (net.firewall.isEnabled()) {
        font.drawString(x + 80, y + 36, "Enabled", graphics.GREEN, null);
    } else {
        font.drawString(x + 80, y + 36, "Disabled", graphics.RED, null);
    }

    font.drawString(x, y + 52, "MAC Random: ", graphics.DARK_GRAY, null);
    if (net.mac.isRandomized()) {
        font.drawString(x + 96, y + 52, "Yes", graphics.GREEN, null);
    } else {
        font.drawString(x + 96, y + 52, "No", graphics.DARK_GRAY, null);
    }
}

// Volume level (0-10)
var volume_level: u8 = 5;
// Mouse speed (1-10)
var mouse_speed: u8 = 5;

// Public setters for config system
pub fn setVolume(vol: u8) void {
    volume_level = if (vol > 10) 10 else vol;
}

pub fn setMouseSpeed(speed: u8) void {
    mouse_speed = if (speed > 10) 10 else if (speed < 1) 1 else speed;
}

pub fn getVolume() u8 {
    return volume_level;
}

pub fn getMouseSpeed() u8 {
    return mouse_speed;
}

fn drawAudioSettings(x: i32, y: i32) void {
    font.drawString(x, y, "Audio Settings", graphics.BLACK, null);

    font.drawString(x, y + 20, "PC Speaker: ", graphics.DARK_GRAY, null);
    font.drawString(x + 96, y + 20, "Enabled", graphics.GREEN, null);

    font.drawString(x, y + 36, "Sound Blaster: ", graphics.DARK_GRAY, null);
    if (audio.hasSoundBlaster()) {
        font.drawString(x + 112, y + 36, "Found", graphics.GREEN, null);
    } else {
        font.drawString(x + 112, y + 36, "Not found", graphics.RED, null);
    }

    // Volume control
    font.drawString(x, y + 56, "Volume: ", graphics.DARK_GRAY, null);
    // Draw volume bar
    graphics.fillRect(x + 64, y + 56, 100, 12, graphics.Color.rgb(200, 200, 205));
    const vol_width: u32 = @as(u32, volume_level) * 10;
    graphics.fillRect(x + 64, y + 56, vol_width, 12, graphics.Color.rgb(80, 200, 120));
    graphics.drawRect(x + 64, y + 56, 100, 12, graphics.DARK_GRAY);
    // Volume number
    var vol_buf: [3]u8 = undefined;
    vol_buf[0] = '0' + volume_level / 10;
    vol_buf[1] = '0' + volume_level % 10;
    vol_buf[2] = 0;
    font.drawString(x + 170, y + 56, vol_buf[0..2], graphics.DARK_GRAY, null);

    // Mouse speed
    font.drawString(x, y + 76, "Mouse: ", graphics.DARK_GRAY, null);
    graphics.fillRect(x + 64, y + 76, 100, 12, graphics.Color.rgb(200, 200, 205));
    const spd_width: u32 = @as(u32, mouse_speed) * 10;
    graphics.fillRect(x + 64, y + 76, spd_width, 12, graphics.Color.rgb(100, 150, 255));
    graphics.drawRect(x + 64, y + 76, 100, 12, graphics.DARK_GRAY);
    var spd_buf: [3]u8 = undefined;
    spd_buf[0] = '0' + mouse_speed / 10;
    spd_buf[1] = '0' + mouse_speed % 10;
    spd_buf[2] = 0;
    font.drawString(x + 170, y + 76, spd_buf[0..2], graphics.DARK_GRAY, null);

    font.drawString(x, y + 100, "B:Beep +/-:Vol [/]:Mouse", graphics.GRAY, null);
}

fn drawSecuritySettings(x: i32, y: i32) void {
    font.drawString(x, y, "Security Settings", graphics.BLACK, null);

    font.drawString(x, y + 20, "Firewall Rules: ", graphics.DARK_GRAY, null);
    drawInt(x + 128, y + 20, @truncate(net.firewall.getRuleCount()));

    font.drawString(x, y + 36, "TLS: ", graphics.DARK_GRAY, null);
    if (net.tls.isInitialized()) {
        font.drawString(x + 40, y + 36, "Ready", graphics.GREEN, null);
    } else {
        font.drawString(x + 40, y + 36, "Not ready", graphics.RED, null);
    }

    font.drawString(x, y + 52, "Crypto: ", graphics.DARK_GRAY, null);
    font.drawString(x + 64, y + 52, "SHA-256, RNG", graphics.DARK_GRAY, null);

    font.drawString(x, y + 76, "Privacy Mode: Active", graphics.GREEN, null);
}

fn drawAboutSettings(x: i32, y: i32) void {
    font.drawString(x, y, "Home OS", graphics.BLACK, null);
    font.drawString(x, y + 16, "Version 0.29.0", graphics.DARK_GRAY, null);
    font.drawString(x, y + 32, "Copyright 2025", graphics.DARK_GRAY, null);
    font.drawString(x, y + 48, "Romy Rianata", graphics.DARK_GRAY, null);
    font.drawString(x, y + 72, "A privacy-focused OS", graphics.GRAY, null);
    font.drawString(x, y + 88, "Written in Zig", graphics.GRAY, null);
}

pub fn handleKey(key: u8) void {
    const keyboard = @import("../../drivers/keyboard.zig");
    const desktop = @import("../desktop.zig");

    if (key >= '1' and key <= '5') {
        selected_tab = key - '1';
    } else if (key == 'b' or key == 'B') {
        // Test beep
        audio.playTone(440, 20);
    } else if (key == 't' or key == 'T') {
        // Toggle theme (works from any tab but mainly for Display)
        desktop.dark_theme = !desktop.dark_theme;
        // Save to config
        const config = @import("../config.zig");
        config.setDarkTheme(desktop.dark_theme);
        config.autoSave();
    } else if (key == '+' or key == '=') {
        // Increase volume
        if (volume_level < 10) {
            volume_level += 1;
            const config = @import("../config.zig");
            config.setVolume(volume_level);
            config.autoSave();
        }
    } else if (key == '-' or key == '_') {
        // Decrease volume
        if (volume_level > 0) {
            volume_level -= 1;
            const config = @import("../config.zig");
            config.setVolume(volume_level);
            config.autoSave();
        }
    } else if (key == ']') {
        // Increase mouse speed
        if (mouse_speed < 10) {
            mouse_speed += 1;
            const config = @import("../config.zig");
            config.setMouseSpeed(mouse_speed);
            config.autoSave();
        }
    } else if (key == '[') {
        // Decrease mouse speed
        if (mouse_speed > 1) {
            mouse_speed -= 1;
            const config = @import("../config.zig");
            config.setMouseSpeed(mouse_speed);
            config.autoSave();
        }
    } else if (key == '/' or key == '?') {
        // Cycle wallpaper style
        desktop.wallpaper_style = (desktop.wallpaper_style + 1) % 7;
    } else if (key == '\\' or key == '|') {
        // Cycle wallpaper style backwards
        if (desktop.wallpaper_style > 0) {
            desktop.wallpaper_style -= 1;
        } else {
            desktop.wallpaper_style = 6;
        }
    } else if (selected_tab == 0) {
        // Display tab - handle resolution selection
        if (key == keyboard.KEY_UP or key == 'w' or key == 'W') {
            if (selected_resolution > 0) {
                selected_resolution -= 1;
            }
        } else if (key == keyboard.KEY_DOWN or key == 's' or key == 'S') {
            if (selected_resolution < vbe.getResolutionCount() - 1) {
                selected_resolution += 1;
            }
        } else if (key == '\n' or key == '\r') {
            // Apply resolution
            if (vbe.setResolution(selected_resolution)) {
                // Update graphics system
                _ = graphics.init();
                // Update desktop and clamp windows
                desktop.onResolutionChange();
                // Save to config
                const config = @import("../config.zig");
                config.setResolution(@truncate(selected_resolution));
                config.autoSave();
            }
        }
    }
}

/// Handle mouse click - check if clicking on tabs
pub fn handleClick(win: *const Window, mx: i32, my: i32) void {
    const content_x = win.x + 4;
    const content_y = win.y + window.TITLE_BAR_HEIGHT + 4;

    // Tab area: y + 18, height 18, each tab 52 wide with 2px gap
    const tab_y = content_y + 18;
    if (my >= tab_y and my < tab_y + 18) {
        const rel_x = mx - content_x;
        if (rel_x >= 0) {
            const tab_idx = @as(usize, @intCast(rel_x)) / 54;
            if (tab_idx < tabs.len) {
                selected_tab = tab_idx;
            }
        }
    }
}

fn formatIp(ip: [4]u8, buf: []u8) usize {
    var pos: usize = 0;
    for (ip, 0..) |octet, i| {
        pos += formatU8(octet, buf[pos..]);
        if (i < 3) {
            buf[pos] = '.';
            pos += 1;
        }
    }
    return pos;
}

fn formatU8(val: u8, buf: []u8) usize {
    if (val == 0) {
        buf[0] = '0';
        return 1;
    }
    var v = val;
    var len: usize = 0;
    var temp: [3]u8 = undefined;
    while (v > 0) : (len += 1) {
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
