{
  "targets": [
    {
      "target_name": "tik-forge",
      "sources": [ "src/lib.zig" ],
      "include_dirs": [
        "<!@(node -p \"require('node-addon-api').include\")"
      ],
      "dependencies": [
        "<!(node -p \"require('node-addon-api').gyp\")"
      ],
      "conditions": [
        ['OS=="win"', {
          "libraries": [
            "-L<(module_root_dir)/zig-out/lib",
            "-ltik-forge",
            "<(module_root_dir)/zig-out/lib/tik-forge.dll.lib"
          ]
        }],
        ['OS=="mac"', {
          "libraries": [
            "-L<(module_root_dir)/zig-out/lib",
            "-ltik-forge",
            "<(module_root_dir)/zig-out/lib/libtik-forge.dylib"
          ],
          "xcode_settings": {
            "OTHER_LDFLAGS": [
              "-Wl,-rpath,@loader_path/"
            ]
          }
        }],
        ['OS=="linux"', {
          "libraries": [
            "-L<(module_root_dir)/zig-out/lib",
            "-ltik-forge",
            "<(module_root_dir)/zig-out/lib/libtik-forge.so"
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