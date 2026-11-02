/* SPDX-License-Identifier: GPL-2.0-or-later */
/* Offscreen contracts for the actual texture_prepare/world_draws SPIR-V. */
#include <vulkan/vulkan.h>
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#define CHECK(x) do { VkResult r=(x); if(r) { fprintf(stderr,"%s failed: %d\n",#x,r);exit(2); } } while(0)
typedef struct { uint32_t slots[4],size[4]; uint64_t buffer0,buffer1; float params[4],params2[4],params3[4]; } Push;
static VkDevice device; static VkPhysicalDevice physical; static VkQueue queue;
static VkCommandBuffer command; static VkCommandPool pool; static VkPipelineLayout layout;
static VkPhysicalDeviceMemoryProperties memory;
typedef struct { VkBuffer buffer; VkDeviceMemory memory; uint64_t address; uint8_t *bytes; size_t size; } Buffer;
static Buffer buffer_new(size_t size) {
    Buffer b={.size=size};
    VkBufferCreateInfo info={.sType=VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,.size=size,
        .usage=VK_BUFFER_USAGE_STORAGE_BUFFER_BIT|VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT|VK_BUFFER_USAGE_INDIRECT_BUFFER_BIT};
    CHECK(vkCreateBuffer(device,&info,0,&b.buffer));
    VkMemoryRequirements requirements; vkGetBufferMemoryRequirements(device,b.buffer,&requirements);
    uint32_t type=UINT32_MAX;
    for(uint32_t i=0;i<memory.memoryTypeCount;i++) if((requirements.memoryTypeBits&(1u<<i)) &&
        (memory.memoryTypes[i].propertyFlags&(VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT|VK_MEMORY_PROPERTY_HOST_COHERENT_BIT)) ==
        (VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT|VK_MEMORY_PROPERTY_HOST_COHERENT_BIT)) { type=i;break; }
    assert(type!=UINT32_MAX);
    VkMemoryAllocateFlagsInfo flags={.sType=VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_FLAGS_INFO,.flags=VK_MEMORY_ALLOCATE_DEVICE_ADDRESS_BIT};
    VkMemoryAllocateInfo allocation={.sType=VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,.pNext=&flags,.allocationSize=requirements.size,.memoryTypeIndex=type};
    CHECK(vkAllocateMemory(device,&allocation,0,&b.memory)); CHECK(vkBindBufferMemory(device,b.buffer,b.memory,0));
    CHECK(vkMapMemory(device,b.memory,0,size,0,(void**)&b.bytes));
    VkBufferDeviceAddressInfo address={.sType=VK_STRUCTURE_TYPE_BUFFER_DEVICE_ADDRESS_INFO,.buffer=b.buffer};
    b.address=vkGetBufferDeviceAddress(device,&address); return b;
}
static void buffer_delete(Buffer b) { vkUnmapMemory(device,b.memory);vkDestroyBuffer(device,b.buffer,0);vkFreeMemory(device,b.memory,0); }
static void barrier(VkPipelineStageFlags source,VkAccessFlags write,VkPipelineStageFlags target,VkAccessFlags read) {
    VkMemoryBarrier memory={.sType=VK_STRUCTURE_TYPE_MEMORY_BARRIER,.srcAccessMask=write,.dstAccessMask=read};
    vkCmdPipelineBarrier(command,source,target,0,1,&memory,0,0,0,0);
}
static void begin(void) {
    CHECK(vkResetCommandBuffer(command,0));
    VkCommandBufferBeginInfo info={.sType=VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,.flags=VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT};
    CHECK(vkBeginCommandBuffer(command,&info));
    barrier(VK_PIPELINE_STAGE_HOST_BIT,VK_ACCESS_HOST_WRITE_BIT,VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,VK_ACCESS_SHADER_READ_BIT|VK_ACCESS_SHADER_WRITE_BIT);
}
static void finish(void) {
    barrier(VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,VK_ACCESS_SHADER_WRITE_BIT,VK_PIPELINE_STAGE_HOST_BIT,VK_ACCESS_HOST_READ_BIT);
    CHECK(vkEndCommandBuffer(command));
    VkSubmitInfo info={.sType=VK_STRUCTURE_TYPE_SUBMIT_INFO,.commandBufferCount=1,.pCommandBuffers=&command};
    CHECK(vkQueueSubmit(queue,1,&info,0));CHECK(vkQueueWaitIdle(queue));
}
static VkPipeline pipeline(const char *path,VkShaderModule *module) {
    FILE *file=fopen(path,"rb");assert(file);fseek(file,0,SEEK_END);long length=ftell(file);rewind(file);
    uint32_t *bytes=malloc(length);assert(bytes);assert(fread(bytes,1,length,file)==(size_t)length);fclose(file);
    VkShaderModuleCreateInfo info={.sType=VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,.codeSize=length,.pCode=bytes};
    CHECK(vkCreateShaderModule(device,&info,0,module));free(bytes);
    VkComputePipelineCreateInfo create={.sType=VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO,
        .stage={.sType=VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,.stage=VK_SHADER_STAGE_COMPUTE_BIT,.module=*module,.pName="main"},.layout=layout};
    VkPipeline result;CHECK(vkCreateComputePipelines(device,0,1,&create,0,&result));return result;
}
static void dispatch(VkPipeline pipeline,Push push,uint32_t x,uint32_t y) {
    vkCmdBindPipeline(command,VK_PIPELINE_BIND_POINT_COMPUTE,pipeline);
    vkCmdPushConstants(command,layout,VK_SHADER_STAGE_COMPUTE_BIT,0,sizeof(push),&push);
    vkCmdDispatch(command,x,y,1);
}
static unsigned texture_cases(VkPipeline pipeline) {
    unsigned cases=0;
    const uint32_t dimensions[][2]={{1,1},{1,17},{17,1},{7,3},{8,2},{31,65},{64,64},{257,129},{1024,512},{4096,4096}};
    for(unsigned shape=0;shape<sizeof(dimensions)/sizeof(dimensions[0]);shape++) {
        uint32_t widths[16],heights[16],offsets[16],count=0,total=0,w=dimensions[shape][0],h=dimensions[shape][1];
        for(;;) { widths[count]=w;heights[count]=h;offsets[count++]=total;total+=w*h*4;if(w==1&&h==1)break;w=w>1?w/2:1;h=h>1?h/2:1; }
        uint8_t *reference=malloc(total);assert(reference);
        for(uint32_t i=0;i<widths[0]*heights[0]*4;i++)reference[i]=(uint8_t)(i*17+i/251);
        for(uint32_t level=1;level<count;level++) for(uint32_t y=0;y<heights[level];y++) for(uint32_t x=0;x<widths[level];x++) for(uint32_t channel=0;channel<4;channel++) {
            uint32_t sum=0;
            for(uint32_t dy=0;dy<2;dy++)for(uint32_t dx=0;dx<2;dx++) {
                uint32_t sx=x*2+dx,sy=y*2+dy;if(sx>=widths[level-1])sx=widths[level-1]-1;if(sy>=heights[level-1])sy=heights[level-1]-1;
                sum+=reference[offsets[level-1]+(sy*widths[level-1]+sx)*4+channel];
            }
            reference[offsets[level]+(y*widths[level]+x)*4+channel]=(uint8_t)(sum>>2);
        }
        for(uint32_t mapping=0;mapping<2;mapping++) for(uint32_t inplace=0;inplace<2;inplace++) {
            size_t output_offset=inplace?0:total,table_offset=inplace?total:total*2;
            Buffer b=buffer_new(table_offset+1024);memset(b.bytes,0xcd,b.size);
            memcpy(b.bytes,reference,widths[0]*heights[0]*4);
            uint32_t *table=(uint32_t*)(b.bytes+table_offset);
            for(uint32_t i=0;i<256;i++)table[i]=mapping?((i*7+3)&255):i;
            begin();
            for(uint32_t i=1;i<count;i++) {
                Push push={.size={widths[i],heights[i],widths[i-1],heights[i-1]},.buffer0=b.address+offsets[i-1],.buffer1=b.address+offsets[i]};
                dispatch(pipeline,push,(widths[i]+7)/8,(heights[i]+7)/8);
                barrier(VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,VK_ACCESS_SHADER_WRITE_BIT,VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,VK_ACCESS_SHADER_READ_BIT);
            }
            barrier(VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,VK_ACCESS_SHADER_READ_BIT|VK_ACCESS_SHADER_WRITE_BIT,VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,VK_ACCESS_SHADER_READ_BIT|VK_ACCESS_SHADER_WRITE_BIT);
            for(uint32_t i=0;i<count;i++) {
                uint64_t address=b.address+table_offset;
                Push push={.slots={1,0,(uint32_t)address,(uint32_t)(address>>32)},.size={widths[i],heights[i]},.buffer0=b.address+offsets[i],.buffer1=b.address+output_offset+offsets[i]};
                dispatch(pipeline,push,(widths[i]+7)/8,(heights[i]+7)/8);
            }
            finish();
            if(!inplace)assert(!memcmp(reference,b.bytes,total));
            for(uint32_t i=0;i<total;i++) {
                uint8_t expected=i%4==3?reference[i]:(uint8_t)table[reference[i]];
                if(b.bytes[output_offset+i]!=expected) { fprintf(stderr,"mip mismatch shape=%u mapping=%u inplace=%u byte=%u got=%u expected=%u\n",shape,mapping,inplace,i,b.bytes[output_offset+i],expected);exit(3); }
            }
            buffer_delete(b);cases++;
        }
        free(reference);
    }
    return cases;
}
typedef struct { uint32_t indices[4]; float mins[4],maxs[4],plane[4]; } Surface;
typedef struct { float planes[4][4],origin[4]; Surface surfaces[256]; } Input;
static unsigned world_cases(VkPipeline pipeline) {
    const uint32_t sizes[]={1,2,63,64,65,255,256};unsigned cases=0;
    for(uint32_t test=0;test<sizeof(sizes)/sizeof(sizes[0]);test++) for(uint32_t nocull=0;nocull<2;nocull++) {
        Buffer input=buffer_new(sizeof(Input)),source=buffer_new(256*12*4),output=buffer_new(16+256*12*4);
        Input *in=(Input*)input.bytes;memset(in,0,sizeof(*in));
        float planes[4][4]={{1,0,0,-10},{-1,0,0,-10},{0,1,0,-10},{0,-1,0,-10}};
        memcpy(in->planes,planes,sizeof(planes));memset(output.bytes,0xcd,output.size);
        uint32_t expected[256*12],written=0;
        for(uint32_t i=0;i<256*12;i++)((uint32_t*)source.bytes)[i]=i*17+3;
        for(uint32_t i=0;i<sizes[test];i++) {
            Surface *s=&in->surfaces[i];s->indices[0]=i*12;s->indices[1]=(i%5)*3;s->indices[2]=i%2;s->indices[3]=i%3;
            for(uint32_t k=0;k<3;k++){s->mins[k]=(float)((int)(i%31)-15);s->maxs[k]=s->mins[k]+2;}
            s->plane[0]=1;s->plane[3]=(float)((int)(i%23)-11);
            int visible=1;
            if(!nocull) {
                if(s->indices[2]) {
                    if(s->indices[3]==1 && 0<s->plane[3]-8)visible=0;
                    if(s->indices[3]==2 && 0>s->plane[3]+8)visible=0;
                } else for(uint32_t j=0;j<4;j++) {
                    float d=0;for(uint32_t k=0;k<3;k++)d+=(planes[j][k]>=0?s->maxs[k]:s->mins[k])*planes[j][k];
                    if(d<planes[j][3])visible=0;
                }
            }
            if(visible)for(uint32_t j=0;j<s->indices[1];j++)expected[written++]=((uint32_t*)source.bytes)[s->indices[0]+j];
        }
        begin();Push push={.slots={sizes[test],nocull,(uint32_t)source.address,(uint32_t)(source.address>>32)},.buffer0=input.address,.buffer1=output.address};
        dispatch(pipeline,push,1,1);finish();
        uint32_t *actual=(uint32_t*)output.bytes;
        assert(actual[0]==written && actual[1]==1 && actual[2]==0 && actual[3]==0);
        assert(!memcmp(expected,actual+4,written*4));
        for(size_t i=16+written*4;i<output.size;i++)assert(output.bytes[i]==0xcd);
        buffer_delete(input);buffer_delete(source);buffer_delete(output);cases++;
    }
    return cases;
}
int main(int argc,char **argv) {
    assert(argc==3);assert(sizeof(Push)==96 && sizeof(Surface)==64);
    VkApplicationInfo app={.sType=VK_STRUCTURE_TYPE_APPLICATION_INFO,.pApplicationName="dk3-offscreen-contracts",.apiVersion=VK_API_VERSION_1_3};
    VkInstanceCreateInfo create={.sType=VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,.pApplicationInfo=&app};VkInstance instance;
    CHECK(vkCreateInstance(&create,0,&instance));uint32_t count=0;CHECK(vkEnumeratePhysicalDevices(instance,&count,0));assert(count>0);
    VkPhysicalDevice *devices=calloc(count,sizeof(*devices));CHECK(vkEnumeratePhysicalDevices(instance,&count,devices));physical=devices[0];free(devices);
    VkPhysicalDeviceProperties properties;vkGetPhysicalDeviceProperties(physical,&properties);printf("device=%s\n",properties.deviceName);fflush(stdout);
    uint32_t families=0;vkGetPhysicalDeviceQueueFamilyProperties(physical,&families,0);VkQueueFamilyProperties *q=calloc(families,sizeof(*q));vkGetPhysicalDeviceQueueFamilyProperties(physical,&families,q);
    uint32_t family=UINT32_MAX;for(uint32_t i=0;i<families;i++)if(q[i].queueFlags&VK_QUEUE_COMPUTE_BIT){family=i;break;}free(q);assert(family!=UINT32_MAX);
    VkPhysicalDeviceVulkan13Features f13={.sType=VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_3_FEATURES,.maintenance4=VK_TRUE};
    VkPhysicalDeviceVulkan12Features f12={.sType=VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_2_FEATURES,.pNext=&f13,.bufferDeviceAddress=VK_TRUE};
    VkPhysicalDeviceFeatures features={.shaderInt64=VK_TRUE};float priority=1;
    VkDeviceQueueCreateInfo queue_info={.sType=VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,.queueFamilyIndex=family,.queueCount=1,.pQueuePriorities=&priority};
    VkDeviceCreateInfo device_info={.sType=VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,.pNext=&f12,.queueCreateInfoCount=1,.pQueueCreateInfos=&queue_info,.pEnabledFeatures=&features};
    CHECK(vkCreateDevice(physical,&device_info,0,&device));vkGetDeviceQueue(device,family,0,&queue);vkGetPhysicalDeviceMemoryProperties(physical,&memory);
    VkCommandPoolCreateInfo pool_info={.sType=VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,.queueFamilyIndex=family,.flags=VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT};
    CHECK(vkCreateCommandPool(device,&pool_info,0,&pool));VkCommandBufferAllocateInfo command_info={.sType=VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,.commandPool=pool,.level=VK_COMMAND_BUFFER_LEVEL_PRIMARY,.commandBufferCount=1};
    CHECK(vkAllocateCommandBuffers(device,&command_info,&command));VkPushConstantRange range={.stageFlags=VK_SHADER_STAGE_COMPUTE_BIT,.size=sizeof(Push)};
    VkPipelineLayoutCreateInfo layout_info={.sType=VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,.pushConstantRangeCount=1,.pPushConstantRanges=&range};CHECK(vkCreatePipelineLayout(device,&layout_info,0,&layout));
    VkShaderModule modules[2];VkPipeline pipelines[2]={pipeline(argv[1],&modules[0]),pipeline(argv[2],&modules[1])};
    unsigned textures=texture_cases(pipelines[0]),worlds=world_cases(pipelines[1]);printf("texture_cases=%u world_cases=%u failed=0\n",textures,worlds);
    for(int i=0;i<2;i++){vkDestroyPipeline(device,pipelines[i],0);vkDestroyShaderModule(device,modules[i],0);}
    vkDestroyPipelineLayout(device,layout,0);vkDestroyCommandPool(device,pool,0);vkDestroyDevice(device,0);vkDestroyInstance(instance,0);return 0;
}
