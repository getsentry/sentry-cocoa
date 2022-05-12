#import "SentrySwizzleWrapper.h"
#import <SentryHub+Private.h>
#import <SentrySDK+Private.h>
#import <SentrySDK.h>
#import <SentryScope.h>
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
        swizzleSendAction:^(NSString *action, id target, id sender, UIEvent *event) {
            [SentrySDK.currentHub.scope useSpan:^(id<SentrySpan> _Nullable span) {
                if (span != nil && ![span.context.operation isEqualToString:@"ui.action"]) {
                    return;
                }

                NSString *operation = @"ui.action";
                if (event
                    && (event.type == UIEventTypePresses || event.type == UIEventTypeTouches)) {
                    operation = @"ui.action.click";
                }

                [span finish];

                Class targetClass = [target class];
                NSString *transactionName;

                if (targetClass) {
                    transactionName = [NSString
                        stringWithFormat:@"%@.%@", NSStringFromClass(targetClass), action];
                } else {
                    transactionName = action;
                }

                SentryTransactionContext *context =
                    [[SentryTransactionContext alloc] initWithName:transactionName
                                                         operation:operation];

                [SentrySDK.currentHub startTransactionWithContext:context
                                                      bindToScope:YES
                                            customSamplingContext:@{}
                                                      idleTimeout:defaultIdleTransactionTimeout
                                             dispatchQueueWrapper:self.dispatchQueueWrapper];
            }];
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
