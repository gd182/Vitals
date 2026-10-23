#include "ProcessNames.hpp"

#include <cassert>
#include <cstring>
#include <iostream>
#include <libproc.h>
#include <string_view>

namespace {
    constexpr int testPID = 42;
    constexpr uint64_t expectedStart = 100;
    constexpr std::string_view fallback = "original-name";

    struct Responses {
        uint64_t starts[2] = {expectedStart, expectedStart};
        int failedRead = -1;
        int reads = 0;
        int pathReads = 0;
        bool pathFails = false;
        const char* path = "/Applications/Test.app/Contents/MacOS/Long Process Name";
    } responses;

    void expect(std::string_view name, int reads, int pathReads,
                uint64_t start = expectedStart)
    {
        assert(Vitals::Detail::resolveProcessName(testPID, fallback, start) == name);
        assert(responses.reads == reads);
        assert(responses.pathReads == pathReads);
    }
}

// These symbols replace libproc only in this standalone test executable.
extern "C" int proc_pid_rusage(int pid, int flavor, rusage_info_t* buffer)
{
    assert(pid == testPID);
    assert(flavor == RUSAGE_INFO_V2);
    assert(responses.reads < 2);
    const int index = responses.reads++;
    if (index == responses.failedRead)
        return -1;
    auto* usage = reinterpret_cast<rusage_info_v2*>(buffer);
    *usage = {};
    usage->ri_proc_start_abstime = responses.starts[index];
    return 0;
}

extern "C" int proc_pidpath(int pid, void* buffer, uint32_t bufferSize)
{
    assert(pid == testPID);
    ++responses.pathReads;
    if (responses.pathFails)
        return 0;
    const auto length = std::strlen(responses.path);
    assert(length + 1 <= bufferSize);
    std::memcpy(buffer, responses.path, length + 1);
    return static_cast<int>(length);
}

int main()
{
    expect("Long Process Name", 2, 1);

    responses = {};
    expect(fallback, 0, 0, 0);

    responses = {};
    responses.failedRead = 0;
    expect(fallback, 1, 0);

    responses = {};
    responses.starts[0] = expectedStart + 1;
    expect(fallback, 1, 0);

    responses = {};
    responses.pathFails = true;
    expect(fallback, 1, 1);

    responses = {};
    responses.failedRead = 1;
    expect(fallback, 2, 1);

    responses = {};
    responses.starts[1] = expectedStart + 1;
    expect(fallback, 2, 1);

    responses = {};
    responses.path = "/";
    expect(fallback, 2, 1);

    std::cout << "Process name identity and failure checks passed\n";
}
