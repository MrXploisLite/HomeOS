// Home OS - RTL8139 Network Driver
// Copyright © 2025 Romy Rianata - Home OS
// Phase 13: Network Stack - NIC Driver

const io = @import("../arch/io.zig");
const serial = @import("../drivers/serial.zig");
const pic = @import("../arch/pic.zig");
const ethernet = @import("ethernet.zig");
const ipv4 = @import("ipv4.zig");
const icmp = @import("icmp.zig");
const arp = @import("arp.zig");
const pit = @import("../drivers/pit.zig");
const pingui = @import("../gui/apps/pingui.zig");

// RTL8139 PCI IDs
pub const RTL8139_VENDOR_ID: u16 = 0x10EC;
pub const RTL8139_DEVICE_ID: u16 = 0x8139;

// RTL8139 Registers (offsets from I/O base)
const REG_MAC0: u16 = 0x00; // MAC address (6 bytes)
const REG_MAR0: u16 = 0x08; // Multicast filter
const REG_TXSTATUS0: u16 = 0x10; // Transmit status (4 descriptors)
const REG_TXADDR0: u16 = 0x20; // Transmit address (4 descriptors)
const REG_RXBUF: u16 = 0x30; // Receive buffer start
const REG_CMD: u16 = 0x37; // Command register
const REG_CAPR: u16 = 0x38; // Current address of packet read
const REG_CBR: u16 = 0x3A; // Current buffer address
const REG_IMR: u16 = 0x3C; // Interrupt mask
const REG_ISR: u16 = 0x3E; // Interrupt status
const REG_TCR: u16 = 0x40; // Transmit config
const REG_RCR: u16 = 0x44; // Receive config
const REG_CONFIG1: u16 = 0x52; // Config register 1

// Command register bits
const CMD_RESET: u8 = 0x10;
const CMD_RX_ENABLE: u8 = 0x08;
const CMD_TX_ENABLE: u8 = 0x04;

// Interrupt bits
const INT_ROK: u16 = 0x0001; // Receive OK
const INT_RER: u16 = 0x0002; // Receive error
const INT_TOK: u16 = 0x0004; // Transmit OK
const INT_TER: u16 = 0x0008; // Transmit error
const INT_RXOVW: u16 = 0x0010; // Rx buffer overflow
const INT_LINK: u16 = 0x0020; // Link change
const INT_FOVW: u16 = 0x0040; // Rx FIFO overflow
const INT_TIMEOUT: u16 = 0x4000; // Timeout

// Receive config bits
const RCR_AAP: u32 = 0x01; // Accept all packets
const RCR_APM: u32 = 0x02; // Accept physical match
const RCR_AM: u32 = 0x04; // Accept multicast
const RCR_AB: u32 = 0x08; // Accept broadcast
const RCR_WRAP: u32 = 0x80; // Wrap mode
const RCR_MXDMA: u32 = 0x700; // Max DMA burst (111 = unlimited)
const RCR_RBLEN: u32 = 0x1800; // Rx buffer length (11 = 64K)

// Transmit config bits
const TCR_MXDMA: u32 = 0x700; // Max DMA burst
const TCR_IFG: u32 = 0x3000000; // Interframe gap

// Buffer sizes
const RX_BUFFER_SIZE: usize = 8192 + 16 + 1500; // 8K + header + MTU
const TX_BUFFER_SIZE: usize = 1536;
const NUM_TX_DESC: usize = 4;

// Driver state
pub const Rtl8139 = struct {
    io_base: u16,
    mac_address: ethernet.MacAddress,
    rx_buffer: [RX_BUFFER_SIZE]u8 align(4),
    tx_buffers: [NUM_TX_DESC][TX_BUFFER_SIZE]u8 align(4),
    rx_offset: u16,
    tx_cur: u8,
    initialized: bool,
    link_up: bool,
    rx_packets: u32,
    tx_packets: u32,
    rx_errors: u32,
    tx_errors: u32,

    pub fn init() Rtl8139 {
        return Rtl8139{
            .io_base = 0,
            .mac_address = ethernet.ZERO_MAC,
            .rx_buffer = undefined,
            .tx_buffers = undefined,
            .rx_offset = 0,
            .tx_cur = 0,
            .initialized = false,
            .link_up = false,
            .rx_packets = 0,
            .tx_packets = 0,
            .rx_errors = 0,
            .tx_errors = 0,
        };
    }
};

// Global driver instance
var rtl8139: Rtl8139 = Rtl8139.init();

