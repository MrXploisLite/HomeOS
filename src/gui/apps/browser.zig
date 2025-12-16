// Home OS - HomeBrowser
// Copyright © 2025 Romy Rianata - Home OS
// Phase 27: Privacy Browser - GUI Browser App

const graphics = @import("../../drivers/graphics.zig");
const font = @import("../../drivers/font.zig");
const window = @import("../window.zig");
const Window = window.Window;
const keyboard = @import("../../drivers/keyboard.zig");
const http = @import("../../net/http.zig");
const html = @import("../../browser/html.zig");
const tor = @import("../../net/tor.zig");
const serial = @import("../../drivers/serial.zig");

// Browser state
pub const BrowserState = enum {
    idle,
    loading,
    loaded,
    error_state,
};

// URL bar
var url_bar: [256]u8 = [_]u8{0} ** 256;
var url_bar_len: usize = 0;
var url_bar_focused: bool = true;

// Current page
var current_doc: html.HtmlDocument = html.HtmlDocument.init();
var browser_state: BrowserState = .idle;
var status_msg: [64]u8 = [_]u8{0} ** 64;
var status_len: usize = 0;
var scroll_y: i32 = 0;

// Privacy settings
var tor_enabled: bool = false;
var private_mode: bool = true; // No history by default

// Bookmarks (simple array)
const MAX_BOOKMARKS: usize = 8;
var bookmarks: [MAX_BOOKMARKS][128]u8 = [_][128]u8{[_]u8{0} ** 128} ** MAX_BOOKMARKS;
var bookmark_lens: [MAX_BOOKMARKS]usize = [_]usize{0} ** MAX_BOOKMARKS;
var bookmark_count: usize = 0;

// Link selection
var selected_link: usize = 0;
var link_count: usize = 0;

// Colors
const COLOR_BG = graphics.Color.rgb(30, 30, 35);
const COLOR_URL_BAR = graphics.Color.rgb(45, 45, 50);
const COLOR_URL_TEXT = graphics.Color.rgb(220, 220, 220);
const COLOR_TOOLBAR = graphics.Color.rgb(40, 40, 45);
const COLOR_STATUS = graphics.Color.rgb(35, 35, 40);
const COLOR_TEXT = graphics.Color.rgb(200, 200, 200);
const COLOR_HEADING = graphics.Color.rgb(100, 180, 255);
const COLOR_LINK = graphics.Color.rgb(100, 200, 255);
const COLOR_LINK_SELECTED = graphics.Color.rgb(255, 200, 100);
const COLOR_TOR_ON = graphics.Color.rgb(100, 255, 100);
const COLOR_TOR_OFF = graphics.Color.rgb(255, 100, 100);

pub fn init() void {
    // Set default homepage
    const homepage = "about:home";
    for (homepage, 0..) |c, i| {
        url_bar[i] = c;
    }
    url_bar_len = homepage.len;

    // Add default bookmarks
    addBookmark("http://example.com");
    addBookmark("http://info.cern.ch");

    setStatus("Ready");
}

fn addBookmark(url: []const u8) void {
    if (bookmark_count >= MAX_BOOKMARKS) return;
    const len = @min(url.len, 127);
    for (url[0..len], 0..) |c, i| {
        bookmarks[bookmark_count][i] = c;
    }
    bookmark_lens[bookmark_count] = len;
    bookmark_count += 1;
}

fn setStatus(msg: []const u8) void {
    const len = @min(msg.len, 63);
    for (msg[0..len], 0..) |c, i| {
        status_msg[i] = c;
    }
    status_len = len;
}

