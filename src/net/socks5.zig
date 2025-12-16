// Home OS - SOCKS5 Proxy Protocol
// Copyright © 2025 Romy Rianata - Home OS
// Phase 26: Onion Routing - SOCKS5 Implementation

const serial = @import("../drivers/serial.zig");
const tcp = @import("tcp.zig");
const ipv4 = @import("ipv4.zig");
const ethernet = @import("ethernet.zig");

// SOCKS5 Protocol Constants
pub const SOCKS_VERSION: u8 = 0x05;

// Authentication methods
pub const AUTH_NONE: u8 = 0x00;
pub const AUTH_GSSAPI: u8 = 0x01;
pub const AUTH_PASSWORD: u8 = 0x02;
pub const AUTH_NO_ACCEPTABLE: u8 = 0xFF;

// Command types
pub const CMD_CONNECT: u8 = 0x01;
pub const CMD_BIND: u8 = 0x02;
pub const CMD_UDP_ASSOCIATE: u8 = 0x03;

// Address types
pub const ATYP_IPV4: u8 = 0x01;
pub const ATYP_DOMAIN: u8 = 0x03;
pub const ATYP_IPV6: u8 = 0x04;

// Reply codes
pub const REP_SUCCESS: u8 = 0x00;
pub const REP_GENERAL_FAILURE: u8 = 0x01;
pub const REP_NOT_ALLOWED: u8 = 0x02;
pub const REP_NETWORK_UNREACHABLE: u8 = 0x03;
pub const REP_HOST_UNREACHABLE: u8 = 0x04;
pub const REP_CONNECTION_REFUSED: u8 = 0x05;
pub const REP_TTL_EXPIRED: u8 = 0x06;
pub const REP_CMD_NOT_SUPPORTED: u8 = 0x07;
pub const REP_ATYP_NOT_SUPPORTED: u8 = 0x08;

// SOCKS5 Connection State
pub const Socks5State = enum {
    disconnected,
    greeting_sent,
    authenticated,
    request_sent,
    connected,
    failed,
};

// SOCKS5 Request
pub const Socks5Request = struct {
    command: u8,
    address_type: u8,
    dest_addr: [256]u8,
    dest_addr_len: u8,
    dest_port: u16,

    pub fn init() Socks5Request {
        return Socks5Request{
            .command = CMD_CONNECT,
            .address_type = ATYP_IPV4,
            .dest_addr = undefined,
            .dest_addr_len = 0,
            .dest_port = 0,
        };
    }

    pub fn setIPv4(self: *Socks5Request, ip: ipv4.IPv4Address, port: u16) void {
        self.address_type = ATYP_IPV4;
        self.dest_addr[0] = ip.octets[0];
        self.dest_addr[1] = ip.octets[1];
        self.dest_addr[2] = ip.octets[2];
        self.dest_addr[3] = ip.octets[3];
        self.dest_addr_len = 4;
        self.dest_port = port;
    }

    pub fn setDomain(self: *Socks5Request, domain: []const u8, port: u16) void {
        self.address_type = ATYP_DOMAIN;
        const len = @min(domain.len, 255);
        self.dest_addr[0] = @truncate(len);
        for (domain[0..len], 0..) |c, i| {
            self.dest_addr[1 + i] = c;
        }
        self.dest_addr_len = @truncate(len + 1);
        self.dest_port = port;
    }
};

// SOCKS5 Client Connection
pub const Socks5Client = struct {
    state: Socks5State,
    proxy_ip: ipv4.IPv4Address,
    proxy_port: u16,
    socket_id: ?u32,
    request: Socks5Request,
    auth_method: u8,

    pub fn init() Socks5Client {
        return Socks5Client{
            .state = .disconnected,
            .proxy_ip = ipv4.ZERO_IP,
            .proxy_port = 1080, // Default SOCKS5 port
            .socket_id = null,
            .request = Socks5Request.init(),
            .auth_method = AUTH_NONE,
        };
    }

    pub fn setProxy(self: *Socks5Client, ip: ipv4.IPv4Address, port: u16) void {
        self.proxy_ip = ip;
        self.proxy_port = port;
    }
};

// Build SOCKS5 greeting (client -> server)
pub fn buildGreeting(buf: []u8, methods: []const u8) usize {
    if (buf.len < 3 + methods.len) return 0;

    buf[0] = SOCKS_VERSION;
    buf[1] = @truncate(methods.len);

    for (methods, 0..) |m, i| {
        buf[2 + i] = m;
    }

    return 2 + methods.len;
}

// Build SOCKS5 connect request
pub fn buildConnectRequest(buf: []u8, req: *const Socks5Request) usize {
    if (buf.len < 10) return 0;

    var offset: usize = 0;

    buf[offset] = SOCKS_VERSION;
    offset += 1;
    buf[offset] = req.command;
    offset += 1;
    buf[offset] = 0x00; // Reserved
    offset += 1;
    buf[offset] = req.address_type;
    offset += 1;

    // Address
    if (req.address_type == ATYP_IPV4) {
        if (buf.len < offset + 4 + 2) return 0;
        for (req.dest_addr[0..4], 0..) |b, i| {
            buf[offset + i] = b;
        }
        offset += 4;
    } else if (req.address_type == ATYP_DOMAIN) {
        const domain_len = req.dest_addr_len;
        if (buf.len < offset + domain_len + 2) return 0;
        for (req.dest_addr[0..domain_len], 0..) |b, i| {
            buf[offset + i] = b;
        }
        offset += domain_len;
    }

    // Port (big-endian)
    buf[offset] = @truncate(req.dest_port >> 8);
    offset += 1;
    buf[offset] = @truncate(req.dest_port & 0xFF);
    offset += 1;

    return offset;
}

// Parse SOCKS5 greeting response
pub fn parseGreetingResponse(data: []const u8) ?u8 {
    if (data.len < 2) return null;
    if (data[0] != SOCKS_VERSION) return null;
    return data[1]; // Selected auth method
}

// Parse SOCKS5 connect response
pub fn parseConnectResponse(data: []const u8) ?u8 {
    if (data.len < 4) return null;
    if (data[0] != SOCKS_VERSION) return null;
    return data[1]; // Reply code
}

// Get reply code description
pub fn getReplyDescription(code: u8) []const u8 {
    return switch (code) {
        REP_SUCCESS => "Success",
        REP_GENERAL_FAILURE => "General failure",
        REP_NOT_ALLOWED => "Connection not allowed",
        REP_NETWORK_UNREACHABLE => "Network unreachable",
        REP_HOST_UNREACHABLE => "Host unreachable",
        REP_CONNECTION_REFUSED => "Connection refused",
        REP_TTL_EXPIRED => "TTL expired",
        REP_CMD_NOT_SUPPORTED => "Command not supported",
        REP_ATYP_NOT_SUPPORTED => "Address type not supported",
        else => "Unknown error",
    };
}

var socks5_initialized: bool = false;

pub fn init() void {
    serial.write("SOCKS5: Initializing proxy client...\n");
    socks5_initialized = true;
    serial.write("SOCKS5: Ready\n");
}

pub fn isInitialized() bool {
    return socks5_initialized;
}
