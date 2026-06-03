// Sentry-specific self-thread stack cursor with Swift async stitching support.

#include "SentryCrashStackCursor_SelfThread.h"
#include "KSStackCursor_Backtrace.h"
#import <Foundation/Foundation.h>
#include <execinfo.h>

#include "SentryAsyncSafeLog.h"

#define MAX_BACKTRACE_LENGTH                                                                       \
    (KSSC_CONTEXT_SIZE - sizeof(KSStackCursor_Backtrace_Context) / sizeof(void *) - 1)

typedef struct {
    KSStackCursor_Backtrace_Context SelfThreadContextSpacer;
    uintptr_t backtrace[0];
} SelfThreadContext;

static BOOL stitchSwiftAsync = NO;

void
sentrycrashsc_setSwiftAsyncStitching(bool enabled)
{
    stitchSwiftAsync = enabled;
}

void
sentrycrashsc_initSelfThread(KSStackCursor *cursor, int skipEntries)
{
    SelfThreadContext *context = (SelfThreadContext *)cursor->context;

// backtrace_async api is only available from xcode 13 and macOS 12.0+ / iOS 15.0+
#if __clang_major__ >= 13
    int backtraceLength;
    if (stitchSwiftAsync) {
        SENTRY_ASYNC_SAFE_LOG_DEBUG("Retrieving backtrace with async swift stitching...");
        if (@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)) {
            backtraceLength
                = (int)backtrace_async((void **)context->backtrace, MAX_BACKTRACE_LENGTH, NULL);
        } else {
            SENTRY_ASYNC_SAFE_LOG_DEBUG("Retrieving backtrace without async swift stitching...");
            backtraceLength = backtrace((void **)context->backtrace, MAX_BACKTRACE_LENGTH);
        }
    } else {
        SENTRY_ASYNC_SAFE_LOG_DEBUG("Retrieving backtrace without async swift stitching...");
        backtraceLength = backtrace((void **)context->backtrace, MAX_BACKTRACE_LENGTH);
    }
#else
    SENTRY_ASYNC_SAFE_LOG_DEBUG(
        "Retrieving backtrace without async swift stitching (old Xcode versions)...");
    int backtraceLength = backtrace((void **)context->backtrace, MAX_BACKTRACE_LENGTH);
#endif

    SENTRY_ASYNC_SAFE_LOG_DEBUG("Finished retrieving backtrace.");
    kssc_initWithBacktrace(cursor, context->backtrace, backtraceLength, skipEntries + 1);
}
