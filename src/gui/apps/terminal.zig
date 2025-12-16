// Home OS - GUI Terminal App
// Copyright © 2025 Romy Rianata - Home OS
// Uses unified command executor

const graphics = @import("../../drivers/graphics.zig");
const font = @import("../../drivers/font.zig");
const window = @import("../window.zig");
const Window = window.Window;
const output = @import("../../lib/output.zig");
const cmd_executor = @import("../../shell/cmd_executor.zig");
const keyboard = @import("../../drivers/keyboard.zig");

// Terminal state
var term_input: [256]u8 = [_]u8{0} ** 256;
var term_input_len: usize = 0;
var term_output: [8192]u8 = [_]u8{0} ** 8192; // Larger buffer
var term_output_len: usize = 0;

// Scroll state
var scroll_offset: usize = 0; // Lines scrolled up from bottom

// Command history
const MAX_HISTORY: usize = 16;
var history: [MAX_HISTORY][256]u8 = [_][256]u8{[_]u8{0} ** 256} ** MAX_HISTORY;
var history_lens: [MAX_HISTORY]usize = [_]usize{0} ** MAX_HISTORY;
var history_count: usize = 0;
var history_idx: usize = 0; // Current position in history (for navigation)
var browsing_history: bool = false;

// Exit flag
var exit_requested_flag: bool = false;

pub fn isExitRequested() bool {
    return exit_requested_flag;
}

pub fn clearExitRequest() void {
    exit_requested_flag = false;
}

/// Draw terminal content - auto-sizes to window
pub fn draw(win: *const Window, x: i32, y: i32) void {
    // Calculate dimensions from window size (content area)
    const content_width = win.width - 12;
    const content_height = win.height - window.TITLE_BAR_HEIGHT - 12;

    // Terminal background with subtle border
    graphics.fillRect(x - 2, y - 2, content_width, content_height, graphics.Color.rgb(20, 20, 25));
    graphics.drawRect(x - 2, y - 2, content_width, content_height, graphics.Color.rgb(60, 60, 65));

    const line_height: i32 = 14;
    const prompt_height: i32 = 20;
    const output_height = @as(i32, @intCast(content_height)) - prompt_height;
    const max_lines: usize = @intCast(@max(1, @divTrunc(output_height, line_height)));
    const max_chars: usize = @intCast(@max(10, @divTrunc(@as(i32, @intCast(content_width)) - 20, 8)));

    // Count total lines
    var total_lines: usize = 0;
    if (term_output_len > 0) {
        for (term_output[0..term_output_len]) |c| {
            if (c == '\n') total_lines += 1;
        }
        if (term_output_len > 0 and term_output[term_output_len - 1] != '\n') {
            total_lines += 1;
        }
    }

    // Calculate which lines to show (with scroll support)
    var skip_lines: usize = 0;
    const max_scroll = if (total_lines > max_lines) total_lines - max_lines else 0;

    // Clamp scroll_offset to valid range
    if (scroll_offset > max_scroll) {
        scroll_offset = max_scroll;
    }

    if (total_lines > max_lines) {
        skip_lines = total_lines - max_lines;
        if (scroll_offset <= skip_lines) {
            skip_lines -= scroll_offset;
        } else {
            skip_lines = 0;
        }
    }

    // Draw output lines with color support
    var line_y = y;
    var current_line: usize = 0;
    var line_start: usize = 0;
    var lines_drawn: usize = 0;

    var i: usize = 0;
    while (i <= term_output_len and lines_drawn < max_lines) : (i += 1) {
        const is_end = (i == term_output_len);
        const is_newline = (i < term_output_len and term_output[i] == '\n');

        if (is_newline or is_end) {
            if (current_line >= skip_lines) {
                const line_end = i;
                if (line_end > line_start) {
                    const display_end = if (line_end - line_start > max_chars) line_start + max_chars else line_end;
                    const line_text = term_output[line_start..display_end];
                    // Color based on content
                    const color = getLineColor(line_text);
                    font.drawString(x, line_y, line_text, color, null);
                }
                line_y += line_height;
                lines_drawn += 1;
            }
            current_line += 1;
            line_start = i + 1;
        }
    }

    // Draw scroll indicators
    const scroll_x = x + @as(i32, @intCast(content_width)) - 20;
    if (scroll_offset > 0) {
        font.drawString(scroll_x, y, "^", graphics.YELLOW, null);
    }
    if (total_lines > max_lines and scroll_offset < total_lines - max_lines) {
        font.drawString(scroll_x, y + output_height - 14, "v", graphics.YELLOW, null);
    }

    // Draw prompt and input at bottom with better styling
    const prompt_y = y + output_height;
    // Prompt background
    graphics.fillRect(x - 2, prompt_y - 2, content_width, 18, graphics.Color.rgb(30, 30, 35));
    // Colored prompt
    font.drawString(x, prompt_y, ">", graphics.Color.rgb(80, 250, 123), null);
    font.drawString(x + 8, prompt_y, " ", graphics.Color.rgb(80, 250, 123), null);
    if (term_input_len > 0) {
        const input_max = @min(term_input_len, max_chars - 3);
        font.drawString(x + 16, prompt_y, term_input[0..input_max], graphics.Color.rgb(248, 248, 242), null);
    }
    const cursor_pos = @min(term_input_len, max_chars - 3);
    const cursor_x = x + 16 + @as(i32, @intCast(cursor_pos * 8));
    font.drawString(cursor_x, prompt_y, "_", graphics.Color.rgb(80, 250, 123), null);
}

