#!/usr/bin/env bash
set -euo pipefail

# Patch 3 missing vkGetInstanceProcAddr names by in-place row remap on active table.
# - Keeps lookup table size unchanged (0x223).
# - Injects custom wrappers in .proxy_patch with explicit signatures.
# - Replaces donor rows at exact lower-bound positions for stable lookup order.
#
# Usage:
#   ./patch-proxy-gipa-missing3-inplace-custom.sh [input_so] [output_so]
#
# Defaults:
#   input_so  = ./libndk_translation_proxy_libvulkan.patched.so
#   output_so = same as input

IN_SO="${1:-./libndk_translation_proxy_libvulkan.patched.so}"
OUT_SO="${2:-$IN_SO}"

# Optional controlled return override for calibrated domains API on ARM path.
# When enabled, wrapper writes:
#   *pCount = CALIB_FORCE_COUNT (if pCount != NULL)
#   return   CALIB_FORCE_RESULT
CALIB_FORCE_ENABLE="${CALIB_FORCE_ENABLE:-1}"
CALIB_FORCE_RESULT="${CALIB_FORCE_RESULT:-0}"
CALIB_FORCE_COUNT="${CALIB_FORCE_COUNT:-3}"
CALIB_DIRECT_BRIDGE="${CALIB_DIRECT_BRIDGE:-1}"

python3 - "$IN_SO" "$OUT_SO" <<'PY'
import struct
import sys
import os
from pathlib import Path

in_path = Path(sys.argv[1])
out_path = Path(sys.argv[2])
b = bytearray(in_path.read_bytes())

TABLES = [0x96768]
COUNT = 0x223
ENT_SZ = 16

# (missing_name, signature, host_symbol_name, donor_row_name_for_order_slot)
TARGETS = [
    ("vkCmdWriteAccelerationStructuresPropertiesKHR", "vpipipi", "vkCmdWriteAccelerationStructuresPropertiesKHR", "vkCmdWriteBufferMarker2AMD"),
    ("vkGetDeviceFaultInfoEXT", "ippp", "vkGetDeviceFaultInfoEXT", "vkGetDeviceGroupPeerMemoryFeatures"),
    ("vkGetPhysicalDeviceCalibrateableTimeDomainsEXT", "ippp", "vkGetPhysicalDeviceCalibrateableTimeDomainsEXT", "vkGetPhysicalDeviceDisplayPlanePropertiesKHR"),
]

WRAP_GUEST_IMPL_PLT = 0x921e0
STRCMP_PLT = 0x92220
NEXT_GIPA_PTR = 0x9ae50
GIPA_PATCH_VA = 0x30ec5
GIPA_RESUME_VA = 0x30ece
EXPECTED_PATCH_BYTES = bytes.fromhex("41bf230200004989f6")
DONOR_SPARSE_OLD = "vkGetPastPresentationTimingGOOGLE"

if b[:4] != b"\x7fELF" or b[4] != 2 or b[5] != 1:
    raise SystemExit("expected ELF64 little-endian")

# Sections
E_SHOFF = 0x28
E_SHENTSIZE = 0x3A
E_SHNUM = 0x3C
E_SHSTRNDX = 0x3E
e_shoff = struct.unpack_from("<Q", b, E_SHOFF)[0]
e_shentsz = struct.unpack_from("<H", b, E_SHENTSIZE)[0]
e_shnum = struct.unpack_from("<H", b, E_SHNUM)[0]
e_shstrndx = struct.unpack_from("<H", b, E_SHSTRNDX)[0]
if e_shentsz != 64:
    raise SystemExit(f"unexpected section header size: {e_shentsz}")

shstr_hdr = e_shoff + e_shstrndx * e_shentsz
_, _, _, _, shstr_off, shstr_sz, _, _, _, _ = struct.unpack_from("<IIQQQQIIQQ", b, shstr_hdr)
shstr = b[shstr_off:shstr_off + shstr_sz]

sections = {}
for i in range(e_shnum):
    off = e_shoff + i * e_shentsz
    fields = struct.unpack_from("<IIQQQQIIQQ", b, off)
    nm_off = fields[0]
    end = shstr.find(b"\0", nm_off)
    if end < 0:
        end = len(shstr)
    name = bytes(shstr[nm_off:end]).decode("ascii", errors="replace")
    sections[name] = fields

if ".proxy_patch" not in sections:
    raise SystemExit(".proxy_patch missing; run rebuild_proxy_from_original.sh build first")
