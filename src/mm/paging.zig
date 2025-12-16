// Home OS - Paging / Virtual Memory
// Copyright © 2025 Romy Rianata - Home OS
// Maps full 4GB address space using 4MB pages (PSE)

const serial = @import("../drivers/serial.zig");

pub const PAGE_SIZE: u32 = 4096;
pub const PAGE_SIZE_4MB: u32 = 4 * 1024 * 1024; // 4MB

pub const PAGE_PRESENT: u32 = 1 << 0;
pub const PAGE_WRITABLE: u32 = 1 << 1;
pub const PAGE_USER: u32 = 1 << 2;
pub const PAGE_WRITE_THROUGH: u32 = 1 << 3;
pub const PAGE_CACHE_DISABLE: u32 = 1 << 4;
pub const PAGE_ACCESSED: u32 = 1 << 5;
pub const PAGE_DIRTY: u32 = 1 << 6;
pub const PAGE_SIZE_BIT: u32 = 1 << 7; // For 4MB pages
pub const PAGE_GLOBAL: u32 = 1 << 8;

var page_directory: [1024]u32 align(PAGE_SIZE) = [_]u32{0} ** 1024;

pub fn init() void {
    // Enable PSE (Page Size Extension) in CR4 for 4MB pages
    enablePSE();

    // Identity map entire 4GB address space using 4MB pages
    // Each page directory entry maps 4MB when PAGE_SIZE_BIT is set
    // 1024 entries * 4MB = 4GB
    var i: u32 = 0;
    while (i < 1024) : (i += 1) {
        // Physical address = i * 4MB
        const phys_addr = i * PAGE_SIZE_4MB;
        // Use 4MB pages with present, writable, user flags
        page_directory[i] = phys_addr | PAGE_PRESENT | PAGE_WRITABLE | PAGE_USER | PAGE_SIZE_BIT;
    }

    loadPageDirectory(@intFromPtr(&page_directory));
    enablePaging();

    serial.write("Paging: Mapped 4GB using 4MB pages (PSE)\n");
}

fn enablePSE() void {
    // Set PSE bit (bit 4) in CR4
    asm volatile (
        \\mov %%cr4, %%eax
        \\or $0x10, %%eax
        \\mov %%eax, %%cr4
        ::: .{ .eax = true });
}

fn loadPageDirectory(addr: u32) void {
    asm volatile ("mov %[addr], %%cr3"
        :
        : [addr] "r" (addr),
    );
}

fn enablePaging() void {
    asm volatile (
        \\mov %%cr0, %%eax
        \\or $0x80000000, %%eax
        \\mov %%eax, %%cr0
        ::: .{ .eax = true });
}

// With 4MB pages, virtual = physical (identity mapped)
pub fn getPhysicalAddress(virtual: u32) ?u32 {
    const pd_index = virtual >> 22;
    const pd_entry = page_directory[pd_index];
    if ((pd_entry & PAGE_PRESENT) == 0) return null;
    // With 4MB pages, physical address is directly from PD entry
    return virtual; // Identity mapped
}

// Not needed with 4MB pages covering all memory, but keep for compatibility
pub fn mapPage(virtual: u32, physical: u32, flags: u32) void {
    _ = virtual;
    _ = physical;
    _ = flags;
    // No-op: all memory already identity mapped with 4MB pages
}

fn invalidatePage(addr: u32) void {
    asm volatile ("invlpg (%[addr])"
        :
        : [addr] "r" (addr),
    );
}

pub fn isPagingEnabled() bool {
    var cr0: u32 = undefined;
    asm volatile ("mov %%cr0, %[cr0]"
        : [cr0] "=r" (cr0),
    );
    return (cr0 & 0x80000000) != 0;
}

// Map framebuffer for graphics (no-op since we map all 4GB at init)
pub fn mapFramebuffer(fb_addr: u32, fb_size: u32) bool {
    _ = fb_addr;
    _ = fb_size;
    // Already mapped via 4MB pages at init
    return true;
}
