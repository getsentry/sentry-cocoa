#import "SentryDefines.h"

@class SentryCrashWrapper;

#if SENTRY_HAS_UIKIT
@class SentryWatchdogTerminationLogic;
#endif // SENTRY_HAS_UIKIT

@interface SentryCrashIntegrationSessionHandler : NSObject

#if SENTRY_HAS_UIKIT
- (instancetype)initWithCrashWrapper:(SentryCrashWrapper *)crashWrapper
            watchdogTerminationLogic:(SentryWatchdogTerminationLogic *)watchdogTerminationLogic;
#else
- (instancetype)initWithCrashWrapper:(SentryCrashWrapper *)crashWrapper;
#endif // SENTRY_HAS_UIKIT

/**
 * When a crash happened the current session is ended as crashed, stored at a different
 * location and the current session is deleted. Checkout SentryHub where most of the session logic
 * is implemented for more details about sessions.
 */
- (void)endCurrentSessionAsCrashedWhenCrashOrWatchdogTermination;

@end
