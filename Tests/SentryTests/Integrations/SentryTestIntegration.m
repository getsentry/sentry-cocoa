#import "SentryTestIntegration.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentryTestIntegration

- (void)installWithOptions:(SentryOptions *)options
{
    self.options = options;
}

@end

NS_ASSUME_NONNULL_END
