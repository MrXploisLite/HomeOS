// Home OS - USB Core Driver
// Copyright © 2025 Romy Rianata - Home OS
// Phase 16: USB Support

const serial = @import("serial.zig");
const uhci = @import("uhci.zig");
const pci = @import("pci.zig");

// USB Device Classes
pub const CLASS_INTERFACE: u8 = 0x00;
pub const CLASS_AUDIO: u8 = 0x01;
pub const CLASS_CDC: u8 = 0x02;
pub const CLASS_HID: u8 = 0x03;
pub const CLASS_PHYSICAL: u8 = 0x05;
pub const CLASS_IMAGE: u8 = 0x06;
pub const CLASS_PRINTER: u8 = 0x07;
pub const CLASS_MASS_STORAGE: u8 = 0x08;
pub const CLASS_HUB: u8 = 0x09;
pub const CLASS_CDC_DATA: u8 = 0x0A;
pub const CLASS_VENDOR: u8 = 0xFF;

// USB Request Types
pub const REQ_GET_STATUS: u8 = 0x00;
pub const REQ_CLEAR_FEATURE: u8 = 0x01;
pub const REQ_SET_FEATURE: u8 = 0x03;
pub const REQ_SET_ADDRESS: u8 = 0x05;
pub const REQ_GET_DESCRIPTOR: u8 = 0x06;
pub const REQ_SET_DESCRIPTOR: u8 = 0x07;
pub const REQ_GET_CONFIG: u8 = 0x08;
pub const REQ_SET_CONFIG: u8 = 0x09;
pub const REQ_GET_INTERFACE: u8 = 0x0A;
pub const REQ_SET_INTERFACE: u8 = 0x0B;

// Descriptor Types
pub const DESC_DEVICE: u8 = 0x01;
pub const DESC_CONFIG: u8 = 0x02;
pub const DESC_STRING: u8 = 0x03;
pub const DESC_INTERFACE: u8 = 0x04;
pub const DESC_ENDPOINT: u8 = 0x05;
pub const DESC_HID: u8 = 0x21;
pub const DESC_REPORT: u8 = 0x22;

// USB Speed
pub const Speed = enum(u8) {
    low = 0, // 1.5 Mbps
    full = 1, // 12 Mbps
    high = 2, // 480 Mbps (USB 2.0)
};

// USB Device Descriptor
pub const DeviceDescriptor = extern struct {
    length: u8,
    descriptor_type: u8,
    usb_version: u16,
    device_class: u8,
    device_subclass: u8,
    device_protocol: u8,
    max_packet_size: u8,
    vendor_id: u16,
    product_id: u16,
    device_version: u16,
    manufacturer_index: u8,
    product_index: u8,
    serial_index: u8,
    num_configurations: u8,
};

// USB Configuration Descriptor
pub const ConfigDescriptor = extern struct {
    length: u8,
    descriptor_type: u8,
    total_length: u16,
    num_interfaces: u8,
    config_value: u8,
    config_index: u8,
    attributes: u8,
    max_power: u8,
};

// USB Interface Descriptor
pub const InterfaceDescriptor = extern struct {
    length: u8,
    descriptor_type: u8,
    interface_number: u8,
    alternate_setting: u8,
    num_endpoints: u8,
    interface_class: u8,
    interface_subclass: u8,
    interface_protocol: u8,
    interface_index: u8,
};

// USB Endpoint Descriptor
pub const EndpointDescriptor = extern struct {
    length: u8,
    descriptor_type: u8,
    endpoint_address: u8,
    attributes: u8,
    max_packet_size: u16,
    interval: u8,
};

// USB Device
pub const UsbDevice = struct {
    address: u8,
    speed: Speed,
    port: u8,
    vendor_id: u16,
    product_id: u16,
    device_class: u8,
    device_subclass: u8,
    max_packet_size: u8,
    configured: bool,
    present: bool,
};

// Controller type
pub const ControllerType = enum {
    none,
    uhci,
    ohci,
    ehci,
    xhci,
};

