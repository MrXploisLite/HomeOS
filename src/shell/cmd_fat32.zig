// Home OS - FAT32 Commands
// Copyright © 2025 Romy Rianata - Home OS
// FAT32 disk commands: lsfat, catfat, mkfat, writefat, rmfat

const vga = @import("../lib/vga.zig");
const VgaWriter = vga.VgaWriter;
const fat32 = @import("../fs/fat32.zig");

var writer: *VgaWriter = undefined;

pub fn init(w: *VgaWriter) void {
    writer = w;
}

pub fn cmdLsFat() void {
    writer.write("\n");
    writer.setColor(.light_cyan, .black);
    writer.write("FAT32 Root Directory:\n");
    if (!fat32.isInitialized()) {
        writer.setColor(.yellow, .black);
        writer.write("  FAT32 not initialized\n");
        writer.setColor(.light_grey, .black);
        return;
    }
    const fs = fat32.getFS();
    if (fs == null) {
        writer.setColor(.light_red, .black);
        writer.write("  Error: Could not get filesystem\n");
        writer.setColor(.light_grey, .black);
        return;
    }
    writer.setColor(.light_grey, .black);
    fs.?.listRoot(&printFatEntry);
}

fn printFatEntry(entry: *const fat32.DirEntry) void {
    if ((entry.attr & fat32.ATTR_VOLUME_ID) != 0) return;
    writer.write("  ");
    var name_buf: [13]u8 = undefined;
    const name_len = fat32.getName83(entry, &name_buf);
    if (entry.isDirectory()) {
        writer.setColor(.light_blue, .black);
        writer.write(name_buf[0..name_len]);
        writer.write("/");
    } else {
        writer.setColor(.white, .black);
        writer.write(name_buf[0..name_len]);
    }
    writer.setColor(.light_grey, .black);
    writer.write(" (");
    writer.printInt(entry.file_size);
    writer.write(" bytes)\n");
}

pub fn cmdCatFat(filename: []const u8) void {
    writer.write("\n");
    if (!fat32.isInitialized()) {
        writer.setColor(.yellow, .black);
        writer.write("FAT32 not initialized\n");
        writer.setColor(.light_grey, .black);
        return;
    }
    const fs = fat32.getFS();
    if (fs == null) {
        writer.setColor(.light_red, .black);
        writer.write("Error: Could not get filesystem\n");
        writer.setColor(.light_grey, .black);
        return;
    }
    const entry = fs.?.findFile(fs.?.root_cluster, filename);
    if (entry == null) {
        writer.setColor(.light_red, .black);
        writer.write("File not found: ");
        writer.write(filename);
        writer.write("\n");
        writer.setColor(.light_grey, .black);
        return;
    }
    if (entry.?.isDirectory()) {
        writer.setColor(.light_red, .black);
        writer.write("Error: ");
        writer.write(filename);
        writer.write(" is a directory\n");
        writer.setColor(.light_grey, .black);
        return;
    }
    var buffer: [4096]u8 = undefined;
    const bytes_read = fs.?.readFile(&entry.?, &buffer, buffer.len);
    writer.setColor(.white, .black);
    if (bytes_read > 0) {
        writer.write(buffer[0..bytes_read]);
    }
    writer.setColor(.light_grey, .black);
    writer.write("\n");
}

pub fn cmdMkFat(filename: []const u8) void {
    writer.write("\n");
    if (!fat32.isInitialized()) {
        writer.setColor(.yellow, .black);
        writer.write("FAT32 not initialized\n");
        writer.setColor(.light_grey, .black);
        return;
    }
    var fs = fat32.getFS();
    if (fs == null) {
        writer.setColor(.light_red, .black);
        writer.write("Error: Could not get filesystem\n");
        writer.setColor(.light_grey, .black);
        return;
    }
    if (filename.len == 0) {
        writer.setColor(.light_red, .black);
        writer.write("Error: No filename specified\n");
        writer.setColor(.light_grey, .black);
        return;
    }
    const entry = fs.?.createFile(fs.?.root_cluster, filename);
    if (entry == null) {
        writer.setColor(.light_red, .black);
        writer.write("Error: Could not create file\n");
        writer.setColor(.light_grey, .black);
        return;
    }
    writer.setColor(.light_green, .black);
    writer.write("Created: ");
    writer.write(filename);
    writer.write("\n");
    writer.setColor(.light_grey, .black);
}

pub fn cmdWriteFat(args: []const u8) void {
    writer.write("\n");
    if (!fat32.isInitialized()) {
        writer.setColor(.yellow, .black);
        writer.write("FAT32 not initialized\n");
        writer.setColor(.light_grey, .black);
        return;
    }
    var fs = fat32.getFS();
    if (fs == null) {
        writer.setColor(.light_red, .black);
        writer.write("Error: Could not get filesystem\n");
        writer.setColor(.light_grey, .black);
        return;
    }
    var space_idx: usize = 0;
    while (space_idx < args.len and args[space_idx] != ' ') space_idx += 1;
    if (space_idx >= args.len) {
        writer.setColor(.light_red, .black);
        writer.write("Usage: writefat <filename> <content>\n");
        writer.setColor(.light_grey, .black);
        return;
    }
    const filename = args[0..space_idx];
    const content = args[space_idx + 1 ..];

    if (fs.?.writeFile(fs.?.root_cluster, filename, content)) {
        writer.setColor(.light_green, .black);
        writer.write("Written ");
        writer.printInt(@truncate(content.len));
        writer.write(" bytes to ");
        writer.write(filename);
        writer.write("\n");
    } else {
        writer.setColor(.light_red, .black);
        writer.write("Error: Could not write to file\n");
    }
    writer.setColor(.light_grey, .black);
}

pub fn cmdRmFat(filename: []const u8) void {
    writer.write("\n");
    if (!fat32.isInitialized()) {
        writer.setColor(.yellow, .black);
        writer.write("FAT32 not initialized\n");
        writer.setColor(.light_grey, .black);
        return;
    }
    var fs = fat32.getFS();
    if (fs == null) {
        writer.setColor(.light_red, .black);
        writer.write("Error: Could not get filesystem\n");
        writer.setColor(.light_grey, .black);
        return;
    }
    if (filename.len == 0) {
        writer.setColor(.light_red, .black);
        writer.write("Error: No filename specified\n");
        writer.setColor(.light_grey, .black);
        return;
    }
    if (fs.?.deleteFile(fs.?.root_cluster, filename)) {
        writer.setColor(.light_green, .black);
        writer.write("Deleted: ");
        writer.write(filename);
        writer.write("\n");
    } else {
        writer.setColor(.light_red, .black);
        writer.write("Error: File not found: ");
        writer.write(filename);
        writer.write("\n");
    }
    writer.setColor(.light_grey, .black);
}
