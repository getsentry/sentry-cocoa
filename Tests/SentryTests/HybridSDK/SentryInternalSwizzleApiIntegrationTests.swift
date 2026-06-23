@testable import Sentry
import SentryTestUtils
import XCTest

private var integrationSwizzleKey: UInt8 = 0

class SentryInternalSwizzleApiIntegrationTests: XCTestCase {

    private static let dsnAsString = TestConstants.dsnForTestCase(type: SentryInternalSwizzleApiIntegrationTests.self)

    override func setUp() {
        super.setUp()
        SentrySDK.start { options in
            options.dsn = SentryInternalSwizzleApiIntegrationTests.dsnAsString
            options.removeAllIntegrations()
        }
    }

    override func tearDown() {
        clearTestState()
        super.tearDown()
    }

    // MARK: - Accessor

    func testSwizzle_shouldBeAccessible() {
        // -- Act --
        let swizzle = SentrySDK.internal.swizzle

        // -- Assert --
        XCTAssertNotNil(swizzle)
    }

    // MARK: - instanceMethod

    func testInstanceMethod_shouldSwizzleAndModifyBehavior() {
        // -- Act --
        let result = SentrySDK.internal.swizzle.instanceMethod(
            #selector(SwizzleIntegrationTarget.compute),
            in: SwizzleIntegrationTarget.self,
            mode: .always,
            key: &integrationSwizzleKey
        ) { getOriginal in
            { (target: SwizzleIntegrationTarget) -> Int in
                let original = unsafeBitCast(
                    getOriginal(),
                    to: (@convention(c) (SwizzleIntegrationTarget, Selector) -> Int).self
                )
                return original(target, #selector(SwizzleIntegrationTarget.compute)) * 2
            } as @convention(block) (SwizzleIntegrationTarget) -> Int
        }

        // -- Assert --
        XCTAssertTrue(result)
        XCTAssertEqual(SwizzleIntegrationTarget().compute(), 10)
    }
}

// MARK: - Test helpers

private class SwizzleIntegrationTarget: NSObject {
    @objc dynamic func compute() -> Int { 5 }
}
