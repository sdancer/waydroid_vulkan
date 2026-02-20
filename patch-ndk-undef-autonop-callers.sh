#!/usr/bin/env bash
set -euo pipefail

# Static patch for libndk_translation UndefinedInsn:
# - default: mprotect guest code page, then replace undefined guest instruction with AArch64 NOP
# - optional (SKIP_MPROTECT=1): write directly without mprotect
# - return 4 (AArch64 instruction width)
#
# This avoids caller-site x86 patching and stops infinite undefined-insn loops.
#
# Usage:
#   ./patch-ndk-undef-autonop-callers.sh apply
#   ./patch-ndk-undef-autonop-callers.sh restore

ACTION="${1:-apply}"
LIB="/var/lib/waydroid/overlay/system/lib64/libndk_translation.so"
SYM="_ZN15ndk_translation13UndefinedInsnEm"
# x86_64 hook bytes:
#   push rbx
#   mov rbx,rdi
#   and rdi, -4096
#   mov esi, 4096
#   mov edx, 7
#   mov eax, 10            ; syscall: mprotect
#   syscall
#   test eax, eax
#   jne +6
#   mov dword [rbx], 0xd503201f   ; AArch64 NOP
#   mov eax,4
#   pop rbx
#   ret
PATCH_HEX_WITH_MPROTECT="534889fb4881e700f0ffffbe00100000ba07000000b80a0000000f0585c07506c7031f2003d5b8040000005bc3"
PATCH_HEX_NO_MPROTECT="534889fbc7031f2003d5b8040000005bc3"

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

apply_patch_now() {
  local sym_hex text_hex off_hex sym_dec text_dec off_dec file_off backup ts patch_hex
  sym_hex="$(sym_addr_hex "$LIB" "$SYM")"
  [ -n "$sym_hex" ] || { echo "Could not find symbol: $SYM" >&2; exit 1; }
  read -r text_hex off_hex < <(text_addr_off_hex "$LIB")
  [ -n "${text_hex:-}" ] && [ -n "${off_hex:-}" ] || { echo "Could not resolve .text section" >&2; exit 1; }

  sym_dec="$(hex_to_dec "$sym_hex")"
  text_dec="$(hex_to_dec "$text_hex")"
  off_dec="$(hex_to_dec "$off_hex")"
  file_off=$((sym_dec - text_dec + off_dec))

  ts="$(date +%s)"
  backup="${LIB}.pre-autonop.${ts}"
  echo "[*] Backup: $backup"
  sudo cp -a "$LIB" "$backup"

  if [ "${SKIP_MPROTECT:-0}" = "1" ]; then
    patch_hex="$PATCH_HEX_NO_MPROTECT"
    echo "[*] Using no-mprotect variant (SKIP_MPROTECT=1)"
  else
    patch_hex="$PATCH_HEX_WITH_MPROTECT"
    echo "[*] Using default mprotect variant"
  fi

  echo "[*] Patching $SYM at vaddr 0x${sym_hex} (file offset 0x$(printf '%x' "$file_off"))"
  printf "$(echo "$patch_hex" | sed 's/../\\x&/g')" | sudo dd of="$LIB" bs=1 seek="$file_off" conv=notrunc status=none

  echo "[*] Verify disasm:"
  sudo objdump -d -Mintel --start-address=$((16#$sym_hex)) --stop-address=$((16#$sym_hex+0x40)) "$LIB"
  echo "[*] SHA256:"
  sudo sha256sum "$LIB"
}

restore_patch() {
  local latest
  latest="$(ls -1t "${LIB}.pre-autonop."* 2>/dev/null | head -n1 || true)"
  [ -n "$latest" ] || { echo "No backup found: ${LIB}.pre-autonop.*" >&2; exit 1; }
  echo "[*] Restoring from: $latest"
  sudo cp -a "$latest" "$LIB"
  sudo sha256sum "$LIB"
}

need_cmd readelf
need_cmd objdump
need_cmd sha256sum
need_cmd dd
need_cmd sed

case "$ACTION" in
  apply) apply_patch_now ;;
  restore) restore_patch ;;
  *) echo "Usage: $0 [apply|restore]" >&2; exit 1 ;;
esac

echo "[*] Restart Waydroid session to load patched translator."
