#import <Foundation/Foundation.h>

@interface CppWrapper : NSObject
- (void)throwCPPException;
- (void)noExceptCppException;
- (void)rethrowNoActiveCPPException;
- (void)throwNSRangeException;
- (void)crashWithNullProgramCounter;
@end
