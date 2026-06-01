@_implementationOnly import _SentryPrivate
import KSCrashRecording
import XCTest

final class KSCrashReportSinkTests: XCTestCase {

    func test_filterReports_emptyArray_callsCompletionWithNoError() {
        let logic = SentryInAppLogic(inAppIncludes: [])
        let sink = KSCrashReportSink(inAppLogic: logic)
        let expectation = expectation(description: "completion")
        sink.filterReports([]) { _, error in
            XCTAssertNil(error)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
    }

    func test_filterReports_nonDictionaryReport_isSkipped() {
        let logic = SentryInAppLogic(inAppIncludes: [])
        let sink = KSCrashReportSink(inAppLogic: logic)
        let stringReport = CrashReportString.report(withValue: "{}")
        let expectation = expectation(description: "completion")
        sink.filterReports([stringReport]) { _, error in
            XCTAssertNil(error)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
    }

    func test_filterReports_emptyDictionaryReport_noClientSet_doesNotCrash() {
        // With no Sentry client configured, the sink should handle an empty report
        // gracefully (the converter will return nil) and still call completion.
        let logic = SentryInAppLogic(inAppIncludes: [])
        let sink = KSCrashReportSink(inAppLogic: logic)
        let report = CrashReportDictionary.report(withValue: [:])
        let expectation = expectation(description: "completion")
        sink.filterReports([report]) { _, error in
            XCTAssertNil(error)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
    }
}
