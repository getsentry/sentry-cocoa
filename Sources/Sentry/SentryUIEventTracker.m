#import "SentrySwizzleWrapper.h"
#import <SentryHub+Private.h>
#import <SentrySDK+Private.h>
#import <SentrySDK.h>
#import <SentrySpanProtocol.h>
#import <SentryTransactionContext.h>
#import <SentryUIEventTracker.h>

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>
#endif

NS_ASSUME_NONNULL_BEGIN

static NSString *const SentryUIEventTrackerSwizzleSendAction
    = @"SentryUIEventTrackerSwizzleSendAction";

@interface
SentryUIEventTracker ()

@property (nonatomic, strong) SentrySwizzleWrapper *swizzleWrapper;
@property (nonatomic, strong) SentryDispatchQueueWrapper *dispatchQueueWrapper;

@end

@implementation SentryUIEventTracker

- (instancetype)initWithSwizzleWrapper:(SentrySwizzleWrapper *)swizzleWrapper
                  dispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper
{
    if (self = [super init]) {
        self.swizzleWrapper = swizzleWrapper;
        self.dispatchQueueWrapper = dispatchQueueWrapper;
    }
    return self;
}

- (void)start
{
#if SENTRY_HAS_UIKIT
    [self.swizzleWrapper
        swizzleSendAction:^(NSString *action, UIEvent *event) {
            for (UITouch *touch in event.allTouches) {
                if (touch.phase == UITouchPhaseCancelled || touch.phase == UITouchPhaseEnded) { }
            }

            SentryTransactionContext *context =
                [[SentryTransactionContext alloc] initWithName:@"UIEvent"
                                                     operation:@"ui.action.click"];

            [SentrySDK.currentHub startTransactionWithContext:context
                                                  bindToScope:YES
                                              waitForChildren:YES
                                        customSamplingContext:@{}
                                                  idleTimeout:3.0
                                         dispatchQueueWrapper:self.dispatchQueueWrapper];
        }
                   forKey:SentryUIEventTrackerSwizzleSendAction];

#endif
}

- (void)stop
{
#if SENTRY_HAS_UIKIT
    [self.swizzleWrapper removeSwizzleSendActionForKey:SentryUIEventTrackerSwizzleSendAction];
#endif
}

@end

NS_ASSUME_NONNULL_END
