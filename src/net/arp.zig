// Home OS - ARP (Address Resolution Protocol)
// Copyright © 2025 Romy Rianata - Home OS
// Phase 13: Network Stack - ARP

const serial = @import("../drivers/serial.zig");
const ethernet = @import("ethernet.zig");
const ipv4 = @import("ipv4.zig");

// ARP constants
pub const ARP_HTYPE_ETHERNET: u16 = 1;
pub const ARP_PTYPE_IPV4: u16 = 0x0800;
pub const ARP_OP_REQUEST: u16 = 1;
pub const ARP_OP_REPLY: u16 = 2;

// ARP Header for Ethernet/IPv4
pub const ArpPacket = extern struct {
    htype: u16, // Hardware type (1 = Ethernet)
    ptype: u16, // Protocol type (0x0800 = IPv4)
    hlen: u8, // Hardware address length (6)
    plen: u8, // Protocol address length (4)
    operation: u16, // Operation (1=request, 2=reply)
    sender_mac: ethernet.MacAddress,
    sender_ip: ipv4.IPv4Address,
    target_mac: ethernet.MacAddress,
    target_ip: ipv4.IPv4Address,

    pub fn init() ArpPacket {
        return ArpPacket{
            .htype = ethernet.htons(ARP_HTYPE_ETHERNET),
            .ptype = ethernet.htons(ARP_PTYPE_IPV4),
            .hlen = 6,
            .plen = 4,
            .operation = 0,
            .sender_mac = ethernet.ZERO_MAC,
            .sender_ip = ipv4.ZERO_IP,
            .target_mac = ethernet.ZERO_MAC,
            .target_ip = ipv4.ZERO_IP,
        };
    }

    pub fn getOperation(self: *const ArpPacket) u16 {
        return ethernet.ntohs(self.operation);
    }

    pub fn setOperation(self: *ArpPacket, op: u16) void {
        self.operation = ethernet.htons(op);
    }

    pub fn isRequest(self: *const ArpPacket) bool {
        return self.getOperation() == ARP_OP_REQUEST;
    }

    pub fn isReply(self: *const ArpPacket) bool {
        return self.getOperation() == ARP_OP_REPLY;
    }
};

// ARP Cache Entry
pub const ArpEntry = struct {
    ip: ipv4.IPv4Address,
    mac: ethernet.MacAddress,
    valid: bool,
    timestamp: u32, // For cache expiry

    pub fn init() ArpEntry {
        return ArpEntry{
            .ip = ipv4.ZERO_IP,
            .mac = ethernet.ZERO_MAC,
            .valid = false,
            .timestamp = 0,
        };
    }
};

// ARP Cache
pub const ARP_CACHE_SIZE: usize = 32;
pub const ARP_CACHE_TIMEOUT: u32 = 300; // 5 minutes

var arp_cache: [ARP_CACHE_SIZE]ArpEntry = undefined;
var arp_initialized: bool = false;

pub fn init() void {
    serial.write("ARP: Initializing cache...\n");
    for (&arp_cache) |*entry| {
        entry.* = ArpEntry.init();
    }
    arp_initialized = true;
    serial.write("ARP: Ready\n");
}

/// Lookup MAC address for IP
pub fn lookup(ip: ipv4.IPv4Address) ?ethernet.MacAddress {
    if (!arp_initialized) return null;

    for (arp_cache) |entry| {
        if (entry.valid and ipv4.ipEqual(entry.ip, ip)) {
            return entry.mac;
        }
    }
    return null;
}

/// Add entry to ARP cache
pub fn addEntry(ip: ipv4.IPv4Address, mac: ethernet.MacAddress, timestamp: u32) void {
    if (!arp_initialized) return;

    // Check if already exists
    for (&arp_cache) |*entry| {
        if (entry.valid and ipv4.ipEqual(entry.ip, ip)) {
            entry.mac = mac;
            entry.timestamp = timestamp;
            return;
        }
    }

    // Find empty slot
    for (&arp_cache) |*entry| {
        if (!entry.valid) {
            entry.ip = ip;
            entry.mac = mac;
            entry.valid = true;
            entry.timestamp = timestamp;

            serial.write("ARP: Added ");
            ipv4.printIp(ip);
            serial.write(" -> ");
            ethernet.printMac(mac);
            serial.write("\n");
            return;
        }
    }

    // Cache full - replace oldest entry
    var oldest_idx: usize = 0;
    var oldest_time: u32 = arp_cache[0].timestamp;

    for (arp_cache, 0..) |entry, i| {
        if (entry.timestamp < oldest_time) {
            oldest_time = entry.timestamp;
            oldest_idx = i;
        }
    }

    arp_cache[oldest_idx].ip = ip;
    arp_cache[oldest_idx].mac = mac;
    arp_cache[oldest_idx].valid = true;
    arp_cache[oldest_idx].timestamp = timestamp;
}

/// Remove entry from cache
pub fn removeEntry(ip: ipv4.IPv4Address) void {
    for (&arp_cache) |*entry| {
        if (entry.valid and ipv4.ipEqual(entry.ip, ip)) {
            entry.valid = false;
            return;
        }
    }
}

/// Clear expired entries
pub fn cleanCache(current_time: u32) void {
    for (&arp_cache) |*entry| {
        if (entry.valid and (current_time - entry.timestamp) > ARP_CACHE_TIMEOUT) {
            entry.valid = false;
        }
    }
}

/// Get cache entry count
pub fn getCacheCount() u32 {
    var count: u32 = 0;
    for (arp_cache) |entry| {
        if (entry.valid) count += 1;
    }
    return count;
}

/// Create ARP request packet
pub fn createRequest(sender_mac: ethernet.MacAddress, sender_ip: ipv4.IPv4Address, target_ip: ipv4.IPv4Address) ArpPacket {
    var pkt = ArpPacket.init();
    pkt.setOperation(ARP_OP_REQUEST);
    pkt.sender_mac = sender_mac;
    pkt.sender_ip = sender_ip;
    pkt.target_mac = ethernet.ZERO_MAC; // Unknown
    pkt.target_ip = target_ip;
    return pkt;
}

/// Create ARP reply packet
pub fn createReply(sender_mac: ethernet.MacAddress, sender_ip: ipv4.IPv4Address, target_mac: ethernet.MacAddress, target_ip: ipv4.IPv4Address) ArpPacket {
    var pkt = ArpPacket.init();
    pkt.setOperation(ARP_OP_REPLY);
    pkt.sender_mac = sender_mac;
    pkt.sender_ip = sender_ip;
    pkt.target_mac = target_mac;
    pkt.target_ip = target_ip;
    return pkt;
}

/// Process incoming ARP packet
pub fn processPacket(pkt: *const ArpPacket, timestamp: u32) void {
    // Always learn from ARP packets
    addEntry(pkt.sender_ip, pkt.sender_mac, timestamp);

    if (pkt.isRequest()) {
        serial.write("ARP: Request from ");
        ipv4.printIp(pkt.sender_ip);
        serial.write(" for ");
        ipv4.printIp(pkt.target_ip);
        serial.write("\n");
    } else if (pkt.isReply()) {
        serial.write("ARP: Reply from ");
        ipv4.printIp(pkt.sender_ip);
        serial.write("\n");
    }
}
