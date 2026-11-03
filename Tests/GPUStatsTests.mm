#import "SystemMonitor.h"
#include "GPUStats.hpp"

#include <cassert>
#include <cmath>
#include <cstring>
#include <dlfcn.h>
#include <iostream>
#include <source_location>

namespace {
    constexpr io_iterator_t iterator = 0xF0000011;
    constexpr io_service_t device = 0xF0000012;
    id statistics = nil;
    bool matchingFails = false;
    bool hasDevice = true;
    bool memoryFails = false;
    bool wrongMemorySize = false;
    uint64_t memoryTotal = 8192;

    NSMutableDictionary* validStatistics()
    {
        return [@{
            @"Device Utilization %": @33.3,
            @"Renderer Utilization %": @25,
            @"Tiler Utilization %": @0,
            @"Neural Engine Utilization %": @100,
            @"In use system memory": @1024,
            @"vramUsedBytes": @1024,
            @"vramFreeBytes": @7168,
        } mutableCopy];
    }

    template<typename T>
    void fails(const Vitals::GPUReading<T>& reading, Vitals::GPUReadError error,
               std::source_location location = std::source_location::current())
    {
        if (reading || reading.error() != error)
            std::cerr << "Unexpected GPU result at line " << location.line()
                      << ", expected error " << static_cast<int>(error)
                      << ", has value " << reading.has_value() << std::endl;
        assert(!reading && reading.error() == error);
    }

    void statisticsFail(const Vitals::GPUInfo& info, Vitals::GPUReadError error)
    {
        fails(info.utilization, error);
        fails(info.renderUtilization, error);
        fails(info.tilerUtilization, error);
        fails(info.aneUtilization, error);
        fails(info.vramUsed, error);
        #if defined(__arm64__) || defined(__aarch64__)
            assert(info.vramTotal && *info.vramTotal == memoryTotal);
        #else
            fails(info.vramTotal, error);
        #endif
    }
}

// Replace only the GPU registry path in this standalone executable.
extern "C" kern_return_t IOServiceGetMatchingServices(mach_port_t, CFDictionaryRef matching, io_iterator_t* result)
{
    assert(CFEqual(CFDictionaryGetValue(matching, CFSTR("IOProviderClass")), CFSTR("IOAccelerator")));
    CFRelease(matching);
    *result = matchingFails ? 0 : iterator;
    return matchingFails ? kIOReturnError : kIOReturnSuccess;
}

extern "C" io_object_t IOIteratorNext(io_iterator_t value)
{
    assert(value == iterator);
    return hasDevice ? device : 0;
}

extern "C" kern_return_t IOObjectRelease(io_object_t value)
{
    assert(value == device || value == iterator);
    return kIOReturnSuccess;
}

extern "C" CFTypeRef IORegistryEntryCreateCFProperty(io_registry_entry_t entry, CFStringRef key,
                                                     CFAllocatorRef, IOOptionBits)
{
    assert(entry == device && CFEqual(key, CFSTR("PerformanceStatistics")));
    return statistics ? CFRetain((__bridge CFTypeRef)statistics) : nullptr;
}

extern "C" int sysctlbyname(const char* name, void* data, size_t* size, void* newData, size_t newSize)
{
    if (std::strcmp(name, "hw.memsize") == 0) {
        assert(data && size && *size >= sizeof(memoryTotal) && !newData && newSize == 0);
        if (memoryFails) return -1;
        std::memcpy(data, &memoryTotal, sizeof(memoryTotal));
        *size = wrongMemorySize ? sizeof(memoryTotal) - 1 : sizeof(memoryTotal);
        return 0;
    }
    using Query = int (*)(const char*, void*, size_t*, void*, size_t);
    static const auto original = reinterpret_cast<Query>(dlsym(RTLD_NEXT, "sysctlbyname"));
    assert(original);
    return original(name, data, size, newData, newSize);
}

