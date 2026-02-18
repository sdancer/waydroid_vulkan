# Sparse-Old Arg Buffer Mapping (Waydroid Vulkan Proxy)

Date: 2026-02-18
Target: `/var/lib/waydroid/overlay/system/lib64/libndk_translation_proxy_libvulkan.so`

## Summary

`vkGetPhysicalDeviceSparseImageFormatProperties` is not invoked with plain SysV C args in the proxy thunk path.

Observed call ABI at proxy thunk entry is:
- `rdi` = context/dispatch value (observed equal to function pointer in probe runs)
- `rsi` = pointer to packed argument buffer

So this call path is thunk-style (`ctx`, `GuestArgumentBuffer*`), not direct C prototype args.

## Captured Probe Output

From `test38_sparse_api_check` with live syscall probe:

`[RXSPARSE_PTR] ctx,argbuf,qwords: 00007600f855fef0 00007603c9c99050 00007603c0d01b08 00007603c0d01b38 00007602abc087a0 0000000000000025 0000000000000001 0000000000000001 0000000000000004 0000000000000000 000076010a1ff9ac 0000000000000000 ...`

Interpreting qwords at `argbuf`:
- `+0x10` -> `VkPhysicalDevice` pointer
- `+0x18` -> `VkFormat` (u32)
- `+0x20` -> `VkImageType` (u32)
- `+0x28` -> `VkSampleCountFlagBits` (u32)
- `+0x30` -> `VkImageUsageFlags` (u32)
- `+0x38` -> `VkImageTiling` (u32)
- `+0x40` -> `uint32_t* pPropertyCount`
- `+0x48` -> `VkSparseImageFormatProperties* pProperties`

So old-sparse args are packed in `rsi` buffer, not directly in call registers.

## Practical consequence

A correct sparse-old shim must read/write arguments via `argbuf` offsets above.
Directly treating the hook as `void(*)(VkPhysicalDevice, ...)` produces wrong argument mapping and instability.
