# Trampoline Register Mapping (Waydroid Vulkan Proxy)

Target binary:
- `/home/sdancer/wd/libndk_translation_proxy_libvulkan.original.so`

## 1) Wrapper -> `WrapGuestFunctionImpl` register contract

From wrapper stubs (`0x69fb0`, `0x69fd0`, `0x6a030`, `0x6a050`):

- `rdi`: preserved from caller (first arg to `WrapGuestFunctionImpl`)
- `rsi`: signature token pointer (e.g. `vppp`, `vpiiiiipp`, `vpppp`)
- `rdx`: host thunk pointer (either cached via `[rip+...]` or direct `lea`)
- `rcx`: API descriptor/name pointer used by wrapper infra
- tail jump to `WrapGuestFunctionImpl@plt` (`0x921e0`)

This matches symbol type:
- `WrapGuestFunctionImpl(unsigned long, const char*, void(*)(unsigned long, GuestArgumentBuffer*), const char*)`

## 2) Sparse-old shape and required signature

Desired API:
- `vkGetPhysicalDeviceSparseImageFormatProperties`
- Vulkan C prototype:
  - `void (VkPhysicalDevice, VkFormat, VkImageType, VkSampleCountFlagBits, VkImageUsageFlags, VkImageTiling, uint32_t*, VkSparseImageFormatProperties*)`

Required proxy signature token:
- `vpiiiiipp` (found at `0xb88d`)

Token decode (left-to-right args):
1. `p` -> `VkPhysicalDevice` (pointer)
2. `i` -> `VkFormat` (u32)
3. `i` -> `VkImageType` (u32)
4. `i` -> `VkSampleCountFlagBits` (u32)
5. `i` -> `VkImageUsageFlags` (u32)
6. `i` -> `VkImageTiling` (u32)
7. `p` -> `uint32_t* pPropertyCount`
8. `p` -> `VkSparseImageFormatProperties* pProperties`

## 3) Guest AArch64 call register mapping (for this API)

At guest call site (AAPCS64):
- `x0`: `VkPhysicalDevice`
- `w1`: `VkFormat`
- `w2`: `VkImageType`
- `w3`: `VkSampleCountFlagBits`
- `w4`: `VkImageUsageFlags`
- `w5`: `VkImageTiling`
- `x6`: `uint32_t*`
- `x7`: `VkSparseImageFormatProperties*`

If building a direct guest trampoline, preserve this exact order.

## 4) Reference stubs used to derive mapping

- `0x69fb0` (`vppp`, cached `rdx=[rip+0x30e99] -> 0x9ae50`)
- `0x69fd0` (`vppp`, direct `rdx=lea 0x8b3b0`)
- `0x6a030` (`vpiiiiipp`, cached `rdx=[rip+0x30e19] -> 0x9ae50`)
- `0x6a050` (`vpppp`, direct `rdx=lea 0x8b7b0`)

So for sparse-old trampoline implementation, the correct wrapper-side register setup is:

```asm
; wrapper for vkGetPhysicalDeviceSparseImageFormatProperties
; rdi untouched
lea  rsi, [rip + sig_vpiiiiipp]   ; "vpiiiiipp"
lea/mov rdx, [host_thunk_ptr]     ; custom thunk or cached slot
lea  rcx, [rip + name_ptr]        ; exact sparse-old API descriptor/name
jmp  WrapGuestFunctionImpl@plt
```

## 5) Practical implication

Do not alias sparse-old to sparse2 wrapper (`vpppp`), because ABI shape differs and causes marshalling mismatch.

Sparse-old needs either:
- a proper thunk bound to `vpiiiiipp`, or
- an adapter thunk that reads old-ABI args and translates to sparse2 semantics safely.
