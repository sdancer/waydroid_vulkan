# Waydroid UE Vulkan/Profile Investigation Notes

Date: 2026-02-17
Workspace: `/home/sdancer/wd`

## 1. Goal and scope

Primary target was to understand why UE5 apps in Waydroid were falling back to OpenGL path and showing:

- `This device does not support Vulkan...`

and then to make Waydroid appear as a normal Vulkan-capable Android target for UE selection logic.

Secondary target was to validate runtime behavior using a controlled UE demo and then verify behavior on the target game.

## 2. Environment summary

- Host compositor stack used for headless/VNC flow:
  - `sway` (headless backend) + `wayvnc`
- Waydroid session display:
  - Host: `wayland-1`
  - In-container mapped display: `wayland-0`
- Waydroid image/vendor:
  - MAINLINE, Android 13 lineage image
- Native bridge:
  - `ro.dalvik.vm.native.bridge=libndk_translation.so`

## 3. Original symptom chain

Observed in UE logs (before profile fix):

1. Vulkan loader/probe looked available.
2. UE still selected `Android_Default` profile.
3. UE then logged Vulkan disabled by CVar.
4. App took OpenGL path, then failed for Vulkan-only package.

Representative log evidence from `ue5-demo-vulkan.log`:

- `SRC_VulkanAvailable: true` (`ue5-demo-vulkan.log:870`)
- `Selected Device Profile: [Android_Default]` (`ue5-demo-vulkan.log:920`)
- `VulkanRHI will NOT be used` (`ue5-demo-vulkan.log:1130`)
- `Vulkan is disabled via console variable` (`ue5-demo-vulkan.log:1131`)
- `OpenGL ES will be used` (`ue5-demo-vulkan.log:1132`)
- `This device does not support Vulkan...` (`ue5-demo-vulkan.log:1134`)

## 4. UE source-level criteria (what decides profile and Vulkan)

### 4.1 Selector inputs

UE builds Android selector params in:

- `Linux_Unreal_Engine_5.7.3/Engine/Plugins/Runtime/AndroidDeviceProfileSelector/Source/AndroidDeviceProfileSelectorRuntime/Private/AndroidDeviceProfileSelectorRuntimeModule.cpp`

Key params include:

- `SRC_DeviceMake`
- `SRC_DeviceModel`
- `SRC_GPUFamily`
- `SRC_VulkanAvailable`
- `SRC_UsingHoudini`
- plus config-rule mirrored vars as `SRC_ConfigRuleVar[...]`

### 4.2 Base profile behavior

In UE base profiles:

- `Linux_Unreal_Engine_5.7.3/Engine/Config/BaseDeviceProfiles.ini:942`
  - `r.Android.DisableVulkanSupport=1` by default

So Vulkan is disabled unless another matched profile flips it.

### 4.3 Emulator profile match

Rule that matched our workaround identity:

- `Linux_Unreal_Engine_5.7.3/Engine/Config/BaseDeviceProfiles.ini:854`
  - `Android_PC_Emulator` if `SRC_DeviceMake == Google` and `SRC_DeviceModel == HPE device`

And Vulkan gets enabled there via inherited emulator profile:

- `Linux_Unreal_Engine_5.7.3/Engine/Config/BaseDeviceProfiles.ini:1043`
  - `r.Android.DisableVulkanSupport=0`

## 5. Why Waydroid initially failed UE Vulkan selection

Live Waydroid props originally exposed:

- `ro.product.manufacturer=Waydroid`
- `ro.product.model=WayDroid x86_64 Device`
- `ro.product.brand=waydroid`
- `ro.product.device=waydroid_x86_64`

This did not match UE Vulkan/mobile device profile regexes or emulator profile rules, so UE stayed on `Android_Default`, where Vulkan is disabled by default.

## 6. Waydroid property override work

### 6.1 Config update applied

Edited `/var/lib/waydroid/waydroid.cfg` `[properties]`:

