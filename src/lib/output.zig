// Home OS - Output Writer Interface
// Copyright © 2025 Romy Rianata - Home OS
// Unified output interface for text shell and GUI terminal

/// Output Writer Interface
/// Both VGA text mode and GUI terminal implement this
pub const OutputWriter = struct {
    ptr: *anyopaque,
    writeFn: *const fn (ptr: *anyopaque, data: []const u8) void,
    setColorFn: *const fn (ptr: *anyopaque, fg: u8, bg: u8) void,
    clearFn: *const fn (ptr: *anyopaque) void,
    printIntFn: *const fn (ptr: *anyopaque, value: u32) void,

    pub fn write(self: OutputWriter, data: []const u8) void {
        self.writeFn(self.ptr, data);
    }

    pub fn setColor(self: OutputWriter, fg: u8, bg: u8) void {
        self.setColorFn(self.ptr, fg, bg);
    }

    pub fn clear(self: OutputWriter) void {
        self.clearFn(self.ptr);
    }

    pub fn printInt(self: OutputWriter, value: u32) void {
        self.printIntFn(self.ptr, value);
    }
};

/// Buffer-based writer for GUI Terminal
pub const BufferWriter = struct {
    buffer: []u8,
    len: *usize,
    max_len: usize,

    pub fn init(buffer: []u8, len: *usize) BufferWriter {
        return BufferWriter{
            .buffer = buffer,
            .len = len,
            .max_len = buffer.len,
        };
    }

    pub fn write(self: *BufferWriter, data: []const u8) void {
        for (data) |c| {
            if (self.len.* < self.max_len - 1) {
                self.buffer[self.len.*] = c;
                self.len.* += 1;
            }
        }
    }

    pub fn setColor(self: *BufferWriter, fg: u8, bg: u8) void {
        // GUI terminal ignores color codes for now
        _ = self;
        _ = fg;
        _ = bg;
    }

    pub fn clear(self: *BufferWriter) void {
        self.len.* = 0;
    }

    pub fn printInt(self: *BufferWriter, value: u32) void {
        if (value == 0) {
            self.write("0");
            return;
        }
        var buf: [10]u8 = undefined;
        var i: usize = 0;
        var v = value;
        while (v > 0) : (i += 1) {
            buf[i] = @truncate((v % 10) + '0');
            v /= 10;
        }
        while (i > 0) {
            i -= 1;
            if (self.len.* < self.max_len - 1) {
                self.buffer[self.len.*] = buf[i];
                self.len.* += 1;
            }
        }
    }

    pub fn toOutputWriter(self: *BufferWriter) OutputWriter {
        return OutputWriter{
            .ptr = self,
            .writeFn = writeWrapper,
            .setColorFn = setColorWrapper,
            .clearFn = clearWrapper,
            .printIntFn = printIntWrapper,
        };
    }

    fn writeWrapper(ptr: *anyopaque, data: []const u8) void {
        const self: *BufferWriter = @ptrCast(@alignCast(ptr));
        self.write(data);
    }

    fn setColorWrapper(ptr: *anyopaque, fg: u8, bg: u8) void {
        const self: *BufferWriter = @ptrCast(@alignCast(ptr));
        self.setColor(fg, bg);
    }

    fn clearWrapper(ptr: *anyopaque) void {
        const self: *BufferWriter = @ptrCast(@alignCast(ptr));
        self.clear();
    }

    fn printIntWrapper(ptr: *anyopaque, value: u32) void {
        const self: *BufferWriter = @ptrCast(@alignCast(ptr));
        self.printInt(value);
    }
};
