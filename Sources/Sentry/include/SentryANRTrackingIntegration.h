#import "SentryANRTrackerV1.h"
#import "SentryBaseIntegration.h"
#import "SentrySwift.h"

NS_ASSUME_NONNULL_BEGIN

static NSString *const SentryANRExceptionType = @"App Hanging";

@interface SentryANRTrackingIntegration
    : SentryBaseIntegration <SentryIntegrationProtocol, SentryANRTrackerDelegate>

- (void)pauseAppHangTracking;
- (void)resumeAppHangTracking;

@end

NS_ASSUME_NONNULL_END
