// Home OS - Audio & USB Commands
// Copyright © 2025 Romy Rianata - Home OS
// Audio commands: beep, sound, play | USB commands: usb, lspci

const vga = @import("../lib/vga.zig");
const VgaWriter = vga.VgaWriter;
const audio = @import("../drivers/audio.zig");
const usb = @import("../drivers/usb.zig");
const pci_driver = @import("../drivers/pci.zig");

var writer: *VgaWriter = undefined;

pub fn init(w: *VgaWriter) void {
    writer = w;
}

// String comparison helper
fn memEql(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    for (a, b) |ca, cb| {
        if (ca != cb) return false;
    }
    return true;
}

pub fn cmdBeep() void {
    writer.write("\n");
    writer.setColor(.light_cyan, .black);
    writer.write("Beep!\n");
    writer.setColor(.light_grey, .black);
    audio.beep();
}

pub fn cmdSound() void {
    writer.write("\n");
    writer.setColor(.light_cyan, .black);
    writer.write("Audio Status:\n");
    writer.setColor(.light_grey, .black);
    writer.write("  Device: ");
    writer.setColor(.white, .black);
    writer.write(audio.getDeviceName());
    writer.write("\n");
    writer.setColor(.light_grey, .black);
    writer.write("  Status: ");
    if (audio.isInitialized()) {
        writer.setColor(.light_green, .black);
        writer.write("Initialized\n");
    } else {
        writer.setColor(.yellow, .black);
        writer.write("Not initialized\n");
    }
    writer.setColor(.light_grey, .black);
    writer.write("  Playing: ");
    if (audio.isPlaying()) {
        writer.setColor(.light_green, .black);
        writer.write("Yes\n");
    } else {
        writer.setColor(.light_grey, .black);
        writer.write("No\n");
    }
    writer.setColor(.light_grey, .black);
}

pub fn cmdPlay(args: []const u8) void {
    writer.write("\n");
    if (memEql(args, "demo")) {
        writer.setColor(.light_cyan, .black);
        writer.write("Playing demo melody...\n");
        writer.setColor(.light_grey, .black);
        audio.playDemo();
        writer.setColor(.light_green, .black);
        writer.write("Done!\n");
    } else if (memEql(args, "startup")) {
        writer.setColor(.light_cyan, .black);
        writer.write("Playing startup sound...\n");
        writer.setColor(.light_grey, .black);
        audio.playStartup();
        writer.setColor(.light_green, .black);
        writer.write("Done!\n");
    } else if (memEql(args, "error")) {
        writer.setColor(.light_cyan, .black);
        writer.write("Playing error sound...\n");
        writer.setColor(.light_grey, .black);
        audio.playError();
        writer.setColor(.light_green, .black);
        writer.write("Done!\n");
    } else if (memEql(args, "beep")) {
        cmdBeep();
        return;
    } else {
        writer.setColor(.light_grey, .black);
        writer.write("Usage: play <demo|startup|error|beep>\n");
    }
    writer.setColor(.light_grey, .black);
}

pub fn cmdUsb() void {
    writer.write("\n");
    writer.setColor(.light_cyan, .black);
    writer.write("USB Status:\n");
    writer.setColor(.light_grey, .black);
    if (!usb.isInitialized()) {
        writer.setColor(.yellow, .black);
        writer.write("  USB not initialized\n");
        writer.setColor(.light_grey, .black);
        return;
    }
    writer.write("  Controller: ");
    writer.setColor(.white, .black);
    writer.write(usb.getControllerName());
    writer.write("\n");
    writer.setColor(.light_grey, .black);
    writer.write("  Devices: ");
    writer.setColor(.white, .black);
    writer.printInt(@truncate(usb.getDeviceCount()));
    writer.write("\n");
    var i: usize = 0;
    while (i < usb.getDeviceCount()) : (i += 1) {
        if (usb.getDevice(i)) |dev| {
            writer.setColor(.light_grey, .black);
            writer.write("    Port ");
            writer.printInt(@as(u32, dev.port));
            writer.write(": ");
            writer.setColor(.white, .black);
            writer.write(if (dev.speed == .low) "Low Speed" else "Full Speed");
            writer.write("\n");
        }
    }
    writer.setColor(.light_grey, .black);
}

pub fn cmdLspci() void {
    writer.write("\n");
    writer.setColor(.light_cyan, .black);
    writer.write("PCI Devices:\n");
    writer.setColor(.light_grey, .black);
    if (!pci_driver.isInitialized()) {
        pci_driver.init();
    }
    const count = pci_driver.getDeviceCount();
    if (count == 0) {
        writer.write("  No devices found\n");
        return;
    }
    var i: usize = 0;
    while (i < count) : (i += 1) {
        if (pci_driver.getDevice(i)) |dev| {
            writer.write("  ");
            writer.printInt(@as(u32, dev.bus));
            writer.write(":");
            writer.printInt(@as(u32, dev.slot));
            writer.write(".");
            writer.printInt(@as(u32, dev.func));
            writer.write(" ");
            writer.setColor(.white, .black);
            writer.write(pci_driver.getClassName(dev.class_code));
            writer.setColor(.light_grey, .black);
            writer.write(" [");
            writer.printHex16(dev.vendor_id);
            writer.write(":");
            writer.printHex16(dev.device_id);
            writer.write("]\n");
        }
    }
}
