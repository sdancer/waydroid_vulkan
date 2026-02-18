#!/usr/bin/env bash
set -euo pipefail

PKG="${1:-com.sdancer.uevulkanprobecpp}"
ACT="${2:-com.epicgames.unreal.SplashActivity}"
MAX_ITERS="${3:-8}"
TARGET_OPCODE="${4:-6ee1d843}"
REPL_HEX="${5:-1f2003d5}" # AArch64 NOP

log() { printf '[patch-ue-undef] %s\n' "$*"; }

get_pid() {
  sudo waydroid shell -- pidof "$PKG" 2>/dev/null | awk '{print $1}' || true
}

launch_app() {
  sudo waydroid shell -- am force-stop "$PKG" >/dev/null 2>&1 || true
  sudo waydroid shell -- logcat -c
  sudo waydroid shell -- am start -n "$PKG/$ACT" >/dev/null 2>&1 || true
}

first_undef_line() {
  local out="$1"
  rg -n "Undefined instruction 0x[0-9a-fA-F]+ at 0x[0-9a-fA-F]+" "$out" | head -n1 || true
}

hex_to_le_bytes() {
  python3 - "$1" <<'PY'
import sys
h=sys.argv[1].lower().strip()
if h.startswith('0x'): h=h[2:]
if len(h)%2: h='0'+h
b=bytes.fromhex(h)
print(' '.join(f'{x:02x}' for x in b[::-1]))
PY
}

for i in $(seq 1 "$MAX_ITERS"); do
  log "iteration $i/$MAX_ITERS"
  launch_app
  sleep 10
  sudo waydroid shell -- logcat -d > /tmp/ue_undef_iter.log

  line="$(first_undef_line /tmp/ue_undef_iter.log)"
  if [ -z "$line" ]; then
    log "no undefined instruction found; stopping"
    exit 0
  fi

  opcode="$(echo "$line" | sed -E 's/.*Undefined instruction 0x([0-9a-fA-F]+).*/\1/' | tr 'A-F' 'a-f')"
  addr="$(echo "$line" | sed -E 's/.* at 0x([0-9a-fA-F]+).*/\1/' | tr 'A-F' 'a-f')"
  log "first undefined: opcode=0x$opcode addr=0x$addr"

  if [ "$opcode" != "$TARGET_OPCODE" ]; then
    log "opcode differs from target (0x$TARGET_OPCODE). stop and report next opcode."
    exit 10
  fi

  pid="$(get_pid)"
  if [ -z "$pid" ]; then
    log "could not resolve running pid"
    exit 11
  fi

  sudo waydroid shell -- sh -lc "cat /proc/$pid/maps" > /tmp/ue_maps_iter.txt

  # Resolve mapping and compute file offset on host for reliability.
  read -r map_start map_off map_path file_off < <(python3 - "$addr" <<'PY'
import sys,re
addr=int(sys.argv[1],16)
for ln in open('/tmp/ue_maps_iter.txt'):
    parts=ln.strip().split()
    if len(parts) < 6:
        continue
    m,perms,off,dev,inode,path = parts[0],parts[1],parts[2],parts[3],parts[4],' '.join(parts[5:])
    a,b=[int(x,16) for x in m.split('-')]
    if a <= addr < b:
        file_off=int(off,16) + (addr-a)
        print(hex(a), hex(int(off,16)), path, hex(file_off))
        break
PY
)

  if [ -z "${map_path:-}" ]; then
    log "failed to resolve map for address 0x$addr"
    exit 12
  fi

  if [[ "$map_path" != *"/lib/arm64/libUnreal.so" ]]; then
    log "address not in libUnreal.so: $map_path"
    exit 13
  fi

  # Backup once per iteration target file.
  ts="$(date +%s)"
  sudo waydroid shell -- sh -lc "cp -an '$map_path' '$map_path.pre-undef-bulk-$ts' || true"

  # Verify bytes at computed file offset.
  cur_bytes="$(sudo waydroid shell -- sh -lc "dd if='$map_path' bs=1 skip=$((file_off)) count=4 2>/dev/null | od -An -tx1" | xargs)"
  want_bytes="$(hex_to_le_bytes "$opcode")"
  if [ "$cur_bytes" != "$want_bytes" ]; then
    log "byte mismatch at file_off=$file_off have='$cur_bytes' want='$want_bytes' (refusing to patch)"
    exit 14
  fi

  # Patch instruction to replacement.
  repl_esc="$(echo "$REPL_HEX" | sed 's/../\\x&/g')"
  sudo waydroid shell -- sh -lc "printf '$repl_esc' | dd of='$map_path' bs=1 seek=$((file_off)) conv=notrunc status=none"
  new_bytes="$(sudo waydroid shell -- sh -lc "dd if='$map_path' bs=1 skip=$((file_off)) count=4 2>/dev/null | od -An -tx1" | xargs)"
  log "patched $map_path @ file_off=$file_off ($cur_bytes -> $new_bytes)"
done

log "reached max iterations ($MAX_ITERS)"
