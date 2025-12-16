// Home OS - 2D Graphics Library
// Copyright © 2025 Romy Rianata - Home OS
// Phase 14: Graphics & Display

const serial = @import("serial.zig");
const vbe = @import("vbe.zig");

// Color type (32-bit ARGB)
pub const Color = packed struct {
    b: u8,
    g: u8,
    r: u8,
    a: u8,

    pub fn rgb(r: u8, g: u8, b: u8) Color {
        return Color{ .r = r, .g = g, .b = b, .a = 255 };
    }

    pub fn rgba(r: u8, g: u8, b: u8, a: u8) Color {
        return Color{ .r = r, .g = g, .b = b, .a = a };
    }

    pub fn toU32(self: Color) u32 {
        return @bitCast(self);
    }

    pub fn fromU32(val: u32) Color {
        return @bitCast(val);
    }
};

// Predefined colors
pub const BLACK = Color.rgb(0, 0, 0);
pub const WHITE = Color.rgb(255, 255, 255);
pub const RED = Color.rgb(255, 0, 0);
pub const GREEN = Color.rgb(0, 255, 0);
pub const BLUE = Color.rgb(0, 0, 255);
pub const YELLOW = Color.rgb(255, 255, 0);
pub const CYAN = Color.rgb(0, 255, 255);
pub const MAGENTA = Color.rgb(255, 0, 255);
pub const GRAY = Color.rgb(128, 128, 128);
pub const DARK_GRAY = Color.rgb(64, 64, 64);
pub const LIGHT_GRAY = Color.rgb(192, 192, 192);

// Desktop colors
pub const DESKTOP_BG = Color.rgb(0, 120, 215); // Windows-like blue
pub const WINDOW_BG = Color.rgb(240, 240, 240);
pub const WINDOW_TITLE = Color.rgb(0, 120, 215);
pub const TASKBAR_BG = Color.rgb(30, 30, 30);

// Point structure
pub const Point = struct {
    x: i32,
    y: i32,
};

// Rectangle structure
pub const Rect = struct {
    x: i32,
    y: i32,
    width: u32,
    height: u32,

    pub fn contains(self: Rect, px: i32, py: i32) bool {
        return px >= self.x and px < self.x + @as(i32, @intCast(self.width)) and
            py >= self.y and py < self.y + @as(i32, @intCast(self.height));
    }
};

var screen_width: u32 = 0;
var screen_height: u32 = 0;
var fb_address: [*]volatile u32 = undefined;
var fb_pitch: u32 = 0;
var initialized: bool = false;

// Double buffering - static buffer for max 1920x1080x32 (supports up to Full HD)
const MAX_WIDTH: u32 = 1920;
const MAX_HEIGHT: u32 = 1080;
var back_buffer: [MAX_WIDTH * MAX_HEIGHT]u32 = [_]u32{0} ** (MAX_WIDTH * MAX_HEIGHT);
var use_double_buffer: bool = true;

// Dirty rectangle tracking for partial updates
var dirty_x1: u32 = 0;
var dirty_y1: u32 = 0;
var dirty_x2: u32 = 0;
var dirty_y2: u32 = 0;
var has_dirty: bool = false;

pub fn init() bool {
    const fb = vbe.getFramebuffer();
    if (fb == null) {
        serial.write("Graphics: No framebuffer available\n");
        return false;
    }

    screen_width = fb.?.width;
    screen_height = fb.?.height;
    fb_address = @ptrCast(@alignCast(fb.?.address));
    fb_pitch = fb.?.pitch / 4; // Convert to u32 units

    // Verify we can use double buffering
    if (screen_width <= MAX_WIDTH and screen_height <= MAX_HEIGHT) {
        use_double_buffer = true;
        serial.write("Graphics: Double buffering enabled\n");
    } else {
        use_double_buffer = false;
        serial.write("Graphics: Resolution too high for double buffer\n");
    }

    initialized = true;

    serial.write("Graphics: Initialized ");
    serial.writeInt(screen_width);
    serial.write("x");
    serial.writeInt(screen_height);
    serial.write("\n");

    return true;
}

