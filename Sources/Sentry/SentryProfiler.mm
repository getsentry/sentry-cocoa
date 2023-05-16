#import "SentryProfiler+Private.h"
#import "SentryProfiler+Test.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED
#    import "NSDate+SentryExtras.h"
#    import "SentryBacktrace.hpp"
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
#    import "SentryNSTimerWrapper.h"
#    import "SentryProfileTimeseries.h"
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

#    if defined(DEBUG)
#        include <execinfo.h>
#    endif

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

NSString *
parseBacktraceSymbolsFunctionName(const char *symbol)
{
    static NSRegularExpression *regex = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        regex = [NSRegularExpression
            regularExpressionWithPattern:@"\\d+\\s+\\S+\\s+0[xX][0-9a-fA-F]+\\s+(.+)\\s+\\+\\s+\\d+"
                                 options:0
                                   error:nil];
    });
    const auto symbolNSStr = [NSString stringWithUTF8String:symbol];
    const auto match = [regex firstMatchInString:symbolNSStr
                                         options:0
                                           range:NSMakeRange(0, [symbolNSStr length])];
    if (match == nil) {
        return symbolNSStr;
    }
    return [symbolNSStr substringWithRange:[match rangeAtIndex:1]];
}

std::mutex _gProfilerLock;
SentryProfiler *_Nullable _gCurrentProfiler;
SentryNSProcessInfoWrapper *_gCurrentProcessInfoWrapper;
SentrySystemWrapper *_gCurrentSystemWrapper;
SentryDispatchFactory *_gDispatchFactory;
SentryNSTimerWrapper *_gTimeoutTimerWrapper;
#    if SENTRY_HAS_UIKIT
SentryFramesTracker *_gCurrentFramesTracker;
#    endif // SENTRY_HAS_UIKIT

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
    if (useMostRecentRecording && slicedGPUEntries.count == 0) {
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
    NSDictionary<NSString *, id> *serializedMetrics, NSArray<SentryDebugMeta *> *debugMeta)
{
    NSMutableArray<SentrySample *> *const samples = profileData[@"profile"][@"samples"];
    // We need at least two samples to be able to draw a stack frame for any given function: one
    // sample for the start of the frame and another for the end. Otherwise we would only have a
    // stack frame with 0 duration, which wouldn't make sense.
    if ([samples count] < 2) {
        SENTRY_LOG_DEBUG(@"Not enough samples in profile");
        return nil;
    }

    // slice the profile data to only include the samples/metrics within the transaction
    const auto slicedSamples = slicedProfileSamples(samples, transaction);
    if (slicedSamples.count < 2) {
        SENTRY_LOG_DEBUG(@"Not enough samples in profile during the transaction");
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
    const auto mutableMetrics =
        [NSMutableDictionary<NSString *, id> dictionaryWithDictionary:metrics];
    const auto slowFrames = sliceGPUData(_gCurrentFramesTracker.currentFrames.slowFrameTimestamps,
        transaction, /*useMostRecentRecording */ NO);
    if (slowFrames.count > 0) {
        mutableMetrics[@"slow_frame_renders"] =
            @ { @"unit" : @"nanosecond", @"values" : slowFrames };
    }

    const auto frozenFrames
        = sliceGPUData(_gCurrentFramesTracker.currentFrames.frozenFrameTimestamps, transaction,
            /*useMostRecentRecording */ NO);
    if (frozenFrames.count > 0) {
        mutableMetrics[@"frozen_frame_renders"] =
            @ { @"unit" : @"nanosecond", @"values" : frozenFrames };
    }

    if (slowFrames.count > 0 || frozenFrames.count > 0) {
        const auto frameRates
            = sliceGPUData(_gCurrentFramesTracker.currentFrames.frameRateTimestamps, transaction,
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

@implementation SentryProfilingMutableState

- (instancetype)init
{
    if (self = [super init]) {
        _samples = [NSMutableArray<SentrySample *> array];
        _stacks = [NSMutableArray<NSArray<NSNumber *> *> array];
        _frames = [NSMutableArray<NSDictionary<NSString *, id> *> array];
        _threadMetadata = [NSMutableDictionary<NSString *, NSMutableDictionary *> dictionary];
        _queueMetadata = [NSMutableDictionary<NSString *, NSDictionary *> dictionary];
        _frameIndexLookup = [NSMutableDictionary<NSString *, NSNumber *> dictionary];
        _stackIndexLookup = [NSMutableDictionary<NSString *, NSNumber *> dictionary];
    }
    return self;
}

@end

@implementation SentryProfilingState {
    SentryProfilingMutableState *_mutableState;
    std::mutex _lock;
}

- (instancetype)init
{
    if (self = [super init]) {
        _mutableState = [[SentryProfilingMutableState alloc] init];
    }
    return self;
}

- (void)mutate:(void (^)(SentryProfilingMutableState *))block
{
    NSParameterAssert(block);
    std::lock_guard<std::mutex> l(_lock);
    block(_mutableState);
}

- (void)appendBacktrace:(const Backtrace &)backtrace
{
    [self mutate:^(SentryProfilingMutableState *state) {
        const auto threadID = sentry_stringForUInt64(backtrace.threadMetadata.threadID);

        NSString *queueAddress = nil;
        if (backtrace.queueMetadata.address != 0) {
            queueAddress = sentry_formatHexAddressUInt64(backtrace.queueMetadata.address);
        }
        NSMutableDictionary<NSString *, id> *metadata = state.threadMetadata[threadID];
        if (metadata == nil) {
            metadata = [NSMutableDictionary<NSString *, id> dictionary];
            state.threadMetadata[threadID] = metadata;
        }
        if (!backtrace.threadMetadata.name.empty() && metadata[@"name"] == nil) {
            metadata[@"name"] =
                [NSString stringWithUTF8String:backtrace.threadMetadata.name.c_str()];
        }
        if (backtrace.threadMetadata.priority != -1 && metadata[@"priority"] == nil) {
            metadata[@"priority"] = @(backtrace.threadMetadata.priority);
        }
        if (queueAddress != nil && state.queueMetadata[queueAddress] == nil
            && backtrace.queueMetadata.label != nullptr) {
            state.queueMetadata[queueAddress] = @ {
                @"label" : [NSString stringWithUTF8String:backtrace.queueMetadata.label->c_str()]
            };
        }
#    if defined(DEBUG)
        const auto symbols
            = backtrace_symbols(reinterpret_cast<void *const *>(backtrace.addresses.data()),
                static_cast<int>(backtrace.addresses.size()));
#    endif

        const auto stack = [NSMutableArray<NSNumber *> array];
        for (std::vector<uintptr_t>::size_type backtraceAddressIdx = 0;
             backtraceAddressIdx < backtrace.addresses.size(); backtraceAddressIdx++) {
            const auto instructionAddress
                = sentry_formatHexAddressUInt64(backtrace.addresses[backtraceAddressIdx]);

            const auto frameIndex = state.frameIndexLookup[instructionAddress];
            if (frameIndex == nil) {
                const auto frame = [NSMutableDictionary<NSString *, id> dictionary];
                frame[@"instruction_addr"] = instructionAddress;
#    if defined(DEBUG)
                frame[@"function"]
                    = parseBacktraceSymbolsFunctionName(symbols[backtraceAddressIdx]);
#    endif
                const auto newFrameIndex = @(state.frames.count);
                [stack addObject:newFrameIndex];
                state.frameIndexLookup[instructionAddress] = newFrameIndex;
                [state.frames addObject:frame];
            } else {
                [stack addObject:frameIndex];
            }
        }

        const auto sample = [[SentrySample alloc] init];
        sample.absoluteTimestamp = backtrace.absoluteTimestamp;
        sample.threadID = backtrace.threadMetadata.threadID;
        if (queueAddress != nil) {
            sample.queueAddress = queueAddress;
        }

        const auto stackKey = [stack componentsJoinedByString:@"|"];
        const auto stackIndex = state.stackIndexLookup[stackKey];
        if (stackIndex) {
            sample.stackIndex = stackIndex;
        } else {
            const auto nextStackIndex = @(state.stacks.count);
            sample.stackIndex = nextStackIndex;
            state.stackIndexLookup[stackKey] = nextStackIndex;
            [state.stacks addObject:stack];
        }

        [state.samples addObject:sample];
    }];
}

- (NSDictionary<NSString *, id> *)copyProfilingData
{
    std::lock_guard<std::mutex> l(_lock);

    NSMutableArray<SentrySample *> *const samples = [_mutableState.samples copy];
    NSMutableArray<NSArray<NSNumber *> *> *const stacks = [_mutableState.stacks copy];
    NSMutableArray<NSDictionary<NSString *, id> *> *const frames = [_mutableState.frames copy];
    NSMutableDictionary<NSString *, NSDictionary *> *const queueMetadata =
        [_mutableState.queueMetadata copy];

    // thread metadata contains a mutable substructure, so it's not enough to perform a copy of
    // the top-level dictionary, we need to go deeper to copy the mutable subdictionaries
    const auto threadMetadata = [NSMutableDictionary<NSString *, NSDictionary *> dictionary];
    [_mutableState.threadMetadata enumerateKeysAndObjectsUsingBlock:^(NSString *_Nonnull key,
        NSDictionary *_Nonnull obj, BOOL *_Nonnull stop) { threadMetadata[key] = [obj copy]; }];

    return @{
        @"profile" : @ {
            @"samples" : samples,
            @"stacks" : stacks,
            @"frames" : frames,
            @"thread_metadata" : threadMetadata,
            @"queue_metadata" : queueMetadata
        }
    };
}

@end

@implementation SentryProfiler {
    SentryProfilingState *_state;
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
    [_gCurrentFramesTracker resetProfilingTimestamps];
#    endif // SENTRY_HAS_UIKIT

    [_gCurrentProfiler start];

    if (_gTimeoutTimerWrapper == nil) {
        _gTimeoutTimerWrapper = [[SentryNSTimerWrapper alloc] init];
    }
    _gCurrentProfiler->_timeoutTimer =
        [_gTimeoutTimerWrapper scheduledTimerWithTimeInterval:kSentryProfilerTimeoutInterval
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

#    pragma mark - Testing

+ (void)useSystemWrapper:(SentrySystemWrapper *)systemWrapper
{
    std::lock_guard<std::mutex> l(_gProfilerLock);
    _gCurrentSystemWrapper = systemWrapper;
}

+ (void)useProcessInfoWrapper:(SentryNSProcessInfoWrapper *)processInfoWrapper
{
    std::lock_guard<std::mutex> l(_gProfilerLock);
    _gCurrentProcessInfoWrapper = processInfoWrapper;
}

+ (void)useDispatchFactory:(SentryDispatchFactory *)dispatchFactory
{
    std::lock_guard<std::mutex> l(_gProfilerLock);
    _gDispatchFactory = dispatchFactory;
}

+ (void)useTimeoutTimerWrapper:(SentryNSTimerWrapper *)timerWrapper
{
    std::lock_guard<std::mutex> l(_gProfilerLock);
    _gTimeoutTimerWrapper = timerWrapper;
}

#    if SENTRY_HAS_UIKIT
+ (void)useFramesTracker:(SentryFramesTracker *)framesTracker
{
    std::lock_guard<std::mutex> l(_gProfilerLock);
    _gCurrentFramesTracker = framesTracker;
}
#    endif // SENTRY_HAS_UIKIT

#    pragma mark - Private

+ (NSDictionary<NSString *, id> *)serializeForTransaction:(SentryTransaction *)transaction
                                                profileID:(SentryId *)profileID
{
    std::lock_guard<std::mutex> l(_gProfilerLock);

    if (_gCurrentProfiler == nil) {
        SENTRY_LOG_DEBUG(@"No profiler from which to receive data.");
        return nil;
    }

    return serializedProfileData([_gCurrentProfiler->_state copyProfilingData], transaction,
        profileID, profilerTruncationReasonName(_gCurrentProfiler->_truncationReason),
        _gCurrentProfiler -> _hub.scope.environmentString
            ?: _gCurrentProfiler->_hub.getClient.options.environment,
        _gCurrentProfiler->_hub.getClient.options.releaseName,
        [_gCurrentProfiler->_metricProfiler serializeForTransaction:transaction],
        [_gCurrentProfiler->_debugImageProvider getDebugImages]);
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
    [_gCurrentFramesTracker resetProfilingTimestamps];
#    endif // SENTRY_HAS_UIKIT
}

- (void)startMetricProfiler
{
    if (_gCurrentSystemWrapper == nil) {
        _gCurrentSystemWrapper = [[SentrySystemWrapper alloc] init];
    }
    if (_gCurrentProcessInfoWrapper == nil) {
        _gCurrentProcessInfoWrapper = [SentryDependencyContainer.sharedInstance processInfoWrapper];
    }
    if (_gDispatchFactory == nil) {
        _gDispatchFactory = [[SentryDispatchFactory alloc] init];
    }
#    if SENTRY_HAS_UIKIT
    if (_gCurrentFramesTracker == nil) {
        _gCurrentFramesTracker = SentryFramesTracker.sharedInstance;
    }
#    endif // SENTRY_HAS_UIKIT
    _metricProfiler =
        [[SentryMetricProfiler alloc] initWithProcessInfoWrapper:_gCurrentProcessInfoWrapper
                                                   systemWrapper:_gCurrentSystemWrapper
                                                 dispatchFactory:_gDispatchFactory];
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

    SentryProfilingState *const state = [[SentryProfilingState alloc] init];
    _state = state;
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

@end

#endif
