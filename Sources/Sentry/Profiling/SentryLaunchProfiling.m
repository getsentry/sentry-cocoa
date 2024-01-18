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
    BOOL shouldProfileNextLaunch = options.enableAppLaunchProfiling
        && options.enableAutoPerformanceTracing
#    if SENTRY_UIKIT_AVAILABLE
        && options.enableUIViewControllerTracing
#    endif // SENTRY_UIKIT_AVAILABLE
        && options.enableSwizzling && options.enableTracing;
    if (!shouldProfileNextLaunch) {
#    if SENTRY_UIKIT_AVAILABLE
        SENTRY_LOG_DEBUG(
            @"Won't write app launch config file due to specified options configuration: "
            @"options.enableAppLaunchProfiling: %d; options.enableAutoPerformanceTracing: %d; "
            @"options.enableUIViewControllerTracing: %d; options.enableSwizzling: %d; "
            @"options.enableTracing: %d",
            options.enableAppLaunchProfiling, options.enableAutoPerformanceTracing,
            options.enableUIViewControllerTracing, options.enableSwizzling, options.enableTracing);
#    else
        SENTRY_LOG_DEBUG(
            @"Won't write app launch config file due to specified options configuration: "
            @"options.enableAppLaunchProfiling: %d; options.enableAutoPerformanceTracing: %d; "
            @"options.enableSwizzling: %d; options.enableTracing: %d",
            options.enableAppLaunchProfiling, options.enableAutoPerformanceTracing,
            options.enableSwizzling, options.enableTracing);
#    endif // SENTRY_UIKIT_AVAILABLE
    }

    [SentryDependencyContainer.sharedInstance.dispatchQueueWrapper dispatchAsyncWithBlock:^{
        SENTRY_LOG_DEBUG(@"Writing app launch profile config file...");
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

        if (!SENTRY_CASSERT_RETURN(resolvedTracesSampleRate != nil,
                @"We should always have a traces sample rate when configuring the SDK.")) {
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

        if (!SENTRY_CASSERT_RETURN(resolvedProfilesSampleRate != nil,
                @"We should always have a profiles sample rate when configuring the SDK.")) {
            return;
        }

        NSMutableDictionary<NSString *, NSNumber *> *json =
            [NSMutableDictionary<NSString *, NSNumber *> dictionary];
        json[@"tracesSampleRate"] = resolvedTracesSampleRate;
        json[@"profilesSampleRate"] = resolvedProfilesSampleRate;
        [SentryFileManager writeAppLaunchProfilingConfig:json];
    }];
}

/**
 * Decision tree:
 * ```
 * ─ is there a configuration file?
 *   ├── yes: SentryTracesSampler sampling decision?
 *   │   ├── yes: SentryProfilesSampler sampling decision?
 *   │   │   ├── yes: ✅ trace app launch
 *   │   │   └── no: ❌ do not trace app launch
 *   │   └── no: ❌ do not trace app launch
 *   └── no: ❌ do not trace app launch
 * ```
 */
BOOL
shouldTraceAppLaunch(void)
{
    [SentryFileManager load];

    NSDictionary<NSString *, NSNumber *> *launchConfig =
        [SentryFileManager appLaunchProfilingConfig];
    if (launchConfig == nil) {
        return NO;
    }

    double tracesSampleRate = [launchConfig[@"tracesSampleRate"] doubleValue];
    double profilesSampleRate = [launchConfig[@"profilesSampleRate"] doubleValue];
    if (tracesSampleRate == 0 || profilesSampleRate == 0) {
        SENTRY_LOG_DEBUG(@"Sampling out this launch trace due to sample rate of 0.");
        return NO;
    }

    [SentryTracesSampler load];
    [SentryProfilesSampler load];
    [SentryRandom load];

    SentryRandom *random = [[SentryRandom alloc] init];
    appLaunchTraceSamplerDecision = [SentryTracesSampler calcSample:tracesSampleRate random:random];
    if (appLaunchTraceSamplerDecision.decision != kSentrySampleDecisionYes) {
        SENTRY_LOG_DEBUG(@"Sampling out this launch trace due to sample decision NO.");
        return NO;
    }

    return [[SentryProfilesSampler calcSample:profilesSampleRate random:random] decision]
        == kSentrySampleDecisionYes;
}

void
startLaunchProfile(void)
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [SentryLog load];
#    if defined(DEBUG)
        // quick and dirty way to get debug logging this early in the process run. this will get
        // overwritten once SentrySDK.startWithOptions is called according to the values of
        // SentryOptions.debug and SentryOptions.diagnosticLevel
        [SentryLog configure:YES diagnosticLevel:kSentryLevelDebug];
#    endif // defined(DEBUG)

        if (!shouldTraceAppLaunch()) {
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
