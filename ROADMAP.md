# Home OS Development Roadmap
## Vision: Privacy-First, Gaming-Ready, Developer-Friendly OS

Copyright © 2025 Romy Rianata

**Current Version: v0.33.0** | **Last Updated: March 20, 2026**

---

## PROJECT OVERVIEW

Home OS is a minimal x86 operating system written in Zig with:
- Full GUI desktop environment with 20+ applications
- Complete TCP/IP networking stack with Tor-like onion routing
- FAT32 filesystem with read/write support
- Privacy-focused design (no telemetry, MAC randomization, encryption)

---

## COMPLETED PHASES ✅

### Phase 1-5: Core Foundation ✅
- [x] Bootloader (Multiboot1 compliant)
- [x] GDT (Global Descriptor Table) & Protected Mode
- [x] IDT (Interrupt Descriptor Table) & Exception Handling
- [x] ISR (Interrupt Service Routines) - Assembly + C++
- [x] Paging & Virtual Memory (4MB PSE pages, 4GB mapped)
- [x] Heap Memory Allocator (1MB kernel heap)
- [x] PIC (Programmable Interrupt Controller) with cascade support
- [x] PIT Timer (100Hz tick, uptime tracking)
- [x] PS/2 Keyboard Driver (scancode to ASCII)
- [x] VGA Text Mode (80x25, colors, scrolling)
- [x] Serial Debug Output (COM1, live logging)

**Files:** `arch/gdt.zig`, `arch/idt.zig`, `arch/isr.zig`, `arch/pic.zig`, `arch/io.zig`, `mm/paging.zig`, `mm/heap.zig`, `drivers/pit.zig`, `drivers/keyboard.zig`, `drivers/serial.zig`, `isr.s`, `idt_setup.cpp`

### Phase 6: Filesystem ✅
- [x] Virtual Filesystem (VFS) abstraction layer
- [x] SimpleFS (in-memory read/write filesystem)
- [x] Ramdisk Backend (64KB)
- [x] TAR archive support (initrd)
- [x] Shell Commands: `ls`, `cat`, `touch`, `rm`, `write`, `echo`

**Files:** `fs/vfs.zig`, `fs/simplefs.zig`, `fs/ramdisk.zig`, `fs/tar.zig`

### Phase 7: User Mode ✅
- [x] Ring 0 ↔ Ring 3 Transitions
- [x] TSS (Task State Segment) Setup
- [x] Syscall Interface (INT 0x80)
- [x] Basic Syscalls: `sys_exit`, `sys_write`, `sys_read`, `sys_getpid`

**Files:** `arch/tss.zig`, `proc/usermode.zig`, `proc/syscall.zig`

### Phase 8: Programs ✅
- [x] Built-in User Programs (hello, counter, sysinfo)
- [x] Program Execution in Ring 3
- [x] Return to Kernel after sys_exit
- [x] ELF header parsing (basic)
- [x] Shell Command: `run`, `programs`

**Files:** `lib/programs.zig`, `lib/elf.zig`

### Phase 9: Multitasking ✅
- [x] Process Control Block (PCB)
- [x] Task States (ready, running, blocked, terminated)
- [x] Context Switching Infrastructure
- [x] Task Creation/Termination
- [x] Timer-based tick counting per task
- [x] Shell Command: `ps`
- [ ] Preemptive Round-Robin Scheduler (future)

**Files:** `proc/task.zig`

### Phase 10: Advanced Memory Management ✅
- [x] Physical Memory Manager (PMM) - Bitmap Allocator
- [x] Virtual Memory Manager (VMM) - Per-process Address Space
- [x] Page allocation tracking per task
- [x] Memory Info Command: `mem`
- [ ] Demand Paging (future)
- [ ] Copy-on-Write (future)

**Files:** `mm/pmm.zig`, `mm/vmm.zig`

### Phase 11: Storage & Persistent Filesystem ✅
- [x] ATA/IDE Driver (PIO Mode, primary master)
- [x] MBR Partition Table Parser
- [x] FAT32 Filesystem Driver (read/write)
- [x] Long filename support (8.3 format)
- [x] Shell Commands: `disk`, `lsfat`, `catfat`, `mkfat`, `writefat`, `rmfat`
- [ ] AHCI/SATA Driver (future)
- [ ] Directory creation (future)

**Files:** `drivers/ata.zig`, `fs/mbr.zig`, `fs/fat32.zig`

### Phase 12: Inter-Process Communication ✅
- [x] Pipes (4KB buffer, read/write)
- [x] Message Queues (async messaging, 16 queues)
- [x] Shared Memory (up to 64KB regions)
- [x] Semaphores (counting semaphores, 32 max)
- [x] Mutexes (binary locks, 32 max)
- [x] Shell Command: `ipc`
- [ ] Signals (future - TERM, KILL, etc.)

**Files:** `proc/ipc.zig`

### Phase 13: Networking Stack ✅
- [x] RTL8139 NIC Driver (PCI detection, TX/RX buffers)
- [x] Ethernet Frame Handling (send/receive)
- [x] ARP Protocol (cache, request/reply)
- [x] IPv4 Stack (header construction, checksum)
- [x] ICMP Protocol (ping request/reply)
- [x] UDP Protocol (sockets, send/receive)
- [x] Shell Commands: `net`, `ping`, `arp`
- [x] TCP Protocol (Phase 19)
- [x] DHCP Client (Phase 19)
- [x] DNS Resolver (Phase 19)

