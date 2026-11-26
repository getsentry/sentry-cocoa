#import "CppWrapper.h"
#import "CppCode.hpp"
#import <Foundation/Foundation.h>

@implementation CppWrapper

- (void)throwCPPException
{
    Sentry::CppCode cpp;
    cpp.throwCPPException();
}

@end
