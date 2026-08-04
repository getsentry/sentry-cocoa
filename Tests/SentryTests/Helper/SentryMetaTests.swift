@_spi(Private) @testable import Sentry
import XCTest

class SentryMetaTests: XCTestCase {

    private var originalVersionString: String!
    private var originalSdkName: String!

    override func setUp() {
        super.setUp()
        originalVersionString = SentryMeta.versionString
        originalSdkName = SentryMeta.sdkName
    }

    override func tearDown() {
        SentryMeta.versionString = originalVersionString
        SentryMeta.sdkName = originalSdkName
        super.tearDown()
    }

    // MARK: - Defaults

    func testSdkName_shouldBeSentryCocoa() {
        // -- Assert --
        XCTAssertEqual(SentryMeta.sdkName, "sentry.cocoa")
    }

    /// The release pipeline (`Utils/VersionBump`) rewrites `versionString` in place. If that
    /// rewrite ever misses the file, the shipped version silently drifts, so assert the literal
    /// still looks like a version we could have released.
    func testVersionString_shouldBeValidSemVer() {
        // -- Arrange --
        let semver = "^[0-9]+\\.[0-9]+\\.[0-9]+(-[0-9A-Za-z.-]+)?$"

        // -- Act --
        let matches = SentryMeta.versionString.range(of: semver, options: .regularExpression) != nil

        // -- Assert --
        XCTAssertTrue(matches, "\(SentryMeta.versionString) is not a valid version string")
    }

    func testVersionString_shouldNotBePlaceholder() {
        // -- Assert --
        XCTAssertNotEqual(SentryMeta.versionString, "0.0.0")
        XCTAssertNotEqual(SentryMeta.versionString, "1.2.3")
    }

    // MARK: - versionString

    func testVersionString_whenSet_shouldReturnNewValue() {
        // -- Act --
        SentryMeta.versionString = "1.2.3-beta.1"

        // -- Assert --
        XCTAssertEqual(SentryMeta.versionString, "1.2.3-beta.1")
    }

    func testVersionString_whenSet_shouldNotAffectSdkName() {
        // -- Arrange --
        let expected = SentryMeta.sdkName

        // -- Act --
        SentryMeta.versionString = "9.9.9"

        // -- Assert --
        XCTAssertEqual(SentryMeta.sdkName, expected)
    }

    // MARK: - sdkName

    func testSdkName_whenSet_shouldReturnNewValue() {
        // -- Act --
        SentryMeta.sdkName = "sentry.cocoa.react-native"

        // -- Assert --
        XCTAssertEqual(SentryMeta.sdkName, "sentry.cocoa.react-native")
    }

    func testSdkName_whenSet_shouldNotAffectVersionString() {
        // -- Arrange --
        let expected = SentryMeta.versionString

        // -- Act --
        SentryMeta.sdkName = "sentry.cocoa.flutter"

        // -- Assert --
        XCTAssertEqual(SentryMeta.versionString, expected)
    }

    // MARK: - Shared state

    /// Both values are process-wide mutable state read by the transport and profiler. Confirm a
    /// write is observed through a second, independent read path.
    func testSetValues_shouldBeVisibleToSdkMetadataProvider() {
        // -- Arrange --
        let provider = SentryDependencyContainer.sharedInstance().sdkMetadataProvider

        // -- Act --
        SentryMeta.sdkName = "sentry.cocoa.unity"
        SentryMeta.versionString = "8.7.6"

        // -- Assert --
        XCTAssertEqual(provider.sdkName, "sentry.cocoa.unity")
        XCTAssertEqual(provider.sdkVersion, "8.7.6")
    }

    func testSetValues_shouldRoundTripThroughRepeatedWrites() {
        // -- Act & Assert --
        for index in 0..<5 {
            SentryMeta.versionString = "1.0.\(index)"
            SentryMeta.sdkName = "sdk.\(index)"
            XCTAssertEqual(SentryMeta.versionString, "1.0.\(index)")
            XCTAssertEqual(SentryMeta.sdkName, "sdk.\(index)")
        }
    }
}
