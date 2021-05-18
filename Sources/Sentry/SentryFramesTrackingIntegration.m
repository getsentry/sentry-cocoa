#import "SentryFramesTrackingIntegration.h"
#import "SentryDisplayLinkWrapper.h"
#import "SentryFramesTracker.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface
SentryFramesTrackingIntegration ()

@property (nonatomic, strong) SentryFramesTracker *tracker;

@end

@implementation SentryFramesTrackingIntegration

- (void)installWithOptions:(SentryOptions *)options
{
#if SENTRY_HAS_UIKIT
    self.tracker = [SentryFramesTracker sharedInstance];
    [self.tracker start];
#endif
}

- (void)uninstall
{
    [self stop];
}

- (void)stop
{
    if (nil != self.tracker) {
        [self.tracker stop];
    }
}

@end

NS_ASSUME_NONNULL_END
