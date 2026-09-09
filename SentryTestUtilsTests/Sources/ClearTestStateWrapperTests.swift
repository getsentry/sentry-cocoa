#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
@_spi(Private) @testable import SentryTestUtils
import _SentryPrivate
import XCTest

final class ClearTestStateWrapperTests: XCTestCase {

    override func tearDown() {
        clearTestState()
        super.tearDown()
    }

    func testClearTestState_whenGlobalStateWasMutated_shouldResetRepresentativeState() {
        // -- Arrange --
        let options = Options.noIntegrations()
        options.dsn = TestConstants.dsnForTestCase(type: Self.self, testName: name)
        SentrySDKInternal.start(options: options)
        SentrySDKInternal.lastRunStatusCalled = true
        XCTAssertNotNil(SentrySDKInternal.currentHub().getClient())

        // -- Act --
        clearTestState()

        // -- Assert --
        XCTAssertNil(SentrySDKInternal.currentHub().getClient())
        XCTAssertFalse(SentrySDKInternal.lastRunStatusCalled)
        XCTAssertEqual(SentrySDKInternal.startInvocations, 0)
    }
}
