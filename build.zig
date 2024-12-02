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
    
    // Add platform-specific Node.js headers
    if (is_macos) {
        if (is_arm) {
            // ARM Mac paths
            lib.addIncludePath(.{ .cwd_relative = "/opt/homebrew/include/node" });
            lib.addIncludePath(.{ .cwd_relative = b.fmt("/Users/{s}/Library/Caches/node-gyp/{s}/include/node", .{
                node_info.username, node_info.version
            }) });
        } else {
            // Intel Mac paths
            lib.addIncludePath(.{ .cwd_relative = "/usr/local/include/node" });
            lib.addIncludePath(.{ .cwd_relative = b.fmt("/Users/{s}/Library/Caches/node-gyp/{s}/include/node", .{
                node_info.username, node_info.version
            }) });
        }
    } else if (is_linux) {
        // Linux paths
        lib.addIncludePath(.{ .cwd_relative = "/usr/include/node" });
        lib.addIncludePath(.{ .cwd_relative = b.fmt("/home/{s}/.cache/node-gyp/{s}/include/node", .{
            node_info.username, node_info.version
        }) });
    }

    // Link with libc
    lib.linkLibC();

    // Platform-specific settings
    if (is_macos) {
        lib.linker_allow_shlib_undefined = true;
        if (is_arm) {
            lib.addRPath(.{ .cwd_relative = "/opt/homebrew/lib" });
        }
    }

    const install_lib = b.addInstallArtifact(lib, .{});
    b.getInstallStep().dependOn(&install_lib.step);
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