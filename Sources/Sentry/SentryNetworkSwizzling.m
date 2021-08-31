#import "SentryNetworkSwizzling.h"
#import "SentryNetworkTracker.h"
#import "SentrySwizzle.h"
#import <objc/runtime.h>

@implementation SentryNetworkSwizzling

+ (void)start
{
    [SentryNetworkTracker.sharedInstance enable];
    [self swizzleURLSessionTaskResume];
    [self swizzleNSURLSessionConfiguration];
}

+ (void)stop
{
    [SentryNetworkTracker.sharedInstance disable];
}

// SentrySwizzleInstanceMethod declaration shadows a local variable. The swizzling is working
// fine and we accept this warning.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wshadow"

+ (void)swizzleURLSessionTaskResume
{
    SEL selector = NSSelectorFromString(@"resume");
    SentrySwizzleInstanceMethod(NSURLSessionTask.class, selector, SentrySWReturnType(void),
        SentrySWArguments(), SentrySWReplacement({
            [SentryNetworkTracker.sharedInstance urlSessionTaskResume:self];
            SentrySWCallOriginal();
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, (void *)selector);
}

+ (void)swizzleNSURLSessionConfiguration
{
    // iOS 13 doesn't have a method for HTTPAdditionalHeaders. Instead, it only has a property.
    // Therefore, we need to make sure that NSURLSessionConfiguration has this method to be able to
    // swizzle it. Otherwise, we would crash. Cause we can't swizzle properties currently, we only
    // swizzle when the method is available.
    SEL selector = NSSelectorFromString(@"HTTPAdditionalHeaders");
    Class classToSwizzle = NSURLSessionConfiguration.class;
    Method method = class_getInstanceMethod(classToSwizzle, selector);

    if (method != nil) {
        SentrySwizzleInstanceMethod(classToSwizzle, selector, SentrySWReturnType(NSDictionary *),
            SentrySWArguments(), SentrySWReplacement({
                return [SentryNetworkTracker.sharedInstance addTraceHeader:SentrySWCallOriginal()];
            }),
            SentrySwizzleModeOncePerClassAndSuperclasses, (void *)selector);
    }
}

#pragma clang diagnostic pop
@end
