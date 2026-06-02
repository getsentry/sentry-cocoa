#import "SentryCrashMachineContext.h"
#import "SentryCrashThread.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/** A wrapper around SentryCrashMachineContext for testability.
 */
@protocol SentryCrashMachineContextWrapper <NSObject>

- (void)fillContextForCurrentThread:(SentryCrashMachineContext *)context;

- (int)getThreadCount:(SentryCrashMachineContext *)context;

- (KSThread)getThread:(SentryCrashMachineContext *)context withIndex:(int)index;

- (BOOL)getThreadName:(const KSThread)thread
            andBuffer:(char *const)buffer
         andBufLength:(int)bufLength;

- (BOOL)isMainThread:(KSThread)thread;

@end

NS_ASSUME_NONNULL_END
