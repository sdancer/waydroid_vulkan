#!/usr/bin/env bash
set -euo pipefail

# Rebuild libndk_translation_proxy_libvulkan.so from a pristine workspace copy.
# It starts by adding an extra executable code cave section and mapping it as RX.
#
# Usage:
#   ./rebuild_proxy_from_original.sh sync-original
#   ./rebuild_proxy_from_original.sh build
#   ./rebuild_proxy_from_original.sh install
#   ./rebuild_proxy_from_original.sh status
#
# Outputs:
#   ./libndk_translation_proxy_libvulkan.original.so   (pristine copy)
#   ./libndk_translation_proxy_libvulkan.patched.so    (rebuilt output)

ACTION="${1:-build}"

SYSTEM_LIB="/var/lib/waydroid/overlay/system/lib64/libndk_translation_proxy_libvulkan.so"
ORIG_LIB="${PWD}/libndk_translation_proxy_libvulkan.original.so"
PATCHED_LIB="${PWD}/libndk_translation_proxy_libvulkan.patched.so"

SECTION_NAME="${SECTION_NAME:-.proxy_patch}"
SECTION_MB="${SECTION_MB:-4}"
SECTION_VADDR="${SECTION_VADDR:-0x9e000}"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing command: $1" >&2
    exit 1
  }
}

need_cmd objcopy
need_cmd readelf
need_cmd python3
need_cmd sha256sum
need_cmd sudo

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
    echo
    readelf -W -S "$PATCHED_LIB" | rg -n "Name|${SECTION_NAME}|\\.text|\\.note" || true
    echo
    readelf -W -l "$PATCHED_LIB" | sed -n '1,120p'
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
  local tmpdir work cave cave_bytes
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "${tmpdir:-}"' EXIT

  if [[ ! -f "$ORIG_LIB" ]]; then
    echo "Original not found: $ORIG_LIB" >&2
    echo "Run: $0 sync-original" >&2
    exit 1
  fi

  work="$tmpdir/lib.work.so"
  cave="$tmpdir/cave.bin"
  cave_bytes=$((SECTION_MB * 1024 * 1024))

  cp -a "$ORIG_LIB" "$work"
  dd if=/dev/zero of="$cave" bs=1 count=0 seek="$cave_bytes" status=none

  echo "[*] Adding section ${SECTION_NAME} (${SECTION_MB} MB)"
  objcopy \
    --add-section "${SECTION_NAME}=${cave}" \
    --set-section-flags "${SECTION_NAME}=alloc,load,readonly,code,contents" \
    --set-section-alignment "${SECTION_NAME}=4096" \
    "$work" "$work.obj"
  mv -f "$work.obj" "$work"

  echo "[*] Rewriting section VA + PT_NOTE->PT_LOAD RX mapping"
  python3 - "$work" "$SECTION_NAME" "$SECTION_VADDR" <<'PY'
import struct
import sys
from pathlib import Path

path = Path(sys.argv[1])
sec_name = sys.argv[2]
sec_vaddr = int(sys.argv[3], 0)

b = bytearray(path.read_bytes())
if b[:4] != b"\x7fELF":
    raise SystemExit("not ELF")
if b[4] != 2 or b[5] != 1:
    raise SystemExit("expecting ELF64 little-endian")

# ELF64 header offsets
E_PHOFF = 0x20
E_SHOFF = 0x28
E_PHENTSIZE = 0x36
E_PHNUM = 0x38
E_SHENTSIZE = 0x3A
E_SHNUM = 0x3C
E_SHSTRNDX = 0x3E

e_phoff = struct.unpack_from("<Q", b, E_PHOFF)[0]
e_shoff = struct.unpack_from("<Q", b, E_SHOFF)[0]
e_phentsize = struct.unpack_from("<H", b, E_PHENTSIZE)[0]
e_phnum = struct.unpack_from("<H", b, E_PHNUM)[0]
e_shentsize = struct.unpack_from("<H", b, E_SHENTSIZE)[0]
e_shnum = struct.unpack_from("<H", b, E_SHNUM)[0]
e_shstrndx = struct.unpack_from("<H", b, E_SHSTRNDX)[0]

if e_phentsize != 56 or e_shentsize != 64:
    raise SystemExit(f"unexpected sizes ph={e_phentsize} sh={e_shentsize}")

shstr_off = e_shoff + e_shstrndx * e_shentsize
_, _, _, _, shstrtab_offset, shstrtab_size, _, _, _, _ = struct.unpack_from("<IIQQQQIIQQ", b, shstr_off)
shstr = bytes(b[shstrtab_offset:shstrtab_offset + shstrtab_size])

def sec_name_at(off):
    end = shstr.find(b"\x00", off)
    if end < 0:
        end = len(shstr)
    return shstr[off:end].decode("ascii", errors="replace")

sec_idx = None
sec_shoff = None
sec_fields = None
for i in range(e_shnum):
    off = e_shoff + i * e_shentsize
    fields = list(struct.unpack_from("<IIQQQQIIQQ", b, off))
    if sec_name_at(fields[0]) == sec_name:
        sec_idx = i
        sec_shoff = off
        sec_fields = fields
        break

if sec_idx is None:
    raise SystemExit(f"section not found: {sec_name}")

sh_name, sh_type, sh_flags, sh_addr, sh_offset, sh_size, sh_link, sh_info, sh_addralign, sh_entsize = sec_fields
if sh_offset % 0x1000 != 0:
    raise SystemExit(f"section offset not page-aligned: 0x{sh_offset:x}")
if sec_vaddr % 0x1000 != 0:
    raise SystemExit(f"section vaddr not page-aligned: 0x{sec_vaddr:x}")

sh_addr = sec_vaddr
if sh_addralign < 0x1000:
    sh_addralign = 0x1000
struct.pack_into("<IIQQQQIIQQ", b, sec_shoff,
                 sh_name, sh_type, sh_flags, sh_addr, sh_offset, sh_size,
                 sh_link, sh_info, sh_addralign, sh_entsize)

note_idx = None
for i in range(e_phnum):
    off = e_phoff + i * e_phentsize
    p_type, _ = struct.unpack_from("<II", b, off)
    if p_type == 4:  # PT_NOTE
        note_idx = i
        break

if note_idx is None:
    raise SystemExit("PT_NOTE not found")

ph_off = e_phoff + note_idx * e_phentsize
struct.pack_into("<IIQQQQQQ", b, ph_off,
                 1,      # PT_LOAD
                 0x5,    # PF_R|PF_X
                 sh_offset,
                 sec_vaddr,
                 sec_vaddr,
                 sh_size,
                 sh_size,
                 0x1000)

path.write_bytes(b)
print(f"patched section#{sec_idx} {sec_name}: off=0x{sh_offset:x} size=0x{sh_size:x} vaddr=0x{sec_vaddr:x}, phdr_note_idx={note_idx}")
PY

  cp -a "$work" "$PATCHED_LIB"
  sha256sum "$PATCHED_LIB"
  trap - EXIT
}

install_patched() {
  if [[ ! -f "$PATCHED_LIB" ]]; then
    echo "Patched output not found: $PATCHED_LIB" >&2
    echo "Run: $0 build" >&2
    exit 1
  fi
  echo "[*] Installing patched proxy to Waydroid overlay"
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

