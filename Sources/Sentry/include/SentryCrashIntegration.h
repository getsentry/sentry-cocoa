#import "SentryBaseIntegration.h"
#import "SentrySwift.h"

NS_ASSUME_NONNULL_BEGIN

@class SentryCrashWrapper;
@class SentryScope;

static NSString *const SentryDeviceContextFreeMemoryKey = @"free_memory";
static NSString *const SentryDeviceContextAppMemoryKey = @"app_memory";

@interface SentryCrashIntegration : SentryBaseIntegration <SentryIntegrationProtocol>

/**
 * Needed for testing.
 */
+ (void)sendAllSentryCrashReports;

@end

NS_ASSUME_NONNULL_END
