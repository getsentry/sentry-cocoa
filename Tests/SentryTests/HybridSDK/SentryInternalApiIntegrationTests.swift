@testable import Sentry
import SentryTestUtils
import XCTest

class SentryInternalApiIntegrationTests: XCTestCase {

    private static let dsnAsString = TestConstants.dsnForTestCase(type: SentryInternalApiIntegrationTests.self)

    override func setUp() {
        super.setUp()
        SentrySDK.start { options in
            options.dsn = SentryInternalApiIntegrationTests.dsnAsString
            options.removeAllIntegrations()
        }
    }

    override func tearDown() {
        clearTestState()
        super.tearDown()
    }

    // MARK: - sdk accessor

    func testSdk_shouldReturnDefaultName() {
        // -- Act --
        let name = SentrySDK.internal.sdk.name

        // -- Assert --
        XCTAssertEqual(name, "sentry.cocoa")
    }

    func testSdk_shouldReturnDefaultVersion() {
        // -- Act --
        let version = SentrySDK.internal.sdk.versionString

        // -- Assert --
        XCTAssertEqual(version, SentryMeta.versionString)
    }

    func testSdk_whenAccessedRepeatedly_shouldReturnConsistentValues() {
        // -- Act --
        let first = SentrySDK.internal.sdk.name
        let second = SentrySDK.internal.sdk.name

        // -- Assert --
        XCTAssertEqual(first, second)
    }

    // MARK: - name

    func testSdk_whenNameSet_shouldPersistAcrossAccesses() {
        // -- Arrange --
        let original = SentrySDK.internal.sdk.name
        defer { SentrySDK.internal.sdk.name = original }

        // -- Act --
        SentrySDK.internal.sdk.name = "TestFromApi"

        // -- Assert --
        XCTAssertEqual(SentrySDK.internal.sdk.name, "TestFromApi")
    }

    // MARK: - versionString

    func testSdk_whenVersionSet_shouldPersistAcrossAccesses() {
        // -- Arrange --
        let original = SentrySDK.internal.sdk.versionString
        defer { SentrySDK.internal.sdk.versionString = original }

        // -- Act --
        SentrySDK.internal.sdk.versionString = "99.0.0"

        // -- Assert --
        XCTAssertEqual(SentrySDK.internal.sdk.versionString, "99.0.0")
    }

    // MARK: - addPackage

    func testSdk_whenPackageAdded_shouldAppearInSdkInfo() {
        // -- Act --
        SentrySDK.internal.sdk.addPackage(name: "integration-pkg", version: "1.0.0")

        // -- Assert --
        let packages = SentrySdkInfo.global().packages
        let match = packages.first { $0["name"] == "integration-pkg" }
        XCTAssertNotNil(match)
        XCTAssertEqual(match?["version"], "1.0.0")
    }

    // MARK: - installationID

    func testSdk_whenInstallationIDAccessed_shouldReturnStableValue() {
        // -- Act --
        let first = SentrySDK.internal.sdk.installationID
        let second = SentrySDK.internal.sdk.installationID

        // -- Assert --
        XCTAssertEqual(first, second)
        XCTAssertEqual(first.count, 36, "Expected UUID format (36 chars with hyphens)")
    }

    // MARK: - extraContext

    func testSdk_whenExtraContextAccessed_shouldContainDeviceKey() {
        // -- Act --
        let context = SentrySDK.internal.sdk.extraContext

        // -- Assert --
        XCTAssertTrue(context.keys.contains("device"))
    }

    // MARK: - breadcrumbs accessor

    func testBreadcrumbs_shouldBeAccessible() {
        // -- Act --
        let breadcrumbs = SentrySDK.internal.breadcrumbs

        // -- Assert --
        XCTAssertNotNil(breadcrumbs)
    }

    // MARK: - user accessor

    func testUser_shouldBeAccessible() {
        // -- Act --
        let user = SentrySDK.internal.user

        // -- Assert --
        XCTAssertNotNil(user)
    }

    // MARK: - debug accessor

    func testDebug_shouldBeAccessible() {
        // -- Act --
        let debug = SentrySDK.internal.debug

        // -- Assert --
        XCTAssertNotNil(debug)
    }

}
