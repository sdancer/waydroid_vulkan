#!/usr/bin/env bash
set -euo pipefail

ACTION="${1:-apply}"
LIB="/var/lib/waydroid/overlay/system/lib64/libndk_translation_proxy_libvulkan.so"

need_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "Missing command: $1" >&2; exit 1; }; }
need_cmd python3
need_cmd sha256sum
need_cmd sudo

apply_patch() {
  local ts backup
  ts="$(date +%s)"
  backup="${LIB}.pre-wrapperpatch.${ts}"

  if [ ! -f "$LIB" ]; then
    echo "Missing: $LIB" >&2
    exit 1
  fi

  echo "[*] Backing up $LIB -> $backup"
  sudo cp -a "$LIB" "$backup"

  echo "[*] Applying wrapper-table patch"
  sudo python3 - <<'PY'
import struct
from pathlib import Path

lib_path = Path('/var/lib/waydroid/overlay/system/lib64/libndk_translation_proxy_libvulkan.so')
b = bytearray(lib_path.read_bytes())

TABLE_OFF = 0x96768
COUNT = 0x223
ENT_SZ = 16

def get_entry(idx):
    off = TABLE_OFF + idx * ENT_SZ
    name_ptr, wrap_ptr = struct.unpack_from('<QQ', b, off)
    end = b.find(b'\x00', name_ptr)
    if end < 0:
        raise RuntimeError(f'No NUL for idx {idx} @0x{name_ptr:x}')
    name = b[name_ptr:end].decode('ascii', errors='strict')
    return off, name_ptr, wrap_ptr, name

def set_entry(idx, *, name=None, wrap_ptr=None):
    off, name_ptr, cur_wrap, cur_name = get_entry(idx)
    if name is not None:
        if len(name) > len(cur_name):
            raise RuntimeError(f'Name too long for idx {idx}: {name} ({len(name)}) > {cur_name} ({len(cur_name)})')
        raw = name.encode('ascii') + b'\x00' + b'\x00' * (len(cur_name) - len(name))
        b[name_ptr:name_ptr + len(cur_name) + 1] = raw
    if wrap_ptr is not None:
        struct.pack_into('<Q', b, off + 8, wrap_ptr)

def wrap_of(idx):
    return get_entry(idx)[2]

# Batch 1 (existing) + Batch 2 (new)
patches = [
    (24,  'vkTransitionImageLayoutEXT',               wrap_of(22)),
    (70,  'vkCmdBindDescriptorBuffersEXT',            wrap_of(68)),
    (73,  'vkCmdBindShadersEXT',                      wrap_of(71)),
    (125, 'vkCmdDrawMeshTasksEXT',                    wrap_of(110)),
    (165, 'vkCmdSetAlphaToOneEnableEXT',              wrap_of(171)),
    (166, 'vkCmdSetColorBlendEnableEXT',              None),
    (171, 'vkCmdSetColorWriteMaskEXT',                wrap_of(166)),
    (174, 'vkCmdSetDepthClampEnableEXT',              wrap_of(171)),
    (195, 'vkCmdSetLogicOpEnableEXT',                 wrap_of(194)),
    (198, 'vkCmdSetPolygonModeEXT',                   wrap_of(168)),
    (203, 'vkCmdSetRasterizationSamplesEXT',          wrap_of(168)),
    (220, 'vkCmdTraceRaysIndirect2KHR',               wrap_of(224)),
    (239, 'vkCopyMemoryToImageEXT',                   wrap_of(241)),
    (293, 'vkCreateShadersEXT',                       wrap_of(291)),
    (341, 'vkDestroyShaderEXT',                       None),
    (378, 'vkGetDescriptorSetLayoutSizeEXT',          wrap_of(380)),
    (380, 'vkGetDescriptorEXT',                       wrap_of(380)),
    (382, 'vkGetDescriptorSetLayoutBindingOffsetEXT', wrap_of(380)),
    (416, 'vkGetImageSubresourceLayout2EXT',          wrap_of(419)),
    (417, 'vkGetImageSubresourceLayout2KHR',          wrap_of(419)),
    (512, 'vkGetShaderBinaryDataEXT',                 wrap_of(513)),
]

for idx, new_name, new_wrap in patches:
    set_entry(idx, name=new_name, wrap_ptr=new_wrap)

lib_path.write_bytes(bytes(b))

for idx, _, _ in patches:
    _, _, wp, nm = get_entry(idx)
    print(f'idx {idx}: {nm} wrapper=0x{wp:x}')
PY

  echo "[*] SHA256 after patch"
  sha256sum "$LIB"

  echo "[*] Restart Waydroid to reload library:"
  echo "    waydroid session stop && waydroid session start"
}

restore_patch() {
  local latest
  latest="$(ls -1t "${LIB}.pre-wrapperpatch."* 2>/dev/null | head -n1 || true)"
  if [ -z "$latest" ]; then
    echo "No backup found for $LIB" >&2
    exit 1
  fi

  echo "[*] Restoring $LIB from $latest"
  sudo cp -a "$latest" "$LIB"
  sha256sum "$LIB"
}

status_patch() {
  python3 - <<'PY'
import struct
from pathlib import Path
lib = Path('/var/lib/waydroid/overlay/system/lib64/libndk_translation_proxy_libvulkan.so').read_bytes()
TABLE_OFF=0x96768
ENT=16
for idx in [24,70,73,125,165,166,171,174,195,198,203,220,239,293,341,378,380,382,416,417,512]:
    np,wp=struct.unpack_from('<QQ',lib,TABLE_OFF+idx*ENT)
    end=lib.find(b'\0',np)
    nm=lib[np:end].decode('ascii','ignore')
    print(f'idx {idx}: {nm} wrapper=0x{wp:x}')
PY
  sha256sum "$LIB"
}

case "$ACTION" in
  apply) apply_patch ;;
  restore) restore_patch ;;
  status) status_patch ;;
  *)
    echo "Usage: $0 [apply|restore|status]" >&2
    exit 1
    ;;
esac
