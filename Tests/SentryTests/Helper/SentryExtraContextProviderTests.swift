import SentryTestUtils
import XCTest

final class SentryExtraContextProviderTests: XCTestCase {

    private class Fixture {
        let crashWrapper = TestSentryCrashWrapper.sharedInstance()
#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
        let deviceWrapper = TestSentryUIDeviceWrapper()
#endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
        let processWrapper = TestSentryNSProcessInfoWrapper()
        
        func getSut() -> SentryExtraContextProvider {
            #if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
            SentryDependencyContainer.sharedInstance().uiDeviceWrapper = deviceWrapper
            #endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
            return SentryExtraContextProvider(
                    crashWrapper: crashWrapper,
                    processInfoWrapper: processWrapper)
        }
    }
    
    private var fixture: Fixture!
    
    override func setUp() {
        super.setUp()
        fixture = Fixture()
    }
    
    func testExtraCrashInfo() throws {
        let sut = fixture.getSut()
        fixture.crashWrapper.internalFreeMemorySize = 123_456
        fixture.crashWrapper.internalAppMemorySize = 234_567
        fixture.crashWrapper.internalFreeStorageSize = 345_678
        
        let actualContext = sut.getExtraContext()
        let device = actualContext["device"] as? [String: Any]
        let app = actualContext["app"] as? [String: Any]
        
        XCTAssertEqual(device?["free_memory"] as? UInt64, fixture.crashWrapper.internalFreeMemorySize)
        XCTAssertEqual(app?["app_memory"] as? UInt64, fixture.crashWrapper.internalAppMemorySize)
        XCTAssertEqual(device?["free_storage"] as? UInt64, fixture.crashWrapper.internalFreeStorageSize)
    }
    
    func testExtraDeviceInfo() {
#if os(iOS)
        let sut = fixture.getSut()
        fixture.deviceWrapper.internalOrientation = .landscapeLeft
        fixture.deviceWrapper.internalBatteryState = .full
        fixture.deviceWrapper.internalBatteryLevel = 0.44
        
        let actualContext = sut.getExtraContext()
        let device = actualContext["device"] as? [String: Any]
        
        XCTAssertEqual(device?["orientation"] as? String, "landscape")
        XCTAssertEqual(device?["charging"] as? Bool, false)
        XCTAssertEqual(device?["battery_level"] as? UInt, 44)
#endif
    }
    
    func testExtraProcessInfo() {
        let sut = fixture.getSut()
        fixture.processWrapper.overrides.processorCount = 12
        
        let actualContext = sut.getExtraContext()
        let device = actualContext["device"] as? [String: Any]
        
        XCTAssertEqual(device?["processor_count"] as? UInt, fixture.processWrapper.overrides.processorCount)
    }

}
