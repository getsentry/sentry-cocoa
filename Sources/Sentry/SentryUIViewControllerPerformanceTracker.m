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

// Instead of using associated objects, we use a global map to store the time to display tracker,
// spanId, spans in execution, and layout subview spanId to avoid memory issues with associated
// objects accessed from different threads.
//
// Using a NSMapTable allows weak references to the keys, which means we don't need to remove the
// entries when the UIViewController is deallocated.

@interface SentryUIViewControllerPerformanceTracker ()

@property (nonatomic, strong) SentryPerformanceTracker *tracker;
@property (nullable, nonatomic, weak) SentryTimeToDisplayTracker *currentTTDTracker;
@property (nonatomic, strong, readonly) SentryDispatchQueueWrapper *dispatchQueueWrapper;

@property (nonatomic, strong)
    NSMapTable<UIViewController *, SentryTimeToDisplayTracker *> *ttdTrackers;
@property (nonatomic, strong) NSMapTable<UIViewController *, SentrySpanId *> *spanIds;
@property (nonatomic, strong)
    NSMapTable<UIViewController *, NSMutableSet<NSString *> *> *spansInExecution;
@property (nonatomic, strong) NSMapTable<UIViewController *, SentrySpanId *> *layoutSubviewSpanIds;

@end

@implementation SentryUIViewControllerPerformanceTracker

