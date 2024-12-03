const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const target_info = target.result;
    const is_macos = target_info.os.tag == .macos;
    const is_linux = target_info.os.tag == .linux;
    const is_arm = target_info.cpu.arch == .aarch64;
    const is_x64 = target_info.cpu.arch == .x86_64;

    if (!is_x64 and !is_arm) {
        @panic("Unsupported CPU architecture. Only x64 and ARM64 are supported.");
    }

    if (!is_macos and !is_linux) {
        @panic("Unsupported operating system. Only macOS and Linux are supported.");
    }

    const lib = b.addSharedLibrary(.{
        .name = "tik-forge.node",
        .root_source_file = .{ .cwd_relative = "src/lib.zig" },
        .target = target,
        .optimize = optimize,
    });

    // Add Node.js headers
    const node_api_headers = b.pathJoin(&.{
        "node_modules",
        "node-api-headers",
        "include",
    });
    const node_addon_api = b.pathJoin(&.{
        "node_modules",
        "node-addon-api",
    });

    lib.addIncludePath(.{ .cwd_relative = node_api_headers });
    lib.addIncludePath(.{ .cwd_relative = node_addon_api });
    lib.addIncludePath(.{ .cwd_relative = b.pathJoin(&.{ node_addon_api, "src" }) });
    lib.addIncludePath(.{ .cwd_relative = b.pathJoin(&.{ node_addon_api, "external-napi" }) });

    // เพิ่มการค้นหา node_api.h จาก node installation
    const node_include = b.pathJoin(&.{
        "/usr/local/include/node",  // สำหรับ Node.js ที่ติดตั้งผ่าน Homebrew
    });
    lib.addIncludePath(.{ .cwd_relative = node_include });

    if (is_macos) {
        const sdk_path = "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk";
        
        lib.addSystemIncludePath(.{ .cwd_relative = b.pathJoin(&.{ sdk_path, "usr/include" }) });
        lib.addSystemIncludePath(.{ .cwd_relative = b.pathJoin(&.{ sdk_path, "usr/lib" }) });
        
        lib.addFrameworkPath(.{ .cwd_relative = b.pathJoin(&.{ sdk_path, "System/Library/Frameworks" }) });
        lib.addLibraryPath(.{ .cwd_relative = b.pathJoin(&.{ sdk_path, "usr/lib" }) });
        
        lib.linkSystemLibrary("System");
        lib.linkFramework("CoreFoundation");
        lib.linkFramework("CoreServices");
        
        lib.install_name = "@rpath/libtik-forge.dylib";
        lib.bundle_compiler_rt = true;
        lib.linker_allow_shlib_undefined = true;

        lib.defineCMacro("NAPI_EXTERN", "__attribute__((weak))");
        lib.defineCMacro("NAPI_MODULE_EXPORT", "__attribute__((visibility(\"default\")))");
    } else if (is_linux) {
        lib.defineCMacro("NAPI_EXTERN", "__attribute__((weak))");
        lib.defineCMacro("NAPI_MODULE_EXPORT", "__attribute__((visibility(\"default\")))");
    }

    // Common settings
    lib.linkLibC();
    lib.defineCMacro("NAPI_VERSION", "8");
    lib.defineCMacro("NODE_GYP_MODULE_NAME", "tik-forge");

    // Set install step with correct output path
    const install_lib = b.addInstallArtifact(lib, .{
        .dest_dir = .{ .override = .{ .custom = "zig-out/lib" } },
    });

    // กำหนดชื่อไฟล์ output ให้ตรงกับที่ script ต้องการ
    if (is_macos) {
        lib.out_filename = "libtik-forge.node.dylib";
    } else if (is_linux) {
        lib.out_filename = "libtik-forge.node.so";
    }

    b.getInstallStep().dependOn(&install_lib.step);
}