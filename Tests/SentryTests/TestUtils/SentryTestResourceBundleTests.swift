import SentryTestUtilsObjC
import XCTest

final class SentryTestResourceBundleTests: XCTestCase {
    func testFixtureBundle_whenLoadingJSON_shouldPreserveResourcesDirectory() throws {
        // -- Arrange --
        let bundle = sentryTestResourceBundle(for: Self.self)

        // -- Act --
        let url = try XCTUnwrap(bundle.url(forResource: "Resources/crash-report-1", withExtension: "json"))
        let data = try Data(contentsOf: url)
        let report = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        // -- Assert --
        XCTAssertNotNil(report["crash"])
    }

    func testFixtureBundle_whenLoadingNestedResource_shouldPreserveSubdirectories() throws {
        // -- Arrange --
        let bundle = sentryTestResourceBundle(for: Self.self)

        // -- Act --
        let urls = try XCTUnwrap(bundle.urls(forResourcesWithExtension: "json", subdirectory: "Resources/NetworkEnvelopeSnapshots"))

        // -- Assert --
        XCTAssertFalse(urls.isEmpty)
        for url in urls {
            XCTAssertFalse(try Data(contentsOf: url).isEmpty)
        }
    }

    func testFixtureBundle_whenLoadingInfoPlist_shouldContainTestValues() throws {
        // -- Arrange --
        let bundle = try XCTUnwrap(TestBundle.createTestBundle())
        defer {
            do {
                try TestBundle.cleanup(bundle)
            } catch {
                XCTFail("Failed to clean up test bundle: \(error)")
            }
        }

        // -- Act --
        let value = bundle.object(forInfoDictionaryKey: "TestStringKey") as? String

        // -- Assert --
        XCTAssertEqual(value, "TestStringValue")
    }
}
