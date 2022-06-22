#import "SentryThreadInspector.h"
#import "SentryFrame.h"
#import "SentryStacktrace.h"
#import "SentryStacktraceBuilder.h"
#import "SentryThread.h"
#import "SentryCrashStackCursor.h"
#include <pthread.h>
#import "SentryBacktrace.hpp"
#include "SentryThreadMetadataCache.hpp"

@interface
SentryThreadInspector ()

@property (nonatomic, strong) SentryStacktraceBuilder *stacktraceBuilder;
@property (nonatomic, strong) id<SentryCrashMachineContextWrapper> machineContextWrapper;

@end

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
    return [self getCurrentThreadsWithStackTrace:NO];
}

- (NSArray<SentryThread *> *)getCurrentThreadsWithStackTrace:(BOOL)getAllStacktraces
{
    NSMutableArray<SentryThread *> *threads = [NSMutableArray new];
    
    @synchronized(self) {
        SentryCrashMC_NEW_CONTEXT(context);
        [self.machineContextWrapper fillContextForCurrentThread:context];
        int threadCount = [self.machineContextWrapper getThreadCount:context];

        SentryCrashThread currentThread = sentrycrashthread_self();
        
        const auto cache = std::make_shared<sentry::profiling::ThreadMetadataCache>();
        sentry::profiling::enumerateBacktracesForAllThreads([&](auto &backtrace) {
            
        }, cache);
        
        thread_act_array_t suspendedThreads = nil;
        mach_msg_type_number_t numSuspendedThreads = 0;
        
        SentryCrashStackEntry stackEntries[threadCount][100];
        int entriesPerThread[threadCount];
        
        if (getAllStacktraces) {
            sentrycrashmc_suspendEnvironment(&suspendedThreads, &numSuspendedThreads);
            
            for (int i = 0 ; i<numSuspendedThreads; i++) {
                if (suspendedThreads[i] != currentThread) {
                    int numberOfEntries = [self.stacktraceBuilder getStackEntriesFromThread:suspendedThreads[i] context:context buffer:stackEntries[i] maxEntries:100];
                    entriesPerThread[i] = numberOfEntries;
                } else {
                    entriesPerThread[i] = 0;
                }
            }
            
            sentrycrashmc_resumeEnvironment(suspendedThreads, numSuspendedThreads);
        }
        
        [self.machineContextWrapper fillContextForCurrentThread:context];
        threadCount = [self.machineContextWrapper getThreadCount:context];
        
        for (int i = 0; i < threadCount; i++) {
            SentryCrashThread thread = [self.machineContextWrapper getThread:context withIndex:i];
            if (thread == 0) {
                NSLog(@"INVALID THREAD");
                continue;
            }
            SentryThread *sentryThread = [[SentryThread alloc] initWithThreadId:@(i)];

            sentryThread.name = [self getThreadName:thread];

            sentryThread.crashed = @NO;
            bool isCurrent = thread == currentThread;
            sentryThread.current = @(isCurrent);

            if (isCurrent) {
                sentryThread.stacktrace = [self.stacktraceBuilder buildStacktraceForCurrentThread];
            } else if (getAllStacktraces) {
                sentryThread.stacktrace = [self.stacktraceBuilder buildStackTraceFromStackEntries:stackEntries[i] amount:entriesPerThread[i]];
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
