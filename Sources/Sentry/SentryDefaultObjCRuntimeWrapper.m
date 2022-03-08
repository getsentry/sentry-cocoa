#import "SentryDefaultObjCRuntimeWrapper.h"
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

@implementation SentryDefaultObjCRuntimeWrapper

- (const char **)copyClassNamesForImage:(const char *)image amount:(unsigned int *)outCount
{
    return objc_copyClassNamesForImage(image, outCount);
}

@end
