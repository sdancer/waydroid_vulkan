#!/usr/bin/env bash
set -euo pipefail

# Push and run all vk_arm_tests binaries inside Waydroid.
# Focus: detect crashy behavior (segfault/abort/trap/timeout) for API probes.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${ROOT}/vk_arm_tests/bin"
REMOTE_DIR="/data/local/tmp"
OUT_DIR="${ROOT}/vk_arm_tests/out"
TS="$(date +%Y%m%d_%H%M%S)"
RAW_OUT="${OUT_DIR}/results_waydroid_${TS}.txt"
SUMMARY_OUT="${OUT_DIR}/summary_waydroid_${TS}.md"

mkdir -p "${OUT_DIR}"

if ! compgen -G "${BIN_DIR}/test*" >/dev/null; then
  echo "No test binaries found in ${BIN_DIR}" >&2
  echo "Build first: ./vk_arm_tests/build.sh" >&2
  exit 1
fi

echo "# Waydroid Vulkan ARM Test Run (${TS})" > "${SUMMARY_OUT}"
echo >> "${SUMMARY_OUT}"
echo "| Test | Status | RC | Note |" >> "${SUMMARY_OUT}"
echo "|---|---|---:|---|" >> "${SUMMARY_OUT}"

: > "${RAW_OUT}"
total=0
pass=0
fail=0

for host_bin in "${BIN_DIR}"/test*; do
  name="$(basename "${host_bin}")"
  total=$((total + 1))

  {
    echo "=== ${name} ==="
    echo "[push]"
  } >> "${RAW_OUT}"

  cat "${host_bin}" | sudo waydroid shell -- sh -lc "cat > ${REMOTE_DIR}/${name} && chmod 755 ${REMOTE_DIR}/${name}" >> "${RAW_OUT}" 2>&1

  {
    echo "[run]"
  } >> "${RAW_OUT}"

  set +e
  timeout 25s sudo waydroid shell -- sh -lc "\"${REMOTE_DIR}/${name}\"; printf '__WAYDROID_TEST_RC__=%d\n' \$?" >> "${RAW_OUT}" 2>&1
  shell_rc=$?
  set -e

  rc="${shell_rc}"
  if [[ ${shell_rc} -ne 124 ]]; then
    marker_line="$(awk "/^=== ${name//\//\\/} ===/{flag=1;next}/^=== /{flag=0}flag" "${RAW_OUT}" | rg -n "__WAYDROID_TEST_RC__=" -S | tail -n1 || true)"
    if [[ -n "${marker_line}" ]]; then
      rc="${marker_line##*=}"
    fi
  fi

  status="PASS"
  note="ok"
  if [[ ${shell_rc} -eq 124 ]]; then
    status="FAIL"
    note="timeout"
  elif [[ ${rc} -ne 0 ]]; then
    status="FAIL"
    note="rc=${rc}"
  fi

  # Secondary crash scan in test output block.
  block="$(awk "/^=== ${name//\//\\/} ===/{flag=1;next}/^=== /{flag=0}flag" "${RAW_OUT}")"
  if echo "${block}" | rg -qi "segmentation fault|SIGSEGV|abort|SIGABRT|illegal instruction|SIGILL|bus error|SIGBUS|trace/breakpoint trap"; then
    status="FAIL"
    note="crash-signature"
  fi

  if [[ "${status}" == "PASS" ]]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
  fi

  {
    echo "RC=${rc}"
    echo
  } >> "${RAW_OUT}"

  echo "| ${name} | ${status} | ${rc} | ${note} |" >> "${SUMMARY_OUT}"
done

{
  echo
  echo "- Total: ${total}"
  echo "- Pass: ${pass}"
  echo "- Fail: ${fail}"
  echo "- Raw: \`${RAW_OUT}\`"
} >> "${SUMMARY_OUT}"

echo "Wrote:"
echo "  ${SUMMARY_OUT}"
echo "  ${RAW_OUT}"
