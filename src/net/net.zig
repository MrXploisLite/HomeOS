// Home OS - Network Stack
// Copyright © 2025 Romy Rianata - Home OS
// Phase 13: Networking

const serial = @import("../drivers/serial.zig");

pub const ethernet = @import("ethernet.zig");
pub const ipv4 = @import("ipv4.zig");
pub const arp = @import("arp.zig");
pub const icmp = @import("icmp.zig");
pub const udp = @import("udp.zig");
pub const tcp = @import("tcp.zig");
pub const dhcp = @import("dhcp.zig");
pub const dns = @import("dns.zig");
pub const rtl8139 = @import("rtl8139.zig");
pub const firewall = @import("firewall.zig");
pub const tls = @import("tls.zig");
pub const mac = @import("mac.zig");
pub const http = @import("http.zig");
pub const socks5 = @import("socks5.zig");
pub const onion = @import("onion.zig");
pub const circuit = @import("circuit.zig");
pub const tor = @import("tor.zig");

// Network configuration
pub const NetConfig = struct {
    ip_address: ipv4.IPv4Address,
    subnet_mask: ipv4.IPv4Address,
    gateway: ipv4.IPv4Address,
    dns_server: ipv4.IPv4Address,
    configured: bool,

    pub fn init() NetConfig {
        return NetConfig{
            .ip_address = ipv4.ZERO_IP,
            .subnet_mask = ipv4.ZERO_IP,
            .gateway = ipv4.ZERO_IP,
            .dns_server = ipv4.ZERO_IP,
            .configured = false,
        };
    }
};

var net_config: NetConfig = NetConfig.init();
var net_initialized: bool = false;

/// Initialize network stack
pub fn init() bool {
    serial.write("NET: Initializing network stack...\n");

    // Initialize ARP cache
    arp.init();

    // Initialize ICMP
    icmp.init();

    // Initialize UDP
    udp.init();

    // Initialize TCP
    tcp.init();

    // Initialize DHCP
    dhcp.init();

    // Initialize DNS
    dns.init();

    // Initialize Firewall
    firewall.init();

    // Initialize TLS
    tls.init();

    // Initialize NIC driver
    if (!rtl8139.init()) {
        serial.write("NET: No network card found\n");
        serial.write("NET: Running in offline mode\n");
        net_initialized = true;
        return true; // Still initialize stack for testing
    }

    net_initialized = true;

    // Initialize MAC randomization (after NIC init)
    mac.init();

    // Set default configuration (can be changed via DHCP or manual)
    setConfig(
        [_]u8{ 10, 0, 2, 15 }, // IP (QEMU default)
        [_]u8{ 255, 255, 255, 0 }, // Subnet
        [_]u8{ 10, 0, 2, 2 }, // Gateway
        [_]u8{ 10, 0, 2, 3 }, // DNS
    );

    // Pre-populate ARP cache with QEMU gateway MAC
    // QEMU user-mode networking uses 52:55:0a:00:02:02 for gateway
    arp.addEntry([_]u8{ 10, 0, 2, 2 }, [_]u8{ 0x52, 0x55, 0x0a, 0x00, 0x02, 0x02 }, 0);

    serial.write("NET: Network stack ready\n");
    return true;
}

/// Set network configuration
pub fn setConfig(ip: ipv4.IPv4Address, mask: ipv4.IPv4Address, gw: ipv4.IPv4Address, dns_server: ipv4.IPv4Address) void {
    net_config.ip_address = ip;
    net_config.subnet_mask = mask;
    net_config.gateway = gw;
    net_config.dns_server = dns_server;
    net_config.configured = true;

    serial.write("NET: IP = ");
    ipv4.printIp(ip);
    serial.write("\n");
}

/// Get network configuration
pub fn getConfig() *const NetConfig {
    return &net_config;
}

/// Check if network is initialized
pub fn isInitialized() bool {
    return net_initialized;
}

/// Check if network is configured
pub fn isConfigured() bool {
    return net_config.configured;
}

/// Check if NIC is present
pub fn hasNic() bool {
    return rtl8139.isInitialized();
}

/// Get local IP address
pub fn getLocalIp() ipv4.IPv4Address {
    return net_config.ip_address;
}

/// Get local MAC address
pub fn getLocalMac() ethernet.MacAddress {
    if (rtl8139.isInitialized()) {
        return rtl8139.getMacAddress();
    }
    return ethernet.ZERO_MAC;
}

/// Send raw Ethernet frame
pub fn sendEthernet(dest_mac: ethernet.MacAddress, ethertype: u16, payload: []const u8) bool {
    if (!rtl8139.isInitialized()) return false;

    var frame: [ethernet.ETH_FRAME_MAX]u8 = undefined;

    // Build Ethernet header
    var i: usize = 0;
    while (i < 6) : (i += 1) {
        frame[i] = dest_mac[i];
        frame[i + 6] = rtl8139.getMacAddress()[i];
    }
    frame[12] = @truncate(ethertype >> 8);
    frame[13] = @truncate(ethertype & 0xFF);

    // Copy payload
    const payload_len = @min(payload.len, ethernet.ETH_MTU);
    for (payload[0..payload_len], 0..) |byte, j| {
        frame[14 + j] = byte;
    }

    return rtl8139.send(frame[0 .. 14 + payload_len]);
}

