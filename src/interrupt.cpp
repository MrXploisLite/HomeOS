// Home OS - C++ Interrupt Handlers
// Copyright © 2025 Romy Rianata - Home OS
// Simple, proven approach

#include <stdint.h>

// External functions from Zig
extern "C" void serial_write_cstr(const char* str);
extern "C" void keyboard_handleInterrupt();
extern "C" void pit_handleTick();

// Simple tick counter in C++
static volatile uint32_t timer_ticks = 0;

// Timer handler (called from IRQ0 stub)
extern "C" void timer_handler() {
    timer_ticks++;
    // Call Zig PIT handler for uptime tracking
    pit_handleTick();
}

// Keyboard handler (called from IRQ1 stub)
extern "C" void keyboard_handler() {
    // Remove debug output to reduce overhead
    keyboard_handleInterrupt();
}
