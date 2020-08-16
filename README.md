# Hello GN Build Example

This project is a simple example for gn build. The build dir is ported from
Chromium project, can works standalone, and be light.

## Supported platforms

The example works around with:
* android (armv5, arm, arm64, x86, x64)
* ios (arm, arm64, x86, x64)
* linux (x86, x64)
* windows (x86, x64)
* mac (x64)

## Build

Build the project with script `./build/build.sh`.

```sh
Usage:
  ./build/build.sh [target_os] [debug] [target_cpu]

  example:
    ./build/build.sh android true arm

Arguments:
  target_os   Can be one of: android, ios, linux, win, mac

  debug       Can be one of: true, false

  target_cpu  Can be one of: armv5, arm, arm64, x86, x64
                armv5   for android
                arm     for android, ios
                arm64   for android, ios
                x86     for android, ios, linux, win
                x64     for android, ios, linux, win, mac
```

e.g. Build for `android` with `armeabi-v7a`, debug version:
```sh
./build/build.sh android true arm
```

And the compiled files are outputted into dir `//out/android`.

## Porting

You may porting the `//build` dir to your project, and don't miss the `.gn` file
in root directory which may be hidden on your system!

### Toolchain

The project uses the toolchains (gcc, clang, llvm, ...) in your `PATH`.
The following conditions are required to make `build/build.sh` works around
with the platforms:

* **android**: Add NDK to your `PATH`. It uses `which ndk-build` to locate NDK.
* **ios**: Add `clang` to your `PATH`. It uses `which clang` to locate the toolchains.
* **linux**: Add `gcc` to your `PATH`. It uses `which gcc` to locate the toolchains.
* **win**: Install Visual Studio 2019, and windows SDK with version `10.0.18362.0`.
* **mac**: Add `clang` to your `PATH`. It uses `which clang` to locate the toolchains.
