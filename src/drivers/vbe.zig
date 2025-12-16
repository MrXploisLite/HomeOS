// Home OS - VBE/VESA Graphics Driver
// Copyright © 2025 Romy Rianata - Home OS
// Phase 14: Graphics & Display

const serial = @import("serial.zig");
const io = @import("../arch/io.zig");
const paging = @import("../mm/paging.zig");

// VBE Info Block (returned by INT 10h, AX=4F00h)
pub const VbeInfoBlock = extern struct {
    signature: [4]u8, // "VESA"
    version: u16, // VBE version (e.g., 0x0300 for 3.0)
    oem_string_ptr: u32, // Far pointer to OEM string
    capabilities: u32, // Capabilities flags
    video_modes_ptr: u32, // Far pointer to video mode list
    total_memory: u16, // Number of 64KB blocks
    oem_software_rev: u16,
    oem_vendor_name_ptr: u32,
    oem_product_name_ptr: u32,
    oem_product_rev_ptr: u32,
    reserved: [222]u8,
    oem_data: [256]u8,
};

// VBE Mode Info Block (returned by INT 10h, AX=4F01h)
pub const VbeModeInfo = extern struct {
    attributes: u16,
    window_a: u8,
    window_b: u8,
    granularity: u16,
    window_size: u16,
    segment_a: u16,
    segment_b: u16,
    win_func_ptr: u32,
    pitch: u16, // Bytes per scanline
    width: u16, // Horizontal resolution
    height: u16, // Vertical resolution
    w_char: u8,
    y_char: u8,
    planes: u8,
    bpp: u8, // Bits per pixel
    banks: u8,
    memory_model: u8,
    bank_size: u8,
    image_pages: u8,
    reserved0: u8,
    red_mask: u8,
    red_position: u8,
    green_mask: u8,
    green_position: u8,
    blue_mask: u8,
    blue_position: u8,
    reserved_mask: u8,
    reserved_position: u8,
    direct_color_attributes: u8,
    framebuffer: u32, // Physical address of framebuffer
    off_screen_mem_off: u32,
    off_screen_mem_size: u16,
    reserved1: [206]u8,
};

// Framebuffer state
pub const Framebuffer = struct {
    address: [*]volatile u8,
    width: u32,
    height: u32,
    pitch: u32,
    bpp: u8,
    bytes_per_pixel: u8,
    size: u32,
    initialized: bool,

    pub fn init() Framebuffer {
        return Framebuffer{
            .address = @ptrFromInt(1), // Placeholder, will be set properly
            .width = 0,
            .height = 0,
            .pitch = 0,
            .bpp = 0,
            .bytes_per_pixel = 0,
            .size = 0,
            .initialized = false,
        };
    }
};

var framebuffer: Framebuffer = Framebuffer{
    .address = @ptrFromInt(0xFD000000), // Will be updated at runtime
    .width = 0,
    .height = 0,
    .pitch = 0,
    .bpp = 0,
    .bytes_per_pixel = 0,
    .size = 0,
    .initialized = false,
};

// Standard VGA ports for basic mode setting
const VGA_MISC_WRITE: u16 = 0x3C2;
const VGA_SEQ_INDEX: u16 = 0x3C4;
const VGA_SEQ_DATA: u16 = 0x3C5;
const VGA_CRTC_INDEX: u16 = 0x3D4;
const VGA_CRTC_DATA: u16 = 0x3D5;
const VGA_GC_INDEX: u16 = 0x3CE;
const VGA_GC_DATA: u16 = 0x3CF;
const VGA_AC_INDEX: u16 = 0x3C0;
const VGA_AC_WRITE: u16 = 0x3C0;
const VGA_AC_READ: u16 = 0x3C1;
const VGA_INSTAT_READ: u16 = 0x3DA;