/// Send ARP request
pub fn sendArpRequest(target_ip: ipv4.IPv4Address) bool {
    const pkt = arp.createRequest(getLocalMac(), getLocalIp(), target_ip);
    const pkt_bytes: [*]const u8 = @ptrCast(&pkt);
    return sendEthernet(ethernet.BROADCAST_MAC, ethernet.ETH_TYPE_ARP, pkt_bytes[0..@sizeOf(arp.ArpPacket)]);
}

/// Send IPv4 packet
pub fn sendIpv4(dest_ip: ipv4.IPv4Address, protocol: u8, payload: []const u8) bool {
    // Build IP header
    var ip_header = ipv4.IPv4Header.init();
    ip_header.src_ip = getLocalIp();
    ip_header.dest_ip = dest_ip;
    ip_header.protocol = protocol;
    ip_header.setTotalLength(@truncate(20 + payload.len));
    ip_header.calculateChecksum();

    // Build packet
    var packet: [ethernet.ETH_MTU]u8 = undefined;
    const header_bytes: [*]const u8 = @ptrCast(&ip_header);

    for (header_bytes[0..20], 0..) |byte, i| {
        packet[i] = byte;
    }
    for (payload, 0..) |byte, i| {
        packet[20 + i] = byte;
    }

    // Get destination MAC
    var dest_mac: ethernet.MacAddress = undefined;

    // Check if same subnet
    const local_net = ipv4.ipToU32(getLocalIp()) & ipv4.ipToU32(net_config.subnet_mask);
    const dest_net = ipv4.ipToU32(dest_ip) & ipv4.ipToU32(net_config.subnet_mask);

    const next_hop = if (local_net == dest_net) dest_ip else net_config.gateway;

    // Lookup MAC in ARP cache
    if (arp.lookup(next_hop)) |found_mac| {
        dest_mac = found_mac;
    } else {
        // Need to send ARP request first
        _ = sendArpRequest(next_hop);
        return false; // Packet will need to be retried
    }

    return sendEthernet(dest_mac, ethernet.ETH_TYPE_IPV4, packet[0 .. 20 + payload.len]);
}

/// Send ICMP echo request (ping)
pub fn ping(dest_ip: ipv4.IPv4Address) bool {
    const echo = icmp.createPingRequest();
    const echo_bytes: [*]const u8 = @ptrCast(&echo);
    return sendIpv4(dest_ip, ipv4.IPPROTO_ICMP, echo_bytes[0 .. 8 + echo.data_len]);
}

/// Send UDP packet
pub fn sendUdp(dest_ip: ipv4.IPv4Address, src_port: u16, dest_port: u16, data: []const u8) bool {
    const pkt = udp.UdpPacket.create(src_port, dest_port, data);
    const pkt_bytes: [*]const u8 = @ptrCast(&pkt);
    return sendIpv4(dest_ip, ipv4.IPPROTO_UDP, pkt_bytes[0..pkt.totalLength()]);
}

/// Get network statistics
pub fn getStats() struct {
    nic_present: bool,
    link_up: bool,
    rx_packets: u32,
    tx_packets: u32,
    arp_entries: u32,
    udp_sockets: u32,
    tcp_sockets: u32,
    dns_cache: u32,
    dhcp_bound: bool,
    firewall_enabled: bool,
    firewall_rules: usize,
    mac_randomized: bool,
    tls_sessions: usize,
} {
    const nic_stats = rtl8139.getStats();
    return .{
        .nic_present = rtl8139.isInitialized(),
        .link_up = rtl8139.isLinkUp(),
        .rx_packets = nic_stats.rx,
        .tx_packets = nic_stats.tx,
        .arp_entries = arp.getCacheCount(),
        .udp_sockets = udp.getSocketCount(),
        .tcp_sockets = tcp.getSocketCount(),
        .dns_cache = dns.getCacheCount(),
        .dhcp_bound = dhcp.isBound(),
        .firewall_enabled = firewall.isEnabled(),
        .firewall_rules = firewall.getRuleCount(),
        .mac_randomized = mac.isRandomized(),
        .tls_sessions = tls.getActiveSessionCount(),
    };
}

