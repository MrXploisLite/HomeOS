// Home OS - DHCP Client
// Copyright © 2025 Romy Rianata - Home OS
// Phase 19: Networking Completion - DHCP

const serial = @import("../drivers/serial.zig");
const ethernet = @import("ethernet.zig");
const ipv4 = @import("ipv4.zig");
const udp = @import("udp.zig");

// DHCP Constants
pub const DHCP_SERVER_PORT: u16 = 67;
pub const DHCP_CLIENT_PORT: u16 = 68;

// DHCP Message Types
pub const DHCP_DISCOVER: u8 = 1;
pub const DHCP_OFFER: u8 = 2;
pub const DHCP_REQUEST: u8 = 3;
pub const DHCP_DECLINE: u8 = 4;
pub const DHCP_ACK: u8 = 5;
pub const DHCP_NAK: u8 = 6;
pub const DHCP_RELEASE: u8 = 7;
pub const DHCP_INFORM: u8 = 8;

// DHCP Options
pub const DHCP_OPT_PAD: u8 = 0;
pub const DHCP_OPT_SUBNET_MASK: u8 = 1;
pub const DHCP_OPT_ROUTER: u8 = 3;
pub const DHCP_OPT_DNS: u8 = 6;
pub const DHCP_OPT_HOSTNAME: u8 = 12;
pub const DHCP_OPT_REQUESTED_IP: u8 = 50;
pub const DHCP_OPT_LEASE_TIME: u8 = 51;
pub const DHCP_OPT_MSG_TYPE: u8 = 53;
pub const DHCP_OPT_SERVER_ID: u8 = 54;
pub const DHCP_OPT_PARAM_LIST: u8 = 55;
pub const DHCP_OPT_END: u8 = 255;

// DHCP Magic Cookie
pub const DHCP_MAGIC_COOKIE: u32 = 0x63825363;

// DHCP Packet (simplified - 576 bytes minimum)
pub const DhcpPacket = extern struct {
    op: u8, // 1 = BOOTREQUEST, 2 = BOOTREPLY
    htype: u8, // Hardware type (1 = Ethernet)
    hlen: u8, // Hardware address length (6)
    hops: u8, // Hops
    xid: u32, // Transaction ID
    secs: u16, // Seconds elapsed
    flags: u16, // Flags (0x8000 = broadcast)
    ciaddr: ipv4.IPv4Address, // Client IP (if known)
    yiaddr: ipv4.IPv4Address, // Your (client) IP
    siaddr: ipv4.IPv4Address, // Server IP
    giaddr: ipv4.IPv4Address, // Gateway IP
    chaddr: [16]u8, // Client hardware address
    sname: [64]u8, // Server name
    file: [128]u8, // Boot filename
    options: [312]u8, // Options (starts with magic cookie)

    pub fn init() DhcpPacket {
        var pkt: DhcpPacket = undefined;
        // Zero everything
        const ptr: [*]u8 = @ptrCast(&pkt);
        for (ptr[0..@sizeOf(DhcpPacket)]) |*b| {
            b.* = 0;
        }
        return pkt;
    }
};

// DHCP State
pub const DhcpState = enum {
    idle,
    discovering,
    requesting,
    bound,
    renewing,
    rebinding,
};

// DHCP Configuration Result
pub const DhcpConfig = struct {
    ip_address: ipv4.IPv4Address,
    subnet_mask: ipv4.IPv4Address,
    gateway: ipv4.IPv4Address,
    dns_server: ipv4.IPv4Address,
    server_id: ipv4.IPv4Address,
    lease_time: u32,
    valid: bool,

    pub fn init() DhcpConfig {
        return DhcpConfig{
            .ip_address = ipv4.ZERO_IP,
            .subnet_mask = ipv4.ZERO_IP,
            .gateway = ipv4.ZERO_IP,
            .dns_server = ipv4.ZERO_IP,
            .server_id = ipv4.ZERO_IP,
            .lease_time = 0,
            .valid = false,
        };
    }
};

// DHCP Client State
var dhcp_state: DhcpState = .idle;
var dhcp_config: DhcpConfig = DhcpConfig.init();
var dhcp_xid: u32 = 0x12345678; // Transaction ID
var dhcp_initialized: bool = false;

pub fn init() void {
    serial.write("DHCP: Initializing client...\n");
    dhcp_state = .idle;
    dhcp_config = DhcpConfig.init();
    dhcp_initialized = true;
    serial.write("DHCP: Ready\n");
}

/// Get current DHCP state
pub fn getState() DhcpState {
    return dhcp_state;
}

/// Get DHCP configuration
pub fn getConfig() *const DhcpConfig {
    return &dhcp_config;
}

/// Check if DHCP is bound
pub fn isBound() bool {
    return dhcp_state == .bound and dhcp_config.valid;
}

