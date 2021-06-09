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

@interface
SentryUIPerformanceTracker ()

@property (nonatomic, strong) SentryPerformanceTracker *tracker;

@end

@implementation SentryUIPerformanceTracker

+ (instancetype)shared
{
    static SentryUIPerformanceTracker *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (instancetype)init
{
    if (self = [super init]) {
        self.tracker = SentryPerformanceTracker.shared;
    }
    return self;
}

- (void)measurePerformance:(NSString *)description
              parentSpanId:(SentrySpanId *)spanId
            blockToMeasure:(Callback)callback
{
    [self.tracker pushActiveSpan:spanId];
    [self.tracker measureSpanWithDescription:description
                                   operation:SENTRY_VIEWCONTROLLER_RENDERING_OPERATION
                                     inBlock:callback];
    [self.tracker popActiveSpan];
}

- (void)measurePerformance:(NSString *)description
                    target:(id)target
            blockToMeasure:(Callback)callback
{
    SentrySpanId *spanId = objc_getAssociatedObject(target, &SENTRY_UI_PERFORMANCE_TRACKER_SPAN_ID);

    if (spanId == nil) {
        callback();
    } else {
        [self measurePerformance:description parentSpanId:spanId blockToMeasure:callback];
    }
}

- (void)viewControllerLoadView:(id)controller callbackToOrigin:(Callback)callback
{
    NSString *name = [SentryUIViewControllerSanitizer sanitizeViewControllerName:controller];
    SentrySpanId *spanId =
        [self.tracker startSpanWithName:name operation:SENTRY_VIEWCONTROLLER_RENDERING_OPERATION];

    // use the target itself to store the spanId to avoid using a global mapper.
    objc_setAssociatedObject(controller, &SENTRY_UI_PERFORMANCE_TRACKER_SPAN_ID, spanId,
        OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    [self measurePerformance:@"loadView" parentSpanId:spanId blockToMeasure:callback];
}

- (void)viewControllerViewDidLoad:(id)controller callbackToOrigin:(Callback)callback
{
    [self measurePerformance:@"viewDidLoad" target:controller blockToMeasure:callback];
}

- (void)viewControllerViewWillAppear:(id)controller callbackToOrigin:(Callback)callback
{
    [self measurePerformance:@"viewWillAppear" target:controller blockToMeasure:callback];
}

- (void)viewControllerViewDidAppear:(id)controller callbackToOrigin:(Callback)callback
{
    [self measurePerformance:@"viewDidAppear" target:controller blockToMeasure:callback];

    SentrySpanId *spanId
        = objc_getAssociatedObject(controller, &SENTRY_UI_PERFORMANCE_TRACKER_SPAN_ID);
    if (spanId != nil) {
        [self.tracker finishSpan:spanId];
    }
}

- (void)viewControllerViewWillLayoutSubViews:(id)controller callbackToOrigin:(Callback)callback
{
    SentrySpanId *spanId
        = objc_getAssociatedObject(controller, &SENTRY_UI_PERFORMANCE_TRACKER_SPAN_ID);

    if (spanId == nil || ![self.tracker isSpanAlive:spanId]) {
        callback();
    } else {
        [self.tracker pushActiveSpan:spanId];
        [self.tracker measureSpanWithDescription:@"viewWillLayoutSubviews"
                                       operation:SENTRY_VIEWCONTROLLER_RENDERING_OPERATION
                                         inBlock:callback];

        SentrySpanId *layoutSubViewId =
            [self.tracker startSpanWithName:@"layoutSubViews"
                                  operation:SENTRY_VIEWCONTROLLER_RENDERING_OPERATION];

        objc_setAssociatedObject(controller, &SENTRY_UI_PERFORMANCE_TRACKER_LAYOUTSUBVIEW_SPAN_ID,
            layoutSubViewId, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

        [self.tracker pushActiveSpan:layoutSubViewId];
    }
}

- (void)viewControllerViewDidLayoutSubViews:(id)controller callbackToOrigin:(Callback)callback
{
    SentrySpanId *spanId
        = objc_getAssociatedObject(controller, &SENTRY_UI_PERFORMANCE_TRACKER_SPAN_ID);

    if (spanId == nil || ![self.tracker isSpanAlive:spanId]) {
        callback();
    } else {
        SentrySpanId *layoutSubViewId = objc_getAssociatedObject(
            controller, &SENTRY_UI_PERFORMANCE_TRACKER_LAYOUTSUBVIEW_SPAN_ID);
        [self.tracker popActiveSpan];
        [self.tracker finishSpan:layoutSubViewId];

        [self.tracker measureSpanWithDescription:@"viewDidLayoutSubviews"
                                       operation:SENTRY_VIEWCONTROLLER_RENDERING_OPERATION
                                         inBlock:callback];
        [self.tracker popActiveSpan];
    }
}

@end
