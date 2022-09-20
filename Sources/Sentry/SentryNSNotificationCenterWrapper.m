#import "SentryNSNotificationCenterWrapper.h"
#import "SentryThreadWrapper.h"

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>
#elif TARGET_OS_OSX || TARGET_OS_MACCATALYST
#    import <Cocoa/Cocoa.h>
#endif

@implementation SentryNSNotificationCenterWrapper

+ (NSNotificationName)didBecomeActiveNotificationName
{
#if SENTRY_HAS_UIKIT
    return UIApplicationDidBecomeActiveNotification;
#elif TARGET_OS_OSX || TARGET_OS_MACCATALYST
    return NSApplicationDidBecomeActiveNotification;
#endif
}

+ (NSNotificationName)willResignActiveNotificationName
{
#if SENTRY_HAS_UIKIT
    return UIApplicationWillResignActiveNotification;
#elif TARGET_OS_OSX || TARGET_OS_MACCATALYST
    return NSApplicationWillResignActiveNotification;
#endif
}

+ (NSNotificationName)willTerminateNotificationName
{
#if SENTRY_HAS_UIKIT
    return UIApplicationWillTerminateNotification;
#elif TARGET_OS_OSX || TARGET_OS_MACCATALYST
    return NSApplicationWillTerminateNotification;
#endif
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

- (void)removeObserver:(id)observer
{
    [NSNotificationCenter.defaultCenter removeObserver:observer];
}

@end
