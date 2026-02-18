#!/usr/bin/env bash
set -euo pipefail

LIB=/var/lib/waydroid/overlay/system/lib64/libndk_translation.so
BIN=/data/local/tmp/simd_jit_map
OPS=(fneg_2d fneg_4s fabs_2d fsqrt_2d frsqrte_2s frsqrte_4s frsqrte_2d)

cat > /tmp/bpf_simd_jit.bt <<'BPF'
uprobe:/var/lib/waydroid/overlay/system/lib64/libndk_translation.so:0x1a0400 { @hits["MacroNegF32_ctor"] = count(); }
uprobe:/var/lib/waydroid/overlay/system/lib64/libndk_translation.so:0x1a0470 { @hits["MacroNegF64_ctor"] = count(); }
uprobe:/var/lib/waydroid/overlay/system/lib64/libndk_translation.so:0x1a06a0 { @hits["MacroRSqrtF32x2_ctor"] = count(); }
uprobe:/var/lib/waydroid/overlay/system/lib64/libndk_translation.so:0x1a0710 { @hits["MacroRSqrtF32x4_ctor"] = count(); }
uprobe:/var/lib/waydroid/overlay/system/lib64/libndk_translation.so:0x180b20 { @hits["LightTranslator_Undef"] = count(); }
uprobe:/var/lib/waydroid/overlay/system/lib64/libndk_translation.so:0x207940 { @hits["UndefinedInsn"] = count(); @opcodes[*(uint32*)arg0] = count(); }
uprobe:/var/lib/waydroid/overlay/system/lib64/libndk_translation.so:0x1f9ba0 { @hits["Interp_VectorRSqrtFP"] = count(); }
uprobe:/var/lib/waydroid/overlay/system/lib64/libndk_translation.so:0x206ba0 { @hits["Interp_VectorNegFP"] = count(); }
uprobe:/var/lib/waydroid/overlay/system/lib64/libndk_translation.so:0x206b20 { @hits["Interp_VectorAbsFP"] = count(); }
uprobe:/var/lib/waydroid/overlay/system/lib64/libndk_translation.so:0x1ed0f0 { @hits["Interp_VectorSqrtFP"] = count(); }
END {
  print(@hits);
  print(@opcodes);
}
BPF

printf "# SIMD JIT mapping (lib sha=%s)\n" "$(sha256sum "$LIB" | awk '{print $1}')"

for op in "${OPS[@]}"; do
  echo
  echo "## $op"
  sudo waydroid shell -- logcat -c >/dev/null 2>&1 || true

  # Run probe workload in background.
  timeout 6s sudo waydroid shell -- "$BIN" "$op" 400000 >/tmp/simd_jit_${op}.out 2>&1 &
  run_pid=$!

  # Trace while workload executes.
  sudo timeout 3s bpftrace /tmp/bpf_simd_jit.bt > /tmp/simd_jit_${op}.trace 2>/tmp/simd_jit_${op}.err || true
  wait "$run_pid" || true

  echo "workload: $(tr '\n' ' ' < /tmp/simd_jit_${op}.out | sed 's/  */ /g')"
  echo "trace:"
  sed -n '1,160p' /tmp/simd_jit_${op}.trace | sed 's/^/  /'

  echo "undef log summary:"
  sudo waydroid shell -- logcat -d | rg -o 'Undefined instruction 0x[0-9a-fA-F]+' | awk '{print $3}' | sort | uniq -c | sort -nr | sed 's/^/  /' || true

done
