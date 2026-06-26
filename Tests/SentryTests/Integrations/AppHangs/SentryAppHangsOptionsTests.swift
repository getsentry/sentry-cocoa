@testable import Sentry
import XCTest

final class SentryAppHangsOptionsTests: XCTestCase {

    func testProfilingSampleRate_defaultIsOne() {
        let sut = AppHangsOptions()
        XCTAssertEqual(sut.profilingSampleRate, 1.0)
    }

    func testProfilingSampleIntervalMs_defaultIs100() {
        let sut = AppHangsOptions()
        XCTAssertEqual(sut.profilingSampleIntervalMs, 100)
    }

    func testProfilingSampleRate_clampsToZero() {
        var sut = AppHangsOptions()
        sut.profilingSampleRate = -0.5
        XCTAssertEqual(sut.profilingSampleRate, 0.0)
    }

    func testProfilingSampleRate_clampsToOne() {
        var sut = AppHangsOptions()
        sut.profilingSampleRate = 1.5
        XCTAssertEqual(sut.profilingSampleRate, 1.0)
    }
}
