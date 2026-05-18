#import <Foundation/Foundation.h>

/**
 * Helper for SentrySubClassFinderTests.
 *
 * Registers a dynamic Objective-C class whose +initialize only flips an internal flag. The tracked
 * class is created at test runtime so it does not become part of the static SentryTests Mach-O
 * class list.
 */
@interface SentryInitializeForGettingSubclassesCalled : NSObject

+ (nullable NSString *)registerDynamicClass;
+ (BOOL)wasCalled;

@end
