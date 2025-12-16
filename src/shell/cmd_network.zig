// Home OS - Network Commands
// Copyright © 2025 Romy Rianata - Home OS
// Network commands: net, ping, arp, dhcp, nslookup, ipc, pipe

const vga = @import("../lib/vga.zig");
const VgaWriter = vga.VgaWriter;
const serial = @import("../drivers/serial.zig");
const net = @import("../net/net.zig");
const ipc = @import("../proc/ipc.zig");

var writer: *VgaWriter = undefined;

pub fn init(w: *VgaWriter) void {
    writer = w;
}

// String comparison helper
fn memEql(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    for (a, b) |ca, cb| {
        if (ca != cb) return false;
    }
    return true;
}

pub fn cmdNet() void {
    writer.write("\n");
    writer.setColor(.light_cyan, .black);
    writer.write("Network Status:\n");
    writer.setColor(.light_grey, .black);
    writer.write("  NIC: ");
    if (net.hasNic()) {
        writer.setColor(.light_green, .black);
        writer.write("RTL8139 (Link UP)\n");
        writer.setColor(.light_grey, .black);
        writer.write("  MAC: ");
        writer.setColor(.white, .black);
        printMac(net.getLocalMac());
        writer.write("\n");
    } else {
        writer.setColor(.yellow, .black);
        writer.write("Not detected\n");
    }
    writer.setColor(.light_grey, .black);
    writer.write("  Status: ");
    if (net.isInitialized()) {
        writer.setColor(.light_green, .black);
        writer.write("Initialized\n");
        writer.setColor(.light_grey, .black);
        writer.write("  IP: ");
        writer.setColor(.white, .black);
        printIp(net.getLocalIp());
        writer.write("\n");
    } else {
        writer.setColor(.yellow, .black);
        writer.write("Not initialized\n");
    }
    writer.setColor(.light_grey, .black);
}

pub fn cmdPing(args: []const u8) void {
    writer.write("\n");
    if (!net.isInitialized()) {
        writer.setColor(.yellow, .black);
        writer.write("Network not initialized\n");
        writer.setColor(.light_grey, .black);
        return;
    }
    if (!net.hasNic()) {
        writer.setColor(.yellow, .black);
        writer.write("No network card detected\n");
        writer.setColor(.light_grey, .black);
        return;
    }
    var start: usize = 0;
    var end: usize = args.len;
    while (start < end and args[start] == ' ') start += 1;
    while (end > start and args[end - 1] == ' ') end -= 1;
    if (start >= end) {
        writer.setColor(.light_red, .black);
        writer.write("Usage: ping <ip_address>\n");
        writer.write("Example: ping 10.0.2.2\n");
        writer.setColor(.light_grey, .black);
        return;
    }
    const ip_str = args[start..end];
    const dest_ip = net.ipv4.parseIp(ip_str);
    if (dest_ip == null) {
        writer.setColor(.light_red, .black);
        writer.write("Invalid IP address: ");
        writer.write(ip_str);
        writer.write("\n");
        writer.setColor(.light_grey, .black);
        return;
    }
    writer.setColor(.light_cyan, .black);
    writer.write("PING ");
    printIp(dest_ip.?);
    writer.write("...\n");
    writer.setColor(.light_grey, .black);
    serial.write("PING: Sending to ");
    net.ipv4.printIp(dest_ip.?);
    serial.write("\n");
    if (net.ping(dest_ip.?)) {
        writer.setColor(.light_green, .black);
        writer.write("Ping sent!\n");
        serial.write("PING: Packet sent successfully\n");
    } else {
        writer.setColor(.yellow, .black);
        writer.write("Ping failed (need ARP first)\n");
        serial.write("PING: Failed - sending ARP request\n");
        if (net.sendArpRequest(dest_ip.?)) {
            writer.write("ARP request sent, try ping again\n");
            serial.write("PING: ARP request sent\n");
        }
    }
    writer.setColor(.light_grey, .black);
}

