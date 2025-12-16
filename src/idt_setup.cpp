// Home OS - IDT Setup in C++ (workaround for Zig extern function pointer issue)
// Copyright © 2025 Romy Rianata - Home OS

#include <stdint.h>

// IDT Entry structure
struct IDTEntry {
    uint16_t offset_low;
    uint16_t selector;
    uint8_t zero;
    uint8_t type_attr;
    uint16_t offset_high;
} __attribute__((packed));

// IDT Pointer structure
struct IDTPtr {
    uint16_t limit;
    uint32_t base;
} __attribute__((packed));

// External ISR stubs from assembly
extern "C" {
    void isr0(); void isr1(); void isr2(); void isr3();
    void isr4(); void isr5(); void isr6(); void isr7();
    void isr8(); void isr9(); void isr10(); void isr11();
    void isr12(); void isr13(); void isr14(); void isr15();
    void isr16(); void isr17(); void isr18(); void isr19();
    void isr20(); void isr21(); void isr22(); void isr23();
    void isr24(); void isr25(); void isr26(); void isr27();
    void isr28(); void isr29(); void isr30(); void isr31();
    
    void irq0(); void irq1(); void irq2(); void irq3();
    void irq4(); void irq5(); void irq6(); void irq7();
    void irq8(); void irq9(); void irq10(); void irq11();
    void irq12(); void irq13(); void irq14(); void irq15();
    
    // Syscall handler (INT 0x80)
    void isr128();
    
    void serial_write_cstr(const char* str);
}

// IDT array (256 entries)
static IDTEntry idt[256] __attribute__((aligned(16)));
static IDTPtr idt_ptr;

// Set an IDT gate
static void setGate(uint8_t num, void (*handler)(), uint16_t selector, uint8_t flags) {
    uint32_t addr = (uint32_t)handler;
    idt[num].offset_low = addr & 0xFFFF;
    idt[num].selector = selector;
    idt[num].zero = 0;
    idt[num].type_attr = flags;
    idt[num].offset_high = (addr >> 16) & 0xFFFF;
}

// Setup all IDT gates
extern "C" void cpp_setup_idt() {
    // Clear IDT
    for(int i = 0; i < 256; i++) {
        idt[i].offset_low = 0;
        idt[i].selector = 0;
        idt[i].zero = 0;
        idt[i].type_attr = 0;
        idt[i].offset_high = 0;
    }
    
    // CPU Exceptions (0-31)
    setGate(0, isr0, 0x08, 0x8E);
    setGate(1, isr1, 0x08, 0x8E);
    setGate(2, isr2, 0x08, 0x8E);
    setGate(3, isr3, 0x08, 0x8E);
    setGate(4, isr4, 0x08, 0x8E);
    setGate(5, isr5, 0x08, 0x8E);
    setGate(6, isr6, 0x08, 0x8E);
    setGate(7, isr7, 0x08, 0x8E);
    setGate(8, isr8, 0x08, 0x8E);
    setGate(9, isr9, 0x08, 0x8E);
    setGate(10, isr10, 0x08, 0x8E);
    setGate(11, isr11, 0x08, 0x8E);
    setGate(12, isr12, 0x08, 0x8E);
    setGate(13, isr13, 0x08, 0x8E);
    setGate(14, isr14, 0x08, 0x8E);
    setGate(15, isr15, 0x08, 0x8E);
    setGate(16, isr16, 0x08, 0x8E);
    setGate(17, isr17, 0x08, 0x8E);
    setGate(18, isr18, 0x08, 0x8E);
    setGate(19, isr19, 0x08, 0x8E);
    setGate(20, isr20, 0x08, 0x8E);
    setGate(21, isr21, 0x08, 0x8E);
    setGate(22, isr22, 0x08, 0x8E);
    setGate(23, isr23, 0x08, 0x8E);
    setGate(24, isr24, 0x08, 0x8E);
    setGate(25, isr25, 0x08, 0x8E);
    setGate(26, isr26, 0x08, 0x8E);
    setGate(27, isr27, 0x08, 0x8E);
    setGate(28, isr28, 0x08, 0x8E);
    setGate(29, isr29, 0x08, 0x8E);
    setGate(30, isr30, 0x08, 0x8E);
    setGate(31, isr31, 0x08, 0x8E);
    
    // Hardware IRQs (32-47)
    setGate(32, irq0, 0x08, 0x8E);
    setGate(33, irq1, 0x08, 0x8E);
    setGate(34, irq2, 0x08, 0x8E);
    setGate(35, irq3, 0x08, 0x8E);
    setGate(36, irq4, 0x08, 0x8E);
    setGate(37, irq5, 0x08, 0x8E);
    setGate(38, irq6, 0x08, 0x8E);
    setGate(39, irq7, 0x08, 0x8E);
    setGate(40, irq8, 0x08, 0x8E);
    setGate(41, irq9, 0x08, 0x8E);
    setGate(42, irq10, 0x08, 0x8E);
    setGate(43, irq11, 0x08, 0x8E);
    setGate(44, irq12, 0x08, 0x8E);
    setGate(45, irq13, 0x08, 0x8E);
    setGate(46, irq14, 0x08, 0x8E);
    setGate(47, irq15, 0x08, 0x8E);
    
    // Syscall interrupt (0x80 = 128)
    // DPL=3 (0xEE) allows Ring 3 to call this interrupt
    setGate(128, isr128, 0x08, 0xEE);
    
    // Setup IDT pointer
    idt_ptr.limit = sizeof(idt) - 1;
    idt_ptr.base = (uint32_t)&idt;
    
    // Load IDT
    asm volatile("lidt (%0)" : : "r"(&idt_ptr));
    
    serial_write_cstr("IDT: Ready\n");
}
