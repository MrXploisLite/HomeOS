// Home OS - FAT32 Filesystem Driver
// Copyright © 2025 Romy Rianata - Home OS

const serial = @import("../drivers/serial.zig");
const ata = @import("../drivers/ata.zig");
const heap = @import("../mm/heap.zig");

pub const FAT32BootSector = extern struct {
    jump_boot: [3]u8,
    oem_name: [8]u8,
    bytes_per_sector: u16,
    sectors_per_cluster: u8,
    reserved_sectors: u16,
    num_fats: u8,
    root_entry_count: u16,
    total_sectors_16: u16,
    media_type: u8,
    fat_size_16: u16,
    sectors_per_track: u16,
    num_heads: u16,
    hidden_sectors: u32,
    total_sectors_32: u32,
    fat_size_32: u32,
    ext_flags: u16,
    fs_version: u16,
    root_cluster: u32,
    fs_info: u16,
    backup_boot: u16,
    reserved: [12]u8,
    drive_number: u8,
    reserved1: u8,
    boot_sig: u8,
    volume_id: u32,
    volume_label: [11]u8,
    fs_type: [8]u8,
};

pub const DirEntry = extern struct {
    name: [11]u8,
    attr: u8,
    nt_reserved: u8,
    create_time_tenth: u8,
    create_time: u16,
    create_date: u16,
    access_date: u16,
    cluster_hi: u16,
    modify_time: u16,
    modify_date: u16,
    cluster_lo: u16,
    file_size: u32,

    pub fn getCluster(self: *const DirEntry) u32 {
        return (@as(u32, self.cluster_hi) << 16) | @as(u32, self.cluster_lo);
    }
    pub fn isDirectory(self: *const DirEntry) bool {
        return (self.attr & ATTR_DIRECTORY) != 0;
    }
    pub fn isFile(self: *const DirEntry) bool {
        return (self.attr & (ATTR_DIRECTORY | ATTR_VOLUME_ID)) == 0;
    }
    pub fn isLongName(self: *const DirEntry) bool {
        return (self.attr & ATTR_LONG_NAME_MASK) == ATTR_LONG_NAME;
    }
    pub fn isEmpty(self: *const DirEntry) bool {
        return self.name[0] == 0x00;
    }
    pub fn isDeleted(self: *const DirEntry) bool {
        return self.name[0] == 0xE5;
    }
};

pub const ATTR_READ_ONLY: u8 = 0x01;
pub const ATTR_HIDDEN: u8 = 0x02;
pub const ATTR_SYSTEM: u8 = 0x04;
pub const ATTR_VOLUME_ID: u8 = 0x08;
pub const ATTR_DIRECTORY: u8 = 0x10;
pub const ATTR_ARCHIVE: u8 = 0x20;
pub const ATTR_LONG_NAME: u8 = 0x0F;
pub const ATTR_LONG_NAME_MASK: u8 = 0x3F;

pub const FAT32_EOC: u32 = 0x0FFFFFF8;
pub const FAT32_BAD: u32 = 0x0FFFFFF7;
pub const FAT32_FREE: u32 = 0x00000000;

