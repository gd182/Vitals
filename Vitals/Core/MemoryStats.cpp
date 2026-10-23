#include "MemoryStats.hpp"

#include <mach/mach.h>
#include <optional>
#include <sys/sysctl.h>

namespace Vitals {
    MemoryStats::MemoryStats()
    {
        uint64_t total = 0;
        size_t size = sizeof(total);
        sysctlbyname("hw.memsize", &total, &size, nullptr, 0);
        this->memoryUsage.totalBytes = total;
    }
    
    MemoryUsage MemoryStats::getUsage()
    {
        vm_statistics64_data_t vmStats{};
        mach_msg_type_number_t count = HOST_VM_INFO64_COUNT;
        const auto host = mach_host_self();
        const auto result = host_statistics64(host, HOST_VM_INFO64, (host_info64_t)&vmStats, &count);
        mach_port_deallocate(mach_task_self(), host);
        if (result != KERN_SUCCESS || memoryUsage.totalBytes == 0)
            return memoryUsage;
        this->memoryUsage.usedBytes = (uint64_t(vmStats.active_count) + vmStats.wire_count + vmStats.compressor_page_count) * vm_kernel_page_size;
        this->memoryUsage.usedPercent = (double)this->memoryUsage.usedBytes / this->memoryUsage.totalBytes * 100;
        return memoryUsage;
    }

    std::optional<SwapUsage> MemoryStats::getSwapUsage() const
    {
        xsw_usage usage{};
        size_t size = sizeof(usage);

        if (sysctlbyname("vm.swapusage", &usage, &size, nullptr, 0) != 0 ||
            size != sizeof(usage)) {
            return std::nullopt;
        }

        return SwapUsage{
            .totalBytes = usage.xsu_total,
            .usedBytes = usage.xsu_used
        };
    }

    std::optional<MemoryPressure> MemoryStats::getMemoryPressure() const
    {
        uint32_t level = 0;
        size_t size = sizeof(level);

        if (sysctlbyname(
                "kern.memorystatus_vm_pressure_level",
                &level,
                &size,
                nullptr,
                0
            ) != 0 || size != sizeof(level)) {
            return std::nullopt;
        }
        switch (level)
        {
            case 1: return MemoryPressure::normal;
            case 2: return MemoryPressure::warning;
            case 4: return MemoryPressure::critical;
            default: return std::nullopt;
        }
    }
}