int main()
{
    using namespace Vitals;
    @autoreleasepool {
        GPUStats gpu;
        SystemMonitor* monitor = [[SystemMonitor alloc] init];
        statistics = validStatistics();
        auto info = gpu.getUsage();
        assert(info.utilization && std::abs(*info.utilization - 33.3f) < 0.001f);
        assert(info.tilerUtilization && *info.tilerUtilization == 0);
        assert(info.aneUtilization && *info.aneUtilization == 100);
        assert(info.vramUsed && *info.vramUsed == 1024);
        assert(info.vramTotal && *info.vramTotal == 8192);
        auto bridged = [monitor gpuUsage];
        assert(bridged.utilizationState == ObjCGPUReadStateAvailable);
        assert(bridged.tilerUtilizationState == ObjCGPUReadStateAvailable && bridged.tilerUtilization == 0);

        for (id property : @[ [NSNull null], @[], @42 ]) {
            statistics = property;
            statisticsFail(gpu.getUsage(), GPUReadError::invalidData);
            assert([monitor gpuUsage].utilizationState == ObjCGPUReadStateInvalidData);
        }
        statistics = nil;
        statisticsFail(gpu.getUsage(), GPUReadError::readFailed);
        assert([monitor gpuUsage].utilizationState == ObjCGPUReadStateReadFailed);

        statistics = @{};
        statisticsFail(gpu.getUsage(), GPUReadError::unavailable);
        assert([monitor gpuUsage].utilizationState == ObjCGPUReadStateUnavailable);
        for (id invalid : @[@"42", @YES, [NSNull null], @(-1), @101, @(NAN), @(INFINITY)]) {
            auto partial = validStatistics();
            partial[@"Device Utilization %"] = invalid;
            statistics = partial;
            info = gpu.getUsage();
            fails(info.utilization, GPUReadError::invalidData);
            assert(info.renderUtilization && *info.renderUtilization == 25);
        }
        auto partial = validStatistics();
        [partial removeObjectForKey:@"Neural Engine Utilization %"];
        statistics = partial;
        info = gpu.getUsage();
        fails(info.aneUtilization, GPUReadError::unavailable);
        assert(info.utilization && info.renderUtilization && info.tilerUtilization);
        assert([monitor gpuUsage].aneUtilizationState == ObjCGPUReadStateUnavailable);

        #if defined(__arm64__) || defined(__aarch64__)
            NSString* usedKey = @"In use system memory";
        #else
            NSString* usedKey = @"vramUsedBytes";
        #endif
        for (id invalid : @[@"1024", @(-1), @1.5, @(NAN), @(INFINITY)]) {
            partial = validStatistics();
            partial[usedKey] = invalid;
            statistics = partial;
            fails(gpu.getUsage().vramUsed, GPUReadError::invalidData);
            assert([monitor gpuUsage].vramUsedState == ObjCGPUReadStateInvalidData);
        }
        partial = validStatistics();
        partial[usedKey] = @0;
        partial[@"Device Utilization %"] = @0;
        statistics = partial;
        assert(gpu.getUsage().vramUsed && *gpu.getUsage().vramUsed == 0);
        assert([monitor gpuUsage].utilizationState == ObjCGPUReadStateAvailable);
        assert([monitor gpuUsage].utilization == 0);
        statistics = nil;
        statisticsFail(gpu.getUsage(), GPUReadError::readFailed);
        statistics = validStatistics();
        assert(gpu.getUsage().utilization);

        hasDevice = false;
        GPUStats absent;
        statisticsFail(absent.getUsage(), GPUReadError::unavailable);
        hasDevice = true;
        matchingFails = true;
        GPUStats queryFailure;
        statisticsFail(queryFailure.getUsage(), GPUReadError::readFailed);
        matchingFails = false;

        #if defined(__arm64__) || defined(__aarch64__)
            partial = validStatistics();
            partial[usedKey] = @8193;
            statistics = partial;
            fails(gpu.getUsage().vramUsed, GPUReadError::invalidData);
            for (int scenario = 0; scenario < 3; ++scenario) {
                memoryFails = scenario == 0;
                wrongMemorySize = scenario == 1;
                memoryTotal = scenario == 2 ? 0 : 8192;
                GPUStats unknownMemory;
                fails(unknownMemory.getUsage().vramTotal,
                      scenario == 0 ? GPUReadError::readFailed : GPUReadError::invalidData);
            }
        #else
            partial = validStatistics();
            [partial removeObjectForKey:@"vramFreeBytes"];
            statistics = partial;
            fails(gpu.getUsage().vramTotal, GPUReadError::unavailable);
        #endif
        std::cout << "GPU native availability, validation, recovery and Objective-C++ bridge checks passed\n";
    }
}
