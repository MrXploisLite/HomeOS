// Home OS - Command Executor (Unified)
// Copyright © 2025 Romy Rianata - Home OS
// Executes commands with output to any writer (VGA or GUI buffer)

const output = @import("../lib/output.zig");
const OutputWriter = output.OutputWriter;

// System imports
const pit = @import("../drivers/pit.zig");
const rtc = @import("../drivers/rtc.zig");
const ata = @import("../drivers/ata.zig");
const pmm = @import("../mm/pmm.zig");
const heap = @import("../mm/heap.zig");
const task = @import("../proc/task.zig");
const net = @import("../net/net.zig");
const ipc = @import("../proc/ipc.zig");
const fat32 = @import("../fs/fat32.zig");
const mbr = @import("../fs/mbr.zig");
const crypto = @import("../crypto/crypto.zig");
const pcspk = @import("../drivers/pcspk.zig");
const audio = @import("../drivers/audio.zig");

/// Execute a command and write output to the given writer
pub fn execute(cmd: []const u8, writer: OutputWriter) bool {
    if (strEql(cmd, "help")) {
        cmdHelp(writer);
        return true;
    } else if (strEql(cmd, "version") or strEql(cmd, "ver")) {
        cmdVersion(writer);
        return true;
    } else if (strEql(cmd, "about")) {
        cmdAbout(writer);
        return true;
    } else if (strEql(cmd, "uptime")) {
        cmdUptime(writer);
        return true;
    } else if (strEql(cmd, "mem")) {
        cmdMem(writer);
        return true;
    } else if (strEql(cmd, "date")) {
        cmdDate(writer);
        return true;
    } else if (strEql(cmd, "time")) {
        cmdTime(writer);
        return true;
    } else if (strEql(cmd, "disk")) {
        cmdDisk(writer);
        return true;
    } else if (strEql(cmd, "ps") or strEql(cmd, "tasks")) {
        cmdPs(writer);
        return true;
    } else if (strEql(cmd, "net") or strEql(cmd, "ifconfig")) {
        cmdNet(writer);
        return true;
    } else if (strEql(cmd, "arp")) {
        cmdArp(writer);
        return true;
    } else if (strEql(cmd, "firewall")) {
        cmdFirewall(writer);
        return true;
    } else if (strEql(cmd, "security")) {
        cmdSecurity(writer);
        return true;
    } else if (strEql(cmd, "crypto")) {
        cmdCrypto(writer);
        return true;
    } else if (strEql(cmd, "ipc")) {
        cmdIpc(writer);
        return true;
    } else if (strEql(cmd, "lsfat")) {
        cmdLsFat(writer);
        return true;
    } else if (strStartsWith(cmd, "catfat ")) {
        cmdCatFat(cmd[7..], writer);
        return true;
    } else if (strEql(cmd, "clear")) {
        writer.clear();
        return true;
    } else if (strEql(cmd, "pwd")) {
        cmdPwd(writer);
        return true;
    } else if (strEql(cmd, "whoami")) {
        cmdWhoami(writer);
        return true;
    } else if (strEql(cmd, "hostname")) {
        cmdHostname(writer);
        return true;
    } else if (strEql(cmd, "uname") or strEql(cmd, "uname -a")) {
        cmdUname(writer);
        return true;
    } else if (strStartsWith(cmd, "ping ")) {
        cmdPing(cmd[5..], writer);
        return true;
    } else if (strEql(cmd, "dhcp")) {
        cmdDhcp(writer);
        return true;
    } else if (strEql(cmd, "macrandom")) {
        cmdMacRandom(writer);
        return true;
    } else if (strEql(cmd, "beep")) {
        cmdBeep(writer);
        return true;
    } else if (strEql(cmd, "sound")) {
        cmdSound(writer);
        return true;
    } else if (strEql(cmd, "tor")) {
        cmdTor("", writer);
        return true;
    } else if (strStartsWith(cmd, "tor ")) {
        cmdTor(cmd[4..], writer);
        return true;
    } else if (strEql(cmd, "circuit")) {
        cmdCircuit(writer);
        return true;
    }
    return false; // Unknown command
}

