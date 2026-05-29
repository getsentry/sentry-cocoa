@import SentryObjC;
@import XCTest;

@interface SentryObjCMeasurementUnitTests : XCTestCase
@end

@implementation SentryObjCMeasurementUnitTests

#pragma mark - initWithUnit:

- (void)testInitWithUnit_shouldSetUnit
{
    // -- Act --
    SentryObjCMeasurementUnit *unit =
        [[SentryObjCMeasurementUnit alloc] initWithUnit:@"custom_unit"];

    // -- Assert --
    XCTAssertEqualObjects(unit.unit, @"custom_unit");
}

#pragma mark - none

- (void)testNone_shouldReturnEmptyString
{
    // -- Assert --
    XCTAssertEqualObjects(SentryObjCMeasurementUnit.none.unit, @"");
}

#pragma mark - Duration

- (void)testDurationUnits_shouldReturnExpectedUnit
{
    // -- Assert --
    XCTAssertEqualObjects(SentryObjCMeasurementUnit.nanosecond.unit, @"nanosecond");
    XCTAssertEqualObjects(SentryObjCMeasurementUnit.microsecond.unit, @"microsecond");
    XCTAssertEqualObjects(SentryObjCMeasurementUnit.millisecond.unit, @"millisecond");
    XCTAssertEqualObjects(SentryObjCMeasurementUnit.second.unit, @"second");
    XCTAssertEqualObjects(SentryObjCMeasurementUnit.minute.unit, @"minute");
    XCTAssertEqualObjects(SentryObjCMeasurementUnit.hour.unit, @"hour");
    XCTAssertEqualObjects(SentryObjCMeasurementUnit.day.unit, @"day");
    XCTAssertEqualObjects(SentryObjCMeasurementUnit.week.unit, @"week");
}

#pragma mark - Information

- (void)testInformationUnits_shouldReturnExpectedUnit
{
    // -- Assert --
    XCTAssertEqualObjects(SentryObjCMeasurementUnit.bit.unit, @"bit");
    XCTAssertEqualObjects(SentryObjCMeasurementUnit.byte.unit, @"byte");
    XCTAssertEqualObjects(SentryObjCMeasurementUnit.kilobyte.unit, @"kilobyte");
    XCTAssertEqualObjects(SentryObjCMeasurementUnit.kibibyte.unit, @"kibibyte");
    XCTAssertEqualObjects(SentryObjCMeasurementUnit.megabyte.unit, @"megabyte");
    XCTAssertEqualObjects(SentryObjCMeasurementUnit.mebibyte.unit, @"mebibyte");
    XCTAssertEqualObjects(SentryObjCMeasurementUnit.gigabyte.unit, @"gigabyte");
    XCTAssertEqualObjects(SentryObjCMeasurementUnit.gibibyte.unit, @"gibibyte");
    XCTAssertEqualObjects(SentryObjCMeasurementUnit.terabyte.unit, @"terabyte");
    XCTAssertEqualObjects(SentryObjCMeasurementUnit.tebibyte.unit, @"tebibyte");
    XCTAssertEqualObjects(SentryObjCMeasurementUnit.petabyte.unit, @"petabyte");
    XCTAssertEqualObjects(SentryObjCMeasurementUnit.pebibyte.unit, @"pebibyte");
    XCTAssertEqualObjects(SentryObjCMeasurementUnit.exabyte.unit, @"exabyte");
    XCTAssertEqualObjects(SentryObjCMeasurementUnit.exbibyte.unit, @"exbibyte");
}

#pragma mark - Fraction

- (void)testFractionUnits_shouldReturnExpectedUnit
{
    // -- Assert --
    XCTAssertEqualObjects(SentryObjCMeasurementUnit.ratio.unit, @"ratio");
    XCTAssertEqualObjects(SentryObjCMeasurementUnit.percent.unit, @"percent");
}

@end