// PCI Configuration Space access
fn pciConfigRead32(bus: u8, slot: u8, func: u8, offset: u8) u32 {
    const address: u32 = (1 << 31) | // Enable bit
        (@as(u32, bus) << 16) |
        (@as(u32, slot) << 11) |
        (@as(u32, func) << 8) |
        (@as(u32, offset) & 0xFC);

    io.outl(0xCF8, address);
    return io.inl(0xCFC);
}

fn pciConfigRead16(bus: u8, slot: u8, func: u8, offset: u8) u16 {
    const val = pciConfigRead32(bus, slot, func, offset & 0xFC);
    return @truncate(val >> @as(u5, @truncate((offset & 2) * 8)));
}

fn pciConfigWrite32(bus: u8, slot: u8, func: u8, offset: u8, value: u32) void {
    const address: u32 = (1 << 31) |
        (@as(u32, bus) << 16) |
        (@as(u32, slot) << 11) |
        (@as(u32, func) << 8) |
        (@as(u32, offset) & 0xFC);

    io.outl(0xCF8, address);
    io.outl(0xCFC, value);
}

/// Scan PCI bus for RTL8139
fn findRtl8139() ?struct { bus: u8, slot: u8 } {
    var bus: u8 = 0;
    while (bus < 8) : (bus += 1) {
        var slot: u8 = 0;
        while (slot < 32) : (slot += 1) {
            const vendor = pciConfigRead16(bus, slot, 0, 0);
            if (vendor == 0xFFFF) continue;

            const device = pciConfigRead16(bus, slot, 0, 2);

            if (vendor == RTL8139_VENDOR_ID and device == RTL8139_DEVICE_ID) {
                serial.write("RTL8139: Found at PCI ");
                serial.writeInt(@as(u32, bus));
                serial.write(":");
                serial.writeInt(@as(u32, slot));
                serial.write("\n");
                return .{ .bus = bus, .slot = slot };
            }
        }
    }
    return null;
}

/// Initialize RTL8139 driver
pub fn init() bool {
    serial.write("RTL8139: Scanning PCI bus...\n");

    const pci_loc = findRtl8139() orelse {
        serial.write("RTL8139: Not found\n");
        return false;
    };

    // Get I/O base address from BAR0
    const bar0 = pciConfigRead32(pci_loc.bus, pci_loc.slot, 0, 0x10);
    rtl8139.io_base = @truncate(bar0 & 0xFFFC);

    serial.write("RTL8139: I/O base = 0x");
    serial.writeHex(@as(u32, rtl8139.io_base));
    serial.write("\n");

    // Enable PCI bus mastering
    var cmd = pciConfigRead32(pci_loc.bus, pci_loc.slot, 0, 0x04);
    cmd |= 0x05; // I/O space + bus master
    pciConfigWrite32(pci_loc.bus, pci_loc.slot, 0, 0x04, cmd);

    // Power on
    io.outb(rtl8139.io_base + REG_CONFIG1, 0x00);

    // Software reset
    io.outb(rtl8139.io_base + REG_CMD, CMD_RESET);

    // Wait for reset to complete
    var timeout: u32 = 0;
    while ((io.inb(rtl8139.io_base + REG_CMD) & CMD_RESET) != 0) {
        timeout += 1;
        if (timeout > 100000) {
            serial.write("RTL8139: Reset timeout\n");
            return false;
        }
    }

    // Read MAC address
    var i: u16 = 0;
    while (i < 6) : (i += 1) {
        rtl8139.mac_address[i] = io.inb(rtl8139.io_base + REG_MAC0 + i);
    }

    serial.write("RTL8139: MAC = ");
    ethernet.printMac(rtl8139.mac_address);
    serial.write("\n");

    // Setup receive buffer
    const rx_buf_phys = @intFromPtr(&rtl8139.rx_buffer);
    io.outl(rtl8139.io_base + REG_RXBUF, @truncate(rx_buf_phys));

    // Initialize CAPR to 0xFFF0 (hardware quirk - starts at -16)
    io.outw(rtl8139.io_base + REG_CAPR, 0xFFF0);
    rtl8139.rx_offset = 0;

    // Enable NIC interrupts for receive
    io.outw(rtl8139.io_base + REG_IMR, INT_ROK | INT_TOK | INT_RER | INT_TER);

    // Enable IRQ11 (typical for RTL8139 in QEMU)
    pic.clearMask(11);

    // Configure receive
    io.outl(rtl8139.io_base + REG_RCR, RCR_APM | RCR_AB | RCR_AM | RCR_AAP | RCR_WRAP | (7 << 8) | (3 << 11));

    // Configure transmit
    io.outl(rtl8139.io_base + REG_TCR, (6 << 8) | (3 << 24));

    // Enable Rx and Tx
    io.outb(rtl8139.io_base + REG_CMD, CMD_RX_ENABLE | CMD_TX_ENABLE);

    rtl8139.initialized = true;
    rtl8139.link_up = true;

    serial.write("RTL8139: Initialized\n");
    return true;
}

