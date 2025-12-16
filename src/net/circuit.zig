// Home OS - Circuit Management
// Copyright © 2025 Romy Rianata - Home OS
// Phase 26: Onion Routing - Circuit Building

const serial = @import("../drivers/serial.zig");
const crypto = @import("../crypto/crypto.zig");
const onion = @import("onion.zig");
const ipv4 = @import("ipv4.zig");
const tcp = @import("tcp.zig");

// Circuit constants
pub const MAX_CIRCUITS: usize = 8;
pub const MIN_HOPS: usize = 3;
pub const MAX_HOPS: usize = 5;
pub const MAX_STREAMS: usize = 16;

// Circuit state
pub const CircuitState = enum {
    unused,
    building, // Creating circuit
    extending, // Adding hops
    ready, // Circuit established
    closing, // Tearing down
    failed, // Circuit failed
};

// Stream state
pub const StreamState = enum {
    unused,
    connecting,
    connected,
    closing,
    closed,
};

// Stream (connection through circuit)
pub const Stream = struct {
    id: u16,
    state: StreamState,
    dest_host: [128]u8,
    dest_host_len: u8,
    dest_port: u16,
    recv_buffer: [2048]u8,
    recv_len: usize,

    pub fn init() Stream {
        return Stream{
            .id = 0,
            .state = .unused,
            .dest_host = undefined,
            .dest_host_len = 0,
            .dest_port = 0,
            .recv_buffer = undefined,
            .recv_len = 0,
        };
    }

    pub fn reset(self: *Stream) void {
        self.state = .unused;
        self.id = 0;
        self.dest_host_len = 0;
        self.dest_port = 0;
        self.recv_len = 0;
    }
};

// Circuit (path through onion network)
pub const Circuit = struct {
    id: u16,
    state: CircuitState,
    hop_count: u8,
    hops: [MAX_HOPS]onion.OnionNode,
    session_keys: [MAX_HOPS][onion.KEY_SIZE]u8,
    streams: [MAX_STREAMS]Stream,
    next_stream_id: u16,
    socket_id: ?u32, // TCP socket to entry node
    created_tick: u32,

    pub fn init() Circuit {
        var c = Circuit{
            .id = 0,
            .state = .unused,
            .hop_count = 0,
            .hops = undefined,
            .session_keys = undefined,
            .streams = undefined,
            .next_stream_id = 1,
            .socket_id = null,
            .created_tick = 0,
        };

        for (&c.hops) |*h| {
            h.* = onion.OnionNode.init();
        }
        for (&c.session_keys) |*k| {
            k.* = [_]u8{0} ** onion.KEY_SIZE;
        }
        for (&c.streams) |*s| {
            s.* = Stream.init();
        }

        return c;
    }

    pub fn reset(self: *Circuit) void {
        self.state = .unused;
        self.hop_count = 0;
        self.next_stream_id = 1;
        self.socket_id = null;

        for (&self.hops) |*h| {
            h.active = false;
        }
        for (&self.streams) |*s| {
            s.reset();
        }
        // Securely wipe session keys
        for (&self.session_keys) |*k| {
            crypto.secureZero(k);
        }
    }

    pub fn addHop(self: *Circuit, node: onion.OnionNode) bool {
        if (self.hop_count >= MAX_HOPS) return false;

        self.hops[self.hop_count] = node;
        self.hops[self.hop_count].active = true;
        self.hop_count += 1;
        return true;
    }

    pub fn getEntryNode(self: *const Circuit) ?*const onion.OnionNode {
        if (self.hop_count == 0) return null;
        return &self.hops[0];
    }

    pub fn getExitNode(self: *const Circuit) ?*const onion.OnionNode {
        if (self.hop_count == 0) return null;
        return &self.hops[self.hop_count - 1];
    }

    pub fn allocateStream(self: *Circuit) ?*Stream {
        for (&self.streams) |*s| {
            if (s.state == .unused) {
                s.id = self.next_stream_id;
                self.next_stream_id += 1;
                s.state = .connecting;
                return s;
            }
        }
        return null;
    }

    pub fn findStream(self: *Circuit, stream_id: u16) ?*Stream {
        for (&self.streams) |*s| {
            if (s.id == stream_id and s.state != .unused) {
                return s;
            }
        }
        return null;
    }

    pub fn getActiveStreamCount(self: *const Circuit) u32 {
        var count: u32 = 0;
        for (self.streams) |s| {
            if (s.state != .unused and s.state != .closed) {
                count += 1;
            }
        }
        return count;
    }
};

