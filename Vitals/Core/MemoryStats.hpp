#ifndef MEMORY_STATS_HPP
#define MEMORY_STATS_HPP

#include <cstdint>
#include <optional>

namespace Vitals
{
    enum class MemoryPressure : uint8_t
    {
        normal,
        warning,
        critical,
    };
    struct SwapUsage
    {
        uint64_t totalBytes;
        uint64_t usedBytes;
    };

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
        std::optional<SwapUsage> getSwapUsage() const;
        std::optional<MemoryPressure> getMemoryPressure() const;
    private:
        MemoryUsage memoryUsage{};
    };
}


#endif // MEMORY_STATS_HPP
