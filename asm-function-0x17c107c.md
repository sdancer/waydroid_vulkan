# Function Containing `0x17c107c`

Source binary: `/tmp/libUnreal.live.so`  
Disassembly command:

```bash
llvm-objdump -d --no-show-raw-insn \
  --start-address=0x17c0eb8 --stop-address=0x17c10e4 \
  /tmp/libUnreal.live.so
```

```asm
00000000017bdc74 <Java_com_epicgames_unreal_BatteryReceiver_dispatchEvent>:
 17c0eb8:      stp    x29, x30, [sp, #-0x50]!
 17c0ebc:      str    x28, [sp, #0x10]
 17c0ec0:      mov    x29, sp
 17c0ec4:      stp    x24, x23, [sp, #0x20]
 17c0ec8:      stp    x22, x21, [sp, #0x30]
 17c0ecc:      stp    x20, x19, [sp, #0x40]
 17c0ed0:      sub    sp, sp, #0x3e0
 17c0ed4:      mrs    x24, TPIDR_EL0
 17c0ed8:      ldr    x8, [x24, #0x28]
 17c0edc:      stur   x8, [x29, #-0x8]
 17c0ee0:      cbz    x0, 0x17c1034 <Java_com_epicgames_unreal_BatteryReceiver_dispatchEvent+0x33c0>
 17c0ee4:      adrp   x1, 0x667000
 17c0ee8:      mov    x22, x0
 17c0eec:      add    x1, x1, #0x665
 17c0ef0:      bl     0x82907b0 <dlsym@plt>
 17c0ef4:      adrp   x1, 0x666000
 17c0ef8:      mov    x23, x0
 17c0efc:      add    x1, x1, #0xe55
 17c0f00:      mov    x0, x22
 17c0f04:      bl     0x82907b0 <dlsym@plt>
 17c0f08:      adrp   x1, 0x59f000
 17c0f0c:      mov    x19, x0
 17c0f10:      add    x1, x1, #0x64
 17c0f14:      mov    x0, x22
 17c0f18:      bl     0x82907b0 <dlsym@plt>
 17c0f1c:      adrp   x1, 0x59b000
 17c0f20:      mov    x21, x0
 17c0f24:      add    x1, x1, #0xafb
 17c0f28:      mov    x0, x22
 17c0f2c:      bl     0x82907b0 <dlsym@plt>
 17c0f30:      adrp   x1, 0x59b000
 17c0f34:      mov    x20, x0
 17c0f38:      add    x1, x1, #0x810
 17c0f3c:      mov    x0, x22
 17c0f40:      bl     0x82907b0 <dlsym@plt>
 17c0f44:      mov    w22, #0x1               // =1
 17c0f48:      cbz    x23, 0x17c1038 <Java_com_epicgames_unreal_BatteryReceiver_dispatchEvent+0x33c4>
 17c0f4c:      cbz    x19, 0x17c1038 <Java_com_epicgames_unreal_BatteryReceiver_dispatchEvent+0x33c4>
 17c0f50:      cbz    x21, 0x17c1038 <Java_com_epicgames_unreal_BatteryReceiver_dispatchEvent+0x33c4>
 17c0f54:      cbz    x20, 0x17c1038 <Java_com_epicgames_unreal_BatteryReceiver_dispatchEvent+0x33c4>
 17c0f58:      cbz    x0, 0x17c1038 <Java_com_epicgames_unreal_BatteryReceiver_dispatchEvent+0x33c4>
 17c0f5c:      movi   v0.2d, #0000000000000000
 17c0f60:      adrp   x8, 0x6ae000
 17c0f64:      add    x8, x8, #0x234
 17c0f68:      adrp   x9, 0x516000
 17c0f6c:      mov    w22, #0x1               // =1
 17c0f70:      add    x0, sp, #0x30
 17c0f74:      add    x2, sp, #0x28
 17c0f78:      mov    x1, xzr
 17c0f7c:      stp    q0, q0, [sp, #0x70]
 17c0f80:      ldr    d1, [x9, #0x9e8]
 17c0f84:      str    x8, [sp, #0x80]
 17c0f88:      str    x8, [sp, #0x90]
 17c0f8c:      add    x8, sp, #0x70
 17c0f90:      stp    q0, q0, [sp, #0x30]
 17c0f94:      str    d1, [sp, #0x98]
 17c0f98:      stp    xzr, xzr, [sp, #0x60]
 17c0f9c:      str    q0, [sp, #0x50]
 17c0fa0:      str    w22, [sp, #0x30]
 17c0fa4:      str    x8, [sp, #0x48]
 17c0fa8:      blr    x23
 17c0fac:      cbnz   w0, 0x17c1038 <Java_com_epicgames_unreal_BatteryReceiver_dispatchEvent+0x33c4>
 17c0fb0:      ldr    x0, [sp, #0x28]
 17c0fb4:      add    x1, sp, #0x24
 17c0fb8:      mov    x2, xzr
 17c0fbc:      str    wzr, [sp, #0x24]
 17c0fc0:      blr    x21
 17c0fc4:      cbnz   w0, 0x17c1028 <Java_com_epicgames_unreal_BatteryReceiver_dispatchEvent+0x33b4>
 17c0fc8:      ldr    w8, [sp, #0x24]
 17c0fcc:      cbz    w8, 0x17c1028 <Java_com_epicgames_unreal_BatteryReceiver_dispatchEvent+0x33b4>
 17c0fd0:      add    x0, sp, #0x10
 17c0fd4:      mov    w1, wzr
 17c0fd8:      sxtw   x22, w8
 17c0fdc:      stp    xzr, xzr, [sp, #0x10]
 17c0fe0:      str    w8, [sp, #0x18]
 17c0fe4:      bl     0x17d7fb8 <Java_com_epicgames_unreal_GameActivity_nativeSetAffinityInfo+0x14894>
 17c0fe8:      ldr    x0, [sp, #0x10]
 17c0fec:      lsl    x2, x22, #3
 17c0ff0:      mov    w1, wzr
 17c0ff4:      bl     0x82903c0 <memset@plt>
 17c0ff8:      ldr    x0, [sp, #0x28]
 17c0ffc:      add    x1, sp, #0x24
 17c1000:      ldr    x2, [sp, #0x10]
 17c1004:      blr    x21
 17c1008:      cbz    w0, 0x17c1068 <Java_com_epicgames_unreal_BatteryReceiver_dispatchEvent+0x33f4>
 17c100c:      ldr    x0, [sp, #0x28]
 17c1010:      mov    x1, xzr
 17c1014:      blr    x19
 17c1018:      mov    w22, #0x1               // =1
 17c101c:      ldr    x0, [sp, #0x10]
 17c1020:      cbnz   x0, 0x17c10d8 <Java_com_epicgames_unreal_BatteryReceiver_dispatchEvent+0x3464>
 17c1024:      b      0x17c1038 <Java_com_epicgames_unreal_BatteryReceiver_dispatchEvent+0x33c4>
 17c1028:      ldr    x0, [sp, #0x28]
 17c102c:      mov    x1, xzr
 17c1030:      blr    x19
 17c1034:      mov    w22, #0x1               // =1
 17c1038:      ldr    x8, [x24, #0x28]
 17c103c:      ldur   x9, [x29, #-0x8]
 17c1040:      cmp    x8, x9
 17c1044:      b.ne   0x17c10e0 <Java_com_epicgames_unreal_BatteryReceiver_dispatchEvent+0x346c>
 17c1048:      mov    w0, w22
 17c104c:      add    sp, sp, #0x3e0
 17c1050:      ldp    x20, x19, [sp, #0x40]
 17c1054:      ldp    x22, x21, [sp, #0x30]
 17c1058:      ldp    x24, x23, [sp, #0x20]
 17c105c:      ldr    x28, [sp, #0x10]
 17c1060:      ldp    x29, x30, [sp], #0x50
 17c1064:      ret
 17c1068:      ldr    x8, [sp, #0x10]
 17c106c:      add    x1, sp, #0xa0
 17c1070:      ldr    x0, [x8]
 17c1074:      blr    x20
 17c1078:      ldr    w8, [sp, #0xa0]
 17c107c:      adrp   x0, 0x2fb000
 17c1080:      add    x0, x0, #0x60
 17c1084:      lsr    w1, w8, #22
 17c1088:      ubfx   w2, w8, #12, #10
 17c108c:      and    w3, w8, #0xfff
 17c1090:      mov    x8, sp
 17c1094:      bl     0x1806af8 <_ZdlPvmSt11align_val_t+0x1dac8>
 17c1098:      adrp   x8, 0x95c5000
 17c109c:      ldr    x0, [x8, #0xa08]
 17c10a0:      cbz    x0, 0x17c10a8 <Java_com_epicgames_unreal_BatteryReceiver_dispatchEvent+0x3434>
 17c10a4:      bl     0x184db5c <_ZdlPvmSt11align_val_t+0x64b2c>
 17c10a8:      adrp   x9, 0x95c5000
 17c10ac:      ldr    x8, [sp]
 17c10b0:      add    x9, x9, #0xa08
 17c10b4:      ldr    d0, [sp, #0x8]
 17c10b8:      ldr    x0, [sp, #0x28]
 17c10bc:      mov    x1, xzr
 17c10c0:      str    x8, [x9]
 17c10c4:      str    d0, [x9, #0x8]
 17c10c8:      blr    x19
 17c10cc:      mov    w22, #0x2               // =2
 17c10d0:      ldr    x0, [sp, #0x10]
 17c10d4:      cbz    x0, 0x17c1038 <Java_com_epicgames_unreal_BatteryReceiver_dispatchEvent+0x33c4>
 17c10d8:      bl     0x184db5c <_ZdlPvmSt11align_val_t+0x64b2c>
 17c10dc:      b      0x17c1038 <Java_com_epicgames_unreal_BatteryReceiver_dispatchEvent+0x33c4>
 17c10e0:      bl     0x82903e0 <__stack_chk_fail@plt>
```
