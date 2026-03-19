// Home OS - System Commands
// Copyright © 2025 Romy Rianata - Home OS
// System commands: mem, ps, uptime, clear, disk, date, time, version, about, help

const vga = @import("../lib/vga.zig");
const VgaWriter = vga.VgaWriter;
const pit = @import("../drivers/pit.zig");
const ata = @import("../drivers/ata.zig");
const rtc = @import("../drivers/rtc.zig");
const mbr = @import("../fs/mbr.zig");
const pmm = @import("../mm/pmm.zig");
const heap = @import("../mm/heap.zig");
const task = @import("../proc/task.zig");
const crypto = @import("../crypto/crypto.zig");

var writer: *VgaWriter = undefined;

pub fn init(w: *VgaWriter) void {
    writer = w;
}

pub fn cmdMem() void {
    writer.write("\n");
    writer.setColor(.light_cyan, .black);
    writer.write("Memory Information:\n");
    writer.setColor(.yellow, .black);
    writer.write("\n  Physical Memory (PMM):\n");
    writer.setColor(.light_grey, .black);
    writer.write("    Total Pages: ");
    writer.printInt(pmm.getTotalPages());
    writer.write(" (");
    writer.printSize(pmm.getTotalMemory() / 1024);
    writer.write(")\n");
    writer.write("    Free Pages:  ");
    writer.printInt(pmm.getFreePages());
    writer.write(" (");
    writer.printSize(pmm.getFreeMemory() / 1024);
    writer.write(")\n");
    writer.setColor(.yellow, .black);
    writer.write("\n  Kernel Heap:\n");
    writer.setColor(.light_grey, .black);
    writer.write("    Total: ");
    writer.printSize(heap.getTotalSize() / 1024);
    writer.write("\n");
    writer.write("    Free:  ");
    writer.printSize(heap.getFreeMemory() / 1024);
    writer.write("\n");
}

pub fn cmdPs() void {
    writer.write("\n");
    writer.setColor(.light_cyan, .black);
    writer.write("Process List:\n");
    writer.setColor(.light_grey, .black);
    writer.write("  PID  STATE  RING  PAGES  TICKS  NAME\n");
    writer.write("  ---  -----  ----  -----  -----  ----\n");
    task.listTasks(&printTaskInfo);
    writer.write("\n  Total: ");
    writer.printInt(task.getTaskCount());
    writer.write(" process(es)\n");
}

fn printTaskInfo(t: *const task.Task) void {
    writer.write("  ");
    writer.printInt(t.id);
    writer.write("  ");
    switch (t.state) {
        .ready => {
            writer.setColor(.yellow, .black);
            writer.write("READY  ");
        },
        .running => {
            writer.setColor(.light_green, .black);
            writer.write("RUN    ");
        },
        .blocked => {
            writer.setColor(.light_red, .black);
            writer.write("BLOCK  ");
        },
        .terminated => {
            writer.setColor(.dark_grey, .black);
            writer.write("TERM   ");
        },
    }
    writer.setColor(.light_cyan, .black);
    writer.write("R");
    writer.printInt(@as(u32, t.ring));
    writer.write("  ");
    writer.setColor(.light_magenta, .black);
    if (t.pages_allocated < 10) writer.write(" ");
    if (t.pages_allocated < 100) writer.write(" ");
    writer.printInt(t.pages_allocated);
    writer.write("  ");
    writer.setColor(.light_grey, .black);
    if (t.ticks < 10) writer.write(" ");
    if (t.ticks < 100) writer.write(" ");
    writer.printInt(t.ticks);
    writer.write("  ");
    writer.setColor(.white, .black);
    writer.write(task.getTaskName(t));
    writer.setColor(.light_grey, .black);
    writer.write("\n");
}

pub fn cmdUptime() void {
    writer.write("\n");
    writer.setColor(.light_grey, .black);
    writer.write("System uptime: ");
    writer.setColor(.white, .black);
    writer.printInt(pit.getUptime());
    writer.write(" seconds\n");
}

pub fn cmdClear() void {
    writer.clear();
    writer.setColor(.light_cyan, .black);
    writer.write("Home OS Shell\n");
    writer.setColor(.light_grey, .black);
    writer.write("Type 'help' for commands\n\n");
}

