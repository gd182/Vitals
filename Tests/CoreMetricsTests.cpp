#include "CPUStats.hpp"
#include "MemoryStats.hpp"
#include "GPUStats.hpp"
#include "ProcessStats.hpp"

#include <atomic>
#include <cassert>
#include <chrono>
#include <cmath>
#include <iostream>
#include <thread>
#include <unistd.h>
#include <mach/mach.h>

int main(int argc, char**) {
    Vitals::GPUStats gpu;
    if (argc > 1) {
        const auto start = std::chrono::steady_clock::now();
        for (int i = 0; i < 2000; ++i)
            gpu.getUsage();
        std::cout << "GPU 2000 samples, ms: " << std::chrono::duration<double, std::milli>(
            std::chrono::steady_clock::now() - start).count() << '\n';
        return 0;
    }
    Vitals::CPUStats cpu;
    const auto host = mach_host_self();
    mach_port_urefs_t initialRefs = 0;
    assert(mach_port_get_refs(mach_task_self(), host, MACH_PORT_RIGHT_SEND, &initialRefs) == KERN_SUCCESS);
    assert(cpu.getUsage() == 0);
    for (int i = 0; i < 200; ++i) {
        cpu.update();
        const auto& result = cpu.cpuStats();
        assert(std::isfinite(result.average.total));
        assert(result.average.total >= 0 && result.average.total <= 100.01);
        for (const auto& core : result.perCore) {
            assert(std::isfinite(core.total));
            assert(core.total >= 0 && core.total <= 100.01);
        }
    }
    Vitals::MemoryStats memory;
    const auto ram = memory.getUsage();
    mach_port_urefs_t finalRefs = 0;
    assert(mach_port_get_refs(mach_task_self(), host, MACH_PORT_RIGHT_SEND, &finalRefs) == KERN_SUCCESS);
    assert(finalRefs == initialRefs);
    mach_port_deallocate(mach_task_self(), host);
    assert(ram.totalBytes > 0 && ram.usedBytes <= ram.totalBytes);
    assert(std::isfinite(ram.usedPercent));
    Vitals::ProcessStats processes;
    assert(processes.getProcCPUInfo(false, 0).empty());
    assert(processes.getProcCPUInfo(false, 10000).empty());
    std::atomic<bool> running{true};
    std::thread busy([&] {
        while (running.load(std::memory_order_relaxed))
            std::atomic_signal_fence(std::memory_order_seq_cst);
    });
    std::this_thread::sleep_for(std::chrono::milliseconds(300));
    const auto top = processes.getProcCPUInfo(false, 10000);
    running = false;
    busy.join();
    bool found = false;
    for (const auto& process : top) {
        assert(std::isfinite(process.value) && process.value >= 0);
        if (process.pid == getpid()) {
            found = true;
            assert(process.value > 1 && process.value < 500);
        }
    }
    assert(found);
    processes.resetCPUHistory();
    assert(processes.getProcCPUInfo(false, 10).empty());
    const auto ramTop = processes.getProcRAMInfo(false, 10);
    assert(ramTop.size() <= 10);
    for (size_t i = 1; i < ramTop.size(); ++i)
        assert(ramTop[i - 1].value >= ramTop[i].value);
    std::cout << "Core metrics checks passed\n";
}
