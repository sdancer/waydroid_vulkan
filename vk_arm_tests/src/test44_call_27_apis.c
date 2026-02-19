#define _GNU_SOURCE
#include "common.h"
#include <inttypes.h>
#include <stdlib.h>
#include <dlfcn.h>
#include <stdint.h>
#include <string.h>

#ifndef VK_EXT_DESCRIPTOR_BUFFER_EXTENSION_NAME
#define VK_EXT_DESCRIPTOR_BUFFER_EXTENSION_NAME "VK_EXT_descriptor_buffer"
#endif
#ifndef VK_EXT_SHADER_OBJECT_EXTENSION_NAME
#define VK_EXT_SHADER_OBJECT_EXTENSION_NAME "VK_EXT_shader_object"
#endif
#ifndef VK_EXT_HOST_IMAGE_COPY_EXTENSION_NAME
#define VK_EXT_HOST_IMAGE_COPY_EXTENSION_NAME "VK_EXT_host_image_copy"
#endif
#ifndef VK_EXT_MESH_SHADER_EXTENSION_NAME
#define VK_EXT_MESH_SHADER_EXTENSION_NAME "VK_EXT_mesh_shader"
#endif
#ifndef VK_KHR_MAINTENANCE_5_EXTENSION_NAME
#define VK_KHR_MAINTENANCE_5_EXTENSION_NAME "VK_KHR_maintenance5"
#endif
#ifndef VK_KHR_BUFFER_DEVICE_ADDRESS_EXTENSION_NAME
#define VK_KHR_BUFFER_DEVICE_ADDRESS_EXTENSION_NAME "VK_KHR_buffer_device_address"
#endif

#ifndef VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FEATURES_2
#define VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FEATURES_2 ((VkStructureType)1000059000)
#endif
#ifndef VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_DESCRIPTOR_BUFFER_FEATURES_EXT
#define VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_DESCRIPTOR_BUFFER_FEATURES_EXT ((VkStructureType)1000316002)
#endif
#ifndef VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SHADER_OBJECT_FEATURES_EXT
#define VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SHADER_OBJECT_FEATURES_EXT ((VkStructureType)1000482000)
#endif
#ifndef VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_HOST_IMAGE_COPY_FEATURES_EXT
#define VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_HOST_IMAGE_COPY_FEATURES_EXT ((VkStructureType)1000270000)
#endif
#ifndef VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_MESH_SHADER_FEATURES_EXT
#define VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_MESH_SHADER_FEATURES_EXT ((VkStructureType)1000328000)
#endif
#ifndef VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_MAINTENANCE_5_FEATURES_KHR
#define VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_MAINTENANCE_5_FEATURES_KHR ((VkStructureType)1000470000)
#endif
#ifndef VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_BUFFER_DEVICE_ADDRESS_FEATURES
#define VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_BUFFER_DEVICE_ADDRESS_FEATURES ((VkStructureType)1000257000)
#endif
#ifndef VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_EXTENDED_DYNAMIC_STATE_3_FEATURES_EXT
#define VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_EXTENDED_DYNAMIC_STATE_3_FEATURES_EXT ((VkStructureType)1000455000)
#endif
#ifndef VK_STRUCTURE_TYPE_MEMORY_TO_IMAGE_COPY_EXT
#define VK_STRUCTURE_TYPE_MEMORY_TO_IMAGE_COPY_EXT ((VkStructureType)1000270002)
#endif
#ifndef VK_STRUCTURE_TYPE_COPY_MEMORY_TO_IMAGE_INFO_EXT
#define VK_STRUCTURE_TYPE_COPY_MEMORY_TO_IMAGE_INFO_EXT ((VkStructureType)1000270005)
#endif
#ifndef VK_STRUCTURE_TYPE_HOST_IMAGE_LAYOUT_TRANSITION_INFO_EXT
#define VK_STRUCTURE_TYPE_HOST_IMAGE_LAYOUT_TRANSITION_INFO_EXT ((VkStructureType)1000270006)
#endif
#ifndef VK_STRUCTURE_TYPE_DESCRIPTOR_ADDRESS_INFO_EXT
#define VK_STRUCTURE_TYPE_DESCRIPTOR_ADDRESS_INFO_EXT ((VkStructureType)1000316003)
#endif
#ifndef VK_STRUCTURE_TYPE_DESCRIPTOR_GET_INFO_EXT
#define VK_STRUCTURE_TYPE_DESCRIPTOR_GET_INFO_EXT ((VkStructureType)1000316004)
#endif
#ifndef VK_STRUCTURE_TYPE_DESCRIPTOR_BUFFER_BINDING_INFO_EXT
#define VK_STRUCTURE_TYPE_DESCRIPTOR_BUFFER_BINDING_INFO_EXT ((VkStructureType)1000316011)
#endif
#ifndef VK_STRUCTURE_TYPE_SHADER_CREATE_INFO_EXT
#define VK_STRUCTURE_TYPE_SHADER_CREATE_INFO_EXT ((VkStructureType)1000482002)
#endif
#ifndef VK_SHADER_CODE_TYPE_SPIRV_EXT
#define VK_SHADER_CODE_TYPE_SPIRV_EXT 1
#endif
#ifndef VK_IMAGE_USAGE_HOST_TRANSFER_BIT_EXT
#define VK_IMAGE_USAGE_HOST_TRANSFER_BIT_EXT 0x00400000
#endif
#ifndef VK_BUFFER_USAGE_RESOURCE_DESCRIPTOR_BUFFER_BIT_EXT
#define VK_BUFFER_USAGE_RESOURCE_DESCRIPTOR_BUFFER_BIT_EXT 0x00400000
#endif

#ifndef VK_EXT_extended_dynamic_state3
typedef struct VkColorBlendEquationEXT {
  VkBlendFactor srcColorBlendFactor;
  VkBlendFactor dstColorBlendFactor;
  VkBlendOp colorBlendOp;
  VkBlendFactor srcAlphaBlendFactor;
  VkBlendFactor dstAlphaBlendFactor;
  VkBlendOp alphaBlendOp;
} VkColorBlendEquationEXT;
#endif

#ifndef VK_DEFINE_NON_DISPATCHABLE_HANDLE
#if defined(__LP64__) || defined(_WIN64)
typedef uint64_t VkShaderEXT;
#else
typedef uint64_t VkShaderEXT;
#endif
#elif !defined(VK_EXT_shader_object)
VK_DEFINE_NON_DISPATCHABLE_HANDLE(VkShaderEXT)
#endif

typedef struct VkPhysicalDeviceDescriptorBufferFeaturesEXT_local {
  VkStructureType sType;
  void* pNext;
  VkBool32 descriptorBuffer;
  VkBool32 descriptorBufferCaptureReplay;
  VkBool32 descriptorBufferImageLayoutIgnored;
  VkBool32 descriptorBufferPushDescriptors;
} VkPhysicalDeviceDescriptorBufferFeaturesEXT_local;

typedef struct VkPhysicalDeviceShaderObjectFeaturesEXT_local {
  VkStructureType sType;
  void* pNext;
  VkBool32 shaderObject;
} VkPhysicalDeviceShaderObjectFeaturesEXT_local;

typedef struct VkPhysicalDeviceHostImageCopyFeaturesEXT_local {
  VkStructureType sType;
  void* pNext;
  VkBool32 hostImageCopy;
} VkPhysicalDeviceHostImageCopyFeaturesEXT_local;

