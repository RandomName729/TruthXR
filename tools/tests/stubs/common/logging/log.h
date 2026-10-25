// Stands in for the emulator's logging in tests that build one source file on
// its own.
#pragma once
#define LOG_INFO(...) ((void)0)
#define LOG_WARNING(...) ((void)0)
#define LOG_ERROR(...) ((void)0)

#define LOG_CRITICAL(...) ((void)0)
#define LOG_TRACE(...) ((void)0)
#include <fmt/format.h>
namespace Common::Log {
enum class Class { Debug };
enum class Level { Critical };
inline void VLog(Class, Level, const char*, int, const char*, fmt::string_view format, fmt::format_args args) { fmt::vprint(format, args); }
}
