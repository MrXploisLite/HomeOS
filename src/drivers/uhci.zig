// Home OS - UHCI (USB 1.x) Controller Driver
// Copyright © 2025 Romy Rianata - Home OS
// Phase 16: USB Support

const io = @import("../arch/io.zig");
const serial = @import("serial.zig");
const pci = @import("pci.zig");
const pic = @import("../arch/pic.zig");
const heap = @import("../mm/heap.zig");

// UHCI I/O Registers (offsets from base)
const USBCMD: u16 = 0x00; // USB Command
const USBSTS: u16 = 0x02; // USB Status
const USBINTR: u16 = 0x04; // USB Interrupt Enable
const FRNUM: u16 = 0x06; // Frame Number
const FRBASEADD: u16 = 0x08; // Frame List Base Address
const SOFMOD: u16 = 0x0C; // Start of Frame Modify
const PORTSC1: u16 = 0x10; // Port 1 Status/Control
const PORTSC2: u16 = 0x12; // Port 2 Status/Control

// USBCMD bits
const CMD_RS: u16 = 0x0001; // Run/Stop
const CMD_HCRESET: u16 = 0x0002; // Host Controller Reset
const CMD_GRESET: u16 = 0x0004; // Global Reset
const CMD_EGSM: u16 = 0x0008; // Enter Global Suspend Mode
const CMD_FGR: u16 = 0x0010; // Force Global Resume
const CMD_SWDBG: u16 = 0x0020; // Software Debug
const CMD_CF: u16 = 0x0040; // Configure Flag
const CMD_MAXP: u16 = 0x0080; // Max Packet (64 bytes)

// USBSTS bits
const STS_USBINT: u16 = 0x0001; // USB Interrupt
const STS_ERROR: u16 = 0x0002; // USB Error Interrupt
const STS_RD: u16 = 0x0004; // Resume Detect
const STS_HSE: u16 = 0x0008; // Host System Error
const STS_HCPE: u16 = 0x0010; // Host Controller Process Error
const STS_HCH: u16 = 0x0020; // HC Halted

// PORTSC bits
const PORT_CCS: u16 = 0x0001; // Current Connect Status
const PORT_CSC: u16 = 0x0002; // Connect Status Change
const PORT_PE: u16 = 0x0004; // Port Enabled
const PORT_PEC: u16 = 0x0008; // Port Enable Change
const PORT_LS: u16 = 0x0030; // Line Status
const PORT_RD: u16 = 0x0040; // Resume Detect
const PORT_LSDA: u16 = 0x0100; // Low Speed Device Attached
const PORT_PR: u16 = 0x0200; // Port Reset
const PORT_SUSP: u16 = 0x1000; // Suspend

// Frame list size
const FRAME_LIST_SIZE: usize = 1024;

// Transfer Descriptor
pub const TransferDescriptor = extern struct {
    link_ptr: u32, // Link pointer to next TD
    control: u32, // Control and status
    token: u32, // Token (PID, address, endpoint, etc)
    buffer_ptr: u32, // Buffer pointer
    // Software use (not read by hardware)
    software: [4]u32,
};

// Queue Head
pub const QueueHead = extern struct {
    head_link: u32, // Queue Head Link Pointer
    element_link: u32, // Queue Element Link Pointer
    // Software use
    software: [2]u32,
};

var io_base: u16 = 0;
var irq_line: u8 = 0;
var frame_list: ?[*]u32 = null;
var initialized: bool = false;
var pci_device: ?*const pci.PciDevice = null;

// Port status
var port1_connected: bool = false;
var port2_connected: bool = false;
var port1_low_speed: bool = false;
var port2_low_speed: bool = false;

/// Read UHCI register
fn readReg16(offset: u16) u16 {
    return io.inw(io_base + offset);
}

/// Write UHCI register
fn writeReg16(offset: u16, value: u16) void {
    io.outw(io_base + offset, value);
}

