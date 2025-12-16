// Home OS - Device Manager App
// Copyright © 2025 Romy Rianata - Home OS
// Shows system devices and their status

const graphics = @import("../../drivers/graphics.zig");
const font = @import("../../drivers/font.zig");
const window = @import("../window.zig");
const Window = window.Window;

// Device imports
const ata = @import("../../drivers/ata.zig");
const rtl8139 = @import("../../net/rtl8139.zig");
const pci = @import("../../drivers/pci.zig");
const audio = @import("../../drivers/audio.zig");
const mouse = @import("../../drivers/mouse.zig");

// Device categories
const DeviceCategory = enum {
    storage,
    network,
    display,
    audio,
    input,
    usb,
};

var selected_category: usize = 0;
const categories = [_][]const u8{ "Storage", "Network", "Display", "Audio", "Input", "USB" };

pub fn draw(win: *const Window, x: i32, y: i32) void {
    const content_w = win.width - 8;
    const content_h = win.height - @as(u32, @intCast(window.TITLE_BAR_HEIGHT)) - 8;

    // Title
    font.drawString(x, y, "Device Manager", graphics.BLACK, null);
    graphics.drawLine(x, y + 12, x + @as(i32, @intCast(content_w)), y + 12, graphics.DARK_GRAY);

    // Category tabs with modern styling (responsive width)
    const tab_w: i32 = @intCast(@max(36, @min(46, @divTrunc(content_w, 6) - 2)));
    var tab_x = x;
    for (categories, 0..) |cat, i| {
        const is_selected = (i == selected_category);
        const bg = if (is_selected) graphics.Color.rgb(50, 120, 200) else graphics.Color.rgb(230, 230, 235);
        const fg = if (is_selected) graphics.WHITE else graphics.DARK_GRAY;

        graphics.fillRect(tab_x, y + 18, @intCast(tab_w), 20, bg);
        if (is_selected) {
            graphics.fillRect(tab_x, y + 36, @intCast(tab_w), 2, graphics.Color.rgb(50, 120, 200));
        }
        font.drawString(tab_x + 2, y + 22, cat, fg, null);
        tab_x += tab_w + 2;
    }

    // Device list area (responsive)
    const list_y = y + 42;
    const list_h: u32 = @max(100, content_h - 60);
    graphics.fillRect(x, list_y, content_w, list_h, graphics.WHITE);
    graphics.drawRect(x, list_y, content_w, list_h, graphics.Color.rgb(200, 200, 205));

    // Draw devices based on category
    const line_y = list_y + 4;
    switch (selected_category) {
        0 => drawStorageDevices(x + 4, line_y),
        1 => drawNetworkDevices(x + 4, line_y),
        2 => drawDisplayDevices(x + 4, line_y),
        3 => drawAudioDevices(x + 4, line_y),
        4 => drawInputDevices(x + 4, line_y),
        5 => drawUsbDevices(x + 4, line_y),
        else => {},
    }

    // Help text at bottom
    if (content_h > 200) {
        font.drawString(x, y + @as(i32, @intCast(content_h)) - 12, "Click tabs or press 1-6", graphics.DARK_GRAY, null);
    }
}

fn drawStorageDevices(x: i32, y: i32) void {
    var line_y = y;

    // ATA/IDE
    font.drawString(x, line_y, "[+] IDE Controller", graphics.BLACK, null);
    line_y += 14;

    if (ata.hasDrive()) {
        font.drawString(x + 12, line_y, "Primary Master: ATA Disk", graphics.DARK_GRAY, null);
        line_y += 12;
        font.drawString(x + 24, line_y, "Size: ", graphics.DARK_GRAY, null);
        drawInt(x + 60, line_y, @truncate(ata.getDiskSize() / 1024 / 1024));
        font.drawString(x + 90, line_y, " MB", graphics.DARK_GRAY, null);
        line_y += 12;
        font.drawString(x + 24, line_y, "Status: OK", graphics.GREEN, null);
    } else {
        font.drawString(x + 12, line_y, "No drives detected", graphics.DARK_GRAY, null);
    }
}

fn drawNetworkDevices(x: i32, y: i32) void {
    var line_y = y;

    font.drawString(x, line_y, "[+] Network Adapters", graphics.BLACK, null);
    line_y += 14;

    if (rtl8139.isInitialized()) {
        font.drawString(x + 12, line_y, "RTL8139 Fast Ethernet", graphics.DARK_GRAY, null);
        line_y += 12;
        font.drawString(x + 24, line_y, "MAC: ", graphics.DARK_GRAY, null);
        const mac = rtl8139.getMacAddress();
        drawMac(x + 60, line_y, mac);
        line_y += 12;
        font.drawString(x + 24, line_y, "Status: Connected", graphics.GREEN, null);
    } else {
        font.drawString(x + 12, line_y, "No network adapter", graphics.DARK_GRAY, null);
    }
}

