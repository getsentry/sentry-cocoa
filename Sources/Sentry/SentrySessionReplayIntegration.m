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

#if SENTRY_HAS_UIKIT && !TARGET_OS_VISION
#    import "SentryUIApplication.h"

NS_ASSUME_NONNULL_BEGIN

API_AVAILABLE(ios(16.0), tvos(16.0))
@interface
SentrySessionReplayIntegration ()
@property (nonatomic, strong) SentrySessionReplay *sessionReplay;
@end

@implementation SentrySessionReplayIntegration

- (BOOL)installWithOptions:(nonnull SentryOptions *)options
{
    if ([super installWithOptions:options] == NO) {
        return NO;
    }

    if (@available(iOS 16.0, tvOS 16.0, *)) {
        BOOL shouldReplayFullSession =
            [self shouldReplayFullSession:options.sessionReplayOptions.replaysSessionSampleRate];

        if (!shouldReplayFullSession
            && options.sessionReplayOptions.replaysOnErrorSampleRate == 0) {
            return NO;
        }

        self.sessionReplay = [[SentrySessionReplay alloc]
            initWithSettings:options.sessionReplayOptions
                dateProvider:SentryDependencyContainer.sharedInstance.dateProvider];

        [self.sessionReplay
                  start:SentryDependencyContainer.sharedInstance.application.windows.firstObject
            fullSession:[self shouldReplayFullSession:options.sessionReplayOptions
                                                          .replaysSessionSampleRate]];

        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(stop)
                                                   name:UIApplicationDidEnterBackgroundNotification
                                                 object:nil];

        [SentryGlobalEventProcessor.shared
            addEventProcessor:^SentryEvent *_Nullable(SentryEvent *_Nonnull event) {
                [self.sessionReplay replayForEvent:event];
                return event;
            }];

        return YES;
    } else {
        return NO;
    }
}

- (void)stop
{
    [self.sessionReplay stop];
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
