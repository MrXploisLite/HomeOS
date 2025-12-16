# Home OS - Create FAT32 Disk Image
# Creates a properly formatted FAT32 disk image

$diskFile = "disk.img"
$diskSizeMB = 64
$diskSizeBytes = $diskSizeMB * 1024 * 1024
$sectorSize = 512
$totalSectors = $diskSizeBytes / $sectorSize

Write-Host "Creating FAT32 disk image: $diskFile ($diskSizeMB MB)" -ForegroundColor Cyan

# Create empty disk
$bytes = New-Object byte[] $diskSizeBytes
$stream = [System.IO.File]::Create($diskFile)

# ============================================================================
# MBR (Master Boot Record) - Sector 0
# ============================================================================

# Partition 1 entry at offset 446 (0x1BE)
# Boot flag
$bytes[446] = 0x80  # Bootable

# CHS start (not used with LBA)
$bytes[447] = 0x00  # Head
$bytes[448] = 0x01  # Sector
$bytes[449] = 0x00  # Cylinder

# Partition type: FAT32 LBA
$bytes[450] = 0x0C

# CHS end (not used with LBA)
$bytes[451] = 0xFE  # Head
$bytes[452] = 0xFF  # Sector
$bytes[453] = 0xFF  # Cylinder

# LBA start (sector 2048 = 1MB offset for alignment)
$lbaStart = 2048
$bytes[454] = [byte]($lbaStart -band 0xFF)
$bytes[455] = [byte](($lbaStart -shr 8) -band 0xFF)
$bytes[456] = [byte](($lbaStart -shr 16) -band 0xFF)
$bytes[457] = [byte](($lbaStart -shr 24) -band 0xFF)

# Partition size in sectors
$partitionSectors = $totalSectors - $lbaStart
$bytes[458] = [byte]($partitionSectors -band 0xFF)
$bytes[459] = [byte](($partitionSectors -shr 8) -band 0xFF)
$bytes[460] = [byte](($partitionSectors -shr 16) -band 0xFF)
$bytes[461] = [byte](($partitionSectors -shr 24) -band 0xFF)

# MBR signature
$bytes[510] = 0x55
$bytes[511] = 0xAA

# ============================================================================
# FAT32 Boot Sector - Sector 2048 (partition start)
# ============================================================================

$bootSectorOffset = $lbaStart * $sectorSize

# Jump instruction
$bytes[$bootSectorOffset + 0] = 0xEB
$bytes[$bootSectorOffset + 1] = 0x58
$bytes[$bootSectorOffset + 2] = 0x90

# OEM Name "HOMEOS  "
$oemName = [System.Text.Encoding]::ASCII.GetBytes("HOMEOS  ")
[Array]::Copy($oemName, 0, $bytes, $bootSectorOffset + 3, 8)

# Bytes per sector (512)
$bytes[$bootSectorOffset + 11] = 0x00
$bytes[$bootSectorOffset + 12] = 0x02

# Sectors per cluster (8 = 4KB clusters)
$bytes[$bootSectorOffset + 13] = 0x08

# Reserved sectors (32)
$reservedSectors = 32
$bytes[$bootSectorOffset + 14] = [byte]($reservedSectors -band 0xFF)
$bytes[$bootSectorOffset + 15] = [byte](($reservedSectors -shr 8) -band 0xFF)

# Number of FATs (2)
$bytes[$bootSectorOffset + 16] = 0x02

# Root entry count (0 for FAT32)
$bytes[$bootSectorOffset + 17] = 0x00
$bytes[$bootSectorOffset + 18] = 0x00

# Total sectors 16-bit (0 for FAT32)
$bytes[$bootSectorOffset + 19] = 0x00
$bytes[$bootSectorOffset + 20] = 0x00

# Media type (0xF8 = hard disk)
$bytes[$bootSectorOffset + 21] = 0xF8

# FAT size 16-bit (0 for FAT32)
$bytes[$bootSectorOffset + 22] = 0x00
$bytes[$bootSectorOffset + 23] = 0x00

# Sectors per track
$bytes[$bootSectorOffset + 24] = 0x3F
$bytes[$bootSectorOffset + 25] = 0x00

# Number of heads
$bytes[$bootSectorOffset + 26] = 0xFF
$bytes[$bootSectorOffset + 27] = 0x00

# Hidden sectors (partition start)
$bytes[$bootSectorOffset + 28] = [byte]($lbaStart -band 0xFF)
$bytes[$bootSectorOffset + 29] = [byte](($lbaStart -shr 8) -band 0xFF)
$bytes[$bootSectorOffset + 30] = [byte](($lbaStart -shr 16) -band 0xFF)
$bytes[$bootSectorOffset + 31] = [byte](($lbaStart -shr 24) -band 0xFF)

