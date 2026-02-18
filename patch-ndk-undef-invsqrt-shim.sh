#!/usr/bin/env bash
set -euo pipefail

LIB="${LIB:-/var/lib/waydroid/overlay/system/lib64/libndk_translation.so}"
ACTION="${1:-apply}"
CAVE_VA="${CAVE_VA:-0x300800}"

need_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "Missing: $1" >&2; exit 1; }; }
need_cmd python3
need_cmd sudo
need_cmd sha256sum
need_cmd readelf

sym_va() {
  readelf -W -s "$LIB" | awk '
    /_ZN15ndk_translation13UndefinedInsnEm/ && / FUNC / && !done {
      print "0x"$2;
      done=1;
    }'
}

status_lib() {
  echo "[*] File: $LIB"
  sha256sum "$LIB"
  echo "[*] UndefinedInsn VA: $(sym_va)"
  readelf -W -l "$LIB" | sed -n '1,120p'
}

apply_patch() {
  local ts backup sva
  ts="$(date +%s)"
  backup="${LIB}.pre-undef-invsqrt.${ts}"
  sva="$(sym_va)"
  if [ -z "$sva" ]; then
    echo "Failed to resolve UndefinedInsn symbol VA" >&2
    exit 1
  fi

  echo "[*] Backup: $backup"
  sudo cp -a "$LIB" "$backup"

  sudo python3 - "$LIB" "$sva" "$CAVE_VA" <<'PY'
import struct
import sys
from pathlib import Path

lib = Path(sys.argv[1])
func_va = int(sys.argv[2], 16)
cave_va = int(sys.argv[3], 0)
b = bytearray(lib.read_bytes())

if b[:4] != b'\x7fELF' or b[4] != 2 or b[5] != 1:
    raise SystemExit('Expected ELF64 little-endian')

e_phoff = struct.unpack_from('<Q', b, 0x20)[0]
e_phentsz = struct.unpack_from('<H', b, 0x36)[0]
e_phnum = struct.unpack_from('<H', b, 0x38)[0]
if e_phentsz != 56:
    raise SystemExit(f'unexpected e_phentsz={e_phentsz}')

loads = []
for i in range(e_phnum):
    off = e_phoff + i * e_phentsz
    p_type, p_flags, p_offset, p_vaddr, p_paddr, p_filesz, p_memsz, p_align = struct.unpack_from('<IIQQQQQQ', b, off)
    if p_type == 1:
        loads.append((p_offset, p_vaddr, p_filesz, p_memsz))

def va_to_off(va):
    for p_offset, p_vaddr, p_filesz, _p_memsz in loads:
        if p_vaddr <= va < p_vaddr + p_filesz:
            return p_offset + (va - p_vaddr)
    raise SystemExit(f'VA not file-backed: 0x{va:x}')

def rel32(from_next, to):
    d = to - from_next
    if not -(1 << 31) <= d < (1 << 31):
        raise SystemExit(f'rel32 out of range from 0x{from_next:x} to 0x{to:x}')
    return struct.pack('<i', d)

code = bytearray()
fixups = []
labels = {}

code += bytes.fromhex('53')                        # push rbx
code += bytes.fromhex('4889fb')                    # mov rbx,rdi
code += bytes.fromhex('4881e700f0ffff')            # and rdi,0xfffffffffffff000
code += bytes.fromhex('be00100000')                # mov esi,0x1000
code += bytes.fromhex('ba07000000')                # mov edx,0x7
code += bytes.fromhex('b80a000000')                # mov eax,0xa
code += bytes.fromhex('0f05')                      # syscall (mprotect)
code += bytes.fromhex('85c0')                      # test eax,eax
code += bytes.fromhex('0f8500000000')              # jne done
fixups.append((len(code) - 4, 'done'))

code += bytes.fromhex('8b03')                      # mov eax,[rbx]
code += bytes.fromhex('89c1')                      # mov ecx,eax
code += bytes.fromhex('81e100f8ffff')              # and ecx,0xfffff800
code += bytes.fromhex('81f900d8e16e')              # cmp ecx,0x6ee1d800
code += bytes.fromhex('0f8500000000')              # jne write_nop
fixups.append((len(code) - 4, 'write_nop'))

code += bytes.fromhex('25ff070000')                # and eax,0x7ff
code += bytes.fromhex('0d00f8e16e')                # or eax,0x6ee1f800
code += bytes.fromhex('8903')                      # mov [rbx],eax
code += bytes.fromhex('8b5304')                    # mov edx,[rbx+4]
code += bytes.fromhex('81fa1f2003d5')              # cmp edx,0xd503201f
code += bytes.fromhex('0f8500000000')              # jne done
fixups.append((len(code) - 4, 'done'))
code += bytes.fromhex('89c1')                      # mov ecx,eax
code += bytes.fromhex('83e11f')                    # and ecx,0x1f
code += bytes.fromhex('89ca')                      # mov edx,ecx
code += bytes.fromhex('c1e205')                    # shl edx,5
code += bytes.fromhex('09ca')                      # or edx,ecx
code += bytes.fromhex('81ca00d8e14e')              # or edx,0x4ee1d800
code += bytes.fromhex('895304')                    # mov [rbx+4],edx
code += bytes.fromhex('e900000000')                # jmp done
fixups.append((len(code) - 4, 'done'))

labels['write_nop'] = len(code)
code += bytes.fromhex('c7031f2003d5')              # mov dword [rbx],0xd503201f

labels['done'] = len(code)
code += bytes.fromhex('b804000000')                # mov eax,4
code += bytes.fromhex('5b')                        # pop rbx
code += bytes.fromhex('c3')                        # ret

cave_off = va_to_off(cave_va)
if cave_off + len(code) > len(b):
    raise SystemExit('cave write out of file range')

for rel_off, target in fixups:
    from_next = cave_va + rel_off + 4
    to_va = cave_va + labels[target] if isinstance(target, str) else target
    code[rel_off:rel_off + 4] = rel32(from_next, to_va)
b[cave_off:cave_off + len(code)] = code

func_off = va_to_off(func_va)
patch_size = 11
jmp = bytearray(b'\xE9\x00\x00\x00\x00')
jmp[1:5] = rel32(func_va + 5, cave_va)
patch = jmp + (b'\x90' * (patch_size - len(jmp)))
b[func_off:func_off + patch_size] = patch

lib.write_bytes(b)
print(f'patched func_va=0x{func_va:x} func_off=0x{func_off:x} cave_va=0x{cave_va:x} cave_off=0x{cave_off:x} code_len=0x{len(code):x}')
PY

  sha256sum "$LIB"
}

restore_patch() {
  local latest
  latest="$(ls -1t "${LIB}.pre-undef-invsqrt."* 2>/dev/null | head -n1 || true)"
  [ -n "$latest" ] || { echo "No backup found" >&2; exit 1; }
  echo "[*] Restoring $latest"
  sudo cp -a "$latest" "$LIB"
  sha256sum "$LIB"
}

case "$ACTION" in
  apply) apply_patch ;;
  restore) restore_patch ;;
  status) status_lib ;;
  *) echo "Usage: $0 [apply|restore|status]" >&2; exit 1 ;;
esac