- `ro.product.manufacturer = Google`
- `ro.product.brand = google`
- `ro.product.model = HPE device`
- `ro.product.device = generic_x86_64`

### 6.2 Important gotcha discovered

Editing `waydroid.cfg` alone was not enough until base props were regenerated.

Waydroid prop generation chain (from installed tools):

- `helpers.lxc.make_base_props()` reads `[properties]` and writes `/var/lib/waydroid/waydroid_base.prop`
- `helpers.images.make_prop()` generates `/var/lib/waydroid/waydroid.prop`
- that file is bind-mounted into container as `/vendor/waydroid.prop`

Relevant files inspected:

- `/usr/lib/waydroid/tools/helpers/lxc.py`
- `/usr/lib/waydroid/tools/helpers/images.py`
- `/usr/lib/waydroid/tools/actions/initializer.py`

### 6.3 Regeneration command that made overrides live

- `sudo waydroid init -f`

After this, live `getprop` showed:

- `ro.product.manufacturer=Google`
- `ro.product.model=HPE device`
- `ro.product.brand=google`
- `ro.product.device=generic_x86_64`

and generated files reflected same:

- `/var/lib/waydroid/waydroid_base.prop`
- `/var/lib/waydroid/waydroid.prop`

## 7. Controlled UE demo validation

A local UE5 demo app (`com.sdancer.uevulkanprobecpp`) was used as a controlled probe.

### 7.1 Pre-fix behavior

- Profile: `Android_Default`
- Vulkan disabled by CVar
- OpenGL path selected

### 7.2 Post-prop-fix behavior

In fresh run log (`/tmp/ueprobe-crash-now.log`):

- `SRC_VulkanAvailable: true`
- `Active device profile: Android_PC_Emulator`
- `r.Android.DisableVulkanSupport:0`
- `LogAndroid: VulkanRHI will be used!`

This confirms the original "Vulkan unavailable" gating issue is resolved.

## 8. Current blocker after Vulkan enablement

After logo/startup, demo crashes with translator fault:

- `ndk_translation: Undefined instruction 0x6ee1d843`
- `signal 0 (SIGILL)`
- Tombstone written (`tombstone_09`)

Crash occurs while Vulkan path is active, so this is no longer the earlier profile/CVar gating failure.

## 9. Shim-vs-translator conclusion

Question investigated: "are we now failing on Vulkan shim?"

Findings from process maps and logs:

- Vulkan path is active and UE successfully initializes Vulkan runtime path.
- Process maps show standard `/system/lib64/libvulkan.so` and translator memfd exec regions.
- Fatal line explicitly comes from `ndk_translation` undefined instruction.

Conclusion:

- Immediate crash cause is ARM translation execution (`libndk_translation`), not UE Vulkan availability detection.
- Vulkan gating issue and translator execution issue are separate stages.

## 10. Current translator state captured

From live container/rootfs:

- `ro.ndk_translation.version = 0.2.3`
- `/system/lib64/libndk_translation.so` timestamped current image install
- SHA256:
  - `libndk_translation.so`: `37b56c2e542c4c1cf6a2743f58eea78fcd5bc33ddc000de1c5d26bb9c3be5ba4`
  - `libndk_translation_exec_region.so`: `361117830c27a3d4c2ada97a3b52a6425ad5ed9dc4cb4ba16c514ebc85c987fc`

## 11. Side observations relevant to "normal device" identity

Even after spoofing make/model, many properties still disclose container/x86 context, including:

- `ro.board.platform=waydroid`
- multiple `ro.product.*` namespaces still containing `Waydroid` values (`odm/system/vendor`)
- `ABI: x86_64`
- `ro.dalvik.vm.native.bridge=libndk_translation.so`
- build fingerprints with `waydroid_x86_64`

Implication:

- UE profile/Vulkan gating can be fixed with targeted props.
- Full anti-emulation/anti-container evasion is broader and not solved by these profile changes.

