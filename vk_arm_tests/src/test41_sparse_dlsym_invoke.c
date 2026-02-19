#include <dlfcn.h>
#include <stdio.h>
#include <signal.h>
#include <unistd.h>
#include <vulkan/vulkan.h>

typedef void (*PFN_sparse_old)(VkPhysicalDevice,VkFormat,VkImageType,VkSampleCountFlagBits,VkImageUsageFlags,VkImageTiling,uint32_t*,VkSparseImageFormatProperties*);

static void alarm_exit_handler(int sig) {
  (void)sig;
  puts("sparse_old_call_timeout_exit");
  _exit(0);
}
int main(){
  setvbuf(stdout, NULL, _IONBF, 0);
  puts("start");
  void* lib=dlopen("/system/lib64/libvulkan.so", RTLD_NOW|RTLD_LOCAL);
  if(!lib){printf("dlopen fail %s\n", dlerror()); return 1;}
  puts("dlopen_ok");
  PFN_sparse_old p=(PFN_sparse_old)dlsym(lib,"vkGetPhysicalDeviceSparseImageFormatProperties");
  printf("p=%p\n", (void*)p);
  if(!p) return 2;
  puts("dlsym_ok");
  VkApplicationInfo app={.sType=VK_STRUCTURE_TYPE_APPLICATION_INFO,.apiVersion=VK_API_VERSION_1_1};
  VkInstanceCreateInfo ci={.sType=VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,.pApplicationInfo=&app};
  VkInstance inst=0; VkResult r=vkCreateInstance(&ci,NULL,&inst); printf("vkCreateInstance=%d\n",(int)r); if(r) return 3;
  puts("instance_ok");
  uint32_t n=0; r=vkEnumeratePhysicalDevices(inst,&n,NULL); printf("enum=%d n=%u\n",(int)r,n); if(r||n==0) return 4;
  puts("enum_count_ok");
  VkPhysicalDevice dev; r=vkEnumeratePhysicalDevices(inst,&n,&dev); if(r) return 5;
  puts("enum_list_ok");
  uint32_t c=0;
  puts("call_sparse_old_count_begin");
  signal(SIGALRM, alarm_exit_handler);
  alarm(3);
  p(dev,VK_FORMAT_R8G8B8A8_UNORM,VK_IMAGE_TYPE_2D,VK_SAMPLE_COUNT_1_BIT,VK_IMAGE_USAGE_SAMPLED_BIT,VK_IMAGE_TILING_OPTIMAL,&c,NULL);
  alarm(0);
  printf("count=%u\n", c);
  puts("call_sparse_old_count_done");
  if(c){
    VkSparseImageFormatProperties out[8]={0};
    uint32_t c2=c>8?8:c;
    puts("call_sparse_old_props_begin");
    alarm(3);
    p(dev,VK_FORMAT_R8G8B8A8_UNORM,VK_IMAGE_TYPE_2D,VK_SAMPLE_COUNT_1_BIT,VK_IMAGE_USAGE_SAMPLED_BIT,VK_IMAGE_TILING_OPTIMAL,&c2,out);
    alarm(0);
    printf("c2=%u gran=%ux%ux%u\n",c2,out[0].imageGranularity.width,out[0].imageGranularity.height,out[0].imageGranularity.depth);
    puts("call_sparse_old_props_done");
  }
  puts("done");
  return 0;
}
