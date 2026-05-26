#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryObjCExperimentalOptions : NSObject

@property (nonatomic) BOOL enableUnhandledCPPExceptionsV2;
@property (nonatomic) BOOL enableWatchdogTerminationsV2;
@property (nonatomic) BOOL enableReplayNetworkDetailsCapturing;

- (instancetype)init;

@end

NS_ASSUME_NONNULL_END
