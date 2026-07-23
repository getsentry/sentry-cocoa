@testable import Sentry
import Foundation
import ObjectiveC
import XCTest

final class AssociatedObjectAccessorTests: XCTestCase {

    func testStringValue_whenNoValueSet_shouldReturnNil() {
        // -- Arrange --
        let object = TestObject()

        // -- Act --
        let value = object.stringValue

        // -- Assert --
        XCTAssertNil(value)
    }

    func testSetStringValue_whenValueProvided_shouldReturnValidValue() {
        // -- Arrange --
        let object = TestObject()

        // -- Act --
        object.setStringValue("value")

        // -- Assert --
        guard case .valid(let value) = object.stringValue else {
            return XCTFail("Expected a valid associated value")
        }
        XCTAssertEqual(value, "value")
    }

    func testStringValue_whenUsingDifferentProperty_shouldReturnNil() {
        // -- Arrange --
        let object = TestObject()
        object.setStringValue("value")

        // -- Act --
        let value = object.otherStringValue

        // -- Assert --
        XCTAssertNil(value)
    }

    func testSetStringValue_whenNilProvided_shouldClearValue() {
        // -- Arrange --
        let object = TestObject()
        object.setStringValue("value")

        // -- Act --
        object.setStringValue(nil)

        // -- Assert --
        XCTAssertNil(object.stringValue)
    }

    func testInvalidStringValue_whenDecodeFails_shouldReturnInvalidRawValue() {
        // -- Arrange --
        let object = TestObject()
        object.setInvalidStringValue("raw value")

        // -- Act --
        let value = object.invalidStringValue

        // -- Assert --
        guard case .invalid(let rawValue) = value else {
            return XCTFail("Expected an invalid associated value")
        }
        XCTAssertEqual(rawValue as? String, "raw value")
    }

    func testSetBoolValue_whenUsingCustomCodec_shouldEncodeAndDecodeValue() {
        // -- Arrange --
        let object = TestObject()

        // -- Act --
        object.setBoolValue(true)

        // -- Assert --
        XCTAssertEqual(object.rawBoolValue?.boolValue, true)
        guard case .valid(let value) = object.boolValue else {
            return XCTFail("Expected a valid associated value")
        }
        XCTAssertTrue(value)
    }
}

fileprivate final class TestObject: NSObject {
    private enum AssociatedKeys {
        static let stringValue = AssociatedObjectAccessor<String>.Key()
        static let otherStringValue = AssociatedObjectAccessor<String>.Key()
        static let invalidStringValue = AssociatedObjectAccessor<String>.Key()
        static let boolValue = AssociatedObjectAccessor<Bool>.Key()
    }

    private var stringValueAccessor: AssociatedObjectAccessor<String> {
        .init(on: self, key: AssociatedKeys.stringValue)
    }

    var stringValue: AssociatedObjectAccessor<String>.Value? {
        stringValueAccessor.value
    }

    func setStringValue(_ newValue: String?) {
        stringValueAccessor.set(newValue)
    }

    private var otherStringValueAccessor: AssociatedObjectAccessor<String> {
        .init(on: self, key: AssociatedKeys.otherStringValue)
    }

    var otherStringValue: AssociatedObjectAccessor<String>.Value? {
        otherStringValueAccessor.value
    }

    private var invalidStringValueAccessor: AssociatedObjectAccessor<String> {
        .init(
            on: self,
            key: AssociatedKeys.invalidStringValue,
            decode: { _ in nil }
        )
    }

    var invalidStringValue: AssociatedObjectAccessor<String>.Value? {
        invalidStringValueAccessor.value
    }

    func setInvalidStringValue(_ newValue: String?) {
        invalidStringValueAccessor.set(newValue)
    }

    private var boolValueAccessor: AssociatedObjectAccessor<Bool> {
        .init(
            on: self,
            key: AssociatedKeys.boolValue,
            decode: { ($0 as? NSNumber)?.boolValue },
            encode: { NSNumber(value: $0) }
        )
    }

    var boolValue: AssociatedObjectAccessor<Bool>.Value? {
        boolValueAccessor.value
    }

    var rawBoolValue: NSNumber? {
        objc_getAssociatedObject(self, AssociatedKeys.boolValue.pointer) as? NSNumber
    }

    func setBoolValue(_ newValue: Bool?) {
        boolValueAccessor.set(newValue)
    }
}
