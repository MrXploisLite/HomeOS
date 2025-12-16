// Home OS - PCI Bus Driver
// Copyright © 2025 Romy Rianata - Home OS
// Phase 16: USB Support (PCI enumeration needed for USB controllers)

const io = @import("../arch/io.zig");
const serial = @import("serial.zig");

// PCI Configuration Space ports
const PCI_CONFIG_ADDR: u16 = 0xCF8;
const PCI_CONFIG_DATA: u16 = 0xCFC;

// PCI Class codes
pub const CLASS_STORAGE: u8 = 0x01;
pub const CLASS_NETWORK: u8 = 0x02;
pub const CLASS_DISPLAY: u8 = 0x03;
pub const CLASS_MULTIMEDIA: u8 = 0x04;
pub const CLASS_MEMORY: u8 = 0x05;
pub const CLASS_BRIDGE: u8 = 0x06;
pub const CLASS_SERIAL_BUS: u8 = 0x0C;

// USB Subclass/ProgIF
pub const SUBCLASS_USB: u8 = 0x03;
pub const PROGIF_UHCI: u8 = 0x00;
pub const PROGIF_OHCI: u8 = 0x10;
pub const PROGIF_EHCI: u8 = 0x20;
pub const PROGIF_XHCI: u8 = 0x30;

pub const PciDevice = struct {
    bus: u8,
    slot: u8,
    func: u8,
    vendor_id: u16,
    device_id: u16,
    class_code: u8,
    subclass: u8,
    prog_if: u8,
    header_type: u8,
    bar0: u32,
    bar1: u32,
    bar2: u32,
    bar3: u32,
    bar4: u32,
    bar5: u32,
    irq_line: u8,
};

const MAX_DEVICES: usize = 32;
var devices: [MAX_DEVICES]PciDevice = undefined;
var device_count: usize = 0;
var initialized: bool = false;

/// Build PCI config address
fn pciConfigAddr(bus: u8, slot: u8, func: u8, offset: u8) u32 {
    return @as(u32, 0x80000000) |
        (@as(u32, bus) << 16) |
        (@as(u32, slot) << 11) |
        (@as(u32, func) << 8) |
        (@as(u32, offset) & 0xFC);
}

/// Read 32-bit from PCI config space
pub fn configRead32(bus: u8, slot: u8, func: u8, offset: u8) u32 {
    io.outl(PCI_CONFIG_ADDR, pciConfigAddr(bus, slot, func, offset));
    return io.inl(PCI_CONFIG_DATA);
}

/// Read 16-bit from PCI config space
pub fn configRead16(bus: u8, slot: u8, func: u8, offset: u8) u16 {
    const val = configRead32(bus, slot, func, offset & 0xFC);
    return @truncate((val >> @as(u5, @truncate((offset & 2) * 8))));
}

/// Read 8-bit from PCI config space
pub fn configRead8(bus: u8, slot: u8, func: u8, offset: u8) u8 {
    const val = configRead32(bus, slot, func, offset & 0xFC);
    return @truncate((val >> @as(u5, @truncate((offset & 3) * 8))));
}

/// Write 32-bit to PCI config space
pub fn configWrite32(bus: u8, slot: u8, func: u8, offset: u8, value: u32) void {
    io.outl(PCI_CONFIG_ADDR, pciConfigAddr(bus, slot, func, offset));
    io.outl(PCI_CONFIG_DATA, value);
}

/// Write 16-bit to PCI config space
pub fn configWrite16(bus: u8, slot: u8, func: u8, offset: u8, value: u16) void {
    const addr = pciConfigAddr(bus, slot, func, offset & 0xFC);
    io.outl(PCI_CONFIG_ADDR, addr);
    var val = io.inl(PCI_CONFIG_DATA);
    const shift: u5 = @truncate((offset & 2) * 8);
    val &= ~(@as(u32, 0xFFFF) << shift);
    val |= @as(u32, value) << shift;
    io.outl(PCI_CONFIG_DATA, val);
}

/// Check if device exists
fn deviceExists(bus: u8, slot: u8, func: u8) bool {
    const vendor = configRead16(bus, slot, func, 0x00);
    return vendor != 0xFFFF;
}

