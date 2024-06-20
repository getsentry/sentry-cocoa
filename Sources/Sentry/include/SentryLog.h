#import "SentryDefines.h"
#import "SentrySwift.h"


@class SentryLogSinkNSLog;
@protocol SentryLogSink;

NS_ASSUME_NONNULL_BEGIN

/**
 * @return @c YES if the the specified logger's configuration will log statements at the specified  level,
 * @c NO if not.
 * @note Exposed as a C function so it can be used from contexts that require async-safety and thus cannot use ObjC.
 */
SENTRY_EXTERN BOOL loggerWillLogAtLevel(const char *loggerLabel, SentryLevel level);

@interface SentryLog : NSObject
SENTRY_NO_INIT

@property (assign, readonly, nonatomic) const char *label;

+ (instancetype)sharedInstance;

- (instancetype)initWithLabel:(const char *)label sinks:(NSArray<id<SentryLogSink>> *)sinks;

- (void)configure:(BOOL)debug diagnosticLevel:(SentryLevel)level;

- (void)logWithMessage:(NSString *)message andLevel:(SentryLevel)level;

@end

NS_ASSUME_NONNULL_END

#define SENTRY_LOG_WITH_LOGGER(SENTRY_LOGGER, _SENTRY_LOG_LEVEL, ...)                              \
    if (loggerWillLogAtLevel(SENTRY_LOGGER.label, _SENTRY_LOG_LEVEL)) {                                        \
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

/**
 * If @c errno is set to a non-zero value after @c statement finishes executing,
 * the error value is logged, and the original return value of @c statement is
 * returned.
 */
#define SENTRY_LOG_ERRNO_RETURN(statement)                                                                \
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
