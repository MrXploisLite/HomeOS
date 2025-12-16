// Home OS - Power Commands
// Copyright © 2025 Romy Rianata - Home OS
// Power commands: reboot, shutdown

const vga = @import("../lib/vga.zig");
const VgaWriter = vga.VgaWriter;
const serial = @import("../drivers/serial.zig");
const io = @import("../arch/io.zig");

var writer: *VgaWriter = undefined;

pub fn init(w: *VgaWriter) void {
    writer = w;
}

pub fn cmdReboot() void {
    writer.write("\n");
    writer.setColor(.yellow, .black);
    writer.write("Rebooting system...\n");
    writer.setColor(.light_grey, .black);
    serial.write("REBOOT: System reboot requested\n");
    var timeout: u32 = 100000;
    while (timeout > 0) : (timeout -= 1) {
        if ((io.inb(0x64) & 0x02) == 0) break;
    }
    io.outb(0x64, 0xFE);
    halt();
}

pub fn cmdShutdown() void {
    writer.write("\n");
    writer.setColor(.yellow, .black);
    writer.write("Shutting down...\n");
    writer.setColor(.light_grey, .black);
    serial.write("SHUTDOWN: System shutdown requested\n");
    io.outw(0x604, 0x2000);
    io.outw(0xB004, 0x2000);
    writer.setColor(.light_green, .black);
    writer.write("It is now safe to turn off your computer.\n");
    halt();
}

fn halt() noreturn {
    asm volatile ("cli");
    while (true) asm volatile ("hlt");
}
