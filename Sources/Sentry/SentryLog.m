#import "SentryLog.h"
#import "SentryAsyncSafeLog.h"
#import "SentryFileManager.h"
#import "SentryInternalCDefines.h"
#import "SentryLevelMapper.h"
#import "SentryLogOutput.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentryLog

/**
 * Enable per default to log initialization errors.
 */
static BOOL isDebug = YES;
static SentryLevel diagnosticLevel = kSentryLevelError;
static SentryLogOutput *logOutput;
static NSObject *logConfigureLock;

+ (void)configure:(BOOL)debug diagnosticLevel:(SentryLevel)level
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ logConfigureLock = [[NSObject alloc] init]; });
    @synchronized(logConfigureLock) {
        isDebug = debug;
        diagnosticLevel = level;
    }

    // set up the async-safe log file
    const char *asyncLogPath =
        [[sentryApplicationSupportPath() stringByAppendingPathComponent:@"async.log"] UTF8String];
    if (SENTRY_LOG_ERRNO(
            sentry_asyncLogSetFileName(asyncLogPath, true /* overwrite existing log */))
        == 0) {
        SENTRY_LOG_ERROR(
            @"Could not open a handle to specified path for async logging %s", asyncLogPath);
    };
}

+ (void)logWithMessage:(NSString *)message andLevel:(SentryLevel)level
{
    if (nil == logOutput) {
        logOutput = [[SentryLogOutput alloc] init];
    }

    if ([self willLogAtLevel:level]) {
        [logOutput log:[NSString stringWithFormat:@"[Sentry] [%@] %@", nameForSentryLevel(level),
                                 message]];
    }
}

+ (BOOL)willLogAtLevel:(SentryLevel)level
    SENTRY_DISABLE_THREAD_SANITIZER(
        "The SDK usually configures the log level and isDebug once when it starts. For tests, we "
        "accept a data race causing some log messages of the wrong level over using a synchronized "
        "block for this method, as it's called frequently in production.")
{
    return isDebug && level != kSentryLevelNone && level >= diagnosticLevel;
}

// Internal and only needed for testing.
+ (void)setLogOutput:(SentryLogOutput *)output
{
    logOutput = output;
}

// Internal and only needed for testing.
+ (SentryLogOutput *)logOutput
{
    return logOutput;
}

// Internal and only needed for testing.
+ (BOOL)isDebug
{
    return isDebug;
}

// Internal and only needed for testing.
+ (SentryLevel)diagnosticLevel
{
    return diagnosticLevel;
}

@end

NS_ASSUME_NONNULL_END
