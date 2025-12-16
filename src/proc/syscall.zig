// Home OS - System Call Handler
// Copyright © 2025 Romy Rianata - Home OS

const serial = @import("../drivers/serial.zig");
const kernel = @import("../kernel.zig");

pub const SYS_EXIT: u32 = 0;
pub const SYS_WRITE: u32 = 1;
pub const SYS_READ: u32 = 2;
pub const SYS_OPEN: u32 = 3;
pub const SYS_CLOSE: u32 = 4;
pub const SYS_GETPID: u32 = 5;
pub const SYS_YIELD: u32 = 6;
pub const SYS_SLEEP: u32 = 7;

pub const STDIN: u32 = 0;
pub const STDOUT: u32 = 1;
pub const STDERR: u32 = 2;

pub export var process_exited: u32 = 0;
pub var exit_status: u32 = 0;
pub export var kernel_return_esp: u32 = 0;
pub export var kernel_return_addr: u32 = 0;

export fn syscall_handler(eax: u32, ebx: u32, ecx: u32, edx: u32) callconv(.c) u32 {
    serial.write("Syscall: ");
    serial.writeInt(eax);
    serial.write("\n");

    return switch (eax) {
        SYS_EXIT => sysExit(ebx),
        SYS_WRITE => sysWrite(ebx, ecx, edx),
        SYS_READ => sysRead(ebx, ecx, edx),
        SYS_GETPID => sysGetpid(),
        SYS_YIELD => sysYield(),
        else => blk: {
            serial.write("Unknown syscall: ");
            serial.writeInt(eax);
            serial.write("\n");
            break :blk @as(u32, @bitCast(@as(i32, -1)));
        },
    };
}

fn sysExit(status: u32) u32 {
    serial.write("sys_exit: status = ");
    serial.writeInt(status);
    serial.write("\n");
    process_exited = 1;
    exit_status = status;
    serial.write("sys_exit: Returning to kernel...\n");
    return 0;
}

fn sysWrite(fd: u32, buf_ptr: u32, count: u32) u32 {
    if (count == 0) return 0;
    if (buf_ptr == 0) return @as(u32, @bitCast(@as(i32, -1)));
    const buf: [*]const u8 = @ptrFromInt(buf_ptr);
    if (fd == STDOUT or fd == STDERR) {
        var i: u32 = 0;
        while (i < count) : (i += 1) {
            kernel.writer.putChar(buf[i]);
        }
        return count;
    }
    return @as(u32, @bitCast(@as(i32, -1)));
}

fn sysRead(fd: u32, buf_ptr: u32, count: u32) u32 {
    _ = fd;
    _ = buf_ptr;
    _ = count;
    return @as(u32, @bitCast(@as(i32, -1)));
}

fn sysGetpid() u32 {
    return 1;
}

fn sysYield() u32 {
    const task = @import("task.zig");
    task.yield();
    return 0;
}

pub fn resetProcessState() void {
    process_exited = 0;
    exit_status = 0;
}
pub fn hasExited() bool {
    return process_exited != 0;
}

pub fn setKernelReturn(esp: u32, addr: u32) void {
    kernel_return_esp = esp;
    kernel_return_addr = addr;
    serial.write("Syscall: Kernel return set - ESP: 0x");
    serial.writeHex(esp);
    serial.write(", Addr: 0x");
    serial.writeHex(addr);
    serial.write("\n");
}

pub fn init() void {
    serial.write("Syscall: Initializing INT 0x80 handler\n");
    serial.write("Syscall: Ready\n");
}
