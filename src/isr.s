# Home OS - ISR Assembly Stubs
# Copyright © 2025 Romy Rianata - Home OS
# Proper exception handling with error code support

.section .text
.code32

# External C handlers
.extern timer_handler
.extern keyboard_handler
.extern syscall_handler
.extern pic_sendEOI
.extern serial_write_cstr
.extern serial_write_int
.extern rtl8139_handleInterrupt

# CPU Exception handlers WITHOUT error code
.macro EXCEPTION_NOERR num
.global isr\num
isr\num:
    cli
    push $0                    # Push dummy error code for consistency
    push $\num                 # Push exception number
    jmp exception_common
.endm

# CPU Exception handlers WITH error code (CPU pushes error code automatically)
.macro EXCEPTION_ERR num
.global isr\num
isr\num:
    cli
    # Error code already on stack from CPU
    push $\num                 # Push exception number
    jmp exception_common
.endm

# Common exception handler
exception_common:
    pusha                      # Save all general registers
    
    # Print exception message
    push $exception_msg
    call serial_write_cstr
    add $4, %esp
    
    # Get exception number from stack (at esp+32 after pusha)
    mov 32(%esp), %eax
    push %eax
    call serial_write_int
    add $4, %esp
    
    push $newline_msg
    call serial_write_cstr
    add $4, %esp
    
    # Halt - don't try to recover from exceptions
1:
    hlt
    jmp 1b

# Exceptions 0-7: No error code
EXCEPTION_NOERR 0              # Division By Zero
EXCEPTION_NOERR 1              # Debug
EXCEPTION_NOERR 2              # NMI
EXCEPTION_NOERR 3              # Breakpoint
EXCEPTION_NOERR 4              # Overflow
EXCEPTION_NOERR 5              # Bound Range Exceeded
EXCEPTION_NOERR 6              # Invalid Opcode
EXCEPTION_NOERR 7              # Device Not Available

# Exception 8: Double Fault (has error code, always 0)
EXCEPTION_ERR 8

# Exception 9: Coprocessor Segment Overrun (no error code, legacy)
EXCEPTION_NOERR 9

# Exceptions 10-14: Have error codes
EXCEPTION_ERR 10               # Invalid TSS
EXCEPTION_ERR 11               # Segment Not Present
EXCEPTION_ERR 12               # Stack-Segment Fault
EXCEPTION_ERR 13               # General Protection Fault
EXCEPTION_ERR 14               # Page Fault

# Exception 15: Reserved
EXCEPTION_NOERR 15

# Exceptions 16-20: No error code
EXCEPTION_NOERR 16             # x87 FPU Error
EXCEPTION_ERR 17               # Alignment Check (has error code)
EXCEPTION_NOERR 18             # Machine Check
EXCEPTION_NOERR 19             # SIMD Floating-Point
EXCEPTION_NOERR 20             # Virtualization

# Exception 21: Control Protection (has error code)
EXCEPTION_ERR 21

# Exceptions 22-28: Reserved
EXCEPTION_NOERR 22
EXCEPTION_NOERR 23
EXCEPTION_NOERR 24
EXCEPTION_NOERR 25
EXCEPTION_NOERR 26
EXCEPTION_NOERR 27
EXCEPTION_NOERR 28

# Exceptions 29-30: Have error codes (newer CPUs)
EXCEPTION_ERR 29               # VMM Communication Exception
EXCEPTION_ERR 30               # Security Exception

# Exception 31: Reserved
EXCEPTION_NOERR 31

# ============================================================================
# Hardware IRQ Handlers (IRQ 0-15 mapped to INT 32-47)
# ============================================================================

# IRQ 0 - Timer (PIT) with context switching support
.extern timerTick

.global irq0
irq0:
    # Save all registers
    pusha
    
    # Save segment registers
    push %ds
    push %es
    push %fs
    push %gs
    
    # Load kernel data segment
    mov $0x10, %ax
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %fs
    mov %ax, %gs
    
    # Call timer handler
    call timer_handler
    
    # Call scheduler tick with current ESP
    push %esp
    call timerTick
    add $4, %esp
    
    # Check if context switch needed (new ESP in EAX)
    test %eax, %eax
    jz .no_switch
    
    # Context switch: use new ESP
    mov %eax, %esp
    
.no_switch:
    # Send EOI
    push $0
    call pic_sendEOI
    add $4, %esp
    
    # Restore segment registers
    pop %gs
    pop %fs
    pop %es
    pop %ds
    
    # Restore general registers
    popa
    
    iret

# IRQ 1 - Keyboard
.global irq1
irq1:
    pusha
    call keyboard_handler
    push $1
    call pic_sendEOI
    add $4, %esp
    popa
    iret

# IRQ 2 - Cascade (used internally by PICs)
.global irq2
irq2:
    pusha
    push $2
    call pic_sendEOI
    add $4, %esp
    popa
    iret

# IRQ 3 - COM2
.global irq3
irq3:
    pusha
    push $3
    call pic_sendEOI
    add $4, %esp
    popa
    iret

# IRQ 4 - COM1
.global irq4
irq4:
    pusha
    push $4
    call pic_sendEOI
    add $4, %esp
    popa
    iret

