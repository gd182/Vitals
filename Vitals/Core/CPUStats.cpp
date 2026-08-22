#include "CPUStats.hpp"

#include <cstdio>
#include <mach/mach.h>
#include <mach/processor_info.h>
#include <mach/mach_host.h>

namespace Vitals
{
    CPUStats::~CPUStats()
    {
        this->prevTicks.clear();
    }

    void CPUStats::update()
    {
        natural_t processorCount;
        processor_info_array_t infoArray;
        mach_msg_type_number_t infoCount;
        host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, 
            &processorCount, &infoArray, &infoCount);
        double totalUsage = 0.0;
        double totalUser = 0.0, totalSystem = 0.0, totalIdle = 0.0;
        CPUStatsResult cpuStatsResult;
        if (this->prevTicks.empty())
        {
            this->prevTicks.resize(processorCount);
            cpuStatsResult.perCore.resize(processorCount);
            for (natural_t i = 0; i < processorCount; ++i)
            {
                processor_cpu_load_info_t load = (processor_cpu_load_info_t)infoArray + i;
                this->prevTicks[i] = {load->cpu_ticks[CPU_STATE_USER], 
                                    load->cpu_ticks[CPU_STATE_SYSTEM], 
                                      load->cpu_ticks[CPU_STATE_IDLE], 
                                      load->cpu_ticks[CPU_STATE_NICE]};
            }
        }
        else
        {
            int i = 0;
            cpuStatsResult.perCore.resize(processorCount);
            for (auto &tick : this->prevTicks)
            {
                processor_cpu_load_info_t load = (processor_cpu_load_info_t)infoArray + i;
                uint64_t dUser = load->cpu_ticks[CPU_STATE_USER] - tick.user;
                uint64_t dSystem = load->cpu_ticks[CPU_STATE_SYSTEM] - tick.system;
                uint64_t dIdle = load->cpu_ticks[CPU_STATE_IDLE] - tick.idle;
                uint64_t dNice = load->cpu_ticks[CPU_STATE_NICE] - tick.nice;
                cpuStatsResult.perCore[i].user = (double)dUser / (dUser + dSystem + dIdle + dNice) * 100;
                cpuStatsResult.perCore[i].system = (double)dSystem / (dUser + dSystem + dIdle + dNice) * 100;
                cpuStatsResult.perCore[i].idle = (double)dIdle / (dUser + dSystem + dIdle + dNice) * 100;
                double usage = (double)(dUser + dSystem) / (dUser + dSystem + dIdle + load->cpu_ticks[CPU_STATE_NICE] - tick.nice) * 100;
                cpuStatsResult.perCore[i].total = usage;
                totalUsage += usage;
                this->prevTicks[i] = {load->cpu_ticks[CPU_STATE_USER], 
                                    load->cpu_ticks[CPU_STATE_SYSTEM], 
                                      load->cpu_ticks[CPU_STATE_IDLE], 
                                      load->cpu_ticks[CPU_STATE_NICE]};
                totalUser += (double)dUser / (dUser + dSystem + dIdle + dNice) * 100;
                totalSystem += (double)dSystem / (dUser + dSystem + dIdle + dNice) * 100;
                totalIdle += (double)dIdle / (dUser + dSystem + dIdle + dNice) * 100;
                
                i++;
            }
            totalUsage /= processorCount;
        }
        cpuStatsResult.average.user = totalUser / processorCount;
        cpuStatsResult.average.system = totalSystem / processorCount;
        cpuStatsResult.average.idle = totalIdle / processorCount;
        cpuStatsResult.average.total = totalUsage;
        vm_deallocate(mach_task_self(), (vm_address_t)infoArray, infoCount * sizeof(integer_t));

        this->lastResult = cpuStatsResult;
    }
}
