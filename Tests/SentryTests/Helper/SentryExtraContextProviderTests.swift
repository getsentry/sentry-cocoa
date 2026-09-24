@_spi(Private) import SentryTestUtils
@_spi(Private) @testable import Sentry
import XCTest

final class SentryExtraContextProviderTests: XCTestCase {

    private class Fixture {
        let memoryMetricsProvider = TestSentryMemoryMetricsProvider()
#if os(iOS)
        let deviceWrapper = TestSentryUIDeviceWrapper()
#endif // os(iOS)
        let processWrapper = MockSentryProcessInfo()
        var reachability = SentryReachability()

        func getSut() -> SentryExtraContextProvider {
            #if os(iOS)
            return SentryExtraContextProvider(
                    memoryMetricsProvider: memoryMetricsProvider,
                    processInfoWrapper: processWrapper,
                    deviceWrapper: deviceWrapper,
                    reachability: reachability)
            #else
            return SentryExtraContextProvider(
                    memoryMetricsProvider: memoryMetricsProvider,
                    processInfoWrapper: processWrapper,
                    reachability: reachability)
            #endif // os(iOS)

        }
    }
    
    private var fixture: Fixture!
    
    override func setUp() {
        super.setUp()
        fixture = Fixture()
    }
    
    override func tearDown() {
        super.tearDown()
        // swiftlint:disable:next avoid_clear_test_state - just disabled to allow adding the SwiftLint rule. Please double check if you can remove this when touching this.
        clearTestState()
    }
    
    func testExtraCrashInfo() throws {
        let sut = fixture.getSut()
        fixture.memoryMetricsProvider.freeMemorySize = 123_456
        fixture.memoryMetricsProvider.appMemorySize = 234_567
        
        let actualContext = sut.getExtraContext()
        let device = actualContext["device"] as? [String: Any]
        let app = actualContext["app"] as? [String: Any]
        
        XCTAssertEqual(device?["free_memory"] as? UInt64, fixture.memoryMetricsProvider.freeMemorySize)
        XCTAssertEqual(app?["app_memory"] as? UInt64, fixture.memoryMetricsProvider.appMemorySize)
    }
    
    func testExtraDeviceInfo() throws {
#if os(iOS)
        let sut = fixture.getSut()
        fixture.deviceWrapper.internalOrientation = .landscapeLeft
        fixture.deviceWrapper.internalBatteryState = .full
        fixture.deviceWrapper.internalBatteryLevel = 0.44
        
        let actualContext = sut.getExtraContext()
        let device = actualContext["device"] as? [String: Any]
        
        XCTAssertEqual(device?["orientation"] as? String, "landscape")
        XCTAssertFalse(try XCTUnwrap(device?["charging"] as? Bool))
        XCTAssertEqual(device?["battery_level"] as? UInt, 44)
#endif // os(iOS)
    }
    
    func testExtraProcessInfo() throws {
        let sut = fixture.getSut()
        fixture.processWrapper.overrides.processorCount = 12
        fixture.processWrapper.overrides.thermalState = .critical

        let actualContext = sut.getExtraContext()
        let device = try XCTUnwrap(actualContext["device"] as? [String: Any])

        XCTAssertEqual(try XCTUnwrap(device["processor_count"] as? Int), fixture.processWrapper.overrides.processorCount)
        XCTAssertEqual(try XCTUnwrap(device["thermal_state"] as? String), "critical")
    }

    func testLowPowerMode() throws {
        let sut = fixture.getSut()
        fixture.processWrapper.overrides.isLowPowerModeEnabled = true

        let actualContext = sut.getExtraContext()
        let device = try XCTUnwrap(actualContext["device"] as? [String: Any])

        XCTAssertTrue(try XCTUnwrap(device["low_power_mode"] as? Bool))
    }

    func testConnectionType_whenReachabilityIsNotMonitoring_shouldNotBeSet() throws {
        // -- Arrange --
        let sut = fixture.getSut()

        // -- Act --
        let actualContext = sut.getExtraContext()

        // -- Assert --
        let device = try XCTUnwrap(actualContext["device"] as? [String: Any])
        XCTAssertNil(device["connection_type"])
    }

    func testConnectionType_whenReachabilityKnowsTheConnection_shouldBeSet() throws {
        // -- Arrange --
        let sut = fixture.getSut()
        fixture.reachability.skipRegisteringActualCallbacks = true
        fixture.reachability.setReachabilityIgnoreActualCallback(true)
        let observer = TestSentryReachabilityObserver()
        fixture.reachability.add(observer)
        fixture.reachability.triggerConnectivityCallback(.wiFi)

        // -- Act --
        let actualContext = sut.getExtraContext()

        // -- Assert --
        let device = try XCTUnwrap(actualContext["device"] as? [String: Any])
        XCTAssertEqual(try XCTUnwrap(device["connection_type"] as? String), "wifi")
        // Only cellular connections have a network technology.
        XCTAssertNil(device["connection_effective_type"])

        fixture.reachability.removeAllObservers()
    }

#if os(iOS) && !targetEnvironment(macCatalyst)
    func testConnectionEffectiveType_whenOnCellularWithKnownTechnology_shouldBeSet() throws {
        // -- Arrange --
        let technologyProvider = TestSentryCellularNetworkTechnologyProvider()
        technologyProvider.currentTechnology = .fifthGeneration
        fixture.reachability = SentryReachability(cellularNetworkTechnologyProvider: technologyProvider)
        let sut = fixture.getSut()
        fixture.reachability.skipRegisteringActualCallbacks = true
        fixture.reachability.setReachabilityIgnoreActualCallback(true)
        let observer = TestSentryReachabilityObserver()
        fixture.reachability.add(observer)
        fixture.reachability.triggerConnectivityCallback(.cellular)

        // -- Act --
        let actualContext = sut.getExtraContext()

        // -- Assert --
        let device = try XCTUnwrap(actualContext["device"] as? [String: Any])
        XCTAssertEqual(try XCTUnwrap(device["connection_type"] as? String), "cellular")
        XCTAssertEqual(try XCTUnwrap(device["connection_effective_type"] as? String), "5g")

        fixture.reachability.removeAllObservers()
    }
#endif // os(iOS) && !targetEnvironment(macCatalyst)

    func testLowPowerModeDisabled() throws {
        let sut = fixture.getSut()
        fixture.processWrapper.overrides.isLowPowerModeEnabled = false

        let actualContext = sut.getExtraContext()
        let device = try XCTUnwrap(actualContext["device"] as? [String: Any])

        XCTAssertFalse(try XCTUnwrap(device["low_power_mode"] as? Bool))
    }

}
