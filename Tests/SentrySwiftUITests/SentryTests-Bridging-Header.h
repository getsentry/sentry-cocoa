#import "SentryHub+Private.h"
#import "SentryPerformanceTracker.h"
#import "SentrySDK+Private.h"
#import "SentrySDK+Tests.h"
#import "SentryTracer.h"
#import "SentryUIViewControllerPerformanceTracker.h"

@class SentryTimeToDisplayTracker;

@interface SentryPerformanceTracker ()
- (void)clear;
@end

@interface SentryUIViewControllerPerformanceTracker ()
@property (nullable, nonatomic, weak) SentryTimeToDisplayTracker *currentTTDTracker;
@end

@interface SentrySDK ()
+ (void)setStartOptions:(nullable SentryOptions *)options;
@end
