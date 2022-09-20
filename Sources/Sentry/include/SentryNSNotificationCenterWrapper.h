#import <Foundation/Foundation.h>

/**
 * A wrapper around NSNotificationCenter functions for testability.
 */
@interface SentryNSNotificationCenterWrapper : NSObject

- (void)addObserver:(id)observer selector:(SEL)aSelector name:(NSNotificationName)aName;

- (void)removeObserver:(id)observer name:(NSNotificationName)aName;

- (void)removeObserver:(id)observer;

@end
