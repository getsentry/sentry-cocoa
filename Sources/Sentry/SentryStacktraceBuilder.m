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
    sentrycrashsc_initSelfThread(&stackCursor, 0);

    while (stackCursor.advanceCursor(&stackCursor)) {
        if (stackCursor.symbolicate(&stackCursor)) {
            SentryFrame *frame = [SentryCrashStackEntryMapper mapStackEntryWithCursor:stackCursor];
            [frames addObject:frame];
        }
    }

    // Remove the current function from the stacktrace
    [frames removeObjectAtIndex:0];

    // The frames must be ordered from caller to callee, or oldest to youngest
    NSArray<SentryFrame *> *framesReversed = [[frames reverseObjectEnumerator] allObjects];

    SentryStacktrace *stacktrace = [[SentryStacktrace alloc] initWithFrames:framesReversed
                                                                  registers:@{}];

    return stacktrace;
}

@end

NS_ASSUME_NONNULL_END
