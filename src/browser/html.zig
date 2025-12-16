// Home OS - HTML Parser
// Copyright © 2025 Romy Rianata - Home OS
// Phase 27: Privacy Browser - Basic HTML Parser

const serial = @import("../drivers/serial.zig");

// HTML Element types
pub const ElementType = enum {
    text,
    html,
    head,
    title,
    body,
    h1,
    h2,
    h3,
    p,
    br,
    hr,
    a,
    b,
    i,
    u,
    strong,
    em,
    div,
    span,
    ul,
    ol,
    li,
    img,
    pre,
    code,
    unknown,
};

// Parsed HTML element
pub const HtmlElement = struct {
    elem_type: ElementType,
    text: [256]u8,
    text_len: usize,
    href: [128]u8, // For links
    href_len: usize,
    is_block: bool, // Block vs inline element

    pub fn init() HtmlElement {
        return HtmlElement{
            .elem_type = .text,
            .text = [_]u8{0} ** 256,
            .text_len = 0,
            .href = [_]u8{0} ** 128,
            .href_len = 0,
            .is_block = false,
        };
    }

    pub fn setText(self: *HtmlElement, text: []const u8) void {
        const len = @min(text.len, 255);
        for (text[0..len], 0..) |c, i| {
            self.text[i] = c;
        }
        self.text_len = len;
    }

    pub fn setHref(self: *HtmlElement, href: []const u8) void {
        const len = @min(href.len, 127);
        for (href[0..len], 0..) |c, i| {
            self.href[i] = c;
        }
        self.href_len = len;
    }

    pub fn getText(self: *const HtmlElement) []const u8 {
        return self.text[0..self.text_len];
    }

    pub fn getHref(self: *const HtmlElement) []const u8 {
        return self.href[0..self.href_len];
    }
};

// Parsed document
pub const MAX_ELEMENTS: usize = 128;

pub const HtmlDocument = struct {
    title: [64]u8,
    title_len: usize,
    elements: [MAX_ELEMENTS]HtmlElement,
    element_count: usize,

    pub fn init() HtmlDocument {
        var doc = HtmlDocument{
            .title = [_]u8{0} ** 64,
            .title_len = 0,
            .elements = undefined,
            .element_count = 0,
        };
        for (&doc.elements) |*e| {
            e.* = HtmlElement.init();
        }
        return doc;
    }

    pub fn setTitle(self: *HtmlDocument, title: []const u8) void {
        const len = @min(title.len, 63);
        for (title[0..len], 0..) |c, i| {
            self.title[i] = c;
        }
        self.title_len = len;
    }

    pub fn getTitle(self: *const HtmlDocument) []const u8 {
        return self.title[0..self.title_len];
    }

    pub fn addElement(self: *HtmlDocument, elem: HtmlElement) bool {
        if (self.element_count >= MAX_ELEMENTS) return false;
        self.elements[self.element_count] = elem;
        self.element_count += 1;
        return true;
    }
};

// Parser state
const ParserState = enum {
    text,
    tag_open,
    tag_name,
    tag_attr,
    tag_close,
};

// Parse HTML string into document
pub fn parse(html: []const u8, doc: *HtmlDocument) void {
    doc.* = HtmlDocument.init();

    var state: ParserState = .text;
    var text_start: usize = 0;
    var tag_start: usize = 0;
    var in_title: bool = false;
    var in_body: bool = false;
    var current_link: [128]u8 = [_]u8{0} ** 128;
    var current_link_len: usize = 0;
    var in_link: bool = false;
    var is_closing_tag: bool = false;
    var current_tag: ElementType = .unknown;

    var i: usize = 0;
    while (i < html.len) : (i += 1) {
        const c = html[i];

        switch (state) {
            .text => {
                if (c == '<') {
                    // End of text, start of tag
                    if (i > text_start) {
                        const text = html[text_start..i];
                        const trimmed = trimWhitespace(text);
                        if (trimmed.len > 0) {
                            if (in_title) {
                                doc.setTitle(trimmed);
                            } else if (in_body) {
                                var elem = HtmlElement.init();
                                elem.elem_type = if (in_link) .a else .text;
                                elem.setText(trimmed);
                                if (in_link and current_link_len > 0) {
                                    elem.setHref(current_link[0..current_link_len]);
                                }
                                _ = doc.addElement(elem);
                            }
                        }
                    }
                    state = .tag_open;
                    tag_start = i + 1;
                    is_closing_tag = false;
                }
            },
            .tag_open => {
                if (c == '/') {
                    is_closing_tag = true;
                    tag_start = i + 1;
                }
                state = .tag_name;
            },
            .tag_name => {
                if (c == '>' or c == ' ' or c == '\t' or c == '\n' or c == '\r') {
                    const tag_name = html[tag_start..i];
                    current_tag = getTagType(tag_name);

                    if (is_closing_tag) {
                        // Handle closing tags
                        if (current_tag == .title) in_title = false;
                        if (current_tag == .a) {
                            in_link = false;
                            current_link_len = 0;
                        }
                        if (current_tag == .body) in_body = false;
                    } else {
                        // Handle opening tags
                        if (current_tag == .title) in_title = true;
                        if (current_tag == .body) in_body = true;

                        // Add block elements
                        if (in_body and isBlockElement(current_tag)) {
                            var elem = HtmlElement.init();
                            elem.elem_type = current_tag;
                            elem.is_block = true;
                            _ = doc.addElement(elem);
                        }
                    }

                    if (c == '>') {
                        state = .text;
                        text_start = i + 1;
                    } else {
                        state = .tag_attr;
                    }
                }
            },
            .tag_attr => {
                // Look for href="..."
                if (c == 'h' and i + 5 < html.len) {
                    if (html[i .. i + 5][0] == 'h' and html[i .. i + 5][1] == 'r' and
                        html[i .. i + 5][2] == 'e' and html[i .. i + 5][3] == 'f' and
                        html[i .. i + 5][4] == '=')
                    {
                        i += 5;
                        // Skip quote
                        if (i < html.len and (html[i] == '"' or html[i] == '\'')) {
                            const quote = html[i];
                            i += 1;
                            const href_start = i;
                            while (i < html.len and html[i] != quote) : (i += 1) {}
                            const href = html[href_start..i];
                            const len = @min(href.len, 127);
                            for (href[0..len], 0..) |ch, j| {
                                current_link[j] = ch;
                            }
                            current_link_len = len;
                            in_link = true;
                        }
                    }
                }
                if (c == '>') {
                    state = .text;
                    text_start = i + 1;
                }
            },
            .tag_close => {
                if (c == '>') {
                    state = .text;
                    text_start = i + 1;
                }
            },
        }
    }

    // Handle remaining text
    if (state == .text and i > text_start) {
        const text = html[text_start..i];
        const trimmed = trimWhitespace(text);
        if (trimmed.len > 0 and in_body) {
            var elem = HtmlElement.init();
            elem.elem_type = .text;
            elem.setText(trimmed);
            _ = doc.addElement(elem);
        }
    }
}

