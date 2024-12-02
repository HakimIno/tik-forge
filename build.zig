const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const target_info = target.result;
    const is_windows = target_info.os.tag == .windows;
    const is_macos = target_info.os.tag == .macos;
    const is_linux = target_info.os.tag == .linux;
    const is_arm = target_info.cpu.arch == .aarch64;
    const is_x64 = target_info.cpu.arch == .x86_64;

    if (!is_x64 and !is_arm) {
        @panic("Unsupported CPU architecture. Only x64 and ARM64 are supported.");
    }

    if (!is_windows and !is_macos and !is_linux) {
        @panic("Unsupported operating system. Only Windows, macOS, and Linux are supported.");
    }

    const lib = b.addSharedLibrary(.{
        .name = "tik-forge",
        .root_source_file = .{ .cwd_relative = "src/lib.zig" },
        .target = target,
        .optimize = optimize,
    });

    // Add Node.js headers
    lib.addIncludePath(.{ .cwd_relative = "node_modules/node-addon-api" });
    lib.addIncludePath(.{ .cwd_relative = "node_modules/node-api-headers/include" });
    lib.addIncludePath(.{ .cwd_relative = "node_modules/node-api-headers/include/node" });
    
    // Add system headers for each platform
    if (is_macos) {
        const sdk_path = "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk";
        lib.addSystemIncludePath(.{ .cwd_relative = b.pathJoin(&.{ sdk_path, "usr/include" }) });
        
        // Add Node.js headers from node-gyp
        lib.addIncludePath(.{ .cwd_relative = "node_modules/node-addon-api/src" });
        lib.addIncludePath(.{ .cwd_relative = "node_modules/node-addon-api/external-napi" });
    }

    // Platform-specific configurations
    if (is_windows) {
        lib.defineCMacro("NAPI_EXTERN", "__declspec(dllexport)");
        lib.defineCMacro("NAPI_MODULE_EXPORT", "__declspec(dllexport)");
        lib.defineCMacro("NAPI_VERSION", "8");
        lib.linkLibC();
    } else if (is_macos) {
        lib.defineCMacro("NAPI_EXTERN", "__attribute__((weak))");
        lib.defineCMacro("NAPI_MODULE_EXPORT", "__attribute__((visibility(\"default\")))");
        lib.defineCMacro("NAPI_VERSION", "8");
        lib.defineCMacro("NODE_GYP_MODULE_NAME", "tik-forge");
        lib.linkFramework("CoreFoundation");
        lib.linkFramework("CoreServices");
        lib.linker_allow_shlib_undefined = true;
        lib.bundle_compiler_rt = true;
        lib.linkLibC();
    } else if (is_linux) {
        lib.defineCMacro("NAPI_EXTERN", "__attribute__((weak))");
        lib.defineCMacro("NAPI_MODULE_EXPORT", "__attribute__((visibility(\"default\")))");
        lib.defineCMacro("NAPI_VERSION", "8");
        lib.linkLibC();
    }

    // Install the library
    b.installArtifact(lib);

    // Create install step
    const install_step = b.addInstallArtifact(lib, .{});

    // Create the build/Release directory
    const mkdir_step = b.addSystemCommand(&.{
        if (is_windows) "mkdir" else "mkdir",
        if (is_windows) "-p" else "-p",
        if (is_windows) "build\\Release" else "build/Release",
    });

    // Wait for install to complete
    mkdir_step.step.dependOn(&install_step.step);

    // Copy the library to build/Release with correct extension
    const copy_cmd = if (is_windows)
        &[_][]const u8{ "copy", "zig-out\\lib\\tik-forge.dll", "build\\Release\\" }
    else if (is_macos)
        &[_][]const u8{ "cp", "zig-out/lib/libtik-forge.dylib", "build/Release/" }
    else
        &[_][]const u8{ "cp", "zig-out/lib/libtik-forge.so", "build/Release/" };

    const copy_step = b.addSystemCommand(copy_cmd);

    // Wait for mkdir to complete
    copy_step.step.dependOn(&mkdir_step.step);

    // Make copy step the default
    b.getInstallStep().dependOn(&copy_step.step);
}