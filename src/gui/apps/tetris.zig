// Home OS - Tetris Game
// Copyright © 2025 Romy Rianata - Home OS
// Classic falling blocks puzzle game

const graphics = @import("../../drivers/graphics.zig");
const font = @import("../../drivers/font.zig");
const window = @import("../window.zig");
const Window = window.Window;
const Color = graphics.Color;

// Game constants
const BOARD_WIDTH: usize = 10;
const BOARD_HEIGHT: usize = 20;
const CELL_SIZE: u32 = 12;

// Tetromino shapes (4 rotations each)
const Tetromino = struct {
    shape: [4][4][4]u8, // 4 rotations, 4x4 grid
    color: Color,
};

// I piece
const PIECE_I = Tetromino{
    .shape = .{
        .{ .{ 0, 0, 0, 0 }, .{ 1, 1, 1, 1 }, .{ 0, 0, 0, 0 }, .{ 0, 0, 0, 0 } },
        .{ .{ 0, 0, 1, 0 }, .{ 0, 0, 1, 0 }, .{ 0, 0, 1, 0 }, .{ 0, 0, 1, 0 } },
        .{ .{ 0, 0, 0, 0 }, .{ 0, 0, 0, 0 }, .{ 1, 1, 1, 1 }, .{ 0, 0, 0, 0 } },
        .{ .{ 0, 1, 0, 0 }, .{ 0, 1, 0, 0 }, .{ 0, 1, 0, 0 }, .{ 0, 1, 0, 0 } },
    },
    .color = Color.rgb(0, 255, 255), // Cyan
};

// O piece
const PIECE_O = Tetromino{
    .shape = .{
        .{ .{ 0, 1, 1, 0 }, .{ 0, 1, 1, 0 }, .{ 0, 0, 0, 0 }, .{ 0, 0, 0, 0 } }, // rot 0
        .{ .{ 0, 1, 1, 0 }, .{ 0, 1, 1, 0 }, .{ 0, 0, 0, 0 }, .{ 0, 0, 0, 0 } }, // rot 1
        .{ .{ 0, 1, 1, 0 }, .{ 0, 1, 1, 0 }, .{ 0, 0, 0, 0 }, .{ 0, 0, 0, 0 } }, // rot 2
        .{ .{ 0, 1, 1, 0 }, .{ 0, 1, 1, 0 }, .{ 0, 0, 0, 0 }, .{ 0, 0, 0, 0 } }, // rot 3
    },
    .color = Color.rgb(255, 255, 0), // Yellow
};

// T piece
const PIECE_T = Tetromino{
    .shape = .{
        .{ .{ 0, 1, 0, 0 }, .{ 1, 1, 1, 0 }, .{ 0, 0, 0, 0 }, .{ 0, 0, 0, 0 } },
        .{ .{ 0, 1, 0, 0 }, .{ 0, 1, 1, 0 }, .{ 0, 1, 0, 0 }, .{ 0, 0, 0, 0 } },
        .{ .{ 0, 0, 0, 0 }, .{ 1, 1, 1, 0 }, .{ 0, 1, 0, 0 }, .{ 0, 0, 0, 0 } },
        .{ .{ 0, 1, 0, 0 }, .{ 1, 1, 0, 0 }, .{ 0, 1, 0, 0 }, .{ 0, 0, 0, 0 } },
    },
    .color = Color.rgb(160, 0, 240), // Purple
};

// S piece
const PIECE_S = Tetromino{
    .shape = .{
        .{ .{ 0, 1, 1, 0 }, .{ 1, 1, 0, 0 }, .{ 0, 0, 0, 0 }, .{ 0, 0, 0, 0 } },
        .{ .{ 0, 1, 0, 0 }, .{ 0, 1, 1, 0 }, .{ 0, 0, 1, 0 }, .{ 0, 0, 0, 0 } },
        .{ .{ 0, 0, 0, 0 }, .{ 0, 1, 1, 0 }, .{ 1, 1, 0, 0 }, .{ 0, 0, 0, 0 } },
        .{ .{ 1, 0, 0, 0 }, .{ 1, 1, 0, 0 }, .{ 0, 1, 0, 0 }, .{ 0, 0, 0, 0 } },
    },
    .color = Color.rgb(0, 255, 0), // Green
};