fn drawDisplayDevices(x: i32, y: i32) void {
    const vbe = @import("../../drivers/vbe.zig");
    var line_y = y;

    font.drawString(x, line_y, "[+] Display Adapters", graphics.BLACK, null);
    line_y += 14;

    if (graphics.isInitialized()) {
        font.drawString(x + 12, line_y, "Bochs VBE Graphics", graphics.DARK_GRAY, null);
        line_y += 12;
        // Dynamic resolution from VBE
        font.drawString(x + 24, line_y, "Resolution: ", graphics.DARK_GRAY, null);
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
        font.drawString(x + 96, line_y, res_buf[0..res_len], graphics.DARK_GRAY, null);
        line_y += 12;
        font.drawString(x + 24, line_y, "Status: OK", graphics.GREEN, null);
    } else {
        font.drawString(x + 12, line_y, "VGA Text Mode", graphics.DARK_GRAY, null);
    }
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

fn drawAudioDevices(x: i32, y: i32) void {
    var line_y = y;

    font.drawString(x, line_y, "[+] Audio Devices", graphics.BLACK, null);
    line_y += 14;

    font.drawString(x + 12, line_y, "PC Speaker", graphics.DARK_GRAY, null);
    line_y += 12;
    font.drawString(x + 24, line_y, "Status: OK", graphics.GREEN, null);
    line_y += 14;

    if (audio.hasSoundBlaster()) {
        font.drawString(x + 12, line_y, "Sound Blaster 16", graphics.DARK_GRAY, null);
        line_y += 12;
        font.drawString(x + 24, line_y, "Status: OK", graphics.GREEN, null);
    } else {
        font.drawString(x + 12, line_y, "Sound Blaster 16", graphics.DARK_GRAY, null);
        line_y += 12;
        font.drawString(x + 24, line_y, "Status: Not found", graphics.RED, null);
    }
}

fn drawInputDevices(x: i32, y: i32) void {
    var line_y = y;

    font.drawString(x, line_y, "[+] Input Devices", graphics.BLACK, null);
    line_y += 14;

    font.drawString(x + 12, line_y, "PS/2 Keyboard", graphics.DARK_GRAY, null);
    line_y += 12;
    font.drawString(x + 24, line_y, "Status: OK", graphics.GREEN, null);
    line_y += 14;

    font.drawString(x + 12, line_y, "PS/2 Mouse", graphics.DARK_GRAY, null);
    line_y += 12;
    if (mouse.isInitialized()) {
        font.drawString(x + 24, line_y, "Status: OK", graphics.GREEN, null);
    } else {
        font.drawString(x + 24, line_y, "Status: Not found", graphics.RED, null);
    }
}

fn drawUsbDevices(x: i32, y: i32) void {
    var line_y = y;

    font.drawString(x, line_y, "[+] USB Controllers", graphics.BLACK, null);
    line_y += 14;

    // Check PCI for USB controllers
    var found_usb = false;
    var i: u8 = 0;
    while (i < pci.getDeviceCount()) : (i += 1) {
        if (pci.getDevice(i)) |dev| {
            if (dev.class_code == 0x0C and dev.subclass == 0x03) {
                found_usb = true;
                const usb_type: []const u8 = switch (dev.prog_if) {
                    0x00 => "UHCI",
                    0x10 => "OHCI",
                    0x20 => "EHCI",
                    0x30 => "xHCI",
                    else => "USB",
                };
                font.drawString(x + 12, line_y, usb_type, graphics.DARK_GRAY, null);
                font.drawString(x + 50, line_y, "Controller", graphics.DARK_GRAY, null);
                line_y += 12;
            }
        }
    }

    if (!found_usb) {
        font.drawString(x + 12, line_y, "No USB controller found", graphics.DARK_GRAY, null);
    }
}

pub fn handleKey(key: u8) void {
    // Number keys 1-6 to switch tabs
    if (key >= '1' and key <= '6') {
        selected_category = key - '1';
    }
}

/// Handle mouse click - check if clicking on tabs
pub fn handleClick(win: *const Window, mx: i32, my: i32) void {
    const content_x = win.x + 4;
    const content_y = win.y + window.TITLE_BAR_HEIGHT + 4;

    // Tab area: y + 18, height 18, each tab 46 wide with 2px gap
    const tab_y = content_y + 18;
    if (my >= tab_y and my < tab_y + 18) {
        const rel_x = mx - content_x;
        if (rel_x >= 0) {
            const tab_idx = @as(usize, @intCast(rel_x)) / 48;
            if (tab_idx < categories.len) {
                selected_category = tab_idx;
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

fn drawMac(x: i32, y: i32, mac: [6]u8) void {
    const hex = "0123456789ABCDEF";
    var buf: [17]u8 = undefined;
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

    font.drawString(x, y, &buf, graphics.DARK_GRAY, null);
}