/// Read 32-bit register
fn readReg32(offset: u16) u32 {
    return io.inl(io_base + offset);
}

/// Write 32-bit register
fn writeReg32(offset: u16, value: u32) void {
    io.outl(io_base + offset, value);
}

/// Reset the controller
fn resetController() bool {
    serial.write("UHCI: Resetting controller...\n");

    // Global reset
    writeReg16(USBCMD, CMD_GRESET);

    // Wait ~10ms
    var i: u32 = 0;
    while (i < 100000) : (i += 1) {
        asm volatile ("nop");
    }

    writeReg16(USBCMD, 0);

    // Host controller reset
    writeReg16(USBCMD, CMD_HCRESET);

    // Wait for reset to complete
    var timeout: u32 = 0;
    while (timeout < 100) : (timeout += 1) {
        if ((readReg16(USBCMD) & CMD_HCRESET) == 0) {
            serial.write("UHCI: Reset complete\n");
            return true;
        }
        // Small delay
        var j: u32 = 0;
        while (j < 10000) : (j += 1) {
            asm volatile ("nop");
        }
    }

    serial.write("UHCI: Reset timeout\n");
    return false;
}

/// Initialize frame list
fn initFrameList() bool {
    // Allocate frame list (must be 4KB aligned)
    const size = FRAME_LIST_SIZE * 4;
    const ptr = heap.alloc(size + 4096);
    if (ptr == null) {
        serial.write("UHCI: Failed to allocate frame list\n");
        return false;
    }

    // Align to 4KB
    const addr = @intFromPtr(ptr);
    const aligned = (addr + 4095) & ~@as(u32, 4095);
    frame_list = @ptrFromInt(aligned);

    // Initialize all entries to terminate
    var i: usize = 0;
    while (i < FRAME_LIST_SIZE) : (i += 1) {
        frame_list.?[i] = 0x00000001; // Terminate bit
    }

    // Set frame list base address
    writeReg32(FRBASEADD, aligned);

    serial.write("UHCI: Frame list at 0x");
    serial.writeHex(aligned);
    serial.write("\n");

    return true;
}

/// Check port status
fn checkPorts() void {
    const port1 = readReg16(PORTSC1);
    const port2 = readReg16(PORTSC2);

    port1_connected = (port1 & PORT_CCS) != 0;
    port2_connected = (port2 & PORT_CCS) != 0;
    port1_low_speed = (port1 & PORT_LSDA) != 0;
    port2_low_speed = (port2 & PORT_LSDA) != 0;

    serial.write("UHCI: Port 1: ");
    if (port1_connected) {
        serial.write("Connected (");
        serial.write(if (port1_low_speed) "Low" else "Full");
        serial.write(" Speed)\n");
    } else {
        serial.write("Not connected\n");
    }

    serial.write("UHCI: Port 2: ");
    if (port2_connected) {
        serial.write("Connected (");
        serial.write(if (port2_low_speed) "Low" else "Full");
        serial.write(" Speed)\n");
    } else {
        serial.write("Not connected\n");
    }
}

/// Reset a port
pub fn resetPort(port: u8) bool {
    const reg: u16 = if (port == 1) PORTSC1 else PORTSC2;

    serial.write("UHCI: Resetting port ");
    serial.writeInt(@as(u32, port));
    serial.write("...\n");

    // Set reset bit
    writeReg16(reg, PORT_PR);

    // Wait ~50ms
    var i: u32 = 0;
    while (i < 500000) : (i += 1) {
        asm volatile ("nop");
    }

    // Clear reset bit
    writeReg16(reg, 0);

    // Wait for port to stabilize
    i = 0;
    while (i < 100000) : (i += 1) {
        asm volatile ("nop");
    }

    // Enable port
    var status = readReg16(reg);
    status |= PORT_PE;
    writeReg16(reg, status);

    // Clear status change bits
    status = readReg16(reg);
    writeReg16(reg, status | PORT_CSC | PORT_PEC);

    return (readReg16(reg) & PORT_PE) != 0;
}

