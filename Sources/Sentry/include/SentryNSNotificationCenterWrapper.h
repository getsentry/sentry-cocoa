#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * A wrapper around NSNotificationCenter functions for testability.
 */
@interface SentryNSNotificationCenterWrapper : NSObject

#if SENTRY_HAS_UIKIT || TARGET_OS_OSX || TARGET_OS_MACCATALYST
@property (nonatomic, readonly, copy, class) NSNotificationName didBecomeActiveNotificationName;
@property (nonatomic, readonly, copy, class) NSNotificationName willResignActiveNotificationName;
@property (nonatomic, readonly, copy, class) NSNotificationName willTerminateNotificationName;
#endif

- (void)addObserver:(id)observer selector:(SEL)aSelector name:(NSNotificationName)aName;

- (void)removeObserver:(id)observer name:(NSNotificationName)aName;

- (void)removeObserver:(id)observer;

NS_ASSUME_NONNULL_END

@end
