# Translator Layer Patch Notes (Waydroid `ndk_translation`)

## Objective
Apply a universal fix at the ARM->x86 translator layer (not per-game APK patching) so UE5 ARM64 apps on Waydroid do not immediately fail on the known unsupported translated opcode path.

## Scope
- Target binary: `/var/lib/waydroid/overlay/system/lib64/libndk_translation.so`
- Target symbol: `_ZN15ndk_translation13UndefinedInsnEm`
- Strategy used: patch function entry to return instead of logging+raising `SIGILL`.

## Baseline
- Known-good pre-patch hash:
  - `309078da0ddf21969ca5e1e0fc2404bca8b91ce9796cf1eb106c1409359fc1b2  /var/lib/waydroid/overlay/system/lib64/libndk_translation.so`
- Crash signature observed before patching:
  - `ndk_translation: Undefined instruction 0x6ee1d843`
  - UE path reached Vulkan init, then died in translated ARM execution.

## How the Patch Address Was Derived
1. Locate `.text` virtual address and file offset.
```bash
readelf -W -S /var/lib/waydroid/overlay/system/lib64/libndk_translation.so | awk '$2==".text" {print $4, $5}'
# -> 00000000000c9370 0c8370
```

2. Locate symbol virtual address.
```bash
readelf -W -s /var/lib/waydroid/overlay/system/lib64/libndk_translation.so | awk '$8=="_ZN15ndk_translation13UndefinedInsnEm"{print $2,$3,$4,$8}'
# -> 0000000000207940 65 FUNC _ZN15ndk_translation13UndefinedInsnEm
```

3. Compute file offset.
- Formula: `file_off = sym_vaddr - text_vaddr + text_file_off`
- Values: `0x207940 - 0x0c9370 + 0x0c8370 = 0x206940`

## Patch Bytes
- Written at file offset `0x206940`:
  - `31 c0 c3 90 90 90`
- Assembly:
  - `xor eax, eax`
  - `ret`
  - `nop`
  - `nop`
  - `nop`

This replaces function entry behavior so it returns immediately.

## Automation Script
Created script: `/home/sdancer/wd/patch-ndk-jit-undef-ret.sh`

Capabilities:
- `apply`
  - Resolves symbol dynamically with `readelf`.
  - Computes file offset from ELF sections.
  - Creates timestamped backup.
  - Applies patch bytes.
  - Verifies with `objdump`.
- `restore`
  - Restores latest `*.pre-jitpatch.*` backup.

## Commands Used
Apply:
```bash
./patch-ndk-jit-undef-ret.sh apply
```

Restore:
```bash
./patch-ndk-jit-undef-ret.sh restore
```

Restart session after apply/restore:
```bash
waydroid session stop
waydroid session start
```

## Verification
1. Disassembly check:
```bash
objdump -d -M intel --start-address=0x207940 --stop-address=0x207970 /var/lib/waydroid/overlay/system/lib64/libndk_translation.so
```
Expected function prologue starts with:
- `31 c0`
- `c3`

2. Hash after patch (recorded):
- `7ab83708174ba1d8937dd65c9b4f2b42924ca6b5b092e4024055d500c222239d  /var/lib/waydroid/overlay/system/lib64/libndk_translation.so`

3. Runtime check method used:
- Re-run UE probe launcher and inspect `logcat` for:
  - `ndk_translation: Undefined instruction`
  - `SIGILL`

## Backups
Script-generated backup format:
- `/var/lib/waydroid/overlay/system/lib64/libndk_translation.so.pre-jitpatch.<timestamp>`

Earlier manual backups also existed during testing:
- `/var/lib/waydroid/overlay/system/lib64/libndk_translation.so.bak.*`

## Caveats
- This is a broad trap bypass for this specific undefined-handler entrypoint, not an opcode-accurate semantic implementation.
- A stricter next step is opcode-gated handling (for example only `0x6ee1d843`) or proper translation in the decode/semantics path.
- 32-bit translator library was not modified in this patch (`lib64` path only).

## Vulkan Proxy Wrapper Extension (Function-by-Function)

### Objective
Incrementally extend `vkGet*ProcAddr` coverage in:
- `/var/lib/waydroid/overlay/system/lib64/libndk_translation_proxy_libvulkan.so`

without source code, by patching the internal proc-name table and wrapper pointer table entries.

### Automation Script
Created:
- `/home/sdancer/wd/patch-proxy-vulkan-wrappers.sh`

Usage:
```bash
./patch-proxy-vulkan-wrappers.sh apply
./patch-proxy-vulkan-wrappers.sh status
./patch-proxy-vulkan-wrappers.sh restore
```

### Current Patched Entries
Applied table rewrites (incremental first batch):

- `vkCmdDrawMeshTasksIndirectCountNV` -> `vkCmdDrawMeshTasksEXT` (wrapper redirected to `vkCmdDispatch` wrapper signature)
- `vkCmdSetColorWriteEnableEXT` -> `vkCmdSetColorBlendEnableEXT` (wrapper kept)
- `vkCmdSetDepthBoundsTestEnableEXT` -> `vkCmdSetDepthClampEnableEXT` (wrapper redirected to `vkCmdSetDepthBiasEnableEXT` wrapper signature)
- `vkCmdSetPerformanceStreamMarkerINTEL` -> `vkCmdSetPolygonModeEXT` (wrapper redirected to `vkCmdSetCullModeEXT` wrapper signature)
- `vkCmdSetRasterizerDiscardEnable` -> `vkCmdSetRasterizationSamplesEXT` (wrapper redirected to `vkCmdSetCullModeEXT` wrapper signature)
- `vkDestroyShaderModule` -> `vkDestroyShaderEXT` (wrapper kept)

### Integrity / Backup
- Backup format:
  - `/var/lib/waydroid/overlay/system/lib64/libndk_translation_proxy_libvulkan.so.pre-wrapperpatch.<timestamp>`
- Example patched hash:
  - `33a86c007e2f5751794f8542a0e02e5393df65510210683e5417b1515f98cdf7`

### Notes
- This is a binary patch path, not a source rebuild.
- It is intended for iterative extension ("function-by-function"), with runtime validation after each batch.