_, _, sec_flags, sec_va, sec_off, sec_sz, _, _, _, _ = sections[".proxy_patch"]
if (sec_flags & 0x6) != 0x6:
    raise SystemExit(f".proxy_patch not AX (flags=0x{sec_flags:x})")

# PT_LOAD mapping
E_PHOFF = 0x20
E_PHENTSIZE = 0x36
E_PHNUM = 0x38
e_phoff = struct.unpack_from("<Q", b, E_PHOFF)[0]
e_phentsz = struct.unpack_from("<H", b, E_PHENTSIZE)[0]
e_phnum = struct.unpack_from("<H", b, E_PHNUM)[0]
loads = []
for i in range(e_phnum):
    off = e_phoff + i * e_phentsz
    p_type, p_flags, p_off, p_vaddr, p_paddr, p_filesz, p_memsz, p_align = struct.unpack_from("<IIQQQQQQ", b, off)
    if p_type == 1:
        loads.append((p_off, p_vaddr, p_filesz, p_memsz))


def va_to_off(va: int):
    for p_off, p_va, p_filesz, _ in loads:
        if p_va <= va < p_va + p_filesz:
            return p_off + (va - p_va)
    return None


def read_cstr(ptr: int):
    off = va_to_off(ptr)
    if off is None and 0 <= ptr < len(b):
        off = ptr
    if off is None or not (0 <= off < len(b)):
        return None
    end = b.find(b"\0", off)
    if end < 0:
        return None
    return bytes(b[off:end]).decode("ascii", errors="ignore")


def parse_table(base: int):
    rows = []
    by_name = {}
    for i in range(COUNT):
        slot_va = base + i * ENT_SZ
        off = va_to_off(slot_va)
        if off is None:
            raise SystemExit(f"table slot VA not mapped: 0x{slot_va:x}")
        np, wp = struct.unpack_from("<QQ", b, off)
        nm = read_cstr(np)
        if nm is None:
            raise SystemExit(f"bad name ptr in table 0x{base:x} idx={i} np=0x{np:x}")
        row = {"idx": i, "off": off, "name": nm, "np": np, "wp": wp}
        rows.append(row)
        by_name[nm] = row
    return rows, by_name


def lower_bound_idx(rows, key):
    # Same algorithm as DoCustomTrampolineWithThunk_vkGetInstanceProcAddr @0x30eb0
    rbx = 0
    r15 = len(rows)
    rbp = r15
    while True:
        rbp >>= 1
        r12 = rbp
        nm = rows[rbx + r12]["name"]
        cmp = (nm > key) - (nm < key)  # sign of strcmp
        if cmp < 0:
            rbp = ~rbp
            rbx = rbx + r12 + 1
            rbp = rbp + r15
        r15 = rbp
        if rbp == 0:
            break
    return rbx

# Allocate payloads in .proxy_patch.
cur = sec_off + 0x1000
limit = sec_off + sec_sz - 0x100

sig_va = {}
name_va = {}
for name, sig, host_name, donor in TARGETS:
    if sig not in sig_va:
        raw = sig.encode("ascii") + b"\0"
        if cur + len(raw) > limit:
            raise SystemExit(".proxy_patch overflow writing signature")
        b[cur:cur+len(raw)] = raw
        sig_va[sig] = sec_va + (cur - sec_off)
        cur += len(raw)

for name, sig, host_name, donor in TARGETS:
    for s in (name, host_name):
        if s in name_va:
            continue
        raw = s.encode("ascii") + b"\0"
        if cur + len(raw) > limit:
            raise SystemExit(".proxy_patch overflow writing names")
        b[cur:cur+len(raw)] = raw
        name_va[s] = sec_va + (cur - sec_off)
        cur += len(raw)

LOG_MSG = "[proxy prehook] vkGIPA query\\n"
CALIB_WRAPPER_MSG = "[proxy wrapper] calib call\\n"
LOG_TAG = "ndk_translation"
CALIB_FMT = "calib rdi=%p a0=%p a1=%p a2=%p"
CALIB_FORCE_ENABLE = int(os.environ.get("CALIB_FORCE_ENABLE", "1"), 0)
CALIB_FORCE_RESULT = int(os.environ.get("CALIB_FORCE_RESULT", "0"), 0)
CALIB_FORCE_COUNT = int(os.environ.get("CALIB_FORCE_COUNT", "3"), 0)
CALIB_DIRECT_BRIDGE = int(os.environ.get("CALIB_DIRECT_BRIDGE", "1"), 0)
if not (-0x80000000 <= CALIB_FORCE_RESULT <= 0x7fffffff):
    raise SystemExit("CALIB_FORCE_RESULT must fit signed int32")
