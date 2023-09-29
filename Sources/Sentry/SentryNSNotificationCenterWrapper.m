#import "SentryNSNotificationCenterWrapper.h"

#import "SentryDefines.h"

#if SENTRY_TARGET_MACOS
#    import <Cocoa/Cocoa.h>
#endif

#if UIKIT_LINKED
#    import <UIKit/UIKit.h>
#endif // UIKIT_LINKED

NS_ASSUME_NONNULL_BEGIN

@implementation SentryNSNotificationCenterWrapper

#if UIKIT_LINKED
+ (NSNotificationName)didBecomeActiveNotificationName
{
    return UIApplicationDidBecomeActiveNotification;
}

+ (NSNotificationName)willResignActiveNotificationName
{
    return UIApplicationWillResignActiveNotification;
}

+ (NSNotificationName)willTerminateNotificationName
{
    return UIApplicationWillTerminateNotification;
}

#elif SENTRY_TARGET_MACOS
+ (NSNotificationName)didBecomeActiveNotificationName
{
    return NSApplicationDidBecomeActiveNotification;
}

+ (NSNotificationName)willResignActiveNotificationName
{
    return NSApplicationWillResignActiveNotification;
}

+ (NSNotificationName)willTerminateNotificationName
{
    return NSApplicationWillTerminateNotification;
}
#endif

- (void)addObserver:(id)observer
           selector:(SEL)aSelector
               name:(NSNotificationName)aName
             object:(nullable id)anObject
{
    [NSNotificationCenter.defaultCenter addObserver:observer
                                           selector:aSelector
                                               name:aName
                                             object:anObject];
}

- (void)addObserver:(id)observer selector:(SEL)aSelector name:(NSNotificationName)aName
{
    [NSNotificationCenter.defaultCenter addObserver:observer
                                           selector:aSelector
                                               name:aName
                                             object:nil];
}

- (void)removeObserver:(id)observer name:(NSNotificationName)aName
{
    [NSNotificationCenter.defaultCenter removeObserver:observer name:aName object:nil];
}

- (void)removeObserver:(id)observer name:(NSNotificationName)aName object:(nullable id)anObject
{
    [NSNotificationCenter.defaultCenter removeObserver:observer name:aName object:anObject];
}

- (void)removeObserver:(id)observer
{
    [NSNotificationCenter.defaultCenter removeObserver:observer];
}

- (void)postNotificationName:(NSNotificationName)aName object:(nullable id)anObject
{
    [NSNotificationCenter.defaultCenter postNotificationName:aName object:anObject];
}

@end

NS_ASSUME_NONNULL_END
