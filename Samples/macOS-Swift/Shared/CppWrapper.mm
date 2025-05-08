#import "CppWrapper.h"
#import "CppSample.hpp"
#import <Foundation/Foundation.h>

@implementation CppWrapper

- (void)throwCPPException
{
    Sentry::CppSample cppTool;
    cppTool.throwCPPException();
}

- (void)noExceptCppException
{
    Sentry::CppSample cppTool;
    cppTool.noExceptCppException();
}

- (void)rethrowNoActiveCPPException
{
    Sentry::CppSample cppTool;
    cppTool.rethrowNoActiveCPPException();
}

- (void)throwNSRangeException
{
    NSArray *array = [NSArray array];
    NSLog(@"%@", array[9]);
}

@end
