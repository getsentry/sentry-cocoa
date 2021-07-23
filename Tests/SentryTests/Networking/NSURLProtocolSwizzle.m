#import "NSURLProtocolSwizzle.h"
#import "SentrySwizzle.h"

@implementation NSURLProtocolSwizzle

+ (NSURLProtocolSwizzle *)shared
{
    static NSURLProtocolSwizzle *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

+ (void)swizzleURLProtocol
{
    SentrySwizzleClassMethod(NSURLProtocol.class, NSSelectorFromString(@"registerClass:"),
        SentrySWReturnType(BOOL), SentrySWArguments(Class class), SentrySWReplacement({
            if (NSURLProtocolSwizzle.shared.registerCallback != nil)
                NSURLProtocolSwizzle.shared.registerCallback(class);

            return SentrySWCallOriginal(class);
        }));

    SentrySwizzleClassMethod(NSURLProtocol.class, NSSelectorFromString(@"unregisterClass:"),
        SentrySWReturnType(void), SentrySWArguments(Class class), SentrySWReplacement({
            if (NSURLProtocolSwizzle.shared.unregisterCallback != nil)
                NSURLProtocolSwizzle.shared.unregisterCallback(class);

            SentrySWCallOriginal(class);
        }));
}

@end
