// Home OS - IPv4 Layer
// Copyright © 2025 Romy Rianata - Home OS
// Phase 13: Network Stack - Layer 3

const serial = @import("../drivers/serial.zig");
const ethernet = @import("ethernet.zig");

// IPv4 Address (4 bytes)
pub const IPv4Address = [4]u8;

pub const ZERO_IP: IPv4Address = [_]u8{ 0, 0, 0, 0 };
pub const BROADCAST_IP: IPv4Address = [_]u8{ 255, 255, 255, 255 };
pub const LOCALHOST: IPv4Address = [_]u8{ 127, 0, 0, 1 };

// IP Protocols
pub const IPPROTO_ICMP: u8 = 1;
pub const IPPROTO_TCP: u8 = 6;
pub const IPPROTO_UDP: u8 = 17;

// IPv4 Header (20 bytes minimum, no options)
pub const IPv4Header = extern struct {
    version_ihl: u8, // Version (4 bits) + IHL (4 bits)
    tos: u8, // Type of Service
    total_length: u16, // Total length (big-endian)
    identification: u16, // Identification
    flags_fragment: u16, // Flags (3 bits) + Fragment offset (13 bits)
    ttl: u8, // Time to Live
    protocol: u8, // Protocol (ICMP=1, TCP=6, UDP=17)
    checksum: u16, // Header checksum
    src_ip: IPv4Address, // Source IP
    dest_ip: IPv4Address, // Destination IP

    pub fn getVersion(self: *const IPv4Header) u8 {
        return self.version_ihl >> 4;
    }

    pub fn getHeaderLength(self: *const IPv4Header) u8 {
        return (self.version_ihl & 0x0F) * 4;
    }

    pub fn getTotalLength(self: *const IPv4Header) u16 {
        return ethernet.ntohs(self.total_length);
    }

    pub fn setTotalLength(self: *IPv4Header, len: u16) void {
        self.total_length = ethernet.htons(len);
    }

    pub fn init() IPv4Header {
        return IPv4Header{
            .version_ihl = 0x45, // IPv4, 20 bytes header
            .tos = 0,
            .total_length = 0,
            .identification = 0,
            .flags_fragment = 0,
            .ttl = 64,
            .protocol = 0,
            .checksum = 0,
            .src_ip = ZERO_IP,
            .dest_ip = ZERO_IP,
        };
    }

    pub fn calculateChecksum(self: *IPv4Header) void {
        self.checksum = 0;
        const header_bytes: [*]const u8 = @ptrCast(self);
        const header_len = self.getHeaderLength();

        var sum: u32 = 0;
        var i: usize = 0;
        while (i < header_len) : (i += 2) {
            const word: u16 = (@as(u16, header_bytes[i]) << 8) | @as(u16, header_bytes[i + 1]);
            sum += word;
        }

        // Fold 32-bit sum to 16 bits
        while ((sum >> 16) != 0) {
            sum = (sum & 0xFFFF) + (sum >> 16);
        }

        self.checksum = ethernet.htons(@truncate(~sum));
    }

    pub fn verifyChecksum(self: *const IPv4Header) bool {
        const header_bytes: [*]const u8 = @ptrCast(self);
        const header_len = self.getHeaderLength();

        var sum: u32 = 0;
        var i: usize = 0;
        while (i < header_len) : (i += 2) {
            const word: u16 = (@as(u16, header_bytes[i]) << 8) | @as(u16, header_bytes[i + 1]);
            sum += word;
        }

        while ((sum >> 16) != 0) {
            sum = (sum & 0xFFFF) + (sum >> 16);
        }

        return (@as(u16, @truncate(sum)) == 0xFFFF);
    }
};

// IPv4 utilities
pub fn ipEqual(a: IPv4Address, b: IPv4Address) bool {
    return a[0] == b[0] and a[1] == b[1] and a[2] == b[2] and a[3] == b[3];
}

pub fn ipIsBroadcast(ip: IPv4Address) bool {
    return ipEqual(ip, BROADCAST_IP);
}

pub fn ipIsZero(ip: IPv4Address) bool {
    return ipEqual(ip, ZERO_IP);
}

pub fn ipToU32(ip: IPv4Address) u32 {
    return (@as(u32, ip[0]) << 24) | (@as(u32, ip[1]) << 16) |
        (@as(u32, ip[2]) << 8) | @as(u32, ip[3]);
}

pub fn u32ToIp(val: u32) IPv4Address {
    return [_]u8{
        @truncate(val >> 24),
        @truncate((val >> 16) & 0xFF),
        @truncate((val >> 8) & 0xFF),
        @truncate(val & 0xFF),
    };
}

pub fn formatIp(ip: IPv4Address, buf: []u8) usize {
    var pos: usize = 0;

    for (ip, 0..) |octet, i| {
        if (i > 0 and pos < buf.len) {
            buf[pos] = '.';
            pos += 1;
        }

        // Convert octet to string
        var val = octet;
        var digits: [3]u8 = undefined;
        var digit_count: usize = 0;

        if (val == 0) {
            if (pos < buf.len) {
                buf[pos] = '0';
                pos += 1;
            }
        } else {
            while (val > 0) : (digit_count += 1) {
                digits[digit_count] = '0' + @as(u8, @truncate(val % 10));
                val /= 10;
            }
            while (digit_count > 0) {
                digit_count -= 1;
                if (pos < buf.len) {
                    buf[pos] = digits[digit_count];
                    pos += 1;
                }
            }
        }
    }
    return pos;
}

pub fn printIp(ip: IPv4Address) void {
    var buf: [16]u8 = undefined;
    const len = formatIp(ip, &buf);
    serial.write(buf[0..len]);
}

// Parse IP from string "192.168.1.1"
pub fn parseIp(s: []const u8) ?IPv4Address {
    var ip: IPv4Address = undefined;
    var octet: u16 = 0;
    var octet_idx: usize = 0;

    for (s) |c| {
        if (c == '.') {
            if (octet > 255 or octet_idx >= 4) return null;
            ip[octet_idx] = @truncate(octet);
            octet_idx += 1;
            octet = 0;
        } else if (c >= '0' and c <= '9') {
            octet = octet * 10 + (c - '0');
        } else {
            return null;
        }
    }

    if (octet > 255 or octet_idx != 3) return null;
    ip[3] = @truncate(octet);

    return ip;
}
