#import "SentryDefines.h"
#import <Foundation/Foundation.h>

@class SentryLogOutput;

#define SENTRY_DEFAULT_LOG_LEVEL kSentryLevelError

NS_ASSUME_NONNULL_BEGIN

@interface SentryLog : NSObject
SENTRY_NO_INIT

+ (void)configure:(BOOL)debug diagnosticLevel:(SentryLevel)level;

+ (void)logWithMessage:(NSString *)message andLevel:(SentryLevel)level;

@end

NS_ASSUME_NONNULL_END