fn cmdHelp(w: OutputWriter) void {
    w.write("Home OS Commands (Ciko Kernel):\n");
    w.write("  help      - Show this help\n");
    w.write("  version   - OS version\n");
    w.write("  about     - About Home OS\n");
    w.write("  uptime    - System uptime\n");
    w.write("  mem       - Memory info\n");
    w.write("  date/time - Date and time\n");
    w.write("  disk      - Disk info\n");
    w.write("  ps        - Process list\n");
    w.write("  net       - Network status\n");
    w.write("  ping <ip> - Ping IP address\n");
    w.write("  arp/dhcp  - ARP/DHCP status\n");
    w.write("  firewall  - Firewall status\n");
    w.write("  security  - Security status\n");
    w.write("  macrandom - Randomize MAC\n");
    w.write("  tor       - Tor status\n");
    w.write("  tor enable/disable/new\n");
    w.write("  circuit   - Circuit status\n");
    w.write("  crypto    - Crypto status\n");
    w.write("  ipc       - IPC status\n");
    w.write("  lsfat     - List FAT32 files\n");
    w.write("  catfat    - Read FAT32 file\n");
    w.write("  beep/sound - Audio\n");
    w.write("  clear     - Clear screen\n");
    w.write("  exit      - Exit terminal\n");
}

fn cmdVersion(w: OutputWriter) void {
    w.write("Home OS Version 0.31.0\n");
    w.write("Kernel: Ciko v0.1\n");
    w.write("Build: Phase 26 (Onion Routing)\n");
    w.write("Architecture: x86 (32-bit)\n");
}

fn cmdAbout(w: OutputWriter) void {
    w.write("================================\n");
    w.write("         HOME OS\n");
    w.write("  Copyright 2025 Romy Rianata\n");
    w.write("     Kernel: Ciko v0.1\n");
    w.write("================================\n");
    w.write("A privacy-focused hobby OS\n");
    w.write("Written in Zig, powered by Ciko Kernel\n");
}

fn cmdUptime(w: OutputWriter) void {
    w.write("Uptime: ");
    w.printInt(pit.getUptime());
    w.write(" seconds\n");
}

fn cmdMem(w: OutputWriter) void {
    w.write("Memory:\n");
    w.write("  Physical Pages: ");
    w.printInt(pmm.getFreePages());
    w.write("/");
    w.printInt(pmm.getTotalPages());
    w.write("\n");
    w.write("  Heap Free: ");
    w.printInt(heap.getFreeMemory() / 1024);
    w.write(" KB\n");
}

fn cmdDate(w: OutputWriter) void {
    const dt = rtc.getDateTime();
    w.write("Date: ");
    w.write(rtc.getWeekdayName(dt.weekday));
    w.write(", ");
    w.write(rtc.getMonthName(dt.month));
    w.write(" ");
    w.printInt(@as(u32, dt.day));
    w.write(", ");
    w.printInt(@as(u32, dt.year));
    w.write("\n");
}

fn cmdTime(w: OutputWriter) void {
    const dt = rtc.getDateTime();
    w.write("Time: ");
    if (dt.hour < 10) w.write("0");
    w.printInt(@as(u32, dt.hour));
    w.write(":");
    if (dt.minute < 10) w.write("0");
    w.printInt(@as(u32, dt.minute));
    w.write(":");
    if (dt.second < 10) w.write("0");
    w.printInt(@as(u32, dt.second));
    w.write("\n");
}

fn cmdDisk(w: OutputWriter) void {
    w.write("Disk:\n");
    if (ata.hasDrive()) {
        w.write("  ATA: ");
        w.printInt(@truncate(ata.getDiskSize() / 1024 / 1024));
        w.write(" MB\n");
        if (mbr.isValid()) {
            w.write("  Partitions: ");
            w.printInt(mbr.getPartitionCount());
            w.write("\n");
        }
    } else {
        w.write("  No disk detected\n");
    }
}

fn cmdPs(w: OutputWriter) void {
    w.write("Processes: ");
    w.printInt(task.getTaskCount());
    w.write(" running\n");
}

fn cmdNet(w: OutputWriter) void {
    w.write("Network:\n");
    if (net.hasNic()) {
        w.write("  NIC: RTL8139\n");
        w.write("  IP: ");
        const ip = net.getLocalIp();
        w.printInt(@as(u32, ip[0]));
        w.write(".");
        w.printInt(@as(u32, ip[1]));
        w.write(".");
        w.printInt(@as(u32, ip[2]));
        w.write(".");
        w.printInt(@as(u32, ip[3]));
        w.write("\n");
    } else {
        w.write("  No NIC detected\n");
    }
}

