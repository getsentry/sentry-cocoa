#import "SentryLevelMapper.h"
#import "SentryLog+TestInit.h"
#import "SentryLog.h"
#import "SentryLogOutput.h"
#import "XCTest+SentryDynamicMethods.h"
#import <XCTest/XCTest.h>

@interface SentryTestLogOutput : SentryLogOutput
@property (copy, nonatomic) NSMutableArray<NSString *> *loggedMessages;
@end

@implementation SentryTestLogOutput

- (void)log:(NSString *)message
{
    if (_loggedMessages == nil) {
        _loggedMessages = [NSMutableArray<NSString *> array];
    }
    [_loggedMessages addObject:message];
}

@end

/**
 * Test that when setting the diagnostic level to each value in @c SentryLevel and then receiving
 * log messages at all levels, that only the levels at or above the configured level are processed.
 */
@interface SentryLogTests : XCTestCase

@end

@implementation SentryLogTests

+ (void)initialize
{
    NSArray *allExpectedMessages = @[
        @"Sentry - none:: 0", @"Sentry - debug:: 1", @"Sentry - info:: 2", @"Sentry - warning:: 3",
        @"Sentry - error:: 4", @"Sentry - fatal:: 5"
    ];
    for (SentryLevel l = kSentryLevelDebug; l < kSentryLevelFatal; l++) {
        NSString *name = [NSString stringWithFormat:@"test_%@Level", SentryLevelNames[l]];
        [self
            sentry_addInstanceMethodWithSelectorName:name
                                           testLogic:^(__unused XCTestCase *_Nonnull testCase) {
                                               SentryTestLogOutput *logOutput =
                                                   [[SentryTestLogOutput alloc] init];
                                               [SentryLog configureWithDiagnosticLevel:l];
                                               [SentryLog setLogOutput:logOutput];

                                               [SentryLog logWithMessage:@"0"
                                                                andLevel:kSentryLevelNone];
                                               [SentryLog logWithMessage:@"1"
                                                                andLevel:kSentryLevelDebug];
                                               [SentryLog logWithMessage:@"2"
                                                                andLevel:kSentryLevelInfo];
                                               [SentryLog logWithMessage:@"3"
                                                                andLevel:kSentryLevelWarning];
                                               [SentryLog logWithMessage:@"4"
                                                                andLevel:kSentryLevelError];
                                               [SentryLog logWithMessage:@"5"
                                                                andLevel:kSentryLevelFatal];

                                               NSArray *expected = [allExpectedMessages
                                                   objectsAtIndexes:[NSIndexSet
                                                                        indexSetWithIndexesInRange:
                                                                            NSMakeRange(l,
                                                                                kSentryLevelFatal
                                                                                    - l + 1)]];
                                               NSArray *actual = logOutput.loggedMessages;
                                               XCTAssert([expected isEqualToArray:actual],
                                                   @"Expected %@ but got %@", expected, actual);
                                           }];
    }
}

@end
