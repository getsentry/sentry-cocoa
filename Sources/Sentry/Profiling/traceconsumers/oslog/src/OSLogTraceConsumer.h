// Copyright (c) Specto Inc. All rights reserved.

#pragma once

#include "cpp/trace/src/TraceConsumer.h"

namespace specto {

/**
 * A trace consumer that writes to Apple's unified logging (OSLog) API.
 * The OSLog subsystem used for the messages generated here is "dev.specto.Specto"
 *
 * Originally, the log type was set to DEBUG. According to the documentation, running
 * the command below should enable debug logging for our subsystem so that the logs
 * show up in Console.app:
 *
 * $ sudo log config --mode "level:debug" --subsystem dev.specto.Specto
 *
 * However, the log messages only show up in Xcode. This appears to be a known issue
 * that is documented in this forum thread: https://forums.developer.apple.com/thread/82736
 *
 * For the time being, this has been changed to use a DEFAULT log type so that Console.app
 * will show the logs. Once the bug is fixed, we can go back to DEBUG.
 *
 * More information in the Unified Logging documentation:
 * https://developer.apple.com/documentation/os/logging?language=objc
 */
class OSLogTraceConsumer : public TraceConsumer {
public:
    /** Creates a new `OSLogTraceConsumer` */
    OSLogTraceConsumer();

    void start(TraceID id) override;
    void end(bool successful) override;
    void receiveEntryBuffer(std::shared_ptr<char> buf, std::size_t size) override;

    OSLogTraceConsumer(const OSLogTraceConsumer &) = delete;
    OSLogTraceConsumer &operator=(const OSLogTraceConsumer &) = delete;
};

} // namespace specto
