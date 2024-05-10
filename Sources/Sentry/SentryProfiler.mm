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
#    import "SentryProfilerState+ObjCpp.h"
#    import "SentryProfilerTestHelpers.h"
#    import "SentrySDK+Private.h"
#    import "SentrySamplingProfiler.hpp"
#    import "SentrySwift.h"
#    import "SentryThreadWrapper.h"

#    if SENTRY_HAS_UIKIT
#        import "SentryFramesTracker.h"
#        import "SentryNSNotificationCenterWrapper.h"
#        import "SentryUIViewControllerPerformanceTracker.h"
#        import <UIKit/UIKit.h>
#    endif // SENTRY_HAS_UIKIT

using namespace sentry::profiling;

namespace {

static const int kSentryProfilerFrequencyHz = 101;
NSTimeInterval kSentryProfilerTimeoutInterval = 30;

} // namespace

#    pragma mark - Public

void
sentry_manageProfilerOnStartSDK(SentryOptions *options, SentryHub *hub)
{
    BOOL shouldStopAndTransmitLaunchProfile = YES;
#    if SENTRY_HAS_UIKIT
    if (SentryUIViewControllerPerformanceTracker.shared.enableWaitForFullDisplay) {
        shouldStopAndTransmitLaunchProfile = NO;
    }
#    endif // SENTRY_HAS_UIKIT

    [SentryDependencyContainer.sharedInstance.dispatchQueueWrapper dispatchAsyncWithBlock:^{
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
}

+ (void)load
{
    sentry_startLaunchProfile();
}

#    pragma mark - Private

- (instancetype)initWithMode:(SentryProfilerMode)mode
{
    if (!(self = [super init])) {
        return nil;
    }

    _profilerId = [[SentryId alloc] init];

    SENTRY_LOG_DEBUG(@"Initialized new SentryProfiler %@", self);

#    if SENTRY_HAS_UIKIT
    // the frame tracker may not be running if SentryOptions.enableAutoPerformanceTracing is NO
    [SentryDependencyContainer.sharedInstance.framesTracker start];
#    endif // SENTRY_HAS_UIKIT

    [self start];

    if (mode == SentryProfilerModeLegacy) {
        [self scheduleTimeoutTimer];
    }

#    if SENTRY_HAS_UIKIT
    [SentryDependencyContainer.sharedInstance.notificationCenterWrapper
        addObserver:self
           selector:@selector(backgroundAbort)
               name:UIApplicationWillResignActiveNotification
             object:nil];
#    endif // SENTRY_HAS_UIKIT

    return self;
}

/**
 * Schedule a timeout timer on the main thread.
 * @warning from NSTimer.h: Timers scheduled in an async context may never fire.
 */
- (void)scheduleTimeoutTimer
{
    __weak SentryProfiler *weakSelf = self;

    [SentryThreadWrapper onMainThread:^{
        if (![weakSelf isRunning]) {
            return;
        }

        SentryProfiler *strongSelf = weakSelf;
        strongSelf->_timeoutTimer = [SentryDependencyContainer.sharedInstance.timerFactory
            scheduledTimerWithTimeInterval:kSentryProfilerTimeoutInterval
                                    target:self
                                  selector:@selector(timeoutAbort)
                                  userInfo:nil
                                   repeats:NO];
    }];
}

- (void)timeoutAbort
{
    if (![self isRunning]) {
        SENTRY_LOG_WARN(@"Current profiler is not running.");
        return;
    }

    SENTRY_LOG_DEBUG(@"Stopping profiler %@ due to timeout.", self);
    [self stopForReason:SentryProfilerTruncationReasonTimeout];
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
}

- (void)startMetricProfiler
{
    self.metricProfiler = [[SentryMetricProfiler alloc] init];
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
    _samplingProfiler = std::make_shared<SamplingProfiler>(
        [state](auto &backtrace) {
    // in test, we'll overwrite the sample's timestamp to one mocked by SentryCurrentDate
    // etal. Doing this in a unified way between tests and production required extensive
    // changes to the C++ layer, so we opted for this solution to avoid any potential
    // breakages or performance hits there.
#    if defined(TEST) || defined(TESTCI) || defined(DEBUG)
            Backtrace backtraceCopy = backtrace;
            backtraceCopy.absoluteTimestamp
                = SentryDependencyContainer.sharedInstance.dateProvider.systemTime;
            [state appendBacktrace:backtraceCopy];
#    else
            [state appendBacktrace:backtrace];
#    endif // defined(TEST) || defined(TESTCI) || defined(DEBUG)
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

@end

#endif
