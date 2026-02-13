// Ciko Kernel (Home OS) - Phase 17 (Reorganized)
// Copyright © 2025 Romy Rianata - Home OS
// Main kernel entry point and initialization

const std = @import("std");

// Architecture
const gdt = @import("arch/gdt.zig");
const idt = @import("arch/idt.zig");
const isr = @import("arch/isr.zig");
const pic = @import("arch/pic.zig");
const tss = @import("arch/tss.zig");
const io = @import("arch/io.zig");

// Memory Management
const paging = @import("mm/paging.zig");
const pmm = @import("mm/pmm.zig");
const vmm = @import("mm/vmm.zig");
const heap = @import("mm/heap.zig");

// Drivers
const serial = @import("drivers/serial.zig");
const keyboard = @import("drivers/keyboard.zig");
const pit = @import("drivers/pit.zig");
const ata = @import("drivers/ata.zig");
const audio = @import("drivers/audio.zig");
const pci_driver = @import("drivers/pci.zig");
const usb = @import("drivers/usb.zig");
const rtc = @import("drivers/rtc.zig");

// Filesystem
const vfs = @import("fs/vfs.zig");
const ramdisk = @import("fs/ramdisk.zig");
const fat32 = @import("fs/fat32.zig");
const mbr = @import("fs/mbr.zig");

// Process Management
const task = @import("proc/task.zig");
const syscall = @import("proc/syscall.zig");
const usermode = @import("proc/usermode.zig");
const ipc = @import("proc/ipc.zig");

// Networking
const net = @import("net/net.zig");

// Security
const panic_wipe = @import("security/panic_wipe.zig");
const audit = @import("security/audit.zig");

// Cryptography
const crypto = @import("crypto/crypto.zig");

// Shell & VGA
const shell = @import("shell/shell.zig");
const vga = @import("lib/vga.zig");

// ============================================================================
// MULTIBOOT1 HEADER
// ============================================================================
const MULTIBOOT_MAGIC: u32 = 0x1BADB002;
const MULTIBOOT_ALIGN: u32 = 1 << 0;
const MULTIBOOT_MEMINFO: u32 = 1 << 1;
const MULTIBOOT_FLAGS: u32 = MULTIBOOT_ALIGN | MULTIBOOT_MEMINFO;
const MULTIBOOT_CHECKSUM: u32 = 0 -% (MULTIBOOT_MAGIC +% MULTIBOOT_FLAGS);

const MultibootHeader = extern struct {
    magic: u32 = MULTIBOOT_MAGIC,
    flags: u32 = MULTIBOOT_FLAGS,
    checksum: u32 = MULTIBOOT_CHECKSUM,
};

export const multiboot_header: MultibootHeader linksection(".multiboot") = .{};

const MultibootInfo = extern struct {
    flags: u32,
    mem_lower: u32,
    mem_upper: u32,
    boot_device: u32,
    cmdline: u32,
    mods_count: u32,
    mods_addr: u32,
    syms: [4]u32,
    mmap_length: u32,
    mmap_addr: u32,
};

// ============================================================================
// BASIC UTILITY FUNCTIONS
// ============================================================================

pub fn memcpy(dest: [*]u8, src: [*]const u8, n: usize) [*]u8 {
    var i: usize = 0;
    while (i < n) : (i += 1) {
        dest[i] = src[i];
    }
    return dest;
}

pub fn memset(dest: [*]u8, val: u8, n: usize) [*]u8 {
    var i: usize = 0;
    while (i < n) : (i += 1) {
        dest[i] = val;
    }
    return dest;
}

// Re-export VgaWriter for compatibility
pub const VgaWriter = vga.VgaWriter;
pub const VgaColor = vga.VgaColor;
pub var writer: VgaWriter = undefined;

// ============================================================================
// GLOBAL STATE
// ============================================================================

var global_ramdisk: ramdisk.Ramdisk = undefined;
var global_vfs: vfs.VFS = undefined;
var fs_initialized: bool = false;

const initrd_data = @embedFile("initrd.tar");

fn createSampleFiles() void {
    serial.write("Creating sample files...\n");
    _ = global_vfs.write("hello.txt", "Hello from Home OS (Ciko Kernel)!\nThis is a sample file.\n") catch {};
    _ = global_vfs.write("readme.txt", "Home OS (Ciko Kernel) - Phase 6 Filesystem\nRead/Write support enabled!\n") catch {};
    _ = global_vfs.write("test.txt", "Test file content.\n") catch {};
    serial.write("Sample files created\n");
}

// ============================================================================
// PANIC & HALT
// ============================================================================

