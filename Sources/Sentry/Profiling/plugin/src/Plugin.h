// Copyright (c) Specto Inc. All rights reserved.

#pragma once

#include "cpp/tracelogger/src/TraceLogger.h"
#include "spectoproto/error/error_generated.pb.h"
#include "spectoproto/trace/configuration_generated.pb.h"

#include <memory>

namespace specto {

/** An abstract class that defines a plugin for collecting trace information. */
class Plugin {
public:
    /**
     * Called by the infrastructure to start logging trace information.
     *
     * @param logger The logger used to write trace information.
     * @param configuration The configuration of the trace that the plugin is being used for.
     */
    virtual void start(std::shared_ptr<TraceLogger> logger,
                       const std::shared_ptr<proto::TraceConfiguration> &configuration) = 0;

    /**
     * Called by the infrastructure to stop logging trace information.
     *
     * @param logger The logger used to write trace information.
     */
    virtual void end(std::shared_ptr<TraceLogger> logger) = 0;

    /**
     * Called by the infrastructure to stop logging trace information in the event that a trace
     * is aborted due to an error.
     *
     * @param error The error that caused the trace to be aborted.
     */
    virtual void abort(const proto::Error &error) = 0;

    /**
     * @return bool Whether this plugin should be enabled for the specified
     * trace configuration.
     */
    virtual bool
      shouldEnable(const std::shared_ptr<proto::TraceConfiguration> &configuration) const = 0;

    virtual ~Plugin() = 0;
};

} // namespace specto
