// Home OS - Desktop & Window Manager
// Copyright © 2025 Romy Rianata - Home OS
// Phase 14: Graphics & Display - Reorganized

const serial = @import("../drivers/serial.zig");
const graphics = @import("../drivers/graphics.zig");
const font = @import("../drivers/font.zig");
const mouse = @import("../drivers/mouse.zig");
const rtc = @import("../drivers/rtc.zig");
const Color = graphics.Color;

// GUI modules
const window = @import("window.zig");
const calculator = @import("apps/calculator.zig");
const notepad = @import("apps/notepad.zig");
const terminal = @import("apps/terminal.zig");
const sysinfo = @import("apps/sysinfo.zig");
const filemanager = @import("apps/filemanager.zig");
const devmgr = @import("apps/devmgr.zig");
const settings = @import("apps/settings.zig");
const taskmanager = @import("apps/taskmanager.zig");
const paint = @import("apps/paint.zig");
const clock = @import("apps/clock.zig");
const snake = @import("apps/snake.zig");
const hexview = @import("apps/hexview.zig");
const colorpicker = @import("apps/colorpicker.zig");
const logviewer = @import("apps/logviewer.zig");
const pingui = @import("apps/pingui.zig");
const fileprops = @import("apps/fileprops.zig");
const sysmon = @import("apps/sysmon.zig");
const calendar = @import("apps/calendar.zig");
const minesweeper = @import("apps/minesweeper.zig");
const tetris = @import("apps/tetris.zig");
const browser = @import("apps/browser.zig");
const notification = @import("notification.zig");
const screensaver = @import("screensaver.zig");
const clipboard = @import("clipboard.zig");

// Audio for click sounds
const audio = @import("../drivers/audio.zig");

pub const Window = window.Window;
pub const WindowType = window.WindowType;
const TITLE_BAR_HEIGHT = window.TITLE_BAR_HEIGHT;

const MAX_WINDOWS: usize = 16;
const TASKBAR_HEIGHT: u32 = 32;
const START_MENU_WIDTH: u32 = 150;
const START_MENU_HEIGHT: u32 = 232; // 7 items * 28 + padding

var windows: [MAX_WINDOWS]Window = undefined;
var window_count: usize = 0;
var focused_window: ?usize = null;

var screen_width: u32 = 0;
var screen_height: u32 = 0;
var initialized: bool = false;

// Start menu state
var start_menu_open: bool = false;
var exit_requested: bool = false;

// Wallpaper color (0=gradient, 1-6=solid colors)
pub var wallpaper_style: u8 = 0;

// Performance: Dirty flags to avoid unnecessary redraws
var wallpaper_dirty: bool = true;
var taskbar_dirty: bool = true;
var icons_dirty: bool = true;
var last_wallpaper_style: u8 = 255;
var last_theme: bool = false;

// Performance: Cached RTC strings (updated once per second)
var cached_date_buf: [10]u8 = undefined;
var cached_date_len: usize = 0;
var cached_time_buf: [5]u8 = undefined;
var cached_time_len: usize = 0;
var last_rtc_second: u8 = 255;

// Version constant
pub const VERSION = "0.33.0";

pub fn shouldExit() bool {
    return exit_requested or terminal.isExitRequested();
}

pub fn resetExit() void {
    exit_requested = false;
    terminal.clearExitRequest();
}

// Cursor state
var cursor_x: i32 = 0;
var cursor_y: i32 = 0;
var cursor_visible: bool = true;

