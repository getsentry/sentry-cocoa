@_spi(Private) import SentryTestUtils
@_spi(Private) @testable import Sentry
import XCTest

final class SentryWithCurrentScopeIntegrationTests: XCTestCase {

    private class Fixture {
        let transportAdapter: TestTransportAdapter
        let options: Options

        init() throws {
            let options = Options()
            options.dsn = TestConstants.dsnAsString(username: "WithCurrentScopeTests")
            options.maxBreadcrumbs = 100
            options.removeAllIntegrations()
            self.options = options

            let transport = TestTransport()
            transportAdapter = TestTransportAdapter(transports: [transport], options: options)
        }

        func getSut() throws -> SentryClientInternal {
            let fileManager = try TestFileManager(
                options: options,
                dateProvider: TestCurrentDateProvider(),
                dispatchQueueWrapper: TestSentryDispatchQueueWrapper()
            )

            return SentryClientInternal(
                options: options,
                dateProvider: TestCurrentDateProvider(),
                transportAdapter: transportAdapter,
                fileManager: fileManager,
                threadInspector: TestDefaultThreadInspector.instance,
                debugImageProvider: TestDebugImageProvider(),
                random: TestRandom(value: 1.0),
                locale: .autoupdatingCurrent,
                timezone: .autoupdatingCurrent,
                eventContextEnricher: TestEventContextEnricher(),
                crashWrapper: TestSentryCrashWrapper(processInfoWrapper: ProcessInfo.processInfo),
                binaryImageCache: SentryDependencyContainer.sharedInstance().binaryImageCache,
                dispatchQueueWrapper: TestSentryDispatchQueueWrapper()
            )
        }
    }

    private var fixture: Fixture!

    override func setUp() {
        super.setUp()
        // swiftlint:disable:next force_try
        fixture = try! Fixture()
        // swiftlint:disable:next force_try
        let client = try! fixture.getSut()
        let hub = SentryHubInternal(
            client: client,
            andScope: Scope(),
            andCrashWrapper: TestSentryCrashWrapper(processInfoWrapper: ProcessInfo.processInfo),
            andDispatchQueue: SentryDispatchQueueWrapper()
        )
        SentrySDK.setStart(with: fixture.options)
        SentrySDKInternal.setCurrentHub(hub)
    }

    override func tearDown() {
        super.tearDown()
        // swiftlint:disable:next avoid_clear_test_state - resets SDK state set in setUp
        clearTestState()
    }

    // MARK: - Tags

    func testWithCurrentScope_tagsAreMerged() {
        SentrySDKInternal.currentHub().scope.setTag(value: "global", key: "global_only")
        SentrySDKInternal.currentHub().scope.setTag(value: "global", key: "shared")

        let currentScope = SentrySDK.internal.scope.createScope()
        currentScope.setTag(value: "current", key: "current_only")
        currentScope.setTag(value: "current", key: "shared")

        SentrySDK.internal.scope.withCurrentScope(currentScope) {
            SentrySDK.capture(event: Event())
        }

        let event = lastSentEvent()
        XCTAssertNotNil(event, "Event should be captured and sent")
        XCTAssertEqual(event?.tags?["global_only"], "global")
        XCTAssertEqual(event?.tags?["current_only"], "current")
        XCTAssertEqual(event?.tags?["shared"], "current")
    }

    // MARK: - Extras

    func testWithCurrentScope_extrasAreMerged() {
        SentrySDKInternal.currentHub().scope.setExtra(value: "global", key: "g")

        let currentScope = SentrySDK.internal.scope.createScope()
        currentScope.setExtra(value: "current", key: "c")

        SentrySDK.internal.scope.withCurrentScope(currentScope) {
            SentrySDK.capture(event: Event())
        }

        let event = lastSentEvent()
        XCTAssertEqual(event?.extra?["g"] as? String, "global")
        XCTAssertEqual(event?.extra?["c"] as? String, "current")
    }

    // MARK: - User

