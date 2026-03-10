#import "SentryInitializeForGettingSubclassesNotCalled.h"
#import <Foundation/Foundation.h>

@implementation SentryInitializeForGettingSubclassesNotCalled

+ (void)initialize
{
    NSAssert(false, @"This class should never be initialized");
    if (self == [SentryInitializeForGettingSubclassesNotCalled self]) {
        _SentryInitializeForGettingSubclassesCalled = YES;
    }
}

@end

@implementation SentryInitializeForGettingSubclassesCalled : NSObject

+ (BOOL)wasCalled
{
    return _SentryInitializeForGettingSubclassesCalled;
}

@end
