#!/usr/bin/env bash
set -euo pipefail

LIB="${LIB:-/var/lib/waydroid/overlay/system/lib64/libndk_translation.so}"
ACTION="${1:-apply}"
CAVE_VA="${CAVE_VA:-0x300000}"
CAVE_SIZE="${CAVE_SIZE:-0x2000}"

# Decode function addresses in lib virtual-address space.
# We hook the "supported?" branch and route through a cave:
# - normal supported path falls through untouched
# - for selected opcodes, only force support when class context is AddSub-like
# - otherwise preserve original UndefinedInsn path
PATCH_SITE=0x1e5fd5       # test al,al ; je undef
TARGET_FALLTHROUGH=0x1e5fdb
TARGET_UNDEFINED=0x1e60b1

need_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "Missing: $1" >&2; exit 1; }; }
need_cmd python3
need_cmd sudo
need_cmd sha256sum
need_cmd readelf

status_lib() {
  echo "[*] File: $LIB"
  sha256sum "$LIB"
  echo
  readelf -W -l "$LIB" | sed -n '1,120p'
  echo
  python3 - <<'PY'
from pathlib import Path
import struct
p=Path('/var/lib/waydroid/overlay/system/lib64/libndk_translation.so')
b=p.read_bytes()
site=0x1e5fd5-0x0c9370+0x0c8370
print(f'patch bytes @site: {b[site:site+8].hex()}')
PY
}

