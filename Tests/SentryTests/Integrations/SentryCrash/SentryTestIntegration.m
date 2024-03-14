#import "SentryTestIntegration.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentryTestIntegration

- (BOOL)installWithOptions:(SentryOptions *)options
{
    self.options = options;
    return YES;
}

- (void)uninstall
{
}

@end

NS_ASSUME_NONNULL_END
