#if SWIFT_PACKAGE && !SDK_V10
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
@_spi(Private) @testable import SentryTestUtils
import _SentryPrivate
import XCTest

final class SentryHubEventSourceSinkTests: SentrySDKIntegrationTestsBase {
    /// Stands in for a client that went away while it captured a fatal event.
    private final class ClientClearedDuringCapture: TestClient {
        public override func captureFatalEvent(_ event: Event, with scope: Scope) -> SentryId {
            clearClientWithoutCapturing()
        }

        public override func wrapper_captureFatalEvent(_ event: Event, session: Any, scope: Scope) -> SentryId {
            clearClientWithoutCapturing()
        }

        private func clearClientWithoutCapturing() -> SentryId {
            SentrySDKInternal.currentHub().bindClient(nil)
            return SentryId.empty
        }
    }

    override var options: Options {
        let options = Options()
        options.dsn = TestConstants.dsnAsString(username: "SentryHubEventSourceSinkTests")
        return options
    }

    private var sut: SentryHubEventSourceSink!
    private var fileManager: SentryFileManager?

    override func setUp() {
        super.setUp()
        givenSdkWithHub()
        fileManager = SentrySDKInternal.currentHub().getClient()?.fileManager
        sut = SentryHubEventSourceSink(dependencies: SentrySDKCurrentHubProvider())
    }

    override func tearDown() {
        // Every client of these tests stores to the same folders, and a crashed session that a
        // test leaves behind would be sent with the fatal event of the next test.
        fileManager?.deleteAllFolders()
        super.tearDown()
    }

    // MARK: - isAvailable

    func testIsAvailable_whenHubHasClient_shouldReturnTrue() {
        XCTAssertTrue(sut.isAvailable)
    }

    func testIsAvailable_whenHubHasNoClient_shouldReturnFalse() {
        // -- Arrange --
        SentrySDKInternal.setCurrentHub(SentryHubInternal(client: nil, andScope: nil))

        // -- Act & Assert --
        XCTAssertFalse(sut.isAvailable)
    }

    // MARK: - Fatal reports

    func testSubmit_whenFatalReport_shouldCaptureFatalEventWithAttachments() throws {
        // -- Arrange --
        let client = try currentTestClient()
        let event = Event(level: .fatal)
        let attachmentPath = "/tmp/event-source-attachment.png"

        // -- Act --
        let result = sut.submit(givenFatalReport(event: event, attachmentPaths: [attachmentPath]))

        // -- Assert --
        XCTAssertEqual(result, .accepted)
        XCTAssertEqual(client.captureFatalEventInvocations.count, 1)
        let capture = try XCTUnwrap(client.captureFatalEventInvocations.first)
        XCTAssertIdentical(capture.event, event)
        XCTAssertEqual(capture.scope.crashReportAttachments.map(\.path), [attachmentPath])
        XCTAssertEqual(client.captureEventWithScopeAndHintInvocations.count, 0)
    }

    func testSubmit_whenFatalReport_shouldNotAddAttachmentsToCurrentScope() {
        // -- Arrange --
        let currentScope = SentrySDKInternal.currentHub().scope

        // -- Act --
        sut.submit(givenFatalReport(attachmentPaths: ["/tmp/event-source-attachment.png"]))

        // -- Assert --
        XCTAssertEqual(currentScope.crashReportAttachments.count, 0)
    }

    func testSubmit_whenFatalReportAndCrashedSessionExists_shouldCaptureWithSessionAndDeleteIt() throws {
        // -- Arrange --
        let client = try currentTestClient()
        let crashedSession = givenCrashedSession(storedBy: client)

        // -- Act --
        let result = sut.submit(givenFatalReport())

        // -- Assert --
        XCTAssertEqual(result, .accepted)
        XCTAssertEqual(client.captureFatalEventWithSessionInvocations.count, 1)
        XCTAssertEqual(client.captureFatalEventWithSessionInvocations.first?.session.sessionId, crashedSession.sessionId)
        XCTAssertNil(client.fileManager.readCrashedSession())
    }

    func testSubmit_whenSourceWithdrawsFatalReport_shouldNotCapture() throws {
        // -- Arrange --
        let client = try currentTestClient()

        // -- Act --
        let result = sut.submit(givenFatalReport()) { false }

        // -- Assert --
        XCTAssertEqual(result, .withdrawn)
        XCTAssertEqual(client.captureFatalEventInvocations.count, 0)
    }

    func testSubmit_whenHubHasNoClient_shouldReturnUnavailableWithoutCallingBeforeAccepting() {
        // -- Arrange --
        SentrySDKInternal.setCurrentHub(SentryHubInternal(client: nil, andScope: nil))
        var beforeAcceptingInvocations = 0

        // -- Act --
        let result = sut.submit(givenFatalReport()) {
            beforeAcceptingInvocations += 1
            return true
        }

        // -- Assert --
        XCTAssertEqual(result, .unavailable)
        XCTAssertEqual(beforeAcceptingInvocations, 0)
    }

