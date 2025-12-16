// Home OS - Paint App
// Copyright © 2025 Romy Rianata - Home OS

const graphics = @import("../../drivers/graphics.zig");
const font = @import("../../drivers/font.zig");
const window = @import("../window.zig");
const Window = window.Window;
const TITLE_BAR_HEIGHT = window.TITLE_BAR_HEIGHT;

// Canvas buffer (200x150 pixels)
const CANVAS_W: usize = 200;
const CANVAS_H: usize = 150;
var canvas: [CANVAS_W * CANVAS_H]u32 = [_]u32{0xFFFFFFFF} ** (CANVAS_W * CANVAS_H);

// Current drawing color
var current_color: graphics.Color = graphics.BLACK;
var brush_size: u8 = 2;

// Tool selection
const Tool = enum { brush, line, rect, eraser, fill, circle };
var current_tool: Tool = .brush;

// Line/rect start point
var tool_start_x: i32 = -1;
var tool_start_y: i32 = -1;

// Color palette
const palette = [_]graphics.Color{
    graphics.BLACK,
    graphics.WHITE,
    graphics.RED,
    graphics.GREEN,
    graphics.BLUE,
    graphics.YELLOW,
    graphics.CYAN,
    graphics.Color.rgb(255, 128, 0), // Orange
    graphics.Color.rgb(128, 0, 255), // Purple
    graphics.Color.rgb(128, 128, 128), // Gray
};

pub fn draw(win: *const Window, x: i32, y: i32) void {
    const toolbar_h: i32 = 24;
    const content_w = win.width - 8;
    const content_h = win.height - @as(u32, @intCast(TITLE_BAR_HEIGHT)) - 8;

    // Toolbar background (responsive width)
    graphics.fillRect(x, y, content_w, @intCast(toolbar_h), graphics.Color.rgb(60, 60, 65));

    // Color palette
    var px: i32 = x + 4;
    for (palette, 0..) |color, i| {
        if (px + 16 > x + @as(i32, @intCast(content_w)) - 40) break; // Don't overflow
        graphics.fillRect(px, y + 4, 16, 16, color);
        if (color.toU32() == current_color.toU32()) {
            graphics.drawRect(px - 1, y + 3, 18, 18, graphics.WHITE);
        }
        px += 18;
        _ = i;
    }

    // Tool indicator (right side)
    const tool_x = x + @as(i32, @intCast(content_w)) - 60;
    const tool_name: []const u8 = switch (current_tool) {
        .brush => "Brsh",
        .line => "Line",
        .rect => "Rect",
        .eraser => "Eras",
        .fill => "Fill",
        .circle => "Circ",
    };
    const tool_color = if (current_tool == .eraser) graphics.YELLOW else if (current_tool == .fill) graphics.CYAN else if (current_tool == .circle) graphics.Color.rgb(255, 150, 200) else graphics.WHITE;
    font.drawString(tool_x, y + 6, tool_name, tool_color, null);

    // Canvas size indicator
    font.drawString(tool_x - 50, y + 6, "200x150", graphics.GRAY, null);

    // Brush size indicator
    const brush_x = x + @as(i32, @intCast(content_w)) - 20;
    var size_buf: [2]u8 = undefined;
    size_buf[0] = '0' + brush_size;
    size_buf[1] = 0;
    font.drawString(brush_x, y + 6, size_buf[0..1], graphics.WHITE, null);

    // Canvas area (responsive to window size)
    const canvas_x = x + 2;
    const canvas_y = y + toolbar_h + 2;
    const visible_w: usize = @intCast(@min(CANVAS_W, @max(10, content_w - 4)));
    const visible_h: usize = @intCast(@min(CANVAS_H, @max(10, content_h - @as(u32, @intCast(toolbar_h)) - 24)));

    // Draw canvas border
    graphics.drawRect(canvas_x - 1, canvas_y - 1, @intCast(visible_w + 2), @intCast(visible_h + 2), graphics.DARK_GRAY);

    // Draw canvas pixels (only visible portion)
    var cy: usize = 0;
    while (cy < visible_h) : (cy += 1) {
        var cx: usize = 0;
        while (cx < visible_w) : (cx += 1) {
            const pixel = canvas[cy * CANVAS_W + cx];
            graphics.putPixel(canvas_x + @as(i32, @intCast(cx)), canvas_y + @as(i32, @intCast(cy)), graphics.Color.fromU32(pixel));
        }
    }

    // Instructions (at bottom, only if space)
    if (content_h > @as(u32, @intCast(toolbar_h)) + visible_h + 20) {
        font.drawString(x + 2, canvas_y + @as(i32, @intCast(visible_h)) + 4, "1-0:Color +/-:Size C:Clear", graphics.GRAY, null);
    }
}

