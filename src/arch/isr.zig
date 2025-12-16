// Home OS - Interrupt Service Routines
// Copyright © 2025 Romy Rianata - Home OS

const idt = @import("idt.zig");
const pic = @import("pic.zig");
const keyboard = @import("../drivers/keyboard.zig");
const serial = @import("../drivers/serial.zig");

// Exception names for debugging
const exception_names = [_][]const u8{
    "Division By Zero",
    "Debug",
    "Non Maskable Interrupt",
    "Breakpoint",
    "Overflow",
    "Bound Range Exceeded",
    "Invalid Opcode",
    "Device Not Available",
    "Double Fault",
    "Coprocessor Segment Overrun",
    "Invalid TSS",
    "Segment Not Present",
    "Stack-Segment Fault",
    "General Protection Fault",
    "Page Fault",
    "Reserved",
    "x87 FPU Error",
    "Alignment Check",
    "Machine Check",
    "SIMD Floating-Point",
    "Virtualization",
    "Control Protection",
};

// External ISR stubs from assembly (isr.s)
// CPU Exceptions (0-31)
extern fn isr0() void;
extern fn isr1() void;
extern fn isr2() void;
extern fn isr3() void;
extern fn isr4() void;
extern fn isr5() void;
extern fn isr6() void;
extern fn isr7() void;
extern fn isr8() void;
extern fn isr9() void;
extern fn isr10() void;
extern fn isr11() void;
extern fn isr12() void;
extern fn isr13() void;
extern fn isr14() void;
extern fn isr15() void;
extern fn isr16() void;
extern fn isr17() void;
extern fn isr18() void;
extern fn isr19() void;
extern fn isr20() void;
extern fn isr21() void;
extern fn isr22() void;
extern fn isr23() void;
extern fn isr24() void;
extern fn isr25() void;
extern fn isr26() void;
extern fn isr27() void;
extern fn isr28() void;
extern fn isr29() void;
extern fn isr30() void;
extern fn isr31() void;

// Hardware IRQs (32-47)
extern fn irq0() void;
extern fn irq1() void;
extern fn irq2() void;
extern fn irq3() void;
extern fn irq4() void;
extern fn irq5() void;
extern fn irq6() void;
extern fn irq7() void;
extern fn irq8() void;
extern fn irq9() void;
extern fn irq10() void;
extern fn irq11() void;
extern fn irq12() void;
extern fn irq13() void;
extern fn irq14() void;
extern fn irq15() void;

// Generic exception handler
var exception_handler: ?*const fn (u8) void = null;

pub fn setExceptionHandler(handler: *const fn (u8) void) void {
    exception_handler = handler;
}

// IRQ handlers
var irq_handlers: [16]?*const fn () void = [_]?*const fn () void{null} ** 16;

pub fn setIrqHandler(irq: u8, handler: *const fn () void) void {
    if (irq < 16) {
        irq_handlers[irq] = handler;
    }
}

// Export functions for C++ to use
export fn serial_write_cstr(str: [*:0]const u8) callconv(.c) void {
    var i: usize = 0;
    while (str[i] != 0) : (i += 1) {
        serial.writeChar(str[i]);
    }
}

export fn pic_sendEOI(irq: u8) callconv(.c) void {
    pic.sendEOI(irq);
}

export fn keyboard_handleInterrupt() callconv(.c) void {
    keyboard.handleInterrupt();
}

export fn pit_handleTick() callconv(.c) void {
    const pit = @import("../drivers/pit.zig");
    pit.handleTick();
}

export fn mouse_handleInterrupt() callconv(.c) void {
    const mouse = @import("../drivers/mouse.zig");
    mouse.handleInterrupt();
}

export fn audio_handleInterrupt() callconv(.c) void {
    const audio = @import("../drivers/audio.zig");
    audio.handleInterrupt();
}

export fn serial_write_int(value: u32) callconv(.c) void {
    serial.writeInt(value);
}

// C++ functions (defined in idt_setup.cpp)
extern fn cpp_setup_idt() callconv(.c) void;

pub fn init() void {
    cpp_setup_idt();
}

pub fn getExceptionName(num: u8) []const u8 {
    if (num < exception_names.len) {
        return exception_names[num];
    }
    return "Unknown Exception";
}
