//
//  GPUStats.cpp
//  Vitals
//
//  Created by Алексей on 7/8/26.
//

#include "GPUStats.hpp"

#include <CoreFoundation/CoreFoundation.h>

#include <sys/sysctl.h>

namespace Vitals {
    GPUStats::GPUStats()
    {
        io_iterator_t iter;
        IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &iter);
        service = IOIteratorNext(iter);
        IOObjectRelease(iter);
        gpuInfo.vramTotal = 0;
        
        #if defined(__arm64__) || defined(__aarch64__)
            size_t size = sizeof(gpuInfo.vramTotal);
            sysctlbyname("hw.memsize", &gpuInfo.vramTotal, &size, nullptr, 0);
        #endif

    }

    GPUStats::~GPUStats()
    {
        if (service)
            IOObjectRelease(service);
    }

    
    GPUInfo GPUStats::getUsage()
    {
        CFMutableDictionaryRef props = nullptr;
        if (IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) != kIOReturnSuccess)
            return gpuInfo;
        CFDictionaryRef perfStats = (CFDictionaryRef)CFDictionaryGetValue(props, CFSTR("PerformanceStatistics"));
        if (perfStats) {
            // utilization
            CFNumberRef utilRef = (CFNumberRef)CFDictionaryGetValue(perfStats, CFSTR("Device Utilization %"));
            if (utilRef)
            {
                int v = 0;
                CFNumberGetValue(utilRef, kCFNumberIntType, &v);
                gpuInfo.utilization = v;
            }
            CFNumberRef renderRef = (CFNumberRef)CFDictionaryGetValue(perfStats, CFSTR("Renderer Utilization %"));
            if (renderRef)
            {
                int v = 0;
                CFNumberGetValue(renderRef, kCFNumberIntType, &v);
                gpuInfo.renderUtilization = v;
            }
            CFNumberRef tilerRef  = (CFNumberRef)CFDictionaryGetValue(perfStats, CFSTR("Tiler Utilization %"));
            if (tilerRef)
            {
                int v = 0;
                CFNumberGetValue(tilerRef,  kCFNumberIntType, &v);
                gpuInfo.tilerUtilization  = v;
            }
            CFNumberRef aneRef  = (CFNumberRef)CFDictionaryGetValue(perfStats, CFSTR("Neural Engine Utilization %"));
            if (aneRef)
            {
                int v = 0;
                CFNumberGetValue(aneRef,  kCFNumberIntType, &v);
                gpuInfo.aneUtilization  = v;
            }

            // vram
            CFNumberRef vramUsedRef = nullptr;
            #if defined(__arm64__) || defined(__aarch64__)
                vramUsedRef = (CFNumberRef)CFDictionaryGetValue(perfStats, CFSTR("In use system memory"));
            #else
                vramUsedRef = (CFNumberRef)CFDictionaryGetValue(perfStats, CFSTR("vramUsedBytes"));
                CFNumberRef vramFreeRef = (CFNumberRef)CFDictionaryGetValue(perfStats, CFSTR("vramFreeBytes"));
                if (vramUsedRef && vramFreeRef) {
                    uint64_t used = 0, free = 0;
                    CFNumberGetValue(vramUsedRef, kCFNumberSInt64Type, &used);
                    CFNumberGetValue(vramFreeRef, kCFNumberSInt64Type, &free);
                    gpuInfo.vramUsed = used;
                    gpuInfo.vramTotal = used + free;
                }
            #endif
            #if defined(__arm64__) || defined(__aarch64__)
                if (vramUsedRef) {
                    uint64_t used = 0;
                    CFNumberGetValue(vramUsedRef, kCFNumberSInt64Type, &used);
                    gpuInfo.vramUsed = used;
                }
            #endif
        }
        CFRelease(props);
        return gpuInfo;
    }
}

