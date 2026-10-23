#pragma once

#include <string>
#include <string_view>
#include <cstdint>

namespace Vitals::Detail {
    std::string resolveProcessName(int pid, std::string_view fallback, uint64_t expectedStartTime);
}