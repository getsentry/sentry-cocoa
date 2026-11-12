#include "SentryThreadSuspension.h"
#include <stdatomic.h>

// Coordinates the SDK's nonfatal bulk-inspection and profiler suspension paths. atomic_flag is
// guaranteed lock-free, so a contender can yield without waiting on an owner that may have
// suspended its thread.
static atomic_flag g_threadSuspensionAdmission = ATOMIC_FLAG_INIT;

bool
sentryThreadSuspensionTryAcquire(void)
{
    return !atomic_flag_test_and_set_explicit(&g_threadSuspensionAdmission, memory_order_acquire);
}

void
sentryThreadSuspensionRelease(void)
{
    atomic_flag_clear_explicit(&g_threadSuspensionAdmission, memory_order_release);
}
