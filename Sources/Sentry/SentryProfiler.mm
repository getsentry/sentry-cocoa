#import "SentryProfiler+Test.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED
#    import "NSDate+SentryExtras.h"
#    import "SentryClient+Private.h"
#    import "SentryCurrentDate.h"
#    import "SentryDebugImageProvider.h"
#    import "SentryDebugMeta.h"
#    import "SentryDefines.h"
#    import "SentryDependencyContainer.h"
#    import "SentryDevice.h"
#    import "SentryDispatchFactory.h"
#    import "SentryDispatchSourceWrapper.h"
#    import "SentryEnvelope.h"
#    import "SentryEnvelopeItemType.h"
#    import "SentryEvent+Private.h"
#    import "SentryFormatter.h"
#    import "SentryFramesTracker.h"
#    import "SentryHub+Private.h"
#    import "SentryId.h"
#    import "SentryInternalDefines.h"
#    import "SentryLog.h"
#    import "SentryMetricProfiler.h"
#    import "SentryNSProcessInfoWrapper.h"
#    import "SentryNSTimerFactory.h"
#    import "SentryProfileTimeseries.h"
#    import "SentryProfilerState+ObjCpp.h"
#    import "SentrySample.h"
#    import "SentrySamplingProfiler.hpp"
#    import "SentryScope+Private.h"
#    import "SentryScreenFrames.h"
#    import "SentrySerialization.h"
#    import "SentrySpanId.h"
#    import "SentrySystemWrapper.h"
#    import "SentryThread.h"
#    import "SentryTime.h"
#    import "SentryTracer.h"
#    import "SentryTransaction.h"
#    import "SentryTransactionContext+Private.h"

#    import <cstdint>
#    import <memory>

#    if TARGET_OS_IOS
#        import <UIKit/UIKit.h>
#    endif

const int kSentryProfilerFrequencyHz = 101;
NSTimeInterval kSentryProfilerTimeoutInterval = 30;

NSString *const kSentryProfilerSerializationKeySlowFrameRenders = @"slow_frame_renders";
NSString *const kSentryProfilerSerializationKeyFrozenFrameRenders = @"frozen_frame_renders";
NSString *const kSentryProfilerSerializationKeyFrameRates = @"screen_frame_rates";

using namespace sentry::profiling;

std::mutex _gProfilerLock;
SentryProfiler *_Nullable _gCurrentProfiler;

NSString *
profilerTruncationReasonName(SentryProfilerTruncationReason reason)
{
    switch (reason) {
    case SentryProfilerTruncationReasonNormal:
        return @"normal";
    case SentryProfilerTruncationReasonAppMovedToBackground:
        return @"backgrounded";
    case SentryProfilerTruncationReasonTimeout:
        return @"timeout";
    }
}

#    if SENTRY_HAS_UIKIT
/**
 * Convert the data structure that records timestamps for GPU frame render info from
 * SentryFramesTracker to the structure expected for profiling metrics, and throw out any that
 * didn't occur within the profile time.
 * @param useMostRecentRecording @c SentryFramesTracker doesn't stop running once it starts.
 * Although we reset the profiling timestamps each time the profiler stops and starts, concurrent
 * transactions that start after the first one won't have a screen frame rate recorded within their
 * timeframe, because it will have already been recorded for the first transaction and isn't
 * recorded again unless the system changes it. In these cases, use the most recently recorded data
 * for it.
 */
