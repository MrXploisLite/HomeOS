# Home OS
**Copyright © 2025 Romy Rianata**

A minimal x86 operating system written in Zig, powered by **Ciko Kernel**.

## 🎯 Project Vision

Home OS is a personal operating system running on the **Ciko Kernel**, designed for:
- **Extreme Privacy**: No telemetry, no tracking, built-in Tor-like routing
- **Maximum Speed**: Minimal overhead, direct hardware access
- **High Stability**: Solid foundation, well-tested components
- **Learning**: Understanding OS internals from scratch

## ✅ Current Status: v0.32.0 - Full Featured Desktop OS

### Core Systems:
- ✅ **Multiboot1 Bootloader** - GRUB compatible
- ✅ **Protected Mode** - GDT, IDT, TSS fully configured
- ✅ **Memory Management** - Paging (4MB PSE), PMM, VMM, Heap (1MB)
- ✅ **Interrupt System** - PIC, PIT (100Hz), PS/2 Keyboard & Mouse
- ✅ **Multitasking** - Process management, task states, context switching
- ✅ **User Mode** - Ring 0 ↔ Ring 3 transitions, syscalls (INT 0x80)
- ✅ **IPC** - Pipes, message queues, shared memory, semaphores, mutexes

### Storage & Filesystem:
- ✅ **ATA/IDE Driver** - PIO mode disk access
- ✅ **FAT32 Filesystem** - Full read/write support
- ✅ **MBR Partition Table** - Partition detection
- ✅ **VFS** - Virtual filesystem abstraction
- ✅ **Ramdisk** - In-memory filesystem (64KB)
- ✅ **TAR Support** - initrd archive loading

### Networking Stack:
- ✅ **RTL8139 NIC Driver** - PCI detection, TX/RX
- ✅ **Ethernet/IPv4/ICMP/UDP/TCP** - Full protocol stack
- ✅ **ARP/DHCP/DNS** - Network configuration & resolution
- ✅ **HTTP Client** - HTTP/1.1 GET requests
- ✅ **Firewall** - Packet filtering with rules
- ✅ **TLS 1.3** - Record layer, ClientHello with SNI
- ✅ **Onion Routing** - Tor-like anonymous networking
- ✅ **SOCKS5 Proxy** - Circuit-based routing

### Graphics & GUI:
- ✅ **VBE/VESA Graphics** - Up to 1920x1080 resolution
- ✅ **Double Buffering** - Flicker-free rendering
- ✅ **Window Manager** - Draggable, resizable windows
- ✅ **Desktop Environment** - Icons, taskbar, start menu
- ✅ **Theme Support** - Dark/Light themes, wallpaper styles
- ✅ **Clipboard** - Copy/paste between apps
- ✅ **Notifications** - Toast messages
- ✅ **Screensaver** - Auto-activate after idle

### Audio System:
- ✅ **PC Speaker** - Beeps, tones, melodies
- ✅ **Sound Blaster 16** - DSP, DMA audio
- ✅ **System Sounds** - Click, window open/close, error

### USB Support:
- ✅ **PCI Bus Driver** - Device enumeration
- ✅ **UHCI Controller** - USB 1.x support
- ✅ **USB Core** - Device descriptors

### Cryptography:
- ✅ **Hardware RNG** - RDRAND detection
- ✅ **SHA-256** - Full hash implementation
- ✅ **Secure Memory** - Volatile wiping
- ✅ **Key Derivation** - PBKDF2-like

## 🖥️ GUI Applications

| App | Description |
|-----|-------------|
| **Terminal** | Full shell with command history, tab completion, colored output |
| **File Manager** | Browse FAT32, copy/paste, delete, sort files |
| **Notepad** | Text editor with save/load, find, undo, word wrap |
| **Calculator** | Scientific calculator with memory functions |
| **Settings** | Display, network, audio, theme configuration |
| **Task Manager** | Processes, performance, memory, network tabs |
| **Device Manager** | Storage, network, display, audio, USB devices |
| **System Info** | CPU, RAM, disk, network information |
| **Paint** | Drawing app with brush, line, rect, circle, fill tools |
| **Clock** | Analog clock with stopwatch and alarm |
| **Browser** | Privacy browser with Tor integration, HTML rendering |
| **Tetris** | Classic game with levels and scoring |
| **Snake** | Classic game with speed levels and high score |
| **Minesweeper** | Classic puzzle game |
| **Ping Tool** | Visual ping with response graph |
| **Hex Viewer** | View files in hexadecimal |
| **Color Picker** | RGB color selection tool |
| **Log Viewer** | System logs with colored levels |
| **Calendar** | Date viewer |

## 🏗️ Architecture

### Memory Layout:
```
0x00000000 - 0x000FFFFF : Low memory (1MB)
0x00100000 - 0x001FFFFF : Kernel code/data
0x00200000 - 0x002FFFFF : Heap (1MB)
0x00300000+             : Available for processes
```

### Interrupt Vector Table:
```
INT 0-31   : CPU Exceptions
INT 32-47  : Hardware IRQs (PIC remapped)
INT 0x80   : System calls
```

## 📁 Project Structure

