// Home OS - Calculator App
// Copyright © 2025 Romy Rianata - Home OS
// Modern calculator with decimal support

const graphics = @import("../../drivers/graphics.zig");
const font = @import("../../drivers/font.zig");
const window = @import("../window.zig");
const Window = window.Window;
const TITLE_BAR_HEIGHT = window.TITLE_BAR_HEIGHT;

// Modern color scheme
const Color = graphics.Color;
const DISPLAY_BG = Color.rgb(32, 32, 32);
const DISPLAY_TEXT = Color.rgb(255, 255, 255);
const BTN_NUMBER = Color.rgb(68, 68, 68);
const BTN_OP = Color.rgb(255, 159, 10);
const BTN_FUNC = Color.rgb(142, 142, 147);
const BTN_EQUAL = Color.rgb(48, 209, 88);
const BTN_TEXT = Color.rgb(255, 255, 255);
const BTN_TEXT_DARK = Color.rgb(0, 0, 0);
const BTN_BORDER = Color.rgb(48, 48, 48);
const CALC_BG = Color.rgb(22, 22, 24);

// Button layout: 4 columns x 6 rows (added memory row)
const BUTTONS = [_][]const u8{
    "MC", "MR", "M-", "M+",
    "C",  "DE", "%",  "/",
    "7",  "8",  "9",  "*",
    "4",  "5",  "6",  "-",
    "1",  "2",  "3",  "+",
    "+-", "0",  ".",  "=",
};

const BTN_W: i32 = 38;
const BTN_H: i32 = 26;
const BTN_GAP: i32 = 3;
const DISPLAY_H: i32 = 40;
const PADDING: i32 = 6;
const BTN_MEM = Color.rgb(88, 86, 214); // Purple for memory buttons

/// Draw calculator content
pub fn draw(win: *const Window, x: i32, y: i32) void {
    // Calculate responsive dimensions with safe arithmetic
    const content_w = win.width -| 8;
    const content_h = win.height -| @as(u32, @intCast(TITLE_BAR_HEIGHT)) -| 8;

    // Calculate button sizes based on available space (safe subtraction)
    const padding2: u32 = 2 * @as(u32, @intCast(PADDING));
    const avail_w: i32 = @intCast(content_w -| padding2);
    const display_overhead: u32 = @as(u32, @intCast(DISPLAY_H + 8 + 2 * PADDING));
    const avail_h: i32 = @intCast(content_h -| display_overhead);
    const a_w = @max(0, avail_w -| 3 * BTN_GAP);
    const btn_w: i32 = @max(24, @divTrunc(a_w, 4));
    const a_h = @max(0, avail_h -| 5 * BTN_GAP);
    const btn_h: i32 = @max(18, @divTrunc(a_h, 6));

    const total_w: i32 = 4 * btn_w + 3 * BTN_GAP + 2 * PADDING;

    // Background
    graphics.fillRect(x - 2, y - 2, @intCast(total_w + 4), content_h, CALC_BG);

    // Display area (responsive width)
    const display_w: u32 = @intCast(@max(60, total_w - 2 * PADDING));
    graphics.fillRect(x + PADDING, y + PADDING, display_w, @intCast(DISPLAY_H), DISPLAY_BG);
    graphics.drawRect(x + PADDING, y + PADDING, display_w, @intCast(DISPLAY_H), BTN_BORDER);

    // Memory indicator (small "M" if memory has value)
    if (calc_memory != 0) {
        font.drawString(x + PADDING + 4, y + PADDING + 4, "M", Color.rgb(100, 200, 255), null);
    }

    // Display text (right-aligned, vertically centered, with clipping)
    const display_str = win.calc_display[0..win.calc_display_len];
    const d_w = @as(i32, @intCast(display_w)) - 16;
    const max_display_chars: usize = @intCast(@max(4, @divTrunc(d_w, 8)));
    const visible_len = @min(win.calc_display_len, max_display_chars);
    const start_idx = if (win.calc_display_len > max_display_chars) win.calc_display_len - max_display_chars else 0;
    const visible_str = display_str[start_idx..];
    const text_width = @as(i32, @intCast(visible_len * 8));
    const text_x = x + total_w - PADDING - 8 - text_width;
    const text_y = y + PADDING + @divTrunc(DISPLAY_H - 8, 2);
    font.drawString(text_x, text_y, visible_str, DISPLAY_TEXT, null);

    // Draw buttons (6 rows now)
    var btn_y = y + PADDING + DISPLAY_H + 8;
    var row: usize = 0;
    while (row < 6) : (row += 1) {
        var col: usize = 0;
        while (col < 4) : (col += 1) {
            const btn_idx = row * 4 + col;
            const btn_x = x + PADDING + @as(i32, @intCast(col)) * (btn_w + BTN_GAP);
            const label = BUTTONS[btn_idx];

            // Determine button color
            var bg_color: Color = BTN_NUMBER;
            var text_color: Color = BTN_TEXT;

            if (row == 0) {
                // Memory row - purple
                bg_color = BTN_MEM;
            } else if (row == 1) {
                // Function row
                if (col < 3) {
                    bg_color = BTN_FUNC;
                    text_color = BTN_TEXT_DARK;
                } else {
                    bg_color = BTN_OP;
                }
            } else if (col == 3) {
                bg_color = BTN_OP;
                if (row == 5) bg_color = BTN_EQUAL;
            }

            // Draw button with slight 3D effect
            graphics.fillRect(btn_x, btn_y, @intCast(btn_w), @intCast(btn_h), bg_color);
            // Top highlight
            graphics.drawLine(btn_x, btn_y, btn_x + btn_w - 1, btn_y, Color.rgb(255, 255, 255));
            // Bottom shadow
            graphics.drawLine(btn_x, btn_y + btn_h - 1, btn_x + btn_w - 1, btn_y + btn_h - 1, BTN_BORDER);

            // Center text properly
            const label_len = @as(i32, @intCast(label.len));
            const label_x = btn_x + @divTrunc(btn_w - label_len * 8, 2);
            const label_y = btn_y + @divTrunc(btn_h - 8, 2);
            font.drawString(label_x, label_y, label, text_color, null);
        }
        btn_y += btn_h + BTN_GAP;
    }
}

