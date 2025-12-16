// Home OS - File Manager App
// Copyright © 2025 Romy Rianata - Home OS

const graphics = @import("../../drivers/graphics.zig");
const font = @import("../../drivers/font.zig");
const fat32 = @import("../../fs/fat32.zig");
const window = @import("../window.zig");
const keyboard = @import("../../drivers/keyboard.zig");
const Window = window.Window;
const TITLE_BAR_HEIGHT = window.TITLE_BAR_HEIGHT;

// File list state
var file_names: [32][12]u8 = [_][12]u8{[_]u8{0} ** 12} ** 32;
var file_sizes: [32]u32 = [_]u32{0} ** 32;
var file_is_dir: [32]bool = [_]bool{false} ** 32;
var file_count: usize = 0;
var selected_idx: usize = 0;
var scroll_offset: usize = 0;
var files_loaded: bool = false;
var current_path: [64]u8 = [_]u8{0} ** 64;
var path_len: usize = 1;
var cached_max_visible: usize = 10; // Updated by draw()

// Clipboard state for copy/paste
var clipboard_name: [12]u8 = [_]u8{0} ** 12;
var clipboard_name_len: usize = 0;
var clipboard_has_file: bool = false;
var clipboard_is_cut: bool = false; // true = cut, false = copy

fn collectFileEntry(entry: *const fat32.DirEntry) void {
    if (file_count >= 32) return;
    if ((entry.attr & 0x08) != 0) return; // Skip volume label

    const len = fat32.getName83(entry, &file_names[file_count]);
    _ = len;
    file_sizes[file_count] = entry.file_size;
    file_is_dir[file_count] = entry.isDirectory();
    file_count += 1;
}

pub fn loadFiles() void {
    file_count = 0;
    selected_idx = 0;
    scroll_offset = 0;

    // Set root path
    current_path[0] = '/';
    path_len = 1;

    if (!fat32.isInitialized()) {
        files_loaded = false;
        return;
    }

    if (fat32.getFS()) |fs| {
        fs.listRoot(&collectFileEntry);
        files_loaded = true;
    } else {
        files_loaded = false;
    }
}

