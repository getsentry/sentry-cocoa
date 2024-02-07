#import "SentryANRTracker.h"
#import "SentryBaseIntegration.h"
#import "SentryIntegrationProtocol.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

static NSString *const SentryANRExceptionType = @"App Hanging";

@interface SentryANRTrackingIntegration
    : SentryBaseIntegration <SentryIntegrationProtocol, SentryANRTrackerDelegate>

@end

NS_ASSUME_NONNULL_END
