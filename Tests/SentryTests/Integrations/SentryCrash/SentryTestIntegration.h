#import <Foundation/Foundation.h>

@class SentryOptions;

NS_ASSUME_NONNULL_BEGIN

/// Test integration that conforms to the integration protocol requirements.
/// Since SentryIntegrationProtocol is now a pure Swift protocol, ObjC test
/// integrations just need to implement the required methods.
@interface SentryTestIntegration : NSObject

@property (nonatomic, strong) SentryOptions *options;

- (BOOL)installWithOptions:(SentryOptions *)options;
- (void)uninstall;

@end

NS_ASSUME_NONNULL_END
