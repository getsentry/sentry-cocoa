import Foundation
@testable import Sentry
import XCTest

class SentryReplayOptionsTests: XCTestCase {
    // MARK: - Initializer

    func testInit_withoutArguments_shouldUseDefaults() {
        // -- Act --
        let options = SentryReplayOptions()

        // -- Assert --
        XCTAssertEqual(options.sessionSampleRate, 0)
        XCTAssertEqual(options.onErrorSampleRate, 0)
        XCTAssertTrue(options.maskAllText)
        XCTAssertTrue(options.maskAllImages)
        XCTAssertTrue(options.enableViewRendererV2)
        XCTAssertFalse(options.enableFastViewRendering)

        XCTAssertEqual(options.maskedViewClasses.count, 0)
        XCTAssertEqual(options.unmaskedViewClasses.count, 0)
        XCTAssertEqual(options.quality, SentryReplayOptions.SentryReplayQuality.defaultQuality)
        XCTAssertEqual(options.frameRate, 1)
        XCTAssertEqual(options.errorReplayDuration, 30)
        XCTAssertEqual(options.sessionSegmentDuration, 5)
        XCTAssertEqual(options.maximumDuration, 60 * 60)
    }

    func testInit_withAllArguments_shouldSetValues() {
        // -- Act --
        // Use the opposite of the default values to check if they are set correctly
        let options = SentryReplayOptions(
            sessionSampleRate: 0.5,
            onErrorSampleRate: 0.8,
            maskAllText: false,
            maskAllImages: false,
            enableViewRendererV2: false,
            enableFastViewRendering: true
        )

        // -- Assert --
        XCTAssertEqual(options.sessionSampleRate, 0.5)
        XCTAssertEqual(options.onErrorSampleRate, 0.8)
        XCTAssertFalse(options.maskAllText)
        XCTAssertFalse(options.maskAllImages)
        XCTAssertFalse(options.enableViewRendererV2)
        XCTAssertTrue(options.enableFastViewRendering)

        XCTAssertEqual(options.maskedViewClasses.count, 0)
        XCTAssertEqual(options.unmaskedViewClasses.count, 0)
        XCTAssertEqual(options.quality, SentryReplayOptions.SentryReplayQuality.defaultQuality)
        XCTAssertEqual(options.frameRate, 1)
        XCTAssertEqual(options.errorReplayDuration, 30)
        XCTAssertEqual(options.sessionSegmentDuration, 5)
        XCTAssertEqual(options.maximumDuration, 60 * 60)
    }

    func testInit_sessionSampleRateOmitted_shouldUseDefaultValues() {
        // -- Act --
        let options = SentryReplayOptions(
            onErrorSampleRate: 0.8,
            maskAllText: false,
            maskAllImages: false,
            enableViewRendererV2: false,
            enableFastViewRendering: true
        )

        // -- Assert --
        XCTAssertEqual(options.sessionSampleRate, 0)
        XCTAssertEqual(options.onErrorSampleRate, 0.8)
        XCTAssertFalse(options.maskAllText)
        XCTAssertFalse(options.maskAllImages)
        XCTAssertFalse(options.enableViewRendererV2)
        XCTAssertTrue(options.enableFastViewRendering)
    }

    func testInit_onErrorSampleRateOmitted_shouldUseDefaultValues() {
        // -- Act --
        let options = SentryReplayOptions(
            sessionSampleRate: 0.5,
            maskAllText: false,
            maskAllImages: false,
            enableViewRendererV2: false,
            enableFastViewRendering: true
        )

        // -- Assert --
        XCTAssertEqual(options.sessionSampleRate, 0.5)
        XCTAssertEqual(options.onErrorSampleRate, 0)
        XCTAssertFalse(options.maskAllText)
        XCTAssertFalse(options.maskAllImages)
        XCTAssertFalse(options.enableViewRendererV2)
        XCTAssertTrue(options.enableFastViewRendering)
    }

