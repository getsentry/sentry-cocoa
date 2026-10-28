#import "SentryProfiler+Private.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED
#    import "SentryContinuousProfiler.h"
#    import "SentryDefaultProfilerSDKBackend.h"
#    import "SentryFileManagerHelper.h"
#    import "SentryInternalDefines.h"
#    import "SentryLogC.h"
#    import "SentryMetricProfiler.h"
#    import "SentryProfilerSDKAdapter.h"
#    import "SentryProfilerState+ObjCpp.h"
#    import "SentryProfilerTestHelpers.h"
#    import "SentrySamplingProfiler.hpp"
#    import "SentryTime.h"
#    import "SentryTracer+Private.h"

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

+ (void)load
{
    sentry_bootstrapProfilerSDKAdapter();

#    if defined(SENTRY_TEST) || defined(SENTRY_TEST_CI) || defined(SENTRY_UI_TEST_SUPPORT)
    // we want to allow starting a launch profile from here for UI tests, but not unit tests
    if (NSProcessInfo.processInfo.environment[@"--io.sentry.ui-test.test-name"] == nil) {
        return;
    }

    // the samples apps may want to wipe the data like before UI test case runs, or manually during
    // development, to remove any launch config files that might be present before launching the app
    // initially, however we need to make sure to remove stale versions of the file before it gets
    // used to potentially start a launch profile that shouldn't have started, so we check here for
    // this. This is runtime-gated and safe to compile in unconditionally.
    if ([NSProcessInfo.processInfo.arguments containsObject:@"--io.sentry.special.wipe-data"]) {
        removeSentryStaticBasePath();
    }
#    endif // defined(SENTRY_TEST) || defined(SENTRY_TEST_CI)

    [SentryProfilerSDKAdapter.shared startLaunchProfile];
}

- (instancetype)initWithMode:(SentryProfilerMode)mode
{
    if (!(self = [super init])) {
        return nil;
    }

    SENTRY_LOG_DEBUG(@"Initialized new SentryProfiler %@", self);

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
        SENTRY_LOG_WARN(@"Current profiler is not running.");
        return;
    }

    SENTRY_LOG_DEBUG(@"Stopping profiler %@ due to app moving to background.", self);
    [self stopForReason:SentryProfilerTruncationReasonAppMovedToBackground];
}

- (void)stopForReason:(SentryProfilerTruncationReason)reason
{
    [SentryProfilerSDKAdapter.shared setIsTracingAppLaunch:NO];
    [self.metricProfiler stop];

    if (![self isRunning]) {
        SENTRY_LOG_DEBUG(@"Profiler is not currently running.");
        return;
    }

    self.truncationReason = reason;

#    if SENTRY_HAS_UIKIT
    [SentryProfilerSDKAdapter.shared stopFramesTrackerIfUnused];
#    endif // SENTRY_HAS_UIKIT

    _samplingProfiler->stopSampling();
    SENTRY_LOG_DEBUG(@"Stopped profiler %@.", self);
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