// Get element type from tag name
fn getTagType(name: []const u8) ElementType {
    if (name.len == 0) return .unknown;

    // Convert to lowercase for comparison
    var lower: [16]u8 = undefined;
    const len = @min(name.len, 15);
    for (name[0..len], 0..) |c, i| {
        lower[i] = if (c >= 'A' and c <= 'Z') c + 32 else c;
    }
    const tag = lower[0..len];

    if (strEql(tag, "html")) return .html;
    if (strEql(tag, "head")) return .head;
    if (strEql(tag, "title")) return .title;
    if (strEql(tag, "body")) return .body;
    if (strEql(tag, "h1")) return .h1;
    if (strEql(tag, "h2")) return .h2;
    if (strEql(tag, "h3")) return .h3;
    if (strEql(tag, "p")) return .p;
    if (strEql(tag, "br")) return .br;
    if (strEql(tag, "hr")) return .hr;
    if (strEql(tag, "a")) return .a;
    if (strEql(tag, "b")) return .b;
    if (strEql(tag, "i")) return .i;
    if (strEql(tag, "u")) return .u;
    if (strEql(tag, "strong")) return .strong;
    if (strEql(tag, "em")) return .em;
    if (strEql(tag, "div")) return .div;
    if (strEql(tag, "span")) return .span;
    if (strEql(tag, "ul")) return .ul;
    if (strEql(tag, "ol")) return .ol;
    if (strEql(tag, "li")) return .li;
    if (strEql(tag, "img")) return .img;
    if (strEql(tag, "pre")) return .pre;
    if (strEql(tag, "code")) return .code;

    return .unknown;
}

fn isBlockElement(elem_type: ElementType) bool {
    return switch (elem_type) {
        .h1, .h2, .h3, .p, .div, .ul, .ol, .li, .hr, .br, .pre => true,
        else => false,
    };
}

fn strEql(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    for (a, b) |ca, cb| {
        if (ca != cb) return false;
    }
    return true;
}

fn trimWhitespace(s: []const u8) []const u8 {
    var start: usize = 0;
    var end: usize = s.len;

    while (start < end and isWhitespace(s[start])) : (start += 1) {}
    while (end > start and isWhitespace(s[end - 1])) : (end -= 1) {}

    return s[start..end];
}

fn isWhitespace(c: u8) bool {
    return c == ' ' or c == '\t' or c == '\n' or c == '\r';
}

// Decode HTML entities
pub fn decodeEntities(text: []const u8, out: []u8) usize {
    var out_len: usize = 0;
    var i: usize = 0;

    while (i < text.len and out_len < out.len) {
        if (text[i] == '&' and i + 2 < text.len) {
            // Check for common entities
            if (i + 4 <= text.len and text[i + 1] == 'l' and text[i + 2] == 't' and text[i + 3] == ';') {
                out[out_len] = '<';
                out_len += 1;
                i += 4;
                continue;
            }
            if (i + 4 <= text.len and text[i + 1] == 'g' and text[i + 2] == 't' and text[i + 3] == ';') {
                out[out_len] = '>';
                out_len += 1;
                i += 4;
                continue;
            }
            if (i + 5 <= text.len and text[i + 1] == 'a' and text[i + 2] == 'm' and text[i + 3] == 'p' and text[i + 4] == ';') {
                out[out_len] = '&';
                out_len += 1;
                i += 5;
                continue;
            }
            if (i + 6 <= text.len and text[i + 1] == 'n' and text[i + 2] == 'b' and text[i + 3] == 's' and text[i + 4] == 'p' and text[i + 5] == ';') {
                out[out_len] = ' ';
                out_len += 1;
                i += 6;
                continue;
            }
            if (i + 6 <= text.len and text[i + 1] == 'q' and text[i + 2] == 'u' and text[i + 3] == 'o' and text[i + 4] == 't' and text[i + 5] == ';') {
                out[out_len] = '"';
                out_len += 1;
                i += 6;
                continue;
            }
        }
        out[out_len] = text[i];
        out_len += 1;
        i += 1;
    }

    return out_len;
}
