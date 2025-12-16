// Home OS - MAC Address Randomization
// Copyright © 2025 Romy Rianata - Home OS
// Phase 22: Network Security Layer - Privacy Feature

const serial = @import("../drivers/serial.zig");
const crypto = @import("../crypto/crypto.zig");
const rtl8139 = @import("rtl8139.zig");

// MAC address type
pub const MacAddress = [6]u8;

// Original MAC (hardware)
var original_mac: MacAddress = [_]u8{0} ** 6;
var original_mac_saved: bool = false;

// Current MAC
var current_mac: MacAddress = [_]u8{0} ** 6;
var mac_randomized: bool = false;

// Randomization settings
var auto_randomize: bool = false;
var randomize_on_boot: bool = true;

/// Initialize MAC randomization
pub fn init() void {
    serial.write("MAC: Initializing MAC randomization...\n");

    // Save original MAC
    if (rtl8139.isInitialized()) {
        original_mac = rtl8139.getMacAddress();
        original_mac_saved = true;
        current_mac = original_mac;

        serial.write("MAC: Original = ");
        printMac(original_mac);
        serial.write("\n");

        // Randomize on boot if enabled
        if (randomize_on_boot) {
            _ = randomize();
        }
    }

    serial.write("MAC: Ready\n");
}

/// Generate a random locally-administered MAC address
pub fn generateRandom() MacAddress {
    var mac: MacAddress = undefined;
    crypto.randomBytes(&mac);

    // Set locally administered bit (bit 1 of first byte)
    mac[0] |= 0x02;

    // Clear multicast bit (bit 0 of first byte)
    mac[0] &= 0xFE;

    return mac;
}

/// Randomize MAC address
pub fn randomize() bool {
    if (!rtl8139.isInitialized()) {
        serial.write("MAC: NIC not initialized\n");
        return false;
    }

    const new_mac = generateRandom();

    serial.write("MAC: Randomizing to ");
    printMac(new_mac);
    serial.write("\n");

    // Set new MAC on NIC
    if (rtl8139.setMacAddress(new_mac)) {
        current_mac = new_mac;
        mac_randomized = true;
        serial.write("MAC: Randomization successful\n");
        return true;
    } else {
        serial.write("MAC: Randomization failed\n");
        return false;
    }
}

/// Restore original MAC address
pub fn restore() bool {
    if (!original_mac_saved) {
        serial.write("MAC: Original MAC not saved\n");
        return false;
    }

    if (!rtl8139.isInitialized()) {
        serial.write("MAC: NIC not initialized\n");
        return false;
    }

    serial.write("MAC: Restoring original ");
    printMac(original_mac);
    serial.write("\n");

    if (rtl8139.setMacAddress(original_mac)) {
        current_mac = original_mac;
        mac_randomized = false;
        serial.write("MAC: Restored successfully\n");
        return true;
    } else {
        serial.write("MAC: Restore failed\n");
        return false;
    }
}

/// Set a specific MAC address
pub fn setMac(mac: MacAddress) bool {
    if (!rtl8139.isInitialized()) return false;

    if (rtl8139.setMacAddress(mac)) {
        current_mac = mac;
        mac_randomized = true;
        return true;
    }
    return false;
}

/// Get current MAC address
pub fn getCurrentMac() MacAddress {
    return current_mac;
}

/// Get original MAC address
pub fn getOriginalMac() ?MacAddress {
    if (original_mac_saved) {
        return original_mac;
    }
    return null;
}

/// Check if MAC is randomized
pub fn isRandomized() bool {
    return mac_randomized;
}

/// Enable/disable auto-randomization
pub fn setAutoRandomize(enabled: bool) void {
    auto_randomize = enabled;
}

/// Check if auto-randomize is enabled
pub fn isAutoRandomizeEnabled() bool {
    return auto_randomize;
}

/// Print MAC address to serial
fn printMac(mac: MacAddress) void {
    const hex = "0123456789ABCDEF";
    var buf: [18]u8 = undefined;
    var pos: usize = 0;

    for (mac, 0..) |b, i| {
        buf[pos] = hex[b >> 4];
        pos += 1;
        buf[pos] = hex[b & 0x0F];
        pos += 1;
        if (i < 5) {
            buf[pos] = ':';
            pos += 1;
        }
    }

    serial.write(buf[0..17]);
}

/// Format MAC address to buffer
pub fn formatMac(mac: MacAddress, buf: []u8) usize {
    if (buf.len < 17) return 0;

    const hex = "0123456789ABCDEF";
    var pos: usize = 0;

    for (mac, 0..) |b, i| {
        buf[pos] = hex[b >> 4];
        pos += 1;
        buf[pos] = hex[b & 0x0F];
        pos += 1;
        if (i < 5) {
            buf[pos] = ':';
            pos += 1;
        }
    }

    return 17;
}

/// Parse MAC address from string "XX:XX:XX:XX:XX:XX"
pub fn parseMac(str: []const u8) ?MacAddress {
    if (str.len < 17) return null;

    var mac: MacAddress = undefined;
    var pos: usize = 0;

    for (0..6) |i| {
        const high = hexDigit(str[pos]) orelse return null;
        pos += 1;
        const low = hexDigit(str[pos]) orelse return null;
        pos += 1;

        mac[i] = (high << 4) | low;

        if (i < 5) {
            if (str[pos] != ':' and str[pos] != '-') return null;
            pos += 1;
        }
    }

    return mac;
}

fn hexDigit(c: u8) ?u8 {
    if (c >= '0' and c <= '9') return c - '0';
    if (c >= 'A' and c <= 'F') return c - 'A' + 10;
    if (c >= 'a' and c <= 'f') return c - 'a' + 10;
    return null;
}
