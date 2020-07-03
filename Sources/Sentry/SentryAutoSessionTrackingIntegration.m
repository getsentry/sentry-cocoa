#import "SentryAutoSessionTrackingIntegration.h"
#import "SentryDefaultCurrentDateProvider.h"
#import "SentryHub.h"
#import "SentryLog.h"
#import "SentryMacOSSessionTracker.h"
#import "SentryOptions.h"
#import "SentrySDK.h"
#import "SentryUIKitSessionTracker.h"

NS_ASSUME_NONNULL_BEGIN

@interface
SentryAutoSessionTrackingIntegration ()

@property (nonatomic, strong) SentryUIKitSessionTracker *tracker;
@property (nonatomic, strong) SentryMacOSSessionTracker *macTracker;

@end

@implementation SentryAutoSessionTrackingIntegration

- (void)installWithOptions:(nonnull SentryOptions *)options
{
    if ([options.enableAutoSessionTracking isEqual:@YES]) {
        id<SentryCurrentDateProvider> currentDateProvider =
            [[SentryDefaultCurrentDateProvider alloc] init];

#if SENTRY_HAS_UIKIT

        SentryUIKitSessionTracker *tracker =
            [[SentryUIKitSessionTracker alloc] initWithOptions:options
                                           currentDateProvider:currentDateProvider];
        [tracker start];
        self.tracker = tracker;

#elif TARGET_OS_OSX || TARGET_OS_MACCATALYST

        SentryMacOSSessionTracker *tracker =
            [[SentryMacOSSessionTracker alloc] initWithOptions:options
                                           currentDateProvider:currentDateProvider];
        [tracker start];
        self.macTracker = tracker;
#else
        [SentryLog logWithMessage:@"NO UIKit -> SentryUIKitSessionTracker will not "
                                  @"track sessions automatically."
                         andLevel:kSentryLogLevelDebug];
#endif
    }
}

- (void)stop
{
    if (nil != self.tracker) {
        [self.tracker stop];
    }

    if (nil != self.macTracker) {
        [self.macTracker stop];
    }
}

@end

NS_ASSUME_NONNULL_END
