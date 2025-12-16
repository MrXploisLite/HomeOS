// Home OS - TCP Protocol
// Copyright © 2025 Romy Rianata - Home OS
// Phase 19: Networking Completion - TCP

const serial = @import("../drivers/serial.zig");
const ethernet = @import("ethernet.zig");
const ipv4 = @import("ipv4.zig");

// TCP Flags
pub const TCP_FIN: u8 = 0x01;
pub const TCP_SYN: u8 = 0x02;
pub const TCP_RST: u8 = 0x04;
pub const TCP_PSH: u8 = 0x08;
pub const TCP_ACK: u8 = 0x10;
pub const TCP_URG: u8 = 0x20;

// TCP States
pub const TcpState = enum {
    closed,
    listen,
    syn_sent,
    syn_received,
    established,
    fin_wait_1,
    fin_wait_2,
    close_wait,
    closing,
    last_ack,
    time_wait,
};

// TCP Header (20 bytes minimum)
pub const TcpHeader = extern struct {
    src_port: u16, // Source port
    dest_port: u16, // Destination port
    seq_num: u32, // Sequence number
    ack_num: u32, // Acknowledgment number
    data_offset: u8, // Data offset (4 bits) + Reserved (4 bits)
    flags: u8, // Flags
    window: u16, // Window size
    checksum: u16, // Checksum
    urgent_ptr: u16, // Urgent pointer

    pub fn init() TcpHeader {
        return TcpHeader{
            .src_port = 0,
            .dest_port = 0,
            .seq_num = 0,
            .ack_num = 0,
            .data_offset = 0x50, // 5 * 4 = 20 bytes (no options)
            .flags = 0,
            .window = 0,
            .checksum = 0,
            .urgent_ptr = 0,
        };
    }

    pub fn getSrcPort(self: *const TcpHeader) u16 {
        return ethernet.ntohs(self.src_port);
    }

    pub fn setSrcPort(self: *TcpHeader, port: u16) void {
        self.src_port = ethernet.htons(port);
    }

    pub fn getDestPort(self: *const TcpHeader) u16 {
        return ethernet.ntohs(self.dest_port);
    }

    pub fn setDestPort(self: *TcpHeader, port: u16) void {
        self.dest_port = ethernet.htons(port);
    }

    pub fn getSeqNum(self: *const TcpHeader) u32 {
        return ethernet.ntohl(self.seq_num);
    }

    pub fn setSeqNum(self: *TcpHeader, seq: u32) void {
        self.seq_num = ethernet.htonl(seq);
    }

    pub fn getAckNum(self: *const TcpHeader) u32 {
        return ethernet.ntohl(self.ack_num);
    }

    pub fn setAckNum(self: *TcpHeader, ack: u32) void {
        self.ack_num = ethernet.htonl(ack);
    }

    pub fn getHeaderLength(self: *const TcpHeader) u8 {
        return (self.data_offset >> 4) * 4;
    }

    pub fn setHeaderLength(self: *TcpHeader, len: u8) void {
        self.data_offset = (len / 4) << 4;
    }

    pub fn getWindow(self: *const TcpHeader) u16 {
        return ethernet.ntohs(self.window);
    }

    pub fn setWindow(self: *TcpHeader, win: u16) void {
        self.window = ethernet.htons(win);
    }

    pub fn hasFlag(self: *const TcpHeader, flag: u8) bool {
        return (self.flags & flag) != 0;
    }

    pub fn setFlag(self: *TcpHeader, flag: u8) void {
        self.flags |= flag;
    }

    pub fn clearFlags(self: *TcpHeader) void {
        self.flags = 0;
    }
};

// TCP Socket
pub const MAX_TCP_SOCKETS: usize = 16;
pub const TCP_RECV_BUFFER_SIZE: usize = 8192;
pub const TCP_SEND_BUFFER_SIZE: usize = 8192;

pub const TcpSocket = struct {
    state: TcpState,
    local_port: u16,
    remote_port: u16,
    remote_ip: ipv4.IPv4Address,

    // Sequence numbers
    send_seq: u32, // Next sequence number to send
    send_ack: u32, // Last acknowledged
    recv_seq: u32, // Next expected sequence
    recv_ack: u32, // Last sent ack

    // Buffers
    recv_buffer: [TCP_RECV_BUFFER_SIZE]u8,
    recv_len: usize,
    send_buffer: [TCP_SEND_BUFFER_SIZE]u8,
    send_len: usize,

    // Flags
    bound: bool,
    connected: bool,

    pub fn init() TcpSocket {
        return TcpSocket{
            .state = .closed,
            .local_port = 0,
            .remote_port = 0,
            .remote_ip = ipv4.ZERO_IP,
            .send_seq = 0,
            .send_ack = 0,
            .recv_seq = 0,
            .recv_ack = 0,
            .recv_buffer = undefined,
            .recv_len = 0,
            .send_buffer = undefined,
            .send_len = 0,
            .bound = false,
            .connected = false,
        };
    }

    pub fn bind(self: *TcpSocket, port: u16) bool {
        if (self.bound) return false;
        self.local_port = port;
        self.bound = true;
        self.state = .closed;
        return true;
    }

    pub fn close(self: *TcpSocket) void {
        self.state = .closed;
        self.bound = false;
        self.connected = false;
        self.local_port = 0;
        self.recv_len = 0;
        self.send_len = 0;
    }
};

