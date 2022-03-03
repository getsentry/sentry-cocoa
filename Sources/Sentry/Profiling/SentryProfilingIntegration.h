#import "SentryIntegrationProtocol.h"
#import <Foundation/Foundation.h>
#import <memory>

@class SentryOptions;
@class SentryProfilingTraceLogger;
@class SentryFileManager;

NS_ASSUME_NONNULL_BEGIN

@interface SentryProfilingIntegration : NSObject <SentryIntegrationProtocol>

@end

namespace sentry {
namespace profiling {
    class SamplingProfiler;

    /**
     * A plugin that captures backtraces from all threads.

     * BACKTRACE entries are created for each sample for each thread separately.
     */
    class BacktracePlugin {
    public:
        BacktracePlugin();

        void start(SentryProfilingTraceLogger *logger, SentryOptions *options);
        void end();
        void abort();
        bool shouldEnable(SentryOptions *options) const;

        BacktracePlugin(const BacktracePlugin &) = delete;
        BacktracePlugin &operator=(const BacktracePlugin &) = delete;

    private:
        std::shared_ptr<SamplingProfiler> profiler_ { nullptr };
        SentryFileManager *filemanager_ { nullptr };

        void stopCollecting();
    };

} // namespace profiling
} // namespace sentry

NS_ASSUME_NONNULL_END