    func testInit_maskAllTextOmitted_shouldUseDefaultValues() {
        // -- Act --
        let options = SentryReplayOptions(
            sessionSampleRate: 0.5,
            onErrorSampleRate: 0.8,
            maskAllImages: false,
            enableViewRendererV2: false,
            enableFastViewRendering: true
        )

        // -- Assert --
        XCTAssertEqual(options.sessionSampleRate, 0.5)
        XCTAssertEqual(options.onErrorSampleRate, 0.8)
        XCTAssertTrue(options.maskAllText)
        XCTAssertFalse(options.maskAllImages)
        XCTAssertFalse(options.enableViewRendererV2)
        XCTAssertTrue(options.enableFastViewRendering)
    }

    func testInit_maskAllImagesOmitted_shouldUseDefaultValues() {
        // -- Act --
        let options = SentryReplayOptions(
            sessionSampleRate: 0.5,
            onErrorSampleRate: 0.8,
            maskAllText: false,
            enableViewRendererV2: false,
            enableFastViewRendering: true
        )

        // -- Assert --
        XCTAssertEqual(options.sessionSampleRate, 0.5)
        XCTAssertEqual(options.onErrorSampleRate, 0.8)
        XCTAssertFalse(options.maskAllText)
        XCTAssertTrue(options.maskAllImages)
        XCTAssertFalse(options.enableViewRendererV2)
        XCTAssertTrue(options.enableFastViewRendering)
    }

    func testInit_enableViewRendererV2Omitted_shouldUseDefaultValues() {
        // -- Act --
        let options = SentryReplayOptions(
            sessionSampleRate: 0.5,
            onErrorSampleRate: 0.8,
            maskAllText: false,
            maskAllImages: false,
            enableFastViewRendering: true
        )

        // -- Assert --
        XCTAssertEqual(options.sessionSampleRate, 0.5)
        XCTAssertEqual(options.onErrorSampleRate, 0.8)
        XCTAssertFalse(options.maskAllText)
        XCTAssertFalse(options.maskAllImages)
        XCTAssertTrue(options.enableViewRendererV2)
        XCTAssertTrue(options.enableFastViewRendering)
    }

    func testInit_enableFastViewRenderingOmitted_shouldUseDefaultValues() {
        // -- Act --
        let options = SentryReplayOptions(
            sessionSampleRate: 0.5,
            onErrorSampleRate: 0.8,
            maskAllText: false,
            maskAllImages: false,
            enableViewRendererV2: false
        )

        // -- Assert --
        XCTAssertEqual(options.sessionSampleRate, 0.5)
        XCTAssertEqual(options.onErrorSampleRate, 0.8)
        XCTAssertFalse(options.maskAllText)
        XCTAssertFalse(options.maskAllImages)
        XCTAssertFalse(options.enableViewRendererV2)
        XCTAssertFalse(options.enableFastViewRendering)
    }

    // MARK: - Quality Options

    func testQualityDefault() {
        // This test case is used to lock down the default quality to notice if gets changed by accident.
        XCTAssertEqual(SentryReplayOptions.SentryReplayQuality.defaultQuality, .medium)
    }

    func testQuality_fromName_shouldParseKnownValues() {
        XCTAssertEqual(SentryReplayOptions.SentryReplayQuality.fromName("low"), .low)
        XCTAssertEqual(SentryReplayOptions.SentryReplayQuality.fromName("medium"), .medium)
        XCTAssertEqual(SentryReplayOptions.SentryReplayQuality.fromName("high"), .high)
        XCTAssertEqual(SentryReplayOptions.SentryReplayQuality.fromName("invalid_value"), .medium)
    }

    func testQuality_fromName_shouldReturnMediumForUnknownValues() {
        XCTAssertEqual(SentryReplayOptions.SentryReplayQuality.fromName("unknown_value"), .defaultQuality)
        XCTAssertEqual(SentryReplayOptions.SentryReplayQuality.fromName(""), .defaultQuality)
    }

    func testQualityLow() {
        // -- Act --
        let options = SentryReplayOptions()
        options.quality = .low

        // -- Assert --
        XCTAssertEqual(options.replayBitRate, 20_000)
        XCTAssertEqual(options.sizeScale, 0.8)
    }

    func testQualityMedium() {
        // -- Act --
        let options = SentryReplayOptions()
        options.quality = .medium

        // -- Assert --
        XCTAssertEqual(options.replayBitRate, 40_000)
        XCTAssertEqual(options.sizeScale, 1.0)
    }

