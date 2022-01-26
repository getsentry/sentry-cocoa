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
}