if not (0 <= CALIB_FORCE_COUNT <= 0xffffffff):
    raise SystemExit("CALIB_FORCE_COUNT must fit uint32")
for s in (LOG_MSG, LOG_TAG, CALIB_FMT):
    if s not in name_va:
        raw = s.encode("ascii") + b"\0"
        if cur + len(raw) > limit:
            raise SystemExit(".proxy_patch overflow writing log strings")
        b[cur:cur+len(raw)] = raw
        name_va[s] = sec_va + (cur - sec_off)
        cur += len(raw)
for s in (CALIB_WRAPPER_MSG,):
    if s not in name_va:
        raw = s.encode("ascii") + b"\0"
        if cur + len(raw) > limit:
            raise SystemExit(".proxy_patch overflow writing wrapper log strings")
        b[cur:cur+len(raw)] = raw
        name_va[s] = sec_va + (cur - sec_off)
        cur += len(raw)

cur = (cur + 0xF) & ~0xF


def emit_rel32(op3: bytes, insn_va: int, target_va: int):
    disp = target_va - (insn_va + 7)
    if not (-0x80000000 <= disp <= 0x7fffffff):
        raise SystemExit(f"disp32 out of range insn@0x{insn_va:x} -> 0x{target_va:x}")
    return op3 + struct.pack("<i", disp)


def emit_call_rel32(insn_va: int, target_va: int):
    disp = target_va - (insn_va + 5)
    if not (-0x80000000 <= disp <= 0x7fffffff):
        raise SystemExit(f"call rel32 out of range insn@0x{insn_va:x} -> 0x{target_va:x}")
    return b"\xe8" + struct.pack("<i", disp)


