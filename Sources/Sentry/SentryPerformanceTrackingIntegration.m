#import "SentryPerformanceTrackingIntegration.h"
#import "SentryDefaultObjCRuntimeWrapper.h"
#import "SentryDispatchQueueWrapper.h"
#import "SentryLog.h"
#import "SentryOptions+Private.h"
#import "SentrySubClassFinder.h"
#import "SentryUIViewControllerSwizzling.h"

@interface
SentryPerformanceTrackingIntegration ()

#if SENTRY_HAS_UIKIT
@property (nonatomic, strong) SentryUIViewControllerSwizzling *swizzling;
#endif

@end

@implementation SentryPerformanceTrackingIntegration

- (void)installWithOptions:(SentryOptions *)options
{
    if (![self shouldBeEnabled:@[
            [[SentryOptionWithDescription alloc]
                initWithOption:options.enableAutoPerformanceTracking
                    optionName:@"enableAutoPerformanceTracking"],
#if SENTRY_HAS_UIKIT
            [[SentryOptionWithDescription alloc]
                initWithOption:options.enableUIViewControllerTracking
                    optionName:@"enableUIViewControllerTracking"],
#endif
            [[SentryOptionWithDescription alloc] initWithOption:options.isTracingEnabled
                                                     optionName:@"isTracingEnabled"],
            [[SentryOptionWithDescription alloc] initWithOption:options.enableSwizzling
                                                     optionName:@"enableSwizzling"],
        ]]) {
        [options removeEnabledIntegration:NSStringFromClass([self class])];
        return;
    }

#if SENTRY_HAS_UIKIT
    dispatch_queue_attr_t attributes = dispatch_queue_attr_make_with_qos_class(
        DISPATCH_QUEUE_SERIAL, DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    SentryDispatchQueueWrapper *dispatchQueue =
        [[SentryDispatchQueueWrapper alloc] initWithName:"sentry-ui-view-controller-swizzling"
                                              attributes:attributes];

    SentrySubClassFinder *subClassFinder = [[SentrySubClassFinder alloc]
        initWithDispatchQueue:dispatchQueue
           objcRuntimeWrapper:[SentryDefaultObjCRuntimeWrapper sharedInstance]];

    self.swizzling = [[SentryUIViewControllerSwizzling alloc]
           initWithOptions:options
             dispatchQueue:dispatchQueue
        objcRuntimeWrapper:[SentryDefaultObjCRuntimeWrapper sharedInstance]
            subClassFinder:subClassFinder];

    [self.swizzling start];
#else
    [SentryLog logWithMessage:@"NO UIKit -> [SentryPerformanceTrackingIntegration "
                              @"start] does nothing."
                     andLevel:kSentryLevelDebug];
#endif
}

@end
