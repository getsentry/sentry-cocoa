import Foundation
@testable import Sentry
import XCTest

class SentryViewScreenshotOptionsTests: XCTestCase {
    // MARK: - Initializer

    func testInit_withoutArguments_shouldUseDefaults() {
        // -- Act --
        let options = SentryViewScreenshotOptions()

        // -- Assert --
        XCTAssertTrue(options.enableViewRendererV2)
        XCTAssertFalse(options.enableFastViewRendering)
        XCTAssertTrue(options.maskAllText)
        XCTAssertTrue(options.maskAllImages)
        XCTAssertEqual(options.maskedViewClasses.count, 0)
        XCTAssertEqual(options.unmaskedViewClasses.count, 0)
    }

    func testInit_withAllArguments_shouldSetValues() {
        // -- Act --
        // Use the opposite of the default values to check if they are set correctly
        let options = SentryViewScreenshotOptions(
            enableViewRendererV2: false,
            enableFastViewRendering: true,
            maskAllText: false,
            maskAllImages: false,
            maskedViewClasses: [NSString.self],
            unmaskedViewClasses: [NSNumber.self]
        )

        // -- Assert --
        XCTAssertFalse(options.enableViewRendererV2)
        XCTAssertTrue(options.enableFastViewRendering)
        XCTAssertFalse(options.maskAllText)
        XCTAssertFalse(options.maskAllImages)
        XCTAssertEqual(options.maskedViewClasses.count, 1)
        XCTAssertEqual(ObjectIdentifier(options.maskedViewClasses[0]), ObjectIdentifier(NSString.self))
        XCTAssertEqual(options.unmaskedViewClasses.count, 1)
        XCTAssertEqual(ObjectIdentifier(options.unmaskedViewClasses[0]), ObjectIdentifier(NSNumber.self))
    }

    func testInit_enableViewRendererV2Omitted_shouldUseDefaultValues() {
        // -- Act --
        let options = SentryViewScreenshotOptions(
            enableFastViewRendering: true,
            maskAllText: false,
            maskAllImages: false
        )

        // -- Assert --
        XCTAssertTrue(options.enableViewRendererV2)
    }

    func testInit_enableFastViewRenderingOmitted_shouldUseDefaultValues() {
        // -- Act --
        let options = SentryViewScreenshotOptions(
            enableViewRendererV2: false,
            maskAllText: false,
            maskAllImages: false
        )

        // -- Assert --
        XCTAssertFalse(options.enableFastViewRendering)
    }

    func testInit_maskAllTextOmitted_shouldUseDefaultValues() {
        // -- Act --
        let options = SentryViewScreenshotOptions(
            enableViewRendererV2: false,
            enableFastViewRendering: true,
            maskAllImages: false
        )

        // -- Assert --
        XCTAssertTrue(options.maskAllText)
    }

    func testInit_maskAllImagesOmitted_shouldUseDefaultValues() {
        // -- Act --
        let options = SentryViewScreenshotOptions(
            enableViewRendererV2: false,
            enableFastViewRendering: true,
            maskAllText: false
        )

        // -- Assert --
        XCTAssertTrue(options.maskAllImages)
    }

    func testInit_maskedViewClassesOmitted_shouldUseDefaultValues() {
        // -- Act --
        let options = SentryViewScreenshotOptions(
            enableViewRendererV2: false,
            enableFastViewRendering: true,
            maskAllText: false,
            maskAllImages: false,
            unmaskedViewClasses: [NSString.self]
        )

        // -- Assert --
        XCTAssertEqual(options.maskedViewClasses.count, 0)
    }

    func testInit_unmaskedViewClassesOmitted_shouldUseDefaultValues() {
        // -- Act --
        let options = SentryViewScreenshotOptions(
            enableViewRendererV2: false,
            enableFastViewRendering: true,
            maskAllText: false,
            maskAllImages: false,
            maskedViewClasses: [NSString.self]
        )

        // -- Assert --
        XCTAssertEqual(options.unmaskedViewClasses.count, 0)
    }

