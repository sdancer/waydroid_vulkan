#!/usr/bin/env bash
set -euo pipefail

LIB="/var/lib/waydroid/overlay/system/lib64/libndk_translation_proxy_libvulkan.so"
ACTION="${1:-apply}"

apply_patch() {
  local ts backup
  ts="$(date +%s)"
  backup="${LIB}.pre-sparse-oldname.${ts}"
  sudo cp -a "$LIB" "$backup"
  sudo python3 - <<'PY'
from pathlib import Path
lib=Path('/var/lib/waydroid/overlay/system/lib64/libndk_translation_proxy_libvulkan.so')
b=bytearray(lib.read_bytes())
old=b'vkGetPhysicalDeviceSparseImageFormatProperties2\x00'
new=b'vkGetPhysicalDeviceSparseImageFormatProperties\x00'
count=0
start=0
while True:
  i=b.find(old,start)
  if i<0:
    break
  # write shorter string + NUL at former '2' position
  b[i:i+len(new)] = new
  count += 1
  start = i + len(new)
if count==0:
  raise SystemExit('target string not found')
lib.write_bytes(bytes(b))
print('patched occurrences',count)
PY
  sha256sum "$LIB"
}

restore_patch() {
  local latest
  latest="$(ls -1t "${LIB}.pre-sparse-oldname."* 2>/dev/null | head -n1 || true)"
  if [[ -z "$latest" ]]; then
    echo "no backup found" >&2
    exit 1
  fi
  sudo cp -a "$latest" "$LIB"
  sha256sum "$LIB"
}

case "$ACTION" in
  apply) apply_patch ;;
  restore) restore_patch ;;
  *) echo "usage: $0 [apply|restore]" >&2; exit 1 ;;
esac
