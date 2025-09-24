#import "SentryDefines.h"

@class SentryEvent;
@class SentryOptions;

@protocol SentryNSNotificationCenterWrapper;
@protocol SentryApplicationProvider;
@protocol SentryCurrentDateProvider;

NS_ASSUME_NONNULL_BEGIN

/**
 * Tracks sessions for release health. For more info see:
 * https://docs.sentry.io/workflow/releases/health/#session
 */
NS_SWIFT_NAME(SessionTracker)
@interface SentrySessionTracker : NSObject
SENTRY_NO_INIT

- (instancetype)initWithOptions:(SentryOptions *)options
            applicationProvider:(id<SentryApplicationProvider>)applicationProvider
                   dateProvider:(id<SentryCurrentDateProvider>)dateProvider
             notificationCenter:(id<SentryNSNotificationCenterWrapper>)notificationCenter;

- (void)start;
- (void)stop;

/** Only used for testing */
- (void)removeObservers;

@end

NS_ASSUME_NONNULL_END
