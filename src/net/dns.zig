// Home OS - DNS Resolver
// Copyright © 2025 Romy Rianata - Home OS
// Phase 19: Networking Completion - DNS

const serial = @import("../drivers/serial.zig");
const ethernet = @import("ethernet.zig");
const ipv4 = @import("ipv4.zig");

// DNS Constants
pub const DNS_PORT: u16 = 53;
pub const DNS_MAX_NAME_LEN: usize = 255;
pub const DNS_MAX_PACKET_SIZE: usize = 512;

// DNS Record Types
pub const DNS_TYPE_A: u16 = 1; // IPv4 address
pub const DNS_TYPE_NS: u16 = 2; // Name server
pub const DNS_TYPE_CNAME: u16 = 5; // Canonical name
pub const DNS_TYPE_MX: u16 = 15; // Mail exchange
pub const DNS_TYPE_AAAA: u16 = 28; // IPv6 address

// DNS Classes
pub const DNS_CLASS_IN: u16 = 1; // Internet

// DNS Response Codes
pub const DNS_RCODE_OK: u8 = 0;
pub const DNS_RCODE_FORMAT_ERR: u8 = 1;
pub const DNS_RCODE_SERVER_FAIL: u8 = 2;
pub const DNS_RCODE_NAME_ERR: u8 = 3; // NXDOMAIN
pub const DNS_RCODE_NOT_IMPL: u8 = 4;
pub const DNS_RCODE_REFUSED: u8 = 5;

// DNS Header (12 bytes)
pub const DnsHeader = extern struct {
    id: u16, // Transaction ID
    flags: u16, // Flags
    qdcount: u16, // Question count
    ancount: u16, // Answer count
    nscount: u16, // Authority count
    arcount: u16, // Additional count

    pub fn init() DnsHeader {
        return DnsHeader{
            .id = 0,
            .flags = 0,
            .qdcount = 0,
            .ancount = 0,
            .nscount = 0,
            .arcount = 0,
        };
    }

    pub fn getId(self: *const DnsHeader) u16 {
        return ethernet.ntohs(self.id);
    }

    pub fn setId(self: *DnsHeader, id: u16) void {
        self.id = ethernet.htons(id);
    }

    pub fn getFlags(self: *const DnsHeader) u16 {
        return ethernet.ntohs(self.flags);
    }

    pub fn setFlags(self: *DnsHeader, flags: u16) void {
        self.flags = ethernet.htons(flags);
    }

    pub fn isResponse(self: *const DnsHeader) bool {
        return (self.getFlags() & 0x8000) != 0;
    }

    pub fn getRcode(self: *const DnsHeader) u8 {
        return @truncate(self.getFlags() & 0x000F);
    }

    pub fn getQuestionCount(self: *const DnsHeader) u16 {
        return ethernet.ntohs(self.qdcount);
    }

    pub fn getAnswerCount(self: *const DnsHeader) u16 {
        return ethernet.ntohs(self.ancount);
    }
};

// DNS Cache Entry
pub const DnsCacheEntry = struct {
    name: [64]u8,
    name_len: usize,
    ip: ipv4.IPv4Address,
    ttl: u32,
    timestamp: u32,
    valid: bool,

    pub fn init() DnsCacheEntry {
        return DnsCacheEntry{
            .name = [_]u8{0} ** 64,
            .name_len = 0,
            .ip = ipv4.ZERO_IP,
            .ttl = 0,
            .timestamp = 0,
            .valid = false,
        };
    }
};

// DNS Cache
pub const DNS_CACHE_SIZE: usize = 16;
var dns_cache: [DNS_CACHE_SIZE]DnsCacheEntry = undefined;
var dns_initialized: bool = false;
var dns_query_id: u16 = 0x1234;

// Pending query state
var pending_query: struct {
    id: u16,
    name: [64]u8,
    name_len: usize,
    waiting: bool,
    result: ipv4.IPv4Address,
    resolved: bool,
} = undefined;

pub fn init() void {
    serial.write("DNS: Initializing resolver...\n");
    for (&dns_cache) |*entry| {
        entry.* = DnsCacheEntry.init();
    }
    pending_query.waiting = false;
    pending_query.resolved = false;
    pending_query.name_len = 0;
    dns_initialized = true;
    serial.write("DNS: Ready\n");
}

/// Lookup in cache
pub fn cacheLookup(name: []const u8) ?ipv4.IPv4Address {
    for (dns_cache) |entry| {
        if (entry.valid and entry.name_len == name.len) {
            var match = true;
            for (name, 0..) |c, i| {
                if (entry.name[i] != c) {
                    match = false;
                    break;
                }
            }
            if (match) {
                return entry.ip;
            }
        }
    }
    return null;
}

/// Add to cache
pub fn cacheAdd(name: []const u8, ip: ipv4.IPv4Address, ttl: u32, timestamp: u32) void {
    // Find empty or oldest slot
    var slot: usize = 0;
    var oldest_time: u32 = 0xFFFFFFFF;

    for (&dns_cache, 0..) |*entry, i| {
        if (!entry.valid) {
            slot = i;
            break;
        }
        if (entry.timestamp < oldest_time) {
            oldest_time = entry.timestamp;
            slot = i;
        }
    }

    const len = @min(name.len, 63);
    for (name[0..len], 0..) |c, i| {
        dns_cache[slot].name[i] = c;
    }
    dns_cache[slot].name_len = len;
    dns_cache[slot].ip = ip;
    dns_cache[slot].ttl = ttl;
    dns_cache[slot].timestamp = timestamp;
    dns_cache[slot].valid = true;
}

