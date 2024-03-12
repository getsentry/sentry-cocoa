#import "SentryANRTracker.h"
#import "SentryBaseIntegration.h"
#import <Foundation/Foundation.h>
#import "SentrySwift.h"

NS_ASSUME_NONNULL_BEGIN

static NSString *const SentryANRExceptionType = @"App Hanging";

@interface SentryANRTrackingIntegration
    : SentryBaseIntegration <SentryIntegrationProtocol, SentryANRTrackerDelegate>

@end

NS_ASSUME_NONNULL_END
