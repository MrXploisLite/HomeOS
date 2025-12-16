// Home OS - Physical Memory Manager (PMM)
// Copyright © 2025 Romy Rianata - Home OS

const serial = @import("../drivers/serial.zig");

pub const PAGE_SIZE: u32 = 4096;
pub const PAGE_SHIFT: u5 = 12;

const KERNEL_END: u32 = 0x400000;
const MEMORY_START: u32 = 0x400000;
const MEMORY_END: u32 = 0x10000000;

const MAX_PAGES: u32 = (MEMORY_END - MEMORY_START) / PAGE_SIZE;
const BITMAP_SIZE: u32 = MAX_PAGES / 32;

var bitmap: [BITMAP_SIZE]u32 = [_]u32{0} ** BITMAP_SIZE;
var total_pages: u32 = 0;
var free_pages: u32 = 0;
var used_pages: u32 = 0;
var alloc_count: u32 = 0;
var free_count: u32 = 0;

pub fn init() void {
    serial.write("PMM: Initializing physical memory manager...\n");
    for (&bitmap) |*entry| {
        entry.* = 0;
    }
    total_pages = MAX_PAGES;
    free_pages = MAX_PAGES;
    used_pages = 0;
    serial.write("PMM: Total pages: ");
    serial.writeInt(total_pages);
    serial.write(" (");
    serial.writeInt(total_pages * PAGE_SIZE / 1024 / 1024);
    serial.write(" MB)\n");
    serial.write("PMM: Ready\n");
}

pub fn initWithSize(mem_upper_kb: u32) void {
    serial.write("PMM: Initializing with detected memory...\n");
    const total_mem = (1024 + mem_upper_kb) * 1024;
    const usable_mem = if (total_mem > MEMORY_START) total_mem - MEMORY_START else 0;
    const actual_pages = usable_mem / PAGE_SIZE;
    total_pages = if (actual_pages > MAX_PAGES) MAX_PAGES else @truncate(actual_pages);

    for (&bitmap) |*entry| {
        entry.* = 0;
    }

    if (total_pages < MAX_PAGES) {
        var page = total_pages;
        while (page < MAX_PAGES) : (page += 1) {
            markUsed(page);
        }
    }
    free_pages = total_pages;
    used_pages = 0;
    serial.write("PMM: Usable pages: ");
    serial.writeInt(total_pages);
    serial.write(" (");
    serial.writeInt(total_pages * PAGE_SIZE / 1024 / 1024);
    serial.write(" MB)\n");
    serial.write("PMM: Ready\n");
}

pub fn allocPage() ?u32 {
    for (bitmap[0..BITMAP_SIZE], 0..) |entry, i| {
        if (entry != 0xFFFFFFFF) {
            var bit: u5 = 0;
            while (bit < 32) : (bit += 1) {
                if ((entry & (@as(u32, 1) << bit)) == 0) {
                    const page_index: u32 = @truncate(i * 32 + bit);
                    if (page_index >= total_pages) return null;
                    markUsed(page_index);
                    alloc_count += 1;
                    return MEMORY_START + (page_index * PAGE_SIZE);
                }
            }
        }
    }
    serial.write("PMM: Out of memory!\n");
    return null;
}

pub fn allocPages(count: u32) ?u32 {
    if (count == 0) return null;
    if (count == 1) return allocPage();

    var start_page: u32 = 0;
    while (start_page + count <= total_pages) {
        var found = true;
        var i: u32 = 0;
        while (i < count) : (i += 1) {
            if (isUsed(start_page + i)) {
                found = false;
                start_page = start_page + i + 1;
                break;
            }
        }
        if (found) {
            i = 0;
            while (i < count) : (i += 1) {
                markUsed(start_page + i);
            }
            alloc_count += count;
            return MEMORY_START + (start_page * PAGE_SIZE);
        }
    }
    serial.write("PMM: Cannot allocate ");
    serial.writeInt(count);
    serial.write(" contiguous pages\n");
    return null;
}

pub fn freePage(phys_addr: u32) void {
    if (phys_addr < MEMORY_START or phys_addr >= MEMORY_END) {
        serial.write("PMM: Invalid address to free: 0x");
        serial.writeHex(phys_addr);
        serial.write("\n");
        return;
    }
    const page_index = (phys_addr - MEMORY_START) / PAGE_SIZE;
    if (page_index >= total_pages) return;
    if (!isUsed(page_index)) {
        serial.write("PMM: Double free detected at 0x");
        serial.writeHex(phys_addr);
        serial.write("\n");
        return;
    }
    markFree(page_index);
    free_count += 1;
}

pub fn freePages(phys_addr: u32, count: u32) void {
    var i: u32 = 0;
    while (i < count) : (i += 1) {
        freePage(phys_addr + i * PAGE_SIZE);
    }
}

fn markUsed(page_index: u32) void {
    const idx = page_index / 32;
    const bit: u5 = @truncate(page_index % 32);
    bitmap[idx] |= (@as(u32, 1) << bit);
    if (free_pages > 0) free_pages -= 1;
    used_pages += 1;
}

fn markFree(page_index: u32) void {
    const idx = page_index / 32;
    const bit: u5 = @truncate(page_index % 32);
    bitmap[idx] &= ~(@as(u32, 1) << bit);
    free_pages += 1;
    if (used_pages > 0) used_pages -= 1;
}

fn isUsed(page_index: u32) bool {
    const idx = page_index / 32;
    const bit: u5 = @truncate(page_index % 32);
    return (bitmap[idx] & (@as(u32, 1) << bit)) != 0;
}

pub fn getTotalPages() u32 {
    return total_pages;
}
pub fn getFreePages() u32 {
    return free_pages;
}
pub fn getUsedPages() u32 {
    return used_pages;
}
pub fn getTotalMemory() u32 {
    return total_pages * PAGE_SIZE;
}
pub fn getFreeMemory() u32 {
    return free_pages * PAGE_SIZE;
}
pub fn getUsedMemory() u32 {
    return used_pages * PAGE_SIZE;
}
pub fn getAllocCount() u32 {
    return alloc_count;
}
pub fn getFreeCount() u32 {
    return free_count;
}
pub fn addrToPage(phys_addr: u32) u32 {
    return (phys_addr - MEMORY_START) / PAGE_SIZE;
}
pub fn pageToAddr(page_index: u32) u32 {
    return MEMORY_START + (page_index * PAGE_SIZE);
}
