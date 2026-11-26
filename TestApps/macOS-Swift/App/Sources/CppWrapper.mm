#import "CppWrapper.h"
#import "CppSample.hpp"
#import <Foundation/Foundation.h>

namespace {
using NullFunctionPointer = void (*)(void);

__attribute__((noinline)) void
callNullFunctionPointer(void)
{
    volatile uintptr_t address = 0;
    auto function = reinterpret_cast<NullFunctionPointer>(address);
    function();
}
} // namespace

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

- (void)crashWithNullProgramCounter
{
    callNullFunctionPointer();
}

@end