pub fn handleClick(win: *const Window, mx: i32, my: i32) void {
    const content_x = win.x + 4;
    const content_y = win.y + TITLE_BAR_HEIGHT + 4;
    const content_w = win.width - 8;
    const content_h = win.height - @as(u32, @intCast(TITLE_BAR_HEIGHT)) - 8;
    const toolbar_h: i32 = 24;

    // Check palette click
    if (my >= content_y + 4 and my < content_y + 20) {
        var px: i32 = content_x + 4;
        for (palette) |color| {
            if (px + 16 > content_x + @as(i32, @intCast(content_w)) - 40) break;
            if (mx >= px and mx < px + 16) {
                current_color = color;
                return;
            }
            px += 18;
        }
    }

    // Check canvas click (responsive bounds)
    const canvas_x = content_x + 2;
    const canvas_y = content_y + toolbar_h + 2;
    const visible_w: usize = @intCast(@min(CANVAS_W, @max(10, content_w - 4)));
    const visible_h: usize = @intCast(@min(CANVAS_H, @max(10, content_h - @as(u32, @intCast(toolbar_h)) - 24)));

    if (mx >= canvas_x and mx < canvas_x + @as(i32, @intCast(visible_w)) and
        my >= canvas_y and my < canvas_y + @as(i32, @intCast(visible_h)))
    {
        const cx = mx - canvas_x;
        const cy = my - canvas_y;

        switch (current_tool) {
            .brush => {
                if (cx >= 0 and cy >= 0) {
                    drawBrush(@intCast(cx), @intCast(cy));
                }
            },
            .eraser => {
                if (cx >= 0 and cy >= 0) {
                    drawEraser(@intCast(cx), @intCast(cy));
                }
            },
            .line, .rect => {
                if (tool_start_x < 0) {
                    // First click - set start point
                    tool_start_x = cx;
                    tool_start_y = cy;
                } else {
                    // Second click - draw shape
                    if (current_tool == .line) {
                        drawLine(@intCast(tool_start_x), @intCast(tool_start_y), @intCast(cx), @intCast(cy));
                    } else {
                        drawRect(@intCast(tool_start_x), @intCast(tool_start_y), @intCast(cx), @intCast(cy));
                    }
                    tool_start_x = -1;
                    tool_start_y = -1;
                }
            },
            .fill => {
                if (cx >= 0 and cy >= 0) {
                    floodFill(@intCast(cx), @intCast(cy));
                }
            },
            .circle => {
                if (tool_start_x < 0) {
                    tool_start_x = cx;
                    tool_start_y = cy;
                } else {
                    // Calculate radius from distance
                    const dx = cx - tool_start_x;
                    const dy = cy - tool_start_y;
                    const r2 = dx * dx + dy * dy;
                    // Simple integer sqrt approximation
                    var radius: usize = 0;
                    var r: i32 = 0;
                    while (r * r < r2 and r < 100) : (r += 1) {
                        radius = @intCast(r);
                    }
                    drawCircle(@intCast(tool_start_x), @intCast(tool_start_y), radius);
                    tool_start_x = -1;
                    tool_start_y = -1;
                }
            },
        }
    }
}

