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
        ['OS=="mac"', {
          "libraries": [
            "-Wl,-rpath,@loader_path",
            "-Wl,-rpath,@loader_path/zig-out/lib",
            "-Wl,-rpath,@loader_path/zig-out/zig-out/lib"
          ],
          "xcode_settings": {
            "OTHER_LDFLAGS": [
              "-Wl,-rpath,@loader_path",
              "-Wl,-rpath,@loader_path/zig-out/lib",
              "-Wl,-rpath,@loader_path/zig-out/zig-out/lib"
            ]
          }
        }],
        ['OS=="linux"', {
          "libraries": [
            "-Wl,-rpath,'$$ORIGIN'",
            "-Wl,-rpath,'$$ORIGIN/zig-out/lib'",
            "-Wl,-rpath,'$$ORIGIN/zig-out/zig-out/lib'"
          ]
        }]
      ],
      "cflags!": [ "-fno-exceptions" ],
      "cflags_cc!": [ "-fno-exceptions" ],
      "defines": [ "NAPI_DISABLE_CPP_EXCEPTIONS" ]
    }
  ]
}