// Mark a region as dirty (needs redraw)
fn markDirty(x: u32, y: u32, w: u32, h: u32) void {
    const x2 = if (x + w > screen_width) screen_width else x + w;
    const y2 = if (y + h > screen_height) screen_height else y + h;

    if (!has_dirty) {
        dirty_x1 = x;
        dirty_y1 = y;
        dirty_x2 = x2;
        dirty_y2 = y2;
        has_dirty = true;
    } else {
        if (x < dirty_x1) dirty_x1 = x;
        if (y < dirty_y1) dirty_y1 = y;
        if (x2 > dirty_x2) dirty_x2 = x2;
        if (y2 > dirty_y2) dirty_y2 = y2;
    }
}

// Mark entire screen dirty
pub fn markFullDirty() void {
    dirty_x1 = 0;
    dirty_y1 = 0;
    dirty_x2 = screen_width;
    dirty_y2 = screen_height;
    has_dirty = true;
}

/// Mark a specific region as dirty (for batch operations)
pub fn markDirtyRegion(x: u32, y: u32, w: u32, h: u32) void {
    markDirty(x, y, w, h);
}

// Fast memcpy using REP MOVSL (copies 4 bytes at a time)
fn fastCopy32(dest: [*]volatile u32, src: [*]const u32, count: u32) void {
    if (count == 0) return;
    asm volatile ("cld; rep movsl"
        :
        : [dest] "{edi}" (dest),
          [src] "{esi}" (src),
          [count] "{ecx}" (count),
        : .{ .edi = true, .esi = true, .ecx = true, .memory = true });
}

/// Optimized buffer swap - copy dirty region with unrolled loop
pub fn swapBuffers() void {
    if (!initialized or !use_double_buffer) return;
    if (!has_dirty) return;

    // Clamp dirty region
    if (dirty_x2 > screen_width) dirty_x2 = screen_width;
    if (dirty_y2 > screen_height) dirty_y2 = screen_height;

    const width = dirty_x2 - dirty_x1;
    if (width == 0) {
        has_dirty = false;
        return;
    }

    // If dirty region is large (>50% of screen), do full copy
    const dirty_area = width * (dirty_y2 - dirty_y1);
    const screen_area = screen_width * screen_height;
    if (dirty_area > screen_area / 2) {
        fastCopy32(fb_address, &back_buffer, screen_width * screen_height);
    } else {
        // Copy only dirty rows
        var y: u32 = dirty_y1;
        while (y < dirty_y2) : (y += 1) {
            const offset = y * screen_width + dirty_x1;
            fastCopy32(fb_address + offset, @ptrCast(&back_buffer[offset]), width);
        }
    }

    // Reset dirty region
    has_dirty = false;
}

// Swap entire buffer (for full redraws)
pub fn swapBuffersFull() void {
    if (!initialized or !use_double_buffer) return;
    fastCopy32(fb_address, &back_buffer, screen_width * screen_height);
    has_dirty = false;
}

// Get the draw target (back buffer if available, else framebuffer)
fn getDrawBuffer() [*]u32 {
    if (use_double_buffer) {
        return &back_buffer;
    }
    return @ptrCast(@volatileCast(fb_address));
}

/// Direct buffer access for optimized drawing (font, etc.)
pub fn getDrawBufferDirect() [*]u32 {
    return getDrawBuffer();
}

pub fn isInitialized() bool {
    return initialized;
}

pub fn getWidth() u32 {
    return screen_width;
}

pub fn getHeight() u32 {
    return screen_height;
}

// ============================================================================
// BASIC DRAWING PRIMITIVES
// ============================================================================

/// Put pixel without marking dirty (for batch operations)
pub fn putPixelFast(x: i32, y: i32, color: Color) void {
    if (!initialized) return;
    if (x < 0 or y < 0) return;
    const ux: u32 = @intCast(x);
    const uy: u32 = @intCast(y);
    if (ux >= screen_width or uy >= screen_height) return;

    const buffer = getDrawBuffer();
    buffer[uy * screen_width + ux] = color.toU32();
}

