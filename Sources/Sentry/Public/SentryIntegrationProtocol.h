#import "SentryDefines.h"
#import <Foundation/Foundation.h>

@class SentryOptions;

NS_ASSUME_NONNULL_BEGIN

@protocol SentryIntegrationProtocol <NSObject>

/**
 * Installs the integration and returns @c YES if successful.
 */
- (BOOL)installWithOptions:(SentryOptions *)options;

/**
 * Uninstalls the integration.
 */
@optional
- (void)uninstall;

@end

NS_ASSUME_NONNULL_END
