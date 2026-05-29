import Foundation

#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif

@testable import SentryObjCCompat
import XCTest

// swiftlint:disable type_body_length file_length

final class SentryObjCCompatEnumConversionTests: XCTestCase {

    // MARK: - SentryObjCLastRunStatus

    func testLastRunStatusInit_whenEachCase_shouldMapCorrectly() {
        // -- Arrange --
        let cases: [(SentryLastRunStatus, SentryObjCLastRunStatus)] = [
            (.unknown, .unknown),
            (.didNotCrash, .didNotCrash),
            (.didCrash, .didCrash)
        ]

        for (underlying, expected) in cases {
            // -- Act --
            let result = SentryObjCLastRunStatus(underlying)

            // -- Assert --
            XCTAssertEqual(result, expected, "Expected \(expected) for underlying \(underlying)")
        }
    }

    func testLastRunStatusUnderlying_whenEachCase_shouldRoundTrip() {
        // -- Arrange --
        let cases: [(SentryObjCLastRunStatus, SentryLastRunStatus)] = [
            (.unknown, .unknown),
            (.didNotCrash, .didNotCrash),
            (.didCrash, .didCrash)
        ]

        for (objcCase, expected) in cases {
            // -- Act --
            let result = objcCase.underlying

            // -- Assert --
            XCTAssertEqual(result, expected, "Expected \(expected) for ObjC case \(objcCase)")
        }
    }

    // MARK: - SentryObjCSpanStatus

    func testSpanStatusInit_whenEachCase_shouldMapCorrectly() {
        // -- Arrange --
        let cases: [(SentrySpanStatus, SentryObjCSpanStatus)] = [
            (.undefined, .undefined),
            (.ok, .ok),
            (.deadlineExceeded, .deadlineExceeded),
            (.unauthenticated, .unauthenticated),
            (.permissionDenied, .permissionDenied),
            (.notFound, .notFound),
            (.resourceExhausted, .resourceExhausted),
            (.invalidArgument, .invalidArgument),
            (.unimplemented, .unimplemented),
            (.unavailable, .unavailable),
            (.internalError, .internalError),
            (.unknownError, .unknownError),
            (.cancelled, .cancelled),
            (.alreadyExists, .alreadyExists),
            (.failedPrecondition, .failedPrecondition),
            (.aborted, .aborted),
            (.outOfRange, .outOfRange),
            (.dataLoss, .dataLoss)
        ]

        for (underlying, expected) in cases {
            // -- Act --
            let result = SentryObjCSpanStatus(underlying)

            // -- Assert --
            XCTAssertEqual(result, expected, "Expected \(expected) for underlying \(underlying)")
        }
    }

    func testSpanStatusUnderlying_whenEachCase_shouldRoundTrip() {
        // -- Arrange --
        let cases: [(SentryObjCSpanStatus, SentrySpanStatus)] = [
            (.undefined, .undefined),
            (.ok, .ok),
            (.deadlineExceeded, .deadlineExceeded),
            (.unauthenticated, .unauthenticated),
            (.permissionDenied, .permissionDenied),
            (.notFound, .notFound),
            (.resourceExhausted, .resourceExhausted),
            (.invalidArgument, .invalidArgument),
            (.unimplemented, .unimplemented),
            (.unavailable, .unavailable),
            (.internalError, .internalError),
            (.unknownError, .unknownError),
            (.cancelled, .cancelled),
            (.alreadyExists, .alreadyExists),
            (.failedPrecondition, .failedPrecondition),
            (.aborted, .aborted),
            (.outOfRange, .outOfRange),
            (.dataLoss, .dataLoss)
        ]

        for (objcCase, expected) in cases {
            // -- Act --
            let result = objcCase.underlying

            // -- Assert --
            XCTAssertEqual(result, expected, "Expected \(expected) for ObjC case \(objcCase)")
        }
    }

    // MARK: - SentryObjCReplayQuality

    func testReplayQualityInit_whenEachCase_shouldMapCorrectly() {
        // -- Arrange --
        let cases: [(SentryReplayOptions.SentryReplayQuality, SentryObjCReplayQuality)] = [
            (.low, .low),
            (.medium, .medium),
            (.high, .high)
        ]

        for (underlying, expected) in cases {
            // -- Act --
            let result = SentryObjCReplayQuality(underlying)

            // -- Assert --
            XCTAssertEqual(result, expected, "Expected \(expected) for underlying \(underlying)")
        }
    }