pub fn putPixel(x: i32, y: i32, color: Color) void {
    if (!initialized) return;
    if (x < 0 or y < 0) return;
    const ux: u32 = @intCast(x);
    const uy: u32 = @intCast(y);
    if (ux >= screen_width or uy >= screen_height) return;

    const buffer = getDrawBuffer();
    buffer[uy * screen_width + ux] = color.toU32();
    // Skip per-pixel dirty marking - use markDirtyRegion for batches
}

pub fn getPixel(x: i32, y: i32) ?Color {
    if (!initialized) return null;
    if (x < 0 or y < 0) return null;
    const ux: u32 = @intCast(x);
    const uy: u32 = @intCast(y);
    if (ux >= screen_width or uy >= screen_height) return null;

    const buffer = getDrawBuffer();
    return Color.fromU32(buffer[uy * screen_width + ux]);
}

pub fn clear(color: Color) void {
    if (!initialized) return;
    const buffer = getDrawBuffer();
    const val = color.toU32();

    // Use fast fill with REP STOSL
    const total = screen_width * screen_height;
    asm volatile ("cld; rep stosl"
        :
        : [dest] "{edi}" (buffer),
          [val] "{eax}" (val),
          [count] "{ecx}" (total),
        : .{ .edi = true, .ecx = true, .memory = true });

    markFullDirty();
}

/// Optimized fillRect with fast clipping and REP STOSL
pub fn fillRect(x: i32, y: i32, width: u32, height: u32, color: Color) void {
    if (!initialized) return;
    if (width == 0 or height == 0) return;

    // Fast clipping
    var draw_x: u32 = 0;
    var draw_y: u32 = 0;
    var draw_w: u32 = width;
    var draw_h: u32 = height;

    if (x < 0) {
        const clip: u32 = @intCast(-x);
        if (clip >= width) return;
        draw_w -= clip;
    } else {
        draw_x = @intCast(x);
    }

    if (y < 0) {
        const clip: u32 = @intCast(-y);
        if (clip >= height) return;
        draw_h -= clip;
    } else {
        draw_y = @intCast(y);
    }

    if (draw_x >= screen_width or draw_y >= screen_height) return;
    if (draw_x + draw_w > screen_width) draw_w = screen_width - draw_x;
    if (draw_y + draw_h > screen_height) draw_h = screen_height - draw_y;

    const buffer = getDrawBuffer();
    const val = color.toU32();

    // Use REP STOSL for each row (4x faster than byte operations)
    var py: u32 = 0;
    while (py < draw_h) : (py += 1) {
        const row_offset = (draw_y + py) * screen_width + draw_x;
        asm volatile ("cld; rep stosl"
            :
            : [dest] "{edi}" (@as([*]u32, @ptrCast(&buffer[row_offset]))),
              [val] "{eax}" (val),
              [count] "{ecx}" (draw_w),
            : .{ .edi = true, .ecx = true, .memory = true });
    }

    markDirty(draw_x, draw_y, draw_w, draw_h);
}

pub fn drawRect(x: i32, y: i32, width: u32, height: u32, color: Color) void {
    if (!initialized) return;
    if (width == 0 or height == 0) return;

    // Top and bottom
    drawHLine(x, y, width, color);
    drawHLine(x, y + @as(i32, @intCast(height)) - 1, width, color);

    // Left and right
    drawVLine(x, y, height, color);
    drawVLine(x + @as(i32, @intCast(width)) - 1, y, height, color);
}

