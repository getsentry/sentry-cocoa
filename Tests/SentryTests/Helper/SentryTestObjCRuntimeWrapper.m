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
    return [self.objcRuntimeWrapper getClassList:buffer bufferCount:bufferCount];
}

@end