fn cmdArp(w: OutputWriter) void {
    w.write("ARP Cache: ");
    w.printInt(net.arp.getCacheCount());
    w.write(" entries\n");
}

fn cmdFirewall(w: OutputWriter) void {
    w.write("Firewall: ");
    if (net.firewall.isEnabled()) {
        w.write("ENABLED\n");
    } else {
        w.write("DISABLED\n");
    }
    w.write("  Rules: ");
    w.printInt(@truncate(net.firewall.getRuleCount()));
    w.write("\n");
    const stats = net.firewall.getStats();
    w.write("  Allowed: ");
    w.printInt(stats.allowed);
    w.write("\n  Denied: ");
    w.printInt(stats.denied);
    w.write("\n  Dropped: ");
    w.printInt(stats.dropped);
    w.write("\n");
}

fn cmdSecurity(w: OutputWriter) void {
    w.write("Security Status:\n");
    w.write("  Firewall: ");
    if (net.firewall.isEnabled()) {
        w.write("ON\n");
    } else {
        w.write("OFF\n");
    }
    w.write("  MAC Randomized: ");
    if (net.mac.isRandomized()) {
        w.write("YES\n");
    } else {
        w.write("NO\n");
    }
    w.write("  TLS: ");
    if (net.tls.isInitialized()) {
        w.write("Ready\n");
    } else {
        w.write("Not ready\n");
    }
    w.write("  Crypto: ");
    if (crypto.isInitialized()) {
        w.write("Ready\n");
    } else {
        w.write("Not ready\n");
    }
}

fn cmdCrypto(w: OutputWriter) void {
    w.write("Cryptography:\n");
    w.write("  RNG: ");
    if (crypto.rng.isInitialized()) {
        if (crypto.rng.hasHardwareRng()) {
            w.write("RDRAND\n");
        } else {
            w.write("Software PRNG\n");
        }
    } else {
        w.write("Not ready\n");
    }
    w.write("  SHA-256: Available\n");
    w.write("  Random: 0x");
    printHex(w, crypto.randomU32());
    w.write("\n");
}

fn cmdIpc(w: OutputWriter) void {
    w.write("IPC Resources:\n");
    w.write("  Pipes: ");
    w.printInt(ipc.getPipeCount());
    w.write("/");
    w.printInt(ipc.MAX_PIPES);
    w.write("\n  Queues: ");
    w.printInt(ipc.getQueueCount());
    w.write("/");
    w.printInt(ipc.MAX_QUEUES);
    w.write("\n  Semaphores: ");
    w.printInt(ipc.getSemCount());
    w.write("/");
    w.printInt(ipc.MAX_SEMAPHORES);
    w.write("\n");
}

fn cmdLsFat(w: OutputWriter) void {
    if (!fat32.isInitialized()) {
        w.write("FAT32 not initialized\n");
        return;
    }
    if (fat32.getFS()) |fs| {
        w.write("FAT32 Files:\n");
        fs.listRoot(&struct {
            fn callback(entry: *const fat32.DirEntry) void {
                _ = entry;
                // Can't easily pass writer here, simplified
            }
        }.callback);
        w.write("(use text shell for full listing)\n");
    } else {
        w.write("FAT32 error\n");
    }
}

fn cmdCatFat(filename: []const u8, w: OutputWriter) void {
    if (!fat32.isInitialized()) {
        w.write("FAT32 not initialized\n");
        return;
    }
    if (fat32.getFS()) |fs| {
        if (fs.findFile(fs.root_cluster, filename)) |entry| {
            if (entry.isDirectory()) {
                w.write("Error: is a directory\n");
            } else {
                var buf: [512]u8 = undefined;
                const bytes = fs.readFile(&entry, &buf, buf.len);
                if (bytes > 0) {
                    w.write(buf[0..bytes]);
                    if (buf[bytes - 1] != '\n') w.write("\n");
                } else {
                    w.write("(empty)\n");
                }
            }
        } else {
            w.write("File not found\n");
        }
    }
}