pub fn cmdDisk() void {
    writer.write("\n");
    writer.setColor(.light_cyan, .black);
    writer.write("Disk Information:\n");
    if (!ata.hasDrive()) {
        writer.setColor(.yellow, .black);
        writer.write("  No disk detected\n");
        writer.setColor(.light_grey, .black);
        return;
    }
    const drive = ata.getPrimaryMaster();
    writer.setColor(.yellow, .black);
    writer.write("\n  Primary Master:\n");
    writer.setColor(.light_grey, .black);
    if (drive.present) {
        if (drive.is_ata) {
            writer.write("    Type: ATA Hard Disk\n");
            writer.write("    Size: ");
            writer.setColor(.white, .black);
            writer.printInt(@truncate(drive.sectors / 2048));
            writer.write(" MB\n");
            writer.setColor(.light_grey, .black);
        } else if (drive.is_atapi) {
            writer.write("    Type: ATAPI (CD-ROM)\n");
        }
    } else {
        writer.write("    Not present\n");
    }
    if (mbr.isValid()) {
        writer.setColor(.yellow, .black);
        writer.write("\n  Partitions:\n");
        writer.setColor(.light_grey, .black);
        var i: u8 = 0;
        while (i < 4) : (i += 1) {
            if (mbr.getPartition(i)) |part| {
                writer.write("    ");
                writer.printInt(@as(u32, i + 1));
                writer.write(": ");
                writer.setColor(.white, .black);
                writer.write(mbr.getTypeName(part.system_id));
                writer.setColor(.light_grey, .black);
                writer.write(" - ");
                writer.printInt(part.getSizeMB());
                writer.write(" MB");
                if (part.isBootable()) {
                    writer.setColor(.light_green, .black);
                    writer.write(" [BOOT]");
                    writer.setColor(.light_grey, .black);
                }
                writer.write("\n");
            }
        }
    }
}

pub fn cmdDate() void {
    writer.write("\n");
    const dt = rtc.getDateTime();
    writer.setColor(.light_cyan, .black);
    writer.write("Date: ");
    writer.setColor(.white, .black);
    writer.write(rtc.getWeekdayName(dt.weekday));
    writer.write(", ");
    writer.write(rtc.getMonthName(dt.month));
    writer.write(" ");
    writer.printInt(@as(u32, dt.day));
    writer.write(", ");
    writer.printInt(@as(u32, dt.year));
    writer.write("\n");
    writer.setColor(.light_grey, .black);
}

pub fn cmdTime() void {
    writer.write("\n");
    const dt = rtc.getDateTime();
    writer.setColor(.light_cyan, .black);
    writer.write("Time: ");
    writer.setColor(.white, .black);
    if (dt.hour < 10) writer.write("0");
    writer.printInt(@as(u32, dt.hour));
    writer.write(":");
    if (dt.minute < 10) writer.write("0");
    writer.printInt(@as(u32, dt.minute));
    writer.write(":");
    if (dt.second < 10) writer.write("0");
    writer.printInt(@as(u32, dt.second));
    writer.write("\n");
    writer.setColor(.light_grey, .black);
}

pub fn cmdVersion() void {
    writer.write("\n");
    writer.setColor(.light_cyan, .black);
    writer.write("Home OS (Ciko Kernel)\n");
    writer.setColor(.white, .black);
    writer.write("Version 0.33.0\n");
    writer.setColor(.light_grey, .black);
    writer.write("Kernel: Ciko v0.1\n");
    writer.write("Build: Phase 25.0 (New Features)\n");
    writer.write("Architecture: x86 (32-bit)\n");
}

pub fn cmdCrypto() void {
    writer.write("\n");
    writer.setColor(.light_cyan, .black);
    writer.write("Cryptography Status:\n\n");

    // RNG Status
    writer.setColor(.yellow, .black);
    writer.write("  Random Number Generator:\n");
    writer.setColor(.light_grey, .black);
    writer.write("    Status: ");
    if (crypto.rng.isInitialized()) {
        writer.setColor(.light_green, .black);
        writer.write("Ready\n");
    } else {
        writer.setColor(.light_red, .black);
        writer.write("Not initialized\n");
    }
    writer.setColor(.light_grey, .black);
    writer.write("    Hardware RNG: ");
    if (crypto.rng.hasHardwareRng()) {
        writer.setColor(.light_green, .black);
        writer.write("RDRAND available\n");
    } else {
        writer.setColor(.yellow, .black);
        writer.write("Software PRNG (xorshift128+)\n");
    }

    // SHA-256 Status
    writer.setColor(.yellow, .black);
    writer.write("\n  Hash Algorithms:\n");
    writer.setColor(.light_grey, .black);
    writer.write("    SHA-256: ");
    writer.setColor(.light_green, .black);
    writer.write("Available\n");

    // Demo: Generate random number
    writer.setColor(.yellow, .black);
    writer.write("\n  Demo - Random Numbers:\n");
    writer.setColor(.light_grey, .black);
    writer.write("    Random u32: ");
    writer.setColor(.white, .black);
    writer.printHex(crypto.randomU32());
    writer.write("\n");
    writer.setColor(.light_grey, .black);
    writer.write("    Random u32: ");
    writer.setColor(.white, .black);
    writer.printHex(crypto.randomU32());
    writer.write("\n");

    // Demo: SHA-256 hash
    writer.setColor(.yellow, .black);
    writer.write("\n  Demo - SHA-256 Hash:\n");
    writer.setColor(.light_grey, .black);
    writer.write("    Input: \"HomeOS\"\n");
    writer.write("    Hash:  ");
    writer.setColor(.white, .black);
    const hash = crypto.hashSha256("HomeOS");
    var hex_buf: [64]u8 = undefined;
    _ = crypto.sha256.hashToHex(hash, &hex_buf);
    writer.write(hex_buf[0..64]);
    writer.write("\n");
    writer.setColor(.light_grey, .black);
}

