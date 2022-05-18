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
                if (target == nil || sender == nil) {
                    return;
                }

                NSString *transactionName = [self getTransactionName:action target:target];

                BOOL sameAction = [self.activeTransaction.name isEqualToString:transactionName];
                if (sameAction) {
                    [self.activeTransaction dispatchIdleTimeout];
                    return;
                }

                [self.activeTransaction finish];

                NSString *operation = [self getOperation:sender];

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

                if ([[sender class] isSubclassOfClass:[UIView class]]) {
                    UIView *view = sender;
                    if (view.accessibilityIdentifier) {
                        [transaction setTagValue:view.accessibilityIdentifier
                                          forKey:@"accessibilityIdentifier"];
                    }
                }

                transaction.finishCallback = ^(void) { self.activeTransaction = nil; };

                self.activeTransaction = transaction;
            }];
        }
                   forKey:SentryUIEventTrackerSwizzleSendAction];
}

- (void)stop
{
    [self.swizzleWrapper removeSwizzleSendActionForKey:SentryUIEventTrackerSwizzleSendAction];
}

- (NSString *)getOperation:(id)sender
{
    Class senderClass = [sender class];
    if ([senderClass isSubclassOfClass:[UIButton class]] ||
        [senderClass isSubclassOfClass:[UIBarButtonItem class]] ||
        [senderClass isSubclassOfClass:[UISegmentedControl class]] ||
        [senderClass isSubclassOfClass:[UIPageControl class]]) {
        return SentrySpanOperationUIActionClick;
    }

    return SentrySpanOperationUIAction;
}

/**
 * The action is an Objective-C selector and might look weird for Swift developers. Therefore we
 * convert the selector to a Swift appropriate format aligned with the Swift #selector syntax.
 * method:first:second:third: gets converted to method(first:second:third:)
 */
- (NSString *)getTransactionName:(NSString *)action target:(id)target
{
    NSString *targetClass = NSStringFromClass([target class]);

    NSArray<NSString *> *componens = [action componentsSeparatedByString:@":"];
    if (componens.count > 2) {
        NSMutableString *result =
            [[NSMutableString alloc] initWithFormat:@"%@.%@(", targetClass, componens.firstObject];

        for (int i = 1; i < (componens.count - 1); i++) {
            [result appendFormat:@"%@:", componens[i]];
        }

        [result appendFormat:@")"];

        return result;
    }

    return [NSString stringWithFormat:@"%@.%@", targetClass, componens.firstObject];
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
