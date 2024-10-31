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
            "maskedViewClasses": ["UILabel"]
        ])

        XCTAssertEqual(options.maskedViewClasses.count, 1)
        XCTAssertEqual(ObjectIdentifier(options.maskedViewClasses[0]), ObjectIdentifier(UILabel.self))
    }

    func testInitFromDictMaskedViewClassesAsString() {
        let options = SentryReplayOptions(dictionary: [
            "maskedViewClasses": "UILabel"
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
            "unmaskedViewClasses": ["UILabel"]
        ])

        XCTAssertEqual(options.unmaskedViewClasses.count, 1)
        XCTAssertEqual(ObjectIdentifier(options.unmaskedViewClasses.first as AnyClass), ObjectIdentifier(UILabel.self))
    }

    func testInitFromDictUnmaskedViewClassesAsString() {
        let options = SentryReplayOptions(dictionary: [
            "unmaskedViewClasses": "invalid_value"
        ])

        XCTAssertEqual(options.unmaskedViewClasses.count, 0)
    }

    func testInitFromDictUnmaskedViewClassesWithInvalidValues() {
        let options = SentryReplayOptions(dictionary: [
            "unmaskedViewClasses": [123, "not.class"]
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

    func testInitFromDictWithMultipleOptions() {
        let options = SentryReplayOptions(dictionary: [
            "sessionSampleRate": 0.5,
            "errorSampleRate": 0.8,
            "maskAllText": false,
            "maskedViewClasses": ["UIView", "not.a.class", 123],
            "unmaskedViewClasses": ["UILabel", "invalid", true]
        ])

        XCTAssertEqual(options.sessionSampleRate, 0.5)
        XCTAssertEqual(options.onErrorSampleRate, 0.8)
        XCTAssertFalse(options.maskAllText)
        XCTAssertTrue(options.maskAllImages)
        XCTAssertEqual(options.maskedViewClasses.count, 1)
        XCTAssertEqual(ObjectIdentifier(options.maskedViewClasses.first), ObjectIdentifier(UIView.self))
        XCTAssertEqual(options.unmaskedViewClasses.count, 1)
        XCTAssertEqual(options.unmaskedViewClasses.first, UILabel.self)
    }
}
