// Home OS - File Properties Dialog
// Copyright © 2025 Romy Rianata - Home OS
// Show file information dialog

const graphics = @import("../../drivers/graphics.zig");
const font = @import("../../drivers/font.zig");
const window = @import("../window.zig");
const fat32 = @import("../../fs/fat32.zig");
const Window = window.Window;
const TITLE_BAR_HEIGHT = window.TITLE_BAR_HEIGHT;
const Color = graphics.Color;

// Current file properties
var file_name: [12]u8 = [_]u8{0} ** 12;
var file_name_len: usize = 0;
var file_size: u32 = 0;
var file_is_dir: bool = false;
var file_attr: u8 = 0;
var file_cluster: u32 = 0;
var props_loaded: bool = false;

/// Load properties for a file
pub fn loadProperties(name: []const u8) void {
    props_loaded = false;
    file_name_len = 0;

    // Copy name
    const copy_len = @min(name.len, 12);
    for (name[0..copy_len], 0..) |c, i| {
        file_name[i] = c;
    }
    file_name_len = copy_len;

    // Look up file in FAT32
    if (fat32.getFS()) |fs| {
        if (fs.findFile(fs.root_cluster, name)) |entry| {
            file_size = entry.file_size;
            file_is_dir = entry.isDirectory();
            file_attr = entry.attr;
            file_cluster = entry.getCluster();
            props_loaded = true;
        }
    }
}

/// Draw file properties content
pub fn draw(win: *const Window, x: i32, y: i32) void {
    const content_width = win.width - 8;

    // File icon
    const icon_x = x + @as(i32, @intCast(content_width / 2)) - 24;
    if (file_is_dir) {
        // Folder icon
        graphics.fillRect(icon_x, y, 48, 36, Color.rgb(255, 200, 80));
        graphics.fillRect(icon_x, y - 4, 20, 8, Color.rgb(255, 200, 80));
        graphics.drawRect(icon_x, y, 48, 36, Color.rgb(200, 150, 50));
    } else {
        // File icon
        graphics.fillRect(icon_x, y, 48, 48, graphics.WHITE);
        graphics.drawRect(icon_x, y, 48, 48, graphics.DARK_GRAY);
        graphics.fillRect(icon_x + 32, y, 16, 16, graphics.LIGHT_GRAY);
        // Lines on document
        graphics.drawLine(icon_x + 8, y + 20, icon_x + 40, y + 20, graphics.LIGHT_GRAY);
        graphics.drawLine(icon_x + 8, y + 28, icon_x + 40, y + 28, graphics.LIGHT_GRAY);
        graphics.drawLine(icon_x + 8, y + 36, icon_x + 32, y + 36, graphics.LIGHT_GRAY);
    }

    // File name
    const name_y = y + 56;
    const name_width = font.measureString(file_name[0..file_name_len]);
    const name_x = x + @as(i32, @intCast((content_width - name_width) / 2));
    font.drawString(name_x, name_y, file_name[0..file_name_len], graphics.BLACK, null);

    // Separator
    graphics.drawLine(x + 10, name_y + 20, x + @as(i32, @intCast(content_width)) - 10, name_y + 20, graphics.LIGHT_GRAY);

    // Properties
    var prop_y = name_y + 30;
    const label_x = x + 10;
    const value_x = x + 80;

    // Type
    font.drawString(label_x, prop_y, "Type:", graphics.DARK_GRAY, null);
    const type_str = if (file_is_dir) "Folder" else "File";
    font.drawString(value_x, prop_y, type_str, graphics.BLACK, null);
    prop_y += 18;

    // Size
    font.drawString(label_x, prop_y, "Size:", graphics.DARK_GRAY, null);
    if (!file_is_dir) {
        var size_buf: [20]u8 = undefined;
        const size_len = formatSize(file_size, &size_buf);
        font.drawString(value_x, prop_y, size_buf[0..size_len], graphics.BLACK, null);
    } else {
        font.drawString(value_x, prop_y, "--", graphics.BLACK, null);
    }
    prop_y += 18;

    // Location
    font.drawString(label_x, prop_y, "Location:", graphics.DARK_GRAY, null);
    font.drawString(value_x, prop_y, "/", graphics.BLACK, null);
    prop_y += 18;

    // Attributes
    font.drawString(label_x, prop_y, "Attributes:", graphics.DARK_GRAY, null);
    var attr_buf: [32]u8 = undefined;
    const attr_len = formatAttributes(file_attr, &attr_buf);
    font.drawString(value_x, prop_y, attr_buf[0..attr_len], graphics.BLACK, null);
    prop_y += 18;

    // Cluster (technical info)
    if (content_width > 180) {
        font.drawString(label_x, prop_y, "Cluster:", graphics.DARK_GRAY, null);
        var cluster_buf: [12]u8 = undefined;
        const cluster_len = formatNum(file_cluster, &cluster_buf);
        font.drawString(value_x, prop_y, cluster_buf[0..cluster_len], Color.rgb(100, 100, 110), null);
    }
}

fn formatSize(size: u32, buf: []u8) usize {
    var len: usize = 0;

    // Format with units
    if (size >= 1024 * 1024) {
        const mb = size / (1024 * 1024);
        len = formatNum(mb, buf);
        const suffix = " MB (";
        for (suffix) |c| {
            buf[len] = c;
            len += 1;
        }
    } else if (size >= 1024) {
        const kb = size / 1024;
        len = formatNum(kb, buf);
        const suffix = " KB (";
        for (suffix) |c| {
            buf[len] = c;
            len += 1;
        }
    } else {
        len = formatNum(size, buf);
        const suffix = " bytes";
        for (suffix) |c| {
            buf[len] = c;
            len += 1;
        }
        return len;
    }

    // Add exact bytes
    len += formatNum(size, buf[len..]);
    const bytes_suffix = " bytes)";
    for (bytes_suffix) |c| {
        buf[len] = c;
        len += 1;
    }

    return len;
}

fn formatAttributes(attr: u8, buf: []u8) usize {
    var len: usize = 0;

    if (attr & 0x01 != 0) {
        const s = "R";
        for (s) |c| {
            buf[len] = c;
            len += 1;
        }
    }
    if (attr & 0x02 != 0) {
        const s = "H";
        for (s) |c| {
            buf[len] = c;
            len += 1;
        }
    }
    if (attr & 0x04 != 0) {
        const s = "S";
        for (s) |c| {
            buf[len] = c;
            len += 1;
        }
    }
    if (attr & 0x20 != 0) {
        const s = "A";
        for (s) |c| {
            buf[len] = c;
            len += 1;
        }
    }

    if (len == 0) {
        const s = "None";
        for (s) |c| {
            buf[len] = c;
            len += 1;
        }
    }

    return len;
}

fn formatNum(val: u32, buf: []u8) usize {
    var v = val;
    var len: usize = 0;

    if (v == 0) {
        buf[0] = '0';
        return 1;
    }

    var digits: [12]u8 = undefined;
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
