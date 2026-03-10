#import "SentryAppStartMeasurement.h"
#import "SentryLogC.h"
#import "SentrySpanContext+Private.h"
#import "SentrySpanId.h"
#import "SentrySpanInternal.h"
#import "SentrySpanOperation.h"
#import "SentrySwift.h"
#import "SentryTraceOrigin.h"
#import "SentryTracer.h"
#import <SentryBuildAppStartSpans.h>

#if SENTRY_HAS_UIKIT

static id<SentrySpan>
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

    // Pass nil for the framesTracker because app start spans are created during launch,
    // before the frames tracker is available.
    return [[SentrySpanInternal alloc] initWithTracer:tracer context:context framesTracker:nil];
}

/**
 * Internal helper that builds the app start child spans. When @c isStandalone is @c YES the
 * intermediate grouping span is omitted and children are parented directly to the tracer.
 */
static NSArray<id<SentrySpan>> *
sentryBuildAppStartSpansInternal(SentryTracer *tracer,
    SentryAppStartMeasurement *_Nullable appStartMeasurement, BOOL isStandalone)
{

    if (appStartMeasurement == nil) {
        return @[];
    }

    NSString *operation;
    NSString *type;

    switch (appStartMeasurement.type) {
    case SentryAppStartTypeCold:
        operation = SentrySpanOperationAppStartCold;
        type = @"Cold Start";
        break;
    case SentryAppStartTypeWarm:
        operation = SentrySpanOperationAppStartWarm;
        type = @"Warm Start";
        break;
    default:
        SENTRY_LOG_ERROR(@"Unknown app start type, can't build app start spans");
        return @[];
    }

    NSMutableArray<id<SentrySpan>> *appStartSpans = [NSMutableArray array];

    NSDate *appStartEndTimestamp = [appStartMeasurement.appStartTimestamp
        dateByAddingTimeInterval:appStartMeasurement.duration];

    SentrySpanId *appStartSpanParentId;
    if (isStandalone) {
        appStartSpanParentId = tracer.spanId;
    } else {
        id<SentrySpan> appStartSpan
            = sentryBuildAppStartSpan(tracer, tracer.spanId, operation, type);
        [appStartSpan setStartTimestamp:appStartMeasurement.appStartTimestamp];
        [appStartSpan setTimestamp:appStartEndTimestamp];
        [appStartSpans addObject:appStartSpan];
        appStartSpanParentId = appStartSpan.spanId;
    }

    if (!appStartMeasurement.isPreWarmed) {
        id<SentrySpan> premainSpan
            = sentryBuildAppStartSpan(tracer, appStartSpanParentId, operation, @"Pre Runtime Init");
        [premainSpan setStartTimestamp:appStartMeasurement.appStartTimestamp];
        [premainSpan setTimestamp:appStartMeasurement.runtimeInitTimestamp];
        [appStartSpans addObject:premainSpan];

        id<SentrySpan> runtimeInitSpan = sentryBuildAppStartSpan(
            tracer, appStartSpanParentId, operation, @"Runtime Init to Pre Main Initializers");
        [runtimeInitSpan setStartTimestamp:appStartMeasurement.runtimeInitTimestamp];
        [runtimeInitSpan setTimestamp:appStartMeasurement.moduleInitializationTimestamp];
        [appStartSpans addObject:runtimeInitSpan];
    }

    id<SentrySpan> appInitSpan
        = sentryBuildAppStartSpan(tracer, appStartSpanParentId, operation, @"UIKit Init");
    [appInitSpan setStartTimestamp:appStartMeasurement.moduleInitializationTimestamp];
    [appInitSpan setTimestamp:appStartMeasurement.sdkStartTimestamp];
    [appStartSpans addObject:appInitSpan];

    id<SentrySpan> didFinishLaunching
        = sentryBuildAppStartSpan(tracer, appStartSpanParentId, operation, @"Application Init");
    [didFinishLaunching setStartTimestamp:appStartMeasurement.sdkStartTimestamp];
    [didFinishLaunching setTimestamp:appStartMeasurement.didFinishLaunchingTimestamp];
    [appStartSpans addObject:didFinishLaunching];

    id<SentrySpan> frameRenderSpan
        = sentryBuildAppStartSpan(tracer, appStartSpanParentId, operation, @"Initial Frame Render");
    [frameRenderSpan setStartTimestamp:appStartMeasurement.didFinishLaunchingTimestamp];
    [frameRenderSpan setTimestamp:appStartEndTimestamp];
    [appStartSpans addObject:frameRenderSpan];

    return appStartSpans;
}

NSArray<id<SentrySpan>> *
sentryBuildAppStartSpans(
    SentryTracer *tracer, SentryAppStartMeasurement *_Nullable appStartMeasurement)
{
    return sentryBuildAppStartSpansInternal(tracer, appStartMeasurement, NO);
}

NSArray<id<SentrySpan>> *
sentryBuildStandaloneAppStartSpans(
    SentryTracer *tracer, SentryAppStartMeasurement *_Nullable appStartMeasurement)
{
    return sentryBuildAppStartSpansInternal(tracer, appStartMeasurement, YES);
}

#endif // SENTRY_HAS_UIKIT
