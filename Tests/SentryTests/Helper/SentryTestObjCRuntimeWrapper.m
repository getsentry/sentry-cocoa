#import "SentryTestObjCRuntimeWrapper.h"
#import "SentryDefaultObjCRuntimeWrapper.h"
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

@interface
SentryTestObjCRuntimeWrapper ()

@property (nonatomic, strong) SentryDefaultObjCRuntimeWrapper *objcRuntimeWrapper;

@end

@implementation SentryTestObjCRuntimeWrapper

- (instancetype)init
{
    if (self = [super init]) {
        self.objcRuntimeWrapper = [[SentryDefaultObjCRuntimeWrapper alloc] init];
    }

    return self;
}

- (int)getClassList:(__unsafe_unretained Class *)buffer bufferCount:(int)bufferCount
{
    if (self.beforeGetClassList != nil) {
        self.beforeGetClassList();
    }
    int numClasses = [self.objcRuntimeWrapper getClassList:buffer bufferCount:bufferCount];

    if (self.numClasses != nil) {
        numClasses = self.numClasses(numClasses);
    }

    if (self.afterGetClassList != nil) {
        self.afterGetClassList();
    }

    return numClasses;
}

- (const char **)copyClassNamesForImage:(const char *)image amount:(unsigned int *)outCount
{
    if (self.beforeGetClassList != nil) {
        self.beforeGetClassList();
    }
    const char **result = [self.objcRuntimeWrapper copyClassNamesForImage:image amount:outCount];

    if (self.classesNames != nil) {
        NSMutableArray *names = [NSMutableArray new];
        for (unsigned int i = 0; i < *outCount; i++) {
            [names addObject:[NSString stringWithCString:result[i] encoding:NSUTF8StringEncoding]];
        }

        NSArray<NSString *> *newNames = self.classesNames(names);
        free(result);

        result = malloc(sizeof(char *) * newNames.count);
        for (NSUInteger i = 0; i < newNames.count; i++) {
            result[i] = [newNames[i] cStringUsingEncoding:NSUTF8StringEncoding];
        }
        *outCount = (unsigned int)newNames.count;
    }

    if (self.afterGetClassList != nil) {
        self.afterGetClassList();
    }

    return result;
}

- (void)countIterateClasses
{
    self.iterateClassesInvocations++;
}

@end