/// Draw file manager content - auto-sizes to window
pub fn draw(win: *const Window, x: i32, y: i32) void {
    // Calculate dimensions from window
    const content_width = win.width - 8;
    const content_height = win.height - @as(u32, @intCast(TITLE_BAR_HEIGHT)) - 8;
    const toolbar_height: u32 = 22;
    const header_height: u32 = 20;
    const status_height: u32 = 18;
    const list_height = content_height - toolbar_height - header_height - status_height - 4;
    const max_visible: usize = @intCast(@max(1, @divTrunc(@as(i32, @intCast(list_height)), 16)));
    cached_max_visible = max_visible; // Cache for handleKey

    // Toolbar
    graphics.fillRect(x, y, content_width, toolbar_height, graphics.LIGHT_GRAY);
    graphics.fillRect(x + 4, y + 2, 50, 18, graphics.WHITE);
    graphics.drawRect(x + 4, y + 2, 50, 18, graphics.DARK_GRAY);
    font.drawString(x + 10, y + 4, "Refresh", graphics.BLACK, null);
    const path_width = content_width - 60;
    graphics.fillRect(x + 60, y + 2, path_width, 18, graphics.WHITE);
    graphics.drawRect(x + 60, y + 2, path_width, 18, graphics.DARK_GRAY);
    // Clip path to fit in path bar
    const max_path_chars: usize = @intCast(@max(4, @divTrunc(@as(i32, @intCast(path_width)) - 8, 8)));
    const display_path_len = @min(path_len, max_path_chars);
    font.drawString(x + 64, y + 4, current_path[0..display_path_len], graphics.BLACK, null);

    // Column Header
    const header_y = y + @as(i32, @intCast(toolbar_height)) + 2;
    graphics.fillRect(x, header_y, content_width, header_height, graphics.DARK_GRAY);
    // Name column with sort indicator
    font.drawString(x + 4, header_y + 2, "Name", graphics.WHITE, null);
    if (!sort_by_size) font.drawString(x + 40, header_y + 2, "v", graphics.YELLOW, null);
    const size_col = x + @as(i32, @intCast(content_width)) - 130;
    const type_col = x + @as(i32, @intCast(content_width)) - 60;
    // Size column with sort indicator
    font.drawString(size_col, header_y + 2, "Size", graphics.WHITE, null);
    if (sort_by_size) font.drawString(size_col + 32, header_y + 2, "v", graphics.YELLOW, null);
    font.drawString(type_col, header_y + 2, "Type", graphics.WHITE, null);

    // File list area
    const list_y = header_y + @as(i32, @intCast(header_height)) + 2;
    graphics.fillRect(x, list_y, content_width, list_height, graphics.WHITE);
    graphics.drawRect(x, list_y, content_width, list_height, graphics.DARK_GRAY);

    if (!files_loaded) {
        if (!fat32.isInitialized()) {
            font.drawString(x + 8, list_y + 16, "FAT32 not initialized", graphics.RED, null);
        } else {
            font.drawString(x + 8, list_y + 16, "Loading...", graphics.GRAY, null);
            loadFiles();
        }
        return;
    }

    if (file_count == 0) {
        font.drawString(x + 8, list_y + 16, "(empty)", graphics.GRAY, null);
        return;
    }

    // Draw files with alternating row colors
    var i: usize = scroll_offset;
    var row_y = list_y + 2;
    const row_height: i32 = 18;

    while (i < file_count and i < scroll_offset + max_visible) : (i += 1) {
        // Alternating background
        const row_bg = if (i == selected_idx)
            graphics.WINDOW_TITLE
        else if (i % 2 == 0)
            graphics.WHITE
        else
            graphics.Color.rgb(245, 245, 250);

        graphics.fillRect(x + 1, row_y, content_width - 2, @intCast(row_height), row_bg);

        const text_color = if (i == selected_idx) graphics.WHITE else graphics.BLACK;

        // Better folder/file icons
        if (file_is_dir[i]) {
            // Folder icon
            graphics.fillRect(x + 4, row_y + 2, 14, 12, graphics.Color.rgb(255, 200, 80));
            graphics.fillRect(x + 4, row_y + 1, 6, 3, graphics.Color.rgb(255, 200, 80));
            graphics.drawRect(x + 4, row_y + 2, 14, 12, graphics.Color.rgb(200, 150, 50));
        } else {
            // File icon
            graphics.fillRect(x + 6, row_y + 2, 10, 13, graphics.WHITE);
            graphics.drawRect(x + 6, row_y + 2, 10, 13, graphics.DARK_GRAY);
            graphics.fillRect(x + 12, row_y + 2, 4, 4, graphics.LIGHT_GRAY);
        }
        // Clip filename to fit in name column (max ~15 chars before size column)
        const max_name_chars: usize = @intCast(@max(8, @divTrunc(@as(i32, @intCast(content_width)) - 160, 8)));
        var name_len: usize = 0;
        while (name_len < 12 and file_names[i][name_len] != 0) : (name_len += 1) {}
        const display_len = @min(name_len, max_name_chars);
        font.drawString(x + 22, row_y + 4, file_names[i][0..display_len], text_color, null);

        if (!file_is_dir[i]) {
            var size_buf: [10]u8 = undefined;
            const size_len = formatSize(file_sizes[i], &size_buf);
            font.drawString(size_col, row_y + 4, size_buf[0..size_len], text_color, null);
        } else {
            font.drawString(size_col, row_y + 4, "<DIR>", text_color, null);
        }

        const type_str = if (file_is_dir[i]) "Folder" else "File";
        font.drawString(type_col, row_y + 4, type_str, text_color, null);

        row_y += row_height;
    }

    // Status bar
    const status_y = list_y + @as(i32, @intCast(list_height)) + 2;
    graphics.fillRect(x, status_y, content_width, status_height, graphics.LIGHT_GRAY);
    var count_buf: [20]u8 = undefined;
    const count_len = formatCount(file_count, &count_buf);
    font.drawString(x + 4, status_y + 2, count_buf[0..count_len], graphics.BLACK, null);

    // Show total size
    const total_size = getTotalSize();
    if (total_size > 0 and content_width > 150) {
        var size_buf: [16]u8 = undefined;
        const size_len = formatSize(total_size, &size_buf);
        font.drawString(x + 70, status_y + 2, size_buf[0..size_len], graphics.DARK_GRAY, null);
    }

    // Show clipboard status
    if (clipboard_has_file and content_width > 220) {
        const clip_x = x + 130;
        const clip_icon = if (clipboard_is_cut) "[CUT]" else "[COPY]";
        font.drawString(clip_x, status_y + 2, clip_icon, graphics.Color.rgb(50, 120, 200), null);
    }

    // Only show help text if window is wide enough
    if (content_width > 320) {
        font.drawString(x + @as(i32, @intCast(content_width)) - 180, status_y + 2, "C:Copy X:Cut V:Paste", graphics.DARK_GRAY, null);
    } else if (content_width > 240) {
        font.drawString(x + @as(i32, @intCast(content_width)) - 80, status_y + 2, "T:Sort", graphics.DARK_GRAY, null);
    }
}

