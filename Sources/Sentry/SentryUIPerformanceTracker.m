#import "SentryUIPerformanceTracker.h"
#import "SentryHub.h"
#import "SentryLog.h"
#import "SentryPerformanceTracker.h"
#import "SentrySDK+Private.h"
#import "SentryScope.h"
#import "SentrySpanId.h"
#import "SentrySwizzle.h"
#import "SentryUIViewControllerSanitizer.h"
#import <objc/runtime.h>

static NSString *const SENTRY_UI_PERFORMANCE_TRACKER_SPAN_ID
    = @"SENTRY_UI_PERFORMANCE_TRACKER_SPAN_ID";

static NSString *const SENTRY_UI_PERFORMANCE_TRACKER_LAYOUTSUBVIEW_SPAN_ID
    = @"SENTRY_UI_PERFORMANCE_TRACKER_LAYOUTSUBVIEW_SPAN_ID";

static NSString *const SENTRY_VIEWCONTROLLER_RENDERING_OPERATION = @"ui.rendering";

@implementation SentryUIPerformanceTracker

+ (instancetype) shared
{
    static SentryUIPerformanceTracker *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (void)measurePerformance:(NSString *)description
              parentSpanId:(SentrySpanId *)spanId
        callbackToOriginal:(Callback)callback
{
    [SentryPerformanceTracker.shared pushActiveSpan:spanId];
    [SentryPerformanceTracker.shared
     measureSpanWithDescription:description
     operation:SENTRY_VIEWCONTROLLER_RENDERING_OPERATION
     inBlock:callback];
    [SentryPerformanceTracker.shared popActiveSpan];
}

- (void)viewControllerLoadView:(UIViewController*)controller
              callbackToOrigin:(Callback)callback {
    NSString *name = [SentryUIViewControllerSanitizer sanitizeViewControllerName:controller];
    SentrySpanId *spanId = [SentryPerformanceTracker.shared
                            startSpanWithName:name
                            operation:SENTRY_VIEWCONTROLLER_RENDERING_OPERATION];
    
    // use the viewcontroller itself to store the spanId to avoid using a global mapper.
    objc_setAssociatedObject(controller, &SENTRY_UI_PERFORMANCE_TRACKER_SPAN_ID, spanId,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    [self measurePerformance:@"loadView"
                parentSpanId:spanId
          callbackToOriginal:callback];
}

- (void)viewControllerViewDidLoad:(UIViewController*)controller
                 callbackToOrigin:(Callback)callback {
    SentrySpanId *spanId
    = objc_getAssociatedObject(controller, &SENTRY_UI_PERFORMANCE_TRACKER_SPAN_ID);
    
    if (spanId == nil) {
        callback();
    } else {
        [self measurePerformance:@"viewDidLoad"
                    parentSpanId:spanId
              callbackToOriginal:callback];
    }
}

- (void)viewControllerViewWillAppear:(UIViewController*)controller
                 callbackToOrigin:(Callback)callback {
    SentrySpanId *spanId
    = objc_getAssociatedObject(controller, &SENTRY_UI_PERFORMANCE_TRACKER_SPAN_ID);
    
    if (spanId == nil) {
        callback();
    } else {
        [self measurePerformance:@"viewWillAppear"
                    parentSpanId:spanId
              callbackToOriginal:callback];
    }
}

- (void)viewControllerViewDidAppear:(UIViewController*)controller
                    callbackToOrigin:(Callback)callback {
    SentrySpanId *spanId
    = objc_getAssociatedObject(controller, &SENTRY_UI_PERFORMANCE_TRACKER_SPAN_ID);
    
    if (spanId == nil) {
        callback();
    } else {
        [self measurePerformance:@"viewDidAppear"
                    parentSpanId:spanId
              callbackToOriginal:callback];
    }
}

- (void)viewControllerViewWillLayoutSubViews:(UIViewController*)controller
                        callbackToOrigin:(Callback)callback {
    SentrySpanId *spanId
    = objc_getAssociatedObject(controller, &SENTRY_UI_PERFORMANCE_TRACKER_SPAN_ID);
    
    if (spanId == nil || ![SentryPerformanceTracker.shared isSpanAlive:spanId]) {
        callback();
    } else {
        [SentryPerformanceTracker.shared pushActiveSpan:spanId];
        [SentryPerformanceTracker.shared
         measureSpanWithDescription:@"viewWillLayoutSubviews"
         operation:SENTRY_VIEWCONTROLLER_RENDERING_OPERATION
         inBlock:callback];
        
        SentrySpanId *layoutSubViewId = [SentryPerformanceTracker.shared
                                         startSpanWithName:@"layoutSubViews"
                                         operation:SENTRY_VIEWCONTROLLER_RENDERING_OPERATION];
        
        objc_setAssociatedObject(controller, &SENTRY_UI_PERFORMANCE_TRACKER_LAYOUTSUBVIEW_SPAN_ID,
                                 layoutSubViewId, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        
        [SentryPerformanceTracker.shared pushActiveSpan:layoutSubViewId];
    }
}

- (void)viewControllerViewDidLayoutSubViews:(UIViewController*)controller
                           callbackToOrigin:(Callback)callback {
    SentrySpanId *spanId
    = objc_getAssociatedObject(controller, &SENTRY_UI_PERFORMANCE_TRACKER_SPAN_ID);
    
    if (spanId == nil || ![SentryPerformanceTracker.shared isSpanAlive:spanId]) {
        callback();
    } else {
        SentrySpanId *layoutSubViewId = objc_getAssociatedObject(
                                                                 controller, &SENTRY_UI_PERFORMANCE_TRACKER_LAYOUTSUBVIEW_SPAN_ID);
        [SentryPerformanceTracker.shared popActiveSpan];
        [SentryPerformanceTracker.shared finishSpan:layoutSubViewId];
        
        [SentryPerformanceTracker.shared
         measureSpanWithDescription:@"viewDidLayoutSubviews"
         operation:SENTRY_VIEWCONTROLLER_RENDERING_OPERATION
         inBlock:callback];
        [SentryPerformanceTracker.shared popActiveSpan];
    }
}

@end