// BGA (Bochs Graphics Adapter) - works in QEMU/Bochs
const VBE_DISPI_IOPORT_INDEX: u16 = 0x01CE;
const VBE_DISPI_IOPORT_DATA: u16 = 0x01CF;

const VBE_DISPI_INDEX_ID: u16 = 0;
const VBE_DISPI_INDEX_XRES: u16 = 1;
const VBE_DISPI_INDEX_YRES: u16 = 2;
const VBE_DISPI_INDEX_BPP: u16 = 3;
const VBE_DISPI_INDEX_ENABLE: u16 = 4;
const VBE_DISPI_INDEX_BANK: u16 = 5;
const VBE_DISPI_INDEX_VIRT_WIDTH: u16 = 6;
const VBE_DISPI_INDEX_VIRT_HEIGHT: u16 = 7;
const VBE_DISPI_INDEX_X_OFFSET: u16 = 8;
const VBE_DISPI_INDEX_Y_OFFSET: u16 = 9;

const VBE_DISPI_DISABLED: u16 = 0x00;
const VBE_DISPI_ENABLED: u16 = 0x01;
const VBE_DISPI_LFB_ENABLED: u16 = 0x40;

const VBE_DISPI_ID0: u16 = 0xB0C0;
const VBE_DISPI_ID1: u16 = 0xB0C1;
const VBE_DISPI_ID2: u16 = 0xB0C2;
const VBE_DISPI_ID3: u16 = 0xB0C3;
const VBE_DISPI_ID4: u16 = 0xB0C4;
const VBE_DISPI_ID5: u16 = 0xB0C5;

// BGA framebuffer address - will be detected from PCI
var bga_lfb_address: u32 = 0xFD000000; // Default fallback

// PCI configuration space access
fn pciConfigRead32(bus: u8, slot: u8, func: u8, offset: u8) u32 {
    const address: u32 = (1 << 31) | // Enable bit
        (@as(u32, bus) << 16) |
        (@as(u32, slot) << 11) |
        (@as(u32, func) << 8) |
        (@as(u32, offset) & 0xFC);
    io.outl(0xCF8, address);
    return io.inl(0xCFC);
}

// Find VGA device and get framebuffer address from BAR0
fn detectFramebufferAddress() u32 {
    var bus: u8 = 0;
    while (bus < 8) : (bus += 1) {
        var slot: u8 = 0;
        while (slot < 32) : (slot += 1) {
            const vendor_device = pciConfigRead32(bus, slot, 0, 0);
            if (vendor_device == 0xFFFFFFFF) continue;

            // Check class code (offset 0x08, bits 24-31 = base class)
            const class_info = pciConfigRead32(bus, slot, 0, 0x08);
            const base_class = @as(u8, @truncate(class_info >> 24));
            const sub_class = @as(u8, @truncate(class_info >> 16));

            // VGA compatible controller: base class 0x03, sub class 0x00
            if (base_class == 0x03 and sub_class == 0x00) {
                // Read BAR0 (framebuffer address)
                const bar0 = pciConfigRead32(bus, slot, 0, 0x10);
                if ((bar0 & 1) == 0) { // Memory BAR
                    const fb_addr = bar0 & 0xFFFFFFF0;
                    if (fb_addr != 0) {
                        return fb_addr;
                    }
                }
            }
        }
    }
    return 0xFD000000;
}

fn bgaWriteRegister(index: u16, value: u16) void {
    io.outw(VBE_DISPI_IOPORT_INDEX, index);
    io.outw(VBE_DISPI_IOPORT_DATA, value);
}

fn bgaReadRegister(index: u16) u16 {
    io.outw(VBE_DISPI_IOPORT_INDEX, index);
    return io.inw(VBE_DISPI_IOPORT_DATA);
}

pub fn bgaAvailable() bool {
    const id = bgaReadRegister(VBE_DISPI_INDEX_ID);
    return id >= VBE_DISPI_ID0 and id <= VBE_DISPI_ID5;
}

