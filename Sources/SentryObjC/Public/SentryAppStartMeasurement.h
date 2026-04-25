#import <Foundation/Foundation.h>

#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

#if SENTRY_OBJC_UIKIT_AVAILABLE

/**
 * App start type classification for performance tracking.
 */
typedef NS_ENUM(NSUInteger, SentryAppStartType) {
    /// App was already in memory (backgrounded or suspended).
    SentryAppStartTypeWarm,
    /// App was not in memory and had to be loaded from disk.
    SentryAppStartTypeCold,
    /// Start type could not be determined.
    SentryAppStartTypeUnknown,
};

/**
 * App start measurement for performance monitoring.
 *
 * @warning Not available in DebugWithoutUIKit / ReleaseWithoutUIKit configurations.
 */
@interface SentryAppStartMeasurement : NSObject

SENTRY_NO_INIT

/// The type of app start (cold, warm, or unknown).
@property (readonly, nonatomic, assign) SentryAppStartType type;

/// Whether the app was pre-warmed by the system before launch.
@property (readonly, nonatomic, assign) BOOL isPreWarmed;

/// Total duration of the app start in seconds.
@property (readonly, nonatomic, assign) NSTimeInterval duration;

/// Timestamp when the app process started.
@property (readonly, nonatomic, strong) NSDate *appStartTimestamp;

/// System timestamp (mach_absolute_time) when runtime initialization began.
@property (readonly, nonatomic, assign) uint64_t runtimeInitSystemTimestamp;

/// Timestamp when Objective-C runtime initialization began.
@property (readonly, nonatomic, strong) NSDate *runtimeInitTimestamp;

/// Timestamp when static module initializers (+load methods) were invoked.
@property (readonly, nonatomic, strong) NSDate *moduleInitializationTimestamp;

/// Timestamp when the Sentry SDK was initialized.
@property (readonly, nonatomic, strong) NSDate *sdkStartTimestamp;

/// Timestamp when application:didFinishLaunchingWithOptions: completed.
@property (readonly, nonatomic, strong) NSDate *didFinishLaunchingTimestamp;

@end

#endif // SENTRY_OBJC_UIKIT_AVAILABLE

NS_ASSUME_NONNULL_END