fn printHex(w: OutputWriter, val: u32) void {
    const hex = "0123456789ABCDEF";
    var buf: [8]u8 = undefined;
    var i: usize = 0;
    var v = val;
    while (i < 8) : (i += 1) {
        buf[7 - i] = hex[v & 0xF];
        v >>= 4;
    }
    w.write(&buf);
}

fn strEql(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    for (a, b) |ca, cb| {
        if (ca != cb) return false;
    }
    return true;
}

fn cmdPwd(w: OutputWriter) void {
    w.write("/\n");
}

fn cmdWhoami(w: OutputWriter) void {
    w.write("root\n");
}

fn cmdHostname(w: OutputWriter) void {
    w.write("homeos\n");
}

fn cmdUname(w: OutputWriter) void {
    w.write("HomeOS 0.31.0 i386 Ciko Kernel v0.1\n");
}

fn strStartsWith(str: []const u8, prefix: []const u8) bool {
    if (str.len < prefix.len) return false;
    for (prefix, 0..) |c, i| {
        if (str[i] != c) return false;
    }
    return true;
}

fn cmdPing(args: []const u8, w: OutputWriter) void {
    if (!net.isInitialized() or !net.hasNic()) {
        w.write("Network not available\n");
        return;
    }
    // Trim whitespace
    var start: usize = 0;
    var end: usize = args.len;
    while (start < end and args[start] == ' ') start += 1;
    while (end > start and args[end - 1] == ' ') end -= 1;
    if (start >= end) {
        w.write("Usage: ping <ip>\n");
        return;
    }
    const ip_str = args[start..end];
    if (net.ipv4.parseIp(ip_str)) |dest_ip| {
        w.write("PING ");
        printIp(w, dest_ip);
        w.write("...\n");
        if (net.ping(dest_ip)) {
            w.write("Ping sent!\n");
        } else {
            w.write("Ping failed (ARP needed)\n");
            _ = net.sendArpRequest(dest_ip);
            w.write("ARP request sent, try again\n");
        }
    } else {
        w.write("Invalid IP: ");
        w.write(ip_str);
        w.write("\n");
    }
}

fn cmdDhcp(w: OutputWriter) void {
    if (!net.isInitialized() or !net.hasNic()) {
        w.write("Network not available\n");
        return;
    }
    w.write("DHCP Status: ");
    const state = net.dhcp.getState();
    switch (state) {
        .idle => w.write("IDLE\n"),
        .discovering => w.write("DISCOVERING\n"),
        .requesting => w.write("REQUESTING\n"),
        .bound => {
            w.write("BOUND\n");
            const cfg = net.dhcp.getConfig();
            w.write("  IP: ");
            printIp(w, cfg.ip_address);
            w.write("\n  Gateway: ");
            printIp(w, cfg.gateway);
            w.write("\n  DNS: ");
            printIp(w, cfg.dns_server);
            w.write("\n");
        },
        .renewing => w.write("RENEWING\n"),
        .rebinding => w.write("REBINDING\n"),
    }
}

fn cmdMacRandom(w: OutputWriter) void {
    w.write("Current MAC: ");
    printMac(w, net.mac.getCurrentMac());
    w.write("\n");
    if (net.mac.randomize()) {
        w.write("New MAC: ");
        printMac(w, net.mac.getCurrentMac());
        w.write("\n");
    } else {
        w.write("Failed to randomize\n");
    }
}

fn cmdBeep(w: OutputWriter) void {
    pcspk.beep(1000, 200);
    w.write("Beep!\n");
}

fn cmdSound(w: OutputWriter) void {
    w.write("Audio Status:\n");
    w.write("  PC Speaker: Available\n");
    w.write("  Sound Blaster: ");
    if (audio.hasSoundBlaster()) {
        w.write("Detected\n");
    } else {
        w.write("Not detected\n");
    }
}

fn printIp(w: OutputWriter, ip: [4]u8) void {
    w.printInt(@as(u32, ip[0]));
    w.write(".");
    w.printInt(@as(u32, ip[1]));
    w.write(".");
    w.printInt(@as(u32, ip[2]));
    w.write(".");
    w.printInt(@as(u32, ip[3]));
}

