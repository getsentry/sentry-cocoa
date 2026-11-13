#ifndef SENTRY_THREAD_SUSPENSION_H
#define SENTRY_THREAD_SUSPENSION_H

#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Process-wide, nonblocking admission shared by nonfatal bulk inspection and profiling.
 *
 * Acquisition returns immediately. Remote-suspension paths acquire before their first suspension.
 * A caller that acquires admission must release it exactly once, after its final balancing resume
 * attempt. A contender must skip remote suspension rather than wait because the current owner may
 * already have suspended the contending thread.
 */
bool sentryThreadSuspensionTryAcquire(void);
void sentryThreadSuspensionRelease(void);

#ifdef __cplusplus
}
#endif

#endif // SENTRY_THREAD_SUSPENSION_H
