#if os(iOS) && !targetEnvironment(macCatalyst)

@_spi(Private) import SentryTestUtils
#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import XCTest

final class SentryConnectionEffectiveTypeIntegrationTests: XCTestCase {

    private class Fixture {
        let options = Options()
        let reachability = SentryReachability()
        let provider = TestSentryCellularNetworkTechnologyProvider()
        let dispatchQueue = TestSentryDispatchQueueWrapper()
        let observer = TestSentryReachabilityObserver()

        init() {
            reachability.skipRegisteringActualCallbacks = true
            reachability.setReachabilityIgnoreActualCallback(true)
            reachability.add(observer)
        }

        func getSut() -> SentryConnectionEffectiveTypeIntegration<SentryDependencyContainer>? {
            SentryConnectionEffectiveTypeIntegration(
                options: options,
                reachability: reachability,
                provider: provider,
                dispatchQueue: dispatchQueue
            )
        }
    }

    private var fixture: Fixture!

    override func setUp() {
        super.setUp()
        fixture = Fixture()
    }

    override func tearDown() {
        fixture.reachability.removeAllObservers()
        fixture.reachability.setReachabilityIgnoreActualCallback(false)
        fixture = nil
        super.tearDown()
    }

    func testInit_whenOptionIsDisabledByDefault_shouldNotInstall() {
        // -- Act --
        let sut = fixture.getSut()

        // -- Assert --
        XCTAssertNil(sut)
        XCTAssertEqual([], fixture.provider.monitoringInvocations.invocations)
        XCTAssertEqual(0, fixture.dispatchQueue.dispatchAsyncInvocations.count)
    }

    func testInit_whenOptionIsEnabled_shouldStartMonitoringOnTheDispatchQueue() {
        // -- Arrange --
        fixture.options.experimental.enableConnectionEffectiveType = true

        // -- Act --
        let sut = fixture.getSut()

        // -- Assert --
        XCTAssertNotNil(sut)
        XCTAssertEqual(1, fixture.dispatchQueue.dispatchAsyncInvocations.count)
        XCTAssertEqual(["start"], fixture.provider.monitoringInvocations.invocations)
    }

    func testInit_whenOptionIsEnabled_shouldReportTheTechnologyOnCellular() {
        // -- Arrange --
        fixture.options.experimental.enableConnectionEffectiveType = true
        fixture.provider.currentTechnology = .fifthGeneration

        // -- Act --
        let sut = fixture.getSut()
        fixture.reachability.triggerConnectivityCallback(.cellular)

        // -- Assert --
        XCTAssertNotNil(sut)
        XCTAssertEqual("5g", fixture.reachability.currentConnection?.effectiveType)
    }

    func testUninstall_shouldStopMonitoringAndStopReportingTheTechnology() throws {
        // -- Arrange --
        fixture.options.experimental.enableConnectionEffectiveType = true
        fixture.provider.currentTechnology = .fifthGeneration
        let sut = try XCTUnwrap(fixture.getSut())
        fixture.reachability.triggerConnectivityCallback(.cellular)

        // -- Act --
        sut.uninstall()

        // -- Assert --
        XCTAssertEqual(["start", "stop"], fixture.provider.monitoringInvocations.invocations)
        XCTAssertEqual("cellular", fixture.reachability.currentConnection?.type)
        XCTAssertNil(fixture.reachability.currentConnection?.effectiveType)
    }
}

#endif // os(iOS) && !targetEnvironment(macCatalyst)
