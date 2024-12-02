const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

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

    // Create the library
    const lib = b.addSharedLibrary(.{
        .name = "tik-forge",
        .root_source_file = .{ .cwd_relative = "src/lib.zig" },
        .target = target,
        .optimize = .Debug,
    });

    // Read node info from file
    const node_info = readNodeInfo(b.allocator) catch unreachable;
    defer node_info.deinit();

    // Get Node.js headers path from node-gyp cache
    const home_dir = std.process.getEnvVarOwned(b.allocator, "HOME") catch "/Users/weerachit";
    const node_version = std.process.getEnvVarOwned(b.allocator, "NODE_VERSION") catch "20.18.1";
    const node_headers = b.pathJoin(&.{ home_dir, "Library/Caches/node-gyp", node_version, "include/node" });

    // Add only necessary include paths
    lib.addSystemIncludePath(.{ .cwd_relative = node_headers });  // node-gyp headers
    lib.addIncludePath(.{ .cwd_relative = b.pathJoin(&.{ b.pathFromRoot("node_modules/node-addon-api") }) });  // node-addon-api

    // Add macOS SDK paths
    if (is_macos) {
        const sdk_path = "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk";
        lib.addSystemIncludePath(.{ .cwd_relative = b.pathJoin(&.{ sdk_path, "usr/include" }) });
        lib.addLibraryPath(.{ .cwd_relative = b.pathJoin(&.{ sdk_path, "usr/lib" }) });
        
        // Add Node.js headers path
        lib.addSystemIncludePath(.{ .cwd_relative = b.pathJoin(&.{ home_dir, "Library/Caches/node-gyp", node_version, "include/node" }) });
        
        // Instead of linking with node library, we'll define the required Node-API symbols as weak
        lib.defineCMacro("NAPI_EXTERN", "__attribute__((weak))");
        lib.defineCMacro("NAPI_MODULE_EXPORT", "__attribute__((visibility(\"default\")))");
        
        // Add required frameworks for macOS
        lib.linkFramework("CoreFoundation");
        lib.linkFramework("CoreServices");
        
        // Set dynamic linking options
        lib.linker_allow_shlib_undefined = true;
        lib.bundle_compiler_rt = true;
    }

    // Link with libc
    lib.linkLibC();

    // Create install step
    const install_step = b.addInstallArtifact(lib, .{});

    // Create the build/Release directory
    const mkdir_step = b.addSystemCommand(&.{
        "mkdir", "-p", "build/Release",
    });

    // Wait for install to complete
    mkdir_step.step.dependOn(&install_step.step);

    // Run node-gyp rebuild first
    const node_gyp_step = b.addSystemCommand(&.{
        "node-gyp", "rebuild",
    });

    // Wait for mkdir to complete
    node_gyp_step.step.dependOn(&mkdir_step.step);

    // Copy the library to build/Release after node-gyp
    const copy_step = b.addSystemCommand(&.{
        "sh",
        "-c",
        \\cp -f zig-out/lib/libtik-forge.dylib build/Release/ && \
        \\chmod 755 build/Release/libtik-forge.dylib && \
        \\ls -la build/Release/
    });

    // Wait for node-gyp to complete
    copy_step.step.dependOn(&node_gyp_step.step);

    // Make copy step the default
    b.getInstallStep().dependOn(&copy_step.step);
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