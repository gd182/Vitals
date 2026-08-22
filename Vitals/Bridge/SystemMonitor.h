

#ifndef SystemMonitor_h
#define SystemMonitor_h

#import <Foundation/Foundation.h>

typedef struct {
    uint64_t totalBytes;
    uint64_t usedBytes;
    float   usedPercent;
} ObjCMemoryUsage;

typedef struct {
    float total;
    float user;
    float system;
    float idle;
} ObjCCPUUsage;

typedef struct {
    int pid;
    const char *name;
    double value;
} ObjCProcessInfo;

typedef struct {
    ObjCCPUUsage average;
    ObjCCPUUsage *perCore;
    int coreCount;
} ObjCCPUStatsResult;

typedef struct {
    float utilization;
    float renderUtilization;
    float tilerUtilization;
    float aneUtilization;
    uint64_t vramUsed;
    uint64_t vramTotal;
} ObjCGPUUsage;

@interface SystemMonitor : NSObject
- (double)cpuUsage;
- (ObjCCPUStatsResult)cpuStats;
- (ObjCMemoryUsage)memoryUsage;
- (ObjCGPUUsage)gpuUsage;
- (NSArray *)topProcessesByCPU;
- (NSArray *)topProcessesByRAM;
- (void)update;
@end

#endif /* SystemMonitor_h */
