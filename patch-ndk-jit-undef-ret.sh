#!/usr/bin/env bash
set -euo pipefail

# Patch ndk_translation undefined-instruction handling.
# Intended for ARM64 guest apps on x86_64 Waydroid when translator hits unsupported opcodes.
#
# Usage:
#   ./patch-ndk-jit-undef-ret.sh apply        # recommended: keep handler, skip raise(SIGILL)
#   ./patch-ndk-jit-undef-ret.sh apply-entry  # legacy: immediate return at function entry
#   ./patch-ndk-jit-undef-ret.sh restore

ACTION="${1:-apply}"
LIB64="/var/lib/waydroid/overlay/system/lib64/libndk_translation.so"
SYM64="_ZN15ndk_translation13UndefinedInsnEm"
PATCH_ENTRY_RET_HEX="31c0c3909090" # xor eax,eax ; ret ; nop ; nop ; nop
PATCH_NORAISE_HEX="31c0c3909090"   # overwrite tail jmp raise with return
PATCH_ENTRY_ORIG_HEX="554156534889" # original first 6 bytes: push rbp; push r14; push rbx; rex.W mov ...

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing command: $1" >&2; exit 1; }
}

hex_to_dec() {
  local h="${1#0x}"
  echo $((16#$h))
}

sym_addr_hex() {
  local lib="$1" sym="$2"
  readelf -W -s "$lib" | awk -v sym="$sym" '$8==sym && $4=="FUNC" {print $2}'
}

text_addr_off_hex() {
  local lib="$1"
  readelf -W -S "$lib" | awk '$2==".text" {print $4, $5}'
}

patch_lib64() {
  local lib="$1" sym="$2"

  if [ ! -f "$lib" ]; then
    echo "Missing: $lib" >&2
    exit 1
  fi

  local sym_hex
  sym_hex="$(sym_addr_hex "$lib" "$sym")"
  if [ -z "$sym_hex" ]; then
    echo "Could not find symbol $sym in $lib" >&2
    exit 1
  fi

  local text_hex off_hex
  read -r text_hex off_hex < <(text_addr_off_hex "$lib")
  if [ -z "${text_hex:-}" ] || [ -z "${off_hex:-}" ]; then
    echo "Could not locate .text in $lib" >&2
    exit 1
  fi

  local sym_dec text_dec off_dec file_off
  sym_dec="$(hex_to_dec "$sym_hex")"
  text_dec="$(hex_to_dec "$text_hex")"
  off_dec="$(hex_to_dec "$off_hex")"
  file_off=$((sym_dec - text_dec + off_dec))

  local ts backup
  ts="$(date +%s)"
  backup="${lib}.pre-jitpatch.${ts}"

  echo "[*] Backing up $lib -> $backup"
  sudo cp -a "$lib" "$backup"

  local patch_site_off patch_site_vaddr
  if [ "$ACTION" = "apply-entry" ]; then
    patch_site_off="$file_off"
    patch_site_vaddr="$sym_hex"
    echo "[*] Legacy patch: immediate return at $sym"
    printf "$(echo "$PATCH_ENTRY_RET_HEX" | sed 's/../\\x&/g')" | sudo dd of="$lib" bs=1 seek="$patch_site_off" conv=notrunc status=none
  else
    # Ensure function prologue is restored (some backups include apply-entry patch).
    printf "$(echo "$PATCH_ENTRY_ORIG_HEX" | sed 's/../\\x&/g')" | sudo dd of="$lib" bs=1 seek="$file_off" conv=notrunc status=none

    # Recommended patch: keep UndefinedInsn logging/state handling and only skip raise(SIGILL)
    # Tail jmp raise is at +0x3c from function start in known builds.
    patch_site_off=$((file_off + 0x3c))
    patch_site_vaddr="$(printf '%x' $((16#$sym_hex + 0x3c)))"
    echo "[*] Recommended patch: no-raise tail patch at vaddr 0x${patch_site_vaddr} (file offset 0x$(printf '%x' "$patch_site_off"))"
    printf "$(echo "$PATCH_NORAISE_HEX" | sed 's/../\\x&/g')" | sudo dd of="$lib" bs=1 seek="$patch_site_off" conv=notrunc status=none
  fi

  echo "[*] Verify bytes/disasm:"
  objdump -d -M intel --start-address=$((16#$sym_hex)) --stop-address=$((16#$sym_hex+32)) "$lib" | sed -n '1,40p'
  objdump -d -M intel --start-address=$((16#$sym_hex+0x30)) --stop-address=$((16#$sym_hex+0x50)) "$lib" | sed -n '1,40p'

  echo "[*] SHA256:"
  sha256sum "$lib"

  echo "[*] Restart Waydroid session for patch to take effect:"
  echo "    waydroid session stop && waydroid session start"
}

restore_lib64() {
  local lib="$1"
  local latest
  latest="$(ls -1t "${lib}.pre-jitpatch."* 2>/dev/null | head -n1 || true)"
  if [ -z "$latest" ]; then
    echo "No backup found for $lib" >&2
    exit 1
  fi

  echo "[*] Restoring $lib from $latest"
  sudo cp -a "$latest" "$lib"
  sha256sum "$lib"
}

need_cmd readelf
need_cmd objdump
need_cmd sha256sum
need_cmd dd
need_cmd sed

case "$ACTION" in
  apply)
    patch_lib64 "$LIB64" "$SYM64"
    ;;
  apply-entry)
    patch_lib64 "$LIB64" "$SYM64"
    ;;
  restore)
    restore_lib64 "$LIB64"
    ;;
  *)
    echo "Usage: $0 [apply|apply-entry|restore]" >&2
    exit 1
    ;;
esac
