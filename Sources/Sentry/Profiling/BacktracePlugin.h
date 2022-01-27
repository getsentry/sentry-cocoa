// Copyright (c) Specto Inc. All rights reserved.
#import "SentryIntegrationProtocol.h"
#import <Foundation/Foundation.h>
#import <memory>

@class SentryOptions;
@class SentryProfilingTraceLogger;
@class SentryFileManager;

NS_ASSUME_NONNULL_BEGIN

@interface SentryBacktraceTrackerIntegration : NSObject <SentryIntegrationProtocol>

@end

namespace specto {
namespace darwin {
class SamplingProfiler;

/**
 * A plugin that captures backtraces from all threads.

 * BACKTRACE entries are created for each sample for each thread separately.
 */
class BacktracePlugin {
public:
    BacktracePlugin();

    void start(SentryProfilingTraceLogger *logger,
               SentryOptions *options);
    void end();
    void abort();
    bool
      shouldEnable(SentryOptions *options) const;

    BacktracePlugin(const BacktracePlugin &) = delete;
    BacktracePlugin &operator=(const BacktracePlugin &) = delete;

private:
    std::shared_ptr<SamplingProfiler> profiler_ {nullptr};
    SentryFileManager *filemanager_ {nullptr};

    void stopCollecting();
};

} // namespace darwin
} // namespace specto

NS_ASSUME_NONNULL_END
