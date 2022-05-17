#import "SentrySwizzleWrapper.h"
#import <SentryHub+Private.h>
#import <SentrySDK+Private.h>
#import <SentrySDK.h>
#import <SentryScope.h>
#import <SentrySpanOperations.h>
#import <SentrySpanProtocol.h>
#import <SentryTracer.h>
#import <SentryTransactionContext.h>
#import <SentryUIEventTracker.h>

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

static NSString *const SentryUIEventTrackerSwizzleSendAction
    = @"SentryUIEventTrackerSwizzleSendAction";

@interface
SentryUIEventTracker ()

@property (nonatomic, strong) SentrySwizzleWrapper *swizzleWrapper;
@property (nonatomic, strong) SentryDispatchQueueWrapper *dispatchQueueWrapper;
@property (nullable, nonatomic, strong) SentryTracer *activeTransaction;
@property (nullable, nonatomic, weak) UIView *activeView;
@property (nonatomic, assign) UIEventType activeEventType;

@end

#endif

@implementation SentryUIEventTracker

#if SENTRY_HAS_UIKIT

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
    [self.swizzleWrapper
        swizzleSendAction:^(NSString *action, id target, id sender, UIEvent *event) {
            [SentrySDK.currentHub.scope useSpan:^(id<SentrySpan> _Nullable span) {
                if (target == nil || sender == nil || ![sender isKindOfClass:[UIView class]]) {
                    return;
                }

                UIView *view = sender;

                BOOL sameView = self.activeView != nil && view == self.activeView;

                NSString *operation = [self getOperation:event];
                BOOL sameOperation =
                    [self.activeTransaction.context.operation isEqualToString:operation];

                if (sameView && sameOperation) {
                    [self.activeTransaction dispatchIdleTimeout];
                    return;
                }

                [self.activeTransaction finish];

                NSString *transactionName = [self getTransactionName:action
                                                              target:target
                                                                view:view];

                SentryTransactionContext *context =
                    [[SentryTransactionContext alloc] initWithName:transactionName
                                                         operation:operation];

                BOOL ongoingScreenLoadTransaction = span != nil &&
                    [span.context.operation isEqualToString:SentrySpanOperationUILoad];
                BOOL ongoingManualTransaction = span != nil
                    && ![span.context.operation isEqualToString:SentrySpanOperationUILoad]
                    && ![span.context.operation containsString:SentrySpanOperationUIAction];

                BOOL bindToScope = !ongoingScreenLoadTransaction && !ongoingManualTransaction;
                SentryTracer *transaction =
                    [SentrySDK.currentHub startTransactionWithContext:context
                                                          bindToScope:bindToScope
                                                customSamplingContext:@{}
                                                          idleTimeout:defaultIdleTransactionTimeout
                                                 dispatchQueueWrapper:self.dispatchQueueWrapper];

                transaction.finishCallback = ^(void) {
                    self.activeTransaction = nil;
                    self.activeView = nil;
                };

                self.activeTransaction = transaction;
                self.activeView = view;
                self.activeEventType = event.type;
            }];
        }
                   forKey:SentryUIEventTrackerSwizzleSendAction];
}

- (void)stop
{
    [self.swizzleWrapper removeSwizzleSendActionForKey:SentryUIEventTrackerSwizzleSendAction];
}

- (NSString *)getOperation:(UIEvent *)event
{
    NSString *operation = @"ui.action";
    if (event && event.type == UIEventTypeTouches) {
        operation = @"ui.action.click";
    }

    return operation;
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

NS_ASSUME_NONNULL_END

#endif

NS_ASSUME_NONNULL_BEGIN

+ (BOOL)isUIEventOperation:(NSString *)operation
{
    if ([operation isEqualToString:SentrySpanOperationUIAction]) {
        return YES;
    }
    if ([operation isEqualToString:SentrySpanOperationUIActionClick]) {
        return YES;
    }
    return NO;
}

@end

NS_ASSUME_NONNULL_END