**Files:** `net/rtl8139.zig`, `net/ethernet.zig`, `net/arp.zig`, `net/ipv4.zig`, `net/icmp.zig`, `net/udp.zig`, `net/net.zig`

### Phase 14: Graphics & Display ✅
- [x] VBE/VESA Graphics Mode (BGA - Bochs Graphics Adapter)
- [x] PCI device scanning for VGA
- [x] Linear Framebuffer Driver (800x600x32)
- [x] Double Buffering (flicker-free rendering)
- [x] 2D Graphics Library (pixel, line, rect, circle, fill)
- [x] Font Rendering (8x8 bitmap font)
- [x] PS/2 Mouse Driver (IRQ12, 3-byte packets)
- [x] Desktop/Window Manager (windows, taskbar, cursor)
- [x] Window Interaction (close button, drag windows, focus)
- [x] Shell Commands: `gui`, `gfxtest`
- [ ] GUI Toolkit - widgets, menus, dialogs (future)

**Files:** `drivers/vbe.zig`, `drivers/graphics.zig`, `drivers/font.zig`, `drivers/mouse.zig`, `gui/desktop.zig`

### Phase 15: Audio System ✅
- [x] PC Speaker Driver (beep, tones, melodies)
- [x] Sound Blaster 16 Driver (DSP, DMA, IRQ5)
- [x] Audio Manager (unified API)
- [x] Musical note frequencies (C4-A5)
- [x] Melody playback system
- [x] Shell Commands: `beep`, `sound`, `play`
- [ ] AC97 Audio Driver (future)
- [ ] HDA (High Definition Audio) (future)
- [ ] WAV file playback (future)

**Files:** `drivers/pcspk.zig`, `drivers/sb16.zig`, `drivers/audio.zig`

### Phase 16: USB Support ✅
- [x] PCI Bus Driver (enumeration, config space)
- [x] UHCI Controller Driver (USB 1.x)
- [x] USB Core (device enumeration, descriptors)
- [x] Root Hub Port Detection
- [x] Shell Commands: `usb`, `lspci`
- [ ] EHCI Controller (USB 2.0) (future)
- [ ] USB Mass Storage (future)
- [ ] USB HID (Keyboard/Mouse) (future)

**Files:** `drivers/pci.zig`, `drivers/uhci.zig`, `drivers/usb.zig`

### Phase 17: System Improvements ✅
- [x] Real-Time Clock (RTC) Driver - CMOS date/time
- [x] Shell Commands: `date`, `time`, `reboot`, `shutdown`, `version`, `about`
- [x] GUI Taskbar Real Clock (from RTC)
- [x] System Reboot (keyboard controller reset)
- [x] System Shutdown (ACPI)
- [x] Start Menu with app launcher
- [x] Desktop Icons (My Computer, Files, Terminal) with click handling
- [x] Window Types (Calculator, Notepad, System Info, About, Terminal, File Manager)
- [x] Calculator Window UI with working buttons (+, -, *, /, =, C)
- [x] Calculator Keyboard Input Support
- [x] Notepad Window UI with text editing
- [x] Notepad Keyboard Input (type, backspace, enter)
- [x] System Info Window (shows date/time, architecture)
- [x] About Window
- [x] GUI Terminal with working shell commands
- [x] Terminal commands: help, ls, lsfat, catfat, date, time, clear, version, about, mem, uptime, exit
- [x] Larger Terminal window (500x350) with more output lines
- [x] FAT32 file reading from GUI Terminal (catfat command)
- [x] GUI Terminal scroll support (Page Up/Down, Home/End)
- [x] Extended keyboard support (arrow keys, page up/down, home/end)
- [x] Device Manager app (storage, network, display, audio, input, USB)
- [x] Task Manager app (processes, performance, memory)
- [x] Settings app (display, network, audio, security, about)
- [x] Desktop Settings icon

**Files:** `drivers/rtc.zig`, `gui/desktop.zig`, `drivers/keyboard.zig`, `drivers/pcspk.zig`, `gui/apps/devmgr.zig`, `gui/apps/taskmanager.zig`, `gui/apps/settings.zig`

### Phase 18: GUI Enhancements ✅
- [x] Window minimize button (yellow "-")
- [x] Minimize/restore from taskbar
- [x] File Manager app (browse FAT32 files)
- [x] File Manager keyboard navigation (W/S keys, R to refresh)
- [x] Click sound effects (PC Speaker)
- [x] Tab key to cycle between windows
- [x] Graphics optimization (dirty rectangle tracking)
- [x] Fast memory operations (REP STOSL/MOVSL)
- [x] Partial buffer swap (only dirty regions)
- [x] VGA backspace handling fix
- [x] Extended scancode filtering (0xE0, 0xE1)
- [x] Buffer initialization fixes (keyboard, terminal, mouse)

**Files:** `gui/desktop.zig`, `gui/window.zig`, `gui/apps/filemanager.zig`, `drivers/graphics.zig`, `lib/vga.zig`

### Phase 19: Networking Completion ✅
- [x] DHCP Client (Discover, Offer, Request, Acknowledge)
- [x] DHCP Options parsing (IP, subnet, gateway, DNS, lease time)
- [x] DNS Resolver (A record lookup)
- [x] DNS name encoding/decoding
- [x] DNS cache (16 entries)
- [x] TCP Protocol (header, flags, state machine)
- [x] TCP States (CLOSED, LISTEN, SYN_SENT, ESTABLISHED, etc.)
- [x] TCP Socket management (16 sockets)
- [x] Shell Commands: `dhcp`, `nslookup <host>`
- [x] Network stats extended (TCP sockets, DNS cache, DHCP status)