    // MARK: - Dictionary Initialization

    func testInitFromDict_emptyDictionary_shouldUseDefaultValues() {
        // -- Act --
        let options = SentryViewScreenshotOptions(dictionary: [:])

        // -- Assert --
        XCTAssertTrue(options.enableViewRendererV2)
        XCTAssertFalse(options.enableFastViewRendering)
        XCTAssertTrue(options.maskAllText)
        XCTAssertTrue(options.maskAllImages)
        XCTAssertEqual(options.maskedViewClasses.count, 0)
        XCTAssertEqual(options.unmaskedViewClasses.count, 0)
    }

    func testInitFromDict_allValues_shouldSetValues() throws {
        // -- Act --
        let options = SentryViewScreenshotOptions(dictionary: [
            "enableViewRendererV2": false,
            "enableFastViewRendering": true,
            "maskAllText": false,
            "maskAllImages": false,
            "maskedViewClasses": ["NSString"],
            "unmaskedViewClasses": ["NSNumber"]
        ])

        // -- Assert --
        XCTAssertFalse(options.enableViewRendererV2)
        XCTAssertTrue(options.enableFastViewRendering)
        XCTAssertFalse(options.maskAllText)
        XCTAssertFalse(options.maskAllImages)

        XCTAssertEqual(options.maskedViewClasses.count, 1)
        let maskedViewClass: AnyClass = try XCTUnwrap(options.maskedViewClasses.first)
        XCTAssertEqual(ObjectIdentifier(maskedViewClass), ObjectIdentifier(NSString.self))

        XCTAssertEqual(options.unmaskedViewClasses.count, 1)
        let unmaskedViewClass: AnyClass = try XCTUnwrap(options.unmaskedViewClasses.first)
        XCTAssertEqual(ObjectIdentifier(unmaskedViewClass), ObjectIdentifier(NSNumber.self))
    }

    // MARK: - enableViewRendererV2

    func testInitFromDict_enableViewRendererV2_whenValidValue_shouldSetValue() {
        // -- Act --
        let options = SentryViewScreenshotOptions(dictionary: [
            "enableViewRendererV2": true
        ])

        // -- Assert --
        XCTAssertTrue(options.enableViewRendererV2)

        let options2 = SentryViewScreenshotOptions(dictionary: [
            "enableViewRendererV2": false
        ])

        // -- Assert --
        XCTAssertFalse(options2.enableViewRendererV2)
    }

    func testInitFromDict_enableViewRendererV2_whenInvalidValue_shouldUseDefaultValue() {
        // -- Act --
        let options = SentryViewScreenshotOptions(dictionary: [
            "enableViewRendererV2": "invalid_value"
        ])

        // -- Assert --
        XCTAssertTrue(options.enableViewRendererV2)
    }

    func testInitFromDict_enableViewRendererV2_whenNotSpecified_shouldUseDefaultValue() {
        // -- Act --
        let options = SentryViewScreenshotOptions(dictionary: [:])

        // -- Assert --
        XCTAssertTrue(options.enableViewRendererV2)
    }

    // MARK: - enableFastViewRendering

    func testInitFromDict_enableFastViewRendering_whenValidValue_shouldSetValue() {
        let options = SentryViewScreenshotOptions(dictionary: [
            "enableFastViewRendering": true
        ])
        XCTAssertTrue(options.enableFastViewRendering)

        let options2 = SentryViewScreenshotOptions(dictionary: [
            "enableFastViewRendering": false
        ])
        XCTAssertFalse(options2.enableFastViewRendering)
    }

    func testInitFromDict_enableFastViewRendering_whenInvalidValue_shouldUseDefaultValue() {
        let options = SentryViewScreenshotOptions(dictionary: [
            "enableFastViewRendering": "invalid_value"
        ])
        XCTAssertFalse(options.enableFastViewRendering)
    }

    // MARK: - maskAllText

