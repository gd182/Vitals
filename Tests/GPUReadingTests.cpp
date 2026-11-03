#include "GPUStats.hpp"

#include <cassert>
#include <iostream>
#include <type_traits>

namespace {
    template<typename T>
    bool startsUnavailable(const Vitals::GPUReading<T>& reading, const char* name)
    {
        if (!reading && reading.error() == Vitals::GPUReadError::unavailable)
            return true;
        std::cerr << name << " must initially be unavailable, not a successful zero\n";
        return false;
    }
}

int main()
{
    using namespace Vitals;
    static_assert(std::is_same_v<GPUReading<float>, std::expected<float, GPUReadError>>);
    GPUInfo info{};
    bool valid = true;
    valid &= startsUnavailable(info.utilization, "utilization");
    valid &= startsUnavailable(info.renderUtilization, "renderUtilization");
    valid &= startsUnavailable(info.tilerUtilization, "tilerUtilization");
    valid &= startsUnavailable(info.aneUtilization, "aneUtilization");
    valid &= startsUnavailable(info.vramUsed, "vramUsed");
    valid &= startsUnavailable(info.vramTotal, "vramTotal");
    if (!valid) return 1;

    GPUReading<float> idle = 0.0f;
    GPUReading<uint64_t> unused = uint64_t{0};
    assert(idle && *idle == 0 && unused && *unused == 0);
    for (const auto error : {GPUReadError::unavailable, GPUReadError::readFailed, GPUReadError::invalidData}) {
        const GPUReading<float> failed = std::unexpected(error);
        assert(!failed && failed.error() == error);
    }
    std::cout << "GPU reading defaults, valid zero and typed errors passed\n";
}
