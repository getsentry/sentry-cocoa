#import <Foundation/Foundation.h>

#import "SentryObjCDefines.h"

NS_ASSUME_NONNULL_BEGIN

#if SENTRY_OBJC_UIKIT_AVAILABLE

typedef NS_ENUM(NSUInteger, SentryAppStartType) {
    SentryAppStartTypeWarm,
    SentryAppStartTypeCold,
    SentryAppStartTypeUnknown,
};

/**
 * App start measurement for performance monitoring.
 *
 * @warning Not available in DebugWithoutUIKit / ReleaseWithoutUIKit configurations.
 */
@interface SentryAppStartMeasurement : NSObject

SENTRY_NO_INIT

@property (readonly, nonatomic, assign) SentryAppStartType type;
@property (readonly, nonatomic, assign) BOOL isPreWarmed;
@property (readonly, nonatomic, assign) NSTimeInterval duration;
@property (readonly, nonatomic, strong) NSDate *appStartTimestamp;
@property (readonly, nonatomic, assign) uint64_t runtimeInitSystemTimestamp;
@property (readonly, nonatomic, strong) NSDate *runtimeInitTimestamp;
@property (readonly, nonatomic, strong) NSDate *moduleInitializationTimestamp;
@property (readonly, nonatomic, strong) NSDate *sdkStartTimestamp;
@property (readonly, nonatomic, strong) NSDate *didFinishLaunchingTimestamp;

@end

#endif // SENTRY_OBJC_UIKIT_AVAILABLE

NS_ASSUME_NONNULL_END
