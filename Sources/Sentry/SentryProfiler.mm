#import "SentryProfiler.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED
#    import "SentryBacktrace.hpp"
#    import "SentryClient+Private.h"
#    import "SentryDebugImageProvider.h"
#    import "SentryDebugMeta.h"
#    import "SentryDefines.h"
#    import "SentryDependencyContainer.h"
#    import "SentryDevice.h"
#    import "SentryEnvelope.h"
#    import "SentryEnvelopeItemType.h"
#    import "SentryFramesTracker.h"
#    import "SentryHexAddressFormatter.h"
#    import "SentryHub+Private.h"
#    import "SentryId.h"
#    import "SentryLog.h"
#    import "SentrySamplingProfiler.hpp"
#    import "SentryScope+Private.h"
#    import "SentryScreenFrames.h"
#    import "SentrySerialization.h"
#    import "SentrySpanId.h"
#    import "SentryTime.h"
#    import "SentryTransaction.h"
#    import "SentryTransactionContext.h"

#    if defined(DEBUG)
#        include <execinfo.h>
#    endif

#    import <cstdint>
#    import <memory>

#    if TARGET_OS_IOS
#        import <UIKit/UIKit.h>
#    endif

const int kSentryProfilerFrequencyHz = 101;
NSString *const kTestStringConst = @"test";

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
NSMutableDictionary<SentrySpanId *, SentryProfiler *> *_gProfilersPerSpanID;
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

@implementation SentryProfiler {
    NSMutableDictionary<NSString *, id> *_profile;
    uint64_t _startTimestamp;
    NSDate *_startDate;
    uint64_t _endTimestamp;
    NSDate *_endDate;
    std::shared_ptr<SamplingProfiler> _profiler;
    SentryDebugImageProvider *_debugImageProvider;
    thread::TIDType _mainThreadID;

    NSMutableArray<SentrySpanId *> *_spansInFlight;
    NSMutableArray<SentryTransaction *> *_transactions;
    SentryProfilerTruncationReason _truncationReason;
    SentryScreenFrames *_frameInfo;
    NSTimer *_timeoutTimer;
    SentryHub *__weak _hub;
}

+ (void)initialize
{
#    if SENTRY_TARGET_PROFILING_SUPPORTED
    if (self == [SentryProfiler class]) {
        _gProfilersPerSpanID = [NSMutableDictionary<SentrySpanId *, SentryProfiler *> dictionary];
    }
#    endif // SENTRY_TARGET_PROFILING_SUPPORTED
}

#    if SENTRY_TARGET_PROFILING_SUPPORTED
- (instancetype)init
{
    if (![NSThread isMainThread]) {
        SENTRY_LOG_ERROR(@"SentryProfiler must be initialized on the main thread");
        return nil;
    }

    if (!(self = [super init])) {
        return nil;
    }

    SENTRY_LOG_DEBUG(@"Initialized new SentryProfiler %@", self);
    _debugImageProvider = [SentryDependencyContainer sharedInstance].debugImageProvider;
    _mainThreadID = ThreadHandle::current()->tid();
    _spansInFlight = [NSMutableArray<SentrySpanId *> array];
    _transactions = [NSMutableArray<SentryTransaction *> array];
    return self;
}
#    endif

#    pragma mark - Public

+ (void)startForSpanID:(SentrySpanId *)spanID hub:(SentryHub *)hub
{
#    if SENTRY_TARGET_PROFILING_SUPPORTED
    NSTimeInterval timeoutInterval = 30;
#        if defined(TEST) || defined(TESTCI)
    timeoutInterval = 1;
#        endif
    [self startForSpanID:spanID hub:hub timeoutInterval:timeoutInterval];
#    endif
}

