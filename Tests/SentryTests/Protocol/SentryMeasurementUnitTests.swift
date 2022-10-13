import XCTest

final class SentryMeasurementUnitTests: XCTestCase {

    func testCustomUnit() {
        let unit = "custom"
        let sut = MeasurementUnit(unit: unit)
        
        XCTAssertEqual(unit, sut.unit)
    }
    
    func testUnitNone() {
        XCTAssertEqual("", MeasurementUnit.none.unit)
    }
    
    func testCopy() {
        let unit = "custom"
        let sut = MeasurementUnit(unit: unit).copy() as! MeasurementUnit

        XCTAssertEqual(unit, sut.unit)
    }
    
    func testCopyOfSubclass() {
        let unit = "custom"
        let sut = MeasurementUnitDuration(unit: unit).copy() as! MeasurementUnitDuration

        XCTAssertEqual(unit, sut.unit)
    }
    
    func testMeasurementUnitDuration() {
        XCTAssertEqual("nanosecond", MeasurementUnitDuration.nanosecond.unit)
        XCTAssertEqual("microsecond", MeasurementUnitDuration.microsecond.unit)
        XCTAssertEqual("millisecond", MeasurementUnitDuration.millisecond.unit)
        XCTAssertEqual("second", MeasurementUnitDuration.second.unit)
        XCTAssertEqual("minute", MeasurementUnitDuration.minute.unit)
        XCTAssertEqual("hour", MeasurementUnitDuration.hour.unit)
        XCTAssertEqual("day", MeasurementUnitDuration.day.unit)
        XCTAssertEqual("week", MeasurementUnitDuration.week.unit)
    }
    
    func testMeasurementUnitInformation() {
        XCTAssertEqual("bit", MeasurementUnitInformation.bit.unit)
        XCTAssertEqual("byte", MeasurementUnitInformation.byte.unit)
        XCTAssertEqual("kilobyte", MeasurementUnitInformation.kilobyte.unit)
        XCTAssertEqual("kibibyte", MeasurementUnitInformation.kibibyte.unit)
        XCTAssertEqual("megabyte", MeasurementUnitInformation.megabyte.unit)
        XCTAssertEqual("mebibyte", MeasurementUnitInformation.mebibyte.unit)
        XCTAssertEqual("gigabyte", MeasurementUnitInformation.gigabyte.unit)
        XCTAssertEqual("gibibyte", MeasurementUnitInformation.gibibyte.unit)
        XCTAssertEqual("terabyte", MeasurementUnitInformation.terabyte.unit)
        XCTAssertEqual("tebibyte", MeasurementUnitInformation.tebibyte.unit)
        XCTAssertEqual("petabyte", MeasurementUnitInformation.petabyte.unit)
        XCTAssertEqual("pebibyte", MeasurementUnitInformation.pebibyte.unit)
        XCTAssertEqual("exabyte", MeasurementUnitInformation.exabyte.unit)
        XCTAssertEqual("exbibyte", MeasurementUnitInformation.exbibyte.unit)
    }
    
    func testMeasurementUnitFraction() {
        XCTAssertEqual("ratio", MeasurementUnitFraction.ratio.unit)
        XCTAssertEqual("percent", MeasurementUnitFraction.percent.unit)
    }
}
