#import <Foundation/Foundation.h>

static BOOL _SentryInitializeForGettingSubclassesCalled = NO;

/**
 * Be aware that the initializer of a class is only called once during the lifetime of an
 * application. Therefore use this only in one test only.
 */
@interface SentryInitializeForGettingSubclassesNotCalled : NSObject

@end

/**
 * Getting the value of _SentryInitializeForGettingSubclassesCalled is not working in Swift. Adding
 * wasCalled to SentryInitializeForGettingSubclassesNotCalled would call the initializer. Hence, we
 * use another class to check if the initializer was called.
 */
@interface SentryInitializeForGettingSubclassesCalled : NSObject

+ (BOOL)wasCalled;

@end
