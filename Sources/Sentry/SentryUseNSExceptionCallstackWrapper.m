#import "SentryUseNSExceptionCallstackWrapper.h"
#import "SentryCrashStackEntryMapper.h"
#import "SentryCrashSymbolicator.h"
#import "SentryFrameRemover.h"
#import "SentryInAppLogic.h"
#import "SentryOptions+Private.h"
#import "SentrySDK+Private.h"
#import "SentryStacktrace.h"
#import "SentryThread.h"

#if TARGET_OS_OSX

@interface SentryUseNSExceptionCallstackWrapper ()

@property (nonatomic, strong) NSObject<ExceptionProtocol> *originalException;

@end

@implementation SentryUseNSExceptionCallstackWrapper

- (instancetype)initWithException:(NSObject<ExceptionProtocol> *)exception
{
    if (self = [super initWithName:exception.name
                            reason:exception.reason
                          userInfo:exception.userInfo]) {
        _originalException = exception;
    }
    return self;
}

- (NSArray<SentryThread *> *)buildThreads
{
    SentryThread *sentryThread = [[SentryThread alloc] initWithThreadId:@0];
    sentryThread.name = @"NSException Thread";
    sentryThread.crashed = @YES;
    // This data might not be real, but we cannot collect other threads
    sentryThread.current = @YES;
    sentryThread.isMain = @YES;

    SentryCrashStackEntryMapper *crashStackToEntryMapper = [self buildCrashStackToEntryMapper];
    NSMutableArray<SentryFrame *> *frames = [NSMutableArray array];

    // Iterate over all the addresses, symbolicate and create a SentryFrame
    [self.originalException.callStackReturnAddresses
        enumerateObjectsUsingBlock:^(NSNumber *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
            SentryCrashStackCursor stackCursor;
            stackCursor.stackEntry.address = [obj unsignedLongValue];
            sentrycrashsymbolicator_symbolicate(&stackCursor);

            [frames addObject:[crashStackToEntryMapper
                                  sentryCrashStackEntryToSentryFrame:stackCursor.stackEntry]];
        }];

    NSArray<SentryFrame *> *framesCleared = [SentryFrameRemover removeNonSdkFrames:frames];

    // The frames must be ordered from caller to callee, or oldest to youngest
    NSArray<SentryFrame *> *framesReversed = [[framesCleared reverseObjectEnumerator] allObjects];

    sentryThread.stacktrace = [[SentryStacktrace alloc] initWithFrames:framesReversed
                                                             registers:@{}];

    return @[ sentryThread ];
}

- (SentryCrashStackEntryMapper *)buildCrashStackToEntryMapper
{
    SentryOptions *options = SentrySDK.options;

    SentryInAppLogic *inAppLogic =
        [[SentryInAppLogic alloc] initWithInAppIncludes:options.inAppIncludes
                                          inAppExcludes:options.inAppExcludes];
    SentryCrashStackEntryMapper *crashStackEntryMapper =
        [[SentryCrashStackEntryMapper alloc] initWithInAppLogic:inAppLogic];

    return crashStackEntryMapper;
}

@end

#endif // TARGET_OS_OSX
