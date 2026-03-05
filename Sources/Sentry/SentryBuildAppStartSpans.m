#import "SentryAppStartMeasurement.h"
#import "SentrySpanContext+Private.h"
#import "SentrySpanId.h"
#import "SentrySpanInternal.h"
#import "SentrySpanOperation.h"
#import "SentrySwift.h"
#import "SentryTraceOrigin.h"
#import "SentryTracer.h"
#import <SentryBuildAppStartSpans.h>

#if SENTRY_HAS_UIKIT

id<SentrySpan>
sentryBuildAppStartSpan(
    SentryTracer *tracer, SentrySpanId *parentId, NSString *operation, NSString *description)
{
    SentrySpanContext *context =
        [[SentrySpanContext alloc] initWithTraceId:tracer.traceId
                                            spanId:[[SentrySpanId alloc] init]
                                          parentId:parentId
                                         operation:operation
                                   spanDescription:description
                                            origin:SentryTraceOriginAutoAppStart
                                           sampled:tracer.sampled];

    return [[SentrySpanInternal alloc] initWithTracer:tracer context:context framesTracker:nil];
}

NSArray<id<SentrySpan>> *
sentryBuildAppStartSpans(
    SentryTracer *tracer, SentryAppStartMeasurement *_Nullable appStartMeasurement)
{

    if (appStartMeasurement == nil) {
        return @[];
    }

    NSString *operation;
    NSString *type;

    switch (appStartMeasurement.type) {
    case SentryAppStartTypeCold:
        operation = @"app.start.cold";
        type = @"Cold Start";
        break;
    case SentryAppStartTypeWarm:
        operation = @"app.start.warm";
        type = @"Warm Start";
        break;
    default:
        return @[];
    }

    NSMutableArray<id<SentrySpan>> *appStartSpans = [NSMutableArray array];

    NSDate *appStartEndTimestamp = [appStartMeasurement.appStartTimestamp
        dateByAddingTimeInterval:appStartMeasurement.duration];

    // For standalone app start transactions the transaction itself is the root span,
    // so we skip creating the intermediate "Cold Start" / "Warm Start" span.
    BOOL isStandaloneAppStartTransaction =
        [tracer.operation isEqualToString:SentrySpanOperationAppStartCold]
        || [tracer.operation isEqualToString:SentrySpanOperationAppStartWarm];

    SentrySpanId *childParentId;
    if (isStandaloneAppStartTransaction) {
        childParentId = tracer.spanId;
    } else {
        SentrySpanInternal *appStartSpan
            = sentryBuildAppStartSpan(tracer, tracer.spanId, operation, type);
        [appStartSpan setStartTimestamp:appStartMeasurement.appStartTimestamp];
        [appStartSpan setTimestamp:appStartEndTimestamp];
        [appStartSpans addObject:appStartSpan];
        childParentId = appStartSpan.spanId;
    }

    if (!appStartMeasurement.isPreWarmed) {
        SentrySpanInternal *premainSpan
            = sentryBuildAppStartSpan(tracer, childParentId, operation, @"Pre Runtime Init");
        [premainSpan setStartTimestamp:appStartMeasurement.appStartTimestamp];
        [premainSpan setTimestamp:appStartMeasurement.runtimeInitTimestamp];
        [appStartSpans addObject:premainSpan];

        SentrySpanInternal *runtimeInitSpan = sentryBuildAppStartSpan(
            tracer, childParentId, operation, @"Runtime Init to Pre Main Initializers");
        [runtimeInitSpan setStartTimestamp:appStartMeasurement.runtimeInitTimestamp];
        [runtimeInitSpan setTimestamp:appStartMeasurement.moduleInitializationTimestamp];
        [appStartSpans addObject:runtimeInitSpan];
    }

    SentrySpanInternal *appInitSpan
        = sentryBuildAppStartSpan(tracer, childParentId, operation, @"UIKit Init");
    [appInitSpan setStartTimestamp:appStartMeasurement.moduleInitializationTimestamp];
    [appInitSpan setTimestamp:appStartMeasurement.sdkStartTimestamp];
    [appStartSpans addObject:appInitSpan];

    SentrySpanInternal *didFinishLaunching
        = sentryBuildAppStartSpan(tracer, childParentId, operation, @"Application Init");
    [didFinishLaunching setStartTimestamp:appStartMeasurement.sdkStartTimestamp];
    [didFinishLaunching setTimestamp:appStartMeasurement.didFinishLaunchingTimestamp];
    [appStartSpans addObject:didFinishLaunching];

    SentrySpanInternal *frameRenderSpan
        = sentryBuildAppStartSpan(tracer, childParentId, operation, @"Initial Frame Render");
    [frameRenderSpan setStartTimestamp:appStartMeasurement.didFinishLaunchingTimestamp];
    [frameRenderSpan setTimestamp:appStartEndTimestamp];
    [appStartSpans addObject:frameRenderSpan];

    return appStartSpans;
}

#endif // SENTRY_HAS_UIKIT