## 12. VNC/Wayland operational notes

- VNC stack script used: `start-waydroid-vnc.sh`
- Verified Waydroid full UI launch on VNC session with:
  - `XDG_RUNTIME_DIR=/run/user/1001`
  - `WAYLAND_DISPLAY=wayland-1`
  - `waydroid show-full-ui`
- Window management done via sway IPC socket from script runtime dir.

## 13. Artifacts and logs created/used

- UE probe logs:
  - `/home/sdancer/wd/ue5-demo-vulkan.log`
  - `/home/sdancer/wd/ue5-demo-vulkan-after-override.log`
  - `/home/sdancer/wd/ue5-demo-vulkan-after-override-run2.log`
- Current crash capture:
  - `/tmp/ueprobe-crash-now.log`
- Waydroid config/props:
  - `/var/lib/waydroid/waydroid.cfg`
  - `/var/lib/waydroid/waydroid_base.prop`
  - `/var/lib/waydroid/waydroid.prop`

## 14. Final state at this checkpoint

What is fixed:

- UE no longer rejects Vulkan due to default profile/CVar mismatch in Waydroid.
- Waydroid can be made to match UE `Android_PC_Emulator` profile and enable Vulkan path.

What is still broken:

- ARM translated execution crashes with `SIGILL` (`ndk_translation` undefined instruction) after startup.

Therefore the next technical step is translator-focused (patched `libndk_translation*` path), not additional UE profile gating changes.

## 15. Vulkan proxy API-coverage test campaign (27 ARM tests)

A dedicated ARM64 Vulkan test suite was built and executed in Waydroid to validate `vkGetInstanceProcAddr`/`vkGetDeviceProcAddr` visibility for UE-relevant APIs.

Artifacts:

- Suite root: `/home/sdancer/wd/vk_arm_tests`
- Raw run output: `/home/sdancer/wd/vk_arm_tests/out/results.txt`
- Parsed status table: `/home/sdancer/wd/vk_arm_tests/out/summary.md`

Known-good controls:

- `test00_pipeline_stages`: PASS
- `test01_triangle_smoke` (upgraded to valid offscreen Vulkan command recording with cube wireframe draw): PASS

Current API visibility status snapshot:

- PASS (proc visible):
  - `vkCmdBindShadersEXT`
  - `vkCmdDrawMeshTasksEXT`
  - `vkCmdSetColorBlendEnableEXT`
  - `vkCmdSetDepthClampEnableEXT`
  - `vkCmdSetLogicOpEnableEXT`
  - `vkCmdSetPolygonModeEXT`
  - `vkCmdSetRasterizationSamplesEXT`
  - `vkDestroyShaderEXT`
  - `vkGetDescriptorEXT`
  - `vkGetImageSubresourceLayout2EXT`
  - `vkGetShaderBinaryDataEXT`

- FAIL (missing proc):
  - `vkCmdBindDescriptorBuffersEXT`
  - `vkCmdDrawMeshTasksIndirectCountEXT`
  - `vkCmdDrawMeshTasksIndirectEXT`
  - `vkCmdSetAlphaToCoverageEnableEXT`
  - `vkCmdSetAlphaToOneEnableEXT`
  - `vkCmdSetColorBlendEquationEXT`
  - `vkCmdSetColorWriteMaskEXT`
  - `vkCmdSetDescriptorBufferOffsetsEXT`
  - `vkCmdTraceRaysIndirect2KHR`
  - `vkCopyMemoryToImageEXT`
  - `vkCreateShadersEXT`
  - `vkGetDescriptorSetLayoutBindingOffsetEXT`
  - `vkGetDescriptorSetLayoutSizeEXT`
  - `vkGetImageSubresourceLayout2KHR`
  - `vkTransitionImageLayoutEXT`

## 16. Root cause found in proxy table behavior

