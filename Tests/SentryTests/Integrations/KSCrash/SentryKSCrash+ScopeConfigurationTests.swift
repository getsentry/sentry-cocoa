#if SDK_V10
@_spi(Private) import SentryTestUtils
@_spi(Private) @testable import Sentry
import XCTest

final class SentryKSCrashScopeConfigurationTests: XCTestCase {
    private var originalHub: SentryHubInternal!

    override func setUp() {
        super.setUp()
        originalHub = SentrySDKInternal.currentHub()
    }

    override func tearDown() {
        sentrycrash_scopesync_clear()
        SentrySDKInternal.setCurrentHub(originalHub)
        super.tearDown()
    }

    func testInit_shouldConfigureInstallerFromScopeAndOptions() throws {
        // -- Arrange --
        let scope = Scope()
        scope.setTag(value: "value", key: "tag")
        scope.setEnvironment("scope-environment")
        scope.setAttribute(value: "unused", key: "attribute")
        setCurrentHub(scope: scope)

        let options = Options()
        options.releaseName = "release"
        options.dist = "dist"
        options.environment = "options-environment"
        let installer = MockKSCrashInstaller()

        // -- Act --
        _ = SentryKSCrash.Scope.Configuration(installer: installer, options: options)

        // -- Assert --
        let userInfo = try XCTUnwrap(installer.setUserInfoInvocations.first)
        XCTAssertEqual(installer.setUserInfoInvocations.count, 1)
        XCTAssertEqual(userInfo["release"] as? String, "release")
        XCTAssertEqual(userInfo["dist"] as? String, "dist")
        XCTAssertEqual(userInfo["environment"] as? String, "scope-environment")
        XCTAssertEqual((userInfo["tags"] as? [String: String])?["tag"], "value")
        XCTAssertNil(userInfo["attributes"])
    }

    func testInit_whenScopeHasNoEnvironment_shouldUseOptionsEnvironment() throws {
        // -- Arrange --
        setCurrentHub(scope: Scope())
        let options = Options()
        options.environment = "options-environment"
        let installer = MockKSCrashInstaller()

        // -- Act --
        _ = SentryKSCrash.Scope.Configuration(installer: installer, options: options)

        // -- Assert --
        let userInfo = try XCTUnwrap(installer.setUserInfoInvocations.first)
        XCTAssertEqual(userInfo["environment"] as? String, "options-environment")
    }

    func testInit_whenScopeHasNestedFields_shouldSeedScopeSync() throws {
        // -- Arrange --
        let scope = Scope()
        let extras: [String: Any] = [
            "crash_e2e_extra": "crash-e2e-extra-value",
            "nested": ["key": "value"]
        ]
        scope.setExtras(extras)
        scope.setTag(value: "tag-value", key: "language")
        scope.setUser(User(userId: "user-1"))
        scope.setContext(value: ["custom": "context-value"], key: "custom")
        scope.setLevel(.warning)
        let breadcrumb = Breadcrumb(level: .info, category: "started")
        breadcrumb.message = "seeded-crumb"
        scope.addBreadcrumb(breadcrumb)
        setCurrentHub(scope: scope)

        // -- Act --
        _ = SentryKSCrash.Scope.Configuration(
            installer: MockKSCrashInstaller(),
            options: Options()
        )

        // -- Assert --
        let extrasJSON = try XCTUnwrap(getScopeJson { $0.extras })
        XCTAssertTrue(extrasJSON.contains("crash_e2e_extra"), extrasJSON)
        XCTAssertTrue(extrasJSON.contains("crash-e2e-extra-value"), extrasJSON)
        XCTAssertTrue(extrasJSON.contains("nested"), extrasJSON)

        let tagsJSON = try XCTUnwrap(getScopeJson { $0.tags })
        XCTAssertTrue(tagsJSON.contains("language"), tagsJSON)
        XCTAssertTrue(tagsJSON.contains("tag-value"), tagsJSON)

        let userJSON = try XCTUnwrap(getScopeJson { $0.user })
        XCTAssertTrue(userJSON.contains("user-1"), userJSON)

        let contextJSON = try XCTUnwrap(getScopeJson { $0.context })
        XCTAssertTrue(contextJSON.contains("context-value"), contextJSON)

        XCTAssertEqual("\"warning\"", getScopeJson { $0.level })

        let crashScope = sentrycrash_scopesync_getScope().pointee
        XCTAssertEqual(1, crashScope.currentCrumb)
        let breadcrumbJSON = String(cString: try XCTUnwrap(crashScope.breadcrumbs?.pointee))
        XCTAssertTrue(breadcrumbJSON.contains("seeded-crumb"), breadcrumbJSON)
    }

    func testInit_shouldAddObserverToScope() {
        // -- Arrange --
        let scope = Scope()
        setCurrentHub(scope: scope)
        let installer = MockKSCrashInstaller()

        // -- Act --
        let sut = SentryKSCrash.Scope.Configuration(installer: installer, options: Options())
        scope.setDist("updated-dist")

        // -- Assert --
        withExtendedLifetime(sut) {
            XCTAssertEqual("\"updated-dist\"", getScopeJson { $0.dist })
        }
    }

    func testInit_shouldPreserveDeviceContextAndAddLowPowerMode() throws {
        // -- Arrange --
        let scope = Scope()
        setCurrentHub(scope: scope)
        scope.setContext(value: ["custom": "preserved"], key: SENTRY_CONTEXT_DEVICE_KEY)

        // -- Act --
        _ = SentryKSCrash.Scope.Configuration(
            installer: MockKSCrashInstaller(),
            options: Options()
        )

        // -- Assert --
        let device = try XCTUnwrap(
            scope.contextDictionary[SENTRY_CONTEXT_DEVICE_KEY] as? [String: Any]
        )
        XCTAssertEqual(device["custom"] as? String, "preserved")
        XCTAssertEqual(
            device["low_power_mode"] as? Bool,
            ProcessInfo.processInfo.isLowPowerModeEnabled
        )
    }

    private func setCurrentHub(scope: Scope) {
        SentrySDKInternal.setCurrentHub(
            SentryHubInternal(client: TestClient(options: Options()), andScope: scope)
        )
    }

    private func getScopeJson(
        getField: (SentryCrashScope) -> UnsafeMutablePointer<CChar>?
    ) -> String? {
        guard let charPointer = getField(sentrycrash_scopesync_getScope().pointee) else {
            return nil
        }
        return String(cString: charPointer)
    }
}
#endif
