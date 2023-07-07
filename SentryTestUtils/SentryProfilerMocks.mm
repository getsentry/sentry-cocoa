#import "SentryProfilerMocks.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

Backtrace
mockBacktrace(thread::TIDType threadID, const int threadPriority, const char *threadName,
    std::uint64_t queueAddress, std::string queueLabel, std::vector<std::uintptr_t> addresses)
{
    ThreadMetadata threadMetadata;
    if (threadName != nullptr) {
        threadMetadata.name = threadName;
    }
    threadMetadata.threadID = threadID;
    threadMetadata.priority = threadPriority;

    QueueMetadata queueMetadata;
    queueMetadata.address = queueAddress;
    queueMetadata.label = std::make_shared<std::string>(queueLabel);

    Backtrace backtrace;
    backtrace.threadMetadata = threadMetadata;
    backtrace.queueMetadata = queueMetadata;
    backtrace.addresses = std::vector<std::uintptr_t>(addresses);

    return backtrace;
}

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
