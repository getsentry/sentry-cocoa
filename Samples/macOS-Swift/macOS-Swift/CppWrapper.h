#import <Foundation/Foundation.h>

@interface CppWrapper : NSObject
- (void)throwCPPException;
- (void)rethrowNoActiveCPPException;
@end
