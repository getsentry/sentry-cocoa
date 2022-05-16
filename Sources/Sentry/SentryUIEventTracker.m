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
@property (nonatomic, strong) id<SentrySpan> activeTransaction;
@property (nullable, nonatomic, weak) UIView *activeView;
@property (nonatomic, assign) UIEventType activeEventType;

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
                if (target == nil || sender == nil || ![sender isKindOfClass:[UIView class]]) {
                    return;
                }

                UIView *view = sender;

                NSString *operation = @"ui.action";
                if (event
                    && (event.type == UIEventTypePresses || event.type == UIEventTypeTouches)) {
                    operation = @"ui.action.click";
                }

                NSString *transactionName = [self getTransactionName:action
                                                              target:target
                                                                view:view];

                if (view == self.activeView && event.type != self.activeEventType) {
                    [self.activeTransaction finish];
                }

                SentryTransactionContext *context =
                    [[SentryTransactionContext alloc] initWithName:transactionName
                                                         operation:operation];

                BOOL ongoingScreenLoadTransaction
                    = span != nil && [span.context.operation isEqualToString:@"ui.load"];
                BOOL ongoingManualTransaction = span != nil
                    && ![span.context.operation isEqualToString:@"ui.load"]
                    && ![span.context.operation containsString:@"ui.action."];

                BOOL bindToScope = !ongoingScreenLoadTransaction && !ongoingManualTransaction;
                id<SentrySpan> transaction =
                    [SentrySDK.currentHub startTransactionWithContext:context
                                                          bindToScope:bindToScope
                                                customSamplingContext:@{}
                                                          idleTimeout:defaultIdleTransactionTimeout
                                                 dispatchQueueWrapper:self.dispatchQueueWrapper];

                self.activeTransaction = transaction;
                self.activeView = view;
                self.activeEventType = event.type;
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

- (NSString *)getTransactionName:(NSString *)action target:(id)target view:(UIView *)element
{
    NSString *viewIdentifier = action;
    if (element.accessibilityIdentifier) {
        viewIdentifier = element.accessibilityIdentifier;
    }

    Class targetClass = [target class];
    return [NSString stringWithFormat:@"%@.%@", NSStringFromClass(targetClass), viewIdentifier];
}

@end

NS_ASSUME_NONNULL_END