NSArray<SentrySerializedMetricReading *> *
sliceGPUData(SentryFrameInfoTimeSeries *frameInfo, SentryTransaction *transaction,
    BOOL useMostRecentRecording)
{
    auto slicedGPUEntries = [NSMutableArray<SentrySerializedMetricEntry *> array];
    __block NSNumber *nearestPredecessorValue;
    [frameInfo enumerateObjectsUsingBlock:^(
        NSDictionary<NSString *, NSNumber *> *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
        const auto timestamp = obj[@"timestamp"].unsignedLongLongValue;

        if (!orderedChronologically(transaction.startSystemTime, timestamp)) {
            SENTRY_LOG_DEBUG(@"GPU info recorded (%llu) before transaction start (%llu), "
                             @"will not report it.",
                timestamp, transaction.startSystemTime);
            nearestPredecessorValue = obj[@"value"];
            return;
        }

        if (!orderedChronologically(timestamp, transaction.endSystemTime)) {
            SENTRY_LOG_DEBUG(@"GPU info recorded after transaction finished, won't record.");
            return;
        }
        const auto relativeTimestamp = getDurationNs(transaction.startSystemTime, timestamp);

        [slicedGPUEntries addObject:@ {
            @"elapsed_since_start_ns" : sentry_stringForUInt64(relativeTimestamp),
            @"value" : obj[@"value"],
        }];
    }];
    if (useMostRecentRecording && slicedGPUEntries.count == 0 && nearestPredecessorValue != nil) {
        [slicedGPUEntries addObject:@ {
            @"elapsed_since_start_ns" : @"0",
            @"value" : nearestPredecessorValue,
        }];
    }
    return slicedGPUEntries;
}
#    endif // SENTRY_HAS_UIKIT

/** Given an array of samples with absolute timestamps, return the serialized JSON mapping with
 * their data, with timestamps normalized relative to the provided transaction's start time. */
NSArray<NSDictionary *> *
serializedSamplesWithRelativeTimestamps(
    NSArray<SentrySample *> *samples, SentryTransaction *transaction)
{
    const auto result = [NSMutableArray<NSDictionary *> array];
    [samples enumerateObjectsUsingBlock:^(
        SentrySample *_Nonnull sample, NSUInteger idx, BOOL *_Nonnull stop) {
        // This shouldn't happen as we would've filtered out any such samples, but we should still
        // guard against it before calling getDurationNs as a defensive measure
        if (!orderedChronologically(transaction.startSystemTime, sample.absoluteTimestamp)) {
            SENTRY_LOG_WARN(@"Filtered sample not chronological with transaction.");
            return;
        }
        const auto dict = [NSMutableDictionary dictionaryWithDictionary:@ {
            @"elapsed_since_start_ns" : sentry_stringForUInt64(
                getDurationNs(transaction.startSystemTime, sample.absoluteTimestamp)),
            @"thread_id" : sentry_stringForUInt64(sample.threadID),
            @"stack_id" : sample.stackIndex,
        }];
        if (sample.queueAddress) {
            dict[@"queue_address"] = sample.queueAddress;
        }

        [result addObject:dict];
    }];
    return result;
}

