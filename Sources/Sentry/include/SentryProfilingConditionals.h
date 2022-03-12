#ifndef SentryProfilingConditionals_h
#define SentryProfilingConditionals_h

#include <TargetConditionals.h>

// tvOS and watchOS do not support the kernel APIs required by our profiler
// e.g. mach_msg, thread_suspend, thread_resume
#define SENTRY_TARGET_PROFILING_SUPPORTED                                                          \
    (TARGET_OS_IOS || TARGET_OS_MACCATALYST || TARGET_OS_SIMULATOR || TARGET_OS_OSX)

#endif /* SentryProfilingConditionals_h */