pub fn bgaSetMode(width: u16, height: u16, bpp: u16) bool {
    serial.write("VBE: Setting BGA mode ");
    serial.writeInt(@as(u32, width));
    serial.write("x");
    serial.writeInt(@as(u32, height));
    serial.write("x");
    serial.writeInt(@as(u32, bpp));
    serial.write("\n");

    // Calculate framebuffer size
    const bytes_per_pixel: u32 = @as(u32, bpp) / 8;
    const fb_size: u32 = @as(u32, width) * @as(u32, height) * bytes_per_pixel;

    // Map framebuffer memory BEFORE enabling graphics mode
    serial.write("VBE: Mapping framebuffer (");
    serial.writeInt(fb_size / 1024);
    serial.write(" KB) at 0x");
    serial.writeHex(bga_lfb_address);
    serial.write("...\n");

    if (!paging.mapFramebuffer(bga_lfb_address, fb_size)) {
        serial.write("VBE: Failed to map framebuffer!\n");
        return false;
    }
    serial.write("VBE: Framebuffer mapped\n");

    // Disable VBE first
    bgaWriteRegister(VBE_DISPI_INDEX_ENABLE, VBE_DISPI_DISABLED);

    // Set resolution and color depth
    bgaWriteRegister(VBE_DISPI_INDEX_XRES, width);
    bgaWriteRegister(VBE_DISPI_INDEX_YRES, height);
    bgaWriteRegister(VBE_DISPI_INDEX_BPP, bpp);

    // Enable VBE with linear framebuffer
    bgaWriteRegister(VBE_DISPI_INDEX_ENABLE, VBE_DISPI_ENABLED | VBE_DISPI_LFB_ENABLED);

    // Setup framebuffer struct using detected address
    framebuffer.address = @ptrFromInt(bga_lfb_address);
    framebuffer.width = @as(u32, width);
    framebuffer.height = @as(u32, height);
    framebuffer.bpp = @truncate(bpp);
    framebuffer.bytes_per_pixel = @truncate(bytes_per_pixel);
    framebuffer.pitch = @as(u32, width) * framebuffer.bytes_per_pixel;
    framebuffer.size = fb_size;
    framebuffer.initialized = true;

    serial.write("VBE: Mode set successfully\n");
    serial.write("VBE: Framebuffer at 0x");
    serial.writeHex(bga_lfb_address);
    serial.write("\n");

    // Test write to framebuffer
    serial.write("VBE: Testing framebuffer write...\n");
    const fb_ptr: [*]volatile u32 = @ptrCast(@alignCast(framebuffer.address));
    fb_ptr[0] = 0x00FF0000; // Red pixel at top-left
    fb_ptr[1] = 0x0000FF00; // Green pixel
    fb_ptr[2] = 0x000000FF; // Blue pixel
    serial.write("VBE: Test write complete\n");

    return true;
}

pub fn init() bool {
    serial.write("VBE: Initializing graphics...\n");

    // Detect framebuffer address from PCI
    bga_lfb_address = detectFramebufferAddress();

    if (bgaAvailable()) {
        serial.write("VBE: BGA (Bochs Graphics Adapter) detected\n");
        // Set 800x600x32 mode (safe default, fits all screens)
        // Can be changed via Settings app
        return bgaSetMode(800, 600, 32);
    }

    serial.write("VBE: No compatible graphics adapter found\n");
    return false;
}

pub fn isInitialized() bool {
    return framebuffer.initialized;
}

pub fn getFramebuffer() ?*Framebuffer {
    if (!framebuffer.initialized) return null;
    return &framebuffer;
}

pub fn getWidth() u32 {
    return framebuffer.width;
}

pub fn getHeight() u32 {
    return framebuffer.height;
}

pub fn getBpp() u8 {
    return framebuffer.bpp;
}

// Available resolutions
pub const Resolution = struct {
    width: u16,
    height: u16,
    name: []const u8,
};

