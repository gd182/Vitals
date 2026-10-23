#include "CPUStats.hpp"
#include "MemoryStats.hpp"
#include "GPUStats.hpp"
#include "ProcessStats.hpp"
#include "ProcessNames.hpp"

#include <atomic>
#include <cassert>
#include <chrono>
#include <cmath>
#include <ctime>
#include <iostream>
#include <thread>
#include <unistd.h>
#include <mach/mach.h>
#include <libproc.h>
#include <sys/resource.h>

static double toSeconds(const timespec& ts)
{
    return static_cast<double>(ts.tv_sec) +
           static_cast<double>(ts.tv_nsec) / 1'000'000'000.0;
}

int main(int argc, char**) {
    Vitals::GPUStats gpu;

    if (argc > 1) {
        const auto start = std::chrono::steady_clock::now();

        for (int i = 0; i < 2000; ++i)
            gpu.getUsage();

        std::cout << "GPU 2000 samples, ms: "
                  << std::chrono::duration<double, std::milli>(
                         std::chrono::steady_clock::now() - start
                     ).count()
                  << '\n';

        return 0;
    }

    Vitals::CPUStats cpu;

    const auto host = mach_host_self();
    mach_port_urefs_t initialRefs = 0;

    assert(mach_port_get_refs(
        mach_task_self(),
        host,
        MACH_PORT_RIGHT_SEND,
        &initialRefs
    ) == KERN_SUCCESS);

    assert(cpu.getUsage() == 0);

    for (int i = 0; i < 200; ++i) {
        cpu.update();

        const auto& result = cpu.cpuStats();

        assert(std::isfinite(result.average.total));
        assert(result.average.total >= 0 &&
               result.average.total <= 100.01);

        for (const auto& core : result.perCore) {
            assert(std::isfinite(core.total));
            assert(core.total >= 0 &&
                   core.total <= 100.01);
        }
    }

    Vitals::MemoryStats memory;
    const auto ram = memory.getUsage();

    mach_port_urefs_t finalRefs = 0;

    assert(mach_port_get_refs(
        mach_task_self(),
        host,
        MACH_PORT_RIGHT_SEND,
        &finalRefs
    ) == KERN_SUCCESS);

    assert(finalRefs == initialRefs);

    mach_port_deallocate(mach_task_self(), host);

    assert(ram.totalBytes > 0 &&
           ram.usedBytes <= ram.totalBytes);

    assert(std::isfinite(ram.usedPercent));

    rusage_info_v2 ownUsage{};
    assert(proc_pid_rusage(
        getpid(), RUSAGE_INFO_V2,
        reinterpret_cast<rusage_info_t*>(&ownUsage)
    ) == 0);
    assert(ownUsage.ri_proc_start_abstime > 0);

    Vitals::ProcessStats processes;

    assert(processes.getProcCPUInfo(false, 0).empty());
    assert(processes.getProcCPUInfo(false, 10000).empty());

    std::atomic<bool> running{true};

    std::thread busy([&] {
        while (running.load(std::memory_order_relaxed))
            std::atomic_signal_fence(std::memory_order_seq_cst);
    });

    timespec cpuBefore{};
    timespec cpuAfter{};

    assert(clock_gettime(
        CLOCK_PROCESS_CPUTIME_ID,
        &cpuBefore
    ) == 0);

    const auto wallBefore = std::chrono::steady_clock::now();

    std::this_thread::sleep_for(std::chrono::milliseconds(300));

    const auto top = processes.getProcCPUInfo(false, 10000);

    const auto wallAfter = std::chrono::steady_clock::now();

    assert(clock_gettime(
        CLOCK_PROCESS_CPUTIME_ID,
        &cpuAfter
    ) == 0);

    running.store(false, std::memory_order_relaxed);
    busy.join();

    const double deltaProcessSeconds =
        toSeconds(cpuAfter) - toSeconds(cpuBefore);

    const double elapsedSeconds =
        std::chrono::duration<double>(
            wallAfter - wallBefore
        ).count();

    assert(elapsedSeconds > 0.0);
    assert(deltaProcessSeconds >= 0.0);
    const double referencePercent =
        deltaProcessSeconds / elapsedSeconds * 100.0;
    assert(referencePercent > 1.0);
    bool found = false;

    for (const auto& process : top) {
        assert(std::isfinite(process.value));
        assert(process.value >= 0);

        if (process.pid == getpid()) {
            assert(process.name == "vitals-core-metrics-tests");
            assert(process.startTime == ownUsage.ri_proc_start_abstime);
            found = true;

            std::cout
                << "Process CPU: " << process.value << "%\n"
                << "Reference CPU: " << referencePercent << "%\n";

            assert(std::abs(
                process.value - referencePercent
            ) < 15.0);
        }
    }
    assert(found);
    processes.resetCPUHistory();
    assert(processes.getProcCPUInfo(false, 10).empty());
    const auto ramTop = processes.getProcRAMInfo(false, 10);
    assert(ramTop.size() <= 10);
    for (size_t i = 1; i < ramTop.size(); ++i)
        assert(ramTop[i - 1].value >= ramTop[i].value);

    const auto ramTopLong = processes.getProcRAMInfo(false, 10000);
    bool foundRAM = false;
    for (const auto& process : ramTopLong) {
        if (process.pid == getpid()) {
            assert(process.name == "vitals-core-metrics-tests");
            assert(process.startTime == ownUsage.ri_proc_start_abstime);
            foundRAM = true;
        }
    }
    assert(foundRAM);

    assert(Vitals::Detail::resolveProcessName(-1, "fallback-name", 1) == "fallback-name");
    assert(Vitals::Detail::resolveProcessName(-1, "", 1).empty());
    assert(Vitals::Detail::resolveProcessName(
        getpid(), "fallback-name", ownUsage.ri_proc_start_abstime
    ) == "vitals-core-metrics-tests");
    assert(Vitals::Detail::resolveProcessName(
        getpid(), "fallback-name", 0
    ) == "fallback-name");
    const uint64_t differentStartTime = ownUsage.ri_proc_start_abstime == 1 ? 2 : 1;
    assert(Vitals::Detail::resolveProcessName(
        getpid(), "fallback-name", differentStartTime
    ) == "fallback-name");

    std::cout << "Core metrics checks passed\n";
}
