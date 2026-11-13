#import "SentryProfilingRuntime.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryCompiler.h"

BOOL
sentry_threadSanitizerIsPresent(void)
{
#    if COMPILER_HAS_CLANG_FEATURE(thread_sanitizer)
    return YES;
#    else
    return NO;
#    endif
}

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
