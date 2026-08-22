#import "SystemMonitor.h"

#include "../Core/CPUStats.hpp"
#include "../Core/MemoryStats.hpp"
#include "../Core/ProcessStats.hpp"
#include "../Core/GPUStats.hpp"

#include <cstdint>

@implementation SystemMonitor {
    Vitals::CPUStats _cpu;
    Vitals::MemoryStats _memory;
    Vitals::ProcessStats _procInfo;
    Vitals::GPUStats _gpu;
}

- (double)cpuUsage {
    return _cpu.getUsage();
}

- (ObjCCPUStatsResult)cpuStats {
    const auto& result = _cpu.cpuStats();
    ObjCCPUStatsResult out;
    out.average = { result.average.total, result.average.user, result.average.system, result.average.idle };
    out.coreCount = (int)result.perCore.size();
    out.perCore = result.perCore.empty() ? nullptr : (ObjCCPUUsage *)result.perCore.data();
    return out;
}

- (void)update {
    _cpu.update();
}

- (ObjCMemoryUsage)memoryUsage {
    auto usage = _memory.getUsage();
    return { usage.totalBytes, usage.usedBytes, usage.usedPercent };
}

- (ObjCGPUUsage)gpuUsage {
    auto usage = _gpu.getUsage();
    return { usage.utilization, usage.renderUtilization, usage.tilerUtilization, usage.aneUtilization, usage.vramUsed, usage.vramTotal};
}

- (NSArray *)topProcessesByCPU {
    NSMutableArray *result = [NSMutableArray array];
    for (const auto& p : _procInfo.getProcCPUInfo()) {
        [result addObject:@{
            @"pid": @(p.pid),
            @"name": @(p.name.c_str()),
            @"value": @(p.value)
        }];
    }
    return result;
}

- (NSArray *)topProcessesByRAM {
    NSMutableArray *result = [NSMutableArray array];
    for (const auto& p : _procInfo.getProcRAMInfo()) {
        [result addObject:@{ @"pid": @(p.pid), @"name": @(p.name.c_str()), @"value": @(p.value) }];
    }
    return result;
}

@end