fn drawBrush(cx: usize, cy: usize) void {
    const size = @as(usize, brush_size);
    const color_val = current_color.toU32();

    var dy: usize = 0;
    while (dy < size) : (dy += 1) {
        var dx: usize = 0;
        while (dx < size) : (dx += 1) {
            const px = cx + dx;
            const py = cy + dy;
            if (px < CANVAS_W and py < CANVAS_H) {
                canvas[py * CANVAS_W + px] = color_val;
            }
        }
    }
}

fn drawEraser(cx: usize, cy: usize) void {
    const size = @as(usize, brush_size) * 2; // Eraser is bigger
    const white: u32 = 0xFFFFFFFF;

    var dy: usize = 0;
    while (dy < size) : (dy += 1) {
        var dx: usize = 0;
        while (dx < size) : (dx += 1) {
            const px = cx + dx;
            const py = cy + dy;
            if (px < CANVAS_W and py < CANVAS_H) {
                canvas[py * CANVAS_W + px] = white;
            }
        }
    }
}

fn drawLine(x0: usize, y0: usize, x1: usize, y1: usize) void {
    const color_val = current_color.toU32();

    // Bresenham's line algorithm
    var x: i32 = @intCast(x0);
    var y: i32 = @intCast(y0);
    const dx: i32 = @intCast(if (x1 > x0) x1 - x0 else x0 - x1);
    const dy: i32 = @intCast(if (y1 > y0) y1 - y0 else y0 - y1);
    const sx: i32 = if (x0 < x1) 1 else -1;
    const sy: i32 = if (y0 < y1) 1 else -1;
    var err = dx - dy;

    while (true) {
        if (x >= 0 and y >= 0 and @as(usize, @intCast(x)) < CANVAS_W and @as(usize, @intCast(y)) < CANVAS_H) {
            canvas[@as(usize, @intCast(y)) * CANVAS_W + @as(usize, @intCast(x))] = color_val;
        }
        if (x == @as(i32, @intCast(x1)) and y == @as(i32, @intCast(y1))) break;
        const e2 = err * 2;
        if (e2 > -dy) {
            err -= dy;
            x += sx;
        }
        if (e2 < dx) {
            err += dx;
            y += sy;
        }
    }
}

fn drawRect(x0: usize, y0: usize, x1: usize, y1: usize) void {
    const color_val = current_color.toU32();
    const min_x = @min(x0, x1);
    const max_x = @max(x0, x1);
    const min_y = @min(y0, y1);
    const max_y = @max(y0, y1);

    // Draw rectangle outline
    var x: usize = min_x;
    while (x <= max_x and x < CANVAS_W) : (x += 1) {
        if (min_y < CANVAS_H) canvas[min_y * CANVAS_W + x] = color_val;
        if (max_y < CANVAS_H) canvas[max_y * CANVAS_W + x] = color_val;
    }
    var y: usize = min_y;
    while (y <= max_y and y < CANVAS_H) : (y += 1) {
        if (min_x < CANVAS_W) canvas[y * CANVAS_W + min_x] = color_val;
        if (max_x < CANVAS_W) canvas[y * CANVAS_W + max_x] = color_val;
    }
}

pub fn handleKey(key: u8) void {
    // Number keys for colors
    if (key >= '1' and key <= '9') {
        const idx = key - '1';
        if (idx < palette.len) {
            current_color = palette[idx];
        }
    } else if (key == '0') {
        if (9 < palette.len) {
            current_color = palette[9];
        }
    } else if (key == '+' or key == '=') {
        if (brush_size < 8) brush_size += 1;
    } else if (key == '-') {
        if (brush_size > 1) brush_size -= 1;
    } else if (key == 'c' or key == 'C') {
        // Clear canvas
        for (&canvas) |*p| {
            p.* = 0xFFFFFFFF;
        }
    } else if (key == 'b' or key == 'B') {
        current_tool = .brush;
        tool_start_x = -1;
    } else if (key == 'l' or key == 'L') {
        current_tool = .line;
        tool_start_x = -1;
    } else if (key == 'r' or key == 'R') {
        current_tool = .rect;
        tool_start_x = -1;
    } else if (key == 'e' or key == 'E') {
        current_tool = .eraser;
        tool_start_x = -1;
    } else if (key == 'f' or key == 'F') {
        current_tool = .fill;
        tool_start_x = -1;
    } else if (key == 'o' or key == 'O') {
        current_tool = .circle;
        tool_start_x = -1;
    }
}

