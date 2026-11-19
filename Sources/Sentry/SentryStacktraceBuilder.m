#import "SentryStacktraceBuilder.h"
#import "SentryCrashStackEntryMapper.h"
#import "SentryFrame.h"
#import "SentryLogC.h"
#import "SentryStacktrace.h"
#import "SentrySwift.h"
#import <dlfcn.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryStacktraceBuilder ()

@property (nonatomic, strong) SentryCrashStackEntryMapper *crashStackEntryMapper;
@property (nonatomic, strong) SentryKSCrashCurrentThreadStackProvider *currentThreadStackProvider;

@end

@implementation SentryStacktraceBuilder

- (id)initWithCrashStackEntryMapper:(SentryCrashStackEntryMapper *)crashStackEntryMapper
{
    if (self = [super init]) {
        self.crashStackEntryMapper = crashStackEntryMapper;
        self.currentThreadStackProvider = [[SentryKSCrashCurrentThreadStackProvider alloc] init];
    }
    return self;
}

- (SentryStacktrace *)buildStackTraceFromAddresses:(NSArray<NSNumber *> *)addresses
{
    NSMutableArray<SentryFrame *> *frames = [NSMutableArray arrayWithCapacity:addresses.count];
    for (NSNumber *address in addresses) {
        SentryFrame *frame =
            [self.crashStackEntryMapper mapAddress:(uintptr_t)address.unsignedLongLongValue];
        [frames addObject:frame];
    }

    return [SentryStacktraceBuilder buildStacktraceFromFrames:frames];
}

- (SentryStacktrace *)buildStacktraceForCurrentThread
{
    return
        [self buildStackTraceFromAddresses:[self.currentThreadStackProvider captureStackEntries]];
}

- (nullable SentryStacktrace *)buildStacktraceForCurrentThreadAsyncUnsafe
{
    SENTRY_LOG_DEBUG(@"Building async-unsafe stack trace...");
    return
        [self buildStackTraceFromAddresses:[self.currentThreadStackProvider captureStackEntries]];
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
