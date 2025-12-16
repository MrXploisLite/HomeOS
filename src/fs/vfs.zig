// Home OS - Virtual Filesystem Interface (Phase 6 - Read/Write Support)
// Copyright © 2025 Romy Rianata - Home OS
// Unified file operations interface with write support

const tar = @import("tar.zig");
const ramdisk = @import("ramdisk.zig");
const simplefs = @import("simplefs.zig");
const serial = @import("../drivers/serial.zig");

/// File info for listing (re-export from simplefs)
pub const FileInfo = simplefs.FileInfo;

/// File handle for read operations
pub const File = struct {
    name_buf: [simplefs.MAX_FILENAME]u8,
    name_len: usize,
    size: usize,
    data_offset: usize,
    position: usize,
    fs: *simplefs.SimpleFS,

    /// Read from file at current position
    pub fn read(self: *File, buffer: []u8) !usize {
        const remaining = self.size - self.position;
        const to_read = @min(buffer.len, remaining);

        if (to_read == 0) return 0;

        const src = self.fs.disk.getPtr(self.data_offset + self.position);
        for (0..to_read) |i| {
            buffer[i] = src[i];
        }

        self.position += to_read;
        return to_read;
    }

    /// Seek to specific offset
    pub fn seek(self: *File, offset: usize) !void {
        if (offset > self.size) return error.InvalidOffset;
        self.position = offset;
    }

    /// Get current position
    pub fn tell(self: *const File) usize {
        return self.position;
    }

    /// Get file size
    pub fn getSize(self: *const File) usize {
        return self.size;
    }

    /// Check if at end of file
    pub fn eof(self: *const File) bool {
        return self.position >= self.size;
    }

    /// Close file
    pub fn close(self: *File) void {
        _ = self;
    }

    /// Get filename
    pub fn getName(self: *const File) []const u8 {
        return self.name_buf[0..self.name_len];
    }
};

/// Virtual Filesystem with Read/Write support
pub const VFS = struct {
    simple_fs: simplefs.SimpleFS,
    tar_fs: ?tar.TARFilesystem,

    /// Initialize VFS with ramdisk
    pub fn init(disk: *ramdisk.Ramdisk) VFS {
        return VFS{
            .simple_fs = simplefs.SimpleFS.init(disk),
            .tar_fs = null,
        };
    }

    /// Initialize VFS with TAR filesystem for initial files
    pub fn initWithTar(disk: *ramdisk.Ramdisk, tar_disk: *ramdisk.Ramdisk) VFS {
        return VFS{
            .simple_fs = simplefs.SimpleFS.init(disk),
            .tar_fs = tar.TARFilesystem.init(tar_disk),
        };
    }

    /// Open file by path (read mode)
    pub fn open(self: *VFS, path: []const u8) !File {
        // First check SimpleFS
        if (self.simple_fs.findFile(path)) |entry| {
            var file = File{
                .name_buf = undefined,
                .name_len = entry.name_len,
                .size = entry.size,
                .data_offset = entry.data_offset,
                .position = 0,
                .fs = &self.simple_fs,
            };
            // Copy name
            for (entry.name[0..entry.name_len], 0..) |c, i| {
                file.name_buf[i] = c;
            }
            return file;
        }

        return error.FileNotFound;
    }

    /// Create a new file
    pub fn create(self: *VFS, name: []const u8) !void {
        _ = try self.simple_fs.createFile(name);
    }

    /// Write data to file (creates if not exists)
    pub fn write(self: *VFS, name: []const u8, data: []const u8) !usize {
        return try self.simple_fs.writeFile(name, data);
    }

    /// Append data to file
    pub fn append(self: *VFS, name: []const u8, data: []const u8) !usize {
        return try self.simple_fs.appendFile(name, data);
    }

    /// Delete a file
    pub fn delete(self: *VFS, name: []const u8) !void {
        return try self.simple_fs.deleteFile(name);
    }

    /// Check if file exists
    pub fn exists(self: *VFS, path: []const u8) bool {
        return self.simple_fs.exists(path);
    }

    /// Get file size
    pub fn stat(self: *VFS, path: []const u8) !usize {
        return try self.simple_fs.getFileSize(path);
    }

    /// List all files
    pub fn list(self: *VFS, callback: *const fn (FileInfo) void) void {
        self.simple_fs.listFiles(callback);
    }

    /// Count files
    pub fn count(self: *VFS) usize {
        return self.simple_fs.countFiles();
    }

    /// Read entire file into buffer
    pub fn readAll(self: *VFS, path: []const u8, buffer: []u8) !usize {
        return try self.simple_fs.readFile(path, buffer);
    }

    /// Import file from TAR (for initial files)
    pub fn importFromTar(self: *VFS, tar_fs: *tar.TARFilesystem, name: []const u8) !void {
        const info = tar_fs.lookup(name) orelse return error.FileNotFound;

        // Read data from TAR
        const src = tar_fs.disk.getPtr(info.data_offset);
        const size = @min(info.size, simplefs.MAX_FILE_SIZE);

        // Write to SimpleFS (creates file if not exists)
        _ = try self.simple_fs.writeFile(name, src[0..size]);
    }
};
