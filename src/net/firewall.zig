// Home OS - Firewall (Packet Filtering)
// Copyright © 2025 Romy Rianata - Home OS
// Phase 22: Network Security Layer

const serial = @import("../drivers/serial.zig");

// Firewall rule actions
pub const Action = enum(u8) {
    allow,
    deny,
    drop, // Silent drop (no ICMP response)
};

// Protocol types
pub const Protocol = enum(u8) {
    any = 0,
    icmp = 1,
    tcp = 6,
    udp = 17,
};

// Direction
pub const Direction = enum(u8) {
    inbound,
    outbound,
    both,
};

// Firewall rule
pub const Rule = struct {
    enabled: bool = false,
    action: Action = .allow,
    direction: Direction = .both,
    protocol: Protocol = .any,
    src_ip: u32 = 0, // 0 = any
    src_mask: u32 = 0, // Subnet mask
    dst_ip: u32 = 0,
    dst_mask: u32 = 0,
    src_port: u16 = 0, // 0 = any
    dst_port: u16 = 0,
    description: [32]u8 = [_]u8{0} ** 32,

    pub fn matches(self: *const Rule, pkt: *const PacketInfo) bool {
        if (!self.enabled) return false;

        // Check direction
        if (self.direction != .both and self.direction != pkt.direction) {
            return false;
        }

        // Check protocol
        if (self.protocol != .any and self.protocol != pkt.protocol) {
            return false;
        }

        // Check source IP (with mask)
        if (self.src_ip != 0) {
            if ((pkt.src_ip & self.src_mask) != (self.src_ip & self.src_mask)) {
                return false;
            }
        }

        // Check destination IP (with mask)
        if (self.dst_ip != 0) {
            if ((pkt.dst_ip & self.dst_mask) != (self.dst_ip & self.dst_mask)) {
                return false;
            }
        }

        // Check ports (TCP/UDP only)
        if (self.src_port != 0 and pkt.src_port != self.src_port) {
            return false;
        }
        if (self.dst_port != 0 and pkt.dst_port != self.dst_port) {
            return false;
        }

        return true;
    }
};

// Packet info for filtering
pub const PacketInfo = struct {
    direction: Direction,
    protocol: Protocol,
    src_ip: u32,
    dst_ip: u32,
    src_port: u16,
    dst_port: u16,
};

// Firewall state
const MAX_RULES = 32;
var rules: [MAX_RULES]Rule = [_]Rule{.{}} ** MAX_RULES;
var rule_count: usize = 0;
var firewall_enabled: bool = false;
var default_action: Action = .allow;

// Statistics
var packets_allowed: u32 = 0;
var packets_denied: u32 = 0;
var packets_dropped: u32 = 0;

/// Initialize firewall
pub fn init() void {
    serial.write("Firewall: Initializing...\n");

    // Clear all rules
    for (&rules) |*r| {
        r.* = Rule{};
    }
    rule_count = 0;

    // Add default rules
    // Allow loopback
    _ = addRule(.{
        .enabled = true,
        .action = .allow,
        .direction = .both,
        .src_ip = 0x7F000001, // 127.0.0.1
        .src_mask = 0xFF000000,
        .description = initDesc("Allow loopback"),
    });

    // Allow established connections (simplified - allow all outbound)
    _ = addRule(.{
        .enabled = true,
        .action = .allow,
        .direction = .outbound,
        .description = initDesc("Allow outbound"),
    });

    // Allow ICMP (ping)
    _ = addRule(.{
        .enabled = true,
        .action = .allow,
        .direction = .both,
        .protocol = .icmp,
        .description = initDesc("Allow ICMP"),
    });

    // Allow DNS (port 53)
    _ = addRule(.{
        .enabled = true,
        .action = .allow,
        .direction = .both,
        .protocol = .udp,
        .dst_port = 53,
        .description = initDesc("Allow DNS"),
    });

    // Allow DHCP
    _ = addRule(.{
        .enabled = true,
        .action = .allow,
        .direction = .both,
        .protocol = .udp,
        .dst_port = 67,
        .description = initDesc("Allow DHCP"),
    });

    _ = addRule(.{
        .enabled = true,
        .action = .allow,
        .direction = .both,
        .protocol = .udp,
        .src_port = 68,
        .description = initDesc("Allow DHCP client"),
    });

    firewall_enabled = true;
    serial.write("Firewall: Ready\n");
}

fn initDesc(comptime s: []const u8) [32]u8 {
    var desc: [32]u8 = [_]u8{0} ** 32;
    for (s, 0..) |c, i| {
        if (i >= 32) break;
        desc[i] = c;
    }
    return desc;
}

/// Add a firewall rule
pub fn addRule(rule: Rule) ?usize {
    if (rule_count >= MAX_RULES) return null;

    rules[rule_count] = rule;
    rules[rule_count].enabled = true;
    rule_count += 1;
    return rule_count - 1;
}

/// Remove a rule by index
pub fn removeRule(index: usize) bool {
    if (index >= rule_count) return false;

    // Shift rules down
    var i = index;
    while (i < rule_count - 1) : (i += 1) {
        rules[i] = rules[i + 1];
    }
    rules[rule_count - 1] = Rule{};
    rule_count -= 1;
    return true;
}

/// Check if packet should be allowed
pub fn filter(pkt: *const PacketInfo) Action {
    if (!firewall_enabled) {
        packets_allowed += 1;
        return .allow;
    }

    // Check rules in order (first match wins)
    for (rules[0..rule_count]) |*rule| {
        if (rule.matches(pkt)) {
            switch (rule.action) {
                .allow => packets_allowed += 1,
                .deny => packets_denied += 1,
                .drop => packets_dropped += 1,
            }
            return rule.action;
        }
    }

    // Default action
    switch (default_action) {
        .allow => packets_allowed += 1,
        .deny => packets_denied += 1,
        .drop => packets_dropped += 1,
    }
    return default_action;
}

/// Enable/disable firewall
pub fn setEnabled(enabled: bool) void {
    firewall_enabled = enabled;
}

/// Check if enabled
pub fn isEnabled() bool {
    return firewall_enabled;
}

/// Set default action
pub fn setDefaultAction(action: Action) void {
    default_action = action;
}

/// Get statistics
pub fn getStats() struct { allowed: u32, denied: u32, dropped: u32 } {
    return .{
        .allowed = packets_allowed,
        .denied = packets_denied,
        .dropped = packets_dropped,
    };
}

/// Get rule count
pub fn getRuleCount() usize {
    return rule_count;
}

/// Get rule by index
pub fn getRule(index: usize) ?*const Rule {
    if (index >= rule_count) return null;
    return &rules[index];
}

/// Block an IP address
pub fn blockIP(ip: u32) ?usize {
    return addRule(.{
        .enabled = true,
        .action = .drop,
        .direction = .both,
        .src_ip = ip,
        .src_mask = 0xFFFFFFFF,
        .description = initDesc("Blocked IP"),
    });
}

/// Allow a port
pub fn allowPort(port: u16, proto: Protocol) ?usize {
    return addRule(.{
        .enabled = true,
        .action = .allow,
        .direction = .inbound,
        .protocol = proto,
        .dst_port = port,
        .description = initDesc("Allowed port"),
    });
}

/// Get description as slice
pub fn getDescription(rule: *const Rule) []const u8 {
    var len: usize = 0;
    for (rule.description) |c| {
        if (c == 0) break;
        len += 1;
    }
    return rule.description[0..len];
}
