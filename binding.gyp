{
  "targets": [
    {
      "target_name": "tik-forge",
      "sources": [ "src/lib.zig" ],
      "include_dirs": [
        "<!@(node -p \"require('node-addon-api').include\")",
        "<!(node -p \"require('node-api-headers').include_dir\")"
      ],
      "dependencies": [
        "<!(node -p \"require('node-addon-api').gyp\")"
      ],
      "conditions": [
        ['OS=="win"', {
          "libraries": [
            "-L<(module_root_dir)/zig-out/zig-out/lib",
            "<(module_root_dir)/zig-out/zig-out/lib/tik-forge.dll.lib"
          ]
        }],
        ['OS=="mac"', {
          "libraries": [
            "<(module_root_dir)/zig-out/zig-out/lib/libtik-forge.node.dylib"
          ],
          "xcode_settings": {
            "OTHER_LDFLAGS": [
              "-Wl,-rpath,@loader_path/../../zig-out/zig-out/lib",
              "-Wl,-rpath,@loader_path/../zig-out/zig-out/lib",
              "-Wl,-rpath,@loader_path/"
            ]
          }
        }],
        ['OS=="linux"', {
          "libraries": [
            "<(module_root_dir)/zig-out/zig-out/lib/libtik-forge.node.so"
          ],
          "ldflags": [
            "-Wl,-rpath,'$$ORIGIN'"
          ]
        }]
      ],
      "cflags!": [ "-fno-exceptions" ],
      "cflags_cc!": [ "-fno-exceptions" ],
      "defines": [ "NAPI_DISABLE_CPP_EXCEPTIONS" ]
    }
  ]
}