+ (void)startForSpanID:(SentrySpanId *)spanID
                   hub:(SentryHub *)hub
       timeoutInterval:(NSTimeInterval)timeoutInterval
{
#    if SENTRY_TARGET_PROFILING_SUPPORTED
    std::lock_guard<std::mutex> l(_gProfilerLock);

    if (_gCurrentProfiler == nil) {
        _gCurrentProfiler = [[SentryProfiler alloc] init];
#        if SENTRY_HAS_UIKIT
        [SentryFramesTracker.sharedInstance resetProfilingTimestamps];
#        endif // SENTRY_HAS_UIKIT
        [_gCurrentProfiler start];
        _gCurrentProfiler->_timeoutTimer =
            [NSTimer scheduledTimerWithTimeInterval:timeoutInterval
                                             target:self
                                           selector:@selector(timeoutAbort)
                                           userInfo:nil
                                            repeats:NO];
#        if SENTRY_HAS_UIKIT
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(backgroundAbort)
                                                     name:UIApplicationWillResignActiveNotification
                                                   object:nil];
#        endif // SENTRY_HAS_UIKIT
        _gCurrentProfiler->_hub = hub;
    }

    SENTRY_LOG_DEBUG(
        @"Tracking span with ID %@ with profiler %@", spanID.sentrySpanIdString, _gCurrentProfiler);
    [_gCurrentProfiler->_spansInFlight addObject:spanID];
    _gProfilersPerSpanID[spanID] = _gCurrentProfiler;
#    endif // SENTRY_TARGET_PROFILING_SUPPORTED
}

+ (void)stopProfilingSpan:(id<SentrySpan>)span
{
#    if SENTRY_TARGET_PROFILING_SUPPORTED
    std::lock_guard<std::mutex> l(_gProfilerLock);

    if (_gCurrentProfiler == nil) {
        SENTRY_LOG_DEBUG(
            @"No profiler tracking span with id %@", span.context.spanId.sentrySpanIdString);
        return;
    }

    [_gCurrentProfiler->_spansInFlight removeObject:span.context.spanId];
    if (_gCurrentProfiler->_spansInFlight.count == 0) {
        SENTRY_LOG_DEBUG(@"Stopping profiler %@ because span with id %@ was last being profiled.",
            _gCurrentProfiler, span.context.spanId.sentrySpanIdString);
        [self stopProfilerForReason:SentryProfilerTruncationReasonNormal];
    }
#    endif // SENTRY_TARGET_PROFILING_SUPPORTED
}

+ (void)dropTransaction:(SentryTransaction *)transaction
{
#    if SENTRY_TARGET_PROFILING_SUPPORTED
    std::lock_guard<std::mutex> l(_gProfilerLock);

    const auto spanID = transaction.trace.context.spanId;
    const auto profiler = _gProfilersPerSpanID[spanID];
    if (profiler == nil) {
        SENTRY_LOG_DEBUG(@"No profiler tracking span with id %@", spanID.sentrySpanIdString);
        return;
    }

    [self captureEnvelopeIfFinished:profiler spanID:spanID];
#    endif // SENTRY_TARGET_PROFILING_SUPPORTED
}

+ (void)linkTransaction:(SentryTransaction *)transaction
{
#    if SENTRY_TARGET_PROFILING_SUPPORTED
    std::lock_guard<std::mutex> l(_gProfilerLock);

    const auto spanID = transaction.trace.context.spanId;
    SentryProfiler *profiler = _gProfilersPerSpanID[spanID];
    if (profiler == nil) {
        SENTRY_LOG_DEBUG(@"No profiler tracking span with id %@", spanID.sentrySpanIdString);
        return;
    }

    SENTRY_LOG_DEBUG(@"Found profiler waiting for span with ID %@: %@",
        transaction.trace.context.spanId.sentrySpanIdString, profiler);
    [profiler addTransaction:transaction];

    [self captureEnvelopeIfFinished:profiler spanID:spanID];
#    endif // SENTRY_TARGET_PROFILING_SUPPORTED
}

