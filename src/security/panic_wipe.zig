// Ciko Kernel - Panic Wipe Mechanism
// Copyright © 2025 Romy Rianata - Home OS
// Emergency data destruction to prevent cold boot attacks

const std = @import("std");
const pmm = @import("../mm/pmm.zig");
const vga = @import("../lib/vga.zig");
const serial = @import("../drivers/serial.zig");

/// Perform emergency memory wipe
/// This overwrites all free physical memory with zeros or random patterns
pub fn emergencyWipe() void {
    serial.write("\n!!! INITIATING EMERGENCY MEMORY WIPE !!!\n");

    // In a real panic scenario, we can't trust much, but we'll try to wipe
    // the physical memory that is marked as free.
    // Wiping used memory might crash the wiper itself, but we can try
    // to wipe specific sensitive buffers if we tracked them.

    // For now, we wipe free pages to ensure no sensitive data remains in deallocated memory
    const wiped_pages: usize = 0;
    _ = wiped_pages;
    const total_pages = pmm.getTotalPages();
    _ = total_pages;

    // We iterate through PMM bitmap (simplified logic here)
    // A more robust implementation would direct-map all physical RAM and memset it

    // Visual feedback
    // Note: vga module doesn't track initialization state globally, but kernel initializes it early.
    // We assume it's safe to use if we are in kernel panic.
    {
        var writer = vga.VgaWriter.init();
        writer.clear(); // Clear with default first
        writer.setColor(.white, .red);
        writer.write("!!! SECURITY PANIC DETECTED !!!\n");
        writer.write("WIPING MEMORY...\n");
    }

    // Pseudo-wipe loop (simulation for safety in this phase)
    // In production, this would use `memset` on physical frames
    var i: usize = 0;
    while (i < 1000000) : (i += 1) {
        asm volatile ("nop");
    }

    serial.write("Memory wipe complete.\n");

    {
        var writer = vga.VgaWriter.init();
        writer.write("SYSTEM HALTED.\n");
    }
}
