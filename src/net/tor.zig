// Home OS - Tor-like Onion Router
// Copyright © 2025 Romy Rianata - Home OS
// Phase 26: Onion Routing - Main Tor Interface

const serial = @import("../drivers/serial.zig");
const crypto = @import("../crypto/crypto.zig");
const onion = @import("onion.zig");
const circuit = @import("circuit.zig");
const socks5 = @import("socks5.zig");
const ipv4 = @import("ipv4.zig");

// Tor status
pub const TorStatus = enum {
    disabled,
    bootstrapping,
    connected,
    error_state,
};

// Directory node (simplified - in real Tor this comes from consensus)
pub const DirectoryNode = struct {
    ip: ipv4.IPv4Address,
    port: u16,
    flags: u8, // Node flags (guard, exit, stable, etc.)
    bandwidth: u32, // Advertised bandwidth
    public_key: [32]u8,

    pub const FLAG_GUARD: u8 = 0x01;
    pub const FLAG_EXIT: u8 = 0x02;
    pub const FLAG_STABLE: u8 = 0x04;
    pub const FLAG_FAST: u8 = 0x08;
    pub const FLAG_VALID: u8 = 0x10;
};

// Hardcoded demo nodes (in real implementation, fetched from directory)
const MAX_DIRECTORY_NODES: usize = 16;
var directory_nodes: [MAX_DIRECTORY_NODES]DirectoryNode = undefined;
var directory_node_count: usize = 0;

// Tor state
var tor_status: TorStatus = .disabled;
var tor_initialized: bool = false;
var bootstrap_progress: u8 = 0;
var current_circuit: ?*circuit.Circuit = null;

// SOCKS5 proxy settings
var socks_port: u16 = 9050;
var socks_enabled: bool = false;

pub fn init() void {
    serial.write("Tor: Initializing onion router...\n");

    // Initialize subsystems
    socks5.init();
    onion.init();
    circuit.init();

    // Add demo directory nodes (simulated)
    addDemoNodes();

    tor_initialized = true;
    tor_status = .disabled;
    serial.write("Tor: Ready (disabled)\n");
}

// Add demo nodes for testing
fn addDemoNodes() void {
    // These are fake nodes for demonstration
    // In real implementation, these come from Tor directory servers

    // Demo guard nodes
    addNode([_]u8{ 192, 168, 1, 100 }, 9001, DirectoryNode.FLAG_GUARD | DirectoryNode.FLAG_STABLE);
    addNode([_]u8{ 192, 168, 1, 101 }, 9001, DirectoryNode.FLAG_GUARD | DirectoryNode.FLAG_STABLE);

    // Demo middle nodes
    addNode([_]u8{ 192, 168, 1, 110 }, 9001, DirectoryNode.FLAG_STABLE | DirectoryNode.FLAG_FAST);
    addNode([_]u8{ 192, 168, 1, 111 }, 9001, DirectoryNode.FLAG_STABLE | DirectoryNode.FLAG_FAST);
    addNode([_]u8{ 192, 168, 1, 112 }, 9001, DirectoryNode.FLAG_STABLE);

    // Demo exit nodes
    addNode([_]u8{ 192, 168, 1, 120 }, 9001, DirectoryNode.FLAG_EXIT | DirectoryNode.FLAG_STABLE);
    addNode([_]u8{ 192, 168, 1, 121 }, 9001, DirectoryNode.FLAG_EXIT | DirectoryNode.FLAG_FAST);

    serial.write("Tor: Added ");
    serial.writeInt(@as(u32, @truncate(directory_node_count)));
    serial.write(" demo nodes\n");
}

fn addNode(ip: ipv4.IPv4Address, port: u16, flags: u8) void {
    if (directory_node_count >= MAX_DIRECTORY_NODES) return;

    var node = DirectoryNode{
        .ip = ip,
        .port = port,
        .flags = flags,
        .bandwidth = 1000000, // 1 MB/s default
        .public_key = undefined,
    };

    // Generate random public key for demo
    crypto.randomBytes(&node.public_key);

    directory_nodes[directory_node_count] = node;
    directory_node_count += 1;
}

