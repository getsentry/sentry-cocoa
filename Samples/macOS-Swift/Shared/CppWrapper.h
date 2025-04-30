#import <Foundation/Foundation.h>

@interface CppWrapper : NSObject
- (void)throwCPPException;
- (void)rethrowNoActiveCPPException;
- (void)throwNSRangeException;
@end
