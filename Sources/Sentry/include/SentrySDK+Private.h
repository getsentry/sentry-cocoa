#import "SentrySDK.h"

@class SentryId, SentryAppStartMeasurement;

NS_ASSUME_NONNULL_BEGIN

@interface SentrySDK (Private)

+ (void)captureCrashEvent:(SentryEvent *)event;

/**
 * SDK private field to store the state if onCrashedLastRun was called.
 */
@property (nonatomic, class) BOOL crashedLastRunCalled;

@property (nullable, nonatomic, class) SentryAppStartMeasurement *appStartMeasurement;

+ (SentryHub *)currentHub;

@end

NS_ASSUME_NONNULL_END
