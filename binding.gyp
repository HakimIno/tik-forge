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
       "libraries": [
      "-L<(module_root_dir)/build/Release",
      "-ltik-forge",
       "../zig-out/lib/libtik-forge.dylib"
    ],
      "cflags!": [ "-fno-exceptions" ],
      "cflags_cc!": [ "-fno-exceptions" ],
      "defines": [ "NAPI_DISABLE_CPP_EXCEPTIONS" ],
      "xcode_settings": {
        "GCC_ENABLE_CPP_EXCEPTIONS": "YES",
        "CLANG_CXX_LIBRARY": "libc++",
        "MACOSX_DEPLOYMENT_TARGET": "10.15"
      },
      "conditions": [
        ['OS=="mac"', {
          "libraries": [
            "-L<!(pwd)/zig-out/lib",
            "-ltik-forge"
          ],
          "xcode_settings": {
            "OTHER_LDFLAGS": [
              "-Wl,-rpath,@loader_path/"
            ]
          }
        }]
      ]
    }
  ]
}