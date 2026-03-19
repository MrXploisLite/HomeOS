const std = @import("std");

pub const LIMINE_BASE_REVISION = [2]u64{ 0xf9562b2d5c95a6c8, 0x6a7b384944536bdc };

// Limine revision tag - placed in a section Limine can find
export var base_revision: [3]u64 align(8) linksection(".limine_reqs") = .{
    LIMINE_BASE_REVISION[0],
    LIMINE_BASE_REVISION[1],
    1, // revision number
};

// Framebuffer request magic
const LIMINE_FRAMEBUFFER_MAGIC = [4]u64{
    0x9d5827dcd881dd75,
    0xa3148604f6fab11b,
    0,
    0,
};

pub const FramebufferResponse = extern struct {
    revision: u64,
    framebuffer_count: u64,
    framebuffers: [*]*Framebuffer,
};

pub const Framebuffer = extern struct {
    address: [*]volatile u32,
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
    edid: ?[*]u8,
};

pub const FramebufferRequest = extern struct {
    id: [4]u64 = LIMINE_FRAMEBUFFER_MAGIC,
    revision: u64 = 0,
    response: ?*FramebufferResponse = null,
};

export var framebuffer_request: FramebufferRequest align(8) linksection(".limine_reqs") = .{};

export fn _start() callconv(.c) noreturn {
    // 64-Bit Limine Entry Point
    if (framebuffer_request.response) |resp| {
        if (resp.framebuffer_count > 0) {
            const fb = resp.framebuffers[0];
            const pitch_px = fb.pitch / 4; // pitch in pixels (32bpp)

            var y: u64 = 0;
            while (y < fb.height) : (y += 1) {
                var x: u64 = 0;
                while (x < fb.width) : (x += 1) {
                    const r: u32 = @truncate((x * 80) / fb.width);
                    const g: u32 = 0;
                    const b: u32 = @as(u32, @truncate((y * 200) / fb.height)) + 55;
                    fb.address[y * pitch_px + x] = (r << 16) | (g << 8) | b;
                }
            }
        }
    }

    while (true) {
        asm volatile ("hlt");
    }
}
