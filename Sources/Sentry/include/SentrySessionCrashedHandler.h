#import "SentryDefines.h"
#import <Foundation/Foundation.h>

@class SentryCrashWrapper, SentryDispatchQueueWrapper;
#if UIKIT_LINKED
@class SentryWatchdogTerminationLogic;
#endif // UIKIT_LINKED

@interface SentrySessionCrashedHandler : NSObject

#if UIKIT_LINKED
- (instancetype)initWithCrashWrapper:(SentryCrashWrapper *)crashWrapper
            watchdogTerminationLogic:(SentryWatchdogTerminationLogic *)watchdogTerminationLogic;
#else
- (instancetype)initWithCrashWrapper:(SentryCrashWrapper *)crashWrapper;
#endif // UIKIT_LINKED

/**
 * When a crash happened the current session is ended as crashed, stored at a different
 * location and the current session is deleted. Checkout SentryHub where most of the session logic
 * is implemented for more details about sessions.
 */
- (void)endCurrentSessionAsCrashedWhenCrashOrOOM;

@end
