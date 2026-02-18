#!/usr/bin/env bash
set -euo pipefail

# Dump assembly handlers for each proxy Vulkan API entry into its own file.
#
# Usage:
#   ./dump_proxy_api_handlers.sh [proxy_so_path] [out_dir]
#
# Defaults:
#   proxy_so_path: /var/lib/waydroid/overlay/system/lib64/libndk_translation_proxy_libvulkan.so
#   out_dir:       ./proxy_api_handlers_asm

LIB="${1:-/var/lib/waydroid/overlay/system/lib64/libndk_translation_proxy_libvulkan.so}"
OUT_DIR="${2:-${PWD}/proxy_api_handlers_asm}"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing command: $1" >&2
    exit 1
  }
}

need_cmd objdump
need_cmd python3

mkdir -p "$OUT_DIR"

python3 - "$LIB" "$OUT_DIR" <<'PY'
import re
import struct
import subprocess
import sys
from pathlib import Path

lib = Path(sys.argv[1])
out_dir = Path(sys.argv[2])

if not lib.exists():
    raise SystemExit(f"missing library: {lib}")

b = lib.read_bytes()
TABLE_BASE = 0x96768
COUNT = 0x223
ENT_SZ = 16

entries = []
for idx in range(COUNT):
    off = TABLE_BASE + idx * ENT_SZ
    name_ptr, wrap_ptr = struct.unpack_from("<QQ", b, off)
    if name_ptr >= len(b):
        continue
    end = b.find(b"\x00", name_ptr)
    if end < 0:
        continue
    name = b[name_ptr:end].decode("ascii", errors="ignore")
    if not name.startswith("vk"):
        continue
    entries.append((idx, name, wrap_ptr))

if not entries:
    raise SystemExit("no proxy entries parsed from table")

uniq_wrap = sorted({w for _, _, w in entries})
next_wrap = {}
for i, addr in enumerate(uniq_wrap):
    nxt = uniq_wrap[i + 1] if i + 1 < len(uniq_wrap) else addr + 0x40
    # Keep bounds reasonable when wrappers are far apart.
    if nxt - addr > 0x200:
        nxt = addr + 0x80
    if nxt <= addr:
        nxt = addr + 0x20
    next_wrap[addr] = nxt

summary_lines = []
for idx, name, wrap in entries:
    start = wrap
    stop = next_wrap[wrap]
    safe = re.sub(r"[^A-Za-z0-9_.-]", "_", name)
    out = out_dir / f"{idx:03d}_{safe}.asm"

    cmd = [
        "objdump", "-d", "-M", "intel",
        f"--start-address=0x{start:x}",
        f"--stop-address=0x{stop:x}",
        str(lib),
    ]
    p = subprocess.run(cmd, text=True, capture_output=True)
    text = p.stdout
    if p.stderr:
        text += "\n; objdump stderr:\n" + p.stderr
    header = (
        f"; index={idx}\n"
        f"; api={name}\n"
        f"; wrapper_start=0x{start:x}\n"
        f"; wrapper_stop=0x{stop:x}\n"
        f"; source={lib}\n\n"
    )
    out.write_text(header + text)
    summary_lines.append(f"{idx:03d} 0x{start:06x} {name}")

(out_dir / "INDEX.txt").write_text("\n".join(summary_lines) + "\n")
print(f"dumped {len(entries)} API handler files to {out_dir}")
PY

echo "Done: ${OUT_DIR}"

