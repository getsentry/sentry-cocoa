#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(CurrentDateProvider)
@interface SentryCurrentDateProvider : SENTRY_BASE_OBJECT

- (NSDate *)date;

- (dispatch_time_t)dispatchTimeNow;

- (NSInteger)timezoneOffset;

- (uint64_t)systemTime;

@end

NS_ASSUME_NONNULL_END
