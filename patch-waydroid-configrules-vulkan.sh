#!/usr/bin/env bash
set -euo pipefail

# Patch UE Android configrules cache Vulkan vars inside Waydroid app data.
# Usage:
#   ./patch-waydroid-configrules-vulkan.sh <package> [vulkan_version]
# Example:
#   ./patch-waydroid-configrules-vulkan.sh com.sdancer.uevulkanprobecpp 1.1.0

PKG="${1:-}"
VK_VER="${2:-1.1.0}"

if [[ -z "${PKG}" ]]; then
  echo "usage: $0 <package> [vulkan_version]" >&2
  exit 2
fi

CACHE_PATH="/data/user/0/${PKG}/files/configrules.cache"
TMP_IN="/tmp/${PKG}.configrules.cache.bin"
TMP_OUT="/tmp/${PKG}.configrules.cache.patched.bin"
JAVA_SRC="/tmp/patch_configrules_cache.java"
JAVA_CLASS="/tmp/patch_configrules_cache.class"

cat > "${JAVA_SRC}" <<'EOF'
import java.io.*;
import java.nio.*;
import java.nio.file.*;
import java.util.*;

public class patch_configrules_cache {
  @SuppressWarnings("unchecked")
  public static void main(String[] args) throws Exception {
    if (args.length < 2) {
      System.err.println("usage: patch_configrules_cache <in> <out> [--set key=value]...");
      System.exit(2);
    }
    byte[] all = Files.readAllBytes(Path.of(args[0]));
    if (all.length < 24) throw new RuntimeException("too small");

    ByteBuffer bb = ByteBuffer.wrap(all).order(ByteOrder.BIG_ENDIAN);
    int ver = bb.getInt();
    long rulesCrc = bb.getLong();
    long varsCrc = bb.getLong();
    int flags = bb.getInt();

    ObjectInputStream ois = new ObjectInputStream(new ByteArrayInputStream(all, 24, all.length - 24));
    Object obj = ois.readObject();
    ois.close();
    if (!(obj instanceof HashMap)) throw new RuntimeException("payload is not HashMap");
    HashMap<String,String> map = (HashMap<String,String>)obj;

    System.out.println("header ver=" + ver + " rulesCrc=" + Long.toUnsignedString(rulesCrc) +
        " varsCrc=" + Long.toUnsignedString(varsCrc) + " flags=" + flags);
    System.out.println("before SRC_VulkanAvailable=" + map.get("SRC_VulkanAvailable") +
        " SRC_VulkanVersion=" + map.get("SRC_VulkanVersion"));

    for (int i = 2; i < args.length; i++) {
      String a = args[i];
      if (!a.startsWith("--set ")) continue;
      String kv = a.substring(6);
      int p = kv.indexOf('=');
      if (p < 1) continue;
      String k = kv.substring(0, p);
      String v = kv.substring(p + 1);
      map.put(k, v);
      System.out.println("set " + k + "=" + v);
    }

    System.out.println("after SRC_VulkanAvailable=" + map.get("SRC_VulkanAvailable") +
        " SRC_VulkanVersion=" + map.get("SRC_VulkanVersion"));

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
  }
}
EOF

if ! command -v javac >/dev/null 2>&1; then
  echo "javac not found; install JDK first" >&2
  exit 3
fi

if ! command -v java >/dev/null 2>&1; then
  echo "java not found; install JRE/JDK first" >&2
  exit 3
fi

sudo waydroid shell -- test -f "${CACHE_PATH}" || {
  echo "configrules cache not found: ${CACHE_PATH}" >&2
  exit 4
}

sudo waydroid shell -- cat "${CACHE_PATH}" > "${TMP_IN}"

javac "${JAVA_SRC}"
java -cp /tmp patch_configrules_cache "${TMP_IN}" "${TMP_OUT}" \
  "--set SRC_VulkanAvailable=true" \
  "--set SRC_VulkanVersion=${VK_VER}"

cat "${TMP_OUT}" | sudo waydroid shell -- sh -lc "cat > '${CACHE_PATH}' && chmod 600 '${CACHE_PATH}'"

echo "patched ${CACHE_PATH}"
echo "done"
