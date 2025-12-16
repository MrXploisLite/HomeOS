// Home OS - SimpleFS (Read/Write Filesystem)
// Copyright © 2025 Romy Rianata - Home OS
// Simple in-memory filesystem with create, read, write, delete support

const ramdisk = @import("ramdisk.zig");
const serial = @import("../drivers/serial.zig");

/// Maximum filename length
pub const MAX_FILENAME: usize = 32;
/// Maximum number of files
pub const MAX_FILES: usize = 64;
/// Maximum file size (4KB per file)
pub const MAX_FILE_SIZE: usize = 4096;

/// File entry in the filesystem
pub const FileEntry = struct {
    name: [MAX_FILENAME]u8,
    name_len: u8,
    size: u32,
    data_offset: u32, // Offset in data region
    is_used: bool,
    is_directory: bool,

    pub fn getName(self: *const FileEntry) []const u8 {
        return self.name[0..self.name_len];
    }
};

/// File info for listing
pub const FileInfo = struct {
    name: []const u8,
    size: usize,
    is_directory: bool,
};

/// SimpleFS - Simple Read/Write Filesystem
pub const SimpleFS = struct {
    disk: *ramdisk.Ramdisk,
    files: [MAX_FILES]FileEntry,
    file_count: usize,
    next_data_offset: u32,

    /// Initialize SimpleFS
    pub fn init(disk: *ramdisk.Ramdisk) SimpleFS {
        var fs = SimpleFS{
            .disk = disk,
            .files = undefined,
            .file_count = 0,
            .next_data_offset = 0,
        };

        // Clear file entries
        for (&fs.files) |*entry| {
            entry.is_used = false;
            entry.name_len = 0;
            entry.size = 0;
            entry.data_offset = 0;
            entry.is_directory = false;
        }

        return fs;
    }

    /// Find a file by name
    pub fn findFile(self: *SimpleFS, name: []const u8) ?*FileEntry {
        for (&self.files) |*entry| {
            if (entry.is_used and entry.name_len == name.len) {
                var match = true;
                for (entry.name[0..entry.name_len], 0..) |c, i| {
                    if (c != name[i]) {
                        match = false;
                        break;
                    }
                }
                if (match) return entry;
            }
        }
        return null;
    }

    /// Find a free file entry slot
    fn findFreeSlot(self: *SimpleFS) ?*FileEntry {
        for (&self.files) |*entry| {
            if (!entry.is_used) return entry;
        }
        return null;
    }

    /// Create a new file
    pub fn createFile(self: *SimpleFS, name: []const u8) !*FileEntry {
        // Check if file already exists
        if (self.findFile(name) != null) {
            return error.FileExists;
        }

        // Check name length
        if (name.len > MAX_FILENAME or name.len == 0) {
            return error.InvalidName;
        }

        // Find free slot
        const entry = self.findFreeSlot() orelse return error.NoSpace;

        // Check if we have space for data
        const needed: usize = self.next_data_offset + MAX_FILE_SIZE;
        if (needed > self.disk.size) {
            return error.NoSpace;
        }

        // Initialize entry
        entry.is_used = true;
        entry.is_directory = false;
        entry.size = 0;
        entry.data_offset = self.next_data_offset;
        entry.name_len = @as(u8, @truncate(name.len));

        // Copy name
        for (name, 0..) |c, i| {
            entry.name[i] = c;
        }

        // Reserve space for this file
        self.next_data_offset += MAX_FILE_SIZE;
        self.file_count += 1;

        return entry;
    }

    /// Write data to a file
    pub fn writeFile(self: *SimpleFS, name: []const u8, data: []const u8) !usize {
        // Find or create file
        var entry = self.findFile(name);
        if (entry == null) {
            entry = try self.createFile(name);
        }

        const file = entry.?;

        // Check size limit
        if (data.len > MAX_FILE_SIZE) {
            return error.FileTooLarge;
        }

        // Write data to ramdisk
        const dst = self.disk.getMutPtr(file.data_offset);
        for (data, 0..) |c, i| {
            dst[i] = c;
        }

        file.size = @as(u32, @truncate(data.len));

        return data.len;
    }

    /// Append data to a file
    pub fn appendFile(self: *SimpleFS, name: []const u8, data: []const u8) !usize {
        const entry = self.findFile(name) orelse return error.FileNotFound;

        // Check size limit
        if (entry.size + data.len > MAX_FILE_SIZE) {
            return error.FileTooLarge;
        }

        // Append data
        const dst = self.disk.getMutPtr(entry.data_offset + entry.size);
        for (data, 0..) |c, i| {
            dst[i] = c;
        }

        entry.size += @as(u32, @truncate(data.len));

        return data.len;
    }

    /// Read data from a file
    pub fn readFile(self: *SimpleFS, name: []const u8, buffer: []u8) !usize {
        const entry = self.findFile(name) orelse return error.FileNotFound;

        const to_read = @min(buffer.len, entry.size);
        const src = self.disk.getPtr(entry.data_offset);

        for (0..to_read) |i| {
            buffer[i] = src[i];
        }

        return to_read;
    }

    /// Delete a file
    pub fn deleteFile(self: *SimpleFS, name: []const u8) !void {
        const entry = self.findFile(name) orelse return error.FileNotFound;

        // Mark as unused (data space is not reclaimed - simple implementation)
        entry.is_used = false;
        entry.name_len = 0;
        entry.size = 0;

        self.file_count -= 1;
    }

    /// Check if file exists
    pub fn exists(self: *SimpleFS, name: []const u8) bool {
        return self.findFile(name) != null;
    }

    /// Get file size
    pub fn getFileSize(self: *SimpleFS, name: []const u8) !usize {
        const entry = self.findFile(name) orelse return error.FileNotFound;
        return entry.size;
    }

    /// List all files
    pub fn listFiles(self: *SimpleFS, callback: *const fn (FileInfo) void) void {
        for (&self.files) |*entry| {
            if (entry.is_used) {
                const info = FileInfo{
                    .name = entry.name[0..entry.name_len],
                    .size = entry.size,
                    .is_directory = entry.is_directory,
                };
                callback(info);
            }
        }
    }

    /// Count files
    pub fn countFiles(self: *SimpleFS) usize {
        return self.file_count;
    }

    /// Import a file from TAR filesystem (for initial files)
    pub fn importFromTar(self: *SimpleFS, tar_fs: anytype, name: []const u8) !void {
        const info = tar_fs.lookup(name) orelse return error.FileNotFound;

        // Create file in SimpleFS
        const entry = try self.createFile(name);

        // Copy data
        const src = tar_fs.disk.getPtr(info.data_offset);
        const dst = self.disk.getMutPtr(entry.data_offset);

        const size = @min(info.size, MAX_FILE_SIZE);
        for (0..size) |i| {
            dst[i] = src[i];
        }

        entry.size = @as(u32, @truncate(size));
    }
};
