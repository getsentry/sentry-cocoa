#import "SentryProfilingConditionals.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryDefines.h"
#    import <Foundation/Foundation.h>

@class SentryEnvelopeItem;
@class SentryHub;
@class SentryId;
@class SentryMetricProfiler;
@class SentryOptions;
@class SentryProfilerState;
@class SentryTransaction;

#    if SENTRY_HAS_UIKIT
@class SentryFramesTracker;
@class SentryScreenFrames;
#    endif // SENTRY_HAS_UIKIT

typedef NS_ENUM(NSUInteger, SentryProfilerTruncationReason) {
    SentryProfilerTruncationReasonNormal,
    SentryProfilerTruncationReasonTimeout,
    SentryProfilerTruncationReasonAppMovedToBackground,
};

typedef NS_ENUM(NSUInteger, SentryProfilerMode) {
    SentryProfilerModeLegacy,
    SentryProfilerModeContinuous,
};

NS_ASSUME_NONNULL_BEGIN

/**
 * Perform necessary profiler tasks that should take place when the SDK starts: configure the next
 * launch's profiling, stop legacy profiling if no automatic performance transaction is running,
 * start the continuous profiler if enabled and not profiling from launch.
 */
SENTRY_EXTERN void sentry_manageProfilerOnStartSDK(SentryOptions *options, SentryHub *hub);

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
