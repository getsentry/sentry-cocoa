#import <Foundation/Foundation.h>

@class SentryCrashWrapper, SentryDispatchQueueWrapper, SentryWatchDogTerminationsLogic;

@interface SentrySessionCrashedHandler : NSObject

- (instancetype)initWithCrashWrapper:(SentryCrashWrapper *)crashWrapper
           watchDogTerminationsLogic:(SentryWatchDogTerminationsLogic *)watchDogTerminationsLogic;

/**
 * When a crash happened the current session is ended as crashed, stored at a different
 * location and the current session is deleted. Checkout SentryHub where most of the session logic
 * is implemented for more details about sessions.
 */
- (void)endCurrentSessionAsCrashedWhenCrashOrOOM;

@end
