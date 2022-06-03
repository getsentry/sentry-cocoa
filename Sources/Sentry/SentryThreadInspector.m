#import "SentryThreadInspector.h"
#import "SentryFrame.h"
#import "SentryStacktrace.h"
#import "SentryStacktraceBuilder.h"
#import "SentryThread.h"

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

- (NSArray<SentryThread *> *)getCurrentThreadsWithStackTrace:(BOOL)forceStackTraces
{
    NSMutableArray<SentryThread *> *threads = [NSMutableArray new];

    SentryCrashMC_NEW_CONTEXT(context);
    [self.machineContextWrapper fillContextForCurrentThread:context];

    int threadCount = [self.machineContextWrapper getThreadCount:context];

    thread_act_array_t suspendedThreads = nil;
    mach_msg_type_number_t numSuspendedThreads = 0;
    if (forceStackTraces) {
        sentrycrashmc_suspendEnvironment(&suspendedThreads, &numSuspendedThreads);
    }

    for (int i = 0; i < threadCount; i++) {
        SentryCrashThread thread = [self.machineContextWrapper getThread:context withIndex:i];
        SentryThread *sentryThread = [[SentryThread alloc] initWithThreadId:@(i)];

        sentryThread.name = [self getThreadName:thread];

        sentryThread.crashed = @NO;
        bool isCurrent = thread == sentrycrashthread_self();
        sentryThread.current = @(isCurrent);

        // For now we can only retrieve the stack trace of the current thread.
        if (isCurrent) {
            sentryThread.stacktrace = [self.stacktraceBuilder buildStacktraceForCurrentThread];
        } else if (forceStackTraces) {
            sentryThread.stacktrace = [self.stacktraceBuilder buildStacktraceForThread:thread];
        }

        [threads addObject:sentryThread];
    }

    if (numSuspendedThreads > 0) {
        sentrycrashmc_resumeEnvironment(suspendedThreads, numSuspendedThreads);
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
