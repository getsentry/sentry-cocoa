#import "NoARCCrash.h"
#import <Foundation/Foundation.h>

void
callMessageOnDeallocatedObject(void)
{
    NSObject *obj = [[NSObject alloc] init];
    [obj release]; // Manually releasing in MRC, making `obj` a dangling pointer
    [obj description]; // Sending a message to a deallocated object causes a SIGSEGV
}
