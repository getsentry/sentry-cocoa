#import "SentryProfiler.h"

#import "SentryBacktrace.h"
#import "SentrySamplingProfiler.h"
#import "SentryHexAddressFormatter.h"

#if defined(DEBUG)
#include <execinfo.h>
#endif

#import <chrono>
#import <cstdint>
#import <ctime>
#import <memory>

using namespace sentry::profiling;

@implementation SentryProfiler {
    NSMutableDictionary<NSString *, id> *_profile;
    uint64_t _referenceUptimeNs;
    std::shared_ptr<SamplingProfiler> _profiler;
}

- (instancetype)init {
    if (self = [super init]) {
        __weak const auto weakSelf = self;
        _profiler = std::make_shared<SamplingProfiler>([weakSelf](auto &backtrace) {
            const auto strongSelf = weakSelf;
            if (strongSelf == nil) {
                return;
            }
            assert(backtrace.uptimeNs >= strongSelf->_referenceUptimeNs);
            const auto tid = [@(backtrace.threadMetadata.threadID) stringValue];
            NSMutableDictionary<NSString *, id> *const sampledProfile = strongSelf->_profile[@"sampled_profile"];
            NSMutableDictionary<NSString *, NSDictionary *> *const threadMetadata = sampledProfile[@"thread_metadata"];
            if (threadMetadata[tid] == nil) {
                const auto metadata = [NSMutableDictionary<NSString *, id> dictionary];
                if (!backtrace.threadMetadata.name.empty()) {
                    metadata[@"name"] = [NSString stringWithUTF8String:backtrace.threadMetadata.name.c_str()];
                }
                metadata[@"priority"] = @(backtrace.threadMetadata.priority);
                threadMetadata[tid] = metadata;
            }
#if defined(DEBUG)
            const auto symbols = backtrace_symbols(
                          reinterpret_cast<void *const *>(backtrace.addresses.data()), static_cast<int>(backtrace.addresses.size()));
#endif
            const auto frames = [NSMutableArray<NSDictionary<NSString *, id> *> new];
            for (std::vector<uintptr_t>::size_type i = 0; i < backtrace.addresses.size(); i++) {
                const auto frame = [NSMutableDictionary<NSString *, id> dictionary];
                frame[@"instruction_addr"] = sentry_formatHexAddress(@(backtrace.addresses[i]));
#if defined(DEBUG)
                frame[@"function"] = [NSString stringWithUTF8String:symbols[i]];
#endif
                [frames addObject:frame];
            }

            const auto sample = [NSMutableDictionary<NSString *, id> dictionary];
            sample[@"frames"] = frames;
            sample[@"relative_timestamp_ns"] = @(backtrace.uptimeNs - strongSelf->_referenceUptimeNs);
            
            NSMutableArray<NSDictionary<NSString *, id> *> *const samples = sampledProfile[@"samples"];
            [samples addObject:sample];
        }, 100 /** Sample 100 times per second */);
    }
    return self;
}

- (void)start {
    // Disable profiling when running with TSAN because it produces a TSAN false
    // positive, similar to the situation described here:
    // https://github.com/envoyproxy/envoy/issues/2561
    #if defined(__has_feature)
    #if __has_feature(thread_sanitizer)
    return;
    #endif
    #endif
    @synchronized(self) {
        _profile = [NSMutableDictionary<NSString *, id> dictionary];
        const auto sampledProfile = [NSMutableDictionary<NSString *, id> dictionary];
        sampledProfile[@"samples"] = [NSMutableArray<NSDictionary<NSString *, id> *> array];
        sampledProfile[@"thread_metadata"] = [NSMutableDictionary<NSString *, NSDictionary *> dictionary];
        _profile[@"sampled_profile"] = sampledProfile;
        _referenceUptimeNs = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
        _profiler->startSampling();
    }
}

- (void)stop {
    @synchronized(self) {
        _profiler->stopSampling();
    }
}

- (NSDictionary *)profile {
    return [_profile copy];
}

@end
