#!/bin/bash

function usage() {
cat<<EOFHELP

Usage:
  $0 [target_os] [debug] [target_cpu]

  example:
    $0 android true arm

Arguments:
  target_os   Can be one of: android, ios, linux, win, mac

  debug       Can be one of: true, false

  target_cpu  Can be one of: armv5, arm, arm64, x86, x64
                armv5   for android
                arm     for android, ios
                arm64   for android, ios
                x86     for android, ios, linux, win
                x64     for android, ios, linux, win, mac

EOFHELP
}

function run() {
  echo "[ Exec] $*"
  "$@"
}

[[ $# != 3 ]] && {
  usage;
  exit 1;
}

target_os=$1
debug=$2
target_cpu=$3
is_armv5=0
is_clang="false"

# Verify args.
[[ "$target_os" =~ ^(android|ios|linux|win|mac)$ ]] || {
  echo "unknown target os: $target_os"
  echo "supported os: android, ios, linux, win, mac"
  exit 1;
}
[[ "$debug" =~ ^(true|false)$ ]] || {
  echo "unknown debug value: $debug"
  echo "supported value: true, false"
  exit 1;
}
[[ "$target_cpu" =~ ^(arm|armv5|arm64|x86|x64)$ ]] || {
  echo "unknown target cpu: $target_cpu"
  echo "supported cpu arch: arm, armv5, arm64, x86, x64"
  exit 1;
}
[[ "$target_cpu" == "armv5" ]] && {
  target_cpu="arm"
  is_armv5=1
}

# Check and setup build envrionment.
[[ $target_os == "linux" ]] && {
  _gcc_path=$(which gcc)
  [[ $_gcc_path == "" ]] && {
    echo "ERROR: Can not found gcc in PATH!"
    exit 1;
  }
}
[[ $target_os == "android" ]] && {
  # Auto search ndk path
  ndk_home=$ANDROID_NDK_HOME
  [[ $ndk_home == "" ]] && {
    ndk_build_path=$(which ndk-build)
    ndk_home=$(dirname $ndk_build_path)
    [[ $ndk_home == "" ]] && {
        echo "ERROR: Set ANDROID_NDK_HOME environment variable first!"
        exit 1;
    }
    echo "Found ANDROID_NDK_HOME: $ndk_home"
  }

  [[ -f "$ndk_home/source.properties" ]] && {
    # NDK r11 and newer:
    # Pkg.Desc = Android NDK
    # Pkg.Revision = 19.2.5345600
    datas=$(cat "$ndk_home/source.properties")
    _tmp=${datas##*Pkg.Revision = }
    ver_num=${_tmp%%.*}
    ver="r${ver_num}"
  }
  [[ -f "$ndk_home/RELEASE.TXT" ]] && {
    # Old version NDK:
    # r10e-rc4 (64-bit)
    datas=$(cat "$ndk_home/RELEASE.TXT")
    ver=${datas%%-*}
    ver_num=$(echo $ver | sed -e 's/^r\([0-9]\{1,\}\).*$/\1/')
  }

  ndk_root="$ndk_home"
  ndk_version="$ver"
  ndk_major_version="$ver_num"

  [[ $((ver_num)) > 12 ]] && {
    is_clang="true"
  }
}
[[ $target_os == "mac" || $target_os == "ios" ]] && {
  clang_path=$(which clang)
  clang_dir=$(dirname $(dirname $clang_path))
  [[ $clang_dir == "" ]] && {
      echo "ERROR: Can not found clang in PATH!"
      exit 1;
  }
  echo "Found clang path: $clang_dir"
  is_clang="true"
}
[[ $target_os == "win" ]] && {
  visual_studio_path="C:\Program Files (x86)\Microsoft Visual Studio"
  visual_studio_version=2019
  vs_install_dir="$visual_studio_path\\$visual_studio_version\\Community"
  [[ ! -d "$vs_install_dir" ]] && {
    echo "Visual studio install path not exist: $vs_install_dir"
    exit 1;
  }
  echo "Use visual studio path: $vs_install_dir"

  export DEPOT_TOOLS_WIN_TOOLCHAIN=0
  export vs2019_install="$vs_install_dir"
  export GYP_MSVS_OVERRIDE_PATH="$vs_install_dir"
}

# Setup gn args.
gn_args="target_os = \"${target_os}\""
gn_args="${gn_args} is_debug = ${debug}"
gn_args="${gn_args} target_cpu = \"${target_cpu}\""
gn_args="${gn_args} is_clang = ${is_clang}"
[[ $target_os == "android" ]] && {
  [[ $is_armv5 == 1 ]] && {
    gn_args="${gn_args} arm_arch = \"armv5te\""

    # Fix executable |hello| link error:
    # ld.lld: error: lld uses extended branch encoding, no object with architecture supporting feature detected.
    # ld.lld: error: lld may use movt/movw, no object with architecture supporting feature detected.
    [[ $is_clang == "true" ]] && {
      gn_args="${gn_args} use_gold = true use_lld = false"
    }
  }
  gn_args="${gn_args} default_android_ndk_root = \"${ndk_root}\""
  gn_args="${gn_args} default_android_ndk_version = \"${ndk_version}\""
  gn_args="${gn_args} default_android_ndk_major_version = ${ndk_major_version}"
}
[[ $target_os == "mac" ]] && {
  gn_args="${gn_args} clang_base_path = \"${clang_dir}\""
}
[[ $target_os == "ios" ]] && {
  gn_args="${gn_args} clang_base_path = \"${clang_dir}\""
  gn_args="${gn_args} ios_enable_code_signing = false"
  gn_args="${gn_args} ios_deployment_target = \"10.0\""  # For 32bits arch.
}
[[ $target_os == "win" ]] && {
  gn_args="${gn_args} visual_studio_path = \"${visual_studio_path}\""
  gn_args="${gn_args} visual_studio_version = \"${visual_studio_path}\""
  gn_args="${gn_args} wdk_path = \"${visual_studio_path}\""
  gn_args="${gn_args} vs_install_dir = \"${vs_install_dir}\""
}
echo
echo "gn args: ${gn_args}"
echo

# Setup paths for gn and ninija.
gn_bin="gn"
ninja_bin="ninja"
os_name=$(uname)
echo "uname is: $os_name"
[[ $os_name == "Linux" ]] && {
  gn_bin="${0%/*}/bin/linux/gn"
  ninja_bin="${0%/*}/bin/linux/ninja"
}
[[ $os_name == "Darwin" ]] && {
  gn_bin="${0%/*}/bin/mac/gn"
  ninja_bin="${0%/*}/bin/mac/ninja"
}
[[ $os_name =~ .*NT.* ]] && {
  gn_bin="${0%/*}/bin/win/gn"
  ninja_bin="${0%/*}/bin/win/ninja"
}
echo "gn path: $gn_bin"
echo "ninja path: $ninja_bin"
echo

# Generate build files for ninja.
out_dir="out/$target_os"
run $gn_bin gen -C ${out_dir} --args="${gn_args}"
echo
[[ $? != 0 ]] && {
  echo "gn gen failed"
  exit 1;
}
echo "gn gen succeed"
echo

# Build executables and libaraies with ninja.
run $ninja_bin -C ${out_dir}
echo
[[ $? != 0 ]] && {
  echo "ninja build failed"
  exit 1;
}
echo "ninja build succeed"