pub fn cmdArp() void {
    writer.write("\n");
    writer.setColor(.light_cyan, .black);
    writer.write("ARP Cache:\n");
    writer.setColor(.light_grey, .black);
    const count = net.arp.getCacheCount();
    if (count == 0) {
        writer.write("  (empty)\n");
    } else {
        writer.write("  Entries: ");
        writer.printInt(count);
        writer.write("\n");
    }
}

pub fn cmdIpc() void {
    writer.write("\n");
    writer.setColor(.light_cyan, .black);
    writer.write("IPC Status:\n");
    writer.setColor(.yellow, .black);
    writer.write("\n  Resources:\n");
    writer.setColor(.light_grey, .black);
    writer.write("    Pipes:          ");
    writer.setColor(.white, .black);
    writer.printInt(ipc.getPipeCount());
    writer.write("/");
    writer.printInt(ipc.MAX_PIPES);
    writer.setColor(.light_grey, .black);
    writer.write("\n    Message Queues: ");
    writer.setColor(.white, .black);
    writer.printInt(ipc.getQueueCount());
    writer.write("/");
    writer.printInt(ipc.MAX_QUEUES);
    writer.setColor(.light_grey, .black);
    writer.write("\n    Shared Memory:  ");
    writer.setColor(.white, .black);
    writer.printInt(ipc.getShmCount());
    writer.write("/");
    writer.printInt(ipc.MAX_SHM_REGIONS);
    writer.setColor(.light_grey, .black);
    writer.write("\n    Semaphores:     ");
    writer.setColor(.white, .black);
    writer.printInt(ipc.getSemCount());
    writer.write("/");
    writer.printInt(ipc.MAX_SEMAPHORES);
    writer.setColor(.light_grey, .black);
    writer.write("\n    Mutexes:        ");
    writer.setColor(.white, .black);
    writer.printInt(ipc.getMutexCount());
    writer.write("/");
    writer.printInt(ipc.MAX_MUTEXES);
    writer.setColor(.light_grey, .black);
    writer.write("\n");
}

pub fn cmdPipe(args: []const u8) void {
    writer.write("\n");
    if (memEql(args, "create")) {
        if (ipc.createPipe()) |pipe_id| {
            writer.setColor(.light_green, .black);
            writer.write("Created pipe ");
            writer.printInt(pipe_id);
            writer.write("\n");
        } else {
            writer.setColor(.light_red, .black);
            writer.write("Error: Could not create pipe\n");
        }
        writer.setColor(.light_grey, .black);
    } else {
        writer.setColor(.light_grey, .black);
        writer.write("Pipe commands:\n");
        writer.write("  pipe create - Create new pipe\n");
    }
}

pub fn cmdDhcp() void {
    writer.write("\n");
    writer.setColor(.light_cyan, .black);
    writer.write("DHCP Client:\n");
    writer.setColor(.light_grey, .black);
    if (!net.isInitialized()) {
        writer.setColor(.yellow, .black);
        writer.write("  Network not initialized\n");
        writer.setColor(.light_grey, .black);
        return;
    }
    if (!net.hasNic()) {
        writer.setColor(.yellow, .black);
        writer.write("  No network card detected\n");
        writer.setColor(.light_grey, .black);
        return;
    }
    const dhcp_state = net.dhcp.getState();
    writer.write("  State: ");
    writer.setColor(.white, .black);
    switch (dhcp_state) {
        .idle => writer.write("IDLE"),
        .discovering => writer.write("DISCOVERING"),
        .requesting => writer.write("REQUESTING"),
        .bound => writer.write("BOUND"),
        .renewing => writer.write("RENEWING"),
        .rebinding => writer.write("REBINDING"),
    }
    writer.write("\n");
    writer.setColor(.light_grey, .black);
    if (net.dhcp.isBound()) {
        const config = net.dhcp.getConfig();
        writer.write("  IP: ");
        writer.setColor(.white, .black);
        printIp(config.ip_address);
        writer.write("\n");
        writer.setColor(.light_grey, .black);
        writer.write("  Subnet: ");
        writer.setColor(.white, .black);
        printIp(config.subnet_mask);
        writer.write("\n");
        writer.setColor(.light_grey, .black);
        writer.write("  Gateway: ");
        writer.setColor(.white, .black);
        printIp(config.gateway);
        writer.write("\n");
        writer.setColor(.light_grey, .black);
        writer.write("  DNS: ");
        writer.setColor(.white, .black);
        printIp(config.dns_server);
        writer.write("\n");
        writer.setColor(.light_grey, .black);
    } else {
        writer.write("\n  Sending DHCP Discover...\n");
        if (net.sendDhcpDiscover()) {
            writer.setColor(.light_green, .black);
            writer.write("  DHCP Discover sent!\n");
            writer.setColor(.light_grey, .black);
            writer.write("  Waiting for DHCP Offer...\n");
        } else {
            writer.setColor(.light_red, .black);
            writer.write("  Failed to send DHCP Discover\n");
        }
    }
    writer.setColor(.light_grey, .black);
}

