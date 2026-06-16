@testable import Sentry
import XCTest

class SentryInternalSwizzleApiTests: XCTestCase {

    private let sut = SentryInternalSwizzleApi()

    // MARK: - Mode

    func testMode_rawValues() {
        XCTAssertEqual(SentryInternalSwizzleApi.Mode.always.rawValue, 0)
        XCTAssertEqual(SentryInternalSwizzleApi.Mode.oncePerClass.rawValue, 1)
        XCTAssertEqual(SentryInternalSwizzleApi.Mode.oncePerClassAndSuperclasses.rawValue, 2)
    }
}
