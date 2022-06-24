#import "SentryThreadInspector.h"
#import "SentryCrashStackCursor.h"
#include "SentryCrashStackCursor_MachineContext.h"
#include "SentryCrashSymbolicator.h"
#import "SentryFrame.h"
#import "SentryStacktrace.h"
#import "SentryStacktraceBuilder.h"
#import "SentryThread.h"
#include <pthread.h>

@interface
SentryThreadInspector ()

@property (nonatomic, strong) SentryStacktraceBuilder *stacktraceBuilder;
@property (nonatomic, strong) id<SentryCrashMachineContextWrapper> machineContextWrapper;

@end

typedef struct {
    SentryCrashThread thread;
    SentryCrashStackEntry stackEntries[100];
    int stackLength;
} ThreadInfo;

// We need a C function to retrieve information from the stack trace in order to avoid
// calling into async code while there is suspended threads.
unsigned int
getStackEntriesFromThread(SentryCrashThread thread, struct SentryCrashMachineContext *context,
    SentryCrashStackEntry *buffer, unsigned int amount)
{
    sentrycrashmc_getContextForThread(thread, context, false);
    SentryCrashStackCursor stackCursor;
    sentrycrashsc_initWithMachineContext(&stackCursor, 100, context);

    unsigned int result = 0;
    while (stackCursor.advanceCursor(&stackCursor)) {
        if (result == amount)
            break;
        if (stackCursor.symbolicate(&stackCursor)) {
            buffer[result] = stackCursor.stackEntry;
            result++;
        }
    }
    sentrycrash_async_backtrace_decref(stackCursor.async_caller);

    return result;
}

@implementation SentryThreadInspector

- (id)initWithStacktraceBuilder:(SentryStacktraceBuilder *)stacktraceBuilder
       andMachineContextWrapper:(id<SentryCrashMachineContextWrapper>)machineContextWrapper
{
    if (self = [super init]) {
        self.stacktraceBuilder = stacktraceBuilder;
        self.machineContextWrapper = machineContextWrapper;
    }
    return self;
}

- (NSArray<SentryThread *> *)getCurrentThreads
{
    NSMutableArray<SentryThread *> *threads = [NSMutableArray new];

    @synchronized(self) {
        SentryCrashMC_NEW_CONTEXT(context);
        SentryCrashThread currentThread = sentrycrashthread_self();

        [self.machineContextWrapper fillContextForCurrentThread:context];
        int threadCount = [self.machineContextWrapper getThreadCount:context];

        for (int i = 0; i < threadCount; i++) {
            SentryCrashThread thread = [self.machineContextWrapper getThread:context withIndex:i];
            SentryThread *sentryThread = [[SentryThread alloc] initWithThreadId:@(i)];

            sentryThread.name = [self getThreadName:thread];

            sentryThread.crashed = @NO;
            bool isCurrent = thread == currentThread;
            sentryThread.current = @(isCurrent);

            if (isCurrent) {
                sentryThread.stacktrace = [self.stacktraceBuilder buildStacktraceForCurrentThread];
            }

            // We need to make sure the main thread is always the first thread in the result
            if ([self.machineContextWrapper isMainThread:thread])
                [threads insertObject:sentryThread atIndex:0];
            else
                [threads addObject:sentryThread];
        }
    }

    return threads;
}

- (NSArray<SentryThread *> *)getCurrentThreadsWithStackTrace
{
    NSMutableArray<SentryThread *> *threads = [NSMutableArray new];

    @synchronized(self) {
        SentryCrashMC_NEW_CONTEXT(context);
        SentryCrashThread currentThread = sentrycrashthread_self();

        thread_act_array_t suspendedThreads = nil;
        mach_msg_type_number_t numSuspendedThreads = 0;

        sentrycrashmc_suspendEnvironment(&suspendedThreads, &numSuspendedThreads);

        ThreadInfo threadsInfos[numSuspendedThreads];

        for (int i = 0; i < numSuspendedThreads; i++) {
            if (suspendedThreads[i] != currentThread) {
                int numberOfEntries = getStackEntriesFromThread(
                    suspendedThreads[i], context, threadsInfos[i].stackEntries, 100);
                threadsInfos[i].stackLength = numberOfEntries;
            } else {
                threadsInfos[i].stackLength = 0;
            }
            threadsInfos[i].thread = suspendedThreads[i];
        }

        sentrycrashmc_resumeEnvironment(suspendedThreads, numSuspendedThreads);

        for (int i = 0; i < numSuspendedThreads; i++) {
            SentryThread *sentryThread = [[SentryThread alloc] initWithThreadId:@(i)];

            sentryThread.name = [self getThreadName:threadsInfos[i].thread];

            sentryThread.crashed = @NO;
            bool isCurrent = threadsInfos[i].thread == currentThread;
            sentryThread.current = @(isCurrent);

            if (isCurrent) {
                sentryThread.stacktrace = [self.stacktraceBuilder buildStacktraceForCurrentThread];
            } else {
                sentryThread.stacktrace = [self.stacktraceBuilder
                    buildStackTraceFromStackEntries:threadsInfos[i].stackEntries
                                             amount:threadsInfos[i].stackLength];
            }

            // We need to make sure the main thread is always the first thread in the result
            if ([self.machineContextWrapper isMainThread:threadsInfos[i].thread])
                [threads insertObject:sentryThread atIndex:0];
            else
                [threads addObject:sentryThread];
        }
    }

    return threads;
}

- (NSString *)getThreadName:(SentryCrashThread)thread
{
    char buffer[128];
    char *const pBuffer = buffer;
    [self.machineContextWrapper getThreadName:thread andBuffer:pBuffer andBufLength:128];

    NSString *threadName = [NSString stringWithCString:pBuffer encoding:NSUTF8StringEncoding];
    if (nil == threadName) {
        threadName = @"";
    }
    return threadName;
}

@end
