#include "MemoryStats.hpp"

#include <mach/mach.h>
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
        vm_statistics64_data_t vmStats;
        mach_msg_type_number_t count = HOST_VM_INFO64_COUNT;
        host_statistics64(mach_host_self(), HOST_VM_INFO64, (host_info64_t)&vmStats, &count);
        this->memoryUsage.usedBytes = (vmStats.active_count + vmStats.wire_count + vmStats.compressor_page_count) * vm_kernel_page_size;
        this->memoryUsage.usedPercent = (double)this->memoryUsage.usedBytes / this->memoryUsage.totalBytes * 100;
        return memoryUsage;
    }
}
