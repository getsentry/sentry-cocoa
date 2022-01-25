// Copyright (c) Specto Inc. All rights reserved.

#import "cpp/plugin/src/Plugin.h"

#import <Foundation/Foundation.h>
#import <memory>

namespace specto {
namespace darwin {
class SamplingProfiler;

/**
 * A plugin that captures backtraces from all threads.

 * BACKTRACE entries are created for each sample for each thread separately.
 */
class BacktracePlugin : public Plugin {
public:
    BacktracePlugin();

    void start(std::shared_ptr<TraceLogger> logger,
               const std::shared_ptr<proto::TraceConfiguration> &configuration) override;
    void end(std::shared_ptr<TraceLogger> logger) override;
    void abort(const proto::Error &error) override;
    bool
      shouldEnable(const std::shared_ptr<proto::TraceConfiguration> &configuration) const override;

    BacktracePlugin(const BacktracePlugin &) = delete;
    BacktracePlugin &operator=(const BacktracePlugin &) = delete;

private:
    std::shared_ptr<SamplingProfiler> profiler_ {nullptr};

    void stopCollecting();
};

} // namespace darwin
} // namespace specto