/// Get color for terminal line based on content
fn getLineColor(line: []const u8) graphics.Color {
    // Error messages in red
    if (line.len >= 5) {
        if (startsWithIgnoreCase(line, "error") or
            startsWithIgnoreCase(line, "fail") or
            startsWithIgnoreCase(line, "unknown"))
        {
            return graphics.Color.rgb(255, 100, 100);
        }
    }
    // Success messages in green
    if (line.len >= 2) {
        if (startsWithIgnoreCase(line, "ok") or
            startsWithIgnoreCase(line, "success") or
            startsWithIgnoreCase(line, "done"))
        {
            return graphics.Color.rgb(100, 255, 100);
        }
    }
    // Commands (starting with >) in cyan
    if (line.len > 0 and line[0] == '>') {
        return graphics.Color.rgb(100, 200, 255);
    }
    return graphics.LIGHT_GRAY;
}

fn startsWithIgnoreCase(str: []const u8, prefix: []const u8) bool {
    if (str.len < prefix.len) return false;
    for (0..prefix.len) |i| {
        var a = str[i];
        var b = prefix[i];
        if (a >= 'A' and a <= 'Z') a += 32;
        if (b >= 'A' and b <= 'Z') b += 32;
        if (a != b) return false;
    }
    return true;
}

/// Handle mouse scroll wheel
pub fn handleScroll(delta: i8) void {
    // Scroll multiplier for better feel
    const scroll_lines: usize = 3;

    // QEMU/IntelliMouse: positive = scroll down, negative = scroll up
    if (delta < 0) {
        // Scroll wheel UP = see older content (increase offset)
        const amount = @as(usize, @intCast(@abs(delta))) * scroll_lines;
        scroll_offset += amount;
        // Will be clamped in draw()
    } else if (delta > 0) {
        // Scroll wheel DOWN = see newer content (decrease offset)
        const amount = @as(usize, @intCast(@abs(delta))) * scroll_lines;
        if (scroll_offset >= amount) {
            scroll_offset -= amount;
        } else {
            scroll_offset = 0;
        }
    }
}