pub const FAT32 = struct {
    bytes_per_sector: u32,
    sectors_per_cluster: u32,
    reserved_sectors: u32,
    num_fats: u32,
    fat_size: u32,
    root_cluster: u32,
    total_sectors: u32,
    fat_start_sector: u32,
    data_start_sector: u32,
    cluster_size: u32,
    partition_start: u32,
    initialized: bool,

    const Self = @This();

    pub fn init(partition_start_lba: u32) ?FAT32 {
        serial.write("FAT32: Initializing from LBA ");
        serial.writeInt(partition_start_lba);
        serial.write("...\n");

        var buffer: [512]u8 = undefined;
        if (!ata.readSectors(partition_start_lba, 1, &buffer)) {
            serial.write("FAT32: Failed to read boot sector\n");
            return null;
        }

        const bytes_per_sector: u16 = @as(u16, buffer[11]) | (@as(u16, buffer[12]) << 8);
        if (bytes_per_sector != 512) {
            serial.write("FAT32: Invalid bytes per sector\n");
            return null;
        }

        const sectors_per_cluster: u8 = buffer[13];
        const reserved_sectors: u16 = @as(u16, buffer[14]) | (@as(u16, buffer[15]) << 8);
        const num_fats: u8 = buffer[16];
        const root_entry_count: u16 = @as(u16, buffer[17]) | (@as(u16, buffer[18]) << 8);
        if (root_entry_count != 0) {
            serial.write("FAT32: Not FAT32 (root_entry_count != 0)\n");
            return null;
        }

        const total_sectors: u32 = @as(u32, buffer[32]) | (@as(u32, buffer[33]) << 8) |
            (@as(u32, buffer[34]) << 16) | (@as(u32, buffer[35]) << 24);
        const fat_size: u32 = @as(u32, buffer[36]) | (@as(u32, buffer[37]) << 8) |
            (@as(u32, buffer[38]) << 16) | (@as(u32, buffer[39]) << 24);
        const root_cluster: u32 = @as(u32, buffer[44]) | (@as(u32, buffer[45]) << 8) |
            (@as(u32, buffer[46]) << 16) | (@as(u32, buffer[47]) << 24);
        const boot_sig: u8 = buffer[66];
        if (boot_sig != 0x29) {
            serial.write("FAT32: Invalid boot signature\n");
            return null;
        }

        var fs = FAT32{
            .bytes_per_sector = bytes_per_sector,
            .sectors_per_cluster = sectors_per_cluster,
            .reserved_sectors = reserved_sectors,
            .num_fats = num_fats,
            .fat_size = fat_size,
            .root_cluster = root_cluster,
            .total_sectors = total_sectors,
            .fat_start_sector = 0,
            .data_start_sector = 0,
            .cluster_size = 0,
            .partition_start = partition_start_lba,
            .initialized = false,
        };

        fs.fat_start_sector = partition_start_lba + fs.reserved_sectors;
        fs.data_start_sector = fs.fat_start_sector + (fs.num_fats * fs.fat_size);
        fs.cluster_size = fs.sectors_per_cluster * fs.bytes_per_sector;
        fs.initialized = true;

        serial.write("FAT32: Initialized successfully\n");
        return fs;
    }

    pub fn clusterToLBA(self: *const Self, cluster: u32) u32 {
        return self.data_start_sector + (cluster - 2) * self.sectors_per_cluster;
    }

    pub fn readCluster(self: *const Self, cluster: u32, buffer: [*]u8) bool {
        const lba = self.clusterToLBA(cluster);
        return ata.readSectors(lba, @truncate(self.sectors_per_cluster), buffer);
    }

    pub fn writeCluster(self: *const Self, cluster: u32, buffer: [*]const u8) bool {
        const lba = self.clusterToLBA(cluster);
        return ata.writeSectors(lba, @truncate(self.sectors_per_cluster), buffer);
    }

    pub fn readFATEntry(self: *const Self, cluster: u32) ?u32 {
        const fat_offset = cluster * 4;
        const fat_sector = self.fat_start_sector + (fat_offset / 512);
        const entry_offset = fat_offset % 512;
        var buffer: [512]u8 align(4) = undefined;
        if (!ata.readSectors(fat_sector, 1, &buffer)) return null;
        const entry_ptr: *const u32 = @ptrCast(@alignCast(&buffer[entry_offset]));
        return entry_ptr.* & 0x0FFFFFFF;
    }

    /// Write FAT entry (updates all FAT copies)
    pub fn writeFATEntry(self: *Self, cluster: u32, value: u32) bool {
        const fat_offset = cluster * 4;
        const sector_offset = fat_offset / 512;
        const entry_offset = fat_offset % 512;

        var buffer: [512]u8 align(4) = undefined;

        // Update all FAT copies
        var fat_num: u32 = 0;
        while (fat_num < self.num_fats) : (fat_num += 1) {
            const fat_sector = self.fat_start_sector + (fat_num * self.fat_size) + sector_offset;

            // Read sector
            if (!ata.readSectors(fat_sector, 1, &buffer)) {
                serial.write("FAT32: Failed to read FAT sector\n");
                return false;
            }

            // Modify entry (preserve high 4 bits)
            const entry_ptr: *u32 = @ptrCast(@alignCast(&buffer[entry_offset]));
            entry_ptr.* = (entry_ptr.* & 0xF0000000) | (value & 0x0FFFFFFF);

            // Write back
            if (!ata.writeSectors(fat_sector, 1, &buffer)) {
                serial.write("FAT32: Failed to write FAT sector\n");
                return false;
            }
        }
        return true;
    }

    /// Allocate a free cluster
    pub fn allocateCluster(self: *Self) ?u32 {
        // Start searching from cluster 2 (first data cluster)
        const total_clusters = (self.total_sectors - self.data_start_sector + self.partition_start) / self.sectors_per_cluster;

        var cluster: u32 = 2;
        while (cluster < total_clusters + 2) : (cluster += 1) {
            const entry = self.readFATEntry(cluster) orelse continue;
            if (entry == FAT32_FREE) {
                // Mark as end of chain
                if (self.writeFATEntry(cluster, FAT32_EOC)) {
                    return cluster;
                }
                return null;
            }
        }
        serial.write("FAT32: No free clusters\n");
        return null;
    }

    /// Allocate a chain of clusters
    pub fn allocateClusterChain(self: *Self, count: u32) ?u32 {
        if (count == 0) return null;

        var first_cluster: ?u32 = null;
        var prev_cluster: u32 = 0;
        var allocated: u32 = 0;

        const total_clusters = (self.total_sectors - self.data_start_sector + self.partition_start) / self.sectors_per_cluster;
        var cluster: u32 = 2;

        while (cluster < total_clusters + 2 and allocated < count) : (cluster += 1) {
            const entry = self.readFATEntry(cluster) orelse continue;
            if (entry == FAT32_FREE) {
                if (first_cluster == null) {
                    first_cluster = cluster;
                } else {
                    // Link previous cluster to this one
                    if (!self.writeFATEntry(prev_cluster, cluster)) {
                        // Rollback on failure
                        if (first_cluster) |fc| self.freeClusterChain(fc);
                        return null;
                    }
                }
                prev_cluster = cluster;
                allocated += 1;
            }
        }

        if (allocated < count) {
            // Not enough space, rollback
            if (first_cluster) |fc| self.freeClusterChain(fc);
            serial.write("FAT32: Not enough free clusters\n");
            return null;
        }

        // Mark last cluster as EOC
        if (!self.writeFATEntry(prev_cluster, FAT32_EOC)) {
            if (first_cluster) |fc| self.freeClusterChain(fc);
            return null;
        }

        return first_cluster;
    }

    /// Free a cluster chain
    pub fn freeClusterChain(self: *Self, start_cluster: u32) void {
        var cluster = start_cluster;
        while (cluster >= 2 and cluster < FAT32_EOC) {
            const next = self.readFATEntry(cluster) orelse break;
            _ = self.writeFATEntry(cluster, FAT32_FREE);
            if (next >= FAT32_EOC) break;
            cluster = next;
        }
    }

    pub fn isEndOfChain(self: *const Self, cluster: u32) bool {
        _ = self;
        return cluster >= FAT32_EOC;
    }

    pub fn listRoot(self: *const Self, callback: *const fn (*const DirEntry) void) void {
        self.listDirectory(self.root_cluster, callback);
    }

    pub fn listDirectory(self: *const Self, start_cluster: u32, callback: *const fn (*const DirEntry) void) void {
        var cluster = start_cluster;
        var buffer: [4096]u8 align(4) = undefined;

        while (!self.isEndOfChain(cluster)) {
            if (!self.readCluster(cluster, &buffer)) {
                serial.write("FAT32: Failed to read cluster\n");
                return;
            }
            const entries_per_cluster = self.cluster_size / 32;
            var i: u32 = 0;
            while (i < entries_per_cluster) : (i += 1) {
                const entry: *const DirEntry = @ptrCast(@alignCast(&buffer[i * 32]));
                if (entry.isEmpty()) return;
                if (!entry.isDeleted() and !entry.isLongName()) callback(entry);
            }
            const next = self.readFATEntry(cluster) orelse return;
            cluster = next;
        }
    }

    pub fn findFile(self: *const Self, dir_cluster: u32, name: []const u8) ?DirEntry {
        var cluster = dir_cluster;
        var buffer: [4096]u8 align(4) = undefined;
        var search_name: [11]u8 = undefined;
        formatName83(name, &search_name);

        while (!self.isEndOfChain(cluster)) {
            if (!self.readCluster(cluster, &buffer)) return null;
            const entries_per_cluster = self.cluster_size / 32;
            var i: u32 = 0;
            while (i < entries_per_cluster) : (i += 1) {
                const entry: *const DirEntry = @ptrCast(@alignCast(&buffer[i * 32]));
                if (entry.isEmpty()) return null;
                if (!entry.isDeleted() and !entry.isLongName()) {
                    if (nameMatch(&entry.name, &search_name)) return entry.*;
                }
            }
            const next = self.readFATEntry(cluster) orelse return null;
            cluster = next;
        }
        return null;
    }

    pub fn readFile(self: *const Self, entry: *const DirEntry, buffer: [*]u8, max_size: u32) u32 {
        var cluster = entry.getCluster();
        var bytes_read: u32 = 0;
        var remaining = if (entry.file_size < max_size) entry.file_size else max_size;

        while (!self.isEndOfChain(cluster) and remaining > 0) {
            var cluster_buf: [4096]u8 align(4) = undefined;
            if (!self.readCluster(cluster, &cluster_buf)) break;
            const to_copy = if (remaining < self.cluster_size) remaining else self.cluster_size;
            var i: u32 = 0;
            while (i < to_copy) : (i += 1) {
                buffer[bytes_read + i] = cluster_buf[i];
            }
            bytes_read += to_copy;
            remaining -= to_copy;
            const next = self.readFATEntry(cluster) orelse break;
            cluster = next;
        }
        return bytes_read;
    }

    /// Find a free directory entry in a directory
    fn findFreeDirEntry(self: *Self, dir_cluster: u32) ?struct { cluster: u32, index: u32 } {
        var cluster = dir_cluster;
        var buffer: [4096]u8 align(4) = undefined;

        while (!self.isEndOfChain(cluster)) {
            if (!self.readCluster(cluster, &buffer)) return null;
            const entries_per_cluster = self.cluster_size / 32;
            var i: u32 = 0;
            while (i < entries_per_cluster) : (i += 1) {
                const entry: *const DirEntry = @ptrCast(@alignCast(&buffer[i * 32]));
                if (entry.isEmpty() or entry.isDeleted()) {
                    return .{ .cluster = cluster, .index = i };
                }
            }
            const next = self.readFATEntry(cluster) orelse break;
            if (self.isEndOfChain(next)) {
                // Need to allocate new cluster for directory
                const new_cluster = self.allocateCluster() orelse return null;
                if (!self.writeFATEntry(cluster, new_cluster)) {
                    _ = self.writeFATEntry(new_cluster, FAT32_FREE);
                    return null;
                }
                // Clear new cluster
                var empty: [4096]u8 = [_]u8{0} ** 4096;
                if (!self.writeCluster(new_cluster, &empty)) return null;
                return .{ .cluster = new_cluster, .index = 0 };
            }
            cluster = next;
        }
        return null;
    }

    /// Create a new file in directory
    pub fn createFile(self: *Self, dir_cluster: u32, name: []const u8) ?DirEntry {
        // Check if file already exists
        if (self.findFile(dir_cluster, name) != null) {
            serial.write("FAT32: File already exists\n");
            return null;
        }

        // Find free directory entry
        const slot = self.findFreeDirEntry(dir_cluster) orelse {
            serial.write("FAT32: No free directory entry\n");
            return null;
        };

        // Read the cluster containing the directory entry
        var buffer: [4096]u8 align(4) = undefined;
        if (!self.readCluster(slot.cluster, &buffer)) return null;

        // Create directory entry
        const entry: *DirEntry = @ptrCast(@alignCast(&buffer[slot.index * 32]));
        formatName83(name, &entry.name);
        entry.attr = ATTR_ARCHIVE;
        entry.nt_reserved = 0;
        entry.create_time_tenth = 0;
        entry.create_time = 0;
        entry.create_date = 0;
        entry.access_date = 0;
        entry.cluster_hi = 0;
        entry.modify_time = 0;
        entry.modify_date = 0;
        entry.cluster_lo = 0;
        entry.file_size = 0;

        // Write back
        if (!self.writeCluster(slot.cluster, &buffer)) return null;

        serial.write("FAT32: Created file: ");
        serial.write(name);
        serial.write("\n");

        return entry.*;
    }

    /// Write data to a file (overwrites existing content)
    pub fn writeFile(self: *Self, dir_cluster: u32, name: []const u8, data: []const u8) bool {
        // Find or create file
        var entry = self.findFile(dir_cluster, name);
        var entry_cluster: u32 = 0;
        var entry_index: u32 = 0;

        if (entry == null) {
            // Create new file
            const new_entry = self.createFile(dir_cluster, name) orelse return false;
            entry = new_entry;
        }

        // Find the directory entry location
        var cluster = dir_cluster;
        var buffer: [4096]u8 align(4) = undefined;
        var search_name: [11]u8 = undefined;
        formatName83(name, &search_name);

        outer: while (!self.isEndOfChain(cluster)) {
            if (!self.readCluster(cluster, &buffer)) return false;
            const entries_per_cluster = self.cluster_size / 32;
            var i: u32 = 0;
            while (i < entries_per_cluster) : (i += 1) {
                const dir_entry: *const DirEntry = @ptrCast(@alignCast(&buffer[i * 32]));
                if (!dir_entry.isDeleted() and !dir_entry.isLongName()) {
                    if (nameMatch(&dir_entry.name, &search_name)) {
                        entry_cluster = cluster;
                        entry_index = i;
                        break :outer;
                    }
                }
            }
            const next = self.readFATEntry(cluster) orelse return false;
            cluster = next;
        }

        if (entry_cluster == 0) return false;

        // Free old cluster chain if exists
        const old_cluster = entry.?.getCluster();
        if (old_cluster >= 2 and old_cluster < FAT32_EOC) {
            self.freeClusterChain(old_cluster);
        }

        // Calculate clusters needed
        const clusters_needed = if (data.len == 0) 0 else (data.len + self.cluster_size - 1) / self.cluster_size;

        var first_cluster: u32 = 0;
        if (clusters_needed > 0) {
            // Allocate new cluster chain
            first_cluster = self.allocateClusterChain(@truncate(clusters_needed)) orelse return false;

            // Write data to clusters
            var data_cluster = first_cluster;
            var data_offset: usize = 0;

            while (data_offset < data.len) {
                var cluster_buf: [4096]u8 = [_]u8{0} ** 4096;
                const to_write = @min(self.cluster_size, data.len - data_offset);

                var j: usize = 0;
                while (j < to_write) : (j += 1) {
                    cluster_buf[j] = data[data_offset + j];
                }

                if (!self.writeCluster(data_cluster, &cluster_buf)) {
                    self.freeClusterChain(first_cluster);
                    return false;
                }

                data_offset += to_write;
                if (data_offset < data.len) {
                    const next = self.readFATEntry(data_cluster) orelse break;
                    data_cluster = next;
                }
            }
        }

        // Update directory entry
        if (!self.readCluster(entry_cluster, &buffer)) return false;
        const dir_entry: *DirEntry = @ptrCast(@alignCast(&buffer[entry_index * 32]));
        dir_entry.cluster_hi = @truncate(first_cluster >> 16);
        dir_entry.cluster_lo = @truncate(first_cluster & 0xFFFF);
        dir_entry.file_size = @truncate(data.len);
        dir_entry.attr |= ATTR_ARCHIVE;

        if (!self.writeCluster(entry_cluster, &buffer)) return false;

        serial.write("FAT32: Wrote ");
        serial.writeInt(@truncate(data.len));
        serial.write(" bytes to ");
        serial.write(name);
        serial.write("\n");

        return true;
    }

    /// Delete a file
    pub fn deleteFile(self: *Self, dir_cluster: u32, name: []const u8) bool {
        var cluster = dir_cluster;
        var buffer: [4096]u8 align(4) = undefined;
        var search_name: [11]u8 = undefined;
        formatName83(name, &search_name);

        while (!self.isEndOfChain(cluster)) {
            if (!self.readCluster(cluster, &buffer)) return false;
            const entries_per_cluster = self.cluster_size / 32;
            var i: u32 = 0;
            while (i < entries_per_cluster) : (i += 1) {
                const entry: *DirEntry = @ptrCast(@alignCast(&buffer[i * 32]));
                if (entry.isEmpty()) return false;
                if (!entry.isDeleted() and !entry.isLongName()) {
                    if (nameMatch(&entry.name, &search_name)) {
                        // Free cluster chain
                        const file_cluster = entry.getCluster();
                        if (file_cluster >= 2 and file_cluster < FAT32_EOC) {
                            self.freeClusterChain(file_cluster);
                        }
                        // Mark entry as deleted
                        entry.name[0] = 0xE5;
                        if (!self.writeCluster(cluster, &buffer)) return false;

                        serial.write("FAT32: Deleted ");
                        serial.write(name);
                        serial.write("\n");
                        return true;
                    }
                }
            }
            const next = self.readFATEntry(cluster) orelse return false;
            cluster = next;
        }
        return false;
    }
};

