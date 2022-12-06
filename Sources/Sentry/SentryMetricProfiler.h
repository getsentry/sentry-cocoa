#import <Foundation/Foundation.h>

@class SentryNSNotificationCenterWrapper;

NS_ASSUME_NONNULL_BEGIN

/**
 * A profiler that gathers various time-series and event-based metrics on the app process, such as
 * CPU and memory usage timeseries and thermal and memory pressure warning notifications.
 */
@interface SentryMetricProfiler : NSObject

- (instancetype)initWithNotificationCenterWrapper:
                    (SentryNSNotificationCenterWrapper *)notificationCenterWrapper
                                 profileStartTime:(uint64_t)profileStartTime;
- (void)start;
- (void)stop;

/** @return All data gathered during the profiling run. */
- (NSData *)serialize;

@end

NS_ASSUME_NONNULL_END