/// Handle keyboard input
pub fn handleKey(key: u8) void {
    // Handle special keys (Page Up/Down/Arrow for scrolling)
    if (key == keyboard.KEY_PAGE_UP) {
        // Scroll up 5 lines (see older content)
        scroll_offset += 5;
        return;
    } else if (key == keyboard.KEY_PAGE_DOWN) {
        // Scroll down 5 lines (see newer content)
        if (scroll_offset >= 5) {
            scroll_offset -= 5;
        } else {
            scroll_offset = 0;
        }
        return;
    } else if (key == keyboard.KEY_UP) {
        // Navigate history (older)
        if (history_count > 0) {
            if (!browsing_history) {
                browsing_history = true;
                history_idx = history_count;
            }
            if (history_idx > 0) {
                history_idx -= 1;
                loadHistoryEntry(history_idx);
            }
        }
        return;
    } else if (key == keyboard.KEY_DOWN) {
        // Navigate history (newer)
        if (browsing_history) {
            if (history_idx < history_count - 1) {
                history_idx += 1;
                loadHistoryEntry(history_idx);
            } else {
                // Clear input when going past newest
                term_input_len = 0;
                browsing_history = false;
            }
        }
        return;
    } else if (key == keyboard.KEY_HOME) {
        // Scroll to top
        scroll_offset = 1000; // Will be clamped in draw()
        return;
    } else if (key == keyboard.KEY_END) {
        // Scroll to bottom
        scroll_offset = 0;
        return;
    }

    if (key == 8) { // Backspace
        if (term_input_len > 0) {
            term_input_len -= 1;
        }
    } else if (key == 12) { // Ctrl+L - clear screen
        term_output_len = 0;
        scroll_offset = 0;
    } else if (key == '\n' or key == '\r') { // Enter
        if (term_input_len > 0) {
            executeCommand();
            scroll_offset = 0; // Reset scroll on new command
        }
    } else if (key == '\t') { // Tab - command completion
        doTabCompletion();
    } else if (key >= 32 and key < 127) { // Printable
        if (term_input_len < 250) {
            term_input[term_input_len] = key;
            term_input_len += 1;
        }
    }
}

// Available commands for tab completion (matches cmd_executor + text shell)
const commands = [_][]const u8{
    "help",     "clear",     "ls",     "cat",      "touch",    "rm",
    "write",    "echo",      "lsfat",  "catfat",   "mkfat",    "writefat",
    "rmfat",    "mem",       "uptime", "ps",       "tasks",    "disk",
    "net",      "ifconfig",  "ping",   "arp",      "dhcp",     "nslookup",
    "ipc",      "pipe",      "run",    "programs", "beep",     "sound",
    "play",     "usb",       "lspci",  "date",     "time",     "reboot",
    "shutdown", "version",   "ver",    "about",    "crypto",   "firewall",
    "security", "macrandom", "pwd",    "whoami",   "hostname", "uname",
    "gui",      "gfxtest",   "exit",   "logs",     "http",     "tor",
    "circuit",
};

fn doTabCompletion() void {
    if (term_input_len == 0) return;

    const prefix = term_input[0..term_input_len];
    var match_count: usize = 0;
    var last_match: []const u8 = "";

    // Find matching commands
    for (commands) |cmd| {
        if (cmd.len >= prefix.len and startsWith(cmd, prefix)) {
            match_count += 1;
            last_match = cmd;
        }
    }

    if (match_count == 1) {
        // Single match - complete it
        const len = @min(last_match.len, 250);
        for (0..len) |i| {
            term_input[i] = last_match[i];
        }
        term_input_len = len;
    } else if (match_count > 1) {
        // Multiple matches - show them
        appendOutput("\n");
        for (commands) |cmd| {
            if (cmd.len >= prefix.len and startsWith(cmd, prefix)) {
                appendOutput(cmd);
                appendOutput("  ");
            }
        }
        appendOutput("\n");
    }
}

fn startsWith(str: []const u8, prefix: []const u8) bool {
    if (str.len < prefix.len) return false;
    for (0..prefix.len) |i| {
        if (str[i] != prefix[i]) return false;
    }
    return true;
}

fn addToHistory(cmd: []const u8) void {
    if (cmd.len == 0) return;

    // Don't add duplicates of last command
    if (history_count > 0) {
        const last_idx = history_count - 1;
        if (history_lens[last_idx] == cmd.len) {
            var same = true;
            for (0..cmd.len) |i| {
                if (history[last_idx][i] != cmd[i]) {
                    same = false;
                    break;
                }
            }
            if (same) return;
        }
    }

    // Shift history if full
    if (history_count >= MAX_HISTORY) {
        for (0..MAX_HISTORY - 1) |i| {
            history[i] = history[i + 1];
            history_lens[i] = history_lens[i + 1];
        }
        history_count = MAX_HISTORY - 1;
    }

    // Add new entry
    const len = @min(cmd.len, 255);
    for (0..len) |i| {
        history[history_count][i] = cmd[i];
    }
    history_lens[history_count] = len;
    history_count += 1;
}

fn loadHistoryEntry(idx: usize) void {
    if (idx >= history_count) return;
    const len = history_lens[idx];
    for (0..len) |i| {
        term_input[i] = history[idx][i];
    }
    term_input_len = len;
}

