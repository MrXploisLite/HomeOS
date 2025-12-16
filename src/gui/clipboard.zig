// Home OS - Clipboard System
// Copyright © 2025 Romy Rianata - Home OS

// Global clipboard buffer
var clipboard_data: [512]u8 = [_]u8{0} ** 512;
var clipboard_len: usize = 0;

/// Copy text to clipboard
pub fn copy(text: []const u8) void {
    const len = @min(text.len, 512);
    for (0..len) |i| {
        clipboard_data[i] = text[i];
    }
    clipboard_len = len;
}

/// Get clipboard content
pub fn paste() []const u8 {
    return clipboard_data[0..clipboard_len];
}

/// Check if clipboard has content
pub fn hasContent() bool {
    return clipboard_len > 0;
}

/// Clear clipboard
pub fn clear() void {
    clipboard_len = 0;
}

/// Get clipboard length
pub fn getLength() usize {
    return clipboard_len;
}
