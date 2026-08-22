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
        std::vector<ProcessInfo> getProcCPUInfo(bool sortAscending = true, int count = 10);
        std::vector<ProcessInfo> getProcRAMInfo(bool sortAscending = true, int count = 10);
    private:
        std::vector<ProcessInfo> getProcInfo (std::string_view command, int count);
        void infoSort(std::vector<ProcessInfo>& temp, int count, bool sortDirection = true);
    };
}

#endif //PROCESS_STATS