fn executeCommand() void {
    const input_cmd = term_input[0..term_input_len];

    // Add to history
    addToHistory(input_cmd);
    browsing_history = false;

    // Echo command
    appendOutput("> ");
    appendOutput(input_cmd);
    appendOutput("\n");

    // Handle aliases
    const cmd = resolveAlias(input_cmd);

    // Handle exit specially
    if (strEql(cmd, "exit") or strEql(cmd, "quit") or strEql(cmd, "q")) {
        exit_requested_flag = true;
        term_input_len = 0;
        return;
    }

    // Handle clear specially
    if (strEql(cmd, "clear") or strEql(cmd, "cls")) {
        term_output_len = 0;
        term_input_len = 0;
        return;
    }

    // Handle history clear
    if (strEql(cmd, "history") or strEql(cmd, "hist")) {
        showHistory();
        term_input_len = 0;
        return;
    }

    // Handle history -c (clear history)
    if (startsWith(cmd, "history -c") or strEql(cmd, "histclear")) {
        clearHistory();
        appendOutput("History cleared\n");
        term_input_len = 0;
        return;
    }

    // Use unified command executor with a TEMPORARY buffer
    var temp_buf: [2048]u8 = [_]u8{0} ** 2048;
    var temp_len: usize = 0;
    var buf_writer = output.BufferWriter.init(&temp_buf, &temp_len);
    const writer = buf_writer.toOutputWriter();

    if (cmd_executor.execute(cmd, writer)) {
        // Append command output to terminal
        if (temp_len > 0) {
            appendOutput(temp_buf[0..temp_len]);
        }
    } else {
        // Unknown command
        appendOutput("Unknown: ");
        appendOutput(cmd);
        appendOutput("\nType 'help' for commands\n");
    }

    term_input_len = 0;

    // Auto-scroll: if buffer too full, remove old lines
    if (term_output_len > 3500) {
        // Find first newline after 1000 chars and shift
        var cut_pos: usize = 1000;
        while (cut_pos < term_output_len and term_output[cut_pos] != '\n') {
            cut_pos += 1;
        }
        if (cut_pos < term_output_len) {
            cut_pos += 1; // Include the newline
            const remaining = term_output_len - cut_pos;
            var i: usize = 0;
            while (i < remaining) : (i += 1) {
                term_output[i] = term_output[cut_pos + i];
            }
            term_output_len = remaining;
        }
    }
}

fn appendOutput(text: []const u8) void {
    for (text) |c| {
        if (term_output_len < term_output.len - 1) {
            term_output[term_output_len] = c;
            term_output_len += 1;
        }
    }
}

fn strEql(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    for (a, b) |ca, cb| {
        if (ca != cb) return false;
    }
    return true;
}

/// Command aliases for convenience
const Alias = struct { alias: []const u8, command: []const u8 };
const aliases = [_]Alias{
    .{ .alias = "ll", .command = "ls" },
    .{ .alias = "dir", .command = "lsfat" },
    .{ .alias = "cat", .command = "catfat" },
    .{ .alias = "rm", .command = "rmfat" },
    .{ .alias = "touch", .command = "mkfat" },
    .{ .alias = "sysinfo", .command = "about" },
    .{ .alias = "info", .command = "about" },
    .{ .alias = "?", .command = "help" },
    .{ .alias = "h", .command = "help" },
    .{ .alias = "cls", .command = "clear" },
    .{ .alias = "quit", .command = "exit" },
    .{ .alias = "q", .command = "exit" },
};

fn resolveAlias(cmd: []const u8) []const u8 {
    for (aliases) |a| {
        if (strEql(cmd, a.alias)) {
            return a.command;
        }
    }
    return cmd;
}

/// Show command history
fn showHistory() void {
    if (history_count == 0) {
        appendOutput("No history\n");
        return;
    }
    appendOutput("Command history:\n");
    var i: usize = 0;
    while (i < history_count) : (i += 1) {
        // Format: "  N: command"
        appendOutput("  ");
        var num_buf: [4]u8 = undefined;
        const num_len = formatNum(i + 1, &num_buf);
        appendOutput(num_buf[0..num_len]);
        appendOutput(": ");
        appendOutput(history[i][0..history_lens[i]]);
        appendOutput("\n");
    }
}

/// Clear command history
fn clearHistory() void {
    history_count = 0;
    history_idx = 0;
    browsing_history = false;
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
    while (v > 0 and digit_count < 10) : (digit_count += 1) {
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