NSDictionary<NSString *, id> *
serializedProfileData(NSDictionary<NSString *, id> *profileData, SentryTransaction *transaction,
    SentryId *profileID, NSString *truncationReason, NSString *environment, NSString *release,
    NSDictionary<NSString *, id> *serializedMetrics, NSArray<SentryDebugMeta *> *debugMeta,
    SentryHub *hub)
{
    NSMutableArray<SentrySample *> *const samples = profileData[@"profile"][@"samples"];
    // We need at least two samples to be able to draw a stack frame for any given function: one
    // sample for the start of the frame and another for the end. Otherwise we would only have a
    // stack frame with 0 duration, which wouldn't make sense.
    if ([samples count] < 2) {
        SENTRY_LOG_DEBUG(@"Not enough samples in profile");
        [hub.getClient recordLostEvent:kSentryDataCategoryProfile
                                reason:kSentryDiscardReasonEventProcessor];
        return nil;
    }

    // slice the profile data to only include the samples/metrics within the transaction
    const auto slicedSamples = slicedProfileSamples(samples, transaction);
    if (slicedSamples.count < 2) {
        SENTRY_LOG_DEBUG(@"Not enough samples in profile during the transaction");
        [hub.getClient recordLostEvent:kSentryDataCategoryProfile
                                reason:kSentryDiscardReasonEventProcessor];
        return nil;
    }
    const auto payload = [NSMutableDictionary<NSString *, id> dictionary];
    NSMutableDictionary<NSString *, id> *const profile = [profileData[@"profile"] mutableCopy];
    profile[@"samples"] = serializedSamplesWithRelativeTimestamps(slicedSamples, transaction);
    payload[@"profile"] = profile;

    payload[@"version"] = @"1";
    const auto debugImages = [NSMutableArray<NSDictionary<NSString *, id> *> new];
    for (SentryDebugMeta *debugImage in debugMeta) {
        [debugImages addObject:[debugImage serialize]];
    }
    if (debugImages.count > 0) {
        payload[@"debug_meta"] = @ { @"images" : debugImages };
    }

    payload[@"os"] = @ {
        @"name" : sentry_getOSName(),
        @"version" : sentry_getOSVersion(),
        @"build_number" : sentry_getOSBuildNumber()
    };

    const auto isEmulated = sentry_isSimulatorBuild();
    payload[@"device"] = @{
        @"architecture" : sentry_getCPUArchitecture(),
        @"is_emulator" : @(isEmulated),
        @"locale" : NSLocale.currentLocale.localeIdentifier,
        @"manufacturer" : @"Apple",
        @"model" : isEmulated ? sentry_getSimulatorDeviceModel() : sentry_getDeviceModel()
    };

    payload[@"profile_id"] = profileID.sentryIdString;
    payload[@"truncation_reason"] = truncationReason;
    payload[@"platform"] = transaction.platform;
    payload[@"environment"] = environment;

    const auto timestamp = transaction.trace.originalStartTimestamp;
    if (UNLIKELY(timestamp == nil)) {
        SENTRY_LOG_WARN(@"There was no start timestamp on the provided transaction. Falling back "
                        @"to old behavior of using the current time.");
        payload[@"timestamp"] = [[SentryCurrentDate date] sentry_toIso8601String];
    } else {
        payload[@"timestamp"] = [timestamp sentry_toIso8601String];
    }

    payload[@"release"] = release;
    payload[@"transaction"] = @ {
        @"id" : transaction.eventId.sentryIdString,
        @"trace_id" : transaction.trace.traceId.sentryIdString,
        @"name" : transaction.transaction,
        @"active_thread_id" : [transaction.trace.transactionContext sentry_threadInfo].threadId
    };

    // add the gathered metrics
    auto metrics = serializedMetrics;

#    if SENTRY_HAS_UIKIT
    const auto framesTracker = SentryDependencyContainer.sharedInstance.framesTracker;
    const auto mutableMetrics =
        [NSMutableDictionary<NSString *, id> dictionaryWithDictionary:metrics];
    const auto slowFrames = sliceGPUData(framesTracker.currentFrames.slowFrameTimestamps,
        transaction, /*useMostRecentRecording */ NO);
    if (slowFrames.count > 0) {
        mutableMetrics[@"slow_frame_renders"] =
            @ { @"unit" : @"nanosecond", @"values" : slowFrames };
    }

    const auto frozenFrames
        = sliceGPUData(framesTracker.currentFrames.frozenFrameTimestamps, transaction,
            /*useMostRecentRecording */ NO);
    if (frozenFrames.count > 0) {
        mutableMetrics[@"frozen_frame_renders"] =
            @ { @"unit" : @"nanosecond", @"values" : frozenFrames };
    }

    if (slowFrames.count > 0 || frozenFrames.count > 0) {
        const auto frameRates
            = sliceGPUData(framesTracker.currentFrames.frameRateTimestamps, transaction,
                /*useMostRecentRecording */ YES);
        if (frameRates.count > 0) {
            mutableMetrics[@"screen_frame_rates"] = @ { @"unit" : @"hz", @"values" : frameRates };
        }
    }
    metrics = mutableMetrics;
#    endif // SENTRY_HAS_UIKIT

    if (metrics.count > 0) {
        payload[@"measurements"] = metrics;
    }

    return payload;
}

@implementation SentryProfiler {
    std::shared_ptr<SamplingProfiler> _profiler;
    SentryMetricProfiler *_metricProfiler;
    SentryDebugImageProvider *_debugImageProvider;

    SentryProfilerTruncationReason _truncationReason;
    NSTimer *_timeoutTimer;
    SentryHub *__weak _hub;
}

- (instancetype)initWithHub:(SentryHub *)hub
{
    if (!(self = [super init])) {
        return nil;
    }

    SENTRY_LOG_DEBUG(@"Initialized new SentryProfiler %@", self);
    _debugImageProvider = [SentryDependencyContainer sharedInstance].debugImageProvider;
    _hub = hub;
    return self;
}

