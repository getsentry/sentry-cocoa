#import "SentryProfiler.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryBacktrace.hpp"
#    import "SentryClient+Private.h"
#    import "SentryDebugImageProvider.h"
#    import "SentryDebugMeta.h"
#    import "SentryDefines.h"
#    import "SentryDependencyContainer.h"
#    import "SentryEnvelope.h"
#    import "SentryEnvelopeItemType.h"
#    import "SentryFramesTracker.h"
#    import "SentryHexAddressFormatter.h"
#    import "SentryHub.h"
#    import "SentryId.h"
#    import "SentryLog.h"
#    import "SentryProfilingLogging.hpp"
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
#    import <memory>
#    import <sys/sysctl.h>
#    import <sys/utsname.h>

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

NSString *profilerStopReasonName(SentryProfilerStopReason reason) {
    switch (reason) {
        case SentryProfilerStopReasonNormal: return @"normal";
        case SentryProfilerStopReasonAppMovedToBackground: return @"backgrounded";
        case SentryProfilerStopReasonTimeout: return @"timeout";
    }
}

namespace {
NSString *
getDeviceModel()
{
    utsname info;
    if (SENTRY_PROF_LOG_ERRNO(uname(&info)) == 0) {
        return [NSString stringWithUTF8String:info.machine];
    }
    return @"";
}

NSString *
getOSBuildNumber()
{
    char str[32];
    size_t size = sizeof(str);
    int cmd[2] = { CTL_KERN, KERN_OSVERSION };
    if (SENTRY_PROF_LOG_ERRNO(sysctl(cmd, sizeof(cmd) / sizeof(*cmd), str, &size, NULL, 0)) == 0) {
        return [NSString stringWithUTF8String:str];
    }
    return @"";
}

bool
isSimulatorBuild()
{
#    if TARGET_OS_SIMULATOR
    return true;
#    else
    return false;
#    endif
}
} // namespace

