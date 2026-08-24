#include <stdexcept>

extern "C" __attribute__((noinline, disable_tail_calls, noreturn, visibility("default"))) void
CrashE2EDynamicImageThrowCPPException(void)
{
    throw std::runtime_error("CrashE2EDynamicImageCPPException");
}
