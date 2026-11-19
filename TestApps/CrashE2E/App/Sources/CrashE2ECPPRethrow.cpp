#include <stdexcept>

__attribute__((noinline, disable_tail_calls)) static void
CrashE2EThrowOrigin()
{
    throw std::runtime_error("CrashE2ECPPRethrow");
}

extern "C" __attribute__((noinline, disable_tail_calls)) void
CrashE2ERethrowSite()
{
    try {
        CrashE2EThrowOrigin();
    } catch (const std::runtime_error &) {
        throw;
    }
}
