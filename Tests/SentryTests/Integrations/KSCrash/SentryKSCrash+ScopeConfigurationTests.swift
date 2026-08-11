#if ENABLE_KSCRASH
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
