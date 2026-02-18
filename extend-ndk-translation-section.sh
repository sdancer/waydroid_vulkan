#!/usr/bin/env bash
set -euo pipefail

LIB="${LIB:-/var/lib/waydroid/overlay/system/lib64/libndk_translation.so}"
ACTION="${1:-apply}"
CAVE_MB="${CAVE_MB:-10}"
CAVE_VADDR="${CAVE_VADDR:-0x300000}"
SECTION_NAME="${SECTION_NAME:-.ndk_patch}"

need_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "Missing: $1" >&2; exit 1; }; }
need_cmd objcopy
need_cmd readelf
need_cmd python3
need_cmd sudo
need_cmd sha256sum

status_lib() {
  echo "[*] File: $LIB"
  sha256sum "$LIB"
  echo
  readelf -W -S "$LIB" | rg -n "Name|${SECTION_NAME}|\.note|\.text|\.gnu_debugdata" || true
  echo
  readelf -W -l "$LIB" | sed -n '1,120p'
}

apply_patch() {
  local ts backup tmpdir work zero cave_bytes
  ts="$(date +%s)"
  backup="${LIB}.pre-ndk-cave.${ts}"
  tmpdir="$(mktemp -d)"
  work="$tmpdir/lib.work.so"
  zero="$tmpdir/cave.bin"
  trap 'rm -rf "${tmpdir:-}"' EXIT

  cave_bytes=$((CAVE_MB * 1024 * 1024))

  echo "[*] Backup: $backup"
  sudo cp -a "$LIB" "$backup"
  sudo cp -a "$LIB" "$work"
  sudo chown "$(id -u):$(id -g)" "$work"

  dd if=/dev/zero of="$zero" bs=1 count=0 seek="$cave_bytes" status=none

  echo "[*] Adding section $SECTION_NAME (${CAVE_MB}MB)"
  objcopy \
    --add-section "${SECTION_NAME}=$zero" \
    --set-section-flags "${SECTION_NAME}=alloc,load,readonly,code,contents" \
    --set-section-alignment "${SECTION_NAME}=4096" \
    "$work" "$work.obj"

  mv -f "$work.obj" "$work"

  echo "[*] Rewriting ELF: map $SECTION_NAME via NOTE->LOAD"
  python3 - "$work" "$SECTION_NAME" "$CAVE_VADDR" <<'PY'
import struct
import sys
from pathlib import Path

path = Path(sys.argv[1])
sec_name = sys.argv[2]
cave_vaddr = int(sys.argv[3], 0)

b = bytearray(path.read_bytes())
if b[:4] != b'\x7fELF':
    raise SystemExit('not ELF')
if b[4] != 2 or b[5] != 1:
    raise SystemExit('expecting ELF64 little-endian')

# ELF64 header offsets
E_PHOFF = 0x20
E_SHOFF = 0x28
E_PHENTSIZE = 0x36
E_PHNUM = 0x38
E_SHENTSIZE = 0x3A
E_SHNUM = 0x3C
E_SHSTRNDX = 0x3E

e_phoff = struct.unpack_from('<Q', b, E_PHOFF)[0]
e_shoff = struct.unpack_from('<Q', b, E_SHOFF)[0]
e_phentsize = struct.unpack_from('<H', b, E_PHENTSIZE)[0]
e_phnum = struct.unpack_from('<H', b, E_PHNUM)[0]
e_shentsize = struct.unpack_from('<H', b, E_SHENTSIZE)[0]
e_shnum = struct.unpack_from('<H', b, E_SHNUM)[0]
e_shstrndx = struct.unpack_from('<H', b, E_SHSTRNDX)[0]

if e_phentsize != 56 or e_shentsize != 64:
    raise SystemExit(f'unexpected sizes: ph={e_phentsize} sh={e_shentsize}')

# Read shstrtab location
shstr_off = e_shoff + e_shstrndx * e_shentsize
_, _, _, _, shstrtab_offset, shstrtab_size, _, _, _, _ = struct.unpack_from('<IIQQQQIIQQ', b, shstr_off)
shstr = bytes(b[shstrtab_offset:shstrtab_offset + shstrtab_size])

def get_sec_name(off):
    end = shstr.find(b'\x00', off)
    if end < 0:
        end = len(shstr)
    return shstr[off:end].decode('ascii', errors='replace')

sec_idx = None
sec_shoff = None
sec_fields = None
for i in range(e_shnum):
    off = e_shoff + i * e_shentsize
    fields = list(struct.unpack_from('<IIQQQQIIQQ', b, off))
    name = get_sec_name(fields[0])
    if name == sec_name:
        sec_idx = i
        sec_shoff = off
        sec_fields = fields
        break

if sec_idx is None:
    raise SystemExit(f'section not found: {sec_name}')

sh_name, sh_type, sh_flags, sh_addr, sh_offset, sh_size, sh_link, sh_info, sh_addralign, sh_entsize = sec_fields
if sh_offset % 0x1000 != 0:
    raise SystemExit(f'section offset not page aligned: 0x{sh_offset:x}')
if cave_vaddr % 0x1000 != 0:
    raise SystemExit(f'cave vaddr not page aligned: 0x{cave_vaddr:x}')

# Set section VA/alignment explicitly.
sh_addr = cave_vaddr
if sh_addralign < 0x1000:
    sh_addralign = 0x1000
struct.pack_into('<IIQQQQIIQQ', b, sec_shoff,
                 sh_name, sh_type, sh_flags, sh_addr, sh_offset, sh_size,
                 sh_link, sh_info, sh_addralign, sh_entsize)

# Reuse PT_NOTE entry as RX PT_LOAD for the cave.
note_idx = None
for i in range(e_phnum):
    off = e_phoff + i * e_phentsize
    p_type, p_flags = struct.unpack_from('<II', b, off)
    if p_type == 4:  # PT_NOTE
        note_idx = i
        break

if note_idx is None:
    raise SystemExit('PT_NOTE not found')

ph_off = e_phoff + note_idx * e_phentsize
p_type = 1          # PT_LOAD
p_flags = 0x5       # PF_R | PF_X
p_offset = sh_offset
p_vaddr = cave_vaddr
p_paddr = cave_vaddr
p_filesz = sh_size
p_memsz = sh_size
p_align = 0x1000

struct.pack_into('<IIQQQQQQ', b, ph_off,
                 p_type, p_flags, p_offset, p_vaddr, p_paddr,
                 p_filesz, p_memsz, p_align)

path.write_bytes(b)
print(f'patched section#{sec_idx} {sec_name}: off=0x{sh_offset:x} size=0x{sh_size:x} vaddr=0x{cave_vaddr:x}; PT_NOTE->PT_LOAD idx={note_idx}')
PY

  echo "[*] Installing patched library"
  sudo cp -a "$work" "$LIB"
  trap - EXIT

  echo "[*] Done"
  status_lib
}

restore_patch() {
  local latest
  latest="$(ls -1t "${LIB}.pre-ndk-cave."* 2>/dev/null | head -n1 || true)"
  if [ -z "$latest" ]; then
    echo "No backup found for $LIB" >&2
    exit 1
  fi
  echo "[*] Restoring from: $latest"
  sudo cp -a "$latest" "$LIB"
  status_lib
}

case "$ACTION" in
  apply) apply_patch ;;
  restore) restore_patch ;;
  status) status_lib ;;
  *)
    echo "Usage: $0 [apply|restore|status]" >&2
    exit 1
    ;;
esac
