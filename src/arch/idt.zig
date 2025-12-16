// Home OS - Interrupt Descriptor Table (IDT)
// Copyright © 2025 Romy Rianata - Home OS

// IDT Entry structure (8 bytes)
pub const IdtEntry = packed struct {
    offset_low: u16,
    selector: u16,
    zero: u8 = 0,
    type_attr: u8,
    offset_high: u16,
};

// IDT Pointer structure (must be packed for LIDT instruction)
pub const IdtPtr = extern struct {
    limit: u16 align(1),
    base: u32 align(1),
};

// Type attributes
const PRESENT: u8 = 0x80;
const DPL_RING0: u8 = 0x00;
const INTERRUPT_GATE: u8 = 0x0E;
const TRAP_GATE: u8 = 0x0F;

// 256 IDT entries - must be 16-byte aligned and initialized to zero
var idt: [256]IdtEntry align(16) = [_]IdtEntry{.{
    .offset_low = 0,
    .selector = 0,
    .zero = 0,
    .type_attr = 0,
    .offset_high = 0,
}} ** 256;

var idt_ptr: IdtPtr = undefined;

// Set an IDT entry by address
pub fn setGateAddr(num: u8, addr: u32, selector: u16, flags: u8) void {
    idt[num] = IdtEntry{
        .offset_low = @truncate(addr & 0xFFFF),
        .selector = selector,
        .zero = 0,
        .type_attr = flags,
        .offset_high = @truncate((addr >> 16) & 0xFFFF),
    };
}

// Set an IDT entry by function pointer
pub fn setGate(num: u8, handler: *const fn () callconv(.c) void, selector: u16, flags: u8) void {
    const addr = @intFromPtr(handler);
    setGateAddr(num, addr, selector, flags);
}

// Initialize IDT structure (clear entries, set pointer)
pub fn init() void {
    // Clear all entries
    for (0..256) |i| {
        idt[i] = IdtEntry{
            .offset_low = 0,
            .selector = 0,
            .zero = 0,
            .type_attr = 0,
            .offset_high = 0,
        };
    }

    // Set up IDT pointer
    idt_ptr.limit = @sizeOf(@TypeOf(idt)) - 1;
    idt_ptr.base = @intFromPtr(&idt);
}

// Load IDT into CPU (call AFTER populating gates!)
pub fn load() void {
    asm volatile ("lidt (%[idt_ptr])"
        :
        : [idt_ptr] "r" (&idt_ptr),
    );
}

// Enable interrupts
pub fn enableInterrupts() void {
    asm volatile ("sti");
}

// Disable interrupts
pub fn disableInterrupts() void {
    asm volatile ("cli");
}
