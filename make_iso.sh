#!/bin/bash
# Home OS ISO Builder (Linux/WSL)
# Copyright © 2025 Romy Rianata

echo "========================================"
echo "       Home OS ISO Builder"
echo "   Copyright 2025 Romy Rianata"
echo "========================================"
echo ""

# Check if kernel exists
if [ ! -f "zig-out/bin/kernel.elf" ]; then
    echo "[ERROR] kernel.elf not found! Run 'zig build' first."
    exit 1
fi

# Create ISO directory structure
echo "[1/4] Creating ISO structure..."
mkdir -p iso/boot/grub

# Copy kernel
echo "[2/4] Copying kernel..."
cp zig-out/bin/kernel.elf iso/boot/kernel.elf

# Create GRUB config if not exists
if [ ! -f "iso/boot/grub/grub.cfg" ]; then
    echo "[2.5/4] Creating GRUB config..."
    cat > iso/boot/grub/grub.cfg << 'EOF'
set timeout=5
set default=0

menuentry "Home OS" {
    multiboot /boot/kernel.elf
    boot
}

menuentry "Home OS (Safe Mode)" {
    multiboot /boot/kernel.elf safemode
    boot
}

menuentry "Home OS (Debug Mode)" {
    multiboot /boot/kernel.elf debug
    boot
}
EOF
fi

# Check for grub-mkrescue
echo "[3/4] Building ISO..."
if command -v grub-mkrescue &> /dev/null; then
    grub-mkrescue -o HomeOS.iso iso/
    
    if [ $? -eq 0 ]; then
        echo "[4/4] ISO created successfully!"
        echo ""
        echo "Output: HomeOS.iso"
        echo "Size: $(du -h HomeOS.iso | cut -f1)"
        echo ""
        echo "To test:"
        echo "  QEMU:      qemu-system-i386 -cdrom HomeOS.iso -m 512M"
        echo "  VirtualBox: Mount HomeOS.iso as CD and boot"
    else
        echo "[ERROR] grub-mkrescue failed!"
    fi
else
    echo "[ERROR] grub-mkrescue not found!"
    echo ""
    echo "Install with:"
    echo "  Ubuntu/Debian: sudo apt install grub-pc-bin grub-common xorriso mtools"
    echo "  Arch:          sudo pacman -S grub xorriso mtools"
    echo "  Fedora:        sudo dnf install grub2-tools xorriso mtools"
fi