/// Create DHCP Discover packet
pub fn createDiscover(mac: ethernet.MacAddress) DhcpPacket {
    var pkt = DhcpPacket.init();

    pkt.op = 1; // BOOTREQUEST
    pkt.htype = 1; // Ethernet
    pkt.hlen = 6; // MAC length
    pkt.hops = 0;
    pkt.xid = ethernet.htonl(dhcp_xid);
    pkt.secs = 0;
    pkt.flags = ethernet.htons(0x8000); // Broadcast flag

    // Copy MAC address
    for (mac, 0..) |b, i| {
        pkt.chaddr[i] = b;
    }

    // Options - Magic Cookie
    pkt.options[0] = @truncate((DHCP_MAGIC_COOKIE >> 24) & 0xFF);
    pkt.options[1] = @truncate((DHCP_MAGIC_COOKIE >> 16) & 0xFF);
    pkt.options[2] = @truncate((DHCP_MAGIC_COOKIE >> 8) & 0xFF);
    pkt.options[3] = @truncate(DHCP_MAGIC_COOKIE & 0xFF);

    var opt_idx: usize = 4;

    // Option 53: DHCP Message Type = Discover
    pkt.options[opt_idx] = DHCP_OPT_MSG_TYPE;
    pkt.options[opt_idx + 1] = 1;
    pkt.options[opt_idx + 2] = DHCP_DISCOVER;
    opt_idx += 3;

    // Option 55: Parameter Request List
    pkt.options[opt_idx] = DHCP_OPT_PARAM_LIST;
    pkt.options[opt_idx + 1] = 4; // Length
    pkt.options[opt_idx + 2] = DHCP_OPT_SUBNET_MASK;
    pkt.options[opt_idx + 3] = DHCP_OPT_ROUTER;
    pkt.options[opt_idx + 4] = DHCP_OPT_DNS;
    pkt.options[opt_idx + 5] = DHCP_OPT_LEASE_TIME;
    opt_idx += 6;

    // End option
    pkt.options[opt_idx] = DHCP_OPT_END;

    return pkt;
}

/// Create DHCP Request packet
pub fn createRequest(mac: ethernet.MacAddress, offered_ip: ipv4.IPv4Address, server_ip: ipv4.IPv4Address) DhcpPacket {
    var pkt = DhcpPacket.init();

    pkt.op = 1; // BOOTREQUEST
    pkt.htype = 1; // Ethernet
    pkt.hlen = 6; // MAC length
    pkt.hops = 0;
    pkt.xid = ethernet.htonl(dhcp_xid);
    pkt.secs = 0;
    pkt.flags = ethernet.htons(0x8000); // Broadcast flag

    // Copy MAC address
    for (mac, 0..) |b, i| {
        pkt.chaddr[i] = b;
    }

    // Options - Magic Cookie
    pkt.options[0] = @truncate((DHCP_MAGIC_COOKIE >> 24) & 0xFF);
    pkt.options[1] = @truncate((DHCP_MAGIC_COOKIE >> 16) & 0xFF);
    pkt.options[2] = @truncate((DHCP_MAGIC_COOKIE >> 8) & 0xFF);
    pkt.options[3] = @truncate(DHCP_MAGIC_COOKIE & 0xFF);

    var opt_idx: usize = 4;

    // Option 53: DHCP Message Type = Request
    pkt.options[opt_idx] = DHCP_OPT_MSG_TYPE;
    pkt.options[opt_idx + 1] = 1;
    pkt.options[opt_idx + 2] = DHCP_REQUEST;
    opt_idx += 3;

    // Option 50: Requested IP Address
    pkt.options[opt_idx] = DHCP_OPT_REQUESTED_IP;
    pkt.options[opt_idx + 1] = 4;
    pkt.options[opt_idx + 2] = offered_ip[0];
    pkt.options[opt_idx + 3] = offered_ip[1];
    pkt.options[opt_idx + 4] = offered_ip[2];
    pkt.options[opt_idx + 5] = offered_ip[3];
    opt_idx += 6;

    // Option 54: Server Identifier
    pkt.options[opt_idx] = DHCP_OPT_SERVER_ID;
    pkt.options[opt_idx + 1] = 4;
    pkt.options[opt_idx + 2] = server_ip[0];
    pkt.options[opt_idx + 3] = server_ip[1];
    pkt.options[opt_idx + 4] = server_ip[2];
    pkt.options[opt_idx + 5] = server_ip[3];
    opt_idx += 6;

    // End option
    pkt.options[opt_idx] = DHCP_OPT_END;

    return pkt;
}