/// Send DHCP Discover
pub fn sendDhcpDiscover() bool {
    if (!rtl8139.isInitialized()) return false;

    dhcp.startDiscover();
    const pkt = dhcp.createDiscover(getLocalMac());

    // Build UDP packet with DHCP
    var udp_buf: [600]u8 = undefined;
    const pkt_bytes: [*]const u8 = @ptrCast(&pkt);

    // UDP header
    var udp_header = udp.UdpHeader.init();
    udp_header.setSrcPort(dhcp.DHCP_CLIENT_PORT);
    udp_header.setDestPort(dhcp.DHCP_SERVER_PORT);
    udp_header.setLength(@truncate(8 + @sizeOf(dhcp.DhcpPacket)));

    const udp_hdr_bytes: [*]const u8 = @ptrCast(&udp_header);
    for (udp_hdr_bytes[0..8], 0..) |b, i| {
        udp_buf[i] = b;
    }
    for (pkt_bytes[0..@sizeOf(dhcp.DhcpPacket)], 0..) |b, i| {
        udp_buf[8 + i] = b;
    }

    // Build IP header for broadcast
    var ip_header = ipv4.IPv4Header.init();
    ip_header.src_ip = ipv4.ZERO_IP;
    ip_header.dest_ip = ipv4.BROADCAST_IP;
    ip_header.protocol = ipv4.IPPROTO_UDP;
    ip_header.setTotalLength(@truncate(20 + 8 + @sizeOf(dhcp.DhcpPacket)));
    ip_header.calculateChecksum();

    var packet: [ethernet.ETH_MTU]u8 = undefined;
    const ip_hdr_bytes: [*]const u8 = @ptrCast(&ip_header);

    for (ip_hdr_bytes[0..20], 0..) |b, i| {
        packet[i] = b;
    }
    const udp_len = 8 + @sizeOf(dhcp.DhcpPacket);
    for (udp_buf[0..udp_len], 0..) |b, i| {
        packet[20 + i] = b;
    }

    return sendEthernet(ethernet.BROADCAST_MAC, ethernet.ETH_TYPE_IPV4, packet[0 .. 20 + udp_len]);
}

/// Send DHCP Request
pub fn sendDhcpRequest() bool {
    if (!rtl8139.isInitialized()) return false;

    const pkt = dhcp.createRequest(getLocalMac(), dhcp.getOfferedIp(), dhcp.getServerId());
    dhcp.setRequesting();

    var udp_buf: [600]u8 = undefined;
    const pkt_bytes: [*]const u8 = @ptrCast(&pkt);

    var udp_header = udp.UdpHeader.init();
    udp_header.setSrcPort(dhcp.DHCP_CLIENT_PORT);
    udp_header.setDestPort(dhcp.DHCP_SERVER_PORT);
    udp_header.setLength(@truncate(8 + @sizeOf(dhcp.DhcpPacket)));

    const udp_hdr_bytes: [*]const u8 = @ptrCast(&udp_header);
    for (udp_hdr_bytes[0..8], 0..) |b, i| {
        udp_buf[i] = b;
    }
    for (pkt_bytes[0..@sizeOf(dhcp.DhcpPacket)], 0..) |b, i| {
        udp_buf[8 + i] = b;
    }

    var ip_header = ipv4.IPv4Header.init();
    ip_header.src_ip = ipv4.ZERO_IP;
    ip_header.dest_ip = ipv4.BROADCAST_IP;
    ip_header.protocol = ipv4.IPPROTO_UDP;
    ip_header.setTotalLength(@truncate(20 + 8 + @sizeOf(dhcp.DhcpPacket)));
    ip_header.calculateChecksum();

    var packet: [ethernet.ETH_MTU]u8 = undefined;
    const ip_hdr_bytes: [*]const u8 = @ptrCast(&ip_header);

    for (ip_hdr_bytes[0..20], 0..) |b, i| {
        packet[i] = b;
    }
    const udp_len = 8 + @sizeOf(dhcp.DhcpPacket);
    for (udp_buf[0..udp_len], 0..) |b, i| {
        packet[20 + i] = b;
    }

    return sendEthernet(ethernet.BROADCAST_MAC, ethernet.ETH_TYPE_IPV4, packet[0 .. 20 + udp_len]);
}

/// Send DNS query
pub fn sendDnsQuery(name: []const u8) bool {
    if (!rtl8139.isInitialized()) return false;

    var query_buf: [512]u8 = undefined;
    const query_len = dns.createQuery(name, &query_buf);
    if (query_len == 0) return false;

    return sendUdp(net_config.dns_server, 53, dns.DNS_PORT, query_buf[0..query_len]);
}

/// Resolve hostname to IP (blocking-ish, needs polling)
pub fn resolve(name: []const u8) ?ipv4.IPv4Address {
    // Check cache first
    if (dns.cacheLookup(name)) |ip| {
        return ip;
    }

    // Send query
    if (!sendDnsQuery(name)) return null;

    // Would need to wait for response - return null for now
    // Caller should poll dns.isResolved() and dns.getResolvedIp()
    return null;
}

/// Send TCP packet
pub fn sendTcp(dest_ip: ipv4.IPv4Address, tcp_data: []const u8) bool {
    return sendIpv4(dest_ip, ipv4.IPPROTO_TCP, tcp_data);
}
