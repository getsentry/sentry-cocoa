#if SWIFT_PACKAGE
@testable import SentrySwift
#else
@testable import Sentry
#endif
import XCTest

final class SentryReleaseNameTests: XCTestCase {

    func testFormat_shouldCombineIdentifierVersionAndBuild() {
        // -- Act --
        let result = SentryReleaseName.format(appIdentifier: "io.sentry.app", appVersion: "1.2.3", appBuild: "45")

        // -- Assert --
        XCTAssertEqual(result, "io.sentry.app@1.2.3+45")
    }

    func testDefaultName_whenBundleInfoHasAllValues_shouldUseThem() {
        // -- Arrange --
        let bundleInfo: [String: Any] = [
            "CFBundleIdentifier": "io.sentry.app",
            "CFBundleShortVersionString": "2.0.0",
            "CFBundleVersion": "20"
        ]

        // -- Act --
        let result = SentryReleaseName.defaultName(bundleInfo: bundleInfo)

        // -- Assert --
        XCTAssertEqual(result, "io.sentry.app@2.0.0+20")
    }

    func testDefaultName_whenBundleInfoIsMissingValues_shouldUseEmptyStrings() {
        // -- Act --
        let result = SentryReleaseName.defaultName(bundleInfo: ["CFBundleIdentifier": "io.sentry.app"])

        // -- Assert --
        XCTAssertEqual(result, "io.sentry.app@+")
    }

    func testDefaultName_whenBundleInfoIsNil_shouldReturnNil() {
        // -- Act --
        let result = SentryReleaseName.defaultName(bundleInfo: nil)

        // -- Assert --
        XCTAssertNil(result)
    }

    func testDefaultName_whenMainBundle_shouldMatchOptionsDefault() {
        // -- Act --
        let result = SentryReleaseName.defaultName(bundleInfo: Bundle.main.infoDictionary)

        // -- Assert --
        XCTAssertEqual(result, Options().releaseName)
    }
}
