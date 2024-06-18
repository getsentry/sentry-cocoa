#import "SentryDefines.h"
#import "SentrySwift.h"

@class SentryLogSinkNSLog;
@protocol SentryLogSink;

NS_ASSUME_NONNULL_BEGIN

@interface SentryLog : NSObject
SENTRY_NO_INIT

+ (instancetype)sharedInstance;

//@property (nonatomic, assign, readonly) BOOL isDebug;
//@property (nonatomic, assign, readonly) SentryLevel diagnosticLevel;

- (instancetype)initWithSinks:(NSArray<id<SentryLogSink>> *)sinks;

- (void)configure:(BOOL)debug diagnosticLevel:(SentryLevel)level;

- (void)logWithMessage:(NSString *)message andLevel:(SentryLevel)level;

/**
 * @return @c YES if the current logging configuration will log statements at the current level,
 * @c NO if not.
 */
- (BOOL)willLogAtLevel:(SentryLevel)level;

@end

NS_ASSUME_NONNULL_END

#define SENTRY_LOG_WITH_LOGGER(SENTRY_LOGGER, _SENTRY_LOG_LEVEL, ...)                              \
    if ([SENTRY_LOGGER willLogAtLevel:_SENTRY_LOG_LEVEL]) {                                        \
        [SENTRY_LOGGER                                                                             \
            logWithMessage:[NSString stringWithFormat:@"[%@:%d] %@",                               \
                                     [[[NSString stringWithUTF8String:__FILE__] lastPathComponent] \
                                         stringByDeletingPathExtension],                           \
                                     __LINE__, [NSString stringWithFormat:__VA_ARGS__]]            \
                  andLevel:_SENTRY_LOG_LEVEL];                                                     \
    }

#define SENTRY_LOG_DEBUG_WITH_LOGGER(SENTRY_LOGGER, ...)                                           \
    SENTRY_LOG_WITH_LOGGER(SENTRY_LOGGER, kSentryLevelDebug, __VA_ARGS__)
#define SENTRY_LOG_INFO_WITH_LOGGER(SENTRY_LOGGER, ...)                                            \
    SENTRY_LOG_WITH_LOGGER(SENTRY_LOGGER, kSentryLevelInfo, __VA_ARGS__)
#define SENTRY_LOG_WARN_WITH_LOGGER(SENTRY_LOGGER, ...)                                            \
    SENTRY_LOG_WITH_LOGGER(SENTRY_LOGGER, kSentryLevelWarning, __VA_ARGS__)
#define SENTRY_LOG_ERROR_WITH_LOGGER(SENTRY_LOGGER, ...)                                           \
    SENTRY_LOG_WITH_LOGGER(SENTRY_LOGGER, kSentryLevelError, __VA_ARGS__)
#define SENTRY_LOG_FATAL_WITH_LOGGER(SENTRY_LOGGER, ...)                                           \
    SENTRY_LOG_WITH_LOGGER(SENTRY_LOGGER, kSentryLevelFatal, __VA_ARGS__)

#define SENTRY_LOG(_SENTRY_LOG_LEVEL, ...)                                                         \
    SENTRY_LOG_WITH_LOGGER(SentryLog.sharedInstance, _SENTRY_LOG_LEVEL, __VA_ARGS__)

#define SENTRY_LOG_DEBUG(...) SENTRY_LOG(kSentryLevelDebug, __VA_ARGS__)
#define SENTRY_LOG_INFO(...) SENTRY_LOG(kSentryLevelInfo, __VA_ARGS__)
#define SENTRY_LOG_WARN(...) SENTRY_LOG(kSentryLevelWarning, __VA_ARGS__)
#define SENTRY_LOG_ERROR(...) SENTRY_LOG(kSentryLevelError, __VA_ARGS__)
#define SENTRY_LOG_FATAL(...) SENTRY_LOG(kSentryLevelFatal, __VA_ARGS__)

#define SENTRY_ASYNC_SAFE_LOG_TO_CONSOLE
#define SENTRY_ASYNC_SAFE_LOG_TO_FILE

/**
 * If @c errno is set to a non-zero value after @c statement finishes executing,
 * the error value is logged, and the original return value of @c statement is
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