pub fn panic(msg: []const u8, _: ?*@import("std").builtin.StackTrace, _: ?usize) noreturn {
    writer.setColor(.light_red, .black);
    writer.write("\n!!! KERNEL PANIC: ");
    writer.write(msg);

    // Trigger security wipe
    panic_wipe.emergencyWipe();

    halt();
}

fn halt() noreturn {
    asm volatile ("cli");
    while (true) asm volatile ("hlt");
}

// Kernel main task (idle loop)
fn kernelMainTask() void {
    while (true) {
        asm volatile ("hlt");
    }
}

// ============================================================================
// KERNEL ENTRY POINT
// ============================================================================

export var kernel_stack: [16 * 1024]u8 align(16) linksection(".bss") = undefined;
export var multiboot_info_ptr: u32 = 0;

export fn _start() callconv(.naked) noreturn {
    asm volatile (
        \\mov %%ebx, multiboot_info_ptr
        \\lea kernel_stack + 16384, %%esp
        \\push %%ebx
        \\call kernelMain
        \\1: hlt
        \\jmp 1b
    );
    while (true) {}
}

export fn kernelMain(mb_info_addr: u32) callconv(.c) noreturn {
    serial.init();
    serial.write("\n=== Home OS Serial Debug Log ===\n");

    writer = VgaWriter.init();
    writer.clear();

    // Banner
    writer.setColor(.light_cyan, .black);
    writer.write("================================================================================\n");
    writer.setColor(.light_green, .black);
    writer.write("                                   HOME OS\n");
    writer.setColor(.light_grey, .black);
    writer.write("                        Copyright (C) 2025 Romy Rianata\n");
    writer.write("                             Kernel: Ciko v0.1\n");
    writer.setColor(.light_cyan, .black);
    writer.write("================================================================================\n\n");

    writer.setColor(.yellow, .black);
    writer.write("Hello Home OS (Ciko Kernel) by Romy Rianata\n\n");
    writer.setColor(.light_grey, .black);
    writer.write("Architecture: x86 (32-bit protected mode)\n\n");

    // Initialize core systems
    initSystem("GDT", gdt.init);
    initSystem("IDT", idt.init);
    initSystem("ISR", isr.init);
    initSystem("Paging", paging.init);
    initSystem("PMM", pmm.init);
    initSystem("VMM", vmm.init);
    initSystemNoArg("PIC", initPic);
    initSystem("PIT Timer", pit.init);

    // Memory info
    if (mb_info_addr != 0) {
        const mb_info: *const MultibootInfo = @ptrFromInt(mb_info_addr);
        if (mb_info.flags & 1 != 0) {
            writer.setColor(.light_grey, .black);
            writer.write("Physical Memory: ");
            writer.setColor(.white, .black);
            writer.printSize(mb_info.mem_lower + mb_info.mem_upper);
            writer.write("\n");
        }
    }

    initSystem("Heap", heap.init);
    initDisk();
    initFilesystem();
    initProcesses();
    initIpc();
    initNetwork();
    initTor();
    initAudio();
    initSystem("USB", initUsb); // Fixed: using initSystem wrapper
    initRtc();
    initSystem("Audit Log", audit.init); // Initialize Audit first to log subsequent events
    initCrypto();

    // Log successful boot
    audit.log(.INFO, .SYSTEM_BOOT, "Kernel initialization complete");

    // All systems initialized
    writer.setColor(.light_green, .black);
    writer.write("[OK] All systems initialized!\n");
    writer.setColor(.light_grey, .black);
    writer.write("Enabling interrupts... ");
    asm volatile ("sti");
    writer.setColor(.green, .black);
    writer.write("[OK]\n\n");

    // Initialize shell (for terminal app)
    shell.init(&writer, &global_vfs);

    // Boot directly to GUI Desktop
    writer.setColor(.light_cyan, .black);
    writer.write("Starting Home OS Desktop...\n");

    // Import and start GUI
    const desktop = @import("gui/desktop.zig");
    desktop.startDesktop();

    // If GUI exits, fall back to shell
    writer.setColor(.light_cyan, .black);
    writer.write("================================================================================\n");
    writer.setColor(.light_green, .black);
    writer.write("Home OS Shell (Recovery Mode) - Ciko Kernel\n");
    writer.setColor(.light_grey, .black);
    writer.write("Type 'gui' to restart desktop, 'help' for commands\n");
    writer.setColor(.light_cyan, .black);
    writer.write("================================================================================\n");
    writer.setColor(.light_green, .black);
    writer.write("\n> ");

    // Fallback shell loop
    while (true) {
        if (keyboard.hasKey()) {
            if (keyboard.getKey()) |key| {
                shell.processChar(key);
            }
        }
        asm volatile ("hlt");
    }
}

// ============================================================================
// INITIALIZATION HELPERS
// ============================================================================