// Z piece
const PIECE_Z = Tetromino{
    .shape = .{
        .{ .{ 1, 1, 0, 0 }, .{ 0, 1, 1, 0 }, .{ 0, 0, 0, 0 }, .{ 0, 0, 0, 0 } },
        .{ .{ 0, 0, 1, 0 }, .{ 0, 1, 1, 0 }, .{ 0, 1, 0, 0 }, .{ 0, 0, 0, 0 } },
        .{ .{ 0, 0, 0, 0 }, .{ 1, 1, 0, 0 }, .{ 0, 1, 1, 0 }, .{ 0, 0, 0, 0 } },
        .{ .{ 0, 1, 0, 0 }, .{ 1, 1, 0, 0 }, .{ 1, 0, 0, 0 }, .{ 0, 0, 0, 0 } },
    },
    .color = Color.rgb(255, 0, 0), // Red
};

// J piece
const PIECE_J = Tetromino{
    .shape = .{
        .{ .{ 1, 0, 0, 0 }, .{ 1, 1, 1, 0 }, .{ 0, 0, 0, 0 }, .{ 0, 0, 0, 0 } },
        .{ .{ 0, 1, 1, 0 }, .{ 0, 1, 0, 0 }, .{ 0, 1, 0, 0 }, .{ 0, 0, 0, 0 } },
        .{ .{ 0, 0, 0, 0 }, .{ 1, 1, 1, 0 }, .{ 0, 0, 1, 0 }, .{ 0, 0, 0, 0 } },
        .{ .{ 0, 1, 0, 0 }, .{ 0, 1, 0, 0 }, .{ 1, 1, 0, 0 }, .{ 0, 0, 0, 0 } },
    },
    .color = Color.rgb(0, 0, 255), // Blue
};

// L piece
const PIECE_L = Tetromino{
    .shape = .{
        .{ .{ 0, 0, 1, 0 }, .{ 1, 1, 1, 0 }, .{ 0, 0, 0, 0 }, .{ 0, 0, 0, 0 } },
        .{ .{ 0, 1, 0, 0 }, .{ 0, 1, 0, 0 }, .{ 0, 1, 1, 0 }, .{ 0, 0, 0, 0 } },
        .{ .{ 0, 0, 0, 0 }, .{ 1, 1, 1, 0 }, .{ 1, 0, 0, 0 }, .{ 0, 0, 0, 0 } },
        .{ .{ 1, 1, 0, 0 }, .{ 0, 1, 0, 0 }, .{ 0, 1, 0, 0 }, .{ 0, 0, 0, 0 } },
    },
    .color = Color.rgb(255, 165, 0), // Orange
};

const PIECES = [_]Tetromino{ PIECE_I, PIECE_O, PIECE_T, PIECE_S, PIECE_Z, PIECE_J, PIECE_L };

// Game state
var board: [BOARD_HEIGHT][BOARD_WIDTH]u8 = [_][BOARD_WIDTH]u8{[_]u8{0} ** BOARD_WIDTH} ** BOARD_HEIGHT;
var board_colors: [BOARD_HEIGHT][BOARD_WIDTH]Color = undefined;

var current_piece: usize = 0;
var current_rotation: usize = 0;
var piece_x: i32 = 3;
var piece_y: i32 = 0;

var next_piece: usize = 0;
var score: u32 = 0;
var lines_cleared: u32 = 0;
var level: u32 = 1;
var game_over: bool = false;
var paused: bool = false;

var tick_counter: u32 = 0;
var drop_speed: u32 = 30; // Ticks between drops

var rng_state: u32 = 12345;

fn random() u32 {
    rng_state ^= rng_state << 13;
    rng_state ^= rng_state >> 17;
    rng_state ^= rng_state << 5;
    return rng_state;
}

pub fn init() void {
    // Clear board
    for (&board) |*row| {
        for (row) |*cell| {
            cell.* = 0;
        }
    }
    // Initialize colors
    for (&board_colors) |*row| {
        for (row) |*cell| {
            cell.* = Color.rgb(0, 0, 0);
        }
    }

    // Seed RNG with something
    const pit = @import("../../drivers/pit.zig");
    rng_state = pit.getTicks() +| 1;

    current_piece = random() % 7;
    next_piece = random() % 7;
    current_rotation = 0;
    piece_x = 3;
    piece_y = 0;
    score = 0;
    lines_cleared = 0;
    level = 1;
    game_over = false;
    paused = false;
    drop_speed = 30;
}

