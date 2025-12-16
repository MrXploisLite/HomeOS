// Home OS - Onion Routing Protocol
// Copyright © 2025 Romy Rianata - Home OS
// Phase 26: Onion Routing - Core Protocol

const serial = @import("../drivers/serial.zig");
const crypto = @import("../crypto/crypto.zig");
const sha256 = @import("../crypto/sha256.zig");
const ipv4 = @import("ipv4.zig");

// Onion routing constants
pub const CELL_SIZE: usize = 512;
pub const PAYLOAD_SIZE: usize = 498; // CELL_SIZE - header
pub const MAX_HOPS: usize = 3;
pub const KEY_SIZE: usize = 32;
pub const NONCE_SIZE: usize = 16;

// Cell commands
pub const CMD_PADDING: u8 = 0;
pub const CMD_CREATE: u8 = 1;
pub const CMD_CREATED: u8 = 2;
pub const CMD_RELAY: u8 = 3;
pub const CMD_DESTROY: u8 = 4;
pub const CMD_CREATE_FAST: u8 = 5;
pub const CMD_CREATED_FAST: u8 = 6;
pub const CMD_EXTEND: u8 = 7;
pub const CMD_EXTENDED: u8 = 8;
pub const CMD_BEGIN: u8 = 9;
pub const CMD_END: u8 = 10;
pub const CMD_CONNECTED: u8 = 11;
pub const CMD_DATA: u8 = 12;

// Relay commands (inside encrypted relay cells)
pub const RELAY_BEGIN: u8 = 1;
pub const RELAY_DATA: u8 = 2;
pub const RELAY_END: u8 = 3;
pub const RELAY_CONNECTED: u8 = 4;
pub const RELAY_EXTEND: u8 = 6;
pub const RELAY_EXTENDED: u8 = 7;
pub const RELAY_DROP: u8 = 10;

// Node types
pub const NodeType = enum {
    entry, // Guard node
    middle, // Middle relay
    exit, // Exit node
};

// Onion node information
pub const OnionNode = struct {
    ip: ipv4.IPv4Address,
    port: u16,
    node_type: NodeType,
    public_key: [KEY_SIZE]u8,
    session_key: [KEY_SIZE]u8, // Derived session key
    active: bool,

    pub fn init() OnionNode {
        return OnionNode{
            .ip = ipv4.ZERO_IP,
            .port = 9001, // Default OR port
            .node_type = .middle,
            .public_key = [_]u8{0} ** KEY_SIZE,
            .session_key = [_]u8{0} ** KEY_SIZE,
            .active = false,
        };
    }
};

// Onion cell header (14 bytes)
pub const CellHeader = extern struct {
    circuit_id: u16, // Circuit identifier
    command: u8, // Cell command
    length: u16, // Payload length
    stream_id: u16, // Stream ID (for relay cells)
    digest: [4]u8, // First 4 bytes of digest
    _reserved: [3]u8,

    pub fn init() CellHeader {
        return CellHeader{
            .circuit_id = 0,
            .command = CMD_PADDING,
            .length = 0,
            .stream_id = 0,
            .digest = [_]u8{0} ** 4,
            ._reserved = [_]u8{0} ** 3,
        };
    }
};

// Onion cell (fixed 512 bytes)
pub const OnionCell = struct {
    header: CellHeader,
    payload: [PAYLOAD_SIZE]u8,

    pub fn init() OnionCell {
        return OnionCell{
            .header = CellHeader.init(),
            .payload = [_]u8{0} ** PAYLOAD_SIZE,
        };
    }

    pub fn setPayload(self: *OnionCell, data: []const u8) void {
        const len = @min(data.len, PAYLOAD_SIZE);
        for (data[0..len], 0..) |b, i| {
            self.payload[i] = b;
        }
        self.header.length = @truncate(len);
    }

    pub fn getPayload(self: *const OnionCell) []const u8 {
        return self.payload[0..self.header.length];
    }
};

// Simple XOR-based encryption (placeholder for real crypto)
// In production, this would use AES-CTR or ChaCha20
fn xorEncrypt(data: []u8, key: []const u8) void {
    for (data, 0..) |*b, i| {
        b.* ^= key[i % key.len];
    }
}

fn xorDecrypt(data: []u8, key: []const u8) void {
    xorEncrypt(data, key); // XOR is symmetric
}

// Encrypt cell payload with session key
pub fn encryptCell(cell: *OnionCell, key: []const u8) void {
    xorEncrypt(&cell.payload, key);
}

// Decrypt cell payload with session key
pub fn decryptCell(cell: *OnionCell, key: []const u8) void {
    xorDecrypt(&cell.payload, key);
}

