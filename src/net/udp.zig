// Home OS - UDP (User Datagram Protocol)
// Copyright © 2025 Romy Rianata - Home OS
// Phase 13: Network Stack - UDP

const serial = @import("../drivers/serial.zig");
const ethernet = @import("ethernet.zig");
const ipv4 = @import("ipv4.zig");

// UDP Header (8 bytes)
pub const UdpHeader = extern struct {
    src_port: u16,
    dest_port: u16,
    length: u16,
    checksum: u16,

    pub fn init() UdpHeader {
        return UdpHeader{
            .src_port = 0,
            .dest_port = 0,
            .length = 0,
            .checksum = 0,
        };
    }

    pub fn getSrcPort(self: *const UdpHeader) u16 {
        return ethernet.ntohs(self.src_port);
    }

    pub fn setSrcPort(self: *UdpHeader, port: u16) void {
        self.src_port = ethernet.htons(port);
    }

    pub fn getDestPort(self: *const UdpHeader) u16 {
        return ethernet.ntohs(self.dest_port);
    }

    pub fn setDestPort(self: *UdpHeader, port: u16) void {
        self.dest_port = ethernet.htons(port);
    }

    pub fn getLength(self: *const UdpHeader) u16 {
        return ethernet.ntohs(self.length);
    }

    pub fn setLength(self: *UdpHeader, len: u16) void {
        self.length = ethernet.htons(len);
    }
};

// UDP Packet
pub const UdpPacket = struct {
    header: UdpHeader,
    data: [1472]u8, // Max UDP payload (MTU - IP header - UDP header)
    data_len: usize,

    pub fn init() UdpPacket {
        return UdpPacket{
            .header = UdpHeader.init(),
            .data = undefined,
            .data_len = 0,
        };
    }

    pub fn create(src_port: u16, dest_port: u16, data: []const u8) UdpPacket {
        var pkt = UdpPacket.init();
        pkt.header.setSrcPort(src_port);
        pkt.header.setDestPort(dest_port);

        const len = @min(data.len, pkt.data.len);
        for (data[0..len], 0..) |byte, i| {
            pkt.data[i] = byte;
        }
        pkt.data_len = len;

        // Length = header (8) + data
        pkt.header.setLength(8 + @as(u16, @intCast(len)));

        return pkt;
    }

    pub fn totalLength(self: *const UdpPacket) usize {
        return 8 + self.data_len;
    }
};

// UDP Socket
pub const MAX_UDP_SOCKETS: usize = 16;
pub const UDP_RECV_BUFFER_SIZE: usize = 4096;

pub const UdpSocket = struct {
    local_port: u16,
    remote_ip: ipv4.IPv4Address,
    remote_port: u16,
    recv_buffer: [UDP_RECV_BUFFER_SIZE]u8,
    recv_len: usize,
    bound: bool,
    connected: bool,

    pub fn init() UdpSocket {
        return UdpSocket{
            .local_port = 0,
            .remote_ip = ipv4.ZERO_IP,
            .remote_port = 0,
            .recv_buffer = undefined,
            .recv_len = 0,
            .bound = false,
            .connected = false,
        };
    }

    pub fn bind(self: *UdpSocket, port: u16) bool {
        if (self.bound) return false;
        self.local_port = port;
        self.bound = true;
        return true;
    }

    pub fn connect(self: *UdpSocket, ip: ipv4.IPv4Address, port: u16) void {
        self.remote_ip = ip;
        self.remote_port = port;
        self.connected = true;
    }

    pub fn close(self: *UdpSocket) void {
        self.bound = false;
        self.connected = false;
        self.local_port = 0;
        self.recv_len = 0;
    }
};

// Socket table
var udp_sockets: [MAX_UDP_SOCKETS]UdpSocket = undefined;
var udp_initialized: bool = false;
var next_ephemeral_port: u16 = 49152; // Start of ephemeral range

pub fn init() void {
    serial.write("UDP: Initializing...\n");
    for (&udp_sockets) |*sock| {
        sock.* = UdpSocket.init();
    }
    udp_initialized = true;
    serial.write("UDP: Ready\n");
}

/// Allocate a socket
pub fn socket() ?u32 {
    for (&udp_sockets, 0..) |*sock, i| {
        if (!sock.bound) {
            sock.* = UdpSocket.init();
            return @truncate(i);
        }
    }
    return null;
}

/// Get socket by ID
pub fn getSocket(id: u32) ?*UdpSocket {
    if (id >= MAX_UDP_SOCKETS) return null;
    return &udp_sockets[id];
}

/// Bind socket to port
pub fn bind(sock_id: u32, port: u16) bool {
    const sock = getSocket(sock_id) orelse return false;

    // Check if port already in use
    for (udp_sockets) |s| {
        if (s.bound and s.local_port == port) {
            return false;
        }
    }

    return sock.bind(port);
}

/// Get ephemeral port
pub fn getEphemeralPort() u16 {
    const port = next_ephemeral_port;
    next_ephemeral_port += 1;
    if (next_ephemeral_port >= 65535) {
        next_ephemeral_port = 49152;
    }
    return port;
}

/// Find socket by local port
pub fn findByPort(port: u16) ?*UdpSocket {
    for (&udp_sockets) |*sock| {
        if (sock.bound and sock.local_port == port) {
            return sock;
        }
    }
    return null;
}

/// Get active socket count
pub fn getSocketCount() u32 {
    var count: u32 = 0;
    for (udp_sockets) |sock| {
        if (sock.bound) count += 1;
    }
    return count;
}