pub fn drawHLine(x: i32, y: i32, length: u32, color: Color) void {
    if (!initialized) return;
    if (length == 0) return;
    if (y < 0 or y >= @as(i32, @intCast(screen_height))) return;

    var start_x: i32 = x;
    var len: u32 = length;

    if (start_x < 0) {
        if (@as(u32, @intCast(-start_x)) >= len) return;
        len -= @intCast(-start_x);
        start_x = 0;
    }

    const ux: u32 = @intCast(start_x);
    const uy: u32 = @intCast(y);

    if (ux >= screen_width) return;
    if (ux + len > screen_width) len = screen_width - ux;

    const buffer = getDrawBuffer();
    const val = color.toU32();
    const offset = uy * screen_width + ux;

    // Use REP STOSL for fast horizontal line
    asm volatile ("cld; rep stosl"
        :
        : [dest] "{edi}" (@as([*]u32, @ptrCast(&buffer[offset]))),
          [val] "{eax}" (val),
          [count] "{ecx}" (len),
        : .{ .edi = true, .ecx = true, .memory = true });

    markDirty(ux, uy, len, 1);
}

pub fn drawVLine(x: i32, y: i32, length: u32, color: Color) void {
    if (!initialized) return;
    if (length == 0) return;
    if (x < 0 or x >= @as(i32, @intCast(screen_width))) return;

    var start_y: i32 = y;
    var len: u32 = length;

    if (start_y < 0) {
        if (@as(u32, @intCast(-start_y)) >= len) return;
        len -= @intCast(-start_y);
        start_y = 0;
    }

    const ux: u32 = @intCast(x);
    const uy: u32 = @intCast(start_y);

    if (uy >= screen_height) return;
    if (uy + len > screen_height) len = screen_height - uy;

    const buffer = getDrawBuffer();
    const val = color.toU32();
    var i: u32 = 0;
    while (i < len) : (i += 1) {
        buffer[(uy + i) * screen_width + ux] = val;
    }

    markDirty(ux, uy, 1, len);
}

pub fn drawLine(x0: i32, y0: i32, x1: i32, y1: i32, color: Color) void {
    if (!initialized) return;

    // Bresenham's line algorithm
    const dx: i32 = if (x1 > x0) x1 - x0 else x0 - x1;
    const dy: i32 = if (y1 > y0) y1 - y0 else y0 - y1;
    const sx: i32 = if (x0 < x1) 1 else -1;
    const sy: i32 = if (y0 < y1) 1 else -1;
    var err: i32 = dx - dy;

    var x = x0;
    var y = y0;

    while (true) {
        putPixel(x, y, color);
        if (x == x1 and y == y1) break;

        const e2 = 2 * err;
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

pub fn drawCircle(cx: i32, cy: i32, radius: u32, color: Color) void {
    if (!initialized) return;
    if (radius == 0) return;

    // Midpoint circle algorithm
    var x: i32 = @intCast(radius);
    var y: i32 = 0;
    var err: i32 = 0;

    while (x >= y) {
        putPixel(cx + x, cy + y, color);
        putPixel(cx + y, cy + x, color);
        putPixel(cx - y, cy + x, color);
        putPixel(cx - x, cy + y, color);
        putPixel(cx - x, cy - y, color);
        putPixel(cx - y, cy - x, color);
        putPixel(cx + y, cy - x, color);
        putPixel(cx + x, cy - y, color);

        y += 1;
        err += 1 + 2 * y;
        if (2 * (err - x) + 1 > 0) {
            x -= 1;
            err += 1 - 2 * x;
        }
    }
}

pub fn fillCircle(cx: i32, cy: i32, radius: u32, color: Color) void {
    if (!initialized) return;
    if (radius == 0) return;

    var x: i32 = @intCast(radius);
    var y: i32 = 0;
    var err: i32 = 0;

    while (x >= y) {
        drawHLine(cx - x, cy + y, @intCast(2 * x + 1), color);
        drawHLine(cx - x, cy - y, @intCast(2 * x + 1), color);
        drawHLine(cx - y, cy + x, @intCast(2 * y + 1), color);
        drawHLine(cx - y, cy - x, @intCast(2 * y + 1), color);

        y += 1;
        err += 1 + 2 * y;
        if (2 * (err - x) + 1 > 0) {
            x -= 1;
            err += 1 - 2 * x;
        }
    }
}
