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

    func testThreadSafety_ResetAndProperties() {

        let options = Options()
        options.dsn = SentryDependencyContainerTests.dsn
        SentrySDK.setStart(options)

        let iterations = 100

        let queue = DispatchQueue(label: "mod", qos: .userInteractive, attributes: [.concurrent, .initiallyInactive])
        let expectation = expectation(description: "Reset")
        expectation.expectedFulfillmentCount = iterations

        for _ in 0..<iterations {

            queue.async {

                for _ in 0...10 {
                    SentryDependencyContainer.reset()
                }

                for _ in 0...10 {
                    // Dependencies in init
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().dispatchQueueWrapper)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().random)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().threadWrapper)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().dateProvider)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().debugImageProvider)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().extraContextProvider)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().notificationCenterWrapper)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().crashReporter)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().rateLimits)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().processInfoWrapper)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().reachability)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().sysctlWrapper)

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().uiDeviceWrapper)
#endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

                    // Dependencies that get set to nil in reset
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().fileManager)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().appStateManager)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().threadInspector)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().fileIOTracker)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().getANRTracker(2.0))

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().getANRTracker(2.0, isV2Enabled: true))
#endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

                    // Dependencies lazy initialized
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().crashWrapper)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().systemWrapper)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().dispatchFactory)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().timerFactory)

#if os(iOS) || os(macOS)
                    if #available(iOS 15.0, macOS 12.0, *) {
                        XCTAssertNotNil(SentryDependencyContainer.sharedInstance().metricKitManager)
                    }
#endif // os(iOS) || os(macOS)

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().viewHierarchy)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().application)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().framesTracker)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().swizzleWrapper)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().uiViewControllerPerformanceTracker)
#endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

                }

                expectation.fulfill()
            }
        }

        queue.activate()

        wait(for: [expectation], timeout: 5.0)
    }
}
