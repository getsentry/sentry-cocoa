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
#    import "SentryNSNotificationCenterWrapper.h"
#    import "SentryNSTimerFactory.h"
#    import "SentryOptions.h"
#    import "SentryProfileTimeseries.h"
#    import "SentryProfiledTracerConcurrency.h"
#    import "SentryProfilerState+ObjCpp.h"
#    import "SentryProfilerTestHelpers.h"
#    import "SentrySDK+Private.h"
#    import "SentrySamplingProfiler.hpp"
#    import "SentrySwift.h"
#    import "SentryThreadWrapper.h"

#    import <cstdint>
#    import <memory>

#    if SENTRY_HAS_UIKIT
#        import "SentryFramesTracker.h"
#        import "SentryUIViewControllerPerformanceTracker.h"
#        import <UIKit/UIKit.h>
#    endif // SENTRY_HAS_UIKIT

using namespace sentry::profiling;

namespace {

const int kSentryProfilerFrequencyHz = 101;
NSTimeInterval kSentryProfilerTimeoutInterval = 30;

std::mutex _gProfilerLock;
SentryProfiler *_Nullable _gCurrentProfiler;

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
    std::shared_ptr<SamplingProfiler> _profiler;
    NSTimer *_timeoutTimer;
}

#    pragma mark - Private

- (instancetype)init
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
    [self scheduleTimeoutTimer];

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

+ (BOOL)startWithTracer:(SentryId *)traceId
{
    std::lock_guard<std::mutex> l(_gProfilerLock);

    if (_gCurrentProfiler && [_gCurrentProfiler isRunning]) {
        SENTRY_LOG_DEBUG(@"A profiler is already running.");
        sentry_trackProfilerForTracer(_gCurrentProfiler, traceId);
        // record a new metric sample for every concurrent span start
        [_gCurrentProfiler.metricProfiler recordMetrics];
        return YES;
    }

    _gCurrentProfiler = [[SentryProfiler alloc] init];
    if (_gCurrentProfiler == nil) {
        SENTRY_LOG_WARN(@"Profiler was not initialized, will not proceed.");
        return NO;
    }

    sentry_trackProfilerForTracer(_gCurrentProfiler, traceId);
    return YES;
}

+ (BOOL)isCurrentlyProfiling
{
    std::lock_guard<std::mutex> l(_gProfilerLock);
    return [_gCurrentProfiler isRunning];
}

+ (void)recordMetrics
{
    std::lock_guard<std::mutex> l(_gProfilerLock);
    if (_gCurrentProfiler == nil) {
        return;
    }
    [_gCurrentProfiler.metricProfiler recordMetrics];
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

    _profiler->stopSampling();
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

    if (_profiler != nullptr) {
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
    _profiler = std::make_shared<SamplingProfiler>(
        [state](auto &backtrace) {
    // in test, we'll overwrite the sample's timestamp to one mocked by SentryCurrentDate
    // etal. Doing this in a unified way between tests and production required extensive
    // changes to the C++ layer, so we opted for this solution to avoid any potential
    // breakages or performance hits there.
#    if defined(TEST) || defined(TESTCI)
            Backtrace backtraceCopy = backtrace;
            backtraceCopy.absoluteTimestamp
                = SentryDependencyContainer.sharedInstance.dateProvider.systemTime;
            [state appendBacktrace:backtraceCopy];
#    else
            [state appendBacktrace:backtrace];
#    endif // defined(TEST) || defined(TESTCI)
        },
        kSentryProfilerFrequencyHz);
    _profiler->startSampling();

    [self startMetricProfiler];
}

- (BOOL)isRunning
{
    if (_profiler == nullptr) {
        return NO;
    }
    return _profiler->isSampling();
}

#    pragma mark - Testing helpers

#    if defined(TEST) || defined(TESTCI)
+ (SentryProfiler *)getCurrentProfiler
{
    return _gCurrentProfiler;
}

+ (void)resetConcurrencyTracking
{
    sentry_resetConcurrencyTracking();
}

+ (NSUInteger)currentProfiledTracers
{
    return sentry_currentProfiledTracers();
}
#    endif // defined(TEST) || defined(TESTCI)

@end

#endif