    func testWithCurrentScope_currentUserOverridesGlobal() {
        SentrySDKInternal.currentHub().scope.setUser(User(userId: "global"))

        let currentScope = SentrySDK.internal.scope.createScope()
        currentScope.setUser(User(userId: "current"))

        SentrySDK.internal.scope.withCurrentScope(currentScope) {
            SentrySDK.capture(event: Event())
        }

        XCTAssertEqual(lastSentEvent()?.user?.userId, "current")
    }

    // MARK: - Breadcrumbs

    // MARK: - Context

    func testWithCurrentScope_contextIsDeepMerged() {
        SentrySDKInternal.currentHub().scope.setContext(value: ["a": "1"], key: "custom")

        let currentScope = SentrySDK.internal.scope.createScope()
        currentScope.setContext(value: ["b": "2"], key: "custom")

        SentrySDK.internal.scope.withCurrentScope(currentScope) {
            SentrySDK.capture(event: Event())
        }

        let custom = lastSentEvent()?.context?["custom"]
        XCTAssertEqual(custom?["a"] as? String, "1")
        XCTAssertEqual(custom?["b"] as? String, "2")
    }

    // MARK: - Scope not applied outside callback

    func testWithCurrentScope_scopeNotAppliedOutsideCallback() {
        let currentScope = SentrySDK.internal.scope.createScope()
        currentScope.setTag(value: "scoped", key: "key")

        SentrySDK.internal.scope.withCurrentScope(currentScope) {}

        SentrySDK.capture(event: Event())

        XCTAssertNil(lastSentEvent()?.tags?["key"])
    }

    // MARK: - Message capture

    func testWithCurrentScope_captureMessage_appliesScope() {
        let currentScope = SentrySDK.internal.scope.createScope()
        currentScope.setTag(value: "scoped", key: "msg_tag")

        SentrySDK.internal.scope.withCurrentScope(currentScope) {
            SentrySDK.capture(message: "test message")
        }

        XCTAssertEqual(lastSentEvent()?.tags?["msg_tag"], "scoped")
    }

    // MARK: - Attachments deduplication

    func testWithCurrentScope_clonedScope_attachmentsNotDuplicated() {
        let attachment = Attachment(data: Data("test".utf8), filename: "test.txt")
        SentrySDKInternal.currentHub().scope.addAttachment(attachment)

        let currentScope = SentrySDK.internal.scope.cloneScope(SentrySDKInternal.currentHub().scope)

        SentrySDK.internal.scope.withCurrentScope(currentScope) {
            SentrySDK.capture(event: Event())
        }

        let sentAttachments = fixture.transportAdapter.sendEventWithTraceStateInvocations.last?.attachments ?? []
        let matchCount = sentAttachments.filter { $0 === attachment }.count
        XCTAssertEqual(matchCount, 1, "Shared attachment should not be duplicated")
    }

    // MARK: - Logs

    func testWithCurrentScope_captureLog_appliesCurrentScope() {
        var capturedLog: SentryLog?
        fixture.options.beforeSendLog = { log in
            capturedLog = log
            return log
        }
        // Recreate client/hub with the updated options
        // swiftlint:disable:next force_try
        let client = try! fixture.getSut()
        let hub = SentryHubInternal(
            client: client,
            andScope: Scope(),
            andCrashWrapper: TestSentryCrashWrapper(processInfoWrapper: ProcessInfo.processInfo),
            andDispatchQueue: SentryDispatchQueueWrapper()
        )
        SentrySDKInternal.setCurrentHub(hub)

        let currentScope = SentrySDK.internal.scope.createScope()
        currentScope.setAttribute(value: "log-scoped", key: "log_tag")

        SentrySDK.internal.scope.withCurrentScope(currentScope) {
            SentrySDK.logger.info("test log message")
        }

        XCTAssertNotNil(capturedLog)
        XCTAssertEqual(capturedLog?.attributes["log_tag"]?.value as? String, "log-scoped")
    }

    // MARK: - Helpers

    private func lastSentEvent() -> Event? {
        fixture.transportAdapter.sendEventWithTraceStateInvocations.last?.event
    }
}