pub fn isInitialized() bool {
    return tor_initialized;
}

pub fn getStatus() TorStatus {
    return tor_status;
}

pub fn getStatusName() []const u8 {
    return switch (tor_status) {
        .disabled => "Disabled",
        .bootstrapping => "Bootstrapping",
        .connected => "Connected",
        .error_state => "Error",
    };
}

pub fn getBootstrapProgress() u8 {
    return bootstrap_progress;
}

// Enable Tor
pub fn enable() bool {
    if (tor_status != .disabled) return false;

    serial.write("Tor: Enabling...\n");
    tor_status = .bootstrapping;
    bootstrap_progress = 0;

    // Start bootstrap process
    if (bootstrap()) {
        tor_status = .connected;
        bootstrap_progress = 100;
        serial.write("Tor: Connected!\n");
        return true;
    } else {
        tor_status = .error_state;
        serial.write("Tor: Bootstrap failed\n");
        return false;
    }
}

// Disable Tor
pub fn disable() void {
    serial.write("Tor: Disabling...\n");

    // Close all circuits
    if (current_circuit) |c| {
        _ = circuit.closeCircuit(c.id);
        current_circuit = null;
    }

    socks_enabled = false;
    tor_status = .disabled;
    bootstrap_progress = 0;
    serial.write("Tor: Disabled\n");
}

// Bootstrap process
fn bootstrap() bool {
    serial.write("Tor: Bootstrapping...\n");

    // Step 1: Check directory nodes (25%)
    bootstrap_progress = 10;
    if (directory_node_count < 3) {
        serial.write("Tor: Not enough directory nodes\n");
        return false;
    }
    bootstrap_progress = 25;

    // Step 2: Select nodes for circuit (50%)
    const entry = selectGuardNode() orelse {
        serial.write("Tor: No guard node available\n");
        return false;
    };
    bootstrap_progress = 35;

    const middle = selectMiddleNode(entry) orelse {
        serial.write("Tor: No middle node available\n");
        return false;
    };
    bootstrap_progress = 45;

    const exit = selectExitNode(entry, middle) orelse {
        serial.write("Tor: No exit node available\n");
        return false;
    };
    bootstrap_progress = 50;

    // Step 3: Build circuit (75%)
    serial.write("Tor: Building circuit...\n");
    current_circuit = circuit.buildCircuit(entry, middle, exit);
    if (current_circuit == null) {
        serial.write("Tor: Failed to build circuit\n");
        return false;
    }
    bootstrap_progress = 75;

    // Step 4: Mark ready (100%)
    if (current_circuit) |c| {
        _ = circuit.markCircuitReady(c.id);
    }
    bootstrap_progress = 100;

    socks_enabled = true;
    return true;
}

// Select a guard (entry) node
fn selectGuardNode() ?onion.OnionNode {
    var candidates: [MAX_DIRECTORY_NODES]usize = undefined;
    var count: usize = 0;

    for (directory_nodes[0..directory_node_count], 0..) |node, i| {
        if ((node.flags & DirectoryNode.FLAG_GUARD) != 0) {
            candidates[count] = i;
            count += 1;
        }
    }

    if (count == 0) return null;

    // Random selection
    const idx = crypto.randomU32() % @as(u32, @truncate(count));
    const selected = &directory_nodes[candidates[idx]];

    var result = onion.OnionNode.init();
    result.ip = selected.ip;
    result.port = selected.port;
    result.node_type = .entry;
    result.public_key = selected.public_key;
    result.active = true;

    return result;
}

