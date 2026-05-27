#include "SentryKSCrashIgnoreNextSignal.h"

// NOTE: upstream KSCrash does not expose a per-thread signal-ignore API.
// This is currently a no-op.  A future change can wire it through once KSCrash
// gains the corresponding facility.
void
sentrycrash_ignore_next_signal(int signum __attribute__((unused)))
{
}
