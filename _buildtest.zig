const std = @import("std");

pub fn build(b: *std.Build) void {
    // Get target and optimize options
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addSharedLibrary(.{
        .name = "tik-forge",
        .root_source_file = .{ .cwd_relative = "src/lib.zig" },
        .target = target,
        .optimize = optimize,
        .pic = true,
    });

    // Platform-specific settings
    const target_info = target.result;
    const is_windows = target_info.os.tag == .windows;
    const is_macos = target_info.os.tag == .macos;

    // Add Node.js headers based on platform
    if (is_windows) {
        lib.addIncludePath(.{ .cwd_relative = "node_modules/node-addon-api" });
        lib.addIncludePath(.{ .cwd_relative = "C:/Users/USERNAME/AppData/Local/node-gyp/Cache/20.18.1/include/node" });
    } else if (is_macos) {
        lib.addIncludePath(.{ .cwd_relative = "node_modules/node-addon-api" });
        lib.addIncludePath(.{ .cwd_relative = "/Users/weerachit/Library/Caches/node-gyp/20.18.1/include/node" });
    } else {
        // Linux
        lib.addIncludePath(.{ .cwd_relative = "node_modules/node-addon-api" });
        lib.addIncludePath(.{ .cwd_relative = "/usr/include/node" });
    }

    // Add system headers and C library
    lib.linkLibC();

    // Platform-specific linker settings
    if (is_windows) {
        lib.linkSystemLibrary("node");
    } else {
        lib.linker_allow_shlib_undefined = true;
    }

    // Optimization settings
    switch (optimize) {
        .Debug => {
            lib.bundle_compiler_rt = true;
        },
        .ReleaseSafe, .ReleaseFast, .ReleaseSmall => {
            lib.bundle_compiler_rt = false;
        },
    }

    // Install step
    const install_lib = b.addInstallArtifact(lib, .{});

    // Platform-specific copy command
    const copy_step = if (is_windows) blk: {
        break :blk b.addSystemCommand(&.{
            "cmd.exe", "/C",
            "mkdir build\\Release 2>NUL & copy zig-out\\lib\\tik-forge.dll build\\Release\\tik-forge.node",
        });
    } else if (is_macos) blk: {
        break :blk b.addSystemCommand(&.{
            "/bin/sh", "-c",
            "mkdir -p build/Release && cp zig-out/lib/libtik-forge.dylib build/Release/tik-forge.node",
        });
    } else blk: {
        break :blk b.addSystemCommand(&.{
            "/bin/sh", "-c",
            "mkdir -p build/Release && cp zig-out/lib/libtik-forge.so build/Release/tik-forge.node",
        });
    };

    // Add dependencies
    copy_step.step.dependOn(&install_lib.step);
    b.default_step.dependOn(&copy_step.step);

    // Add test step
    const main_tests = b.addTest(.{
        .root_source_file = .{ .cwd_relative = "src/lib.zig" },
        .target = target,
        .optimize = optimize,
    });

    const run_main_tests = b.addRunArtifact(main_tests);
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_main_tests.step);
} 