/// Draw browser window
pub fn draw(win: *const Window, x: i32, y: i32) void {
    const content_width = win.width - 12;
    const content_height = win.height - window.TITLE_BAR_HEIGHT - 12;

    // Toolbar background
    const toolbar_height: u32 = 28;
    graphics.fillRect(x, y, content_width, toolbar_height, COLOR_TOOLBAR);

    // Back/Forward/Refresh buttons
    drawButton(x + 4, y + 4, "<", false);
    drawButton(x + 28, y + 4, ">", false);
    drawButton(x + 52, y + 4, "R", false);

    // Tor indicator
    const tor_x = x + 80;
    if (tor_enabled or tor.getStatus() == .connected) {
        graphics.fillRect(tor_x, y + 6, 32, 16, COLOR_TOR_ON);
        font.drawString(tor_x + 4, y + 8, "TOR", graphics.BLACK, null);
    } else {
        graphics.fillRect(tor_x, y + 6, 32, 16, graphics.Color.rgb(60, 60, 65));
        font.drawString(tor_x + 4, y + 8, "TOR", graphics.DARK_GRAY, null);
    }

    // URL bar
    const url_x = x + 120;
    const url_width = @as(u32, @intCast(content_width)) - 130;
    graphics.fillRect(url_x, y + 4, url_width, 20, COLOR_URL_BAR);
    graphics.drawRect(url_x, y + 4, url_width, 20, if (url_bar_focused) COLOR_LINK else graphics.DARK_GRAY);

    // URL text
    if (url_bar_len > 0) {
        const max_chars = (url_width - 8) / 8;
        const display_len = @min(url_bar_len, max_chars);
        font.drawString(url_x + 4, y + 8, url_bar[0..display_len], COLOR_URL_TEXT, null);
    }

    // Cursor in URL bar
    if (url_bar_focused) {
        const cursor_x = url_x + 4 + @as(i32, @intCast(url_bar_len * 8));
        font.drawString(cursor_x, y + 8, "_", COLOR_LINK, null);
    }

    // Content area
    const content_y = y + @as(i32, @intCast(toolbar_height));
    const page_height = content_height - toolbar_height - 20;
    graphics.fillRect(x, content_y, content_width, page_height, COLOR_BG);

    // Draw page content
    drawPageContent(x + 8, content_y + 4, content_width - 16, page_height - 8);

    // Status bar
    const status_y = y + @as(i32, @intCast(content_height)) - 18;
    graphics.fillRect(x, status_y, content_width, 18, COLOR_STATUS);

    // Status text
    if (status_len > 0) {
        font.drawString(x + 4, status_y + 4, status_msg[0..status_len], graphics.LIGHT_GRAY, null);
    }

    // Privacy indicator
    const priv_x = x + @as(i32, @intCast(content_width)) - 80;
    if (private_mode) {
        font.drawString(priv_x, status_y + 4, "[Private]", graphics.Color.rgb(150, 100, 255), null);
    }
}

fn drawButton(x: i32, y: i32, label: []const u8, active: bool) void {
    const bg = if (active) graphics.Color.rgb(70, 70, 80) else graphics.Color.rgb(55, 55, 60);
    graphics.fillRect(x, y, 20, 20, bg);
    graphics.drawRect(x, y, 20, 20, graphics.Color.rgb(80, 80, 85));
    font.drawString(x + 6, y + 6, label, graphics.LIGHT_GRAY, null);
}

fn drawPageContent(x: i32, y: i32, width: u32, height: u32) void {
    var draw_y = y - scroll_y;
    const max_y = y + @as(i32, @intCast(height));
    const line_height: i32 = 16;
    const chars_per_line = width / 8;

    link_count = 0;

    switch (browser_state) {
        .idle => {
            // Show homepage
            drawHomePage(x, draw_y, width);
        },
        .loading => {
            font.drawString(x, draw_y, "Loading...", COLOR_TEXT, null);
        },
        .error_state => {
            font.drawString(x, draw_y, "Error loading page", graphics.Color.rgb(255, 100, 100), null);
        },
        .loaded => {
            // Draw title
            if (current_doc.title_len > 0) {
                font.drawString(x, draw_y, current_doc.getTitle(), COLOR_HEADING, null);
                draw_y += line_height + 8;
            }

            // Draw elements
            var i: usize = 0;
            while (i < current_doc.element_count and draw_y < max_y) : (i += 1) {
                const elem = &current_doc.elements[i];

                // Skip if above viewport
                if (draw_y + line_height < y) {
                    if (elem.is_block) draw_y += line_height;
                    continue;
                }

                switch (elem.elem_type) {
                    .h1 => {
                        draw_y += 8;
                        font.drawString(x, draw_y, elem.getText(), COLOR_HEADING, null);
                        draw_y += line_height + 8;
                    },
                    .h2, .h3 => {
                        draw_y += 4;
                        font.drawString(x, draw_y, elem.getText(), COLOR_HEADING, null);
                        draw_y += line_height + 4;
                    },
                    .p, .div => {
                        draw_y += 4;
                    },
                    .br => {
                        draw_y += line_height;
                    },
                    .hr => {
                        draw_y += 4;
                        graphics.drawHLine(x, draw_y, width, graphics.DARK_GRAY);
                        draw_y += 8;
                    },
                    .li => {
                        font.drawString(x, draw_y, "* ", COLOR_TEXT, null);
                        font.drawString(x + 16, draw_y, elem.getText(), COLOR_TEXT, null);
                        draw_y += line_height;
                    },
                    .a => {
                        const is_selected = (link_count == selected_link);
                        const color = if (is_selected) COLOR_LINK_SELECTED else COLOR_LINK;
                        font.drawString(x, draw_y, elem.getText(), color, null);
                        if (is_selected and elem.href_len > 0) {
                            // Show link URL in status
                            setStatus(elem.getHref());
                        }
                        link_count += 1;
                        draw_y += line_height;
                    },
                    .text => {
                        // Word wrap text
                        const text = elem.getText();
                        var text_x = x;
                        var word_start: usize = 0;

                        var j: usize = 0;
                        while (j <= text.len) : (j += 1) {
                            const is_end = (j == text.len);
                            const is_space = (!is_end and (text[j] == ' ' or text[j] == '\n'));

                            if (is_end or is_space) {
                                const word = text[word_start..j];
                                const word_width = @as(i32, @intCast(word.len * 8));

                                // Check if word fits on current line
                                if (text_x + word_width > x + @as(i32, @intCast(chars_per_line * 8))) {
                                    draw_y += line_height;
                                    text_x = x;
                                }

                                if (draw_y >= y and draw_y < max_y) {
                                    font.drawString(text_x, draw_y, word, COLOR_TEXT, null);
                                }
                                text_x += word_width + 8; // Add space

                                word_start = j + 1;
                            }
                        }
                        draw_y += line_height;
                    },
                    else => {},
                }
            }
        },
    }
}

