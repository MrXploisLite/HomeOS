// Home OS - TLS 1.3 Implementation (Basic)
// Copyright © 2025 Romy Rianata - Home OS
// Phase 22: Network Security Layer

const serial = @import("../drivers/serial.zig");
const crypto = @import("../crypto/crypto.zig");
const sha256 = @import("../crypto/sha256.zig");
const tcp = @import("tcp.zig");

// TLS Record Types
pub const ContentType = enum(u8) {
    change_cipher_spec = 20,
    alert = 21,
    handshake = 22,
    application_data = 23,
};

// TLS Versions
pub const Version = struct {
    major: u8,
    minor: u8,

    pub const TLS_1_0: Version = .{ .major = 3, .minor = 1 };
    pub const TLS_1_2: Version = .{ .major = 3, .minor = 3 };
    pub const TLS_1_3: Version = .{ .major = 3, .minor = 3 }; // TLS 1.3 uses 0x0303 for compatibility
};

// TLS Alert Levels
pub const AlertLevel = enum(u8) {
    warning = 1,
    fatal = 2,
};

// TLS Alert Descriptions
pub const AlertDescription = enum(u8) {
    close_notify = 0,
    unexpected_message = 10,
    bad_record_mac = 20,
    record_overflow = 22,
    handshake_failure = 40,
    bad_certificate = 42,
    certificate_expired = 45,
    unknown_ca = 48,
    decode_error = 50,
    decrypt_error = 51,
    protocol_version = 70,
    insufficient_security = 71,
    internal_error = 80,
};

// Handshake Types
pub const HandshakeType = enum(u8) {
    client_hello = 1,
    server_hello = 2,
    new_session_ticket = 4,
    encrypted_extensions = 8,
    certificate = 11,
    certificate_request = 13,
    certificate_verify = 15,
    finished = 20,
    key_update = 24,
};

// Cipher Suites (TLS 1.3)
pub const CipherSuite = enum(u16) {
    TLS_AES_128_GCM_SHA256 = 0x1301,
    TLS_AES_256_GCM_SHA384 = 0x1302,
    TLS_CHACHA20_POLY1305_SHA256 = 0x1303,
};

// TLS Record Header (5 bytes)
pub const RecordHeader = packed struct {
    content_type: u8,
    version_major: u8,
    version_minor: u8,
    length_high: u8,
    length_low: u8,

    pub fn getLength(self: *const RecordHeader) u16 {
        return (@as(u16, self.length_high) << 8) | @as(u16, self.length_low);
    }

    pub fn setLength(self: *RecordHeader, len: u16) void {
        self.length_high = @truncate(len >> 8);
        self.length_low = @truncate(len);
    }
};

// TLS Connection State
pub const State = enum {
    disconnected,
    connecting,
    client_hello_sent,
    server_hello_received,
    handshake_complete,
    established,
    closing,
    closed,
};

// TLS Session
pub const Session = struct {
    state: State = .disconnected,
    tcp_socket_id: ?usize = null, // TCP socket index

    // Handshake state
    client_random: [32]u8 = [_]u8{0} ** 32,
    server_random: [32]u8 = [_]u8{0} ** 32,

    // Keys (simplified - real TLS uses key derivation)
    client_write_key: [32]u8 = [_]u8{0} ** 32,
    server_write_key: [32]u8 = [_]u8{0} ** 32,
    client_write_iv: [12]u8 = [_]u8{0} ** 12,
    server_write_iv: [12]u8 = [_]u8{0} ** 12,

    // Sequence numbers
    client_seq: u64 = 0,
    server_seq: u64 = 0,

    // Handshake hash (for Finished message)
    handshake_hash: sha256.Sha256 = sha256.Sha256.init(),

    // Cipher suite
    cipher_suite: CipherSuite = .TLS_AES_128_GCM_SHA256,

    // Error state
    last_alert: ?AlertDescription = null,

    pub fn init() Session {
        return Session{};
    }

    pub fn reset(self: *Session) void {
        self.state = .disconnected;
        self.tcp_socket_id = null;
        self.client_seq = 0;
        self.server_seq = 0;
        self.last_alert = null;
        crypto.secureZero(&self.client_write_key);
        crypto.secureZero(&self.server_write_key);
        crypto.secureZero(&self.client_write_iv);
        crypto.secureZero(&self.server_write_iv);
    }
};

// TLS Context (manages multiple sessions)
const MAX_SESSIONS = 8;
var sessions: [MAX_SESSIONS]Session = [_]Session{Session.init()} ** MAX_SESSIONS;
var tls_initialized: bool = false;

/// Initialize TLS subsystem
pub fn init() void {
    serial.write("TLS: Initializing...\n");

    for (&sessions) |*s| {
        s.* = Session.init();
    }

    tls_initialized = true;
    serial.write("TLS: Ready\n");
}

/// Allocate a new TLS session
pub fn createSession() ?*Session {
    for (&sessions) |*s| {
        if (s.state == .disconnected) {
            s.* = Session.init();
            return s;
        }
    }
    return null;
}

/// Free a TLS session
pub fn destroySession(session: *Session) void {
    session.reset();
}