fn printMac(w: OutputWriter, mac_addr: [6]u8) void {
    const hex_chars = "0123456789ABCDEF";
    var buf: [17]u8 = undefined;
    var idx: usize = 0;
    for (mac_addr, 0..) |b, i| {
        if (i > 0) {
            buf[idx] = ':';
            idx += 1;
        }
        buf[idx] = hex_chars[b >> 4];
        buf[idx + 1] = hex_chars[b & 0x0F];
        idx += 2;
    }
    w.write(buf[0..17]);
}

fn cmdTor(args: []const u8, w: OutputWriter) void {
    // Trim whitespace
    var start: usize = 0;
    var end: usize = args.len;
    while (start < end and args[start] == ' ') start += 1;
    while (end > start and args[end - 1] == ' ') end -= 1;

    if (start >= end) {
        // Show status
        showTorStatus(w);
        return;
    }

    const subcmd = args[start..end];

    if (strEql(subcmd, "enable") or strEql(subcmd, "on")) {
        w.write("Enabling Tor...\n");
        if (net.tor.enable()) {
            w.write("Tor enabled and connected!\n");
        } else {
            w.write("Failed to enable Tor\n");
        }
    } else if (strEql(subcmd, "disable") or strEql(subcmd, "off")) {
        net.tor.disable();
        w.write("Tor disabled\n");
    } else if (strEql(subcmd, "newcircuit") or strEql(subcmd, "new")) {
        if (net.tor.newCircuit()) {
            w.write("New circuit created!\n");
        } else {
            w.write("Failed to create circuit\n");
        }
    } else if (strEql(subcmd, "status")) {
        showTorStatus(w);
    } else {
        w.write("Usage: tor [enable|disable|new|status]\n");
    }
}

fn showTorStatus(w: OutputWriter) void {
    w.write("Tor Onion Router:\n");
    w.write("  Status: ");
    switch (net.tor.getStatus()) {
        .disabled => w.write("DISABLED\n"),
        .bootstrapping => {
            w.write("BOOTSTRAPPING (");
            w.printInt(net.tor.getBootstrapProgress());
            w.write("%)\n");
        },
        .connected => w.write("CONNECTED\n"),
        .error_state => w.write("ERROR\n"),
    }

    w.write("  Nodes: ");
    w.printInt(@truncate(net.tor.getNodeCount()));
    w.write(" (");
    w.printInt(@truncate(net.tor.getGuardCount()));
    w.write(" guard, ");
    w.printInt(@truncate(net.tor.getExitCount()));
    w.write(" exit)\n");

    w.write("  SOCKS5: ");
    if (net.tor.isSocksEnabled()) {
        w.write("Enabled (port ");
        w.printInt(net.tor.getSocksPort());
        w.write(")\n");
    } else {
        w.write("Disabled\n");
    }

    // Show circuit if connected
    if (net.tor.getCurrentCircuit()) |c| {
        w.write("  Circuit: #");
        w.printInt(c.id);
        w.write(" (");
        w.printInt(c.hop_count);
        w.write(" hops)\n");

        // Show path
        var i: u8 = 0;
        while (i < c.hop_count) : (i += 1) {
            const hop = &c.hops[i];
            w.write("    ");
            w.printInt(i + 1);
            w.write(". ");
            switch (hop.node_type) {
                .entry => w.write("[GUARD] "),
                .middle => w.write("[RELAY] "),
                .exit => w.write("[EXIT]  "),
            }
            printIp(w, hop.ip);
            w.write("\n");
        }
    }
}

fn cmdCircuit(w: OutputWriter) void {
    w.write("Circuit Status:\n");
    w.write("  Active: ");
    w.printInt(net.circuit.getActiveCircuitCount());
    w.write("/");
    w.printInt(net.circuit.MAX_CIRCUITS);
    w.write("\n");
    w.write("  Ready: ");
    w.printInt(net.circuit.getReadyCircuitCount());
    w.write("\n");

    // List circuits
    var found: bool = false;
    var i: usize = 0;
    while (i < net.circuit.MAX_CIRCUITS) : (i += 1) {
        if (net.circuit.getCircuit(i)) |c| {
            found = true;
            w.write("  #");
            w.printInt(c.id);
            w.write(" - ");
            w.write(net.circuit.getStateName(c.state));
            w.write(" (");
            w.printInt(c.hop_count);
            w.write(" hops)\n");
        }
    }

    if (!found) {
        w.write("  (no circuits)\n");
    }
}