fn drawHomePage(x: i32, y: i32, width: u32) void {
    _ = width;
    var draw_y = y;

    font.drawString(x, draw_y, "HomeBrowser", COLOR_HEADING, null);
    draw_y += 24;

    font.drawString(x, draw_y, "Privacy-First Web Browser", COLOR_TEXT, null);
    draw_y += 20;

    font.drawString(x, draw_y, "Version 0.31.0", graphics.DARK_GRAY, null);
    draw_y += 24;

    // Tor status
    font.drawString(x, draw_y, "Tor: ", COLOR_TEXT, null);
    if (tor.getStatus() == .connected) {
        font.drawString(x + 40, draw_y, "Connected", COLOR_TOR_ON, null);
    } else {
        font.drawString(x + 40, draw_y, "Disabled", COLOR_TOR_OFF, null);
    }
    draw_y += 20;

    // Bookmarks
    draw_y += 8;
    font.drawString(x, draw_y, "Bookmarks:", COLOR_HEADING, null);
    draw_y += 16;

    var i: usize = 0;
    while (i < bookmark_count) : (i += 1) {
        const is_selected = (i == selected_link);
        const color = if (is_selected) COLOR_LINK_SELECTED else COLOR_LINK;
        font.drawString(x + 8, draw_y, bookmarks[i][0..bookmark_lens[i]], color, null);
        draw_y += 14;
    }
    link_count = bookmark_count;

    draw_y += 16;
    font.drawString(x, draw_y, "Controls:", graphics.DARK_GRAY, null);
    draw_y += 14;
    font.drawString(x, draw_y, "  Enter - Go to URL / Open link", graphics.DARK_GRAY, null);
    draw_y += 12;
    font.drawString(x, draw_y, "  Tab - Focus URL bar", graphics.DARK_GRAY, null);
    draw_y += 12;
    font.drawString(x, draw_y, "  Up/Down - Select link", graphics.DARK_GRAY, null);
    draw_y += 12;
    font.drawString(x, draw_y, "  T - Toggle Tor", graphics.DARK_GRAY, null);
    draw_y += 12;
    font.drawString(x, draw_y, "  PgUp/PgDn - Scroll", graphics.DARK_GRAY, null);
}

/// Handle keyboard input
pub fn handleKey(key: u8) void {
    if (key == '\t') {
        // Toggle URL bar focus
        url_bar_focused = !url_bar_focused;
        return;
    }

    if (key == 't' or key == 'T') {
        // Toggle Tor
        if (tor.getStatus() == .connected) {
            tor.disable();
            tor_enabled = false;
            setStatus("Tor disabled");
        } else {
            if (tor.enable()) {
                tor_enabled = true;
                setStatus("Tor enabled");
            } else {
                setStatus("Tor failed to connect");
            }
        }
        return;
    }

    if (url_bar_focused) {
        // URL bar input
        if (key == 8) { // Backspace
            if (url_bar_len > 0) {
                url_bar_len -= 1;
            }
        } else if (key == '\n' or key == '\r') {
            // Navigate to URL
            navigate(url_bar[0..url_bar_len]);
            url_bar_focused = false;
        } else if (key >= 32 and key < 127) {
            if (url_bar_len < 250) {
                url_bar[url_bar_len] = key;
                url_bar_len += 1;
            }
        }
    } else {
        // Page navigation
        if (key == keyboard.KEY_UP) {
            if (selected_link > 0) selected_link -= 1;
        } else if (key == keyboard.KEY_DOWN) {
            if (link_count > 0 and selected_link < link_count - 1) {
                selected_link += 1;
            }
        } else if (key == keyboard.KEY_PAGE_UP) {
            if (scroll_y > 50) scroll_y -= 50 else scroll_y = 0;
        } else if (key == keyboard.KEY_PAGE_DOWN) {
            scroll_y += 50;
        } else if (key == '\n' or key == '\r') {
            // Activate selected link
            activateLink();
        } else if (key == keyboard.KEY_HOME) {
            scroll_y = 0;
        }
    }
}

