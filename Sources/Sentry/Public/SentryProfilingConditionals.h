#ifndef SentryProfilingConditionals_h
#    define SentryProfilingConditionals_h

#    include <TargetConditionals.h>

// tvOS and watchOS do not support the kernel APIs required by our profiler
// e.g. mach_msg, thread_suspend, thread_resume
#    if TARGET_OS_WATCH || TARGET_OS_TV
#        define SENTRY_TARGET_PROFILING_SUPPORTED 0
#    else
#        define SENTRY_TARGET_PROFILING_SUPPORTED 1
#    endif

#endif /* SentryProfilingConditionals_h */

// feature flags we'll use to conditionally compile code as we migrate to continuous profiling:
// https://github.com/getsentry/sentry-cocoa/issues/3555
#define SENTRY_PROFILING_MODE_LEGACY 1
#define SENTRY_PROFILING_MODE_CONTINUOUS 0
