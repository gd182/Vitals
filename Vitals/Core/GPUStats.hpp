//
//  GPUStats.hpp
//  Vitals
//
//  Created by Алексей on 7/8/26.
//

#ifndef GPUSTATS_HPP
#define GPUSTATS_HPP

#include <cstdint>
#include <expected>
#include <IOKit/IOKitLib.h>

namespace Vitals
{
    enum class GPUReadError : uint8_t
    {
        unavailable, ///< device or meter is missing
        readFailed,  ///< data request failed
        invalidData, ///< data of an incorrect type or range received
    };

    template<typename T> using GPUReading = std::expected<T, GPUReadError>;

    struct GPUInfo {
        GPUReading<float> utilization = std::unexpected(GPUReadError::unavailable);
        GPUReading<float> renderUtilization = std::unexpected(GPUReadError::unavailable);
        GPUReading<float> tilerUtilization = std::unexpected(GPUReadError::unavailable);
        GPUReading<float> aneUtilization = std::unexpected(GPUReadError::unavailable);
        GPUReading<uint64_t> vramUsed = std::unexpected(GPUReadError::unavailable);
        GPUReading<uint64_t> vramTotal = std::unexpected(GPUReadError::unavailable);
    };


    class GPUStats
    {
    public:
        GPUStats();
        ~GPUStats();
        GPUInfo getUsage();
    private:
        io_service_t service = 0;
        GPUReadError serviceError = GPUReadError::unavailable;
        GPUReading<uint64_t> unifiedMemoryTotal = std::unexpected(GPUReadError::unavailable);
    };
};
#endif //GPUSTATS_HPP
