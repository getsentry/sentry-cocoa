@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

class SentryInternalSdkApiTests: XCTestCase {

    private var sut: SentryInternalSdkApi { SentrySDK.internal.sdk }

    override func setUp() {
        super.setUp()
        SentrySdkPackage.resetPackageManager()
        SentryExtraPackages.clear()
        SentrySDK.start {
            $0.dsn = TestConstants.dsnForTestCase(type: SentryInternalSdkApiTests.self)
            $0.removeAllIntegrations()
        }
    }

    override func tearDown() {
        super.tearDown()
        clearTestState()
    }

    // MARK: - name

    func testName_shouldReturnNonEmpty() {
        // -- Act --
        let name = sut.name

        // -- Assert --
        XCTAssertFalse(name.isEmpty)
    }

    func testName_whenSet_shouldUpdateSentryMeta() {
        // -- Arrange --
        let originalName = sut.name
        defer { sut.name = originalName }

        // -- Act --
        sut.name = "Custom SDK"

        // -- Assert --
        XCTAssertEqual(sut.name, "Custom SDK")
        XCTAssertEqual(SentryMeta.sdkName, "Custom SDK")
    }

    // MARK: - versionString

    func testVersionString_shouldReturnNonEmpty() {
        // -- Act --
        let version = sut.versionString

        // -- Assert --
        XCTAssertFalse(version.isEmpty)
    }

    func testVersionString_whenSet_shouldUpdateSentryMeta() {
        // -- Arrange --
        let originalVersion = sut.versionString
        defer { sut.versionString = originalVersion }

        // -- Act --
        sut.versionString = "1.2.3"

        // -- Assert --
        XCTAssertEqual(sut.versionString, "1.2.3")
        XCTAssertEqual(SentryMeta.versionString, "1.2.3")
    }

    // MARK: - setName(_:version:)

    func testSetName_whenCalledWithBoth_shouldUpdateNameAndVersion() {
        // -- Arrange --
        let originalName = sut.name
        let originalVersion = sut.versionString
        defer { sut.setName(originalName, version: originalVersion) }

        // -- Act --
        sut.setName("New SDK", version: "4.5.6")

        // -- Assert --
        XCTAssertEqual(sut.name, "New SDK")
        XCTAssertEqual(sut.versionString, "4.5.6")
        XCTAssertEqual(SentryMeta.sdkName, "New SDK")
        XCTAssertEqual(SentryMeta.versionString, "4.5.6")
    }

    func testSetName_whenCalledTwice_shouldReflectLatestValues() {
        // -- Arrange --
        let originalName = sut.name
        let originalVersion = sut.versionString
        defer { sut.setName(originalName, version: originalVersion) }

        // -- Act --
        sut.setName("First", version: "1.0.0")
        sut.setName("Second", version: "2.0.0")

        // -- Assert --
        XCTAssertEqual(sut.name, "Second")
        XCTAssertEqual(sut.versionString, "2.0.0")
    }

    // MARK: - addPackage

    func testAddPackage_shouldAppearInSdkInfo() throws {
        // -- Act --
        sut.addPackage(name: "package1", version: "version1")
        sut.addPackage(name: "package2", version: "version2")

        // -- Assert --
        let packages = try SentrySdkInfo.global().packages.sorted { package1, package2 in
            try XCTUnwrap(package1["name"]) < XCTUnwrap(package2["name"])
        }
        XCTAssertEqual(packages.count, 2)
        XCTAssertEqual(packages[0]["name"], "package1")
        XCTAssertEqual(packages[0]["version"], "version1")
        XCTAssertEqual(packages[1]["name"], "package2")
        XCTAssertEqual(packages[1]["version"], "version2")
    }

    // MARK: - installationID

    func testInstallationID_shouldMatchSentryInstallation() {
        // -- Arrange --
        let options = SentrySDK.internal.options
        let expected = SentryInstallation.id(withCacheDirectoryPath: options.cacheDirectoryPath)

        // -- Act --
        let installationID = sut.installationID

        // -- Assert --
        XCTAssertEqual(installationID, expected)
    }

    // MARK: - extraContext

    func testExtraContext_shouldReturnDictionary() {
        // -- Act --
        let context = sut.extraContext

        // -- Assert --
        XCTAssertNotNil(context)
    }
}