def make_wrapper(sig: str, host: str):
    global cur
    code_off = cur
    code_va = sec_va + (code_off - sec_off)
    insn_va = code_va
    out = bytearray()
    if host == "vkGetPhysicalDeviceCalibrateableTimeDomainsEXT":
        if CALIB_DIRECT_BRIDGE:
            # Direct ABI bridge (no WrapGuestFunctionImpl):
            # entry:
            #   rdi = host function pointer
            #   rsi = guest arg buffer
            # argbuf layout for ippp:
            #   [0x00] return slot (int32)
            #   [0x00] arg0 (VkPhysicalDevice) for input load
            #   [0x08] arg1 (uint32_t* pCount)
            #   [0x10] arg2 (VkTimeDomainEXT* pDomains)
            out += b"\x53"                  # push rbx
            insn_va += 1
            out += b"\x48\x89\xf3"          # mov rbx,rsi        ; keep argbuf
            insn_va += 3
            out += b"\x48\x89\xf8"          # mov rax,rdi        ; host fn ptr
            insn_va += 3
            out += b"\x48\x8b\x3b"          # mov rdi,[rbx+0x0]  ; arg0
            insn_va += 3
            out += b"\x48\x8b\x73\x08"      # mov rsi,[rbx+0x8]  ; arg1
            insn_va += 4
            out += b"\x48\x8b\x53\x10"      # mov rdx,[rbx+0x10] ; arg2
            insn_va += 4
            out += b"\xff\xd0"              # call rax
            insn_va += 2
            out += b"\x89\x03"              # mov [rbx],eax      ; write VkResult
            insn_va += 2
            out += b"\x5b"                  # pop rbx
            insn_va += 1
            out += b"\x31\xc0"              # xor eax,eax
            insn_va += 2
            out += b"\xc3"                  # ret
            insn_va += 1
            if code_off + len(out) > limit:
                raise SystemExit(".proxy_patch overflow writing direct calib bridge")
            b[code_off:code_off+len(out)] = out
            cur = (code_off + len(out) + 0xF) & ~0xF
            return code_va

        if CALIB_FORCE_ENABLE:
            # ABI assumption validated by ippp adapter:
            #   arg0 = [rsi+0], arg1 = [rsi+8] (uint32_t* pCount), arg2 = [rsi+0x10]
            # Force:
            #   if (pCount) *pCount = CALIB_FORCE_COUNT;
            #   *(int32_t*)(argbuf+0) = CALIB_FORCE_RESULT;
            #   return 0;
            out += b"\x48\x8b\x46\x08"      # mov rax,[rsi+0x8]
            insn_va += 4
            out += b"\x48\x85\xc0"          # test rax,rax
            insn_va += 3
            out += b"\x74\x06"              # je +6
            insn_va += 2
            out += b"\xc7\x00" + struct.pack("<I", CALIB_FORCE_COUNT & 0xffffffff)  # mov dword [rax],imm32
            insn_va += 6
            out += b"\xc7\x06" + struct.pack("<i", CALIB_FORCE_RESULT)               # mov dword [rsi],imm32
            insn_va += 6
            out += b"\x31\xc0"              # xor eax,eax
            insn_va += 2
            out += b"\xc3"                  # ret
            insn_va += 1
            if code_off + len(out) > limit:
                raise SystemExit(".proxy_patch overflow writing forced calib wrapper")
            b[code_off:code_off+len(out)] = out
            cur = (code_off + len(out) + 0xF) & ~0xF
            return code_va

        # Debug log with ABI values:
        # __android_log_print(4, "ndk_translation", "calib rdi=%p a0=%p a1=%p a2=%p",
        #                     rdi, [rsi+0], [rsi+8], [rsi+0x10])
        for op in (b"\x50", b"\x53", b"\x57", b"\x56", b"\x52", b"\x51", b"\x41\x50", b"\x41\x51"):  # save rax,rbx,rdi,rsi,rdx,rcx,r8,r9
            out += op
            insn_va += len(op)
        out += b"\x48\x89\xf3"  # mov rbx,rsi (argbuf)
        insn_va += 3
        out += b"\x49\x89\xfa"  # mov r10,rdi (wrapped fn ptr)
        insn_va += 3
        out += b"\x4c\x8b\x03"  # mov r8,[rbx+0]
        insn_va += 3
        out += b"\x4c\x8b\x4b\x08"  # mov r9,[rbx+8]
        insn_va += 4
        out += b"\x4c\x8b\x5b\x10"  # mov r11,[rbx+0x10]
        insn_va += 4
        out += b"\x48\x83\xec\x08"  # sub rsp,8 (stack vararg + align for call)
        insn_va += 4
        out += b"\x4c\x89\x1c\x24"  # mov [rsp],r11
        insn_va += 4
        out += b"\xbf\x04\x00\x00\x00"  # mov edi,4
        insn_va += 5
        out += emit_rel32(b"\x48\x8d\x35", insn_va, name_va[LOG_TAG])  # lea rsi,[rip+tag]
        insn_va += 7
        out += emit_rel32(b"\x48\x8d\x15", insn_va, name_va[CALIB_FMT])  # lea rdx,[rip+fmt]
        insn_va += 7
        out += b"\x4c\x89\xd1"  # mov rcx,r10
        insn_va += 3
        out += b"\x31\xc0"  # xor eax,eax (varargs)
        insn_va += 2
        out += emit_call_rel32(insn_va, 0x92250)  # __android_log_print@plt
        insn_va += 5
        out += b"\x48\x83\xc4\x08"  # add rsp,8
        insn_va += 4
        for op in (b"\x41\x59", b"\x41\x58", b"\x59", b"\x5a", b"\x5e", b"\x5f", b"\x5b", b"\x58"):
            out += op
            insn_va += len(op)
    # lea rsi, [rip+sig]
    out += emit_rel32(b"\x48\x8d\x35", insn_va, sig_va[sig]); insn_va += 7
    # mov rdx, [rip+NEXT_GIPA_PTR]
    out += emit_rel32(b"\x48\x8b\x15", insn_va, NEXT_GIPA_PTR); insn_va += 7
    # lea rcx, [rip+host_name]
    out += emit_rel32(b"\x48\x8d\x0d", insn_va, name_va[host]); insn_va += 7
    # jmp WrapGuestFunctionImpl@plt
    disp = WRAP_GUEST_IMPL_PLT - (insn_va + 5)
    if not (-0x80000000 <= disp <= 0x7fffffff):
        raise SystemExit("jmp rel32 out of range")
    out += b"\xe9" + struct.pack("<i", disp)

    if code_off + len(out) > limit:
        raise SystemExit(".proxy_patch overflow writing wrapper")
    b[code_off:code_off+len(out)] = out
    cur = (code_off + len(out) + 0xF) & ~0xF
    return code_va

wrapper_va = {}
for name, sig, host_name, donor in TARGETS:
    wrapper_va[name] = make_wrapper(sig, host_name)