/// Handle mouse scroll wheel
pub fn handleScroll(delta: i8) void {
    if (!files_loaded or file_count == 0) return;
    const max_visible: usize = cached_max_visible;

    // QEMU/IntelliMouse: positive = scroll down, negative = scroll up
    if (delta < 0) {
        // Scroll wheel UP - move selection toward beginning
        const amount = @as(usize, @intCast(@abs(delta)));
        if (selected_idx >= amount) {
            selected_idx -= amount;
        } else {
            selected_idx = 0;
        }
        // Adjust scroll offset to keep selection visible
        if (selected_idx < scroll_offset) {
            scroll_offset = selected_idx;
        }
    } else if (delta > 0) {
        // Scroll wheel DOWN - move selection toward end
        const amount = @as(usize, @intCast(@abs(delta)));
        if (selected_idx + amount < file_count) {
            selected_idx += amount;
        } else if (file_count > 0) {
            selected_idx = file_count - 1;
        }
        // Adjust scroll offset to keep selection visible
        if (max_visible > 0 and selected_idx >= scroll_offset + max_visible) {
            scroll_offset = selected_idx - max_visible + 1;
        }
    }
}

/// Handle keyboard input
pub fn handleKey(key: u8) void {
    // Refresh always works
    if (key == 'r' or key == 'R') {
        loadFiles();
        return;
    }

    if (!files_loaded or file_count == 0) return;

    const max_visible: usize = cached_max_visible;

    if (key == 'w' or key == 'W' or key == keyboard.KEY_UP) {
        // Up
        if (selected_idx > 0) {
            selected_idx -= 1;
            if (selected_idx < scroll_offset) {
                scroll_offset = selected_idx;
            }
        }
    } else if (key == 's' or key == 'S' or key == keyboard.KEY_DOWN) {
        // Down
        if (selected_idx < file_count - 1) {
            selected_idx += 1;
            if (selected_idx >= scroll_offset + max_visible) {
                scroll_offset = selected_idx - max_visible + 1;
            }
        }
    } else if (key == keyboard.KEY_PAGE_UP) {
        // Page Up
        if (selected_idx >= max_visible) {
            selected_idx -= max_visible;
        } else {
            selected_idx = 0;
        }
        if (selected_idx < scroll_offset) {
            scroll_offset = selected_idx;
        }
    } else if (key == keyboard.KEY_PAGE_DOWN) {
        // Page Down
        if (selected_idx + max_visible < file_count) {
            selected_idx += max_visible;
        } else {
            selected_idx = file_count - 1;
        }
        if (selected_idx >= scroll_offset + max_visible) {
            scroll_offset = selected_idx - max_visible + 1;
        }
    } else if (key == keyboard.KEY_HOME) {
        // Home - go to first
        selected_idx = 0;
        scroll_offset = 0;
    } else if (key == keyboard.KEY_END) {
        // End - go to last
        selected_idx = file_count - 1;
        if (file_count > max_visible) {
            scroll_offset = file_count - max_visible;
        }
    } else if (key == '\n' or key == '\r') {
        // Enter - open file in notepad (future: navigate folders)
        openSelectedFile();
    } else if (key == 'd' or key == 'D') {
        // Delete selected file
        deleteSelectedFile();
    } else if (key == 'n' or key == 'N') {
        // Create new file
        createNewFile();
    } else if (key == 'c' or key == 'C' or key == 3) {
        // Copy (Ctrl+C = 3)
        copySelectedFile(false);
    } else if (key == 'x' or key == 'X' or key == 24) {
        // Cut (Ctrl+X = 24)
        copySelectedFile(true);
    } else if (key == 'v' or key == 'V' or key == 22) {
        // Paste (Ctrl+V = 22)
        pasteFile();
    } else if (key == 't' or key == 'T') {
        // Toggle sort mode
        sort_by_size = !sort_by_size;
        sortFiles();
    }
}