#    pragma mark - Public

+ (void)startWithHub:(SentryHub *)hub
{
    std::lock_guard<std::mutex> l(_gProfilerLock);

    if (_gCurrentProfiler && [_gCurrentProfiler isRunning]) {
        SENTRY_LOG_DEBUG(@"A profiler is already running.");
        return;
    }

    _gCurrentProfiler = [[SentryProfiler alloc] initWithHub:hub];
    if (_gCurrentProfiler == nil) {
        SENTRY_LOG_WARN(@"Profiler was not initialized, will not proceed.");
        return;
    }

#    if SENTRY_HAS_UIKIT
    [SentryDependencyContainer.sharedInstance.framesTracker resetProfilingTimestamps];
#    endif // SENTRY_HAS_UIKIT

    [_gCurrentProfiler start];

    _gCurrentProfiler->_timeoutTimer = [SentryDependencyContainer.sharedInstance.timerFactory
        scheduledTimerWithTimeInterval:kSentryProfilerTimeoutInterval
                                target:self
                              selector:@selector(timeoutAbort)
                              userInfo:nil
                               repeats:NO];
#    if SENTRY_HAS_UIKIT
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(backgroundAbort)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:nil];
#    endif // SENTRY_HAS_UIKIT
}

+ (void)stop
{
    std::lock_guard<std::mutex> l(_gProfilerLock);

    if (!_gCurrentProfiler) {
        SENTRY_LOG_WARN(@"No current global profiler manager to stop.");
        return;
    }
    if (![_gCurrentProfiler isRunning]) {
        SENTRY_LOG_WARN(@"Current profiler is not running.");
        return;
    }

    [self stopProfilerForReason:SentryProfilerTruncationReasonNormal];
}

+ (BOOL)isRunning
{
    std::lock_guard<std::mutex> l(_gProfilerLock);
    return [_gCurrentProfiler isRunning];
}

+ (SentryEnvelopeItem *)createProfilingEnvelopeItemForTransaction:(SentryTransaction *)transaction
{
    const auto profileID = [[SentryId alloc] init];
    const auto payload = [self serializeForTransaction:transaction profileID:profileID];

#    if defined(TEST) || defined(TESTCI)
    [NSNotificationCenter.defaultCenter postNotificationName:@"SentryProfileCompleteNotification"
                                                      object:nil
                                                    userInfo:payload];
#    endif // defined(TEST) || defined(TESTCI)

    return [self envelopeItemForProfileData:payload profileID:profileID];
}

#    pragma mark - Private

+ (NSDictionary<NSString *, id> *)serializeForTransaction:(SentryTransaction *)transaction
                                                profileID:(SentryId *)profileID
{
    std::lock_guard<std::mutex> l(_gProfilerLock);

    if (_gCurrentProfiler == nil) {
        SENTRY_LOG_DEBUG(@"No profiler from which to receive data.");
        return nil;
    }

    return serializedProfileData([_gCurrentProfiler._state copyProfilingData], transaction,
        profileID, profilerTruncationReasonName(_gCurrentProfiler->_truncationReason),
        _gCurrentProfiler -> _hub.scope.environmentString
            ?: _gCurrentProfiler->_hub.getClient.options.environment,
        _gCurrentProfiler->_hub.getClient.options.releaseName,
        [_gCurrentProfiler->_metricProfiler serializeForTransaction:transaction],
        [_gCurrentProfiler->_debugImageProvider getDebugImagesCrashed:NO],
        _gCurrentProfiler -> _hub);
}

+ (void)timeoutAbort
{
    std::lock_guard<std::mutex> l(_gProfilerLock);

    if (!_gCurrentProfiler) {
        SENTRY_LOG_WARN(@"No current global profiler manager to stop.");
        return;
    }
    if (![_gCurrentProfiler isRunning]) {
        SENTRY_LOG_WARN(@"Current profiler is not running.");
        return;
    }

    SENTRY_LOG_DEBUG(@"Stopping profiler %@ due to timeout.", _gCurrentProfiler);
    [self stopProfilerForReason:SentryProfilerTruncationReasonTimeout];
}

