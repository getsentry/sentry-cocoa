#import "SentryCrashDefaultMachineContextWrapper.h"
#import "SentryCrashDynamicLinker.h"
#import "KSMachineContext.h"
#import "SentryCrashMachineContextWrapper.h"
#import "SentryCrashStackCursor.h"
#import "SentryCrashStackCursor_SelfThread.h"
#import "SentryCrashThread.h"
#import "SentryFormatter.h"
#import "SentryFrame.h"
#import "SentryStacktrace.h"
#import "SentryStacktraceBuilder.h"
#import "SentryThread.h"
#import <Foundation/Foundation.h>
#include <execinfo.h>
#include <pthread.h>

NS_ASSUME_NONNULL_BEGIN

KSThread mainThreadID;

@implementation SentryCrashDefaultMachineContextWrapper

+ (void)load
{
    mainThreadID = pthread_mach_thread_np(pthread_self());
}

- (void)fillContextForCurrentThread:(KSMachineContext *)context
{
    ksmc_getContextForThread(sentrycrashthread_self(), context, YES);
}

- (int)getThreadCount:(KSMachineContext *)context
{
    return ksmc_getThreadCount(context);
}

- (KSThread)getThread:(KSMachineContext *)context withIndex:(int)index
{
    KSThread thread = ksmc_getThreadAtIndex(context, index);
    return thread;
}

- (BOOL)getThreadName:(const KSThread)thread
            andBuffer:(char *const)buffer
         andBufLength:(int)bufLength;
{
    return sentrycrashthread_getThreadName(thread, buffer, bufLength) == true;
}

- (BOOL)isMainThread:(KSThread)thread
{
    return thread == mainThreadID;
}

@end

NS_ASSUME_NONNULL_END
