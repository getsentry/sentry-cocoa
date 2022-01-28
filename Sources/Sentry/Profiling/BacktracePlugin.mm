// Copyright (c) Specto Inc. All rights reserved.

#import "BacktracePlugin.h"

#import "SentryAttachment.h"
#import "SentryId.h"
#import "SamplingProfiler.h"
#import "Exception.h"
#import "SpectoTime.h"
#import "SpectoProtoPolyfills.h"
#import "SentryEnvelope.h"
#import "SentryFileManager.h"
#import "SentryOptions.h"
#import "SentryDefaultCurrentDateProvider.h"
#import "Log.h"

#if !defined(NDEBUG) && defined(__APPLE__)
#include <execinfo.h>
#endif

#import <chrono>
#import <cstdint>
#import <memory>

@interface SentryBacktraceTrackerIntegration() {
    std::shared_ptr<specto::darwin::BacktracePlugin> _plugin;
    SentryProfilingTraceLogger *_logger;
}

@end

@implementation SentryBacktraceTrackerIntegration

- (void)installWithOptions:(SentryOptions *)options {
    _plugin = std::make_shared<specto::darwin::BacktracePlugin>();
    _logger = [[SentryProfilingTraceLogger alloc] init];

    _plugin->start(_logger, options);
}

@end

namespace specto {
namespace darwin {

BacktracePlugin::BacktracePlugin() = default;

void BacktracePlugin::start(SentryProfilingTraceLogger *logger,
                            SentryOptions *options) {
    SPECTO_HANDLE_CPP_EXCEPTION({
        NSError *error;
        filemanager_ = [[SentryFileManager alloc] initWithOptions:options andCurrentDateProvider:[SentryDefaultCurrentDateProvider sharedInstance] error:&error];
        profiler_ = std::make_shared<SamplingProfiler>(
          [logger = std::move(logger), this](auto entry) {
              // Perform the same timestamp transformation that TraceLogger::log() does
              const auto timeSinceReference = time::getDurationNs(
                logger->referenceUptimeNs, entry->elapsedRelativeToStartDateNs);
              entry->elapsedRelativeToStartDateNs = timeSinceReference.count();

              const auto payload = [NSMutableDictionary dictionaryWithDictionary:@{
                @"addresses": entry->backtrace->addresses,
                @"priority": @(entry->backtrace->priority),
              }];

              if (entry->backtrace->threadName != nil) {
                  payload[@"thread_name"] = entry->backtrace->threadName;
              }

              if (entry->backtrace->queueName != nil) {
                  payload[@"queue_name"] = entry->backtrace->queueName;
              }

              NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:@{
                  // TODO: create a dict of the values in the entry
                  @"elapsed_relative_to_start_date_ns": @(entry->elapsedRelativeToStartDateNs),
                  @"tid": @(entry->tid),
                  @"type": @4, // legacy, this corresponds to //spectoproto/entry/entry.proto, field "type", enum value "BACKTRACE"
                  @"group_id": @0,
                  @"cost_ns": @(entry->costNs),
                  @"payload": payload,
              }];

#if defined(DEBUG) && defined(__APPLE__)
              const auto addressesSize = entry->backtrace->addresses.count;
              const auto addressPointers = (void**)malloc(sizeof(uintptr_t) * addressesSize);
              int idx = 0;
              for (NSValue *value in entry->backtrace->addresses) {
                  addressPointers[idx] = (void *)value.pointerValue;
              }
              char **symbols = backtrace_symbols(
                addressPointers, (int)addressesSize);
              const auto symbolStrings = [NSMutableArray arrayWithCapacity:addressesSize];
              for (idx = 0; idx < addressesSize; idx++) {
                  [symbolStrings addObject:[NSString stringWithUTF8String:symbols[idx]]];
              }
              free(symbols);
              free(addressPointers);
              dict[@"payload"][@"symbols"] = symbolStrings;
#endif

              if (!SPECTO_ASSERT([NSJSONSerialization isValidJSONObject:dict], @"Encountered a dict that can't be converted to JSON: %@", dict)) {
                  return;
              }

              NSError *serializationError;
              const auto json = [NSJSONSerialization dataWithJSONObject:dict options:0 error:&serializationError];
              if (!SPECTO_ASSERT_NULL(serializationError, @"Encountered an error serializing dictionary (%@): %@", dict, serializationError)) {
                  return;
              }
              if (!SPECTO_ASSERT_NOT_NULL(json, @"Successfully serialized dictionary but got nil data back. (Input dict: %@)", dict)) {
                  return;
              }

              const auto uuid = [NSUUID UUID];
              const auto attachment = [[SentryAttachment alloc] initWithData:json filename:uuid.UUIDString];
              const auto item = [[SentryEnvelopeItem alloc] initWithAttachment:attachment maxAttachmentSize:NSUIntegerMax];
              const auto items = @[item];
              const auto envelope = [[SentryEnvelope alloc] initWithId:[[SentryId alloc] initWithUUID:uuid] items:items];
              [filemanager_ storeEnvelope:envelope];
          },
          options.profilerSampleRateHz,
          options.measureProfilerCost);
        profiler_->startSampling();
    });
}

void BacktracePlugin::end() {
    stopCollecting();
}

void BacktracePlugin::abort() {
    stopCollecting();
}

void BacktracePlugin::stopCollecting() {
    SPECTO_HANDLE_CPP_EXCEPTION({
        profiler_->stopSampling();
        profiler_ = nullptr;
    });
}

bool BacktracePlugin::shouldEnable(
                                   SentryOptions *options) const {
// Disable backtrace collection when running with TSAN because it produces a TSAN false
// positive, similar to the situation described here:
// https://github.com/envoyproxy/envoy/issues/2561
#if defined(__has_feature)
#if __has_feature(thread_sanitizer)
    SPECTO_LOG_INFO("Disabling backtrace collection because TSAN is enabled.");
    return false;
#endif
#endif
    return options.profilerEnabled;
}

} // namespace darwin
} // namespace specto