// Calculator memory storage
var calc_memory: i64 = 0;

// Calculator history
const MAX_HISTORY: usize = 4;
var calc_history: [MAX_HISTORY][16]u8 = [_][16]u8{[_]u8{' '} ** 16} ** MAX_HISTORY;
var calc_history_lens: [MAX_HISTORY]usize = [_]usize{0} ** MAX_HISTORY;
var history_count: usize = 0;

fn addToHistory(display: []const u8) void {
    if (display.len == 0) return;
    // Shift history
    var i: usize = MAX_HISTORY - 1;
    while (i > 0) : (i -= 1) {
        calc_history[i] = calc_history[i - 1];
        calc_history_lens[i] = calc_history_lens[i - 1];
    }
    // Add new entry
    const len = @min(display.len, 16);
    for (0..len) |j| {
        calc_history[0][j] = display[j];
    }
    calc_history_lens[0] = len;
    if (history_count < MAX_HISTORY) history_count += 1;
}

/// Handle mouse click on calculator
pub fn handleClick(win: *Window, mx: i32, my: i32) void {
    const content_x = win.x + 4;
    const content_y = win.y + TITLE_BAR_HEIGHT + 4;
    const content_w = win.width -| 8;
    const content_h = win.height -| @as(u32, @intCast(TITLE_BAR_HEIGHT)) -| 8;

    // Calculate button sizes (same as draw) with safe arithmetic
    const padding2: u32 = 2 * @as(u32, @intCast(PADDING));
    const avail_w: i32 = @intCast(content_w -| padding2);
    const display_overhead: u32 = @as(u32, @intCast(DISPLAY_H + 8 + 2 * PADDING));
    const avail_h: i32 = @intCast(content_h -| display_overhead);
    const a_w = @max(0, avail_w -| 3 * BTN_GAP);
    const btn_w: i32 = @max(24, @divTrunc(a_w, 4));
    const a_h = @max(0, avail_h -| 5 * BTN_GAP);
    const btn_h: i32 = @max(18, @divTrunc(a_h, 6));

    const btn_start_y = content_y + PADDING + DISPLAY_H + 8;

    if (my < btn_start_y) return;

    const rel_x = mx - content_x - PADDING;
    const rel_y = my - btn_start_y;

    if (rel_x < 0 or rel_y < 0) return;

    const col = @as(usize, @intCast(rel_x)) / @as(usize, @intCast(btn_w + BTN_GAP));
    const row = @as(usize, @intCast(rel_y)) / @as(usize, @intCast(btn_h + BTN_GAP));

    if (col >= 4 or row >= 6) return;

    const btn_idx = row * 4 + col;
    if (btn_idx >= BUTTONS.len) return;

    processButtonLabel(win, BUTTONS[btn_idx]);
}

