#include "CPUStats.hpp"

#include <mach/mach.h>
#include <mach/processor_info.h>
#include <mach/mach_host.h>

namespace Vitals {
    CPUStats::~CPUStats() = default;

    void CPUStats::update() {
        natural_t processorCount = 0;
        processor_info_array_t infoArray = nullptr;
        mach_msg_type_number_t infoCount = 0;
        const auto host = mach_host_self();
        const auto result = host_processor_info(host, PROCESSOR_CPU_LOAD_INFO,
            &processorCount, &infoArray, &infoCount);
        mach_port_deallocate(mach_task_self(), host);
        if (result != KERN_SUCCESS)
            return;

        const bool hasBaseline = prevTicks.size() == processorCount;
        prevTicks.resize(processorCount);
        lastResult.perCore.resize(processorCount);
        lastResult.average = {};
        for (natural_t i = 0; i < processorCount; ++i) {
            const auto load = reinterpret_cast<processor_cpu_load_info_t>(infoArray) + i;
            const CoreTicks current = {load->cpu_ticks[CPU_STATE_USER], load->cpu_ticks[CPU_STATE_SYSTEM],
                load->cpu_ticks[CPU_STATE_IDLE], load->cpu_ticks[CPU_STATE_NICE]};
            CPUUsage usage{};
            if (hasBaseline) {
                // CPU ticks are wrapping 32-bit counters on Darwin.
                const auto user = uint32_t(current.user - prevTicks[i].user);
                const auto system = uint32_t(current.system - prevTicks[i].system);
                const auto idle = uint32_t(current.idle - prevTicks[i].idle);
                const auto nice = uint32_t(current.nice - prevTicks[i].nice);
                const double total = double(user) + system + idle + nice;
                if (total > 0) {
                    usage = {float((double(user) + system + nice) / total * 100),
                        float((double(user) + nice) / total * 100),
                        float(system / total * 100), float(idle / total * 100)};
                }
            }
            prevTicks[i] = current;
            lastResult.perCore[i] = usage;
            lastResult.average.total += usage.total;
            lastResult.average.user += usage.user;
            lastResult.average.system += usage.system;
            lastResult.average.idle += usage.idle;
        }
        if (processorCount > 0) {
            lastResult.average.total /= processorCount;
            lastResult.average.user /= processorCount;
            lastResult.average.system /= processorCount;
            lastResult.average.idle /= processorCount;
        }
        vm_deallocate(mach_task_self(), reinterpret_cast<vm_address_t>(infoArray), infoCount * sizeof(integer_t));
    }
}