// Circuit manager
var circuits: [MAX_CIRCUITS]Circuit = undefined;
var next_circuit_id: u16 = 1;
var circuit_initialized: bool = false;

pub fn init() void {
    serial.write("Circuit: Initializing circuit manager...\n");

    for (&circuits) |*c| {
        c.* = Circuit.init();
    }

    circuit_initialized = true;
    serial.write("Circuit: Ready\n");
}

pub fn isInitialized() bool {
    return circuit_initialized;
}

// Allocate a new circuit
pub fn allocateCircuit() ?*Circuit {
    for (&circuits) |*c| {
        if (c.state == .unused) {
            c.* = Circuit.init();
            c.id = next_circuit_id;
            next_circuit_id += 1;
            c.state = .building;
            return c;
        }
    }
    return null;
}

// Find circuit by ID
pub fn findCircuit(circuit_id: u16) ?*Circuit {
    for (&circuits) |*c| {
        if (c.id == circuit_id and c.state != .unused) {
            return c;
        }
    }
    return null;
}

// Get circuit by index
pub fn getCircuit(idx: usize) ?*Circuit {
    if (idx >= MAX_CIRCUITS) return null;
    if (circuits[idx].state == .unused) return null;
    return &circuits[idx];
}

// Close circuit
pub fn closeCircuit(circuit_id: u16) bool {
    const c = findCircuit(circuit_id) orelse return false;

    serial.write("Circuit: Closing circuit ");
    serial.writeInt(circuit_id);
    serial.write("\n");

    // Close TCP socket if open
    if (c.socket_id) |sock_id| {
        if (tcp.getSocket(sock_id)) |sock| {
            sock.close();
        }
    }

    c.reset();
    return true;
}

// Build a 3-hop circuit with given nodes
pub fn buildCircuit(entry: onion.OnionNode, middle: onion.OnionNode, exit: onion.OnionNode) ?*Circuit {
    const c = allocateCircuit() orelse return null;

    serial.write("Circuit: Building 3-hop circuit ID=");
    serial.writeInt(c.id);
    serial.write("\n");

    // Add hops
    var entry_node = entry;
    entry_node.node_type = .entry;
    _ = c.addHop(entry_node);

    var middle_node = middle;
    middle_node.node_type = .middle;
    _ = c.addHop(middle_node);

    var exit_node = exit;
    exit_node.node_type = .exit;
    _ = c.addHop(exit_node);

    // Generate session keys for each hop
    for (0..c.hop_count) |i| {
        crypto.randomBytes(&c.session_keys[i]);
    }

    c.state = .extending;
    return c;
}

// Mark circuit as ready
pub fn markCircuitReady(circuit_id: u16) bool {
    const c = findCircuit(circuit_id) orelse return false;
    c.state = .ready;
    serial.write("Circuit: Circuit ");
    serial.writeInt(circuit_id);
    serial.write(" is ready\n");
    return true;
}

// Get active circuit count
pub fn getActiveCircuitCount() u32 {
    var count: u32 = 0;
    for (circuits) |c| {
        if (c.state != .unused and c.state != .failed) {
            count += 1;
        }
    }
    return count;
}

// Get ready circuit count
pub fn getReadyCircuitCount() u32 {
    var count: u32 = 0;
    for (circuits) |c| {
        if (c.state == .ready) {
            count += 1;
        }
    }
    return count;
}

// Get first ready circuit
pub fn getReadyCircuit() ?*Circuit {
    for (&circuits) |*c| {
        if (c.state == .ready) {
            return c;
        }
    }
    return null;
}

// Get circuit state name
pub fn getStateName(state: CircuitState) []const u8 {
    return switch (state) {
        .unused => "UNUSED",
        .building => "BUILDING",
        .extending => "EXTENDING",
        .ready => "READY",
        .closing => "CLOSING",
        .failed => "FAILED",
    };
}

// Get stream state name
pub fn getStreamStateName(state: StreamState) []const u8 {
    return switch (state) {
        .unused => "UNUSED",
        .connecting => "CONNECTING",
        .connected => "CONNECTED",
        .closing => "CLOSING",
        .closed => "CLOSED",
    };
}