+ (BOOL)isRunning
{
#    if SENTRY_TARGET_PROFILING_SUPPORTED
    std::lock_guard<std::mutex> l(_gProfilerLock);
    return [_gCurrentProfiler isRunning];
#    endif // SENTRY_TARGET_PROFILING_SUPPORTED
}

#    pragma mark - Private

+ (void)captureEnvelopeIfFinished:(SentryProfiler *)profiler spanID:(SentrySpanId *)spanID
{
    [_gProfilersPerSpanID removeObjectForKey:spanID];
    [profiler->_spansInFlight removeObject:spanID];
    if (profiler->_spansInFlight.count == 0) {
        [profiler captureEnvelope];
        [profiler->_transactions removeAllObjects];
    } else {
        SENTRY_LOG_DEBUG(@"Profiler %@ is waiting for more spans to complete.", profiler);
    }
}

+ (void)timeoutAbort
{
    std::lock_guard<std::mutex> l(_gProfilerLock);

    if (_gCurrentProfiler == nil) {
        SENTRY_LOG_DEBUG(@"No current profiler to stop.");
        return;
    }

    SENTRY_LOG_DEBUG(@"Stopping profiler %@ due to timeout.", _gCurrentProfiler);
    [self stopProfilerForReason:SentryProfilerTruncationReasonTimeout];
}