// Create onion layers (wrap data in multiple encryption layers)
pub fn createOnionLayers(data: []const u8, keys: []const [KEY_SIZE]u8, output: []u8) usize {
    if (output.len < data.len) return 0;
    if (keys.len == 0) return 0;

    // Copy data to output
    const len = @min(data.len, output.len);
    for (data[0..len], 0..) |b, i| {
        output[i] = b;
    }

    // Apply encryption layers in reverse order (exit -> middle -> entry)
    var i: usize = keys.len;
    while (i > 0) {
        i -= 1;
        xorEncrypt(output[0..len], &keys[i]);
    }

    return len;
}

// Peel one onion layer (decrypt with one key)
pub fn peelOnionLayer(data: []u8, key: []const u8) void {
    xorDecrypt(data, key);
}

// Build CREATE cell for circuit establishment
pub fn buildCreateCell(circuit_id: u16, client_key_material: []const u8) OnionCell {
    var cell = OnionCell.init();
    cell.header.circuit_id = circuit_id;
    cell.header.command = CMD_CREATE_FAST;
    cell.setPayload(client_key_material);
    return cell;
}

// Build EXTEND cell to extend circuit through relay
pub fn buildExtendCell(circuit_id: u16, stream_id: u16, next_ip: ipv4.IPv4Address, next_port: u16) OnionCell {
    var cell = OnionCell.init();
    cell.header.circuit_id = circuit_id;
    cell.header.command = CMD_RELAY;
    cell.header.stream_id = stream_id;

    // Payload: relay command + address
    cell.payload[0] = RELAY_EXTEND;
    cell.payload[1] = next_ip.octets[0];
    cell.payload[2] = next_ip.octets[1];
    cell.payload[3] = next_ip.octets[2];
    cell.payload[4] = next_ip.octets[3];
    cell.payload[5] = @truncate(next_port >> 8);
    cell.payload[6] = @truncate(next_port & 0xFF);
    cell.header.length = 7;

    return cell;
}

// Build BEGIN cell to start a stream
pub fn buildBeginCell(circuit_id: u16, stream_id: u16, host: []const u8, port: u16) OnionCell {
    var cell = OnionCell.init();
    cell.header.circuit_id = circuit_id;
    cell.header.command = CMD_RELAY;
    cell.header.stream_id = stream_id;

    // Payload: relay command + host:port
    cell.payload[0] = RELAY_BEGIN;
    var offset: usize = 1;

    // Copy hostname
    const host_len = @min(host.len, 200);
    for (host[0..host_len], 0..) |c, i| {
        cell.payload[offset + i] = c;
    }
    offset += host_len;

    // Add colon
    cell.payload[offset] = ':';
    offset += 1;

    // Add port as string
    var port_buf: [6]u8 = undefined;
    const port_len = formatPort(port, &port_buf);
    for (port_buf[0..port_len], 0..) |c, i| {
        cell.payload[offset + i] = c;
    }
    offset += port_len;

    cell.header.length = @truncate(offset);
    return cell;
}

// Build DATA cell
pub fn buildDataCell(circuit_id: u16, stream_id: u16, data: []const u8) OnionCell {
    var cell = OnionCell.init();
    cell.header.circuit_id = circuit_id;
    cell.header.command = CMD_RELAY;
    cell.header.stream_id = stream_id;

    cell.payload[0] = RELAY_DATA;
    const data_len = @min(data.len, PAYLOAD_SIZE - 1);
    for (data[0..data_len], 0..) |b, i| {
        cell.payload[1 + i] = b;
    }
    cell.header.length = @truncate(data_len + 1);

    return cell;
}

// Build DESTROY cell
pub fn buildDestroyCell(circuit_id: u16) OnionCell {
    var cell = OnionCell.init();
    cell.header.circuit_id = circuit_id;
    cell.header.command = CMD_DESTROY;
    return cell;
}

// Helper: format port number to string
fn formatPort(port: u16, buf: []u8) usize {
    var p = port;
    var len: usize = 0;
    var temp: [6]u8 = undefined;

    if (p == 0) {
        buf[0] = '0';
        return 1;
    }

    while (p > 0) {
        temp[len] = @truncate((p % 10) + '0');
        p /= 10;
        len += 1;
    }

    // Reverse
    for (0..len) |i| {
        buf[i] = temp[len - 1 - i];
    }

    return len;
}

// Derive session key from shared secret
pub fn deriveSessionKey(shared_secret: []const u8, output: *[KEY_SIZE]u8) void {
    const hash = sha256.hash(shared_secret);
    for (hash.bytes[0..KEY_SIZE], 0..) |b, i| {
        output[i] = b;
    }
}

var onion_initialized: bool = false;

pub fn init() void {
    serial.write("Onion: Initializing onion routing protocol...\n");
    onion_initialized = true;
    serial.write("Onion: Ready\n");
}

pub fn isInitialized() bool {
    return onion_initialized;
}
