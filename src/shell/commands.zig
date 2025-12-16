// Home OS - Shell Commands Dispatcher
// Copyright © 2025 Romy Rianata - Home OS
// Main command dispatcher - delegates to specialized command modules

const vga = @import("../lib/vga.zig");
const VgaWriter = vga.VgaWriter;
const vfs = @import("../fs/vfs.zig");

// Command modules
const cmd_file = @import("cmd_file.zig");
const cmd_fat32 = @import("cmd_fat32.zig");
const cmd_system = @import("cmd_system.zig");
const cmd_network = @import("cmd_network.zig");
const cmd_audio = @import("cmd_audio.zig");
const cmd_gui = @import("cmd_gui.zig");
const cmd_power = @import("cmd_power.zig");

// Global state references
var writer: *VgaWriter = undefined;

/// Initialize all command modules
pub fn init(w: *VgaWriter, vfs_ptr: *vfs.VFS) void {
    writer = w;
    cmd_file.init(w, vfs_ptr);
    cmd_fat32.init(w);
    cmd_system.init(w);
    cmd_network.init(w);
    cmd_audio.init(w);
    cmd_gui.init(w);
    cmd_power.init(w);
}

/// Execute a command
pub fn execute(cmd: []const u8) void {
    // File commands (RAM)
    if (memEql(cmd, "ls")) {
        cmd_file.cmdLs();
    } else if (memStartsWith(cmd, "cat ")) {
        cmd_file.cmdCat(cmd[4..]);
    } else if (memStartsWith(cmd, "touch ")) {
        cmd_file.cmdTouch(cmd[6..]);
    } else if (memStartsWith(cmd, "rm ")) {
        cmd_file.cmdRm(cmd[3..]);
    } else if (memStartsWith(cmd, "write ")) {
        cmd_file.cmdWrite(cmd[6..]);
    } else if (memEql(cmd, "echo")) {
        cmd_file.cmdEcho("");
    } else if (memStartsWith(cmd, "echo ")) {
        cmd_file.cmdEcho(cmd[5..]);
    }
    // FAT32 commands
    else if (memEql(cmd, "lsfat")) {
        cmd_fat32.cmdLsFat();
    } else if (memStartsWith(cmd, "catfat ")) {
        cmd_fat32.cmdCatFat(cmd[7..]);
    } else if (memStartsWith(cmd, "mkfat ")) {
        cmd_fat32.cmdMkFat(cmd[6..]);
    } else if (memStartsWith(cmd, "writefat ")) {
        cmd_fat32.cmdWriteFat(cmd[9..]);
    } else if (memStartsWith(cmd, "rmfat ")) {
        cmd_fat32.cmdRmFat(cmd[6..]);
    }
    // System commands
    else if (memEql(cmd, "help")) {
        cmd_system.cmdHelp();
    } else if (memEql(cmd, "mem")) {
        cmd_system.cmdMem();
    } else if (memEql(cmd, "tasks") or memEql(cmd, "ps")) {
        cmd_system.cmdPs();
    } else if (memEql(cmd, "uptime")) {
        cmd_system.cmdUptime();
    } else if (memEql(cmd, "clear")) {
        cmd_system.cmdClear();
    } else if (memEql(cmd, "disk")) {
        cmd_system.cmdDisk();
    } else if (memEql(cmd, "date")) {
        cmd_system.cmdDate();
    } else if (memEql(cmd, "time")) {
        cmd_system.cmdTime();
    } else if (memEql(cmd, "version") or memEql(cmd, "ver")) {
        cmd_system.cmdVersion();
    } else if (memEql(cmd, "about")) {
        cmd_system.cmdAbout();
    } else if (memEql(cmd, "crypto")) {
        cmd_system.cmdCrypto();
    }
    // Network commands
    else if (memEql(cmd, "net") or memEql(cmd, "ifconfig")) {
        cmd_network.cmdNet();
    } else if (memStartsWith(cmd, "ping ")) {
        cmd_network.cmdPing(cmd[5..]);
    } else if (memEql(cmd, "arp")) {
        cmd_network.cmdArp();
    } else if (memEql(cmd, "ipc")) {
        cmd_network.cmdIpc();
    } else if (memStartsWith(cmd, "pipe ")) {
        cmd_network.cmdPipe(cmd[5..]);
    } else if (memEql(cmd, "dhcp")) {
        cmd_network.cmdDhcp();
    } else if (memStartsWith(cmd, "nslookup ")) {
        cmd_network.cmdNslookup(cmd[9..]);
    } else if (memEql(cmd, "firewall")) {
        cmd_network.cmdFirewall();
    } else if (memEql(cmd, "security")) {
        cmd_network.cmdSecurity();
    } else if (memEql(cmd, "macrandom")) {
        cmd_network.cmdMacRandom();
    } else if (memEql(cmd, "tor")) {
        cmd_network.cmdTor("");
    } else if (memStartsWith(cmd, "tor ")) {
        cmd_network.cmdTor(cmd[4..]);
    } else if (memEql(cmd, "circuit")) {
        cmd_network.cmdCircuit();
    }
    // Audio & USB commands
    else if (memEql(cmd, "beep")) {
        cmd_audio.cmdBeep();
    } else if (memEql(cmd, "sound")) {
        cmd_audio.cmdSound();
    } else if (memStartsWith(cmd, "play ")) {
        cmd_audio.cmdPlay(cmd[5..]);
    } else if (memEql(cmd, "usb")) {
        cmd_audio.cmdUsb();
    } else if (memEql(cmd, "lspci")) {
        cmd_audio.cmdLspci();
    }
    // GUI & Program commands
    else if (memEql(cmd, "gui")) {
        cmd_gui.cmdGui();
    } else if (memEql(cmd, "gfxtest")) {
        cmd_gui.cmdGfxTest();
    } else if (memStartsWith(cmd, "run ")) {
        cmd_gui.cmdRun(cmd[4..]);
    } else if (memEql(cmd, "programs")) {
        cmd_gui.cmdPrograms();
    }
    // Power commands
    else if (memEql(cmd, "reboot")) {
        cmd_power.cmdReboot();
    } else if (memEql(cmd, "shutdown")) {
        cmd_power.cmdShutdown();
    }
    // Unknown command
    else {
        writer.write("\n");
        writer.setColor(.light_red, .black);
        writer.write("Unknown command: ");
        writer.write(cmd);
        writer.write("\n");
        writer.setColor(.light_grey, .black);
        writer.write("Type 'help' for available commands\n");
    }
    writer.setColor(.light_green, .black);
    writer.write("\n> ");
}

// String utilities (exported for other modules)
pub fn memEql(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    for (a, b) |ca, cb| {
        if (ca != cb) return false;
    }
    return true;
}

pub fn memStartsWith(str: []const u8, prefix: []const u8) bool {
    if (str.len < prefix.len) return false;
    for (prefix, 0..) |c, i| {
        if (str[i] != c) return false;
    }
    return true;
}
