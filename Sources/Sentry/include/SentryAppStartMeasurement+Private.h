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

/**
 * The extended app start span, set when the user calls @c extendAppLaunch().
 * Its @c timestamp is the authoritative end time of the extended app start, regardless of how
 * the span was finished (direct @c finish(), child span completion, or @c finishExtendedAppLaunch).
 *
 * Default is nil.
 */
@property (nonatomic, strong, nullable) id<SentrySpan> extendedAppStartSpan;

/**
 * Returns the effective app start duration in seconds.
 *
 * When @c extendedAppStartSpan is set and finished, the duration spans from
 * @c appStartTimestamp to the span's end timestamp. Otherwise falls back to @c duration.
 */
@property (readonly, nonatomic, assign) NSTimeInterval effectiveDuration;

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_UIKIT_AVAILABLE