/// Handle keyboard input
pub fn handleKey(win: *Window, key: u8) void {
    if (key >= '0' and key <= '9') {
        addDigit(win, key);
    } else if (key == '+' or key == '-' or key == '*' or key == '/') {
        setOperator(win, key);
    } else if (key == '%') {
        doPercent(win);
    } else if (key == '=' or key == '\n' or key == '\r') {
        doEquals(win);
    } else if (key == 'c' or key == 'C' or key == 27) {
        doClear(win);
    } else if (key == '.') {
        addDecimal(win);
    } else if (key == 8) {
        doBackspace(win);
    } else if (key == 'r' or key == 'R') {
        // Memory Recall
        formatResultFloat(win, calc_memory);
        win.calc_new_input = true;
    } else if (key == 'p' or key == 'P') {
        // Memory Add (Plus)
        calc_memory += parseDisplayFloat(win);
    } else if (key == 'm' or key == 'M') {
        // Memory Subtract (Minus)
        calc_memory -= parseDisplayFloat(win);
    } else if (key == 'l' or key == 'L') {
        // Memory Clear (cLear)
        calc_memory = 0;
    } else if (key == 'q' or key == 'Q') {
        // Square root
        doSqrt(win);
    } else if (key == '^') {
        // Power (x^2)
        doPower(win);
    } else if (key == 'i' or key == 'I') {
        // Inverse (1/x)
        doInverse(win);
    }
}

fn processButtonLabel(win: *Window, label: []const u8) void {
    if (label.len == 1) {
        const c = label[0];
        if (c >= '0' and c <= '9') {
            addDigit(win, c);
        } else if (c == '+' or c == '-' or c == '*' or c == '/') {
            setOperator(win, c);
        } else if (c == '=') {
            doEquals(win);
        } else if (c == 'C') {
            doClear(win);
        } else if (c == '.') {
            addDecimal(win);
        } else if (c == '%') {
            doPercent(win);
        }
    } else if (eql(label, "DE")) {
        doBackspace(win);
    } else if (eql(label, "+-")) {
        toggleSign(win);
    } else if (eql(label, "MC")) {
        calc_memory = 0;
    } else if (eql(label, "MR")) {
        // Memory Recall - display memory value
        formatResultFloat(win, calc_memory);
        win.calc_new_input = true;
    } else if (eql(label, "M+")) {
        // Memory Add
        calc_memory += parseDisplayFloat(win);
    } else if (eql(label, "M-")) {
        // Memory Subtract
        calc_memory -= parseDisplayFloat(win);
    }
}

fn addDigit(win: *Window, digit: u8) void {
    if (win.calc_new_input) {
        win.calc_display[0] = digit;
        win.calc_display_len = 1;
        win.calc_new_input = false;
    } else if (win.calc_display_len < 12) {
        if (win.calc_display_len == 1 and win.calc_display[0] == '0' and digit != '0') {
            win.calc_display[0] = digit;
        } else if (!(win.calc_display_len == 1 and win.calc_display[0] == '0' and digit == '0')) {
            win.calc_display[win.calc_display_len] = digit;
            win.calc_display_len += 1;
        }
    }
}

