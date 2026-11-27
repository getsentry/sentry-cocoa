#import "SentryProfilingConditionals.h"
#import <Foundation/Foundation.h>

#if SENTRY_TARGET_PROFILING_SUPPORTED

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, SentryProfilingLogLevel) {
    SentryProfilingLogLevelDebug,
    SentryProfilingLogLevelWarning,
    SentryProfilingLogLevelError,
};

/** Diagnostic logging outside signal handlers and suspended-thread sampling. */
@protocol SentryProfilingLogger <NSObject>
- (BOOL)shouldLog:(SentryProfilingLogLevel)level;
- (void)log:(SentryProfilingLogLevel)level
    message:(NSString *)message
       file:(NSString *)file
       line:(NSUInteger)line;
@end

/** The SDK or another profiling consumer owns and injects the output. */
@interface SentryProfilingLog : NSObject
@property (class, nonatomic, weak, nullable) id<SentryProfilingLogger> logger;
@end

// Keep a strong snapshot through filtering and emission, and do not evaluate disabled messages.
#    define SENTRY_PROFILING_LOG(LEVEL, ...)                                                       \
        do {                                                                                       \
            id<SentryProfilingLogger> _sentryProfilingLogger = SentryProfilingLog.logger;          \
            if ([_sentryProfilingLogger shouldLog:LEVEL]) {                                        \
                [_sentryProfilingLogger log:LEVEL                                                  \
                                    message:[NSString stringWithFormat:__VA_ARGS__]                \
                                       file:@(__FILE__)                                            \
                                       line:__LINE__];                                             \
            }                                                                                      \
        } while (0)

#    define SENTRY_PROFILING_LOG_DEBUG(...)                                                        \
        SENTRY_PROFILING_LOG(SentryProfilingLogLevelDebug, __VA_ARGS__)
#    define SENTRY_PROFILING_LOG_WARN(...)                                                         \
        SENTRY_PROFILING_LOG(SentryProfilingLogLevelWarning, __VA_ARGS__)
#    define SENTRY_PROFILING_LOG_ERROR(...)                                                        \
        SENTRY_PROFILING_LOG(SentryProfilingLogLevelError, __VA_ARGS__)

NS_ASSUME_NONNULL_END

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
