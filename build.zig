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
        .pic = true,
    });

    // Read node info from file
    const node_info = readNodeInfo(b.allocator) catch unreachable;
    defer node_info.deinit();

    // Add Node.js headers
    lib.addIncludePath(.{ .cwd_relative = "node_modules/node-addon-api" });
    
    // Add platform-specific Node.js headers using node_info
    if (is_macos) {
        if (is_arm) {
            // Path สำหรับ ARM Mac
            const include_path = b.fmt("/opt/homebrew/lib/node_modules/npm/node_modules/node-gyp/include/node", .{});
            lib.addIncludePath(.{ .cwd_relative = include_path });
            lib.linker_allow_shlib_undefined = true;
            lib.addRPath(.{ .cwd_relative = "/opt/homebrew/lib" });
        } else {
            // Path สำหรับ Intel Mac
            const include_path = b.fmt("/Users/{s}/Library/Caches/node-gyp/{s}/include/node", .{
                node_info.username, node_info.version
            });
            lib.addIncludePath(.{ .cwd_relative = include_path });
        }
    } else if (is_windows) {
        const include_path = b.fmt("C:/Users/{s}/AppData/Local/node-gyp/Cache/{s}/include/node", .{
            node_info.username, node_info.version
        });
        lib.addIncludePath(.{ .cwd_relative = include_path });
    } else {
        // Linux
        const include_path = b.fmt("/home/{s}/.cache/node-gyp/{s}/include/node", .{
            node_info.username, node_info.version
        });
        lib.addIncludePath(.{ .cwd_relative = include_path });
    }

    // Add system headers and C library
    lib.linkLibC();

    // Platform-specific linker settings
    if (is_macos and is_arm) {
        // ARM Mac specific settings
        lib.linker_allow_shlib_undefined = true;
    } else if (is_windows) {
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

    const install_lib = b.addInstallArtifact(lib, .{});

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

    // Add Node.js headers
    // lib.addIncludePath(.{ .cwd_relative = "/Users/weerachit/Library/Caches/node-gyp/20.18.1/include" });
    // lib.addIncludePath(.{ .cwd_relative = "node_modules/node-addon-api" });
    // lib.addIncludePath(.{ .cwd_relative = "node_modules/node-addon-api/src" });

    // Link with libc
    lib.linkLibC();

    // Set as C ABI
    lib.linkage = .dynamic;
    lib.bundle_compiler_rt = true;

    // Set install directory to build/Release
    const install_step = b.addInstallArtifact(lib, .{
        .dest_dir = .{ .override = .{ .custom = "build/Release" } },
    });

    // Make install the default step
    b.getInstallStep().dependOn(&install_step.step);
}

const NodeInfo = struct {
    version: []const u8,
    username: []const u8,
    homedir: []const u8,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *NodeInfo) void {
        self.allocator.free(self.version);
        self.allocator.free(self.username);
        self.allocator.free(self.homedir);
    }
};

fn readNodeInfo(allocator: std.mem.Allocator) !*NodeInfo {
    const file = try std.fs.cwd().openFile("node-info.txt", .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(content);

    const parsed = try std.json.parseFromSlice(
        std.json.Value,
        allocator,
        content,
        .{},
    );
    defer parsed.deinit();

    const info = try allocator.create(NodeInfo);
    info.* = .{
        .version = try allocator.dupe(u8, parsed.value.object.get("version").?.string),
        .username = try allocator.dupe(u8, parsed.value.object.get("username").?.string),
        .homedir = try allocator.dupe(u8, parsed.value.object.get("homedir").?.string),
        .allocator = allocator,
    };
    return info;
} 