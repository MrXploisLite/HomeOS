// Home OS - ICMP (Internet Control Message Protocol)
// Copyright © 2025 Romy Rianata - Home OS
// Phase 13: Network Stack - ICMP (Ping)

const serial = @import("../drivers/serial.zig");
const ethernet = @import("ethernet.zig");
const ipv4 = @import("ipv4.zig");

// ICMP Types
pub const ICMP_ECHO_REPLY: u8 = 0;
pub const ICMP_DEST_UNREACHABLE: u8 = 3;
pub const ICMP_ECHO_REQUEST: u8 = 8;
pub const ICMP_TIME_EXCEEDED: u8 = 11;

// ICMP Header
pub const IcmpHeader = extern struct {
    icmp_type: u8,
    code: u8,
    checksum: u16,
    identifier: u16,
    sequence: u16,

    pub fn init() IcmpHeader {
        return IcmpHeader{
            .icmp_type = 0,
            .code = 0,
            .checksum = 0,
            .identifier = 0,
            .sequence = 0,
        };
    }

    pub fn getIdentifier(self: *const IcmpHeader) u16 {
        return ethernet.ntohs(self.identifier);
    }

    pub fn setIdentifier(self: *IcmpHeader, id: u16) void {
        self.identifier = ethernet.htons(id);
    }

    pub fn getSequence(self: *const IcmpHeader) u16 {
        return ethernet.ntohs(self.sequence);
    }

    pub fn setSequence(self: *IcmpHeader, seq: u16) void {
        self.sequence = ethernet.htons(seq);
    }

    pub fn isEchoRequest(self: *const IcmpHeader) bool {
        return self.icmp_type == ICMP_ECHO_REQUEST;
    }

    pub fn isEchoReply(self: *const IcmpHeader) bool {
        return self.icmp_type == ICMP_ECHO_REPLY;
    }
};

// ICMP Echo packet (ping)
pub const IcmpEcho = struct {
    header: IcmpHeader,
    data: [56]u8, // Standard ping payload
    data_len: usize,

    pub fn init() IcmpEcho {
        return IcmpEcho{
            .header = IcmpHeader.init(),
            .data = undefined,
            .data_len = 0,
        };
    }

    pub fn createRequest(id: u16, seq: u16) IcmpEcho {
        var echo = IcmpEcho.init();
        echo.header.icmp_type = ICMP_ECHO_REQUEST;
        echo.header.code = 0;
        echo.header.setIdentifier(id);
        echo.header.setSequence(seq);

        // Fill with pattern
        for (&echo.data, 0..) |*byte, i| {
            byte.* = @truncate(i & 0xFF);
        }
        echo.data_len = 56;

        echo.calculateChecksum();
        return echo;
    }

    pub fn createReply(request: *const IcmpEcho) IcmpEcho {
        var reply = request.*;
        reply.header.icmp_type = ICMP_ECHO_REPLY;
        reply.header.checksum = 0;
        reply.calculateChecksum();
        return reply;
    }

    pub fn calculateChecksum(self: *IcmpEcho) void {
        self.header.checksum = 0;

        var sum: u32 = 0;

        // Header
        sum += (@as(u32, self.header.icmp_type) << 8) | @as(u32, self.header.code);
        sum += 0; // Checksum field
        sum += ethernet.ntohs(self.header.identifier);
        sum += ethernet.ntohs(self.header.sequence);

        // Data
        var i: usize = 0;
        while (i < self.data_len) : (i += 2) {
            if (i + 1 < self.data_len) {
                sum += (@as(u32, self.data[i]) << 8) | @as(u32, self.data[i + 1]);
            } else {
                sum += @as(u32, self.data[i]) << 8;
            }
        }

        // Fold
        while ((sum >> 16) != 0) {
            sum = (sum & 0xFFFF) + (sum >> 16);
        }

        self.header.checksum = ethernet.htons(@truncate(~sum));
    }
};

// Ping statistics
pub const PingStats = struct {
    sent: u32,
    received: u32,
    lost: u32,
    min_rtt: u32,
    max_rtt: u32,
    total_rtt: u32,

    pub fn init() PingStats {
        return PingStats{
            .sent = 0,
            .received = 0,
            .lost = 0,
            .min_rtt = 0xFFFFFFFF,
            .max_rtt = 0,
            .total_rtt = 0,
        };
    }

    pub fn recordSent(self: *PingStats) void {
        self.sent += 1;
    }

    pub fn recordReceived(self: *PingStats, rtt: u32) void {
        self.received += 1;
        self.total_rtt += rtt;
        if (rtt < self.min_rtt) self.min_rtt = rtt;
        if (rtt > self.max_rtt) self.max_rtt = rtt;
    }

    pub fn recordLost(self: *PingStats) void {
        self.lost += 1;
    }

    pub fn getAvgRtt(self: *const PingStats) u32 {
        if (self.received == 0) return 0;
        return self.total_rtt / self.received;
    }

    pub fn getLossPercent(self: *const PingStats) u32 {
        if (self.sent == 0) return 0;
        // Use u64 to avoid overflow
        return @truncate((@as(u64, self.lost) * 100) / @as(u64, self.sent));
    }
};

// Global ping state
var ping_stats: PingStats = PingStats.init();
var ping_sequence: u16 = 0;
var ping_identifier: u16 = 0x1234;

pub fn init() void {
    serial.write("ICMP: Initialized\n");
    ping_stats = PingStats.init();
    ping_sequence = 0;
}

pub fn getStats() *PingStats {
    return &ping_stats;
}

pub fn resetStats() void {
    ping_stats = PingStats.init();
    ping_sequence = 0;
}

/// Create ping request
pub fn createPingRequest() IcmpEcho {
    ping_sequence += 1;
    ping_stats.recordSent();
    return IcmpEcho.createRequest(ping_identifier, ping_sequence);
}

/// Process ping reply
pub fn processPingReply(reply: *const IcmpEcho, rtt: u32) void {
    if (reply.header.isEchoReply()) {
        ping_stats.recordReceived(rtt);
        serial.write("ICMP: Reply seq=");
        serial.writeInt(@as(u32, reply.header.getSequence()));
        serial.write(" rtt=");
        serial.writeInt(rtt);
        serial.write("ms\n");
    }
}
