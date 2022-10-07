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
#    import "SentryHub.h"
#    import "SentryId.h"
#    import "SentryLog.h"
#    import "SentrySamplingProfiler.hpp"
#    import "SentryScope+Private.h"
#    import "SentryScreenFrames.h"
#    import "SentrySerialization.h"
#    import "SentryTime.h"
#    import "SentryTransaction.h"
#    import "SentryTransactionContext.h"

#    if defined(DEBUG)
#        include <execinfo.h>
#    endif

#    import <cstdint>
#    import <mach-o/arch.h>
#    include <mach/machine.h>
#    import <memory>

#    if TARGET_OS_IOS
#        import <UIKit/UIKit.h>
#    endif

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

@implementation SentryProfiler {
    NSMutableDictionary<NSString *, id> *_profile;
    uint64_t _startTimestamp;
    std::shared_ptr<SamplingProfiler> _profiler;
    SentryDebugImageProvider *_debugImageProvider;
    thread::TIDType _mainThreadID;
}

- (instancetype)init
{
    if (![NSThread isMainThread]) {
        SENTRY_LOG_ERROR(@"SentryProfiler must be initialized on the main thread");
        return nil;
    }
    if (self = [super init]) {
        _debugImageProvider = [SentryDependencyContainer sharedInstance].debugImageProvider;
        _mainThreadID = ThreadHandle::current()->tid();
    }
    return self;
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
         * Maintain an index of unique frames to avoid duplicating large amounts of data. Every unique frame is stored in an array, and every time a stack trace is captured for a sample, the stack is stored as an array of integers indexing into the array of frames. Stacks are thusly also stored as unique elements in their own index, an array of arrays of frame indices, and each sample references a stack by index, to deduplicate common stacks between samples, such as when the same deep function call runs across multiple samples.
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

        __weak const auto weakSelf = self;
        _profiler = std::make_shared<SamplingProfiler>(
                                                       [weakSelf, threadMetadata, queueMetadata, samples, mainThreadID = _mainThreadID, frames, stacks](
                auto &backtrace) {
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
                for (std::vector<uintptr_t>::size_type i = 0; i < backtrace.addresses.size(); i++) {
                    const auto instructionAddress = sentry_formatHexAddress(@(backtrace.addresses[i]));
                    const auto frameIndex = [frames indexOfObjectPassingTest:^BOOL(NSDictionary<NSString *,id> * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                        return [obj[@"instruction_addr"] isEqualToString:instructionAddress];
                    }];
                    if (frameIndex == NSNotFound) {
                        const auto frame = [NSMutableDictionary<NSString *, id> dictionary];
                        frame[@"instruction_addr"] = instructionAddress;
    #    if defined(DEBUG)
                        frame[@"function"] = parseBacktraceSymbolsFunctionName(symbols[i]);
    #    endif
                        [stack addObject:@(frames.count)];
                        [frames addObject:frame];
                    } else {
                        [stack addObject:@(frameIndex)];
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
            101 /** Sample 101 times per second */);
        _profiler->startSampling();
    }
}

- (void)stop
{
    @synchronized(self) {
        if (_profiler != nullptr) {
            _profiler->stopSampling();
        }
    }
}

- (SentryEnvelopeItem *)buildEnvelopeItemForTransaction:(SentryTransaction *)transaction
                                                    hub:(SentryHub *)hub
                                              frameInfo:(SentryScreenFrames *)frameInfo
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
        @"name" : getOSName(),
        @"version" : getOSVersion(),
        @"build_number" : getOSBuildNumber()
    };

    const auto isEmulated = sentry_isSimulatorBuild();
    profile[@"device"] = @{
        @"architecture" : sentry_getCPUArchitecture(),
        @"is_emulator" : @(isEmulated),
        @"locale" : NSLocale.currentLocale.localeIdentifier,
        @"manufacturer" : @"Apple",
        @"model" : isEmulated ? sentry_getSimulatorDeviceModel() : sentry_getDeviceModel(),
		@"os_name" : sentry_getOSName(),
        @"physical_memory_bytes" : [@(NSProcessInfo.processInfo.physicalMemory) stringValue]
    };

    profile[@"environment"] = hub.scope.environmentString ?: hub.getClient.options.environment ?: kSentryDefaultEnvironment;
    profile[@"platform"] = transaction.platform;
    profile[@"transaction_id"] = transaction.eventId.sentryIdString;
    profile[@"trace_id"] = transaction.trace.context.traceId.sentryIdString;
    profile[@"profile_id"] = [[SentryId alloc] init].sentryIdString;
    profile[@"transaction_name"] = transaction.transaction;
    profile[@"duration_ns"] = [@(getDurationNs(_startTimestamp, getAbsoluteTime())) stringValue];

    const auto bundle = NSBundle.mainBundle;
    profile[@"release"] =
        [NSString stringWithFormat:@"%@ (%@)",
                  [bundle objectForInfoDictionaryKey:(NSString *)kCFBundleVersionKey],
                  [bundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"]];

#    if SENTRY_HAS_UIKIT
    auto relativeFrameTimestampsNs = [NSMutableArray array];
    [frameInfo.frameTimestamps enumerateObjectsUsingBlock:^(
        NSDictionary<NSString *, NSNumber *> *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
        const auto begin = (uint64_t)(obj[@"start_timestamp"].doubleValue * 1e9);
        if (begin < _startTimestamp) {
            return;
        }
        const auto end = (uint64_t)(obj[@"end_timestamp"].doubleValue * 1e9);
        [relativeFrameTimestampsNs addObject:@{
            @"start_timestamp_relative_ns" : @(getDurationNs(_startTimestamp, begin)),
            @"end_timestamp_relative_ns" : @(getDurationNs(_startTimestamp, end)),
        }];
    }];
    profile[@"adverse_frame_render_timestamps"] = relativeFrameTimestampsNs;

    relativeFrameTimestampsNs = [NSMutableArray array];
    [frameInfo.frameRateTimestamps enumerateObjectsUsingBlock:^(
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

    NSError *error = nil;
    const auto JSONData = [SentrySerialization dataWithJSONObject:profile error:&error];
    if (JSONData == nil) {
        [SentryLog
            logWithMessage:[NSString
                               stringWithFormat:@"Failed to encode profile to JSON: %@", error]
                  andLevel:kSentryLevelError];
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