# Total sectors 32-bit
$bytes[$bootSectorOffset + 32] = [byte]($partitionSectors -band 0xFF)
$bytes[$bootSectorOffset + 33] = [byte](($partitionSectors -shr 8) -band 0xFF)
$bytes[$bootSectorOffset + 34] = [byte](($partitionSectors -shr 16) -band 0xFF)
$bytes[$bootSectorOffset + 35] = [byte](($partitionSectors -shr 24) -band 0xFF)

# FAT32 specific fields

# FAT size 32-bit (calculate: (total_sectors - reserved - root_sectors) / (cluster_size/4 + num_fats))
# Simplified: ~128 sectors for 64MB disk
$fatSize = 128
$bytes[$bootSectorOffset + 36] = [byte]($fatSize -band 0xFF)
$bytes[$bootSectorOffset + 37] = [byte](($fatSize -shr 8) -band 0xFF)
$bytes[$bootSectorOffset + 38] = [byte](($fatSize -shr 16) -band 0xFF)
$bytes[$bootSectorOffset + 39] = [byte](($fatSize -shr 24) -band 0xFF)

# Extended flags
$bytes[$bootSectorOffset + 40] = 0x00
$bytes[$bootSectorOffset + 41] = 0x00

# Filesystem version
$bytes[$bootSectorOffset + 42] = 0x00
$bytes[$bootSectorOffset + 43] = 0x00

# Root cluster (2)
$bytes[$bootSectorOffset + 44] = 0x02
$bytes[$bootSectorOffset + 45] = 0x00
$bytes[$bootSectorOffset + 46] = 0x00
$bytes[$bootSectorOffset + 47] = 0x00

# FSInfo sector (1)
$bytes[$bootSectorOffset + 48] = 0x01
$bytes[$bootSectorOffset + 49] = 0x00

# Backup boot sector (6)
$bytes[$bootSectorOffset + 50] = 0x06
$bytes[$bootSectorOffset + 51] = 0x00

# Reserved (12 bytes)
# Already zero

# Drive number
$bytes[$bootSectorOffset + 64] = 0x80

# Reserved
$bytes[$bootSectorOffset + 65] = 0x00

# Boot signature
$bytes[$bootSectorOffset + 66] = 0x29

# Volume ID
$bytes[$bootSectorOffset + 67] = 0x12
$bytes[$bootSectorOffset + 68] = 0x34
$bytes[$bootSectorOffset + 69] = 0x56
$bytes[$bootSectorOffset + 70] = 0x78

# Volume label "HOMEOS     "
$volLabel = [System.Text.Encoding]::ASCII.GetBytes("HOMEOS     ")
[Array]::Copy($volLabel, 0, $bytes, $bootSectorOffset + 71, 11)

# Filesystem type "FAT32   "
$fsType = [System.Text.Encoding]::ASCII.GetBytes("FAT32   ")
[Array]::Copy($fsType, 0, $bytes, $bootSectorOffset + 82, 8)

# Boot sector signature
$bytes[$bootSectorOffset + 510] = 0x55
$bytes[$bootSectorOffset + 511] = 0xAA

# ============================================================================
# FAT Tables - Initialize first entries
# ============================================================================

$fat1Offset = ($lbaStart + $reservedSectors) * $sectorSize
$fat2Offset = $fat1Offset + ($fatSize * $sectorSize)

# FAT entry 0: Media type
$bytes[$fat1Offset + 0] = 0xF8
$bytes[$fat1Offset + 1] = 0xFF
$bytes[$fat1Offset + 2] = 0xFF
$bytes[$fat1Offset + 3] = 0x0F

# FAT entry 1: End of chain marker
$bytes[$fat1Offset + 4] = 0xFF
$bytes[$fat1Offset + 5] = 0xFF
$bytes[$fat1Offset + 6] = 0xFF
$bytes[$fat1Offset + 7] = 0x0F

# FAT entry 2: Root directory (end of chain)
$bytes[$fat1Offset + 8] = 0xFF
$bytes[$fat1Offset + 9] = 0xFF
$bytes[$fat1Offset + 10] = 0xFF
$bytes[$fat1Offset + 11] = 0x0F

# Copy to FAT2
[Array]::Copy($bytes, $fat1Offset, $bytes, $fat2Offset, 12)

# ============================================================================
# Root Directory - Create volume label entry and test files
# ============================================================================