pub fn cmdNslookup(args: []const u8) void {
    writer.write("\n");
    writer.setColor(.light_cyan, .black);
    writer.write("DNS Lookup:\n");
    writer.setColor(.light_grey, .black);
    if (!net.isInitialized()) {
        writer.setColor(.yellow, .black);
        writer.write("  Network not initialized\n");
        writer.setColor(.light_grey, .black);
        return;
    }
    var start: usize = 0;
    var end: usize = args.len;
    while (start < end and args[start] == ' ') start += 1;
    while (end > start and args[end - 1] == ' ') end -= 1;
    if (start >= end) {
        writer.setColor(.light_red, .black);
        writer.write("Usage: nslookup <hostname>\n");
        writer.write("Example: nslookup google.com\n");
        writer.setColor(.light_grey, .black);
        return;
    }
    const hostname = args[start..end];
    writer.write("  Querying: ");
    writer.setColor(.white, .black);
    writer.write(hostname);
    writer.write("\n");
    writer.setColor(.light_grey, .black);
    if (net.dns.cacheLookup(hostname)) |ip| {
        writer.write("  Result (cached): ");
        writer.setColor(.light_green, .black);
        printIp(ip);
        writer.write("\n");
        writer.setColor(.light_grey, .black);
        return;
    }
    writer.write("  DNS Server: ");
    writer.setColor(.white, .black);
    const config = net.getConfig();
    printIp(config.dns_server);
    writer.write("\n");
    writer.setColor(.light_grey, .black);
    if (net.sendDnsQuery(hostname)) {
        writer.setColor(.light_green, .black);
        writer.write("  DNS query sent!\n");
        writer.setColor(.light_grey, .black);
        writer.write("  Waiting for response...\n");
    } else {
        writer.setColor(.light_red, .black);
        writer.write("  Failed to send DNS query\n");
    }
    writer.setColor(.light_grey, .black);
}

// Helper functions
pub fn printIp(ip: [4]u8) void {
    writer.printInt(@as(u32, ip[0]));
    writer.write(".");
    writer.printInt(@as(u32, ip[1]));
    writer.write(".");
    writer.printInt(@as(u32, ip[2]));
    writer.write(".");
    writer.printInt(@as(u32, ip[3]));
}

pub fn printMac(mac_addr: [6]u8) void {
    const hex = "0123456789ABCDEF";
    var i: usize = 0;
    while (i < 6) : (i += 1) {
        if (i > 0) writer.write(":");
        writer.putChar(hex[mac_addr[i] >> 4]);
        writer.putChar(hex[mac_addr[i] & 0x0F]);
    }
}

