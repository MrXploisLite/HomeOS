// Home OS - Window Management
// Copyright © 2025 Romy Rianata - Home OS
// Modern window styling

const graphics = @import("../drivers/graphics.zig");
const font = @import("../drivers/font.zig");
const Color = graphics.Color;

pub const TITLE_BAR_HEIGHT: i32 = 26;

pub const WindowType = enum {
    generic,
    calculator,
    notepad,
    sysinfo,
    about,
    terminal,
    filemanager,
    devmgr,
    settings,
    taskmanager,
    paint,
    clock,
    snake,
    hexview,
    colorpicker,
    logviewer,
    pingui,
    fileprops,
    sysmon,
    calendar,
    minesweeper,
    tetris,
    browser,
};

pub const Window = struct {
    x: i32,
    y: i32,
    width: u32,
    height: u32,
    title: [32]u8,
    title_len: usize,
    visible: bool,
    focused: bool,
    minimized: bool,
    maximized: bool,
    dragging: bool,
    drag_offset_x: i32,
    drag_offset_y: i32,
    win_type: WindowType,
    saved_x: i32,
    saved_y: i32,
    saved_width: u32,
    saved_height: u32,
    // Calculator state
    calc_display: [16]u8,
    calc_display_len: usize,
    calc_value: i64,
    calc_op: u8,
    calc_new_input: bool,
    // Notepad state
    notepad_text: [512]u8,
    notepad_len: usize,
    // Task Manager state
    taskmanager_tab: u8,

    pub fn init(x: i32, y: i32, w: u32, h: u32, title: []const u8) Window {
        return initWithType(x, y, w, h, title, .generic);
    }

    pub fn initWithType(x: i32, y: i32, w: u32, h: u32, title: []const u8, wtype: WindowType) Window {
        var win = Window{
            .x = x,
            .y = y,
            .width = w,
            .height = h,
            .title = undefined,
            .title_len = 0,
            .visible = true,
            .focused = false,
            .minimized = false,
            .maximized = false,
            .dragging = false,
            .drag_offset_x = 0,
            .drag_offset_y = 0,
            .win_type = wtype,
            .saved_x = x,
            .saved_y = y,
            .saved_width = w,
            .saved_height = h,
            .calc_display = undefined,
            .calc_display_len = 1,
            .calc_value = 0,
            .calc_op = 0,
            .calc_new_input = true,
            .notepad_text = undefined,
            .notepad_len = 0,
            .taskmanager_tab = 0,
        };
        win.calc_display[0] = '0';
        const len = @min(title.len, 31);
        for (0..len) |i| {
            win.title[i] = title[i];
        }
        win.title_len = len;
        return win;
    }

    pub fn getTitle(self: *const Window) []const u8 {
        return self.title[0..self.title_len];
    }

    pub fn containsPoint(self: *const Window, px: i32, py: i32) bool {
        return px >= self.x and px < self.x + @as(i32, @intCast(self.width)) and
            py >= self.y and py < self.y + @as(i32, @intCast(self.height));
    }

    pub fn titleBarContains(self: *const Window, px: i32, py: i32) bool {
        return px >= self.x and px < self.x + @as(i32, @intCast(self.width)) and
            py >= self.y and py < self.y + TITLE_BAR_HEIGHT;
    }
};

// Modern colors
const TITLE_FOCUSED = Color.rgba(40, 45, 55, 235); // Glass dark mode
const TITLE_UNFOCUSED = Color.rgba(60, 65, 75, 180);
const TITLE_TEXT = Color.rgb(255, 255, 255);
const WINDOW_BODY = Color.rgba(240, 240, 245, 240); // 94% opacity white frosted glass
const WINDOW_BORDER_FOCUSED = Color.rgba(80, 150, 255, 255); // Glowing cyan active
const WINDOW_BORDER = Color.rgba(140, 140, 145, 150);
const SHADOW_COLOR = Color.rgba(0, 0, 0, 80);

// Button colors
const BTN_CLOSE = Color.rgb(255, 95, 87);
const BTN_CLOSE_HOVER = Color.rgb(255, 59, 48);
const BTN_MAXIMIZE = Color.rgb(40, 205, 65);
const BTN_MINIMIZE = Color.rgb(255, 189, 46);
const BTN_ICON = Color.rgb(80, 80, 80);

