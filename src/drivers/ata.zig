// Home OS - ATA/IDE Driver
// Copyright © 2025 Romy Rianata - Home OS
// Phase 11: Hard disk read/write support

const io = @import("../arch/io.zig");
const serial = @import("serial.zig");

// ATA I/O Ports (Primary Bus)
const ATA_PRIMARY_DATA: u16 = 0x1F0;
const ATA_PRIMARY_ERROR: u16 = 0x1F1;
const ATA_PRIMARY_FEATURES: u16 = 0x1F1;
const ATA_PRIMARY_SECCOUNT: u16 = 0x1F2;
const ATA_PRIMARY_LBA_LO: u16 = 0x1F3;
const ATA_PRIMARY_LBA_MID: u16 = 0x1F4;
const ATA_PRIMARY_LBA_HI: u16 = 0x1F5;
const ATA_PRIMARY_DRIVE: u16 = 0x1F6;
const ATA_PRIMARY_STATUS: u16 = 0x1F7;
const ATA_PRIMARY_COMMAND: u16 = 0x1F7;
const ATA_PRIMARY_CONTROL: u16 = 0x3F6;

// ATA Commands
const ATA_CMD_READ_PIO: u8 = 0x20;
const ATA_CMD_WRITE_PIO: u8 = 0x30;
const ATA_CMD_CACHE_FLUSH: u8 = 0xE7;
const ATA_CMD_IDENTIFY: u8 = 0xEC;

// ATA Status Register Bits
const ATA_SR_BSY: u8 = 0x80;
const ATA_SR_DRDY: u8 = 0x40;
const ATA_SR_DF: u8 = 0x20;
const ATA_SR_DRQ: u8 = 0x08;
const ATA_SR_ERR: u8 = 0x01;

// Drive selection
const ATA_MASTER: u8 = 0xA0;
const ATA_SLAVE: u8 = 0xB0;

pub const SECTOR_SIZE: u32 = 512;

pub const DriveInfo = struct {
    present: bool,
    is_ata: bool,
    is_atapi: bool,
    lba48: bool,
    sectors: u64,
    model: [41]u8,
    serial: [21]u8,
};

var primary_master: DriveInfo = .{
    .present = false,
    .is_ata = false,
    .is_atapi = false,
    .lba48 = false,
    .sectors = 0,
    .model = undefined,
    .serial = undefined,
};

var primary_slave: DriveInfo = .{
    .present = false,
    .is_ata = false,
    .is_atapi = false,
    .lba48 = false,
    .sectors = 0,
    .model = undefined,
    .serial = undefined,
};

var initialized: bool = false;

pub fn init() void {
    serial.write("ATA: Initializing...\n");
    serial.write("ATA: Detecting primary master...\n");
    detectDrive(true, true, &primary_master);
    serial.write("ATA: Detecting primary slave...\n");
    detectDrive(true, false, &primary_slave);
    initialized = true;

    if (primary_master.present) {
        serial.write("ATA: Primary Master: ");
        if (primary_master.is_ata) {
            serial.write("ATA ");
            serial.writeInt(@truncate(primary_master.sectors / 2048));
            serial.write(" MB\n");
        } else if (primary_master.is_atapi) {
            serial.write("ATAPI (CD-ROM)\n");
        }
    } else {
        serial.write("ATA: Primary Master: Not present\n");
    }

    if (primary_slave.present) {
        serial.write("ATA: Primary Slave: ");
        if (primary_slave.is_ata) {
            serial.write("ATA ");
            serial.writeInt(@truncate(primary_slave.sectors / 2048));
            serial.write(" MB\n");
        } else if (primary_slave.is_atapi) {
            serial.write("ATAPI (CD-ROM)\n");
        }
    } else {
        serial.write("ATA: Primary Slave: Not present\n");
    }
    serial.write("ATA: Ready\n");
}

fn detectDrive(primary: bool, master: bool, info: *DriveInfo) void {
    const base: u16 = if (primary) ATA_PRIMARY_DATA else 0x170;
    const drive_sel: u8 = if (master) ATA_MASTER else ATA_SLAVE;

    io.outb(base + 6, drive_sel);
    io.wait();
    io.outb(base + 2, 0);
    io.outb(base + 3, 0);
    io.outb(base + 4, 0);
    io.outb(base + 5, 0);
    io.outb(base + 7, ATA_CMD_IDENTIFY);
    io.wait();

    var status = io.inb(base + 7);
    if (status == 0) {
        info.present = false;
        return;
    }

    var timeout: u32 = 0;
    while ((status & ATA_SR_BSY) != 0) {
        status = io.inb(base + 7);
        timeout += 1;
        if (timeout > 100000) {
            info.present = false;
            return;
        }
    }

    const lba_mid = io.inb(base + 4);
    const lba_hi = io.inb(base + 5);

    if (lba_mid == 0x14 and lba_hi == 0xEB) {
        info.present = true;
        info.is_atapi = true;
        info.is_ata = false;
        return;
    } else if (lba_mid == 0x69 and lba_hi == 0x96) {
        info.present = true;
        info.is_atapi = true;
        info.is_ata = false;
        return;
    } else if (lba_mid != 0 or lba_hi != 0) {
        info.present = false;
        return;
    }

    timeout = 0;
    while (true) {
        status = io.inb(base + 7);
        if ((status & ATA_SR_ERR) != 0) {
            info.present = false;
            return;
        }
        if ((status & ATA_SR_DRQ) != 0) break;
        timeout += 1;
        if (timeout > 100000) {
            info.present = false;
            return;
        }
    }

    var identify_data: [256]u16 = undefined;
    for (&identify_data) |*word| {
        word.* = io.inw(base);
    }

    info.present = true;
    info.is_ata = true;
    info.is_atapi = false;
    info.lba48 = (identify_data[83] & (1 << 10)) != 0;

    if (info.lba48) {
        info.sectors = @as(u64, identify_data[100]) |
            (@as(u64, identify_data[101]) << 16) |
            (@as(u64, identify_data[102]) << 32) |
            (@as(u64, identify_data[103]) << 48);
    } else {
        info.sectors = @as(u64, identify_data[60]) |
            (@as(u64, identify_data[61]) << 16);
    }

    var i: usize = 0;
    while (i < 20) : (i += 1) {
        const word = identify_data[27 + i];
        info.model[i * 2] = @truncate(word >> 8);
        info.model[i * 2 + 1] = @truncate(word & 0xFF);
    }
    info.model[40] = 0;

    i = 0;
    while (i < 10) : (i += 1) {
        const word = identify_data[10 + i];
        info.serial[i * 2] = @truncate(word >> 8);
        info.serial[i * 2 + 1] = @truncate(word & 0xFF);
    }
    info.serial[20] = 0;
}

