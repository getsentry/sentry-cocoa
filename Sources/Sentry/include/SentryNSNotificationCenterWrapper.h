#import <Foundation/Foundation.h>

/**
 * A wrapper around NSNotificationCenter functions for testability.
 */
@interface SentryNSNotificationCenterWrapper : NSObject

#if SENTRY_HAS_UIKIT
@property (nonatomic, readonly, copy, class) NSNotificationName didBecomeActiveNotificationName;
@property (nonatomic, readonly, copy, class) NSNotificationName willResignActiveNotificationName;
@property (nonatomic, readonly, copy, class) NSNotificationName willTerminateNotificationName;
#elif TARGET_OS_OSX || TARGET_OS_MACCATALYST
@property (nonatomic, readonly, copy, class) NSNotificationName didBecomeActiveNotificationName;
@property (nonatomic, readonly, copy, class) NSNotificationName willResignActiveNotificationName;
@property (nonatomic, readonly, copy, class) NSNotificationName willTerminateNotificationName;
#endif

- (void)addObserver:(id)observer selector:(SEL)aSelector name:(NSNotificationName)aName;

- (void)removeObserver:(id)observer name:(NSNotificationName)aName;

- (void)removeObserver:(id)observer;

@end