fn navigate(url: []const u8) void {
    if (url.len == 0) return;

    // Check for special URLs
    if (strStartsWith(url, "about:")) {
        if (strEql(url, "about:home")) {
            browser_state = .idle;
            scroll_y = 0;
            selected_link = 0;
            setStatus("Home");
            return;
        }
    }

    serial.write("Browser: Navigating to ");
    serial.write(url);
    serial.write("\n");

    // Copy URL to bar
    const len = @min(url.len, 255);
    for (url[0..len], 0..) |c, i| {
        url_bar[i] = c;
    }
    url_bar_len = len;

    // Start HTTP request
    browser_state = .loading;
    scroll_y = 0;
    selected_link = 0;
    setStatus("Loading...");

    if (http.get(url)) {
        setStatus("Connecting...");
    } else {
        browser_state = .error_state;
        setStatus("Failed to connect");
    }
}

fn activateLink() void {
    if (browser_state == .idle) {
        // Homepage - bookmarks
        if (selected_link < bookmark_count) {
            navigate(bookmarks[selected_link][0..bookmark_lens[selected_link]]);
        }
    } else if (browser_state == .loaded) {
        // Find selected link in document
        var link_idx: usize = 0;
        var i: usize = 0;
        while (i < current_doc.element_count) : (i += 1) {
            if (current_doc.elements[i].elem_type == .a) {
                if (link_idx == selected_link) {
                    const href = current_doc.elements[i].getHref();
                    if (href.len > 0) {
                        navigate(href);
                    }
                    return;
                }
                link_idx += 1;
            }
        }
    }
}

/// Update browser state (call from main loop)
pub fn update() void {
    if (browser_state == .loading) {
        http.update();

        if (http.isComplete()) {
            const response = http.getResponse();
            if (response.status_code >= 200 and response.status_code < 400) {
                // Parse HTML
                if (response.headers_end < response.body_len) {
                    const body = response.body[response.headers_end..response.body_len];
                    html.parse(body, &current_doc);
                }
                browser_state = .loaded;
                setStatus("Done");
            } else {
                browser_state = .error_state;
                setStatus("HTTP Error");
            }
            http.reset();
        } else if (http.isError()) {
            browser_state = .error_state;
            setStatus("Connection failed");
            http.reset();
        }
    }
}

/// Handle mouse click
pub fn handleClick(win: *const Window, mx: i32, my: i32) void {
    const rel_x = mx - win.x - 6;
    const rel_y = my - win.y - @as(i32, @intCast(window.TITLE_BAR_HEIGHT)) - 6;

    // Check toolbar buttons
    if (rel_y >= 4 and rel_y <= 24) {
        if (rel_x >= 4 and rel_x <= 24) {
            // Back button (not implemented)
        } else if (rel_x >= 28 and rel_x <= 48) {
            // Forward button (not implemented)
        } else if (rel_x >= 52 and rel_x <= 72) {
            // Refresh
            if (url_bar_len > 0) {
                navigate(url_bar[0..url_bar_len]);
            }
        } else if (rel_x >= 80 and rel_x <= 112) {
            // Tor toggle
            if (tor.getStatus() == .connected) {
                tor.disable();
                tor_enabled = false;
            } else {
                _ = tor.enable();
                tor_enabled = true;
            }
        } else if (rel_x >= 120) {
            // URL bar clicked
            url_bar_focused = true;
        }
    }
}

fn strEql(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    for (a, b) |ca, cb| {
        if (ca != cb) return false;
    }
    return true;
}

fn strStartsWith(str: []const u8, prefix: []const u8) bool {
    if (str.len < prefix.len) return false;
    for (prefix, 0..) |c, i| {
        if (str[i] != c) return false;
    }
    return true;
}
