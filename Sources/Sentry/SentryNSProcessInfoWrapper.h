#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryNSProcessInfoWrapper : NSObject

@property (readonly) NSProcessInfoThermalState thermalState;
@property (readonly, getter=isLowPowerModeEnabled) BOOL lowPowerModeEnabled;

- (void)monitorForPowerStateChanges:(id)target callback:(SEL)callback;
- (void)monitorForThermalStateChanges:(id)target callback:(SEL)callback;
- (void)stopMonitoring:(id)target;

@end

NS_ASSUME_NONNULL_END
