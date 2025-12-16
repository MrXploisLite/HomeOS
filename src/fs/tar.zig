// Home OS - TAR Filesystem (USTAR format)
// Copyright © 2025 Romy Rianata - Home OS
// Read-only TAR archive filesystem

const ramdisk = @import("ramdisk.zig");
const serial = @import("../drivers/serial.zig");

/// USTAR header structure (512 bytes)
pub const TARHeader = extern struct {
    filename: [100]u8, // File name
    mode: [8]u8, // File mode (octal)
    uid: [8]u8, // Owner user ID (octal)
    gid: [8]u8, // Owner group ID (octal)
    size: [12]u8, // File size in bytes (octal)
    mtime: [12]u8, // Modification time (octal)
    checksum: [8]u8, // Header checksum (octal)
    typeflag: u8, // File type
    linkname: [100]u8, // Link target name
    magic: [6]u8, // "ustar\0"
    version: [2]u8, // "00"
    uname: [32]u8, // Owner user name
    gname: [32]u8, // Owner group name
    devmajor: [8]u8, // Device major number
    devminor: [8]u8, // Device minor number
    prefix: [155]u8, // Filename prefix
    padding: [12]u8, // Padding to 512 bytes
};

/// File type flags
pub const FileType = enum(u8) {
    regular = '0',
    regular_old = 0, // Old format (null byte)
    hard_link = '1',
    symlink = '2',
    char_device = '3',
    block_device = '4',
    directory = '5',
    fifo = '6',
    _,

    pub fn isRegular(self: FileType) bool {
        return self == .regular or self == .regular_old;
    }

    pub fn isDirectory(self: FileType) bool {
        return self == .directory;
    }
};

/// File information
pub const FileInfo = struct {
    name: []const u8,
    size: usize,
    file_type: FileType,
    data_offset: usize, // Offset in ramdisk where data starts
};

/// TAR filesystem
pub const TARFilesystem = struct {
    disk: *ramdisk.Ramdisk,

    /// Initialize TAR filesystem
    pub fn init(disk: *ramdisk.Ramdisk) TARFilesystem {
        return TARFilesystem{ .disk = disk };
    }

    /// Convert octal ASCII string to binary
    fn oct2bin(str: []const u8) usize {
        var n: usize = 0;
        for (str) |c| {
            if (c < '0' or c > '7') break;
            n = n * 8 + (c - '0');
        }
        return n;
    }

    /// Check if header is valid USTAR
    fn isValidHeader(header: *const TARHeader) bool {
        return header.magic[0] == 'u' and
            header.magic[1] == 's' and
            header.magic[2] == 't' and
            header.magic[3] == 'a' and
            header.magic[4] == 'r';
    }

    /// Get filename from header (handle null termination)
    fn getFilename(header: *const TARHeader) []const u8 {
        // Find null terminator or use full 100 bytes
        var len: usize = 0;
        while (len < 100 and header.filename[len] != 0) : (len += 1) {}
        return header.filename[0..len];
    }

    /// Strip leading "./" from filename if present
    fn stripPrefix(name: []const u8) []const u8 {
        if (name.len >= 2 and name[0] == '.' and name[1] == '/') {
            return name[2..];
        }
        return name;
    }

    /// Find file in archive
    pub fn lookup(self: *TARFilesystem, filename: []const u8) ?FileInfo {
        var offset: usize = 0;

        while (offset < self.disk.size) {
            // Get header
            const header: *const TARHeader = @ptrCast(
                @alignCast(self.disk.getPtr(offset)),
            );

            // Check for end of archive (all zeros)
            if (!isValidHeader(header)) break;

            // Get file size
            const size = oct2bin(header.size[0..12]);

            // Get filename (strip ./ prefix for comparison)
            const raw_name = getFilename(header);
            const name = stripPrefix(raw_name);

            // Compare filename (also strip ./ from search term)
            const search_name = stripPrefix(filename);

            if (name.len == search_name.len) {
                var match = true;
                for (name, 0..) |c, i| {
                    if (c != search_name[i]) {
                        match = false;
                        break;
                    }
                }

                if (match) {
                    return FileInfo{
                        .name = name,
                        .size = size,
                        .file_type = @enumFromInt(header.typeflag),
                        .data_offset = offset + 512,
                    };
                }
            }

            // Move to next file (header + data, rounded to 512)
            const data_blocks = (size + 511) / 512;
            offset += 512 + (data_blocks * 512);

            // Safety check to prevent infinite loop
            if (offset >= self.disk.size) break;
        }

        return null;
    }

    /// Read file data
    pub fn readFile(self: *TARFilesystem, info: *const FileInfo, buffer: []u8) !usize {
        if (buffer.len < info.size) return error.BufferTooSmall;

        const src = self.disk.getPtr(info.data_offset);
        @memcpy(buffer[0..info.size], src[0..info.size]);

        return info.size;
    }

    /// List all files in archive
    pub fn listFiles(self: *TARFilesystem, callback: *const fn (FileInfo) void) void {
        var offset: usize = 0;

        while (offset < self.disk.size) {
            const header: *const TARHeader = @ptrCast(
                @alignCast(self.disk.getPtr(offset)),
            );

            if (!isValidHeader(header)) break;

            const size = oct2bin(header.size[0..12]);
            const raw_name = getFilename(header);
            const name = stripPrefix(raw_name);

            const file_type: FileType = @enumFromInt(header.typeflag);

            // Skip directory entries (empty name after stripping or directory type)
            if (name.len == 0 or file_type.isDirectory()) {
                const data_blocks = (size + 511) / 512;
                offset += 512 + (data_blocks * 512);
                continue;
            }

            const info = FileInfo{
                .name = name,
                .size = size,
                .file_type = file_type,
                .data_offset = offset + 512,
            };

            callback(info);

            const data_blocks = (size + 511) / 512;
            offset += 512 + (data_blocks * 512);

            if (offset >= self.disk.size) break;
        }
    }

    /// Count files in archive (excludes directories)
    pub fn countFiles(self: *TARFilesystem) usize {
        var count: usize = 0;
        var offset: usize = 0;

        while (offset < self.disk.size) {
            const header: *const TARHeader = @ptrCast(
                @alignCast(self.disk.getPtr(offset)),
            );

            if (!isValidHeader(header)) break;

            // Only count regular files, not directories
            const raw_name = getFilename(header);
            const name = stripPrefix(raw_name);
            const file_type: FileType = @enumFromInt(header.typeflag);

            if (name.len > 0 and file_type.isRegular()) {
                count += 1;
            }

            const size = oct2bin(header.size[0..12]);
            const data_blocks = (size + 511) / 512;
            offset += 512 + (data_blocks * 512);

            if (offset >= self.disk.size) break;
        }

        return count;
    }
};
