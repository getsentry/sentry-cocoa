#import "SentryFramesTrackingIntegration.h"
#import "SentryDisplayLinkWrapper.h"
#import "SentryFramesTracker.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface
SentryFramesTrackingIntegration ()

#if SENTRY_HAS_UIKIT
@property (nonatomic, strong) SentryFramesTracker *tracker;
#endif

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
#if SENTRY_HAS_UIKIT
    if (nil != self.tracker) {
        [self.tracker stop];
    }
#endif
}

@end

NS_ASSUME_NONNULL_END
