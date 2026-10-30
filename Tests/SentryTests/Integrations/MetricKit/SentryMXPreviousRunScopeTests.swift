@_spi(Private) import SentryTestUtils
#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import XCTest

#if os(iOS) || os(macOS) || os(visionOS)

/// Covers how the persisted scope data of the previous run is applied to a MetricKit event.
final class SentryMXPreviousRunScopeTests: XCTestCase {

    private static let dsnAsString = TestConstants.dsnForTestCase(type: SentryMXPreviousRunScopeTests.self)

    private var fileManager: TestFileManager!
    private var scopePersistentStore: SentryScopePersistentStore!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let options = Options()
        options.dsn = Self.dsnAsString
        fileManager = try TestFileManager(options: options, dateProvider: TestCurrentDateProvider(), dispatchQueueWrapper: TestSentryDispatchQueueWrapper())
        scopePersistentStore = try XCTUnwrap(SentryScopePersistentStore(fileManager: fileManager))
    }

    override func tearDown() {
        fileManager.deleteAllFolders()
        super.tearDown()
    }

    func testApply_whenPreviousRunPersistedScope_shouldApplyIt() {
        // -- Arrange --
        let user = User(userId: "previous-user")
        scopePersistentStore.writeUserToDisk(user: user)
        scopePersistentStore.writeEnvironmentToDisk(environment: "staging")
        scopePersistentStore.writeTagsToDisk(tags: ["screen": "checkout"])
        scopePersistentStore.writeExtrasToDisk(extras: ["cart": 3])
        scopePersistentStore.writeFingerprintToDisk(fingerprint: ["checkout-crash"])
        scopePersistentStore.moveAllCurrentStateToPreviousState()
        let event = Event()

        // -- Act --
        givenSut().apply(to: event)

        // -- Assert --
        XCTAssertEqual(event.user?.userId, "previous-user")
        XCTAssertEqual(event.environment, "staging")
        XCTAssertEqual(event.tags, ["screen": "checkout"])
        XCTAssertEqual(event.extra?["cart"] as? Int, 3)
        XCTAssertEqual(event.fingerprint, ["checkout-crash"])
    }

    func testApply_whenEventHasDiagnosticContext_shouldKeepDiagnosticValues() throws {
        // -- Arrange --
        scopePersistentStore.writeContextToDisk(context: [
            "app": ["app_version": "1.0.0", "app_name": "Sentry"],
            "culture": ["locale": "en_US"]
        ])
        scopePersistentStore.moveAllCurrentStateToPreviousState()
        let event = Event()
        // The versions MetricKit recorded the diagnostic with.
        event.context = ["app": ["app_version": "2.0.0"]]

        // -- Act --
        givenSut().apply(to: event)

        // -- Assert --
        let appContext = try XCTUnwrap(event.context?["app"])
        XCTAssertEqual(appContext["app_version"] as? String, "2.0.0")
        XCTAssertEqual(appContext["app_name"] as? String, "Sentry")
        XCTAssertEqual(event.context?["culture"]?["locale"] as? String, "en_US")
    }

    func testApply_whenNothingPersisted_shouldNotChangeEvent() {
        // -- Arrange --
        scopePersistentStore.moveAllCurrentStateToPreviousState()
        let event = Event()
        event.context = ["app": ["app_version": "2.0.0"]]

        // -- Act --
        givenSut().apply(to: event)

        // -- Assert --
        XCTAssertNil(event.user)
        XCTAssertNil(event.tags)
        XCTAssertNil(event.serializedBreadcrumbs)
        XCTAssertEqual(event.context?["app"]?["app_version"] as? String, "2.0.0")
    }

    private func givenSut() -> SentryMXPreviousRunScope {
        SentryMXPreviousRunScope(fileManager: fileManager, scopePersistentStore: scopePersistentStore, maxBreadcrumbs: 100)
    }
}

#endif // os(iOS) || os(macOS) || os(visionOS)
