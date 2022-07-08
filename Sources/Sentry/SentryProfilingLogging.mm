#include "SentryProfilingLogging.hpp"

#import "SentryLog.h"

namespace sentry {
namespace profiling {
    namespace {
        SentryLevel
        sentryLevelFromLogLevel(LogLevel level)
        {
            switch (level) {
            case LogLevel::None:
                return kSentryLevelNone;
            case LogLevel::Debug:
                return kSentryLevelDebug;
            case LogLevel::Info:
                return kSentryLevelInfo;
            case LogLevel::Warning:
                return kSentryLevelWarning;
            case LogLevel::Error:
                return kSentryLevelError;
            case LogLevel::Fatal:
                return kSentryLevelFatal;
            }
        }
    }

    void
    log(LogLevel level, const char *fmt, ...)
    {
        if (fmt == nullptr) {
            return;
        }
        va_list args;
        va_start(args, fmt);
        va_end(args);
        const auto fmtStr = [[NSString alloc] initWithUTF8String:fmt];
        [SentryLog logWithMessage:[[NSString alloc] initWithFormat:fmtStr arguments:args]
                         andLevel:sentryLevelFromLogLevel(level)];
    }

} // namespace profiling
} // namespace sentry
