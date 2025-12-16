// Home OS - System Configuration Persistence
// Copyright © 2025 Romy Rianata - Home OS
// Phase 25: Settings Persistence - Save/Load to FAT32

const serial = @import("../drivers/serial.zig");
const fat32 = @import("../fs/fat32.zig");
const vbe = @import("../drivers/vbe.zig");
const graphics = @import("../drivers/graphics.zig");

// Config file magic and version
const CONFIG_MAGIC: u32 = 0x484F4D45; // "HOME"
const CONFIG_VERSION: u16 = 1;

// System configuration structure (saved to disk)
pub const SystemConfig = extern struct {
    magic: u32,
    version: u16,
    checksum: u16,

    // Display settings
    resolution_idx: u8,
    dark_theme: u8,
    _pad1: [2]u8,

    // Audio settings
    volume: u8,
    beep_enabled: u8,
    _pad2: [2]u8,

    // Mouse settings
    mouse_speed: u8,
    _pad3: [3]u8,

    // Window settings
    last_window_x: i16,
    last_window_y: i16,

    // Reserved for future use
    reserved: [44]u8,

    pub fn init() SystemConfig {
        return SystemConfig{
            .magic = CONFIG_MAGIC,
            .version = CONFIG_VERSION,
            .checksum = 0,
            .resolution_idx = 1, // Default 800x600
            .dark_theme = 1,
            ._pad1 = [_]u8{0} ** 2,
            .volume = 5,
            .beep_enabled = 1,
            ._pad2 = [_]u8{0} ** 2,
            .mouse_speed = 5,
            ._pad3 = [_]u8{0} ** 3,
            .last_window_x = 100,
            .last_window_y = 100,
            .reserved = [_]u8{0} ** 44,
        };
    }

    pub fn calculateChecksum(self: *SystemConfig) u16 {
        const bytes: [*]const u8 = @ptrCast(self);
        var sum: u32 = 0;
        // Skip magic, version, checksum fields (first 8 bytes)
        var i: usize = 8;
        while (i < @sizeOf(SystemConfig)) : (i += 1) {
            sum += bytes[i];
        }
        return @truncate(sum & 0xFFFF);
    }

    pub fn isValid(self: *const SystemConfig) bool {
        if (self.magic != CONFIG_MAGIC) return false;
        if (self.version != CONFIG_VERSION) return false;
        var copy = self.*;
        const expected = copy.calculateChecksum();
        return self.checksum == expected;
    }
};

// Global config instance
var current_config: SystemConfig = SystemConfig.init();
var config_loaded: bool = false;
var config_dirty: bool = false;

/// Load configuration from disk
pub fn load() bool {
    const fs = fat32.getFS() orelse {
        serial.write("Config: No filesystem\n");
        return false;
    };

    // Try to find CONFIG.DAT in root
    const entry = fs.findFile(fs.root_cluster, "CONFIG.DAT") orelse {
        serial.write("Config: No config file, using defaults\n");
        return false;
    };

    // Read config file (struct is 68 bytes)
    var buffer: [128]u8 align(4) = undefined;
    const bytes_read = fs.readFile(&entry, &buffer, 128);

    if (bytes_read < @sizeOf(SystemConfig)) {
        serial.write("Config: File too small\n");
        return false;
    }

    // Copy to config struct
    const loaded: *const SystemConfig = @ptrCast(@alignCast(&buffer));

    if (!loaded.isValid()) {
        serial.write("Config: Invalid checksum\n");
        return false;
    }

    current_config = loaded.*;
    config_loaded = true;
    config_dirty = false;

    serial.write("Config: Loaded successfully\n");
    return true;
}

/// Save configuration to disk
pub fn save() bool {
    const fs = fat32.getFS() orelse {
        serial.write("Config: No filesystem for save\n");
        return false;
    };

    // Update checksum
    current_config.checksum = current_config.calculateChecksum();

    // Convert to bytes
    const config_bytes: [*]const u8 = @ptrCast(&current_config);

    // Write to file
    if (!fs.writeFile(fs.root_cluster, "CONFIG.DAT", config_bytes[0..@sizeOf(SystemConfig)])) {
        serial.write("Config: Failed to write\n");
        return false;
    }

    config_dirty = false;
    serial.write("Config: Saved\n");
    return true;
}

/// Apply loaded configuration to system
/// Called during init - resolution is applied later after VBE is ready
pub fn apply() void {
    const desktop = @import("desktop.zig");

    // Apply theme
    desktop.dark_theme = (current_config.dark_theme != 0);

    // Apply audio settings
    const settings_mod = @import("apps/settings.zig");
    settings_mod.setVolume(current_config.volume);
    settings_mod.setMouseSpeed(current_config.mouse_speed);

    serial.write("Config: Applied settings\n");
}

/// Apply resolution from config (call after VBE is fully ready)
pub fn applyResolution() void {
    // Only apply if config was loaded from disk
    if (!config_loaded) {
        serial.write("Config: No saved resolution to apply\n");
        return;
    }

    const desktop = @import("desktop.zig");
    const current_res = vbe.getCurrentResolutionIdx();

    serial.write("Config: Checking resolution idx=");
    serial.writeInt(current_config.resolution_idx);
    serial.write(" current=");
    serial.writeInt(current_res);
    serial.write("\n");

    if (current_config.resolution_idx != current_res and current_config.resolution_idx < vbe.getResolutionCount()) {
        serial.write("Config: Applying saved resolution...\n");
        if (vbe.setResolution(current_config.resolution_idx)) {
            _ = graphics.init();
            desktop.onResolutionChange();
            serial.write("Config: Applied resolution\n");
        }
    }
}

/// Get current config
pub fn getConfig() *SystemConfig {
    return &current_config;
}

/// Mark config as dirty (needs save)
pub fn markDirty() void {
    config_dirty = true;
}

/// Check if config needs saving
pub fn isDirty() bool {
    return config_dirty;
}

/// Check if config was loaded
pub fn isLoaded() bool {
    return config_loaded;
}

// Convenience setters that auto-mark dirty

pub fn setResolution(idx: u8) void {
    if (current_config.resolution_idx != idx) {
        current_config.resolution_idx = idx;
        config_dirty = true;
    }
}

pub fn setDarkTheme(enabled: bool) void {
    const val: u8 = if (enabled) 1 else 0;
    if (current_config.dark_theme != val) {
        current_config.dark_theme = val;
        config_dirty = true;
    }
}

pub fn setVolume(vol: u8) void {
    if (current_config.volume != vol) {
        current_config.volume = vol;
        config_dirty = true;
    }
}

pub fn setMouseSpeed(speed: u8) void {
    if (current_config.mouse_speed != speed) {
        current_config.mouse_speed = speed;
        config_dirty = true;
    }
}

/// Auto-save if dirty (call periodically)
pub fn autoSave() void {
    if (config_dirty) {
        _ = save();
    }
}

/// Initialize config system - load and apply
pub fn init() void {
    serial.write("Config: Initializing...\n");
    if (load()) {
        apply();
    } else {
        // Use defaults, save initial config
        _ = save();
    }
}
