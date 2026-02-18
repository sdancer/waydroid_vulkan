#!/usr/bin/env bash
set -euo pipefail

PKG="${1:-com.sdancer.uevulkanprobecpp}"
ACT="${2:-com.epicgames.unreal.SplashActivity}"
MAX_PATCHES="${3:-32}"
TARGET_OPCODE="${4:-6ee1d843}"
REPL_HEX="${5:-1f2003d5}" # AArch64 NOP

log(){ printf '[runtime-undef] %s\n' "$*"; }

hex_to_le_bytes(){
  python3 - "$1" <<'PY'
import sys
h=sys.argv[1].lower().replace('0x','')
if len(h)%2: h='0'+h
b=bytes.fromhex(h)
print(' '.join(f'{x:02x}' for x in b[::-1]))
PY
}

patched_set=/tmp/runtime_undef_patched_addrs.txt
: > "$patched_set"

sudo waydroid shell -- am force-stop "$PKG" >/dev/null 2>&1 || true
sudo waydroid shell -- logcat -c
sudo waydroid shell -- am start -n "$PKG/$ACT" >/dev/null 2>&1 || true

count=0
for _ in $(seq 1 "$MAX_PATCHES"); do
  sleep 1
  sudo waydroid shell -- logcat -d > /tmp/runtime_undef.log
  line=$(rg "Undefined instruction 0x[0-9a-fA-F]+ at 0x[0-9a-fA-F]+" /tmp/runtime_undef.log | tail -n1 || true)
  if [ -z "$line" ]; then
    continue
  fi

  pid=$(echo "$line" | awk '{print $3}')
  op=$(echo "$line" | sed -E 's/.*Undefined instruction 0x([0-9a-fA-F]+).*/\1/' | tr 'A-F' 'a-f')
  addr=$(echo "$line" | sed -E 's/.* at 0x([0-9a-fA-F]+).*/\1/' | tr 'A-F' 'a-f')

  if grep -q "^$addr$" "$patched_set"; then
    continue
  fi

  if [ "$op" != "$TARGET_OPCODE" ]; then
    log "next opcode differs: 0x$op at 0x$addr (pid=$pid)"
    exit 10
  fi

  want=$(hex_to_le_bytes "$op")
  have=$(sudo waydroid shell -- sh -lc "dd if=/proc/$pid/mem bs=1 skip=$((0x$addr)) count=4 2>/dev/null | od -An -tx1" | xargs)
  if [ "$have" != "$want" ]; then
    log "mismatch at 0x$addr have='$have' want='$want' (pid=$pid)"
    exit 11
  fi

  repl_esc=$(echo "$REPL_HEX" | sed 's/../\\x&/g')
  sudo waydroid shell -- sh -lc "printf '$repl_esc' | dd of=/proc/$pid/mem bs=1 seek=$((0x$addr)) conv=notrunc status=none"
  after=$(sudo waydroid shell -- sh -lc "dd if=/proc/$pid/mem bs=1 skip=$((0x$addr)) count=4 2>/dev/null | od -An -tx1" | xargs)
  echo "$addr" >> "$patched_set"
  count=$((count+1))
  log "patched #$count pid=$pid addr=0x$addr ($have -> $after)"
  sudo waydroid shell -- logcat -c

done

log "done, patched $count addresses"
