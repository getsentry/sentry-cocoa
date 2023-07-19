#import "SentryAddressRetriever.h"
#import "SentryBinaryImageCache.h"
#import "SentryCrashStackEntryMapper.h"
#import "SentryFrame.h"
#import "SentryInAppLogic.h"
#import "SentryStacktrace.h"
#import "SentryStacktraceBuilder.h"
#import <XCTest/XCTest.h>

@interface SentryAddressRetrieverTests : XCTestCase

@end

@implementation SentryAddressRetrieverTests

- (void)testRetrieveAddressForSelector
{
    SentryInAppLogic *inAppLogic = [[SentryInAppLogic alloc] initWithInAppIncludes:@[]
                                                                     inAppExcludes:@[]];

    SentryStacktraceBuilder *builder = [[SentryStacktraceBuilder alloc]
        initWithCrashStackEntryMapper:[[SentryCrashStackEntryMapper alloc]
                                          initWithInAppLogic:inAppLogic
                                            binaryImageCache:SentryBinaryImageCache.shared]];

    SentryStacktrace *stacktrace = [builder buildStacktraceForCurrentThread];

    SEL selector = @selector(testRetrieveAddressForSelector);

    NSString *symbolAddress = sentry_retrieveAddressForObject(self, selector);

    int count = 0;

    for (SentryFrame *frame in stacktrace.frames) {

        NSString *frameSymbolAddress
            = getSymbolAddressForInstructionAddress(frame.instructionAddress);

        if ([frameSymbolAddress isEqualToString:symbolAddress]) {
            count++;
        }
    }

    XCTAssertEqual(count, 1);
}

@end