// Socket table
var tcp_sockets: [MAX_TCP_SOCKETS]TcpSocket = undefined;
var tcp_initialized: bool = false;
var next_ephemeral_port: u16 = 49152;
var initial_seq: u32 = 0x12345678;

pub fn init() void {
    serial.write("TCP: Initializing...\n");
    for (&tcp_sockets) |*sock| {
        sock.* = TcpSocket.init();
    }
    tcp_initialized = true;
    serial.write("TCP: Ready\n");
}

/// Allocate a socket
pub fn socket() ?u32 {
    for (&tcp_sockets, 0..) |*sock, i| {
        if (!sock.bound and sock.state == .closed) {
            sock.* = TcpSocket.init();
            return @truncate(i);
        }
    }
    return null;
}

/// Get socket by ID
pub fn getSocket(id: u32) ?*TcpSocket {
    if (id >= MAX_TCP_SOCKETS) return null;
    return &tcp_sockets[id];
}

/// Bind socket to port
pub fn bind(sock_id: u32, port: u16) bool {
    const sock = getSocket(sock_id) orelse return false;

    // Check if port already in use
    for (tcp_sockets) |s| {
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

/// Generate initial sequence number
fn getInitialSeq() u32 {
    initial_seq +%= 64000; // Increment by ~64K each time
    return initial_seq;
}

/// Find socket by local port and remote endpoint
pub fn findSocket(local_port: u16, remote_ip: ipv4.IPv4Address, remote_port: u16) ?*TcpSocket {
    for (&tcp_sockets) |*sock| {
        if (sock.bound and sock.local_port == local_port) {
            if (sock.state == .listen) {
                return sock;
            }
            if (ipv4.ipEqual(sock.remote_ip, remote_ip) and sock.remote_port == remote_port) {
                return sock;
            }
        }
    }
    return null;
}

/// Find socket by local port only (for listening)
pub fn findByPort(port: u16) ?*TcpSocket {
    for (&tcp_sockets) |*sock| {
        if (sock.bound and sock.local_port == port) {
            return sock;
        }
    }
    return null;
}

/// Create TCP SYN packet (for connect)
pub fn createSyn(sock: *TcpSocket, buf: []u8) usize {
    if (buf.len < 20) return 0;

    var header: *TcpHeader = @ptrCast(@alignCast(buf.ptr));
    header.* = TcpHeader.init();

    sock.send_seq = getInitialSeq();

    header.setSrcPort(sock.local_port);
    header.setDestPort(sock.remote_port);
    header.setSeqNum(sock.send_seq);
    header.setAckNum(0);
    header.setHeaderLength(20);
    header.setFlag(TCP_SYN);
    header.setWindow(8192);

    return 20;
}

/// Create TCP SYN-ACK packet (for accept)
pub fn createSynAck(sock: *TcpSocket, buf: []u8) usize {
    if (buf.len < 20) return 0;

    var header: *TcpHeader = @ptrCast(@alignCast(buf.ptr));
    header.* = TcpHeader.init();

    header.setSrcPort(sock.local_port);
    header.setDestPort(sock.remote_port);
    header.setSeqNum(sock.send_seq);
    header.setAckNum(sock.recv_seq);
    header.setHeaderLength(20);
    header.setFlag(TCP_SYN);
    header.setFlag(TCP_ACK);
    header.setWindow(8192);

    return 20;
}

/// Create TCP ACK packet
pub fn createAck(sock: *TcpSocket, buf: []u8) usize {
    if (buf.len < 20) return 0;

    var header: *TcpHeader = @ptrCast(@alignCast(buf.ptr));
    header.* = TcpHeader.init();

    header.setSrcPort(sock.local_port);
    header.setDestPort(sock.remote_port);
    header.setSeqNum(sock.send_seq);
    header.setAckNum(sock.recv_seq);
    header.setHeaderLength(20);
    header.setFlag(TCP_ACK);
    header.setWindow(8192);

    return 20;
}

/// Create TCP FIN packet
pub fn createFin(sock: *TcpSocket, buf: []u8) usize {
    if (buf.len < 20) return 0;

    var header: *TcpHeader = @ptrCast(@alignCast(buf.ptr));
    header.* = TcpHeader.init();

    header.setSrcPort(sock.local_port);
    header.setDestPort(sock.remote_port);
    header.setSeqNum(sock.send_seq);
    header.setAckNum(sock.recv_seq);
    header.setHeaderLength(20);
    header.setFlag(TCP_FIN);
    header.setFlag(TCP_ACK);
    header.setWindow(8192);

    return 20;
}

/// Create TCP data packet
pub fn createData(sock: *TcpSocket, data: []const u8, buf: []u8) usize {
    if (buf.len < 20 + data.len) return 0;

    var header: *TcpHeader = @ptrCast(@alignCast(buf.ptr));
    header.* = TcpHeader.init();

    header.setSrcPort(sock.local_port);
    header.setDestPort(sock.remote_port);
    header.setSeqNum(sock.send_seq);
    header.setAckNum(sock.recv_seq);
    header.setHeaderLength(20);
    header.setFlag(TCP_ACK);
    header.setFlag(TCP_PSH);
    header.setWindow(8192);

    // Copy data
    for (data, 0..) |b, i| {
        buf[20 + i] = b;
    }

    return 20 + data.len;
}

/// Process incoming TCP packet
pub fn processPacket(src_ip: ipv4.IPv4Address, header: *const TcpHeader, data: []const u8) void {
    const local_port = header.getDestPort();
    const remote_port = header.getSrcPort();

    // Find matching socket
    const sock = findSocket(local_port, src_ip, remote_port) orelse {
        // No socket found, could send RST
        return;
    };

    const seq = header.getSeqNum();
    const ack = header.getAckNum();

    switch (sock.state) {
        .listen => {
            if (header.hasFlag(TCP_SYN) and !header.hasFlag(TCP_ACK)) {
                // Incoming connection
                serial.write("TCP: SYN received on port ");
                serial.writeInt(local_port);
                serial.write("\n");

                sock.remote_ip = src_ip;
                sock.remote_port = remote_port;
                sock.recv_seq = seq + 1;
                sock.send_seq = getInitialSeq();
                sock.state = .syn_received;
            }
        },
        .syn_sent => {
            if (header.hasFlag(TCP_SYN) and header.hasFlag(TCP_ACK)) {
                // SYN-ACK received
                if (ack == sock.send_seq + 1) {
                    serial.write("TCP: SYN-ACK received\n");
                    sock.send_seq = ack;
                    sock.recv_seq = seq + 1;
                    sock.state = .established;
                    sock.connected = true;
                }
            }
        },
        .syn_received => {
            if (header.hasFlag(TCP_ACK)) {
                if (ack == sock.send_seq + 1) {
                    serial.write("TCP: Connection established\n");
                    sock.send_seq = ack;
                    sock.state = .established;
                    sock.connected = true;
                }
            }
        },
        .established => {
            if (header.hasFlag(TCP_FIN)) {
                // Remote closing
                serial.write("TCP: FIN received\n");
                sock.recv_seq = seq + 1;
                sock.state = .close_wait;
            } else if (header.hasFlag(TCP_ACK)) {
                // Data or ACK
                if (data.len > 0) {
                    // Received data
                    const copy_len = @min(data.len, TCP_RECV_BUFFER_SIZE - sock.recv_len);
                    for (data[0..copy_len], 0..) |b, i| {
                        sock.recv_buffer[sock.recv_len + i] = b;
                    }
                    sock.recv_len += copy_len;
                    sock.recv_seq = seq + @as(u32, @truncate(data.len));
                }
                sock.send_ack = ack;
            }
        },
        .fin_wait_1 => {
            if (header.hasFlag(TCP_ACK)) {
                sock.state = .fin_wait_2;
            }
            if (header.hasFlag(TCP_FIN)) {
                sock.recv_seq = seq + 1;
                sock.state = .time_wait;
            }
        },
        .fin_wait_2 => {
            if (header.hasFlag(TCP_FIN)) {
                sock.recv_seq = seq + 1;
                sock.state = .time_wait;
            }
        },
        .close_wait => {
            // Waiting for application to close
        },
        .last_ack => {
            if (header.hasFlag(TCP_ACK)) {
                sock.state = .closed;
                sock.connected = false;
            }
        },
        .time_wait => {
            // Wait for 2*MSL then close
            sock.state = .closed;
            sock.connected = false;
        },
        else => {},
    }
}

/// Get active socket count
pub fn getSocketCount() u32 {
    var count: u32 = 0;
    for (tcp_sockets) |sock| {
        if (sock.bound or sock.state != .closed) count += 1;
    }
    return count;
}

/// Get state name
pub fn getStateName(state: TcpState) []const u8 {
    return switch (state) {
        .closed => "CLOSED",
        .listen => "LISTEN",
        .syn_sent => "SYN_SENT",
        .syn_received => "SYN_RCVD",
        .established => "ESTABLISHED",
        .fin_wait_1 => "FIN_WAIT_1",
        .fin_wait_2 => "FIN_WAIT_2",
        .close_wait => "CLOSE_WAIT",
        .closing => "CLOSING",
        .last_ack => "LAST_ACK",
        .time_wait => "TIME_WAIT",
    };
}