// Simple arrow cursor (16x16)
const cursor_data = [16][16]u8{
    .{ 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
    .{ 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
    .{ 1, 2, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
    .{ 1, 2, 2, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
    .{ 1, 2, 2, 2, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
    .{ 1, 2, 2, 2, 2, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
    .{ 1, 2, 2, 2, 2, 2, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
    .{ 1, 2, 2, 2, 2, 2, 2, 1, 0, 0, 0, 0, 0, 0, 0, 0 },
    .{ 1, 2, 2, 2, 2, 2, 2, 2, 1, 0, 0, 0, 0, 0, 0, 0 },
    .{ 1, 2, 2, 2, 2, 2, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0 },
    .{ 1, 2, 2, 1, 2, 2, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
    .{ 1, 2, 1, 0, 1, 2, 2, 1, 0, 0, 0, 0, 0, 0, 0, 0 },
    .{ 1, 1, 0, 0, 1, 2, 2, 1, 0, 0, 0, 0, 0, 0, 0, 0 },
    .{ 1, 0, 0, 0, 0, 1, 2, 2, 1, 0, 0, 0, 0, 0, 0, 0 },
    .{ 0, 0, 0, 0, 0, 1, 2, 2, 1, 0, 0, 0, 0, 0, 0, 0 },
    .{ 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0 },
};

pub fn init() bool {
    if (!graphics.isInitialized()) {
        serial.write("Desktop: Graphics not initialized\n");
        return false;
    }

    screen_width = graphics.getWidth();
    screen_height = graphics.getHeight();
    mouse.setScreenSize(@intCast(screen_width), @intCast(screen_height));

    cursor_x = @intCast(screen_width / 2);
    cursor_y = @intCast(screen_height / 2);

    initialized = true;

    // Load and apply saved configuration
    const config = @import("config.zig");
    config.init();

    serial.write("Desktop: Initialized\n");
    return true;
}

/// Called after resolution change to update desktop and clamp windows
pub fn onResolutionChange() void {
    // Update screen dimensions
    screen_width = graphics.getWidth();
    screen_height = graphics.getHeight();

    // Update mouse bounds
    mouse.setScreenSize(@intCast(screen_width), @intCast(screen_height));

    // Clamp all windows to new screen size
    var i: usize = 0;
    while (i < window_count) : (i += 1) {
        clampWindowToScreen(&windows[i]);
    }

    serial.write("Desktop: Resolution changed to ");
    serial.writeInt(screen_width);
    serial.write("x");
    serial.writeInt(screen_height);
    serial.write("\n");
}

/// Clamp window position and size to fit within screen
fn clampWindowToScreen(win: *Window) void {
    // Safe calculation using saturating arithmetic
    const usable_height = screen_height -| TASKBAR_HEIGHT;
    const win_w = @min(win.width, screen_width);
    const win_h = @min(win.height, usable_height);
    const max_x: i32 = @as(i32, @intCast(screen_width -| win_w));
    const max_y: i32 = @as(i32, @intCast(usable_height -| win_h));

    // Clamp position
    if (win.x < 0) win.x = 0;
    if (win.y < 0) win.y = 0;
    if (max_x > 0 and win.x > max_x) win.x = max_x;
    if (max_y > 0 and win.y > max_y) win.y = max_y;

    // If window is too big, resize it
    if (screen_width > 10 and win.width > screen_width - 10) {
        win.width = screen_width - 10;
    }
    if (usable_height > 10 and win.height > usable_height - 10) {
        win.height = usable_height - 10;
    }

    // Reset maximized state if resolution changed
    if (win.maximized) {
        win.maximized = false;
    }
}

pub fn createWindow(x: i32, y: i32, width: u32, height: u32, title: []const u8) ?usize {
    return createWindowWithType(x, y, width, height, title, .generic);
}

pub fn createWindowWithType(x: i32, y: i32, width: u32, height: u32, title: []const u8, wtype: WindowType) ?usize {
    if (window_count >= MAX_WINDOWS) return null;

    windows[window_count] = Window.initWithType(x, y, width, height, title, wtype);
    const idx = window_count;
    window_count += 1;

    if (focused_window) |prev| {
        windows[prev].focused = false;
    }
    focused_window = idx;
    windows[idx].focused = true;

    serial.write("Desktop: Created window '");
    serial.write(title);
    serial.write("'\n");

    // Play window open sound
    playOpenSound();

    return idx;
}

// Theme settings
pub var dark_theme: bool = true;

pub fn drawDesktop() void {
    if (!initialized) return;

    // Check screensaver
    screensaver.update();
    if (screensaver.isActive()) {
        screensaver.draw(screen_width, screen_height);
        graphics.swapBuffers();
        return;
    }

    // Track theme/style changes
    if (wallpaper_style != last_wallpaper_style or dark_theme != last_theme) {
        last_wallpaper_style = wallpaper_style;
        last_theme = dark_theme;
    }

    // Always redraw wallpaper and icons (double buffering requires full redraw)
    drawWallpaper();
    drawDesktopIcons();

    // Always redraw windows (they can move/change)
    var i: usize = 0;
    while (i < window_count) : (i += 1) {
        if (windows[i].visible and !windows[i].minimized) {
            drawWindow(&windows[i]);
        }
    }

    drawTaskbar();

    // Draw snap preview overlay
    if (snap_preview_active and snap_preview_zone != .none) {
        drawSnapPreview();
    }

    // Draw notifications
    notification.update();
    notification.draw(screen_width);

    // Draw date popup if open
    drawDatePopup();

    drawCursor();
    graphics.swapBuffers();
}

/// Force full desktop redraw (call after resolution change, etc.)
pub fn invalidateDesktop() void {
    wallpaper_dirty = true;
    taskbar_dirty = true;
    icons_dirty = true;
}

// Solid wallpaper colors
const wallpaper_colors = [_]Color{
    Color.rgb(0, 0, 0), // Gradient (placeholder)
    Color.rgb(30, 40, 60), // Dark Blue
    Color.rgb(40, 50, 40), // Dark Green
    Color.rgb(50, 30, 50), // Dark Purple
    Color.rgb(60, 40, 30), // Dark Brown
    Color.rgb(40, 40, 40), // Dark Gray
    Color.rgb(20, 20, 30), // Near Black
};

/// Draw wallpaper (gradient or solid color)
fn drawWallpaper() void {
    const h = screen_height - TASKBAR_HEIGHT;

    // Solid color wallpapers (fast path)
    if (wallpaper_style > 0 and wallpaper_style < wallpaper_colors.len) {
        graphics.fillRect(0, 0, screen_width, h, wallpaper_colors[wallpaper_style]);
        return;
    }

    // Gradient wallpaper - use larger bands for better performance
    const band_size: u32 = 32; // Larger bands = fewer fillRect calls

    if (dark_theme) {
        // Dark theme: dark blue gradient (simplified - fewer color steps)
        var y: u32 = 0;
        while (y < h) : (y += band_size) {
            const ratio = (y * 100) / h;
            const r: u8 = @truncate(20 + (ratio * 15) / 100);
            const g: u8 = @truncate(30 + (ratio * 20) / 100);
            const b: u8 = @truncate(50 + (ratio * 30) / 100);
            const band_h = @min(band_size, h - y);
            graphics.fillRect(0, @intCast(y), screen_width, band_h, Color.rgb(r, g, b));
        }
    } else {
        // Light theme: light blue gradient
        var y: u32 = 0;
        while (y < h) : (y += band_size) {
            const ratio = (y * 100) / h;
            const r: u8 = @truncate(200 - (ratio * 50) / 100);
            const g: u8 = @truncate(220 - (ratio * 40) / 100);
            const b: u8 = @truncate(255 - (ratio * 30) / 100);
            const band_h = @min(band_size, h - y);
            graphics.fillRect(0, @intCast(y), screen_width, band_h, Color.rgb(r, g, b));
        }
    }
}

// Desktop icons
const DesktopIcon = struct {
    x: i32,
    y: i32,
    name: []const u8,
    icon_type: IconType,
};

const IconType = enum { computer, folder, file, terminal, settings, notepad, calculator, paint, clock, snake, hexview, colorpicker, logs, ping, sysmon, calendar, minesweeper, tetris, browser };

const desktop_icons = [_]DesktopIcon{
    // Left column - System
    .{ .x = 20, .y = 20, .name = "My Computer", .icon_type = .computer },
    .{ .x = 20, .y = 100, .name = "Files", .icon_type = .folder },
    .{ .x = 20, .y = 180, .name = "Terminal", .icon_type = .terminal },
    .{ .x = 20, .y = 260, .name = "Notepad", .icon_type = .notepad },
    .{ .x = 20, .y = 340, .name = "Calculator", .icon_type = .calculator },
    // Second column - Apps
    .{ .x = 100, .y = 20, .name = "Browser", .icon_type = .browser },
    .{ .x = 100, .y = 100, .name = "Paint", .icon_type = .paint },
    .{ .x = 100, .y = 180, .name = "Clock", .icon_type = .clock },
    .{ .x = 100, .y = 260, .name = "Snake", .icon_type = .snake },
    .{ .x = 100, .y = 340, .name = "Minesweeper", .icon_type = .minesweeper },
    // Third column - Tools
    .{ .x = 180, .y = 20, .name = "Sys Monitor", .icon_type = .sysmon },
    .{ .x = 180, .y = 100, .name = "Calendar", .icon_type = .calendar },
    .{ .x = 180, .y = 180, .name = "Hex View", .icon_type = .hexview },
    .{ .x = 180, .y = 260, .name = "Logs", .icon_type = .logs },
    .{ .x = 180, .y = 340, .name = "Ping", .icon_type = .ping },
    // Fourth column - Games
    .{ .x = 260, .y = 20, .name = "Tetris", .icon_type = .tetris },
    .{ .x = 260, .y = 100, .name = "Colors", .icon_type = .colorpicker },
};

/// Draw desktop icons
fn drawDesktopIcons() void {
    for (desktop_icons) |icon| {
        drawIcon(icon.x, icon.y, icon.name, icon.icon_type);
    }
}

// Selected desktop icon
var selected_icon: ?usize = null;

fn drawIcon(x: i32, y: i32, name: []const u8, icon_type: IconType) void {
    // Check if this icon is selected
    var is_selected = false;
    for (desktop_icons, 0..) |icon, idx| {
        if (icon.x == x and icon.y == y and selected_icon == idx) {
            is_selected = true;
            break;
        }
    }

    // Selection highlight
    if (is_selected) {
        graphics.fillRect(x - 2, y - 2, 52, 62, Color.rgb(80, 130, 200));
    }

    const icon_color = switch (icon_type) {
        .computer => graphics.CYAN,
        .folder => graphics.YELLOW,
        .file => graphics.WHITE,
        .terminal => graphics.DARK_GRAY,
        .settings => graphics.LIGHT_GRAY,
        .notepad => graphics.WHITE,
        .calculator => Color.rgb(100, 200, 255),
        .paint => Color.rgb(255, 100, 200),
        .clock => Color.rgb(100, 200, 200),
        .snake => Color.rgb(100, 200, 100),
        .hexview => Color.rgb(150, 100, 255),
        .colorpicker => Color.rgb(255, 150, 100),
        .logs => Color.rgb(200, 150, 100),
        .ping => Color.rgb(100, 200, 150),
        .sysmon => Color.rgb(100, 150, 255),
        .calendar => Color.rgb(255, 100, 100),
        .minesweeper => Color.rgb(180, 180, 185),
        .tetris => Color.rgb(100, 200, 255),
        .browser => Color.rgb(100, 180, 255),
    };

    graphics.fillRect(x, y, 48, 40, icon_color);
    graphics.drawRect(x, y, 48, 40, graphics.BLACK);

    switch (icon_type) {
        .computer => {
            graphics.fillRect(x + 8, y + 4, 32, 24, graphics.DARK_GRAY);
            graphics.fillRect(x + 10, y + 6, 28, 20, graphics.BLUE);
            graphics.fillRect(x + 18, y + 28, 12, 4, graphics.DARK_GRAY);
            graphics.fillRect(x + 14, y + 32, 20, 4, graphics.DARK_GRAY);
        },
        .folder => {
            graphics.fillRect(x + 4, y + 8, 40, 28, Color.rgb(200, 180, 100));
            graphics.fillRect(x + 4, y + 4, 16, 8, Color.rgb(200, 180, 100));
        },
        .terminal => {
            graphics.fillRect(x + 4, y + 4, 40, 32, graphics.BLACK);
            font.drawString(x + 8, y + 8, ">_", graphics.GREEN, null);
        },
        .file => {
            graphics.fillRect(x + 8, y + 4, 32, 32, graphics.WHITE);
            graphics.drawRect(x + 8, y + 4, 32, 32, graphics.BLACK);
        },
        .settings => {
            // Gear icon
            graphics.fillRect(x + 12, y + 8, 24, 24, graphics.DARK_GRAY);
            graphics.fillRect(x + 16, y + 12, 16, 16, graphics.LIGHT_GRAY);
            graphics.fillRect(x + 20, y + 16, 8, 8, graphics.DARK_GRAY);
        },
        .notepad => {
            // Notepad icon - paper with lines
            graphics.fillRect(x + 8, y + 4, 32, 32, graphics.WHITE);
            graphics.drawRect(x + 8, y + 4, 32, 32, graphics.DARK_GRAY);
            graphics.drawLine(x + 12, y + 12, x + 36, y + 12, graphics.LIGHT_GRAY);
            graphics.drawLine(x + 12, y + 18, x + 36, y + 18, graphics.LIGHT_GRAY);
            graphics.drawLine(x + 12, y + 24, x + 36, y + 24, graphics.LIGHT_GRAY);
        },
        .calculator => {
            // Calculator icon
            graphics.fillRect(x + 10, y + 4, 28, 32, Color.rgb(50, 50, 55));
            graphics.fillRect(x + 12, y + 6, 24, 10, Color.rgb(80, 80, 85));
            graphics.fillRect(x + 12, y + 18, 10, 6, Color.rgb(100, 100, 105));
            graphics.fillRect(x + 24, y + 18, 10, 6, Color.rgb(255, 159, 10));
            graphics.fillRect(x + 12, y + 26, 10, 6, Color.rgb(100, 100, 105));
            graphics.fillRect(x + 24, y + 26, 10, 6, Color.rgb(100, 100, 105));
        },
        .paint => {
            // Paint icon - palette
            graphics.fillRect(x + 8, y + 8, 32, 24, Color.rgb(240, 230, 200));
            graphics.fillRect(x + 12, y + 12, 6, 6, graphics.RED);
            graphics.fillRect(x + 20, y + 12, 6, 6, graphics.GREEN);
            graphics.fillRect(x + 28, y + 12, 6, 6, graphics.BLUE);
            graphics.fillRect(x + 16, y + 22, 6, 6, graphics.YELLOW);
            graphics.fillRect(x + 24, y + 22, 6, 6, graphics.CYAN);
        },
        .clock => {
            // Clock icon - circle with hands
            graphics.fillCircle(x + 24, y + 20, 16, graphics.WHITE);
            graphics.drawCircle(x + 24, y + 20, 16, graphics.DARK_GRAY);
            graphics.drawLine(x + 24, y + 20, x + 24, y + 10, graphics.BLACK);
            graphics.drawLine(x + 24, y + 20, x + 32, y + 20, graphics.BLACK);
        },
        .snake => {
            // Snake icon - green snake
            graphics.fillRect(x + 8, y + 8, 32, 24, Color.rgb(30, 50, 30));
            graphics.fillRect(x + 10, y + 16, 8, 8, graphics.GREEN);
            graphics.fillRect(x + 18, y + 16, 8, 8, graphics.GREEN);
            graphics.fillRect(x + 26, y + 16, 8, 8, Color.rgb(100, 200, 100));
            graphics.fillRect(x + 30, y + 10, 6, 6, graphics.RED);
        },
        .hexview => {
            // Hex viewer icon - binary display
            graphics.fillRect(x + 4, y + 4, 40, 32, Color.rgb(30, 30, 40));
            font.drawString(x + 8, y + 8, "0x", Color.rgb(150, 100, 255), null);
            font.drawString(x + 8, y + 20, "FF", Color.rgb(100, 200, 100), null);
        },
        .colorpicker => {
            // Color picker icon - palette
            graphics.fillRect(x + 8, y + 8, 32, 24, graphics.WHITE);
            graphics.fillRect(x + 10, y + 10, 8, 8, graphics.RED);
            graphics.fillRect(x + 20, y + 10, 8, 8, graphics.GREEN);
            graphics.fillRect(x + 30, y + 10, 8, 8, graphics.BLUE);
            graphics.fillRect(x + 15, y + 20, 8, 8, graphics.YELLOW);
            graphics.fillRect(x + 25, y + 20, 8, 8, graphics.CYAN);
        },
        .logs => {
            // Log viewer icon - list
            graphics.fillRect(x + 4, y + 4, 40, 32, Color.rgb(35, 38, 45));
            graphics.fillRect(x + 8, y + 8, 4, 4, Color.rgb(80, 200, 120));
            graphics.fillRect(x + 14, y + 8, 24, 4, Color.rgb(150, 150, 160));
            graphics.fillRect(x + 8, y + 16, 4, 4, Color.rgb(220, 180, 60));
            graphics.fillRect(x + 14, y + 16, 24, 4, Color.rgb(150, 150, 160));
            graphics.fillRect(x + 8, y + 24, 4, 4, Color.rgb(220, 80, 80));
            graphics.fillRect(x + 14, y + 24, 24, 4, Color.rgb(150, 150, 160));
        },
        .ping => {
            // Ping icon - network graph
            graphics.fillRect(x + 4, y + 4, 40, 32, Color.rgb(25, 28, 35));
            graphics.fillRect(x + 8, y + 28, 4, 4, Color.rgb(80, 200, 120));
            graphics.fillRect(x + 14, y + 22, 4, 10, Color.rgb(80, 200, 120));
            graphics.fillRect(x + 20, y + 18, 4, 14, Color.rgb(80, 200, 120));
            graphics.fillRect(x + 26, y + 24, 4, 8, Color.rgb(80, 200, 120));
            graphics.fillRect(x + 32, y + 20, 4, 12, Color.rgb(80, 200, 120));
        },
        .sysmon => {
            // System Monitor icon - CPU/graph
            graphics.fillRect(x + 4, y + 4, 40, 32, Color.rgb(30, 30, 35));
            graphics.fillRect(x + 8, y + 24, 32, 8, Color.rgb(50, 50, 55));
            graphics.fillRect(x + 8, y + 24, 20, 8, Color.rgb(100, 200, 100));
            graphics.fillRect(x + 8, y + 10, 32, 10, Color.rgb(50, 50, 55));
            graphics.fillRect(x + 8, y + 10, 24, 10, Color.rgb(100, 150, 255));
        },
        .calendar => {
            // Calendar icon
            graphics.fillRect(x + 4, y + 4, 40, 32, Color.rgb(255, 255, 255));
            graphics.fillRect(x + 4, y + 4, 40, 10, Color.rgb(200, 50, 50));
            graphics.drawRect(x + 4, y + 4, 40, 32, Color.rgb(100, 100, 105));
            font.drawString(x + 16, y + 18, "31", Color.rgb(50, 50, 55), null);
        },
        .minesweeper => {
            // Minesweeper icon - mine/grid
            graphics.fillRect(x + 4, y + 4, 40, 32, Color.rgb(180, 180, 185));
            graphics.drawRect(x + 4, y + 4, 40, 32, Color.rgb(120, 120, 125));
            graphics.fillCircle(x + 24, y + 20, 8, Color.rgb(40, 40, 45));
            graphics.fillRect(x + 22, y + 8, 4, 8, Color.rgb(40, 40, 45));
        },
        .tetris => {
            // Tetris icon - falling blocks
            graphics.fillRect(x + 4, y + 4, 40, 32, Color.rgb(20, 20, 30));
            graphics.fillRect(x + 8, y + 8, 8, 8, Color.rgb(255, 100, 100));
            graphics.fillRect(x + 16, y + 8, 8, 8, Color.rgb(255, 100, 100));
            graphics.fillRect(x + 8, y + 16, 8, 8, Color.rgb(255, 100, 100));
            graphics.fillRect(x + 24, y + 16, 8, 8, Color.rgb(100, 200, 255));
            graphics.fillRect(x + 24, y + 24, 8, 8, Color.rgb(100, 200, 255));
            graphics.fillRect(x + 32, y + 24, 8, 8, Color.rgb(100, 200, 255));
        },
        .browser => {
            // Browser icon - globe
            graphics.fillRect(x + 4, y + 4, 40, 32, Color.rgb(30, 30, 40));
            graphics.fillCircle(x + 24, y + 20, 14, Color.rgb(100, 180, 255));
            graphics.drawCircle(x + 24, y + 20, 14, Color.rgb(60, 140, 220));
            graphics.drawHLine(x + 10, y + 20, 28, Color.rgb(60, 140, 220));
            graphics.drawVLine(x + 24, y + 6, 28, Color.rgb(60, 140, 220));
        },
    }

    const name_width = font.measureString(name);
    const label_x = x + 24 - @as(i32, @intCast(name_width / 2));
    font.drawString(label_x, y + 44, name, graphics.WHITE, null);
}

fn drawWindow(win: *const Window) void {
    // Draw window frame
    window.drawFrame(win);

    // Draw content based on type
    const content_x = win.x + 4;
    const content_y = win.y + TITLE_BAR_HEIGHT + 4;

    switch (win.win_type) {
        .calculator => calculator.draw(win, content_x, content_y),
        .notepad => notepad.draw(win, content_x, content_y),
        .sysinfo => sysinfo.drawSysInfo(win, content_x, content_y),
        .about => sysinfo.drawAbout(win, content_x, content_y),
        .terminal => terminal.draw(win, content_x, content_y),
        .filemanager => filemanager.draw(win, content_x, content_y),
        .devmgr => devmgr.draw(win, content_x, content_y),
        .settings => settings.draw(win, content_x, content_y),
        .taskmanager => taskmanager.draw(win, content_x, content_y),
        .paint => paint.draw(win, content_x, content_y),
        .clock => clock.draw(win, content_x, content_y),
        .snake => {
            snake.draw(win, content_x, content_y);
            snake.update();
        },
        .hexview => hexview.draw(win, content_x, content_y),
        .colorpicker => colorpicker.draw(win, content_x, content_y),
        .logviewer => logviewer.draw(win, content_x, content_y),
        .pingui => {
            pingui.draw(win, content_x, content_y);
            pingui.update();
        },
        .fileprops => fileprops.draw(win, content_x, content_y),
        .sysmon => sysmon.draw(win, content_x, content_y),
        .calendar => calendar.draw(win, content_x, content_y),
        .minesweeper => minesweeper.draw(win, content_x, content_y),
        .tetris => {
            tetris.draw(win, content_x, content_y);
            tetris.update();
        },
        .browser => {
            browser.draw(win, content_x, content_y);
            browser.update();
        },
        .generic => drawGenericContent(content_x, content_y),
    }
}

fn drawGenericContent(x: i32, y: i32) void {
    font.drawString(x, y, "Welcome to Home OS!", graphics.BLACK, null);
    font.drawString(x, y + 16, "Click Start for apps", graphics.DARK_GRAY, null);
}

/// Draw snap preview overlay
fn drawSnapPreview() void {
    const sw = screen_width;
    const sh = screen_height - TASKBAR_HEIGHT;
    const preview_color = Color.rgba(50, 120, 200, 100);
    const border_color = Color.rgb(80, 150, 230);

    switch (snap_preview_zone) {
        .left => {
            graphics.fillRect(0, 0, sw / 2, sh, preview_color);
            graphics.drawRect(0, 0, sw / 2, sh, border_color);
        },
        .right => {
            graphics.fillRect(@intCast(sw / 2), 0, sw / 2, sh, preview_color);
            graphics.drawRect(@intCast(sw / 2), 0, sw / 2, sh, border_color);
        },
        .top => {
            graphics.fillRect(0, 0, sw, sh, preview_color);
            graphics.drawRect(0, 0, sw, sh, border_color);
        },
        .top_left => {
            graphics.fillRect(0, 0, sw / 2, sh / 2, preview_color);
            graphics.drawRect(0, 0, sw / 2, sh / 2, border_color);
        },
        .top_right => {
            graphics.fillRect(@intCast(sw / 2), 0, sw / 2, sh / 2, preview_color);
            graphics.drawRect(@intCast(sw / 2), 0, sw / 2, sh / 2, border_color);
        },
        .none => {},
    }
}

/// Show boot splash screen with animated progress bar
fn showBootSplash() void {
    const pit = @import("../drivers/pit.zig");

    // Dark background
    graphics.fillRect(0, 0, screen_width, screen_height, Color.rgb(15, 18, 25));

    // Center coordinates
    const cx = @as(i32, @intCast(screen_width / 2));
    const cy = @as(i32, @intCast(screen_height / 2));

    // Logo box with gradient effect
    graphics.fillRect(cx - 120, cy - 80, 240, 100, Color.rgb(30, 40, 55));
    graphics.drawRect(cx - 120, cy - 80, 240, 100, Color.rgb(60, 80, 120));
    graphics.drawRect(cx - 119, cy - 79, 238, 98, Color.rgb(40, 55, 80));

    // Title with shadow
    font.drawString(cx - 39, cy - 59, "HOME OS", Color.rgb(30, 30, 40), null);
    font.drawString(cx - 40, cy - 60, "HOME OS", graphics.WHITE, null);

    // Version
    font.drawString(cx - 28, cy - 35, "v" ++ VERSION, Color.rgb(100, 150, 255), null);

    // Tagline
    font.drawString(cx - 60, cy - 10, "A Hobby Operating System", Color.rgb(120, 130, 150), null);

    // Progress bar background
    const bar_w: u32 = 200;
    const bar_h: u32 = 8;
    const bar_x = cx - @as(i32, @intCast(bar_w / 2));
    const bar_y = cy + 30;
    graphics.fillRect(bar_x, bar_y, bar_w, bar_h, Color.rgb(40, 45, 55));
    graphics.drawRect(bar_x, bar_y, bar_w, bar_h, Color.rgb(60, 70, 85));

    // Copyright
    font.drawString(cx - 80, cy + 60, "Copyright 2025 Romy Rianata", Color.rgb(80, 85, 95), null);

    graphics.swapBuffers();

    // Animated progress bar
    const total_steps: u32 = 20;
    const step_width = bar_w / total_steps;
    var progress: u32 = 0;

    while (progress < total_steps) : (progress += 1) {
        // Draw progress
        const fill_w = (progress + 1) * step_width;
        graphics.fillRect(bar_x + 1, bar_y + 1, fill_w, bar_h - 2, Color.rgb(50, 140, 220));

        // Highlight effect
        graphics.fillRect(bar_x + 1, bar_y + 1, fill_w, 2, Color.rgb(100, 180, 255));

        graphics.swapBuffers();

        // Wait ~50ms per step (5 ticks at 100Hz)
        const start = pit.getTicks();
        while (pit.getTicks() - start < 5) {
            asm volatile ("hlt");
        }
    }

    // Final wait
    const final_start = pit.getTicks();
    while (pit.getTicks() - final_start < 30) {
        asm volatile ("hlt");
    }
}

/// Show shutdown screen with message
pub fn showShutdownScreen() void {
    const pit = @import("../drivers/pit.zig");

    // Dark background
    graphics.fillRect(0, 0, screen_width, screen_height, Color.rgb(10, 12, 18));

    // Center coordinates
    const cx = @as(i32, @intCast(screen_width / 2));
    const cy = @as(i32, @intCast(screen_height / 2));

    // Shutdown icon (power symbol)
    graphics.drawCircle(cx, cy - 40, 30, Color.rgb(200, 80, 80));
    graphics.drawCircle(cx, cy - 40, 28, Color.rgb(200, 80, 80));
    graphics.fillRect(cx - 2, cy - 70, 4, 20, Color.rgb(200, 80, 80));

    // Message
    font.drawString(cx - 52, cy + 10, "Shutting down...", graphics.WHITE, null);
    font.drawString(cx - 80, cy + 30, "Thank you for using Home OS", Color.rgb(120, 130, 150), null);

    // Copyright
    font.drawString(cx - 80, cy + 70, "Copyright 2025 Romy Rianata", Color.rgb(60, 65, 75), null);

    graphics.swapBuffers();

    // Wait 2 seconds
    const start = pit.getTicks();
    while (pit.getTicks() - start < 200) {
        asm volatile ("hlt");
    }
}

// Date popup state
var date_popup_open: bool = false;
var date_popup_x: i32 = 0;
var date_popup_y: i32 = 0;

/// Draw date popup near system tray
fn drawDatePopup() void {
    if (!date_popup_open) return;

    const popup_w: u32 = 140;
    const popup_h: u32 = 80;

    // Shadow
    graphics.fillRect(date_popup_x + 2, date_popup_y + 2, popup_w, popup_h, Color.rgba(0, 0, 0, 80));
    // Background
    graphics.fillRect(date_popup_x, date_popup_y, popup_w, popup_h, Color.rgb(45, 48, 55));
    graphics.drawRect(date_popup_x, date_popup_y, popup_w, popup_h, Color.rgb(70, 75, 85));

    // Header
    graphics.fillRect(date_popup_x, date_popup_y, popup_w, 20, Color.rgb(50, 120, 200));
    font.drawString(date_popup_x + 8, date_popup_y + 4, "Date & Time", graphics.WHITE, null);

    // Full date
    var date_buf: [20]u8 = undefined;
    const date_len = rtc.getFullDateString(&date_buf);
    font.drawString(date_popup_x + 8, date_popup_y + 28, date_buf[0..date_len], graphics.WHITE, null);

    // Full time with seconds
    var time_buf: [10]u8 = undefined;
    const time_len = rtc.getFullTimeString(&time_buf);
    font.drawString(date_popup_x + 8, date_popup_y + 44, time_buf[0..time_len], Color.rgb(100, 200, 255), null);

    // Day of week
    const dow = rtc.getDayOfWeek();
    const dow_names = [_][]const u8{ "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday" };
    if (dow < 7) {
        font.drawString(date_popup_x + 8, date_popup_y + 60, dow_names[dow], Color.rgb(150, 150, 160), null);
    }
}

/// Update cached time strings (called once per second)
fn updateCachedTime() void {
    const dt = rtc.getDateTime();
    // Only update if second changed
    if (dt.second != last_rtc_second) {
        last_rtc_second = dt.second;
        cached_date_len = rtc.getShortDateString(&cached_date_buf);
        cached_time_len = rtc.getShortTimeString(&cached_time_buf);
    }
}

/// MacOS-style centered translucent Dock (Hyprland UI)
fn drawTaskbar() void {
    const dock_margin_b: i32 = 8;
    const dock_h: u32 = 44;
    const dock_y = @as(i32, @intCast(screen_height)) - @as(i32, @intCast(dock_h)) - dock_margin_b;

    // Calculate total dock width (Start + Tray + Windows)
    var visible_windows: u32 = 0;
    var i: usize = 0;
    while (i < window_count) : (i += 1) {
        if (windows[i].visible) visible_windows += 1;
    }
    
    const item_w: u32 = 50;
    // 60px (start) + 120px (tray) + padding + (windows * 55)
    const dock_w: u32 = 60 + 120 + 20 + (visible_windows * (item_w + 5));
    const dock_x = @as(i32, @intCast(screen_width / 2)) - @as(i32, @intCast(dock_w / 2));

    // Draw Translucent MacOS Dock background
    graphics.fillRoundRectAlpha(dock_x, dock_y, dock_w, dock_h, 8, Color.rgba(30, 30, 35, 180));
    graphics.drawRoundRectAlpha(dock_x, dock_y, dock_w, dock_h, 8, Color.rgba(100, 150, 255, 100));

    // Start Button (Mac Apple Logo style substitute)
    const start_color = if (start_menu_open) Color.rgba(100, 100, 110, 200) else Color.rgba(60, 60, 65, 150);
    graphics.fillRoundRectAlpha(dock_x + 8, dock_y + 6, 44, 32, 4, start_color);
    font.drawString(dock_x + 16, dock_y + 16, "OS", graphics.WHITE, null);

    // Active Window Icons
    var btn_x: i32 = dock_x + 60;
    const btn_focused = Color.rgba(80, 150, 255, 200);
    const btn_normal = Color.rgba(50, 50, 55, 150);

    var j: usize = 0;
    while (j < window_count) : (j += 1) {
        if (windows[j].visible) {
            const btn_c = if (windows[j].focused) btn_focused else btn_normal;
            graphics.fillRoundRectAlpha(btn_x, dock_y + 6, item_w, 32, 4, btn_c);
            
            // App Initial (first 2 chars of title)
            const title = windows[j].getTitle();
            const len = @min(2, title.len);
            font.drawString(btn_x + 16, dock_y + 16, title[0..len], graphics.WHITE, null);
            
            // Dot indicator for open app
            if (windows[j].focused) {
                graphics.fillRectAlpha(btn_x + 22, dock_y + 40, 6, 2, Color.rgba(255, 255, 255, 200));
            }
            btn_x += @intCast(item_w + 5);
        }
    }

    // System Tray (Right side of dock)
    const tray_x = dock_x + @as(i32, @intCast(dock_w)) - 130;
    graphics.fillRoundRectAlpha(tray_x, dock_y + 6, 120, 32, 4, Color.rgba(40, 40, 45, 150));

    // Memory usage bubble
    const heap = @import("../mm/heap.zig");
    const mem_used = heap.getUsedMemory();
    const mem_total = heap.getTotalSize();
    const mem_pct: u32 = if (mem_total > 0) @truncate((@as(u64, mem_used) * 100) / @as(u64, mem_total)) else 0;
    const bar_color = if (mem_pct > 80) Color.rgb(255, 80, 80) else Color.rgb(80, 255, 120);
    graphics.fillRectAlpha(tray_x + 6, dock_y + 18, 16, 8, bar_color);

    // Network dot
    const net = @import("../net/net.zig");
    const net_color = if (net.hasNic()) Color.rgb(80, 255, 120) else Color.rgb(255, 80, 80);
    graphics.fillCircle(tray_x + 34, dock_y + 22, 4, net_color);

    // Clock
    updateCachedTime();
    if (cached_date_len > 0) {
        font.drawString(tray_x + 46, dock_y + 10, cached_date_buf[0..cached_date_len], Color.rgba(200, 200, 205, 200), null);
    }
    if (cached_time_len > 0) {
        font.drawString(tray_x + 46, dock_y + 22, cached_time_buf[0..cached_time_len], graphics.WHITE, null);
    }

    if (start_menu_open) {
        drawStartMenu();
    }

    if (context_menu_open) {
        drawContextMenu();
    }
}

fn drawContextMenu() void {
    // Shadow
    graphics.fillRect(context_menu_x + 3, context_menu_y + 3, CONTEXT_MENU_WIDTH, CONTEXT_MENU_HEIGHT, Color.rgba(0, 0, 0, 80));
    // Background
    graphics.fillRect(context_menu_x, context_menu_y, CONTEXT_MENU_WIDTH, CONTEXT_MENU_HEIGHT, Color.rgb(45, 45, 50));
    graphics.drawRect(context_menu_x, context_menu_y, CONTEXT_MENU_WIDTH, CONTEXT_MENU_HEIGHT, Color.rgb(70, 70, 75));

    const items = [_][]const u8{ "New File", "Hex Viewer", "Colors", "Settings" };
    var item_y = context_menu_y + 4;
    const state = mouse.getState();

    for (items) |item| {
        const hover = state.x >= context_menu_x and state.x < context_menu_x + @as(i32, @intCast(CONTEXT_MENU_WIDTH)) and
            state.y >= item_y and state.y < item_y + 22;
        if (hover) {
            graphics.fillRect(context_menu_x + 2, item_y, CONTEXT_MENU_WIDTH - 4, 22, Color.rgb(60, 130, 210));
        }
        font.drawString(context_menu_x + 8, item_y + 4, item, graphics.WHITE, null);
        item_y += 24;
    }
}

fn drawStartMenu() void {
    const menu_x: i32 = 4;
    const menu_y = @as(i32, @intCast(screen_height - TASKBAR_HEIGHT)) - @as(i32, @intCast(START_MENU_HEIGHT + 28));

    // Shadow
    graphics.fillRect(menu_x + 4, menu_y + 4, START_MENU_WIDTH, START_MENU_HEIGHT + 28, Color.rgba(0, 0, 0, 100));
    // Menu background
    graphics.fillRect(menu_x, menu_y, START_MENU_WIDTH, START_MENU_HEIGHT + 28, Color.rgb(45, 45, 50));
    graphics.drawRect(menu_x, menu_y, START_MENU_WIDTH, START_MENU_HEIGHT + 28, Color.rgb(70, 70, 75));

    // Header
    graphics.fillRect(menu_x, menu_y, START_MENU_WIDTH, 28, Color.rgb(50, 120, 200));
    font.drawString(menu_x + 12, menu_y + 6, "Home OS", graphics.WHITE, null);
    font.drawString(menu_x + 80, menu_y + 6, VERSION, Color.rgb(200, 220, 255), null);

    // Compact Start Menu - essential items only (apps on desktop)
    const items = [_][]const u8{ "HomeBrowser", "File Manager", "Task Manager", "Settings", "About", "Shutdown", "Exit GUI" };
    const icons = [_]Color{ Color.rgb(100, 180, 255), Color.rgb(255, 200, 80), Color.rgb(80, 200, 120), Color.rgb(150, 150, 155), Color.rgb(100, 150, 255), Color.rgb(255, 150, 100), Color.rgb(255, 100, 100) };
    var item_y = menu_y + 34;
    var idx: usize = 0;
    for (items) |item| {
        const state = mouse.getState();
        const hover = state.x >= menu_x and state.x < menu_x + @as(i32, @intCast(START_MENU_WIDTH)) and
            state.y >= item_y and state.y < item_y + 26;
        if (hover) {
            graphics.fillRect(menu_x + 2, item_y, START_MENU_WIDTH - 4, 26, Color.rgb(60, 130, 210));
            graphics.fillRect(menu_x + 10, item_y + 5, 16, 16, icons[idx]);
            graphics.drawRect(menu_x + 10, item_y + 5, 16, 16, Color.rgb(30, 30, 35));
            font.drawString(menu_x + 32, item_y + 6, item, graphics.WHITE, null);
        } else {
            graphics.fillRect(menu_x + 10, item_y + 5, 16, 16, icons[idx]);
            graphics.drawRect(menu_x + 10, item_y + 5, 16, 16, Color.rgb(60, 60, 65));
            font.drawString(menu_x + 32, item_y + 6, item, Color.rgb(220, 220, 225), null);
        }
        item_y += 28;
        idx += 1;
    }
}

/// Optimized cursor drawing - only draw non-transparent pixels
fn drawCursor() void {
    if (!cursor_visible) return;

    const state = mouse.getState();
    cursor_x = state.x;
    cursor_y = state.y;

    // Pre-compute colors
    const black = graphics.BLACK.toU32();
    const white = graphics.WHITE.toU32();
    const buffer = graphics.getDrawBufferDirect();
    const sw = graphics.getWidth();
    const sh = graphics.getHeight();

    var row: usize = 0;
    while (row < 16) : (row += 1) {
        const py = cursor_y + @as(i32, @intCast(row));
        if (py < 0 or py >= @as(i32, @intCast(sh))) continue;

        const row_offset = @as(u32, @intCast(py)) * sw;

        var col: usize = 0;
        while (col < 16) : (col += 1) {
            const pixel = cursor_data[row][col];
            if (pixel == 0) continue;

            const px = cursor_x + @as(i32, @intCast(col));
            if (px < 0 or px >= @as(i32, @intCast(sw))) continue;

            const offset = row_offset + @as(u32, @intCast(px));
            buffer[offset] = if (pixel == 1) black else white;
        }
    }
}

var last_left_pressed: bool = false;
var last_right_pressed: bool = false;
var dragging_window: ?usize = null;
var drag_offset_x: i32 = 0;
var drag_offset_y: i32 = 0;

// Context menu state
var context_menu_open: bool = false;
var context_menu_x: i32 = 0;
var context_menu_y: i32 = 0;
const CONTEXT_MENU_WIDTH: u32 = 120;
const CONTEXT_MENU_HEIGHT: u32 = 100;

// Window resize state
var resizing_window: ?usize = null;
var resize_start_w: u32 = 0;
var resize_start_h: u32 = 0;
var resize_start_mx: i32 = 0;
var resize_start_my: i32 = 0;
const RESIZE_HANDLE_SIZE: i32 = 12;

// Window snapping state
const SNAP_THRESHOLD: i32 = 15; // Pixels from edge to trigger snap
var snap_preview_active: bool = false;
var snap_preview_zone: SnapZone = .none;

const SnapZone = enum {
    none,
    left, // Left half of screen
    right, // Right half of screen
    top, // Maximize
    top_left, // Top-left quarter
    top_right, // Top-right quarter
};

// Double-click detection
var last_click_time: u32 = 0;
var last_click_x: i32 = 0;
var last_click_y: i32 = 0;
var click_count: u8 = 0;
var frame_tick: u32 = 0;

fn handleRightClick(mx: i32, my: i32) void {
    const taskbar_y = @as(i32, @intCast(screen_height - TASKBAR_HEIGHT));

    // Only show context menu on desktop area (not on windows or taskbar)
    if (my >= taskbar_y) return;

    // Check if clicking on a window
    var i: usize = window_count;
    while (i > 0) {
        i -= 1;
        if (!windows[i].visible or windows[i].minimized) continue;
        if (windows[i].containsPoint(mx, my)) return;
    }

    // Show context menu at mouse position
    context_menu_x = mx;
    context_menu_y = my;

    // Clamp to screen bounds
    if (context_menu_x + @as(i32, @intCast(CONTEXT_MENU_WIDTH)) > @as(i32, @intCast(screen_width))) {
        context_menu_x = @as(i32, @intCast(screen_width)) - @as(i32, @intCast(CONTEXT_MENU_WIDTH));
    }
    if (context_menu_y + @as(i32, @intCast(CONTEXT_MENU_HEIGHT)) > taskbar_y) {
        context_menu_y = taskbar_y - @as(i32, @intCast(CONTEXT_MENU_HEIGHT));
    }

    context_menu_open = true;
    start_menu_open = false;
}

pub fn handleMouseClick(mx: i32, my: i32) void {
    // Reset screensaver on click
    screensaver.resetIdle();
    playClickSound();

    // Calculate MacOS Dock Bounds dynamically
    const dock_margin_b: i32 = 8;
    const dock_h: u32 = 44;
    const dock_y = @as(i32, @intCast(screen_height)) - @as(i32, @intCast(dock_h)) - dock_margin_b;

    var visible_windows: u32 = 0;
    var w_idx: usize = 0;
    while (w_idx < window_count) : (w_idx += 1) {
        if (windows[w_idx].visible) visible_windows += 1;
    }
    
    const item_w: u32 = 50;
    const dock_w: u32 = 60 + 120 + 20 + (visible_windows * (item_w + 5));
    const dock_x = @as(i32, @intCast(screen_width / 2)) - @as(i32, @intCast(dock_w / 2));
    const tray_x = dock_x + @as(i32, @intCast(dock_w)) - 130;

    // Close date popup if clicking outside
    if (date_popup_open) {
        if (mx < date_popup_x or mx >= date_popup_x + 140 or
            my < date_popup_y or my >= date_popup_y + 80)
        {
            date_popup_open = false;
        }
    }

    // Handle context menu click
    if (context_menu_open) {
        if (mx >= context_menu_x and mx < context_menu_x + @as(i32, @intCast(CONTEXT_MENU_WIDTH)) and
            my >= context_menu_y and my < context_menu_y + @as(i32, @intCast(CONTEXT_MENU_HEIGHT)))
        {
            const rel_y = my - context_menu_y - 4;
            if (rel_y >= 0) {
                const item_idx = @as(usize, @intCast(rel_y)) / 24;
                handleContextMenuItem(item_idx);
            }
        }
        context_menu_open = false;
        return;
    }

    // Check if click is inside the Dock
    if (my >= dock_y and my < dock_y + @as(i32, @intCast(dock_h)) and mx >= dock_x and mx < dock_x + @as(i32, @intCast(dock_w))) {
        // Start button (Apple logo equivalent)
        if (mx >= dock_x + 8 and mx < dock_x + 52) {
            start_menu_open = !start_menu_open;
            return;
        }
        
        // System tray clicks
        if (mx >= tray_x and mx < tray_x + 120) {
            // Memory icon
            if (mx < tray_x + 30) {
                _ = createWindowWithType(140, 70, 310, 250, "Task Manager", .taskmanager);
                return;
            }
            // Ping Tool via Network Node
            if (mx >= tray_x + 30 and mx < tray_x + 40) {
                _ = createWindowWithType(150, 80, 280, 200, "Ping Tool", .pingui);
                return;
            }
            // Clock
            if (mx >= tray_x + 40) {
                date_popup_open = !date_popup_open;
                if (date_popup_open) {
                    date_popup_x = tray_x;
                    date_popup_y = dock_y - 90;
                }
                return;
            }
        }

        // Active Apps Click
        var btn_x: i32 = dock_x + 60;
        var btn_i: usize = 0;
        while (btn_i < window_count) : (btn_i += 1) {
            if (windows[btn_i].visible) {
                if (mx >= btn_x and mx < btn_x + @as(i32, @intCast(item_w))) {
                    if (windows[btn_i].minimized) {
                        windows[btn_i].minimized = false;
                    }
                    if (focused_window) |prev| {
                        windows[prev].focused = false;
                    }
                    focused_window = btn_i;
                    windows[btn_i].focused = true;
                    return;
                }
                btn_x += @intCast(item_w + 5);
            }
        }
        return; // Clicked empty dock space
    }

    if (start_menu_open) {
        const menu_x: i32 = 4;
        const menu_y = dock_y - @as(i32, @intCast(START_MENU_HEIGHT + 28));

        if (mx >= menu_x and mx < menu_x + @as(i32, @intCast(START_MENU_WIDTH)) and
            my >= menu_y and my < menu_y + @as(i32, @intCast(START_MENU_HEIGHT + 28)))
        {
            const item_start_y = menu_y + 32;
            if (my >= item_start_y) {
                const item_idx = @as(usize, @intCast(my - item_start_y)) / 28;
                handleStartMenuItem(item_idx);
            }
            start_menu_open = false;
            return;
        }
        start_menu_open = false;
    }

    // Check windows FIRST before desktop icons (fix click-through bug)
    var i: usize = window_count;
    while (i > 0) {
        i -= 1;
        if (!windows[i].visible or windows[i].minimized) continue;

        const win = &windows[i];

        // Close button
        if (window.isOnCloseButton(win, mx, my)) {
            win.visible = false;
            if (focused_window == i) focused_window = null;
            playCloseSound();
            return;
        }

        // Maximize button
        if (window.isOnMaximizeButton(win, mx, my)) {
            window.toggleMaximize(win, screen_width, screen_height, TASKBAR_HEIGHT);
            return;
        }

        // Minimize button
        if (window.isOnMinimizeButton(win, mx, my)) {
            win.minimized = true;
            win.focused = false;
            if (focused_window == i) focused_window = null;
            return;
        }

        // Check resize handle (bottom-right corner)
        if (isOnResizeHandle(win, mx, my)) {
            resizing_window = i;
            resize_start_w = win.width;
            resize_start_h = win.height;
            resize_start_mx = mx;
            resize_start_my = my;
            if (focused_window) |prev| {
                windows[prev].focused = false;
            }
            focused_window = i;
            win.focused = true;
            return;
        }

        if (win.titleBarContains(mx, my)) {
            // Check for double-click to maximize
            const is_double = (frame_tick - last_click_time < 20) and
                (@abs(mx - last_click_x) < 5) and
                (@abs(my - last_click_y) < 5);

            if (is_double) {
                window.toggleMaximize(win, screen_width, screen_height, TASKBAR_HEIGHT);
                last_click_time = 0; // Reset to prevent triple-click
            } else {
                dragging_window = i;
                drag_offset_x = mx - win.x;
                drag_offset_y = my - win.y;
            }

            if (focused_window) |prev| {
                windows[prev].focused = false;
            }
            focused_window = i;
            win.focused = true;

            last_click_time = frame_tick;
            last_click_x = mx;
            last_click_y = my;
            return;
        }

        if (win.containsPoint(mx, my)) {
            if (focused_window) |prev| {
                windows[prev].focused = false;
            }
            focused_window = i;
            windows[i].focused = true;

            // Handle click inside window based on type
            switch (windows[i].win_type) {
                .calculator => calculator.handleClick(&windows[i], mx, my),
                .settings => settings.handleClick(&windows[i], mx, my),
                .devmgr => devmgr.handleClick(&windows[i], mx, my),
                .taskmanager => taskmanager.handleClick(&windows[i], mx, my),
                .filemanager => filemanager.handleClick(&windows[i], mx, my),
                .paint => paint.handleClick(&windows[i], mx, my),
                .calendar => calendar.handleClick(&windows[i], mx, my),
                .minesweeper => minesweeper.handleClick(&windows[i], mx, my),
                .browser => browser.handleClick(&windows[i], mx, my),
                else => {},
            }
            return;
        }
    }

    // Only check desktop icons if no window was clicked
    _ = handleDesktopIconClick(mx, my);
}

fn playClickSound() void {
    // Short click sound - non-blocking
    audio.playToneAsync(800, 3);
}

/// Play window open sound (non-blocking)
fn playOpenSound() void {
    audio.playToneAsync(700, 4);
}

/// Play window close sound (non-blocking)
fn playCloseSound() void {
    audio.playToneAsync(500, 4);
}

/// Play error sound
pub fn playErrorSound() void {
    audio.playTone(200, 10);
}

fn handleContextMenuItem(idx: usize) void {
    switch (idx) {
        0 => {
            // New File - open notepad
            _ = createWindowWithType(200, 100, 380, 300, "Notepad", .notepad);
        },
        1 => {
            // Hex Viewer
            _ = createWindowWithType(150, 80, 300, 200, "Hex Viewer", .hexview);
        },
        2 => {
            // Color Picker
            _ = createWindowWithType(150, 80, 250, 140, "Color Picker", .colorpicker);
        },
        3 => {
            // Settings
            _ = createWindowWithType(160, 90, 290, 230, "Settings", .settings);
        },
        else => {},
    }
}

fn handleStartMenuItem(idx: usize) void {
    switch (idx) {
        0 => {
            // Browser
            _ = createWindowWithType(80, 40, 500, 380, "HomeBrowser", .browser);
            browser.init();
        },
        1 => {
            // File Manager
            _ = createWindowWithType(150, 80, 300, 250, "File Manager", .filemanager);
            filemanager.loadFiles();
        },
        2 => _ = createWindowWithType(140, 70, 310, 250, "Task Manager", .taskmanager),
        3 => _ = createWindowWithType(160, 90, 290, 230, "Settings", .settings),
        4 => _ = createWindowWithType(200, 150, 280, 180, "About Home OS", .about),
        5 => {
            // Shutdown - show shutdown screen and exit
            showShutdownScreen();
            exit_requested = true;
        },
        6 => exit_requested = true, // Exit GUI
        else => {},
    }
}

fn handleDesktopIconClick(mx: i32, my: i32) bool {
    for (desktop_icons) |icon| {
        if (mx >= icon.x and mx < icon.x + 48 and my >= icon.y and my < icon.y + 56) {
            // Check for double-click (within 30 frames and 10 pixels)
            const is_double = (frame_tick - last_click_time < 30) and
                (@abs(mx - last_click_x) < 10) and
                (@abs(my - last_click_y) < 10);

            if (is_double) {
                // Double-click - open the app
                switch (icon.icon_type) {
                    .computer => _ = createWindowWithType(150, 80, 320, 220, "System Info", .sysinfo),
                    .folder => {
                        _ = createWindowWithType(150, 80, 300, 250, "File Manager", .filemanager);
                        filemanager.loadFiles();
                    },
                    .terminal => _ = createWindowWithType(80, 50, 500, 340, "Terminal", .terminal),
                    .settings => _ = createWindowWithType(160, 90, 290, 230, "Settings", .settings),
                    .notepad => _ = createWindowWithType(200, 100, 380, 300, "Notepad", .notepad),
                    .calculator => _ = createWindowWithType(200, 100, 180, 270, "Calculator", .calculator),
                    .paint => _ = createWindowWithType(100, 60, 320, 280, "Paint", .paint),
                    .clock => _ = createWindowWithType(250, 120, 220, 240, "Clock", .clock),
                    .snake => _ = createWindowWithType(150, 80, 360, 320, "Snake", .snake),
                    .hexview => _ = createWindowWithType(150, 80, 300, 200, "Hex Viewer", .hexview),
                    .colorpicker => _ = createWindowWithType(150, 80, 250, 140, "Color Picker", .colorpicker),
                    .logs => {
                        _ = createWindowWithType(120, 60, 320, 220, "System Logs", .logviewer);
                        logviewer.initSystemLogs();
                    },
                    .ping => _ = createWindowWithType(150, 80, 280, 200, "Ping Tool", .pingui),
                    .sysmon => _ = createWindowWithType(100, 60, 260, 280, "System Monitor", .sysmon),
                    .calendar => _ = createWindowWithType(150, 80, 220, 240, "Calendar", .calendar),
                    .minesweeper => _ = createWindowWithType(120, 60, 220, 260, "Minesweeper", .minesweeper),
                    .tetris => _ = createWindowWithType(150, 80, 260, 340, "Tetris", .tetris),
                    .browser => {
                        _ = createWindowWithType(80, 40, 500, 380, "HomeBrowser", .browser);
                        browser.init();
                    },
                    .file => {},
                }
                click_count = 0;
                selected_icon = null;
            } else {
                // Single click - select icon
                for (desktop_icons, 0..) |di, didx| {
                    if (di.x == icon.x and di.y == icon.y) {
                        selected_icon = didx;
                        break;
                    }
                }
                click_count = 1;
            }

            last_click_time = frame_tick;
            last_click_x = mx;
            last_click_y = my;
            return is_double;
        }
    }
    return false;
}

pub fn handleMouseRelease() void {
    // Apply window snapping on release
    if (dragging_window) |idx| {
        if (snap_preview_active and snap_preview_zone != .none) {
            applyWindowSnap(&windows[idx], snap_preview_zone);
        }
        snap_preview_active = false;
        snap_preview_zone = .none;
        dragging_window = null;
    }
    if (resizing_window != null) {
        resizing_window = null;
    }
}

/// Detect which snap zone the mouse is in
fn detectSnapZone(mx: i32, my: i32) SnapZone {
    const sw = @as(i32, @intCast(screen_width));
    const sh = @as(i32, @intCast(screen_height - TASKBAR_HEIGHT));

    // Top edge = maximize
    if (my < SNAP_THRESHOLD) {
        if (mx < SNAP_THRESHOLD) return .top_left;
        if (mx > sw - SNAP_THRESHOLD) return .top_right;
        return .top;
    }

    // Left edge = left half
    if (mx < SNAP_THRESHOLD and my < sh) {
        return .left;
    }

    // Right edge = right half
    if (mx > sw - SNAP_THRESHOLD and my < sh) {
        return .right;
    }

    return .none;
}

/// Apply window snap to the specified zone
fn applyWindowSnap(win: *Window, zone: SnapZone) void {
    const sw = screen_width;
    const sh = screen_height - TASKBAR_HEIGHT;

    // Save original position/size for restore
    if (!win.maximized) {
        win.saved_x = win.x;
        win.saved_y = win.y;
        win.saved_width = win.width;
        win.saved_height = win.height;
    }

    switch (zone) {
        .left => {
            win.x = 0;
            win.y = 0;
            win.width = sw / 2;
            win.height = sh;
            win.maximized = false; // Half-snapped, not maximized
        },
        .right => {
            win.x = @intCast(sw / 2);
            win.y = 0;
            win.width = sw / 2;
            win.height = sh;
            win.maximized = false;
        },
        .top => {
            win.x = 0;
            win.y = 0;
            win.width = sw;
            win.height = sh;
            win.maximized = true;
        },
        .top_left => {
            win.x = 0;
            win.y = 0;
            win.width = sw / 2;
            win.height = sh / 2;
            win.maximized = false;
        },
        .top_right => {
            win.x = @intCast(sw / 2);
            win.y = 0;
            win.width = sw / 2;
            win.height = sh / 2;
            win.maximized = false;
        },
        .none => {},
    }
}

fn isOnResizeHandle(win: *const Window, mx: i32, my: i32) bool {
    const right = win.x +| @as(i32, @intCast(win.width));
    const bottom = win.y +| @as(i32, @intCast(win.height));
    return mx >= right -| RESIZE_HANDLE_SIZE and mx < right and
        my >= bottom -| RESIZE_HANDLE_SIZE and my < bottom;
}

pub fn handleMouseMove(mx: i32, my: i32) void {
    if (dragging_window) |idx| {
        windows[idx].x = mx -| drag_offset_x;
        windows[idx].y = my -| drag_offset_y;

        // Detect snap zones while dragging
        snap_preview_zone = detectSnapZone(mx, my);
        snap_preview_active = snap_preview_zone != .none;

        // Basic edge snapping (within 10 pixels)
        const snap_dist: i32 = 10;
        if (windows[idx].x < snap_dist) windows[idx].x = 0;
        if (windows[idx].y < snap_dist) windows[idx].y = 0;

        // Safe max calculation - ensure window width/height don't exceed screen
        const win_w = @min(windows[idx].width, screen_width);
        const win_h = @min(windows[idx].height, if (screen_height > TASKBAR_HEIGHT) screen_height - TASKBAR_HEIGHT else 100);
        const max_x: i32 = @as(i32, @intCast(screen_width)) -| @as(i32, @intCast(win_w));
        const max_y: i32 = @as(i32, @intCast(screen_height -| TASKBAR_HEIGHT)) -| @as(i32, @intCast(win_h));

        if (windows[idx].x > max_x -| snap_dist) windows[idx].x = @max(0, max_x);
        if (windows[idx].y > max_y -| snap_dist) windows[idx].y = @max(0, max_y);

        // Clamp to screen bounds
        if (windows[idx].x < 0) windows[idx].x = 0;
        if (windows[idx].y < 0) windows[idx].y = 0;
        if (max_x > 0 and windows[idx].x > max_x) windows[idx].x = max_x;
        if (max_y > 0 and windows[idx].y > max_y) windows[idx].y = max_y;
    }

    if (resizing_window) |idx| {
        const dx = mx -| resize_start_mx;
        const dy = my -| resize_start_my;

        // Calculate new size with safe arithmetic
        var new_w: i32 = @as(i32, @intCast(resize_start_w)) +| dx;
        var new_h: i32 = @as(i32, @intCast(resize_start_h)) +| dy;

        // Minimum size constraints
        const min_w: i32 = 150;
        const min_h: i32 = 100;
        if (new_w < min_w) new_w = min_w;
        if (new_h < min_h) new_h = min_h;

        // Maximum size constraints (screen bounds) - safe calculation
        const max_w: i32 = @as(i32, @intCast(screen_width)) -| windows[idx].x;
        const max_h: i32 = @as(i32, @intCast(screen_height -| TASKBAR_HEIGHT)) -| windows[idx].y;
        if (max_w > 0 and new_w > max_w) new_w = max_w;
        if (max_h > 0 and new_h > max_h) new_h = max_h;

        windows[idx].width = if (new_w > 0) @intCast(new_w) else 150;
        windows[idx].height = if (new_h > 0) @intCast(new_h) else 100;
    }
}

pub fn update() void {
    frame_tick +%= 1;
    const state = mouse.getState();

    if (state.left and !last_left_pressed) {
        handleMouseClick(state.x, state.y);
    } else if (!state.left and last_left_pressed) {
        handleMouseRelease();
    }

    // Right-click for context menu
    if (state.right and !last_right_pressed) {
        handleRightClick(state.x, state.y);
    }

    if (state.left and (dragging_window != null or resizing_window != null)) {
        handleMouseMove(state.x, state.y);
    }

    // Handle mouse drag for Paint app (continuous drawing while holding)
    if (state.left and dragging_window == null and resizing_window == null) {
        if (focused_window) |idx| {
            if (windows[idx].win_type == .paint and windows[idx].visible and !windows[idx].minimized) {
                paint.handleDrag(&windows[idx], state.x, state.y);
            }
        }
    }

    // Handle mouse scroll wheel - process all pending scroll events
    while (mouse.hasScrollEvents()) {
        const scroll = mouse.getScrollEvent();
        if (scroll != 0) {
            handleMouseScroll(scroll);
        }
    }

    // Also check accumulated scroll for smooth scrolling
    const acc_scroll = mouse.getAccumulatedScroll();
    if (acc_scroll != 0) {
        // Convert accumulated scroll to i8 range
        const clamped: i8 = if (acc_scroll > 127) 127 else if (acc_scroll < -128) -128 else @as(i8, @intCast(acc_scroll));
        if (clamped != 0) {
            handleMouseScroll(clamped);
        }
    }

    last_left_pressed = state.left;
    last_right_pressed = state.right;
    drawDesktop();
}

/// Handle mouse scroll wheel for focused window
fn handleMouseScroll(scroll: i8) void {
    // Reset screensaver on scroll
    screensaver.resetIdle();

    if (focused_window) |idx| {
        if (!windows[idx].visible or windows[idx].minimized) return;

        switch (windows[idx].win_type) {
            .terminal => terminal.handleScroll(scroll),
            .filemanager => filemanager.handleScroll(scroll),
            .notepad => notepad.handleScroll(scroll),
            .hexview => hexview.handleScroll(scroll),
            .logviewer => logviewer.handleScroll(scroll),
            else => {},
        }
    }
}

pub fn isInitialized() bool {
    return initialized;
}

pub fn handleKeyPress(key: u8) void {
    // Reset screensaver on any key
    screensaver.resetIdle();

    // Global keyboard shortcuts
    const keyboard = @import("../drivers/keyboard.zig");

    // Alt+Tab to cycle windows (Tab = 9)
    if (key == '\t') {
        cycleWindows();
        return;
    }

    // Escape to close focused window (like Alt+F4)
    if (key == 27) { // ESC key
        if (focused_window) |idx| {
            windows[idx].visible = false;
            focused_window = null;
        }
        return;
    }

    // F1 = Help/About
    if (key == keyboard.KEY_F1) {
        _ = createWindowWithType(200, 150, 280, 180, "About Home OS", .about);
        return;
    }

    // F2 = File Manager
    if (key == keyboard.KEY_F2) {
        _ = createWindowWithType(150, 80, 300, 250, "File Manager", .filemanager);
        filemanager.loadFiles();
        return;
    }

    // F3 = Terminal
    if (key == keyboard.KEY_F3) {
        _ = createWindowWithType(80, 50, 500, 340, "Terminal", .terminal);
        return;
    }

    // F4 = Calculator
    if (key == keyboard.KEY_F4) {
        _ = createWindowWithType(200, 100, 180, 270, "Calculator", .calculator);
        return;
    }

    // F5 = Notepad
    if (key == keyboard.KEY_F5) {
        _ = createWindowWithType(200, 100, 380, 300, "Notepad", .notepad);
        return;
    }

    // F6 = Settings
    if (key == keyboard.KEY_F6) {
        _ = createWindowWithType(160, 90, 290, 230, "Settings", .settings);
        return;
    }

    // F7 = Task Manager
    if (key == keyboard.KEY_F7) {
        _ = createWindowWithType(140, 70, 310, 250, "Task Manager", .taskmanager);
        return;
    }

    // F8 = System Logs
    if (key == keyboard.KEY_F8) {
        _ = createWindowWithType(120, 60, 320, 220, "System Logs", .logviewer);
        logviewer.initSystemLogs();
        return;
    }

    // F10 = Cascade windows
    if (key == keyboard.KEY_F10) {
        cascadeWindows();
        return;
    }

    // F11 = Tile windows
    if (key == keyboard.KEY_F11) {
        tileWindows();
        return;
    }

    // F9 = Cycle wallpaper style
    if (key == keyboard.KEY_F9) {
        cycleWallpaper();
        return;
    }

    // F12 = Minimize all / Show desktop
    if (key == keyboard.KEY_F12) {
        minimizeAll();
        return;
    }

    // Shift+F12 = Restore all windows
    if (key == keyboard.KEY_F12 + 12) { // Shift modifier adds 12
        restoreAll();
        return;
    }

    if (focused_window) |idx| {
        switch (windows[idx].win_type) {
            .notepad => notepad.handleKey(&windows[idx], key),
            .calculator => calculator.handleKey(&windows[idx], key),
            .terminal => terminal.handleKey(key),
            .filemanager => {
                filemanager.handleKey(key);
                // Check if file manager wants to open a file in notepad
                if (filemanager.open_file_requested) {
                    filemanager.open_file_requested = false;
                    openFileInNotepad();
                }
            },
            .devmgr => devmgr.handleKey(key),
            .settings => settings.handleKey(key),
            .taskmanager => taskmanager.handleKey(&windows[idx], key),
            .paint => paint.handleKey(key),
            .clock => clock.handleKey(key),
            .snake => snake.handleKey(key),
            .hexview => hexview.handleKey(key),
            .colorpicker => colorpicker.handleKey(key),
            .logviewer => logviewer.handleKey(key),
            .pingui => pingui.handleKey(key),
            .sysmon => sysmon.handleKey(key),
            .calendar => calendar.handleKey(key),
            .minesweeper => minesweeper.handleKey(key),
            .tetris => tetris.handleKey(key),
            .browser => browser.handleKey(key),
            else => {},
        }
    }
}

fn openFileInNotepad() void {
    if (notepad.pending_file_len == 0) return;

    // Create notepad window
    const idx = createWindowWithType(200, 100, 380, 300, "Notepad", .notepad);
    if (idx) |win_idx| {
        // Load file content
        notepad.loadFileContent(&windows[win_idx], notepad.pending_file[0..notepad.pending_file_len]);
        notepad.pending_file_len = 0;
    }
}

/// Minimize all windows (show desktop)
fn minimizeAll() void {
    var i: usize = 0;
    while (i < window_count) : (i += 1) {
        if (windows[i].visible and !windows[i].minimized) {
            windows[i].minimized = true;
        }
    }
    if (focused_window) |idx| {
        windows[idx].focused = false;
    }
    focused_window = null;
}

/// Restore all minimized windows
fn restoreAll() void {
    var i: usize = 0;
    while (i < window_count) : (i += 1) {
        if (windows[i].visible and windows[i].minimized) {
            windows[i].minimized = false;
        }
    }
}

/// Cycle wallpaper style (F9)
fn cycleWallpaper() void {
    wallpaper_style = (wallpaper_style + 1) % @as(u8, @intCast(wallpaper_colors.len));
    notification.show("Wallpaper changed", .info);
}

/// Cascade windows (staggered arrangement)
fn cascadeWindows() void {
    const vbe = @import("../drivers/vbe.zig");
    const screen_w = vbe.getWidth();
    const screen_h = vbe.getHeight();
    const start_x: i32 = 50;
    const start_y: i32 = 50;
    const offset: i32 = 30;

    var pos: i32 = 0;
    var i: usize = 0;
    while (i < window_count) : (i += 1) {
        if (windows[i].visible and !windows[i].minimized) {
            windows[i].x = start_x + pos * offset;
            windows[i].y = start_y + pos * offset;
            // Wrap if going off screen
            if (windows[i].x + @as(i32, @intCast(windows[i].width)) > @as(i32, @intCast(screen_w)) - 50 or
                windows[i].y + @as(i32, @intCast(windows[i].height)) > @as(i32, @intCast(screen_h)) - 80)
            {
                pos = 0;
                windows[i].x = start_x;
                windows[i].y = start_y;
            }
            pos += 1;
        }
    }
}

/// Tile windows (grid arrangement)
fn tileWindows() void {
    const vbe = @import("../drivers/vbe.zig");
    const screen_w = vbe.getWidth();
    const screen_h = vbe.getHeight();
    const taskbar_h: u32 = 32;
    const usable_h = screen_h - taskbar_h;

    // Count visible windows
    var visible_count: usize = 0;
    var i: usize = 0;
    while (i < window_count) : (i += 1) {
        if (windows[i].visible and !windows[i].minimized) {
            visible_count += 1;
        }
    }

    if (visible_count == 0) return;

    // Calculate grid dimensions
    const cols: usize = if (visible_count <= 2) visible_count else if (visible_count <= 4) 2 else 3;
    const rows: usize = (visible_count + cols - 1) / cols;

    const tile_w: u32 = screen_w / @as(u32, @intCast(cols));
    const tile_h: u32 = usable_h / @as(u32, @intCast(rows));

    var idx: usize = 0;
    i = 0;
    while (i < window_count) : (i += 1) {
        if (windows[i].visible and !windows[i].minimized) {
            const col = idx % cols;
            const row = idx / cols;
            windows[i].x = @intCast(col * tile_w);
            windows[i].y = @intCast(row * tile_h);
            windows[i].width = tile_w - 4;
            windows[i].height = tile_h - 4;
            windows[i].maximized = false;
            idx += 1;
        }
    }
}

fn cycleWindows() void {
    if (window_count == 0) return;

    // Find next visible window
    var start: usize = 0;
    if (focused_window) |idx| {
        windows[idx].focused = false;
        start = (idx + 1) % window_count;
    }

    var i: usize = 0;
    while (i < window_count) : (i += 1) {
        const idx = (start + i) % window_count;
        if (windows[idx].visible) {
            windows[idx].minimized = false;
            windows[idx].focused = true;
            focused_window = idx;
            return;
        }
    }
}

/// Start desktop directly from kernel boot
/// This is the main entry point for GUI mode
pub fn startDesktop() void {
    const vbe = @import("../drivers/vbe.zig");
    const keyboard = @import("../drivers/keyboard.zig");

    serial.write("Desktop: Starting Home OS Desktop...\n");

    // Initialize VBE graphics
    if (!vbe.isInitialized()) {
        if (!vbe.init()) {
            serial.write("Desktop: Failed to initialize VBE\n");
            return;
        }
    }

    // Initialize graphics library
    if (!graphics.isInitialized()) {
        if (!graphics.init()) {
            serial.write("Desktop: Failed to initialize graphics\n");
            return;
        }
    }

    // Initialize mouse
    if (!mouse.isInitialized()) {
        _ = mouse.init();
    }

    // Initialize desktop
    if (!initialized) {
        if (!init()) {
            serial.write("Desktop: Failed to initialize desktop\n");
            return;
        }
    }

    // Apply saved resolution from config (after VBE is ready)
    const config = @import("config.zig");
    config.applyResolution();

    // Show boot splash
    showBootSplash();

    // Create welcome window
    _ = createWindow(100, 100, 350, 200, "Welcome to Home OS");

    serial.write("Desktop: Entering main event loop\n");

    // Main GUI event loop
    var last_mouse_x: i32 = mouse.getX();
    var last_mouse_y: i32 = mouse.getY();
    var last_left: bool = mouse.isLeftPressed();

    drawDesktop();

    var need_redraw: bool = false;
    var frame_counter: u32 = 0;

    const pit = @import("../drivers/pit.zig");

    while (true) {
        // Handle keyboard input
        if (keyboard.hasKey()) {
            if (keyboard.getKey()) |key| {
                pit.markBusy(); // CPU doing work
                if (key == 27) { // ESC to exit to recovery shell
                    serial.write("Desktop: ESC pressed, exiting to shell\n");
                    break;
                } else {
                    handleKeyPress(key);
                    need_redraw = true;
                }
            }
        }

        // Check for exit request from Start Menu
        if (shouldExit()) {
            resetExit();
            serial.write("Desktop: Exit requested\n");
            break;
        }

        // Handle mouse input
        const cur_x = mouse.getX();
        const cur_y = mouse.getY();
        const cur_left = mouse.isLeftPressed();

        if (cur_x != last_mouse_x or cur_y != last_mouse_y or cur_left != last_left) {
            pit.markBusy(); // CPU doing work
            last_mouse_x = cur_x;
            last_mouse_y = cur_y;
            last_left = cur_left;
            need_redraw = true;
        }

        // Update display - optimized frame rate (redraw every 10 ticks = 10 FPS for lower CPU)
        frame_counter += 1;
        if (need_redraw or (frame_counter >= 10)) {
            pit.markBusy(); // CPU doing work (rendering)
            update();
            need_redraw = false;
            frame_counter = 0;
        }

        // Update async audio
        audio.updateAsync();

        // HLT to save CPU until next interrupt
        pit.markIdle();
        asm volatile ("hlt");
    }

    // Restore text mode when exiting
    serial.write("Desktop: Restoring text mode\n");
    vbe.restoreTextMode();
}

// ============================================================================
// Window Info API (for Task Manager)
// ============================================================================

/// Window info for GUI display
pub const WindowInfo = struct {
    title: []const u8,
    visible: bool,
    minimized: bool,
    focused: bool,
    win_type: WindowType,
};

/// Get count of GUI windows
pub fn getWindowCount() usize {
    return window_count;
}

/// Get window info by index
pub fn getWindowInfo(index: usize) ?WindowInfo {
    if (index >= window_count) return null;
    const win = &windows[index];
    return WindowInfo{
        .title = win.getTitle(),
        .visible = win.visible,
        .minimized = win.minimized,
        .focused = win.focused,
        .win_type = win.win_type,
    };
}
