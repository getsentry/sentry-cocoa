#import "SentryLaunchProfiling.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryDependencyContainer.h"
#    import "SentryDispatchQueueWrapper.h"
#    import "SentryFileManager.h"
#    import "SentryInternalDefines.h"
#    import "SentryLaunchProfiling.h"
#    import "SentryLog.h"
#    import "SentryOptions.h"
#    import "SentryProfiler+Private.h"
#    import "SentryRandom.h"
#    import "SentrySamplerDecision.h"
#    import "SentrySampling.h"
#    import "SentrySamplingContext.h"
#    import "SentrySwift.h"
#    import "SentryTime.h"
#    import "SentryTraceOrigins.h"
#    import "SentryTracer+Private.h"
#    import "SentryTracerConfiguration.h"
#    import "SentryTransactionContext+Private.h"

NS_ASSUME_NONNULL_BEGIN

#    pragma mark - Private

static SentryTracer *_Nullable sentry_launchTracer;

SentryTracerConfiguration *
sentry_config(NSNumber *profilesRate)
{
    SentryTracerConfiguration *config = [SentryTracerConfiguration defaultConfiguration];
    config.profilesSamplerDecision =
        [[SentrySamplerDecision alloc] initWithDecision:kSentrySampleDecisionYes
                                          forSampleRate:profilesRate];
    return config;
}

#    pragma mark - Package

typedef struct {
    BOOL shouldProfile;
    SentrySamplerDecision *_Nullable tracesDecision;
    SentrySamplerDecision *_Nullable profilesDecision;
} SentryLaunchProfileConfig;

NSString *const kSentryLaunchProfileConfigKeyTracesSampleRate = @"traces";
NSString *const kSentryLaunchProfileConfigKeyProfilesSampleRate = @"profiles";

SentryLaunchProfileConfig
sentry_shouldProfileNextLaunch(SentryOptions *options)
{
    BOOL shouldProfileNextLaunch = options.enableAppLaunchProfiling && options.enableTracing;
    if (!shouldProfileNextLaunch) {
        SENTRY_LOG_DEBUG(@"Won't profile next launch due to specified options configuration: "
                         @"options.enableAppLaunchProfiling: %d; options.enableTracing: %d",
            options.enableAppLaunchProfiling, options.enableTracing);
        return (SentryLaunchProfileConfig) { NO, nil, nil };
    }

    SentryTransactionContext *transactionContext =
        [[SentryTransactionContext alloc] initWithName:@"app.launch" operation:@"profile"];
    transactionContext.forNextAppLaunch = YES;
    SentrySamplingContext *context =
        [[SentrySamplingContext alloc] initWithTransactionContext:transactionContext];

    SentrySamplerDecision *tracesSamplerDecision = sentry_sampleTrace(context, options);
    if (tracesSamplerDecision.decision != kSentrySampleDecisionYes) {
        SENTRY_LOG_DEBUG(@"Sampling out the launch trace.");
        return (SentryLaunchProfileConfig) { NO, nil, nil };
    }

    SentrySamplerDecision *profilesSamplerDecision
        = sentry_sampleProfile(context, tracesSamplerDecision, options);
    if (profilesSamplerDecision.decision != kSentrySampleDecisionYes) {
        SENTRY_LOG_DEBUG(@"Sampling out the launch profile.");
        return (SentryLaunchProfileConfig) { NO, nil, nil };
    }

    SENTRY_LOG_DEBUG(@"Will profile the next launch.");
    return (SentryLaunchProfileConfig) { YES, tracesSamplerDecision, profilesSamplerDecision };
}

SentryTransactionContext *
sentry_context(NSNumber *tracesRate)
{
    SentryTransactionContext *context =
        [[SentryTransactionContext alloc] initWithName:@"launch"
                                            nameSource:kSentryTransactionNameSourceCustom
                                             operation:@"app.lifecycle"
                                                origin:SentryTraceOriginAutoAppStartProfile
                                               sampled:kSentrySampleDecisionYes];
    context.sampleRate = tracesRate;
    return context;
}

#    pragma mark - Public

BOOL sentry_isTracingAppLaunch;

void
sentry_configureLaunchProfiling(SentryOptions *options)
{
    [SentryDependencyContainer.sharedInstance.dispatchQueueWrapper dispatchAsyncWithBlock:^{
        SentryLaunchProfileConfig config = sentry_shouldProfileNextLaunch(options);
        if (!config.shouldProfile) {
            removeAppLaunchProfilingConfigFile();
            return;
        }

        NSMutableDictionary<NSString *, NSNumber *> *configDict =
            [NSMutableDictionary<NSString *, NSNumber *> dictionary];
        configDict[kSentryLaunchProfileConfigKeyTracesSampleRate]
            = config.tracesDecision.sampleRate;
        configDict[kSentryLaunchProfileConfigKeyProfilesSampleRate]
            = config.profilesDecision.sampleRate;
        writeAppLaunchProfilingConfigFile(configDict);
    }];
}

void
sentry_startLaunchProfile(void)
{

    static dispatch_once_t onceToken;
    // this function is called from SentryTracer.load but in the future we may expose access
    // directly to customers, and we'll want to ensure it only runs once. dispatch_once is an
    // efficient operation so it's fine to leave this in the launch path in any case.
    dispatch_once(&onceToken, ^{
        sentry_isTracingAppLaunch = appLaunchProfileConfigFileExists();
        if (!sentry_isTracingAppLaunch) {
            return;
        }

#    if defined(DEBUG)
        // quick and dirty way to get debug logging this early in the process run. this will get
        // overwritten once SentrySDK.startWithOptions is called according to the values of
        // SentryOptions.debug and SentryOptions.diagnosticLevel
        [SentryLog configure:YES diagnosticLevel:kSentryLevelDebug];
#    endif // defined(DEBUG)

        NSDictionary<NSString *, NSNumber *> *rates = appLaunchProfileConfiguration();
        NSNumber *profilesRate = rates[kSentryLaunchProfileConfigKeyProfilesSampleRate];
        NSNumber *tracesRate = rates[kSentryLaunchProfileConfigKeyTracesSampleRate];
        if (profilesRate == nil || tracesRate == nil) {
            SENTRY_LOG_DEBUG(
                @"Received a nil configured launch sample rate, will not trace or profile.");
            return;
        }

        SENTRY_LOG_INFO(@"Starting app launch profile at %llu.", getAbsoluteTime());
        sentry_launchTracer =
            [[SentryTracer alloc] initWithTransactionContext:sentry_context(tracesRate)
                                                         hub:nil
                                               configuration:sentry_config(profilesRate)];
    });
}

void
sentry_stopAndTransmitLaunchProfile(SentryHub *hub)
{
    if (sentry_launchTracer == nil) {
        SENTRY_LOG_DEBUG(@"No launch tracer present to stop.");
        return;
    }

    sentry_launchTracer.hub = hub;
    sentry_stopAndDiscardLaunchProfileTracer();
}

void
sentry_stopAndDiscardLaunchProfileTracer(void)
{
    SENTRY_LOG_DEBUG(@"Finishing launch tracer.");
    [sentry_launchTracer finish];
}

NS_ASSUME_NONNULL_END

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
