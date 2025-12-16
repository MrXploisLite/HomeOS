// Home OS - Simple Heap Allocator
// Copyright © 2025 Romy Rianata - Home OS

const paging = @import("paging.zig");

// Heap configuration
// Kernel starts at 1MB, code ~3MB, BSS has back_buffer ~8MB static array
// BSS can extend to ~12MB, so heap starts at 16MB to be safe
const HEAP_START: u32 = 0x1000000; // 16MB
const HEAP_SIZE: u32 = 0x1000000; // 16MB heap (16MB-32MB)
const HEAP_END: u32 = HEAP_START + HEAP_SIZE;

const BlockHeader = struct {
    size: u32,
    is_free: bool,
    next: ?*BlockHeader,
};

const HEADER_SIZE: u32 = @sizeOf(BlockHeader);

var free_list: ?*BlockHeader = null;
var heap_initialized: bool = false;

pub fn init() void {
    const first_block: *BlockHeader = @ptrFromInt(HEAP_START);
    first_block.size = HEAP_SIZE - HEADER_SIZE;
    first_block.is_free = true;
    first_block.next = null;
    free_list = first_block;
    heap_initialized = true;
}

pub fn isInitialized() bool {
    return heap_initialized;
}

pub fn alloc(size: u32) ?[*]u8 {
    if (!heap_initialized) return null;
    if (size == 0) return null;

    const aligned_size = (size + 3) & ~@as(u32, 3);
    var current = free_list;
    var prev: ?*BlockHeader = null;

    while (current) |block| {
        if (block.is_free and block.size >= aligned_size) {
            const remaining = block.size - aligned_size;
            if (remaining > HEADER_SIZE + 16) {
                const new_block_addr = @intFromPtr(block) + HEADER_SIZE + aligned_size;
                const new_block: *BlockHeader = @ptrFromInt(new_block_addr);
                new_block.size = remaining - HEADER_SIZE;
                new_block.is_free = true;
                new_block.next = block.next;
                block.size = aligned_size;
                block.next = new_block;
            }
            block.is_free = false;
            const data_addr = @intFromPtr(block) + HEADER_SIZE;
            return @ptrFromInt(data_addr);
        }
        prev = block;
        current = block.next;
    }
    return null;
}

pub fn free(ptr: ?[*]u8) void {
    if (ptr == null) return;
    const data_addr = @intFromPtr(ptr);
    const header_addr = data_addr - HEADER_SIZE;
    const block: *BlockHeader = @ptrFromInt(header_addr);
    block.is_free = true;

    if (block.next) |next_block| {
        if (next_block.is_free) {
            block.size += HEADER_SIZE + next_block.size;
            block.next = next_block.next;
        }
    }

    var prev: ?*BlockHeader = null;
    var current = free_list;
    while (current) |curr| {
        if (curr == block) break;
        prev = curr;
        current = curr.next;
    }

    if (prev) |prev_block| {
        if (prev_block.is_free) {
            prev_block.size += HEADER_SIZE + block.size;
            prev_block.next = block.next;
        }
    }
}

pub fn getFreeMemory() u32 {
    if (!heap_initialized) return 0;
    var total: u32 = 0;
    var current = free_list;
    while (current) |block| {
        if (block.is_free) {
            total += block.size;
        }
        current = block.next;
    }
    return total;
}

pub fn getUsedMemory() u32 {
    if (!heap_initialized) return 0;
    return HEAP_SIZE - HEADER_SIZE - getFreeMemory();
}

pub fn getTotalSize() u32 {
    return HEAP_SIZE;
}
