#!/usr/bin/env bash
set -euo pipefail

LIB="${LIB:-/var/lib/waydroid/overlay/system/lib64/libndk_translation.so}"
ACTION="${1:-apply}"
IMM_BASE="${2:-0x6ea1d800}"   # replacement base, low 11 bits preserved from original opcode

need_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "Missing: $1" >&2; exit 1; }; }
need_cmd python3
need_cmd sudo
need_cmd sha256sum

sym_off() {
  # _ZN15ndk_translation13UndefinedInsnEm at runtime 0x206940 in this build image.
  # derive from ELF sections to avoid hardcoding fragility.
  python3 - "$LIB" <<'PY'
import subprocess,sys
lib=sys.argv[1]
# read symbol va
out=subprocess.check_output(['readelf','-W','-s',lib], text=True)
va=None
for ln in out.splitlines():
    if '_ZN15ndk_translation13UndefinedInsnEm' in ln and ' FUNC ' in ln:
        va=int(ln.split()[1],16)
        break
if va is None:
    raise SystemExit('symbol not found')
# text section va/off
out2=subprocess.check_output(['readelf','-W','-S',lib], text=True)
text_va=text_off=None
for ln in out2.splitlines():
    if '.text' in ln and 'PROGBITS' in ln:
        parts=ln.split()
        # ... Name Type Address Off ...
        # find address/off columns robustly by hex-like fields
        hexes=[p for p in parts if all(c in '0123456789abcdefABCDEF' for c in p)]
        # first hex is Address, second is Off
        text_va=int(hexes[0],16)
        text_off=int(hexes[1],16)
        break
if text_va is None:
    raise SystemExit('.text not found')
fo=va-text_va+text_off
print(hex(fo))
PY
}

apply_patch() {
  local ts backup off
  ts="$(date +%s)"
  backup="${LIB}.pre-undef-rewrite.${ts}"
  echo "[*] Backup: $backup"
  sudo cp -a "$LIB" "$backup"

  off="$(sym_off)"
  echo "[*] Patching UndefinedInsn at file offset ${off} with IMM_BASE=${IMM_BASE}"

  sudo python3 - "$LIB" "$off" "$IMM_BASE" <<'PY'
import sys,struct
from pathlib import Path
lib=Path(sys.argv[1])
off=int(sys.argv[2],16)
imm=int(sys.argv[3],0)
b=bytearray(lib.read_bytes())

# push rbx
# mov rbx,rdi
# mov eax,[rbx]
# mov ecx,eax
# and ecx,0xfffff800
# cmp ecx,0x6ee1d800
# jne ret4
# and eax,0x7ff
# or eax,imm
# mov [rbx],eax
# ret4: mov eax,4
# pop rbx
# ret
code=bytearray()
code += bytes.fromhex('53')
code += bytes.fromhex('4889fb')
code += bytes.fromhex('8b03')
code += bytes.fromhex('89c1')
code += bytes.fromhex('81e100f8ffff')
code += bytes.fromhex('81f900d8e16e')
code += bytes.fromhex('750f')
code += bytes.fromhex('25ff070000')
code += bytes.fromhex('0d') + struct.pack('<I',imm)
code += bytes.fromhex('8903')
code += bytes.fromhex('b804000000')
code += bytes.fromhex('5bc3')

# overwrite 0x41 bytes (original func size 65) with code + int3 padding
size=0x41
if len(code) > size:
    raise SystemExit('stub too large')
patch=code + b'\xCC'*(size-len(code))
b[off:off+size]=patch
lib.write_bytes(b)
print(f'patched_len=0x{len(code):x} total=0x{size:x} imm=0x{imm:x}')
PY

  sha256sum "$LIB"
}

restore_patch() {
  local latest
  latest="$(ls -1t "${LIB}.pre-undef-rewrite."* 2>/dev/null | head -n1 || true)"
  [ -n "$latest" ] || { echo "No backup found" >&2; exit 1; }
  echo "[*] Restoring $latest"
  sudo cp -a "$latest" "$LIB"
  sha256sum "$LIB"
}

case "$ACTION" in
  apply) apply_patch ;;
  restore) restore_patch ;;
  *) echo "Usage: $0 [apply|restore] [imm_base]" >&2; exit 1 ;;
esac
