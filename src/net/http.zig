// Home OS - HTTP Client
// Copyright © 2025 Romy Rianata - Home OS
// Simple HTTP/1.1 client for GET requests

const serial = @import("../drivers/serial.zig");
const tcp = @import("tcp.zig");
const dns = @import("dns.zig");
const ipv4 = @import("ipv4.zig");
const net = @import("net.zig");

pub const HTTP_PORT: u16 = 80;
pub const MAX_RESPONSE_SIZE: usize = 4096;

// HTTP response structure
pub const HttpResponse = struct {
    status_code: u16,
    content_length: u32,
    body: [MAX_RESPONSE_SIZE]u8,
    body_len: usize,
    headers_end: usize,
    complete: bool,

    pub fn init() HttpResponse {
        return HttpResponse{
            .status_code = 0,
            .content_length = 0,
            .body = [_]u8{0} ** MAX_RESPONSE_SIZE,
            .body_len = 0,
            .headers_end = 0,
            .complete = false,
        };
    }
};

// HTTP request state
pub const HttpState = enum {
    idle,
    resolving,
    connecting,
    sending,
    receiving,
    complete,
    error_state,
};

var http_state: HttpState = .idle;
var current_response: HttpResponse = HttpResponse.init();
var request_host: [64]u8 = [_]u8{0} ** 64;
var request_host_len: usize = 0;
var request_path: [128]u8 = [_]u8{0} ** 128;
var request_path_len: usize = 0;
var target_ip: ipv4.IPv4Address = ipv4.ZERO_IP;
var http_socket: ?usize = null;

/// Initialize HTTP client
pub fn init() void {
    serial.write("HTTP: Initializing HTTP client...\n");
    http_state = .idle;
    serial.write("HTTP: Ready\n");
}

/// Start an HTTP GET request (non-blocking)
pub fn get(url: []const u8) bool {
    if (http_state != .idle and http_state != .complete and http_state != .error_state) {
        return false; // Already in progress
    }

    // Reset state
    current_response = HttpResponse.init();
    http_state = .idle;

    // Parse URL
    if (!parseUrl(url)) {
        http_state = .error_state;
        return false;
    }

    serial.write("HTTP: GET ");
    serial.write(request_host[0..request_host_len]);
    serial.write(request_path[0..request_path_len]);
    serial.write("\n");

    // Start DNS resolution
    http_state = .resolving;

    // Check if host is IP address
    if (parseIpAddress(request_host[0..request_host_len])) |ip| {
        target_ip = ip;
        http_state = .connecting;
        return startConnection();
    }

    // Need DNS resolution
    if (dns.cacheLookup(request_host[0..request_host_len])) |ip| {
        target_ip = ip;
        http_state = .connecting;
        return startConnection();
    }

    // Send DNS query
    _ = net.sendDnsQuery(request_host[0..request_host_len]);
    return true;
}

/// Parse URL into host and path
fn parseUrl(url: []const u8) bool {
    request_host_len = 0;
    request_path_len = 0;

    var start: usize = 0;

    // Skip http://
    if (url.len > 7 and url[0] == 'h' and url[1] == 't' and url[2] == 't' and url[3] == 'p') {
        if (url[4] == ':' and url[5] == '/' and url[6] == '/') {
            start = 7;
        } else if (url[4] == 's' and url[5] == ':' and url[6] == '/' and url[7] == '/') {
            start = 8; // https:// (not supported but skip)
        }
    }

    // Find end of host (/ or end of string)
    var host_end = start;
    while (host_end < url.len and url[host_end] != '/') : (host_end += 1) {}

    // Copy host
    const host_len = host_end - start;
    if (host_len == 0 or host_len > 63) return false;

    for (url[start..host_end]) |c| {
        request_host[request_host_len] = c;
        request_host_len += 1;
    }

    // Copy path (or default to /)
    if (host_end < url.len) {
        const path_len = url.len - host_end;
        if (path_len > 127) return false;
        for (url[host_end..]) |c| {
            request_path[request_path_len] = c;
            request_path_len += 1;
        }
    } else {
        request_path[0] = '/';
        request_path_len = 1;
    }

    return true;
}

/// Parse IP address string to bytes
fn parseIpAddress(s: []const u8) ?ipv4.IPv4Address {
    var ip: ipv4.IPv4Address = [_]u8{0} ** 4;
    var octet: u8 = 0;
    var octet_idx: usize = 0;
    var has_digit = false;

    for (s) |c| {
        if (c >= '0' and c <= '9') {
            octet = octet * 10 + (c - '0');
            has_digit = true;
        } else if (c == '.') {
            if (!has_digit or octet_idx >= 3) return null;
            ip[octet_idx] = octet;
            octet_idx += 1;
            octet = 0;
            has_digit = false;
        } else {
            return null; // Not an IP address
        }
    }

    if (has_digit and octet_idx == 3) {
        ip[3] = octet;
        return ip;
    }

    return null;
}

/// Start TCP connection
fn startConnection() bool {
    // Allocate TCP socket
    if (tcp.socket()) |sock_id| {
        http_socket = sock_id;
        // Bind to ephemeral port
        const local_port = tcp.getEphemeralPort();
        if (!tcp.bind(sock_id, local_port)) {
            http_state = .error_state;
            return false;
        }
        // Start TCP handshake - send SYN
        if (tcp.getSocket(sock_id)) |sock| {
            sock.remote_ip = target_ip;
            sock.remote_port = HTTP_PORT;
            sock.state = .syn_sent;
            sock.connected = false;

            var syn_buf: [64]u8 = undefined;
            const syn_len = tcp.createSyn(sock, &syn_buf);
            if (syn_len > 0) {
                _ = net.sendTcp(target_ip, syn_buf[0..syn_len]);
                http_state = .connecting;
                return true;
            }
        }
    }
    http_state = .error_state;
    return false;
}

