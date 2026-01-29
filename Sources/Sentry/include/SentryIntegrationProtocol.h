#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class SentryOptions;

// All Integrations conform to this protocol so that the SDK
// can uninstall them when the SDK is closed.
@protocol SentryIntegrationProtocol <NSObject>

/**
 * Uninstalls the integration.
 */
- (void)uninstall;

@end

NS_ASSUME_NONNULL_END
