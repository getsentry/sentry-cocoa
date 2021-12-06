#import "CppWrapper.h"
#import "CppSample.hpp"
#import <Foundation/Foundation.h>

@implementation CppWrapper

- (void)throwCPPException
{
    Sentry::CppSample cppTool;
    cppTool.throwCPPException();
}

@end
