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

namespace {
/**
 * @brief Get the hardware description of the device.
 * @discussion The values returned are different between iOS and macOS. Some examples of values returned on different devices:
 * @code
 * | device                        | machine    | model          |
 * ---------------------------------------------------------------
 * | m1 mbp                        | arm64      | MacBookPro18,3 |
 * | iphone 13 mini                | iPhone14,4 | D16AP          |
 * | intel imac                    | x86_64     | iMac20,1       |
 * | iphone simulator on m1 mac    | arm64      | MacBookPro18,3 |
 * | iphone simulator on intel mac | x86_64     | iMac20,1       |
 * @endcode
 * @seealso See https://www.cocoawithlove.com/blog/2016/03/08/swift-wrapper-for-sysctl.html#looking-for-the-source for more info.
 * @return @c sysctl value for the combination of @c CTL_HW and the provided other flag in the @c type parameter.
 */
NSString *
getHardwareDescription(int type)
{
    int mib[2];
    char name[128];
    size_t len;

    mib[0] = CTL_HW;
    mib[1] = type;
    len = sizeof(name);
    if (sysctl(mib, 2, &name, &len, NULL, 0) != 0) {
        return @"";
    }
    return [NSString stringWithUTF8String:name];
}

NSString *
getCPUArchitecture()
{
#if SENTRY_HAS_UIKIT
    size_t size;
    cpu_type_t type;
    cpu_subtype_t subtype;
    size = sizeof(type);
    const auto nameStr = [NSMutableString string];
    if (sysctlbyname("hw.cputype", &type, &size, NULL, 0) == 0) {
        switch (type) {
        case CPU_TYPE_I386:
            [nameStr appendString:@"i386"];
            break;
        case CPU_TYPE_X86_64:
            [nameStr appendString:@"x86_64"];
            break;
        case CPU_TYPE_ARM:
            [nameStr appendString:@"arm"];
            break;
        case CPU_TYPE_ARM64:
            [nameStr appendString:@"arm64"];
            break;
        case CPU_TYPE_ARM64_32:
            [nameStr appendString:@"arm64_32"];
            break;
        default:
            [nameStr appendFormat:@"unknown type (%d)", type];
            break;
        }
    }

    size = sizeof(subtype);
    if (sysctlbyname("hw.cpusubtype", &subtype, &size, NULL, 0) == 0) {
        switch (subtype) {
        case CPU_SUBTYPE_ARM_V6:
            [nameStr appendString:@"v6"];
            break;
        case CPU_SUBTYPE_ARM_V7:
            [nameStr appendString:@"v7"];
            break;
        case CPU_SUBTYPE_ARM_V7S:
            [nameStr appendString:@"v7s"];
            break;
        case CPU_SUBTYPE_ARM_V7K:
            [nameStr appendString:@"v7k"];
            break;
        case CPU_SUBTYPE_ARM64_V8:
            // this also catches CPU_SUBTYPE_ARM64_32_V8 since they are both defined as
            // ((cpu_subtype_t) 1)
            [nameStr appendString:@"v8"];
            break;
        case CPU_SUBTYPE_ARM64E:
            [nameStr appendString:@"e"];
            break;
        }
    }

    return nameStr;
#else
    return getHardwareDescription(HW_MACHINE);
#endif // SENTRY_HAS_UIKIT
}

NSString *
getOSName()
{
#    if SENTRY_HAS_UIKIT
    return UIDevice.currentDevice.systemName;
#    else
    return @"macOS";
#    endif // SENTRY_HAS_UIKIT
}

NSString *
getOSVersion()
{
#    if SENTRY_HAS_UIKIT
    return UIDevice.currentDevice.systemVersion;
#    else
    // based off of
    // https://github.com/lmirosevic/GBDeviceInfo/blob/98dd3c75bb0e1f87f3e0fd909e52dcf0da4aa47d/GBDeviceInfo/GBDeviceInfo_OSX.m#L107-L133
    if ([[NSProcessInfo processInfo] respondsToSelector:@selector(operatingSystemVersion)]) {
        const auto version = [[NSProcessInfo processInfo] operatingSystemVersion];
        return [NSString stringWithFormat:@"%ld.%ld.%ld", (long)version.majorVersion,
                         (long)version.minorVersion, (long)version.patchVersion];
    } else {
        SInt32 major, minor, patch;

#        pragma clang diagnostic push
#        pragma clang diagnostic ignored "-Wdeprecated-declarations"
        Gestalt(gestaltSystemVersionMajor, &major);
        Gestalt(gestaltSystemVersionMinor, &minor);
        Gestalt(gestaltSystemVersionBugFix, &patch);
#        pragma clang diagnostic pop

        return [NSString stringWithFormat:@"%d.%d.%d", major, minor, patch];
    }
#    endif // SENTRY_HAS_UIKIT
}

NSString *
getDeviceModel()
{
#if SENTRY_HAS_UIKIT
#if TARGET_OS_SIMULATOR
    return getHardwareDescription(HW_MODEL);
#else
    return getHardwareDescription(HW_MACHINE);
#endif // TARGET_OS_SIMULATOR
#else
    return getHardwareDescription(HW_MODEL);
#endif // SENTRY_HAS_UIKIT
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
    profile[@"environment"] = hub.scope.environmentString ?: hub.getClient.options.environment ?: kSentryDefaultEnvironment;
    profile[@"platform"] = transaction.platform;
    profile[@"transaction_id"] = transaction.eventId.sentryIdString;
    profile[@"trace_id"] = transaction.trace.context.traceId.sentryIdString;
    profile[@"profile_id"] = [[SentryId alloc] init].sentryIdString;
    profile[@"transaction_name"] = transaction.transaction;
    profile[@"duration_ns"] = [@(getDurationNs(_startTimestamp, getAbsoluteTime())) stringValue];

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
