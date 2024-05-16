#import "SentryProfiler+Private.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED
#    import "SentryClient+Private.h"
#    import "SentryContinuousProfiler.h"
#    import "SentryDependencyContainer.h"
#    import "SentryDispatchQueueWrapper.h"
#    import "SentryHub+Private.h"
#    import "SentryLaunchProfiling.h"
#    import "SentryLog.h"
#    import "SentryMetricProfiler.h"
#    import "SentryNSTimerFactory.h"
#    import "SentryOptions+Private.h"
#    import "SentryProfilerSerialization.h"
#    import "SentryProfilerState+ObjCpp.h"
#    import "SentryProfilerTestHelpers.h"
#    import "SentrySDK+Private.h"
#    import "SentrySamplingProfiler.hpp"
#    import "SentrySwift.h"
#    import "SentryThreadWrapper.h"
#    import "SentryTime.h"

#    if SENTRY_HAS_UIKIT
#        import "SentryFramesTracker.h"
#        import "SentryNSNotificationCenterWrapper.h"
#        import "SentryUIViewControllerPerformanceTracker.h"
#        import <UIKit/UIKit.h>
#    endif // SENTRY_HAS_UIKIT

using namespace sentry::profiling;

namespace {

static const int kSentryProfilerFrequencyHz = 101;

} // namespace

#    pragma mark - Public

void
sentry_manageTraceProfilerOnStartSDK(SentryOptions *options, SentryHub *hub)
{
    [SentryDependencyContainer.sharedInstance.dispatchQueueWrapper dispatchAsyncWithBlock:^{
        BOOL shouldStopAndTransmitLaunchProfile = !options.enableContinuousProfiling;
#    if SENTRY_HAS_UIKIT
        if (SentryUIViewControllerPerformanceTracker.shared.enableWaitForFullDisplay) {
            shouldStopAndTransmitLaunchProfile = NO;
        }
#    endif // SENTRY_HAS_UIKIT
        if (shouldStopAndTransmitLaunchProfile) {
            SENTRY_LOG_DEBUG(@"Stopping launch profile in SentrySDK.start because there will "
                             @"be no automatic trace to attach it to.");
            sentry_stopAndTransmitLaunchProfile(hub);
        }
        sentry_configureLaunchProfiling(options);
    }];
}

@implementation SentryProfiler {
    std::shared_ptr<SamplingProfiler> _samplingProfiler;
    NSTimer *_Nullable _timeoutTimer;
    SentryProfilerMode _mode;
}

+ (void)load
{
    sentry_startLaunchProfile();
}

- (instancetype)initWithMode:(SentryProfilerMode)mode
{
    if (!(self = [super init])) {
        return nil;
    }

    _profilerId = [[SentryId alloc] init];
    _mode = mode;

    SENTRY_LOG_DEBUG(@"Initialized new SentryProfiler %@", self);

#    if SENTRY_HAS_UIKIT
    // the frame tracker may not be running if SentryOptions.enableAutoPerformanceTracing is NO
    [SentryDependencyContainer.sharedInstance.framesTracker start];
#    endif // SENTRY_HAS_UIKIT

    [self start];

    [self scheduleTimer];

#    if SENTRY_HAS_UIKIT
    [SentryDependencyContainer.sharedInstance.notificationCenterWrapper
        addObserver:self
           selector:@selector(backgroundAbort)
               name:UIApplicationWillResignActiveNotification
             object:nil];
#    endif // SENTRY_HAS_UIKIT

    return self;
}

#    pragma mark - Private

/**
 * Schedule a timeout timer on the main thread.
 * @warning from NSTimer.h: Timers scheduled in an async context may never fire.
 */
- (void)scheduleTimer
{
    __weak SentryProfiler *weakSelf = self;

    [SentryThreadWrapper onMainThread:^{
        if (![weakSelf isRunning]) {
            return;
        }

        SentryProfiler *strongSelf = weakSelf;
        const auto isContinuous = strongSelf->_mode == SentryProfilerModeContinuous;
        strongSelf->_timeoutTimer = [SentryDependencyContainer.sharedInstance.timerFactory
            scheduledTimerWithTimeInterval:isContinuous ? kSentryProfilerChunkExpirationInterval
                                                        : kSentryProfilerTimeoutInterval
                                    target:self
                                  selector:@selector(timerExpired)
                                  userInfo:nil
                                   repeats:isContinuous];
    }];
}

- (void)timerExpired
{
    if (![self isRunning]) {
        SENTRY_LOG_WARN(@"Current profiler is not running.");
        return;
    }

    switch (_mode) {
    default: // fall-through!
    case SentryProfilerModeTrace:
        SENTRY_LOG_DEBUG(@"Stopping profiler %@ due to timeout.", self);
        [self stopForReason:SentryProfilerTruncationReasonTimeout];
        break;
    case SentryProfilerModeContinuous:
        [self transmitChunkEnvelope];
        break;
    }
}

