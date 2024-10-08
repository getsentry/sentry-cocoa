#import "SentryDefines.h"
#import "SentrySwift.h"

#define SENTRY_LOG(_SENTRY_LOG_LEVEL, ...)                                                         \
    if ([SentryLog willLogAtLevel:_SENTRY_LOG_LEVEL]) {                                            \
        [SentryLog logWithMessage:[NSString stringWithFormat:@"[%@:%d] %@",                        \
                                      [[[NSString stringWithUTF8String:__FILE__]                   \
                                          lastPathComponent] stringByDeletingPathExtension],       \
                                      __LINE__, [NSString stringWithFormat:__VA_ARGS__]]           \
                         andLevel:_SENTRY_LOG_LEVEL];                                              \
    }
#define SENTRY_LOG_DEBUG(...) SENTRY_LOG(kSentryLevelDebug, __VA_ARGS__)
#define SENTRY_LOG_INFO(...) SENTRY_LOG(kSentryLevelInfo, __VA_ARGS__)
#define SENTRY_LOG_WARN(...) SENTRY_LOG(kSentryLevelWarning, __VA_ARGS__)
#define SENTRY_LOG_ERROR(...) SENTRY_LOG(kSentryLevelError, __VA_ARGS__)
#define SENTRY_LOG_FATAL(...) SENTRY_LOG(kSentryLevelFatal, __VA_ARGS__)

/**
 * If @c errno is set to a non-zero value after @c statement finishes executing,
 * the error value is logged, and the original return value of @c statement is
 * returned.
 */
#define SENTRY_LOG_ERRNO(statement)                                                                \
    ({                                                                                             \
        errno = 0;                                                                                 \
        const int __log_rv = (statement);                                                          \
        const int __log_errnum = errno;                                                            \
        if (__log_errnum != 0) {                                                                   \
            SENTRY_LOG_ERROR(@"%s failed with code: %d, description: %s", #statement,              \
                __log_errnum, strerror(__log_errnum));                                             \
        }                                                                                          \
        __log_rv;                                                                                  \
    })
