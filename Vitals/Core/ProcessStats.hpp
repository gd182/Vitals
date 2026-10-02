//
//  ProcessStats.hpp
//  Vitals
//
//  Created by Алексей on 6/24/26.
//

#ifndef PROCESS_STATS
#define PROCESS_STATS

#include <string>
#include <string_view>
#include <vector>
#include <unordered_map>
#include <chrono>

namespace Vitals
{
    struct ProcessInfo
    {
        int pid;
        std::string name;
        double value;
    };

    class ProcessStats
    {
    public:
        ProcessStats() = default;
        ~ProcessStats() = default;
        std::vector<ProcessInfo> getProcCPUInfo(bool sortAscending = false, int count = 10);
        std::vector<ProcessInfo> getProcRAMInfo(bool sortAscending = false, int count = 10);
        void resetCPUHistory();
    private:
        struct CPUSample {
            uint64_t cpuNs;
            uint64_t startTime;
        };
        std::unordered_map<int, CPUSample> prevCpuNs_;
        std::chrono::steady_clock::time_point prevCpuTime_;
        bool cpuFirstRun_ = true;
    };
}

#endif //PROCESS_STATS