pub fn cmdFirewall() void {
    writer.write("\n");
    writer.setColor(.light_cyan, .black);
    writer.write("Firewall Status:\n");
    writer.setColor(.light_grey, .black);

    writer.write("  Status: ");
    if (net.firewall.isEnabled()) {
        writer.setColor(.light_green, .black);
        writer.write("ENABLED\n");
    } else {
        writer.setColor(.yellow, .black);
        writer.write("DISABLED\n");
    }
    writer.setColor(.light_grey, .black);

    writer.write("  Rules: ");
    writer.setColor(.white, .black);
    writer.printInt(@truncate(net.firewall.getRuleCount()));
    writer.write("\n");
    writer.setColor(.light_grey, .black);

    const stats = net.firewall.getStats();
    writer.setColor(.yellow, .black);
    writer.write("\n  Statistics:\n");
    writer.setColor(.light_grey, .black);
    writer.write("    Allowed: ");
    writer.setColor(.light_green, .black);
    writer.printInt(stats.allowed);
    writer.write("\n");
    writer.setColor(.light_grey, .black);
    writer.write("    Denied:  ");
    writer.setColor(.light_red, .black);
    writer.printInt(stats.denied);
    writer.write("\n");
    writer.setColor(.light_grey, .black);
    writer.write("    Dropped: ");
    writer.setColor(.yellow, .black);
    writer.printInt(stats.dropped);
    writer.write("\n");
    writer.setColor(.light_grey, .black);

    writer.setColor(.yellow, .black);
    writer.write("\n  Active Rules:\n");
    writer.setColor(.light_grey, .black);

    var i: usize = 0;
    while (i < net.firewall.getRuleCount()) : (i += 1) {
        if (net.firewall.getRule(i)) |rule| {
            writer.write("    ");
            writer.printInt(@truncate(i + 1));
            writer.write(". ");

            switch (rule.action) {
                .allow => {
                    writer.setColor(.light_green, .black);
                    writer.write("ALLOW ");
                },
                .deny => {
                    writer.setColor(.light_red, .black);
                    writer.write("DENY  ");
                },
                .drop => {
                    writer.setColor(.yellow, .black);
                    writer.write("DROP  ");
                },
            }
            writer.setColor(.light_grey, .black);

            const desc = net.firewall.getDescription(rule);
            if (desc.len > 0) {
                writer.write(desc);
            }
            writer.write("\n");
        }
    }
}

pub fn cmdSecurity() void {
    writer.write("\n");
    writer.setColor(.light_cyan, .black);
    writer.write("Network Security Status:\n");
    writer.setColor(.light_grey, .black);

    // Firewall
    writer.setColor(.yellow, .black);
    writer.write("\n  Firewall:\n");
    writer.setColor(.light_grey, .black);
    writer.write("    Status: ");
    if (net.firewall.isEnabled()) {
        writer.setColor(.light_green, .black);
        writer.write("Enabled\n");
    } else {
        writer.setColor(.light_red, .black);
        writer.write("Disabled\n");
    }
    writer.setColor(.light_grey, .black);
    writer.write("    Rules:  ");
    writer.setColor(.white, .black);
    writer.printInt(@truncate(net.firewall.getRuleCount()));
    writer.write("\n");

    // MAC Randomization
    writer.setColor(.yellow, .black);
    writer.write("\n  MAC Address:\n");
    writer.setColor(.light_grey, .black);
    writer.write("    Current: ");
    writer.setColor(.white, .black);
    printMac(net.mac.getCurrentMac());
    writer.write("\n");
    writer.setColor(.light_grey, .black);
    writer.write("    Randomized: ");
    if (net.mac.isRandomized()) {
        writer.setColor(.light_green, .black);
        writer.write("Yes\n");
    } else {
        writer.setColor(.yellow, .black);
        writer.write("No (original)\n");
    }
    writer.setColor(.light_grey, .black);

    // TLS
    writer.setColor(.yellow, .black);
    writer.write("\n  TLS:\n");
    writer.setColor(.light_grey, .black);
    writer.write("    Status: ");
    if (net.tls.isInitialized()) {
        writer.setColor(.light_green, .black);
        writer.write("Ready\n");
    } else {
        writer.setColor(.yellow, .black);
        writer.write("Not initialized\n");
    }
    writer.setColor(.light_grey, .black);
    writer.write("    Sessions: ");
    writer.setColor(.white, .black);
    writer.printInt(@truncate(net.tls.getActiveSessionCount()));
    writer.write("\n");
    writer.setColor(.light_grey, .black);
}

