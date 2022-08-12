#import "SentryLog.h"
#import "SentryLogOutput.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentryLog

static SentryLevel diagnosticLevel = SENTRY_DEFAULT_LOG_LEVEL;
static SentryLogOutput *logOutput;

+ (void)configureWithDiagnosticLevel:(SentryLevel)level
{
    diagnosticLevel = level;
}

+ (void)logWithMessage:(NSString *)message andLevel:(SentryLevel)level
{
    if (nil == logOutput) {
        logOutput = [[SentryLogOutput alloc] init];
    }

    if (level != kSentryLevelNone && level >= diagnosticLevel) {
        [logOutput
            log:[NSString stringWithFormat:@"Sentry - %@:: %@", SentryLevelNames[level], message]];
    }
}

/**
 * Internal and only needed for testing.
 */
+ (void)setLogOutput:(nullable SentryLogOutput *)output
{
    logOutput = output;
}

@end

NS_ASSUME_NONNULL_END
