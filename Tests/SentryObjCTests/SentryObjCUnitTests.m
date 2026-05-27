@import SentryObjC;
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

- (void)testDurationUnits_shouldReturnNonNilWithRawValue
{
    // -- Assert --
    XCTAssertNotNil(SentryObjCUnit.nanosecond);
    XCTAssertNotNil(SentryObjCUnit.nanosecond.rawValue);

    XCTAssertNotNil(SentryObjCUnit.microsecond);
    XCTAssertNotNil(SentryObjCUnit.microsecond.rawValue);

    XCTAssertNotNil(SentryObjCUnit.millisecond);
    XCTAssertNotNil(SentryObjCUnit.millisecond.rawValue);

    XCTAssertNotNil(SentryObjCUnit.second);
    XCTAssertNotNil(SentryObjCUnit.second.rawValue);

    XCTAssertNotNil(SentryObjCUnit.minute);
    XCTAssertNotNil(SentryObjCUnit.minute.rawValue);

    XCTAssertNotNil(SentryObjCUnit.hour);
    XCTAssertNotNil(SentryObjCUnit.hour.rawValue);

    XCTAssertNotNil(SentryObjCUnit.day);
    XCTAssertNotNil(SentryObjCUnit.day.rawValue);

    XCTAssertNotNil(SentryObjCUnit.week);
    XCTAssertNotNil(SentryObjCUnit.week.rawValue);
}

- (void)testInformationUnits_shouldReturnNonNilWithRawValue
{
    // -- Assert --
    XCTAssertNotNil(SentryObjCUnit.bit);
    XCTAssertNotNil(SentryObjCUnit.bit.rawValue);

    XCTAssertNotNil(SentryObjCUnit.byte);
    XCTAssertNotNil(SentryObjCUnit.byte.rawValue);

    XCTAssertNotNil(SentryObjCUnit.kilobyte);
    XCTAssertNotNil(SentryObjCUnit.kilobyte.rawValue);

    XCTAssertNotNil(SentryObjCUnit.kibibyte);
    XCTAssertNotNil(SentryObjCUnit.kibibyte.rawValue);

    XCTAssertNotNil(SentryObjCUnit.megabyte);
    XCTAssertNotNil(SentryObjCUnit.megabyte.rawValue);

    XCTAssertNotNil(SentryObjCUnit.mebibyte);
    XCTAssertNotNil(SentryObjCUnit.mebibyte.rawValue);

    XCTAssertNotNil(SentryObjCUnit.gigabyte);
    XCTAssertNotNil(SentryObjCUnit.gigabyte.rawValue);

    XCTAssertNotNil(SentryObjCUnit.gibibyte);
    XCTAssertNotNil(SentryObjCUnit.gibibyte.rawValue);

    XCTAssertNotNil(SentryObjCUnit.terabyte);
    XCTAssertNotNil(SentryObjCUnit.terabyte.rawValue);

    XCTAssertNotNil(SentryObjCUnit.tebibyte);
    XCTAssertNotNil(SentryObjCUnit.tebibyte.rawValue);

    XCTAssertNotNil(SentryObjCUnit.petabyte);
    XCTAssertNotNil(SentryObjCUnit.petabyte.rawValue);

    XCTAssertNotNil(SentryObjCUnit.pebibyte);
    XCTAssertNotNil(SentryObjCUnit.pebibyte.rawValue);

    XCTAssertNotNil(SentryObjCUnit.exabyte);
    XCTAssertNotNil(SentryObjCUnit.exabyte.rawValue);

    XCTAssertNotNil(SentryObjCUnit.exbibyte);
    XCTAssertNotNil(SentryObjCUnit.exbibyte.rawValue);
}

- (void)testFractionUnits_shouldReturnNonNilWithRawValue
{
    // -- Assert --
    XCTAssertNotNil(SentryObjCUnit.ratio);
    XCTAssertNotNil(SentryObjCUnit.ratio.rawValue);

    XCTAssertNotNil(SentryObjCUnit.percent);
    XCTAssertNotNil(SentryObjCUnit.percent.rawValue);
}

@end
