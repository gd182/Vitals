#ifndef CPUSTATS_HPP
#define CPUSTATS_HPP

#include <cstdint>
#include <vector>

namespace Vitals
{
    struct CoreTicks
    {
        uint64_t user;
        uint64_t system;
        uint64_t idle;
        uint64_t nice;
    };

    struct CPUUsage {
        float total;
        float user;
        float system;
        float idle;
    };

    struct CPUStatsResult {
        CPUUsage average;
        std::vector<CPUUsage> perCore;
    };

    class CPUStats
    {
    public:
        CPUStats() = default;
        ~CPUStats();
        void update();
        double getUsage() {return this->lastResult.average.total;}
        const CPUStatsResult& cpuStats() {return this->lastResult;}
    private:
        CPUStatsResult lastResult;
        std::vector<CoreTicks> prevTicks;
    };
}



#endif // CPUSTATS_HPP
