#import "SentrySessionReplayIntegration.h"
#import "SentryClient+Private.h"
#import "SentryDependencyContainer.h"
#import "SentryGlobalEventProcessor.h"
#import "SentryHub+Private.h"
#import "SentryOptions.h"
#import "SentryRandom.h"
#import "SentrySDK+Private.h"
#import "SentrySessionReplay.h"
#import "SentrySwift.h"

#if SENTRY_HAS_UIKIT
#    import "SentryUIApplication.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentrySessionReplayIntegration {
    SentrySessionReplay *sessionReplay;
}

- (BOOL)installWithOptions:(nonnull SentryOptions *)options
{
    if ([super installWithOptions:options] == NO) {
        return NO;
    }

    if (@available(iOS 16.0, tvOS 16.0, *)) {
        if (options.sessionReplayOptions.replaysSessionSampleRate == 0
            && options.sessionReplayOptions.replaysOnErrorSampleRate == 0) {
            return NO;
        }

        sessionReplay = [[SentrySessionReplay alloc] initWithSettings:options.sessionReplayOptions];

        [sessionReplay
                  start:SentryDependencyContainer.sharedInstance.application.windows.firstObject
            fullSession:[self shouldReplayFullSession:options.sessionReplayOptions
                                                          .replaysSessionSampleRate]];

        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(stop)
                                                   name:UIApplicationDidEnterBackgroundNotification
                                                 object:nil];

        [SentryGlobalEventProcessor.shared
            addEventProcessor:^SentryEvent *_Nullable(SentryEvent *_Nonnull event) {
                [self->sessionReplay replayForEvent:event];
                return event;
            }];

        return YES;
    } else {
        return NO;
    }
}

- (void)stop
{
    [sessionReplay stop];
}

- (SentryIntegrationOption)integrationOptions
{
    return kIntegrationOptionEnableReplay;
}

- (void)uninstall
{
}

- (BOOL)shouldReplayFullSession:(CGFloat)rate
{
    return [SentryDependencyContainer.sharedInstance.random nextNumber] < rate;
}

@end
NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
