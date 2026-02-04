#import "SentryAppStartMeasurement.h"
#import "SentrySpanContext+Private.h"
#import "SentrySpanId.h"
#import "SentrySpanInternal.h"
#import "SentryTraceOrigin.h"
#import "SentryTracer.h"
#import <SentryBuildAppStartSpans.h>

#if SENTRY_HAS_UIKIT

// These span description constants must match SentryAppStartSpanBuilder.swift
static NSString *const kAppStartColdStartDescription = @"Cold Start";
static NSString *const kAppStartWarmStartDescription = @"Warm Start";
static NSString *const kAppStartPreRuntimeInitDescription = @"Pre Runtime Init";
static NSString *const kAppStartRuntimeInitDescription = @"Runtime Init to Pre Main Initializers";
static NSString *const kAppStartUIKitInitDescription = @"UIKit Init";
static NSString *const kAppStartApplicationInitDescription = @"Application Init";
static NSString *const kAppStartInitialFrameRenderDescription = @"Initial Frame Render";

static SentrySpanInternal *
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

NSArray<SentrySpanInternal *> *
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
        type = kAppStartColdStartDescription;
        break;
    case SentryAppStartTypeWarm:
        operation = @"app.start.warm";
        type = kAppStartWarmStartDescription;
        break;
    default:
        return @[];
    }

    NSMutableArray<SentrySpanInternal *> *appStartSpans = [NSMutableArray array];

    NSDate *appStartEndTimestamp = [appStartMeasurement.appStartTimestamp
        dateByAddingTimeInterval:appStartMeasurement.duration];

    SentrySpanInternal *appStartSpan
        = sentryBuildAppStartSpan(tracer, tracer.spanId, operation, type);
    [appStartSpan setStartTimestamp:appStartMeasurement.appStartTimestamp];
    [appStartSpan setTimestamp:appStartEndTimestamp];

    [appStartSpans addObject:appStartSpan];

    if (!appStartMeasurement.isPreWarmed) {
        SentrySpanInternal *premainSpan = sentryBuildAppStartSpan(
            tracer, appStartSpan.spanId, operation, kAppStartPreRuntimeInitDescription);
        [premainSpan setStartTimestamp:appStartMeasurement.appStartTimestamp];
        [premainSpan setTimestamp:appStartMeasurement.runtimeInitTimestamp];
        [appStartSpans addObject:premainSpan];

        SentrySpanInternal *runtimeInitSpan = sentryBuildAppStartSpan(
            tracer, appStartSpan.spanId, operation, kAppStartRuntimeInitDescription);
        [runtimeInitSpan setStartTimestamp:appStartMeasurement.runtimeInitTimestamp];
        [runtimeInitSpan setTimestamp:appStartMeasurement.moduleInitializationTimestamp];
        [appStartSpans addObject:runtimeInitSpan];
    }

    SentrySpanInternal *appInitSpan = sentryBuildAppStartSpan(
        tracer, appStartSpan.spanId, operation, kAppStartUIKitInitDescription);
    [appInitSpan setStartTimestamp:appStartMeasurement.moduleInitializationTimestamp];
    [appInitSpan setTimestamp:appStartMeasurement.sdkStartTimestamp];
    [appStartSpans addObject:appInitSpan];

    SentrySpanInternal *didFinishLaunching = sentryBuildAppStartSpan(
        tracer, appStartSpan.spanId, operation, kAppStartApplicationInitDescription);
    [didFinishLaunching setStartTimestamp:appStartMeasurement.sdkStartTimestamp];
    [didFinishLaunching setTimestamp:appStartMeasurement.didFinishLaunchingTimestamp];
    [appStartSpans addObject:didFinishLaunching];

    SentrySpanInternal *frameRenderSpan = sentryBuildAppStartSpan(
        tracer, appStartSpan.spanId, operation, kAppStartInitialFrameRenderDescription);
    [frameRenderSpan setStartTimestamp:appStartMeasurement.didFinishLaunchingTimestamp];
    [frameRenderSpan setTimestamp:appStartEndTimestamp];
    [appStartSpans addObject:frameRenderSpan];

    return appStartSpans;
}

#endif // SENTRY_HAS_UIKIT