**Files:** `net/dhcp.zig`, `net/dns.zig`, `net/tcp.zig`, `net/net.zig`, `shell/commands.zig`

---

## COMPLETED PHASES (Continued) ✅

### Phase 20: Shell Refactoring & Code Organization ✅
- [x] Refactor commands.zig into modular files
- [x] cmd_file.zig - RAM filesystem commands
- [x] cmd_fat32.zig - FAT32 disk commands
- [x] cmd_system.zig - System info commands
- [x] cmd_network.zig - Network commands
- [x] cmd_audio.zig - Audio & USB commands
- [x] cmd_gui.zig - GUI & program commands
- [x] cmd_power.zig - Power management commands
- [x] Main dispatcher in commands.zig

**Files:** `shell/commands.zig`, `shell/cmd_*.zig`

### Phase 21: Cryptography Foundation ✅
- [x] Hardware RNG detection (RDRAND via CPUID)
- [x] Software PRNG fallback (xorshift128+)
- [x] Entropy mixing (TSC, PIT ticks, uptime)
- [x] SHA-256 hash implementation (full)
- [x] Secure memory wiping (volatile writes)
- [x] Constant-time comparison (timing attack prevention)
- [x] Key derivation (PBKDF2-like)
- [x] Crypto API for kernel/userspace
- [x] Shell Command: `crypto`
- [ ] AES-256 encryption/decryption (future)
- [ ] ChaCha20 stream cipher (future)

**Files:** `crypto/rng.zig`, `crypto/sha256.zig`, `crypto/crypto.zig`, `shell/cmd_system.zig`

### Phase 22: Network Security Layer ✅
- [x] Firewall (packet filtering with rules)
- [x] Firewall rules: allow/deny/drop actions
- [x] Default rules (loopback, outbound, ICMP, DNS, DHCP)
- [x] Firewall statistics (allowed/denied/dropped)
- [x] MAC address randomization
- [x] MAC address set/restore functions
- [x] TLS 1.3 record layer structure
- [x] TLS ClientHello builder with SNI
- [x] TLS session management (8 sessions)
- [x] Shell Commands: `firewall`, `security`, `macrandom`
- [ ] TLS handshake completion (future)
- [ ] Certificate parsing (X.509) (future)
- [ ] HTTPS support (future)
- [ ] DNS over HTTPS (DoH) (future)

**Files:** `net/firewall.zig`, `net/tls.zig`, `net/mac.zig`, `net/rtl8139.zig`, `shell/cmd_network.zig`

### Phase 22.5: GUI Improvements ✅
- [x] File Manager: Toolbar with Refresh button
- [x] File Manager: Path bar showing current directory
- [x] File Manager: Mouse click to select files
- [x] File Manager: Arrow key navigation (Up/Down)
- [x] File Manager: Page Up/Down, Home/End support
- [x] Notepad: Line numbers in gutter
- [x] Notepad: Status bar with character/line count
- [x] Calculator: Decimal point support
- [x] Calculator: Backspace/DEL button
- [x] Calculator: 5-row layout with wider equals button
- [x] Desktop: Double-click to open icons
- [x] Taskbar: Date display (DD/MM) next to time
- [x] Window: Maximize button (green square)
- [x] Window: Maximize/restore toggle
- [x] Window: Saved position for restore
- [x] Terminal: Command history (Up/Down arrow)
- [x] Terminal: 16 command history entries
- [x] Start Menu: Icons next to menu items
- [x] Resolution Switching: Settings → Display tab
- [x] Resolution Options: 640x480, 800x600, 1024x768, 1280x720, 1280x800, 1366x768
- [x] Auto-resize: Windows clamp to new resolution bounds
- [x] Auto-resize: Apps (Terminal, Notepad, File Manager) adapt to window size
- [x] Mouse bounds: Auto-update on resolution change
- [x] Back buffer: Supports up to 1920x1080 (Full HD ready)

**Files:** `gui/apps/filemanager.zig`, `gui/apps/notepad.zig`, `gui/apps/calculator.zig`, `gui/desktop.zig`, `gui/window.zig`, `gui/apps/terminal.zig`, `drivers/rtc.zig`, `drivers/vbe.zig`, `drivers/graphics.zig`, `gui/apps/settings.zig`

### Phase 22.6: UI Modernization ✅
- [x] Calculator: Fixed button padding and text centering
- [x] Calculator: Modern dark theme with orange operators
- [x] Calculator: 3D button effect with highlights/shadows
- [x] Window: Modern title bar with darker theme
- [x] Window: macOS-style circular control buttons (red/yellow/green)
- [x] Window: Better shadow and border styling
- [x] Taskbar: Dark theme with gradient effect
- [x] Taskbar: System tray area with clock
- [x] Taskbar: Active window indicator bar
- [x] Start Menu: Modern dark theme with blue header
- [x] Start Menu: Version display in header
- [x] File Manager: Alternating row colors
- [x] File Manager: Better folder/file icons
- [x] Terminal: Dark theme with colored prompt
- [x] Terminal: Prompt input area highlight
- [x] Notepad: Better line number gutter styling
- [x] Notepad: Improved status bar
- [x] Settings: Modern tab styling with indicator
- [x] Task Manager: Progress bar with percentage
- [x] Task Manager: Modern tab styling
- [x] Device Manager: Modern tab styling