const MAX_DEVICES: usize = 16;
var devices: [MAX_DEVICES]UsbDevice = undefined;
var device_count: usize = 0;
var next_address: u8 = 1;
var controller_type: ControllerType = .none;
var initialized: bool = false;

/// Initialize USB subsystem
pub fn init() bool {
    serial.write("USB: Initializing USB subsystem...\n");

    // Initialize PCI first
    if (!pci.isInitialized()) {
        pci.init();
    }

    // Clear device list
    device_count = 0;
    next_address = 1;
    for (&devices) |*dev| {
        dev.present = false;
        dev.configured = false;
    }

    // Try UHCI first (most common in QEMU)
    if (uhci.init()) {
        controller_type = .uhci;
        serial.write("USB: Using UHCI controller\n");

        // Enumerate devices on root ports
        enumerateRootPorts();

        initialized = true;
        serial.write("USB: Ready\n");
        return true;
    }

    // NOTE: OHCI, EHCI, XHCI support planned for future phases

    serial.write("USB: No USB controller found\n");
    return false;
}

/// Enumerate devices on root hub ports
fn enumerateRootPorts() void {
    serial.write("USB: Enumerating root ports...\n");

    const port_count = uhci.getPortCount();
    var port: u8 = 1;
    while (port <= port_count) : (port += 1) {
        if (uhci.isPortConnected(port)) {
            serial.write("USB: Device on port ");
            serial.writeInt(@as(u32, port));
            serial.write("\n");

            // Reset port
            if (uhci.resetPort(port)) {
                // Add device
                if (device_count < MAX_DEVICES) {
                    devices[device_count] = UsbDevice{
                        .address = 0, // Default address until configured
                        .speed = if (uhci.isPortLowSpeed(port)) .low else .full,
                        .port = port,
                        .vendor_id = 0,
                        .product_id = 0,
                        .device_class = 0,
                        .device_subclass = 0,
                        .max_packet_size = 8, // Default for control
                        .configured = false,
                        .present = true,
                    };
                    device_count += 1;

                    serial.write("USB: Device added (");
                    serial.write(if (uhci.isPortLowSpeed(port)) "Low" else "Full");
                    serial.write(" Speed)\n");
                }
            }
        }
    }

    serial.write("USB: Found ");
    serial.writeInt(@truncate(device_count));
    serial.write(" device(s)\n");
}

/// Check if initialized
pub fn isInitialized() bool {
    return initialized;
}

/// Get controller type
pub fn getControllerType() ControllerType {
    return controller_type;
}

/// Get controller name
pub fn getControllerName() []const u8 {
    return switch (controller_type) {
        .none => "None",
        .uhci => "UHCI (USB 1.x)",
        .ohci => "OHCI (USB 1.x)",
        .ehci => "EHCI (USB 2.0)",
        .xhci => "xHCI (USB 3.x)",
    };
}

/// Get device count
pub fn getDeviceCount() usize {
    return device_count;
}

/// Get device by index
pub fn getDevice(index: usize) ?*const UsbDevice {
    if (index >= device_count) return null;
    if (!devices[index].present) return null;
    return &devices[index];
}

/// Get class name
pub fn getClassName(class: u8) []const u8 {
    return switch (class) {
        CLASS_INTERFACE => "Interface-specific",
        CLASS_AUDIO => "Audio",
        CLASS_CDC => "CDC (Communications)",
        CLASS_HID => "HID (Human Interface)",
        CLASS_PHYSICAL => "Physical",
        CLASS_IMAGE => "Image",
        CLASS_PRINTER => "Printer",
        CLASS_MASS_STORAGE => "Mass Storage",
        CLASS_HUB => "Hub",
        CLASS_CDC_DATA => "CDC Data",
        CLASS_VENDOR => "Vendor-specific",
        else => "Unknown",
    };
}

/// Handle USB interrupt
pub fn handleInterrupt() void {
    if (controller_type == .uhci) {
        uhci.handleInterrupt();
    }
}
