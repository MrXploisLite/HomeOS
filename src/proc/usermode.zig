// Home OS - User Mode Support
// Copyright © 2025 Romy Rianata - Home OS

const serial = @import("../drivers/serial.zig");
const gdt = @import("../arch/gdt.zig");
const tss = @import("../arch/tss.zig");
const heap = @import("../mm/heap.zig");

pub const USER_STACK_SIZE: usize = 4096;

pub const UserContext = struct {
    edi: u32,
    esi: u32,
    ebp: u32,
    esp: u32,
    ebx: u32,
    edx: u32,
    ecx: u32,
    eax: u32,
    eip: u32,
    cs: u32,
    eflags: u32,
    user_esp: u32,
    user_ss: u32,
};

pub fn init() void {
    serial.write("UserMode: Initializing...\n");
    gdt.setupTSS(tss.getBase(), tss.getLimit());
    tss.init();
    serial.write("UserMode: Ready for Ring 3 execution\n");
}

extern fn enter_user_mode_asm(entry: u32, stack: u32, user_cs: u32, user_ds: u32) void;

pub fn enterUserMode(entry_point: u32, user_stack: u32) void {
    const syscall = @import("syscall.zig");
    serial.write("UserMode: Entering Ring 3\n");
    serial.write("  Entry: 0x");
    serial.writeHex(entry_point);
    serial.write("\n  Stack: 0x");
    serial.writeHex(user_stack);
    serial.write("\n");
    syscall.resetProcessState();
    enter_user_mode_asm(entry_point, user_stack, gdt.USER_CODE_SEL, gdt.USER_DATA_SEL);
    serial.write("UserMode: Returned from Ring 3\n");
}

pub fn allocUserStack() ?u32 {
    const stack = heap.alloc(USER_STACK_SIZE);
    if (stack == null) return null;
    return @intFromPtr(stack) + USER_STACK_SIZE;
}

pub fn testUserFunction() callconv(.c) void {
    const msg = "Hello from Ring 3!\n";
    _ = asm volatile (
        \\int $0x80
        : [ret] "={eax}" (-> u32),
        : [syscall] "{eax}" (@as(u32, 1)),
          [fd] "{ebx}" (@as(u32, 1)),
          [buf] "{ecx}" (@intFromPtr(msg.ptr)),
          [count] "{edx}" (@as(u32, msg.len)),
    );
    _ = asm volatile (
        \\int $0x80
        : [ret] "={eax}" (-> u32),
        : [syscall] "{eax}" (@as(u32, 0)),
          [status] "{ebx}" (@as(u32, 0)),
          [_] "{ecx}" (@as(u32, 0)),
          [__] "{edx}" (@as(u32, 0)),
    );
    while (true) {}
}