fn addDecimal(win: *Window) void {
    var i: usize = 0;
    while (i < win.calc_display_len) : (i += 1) {
        if (win.calc_display[i] == '.') return;
    }

    if (win.calc_new_input) {
        win.calc_display[0] = '0';
        win.calc_display[1] = '.';
        win.calc_display_len = 2;
        win.calc_new_input = false;
    } else if (win.calc_display_len < 12) {
        win.calc_display[win.calc_display_len] = '.';
        win.calc_display_len += 1;
    }
}

fn setOperator(win: *Window, op: u8) void {
    if (win.calc_op != 0 and !win.calc_new_input) {
        doEquals(win);
    }
    win.calc_value = parseDisplayFloat(win);
    win.calc_op = op;
    win.calc_new_input = true;
}

fn doEquals(win: *Window) void {
    const current = parseDisplayFloat(win);
    var result: i64 = 0;
    const scale: i64 = 10000;
    const val_scaled = win.calc_value;
    const cur_scaled = current;

    switch (win.calc_op) {
        '+' => result = val_scaled + cur_scaled,
        '-' => result = val_scaled - cur_scaled,
        '*' => result = @divTrunc(val_scaled * cur_scaled, scale),
        '/' => {
            if (cur_scaled != 0) {
                result = @divTrunc(val_scaled * scale, cur_scaled);
            } else {
                win.calc_display[0] = 'E';
                win.calc_display[1] = 'r';
                win.calc_display[2] = 'r';
                win.calc_display_len = 3;
                win.calc_value = 0;
                win.calc_op = 0;
                win.calc_new_input = true;
                return;
            }
        },
        else => result = current,
    }

    // Add to history before updating display
    addToHistory(win.calc_display[0..win.calc_display_len]);

    formatResultFloat(win, result);
    win.calc_value = result;
    win.calc_op = 0;
    win.calc_new_input = true;
}

/// Square root (integer approximation)
fn doSqrt(win: *Window) void {
    const val = parseDisplayFloat(win);
    if (val < 0) {
        win.calc_display[0] = 'E';
        win.calc_display[1] = 'r';
        win.calc_display[2] = 'r';
        win.calc_display_len = 3;
        return;
    }
    // Newton's method for sqrt (scaled)
    const scale: i64 = 10000;
    const x = val;
    if (x == 0) {
        formatResultFloat(win, 0);
        return;
    }
    // Initial guess
    var guess: i64 = x;
    var i: usize = 0;
    while (i < 20) : (i += 1) {
        _ = guess != 0;
        const new_guess = @divTrunc(guess + @divTrunc(x * scale, guess), 2);
        if (new_guess == guess) break;
        guess = new_guess;
    }
    formatResultFloat(win, guess);
    win.calc_new_input = true;
}

/// Power (x^2)
fn doPower(win: *Window) void {
    const val = parseDisplayFloat(win);
    const scale: i64 = 10000;
    // x^2 = (val/scale)^2 * scale = val^2 / scale
    const result = @divTrunc(val * val, scale);
    formatResultFloat(win, result);
    win.calc_new_input = true;
}

/// Inverse (1/x)
fn doInverse(win: *Window) void {
    const val = parseDisplayFloat(win);
    if (val == 0) {
        win.calc_display[0] = 'E';
        win.calc_display[1] = 'r';
        win.calc_display[2] = 'r';
        win.calc_display_len = 3;
        return;
    }
    const scale: i64 = 10000;
    // 1/x = scale^2 / val
    _ = val != 0;
    const result = @divTrunc(scale * scale, val);
    formatResultFloat(win, result);
    win.calc_new_input = true;
}

fn doClear(win: *Window) void {
    win.calc_display[0] = '0';
    win.calc_display_len = 1;
    win.calc_value = 0;
    win.calc_op = 0;
    win.calc_new_input = true;
}

fn doBackspace(win: *Window) void {
    if (win.calc_new_input) return;
    if (win.calc_display_len > 1) {
        win.calc_display_len -= 1;
    } else {
        win.calc_display[0] = '0';
        win.calc_display_len = 1;
    }
}

fn doPercent(win: *Window) void {
    const current = parseDisplayFloat(win);
    const result = @divTrunc(current, 100);
    formatResultFloat(win, result);
    win.calc_new_input = true;
}

