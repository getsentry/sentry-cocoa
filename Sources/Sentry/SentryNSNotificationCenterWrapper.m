#import "SentryNSNotificationCenterWrapper.h"
#import "SentryThreadWrapper.h"

@implementation SentryNSNotificationCenterWrapper

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