typedef struct VkPhysicalDeviceMeshShaderFeaturesEXT_local {
  VkStructureType sType;
  void* pNext;
  VkBool32 taskShader;
  VkBool32 meshShader;
  VkBool32 multiviewMeshShader;
  VkBool32 primitiveFragmentShadingRateMeshShader;
  VkBool32 meshShaderQueries;
} VkPhysicalDeviceMeshShaderFeaturesEXT_local;

typedef struct VkPhysicalDeviceMaintenance5FeaturesKHR_local {
  VkStructureType sType;
  void* pNext;
  VkBool32 maintenance5;
} VkPhysicalDeviceMaintenance5FeaturesKHR_local;

typedef struct VkPhysicalDeviceBufferDeviceAddressFeatures_local {
  VkStructureType sType;
  void* pNext;
  VkBool32 bufferDeviceAddress;
  VkBool32 bufferDeviceAddressCaptureReplay;
  VkBool32 bufferDeviceAddressMultiDevice;
} VkPhysicalDeviceBufferDeviceAddressFeatures_local;

typedef struct VkPhysicalDeviceExtendedDynamicState3FeaturesEXT_local {
  VkStructureType sType;
  void* pNext;
  VkBool32 extendedDynamicState3TessellationDomainOrigin;
  VkBool32 extendedDynamicState3DepthClampEnable;
  VkBool32 extendedDynamicState3PolygonMode;
  VkBool32 extendedDynamicState3RasterizationSamples;
  VkBool32 extendedDynamicState3SampleMask;
  VkBool32 extendedDynamicState3AlphaToCoverageEnable;
  VkBool32 extendedDynamicState3AlphaToOneEnable;
  VkBool32 extendedDynamicState3LogicOpEnable;
  VkBool32 extendedDynamicState3ColorBlendEnable;
  VkBool32 extendedDynamicState3ColorBlendEquation;
  VkBool32 extendedDynamicState3ColorWriteMask;
} VkPhysicalDeviceExtendedDynamicState3FeaturesEXT_local;

typedef struct VkPhysicalDeviceFeatures2_local {
  VkStructureType sType;
  void* pNext;
  VkPhysicalDeviceFeatures features;
} VkPhysicalDeviceFeatures2_local;

typedef struct VkDescriptorAddressInfoEXT_local {
  VkStructureType sType;
  void* pNext;
  VkDeviceAddress address;
  VkDeviceSize range;
  VkFormat format;
} VkDescriptorAddressInfoEXT_local;

typedef union VkDescriptorDataEXT_local {
  const VkSampler* pSampler;
  const VkDescriptorImageInfo* pCombinedImageSampler;
  const VkDescriptorImageInfo* pInputAttachmentImage;
  const VkDescriptorImageInfo* pSampledImage;
  const VkDescriptorImageInfo* pStorageImage;
  const VkDescriptorAddressInfoEXT_local* pUniformTexelBuffer;
  const VkDescriptorAddressInfoEXT_local* pStorageTexelBuffer;
  const VkDescriptorAddressInfoEXT_local* pUniformBuffer;
  const VkDescriptorAddressInfoEXT_local* pStorageBuffer;
  VkDeviceAddress accelerationStructure;
} VkDescriptorDataEXT_local;

typedef struct VkDescriptorGetInfoEXT_local {
  VkStructureType sType;
  const void* pNext;
  VkDescriptorType type;
  VkDescriptorDataEXT_local data;
} VkDescriptorGetInfoEXT_local;

typedef struct VkDescriptorBufferBindingInfoEXT_local {
  VkStructureType sType;
  void* pNext;
  VkDeviceAddress address;
  VkBufferUsageFlags usage;
} VkDescriptorBufferBindingInfoEXT_local;

typedef struct VkMemoryToImageCopyEXT_local {
  VkStructureType sType;
  const void* pNext;
  const void* pHostPointer;
  uint32_t memoryRowLength;
  uint32_t memoryImageHeight;
  VkImageSubresourceLayers imageSubresource;
  VkOffset3D imageOffset;
  VkExtent3D imageExtent;
} VkMemoryToImageCopyEXT_local;

typedef struct VkCopyMemoryToImageInfoEXT_local {
  VkStructureType sType;
  const void* pNext;
  VkFlags flags;
  VkImage dstImage;
  VkImageLayout dstImageLayout;
  uint32_t regionCount;
  const VkMemoryToImageCopyEXT_local* pRegions;
} VkCopyMemoryToImageInfoEXT_local;

typedef struct VkHostImageLayoutTransitionInfoEXT_local {
  VkStructureType sType;
  const void* pNext;
  VkImage image;
  VkImageLayout oldLayout;
  VkImageLayout newLayout;
  VkImageSubresourceRange subresourceRange;
} VkHostImageLayoutTransitionInfoEXT_local;

typedef struct VkImageSubresource2_local {
  VkStructureType sType;
  const void* pNext;
  VkImageSubresource imageSubresource;
} VkImageSubresource2_local;

typedef struct VkSubresourceLayout2_local {
  VkStructureType sType;
  void* pNext;
  VkSubresourceLayout subresourceLayout;
} VkSubresourceLayout2_local;

typedef struct VkShaderCreateInfoEXT_local {
  VkStructureType sType;
  const void* pNext;
  VkFlags flags;
  VkShaderStageFlagBits stage;
  VkShaderStageFlags nextStage;
  uint32_t codeType;
  size_t codeSize;
  const void* pCode;
  const char* pName;
  uint32_t setLayoutCount;
  const VkDescriptorSetLayout* pSetLayouts;
  uint32_t pushConstantRangeCount;
  const VkPushConstantRange* pPushConstantRanges;
  const VkSpecializationInfo* pSpecializationInfo;
} VkShaderCreateInfoEXT_local;

typedef VkDeviceAddress (VKAPI_PTR *PFN_vkGetBufferDeviceAddress_local)(
    VkDevice device, const VkBufferDeviceAddressInfo* pInfo);
typedef void (VKAPI_PTR *PFN_vkCmdBindDescriptorBuffersEXT_local)(
    VkCommandBuffer commandBuffer, uint32_t bufferCount, const VkDescriptorBufferBindingInfoEXT_local* pBindingInfos);
typedef void (VKAPI_PTR *PFN_vkCmdSetDescriptorBufferOffsetsEXT_local)(
    VkCommandBuffer commandBuffer, VkPipelineBindPoint pipelineBindPoint, VkPipelineLayout layout,
    uint32_t firstSet, uint32_t setCount, const uint32_t* pBufferIndices, const VkDeviceSize* pOffsets);
typedef void (VKAPI_PTR *PFN_vkCmdBindShadersEXT_local)(
    VkCommandBuffer commandBuffer, uint32_t stageCount, const VkShaderStageFlagBits* pStages, const VkShaderEXT* pShaders);
typedef void (VKAPI_PTR *PFN_vkCmdDrawMeshTasksEXT_local)(
    VkCommandBuffer commandBuffer, uint32_t groupCountX, uint32_t groupCountY, uint32_t groupCountZ);
typedef void (VKAPI_PTR *PFN_vkCmdDrawMeshTasksIndirectEXT_local)(
    VkCommandBuffer commandBuffer, VkBuffer buffer, VkDeviceSize offset, uint32_t drawCount, uint32_t stride);