    func testInitFromDict_maskAllText_whenValidValue_shouldSetValue() {
        // -- Act --
        let options = SentryViewScreenshotOptions(dictionary: [
            "maskAllText": true
        ])

        // -- Assert --
        XCTAssertTrue(options.maskAllText)

        let options2 = SentryViewScreenshotOptions(dictionary: [
            "maskAllText": false
        ])

        // -- Assert --
        XCTAssertFalse(options2.maskAllText)
    }

    func testInitFromDict_maskAllText_whenNotValidValue_shouldUseDefaultValue() {
        // -- Act --
        let options = SentryViewScreenshotOptions(dictionary: [
            "maskAllText": "invalid_value"
        ])

        // -- Assert --
        XCTAssertTrue(options.maskAllText)
    }

    // MARK: - maskAllImages

    func testInitFromDict_maskAllImages_whenValidValue_shouldSetValue() {
        // -- Act --
        let options = SentryViewScreenshotOptions(dictionary: [
            "maskAllImages": true
        ])

        // -- Assert --
        XCTAssertTrue(options.maskAllImages)

        let options2 = SentryViewScreenshotOptions(dictionary: [
            "maskAllImages": false
        ])

        // -- Assert --
        XCTAssertFalse(options2.maskAllImages)
    }

    func testInitFromDict_maskAllImages_whenNotValidValue_shouldUseDefaultValue() {
        // -- Act --
        let options = SentryViewScreenshotOptions(dictionary: [
            "maskAllImages": "invalid_value"
        ])

        // -- Assert --
        XCTAssertTrue(options.maskAllImages)
    }

    // MARK: - maskedViewClasses

    func testInitFromDict_maskedViewClasses_whenValidValue_shouldSetValue() throws {
        // -- Act --
        let options = SentryViewScreenshotOptions(dictionary: [
            "maskedViewClasses": ["NSString"]
        ])

        // -- Assert --
        XCTAssertEqual(options.maskedViewClasses.count, 1)
        let maskedClass: AnyClass = try XCTUnwrap(options.maskedViewClasses.first)
        XCTAssertEqual(ObjectIdentifier(maskedClass), ObjectIdentifier(NSString.self))
    }

    func testInitFromDict_maskedViewClasses_whenMultipleValidValue_shouldKeepAll() throws {
        // -- Act --
        let options = SentryViewScreenshotOptions(dictionary: [
            "maskedViewClasses": ["NSString", "NSNumber"]
        ])

        // -- Assert --
        XCTAssertEqual(options.maskedViewClasses.count, 2)
        guard options.maskedViewClasses.count == 2 else {
            return XCTFail("Expected two masked view classes, can not proceed.")
        }
        XCTAssertEqual(ObjectIdentifier(options.maskedViewClasses[0]), ObjectIdentifier(NSString.self))
        XCTAssertEqual(ObjectIdentifier(options.maskedViewClasses[1]), ObjectIdentifier(NSNumber.self))
    }

    func testInitFromDict_maskedViewClasses_whenInvalidValue_shouldExcludedClass() {
        // -- Act --
        let options = SentryViewScreenshotOptions(dictionary: [
            "maskedViewClasses": "invalid_value"
        ])

        // -- Assert --
        XCTAssertEqual(options.maskedViewClasses.count, 0)
    }

    func testInitFromDict_maskedViewClasses_whenInvalidArrayValue_shouldFilterInvalidValues() throws {
        // -- Act --
        let options = SentryViewScreenshotOptions(dictionary: [
            "maskedViewClasses": [
                "NSString",         // Valid class
                "some.class",       // Invalid class name
                123,                // Invalid type (number)
                true,               // Invalid type (boolean)
                ["nested": "array"], // Invalid type (dictionary)
                NSNull(),           // Invalid type (NSNull)
                ""                  // Empty string
            ] as [Any]
        ])

        // -- Assert --
        XCTAssertEqual(options.maskedViewClasses.count, 1)
        let maskedViewClass: AnyClass = try XCTUnwrap(options.maskedViewClasses.first)
        XCTAssertEqual(ObjectIdentifier(maskedViewClass), ObjectIdentifier(NSString.self))
    }

