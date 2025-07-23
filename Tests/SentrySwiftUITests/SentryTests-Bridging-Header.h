#import "SentryHub+Private.h"
#import "SentryPerformanceTracker.h"
#import "SentryTracer.h"
#import "SentryUIViewControllerPerformanceTracker.h"

@class SentryTimeToDisplayTracker;

@interface SentryPerformanceTracker ()
- (void)clear;
@end

@interface SentryUIViewControllerPerformanceTracker ()
@property (nullable, nonatomic, weak) SentryTimeToDisplayTracker *currentTTDTracker;
@end
