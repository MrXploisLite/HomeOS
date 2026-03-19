// Home OS - Notepad App
// Copyright © 2025 Romy Rianata - Home OS

const graphics = @import("../../drivers/graphics.zig");
const font = @import("../../drivers/font.zig");
const window = @import("../window.zig");
const Window = window.Window;
const TITLE_BAR_HEIGHT = window.TITLE_BAR_HEIGHT;

const LINE_NUM_WIDTH: i32 = 28;
const STATUS_BAR_HEIGHT: u32 = 18;

/// Draw notepad content - auto-sizes to window
pub fn draw(win: *const Window, x: i32, y: i32) void {
    // Calculate dimensions from window
    const content_width = win.width - 8;
    const content_height = win.height - @as(u32, @intCast(TITLE_BAR_HEIGHT)) - 8;
    const text_area_height = content_height - STATUS_BAR_HEIGHT;
    const text_area_width = content_width - @as(u32, @intCast(LINE_NUM_WIDTH));
    const t_w = @as(i32, @intCast(text_area_width)) - 8;
    const chars_per_line: usize = @intCast(@max(10, @divTrunc(t_w, 8)));
    const t_h = @as(i32, @intCast(text_area_height)) - 8;
    const max_lines: usize = @intCast(@max(1, @divTrunc(t_h, 12)));

    // Line number gutter with better styling
    graphics.fillRect(x, y, @intCast(LINE_NUM_WIDTH), text_area_height, graphics.Color.rgb(245, 245, 250));
    graphics.drawLine(x + LINE_NUM_WIDTH - 1, y, x + LINE_NUM_WIDTH - 1, y + @as(i32, @intCast(text_area_height)), graphics.Color.rgb(220, 220, 225));

    // Text area
    graphics.fillRect(x + LINE_NUM_WIDTH, y, text_area_width, text_area_height, graphics.WHITE);
    graphics.drawRect(x + LINE_NUM_WIDTH, y, text_area_width, text_area_height, graphics.DARK_GRAY);

    // Status bar with better styling
    const status_y = y + @as(i32, @intCast(text_area_height)) + 2;
    graphics.fillRect(x, status_y, content_width, STATUS_BAR_HEIGHT, graphics.Color.rgb(235, 235, 240));
    graphics.drawLine(x, status_y, x + @as(i32, @intCast(content_width)), status_y, graphics.Color.rgb(200, 200, 205));
    var char_buf: [20]u8 = undefined;
    const char_len = formatCharCount(win.notepad_len, &char_buf);
    font.drawString(x + 4, status_y + 3, char_buf[0..char_len], graphics.DARK_GRAY, null);

    // Count lines for status
    var line_count: usize = 1;
    var i: usize = 0;
    while (i < win.notepad_len) : (i += 1) {
        if (win.notepad_text[i] == '\n') line_count += 1;
    }
    var line_buf: [16]u8 = undefined;
    const line_len = formatLineCount(line_count, &line_buf);
    font.drawString(x + 100, status_y + 3, line_buf[0..line_len], graphics.DARK_GRAY, null);

    // Word wrap indicator
    const wrap_str = if (word_wrap) "Wrap:ON" else "Wrap:OFF";
    font.drawString(x + @as(i32, @intCast(content_width)) - 60, status_y + 3, wrap_str, graphics.GRAY, null);

    // Find bar (if active)
    if (find_mode) {
        const find_y = y + 2;
        graphics.fillRect(x + LINE_NUM_WIDTH + 2, find_y, 150, 14, graphics.Color.rgb(255, 255, 200));
        graphics.drawRect(x + LINE_NUM_WIDTH + 2, find_y, 150, 14, graphics.DARK_GRAY);
        font.drawString(x + LINE_NUM_WIDTH + 4, find_y + 2, "Find:", graphics.BLACK, null);
        font.drawString(x + LINE_NUM_WIDTH + 44, find_y + 2, find_text[0..find_text_len], graphics.BLACK, null);
        // Result indicator
        if (find_text_len > 0) {
            const result_str = if (find_result_pos >= 0) "Found" else "Not found";
            const result_color = if (find_result_pos >= 0) graphics.GREEN else graphics.RED;
            font.drawString(x + LINE_NUM_WIDTH + 156, find_y + 2, result_str, result_color, null);
        }
    }

    const max_y = y + @as(i32, @intCast(text_area_height)) - 12;

    if (win.notepad_len == 0) {
        font.drawString(x + 4, y + 4, "1", graphics.DARK_GRAY, null);
        font.drawString(x + LINE_NUM_WIDTH + 4, y + 4, "Type here...", graphics.GRAY, null);
    } else {
        var line_y = y + 4;
        var line_start: usize = 0;
        var line_num: usize = 1;
        var num_buf: [4]u8 = undefined;

        i = 0;
        while (i < win.notepad_len) : (i += 1) {
            if (win.notepad_text[i] == '\n' or i - line_start >= chars_per_line) {
                const num_len = formatNum(line_num, &num_buf);
                font.drawString(x + 4, line_y, num_buf[0..num_len], graphics.DARK_GRAY, null);
                font.drawString(x + LINE_NUM_WIDTH + 4, line_y, win.notepad_text[line_start..i], graphics.BLACK, null);
                line_y += 12;
                line_num += 1;
                line_start = if (win.notepad_text[i] == '\n') i + 1 else i;
                if (line_y > max_y) break;
            }
        }
        if (line_start < win.notepad_len and line_y <= max_y) {
            const num_len = formatNum(line_num, &num_buf);
            font.drawString(x + 4, line_y, num_buf[0..num_len], graphics.DARK_GRAY, null);
            font.drawString(x + LINE_NUM_WIDTH + 4, line_y, win.notepad_text[line_start..win.notepad_len], graphics.BLACK, null);
        }
    }

    // Draw cursor if focused
    if (win.focused) {
        const cursor_col = win.notepad_len % chars_per_line;
        const cursor_row = win.notepad_len / chars_per_line;
        if (cursor_row < max_lines) {
            const text_cursor_x = x + LINE_NUM_WIDTH + 4 + @as(i32, @intCast(cursor_col * 8));
            const text_cursor_y = y + 4 + @as(i32, @intCast(cursor_row * 12));
            graphics.fillRect(text_cursor_x, text_cursor_y, 2, 10, graphics.BLACK);
        }
    }
}