    func testInitFromDict_maskedViewClasses_whenMixedValidAndInvalidValues_shouldKeepOnlyValidValues() throws {
        // -- Act --
        let options = SentryViewScreenshotOptions(dictionary: [
            "maskedViewClasses": [
                "NSString",         // Valid class
                "NSNumber",         // Valid class
                "not.a.class",      // Invalid class name
                123                 // Invalid type (number)
            ] as [Any]
        ])

        // -- Assert --
        XCTAssertEqual(options.maskedViewClasses.count, 2)
        guard options.maskedViewClasses.count == 2 else {
            return XCTFail("Expected two masked view classes, can not proceed.")
        }
        XCTAssertEqual(ObjectIdentifier(options.maskedViewClasses[0]), ObjectIdentifier(NSString.self))
        XCTAssertEqual(ObjectIdentifier(options.maskedViewClasses[1]), ObjectIdentifier(NSNumber.self))
    }

    func testInitFromDict_maskedViewClasses_whenKeyOmitted_shouldUseDefaultValue() {
        // -- Act --
        let options = SentryViewScreenshotOptions(dictionary: [:])

        // -- Assert --
        XCTAssertEqual(options.maskedViewClasses.count, 0)
    }

    // MARK: - unmaskedViewClasses

    func testInitFromDict_unmaskedViewClasses_whenValidValue_shouldSetValue() throws {
        // -- Act --
        let options = SentryViewScreenshotOptions(dictionary: [
            "unmaskedViewClasses": ["NSString"]
        ])

        // -- Assert --
        XCTAssertEqual(options.unmaskedViewClasses.count, 1)
        let unmaskedClass: AnyClass = try XCTUnwrap(options.unmaskedViewClasses.first)
        XCTAssertEqual(ObjectIdentifier(unmaskedClass), ObjectIdentifier(NSString.self))
    }
    
    func testInitFromDict_unmaskedViewClasses_whenMultipleValidValue_shouldKeepAll() throws {
        // -- Act --
        let options = SentryViewScreenshotOptions(dictionary: [
            "unmaskedViewClasses": ["NSString", "NSNumber"]
        ])

        // -- Assert --
        XCTAssertEqual(options.unmaskedViewClasses.count, 2)
        guard options.unmaskedViewClasses.count == 2 else {
            return XCTFail("Expected two unmasked view classes, can not proceed.")
        }
        XCTAssertEqual(ObjectIdentifier(options.unmaskedViewClasses[0]), ObjectIdentifier(NSString.self))
        XCTAssertEqual(ObjectIdentifier(options.unmaskedViewClasses[1]), ObjectIdentifier(NSNumber.self))
    }
        
    func testInitFromDict_unmaskedViewClasses_whenNotValidValue_shouldUseDefaultValue() {
        // -- Act --
        let options = SentryViewScreenshotOptions(dictionary: [
            "unmaskedViewClasses": "invalid_value"
        ])

        // -- Assert --
        XCTAssertEqual(options.unmaskedViewClasses.count, 0)
    }

    func testInitFromDict_unmaskedViewClasses_whenInvalidArrayValues_shouldUseDefaultValue() throws {
        // -- Act --
        let options = SentryViewScreenshotOptions(dictionary: [
            "unmaskedViewClasses": [
                "not.a.class",      // Invalid class name
                123,                // Invalid type (number)
                true,               // Invalid type (boolean)
                ["nested": "array"], // Invalid type (dictionary)
                NSNull(),           // Invalid type (NSNull)
                ""                  // Empty string
            ] as [Any]
        ])

        // -- Assert --
        XCTAssertEqual(options.unmaskedViewClasses.count, 0)
    }
    
