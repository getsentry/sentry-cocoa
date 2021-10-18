#import "SentryPerformanceTrackingIntegration.h"
#import "SentryDispatchQueueWrapper.h"
#import "SentryLog.h"
#import "SentryUIViewControllerSwizziling.h"

@interface
SentryPerformanceTrackingIntegration ()

@property (nonatomic, strong) SentryOptions *options;
@end

@implementation SentryPerformanceTrackingIntegration

- (void)installWithOptions:(SentryOptions *)options
{
    self.options = options;
    if (options.enableAutoPerformanceTracking) {
#if SENTRY_HAS_UIKIT
        dispatch_queue_attr_t attributes = dispatch_queue_attr_make_with_qos_class(
            DISPATCH_QUEUE_SERIAL, DISPATCH_QUEUE_PRIORITY_HIGH, 0);
        SentryDispatchQueueWrapper *dispatchQueue =
            [[SentryDispatchQueueWrapper alloc] initWithName:"sentry-ui-view-controller-swizzling"
                                                  attributes:attributes];
        SentryUIViewControllerSwizziling *swizzling =
            [[SentryUIViewControllerSwizziling alloc] initWithOptions:options
                                                        dispatchQueue:dispatchQueue];

        [swizzling start];
#else
        [SentryLog logWithMessage:@"NO UIKit -> [SentryPerformanceTrackingIntegration "
                                  @"start] does nothing."
                         andLevel:kSentryLevelDebug];
#endif
    }
}

@end
