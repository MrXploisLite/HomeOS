// Home OS - ELF Loader
// Copyright © 2025 Romy Rianata - Home OS
// Placeholder for ELF binary loading

const serial = @import("../drivers/serial.zig");

pub const ElfHeader = extern struct {
    magic: [4]u8,
    class: u8,
    data: u8,
    version: u8,
    osabi: u8,
    abiversion: u8,
    pad: [7]u8,
    elf_type: u16,
    machine: u16,
    elf_version: u32,
    entry: u32,
    phoff: u32,
    shoff: u32,
    flags: u32,
    ehsize: u16,
    phentsize: u16,
    phnum: u16,
    shentsize: u16,
    shnum: u16,
    shstrndx: u16,
};

pub fn isValidElf(data: []const u8) bool {
    if (data.len < @sizeOf(ElfHeader)) return false;
    return data[0] == 0x7F and data[1] == 'E' and data[2] == 'L' and data[3] == 'F';
}

pub fn getEntryPoint(data: []const u8) ?u32 {
    if (!isValidElf(data)) return null;
    const header: *const ElfHeader = @ptrCast(@alignCast(data.ptr));
    return header.entry;
}
