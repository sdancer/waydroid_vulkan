#!/usr/bin/env bash
set -euo pipefail

# Install a safe sparse-old shim:
# - exposes vkGetPhysicalDeviceSparseImageFormatProperties name
# - points all known sparse-old lookup rows to a tiny no-op handler in .proxy_patch (ret)
#
# Usage:
#   ./patch-proxy-sparse-old-safe.sh [input_so] [output_so]
#
# Defaults:
#   input_so  = ./libndk_translation_proxy_libvulkan.patched.so
#   output_so = same as input

IN_SO="${1:-./libndk_translation_proxy_libvulkan.patched.so}"
OUT_SO="${2:-$IN_SO}"

python3 - "$IN_SO" "$OUT_SO" <<'PY'
import struct
import sys
from pathlib import Path

in_path = Path(sys.argv[1])
out_path = Path(sys.argv[2])
b = bytearray(in_path.read_bytes())

if b[:4] != b"\x7fELF" or b[4] != 2 or b[5] != 1:
    raise SystemExit("expected ELF64 little-endian")

e_shoff = struct.unpack_from("<Q", b, 0x28)[0]
e_shentsz = struct.unpack_from("<H", b, 0x3A)[0]
e_shnum = struct.unpack_from("<H", b, 0x3C)[0]
e_shstrndx = struct.unpack_from("<H", b, 0x3E)[0]

shstr_off = e_shoff + e_shstrndx * e_shentsz
_, _, _, _, shstrtab_off, shstrtab_sz, _, _, _, _ = struct.unpack_from("<IIQQQQIIQQ", b, shstr_off)
shstr = b[shstrtab_off:shstrtab_off + shstrtab_sz]

proxy = None
for i in range(e_shnum):
    off = e_shoff + i * e_shentsz
    fields = struct.unpack_from("<IIQQQQIIQQ", b, off)
    name_off = fields[0]
    end = shstr.find(b"\0", name_off)
    if end < 0:
        end = len(shstr)
    name = shstr[name_off:end]
    if name == b".proxy_patch":
        proxy = fields
        break

if proxy is None:
    raise SystemExit(".proxy_patch missing; rebuild with extended RX section first")

_, _, _, sec_va, sec_off, sec_sz, _, _, _, _ = proxy

# Ensure canonical sparse-old name at known rodata slot used by proxy rows.
name_off = 0x701D
name_raw = b"vkGetPhysicalDeviceSparseImageFormatProperties\0"
b[name_off:name_off + len(name_raw)] = name_raw
if name_off + len(name_raw) < len(b):
    b[name_off + len(name_raw)] = 0

# Allocate one-byte "ret" stub in .proxy_patch.
cursor = (sec_off + 0x1200 + 15) & ~15
stub_off = None
while cursor < sec_off + sec_sz:
    if b[cursor] == 0:
        stub_off = cursor
        break
    cursor += 16
if stub_off is None:
    raise SystemExit("no code cave found in .proxy_patch")

b[stub_off] = 0xC3
stub_va = sec_va + (stub_off - sec_off)

# Patch all known sparse-old dispatch table regions.
patched = []
for base, count in ((0x92220, 0x223), (0x96318, 0x223), (0x96768, 0x223), (0x96998, 0x223)):
    for i in range(count):
        off = base + i * 16
        if off + 16 > len(b):
            break
        np, wp = struct.unpack_from("<QQ", b, off)
        if np >= len(b):
            continue
        end = b.find(b"\0", np)
        if end < 0:
            continue
        nm = b[np:end].decode("ascii", errors="ignore")
        if nm == "vkGetPhysicalDeviceSparseImageFormatProperties":
            struct.pack_into("<QQ", b, off, np, stub_va)
            patched.append((base, i, wp, stub_va))

if not patched:
    raise SystemExit("no sparse-old rows found to patch")

out_path.write_bytes(bytes(b))
print(f"safe stub va=0x{stub_va:x}")
for base, idx, old, new in patched:
    print(f"patched base=0x{base:x} idx={idx} old=0x{old:x} new=0x{new:x}")
PY

sha256sum "$OUT_SO"