    func testInitFromDict_unmaskedViewClasses_whenMixedValidAndInvalidValues_shouldKeepOnlyValidValues() throws {
        // -- Act --
        let options = SentryViewScreenshotOptions(dictionary: [
            "unmaskedViewClasses": [
                "NSString",         // Valid class
                "NSNumber",         // Valid class
                "not.a.class",      // Invalid class name
                123                 // Invalid type (number)
            ] as [Any]
        ])

        // -- Assert --
        XCTAssertEqual(options.unmaskedViewClasses.count, 2)
        guard options.unmaskedViewClasses.count == 2 else {
            return XCTFail("Expected two unmasked view classes, can not proceed.")
        }
        XCTAssertEqual(ObjectIdentifier(options.unmaskedViewClasses[0]), ObjectIdentifier(NSString.self))
        XCTAssertEqual(ObjectIdentifier(options.unmaskedViewClasses[1]), ObjectIdentifier(NSNumber.self))
    }

    func testInitFromDict_unmaskedViewClasses_whenKeyOmitted_shouldUseDefaultValue() {
        // -- Act --
        let options = SentryViewScreenshotOptions(dictionary: [:])

        // -- Assert --
        XCTAssertEqual(options.unmaskedViewClasses.count, 0)
    }

    // MARK: - Mixed Dictionary Options

    func testInitFromDict_withMultipleOptions_shouldSetAllValues() {
        let options = SentryViewScreenshotOptions(dictionary: [
            "enableViewRendererV2": false,
            "enableFastViewRendering": true,
            "maskAllText": false,
            "maskAllImages": false,
            "maskedViewClasses": ["NSString", "not.a.class", 123] as [Any],
            "unmaskedViewClasses": ["NSNumber", "invalid", true] as [Any]
        ])

        XCTAssertFalse(options.enableViewRendererV2)
        XCTAssertTrue(options.enableFastViewRendering)
        XCTAssertFalse(options.maskAllText)
        XCTAssertFalse(options.maskAllImages)
        XCTAssertEqual(options.maskedViewClasses.count, 1)
        XCTAssertEqual(ObjectIdentifier(options.maskedViewClasses.first!), ObjectIdentifier(NSString.self))
        XCTAssertEqual(options.unmaskedViewClasses.count, 1)
        XCTAssertEqual(ObjectIdentifier(options.unmaskedViewClasses.first!), ObjectIdentifier(NSNumber.self))
    }

    // MARK: - Description

    func testDescription_shouldContainAllProperties() {
        // -- Arrange --
        let options = SentryViewScreenshotOptions(
            enableViewRendererV2: false,
            enableFastViewRendering: true,
            maskAllText: false,
            maskAllImages: false,
            maskedViewClasses: [NSString.self],
            unmaskedViewClasses: [NSNumber.self]
        )

        // -- Act --
        let description = options.description

        // -- Assert --
        XCTAssertTrue(description.contains("SentryViewScreenshotOptions"))
        XCTAssertTrue(description.contains("enableViewRendererV2: false"))
        XCTAssertTrue(description.contains("enableFastViewRendering: true"))
        XCTAssertTrue(description.contains("maskAllText: false"))
        XCTAssertTrue(description.contains("maskAllImages: false"))
        XCTAssertTrue(description.contains("maskedViewClasses"))
        XCTAssertTrue(description.contains("unmaskedViewClasses"))
    }

    // MARK: - Default Values

    func testDefaultValues_shouldMatchExpectedValues() {
        XCTAssertTrue(SentryViewScreenshotOptions.DefaultValues.enableViewRendererV2)
        XCTAssertFalse(SentryViewScreenshotOptions.DefaultValues.enableFastViewRendering)
        XCTAssertTrue(SentryViewScreenshotOptions.DefaultValues.maskAllText)
        XCTAssertTrue(SentryViewScreenshotOptions.DefaultValues.maskAllImages)
        XCTAssertEqual(SentryViewScreenshotOptions.DefaultValues.maskedViewClasses.count, 0)
        XCTAssertEqual(SentryViewScreenshotOptions.DefaultValues.unmaskedViewClasses.count, 0)
    }
}
