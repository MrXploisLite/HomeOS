// Home OS - Built-in Programs
// Copyright © 2025 Romy Rianata - Home OS

const serial = @import("../drivers/serial.zig");

pub fn getProgram(name: []const u8) ?*const fn () callconv(.c) void {
    if (strEql(name, "hello")) return &programHello;
    if (strEql(name, "counter")) return &programCounter;
    if (strEql(name, "sysinfo")) return &programSysinfo;
    return null;
}

fn strEql(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    for (a, b) |ca, cb| {
        if (ca != cb) return false;
    }
    return true;
}

fn syscall_write(msg: []const u8) void {
    _ = asm volatile (
        \\int $0x80
        : [ret] "={eax}" (-> u32),
        : [syscall] "{eax}" (@as(u32, 1)),
          [fd] "{ebx}" (@as(u32, 1)),
          [buf] "{ecx}" (@intFromPtr(msg.ptr)),
          [count] "{edx}" (@as(u32, msg.len)),
    );
}

fn syscall_exit(status: u32) void {
    _ = asm volatile (
        \\int $0x80
        : [ret] "={eax}" (-> u32),
        : [syscall] "{eax}" (@as(u32, 0)),
          [status] "{ebx}" (status),
          [_] "{ecx}" (@as(u32, 0)),
          [__] "{edx}" (@as(u32, 0)),
    );
}

fn programHello() callconv(.c) void {
    syscall_write("Hello from user space!\n");
    syscall_write("This program runs in Ring 3.\n");
    syscall_exit(0);
}

fn programCounter() callconv(.c) void {
    syscall_write("Counting: 1 2 3 4 5\n");
    syscall_exit(0);
}

fn programSysinfo() callconv(.c) void {
    syscall_write("Home OS - System Information\n");
    syscall_write("Kernel: Ciko v0.1\n");
    syscall_write("Architecture: x86 (32-bit)\n");
    syscall_write("Mode: Protected Mode\n");
    syscall_exit(0);
}
