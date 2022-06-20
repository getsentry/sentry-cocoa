import XCTest

class SentryOutOfMemoryIntegrationTests: XCTestCase {

    func testWhenUnitTests_TrackerNotInitialized() {
        let sut = SentryOutOfMemoryTrackingIntegration()
        sut.install(with: Options())
        
        XCTAssertNil(Dynamic(sut).tracker.asAnyObject)
    }
    
    func testWhenNoUnitTests_TrackerInitialized() {
        let sut = SentryOutOfMemoryTrackingIntegration()
        Dynamic(sut).setTestConfigurationFilePath(nil)
        sut.install(with: Options())
        
        XCTAssertNotNil(Dynamic(sut).tracker.asAnyObject)
    }
    
    func testTestConfigurationFilePath() {
        let sut = SentryOutOfMemoryTrackingIntegration()
        let path = Dynamic(sut).testConfigurationFilePath.asString
        XCTAssertEqual(path, ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"])
    }
    
    func test_OOMDisabled_RemovesEnabledIntegration() {
        let options = Options()
        options.enableOutOfMemoryTracking = false
        
        let sut = SentryOutOfMemoryTrackingIntegration()
        sut.install(with: options)
        
        let expexted = Options.defaultIntegrations().filter { !$0.contains("OutOfMemory") }
        assertArrayEquals(expected: expexted, actual: Array(options.enabledIntegrations))
    }
}
