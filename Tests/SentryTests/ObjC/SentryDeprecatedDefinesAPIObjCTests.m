#import "SentryDefines.h"
#import <XCTest/XCTest.h>

@interface SentryDeprecatedDefinesAPIObjCTests : XCTestCase

@end

@implementation SentryDeprecatedDefinesAPIObjCTests

- (void)testDefinesConstants_shouldMatchWireLiterals
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    XCTAssertEqual(defaultMaxBreadcrumbs, 100);
    XCTAssertEqualObjects(kSentryTrueString, @"true");
    XCTAssertEqualObjects(kSentryFalseString, @"false");
#pragma clang diagnostic pop
}

@end