// Sort mode
var sort_by_size: bool = false;

fn sortFiles() void {
    if (file_count < 2) return;

    // Simple bubble sort (file count is small)
    var i: usize = 0;
    while (i < file_count - 1) : (i += 1) {
        var j: usize = 0;
        while (j < file_count - 1 - i) : (j += 1) {
            const should_swap = if (sort_by_size)
                file_sizes[j] < file_sizes[j + 1] // Larger first
            else
                compareNames(&file_names[j], &file_names[j + 1]) > 0;

            if (should_swap) {
                // Swap all arrays
                const tmp_name = file_names[j];
                file_names[j] = file_names[j + 1];
                file_names[j + 1] = tmp_name;

                const tmp_size = file_sizes[j];
                file_sizes[j] = file_sizes[j + 1];
                file_sizes[j + 1] = tmp_size;

                const tmp_dir = file_is_dir[j];
                file_is_dir[j] = file_is_dir[j + 1];
                file_is_dir[j + 1] = tmp_dir;
            }
        }
    }
}

fn compareNames(a: *const [12]u8, b: *const [12]u8) i32 {
    var i: usize = 0;
    while (i < 12) : (i += 1) {
        const ca = if (a[i] >= 'a' and a[i] <= 'z') a[i] - 32 else a[i];
        const cb = if (b[i] >= 'a' and b[i] <= 'z') b[i] - 32 else b[i];
        if (ca == 0 and cb == 0) return 0;
        if (ca == 0) return -1;
        if (cb == 0) return 1;
        if (ca < cb) return -1;
        if (ca > cb) return 1;
    }
    return 0;
}

/// Copy selected file to clipboard
fn copySelectedFile(is_cut: bool) void {
    if (!files_loaded or file_count == 0) return;
    if (selected_idx >= file_count) return;
    if (file_is_dir[selected_idx]) return; // Can't copy folders yet

    // Copy filename to clipboard
    clipboard_name_len = 0;
    for (file_names[selected_idx]) |c| {
        if (c == 0 or c == ' ') break;
        clipboard_name[clipboard_name_len] = c;
        clipboard_name_len += 1;
    }
    clipboard_has_file = clipboard_name_len > 0;
    clipboard_is_cut = is_cut;
}

