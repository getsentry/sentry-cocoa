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

// ObjC integrations conform to this protocol. This should not be used for new
// integrations. New ones should be written in Swift and use the `Sentry.Integration`
// protocol. The main difference is that the ObjC protocol does not inject dependencies
// so conformers need to access the singleton.
@protocol SentryObjCIntegrationProtocol <SentryIntegrationProtocol>

/**
 * Installs the integration and returns YES if successful.
 */
- (BOOL)installWithOptions:(SentryOptions *)options NS_SWIFT_NAME(install(with:));

@end

NS_ASSUME_NONNULL_END
