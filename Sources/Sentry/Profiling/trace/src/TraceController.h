// Copyright (c) Specto Inc. All rights reserved.

#pragma once

#include "TraceEventSubject.h"
#include "PluginRegistry.h"
#include "Thread.h"
#include "SpectoTime.h"
#include "TraceID.h"
//#include "spectoproto./trace/trace_metadata_generated.pb.h"

#include <chrono>
#include <functional>
#include <memory>
#include <mutex>
#include <string>
#include <utility>
#include <vector>

namespace specto {
class EntryParser;
struct Packet;
class PacketWriter;
class RingBufferPacketReader;
class RingBufferPacketWriter;
class TraceBufferConsumer;
class TraceConsumer;

template<typename T>
class RingBuffer;

namespace internal {
struct TraceContext;
struct SpanContext;
} // namespace internal

namespace proto {
class Entry;
class Error;
class AppInfo;
class TraceConfiguration;
} // namespace proto

/** An ID that uniquely identifies a trace or span annotation within a single trace. */
using AnnotationID = std::uint64_t;

/** A value that represents the lack of existence of an annotation ID. */
constexpr AnnotationID EmptyAnnotationID = 0;

/**
 * Controls starting/stopping traces and manages shared state.
 *
 * @warning This class is not re-entrant! If starting or stopping a trace causes
 * one of these methods to be called again (e.g. via a plugin's `start` or `end`)
 * function, there will be a deadlock. This scenario is programmer error, as
 * there should be no reason why a plugin should start or stop a trace from inside
 * another trace.
 */
class TraceController : public std::enable_shared_from_this<TraceController> {
public:
    /**
     * Constructs a new trace controller.
     *
     * @param pluginRegistry The registry of plugins that are supported by traces
     * started using this trace controller.
     * @param bufferConsumer The trace buffer consumer to be notified when trace
     * @param appInfo Information about the app & device.
     * data is available to be read.
     */
    TraceController(PluginRegistry pluginRegistry,
                    std::shared_ptr<TraceBufferConsumer> bufferConsumer,
                    std::shared_ptr<proto::AppInfo> appInfo);

    /**
     * Starts a new trace.
     * @param configuration Configuration parameters for the new trace.
     * @param consumer Consumes trace events as they are written.
     * @param sessionID The ID of the session that this trace was started within.
     * @param interactionName The name of the interaction that this trace is associated with.
     * @param timestampNs The absolute timestamp in nanoseconds of when the trace
     * was started, which defaults to the current absolute timestamp.
     * @param tid The ID of the thread from which the trace was started.
     * @return The ID of the trace that was started.
     */
    TraceID startTrace(const std::shared_ptr<proto::TraceConfiguration> &configuration,
                       std::shared_ptr<TraceConsumer> consumer,
                       TraceID sessionID,
                       std::string interactionName,
                       time::Type timestampNs = time::getUptimeNs(),
                       thread::TIDType tid = thread::getCurrentTID());

    /**
     * Ends the current trace if one is in progress, otherwise no-op. This is
     * used for ending the trace intentionally (not a failure case).
     *
     * @param interactionName The interaction name that was previously used
     * to start the trace. If this does not represent an active trace, this
     * function will log a warning and be a no-op.
     * @param timestampNs The absolute timestamp in nanoseconds of when the trace
     * was ended, which defaults to the current absolute timestamp.
     * @param tid The ID of the thread from which the trace was ended.
     * @return The ID of the trace that was ended, or `TraceID::empty` if no
     * trace was running.
     */
    TraceID endTrace(const std::string &interactionName,
                     time::Type timestampNs = time::getUptimeNs(),
                     thread::TIDType tid = thread::getCurrentTID());

    /**
     * Adds a key-value annotation to the trace with the specified interaction name.
     * @param interactionName The interaction name that was previously used
     * to start the trace. If this does not represent an active trace, this
     * function will log a warning and be a no-op.
     * @param key The key of the annotation.
     * @param value The value of the annotation.
     * @param timestampNs The absolute timestamp in nanoseconds of when the trace
     * was annotated, which defaults to the current absolute timestamp.
     * @param tid The ID of the thread from which the trace was annotated.
     * @return The ID of the annotation, or `EmptyAnnotationID` if no trace matching
     * the specified interaction name was running.
     */
    AnnotationID annotateTrace(const std::string &interactionName,
                               std::string key,
                               std::string value,
                               time::Type timestampNs = time::getUptimeNs(),
                               thread::TIDType tid = thread::getCurrentTID());