fn formatName83(name: []const u8, out: *[11]u8) void {
    for (out) |*c| {
        c.* = ' ';
    }
    var i: usize = 0;
    var out_idx: usize = 0;
    var in_ext = false;
    while (i < name.len and out_idx < 11) : (i += 1) {
        const c = name[i];
        if (c == '.') {
            in_ext = true;
            out_idx = 8;
            continue;
        }
        const upper = if (c >= 'a' and c <= 'z') c - 32 else c;
        if (in_ext) {
            if (out_idx < 11) {
                out[out_idx] = upper;
                out_idx += 1;
            }
        } else {
            if (out_idx < 8) {
                out[out_idx] = upper;
                out_idx += 1;
            }
        }
    }
}

fn nameMatch(a: *const [11]u8, b: *const [11]u8) bool {
    for (a, b) |ca, cb| {
        if (ca != cb) return false;
    }
    return true;
}

pub fn getName83(entry: *const DirEntry, out: []u8) usize {
    var len: usize = 0;
    var name_len: usize = 8;
    while (name_len > 0 and entry.name[name_len - 1] == ' ') name_len -= 1;
    var i: usize = 0;
    while (i < name_len and len < out.len) : (i += 1) {
        out[len] = entry.name[i];
        len += 1;
    }
    var ext_len: usize = 3;
    while (ext_len > 0 and entry.name[8 + ext_len - 1] == ' ') ext_len -= 1;
    if (ext_len > 0 and len < out.len) {
        out[len] = '.';
        len += 1;
        i = 0;
        while (i < ext_len and len < out.len) : (i += 1) {
            out[len] = entry.name[8 + i];
            len += 1;
        }
    }
    return len;
}

var fat32_fs: ?FAT32 = null;

pub fn initFS() bool {
    const mbr = @import("mbr.zig");
    const part = mbr.findFAT32();
    if (part == null) {
        serial.write("FAT32: No FAT32 partition found\n");
        return false;
    }
    fat32_fs = FAT32.init(part.?.lba_start);
    return fat32_fs != null;
}

pub fn getFS() ?*FAT32 {
    if (fat32_fs) |*fs| return fs;
    return null;
}

pub fn isInitialized() bool {
    return fat32_fs != null and fat32_fs.?.initialized;
}
