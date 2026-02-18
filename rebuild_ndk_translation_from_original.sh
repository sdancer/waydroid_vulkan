#!/usr/bin/env bash
set -euo pipefail

# Rebuild libndk_translation.so from a pristine workspace copy.
#
# Usage:
#   ./rebuild_ndk_translation_from_original.sh sync-original
#   ./rebuild_ndk_translation_from_original.sh build
#   ./rebuild_ndk_translation_from_original.sh install
#   ./rebuild_ndk_translation_from_original.sh status
#
# Outputs:
#   ./libndk_translation.original.so
#   ./libndk_translation.patched.so

ACTION="${1:-build}"

SYSTEM_LIB="/var/lib/waydroid/overlay/system/lib64/libndk_translation.so"
ORIG_LIB="${PWD}/libndk_translation.original.so"
PATCHED_LIB="${PWD}/libndk_translation.patched.so"

# Stable patch: skip the syscall callsite in ndk_translation_HandleNoExec path.
NOEXEC_CALL_VADDR="${NOEXEC_CALL_VADDR:-0x210cec}"
NOEXEC_PATCH_HEX="${NOEXEC_PATCH_HEX:-9090909090}"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing command: $1" >&2
    exit 1
  }
}

need_cmd readelf
need_cmd sha256sum
need_cmd dd
need_cmd od
need_cmd sudo

hex_to_dec() {
  local h="${1#0x}"
  echo $((16#$h))
}

text_addr_off_hex() {
  local lib="$1"
  readelf -W -S "$lib" | awk '$2==".text" {print $4, $5}'
}

show_status() {
  echo "[*] Original: $ORIG_LIB"
  if [[ -f "$ORIG_LIB" ]]; then
    sha256sum "$ORIG_LIB"
  else
    echo "missing"
  fi

  echo "[*] Patched:  $PATCHED_LIB"
  if [[ -f "$PATCHED_LIB" ]]; then
    sha256sum "$PATCHED_LIB"
    read -r text_hex off_hex < <(text_addr_off_hex "$PATCHED_LIB")
    local file_off
    file_off=$(( $(hex_to_dec "$NOEXEC_CALL_VADDR") - $(hex_to_dec "$text_hex") + $(hex_to_dec "$off_hex") ))
    echo "[*] .text vaddr=$text_hex off=$off_hex noexec_patch_file_off=0x$(printf '%x' "$file_off")"
    echo -n "[*] bytes@patch: "
    od -An -tx1 -N5 -j "$file_off" "$PATCHED_LIB" | xargs echo
  else
    echo "missing"
  fi
}

sync_original() {
  echo "[*] Syncing pristine original from system -> workspace"
  sudo cp -a "$SYSTEM_LIB" "$ORIG_LIB"
  sudo chown "$(id -u):$(id -g)" "$ORIG_LIB"
  sha256sum "$ORIG_LIB"
}

build_patched() {
  if [[ ! -f "$ORIG_LIB" ]]; then
    echo "Original not found: $ORIG_LIB" >&2
    echo "Run: $0 sync-original" >&2
    exit 1
  fi

  cp -a "$ORIG_LIB" "$PATCHED_LIB"

  read -r text_hex off_hex < <(text_addr_off_hex "$PATCHED_LIB")
  local file_off
  file_off=$(( $(hex_to_dec "$NOEXEC_CALL_VADDR") - $(hex_to_dec "$text_hex") + $(hex_to_dec "$off_hex") ))

  echo "[*] Applying patch at vaddr $NOEXEC_CALL_VADDR (file off 0x$(printf '%x' "$file_off"))"
  printf "$(echo "$NOEXEC_PATCH_HEX" | sed 's/../\\x&/g')" | dd of="$PATCHED_LIB" bs=1 seek="$file_off" conv=notrunc status=none

  echo -n "[*] bytes@patch after write: "
  od -An -tx1 -N5 -j "$file_off" "$PATCHED_LIB" | xargs echo
  sha256sum "$PATCHED_LIB"
}

install_patched() {
  if [[ ! -f "$PATCHED_LIB" ]]; then
    echo "Patched output not found: $PATCHED_LIB" >&2
    echo "Run: $0 build" >&2
    exit 1
  fi
  echo "[*] Installing patched lib to Waydroid overlay"
  sudo cp -a "$PATCHED_LIB" "$SYSTEM_LIB"
  sha256sum "$SYSTEM_LIB"
}

case "$ACTION" in
  sync-original) sync_original ;;
  build) build_patched ;;
  install) install_patched ;;
  status) show_status ;;
  *)
    echo "Usage: $0 [sync-original|build|install|status]" >&2
    exit 1
    ;;
esac