fn canPlace(px: i32, py: i32, rot: usize) bool {
    const piece = &PIECES[current_piece];
    for (0..4) |row| {
        for (0..4) |col| {
            if (piece.shape[rot][row][col] != 0) {
                const bx = px + @as(i32, @intCast(col));
                const by = py + @as(i32, @intCast(row));
                if (bx < 0 or bx >= BOARD_WIDTH or by >= BOARD_HEIGHT) return false;
                if (by >= 0 and board[@intCast(by)][@intCast(bx)] != 0) return false;
            }
        }
    }
    return true;
}

fn lockPiece() void {
    const piece = &PIECES[current_piece];
    for (0..4) |row| {
        for (0..4) |col| {
            if (piece.shape[current_rotation][row][col] != 0) {
                const bx = piece_x + @as(i32, @intCast(col));
                const by = piece_y + @as(i32, @intCast(row));
                if (by >= 0 and by < BOARD_HEIGHT and bx >= 0 and bx < BOARD_WIDTH) {
                    board[@intCast(by)][@intCast(bx)] = 1;
                    board_colors[@intCast(by)][@intCast(bx)] = piece.color;
                }
            }
        }
    }
}

fn clearLines() void {
    var cleared: u32 = 0;
    var row: usize = BOARD_HEIGHT;
    while (row > 0) {
        row -= 1;
        var full = true;
        for (0..BOARD_WIDTH) |col| {
            if (board[row][col] == 0) {
                full = false;
                break;
            }
        }
        if (full) {
            // Move all rows above down
            var r = row;
            while (r > 0) : (r -= 1) {
                for (0..BOARD_WIDTH) |col| {
                    board[r][col] = board[r - 1][col];
                    board_colors[r][col] = board_colors[r - 1][col];
                }
            }
            // Clear top row
            for (0..BOARD_WIDTH) |col| {
                board[0][col] = 0;
            }
            cleared += 1;
            row += 1; // Check same row again
        }
    }

    if (cleared > 0) {
        lines_cleared += cleared;
        // Score: 100, 300, 500, 800 for 1-4 lines
        const points: u32 = switch (cleared) {
            1 => 100,
            2 => 300,
            3 => 500,
            4 => 800,
            else => 0,
        };
        score += points *| level;

        // Level up every 10 lines
        level = (lines_cleared / 10) + 1;
        if (level > 10) level = 10;
        drop_speed = 30 -| (level * 2);
        if (drop_speed < 5) drop_speed = 5;
    }
}

fn spawnPiece() void {
    current_piece = next_piece;
    next_piece = random() % 7;
    current_rotation = 0;
    piece_x = 3;
    piece_y = 0;

    if (!canPlace(piece_x, piece_y, current_rotation)) {
        game_over = true;
    }
}

pub fn update() void {
    if (game_over or paused) return;

    tick_counter += 1;
    if (tick_counter >= drop_speed) {
        tick_counter = 0;
        // Try to move down
        if (canPlace(piece_x, piece_y + 1, current_rotation)) {
            piece_y += 1;
        } else {
            lockPiece();
            clearLines();
            spawnPiece();
        }
    }
}

pub fn handleKey(key: u8) void {
    if (key == 'r' or key == 'R') {
        init();
        return;
    }
    if (key == 'p' or key == 'P') {
        paused = !paused;
        return;
    }
    if (game_over or paused) return;

    switch (key) {
        'a', 'A' => { // Left
            if (canPlace(piece_x - 1, piece_y, current_rotation)) {
                piece_x -= 1;
            }
        },
        'd', 'D' => { // Right
            if (canPlace(piece_x + 1, piece_y, current_rotation)) {
                piece_x += 1;
            }
        },
        's', 'S' => { // Soft drop
            if (canPlace(piece_x, piece_y + 1, current_rotation)) {
                piece_y += 1;
                score += 1;
            }
        },
        'w', 'W' => { // Rotate
            const new_rot = (current_rotation + 1) % 4;
            if (canPlace(piece_x, piece_y, new_rot)) {
                current_rotation = new_rot;
            }
        },
        ' ' => { // Hard drop
            while (canPlace(piece_x, piece_y + 1, current_rotation)) {
                piece_y += 1;
                score += 2;
            }
            lockPiece();
            clearLines();
            spawnPiece();
        },
        else => {},
    }
}

