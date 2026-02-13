// Ciko Kernel - Security Audit Logger
// Copyright © 2025 Romy Rianata - Home OS
// Centralized logging for security-critical events

const std = @import("std");
const serial = @import("../drivers/serial.zig");
const rtc = @import("../drivers/rtc.zig");

pub const AuditLevel = enum {
    INFO,
    WARNING,
    CRITICAL,
    ALERT
};

pub const AuditEvent = enum {
    SYSTEM_BOOT,
    LOGIN_ATTEMPT,
    PRIVILEGE_ESCALATION,
    FILE_ACCESS,
    NETWORK_CONNECTION,
    FIREWALL_DROP,
    TOR_CIRCUIT_CHANGE,
    MEMORY_WIPE
};

var initialized: bool = false;

pub fn init() void {
    initialized = true;
    log(.INFO, .SYSTEM_BOOT, "Audit system initialized");
}

pub fn log(level: AuditLevel, event: AuditEvent, message: []const u8) void {
    if (!initialized) return;

    // Format: [TIMESTAMP] [LEVEL] [EVENT] Message
    
    // Timestamp
    const dt = rtc.getDateTime();
    serial.printInt(dt.year);
    serial.write("-");
    if (dt.month < 10) serial.write("0");
    serial.printInt(dt.month);
    serial.write("-");
    if (dt.day < 10) serial.write("0");
    serial.printInt(dt.day);
    serial.write(" ");
    if (dt.hour < 10) serial.write("0");
    serial.printInt(dt.hour);
    serial.write(":");
    if (dt.minute < 10) serial.write("0");
    serial.printInt(dt.minute);
    serial.write(":");
    if (dt.second < 10) serial.write("0");
    serial.printInt(dt.second);
    serial.write(" ");

    // Level
    switch (level) {
        .INFO => serial.write("[INFO] "),
        .WARNING => serial.write("[WARN] "),
        .CRITICAL => serial.write("[CRIT] "),
        .ALERT => serial.write("[ALRT] "),
    }

    // Event
    switch (event) {
        .SYSTEM_BOOT => serial.write("[BOOT] "),
        .LOGIN_ATTEMPT => serial.write("[AUTH] "),
        .PRIVILEGE_ESCALATION => serial.write("[SUDO] "),
        .FILE_ACCESS => serial.write("[FILE] "),
        .NETWORK_CONNECTION => serial.write("[NETW] "),
        .FIREWALL_DROP => serial.write("[FWALL] "),
        .TOR_CIRCUIT_CHANGE => serial.write("[TOR] "),
        .MEMORY_WIPE => serial.write("[WIPE] "),
    }

    serial.write(message);
    serial.write("\n");
}
