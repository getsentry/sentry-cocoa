import Foundation
@testable import Sentry
import XCTest

class SentryReplayOptionsTests: XCTestCase {
    
    func testQualityLow() {
        let options = SentryReplayOptions()
        options.quality = .low
        
        XCTAssertEqual(options.replayBitRate, 20_000)
        XCTAssertEqual(options.sizeScale, 0.8)
    }
    
    func testQualityMedium() {
        let options = SentryReplayOptions()
        options.quality = .medium
        
        XCTAssertEqual(options.replayBitRate, 40_000)
        XCTAssertEqual(options.sizeScale, 1.0)
    }
    
    func testQualityHigh() {
        let options = SentryReplayOptions()
        options.quality = .high
        
        XCTAssertEqual(options.replayBitRate, 60_000)
        XCTAssertEqual(options.sizeScale, 1.0)
    }

    func testQualityFromName() {
        XCTAssertEqual(SentryReplayOptions.SentryReplayQuality.fromName("low"), .low)
        XCTAssertEqual(SentryReplayOptions.SentryReplayQuality.fromName("medium"), .medium)
        XCTAssertEqual(SentryReplayOptions.SentryReplayQuality.fromName("high"), .high)
        XCTAssertEqual(SentryReplayOptions.SentryReplayQuality.fromName("invalid_value"), .medium)
    }

    func testInitFromDictOnErrorSampleRateAsDouble() {
        let options = SentryReplayOptions(dictionary: [
            "errorSampleRate": 0.44
        ])

        XCTAssertEqual(options.onErrorSampleRate, 0.44)
    }

    func testInitFromDictOnErrorSampleRateMissing() {
        let options = SentryReplayOptions(dictionary: [:])

        XCTAssertEqual(options.onErrorSampleRate, 0)
    }

    func testInitFromDictOnErrorSampleRateAsString() {
        let options = SentryReplayOptions(dictionary: [
            "onErrorSampleRate": "0.44"
        ])

        XCTAssertEqual(options.onErrorSampleRate, 0)
    }

    func testInitFromDictSessionSampleRateAsDouble() {
        let options = SentryReplayOptions(dictionary: [
            "sessionSampleRate": 0.44
        ])

        XCTAssertEqual(options.sessionSampleRate, 0.44)
    }

    func testInitFromDictSessionSampleRateMissing() {
        let options = SentryReplayOptions(dictionary: [:])

        XCTAssertEqual(options.sessionSampleRate, 0)
    }

    func testInitFromDictSessionSampleRateAsString() {
        let options = SentryReplayOptions(dictionary: [
            "sessionSampleRate": "0.44"
        ])

        XCTAssertEqual(options.sessionSampleRate, 0)
    }

    func testInitFromDictMaskedViewClasses() {
        let options = SentryReplayOptions(dictionary: [
            "maskedViewClasses": ["NSString"]
        ])

        XCTAssertEqual(options.maskedViewClasses.count, 1)
        XCTAssertEqual(ObjectIdentifier(options.maskedViewClasses.first!), ObjectIdentifier(NSString.self))
    }

    func testInitFromDictMaskedViewClassesAsString() {
        let options = SentryReplayOptions(dictionary: [
            "maskedViewClasses": "ExampleView1"
        ])

        XCTAssertEqual(options.maskedViewClasses.count, 0)
    }

    func testInitFromDictMaskedViewClassesWithNumber() {
        let options = SentryReplayOptions(dictionary: [
            "maskedViewClasses": [123]
        ])

        XCTAssertEqual(options.maskedViewClasses.count, 0)
    }

    func testInitFromDictUnmaskedViewClasses() {
        let options = SentryReplayOptions(dictionary: [
            "unmaskedViewClasses": ["NSString"]
        ])

        XCTAssertEqual(options.unmaskedViewClasses.count, 1)
        XCTAssertEqual(ObjectIdentifier(options.unmaskedViewClasses.first!), ObjectIdentifier(NSString.self))
    }

    func testInitFromDictUnmaskedViewClassesAsString() {
        let options = SentryReplayOptions(dictionary: [
            "unmaskedViewClasses": "invalid_value"
        ])

        XCTAssertEqual(options.unmaskedViewClasses.count, 0)
    }

    func testInitFromDictUnmaskedViewClassesWithInvalidValues() {
        let options = SentryReplayOptions(dictionary: [
            "unmaskedViewClasses": [123, "not.class"] as [Any]
        ])

        XCTAssertEqual(options.unmaskedViewClasses.count, 0)
    }

    func testInitFromDictMaskAllTextWithBool() {
        let options = SentryReplayOptions(dictionary: [
            "maskAllText": true
        ])
        XCTAssertTrue(options.maskAllText)

        let options2 = SentryReplayOptions(dictionary: [
            "maskAllText": false
        ])
        XCTAssertFalse(options2.maskAllText)
    }

    func testInitFromDictMaskAllTextWithString() {
        let options = SentryReplayOptions(dictionary: [
            "maskAllText": "invalid_value"
        ])
        XCTAssertTrue(options.maskAllText)
    }

    func testInitFromDictMaskAllImagesWithBool() {
        let options = SentryReplayOptions(dictionary: [
            "maskAllImages": true
        ])
        XCTAssertTrue(options.maskAllImages)

        let options2 = SentryReplayOptions(dictionary: [
            "maskAllImages": false
        ])
        XCTAssertFalse(options2.maskAllImages)
    }

    func testInitFromDictMaskAllImagesWithString() {
        let options = SentryReplayOptions(dictionary: [
            "maskAllImages": "invalid_value"
        ])
        XCTAssertTrue(options.maskAllImages)
    }

    func testInitFromDictQualityWithString() {
        let options = SentryReplayOptions(dictionary: [
            "quality": "low"
        ])
        XCTAssertEqual(options.quality, .low)

        let options2 = SentryReplayOptions(dictionary: [
            "quality": "medium"
        ])
        XCTAssertEqual(options2.quality, .medium)

        let options3 = SentryReplayOptions(dictionary: [
            "quality": "high"
        ])
        XCTAssertEqual(options3.quality, .high)
    }

    func testInitFromDictQualityWithInvalidValue() {
        let options = SentryReplayOptions(dictionary: [
            "quality": "invalid_value"
        ])
        XCTAssertEqual(options.quality, .medium)

        let options2 = SentryReplayOptions(dictionary: [
            "quality": [1]
        ])
        XCTAssertEqual(options2.quality, .medium)
    }

    func testInitFromDictWithMultipleOptions() {
        let options = SentryReplayOptions(dictionary: [
            "sessionSampleRate": 0.5,
            "errorSampleRate": 0.8,
            "maskAllText": false,
            "maskedViewClasses": ["NSString", "not.a.class", 123] as [Any],
            "unmaskedViewClasses": ["NSNumber", "invalid", true] as [Any],
            "quality": "low"
        ])

        XCTAssertEqual(options.sessionSampleRate, 0.5)
        XCTAssertEqual(options.onErrorSampleRate, 0.8)
        XCTAssertFalse(options.maskAllText)
        XCTAssertTrue(options.maskAllImages)
        XCTAssertEqual(options.maskedViewClasses.count, 1)
        XCTAssertEqual(ObjectIdentifier(options.maskedViewClasses.first!), ObjectIdentifier(NSString.self))
        XCTAssertEqual(options.unmaskedViewClasses.count, 1)
        XCTAssertEqual(ObjectIdentifier(options.unmaskedViewClasses.first!), ObjectIdentifier(NSNumber.self))
        XCTAssertEqual(options.quality, .low)
    }

}