- (void)backgroundAbort
{
    if (![self isRunning]) {
        SENTRY_LOG_WARN(@"Current profiler is not running.");
        return;
    }

    SENTRY_LOG_DEBUG(@"Stopping profiler %@ due to app moving to background.", self);
    [self stopForReason:SentryProfilerTruncationReasonAppMovedToBackground];
}

- (void)stopForReason:(SentryProfilerTruncationReason)reason
{
    // the following line makes unit tests pass, but ui tests fail because sentry_writeProfileFile
    // needs it to be true to write to the correct path
    sentry_isTracingAppLaunch = NO;
    [_timeoutTimer invalidate];
    [self.metricProfiler stop];
    self.truncationReason = reason;

    if (![self isRunning]) {
        SENTRY_LOG_WARN(@"Profiler is not currently running.");
        return;
    }

#    if SENTRY_HAS_UIKIT
    // if SentryOptions.enableAutoPerformanceTracing is NO, then we need to stop the frames tracker
    // from running outside of profiles because it isn't needed for anything else
    if (![[[[SentrySDK currentHub] getClient] options] enableAutoPerformanceTracing]) {
        [SentryDependencyContainer.sharedInstance.framesTracker stop];
    }
#    endif // SENTRY_HAS_UIKIT

    _samplingProfiler->stopSampling();
    SENTRY_LOG_DEBUG(@"Stopped profiler %@.", self);

    if (_mode == SentryProfilerModeContinuous) {
        [self transmitChunkEnvelope];
    }
}

- (void)startMetricProfiler
{
    self.metricProfiler = [[SentryMetricProfiler alloc] initWithMode:_mode];
    [self.metricProfiler start];
}

- (void)start
{
    if (sentry_threadSanitizerIsPresent()) {
        SENTRY_LOG_DEBUG(@"Disabling profiling when running with TSAN");
        return;
    }

    if (_samplingProfiler != nullptr) {
        // This theoretically shouldn't be possible as long as we're checking for nil and running
        // profilers in +[start], but technically we should still cover nilness here as well. So,
        // we'll just bail and let the current one continue to do whatever it's already doing:
        // either currently sampling, or waiting to be queried and provide profile data to
        // SentryTracer for upload with transaction envelopes, so as not to lose that data.
        SENTRY_LOG_WARN(
            @"There is already a private profiler instance present, will not start a new one.");
        return;
    }

    // Pop the clang diagnostic to ignore unreachable code for TSAN runs
#    if defined(__has_feature)
#        if __has_feature(thread_sanitizer)
#            pragma clang diagnostic pop
#        endif // __has_feature(thread_sanitizer)
#    endif // defined(__has_feature)

    SENTRY_LOG_DEBUG(@"Starting profiler.");

    SentryProfilerState *const state = [[SentryProfilerState alloc] init];
    self.state = state;
    self.continuousChunkStartSystemTime
        = SentryDependencyContainer.sharedInstance.dateProvider.systemTime;
    _samplingProfiler = std::make_shared<SamplingProfiler>(
        [state](auto &backtrace) {
            Backtrace backtraceCopy = backtrace;
            backtraceCopy.absoluteTimestamp
                = SentryDependencyContainer.sharedInstance.dateProvider.systemTime;
            [state appendBacktrace:backtraceCopy];
        },
        kSentryProfilerFrequencyHz);
    _samplingProfiler->startSampling();

    [self startMetricProfiler];
}

- (BOOL)isRunning
{
    if (_samplingProfiler == nullptr) {
        return NO;
    }
    return _samplingProfiler->isSampling();
}

- (void)transmitChunkEnvelope
{
    const auto stateCopy = [self.state copyProfilingData];
    const auto startSystemTime = self.continuousChunkStartSystemTime;
    const auto endSystemTime = SentryDependencyContainer.sharedInstance.dateProvider.systemTime;
    self.continuousChunkStartSystemTime = endSystemTime + 1;
    [self.state clear]; // !!!: profile this to see if it takes longer than one sample duration
                        // length: ~9ms

    const auto envelope = sentry_continuousProfileChunkEnvelope(
        startSystemTime, endSystemTime, stateCopy, self.profilerId,
        [self.metricProfiler serializeBetween:startSystemTime and:endSystemTime]
#    if SENTRY_HAS_UIKIT
        ,
        self.screenFrameData
#    endif // SENTRY_HAS_UIKIT
    );
    [SentrySDK captureEnvelope:envelope];
}

@end

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
