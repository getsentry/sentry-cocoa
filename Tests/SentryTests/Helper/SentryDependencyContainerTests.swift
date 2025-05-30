@testable import Sentry
import SentryTestUtils
import XCTest

final class SentryDependencyContainerTests: XCTestCase {

    private static let dsn = TestConstants.dsnAsString(username: "SentryDependencyContainerTests")

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    func testReset_CallsFramesTrackerStop() throws {
        let framesTracker = SentryDependencyContainer.sharedInstance().framesTracker
        framesTracker.start()
        SentryDependencyContainer.reset()
        
        XCTAssertFalse(framesTracker.isRunning)
    }
    
    func testGetANRTrackerV2() {
        let instance = SentryDependencyContainer.sharedInstance().getANRTracker(2.0, isV2Enabled: true)
        XCTAssertTrue(instance is SentryANRTrackerV2)
        
        SentryDependencyContainer.reset()
        
    }
    
    func testGetANRTrackerV1() {
        let instance = SentryDependencyContainer.sharedInstance().getANRTracker(2.0, isV2Enabled: false)
        XCTAssertTrue(instance is SentryANRTrackerV1)
        
        SentryDependencyContainer.reset()
    }
    
    func testGetANRTrackerV2AndThenV1_FirstCalledVersionStaysTheSame() {
        let instance1 = SentryDependencyContainer.sharedInstance().getANRTracker(2.0, isV2Enabled: true)
        XCTAssertTrue(instance1 is SentryANRTrackerV2)
        
        let instance2 = SentryDependencyContainer.sharedInstance().getANRTracker(2.0, isV2Enabled: false)
        XCTAssertTrue(instance2 is SentryANRTrackerV2)
        
        SentryDependencyContainer.reset()
    }
    
    func testGetANRTrackerV1AndThenV2_FirstCalledVersionStaysTheSame() {
        let instance1 = SentryDependencyContainer.sharedInstance().getANRTracker(2.0, isV2Enabled: false)
        XCTAssertTrue(instance1 is SentryANRTrackerV1)
        
        let instance2 = SentryDependencyContainer.sharedInstance().getANRTracker(2.0, isV2Enabled: true)
        XCTAssertTrue(instance2 is SentryANRTrackerV1)
        
        SentryDependencyContainer.reset()
    }
    
#endif
    
    func testGetANRTracker_ReturnsV1() {
        
        let instance = SentryDependencyContainer.sharedInstance().getANRTracker(2.0)
        XCTAssertTrue(instance is SentryANRTrackerV1)

        SentryDependencyContainer.reset()
    }

    /**
     * This test helps to find threading issues. If you run it once it detects obvious threading issues. Some rare edge cases
     * only happen if you run this 1000 times in a row or increase the test iterations to 100k.
     * While this testing scenario is atypical for production, we heavily call reset in our tests and saw crashes and problems
     * related to that. Therefore, it makes sense to ensure thread safety.
     */
    func testThreadSafety_ResetAndAccessProperties() {

        let options = Options()
        options.dsn = SentryDependencyContainerTests.dsn
        SentrySDK.setStart(options)

        let iterations = 100

        let queue = DispatchQueue(label: "SentryDependencyContainerTests", qos: .userInteractive, attributes: [.concurrent, .initiallyInactive])
        let expectation = expectation(description: "testThreadSafety_ResetAndAccessProperties")
        expectation.expectedFulfillmentCount = iterations

        for _ in 0..<iterations {

            queue.async {

                for _ in 0...10 {
                    // This is a quite unrealistic scenario, but it helps to find threading issues.
                    SentryDependencyContainer.reset()
                }

                for _ in 0...10 {
                    // Init Dependencies
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().dispatchQueueWrapper)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().random)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().threadWrapper)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().binaryImageCache)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().dateProvider)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().debugImageProvider)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().extraContextProvider)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().notificationCenterWrapper)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().crashWrapper)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().processInfoWrapper)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().sysctlWrapper)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().rateLimits)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().reachability)

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().uiDeviceWrapper)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().application)
#endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

                    // Lazy Dependencies
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().fileManager)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().appStateManager)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().threadInspector)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().fileIOTracker)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().crashReporter)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().getANRTracker(2.0))

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().getANRTracker(2.0, isV2Enabled: true))
#endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().systemWrapper)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().dispatchFactory)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().dispatchQueueProvider)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().timerFactory)

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().swizzleWrapper)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().framesTracker)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().screenshot)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().viewHierarchy)

                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().uiViewControllerPerformanceTracker)
#endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

#if os(iOS) || os(macOS)
                    if #available(iOS 15.0, macOS 12.0, *) {
                        XCTAssertNotNil(SentryDependencyContainer.sharedInstance().metricKitManager)
                    }
#endif // os(iOS) || os(macOS)

                }

                expectation.fulfill()
            }
        }

        queue.activate()

        wait(for: [expectation], timeout: 10)
    }
}
