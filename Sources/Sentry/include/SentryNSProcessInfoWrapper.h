#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryNSProcessInfoWrapper : NSObject

@property (readonly) NSProcessInfoThermalState thermalState;
@property (readonly, getter=isLowPowerModeEnabled) BOOL lowPowerModeEnabled;
@property (readonly) NSUInteger processorCount;

- (void)monitorForPowerStateChanges:(id)observer callback:(SEL)callback;
- (void)monitorForThermalStateChanges:(id)observer callback:(SEL)callback;
- (void)stopMonitoring:(id)observer;

@end

NS_ASSUME_NONNULL_END