    func testReplayQualityUnderlying_whenEachCase_shouldRoundTrip() {
        // -- Arrange --
        let cases: [(SentryObjCReplayQuality, SentryReplayOptions.SentryReplayQuality)] = [
            (.low, .low),
            (.medium, .medium),
            (.high, .high)
        ]

        for (objcCase, expected) in cases {
            // -- Act --
            let result = objcCase.underlying

            // -- Assert --
            XCTAssertEqual(result, expected, "Expected \(expected) for ObjC case \(objcCase)")
        }
    }

    // MARK: - SentryObjCTransactionNameSource

    func testTransactionNameSourceInit_whenEachCase_shouldMapCorrectly() {
        // -- Arrange --
        let cases: [(SentryTransactionNameSource, SentryObjCTransactionNameSource)] = [
            (.custom, .custom),
            (.url, .url),
            (.route, .route),
            (.view, .view),
            (.component, .component),
            (.sourceTask, .task)
        ]

        for (underlying, expected) in cases {
            // -- Act --
            let result = SentryObjCTransactionNameSource(underlying)

            // -- Assert --
            XCTAssertEqual(result, expected, "Expected \(expected) for underlying \(underlying)")
        }
    }

    func testTransactionNameSourceUnderlying_whenEachCase_shouldRoundTrip() {
        // -- Arrange --
        let cases: [(SentryObjCTransactionNameSource, SentryTransactionNameSource)] = [
            (.custom, .custom),
            (.url, .url),
            (.route, .route),
            (.view, .view),
            (.component, .component),
            (.task, .sourceTask)
        ]

        for (objcCase, expected) in cases {
            // -- Act --
            let result = objcCase.underlying

            // -- Assert --
            XCTAssertEqual(result, expected, "Expected \(expected) for ObjC case \(objcCase)")
        }
    }

    // MARK: - SentryObjCLevel

    func testLevelInit_whenEachCase_shouldMapCorrectly() {
        // -- Arrange --
        let cases: [(SentryLevel, SentryObjCLevel)] = [
            (.none, .none),
            (.debug, .debug),
            (.info, .info),
            (.warning, .warning),
            (.error, .error),
            (.fatal, .fatal)
        ]

        for (underlying, expected) in cases {
            // -- Act --
            let result = SentryObjCLevel(underlying)

            // -- Assert --
            XCTAssertEqual(result, expected, "Expected \(expected) for underlying \(underlying)")
        }
    }

    func testLevelUnderlying_whenEachCase_shouldRoundTrip() {
        // -- Arrange --
        let cases: [(SentryObjCLevel, SentryLevel)] = [
            (.none, .none),
            (.debug, .debug),
            (.info, .info),
            (.warning, .warning),
            (.error, .error),
            (.fatal, .fatal)
        ]

        for (objcCase, expected) in cases {
            // -- Act --
            let result = objcCase.underlying

            // -- Assert --
            XCTAssertEqual(result, expected, "Expected \(expected) for ObjC case \(objcCase)")
        }
    }

    // MARK: - SentryObjCSampleDecision

    func testSampleDecisionInit_whenEachCase_shouldMapCorrectly() {
        // -- Arrange --
        let cases: [(SentrySampleDecision, SentryObjCSampleDecision)] = [
            (.undecided, .undecided),
            (.yes, .yes),
            (.no, .no)
        ]

        for (underlying, expected) in cases {
            // -- Act --
            let result = SentryObjCSampleDecision(underlying)

            // -- Assert --
            XCTAssertEqual(result, expected, "Expected \(expected) for underlying \(underlying)")
        }
    }

    func testSampleDecisionUnderlying_whenEachCase_shouldRoundTrip() {
        // -- Arrange --
        let cases: [(SentryObjCSampleDecision, SentrySampleDecision)] = [
            (.undecided, .undecided),
            (.yes, .yes),
            (.no, .no)
        ]

        for (objcCase, expected) in cases {
            // -- Act --
            let result = objcCase.underlying

            // -- Assert --
            XCTAssertEqual(result, expected, "Expected \(expected) for ObjC case \(objcCase)")
        }
    }

    // MARK: - SentryObjCFeedbackSource

    func testFeedbackSourceInit_whenEachCase_shouldMapCorrectly() {
        // -- Arrange --
        let cases: [(SentryFeedback.SentryFeedbackSource, SentryObjCFeedbackSource)] = [
            (.widget, .widget),
            (.custom, .custom)
        ]

        for (underlying, expected) in cases {
            // -- Act --
            let result = SentryObjCFeedbackSource(underlying)

            // -- Assert --
            XCTAssertEqual(result, expected, "Expected \(expected) for underlying \(underlying)")
        }
    }