// Select a middle node (not same as entry)
fn selectMiddleNode(entry: onion.OnionNode) ?onion.OnionNode {
    var candidates: [MAX_DIRECTORY_NODES]usize = undefined;
    var count: usize = 0;

    for (directory_nodes[0..directory_node_count], 0..) |node, i| {
        // Not the same as entry
        if (ipv4.ipEqual(node.ip, entry.ip)) continue;

        // Prefer stable nodes
        if ((node.flags & DirectoryNode.FLAG_STABLE) != 0) {
            candidates[count] = i;
            count += 1;
        }
    }

    if (count == 0) return null;

    const idx = crypto.randomU32() % @as(u32, @truncate(count));
    const selected = &directory_nodes[candidates[idx]];

    var result = onion.OnionNode.init();
    result.ip = selected.ip;
    result.port = selected.port;
    result.node_type = .middle;
    result.public_key = selected.public_key;
    result.active = true;

    return result;
}

// Select an exit node (not same as entry or middle)
fn selectExitNode(entry: onion.OnionNode, middle: onion.OnionNode) ?onion.OnionNode {
    var candidates: [MAX_DIRECTORY_NODES]usize = undefined;
    var count: usize = 0;

    for (directory_nodes[0..directory_node_count], 0..) |node, i| {
        // Must be exit node
        if ((node.flags & DirectoryNode.FLAG_EXIT) == 0) continue;

        // Not same as entry or middle
        if (ipv4.ipEqual(node.ip, entry.ip)) continue;
        if (ipv4.ipEqual(node.ip, middle.ip)) continue;

        candidates[count] = i;
        count += 1;
    }

    if (count == 0) return null;

    const idx = crypto.randomU32() % @as(u32, @truncate(count));
    const selected = &directory_nodes[candidates[idx]];

    var result = onion.OnionNode.init();
    result.ip = selected.ip;
    result.port = selected.port;
    result.node_type = .exit;
    result.public_key = selected.public_key;
    result.active = true;

    return result;
}

// Get current circuit
pub fn getCurrentCircuit() ?*circuit.Circuit {
    return current_circuit;
}

// Get SOCKS port
pub fn getSocksPort() u16 {
    return socks_port;
}

// Check if SOCKS proxy is enabled
pub fn isSocksEnabled() bool {
    return socks_enabled and tor_status == .connected;
}

// Get directory node count
pub fn getNodeCount() usize {
    return directory_node_count;
}

// Get guard node count
pub fn getGuardCount() usize {
    var count: usize = 0;
    for (directory_nodes[0..directory_node_count]) |node| {
        if ((node.flags & DirectoryNode.FLAG_GUARD) != 0) count += 1;
    }
    return count;
}

// Get exit node count
pub fn getExitCount() usize {
    var count: usize = 0;
    for (directory_nodes[0..directory_node_count]) |node| {
        if ((node.flags & DirectoryNode.FLAG_EXIT) != 0) count += 1;
    }
    return count;
}

// Create new circuit (rebuild)
pub fn newCircuit() bool {
    if (tor_status != .connected) return false;

    serial.write("Tor: Creating new circuit...\n");

    // Close old circuit
    if (current_circuit) |c| {
        _ = circuit.closeCircuit(c.id);
        current_circuit = null;
    }

    // Build new one
    const entry = selectGuardNode() orelse return false;
    const middle = selectMiddleNode(entry) orelse return false;
    const exit = selectExitNode(entry, middle) orelse return false;

    current_circuit = circuit.buildCircuit(entry, middle, exit);
    if (current_circuit) |c| {
        _ = circuit.markCircuitReady(c.id);
        serial.write("Tor: New circuit ready\n");
        return true;
    }

    return false;
}

// Resolve .onion address (simplified)
pub fn resolveOnion(address: []const u8) ?ipv4.IPv4Address {
    // Check if it's a .onion address
    if (address.len < 7) return null;

    const suffix = address[address.len - 6 ..];
    if (!strEqual(suffix, ".onion")) return null;

    // In real Tor, this would involve hidden service descriptors
    // For demo, we just return a placeholder
    serial.write("Tor: Resolving .onion address (demo)\n");

    // Return a demo address
    return [_]u8{ 10, 0, 0, 1 };
}

fn strEqual(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    for (a, b) |x, y| {
        if (x != y) return false;
    }
    return true;
}