pub fn handleDrag(win: *const Window, mx: i32, my: i32) void {
    handleClick(win, mx, my);
}

// Flood fill using stack-based approach (non-recursive to avoid stack overflow)
fn floodFill(start_x: usize, start_y: usize) void {
    if (start_x >= CANVAS_W or start_y >= CANVAS_H) return;

    const target_color = canvas[start_y * CANVAS_W + start_x];
    const fill_color = current_color.toU32();

    // Don't fill if same color
    if (target_color == fill_color) return;

    // Simple stack for flood fill (limited size for safety)
    var stack_x: [1024]u16 = undefined;
    var stack_y: [1024]u16 = undefined;
    var stack_ptr: usize = 0;

    // Push start point
    stack_x[stack_ptr] = @truncate(start_x);
    stack_y[stack_ptr] = @truncate(start_y);
    stack_ptr += 1;

    var pixels_filled: usize = 0;
    const max_pixels: usize = 5000; // Limit to prevent infinite loops

    while (stack_ptr > 0 and pixels_filled < max_pixels) {
        stack_ptr -= 1;
        const x = stack_x[stack_ptr];
        const y = stack_y[stack_ptr];

        if (x >= CANVAS_W or y >= CANVAS_H) continue;

        const idx = @as(usize, y) * CANVAS_W + @as(usize, x);
        if (canvas[idx] != target_color) continue;

        // Fill this pixel
        canvas[idx] = fill_color;
        pixels_filled += 1;

        // Push neighbors (4-connected)
        if (stack_ptr < 1020) {
            if (x > 0) {
                stack_x[stack_ptr] = x - 1;
                stack_y[stack_ptr] = y;
                stack_ptr += 1;
            }
            if (x < CANVAS_W - 1) {
                stack_x[stack_ptr] = x + 1;
                stack_y[stack_ptr] = y;
                stack_ptr += 1;
            }
            if (y > 0) {
                stack_x[stack_ptr] = x;
                stack_y[stack_ptr] = y - 1;
                stack_ptr += 1;
            }
            if (y < CANVAS_H - 1) {
                stack_x[stack_ptr] = x;
                stack_y[stack_ptr] = y + 1;
                stack_ptr += 1;
            }
        }
    }
}

// Draw circle using midpoint algorithm
fn drawCircle(cx: usize, cy: usize, radius: usize) void {
    if (radius == 0) return;
    const color_val = current_color.toU32();

    var x: i32 = @intCast(radius);
    var y: i32 = 0;
    var err: i32 = 0;

    while (x >= y) {
        // Draw 8 octants
        setPixelSafe(cx, cy, x, y, color_val);
        setPixelSafe(cx, cy, y, x, color_val);
        setPixelSafe(cx, cy, -y, x, color_val);
        setPixelSafe(cx, cy, -x, y, color_val);
        setPixelSafe(cx, cy, -x, -y, color_val);
        setPixelSafe(cx, cy, -y, -x, color_val);
        setPixelSafe(cx, cy, y, -x, color_val);
        setPixelSafe(cx, cy, x, -y, color_val);

        y += 1;
        err += 1 + 2 * y;
        if (2 * (err - x) + 1 > 0) {
            x -= 1;
            err += 1 - 2 * x;
        }
    }
}

fn setPixelSafe(cx: usize, cy: usize, dx: i32, dy: i32, color: u32) void {
    const px = @as(i32, @intCast(cx)) + dx;
    const py = @as(i32, @intCast(cy)) + dy;
    if (px >= 0 and py >= 0 and px < CANVAS_W and py < CANVAS_H) {
        canvas[@as(usize, @intCast(py)) * CANVAS_W + @as(usize, @intCast(px))] = color;
    }
}