**Files:** `gui/apps/calculator.zig`, `gui/window.zig`, `gui/desktop.zig`, `gui/apps/filemanager.zig`, `gui/apps/terminal.zig`, `gui/apps/notepad.zig`, `gui/apps/settings.zig`, `gui/apps/taskmanager.zig`, `gui/apps/devmgr.zig`

### Phase 22.7: Advanced GUI Features ✅
- [x] Desktop: Gradient wallpaper (dark/light theme)
- [x] Desktop: Theme toggle variable (dark_theme)
- [x] Taskbar: Network status icon in system tray
- [x] Settings: Theme toggle UI in Display tab (press T)
- [x] Window: Resize by dragging bottom-right corner
- [x] Window: Visual resize handle indicator
- [x] Terminal: Tab completion for commands
- [x] Terminal: Shows matching commands on multiple matches
- [x] Calculator: Memory functions (MC, MR, M-, M+)
- [x] Calculator: Memory indicator "M" when memory has value
- [x] Calculator: Keyboard shortcuts for memory (R/P/M/L)
- [x] About: Enhanced system specs display (CPU, RAM, Display, Network, Uptime)

**Files:** `gui/desktop.zig`, `gui/window.zig`, `gui/apps/settings.zig`, `gui/apps/terminal.zig`, `gui/apps/calculator.zig`, `gui/apps/sysinfo.zig`

### Phase 22.8: Performance Optimizations ✅
- [x] Font: Direct buffer access for character drawing (bypass putPixel)
- [x] Font: Early bounds checking to skip off-screen strings
- [x] Font: Optimized drawString with visibility culling
- [x] Graphics: Optimized fillRect with simplified clipping
- [x] Graphics: Smart swapBuffers - full copy if >50% dirty
- [x] Graphics: Added getDrawBufferDirect() for fast access
- [x] Desktop: Optimized cursor drawing with direct buffer writes
- [x] Desktop: Reduced frame rate (3 ticks vs 100) for smoother feel
- [x] Desktop: Unrolled desktop icon drawing loop
- [x] Desktop: Pre-computed taskbar colors to reduce allocations
- [x] Desktop: Simplified network icon drawing
- [x] Window: Reduced drawFrame calls (simplified buttons)
- [x] Window: Skip shadow if window at screen edge
- [x] Window: Simplified resize handle (single rect vs 3 lines)
- [x] Wallpaper: 8-pixel band gradient (8x faster than per-line)

**Files:** `drivers/graphics.zig`, `drivers/font.zig`, `gui/desktop.zig`, `gui/window.zig`

### Phase 22.9: Feature Enhancements (20 items) ✅
- [x] Notepad: Save to FAT32 (Ctrl+S)
- [x] Notepad: Load from FAT32 (Ctrl+O)
- [x] Notepad: Undo support (single level)
- [x] Notepad: Word wrap toggle (Ctrl+W)
- [x] File Manager: Delete files (D key)
- [x] File Manager: Create new file (N key)
- [x] File Manager: Open files in Notepad (Enter)
- [x] File Manager: Navigate into folders (Enter)
- [x] Terminal: Colored output (errors red, success green, commands cyan)
- [x] Terminal: Tab completion for commands
- [x] Calculator: Square root (Q key)
- [x] Calculator: Memory functions (MC, MR, M-, M+)
- [x] Calculator: History storage
- [x] Desktop: Icon selection highlight
- [x] Desktop: Right-click context menu
- [x] Window: Snap to edges (10px threshold)
- [x] Window: Bring to front on click
- [x] Settings: Sound volume control (+/- keys)
- [x] Settings: Mouse speed adjustment ([/] keys)
- [ ] Taskbar: Window preview on hover (deferred - complex)

**Files:** `gui/apps/notepad.zig`, `gui/apps/filemanager.zig`, `gui/apps/terminal.zig`, `gui/apps/calculator.zig`, `gui/desktop.zig`, `gui/window.zig`, `gui/apps/settings.zig`

### Phase 23.0: Major Update (25 items) ✅
**GUI/Desktop:**
- [x] Clipboard system (copy/paste module)
- [x] Notification toast messages
- [x] Screensaver (after 60s idle, bouncing text)
- [x] Keyboard shortcuts (ESC to close window)
- [x] Window title bar double-click maximize
- [ ] Taskbar clock click shows date popup
- [ ] Desktop icon drag and drop
- [ ] Window minimize animation effect

**New Apps:**
- [x] Paint app (simple drawing with colors, brush sizes)
- [x] Clock app (analog display with hour/minute/second hands)
- [x] Snake game (classic gameplay with score)
- [x] Hex viewer for files (FAT32 file hex dump)
- [x] Color picker tool (RGB sliders, hex display)

**Terminal/Shell:**
- [x] More commands (pwd, whoami, hostname, uname)
- [ ] Command output piping (basic)
- [ ] Environment variables

**System Features:**
- [x] Keyboard LED control (Caps/Num lock functions)
- [x] System event sounds (window open/close, click, error)
- [x] Boot splash screen (1 second logo display)
- [ ] Shutdown screen with message
- [x] Idle time tracking (screensaver)
- [ ] CPU usage display in Task Manager
- [x] Memory usage bar in taskbar (color-coded)
- [x] Uptime display in About dialog (already present)
- [ ] System log viewer

**Files:** `gui/desktop.zig`, `gui/apps/*.zig`, `gui/clipboard.zig`, `gui/notification.zig`, `gui/screensaver.zig`, `shell/cmd_executor.zig`

