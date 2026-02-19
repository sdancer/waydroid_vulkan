#include "common.h"
#include <dlfcn.h>
#include <stdint.h>

#ifndef VK_EXT_SHADER_OBJECT_EXTENSION_NAME
#define VK_EXT_SHADER_OBJECT_EXTENSION_NAME "VK_EXT_shader_object"
#endif
#ifndef VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FEATURES_2
#define VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FEATURES_2 ((VkStructureType)1000059000)
#endif
#ifndef VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SHADER_OBJECT_FEATURES_EXT
#define VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SHADER_OBJECT_FEATURES_EXT ((VkStructureType)1000482000)
#endif

typedef struct VkPhysicalDeviceShaderObjectFeaturesEXT_local {
  VkStructureType sType;
  void* pNext;
  VkBool32 shaderObject;
} VkPhysicalDeviceShaderObjectFeaturesEXT_local;

typedef struct VkPhysicalDeviceFeatures2_local {
  VkStructureType sType;
  void* pNext;
  VkPhysicalDeviceFeatures features;
} VkPhysicalDeviceFeatures2_local;

typedef void (VKAPI_PTR *PFN_vkCmdBindShadersEXT_local)(
    VkCommandBuffer commandBuffer, uint32_t stageCount,
    const VkShaderStageFlagBits* pStages, const uint64_t* pShaders);

static int has_ext(VkPhysicalDevice gpu, const char* name) {
  uint32_t ext_count = 0;
  if (vkEnumerateDeviceExtensionProperties(gpu, NULL, &ext_count, NULL) != VK_SUCCESS) return 0;
  VkExtensionProperties* exts = (VkExtensionProperties*)calloc(ext_count ? ext_count : 1, sizeof(*exts));
  if (!exts) return 0;
  if (ext_count) vkEnumerateDeviceExtensionProperties(gpu, NULL, &ext_count, exts);
  int found = 0;
  for (uint32_t i = 0; i < ext_count; ++i) {
    if (strcmp(exts[i].extensionName, name) == 0) {
      found = 1;
      break;
    }
  }
  free(exts);
  return found;
}

static void dump_cb_bytes(const char* tag, const void* p) {
  const unsigned char* b = (const unsigned char*)p;
  if (!b) {
    printf("DBG %s=<null>\n", tag);
    return;
  }
  printf("DBG %s ptr=%p bytes=", tag, p);
  for (int i = 0; i < 16; ++i) printf("%02x", b[i]);
  printf("\n");
}

int main(void) {
  VkInstance instance;
  VkPhysicalDevice phys;
  VkDevice dev;
  uint32_t qfi;
  int rc = init_instance_device(&instance, &phys, &dev, &qfi);
  if (rc) return rc;

  PFN_vkVoidFunction fp_i = vkGetInstanceProcAddr(instance, "vkCmdBindShadersEXT");
  PFN_vkVoidFunction fp_d = vkGetDeviceProcAddr(dev, "vkCmdBindShadersEXT");

  printf("FUNC=vkCmdBindShadersEXT instance_ptr=%p device_ptr=%p\n", (void*)fp_i, (void*)fp_d);
  if (fp_i) {
    Dl_info inf = {0};
    if (dladdr((void*)fp_i, &inf) && inf.dli_fname) {
      printf("instance_owner=%s sym=%s\n", inf.dli_fname, inf.dli_sname ? inf.dli_sname : "<null>");
    }
  }
  if (fp_d) {
    Dl_info inf = {0};
    if (dladdr((void*)fp_d, &inf) && inf.dli_fname) {
      printf("device_owner=%s sym=%s\n", inf.dli_fname, inf.dli_sname ? inf.dli_sname : "<null>");
    }
  }

  if (!fp_i && !fp_d) {
    cleanup_instance_device(instance, dev);
    puts("FAIL missing proc");
    return 2;
  }

  int ext_present = has_ext(phys, VK_EXT_SHADER_OBJECT_EXTENSION_NAME);
  PFN_vkVoidFunction p_gpdf2 = vkGetInstanceProcAddr(instance, "vkGetPhysicalDeviceFeatures2");
  VkPhysicalDeviceShaderObjectFeaturesEXT_local f_shader = {
      .sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SHADER_OBJECT_FEATURES_EXT, .pNext = NULL};
  VkPhysicalDeviceFeatures2_local f2 = {
      .sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FEATURES_2, .pNext = &f_shader};
  if (p_gpdf2) {
    typedef void (VKAPI_PTR *PFN_vkGetPhysicalDeviceFeatures2_local)(
        VkPhysicalDevice, VkPhysicalDeviceFeatures2_local*);
    ((PFN_vkGetPhysicalDeviceFeatures2_local)p_gpdf2)(phys, &f2);
  }
  printf("DBG shader_object ext_present=%d feature=%u\n", ext_present, (unsigned)f_shader.shaderObject);
  if (!ext_present || f_shader.shaderObject == VK_FALSE) {
    cleanup_instance_device(instance, dev);
    puts("PASS proc visible (shader object disabled, call skipped)");
    return 0;
  }

  VkCommandPool pool = VK_NULL_HANDLE;
  VkCommandBuffer cb = VK_NULL_HANDLE;
  VkCommandPoolCreateInfo pci = {0};
  pci.sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO;
  pci.queueFamilyIndex = qfi;
  pci.flags = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;
  if (vkCreateCommandPool(dev, &pci, NULL, &pool) != VK_SUCCESS) {
    cleanup_instance_device(instance, dev);
    puts("FAIL create pool");
    return 3;
  }
  VkCommandBufferAllocateInfo cai = {0};
  cai.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
  cai.commandPool = pool;
  cai.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
  cai.commandBufferCount = 1;
  if (vkAllocateCommandBuffers(dev, &cai, &cb) != VK_SUCCESS) {
    vkDestroyCommandPool(dev, pool, NULL);
    cleanup_instance_device(instance, dev);
    puts("FAIL alloc cb");
    return 4;
  }
  VkCommandBufferBeginInfo bi = {0};
  bi.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
  if (vkBeginCommandBuffer(cb, &bi) != VK_SUCCESS) {
    vkDestroyCommandPool(dev, pool, NULL);
    cleanup_instance_device(instance, dev);
    puts("FAIL begin cb");
    return 5;
  }

  PFN_vkCmdBindShadersEXT_local fn =
      (PFN_vkCmdBindShadersEXT_local)(fp_d ? fp_d : fp_i);
  VkShaderStageFlagBits stages_local[1] = {VK_SHADER_STAGE_VERTEX_BIT};
  uint64_t shaders_local[1] = {0};
  uint32_t stage_count = 1;
  const VkShaderStageFlagBits* stages = stages_local;
  const uint64_t* shaders = shaders_local;
  printf("DBG call vkCmdBindShadersEXT fn=%p cb=%p stageCount=%u stages=%p shaders=%p\n",
         (void*)fn, (void*)cb, stage_count, (void*)stages, (void*)shaders);
  dump_cb_bytes("cb_pre", (const void*)cb);
  fn(cb, stage_count, stages, shaders);
  dump_cb_bytes("cb_post", (const void*)cb);

  if (vkEndCommandBuffer(cb) != VK_SUCCESS) {
    vkDestroyCommandPool(dev, pool, NULL);
    cleanup_instance_device(instance, dev);
    puts("FAIL end cb");
    return 6;
  }

  vkDestroyCommandPool(dev, pool, NULL);
  cleanup_instance_device(instance, dev);
  puts("PASS proc+call");
  return 0;
}
