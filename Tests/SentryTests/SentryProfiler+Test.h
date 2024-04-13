#import "SentryProfilingConditionals.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryDefines.h"
#    import "SentryProfiler+Private.h"
#    import <Foundation/Foundation.h>

@class SentryDebugMeta;

NS_ASSUME_NONNULL_BEGIN

@interface
SentryProfiler ()

#    if defined(TEST) || defined(TESTCI)

+ (SentryProfiler *)getCurrentProfiler;

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

#    endif // defined(TEST) || defined(TESTCI)

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