/// Scan a single device
fn scanDevice(bus: u8, slot: u8, func: u8) void {
    if (!deviceExists(bus, slot, func)) return;
    if (device_count >= MAX_DEVICES) return;

    const vendor_id = configRead16(bus, slot, func, 0x00);
    const device_id = configRead16(bus, slot, func, 0x02);
    const class_code = configRead8(bus, slot, func, 0x0B);
    const subclass = configRead8(bus, slot, func, 0x0A);
    const prog_if = configRead8(bus, slot, func, 0x09);
    const header_type = configRead8(bus, slot, func, 0x0E);
    const irq_line = configRead8(bus, slot, func, 0x3C);

    devices[device_count] = PciDevice{
        .bus = bus,
        .slot = slot,
        .func = func,
        .vendor_id = vendor_id,
        .device_id = device_id,
        .class_code = class_code,
        .subclass = subclass,
        .prog_if = prog_if,
        .header_type = header_type & 0x7F,
        .bar0 = configRead32(bus, slot, func, 0x10),
        .bar1 = configRead32(bus, slot, func, 0x14),
        .bar2 = configRead32(bus, slot, func, 0x18),
        .bar3 = configRead32(bus, slot, func, 0x1C),
        .bar4 = configRead32(bus, slot, func, 0x20),
        .bar5 = configRead32(bus, slot, func, 0x24),
        .irq_line = irq_line,
    };
    device_count += 1;
}

/// Scan PCI bus
fn scanBus(bus: u8) void {
    var slot: u8 = 0;
    while (slot < 32) : (slot += 1) {
        if (!deviceExists(bus, slot, 0)) continue;

        scanDevice(bus, slot, 0);

        // Check for multi-function device
        const header_type = configRead8(bus, slot, 0, 0x0E);
        if ((header_type & 0x80) != 0) {
            var func: u8 = 1;
            while (func < 8) : (func += 1) {
                scanDevice(bus, slot, func);
            }
        }
    }
}

/// Initialize PCI and enumerate devices
pub fn init() void {
    serial.write("PCI: Scanning bus...\n");
    device_count = 0;

    // Scan bus 0 (and secondary buses if bridges found)
    scanBus(0);

    serial.write("PCI: Found ");
    serial.writeInt(@truncate(device_count));
    serial.write(" device(s)\n");

    initialized = true;
}

/// Get device count
pub fn getDeviceCount() usize {
    return device_count;
}

/// Get device by index
pub fn getDevice(index: usize) ?*const PciDevice {
    if (index >= device_count) return null;
    return &devices[index];
}

/// Find device by class/subclass
pub fn findByClass(class: u8, subclass: u8) ?*const PciDevice {
    for (devices[0..device_count]) |*dev| {
        if (dev.class_code == class and dev.subclass == subclass) {
            return dev;
        }
    }
    return null;
}

/// Find device by class/subclass/progif
pub fn findByClassProgIf(class: u8, subclass: u8, prog_if: u8) ?*const PciDevice {
    for (devices[0..device_count]) |*dev| {
        if (dev.class_code == class and dev.subclass == subclass and dev.prog_if == prog_if) {
            return dev;
        }
    }
    return null;
}

/// Find USB controller
pub fn findUsbController(controller_type: u8) ?*const PciDevice {
    return findByClassProgIf(CLASS_SERIAL_BUS, SUBCLASS_USB, controller_type);
}

/// Get BAR as I/O port address
pub fn getBarIoPort(bar: u32) ?u16 {
    if ((bar & 1) == 0) return null; // Not I/O space
    return @truncate(bar & 0xFFFC);
}

/// Get BAR as memory address
pub fn getBarMemory(bar: u32) ?u32 {
    if ((bar & 1) != 0) return null; // Not memory space
    return bar & 0xFFFFFFF0;
}

/// Enable bus mastering for device
pub fn enableBusMaster(dev: *const PciDevice) void {
    var cmd = configRead16(dev.bus, dev.slot, dev.func, 0x04);
    cmd |= 0x04; // Bus Master Enable
    configWrite16(dev.bus, dev.slot, dev.func, 0x04, cmd);
}

/// Enable memory space access
pub fn enableMemorySpace(dev: *const PciDevice) void {
    var cmd = configRead16(dev.bus, dev.slot, dev.func, 0x04);
    cmd |= 0x02; // Memory Space Enable
    configWrite16(dev.bus, dev.slot, dev.func, 0x04, cmd);
}

/// Enable I/O space access
pub fn enableIoSpace(dev: *const PciDevice) void {
    var cmd = configRead16(dev.bus, dev.slot, dev.func, 0x04);
    cmd |= 0x01; // I/O Space Enable
    configWrite16(dev.bus, dev.slot, dev.func, 0x04, cmd);
}

/// Check if initialized
pub fn isInitialized() bool {
    return initialized;
}

/// Get class name
pub fn getClassName(class: u8) []const u8 {
    return switch (class) {
        0x00 => "Unclassified",
        0x01 => "Storage",
        0x02 => "Network",
        0x03 => "Display",
        0x04 => "Multimedia",
        0x05 => "Memory",
        0x06 => "Bridge",
        0x07 => "Communication",
        0x08 => "System",
        0x09 => "Input",
        0x0A => "Docking",
        0x0B => "Processor",
        0x0C => "Serial Bus",
        0x0D => "Wireless",
        0x0E => "Intelligent",
        0x0F => "Satellite",
        0x10 => "Encryption",
        0x11 => "Signal Processing",
        else => "Unknown",
    };
}