    /**
     * Ends the current trace *with an error* if one is in progress, otherwise
     * no-op.
     *
     * @param interactionName The interaction name that was previously used
     * to start the trace. If this does not represent an active trace, this
     * function will log a warning and be a no-op.
     * @param error The error that caused the trace to fail.
     * @param timestampNs The absolute timestamp in nanoseconds of when the trace
     * was aborted, which defaults to the current absolute timestamp.
     * @param tid The ID of the thread from which the trace was aborted.
     * @return The ID of the trace that was aborted, or `TraceID::empty` if no
     * trace was running.
     */
    TraceID abortTrace(const std::string &interactionName,
                       proto::Error error,
                       time::Type timestampNs = time::getUptimeNs(),
                       thread::TIDType tid = thread::getCurrentTID());

    /**
     * Notifies the trace controller that the current trace, if there is one,
     * has timed out.
     *
     * @param interactionName The interaction name that was previously used
     * to start the trace. If this does not represent an active trace, this
     * function will log a warning and be a no-op.
     * @param timestampNs The absolute timestamp in nanoseconds of when the trace
     * was aborted, which defaults to the current absolute timestamp.
     * @param tid The ID of the thread from which the trace was timed out.
     * @return The ID of the trace that timed out, or `TraceID::empty` if no
     * trace was running.
     */
    TraceID timeoutTrace(const std::string &interactionName,
                         time::Type timestampNs = time::getUptimeNs(),
                         thread::TIDType tid = thread::getCurrentTID());

    /**
     * Starts a trace span with the specified name. A span is an operation
     * within a trace that has a defined start and end. Spans can be started
     * and ended on any thread and can also be nested.
     *
     * @param spanName A name that identifies the span, which does not need to
     * be unique (there can be multiple spans in the same trace with the same
     * name, even nested)
     * @param timestampNs The absolute timestamp in nanoseconds of when the span
     * was started, which defaults to the current absolute timestamp.
     * @param tid The ID of the thread from which the span was started.
     * @return The ID of the span that was started.
     */
    TraceID startSpan(std::string spanName,
                      time::Type timestampNs = time::getUptimeNs(),
                      thread::TIDType tid = thread::getCurrentTID());

    /**
     * Ends the span with the specified name, which can be any span in the
     * current stack of spans. If there are multiple spans with the same name, this
     * will end the top-most one on the stack.
     * @param spanName The name of the span to end.
     * @param timestampNs The absolute timestamp in nanoseconds of when the span
     * was ended, which defaults to the current absolute timestamp.
     * @param tid The ID of the thread from which the span was ended.
     * @return The ID of the span that was ended, or `TraceID::empty` if no span
     * matching the name exists.
     */
    TraceID endSpan(std::string spanName,
                    time::Type timestampNs = time::getUptimeNs(),
                    thread::TIDType tid = thread::getCurrentTID());

    /**
     * Adds a key-value annotation to the span with the specified name, which
     * can be any span in the current stack of spans. If there are multiple spans
     * with the same name, this will annotate the top-most one on the stack.
     * @param spanName The name of the span to annotate.
     * @param key The key of the annotation.
     * @param value The value of the annotation.
     * @param timestampNs The absolute timestamp in nanoseconds of when the span
     * was annotated, which defaults to the current absolute timestamp.
     * @param tid The ID of the thread from which the span was annotated.
     * @return A pair of the ID of the span that was annotated and the ID of the
     * annotation, or `TraceID::empty` and `EmptyAnnotationID` if no span matching the name exists.
     */
    std::pair<TraceID, AnnotationID> annotateSpan(std::string spanName,
                                                  std::string key,
                                                  std::string value,
                                                  time::Type timestampNs = time::getUptimeNs(),
                                                  thread::TIDType tid = thread::getCurrentTID());

    /**
     * Ends the span with the specified ID, which can be any span in the
     * current stack of spans.
     * @param spanID The ID of the span to end.
     * @param timestampNs The absolute timestamp in nanoseconds of when the span
     * was ended, which defaults to the current absolute timestamp.
     * @param tid The ID of the thread from which the span was ended.
     * @return Whether the span was ended -- this could be `false` if a span with
     * the specified ID does not exist in the stack.
     */
    bool endSpan(TraceID spanID,
                 time::Type timestampNs = time::getUptimeNs(),
                 thread::TIDType tid = thread::getCurrentTID());

    /**
     * Adds a key-value annotation to the span with the specified ID, which
     * can be any span in the current stack of spans.
     * @param spanID The ID of the span to annotate.
     * @param key The key of the annotation.
     * @param value The value of the annotation.
     * @param timestampNs The absolute timestamp in nanoseconds of when the span
     * was annotated, which defaults to the current absolute timestamp.
     * @param tid The ID of the thread from which the span was annotated.
     * @return The ID of the annotation, or `EmptyAnnotationID` if no span matching the
     * ID exists.
     */
    AnnotationID annotateSpan(TraceID spanID,
                              std::string key,
                              std::string value,
                              time::Type timestampNs = time::getUptimeNs(),
                              thread::TIDType tid = thread::getCurrentTID());