pub fn cmdMacRandom() void {
    writer.write("\n");
    writer.setColor(.light_cyan, .black);
    writer.write("MAC Randomization:\n");
    writer.setColor(.light_grey, .black);

    writer.write("  Current MAC: ");
    writer.setColor(.white, .black);
    printMac(net.mac.getCurrentMac());
    writer.write("\n");
    writer.setColor(.light_grey, .black);

    writer.write("  Generating new random MAC...\n");

    if (net.mac.randomize()) {
        writer.setColor(.light_green, .black);
        writer.write("  Success! New MAC: ");
        writer.setColor(.white, .black);
        printMac(net.mac.getCurrentMac());
        writer.write("\n");
    } else {
        writer.setColor(.light_red, .black);
        writer.write("  Failed to randomize MAC\n");
    }
    writer.setColor(.light_grey, .black);
}

// Tor module
const tor = @import("../net/tor.zig");
const circuit = @import("../net/circuit.zig");
const onion = @import("../net/onion.zig");

pub fn cmdTor(args: []const u8) void {
    writer.write("\n");
    writer.setColor(.light_cyan, .black);
    writer.write("Tor Onion Router:\n");
    writer.setColor(.light_grey, .black);

    // Parse subcommand
    var start: usize = 0;
    var end: usize = args.len;
    while (start < end and args[start] == ' ') start += 1;
    while (end > start and args[end - 1] == ' ') end -= 1;

    if (start >= end) {
        // Show status
        showTorStatus();
        return;
    }

    const subcmd = args[start..end];

    if (memEql(subcmd, "enable") or memEql(subcmd, "on")) {
        writer.write("  Enabling Tor...\n");
        if (tor.enable()) {
            writer.setColor(.light_green, .black);
            writer.write("  Tor enabled and connected!\n");
        } else {
            writer.setColor(.light_red, .black);
            writer.write("  Failed to enable Tor\n");
        }
    } else if (memEql(subcmd, "disable") or memEql(subcmd, "off")) {
        tor.disable();
        writer.setColor(.yellow, .black);
        writer.write("  Tor disabled\n");
    } else if (memEql(subcmd, "newcircuit") or memEql(subcmd, "new")) {
        if (tor.newCircuit()) {
            writer.setColor(.light_green, .black);
            writer.write("  New circuit created!\n");
        } else {
            writer.setColor(.light_red, .black);
            writer.write("  Failed to create new circuit\n");
        }
    } else if (memEql(subcmd, "status")) {
        showTorStatus();
    } else {
        writer.setColor(.yellow, .black);
        writer.write("  Usage: tor [enable|disable|newcircuit|status]\n");
    }
    writer.setColor(.light_grey, .black);
}

