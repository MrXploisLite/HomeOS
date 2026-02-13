// Home OS Build Configuration
// Copyright © 2025 Romy Rianata - Home OS

const std = @import("std");

pub fn build(b: *std.Build) void {
    // Target: x86 (32-bit) freestanding for Phase 1
    // This allows direct QEMU -kernel boot with multiboot
    // Disable SSE/MMX to avoid Invalid Opcode exceptions
    var target_query: std.Target.Query = .{
        .cpu_arch = .x86,
        .os_tag = .freestanding,
        .abi = .none,
    };
    // Disable SSE and soft float - use x87 FPU only
    target_query.cpu_features_sub = std.Target.x86.featureSet(&.{
        .sse,
        .sse2,
        .mmx,
    });
    const target = b.resolveTargetQuery(target_query);

    const optimize = b.standardOptimizeOption(.{});

    const kernel = b.addExecutable(.{
        .name = "kernel.elf",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/kernel.zig"),
            .target = target,
            .optimize = optimize,
            .red_zone = false,
            .stack_check = false,
            .omit_frame_pointer = false,
        }),
    });

    // Add assembly file for ISR stubs
    kernel.root_module.addAssemblyFile(b.path("src/isr.s"));

    // Add C++ files for interrupt handlers and IDT setup
    const cpp_flags = &[_][]const u8{
        "-m32",
        "-ffreestanding",
        "-fno-exceptions",
        "-fno-rtti",
        "-nostdlib",
        "-mno-red-zone",
        "-fno-stack-protector",
    };

    kernel.root_module.addCSourceFile(.{
        .file = b.path("src/interrupt.cpp"),
        .flags = cpp_flags,
    });

    kernel.root_module.addCSourceFile(.{
        .file = b.path("src/idt_setup.cpp"),
        .flags = cpp_flags,
    });

    kernel.setLinkerScript(b.path("linker.ld"));
    b.installArtifact(kernel);

    // Run step for QEMU
    const run_cmd = b.addSystemCommand(&[_][]const u8{
        "qemu-system-i386",
        "-kernel",
        "zig-out/bin/kernel.elf",
        "-m",
        "512M",
    });
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the kernel in QEMU");
    run_step.dependOn(&run_cmd.step);
}
