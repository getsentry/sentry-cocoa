@_spi(Private) @testable import Sentry
import XCTest

class SentryUnitTests: XCTestCase {

    // MARK: - Duration Units Tests

    func testRawValue_whenNanosecond_shouldReturnNanosecond() {
        // -- Arrange --
        let unit = SentryUnit.nanosecond

        // -- Act --
        let rawValue = unit.rawValue

        // -- Assert --
        XCTAssertEqual(rawValue, "nanosecond")
    }

    func testInitRawValue_whenNanosecond_shouldCreateNanosecond() {
        // -- Arrange --
        let rawValue = "nanosecond"

        // -- Act --
        let unit = SentryUnit(rawValue: rawValue)

        // -- Assert --
        XCTAssertEqual(unit, .nanosecond)
    }

    func testRawValue_whenMicrosecond_shouldReturnMicrosecond() {
        // -- Arrange --
        let unit = SentryUnit.microsecond

        // -- Act --
        let rawValue = unit.rawValue

        // -- Assert --
        XCTAssertEqual(rawValue, "microsecond")
    }

    func testInitRawValue_whenMicrosecond_shouldCreateMicrosecond() {
        // -- Arrange --
        let rawValue = "microsecond"

        // -- Act --
        let unit = SentryUnit(rawValue: rawValue)

        // -- Assert --
        XCTAssertEqual(unit, .microsecond)
    }

    func testRawValue_whenMillisecond_shouldReturnMillisecond() {
        // -- Arrange --
        let unit = SentryUnit.millisecond

        // -- Act --
        let rawValue = unit.rawValue

        // -- Assert --
        XCTAssertEqual(rawValue, "millisecond")
    }

    func testInitRawValue_whenMillisecond_shouldCreateMillisecond() {
        // -- Arrange --
        let rawValue = "millisecond"

        // -- Act --
        let unit = SentryUnit(rawValue: rawValue)

        // -- Assert --
        XCTAssertEqual(unit, .millisecond)
    }

    func testRawValue_whenSecond_shouldReturnSecond() {
        // -- Arrange --
        let unit = SentryUnit.second

        // -- Act --
        let rawValue = unit.rawValue

        // -- Assert --
        XCTAssertEqual(rawValue, "second")
    }

    func testInitRawValue_whenSecond_shouldCreateSecond() {
        // -- Arrange --
        let rawValue = "second"

        // -- Act --
        let unit = SentryUnit(rawValue: rawValue)

        // -- Assert --
        XCTAssertEqual(unit, .second)
    }

    func testRawValue_whenMinute_shouldReturnMinute() {
        // -- Arrange --
        let unit = SentryUnit.minute

        // -- Act --
        let rawValue = unit.rawValue

        // -- Assert --
        XCTAssertEqual(rawValue, "minute")
    }

    func testInitRawValue_whenMinute_shouldCreateMinute() {
        // -- Arrange --
        let rawValue = "minute"

        // -- Act --
        let unit = SentryUnit(rawValue: rawValue)

        // -- Assert --
        XCTAssertEqual(unit, .minute)
    }

    func testRawValue_whenHour_shouldReturnHour() {
        // -- Arrange --
        let unit = SentryUnit.hour

        // -- Act --
        let rawValue = unit.rawValue

        // -- Assert --
        XCTAssertEqual(rawValue, "hour")
    }

    func testInitRawValue_whenHour_shouldCreateHour() {
        // -- Arrange --
        let rawValue = "hour"

        // -- Act --
        let unit = SentryUnit(rawValue: rawValue)

        // -- Assert --
        XCTAssertEqual(unit, .hour)
    }

    func testRawValue_whenDay_shouldReturnDay() {
        // -- Arrange --
        let unit = SentryUnit.day

        // -- Act --
        let rawValue = unit.rawValue

        // -- Assert --
        XCTAssertEqual(rawValue, "day")
    }

    func testInitRawValue_whenDay_shouldCreateDay() {
        // -- Arrange --
        let rawValue = "day"

        // -- Act --
        let unit = SentryUnit(rawValue: rawValue)

        // -- Assert --
        XCTAssertEqual(unit, .day)
    }

