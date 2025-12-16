// Home OS - Minesweeper Game
// Copyright © 2025 Romy Rianata - Home OS
// Classic minesweeper with 9x9 grid

const graphics = @import("../../drivers/graphics.zig");
const font = @import("../../drivers/font.zig");
const window = @import("../window.zig");
const Window = window.Window;

const TITLE_BAR_HEIGHT = window.TITLE_BAR_HEIGHT;

const GRID_W: usize = 9;
const GRID_H: usize = 9;
const MINE_COUNT: usize = 10;

// Cell states
const CELL_HIDDEN: u8 = 0;
const CELL_REVEALED: u8 = 1;
const CELL_FLAGGED: u8 = 2;

var grid: [GRID_W * GRID_H]u8 = [_]u8{0} ** (GRID_W * GRID_H); // 0-8 = adjacent mines, 9 = mine
var state: [GRID_W * GRID_H]u8 = [_]u8{CELL_HIDDEN} ** (GRID_W * GRID_H);
var game_over: bool = false;
var game_won: bool = false;
var flags_placed: usize = 0;
var cells_revealed: usize = 0;
var game_started: bool = false;

// Simple RNG
var rng_state: u32 = 54321;

fn simpleRand() u32 {
    rng_state = rng_state *% 1103515245 +% 12345;
    return (rng_state >> 16) & 0x7FFF;
}

pub fn draw(win: *const Window, x: i32, y: i32) void {
    const content_w = win.width - 8;
    const content_h = win.height - @as(u32, @intCast(TITLE_BAR_HEIGHT)) - 8;

    // Calculate cell size
    const cell_w: i32 = @intCast(@max(16, @min(24, @divTrunc(content_w - 4, GRID_W))));
    const cell_h: i32 = @intCast(@max(16, @min(24, @divTrunc(content_h - 40, GRID_H))));
    const cell_size: i32 = @min(cell_w, cell_h);

    // Header
    graphics.fillRect(x, y, content_w, 24, graphics.Color.rgb(60, 60, 65));

    // Mine counter
    font.drawString(x + 4, y + 6, "Mines:", graphics.WHITE, null);
    var mine_buf: [3]u8 = undefined;
    const remaining = if (MINE_COUNT >= flags_placed) MINE_COUNT - flags_placed else 0;
    const mine_len = formatNum(@truncate(remaining), &mine_buf);
    font.drawString(x + 52, y + 6, mine_buf[0..mine_len], graphics.RED, null);

    // Status
    const status = if (game_won) "WIN!" else if (game_over) "BOOM!" else "Play";
    const status_color = if (game_won) graphics.GREEN else if (game_over) graphics.RED else graphics.WHITE;
    font.drawString(x + @as(i32, @intCast(content_w / 2)) - 16, y + 6, status, status_color, null);

    // Grid
    const grid_x = x + 2;
    const grid_y = y + 28;

    var cy: usize = 0;
    while (cy < GRID_H) : (cy += 1) {
        var cx: usize = 0;
        while (cx < GRID_W) : (cx += 1) {
            const idx = cy * GRID_W + cx;
            const px = grid_x + @as(i32, @intCast(cx)) * cell_size;
            const py = grid_y + @as(i32, @intCast(cy)) * cell_size;

            const cell_state = state[idx];
            const cell_val = grid[idx];

            if (cell_state == CELL_HIDDEN) {
                // Hidden cell
                graphics.fillRect(px, py, @intCast(cell_size - 1), @intCast(cell_size - 1), graphics.Color.rgb(180, 180, 185));
                graphics.drawLine(px, py, px + cell_size - 2, py, graphics.WHITE);
                graphics.drawLine(px, py, px, py + cell_size - 2, graphics.WHITE);
                graphics.drawLine(px + cell_size - 2, py, px + cell_size - 2, py + cell_size - 2, graphics.Color.rgb(120, 120, 125));
                graphics.drawLine(px, py + cell_size - 2, px + cell_size - 2, py + cell_size - 2, graphics.Color.rgb(120, 120, 125));
            } else if (cell_state == CELL_FLAGGED) {
                // Flagged cell
                graphics.fillRect(px, py, @intCast(cell_size - 1), @intCast(cell_size - 1), graphics.Color.rgb(180, 180, 185));
                font.drawString(px + 4, py + 2, "F", graphics.RED, null);
            } else {
                // Revealed cell
                graphics.fillRect(px, py, @intCast(cell_size - 1), @intCast(cell_size - 1), graphics.Color.rgb(200, 200, 205));
                graphics.drawRect(px, py, @intCast(cell_size - 1), @intCast(cell_size - 1), graphics.Color.rgb(160, 160, 165));

                if (cell_val == 9) {
                    // Mine
                    graphics.fillCircle(px + @divTrunc(cell_size, 2), py + @divTrunc(cell_size, 2), 5, graphics.BLACK);
                } else if (cell_val > 0) {
                    // Number
                    var num_buf: [2]u8 = undefined;
                    num_buf[0] = '0' + cell_val;
                    num_buf[1] = 0;
                    const num_color = getNumberColor(cell_val);
                    font.drawString(px + 5, py + 2, num_buf[0..1], num_color, null);
                }
            }
        }
    }

    // Instructions
    const grid_total_h: i32 = @as(i32, @intCast(GRID_H)) * cell_size;
    if (content_h > @as(u32, @intCast(grid_y - y + grid_total_h + 20))) {
        const inst_y = grid_y + grid_total_h + 4;
        font.drawString(x + 4, inst_y, "Click:Reveal F:Flag R:Reset", graphics.GRAY, null);
    }
}