# Add pre-search remap: old sparse name -> donor key with old-sparse-compatible wrapper.
SPARSE_OLD = "vkGetPhysicalDeviceSparseImageFormatProperties"
SPARSE_OLD_SIG = "vpiiiiipp"
for s in (SPARSE_OLD,):
    if s not in name_va:
        raw = s.encode("ascii") + b"\0"
        if cur + len(raw) > limit:
            raise SystemExit(".proxy_patch overflow writing sparse-old names")
        b[cur:cur+len(raw)] = raw
        name_va[s] = sec_va + (cur - sec_off)
        cur += len(raw)

if SPARSE_OLD_SIG not in sig_va:
    raw = SPARSE_OLD_SIG.encode("ascii") + b"\0"
    if cur + len(raw) > limit:
        raise SystemExit(".proxy_patch overflow writing sparse-old signature")
    b[cur:cur+len(raw)] = raw
    sig_va[SPARSE_OLD_SIG] = sec_va + (cur - sec_off)
    cur += len(raw)

cur = (cur + 0xF) & ~0xF

def emit_call_rel32(insn_va: int, target_va: int):
    disp = target_va - (insn_va + 5)
    if not (-0x80000000 <= disp <= 0x7fffffff):
        raise SystemExit(f"call rel32 out of range insn@0x{insn_va:x} -> 0x{target_va:x}")
    return b"\xe8" + struct.pack("<i", disp)

def emit_jmp_rel32(insn_va: int, target_va: int):
    disp = target_va - (insn_va + 5)
    if not (-0x80000000 <= disp <= 0x7fffffff):
        raise SystemExit(f"jmp rel32 out of range insn@0x{insn_va:x} -> 0x{target_va:x}")
    return b"\xe9" + struct.pack("<i", disp)

# Wrapper for vkGetPhysicalDeviceSparseImageFormatProperties (old API shape).
sparse_old_wrapper_va = make_wrapper(SPARSE_OLD_SIG, SPARSE_OLD)

# Donor key string used for sparse-old presearch remap.
if DONOR_SPARSE_OLD not in name_va:
    raw = DONOR_SPARSE_OLD.encode("ascii") + b"\0"
    if cur + len(raw) > limit:
        raise SystemExit(".proxy_patch overflow writing donor remap name")
    b[cur:cur+len(raw)] = raw
    name_va[DONOR_SPARSE_OLD] = sec_va + (cur - sec_off)
    cur += len(raw)
cur = (cur + 0xF) & ~0xF

# Cave hook body that restores overwritten instructions, remaps sparse name pre-search,
# then resumes at 0x30ece.
hook_off = cur
hook_va = sec_va + (hook_off - sec_off)
out = bytearray()
insn = hook_va

# Preserve caller-saved we clobber.
for op in (b"\x50", b"\x56", b"\x57", b"\x52", b"\x51", b"\x41\x53"):  # push rax,rsi,rdi,rdx,rcx,r11
    out += op
    insn += len(op)

# Re-emit overwritten instructions.
out += b"\x41\xbf\x23\x02\x00\x00"  # mov r15d,0x223
insn += 6
out += b"\x49\x89\xf6"              # mov r14,rsi
insn += 3

# write(2, LOG_MSG, len)
out += b"\xb8\x01\x00\x00\x00"  # mov eax,1 (sys_write)
insn += 5
out += b"\xbf\x02\x00\x00\x00"  # mov edi,2 (stderr)
insn += 5
out += emit_rel32(b"\x48\x8d\x35", insn, name_va[LOG_MSG])  # lea rsi,[rip+msg]
insn += 7
out += b"\xba" + struct.pack("<I", len(LOG_MSG))  # mov edx,len
insn += 5
out += b"\x0f\x05"                  # syscall
insn += 2

# strcmp(r13, SPARSE_OLD)
out += b"\x4c\x89\xef"              # mov rdi,r13
insn += 3
out += emit_rel32(b"\x48\x8d\x35", insn, name_va[SPARSE_OLD])  # lea rsi,[rip+old]
insn += 7
out += emit_call_rel32(insn, STRCMP_PLT)  # call strcmp@plt
insn += 5
out += b"\x85\xc0"                  # test eax,eax
insn += 2

# jne done (near)
jne_pos = len(out)
out += b"\x0f\x85\x00\x00\x00\x00"
insn += 6

