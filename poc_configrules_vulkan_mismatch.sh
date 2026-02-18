#!/usr/bin/env bash
set -euo pipefail

PKG="${1:-com.sdancer.uevulkanprobecpp}"
VK_VER="${2:-1.1.311}"
CACHE_PATH="/data/user/0/${PKG}/files/configrules.cache"
OUT_DIR="${PWD}/poc_out"
mkdir -p "${OUT_DIR}"

need() {
  command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 2; }
}

need sudo
need waydroid
need javac
need java

if ! sudo waydroid shell -- test -f "${CACHE_PATH}"; then
  echo "configrules cache missing at ${CACHE_PATH}" >&2
  exit 3
fi

JAVA_SRC="${OUT_DIR}/PatchConfigRulesCache.java"
cat > "${JAVA_SRC}" <<'JAV'
import java.io.*;
import java.nio.*;
import java.nio.file.*;
import java.util.*;

public class PatchConfigRulesCache {
  @SuppressWarnings("unchecked")
  public static void main(String[] args) throws Exception {
    if (args.length != 4) {
      System.err.println("usage: PatchConfigRulesCache <in> <out> <vulkanAvailable:true|false> <vulkanVersion>");
      System.exit(2);
    }
    byte[] all = Files.readAllBytes(Path.of(args[0]));
    if (all.length < 24) throw new RuntimeException("cache too small");

    ByteBuffer bb = ByteBuffer.wrap(all).order(ByteOrder.BIG_ENDIAN);
    int ver = bb.getInt();
    long rulesCrc = bb.getLong();
    long varsCrc = bb.getLong();
    int flags = bb.getInt();

    ObjectInputStream ois = new ObjectInputStream(new ByteArrayInputStream(all, 24, all.length - 24));
    Object obj = ois.readObject();
    ois.close();
    if (!(obj instanceof HashMap)) throw new RuntimeException("payload is not HashMap");

    HashMap<String, String> map = (HashMap<String, String>) obj;
    map.put("SRC_VulkanAvailable", args[2]);
    map.put("SRC_VulkanVersion", args[3]);

    ByteArrayOutputStream payloadBos = new ByteArrayOutputStream();
    ObjectOutputStream oos = new ObjectOutputStream(payloadBos);
    oos.writeObject(map);
    oos.close();

    byte[] payload = payloadBos.toByteArray();
    ByteArrayOutputStream out = new ByteArrayOutputStream();
    DataOutputStream dos = new DataOutputStream(out);
    dos.writeInt(ver);
    dos.writeLong(rulesCrc);
    dos.writeLong(varsCrc);
    dos.writeInt(flags);
    dos.write(payload);
    dos.close();

    Files.write(Path.of(args[1]), out.toByteArray());

    System.out.println("header ver=" + ver + " rulesCrc=" + Long.toUnsignedString(rulesCrc)
        + " varsCrc=" + Long.toUnsignedString(varsCrc) + " flags=" + flags);
    System.out.println("patched SRC_VulkanAvailable=" + map.get("SRC_VulkanAvailable")
        + " SRC_VulkanVersion=" + map.get("SRC_VulkanVersion"));
  }
}
JAV

javac "${JAVA_SRC}"

apply_cache() {
  local vulkan_available="$1"
  local vulkan_version="$2"
  local in_file="${OUT_DIR}/configrules.in.bin"
  local out_file="${OUT_DIR}/configrules.${vulkan_available}.bin"

  sudo waydroid shell -- cat "${CACHE_PATH}" > "${in_file}"
  java -cp "${OUT_DIR}" PatchConfigRulesCache "${in_file}" "${out_file}" "${vulkan_available}" "${vulkan_version}" > "${OUT_DIR}/patch_${vulkan_available}.txt"
  cat "${out_file}" | sudo waydroid shell -- sh -lc "cat > '${CACHE_PATH}' && chmod 600 '${CACHE_PATH}'"
}

capture_phase() {
  local phase="$1"
  local log_file="${OUT_DIR}/${phase}.log"
  local component="${PKG}/com.epicgames.unreal.SplashActivity"

  sudo waydroid shell -- am force-stop "${PKG}" || true
  sudo waydroid shell -- logcat -c || true
  sudo waydroid shell -- am start -W -n "${component}" > "${OUT_DIR}/${phase}_am_start.txt" 2>&1 || true
  sleep 45
  sudo waydroid shell -- logcat -d > "${log_file}" || true

  {
    echo "=== ${phase} summary ==="
    rg -n "\\[GameActivity\\] Vulkan version|\\$\\$\\$ configrules|SRC_VKQuality|SRC_ConfigRuleVar\\[SRC_VulkanAvailable\\]|SRC_ConfigRuleVar\\[SRC_VulkanVersion\\]|VulkanRHI will be used|VulkanRHI will NOT be used|This device does not support Vulkan" "${log_file}" || true
    echo
  } > "${OUT_DIR}/${phase}_summary.txt"
}

# Repro bad state
apply_cache "false" "0.0.0"
capture_phase "fail"

# Apply fix
apply_cache "true" "${VK_VER}"
capture_phase "fix"

printf "PoC outputs:\n"
printf "  %s\n" "${OUT_DIR}/fail_summary.txt" "${OUT_DIR}/fix_summary.txt" "${OUT_DIR}/fail.log" "${OUT_DIR}/fix.log" "${OUT_DIR}/patch_false.txt" "${OUT_DIR}/patch_true.txt"
