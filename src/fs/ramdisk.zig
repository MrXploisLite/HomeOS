// Home OS - Ramdisk Driver
// Copyright © 2025 Romy Rianata - Home OS
// Memory-backed storage device for filesystem

const heap = @import("../mm/heap.zig");
const serial = @import("../drivers/serial.zig");

/// Ramdisk structure - represents a block of memory used as storage
pub const Ramdisk = struct {
    base: usize, // Base address in memory
    size: usize, // Total size in bytes

    /// Initialize ramdisk by allocating memory
    /// size_kb: Size in kilobytes
    pub fn init(size_kb: usize) !Ramdisk {
        const size_bytes = size_kb * 1024;

        serial.write("Ramdisk: Allocating ");
        serial.writeInt(@truncate(size_kb));
        serial.write(" KB...\n");

        const mem = heap.alloc(@truncate(size_bytes));
        if (mem == null) {
            serial.write("Ramdisk: Allocation failed!\n");
            return error.OutOfMemory;
        }

        const base_addr = @intFromPtr(mem);

        serial.write("Ramdisk: Allocated at 0x");
        serial.writeHex(@truncate(base_addr));
        serial.write("\n");

        // Clear memory using fast REP STOSB
        const ptr: [*]u8 = @ptrFromInt(base_addr);
        asm volatile ("cld; rep stosb"
            :
            : [dest] "{edi}" (ptr),
              [val] "{al}" (@as(u8, 0)),
              [count] "{ecx}" (size_bytes),
            : .{ .edi = true, .ecx = true, .memory = true }
        );

        return Ramdisk{
            .base = base_addr,
            .size = size_bytes,
        };
    }

    /// Initialize ramdisk from existing data (e.g., embedded TAR)
    /// data: Pointer to existing data in memory
    pub fn initFromData(data: []const u8) !Ramdisk {
        if (data.len == 0) {
            return error.InvalidData;
        }

        return Ramdisk{
            .base = @intFromPtr(data.ptr),
            .size = data.len,
        };
    }

    /// Read a 512-byte sector from ramdisk
    /// sector: Sector number (0-based)
    /// buffer: Buffer to read into (must be at least 512 bytes)
    pub fn readSector(self: *const Ramdisk, sector: usize, buffer: []u8) !void {
        const offset = sector * 512;
        if (offset + 512 > self.size) {
            return error.OutOfBounds;
        }

        const src: [*]const u8 = @ptrFromInt(self.base + offset);
        @memcpy(buffer[0..512], src[0..512]);
    }

    /// Get direct pointer to data at offset
    /// offset: Byte offset from start of ramdisk
    /// Note: Caller must ensure offset is within bounds
    pub fn getPtr(self: *const Ramdisk, offset: usize) [*]const u8 {
        // Safety: clamp offset to prevent out-of-bounds access
        const safe_offset = if (offset >= self.size) self.size - 1 else offset;
        return @ptrFromInt(self.base + safe_offset);
    }

    /// Get mutable pointer to data at offset (for writing)
    /// offset: Byte offset from start of ramdisk
    /// Note: Caller must ensure offset is within bounds
    pub fn getMutPtr(self: *const Ramdisk, offset: usize) [*]u8 {
        // Safety: clamp offset to prevent out-of-bounds access
        const safe_offset = if (offset >= self.size) self.size - 1 else offset;
        return @ptrFromInt(self.base + safe_offset);
    }

    /// Write data to ramdisk
    /// offset: Byte offset from start
    /// data: Data to write
    pub fn write(self: *const Ramdisk, offset: usize, data: []const u8) !void {
        if (offset + data.len > self.size) {
            return error.OutOfBounds;
        }

        const dst: [*]u8 = @ptrFromInt(self.base + offset);
        @memcpy(dst[0..data.len], data);
    }

    /// Get ramdisk size
    pub fn getSize(self: *const Ramdisk) usize {
        return self.size;
    }
};
