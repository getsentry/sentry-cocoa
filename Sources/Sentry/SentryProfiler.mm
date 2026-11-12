#import "SentryProfiler+Private.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED
#    import "SentryContinuousProfiler.h"
#    import "SentryInternalDefines.h"
#    import "SentryMetricProfiler.h"
#    import "SentryProfilerSDKAdapter.h"
#    import "SentryProfilerState+ObjCpp.h"
#    import "SentryProfilingLog.h"
#    import "SentryProfilingRuntime.h"
#    import "SentrySamplingProfiler.hpp"
#    import "SentryTime.h"

#    if SENTRY_HAS_UIKIT
#        import <UIKit/UIKit.h>
#    endif // SENTRY_HAS_UIKIT

using namespace sentry::profiling;

namespace {

static const int kSentryProfilerFrequencyHz = 101;

} // namespace

#    pragma mark - Public

BOOL
sentry_isLaunchProfileCorrelatedToTraces(void)
{
    return [SentryProfilerSDKAdapter.shared configuration].launchProfileCorrelatedToTraces;
}

@implementation SentryProfiler {
    std::unique_ptr<SamplingProfiler> _samplingProfiler;
}

- (instancetype)initWithMode:(SentryProfilerMode)mode
{
    if (!(self = [super init])) {
        return nil;
    }

    SENTRY_PROFILING_LOG_DEBUG(@"Initialized new SentryProfiler %@", self);

#    if SENTRY_HAS_UIKIT
    // the frame tracker may not be running if SentryOptions.enableAutoPerformanceTracing is NO
    [SentryProfilerSDKAdapter.shared startFramesTracker];
#    endif // SENTRY_HAS_UIKIT

    [self start];

    self.metricProfiler = [[SentryMetricProfiler alloc] initWithMode:mode];
    [self.metricProfiler start];

#    if SENTRY_HAS_UIKIT
    if (mode == SentryProfilerModeTrace) {
        [SentryProfilerSDKAdapter.shared addObserver:self
                                            selector:@selector(backgroundAbort)
                                                name:UIApplicationWillResignActiveNotification
                                              object:nil];
    }
#    endif // SENTRY_HAS_UIKIT

    return self;
}

#    pragma mark - Private

- (void)backgroundAbort
{
    if (![self isRunning]) {
        SENTRY_PROFILING_LOG_WARN(@"Current profiler is not running.");
        return;
    }

    SENTRY_PROFILING_LOG_DEBUG(@"Stopping profiler %@ due to app moving to background.", self);
    [self stopForReason:SentryProfilerTruncationReasonAppMovedToBackground];
}

- (void)stopForReason:(SentryProfilerTruncationReason)reason
{
    [SentryProfilerSDKAdapter.shared setIsTracingAppLaunch:NO];
    [self.metricProfiler stop];

    if (![self isRunning]) {
        SENTRY_PROFILING_LOG_DEBUG(@"Profiler is not currently running.");
        return;
    }

    self.truncationReason = reason;

#    if SENTRY_HAS_UIKIT
    [SentryProfilerSDKAdapter.shared stopFramesTrackerIfUnused];
#    endif // SENTRY_HAS_UIKIT

    _samplingProfiler->stopSampling();
    SENTRY_PROFILING_LOG_DEBUG(@"Stopped profiler %@.", self);
}

- (void)start
{
    if (sentry_threadSanitizerIsPresent()) {
        SENTRY_PROFILING_LOG_DEBUG(@"Disabling profiling when running with TSAN");
        return;
    }

    if (_samplingProfiler != nullptr) {
        // This theoretically shouldn't be possible as long as we're checking for nil and running
        // profilers in +[start], but technically we should still cover nilness here as well. So,
        // we'll just bail and let the current one continue to do whatever it's already doing:
        // either currently sampling, or waiting to be queried and provide profile data to
        // SentryTracer for upload with transaction envelopes, so as not to lose that data.
        SENTRY_PROFILING_LOG_WARN(
            @"There is already a private profiler instance present, will not start a new one.");
        return;
    }

    SENTRY_PROFILING_LOG_DEBUG(@"Starting profiler.");

    SentryProfilerState *const state = [[SentryProfilerState alloc] init];
    self.state = state;
    _samplingProfiler = std::make_unique<SamplingProfiler>(
        [state](auto &backtrace) {
            Backtrace backtraceCopy = backtrace;
            @autoreleasepool {
                backtraceCopy.absoluteTimestamp = SentryProfilerSDKAdapter.shared.systemTime;
                [state appendBacktrace:backtraceCopy];
            }
        },
        kSentryProfilerFrequencyHz);
    _samplingProfiler->startSampling();
}

- (BOOL)isRunning
{
    if (_samplingProfiler == nullptr) {
        return NO;
    }
    return _samplingProfiler->isSampling();
}

@end

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
