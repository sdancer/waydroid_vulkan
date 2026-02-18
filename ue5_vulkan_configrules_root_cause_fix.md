# UE5 Waydroid Vulkan Init Root Cause + PoC + Fix

## Root cause

`GameActivity` computes ConfigRules variables on `ProcessSystemInfoThread` before Vulkan feature probing is completed in `onCreateBody()`.

In stock template:

- `VulkanVersionString` starts as `"0.0.0"`
- `processSystemInfo()` emits:
  - `SRC_VulkanVersion = VulkanVersionString`
  - `SRC_VulkanAvailable = (bSupportsVulkan && VulkanVersionString != "0.0.0") ? "true" : "false"`
- `runConfigRules()` runs immediately after this on the same thread.
- Later, `onCreateBody()` updates Vulkan fields (`Vulkan version: 1.1.0` in logs).

So ConfigRules can evaluate with stale Vulkan values (`false/0.0.0`) even when device Vulkan is available.

There is also a Java bug in the expression above: `VulkanVersionString != "0.0.0"` is reference comparison, not value comparison.

## On-device PoC that fails the same way

Script:

- `poc_configrules_vulkan_mismatch.sh`

What it does:

1. Patches app `configrules.cache` to force a bad state (`SRC_VulkanAvailable=false`, `SRC_VulkanVersion=0.0.0`).
2. Launches app and captures logcat (`fail` phase).
3. Patches cache to a good state (`true`, `1.1.311`).
4. Launches app and captures logcat (`fix` phase).

Result (both phases):

- `$$$ configrules: run config rules`
- later `Vulkan version: 1.1.0`
- still `SRC_ConfigRuleVar[SRC_VulkanAvailable]: false`
- still `SRC_ConfigRuleVar[SRC_VulkanVersion]: 0.0.0`

This shows cache patching alone is not a durable fix because runtime ordering regenerates stale values.

Logs:

- `poc_out/fail_summary.txt`
- `poc_out/fix_summary.txt`

## Minimal code-level PoC

File:

- `ue_vulkan_configrules_race_poc.java`

Run:

```bash
javac ue_vulkan_configrules_race_poc.java && java ue_vulkan_configrules_race_poc
```

Output demonstrates:

- broken flow: `SRC_VulkanAvailable=false` while Vulkan becomes `1.1.0` later
- fixed flow: `SRC_VulkanAvailable=true`

## Fix applied in UE source template

File patched:

- `Linux_Unreal_Engine_5.7.3/Engine/Build/Android/Java/src/com/epicgames/unreal/GameActivity.java.template`

Changes:

1. Added helper:
   - `refreshVulkanInfoFromSystemFeatures()`
2. Called helper before assembling ConfigRules variables in `processSystemInfo()`.
3. Fixed string comparison:
   - from `VulkanVersionString != "0.0.0"`
   - to `!VulkanVersionString.equals("0.0.0")`
4. Replaced duplicate Vulkan probing block in `onCreateBody()` with helper call.

## Why this fixes UE5 Vulkan selection

It aligns `SRC_ConfigRuleVar[SRC_VulkanAvailable]` / `SRC_ConfigRuleVar[SRC_VulkanVersion]` with actual device Vulkan capability at ConfigRules evaluation time, preventing false GLES fallback decisions such as `GLESBecauseNoDeviceMatch` on Vulkan-capable Waydroid setups.
