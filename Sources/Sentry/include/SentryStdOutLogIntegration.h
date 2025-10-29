#import "SentryBaseIntegration.h"

NS_ASSUME_NONNULL_BEGIN

@class SentryLogger;
@class SentryDispatchFactory;
@class SentryDispatchQueueWrapper;

/**
 * Integration that captures stdout and stderr output and forwards it to Sentry logs.
 * This integration is automatically enabled when enableLogs is set to true.
 */
@interface SentryStdOutLogIntegration : SentryBaseIntegration

// Only for testing
- (instancetype)initWithDispatchFactory:(SentryDispatchFactory *)dispatchFactory
                                 logger:(nullable SentryLogger *)logger;

@end

NS_ASSUME_NONNULL_END
