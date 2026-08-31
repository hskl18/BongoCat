#!/bin/zsh

set -euo pipefail

native_root="${0:A:h:h}"
user_name="$(/usr/bin/id -un)"
user_home="$(
  /usr/bin/dscl . -read "/Users/$user_name" NFSHomeDirectory |
    /usr/bin/cut -d ' ' -f 2-
)"
sdk_root="${CUBISM_SDK_ROOT:-$user_home/SDKs/CubismSdkForNative-5-r.5}"
build_root="$native_root/.build/cubism"
core_root="$sdk_root/Core/lib/macos"
host_arch="$(/usr/bin/uname -m)"
cmake_bin="${CMAKE_BIN:-$(command -v cmake || true)}"

case "$host_arch" in
  arm64 | x86_64) ;;
  *)
    echo "Unsupported Mac architecture: $host_arch" >&2
    exit 1
    ;;
esac

if [[ -z "$cmake_bin" ]]; then
  echo "CMake is required. Install it with: brew install cmake" >&2
  exit 1
fi

if [[ ! -f "$sdk_root/Core/include/Live2DCubismCore.h" ]]; then
  echo "Cubism SDK not found at $sdk_root" >&2
  echo "Set CUBISM_SDK_ROOT to the extracted CubismSdkForNative-5-r.5 folder." >&2
  exit 1
fi

/bin/mkdir -p "$build_root/lib"
if [[ ! -f "$core_root/$host_arch/libLive2DCubismCore.a" ]]; then
  echo "Cubism Core does not contain a $host_arch macOS library." >&2
  exit 1
fi
/bin/cp \
  "$core_root/$host_arch/libLive2DCubismCore.a" \
  "$build_root/lib/libLive2DCubismCore.a"

"$cmake_bin" \
  -S "$native_root/CubismRuntime" \
  -B "$build_root/cmake" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_OSX_ARCHITECTURES="$host_arch" \
  -DCMAKE_OSX_DEPLOYMENT_TARGET="26.0" \
  -DCUBISM_SDK_ROOT="$sdk_root" \
  -DCUBISM_BUILD_ROOT="$build_root"

"$cmake_bin" --build "$build_root/cmake" --config Release --parallel