+ (void)backgroundAbort
{
    std::lock_guard<std::mutex> l(_gProfilerLock);

    if (_gCurrentProfiler == nil) {
        SENTRY_LOG_DEBUG(@"No current profiler to stop.");
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
    _gCurrentProfiler->_frameInfo = SentryFramesTracker.sharedInstance.currentFrames;
    [SentryFramesTracker.sharedInstance resetProfilingTimestamps];
#    endif // SENTRY_HAS_UIKIT
    _gCurrentProfiler = nil;
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
#        endif
#    endif
    @synchronized(self) {
#    pragma clang diagnostic pop
        if (_profiler != nullptr) {
            _profiler->stopSampling();
        }
        _profile = [NSMutableDictionary<NSString *, id> dictionary];
        const auto sampledProfile = [NSMutableDictionary<NSString *, id> dictionary];

        /*
         * Maintain an index of unique frames to avoid duplicating large amounts of data. Every
         * unique frame is stored in an array, and every time a stack trace is captured for a
         * sample, the stack is stored as an array of integers indexing into the array of frames.
         * Stacks are thusly also stored as unique elements in their own index, an array of arrays
         * of frame indices, and each sample references a stack by index, to deduplicate common
         * stacks between samples, such as when the same deep function call runs across multiple
         * samples.
         *
         * E.g. if we have the following samples in the following function call stacks:
         *
         *              v sample1    v sample2               v sample3    v sample4
         * |-foo--------|------------|-----|    |-abc--------|------------|-----|
         *    |-bar-----|------------|--|          |-def-----|------------|--|
         *      |-baz---|------------|-|             |-ghi---|------------|-|
         *
         * Then we'd wind up with the following structures:
         *
         * frames: [
         *   { function: foo, instruction_addr: ... },
         *   { function: bar, instruction_addr: ... },
         *   { function: baz, instruction_addr: ... },
         *   { function: abc, instruction_addr: ... },
         *   { function: def, instruction_addr: ... },
         *   { function: ghi, instruction_addr: ... }
         * ]
         * stacks: [ [0, 1, 2], [3, 4, 5] ]
         * samples: [
         *   { stack_id: 0, ... },
         *   { stack_id: 0, ... },
         *   { stack_id: 1, ... },
         *   { stack_id: 1, ... }
         * ]
         */
        const auto samples = [NSMutableArray<NSDictionary<NSString *, id> *> array];
        const auto stacks = [NSMutableArray<NSMutableArray<NSNumber *> *> array];
        const auto frames = [NSMutableArray<NSDictionary<NSString *, id> *> array];
        sampledProfile[@"samples"] = samples;
        sampledProfile[@"stacks"] = stacks;
        sampledProfile[@"frames"] = frames;

        const auto threadMetadata =
            [NSMutableDictionary<NSString *, NSMutableDictionary *> dictionary];
        const auto queueMetadata = [NSMutableDictionary<NSString *, NSDictionary *> dictionary];
        sampledProfile[@"thread_metadata"] = threadMetadata;
        sampledProfile[@"queue_metadata"] = queueMetadata;
        _profile[@"sampled_profile"] = sampledProfile;
        _startTimestamp = getAbsoluteTime();
        _startDate = [NSDate date];

        SENTRY_LOG_DEBUG(@"Starting profiler %@ at system time %llu.", self, _startTimestamp);

        __weak const auto weakSelf = self;
        _profiler = std::make_shared<SamplingProfiler>(
            [weakSelf, threadMetadata, queueMetadata, samples, mainThreadID = _mainThreadID, frames,
                stacks](auto &backtrace) {
                const auto strongSelf = weakSelf;
                if (strongSelf == nil) {
                    return;
                }
                const auto threadID = [@(backtrace.threadMetadata.threadID) stringValue];
                NSString *queueAddress = nil;
                if (backtrace.queueMetadata.address != 0) {
                    queueAddress = sentry_formatHexAddress(@(backtrace.queueMetadata.address));
                }
                NSMutableDictionary<NSString *, id> *metadata = threadMetadata[threadID];
                if (metadata == nil) {
                    metadata = [NSMutableDictionary<NSString *, id> dictionary];
                    if (backtrace.threadMetadata.threadID == mainThreadID) {
                        metadata[@"is_main_thread"] = @YES;
                    }
                    threadMetadata[threadID] = metadata;
                }
                if (!backtrace.threadMetadata.name.empty() && metadata[@"name"] == nil) {
                    metadata[@"name"] =
                        [NSString stringWithUTF8String:backtrace.threadMetadata.name.c_str()];
                }
                if (backtrace.threadMetadata.priority != -1 && metadata[@"priority"] == nil) {
                    metadata[@"priority"] = @(backtrace.threadMetadata.priority);
                }
                if (queueAddress != nil && queueMetadata[queueAddress] == nil
                    && backtrace.queueMetadata.label != nullptr) {
                    queueMetadata[queueAddress] = @{
                        @"label" :
                            [NSString stringWithUTF8String:backtrace.queueMetadata.label->c_str()]
                    };
                }
#    if defined(DEBUG)
                const auto symbols
                    = backtrace_symbols(reinterpret_cast<void *const *>(backtrace.addresses.data()),
                        static_cast<int>(backtrace.addresses.size()));
#    endif

                const auto stack = [NSMutableArray<NSNumber *> array];
                const auto frameIndexLookup =
                    [NSMutableDictionary<NSString *, NSNumber *> dictionary];
                for (std::vector<uintptr_t>::size_type i = 0; i < backtrace.addresses.size(); i++) {
                    const auto instructionAddress
                        = sentry_formatHexAddress(@(backtrace.addresses[i]));

                    const auto frameIndex = frameIndexLookup[instructionAddress];

                    if (frameIndex == nil) {
                        const auto frame = [NSMutableDictionary<NSString *, id> dictionary];
                        frame[@"instruction_addr"] = instructionAddress;
#    if defined(DEBUG)
                        frame[@"function"] = parseBacktraceSymbolsFunctionName(symbols[i]);
#    endif
                        [stack addObject:@(frames.count)];
                        [frames addObject:frame];
                        frameIndexLookup[instructionAddress] = @(stack.count);
                    } else {
                        [stack addObject:frameIndex];
                    }
                }

                const auto sample = [NSMutableDictionary<NSString *, id> dictionary];
                sample[@"relative_timestamp_ns"] =
                    [@(getDurationNs(strongSelf->_startTimestamp, backtrace.absoluteTimestamp))
                        stringValue];
                sample[@"thread_id"] = threadID;
                if (queueAddress != nil) {
                    sample[@"queue_address"] = queueAddress;
                }

                const auto stackIndex = [stacks indexOfObject:stack];
                if (stackIndex != NSNotFound) {
                    sample[@"stack_id"] = @(stackIndex);
                } else {
                    sample[@"stack_id"] = @(stacks.count);
                    [stacks addObject:stack];
                }

                [samples addObject:sample];
            },
            kSentryProfilerFrequencyHz);
        _profiler->startSampling();
    }
}

- (void)addTransaction:(nonnull SentryTransaction *)transaction
{
    NSParameterAssert(transaction);
    if (transaction == nil) {
        SENTRY_LOG_WARN(@"Received nil transaction!");
        return;
    }

    SENTRY_LOG_DEBUG(@"Adding transaction %@ to list of profiled transactions for profiler %@.",
        transaction, self);
    if (_transactions == nil) {
        _transactions = [NSMutableArray<SentryTransaction *> array];
    }
    [_transactions addObject:transaction];
}

- (void)stop
{
    @synchronized(self) {
        if (_profiler == nullptr || !_profiler->isSampling()) {
            return;
        }

        _profiler->stopSampling();
        _endTimestamp = getAbsoluteTime();
        _endDate = [NSDate date];
        SENTRY_LOG_DEBUG(@"Stopped profiler %@ at system time: %llu.", self, _endTimestamp);
    }
}

- (void)captureEnvelope
{
    NSMutableDictionary<NSString *, id> *profile = nil;
    @synchronized(self) {
        profile = [_profile mutableCopy];
    }
    const auto debugImages = [NSMutableArray<NSDictionary<NSString *, id> *> new];
    const auto debugMeta = [_debugImageProvider getDebugImages];
    for (SentryDebugMeta *debugImage in debugMeta) {
        const auto debugImageDict = [NSMutableDictionary<NSString *, id> dictionary];
        debugImageDict[@"type"] = @"macho";
        debugImageDict[@"debug_id"] = debugImage.uuid;
        debugImageDict[@"code_file"] = debugImage.name;
        debugImageDict[@"image_addr"] = debugImage.imageAddress;
        debugImageDict[@"image_size"] = debugImage.imageSize;
        debugImageDict[@"image_vmaddr"] = debugImage.imageVmAddress;
        [debugImages addObject:debugImageDict];
    }
    if (debugImages.count > 0) {
        profile[@"debug_meta"] = @{ @"images" : debugImages };
    }

    profile[@"os"] = @{
        @"name" : sentry_getOSName(),
        @"version" : sentry_getOSVersion(),
        @"build_number" : sentry_getOSBuildNumber()
    };

    const auto isEmulated = sentry_isSimulatorBuild();
    profile[@"device"] = @{
        @"architecture" : sentry_getCPUArchitecture(),
        @"is_emulator" : @(isEmulated),
        @"locale" : NSLocale.currentLocale.localeIdentifier,
        @"manufacturer" : @"Apple",
        @"model" : isEmulated ? sentry_getSimulatorDeviceModel() : sentry_getDeviceModel()
    };

    const auto profileID = [[SentryId alloc] init];
    profile[@"profile_id"] = profileID.sentryIdString;
    const auto profileDuration = getDurationNs(_startTimestamp, _endTimestamp);
    profile[@"duration_ns"] = [@(profileDuration) stringValue];
    profile[@"truncation_reason"] = profilerTruncationReasonName(_truncationReason);

    const auto bundle = NSBundle.mainBundle;
    profile[@"release"] =
        [NSString stringWithFormat:@"%@ (%@)",
                  [bundle objectForInfoDictionaryKey:(NSString *)kCFBundleVersionKey],
                  [bundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"]];

#    if SENTRY_HAS_UIKIT
    auto relativeFrameTimestampsNs = [NSMutableArray array];
    [_frameInfo.frameTimestamps enumerateObjectsUsingBlock:^(
        NSDictionary<NSString *, NSNumber *> *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
        const auto begin = (uint64_t)(obj[@"start_timestamp"].doubleValue * 1e9);
        if (begin < _startTimestamp) {
            return;
        }
        const auto end = (uint64_t)(obj[@"end_timestamp"].doubleValue * 1e9);
        const auto relativeEnd = getDurationNs(_startTimestamp, end);
        if (relativeEnd > profileDuration) {
            SENTRY_LOG_DEBUG(@"The last slow/frozen frame extended past the end of the profile, "
                             @"will not report it.");
            return;
        }
        [relativeFrameTimestampsNs addObject:@{
            @"start_timestamp_relative_ns" : @(getDurationNs(_startTimestamp, begin)),
            @"end_timestamp_relative_ns" : @(relativeEnd),
        }];
    }];
    profile[@"adverse_frame_render_timestamps"] = relativeFrameTimestampsNs;

    relativeFrameTimestampsNs = [NSMutableArray array];
    [_frameInfo.frameRateTimestamps enumerateObjectsUsingBlock:^(
        NSDictionary<NSString *, NSNumber *> *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
        const auto timestamp = (uint64_t)(obj[@"timestamp"].doubleValue * 1e9);
        const auto refreshRate = obj[@"frame_rate"];
        uint64_t relativeTimestamp = 0;
        if (timestamp >= _startTimestamp) {
            relativeTimestamp = getDurationNs(_startTimestamp, timestamp);
        }
        [relativeFrameTimestampsNs addObject:@{
            @"start_timestamp_relative_ns" : @(relativeTimestamp),
            @"frame_rate" : refreshRate,
        }];
    }];
    profile[@"screen_frame_rates"] = relativeFrameTimestampsNs;
#    endif // SENTRY_HAS_UIKIT

    // populate info from all transactions that occurred while profiler was running
    profile[@"platform"] = _transactions.firstObject.platform;
    auto transactionsInfo = [NSMutableArray array];
    for (SentryTransaction *transaction in _transactions) {
        const auto relativeStart =
            [NSString stringWithFormat:@"%llu",
                      [transaction.startTimestamp compare:_startDate] == NSOrderedAscending
                          ? 0
                          : (unsigned long long)(
                              [transaction.startTimestamp timeIntervalSinceDate:_startDate] * 1e9)];
        const auto relativeEnd =
            [NSString stringWithFormat:@"%llu",
                      [transaction.timestamp compare:_endDate] == NSOrderedDescending
                          ? profileDuration
                          : (unsigned long long)(
                              [transaction.timestamp timeIntervalSinceDate:_startDate] * 1e9)];
        [transactionsInfo addObject:@{
            @"environment" : _hub.scope.environmentString ?: _hub.getClient.options.environment ?: kSentryDefaultEnvironment,
            @"id" : transaction.eventId.sentryIdString,
            @"trace_id" : transaction.trace.context.traceId.sentryIdString,
            @"name" : transaction.transaction,
            @"relative_start_ns" : relativeStart,
            @"relative_end_ns" : relativeEnd
        }];
    }
    profile[@"transactions"] = transactionsInfo;

    NSError *error = nil;
    const auto JSONData = [SentrySerialization dataWithJSONObject:profile error:&error];
    if (JSONData == nil) {
        [SentryLog
            logWithMessage:[NSString
                               stringWithFormat:@"Failed to encode profile to JSON: %@", error]
                  andLevel:kSentryLevelError];
        return;
    }

    const auto header = [[SentryEnvelopeItemHeader alloc] initWithType:SentryEnvelopeItemTypeProfile
                                                                length:JSONData.length];
    const auto item = [[SentryEnvelopeItem alloc] initWithHeader:header data:JSONData];
    const auto envelopeHeader = [[SentryEnvelopeHeader alloc] initWithId:profileID];
    const auto envelope = [[SentryEnvelope alloc] initWithHeader:envelopeHeader singleItem:item];
    [_hub captureEnvelope:envelope];
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
