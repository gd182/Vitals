#ifndef MEMORY_STATS_HPP
#define MEMORY_STATS_HPP

#include <cstdint>

namespace Vitals
{
    struct MemoryUsage
    {
        uint64_t totalBytes;
        uint64_t usedBytes;
        float usedPercent;
    };

    class MemoryStats
    {
    public:
        MemoryStats();
        ~MemoryStats() = default;
        MemoryUsage getUsage();
    private:
        MemoryUsage memoryUsage;
    };
}


#endif // MEMORY_STATS_HPP
