// Home OS - MBR Partition Table Parser
// Copyright © 2025 Romy Rianata - Home OS

const serial = @import("../drivers/serial.zig");
const ata = @import("../drivers/ata.zig");

pub const PART_TYPE_EMPTY: u8 = 0x00;
pub const PART_TYPE_FAT12: u8 = 0x01;
pub const PART_TYPE_FAT16_SMALL: u8 = 0x04;
pub const PART_TYPE_EXTENDED: u8 = 0x05;
pub const PART_TYPE_FAT16: u8 = 0x06;
pub const PART_TYPE_NTFS: u8 = 0x07;
pub const PART_TYPE_FAT32: u8 = 0x0B;
pub const PART_TYPE_FAT32_LBA: u8 = 0x0C;
pub const PART_TYPE_FAT16_LBA: u8 = 0x0E;
pub const PART_TYPE_EXTENDED_LBA: u8 = 0x0F;
pub const PART_TYPE_LINUX: u8 = 0x83;
pub const PART_TYPE_LINUX_SWAP: u8 = 0x82;
pub const PART_TYPE_LINUX_LVM: u8 = 0x8E;

const MBR_SIGNATURE: u16 = 0xAA55;

pub const PartitionEntry = extern struct {
    boot_flag: u8,
    start_head: u8,
    start_sector: u8,
    start_cylinder: u8,
    system_id: u8,
    end_head: u8,
    end_sector: u8,
    end_cylinder: u8,
    lba_start: u32,
    sector_count: u32,

    pub fn isValid(self: *const PartitionEntry) bool {
        return self.system_id != PART_TYPE_EMPTY and self.sector_count > 0;
    }
    pub fn isBootable(self: *const PartitionEntry) bool {
        return self.boot_flag == 0x80;
    }
    pub fn isFAT32(self: *const PartitionEntry) bool {
        return self.system_id == PART_TYPE_FAT32 or self.system_id == PART_TYPE_FAT32_LBA;
    }
    pub fn isFAT16(self: *const PartitionEntry) bool {
        return self.system_id == PART_TYPE_FAT16 or self.system_id == PART_TYPE_FAT16_LBA or self.system_id == PART_TYPE_FAT16_SMALL;
    }
    pub fn isLinux(self: *const PartitionEntry) bool {
        return self.system_id == PART_TYPE_LINUX;
    }
    pub fn getSizeBytes(self: *const PartitionEntry) u64 {
        return @as(u64, self.sector_count) * ata.SECTOR_SIZE;
    }
    pub fn getSizeMB(self: *const PartitionEntry) u32 {
        return @truncate(self.getSizeBytes() / (1024 * 1024));
    }
};

pub const MBR = extern struct {
    bootstrap: [446]u8,
    partitions: [4]PartitionEntry,
    signature: u16,
    pub fn isValid(self: *const MBR) bool {
        return self.signature == MBR_SIGNATURE;
    }
};

var partitions: [4]PartitionEntry = undefined;
var partition_count: u8 = 0;
var mbr_valid: bool = false;

pub fn init() void {
    serial.write("MBR: Reading partition table...\n");
    if (!ata.hasDrive()) {
        serial.write("MBR: No drive present\n");
        return;
    }

    var buffer: [512]u8 = undefined;
    if (!ata.readSectors(0, 1, &buffer)) {
        serial.write("MBR: Failed to read sector 0\n");
        return;
    }

    const sig: u16 = @as(u16, buffer[510]) | (@as(u16, buffer[511]) << 8);
    serial.write("MBR: Signature = 0x");
    serial.writeHex(@as(u32, sig));
    serial.write("\n");

    if (sig != MBR_SIGNATURE) {
        serial.write("MBR: Invalid signature (expected 0xAA55)\n");
        return;
    }

    const part_offset: usize = 446;
    mbr_valid = true;
    serial.write("MBR: Valid signature found\n");

    partition_count = 0;
    var i: usize = 0;
    while (i < 4) : (i += 1) {
        const offset = part_offset + (i * 16);
        partitions[i].boot_flag = buffer[offset + 0];
        partitions[i].start_head = buffer[offset + 1];
        partitions[i].start_sector = buffer[offset + 2];
        partitions[i].start_cylinder = buffer[offset + 3];
        partitions[i].system_id = buffer[offset + 4];
        partitions[i].end_head = buffer[offset + 5];
        partitions[i].end_sector = buffer[offset + 6];
        partitions[i].end_cylinder = buffer[offset + 7];
        partitions[i].lba_start = @as(u32, buffer[offset + 8]) |
            (@as(u32, buffer[offset + 9]) << 8) |
            (@as(u32, buffer[offset + 10]) << 16) |
            (@as(u32, buffer[offset + 11]) << 24);
        partitions[i].sector_count = @as(u32, buffer[offset + 12]) |
            (@as(u32, buffer[offset + 13]) << 8) |
            (@as(u32, buffer[offset + 14]) << 16) |
            (@as(u32, buffer[offset + 15]) << 24);

        if (partitions[i].isValid()) {
            partition_count += 1;
            serial.write("MBR: Partition ");
            serial.writeInt(@truncate(i + 1));
            serial.write(": Type=0x");
            serial.writeHex(@as(u32, partitions[i].system_id));
            serial.write(", LBA=");
            serial.writeInt(partitions[i].lba_start);
            serial.write(", Size=");
            serial.writeInt(partitions[i].getSizeMB());
            serial.write(" MB");
            if (partitions[i].isBootable()) serial.write(" [BOOT]");
            serial.write("\n");
        }
    }
    serial.write("MBR: Found ");
    serial.writeInt(@as(u32, partition_count));
    serial.write(" partition(s)\n");
}

pub fn getPartition(index: u8) ?*const PartitionEntry {
    if (index >= 4) return null;
    if (!partitions[index].isValid()) return null;
    return &partitions[index];
}

pub fn getPartitionCount() u8 {
    return partition_count;
}
pub fn isValid() bool {
    return mbr_valid;
}

pub fn findFAT32() ?*const PartitionEntry {
    for (&partitions) |*part| {
        if (part.isValid() and part.isFAT32()) return part;
    }
    return null;
}

pub fn findLinux() ?*const PartitionEntry {
    for (&partitions) |*part| {
        if (part.isValid() and part.isLinux()) return part;
    }
    return null;
}

pub fn getTypeName(system_id: u8) []const u8 {
    return switch (system_id) {
        PART_TYPE_EMPTY => "Empty",
        PART_TYPE_FAT12 => "FAT12",
        PART_TYPE_FAT16_SMALL => "FAT16 (<32MB)",
        PART_TYPE_EXTENDED => "Extended",
        PART_TYPE_FAT16 => "FAT16",
        PART_TYPE_NTFS => "NTFS",
        PART_TYPE_FAT32 => "FAT32",
        PART_TYPE_FAT32_LBA => "FAT32 LBA",
        PART_TYPE_FAT16_LBA => "FAT16 LBA",
        PART_TYPE_EXTENDED_LBA => "Extended LBA",
        PART_TYPE_LINUX => "Linux",
        PART_TYPE_LINUX_SWAP => "Linux Swap",
        PART_TYPE_LINUX_LVM => "Linux LVM",
        else => "Unknown",
    };
}
