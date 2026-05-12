#import "SentryInitializeForGettingSubclassesNotCalled.h"
#import <objc/runtime.h>

static BOOL sentryInitializeForGettingSubclassesCalled = NO;

static void
sentryDynamicInitialize(__unused id self, __unused SEL _cmd)
{
    sentryInitializeForGettingSubclassesCalled = YES;
}

@implementation SentryInitializeForGettingSubclassesCalled

+ (nullable NSString *)registerDynamicClass
{
    sentryInitializeForGettingSubclassesCalled = NO;

    NSString *className =
        [NSString stringWithFormat:@"SentryInitializeForGettingSubclassesDynamic_%@",
            [[NSUUID UUID] UUIDString]];
    className = [className stringByReplacingOccurrencesOfString:@"-" withString:@"_"];

    Class dynamicClass = objc_allocateClassPair([NSObject class], [className UTF8String], 0);
    if (dynamicClass == Nil) {
        return nil;
    }

    Class metaClass = object_getClass(dynamicClass);
    BOOL addedInitialize
        = class_addMethod(metaClass, @selector(initialize), (IMP)sentryDynamicInitialize, "v@:");
    if (!addedInitialize) {
        objc_disposeClassPair(dynamicClass);
        return nil;
    }

    objc_registerClassPair(dynamicClass);

    return className;
}

+ (BOOL)wasCalled
{
    return sentryInitializeForGettingSubclassesCalled;
}

@end
