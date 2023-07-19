#import "SentryNSNotificationCenterWrapper.h"

#import "SentryDefines.h"

#if TARGET_OS_OSX || TARGET_OS_MACCATALYST
#    import <Cocoa/Cocoa.h>
#endif

NS_ASSUME_NONNULL_BEGIN

@implementation SentryNSNotificationCenterWrapper

#if SENTRY_HAS_UIKIT
+ (NSNotificationName)didBecomeActiveNotificationName
{
    return SENTRY_UIApplicationDidBecomeActiveNotification;
}

+ (NSNotificationName)willResignActiveNotificationName
{
    return SENTRY_UIApplicationWillResignActiveNotification;
}

+ (NSNotificationName)willTerminateNotificationName
{
    return SENTRY_UIApplicationWillTerminateNotification;
}

#elif TARGET_OS_OSX || TARGET_OS_MACCATALYST
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
