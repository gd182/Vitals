//
//  ProcessStats.cpp
//  Vitals
//

#include "ProcessStats.hpp"

#include <algorithm>
#include <sys/sysctl.h>
#include <cstdint>

namespace Vitals
{

    std::vector<ProcessInfo> ProcessStats::getProcInfo(std::string_view command, int count)
    {
        int mib[3] = {CTL_KERN, KERN_PROC, KERN_PROC_ALL};
        size_t size = 0;
        sysctl(mib, 3, nullptr, &size, nullptr, 0);
        
        std::vector<ProcessInfo> temp;
        temp.reserve(size / sizeof(kinfo_proc));
        
        FILE* pipe = popen(command.data(), "r");
    
        if (!pipe) return {};
        char line[512];
        fgets(line, sizeof(line), pipe);
        while (fgets(line, sizeof(line), pipe)) {
            int pid; float value; char name[256];
            if (sscanf(line, "%d %f %255s", &pid, &value, name) == 3)
                temp.push_back({pid, name, (float)value});
        }
        pclose(pipe);
        return temp;
    }


    void ProcessStats::infoSort(std::vector<ProcessInfo>& temp, int count, bool sortDirection)
    {
        std::partial_sort(temp.begin(), temp.begin() + count, temp.end(),
            [sortDirection](const ProcessInfo& a, const ProcessInfo& b){ return sortDirection ? a.value > b.value : a.value < b.value; });
    }

    std::vector<ProcessInfo> ProcessStats::getProcCPUInfo(bool sortAscending, int count)
    {
        std::vector<ProcessInfo> temp = getProcInfo("/bin/ps -Aceo pid,pcpu,comm", count);
        int n = std::min(count, (int)temp.size());
        infoSort(temp, n, sortAscending);
        
        return std::vector<ProcessInfo>(temp.begin(), temp.begin() + n);
    }

    std::vector<ProcessInfo> ProcessStats::getProcRAMInfo(bool sortAscending, int count)
    {
        std::vector<ProcessInfo> temp = getProcInfo("/bin/ps -Aceo pid,rss,comm", count);
        int n = std::min(count, (int)temp.size());
        infoSort(temp, n, sortAscending);
        
        std::vector<ProcessInfo> ramInfo;
        std::transform(temp.begin(), temp.begin() + n,
                        std::back_inserter(ramInfo),
                        [](const ProcessInfo& r) -> ProcessInfo {
            return {r.pid, r.name, r.value * 1024};
                        });

        return ramInfo;
    }
}
