// Home OS - Shell Module
// Copyright © 2025 Romy Rianata - Home OS
// Command line interface

const serial = @import("../drivers/serial.zig");
const vga = @import("../lib/vga.zig");
const vfs = @import("../fs/vfs.zig");
const commands = @import("commands.zig");

pub const VgaWriter = vga.VgaWriter;

var command_buffer: [256]u8 = [_]u8{0} ** 256;
var command_len: usize = 0;
var writer: *VgaWriter = undefined;

/// Initialize shell
pub fn init(w: *VgaWriter, vfs_ptr: *vfs.VFS) void {
    writer = w;
    commands.init(w, vfs_ptr);
}

/// Process a character input
pub fn processChar(c: u8) void {
    if (c == '\n') {
        if (command_len > 0) {
            handleCommand(command_buffer[0..command_len]);
            command_len = 0;
        } else {
            writer.write("\n> ");
        }
    } else if (c == 8) { // Backspace
        if (command_len > 0) {
            command_len -= 1;
            writer.putChar(8); // VGA now handles backspace properly
        }
    } else if (c >= 32 and c < 127) {
        if (command_len < 255) {
            command_buffer[command_len] = c;
            command_len += 1;
            writer.putChar(c);
        }
    }
}

fn handleCommand(cmd: []const u8) void {
    // Trim whitespace
    var start: usize = 0;
    var end: usize = cmd.len;
    while (start < end and cmd[start] == ' ') start += 1;
    while (end > start and cmd[end - 1] == ' ') end -= 1;
    if (start >= end) {
        writer.write("\n> ");
        return;
    }
    const trimmed = cmd[start..end];

    serial.write("Shell> ");
    serial.write(trimmed);
    serial.write("\n");

    commands.execute(trimmed);
}
