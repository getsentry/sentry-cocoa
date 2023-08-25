#import "SentryClassRegistrator.h"
#import <objc/runtime.h>

@implementation SentryClassRegistrator

+ (void)registerClass:(NSString *)name
{
    Class c = objc_allocateClassPair(
        [NSObject class], [name cStringUsingEncoding:NSUTF8StringEncoding], 0);

    objc_registerClassPair(c);
}

+ (void)unregisterClass:(NSString *)name
{
    Class c = NSClassFromString(name);
    if (c) {
        objc_disposeClassPair(c);
    }
}

@end
