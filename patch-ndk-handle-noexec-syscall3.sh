#!/usr/bin/env bash
set -euo pipefail

# Patch ndk_translation HandleNoExec path to skip the final syscall that faults
# on this Waydroid stack (SIGSEGV in ndk_translation_HandleNoExec+208).
#
# Usage:
#   ./patch-ndk-handle-noexec-syscall3.sh apply
#   ./patch-ndk-handle-noexec-syscall3.sh restore

ACTION="${1:-apply}"
LIB="/var/lib/waydroid/overlay/system/lib64/libndk_translation.so"
VADDR_CALL=0x210cec
PATCH_HEX="9090909090" # nop x5 (replaces call rel32)

need_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "Missing command: $1" >&2; exit 1; }; }
need_cmd readelf
need_cmd objdump
need_cmd sha256sum
need_cmd dd
need_cmd sudo

hex_to_dec() { local h="${1#0x}"; echo $((16#$h)); }

text_addr_off_hex() {
  local lib="$1"
  readelf -W -S "$lib" | awk '$2==".text" {print $4, $5}'
}

apply_patch() {
  [ -f "$LIB" ] || { echo "Missing: $LIB" >&2; exit 1; }

  local text_hex off_hex
  read -r text_hex off_hex < <(text_addr_off_hex "$LIB")

  local vaddr_dec text_dec off_dec file_off
  vaddr_dec="$(hex_to_dec "$(printf '0x%x' "$VADDR_CALL")")"
  text_dec="$(hex_to_dec "$text_hex")"
  off_dec="$(hex_to_dec "$off_hex")"
  file_off=$((vaddr_dec - text_dec + off_dec))

  local ts backup
  ts="$(date +%s)"
  backup="${LIB}.pre-noexec-syscall3patch.${ts}"
  echo "[*] Backing up $LIB -> $backup"
  sudo cp -a "$LIB" "$backup"

  echo "[*] Patching call at vaddr 0x$(printf '%x' "$VADDR_CALL") (file off 0x$(printf '%x' "$file_off"))"
  printf "$(echo "$PATCH_HEX" | sed 's/../\\x&/g')" | sudo dd of="$LIB" bs=1 seek="$file_off" conv=notrunc status=none

  objdump -d -M intel --start-address="$VADDR_CALL" --stop-address=$((VADDR_CALL+16)) "$LIB" | sed -n '1,40p'
  sha256sum "$LIB"

  echo "[*] Restart Waydroid session for patch to take effect."
}

restore_patch() {
  local latest
  latest="$(ls -1t "${LIB}.pre-noexec-syscall3patch."* 2>/dev/null | head -n1 || true)"
  if [ -z "$latest" ]; then
    echo "No backup found for $LIB" >&2
    exit 1
  fi
  echo "[*] Restoring $LIB from $latest"
  sudo cp -a "$latest" "$LIB"
  sha256sum "$LIB"
}

case "$ACTION" in
  apply) apply_patch ;;
  restore) restore_patch ;;
  *) echo "Usage: $0 [apply|restore]" >&2; exit 1 ;;
esac
