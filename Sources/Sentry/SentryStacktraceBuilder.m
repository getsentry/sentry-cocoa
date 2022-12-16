#import "SentryStacktraceBuilder.h"
#import "SentryCrashStackCursor.h"
#import "SentryCrashStackCursor_MachineContext.h"
#import "SentryCrashStackCursor_SelfThread.h"
#import "SentryCrashStackEntryMapper.h"
#import "SentryFrame.h"
#import "SentryFrameRemover.h"
#import "SentryStacktrace.h"
#import <dlfcn.h>

NS_ASSUME_NONNULL_BEGIN

@interface
SentryStacktraceBuilder ()

@property (nonatomic, strong) SentryCrashStackEntryMapper *crashStackEntryMapper;

@end

@implementation SentryStacktraceBuilder

- (id)initWithCrashStackEntryMapper:(SentryCrashStackEntryMapper *)crashStackEntryMapper
{
    if (self = [super init]) {
        self.crashStackEntryMapper = crashStackEntryMapper;
    }
    return self;
}

- (SentryStacktrace *)retrieveStacktraceFromCursorWithLock:(SentryCrashStackCursor)stackCursor {
    NSMutableArray<SentryFrame *> *frames = [NSMutableArray array];
    SentryFrame *frame = nil;
    while (stackCursor.advanceCursor(&stackCursor)) {
        if (stackCursor.stackEntry.address == SentryCrashSC_ASYNC_MARKER) {
            if (frame != nil) {
                frame.stackStart = @(YES);
            }
            // skip the marker frame
            continue;
        }

        Dl_info info = {0};
        if (dladdr((const void *)stackCursor.stackEntry.address, &info)) {

            stackCursor.stackEntry.imageName = info.dli_fname;
            stackCursor.stackEntry.imageAddress = (uintptr_t)info.dli_fbase;
            stackCursor.stackEntry.symbolName = info.dli_sname;
            stackCursor.stackEntry.symbolAddress = (uintptr_t)info.dli_saddr;

            frame = [self.crashStackEntryMapper mapStackEntryWithCursor:stackCursor];
            [frames addObject:frame];
        }
    }
    sentrycrash_async_backtrace_decref(stackCursor.async_caller);

    NSArray<SentryFrame *> *framesCleared = [SentryFrameRemover removeNonSdkFrames:frames];

    // The frames must be ordered from caller to callee, or oldest to youngest
    NSArray<SentryFrame *> *framesReversed = [[framesCleared reverseObjectEnumerator] allObjects];

    SentryStacktrace *stacktrace = [[SentryStacktrace alloc] initWithFrames:framesReversed
                                                                  registers:@{}];

    return stacktrace;
}

- (SentryStacktrace *)retrieveStacktraceFromCursor:(SentryCrashStackCursor)stackCursor
{
    NSMutableArray<SentryFrame *> *frames = [NSMutableArray new];
    SentryFrame *frame = nil;
    while (stackCursor.advanceCursor(&stackCursor)) {
        if (stackCursor.stackEntry.address == SentryCrashSC_ASYNC_MARKER) {
            if (frame != nil) {
                frame.stackStart = @(YES);
            }
            // skip the marker frame
            continue;
        }
        if (stackCursor.symbolicate(&stackCursor)) {
            frame = [self.crashStackEntryMapper mapStackEntryWithCursor:stackCursor];
            [frames addObject:frame];
        }
    }
    sentrycrash_async_backtrace_decref(stackCursor.async_caller);

    NSArray<SentryFrame *> *framesCleared = [SentryFrameRemover removeNonSdkFrames:frames];

    // The frames must be ordered from caller to callee, or oldest to youngest
    NSArray<SentryFrame *> *framesReversed = [[framesCleared reverseObjectEnumerator] allObjects];

    SentryStacktrace *stacktrace = [[SentryStacktrace alloc] initWithFrames:framesReversed
                                                                  registers:@{}];

    return stacktrace;
}

- (SentryStacktrace *)buildStackTraceFromStackEntries:(SentryCrashStackEntry *)entries
                                               amount:(unsigned int)amount
{
    NSMutableArray<SentryFrame *> *frames = [[NSMutableArray alloc] initWithCapacity:amount];
    SentryFrame *frame = nil;
    for (int i = 0; i < amount; i++) {
        SentryCrashStackEntry stackEntry = entries[i];
        if (stackEntry.address == SentryCrashSC_ASYNC_MARKER) {
            if (frame != nil) {
                frame.stackStart = @(YES);
            }
            // skip the marker frame
            continue;
        }
        frame = [self.crashStackEntryMapper sentryCrashStackEntryToSentryFrame:stackEntry];
        [frames addObject:frame];
    }

    NSArray<SentryFrame *> *framesCleared = [SentryFrameRemover removeNonSdkFrames:frames];

    // The frames must be ordered from caller to callee, or oldest to youngest
    NSArray<SentryFrame *> *framesReversed = [[framesCleared reverseObjectEnumerator] allObjects];

    return [[SentryStacktrace alloc] initWithFrames:framesReversed registers:@{}];
}

- (SentryStacktrace *)buildStacktraceForThread:(SentryCrashThread)thread
                                       context:(struct SentryCrashMachineContext *)context
{
    sentrycrashmc_getContextForThread(thread, context, false);
    SentryCrashStackCursor stackCursor;
    sentrycrashsc_initWithMachineContext(&stackCursor, MAX_STACKTRACE_LENGTH, context);

    return [self retrieveStacktraceFromCursor:stackCursor];
}

- (SentryStacktrace *)buildStacktraceForCurrentThread
{
    SentryCrashStackCursor stackCursor;
    // We don't need to skip any frames, because we filter out non sentry frames below.
    NSInteger framesToSkip = 0;
    sentrycrashsc_initSelfThread(&stackCursor, (int)framesToSkip);

    return [self retrieveStacktraceFromCursor:stackCursor];
}

- (SentryStacktrace *)buildStacktraceForCurrentThreadOnlyInstAddresses {
    SentryCrashStackCursor stackCursor;

    sentrycrashsc_initSelfThread(&stackCursor, 0);

    return [self retrieveStacktraceFromCursor:stackCursor];
}


@end

NS_ASSUME_NONNULL_END
