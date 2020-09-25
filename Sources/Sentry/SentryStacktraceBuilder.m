#import "SentryStacktraceBuilder.h"
#import "SentryCrashDynamicLinker.h"
#import "SentryCrashStackCursor.h"
#import "SentryCrashStackCursor_SelfThread.h"
#import "SentryCrashStackEntryMapper.h"
#import "SentryFrame.h"
#import "SentryHexAddressFormatter.h"
#import "SentryStacktrace.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentryStacktraceBuilder

- (SentryStacktrace *)buildStacktraceForCurrentThread
{
    NSMutableArray<SentryFrame *> *frames = [NSMutableArray new];

    SentryCrashStackCursor stackCursor;
    // We don't need to skip any frames, because we filter out non sentry frames below.
    NSInteger framesToSkip = 0;
    sentrycrashsc_initSelfThread(&stackCursor, (int)framesToSkip);

    while (stackCursor.advanceCursor(&stackCursor)) {
        if (stackCursor.symbolicate(&stackCursor)) {
            SentryFrame *frame = [SentryCrashStackEntryMapper mapStackEntryWithCursor:stackCursor];
            [frames addObject:frame];
        }
    }

    // When including Sentry via the Swift Package Manager the package is the same as the
    // application that includes Sentry. Therefore removing frames with a package containing
    // "sentry" doesn't work. We could instead look into the function name, but then we risk
    // removing functions that are not from this SDK and contain "sentry", which would lead to a
    // loss of frames on the stacktrace. Therefore we don't remove any frames.
    NSUInteger indexOfFirstNonSentryFrame = [frames indexOfObjectPassingTest:^BOOL(
        SentryFrame *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
        return ![[obj.package lowercaseString] containsString:@"sentry"];
    }];

    NSArray<SentryFrame *> *framesCleared =
        [frames subarrayWithRange:NSMakeRange(indexOfFirstNonSentryFrame,
                                      frames.count - indexOfFirstNonSentryFrame)];

    // The frames must be ordered from caller to callee, or oldest to youngest
    NSArray<SentryFrame *> *framesReversed = [[framesCleared reverseObjectEnumerator] allObjects];

    SentryStacktrace *stacktrace = [[SentryStacktrace alloc] initWithFrames:framesReversed
                                                                  registers:@{}];

    return stacktrace;
}

@end

NS_ASSUME_NONNULL_END
