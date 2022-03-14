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
    if ([self shouldBeDisabled:options]) {
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

- (BOOL)shouldBeDisabled:(SentryOptions *)options
{
    if (!options.enableAutoPerformanceTracking) {
        [SentryLog logWithMessage:@"AutoUIPerformanceTracking disabled. Will not start "
                                  @"SentryPerformanceTrackingIntegration."
                         andLevel:kSentryLevelDebug];
        return YES;
    }

    if (!options.isTracingEnabled) {
        [SentryLog logWithMessage:@"No tracesSampleRate and tracesSampler set. Will not start "
                                  @"SentryPerformanceTrackingIntegration."
                         andLevel:kSentryLevelDebug];
        return YES;
    }

    if (!options.enableSwizzling) {
        [SentryLog logWithMessage:@"enableSwizzling disabled. Will not start "
                                  @"SentryPerformanceTrackingIntegration."
                         andLevel:kSentryLevelDebug];
        return YES;
    }

    return NO;
}

@end
