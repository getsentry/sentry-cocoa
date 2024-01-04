#import "SentryDefaultObjCRuntimeWrapper.h"
#import <objc/runtime.h>

@implementation SentryDefaultObjCRuntimeWrapper

+ (void)load
{
    NSLog(@"%llu %s", clock_gettime_nsec_np(CLOCK_UPTIME_RAW), __PRETTY_FUNCTION__);
}

+ (instancetype)sharedInstance
{
    static SentryDefaultObjCRuntimeWrapper *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (const char **)copyClassNamesForImage:(const char *)image amount:(unsigned int *)outCount
{
    return objc_copyClassNamesForImage(image, outCount);
}

- (const char *)class_getImageName:(Class)cls
{
    return class_getImageName(cls);
}

@end
