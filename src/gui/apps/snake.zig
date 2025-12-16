// Home OS - Snake Game
// Copyright © 2025 Romy Rianata - Home OS

const graphics = @import("../../drivers/graphics.zig");
const font = @import("../../drivers/font.zig");
const window = @import("../window.zig");
const keyboard = @import("../../drivers/keyboard.zig");
const Window = window.Window;

const GRID_W: usize = 20;
const GRID_H: usize = 15;
const TITLE_BAR_HEIGHT = window.TITLE_BAR_HEIGHT;

const Direction = enum { up, down, left, right };

// Snake body (max 100 segments)
var snake_x: [100]u8 = [_]u8{10} ** 100;
var snake_y: [100]u8 = [_]u8{7} ** 100;
var snake_len: usize = 3;
var direction: Direction = .right;
var next_direction: Direction = .right;

// Food position
var food_x: u8 = 15;
var food_y: u8 = 7;

// Game state
var score: u32 = 0;
var high_score: u32 = 0;
var game_over: bool = false;
var game_paused: bool = false;
var game_tick: u32 = 0;
var speed_level: u8 = 1; // 1-5, affects move delay
var wrap_mode: bool = false; // Wrap around edges instead of dying
const BASE_DELAY: u32 = 12;

// Simple RNG for food placement
var rng_state: u32 = 12345;

fn simpleRand() u32 {
    rng_state = rng_state *% 1103515245 +% 12345;
    return (rng_state >> 16) & 0x7FFF;
}

pub fn draw(win: *const Window, x: i32, y: i32) void {
    // Calculate responsive cell size based on window with safe arithmetic
    const content_w = win.width -| 8;
    const content_h = win.height -| @as(u32, @intCast(TITLE_BAR_HEIGHT)) -| 8;

    // Fill entire content area with dark background first
    graphics.fillRect(x, y, content_w, content_h, graphics.Color.rgb(20, 30, 20));

    const cell_w: i32 = @intCast(@max(6, (content_w -| 4) / GRID_W));
    const cell_h: i32 = @intCast(@max(6, (content_h -| 24) / GRID_H)); // Leave space for score
    const cell_size: i32 = @min(cell_w, cell_h); // Keep cells square

    const grid_w: u32 = @intCast(GRID_W * @as(usize, @intCast(cell_size)));
    const grid_h: u32 = @intCast(GRID_H * @as(usize, @intCast(cell_size)));

    // Game area background
    graphics.fillRect(x, y, grid_w, grid_h, graphics.Color.rgb(20, 40, 20));
    graphics.drawRect(x, y, grid_w, grid_h, graphics.Color.rgb(60, 100, 60));

    // Draw grid lines (subtle) - skip if cells too small
    if (cell_size >= 8) {
        var gx: usize = 0;
        while (gx <= GRID_W) : (gx += 1) {
            graphics.drawLine(x + @as(i32, @intCast(gx)) * cell_size, y, x + @as(i32, @intCast(gx)) * cell_size, y + @as(i32, @intCast(grid_h)), graphics.Color.rgb(30, 50, 30));
        }
        var gy: usize = 0;
        while (gy <= GRID_H) : (gy += 1) {
            graphics.drawLine(x, y + @as(i32, @intCast(gy)) * cell_size, x + @as(i32, @intCast(grid_w)), y + @as(i32, @intCast(gy)) * cell_size, graphics.Color.rgb(30, 50, 30));
        }
    }

    // Draw food
    const fx = x + @as(i32, food_x) * cell_size + 2;
    const fy = y + @as(i32, food_y) * cell_size + 2;
    const food_size: u32 = @intCast(@max(2, cell_size - 4));
    graphics.fillRect(fx, fy, food_size, food_size, graphics.RED);

    // Draw snake
    var i: usize = 0;
    while (i < snake_len) : (i += 1) {
        const sx = x + @as(i32, snake_x[i]) * cell_size + 1;
        const sy = y + @as(i32, snake_y[i]) * cell_size + 1;
        const color = if (i == 0) graphics.Color.rgb(100, 200, 100) else graphics.GREEN;
        const snake_size: u32 = @intCast(@max(2, cell_size - 2));
        graphics.fillRect(sx, sy, snake_size, snake_size, color);
    }

    // Score and high score
    const score_y = y + @as(i32, @intCast(grid_h)) + 5;
    font.drawString(x, score_y, "Score:", graphics.WHITE, null);
    var score_buf: [8]u8 = undefined;
    const score_len = formatNum(score, &score_buf);
    font.drawString(x + 48, score_y, score_buf[0..score_len], graphics.YELLOW, null);

    // High score
    if (content_w > 160) {
        font.drawString(x + 80, score_y, "Hi:", graphics.GRAY, null);
        var hi_buf: [8]u8 = undefined;
        const hi_len = formatNum(high_score, &hi_buf);
        font.drawString(x + 104, score_y, hi_buf[0..hi_len], graphics.Color.rgb(255, 200, 100), null);
    }

    // Speed level indicator
    if (content_w > 200) {
        font.drawString(x + 140, score_y, "Spd:", graphics.GRAY, null);
        var spd_buf: [2]u8 = undefined;
        spd_buf[0] = '0' + speed_level;
        spd_buf[1] = 0;
        font.drawString(x + 172, score_y, spd_buf[0..1], graphics.CYAN, null);
    }

    // Game over message (centered in grid)
    if (game_over) {
        const msg_x = x + @as(i32, @intCast(grid_w / 2)) - 48;
        const msg_y = y + @as(i32, @intCast(grid_h / 2)) - 8;
        graphics.fillRect(msg_x - 4, msg_y - 4, 100, 32, graphics.Color.rgb(40, 40, 45));
        font.drawString(msg_x, msg_y, "GAME OVER!", graphics.RED, null);
        font.drawString(msg_x - 8, msg_y + 12, "R:Restart +/-:Speed", graphics.WHITE, null);
    } else if (game_paused) {
        const msg_x = x + @as(i32, @intCast(grid_w / 2)) - 32;
        const msg_y = y + @as(i32, @intCast(grid_h / 2)) - 4;
        graphics.fillRect(msg_x - 4, msg_y - 4, 72, 20, graphics.Color.rgb(40, 40, 45));
        font.drawString(msg_x, msg_y, "PAUSED", graphics.YELLOW, null);
    }

    // Wrap mode indicator
    if (wrap_mode) {
        font.drawString(x + 180, score_y, "W", graphics.CYAN, null);
    }

    // Controls hint (only if space)
    if (content_w > 280) {
        font.drawString(x + @as(i32, @intCast(grid_w)) - 100, score_y, "P:Pause W:Wrap", graphics.GRAY, null);
    }
}

