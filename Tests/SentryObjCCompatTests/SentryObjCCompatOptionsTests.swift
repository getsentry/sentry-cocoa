import Foundation

#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif

@testable import SentryObjCCompat
import XCTest

final class SentryObjCCompatOptionsTests: XCTestCase {

    func testHangReportingMode_whenSetThroughObjCOptions_shouldUpdateSDKOptions() {
        // -- Arrange --
        let options = SentryObjCOptions()

        // -- Act --
        options.experimental.metrickit.hangReportingMode = .flamegraphAttachment

        // -- Assert --
        XCTAssertEqual(options.wrapped.experimental.metrickit.hangReportingMode, .flamegraphAttachment)

        // -- Act --
        options.experimental.metrickit.hangReportingMode = .legacy

        // -- Assert --
        XCTAssertEqual(options.wrapped.experimental.metrickit.hangReportingMode, .legacy)
    }

    #if SDK_V10 && (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
    func testPrivacy_whenWrapperIsModified_shouldUpdateBaseOptions() {
        // -- Arrange --
        let options = Options()
        let wrapper = SentryObjCOptions(options)

        // -- Act --
        wrapper.privacy.maskAllText = false
        wrapper.privacy.maskedViewClasses = [NSString.self]
        wrapper.privacy.excludeViewTypeFromSubtreeTraversal("CustomView")

        // -- Assert --
        XCTAssertFalse(options.privacy.maskAllText)
        XCTAssertEqual(options.privacy.maskedViewClasses.map(ObjectIdentifier.init), [ObjectIdentifier(NSString.self)])
        XCTAssertEqual(options.privacy.excludedViewClasses, ["CustomView"])
    }

    func testPrivacy_whenAssignedFromWrapper_shouldCopySettings() {
        // -- Arrange --
        let options = SentryObjCOptions()
        let privacy = SentryObjCPrivacyOptions()
        privacy.maskAllText = false
        options.privacy = privacy

        // -- Act --
        privacy.maskAllText = true

        // -- Assert --
        XCTAssertFalse(options.privacy.maskAllText)
        XCTAssertTrue(privacy.maskAllText)
    }
    #endif // SDK_V10 && UI platforms

    override func tearDown() {
        SentryObjCSDK.close()
        super.tearDown()
    }

    func testBeforeSendTransaction_whenTransactionFinishes_shouldReceiveTransactionAndHint() throws {
#if !SDK_V10
        throw XCTSkip("Test skipped for non SDK_V10")
#else
        // -- Arrange --
        let callbackInvoked = expectation(description: "beforeSendTransaction invoked")
        var receivedTransaction: SentryObjCTransaction?
        var receivedHint: SentryObjCHint?
        startSDK { transaction, hint in
            guard transaction.transaction == "Tap" else { return nil }
            receivedTransaction = transaction
            receivedHint = hint
            callbackInvoked.fulfill()
            return nil
        }
        SentryObjCSDK.configureScope { scope in
            scope.addAttachment(SentryObjCAttachment(data: Data("scope-data".utf8), filename: "scope.txt"))
        }

        // -- Act --
        SentryObjCSDK.startTransaction(name: "Tap", operation: "ui.action.click").finish()

        // -- Assert --
        wait(for: [callbackInvoked], timeout: 5)
        XCTAssertEqual(try XCTUnwrap(receivedTransaction).transaction, "Tap")
        let hint = try XCTUnwrap(receivedHint)
        XCTAssertEqual(hint.attachments.map(\.filename), ["scope.txt"])
        XCTAssertNil(hint.originalError)
        XCTAssertNil(hint.originalException)
#endif // !SDK_V10
    }

    func testBeforeSendTransaction_whenCallbackEditsHintAttachments_shouldApplyToWrappedHint() throws {
#if !SDK_V10
        throw XCTSkip("Test skipped for non SDK_V10")
#else
        // -- Arrange --
        let callbackInvoked = expectation(description: "beforeSendTransaction invoked")
        var receivedWrappedHint: Hint?
        startSDK { transaction, hint in
            guard transaction.transaction == "Tap" else { return nil }
            hint.attachments = [SentryObjCAttachment(data: Data("hint-data".utf8), filename: "hint.txt")]
            receivedWrappedHint = hint.wrapped
            callbackInvoked.fulfill()
            return nil
        }
        SentryObjCSDK.configureScope { scope in
            scope.addAttachment(SentryObjCAttachment(data: Data("scope-data".utf8), filename: "scope.txt"))
        }

        // -- Act --
        SentryObjCSDK.startTransaction(name: "Tap", operation: "ui.action.click").finish()

        // -- Assert --
        wait(for: [callbackInvoked], timeout: 5)
        XCTAssertEqual(try XCTUnwrap(receivedWrappedHint).attachments.map(\.filename), ["hint.txt"])
#endif // !SDK_V10
    }

    func testBeforeSendTransaction_whenSetToNil_shouldClearWrappedCallback() throws {
#if !SDK_V10
        throw XCTSkip("Test skipped for non SDK_V10")
#else
        // -- Arrange --
        let options = SentryObjCOptions()
        options.beforeSendTransaction = { transaction, _ in transaction }
        XCTAssertNotNil(options.wrapped.beforeSendTransaction)

        // -- Act --
        options.beforeSendTransaction = nil

        // -- Assert --
        XCTAssertNil(options.wrapped.beforeSendTransaction)
#endif // !SDK_V10
    }

#if SDK_V10
    private func startSDK(
        beforeSendTransaction: @escaping (SentryObjCTransaction, SentryObjCHint) -> SentryObjCTransaction?
    ) {
        SentryObjCSDK.start { options in
            options.dsn = "https://key@sentry.io/123"
            options.enableCrashHandler = false
            options.enableAutoPerformanceTracing = false
            options.enableSwizzling = false
            options.tracesSampleRate = 1
            options.beforeSendTransaction = beforeSendTransaction
        }
    }
#endif // SDK_V10
}
