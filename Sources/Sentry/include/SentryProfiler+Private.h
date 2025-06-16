#import "SentryProfilingConditionals.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryDefines.h"
#    import "SentryProfilerDefines.h"

@class SentryEnvelopeItem;
@class SentryHub;
@class SentryId;
@class SentryMetricProfiler;
@class SentryOptions;
@class SentryProfileOptions;
@class SentryProfilerState;
@class SentrySamplerDecision;
@class SentryTransaction;

#    if SENTRY_HAS_UIKIT
@class SentryFramesTracker;
@class SentryScreenFrames;
#    endif // SENTRY_HAS_UIKIT

NS_ASSUME_NONNULL_BEGIN

typedef struct {
    BOOL shouldProfile;
    /** Only needed for trace launch profiling or continuous profiling v2 with trace lifecycle;
     * unused with continuous profiling. */
    SentrySamplerDecision *_Nullable tracesDecision;
    SentrySamplerDecision *_Nullable profilesDecision;
} SentryLaunchProfileConfig;

/**
 * A data structure to hold in memory the options that were persisted when configuring launch
 * profiling on the previous launch's call to @c SentrySDK.startWith(options:) .
 * @note @c profilerSessionSampleDecision and @c profileOptions will be @c nil for continuous
 * profiling v1 (continuous profiling beta).
 */
@interface SentryLaunchProfileConfiguration : NSObject

@property (assign, nonatomic, readonly) BOOL isContinuousV1;
@property (assign, nonatomic, readonly) BOOL waitForFullDisplay;
@property (strong, nonatomic, nullable, readonly)
    SentrySamplerDecision *profilerSessionSampleDecision;
@property (strong, nonatomic, nullable, readonly) SentryProfileOptions *profileOptions;

- (void)reevaluateSessionSampleRate;

SENTRY_EXTERN BOOL sentry_isLaunchProfileCorrelatedToTraces(void);

- (instancetype)initWaitingForFullDisplay:(BOOL)shouldWaitForFullDisplay
                             continuousV1:(BOOL)continuousV1;

- (instancetype)initContinuousProfilingV2WaitingForFullDisplay:(BOOL)shouldWaitForFullDisplay
                                               samplerDecision:(SentrySamplerDecision *)decision
                                                profileOptions:(SentryProfileOptions *)options;

@end

/**
 * Perform necessary profiler tasks that should take place when the SDK starts: configure the next
 * launch's profiling, stop tracer profiling if no automatic performance transaction is running,
 * start the continuous profiler if enabled and not profiling from launch.
 */
SENTRY_EXTERN void sentry_sdkInitProfilerTasks(SentryOptions *options, SentryHub *hub);

/**
 * Continuous profiling will respect its own sampling rate, which is computed once for each Sentry
 * session.
 */
SENTRY_EXTERN SentryLaunchProfileConfiguration *_Nullable sentry_launchProfileConfiguration;

SENTRY_EXTERN void sentry_reevaluateSessionSampleRate(void);

SENTRY_EXTERN void sentry_configureContinuousProfiling(SentryOptions *options);

/**
 * A wrapper around the low-level components used to gather sampled backtrace profiles.
 * @warning A main assumption is that profile start/stop must be contained within range of time of
 * the first concurrent transaction's start time and last one's end time.
 */
@interface SentryProfiler : NSObject

@property (strong, nonatomic) SentryId *profilerId;
@property (strong, nonatomic) SentryProfilerState *state;
@property (assign, nonatomic) SentryProfilerTruncationReason truncationReason;
@property (strong, nonatomic) SentryMetricProfiler *metricProfiler;

#    if SENTRY_HAS_UIKIT
/**
 * @note This property is only needed for trace profiling, to store the appropriate GPU data per
 * profiler instance when there might be multiple profiler instances all waiting for their linked
 * transactions to finish. Once we move to continuous profiling only, this won't be needed as the
 * data can be directly marshaled to the serialization function.
 */
@property (strong, nonatomic) SentryScreenFrames *screenFrameData;
#    endif // SENTRY_HAS_UIKIT

SENTRY_NO_INIT

- (instancetype)initWithMode:(SentryProfilerMode)mode;

/**
 * Stop the profiler if it is running.
 */
- (void)stopForReason:(SentryProfilerTruncationReason)reason;

/**
 * Whether the profiler instance is currently running. If not, then it probably timed out or aborted
 * due to app backgrounding and is being kept alive while its associated transactions finish so they
 * can query for its profile data. */
- (BOOL)isRunning;

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
