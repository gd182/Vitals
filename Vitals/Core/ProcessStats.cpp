//
//  ProcessStats.cpp
//  Vitals
//

#include "ProcessStats.hpp"
#include "ProcessNames.hpp"

#include <algorithm>
#include <string>
#include <sys/sysctl.h>
#include <cstdint>
#include <libproc.h>
#include <sys/resource.h>
#include <mach/mach_time.h>

namespace Vitals
{
    namespace {
        void addToTop(std::vector<ProcessInfo>& top, int pid, const char* name,
                      double value, size_t count, bool ascending, uint64_t startTime)
        {
            const auto position = std::lower_bound(top.begin(), top.end(), value,
                [ascending](const ProcessInfo& process, double candidate) {
                    return ascending ? process.value < candidate : process.value > candidate;
                });
            if (position == top.end() && top.size() >= count)
                return;
            top.insert(position, {pid, name, value, startTime});
            if (top.size() > count)
                top.pop_back();
        }

        void resolveProcessNames(std::vector<ProcessInfo>& processes)
        {
            for (auto& process : processes) {
                process.name = Detail::resolveProcessName(process.pid, process.name, process.startTime);
            }
        }
    }

    void ProcessStats::resetCPUHistory()
    {
        decltype(prevCpuNs_){}.swap(prevCpuNs_);
        cpuFirstRun_ = true;
    }

    std::vector<ProcessInfo> ProcessStats::getProcCPUInfo(bool sortAscending, int count)
    {
        if (count <= 0)
            return {};
        static const mach_timebase_info_data_t timebase = [] {
            mach_timebase_info_data_t info{};
            if (mach_timebase_info(&info) != KERN_SUCCESS) {
                return mach_timebase_info_data_t{};
            }
            return info;
        }();
        if (timebase.numer == 0 || timebase.denom == 0)
            return {};
        int mib[] = {CTL_KERN, KERN_PROC, KERN_PROC_ALL};
        size_t size = 0;
        if (sysctl(mib, 3, nullptr, &size, nullptr, 0) != 0)
            return {};
        std::vector<kinfo_proc> procs(size / sizeof(kinfo_proc) + 32);
        size = procs.size() * sizeof(kinfo_proc);
        if (sysctl(mib, 3, procs.data(), &size, nullptr, 0) != 0)
            return {};
        procs.resize(size / sizeof(kinfo_proc));

        const auto now = std::chrono::steady_clock::now();
        const double elapsedNs = std::chrono::duration<double, std::nano>(now - prevCpuTime_).count();
        std::unordered_map<int, CPUSample> current;
        current.reserve(procs.size());
        std::vector<ProcessInfo> top;
        top.reserve(std::min<size_t>(count, procs.size()) + 1);
        for (const auto& proc : procs) {
            const auto pid = proc.kp_proc.p_pid;
            rusage_info_v2 usage{};
            if (pid <= 0 || proc_pid_rusage(pid, RUSAGE_INFO_V2, reinterpret_cast<rusage_info_t*>(&usage)) != 0)
                continue;
            const uint64_t cpuNs = usage.ri_user_time + usage.ri_system_time;
            current.emplace(pid, CPUSample{cpuNs, usage.ri_proc_start_abstime});
            const auto previous = prevCpuNs_.find(pid);
            if (cpuFirstRun_ || elapsedNs <= 0 || previous == prevCpuNs_.end()
                || previous->second.startTime != usage.ri_proc_start_abstime || cpuNs < previous->second.cpuNs)
                continue;
            const double deltaTicks = cpuNs - previous->second.cpuNs;
            const double deltaNanoseconds = deltaTicks * timebase.numer / timebase.denom;
            const double percent = deltaNanoseconds / elapsedNs * 100;
            addToTop(top, pid, proc.kp_proc.p_comm, percent,
                    count, sortAscending, usage.ri_proc_start_abstime);
        }
        prevCpuNs_.swap(current);
        prevCpuTime_ = now;
        cpuFirstRun_ = false;
        resolveProcessNames(top);
        return top;
    }

    std::vector<ProcessInfo> ProcessStats::getProcRAMInfo(bool sortAscending, int count)
    {
        if (count <= 0)
            return {};
        int mib[3] = {
            CTL_KERN,
            KERN_PROC,
            KERN_PROC_ALL
        };

        size_t size = 0;

        if (sysctl(mib, 3, nullptr, &size, nullptr, 0) != 0) {
            return {};
        }

        const size_t capacity = size / sizeof(kinfo_proc) + 32;

        std::vector<kinfo_proc> procs(capacity);

        size = procs.size() * sizeof(kinfo_proc);

        if (sysctl(mib, 3, procs.data(), &size, nullptr, 0) != 0)
        {
            return {};
        }

        procs.resize(size / sizeof(kinfo_proc));

        std::vector<ProcessInfo> temp;
        temp.reserve(std::min<size_t>(count, procs.size()) + 1);

        for (const auto& proc : procs) {
            const pid_t pid = proc.kp_proc.p_pid;

            if (pid <= 0)
                continue;

            uint64_t memory = 0;
            uint64_t startTime = 0;
            rusage_info_v2 ri{};
            errno = 0;

            const int rusageResult = proc_pid_rusage(pid, RUSAGE_INFO_V2, reinterpret_cast<rusage_info_t*>(&ri));

            if (rusageResult == 0) {
                memory = ri.ri_phys_footprint;
                startTime = ri.ri_proc_start_abstime;
            }
            else {
                proc_taskinfo ti{};

                errno = 0;

                const int taskResult = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &ti, sizeof(ti));

                if (taskResult == sizeof(ti)) {
                    memory = ti.pti_resident_size;
                }
            }

            if (memory == 0) {
                continue;
            }

            addToTop(temp, pid, proc.kp_proc.p_comm,
                    static_cast<double>(memory), count, sortAscending, startTime);
        }
        resolveProcessNames(temp);
        return temp;
    }
}