/// Paste file from clipboard
fn pasteFile() void {
    if (!clipboard_has_file or clipboard_name_len == 0) return;
    if (!fat32.isInitialized()) return;

    if (fat32.getFS()) |fs| {
        // Find source file entry first
        const entry = fs.findFile(fs.root_cluster, clipboard_name[0..clipboard_name_len]) orelse return;

        // Read source file content
        var content_buf: [4096]u8 = undefined;
        const bytes_read = fs.readFile(&entry, &content_buf, 4096);

        if (bytes_read > 0) {
            if (clipboard_is_cut) {
                // Cut: delete original after copy
                _ = fs.deleteFile(fs.root_cluster, clipboard_name[0..clipboard_name_len]);
                clipboard_has_file = false;
                clipboard_name_len = 0;
            }

            // Generate new filename (add _copy suffix if same name exists)
            var new_name: [12]u8 = undefined;
            var new_len: usize = 0;

            // Find extension position
            var ext_pos: usize = clipboard_name_len;
            var i: usize = clipboard_name_len;
            while (i > 0) {
                i -= 1;
                if (clipboard_name[i] == '.') {
                    ext_pos = i;
                    break;
                }
            }

            // Check if destination file already exists
            if (fs.findFile(fs.root_cluster, clipboard_name[0..clipboard_name_len])) |_| {
                // File exists, add suffix
                const base_len = @min(ext_pos, 5); // Limit base name
                for (clipboard_name[0..base_len]) |c| {
                    new_name[new_len] = c;
                    new_len += 1;
                }
                // Add _CP suffix
                new_name[new_len] = '_';
                new_len += 1;
                new_name[new_len] = 'C';
                new_len += 1;
                new_name[new_len] = 'P';
                new_len += 1;
                // Add extension
                if (ext_pos < clipboard_name_len) {
                    for (clipboard_name[ext_pos..clipboard_name_len]) |c| {
                        if (c == 0 or c == ' ') break;
                        new_name[new_len] = c;
                        new_len += 1;
                    }
                }
            } else {
                // File doesn't exist, use same name
                for (clipboard_name[0..clipboard_name_len]) |c| {
                    new_name[new_len] = c;
                    new_len += 1;
                }
            }

            // Write new file
            _ = fs.writeFile(fs.root_cluster, new_name[0..new_len], content_buf[0..bytes_read]);
            loadFiles(); // Refresh
        }
    }
}

fn openSelectedFile() void {
    if (!files_loaded or file_count == 0) return;
    if (selected_idx >= file_count) return;

    if (file_is_dir[selected_idx]) {
        // Navigate into folder
        navigateIntoFolder();
        return;
    }

    // Open file in notepad - store filename for desktop to pick up
    const notepad = @import("notepad.zig");
    var name_len: usize = 0;
    for (file_names[selected_idx]) |c| {
        if (c == 0 or c == ' ') break;
        notepad.pending_file[name_len] = c;
        name_len += 1;
    }
    notepad.pending_file_len = name_len;
    open_file_requested = true;
}

// Flag to signal desktop to open notepad with file
pub var open_file_requested: bool = false;

fn navigateIntoFolder() void {
    if (!files_loaded or file_count == 0) return;
    if (selected_idx >= file_count) return;
    if (!file_is_dir[selected_idx]) return;

    // Get folder name
    var folder_name: [12]u8 = undefined;
    var name_len: usize = 0;
    for (file_names[selected_idx]) |c| {
        if (c == 0 or c == ' ') break;
        folder_name[name_len] = c;
        name_len += 1;
    }

    // Skip . and .. for now (would need parent tracking)
    if (name_len == 1 and folder_name[0] == '.') return;
    if (name_len == 2 and folder_name[0] == '.' and folder_name[1] == '.') return;

    // Find folder entry and get its cluster
    if (fat32.getFS()) |fs| {
        if (fs.findFile(fs.root_cluster, folder_name[0..name_len])) |entry| {
            if (entry.isDirectory()) {
                // Update path display
                if (path_len < 60) {
                    for (folder_name[0..name_len]) |c| {
                        if (path_len < 63) {
                            current_path[path_len] = c;
                            path_len += 1;
                        }
                    }
                    if (path_len < 63) {
                        current_path[path_len] = '/';
                        path_len += 1;
                    }
                }
                // List directory contents
                current_cluster = entry.getCluster();
                loadFilesFromCluster(current_cluster);
            }
        }
    }
}

