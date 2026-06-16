#import <Foundation/Foundation.h>
#if !__has_include(<SentryObjC/SentryObjCDefines.h>)
#    import "SentryObjCDefines.h"
#else
#    import <SentryObjC/SentryObjCDefines.h>
#endif

#if SENTRY_OBJC_PROFILING_SUPPORTED

@class SentryObjCId;

NS_ASSUME_NONNULL_BEGIN

/// Profiling APIs for Sentry hybrid SDKs.
///
/// These methods may change in any minor release without deprecation.
@interface SentryObjCInternalProfilingApi : NSObject
SENTRY_NO_INIT

/// Starts a profiler session for the given trace ID.
/// Returns the system time when the profiler session started.
- (uint64_t)startFor:(SentryObjCId *)traceId;

/// Collects profiler data between the given system times for the trace.
/// Returns @c nil if no data is available.
- (nullable NSDictionary<NSString *, id> *)collectBetween:(uint64_t)startTime
                                                      and:(uint64_t)endTime
                                                      for:(SentryObjCId *)traceId;

/// Discards the profiler session without collecting data.
- (void)discardFor:(SentryObjCId *)traceId;

@end

NS_ASSUME_NONNULL_END

#endif