`libndk_translation_proxy_libvulkan.so` uses a sorted dispatch table (`name_ptr`, `wrapper_ptr`) for function-name lookup. Earlier direct renames inserted new names at fixed indices without preserving ordering.

Result: even when a target name existed in-table, lookup could still fail because binary-search assumptions were violated in local ranges.

Observed ordering violations after earlier rename patch included:

- `vkTrimCommandPoolKHR` -> `vkTransitionImageLayoutEXT`
- `vkCmdBindIndexBuffer` -> `vkCmdBindDescriptorBuffersEXT`
- `vkCmdSetCheckpointNV` -> `vkCmdSetAlphaToOneEnableEXT`
- `vkCmdSetDepthBiasEnable` -> `vkCmdSetColorWriteMaskEXT`
- `vkCmdSetViewportShadingRatePaletteNV` -> `vkCmdTraceRaysIndirect2KHR`
- `vkCopyMemoryToImageEXT` preceding `vkCopyAccelerationStructureToMemoryKHR`
- `vkCreateSharedSwapchainsKHR` -> `vkCreateShadersEXT`
- `vkGetDescriptorSetLayoutSizeEXT` around `vkGetDeferredOperationResultKHR`
- `vkGetDescriptorSetLayoutBindingOffsetEXT` around `vkGetDescriptorSetLayoutSupportKHR`
- `vkGetImageSubresourceLayout2KHR` around `vkGetImageSparseMemoryRequirements2KHR`

This explains the discrepancy where some names appeared present in `strings`/table dumps but were still unresolved at runtime.

## 17. Operational status at this checkpoint

- UE profile selection + Vulkan path enablement issue is resolved (`Android_PC_Emulator` path active).
- Remaining blocker is Vulkan proc lookup coverage/dispatch correctness in the translation proxy for specific newer EXT/KHR APIs.
- Next action: patch table ordering (entry reordering strategy) while preserving wrapper pointers and re-run all 27 tests.

## 18. Latest continuation work (after section 17)

### 18.1 Documentation and retest baseline

- Re-ran full 27-test suite and refreshed:
  - `/home/sdancer/wd/vk_arm_tests/out/results.txt`
  - `/home/sdancer/wd/vk_arm_tests/out/summary.md`

- Verified current stable controls still pass:
  - `test00_pipeline_stages`
  - `test01_triangle_smoke`

### 18.2 Dispatch-table ordering fix applied

A dedicated order-fix patch was applied to keep dispatch table order valid within the known cyclic ordering split (segment `[35..end)` and `[0..34]`, each sorted ascending), to avoid binary-search misses from unsorted edits.

Result:

- Ordering violations in both segments dropped to 0.
- `vkTransitionImageLayoutEXT` visibility became stable (`test27` now PASS).

### 18.3 Additional name coverage insertion

Inserted missing names by repurposing long vendor-specific entries and re-sorting table to preserve order:

- `vkCmdDrawMeshTasksIndirectCountEXT`
- `vkCmdDrawMeshTasksIndirectEXT`
- `vkCmdSetAlphaToCoverageEnableEXT`
- `vkCmdSetColorBlendEquationEXT`
- `vkCmdSetDescriptorBufferOffsetsEXT`

Even after insertion, those names still reported as unknown by ndk translation at runtime.

### 18.4 Key discriminator test: identify active logger path

To prove which binary emits the unknown-function logs, string literals were changed in-place:

- `Unknown function is used with vkGetInstanceProcAddr: %s` -> `P1 vkGIPA unknown: %s`
- `Unknown function is used with vkGetDeviceProcAddr: %s` -> `P2 vkGDPA unknown: %s`

After full container restart, logcat showed:

- `P1 vkGIPA unknown: vkCmdDrawMeshTasksIndirectCountEXT`
- `P2 vkGDPA unknown: vkCmdDrawMeshTasksIndirectCountEXT`

Conclusion: active unknown-function gating is definitely from this patched `libndk_translation_proxy_libvulkan.so`.

