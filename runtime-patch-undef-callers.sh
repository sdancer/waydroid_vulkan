#!/usr/bin/env bash
set -euo pipefail

PKG="${1:-com.sdancer.uevulkanprobecpp}"
LIB="${2:-/var/lib/waydroid/overlay/system/lib64/libndk_translation.so}"
MAX_ROUNDS="${3:-8}"
SAMPLE_SEC="${4:-2}"

log() { printf '[runtime-patch-undef-callers] %s\n' "$*"; }

get_pid() {
  ps -eo pid=,pcpu=,cmd= | awk -v pkg="$PKG" '$3==pkg { printf "%s %s\n", $1, $2 }' | sort -k2,2nr | awk 'NR==1{print $1}'
}

sample_ras() {
  local pid="$1"
  sudo timeout "${SAMPLE_SEC}" bpftrace -e "
uprobe:${LIB}:0x207940 /pid==${pid}/ {
  \$ra = *(uint64*)reg(\"sp\");
  printf(\"ra=0x%lx op=0x%x arg=0x%lx\\n\", \$ra, *(uint32*)arg0, arg0);
}
" 2>/dev/null || true
}

patch_callsite() {
  local pid="$1"
  local ra_hex="$2"
  python3 - "$pid" "$ra_hex" <<'PY'
import sys
pid = int(sys.argv[1])
ra = int(sys.argv[2], 16)
call = ra - 6
with open(f"/proc/{pid}/mem", "r+b", buffering=0) as f:
    f.seek(call)
    old = f.read(6)
    f.seek(call)
    f.write(b"\x90" * 6)
print(f"patched call@0x{call:x} old={old.hex()}")
PY
}

pid="$(get_pid || true)"
if [ -z "${pid}" ]; then
  log "process not found for package: $PKG"
  exit 1
fi
log "target pid: $pid"

nohit=0
for round in $(seq 1 "$MAX_ROUNDS"); do
  pid="$(get_pid || true)"
  if [ -z "${pid}" ]; then
    log "round ${round}/${MAX_ROUNDS}: process not found, waiting"
    sleep 1
    continue
  fi
  log "round ${round}/${MAX_ROUNDS}: sampling UndefinedInsn callers"
  sample_ras "$pid" > /tmp/undef_callers_sample.txt
  if ! rg -q '^ra=0x' /tmp/undef_callers_sample.txt; then
    nohit=$((nohit+1))
    log "no callers observed in this round (streak=${nohit})"
    if [ "$nohit" -ge 3 ]; then
      log "no callers across 3 rounds; done"
      exit 0
    fi
    sleep 1
    continue
  fi
  nohit=0

  mapfile -t ras < <(rg -o 'ra=0x[0-9a-f]+' /tmp/undef_callers_sample.txt | cut -d= -f2 | sort -u)
  log "unique callers: ${#ras[@]}"
  for ra in "${ras[@]}"; do
    sudo bash -lc "$(declare -f patch_callsite); patch_callsite '$pid' '$ra'"
  done

  sleep 1
done

log "reached max rounds"
