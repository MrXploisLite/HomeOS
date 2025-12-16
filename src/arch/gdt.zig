// Home OS - Global Descriptor Table (GDT)
// Copyright © 2025 Romy Rianata - Home OS
// Phase 7: Added User Mode segments and TSS

const serial = @import("../drivers/serial.zig");

// GDT Entry structure (8 bytes)
pub const GdtEntry = packed struct {
    limit_low: u16,
    base_low: u16,
    base_middle: u8,
    access: u8,
    granularity: u8,
    base_high: u8,
};

// GDT Pointer structure (must be packed for LGDT instruction)
pub const GdtPtr = extern struct {
    limit: u16 align(1),
    base: u32 align(1),
};

// Access byte flags
const PRESENT: u8 = 0x80;
const DPL_RING0: u8 = 0x00;
const DPL_RING3: u8 = 0x60; // Ring 3 privilege level
const DESCRIPTOR: u8 = 0x10;
const EXECUTABLE: u8 = 0x08;
const RW: u8 = 0x02;
const ACCESSED: u8 = 0x01;

// TSS access byte: Present | Executable | Accessed (0x89)
const TSS_ACCESS: u8 = PRESENT | EXECUTABLE | ACCESSED;

// Granularity flags
const GRANULARITY_4K: u8 = 0x80;
const SIZE_32BIT: u8 = 0x40;

// Segment selectors
pub const KERNEL_CODE_SEL: u16 = 0x08;
pub const KERNEL_DATA_SEL: u16 = 0x10;
pub const USER_CODE_SEL: u16 = 0x18 | 3; // Ring 3 RPL
pub const USER_DATA_SEL: u16 = 0x20 | 3; // Ring 3 RPL
pub const TSS_SEL: u16 = 0x28;

// GDT with 6 entries: null, kernel code, kernel data, user code, user data, TSS
var gdt: [6]GdtEntry = [_]GdtEntry{
    // 0x00: Null descriptor
    GdtEntry{ .limit_low = 0, .base_low = 0, .base_middle = 0, .access = 0, .granularity = 0, .base_high = 0 },
    // 0x08: Kernel code segment (Ring 0)
    GdtEntry{
        .limit_low = 0xFFFF,
        .base_low = 0,
        .base_middle = 0,
        .access = PRESENT | DPL_RING0 | DESCRIPTOR | EXECUTABLE | RW,
        .granularity = GRANULARITY_4K | SIZE_32BIT | 0x0F,
        .base_high = 0,
    },
    // 0x10: Kernel data segment (Ring 0)
    GdtEntry{
        .limit_low = 0xFFFF,
        .base_low = 0,
        .base_middle = 0,
        .access = PRESENT | DPL_RING0 | DESCRIPTOR | RW,
        .granularity = GRANULARITY_4K | SIZE_32BIT | 0x0F,
        .base_high = 0,
    },
    // 0x18: User code segment (Ring 3)
    GdtEntry{
        .limit_low = 0xFFFF,
        .base_low = 0,
        .base_middle = 0,
        .access = PRESENT | DPL_RING3 | DESCRIPTOR | EXECUTABLE | RW,
        .granularity = GRANULARITY_4K | SIZE_32BIT | 0x0F,
        .base_high = 0,
    },
    // 0x20: User data segment (Ring 3)
    GdtEntry{
        .limit_low = 0xFFFF,
        .base_low = 0,
        .base_middle = 0,
        .access = PRESENT | DPL_RING3 | DESCRIPTOR | RW,
        .granularity = GRANULARITY_4K | SIZE_32BIT | 0x0F,
        .base_high = 0,
    },
    // 0x28: TSS descriptor (will be set up in setupTSS)
    GdtEntry{ .limit_low = 0, .base_low = 0, .base_middle = 0, .access = 0, .granularity = 0, .base_high = 0 },
};

var gdt_ptr: GdtPtr = undefined;

pub fn init() void {
    gdt_ptr.limit = @sizeOf(@TypeOf(gdt)) - 1;
    gdt_ptr.base = @intFromPtr(&gdt);

    // Load GDT
    asm volatile ("lgdt (%[ptr])"
        :
        : [ptr] "r" (&gdt_ptr),
    );

    // Reload segment registers
    asm volatile (
        \\mov $0x10, %%ax
        \\mov %%ax, %%ds
        \\mov %%ax, %%es
        \\mov %%ax, %%fs
        \\mov %%ax, %%gs
        \\mov %%ax, %%ss
    );

    // Far jump to reload CS
    asm volatile (
        \\ljmp $0x08, $1f
        \\1:
    );
}

/// Setup TSS descriptor in GDT
/// Must be called before loading TSS
pub fn setupTSS(base: u32, limit: u32) void {
    serial.write("GDT: Setting up TSS descriptor at 0x28\n");
    serial.write("  Base: 0x");
    serial.writeHex(base);
    serial.write(", Limit: 0x");
    serial.writeHex(limit);
    serial.write("\n");

    // TSS descriptor at index 5 (0x28)
    gdt[5] = GdtEntry{
        .limit_low = @truncate(limit & 0xFFFF),
        .base_low = @truncate(base & 0xFFFF),
        .base_middle = @truncate((base >> 16) & 0xFF),
        .access = TSS_ACCESS, // 0x89: Present | Executable | Accessed
        .granularity = @as(u8, @truncate((limit >> 16) & 0x0F)) | SIZE_32BIT,
        .base_high = @truncate((base >> 24) & 0xFF),
    };

    // Reload GDT with new TSS entry
    asm volatile ("lgdt (%[ptr])"
        :
        : [ptr] "r" (&gdt_ptr),
    );

    serial.write("GDT: TSS descriptor installed\n");
}
