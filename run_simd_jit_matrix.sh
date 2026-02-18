#!/usr/bin/env bash
set -u
OPS=(fneg_2d fneg_4s fabs_2d fsqrt_2d frsqrte_2s frsqrte_4s frsqrte_2d)
ITERS=800000

cat > /tmp/bpf_one.bt <<'BPF'
uprobe:/var/lib/waydroid/overlay/system/lib64/libndk_translation.so:0x1a06a0 { @hits["RSqrtF32x2_ctor"] = count(); }
uprobe:/var/lib/waydroid/overlay/system/lib64/libndk_translation.so:0x1a0710 { @hits["RSqrtF32x4_ctor"] = count(); }
uprobe:/var/lib/waydroid/overlay/system/lib64/libndk_translation.so:0x1a0400 { @hits["NegF32_ctor"] = count(); }
uprobe:/var/lib/waydroid/overlay/system/lib64/libndk_translation.so:0x1a0470 { @hits["NegF64_ctor"] = count(); }
uprobe:/var/lib/waydroid/overlay/system/lib64/libndk_translation.so:0x180b20 { @hits["LightTranslator_Undef"] = count(); }
uprobe:/var/lib/waydroid/overlay/system/lib64/libndk_translation.so:0x207940 { @hits["UndefinedInsn"] = count(); @op[*(uint32*)arg0]=count(); }
END { print(@hits); print(@op); }
BPF

printf "%-14s | %-12s | %-12s | %-10s | %-10s | %-10s | %-10s\n" "op" "RSqrt2" "RSqrt4" "NegF32" "NegF64" "LT_Undef" "Undef"
printf -- "%.0s-" {1..96}; echo

for op in "${OPS[@]}"; do
  sudo timeout 8s bpftrace /tmp/bpf_one.bt > "/tmp/bpf_${op}.out" 2>"/tmp/bpf_${op}.err" &
  BPID=$!
  sleep 0.6
  timeout 7s sudo waydroid shell -- /data/local/tmp/simd_jit_map "$op" "$ITERS" > "/tmp/run_${op}.out" 2>&1 || true
  wait "$BPID" || true

  rs2=$(rg -o '@hits\[RSqrtF32x2_ctor\]:\s*[0-9]+' "/tmp/bpf_${op}.out" | awk '{print $2}' | tail -n1)
  rs4=$(rg -o '@hits\[RSqrtF32x4_ctor\]:\s*[0-9]+' "/tmp/bpf_${op}.out" | awk '{print $2}' | tail -n1)
  n32=$(rg -o '@hits\[NegF32_ctor\]:\s*[0-9]+' "/tmp/bpf_${op}.out" | awk '{print $2}' | tail -n1)
  n64=$(rg -o '@hits\[NegF64_ctor\]:\s*[0-9]+' "/tmp/bpf_${op}.out" | awk '{print $2}' | tail -n1)
  ltu=$(rg -o '@hits\[LightTranslator_Undef\]:\s*[0-9]+' "/tmp/bpf_${op}.out" | awk '{print $2}' | tail -n1)
  und=$(rg -o '@hits\[UndefinedInsn\]:\s*[0-9]+' "/tmp/bpf_${op}.out" | awk '{print $2}' | tail -n1)

  rs2=${rs2:-0}; rs4=${rs4:-0}; n32=${n32:-0}; n64=${n64:-0}; ltu=${ltu:-0}; und=${und:-0}

  printf "%-14s | %-12s | %-12s | %-10s | %-10s | %-10s | %-10s\n" "$op" "$rs2" "$rs4" "$n32" "$n64" "$ltu" "$und"

  echo "  run: $(tr '\n' ' ' < /tmp/run_${op}.out | sed 's/  */ /g')"
  if [ -s "/tmp/bpf_${op}.err" ]; then
    tail -n 4 "/tmp/bpf_${op}.err" | sed 's/^/  bpferr: /'
  fi
  opcodes=$(rg '^@op\[' "/tmp/bpf_${op}.out" | sed 's/^/  /')
  if [ -n "$opcodes" ]; then echo "$opcodes"; fi

done