typedef void (VKAPI_PTR *PFN_vkCmdDrawMeshTasksIndirectCountEXT_local)(
    VkCommandBuffer commandBuffer, VkBuffer buffer, VkDeviceSize offset, VkBuffer countBuffer,
    VkDeviceSize countBufferOffset, uint32_t maxDrawCount, uint32_t stride);
typedef void (VKAPI_PTR *PFN_vkCmdSetAlphaToCoverageEnableEXT_local)(VkCommandBuffer commandBuffer, VkBool32 alphaToCoverageEnable);
typedef void (VKAPI_PTR *PFN_vkCmdSetAlphaToOneEnableEXT_local)(VkCommandBuffer commandBuffer, VkBool32 alphaToOneEnable);
typedef void (VKAPI_PTR *PFN_vkCmdSetColorBlendEnableEXT_local)(
    VkCommandBuffer commandBuffer, uint32_t firstAttachment, uint32_t attachmentCount, const VkBool32* pColorBlendEnables);
typedef void (VKAPI_PTR *PFN_vkCmdSetColorBlendEquationEXT_local)(
    VkCommandBuffer commandBuffer, uint32_t firstAttachment, uint32_t attachmentCount, const VkColorBlendEquationEXT* pColorBlendEquations);
typedef void (VKAPI_PTR *PFN_vkCmdSetColorWriteMaskEXT_local)(
    VkCommandBuffer commandBuffer, uint32_t firstAttachment, uint32_t attachmentCount, const VkColorComponentFlags* pColorWriteMasks);
typedef void (VKAPI_PTR *PFN_vkCmdSetDepthClampEnableEXT_local)(VkCommandBuffer commandBuffer, VkBool32 depthClampEnable);
typedef void (VKAPI_PTR *PFN_vkCmdSetLogicOpEnableEXT_local)(VkCommandBuffer commandBuffer, VkBool32 logicOpEnable);
typedef void (VKAPI_PTR *PFN_vkCmdSetPolygonModeEXT_local)(VkCommandBuffer commandBuffer, VkPolygonMode polygonMode);
typedef void (VKAPI_PTR *PFN_vkCmdSetRasterizationSamplesEXT_local)(VkCommandBuffer commandBuffer, VkSampleCountFlagBits rasterizationSamples);
typedef void (VKAPI_PTR *PFN_vkCmdTraceRaysIndirect2KHR_local)(VkCommandBuffer commandBuffer, VkDeviceAddress indirectDeviceAddress);
typedef VkResult (VKAPI_PTR *PFN_vkCopyMemoryToImageEXT_local)(VkDevice device, const VkCopyMemoryToImageInfoEXT_local* pCopyMemoryToImageInfo);
typedef VkResult (VKAPI_PTR *PFN_vkTransitionImageLayoutEXT_local)(
    VkDevice device, uint32_t transitionCount, const VkHostImageLayoutTransitionInfoEXT_local* pTransitions);
typedef VkResult (VKAPI_PTR *PFN_vkCreateShadersEXT_local)(
    VkDevice device, uint32_t createInfoCount, const VkShaderCreateInfoEXT_local* pCreateInfos,
    const VkAllocationCallbacks* pAllocator, VkShaderEXT* pShaders);
typedef void (VKAPI_PTR *PFN_vkDestroyShaderEXT_local)(VkDevice device, VkShaderEXT shader, const VkAllocationCallbacks* pAllocator);
typedef void (VKAPI_PTR *PFN_vkGetDescriptorEXT_local)(
    VkDevice device, const VkDescriptorGetInfoEXT_local* pDescriptorInfo, size_t dataSize, void* pDescriptor);
typedef VkResult (VKAPI_PTR *PFN_vkGetShaderBinaryDataEXT_local)(
    VkDevice device, VkShaderEXT shader, size_t* pDataSize, void* pData);
typedef void (VKAPI_PTR *PFN_vkGetImageSubresourceLayout2_local)(
    VkDevice device, VkImage image, const VkImageSubresource2_local* pSubresource, VkSubresourceLayout2_local* pLayout);
typedef void (VKAPI_PTR *PFN_vkGetDescriptorSetLayoutSizeEXT_local)(
    VkDevice device, VkDescriptorSetLayout layout, VkDeviceSize* pLayoutSizeInBytes);
typedef void (VKAPI_PTR *PFN_vkGetDescriptorSetLayoutBindingOffsetEXT_local)(
    VkDevice device, VkDescriptorSetLayout layout, uint32_t binding, VkDeviceSize* pOffset);

typedef struct ApiResult {
  const char* name;
  int looked_up;
  int called;
  long long rc;
} ApiResult;

static int find_map_line(uintptr_t addr, char* out, size_t out_sz, int* readable) {
  FILE* f = fopen("/proc/self/maps", "r");
  if (!f) return 0;
  char line[1024];
  while (fgets(line, sizeof(line), f)) {
    unsigned long long lo = 0, hi = 0;
    char perms[8] = {0};
    if (sscanf(line, "%llx-%llx %7s", &lo, &hi, perms) != 3) continue;
    if (addr >= (uintptr_t)lo && addr < (uintptr_t)hi) {
      if (out && out_sz) {
        size_t n = strlen(line);
        if (n >= out_sz) n = out_sz - 1;
        memcpy(out, line, n);
        out[n] = '\0';
      }
      if (readable) *readable = (perms[0] == 'r');
      fclose(f);
      return 1;
    }
  }
  fclose(f);
  return 0;
}

static void dump_bytes_if_readable(const char* tag, const void* p, size_t n) {
  uintptr_t a = (uintptr_t)p;
  char mline[1024];
  int rd = 0;
  if (!p) {
    printf("DBG %s ptr=%p map=<null>\n", tag, p);
    return;
  }
  if (!find_map_line(a, mline, sizeof(mline), &rd)) {
    printf("DBG %s ptr=%p map=<not_mapped>\n", tag, p);
    return;
  }
  printf("DBG %s ptr=%p map=%s", tag, p, mline);
  if (!rd) {
    printf("DBG %s bytes=<not_readable>\n", tag);
    return;
  }
  const unsigned char* s = (const unsigned char*)p;
  for (size_t i = 0; i < n; i += 16) {
    size_t chunk = (n - i > 16) ? 16 : (n - i);
    printf("DBG %s bytes+0x%zx", tag, i);
    for (size_t j = 0; j < chunk; ++j) printf(" %02x", s[i + j]);
    printf("\n");
  }
}

static int has_ext(const char* name, const VkExtensionProperties* exts, uint32_t count) {
  for (uint32_t i = 0; i < count; ++i) {
    if (strcmp(name, exts[i].extensionName) == 0) return 1;
  }
  return 0;
}

static void print_api_result(const ApiResult* r) {
  printf("%s lookup=%s called=%s rc=%lld\n", r->name, r->looked_up ? "yes" : "no",
         r->called ? "yes" : "no", r->rc);
}

static PFN_vkVoidFunction get_any_proc(VkInstance instance, VkDevice dev, const char* name) {
  PFN_vkVoidFunction p = vkGetDeviceProcAddr(dev, name);
  if (p) {
    printf("DBG lookup %s via GDPA -> %p\n", name, (void*)p);
    return p;
  }
  p = vkGetInstanceProcAddr(instance, name);
  printf("DBG lookup %s via GIPA -> %p\n", name, (void*)p);
  return p;
}

static int run_enabled(const char* only, const char* api) {
  if (!only || !*only) return 1;
  return strcmp(only, api) == 0;
}

