@import SentryObjC;
@import XCTest;

@interface SentryObjCMeasurementUnitTests : XCTestCase
@end

@implementation SentryObjCMeasurementUnitTests

#pragma mark - initWithUnit:

- (void)testInitWithUnit_shouldReturnNonNil
{
    // -- Arrange --
    // (nothing)

    // -- Act --
    SentryObjCMeasurementUnit *unit =
        [[SentryObjCMeasurementUnit alloc] initWithUnit:@"custom_unit"];

    // -- Assert --
    XCTAssertNotNil(unit);
}

- (void)testInitWithUnit_shouldSetUnit
{
    // -- Arrange --
    // (nothing)

    // -- Act --
    SentryObjCMeasurementUnit *unit =
        [[SentryObjCMeasurementUnit alloc] initWithUnit:@"custom_unit"];

    // -- Assert --
    XCTAssertEqualObjects(unit.unit, @"custom_unit");
}

#pragma mark - none

- (void)testNone_shouldReturnNonNil
{
    // -- Arrange --
    // (nothing)

    // -- Act --
    SentryObjCMeasurementUnit *unit = SentryObjCMeasurementUnit.none;

    // -- Assert --
    XCTAssertNotNil(unit);
    XCTAssertNotNil(unit.unit);
}

#pragma mark - Duration

- (void)testNanosecond_shouldReturnNonNilWithUnit
{
    // -- Arrange --
    // (nothing)

    // -- Act --
    SentryObjCMeasurementUnit *unit = SentryObjCMeasurementUnit.nanosecond;

    // -- Assert --
    XCTAssertNotNil(unit);
    XCTAssertNotNil(unit.unit);
}

- (void)testMicrosecond_shouldReturnNonNilWithUnit
{
    // -- Arrange --
    // (nothing)

    // -- Act --
    SentryObjCMeasurementUnit *unit = SentryObjCMeasurementUnit.microsecond;

    // -- Assert --
    XCTAssertNotNil(unit);
    XCTAssertNotNil(unit.unit);
}

- (void)testMillisecond_shouldReturnNonNilWithUnit
{
    // -- Arrange --
    // (nothing)

    // -- Act --
    SentryObjCMeasurementUnit *unit = SentryObjCMeasurementUnit.millisecond;

    // -- Assert --
    XCTAssertNotNil(unit);
    XCTAssertNotNil(unit.unit);
}

- (void)testSecond_shouldReturnNonNilWithUnit
{
    // -- Arrange --
    // (nothing)

    // -- Act --
    SentryObjCMeasurementUnit *unit = SentryObjCMeasurementUnit.second;

    // -- Assert --
    XCTAssertNotNil(unit);
    XCTAssertNotNil(unit.unit);
}

- (void)testMinute_shouldReturnNonNilWithUnit
{
    // -- Arrange --
    // (nothing)

    // -- Act --
    SentryObjCMeasurementUnit *unit = SentryObjCMeasurementUnit.minute;

    // -- Assert --
    XCTAssertNotNil(unit);
    XCTAssertNotNil(unit.unit);
}

- (void)testHour_shouldReturnNonNilWithUnit
{
    // -- Arrange --
    // (nothing)

    // -- Act --
    SentryObjCMeasurementUnit *unit = SentryObjCMeasurementUnit.hour;

    // -- Assert --
    XCTAssertNotNil(unit);
    XCTAssertNotNil(unit.unit);
}

- (void)testDay_shouldReturnNonNilWithUnit
{
    // -- Arrange --
    // (nothing)

    // -- Act --
    SentryObjCMeasurementUnit *unit = SentryObjCMeasurementUnit.day;

    // -- Assert --
    XCTAssertNotNil(unit);
    XCTAssertNotNil(unit.unit);
}

- (void)testWeek_shouldReturnNonNilWithUnit
{
    // -- Arrange --
    // (nothing)

    // -- Act --
    SentryObjCMeasurementUnit *unit = SentryObjCMeasurementUnit.week;

    // -- Assert --
    XCTAssertNotNil(unit);
    XCTAssertNotNil(unit.unit);
}

#pragma mark - Information

- (void)testBit_shouldReturnNonNilWithUnit
{
    // -- Arrange --
    // (nothing)

    // -- Act --
    SentryObjCMeasurementUnit *unit = SentryObjCMeasurementUnit.bit;

    // -- Assert --
    XCTAssertNotNil(unit);
    XCTAssertNotNil(unit.unit);
}

- (void)testByte_shouldReturnNonNilWithUnit
{
    // -- Arrange --
    // (nothing)

    // -- Act --
    SentryObjCMeasurementUnit *unit = SentryObjCMeasurementUnit.byte;

    // -- Assert --
    XCTAssertNotNil(unit);
    XCTAssertNotNil(unit.unit);
}

