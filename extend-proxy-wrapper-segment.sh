#!/usr/bin/env bash
set -euo pipefail

LIB="/var/lib/waydroid/overlay/system/lib64/libndk_translation_proxy_libvulkan.so"
ACTION="${1:-apply}"

need_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "Missing: $1" >&2; exit 1; }; }
need_cmd python3
need_cmd sudo
need_cmd sha256sum

apply_patch() {
  local ts backup
  ts="$(date +%s)"
  backup="${LIB}.pre-extend-seg.${ts}"
  echo "[*] Backup: $backup"
  sudo cp -a "$LIB" "$backup"

  sudo python3 - <<'PY'
import struct
from pathlib import Path

lib_path = Path('/var/lib/waydroid/overlay/system/lib64/libndk_translation_proxy_libvulkan.so')
b = bytearray(lib_path.read_bytes())

# ELF64 little-endian
e_phoff = struct.unpack_from('<Q', b, 0x20)[0]
e_phentsize = struct.unpack_from('<H', b, 0x36)[0]
e_phnum = struct.unpack_from('<H', b, 0x38)[0]

if e_phentsize != 56:
    raise RuntimeError(f'unexpected phentsize: {e_phentsize}')

note_i = None
for i in range(e_phnum):
    off = e_phoff + i * e_phentsize
    p_type, p_flags = struct.unpack_from('<II', b, off)
    p_offset, p_vaddr, p_paddr, p_filesz, p_memsz, p_align = struct.unpack_from('<QQQQQQ', b, off + 8)
    if p_type == 4:  # PT_NOTE
        note_i = i
        break

if note_i is None:
    raise RuntimeError('PT_NOTE segment not found')

off = e_phoff + note_i * e_phentsize

# New dedicated wrapper segment from NOTE phdr slot.
# Must satisfy offset % 0x1000 == vaddr % 0x1000.
# Use a fresh VA page after existing LOAD ranges.
vaddr = 0x9e000
align = 0x1000
seg_size = 0x2000

cur_len = len(b)
new_off = ((max(cur_len, 0) + align - 1) // align) * align

need_len = new_off + seg_size
if len(b) < need_len:
    b.extend(b'\x00' * (need_len - len(b)))

# Patch program header: LOAD RX at chosen file offset.
struct.pack_into('<II', b, off, 1, 0x5)  # PT_LOAD, PF_R|PF_X
struct.pack_into('<QQQQQQ', b, off + 8, new_off, vaddr, vaddr, seg_size, seg_size, align)

# Place first custom wrapper at segment start.
wrapper_va = vaddr
wrapper_off = new_off + (wrapper_va - vaddr)
stub = bytes([0x31, 0xC0, 0xC3, 0xCC, 0xCC, 0xCC, 0xCC, 0xCC])  # xor eax,eax; ret
b[wrapper_off:wrapper_off + len(stub)] = stub

# Ensure sparse-old name matches and route idx 479 to new wrapper VA.
legacy = b'xkGetPhysicalDeviceSparseImageFormatProperties\x00'
p = b.find(legacy)
if p >= 0:
    b[p] = ord('v')

table_off = 0x96768
idx = 479
struct.pack_into('<Q', b, table_off + idx * 16 + 8, wrapper_va)

lib_path.write_bytes(bytes(b))
print(f'patched NOTE->LOAD phdr index={note_i} new_off=0x{new_off:x} seg_size=0x{seg_size:x} wrapper_va=0x{wrapper_va:x}')
PY

  sha256sum "$LIB"
}

restore_patch() {
  local latest
  latest="$(ls -1t "${LIB}.pre-extend-seg."* 2>/dev/null | head -n1 || true)"
  if [ -z "$latest" ]; then
    echo "No backup found for $LIB" >&2
    exit 1
  fi
  echo "[*] Restoring from $latest"
  sudo cp -a "$latest" "$LIB"
  sha256sum "$LIB"
}

case "$ACTION" in
  apply) apply_patch ;;
  restore) restore_patch ;;
  *)
    echo "Usage: $0 [apply|restore]" >&2
    exit 1
    ;;
esac