fn waitReady(base: u16) bool {
    var timeout: u32 = 0;
    while (timeout < 100000) : (timeout += 1) {
        const status = io.inb(base + 7);
        if ((status & ATA_SR_BSY) == 0) {
            if ((status & ATA_SR_ERR) != 0) return false;
            if ((status & ATA_SR_DF) != 0) return false;
            return true;
        }
    }
    return false;
}

fn waitDRQ(base: u16) bool {
    var timeout: u32 = 0;
    while (timeout < 100000) : (timeout += 1) {
        const status = io.inb(base + 7);
        if ((status & ATA_SR_BSY) == 0) {
            if ((status & ATA_SR_ERR) != 0) return false;
            if ((status & ATA_SR_DRQ) != 0) return true;
        }
    }
    return false;
}

pub fn readSectors(lba: u32, count: u8, buffer: [*]u8) bool {
    if (!primary_master.present or !primary_master.is_ata) {
        serial.write("ATA: No drive present\n");
        return false;
    }

    const base: u16 = ATA_PRIMARY_DATA;
    if (!waitReady(base)) {
        serial.write("ATA: Drive not ready\n");
        return false;
    }

    const lba_hi: u8 = @truncate((lba >> 24) & 0x0F);
    io.outb(base + 6, 0xE0 | lba_hi);
    io.wait();
    io.outb(base + 2, count);
    io.outb(base + 3, @truncate(lba & 0xFF));
    io.outb(base + 4, @truncate((lba >> 8) & 0xFF));
    io.outb(base + 5, @truncate((lba >> 16) & 0xFF));
    io.outb(base + 7, ATA_CMD_READ_PIO);

    var sector: u32 = 0;
    while (sector < count) : (sector += 1) {
        if (!waitDRQ(base)) {
            serial.write("ATA: Read timeout\n");
            return false;
        }
        const offset = sector * SECTOR_SIZE;
        var i: u32 = 0;
        while (i < 256) : (i += 1) {
            const word = io.inw(base);
            buffer[offset + i * 2] = @truncate(word & 0xFF);
            buffer[offset + i * 2 + 1] = @truncate(word >> 8);
        }
    }
    return true;
}

pub fn writeSectors(lba: u32, count: u8, buffer: [*]const u8) bool {
    if (!primary_master.present or !primary_master.is_ata) {
        serial.write("ATA: No drive present\n");
        return false;
    }

    const base: u16 = ATA_PRIMARY_DATA;
    if (!waitReady(base)) {
        serial.write("ATA: Drive not ready\n");
        return false;
    }

    const lba_hi: u8 = @truncate((lba >> 24) & 0x0F);
    io.outb(base + 6, 0xE0 | lba_hi);
    io.wait();
    io.outb(base + 2, count);
    io.outb(base + 3, @truncate(lba & 0xFF));
    io.outb(base + 4, @truncate((lba >> 8) & 0xFF));
    io.outb(base + 5, @truncate((lba >> 16) & 0xFF));
    io.outb(base + 7, ATA_CMD_WRITE_PIO);

    var sector: u32 = 0;
    while (sector < count) : (sector += 1) {
        if (!waitDRQ(base)) {
            serial.write("ATA: Write timeout\n");
            return false;
        }
        const offset = sector * SECTOR_SIZE;
        var i: u32 = 0;
        while (i < 256) : (i += 1) {
            const word: u16 = @as(u16, buffer[offset + i * 2]) |
                (@as(u16, buffer[offset + i * 2 + 1]) << 8);
            io.outw(base, word);
        }
    }

    io.outb(base + 7, ATA_CMD_CACHE_FLUSH);
    if (!waitReady(base)) {
        serial.write("ATA: Flush failed\n");
        return false;
    }
    return true;
}

pub fn getPrimaryMaster() *const DriveInfo {
    return &primary_master;
}

pub fn getPrimarySlave() *const DriveInfo {
    return &primary_slave;
}

pub fn hasDrive() bool {
    return primary_master.present or primary_slave.present;
}

pub fn getDiskSize() u64 {
    if (primary_master.present and primary_master.is_ata) {
        return primary_master.sectors * SECTOR_SIZE;
    }
    return 0;
}
