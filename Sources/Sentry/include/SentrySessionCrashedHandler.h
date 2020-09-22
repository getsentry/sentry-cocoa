#import <Foundation/Foundation.h>

@class SentryCrashAdapter, SentryDispatchQueueWrapper;

@interface SentrySessionCrashedHandler : NSObject

- (instancetype)initWithCrashWrapper:(SentryCrashAdapter *)crashWrapper;

/**
 * When a crash happened the current session is marked as crashed, stored at a different
 * location and the current session is deleted. Checkout SentryHub where most of the session logic
 * is implemented for more details about sessions.
 */
- (void)storeCrashedSession;

@end