### Phase 24.0: Major Improvements ✅
**GUI & UX:**
- [x] Window Snapping - Snap windows to screen edges (left/right half, maximize on top)
- [x] Snap preview overlay while dragging
- [x] Boot Splash Screen - Animated progress bar with logo
- [x] System Tray Icons - Clickable (memory opens Task Manager, network opens Ping)
- [x] Keyboard Shortcuts Manager - F1-F8 for quick app launch

**Filesystem & Storage:**
- [x] File Copy/Paste - C/X/V keys in File Manager
- [x] Clipboard status indicator in File Manager

**Networking:**
- [x] HTTP Client - Simple HTTP/1.1 GET requests
- [x] Ping GUI - Visual ping tool with response time graph

**System:**
- [x] System Logs Viewer - GUI app for kernel logs
- [x] Function key support (F1-F12) in keyboard driver

**New Apps:**
- [x] Log Viewer app (colored log levels, scrollable)
- [x] Ping Tool app (visual graph, statistics)
- [x] File Properties dialog (size, attributes, cluster)

**Files:** `gui/desktop.zig`, `gui/window.zig`, `gui/apps/filemanager.zig`, `gui/apps/logviewer.zig`, `gui/apps/pingui.zig`, `gui/apps/fileprops.zig`, `net/http.zig`, `drivers/keyboard.zig`

### Phase 24.6: Settings Persistence ✅
**Configuration System:**
- [x] SystemConfig struct with magic, version, checksum
- [x] CONFIG.DAT file on FAT32 root directory
- [x] Auto-load settings on boot
- [x] Auto-save when settings change

**Persisted Settings:**
- [x] Display resolution index
- [x] Dark/Light theme preference
- [x] Volume level (0-10)
- [x] Mouse speed (1-10)
- [x] Beep enabled flag

**Integration:**
- [x] Settings app saves on change (theme, volume, mouse speed, resolution)
- [x] Desktop loads config on init
- [x] Checksum validation for data integrity

**Files:** `gui/config.zig`, `gui/apps/settings.zig`, `gui/desktop.zig`

### Phase 24.7: Major Update (20 items) ✅
**Snake Game:**
- [x] High score tracking (persists during session)
- [x] Speed levels 1-5 (+/- keys)
- [x] Speed affects game difficulty

**Paint App:**
- [x] Line tool (L key, click start/end)
- [x] Rectangle tool (R key, click corners)
- [x] Eraser tool (E key)
- [x] Tool indicator in toolbar

**Clock App:**
- [x] Stopwatch mode (M key to toggle)
- [x] Start/Stop (Space key)
- [x] Reset (R key)
- [x] MM:SS.ms display format

**Terminal:**
- [x] Ctrl+L to clear screen

**Desktop:**
- [x] Wallpaper color options (7 styles)
- [x] F12 minimize all windows (show desktop)
- [x] minimizeAll() function

**Settings:**
- [x] Wallpaper style selector (/ key to cycle)
- [x] Display wallpaper name

**GUI Fixes:**
- [x] Ping Tool responsive stats layout
- [x] Task Manager compact columns
- [x] Bounds checking for text overflow

**Files:** `gui/apps/snake.zig`, `gui/apps/paint.zig`, `gui/apps/clock.zig`, `gui/apps/terminal.zig`, `gui/desktop.zig`, `gui/apps/settings.zig`, `gui/apps/pingui.zig`, `gui/apps/taskmanager.zig`

### Phase 24.8: Feature Update (20 items) ✅
**Snake Game:**
- [x] Pause game (P key)
- [x] Wrap-around mode toggle (W key when paused)
- [x] Pause indicator display

**Paint App:**
- [x] Fill tool (F key) - flood fill with current color
- [x] Stack-based flood fill (non-recursive, safe)
- [x] Tool indicator shows Fill mode

**Clock App:**
- [x] Alarm feature (A key to toggle mode)
- [x] Set alarm hour (+/- keys)
- [x] Set alarm minute ([/] keys)
- [x] Enable/disable alarm (E key)
- [x] Alarm status display

**Terminal:**
- [x] Command aliases (ll, dir, cat, rm, cls, quit, etc.)
- [x] Alias resolution before execution

**File Manager:**
- [x] Sort by name/size toggle (T key)
- [x] Sort indicator in column header
- [x] Bubble sort implementation

**Desktop:**
- [x] Window cascade (F10) - staggered arrangement
- [x] Window tile (F11) - grid arrangement
- [x] Dynamic grid calculation for tile

**System Info:**
- [x] Disk usage display (MB)

**Device Manager:**
- [x] Dynamic VBE resolution display (was hardcoded)

**Task Manager:**
- [x] Windows tab shows GUI windows
- [x] Real CPU usage tracking

**Version:**
- [x] Updated to v0.27.0

**Files:** `gui/apps/snake.zig`, `gui/apps/paint.zig`, `gui/apps/clock.zig`, `gui/apps/terminal.zig`, `gui/apps/filemanager.zig`, `gui/desktop.zig`, `gui/apps/sysinfo.zig`, `gui/apps/devmgr.zig`, `gui/apps/taskmanager.zig`

### Phase 24.9: Feature Update (20 items) ✅
**Notepad:**
- [x] Find text (Ctrl+F) with find bar display
- [x] Find mode variables and doFind() function

**Calculator:**
- [x] Power function (^ key for x^2)
- [x] Inverse function (I key for 1/x)

**Task Manager:**
- [x] Network tab added (5th tab)
- [x] drawNetwork() function with IP, MAC, packets, firewall status

