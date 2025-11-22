#import "SentryBaseIntegration.h"

NS_ASSUME_NONNULL_BEGIN

@class SentryLogger;
@class SentryDispatchQueueWrapper;

/**
 * Integration that captures stdout and stderr output and forwards it to Sentry logs.
 */
@interface SentryStdOutLogIntegration : SentryBaseIntegration

// Only for testing
- (instancetype)initWithDispatchQueue:(SentryDispatchQueueWrapper *)dispatchQueue
                               logger:(SentryLogger *)logger;

@end

NS_ASSUME_NONNULL_END
