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
            "-Wl,-rpath,@loader_path/prebuilds"
          ],
          "xcode_settings": {
            "OTHER_LDFLAGS": [
              "-Wl,-rpath,@loader_path",
              "-Wl,-rpath,@loader_path/prebuilds"
            ],
            "MACOSX_DEPLOYMENT_TARGET": "10.13",
            "GCC_ENABLE_CPP_EXCEPTIONS": "YES"
          }
        }],
        ['OS=="linux"', {
          "libraries": [
            "-Wl,-rpath,'$$ORIGIN'",
            "-Wl,-rpath,'$$ORIGIN/prebuilds'"
          ],
          "cflags": [
            "-fPIC"
          ]
        }]
      ],
      "cflags!": [ "-fno-exceptions" ],
      "cflags_cc!": [ "-fno-exceptions" ],
      "defines": [ 
        "NAPI_DISABLE_CPP_EXCEPTIONS",
        "NAPI_VERSION=8"
      ],
      "variables": {
        "module_name": "tik-forge",
        "module_path": "prebuilds/$(Platform)-$(Architecture)"
      }
    }
  ]
}