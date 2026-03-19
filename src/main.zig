const std = @import("std");

pub const LIMINE_BASE_REVISION = [4]u64{ 0xf9562b2d5c95a6c8, 0x6a7b384944536bdc, 1, 0 };
pub const LIMINE_FRAMEBUFFER_REQUEST = [4]u64{ 0x9d5827dcd881dd75, 0xa3148604f6fab11b, 0, 0 };

export var base_revision: [4]u64 align(8) linksection(".requests") = LIMINE_BASE_REVISION;

pub const FramebufferRequest = extern struct {
    id: [4]u64 = LIMINE_FRAMEBUFFER_REQUEST,
    revision: u64 = 0,
    response: ?*FramebufferResponse = null,
};

pub const FramebufferResponse = extern struct {
    revision: u64,
    framebuffer_count: u64,
    framebuffers: [*]*Framebuffer,
};

pub const Framebuffer = extern struct {
    address: [*]u8,
    width: u64,
    height: u64,
    pitch: u64,
    bpp: u16,
    memory_model: u8,
    red_mask_size: u8,
    red_mask_shift: u8,
    green_mask_size: u8,
    green_mask_shift: u8,
    blue_mask_size: u8,
    blue_mask_shift: u8,
    unused: [7]u8,
    edid_size: u64,
    edid: [*]u8,
};

export var framebuffer_request: FramebufferRequest align(8) linksection(".requests") = .{};

export fn _start() callconv(.c) noreturn {
    // 64-Bit Limine Entry Point
    if (framebuffer_request.response) |resp| {
        if (resp.framebuffer_count > 0) {
            const fb = resp.framebuffers[0];
            
            // Draw a purple/blue gradient overlay
            var y: u64 = 0;
            while (y < fb.height) : (y += 1) {
                var x: u64 = 0;
                while (x < fb.width) : (x += 1) {
                    const offset = y * (fb.pitch / 4) + x;
                    const ptr: [*]u32 = @ptrCast(@alignCast(fb.address));
                    
                    const r: u32 = @truncate((x * 255) / fb.width);
                    const b: u32 = @truncate((y * 255) / fb.height);
                    const color = (r << 16) | b;
                    
                    ptr[offset] = color;
                }
            }
        }
    }

    while (true) {
        asm volatile ("hlt");
    }
}