/// Encode domain name to DNS format (labels)
/// "www.example.com" -> "\x03www\x07example\x03com\x00"
pub fn encodeName(name: []const u8, buf: []u8) usize {
    var pos: usize = 0;
    var label_start: usize = 0;

    for (name, 0..) |c, i| {
        if (c == '.') {
            const label_len = i - label_start;
            if (pos + 1 + label_len > buf.len) return 0;

            buf[pos] = @truncate(label_len);
            pos += 1;

            for (name[label_start..i]) |lc| {
                buf[pos] = lc;
                pos += 1;
            }
            label_start = i + 1;
        }
    }

    // Last label
    const label_len = name.len - label_start;
    if (label_len > 0) {
        if (pos + 1 + label_len + 1 > buf.len) return 0;

        buf[pos] = @truncate(label_len);
        pos += 1;

        for (name[label_start..]) |lc| {
            buf[pos] = lc;
            pos += 1;
        }
    }

    // Null terminator
    if (pos < buf.len) {
        buf[pos] = 0;
        pos += 1;
    }

    return pos;
}

/// Create DNS query packet
pub fn createQuery(name: []const u8, buf: []u8) usize {
    if (buf.len < 12 + DNS_MAX_NAME_LEN + 4) return 0;

    dns_query_id += 1;

    // Header
    var header: *DnsHeader = @ptrCast(@alignCast(buf.ptr));
    header.* = DnsHeader.init();
    header.setId(dns_query_id);
    header.setFlags(0x0100); // Standard query, recursion desired
    header.qdcount = ethernet.htons(1);

    // Question section
    var pos: usize = 12;

    // Encode name
    const name_len = encodeName(name, buf[pos..]);
    if (name_len == 0) return 0;
    pos += name_len;

    // Type (A record)
    buf[pos] = 0;
    buf[pos + 1] = DNS_TYPE_A;
    pos += 2;

    // Class (IN)
    buf[pos] = 0;
    buf[pos + 1] = DNS_CLASS_IN;
    pos += 2;

    // Store pending query info
    pending_query.id = dns_query_id;
    const copy_len = @min(name.len, 63);
    for (name[0..copy_len], 0..) |c, i| {
        pending_query.name[i] = c;
    }
    pending_query.name_len = copy_len;
    pending_query.waiting = true;
    pending_query.resolved = false;

    return pos;
}

/// Skip DNS name (handles compression)
fn skipName(data: []const u8, start: usize) usize {
    var pos = start;
    while (pos < data.len) {
        const len = data[pos];
        if (len == 0) {
            return pos + 1;
        }
        if ((len & 0xC0) == 0xC0) {
            // Compression pointer
            return pos + 2;
        }
        pos += 1 + len;
    }
    return pos;
}

/// Parse DNS response
pub fn parseResponse(data: []const u8) ?ipv4.IPv4Address {
    if (data.len < 12) return null;

    const header: *const DnsHeader = @ptrCast(@alignCast(data.ptr));

    // Check if response
    if (!header.isResponse()) return null;

    // Check ID
    if (header.getId() != pending_query.id) return null;

    // Check for errors
    if (header.getRcode() != DNS_RCODE_OK) {
        serial.write("DNS: Query failed, rcode=");
        serial.writeInt(header.getRcode());
        serial.write("\n");
        pending_query.waiting = false;
        return null;
    }

    const answer_count = header.getAnswerCount();
    if (answer_count == 0) {
        serial.write("DNS: No answers\n");
        pending_query.waiting = false;
        return null;
    }

    // Skip header
    var pos: usize = 12;

    // Skip questions
    const question_count = header.getQuestionCount();
    var q: u16 = 0;
    while (q < question_count) : (q += 1) {
        pos = skipName(data, pos);
        pos += 4; // Type + Class
    }

    // Parse answers
    var a: u16 = 0;
    while (a < answer_count) : (a += 1) {
        if (pos >= data.len) break;

        // Skip name
        pos = skipName(data, pos);

        if (pos + 10 > data.len) break;

        // Type
        const rtype = (@as(u16, data[pos]) << 8) | @as(u16, data[pos + 1]);
        pos += 2;

        // Class
        pos += 2;

        // TTL
        const ttl = (@as(u32, data[pos]) << 24) |
            (@as(u32, data[pos + 1]) << 16) |
            (@as(u32, data[pos + 2]) << 8) |
            @as(u32, data[pos + 3]);
        pos += 4;
        _ = ttl;

        // Data length
        const rdlen = (@as(u16, data[pos]) << 8) | @as(u16, data[pos + 1]);
        pos += 2;

        // Check for A record
        if (rtype == DNS_TYPE_A and rdlen == 4) {
            if (pos + 4 <= data.len) {
                const ip = [_]u8{
                    data[pos],
                    data[pos + 1],
                    data[pos + 2],
                    data[pos + 3],
                };

                pending_query.result = ip;
                pending_query.resolved = true;
                pending_query.waiting = false;

                serial.write("DNS: Resolved to ");
                ipv4.printIp(ip);
                serial.write("\n");

                return ip;
            }
        }

        pos += rdlen;
    }

    pending_query.waiting = false;
    return null;
}

/// Check if query is pending
pub fn isQueryPending() bool {
    return pending_query.waiting;
}

/// Check if query resolved
pub fn isResolved() bool {
    return pending_query.resolved;
}

/// Get resolved IP
pub fn getResolvedIp() ?ipv4.IPv4Address {
    if (pending_query.resolved) {
        return pending_query.result;
    }
    return null;
}

/// Get cache entry count
pub fn getCacheCount() u32 {
    var count: u32 = 0;
    for (dns_cache) |entry| {
        if (entry.valid) count += 1;
    }
    return count;
}

/// Clear cache
pub fn clearCache() void {
    for (&dns_cache) |*entry| {
        entry.valid = false;
    }
}