fn initSystem(name: []const u8, init_fn: fn () void) void {
    writer.setColor(.light_grey, .black);
    writer.write("Initializing ");
    writer.write(name);
    writer.write("... ");
    init_fn();
    writer.setColor(.green, .black);
    writer.write("[OK]\n");
}

fn initSystemNoArg(name: []const u8, init_fn: fn () void) void {
    writer.setColor(.light_grey, .black);
    writer.write("Initializing ");
    writer.write(name);
    writer.write("... ");
    init_fn();
    writer.setColor(.green, .black);
    writer.write("[OK]\n");
}

fn initPic() void {
    pic.init();
    pic.clearMask(0);
    pic.clearMask(1);
}

fn initDisk() void {
    writer.setColor(.light_grey, .black);
    writer.write("Initializing ATA... ");
    ata.init();
    if (ata.hasDrive()) {
        writer.setColor(.green, .black);
        writer.write("[OK]\n");
        writer.setColor(.light_grey, .black);
        writer.write("Disk: ");
        writer.setColor(.white, .black);
        writer.printInt(@truncate(ata.getDiskSize() / 1024 / 1024));
        writer.write(" MB\n");

        writer.setColor(.light_grey, .black);
        writer.write("Reading MBR... ");
        mbr.init();
        if (mbr.isValid()) {
            writer.setColor(.green, .black);
            writer.write("[OK]\n");
            if (mbr.findFAT32() != null) {
                writer.setColor(.light_grey, .black);
                writer.write("Initializing FAT32... ");
                if (fat32.initFS()) {
                    writer.setColor(.green, .black);
                    writer.write("[OK]\n");
                } else {
                    writer.setColor(.yellow, .black);
                    writer.write("[FAILED]\n");
                }
            }
        } else {
            writer.setColor(.yellow, .black);
            writer.write("[NO MBR]\n");
        }
    } else {
        writer.setColor(.yellow, .black);
        writer.write("[NO DISK]\n");
    }
}

fn initFilesystem() void {
    writer.setColor(.light_grey, .black);
    writer.write("Initializing Filesystem... ");
    global_ramdisk = ramdisk.Ramdisk.init(64) catch {
        writer.setColor(.red, .black);
        writer.write("[FAILED]\n");
        halt();
    };
    global_vfs = vfs.VFS.init(&global_ramdisk);
    createSampleFiles();
    fs_initialized = true;
    writer.setColor(.green, .black);
    writer.write("[OK]\n");
}

fn initProcesses() void {
    writer.setColor(.light_grey, .black);
    writer.write("Initializing Task System... ");
    task.init();
    _ = task.createKernelTask("kernel", &kernelMainTask);
    writer.setColor(.green, .black);
    writer.write("[OK]\n");

    writer.setColor(.light_grey, .black);
    writer.write("Initializing User Mode... ");
    usermode.init();
    syscall.init();
    writer.setColor(.green, .black);
    writer.write("[OK]\n");
}

fn initIpc() void {
    writer.setColor(.light_grey, .black);
    writer.write("Initializing IPC... ");
    ipc.init();
    writer.setColor(.green, .black);
    writer.write("[OK]\n");
}

fn initNetwork() void {
    writer.setColor(.light_grey, .black);
    writer.write("Initializing Network... ");
    _ = net.init();
    writer.setColor(.green, .black);
    writer.write("[OK]\n");
}

fn initTor() void {
    writer.setColor(.light_grey, .black);
    writer.write("Initializing Tor... ");
    net.tor.init();
    writer.setColor(.green, .black);
    writer.write("[OK]\n");
}

fn initAudio() void {
    writer.setColor(.light_grey, .black);
    writer.write("Initializing Audio... ");
    _ = audio.init();
    writer.setColor(.green, .black);
    writer.write("[OK]\n");
}

fn initUsb() void {
    writer.setColor(.light_grey, .black);
    writer.write("Initializing USB... ");
    if (!pci_driver.isInitialized()) {
        pci_driver.init();
    }
    _ = usb.init();
    if (usb.isInitialized()) {
        writer.setColor(.green, .black);
        writer.write("[OK]\n");
    } else {
        writer.setColor(.yellow, .black);
        writer.write("[NO USB]\n");
    }
}

fn initRtc() void {
    writer.setColor(.light_grey, .black);
    writer.write("Initializing RTC... ");
    rtc.init();
    writer.setColor(.green, .black);
    writer.write("[OK]\n");
}

fn initCrypto() void {
    writer.setColor(.light_grey, .black);
    writer.write("Initializing Crypto... ");
    if (crypto.init()) {
        writer.setColor(.green, .black);
        writer.write("[OK]\n");
    } else {
        writer.setColor(.yellow, .black);
        writer.write("[WARN]\n");
    }
}
