#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

@class SentryDispatchQueueWrapper;

@interface SentryUIDeviceWrapper : NSObject

#if TARGET_OS_IOS
- (instancetype)init;
- (instancetype)initWithDispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper;
- (void)stop;
- (SENTRY_UIDeviceOrientation)orientation;
- (BOOL)isBatteryMonitoringEnabled;
- (SENTRY_UIDeviceBatteryState)batteryState;
- (float)batteryLevel;
#endif

@end

NS_ASSUME_NONNULL_END