/// Build ClientHello message
pub fn buildClientHello(session: *Session, buf: []u8, hostname: []const u8) usize {
    if (buf.len < 512) return 0;

    // Generate client random
    crypto.randomBytes(&session.client_random);

    var pos: usize = 0;

    // Record header (will fill length later)
    buf[pos] = @intFromEnum(ContentType.handshake);
    pos += 1;
    buf[pos] = Version.TLS_1_2.major;
    pos += 1;
    buf[pos] = Version.TLS_1_2.minor;
    pos += 1;
    const length_pos = pos;
    pos += 2; // Length placeholder

    const handshake_start = pos;

    // Handshake header
    buf[pos] = @intFromEnum(HandshakeType.client_hello);
    pos += 1;
    const hs_length_pos = pos;
    pos += 3; // Handshake length placeholder

    // Client Version (TLS 1.2 for compatibility)
    buf[pos] = 0x03;
    pos += 1;
    buf[pos] = 0x03;
    pos += 1;

    // Client Random (32 bytes)
    for (session.client_random) |b| {
        buf[pos] = b;
        pos += 1;
    }

    // Session ID (empty for new connection)
    buf[pos] = 0;
    pos += 1;

    // Cipher Suites
    buf[pos] = 0;
    pos += 1;
    buf[pos] = 2; // 2 bytes = 1 cipher suite
    pos += 1;
    buf[pos] = 0x13;
    pos += 1; // TLS_AES_128_GCM_SHA256
    buf[pos] = 0x01;
    pos += 1;

    // Compression Methods (null only)
    buf[pos] = 1;
    pos += 1;
    buf[pos] = 0;
    pos += 1;

    // Extensions
    const ext_length_pos = pos;
    pos += 2; // Extensions length placeholder
    const ext_start = pos;

    // SNI Extension (Server Name Indication)
    if (hostname.len > 0 and hostname.len < 256) {
        // Extension type: server_name (0)
        buf[pos] = 0;
        pos += 1;
        buf[pos] = 0;
        pos += 1;

        // Extension length
        const sni_len: u16 = @truncate(hostname.len + 5);
        buf[pos] = @truncate(sni_len >> 8);
        pos += 1;
        buf[pos] = @truncate(sni_len);
        pos += 1;

        // Server name list length
        const list_len: u16 = @truncate(hostname.len + 3);
        buf[pos] = @truncate(list_len >> 8);
        pos += 1;
        buf[pos] = @truncate(list_len);
        pos += 1;

        // Name type: hostname (0)
        buf[pos] = 0;
        pos += 1;

        // Hostname length
        buf[pos] = 0;
        pos += 1;
        buf[pos] = @truncate(hostname.len);
        pos += 1;

        // Hostname
        for (hostname) |c| {
            buf[pos] = c;
            pos += 1;
        }
    }

    // Supported Versions Extension (TLS 1.3)
    buf[pos] = 0x00;
    pos += 1;
    buf[pos] = 0x2b;
    pos += 1; // supported_versions
    buf[pos] = 0x00;
    pos += 1;
    buf[pos] = 0x03;
    pos += 1; // length
    buf[pos] = 0x02;
    pos += 1; // versions length
    buf[pos] = 0x03;
    pos += 1;
    buf[pos] = 0x04;
    pos += 1; // TLS 1.3

    // Fill in lengths
    const ext_len: u16 = @truncate(pos - ext_start);
    buf[ext_length_pos] = @truncate(ext_len >> 8);
    buf[ext_length_pos + 1] = @truncate(ext_len);

    const hs_len: u24 = @truncate(pos - hs_length_pos - 3);
    buf[hs_length_pos] = @truncate(hs_len >> 16);
    buf[hs_length_pos + 1] = @truncate(hs_len >> 8);
    buf[hs_length_pos + 2] = @truncate(hs_len);

    const record_len: u16 = @truncate(pos - handshake_start);
    buf[length_pos] = @truncate(record_len >> 8);
    buf[length_pos + 1] = @truncate(record_len);

    // Update handshake hash
    session.handshake_hash.update(buf[handshake_start..pos]);

    session.state = .client_hello_sent;
    return pos;
}

/// Parse ServerHello message
pub fn parseServerHello(session: *Session, data: []const u8) bool {
    if (data.len < 39) return false;

    // Skip record header (5 bytes)
    var pos: usize = 5;

    // Check handshake type
    if (data[pos] != @intFromEnum(HandshakeType.server_hello)) {
        return false;
    }
    pos += 1;

    // Skip handshake length (3 bytes)
    pos += 3;

    // Server version
    pos += 2;

    // Server random (32 bytes)
    if (pos + 32 > data.len) return false;
    for (session.server_random, 0..) |*b, i| {
        b.* = data[pos + i];
    }
    pos += 32;

    // Update handshake hash
    session.handshake_hash.update(data[5..]);

    session.state = .server_hello_received;
    return true;
}

/// Build Alert message
pub fn buildAlert(buf: []u8, level: AlertLevel, desc: AlertDescription) usize {
    if (buf.len < 7) return 0;

    buf[0] = @intFromEnum(ContentType.alert);
    buf[1] = Version.TLS_1_2.major;
    buf[2] = Version.TLS_1_2.minor;
    buf[3] = 0;
    buf[4] = 2; // Length
    buf[5] = @intFromEnum(level);
    buf[6] = @intFromEnum(desc);

    return 7;
}

/// Check if TLS is initialized
pub fn isInitialized() bool {
    return tls_initialized;
}

/// Get active session count
pub fn getActiveSessionCount() usize {
    var count: usize = 0;
    for (sessions) |s| {
        if (s.state != .disconnected and s.state != .closed) {
            count += 1;
        }
    }
    return count;
}
