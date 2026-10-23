#include "ProcessNames.hpp"

#include <filesystem>
#include <libproc.h>

namespace Vitals::Detail
{
    std::string resolveProcessName(int pid, std::string_view fallback, uint64_t expectedStartTime)
    {
        if (expectedStartTime == 0)
        {
            return std::string(fallback);
        }
        rusage_info_v2 before{};
        if (proc_pid_rusage(pid, RUSAGE_INFO_V2, reinterpret_cast<rusage_info_t*>(&before)) != 0 ||
            before.ri_proc_start_abstime != expectedStartTime)
        {
            return std::string(fallback);
        }

        char path[PROC_PIDPATHINFO_MAXSIZE]{};
        int countRes = proc_pidpath(pid, path, sizeof(path));

        if (countRes <= 0)
        {
            return std::string(fallback);
        }
        
        rusage_info_v2 after{};
        if (proc_pid_rusage(pid, RUSAGE_INFO_V2, reinterpret_cast<rusage_info_t*>(&after)) != 0 ||
            after.ri_proc_start_abstime != expectedStartTime)
        {
            return std::string(fallback);
        }

        std::string filename = std::filesystem::path(path).filename().string();

        if (filename.empty())
        {
            return std::string(fallback);
        }
        return filename;
    }
}