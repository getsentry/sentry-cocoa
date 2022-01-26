#import "SentryIntegrationProvider.h"
#import "SentrySDK+Private.h"

@implementation SentryIntegrationProvider

- (NSArray<NSString *> *)enabledIntegrations
{
    return SentrySDK.enabledIntegrations;
}

@end