int main(int argc, char** argv) {
  setvbuf(stdout, NULL, _IONBF, 0);
  const char* only = NULL;
  if (argc >= 3 && strcmp(argv[1], "--only") == 0) {
    only = argv[2];
  } else {
    only = getenv("TEST44_ONLY");
  }

  ApiResult r[27] = {
      {"vkCmdBindDescriptorBuffersEXT", 0, 0, -1},
      {"vkCmdBindShadersEXT", 0, 0, -1},
      {"vkCmdDrawMeshTasksEXT", 0, 0, -1},
      {"vkCmdDrawMeshTasksIndirectCountEXT", 0, 0, -1},
      {"vkCmdDrawMeshTasksIndirectEXT", 0, 0, -1},
      {"vkCmdSetAlphaToCoverageEnableEXT", 0, 0, -1},
      {"vkCmdSetAlphaToOneEnableEXT", 0, 0, -1},
      {"vkCmdSetColorBlendEnableEXT", 0, 0, -1},
      {"vkCmdSetColorBlendEquationEXT", 0, 0, -1},
      {"vkCmdSetColorWriteMaskEXT", 0, 0, -1},
      {"vkCmdSetDepthClampEnableEXT", 0, 0, -1},
      {"vkCmdSetDescriptorBufferOffsetsEXT", 0, 0, -1},
      {"vkCmdSetLogicOpEnableEXT", 0, 0, -1},
      {"vkCmdSetPolygonModeEXT", 0, 0, -1},
      {"vkCmdSetRasterizationSamplesEXT", 0, 0, -1},
      {"vkCmdTraceRaysIndirect2KHR", 0, 0, -1},
      {"vkCopyMemoryToImageEXT", 0, 0, -1},
      {"vkCreateShadersEXT", 0, 0, -1},
      {"vkDestroyShaderEXT", 0, 0, -1},
      {"vkGetDescriptorEXT", 0, 0, -1},
      {"vkGetDescriptorSetLayoutBindingOffsetEXT", 0, 0, -1},
      {"vkGetDescriptorSetLayoutSizeEXT", 0, 0, -1},
      {"vkGetImageSubresourceLayout2EXT", 0, 0, -1},
      {"vkGetImageSubresourceLayout2KHR", 0, 0, -1},
      {"vkGetShaderBinaryDataEXT", 0, 0, -1},
      {"vkTransitionImageLayoutEXT", 0, 0, -1},
      {"vkTransitionImageLayoutEXT#2", 0, 0, -1},
  };

  VkApplicationInfo app = {0};
  app.sType = VK_STRUCTURE_TYPE_APPLICATION_INFO;
  app.pApplicationName = "call_27_apis";
  app.apiVersion = VK_API_VERSION_1_2;

  VkInstanceCreateInfo ici = {0};
  ici.sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
  ici.pApplicationInfo = &app;

  VkInstance instance = VK_NULL_HANDLE;
  VkResult vr = vkCreateInstance(&ici, NULL, &instance);
  if (vr != VK_SUCCESS) {
    printf("FAIL vkCreateInstance=%d\n", (int)vr);
    return 2;
  }

  uint32_t gpu_count = 0;
  vr = vkEnumeratePhysicalDevices(instance, &gpu_count, NULL);
  if (vr != VK_SUCCESS || gpu_count == 0) {
    printf("FAIL vkEnumeratePhysicalDevices r=%d count=%u\n", (int)vr, gpu_count);
    vkDestroyInstance(instance, NULL);
    return 3;
  }
  VkPhysicalDevice gpu = VK_NULL_HANDLE;
  vkEnumeratePhysicalDevices(instance, &gpu_count, &gpu);

  uint32_t ext_count = 0;
  vkEnumerateDeviceExtensionProperties(gpu, NULL, &ext_count, NULL);
  VkExtensionProperties* exts = (VkExtensionProperties*)calloc(ext_count ? ext_count : 1, sizeof(VkExtensionProperties));
  if (ext_count) vkEnumerateDeviceExtensionProperties(gpu, NULL, &ext_count, exts);

  const char* want_exts[] = {
      VK_EXT_DESCRIPTOR_BUFFER_EXTENSION_NAME,
      VK_EXT_SHADER_OBJECT_EXTENSION_NAME,
      VK_EXT_HOST_IMAGE_COPY_EXTENSION_NAME,
      VK_EXT_MESH_SHADER_EXTENSION_NAME,
      VK_KHR_MAINTENANCE_5_EXTENSION_NAME,
      VK_KHR_BUFFER_DEVICE_ADDRESS_EXTENSION_NAME,
  };
  const size_t want_n = sizeof(want_exts) / sizeof(want_exts[0]);
  const char* enable_exts[16];
  uint32_t enable_n = 0;
  for (size_t i = 0; i < want_n; ++i) {
    if (has_ext(want_exts[i], exts, ext_count)) enable_exts[enable_n++] = want_exts[i];
  }
  int has_desc = has_ext(VK_EXT_DESCRIPTOR_BUFFER_EXTENSION_NAME, exts, ext_count);
  int has_shader_obj = has_ext(VK_EXT_SHADER_OBJECT_EXTENSION_NAME, exts, ext_count);
  int has_host_copy = has_ext(VK_EXT_HOST_IMAGE_COPY_EXTENSION_NAME, exts, ext_count);
  int has_mesh = has_ext(VK_EXT_MESH_SHADER_EXTENSION_NAME, exts, ext_count);
  int has_m5 = has_ext(VK_KHR_MAINTENANCE_5_EXTENSION_NAME, exts, ext_count);
  int has_dyn3 = has_ext("VK_EXT_extended_dynamic_state3", exts, ext_count);
  int has_rt_ind2 = has_ext("VK_KHR_ray_tracing_maintenance1", exts, ext_count);

  VkPhysicalDeviceDescriptorBufferFeaturesEXT_local f_desc = {
      .sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_DESCRIPTOR_BUFFER_FEATURES_EXT,
  };
  VkPhysicalDeviceShaderObjectFeaturesEXT_local f_shader = {
      .sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SHADER_OBJECT_FEATURES_EXT,
  };
  VkPhysicalDeviceHostImageCopyFeaturesEXT_local f_hostcopy = {
      .sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_HOST_IMAGE_COPY_FEATURES_EXT,
  };
  VkPhysicalDeviceMeshShaderFeaturesEXT_local f_mesh = {
      .sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_MESH_SHADER_FEATURES_EXT,
  };
  VkPhysicalDeviceMaintenance5FeaturesKHR_local f_m5 = {
      .sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_MAINTENANCE_5_FEATURES_KHR,
  };
  VkPhysicalDeviceBufferDeviceAddressFeatures_local f_bda = {
      .sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_BUFFER_DEVICE_ADDRESS_FEATURES,
  };
  VkPhysicalDeviceExtendedDynamicState3FeaturesEXT_local f_dyn3 = {
      .sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_EXTENDED_DYNAMIC_STATE_3_FEATURES_EXT,
  };
  VkPhysicalDeviceFeatures2_local f2 = {
      .sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FEATURES_2,
      .pNext = &f_desc,
  };
  f_desc.pNext = &f_shader;
  f_shader.pNext = &f_hostcopy;
  f_hostcopy.pNext = &f_mesh;
  f_mesh.pNext = &f_m5;
  f_m5.pNext = &f_bda;
  f_bda.pNext = &f_dyn3;
  f_dyn3.pNext = NULL;

  PFN_vkVoidFunction p_gpdf2 = vkGetInstanceProcAddr(instance, "vkGetPhysicalDeviceFeatures2");
  if (p_gpdf2) {
    typedef void (VKAPI_PTR *PFN_vkGetPhysicalDeviceFeatures2_local)(VkPhysicalDevice, VkPhysicalDeviceFeatures2_local*);
    ((PFN_vkGetPhysicalDeviceFeatures2_local)p_gpdf2)(gpu, &f2);
  }
  has_desc = has_desc && (f_desc.descriptorBuffer != VK_FALSE);
  has_shader_obj = has_shader_obj && (f_shader.shaderObject != VK_FALSE);
  has_host_copy = has_host_copy && (f_hostcopy.hostImageCopy != VK_FALSE);
  has_mesh = has_mesh && (f_mesh.meshShader != VK_FALSE);
  has_m5 = has_m5 && (f_m5.maintenance5 != VK_FALSE);
  int has_dyn3_cb_enable = has_dyn3 && (f_dyn3.extendedDynamicState3ColorBlendEnable != VK_FALSE);
  int has_dyn3_cb_equation = has_dyn3 && (f_dyn3.extendedDynamicState3ColorBlendEquation != VK_FALSE);
  int has_dyn3_cwm = has_dyn3 && (f_dyn3.extendedDynamicState3ColorWriteMask != VK_FALSE);

  uint32_t qcount = 0;
  vkGetPhysicalDeviceQueueFamilyProperties(gpu, &qcount, NULL);
  VkQueueFamilyProperties* qprops = (VkQueueFamilyProperties*)calloc(qcount ? qcount : 1, sizeof(VkQueueFamilyProperties));
  vkGetPhysicalDeviceQueueFamilyProperties(gpu, &qcount, qprops);
  uint32_t qfi = 0;
  for (uint32_t i = 0; i < qcount; ++i) {
    if (qprops[i].queueCount > 0) {
      qfi = i;
      break;
    }
  }
  free(qprops);

  float pri = 1.0f;
  VkDeviceQueueCreateInfo qci = {0};
  qci.sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
  qci.queueFamilyIndex = qfi;
  qci.queueCount = 1;
  qci.pQueuePriorities = &pri;

  VkDeviceCreateInfo dci = {0};
  dci.sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
  dci.pNext = &f2;
  dci.queueCreateInfoCount = 1;
  dci.pQueueCreateInfos = &qci;
  dci.enabledExtensionCount = enable_n;
  dci.ppEnabledExtensionNames = enable_exts;

  VkDevice dev = VK_NULL_HANDLE;
  vr = vkCreateDevice(gpu, &dci, NULL, &dev);
  if (vr != VK_SUCCESS) {
    printf("FAIL vkCreateDevice=%d\n", (int)vr);
    free(exts);
    vkDestroyInstance(instance, NULL);
    return 4;
  }
  free(exts);

  VkCommandPool pool = VK_NULL_HANDLE;
  VkCommandPoolCreateInfo pci = {0};
  pci.sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO;
  pci.queueFamilyIndex = qfi;
  vkCreateCommandPool(dev, &pci, NULL, &pool);

  VkCommandBuffer cb = VK_NULL_HANDLE;
  VkCommandBufferAllocateInfo cai = {0};
  cai.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
  cai.commandPool = pool;
  cai.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
  cai.commandBufferCount = 1;
  vkAllocateCommandBuffers(dev, &cai, &cb);
  VkCommandBufferBeginInfo cbi = {0};
  cbi.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
  vkBeginCommandBuffer(cb, &cbi);

  VkBuffer buf = VK_NULL_HANDLE;
  VkDeviceMemory buf_mem = VK_NULL_HANDLE;
  VkBufferCreateInfo bci = {0};
  bci.sType = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO;
  bci.size = 4096;
  bci.usage = VK_BUFFER_USAGE_INDIRECT_BUFFER_BIT | VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT |
              VK_BUFFER_USAGE_RESOURCE_DESCRIPTOR_BUFFER_BIT_EXT;
  vkCreateBuffer(dev, &bci, NULL, &buf);
  VkMemoryRequirements breq;
  vkGetBufferMemoryRequirements(dev, buf, &breq);
  uint32_t bmt = 0;
  if (find_memory_type_index(gpu, breq.memoryTypeBits,
                             VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT, &bmt) == 0) {
    VkMemoryAllocateFlagsInfo maf = {0};
    maf.sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_FLAGS_INFO;
    maf.flags = VK_MEMORY_ALLOCATE_DEVICE_ADDRESS_BIT;
    VkMemoryAllocateInfo mai = {0};
    mai.sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
    mai.pNext = &maf;
    mai.allocationSize = breq.size;
    mai.memoryTypeIndex = bmt;
    if (vkAllocateMemory(dev, &mai, NULL, &buf_mem) == VK_SUCCESS) {
      vkBindBufferMemory(dev, buf, buf_mem, 0);
    }
  }

  VkDeviceAddress buf_addr = 0;
  PFN_vkGetBufferDeviceAddress_local p_get_bda =
      (PFN_vkGetBufferDeviceAddress_local)vkGetDeviceProcAddr(dev, "vkGetBufferDeviceAddress");
  if (p_get_bda && buf != VK_NULL_HANDLE) {
    VkBufferDeviceAddressInfo bai = {0};
    bai.sType = VK_STRUCTURE_TYPE_BUFFER_DEVICE_ADDRESS_INFO;
    bai.buffer = buf;
    buf_addr = p_get_bda(dev, &bai);
  }

  VkDescriptorSetLayout dsl = VK_NULL_HANDLE;
  VkDescriptorSetLayoutBinding bind = {0};
  bind.binding = 0;
  bind.descriptorType = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER;
  bind.descriptorCount = 1;
  bind.stageFlags = VK_SHADER_STAGE_VERTEX_BIT;
  VkDescriptorSetLayoutCreateInfo dsl_ci = {0};
  dsl_ci.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO;
  dsl_ci.bindingCount = 1;
  dsl_ci.pBindings = &bind;
  vkCreateDescriptorSetLayout(dev, &dsl_ci, NULL, &dsl);

  VkPipelineLayout pl = VK_NULL_HANDLE;
  VkPipelineLayoutCreateInfo plci = {0};
  plci.sType = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO;
  plci.setLayoutCount = 1;
  plci.pSetLayouts = &dsl;
  vkCreatePipelineLayout(dev, &plci, NULL, &pl);

  VkImage img = VK_NULL_HANDLE;
  VkDeviceMemory img_mem = VK_NULL_HANDLE;
  VkImageCreateInfo ici2 = {0};
  ici2.sType = VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO;
  ici2.imageType = VK_IMAGE_TYPE_2D;
  ici2.format = VK_FORMAT_R8G8B8A8_UNORM;
  ici2.extent.width = 16;
  ici2.extent.height = 16;
  ici2.extent.depth = 1;
  ici2.mipLevels = 1;
  ici2.arrayLayers = 1;
  ici2.samples = VK_SAMPLE_COUNT_1_BIT;
  ici2.tiling = VK_IMAGE_TILING_LINEAR;
  ici2.usage = VK_IMAGE_USAGE_TRANSFER_DST_BIT | VK_IMAGE_USAGE_TRANSFER_SRC_BIT | VK_IMAGE_USAGE_HOST_TRANSFER_BIT_EXT;
  ici2.initialLayout = VK_IMAGE_LAYOUT_PREINITIALIZED;
  vkCreateImage(dev, &ici2, NULL, &img);
  VkMemoryRequirements ireq;
  vkGetImageMemoryRequirements(dev, img, &ireq);
  uint32_t imt = 0;
  if (find_memory_type_index(gpu, ireq.memoryTypeBits,
                             VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT, &imt) == 0) {
    VkMemoryAllocateInfo imai = {0};
    imai.sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
    imai.allocationSize = ireq.size;
    imai.memoryTypeIndex = imt;
    if (vkAllocateMemory(dev, &imai, NULL, &img_mem) == VK_SUCCESS) {
      vkBindImageMemory(dev, img, img_mem, 0);
    }
  }

  PFN_vkCmdBindDescriptorBuffersEXT_local fn_bind_desc_buf =
      (PFN_vkCmdBindDescriptorBuffersEXT_local)get_any_proc(instance, dev, r[0].name);
  PFN_vkCmdBindShadersEXT_local fn_bind_shaders =
      (PFN_vkCmdBindShadersEXT_local)get_any_proc(instance, dev, r[1].name);
  if (fn_bind_shaders) {
    Dl_info inf = {0};
    if (dladdr((void*)fn_bind_shaders, &inf) && inf.dli_fname) {
      printf("DBG bindshaders fn=%p owner=%s sym=%s\n",
             (void*)fn_bind_shaders,
             inf.dli_fname,
             inf.dli_sname ? inf.dli_sname : "<null>");
    } else {
      printf("DBG bindshaders fn=%p owner=<dladdr failed>\n", (void*)fn_bind_shaders);
    }
  }
  PFN_vkCmdDrawMeshTasksEXT_local fn_draw_mesh =
      (PFN_vkCmdDrawMeshTasksEXT_local)get_any_proc(instance, dev, r[2].name);
  PFN_vkCmdDrawMeshTasksIndirectCountEXT_local fn_draw_mesh_ind_count =
      (PFN_vkCmdDrawMeshTasksIndirectCountEXT_local)get_any_proc(instance, dev, r[3].name);
  PFN_vkCmdDrawMeshTasksIndirectEXT_local fn_draw_mesh_ind =
      (PFN_vkCmdDrawMeshTasksIndirectEXT_local)get_any_proc(instance, dev, r[4].name);
  PFN_vkCmdSetAlphaToCoverageEnableEXT_local fn_a2c =
      (PFN_vkCmdSetAlphaToCoverageEnableEXT_local)get_any_proc(instance, dev, r[5].name);
  PFN_vkCmdSetAlphaToOneEnableEXT_local fn_a2o =
      (PFN_vkCmdSetAlphaToOneEnableEXT_local)get_any_proc(instance, dev, r[6].name);
  PFN_vkCmdSetColorBlendEnableEXT_local fn_cb_en =
      (PFN_vkCmdSetColorBlendEnableEXT_local)get_any_proc(instance, dev, r[7].name);
  PFN_vkCmdSetColorBlendEquationEXT_local fn_cb_eq =
      (PFN_vkCmdSetColorBlendEquationEXT_local)get_any_proc(instance, dev, r[8].name);
  PFN_vkCmdSetColorWriteMaskEXT_local fn_cwm =
      (PFN_vkCmdSetColorWriteMaskEXT_local)get_any_proc(instance, dev, r[9].name);
  PFN_vkCmdSetDepthClampEnableEXT_local fn_dce =
      (PFN_vkCmdSetDepthClampEnableEXT_local)get_any_proc(instance, dev, r[10].name);
  PFN_vkCmdSetDescriptorBufferOffsetsEXT_local fn_desc_off =
      (PFN_vkCmdSetDescriptorBufferOffsetsEXT_local)get_any_proc(instance, dev, r[11].name);
  PFN_vkCmdSetLogicOpEnableEXT_local fn_logic =
      (PFN_vkCmdSetLogicOpEnableEXT_local)get_any_proc(instance, dev, r[12].name);
  PFN_vkCmdSetPolygonModeEXT_local fn_poly =
      (PFN_vkCmdSetPolygonModeEXT_local)get_any_proc(instance, dev, r[13].name);
  PFN_vkCmdSetRasterizationSamplesEXT_local fn_rs =
      (PFN_vkCmdSetRasterizationSamplesEXT_local)get_any_proc(instance, dev, r[14].name);
  PFN_vkCmdTraceRaysIndirect2KHR_local fn_trace =
      (PFN_vkCmdTraceRaysIndirect2KHR_local)get_any_proc(instance, dev, r[15].name);
  PFN_vkCopyMemoryToImageEXT_local fn_copy =
      (PFN_vkCopyMemoryToImageEXT_local)get_any_proc(instance, dev, r[16].name);
  PFN_vkCreateShadersEXT_local fn_create_sh =
      (PFN_vkCreateShadersEXT_local)get_any_proc(instance, dev, r[17].name);
  PFN_vkDestroyShaderEXT_local fn_destroy_sh =
      (PFN_vkDestroyShaderEXT_local)get_any_proc(instance, dev, r[18].name);
  PFN_vkGetDescriptorEXT_local fn_get_desc =
      (PFN_vkGetDescriptorEXT_local)get_any_proc(instance, dev, r[19].name);
  PFN_vkGetDescriptorSetLayoutBindingOffsetEXT_local fn_get_off =
      (PFN_vkGetDescriptorSetLayoutBindingOffsetEXT_local)get_any_proc(instance, dev, r[20].name);
  PFN_vkGetDescriptorSetLayoutSizeEXT_local fn_get_sz =
      (PFN_vkGetDescriptorSetLayoutSizeEXT_local)get_any_proc(instance, dev, r[21].name);
  PFN_vkGetImageSubresourceLayout2_local fn_get_isl2_ext =
      (PFN_vkGetImageSubresourceLayout2_local)get_any_proc(instance, dev, r[22].name);
  PFN_vkGetImageSubresourceLayout2_local fn_get_isl2_khr =
      (PFN_vkGetImageSubresourceLayout2_local)get_any_proc(instance, dev, r[23].name);
  PFN_vkGetShaderBinaryDataEXT_local fn_get_shbin =
      (PFN_vkGetShaderBinaryDataEXT_local)get_any_proc(instance, dev, r[24].name);
  PFN_vkTransitionImageLayoutEXT_local fn_trans =
      (PFN_vkTransitionImageLayoutEXT_local)get_any_proc(instance, dev, r[25].name);

  for (int i = 0; i < 26; ++i) r[i].looked_up = 1;
  r[26].looked_up = 1;

  if (fn_bind_desc_buf && has_desc && run_enabled(only, "vkCmdBindDescriptorBuffersEXT")) {
    puts("STEP call vkCmdBindDescriptorBuffersEXT");
    VkDescriptorBufferBindingInfoEXT_local bi = {0};
    bi.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_BUFFER_BINDING_INFO_EXT;
    bi.address = buf_addr;
    bi.usage = VK_BUFFER_USAGE_RESOURCE_DESCRIPTOR_BUFFER_BIT_EXT;
    fn_bind_desc_buf(cb, 1, &bi);
    r[0].called = 1;
    r[0].rc = 0;
    puts("STEP ok vkCmdBindDescriptorBuffersEXT");
  }
  if (fn_bind_shaders && has_shader_obj && run_enabled(only, "vkCmdBindShadersEXT")) {
    puts("STEP call vkCmdBindShadersEXT");
    VkShaderStageFlagBits stages_local[1] = {VK_SHADER_STAGE_VERTEX_BIT};
    VkShaderEXT shaders_local[1] = {(VkShaderEXT)0};
    VkShaderStageFlagBits* stages = stages_local;
    VkShaderEXT* shaders = shaders_local;
    uint32_t stage_count = 1;
    dump_bytes_if_readable("bindshaders_fn", (const void*)fn_bind_shaders, 16);
    dump_bytes_if_readable("bindshaders_cb_pre", (const void*)cb, 64);
    dump_bytes_if_readable("bindshaders_stages", (const void*)stages, 16);
    dump_bytes_if_readable("bindshaders_shaders", (const void*)shaders, 16);
    for (uint32_t i = 0; i < stage_count; ++i) {
      if (shaders[i] != 0) {
        char tag[64];
        snprintf(tag, sizeof(tag), "bindshaders_shader%u_ptr", i);
        dump_bytes_if_readable(tag, (const void*)(uintptr_t)shaders[i], 64);
      } else {
        printf("DBG bindshaders_shader%u_ptr=<null>\n", i);
      }
    }
    printf("DBG call vkCmdBindShadersEXT cb=%p stageCount=%u stages_ptr=%p shaders_ptr=%p stage0=0x%x shader0=0x%llx\n",
           (void*)cb,
           stage_count,
           (void*)stages,
           (void*)shaders,
           (unsigned)(stage_count ? stages[0] : 0u),
           (unsigned long long)(stage_count ? shaders[0] : 0ull));
    fn_bind_shaders(cb, stage_count, stages, shaders);
    dump_bytes_if_readable("bindshaders_cb_post", (const void*)cb, 64);
    r[1].called = 1;
    r[1].rc = 0;
    puts("STEP ok vkCmdBindShadersEXT");
  }
  if (fn_draw_mesh && run_enabled(only, "vkCmdDrawMeshTasksEXT")) {
    puts("STEP call vkCmdDrawMeshTasksEXT");
    fn_draw_mesh(cb, 0, 0, 0);
    r[2].called = 1;
    r[2].rc = 0;
    puts("STEP ok vkCmdDrawMeshTasksEXT");
  }
  if (fn_draw_mesh_ind_count && run_enabled(only, "vkCmdDrawMeshTasksIndirectCountEXT")) {
    puts("STEP call vkCmdDrawMeshTasksIndirectCountEXT");
    fn_draw_mesh_ind_count(cb, buf, 0, buf, 0, 0, sizeof(uint32_t) * 4);
    r[3].called = 1;
    r[3].rc = 0;
    puts("STEP ok vkCmdDrawMeshTasksIndirectCountEXT");
  }
  if (fn_draw_mesh_ind && run_enabled(only, "vkCmdDrawMeshTasksIndirectEXT")) {
    puts("STEP call vkCmdDrawMeshTasksIndirectEXT");
    fn_draw_mesh_ind(cb, buf, 0, 0, sizeof(uint32_t) * 4);
    r[4].called = 1;
    r[4].rc = 0;
    puts("STEP ok vkCmdDrawMeshTasksIndirectEXT");
  }
  if (fn_a2c && run_enabled(only, "vkCmdSetAlphaToCoverageEnableEXT")) {
    puts("STEP call vkCmdSetAlphaToCoverageEnableEXT");
    fn_a2c(cb, VK_FALSE);
    r[5].called = 1;
    r[5].rc = 0;
    puts("STEP ok vkCmdSetAlphaToCoverageEnableEXT");
  }
  if (fn_a2o && run_enabled(only, "vkCmdSetAlphaToOneEnableEXT")) {
    puts("STEP call vkCmdSetAlphaToOneEnableEXT");
    fn_a2o(cb, VK_FALSE);
    r[6].called = 1;
    r[6].rc = 0;
    puts("STEP ok vkCmdSetAlphaToOneEnableEXT");
  }
  if (fn_cb_en && has_dyn3_cb_enable && run_enabled(only, "vkCmdSetColorBlendEnableEXT")) {
    puts("STEP call vkCmdSetColorBlendEnableEXT");
    fn_cb_en(cb, 0, 0, NULL);
    r[7].called = 1;
    r[7].rc = 0;
    puts("STEP ok vkCmdSetColorBlendEnableEXT");
  }
  if (fn_cb_eq && has_dyn3_cb_equation && run_enabled(only, "vkCmdSetColorBlendEquationEXT")) {
    puts("STEP call vkCmdSetColorBlendEquationEXT");
    fn_cb_eq(cb, 0, 0, NULL);
    r[8].called = 1;
    r[8].rc = 0;
    puts("STEP ok vkCmdSetColorBlendEquationEXT");
  }
  if (fn_cwm && has_dyn3_cwm && run_enabled(only, "vkCmdSetColorWriteMaskEXT")) {
    puts("STEP call vkCmdSetColorWriteMaskEXT");
    fn_cwm(cb, 0, 0, NULL);
    r[9].called = 1;
    r[9].rc = 0;
    puts("STEP ok vkCmdSetColorWriteMaskEXT");
  }
  if (fn_dce && run_enabled(only, "vkCmdSetDepthClampEnableEXT")) {
    puts("STEP call vkCmdSetDepthClampEnableEXT");
    fn_dce(cb, VK_FALSE);
    r[10].called = 1;
    r[10].rc = 0;
    puts("STEP ok vkCmdSetDepthClampEnableEXT");
  }
  if (fn_desc_off && has_desc && run_enabled(only, "vkCmdSetDescriptorBufferOffsetsEXT")) {
    puts("STEP call vkCmdSetDescriptorBufferOffsetsEXT");
    fn_desc_off(cb, VK_PIPELINE_BIND_POINT_GRAPHICS, pl, 0, 0, NULL, NULL);
    r[11].called = 1;
    r[11].rc = 0;
    puts("STEP ok vkCmdSetDescriptorBufferOffsetsEXT");
  }
  if (fn_logic && run_enabled(only, "vkCmdSetLogicOpEnableEXT")) {
    puts("STEP call vkCmdSetLogicOpEnableEXT");
    fn_logic(cb, VK_FALSE);
    r[12].called = 1;
    r[12].rc = 0;
    puts("STEP ok vkCmdSetLogicOpEnableEXT");
  }
  if (fn_poly && run_enabled(only, "vkCmdSetPolygonModeEXT")) {
    puts("STEP call vkCmdSetPolygonModeEXT");
    fn_poly(cb, VK_POLYGON_MODE_FILL);
    r[13].called = 1;
    r[13].rc = 0;
    puts("STEP ok vkCmdSetPolygonModeEXT");
  }
  if (fn_rs && run_enabled(only, "vkCmdSetRasterizationSamplesEXT")) {
    puts("STEP call vkCmdSetRasterizationSamplesEXT");
    fn_rs(cb, VK_SAMPLE_COUNT_1_BIT);
    r[14].called = 1;
    r[14].rc = 0;
    puts("STEP ok vkCmdSetRasterizationSamplesEXT");
  }
  if (fn_trace && has_rt_ind2 && run_enabled(only, "vkCmdTraceRaysIndirect2KHR")) {
    r[15].called = 0;
    r[15].rc = -2;
  }

  unsigned char host_img[16 * 16 * 4];
  memset(host_img, 0x7f, sizeof(host_img));
  if (fn_copy && has_host_copy && img != VK_NULL_HANDLE && run_enabled(only, "vkCopyMemoryToImageEXT")) {
    puts("STEP call vkCopyMemoryToImageEXT");
    VkMemoryToImageCopyEXT_local region = {0};
    region.sType = VK_STRUCTURE_TYPE_MEMORY_TO_IMAGE_COPY_EXT;
    region.pHostPointer = host_img;
    region.memoryRowLength = 16;
    region.memoryImageHeight = 16;
    region.imageSubresource.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
    region.imageSubresource.mipLevel = 0;
    region.imageSubresource.baseArrayLayer = 0;
    region.imageSubresource.layerCount = 1;
    region.imageOffset = (VkOffset3D){0, 0, 0};
    region.imageExtent = (VkExtent3D){16, 16, 1};

    VkCopyMemoryToImageInfoEXT_local info = {0};
    info.sType = VK_STRUCTURE_TYPE_COPY_MEMORY_TO_IMAGE_INFO_EXT;
    info.dstImage = img;
    info.dstImageLayout = VK_IMAGE_LAYOUT_GENERAL;
    info.regionCount = 1;
    info.pRegions = &region;
    r[16].rc = fn_copy(dev, &info);
    r[16].called = 1;
    puts("STEP ok vkCopyMemoryToImageEXT");
  }

  VkShaderEXT shader = (VkShaderEXT)0;
  if (fn_create_sh && has_shader_obj && run_enabled(only, "vkCreateShadersEXT")) {
    puts("STEP call vkCreateShadersEXT");
    r[17].rc = fn_create_sh(dev, 0, NULL, NULL, NULL);
    r[17].called = 1;
    puts("STEP ok vkCreateShadersEXT");
  }

  if (fn_destroy_sh && has_shader_obj && run_enabled(only, "vkDestroyShaderEXT")) {
    puts("STEP call vkDestroyShaderEXT");
    fn_destroy_sh(dev, shader, NULL);
    r[18].called = 1;
    r[18].rc = 0;
    puts("STEP ok vkDestroyShaderEXT");
  }

  if (fn_get_desc && has_desc && run_enabled(only, "vkGetDescriptorEXT")) {
    puts("STEP call vkGetDescriptorEXT");
    VkSampler sampler = VK_NULL_HANDLE;
    VkSamplerCreateInfo sci = {0};
    sci.sType = VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO;
    sci.magFilter = VK_FILTER_NEAREST;
    sci.minFilter = VK_FILTER_NEAREST;
    sci.mipmapMode = VK_SAMPLER_MIPMAP_MODE_NEAREST;
    sci.addressModeU = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
    sci.addressModeV = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
    sci.addressModeW = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
    if (vkCreateSampler(dev, &sci, NULL, &sampler) == VK_SUCCESS) {
      VkDescriptorGetInfoEXT_local gi = {0};
      gi.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_GET_INFO_EXT;
      gi.type = VK_DESCRIPTOR_TYPE_SAMPLER;
      gi.data.pSampler = &sampler;
      fn_get_desc(dev, &gi, 0, NULL);
      r[19].called = 1;
      r[19].rc = 0;
      vkDestroySampler(dev, sampler, NULL);
    }
    puts("STEP ok vkGetDescriptorEXT");
  }

  if (fn_get_off && has_desc && run_enabled(only, "vkGetDescriptorSetLayoutBindingOffsetEXT")) {
    puts("STEP call vkGetDescriptorSetLayoutBindingOffsetEXT");
    VkDeviceSize off = 0;
    fn_get_off(dev, VK_NULL_HANDLE, 0, &off);
    r[20].called = 1;
    r[20].rc = (long long)off;
    puts("STEP ok vkGetDescriptorSetLayoutBindingOffsetEXT");
  }
  if (fn_get_sz && has_desc && run_enabled(only, "vkGetDescriptorSetLayoutSizeEXT")) {
    puts("STEP call vkGetDescriptorSetLayoutSizeEXT");
    VkDeviceSize sz = 0;
    fn_get_sz(dev, VK_NULL_HANDLE, &sz);
    r[21].called = 1;
    r[21].rc = (long long)sz;
    puts("STEP ok vkGetDescriptorSetLayoutSizeEXT");
  }

  VkImageSubresource2_local is2 = {0};
  is2.sType = (VkStructureType)1000338000;
  is2.imageSubresource.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
  is2.imageSubresource.arrayLayer = 0;
  VkSubresourceLayout2_local sl2 = {0};
  sl2.sType = (VkStructureType)1000338002;
  if (fn_get_isl2_ext && img != VK_NULL_HANDLE && run_enabled(only, "vkGetImageSubresourceLayout2EXT")) {
    puts("STEP call vkGetImageSubresourceLayout2EXT");
    fn_get_isl2_ext(dev, img, &is2, &sl2);
    r[22].called = 1;
    r[22].rc = (long long)sl2.subresourceLayout.size;
    puts("STEP ok vkGetImageSubresourceLayout2EXT");
  }
  if (fn_get_isl2_khr && img != VK_NULL_HANDLE && run_enabled(only, "vkGetImageSubresourceLayout2KHR")) {
    puts("STEP call vkGetImageSubresourceLayout2KHR");
    memset(&sl2, 0, sizeof(sl2));
    sl2.sType = (VkStructureType)1000338002;
    fn_get_isl2_khr(dev, img, &is2, &sl2);
    r[23].called = 1;
    r[23].rc = (long long)sl2.subresourceLayout.size;
    puts("STEP ok vkGetImageSubresourceLayout2KHR");
  }

  if (fn_get_shbin && has_shader_obj && run_enabled(only, "vkGetShaderBinaryDataEXT")) {
    size_t sz = 0;
    r[24].rc = fn_get_shbin(dev, shader, &sz, NULL);
    r[24].called = 1;
  }

  if (fn_trans && has_host_copy && img != VK_NULL_HANDLE && run_enabled(only, "vkTransitionImageLayoutEXT")) {
    puts("STEP call vkTransitionImageLayoutEXT");
    r[25].rc = fn_trans(dev, 0, NULL);
    r[25].called = 1;
    r[26] = r[25];
    r[26].name = "vkTransitionImageLayoutEXT(second_call)";
    r[26].rc = fn_trans(dev, 0, NULL);
    r[26].called = 1;
    puts("STEP ok vkTransitionImageLayoutEXT");
  }

  vkEndCommandBuffer(cb);

  for (size_t i = 0; i < sizeof(r) / sizeof(r[0]); ++i) print_api_result(&r[i]);

  if (img_mem) vkFreeMemory(dev, img_mem, NULL);
  if (img) vkDestroyImage(dev, img, NULL);
  if (buf_mem) vkFreeMemory(dev, buf_mem, NULL);
  if (buf) vkDestroyBuffer(dev, buf, NULL);
  if (pl) vkDestroyPipelineLayout(dev, pl, NULL);
  if (dsl) vkDestroyDescriptorSetLayout(dev, dsl, NULL);
  if (pool) vkDestroyCommandPool(dev, pool, NULL);
  vkDestroyDevice(dev, NULL);
  vkDestroyInstance(instance, NULL);
  puts("PASS test44_call_27_apis");
  return 0;
}
