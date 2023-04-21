#import "SentryANRTracker.h"
#import "SentryBaseIntegration.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryANRTrackingIntegration : SentryBaseIntegration <SentryANRTrackerDelegate>

@end

NS_ASSUME_NONNULL_END