apply_patch() {
  local ts backup
  ts="$(date +%s)"
  backup="${LIB}.pre-frsqrte-decode.${ts}"
  echo "[*] Backup: $backup"
  sudo cp -a "$LIB" "$backup"

  sudo python3 - "$LIB" "$CAVE_VA" "$CAVE_SIZE" <<'PY'
import struct
import sys
from pathlib import Path

lib = Path(sys.argv[1])
cave_va = int(sys.argv[2], 0)
cave_size = int(sys.argv[3], 0)

PATCH_SITE=0x1e5fd5
TARGET_FALLTHROUGH=0x1e5fdb
TARGET_UNDEFINED=0x1e60b1

# Opcode masks/values (mask low 11 bits for register fields).
# We compare multiple instruction forms that map to the same family.
MASK = 0xfffff800
VALUES = [0x6ee1d800, 0x2ea1d800, 0x7ea1d800, 0x7ee1d800]

b = bytearray(lib.read_bytes())

# ELF64 little endian headers
e_phoff = struct.unpack_from('<Q', b, 0x20)[0]
e_phentsz = struct.unpack_from('<H', b, 0x36)[0]
e_phnum = struct.unpack_from('<H', b, 0x38)[0]
if e_phentsz != 56:
    raise SystemExit(f'unexpected e_phentsz={e_phentsz}')

def va_to_off(va):
    # .text VA base 0x0c9370 at file off 0x0c8370
    return va - 0x0c9370 + 0x0c8370

# Reuse an existing cave LOAD segment when present, otherwise reuse PT_NOTE.
note_i = None
existing_cave = None
for i in range(e_phnum):
    off = e_phoff + i * e_phentsz
    p_type, p_flags, p_offset, p_vaddr, _p_paddr, p_filesz, _p_memsz, _p_align = struct.unpack_from('<IIQQQQQQ', b, off)
    if p_type == 1 and p_vaddr == cave_va and p_filesz > 0:
        existing_cave = (p_offset, p_filesz)
        break
    if p_type == 4:  # PT_NOTE
        note_i = i
if existing_cave is not None:
    new_off, cave_avail = existing_cave
else:
    if note_i is None:
        raise SystemExit('Neither existing cave LOAD nor PT_NOTE found')
    align = 0x1000
    new_off = (len(b) + align - 1) & ~(align - 1)
    need = new_off + cave_size
    if len(b) < need:
        b.extend(b'\x00' * (need - len(b)))
    cave_avail = cave_size
    ph = e_phoff + note_i * e_phentsz
    struct.pack_into('<IIQQQQQQ', b, ph,
                     1, 0x5, new_off, cave_va, cave_va, cave_size, cave_size, align)

# Build cave stub with reloc patching.
code = bytearray()
fixups = []  # (offset_of_rel32, target_va)
labels = {}

# test al, al
code += b'\x84\xC0'
# jne supported
code += b'\x0F\x85\x00\x00\x00\x00'; fixups.append((len(code)-4, 'supported'))

# eax = [r14+8] (guest instruction)
code += b'\x41\x8B\x46\x08'
# and eax, 0xfffff800
code += b'\x25\x00\xF8\xFF\xFF'

for v in VALUES:
    code += b'\x3D' + struct.pack('<I', v)  # cmp eax, imm32
    code += b'\x0F\x84\x00\x00\x00\x00'; fixups.append((len(code)-4, 'force'))

# default => original undefined path
code += b'\xE9\x00\x00\x00\x00'; fixups.append((len(code)-4, TARGET_UNDEFINED))

labels['force'] = len(code)
# Only force support in the same class context that reaches AddSub handling.
# r13b is the element-width/class selector in this decode path.
code += b'\x41\x80\xFD\x04'                      # cmp r13b,0x4
code += b'\x0F\x84\x0A\x00\x00\x00'              # je force_ok
code += b'\x41\x80\xFD\x08'                      # cmp r13b,0x8
code += b'\x0F\x85\x00\x00\x00\x00'              # jne undef
fixups.append((len(code)-4, TARGET_UNDEFINED))
code += b'\x41\xB5\x04'                          # mov r13b,0x4 (normalize to AddSub class)
# force_ok:
code += b'\xB0\x01'  # mov al,1
labels['supported'] = len(code)
code += b'\xE9\x00\x00\x00\x00'; fixups.append((len(code)-4, TARGET_FALLTHROUGH))

# Resolve rel32 fixups.
def rel32(from_va_next, to_va):
    d = to_va - from_va_next
    if not -(1<<31) <= d < (1<<31):
        raise SystemExit(f'rel32 out of range: from=0x{from_va_next:x} to=0x{to_va:x}')
    return struct.pack('<i', d)

for rel_off, target in fixups:
    insn_rel_field_va = cave_va + rel_off
    from_next = insn_rel_field_va + 4
    if isinstance(target, str):
        to_va = cave_va + labels[target]
    else:
        to_va = target
    code[rel_off:rel_off+4] = rel32(from_next, to_va)

# Write code into cave
if len(code) > cave_avail:
    raise SystemExit('cave code too large')
cave_span = max(len(code), 0x100)
b[new_off:new_off+cave_span] = b'\xCC' * cave_span
b[new_off:new_off+len(code)] = code

# Patch decode branch: replace `je 0x1e60b1` (6 bytes) with `jmp cave` + nop.
site_off = va_to_off(PATCH_SITE)
site = b[site_off:site_off+6]
if not (len(site) == 6 and site[0] == 0x0f and site[1] == 0x84):
    raise SystemExit(f'unexpected bytes at patch site: {site.hex()}')

jmp = bytearray(b'\xE9\x00\x00\x00\x00\x90')
from_next = PATCH_SITE + 5
jmp[1:5] = rel32(from_next, cave_va)
b[site_off:site_off+6] = jmp

lib.write_bytes(bytes(b))
where = f'existing_load cave_off=0x{new_off:x}' if existing_cave is not None else f'note->load idx={note_i} cave_off=0x{new_off:x}'
print(f'patched: {where} cave_va=0x{cave_va:x} cave_avail=0x{cave_avail:x} code_len=0x{len(code):x}')
print(f'patch_site old={site.hex()} new={jmp.hex()}')
PY

  status_lib
}

restore_patch() {
  local latest
  latest="$(ls -1t "${LIB}.pre-frsqrte-decode."* 2>/dev/null | head -n1 || true)"
  if [ -z "$latest" ]; then
    echo "No backup found for $LIB" >&2
    exit 1
  fi
  echo "[*] Restoring from $latest"
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