# IRQ 5 - Sound Blaster 16
.extern audio_handleInterrupt
.global irq5
irq5:
    pusha
    call audio_handleInterrupt
    push $5
    call pic_sendEOI
    add $4, %esp
    popa
    iret

# IRQ 6 - Floppy Disk
.global irq6
irq6:
    pusha
    push $6
    call pic_sendEOI
    add $4, %esp
    popa
    iret

# IRQ 7 - LPT1 / Spurious
.global irq7
irq7:
    pusha
    push $7
    call pic_sendEOI
    add $4, %esp
    popa
    iret

# IRQ 8 - CMOS Real-Time Clock
.global irq8
irq8:
    pusha
    push $8
    call pic_sendEOI
    add $4, %esp
    popa
    iret

# IRQ 9 - Free / ACPI
.global irq9
irq9:
    pusha
    push $9
    call pic_sendEOI
    add $4, %esp
    popa
    iret

# IRQ 10 - Free
.global irq10
irq10:
    pusha
    push $10
    call pic_sendEOI
    add $4, %esp
    popa
    iret

# IRQ 11 - RTL8139 Network
.global irq11
irq11:
    pusha
    call rtl8139_handleInterrupt
    push $11
    call pic_sendEOI
    add $4, %esp
    popa
    iret

# IRQ 12 - PS/2 Mouse
.extern mouse_handleInterrupt
.global irq12
irq12:
    pusha
    call mouse_handleInterrupt
    push $12
    call pic_sendEOI
    add $4, %esp
    popa
    iret

# IRQ 13 - FPU / Coprocessor
.global irq13
irq13:
    pusha
    push $13
    call pic_sendEOI
    add $4, %esp
    popa
    iret

# IRQ 14 - Primary ATA Hard Disk
.global irq14
irq14:
    pusha
    push $14
    call pic_sendEOI
    add $4, %esp
    popa
    iret

# IRQ 15 - Secondary ATA Hard Disk
.global irq15
irq15:
    pusha
    push $15
    call pic_sendEOI
    add $4, %esp
    popa
    iret

# ============================================================================
# User Mode Entry Function
# ============================================================================

.extern process_exited
.extern kernel_return_esp
.extern kernel_return_addr

# enter_user_mode_asm(entry, stack, user_cs, user_ds)
# Arguments on stack: [esp+4]=entry, [esp+8]=stack, [esp+12]=user_cs, [esp+16]=user_ds
.global enter_user_mode_asm
enter_user_mode_asm:
    # Save callee-saved registers
    push %ebp
    mov %esp, %ebp
    push %ebx
    push %esi
    push %edi
    
    # Save kernel return context
    mov %esp, kernel_return_esp
    lea .user_return_point, %eax
    mov %eax, kernel_return_addr
    
    # Get arguments
    mov 8(%ebp), %eax          # entry point
    mov 12(%ebp), %ebx         # user stack
    mov 16(%ebp), %ecx         # user_cs
    mov 20(%ebp), %edx         # user_ds
    
    # Setup user data segments
    mov %dx, %ds
    mov %dx, %es
    mov %dx, %fs
    mov %dx, %gs
    
    # Build IRET frame for Ring 3
    # Stack: SS, ESP, EFLAGS, CS, EIP
    push %edx                  # SS = user_ds
    push %ebx                  # ESP = user stack
    push $0x202                # EFLAGS (IF=1, reserved bit 1=1)
    push %ecx                  # CS = user_cs
    push %eax                  # EIP = entry point
    
    # Jump to user mode!
    iret

.user_return_point:
    # Returned from sys_exit
    # Restore kernel data segments
    mov $0x10, %ax
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %fs
    mov %ax, %gs
    
    # Restore callee-saved registers
    pop %edi
    pop %esi
    pop %ebx
    pop %ebp
    
    # Return to caller (enterUserMode in Zig)
    ret

# ============================================================================
# Syscall Handler (INT 0x80)
# ============================================================================

.global isr128
isr128:
    # Save all registers
    pusha
    
    # Push syscall arguments (from registers)
    # Syscall convention: EAX=syscall#, EBX=arg1, ECX=arg2, EDX=arg3
    push %edx                  # arg3
    push %ecx                  # arg2
    push %ebx                  # arg1
    push %eax                  # syscall number
    
    # Call C syscall handler
    call syscall_handler
    
    # Clean up arguments
    add $16, %esp
    
    # Check if process exited (sys_exit was called)
    movl process_exited, %ecx
    test %ecx, %ecx
    jnz .syscall_exit_return
    
    # Normal return: Store return value in EAX position on stack
    # After pusha, EAX is at offset 28 from ESP
    mov %eax, 28(%esp)
    
    # Restore registers (EAX will have return value)
    popa
    
    # Return to user mode
    iret

.syscall_exit_return:
    # Process called sys_exit - return to kernel
    # Restore kernel stack and jump to return address
    movl kernel_return_esp, %esp
    movl kernel_return_addr, %eax
    
    # Re-enable interrupts (they were disabled by INT)
    sti
    
    # Jump to kernel return point
    jmp *%eax

# ============================================================================
# Read-only data
# ============================================================================
.section .rodata
exception_msg:
    .asciz "CPU EXCEPTION #"
newline_msg:
    .asciz "\n"
