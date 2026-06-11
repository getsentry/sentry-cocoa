#import <Foundation/Foundation.h>

@class SentryObjCId;

NS_ASSUME_NONNULL_BEGIN

/// Profiling APIs for Sentry hybrid SDKs.
///
/// These methods may change in any minor release without deprecation.
@interface SentryObjCInternalProfilingApi : NSObject

/// Starts a profiler session associated with the given trace ID.
/// @return The system time when the profiler session started.
- (uint64_t)startForTraceId:(SentryObjCId *)traceId;

/// Collects profiler session data between two system timestamps.
/// @return The profile data dictionary, or @c nil if collection failed.
- (nullable NSDictionary<NSString *, id> *)collectBetween:(uint64_t)startSystemTime
                                                      and:(uint64_t)endSystemTime
                                               forTraceId:(SentryObjCId *)traceId;

/// Discards profiler session data for the given trace ID.
- (void)discardForTraceId:(SentryObjCId *)traceId;

@end

NS_ASSUME_NONNULL_END