/// Send packet
pub fn send(data: []const u8) bool {
    if (!rtl8139.initialized) return false;
    if (data.len > TX_BUFFER_SIZE) return false;

    const desc = rtl8139.tx_cur;

    // Copy data to TX buffer
    for (data, 0..) |byte, j| {
        rtl8139.tx_buffers[desc][j] = byte;
    }

    // Set TX address
    const tx_buf_phys = @intFromPtr(&rtl8139.tx_buffers[desc]);
    io.outl(rtl8139.io_base + REG_TXADDR0 + @as(u16, desc) * 4, @truncate(tx_buf_phys));

    // Set TX status (start transmission)
    io.outl(rtl8139.io_base + REG_TXSTATUS0 + @as(u16, desc) * 4, @truncate(data.len));

    // Move to next descriptor
    rtl8139.tx_cur = @truncate((desc + 1) % NUM_TX_DESC);
    rtl8139.tx_packets += 1;

    return true;
}

/// Handle interrupt (exported for assembly ISR)
export fn rtl8139_handleInterrupt() callconv(.c) void {
    handleInterrupt();
}

/// Handle interrupt
pub fn handleInterrupt() void {
    if (!rtl8139.initialized) return;

    const status = io.inw(rtl8139.io_base + REG_ISR);
    if (status == 0) return; // Spurious interrupt

    // IMPORTANT: Acknowledge interrupt BEFORE reading packets (per OSDev wiki)
    io.outw(rtl8139.io_base + REG_ISR, status);

    if ((status & INT_ROK) != 0) {
        // Receive OK - packet received
        serial.write("RTL8139: IRQ ROK\n");
        receivePackets();
    }

    if ((status & INT_TOK) != 0) {
        // Transmit OK - silent
    }

    if ((status & INT_RER) != 0) {
        rtl8139.rx_errors += 1;
        serial.write("RTL8139: RX Error\n");
    }

    if ((status & INT_TER) != 0) {
        rtl8139.tx_errors += 1;
        serial.write("RTL8139: TX Error\n");
    }
}

/// Receive packets from buffer
fn receivePackets() void {
    // Check if buffer is empty (BUFE bit in CMD register)
    // Bit 0 = BUFE (Buffer Empty) - when 1, no packets to read
    while ((io.inb(rtl8139.io_base + REG_CMD) & 0x01) == 0) {
        // Read packet header at current offset
        const offset = rtl8139.rx_offset;

        // Packet header: 2 bytes status + 2 bytes length
        const header_ptr: [*]const u8 = @ptrCast(&rtl8139.rx_buffer[offset]);

        const status: u16 = @as(u16, header_ptr[0]) | (@as(u16, header_ptr[1]) << 8);
        const length: u16 = @as(u16, header_ptr[2]) | (@as(u16, header_ptr[3]) << 8);

        // Check ROK bit (bit 0) - Receive OK
        if ((status & 0x01) == 0) {
            serial.write("RTL8139: Bad packet status 0x");
            serial.writeHex(@as(u32, status));
            serial.write("\n");
            break;
        }

        // Sanity check length
        if (length < 4 or length > 1518 + 4) {
            serial.write("RTL8139: Bad packet length ");
            serial.writeInt(@as(u32, length));
            serial.write("\n");
            break;
        }

        // Process packet (skip 4-byte header, length includes 4-byte CRC)
        const packet_len = length - 4; // Remove CRC
        if (offset + 4 + packet_len <= RX_BUFFER_SIZE) {
            const packet_data = rtl8139.rx_buffer[offset + 4 .. offset + 4 + packet_len];
            processPacket(packet_data);
        }

        rtl8139.rx_packets += 1;

        // Update offset: header(4) + length, aligned to 4 bytes
        const new_offset = (offset + length + 4 + 3) & 0xFFFC;
        rtl8139.rx_offset = @truncate(new_offset % (RX_BUFFER_SIZE - 16));

        // Update CAPR (Current Address of Packet Read)
        // CAPR is offset - 16 (hardware quirk)
        io.outw(rtl8139.io_base + REG_CAPR, rtl8139.rx_offset -% 16);
    }
}