@implementation SentryProfiler {
    NSMutableDictionary<NSString *, id> *_profile;
    uint64_t _startTimestamp;
    uint64_t _endTimestamp;
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
        const auto samples = [NSMutableArray<NSDictionary<NSString *, id> *> array];
        const auto threadMetadata =
            [NSMutableDictionary<NSString *, NSMutableDictionary *> dictionary];
        const auto queueMetadata = [NSMutableDictionary<NSString *, NSDictionary *> dictionary];
        sampledProfile[@"samples"] = samples;
        sampledProfile[@"thread_metadata"] = threadMetadata;
        sampledProfile[@"queue_metadata"] = queueMetadata;
        _profile[@"sampled_profile"] = sampledProfile;
        _startTimestamp = getAbsoluteTime();

        [SentryLog logWithMessage:[NSString stringWithFormat:@"Starting profiler at system time %llu.", _startTimestamp] andLevel:kSentryLevelDebug];

        __weak const auto weakSelf = self;
        _profiler = std::make_shared<SamplingProfiler>(
            [weakSelf, threadMetadata, queueMetadata, samples, mainThreadID = _mainThreadID](
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
                const auto frames = [NSMutableArray<NSDictionary<NSString *, id> *> new];
                for (std::vector<uintptr_t>::size_type i = 0; i < backtrace.addresses.size(); i++) {
                    const auto frame = [NSMutableDictionary<NSString *, id> dictionary];
                    frame[@"instruction_addr"] = sentry_formatHexAddress(@(backtrace.addresses[i]));
#    if defined(DEBUG)
                    frame[@"function"] = parseBacktraceSymbolsFunctionName(symbols[i]);
#    endif
                    [frames addObject:frame];
                }

                const auto sample = [NSMutableDictionary<NSString *, id> dictionary];
                sample[@"frames"] = frames;
                sample[@"relative_timestamp_ns"] =
                    [@(getDurationNs(strongSelf->_startTimestamp, backtrace.absoluteTimestamp))
                        stringValue];
                sample[@"thread_id"] = threadID;
                if (queueAddress != nil) {
                    sample[@"queue_address"] = queueAddress;
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
            _endTimestamp = getAbsoluteTime();
            [SentryLog logWithMessage:[NSString stringWithFormat:@"Stopped profiler at system time: %llu.", _endTimestamp] andLevel:kSentryLevelDebug];
        }
    }
}

- (SentryEnvelope *)buildEnvelopeItemForTransactions:(NSArray<SentryTransaction *> *)transactions
                                                 hub:(SentryHub *)hub
                                           frameInfo:(SentryScreenFrames *)frameInfo
stopReason:(SentryProfilerStopReason)stopReason
{
    NSParameterAssert(transactions.count > 0);
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

    profile[@"device_locale"] = NSLocale.currentLocale.localeIdentifier;
    profile[@"device_manufacturer"] = @"Apple";
    const auto model = getDeviceModel();
    profile[@"device_model"] = model;
    profile[@"device_os_build_number"] = getOSBuildNumber();
#    if TARGET_OS_IOS
    profile[@"device_os_name"] = UIDevice.currentDevice.systemName;
    profile[@"device_os_version"] = UIDevice.currentDevice.systemVersion;
#    endif
    profile[@"device_is_emulator"] = @(isSimulatorBuild());
    profile[@"device_physical_memory_bytes"] =
        [@(NSProcessInfo.processInfo.physicalMemory) stringValue];
    const auto profileID = [[SentryId alloc] init];
    profile[@"profile_id"] = profileID.sentryIdString;
    const auto profileEnd = getAbsoluteTime();
    const auto profileDuration = getDurationNs(_startTimestamp, profileEnd);
    profile[@"duration_ns"] = [@(profileDuration) stringValue];
    profile[@"truncation_reason"] = profilerStopReasonName(stopReason);

    const auto bundle = NSBundle.mainBundle;
    profile[@"version_code"] = [bundle objectForInfoDictionaryKey:(NSString *)kCFBundleVersionKey];
    profile[@"version_name"] = [bundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];

#    if SENTRY_HAS_UIKIT
    auto relativeFrameTimestampsNs = [NSMutableArray array];
    [frameInfo.frameTimestamps enumerateObjectsUsingBlock:^(
        NSDictionary<NSString *, NSNumber *> *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
        const auto begin = (uint64_t)(obj[@"start_timestamp"].doubleValue * 1e9);
        if (begin < _startTimestamp) {
            return;
        }
        const auto end = (uint64_t)(obj[@"end_timestamp"].doubleValue * 1e9);
        const auto relativeEnd = getDurationNs(_startTimestamp, end);
        if (relativeEnd > profileDuration) {
            return;
        }
        [relativeFrameTimestampsNs addObject:@{
            @"start_timestamp_relative_ns" : @(getDurationNs(_startTimestamp, begin)),
            @"end_timestamp_relative_ns" : @(relativeEnd),
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

    // populate info from all transactions that occurred while profiler was running
    profile[@"platform"] = transactions.firstObject.platform;
    auto transactionsInfo = [NSMutableArray array];
    for (SentryTransaction *transaction in transactions) {
        [transactionsInfo addObject:@{
            @"environment" : hub.scope.environmentString ?: hub.getClient.options.environment ?: kSentryDefaultEnvironment,
            @"id" : transaction.eventId.sentryIdString,
            @"trace_id" : transaction.trace.context.traceId.sentryIdString,
            @"name" : transaction.transaction,
            @"relative_start_ns" : [@(transaction.systemStartTime <= _startTimestamp ? 0 : getDurationNs(_startTimestamp, transaction.systemStartTime)) stringValue],
            @"relative_end_ns" : [@(transaction.systemEndTime < _startTimestamp + profileDuration ? profileDuration : getDurationNs(_startTimestamp, transaction.systemEndTime)) stringValue]
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
        return nil;
    }

    const auto header = [[SentryEnvelopeItemHeader alloc] initWithType:SentryEnvelopeItemTypeProfile
                                                                length:JSONData.length];
    const auto item = [[SentryEnvelopeItem alloc] initWithHeader:header data:JSONData];

    const auto envelopeHeader = [[SentryEnvelopeHeader alloc] initWithId:profileID];
    return [[SentryEnvelope alloc] initWithHeader:envelopeHeader singleItem:item];
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
