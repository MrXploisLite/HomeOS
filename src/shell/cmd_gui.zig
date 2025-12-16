// Home OS - GUI & Program Commands
// Copyright © 2025 Romy Rianata - Home OS
// GUI commands: gui, gfxtest | Program commands: run, programs

const vga = @import("../lib/vga.zig");
const VgaWriter = vga.VgaWriter;
const serial = @import("../drivers/serial.zig");
const vbe = @import("../drivers/vbe.zig");
const graphics = @import("../drivers/graphics.zig");
const font = @import("../drivers/font.zig");
const mouse = @import("../drivers/mouse.zig");
const keyboard = @import("../drivers/keyboard.zig");
const desktop = @import("../gui/desktop.zig");
const programs = @import("../lib/programs.zig");
const usermode = @import("../proc/usermode.zig");

var writer: *VgaWriter = undefined;

pub fn init(w: *VgaWriter) void {
    writer = w;
}

pub fn cmdRun(name: []const u8) void {
    writer.write("\n");
    var start: usize = 0;
    var end: usize = name.len;
    while (start < end and name[start] == ' ') start += 1;
    while (end > start and name[end - 1] == ' ') end -= 1;
    if (start >= end) {
        writer.setColor(.light_red, .black);
        writer.write("Usage: run <program_name>\n");
        writer.setColor(.light_grey, .black);
        return;
    }
    const prog_name = name[start..end];
    writer.setColor(.light_cyan, .black);
    writer.write("Running program: ");
    writer.write(prog_name);
    writer.write("\n");
    writer.setColor(.light_grey, .black);
    const prog = programs.getProgram(prog_name);
    if (prog == null) {
        writer.setColor(.light_red, .black);
        writer.write("Error: Program not found: ");
        writer.write(prog_name);
        writer.write("\n");
        writer.setColor(.light_grey, .black);
        return;
    }
    const user_stack = usermode.allocUserStack();
    if (user_stack == null) {
        writer.setColor(.light_red, .black);
        writer.write("Error: Failed to allocate user stack\n");
        writer.setColor(.light_grey, .black);
        return;
    }
    writer.setColor(.yellow, .black);
    writer.write("Executing in Ring 3...\n");
    writer.setColor(.white, .black);
    const entry = @intFromPtr(prog.?);
    usermode.enterUserMode(entry, user_stack.?);
    writer.setColor(.light_green, .black);
    writer.write("\nProgram exited.\n");
    writer.setColor(.light_grey, .black);
}

pub fn cmdPrograms() void {
    writer.write("\n");
    writer.setColor(.light_cyan, .black);
    writer.write("Available Programs:\n");
    writer.setColor(.light_grey, .black);
    writer.write("  hello   - Hello world program\n");
    writer.write("  counter - Count from 1 to 5\n");
    writer.write("  sysinfo - Display system information\n");
    writer.write("\nUsage: run <program_name>\n");
}

pub fn cmdGui() void {
    writer.write("\n");
    writer.setColor(.light_cyan, .black);
    writer.write("Starting GUI mode...\n");
    writer.setColor(.light_grey, .black);
    if (!vbe.isInitialized()) {
        if (!vbe.init()) {
            writer.setColor(.light_red, .black);
            writer.write("Error: Could not initialize graphics\n");
            writer.setColor(.light_grey, .black);
            return;
        }
    }
    if (!graphics.isInitialized()) {
        if (!graphics.init()) {
            writer.setColor(.light_red, .black);
            writer.write("Error: Could not initialize graphics library\n");
            writer.setColor(.light_grey, .black);
            return;
        }
    }
    if (!mouse.isInitialized()) {
        _ = mouse.init();
    }
    if (!desktop.isInitialized()) {
        if (!desktop.init()) {
            writer.setColor(.light_red, .black);
            writer.write("Error: Could not initialize desktop\n");
            writer.setColor(.light_grey, .black);
            return;
        }
    }
    _ = desktop.createWindow(100, 100, 300, 200, "Welcome");
    serial.write("GUI: Entering GUI event loop\n");
    var last_mouse_x: i32 = mouse.getX();
    var last_mouse_y: i32 = mouse.getY();
    var last_left: bool = mouse.isLeftPressed();
    desktop.drawDesktop();
    var need_redraw: bool = false;
    var frame_counter: u32 = 0;
    while (true) {
        if (keyboard.hasKey()) {
            if (keyboard.getKey()) |key| {
                if (key == 27) {
                    serial.write("GUI: ESC pressed, exiting GUI mode\n");
                    break;
                } else {
                    desktop.handleKeyPress(key);
                    need_redraw = true;
                }
            }
        }
        if (desktop.shouldExit()) {
            desktop.resetExit();
            serial.write("GUI: Exit requested from Start Menu\n");
            break;
        }
        const cur_x = mouse.getX();
        const cur_y = mouse.getY();
        const cur_left = mouse.isLeftPressed();
        if (cur_x != last_mouse_x or cur_y != last_mouse_y or cur_left != last_left) {
            last_mouse_x = cur_x;
            last_mouse_y = cur_y;
            last_left = cur_left;
            need_redraw = true;
        }
        frame_counter += 1;
        if (need_redraw or (frame_counter >= 100)) {
            desktop.update();
            need_redraw = false;
            if (frame_counter >= 100) frame_counter = 0;
        }
        asm volatile ("hlt");
    }
    serial.write("GUI: Returning to text mode\n");
    vbe.restoreTextMode();
    writer.* = vga.VgaWriter.initAndClear();
    writer.setColor(.light_green, .black);
    writer.write("Returned from GUI mode.\n");
    writer.setColor(.light_grey, .black);
    writer.write("Note: Screen may be black due to graphics mode.\n");
    writer.write("Type 'reboot' to restart, or 'gui' to re-enter GUI.\n");
}

pub fn cmdGfxTest() void {
    writer.write("\n");
    writer.setColor(.light_cyan, .black);
    writer.write("Running graphics test...\n");
    writer.setColor(.light_grey, .black);
    if (!vbe.isInitialized()) {
        if (!vbe.init()) {
            writer.setColor(.light_red, .black);
            writer.write("Error: Could not initialize graphics\n");
            writer.setColor(.light_grey, .black);
            return;
        }
    }
    if (!graphics.isInitialized()) {
        if (!graphics.init()) {
            writer.setColor(.light_red, .black);
            writer.write("Error: Could not initialize graphics library\n");
            writer.setColor(.light_grey, .black);
            return;
        }
    }
    graphics.clear(graphics.DESKTOP_BG);
    graphics.fillRect(50, 50, 200, 150, graphics.RED);
    graphics.fillRect(100, 100, 200, 150, graphics.GREEN);
    graphics.fillRect(150, 150, 200, 150, graphics.BLUE);
    graphics.fillCircle(500, 200, 80, graphics.YELLOW);
    graphics.drawCircle(500, 200, 100, graphics.WHITE);
    graphics.drawLine(0, 0, 800, 600, graphics.WHITE);
    graphics.drawLine(800, 0, 0, 600, graphics.WHITE);
    font.drawString(300, 50, "Home OS Graphics Test", graphics.WHITE, null);
    font.drawString(300, 70, "Phase 14: Graphics & Display", graphics.LIGHT_GRAY, null);
    graphics.drawRect(600, 400, 150, 100, graphics.CYAN);
    graphics.fillRect(610, 410, 130, 80, graphics.MAGENTA);
    writer.setColor(.light_green, .black);
    writer.write("Graphics test complete!\n");
    writer.write("Press any key to return to text mode.\n");
}
