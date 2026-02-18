# Vulkan Proxy Wrapper Assembly Notes

Target:
- `/var/lib/waydroid/overlay/system/lib64/libndk_translation_proxy_libvulkan.so`

## 1) Wrapper stub shape

Most proxy wrappers are tiny x86_64 stubs that set 3 args then jump to:
- `WrapGuestFunctionImpl@plt` at `0x921e0`

Template (seen repeatedly around `0x699b0..0x6a030`):

```asm
; optional: mov rdx, [rip+...]
; optional: mov rsi, [rip+...]
lea/mov rsi, <signature_or_name_ptr>
lea/mov rdx, <host_impl_ptr>
lea     rcx, <helper_descriptor_ptr>
jmp     0x921e0   ; WrapGuestFunctionImpl@plt
```

Padding between stubs is typically `int3` bytes.

## 2) Important registers for stub -> WrapGuestFunctionImpl

From live disassembly, each stub prepares:
- `rsi`: wrapper signature/name blob pointer
- `rdx`: host-side callable entry (or pointer loaded from data)
- `rcx`: helper descriptor pointer
- tail-jump to `WrapGuestFunctionImpl`

The caller path (`vkGetInstanceProcAddr` table lookup block near `0x889c0`) later executes the wrapper pointer from table entry `+8`.

## 3) Relevant block for vkGetPhysicalDevice* wrappers

The `vkGetPhysicalDevice*` wrappers cluster near:
- `0x69f30` .. `0x6a130`

Examples:
- `0x69fb0` (used for `vkGetPhysicalDeviceQueueFamilyProperties`)
- `0x69fd0` (`...QueueFamilyProperties2`)
- `0x69ff0` (`...QueueFamilyProperties2KHR`)
- `0x6a0b0` (`...SurfaceCapabilities2EXT`)

These are all stub-style entries (not full implementations), i.e. they rely on translator helper signatures.

## 4) VA vs file offset rule (critical)

For this binary, `.text` is mapped with:
- `VA = file_offset + 0x1000`

So patching VA `0x69fb0` means file offset `0x68fb0`.

This must be respected for all manual byte patches.

## 5) How to add a custom assembly wrapper safely

1. Pick/allocate code space (code cave or replace an unused wrapper slot).
2. Write a stub that sets:
   - `rsi` to a valid signature/name record
   - `rdx` to your host thunk or safe fallback thunk
   - `rcx` to compatible helper descriptor
   - `jmp WrapGuestFunctionImpl@plt`
3. Point dispatch table entry `(name_ptr, wrapper_ptr)` to your new stub VA.
4. Restart Waydroid to reload library.
5. Validate with:
   - targeted ARM test (`vk_arm_tests/bin/testXX`)
   - UE launch logcat checks

## 6) Why direct wrapper-copy can crash

If signature/helper does not match the API ABI exactly, translator marshalling is wrong and crashes when function is called (as seen with sparse-old experiments).

So for universal correctness, the custom wrapper must use a compatible helper signature path, not just a random nearby `vkGetPhysicalDevice*` stub.

