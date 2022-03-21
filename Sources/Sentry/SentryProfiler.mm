#import "SentryProfiler.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryBacktrace.hpp"
#    import "SentryDebugImageProvider.h"
#    import "SentryDebugMeta.h"
#    import "SentryDefines.h"
#    import "SentryEnvelope.h"
#    import "SentryHexAddressFormatter.h"
#    import "SentryId.h"
#    import "SentryLog.h"
#    import "SentryProfilingLogging.hpp"
#    import "SentrySamplingProfiler.hpp"
#    import "SentrySerialization.h"
#    import "SentryTime.h"
#    import "SentryTransaction.h"

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
    std::shared_ptr<SamplingProfiler> _profiler;
    SentryDebugImageProvider *_debugImageProvider;
}

- (instancetype)init
{
    if (self = [super init]) {
        _debugImageProvider = [[SentryDebugImageProvider alloc] init];
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
    [SentryLog logWithMessage:@"Disabling profiling when running with TSAN"
                     andLevel:kSentryLevelDebug];
    return;
#        endif
#    endif
    @synchronized(self) {
        if (_profiler != nullptr) {
            _profiler->stopSampling();
        }
        _profile = [NSMutableDictionary<NSString *, id> dictionary];
        const auto sampledProfile = [NSMutableDictionary<NSString *, id> dictionary];
        const auto samples = [NSMutableArray<NSDictionary<NSString *, id> *> array];
        const auto threadMetadata = [NSMutableDictionary<NSString *, NSDictionary *> dictionary];
        sampledProfile[@"samples"] = samples;
        sampledProfile[@"thread_metadata"] = threadMetadata;
        _profile[@"sampled_profile"] = sampledProfile;
        _startTimestamp = getAbsoluteTime();

        __weak const auto weakSelf = self;
        _profiler = std::make_shared<SamplingProfiler>(
            [weakSelf, sampledProfile, threadMetadata, samples](auto &backtrace) {
                const auto strongSelf = weakSelf;
                if (strongSelf == nil) {
                    return;
                }
                const auto threadID = [@(backtrace.threadMetadata.threadID) stringValue];
                if (threadMetadata[threadID] == nil) {
                    const auto metadata = [NSMutableDictionary<NSString *, id> dictionary];
                    if (!backtrace.threadMetadata.name.empty()) {
                        metadata[@"name"] =
                            [NSString stringWithUTF8String:backtrace.threadMetadata.name.c_str()];
                    }
                    metadata[@"priority"] = @(backtrace.threadMetadata.priority);
                    threadMetadata[threadID] = metadata;
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
                    frame[@"function"] = [NSString stringWithUTF8String:symbols[i]];
#    endif
                    [frames addObject:frame];
                }

                const auto sample = [NSMutableDictionary<NSString *, id> dictionary];
                sample[@"frames"] = frames;
                sample[@"relative_timestamp_ns"] =
                    [@(getDurationNs(strongSelf->_startTimestamp, backtrace.absoluteTimestamp))
                        stringValue];
                sample[@"thread_id"] = threadID;
                [samples addObject:sample];
            },
            100 /** Sample 100 times per second */);
        _profiler->startSampling();
    }
}

- (void)stop
{
    @synchronized(self) {
        _profiler->stopSampling();
    }
}

- (SentryEnvelopeItem *)buildEnvelopeItemForTransaction:(SentryTransaction *)transaction
{
    NSMutableDictionary<NSString *, id> *profile = nil;
    @synchronized(self) {
        profile = [_profile mutableCopy];
    }
    const auto debugImages = [NSMutableArray<NSDictionary<NSString *, id> *> new];
    const auto debugMeta = [_debugImageProvider getDebugImages];
    for (SentryDebugMeta *debugImage in debugMeta) {
        [debugImages addObject:[debugImage serialize]];
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
    profile[@"environment"] = transaction.environment;
    profile[@"platform"] = transaction.platform;
    profile[@"transaction_id"] = transaction.eventId.sentryIdString;
    profile[@"trace_id"] = transaction.trace.context.traceId.sentryIdString;
    profile[@"profile_id"] = [[SentryId alloc] init].sentryIdString;
    profile[@"transaction_name"] = transaction.transaction;
    profile[@"duration_ns"] = [@(getDurationNs(_startTimestamp, getAbsoluteTime())) stringValue];

    const auto bundle = NSBundle.mainBundle;
    profile[@"version_code"] = [bundle objectForInfoDictionaryKey:(NSString *)kCFBundleVersionKey];
    profile[@"version_name"] = [bundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];

    NSError *error = nil;
    const auto JSONData = [SentrySerialization dataWithJSONObject:profile error:&error];
    if (JSONData == nil) {
        [SentryLog
            logWithMessage:[NSString
                               stringWithFormat:@"Failed to encode profile to JSON: %@", error]
                  andLevel:kSentryLevelError];
        return nil;
    }

    const auto header = [[SentryEnvelopeItemHeader alloc] initWithType:@"profile"
                                                                length:JSONData.length];
    return [[SentryEnvelopeItem alloc] initWithHeader:header data:JSONData];
}

@end

#endif
