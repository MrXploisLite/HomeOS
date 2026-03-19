#![no_std]
#![no_main]

use core::panic::PanicInfo;

#[no_mangle]
pub extern "C" fn rust_math_multiply(a: u32, b: u32) -> u32 {
    // A simple, safe wrapping multiplication exposed to Zig
    a.wrapping_mul(b)
}

#[no_mangle]
pub extern "C" fn rust_calculate_fibonacci(n: u32) -> u32 {
    let mut a: u32 = 0;
    let mut b: u32 = 1;
    for _ in 0..n {
        let temp = a;
        a = b;
        b = a.wrapping_add(temp);
    }
    a
}

// Emergency bare-metal panic handler
#[panic_handler]
fn panic(_info: &PanicInfo) -> ! {
    loop {}
}
