@echo off
REM Home OS Build Script for Windows
REM Copyright © 2025 Romy Rianata - Home OS

echo ========================================
echo        Home OS Build System
echo   Copyright (C) 2025 Romy Rianata
echo ========================================
echo.

REM Check if Zig is available
where zig >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo ERROR: Zig not found in PATH!
    echo Please ensure Zig is installed and added to PATH.
    exit /b 1
)

echo [1/3] Cleaning previous build...
if exist zig-out rmdir /s /q zig-out
if exist .zig-cache rmdir /s /q .zig-cache

echo [2/3] Building kernel...
zig build -Doptimize=ReleaseSmall

if %ERRORLEVEL% neq 0 (
    echo.
    echo ERROR: Build failed!
    exit /b 1
)

echo [3/3] Build complete!
echo.
echo Kernel binary: zig-out\bin\kernel.elf
echo.
echo To test in QEMU (from MSYS2 MinGW64 shell):
echo   qemu-system-x86_64 -kernel zig-out/bin/kernel.elf -m 512M
echo.
echo To create bootable ISO, run: build_iso.sh in MSYS2
