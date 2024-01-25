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
#    import "SentryRandom.h"
#    import "SentrySamplerDecision.h"
#    import "SentrySampling.h"
#    import "SentrySamplingContext.h"
#    import "SentryTracerConfiguration.h"
#    import "SentryTransactionContext.h"

BOOL isTracingAppLaunch;
SentryId *_Nullable appLaunchTraceId;
NSObject *appLaunchTraceLock;
uint64_t appLaunchSystemTime;
static NSString *const kSentryLaunchProfileConfigKeyTracesSampleRate = @"traces";
static NSString *const kSentryLaunchProfileConfigKeyProfilesSampleRate = @"profiles";

typedef struct {
    BOOL shouldProfile;
    SentrySamplerDecision *tracesDecision;
    SentrySamplerDecision *profilesDecision;
} SentryLaunchProfileConfig;

#    pragma mark - Private

SentryLaunchProfileConfig
shouldProfileNextLaunch(SentryOptions *options)
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
            @"Won't profile next launch due to specified options configuration: "
            @"options.enableAppLaunchProfiling: %d; options.enableAutoPerformanceTracing: %d; "
            @"options.enableUIViewControllerTracing: %d; options.enableSwizzling: %d; "
            @"options.enableTracing: %d",
            options.enableAppLaunchProfiling, options.enableAutoPerformanceTracing,
            options.enableUIViewControllerTracing, options.enableSwizzling, options.enableTracing);
#    else
        SENTRY_LOG_DEBUG(
            @"Won't profile next launch due to specified options configuration: "
            @"options.enableAppLaunchProfiling: %d; options.enableAutoPerformanceTracing: %d; "
            @"options.enableSwizzling: %d; options.enableTracing: %d",
            options.enableAppLaunchProfiling, options.enableAutoPerformanceTracing,
            options.enableSwizzling, options.enableTracing);
#    endif // SENTRY_UIKIT_AVAILABLE

        return (SentryLaunchProfileConfig) { NO, nil, nil };
    }

    SentryTransactionContext *transactionContext =
        [[SentryTransactionContext alloc] initWithName:@"app.launch" operation:@"profile"];
    transactionContext.forNextAppLaunch = YES;
    SentrySamplingContext *context =
        [[SentrySamplingContext alloc] initWithTransactionContext:transactionContext];

    SentrySamplerDecision *tracesSamplerDecision = sampleTrace(context, options);
    if (tracesSamplerDecision.decision != kSentrySampleDecisionYes) {
        SENTRY_LOG_DEBUG(@"Sampling out the launch trace.");
        return (SentryLaunchProfileConfig) { NO, nil, nil };
    }

    SentrySamplerDecision *profilesSamplerDecision
        = sampleProfile(context, tracesSamplerDecision, options);
    if (profilesSamplerDecision.decision != kSentrySampleDecisionYes) {
        SENTRY_LOG_DEBUG(@"Sampling out the launch profile.");
        return (SentryLaunchProfileConfig) { NO, nil, nil };
    }

    SENTRY_LOG_DEBUG(@"Will profile the next launch.");
    return (SentryLaunchProfileConfig) { YES, tracesSamplerDecision, profilesSamplerDecision };
}

#    pragma mark - Public

void
configureLaunchProfiling(SentryOptions *options)
{
    [SentryDependencyContainer.sharedInstance.dispatchQueueWrapper dispatchAsyncWithBlock:^{
        SentryLaunchProfileConfig config = shouldProfileNextLaunch(options);
        if (config.shouldProfile) {
            NSMutableDictionary<NSString *, NSNumber *> *configDict =
                [NSMutableDictionary<NSString *, NSNumber *> dictionary];
            configDict[kSentryLaunchProfileConfigKeyTracesSampleRate]
                = config.tracesDecision.sampleRate;
            configDict[kSentryLaunchProfileConfigKeyProfilesSampleRate]
                = config.profilesDecision.sampleRate;
            writeAppLaunchProfilingConfigFile(configDict);
        } else {
            removeAppLaunchProfilingConfigFile();
        }
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
        if (!appLaunchProfileConfigFileExists()) {
            return;
        }

#    if defined(DEBUG)
        // quick and dirty way to get debug logging this early in the process run. this will get
        // overwritten once SentrySDK.startWithOptions is called according to the values of
        // SentryOptions.debug and SentryOptions.diagnosticLevel
        [SentryLog configure:YES diagnosticLevel:kSentryLevelDebug];
#    endif // defined(DEBUG)

        appLaunchSystemTime = SentryDependencyContainer.sharedInstance.dateProvider.systemTime;
        appLaunchTraceLock = [[NSObject alloc] init];
        appLaunchTraceId = [[SentryId alloc] init];

        SENTRY_LOG_INFO(@"Starting app launch profile at %llu", appLaunchSystemTime);

        // don't worry about synchronizing the write here, as there should be no other tracing
        // activity going on this early in the process. this codepath is also behind a dispatch_once
        isTracingAppLaunch = [SentryProfiler startWithTracer:appLaunchTraceId];
    });
}

BOOL
injectLaunchSamplerDecisions(
    SentryTransactionContext *transactionContext, SentryTracerConfiguration *configuration)
{
    NSDictionary<NSString *, NSNumber *> *rates = appLaunchProfileConfiguration();
    NSNumber *profilesRate = rates[kSentryLaunchProfileConfigKeyProfilesSampleRate];
    NSNumber *tracesRate = rates[kSentryLaunchProfileConfigKeyTracesSampleRate];
    if (profilesRate == nil || tracesRate == nil) {
        return NO;
    }
    configuration.profilesSamplerDecision =
        [[SentrySamplerDecision alloc] initWithDecision:kSentrySampleDecisionYes
                                          forSampleRate:profilesRate];
    transactionContext.sampleRate = rates[kSentryLaunchProfileConfigKeyTracesSampleRate];
    return YES;
}

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
