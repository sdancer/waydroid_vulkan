#!/usr/bin/env bash
set -euo pipefail

# Collect unsupported ARM instruction reports from ndk_translation.
# Usage:
#   ./collect-ndk-undef.sh [package] [activity] [runs]
#
# Example:
#   ./collect-ndk-undef.sh com.sdancer.uevulkanprobecpp com.epicgames.unreal.SplashActivity 10

PKG="${1:-com.sdancer.uevulkanprobecpp}"
ACTIVITY="${2:-com.epicgames.unreal.SplashActivity}"
RUNS="${3:-8}"

OUT_DIR="${OUT_DIR:-/tmp}"
STAMP="$(date +%Y%m%d-%H%M%S)"
RAW_LOG="${OUT_DIR}/ndk-undef-${PKG}-${STAMP}.log"
REPORT="${OUT_DIR}/ndk-undef-${PKG}-${STAMP}.report.txt"

COMPONENT="${PKG}/${ACTIVITY}"

echo "Package: ${PKG}" | tee "${REPORT}"
echo "Activity: ${ACTIVITY}" | tee -a "${REPORT}"
echo "Runs: ${RUNS}" | tee -a "${REPORT}"
echo "Raw log: ${RAW_LOG}" | tee -a "${REPORT}"
echo "---" | tee -a "${REPORT}"

for i in $(seq 1 "${RUNS}"); do
  echo "[run ${i}] launching ${COMPONENT}" | tee -a "${REPORT}"
  sudo waydroid shell -- am force-stop "${PKG}" >/dev/null 2>&1 || true
  sudo waydroid shell -- logcat -c
  sudo waydroid shell -- am start -n "${COMPONENT}" >/dev/null 2>&1 || true
  sleep 7
  sudo waydroid shell -- logcat -d >> "${RAW_LOG}" || true
  echo "[run ${i}] done" | tee -a "${REPORT}"
done

echo "--- unique unsupported opcodes ---" | tee -a "${REPORT}"
rg -o "Undefined instruction 0x[0-9a-fA-F]+ at 0x[0-9a-fA-F]+" "${RAW_LOG}" \
  | sort -u | tee -a "${REPORT}" || true

echo "--- summary by opcode ---" | tee -a "${REPORT}"
rg -o "Undefined instruction 0x[0-9a-fA-F]+" "${RAW_LOG}" \
  | awk '{print $3}' | sort | uniq -c | sort -nr | tee -a "${REPORT}" || true

echo "--- recent matching lines ---" | tee -a "${REPORT}"
rg -n "ndk_translation: Undefined instruction|signal 0 \\(SIGILL\\)|F DEBUG" "${RAW_LOG}" \
  | tail -n 80 | tee -a "${REPORT}" || true

echo "Report: ${REPORT}"
