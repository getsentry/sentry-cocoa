#import "SentryNetworkSwizzling.h"
#import "SentryNetworkTracker.h"
#import "SentrySwizzle.h"
#import <SentryLog.h>
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
    Class class = NSURLSessionConfiguration.class;

    SEL selector = NSSelectorFromString(@"HTTPAdditionalHeaders");
    Method method = class_getInstanceMethod(class, selector);

    // The HTTPAdditionalHeaders is only an instance method for NSURLSessionConfiguration on
    // iOS/tvOS 8.x, 14.x, and 15.x. On the other OS versions we can swizzle
    // __NSCFURLSessionConfiguration instead. We can't only swizzle __NSCFURLSessionConfiguration
    // though, because it doesn't exist on on iOS/tvOS 8.x, 14.x, and 15. See
    // https://developer.limneos.net/index.php?ios=14.4&framework=CFNetwork.framework&header=NSURLSessionConfiguration.h
    // and
    // https://developer.limneos.net/index.php?ios=13.1.3&framework=CFNetwork.framework&header=__NSCFURLSessionConfiguration.h.
    if (method == nil) {
        class = NSClassFromString(@"__NSCFURLSessionConfiguration");
    }

    if (class == nil) {
        [SentryLog
            logWithMessage:@"SentryNetworkSwizzling: Can't find __NSCFURLSessionConfiguration. "
                           @"Won't add Sentry Trace HTTP headers."
                  andLevel:kSentryLevelWarning];
        return;
    }

    method = class_getInstanceMethod(class, selector);

    if (method == nil) {
        [SentryLog logWithMessage:@"SentryNetworkSwizzling: Both NSURLSessionConfiguration and "
                                  @"__NSCFURLSessionConfiguration don't have "
                                  @"HTTPAdditionalHeaders. Won't add Sentry Trace HTTP headers."
                         andLevel:kSentryLevelWarning];
        return;
    }

    SentrySwizzleInstanceMethod(class, selector, SentrySWReturnType(NSDictionary *),
        SentrySWArguments(), SentrySWReplacement({
            return [SentryNetworkTracker.sharedInstance addTraceHeader:SentrySWCallOriginal()];
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, (void *)selector);
}

#pragma clang diagnostic pop
@end