    func testQualityHigh() {
        // -- Act --
        let options = SentryReplayOptions()
        options.quality = .high

        // -- Assert --
        XCTAssertEqual(options.replayBitRate, 60_000)
        XCTAssertEqual(options.sizeScale, 1.0)
    }

    func testQualityFromName() {
        XCTAssertEqual(SentryReplayOptions.SentryReplayQuality.fromName("low"), .low)
        XCTAssertEqual(SentryReplayOptions.SentryReplayQuality.fromName("medium"), .medium)
        XCTAssertEqual(SentryReplayOptions.SentryReplayQuality.fromName("high"), .high)
    }

    func testQualityFromName_invalidValue_shouldReturnDefaultQuality() {
        XCTAssertEqual(SentryReplayOptions.SentryReplayQuality.fromName("unknown_value"), .defaultQuality)
    }

    // MARK: - Dictionary Initialization

    func testInitFromDict_emptyDictionary_shouldUseDefaultValues() {
        // -- Act --
        let options = SentryReplayOptions(dictionary: [:])

        // -- Assert --
        XCTAssertEqual(options.sessionSampleRate, 0)
        XCTAssertEqual(options.onErrorSampleRate, 0)
        XCTAssertTrue(options.maskAllText)
        XCTAssertTrue(options.maskAllImages)
        XCTAssertTrue(options.enableViewRendererV2)
        XCTAssertFalse(options.enableFastViewRendering)

        XCTAssertEqual(options.maskedViewClasses.count, 0)
        XCTAssertEqual(options.unmaskedViewClasses.count, 0)
        XCTAssertEqual(options.quality, SentryReplayOptions.SentryReplayQuality.defaultQuality)
        XCTAssertEqual(options.frameRate, 1)
        XCTAssertEqual(options.errorReplayDuration, 30)
        XCTAssertEqual(options.sessionSegmentDuration, 5)
        XCTAssertEqual(options.maximumDuration, 60 * 60)
    }

    func testInitFromDict_allValues_shouldSetValues() throws {
        // -- Act --
        let options = SentryReplayOptions(dictionary: [
            "sessionSampleRate": 0.44,
            "errorSampleRate": 0.44,
            "maskAllText": true,
            "maskAllImages": true,
            "enableViewRendererV2": true,
            "enableFastViewRendering": false,
            "maskedViewClasses": ["NSString"],
            "unmaskedViewClasses": ["NSNumber"],
            "quality": 0,
            "frameRate": 2,
            "errorReplayDuration": 300,
            "sessionSegmentDuration": 10,
            "maximumDuration": 120
        ])

        // -- Assert --
        XCTAssertEqual(options.sessionSampleRate, 0.44)
        XCTAssertEqual(options.onErrorSampleRate, 0.44)
        XCTAssertTrue(options.maskAllText)
        XCTAssertTrue(options.maskAllImages)
        XCTAssertTrue(options.enableViewRendererV2)
        XCTAssertFalse(options.enableFastViewRendering)

        XCTAssertEqual(options.maskedViewClasses.count, 1)
        let maskedViewClass: AnyClass = try XCTUnwrap(options.maskedViewClasses.first)
        XCTAssertEqual(ObjectIdentifier(maskedViewClass), ObjectIdentifier(NSString.self))

        XCTAssertEqual(options.unmaskedViewClasses.count, 1)
        let unmaskedViewClass: AnyClass = try XCTUnwrap(options.unmaskedViewClasses.first)
        XCTAssertEqual(ObjectIdentifier(unmaskedViewClass), ObjectIdentifier(NSNumber.self))

        XCTAssertEqual(options.quality, .low)
        XCTAssertEqual(options.frameRate, 2)
        XCTAssertEqual(options.errorReplayDuration, 300)
        XCTAssertEqual(options.sessionSegmentDuration, 10)
        XCTAssertEqual(options.maximumDuration, 120)
    }

    // MARK: onErrorSampleRate

    func testInitFromDict_onErrorSampleRate_whenDoubleValue_shouldSetValue() {
        // -- Act --
        let options = SentryReplayOptions(dictionary: [
            "errorSampleRate": 0.44
        ])

        // -- Assert --
        XCTAssertEqual(options.onErrorSampleRate, 0.44)
    }

