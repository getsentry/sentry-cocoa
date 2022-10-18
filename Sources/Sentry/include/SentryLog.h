#import "SentryDefines.h"

@class SentryLogOutput;

NS_ASSUME_NONNULL_BEGIN

@interface SentryLog : NSObject
SENTRY_NO_INIT

+ (void)configure:(BOOL)debug diagnosticLevel:(SentryLevel)level;

+ (void)logWithMessage:(NSString *)message andLevel:(SentryLevel)level;

@end

NS_ASSUME_NONNULL_END

#define SENTRY_LOG_DEBUG(...)                                                                      \
    [SentryLog logWithMessage:[NSString stringWithFormat:__VA_ARGS__] andLevel:kSentryLevelDebug]
#define SENTRY_LOG_INFO(...)                                                                       \
    [SentryLog logWithMessage:[NSString stringWithFormat:__VA_ARGS__] andLevel:kSentryLevelInfo]
#define SENTRY_LOG_WARN(...)                                                                       \
    [SentryLog logWithMessage:[NSString stringWithFormat:__VA_ARGS__] andLevel:kSentryLevelWarning]
#define SENTRY_LOG_ERROR(...)                                                                      \
    [SentryLog logWithMessage:[NSString stringWithFormat:__VA_ARGS__] andLevel:kSentryLevelError]
#define SENTRY_LOG_CRITICAL(...)                                                                   \
    [SentryLog logWithMessage:[NSString stringWithFormat:__VA_ARGS__] andLevel:kSentryLevelCritical]

/**
 * If `errno` is set to a non-zero value after `statement` finishes executing,
 * the error value is logged, and the original return value of `statement` is
 * returned.
 */
#define SENTRY_LOG_ERRNO(statement)                                                                \
    ({                                                                                             \
        errno = 0;                                                                                 \
        const auto __log_rv = (statement);                                                         \
        const int __log_errnum = errno;                                                            \
        if (__log_errnum != 0) {                                                                   \
            SENTRY_LOG_ERROR(@"%s failed with code: %d, description: %s", #statement,              \
                __log_errnum, strerror(__log_errnum));                                             \
        }                                                                                          \
        __log_rv;                                                                                  \
    })
