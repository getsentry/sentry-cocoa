#ifndef SentryProfilerTestConditionals_h
#define SentryProfilerTestConditionals_h

#import "SentryProfilingConditionals.h"

// Package-only exclusion matches the V9-only Xcode test-plan selection without changing
// production profiling support or the guards used by existing project builds.
#if SENTRY_TARGET_PROFILING_SUPPORTED && (!SWIFT_PACKAGE || !SDK_V10)
#    define SENTRY_PROFILER_TESTS_SUPPORTED 1
#else
#    define SENTRY_PROFILER_TESTS_SUPPORTED 0
#endif

#endif
