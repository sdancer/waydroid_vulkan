#!/usr/bin/env python3
import argparse
import hashlib
import os
import re
import shutil
import subprocess
from pathlib import Path

EXPECTED_ORIG_SHA256 = "e7c01f4c55eb814e3f7858457fc0f2e20c8eef343d043dc86ffb4bd4ba0151fd"

SYSTEM_LIB = Path("/var/lib/waydroid/overlay/system/lib64/libndk_translation.so")
ORIG_LIB = Path.cwd() / "libndk_translation.original.so"
PATCHED_LIB = Path.cwd() / "libndk_translation.patched.so"

NOEXEC_CALL_VADDR = int(os.environ.get("NOEXEC_CALL_VADDR", "0x210cec"), 0)
NOEXEC_PATCH_HEX = os.environ.get("NOEXEC_PATCH_HEX", "9090909090")
ALLOW_ORIG_HASH_MISMATCH = os.environ.get("ALLOW_ORIG_HASH_MISMATCH", "0") == "1"


def run(cmd, check=True, capture=False):
    if capture:
        return subprocess.run(cmd, check=check, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT).stdout
    return subprocess.run(cmd, check=check)


def need_cmd(cmd):
    if shutil.which(cmd) is None:
        raise SystemExit(f"Missing command: {cmd}")


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def verify_orig_hash(path: Path):
    if not path.exists():
        raise SystemExit(f"Original not found: {path}")
    got = sha256(path)
    print(f"[*] original sha256: {got}")
    print(f"[*] expected sha256: {EXPECTED_ORIG_SHA256}")
    if got != EXPECTED_ORIG_SHA256 and not ALLOW_ORIG_HASH_MISMATCH:
        raise SystemExit("ERROR: original hash mismatch (set ALLOW_ORIG_HASH_MISMATCH=1 to override)")


def parse_text_addr_off(lib: Path):
    out = run(["readelf", "-W", "-S", str(lib)], capture=True)
    for line in out.splitlines():
        if re.search(r"\]\s+\.text\s+", line):
            toks = line.split()
            # [Nr] Name Type Address Off Size ...
            return int(toks[3], 16), int(toks[4], 16)
    raise SystemExit("Failed to locate .text section")


def patch_offset(lib: Path):
    text_addr, text_off = parse_text_addr_off(lib)
    return NOEXEC_CALL_VADDR - text_addr + text_off


def sync_original():
    print("[*] Syncing pristine original from system -> workspace")
    run(["sudo", "cp", "-a", str(SYSTEM_LIB), str(ORIG_LIB)])
    run(["sudo", "chown", f"{os.getuid()}:{os.getgid()}", str(ORIG_LIB)])
    print(f"{sha256(ORIG_LIB)}  {ORIG_LIB}")
    verify_orig_hash(ORIG_LIB)


def build_patched():
    verify_orig_hash(ORIG_LIB)
    shutil.copy2(ORIG_LIB, PATCHED_LIB)
    off = patch_offset(PATCHED_LIB)
    patch = bytes.fromhex(NOEXEC_PATCH_HEX)
    b = bytearray(PATCHED_LIB.read_bytes())
    end = off + len(patch)
    if off < 0 or end > len(b):
        raise SystemExit(f"patch offset out of range: off={off} size={len(patch)}")
    b[off:end] = patch
    PATCHED_LIB.write_bytes(bytes(b))
    print(f"[*] Applied patch at vaddr=0x{NOEXEC_CALL_VADDR:x} file_off=0x{off:x}")
    print(f"[*] bytes@patch: {PATCHED_LIB.read_bytes()[off:end].hex()}")
    print(f"{sha256(PATCHED_LIB)}  {PATCHED_LIB}")


def install_patched():
    if not PATCHED_LIB.exists():
        raise SystemExit(f"Patched output not found: {PATCHED_LIB}")
    print("[*] Installing patched lib to Waydroid overlay")
    run(["sudo", "cp", "-a", str(PATCHED_LIB), str(SYSTEM_LIB)])
    print(f"{sha256(SYSTEM_LIB)}  {SYSTEM_LIB}")


def show_status():
    print(f"[*] Expected original SHA256: {EXPECTED_ORIG_SHA256}")
    print(f"[*] Original: {ORIG_LIB}")
    if ORIG_LIB.exists():
        print(f"{sha256(ORIG_LIB)}  {ORIG_LIB}")
    else:
        print("missing")
    print(f"[*] Patched:  {PATCHED_LIB}")
    if PATCHED_LIB.exists():
        print(f"{sha256(PATCHED_LIB)}  {PATCHED_LIB}")
        off = patch_offset(PATCHED_LIB)
        b = PATCHED_LIB.read_bytes()
        sl = b[off:off + len(bytes.fromhex(NOEXEC_PATCH_HEX))]
        print(f"[*] bytes@patch: {sl.hex()}")
    else:
        print("missing")


def main():
    for c in ("readelf", "sudo"):
        need_cmd(c)

    p = argparse.ArgumentParser(usage="%(prog)s [sync-original|build|install|status]")
    p.add_argument("action", choices=["sync-original", "build", "install", "status"], nargs="?", default="build")
    args = p.parse_args()

    if args.action == "sync-original":
        sync_original()
    elif args.action == "build":
        build_patched()
    elif args.action == "install":
        install_patched()
    else:
        show_status()


if __name__ == "__main__":
    main()