**Paint:**
- [x] Circle tool (O key)
- [x] drawCircle() and setPixelSafe() functions
- [x] Canvas size indicator (200x150)

**Snake:**
- [x] Score multiplier based on speed level

**Clock:**
- [x] 12/24 hour toggle (H key)

**Desktop:**
- [x] Wallpaper cycle (F9 key)
- [x] Restore all windows (restoreAll function)

**Terminal:**
- [x] History command (show history)
- [x] History clear command (history -c)

**File Manager:**
- [x] Total size display in status bar
- [x] getTotalSize() function

**System Info:**
- [x] Network info (IP address display)
- [x] MAC address display

**Version:**
- [x] Updated to v0.28.0

**Files:** `gui/apps/notepad.zig`, `gui/apps/calculator.zig`, `gui/apps/taskmanager.zig`, `gui/apps/paint.zig`, `gui/apps/snake.zig`, `gui/apps/clock.zig`, `gui/desktop.zig`, `gui/apps/terminal.zig`, `gui/apps/filemanager.zig`, `gui/apps/sysinfo.zig`

### Phase 25.0: Major Feature Update ✅
**New Game - Tetris:**
- [x] Classic Tetris gameplay with 7 tetromino shapes (I, O, T, S, Z, J, L)
- [x] Arrow keys for movement (Left/Right/Down)
- [x] Up arrow or Z key to rotate
- [x] Space bar for hard drop
- [x] Score system (100/300/500/800 points for 1-4 lines)
- [x] Level progression (speed increases every 10 lines)
- [x] Next piece preview
- [x] Pause functionality (P key)
- [x] Game over detection with collision checking
- [x] Desktop icon for Tetris

**Shutdown Screen:**
- [x] Nice shutdown screen with progress bar
- [x] "Shutting down..." message with animation
- [x] Copyright notice display
- [x] Smooth transition before power off

**Date Popup (Taskbar Clock):**
- [x] Click on clock area shows date popup
- [x] Full date display (Day, DD Month YYYY)
- [x] Full time display (HH:MM:SS)
- [x] Day of week calculation
- [x] Month name display
- [x] Click anywhere to close popup

**RTC Improvements:**
- [x] getFullDateString() - "DD Month YYYY" format
- [x] getFullTimeString() - "HH:MM:SS" format
- [x] getDayOfWeek() - Returns day name (Monday-Sunday)
- [x] getMonthName() - Returns month name (January-December)

**Bug Fixes:**
- [x] Task Manager Network tab state persistence (moved to Window struct)
- [x] Cleaned up verbose debug logs (IDT, ISR, Mouse, PIC)

**Version:**
- [x] Updated to v0.29.0

**Files:** `gui/apps/tetris.zig`, `gui/desktop.zig`, `gui/window.zig`, `drivers/rtc.zig`, `gui/apps/taskmanager.zig`, `idt_setup.cpp`, `arch/isr.zig`

### Phase 26: Onion Routing (Tor-like) ✅
- [x] SOCKS5 proxy implementation (protocol structures, client)
- [x] Onion routing protocol (cells, encryption layers)
- [x] Circuit building (3-hop minimum)
- [x] Directory server communication (demo nodes)
- [x] Entry/Middle/Exit node selection (random selection)
- [x] Traffic encryption layers (XOR-based, placeholder for AES)
- [x] .onion address resolution (basic)
- [x] Tor control protocol (enable/disable/newcircuit)
- [x] Shell Commands: `tor`, `circuit`
- [x] Stream management (16 streams per circuit)
- [x] Bootstrap progress tracking

**Version:**
- [x] Updated to v0.31.0

**Files:** `net/socks5.zig`, `net/onion.zig`, `net/circuit.zig`, `net/tor.zig`, `shell/cmd_network.zig`, `kernel.zig`

### Phase 27: Privacy Browser (HomeBrowser) ✅
- [x] HTTP/1.1 client implementation (existing)
- [x] HTML parser (basic tags: h1-h3, p, a, br, hr, li, div, span)
- [x] Text-based rendering engine
- [x] GUI browser window with toolbar
- [x] URL bar and navigation (Enter to go)
- [x] Bookmarks (in-memory, default sites)
- [x] Privacy mode (no history by default)
- [x] Tor integration toggle (T key or click TOR button)
- [x] Link navigation (Up/Down arrows, Enter to follow)
- [x] Page scrolling (PgUp/PgDn)
- [x] Desktop icon for Browser
- [x] Start Menu entry for HomeBrowser
- [x] HTML entity decoding (&lt; &gt; &amp; &nbsp; &quot;)
- [ ] CSS parser (future)
- [ ] Search engine selection (future)
- [ ] Shell Commands: `browse`, `wget` (future)

**Version:**
- [x] Updated to v0.33.0

**Files:** `net/http.zig`, `browser/html.zig`, `gui/apps/browser.zig`, `gui/desktop.zig`, `gui/window.zig`

---

## UPCOMING PHASES 🚀

### Phase 28: Privacy Hardening
- [ ] Memory encryption (RAM scrambling)
- [ ] ASLR (Address Space Layout Randomization)
- [ ] Stack canaries (buffer overflow protection)
- [ ] NX bit enforcement (no-execute pages)
- [ ] Secure boot chain verification
- [ ] Anti-forensics (secure deletion)
- [ ] Encrypted swap space
- [ ] Process isolation (sandboxing)
- [ ] Syscall filtering (allowlist)
- [ ] Audit logging (optional)
- [ ] Panic wipe (emergency data destruction)
- [ ] Shell Commands: `secure`, `wipe`, `audit`

