#include <cassert>
#include <expected>
#include <iostream>
#include <type_traits>

#if !defined(__cpp_lib_expected) || __cpp_lib_expected < 202211L
#error Expected and its monadic operations are required
#endif

enum class ReadError { unavailable, invalidValue };

using Reading = std::expected<float, ReadError>;
static_assert(std::is_trivially_destructible_v<Reading>);
static_assert(Reading(0).has_value());

int main()
{
    Reading idle = 0.0f;
    assert(idle && idle.value() == 0);
    Reading missing = std::unexpected(ReadError::unavailable);
    assert(!missing && missing.error() == ReadError::unavailable);
    assert(missing.value_or(-1) == -1);
    bool called = false;
    const auto absent = missing.transform([&](float value) {
        called = true;
        return value * 2;
    });
    assert(!called && !absent);
    const auto valid = Reading(25).and_then([](float value) -> Reading {
        if (value < 0 || value > 100)
            return std::unexpected(ReadError::invalidValue);
        return value;
    }).transform([](float value) { return value / 100; });
    assert(valid.value() == 0.25f);
    const auto recovered = missing.or_else([](ReadError) -> Reading { return 0; });
    assert(recovered.value() == 0);
    try {
        (void)missing.value();
        assert(false);
    } catch (const std::bad_expected_access<ReadError>& error) {
        assert(error.error() == ReadError::unavailable);
    }
    std::expected<void, ReadError> completed;
    assert(completed);
    std::cout << "__cplusplus=" << __cplusplus
              << ", __cpp_lib_expected=" << __cpp_lib_expected
              << ", sizeof(Reading)=" << sizeof(Reading)
              << "\nexpected value/error, monadic operations and exceptions passed\n";
}
