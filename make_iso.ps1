# Home OS ISO Builder
# Copyright © 2025 Romy Rianata
# Creates bootable ISO image for VirtualBox/VMware/Real Hardware

param(
    [string]$OutputName = "HomeOS.iso"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "       Home OS ISO Builder" -ForegroundColor Green
Write-Host "   Copyright 2025 Romy Rianata" -ForegroundColor Gray
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if kernel exists
if (-not (Test-Path "zig-out/bin/kernel.elf")) {
    Write-Host "[ERROR] kernel.elf not found! Run 'zig build' first." -ForegroundColor Red
    exit 1
}

# Create ISO directory structure
Write-Host "[1/4] Creating ISO structure..." -ForegroundColor Yellow
$isoDir = "iso"
$bootDir = "$isoDir/boot"
$grubDir = "$bootDir/grub"

if (-not (Test-Path $grubDir)) {
    New-Item -ItemType Directory -Path $grubDir -Force | Out-Null
}

# Copy kernel
Write-Host "[2/4] Copying kernel..." -ForegroundColor Yellow
Copy-Item "zig-out/bin/kernel.elf" "$bootDir/kernel.elf" -Force

# Check for grub-mkrescue (WSL or native)
Write-Host "[3/4] Building ISO..." -ForegroundColor Yellow

$grubMkrescue = $null

# Try WSL first
if (Get-Command wsl -ErrorAction SilentlyContinue) {
    $wslCheck = wsl which grub-mkrescue 2>$null
    if ($wslCheck) {
        $grubMkrescue = "wsl"
    }
}

if ($grubMkrescue -eq "wsl") {
    Write-Host "  Using WSL grub-mkrescue..." -ForegroundColor Gray
    
    # Convert Windows path to WSL path
    $currentPath = (Get-Location).Path -replace '\\', '/'
    $driveLetter = $currentPath.Substring(0, 1).ToLower()
    $wslPath = "/mnt/$driveLetter" + $currentPath.Substring(2)
    
    # Run grub-mkrescue in WSL
    wsl grub-mkrescue -o "$wslPath/$OutputName" "$wslPath/iso" 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[4/4] ISO created successfully!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Output: $OutputName" -ForegroundColor White
        Write-Host "Size: $((Get-Item $OutputName).Length / 1MB) MB" -ForegroundColor Gray
        Write-Host ""
        Write-Host "To test in VirtualBox:" -ForegroundColor Cyan
        Write-Host "  1. Create new VM (Type: Other, Version: Other/Unknown)" -ForegroundColor Gray
        Write-Host "  2. Set RAM to 512MB+" -ForegroundColor Gray
        Write-Host "  3. Mount $OutputName as CD/DVD" -ForegroundColor Gray
        Write-Host "  4. Boot from CD" -ForegroundColor Gray
    } else {
        Write-Host "[ERROR] grub-mkrescue failed!" -ForegroundColor Red
        Write-Host ""
        Write-Host "Alternative: Use QEMU directly:" -ForegroundColor Yellow
        Write-Host "  qemu-system-i386 -kernel zig-out/bin/kernel.elf -m 512M" -ForegroundColor Gray
    }
} else {
    Write-Host "[WARNING] grub-mkrescue not found!" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To create bootable ISO, install GRUB tools:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Option 1 - WSL (Recommended):" -ForegroundColor White
    Write-Host "  wsl --install" -ForegroundColor Gray
    Write-Host "  wsl sudo apt update" -ForegroundColor Gray
    Write-Host "  wsl sudo apt install grub-pc-bin grub-common xorriso mtools" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Option 2 - Use QEMU directly (no ISO needed):" -ForegroundColor White
    Write-Host "  qemu-system-i386 -kernel zig-out/bin/kernel.elf -m 512M -vga std" -ForegroundColor Gray
    Write-Host ""
    Write-Host "ISO structure prepared in ./iso/ folder" -ForegroundColor Green
}