    /**
     * Logs a trace entry. The entry timestamp will be overwritten with the
     * time relative to the logger's reference time. The maximum serialized
     * size of the entry cannot be larger than `TraceLogger::kMaxEntrySize` bytes.
     *
     * @warning This is intended only to be used by internal infrastructure to
     * inject one-time metadata entries into a trace without the need of a dedicated
     * plugin. Any use case that involves the repeated collection and logging
     * of a specific metric should use the plugin-based API, as using this
     * function to log is not performant.
     *
     * @param entry The entry to log.
     */
    void log(specto::proto::Entry entry);

    /**
     * Add a new observer to be notified on trace events.
     * @param observer The observer to add.
     */
    void addObserver(std::shared_ptr<TraceEventObserver> observer);

    /**
     * Remove a previously registered observer.
     * @param observer The observer to remove.
     */
    void removeObserver(std::shared_ptr<TraceEventObserver> observer);

    TraceController(const TraceController &) = delete;
    TraceController &operator=(const TraceController &) = delete;
    ~TraceController();

private:
    /**
     * Returns an existing packet writer for the specified plugin if one exists,
     * or creates one if necessary.
     */
    std::shared_ptr<PacketWriter> packetWriterForPlugin(const std::shared_ptr<Plugin> &plugin);

    /**
     * Invalidates the trace with the specified interaction name and writes the
     * a final trace entry.
     *
     * @param interactionName The interaction name that was previously used
     * to start the trace.
     * @param finalEventGenerator The function to call to get the final entry to write to conclude
     * the trace.
     * @return The ID of the trace that was invalidated, or `TraceID::empty` if
     * no trace was running.
     */
    std::pair<TraceID, proto::Entry>
      invalidateTrace(const std::string &interactionName,
                      std::function<proto::Entry(TraceID)> finalEntryGenerator);

    /**
     * Invalidates the currently running trace and writes a final trace entry.
     *
     * @param finalEventGenerator The function to call to get the final entry to write to conclude
     * the trace.
     * @return The ID of the trace that was invalidated, or `TraceID::empty` if
     * no trace was running.
     */
    std::pair<TraceID, proto::Entry>
      invalidateCurrentTrace(std::function<proto::Entry(TraceID)> finalEntryGenerator);

    /** If a trace is currently running, calls abort on all of the trace plugins. */
    void abortAllPlugins();

    /**
     * A function that returns true when a span meets a condition. `SpanContext`
     * is a data structure that contains metadata that identifies the span.
     */
    using SpanPredicate = std::function<bool(const internal::SpanContext &)>;

    /**
     * Ends the top-most span in the stack that matches a predicate.
     * @param predicate The predicate to evaluate.
     * @param timestampNs The absolute timestamp in nanoseconds of when the span
     * was ended, which defaults to the current absolute timestamp.
     * @param tid The ID of the thread from which the span was ended.
     * @return The ID of the span matching the predicate, or `TraceID::empty` if
     * no matching span exists.
     */
    TraceID endSpan(SpanPredicate predicate,
                    time::Type timestampNs = time::getUptimeNs(),
                    thread::TIDType tid = thread::getCurrentTID());

    /**
     * Annotates the top-most span in the stack that matches a predicate.
     * @param predicate The predicate to evaluate.
     * @param key The key to annotate with.
     * @param value The value to annotate with.
     * @param timestampNs The absolute timestamp in nanoseconds of when the span
     * was annotated, which defaults to the current absolute timestamp.
     * @param tid The ID of the thread from which the span was annotated.
     * @return A pair of the ID of the span that was annotated and the ID of the
     * annotation, or `TraceID::empty` and `EmptyAnnotationID` if no span matching
     * the name exists.
     */
    std::pair<TraceID, AnnotationID> annotateSpan(SpanPredicate predicate,
                                                  std::string key,
                                                  std::string value,
                                                  time::Type timestampNs = time::getUptimeNs(),
                                                  thread::TIDType tid = thread::getCurrentTID());

    std::shared_ptr<RingBuffer<Packet>> ringBuffer_;
    std::shared_ptr<RingBufferPacketReader> packetReader_;
    std::shared_ptr<EntryParser> entryParser_;
    PluginRegistry pluginRegistry_;
    std::shared_ptr<TraceBufferConsumer> bufferConsumer_;
    std::vector<std::pair<std::shared_ptr<Plugin>, std::shared_ptr<PacketWriter>>>
      pluginPacketWriters_;
    std::shared_ptr<PacketWriter> traceStatePacketWriter_;
    std::unique_ptr<internal::TraceContext> traceContext_;
    std::mutex traceContextLock_;
    TraceEventSubject traceEventSubject_;
    std::mutex traceCompletionLock_;
    std::condition_variable traceCompletionCondvar_;
    bool waitingForTraceCompletion_;
    std::shared_ptr<proto::AppInfo> appInfo_;
    bool hasAddedExceptionKillswitchObserver_;
    bool hasAddedGlobalConfigurationChangedObserver_;
};

} // namespace specto