**Files:** `security/aslr.zig`, `security/canary.zig`, `security/sandbox.zig`, `security/audit.zig`

---

## PRIVACY PHILOSOPHY 🔒

Home OS is built with **freedom and democracy** in mind:

1. **No Telemetry** - Zero data collection, ever
2. **No Backdoors** - Open source, auditable code
3. **Encryption by Default** - All network traffic encrypted
4. **Anonymity Option** - Built-in Tor-like routing
5. **Minimal Fingerprint** - Reduce tracking vectors
6. **User Control** - You own your data completely
7. **Plausible Deniability** - Hidden volumes support (future)

### Threat Model
- Protects against: ISP surveillance, corporate tracking, mass surveillance
- Tor routing makes traffic analysis extremely difficult
- No persistent identifiers across sessions
- MAC randomization prevents hardware tracking

---

## GAMING FEATURES 🎮

### Phase G1: Graphics Acceleration
- [ ] Basic GPU Driver (SVGA)
- [ ] Hardware Acceleration
- [ ] OpenGL Software Renderer
- [ ] Vulkan Support (long-term)

### Phase G2: Input & Controllers
- [ ] Gamepad/Joystick Support
- [ ] Low-Latency Input
- [ ] Input Mapping

### Phase G3: Performance
- [ ] Real-Time Scheduling
- [ ] CPU Affinity
- [ ] Memory Huge Pages
- [ ] I/O Prioritization

### Phase G4: Compatibility
- [ ] DOS Emulation Layer
- [ ] Wine-like Compatibility (long-term)
- [ ] Retro Game Support

---

## DEVELOPER FEATURES 💻

### Phase D1: Development Tools
- [ ] Built-in Shell (bash-like)
- [ ] Text Editor (vi-like)
- [ ] Compiler Toolchain (GCC/Clang port)
- [ ] Debugger (GDB port)
- [ ] Package Manager

### Phase D2: Programming Languages
- [ ] C Runtime Library (libc)
- [ ] C++ Support
- [ ] Zig Standard Library
- [ ] Python Interpreter (long-term)
- [ ] Rust Support (long-term)

### Phase D3: System Programming
- [ ] Kernel Module Support
- [ ] Driver Development Kit
- [ ] System Call Documentation
- [ ] API Reference

### Phase D4: Networking Tools
- [ ] SSH Server/Client
- [ ] HTTP Server
- [ ] Git Support
- [ ] curl/wget equivalents

---

## SHELL COMMANDS REFERENCE

| Command | Description |
|---------|-------------|
| `help` | Show available commands |
| `clear` | Clear screen |
| `uptime` | Show system uptime |
| `mem` | Memory information |
| `disk` | Disk information |
| `ps` | Process list |
| `ls` | List RAM filesystem |
| `cat <file>` | Read file from RAM |
| `touch <file>` | Create empty file |
| `rm <file>` | Delete file |
| `write <file> <text>` | Write to file |
| `echo <text>` | Print text |
| `lsfat` | List FAT32 root directory |
| `catfat <file>` | Read FAT32 file |
| `mkfat <file>` | Create FAT32 file |
| `writefat <file> <text>` | Write to FAT32 file |
| `rmfat <file>` | Delete FAT32 file |
| `net` | Network status |
| `ping <ip>` | Ping IP address |
| `arp` | Show ARP cache |
| `dhcp` | DHCP client status/request |
| `nslookup <host>` | DNS lookup |
| `ipc` | IPC resources status |
| `run <program>` | Run user program |
| `programs` | List available programs |
| `gui` | Enter GUI mode |
| `gfxtest` | Graphics test |
| `beep` | Play a beep sound |
| `sound` | Audio status |
| `play <name>` | Play sound (demo/startup/error) |
| `usb` | USB status and devices |
| `lspci` | List PCI devices |
| `date` | Show current date |
| `time` | Show current time |
| `reboot` | Reboot system |
| `shutdown` | Shutdown system |
| `version` | Show OS version |
| `about` | About Home OS |
| `crypto` | Cryptography status & demo |
| `firewall` | Firewall status & rules |
| `security` | Network security status |
| `macrandom` | Randomize MAC address |

---

## BOOTABLE ISO 💿

Home OS can be built as a bootable ISO for VirtualBox, VMware, or real hardware.

### Building ISO

**Windows (with WSL):**
```powershell
# Install WSL tools first
wsl sudo apt install grub-pc-bin grub-common xorriso mtools

# Build ISO
.\make_iso.ps1
```

**Linux:**
```bash
# Install tools
sudo apt install grub-pc-bin grub-common xorriso mtools

# Build ISO
chmod +x make_iso.sh
./make_iso.sh
```

### Testing ISO

**QEMU:**
```bash
qemu-system-i386 -cdrom HomeOS.iso -m 512M -vga std
```

**VirtualBox:**
1. Create new VM (Type: Other, Version: Other/Unknown)
2. Set RAM to 512MB+
3. Mount HomeOS.iso as CD/DVD
4. Boot from CD

### Boot Process
```
BIOS/UEFI → GRUB Bootloader → Home OS Kernel → Shell/GUI
```

---

## ARCHITECTURE

