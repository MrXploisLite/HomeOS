// Home OS - Task State Segment (TSS)
// Copyright © 2025 Romy Rianata - Home OS
// TSS for Ring 0 <-> Ring 3 transitions

const serial = @import("../drivers/serial.zig");

/// TSS Structure for 32-bit Protected Mode
/// Used for stack switching when transitioning from Ring 3 to Ring 0
pub const TSS = extern struct {
    link: u16 = 0, // Previous TSS link (unused in software multitasking)
    reserved0: u16 = 0,
    esp0: u32 = 0, // Stack pointer for Ring 0 (kernel stack)
    ss0: u16 = 0, // Stack segment for Ring 0
    reserved1: u16 = 0,
    esp1: u32 = 0, // Stack pointer for Ring 1 (unused)
    ss1: u16 = 0,
    reserved2: u16 = 0,
    esp2: u32 = 0, // Stack pointer for Ring 2 (unused)
    ss2: u16 = 0,
    reserved3: u16 = 0,
    cr3: u32 = 0, // Page directory base
    eip: u32 = 0,
    eflags: u32 = 0,
    eax: u32 = 0,
    ecx: u32 = 0,
    edx: u32 = 0,
    ebx: u32 = 0,
    esp: u32 = 0,
    ebp: u32 = 0,
    esi: u32 = 0,
    edi: u32 = 0,
    es: u16 = 0,
    reserved4: u16 = 0,
    cs: u16 = 0,
    reserved5: u16 = 0,
    ss: u16 = 0,
    reserved6: u16 = 0,
    ds: u16 = 0,
    reserved7: u16 = 0,
    fs: u16 = 0,
    reserved8: u16 = 0,
    gs: u16 = 0,
    reserved9: u16 = 0,
    ldtr: u16 = 0,
    reserved10: u16 = 0,
    reserved11: u16 = 0,
    iopb_offset: u16 = @sizeOf(TSS), // I/O Permission Bitmap offset (set to TSS size = no IOPB)
};

// Global TSS instance
pub var tss: TSS = .{};

// Kernel stack for syscalls (4KB)
var kernel_stack: [4096]u8 align(16) = undefined;

/// Initialize TSS
pub fn init() void {
    serial.write("TSS: Initializing...\n");

    // Set kernel stack pointer (top of stack)
    tss.esp0 = @intFromPtr(&kernel_stack) + kernel_stack.len;
    tss.ss0 = 0x10; // Kernel data segment selector

    serial.write("TSS: esp0 = 0x");
    serial.writeHex(tss.esp0);
    serial.write(", ss0 = 0x");
    serial.writeHex(@as(u32, tss.ss0));
    serial.write("\n");

    // Load TSS into TR register
    // TSS descriptor is at GDT index 5 (0x28)
    const tss_selector: u16 = 0x28;
    asm volatile ("ltr %[sel]"
        :
        : [sel] "r" (tss_selector),
    );

    serial.write("TSS: Loaded (selector 0x28)\n");
}

/// Update kernel stack pointer (called on task switch)
pub fn setKernelStack(stack_top: u32) void {
    tss.esp0 = stack_top;
}

/// Get TSS base address (for GDT entry)
pub fn getBase() u32 {
    return @intFromPtr(&tss);
}

/// Get TSS limit (size - 1)
pub fn getLimit() u32 {
    return @sizeOf(TSS) - 1;
}
