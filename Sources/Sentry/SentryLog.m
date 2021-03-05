#import "SentryLog.h"
#import "SentryClient.h"
#import "SentrySDK.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentryLog

/**
 * Enable per default to log initialization errors.
 */
static BOOL isDebug = YES;
static SentryLevel diagnosticLevel = kSentryLevelError;

+ (void)configure:(BOOL)debug diagnosticLevel:(SentryLevel)level
{
    isDebug = debug;
    diagnosticLevel = level;
}

+ (void)logWithMessage:(NSString *)message andLevel:(SentryLevel)level
{
    if (isDebug && level != kSentryLevelNone && level <= diagnosticLevel) {
        NSLog(@"Sentry - %@:: %@", SentryLevelNames[level], message);
    }
}

@end

NS_ASSUME_NONNULL_END