/// Optimized window frame drawing - reduced draw calls
pub fn drawFrame(win: *const Window) void {
    const title_color = if (win.focused) TITLE_FOCUSED else TITLE_UNFOCUSED;
    const border_col = if (win.focused) WINDOW_BORDER_FOCUSED else WINDOW_BORDER;
    const body_h = win.height - @as(u32, @intCast(TITLE_BAR_HEIGHT));

    // Hyprland Shadow Blur
    if (win.x > 0 and win.y > 0) {
        graphics.fillRectAlpha(win.x - 4, win.y - 4, win.width + 16, win.height + 16, Color.rgba(0,0,0, 30));
        graphics.fillRectAlpha(win.x + 8, win.y + 8, win.width, win.height, SHADOW_COLOR);
    }

    // Window Content Body (Glass)
    graphics.fillRectAlpha(win.x, win.y + TITLE_BAR_HEIGHT, win.width, body_h, WINDOW_BODY);

    // Title bar (Rounded Top simulation through fillRect limits)
    graphics.fillRectAlpha(win.x, win.y, win.width, @intCast(TITLE_BAR_HEIGHT), title_color);

    // Border (Hyprland Neon Border)
    if (win.focused) {
        // Glowing Double Border Array
        graphics.fillRectAlpha(win.x - 2, win.y - 2, win.width + 4, 2, border_col);
        graphics.fillRectAlpha(win.x - 2, win.y + @as(i32, @intCast(win.height)), win.width + 4, 2, border_col);
        graphics.fillRectAlpha(win.x - 2, win.y - 2, 2, win.height + 4, border_col);
        graphics.fillRectAlpha(win.x + @as(i32, @intCast(win.width)), win.y - 2, 2, win.height + 4, border_col);
    } else {
        graphics.drawRect(win.x, win.y, win.width, win.height, WINDOW_BORDER);
    }

    // Title text
    font.drawString(win.x + 10, win.y + 6, win.getTitle(), TITLE_TEXT, null);

    // Control buttons (MacOS Style Apple Colors)
    const btn_y = win.y + 7;
    const close_x = win.x + @as(i32, @intCast(win.width)) - 22;
    const max_x = close_x - 20;
    const min_x = max_x - 20;

    graphics.fillCircle(close_x + 6, btn_y + 6, 6, BTN_CLOSE);
    graphics.fillCircle(max_x + 6, btn_y + 6, 6, if (win.maximized) Color.rgb(100, 200, 255) else BTN_MAXIMIZE);
    graphics.fillCircle(min_x + 6, btn_y + 6, 6, BTN_MINIMIZE);

    // Resize handle
    const rx = win.x + @as(i32, @intCast(win.width)) - 10;
    const ry = win.y + @as(i32, @intCast(win.height)) - 10;
    graphics.fillRectAlpha(rx, ry, 8, 8, Color.rgba(180, 180, 185, 100));
}

fn drawCircleButton(x: i32, y: i32, size: i32, color: Color) void {
    // Simple filled circle approximation
    graphics.fillRect(x + 2, y, @intCast(size - 4), @intCast(size), color);
    graphics.fillRect(x, y + 2, @intCast(size), @intCast(size - 4), color);
    graphics.fillRect(x + 1, y + 1, @intCast(size - 2), @intCast(size - 2), color);
}

pub fn isOnMinimizeButton(win: *const Window, px: i32, py: i32) bool {
    const btn_x = win.x + @as(i32, @intCast(win.width)) - 62;
    return px >= btn_x and px < btn_x + 14 and py >= win.y + 6 and py < win.y + 20;
}

pub fn isOnMaximizeButton(win: *const Window, px: i32, py: i32) bool {
    const btn_x = win.x + @as(i32, @intCast(win.width)) - 42;
    return px >= btn_x and px < btn_x + 14 and py >= win.y + 6 and py < win.y + 20;
}

pub fn isOnCloseButton(win: *const Window, px: i32, py: i32) bool {
    const btn_x = win.x + @as(i32, @intCast(win.width)) - 22;
    return px >= btn_x and px < btn_x + 14 and py >= win.y + 6 and py < win.y + 20;
}

pub fn toggleMaximize(win: *Window, screen_w: u32, screen_h: u32, taskbar_h: u32) void {
    if (win.maximized) {
        win.x = win.saved_x;
        win.y = win.saved_y;
        win.width = win.saved_width;
        win.height = win.saved_height;
        win.maximized = false;
    } else {
        win.saved_x = win.x;
        win.saved_y = win.y;
        win.saved_width = win.width;
        win.saved_height = win.height;
        win.x = 0;
        win.y = 0;
        win.width = screen_w;
        win.height = screen_h - taskbar_h;
        win.maximized = true;
    }
}
