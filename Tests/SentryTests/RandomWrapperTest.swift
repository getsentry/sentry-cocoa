import _SentryPrivate
import Nimble
@testable import Sentry
import XCTest

final class RandomWrapperTest: XCTestCase {
    func testExample() throws {
        let randomWrapper = RandomWrapper()
        expect(randomWrapper.calc()) >= 0
    }
}
