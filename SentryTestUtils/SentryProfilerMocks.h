#import "SentryBacktrace.hpp"
#import <Foundation/Foundation.h>

using namespace sentry::profiling;

NS_ASSUME_NONNULL_BEGIN

Backtrace mockBacktrace(thread::TIDType threadID, const int threadPriority,
    const char *_Nullable threadName, std::uint64_t queueAddress, std::string queueLabel,
    std::vector<std::uintptr_t> addresses);

NS_ASSUME_NONNULL_END
