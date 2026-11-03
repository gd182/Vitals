#import "SystemMonitor.h"

#include "../Core/CPUStats.hpp"
#include "../Core/MemoryStats.hpp"
#include "../Core/ProcessStats.hpp"
#include "../Core/GPUStats.hpp"

#include <cstdint>

namespace {
    template<typename T>
    ObjCGPUReadState gpuReadState(const Vitals::GPUReading<T>& reading)
    {
        if (reading) return ObjCGPUReadStateAvailable;
        switch (reading.error()) {
            case Vitals::GPUReadError::unavailable: return ObjCGPUReadStateUnavailable;
            case Vitals::GPUReadError::readFailed: return ObjCGPUReadStateReadFailed;
            case Vitals::GPUReadError::invalidData: return ObjCGPUReadStateInvalidData;
        }
    }
}

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

- (ObjCMemoryPressure)memoryPressure {
    auto pressure = _memory.getMemoryPressure();
    if (!pressure) {
        return ObjCMemoryPressureUnknown;
    }
    switch (pressure.value()) {
        case Vitals::MemoryPressure::normal:
            return ObjCMemoryPressureNormal;
        case Vitals::MemoryPressure::warning:
            return ObjCMemoryPressureWarning;
        case Vitals::MemoryPressure::critical:
            return ObjCMemoryPressureCritical;
        default:
            return ObjCMemoryPressureUnknown;
    }
}

- (ObjCGPUUsage)gpuUsage {
    auto usage = _gpu.getUsage();
    return {
        usage.utilization.value_or(0), usage.renderUtilization.value_or(0),
        usage.tilerUtilization.value_or(0), usage.aneUtilization.value_or(0),
        usage.vramUsed.value_or(0), usage.vramTotal.value_or(0),
        gpuReadState(usage.utilization), gpuReadState(usage.renderUtilization),
        gpuReadState(usage.tilerUtilization), gpuReadState(usage.aneUtilization),
        gpuReadState(usage.vramUsed), gpuReadState(usage.vramTotal)
    };
}

- (ObjCSwapUsage)swapUsage {
    auto usage = _memory.getSwapUsage();
    if (!usage) {
        return {0,0, false};
    }
    return {usage->totalBytes, usage->usedBytes, true};
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

- (void)resetProcessCPUHistory {
    _procInfo.resetCPUHistory();
}

@end
