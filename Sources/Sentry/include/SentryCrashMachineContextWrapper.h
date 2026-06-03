#import "KSMachineContext.h"
#import "SentryCrashThread.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/** A wrapper around SentryCrashMachineContext for testability.
 */
@protocol SentryCrashMachineContextWrapper <NSObject>

- (void)fillContextForCurrentThread:(KSMachineContext *)context;

- (int)getThreadCount:(KSMachineContext *)context;

- (KSThread)getThread:(KSMachineContext *)context withIndex:(int)index;

- (BOOL)getThreadName:(const KSThread)thread
            andBuffer:(char *const)buffer
         andBufLength:(int)bufLength;

- (BOOL)isMainThread:(KSThread)thread;

@end

NS_ASSUME_NONNULL_END
