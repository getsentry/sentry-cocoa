@_spi(Private) @testable import Sentry
import SentryTestUtils
import XCTest

class SentryInternalSdkApiTests: XCTestCase {

    private var sut: SentryInternalSdkApi!

    override func setUp() {
        super.setUp()
        let container = SentryDependencyContainer.sharedInstance()
        sut = SentryInternalSdkApi(dependencies: container)
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - name

    func testName_shouldReturnDefaultSdkName() {
        // -- Act --
        let name = sut.name

        // -- Assert --
        XCTAssertEqual(name, "sentry.cocoa")
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

    func testVersionString_shouldReturnDefaultVersion() {
        // -- Act --
        let version = sut.versionString

        // -- Assert --
        XCTAssertEqual(version, SentryMeta.versionString)
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

    func testSetName_shouldUpdateBoth() {
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

    func testSetName_whenCalledTwice_shouldReflectLatest() {
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
        let packages = try SentrySdkInfo.global().packages.sorted { p1, p2 in
            try XCTUnwrap(p1["name"]) < XCTUnwrap(p2["name"])
        }
        XCTAssertEqual(packages.count, 2)
        XCTAssertEqual(packages[0]["name"], "package1")
        XCTAssertEqual(packages[0]["version"], "version1")
        XCTAssertEqual(packages[1]["name"], "package2")
        XCTAssertEqual(packages[1]["version"], "version2")
    }

    // MARK: - installationID

    func testInstallationID_shouldReturnUUIDFormat() {
        // -- Act --
        let installationID = sut.installationID

        // -- Assert --
        XCTAssertEqual(installationID.count, 36, "Expected UUID format (36 chars with hyphens)")
    }

    func testInstallationID_whenAccessedTwice_shouldReturnSameValue() {
        // -- Act --
        let first = sut.installationID
        let second = sut.installationID

        // -- Assert --
        XCTAssertEqual(first, second)
    }

    // MARK: - extraContext

    func testExtraContext_shouldContainDeviceKey() {
        // -- Act --
        let context = sut.extraContext

        // -- Assert --
        XCTAssertTrue(context.keys.contains("device"))
    }
}