+ (void)backgroundAbort
{
    std::lock_guard<std::mutex> l(_gProfilerLock);

    if (!_gCurrentProfiler) {
        SENTRY_LOG_WARN(@"No current global profiler manager to stop.");
        return;
    }
    if (![_gCurrentProfiler isRunning]) {
        SENTRY_LOG_WARN(@"Current profiler is not running.");
        return;
    }

    SENTRY_LOG_DEBUG(@"Stopping profiler %@ due to timeout.", _gCurrentProfiler);
    [self stopProfilerForReason:SentryProfilerTruncationReasonAppMovedToBackground];
}

+ (void)stopProfilerForReason:(SentryProfilerTruncationReason)reason
{
    [_gCurrentProfiler->_timeoutTimer invalidate];
    [_gCurrentProfiler stop];
    _gCurrentProfiler->_truncationReason = reason;
#    if SENTRY_HAS_UIKIT
    [SentryDependencyContainer.sharedInstance.framesTracker resetProfilingTimestamps];
#    endif // SENTRY_HAS_UIKIT
}

- (void)startMetricProfiler
{
    _metricProfiler = [[SentryMetricProfiler alloc] init];
    [_metricProfiler start];
}

- (void)start
{
// Disable profiling when running with TSAN because it produces a TSAN false
// positive, similar to the situation described here:
// https://github.com/envoyproxy/envoy/issues/2561
#    if defined(__has_feature)
#        if __has_feature(thread_sanitizer)
    SENTRY_LOG_DEBUG(@"Disabling profiling when running with TSAN");
    return;
#            pragma clang diagnostic push
#            pragma clang diagnostic ignored "-Wunreachable-code"
#        endif // __has_feature(thread_sanitizer)
#    endif // defined(__has_feature)

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
    self._state = state;
    _profiler = std::make_shared<SamplingProfiler>(
        [state](auto &backtrace) {
    // in test, we'll overwrite the sample's timestamp to one mocked by SentryCurrentDate
    // etal. Doing this in a unified way between tests and production required extensive
    // changes to the C++ layer, so we opted for this solution to avoid any potential
    // breakages or performance hits there.
#    if defined(TEST) || defined(TESTCI)
            Backtrace backtraceCopy = backtrace;
            backtraceCopy.absoluteTimestamp = SentryCurrentDate.systemTime;
            [state appendBacktrace:backtraceCopy];
#    else
            [state appendBacktrace:backtrace];
#    endif // defined(TEST) || defined(TESTCI)
        },
        kSentryProfilerFrequencyHz);
    _profiler->startSampling();

    [self startMetricProfiler];
}

- (void)stop
{
    if (_profiler == nullptr) {
        SENTRY_LOG_WARN(@"No profiler instance found.");
        return;
    }
    if (!_profiler->isSampling()) {
        SENTRY_LOG_WARN(@"Profiler is not currently sampling.");
        return;
    }

    _profiler->stopSampling();
    [_metricProfiler stop];
    SENTRY_LOG_DEBUG(@"Stopped profiler %@.", self);
}

+ (SentryEnvelopeItem *)envelopeItemForProfileData:(NSDictionary<NSString *, id> *)profile
                                         profileID:(SentryId *)profileID
{
    const auto JSONData = [SentrySerialization dataWithJSONObject:profile];
    if (JSONData == nil) {
        SENTRY_LOG_DEBUG(@"Failed to encode profile to JSON.");
        return nil;
    }

    const auto header = [[SentryEnvelopeItemHeader alloc] initWithType:SentryEnvelopeItemTypeProfile
                                                                length:JSONData.length];
    return [[SentryEnvelopeItem alloc] initWithHeader:header data:JSONData];
}

- (BOOL)isRunning
{
    if (_profiler == nullptr) {
        return NO;
    }
    return _profiler->isSampling();
}

#    if defined(TEST) || defined(TESTCI)
+ (SentryProfiler *)getCurrentProfiler
{
    return _gCurrentProfiler;
}
#    endif // defined(TEST) || defined(TESTCI)

@end

#endif