pub fn update() void {
    if (game_over or game_paused) return;

    game_tick += 1;
    // Safe subtraction to avoid underflow
    const speed_reduction = @as(u32, speed_level) * 2;
    const move_delay = if (BASE_DELAY > speed_reduction) BASE_DELAY - speed_reduction else 2;
    if (game_tick < move_delay) return;
    game_tick = 0;

    // Apply direction change
    direction = next_direction;

    // Calculate new head position
    var new_x = snake_x[0];
    var new_y = snake_y[0];

    switch (direction) {
        .up => {
            if (new_y > 0) {
                new_y -= 1;
            } else if (wrap_mode) {
                new_y = GRID_H - 1;
            } else {
                game_over = true;
            }
        },
        .down => {
            if (new_y < GRID_H - 1) {
                new_y += 1;
            } else if (wrap_mode) {
                new_y = 0;
            } else {
                game_over = true;
            }
        },
        .left => {
            if (new_x > 0) {
                new_x -= 1;
            } else if (wrap_mode) {
                new_x = GRID_W - 1;
            } else {
                game_over = true;
            }
        },
        .right => {
            if (new_x < GRID_W - 1) {
                new_x += 1;
            } else if (wrap_mode) {
                new_x = 0;
            } else {
                game_over = true;
            }
        },
    }

    if (game_over) return;

    // Check self collision
    var i: usize = 0;
    while (i < snake_len) : (i += 1) {
        if (snake_x[i] == new_x and snake_y[i] == new_y) {
            game_over = true;
            return;
        }
    }

    // Check food collision
    const ate_food = (new_x == food_x and new_y == food_y);

    // Move snake body
    if (!ate_food) {
        i = snake_len - 1;
        while (i > 0) : (i -= 1) {
            snake_x[i] = snake_x[i - 1];
            snake_y[i] = snake_y[i - 1];
        }
    } else {
        // Grow snake
        i = snake_len;
        while (i > 0) : (i -= 1) {
            snake_x[i] = snake_x[i - 1];
            snake_y[i] = snake_y[i - 1];
        }
        if (snake_len < 99) snake_len += 1;
        // Score multiplier based on speed level
        score += 10 * @as(u32, speed_level);
        spawnFood();
    }

    snake_x[0] = new_x;
    snake_y[0] = new_y;
}

fn spawnFood() void {
    // Find empty cell
    var attempts: u32 = 0;
    while (attempts < 100) : (attempts += 1) {
        food_x = @truncate(simpleRand() % GRID_W);
        food_y = @truncate(simpleRand() % GRID_H);

        // Check not on snake
        var valid = true;
        var i: usize = 0;
        while (i < snake_len) : (i += 1) {
            if (snake_x[i] == food_x and snake_y[i] == food_y) {
                valid = false;
                break;
            }
        }
        if (valid) return;
    }
}

pub fn handleKey(key: u8) void {
    // Speed controls (work anytime)
    if (key == '+' or key == '=') {
        if (speed_level < 5) speed_level += 1;
        return;
    } else if (key == '-') {
        if (speed_level > 1) speed_level -= 1;
        return;
    }

    // Pause toggle
    if (key == 'p' or key == 'P') {
        if (!game_over) {
            game_paused = !game_paused;
        }
        return;
    }

    // Wrap mode toggle (only when paused or game over)
    if (key == 'w' or key == 'W') {
        if (game_paused or game_over) {
            wrap_mode = !wrap_mode;
            return;
        }
    }

    if (game_over) {
        if (key == 'r' or key == 'R') {
            // Update high score before reset
            if (score > high_score) high_score = score;
            resetGame();
        }
        return;
    }

    if (game_paused) return;

    // Change direction (prevent 180 degree turns)
    if ((key == 'w' or key == 'W' or key == keyboard.KEY_UP) and direction != .down) {
        next_direction = .up;
    } else if ((key == 's' or key == 'S' or key == keyboard.KEY_DOWN) and direction != .up) {
        next_direction = .down;
    } else if ((key == 'a' or key == 'A' or key == keyboard.KEY_LEFT) and direction != .right) {
        next_direction = .left;
    } else if ((key == 'd' or key == 'D' or key == keyboard.KEY_RIGHT) and direction != .left) {
        next_direction = .right;
    }
}

fn resetGame() void {
    snake_len = 3;
    snake_x[0] = 10;
    snake_y[0] = 7;
    snake_x[1] = 9;
    snake_y[1] = 7;
    snake_x[2] = 8;
    snake_y[2] = 7;
    direction = .right;
    next_direction = .right;
    score = 0;
    game_over = false;
    game_paused = false;
    game_tick = 0;
    spawnFood();
}

fn formatNum(val: u32, buf: []u8) usize {
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