- (void)testKilobyte_shouldReturnNonNilWithUnit
{
    // -- Arrange --
    // (nothing)

    // -- Act --
    SentryObjCMeasurementUnit *unit = SentryObjCMeasurementUnit.kilobyte;

    // -- Assert --
    XCTAssertNotNil(unit);
    XCTAssertNotNil(unit.unit);
}

- (void)testKibibyte_shouldReturnNonNilWithUnit
{
    // -- Arrange --
    // (nothing)

    // -- Act --
    SentryObjCMeasurementUnit *unit = SentryObjCMeasurementUnit.kibibyte;

    // -- Assert --
    XCTAssertNotNil(unit);
    XCTAssertNotNil(unit.unit);
}

- (void)testMegabyte_shouldReturnNonNilWithUnit
{
    // -- Arrange --
    // (nothing)

    // -- Act --
    SentryObjCMeasurementUnit *unit = SentryObjCMeasurementUnit.megabyte;

    // -- Assert --
    XCTAssertNotNil(unit);
    XCTAssertNotNil(unit.unit);
}

- (void)testMebibyte_shouldReturnNonNilWithUnit
{
    // -- Arrange --
    // (nothing)

    // -- Act --
    SentryObjCMeasurementUnit *unit = SentryObjCMeasurementUnit.mebibyte;

    // -- Assert --
    XCTAssertNotNil(unit);
    XCTAssertNotNil(unit.unit);
}

- (void)testGigabyte_shouldReturnNonNilWithUnit
{
    // -- Arrange --
    // (nothing)

    // -- Act --
    SentryObjCMeasurementUnit *unit = SentryObjCMeasurementUnit.gigabyte;

    // -- Assert --
    XCTAssertNotNil(unit);
    XCTAssertNotNil(unit.unit);
}

- (void)testGibibyte_shouldReturnNonNilWithUnit
{
    // -- Arrange --
    // (nothing)

    // -- Act --
    SentryObjCMeasurementUnit *unit = SentryObjCMeasurementUnit.gibibyte;

    // -- Assert --
    XCTAssertNotNil(unit);
    XCTAssertNotNil(unit.unit);
}

- (void)testTerabyte_shouldReturnNonNilWithUnit
{
    // -- Arrange --
    // (nothing)

    // -- Act --
    SentryObjCMeasurementUnit *unit = SentryObjCMeasurementUnit.terabyte;

    // -- Assert --
    XCTAssertNotNil(unit);
    XCTAssertNotNil(unit.unit);
}

- (void)testTebibyte_shouldReturnNonNilWithUnit
{
    // -- Arrange --
    // (nothing)

    // -- Act --
    SentryObjCMeasurementUnit *unit = SentryObjCMeasurementUnit.tebibyte;

    // -- Assert --
    XCTAssertNotNil(unit);
    XCTAssertNotNil(unit.unit);
}

- (void)testPetabyte_shouldReturnNonNilWithUnit
{
    // -- Arrange --
    // (nothing)

    // -- Act --
    SentryObjCMeasurementUnit *unit = SentryObjCMeasurementUnit.petabyte;

    // -- Assert --
    XCTAssertNotNil(unit);
    XCTAssertNotNil(unit.unit);
}

- (void)testPebibyte_shouldReturnNonNilWithUnit
{
    // -- Arrange --
    // (nothing)

    // -- Act --
    SentryObjCMeasurementUnit *unit = SentryObjCMeasurementUnit.pebibyte;

    // -- Assert --
    XCTAssertNotNil(unit);
    XCTAssertNotNil(unit.unit);
}

- (void)testExabyte_shouldReturnNonNilWithUnit
{
    // -- Arrange --
    // (nothing)

    // -- Act --
    SentryObjCMeasurementUnit *unit = SentryObjCMeasurementUnit.exabyte;

    // -- Assert --
    XCTAssertNotNil(unit);
    XCTAssertNotNil(unit.unit);
}

- (void)testExbibyte_shouldReturnNonNilWithUnit
{
    // -- Arrange --
    // (nothing)

    // -- Act --
    SentryObjCMeasurementUnit *unit = SentryObjCMeasurementUnit.exbibyte;

    // -- Assert --
    XCTAssertNotNil(unit);
    XCTAssertNotNil(unit.unit);
}

#pragma mark - Fraction

- (void)testRatio_shouldReturnNonNilWithUnit
{
    // -- Arrange --
    // (nothing)

    // -- Act --
    SentryObjCMeasurementUnit *unit = SentryObjCMeasurementUnit.ratio;

    // -- Assert --
    XCTAssertNotNil(unit);
    XCTAssertNotNil(unit.unit);
}

- (void)testPercent_shouldReturnNonNilWithUnit
{
    // -- Arrange --
    // (nothing)

    // -- Act --
    SentryObjCMeasurementUnit *unit = SentryObjCMeasurementUnit.percent;

    // -- Assert --
    XCTAssertNotNil(unit);
    XCTAssertNotNil(unit.unit);
}

@end
