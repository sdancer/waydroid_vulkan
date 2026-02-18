#!/usr/bin/env bash
set -euo pipefail

# Install a new proxy wrapper stub into the extended RX section (.proxy_patch)
# and repoint one or both dispatch table entries to it.
#
# Example:
#   ./patch-proxy-rx-handler.sh \
#     --in ./libndk_translation_proxy_libvulkan.patched.so \
#     --out ./libndk_translation_proxy_libvulkan.patched.so \
#     --index 479 \
#     --both-tables \
#     --sig-va 0xb88d \
#     --host-va 0x9ae50 \
#     --name-va 0x701d

IN_SO="./libndk_translation_proxy_libvulkan.patched.so"
OUT_SO=""
INDEX=""
BOTH_TABLES=0
TABLE_BASE="0x96768"
TABLE_BASE2="0x96998"
SIG_VA=""
HOST_VA=""
NAME_VA=""
WRAP_VA="0x921e0"

usage() {
  cat <<'USAGE'
Usage:
  patch-proxy-rx-handler.sh --index N --sig-va HEX --host-va HEX --name-va HEX [options]

Required:
  --index N          Dispatch table index (0..546).
  --sig-va HEX       VA of signature token string (e.g. 0xb88d for "vpiiiiipp").
  --host-va HEX      VA of host thunk/cached function pointer slot.
  --name-va HEX      VA of API descriptor/name string.

Options:
  --in PATH          Input .so (default: ./libndk_translation_proxy_libvulkan.patched.so)
  --out PATH         Output .so (default: in-place edit)
  --table-base HEX   Primary table base (default: 0x96768)
  --table-base2 HEX  Secondary table base (default: 0x96998)
  --both-tables      Patch wrapper ptr in both tables.
  --wrap-va HEX      VA of WrapGuestFunctionImpl@plt (default: 0x921e0)
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --in) IN_SO="$2"; shift 2 ;;
    --out) OUT_SO="$2"; shift 2 ;;
    --index) INDEX="$2"; shift 2 ;;
    --table-base) TABLE_BASE="$2"; shift 2 ;;
    --table-base2) TABLE_BASE2="$2"; shift 2 ;;
    --both-tables) BOTH_TABLES=1; shift ;;
    --sig-va) SIG_VA="$2"; shift 2 ;;
    --host-va) HOST_VA="$2"; shift 2 ;;
    --name-va) NAME_VA="$2"; shift 2 ;;
    --wrap-va) WRAP_VA="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

[[ -n "$INDEX" && -n "$SIG_VA" && -n "$HOST_VA" && -n "$NAME_VA" ]] || {
  usage
  exit 1
}

if [[ -z "$OUT_SO" ]]; then
  OUT_SO="$IN_SO"
fi

python3 - "$IN_SO" "$OUT_SO" "$INDEX" "$TABLE_BASE" "$TABLE_BASE2" "$BOTH_TABLES" "$SIG_VA" "$HOST_VA" "$NAME_VA" "$WRAP_VA" <<'PY'
import struct
import sys
from pathlib import Path

in_path = Path(sys.argv[1])
out_path = Path(sys.argv[2])
index = int(sys.argv[3], 0)
table_base = int(sys.argv[4], 0)
table_base2 = int(sys.argv[5], 0)
both_tables = int(sys.argv[6], 0) != 0
sig_va = int(sys.argv[7], 0)
host_va = int(sys.argv[8], 0)
name_va = int(sys.argv[9], 0)
wrap_va = int(sys.argv[10], 0)

if not (0 <= index < 0x223):
    raise SystemExit(f"invalid index: {index}")

b = bytearray(in_path.read_bytes())
if b[:4] != b"\x7fELF" or b[4] != 2 or b[5] != 1:
    raise SystemExit("expected ELF64 little-endian")

e_phoff = struct.unpack_from("<Q", b, 0x20)[0]
e_shoff = struct.unpack_from("<Q", b, 0x28)[0]
e_phentsz = struct.unpack_from("<H", b, 0x36)[0]
e_phnum = struct.unpack_from("<H", b, 0x38)[0]
e_shentsz = struct.unpack_from("<H", b, 0x3A)[0]
e_shnum = struct.unpack_from("<H", b, 0x3C)[0]
e_shstrndx = struct.unpack_from("<H", b, 0x3E)[0]

