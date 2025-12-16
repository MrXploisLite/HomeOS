// Home OS - Virtual Memory Manager (VMM)
// Copyright © 2025 Romy Rianata - Home OS

const serial = @import("../drivers/serial.zig");
const pmm = @import("pmm.zig");
const paging = @import("paging.zig");

pub const PAGE_PRESENT: u32 = 1 << 0;
pub const PAGE_WRITABLE: u32 = 1 << 1;
pub const PAGE_USER: u32 = 1 << 2;
pub const PAGE_WRITETHROUGH: u32 = 1 << 3;
pub const PAGE_NOCACHE: u32 = 1 << 4;
pub const PAGE_ACCESSED: u32 = 1 << 5;
pub const PAGE_DIRTY: u32 = 1 << 6;
pub const PAGE_SIZE_4MB: u32 = 1 << 7;
pub const PAGE_GLOBAL: u32 = 1 << 8;

pub const USER_SPACE_START: u32 = 0x00400000;
pub const USER_SPACE_END: u32 = 0xC0000000;
pub const KERNEL_SPACE_START: u32 = 0xC0000000;
pub const USER_STACK_TOP: u32 = 0xBFFFF000;
pub const USER_HEAP_START: u32 = 0x10000000;

pub const PageDirEntry = packed struct {
    present: bool,
    writable: bool,
    user: bool,
    write_through: bool,
    cache_disable: bool,
    accessed: bool,
    reserved: bool,
    page_size: bool,
    global: bool,
    available: u3,
    page_table_addr: u20,

    pub fn fromU32(val: u32) PageDirEntry {
        return @bitCast(val);
    }
    pub fn toU32(self: PageDirEntry) u32 {
        return @bitCast(self);
    }
};

pub const AddressSpace = struct {
    page_directory: u32,

    pub fn create() ?AddressSpace {
        const pd_phys = pmm.allocPage() orelse return null;
        const pd: [*]volatile u32 = @ptrFromInt(pd_phys);
        var i: usize = 0;
        while (i < 1024) : (i += 1) {
            pd[i] = 0;
        }

        const kernel_pt = pmm.allocPage() orelse {
            pmm.freePage(pd_phys);
            return null;
        };

        const pt: [*]volatile u32 = @ptrFromInt(kernel_pt);
        i = 0;
        while (i < 1024) : (i += 1) {
            pt[i] = @as(u32, @truncate(i)) * 4096 | PAGE_PRESENT | PAGE_WRITABLE;
        }
        pd[0] = kernel_pt | PAGE_PRESENT | PAGE_WRITABLE;

        serial.write("VMM: Created address space at 0x");
        serial.writeHex(pd_phys);
        serial.write("\n");
        return AddressSpace{ .page_directory = pd_phys };
    }

    pub fn destroy(self: *AddressSpace) void {
        const pd: [*]volatile u32 = @ptrFromInt(self.page_directory);
        var i: usize = 1;
        while (i < 768) : (i += 1) {
            if ((pd[i] & PAGE_PRESENT) != 0) {
                const pt_phys = pd[i] & 0xFFFFF000;
                const pt: [*]volatile u32 = @ptrFromInt(pt_phys);
                var j: usize = 0;
                while (j < 1024) : (j += 1) {
                    if ((pt[j] & PAGE_PRESENT) != 0) {
                        const page_phys = pt[j] & 0xFFFFF000;
                        pmm.freePage(page_phys);
                    }
                }
                pmm.freePage(pt_phys);
            }
        }
        pmm.freePage(self.page_directory);
        self.page_directory = 0;
    }

    pub fn mapPage(self: *AddressSpace, virt: u32, phys: u32, flags: u32) bool {
        const pd_idx = virt >> 22;
        const pt_idx = (virt >> 12) & 0x3FF;
        const pd: [*]volatile u32 = @ptrFromInt(self.page_directory);

        if ((pd[pd_idx] & PAGE_PRESENT) == 0) {
            const pt_phys = pmm.allocPage() orelse return false;
            const pt: [*]volatile u32 = @ptrFromInt(pt_phys);
            var i: usize = 0;
            while (i < 1024) : (i += 1) {
                pt[i] = 0;
            }
            pd[pd_idx] = pt_phys | PAGE_PRESENT | PAGE_WRITABLE | PAGE_USER;
        }

        const pt_phys = pd[pd_idx] & 0xFFFFF000;
        const pt: [*]volatile u32 = @ptrFromInt(pt_phys);
        pt[pt_idx] = (phys & 0xFFFFF000) | flags | PAGE_PRESENT;
        invalidatePage(virt);
        return true;
    }

    pub fn unmapPage(self: *AddressSpace, virt: u32) void {
        const pd_idx = virt >> 22;
        const pt_idx = (virt >> 12) & 0x3FF;
        const pd: [*]volatile u32 = @ptrFromInt(self.page_directory);
        if ((pd[pd_idx] & PAGE_PRESENT) == 0) return;
        const pt_phys = pd[pd_idx] & 0xFFFFF000;
        const pt: [*]volatile u32 = @ptrFromInt(pt_phys);
        pt[pt_idx] = 0;
        invalidatePage(virt);
    }

    pub fn allocPage(self: *AddressSpace, virt: u32, flags: u32) bool {
        const phys = pmm.allocPage() orelse return false;
        if (!self.mapPage(virt, phys, flags)) {
            pmm.freePage(phys);
            return false;
        }
        const ptr: [*]volatile u8 = @ptrFromInt(virt);
        var i: usize = 0;
        while (i < pmm.PAGE_SIZE) : (i += 1) {
            ptr[i] = 0;
        }
        return true;
    }

    pub fn getPhysical(self: *AddressSpace, virt: u32) ?u32 {
        const pd_idx = virt >> 22;
        const pt_idx = (virt >> 12) & 0x3FF;
        const offset = virt & 0xFFF;
        const pd: [*]volatile u32 = @ptrFromInt(self.page_directory);
        if ((pd[pd_idx] & PAGE_PRESENT) == 0) return null;
        const pt_phys = pd[pd_idx] & 0xFFFFF000;
        const pt: [*]volatile u32 = @ptrFromInt(pt_phys);
        if ((pt[pt_idx] & PAGE_PRESENT) == 0) return null;
        return (pt[pt_idx] & 0xFFFFF000) + offset;
    }

    pub fn activate(self: *AddressSpace) void {
        asm volatile ("mov %[pd], %%cr3"
            :
            : [pd] "r" (self.page_directory),
        );
    }
};

fn invalidatePage(virt: u32) void {
    asm volatile ("invlpg (%[addr])"
        :
        : [addr] "r" (virt),
        : .{ .memory = true });
}

pub fn getCurrentPageDir() u32 {
    var cr3: u32 = undefined;
    asm volatile ("mov %%cr3, %[cr3]"
        : [cr3] "=r" (cr3),
    );
    return cr3;
}

var kernel_space: ?AddressSpace = null;

pub fn init() void {
    serial.write("VMM: Initializing virtual memory manager...\n");
    serial.write("VMM: Ready\n");
}

pub fn initKernelSpace() void {
    kernel_space = AddressSpace.create();
    if (kernel_space) |*ks| {
        ks.activate();
        serial.write("VMM: Kernel address space activated\n");
    }
}

pub fn getKernelSpace() ?*AddressSpace {
    if (kernel_space) |*ks| {
        return ks;
    }
    return null;
}
