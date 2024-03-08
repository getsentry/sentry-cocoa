#import "SentryLaunchProfiling.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryDependencyContainer.h"
#    import "SentryDispatchQueueWrapper.h"
#    import "SentryFileManager.h"
#    import "SentryInternalDefines.h"
#    import "SentryLog.h"
#    import "SentryOptions.h"
#    import "SentryProfiler.h"
#    import "SentryRandom.h"
#    import "SentrySamplerDecision.h"
#    import "SentrySampling.h"
#    import "SentrySamplingContext.h"
#    import "SentrySwift.h"
#    import "SentryTraceOrigins.h"
#    import "SentryTracer+Private.h"
#    import "SentryTracerConfiguration.h"
#    import "SentryTransactionContext+Private.h"

NS_ASSUME_NONNULL_BEGIN

BOOL isTracingAppLaunch;
NSString *const kSentryLaunchProfileConfigKeyTracesSampleRate = @"traces";
NSString *const kSentryLaunchProfileConfigKeyProfilesSampleRate = @"profiles";
static SentryTracer *_Nullable launchTracer;

#    pragma mark - Private

typedef struct {
    BOOL shouldProfile;
    SentrySamplerDecision *_Nullable tracesDecision;
    SentrySamplerDecision *_Nullable profilesDecision;
} SentryLaunchProfileConfig;

SentryLaunchProfileConfig
shouldProfileNextLaunch(SentryOptions *options)
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

SentryTransactionContext *
context(NSNumber *tracesRate)
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

SentryTracerConfiguration *
config(NSNumber *profilesRate)
{
    SentryTracerConfiguration *config = [SentryTracerConfiguration defaultConfiguration];
    config.profilesSamplerDecision =
        [[SentrySamplerDecision alloc] initWithDecision:kSentrySampleDecisionYes
                                          forSampleRate:profilesRate];
    return config;
}

void
startLaunchProfile(void)
{
    static dispatch_once_t onceToken;
    // this function is called from SentryTracer.load but in the future we may expose access
    // directly to customers, and we'll want to ensure it only runs once. dispatch_once is an
    // efficient operation so it's fine to leave this in the launch path in any case.
    dispatch_once(&onceToken, ^{
        isTracingAppLaunch = appLaunchProfileConfigFileExists();
        if (!isTracingAppLaunch) {
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

        SENTRY_LOG_INFO(@"Starting app launch profile.");
        launchTracer = [[SentryTracer alloc] initWithTransactionContext:context(tracesRate)
                                                                    hub:nil
                                                          configuration:config(profilesRate)];
    });
}

void
stopLaunchProfile(SentryHub *hub)
{
    if (launchTracer == nil) {
        SENTRY_LOG_DEBUG(@"No launch tracer present to stop.");
        return;
    }

    SENTRY_LOG_DEBUG(@"Finishing launch tracer.");

    launchTracer.hub = hub;
    [launchTracer finish];
}

NS_ASSUME_NONNULL_END

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