```
HomeOS/
├── src/
│   ├── kernel.zig          # Main kernel entry
│   ├── arch/               # x86 architecture (GDT, IDT, ISR, PIC, TSS)
│   ├── mm/                 # Memory (paging, PMM, VMM, heap)
│   ├── drivers/            # Hardware (ATA, keyboard, mouse, VBE, audio, USB)
│   ├── fs/                 # Filesystem (VFS, FAT32, ramdisk)
│   ├── net/                # Network (Ethernet, TCP/IP, DNS, Tor)
│   ├── proc/               # Process (task, syscall, IPC)
│   ├── gui/                # GUI (desktop, window, apps/)
│   ├── shell/              # Shell commands
│   ├── crypto/             # Cryptography (RNG, SHA256)
│   ├── browser/            # HTML parser
│   └── lib/                # Libraries (VGA, ELF)
├── build.zig               # Build configuration
├── linker.ld               # Linker script
└── iso/boot/grub/grub.cfg  # GRUB config
```

## 🚀 Building & Running

### Prerequisites:
- **Zig 0.15.x**
- **QEMU** (qemu-system-i386)
- **GCC** (for C++ compilation)

### Build:
```bash
cd HomeOS
zig build
```

### Run in QEMU:
```bash
# Basic run
qemu-system-i386 -kernel zig-out/bin/kernel.elf -m 512M -vga std

# Full features (network, disk, audio)
qemu-system-i386 -kernel zig-out/bin/kernel.elf -m 512M \
  -netdev user,id=net0 -device rtl8139,netdev=net0 \
  -hda disk.img -serial stdio -vga std \
  -audiodev dsound,id=audio0 -machine pcspk-audiodev=audio0
```

### Build ISO:
```powershell
# Windows (requires WSL with grub tools)
.\make_iso_simple.ps1

# Test ISO
qemu-system-i386 -cdrom HomeOS.iso -m 512M -vga std
```

## 💻 Shell Commands

### File Operations:
| Command | Description |
|---------|-------------|
| `ls` | List RAM filesystem |
| `cat <file>` | Read file from RAM |
| `touch <file>` | Create empty file |
| `rm <file>` | Delete file |
| `write <file> <text>` | Write to file |
| `lsfat` | List FAT32 root |
| `catfat <file>` | Read FAT32 file |
| `mkfat <file>` | Create FAT32 file |
| `writefat <file> <text>` | Write to FAT32 |
| `rmfat <file>` | Delete FAT32 file |

### System:
| Command | Description |
|---------|-------------|
| `help` | Show commands |
| `clear` | Clear screen |
| `uptime` | System uptime |
| `mem` | Memory info |
| `disk` | Disk info |
| `ps` | Process list |
| `date` / `time` | Current date/time |
| `version` / `about` | OS info |
| `reboot` / `shutdown` | Power control |

### Network:
| Command | Description |
|---------|-------------|
| `net` | Network status |
| `ping <ip>` | Ping address |
| `arp` | ARP cache |
| `dhcp` | DHCP status |
| `nslookup <host>` | DNS lookup |
| `firewall` | Firewall rules |
| `security` | Security status |
| `macrandom` | Randomize MAC |
| `tor` | Tor control |
| `circuit` | Circuit info |

### Other:
| Command | Description |
|---------|-------------|
| `gui` | Start desktop |
| `crypto` | Crypto status |
| `beep` / `sound` / `play` | Audio |
| `usb` / `lspci` | Hardware |
| `ipc` | IPC resources |
| `run <prog>` / `programs` | User programs |

## 🔒 Privacy Features

- **No Telemetry** - Zero data collection
- **Onion Routing** - Built-in Tor-like anonymous networking
- **MAC Randomization** - Hardware tracking prevention
- **Firewall** - Packet filtering
- **TLS 1.3** - Encrypted connections
- **Secure Memory** - Sensitive data wiping

## ⌨️ Keyboard Shortcuts

### Desktop:
| Key | Action |
|-----|--------|
| `F1-F8` | Quick launch apps |
| `F9` | Cycle wallpaper |
| `F10` | Cascade windows |
| `F11` | Tile windows |
| `F12` | Minimize all |
| `Tab` | Cycle windows |
| `ESC` | Close window |

### Window:
- Drag title bar to move
- Drag corner to resize
- Double-click title to maximize
- Snap to edges when dragging

## 📊 Technical Specifications

- **Architecture**: x86 (32-bit protected mode)
- **Boot**: Multiboot1 (GRUB compatible)
- **Memory**: 512 MB recommended
- **Display**: VBE graphics, up to 1920x1080
- **Timer**: PIT at 100 Hz
- **Keyboard**: PS/2, US layout
- **Mouse**: PS/2, 3-button
- **Network**: RTL8139 NIC
- **Storage**: ATA/IDE, FAT32
- **Audio**: PC Speaker, Sound Blaster 16

## 📄 License

**Copyright © 2025 Romy Rianata** - All rights reserved.

## 🙏 Acknowledgments

- [OSDev Wiki](https://wiki.osdev.org/) - OS development resource
- [Intel Manuals](https://www.intel.com/content/www/us/en/developer/articles/technical/intel-sdm.html) - x86 reference
- [Zig Language](https://ziglang.org/) - Systems programming language

---

**Version**: 0.32.0  
**Last Updated**: December 17, 2025
