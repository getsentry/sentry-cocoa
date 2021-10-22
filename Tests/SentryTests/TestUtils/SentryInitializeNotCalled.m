#import "SentryInitializeNotCalled.h"
#import <Foundation/Foundation.h>

@implementation SentryInitializeNotCalled

+ (void)initialize
{
    if (self == [SentryInitializeNotCalled self]) {
        SentryInitializerCalled = YES;
    }
}

+ (BOOL)wasInitializerCalled
{
    return SentryInitializerCalled;
}

+ (void)resetWasInitializerCalled
{
    SentryInitializerCalled = NO;
}

@end
