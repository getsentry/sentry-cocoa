#import "SentryObjC.h"
@import XCTest;

@interface SentryObjCUnitTests : XCTestCase
@end

@implementation SentryObjCUnitTests

- (void)testInitWithRawValue_shouldReturnCustomUnit
{
    // -- Act --
    SentryObjCUnit *unit = [[SentryObjCUnit alloc] initWithRawValue:@"custom_unit"];

    // -- Assert --
    XCTAssertNotNil(unit);
    XCTAssertEqualObjects(unit.rawValue, @"custom_unit");
}

- (void)testDurationUnits_shouldReturnExpectedRawValue
{
    // -- Assert --
    XCTAssertEqualObjects(SentryObjCUnit.nanosecond.rawValue, @"nanosecond");
    XCTAssertEqualObjects(SentryObjCUnit.microsecond.rawValue, @"microsecond");
    XCTAssertEqualObjects(SentryObjCUnit.millisecond.rawValue, @"millisecond");
    XCTAssertEqualObjects(SentryObjCUnit.second.rawValue, @"second");
    XCTAssertEqualObjects(SentryObjCUnit.minute.rawValue, @"minute");
    XCTAssertEqualObjects(SentryObjCUnit.hour.rawValue, @"hour");
    XCTAssertEqualObjects(SentryObjCUnit.day.rawValue, @"day");
    XCTAssertEqualObjects(SentryObjCUnit.week.rawValue, @"week");
}

- (void)testInformationUnits_shouldReturnExpectedRawValue
{
    // -- Assert --
    XCTAssertEqualObjects(SentryObjCUnit.bit.rawValue, @"bit");
    XCTAssertEqualObjects(SentryObjCUnit.byte.rawValue, @"byte");
    XCTAssertEqualObjects(SentryObjCUnit.kilobyte.rawValue, @"kilobyte");
    XCTAssertEqualObjects(SentryObjCUnit.kibibyte.rawValue, @"kibibyte");
    XCTAssertEqualObjects(SentryObjCUnit.megabyte.rawValue, @"megabyte");
    XCTAssertEqualObjects(SentryObjCUnit.mebibyte.rawValue, @"mebibyte");
    XCTAssertEqualObjects(SentryObjCUnit.gigabyte.rawValue, @"gigabyte");
    XCTAssertEqualObjects(SentryObjCUnit.gibibyte.rawValue, @"gibibyte");
    XCTAssertEqualObjects(SentryObjCUnit.terabyte.rawValue, @"terabyte");
    XCTAssertEqualObjects(SentryObjCUnit.tebibyte.rawValue, @"tebibyte");
    XCTAssertEqualObjects(SentryObjCUnit.petabyte.rawValue, @"petabyte");
    XCTAssertEqualObjects(SentryObjCUnit.pebibyte.rawValue, @"pebibyte");
    XCTAssertEqualObjects(SentryObjCUnit.exabyte.rawValue, @"exabyte");
    XCTAssertEqualObjects(SentryObjCUnit.exbibyte.rawValue, @"exbibyte");
}

- (void)testFractionUnits_shouldReturnExpectedRawValue
{
    // -- Assert --
    XCTAssertEqualObjects(SentryObjCUnit.ratio.rawValue, @"ratio");
    XCTAssertEqualObjects(SentryObjCUnit.percent.rawValue, @"percent");
}

@end
