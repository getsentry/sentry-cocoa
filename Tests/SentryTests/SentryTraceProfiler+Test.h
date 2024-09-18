#import "SentryProfilingConditionals.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryDefines.h"
#    import "SentryTraceProfiler.h"
#    import <Foundation/Foundation.h>

@class SentryProfiler;

SENTRY_EXTERN NSTimer *_Nullable _sentry_threadUnsafe_traceProfileTimeoutTimer;

@interface
SentryTraceProfiler ()

#    if defined(TEST) || defined(TESTCI) || defined(DEBUG)

+ (SentryProfiler *_Nullable)getCurrentProfiler;

/**
 * Provided as a pass-through to the SentryProfiledTracerConcurrency function of the same name,
 * because that file contains C++ which cannot be included in test targets via ObjC bridging headers
 * for usage in Swift.
 */
+ (void)resetConcurrencyTracking;

/**
 * Provided as a pass-through to the SentryProfiledTracerConcurrency function of the same name,
 * because that file contains C++ which cannot be included in test targets via ObjC bridging headers
 * for usage in Swift.
 */
+ (NSUInteger)currentProfiledTracers;

#    endif // defined(TEST) || defined(TESTCI) || defined(DEBUG)

@end

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