/// Parse DHCP options from packet
pub fn parseOptions(pkt: *const DhcpPacket) DhcpConfig {
    var config = DhcpConfig.init();

    // Check magic cookie
    const cookie = (@as(u32, pkt.options[0]) << 24) |
        (@as(u32, pkt.options[1]) << 16) |
        (@as(u32, pkt.options[2]) << 8) |
        @as(u32, pkt.options[3]);

    if (cookie != DHCP_MAGIC_COOKIE) {
        serial.write("DHCP: Invalid magic cookie\n");
        return config;
    }

    // Get offered IP
    config.ip_address = pkt.yiaddr;

    // Parse options
    var i: usize = 4;
    while (i < pkt.options.len) {
        const opt = pkt.options[i];

        if (opt == DHCP_OPT_PAD) {
            i += 1;
            continue;
        }

        if (opt == DHCP_OPT_END) {
            break;
        }

        if (i + 1 >= pkt.options.len) break;
        const len = pkt.options[i + 1];

        if (i + 2 + len > pkt.options.len) break;

        switch (opt) {
            DHCP_OPT_SUBNET_MASK => {
                if (len >= 4) {
                    config.subnet_mask = [_]u8{
                        pkt.options[i + 2],
                        pkt.options[i + 3],
                        pkt.options[i + 4],
                        pkt.options[i + 5],
                    };
                }
            },
            DHCP_OPT_ROUTER => {
                if (len >= 4) {
                    config.gateway = [_]u8{
                        pkt.options[i + 2],
                        pkt.options[i + 3],
                        pkt.options[i + 4],
                        pkt.options[i + 5],
                    };
                }
            },
            DHCP_OPT_DNS => {
                if (len >= 4) {
                    config.dns_server = [_]u8{
                        pkt.options[i + 2],
                        pkt.options[i + 3],
                        pkt.options[i + 4],
                        pkt.options[i + 5],
                    };
                }
            },
            DHCP_OPT_LEASE_TIME => {
                if (len >= 4) {
                    config.lease_time = (@as(u32, pkt.options[i + 2]) << 24) |
                        (@as(u32, pkt.options[i + 3]) << 16) |
                        (@as(u32, pkt.options[i + 4]) << 8) |
                        @as(u32, pkt.options[i + 5]);
                }
            },
            DHCP_OPT_SERVER_ID => {
                if (len >= 4) {
                    config.server_id = [_]u8{
                        pkt.options[i + 2],
                        pkt.options[i + 3],
                        pkt.options[i + 4],
                        pkt.options[i + 5],
                    };
                }
            },
            else => {},
        }

        i += 2 + len;
    }

    config.valid = !ipv4.ipIsZero(config.ip_address);
    return config;
}

/// Get DHCP message type from packet
pub fn getMessageType(pkt: *const DhcpPacket) ?u8 {
    // Check magic cookie
    const cookie = (@as(u32, pkt.options[0]) << 24) |
        (@as(u32, pkt.options[1]) << 16) |
        (@as(u32, pkt.options[2]) << 8) |
        @as(u32, pkt.options[3]);

    if (cookie != DHCP_MAGIC_COOKIE) return null;

    var i: usize = 4;
    while (i < pkt.options.len) {
        const opt = pkt.options[i];

        if (opt == DHCP_OPT_PAD) {
            i += 1;
            continue;
        }
        if (opt == DHCP_OPT_END) break;
        if (i + 1 >= pkt.options.len) break;

        const len = pkt.options[i + 1];

        if (opt == DHCP_OPT_MSG_TYPE and len >= 1) {
            return pkt.options[i + 2];
        }

        i += 2 + len;
    }
    return null;
}

/// Process incoming DHCP packet
pub fn processPacket(pkt: *const DhcpPacket) void {
    // Verify it's a reply
    if (pkt.op != 2) return;

    // Verify transaction ID
    if (ethernet.ntohl(pkt.xid) != dhcp_xid) return;

    const msg_type = getMessageType(pkt) orelse return;

    switch (msg_type) {
        DHCP_OFFER => {
            if (dhcp_state == .discovering) {
                serial.write("DHCP: Received OFFER - IP ");
                ipv4.printIp(pkt.yiaddr);
                serial.write("\n");

                // Parse and store offered config
                dhcp_config = parseOptions(pkt);
                dhcp_state = .requesting;
            }
        },
        DHCP_ACK => {
            if (dhcp_state == .requesting) {
                serial.write("DHCP: Received ACK - Bound!\n");
                dhcp_config = parseOptions(pkt);
                dhcp_state = .bound;

                serial.write("DHCP: IP = ");
                ipv4.printIp(dhcp_config.ip_address);
                serial.write("\nDHCP: Subnet = ");
                ipv4.printIp(dhcp_config.subnet_mask);
                serial.write("\nDHCP: Gateway = ");
                ipv4.printIp(dhcp_config.gateway);
                serial.write("\nDHCP: DNS = ");
                ipv4.printIp(dhcp_config.dns_server);
                serial.write("\n");
            }
        },
        DHCP_NAK => {
            serial.write("DHCP: Received NAK - Request denied\n");
            dhcp_state = .idle;
            dhcp_config = DhcpConfig.init();
        },
        else => {},
    }
}

/// Start DHCP discovery
pub fn startDiscover() void {
    dhcp_xid += 1; // New transaction
    dhcp_state = .discovering;
    dhcp_config = DhcpConfig.init();
    serial.write("DHCP: Starting discovery...\n");
}

/// Set state to requesting (after sending request)
pub fn setRequesting() void {
    dhcp_state = .requesting;
}

/// Get offered IP (for request)
pub fn getOfferedIp() ipv4.IPv4Address {
    return dhcp_config.ip_address;
}

/// Get server ID (for request)
pub fn getServerId() ipv4.IPv4Address {
    return dhcp_config.server_id;
}
