#import "SentryBacktraceTrackerIntegration.h"

#import "SentryAttachment.h"
#import "SentryBacktrace.h"
#import "SentryId.h"
#import "SentrySamplingProfiler.h"
#import "SentryTime.h"
#import "SentryProtoPolyfills.h"
#import "SentryEnvelope.h"
#import "SentryFileManager.h"
#import "SentryOptions.h"
#import "SentryDefaultCurrentDateProvider.h"
#import "SentryProfilingLogging.h"
#import "SentryLog.h"

#if defined(DEBUG)
#include <execinfo.h>
#endif

#import <chrono>
#import <cstdint>
#import <memory>

using namespace sentry::profiling;

@interface SentryBacktraceTrackerIntegration() {
    std::shared_ptr<BacktracePlugin> _plugin;
    SentryProfilingTraceLogger *_logger;
}

@end

@implementation SentryBacktraceTrackerIntegration

- (void)installWithOptions:(SentryOptions *)options {
    _plugin = std::make_shared<BacktracePlugin>();
    _logger = [[SentryProfilingTraceLogger alloc] init];

    _plugin->start(_logger, options);
}

@end

namespace sentry {
namespace profiling {

BacktracePlugin::BacktracePlugin() = default;

void BacktracePlugin::start(SentryProfilingTraceLogger *logger,
                            SentryOptions *options) {
    // TODO(indragie): Handle C++ exception
    NSError *error;
    filemanager_ = [[SentryFileManager alloc] initWithOptions:options andCurrentDateProvider:[SentryDefaultCurrentDateProvider sharedInstance] error:&error];
    profiler_ = std::make_shared<SamplingProfiler>(
      [logger = std::move(logger), this](auto &backtrace) {
          const auto addresses = [NSMutableArray<NSNumber *> array];
          for (const auto address : backtrace.addresses) {
              [addresses addObject:@(address)];
          }
          const auto payload = [NSMutableDictionary dictionaryWithDictionary:@{
            @"addresses": addresses,
            @"priority": @(backtrace.threadMetadata.priority),
          }];
          payload[@"thread_name"] = [NSString stringWithUTF8String:backtrace.threadMetadata.name.c_str()];
          NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:@{
              @"payload": payload,
          }];

#if defined(DEBUG)
//          const auto addressesSize = entry->backtrace->addresses.count;
//          const auto addressPointers = (void**)malloc(sizeof(uintptr_t) * addressesSize);
//          int idx = 0;
//          for (NSValue *value in entry->backtrace->addresses) {
//              addressPointers[idx] = (void *)value.pointerValue;
//          }
//          char **symbols = backtrace_symbols(
//            addressPointers, (int)addressesSize);
//          const auto symbolStrings = [NSMutableArray arrayWithCapacity:addressesSize];
//          for (idx = 0; idx < addressesSize; idx++) {
//              [symbolStrings addObject:[NSString stringWithUTF8String:symbols[idx]]];
//          }
//          free(symbols);
//          free(addressPointers);
//          dict[@"payload"][@"symbols"] = symbolStrings;
#endif
          if (![NSJSONSerialization isValidJSONObject:dict]) {
              [SentryLog logWithMessage:[NSString stringWithFormat:@"Dict (%@) cannot be converted to JSON", dict] andLevel:kSentryLevelError];
              return;
          }

          NSError *serializationError;
          const auto json = [NSJSONSerialization dataWithJSONObject:dict options:0 error:&serializationError];
          if (json == nil) {
              [SentryLog logWithMessage:[NSString stringWithFormat:@"Failed to serialize dict (%@) to JSON: %@", dict, serializationError] andLevel:kSentryLevelError];
              return;
          }

          const auto uuid = [NSUUID UUID];
          const auto attachment = [[SentryAttachment alloc] initWithData:json filename:uuid.UUIDString];
          const auto item = [[SentryEnvelopeItem alloc] initWithAttachment:attachment maxAttachmentSize:NSUIntegerMax];
          const auto items = @[item];
          const auto envelope = [[SentryEnvelope alloc] initWithId:[[SentryId alloc] initWithUUID:uuid] items:items];
          [filemanager_ storeEnvelope:envelope];
      },
      options.profilerSampleRateHz);
    profiler_->startSampling();
}

void BacktracePlugin::end() {
    stopCollecting();
}

void BacktracePlugin::abort() {
    stopCollecting();
}

void BacktracePlugin::stopCollecting() {
    // TODO(indragie): Handle C++ exception
    profiler_->stopSampling();
    profiler_ = nullptr;
}

bool BacktracePlugin::shouldEnable(
                                   SentryOptions *options) const {
// Disable backtrace collection when running with TSAN because it produces a TSAN false
// positive, similar to the situation described here:
// https://github.com/envoyproxy/envoy/issues/2561
#if defined(__has_feature)
#if __has_feature(thread_sanitizer)
    return false;
#endif
#endif
    return options.profilerEnabled;
}

} // namespace profiling
} // namespace sentry