if e_phentsz != 56 or e_shentsz != 64:
    raise SystemExit("unexpected ELF header sizes")

# Section name table
shstr_off = e_shoff + e_shstrndx * e_shentsz
_, _, _, _, shstrtab_off, shstrtab_sz, _, _, _, _ = struct.unpack_from("<IIQQQQIIQQ", b, shstr_off)
shstr = b[shstrtab_off:shstrtab_off + shstrtab_sz]

def sh_name_at(name_off: int) -> str:
    end = shstr.find(b"\0", name_off)
    if end < 0:
        end = len(shstr)
    return bytes(shstr[name_off:end]).decode("ascii", errors="replace")

proxy = None
for i in range(e_shnum):
    off = e_shoff + i * e_shentsz
    fields = struct.unpack_from("<IIQQQQIIQQ", b, off)
    name = sh_name_at(fields[0])
    if name == ".proxy_patch":
        proxy = fields
        break
if proxy is None:
    raise SystemExit(".proxy_patch section missing: rebuild with extended RX first")

_, _, sh_flags, sh_addr, sh_off, sh_size, _, _, sh_addralign, _ = proxy
# SHF_EXECINSTR = 0x4, SHF_ALLOC = 0x2
if (sh_flags & 0x6) != 0x6:
    raise SystemExit(f".proxy_patch flags not AX: 0x{sh_flags:x}")

# Verify PT_LOAD RX covers .proxy_patch
covered = False
for i in range(e_phnum):
    off = e_phoff + i * e_phentsz
    p_type, p_flags, p_offset, p_vaddr, p_paddr, p_filesz, p_memsz, p_align = struct.unpack_from("<IIQQQQQQ", b, off)
    if p_type != 1:
        continue
    if p_offset <= sh_off and (p_offset + p_filesz) >= (sh_off + sh_size):
        # PF_R|PF_X = 0x5
        if (p_flags & 0x5) == 0x5:
            covered = True
            break
if not covered:
    raise SystemExit(".proxy_patch is not covered by an RX PT_LOAD segment")

# Build absolute-address wrapper stub in .proxy_patch:
#   movabs rsi, sig_va
#   movabs rdx, host_va
#   movabs rcx, name_va
#   movabs rax, wrap_va
#   jmp    rax
stub = bytearray()
stub += b"\x48\xBE" + struct.pack("<Q", sig_va)
stub += b"\x48\xBA" + struct.pack("<Q", host_va)
stub += b"\x48\xB9" + struct.pack("<Q", name_va)
stub += b"\x48\xB8" + struct.pack("<Q", wrap_va)
stub += b"\xFF\xE0"

align = 16
stub_len = len(stub)

# Find first aligned zero run in .proxy_patch
start = sh_off
end = sh_off + sh_size
cursor = (start + (align - 1)) & ~(align - 1)
place = None
zeros = b"\x00" * stub_len
while cursor + stub_len <= end:
    if b[cursor:cursor + stub_len] == zeros:
        place = cursor
        break
    cursor += align
if place is None:
    raise SystemExit("no code cave left in .proxy_patch")

b[place:place + stub_len] = stub
new_wrapper_va = sh_addr + (place - sh_off)

def set_wrapper_ptr(base: int):
    ent_off = base + index * 16
    if ent_off + 16 > len(b):
        raise SystemExit(f"table base out of range: 0x{base:x}")
    name_ptr, _ = struct.unpack_from("<QQ", b, ent_off)
    struct.pack_into("<QQ", b, ent_off, name_ptr, new_wrapper_va)

set_wrapper_ptr(table_base)
if both_tables:
    set_wrapper_ptr(table_base2)

out_path.write_bytes(bytes(b))
print(f"installed handler in .proxy_patch file_off=0x{place:x} va=0x{new_wrapper_va:x} len={stub_len}")
print(f"patched table 0x{table_base:x} idx={index} wrapper=0x{new_wrapper_va:x}")
if both_tables:
    print(f"patched table 0x{table_base2:x} idx={index} wrapper=0x{new_wrapper_va:x}")
PY

sha256sum "$OUT_SO"