    func testRawValue_whenWeek_shouldReturnWeek() {
        // -- Arrange --
        let unit = SentryUnit.week

        // -- Act --
        let rawValue = unit.rawValue

        // -- Assert --
        XCTAssertEqual(rawValue, "week")
    }

    func testInitRawValue_whenWeek_shouldCreateWeek() {
        // -- Arrange --
        let rawValue = "week"

        // -- Act --
        let unit = SentryUnit(rawValue: rawValue)

        // -- Assert --
        XCTAssertEqual(unit, .week)
    }

    // MARK: - Information Units Tests

    func testRawValue_whenBit_shouldReturnBit() {
        // -- Arrange --
        let unit = SentryUnit.bit

        // -- Act --
        let rawValue = unit.rawValue

        // -- Assert --
        XCTAssertEqual(rawValue, "bit")
    }

    func testInitRawValue_whenBit_shouldCreateBit() {
        // -- Arrange --
        let rawValue = "bit"

        // -- Act --
        let unit = SentryUnit(rawValue: rawValue)

        // -- Assert --
        XCTAssertEqual(unit, .bit)
    }

    func testRawValue_whenByte_shouldReturnByte() {
        // -- Arrange --
        let unit = SentryUnit.byte

        // -- Act --
        let rawValue = unit.rawValue

        // -- Assert --
        XCTAssertEqual(rawValue, "byte")
    }

    func testInitRawValue_whenByte_shouldCreateByte() {
        // -- Arrange --
        let rawValue = "byte"

        // -- Act --
        let unit = SentryUnit(rawValue: rawValue)

        // -- Assert --
        XCTAssertEqual(unit, .byte)
    }

    func testRawValue_whenKilobyte_shouldReturnKilobyte() {
        // -- Arrange --
        let unit = SentryUnit.kilobyte

        // -- Act --
        let rawValue = unit.rawValue

        // -- Assert --
        XCTAssertEqual(rawValue, "kilobyte")
    }

    func testInitRawValue_whenKilobyte_shouldCreateKilobyte() {
        // -- Arrange --
        let rawValue = "kilobyte"

        // -- Act --
        let unit = SentryUnit(rawValue: rawValue)

        // -- Assert --
        XCTAssertEqual(unit, .kilobyte)
    }

    func testRawValue_whenKibibyte_shouldReturnKibibyte() {
        // -- Arrange --
        let unit = SentryUnit.kibibyte

        // -- Act --
        let rawValue = unit.rawValue

        // -- Assert --
        XCTAssertEqual(rawValue, "kibibyte")
    }

    func testInitRawValue_whenKibibyte_shouldCreateKibibyte() {
        // -- Arrange --
        let rawValue = "kibibyte"

        // -- Act --
        let unit = SentryUnit(rawValue: rawValue)

        // -- Assert --
        XCTAssertEqual(unit, .kibibyte)
    }

    func testRawValue_whenMegabyte_shouldReturnMegabyte() {
        // -- Arrange --
        let unit = SentryUnit.megabyte

        // -- Act --
        let rawValue = unit.rawValue

        // -- Assert --
        XCTAssertEqual(rawValue, "megabyte")
    }

    func testInitRawValue_whenMegabyte_shouldCreateMegabyte() {
        // -- Arrange --
        let rawValue = "megabyte"

        // -- Act --
        let unit = SentryUnit(rawValue: rawValue)

        // -- Assert --
        XCTAssertEqual(unit, .megabyte)
    }

    func testRawValue_whenMebibyte_shouldReturnMebibyte() {
        // -- Arrange --
        let unit = SentryUnit.mebibyte

        // -- Act --
        let rawValue = unit.rawValue

        // -- Assert --
        XCTAssertEqual(rawValue, "mebibyte")
    }

    func testInitRawValue_whenMebibyte_shouldCreateMebibyte() {
        // -- Arrange --
        let rawValue = "mebibyte"

        // -- Act --
        let unit = SentryUnit(rawValue: rawValue)

        // -- Assert --
        XCTAssertEqual(unit, .mebibyte)
    }

