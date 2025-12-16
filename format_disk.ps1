# Home OS - Disk Image Formatter
# Creates a FAT32 formatted disk image for testing

param(
    [string]$DiskImage = "disk.img",
    [int]$SizeMB = 64
)

Write-Host "Home OS Disk Formatter" -ForegroundColor Cyan
Write-Host "======================" -ForegroundColor Cyan

# Check if qemu-img exists
$qemuImg = Get-Command qemu-img -ErrorAction SilentlyContinue
if (-not $qemuImg) {
    Write-Host "Error: qemu-img not found. Please install QEMU." -ForegroundColor Red
    exit 1
}

# Create raw disk image
Write-Host "Creating $SizeMB MB disk image..." -ForegroundColor Yellow
qemu-img create -f raw $DiskImage "${SizeMB}M"

if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Failed to create disk image" -ForegroundColor Red
    exit 1
}

Write-Host "Disk image created: $DiskImage" -ForegroundColor Green
Write-Host ""
Write-Host "To format with FAT32, you can use one of these methods:" -ForegroundColor Yellow
Write-Host ""
Write-Host "Method 1: Use mkfs.fat (WSL or Linux):" -ForegroundColor Cyan
Write-Host "  wsl mkfs.fat -F 32 $DiskImage"
Write-Host ""
Write-Host "Method 2: Mount in Windows and format:" -ForegroundColor Cyan
Write-Host "  1. Open Disk Management"
Write-Host "  2. Action -> Attach VHD"
Write-Host "  3. Format as FAT32"
Write-Host ""
Write-Host "Method 3: Use mtools (if installed):" -ForegroundColor Cyan
Write-Host "  mformat -F -i $DiskImage ::"
Write-Host ""
Write-Host "For now, the disk is raw (unformatted)." -ForegroundColor Yellow
Write-Host "Home OS will detect it as 'No MBR partition table'" -ForegroundColor Yellow