    func testInitFromDict_onErrorSampleRate_whenInvalidValue_shouldUseDefaultValue() {
        // -- Act --
        let options = SentryReplayOptions(dictionary: [
            "errorSampleRate": "0.44"
        ])

        // -- Assert --
        XCTAssertEqual(options.onErrorSampleRate, 0)
    }

    // MARK: sessionSampleRate

    func testInitFromDict_sessionSampleRate_whenDoubleValue_shouldSetValue() {
        // -- Act --
        let options = SentryReplayOptions(dictionary: [
            "sessionSampleRate": 0.44
        ])

        // -- Assert --
        XCTAssertEqual(options.sessionSampleRate, 0.44)
    }

    func testInitFromDict_sessionSampleRate_whenInvalidValue_shouldUseDefaultValue() {
        // -- Act --
        let options = SentryReplayOptions(dictionary: [
            "sessionSampleRate": "0.44"
        ])

        // -- Assert --
        XCTAssertEqual(options.sessionSampleRate, 0)
    }

    // MARK: maskedViewClasses

    func testInitFromDict_maskedViewClasses_whenValidValue_shouldSetValue() throws {
        // -- Act --
        let options = SentryReplayOptions(dictionary: [
            "maskedViewClasses": ["NSString"]
        ])

        // -- Assert --
        XCTAssertEqual(options.maskedViewClasses.count, 1)
        let maskedClass: AnyClass = try XCTUnwrap(options.maskedViewClasses.first)
        XCTAssertEqual(ObjectIdentifier(maskedClass), ObjectIdentifier(NSString.self))
    }

