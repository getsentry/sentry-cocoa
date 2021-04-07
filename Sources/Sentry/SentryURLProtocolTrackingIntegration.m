#import "SentryURLProtocolTrackingIntegration.h"
#import "SentryURLProtocolTracker.h"

@interface
SentryURLProtocolTrackingIntegration ()

@property (nonatomic, weak) SentryOptions *options;
@end

@implementation SentryURLProtocolTrackingIntegration

- (void)installWithOptions:(nonnull SentryOptions *)options
{
    self.options = options;
    [self enableURLIntercepting];
}

- (void)enableURLIntercepting
{
    [NSURLProtocol registerClass:SentryURLProtocolTracker.class];
}

@end
