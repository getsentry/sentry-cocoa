@_spi(Private) @testable import Sentry
import XCTest

final class SentryCurrentScopeStorageTests: XCTestCase {

    private var sut: SentryCurrentScopeStorage!

    override func setUp() {
        super.setUp()
        sut = SentryCurrentScopeStorage()
    }

    func testScope_returnsNilByDefault() {
        XCTAssertNil(sut.scope())
    }

    func testWithScope_setsScope() {
        let scope = Scope()
        scope.setTag(value: "value", key: "key")

        sut.withScope(scope) {
            let current = sut.scope()
            XCTAssertNotNil(current)
            XCTAssertEqual(current?.tags["key"], "value")
        }
    }

    func testWithScope_restoresNilAfterCallback() {
        let scope = Scope()

        sut.withScope(scope) {}

        XCTAssertNil(sut.scope())
    }

    func testWithScope_supportsNesting() {
        let outer = Scope()
        outer.setTag(value: "outer", key: "level")

        let inner = Scope()
        inner.setTag(value: "inner", key: "level")

        sut.withScope(outer) {
            XCTAssertEqual(sut.scope()?.tags["level"], "outer")

            sut.withScope(inner) {
                XCTAssertEqual(sut.scope()?.tags["level"], "inner")
            }

            XCTAssertEqual(sut.scope()?.tags["level"], "outer")
        }

        XCTAssertNil(sut.scope())
    }

    func testWithScope_isThreadLocal() {
        let scope = Scope()
        scope.setTag(value: "main", key: "thread")

        let expectation = expectation(description: "background check")

        sut.withScope(scope) {
            XCTAssertNotNil(sut.scope())

            DispatchQueue.global().async {
                XCTAssertNil(self.sut.scope())
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 1)
    }
}
