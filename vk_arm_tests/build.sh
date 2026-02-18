#!/usr/bin/env bash
set -euo pipefail

NDK="${NDK:-/usr/lib/android-sdk/ndk/23.2.8568313}"
TC="$NDK/toolchains/llvm/prebuilt/linux-x86_64"
CC="$TC/bin/aarch64-linux-android24-clang"
CFLAGS="-O2 -fPIE "
LDFLAGS="-pie -lvulkan -ldl -llog"

mkdir -p /home/sdancer/wd/vk_arm_tests/bin

for src in /home/sdancer/wd/vk_arm_tests/src/test*.c; do
  name="$(basename "$src" .c)"
  out="/home/sdancer/wd/vk_arm_tests/bin/${name}"
  echo "[*] $name"
  "$CC" $CFLAGS "$src" -o "$out" $LDFLAGS
  file "$out" | sed -n '1p'
done

ls -1 /home/sdancer/wd/vk_arm_tests/bin | wc -l