    func testRawValue_whenGigabyte_shouldReturnGigabyte() {
        // -- Arrange --
        let unit = SentryUnit.gigabyte

        // -- Act --
        let rawValue = unit.rawValue

        // -- Assert --
        XCTAssertEqual(rawValue, "gigabyte")
    }

    func testInitRawValue_whenGigabyte_shouldCreateGigabyte() {
        // -- Arrange --
        let rawValue = "gigabyte"

        // -- Act --
        let unit = SentryUnit(rawValue: rawValue)

        // -- Assert --
        XCTAssertEqual(unit, .gigabyte)
    }

    func testRawValue_whenGibibyte_shouldReturnGibibyte() {
        // -- Arrange --
        let unit = SentryUnit.gibibyte

        // -- Act --
        let rawValue = unit.rawValue

        // -- Assert --
        XCTAssertEqual(rawValue, "gibibyte")
    }

    func testInitRawValue_whenGibibyte_shouldCreateGibibyte() {
        // -- Arrange --
        let rawValue = "gibibyte"

        // -- Act --
        let unit = SentryUnit(rawValue: rawValue)

        // -- Assert --
        XCTAssertEqual(unit, .gibibyte)
    }

    func testRawValue_whenTerabyte_shouldReturnTerabyte() {
        // -- Arrange --
        let unit = SentryUnit.terabyte

        // -- Act --
        let rawValue = unit.rawValue

        // -- Assert --
        XCTAssertEqual(rawValue, "terabyte")
    }

    func testInitRawValue_whenTerabyte_shouldCreateTerabyte() {
        // -- Arrange --
        let rawValue = "terabyte"

        // -- Act --
        let unit = SentryUnit(rawValue: rawValue)

        // -- Assert --
        XCTAssertEqual(unit, .terabyte)
    }

    func testRawValue_whenTebibyte_shouldReturnTebibyte() {
        // -- Arrange --
        let unit = SentryUnit.tebibyte

        // -- Act --
        let rawValue = unit.rawValue

        // -- Assert --
        XCTAssertEqual(rawValue, "tebibyte")
    }

    func testInitRawValue_whenTebibyte_shouldCreateTebibyte() {
        // -- Arrange --
        let rawValue = "tebibyte"

        // -- Act --
        let unit = SentryUnit(rawValue: rawValue)

        // -- Assert --
        XCTAssertEqual(unit, .tebibyte)
    }

    func testRawValue_whenPetabyte_shouldReturnPetabyte() {
        // -- Arrange --
        let unit = SentryUnit.petabyte

        // -- Act --
        let rawValue = unit.rawValue

        // -- Assert --
        XCTAssertEqual(rawValue, "petabyte")
    }

    func testInitRawValue_whenPetabyte_shouldCreatePetabyte() {
        // -- Arrange --
        let rawValue = "petabyte"

        // -- Act --
        let unit = SentryUnit(rawValue: rawValue)

        // -- Assert --
        XCTAssertEqual(unit, .petabyte)
    }

    func testRawValue_whenPebibyte_shouldReturnPebibyte() {
        // -- Arrange --
        let unit = SentryUnit.pebibyte

        // -- Act --
        let rawValue = unit.rawValue

        // -- Assert --
        XCTAssertEqual(rawValue, "pebibyte")
    }

    func testInitRawValue_whenPebibyte_shouldCreatePebibyte() {
        // -- Arrange --
        let rawValue = "pebibyte"

        // -- Act --
        let unit = SentryUnit(rawValue: rawValue)

        // -- Assert --
        XCTAssertEqual(unit, .pebibyte)
    }

    func testRawValue_whenExabyte_shouldReturnExabyte() {
        // -- Arrange --
        let unit = SentryUnit.exabyte

        // -- Act --
        let rawValue = unit.rawValue

        // -- Assert --
        XCTAssertEqual(rawValue, "exabyte")
    }

