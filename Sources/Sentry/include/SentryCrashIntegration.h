#import "SentryBaseIntegration.h"

NS_ASSUME_NONNULL_BEGIN

@class SentryCrashWrapper;
@class SentryScope;

@interface SentryCrashIntegration : SentryBaseIntegration

/**
 * Needed for testing.
 */
+ (void)sendAllSentryCrashReports;

@end

NS_ASSUME_NONNULL_END
