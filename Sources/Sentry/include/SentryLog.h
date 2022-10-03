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