var current_cluster: u32 = 0;

fn loadFilesFromCluster(cluster: u32) void {
    file_count = 0;
    selected_idx = 0;
    scroll_offset = 0;

    if (!fat32.isInitialized()) {
        files_loaded = false;
        return;
    }

    if (fat32.getFS()) |fs| {
        fs.listDirectory(cluster, &collectFileEntry);
        files_loaded = true;
    } else {
        files_loaded = false;
    }
}

fn deleteSelectedFile() void {
    if (!files_loaded or file_count == 0) return;
    if (selected_idx >= file_count) return;
    if (file_is_dir[selected_idx]) return; // Can't delete folders

    // Get filename and delete
    var name_buf: [12]u8 = undefined;
    var name_len: usize = 0;
    for (file_names[selected_idx]) |c| {
        if (c == 0 or c == ' ') break;
        name_buf[name_len] = c;
        name_len += 1;
    }

    if (name_len > 0) {
        if (fat32.getFS()) |fs| {
            _ = fs.deleteFile(fs.root_cluster, name_buf[0..name_len]);
            loadFiles(); // Refresh
        }
    }
}

fn createNewFile() void {
    if (!fat32.isInitialized()) return;
    if (fat32.getFS()) |fs| {
        // Create empty file with timestamp name
        _ = fs.writeFile(fs.root_cluster, "NEWFILE.TXT", "");
        loadFiles(); // Refresh
    }
}

/// Handle mouse click - uses window dimensions
pub fn handleClick(win: *const Window, mx: i32, my: i32) void {
    const content_x = win.x + 4;
    const content_y = win.y + TITLE_BAR_HEIGHT + 4;
    const content_width = win.width - 8;
    const content_height = win.height - @as(u32, @intCast(TITLE_BAR_HEIGHT)) - 8;
    const list_height = content_height - 22 - 20 - 18 - 4; // toolbar, header, status, padding

    // Check toolbar - Refresh button
    if (my >= content_y + 2 and my < content_y + 20) {
        if (mx >= content_x + 4 and mx < content_x + 54) {
            loadFiles();
            return;
        }
    }

    // Check file list area
    const list_y = content_y + 22 + 20 + 4; // after toolbar and header
    const list_y_end = list_y + @as(i32, @intCast(list_height));

    if (my >= list_y and my < list_y_end) {
        if (mx >= content_x and mx < content_x + @as(i32, @intCast(content_width))) {
            const rel_y = my - list_y;
            const clicked_row = @as(usize, @intCast(rel_y)) / 16;
            const new_idx = scroll_offset + clicked_row;
            if (new_idx < file_count) {
                selected_idx = new_idx;
            }
        }
    }
}

fn formatSize(size: u32, buf: []u8) usize {
    if (size >= 1024 * 1024) {
        const mb = size / (1024 * 1024);
        return formatNum(mb, buf, " MB");
    } else if (size >= 1024) {
        const kb = size / 1024;
        return formatNum(kb, buf, " KB");
    } else {
        return formatNum(size, buf, " B");
    }
}

fn formatNum(val: u32, buf: []u8, suffix: []const u8) usize {
    var v = val;
    var len: usize = 0;

    if (v == 0) {
        buf[0] = '0';
        len = 1;
    } else {
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
    }

    for (suffix) |c| {
        buf[len] = c;
        len += 1;
    }

    return len;
}

fn formatCount(count: usize, buf: []u8) usize {
    var len: usize = 0;
    var v = count;

    if (v == 0) {
        buf[0] = '0';
        len = 1;
    } else {
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
    }

    const suffix = " file(s)";
    for (suffix) |c| {
        buf[len] = c;
        len += 1;
    }

    return len;
}

/// Calculate total size of all files
fn getTotalSize() u32 {
    var total: u32 = 0;
    var i: usize = 0;
    while (i < file_count) : (i += 1) {
        if (!file_is_dir[i]) {
            total += file_sizes[i];
        }
    }
    return total;
}