pub const resolutions = [_]Resolution{
    .{ .width = 640, .height = 480, .name = "640x480" },
    .{ .width = 800, .height = 600, .name = "800x600" },
    .{ .width = 1024, .height = 768, .name = "1024x768" },
    .{ .width = 1280, .height = 720, .name = "1280x720 (HD)" },
    .{ .width = 1280, .height = 800, .name = "1280x800" },
    .{ .width = 1366, .height = 768, .name = "1366x768" },
};

var current_resolution_idx: usize = 1; // Default 800x600

pub fn getResolutionCount() usize {
    return resolutions.len;
}

pub fn getResolution(idx: usize) ?Resolution {
    if (idx >= resolutions.len) return null;
    return resolutions[idx];
}

pub fn getCurrentResolutionIdx() usize {
    return current_resolution_idx;
}

/// Change resolution (returns true if successful)
pub fn setResolution(idx: usize) bool {
    if (idx >= resolutions.len) return false;

    const res = resolutions[idx];
    serial.write("VBE: Changing resolution to ");
    serial.write(res.name);
    serial.write("\n");

    if (bgaSetMode(res.width, res.height, 32)) {
        current_resolution_idx = idx;
        return true;
    }
    return false;
}

/// Restore VGA text mode (disable BGA graphics mode)
pub fn restoreTextMode() void {
    if (!framebuffer.initialized) return;

    serial.write("VBE: Restoring text mode...\n");

    // Disable BGA completely
    bgaWriteRegister(VBE_DISPI_INDEX_ENABLE, VBE_DISPI_DISABLED);

    // Small delay
    var i: u32 = 0;
    while (i < 100000) : (i += 1) {
        asm volatile ("nop");
    }

    // Reset VGA to mode 3 (80x25 text) using standard VGA registers
    // This sequence is based on standard VGA mode 3 initialization

    // Misc Output Register - enable color mode, enable RAM, select clock
    io.outb(0x3C2, 0x67);

    // Sequencer registers
    io.outb(0x3C4, 0x00);
    io.outb(0x3C5, 0x03); // Sequencer reset
    io.outb(0x3C4, 0x01);
    io.outb(0x3C5, 0x00); // Clocking mode - 9 dots/char
    io.outb(0x3C4, 0x02);
    io.outb(0x3C5, 0x03); // Map mask - enable planes 0,1
    io.outb(0x3C4, 0x03);
    io.outb(0x3C5, 0x00); // Character map select
    io.outb(0x3C4, 0x04);
    io.outb(0x3C5, 0x02); // Memory mode - odd/even

    // Unlock CRTC registers
    io.outb(0x3D4, 0x11);
    io.outb(0x3D5, io.inb(0x3D5) & 0x7F);

    // Graphics controller
    io.outb(0x3CE, 0x05);
    io.outb(0x3CF, 0x10); // Mode - odd/even
    io.outb(0x3CE, 0x06);
    io.outb(0x3CF, 0x0E); // Misc - text mode, A0000-BFFFF

    // Attribute controller - set palette
    _ = io.inb(0x3DA); // Reset flip-flop
    var attr: u8 = 0;
    while (attr < 16) : (attr += 1) {
        io.outb(0x3C0, attr);
        io.outb(0x3C0, attr);
    }
    io.outb(0x3C0, 0x10);
    io.outb(0x3C0, 0x0C); // Mode control
    io.outb(0x3C0, 0x20); // Enable video

    // Clear VGA text buffer at 0xB8000
    const vga_buffer: [*]volatile u16 = @ptrFromInt(0xB8000);
    const blank: u16 = 0x0720; // Space with light gray on black
    var j: usize = 0;
    while (j < 80 * 25) : (j += 1) {
        vga_buffer[j] = blank;
    }

    framebuffer.initialized = false;
    serial.write("VBE: Text mode restored\n");
}
