#import "SentryUIViewControllerPerformanceTracker.h"

#if SENTRY_HAS_UIKIT

#    import "SentryDependencyContainer.h"
#    import "SentryHub.h"
#    import "SentryLog.h"
#    import "SentryOptions.h"
#    import "SentryPerformanceTracker.h"
#    import "SentrySDK+Private.h"
#    import "SentrySpanId.h"
#    import "SentrySpanOperation.h"
#    import "SentrySwift.h"
#    import "SentryTimeToDisplayTracker.h"
#    import "SentryTraceOrigin.h"
#    import "SentryTracer.h"
#    import <SentryInAppLogic.h>
#    import <UIKit/UIKit.h>
#    import <objc/runtime.h>

@interface SentryUIViewControllerPerformanceTracker ()

@property (nonatomic, strong) SentryPerformanceTracker *tracker;
@property (nullable, nonatomic, weak) SentryTimeToDisplayTracker *currentTTDTracker;
@property (nonatomic, strong, readonly) SentryDispatchQueueWrapper *dispatchQueueWrapper;

@end

@implementation SentryUIViewControllerPerformanceTracker

+ (instancetype)shared
{
    static SentryUIViewControllerPerformanceTracker *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (instancetype)init
{
    if (self = [super init]) {
        self.tracker = SentryPerformanceTracker.shared;

        SentryOptions *options = [SentrySDK options];
        self.inAppLogic = [[SentryInAppLogic alloc] initWithInAppIncludes:options.inAppIncludes
                                                            inAppExcludes:options.inAppExcludes];

        _alwaysWaitForFullDisplay = NO;
        _dispatchQueueWrapper = SentryDependencyContainer.sharedInstance.dispatchQueueWrapper;
    }
    return self;
}

- (SentrySpan *)viewControllerPerformanceSpan:(UIViewController *)controller
{
    SentrySpanId *spanId
        = objc_getAssociatedObject(controller, &SENTRY_UI_PERFORMANCE_TRACKER_SPAN_ID);
    return [self.tracker getSpan:spanId];
}

- (void)viewControllerLoadView:(UIViewController *)controller
              callbackToOrigin:(void (^)(void))callbackToOrigin
{
    if (![self.inAppLogic isClassInApp:[controller class]]) {
        SENTRY_LOG_DEBUG(
            @"Won't track view controller that is not part of the app bundle: %@.", controller);
        callbackToOrigin();
        return;
    }

    SentryOptions *options = [SentrySDK options];

    if ([SentrySwizzleClassNameExclude
            shouldExcludeClassWithClassName:NSStringFromClass([controller class])
                   swizzleClassNameExcludes:options.swizzleClassNameExcludes]) {
        SENTRY_LOG_DEBUG(@"Won't track view controller because it's excluded with the option "
                         @"swizzleClassNameExcludes: %@",
            controller);
        callbackToOrigin();
        return;
    }

    [self limitOverride:@"loadView"
                  target:controller
        callbackToOrigin:callbackToOrigin
                   block:^{
                       SENTRY_LOG_DEBUG(@"Tracking loadView");
                       [self startRootSpanFor:controller];
                       [self measurePerformance:@"loadView"
                                         target:controller
                               callbackToOrigin:callbackToOrigin];
                   }];
}

- (void)viewControllerViewDidLoad:(UIViewController *)controller
                 callbackToOrigin:(void (^)(void))callbackToOrigin
{
    [self limitOverride:@"viewDidLoad"
                  target:controller
        callbackToOrigin:callbackToOrigin
                   block:^{
                       SENTRY_LOG_DEBUG(@"Tracking viewDidLoad");
                       [self startRootSpanFor:controller];
                       [self measurePerformance:@"viewDidLoad"
                                         target:controller
                               callbackToOrigin:callbackToOrigin];
                   }];
}

- (void)startRootSpanFor:(UIViewController *)controller
{
    SentrySpanId *spanId
        = objc_getAssociatedObject(controller, &SENTRY_UI_PERFORMANCE_TRACKER_SPAN_ID);

    // If the user manually calls loadView outside the lifecycle we don't start a new transaction
    // and override the previous id stored.
    if (spanId == nil) {

        // The tracker must create a new transaction and bind it to the scope when there is no
        // active span. If the user didn't call reportFullyDisplayed, the previous UIViewController
        // transaction is still bound to the scope because it waits for its children to finish,
        // including the TTFD span. Therefore, we need to finish the TTFD span so the tracer can
        // finish and remove itself from the scope. We don't need to finish the transaction because
        // we already finished it in viewControllerViewDidAppear.
        if (self.tracker.activeSpanId == nil) {
            [self.currentTTDTracker finishSpansIfNotFinished];
        }

        NSString *name = [SwiftDescriptor getViewControllerClassName:controller];
        spanId = [self.tracker startSpanWithName:name
                                      nameSource:kSentryTransactionNameSourceComponent
                                       operation:SentrySpanOperationUiLoad
                                          origin:SentryTraceOriginAutoUIViewController];

        // Use the target itself to store the spanId to avoid using a global mapper.
        objc_setAssociatedObject(controller, &SENTRY_UI_PERFORMANCE_TRACKER_SPAN_ID, spanId,
            OBJC_ASSOCIATION_RETAIN_NONATOMIC);

        // If there is no active span in the queue push this transaction
        // to serve as an umbrella transaction that will capture every span
        // happening while the transaction is active.
        if (self.tracker.activeSpanId == nil) {
            SENTRY_LOG_DEBUG(@"Started new transaction with id %@ to track view controller %@.",
                spanId.sentrySpanIdString, name);
            [self.tracker pushActiveSpan:spanId];
        } else {
            SENTRY_LOG_DEBUG(@"Started child span with id %@ to track view controller %@.",
                spanId.sentrySpanIdString, name);
        }
    }

    SentrySpan *vcSpan = [self viewControllerPerformanceSpan:controller];

    if (![vcSpan isKindOfClass:[SentryTracer self]]) {
        // Since TTID and TTFD are meant to the whole screen
        // we will not track child view controllers
        return;
    }

    if (objc_getAssociatedObject(controller, &SENTRY_UI_PERFORMANCE_TRACKER_TTD_TRACKER)) {
        // Already tracking time to display, not creating a new tracker.
        // This may happen if user manually call `loadView` from a view controller more than once.
        return;
    }

    SentryTimeToDisplayTracker *ttdTracker =
        [self startTimeToDisplayTrackerForScreen:[SwiftDescriptor getObjectClassName:controller]
                              waitForFullDisplay:self.alwaysWaitForFullDisplay
                                          tracer:(SentryTracer *)vcSpan];

    if (ttdTracker) {
        objc_setAssociatedObject(controller, &SENTRY_UI_PERFORMANCE_TRACKER_TTD_TRACKER, ttdTracker,
            OBJC_ASSOCIATION_ASSIGN);
    }
}

- (void)reportFullyDisplayed
{
    SentryTimeToDisplayTracker *tracker = self.currentTTDTracker;
    if (tracker == nil) {
        SENTRY_LOG_DEBUG(@"No screen transaction being tracked right now.")
        return;
    }
    if (!tracker.waitForFullDisplay) {
        SENTRY_LOG_WARN(@"Transaction is not waiting for full display report. You can enable "
                        @"`enableTimeToFullDisplay` option, or use the waitForFullDisplay "
                        @"property in our `SentryTracedView` view for SwiftUI.");
        return;
    }
    [self.currentTTDTracker reportFullyDisplayed];
}

- (SentryTimeToDisplayTracker *)startTimeToDisplayTrackerForScreen:(NSString *)screenName
                                                waitForFullDisplay:(BOOL)waitForFullDisplay
                                                            tracer:(SentryTracer *)tracer
{
    [self.currentTTDTracker finishSpansIfNotFinished];

    SentryTimeToDisplayTracker *ttdTracker =
        [[SentryTimeToDisplayTracker alloc] initWithName:screenName
                                      waitForFullDisplay:waitForFullDisplay
                                    dispatchQueueWrapper:_dispatchQueueWrapper];

    if ([ttdTracker startForTracer:tracer] == NO) {
        self.currentTTDTracker = nil;
        return nil;
    }

    self.currentTTDTracker = ttdTracker;
    return ttdTracker;
}

- (void)viewControllerViewWillAppear:(UIViewController *)controller
                    callbackToOrigin:(void (^)(void))callbackToOrigin
{
    void (^limitOverrideBlock)(void) = ^{
        SentrySpanId *spanId
            = objc_getAssociatedObject(controller, &SENTRY_UI_PERFORMANCE_TRACKER_SPAN_ID);

        if (spanId == nil || ![self.tracker isSpanAlive:spanId]) {
            // We are no longer tracking this UIViewController, just call the base
            // method.
            callbackToOrigin();
            return;
        }

        void (^duringBlock)(void) = ^{
            SENTRY_LOG_DEBUG(@"Tracking UIViewController.viewWillAppear");
            [self.tracker measureSpanWithDescription:@"viewWillAppear"
                                          nameSource:kSentryTransactionNameSourceComponent
                                           operation:SentrySpanOperationUiLoad
                                              origin:SentryTraceOriginAutoUIViewController
                                             inBlock:callbackToOrigin];
        };

        [self.tracker activateSpan:spanId duringBlock:duringBlock];
        [self reportInitialDisplay:controller];
    };

    [self limitOverride:@"viewWillAppear"
                  target:controller
        callbackToOrigin:callbackToOrigin
                   block:limitOverrideBlock];
}

- (void)viewControllerViewDidAppear:(UIViewController *)controller
                   callbackToOrigin:(void (^)(void))callbackToOrigin
{
    SENTRY_LOG_DEBUG(@"Tracking UIViewController.viewDidAppear");
    [self finishTransaction:controller
                     status:kSentrySpanStatusOk
            lifecycleMethod:@"viewDidAppear"
           callbackToOrigin:callbackToOrigin];
}

/**
 * According to the apple docs, see
 * https://developer.apple.com/documentation/uikit/uiviewcontroller: Not all ‘will’ callback
 * methods are paired with only a ‘did’ callback method. You need to ensure that if you start a
 * process in a ‘will’ callback method, you end the process in both the corresponding ‘did’ and
 * the opposite ‘will’ callback method.
 *
 * As stated above @c viewWillAppear doesn't need to be followed by a @c viewDidAppear. A
 * @c viewWillAppear can also be followed by a @c viewWillDisappear. Therefore, we finish the
 * transaction in
 * @c viewWillDisappear, if it wasn't already finished in @c viewDidAppear.
 */
- (void)viewControllerViewWillDisappear:(UIViewController *)controller
                       callbackToOrigin:(void (^)(void))callbackToOrigin
{

    [self finishTransaction:controller
                     status:kSentrySpanStatusCancelled
            lifecycleMethod:@"viewWillDisappear"
           callbackToOrigin:callbackToOrigin];
}

- (void)finishTransaction:(UIViewController *)controller
                   status:(SentrySpanStatus)status
          lifecycleMethod:(NSString *)lifecycleMethod
         callbackToOrigin:(void (^)(void))callbackToOrigin
{
    void (^limitOverrideBlock)(void) = ^{
        SentrySpanId *spanId
            = objc_getAssociatedObject(controller, &SENTRY_UI_PERFORMANCE_TRACKER_SPAN_ID);

        if (spanId == nil || ![self.tracker isSpanAlive:spanId]) {
            // We are no longer tracking this UIViewController, just call the base
            // method.
            callbackToOrigin();
            return;
        }

        void (^duringBlock)(void) = ^{
            [self.tracker measureSpanWithDescription:lifecycleMethod
                                          nameSource:kSentryTransactionNameSourceComponent
                                           operation:SentrySpanOperationUiLoad
                                              origin:SentryTraceOriginAutoUIViewController
                                             inBlock:callbackToOrigin];
        };

        [self.tracker activateSpan:spanId duringBlock:duringBlock];
        id<SentrySpan> vcSpan = [self.tracker getSpan:spanId];
        // If the current controller span has no parent,
        // it means it is the root transaction and need to be pop from the queue.
        if (vcSpan.parentSpanId == nil) {
            [self.tracker popActiveSpan];
        }

        // If we are still tracking this UIViewController finish the transaction
        // and remove associated span id.
        [self.tracker finishSpan:spanId withStatus:status];

        objc_setAssociatedObject(controller, &SENTRY_UI_PERFORMANCE_TRACKER_SPAN_ID, nil,
            OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    };

    [self limitOverride:lifecycleMethod
                  target:controller
        callbackToOrigin:callbackToOrigin
                   block:limitOverrideBlock];
}

- (void)viewControllerViewWillLayoutSubViews:(UIViewController *)controller
                            callbackToOrigin:(void (^)(void))callbackToOrigin
{
    void (^limitOverrideBlock)(void) = ^{
        SentrySpanId *spanId
            = objc_getAssociatedObject(controller, &SENTRY_UI_PERFORMANCE_TRACKER_SPAN_ID);

        if (spanId == nil || ![self.tracker isSpanAlive:spanId]) {
            // We are no longer tracking this UIViewController, just call the base
            // method.
            callbackToOrigin();
            return;
        }

        void (^duringBlock)(void) = ^{
            [self.tracker measureSpanWithDescription:@"viewWillLayoutSubviews"
                                          nameSource:kSentryTransactionNameSourceComponent
                                           operation:SentrySpanOperationUiLoad
                                              origin:SentryTraceOriginAutoUIViewController
                                             inBlock:callbackToOrigin];

            SentrySpanId *layoutSubViewId =
                [self.tracker startSpanWithName:@"layoutSubViews"
                                     nameSource:kSentryTransactionNameSourceComponent
                                      operation:SentrySpanOperationUiLoad
                                         origin:SentryTraceOriginAutoUIViewController];

            objc_setAssociatedObject(controller,
                &SENTRY_UI_PERFORMANCE_TRACKER_LAYOUTSUBVIEW_SPAN_ID, layoutSubViewId,
                OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        };
        [self.tracker activateSpan:spanId duringBlock:duringBlock];

        // According to the Apple docs
        // (https://developer.apple.com/documentation/uikit/uiviewcontroller/1621510-viewwillappear),
        // viewWillAppear should be called for before the UIViewController is added to the view
        // hierarchy. There are some edge cases, though, when this doesn't happen, and we saw
        // customers' transactions also proofing this. Therefore, we must also report the
        // initial display here, as the customers' transactions had spans for
        // `viewWillLayoutSubviews`.

        [self reportInitialDisplay:controller];
    };

    [self limitOverride:@"viewWillLayoutSubviews"
                  target:controller
        callbackToOrigin:callbackToOrigin
                   block:limitOverrideBlock];
}

- (void)viewControllerViewDidLayoutSubViews:(UIViewController *)controller
                           callbackToOrigin:(void (^)(void))callbackToOrigin
{
    void (^limitOverrideBlock)(void) = ^{
        SentrySpanId *spanId
            = objc_getAssociatedObject(controller, &SENTRY_UI_PERFORMANCE_TRACKER_SPAN_ID);

        if (spanId == nil || ![self.tracker isSpanAlive:spanId]) {
            // We are no longer tracking this UIViewController, just call the base
            // method.
            callbackToOrigin();
            return;
        }

        void (^duringBlock)(void) = ^{
            SentrySpanId *layoutSubViewId = objc_getAssociatedObject(
                controller, &SENTRY_UI_PERFORMANCE_TRACKER_LAYOUTSUBVIEW_SPAN_ID);

            if (layoutSubViewId != nil) {
                [self.tracker finishSpan:layoutSubViewId];
            }

            [self.tracker measureSpanWithDescription:@"viewDidLayoutSubviews"
                                          nameSource:kSentryTransactionNameSourceComponent
                                           operation:SentrySpanOperationUiLoad
                                              origin:SentryTraceOriginAutoUIViewController
                                             inBlock:callbackToOrigin];

            objc_setAssociatedObject(controller,
                &SENTRY_UI_PERFORMANCE_TRACKER_LAYOUTSUBVIEW_SPAN_ID, nil,
                OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        };

        [self.tracker activateSpan:spanId duringBlock:duringBlock];
    };

    [self limitOverride:@"viewDidLayoutSubviews"
                  target:controller
        callbackToOrigin:callbackToOrigin
                   block:limitOverrideBlock];
}

/**
 * When a custom UIViewController is a subclass of another custom UIViewController, the SDK
 * swizzles both functions, which would create one span for each UIViewController leading to
 * duplicate spans in the transaction. To fix this, we only allow one span per lifecycle method
 * at a time.
 */
- (void)limitOverride:(NSString *)description
               target:(UIViewController *)viewController
     callbackToOrigin:(void (^)(void))callbackToOrigin
                block:(void (^)(void))block

{
    NSMutableSet<NSString *> *spansInExecution;

    spansInExecution = objc_getAssociatedObject(
        viewController, &SENTRY_UI_PERFORMANCE_TRACKER_SPANS_IN_EXECUTION_SET);
    if (spansInExecution == nil) {
        spansInExecution = [[NSMutableSet alloc] init];
        objc_setAssociatedObject(viewController,
            &SENTRY_UI_PERFORMANCE_TRACKER_SPANS_IN_EXECUTION_SET, spansInExecution,
            OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    if (![spansInExecution containsObject:description]) {
        [spansInExecution addObject:description];
        block();
        [spansInExecution removeObject:description];
    } else {
        callbackToOrigin();
    }
}

- (void)measurePerformance:(NSString *)description
                    target:(UIViewController *)viewController
          callbackToOrigin:(void (^)(void))callbackToOrigin
{
    SentrySpanId *spanId
        = objc_getAssociatedObject(viewController, &SENTRY_UI_PERFORMANCE_TRACKER_SPAN_ID);

    if (spanId == nil) {
        SENTRY_LOG_DEBUG(@"No longer tracking UIViewController %@", viewController);
        callbackToOrigin();
    } else {
        [self.tracker measureSpanWithDescription:description
                                      nameSource:kSentryTransactionNameSourceComponent
                                       operation:SentrySpanOperationUiLoad
                                          origin:SentryTraceOriginAutoUIViewController
                                    parentSpanId:spanId
                                         inBlock:callbackToOrigin];
    }
}

- (void)reportInitialDisplay:(UIViewController *)controller
{
    SentryTimeToDisplayTracker *ttdTracker
        = objc_getAssociatedObject(controller, &SENTRY_UI_PERFORMANCE_TRACKER_TTD_TRACKER);
    [ttdTracker reportInitialDisplay];
}

@end

#endif // SENTRY_HAS_UIKIT