- (instancetype)initWithTracker:(SentryPerformanceTracker *)tracker
           dispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper
{
    if (self = [super init]) {
        self.tracker = tracker;

        SentryOptions *options = [SentrySDK options];
        self.inAppLogic = [[SentryInAppLogic alloc] initWithInAppIncludes:options.inAppIncludes
                                                            inAppExcludes:options.inAppExcludes];

        _alwaysWaitForFullDisplay = NO;
        _dispatchQueueWrapper = dispatchQueueWrapper;

        _ttdTrackers = [NSMapTable weakToStrongObjectsMapTable];
        _spanIds = [NSMapTable weakToStrongObjectsMapTable];
        _spansInExecution = [NSMapTable weakToStrongObjectsMapTable];
        _layoutSubviewSpanIds = [NSMapTable weakToStrongObjectsMapTable];
    }
    return self;
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
    SentrySpanId *_Nullable spanId = [self getSpanIdForViewController:controller];

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

        [self setSpanIdForViewController:controller spanId:spanId];

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

    spanId = [self getSpanIdForViewController:controller];
    SentrySpan *_Nullable vcSpan = [self.tracker getSpan:spanId];

    if (![vcSpan isKindOfClass:[SentryTracer self]]) {
        // Since TTID and TTFD are meant to the whole screen
        // we will not track child view controllers
        return;
    }

    if ([self getTimeToDisplayTrackerForController:controller]) {
        // Already tracking time to display, not creating a new tracker.
        // This may happen if user manually call `loadView` from a view controller more than once.
        return;
    }

    SentryTimeToDisplayTracker *ttdTracker =
        [self startTimeToDisplayTrackerForScreen:[SwiftDescriptor getObjectClassName:controller]
                              waitForFullDisplay:self.alwaysWaitForFullDisplay
                                          tracer:(SentryTracer *)vcSpan];

    if (ttdTracker) {
        [self setTimeToDisplayTrackerForController:controller ttdTracker:ttdTracker];
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

    // Report the fully displayed time, then discard the tracker, because it should not be used
    // after TTFD is reported.
    [self.currentTTDTracker reportFullyDisplayed];
}

- (nullable SentryTimeToDisplayTracker *)startTimeToDisplayTrackerForScreen:(NSString *)screenName
                                                         waitForFullDisplay:(BOOL)waitForFullDisplay
                                                                     tracer:(SentryTracer *)tracer
{
    [self.currentTTDTracker finishSpansIfNotFinished];

    SentryTimeToDisplayTracker *ttdTracker =
        [[SentryTimeToDisplayTracker alloc] initWithName:screenName
                                      waitForFullDisplay:waitForFullDisplay
                                    dispatchQueueWrapper:_dispatchQueueWrapper];

    // If the tracker did not start, it means that the tracer can be discarded.
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
        SentrySpanId *_Nullable spanId = [self getSpanIdForViewController:controller];

        if (spanId == nil || ![self.tracker isSpanAlive:spanId]) {
            // We are no longer tracking this UIViewController, just call the base
            // method.
            SENTRY_LOG_DEBUG(
                @"Not tracking UIViewController.viewWillAppear because there is no active span.");
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
        [self reportInitialDisplayForController:controller];
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
        SentrySpanId *_Nullable spanId = [self getSpanIdForViewController:controller];

        if (spanId == nil || ![self.tracker isSpanAlive:spanId]) {
            // We are no longer tracking this UIViewController, just call the base
            // method.
            SENTRY_LOG_DEBUG(@"Not tracking UIViewController.%@ because there is no active span.",
                lifecycleMethod);
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
        [self setSpanIdForViewController:controller spanId:nil];
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
        SentrySpanId *_Nullable spanId = [self getSpanIdForViewController:controller];

        if (spanId == nil || ![self.tracker isSpanAlive:spanId]) {
            // We are no longer tracking this UIViewController, just call the base
            // method.
            SENTRY_LOG_DEBUG(@"Not tracking UIViewController.viewWillLayoutSubviews because there "
                             @"is no active span.");
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

            [self setLayoutSubviewSpanID:controller spanId:layoutSubViewId];
        };
        [self.tracker activateSpan:spanId duringBlock:duringBlock];

        // According to the Apple docs
        // (https://developer.apple.com/documentation/uikit/uiviewcontroller/1621510-viewwillappear),
        // viewWillAppear should be called for before the UIViewController is added to the view
        // hierarchy. There are some edge cases, though, when this doesn't happen, and we saw
        // customers' transactions also proofing this. Therefore, we must also report the
        // initial display here, as the customers' transactions had spans for
        // `viewWillLayoutSubviews`.
        [self reportInitialDisplayForController:controller];
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
        SentrySpanId *_Nullable spanId = [self getSpanIdForViewController:controller];

        if (spanId == nil || ![self.tracker isSpanAlive:spanId]) {
            // We are no longer tracking this UIViewController, just call the base
            // method.
            SENTRY_LOG_DEBUG(@"Not tracking UIViewController.viewDidLayoutSubviews because there "
                             @"is no active span.");
            callbackToOrigin();
            return;
        }

        void (^duringBlock)(void) = ^{
            SentrySpanId *layoutSubViewId =
                [self getLayoutSubviewSpanIdForViewController:controller];

            if (layoutSubViewId != nil) {
                [self.tracker finishSpan:layoutSubViewId];
            }

            [self.tracker measureSpanWithDescription:@"viewDidLayoutSubviews"
                                          nameSource:kSentryTransactionNameSourceComponent
                                           operation:SentrySpanOperationUiLoad
                                              origin:SentryTraceOriginAutoUIViewController
                                             inBlock:callbackToOrigin];

            // We need to remove the spanId for layoutSubviews, as it is not needed anymore.
            [self setLayoutSubviewSpanID:controller spanId:nil];
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
    NSMutableSet<NSString *> *spansInExecution =
        [self getSpansInExecutionSetForViewController:viewController];
    if (spansInExecution == nil) {
        spansInExecution = [[NSMutableSet alloc] init];
        [self setSpansInExecutionSetForViewController:viewController spansIds:spansInExecution];
    }

    if (![spansInExecution containsObject:description]) {
        [spansInExecution addObject:description];
        block();
        [spansInExecution removeObject:description];
    } else {
        SENTRY_LOG_DEBUG(@"Skipping tracking the method %@ for %@, cause we're already tracking it "
                         @"for a parent or child class.",
            description, viewController);
        callbackToOrigin();
    }
}

- (void)measurePerformance:(NSString *)description
                    target:(UIViewController *)viewController
          callbackToOrigin:(void (^)(void))callbackToOrigin
{
    SentrySpanId *spanId = [self getSpanIdForViewController:viewController];

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

- (void)reportInitialDisplayForController:(NSObject *)controller
{
    SENTRY_LOG_DEBUG(
        @"[UIViewController Performance] Reporting initial display for controller: %@", controller);
    if (self.currentTTDTracker == nil) {
        SENTRY_LOG_DEBUG(@"[UIViewController Performance] Can't report initial display, no screen "
                         @"transaction being tracked right now.");
        return;
    }
    [self.currentTTDTracker reportInitialDisplay];
    SENTRY_LOG_DEBUG(
        @"[UIViewController Performance] Reported initial display for controller: %@", controller);
}

// - MARK: - Getter and Setter Helpers

- (SentryTimeToDisplayTracker *_Nullable)getTimeToDisplayTrackerForController:
    (UIViewController *)controller
{
    SENTRY_LOG_DEBUG(
        @"[UIViewController Performance] Getting time to display tracker for controller: %@",
        controller);
    // Use a global map to store the time to display tracker to avoid memory issues with associated
    // objects.
    return [self.ttdTrackers objectForKey:controller];
}

- (void)setTimeToDisplayTrackerForController:(UIViewController *)controller
                                  ttdTracker:(SentryTimeToDisplayTracker *)ttdTracker
{
    SENTRY_LOG_DEBUG(
        @"[UIViewController Performance] Setting time to display tracker for controller: %@, "
         "ttdTracker: %@",
        controller, ttdTracker);
    // Use a global map to store the time to display tracker to avoid memory issues with associated
    // objects.
    [self.ttdTrackers setObject:ttdTracker forKey:controller];
}

- (void)setSpanIdForViewController:(UIViewController *)controller
                            spanId:(SentrySpanId *_Nullable)spanId
{
    SENTRY_LOG_DEBUG(
        @"[UIViewController Performance] Setting span id for controller: %@, spanId: %@",
        controller, spanId.sentrySpanIdString);
    // Use a global map to store the spanId to avoid memory issues with associated objects.
    [self.spanIds setObject:spanId forKey:controller];
}

- (SentrySpanId *_Nullable)getSpanIdForViewController:(UIViewController *)controller
{
    SENTRY_LOG_DEBUG(
        @"[UIViewController Performance] Getting span id for controller: %@", controller);
    // Use a global map to store the spanId to avoid memory issues with associated objects.
    return [self.spanIds objectForKey:controller];
}

- (SentrySpanId *_Nullable)getLayoutSubviewSpanIdForViewController:
    (UIViewController *_Nonnull)controller
{
    SENTRY_LOG_DEBUG(
        @"[UIViewController Performance] Getting layout subview span id for controller: %@",
        controller);
    // Use a global map to store the layout subview spanId to avoid memory issues with associated
    // objects.
    return [self.layoutSubviewSpanIds objectForKey:controller];
}

- (void)setLayoutSubviewSpanID:(UIViewController *_Nonnull)controller spanId:(SentrySpanId *)spanId
{
    SENTRY_LOG_DEBUG(@"[UIViewController Performance] Setting layout subview span id for "
                     @"controller: %@, spanId: %@",
        controller, spanId.sentrySpanIdString);
    // Use a global map to store the layout subview spanId to avoid memory issues with associated
    // objects.
    [self.layoutSubviewSpanIds setObject:spanId forKey:controller];
}

- (NSMutableSet<NSString *> *_Nullable)getSpansInExecutionSetForViewController:
    (UIViewController *)viewController
{
    SENTRY_LOG_DEBUG(
        @"[UIViewController Performance] Getting spans in execution set for controller: %@",
        viewController);
    // Use a global map to store the spans in execution set to avoid memory issues with associated
    // objects.
    return [self.spansInExecution objectForKey:viewController];
}

- (void)setSpansInExecutionSetForViewController:(UIViewController *)viewController
                                       spansIds:(NSMutableSet<NSString *> *)spanIds
{
    SENTRY_LOG_DEBUG(@"[UIViewController Performance] Setting spans in execution set for "
                     @"controller: %@, spanIds: %@",
        viewController, spanIds);
    // Use a global map to store the spans in execution set to avoid memory issues with associated
    // objects.
    [self.spansInExecution setObject:spanIds forKey:viewController];
}

@end

#endif // SENTRY_HAS_UIKIT