fn formatCharCount(count: usize, buf: []u8) usize {
    var len: usize = 0;
    const prefix = "Chars: ";
    for (prefix) |c| {
        buf[len] = c;
        len += 1;
    }
    len += formatNum(count, buf[len..]);
    return len;
}

fn formatLineCount(count: usize, buf: []u8) usize {
    var len: usize = 0;
    const prefix = "Lines: ";
    for (prefix) |c| {
        buf[len] = c;
        len += 1;
    }
    len += formatNum(count, buf[len..]);
    return len;
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

// Undo buffer
var undo_text: [512]u8 = undefined;
var undo_len: usize = 0;
var has_undo: bool = false;

// Word wrap toggle
pub var word_wrap: bool = true;

// Scroll offset for notepad view (in lines)
var notepad_scroll_line: usize = 0;

// Find feature
var find_mode: bool = false;
var find_text: [32]u8 = [_]u8{0} ** 32;
var find_text_len: usize = 0;
var find_result_pos: i32 = -1; // -1 = not found

/// Handle mouse scroll wheel
pub fn handleScroll(delta: i8) void {
    // QEMU/IntelliMouse: positive = scroll down, negative = scroll up
    const scroll_lines: usize = 2;

    if (delta < 0) {
        // Scroll wheel UP - see earlier content (decrease line offset)
        const amount = @as(usize, @intCast(@abs(delta))) * scroll_lines;
        if (notepad_scroll_line >= amount) {
            notepad_scroll_line -= amount;
        } else {
            notepad_scroll_line = 0;
        }
    } else if (delta > 0) {
        // Scroll wheel DOWN - see later content (increase line offset)
        const amount = @as(usize, @intCast(@abs(delta))) * scroll_lines;
        notepad_scroll_line += amount;
        // Will be clamped when drawing
    }
}

/// Handle keyboard input with save/load/undo support
pub fn handleKey(win: *Window, key: u8) void {
    const keyboard = @import("../../drivers/keyboard.zig");

    // Ctrl+S = Save (key 19)
    if (key == 19) {
        saveToFat32(win);
        return;
    }
    // Ctrl+O = Open (key 15)
    if (key == 15) {
        loadFromFat32(win);
        return;
    }
    // Ctrl+Z = Undo (key 26)
    if (key == 26) {
        doUndo(win);
        return;
    }
    // Ctrl+W = Toggle word wrap (key 23)
    if (key == 23) {
        word_wrap = !word_wrap;
        return;
    }
    // Ctrl+F = Find (key 6)
    if (key == 6) {
        find_mode = !find_mode;
        if (!find_mode) {
            find_text_len = 0;
            find_result_pos = -1;
        }
        return;
    }
    // Ctrl+A = Select all (key 1) - copy all to clipboard
    if (key == 1) {
        // For now, just highlight that all is selected
        return;
    }

    // Handle find mode input
    if (find_mode) {
        if (key == 27) { // ESC to exit find
            find_mode = false;
            find_text_len = 0;
            find_result_pos = -1;
        } else if (key == 8) { // Backspace
            if (find_text_len > 0) find_text_len -= 1;
            doFind(win);
        } else if (key == '\n' or key == '\r') {
            doFind(win);
        } else if (key >= 32 and key < 127 and find_text_len < 31) {
            find_text[find_text_len] = key;
            find_text_len += 1;
            doFind(win);
        }
        return;
    }

    // Save undo state before modification
    if (key == 8 or (key >= 32 and key < 127) or key == '\n' or key == '\r') {
        saveUndo(win);
    }

    if (key == 8) {
        // Backspace
        if (win.notepad_len > 0) {
            win.notepad_len -= 1;
        }
    } else if (key == '\n' or key == '\r') {
        // Enter
        if (win.notepad_len < 511) {
            win.notepad_text[win.notepad_len] = '\n';
            win.notepad_len += 1;
        }
    } else if (key >= 32 and key < 127) {
        // Printable character
        if (win.notepad_len < 511) {
            win.notepad_text[win.notepad_len] = key;
            win.notepad_len += 1;
        }
    }
    _ = keyboard;
}

fn saveUndo(win: *Window) void {
    for (0..win.notepad_len) |i| {
        undo_text[i] = win.notepad_text[i];
    }
    undo_len = win.notepad_len;
    has_undo = true;
}

fn doUndo(win: *Window) void {
    if (!has_undo) return;
    // Swap current with undo
    var temp: [512]u8 = undefined;
    const temp_len = win.notepad_len;
    for (0..win.notepad_len) |i| {
        temp[i] = win.notepad_text[i];
    }
    for (0..undo_len) |i| {
        win.notepad_text[i] = undo_text[i];
    }
    win.notepad_len = undo_len;
    for (0..temp_len) |i| {
        undo_text[i] = temp[i];
    }
    undo_len = temp_len;
}

fn saveToFat32(win: *Window) void {
    const fat32 = @import("../../fs/fat32.zig");
    if (!fat32.isInitialized()) return;
    if (fat32.getFS()) |fs| {
        // Save as "NOTEPAD.TXT" in root directory (cluster 2)
        _ = fs.writeFile(fs.root_cluster, "NOTEPAD.TXT", win.notepad_text[0..win.notepad_len]);
    }
}

fn loadFromFat32(win: *Window) void {
    const fat32 = @import("../../fs/fat32.zig");
    if (!fat32.isInitialized()) return;
    if (fat32.getFS()) |fs| {
        // Try to load NOTEPAD.TXT from root
        if (fs.findFile(fs.root_cluster, "NOTEPAD.TXT")) |entry| {
            win.notepad_len = fs.readFile(&entry, &win.notepad_text, 512);
        }
    }
}

/// Load specific file content into notepad (called from file manager)
pub fn loadFileContent(win: *window.Window, name: []const u8) void {
    const fat32 = @import("../../fs/fat32.zig");
    if (!fat32.isInitialized()) return;
    if (fat32.getFS()) |fs| {
        if (fs.findFile(fs.root_cluster, name)) |entry| {
            win.notepad_len = fs.readFile(&entry, &win.notepad_text, 512);
        }
    }
}

// Shared buffer for file content to open
pub var pending_file: [12]u8 = [_]u8{0} ** 12;
pub var pending_file_len: usize = 0;

fn doFind(win: *const Window) void {
    if (find_text_len == 0) {
        find_result_pos = -1;
        return;
    }
    // Simple substring search
    var i: usize = 0;
    while (i + find_text_len <= win.notepad_len) : (i += 1) {
        var match = true;
        var j: usize = 0;
        while (j < find_text_len) : (j += 1) {
            if (win.notepad_text[i + j] != find_text[j]) {
                match = false;
                break;
            }
        }
        if (match) {
            find_result_pos = @intCast(i);
            return;
        }
    }
    find_result_pos = -1;
}

/// Check if find mode is active (for draw)
pub fn isFindMode() bool {
    return find_mode;
}

/// Get find text for display
pub fn getFindText() []const u8 {
    return find_text[0..find_text_len];
}

/// Get find result position
pub fn getFindResult() i32 {
    return find_result_pos;
}