fn showTorStatus() void {
    writer.write("  Status: ");
    switch (tor.getStatus()) {
        .disabled => {
            writer.setColor(.yellow, .black);
            writer.write("DISABLED\n");
        },
        .bootstrapping => {
            writer.setColor(.light_cyan, .black);
            writer.write("BOOTSTRAPPING (");
            writer.printInt(tor.getBootstrapProgress());
            writer.write("%)\n");
        },
        .connected => {
            writer.setColor(.light_green, .black);
            writer.write("CONNECTED\n");
        },
        .error_state => {
            writer.setColor(.light_red, .black);
            writer.write("ERROR\n");
        },
    }
    writer.setColor(.light_grey, .black);

    writer.setColor(.yellow, .black);
    writer.write("\n  Directory:\n");
    writer.setColor(.light_grey, .black);
    writer.write("    Total Nodes: ");
    writer.setColor(.white, .black);
    writer.printInt(@truncate(tor.getNodeCount()));
    writer.write("\n");
    writer.setColor(.light_grey, .black);
    writer.write("    Guard Nodes: ");
    writer.setColor(.white, .black);
    writer.printInt(@truncate(tor.getGuardCount()));
    writer.write("\n");
    writer.setColor(.light_grey, .black);
    writer.write("    Exit Nodes:  ");
    writer.setColor(.white, .black);
    writer.printInt(@truncate(tor.getExitCount()));
    writer.write("\n");
    writer.setColor(.light_grey, .black);

    writer.setColor(.yellow, .black);
    writer.write("\n  SOCKS5 Proxy:\n");
    writer.setColor(.light_grey, .black);
    writer.write("    Port: ");
    writer.setColor(.white, .black);
    writer.printInt(tor.getSocksPort());
    writer.write("\n");
    writer.setColor(.light_grey, .black);
    writer.write("    Status: ");
    if (tor.isSocksEnabled()) {
        writer.setColor(.light_green, .black);
        writer.write("Enabled\n");
    } else {
        writer.setColor(.yellow, .black);
        writer.write("Disabled\n");
    }
    writer.setColor(.light_grey, .black);

    // Show current circuit if connected
    if (tor.getCurrentCircuit()) |c| {
        writer.setColor(.yellow, .black);
        writer.write("\n  Current Circuit:\n");
        writer.setColor(.light_grey, .black);
        writer.write("    ID: ");
        writer.setColor(.white, .black);
        writer.printInt(c.id);
        writer.write("\n");
        writer.setColor(.light_grey, .black);
        writer.write("    State: ");
        writer.setColor(.white, .black);
        writer.write(circuit.getStateName(c.state));
        writer.write("\n");
        writer.setColor(.light_grey, .black);
        writer.write("    Hops: ");
        writer.setColor(.white, .black);
        writer.printInt(c.hop_count);
        writer.write("\n");
        writer.setColor(.light_grey, .black);

        // Show path
        writer.setColor(.yellow, .black);
        writer.write("\n  Circuit Path:\n");
        writer.setColor(.light_grey, .black);

        var i: u8 = 0;
        while (i < c.hop_count) : (i += 1) {
            const hop = &c.hops[i];
            writer.write("    ");
            writer.printInt(i + 1);
            writer.write(". ");

            // Node type
            switch (hop.node_type) {
                .entry => {
                    writer.setColor(.light_green, .black);
                    writer.write("[GUARD] ");
                },
                .middle => {
                    writer.setColor(.light_cyan, .black);
                    writer.write("[RELAY] ");
                },
                .exit => {
                    writer.setColor(.light_magenta, .black);
                    writer.write("[EXIT]  ");
                },
            }
            writer.setColor(.white, .black);
            printIp(hop.ip);
            writer.write(":");
            writer.printInt(hop.port);
            writer.write("\n");
            writer.setColor(.light_grey, .black);
        }
    }
}

pub fn cmdCircuit() void {
    writer.write("\n");
    writer.setColor(.light_cyan, .black);
    writer.write("Circuit Status:\n");
    writer.setColor(.light_grey, .black);

    writer.write("  Active Circuits: ");
    writer.setColor(.white, .black);
    writer.printInt(circuit.getActiveCircuitCount());
    writer.write("/");
    writer.printInt(circuit.MAX_CIRCUITS);
    writer.write("\n");
    writer.setColor(.light_grey, .black);

    writer.write("  Ready Circuits:  ");
    writer.setColor(.light_green, .black);
    writer.printInt(circuit.getReadyCircuitCount());
    writer.write("\n");
    writer.setColor(.light_grey, .black);

    // List all circuits
    writer.setColor(.yellow, .black);
    writer.write("\n  Circuits:\n");
    writer.setColor(.light_grey, .black);

    var found: bool = false;
    var i: usize = 0;
    while (i < circuit.MAX_CIRCUITS) : (i += 1) {
        if (circuit.getCircuit(i)) |c| {
            found = true;
            writer.write("    #");
            writer.printInt(c.id);
            writer.write(" - ");

            switch (c.state) {
                .unused => {
                    writer.setColor(.dark_grey, .black);
                    writer.write("UNUSED");
                },
                .building => {
                    writer.setColor(.yellow, .black);
                    writer.write("BUILDING");
                },
                .extending => {
                    writer.setColor(.light_cyan, .black);
                    writer.write("EXTENDING");
                },
                .ready => {
                    writer.setColor(.light_green, .black);
                    writer.write("READY");
                },
                .closing => {
                    writer.setColor(.light_red, .black);
                    writer.write("CLOSING");
                },
                .failed => {
                    writer.setColor(.light_red, .black);
                    writer.write("FAILED");
                },
            }
            writer.setColor(.light_grey, .black);

            writer.write(" (");
            writer.printInt(c.hop_count);
            writer.write(" hops, ");
            writer.printInt(c.getActiveStreamCount());
            writer.write(" streams)\n");
        }
    }

    if (!found) {
        writer.write("    (no circuits)\n");
    }
}
