#import "SentryObjC.h"
@import XCTest;

@interface SentryObjCLevelTests : XCTestCase
@end

@implementation SentryObjCLevelTests

- (void)testLevel_shouldMapAllCasesToExpectedValues
{
    // -- Assert --
    XCTAssertEqual(SentryObjCLevelNone, (NSUInteger)0);
    XCTAssertEqual(SentryObjCLevelDebug, (NSUInteger)1);
    XCTAssertEqual(SentryObjCLevelInfo, (NSUInteger)2);
    XCTAssertEqual(SentryObjCLevelWarning, (NSUInteger)3);
    XCTAssertEqual(SentryObjCLevelError, (NSUInteger)4);
    XCTAssertEqual(SentryObjCLevelFatal, (NSUInteger)5);
}

- (void)testLevel_whenRoundTripped_shouldPreserveValue
{
    // -- Act --
    SentryObjCLevel roundTripped = (SentryObjCLevel)SentryObjCLevelWarning;

    // -- Assert --
    XCTAssertEqual(roundTripped, SentryObjCLevelWarning);
}

@end