    func testInitFromDict_maskedViewClasses_whenMultipleValidValue_shouldKeepAll() throws {
        // -- Act --
        let options = SentryReplayOptions(dictionary: [
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
        let options = SentryReplayOptions(dictionary: [
            "maskedViewClasses": "invalid_value"
        ])

        // -- Assert --
        XCTAssertEqual(options.maskedViewClasses.count, 0)
    }

    func testInitFromDict_maskedViewClasses_whenInvalidArrayValue_shouldFilterInvalidValues() throws {
        // -- Act --
        let options = SentryReplayOptions(dictionary: [
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
        let options = SentryReplayOptions(dictionary: [
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
        let options = SentryReplayOptions(dictionary: [:])

        // -- Assert --
        XCTAssertEqual(options.maskedViewClasses.count, 0)
    }

    // MARK: unmaskedViewClasses

    func testInitFromDict_unmaskedViewClasses_whenValidValue_shouldSetValue() throws {
        // -- Act --
        let options = SentryReplayOptions(dictionary: [
            "unmaskedViewClasses": ["NSString"]
        ])

        // -- Assert --
        XCTAssertEqual(options.unmaskedViewClasses.count, 1)
        let unmaskedClass: AnyClass = try XCTUnwrap(options.unmaskedViewClasses.first)
        XCTAssertEqual(ObjectIdentifier(unmaskedClass), ObjectIdentifier(NSString.self))
    }
    
    func testInitFromDict_unmaskedViewClasses_whenMultipleValidValue_shouldKeepAll() throws {
        // -- Act --
        let options = SentryReplayOptions(dictionary: [
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
        let options = SentryReplayOptions(dictionary: [
            "unmaskedViewClasses": "invalid_value"
        ])

        // -- Assert --
        XCTAssertEqual(options.unmaskedViewClasses.count, 0)
    }

    func testInitFromDict_unmaskedViewClasses_whenInvalidArrayValues_shouldUseDefaultValue() throws {
        // -- Act --
        let options = SentryReplayOptions(dictionary: [
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
        let options = SentryReplayOptions(dictionary: [
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
        let options = SentryReplayOptions(dictionary: [:])

        // -- Assert --
        XCTAssertEqual(options.unmaskedViewClasses.count, 0)
    }

    // MARK: maskAllText

    func testInitFromDict_maskAllText_whenValidValue_shouldSetValue() {
        // -- Act --
        let options = SentryReplayOptions(dictionary: [
            "maskAllText": true
        ])

        // -- Assert --
        XCTAssertTrue(options.maskAllText)

        let options2 = SentryReplayOptions(dictionary: [
            "maskAllText": false
        ])

        // -- Assert --
        XCTAssertFalse(options2.maskAllText)
    }

    func testInitFromDict_maskAllText_whenNotValidValue_shouldUseDefaultValue() {
        // -- Act --
        let options = SentryReplayOptions(dictionary: [
            "maskAllText": "invalid_value"
        ])

        // -- Assert --
        XCTAssertTrue(options.maskAllText)
    }

    func testInitFromDict_maskAllImages_whenValidValue_shouldSetValue() {
        // -- Act --
        let options = SentryReplayOptions(dictionary: [
            "maskAllImages": true
        ])

        // -- Assert --
        XCTAssertTrue(options.maskAllImages)

        let options2 = SentryReplayOptions(dictionary: [
            "maskAllImages": false
        ])

        // -- Assert --
        XCTAssertFalse(options2.maskAllImages)
    }

    func testInitFromDict_maskAllImages_whenNotValidValue_shouldUseDefaultValue() {
        // -- Act --
        let options = SentryReplayOptions(dictionary: [
            "maskAllImages": "invalid_value"
        ])

        // -- Assert --
        XCTAssertTrue(options.maskAllImages)
    }
    
    // MARK: enableViewRendererV2
    
    func testInitFromDict_enableViewRendererV2_whenValidValue_shouldSetValue() {
        // -- Act --
        let options = SentryReplayOptions(dictionary: [
            "enableViewRendererV2": true
        ])

        // -- Assert --
        XCTAssertTrue(options.enableViewRendererV2)

        let options2 = SentryReplayOptions(dictionary: [
            "enableViewRendererV2": false
        ])

        // -- Assert --
        XCTAssertFalse(options2.enableViewRendererV2)
    }

    func testInitFromDict_enableViewRendererV2_whenInvalidValue_shouldUseDefaultValue() {
        // -- Act --
        let options = SentryReplayOptions(dictionary: [
            "enableViewRendererV2": "invalid_value"
        ])

        // -- Assert --
        XCTAssertTrue(options.enableViewRendererV2)
    }
    
    func testInitFromDict_enableViewRendererV2_whenNotSpecified_shouldUseDefaultValue() {
        // -- Act --
        let options = SentryReplayOptions(dictionary: [:])

        // -- Assert --
        XCTAssertTrue(options.enableViewRendererV2)
    }
    
    func testInitFromDict_enableViewRendererV2_precedenceOverEnableExperimentalViewRenderer() {
        // -- Act --
        let options = SentryReplayOptions(dictionary: [
            "enableViewRendererV2": false,
            "enableExperimentalViewRenderer": true
        ])

        // -- Assert --
        XCTAssertFalse(options.enableViewRendererV2)
    }
    
    func testInitFromDict_enableExperimentalViewRenderer_whenValidValue_shouldSetValue() {
        // To support backwards compatibility we keep support for the old key
        // "experimentalViewRenderer" until we remove it in a future version.

        // -- Act --
        let options = SentryReplayOptions(dictionary: [
            "enableExperimentalViewRenderer": true
        ])

        // -- Assert --
        XCTAssertTrue(options.enableViewRendererV2)

        let options2 = SentryReplayOptions(dictionary: [
            "enableExperimentalViewRenderer": false
        ])

        // -- Assert --
        XCTAssertTrue(options.enableViewRendererV2)
        XCTAssertFalse(options2.enableViewRendererV2)
    }

    func testInitFromDict_enableExperimentalViewRenderer_whenInvalidValue_shouldUseDefaultValue() {
        // To support backwards compatibility we keep support for the old key
        // "experimentalViewRenderer" until we remove it in a future version.

        // -- Act --
        let options = SentryReplayOptions(dictionary: [
            "enableExperimentalViewRenderer": "invalid_value"
        ])

        // -- Assert --
        XCTAssertTrue(options.enableViewRendererV2)
    }

    func testInitFromDict_enableViewRendererV2WithBool_shouldIgnoreValue() {
        // -- Act --
        let options = SentryReplayOptions(dictionary: [
            "enableExperimentalViewRenderer": true
        ])
        let options2 = SentryReplayOptions(dictionary: [
            "enableExperimentalViewRenderer": false
        ])

        // -- Assert --
        XCTAssertTrue(options.enableViewRendererV2)
        XCTAssertFalse(options2.enableViewRendererV2)
    }

    func testInitFromDict_enableViewRendererV2WithString_shouldIgnoreValue() {
        // -- Act --
        let options = SentryReplayOptions(dictionary: [
            "enableExperimentalViewRenderer": "invalid_value"
        ])

        // -- Assert --
        XCTAssertTrue(options.enableViewRendererV2)
    }

    func testInitFromDict_enableFastViewRendering_whenValidValue_shouldSetValue() {
        let options = SentryReplayOptions(dictionary: [
            "enableFastViewRendering": true
        ])
        XCTAssertTrue(options.enableFastViewRendering)

        let options2 = SentryReplayOptions(dictionary: [
            "enableFastViewRendering": false
        ])
        XCTAssertFalse(options2.enableFastViewRendering)
    }

    func testInitFromDict_enableFastViewRendering_whenInvalidValue_shouldUseDefaultValue() {
        let options = SentryReplayOptions(dictionary: [
            "enableFastViewRendering": "invalid_value"
        ])
        XCTAssertFalse(options.enableFastViewRendering)
    }

    func testInitFromDict_quality_whenValidValue_shouldSetValue() {
        let options = SentryReplayOptions(dictionary: [
            "quality": 0 // low
        ])
        XCTAssertEqual(options.quality, .low)

        let options2 = SentryReplayOptions(dictionary: [
            "quality": 1 // medium
        ])
        XCTAssertEqual(options2.quality, .medium)

        let options3 = SentryReplayOptions(dictionary: [
            "quality": 2 // high
        ])
        XCTAssertEqual(options3.quality, .high)
    }

    func testInitFromDict_quality_whenInvalidValue_shouldUseDefaultValue() {
        let options = SentryReplayOptions(dictionary: [
            "quality": "invalid_value"
        ])
        XCTAssertEqual(options.quality, .medium)

        let options2 = SentryReplayOptions(dictionary: [
            "quality": [1]
        ])
        XCTAssertEqual(options2.quality, .medium)
    }

    func testInitFromDict_withMultipleOptions_shouldSetAllValues() {
        let options = SentryReplayOptions(dictionary: [
            "sessionSampleRate": 0.5,
            "errorSampleRate": 0.8,
            "maskAllText": false,
            "maskedViewClasses": ["NSString", "not.a.class", 123] as [Any],
            "unmaskedViewClasses": ["NSNumber", "invalid", true] as [Any],
            "quality": 0 // low
        ])

        XCTAssertEqual(options.sessionSampleRate, 0.5)
        XCTAssertEqual(options.onErrorSampleRate, 0.8)
        XCTAssertFalse(options.maskAllText)
        XCTAssertTrue(options.maskAllImages)
        XCTAssertTrue(options.enableViewRendererV2)
        XCTAssertFalse(options.enableFastViewRendering)
        XCTAssertEqual(options.maskedViewClasses.count, 1)
        XCTAssertEqual(ObjectIdentifier(options.maskedViewClasses.first!), ObjectIdentifier(NSString.self))
        XCTAssertEqual(options.unmaskedViewClasses.count, 1)
        XCTAssertEqual(ObjectIdentifier(options.unmaskedViewClasses.first!), ObjectIdentifier(NSNumber.self))
        XCTAssertEqual(options.quality, .low)
    }

    @available(*, deprecated, message: "The test is marked as deprecated to silence the deprecation warning of the tested property.")
    func testExperimentalViewRenderer_shouldBeAnAliasForEnableViewRendererV2() {
        // -- Arrange --
        let options = SentryReplayOptions()
        options.enableViewRendererV2 = false
        options.enableExperimentalViewRenderer = false

        // -- Act & Assert --
        XCTAssertFalse(options.enableViewRendererV2)
        XCTAssertFalse(options.enableExperimentalViewRenderer)

        options.enableViewRendererV2 = true
        
        XCTAssertTrue(options.enableViewRendererV2)
        XCTAssertTrue(options.enableExperimentalViewRenderer)

        options.enableExperimentalViewRenderer = false

        XCTAssertFalse(options.enableViewRendererV2)
        XCTAssertFalse(options.enableExperimentalViewRenderer)
    }

    // MARK: frameRate

    func testInitFromDict_frameRate_whenValidValue_shouldSetValue() {
        // -- Act --
        let options = SentryReplayOptions(dictionary: [
            "frameRate": 5
        ])

        // -- Assert --
        XCTAssertEqual(options.frameRate, 5)
    }

    func testInitFromDict_frameRate_whenInvalidValue_shouldUseDefaultValue() {
        // -- Act --
        let options = SentryReplayOptions(dictionary: [
            "frameRate": "invalid_value"
        ])

        // -- Assert --
        XCTAssertEqual(options.frameRate, 1)
    }

    func testFrameRate_whenSetToZero_shouldBeSetToOne() {
        // -- Arrange --
        let options = SentryReplayOptions()
        
        // -- Act --
        options.frameRate = 0
        
        // -- Assert --
        XCTAssertEqual(options.frameRate, 1)
    }

    // MARK: errorReplayDuration

    func testInitFromDict_errorReplayDuration_whenValidValue_shouldSetValue() {
        // -- Act --
        let options = SentryReplayOptions(dictionary: [
            "errorReplayDuration": 60
        ])

        // -- Assert --
        XCTAssertEqual(options.errorReplayDuration, 60)
    }

    func testInitFromDict_errorReplayDuration_whenInvalidValue_shouldUseDefaultValue() {
        // -- Act --
        let options = SentryReplayOptions(dictionary: [
            "errorReplayDuration": "invalid_value"
        ])

        // -- Assert --
        XCTAssertEqual(options.errorReplayDuration, 30)
    }

    // MARK: sessionSegmentDuration

    func testInitFromDict_sessionSegmentDuration_whenValidValue_shouldSetValue() {
        // -- Act --
        let options = SentryReplayOptions(dictionary: [
            "sessionSegmentDuration": 10
        ])

        // -- Assert --
        XCTAssertEqual(options.sessionSegmentDuration, 10)
    }

    func testInitFromDict_sessionSegmentDuration_whenInvalidValue_shouldUseDefaultValue() {
        // -- Act --
        let options = SentryReplayOptions(dictionary: [
            "sessionSegmentDuration": "invalid_value"
        ])

        // -- Assert --
        XCTAssertEqual(options.sessionSegmentDuration, 5)
    }

    // MARK: maximumDuration

    func testInitFromDict_maximumDuration_whenValidValue_shouldSetValue() {
        // -- Act --
        let options = SentryReplayOptions(dictionary: [
            "maximumDuration": 120
        ])

        // -- Assert --
        XCTAssertEqual(options.maximumDuration, 120)
    }

    func testInitFromDict_maximumDuration_whenInvalidValue_shouldUseDefaultValue() {
        // -- Act --
        let options = SentryReplayOptions(dictionary: [
            "maximumDuration": "invalid_value"
        ])

        // -- Assert --
        XCTAssertEqual(options.maximumDuration, 60 * 60)
    }
    
    // MARK: sdkInfo
    
    func testInitFromDict_sdkInfo_whenValidValue_shouldSetValue() {
        // -- Act --
        let sdkInfo: [String: Any] = ["name": "sentry.cocoa", "version": "1.0.0"]
        let options = SentryReplayOptions(dictionary: [
            "sdkInfo": sdkInfo
        ])

        // -- Assert --
        XCTAssertNotNil(options.sdkInfo)
        XCTAssertEqual(options.sdkInfo?["name"] as? String, "sentry.cocoa")
        XCTAssertEqual(options.sdkInfo?["version"] as? String, "1.0.0")
    }
    
    func testInitFromDict_sdkInfo_whenInvalidValue_shouldUseDefaultValue() {
        // -- Act --
        let options = SentryReplayOptions(dictionary: [
            "sdkInfo": "invalid_value"
        ])

        // -- Assert --
        XCTAssertNil(options.sdkInfo)
    }
}
