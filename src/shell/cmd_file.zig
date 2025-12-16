// Home OS - File Commands
// Copyright © 2025 Romy Rianata - Home OS
// RAM filesystem commands: ls, cat, touch, rm, write, echo

const vga = @import("../lib/vga.zig");
const VgaWriter = vga.VgaWriter;
const vfs = @import("../fs/vfs.zig");
const FileInfo = vfs.FileInfo;

var writer: *VgaWriter = undefined;
var global_vfs: *vfs.VFS = undefined;

pub fn init(w: *VgaWriter, vfs_ptr: *vfs.VFS) void {
    writer = w;
    global_vfs = vfs_ptr;
}

pub fn cmdLs() void {
    writer.write("\n");
    writer.setColor(.light_cyan, .black);
    writer.write("Files in filesystem:\n");
    writer.setColor(.light_grey, .black);
    const count = global_vfs.count();
    if (count == 0) {
        writer.write("  (no files)\n");
    } else {
        global_vfs.list(&printFileInfo);
    }
}

fn printFileInfo(info: FileInfo) void {
    writer.write("  ");
    if (info.is_directory) {
        writer.setColor(.light_blue, .black);
        writer.write(info.name);
        writer.write("/");
    } else {
        writer.setColor(.white, .black);
        writer.write(info.name);
    }
    writer.setColor(.light_grey, .black);
    writer.write(" (");
    writer.printInt(@truncate(info.size));
    writer.write(" bytes)\n");
}

pub fn cmdCat(filename: []const u8) void {
    writer.write("\n");
    var file = global_vfs.open(filename) catch {
        writer.setColor(.light_red, .black);
        writer.write("Error: File not found: ");
        writer.write(filename);
        writer.write("\n");
        writer.setColor(.light_grey, .black);
        return;
    };
    writer.setColor(.white, .black);
    var buffer: [512]u8 = undefined;
    while (true) {
        const bytes_read = file.read(&buffer) catch break;
        if (bytes_read == 0) break;
        writer.write(buffer[0..bytes_read]);
    }
    writer.setColor(.light_grey, .black);
    writer.write("\n");
}

pub fn cmdTouch(filename: []const u8) void {
    writer.write("\n");
    if (filename.len == 0) {
        writer.setColor(.light_red, .black);
        writer.write("Error: No filename specified\n");
        writer.setColor(.light_grey, .black);
        return;
    }
    global_vfs.create(filename) catch |err| {
        writer.setColor(.light_red, .black);
        switch (err) {
            error.FileExists => writer.write("Error: File already exists\n"),
            error.NoSpace => writer.write("Error: No space left\n"),
            error.InvalidName => writer.write("Error: Invalid filename\n"),
        }
        writer.setColor(.light_grey, .black);
        return;
    };
    writer.setColor(.light_green, .black);
    writer.write("Created: ");
    writer.write(filename);
    writer.write("\n");
    writer.setColor(.light_grey, .black);
}

pub fn cmdRm(filename: []const u8) void {
    writer.write("\n");
    if (filename.len == 0) {
        writer.setColor(.light_red, .black);
        writer.write("Error: No filename specified\n");
        writer.setColor(.light_grey, .black);
        return;
    }
    global_vfs.delete(filename) catch {
        writer.setColor(.light_red, .black);
        writer.write("Error: File not found: ");
        writer.write(filename);
        writer.write("\n");
        writer.setColor(.light_grey, .black);
        return;
    };
    writer.setColor(.light_green, .black);
    writer.write("Deleted: ");
    writer.write(filename);
    writer.write("\n");
    writer.setColor(.light_grey, .black);
}

pub fn cmdWrite(args: []const u8) void {
    writer.write("\n");
    var space_idx: usize = 0;
    while (space_idx < args.len and args[space_idx] != ' ') space_idx += 1;
    if (space_idx >= args.len) {
        writer.setColor(.light_red, .black);
        writer.write("Usage: write <filename> <content>\n");
        writer.setColor(.light_grey, .black);
        return;
    }
    const filename = args[0..space_idx];
    const content = args[space_idx + 1 ..];
    _ = global_vfs.write(filename, content) catch {
        writer.setColor(.light_red, .black);
        writer.write("Error: Could not write to file\n");
        writer.setColor(.light_grey, .black);
        return;
    };
    writer.setColor(.light_green, .black);
    writer.write("Written ");
    writer.printInt(@truncate(content.len));
    writer.write(" bytes to: ");
    writer.write(filename);
    writer.write("\n");
    writer.setColor(.light_grey, .black);
}

pub fn cmdEcho(args: []const u8) void {
    writer.write("\n");
    writer.setColor(.white, .black);
    writer.write(args);
    writer.write("\n");
    writer.setColor(.light_grey, .black);
}
