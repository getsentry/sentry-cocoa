#import "CppWrapper.h"
#import "CppSample.hpp"
#import <Foundation/Foundation.h>

@implementation CppWrapper

- (void)throwCPPException
{
    Sentry::CppSample cppTool;
    cppTool.throwCPPException();
}

- (void)rethrowNoActiveCPPException
{
    Sentry::CppSample cppTool;
    cppTool.rethrowNoActiveCPPException();
}

@end