```
┌─────────────────────────────────────────────────────────────┐
│                     USER APPLICATIONS                        │
│  (Games, Browsers, Dev Tools, System Utils)                 │
├─────────────────────────────────────────────────────────────┤
│                     SYSTEM LIBRARIES                         │
│  (libc, libm, libpthread, Graphics, Audio, Network)         │
├─────────────────────────────────────────────────────────────┤
│                     SYSTEM SERVICES                          │
│  (Window Manager, Audio Daemon, Network Manager)            │
├─────────────────────────────────────────────────────────────┤
│                     KERNEL SPACE                             │
│  ┌─────────┬─────────┬─────────┬─────────┬─────────┐       │
│  │ Process │ Memory  │   VFS   │ Network │ Device  │       │
│  │ Manager │ Manager │         │  Stack  │ Drivers │       │
│  └─────────┴─────────┴─────────┴─────────┴─────────┘       │
│  ┌─────────────────────────────────────────────────┐       │
│  │              Hardware Abstraction               │       │
│  └─────────────────────────────────────────────────┘       │
├─────────────────────────────────────────────────────────────┤
│                       HARDWARE                               │
│  (CPU, RAM, Storage, GPU, NIC, USB, Audio)                  │
└─────────────────────────────────────────────────────────────┘
```

---

## SOURCE CODE STRUCTURE

```
HomeOS/src/
├── arch/           # Architecture-specific (x86)
│   ├── gdt.zig     # Global Descriptor Table
│   ├── idt.zig     # Interrupt Descriptor Table
│   ├── isr.zig     # Interrupt Service Routines
│   ├── pic.zig     # Programmable Interrupt Controller
│   ├── tss.zig     # Task State Segment
│   └── io.zig      # Port I/O
├── drivers/        # Hardware Drivers
│   ├── ata.zig     # ATA/IDE disk
│   ├── keyboard.zig
│   ├── mouse.zig   # PS/2 mouse
│   ├── pit.zig     # Timer
│   ├── serial.zig  # COM1 debug
│   ├── vbe.zig     # VBE graphics
│   ├── graphics.zig # 2D drawing
│   ├── font.zig    # Bitmap font
│   ├── pcspk.zig   # PC Speaker
│   ├── sb16.zig    # Sound Blaster 16
│   ├── audio.zig   # Audio manager
│   ├── pci.zig     # PCI bus driver
│   ├── uhci.zig    # UHCI USB controller
│   ├── usb.zig     # USB core
│   └── rtc.zig     # Real-time clock
├── fs/             # Filesystems
│   ├── vfs.zig     # Virtual FS
│   ├── fat32.zig   # FAT32 driver
│   ├── mbr.zig     # MBR parser
│   ├── ramdisk.zig # RAM disk
│   └── simplefs.zig
├── gui/            # Graphical Interface
│   ├── desktop.zig # Desktop, taskbar, icons
│   ├── window.zig  # Window struct & frame
│   └── apps/       # GUI Applications
│       ├── calculator.zig
│       ├── notepad.zig
│       ├── terminal.zig
│       └── sysinfo.zig
├── shell/          # Shell & Commands
│   ├── shell.zig   # Shell input processing
│   ├── commands.zig # Command dispatcher
│   ├── cmd_file.zig # RAM file commands
│   ├── cmd_fat32.zig # FAT32 commands
│   ├── cmd_system.zig # System commands
│   ├── cmd_network.zig # Network commands
│   ├── cmd_audio.zig # Audio/USB commands
│   ├── cmd_gui.zig # GUI commands
│   └── cmd_power.zig # Power commands
├── lib/            # Libraries
│   ├── vga.zig     # VGA text mode driver
│   ├── elf.zig     # ELF parser
│   └── programs.zig # Built-in programs
├── mm/             # Memory Management
│   ├── paging.zig  # Virtual memory
│   ├── pmm.zig     # Physical memory
│   ├── vmm.zig     # VM manager
│   └── heap.zig    # Kernel heap
├── net/            # Networking
│   ├── rtl8139.zig # NIC driver
│   ├── ethernet.zig
│   ├── arp.zig
│   ├── ipv4.zig
│   ├── icmp.zig
│   ├── udp.zig
│   └── net.zig     # Network API
├── proc/           # Process Management
│   ├── task.zig    # Task/process
│   ├── syscall.zig # System calls
│   ├── usermode.zig # Ring 3
│   └── ipc.zig     # IPC primitives
├── kernel.zig      # Main kernel entry & init
├── isr.s           # Assembly ISRs
└── idt_setup.cpp   # C++ IDT setup
```

---

## NEXT IMMEDIATE STEPS

1. **Phase 28** - Privacy Hardening (ASLR, stack canaries, sandboxing)
2. **Phase 29** - Advanced Browser (CSS parser, JavaScript engine)
3. **Phase 30** - Package Manager & App Store
4. **Phase 31** - Multi-user Support

---

## BUILD & RUN

```bash
# Build
cd HomeOS
zig build

# Run with QEMU (basic)
qemu-system-i386 -kernel zig-out/bin/kernel.elf -m 512M \
  -netdev user,id=net0 -device rtl8139,netdev=net0 \
  -hda disk.img -serial stdio -vga std

# Run with Audio (PC Speaker)
qemu-system-i386 -kernel zig-out/bin/kernel.elf -m 512M \
  -netdev user,id=net0 -device rtl8139,netdev=net0 \
  -hda disk.img -serial stdio -vga std \
  -audiodev dsound,id=audio0 -machine pcspk-audiodev=audio0

# Or use the convenience script (Windows)
run.bat
```

---

## NOTES

- Written in Zig with some C++ and Assembly
- Targets x86 (i386) architecture
- Runs on QEMU with Multiboot
- Focus on stability over features
- Privacy and security from the ground up

