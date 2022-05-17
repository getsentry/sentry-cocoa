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
                if (target == nil || sender == nil) {
                    return;
                }

                if (![sender isKindOfClass:[UIButton class]]
                    && ![sender isKindOfClass:[UISegmentedControl class]]
                    && ![sender isKindOfClass:[UIPageControl class]]) {
                    return;
                }

                UIView *view = sender;
                BOOL sameView = self.activeView != nil && view == self.activeView;
                if (sameView) {
                    [self.activeTransaction dispatchIdleTimeout];
                    return;
                }

                [self.activeTransaction finish];

                NSString *transactionName = [self getTransactionName:action
                                                              target:target
                                                                view:view];

                SentryTransactionContext *context = [[SentryTransactionContext alloc]
                    initWithName:transactionName
                       operation:SentrySpanOperationUIActionClick];

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

- (NSString *)getTransactionName:(NSString *)action target:(id)target view:(UIView *)element
{
    NSString *targetClass = NSStringFromClass([target class]);

    if (element.accessibilityIdentifier) {
        return [NSString stringWithFormat:@"%@.%@", targetClass, element.accessibilityIdentifier];
    }

    // The action is an Objective-C selector and might look weird for Swift developers. Therefore we
    // convert the selector to a Swift appropriate format aligned with the Swift #selector syntax.
    // method:first:second:third: gets converted to method(first:second:third:)

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
