const std = @import("std");

pub fn build(b: *std.Build) void {
    // 64-Bit Arch Target
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
    
    // Memory Linking Strategy for Higher Half
    kernel.setLinkerScript(b.path("src/linker.ld"));
    kernel.pie = false;
    kernel.root_module.code_model = .kernel;

    b.installArtifact(kernel);

    // Iso Generation Pipelines
    const create_iso_dir = b.addSystemCommand(&.{ "mkdir", "-p", "iso_root/boot/limine" });
    const copy_kernel = b.addSystemCommand(&.{ "cp", "zig-out/bin/kernel.elf", "iso_root/boot/" });
    const copy_limine_conf = b.addSystemCommand(&.{ "cp", "src/limine.conf", "iso_root/boot/limine/" });
    const copy_limine_bin = b.addSystemCommand(&.{ "cp", "limine_binary/limine-bios.sys", "limine_binary/limine-bios-cd.bin", "limine_binary/limine-uefi-cd.bin", "iso_root/boot/limine/" });
    
    // Construct bootable ISO image
    const xorriso = b.addSystemCommand(&[_][]const u8{
        "xorriso", "-as", "mkisofs", "-b", "boot/limine/limine-bios-cd.bin",
        "-no-emul-boot", "-boot-load-size", "4", "-boot-info-table",
        "--efi-boot", "boot/limine/limine-uefi-cd.bin",
        "-efi-boot-part", "--efi-boot-image", "--protective-msdos-label",
        "iso_root", "-o", "homeos.iso"
    });
    
    // Inject Limine stage 1 into MBR
    const install_limine = b.addSystemCommand(&.{ "./limine_binary/limine", "bios-install", "homeos.iso" });

    // Step Dependencies
    create_iso_dir.step.dependOn(&kernel.step);
    copy_kernel.step.dependOn(&create_iso_dir.step);
    copy_limine_conf.step.dependOn(&copy_kernel.step);
    copy_limine_bin.step.dependOn(&copy_limine_conf.step);
    xorriso.step.dependOn(&copy_limine_bin.step);
    install_limine.step.dependOn(&xorriso.step);

    // QEMU Launcher
    const run_qemu = b.addSystemCommand(&.{
        "qemu-system-x86_64",
        "-cdrom", "homeos.iso",
        "-m", "512M",
        "-D", "qemu.log",
        "-d", "int,guest_errors",
        "-no-reboot",
        "-no-shutdown",
    });
    run_qemu.step.dependOn(&install_limine.step);

    const run_step = b.step("run", "Run the 64-bit kernel in QEMU");
    run_step.dependOn(&run_qemu.step);
}
