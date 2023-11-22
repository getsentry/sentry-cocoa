#import "SentryDefines.h"

@class SentryEvent, SentryOptions, SentryCurrentDateProvider, SentryNSNotificationCenterWrapper;

/**
 * Tracks sessions for release health. For more info see:
 * https://docs.sentry.io/workflow/releases/health/#session
 */
NS_SWIFT_NAME(SessionTracker)
@interface SentrySessionTracker : SENTRY_BASE_OBJECT
SENTRY_NO_INIT

- (instancetype)initWithOptions:(SentryOptions *)options
             notificationCenter:(SentryNSNotificationCenterWrapper *)notificationCenter;

- (void)start;
- (void)stop;
@end
