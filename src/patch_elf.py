#!/usr/bin/env python3
"""
Patch all LOAD segment virtual addresses in an ELF64 to the higher half.
Usage: patch_elf.py <input.elf> <output.elf> <add_offset_hex>
E.g.:  patch_elf.py kernel.elf kernel_hh.elf 0xffffffff7f000000
"""
import sys, struct, shutil, os

def patch(inp, out, add):
    shutil.copy2(inp, out)
    with open(out, 'r+b') as f:
        # Read ELF header (64 bytes)
        hdr = f.read(64)
        e_phoff = struct.unpack_from('<Q', hdr, 32)[0]   # program header offset
        e_phentsize = struct.unpack_from('<H', hdr, 54)[0]
        e_phnum = struct.unpack_from('<H', hdr, 56)[0]
        e_shoff = struct.unpack_from('<Q', hdr, 40)[0]   # section header offset
        e_shentsize = struct.unpack_from('<H', hdr, 58)[0]
        e_shnum = struct.unpack_from('<H', hdr, 60)[0]

        # Patch entry point
        e_entry = struct.unpack_from('<Q', hdr, 24)[0]
        f.seek(24); f.write(struct.pack('<Q', (e_entry + add) & 0xffffffffffffffff))

        # Patch program headers
        for i in range(e_phnum):
            base = e_phoff + i * e_phentsize
            f.seek(base)
            ph = f.read(e_phentsize)
            p_type = struct.unpack_from('<I', ph, 0)[0]
            # Patch vaddr (offset 16) and paddr (offset 24)
            p_vaddr = struct.unpack_from('<Q', ph, 16)[0]
            p_paddr = struct.unpack_from('<Q', ph, 24)[0]
            new_vaddr = (p_vaddr + add) & 0xffffffffffffffff
            new_paddr = (p_paddr + add) & 0xffffffffffffffff
            f.seek(base + 16); f.write(struct.pack('<Q', new_vaddr))
            f.seek(base + 24); f.write(struct.pack('<Q', new_paddr))

        # Patch section headers
        for i in range(e_shnum):
            base = e_shoff + i * e_shentsize
            f.seek(base)
            sh = f.read(e_shentsize)
            sh_type = struct.unpack_from('<I', sh, 4)[0]
            sh_addr = struct.unpack_from('<Q', sh, 16)[0]
            if sh_addr != 0:
                new_addr = (sh_addr + add) & 0xffffffffffffffff
                f.seek(base + 16); f.write(struct.pack('<Q', new_addr))

    print(f"Patched {inp} -> {out} (added {hex(add)})")

if __name__ == '__main__':
    inp, out, off = sys.argv[1], sys.argv[2], int(sys.argv[3], 16)
    patch(inp, out, off)
