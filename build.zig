const std = @import("std");

pub fn build(b: *std.Build) void {
    // 64-Bit bare-metal target
    const targetQuery = std.Target.Query{
        .cpu_arch = .x86_64,
        .os_tag = .freestanding,
        .abi = .none,
    };

    const target = b.resolveTargetQuery(targetQuery);
    const optimize = b.standardOptimizeOption(.{});

    // Main Kernel Executable
    const kernel = b.addExecutable(.{
        .name = "kernel.elf",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    kernel.pie = false;
    kernel.root_module.code_model = .kernel;
    kernel.setLinkerScript(b.path("src/linker.ld"));

    b.installArtifact(kernel);

    // Remap ELF virtual addresses to higher half (0xffffffff80000000)
    // Zig LLD with code_model=kernel compiles to 0x1000000 by default
    // Offset = 0xffffffff80000000 - 0x1000000 = 0xffffffff7f000000
    const remap = b.addSystemCommand(&[_][]const u8{
        "python3", "src/patch_elf.py",
        "zig-out/bin/kernel.elf",
        "zig-out/bin/kernel_hh.elf",
        "0xffffffff7f000000",
    });
    remap.step.dependOn(&kernel.step);
    b.default_step.dependOn(&remap.step);

    // ISO construction steps (use kernel_hh.elf)
    const rm_iso = b.addSystemCommand(&.{ "rm", "-rf", "iso_root" });
    const mk_dir = b.addSystemCommand(&.{ "mkdir", "-p", "iso_root/boot/limine" });
    const cp_kernel = b.addSystemCommand(&.{ "cp", "zig-out/bin/kernel_hh.elf", "iso_root/boot/kernel.elf" });
    const cp_conf = b.addSystemCommand(&.{ "cp", "src/limine.conf", "iso_root/boot/limine/" });
    const cp_limine = b.addSystemCommand(&.{
        "cp",
        "limine_binary/limine-bios.sys",
        "limine_binary/limine-bios-cd.bin",
        "limine_binary/limine-uefi-cd.bin",
        "iso_root/boot/limine/",
    });

    const xorriso = b.addSystemCommand(&[_][]const u8{
        "xorriso", "-as", "mkisofs",
        "-b", "boot/limine/limine-bios-cd.bin",
        "-no-emul-boot", "-boot-load-size", "4", "-boot-info-table",
        "--efi-boot", "boot/limine/limine-uefi-cd.bin",
        "-efi-boot-part", "--efi-boot-image", "--protective-msdos-label",
        "iso_root", "-o", "homeos.iso",
    });

    const limine_install = b.addSystemCommand(&.{
        "./limine_binary/limine", "bios-install", "homeos.iso",
    });

    // Dependency chain
    rm_iso.step.dependOn(&remap.step);
    mk_dir.step.dependOn(&rm_iso.step);
    cp_kernel.step.dependOn(&mk_dir.step);
    cp_conf.step.dependOn(&cp_kernel.step);
    cp_limine.step.dependOn(&cp_conf.step);
    xorriso.step.dependOn(&cp_limine.step);
    limine_install.step.dependOn(&xorriso.step);

    // QEMU run step
    const run_qemu = b.addSystemCommand(&.{
        "qemu-system-x86_64",
        "-cdrom", "homeos.iso",
        "-m", "512M",
        "-serial", "stdio",
        "-no-reboot",
        "-no-shutdown",
    });
    run_qemu.step.dependOn(&limine_install.step);

    const run_step = b.step("run", "Run HomeOS 64-bit in QEMU");
    run_step.dependOn(&run_qemu.step);
}
