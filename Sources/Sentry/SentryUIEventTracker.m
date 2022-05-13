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
@property (nonatomic, strong) NSMutableArray<id<SentrySpan>> * transactions;

@end

@implementation SentryUIEventTracker

- (instancetype)initWithSwizzleWrapper:(SentrySwizzleWrapper *)swizzleWrapper
                  dispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper
{
    if (self = [super init]) {
        self.swizzleWrapper = swizzleWrapper;
        self.dispatchQueueWrapper = dispatchQueueWrapper;
        self.transactions = [NSMutableArray new];
    }
    return self;
}

- (void)start
{
#if SENTRY_HAS_UIKIT
    [self.swizzleWrapper
        swizzleSendAction:^(NSString *action, id target, id sender, UIEvent *event) {
            [SentrySDK.currentHub.scope useSpan:^(id<SentrySpan> _Nullable span) {
                [self removeFinishedTransactions];


                NSString *operation = @"ui.action";
                if (event
                    && (event.type == UIEventTypePresses || event.type == UIEventTypeTouches)) {
                    operation = @"ui.action.click";
                }
                
                NSString *transactionName = [self getTransactionName:action
                                                              target:target
                                                              sender:sender];

                SentryTransactionContext *context =
                    [[SentryTransactionContext alloc] initWithName:transactionName
                                                         operation:operation];

                BOOL ongoingScreenLoadTransaction = span != nil && [span.context.operation isEqualToString:@"ui.load"];
                BOOL ongoingManualTransaction = span != nil && ![span.context.operation isEqualToString:@"ui.load"] && ![span.context.operation containsString:@"ui.action."];
                
                
                
                BOOL bindToScope = !ongoingScreenLoadTransaction && !ongoingManualTransaction;
                id<SentrySpan> transaction = [SentrySDK.currentHub startTransactionWithContext:context
                                                      bindToScope:bindToScope
                                            customSamplingContext:@{}
                                                      idleTimeout:defaultIdleTransactionTimeout
                                             dispatchQueueWrapper:self.dispatchQueueWrapper];
                
                [self.transactions addObject:transaction];
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

- (NSString *)getTransactionName:(NSString *)action target:(id)target sender:(id)sender
{
    NSString *viewIdentifier = action;
    if ([sender isKindOfClass:[UIView class]]) {
        UIView *element = sender;
        if (element.accessibilityIdentifier) {
            viewIdentifier = element.accessibilityIdentifier;
        }
    }

    Class targetClass = [target class];

    NSString *transactionName = @"";
    if (targetClass) {
        transactionName =
            [NSString stringWithFormat:@"%@.%@", NSStringFromClass(targetClass), viewIdentifier];
    } else {
        transactionName = viewIdentifier;
    }

    return transactionName;
}

- (void)removeFinishedTransactions {
    NSMutableArray<id<SentrySpan>> *finishedTransactions = [NSMutableArray new];
    for (id<SentrySpan> transaction in self.transactions) {
        if (transaction.isFinished) {
            [finishedTransactions addObject:transaction];
        }
    }
    
    for (id<SentrySpan> transaction in finishedTransactions) {
        [self.transactions removeObject:transaction];
    }
}

@end

NS_ASSUME_NONNULL_END
