// Home OS - Ethernet Layer
// Copyright © 2025 Romy Rianata - Home OS
// Phase 13: Network Stack - Layer 2

const serial = @import("../drivers/serial.zig");

// Ethernet constants
pub const ETH_ALEN: usize = 6; // MAC address length
pub const ETH_HLEN: usize = 14; // Ethernet header length
pub const ETH_MTU: usize = 1500; // Maximum transmission unit
pub const ETH_FRAME_MAX: usize = 1518; // Max frame size (header + MTU + FCS)

// EtherTypes
pub const ETH_TYPE_IPV4: u16 = 0x0800;
pub const ETH_TYPE_ARP: u16 = 0x0806;
pub const ETH_TYPE_IPV6: u16 = 0x86DD;

// MAC Address
pub const MacAddress = [ETH_ALEN]u8;

pub const BROADCAST_MAC: MacAddress = [_]u8{ 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF };
pub const ZERO_MAC: MacAddress = [_]u8{ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 };

// Ethernet Header (14 bytes)
pub const EthernetHeader = extern struct {
    dest_mac: MacAddress, // Destination MAC
    src_mac: MacAddress, // Source MAC
    ethertype: u16, // Protocol type (big-endian)

    pub fn getEtherType(self: *const EthernetHeader) u16 {
        return ntohs(self.ethertype);
    }

    pub fn setEtherType(self: *EthernetHeader, etype: u16) void {
        self.ethertype = htons(etype);
    }
};

// Ethernet Frame
pub const EthernetFrame = struct {
    header: EthernetHeader,
    payload: [ETH_MTU]u8,
    payload_len: usize,

    pub fn init() EthernetFrame {
        return EthernetFrame{
            .header = undefined,
            .payload = undefined,
            .payload_len = 0,
        };
    }

    pub fn setDestination(self: *EthernetFrame, mac: MacAddress) void {
        self.header.dest_mac = mac;
    }

    pub fn setSource(self: *EthernetFrame, mac: MacAddress) void {
        self.header.src_mac = mac;
    }

    pub fn setPayload(self: *EthernetFrame, data: []const u8) void {
        const len = @min(data.len, ETH_MTU);
        for (data[0..len], 0..) |byte, i| {
            self.payload[i] = byte;
        }
        self.payload_len = len;
    }

    pub fn totalLength(self: *const EthernetFrame) usize {
        return ETH_HLEN + self.payload_len;
    }
};

// Network byte order conversion (big-endian)
pub fn htons(val: u16) u16 {
    return @byteSwap(val);
}

pub fn ntohs(val: u16) u16 {
    return @byteSwap(val);
}

pub fn htonl(val: u32) u32 {
    return @byteSwap(val);
}

pub fn ntohl(val: u32) u32 {
    return @byteSwap(val);
}

// MAC address utilities
pub fn macEqual(a: MacAddress, b: MacAddress) bool {
    for (a, b) |x, y| {
        if (x != y) return false;
    }
    return true;
}

pub fn macIsBroadcast(mac: MacAddress) bool {
    return macEqual(mac, BROADCAST_MAC);
}

pub fn macIsZero(mac: MacAddress) bool {
    return macEqual(mac, ZERO_MAC);
}

pub fn formatMac(mac: MacAddress, buf: []u8) usize {
    const hex = "0123456789ABCDEF";
    var pos: usize = 0;

    for (mac, 0..) |byte, i| {
        if (i > 0 and pos < buf.len) {
            buf[pos] = ':';
            pos += 1;
        }
        if (pos + 2 <= buf.len) {
            buf[pos] = hex[byte >> 4];
            buf[pos + 1] = hex[byte & 0x0F];
            pos += 2;
        }
    }
    return pos;
}

pub fn printMac(mac: MacAddress) void {
    var buf: [18]u8 = undefined;
    const len = formatMac(mac, &buf);
    serial.write(buf[0..len]);
}
