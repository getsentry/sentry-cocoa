#import "SentryLaunchProfiling.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryCurrentDateProvider.h"
#    import "SentryDependencyContainer.h"
#    import "SentryDispatchQueueWrapper.h"
#    import "SentryFileManager.h"
#    import "SentryId.h"
#    import "SentryInternalDefines.h"
#    import "SentryLog.h"
#    import "SentryOptions.h"
#    import "SentryProfiler.h"
#    import "SentryProfilesSampler.h"
#    import "SentryRandom.h"
#    import "SentrySamplingContext.h"
#    import "SentryTracesSampler.h"
#    import "SentryTransactionContext.h"

SentryTracesSamplerDecision *appLaunchTraceSamplerDecision;
BOOL isTracingAppLaunch;
SentryId *_Nullable appLaunchTraceId;
NSObject *appLaunchTraceLock;
uint64_t appLaunchSystemTime;

SentrySamplingContext *
samplingContextForAppLaunches(void)
{
    SentryTransactionContext *transactionContext =
        [[SentryTransactionContext alloc] initWithName:@"app.launch" operation:@"profile"];
    transactionContext.forNextAppLaunch = YES;
    return [[SentrySamplingContext alloc] initWithTransactionContext:transactionContext];
}

void
configureLaunchProfiling(SentryOptions *options)
{
    [SentryDependencyContainer.sharedInstance.dispatchQueueWrapper dispatchAsyncWithBlock:^{
        BOOL shouldProfileNextLaunch = options.enableAppLaunchProfiling
            && options.enableAutoPerformanceTracing
#    if SENTRY_UIKIT_AVAILABLE
            && options.enableUIViewControllerTracing
#    endif // SENTRY_UIKIT_AVAILABLE
            && options.enableSwizzling && options.enableTracing;
        if (!shouldProfileNextLaunch) {
#    if SENTRY_UIKIT_AVAILABLE
            SENTRY_LOG_DEBUG(
                @"Won't profile next launch due to specified options configuration: "
                @"options.enableAppLaunchProfiling: %d; options.enableAutoPerformanceTracing: %d; "
                @"options.enableUIViewControllerTracing: %d; options.enableSwizzling: %d; "
                @"options.enableTracing: %d",
                options.enableAppLaunchProfiling, options.enableAutoPerformanceTracing,
                options.enableUIViewControllerTracing, options.enableSwizzling,
                options.enableTracing);
#    else
            SENTRY_LOG_DEBUG(
                             @"Won't profile next launch due to specified options configuration: "
                             @"options.enableAppLaunchProfiling: %d; options.enableAutoPerformanceTracing: %d; "
                             @"options.enableSwizzling: %d; options.enableTracing: %d",
                             options.enableAppLaunchProfiling, options.enableAutoPerformanceTracing,
                             options.enableSwizzling, options.enableTracing);
#    endif // SENTRY_UIKIT_AVAILABLE

            [SentryFileManager removeAppLaunchProfilingMarkerFile];
            return;
        }

        SentrySamplingContext *appLaunchSamplingContext;
        NSNumber *resolvedTracesSampleRate;
        if (options.tracesSampler != nil) {
            appLaunchSamplingContext = samplingContextForAppLaunches();
            resolvedTracesSampleRate = options.tracesSampler(appLaunchSamplingContext);
            SENTRY_LOG_DEBUG(
                @"Got sample rate of %@ from tracesSampler.", resolvedTracesSampleRate);
        } else if (options.tracesSampleRate != nil) {
            resolvedTracesSampleRate = options.tracesSampleRate;
            SENTRY_LOG_DEBUG(@"Got numerical traces sample rate of %@.", resolvedTracesSampleRate);
        }

        if ([resolvedTracesSampleRate compare:@0] == NSOrderedSame) {
            SENTRY_LOG_DEBUG(@"Sampling out the launch trace due to missing or 0%% sample rate.");
            [SentryFileManager removeAppLaunchProfilingMarkerFile];
            return;
        }

        id<SentryRandom> random = SentryDependencyContainer.sharedInstance.random;
        if ([[SentryTracesSampler calcSample:resolvedTracesSampleRate random:random] decision]
            != kSentrySampleDecisionYes) {
            SENTRY_LOG_DEBUG(@"Sampling out the launch trace.");
            [SentryFileManager removeAppLaunchProfilingMarkerFile];
            return;
        }

        NSNumber *resolvedProfilesSampleRate;
        if (options.profilesSampler != nil) {
            if (appLaunchSamplingContext == nil) {
                appLaunchSamplingContext = samplingContextForAppLaunches();
            }
            resolvedProfilesSampleRate = options.profilesSampler(appLaunchSamplingContext);
            SENTRY_LOG_DEBUG(
                @"Got sample rate of %@ from profilesSampler.", resolvedProfilesSampleRate);
        } else if (options.profilesSampleRate != nil) {
            resolvedProfilesSampleRate = options.profilesSampleRate;
            SENTRY_LOG_DEBUG(
                @"Got numerical profiles sample rate of %@.", resolvedProfilesSampleRate);
        }

        if ([resolvedProfilesSampleRate compare:@0] == NSOrderedSame) {
            SENTRY_LOG_DEBUG(@"Sampling out the launch profile due to missing or 0%% sample rate.");
            [SentryFileManager removeAppLaunchProfilingMarkerFile];
            return;
        }

        if ([[SentryProfilesSampler calcSample:resolvedProfilesSampleRate random:random] decision]
            != kSentrySampleDecisionYes) {
            SENTRY_LOG_DEBUG(@"Sampling out the launch profile.");
            [SentryFileManager removeAppLaunchProfilingMarkerFile];
            return;
        }

        SENTRY_LOG_DEBUG(@"Will profile the next launch.");
        [SentryFileManager writeAppLaunchProfilingMarkerFile];
    }];
}

void
startLaunchProfile(void)
{
    static dispatch_once_t onceToken;
    // this function is called from SentryTracer.load but in the future we may expose access
    // directly to customers, and we'll want to ensure it only runs once. dispatch_once is an
    // efficient operation so it's fine to leave this in the launch path in any case.
    dispatch_once(&onceToken, ^{
#    if defined(DEBUG)
        // quick and dirty way to get debug logging this early in the process run. this will get
        // overwritten once SentrySDK.startWithOptions is called according to the values of
        // SentryOptions.debug and SentryOptions.diagnosticLevel
        [SentryLog configure:YES diagnosticLevel:kSentryLevelDebug];
#    endif // defined(DEBUG)

        if (!appLaunchProfileMarkerFileExists()) {
            return;
        }

        appLaunchSystemTime = SentryDependencyContainer.sharedInstance.dateProvider.systemTime;
        appLaunchTraceLock = [[NSObject alloc] init];
        appLaunchTraceId = [[SentryId alloc] init];

        SENTRY_LOG_INFO(@"Starting app launch profile at %llu", appLaunchSystemTime);

        // don't worry about synchronizing the write here, as there should be no other tracing
        // activity going on this early in the process. this codepath is also behind a dispatch_once
        isTracingAppLaunch = [SentryProfiler startWithTracer:appLaunchTraceId];
    });
}

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