    func testFeedbackSourceUnderlying_whenEachCase_shouldRoundTrip() {
        // -- Arrange --
        let cases: [(SentryObjCFeedbackSource, SentryFeedback.SentryFeedbackSource)] = [
            (.widget, .widget),
            (.custom, .custom)
        ]

        for (objcCase, expected) in cases {
            // -- Act --
            let result = objcCase.underlying

            // -- Assert --
            XCTAssertEqual(result, expected, "Expected \(expected) for ObjC case \(objcCase)")
        }
    }

    // MARK: - SentryObjCAttachmentType

    func testAttachmentTypeInit_whenEachCase_shouldMapCorrectly() {
        // -- Arrange --
        let cases: [(SentryAttachmentType, SentryObjCAttachmentType)] = [
            (.eventAttachment, .eventAttachment),
            (.viewHierarchy, .viewHierarchy)
        ]

        for (underlying, expected) in cases {
            // -- Act --
            let result = SentryObjCAttachmentType(underlying)

            // -- Assert --
            XCTAssertEqual(result, expected, "Expected \(expected) for underlying \(underlying)")
        }
    }

    func testAttachmentTypeUnderlying_whenEachCase_shouldRoundTrip() {
        // -- Arrange --
        let cases: [(SentryObjCAttachmentType, SentryAttachmentType)] = [
            (.eventAttachment, .eventAttachment),
            (.viewHierarchy, .viewHierarchy)
        ]

        for (objcCase, expected) in cases {
            // -- Act --
            let result = objcCase.underlying

            // -- Assert --
            XCTAssertEqual(result, expected, "Expected \(expected) for ObjC case \(objcCase)")
        }
    }

    // MARK: - SentryObjCLogLevel

    func testLogLevelInit_whenEachCase_shouldMapCorrectly() {
        // -- Arrange --
        let cases: [(SentryLog.Level, SentryObjCLogLevel)] = [
            (.trace, .trace),
            (.debug, .debug),
            (.info, .info),
            (.warn, .warn),
            (.error, .error),
            (.fatal, .fatal)
        ]

        for (underlying, expected) in cases {
            // -- Act --
            let result = SentryObjCLogLevel(underlying)

            // -- Assert --
            XCTAssertEqual(result, expected, "Expected \(expected) for underlying \(underlying)")
        }
    }

    func testLogLevelUnderlying_whenEachCase_shouldRoundTrip() {
        // -- Arrange --
        let cases: [(SentryObjCLogLevel, SentryLog.Level)] = [
            (.trace, .trace),
            (.debug, .debug),
            (.info, .info),
            (.warn, .warn),
            (.error, .error),
            (.fatal, .fatal)
        ]

        for (objcCase, expected) in cases {
            // -- Act --
            let result = objcCase.underlying

            // -- Assert --
            XCTAssertEqual(result, expected, "Expected \(expected) for ObjC case \(objcCase)")
        }
    }

    // MARK: - SentryObjCRedactRegionType

    func testRedactRegionTypeInit_whenEachCase_shouldMapCorrectly() {
        // -- Arrange --
        let cases: [(SentryRedactRegionType, SentryObjCRedactRegionType)] = [
            (.redact, .redact),
            (.clipOut, .clipOut),
            (.clipBegin, .clipBegin),
            (.clipEnd, .clipEnd),
            (.redactSwiftUI, .redactSwiftUI)
        ]

        for (underlying, expected) in cases {
            // -- Act --
            let result = SentryObjCRedactRegionType(underlying)

            // -- Assert --
            XCTAssertEqual(result, expected, "Expected \(expected) for underlying \(underlying)")
        }
    }

    func testRedactRegionTypeUnderlying_whenEachCase_shouldRoundTrip() {
        // -- Arrange --
        let cases: [(SentryObjCRedactRegionType, SentryRedactRegionType)] = [
            (.redact, .redact),
            (.clipOut, .clipOut),
            (.clipBegin, .clipBegin),
            (.clipEnd, .clipEnd),
            (.redactSwiftUI, .redactSwiftUI)
        ]

        for (objcCase, expected) in cases {
            // -- Act --
            let result = objcCase.underlying

            // -- Assert --
            XCTAssertEqual(result, expected, "Expected \(expected) for ObjC case \(objcCase)")
        }
    }
}

// swiftlint:enable type_body_length file_length