/// Initialize UHCI controller
pub fn init() bool {
    serial.write("UHCI: Scanning for UHCI controller...\n");

    // Initialize PCI if not done
    if (!pci.isInitialized()) {
        pci.init();
    }

    // Find UHCI controller
    pci_device = pci.findUsbController(pci.PROGIF_UHCI);
    if (pci_device == null) {
        serial.write("UHCI: No UHCI controller found\n");
        return false;
    }

    const dev = pci_device.?;
    serial.write("UHCI: Found at PCI ");
    serial.writeInt(@as(u32, dev.bus));
    serial.write(":");
    serial.writeInt(@as(u32, dev.slot));
    serial.write("\n");

    // Get I/O base from BAR4 (UHCI uses BAR4)
    const bar4 = dev.bar4;
    if ((bar4 & 1) == 0) {
        serial.write("UHCI: BAR4 is not I/O space\n");
        return false;
    }
    io_base = @truncate(bar4 & 0xFFFC);
    irq_line = dev.irq_line;

    serial.write("UHCI: I/O base = 0x");
    serial.writeHex(@as(u32, io_base));
    serial.write(", IRQ = ");
    serial.writeInt(@as(u32, irq_line));
    serial.write("\n");

    // Enable bus mastering and I/O space
    pci.enableBusMaster(dev);
    pci.enableIoSpace(dev);

    // Reset controller
    if (!resetController()) {
        return false;
    }

    // Initialize frame list
    if (!initFrameList()) {
        return false;
    }

    // Set frame number to 0
    writeReg16(FRNUM, 0);

    // Set SOF timing
    writeReg16(SOFMOD, 64); // Default value

    // Enable interrupts
    writeReg16(USBINTR, 0x000F); // All interrupts

    // Enable IRQ
    if (irq_line < 16) {
        pic.clearMask(irq_line);
    }

    // Start controller
    writeReg16(USBCMD, CMD_RS | CMD_CF | CMD_MAXP);

    // Check if running
    if ((readReg16(USBSTS) & STS_HCH) != 0) {
        serial.write("UHCI: Controller failed to start\n");
        return false;
    }

    // Check ports
    checkPorts();

    initialized = true;
    serial.write("UHCI: Initialized successfully\n");
    return true;
}

/// Handle interrupt
pub fn handleInterrupt() void {
    if (!initialized) return;

    const status = readReg16(USBSTS);

    // Clear interrupt bits
    writeReg16(USBSTS, status);

    if ((status & STS_USBINT) != 0) {
        serial.write("UHCI: Transfer complete\n");
    }
    if ((status & STS_ERROR) != 0) {
        serial.write("UHCI: Transfer error\n");
    }
    if ((status & STS_RD) != 0) {
        serial.write("UHCI: Resume detect\n");
    }
    if ((status & STS_HSE) != 0) {
        serial.write("UHCI: Host system error\n");
    }
}

/// Check if initialized
pub fn isInitialized() bool {
    return initialized;
}

/// Get port count
pub fn getPortCount() u8 {
    return 2; // UHCI always has 2 root ports
}

/// Check if port has device
pub fn isPortConnected(port: u8) bool {
    if (port == 1) return port1_connected;
    if (port == 2) return port2_connected;
    return false;
}

/// Check if port device is low speed
pub fn isPortLowSpeed(port: u8) bool {
    if (port == 1) return port1_low_speed;
    if (port == 2) return port2_low_speed;
    return false;
}

/// Get controller status
pub fn getStatus() u16 {
    if (!initialized) return 0;
    return readReg16(USBSTS);
}

/// Get frame number
pub fn getFrameNumber() u16 {
    if (!initialized) return 0;
    return readReg16(FRNUM) & 0x7FF;
}
