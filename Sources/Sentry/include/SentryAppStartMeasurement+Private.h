#if __has_include(<Sentry/PrivatesHeader.h>)
#    import <Sentry/PrivatesHeader.h>
#else
#    import "PrivatesHeader.h"
#endif
#import "SentryAppStartMeasurement.h"

#if SENTRY_UIKIT_AVAILABLE

NS_ASSUME_NONNULL_BEGIN

@interface SentryAppStartMeasurement ()

/**
 * Initializes SentryAppStartMeasurement with the given parameters.
 */
- (instancetype)initWithType:(SentryAppStartType)type
                      isPreWarmed:(BOOL)isPreWarmed
                appStartTimestamp:(NSDate *)appStartTimestamp
       runtimeInitSystemTimestamp:(uint64_t)runtimeInitSystemTimestamp
                         duration:(NSTimeInterval)duration
             runtimeInitTimestamp:(NSDate *)runtimeInitTimestamp
    moduleInitializationTimestamp:(NSDate *)moduleInitializationTimestamp
                sdkStartTimestamp:(NSDate *)sdkStartTimestamp
      didFinishLaunchingTimestamp:(NSDate *)didFinishLaunchingTimestamp;

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_UIKIT_AVAILABLE
