#!/usr/bin/env bash
set -euo pipefail

# Patch missing Vulkan proc names into BOTH proxy lookup tables with correct file offsets.
# Requires a proxy binary that already includes .proxy_patch (from rebuild_proxy_from_original.sh build).
#
# Usage:
#   ./patch-proxy-missing3-correct.sh [input_so] [output_so]
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

# File offsets for the two 547-entry dispatch tables.
TABLES = [0x96768, 0x96998]
COUNT = 0x223
ENT_SZ = 16

TARGETS = [
    ("vkCmdWriteAccelerationStructuresPropertiesKHR", "vkCmdTraceRaysIndirect2KHR"),
    ("vkGetPhysicalDeviceCalibrateableTimeDomainsEXT", "vkGetPhysicalDeviceToolPropertiesEXT"),
    ("vkGetDeviceFaultInfoEXT", "vkGetDeviceGroupSurfacePresentModes2EXT"),
]

def elf_sections(blob):
    if blob[:4] != b"\x7fELF" or blob[4] != 2 or blob[5] != 1:
        raise SystemExit("expected ELF64 little-endian")
    e_shoff = struct.unpack_from("<Q", blob, 0x28)[0]
    e_shentsz = struct.unpack_from("<H", blob, 0x3A)[0]
    e_shnum = struct.unpack_from("<H", blob, 0x3C)[0]
    e_shstrndx = struct.unpack_from("<H", blob, 0x3E)[0]
    if e_shentsz != 64:
        raise SystemExit(f"unexpected e_shentsz={e_shentsz}")

    shstr_off = e_shoff + e_shstrndx * e_shentsz
    sh_name, sh_type, sh_flags, sh_addr, sh_offset, sh_size, sh_link, sh_info, sh_addralign, sh_entsize = struct.unpack_from(
        "<IIQQQQIIQQ", blob, shstr_off
    )
    shstr = blob[sh_offset:sh_offset + sh_size]

    out = []
    for i in range(e_shnum):
        off = e_shoff + i * e_shentsz
        fields = struct.unpack_from("<IIQQQQIIQQ", blob, off)
        nm_off = fields[0]
        end = shstr.find(b"\0", nm_off)
        if end < 0:
            end = len(shstr)
        name = bytes(shstr[nm_off:end]).decode("ascii", errors="replace")
        out.append((name, fields))
    return out

sections = dict(elf_sections(b))
if ".proxy_patch" not in sections:
    raise SystemExit(".proxy_patch section missing; run rebuild_proxy_from_original.sh build first")

_, _, _, sec_addr, sec_off, sec_sz, _, _, _, _ = sections[".proxy_patch"]
if sec_sz < 0x100:
    raise SystemExit(".proxy_patch too small")

cursor = sec_off
limit = sec_off + sec_sz
new_ptr = {}
for name, _ in TARGETS:
    raw = name.encode("ascii") + b"\0"
    if cursor + len(raw) > limit:
        raise SystemExit(".proxy_patch exhausted while writing target names")
    b[cursor:cursor + len(raw)] = raw
    new_ptr[name] = cursor
    cursor += len(raw)


def read_cstr(ptr):
    if not (0 <= ptr < len(b)):
        return None
    end = b.find(b"\0", ptr)
    if end < 0:
        return None
    return bytes(b[ptr:end]).decode("ascii", errors="ignore")

for base in TABLES:
    entries = []
    by_name = {}
    for i in range(COUNT):
        off = base + i * ENT_SZ
        np, wp = struct.unpack_from("<QQ", b, off)
        name = read_cstr(np)
        if name is None:
            raise SystemExit(f"bad name pointer in table 0x{base:x} idx={i} np=0x{np:x}")
        e = {"idx": i, "off": off, "np": np, "wp": wp, "name": name}
        entries.append(e)
        by_name.setdefault(name, []).append(e)

    # Resolve wrappers from known supported APIs in this same table.
    target_to_wrapper = {}
    for tname, src_name in TARGETS:
        src = by_name.get(src_name)
        if not src:
            raise SystemExit(f"table 0x{base:x}: source wrapper name missing: {src_name}")
        target_to_wrapper[tname] = src[0]["wp"]

    # Pick donor rows dynamically from low-impact acquire/display entries in this table.
    donor_rows = []
    for e in entries:
        nm = e["name"]
        if not nm.startswith("vkAcquire"):
            continue
        if "Display" not in nm:
            continue
        donor_rows.append(e)
    if len(donor_rows) < len(TARGETS):
        raise SystemExit(f"table 0x{base:x}: insufficient donor rows ({len(donor_rows)})")
    donor_rows = donor_rows[:len(TARGETS)]

    # Apply target names onto donor rows.
    used = set()
    for (tname, _), row in zip(TARGETS, donor_rows):
        if row["idx"] in used:
            raise SystemExit("donor row reused unexpectedly")
        used.add(row["idx"])
        row["np"] = new_ptr[tname]
        row["name"] = tname
        row["wp"] = target_to_wrapper[tname]

    # Keep binary-search assumptions valid.
    entries.sort(key=lambda e: e["name"])

    for i, e in enumerate(entries):
        off = base + i * ENT_SZ
        struct.pack_into("<QQ", b, off, e["np"], e["wp"])

    # Post-check: targets exist in this table.
    seen = set()
    for i in range(COUNT):
        np, wp = struct.unpack_from("<QQ", b, base + i * ENT_SZ)
        nm = read_cstr(np)
        if nm in {t[0] for t in TARGETS}:
            seen.add(nm)
    missing = [t[0] for t in TARGETS if t[0] not in seen]
    if missing:
        raise SystemExit(f"table 0x{base:x}: missing targets after sort: {missing}")

out_path.write_bytes(bytes(b))
print(f"patched: {out_path}")
print(f".proxy_patch file_off=0x{sec_off:x} size=0x{sec_sz:x}")
for t, _ in TARGETS:
    print(f"  name '{t}' ptr(file)=0x{new_ptr[t]:x}")
PY

sha256sum "$OUT_SO"