    func testSubmit_whenHubIsReplacedInBeforeAccepting_shouldCaptureOnHubReadBefore() throws {
        // -- Arrange --
        let oldClient = try currentTestClient()
        let replacementClient = try XCTUnwrap(TestClient(options: options))
        let replacementHub = SentryHubInternal(client: replacementClient, andScope: nil)

        // -- Act --
        let result = sut.submit(givenFatalReport()) {
            SentrySDKInternal.setCurrentHub(replacementHub)
            return true
        }

        // -- Assert --
        XCTAssertEqual(result, .accepted)
        XCTAssertEqual(oldClient.captureFatalEventInvocations.count, 1)
        XCTAssertEqual(replacementClient.captureFatalEventInvocations.count, 0)
    }

    func testSubmit_whenClientGoesAwayDuringCaptureOfRetainedReport_shouldReturnUnavailableAndKeepSession() throws {
        // -- Arrange --
        let client = try XCTUnwrap(ClientClearedDuringCapture(options: options))
        SentrySDKInternal.setCurrentHub(SentryHubInternal(client: client, andScope: nil))
        let crashedSession = givenCrashedSession(storedBy: client)

        // -- Act --
        let result = sut.submit(givenFatalReport(isRetainedOnFailure: true))

        // -- Assert --
        XCTAssertEqual(result, .unavailable)
        XCTAssertEqual(client.fileManager.readCrashedSession()?.sessionId, crashedSession.sessionId)
    }

    func testSubmit_whenClientGoesAwayDuringCaptureOfReportThatIsNotRetained_shouldDeleteSession() throws {
        // -- Arrange --
        let client = try XCTUnwrap(ClientClearedDuringCapture(options: options))
        SentrySDKInternal.setCurrentHub(SentryHubInternal(client: client, andScope: nil))
        givenCrashedSession(storedBy: client)

        // -- Act --
        let result = sut.submit(givenFatalReport(isRetainedOnFailure: false))

        // -- Assert --
        XCTAssertEqual(result, .unavailable)
        XCTAssertNil(client.fileManager.readCrashedSession())
    }

    // MARK: - Diagnostic reports

    func testSubmit_whenDiagnosticReport_shouldCaptureEventWithAttachmentsInHint() throws {
        // -- Arrange --
        let client = try currentTestClient()
        let event = Event(level: .error)
        let attachment = Attachment(data: Data("diagnostic".utf8), filename: "diagnostic.json")
        let report = SentryEventSourceReport(
            source: .metricKit,
            kind: .diagnostic(attachments: [attachment]),
            runId: nil,
            event: event
        )

        // -- Act --
        let result = sut.submit(report)

        // -- Assert --
        XCTAssertEqual(result, .accepted)
        XCTAssertEqual(client.captureEventWithScopeAndHintInvocations.count, 1)
        let capture = try XCTUnwrap(client.captureEventWithScopeAndHintInvocations.first)
        XCTAssertIdentical(capture.event, event)
        XCTAssertIdentical(capture.scope, SentrySDKInternal.currentHub().scope)
        XCTAssertEqual(capture.hint?.attachments.count, 1)
        XCTAssertIdentical(capture.hint?.attachments.first, attachment)
        XCTAssertEqual(client.captureFatalEventInvocations.count, 0)
    }

    func testSubmit_whenSourceWithdrawsDiagnosticReport_shouldNotCapture() throws {
        // -- Arrange --
        let client = try currentTestClient()
        let report = SentryEventSourceReport(
            source: .metricKit,
            kind: .diagnostic(attachments: []),
            runId: nil,
            event: Event(level: .error)
        )

        // -- Act --
        let result = sut.submit(report) { false }

        // -- Assert --
        XCTAssertEqual(result, .withdrawn)
        XCTAssertEqual(client.captureEventWithScopeAndHintInvocations.count, 0)
    }

    // MARK: - Helpers

    private func currentTestClient() throws -> TestClient {
        try XCTUnwrap(SentrySDKInternal.currentHub().getClient() as? TestClient)
    }

    private func givenFatalReport(
        event: Event = Event(level: .fatal),
        attachmentPaths: [String] = [],
        isRetainedOnFailure: Bool = false
    ) -> SentryEventSourceReport {
        SentryEventSourceReport(
            source: .crashHandler,
            kind: .fatal(attachmentPaths: attachmentPaths, isRetainedOnFailure: isRetainedOnFailure),
            runId: nil,
            event: event
        )
    }

    @discardableResult
    private func givenCrashedSession(storedBy client: TestClient) -> SentrySession {
        let crashedSession = SentrySession(releaseName: "1.0.0", distinctId: "test-installation")
        crashedSession.endCrashed(withTimestamp: Date())
        client.fileManager.storeCrashedSession(crashedSession)
        return crashedSession
    }
}