$dataStartSector = $lbaStart + $reservedSectors + (2 * $fatSize)
$rootDirOffset = $dataStartSector * $sectorSize
$sectorsPerCluster = 8

# Volume label entry (entry 0)
$volLabelEntry = [System.Text.Encoding]::ASCII.GetBytes("HOMEOS     ")
[Array]::Copy($volLabelEntry, 0, $bytes, $rootDirOffset, 11)
$bytes[$rootDirOffset + 11] = 0x08  # Volume label attribute

# Test file 1: README.TXT (entry 1, 32 bytes offset)
$entry1Offset = $rootDirOffset + 32
$fileName1 = [System.Text.Encoding]::ASCII.GetBytes("README  TXT")
[Array]::Copy($fileName1, 0, $bytes, $entry1Offset, 11)
$bytes[$entry1Offset + 11] = 0x20  # Archive attribute
# Cluster 3 (low word at offset 26-27)
$bytes[$entry1Offset + 26] = 0x03
$bytes[$entry1Offset + 27] = 0x00
# File size: 45 bytes
$fileSize1 = 45
$bytes[$entry1Offset + 28] = [byte]($fileSize1 -band 0xFF)
$bytes[$entry1Offset + 29] = [byte](($fileSize1 -shr 8) -band 0xFF)
$bytes[$entry1Offset + 30] = 0x00
$bytes[$entry1Offset + 31] = 0x00

# Test file 2: HELLO.TXT (entry 2, 64 bytes offset)
$entry2Offset = $rootDirOffset + 64
$fileName2 = [System.Text.Encoding]::ASCII.GetBytes("HELLO   TXT")
[Array]::Copy($fileName2, 0, $bytes, $entry2Offset, 11)
$bytes[$entry2Offset + 11] = 0x20  # Archive attribute
# Cluster 4 (low word at offset 26-27)
$bytes[$entry2Offset + 26] = 0x04
$bytes[$entry2Offset + 27] = 0x00
# File size: 26 bytes
$fileSize2 = 26
$bytes[$entry2Offset + 28] = [byte]($fileSize2 -band 0xFF)
$bytes[$entry2Offset + 29] = [byte](($fileSize2 -shr 8) -band 0xFF)
$bytes[$entry2Offset + 30] = 0x00
$bytes[$entry2Offset + 31] = 0x00

# Update FAT entries for clusters 3 and 4 (end of chain)
# Cluster 3 at FAT offset 12
$bytes[$fat1Offset + 12] = 0xFF
$bytes[$fat1Offset + 13] = 0xFF
$bytes[$fat1Offset + 14] = 0xFF
$bytes[$fat1Offset + 15] = 0x0F

# Cluster 4 at FAT offset 16
$bytes[$fat1Offset + 16] = 0xFF
$bytes[$fat1Offset + 17] = 0xFF
$bytes[$fat1Offset + 18] = 0xFF
$bytes[$fat1Offset + 19] = 0x0F

# Copy updated FAT to FAT2
[Array]::Copy($bytes, $fat1Offset, $bytes, $fat2Offset, 20)

# ============================================================================
# Write file data to clusters
# ============================================================================

# Cluster 3 data (README.TXT content)
$cluster3Offset = ($dataStartSector + $sectorsPerCluster) * $sectorSize  # Cluster 3 = root + 1 cluster
$readme = [System.Text.Encoding]::ASCII.GetBytes("Welcome to Home OS!`nFAT32 filesystem works!`n")
[Array]::Copy($readme, 0, $bytes, $cluster3Offset, $readme.Length)

# Cluster 4 data (HELLO.TXT content)
$cluster4Offset = ($dataStartSector + (2 * $sectorsPerCluster)) * $sectorSize  # Cluster 4 = root + 2 clusters
$hello = [System.Text.Encoding]::ASCII.GetBytes("Hello from FAT32 disk!`n")
[Array]::Copy($hello, 0, $bytes, $cluster4Offset, $hello.Length)

# Write to file
$stream.Write($bytes, 0, $bytes.Length)
$stream.Close()

Write-Host "Done! Created $diskFile with:" -ForegroundColor Green
Write-Host "  - MBR partition table" -ForegroundColor White
Write-Host "  - FAT32 partition (starting at sector $lbaStart)" -ForegroundColor White
Write-Host "  - Volume label: HOMEOS" -ForegroundColor White
Write-Host ""
Write-Host "Run QEMU with: qemu-system-i386 -kernel zig-out/bin/kernel.elf -m 512M -serial stdio -drive file=disk.img,format=raw" -ForegroundColor Yellow