pub fn draw(win: *const Window, x: i32, y: i32) void {
    _ = win;

    // Draw board background
    graphics.fillRect(x, y, BOARD_WIDTH * CELL_SIZE + 2, BOARD_HEIGHT * CELL_SIZE + 2, Color.rgb(20, 20, 25));
    graphics.drawRect(x, y, BOARD_WIDTH * CELL_SIZE + 2, BOARD_HEIGHT * CELL_SIZE + 2, Color.rgb(60, 60, 65));

    // Draw placed blocks
    for (0..BOARD_HEIGHT) |row| {
        for (0..BOARD_WIDTH) |col| {
            if (board[row][col] != 0) {
                const bx = x + 1 + @as(i32, @intCast(col)) * @as(i32, CELL_SIZE);
                const by = y + 1 + @as(i32, @intCast(row)) * @as(i32, CELL_SIZE);
                graphics.fillRect(bx, by, CELL_SIZE - 1, CELL_SIZE - 1, board_colors[row][col]);
            }
        }
    }

    // Draw current piece
    if (!game_over) {
        const piece = &PIECES[current_piece];
        for (0..4) |row| {
            for (0..4) |col| {
                if (piece.shape[current_rotation][row][col] != 0) {
                    const bx = x + 1 + (piece_x + @as(i32, @intCast(col))) * @as(i32, CELL_SIZE);
                    const by = y + 1 + (piece_y + @as(i32, @intCast(row))) * @as(i32, CELL_SIZE);
                    if (by >= y) {
                        graphics.fillRect(bx, by, CELL_SIZE - 1, CELL_SIZE - 1, piece.color);
                    }
                }
            }
        }
    }

    // Side panel
    const panel_x = x + @as(i32, BOARD_WIDTH * CELL_SIZE) + 10;

    // Next piece
    font.drawString(panel_x, y, "NEXT:", graphics.WHITE, null);
    graphics.fillRect(panel_x, y + 14, 50, 50, Color.rgb(30, 30, 35));
    const next = &PIECES[next_piece];
    for (0..4) |row| {
        for (0..4) |col| {
            if (next.shape[0][row][col] != 0) {
                const nx = panel_x + 5 + @as(i32, @intCast(col)) * 10;
                const ny = y + 19 + @as(i32, @intCast(row)) * 10;
                graphics.fillRect(nx, ny, 9, 9, next.color);
            }
        }
    }

    // Score
    font.drawString(panel_x, y + 70, "SCORE:", graphics.WHITE, null);
    drawInt(panel_x, y + 84, score);

    // Lines
    font.drawString(panel_x, y + 100, "LINES:", graphics.WHITE, null);
    drawInt(panel_x, y + 114, lines_cleared);

    // Level
    font.drawString(panel_x, y + 130, "LEVEL:", graphics.WHITE, null);
    drawInt(panel_x, y + 144, level);

    // Controls
    font.drawString(panel_x, y + 170, "A/D Move", Color.rgb(150, 150, 160), null);
    font.drawString(panel_x, y + 184, "W Rotate", Color.rgb(150, 150, 160), null);
    font.drawString(panel_x, y + 198, "S Drop", Color.rgb(150, 150, 160), null);
    font.drawString(panel_x, y + 212, "SPACE Hard", Color.rgb(150, 150, 160), null);
    font.drawString(panel_x, y + 226, "P Pause", Color.rgb(150, 150, 160), null);
    font.drawString(panel_x, y + 240, "R Restart", Color.rgb(150, 150, 160), null);

    // Game over / Paused overlay
    if (game_over) {
        graphics.fillRect(x + 20, y + 100, 80, 30, Color.rgb(200, 50, 50));
        font.drawString(x + 24, y + 108, "GAME OVER", graphics.WHITE, null);
    } else if (paused) {
        graphics.fillRect(x + 30, y + 100, 60, 30, Color.rgb(50, 100, 200));
        font.drawString(x + 38, y + 108, "PAUSED", graphics.WHITE, null);
    }
}

fn drawInt(x: i32, y: i32, value: u32) void {
    var buf: [10]u8 = undefined;
    var len: usize = 0;
    var v = value;

    if (v == 0) {
        font.drawString(x, y, "0", graphics.WHITE, null);
        return;
    }

    while (v > 0 and len < 10) : (len += 1) {
        buf[9 - len] = @truncate((v % 10) + '0');
        v /= 10;
    }

    font.drawString(x, y, buf[10 - len .. 10], graphics.WHITE, null);
}
