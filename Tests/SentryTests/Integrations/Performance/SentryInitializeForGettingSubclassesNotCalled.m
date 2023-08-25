#import "SentryInitializeForGettingSubclassesNotCalled.h"

@implementation SentryInitializeForGettingSubclassesNotCalled

+ (void)initialize
{
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
