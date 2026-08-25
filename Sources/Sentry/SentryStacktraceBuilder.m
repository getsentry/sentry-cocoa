#import "SentryStacktraceBuilder.h"
#import "SentryCrashStackCursor.h"
#import "SentryCrashStackCursor_MachineContext.h"
#if !SDK_V10
#    import "SentryCrashStackCursor_SelfThread.h"
#endif
#import "SentryCrashStackEntryMapper.h"
#import "SentryFrame.h"
#import "SentryLogC.h"
#import "SentryStacktrace.h"
#import "SentrySwift.h"
#import <dlfcn.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryStacktraceBuilder ()

@property (nonatomic, strong) SentryCrashStackEntryMapper *crashStackEntryMapper;
#if SDK_V10
@property (nonatomic, strong) SentryKSCrashCurrentThreadStackProvider *currentThreadStackProvider;
#endif

@end

@implementation SentryStacktraceBuilder

- (id)initWithCrashStackEntryMapper:(SentryCrashStackEntryMapper *)crashStackEntryMapper
{
    if (self = [super init]) {
        self.crashStackEntryMapper = crashStackEntryMapper;
#if SDK_V10
        self.currentThreadStackProvider = [[SentryKSCrashCurrentThreadStackProvider alloc] init];
#endif
    }
    return self;
}

- (SentryStacktrace *)retrieveStacktraceFromCursor:(SentryCrashStackCursor)stackCursor
{
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
        frame = [self.crashStackEntryMapper mapStackEntryWithCursor:stackCursor];
        [frames addObject:frame];
    }

    return [SentryStacktraceBuilder buildStacktraceFromFrames:frames];
}

#if SDK_V10
- (SentryStacktrace *)retrieveStacktraceFromAddresses:(NSArray<NSNumber *> *)addresses
{
    NSMutableArray<SentryFrame *> *frames = [NSMutableArray arrayWithCapacity:addresses.count];
    SentryFrame *frame = nil;
    for (NSNumber *address in addresses) {
        SentryCrashStackEntry stackEntry = { .address = (uintptr_t)address.unsignedLongLongValue };
        if (stackEntry.address == SentryCrashSC_ASYNC_MARKER) {
            if (frame != nil) {
                frame.stackStart = @(YES);
            }
            continue;
        }
        frame = [self.crashStackEntryMapper sentryCrashStackEntryToSentryFrame:stackEntry];
        [frames addObject:frame];
    }

    return [SentryStacktraceBuilder buildStacktraceFromFrames:frames];
}
#endif

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

    return [SentryStacktraceBuilder buildStacktraceFromFrames:frames];
}

- (SentryStacktrace *)buildStacktraceForThread:(SentryCrashThread)thread
                                       context:(struct SentryCrashMachineContext *)context
{
    sentrycrashmc_getContextForThread(thread, context, NO);
    SentryCrashStackCursor stackCursor;
    sentrycrashsc_initWithMachineContext(&stackCursor, MAX_STACKTRACE_LENGTH, context);

    return [self retrieveStacktraceFromCursor:stackCursor];
}

- (SentryStacktrace *)buildStacktraceForCurrentThread
{
#if SDK_V10
    return [self
        retrieveStacktraceFromAddresses:[self.currentThreadStackProvider captureStackEntries]];
#else
    SentryCrashStackCursor stackCursor;
    // We don't need to skip any frames, because we filter out non sentry frames below.
    NSInteger framesToSkip = 0;
    sentrycrashsc_initSelfThread(&stackCursor, (int)framesToSkip);

    return [self retrieveStacktraceFromCursor:stackCursor];
#endif
}

- (nullable SentryStacktrace *)buildStacktraceForCurrentThreadAsyncUnsafe
{
    SENTRY_LOG_DEBUG(@"Building async-unsafe stack trace...");
#if SDK_V10
    return [self
        retrieveStacktraceFromAddresses:[self.currentThreadStackProvider captureStackEntries]];
#else
    SentryCrashStackCursor stackCursor;
    sentrycrashsc_initSelfThread(&stackCursor, 0);
    return [self retrieveStacktraceFromCursor:stackCursor];
#endif
}

+ (SentryStacktrace *_Nonnull)buildStacktraceFromFrames:(NSArray<SentryFrame *> *)frames
{
    NSArray<SentryFrame *> *framesCleared = [SentryFrameRemover removeNonSdkFrames:frames];

    // The frames must be ordered from caller to callee, or oldest to youngest
    NSArray<SentryFrame *> *framesReversed = [[framesCleared reverseObjectEnumerator] allObjects];

    return [[SentryStacktrace alloc] initWithFrames:framesReversed registers:@{ }];
}

@end

NS_ASSUME_NONNULL_END