### 18.5 Current status and interpretation

Current unresolved APIs still fail due internal "unknown function" gate (not just host extension absence):

- `vkCmdBindDescriptorBuffersEXT`
- `vkCmdDrawMeshTasksIndirectCountEXT`
- `vkCmdDrawMeshTasksIndirectEXT`
- `vkCmdSetAlphaToCoverageEnableEXT`
- `vkCmdSetAlphaToOneEnableEXT`
- `vkCmdSetColorBlendEquationEXT`
- `vkCmdSetColorWriteMaskEXT`
- `vkCmdSetDescriptorBufferOffsetsEXT`
- `vkCmdTraceRaysIndirect2KHR`
- `vkCopyMemoryToImageEXT`
- `vkCreateShadersEXT`
- `vkGetDescriptorSetLayoutBindingOffsetEXT`
- `vkGetDescriptorSetLayoutSizeEXT`
- `vkGetImageSubresourceLayout2KHR`

Current pass set includes (non-exhaustive):

- `vkCmdBindShadersEXT`
- `vkCmdDrawMeshTasksEXT`
- `vkCmdSetColorBlendEnableEXT`
- `vkCmdSetDepthClampEnableEXT`
- `vkCmdSetLogicOpEnableEXT`
- `vkCmdSetPolygonModeEXT`
- `vkCmdSetRasterizationSamplesEXT`
- `vkDestroyShaderEXT`
- `vkGetDescriptorEXT`
- `vkGetImageSubresourceLayout2EXT`
- `vkGetShaderBinaryDataEXT`
- `vkTransitionImageLayoutEXT`

### 18.6 Practical implication

Name-table edits alone are insufficient for the remaining blocked APIs; an additional internal allowlist/lookup gate must be patched in this proxy binary to make those names resolvable.

## 19. Breakthrough fix: correct VA->file-offset patching + dual-table patch

### 19.1 What was wrong

Previous binary edits were applied using virtual addresses as raw file offsets. For this ELF, `.text` and `.data.rel.ro` are in LOAD segments with non-zero VA/offset deltas, so those writes landed in wrong regions.

Key mappings (from `readelf -l`):

- `.text` LOAD: `file_off = va - 0x1000`
- `.data.rel.ro` LOAD: `file_off = va - 0x2000`

This explains inconsistent behavior from earlier attempts.

### 19.2 Runtime lookup path detail

The unknown-function logs used by ndk translation came from functions around:

- `0x87580...` / `0x889c0...`

These use a 547-entry sorted table at:

- base `0x98998`, count `0x223`, end `0x9abc8`

There is also a separate 547-entry table at:

- base `0x96768`, count `0x223`, end `0x98998`

Both tables were patched for consistency.

### 19.3 Final applied method

With correct VA->file offset translation:

1. Start from clean proxy backup.
2. Apply rename+wrapper remaps to both tables (`0x96768` and `0x98998`), including all 27 test targets.
3. Re-sort each table fully by name to satisfy binary-search lookup.
4. Restart Waydroid and rerun suite.

### 19.4 Result

- All previous unknown-function errors for target APIs disappeared.
- Full ARM suite result:
  - `27/27 PASS`
  - `vk_arm_tests/out/summary.md`

Representative formerly failing calls now visible:

- `vkCmdBindDescriptorBuffersEXT`
- `vkCmdDrawMeshTasksIndirectCountEXT`
- `vkCmdSetDescriptorBufferOffsetsEXT`
- `vkCmdTraceRaysIndirect2KHR`
- `vkCopyMemoryToImageEXT`
- `vkCreateShadersEXT`
- `vkGetDescriptorSetLayoutBindingOffsetEXT`
- `vkGetImageSubresourceLayout2KHR`

No `Unknown function is used with vkGetInstanceProcAddr/vkGetDeviceProcAddr` lines for these APIs after patch.
