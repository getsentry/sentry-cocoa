#if __has_include(<Sentry/Sentry.h>)
#import <Sentry/SentryAutoSessionTrackingIntegration.h>
#import <Sentry/SentrySessionTracker.h>
#import <Sentry/SentryOptions.h>
#import <Sentry/SentryHub.h>
#import <Sentry/SentrySDK.h>
#import <Sentry/SentryLog.h>
#else
#import "SentryAutoSessionTrackingIntegration.h"
#import "SentrySessionTracker.h"
#import "SentryOptions.h"
#import "SentryHub.h"
#import "SentrySDK.h"
#import "SentryLog.h"
#endif

NS_ASSUME_NONNULL_BEGIN

@interface SentryAutoSessionTrackingIntegration()

@property(nonatomic, strong) SentrySessionTracker *tracker;

@end

@implementation SentryAutoSessionTrackingIntegration

- (void)installWithOptions:(nonnull SentryOptions *)options {
    if ([options.enableAutoSessionTracking isEqual:@YES]) {
        SentrySessionTracker *tracker = [[SentrySessionTracker alloc] initWithOptions:options];
        [tracker start];
        self.tracker = tracker;
    }
}

@end

NS_ASSUME_NONNULL_END