fn toggleSign(win: *Window) void {
    if (win.calc_display_len == 1 and win.calc_display[0] == '0') return;

    if (win.calc_display[0] == '-') {
        var i: usize = 0;
        while (i < win.calc_display_len - 1) : (i += 1) {
            win.calc_display[i] = win.calc_display[i + 1];
        }
        win.calc_display_len -= 1;
    } else if (win.calc_display_len < 12) {
        var i: usize = win.calc_display_len;
        while (i > 0) : (i -= 1) {
            win.calc_display[i] = win.calc_display[i - 1];
        }
        win.calc_display[0] = '-';
        win.calc_display_len += 1;
    }
}

fn parseDisplayFloat(win: *const Window) i64 {
    var result: i64 = 0;
    var negative = false;
    var start: usize = 0;
    var decimal_pos: i32 = -1;
    const scale: i64 = 10000;

    if (win.calc_display_len > 0 and win.calc_display[0] == '-') {
        negative = true;
        start = 1;
    }

    var i: usize = start;
    while (i < win.calc_display_len) : (i += 1) {
        if (win.calc_display[i] == '.') {
            decimal_pos = @as(i32, @intCast(i));
            break;
        }
    }

    i = start;
    while (i < win.calc_display_len) : (i += 1) {
        const c = win.calc_display[i];
        if (c >= '0' and c <= '9') {
            result = result * 10 + @as(i64, c - '0');
        } else if (c == '.') {
            break;
        }
    }

    result = result * scale;

    if (decimal_pos >= 0) {
        var frac: i64 = 0;
        var frac_digits: u32 = 0;
        i = @as(usize, @intCast(decimal_pos)) + 1;
        while (i < win.calc_display_len and frac_digits < 4) : (i += 1) {
            const c = win.calc_display[i];
            if (c >= '0' and c <= '9') {
                frac = frac * 10 + @as(i64, c - '0');
                frac_digits += 1;
            }
        }
        while (frac_digits < 4) : (frac_digits += 1) {
            frac *= 10;
        }
        result += frac;
    }

    return if (negative) -result else result;
}

fn formatResultFloat(win: *Window, value: i64) void {
    const scale: i64 = 10000;
    var v = value;
    var negative = false;

    if (v < 0) {
        negative = true;
        v = -v;
    }

    const int_part = @divTrunc(v, scale);
    var frac_part = @mod(v, scale);

    var int_buf: [12]u8 = undefined;
    var int_len: usize = 0;

    if (int_part == 0) {
        int_buf[0] = '0';
        int_len = 1;
    } else {
        var ip = int_part;
        while (ip > 0 and int_len < 12) : (int_len += 1) {
            int_buf[int_len] = '0' + @as(u8, @truncate(@as(u64, @intCast(@mod(ip, 10)))));
            ip = @divTrunc(ip, 10);
        }
    }

    win.calc_display_len = 0;

    if (negative) {
        win.calc_display[win.calc_display_len] = '-';
        win.calc_display_len += 1;
    }

    var j: usize = int_len;
    while (j > 0 and win.calc_display_len < 12) {
        j -= 1;
        win.calc_display[win.calc_display_len] = int_buf[j];
        win.calc_display_len += 1;
    }

    if (frac_part > 0 and win.calc_display_len < 10) {
        win.calc_display[win.calc_display_len] = '.';
        win.calc_display_len += 1;

        var frac_buf: [4]u8 = undefined;
        var fi: usize = 4;
        while (fi > 0) : (fi -= 1) {
            frac_buf[fi - 1] = '0' + @as(u8, @truncate(@as(u64, @intCast(@mod(frac_part, 10)))));
            frac_part = @divTrunc(frac_part, 10);
        }

        var last_nonzero: usize = 0;
        fi = 0;
        while (fi < 4) : (fi += 1) {
            if (frac_buf[fi] != '0') last_nonzero = fi + 1;
        }

        fi = 0;
        while (fi < last_nonzero and win.calc_display_len < 12) : (fi += 1) {
            win.calc_display[win.calc_display_len] = frac_buf[fi];
            win.calc_display_len += 1;
        }
    }
}

fn eql(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    for (a, b) |ca, cb| {
        if (ca != cb) return false;
    }
    return true;
}
