// Copyright (c) Specto Inc. All rights reserved.

#include "TraceController.h"

#include "RingBufferPacketReader.h"
#include "RingBufferPacketWriter.h"
#include "TraceBufferConsumer.h"
#include "TraceConsumer.h"
#include "TraceEventSubject.h"
#include "GlobalConfiguration.h"
#include "Exception.h"
#include "Log.h"
#include "Protobuf.h"
#include "RingBuffer.h"
#include "EntryParser.h"
#include "Packet.h"
#include "PacketStreamID.h"
#include "TraceLogger.h"
//#include "spectoproto./entry/entry_generated.pb.h"
//#include "spectoproto./error/error_generated.pb.h"
//#include "spectoproto./trace/configuration_generated.pb.h"

#include <atomic>
#include <cassert>
#include <tuple>
#include <utility>

using namespace specto::internal;

namespace specto {

/**
 * Default number of slots to allocate in the ring buffer.
 * Android needs a big buffer because of ANDROID_TRACE entries.
 */
#ifdef __ANDROID__
constexpr std::size_t kDefaultSlotCount = 39000; // About 5MB
#else
constexpr std::size_t kDefaultSlotCount = 1000;
#endif

namespace internal {
struct SpanContext {
    TraceID id;
    std::string name;
};

struct TraceContext {
    TraceID id;
    std::string interactionName;
    proto::TraceMetadata traceMetadata;
    std::vector<std::shared_ptr<Plugin>> plugins;
    std::vector<std::pair<std::shared_ptr<Plugin>, std::shared_ptr<TraceLogger>>>
      pluginTraceLoggers;
    std::shared_ptr<TraceLogger> traceStateLogger;
    std::shared_ptr<TraceConsumer> consumer;
    std::vector<SpanContext> traceSpans;
    std::atomic<std::uint64_t> annotationID;
};
} // namespace internal

TraceController::TraceController(PluginRegistry pluginRegistry,
                                 std::shared_ptr<TraceBufferConsumer> bufferConsumer,
                                 std::shared_ptr<proto::AppInfo> appInfo) :
    ringBuffer_(
      std::make_shared<RingBuffer<Packet>>(static_cast<unsigned>(pluginRegistry.size()) + 1,
                                           kDefaultSlotCount)),
    packetReader_(std::make_shared<RingBufferPacketReader>(ringBuffer_)),
    entryParser_(std::make_shared<EntryParser>(packetReader_)),
    pluginRegistry_(std::move(pluginRegistry)), bufferConsumer_(std::move(bufferConsumer)),
    traceStatePacketWriter_(std::make_shared<RingBufferPacketWriter>(ringBuffer_)),
    traceContext_(nullptr), waitingForTraceCompletion_(false), appInfo_(std::move(appInfo)),
    hasAddedExceptionKillswitchObserver_(false),
    hasAddedGlobalConfigurationChangedObserver_(false) { }

TraceController::~TraceController() {
    std::lock_guard<std::mutex> l(traceContextLock_);
    invalidateCurrentTrace([](const auto id) {
        auto entry = protobuf::makeEntry(proto::Entry_Type_TRACE_FAILURE, id.uuid());
        entry.mutable_error()->set_code(proto::Error_Code_CONTROLLER_DESTRUCTED);
        entry.mutable_error()->set_description(
          "The trace was aborted because the TraceController that managed it was destructed.");
        return entry;
    });
}

TraceID TraceController::startTrace(const std::shared_ptr<proto::TraceConfiguration> &configuration,
                                    std::shared_ptr<TraceConsumer> consumer,
                                    TraceID sessionID,
                                    std::string interactionName,
                                    time::Type timestampNs,
                                    thread::TIDType tid) {
    assert(configuration != nullptr);
    assert(consumer != nullptr);

    const auto epochTime = time::getSecondsSinceEpoch();
    TraceID traceID;
    auto plugins = pluginRegistry_.pluginsForConfiguration(configuration);

    SPECTO_LOG_DEBUG("Starting trace {} for interaction {}", traceID.uuid(), interactionName);

    TraceID previousTraceID;
    proto::Entry finalEntry;
    {
        std::lock_guard<std::mutex> l(traceContextLock_);
        if (!hasAddedExceptionKillswitchObserver_) {
            addCppExceptionKillswitchObserver([weakPtr = weak_from_this()] {
                if (auto self = weakPtr.lock()) {
                    self->abortAllPlugins();
                }
            });
            hasAddedExceptionKillswitchObserver_ = true;
        }
        if (!hasAddedGlobalConfigurationChangedObserver_) {
            configuration::addGlobalConfigurationChangedObserver(
              [weakPtr = weak_from_this()](auto config) {
                  if (config != nullptr && config->enabled()) {
                      return;
                  }
                  if (auto self = weakPtr.lock()) {
                      std::lock_guard<std::mutex> l(self->traceContextLock_);
                      self->invalidateCurrentTrace([](const auto id) {
                          auto entry =
                            protobuf::makeEntry(proto::Entry_Type_TRACE_FAILURE, id.uuid());
                          entry.mutable_error()->set_code(
                            proto::Error_Code_CONFIGURATION_DISABLED_TRACING);
                          entry.mutable_error()->set_description(
                            "The trace was aborted because a new global configuration disabled "
                            "tracing.");
                          return entry;
                      });
                  }
              });
            hasAddedGlobalConfigurationChangedObserver_ = true;
        }

        // Have to stop and invalidate the existing trace before starting a new
        // one, since only one concurrent trace is supported right now.
        std::tie(previousTraceID, finalEntry) =
          invalidateCurrentTrace([timestampNs, tid, interactionName](const auto id) {
              auto entry =
                protobuf::makeEntry(proto::Entry_Type_TRACE_FAILURE, id.uuid(), timestampNs, tid);
              entry.mutable_error()->set_code(proto::Error_Code_TRACE_LIMIT_EXCEEDED);
              entry.mutable_error()->set_description("New \"" + interactionName
                                                     + "\" trace was started.");
              return entry;
          });

        // Wait for another trace to complete if necessary, to avoid writing data to the ring buffer
        // that will be cleared upon completion of the previous trace -- could result in data loss.
        auto willWaitForTraceCompletion = false;
        {
            std::unique_lock<std::mutex> completionLock(traceCompletionLock_);
            willWaitForTraceCompletion = waitingForTraceCompletion_;
            while (waitingForTraceCompletion_) {
                traceCompletionCondvar_.wait(completionLock);
            }
        }
        if (willWaitForTraceCompletion) {
            SPECTO_LOG_DEBUG("Previous trace finished, proceeding with new trace.");
        }

        // Reset stream ID's for packets between traces, since they only need to be unique per-trace
        // and not globally.
        PacketStreamID::reset();

        // Start a new trace.
        proto::TraceMetadata metadata;
        metadata.set_session_id(sessionID.uuid());
        metadata.set_start_date_sec(epochTime.count());
        metadata.set_interaction_name(interactionName);

        consumer->start(traceID);

        // Function that notifies the `TraceBufferConsumer` that there is new data to read. This
        // triggers a wakeup for the consumer thread, which then reads the data from the buffer.
        // The function is passed to each `TraceLogger` to be called whenever a new entry is
        // written.
        const auto notifyBufferConsumer = [weakSelf = weak_from_this(), consumer] {
            if (auto self = weakSelf.lock()) {
                self->bufferConsumer_->notify(self->entryParser_, consumer);
            }
        };

        auto startEntry =
          protobuf::makeEntry(proto::Entry_Type_TRACE_START, traceID.uuid(), timestampNs, tid);
        startEntry.mutable_trace_metadata()->CopyFrom(metadata);

        auto traceContext = std::make_unique<TraceContext>();
        traceContext->id = traceID;
        traceContext->interactionName = std::move(interactionName);
        traceContext->traceMetadata = std::move(metadata);
        traceContext->traceStateLogger =
          std::make_shared<TraceLogger>(traceStatePacketWriter_, timestampNs, notifyBufferConsumer);
        traceContext->traceStateLogger->log(std::move(startEntry));
        traceContext->consumer = std::move(consumer);

        auto appInfoEntry = protobuf::makeEntry(proto::Entry_Type_APP_INFO, "", timestampNs, tid);
        *(appInfoEntry.mutable_app_info()) = *appInfo_;
        traceContext->traceStateLogger->log(std::move(appInfoEntry));

        std::vector<std::pair<std::shared_ptr<Plugin>, std::shared_ptr<TraceLogger>>>
          pluginTraceLoggers;
        SPECTO_LOG_TRACE("Creating TraceLoggers with timestamp {}", timestampNs);
        for (const auto &plugin : plugins) {
            auto traceLogger = std::make_shared<TraceLogger>(
              packetWriterForPlugin(plugin), timestampNs, notifyBufferConsumer);
            plugin->start(traceLogger, configuration);
            pluginTraceLoggers.push_back(std::make_pair(plugin, std::move(traceLogger)));
        }

        traceContext->plugins = std::move(plugins);
        traceContext->pluginTraceLoggers = std::move(pluginTraceLoggers);
        std::atomic_init(&traceContext->annotationID, EmptyAnnotationID);
        traceContext_ = std::move(traceContext);
    }
    if (!previousTraceID.isEmpty()) {
        traceEventSubject_.traceFailed(previousTraceID, finalEntry.error());
    }
    traceEventSubject_.traceStarted(traceID);
    return traceID;
}

TraceID TraceController::endTrace(const std::string &interactionName,
                                  time::Type timestampNs,
                                  thread::TIDType tid) {
    TraceID traceID;
    {
        std::lock_guard<std::mutex> l(traceContextLock_);
        std::tie(traceID, std::ignore) =
          invalidateTrace(interactionName, [timestampNs, tid](const auto id) {
              return protobuf::makeEntry(proto::Entry_Type_TRACE_END, id.uuid(), timestampNs, tid);
          });
    }
    if (!traceID.isEmpty()) {
        SPECTO_LOG_DEBUG(
          "Ending trace {} for interaction name {}", traceID.uuid(), interactionName);
        traceEventSubject_.traceEnded(traceID);
    }
    return traceID;
}

TraceID TraceController::abortTrace(const std::string &interactionName,
                                    proto::Error error,
                                    time::Type timestampNs,
                                    thread::TIDType tid) {
    TraceID traceID;
    proto::Entry finalEntry;
    {
        std::lock_guard<std::mutex> l(traceContextLock_);
        std::tie(traceID, finalEntry) =
          invalidateTrace(interactionName, [&error, timestampNs, tid](const auto id) {
              auto entry =
                protobuf::makeEntry(proto::Entry_Type_TRACE_FAILURE, id.uuid(), timestampNs, tid);
              entry.mutable_error()->CopyFrom(error);
              return entry;
          });
    }
    if (!traceID.isEmpty()) {
        SPECTO_LOG_DEBUG("Aborting trace {}", traceID.uuid());
        traceEventSubject_.traceFailed(traceID, finalEntry.error());
    }
    return traceID;
}

TraceID TraceController::timeoutTrace(const std::string &interactionName,
                                      time::Type timestampNs,
                                      thread::TIDType tid) {
    TraceID traceID;
    proto::Entry finalEntry;
    {
        std::lock_guard<std::mutex> l(traceContextLock_);
        std::tie(traceID, finalEntry) =
          invalidateTrace(interactionName, [timestampNs, tid](const auto id) {
              auto entry =
                protobuf::makeEntry(proto::Entry_Type_TRACE_FAILURE, id.uuid(), timestampNs, tid);
              proto::Error error;
              entry.mutable_error()->set_code(proto::Error_Code_TRACE_TIMEOUT);
              entry.mutable_error()->set_description(
                "The trace did not complete within the timeout duration.");
              return entry;
          });
        SPECTO_LOG_DEBUG("Timing out trace {}", traceID.uuid());
    }
    if (!traceID.isEmpty()) {
        traceEventSubject_.traceFailed(traceID, finalEntry.error());
    }
    return traceID;
}

AnnotationID TraceController::annotateTrace(const std::string &interactionName,
                                            std::string key,
                                            std::string value,
                                            time::Type timestampNs,
                                            thread::TIDType tid) {
    std::lock_guard<std::mutex> l(traceContextLock_);
    if (traceContext_ == nullptr) {
        SPECTO_LOG_DEBUG("no current trace for annotateTrace with name: {} timestampNs: {} tid: {}",
                         interactionName,
                         timestampNs,
                         tid);
        return EmptyAnnotationID;
    }

    if (interactionName != traceContext_->interactionName) {
        SPECTO_LOG_WARN("Called annotateTrace for interaction name \"{}\", does not match active "
                        "trace interaction name: \"{}\"",
                        interactionName,
                        traceContext_->interactionName);
        return EmptyAnnotationID;
    }

    auto entry = protobuf::makeEntry(
      proto::Entry_Type_TRACE_ANNOTATION, traceContext_->id.uuid(), timestampNs, tid);
    const auto annotation = entry.mutable_annotation();
    const auto annotationID = ++traceContext_->annotationID;
    annotation->set_id(annotationID);
    annotation->set_key(std::move(key));
    annotation->set_value(std::move(value));
    traceContext_->traceStateLogger->log(std::move(entry));
    return annotationID;
}

void TraceController::addObserver(std::shared_ptr<TraceEventObserver> observer) {
    traceEventSubject_.addObserver(observer);
}

void TraceController::removeObserver(std::shared_ptr<TraceEventObserver> observer) {
    traceEventSubject_.removeObserver(observer);
}

TraceID
  TraceController::startSpan(std::string spanName, time::Type timestampNs, thread::TIDType tid) {
    std::lock_guard<std::mutex> l(traceContextLock_);
    if (traceContext_ == nullptr) {
        SPECTO_LOG_DEBUG("No current trace for startSpan with name: {}, timestampNs: {}, tid: {}",
                         spanName,
                         timestampNs,
                         tid);
        return TraceID::empty;
    }

    TraceID spanID;
    SPECTO_LOG_DEBUG("Starting span {} with name {}", spanID.uuid(), spanName);

    traceContext_->traceSpans.push_back({.id = spanID, .name = spanName});

    auto entry = protobuf::makeEntry(proto::Entry_Type_SPAN_START, spanID.uuid(), timestampNs, tid);
    entry.mutable_span_metadata()->set_name(std::move(spanName));
    traceContext_->traceStateLogger->log(std::move(entry));

    return spanID;
}

TraceID
  TraceController::endSpan(std::string spanName, time::Type timestampNs, thread::TIDType tid) {
    SPECTO_LOG_TRACE(
      "Called endSpan with name: {}, timestampNs: {}, tid: {}", spanName, timestampNs, tid);
    return endSpan(
      [&spanName](const auto &context) { return context.name == spanName; }, timestampNs, tid);
}

std::pair<TraceID, AnnotationID> TraceController::annotateSpan(std::string spanName,
                                                               std::string key,
                                                               std::string value,
                                                               time::Type timestampNs,
                                                               thread::TIDType tid) {
    SPECTO_LOG_TRACE(
      "Called annotateSpan with name: {}, key: {}, value: {}, timestampNs: {}, tid: {}",
      spanName,
      key,
      value,
      timestampNs,
      tid);
    return annotateSpan([&spanName](const auto &context) { return context.name == spanName; },
                        std::move(key),
                        std::move(value),
                        timestampNs,
                        tid);
}

bool TraceController::endSpan(TraceID spanID, time::Type timestampNs, thread::TIDType tid) {
    SPECTO_LOG_TRACE(
      "Called endSpan with spanID: {}, timestampNs: {}, tid: {}", spanID.uuid(), timestampNs, tid);
    return !endSpan(
              [&spanID](const auto &context) { return context.id == spanID; }, timestampNs, tid)
              .isEmpty();
}

AnnotationID TraceController::annotateSpan(TraceID spanID,
                                           std::string key,
                                           std::string value,
                                           time::Type timestampNs,
                                           thread::TIDType tid) {
    SPECTO_LOG_TRACE(
      "Called annotateSpan with spanID: {}, key: {}, value: {}, timestampNs: {}, tid: {}",
      spanID.uuid(),
      key,
      value,
      timestampNs,
      tid);
    return annotateSpan([&spanID](const auto &context) { return context.id == spanID; },
                        std::move(key),
                        std::move(value),
                        timestampNs,
                        tid)
      .second;
}

void TraceController::log(specto::proto::Entry entry) {
    std::lock_guard<std::mutex> l(traceContextLock_);
    if (traceContext_ == nullptr) {
        return;
    }
    traceContext_->traceStateLogger->log(std::move(entry));
}

#pragma mark - Private

std::shared_ptr<PacketWriter>
  TraceController::packetWriterForPlugin(const std::shared_ptr<Plugin> &plugin) {
    assert(plugin != nullptr);

    for (const auto &pluginAndPacketWriter : pluginPacketWriters_) {
        if (pluginAndPacketWriter.first == plugin) {
            return pluginAndPacketWriter.second;
        }
    }
    auto packetWriter = std::make_shared<RingBufferPacketWriter>(ringBuffer_);
    pluginPacketWriters_.push_back(std::make_pair(plugin, packetWriter));
    return packetWriter;
}

std::pair<TraceID, proto::Entry>
  TraceController::invalidateTrace(const std::string &interactionName,
                                   std::function<proto::Entry(TraceID)> finalEntryGenerator) {
    if (traceContext_ == nullptr) {
        return std::make_pair(TraceID::empty, proto::Entry {});
    }

    if (interactionName != traceContext_->interactionName) {
        SPECTO_LOG_WARN("Called invalidateTrace for interaction name \"{}\", does not match active "
                        "trace interaction name: \"{}\"",
                        interactionName,
                        traceContext_->interactionName);
        return std::make_pair(TraceID::empty, proto::Entry {});
    }

    return invalidateCurrentTrace(finalEntryGenerator);
}

std::pair<TraceID, proto::Entry> TraceController::invalidateCurrentTrace(
  std::function<proto::Entry(TraceID)> finalEntryGenerator) {
    assert(finalEntryGenerator != nullptr);

    if (traceContext_ == nullptr) {
        return std::make_pair(TraceID::empty, proto::Entry {});
    }

    const auto traceID = traceContext_->id;
    auto finalEntry = finalEntryGenerator(traceID);
    const auto isSuccessful = finalEntry.type() == proto::Entry_Type_TRACE_END;

    for (const auto &pluginAndLogger : traceContext_->pluginTraceLoggers) {
        const auto plugin = pluginAndLogger.first;
        const auto logger = pluginAndLogger.second;
        if (isSuccessful) {
            plugin->end(logger);
        } else if (finalEntry.has_error()) {
            plugin->abort(finalEntry.error());
        } else {
            plugin->abort({});
        }
        logger->invalidate();
    }

    const auto dropCount = ringBuffer_->getDropCounter();
    if (dropCount > 0) {
        auto ringBufferEntry = protobuf::makeEntry(proto::Entry_Type_RINGBUFFER_METRICS);
        ringBufferEntry.mutable_ringbuffer_metrics()->set_drop_count(dropCount);
        traceContext_->traceStateLogger->log(std::move(ringBufferEntry));
    }
    traceContext_->traceStateLogger->log(finalEntry);
    traceContext_->traceStateLogger->invalidate();

    // Manually notify the buffer consumer that there's new data to read (even though there
    // isn't any) to implement a barrier of sorts, so that we know when all of the data has been
    // written and it is safe to call `end` on the consumer.
    {
        std::lock_guard<std::mutex> l(this->traceCompletionLock_);
        waitingForTraceCompletion_ = true;
    }

    const auto consumer = traceContext_->consumer;
    bufferConsumer_->notify(
      entryParser_, consumer, [weakSelf = weak_from_this(), isSuccessful, consumer]() {
          if (auto self = weakSelf.lock()) {
              self->ringBuffer_->clear();
              self->ringBuffer_->resetDropCounter();
              {
                  std::lock_guard<std::mutex> l(self->traceCompletionLock_);
                  self->waitingForTraceCompletion_ = false;
              }
              self->traceCompletionCondvar_.notify_all();
          }
          consumer->end(isSuccessful);
      });

    traceContext_ = nullptr;
    return std::make_pair(traceID, std::move(finalEntry));
}

void TraceController::abortAllPlugins() {
    std::lock_guard<std::mutex> l(traceContextLock_);
    if (traceContext_ == nullptr) {
        return;
    }

    proto::Error error;
    error.set_code(proto::Error_Code_EXCEPTION_RAISED);
    error.set_description("A C++ exception was raised");

    for (const auto &pluginAndLogger : traceContext_->pluginTraceLoggers) {
        pluginAndLogger.first->abort(error);
    }
    traceContext_ = nullptr;
}

TraceID
  TraceController::endSpan(SpanPredicate predicate, time::Type timestampNs, thread::TIDType tid) {
    std::lock_guard<std::mutex> l(traceContextLock_);
    if (traceContext_ == nullptr) {
        SPECTO_LOG_DEBUG(
          "No current trace for endSpan called with predicate, timestampNs: {}, tid: {}",
          timestampNs,
          tid);
        return TraceID::empty;
    }

    auto &spans = traceContext_->traceSpans;
    const auto findItReverse = std::find_if(spans.rbegin(), spans.rend(), predicate);
    if (findItReverse == spans.rend()) {
        // The span does not exist, no-op.
        SPECTO_LOG_DEBUG(
          "No matching span found for endSpan called with predicate, timestampNs: {}, tid: {}",
          timestampNs,
          tid);
        return TraceID::empty;
    }
    // base() turns a reverse iterator into a forward iterator, but it needs
    // to be decremented by 1 because the reverse iterator points at one element
    // but dereferences the *previous* element, as explained here:
    // https://stackoverflow.com/a/4408182
    const auto findIt = --(findItReverse.base());
    const auto spanID = (*findIt).id;

    SPECTO_LOG_DEBUG("Ending span {} with name {}", spanID.uuid(), (*findIt).name);

    auto entry = protobuf::makeEntry(proto::Entry_Type_SPAN_END, spanID.uuid(), timestampNs, tid);
    entry.set_elapsed_relative_to_start_date_ns(timestampNs);
    traceContext_->traceStateLogger->log(std::move(entry));

    spans.erase(findIt);
    return spanID;
}

std::pair<TraceID, AnnotationID> TraceController::annotateSpan(SpanPredicate predicate,
                                                               std::string key,
                                                               std::string value,
                                                               time::Type timestampNs,
                                                               thread::TIDType tid) {
    std::lock_guard<std::mutex> l(traceContextLock_);
    if (traceContext_ == nullptr) {
        SPECTO_LOG_DEBUG("No current trace for annotateSpan called with predicate, key: {}, value: "
                         "{}, timestampNs: {}, tid: {}",
                         key,
                         value,
                         timestampNs,
                         tid);
        return std::make_pair(TraceID::empty, EmptyAnnotationID);
    }

    auto &spans = traceContext_->traceSpans;
    const auto findItReverse = std::find_if(spans.rbegin(), spans.rend(), predicate);
    if (findItReverse == spans.rend()) {
        // The span does not exist, no-op.
        SPECTO_LOG_DEBUG("No matching span found for annotateSpan called with predicate, key: {}, "
                         "value: {}, timestampNs: {}, tid: {}",
                         key,
                         value,
                         timestampNs,
                         tid);
        return std::make_pair(TraceID::empty, EmptyAnnotationID);
    }

    const auto findIt = --(findItReverse.base());
    const auto spanID = (*findIt).id;

    SPECTO_LOG_DEBUG("Annotating span {} with name {}: key: {}, value: {}",
                     spanID.uuid(),
                     (*findIt).name,
                     key,
                     value);

    auto entry =
      protobuf::makeEntry(proto::Entry_Type_SPAN_ANNOTATION, spanID.uuid(), timestampNs, tid);
    const auto annotation = entry.mutable_annotation();
    const auto annotationID = ++traceContext_->annotationID;
    annotation->set_id(annotationID);
    annotation->set_key(std::move(key));
    annotation->set_value(std::move(value));
    traceContext_->traceStateLogger->log(std::move(entry));
    return std::make_pair(spanID, annotationID);
}

} // namespace specto
