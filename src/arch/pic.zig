// Home OS - Programmable Interrupt Controller (PIC)
// Copyright © 2025 Romy Rianata - Home OS

const io = @import("io.zig");

// PIC ports
const PIC1_COMMAND: u16 = 0x20;
const PIC1_DATA: u16 = 0x21;
const PIC2_COMMAND: u16 = 0xA0;
const PIC2_DATA: u16 = 0xA1;

// PIC commands
const ICW1_INIT: u8 = 0x10;
const ICW1_ICW4: u8 = 0x01;
const ICW4_8086: u8 = 0x01;
const PIC_EOI: u8 = 0x20;

// Remap PIC to avoid conflicts with CPU exceptions (0-31)
// IRQ 0-7  -> INT 32-39
// IRQ 8-15 -> INT 40-47
pub const PIC1_OFFSET: u8 = 32;
pub const PIC2_OFFSET: u8 = 40;

pub fn init() void {
    // Save masks
    const mask1 = io.inb(PIC1_DATA);
    const mask2 = io.inb(PIC2_DATA);

    // Start initialization sequence (cascade mode)
    io.outb(PIC1_COMMAND, ICW1_INIT | ICW1_ICW4);
    io.wait();
    io.outb(PIC2_COMMAND, ICW1_INIT | ICW1_ICW4);
    io.wait();

    // Set vector offsets
    io.outb(PIC1_DATA, PIC1_OFFSET);
    io.wait();
    io.outb(PIC2_DATA, PIC2_OFFSET);
    io.wait();

    // Tell Master PIC there's a slave at IRQ2
    io.outb(PIC1_DATA, 4);
    io.wait();
    // Tell Slave PIC its cascade identity
    io.outb(PIC2_DATA, 2);
    io.wait();

    // Set 8086 mode
    io.outb(PIC1_DATA, ICW4_8086);
    io.wait();
    io.outb(PIC2_DATA, ICW4_8086);
    io.wait();

    // Restore masks (or set new ones)
    _ = mask1;
    _ = mask2;
    // Mask all IRQs initially - we'll enable them individually later
    io.outb(PIC1_DATA, 0xFF); // Mask all on master
    io.outb(PIC2_DATA, 0xFF); // Mask all on slave
}

// Send End of Interrupt signal
pub fn sendEOI(irq: u8) void {
    if (irq >= 8) {
        io.outb(PIC2_COMMAND, PIC_EOI);
    }
    io.outb(PIC1_COMMAND, PIC_EOI);
}

// Disable specific IRQ
pub fn setMask(irq: u8) void {
    const port: u16 = if (irq < 8) PIC1_DATA else PIC2_DATA;
    const irq_line: u3 = @truncate(irq & 7);
    const value = io.inb(port) | (@as(u8, 1) << irq_line);
    io.outb(port, value);
}

// Enable specific IRQ
pub fn clearMask(irq: u8) void {
    const port: u16 = if (irq < 8) PIC1_DATA else PIC2_DATA;
    const irq_line: u3 = @truncate(irq & 7);
    const value = io.inb(port) & ~(@as(u8, 1) << irq_line);
    io.outb(port, value);

    // For slave PIC IRQs (8-15), also enable cascade IRQ2 on master
    if (irq >= 8) {
        const master_value = io.inb(PIC1_DATA) & ~(@as(u8, 1) << 2);
        io.outb(PIC1_DATA, master_value);
    }
}