/// Build HTTP GET request
fn buildRequest(buf: []u8) usize {
    var len: usize = 0;

    // GET /path HTTP/1.1\r\n
    const get_str = "GET ";
    for (get_str) |c| {
        buf[len] = c;
        len += 1;
    }
    for (request_path[0..request_path_len]) |c| {
        buf[len] = c;
        len += 1;
    }
    const http_ver = " HTTP/1.1\r\n";
    for (http_ver) |c| {
        buf[len] = c;
        len += 1;
    }

    // Host: header
    const host_hdr = "Host: ";
    for (host_hdr) |c| {
        buf[len] = c;
        len += 1;
    }
    for (request_host[0..request_host_len]) |c| {
        buf[len] = c;
        len += 1;
    }
    buf[len] = '\r';
    len += 1;
    buf[len] = '\n';
    len += 1;

    // User-Agent
    const ua = "User-Agent: HomeOS/0.29.0\r\n";
    for (ua) |c| {
        buf[len] = c;
        len += 1;
    }

    // Connection: close
    const conn = "Connection: close\r\n";
    for (conn) |c| {
        buf[len] = c;
        len += 1;
    }

    // End headers
    buf[len] = '\r';
    len += 1;
    buf[len] = '\n';
    len += 1;

    return len;
}

/// Update HTTP state machine (call periodically)
pub fn update() void {
    switch (http_state) {
        .resolving => {
            // Check if DNS resolved
            if (dns.cacheLookup(request_host[0..request_host_len])) |ip| {
                target_ip = ip;
                http_state = .connecting;
                _ = startConnection();
            }
        },
        .connecting => {
            // Check TCP connection state
            if (http_socket) |sock_id| {
                if (tcp.getSocket(@intCast(sock_id))) |sock| {
                    if (sock.state == .established) {
                        http_state = .sending;
                        // Send HTTP request
                        var req_buf: [512]u8 = undefined;
                        const req_len = buildRequest(&req_buf);

                        var data_buf: [600]u8 = undefined;
                        const data_len = tcp.createData(sock, req_buf[0..req_len], &data_buf);
                        if (data_len > 0) {
                            _ = net.sendTcp(sock.remote_ip, data_buf[0..data_len]);
                        }
                        http_state = .receiving;
                    } else if (sock.state == .closed) {
                        http_state = .error_state;
                    }
                }
            }
        },
        .receiving => {
            // Check for received data in socket buffer
            if (http_socket) |sock_id| {
                if (tcp.getSocket(@intCast(sock_id))) |sock| {
                    // Check if we have data in receive buffer
                    if (sock.recv_len > 0) {
                        const copy_len = @min(sock.recv_len, MAX_RESPONSE_SIZE - current_response.body_len);
                        for (sock.recv_buffer[0..copy_len], 0..) |c, i| {
                            current_response.body[current_response.body_len + i] = c;
                        }
                        current_response.body_len += copy_len;
                        sock.recv_len = 0; // Clear buffer

                        // Parse response
                        parseResponse();
                    }

                    if (sock.state == .closed or sock.state == .close_wait or current_response.complete) {
                        http_state = .complete;
                        sock.close();
                        http_socket = null;
                    }
                }
            }
        },
        else => {},
    }
}

/// Parse HTTP response
fn parseResponse() void {
    if (current_response.body_len < 12) return;

    // Parse status code from "HTTP/1.x NNN"
    if (current_response.status_code == 0) {
        if (current_response.body[9] >= '0' and current_response.body[9] <= '9') {
            current_response.status_code = (@as(u16, current_response.body[9] - '0') * 100) +
                (@as(u16, current_response.body[10] - '0') * 10) +
                @as(u16, current_response.body[11] - '0');
        }
    }

    // Find end of headers (\r\n\r\n)
    if (current_response.headers_end == 0) {
        var i: usize = 0;
        while (i + 3 < current_response.body_len) : (i += 1) {
            if (current_response.body[i] == '\r' and
                current_response.body[i + 1] == '\n' and
                current_response.body[i + 2] == '\r' and
                current_response.body[i + 3] == '\n')
            {
                current_response.headers_end = i + 4;
                break;
            }
        }
    }

    // Check if complete (simplified - just check if we have headers)
    if (current_response.headers_end > 0) {
        current_response.complete = true;
    }
}

/// Get current HTTP state
pub fn getState() HttpState {
    return http_state;
}

/// Get response (only valid when state is complete)
pub fn getResponse() *const HttpResponse {
    return &current_response;
}

/// Check if request is complete
pub fn isComplete() bool {
    return http_state == .complete;
}

/// Check if request failed
pub fn isError() bool {
    return http_state == .error_state;
}

/// Reset HTTP client for new request
pub fn reset() void {
    if (http_socket) |sock_id| {
        if (tcp.getSocket(@intCast(sock_id))) |sock| {
            sock.close();
        }
        http_socket = null;
    }
    http_state = .idle;
    current_response = HttpResponse.init();
}
