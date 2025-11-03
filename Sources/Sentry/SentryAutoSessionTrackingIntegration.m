#import "SentryAutoSessionTrackingIntegration.h"
#import "SentryLogC.h"
#import "SentryOptionsConverter.h"
#import "SentryOptionsInternal.h"
#import "SentrySDKInternal.h"
#import "SentrySwift.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryAutoSessionTrackingIntegration ()

@property (nonatomic, strong) SentrySessionTracker *tracker;

@end

@implementation SentryAutoSessionTrackingIntegration

- (BOOL)installWithOptions:(SentryOptionsInternal *)options
{
    if (![super installWithOptions:options]) {
        return NO;
    }

    self.tracker = [SentryDependencyContainer.sharedInstance
        getSessionTrackerWithOptions:[SentryOptionsConverter fromInternal:options]];
    [self.tracker start];

    return YES;
}

- (SentryIntegrationOption)integrationOptions
{
    return kIntegrationOptionEnableAutoSessionTracking;
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
