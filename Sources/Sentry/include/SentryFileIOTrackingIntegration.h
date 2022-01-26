#import "SentryIntegrationProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryFileIOTrackingIntegration : NSObject <SentryIntegrationProtocol>

@property (nonatomic, assign) BOOL isEnabled;

@end

NS_ASSUME_NONNULL_END
