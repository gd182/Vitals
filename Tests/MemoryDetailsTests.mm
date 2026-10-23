#import "SystemMonitor.h"
#include "MemoryStats.hpp"

#include <cassert>
#include <cerrno>
#include <cstring>
#include <dlfcn.h>
#include <iostream>
#include <sys/sysctl.h>

namespace {
    struct Response {
        bool fail = false;
        bool wrongSize = false;
        uint32_t pressure = 1;
        uint64_t swapTotal = 2ULL * 1024 * 1024 * 1024;
        uint64_t swapUsed = 1024ULL * 1024 * 1024;
    } response;

    template<class T> int deliver(const T& value, void* data, size_t* size)
    {
        assert(data && size && *size >= sizeof(T));
        if (response.fail) {
            errno = EACCES;
            return -1;
        }
        std::memcpy(data, &value, sizeof(value));
        *size = response.wrongSize ? sizeof(value) - 1 : sizeof(value);
        return 0;
    }
}

// Only the two RAM queries are replaced in this standalone executable.
extern "C" int sysctlbyname(const char* name, void* data, size_t* size,
                            void* newData, size_t newSize)
{
    if (std::strcmp(name, "kern.memorystatus_vm_pressure_level") == 0) {
        assert(!newData && newSize == 0);
        return deliver(response.pressure, data, size);
    }
    if (std::strcmp(name, "vm.swapusage") == 0) {
        assert(!newData && newSize == 0);
        xsw_usage swap{};
        swap.xsu_total = response.swapTotal;
        swap.xsu_used = response.swapUsed;
        return deliver(swap, data, size);
    }
    using Query = int (*)(const char*, void*, size_t*, void*, size_t);
    static const auto original = reinterpret_cast<Query>(dlsym(RTLD_NEXT, "sysctlbyname"));
    assert(original);
    return original(name, data, size, newData, newSize);
}

int main()
{
    @autoreleasepool {
        Vitals::MemoryStats memory;
        SystemMonitor* monitor = [[SystemMonitor alloc] init];
        const struct {
            uint32_t raw;
            Vitals::MemoryPressure native;
            ObjCMemoryPressure bridged;
        } levels[] = {
            {1, Vitals::MemoryPressure::normal, ObjCMemoryPressureNormal},
            {2, Vitals::MemoryPressure::warning, ObjCMemoryPressureWarning},
            {4, Vitals::MemoryPressure::critical, ObjCMemoryPressureCritical},
            {1, Vitals::MemoryPressure::normal, ObjCMemoryPressureNormal},
        };
        for (const auto& level : levels) {
            response = {};
            response.pressure = level.raw;
            assert(memory.getMemoryPressure() == level.native);
            assert([monitor memoryPressure] == level.bridged);
        }
        for (uint32_t unknown : {0U, 3U, 5U, 255U}) {
            response.pressure = unknown;
            assert(!memory.getMemoryPressure());
            assert([monitor memoryPressure] == ObjCMemoryPressureUnknown);
        }
        for (bool wrongSize : {false, true}) {
            response = {};
            response.fail = !wrongSize;
            response.wrongSize = wrongSize;
            assert(!memory.getMemoryPressure());
            assert([monitor memoryPressure] == ObjCMemoryPressureUnknown);
            assert(!memory.getSwapUsage());
            const auto swap = [monitor swapUsage];
            assert(!swap.available && swap.totalBytes == 0 && swap.usedBytes == 0);
        }
        for (bool empty : {false, true}) {
            response = {};
            if (empty) response.swapTotal = response.swapUsed = 0;
            const auto native = memory.getSwapUsage();
            assert(native && native->totalBytes == response.swapTotal);
            assert(native->usedBytes == response.swapUsed);
            const auto bridged = [monitor swapUsage];
            assert(bridged.available);
            assert(bridged.totalBytes == response.swapTotal);
            assert(bridged.usedBytes == response.swapUsed);
            assert(memory.getMemoryPressure() == Vitals::MemoryPressure::normal);
            assert([monitor memoryPressure] == ObjCMemoryPressureNormal);
        }
        std::cout << "Native memory pressure, swap and Objective-C++ bridge checks passed\n";
    }
}