# r13 = DONOR_SPARSE_OLD key (lookup will resolve to patched donor wrapper).
out += emit_rel32(b"\x4c\x8d\x2d", insn, name_va[DONOR_SPARSE_OLD])  # lea r13,[rip+donor]
insn += 7

no_remap_va = insn
rel = no_remap_va - (hook_va + jne_pos + 6)
out[jne_pos+2:jne_pos+6] = struct.pack("<i", rel)

# Restore regs and jump back into original function.
for op in (b"\x41\x5b", b"\x59", b"\x5a", b"\x5f", b"\x5e", b"\x58"):  # pop r11,rcx,rdx,rdi,rsi,rax
    out += op
    insn += len(op)
out += emit_jmp_rel32(insn, GIPA_RESUME_VA)
insn += 5

if hook_off + len(out) > limit:
    raise SystemExit(".proxy_patch overflow writing pre-search hook")
b[hook_off:hook_off+len(out)] = out
cur = (hook_off + len(out) + 0xF) & ~0xF

# Patch function entry chunk (pre-search site) to jump to cave hook.
patch_off = va_to_off(GIPA_PATCH_VA)
if patch_off is None:
    raise SystemExit(f"patch site unmapped: 0x{GIPA_PATCH_VA:x}")
cur_bytes = bytes(b[patch_off:patch_off+len(EXPECTED_PATCH_BYTES)])
if cur_bytes != EXPECTED_PATCH_BYTES:
    raise SystemExit(
        f"unexpected bytes at 0x{GIPA_PATCH_VA:x}: {cur_bytes.hex()} expected {EXPECTED_PATCH_BYTES.hex()}"
    )
j = emit_jmp_rel32(GIPA_PATCH_VA, hook_va)
b[patch_off:patch_off+9] = j + b"\x90\x90\x90\x90"

for base in TABLES:
    rows, by_name = parse_table(base)

    for name, sig, host_name, donor in TARGETS:
        if donor not in by_name:
            raise SystemExit(f"table 0x{base:x}: donor row missing: {donor}")

        # Verify donor is exactly where lower_bound points for this missing key.
        lb = lower_bound_idx(rows, name)
        donor_row = by_name[donor]
        if donor_row["idx"] != lb:
            raise SystemExit(
                f"table 0x{base:x}: donor '{donor}' idx={donor_row['idx']} != lb({name})={lb}; "
                f"found lb row='{rows[lb]['name']}'"
            )

        # Patch row in-place.
        off = donor_row["off"]
        struct.pack_into("<QQ", b, off, name_va[name], wrapper_va[name])

        # Update local mirror for next lb checks in same table.
        donor_row["name"] = name
        donor_row["np"] = name_va[name]
        donor_row["wp"] = wrapper_va[name]

    # Post-check: each key should resolve to exact row via same binary-search logic.
    rows2, _ = parse_table(base)
    for name, *_ in TARGETS:
        idx = lower_bound_idx(rows2, name)
        if idx >= len(rows2) or rows2[idx]["name"] != name:
            got = rows2[idx]["name"] if idx < len(rows2) else "<end>"
            raise SystemExit(f"table 0x{base:x}: lookup mismatch for {name}, got {got} at idx {idx}")

    # Patch donor wrapper pointer for old sparse API without renaming donor key.
    if DONOR_SPARSE_OLD not in by_name:
        raise SystemExit(f"table 0x{base:x}: sparse donor missing: {DONOR_SPARSE_OLD}")
    donor_row = by_name[DONOR_SPARSE_OLD]
    struct.pack_into("<QQ", b, donor_row["off"], donor_row["np"], sparse_old_wrapper_va)

out_path.write_bytes(bytes(b))
print(f"patched: {out_path}")
for name, sig, host_name, donor in TARGETS:
    print(f"  {name}: wrapper_va=0x{wrapper_va[name]:x}, donor={donor}, host={host_name}, sig={sig}")
print(f"  sparse_old_wrapper_va=0x{sparse_old_wrapper_va:x}, donor_key={DONOR_SPARSE_OLD}")
print(f"  presearch_hook_va=0x{hook_va:x} patched_site=0x{GIPA_PATCH_VA:x} sparse_old->{DONOR_SPARSE_OLD}")
print(f"  calib_force_enable={CALIB_FORCE_ENABLE} result={CALIB_FORCE_RESULT} count={CALIB_FORCE_COUNT}")
print(f"  calib_direct_bridge={CALIB_DIRECT_BRIDGE}")
PY

sha256sum "$OUT_SO"
