#include "GPUStats.hpp"

#include <CoreFoundation/CoreFoundation.h>
#include <cmath>
#include <expected>
#include <limits>
#include <sys/sysctl.h>

namespace {
    using Vitals::GPUReading;
    using Vitals::GPUReadError;

    GPUReading<CFNumberRef> numberForKey(CFDictionaryRef statistics, CFStringRef key)
    {
        const auto value = CFDictionaryGetValue(statistics, key);
        if (!value)
        {
            return std::unexpected(GPUReadError::unavailable);
        }
        if (CFGetTypeID(value) != CFNumberGetTypeID())
        {
            return std::unexpected(GPUReadError::invalidData);
        }
        return static_cast<CFNumberRef>(value);
    }

    GPUReading<float> percentage(CFDictionaryRef statistics, CFStringRef key)
    {
        const auto number = numberForKey(statistics, key);
        if (!number)
        {
            return std::unexpected(number.error());
        }
        double value = 0;
        if (!CFNumberGetValue(*number, kCFNumberDoubleType, &value) ||
            !std::isfinite(value) || value < 0 || value > 100)
            return std::unexpected(GPUReadError::invalidData);
        return static_cast<float>(value);
    }

    GPUReading<uint64_t> bytes(CFDictionaryRef statistics, CFStringRef key)
    {
        const auto number = numberForKey(statistics, key);
        if (!number)
        {
            return std::unexpected(number.error());
        }
        if (CFNumberIsFloatType(*number)) {
            double numeric = 0;
            if (!CFNumberGetValue(*number, kCFNumberDoubleType, &numeric) ||
                !std::isfinite(numeric) || numeric < 0 || std::trunc(numeric) != numeric ||
                numeric >= std::ldexp(1.0, 63))
                return std::unexpected(GPUReadError::invalidData);
        }
        int64_t value = 0;
        if (!CFNumberGetValue(*number, kCFNumberSInt64Type, &value) || value < 0)
        {
            return std::unexpected(GPUReadError::invalidData);
        }
        return static_cast<uint64_t>(value);
    }
}

namespace Vitals {
    GPUStats::GPUStats()
    {
        io_iterator_t iter = 0;
        if (IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &iter) == kIOReturnSuccess) {
            service = IOIteratorNext(iter);
            IOObjectRelease(iter);
        } else {
            serviceError = GPUReadError::readFailed;
        }
        #if defined(__arm64__) || defined(__aarch64__)
            uint64_t total = 0;
            size_t size = sizeof(total);
            if (sysctlbyname("hw.memsize", &total, &size, nullptr, 0) !=0)
            {
                unifiedMemoryTotal = std::unexpected(GPUReadError::readFailed);
            }
            else if (size != sizeof(total) || total == 0)
            {
                unifiedMemoryTotal = std::unexpected(GPUReadError::invalidData);
            }
            else {
                unifiedMemoryTotal = total;
            }
        #endif
    }

    GPUStats::~GPUStats()
    {
        if (service)
            IOObjectRelease(service);
    }

    GPUInfo GPUStats::getUsage()
    {
        // Each read is independent: failed counters must not retain an earlier value.
        GPUInfo info{};
        info.vramTotal = unifiedMemoryTotal;
        const auto setStatisticsError = [&info](GPUReadError error) {
            info.utilization = std::unexpected(error);
            info.renderUtilization = std::unexpected(error);
            info.tilerUtilization = std::unexpected(error);
            info.aneUtilization = std::unexpected(error);
            info.vramUsed = std::unexpected(error);
            #if !defined(__arm64__) && !defined(__aarch64__)
                info.vramTotal = std::unexpected(error);
            #endif
        };
        if (!service) {
            setStatisticsError(serviceError);
            return info;
        }
        const auto property = IORegistryEntryCreateCFProperty(service, CFSTR("PerformanceStatistics"), kCFAllocatorDefault, 0);
        if (!property) {
            setStatisticsError(GPUReadError::readFailed);
            return info;
        }
        if (CFGetTypeID(property) == CFDictionaryGetTypeID()) {
            const auto statistics = static_cast<CFDictionaryRef>(property);
            info.utilization = percentage(statistics, CFSTR("Device Utilization %"));
            info.renderUtilization = percentage(statistics, CFSTR("Renderer Utilization %"));
            info.tilerUtilization = percentage(statistics, CFSTR("Tiler Utilization %"));
            info.aneUtilization = percentage(statistics, CFSTR("Neural Engine Utilization %"));

            #if defined(__arm64__) || defined(__aarch64__)
                info.vramUsed = bytes(statistics, CFSTR("In use system memory"));
            #else
                info.vramUsed = bytes(statistics, CFSTR("vramUsedBytes"));
                const auto free = bytes(statistics, CFSTR("vramFreeBytes"));
                if (!info.vramUsed) {
                    info.vramTotal = std::unexpected(info.vramUsed.error());
                } else if (!free) {
                    info.vramTotal = std::unexpected(free.error());
                } else if (*info.vramUsed > std::numeric_limits<uint64_t>::max() - *free) {
                    info.vramTotal = std::unexpected(GPUReadError::invalidData);
                } else {
                    const auto total = *info.vramUsed + *free;
                    info.vramTotal = total > 0 ? GPUReading<uint64_t>(total)
                        : std::unexpected(GPUReadError::invalidData);
                }
            #endif
            if (info.vramUsed && info.vramTotal && *info.vramUsed > *info.vramTotal)
                info.vramUsed = std::unexpected(GPUReadError::invalidData);
        }
        else
        {
            setStatisticsError(GPUReadError::invalidData);
        }
        CFRelease(property);
        return info;
    }
}