pub fn cmdAbout() void {
    writer.write("\n");
    writer.setColor(.light_cyan, .black);
    writer.write("================================================================================\n");
    writer.setColor(.light_green, .black);
    writer.write("                                   HOME OS\n");
    writer.setColor(.light_grey, .black);
    writer.write("                        Copyright (C) 2025 Romy Rianata\n");
    writer.write("                             Kernel: Ciko v0.1\n");
    writer.setColor(.light_cyan, .black);
    writer.write("================================================================================\n\n");
    writer.setColor(.white, .black);
    writer.write("A hobby operating system written in Zig, powered by Ciko Kernel.\n\n");
    writer.setColor(.light_grey, .black);
    writer.write("Features:\n");
    writer.write("  - 32-bit x86 protected mode\n");
    writer.write("  - Virtual memory with paging\n");
    writer.write("  - FAT32 filesystem support\n");
    writer.write("  - Networking (RTL8139, TCP/IP stack)\n");
    writer.write("  - GUI with window manager\n");
    writer.write("  - Audio (PC Speaker, Sound Blaster 16)\n");
    writer.write("  - USB support (UHCI)\n");
    writer.write("\nType 'help' for available commands.\n");
}

pub fn cmdHelp() void {
    writer.write("\n");
    writer.setColor(.light_green, .black);
    writer.write("Home OS Shell Commands:\n");
    writer.setColor(.light_cyan, .black);
    writer.write("\nFile Operations (RAM):\n");
    writer.setColor(.light_grey, .black);
    writer.write("  ls, cat, touch, rm, write, echo\n");
    writer.setColor(.light_cyan, .black);
    writer.write("\nFAT32 Disk Operations:\n");
    writer.setColor(.light_grey, .black);
    writer.write("  lsfat, catfat, mkfat, writefat, rmfat\n");
    writer.setColor(.light_cyan, .black);
    writer.write("\nNetwork:\n");
    writer.setColor(.light_grey, .black);
    writer.write("  net, ping <ip>, arp, dhcp, nslookup <host>\n");
    writer.setColor(.light_cyan, .black);
    writer.write("\nGraphics:\n");
    writer.setColor(.light_grey, .black);
    writer.write("  gui, gfxtest\n");
    writer.setColor(.light_cyan, .black);
    writer.write("\nAudio:\n");
    writer.setColor(.light_grey, .black);
    writer.write("  beep, sound, play <demo|startup|error>\n");
    writer.setColor(.light_cyan, .black);
    writer.write("\nUSB:\n");
    writer.setColor(.light_grey, .black);
    writer.write("  usb, lspci\n");
    writer.setColor(.light_cyan, .black);
    writer.write("\nProcess Management:\n");
    writer.setColor(.light_grey, .black);
    writer.write("  ps, run, programs\n");
    writer.setColor(.light_cyan, .black);
    writer.write("\nSecurity:\n");
    writer.setColor(.light_grey, .black);
    writer.write("  crypto, firewall, security, macrandom\n");
    writer.setColor(.light_cyan, .black);
    writer.write("\nOnion Routing:\n");
    writer.setColor(.light_grey, .black);
    writer.write("  tor [enable|disable|new], circuit\n");
    writer.setColor(.light_cyan, .black);
    writer.write("\nSystem:\n");
    writer.setColor(.light_grey, .black);
    writer.write("  disk, mem, uptime, date, time, clear, help, ipc\n");
    writer.write("  reboot, shutdown, version, about\n");
}