/// Process received packet
fn processPacket(data: []const u8) void {
    if (data.len < ethernet.ETH_HLEN) return;

    serial.write("RTL8139: RX ");
    serial.writeInt(@truncate(data.len));
    serial.write(" bytes\n");

    // Parse Ethernet header
    const eth_header: *const ethernet.EthernetHeader = @ptrCast(@alignCast(data.ptr));
    const ethertype = eth_header.getEtherType();

    switch (ethertype) {
        ethernet.ETH_TYPE_ARP => {
            // Process ARP packet
            if (data.len >= ethernet.ETH_HLEN + @sizeOf(arp.ArpPacket)) {
                const arp_pkt: *const arp.ArpPacket = @ptrCast(@alignCast(data.ptr + ethernet.ETH_HLEN));
                arp.processPacket(arp_pkt, pit.getTicks());
            }
        },
        ethernet.ETH_TYPE_IPV4 => {
            // Process IPv4 packet
            processIpv4Packet(data[ethernet.ETH_HLEN..]);
        },
        else => {},
    }
}

/// Process IPv4 packet
fn processIpv4Packet(data: []const u8) void {
    if (data.len < @sizeOf(ipv4.IPv4Header)) return;

    const ip_header: *const ipv4.IPv4Header = @ptrCast(@alignCast(data.ptr));
    const protocol = ip_header.protocol;
    const header_len = (@as(usize, ip_header.version_ihl) & 0x0F) * 4;

    if (data.len < header_len) return;

    const src_ip = ip_header.src_ip;

    if (protocol == ipv4.IPPROTO_ICMP) {
        // ICMP packet
        processIcmpPacket(data[header_len..], src_ip);
    }
}

/// Process ICMP packet
fn processIcmpPacket(data: []const u8, src_ip: ipv4.IPv4Address) void {
    if (data.len < @sizeOf(icmp.IcmpHeader)) return;

    const icmp_header: *const icmp.IcmpHeader = @ptrCast(@alignCast(data.ptr));

    if (icmp_header.isEchoReply()) {
        serial.write("RTL8139: ICMP Echo Reply from ");
        serial.writeInt(@as(u32, src_ip[0]));
        serial.write(".");
        serial.writeInt(@as(u32, src_ip[1]));
        serial.write(".");
        serial.writeInt(@as(u32, src_ip[2]));
        serial.write(".");
        serial.writeInt(@as(u32, src_ip[3]));
        serial.write(" seq=");
        serial.writeInt(@as(u32, icmp_header.getSequence()));
        serial.write("\n");

        // Notify ping GUI
        pingui.onPingReply(src_ip, icmp_header.getSequence());
    }
}

/// Get MAC address
pub fn getMacAddress() ethernet.MacAddress {
    return rtl8139.mac_address;
}

/// Set MAC address (for MAC randomization)
pub fn setMacAddress(mac: ethernet.MacAddress) bool {
    if (!rtl8139.initialized) return false;

    // Disable Rx/Tx before changing MAC
    io.outb(rtl8139.io_base + REG_CMD, 0x00);

    // Write new MAC address
    var i: u16 = 0;
    while (i < 6) : (i += 1) {
        io.outb(rtl8139.io_base + REG_MAC0 + i, mac[i]);
    }

    // Verify write
    i = 0;
    while (i < 6) : (i += 1) {
        if (io.inb(rtl8139.io_base + REG_MAC0 + i) != mac[i]) {
            // Restore original and re-enable
            var j: u16 = 0;
            while (j < 6) : (j += 1) {
                io.outb(rtl8139.io_base + REG_MAC0 + j, rtl8139.mac_address[j]);
            }
            io.outb(rtl8139.io_base + REG_CMD, CMD_RX_ENABLE | CMD_TX_ENABLE);
            return false;
        }
    }

    // Update stored MAC
    rtl8139.mac_address = mac;

    // Re-enable Rx/Tx
    io.outb(rtl8139.io_base + REG_CMD, CMD_RX_ENABLE | CMD_TX_ENABLE);

    return true;
}

/// Check if initialized
pub fn isInitialized() bool {
    return rtl8139.initialized;
}

/// Check link status
pub fn isLinkUp() bool {
    return rtl8139.link_up;
}

/// Get statistics
pub fn getStats() struct { rx: u32, tx: u32, rx_err: u32, tx_err: u32 } {
    return .{
        .rx = rtl8139.rx_packets,
        .tx = rtl8139.tx_packets,
        .rx_err = rtl8139.rx_errors,
        .tx_err = rtl8139.tx_errors,
    };
}
