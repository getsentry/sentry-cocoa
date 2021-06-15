#import "SentryIntegrationProtocol.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Tracks cold and warm app start time for iOS, tvOS, and Mac Catalyst.
 */
@interface SentryAppStartTrackingIntegration : NSObject <SentryIntegrationProtocol>

- (void)stop;

@end

NS_ASSUME_NONNULL_END