    func testInitRawValue_whenExabyte_shouldCreateExabyte() {
        // -- Arrange --
        let rawValue = "exabyte"

        // -- Act --
        let unit = SentryUnit(rawValue: rawValue)

        // -- Assert --
        XCTAssertEqual(unit, .exabyte)
    }

    func testRawValue_whenExbibyte_shouldReturnExbibyte() {
        // -- Arrange --
        let unit = SentryUnit.exbibyte

        // -- Act --
        let rawValue = unit.rawValue

        // -- Assert --
        XCTAssertEqual(rawValue, "exbibyte")
    }

    func testInitRawValue_whenExbibyte_shouldCreateExbibyte() {
        // -- Arrange --
        let rawValue = "exbibyte"

        // -- Act --
        let unit = SentryUnit(rawValue: rawValue)

        // -- Assert --
        XCTAssertEqual(unit, .exbibyte)
    }

    // MARK: - Fraction Units Tests

    func testRawValue_whenRatio_shouldReturnRatio() {
        // -- Arrange --
        let unit = SentryUnit.ratio

        // -- Act --
        let rawValue = unit.rawValue

        // -- Assert --
        XCTAssertEqual(rawValue, "ratio")
    }

    func testInitRawValue_whenRatio_shouldCreateRatio() {
        // -- Arrange --
        let rawValue = "ratio"

        // -- Act --
        let unit = SentryUnit(rawValue: rawValue)

        // -- Assert --
        XCTAssertEqual(unit, .ratio)
    }

    func testRawValue_whenPercent_shouldReturnPercent() {
        // -- Arrange --
        let unit = SentryUnit.percent

        // -- Act --
        let rawValue = unit.rawValue

        // -- Assert --
        XCTAssertEqual(rawValue, "percent")
    }

    func testInitRawValue_whenPercent_shouldCreatePercent() {
        // -- Arrange --
        let rawValue = "percent"

        // -- Act --
        let unit = SentryUnit(rawValue: rawValue)

        // -- Assert --
        XCTAssertEqual(unit, .percent)
    }

    // MARK: - Generic Units Tests

    func testRawValue_whenGeneric_shouldReturnCustomValue() {
        // -- Arrange --
        let customValue = "custom_unit"
        let unit = SentryUnit.generic(customValue)

        // -- Act --
        let rawValue = unit.rawValue

        // -- Assert --
        XCTAssertEqual(rawValue, customValue)
    }

    func testInitRawValue_whenUnknownString_shouldCreateGeneric() {
        // -- Arrange --
        let rawValue = "unknown_unit"

        // -- Act --
        let unit = SentryUnit(rawValue: rawValue)

        // -- Assert --
        if case .generic(let value) = unit {
            XCTAssertEqual(value, rawValue)
        } else {
            XCTFail("Expected generic case with value '\(rawValue)'")
        }
    }

    func testInitRawValue_whenEmptyString_shouldCreateGeneric() {
        // -- Arrange --
        let rawValue = ""

        // -- Act --
        let unit = SentryUnit(rawValue: rawValue)

        // -- Assert --
        if case .generic(let value) = unit {
            XCTAssertEqual(value, rawValue)
        } else {
            XCTFail("Expected generic case with empty value")
        }
    }

    // MARK: - Round-Trip Tests

    func testRoundTrip_whenKnownUnit_shouldPreserveValue() {
        // -- Arrange --
        let originalUnit = SentryUnit.second

        // -- Act --
        let rawValue = originalUnit.rawValue
        let reconstructedUnit = SentryUnit(rawValue: rawValue)

        // -- Assert --
        XCTAssertEqual(reconstructedUnit, originalUnit)
    }

    func testRoundTrip_whenGenericUnit_shouldPreserveValue() {
        // -- Arrange --
        let customValue = "custom_metric_unit"
        let originalUnit = SentryUnit.generic(customValue)

        // -- Act --
        let rawValue = originalUnit.rawValue
        let reconstructedUnit = SentryUnit(rawValue: rawValue)

        // -- Assert --
        if case .generic(let value) = reconstructedUnit {
            XCTAssertEqual(value, customValue)
        } else {
            XCTFail("Expected generic case with value '\(customValue)'")
        }
    }
}
