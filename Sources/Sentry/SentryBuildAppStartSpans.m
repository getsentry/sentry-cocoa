#import "SentryAppStartMeasurement.h"
#import "SentryLogC.h"
#import "SentrySpanContext+Private.h"
#import "SentrySpanDataKey.h"
#import "SentrySpanId.h"
#import "SentrySpanInternal.h"
#import "SentrySpanOperation.h"
#import "SentrySwift.h"
#import "SentryTraceOrigin.h"
#import "SentryTracer.h"
#import <SentryBuildAppStartSpans.h>

#if SENTRY_HAS_UIKIT

#    pragma mark - Private

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

    if (isStandalone) {
        operation = SentrySpanOperationAppStart;
        type = @"App Start";
    } else {
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
    }

    NSString *startType = nil;
    if (appStartMeasurement.type == SentryAppStartTypeCold
        || appStartMeasurement.type == SentryAppStartTypeWarm) {
        NSString *base = appStartMeasurement.type == SentryAppStartTypeCold ? @"cold" : @"warm";
        startType = appStartMeasurement.isPreWarmed
            ? [NSString stringWithFormat:@"%@.prewarmed", base]
            : base;
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
        if (isStandalone && startType != nil) {
            [premainSpan setDataValue:startType forKey:SentrySpanDataKeyAppVitalsStartType];
        }
        [appStartSpans addObject:premainSpan];

        id<SentrySpan> runtimeInitSpan = sentryBuildAppStartSpan(
            tracer, appStartSpanParentId, operation, @"Runtime Init to Pre Main Initializers");
        [runtimeInitSpan setStartTimestamp:appStartMeasurement.runtimeInitTimestamp];
        [runtimeInitSpan setTimestamp:appStartMeasurement.moduleInitializationTimestamp];
        if (isStandalone && startType != nil) {
            [runtimeInitSpan setDataValue:startType forKey:SentrySpanDataKeyAppVitalsStartType];
        }
        [appStartSpans addObject:runtimeInitSpan];
    }

    id<SentrySpan> appInitSpan
        = sentryBuildAppStartSpan(tracer, appStartSpanParentId, operation, @"UIKit Init");
    [appInitSpan setStartTimestamp:appStartMeasurement.moduleInitializationTimestamp];
    [appInitSpan setTimestamp:appStartMeasurement.sdkStartTimestamp];
    if (isStandalone && startType != nil) {
        [appInitSpan setDataValue:startType forKey:SentrySpanDataKeyAppVitalsStartType];
    }
    [appStartSpans addObject:appInitSpan];

    id<SentrySpan> didFinishLaunching
        = sentryBuildAppStartSpan(tracer, appStartSpanParentId, operation, @"Application Init");
    [didFinishLaunching setStartTimestamp:appStartMeasurement.sdkStartTimestamp];
    [didFinishLaunching setTimestamp:appStartMeasurement.didFinishLaunchingTimestamp];
    if (isStandalone && startType != nil) {
        [didFinishLaunching setDataValue:startType forKey:SentrySpanDataKeyAppVitalsStartType];
    }
    [appStartSpans addObject:didFinishLaunching];

    id<SentrySpan> frameRenderSpan
        = sentryBuildAppStartSpan(tracer, appStartSpanParentId, operation, @"Initial Frame Render");
    [frameRenderSpan setStartTimestamp:appStartMeasurement.didFinishLaunchingTimestamp];
    [frameRenderSpan setTimestamp:appStartEndTimestamp];
    if (isStandalone && startType != nil) {
        [frameRenderSpan setDataValue:startType forKey:SentrySpanDataKeyAppVitalsStartType];
    }
    [appStartSpans addObject:frameRenderSpan];

    return appStartSpans;
}

#    pragma mark - Public

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