fn getNumberColor(n: u8) graphics.Color {
    return switch (n) {
        1 => graphics.BLUE,
        2 => graphics.GREEN,
        3 => graphics.RED,
        4 => graphics.Color.rgb(128, 0, 128),
        5 => graphics.Color.rgb(128, 0, 0),
        6 => graphics.CYAN,
        7 => graphics.BLACK,
        8 => graphics.GRAY,
        else => graphics.BLACK,
    };
}

pub fn handleClick(win: *const Window, mx: i32, my: i32) void {
    if (game_over or game_won) return;

    const content_x = win.x + 4;
    const content_y = win.y + TITLE_BAR_HEIGHT + 4;
    const content_w = win.width - 8;
    const content_h = win.height - @as(u32, @intCast(TITLE_BAR_HEIGHT)) - 8;

    const cell_w: i32 = @intCast(@max(16, @min(24, @divTrunc(content_w - 4, GRID_W))));
    const cell_h: i32 = @intCast(@max(16, @min(24, @divTrunc(content_h - 40, GRID_H))));
    const cell_size: i32 = @min(cell_w, cell_h);

    const grid_x = content_x + 2;
    const grid_y = content_y + 28;

    const rel_x = mx - grid_x;
    const rel_y = my - grid_y;

    if (rel_x < 0 or rel_y < 0) return;

    const cx = @as(usize, @intCast(rel_x)) / @as(usize, @intCast(cell_size));
    const cy = @as(usize, @intCast(rel_y)) / @as(usize, @intCast(cell_size));

    if (cx >= GRID_W or cy >= GRID_H) return;

    const idx = cy * GRID_W + cx;

    if (!game_started) {
        initGame(cx, cy);
        game_started = true;
    }

    if (state[idx] == CELL_HIDDEN) {
        revealCell(cx, cy);
    }
}

pub fn handleKey(key: u8) void {
    if (key == 'r' or key == 'R') {
        resetGame();
    } else if (key == 'f' or key == 'F') {
        // Toggle flag on selected cell (simplified - flags last clicked area)
        // In a real implementation, we'd track cursor position
    }
}

fn initGame(safe_x: usize, safe_y: usize) void {
    // Clear grid
    for (&grid) |*g| g.* = 0;
    for (&state) |*s| s.* = CELL_HIDDEN;

    // Place mines (avoiding safe cell)
    var placed: usize = 0;
    while (placed < MINE_COUNT) {
        const rx = simpleRand() % GRID_W;
        const ry = simpleRand() % GRID_H;
        const idx = ry * GRID_W + rx;

        // Skip if already mine or safe zone
        if (grid[idx] == 9) continue;
        if (rx == safe_x and ry == safe_y) continue;

        grid[idx] = 9;
        placed += 1;
    }

    // Calculate adjacent mine counts
    var y: usize = 0;
    while (y < GRID_H) : (y += 1) {
        var x: usize = 0;
        while (x < GRID_W) : (x += 1) {
            const idx = y * GRID_W + x;
            if (grid[idx] == 9) continue;

            var count: u8 = 0;
            var dy: i32 = -1;
            while (dy <= 1) : (dy += 1) {
                var dx: i32 = -1;
                while (dx <= 1) : (dx += 1) {
                    if (dx == 0 and dy == 0) continue;
                    const nx = @as(i32, @intCast(x)) + dx;
                    const ny = @as(i32, @intCast(y)) + dy;
                    if (nx >= 0 and nx < GRID_W and ny >= 0 and ny < GRID_H) {
                        const nidx = @as(usize, @intCast(ny)) * GRID_W + @as(usize, @intCast(nx));
                        if (grid[nidx] == 9) count += 1;
                    }
                }
            }
            grid[idx] = count;
        }
    }
}

fn revealCell(cx: usize, cy: usize) void {
    if (cx >= GRID_W or cy >= GRID_H) return;
    const idx = cy * GRID_W + cx;
    if (state[idx] != CELL_HIDDEN) return;

    state[idx] = CELL_REVEALED;
    cells_revealed += 1;

    if (grid[idx] == 9) {
        // Hit a mine!
        game_over = true;
        revealAllMines();
        return;
    }

    // Check win condition
    if (cells_revealed == GRID_W * GRID_H - MINE_COUNT) {
        game_won = true;
        return;
    }

    // Auto-reveal adjacent cells if this is a 0
    if (grid[idx] == 0) {
        var dy: i32 = -1;
        while (dy <= 1) : (dy += 1) {
            var dx: i32 = -1;
            while (dx <= 1) : (dx += 1) {
                if (dx == 0 and dy == 0) continue;
                const nx = @as(i32, @intCast(cx)) + dx;
                const ny = @as(i32, @intCast(cy)) + dy;
                if (nx >= 0 and nx < GRID_W and ny >= 0 and ny < GRID_H) {
                    revealCell(@intCast(nx), @intCast(ny));
                }
            }
        }
    }
}

fn revealAllMines() void {
    for (grid, 0..) |val, i| {
        if (val == 9) {
            state[i] = CELL_REVEALED;
        }
    }
}

fn resetGame() void {
    for (&grid) |*g| g.* = 0;
    for (&state) |*s| s.* = CELL_HIDDEN;
    game_over = false;
    game_won = false;
    flags_placed = 0;
    cells_revealed = 0;
    game_started = false;
}

fn formatNum(val: usize, buf: []u8) usize {
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
