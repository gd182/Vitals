//
//  GPUStats.hpp
//  Vitals
//
//  Created by Алексей on 7/8/26.
//

#ifndef GPUSTATS_HPP
#define GPUSTATS_HPP

#include <cstdint>
#include <IOKit/IOKitLib.h>

namespace Vitals
{
    struct GPUInfo {
        float utilization;
        float renderUtilization;
        float tilerUtilization;
        float aneUtilization;
        uint64_t vramUsed;
        uint64_t vramTotal;
    };


    class GPUStats
    {
    public:
        GPUStats();
        ~GPUStats();
        GPUInfo getUsage();
    private:
        io_service_t service = 0;
        GPUInfo gpuInfo = {0, 0, 0, 0, 0};
    };
};
#endif //GPUSTATS_HPP
